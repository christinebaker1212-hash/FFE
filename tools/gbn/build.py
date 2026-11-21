"""Build the native FF1 Game Boy ROM (docs/ff1-native.md) from the English NES ROM the
existing pipeline makes. Game data is read from that ROM here, at build time.
usage: python3 tools/gbn/build.py [--nes build/ff1_gb.nes] [--out build/ff1n.gb] [--map M]"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..', '..')
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..', 'gb'))
from asm_sm83 import asm, make_rom
import data


def data_src(rom, m):
    p = data.map_pack(rom, m)
    db = data.db
    src = ['section bank 1, $4000', db('sm_map', p['map']),
           'section bank 1, $5000', db('sm_prop', p['prop'])]
    for name, tbl in (('mt_dmg', p['mt_dmg']), ('mt_cgb', p['mt_cgb'])):
        # corner tables of 128: UL + UR on one page, DL + DR on the next (256-aligned)
        src.append(db(name + '_ul', bytes(tbl[0]) + bytes(tbl[1]) + bytes(tbl[2]) + bytes(tbl[3])))
    src.append(db('mt_pal', bytes(p['mt_pal'])))
    src += ['section bank 2, $4000', db('cgb_tiles', p['cgb_tiles']),
            'section bank 2, $4800', db('dmg_tiles', p['dmg_tiles'].ljust(4096, b'\0')),
            'section bank 2, $5800', db('spr_tiles', p['spr_tiles']),
            db('cgb_bg', p['cgb_bg']), db('cgb_obj', p['cgb_obj']), db('obp_vals', bytes(p['obp'])),
            db('mapman_tbl', p['mapman'])]
    # placement checks for the engine's page arithmetic
    return '\n'.join(src)


def main():
    a = sys.argv[1:]
    nes = a[a.index('--nes') + 1] if '--nes' in a else os.path.join(ROOT, 'build', 'ff1_gb.nes')
    out = a[a.index('--out') + 1] if '--out' in a else os.path.join(ROOT, 'build', 'ff1n.gb')
    m = int(a[a.index('--map') + 1]) if '--map' in a else 0
    rom = data.Rom(nes)
    src = (open(os.path.join(HERE, '..', 'gb', 'rt', 'hw.s')).read() +
           open(os.path.join(HERE, 'src', 'main.s')).read() + '\n' + data_src(rom, m))
    r = asm(src)
    for lbl, align in (('sm_map', 0x100), ('mt_dmg_ul', 0x100), ('mt_cgb_ul', 0x100), ('mt_pal', 0x100),
                       ('qbuf', 0x100), ('oam_buf', 0x100)):
        assert r.labels[lbl] % align == 0, '%s at %04X not aligned' % (lbl, r.labels[lbl])
    img = make_rom(r.banks, 'FF1 NATIVE', cart_type=0x1B, rom_banks=4, ram_size_code=0x03,
                   sgb=True, cgb=0x80)
    open(out, 'wb').write(img)
    open(out[:-3] + '.sym', 'w').write(r.sym_file())
    print('wrote %s (%d KB), bank 0 used %d bytes' % (out, len(img) // 1024, len(r.banks[0])))


if __name__ == '__main__':
    main()
