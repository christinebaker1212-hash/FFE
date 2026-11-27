"""Build the native FF3 Game Boy Color ROM (docs/ff3-gb-status.md) from the English NES ROM the
existing pipeline makes (tools/ff3_mmc5/build.py, then tools/ff3/insert.py). Game data is read
from that ROM here, at build time; nothing game-specific is kept in the repository.

usage: python3 tools/gb3n/build.py [--nes build/ff3_en.nes] [--out build/ff3n.gbc] [--release]"""
import os, sys, hashlib
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..', '..')
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..', 'gb'))
from asm_sm83 import asm, make_rom
import tiles

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
    return ('section bank 0, $1000\nC_TILES:\n' + db(b''.join(tiles.tileset())) +
            'C_SCR_CGBONLY:\n' + db(tiles.screen(tiles.CGB_ONLY), 20) +
            'C_SCR_TEST:\n' + db(test, 20) + 'C_PAL0:\n' + db(pal0))


def main():
    a = sys.argv[1:]
    nes = a[a.index('--nes') + 1] if '--nes' in a else os.path.join(ROOT, 'build', 'ff3_en.nes')
    out = a[a.index('--out') + 1] if '--out' in a else os.path.join(ROOT, 'build', 'ff3n.gbc')
    rom = open(nes, 'rb').read()
    if hashlib.sha1(rom).hexdigest() != EN_SHA1:
        print('note: %s is not the expected English FF3 NES ROM (SHA-1 %s)' % (nes, EN_SHA1))
    src = (open(os.path.join(HERE, '..', 'gb', 'rt', 'hw.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'main.s')).read() + '\n' + own_data())
    r = asm(src)
    img = make_rom(dict(r.banks), 'FF3 NATIVE', cart_type=0x1B, rom_banks=ROM_BANKS,
                   ram_size_code=RAM_CODE, sgb=False, cgb=0xC0)
    open(out, 'wb').write(img)
    base = os.path.splitext(out)[0]
    open(base + '.sym', 'w').write(r.sym_file())
    print('wrote %s (%d KB), bank 0 used %d bytes' % (out, len(img) // 1024, len(r.banks[0])))


if __name__ == '__main__':
    main()
