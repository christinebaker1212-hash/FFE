"""Build the native FF3 Game Boy Color ROM (docs/ff3-gb-status.md) from the English NES ROM the
existing pipeline makes (tools/ff3_mmc5/build.py, then tools/ff3/insert.py). Game data is read
from that ROM here, at build time; nothing game-specific is kept in the repository.

usage: python3 tools/gb3n/build.py [--nes build/ff3_en.nes] [--out build/ff3n.gbc] [--map P]"""
import os, sys, hashlib
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..', '..')
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..', 'gb'))
from asm_sm83 import asm, make_rom
import tiles, data

ROM_BANKS = 128             # 2 MB (sized to the game later)
MAP_BANK = 2                # the test map's data bank (src/field.s)
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
    return ('section bank 0, $1000\nC_TILES:\n' + db(b''.join(tiles.tileset())) +
            'C_SCR_CGBONLY:\n' + db(tiles.screen(tiles.CGB_ONLY), 20) +
            'C_SCR_TEST:\n' + db(test, 20) + 'C_PAL0:\n' + db(pal0))


def map_bank(rom, p):
    """one map's data bank for src/field.s, from the user's ROM"""
    m = data.Map(rom, p)
    b = bytearray(b'\xff' * 0x4000)
    til = m.bg_tiles()
    b[0:0x1000] = b''.join(tiles.gb(til[16 * i:16 * i + 16]) for i in range(256))
    b[0x1000:0x1200] = b''.join(m.quad)
    b[0x1200:0x1280] = bytes(a & 3 for a in m.attr)
    b[0x1300:0x1320] = b''.join(data.rgb555(c).to_bytes(2, 'little') for pal in m.bg_palettes() for c in pal)
    b[0x1400:0x1800] = m.tilemap()
    b[0x1800:0x1803] = bytes([m.props[0] & 31, m.props[1] & 31, m.props[3] & 0x7F])
    b[0x1880:0x1900] = bytes(p1 for p1, p2 in m.tprop)
    b[0x1900:0x1980] = bytes(p2 for p1, p2 in m.tprop)
    chr_ = rom.map_char_tiles(0)                     # (the party's first member: Onion Knight)
    b[0x1A00:0x1B00] = b''.join(tiles.gb(chr_[16 * i:16 * i + 16]) for i in range(16))
    b[0x1B00:0x1B10] = b''.join(data.rgb555(c).to_bytes(2, 'little') for pal in rom.char_palettes(0, 0) for c in pal)
    b[0x1B10:0x1B50] = rom.player_poses()
    return bytes(b)


def main():
    a = sys.argv[1:]
    nes = a[a.index('--nes') + 1] if '--nes' in a else os.path.join(ROOT, 'build', 'ff3_en.nes')
    out = a[a.index('--out') + 1] if '--out' in a else os.path.join(ROOT, 'build', 'ff3n.gbc')
    test_map = int(a[a.index('--map') + 1]) if '--map' in a else 10
    raw = open(nes, 'rb').read()
    if hashlib.sha1(raw).hexdigest() != EN_SHA1:
        print('note: %s is not the expected English FF3 NES ROM (SHA-1 %s)' % (nes, EN_SHA1))
    src = (open(os.path.join(HERE, '..', 'gb', 'rt', 'hw.s')).read() + '\n' +
           'MAP_BANK = %d\nTEST_MAP = %d\n' % (MAP_BANK, test_map) +
           open(os.path.join(HERE, 'src', 'main.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'field.s')).read() + '\n' + own_data())
    r = asm(src)
    banks = dict(r.banks)
    rom = data.Rom(nes)
    assert MAP_BANK not in banks
    banks[MAP_BANK] = map_bank(rom, test_map)
    img = make_rom(banks, 'FF3 NATIVE', cart_type=0x1B, rom_banks=ROM_BANKS,
                   ram_size_code=RAM_CODE, sgb=False, cgb=0xC0)
    open(out, 'wb').write(img)
    base = os.path.splitext(out)[0]
    open(base + '.sym', 'w').write(r.sym_file())
    print('wrote %s (%d KB), bank 0 used %d bytes' % (out, len(img) // 1024, len(r.banks[0])))


if __name__ == '__main__':
    main()
