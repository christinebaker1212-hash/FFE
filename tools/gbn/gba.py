"""FF1 native build: reading the user's Final Fantasy I・II Advance (Japan, Rev 1) cartridge
(Dawn of Souls' Japanese release) at build time, for the post-game dungeons (docs/ff1-postgame-
design.md). Nothing from it is kept in the repository: this module only knows where things are
and how they are packed. SHA-1 of the expected file: 3d1c580b9b3007f6f910d80f4c7421f5d2e19dbe."""
import hashlib, os, struct

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
DEFAULT = os.path.join(ROOT, 'roms', 'Final Fantasy I, II Advance (Japan) (Rev 1).gba')
SHA1 = '3d1c580b9b3007f6f910d80f4c7421f5d2e19dbe'


class Gba:
    def __init__(self, path=DEFAULT):
        self.d = open(path, 'rb').read()
        if hashlib.sha1(self.d).hexdigest() != SHA1:
            raise ValueError('%s is not Final Fantasy I・II Advance (Japan, Rev 1)' % path)

    def u8(self, o): return self.d[o]
    def u16(self, o): return struct.unpack_from('<H', self.d, o)[0]
    def u32(self, o): return struct.unpack_from('<I', self.d, o)[0]
    def ptr(self, o):
        """a ROM pointer at o -> file offset (None if it is not one)"""
        v = self.u32(o)
        return v - 0x08000000 if 0x08000000 <= v < 0x09000000 else None

    def lz77(self, o):
        """the GBA BIOS LZ77 (type $10) block at o -> (bytes, packed length)"""
        d = self.d
        assert d[o] == 0x10
        n = d[o + 1] | d[o + 2] << 8 | d[o + 3] << 16
        out = bytearray(); p = o + 4
        while len(out) < n:
            flags = d[p]; p += 1
            for b in range(8):
                if len(out) >= n: break
                if flags & 0x80 >> b:
                    a, c = d[p], d[p + 1]; p += 2
                    ln = (a >> 4) + 3; disp = ((a & 15) << 8 | c) + 1
                    for _ in range(ln): out.append(out[-disp])
                else:
                    out.append(d[p]); p += 1
        return bytes(out[:n]), p - o

    def sjis(self, o):
        e = self.d.index(b'\x00', o)
        return self.d[o:e].decode('shift_jis', 'replace')


ASSETS = 0x2192A8                       # pointer table of packed assets (tilesets: 3 per set)
MAP_TABLE = 0x215EE0                    # FF1 map records (32 bytes): 0 world, 1-119 FF1, 120-211 Soul of Chaos
SOC_FIRST, SOC_COUNT = 120, 92
MONSTERS = 0x1D5324                     # 32-byte monster records (0-127 FF1's, then Dawn of Souls')
MONSTER_NAMES = 0x1D44E0


def _unpack(G, k):
    p = G.u32(ASSETS + 4 * k) - 0x08000000
    return G.lz77(p)[0]


