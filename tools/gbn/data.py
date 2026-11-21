"""FF1 native build: game data read from the user's ROM at build time and converted to
Game Boy form (docs/ff1-native.md). Nothing here contains game data; it only knows where the
ROM keeps it (FF1 disassembly, matched to the Japanese ROM) and how to convert it.

The input is the English NES ROM the existing pipeline makes (NES ROM -> MMC5 split ->
English insert; 16 KB PRG banks as the original MMC1 layout)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'gb'))

# 2C02 colours (approximation, as the recompiled build's NES_RGB) -> RGB
from build import NES_RGB

BANK_SMINFO, BANK_TILESETCHR, BANK_MAPCHR, BANK_STANDARDMAPS = 0, 3, 2, 4
SM_PROP, SM_TSA, SM_ATTR, SM_PAL = 0x8800, 0x9000, 0x8400, 0xA000
TILESETS = 0xACC0                       # map -> tileset (BANK_TELEPORTINFO = 0)
MAPMAN_PAL = 0x83A0                     # class -> two sprite colours (BANK_MAPMANPAL = 0)
MAPMAN_CHR = 0x9000                     # class c: 16 tiles at $9000 + $100 c (BANK_MAPCHR)
MAPMAN_SPR = [                          # (tile, attr) x4 per (facing, frame): UL, DL, UR, DR
    # right 0/1, left 0/1, up 0/1, down 0/1 - read from the ROM (see mapman_table)
]


class Rom:
    def __init__(self, path):
        data = open(path, 'rb').read()
        self.prg = data[16:]

    def rd(self, bank, addr, n=1):
        o = bank * 0x4000 + addr - 0x8000
        return self.prg[o:o + n] if n != 1 else self.prg[o]


def lum(c):
    """perceived brightness 0..1 of NES colour c"""
    v = NES_RGB[c & 0x3F]
    r, g, b = v >> 16, (v >> 8) & 0xFF, v & 0xFF
    return (0.299 * r + 0.587 * g + 0.114 * b) / 255


def rgb555(c):
    v = NES_RGB[c & 0x3F]
    r, g, b = v >> 19, (v >> 11) & 0x1F, (v >> 3) & 0x1F
    return r | g << 5 | b << 10


def shades(cols):
    """DMG shade (0 white .. 3 black) for each of a palette's colours: by brightness,
    different colours kept apart where four shades allow"""
    uniq = sorted(set(cols), key=lambda c: -lum(c))           # brightest first
    q = {c: min(3, max(0, round((1 - lum(c)) * 3.2))) for c in uniq}
    out = {}
    prev = -1
    for i, c in enumerate(uniq):                               # monotonic, distinct if possible
        s = max(q[c], prev + 1) if len(uniq) <= 4 else max(q[c], prev)
        s = min(s, 3 - (len(uniq) - 1 - i) if len(uniq) <= 4 else 3)
        s = max(s, prev + (1 if len(uniq) <= 4 else 0))
        out[c] = s; prev = s
    return [out[c] for c in cols]


def level(c):
    """the 2C02 brightness row of a colour (-1: black), greys placed by their brightness"""
    c &= 0x3F
    if (c & 0x0F) >= 0x0D: return -1
    if (c & 0x0F) == 0: return {0x00: 0, 0x10: 1, 0x20: 3, 0x30: 3}[c]
    return c >> 4


def map_shades(pals):
    """one DMG shade per NES colour for a whole screen (all its BG palettes), as the
    recompiled build's rule: black stays black; the other brightness rows go to dark grey /
    light grey / white, darkest first (four rows: the brightest two share white), so a colour
    shades alike in every palette"""
    cols = set(c for p in pals for c in p)
    lv = sorted(set(level(c) for c in cols if level(c) >= 0))
    if len(lv) > 3:                                  # merge until three: brightest first
        while len(lv) > 3: lv = lv[:-2] + [lv[-1]]
    shade_of = {}
    for i, l in enumerate(lv):
        shade_of[l] = 2 - i if len(lv) == 3 else (2 - i if len(lv) == 2 else 1)
    out = {}
    for c in cols:
        l = level(c)
        if l < 0: out[c] = 3; continue
        k = max(x for x in lv if x <= l) if any(x <= l for x in lv) else lv[0]
        out[c] = shade_of[k]
    return out


def obj_shades(p):
    """DMG sprite palette: colour 1-3 by brightness, darkest black (an outline on any
    ground), brightest white, the middle one light or dark grey"""
    cols = sorted(range(1, 4), key=lambda i: -lum(p[i]))
    s = [0, 0, 0, 0]
    s[cols[0]] = 0; s[cols[2]] = 3
    s[cols[1]] = 2
    return s[0] | s[1] << 2 | s[2] << 4 | s[3] << 6


def gb_tile(t16, remap=(0, 1, 2, 3)):
    """NES tile (plane 0 rows, plane 1 rows) -> GB 2bpp (lo, hi per row), values remapped"""
    out = bytearray()
    for y in range(8):
        lo = hi = 0
        for x in range(8):
            v = (t16[y] >> (7 - x) & 1) | (t16[8 + y] >> (7 - x) & 1) << 1
            v = remap[v]
            lo |= (v & 1) << (7 - x); hi |= (v >> 1) << (7 - x)
        out += bytes([lo, hi])
    return bytes(out)


def std_map(rom, m):
    """standard map m (64 x 64 metatile numbers), decompressed as FF1's loader does"""
    lo, hi = rom.rd(BANK_STANDARDMAPS, 0x8000 + 2 * m), rom.rd(BANK_STANDARDMAPS, 0x8001 + 2 * m)
    bank, p = (hi >> 6) | BANK_STANDARDMAPS, lo | ((hi & 0x3F) | 0x80) << 8
    out = bytearray()
    while len(out) < 4096:
        a = rom.rd(bank, p)
        if a == 0xFF: break
        if a < 0x80:
            out.append(a); p += 1
        else:
            n = rom.rd(bank, p + 1)
            out += bytes([a & 0x7F]) * (n if n else 256); p += 2
        if p >= 0xC000: bank, p = bank + 1, p - 0x4000
    return bytes(out[:4096].ljust(4096, b'\0'))


