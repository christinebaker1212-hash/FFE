"""FF3 data readers (build time): where the ROM keeps each table and how to read it, from the
everything8215/ff3 listing (build/ref/ff3). No game bytes are kept here; everything is read from
the user's ROM (the English MMC5 build keeps the Japanese banks 0-63 where they were).

Addresses are 8 KB banks as in the listing ("BB/AAAA"); `lin(bank, addr)` is the PRG offset."""
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'gb'))
from build import NES_RGB                     # (a generic 2C02 palette: no game data)

B8 = 0x2000
GFX_BLOCKS = 8                                # map BG graphics: 8 blocks of tiles ($3E $DE5A)


class Rom:
    def __init__(self, path):
        d = open(path, 'rb').read()
        self.prg = d[16:16 + (d[4] * 0x4000)]

    def lin(self, bank, addr):
        return bank * B8 + (addr & 0x1FFF)

    def rd(self, bank, addr, n=1):
        o = self.lin(bank, addr)
        return self.prg[o:o + n] if n != 1 else self.prg[o]

    def at(self, o, n=1):
        return self.prg[o:o + n] if n != 1 else self.prg[o]

    # ---- the listing's own constants, read from the ROM's code where they live
    def gfx_counts(self):
        """tiles per map BG graphics block: the table after "copy tiles to vram" ($3E $DF00)"""
        return list(self.rd(0x3E, 0xDF00, GFX_BLOCKS))

    def player_poses(self):
        """the player sprite poses ($3E $DC2A, 64 bytes: right, left, up, down; 2 frames each;
        per frame UL, DL, UR, DR as tile + NES attributes)"""
        return self.rd(0x3E, 0xDC2A, 64)

    def map_char_tiles(self, pal_id):
        """16 walking tiles of map character graphics set `pal_id` (job, $16 toad, $17 mini,
        guests from $18: 0E/8000 + $100 each, $3E $DD2D)"""
        return self.at(0x0E * B8 + 0x100 * (pal_id & 0x3F), 0x100)

    def char_palettes(self, pal_id, world):
        """the walking character's two sprite palettes (NES colours): the map sprite palettes
        (00/9670 + (world & 4) * 4) with colours 2-3 of each from the map character palette
        (00/9690 + 4 * id; $3A $9050 / $9091)"""
        base = list(self.rd(0x00, 0x9670 + (world & 4) * 4, 16))
        c = self.rd(0x00, 0x9690 + 4 * pal_id, 4)
        base[2], base[3], base[6], base[7] = c[0], c[1], c[2], c[3]
        return [base[0:4], base[4:8]]


def ptr(lo, hi, base_bank):
    """FF3's banked pointer (lo, hi): address lo | ((hi & $1F) | $80) << 8 in 8 KB bank
    (hi >> 5) + base_bank, mapped as a 16 KB pair: a linear offset"""
    return base_bank * B8 + ((hi << 8) | lo)


class Map:
    """a normal map: index `p` into the map properties (0-511), `t` into the tilemap / graphics
    tables (0-511; the game uses p = map + 256 * (world != 0), t = map + 256 * (world >= 2))"""

    def __init__(self, rom, p, t=None):
        self.rom, self.p = rom, p
        self.t = p if t is None else t
        self.props = rom.rd(0x02, 0xA000 + 16 * p, 16)                       # $3A $915E
        self.tileset = self.props[0] >> 5                                      # $3A $9267
        ts = self.tileset
        q = rom.rd(0x01, 0xA380 + 0x200 * ts, 0x200)
        self.quad = [q[0:128], q[128:256], q[256:384], q[384:512]]            # UL UR DL DR
        self.attr = rom.rd(0x01, 0xB180 + 0x80 * ts, 0x80)                     # palette per metatile
        tp = rom.rd(0x01, 0xB500 + 0x100 * ts, 0x100)
        self.tprop = [(tp[2 * i], tp[2 * i + 1]) for i in range(128)]

    def tilemap(self):
        """the 32 x 32 metatile map ($3E $CBA4 load map data, $CBFA RLE: a byte < $80 is a
        metatile; $80 | v is followed by a run length, 0 meaning 256)"""
        r = self.rom
        tid = r.rd(0x00, 0x8A00 + self.t)
        lo, hi = r.rd(0x11, 0x8000 + 2 * tid, 2)
        o = ptr(lo, hi, 0x11)
        out = bytearray()
        while len(out) < 1024:
            v = r.at(o); o += 1
            if v & 0x80:
                n = r.at(o) or 256; o += 1
                out += bytes([v & 0x7F]) * n
            else:
                out.append(v)
        return bytes(out[:1024])

    def bg_tiles(self):
        """BG pattern table as the game loads it: 8 graphics blocks from tile 0 ($3E $DE5A), then
        the menu window / text tiles at $70-$FF (0D/B700, 144 tiles); 256 NES tiles of 16 bytes"""
        r = self.rom
        sub = r.rd(0x00, 0x8C00 + self.t)
        ptrs = r.rd(0x00, 0x8E00 + 16 * sub, 16)
        out = bytearray()
        for k, n in enumerate(r.gfx_counts()):
            o = ptr(ptrs[2 * k], ptrs[2 * k + 1], 0x03)
            out += r.at(o, 16 * n)
        out = out[:0x700]
        out += r.rd(0x0D, 0xB700, 144 * 16)
        return bytes(out[:0x1000])

    def bg_palettes(self):
        """the four BG palettes (NES colours): 0-2 from the map properties bytes 5-7 through the
        general use palettes (00/9100, 9200, 9300), colour 0 black; 3 the menu window
        ($3A $9091 load map palette)"""
        r = self.rom
        pals = []
        for b in self.props[5:8]:
            pals.append([0x0F, r.rd(0x00, 0x9100 + b), r.rd(0x00, 0x9200 + b), r.rd(0x00, 0x9300 + b)])
        pals.append([0x0F, 0x00, 0x02, 0x30])
        return pals


