"""Build the Game Boy (dual-mode DMG / SGB / CGB) FF1 English ROM from the user's own NES ROM.

usage: build.py ["Final Fantasy I, II (Japan).nes"] [--gb] [--cov DIR] [--out ROM]
  --gb: the GB layout (insert.py --gb -> build/ff1_gb.nes; default coverage build/cov3,
        output build/ff1_gb.gb); without it: build/ff1_en.nes, build/cov2, build/ff1_en.gb

1. NES ROM -> MMC5 split (tools/split/build_mmc5.py) -> English (tools/ff1/insert.py)
   = build/ff1_en.nes
2. code map from coverage logs (DIR/*.bin, made by tools/gb/covrun.py)
3. recompile (tools/gb/recomp.py) + runtime (tools/gb/rt/runtime.s), assemble
4. ROM: bank 0 runtime, banks DATA.. = the NES banks' data, then code banks
Nothing game-specific is stored in the repo; everything comes from the NES ROM.
"""
import re, os, sys, glob, hashlib, subprocess, time
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..', '..')
sys.path.insert(0, HERE)
from nescode import CodeMap
from recomp import Recompiler, emit_program, DATA, RT_TABLES
from asm_sm83 import asm, make_rom

SHA1_FF12 = '4b22c2c88fc71eacf270ea51ef218944bb4c536a'


def shade(c):
    """NES palette index -> DMG shade (0 white .. 3 black), by brightness row."""
    lo, hi = c & 0x0F, c >> 4
    if lo >= 0x0D: return 3
    if lo == 0: return [2, 1, 0, 0][hi]
    return [3, 2, 1, 0][hi]


# NES 2C02 palette (the values of the cynes emulator, our NES reference, no emphasis) ->
# CGB RGB555. Hardware data, not game content: the CGB mode shows the NES palette RAM
# through it.
NES_RGB = [
    0x545454, 0x001E74, 0x081090, 0x300088, 0x440064, 0x5C0030, 0x540400, 0x3C1800,
    0x202A00, 0x083A00, 0x004000, 0x003C00, 0x00323C, 0x000000, 0x000000, 0x000000,
    0x989698, 0x084CC4, 0x3032EC, 0x5C1EE4, 0x8814B0, 0xA01464, 0x982220, 0x783C00,
    0x545A00, 0x287200, 0x087C00, 0x007628, 0x006678, 0x000000, 0x000000, 0x000000,
    0xECEEEC, 0x4C9AEC, 0x787CEC, 0xB062EC, 0xE454EC, 0xEC58B4, 0xEC6A64, 0xD48820,
    0xA0AA00, 0x74C400, 0x4CD020, 0x38CC6C, 0x38B4CC, 0x3C3C3C, 0x000000, 0x000000,
    0xECEEEC, 0xA8CCEC, 0xBCBCEC, 0xD4B2EC, 0xECAEEC, 0xECAED4, 0xECB4B0, 0xE4C490,
    0xCCD278, 0xB4DE78, 0xA8E290, 0x98E2B4, 0xA0D6E4, 0xA0A2A0, 0x000000, 0x000000]


def border_src():
    """SGB border (tools/gb/sgb_border.py, drawn by code) in bank RT_TABLES at $6000"""
    import sgb_border
    chr_, pct, n = sgb_border.make()
    out = 'section bank %d, $6000\nsgb_bdr_chr:\n' % RT_TABLES
    out += ''.join('    db %s\n' % ', '.join('$%02X' % b for b in chr_[i:i + 16]) for i in range(0, len(chr_), 16))
    out += 'sgb_bdr_chr_end:\nsgb_bdr_pct:\n'
    out += ''.join('    db %s\n' % ', '.join('$%02X' % b for b in pct[i:i + 16]) for i in range(0, len(pct), 16))
    return out