def tileset(G, k):
    """tileset k: (4bpp tiles as bytes, 96 RGB555 colours, 640 tilemap entries)"""
    t = _unpack(G, 3 * k)[8:]
    p = _unpack(G, 3 * k + 1)[8:]
    m = _unpack(G, 3 * k + 2)
    n = m[4] | m[5] << 8
    cols = [p[2 * i] | p[2 * i + 1] << 8 for i in range(len(p) // 2)]
    ents = [m[8 + 2 * i] | m[9 + 2 * i] << 8 for i in range(n)]
    return t, cols, ents


def map_record(G, i):
    r = MAP_TABLE + 0x20 * i
    mp = G.u32(r + 8) - 0x08000000
    out = G.lz77(mp)[0]
    w, h = out[4] | out[5] << 8, out[6] | out[7] << 8
    cells = [out[8 + 2 * k] | out[9 + 2 * k] << 8 for k in range(w * h)]
    lp = G.u32(r + 0x20)                # (the record is +8 .. +$27: its point list is in the next row)
    pts = []
    if lp:
        for k in range(G.u32(r + 0x24)):
            o = lp - 0x08000000 + 4 * k
            pts.append((G.d[o], G.d[o + 1], G.d[o + 2], G.d[o + 3]))
    return dict(w=w, h=h, cells=cells, kind=out[0], tileset=G.u32(r + 12), area=G.u32(r + 16),
                points=pts, name=G.sjis(G.u32(r + 20) - 0x08000000))


FIELD_SETS = 0x2148B4                   # field tilesets: 36-byte records (index = a map's tileset)


def field_set(G, k):
    """field tileset k: dict(sheet: 64 x 64 tile entries (16-px chips, 16 a row in its left half), tiles (4bpp),
    pal (128 RGB555), pal2, attr (u16 per chip), anim pointer)"""
    r = FIELD_SETS + 36 * k
    p = [G.u32(r + 4 * j) for j in range(9)]
    sheet = G.lz77(p[0] - 0x08000000)[0]
    tiles = G.lz77(p[1] - 0x08000000)[0][8:]
    def pal(q):
        o = q - 0x08000000
        n = G.u32(o + 4)
        return [G.u16(o + 8 + 2 * i) for i in range(n)]
    ents = [sheet[12 + 2 * i] | sheet[13 + 2 * i] << 8 for i in range(4096)]
    ao = p[4] - 0x08000000
    attr = [G.u16(ao + 2 * i) for i in range(1024)]
    return dict(ents=ents, tiles=tiles, pal=pal(p[2]), pal2=pal(p[3]), attr=attr, anim=p[5], raw=p)


def rgb(c):
    return ((c & 31) * 255 // 31, (c >> 5 & 31) * 255 // 31, (c >> 10 & 31) * 255 // 31)


def chip_image(fs, c):
    """16 x 16 picture of chip c (PIL image)"""
    from PIL import Image
    im = Image.new('RGB', (16, 16)); px = im.load()
    for q in range(4):
        e = fs['ents'][(2 * (c // 16) + q // 2) * 64 + 2 * (c % 16) + q % 2]
        idx, hf, vf, pal = e & 0x3FF, e >> 10 & 1, e >> 11 & 1, e >> 12
        b = fs['tiles'][32 * idx:32 * idx + 32]
        for y in range(8):
            for x in range(8):
                v = b[y * 4 + x // 2] >> (4 * (x & 1)) & 15 if len(b) == 32 else 0
                col = fs['pal'][16 * pal + v] if 16 * pal + v < len(fs['pal']) else 0x7C1F
                px[8 * (q % 2) + ((7 - x) if hf else x), 8 * (q // 2) + ((7 - y) if vf else y)] = rgb(col)
    return im


def map_image(G, i):
    from PIL import Image
    m = map_record(G, i)
    fs = field_set(G, m['tileset'])
    cache = {}
    im = Image.new('RGB', (16 * m['w'], 16 * m['h']))
    for k, v in enumerate(m['cells']):
        c = v & 0x3FF
        if c not in cache: cache[c] = chip_image(fs, c)
        im.paste(cache[c], (16 * (k % m['w']), 16 * (k // m['w'])))
    return im


def _asset(G, k):
    """asset k unpacked (LZ77 when its first byte is $10, else raw: header u32 kind, u32 size)"""
    p = G.u32(ASSETS + 4 * k) - 0x08000000
    if G.d[p] == 0x10:
        return G.lz77(p)[0]
    n = G.u32(p + 4)
    return G.d[p:p + 8 + 2 * n + 8]


MON_FF1, MON_BOSS, MON_NEW = 117, 501, 552         # asset triples: FF1's 128, the 17 bosses, 50 new


def monster_asset(rec):
    """a monster record id (0-127 FF1's, 128-144 the bosses, 145-194 the new) -> its asset triple"""
    if rec < 128: return MON_FF1 + 3 * rec
    if rec < 145: return MON_BOSS + 3 * (rec - 128)
    return MON_NEW + 3 * (rec - 145)


def monster_picture(G, rec):
    """a monster's battle picture: (tile data pointer (shared by recoloured families), w, h in tiles,
    [rows of colour indices 0-15], 16 RGB555 colours)"""
    a = monster_asset(rec)
    tp = G.u32(ASSETS + 4 * a) - 0x08000000
    tiles = _asset(G, a)[8:]
    pal = _asset(G, a + 1)[8:]
    cols = [pal[2 * i] | pal[2 * i + 1] << 8 for i in range(16)]
    arr = _asset(G, a + 2)
    w, h = arr[8], arr[9]
    ents = [arr[12 + 2 * i] | arr[13 + 2 * i] << 8 for i in range(w * h)]
    px = [[0] * (8 * w) for _ in range(8 * h)]
    for i, e in enumerate(ents):
        t = e & 0x3FF; hf = e >> 10 & 1; vf = e >> 11 & 1
        for y in range(8):
            for x in range(8):
                b = tiles[32 * t + 4 * y + x // 2] if 32 * t + 32 <= len(tiles) else 0
                v = (b >> 4) if x & 1 else (b & 15)
                X = 7 - x if hf else x; Y = 7 - y if vf else y
                px[8 * (i // w) + Y][8 * (i % w) + X] = v
    return tp, w, h, px, cols


# Items (offsets in this revision): names from $1970E7 (each: 2 bytes (an icon code) + Shift-JIS, 0-ended),
# 0-42 consumables, 43-106 weapons (FF1's 40 in FF1's order, then 24 new), 107-176 armour (FF1's 40 by type, the
# new ones after each type's: bodies 107-133, shields 134-147, helmets 148-163, gloves / rings 164-176).
ITEM_NAMES = 0x1970E7
WEAPONS = 0x19A784                      # 64 x 28 bytes: +6 / +7 classes (a bit a class), +8 damage, +9 hit,
ARMOUR = 0x19AE9C                       #   +10 critical, +11 spell, +12 element, +14 category, +24 price;
                                        # 70 x 28: +0 price, +10 / +11 classes, +12 defence, +13 weight,
                                        #   +16 elements resisted
ARMOUR_TYPES = [(107, 134, 0), (134, 148, 1), (148, 164, 2), (164, 177, 3)]   # (first, end, FF1 type)


def item_names(G):
    """the 177 item names (Japanese) and their icon codes"""
    o, out = ITEM_NAMES, []
    while len(out) < 177:
        e = G.d.index(b'\x00', o)
        if e > o:
            out.append((G.d[o + 1], G.d[o + 2:e].decode('shift_jis', 'replace')))
        o = e + 1
    return out


def classes(lo, hi):
    """Dawn of Souls' class bytes (base classes bits 0-5, promoted bits 0-5) -> FF1's permission word (a set bit:
    a class that cannot use it; Fighter bit 11 .. Black Wizard bit 0)"""
    can = [(lo >> j) & 1 for j in range(6)] + [(hi >> j) & 1 for j in range(6)]
    return sum((1 - c) << (11 - j) for j, c in enumerate(can))


def weapon(G, k):
    r = G.d[WEAPONS + 28 * k:WEAPONS + 28 * k + 28]
    return dict(dmg=r[8], hit=r[9], crit=r[10], spell=r[11], element=r[12], category=r[14],
                perm=classes(r[6], r[7]), price=struct.unpack_from('<I', r, 24)[0])


def armour(G, k):
    r = G.d[ARMOUR + 28 * k:ARMOUR + 28 * k + 28]
    return dict(defence=r[12], weight=r[13], element=r[16], perm=classes(r[10], r[11]),
                price=struct.unpack_from('<I', r, 0)[0])
