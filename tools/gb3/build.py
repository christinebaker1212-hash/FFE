"""Build the Game Boy Color FF3 English ROM from the user's own NES ROM.

usage: build.py ["Final Fantasy III (Japan).nes"] [--gb] [--release] [--nes EN.nes] [--cov DIR] [--out ROM]

--release: no test hooks (the test-pad input mode), cart RAM 8 KB in the header; check with
tools/gb/lotcheck.py ROM --game ff3 --release (docs/gb-release-checklist.md)

--gb: the GB screen layouts (tools/gb3/layout.py on the English NES ROM = build/ff3_gb.nes,
source base build/ff3/src_gb, output build/ff3_gb.gbc)

1. NES ROM -> MMC5 (tools/ff3_mmc5/build.py) -> English (tools/ff3/insert.py)
   = build/ff3_en.nes
2. source base (tools/gb3/ff3src.py --english -> build/ff3/src_en: listing + ROM; needs
   build/src/ff3, the everything8215 listing) -> code map (tools/gb3/ff3code.py)
3. translate (tools/gb3/translate.py) + runtime (tools/gb3/rt/*.s), assemble
4. ROM (2 MB MBC5 + 32 KB battery RAM, CGB only): bank 0 runtime + stubs, banks DATA.. =
   the NES 8KB banks in pairs, RT_TABLES, code banks, the dynamic-target table in bank 127
Nothing game-specific is stored in the repo; everything comes from the NES ROM.
"""
import os, sys, glob, hashlib, subprocess, time, json
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..', '..')
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..', 'gb'))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
from ff3code import CodeMap
from translate import Recompiler, emit_program, DATA, RT_TABLES, CODE0
from asm_sm83 import asm, make_rom
import build as gb1                       # tools/gb/build.py: shared tables (NES colours)

SHA1_JA = 'c4443fc24625e3c2bb859525eb44b6b3a80e7c35'
RT_FILES = ('hw.s', 'runtime.s', 'native.s')   # (native.s continues bank 0)


def nes_english(src, out_dir):
    out = os.path.join(out_dir, 'ff3_en.nes')
    if hashlib.sha1(open(src, 'rb').read()).hexdigest() != SHA1_JA:
        raise SystemExit('not the expected Final Fantasy III (Japan) ROM: ' + src)
    from pyrun import script_cmd
    mmc5 = os.path.join(out_dir, 'ff3_mmc5.nes')
    subprocess.check_call(script_cmd(os.path.join(ROOT, 'tools', 'ff3_mmc5', 'build.py'), src, mmc5), cwd=ROOT)
    subprocess.check_call(script_cmd(os.path.join(ROOT, 'tools', 'ff3', 'insert.py'), mmc5, out), cwd=ROOT)
    return out


def source_base(src, nes, srcdir, gb=False):
    """build/ff3/src_en (src_gb) from the listing + ROM, unless it is already there for this ROM"""
    mp = os.path.join(srcdir, 'map.json')
    sha = hashlib.sha1(open(nes, 'rb').read()).hexdigest()
    tools = [os.path.join(HERE, f) for f in ('ff3src.py', 'ff3en.py', 'layout.py')] + [os.path.join(ROOT, 'tools', 'ff3', 'insert.py')]
    fresh = os.path.exists(mp) and all(os.path.getmtime(t) <= os.path.getmtime(mp) for t in tools)
    if fresh and json.load(open(mp))['rom_sha1'] == sha: return
    listing = os.path.join(ROOT, 'build', 'src', 'ff3', 'ff3j.asm')
    if not os.path.exists(listing):
        raise SystemExit('everything8215 listing missing: git clone --depth 1 '
                         'https://github.com/everything8215/ff3 build/src/ff3')
    from pyrun import script_cmd
    subprocess.check_call(script_cmd(os.path.join(HERE, 'ff3src.py'), src, srcdir, '--english', '--listing', listing,
                                     *(['--gb'] if gb else [])), cwd=ROOT)


DMG_MSG = ['This Game Pak', 'is designed only', 'for use with the', 'Game Boy Color™', 'system.']
TM = ['####...#', '.#.##.##', '.#.#.#.#', '.#.#...#', '........', '........', '........', '........']
SAVE_MSG = ['Save data error', '', '', '', '', '', 'Damaged save files', 'will be erased.',
            '', '', 'Press the A Button.']
