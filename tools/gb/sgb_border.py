"""Super Game Boy border for the GB builds, drawn here (no game graphics): a dark blue
patterned field, an FF-style window frame (white / grey lines, rounded corners, blue band)
around the 160x144 screen, and four crystal diamonds (earth, fire, water, wind) at the
frame's corners.
make() -> (chr bytes (SNES 4bpp, n tiles * 32), pct bytes (map $000-$6FF + palettes 4-7 at
$800), n tiles). preview(path) saves the border as a PNG (the screen area shown grey).
usage: sgb_border.py OUT.png"""
import sys

W, H = 256, 224
SX, SY = 48, 40                     # GB screen position (8x8 cells 6-25, 5-22)

# palette 4 (index 0 unused: transparent)
PAL = [
    (0, 0, 0),          # 0 (transparent)
    (6, 6, 26),         # 1 navy dark
    (12, 14, 52),       # 2 navy
    (20, 26, 84),       # 3 blue (pattern)
    (40, 56, 150),      # 4 window blue
    (70, 96, 200),      # 5 window blue light
    (250, 250, 250),    # 6 white
    (168, 168, 176),    # 7 grey
    (96, 96, 108),      # 8 dark grey
    (220, 60, 40),      # 9 fire
    (255, 160, 90),     # 10 fire light
    (60, 170, 70),      # 11 earth
    (150, 230, 120),    # 12 earth light
    (50, 110, 230),     # 13 water
    (140, 200, 255),    # 14 water light
    (240, 220, 80),     # 15 wind (yellow)
]


def draw():
    img = [[1] * W for _ in range(H)]
    for y in range(H):                       # field: fine diagonal lattice
        for x in range(W):
            d = (x + y) % 16; e = (x - y) % 16
            if d == 0 or e == 0: img[y][x] = 2
            if (x + y) % 32 == 0 and (x - y) % 32 == 0: img[y][x] = 3
    # window frame: band of 12 px around the screen
    x0, y0, x1, y1 = SX - 12, SY - 12, SX + 160 + 11, SY + 144 + 11
    def inside_round(x, y, ax0, ay0, ax1, ay1, r):
        cx = min(max(x, ax0 + r), ax1 - r); cy = min(max(y, ay0 + r), ay1 - r)
        return (x - cx) ** 2 + (y - cy) ** 2 <= r * r
    for y in range(y0 - 2, y1 + 3):
        for x in range(x0 - 2, x1 + 3):
            if not (0 <= x < W and 0 <= y < H): continue
            if inside_round(x, y, x0 - 2, y0 - 2, x1 + 2, y1 + 2, 6):
                img[y][x] = 8                                   # dark outer edge
            if inside_round(x, y, x0 - 1, y0 - 1, x1 + 1, y1 + 1, 5):
                img[y][x] = 6                                   # white line
            if inside_round(x, y, x0 + 1, y0 + 1, x1 - 1, y1 - 1, 4):
                img[y][x] = 7                                   # grey line
            if inside_round(x, y, x0 + 2, y0 + 2, x1 - 2, y1 - 2, 3):
                img[y][x] = 4 if (y - y0) < 6 or (x - x0) < 6 else 4   # blue band
                if (y - y0) in (3, 4) or (x - x0) in (3, 4): img[y][x] = 5
    for y in range(SY - 2, SY + 146):                            # inner white rim
        for x in range(SX - 2, SX + 162):
            if SX - 2 <= x < SX + 162 and SY - 2 <= y < SY + 146:
                if x in (SX - 2, SX + 161) or y in (SY - 2, SY + 145): img[y][x] = 6
                elif x in (SX - 1, SX + 160) or y in (SY - 1, SY + 144): img[y][x] = 8
    for y in range(SY, SY + 144):                                # the GB screen: transparent
        for x in range(SX, SX + 160): img[y][x] = 0
    # crystals at the corners of the frame
    def crystal(cx, cy, dark, light):
        for dy in range(-11, 12):
            w = 7 - abs(dy) * 7 // 11
            for dx in range(-w, w + 1):
                c = light if dx < 0 or (dx == 0 and dy < 0) else dark
                if abs(dx) == w or abs(dy) == 11: c = 6 if dy < 0 else 8
                img[cy + dy][cx + dx] = c
        img[cy - 5][cx - 2] = 6; img[cy - 4][cx - 2] = 6; img[cy - 4][cx - 3] = 6
    crystal(x0 + 1, y0 + 1, 11, 12)          # earth
    crystal(x1 - 1, y0 + 1, 9, 10)           # fire
    crystal(x0 + 1, y1 - 1, 13, 14)          # water
    crystal(x1 - 1, y1 - 1, 15, 6)           # wind
    return img


def tiles_of(img):
    """8x8 tiles with flips de-duplicated -> (tile list, map entries)"""
    tiles, index, mp = [], {}, []
    for ty in range(H // 8):
        for tx in range(W // 8):
            t = tuple(tuple(img[ty * 8 + r][tx * 8 + c] for c in range(8)) for r in range(8))
            found = None
            for hf in (0, 1):
                for vf in (0, 1):
                    u = t
                    if hf: u = tuple(tuple(reversed(r)) for r in u)
                    if vf: u = tuple(reversed(u))
                    if u in index: found = (index[u], hf, vf); break
                if found: break
            if not found:
                index[t] = len(tiles); tiles.append(t); found = (index[t], 0, 0)
            mp.append(found)
    return tiles, mp


def make():
    img = draw()
    tiles, mp = tiles_of(img)
    if len(tiles) > 256: raise SystemExit('SGB border: %d tiles (max 256)' % len(tiles))
    chr_ = bytearray()
    for t in tiles:
        lo, hi = bytearray(), bytearray()
        for r in t:
            p = [0, 0, 0, 0]
            for c, v in enumerate(r):
                for b in range(4):
                    if v >> b & 1: p[b] |= 0x80 >> c
            lo += bytes([p[0], p[1]]); hi += bytes([p[2], p[3]])
        chr_ += lo + hi
    pct = bytearray(0x880)
    for i, (t, hf, vf) in enumerate(mp):
        v = t | 4 << 10 | hf << 14 | vf << 15
        pct[2 * i] = v & 0xFF; pct[2 * i + 1] = v >> 8
    for i, (r, g, b) in enumerate(PAL):
        c = (r >> 3) | (g >> 3) << 5 | (b >> 3) << 10
        pct[0x800 + 2 * i] = c & 0xFF; pct[0x801 + 2 * i] = c >> 8
    return bytes(chr_), bytes(pct), len(tiles)


def preview(path):
    from PIL import Image
    img = draw()
    im = Image.new('RGB', (W, H))
    for y in range(H):
        for x in range(W):
            im.putpixel((x, y), (120, 120, 120) if img[y][x] == 0 else PAL[img[y][x]])
    im.save(path)


if __name__ == '__main__':
    c, p, n = make()
    print('tiles', n)
    preview(sys.argv[1])
