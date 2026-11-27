"""Build the native FF3 Game Boy Color ROM (docs/ff3-gb-status.md) from the English NES ROM the
existing pipeline makes (tools/ff3_mmc5/build.py, then tools/ff3/insert.py). Game data is read
from that ROM here, at build time; nothing game-specific is kept in the repository.

usage: python3 tools/gb3n/build.py [--nes build/ff3_en.nes] [--out build/ff3n.gbc] [--map M[,WORLD[,X,Y]]]"""
import os, sys, hashlib
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..', '..')
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..', 'gb'))
from asm_sm83 import asm, make_rom
import tiles, data, text

BATTLE_SRC = ['batlib.s', 'batcore.s', 'batmagic.s', 'batinit.s', 'batequip.s', 'batflow.s', 'batvict.s']
ROM_BANKS = 128             # 2 MB (sized to the game later)
RAM_CODE = 0x03             # 32 KB cart RAM (4 banks, as retail MBC5 games: docs/gb-lessons.md)
EN_SHA1 = '4a7f1ae4c89305cf161aa3d78fd4416548663f99'   # build/ff3_en.nes (patches/README.md)


def db(data, per=16):
    return ''.join('            db ' + ', '.join('$%02X' % b for b in data[i:i + per]) + '\n'
                   for i in range(0, len(data), per))


def own_data():
    """our own tiles / screens (no game data) in bank 0"""
    rgb = lambda r, g, b: (r | g << 5 | b << 10).to_bytes(2, 'little')
    pal0 = rgb(0, 0, 0) + rgb(21, 21, 21) + rgb(10, 10, 10) + rgb(31, 31, 31)
    test = tiles.screen([(2, None, 'FINAL FANTASY III'), ('frame', 1, 5, 18, 7),
                         (7, None, 'Native engine'), (9, None, 'Game Boy Color')])
    return ('section bank %d, $4000\nC_TILES:\n' % B_OWN + db(b''.join(tiles.tileset())) +
            'C_SCR_CGBONLY:\n' + db(tiles.screen(tiles.CGB_ONLY), 20) +
            'C_SCR_TEST:\n' + db(test, 20) + 'C_PAL0:\n' + db(pal0) +
            'section bank %d, $6000\nC_WFONT:\n' % B_OWN + db(b''.join(tiles.tileset(fg=3, bg=2)[:128])) +
            'C_FF3ASC:\n' + db(tiles.ff3_to_ascii()))


B_MAPINFO, B_MAPAUX, B_EVENTS, B_CHARS, B_TMAP0, B_SUB0, B_COMMON = 3, 4, 5, 6, 8, 12, 17
B_NPCS, B_NPCGFX, B_OWN, B_TEXT, B_SCRIPT, B_FIELD = 18, 19, 20, 21, 28, 29
B_WORLD0, B_WINFO, B_WGFX = 32, 48, 49
B_SND0 = 50                 # 50-53: NES bank $36 at $4000, song bank $37 / $38 / $39 / $09 at $6000
B_BAT, B_BDAT, B_BDAT2, B_BDAT3 = 54, 55, 56, 57   # battle code; NES $30 + $31; $2E + $01; $38 + $39
B_BAT2 = 58                 # battle flow code


