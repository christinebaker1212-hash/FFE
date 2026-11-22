"""Build the native FF3 Game Boy Color ROM (tools/gb3n): the user's English NES ROM (made by the
FF3 pipeline: tools/gb3/build.py -> build/ff3_en.nes) is the only input for game data.

usage: build.py [EN.nes] [--map ID] [--world W] [--out ROM]"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, HERE); sys.path.insert(0, os.path.join(ROOT, 'tools', 'gb'))
from data import Rom, nes2gb
from asm_sm83 import asm, make_rom
import build as gb1                     # tools/gb/build.py: NES_RGB (the 2C02 colours)


def rgb555(c):
    v = gb1.NES_RGB[c & 0x3F]
    r, g, b = v >> 16, (v >> 8) & 255, v & 255
    return (r >> 3) | (g >> 3) << 5 | (b >> 3) << 10


def map_bank(rom, mid, world):
    """the map data bank (src/main.s MAPB layout)"""
    bank = bytearray(b'\xFF' * 0x4000)
    bank[0x0000:0x0400] = rom.layout(mid, world)
    mp = rom.map_props(mid, world)
    t = rom.tileset(mp[0] >> 5)
    for k, key in enumerate(('tl', 'tr', 'bl', 'br', 'attr', 'p1', 'p2')):
        bank[0x400 + 0x100 * k:0x500 + 0x100 * k] = t[key]
    pal = rom.map_palettes(mid, world)
    out = bytearray()
    for i in range(8):                                 # BG 0-3, OBJ 0-3 (4 colours each)
        for j in range(4):
            v = rgb555(pal[4 * i + j]); out += bytes([v & 255, v >> 8])
    bank[0xB00:0xB00 + 32] = out[:32]                  # BG palettes 0-3
    bank[0xB40:0xB40 + 32] = out[32:]                  # OBJ palettes 0-3
    chr_, _ = rom.bg_chr(mid, world)
    bank[0xC00:0x1C00] = b''.join(nes2gb(chr_[16 * k:16 * k + 16]) for k in range(256))
    sp = rom.char_chr(0)
    bank[0x1C00:0x1D00] = b''.join(nes2gb(sp[16 * k:16 * k + 16]) for k in range(16))
    return bytes(bank), mp


def main():
    args = sys.argv[1:]
    opt = {'--map': '181', '--world': '0', '--out': os.path.join(ROOT, 'build', 'ff3n.gbc')}
    pos = []
    while args:
        a = args.pop(0)
        if a in opt: opt[a] = args.pop(0)
        else: pos.append(a)
    rom = Rom(pos[0] if pos else os.path.join(ROOT, 'build', 'ff3_en.nes'))
    mid, world = int(opt['--map'], 0), int(opt['--world'], 0)
    data, mp = map_bank(rom, mid, world)
    src = open(os.path.join(ROOT, 'tools', 'gb3', 'rt', 'hw.s')).read() + '\n' + \
        open(os.path.join(HERE, 'src', 'main.s')).read()
    r = asm(src, syms={'START_X': mp[0] & 0x1F, 'START_Y': mp[1] & 0x1F, 'FILL_MT': mp[3]})
    r.banks[1] = bytearray(data)
    size = 2
    while size < max(r.banks) + 1: size *= 2
    rom_bytes = make_rom(r.banks, 'FF3 NATIVE', cart_type=0x1B, rom_banks=size, ram_size_code=0x02, cgb=0xC0)
    open(opt['--out'], 'wb').write(rom_bytes)
    print('wrote %s (map %d, world %d, start %d,%d)' % (opt['--out'], mid, world, mp[0] & 0x1F, mp[1] & 0x1F))


if __name__ == '__main__':
    main()