def mapman_table(rom):
    """FF1's player sprite tables (8 x 8 bytes: tile, attr for UL, DL, UR, DR), found in the
    fixed bank by their shape (facing right frame 0 starts $09,$40,$0B,$41)"""
    fix = rom.prg[-0x4000:]
    sig = bytes([0x09, 0x40, 0x0B, 0x41, 0x08, 0x40, 0x0A, 0x41])
    i = fix.find(sig)
    assert i >= 0, 'player sprite table not found'
    return fix[i:i + 64]


NORM_TELE_X, NORM_TELE_Y, NORM_TELE_MAP = 0xAD00, 0xAD40, 0xAD80   # BANK_TELEPORTINFO = 0
EXIT_TELE_X, EXIT_TELE_Y = 0xAC60, 0xAC70
ENTR_TELE_X, ENTR_TELE_Y, ENTR_TELE_MAP = 0xAC00, 0xAC20, 0xAC40
N_MAPS = 61


def tileset_pack(rom, ts):
    """a standard-map tileset: properties, metatile corner tiles (CGB: the NES tile numbers),
    metatile palettes, the 128 BG tiles in GB form"""
    prop = rom.rd(BANK_SMINFO, SM_PROP + 256 * ts, 256)
    tsa = rom.rd(BANK_SMINFO, SM_TSA + 512 * ts, 512)
    attr = rom.rd(BANK_SMINFO, SM_ATTR + 128 * ts, 128)
    chr_ = rom.rd(BANK_TILESETCHR, 0x8000 + 0x800 * ts, 0x800)
    return dict(prop=prop, tsa=tsa, mt_pal=bytes(a & 3 for a in attr),
                cgb_tiles=b''.join(gb_tile(chr_[16 * t:16 * t + 16]) for t in range(128)))


def map_pack(rom, m, cls=0):
    """a standard map: metatiles, palettes (outside / in a room), and for DMG the tiles
    pre-shaded per (tile, shading) with a metatile table for each room state"""
    ts = rom.rd(BANK_SMINFO, TILESETS + m)
    t = tileset_pack(rom, ts)
    pal = bytearray(rom.rd(BANK_SMINFO, SM_PAL + 0x30 * m, 0x30))
    mp = rom.rd(BANK_SMINFO, MAPMAN_PAL + 2 * cls, 2)
    pal[0x12], pal[0x16] = mp[0], mp[1]
    chr_ = rom.rd(BANK_TILESETCHR, 0x8000 + 0x800 * ts, 0x800)
    var = {}; dmg_tiles = bytearray(); mt_dmg = {}
    cgb_bg = {}
    for room, off in (('out', 0), ('in', 0x20)):
        bg = [[pal[off]] + list(pal[off + 4 * p + 1:off + 4 * p + 4]) for p in range(4)]
        msh = map_shades(bg)
        tbl = bytearray(512)
        for k in range(4):
            for mt in range(128):
                nt, p = t['tsa'][128 * k + mt], t['mt_pal'][mt]
                key = (nt, tuple(msh[c] for c in bg[p]))
                if key not in var:
                    var[key] = len(var)
                    dmg_tiles += gb_tile(chr_[16 * nt:16 * nt + 16], key[1])
                tbl[128 * k + mt] = var[key]
        mt_dmg[room] = bytes(tbl)
        cgb_bg[room] = b''.join(rgb555(c).to_bytes(2, 'little') for p in range(4) for c in bg[p])
    assert len(var) <= 256, 'map %d: %d DMG tile variants' % (m, len(var))
    sppal = [[pal[0x10]] + list(pal[0x10 + 4 * p + 1:0x10 + 4 * p + 4]) for p in range(2)]
    cgb_obj = b''.join(rgb555(c).to_bytes(2, 'little') for p in range(2) for c in sppal[p])
    return dict(ts=ts, map=std_map(rom, m), mt_dmg_out=mt_dmg['out'], mt_dmg_in=mt_dmg['in'],
                dmg_tiles=bytes(dmg_tiles), n_dmg=len(var), cgb_bg_out=cgb_bg['out'],
                cgb_bg_in=cgb_bg['in'], cgb_obj=cgb_obj, obp=bytes(obj_shades(p) for p in sppal))


