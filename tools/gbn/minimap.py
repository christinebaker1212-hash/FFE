"""FF1 native build: the world map (FF1's minimap, bank 9: EnterMinimap). FF1 builds it at run
time from the overworld rows: each pixel is a 2 x 2 block of map tiles, the OR of their colours
in lut_MinimapTileset (bit 2: a town / dungeon marker). The overworld never changes, so here the
128 x 128 picture is made at build time from the user's ROM (the same rule), as 16 x 16 tiles;
FF1's single-pixel marker sprites are grouped into 8 x 8 sprites (the Game Boy has 40 sprites).

Bank MINI_BANK: $4000 the 256 tiles (CGB: FF1's colour indices), $5000 for DMG (indices
remapped to shades by brightness), $6000 sprite tiles (0: FF1's "you are here" mark, then the
marker groups), $6200 marker sprites (count, then y, x, tile in OAM coordinates), $6300 the
BG palette (4 x RGB555), $6308 the tile id of an empty tile (for the cells around the map),
$6309 FF1's palette colours (4)."""
import data

MINI_BANK = 97
BANK_MINIMAP = 9
TILESET_LUT, SPR_CHR, BG_PAL = 0xBF80, 0xBF00, 0xBF20
MAP_X, MAP_Y = 16, 8                     # the picture's place on the screen (pixels)


def bank(rom):
    t = rom.rd(BANK_MINIMAP, TILESET_LUT, 128)
    rows = data.ow_pack(rom)['rows']
    img = [[0] * 128 for _ in range(128)]
    marks = []
    for y in range(128):
        for x in range(128):
            v = 0
            for dy in (0, 1):
                for dx in (0, 1):
                    v |= t[rows[2 * y + dy][2 * x + dx] & 0x7F]
            img[y][x] = v & 3
            if v & 4: marks.append((y, x))
    pal = rom.rd(BANK_MINIMAP, BG_PAL, 4)
    order = sorted(range(4), key=lambda i: -data.lum(pal[i]))
    shade = [0] * 4
    for s, i in enumerate(order): shade[i] = s
    blob = bytearray(b'\0' * 0x4000)
    zero = None
    for i in range(256):
        ty, tx = divmod(i, 16)
        cgb, dmg = bytearray(), bytearray()
        for yy in range(8):
            row = img[8 * ty + yy][8 * tx:8 * tx + 8]
            for vals, out in ((row, cgb), ([shade[v] for v in row], dmg)):
                lo = hi = 0
                for x, v in enumerate(vals):
                    lo |= (v & 1) << (7 - x); hi |= (v >> 1) << (7 - x)
                out += bytes([lo, hi])
        blob[16 * i:16 * i + 16] = cgb
        blob[0x1000 + 16 * i:0x1000 + 16 * i + 16] = dmg
        if zero is None and not any(cgb): zero = i
    assert zero is not None, 'minimap: no empty tile'
    spr = rom.rd(BANK_MINIMAP, SPR_CHR, 32)
    tiles = [data.gb_tile(spr[:16])]
    sprites = []
    left = sorted(marks)
    while left:                                         # 8 x 8 groups
        y0, x0 = left[0]
        xs = min(x for y, x in left if y0 <= y < y0 + 8 and abs(x - x0) < 8)
        g = [(y, x) for y, x in left if y0 <= y < y0 + 8 and xs <= x < xs + 8]
        left = [p for p in left if p not in g]
        lo = [0] * 8; hi = [0] * 8
        for y, x in g:
            hi[y - y0] |= 0x80 >> (x - xs)               # (colour 2, as FF1's one-pixel dot)
        tiles.append(bytes(b for r in range(8) for b in (lo[r], hi[r])))
        sprites.append((MAP_Y + y0 + 16, MAP_X + xs + 8, len(tiles) - 1))
    assert len(sprites) <= 39 and len(tiles) <= 32
    for i, tl in enumerate(tiles): blob[0x2000 + 16 * i:0x2010 + 16 * i] = tl
    blob[0x2200] = len(sprites)
    for i, s in enumerate(sprites): blob[0x2201 + 3 * i:0x2204 + 3 * i] = bytes(s)
    blob[0x2300:0x2308] = b''.join(data.rgb555(c).to_bytes(2, 'little') for c in pal)
    blob[0x2308] = (zero + 0x80) & 0xFF
    blob[0x2309:0x230D] = pal
    return bytes(blob)