def rgb(c):
    v = NES_RGB[c & 0x3F]
    return (v >> 16, (v >> 8) & 0xFF, v & 0xFF)


def rgb555(c):
    v = NES_RGB[c & 0x3F]
    return (v >> 19) | ((v >> 11) & 0x1F) << 5 | ((v >> 3) & 0x1F) << 10


def render(m, path):
    """the whole 512 x 512 map as the NES draws it (checking the readers)"""
    from PIL import Image
    tm, til, pals = m.tilemap(), m.bg_tiles(), m.bg_palettes()
    im = Image.new('RGB', (512, 512)); px = im.load()
    def tile(n, x0, y0, pal):
        t = til[16 * n:16 * n + 16]
        for y in range(8):
            for x in range(8):
                c = ((t[y] >> (7 - x)) & 1) | (((t[8 + y] >> (7 - x)) & 1) << 1)
                px[x0 + x, y0 + y] = rgb(pal[c])
    for my in range(32):
        for mx in range(32):
            v = tm[32 * my + mx]
            pal = pals[m.attr[v & 0x7F] & 3]
            for k, (dx, dy) in enumerate(((0, 0), (8, 0), (0, 8), (8, 8))):
                tile(m.quad[k][v & 0x7F], 16 * mx + dx, 16 * my + dy, pal)
    im.save(path)


if __name__ == '__main__':
    rom = Rom(sys.argv[1])
    for p in map(int, sys.argv[3:]):
        m = Map(rom, p)
        print(p, 'props', m.props.hex(), 'tileset', m.tileset)
        render(m, os.path.join(sys.argv[2], 'map%03d.png' % p))


# ---- the field's data banks for the GB build (tools/gb3n/build.py places them; layouts are
# described at the top of src/field.s)
TILESET_COUNT = 7
SUBSET_TILES = 112                            # 26+8+8+14+8+16+16+16: BG tiles $00-$6F


def tilemap_stream(rom, tid):
    """the compressed bytes of tilemap `tid`, as stored (RLE, ends when 1024 cells are out)"""
    lo, hi = rom.rd(0x11, 0x8000 + 2 * tid, 2)
    o = s = ptr(lo, hi, 0x11)
    n = 0
    while n < 1024:
        v = rom.at(o); o += 1
        if v & 0x80:
            n += rom.at(o) or 256; o += 1
        else:
            n += 1
    return rom.at(s, o - s)


def subset_tiles(rom, sub):
    """graphics subset `sub` as the NES loads it: 112 tiles (NES format)"""
    ptrs = rom.rd(0x00, 0x8E00 + 16 * sub, 16)
    out = bytearray()
    for k, n in enumerate(rom.gfx_counts()):
        o = ptr(ptrs[2 * k], ptrs[2 * k + 1], 0x03)
        out += rom.at(o, 16 * n)
    return bytes(out[:16 * SUBSET_TILES])


def tileset_block(rom, ts):
    """1 KB per tileset: UL, UR, DL, DR pages (128 each), palette (& 3), property 1, property 2"""
    q = rom.rd(0x01, 0xA380 + 0x200 * ts, 0x200)
    a = rom.rd(0x01, 0xB180 + 0x80 * ts, 0x80)
    tp = rom.rd(0x01, 0xB500 + 0x100 * ts, 0x100)
    return q + bytes(v & 3 for v in a) + tp[0::2] + tp[1::2] + bytes(0x80)


def trigger_tables(rom):
    """trigger tiles ($3A $91C8 init trigger): base tile for metatiles $80-$FF (93C1, 128),
    type per tile $60-$7F (921F, 32), first metatile per tile $60-$7F (923F, 32)"""
    return rom.rd(0x3A, 0x93C1, 128), rom.rd(0x3A, 0x921F, 32), rom.rd(0x3A, 0x923F, 32)


def window_colours(rom):
    """palette 3 (menu window) on normal maps: the immediates at $3A $9133-$9144 (gray, blue,
    white, and black as colour 0)"""
    return bytes([rom.rd(0x3A, 0x9143), rom.rd(0x3A, 0x9134), rom.rd(0x3A, 0x9139), rom.rd(0x3A, 0x913E)])
