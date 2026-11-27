"""FF3's minimap (Sight, Midgard Bread: 3A/88A3) from the user's ROM.

nes_screen(rom, world): runs FF3's own screen set-up (3A/8B11, 8C25, 8C3F) in py65 with the PPU
writes captured: nametable, attributes, pattern tables, palettes, the party marker's sprites.
bitmap(rom, world, x, y): the 128 x 112 map picture as FF3 draws it (3A/8A4E: one pixel a cell,
the colour from 3A/8080 / 8100 by the metatile, bits 0-1 or 2-3 in a checkerboard, bit 4 a town).
python3 tools/gb3n/minimap.py [world x y]: a mock-up PNG (NES layout and the GB's) in build/mock3."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import data
from py65.devices.mpu6502 import MPU

B8 = 0x2000


class Mem(bytearray):
    def __init__(self, rom):
        bytearray.__init__(self, 0x10000)
        for slot, b in enumerate((0x3A, 0x3B, 0x3E, 0x3F)):
            bytearray.__setitem__(self, slice(0x8000 + slot * B8, 0xA000 + slot * B8), rom.at(b * B8, B8))
        self.vram = bytearray(0x4000)
        self.addr = 0
        self.latch = 0

    def __getitem__(self, a):
        if isinstance(a, int) and a == 0x2002:
            self.latch = 0
            return 0x80
        return bytearray.__getitem__(self, a)

    def __setitem__(self, a, v):
        if isinstance(a, int):
            if a == 0x2006:
                self.addr = (self.addr & 0x3F00) | v if self.latch else (v << 8) & 0x3FFF
                self.latch ^= 1
                return
            if a == 0x2007:
                self.vram[self.addr] = v
                self.addr = (self.addr + 1) & 0x3FFF
                return
            if 0x2000 <= a < 0x6000 or a >= 0x8000:
                return
        bytearray.__setitem__(self, a, v)


def run(mem, addr):
    cpu = MPU(memory=mem)
    mem[0x1FF] = 0xFF; mem[0x1FE] = 0xEF
    cpu.sp = 0xFD; cpu.pc = addr
    n = 0
    while cpu.pc != 0xFFF0:
        cpu.step(); n += 1
        assert n < 2000000, hex(cpu.pc)


def nes_screen(rom, world):
    mem = Mem(rom)
    for a in (0xFF00, 0xC00F, 0xC009):                     # wait for V-Blank, palettes, sound: RTS
        bytearray.__setitem__(mem, a, 0x60)
    mem[0x78] = world
    mem[0xFF] = 0x88
    for a in (0x8B11, 0x8C25, 0x8C3F):
        run(mem, a)
    return {'nt': bytes(mem.vram[0x2000:0x23C0]), 'at': bytes(mem.vram[0x23C0:0x2400]),
            'pt0': bytes(mem.vram[0:0x1000]), 'pt1': bytes(mem.vram[0x1000:0x2000]),
            'pal': bytes(mem[0x3C0:0x3E0]), 'oam': bytes(mem[0x200:0x210]),
            'col': bytes(mem[0x7E00:0x7E80])}


def bitmap(rom, world, x, y, col):
    """128 x 112 colour values (0-3) and the towns' pixels, the party at (x, y) (3A/88D4)"""
    rows = data.world_rows(rom, world)
    x0, y0 = (x - 7 - 0x39 + 1) & 0xFF, (y - 7 - 0x31) & 0xFF
    pix = [[0] * 128 for _ in range(112)]
    towns = []
    for r in range(112):
        row = rows[(y0 + r) & 0xFF]
        for c in range(128):
            v = col[row[(x0 + c) & 0xFF] & 0x7F]
            if v & 0x10:
                towns.append((c, r))
            if (r + c) & 1 == 0:                            # (odd rows start with bits 0-1)
                v >>= 2
            pix[r][c] = (v & 1) | (v >> 1 & 1) << 1
    return pix, towns


