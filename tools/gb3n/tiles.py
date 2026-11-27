"""Our own tiles for the FF3 Game Boy Color build (no game data): the Latin font and a window
frame, in Game Boy 2bpp. The font is the project's (tools/latin_font.py); tile number = ASCII code
(32-126), frame tiles 1-8, tile 0 blank (colour 0)."""
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
from latin_font import G, tile as nes_tile

FRAME = {'TL': 1, 'T': 2, 'TR': 3, 'L': 4, 'R': 5, 'BL': 6, 'B': 7, 'BR': 8}


def gb(nes16):
    """NES planar (8 low bytes, 8 high bytes) -> Game Boy (low, high per row)"""
    return bytes(b for y in range(8) for b in (nes16[y], nes16[8 + y]))


def from_pixels(px):
    """8 rows of 8 colour values -> a Game Boy tile"""
    out = bytearray()
    for row in px:
        lo = hi = 0
        for x, c in enumerate(row):
            if c & 1: lo |= 0x80 >> x
            if c & 2: hi |= 0x80 >> x
        out += bytes((lo, hi))
    return bytes(out)


def frame_tiles(outer=3, inner=1):
    """window frame: a line of `outer` one pixel in from the cell edge, a line of `inner` inside it
    (as the mock-up, build/mock3/cgbonly.png B); returns {name: tile}"""
    W = 24
    px = [[0] * W for _ in range(W)]
    for i, c in ((1, outer), (2, inner)):
        for k in range(i, W - i):
            px[i][k] = px[W - 1 - i][k] = px[k][i] = px[k][W - 1 - i] = c
    # (the outer line drawn last so it wins at the corners)
    for k in range(1, W - 1):
        px[1][k] = px[W - 2][k] = px[k][1] = px[k][W - 2] = outer
    cell = lambda cx, cy: [r[8 * cx:8 * cx + 8] for r in px[8 * cy:8 * cy + 8]]
    pos = {'TL': (0, 0), 'T': (1, 0), 'TR': (2, 0), 'L': (0, 1), 'R': (2, 1), 'BL': (0, 2),
           'B': (1, 2), 'BR': (2, 2)}
    return {n: from_pixels(cell(*p)) for n, p in pos.items()}


def tileset(fg=3, bg=0):
    """256 tiles: font at its ASCII codes, frame at 1-8"""
    t = [bytes(16)] * 256
    for ch in G:
        if len(ch) == 1 and 32 <= ord(ch) < 127:
            t[ord(ch)] = gb(nes_tile(ch, fg, bg))
    for n, data in frame_tiles().items():
        t[FRAME[n]] = data
    return t


def screen(rows):
    """20 x 18 map from [(row, col or None to centre, text)] and [('frame', x, y, w, h)]"""
    m = [[0] * 20 for _ in range(18)]
    for item in rows:
        if item[0] == 'frame':
            _, x, y, w, h = item
            for k in range(x + 1, x + w - 1):
                m[y][k] = FRAME['T']; m[y + h - 1][k] = FRAME['B']
            for k in range(y + 1, y + h - 1):
                m[k][x] = FRAME['L']; m[k][x + w - 1] = FRAME['R']
            m[y][x], m[y][x + w - 1] = FRAME['TL'], FRAME['TR']
            m[y + h - 1][x], m[y + h - 1][x + w - 1] = FRAME['BL'], FRAME['BR']
        else:
            r, c, s = item
            if c is None: c = (20 - len(s)) // 2
            for i, ch in enumerate(s): m[r][c + i] = ord(ch)
    return bytes(b for row in m for b in row)


# The "Game Boy Color only" screen (owner chose variant B, 2026-11-27); wording with Nintendo's
# hardware names (Lot Check 3.3 / 4.1)
CGB_ONLY = [(2, None, 'FINAL FANTASY III'), ('frame', 1, 5, 18, 11),
            (7, None, 'This Game Pak is'), (9, None, 'designed only'),
            (11, None, 'for use on the'), (13, None, 'Game Boy Color.')]