def field_banks(rom):
    """the field's data banks (layouts: the top of src/field.s), all from the user's ROM"""
    banks = {}
    def blank(): return bytearray(b'\xff' * 0x4000)
    gbt = lambda nes: b''.join(tiles.gb(nes[16 * i:16 * i + 16]) for i in range(len(nes) // 16))
    b = blank()                                          # map info
    b[0x0000:0x2000] = rom.at(0x02 * data.B8, 0x2000)
    for ts in range(data.TILESET_COUNT):
        b[0x2000 + 0x400 * ts:0x2400 + 0x400 * ts] = data.tileset_block(rom, ts)
    base, typ, first = data.trigger_tables(rom)
    b[0x3C00:0x3C80] = base; b[0x3C80:0x3CA0] = typ; b[0x3CA0:0x3CC0] = first
    b[0x3CC0:0x3CC4] = data.window_colours(rom)
    b[0x3D00:0x3D80] = b''.join(data.rgb555(c).to_bytes(2, 'little') for c in range(64))
    banks[B_MAPINFO] = b
    b = blank()                                          # map aux tables
    b[0x0000:0x0100] = rom.rd(0x00, 0x9100, 256)
    b[0x0100:0x0200] = rom.rd(0x00, 0x9200, 256)
    b[0x0200:0x0300] = rom.rd(0x00, 0x9300, 256)
    b[0x0300:0x0500] = rom.rd(0x00, 0x8A00, 512)
    b[0x0500:0x0700] = rom.rd(0x00, 0x8C00, 512)
    b[0x0700:0x0720] = rom.rd(0x00, 0x9670, 32)
    b[0x0720:0x0788] = rom.rd(0x00, 0x9690, 104)
    b[0x0C00:0x0C40] = rom.rd(0x00, 0x8880, 64)
    b[0x0C40:0x0C80] = rom.rd(0x00, 0x88C0, 64)
    b[0x0D00:0x0D40] = rom.player_poses()
    tm = {}                                              # tilemaps: streams packed per bank
    bank, at = B_TMAP0, 0
    for tid in sorted(set(rom.rd(0x00, 0x8A00, 512))):
        st = data.tilemap_stream(rom, tid)
        if at + len(st) > 0x4000: bank, at = bank + 1, 0
        assert bank < B_SUB0, 'tilemaps overflow'
        banks.setdefault(bank, blank())[at:at + len(st)] = st
        b[0x0800 + 3 * tid:0x0803 + 3 * tid] = bytes([bank, (0x4000 + at) & 0xFF, (0x4000 + at) >> 8])
        at += len(st)
    per = 0x4000 // (16 * data.SUBSET_TILES)             # graphics subsets
    for sub in range(max(rom.rd(0x00, 0x8C00, 512)) + 1):
        bk, k = B_SUB0 + sub // per, sub % per
        assert bk < B_COMMON, 'subsets overflow'
        a = 16 * data.SUBSET_TILES * k
        banks.setdefault(bk, blank())[a:a + 16 * data.SUBSET_TILES] = gbt(data.subset_tiles(rom, sub))
        b[0x0B00 + 3 * sub:0x0B03 + 3 * sub] = bytes([bk, (0x4000 + a) & 0xFF, (0x4000 + a) >> 8])
    banks[B_MAPAUX] = b
    b = blank(); b[0:0x2000] = rom.at(0x10 * data.B8, 0x2000); banks[B_EVENTS] = b
    b = blank(); b[0:0x4000] = gbt(rom.at(0x0E * data.B8, 0x4000)); banks[B_CHARS] = b
    b = blank(); b[0:144 * 16] = gbt(rom.rd(0x0D, 0xB700, 144 * 16)); banks[B_COMMON] = b
    banks[B_SCRIPT] = bytearray(rom.at(0x2C * data.B8, 0x4000))   # NES $2C/$2D: npc lists, scripts
    b = blank()                                          # people: tables, init
    b[0x2000:0x2200] = rom.rd(0x00, 0x9400, 512)
    b[0x2200:0x2400] = rom.rd(0x01, 0xBE00, 512)
    b[0x2400:0x2500] = rom.rd(0x3B, 0xB41A, 256)
    si = data.sram_init_data(rom)
    b[0x2500:0x2540] = si['npcsw']
    b[0x2540:0x2548] = si['base']; b[0x2548:0x2550] = si['mp']; b[0x2550:0x2552] = si['hp']
    b[0x2560:0x2574] = si['stats']; b[0x2580:0x2590] = si['equip']
    b[0x2590:0x2592] = bytes([si['wmx'], si['wmy']])
    b[0x2A00:0x2C00] = rom.rd(0x01, 0x9C00, 512)        # chest contents (world 0 / others)
    gfx = blank(); at = 0
    for g in range(256):
        if g < 0x40:
            ent = (B_CHARS, 0x4000 + 0x100 * g)
        else:
            gfx[at:at + 0x100] = gbt(data.npc_gfx_block(rom, g)); ent = (B_NPCGFX, 0x4000 + at); at += 0x100
            if at >= 0x4000: break
        b[0x2700 + 3 * g:0x2703 + 3 * g] = bytes([ent[0], ent[1] & 0xFF, ent[1] >> 8])
    banks[B_NPCS] = b; banks[B_NPCGFX] = gfx
    for wi, w in enumerate(data.WORLD_MAPS):             # world maps unpacked: 4 banks each
        rows = data.world_rows(rom, w)
        for k in range(4):
            banks[B_WORLD0 + 4 * wi + k] = bytearray(b''.join(rows[64 * k:64 * k + 64]))
    b = blank()                                          # world tilesets, palettes, entrances
    for w in range(5):
        b[0x400 * w:0x400 * w + 0x400] = data.world_tileset(rom, w)
        b[0x1400 + 16 * w:0x1410 + 16 * w] = bytes(c for pal in data.world_palettes(rom, w) for c in pal)
    b[0x1500:0x1540] = rom.rd(0x00, 0x8800, 64)
    b[0x1540:0x1580] = rom.rd(0x00, 0x8840, 64)
    banks[B_WINFO] = b
    b = blank()                                          # world graphics: 256 tiles per pair
    for k, w in enumerate((0, 2, 4)):
        b[0x1000 * k:0x1000 * k + 0x1000] = gbt(data.world_tiles(rom, w))
    banks[B_WGFX] = b
    banks[B_BDAT] = bytearray(rom.at(0x30 * data.B8, 0x4000))      # battle data: NES $30/$31 as mapped
    banks[B_BDAT3] = bytearray(rom.at(0x38 * data.B8, 0x4000))
    banks[B_BDAT2] = bytearray(rom.at(0x2E * data.B8, 0x2000) + rom.at(0x01 * data.B8, 0x2000))
    for k, sb in enumerate((0x37, 0x38, 0x39, 0x09)):     # sound: driver tables + song data
        banks[B_SND0 + k] = bytearray(rom.at(0x36 * data.B8, 0x2000) + rom.at(sb * data.B8, 0x2000))
    return banks


NES_NOISE = [4, 8, 16, 32, 64, 96, 128, 160, 202, 254, 380, 508, 762, 1016, 2034, 4068]


def sound_data():
    """bank 0 tables: NES period -> GB frequency (pulses and triangle alike: 2048 - 1.1717 (p + 1)),
    NES noise period index (+ 16 for the short mode) -> NR43"""
    import math
    ft = []
    for p in range(2048):
        x = int(round(2048 - 131072.0 * 16 * (p + 1) / 1789773.0))
        ft.append(max(0, min(2047, x)))
    nt = []
    for mode in (0, 1):
        for per in NES_NOISE:
            f = 1789773.0 / per
            best = min(((abs(math.log(262144.0 / ((r or 0.5) * 2 ** sh)) - math.log(f)), sh << 4 | r)
                        for sh in range(14) for r in range(8)))
            nt.append(best[1] | (8 if mode else 0))
    lines = ['section bank 0, $3000', 'snd_ftab:']
    for i in range(0, 2048, 8):
        lines.append('    dw ' + ', '.join('$%04X' % v for v in ft[i:i + 8]))
    lines.append('section bank 0, $2FC0')
    lines.append('snd_ntab:')
    lines.append('    db ' + ', '.join('$%02X' % v for v in nt))
    return '\n'.join(lines) + '\n'


# battle code macros (src/bat*.s): pointer accesses as FF3's (zp),Y. %LDZ zp, off: A = [[BZ+zp] + off]
# (HL left at the byte); %STZ zp, off: the same address = A (B used); %PZ zp, off: HL = the address
# (%STZ / %PZ: an address in FF3's ROM range, GB $E000+, goes to a dummy: the NES ignores such writes);
# %LDX table: A = [table + X] with X in [BZ_X]; %MOVZ dst, src: a 16-bit pointer copy in BZ
# tables of FF3's code banks filled from the user's ROM after assembling: label -> (NES bank, address, n)
ROMDATA = {
    'w_songs': (0x3B, 0xA027, 32),       # world map songs by world and vehicle
    'refl_bits': (0x31, 0xBB0E, 11),     # spells that Reflect bounces
}

MACROS = {
    'PZ': ['ld hl, BZ + ({0})', 'ld a, [hl+]', 'ld h, [hl]', 'add {1}', 'ld l, a', 'ld a, h', 'adc 0', 'ld h, a',
           'call wchk'],
    'LDZ': ['ld hl, BZ + ({0})', 'ld a, [hl+]', 'ld h, [hl]', 'add {1}', 'ld l, a', 'ld a, h', 'adc 0', 'ld h, a',
            'ld a, [hl]'],
    'STZ': ['ld b, a', 'ld hl, BZ + ({0})', 'ld a, [hl+]', 'ld h, [hl]', 'add {1}', 'ld l, a', 'ld a, h', 'adc 0',
            'ld h, a', 'call wchk', 'ld [hl], b', 'ld a, b'],
    'MOVZ': ['ld a, [BZ + ({1})]', 'ld [BZ + ({0})], a', 'ld a, [BZ + ({1}) + 1]', 'ld [BZ + ({0}) + 1], a'],
}


def expand(src):
    import re
    out = []
    for line in src.split('\n'):
        m = re.match(r'^(\s*(?:[.\w]+:)?\s*)%(\w+)\s*(.*?)\s*(;.*)?$', line)
        if m and m.group(2) in MACROS:
            args = [a.strip() for a in m.group(3).split(',')] if m.group(3) else []
            body = MACROS[m.group(2)]
            out.append(m.group(1) + body[0].format(*args))
            out += ['            ' + b.format(*args) for b in body[1:]]
        else:
            out.append(line)
    return '\n'.join(out)


def main():
    a = sys.argv[1:]
    nes = a[a.index('--nes') + 1] if '--nes' in a else os.path.join(ROOT, 'build', 'ff3_en.nes')
    out = a[a.index('--out') + 1] if '--out' in a else os.path.join(ROOT, 'build', 'ff3n.gbc')
    mp = (a[a.index('--map') + 1] if '--map' in a else '0').split(',')   # --map M[,WORLD[,X,Y]]
    mp = [int(v) for v in mp] + [0, 255, 255][len(mp) - 1:]
    test_map, test_world, test_x, test_y = mp[:4]
    raw = open(nes, 'rb').read()
    tbanks, tlay, tlast = text.banks(B_TEXT)
    assert tlast < B_SCRIPT, 'text banks overflow'
    text_defs = ''.join('T_%s = $%04X\n' % (k.upper(), v) for k, v in tlay.items())
    if hashlib.sha1(raw).hexdigest() != EN_SHA1:
        print('note: %s is not the expected English FF3 NES ROM (SHA-1 %s)' % (nes, EN_SHA1))
    src = (open(os.path.join(HERE, '..', 'gb', 'rt', 'hw.s')).read() + '\n' +
           'START_MAP = %d\nSTART_WORLD = %d\nSTART_X = %d\nSTART_Y = %d\n' % (test_map, test_world, test_x, test_y) +
           'B_MAPINFO = %d\nB_MAPAUX = %d\nB_EVENTS = %d\nB_CHARS = %d\nB_COMMON = %d\n' % (
               B_MAPINFO, B_MAPAUX, B_EVENTS, B_CHARS, B_COMMON) +
           'B_NPCS = %d\nB_NPCGFX = %d\nB_OWN = %d\nB_TEXT = %d\nB_SCRIPT = %d\nB_FIELD = %d\n' % (
               B_NPCS, B_NPCGFX, B_OWN, B_TEXT, B_SCRIPT, B_FIELD) +
           'B_WORLD0 = %d\nB_WINFO = %d\nB_WGFX = %d\nB_SND0 = %d\n' % (B_WORLD0, B_WINFO, B_WGFX, B_SND0) +
           'B_BAT = %d\nB_BDAT = %d\nB_BDAT2 = %d\nB_BDAT3 = %d\nB_BAT2 = %d\n' % (B_BAT, B_BDAT, B_BDAT2, B_BDAT3, B_BAT2) + text_defs +
           open(os.path.join(HERE, 'src', 'main.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'field.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'npc.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'text.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'event.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'world.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'sound.s')).read() + '\n' +
           ''.join(open(os.path.join(HERE, 'src', f)).read() + '\n' for f in BATTLE_SRC) + sound_data() + own_data())
    if os.environ.get('GB3N_TEST'):              # test builds: tools/gb3n/test (never a release)
        src = src.replace('.nw:        call map_enter', '.nw:        jp test_loop')
        src += open(os.path.join(HERE, 'src', 'test.s')).read() + '\n'
    import re                                    # (constants from every file first)
    lines = expand(src).split('\n')
    is_def = lambda l: re.match(r'^[A-Za-z_]\w*\s+=', l)
    src = '\n'.join([l for l in lines if is_def(l)] + [l for l in lines if not is_def(l)])
    import asm_sm83
    asm_sm83.RAM_SECTIONS[:] = []
    r = asm(src)
    secs = sorted(set((a, b) for a, b, _ in asm_sm83.RAM_SECTIONS if b > a))   # (RAM sections may
    for (a0, a1), (b0, b1) in zip(secs, secs[1:]):                        #   not overlap)
        assert a1 <= b0, 'RAM sections overlap: %04X-%04X and %04X-%04X' % (a0, a1, b0, b1)
    banks = dict(r.banks)
    if os.environ.get('GB3N_GAPS'):              # free runs (32+ bytes) of a code bank: GB3N_GAPS=29
        gb = int(os.environ['GB3N_GAPS']); run = []
        for off in range(0x4000 + 1):
            if off < 0x4000 and not r.claimed.get((gb, off)): run.append(off)
            else:
                if len(run) >= 32: print('bank %d free: $%04X-$%04X (%d)' % (gb, run[0] + (0x4000 if gb else 0), run[-1] + (0x4000 if gb else 0), len(run)))
                run = []
    rom = data.Rom(nes)
    for name, (nb, addr, n) in ROMDATA.items():
        if name not in r.labels: continue
        gb, ga = r.label_bank[name], r.labels[name]
        off = ga - (0x4000 if gb else 0)
        banks[gb] = bytearray(banks[gb])
        banks[gb][off:off + n] = rom.rd(nb, addr, n)
    for k, v in tbanks.items():
        assert k not in banks, 'bank %d used twice' % k
        banks[k] = v
    for k, v in field_banks(rom).items():
        assert k not in banks, 'bank %d used twice' % k
        banks[k] = v
    img = make_rom(banks, 'FF3 NATIVE', cart_type=0x1B, rom_banks=ROM_BANKS,
                   ram_size_code=RAM_CODE, sgb=False, cgb=0xC0)
    open(out, 'wb').write(img)
    base = os.path.splitext(out)[0]
    open(base + '.sym', 'w').write(r.sym_file())
    print('wrote %s (%d KB), bank 0 used %d bytes' % (out, len(img) // 1024, len(r.banks[0])))


if __name__ == '__main__':
    main()