def ramchk_src():
    """Font and text of the boot RAM-check message (rt/ramchk.s), from the repo's own font
    (tools/latin_font.py): one 8 x 8 tile per character, ink colour 3."""
    sys.path.insert(0, os.path.join(HERE, '..'))
    import latin_font as L
    chars = ' ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,()-:'
    out = 'section bank DYN_BANK, $7200\nramchk_font:\n'
    for ch in chars:
        cols = L._glyph_cols(ch, L.G) if ch != ' ' else []
        x0 = max(0, (8 - len(cols)) // 2)
        rows = []
        for y in range(8):
            v = 0
            for x, col in enumerate(cols[:8]):
                if col[y]: v |= 0x80 >> (x0 + x)
            rows += [v, v]
        out += '    db %s\n' % ', '.join('$%02X' % b for b in rows)
    out += 'ramchk_font_end:\nramchk_text:\n'
    lines = ['CARTRIDGE RAM ERROR', '', 'THIS GAME NEEDS', '32 KB OF SAVE RAM', 'IN FOUR BANKS (MBC5)',
             '', 'THIS CART DOES NOT', 'BANK ITS SAVE RAM.']
    assert all(len(t) <= 20 for t in lines)
    for r, t in enumerate(lines):
        if not t: continue
        off = 0x9800 + (4 + r) * 32 + (20 - len(t)) // 2
        out += '    db $%02X, $%02X, %d, %s\n' % (off & 0xFF, off >> 8, len(t), ', '.join(str(chars.index(c)) for c in t))
    out += '    db 0, 0\n'
    return out


def nes_rgb_src():
    """NES_RGB ($3E00) and, at EMPH_RGB + e * $80 ($3A80-$3DFF), the colours with the NES
    emphasis bits e = 1-7 ($2001 bits 5-7: red, green, blue): the other components dimmed
    to 3/4, as the 2C02 roughly does (FF1's battle-start flashes cycle through them)"""
    def table(e):
        vals = []
        for c in NES_RGB:
            r, g, b = c >> 16, (c >> 8) & 255, c & 255
            if e:
                if e & 6: r = r * 3 // 4
                if e & 5: g = g * 3 // 4
                if e & 3: b = b * 3 // 4
            vals.append(str((r >> 3) | (g >> 3) << 5 | (b >> 3) << 10))
        return ''.join('    dw %s\n' % ', '.join(vals[k:k + 8]) for k in range(0, 64, 8))
    return 'section bank 0, $3E00\nNES_RGB:\n' + table(0)     # (emphasis: computed, runtime.s)


def apu_tables():
    """NES APU -> GB: frequency value for each 11-bit pulse/triangle timer (both:
    2048 - x = 131072 * 16 * (t + 1) / 1789773), and NR43 for each NES noise period."""
    import math
    freq = []
    for t in range(2048):
        x = round(2048 - 131072 * 16 * (t + 1) / 1789773)
        freq.append(max(0, min(2047, x)))
    periods = [4, 8, 16, 32, 64, 96, 128, 160, 202, 254, 380, 508, 762, 1016, 2034, 4068]
    noise = []
    for p in periods:
        f = 1789773 / p
        best = None
        for sh in range(14):
            for r in range(8):
                g = 262144 / ((r or 0.5) * (1 << sh))
                e = abs(math.log(g / f))
                if best is None or e < best[0]: best = (e, sh << 4 | r)
        noise.append(best[1])
    src = 'section bank %d, $4000\napu_freq:\n' % RT_TABLES
    for k in range(0, 2048, 16):
        src += '    dw %s\n' % ', '.join(str(v) for v in freq[k:k + 16])
    src += 'apu_noise:\n    db %s\n' % ', '.join(str(v) for v in noise)
    # volume scaling (apu_core vscale): VSTAB[level * 16 + v] = v at level 8, else
    # (v * level + 7) >> 3 (rounded up: a quiet note stays audible); PADJ[level] = the pulses'
    # level, 5/8 of it ((5 * level + 4) >> 3)
    src += 'section bank %d, $5100\nVSTAB:\n' % RT_TABLES
    for lv in range(9):
        src += '    db %s\n' % ', '.join(str(v if lv >= 8 else (v * lv + 7) >> 3) for v in range(16))
    src += 'PADJ:\n    db %s\n' % ', '.join(str((5 * lv + 4) >> 3) for lv in range(9))
    return src


def nes_english(src, out_dir, gb=False):
    out = os.path.join(out_dir, 'ff1_gb.nes' if gb else 'ff1_en.nes')
    if os.path.exists(out) and not gb: return out
    if hashlib.sha1(open(src, 'rb').read()).hexdigest() != SHA1_FF12:
        raise SystemExit('not the expected Final Fantasy I・II (Japan) ROM: ' + src)
    sys.path.insert(0, os.path.join(ROOT, 'tools'))
    from pyrun import script_cmd
    subprocess.check_call(script_cmd(os.path.join(ROOT, 'tools', 'split', 'build_mmc5.py'), src, out_dir), cwd=ROOT)
    subprocess.check_call(script_cmd(os.path.join(ROOT, 'tools', 'ff1', 'insert.py'),
                                     os.path.join(out_dir, 'ff1_mmc5.nes'), out, *(['--gb'] if gb else [])), cwd=ROOT)
    return out


FAR_EXT = {'vtile': ('hle_vtile', 'NZC'),        # gb_layout.py's small-font tile upload
           'vstr': ('hle_vstr', 'NZC'),          #   and text renderer (rt/ff1_native.s)
           'vclear': ('hle_vclear', 'NZC')}
FAR_BANK = 40                                     # (8 KB bank of the far code)


def vwf_tables(prg, far_sym):
    """The small-font glyph tables (widths GW, rows GR, codes $7A-$FF) copied from the far bank
    of the English NES ROM into the native bank for vstr_b (rt/ff1_native.s)."""
    n = 256 - 0x7A
    if 'GW' not in far_sym or 'GR' not in far_sym:
        return 'VW_GR_NES = 0\nsection bank HLE_BANK, $7A00\nvw_gw:\nvw_gr:\nsection bank HLE_BANK, $6000\nVW_SHR:\n'
    off = lambda a: FAR_BANK * 0x2000 + a - 0xC000
    gw = prg[off(far_sym['GW']):off(far_sym['GW']) + n]
    gr = prg[off(far_sym['GR']):off(far_sym['GR']) + 8 * n]
    rows = lambda b: '\n'.join('            db ' + ', '.join('$%02X' % x for x in b[i:i + 16]) for i in range(0, len(b), 16))
    shr = bytearray()                                # shift s (1-7): page of b >> s, page of b << (8 - s)
    for sh in range(1, 8):
        shr += bytes(b >> sh for b in range(256)) + bytes((b << (8 - sh)) & 255 for b in range(256))
    return ('VW_GR_NES = $%04X\nsection bank HLE_BANK, $7A00\nvw_gw:\n%s\nvw_gr:\n%s\n' % (far_sym['GR'], rows(gw), rows(gr))
            + 'section bank HLE_BANK, $6000\nVW_SHR:\n%s\n' % rows(shr))


def main():
    args = sys.argv[1:]
    gb = '--gb' in args
    if gb: args.remove('--gb')
    name = 'ff1_gb' if gb else 'ff1_en'
    opt = {'--cov': os.path.join(ROOT, 'build', 'cov3' if gb else 'cov2'),
           '--out': os.path.join(ROOT, 'build', name + '.gb'), '--nes': None}
    pos = []
    while args:
        a = args.pop(0)
        if a in opt: opt[a] = args.pop(0)
        else: pos.append(a)
    src = pos[0] if pos else os.path.join(ROOT, 'roms', 'Final Fantasy I, II (Japan).nes')
    out_dir = os.path.dirname(os.path.abspath(opt['--out']))
    os.makedirs(out_dir, exist_ok=True)
    nes = opt['--nes'] or nes_english(src, out_dir, gb)     # --nes: an English NES ROM already built
    covs = sorted(glob.glob(os.path.join(opt['--cov'], '*.bin')))
    if not covs: raise SystemExit('no coverage logs in %s (run tools/gb/covall.py)' % opt['--cov'])
    shf = os.path.join(opt['--cov'], 'rom.sha1')
    old_rom = None
    if os.path.exists(shf) and open(shf).read().split()[0] != hashlib.sha1(open(nes, 'rb').read()).hexdigest():
        print('WARNING: coverage in %s is from another NES ROM: run tools/gb/covall.py %s %s'
              % (opt['--cov'], nes, opt['--cov']))
        if os.path.exists(os.path.join(opt['--cov'], 'rom.nes')):     # (covall keeps a copy)
            old_rom = open(os.path.join(opt['--cov'], 'rom.nes'), 'rb').read()
    t = time.time()
    entries = []                                      # far routines (dispatched by farjsr)
    if os.path.exists(nes + '.far'):
        for l in open(nes + '.far'):           # (lines 'ex:ADDR': ExRAM RTS-dispatch targets)
            if not l.strip(): continue
            a = l.split()[0]
            entries.append(('ex', int(a[3:], 16)) if a.startswith('ex:') else ('far', int(a, 16)))
    from recomp import FF1
    cm = CodeMap(nes, covs, entries, old_rom, getattr(FF1, 'jump_tables', ()))
    if old_rom is not None:
        print('  coverage of %d changed bytes dropped (static flow only there; check, then regenerate)' % cm.stale)
    cm = cm.build()
    rc = Recompiler(cm)
    prg = open(nes, 'rb').read()[16:]
    for k, code in getattr(rc.g, 'idiom_code', {}).items():   # (fixed bank: the last 8KB)
        off = (len(prg) - 0x2000 + k[1] - 0xE000 if k[0] == 'fix' else
               int(k[0][1:]) * 0x4000 + k[1] - 0x8000 if k[0][0] == 'b' else
               62 * 0x2000 + k[1] - 0xC000 if k[0] == 'c62' else None)
        if off is None or prg[off:off + len(code)] != code:
            print('  idiom %s:%04X: code not found, not used' % k); rc.g.idioms.pop(k, None)
    wrow3 = {}                                       # window rows in the fixed bank: LDA #L /
    fixo = len(prg) - 0x2000                         #   STA $2007 / LDA #M / STA $2007 / DEX /
    for m in re.finditer(re.escape(bytes.fromhex('8d0720a9')) + b'(.)' + re.escape(bytes.fromhex(
            '8d0720cad0faa9')) + b'(.)' + re.escape(bytes.fromhex('8d0720')), prg[fixo:], re.S):   # BNE / LDA #R / STA $2007
        at = fixo + m.start()
        if prg[at - 2] != 0xA9: continue
        lt, mt, rt_ = prg[at - 1], m.group(1)[0], m.group(2)[0]
        if wrow3.get(lt, (mt, rt_)) != (mt, rt_): print('  window row: tile $%02X twice, not native' % lt); continue
        wrow3[lt] = (mt, rt_)
        a = 0xE000 + m.start()
        rc.g.idioms[('fix', a)] = ('hle_wrow3', a + 16, 'NZ')   # (at the left tile's STA: A = L)
    for sp, base, off, size in ([('fix', 0xE000, fixo, 0x2000), ('c62', 0xC000, 62 * 0x2000, 0x2000)] +
                                [('b%02d' % b, 0x8000, b * 0x4000, 0x4000) for b in range(31)]):
        blk = prg[off:off + size]                    # every STA $2007 / DEX / BNE (to the STA):
        for m in re.finditer(re.escape(bytes.fromhex('8d0720cad0fa')), blk):   # X x A (hle_wrow)
            k = (sp, base + m.start())
            if k not in rc.g.idioms and k in rc.insns:
                rc.g.idioms[k] = ('hle_wrow', base + m.start() + 6, 'NZ')
    wrf = []                                         # whole window-row routines after their
    pat = re.compile(re.escape(bytes.fromhex('20bde1ad0220a5558d0620a5548d0620a61aa9')) + b'(.)' +
                     re.escape(bytes.fromhex('8d0720a9')) + b'(.)' + re.escape(bytes.fromhex('8d0720cad0faa9')) +
                     b'(.)' + re.escape(bytes.fromhex('8d0720')), re.S)    # JSR $E1BD ... (fixed bank)
    for m in pat.finditer(prg[fixo:]):
        a = 0xE000 + m.start() + 3                   # (the LDA $2002)
        tail = prg[fixo + m.end():fixo + m.end() + 14]
        if tail[:13] == bytes.fromhex('a5541869208554a55569008555') and tail[13] == 0x60:
            add, end = 1, 0xE000 + m.end() + 13
        elif tail[0] == 0x60:
            add, end = 0, 0xE000 + m.end()
        else:
            continue
        if len(wrf) >= 3: break
        n = len(wrf)
        wrf.append((m.group(1)[0], m.group(2)[0], m.group(3)[0], add))
        rc.g.idioms[('fix', a)] = ('pf:wrf_v%d' % n, end, 'NZC')
    txr = {('c62', 0xDECE): 'a000b13ef0cce63ed002e63fc948902b4ca45c',      # menu text printer:
           ('c62', 0xDEF1): 'ae0220a6558e0620a6548e06208c07208d0720e6544ccede',   # the loop head,
           ('ex', 0x5CA4): 'ac005cd005a0ff4cf1deae022088d010a6558e0620a6548e06208d07204c04df'
                           '48a554186920aaa55569008d06208e0620688d07204c04df'}  # letters (txrun_b)
    def at(k): return (62 * 0x2000 + k[1] - 0xC000 if k[0] == 'c62' else 18 * 0x4000 + k[1] - 0x5C00)
    if all(prg[at(k):at(k) + len(h) // 2].hex() == h for k, h in txr.items()):
        rc.g.idioms[('c62', 0xDECE)] = ('pf:txrun_b', 0xDED2, 'NZCV')
    else:
        print('  menu text printer: code not found, not native')
    dbox = ('a53c38e902851aa53d38e902851b208be12034e1c61bd0f92066e1',      # DrawBox rows (E0FD) and
            '20bde1ad0220a5558d0620a5548d0620a61aa9fa8d0720a9ff8d0720cad0faa9fb8d0720a554186920'   # its row
            '8554a555690085556020bde1ad0220a5558d0620a5548d0620a61aa9fc8d0720a9fd8d0720cad0faa9fe'  # routines
            '8d07206020bde1ad0220a5558d0620a5548d0620a61aa9f78d0720a9f88d0720cad0faa9f98d0720a554'  # (E134-E1D4):
            '1869208554a5556900855560a537f013a5ff8d0020a9008d05208d0520208bc62000fe60')           # dbox_b
    if prg[fixo + 0x0FD:fixo + 0x118].hex() == dbox[0] and prg[fixo + 0x134:fixo + 0x1D5].hex() == dbox[1]:
        rc.g.idioms[('fix', 0xE0FD)] = ('pf:dbox_b', 0xE118, 'NZCV', 'cond')
    else:
        print('  DrawBox: code not found, not native')
    wrf_src = 'WRF:\n' + ''.join('    db $%02X, $%02X, $%02X, %d\n' % w for w in wrf)
    for n in range(3):
        wrf_src += 'wrf_v%d:     ld a, %d\n            jp wrf_b\n' % (n, n) if n < len(wrf) else 'wrf_v%d:     ret\n' % n
    wrow3_src = 'WROW3:\n' + ''.join('    db $%02X, $%02X, $%02X\n' % (l, m_, r_) for l, (m_, r_) in sorted(wrow3.items())) + '    db 0, 0, 0\n'
    far_sym = {}
    if os.path.exists(nes + '.farsym'):              # far routines run natively (rt/ff1_native.s)
        for l in open(nes + '.farsym'):
            a, n = l.split()
            far_sym[n] = int(a, 16)
            if n in FAR_EXT: rc.g.ext[('far', int(a, 16))] = FAR_EXT[n]
    prow_off = 0                                     # gb_layout prow's row loop (pr1..pr3):
    if 'pr1' in far_sym and 'pr3' in far_sym:        #   native (rt/ff1_native.s prow_b)
        o = FAR_BANK * 0x2000 + far_sym['pr1'] - 0xC000
        c = prg[o:o + 15]
        if (c[:5] == bytes.fromhex('b110c91090') and c[6] == 0x4D and c[9:] == bytes.fromhex('8d0720c8d0f1')
                and far_sym['pr1'] + 6 + c[5] == far_sym['pr3'] and c[8] < 0x08):
            prow_off = c[7] | c[8] << 8
            rc.g.idioms[('far', far_sym['pr1'])] = ('pf:prow_b', far_sym['pr3'], 'NZC')
        else:
            print('  far pr1: code not as expected, not native')
    prog, bank_of, banks = emit_program(rc)
    rt = '\n'.join(open(os.path.join(HERE, 'rt', f)).read() for f in ('runtime.s', 'apu.s', 'ff1_hle.s', 'dmg_shade.s', 'sgb.s'))
    rt += '\nPROW_OFF = NES_RAM + $%04X\n' % prow_off
    rt += '\nsection bank HLE_BANK, $7800\n' + wrow3_src     # (build-time table from the ROM)
    rt += '\nsection bank PF_BANK, $7C00\n' + wrf_src
    rt += '\n' + apu_tables() + '\nSND_MASK = $%02X\n' % int(os.environ.get('GB_SND_MASK', 'FF'), 16) + 'MDF_ON = %d\n' % int(os.environ.get('GB_MDF', '1'))
    rt += open(os.path.join(HERE, 'rt', 'apu_core.s')).read()
    rt += '\n' + vwf_tables(prg, far_sym)            # (before ff1_native.s: VW_GR_NES)
    rt += '\n' + open(os.path.join(HERE, 'rt', 'ff1_native.s')).read()
    rt += '\n' + open(os.path.join(HERE, 'rt', 'ramchk.s')).read() + '\n' + ramchk_src()
    shade_src = 'section bank 0, $3F00\nshade_tab:\n' + ''.join(
        '    db %s\n' % ', '.join(str(shade(c)) for c in range(r, r + 16)) for r in range(0, 64, 16))
    src_all = rt + '\n' + shade_src + '\n' + nes_rgb_src() + '\n' + border_src() + '\n' + prog
    open(opt['--out'] + '.s', 'w').write(src_all)
    print('recompiled: %d instructions, %d code banks (%.1fs)' % (len(rc.insns), len(banks), time.time() - t))
    print('  (zp),Y inline: %d' % getattr(rc, 'izy_inl', 0))
    t = time.time()
    r = asm(src_all, syms={'DATA': DATA, 'RT_TABLES': RT_TABLES})
    print('assembled (%.1fs)' % (time.time() - t))
    rom_nes = open(nes, 'rb').read()[16:]
    for n in range(32):
        r.banks[DATA + n] = bytearray(rom_nes[n * 0x4000:(n + 1) * 0x4000])
    top = max(r.banks) + 1
    size = 2
    while size < top: size *= 2
    rom = make_rom(r.banks, 'FF1 ENGLISH', cart_type=0x1B, rom_banks=size, ram_size_code=0x03, sgb=True,
                   cgb=0x80)                          # dual-mode: DMG / SGB / CGB
    open(opt['--out'], 'wb').write(rom)
    open(opt['--out'][:-3] + '.sym', 'w').write(r.sym_file())
    used0 = len(r.banks[0])
    print('wrote %s: %d KB, bank 0 used %d bytes' % (opt['--out'], len(rom) // 1024, used0))
    w = {}
    for x in rc.warn: w.setdefault(x.split(' at ')[0].split(' from ')[0][:40], []).append(x)
    open(opt['--out'] + '.warn', 'w').write('\n'.join(rc.warn) + '\n')
    for k, v in sorted(w.items(), key=lambda kv: -len(kv[1])):
        print('  warn %-42s x%d  e.g. %s' % (k, len(v), v[0][-40:]))


if __name__ == '__main__':
    main()