SAVE_ROW0 = 3                       # SAVE_MSG from map row 3; "File n is damaged." at rows 5-7
SAVE_FILE = 'File %d is damaged.'


def font_tiles(text):
    """tiles for the characters of text in the project font (tools/latin_font.py), colour 3
    ink on colour 0; tile 0 blank. -> (tile bytes, {char: tile})"""
    sys.path.insert(0, os.path.join(ROOT, 'tools'))
    from latin_font import G
    chars = sorted(set(text) - {' '})
    tiles = [bytes(16)]
    for ch in chars:
        if ch == '™': src = TM
        else: src = G[ch]
        rows = [sum(0x80 >> x for x, v in enumerate(r) if v == '#') for r in src]
        if ch in 'gjpqy,;': rows = [0] + rows               # (descenders: rows 1-7)
        rows = (rows + [0] * 8)[:8]
        tiles.append(bytes(b for r in rows for b in (r, r)))
    return b''.join(tiles), {ch: i + 1 for i, ch in enumerate(chars)}


def text_row(line, code):
    r = bytearray(20); c0 = (20 - len(line)) // 2
    for i, ch in enumerate(line):
        if ch != ' ': r[c0 + i] = code[ch]
    return bytes(r)


def dmg_msg_src():
    """Color-only cartridge on a monochrome Game Boy (release requirement, docs/
    gb-release-checklist.md): a screen with DMG_MSG in the project's own font
    (tools/latin_font.py), LCD switched off only in the vblank, then a halt with no interrupt
    enabled (low power). In the runtime tables bank; boot jumps here on A <> $11.
    Then save_check (called by the boot on a Color): the release checklist's save validation."""
    t, code = font_tiles(''.join(DMG_MSG))
    mp = bytearray(18 * 32)
    top = (18 - 2 * len(DMG_MSG) + 1) // 2
    for k, line in enumerate(DMG_MSG):
        r = text_row(line, code); o = (top + 2 * k) * 32; mp[o:o + 20] = r
    db = lambda b: '\n'.join('    db ' + ', '.join('$%02X' % v for v in b[i:i + 16]) for i in range(0, len(b), 16))
    st, scode = font_tiles(''.join(SAVE_MSG) + ''.join(SAVE_FILE % n for n in (1, 2, 3)))
    sm = bytearray(18 * 32)
    for k, line in enumerate(SAVE_MSG):
        if line: o = (SAVE_ROW0 + k) * 32; sm[o:o + 20] = text_row(line, scode)
    sf = b''.join(text_row(SAVE_FILE % n, scode) for n in (1, 2, 3))
    return """section bank RT_TABLES, $7000
dmg_msg:    ldh a, [rLY]                    ; (the boot ROM leaves the LCD on: off in the vblank)
            cp 144
            jr c, dmg_msg
            xor a
            ldh [rLCDC], a
            ld hl, DMSG_T
            ld de, $8000
            ld bc, %d
            call smcopy
            ld hl, $9800
            ld bc, $400
            call smclr
            ld hl, DMSG_M
            ld de, $9800
            ld bc, %d
            call smcopy
            xor a
            ldh [rSCX], a
            ldh [rSCY], a
            ldh [rIE], a
            ld a, $E4
            ldh [$FF47], a                  ; BGP: colour 3 black, 0 white
            ld a, $91                       ; LCD on, BG on, tiles $8000, map $9800
            ldh [rLCDC], a
.h:         halt                            ; (no interrupt enabled: stays here, low power)
            jr .h
smcopy:     ld a, [hl+]                     ; HL -> DE, BC bytes
            ld [de], a
            inc de
            dec bc
            ld a, b
            or c
            jr nz, smcopy
            ret
smclr:      xor a                           ; HL, BC bytes
            ld [hl+], a
            dec bc
            ld a, b
            or c
            jr nz, smclr
            ret

; save data check (boot, LCD off, interrupts off, VRAM clear): each save slot ($A400 /
; $A800 / $AC00, 1KB) whose "initialised" byte (+$19) is $5A must sum to $FF (the game's own
; test, 3D:AE97); a slot that does not is damaged. Damaged slots: a message screen until the A
; Button is pressed, then their "initialised" byte cleared (the game shows them empty). Cart
; RAM is on only during the reads and the clear. No damaged slot: nothing shown.
save_check: ld a, $0A
            ld [MBC5_RAMG], a
            ld c, 0                         ; C = damaged slots (bit 0-2)
            ld e, 1                         ; E = this slot's bit
            ld h, $A4
.sl:        ld l, $19
            ld a, [hl]
            cp $5A
            jr nz, .nx
            ld l, 0
            ld d, 4
            ld b, h
            xor a
.sum:       add a, [hl]
            inc l
            jr nz, .sum
            inc h
            dec d
            jr nz, .sum
            ld h, b
            inc a
            jr z, .nx
            ld a, c
            or e
            ld c, a
.nx:        ld a, h
            add a, 4
            ld h, a
            sla e
            bit 3, e
            jr z, .sl
            xor a
            ld [MBC5_RAMG], a
            ld a, c
            and a
            ret z
            push bc
            ld hl, SMSG_T                   ; the message
            ld de, $8000
            ld bc, %d
            call smcopy
            ld hl, SMSG_M
            ld de, $9800
            ld bc, %d
            call smcopy
            pop bc
            push bc
            ld hl, SMSG_F                   ; "File n is damaged." for each damaged slot
            ld de, $9800 + %d * 32
.fl:        srl c
            jr nc, .fs
            push bc
            ld bc, 20
            call smcopy
            pop bc
            ld a, e
            add a, 12
            ld e, a
            jr nc, .fn
            inc d
            jr .fn
.fs:        ld a, l
            add a, 20
            ld l, a
            jr nc, .fn
            inc h
.fn:        ld a, c
            and a
            jr nz, .fl
            ld a, $80                       ; BG palette 0: white, greys, black
            ldh [rBCPS], a
            ld hl, SMSG_P
            ld b, 8
.pl:        ld a, [hl+]
            ldh [rBCPD], a
            dec b
            jr nz, .pl
            ld a, $91                       ; LCD on, BG on, tiles $8000, map $9800
            ldh [rLCDC], a
            ld a, $10                       ; buttons: all released, then A pressed, then released
            ldh [rP1], a
.w1:        call .pad
            jr nz, .w1
.w2:        call .pad
            bit 0, a
            jr z, .w2
.w3:        call .pad
            jr nz, .w3
            pop bc
            ld a, $0A                       ; clear the damaged slots' "initialised" byte
            ld [MBC5_RAMG], a
            ld h, $A4
            ld l, $19
.cl:        srl c
            jr nc, .cn
            ld [hl], 0
.cn:        ld a, h
            add a, 4
            ld h, a
            ld a, c
            and a
            jr nz, .cl
            xor a
            ld [MBC5_RAMG], a
            ld a, $30
            ldh [rP1], a
.wv:        ldh a, [rLY]                    ; LCD off in the vblank
            cp 144
            jr c, .wv
            xor a
            ldh [rLCDC], a
            ld hl, $8000                    ; VRAM bank 0 clear again
            ld bc, $2000
            jp smclr
.pad:       ld b, 4                         ; A = pressed buttons (1 = pressed), Z: none;
.pd:        ldh a, [rLY]                    ;   read once a frame, a few times over
.pw:        ldh a, [rLY]
            cp 144
            jr nz, .pw
.pq:        ldh a, [rLY]
            cp 144
            jr z, .pq
            dec b
            jr nz, .pd
            ldh a, [rP1]
            ldh a, [rP1]
            ldh a, [rP1]
            cpl
            and $0F
            ret
DMSG_T:
%s
DMSG_M:
%s
SMSG_T:
%s
SMSG_M:
%s
SMSG_F:
%s
SMSG_P:     db $FF, $7F, $B5, $56, $4A, $29, $00, $00
""" % (len(t), len(mp), len(st), len(sm), SAVE_ROW0 + 2, db(t), db(bytes(mp)), db(st), db(bytes(sm)), db(sf))


