"""Build the native FF1 Game Boy ROM (docs/ff1-native.md) from the English NES ROM the
existing pipeline makes. Game data is read from that ROM here, at build time; the bank layout
is described at the top of tools/gbn/src/main.s.
usage: python3 tools/gbn/build.py [--nes build/ff1_gb.nes] [--out build/ff1n.gb] [--start MAP,X,Y]"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..', '..')
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..', 'gb'))
from asm_sm83 import asm, make_rom
import data

COMMON, TS_BANK0, MAP_BANK0, OW_TS, OW_INFO, OW_ROWS, ROM_BANKS = 1, 8, 20, 16, 81, 84, 128


def place(banks, bank, addr, blob):
    b = banks.setdefault(bank, bytearray(b'\xff' * 0x4000))
    o = addr - 0x4000
    assert o + len(blob) <= 0x4000, 'bank %d overflow at %04X' % (bank, addr)
    b[o:o + len(blob)] = blob


def data_banks(rom):
    banks = {}
    c = data.common_pack(rom)
    place(banks, COMMON, 0x4000, c['spr_tiles'])
    place(banks, COMMON, 0x4100, c['mapman'])
    place(banks, COMMON, 0x4200, c['tele'])
    for ts in range(8):
        t = data.tileset_pack(rom, ts)
        place(banks, TS_BANK0 + ts, 0x4000, t['prop'])
        place(banks, TS_BANK0 + ts, 0x4100, t['tsa'])          # UL, UR / DL, DR pages
        place(banks, TS_BANK0 + ts, 0x4300, t['mt_pal'])
        place(banks, TS_BANK0 + ts, 0x4400, t['cgb_tiles'])
    o = data.ow_pack(rom)
    place(banks, OW_TS, 0x4000, o['prop'])
    place(banks, OW_TS, 0x4100, o['tsa'])
    place(banks, OW_TS, 0x4300, o['mt_pal'])
    place(banks, OW_TS, 0x4400, o['cgb_tiles'])
    place(banks, OW_INFO, 0x5000, o['cgb_bg'] + o['cgb_bg'])
    place(banks, OW_INFO, 0x5040, o['cgb_obj'])
    place(banks, OW_INFO, 0x5050, o['obp'] + bytes([8]))
    place(banks, OW_INFO, 0x5100, o['mt_dmg'] + o['mt_dmg'])
    place(banks, OW_INFO, 0x5800, o['dmg_tiles'])
    place(banks, COMMON, 0x43C0, bytes([o['start'], o['start_y']]))
    for row in range(256):
        place(banks, OW_ROWS + row // 64, 0x4000 + (row % 64) * 256, o['rows'][row])
    for m in range(data.N_MAPS):
        p = data.map_pack(rom, m)
        b = MAP_BANK0 + m
        place(banks, b, 0x4000, p['map'])
        place(banks, b, 0x5000, p['cgb_bg_out'])
        place(banks, b, 0x5020, p['cgb_bg_in'])
        place(banks, b, 0x5040, p['cgb_obj'])
        place(banks, b, 0x5050, p['obp'] + bytes([p['ts']]))
        place(banks, b, 0x5100, p['mt_dmg_out'])
        place(banks, b, 0x5300, p['mt_dmg_in'])
        place(banks, b, 0x5800, p['dmg_tiles'])
    return banks


def main():
    a = sys.argv[1:]
    nes = a[a.index('--nes') + 1] if '--nes' in a else os.path.join(ROOT, 'build', 'ff1_gb.nes')
    out = a[a.index('--out') + 1] if '--out' in a else os.path.join(ROOT, 'build', 'ff1n.gb')
    st = a[a.index('--start') + 1].split(',') if '--start' in a else ('$FF', '0', '0')
    rom = data.Rom(nes)
    src = ('START_MAP = %s\nSTART_X = %s\nSTART_Y = %s\n' % tuple(st) +
           open(os.path.join(HERE, '..', 'gb', 'rt', 'hw.s')).read() +
           open(os.path.join(HERE, 'src', 'main.s')).read())
    r = asm(src)
    for lbl in ('qbuf', 'oam_buf'):
        assert r.labels[lbl] % 0x100 == 0, '%s at %04X not aligned' % (lbl, r.labels[lbl])
    banks = dict(r.banks)
    for b, blob in data_banks(rom).items():
        assert b not in banks, 'bank %d used by code and data' % b
        banks[b] = blob
    img = make_rom(banks, 'FF1 NATIVE', cart_type=0x1B, rom_banks=ROM_BANKS, ram_size_code=0x03,
                   sgb=True, cgb=0x80)
    open(out, 'wb').write(img)
    open(out[:-3] + '.sym', 'w').write(r.sym_file())
    print('wrote %s (%d KB), bank 0 used %d bytes' % (out, len(img) // 1024, len(r.banks[0])))


if __name__ == '__main__':
    main()
