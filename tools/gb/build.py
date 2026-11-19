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
import os, sys, glob, hashlib, subprocess, time
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
    far_sym = {}
    if os.path.exists(nes + '.farsym'):              # far routines run natively (rt/ff1_native.s)
        for l in open(nes + '.farsym'):
            a, n = l.split()
            far_sym[n] = int(a, 16)
            if n in FAR_EXT: rc.g.ext[('far', int(a, 16))] = FAR_EXT[n]
    prog, bank_of, banks = emit_program(rc)
    rt = '\n'.join(open(os.path.join(HERE, 'rt', f)).read() for f in ('runtime.s', 'apu.s', 'ff1_hle.s', 'dmg_shade.s', 'sgb.s'))
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