def cv_glyph_src():
    """condensed-name glyphs for the native line printer (native.s far_cvr): CV_W ($6000, runtime
    tables bank) = width per text code (0: not condensed, e.g. icons), CV_G ($6100) = 8 rows
    per code, left-aligned (tools/latin_font.py COND, as the English job tiles; digits from the
    normal letters, trimmed; descenders one row down; the space 2 px)"""
    sys.path.insert(0, os.path.join(ROOT, 'tools'))
    from latin_font import COND, G, DESC
    import importlib.util
    spec = importlib.util.spec_from_file_location('ff3ins', os.path.join(ROOT, 'tools', 'ff3', 'insert.py'))
    ins = importlib.util.module_from_spec(spec); spec.loader.exec_module(ins)
    W = bytearray(256); R = bytearray(256 * 8)
    def put(code, rows, desc):
        w = len(rows[0])
        rr = (['.' * w] + list(rows)) if desc else (list(rows) + ['.' * w])
        rr = (rr + ['.' * w] * 8)[:8]
        W[code] = w
        for y, r in enumerate(rr): R[code * 8 + y] = sum(0x80 >> x for x, v in enumerate(r) if v == '#')
    for ch, code in ins.ENC.items():
        if ch == ' ': continue
        if ch in COND: put(code, COND[ch], ch in DESC)
        elif ch in G:
            rows = list(G[ch]); cols = [x for x in range(len(rows[0])) if any(r[x] == '#' for r in rows)]
            put(code, [r[cols[0]:cols[-1] + 1] for r in rows], ch in DESC)
    W[0xFF] = 2                                            # space (empty rows)
    lig = ['#.....', '#.....', '..###.', '.#....', '..##..', '....#.', '.###..']   # "'s" (code $C9)
    put(ins.LIG_S, lig, False)
    db = lambda b: '\n'.join('    db ' + ', '.join('$%02X' % v for v in b[i:i + 16]) for i in range(0, len(b), 16))
    return 'section bank RT_TABLES, $6000\nCV_W:\n%s\nCV_G:\n%s\n' % (db(W), db(R))