OW_INFO, OW_CHR, INIT_UNSRAM = 0x8000, 0x8000, 0xB000   # BANK_OWINFO / BANK_MAPCHR / STARTUPINFO


def ow_row(rom, row):
    """overworld row (256 metatiles), decompressed as FF1's row loader does"""
    ptr = rom.rd(1, 0x8000 + 2 * row) | rom.rd(1, 0x8001 + 2 * row) << 8
    out = bytearray(); p = ptr
    while len(out) < 256:
        a = rom.rd(1, p)
        if a == 0xFF: break
        if a < 0x80:
            out.append(a); p += 1
        else:
            n = rom.rd(1, p + 1)
            out += bytes([a & 0x7F]) * (n if n else 256); p += 2
    return bytes(out[:256].ljust(256, b'\0'))


def ow_pack(rom, cls=0):
    """the overworld: tileset (properties, metatiles, palettes, 256 BG tiles), DMG pre-shaded
    tiles, the 256 rows"""
    blk = rom.rd(BANK_SMINFO, OW_INFO, 0x400)
    prop, tsa, attr, pal = blk[:256], blk[256:768], blk[768:896], bytearray(blk[0x380:0x3B0])
    mp = rom.rd(BANK_SMINFO, MAPMAN_PAL + 2 * cls, 2)
    pal[0x12], pal[0x16] = mp[0], mp[1]
    mt_pal = bytes(a & 3 for a in attr)
    chr_ = rom.rd(BANK_MAPCHR, OW_CHR, 0x1000)
    bg = [[pal[0]] + list(pal[4 * p + 1:4 * p + 4]) for p in range(4)]
    msh = map_shades(bg)
    var = {}; dmg = bytearray(); tbl = bytearray(512)
    for k in range(4):
        for mt in range(128):
            nt, p = tsa[128 * k + mt], mt_pal[mt]
            key = (nt, tuple(msh[c] for c in bg[p]))
            if key not in var:
                var[key] = len(var); dmg += gb_tile(chr_[16 * nt:16 * nt + 16], key[1])
            tbl[128 * k + mt] = var[key]
    assert len(var) <= 256
    sppal = [[pal[0x10]] + list(pal[0x10 + 4 * p + 1:0x10 + 4 * p + 4]) for p in range(2)]
    return dict(prop=prop, tsa=tsa, mt_pal=mt_pal,
                cgb_tiles=b''.join(gb_tile(chr_[16 * t:16 * t + 16]) for t in range(256)),
                cgb_bg=b''.join(rgb555(c).to_bytes(2, 'little') for p in range(4) for c in bg[p]),
                cgb_obj=b''.join(rgb555(c).to_bytes(2, 'little') for p in range(2) for c in sppal[p]),
                obp=bytes(obj_shades(p) for p in sppal), mt_dmg=bytes(tbl), dmg_tiles=bytes(dmg),
                rows=[ow_row(rom, r) for r in range(256)],
                start=(rom.rd(BANK_SMINFO, INIT_UNSRAM + 0x10) + 7) & 0xFF,
                start_y=(rom.rd(BANK_SMINFO, INIT_UNSRAM + 0x11) + 7) & 0xFF)


def common_pack(rom, cls=0):
    """the party sprite, FF1's sprite tables, the teleport tables"""
    spr = rom.rd(BANK_MAPCHR, MAPMAN_CHR + 0x100 * cls, 0x100)
    tele = b''.join(rom.rd(BANK_SMINFO, a, 64) for a in (NORM_TELE_X, NORM_TELE_Y, NORM_TELE_MAP))
    tele += rom.rd(BANK_SMINFO, EXIT_TELE_X, 16) + rom.rd(BANK_SMINFO, EXIT_TELE_Y, 16)
    tele += b''.join(rom.rd(BANK_SMINFO, a, 32) for a in (ENTR_TELE_X, ENTR_TELE_Y, ENTR_TELE_MAP))
    return dict(spr_tiles=b''.join(gb_tile(spr[16 * t:16 * t + 16]) for t in range(16)),
                mapman=mapman_table(rom), tele=tele)


def db(name, data, per=16):
    out = ['%s:' % name]
    for i in range(0, len(data), per):
        out.append('            db ' + ', '.join('$%02X' % b for b in data[i:i + per]))
    return '\n'.join(out) + '\n'
