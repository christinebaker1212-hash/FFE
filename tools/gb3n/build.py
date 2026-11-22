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


TS_BANK = 8                             # the 8 tilesets: $4000 + $700 ts (TL TR BL BR ATTR P1 P2)
MT_BANK = 9                             # map entries: 64 bytes, (group * 256 + id) -> bank 9 + group
LAY_BANK0 = 12                          # layouts: 16 a bank
CHR_BANK0 = LAY_BANK0 + 16              # BG tile sets (GB format): 4 a bank
SPR_BANK = CHR_BANK0 + 16               # walking characters: $4000 + $100 job; frames $7F00


def group_world(g):
    return (0, 1, 2)[g]


def pack(rom):
    """all maps: {bank: bytes}"""
    banks = {}
    ts = bytearray(b'\xFF' * 0x4000)
    for t in range(8):
        d = rom.tileset(t)
        for k, key in enumerate(('tl', 'tr', 'bl', 'br', 'attr', 'p1', 'p2')):
            ts[0x700 * t + 0x100 * k:0x700 * t + 0x100 * k + 0x100] = d[key]
    banks[TS_BANK] = ts
    lay_ix, chr_ix = {}, {}
    ent = {g: bytearray(b'\x00' * 0x4000) for g in range(3)}
    for g in range(3):
        w = group_world(g)
        for mid in range(256):
            tid = rom.u8(0, (0x8B00 if w >= 2 else 0x8A00) + mid)
            sid = rom.u8(0, (0x8D00 if w >= 2 else 0x8C00) + mid)
            lk, ck = (w >= 2, tid), (w >= 2, sid)
            if lk not in lay_ix:
                n = len(lay_ix); lay_ix[lk] = n
                b = LAY_BANK0 + n // 16
                banks.setdefault(b, bytearray(b'\xFF' * 0x4000))
                banks[b][0x400 * (n % 16):0x400 * (n % 16) + 0x400] = rom.layout(mid, w)
            if ck not in chr_ix:
                n = len(chr_ix); chr_ix[ck] = n
                b = CHR_BANK0 + n // 4
                banks.setdefault(b, bytearray(b'\xFF' * 0x4000))
                c, _ = rom.bg_chr(mid, w)
                banks[b][0x1000 * (n % 4):0x1000 * (n % 4) + 0x1000] = b''.join(
                    nes2gb(c[16 * k:16 * k + 16]) for k in range(256))
            mp = rom.map_props(mid, w)
            li, ci = lay_ix[lk], chr_ix[ck]
            e = bytearray(64)
            e[0], e[1] = LAY_BANK0 + li // 16, 0x40 + 4 * (li % 16)     # layout: bank, page
            e[2], e[3] = CHR_BANK0 + ci // 4, 0x40 + 0x10 * (ci % 4)    # tiles: bank, page
            e[4] = mp[0] >> 5                                          # tileset
            e[5], e[6], e[7] = mp[0] & 0x1F, mp[1] & 0x1F, mp[3]       # start x, y, fill
            e[8], e[9] = mp[2], mp[10]                                 # title, song
            e[10] = mp[1]                                              # flags (gil, water)
            e[16:48] = rom.map_palettes(mid, w)                        # NES colours
            ent[g][64 * mid:64 * mid + 64] = e
    for g in range(3): banks[MT_BANK + g] = ent[g]
    sp = bytearray(b'\xFF' * 0x4000)
    for job in range(0x20):
        c = rom.char_chr(job)
        sp[0x100 * job:0x100 * job + 0x100] = b''.join(nes2gb(c[16 * k:16 * k + 16]) for k in range(16))
    sp[0x3F00:0x3F10] = rom.b(0x7E, 0xDC1A, 16)
    fr = rom.b(0x7E, 0xDC2A, 0x40)
    cv = lambda a: (a & 3) | 8 | ((a & 0x40) >> 1) | ((a & 0x80) >> 1) | ((a & 0x20) << 2)
    sp[0x3F10:0x3F50] = bytes(v if k % 2 == 0 else cv(v) for k, v in enumerate(fr))
    banks[SPR_BANK] = sp
    return banks, len(lay_ix), len(chr_ix)


def nes_rgb_src():
    """NES colour -> RGB555 (bank 0)"""
    v = [rgb555(c) for c in range(64)]
    return 'section bank 0, $3F00\nNES_RGB:\n' + ''.join(
        '    dw %s\n' % ', '.join(str(x) for x in v[k:k + 8]) for k in range(0, 64, 8))


def main():
    args = sys.argv[1:]
    opt = {'--map': '181', '--group': '0', '--out': os.path.join(ROOT, 'build', 'ff3n.gbc')}
    pos = []
    while args:
        a = args.pop(0)
        if a in opt: opt[a] = args.pop(0)
        else: pos.append(a)
    rom = Rom(pos[0] if pos else os.path.join(ROOT, 'build', 'ff3_en.nes'))
    banks, nl, nc = pack(rom)
    src = open(os.path.join(ROOT, 'tools', 'gb3', 'rt', 'hw.s')).read() + '\n' + \
        open(os.path.join(HERE, 'src', 'main.s')).read() + '\n' + nes_rgb_src()
    r = asm(src, syms={'START_MAP': int(opt['--map'], 0), 'START_GRP': int(opt['--group'], 0),
                       'TS_BANK': TS_BANK, 'MT_BANK': MT_BANK, 'SPR_BANK': SPR_BANK})
    for b, d in banks.items(): r.banks[b] = bytearray(d)
    size = 2
    while size < max(r.banks) + 1: size *= 2
    rom_bytes = make_rom(r.banks, 'FF3 NATIVE', cart_type=0x1B, rom_banks=size, ram_size_code=0x02, cgb=0xC0)
    open(opt['--out'], 'wb').write(rom_bytes)
    print('wrote %s: %d KB, %d layouts, %d tile sets; start map %s group %s'
          % (opt['--out'], len(rom_bytes) // 1024, nl, nc, opt['--map'], opt['--group']))


if __name__ == '__main__':
    main()