def oam_attr_src():
    """OAM_ATTR ($3D00, bank 0): NES sprite attribute byte -> CGB OAM attributes (palette
    bits 0-1, priority bit 5 -> bit 7, horizontal / vertical flip bits 6 / 7 -> bits 5 / 6);
    the runtime ORs in the VRAM bank of the sprite pattern table"""
    t = []
    for a in range(256):
        t.append((a & 3) | ((a & 0x20) << 2) | ((a & 0x40) >> 1) | ((a & 0x80) >> 1))
    out = 'section bank 0, $3C00\nOAM_ATTR:\n'        # $3C00: pattern table 0, $3D00: table 1 (VRAM bank 1)
    for bank in (0, 8):
        out += ''.join('    db %s\n' % ', '.join(str(v | bank) for v in t[k:k + 16]) for k in range(0, 256, 16))
    return out


def main():
    args = sys.argv[1:]
    opt = {'--cov': os.path.join(ROOT, 'build', 'ff3', 'cov'),
           '--out': None, '--nes': None}
    pos = []; gb = False; release = False
    while args:
        a = args.pop(0)
        if a == '--gb': gb = True
        elif a == '--release': release = True
        elif a in opt: opt[a] = args.pop(0)
        else: pos.append(a)
    opt['--out'] = opt['--out'] or os.path.join(ROOT, 'build', 'ff3_gb.gbc' if gb else 'ff3_en.gbc')
    src = pos[0] if pos else os.path.join(ROOT, 'roms', 'Final Fantasy III (Japan).nes')
    out_dir = os.path.dirname(os.path.abspath(opt['--out']))
    os.makedirs(out_dir, exist_ok=True)
    nes = opt['--nes'] or nes_english(src, out_dir)
    if gb and not opt['--nes']:              # the GB-layout NES ROM (tools/gb3/layout.py)
        import layout
        d, _, log = layout.apply(open(nes, 'rb').read())
        nes = os.path.join(out_dir, 'ff3_gb.nes')
        open(nes, 'wb').write(d)
        print('layout: %d patches -> %s' % (len(log), nes))
    srcdir = os.path.join(ROOT, 'build', 'ff3', 'src_gb' if gb else 'src_en')
    source_base(src, nes, srcdir, gb)
    import translate                         # natives found in the ExRAM image (the English
    img = open(nes, 'rb').read()[16 + 64 * 0x2000:16 + 64 * 0x2000 + 0x400]   #   patch's code)
    k = img.find(bytes.fromhex('200AF4A200BDA0078D0720'))   # h_flush .one: JSR $F40A / LDX #0 / LDA $07A0,X / STA $2007
    if k >= 0 and not os.environ.get('GB3_NO_NATIVE_TEXT'): translate.FF3.ext[('ex', 0x5C00 + k)] = ('nat_h1', 'NZC')
    else: print('  h_flush not found: one-row lines through $2007')
    if os.environ.get('GB3_NO_NATIVE_SOUND'):   # (dev comparison: the NES output routines translated)
        for a in (0x80AB, 0x8030, 0x81C3): translate.FF3.ext.pop(('b36', a), None)
    covs = sorted(glob.glob(os.path.join(opt['--cov'], 'c*.bin')))   # optional: stack-trick flags
    t = time.time()
    cm = CodeMap(nes, srcdir, covs).build()
    rc = Recompiler(cm)
    prg = open(nes, 'rb').read()[16:]
    from ff3code import SPACES
    for k, code in list(getattr(rc.g, 'idiom_code', {}).items()):
        base, off, size = SPACES[k[0]]
        o = off + k[1] - base
        if prg[o:o + len(code)] != code or k not in cm.insns:
            print('  idiom %s:%04X: code not found, not used' % k); rc.g.idioms.pop(k, None)
    prog, bank_of, banks = emit_program(rc)
    rt = '\n'.join(open(os.path.join(HERE, 'rt', f)).read() for f in RT_FILES)
    if release:                              # release build: no test hooks (docs/gb-release-checklist.md 4)
        import re
        rt, n = re.subn(r'^;@test\{.*?^;@test\}[^\n]*\n', '', rt, flags=re.S | re.M)
        assert n >= 3
        rt = re.sub(r'^;@rel ', '', rt, flags=re.M)        # release-only lines
        for v in ('GB3_TEST_MINI', 'FF3_TEST_GOBLIN'):
            if os.environ.get(v): raise SystemExit('release build with test switch %s set' % v)
    # (the cross-bank stubs continue bank 0 right after the runtime, up to OAM_ATTR at $3C00)
    head, sep, rest = prog.partition('section bank DYN_BANK')
    stubs = head.split('\n', 1)[1] if head.startswith('section bank 0') else head
    src_all = rt + '\n' + stubs + '\n' + gb1.nes_rgb_src() + '\n' + oam_attr_src() + '\n' + dmg_msg_src() + '\n' + cv_glyph_src() + '\n' + sep + rest
    open(opt['--out'] + '.s', 'w').write(src_all)
    print('N-branch peephole: %d' % getattr(rc, 'n_npeep', 0))
    print('translated: %d instructions, %d code banks (%.1fs), %d dynamic targets'
          % (len(rc.insns), len(banks), time.time() - t, rc.n_dyn))
    t = time.time()
    # GB layout ROM (tools/gb3/layout.py)? natives that follow patched routines check it
    o = 16 + 0x34 * 0x2000 + (0x966A & 0x1FFF)
    bconv_gb = 1 if open(nes, 'rb').read()[o:o + 2] == bytes.fromhex('A900') else 0
    r = asm(src_all, syms={'DATA': DATA, 'RT_TABLES': RT_TABLES, 'CODE_BANK0': CODE0, 'RESET_NES': rc.g.reset[1],
                           'BCONV_GB': bconv_gb})
    print('assembled (%.1fs)' % (time.time() - t))
    for n in range(64):                                    # NES 8KB banks 2n, 2n+1
        r.banks[DATA + n] = bytearray(prg[2 * n * 0x2000:(2 * n + 2) * 0x2000])
    top = max(r.banks) + 1
    size = 2
    while size < top: size *= 2
    # cart RAM: the save slots in bank 0 ($A000-$AFFF); dev builds also read test pads from bank 3
    rom = make_rom(r.banks, 'FF3 ENGLISH', cart_type=0x1B, rom_banks=size, ram_size_code=0x02 if release else 0x03,
                   cgb=0xC0)
    open(opt['--out'], 'wb').write(rom)
    open(os.path.splitext(opt['--out'])[0] + '.sym', 'w').write(r.sym_file())
    print('wrote %s: %d KB, bank 0 used %d bytes' % (opt['--out'], len(rom) // 1024, len(r.banks[0])))
    w = {}
    for x in rc.warn: w.setdefault(x.split(' at ')[0].split(' from ')[0][:40], []).append(x)
    open(opt['--out'] + '.warn', 'w').write('\n'.join(rc.warn) + '\n')
    for k, v in sorted(w.items(), key=lambda kv: -len(kv[1])):
        print('  warn %-42s x%d  e.g. %s' % (k, len(v), v[0][-40:]))


if __name__ == '__main__':
    main()