def gb_bank(rom):
    """B_MINI's data ($4000-$5FFF): the screen's tiles (VRAM bank 0), OBJ tiles, the 20 x 18 map and
    attributes (FF3's rows 3-5 and 9-23, columns 6-25; the map's 224 tiles in VRAM bank 1), rows 0-2
    before the logo, palettes and pixel colours per world, the marker's sprites"""
    import tiles
    out = bytearray(0x2000)
    s0 = nes_screen(rom, 0)
    nt, at = s0['nt'], s0['at']
    used = []
    def tid(tb, t):
        if (tb, t) not in used: used.append((tb, t))
        return used.index((tb, t))
    attr = lambda ny, nx: at[8 * (ny >> 2) + (nx >> 2)] >> (((ny & 2) << 1) | (nx & 2)) & 3
    mp, ma = bytearray(360), bytearray(360)
    for gy in range(18):
        for gx in range(20):
            nx, ny = gx + 6, (gy + 3 if gy < 3 else gy + 6)
            t, a = nt[32 * ny + nx], attr(ny, nx)
            if 10 <= ny <= 23 and 8 <= nx <= 23:
                mp[20 * gy + gx], ma[20 * gy + gx] = t - 0x20, a | 8
            else:
                mp[20 * gy + gx], ma[20 * gy + gx] = tid(1 if gy < 3 else 0, t), a
    pre = bytes([tid(1, 0x01)] * 60)                        # (rows 3-5 while it draws: 3A/8B5B)
    assert len(used) <= 0x60, len(used)
    for k, (tb, t) in enumerate(used):
        pt = s0['pt1'] if tb else s0['pt0']
        out[16 * k:16 * k + 16] = tiles.gb(pt[16 * t:16 * t + 16])
    o = s0['oam']                                           # OBJ tile 0: the marker's (table 1), 1: a town
    assert len(set(o[1::4])) == 1
    out[0x600:0x610] = tiles.gb(s0['pt1'][16 * o[1]:16 * o[1] + 16])
    out[0x610:0x620] = tiles.gb(s0['pt1'][16:32])
    out[0x700:0x868] = mp
    out[0x900:0xA68] = ma
    out[0xA80:0xABC] = pre
    out[0xAC0:0xAFC] = ma[0:60]
    for w in range(5):                                      # BG palettes 0-3 (RGB555), colours, by world
        sw = nes_screen(rom, w)
        for k in range(16):
            out[0xB00 + 32 * w + 2 * k:0xB02 + 32 * w + 2 * k] = data.rgb555(sw['pal'][k]).to_bytes(2, 'little')
        out[0xC00 + 128 * w:0xC80 + 128 * w] = sw['col']
    for k in range(4):                                      # the marker (3A/8040): GB OAM (NES - 48)
        y, t, a, x = o[4 * k:4 * k + 4]
        out[0xE80 + 4 * k:0xE84 + 4 * k] = bytes([y + 1 - 48 + 16, x - 48 + 8, 0, (a & 0xC0) >> 1])
    return bytes(out)


def nes_tile(pt, t):
    b = pt[16 * t:16 * t + 16]
    return [[(b[y] >> (7 - x) & 1) | (b[8 + y] >> (7 - x) & 1) << 1 for x in range(8)] for y in range(8)]


def render_nes(s, pix, towns):
    """the NES screen (256 x 240) as FF3 shows it: BG from pattern table 1 above the map, table 0
    from the map's rows (its raster split), the bitmap in tiles $20-$FF, towns and the marker"""
    from build import NES_RGB
    from PIL import Image
    pt0 = bytearray(s['pt0'])
    for r in range(112):                                    # the bitmap into tiles $20 + 16 (r / 8) + c / 8
        for c in range(128):
            t = 0x20 + 16 * (r >> 3) + (c >> 3)
            v = pix[r][c]
            bit = 0x80 >> (c & 7)
            if v & 1: pt0[16 * t + (r & 7)] |= bit
            if v & 2: pt0[16 * t + 8 + (r & 7)] |= bit
    im = Image.new('RGB', (256, 240))
    pal = s['pal']
    rgb = lambda c: (NES_RGB[c & 0x3F] >> 16, NES_RGB[c & 0x3F] >> 8 & 255, NES_RGB[c & 0x3F] & 255)
    for ty in range(30):
        for tx in range(32):
            t = s['nt'][32 * ty + tx]
            a = s['at'][8 * (ty >> 2) + (tx >> 2)] >> (((ty & 2) << 1) | (tx & 2)) & 3
            pt = pt0 if 9 <= ty <= 24 else s['pt1']
            for y, row in enumerate(nes_tile(pt, t)):
                for x, v in enumerate(row):
                    im.putpixel((8 * tx + x, 8 * ty + y), rgb(pal[0] if v == 0 else pal[4 * a + v]))
    for c, r in towns:                                      # (3A/8AD2: tile 1, palette 0, from (60, 76))
        for y, row in enumerate(nes_tile(s['pt1'], 1)):
            for x, v in enumerate(row):
                if v: im.putpixel((60 + c + x, 76 + r + y), rgb(pal[16 + v]))
    o = s['oam']
    for k in range(4):
        sy, t, at, sx = o[4 * k:4 * k + 4]
        for y, row in enumerate(nes_tile(s['pt1'], t)):
            for x, v in enumerate(row):
                if v: im.putpixel((sx + (7 - x if at & 0x40 else x), sy + 1 + (7 - y if at & 0x80 else y)), rgb(pal[16 + 4 * (at & 3) + v] if v != 1 else 0x16))
    return im


def main():
    from PIL import Image
    sys.path.insert(0, os.path.join(HERE, '..', 'gb'))
    rom = data.Rom(os.path.join(HERE, '..', '..', 'build', 'ff3_en.nes'))
    a = [int(v, 0) for v in sys.argv[1:4]] if len(sys.argv) > 3 else [0, 60, 90]
    world, x, y = a
    s = nes_screen(rom, world)
    pix, towns = bitmap(rom, world, x, y, s['col'])
    im = render_nes(s, pix, towns)
    out = os.path.join(HERE, '..', '..', 'build', 'mock3')
    im.resize((512, 480), Image.NEAREST).save(os.path.join(out, 'minimap_nes.png'))
    gb = Image.new('RGB', (160, 144))                       # the GB: FF3's logo (NES rows 3-5), then
    gb.paste(im.crop((48, 24, 208, 48)), (0, 0))            #   the map with its border (rows 9-23),
    gb.paste(im.crop((48, 72, 208, 192)), (0, 24))          #   NES columns 6-25
    gb.resize((480, 432), Image.NEAREST).save(os.path.join(out, 'minimap_gb.png'))


if __name__ == '__main__':
    main()
