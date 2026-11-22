"""FF3 native engine: build-time tables for the field menus (owner-approved main menu mock N5B / N6:
party window with one block per member, job names condensed, HP in the English font, the MP of the
8 levels in 3-pixel digits with slashes, commands at the right, Gil / Capacity in small digits).

Everything game-specific is read from the user's English ROM: job names (t8200 $E2 + job), the
command words (t8200 $0131), the menu palettes (fix:E1BC), the cursor graphics (0D/B400). The
letter shapes for the condensed names and the small digits are this project's own
(tools/latin_font.py and the digit rows below).

MENU_BANK layout:
  $4000  job names: 22 x 12 tiles (GB format, colour 3 on colour 2), $5080 their tile counts
  $5100  MP tiles: "0/".."9/" then "0".."9" (20 tiles)
  $5300  small digits for run-time numbers: 10 x 5 rows (3 bits, bit 2 = left column)
  $5340  the menu palettes (32 NES colours -> RGB555, 64 bytes)
  $5400  cursor / misc sprite tiles (0D/B400, 32 tiles, GB format)
  $5600  command words: 7 x 8 bytes (font codes, $FF padded); $5640 the hand's frame (OAM order)
"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..'))
import text
from data import nes2gb

# 3 x 5 digits (this project's), rows top to bottom
DIG = {
    '0': ['###', '#.#', '#.#', '#.#', '###'], '1': ['.#.', '##.', '.#.', '.#.', '###'],
    '2': ['###', '..#', '###', '#..', '###'], '3': ['###', '..#', '.##', '..#', '###'],
    '4': ['#.#', '#.#', '###', '..#', '..#'], '5': ['###', '#..', '###', '..#', '###'],
    '6': ['###', '#..', '###', '#.#', '###'], '7': ['###', '..#', '.#.', '.#.', '.#.'],
    '8': ['###', '#.#', '###', '#.#', '###'], '9': ['###', '#.#', '###', '..#', '###'],
}
SLASH = ['..#', '..#', '.#.', '#..', '#..']


def tile_from_cols(cols, fg=3, bg=2):
    lo = bytearray(8); hi = bytearray(8)
    for y in range(8):
        for x in range(8):
            c = fg if x < len(cols) and cols[x][y] else bg
            if c & 1: lo[y] |= 0x80 >> x
            if c & 2: hi[y] |= 0x80 >> x
    return bytes(b for r in range(8) for b in (lo[r], hi[r]))       # GB format


def glyph_cols(rows, top=2):
    w = len(rows[0])
    return [[1 if top <= y < top + 5 and rows[y - top][x] == '#' else 0 for y in range(8)] for x in range(w)]


def mp_tiles():
    out = []
    for d in '0123456789':                      # "d/": digit, gap, slash
        out.append(tile_from_cols(glyph_cols(DIG[d]) + [[0] * 8] + glyph_cols(SLASH)))
    for d in '0123456789':
        out.append(tile_from_cols([[0] * 8] * 2 + glyph_cols(DIG[d])))
    return out


def job_names(rom):
    from latin_font import packed_label, COND, TIGHT
    names = []
    for j in range(22):
        nm = text.decode(text.raw_string(rom, 't8200', 0xE2 + j)).rstrip(' ')
        nm = ''.join(ch for ch in nm if ch.isalnum() or ch in " '-.")
        names.append(nm)
    tiles = []
    for nm in names:
        t = None
        for n in range(1, 13):
            t = packed_label(nm, n, COND, fg=3, bg=2) or packed_label(nm, n, TIGHT, fg=3, bg=2)
            if t: break
        assert t, nm
        tiles.append([bytes(b for r in range(8) for b in (tl[r], tl[8 + r])) for tl in t])
    return names, tiles


def commands(rom):
    s = text.raw_string(rom, 't8200', 0x31)
    words = []; cur = bytearray(); k = 0
    while k < len(s):
        c = s[k]; k += 1
        if c == 0x01: words.append(bytes(cur)); cur = bytearray()
        elif 0x10 <= c < 0x28: k += 1
        elif c >= 0x28: cur.append(c)
    words.append(bytes(cur))
    return words


# the words of the GB-only screens (Select menu, suspend point): this project's text
GB_TEXT = {
    's_opt': 'Options', 's_sus': 'Suspend', 's_spd': 'Battle Speed', 's_bgm': 'Music Volume',
    's_sfx': 'Sound Volume', 's_sq1': 'Create a Suspend', 's_sq2': 'Point and return',
    's_sq3': 'to the Title?', 's_sq4': '', 's_yes': 'Yes', 's_no': 'No',
}
GB_TEXT_AT = 0x5800


def gb_text():
    """(bytes at MENU_BANK $5800, {label: address})"""
    out = bytearray(); syms = {}
    for k, v in GB_TEXT.items():
        syms[k] = 0x4000 + GB_TEXT_AT - 0x4000 + len(out) + 0x0000
        out += text.encode(v) + b'\0'
    return bytes(out), syms


def pack(rom, rgb555):
    b = bytearray(0x4000)
    names, tiles = job_names(rom)
    for j, ts in enumerate(tiles):
        for k, t in enumerate(ts[:12]):
            b[12 * 16 * j + 16 * k:12 * 16 * j + 16 * k + 16] = t
        b[0x1080 + j] = min(len(ts), 12)
    for k, t in enumerate(mp_tiles()):
        b[0x1100 + 16 * k:0x1110 + 16 * k] = t
    for i, d in enumerate('0123456789'):
        for y in range(5):
            b[0x1300 + 5 * i + y] = int(DIG[d][y].replace('#', '1').replace('.', '0'), 2)
    pal = rom.b(0x7F, 0xE1BC, 32)
    for k, c in enumerate(pal):
        v = rgb555(c)
        b[0x1340 + 2 * k] = v & 0xFF; b[0x1341 + 2 * k] = v >> 8
    cur = rom.prg[0x0D * 0x2000 + 0x1400:0x0D * 0x2000 + 0x1600]
    b[0x1400:0x1600] = b''.join(nes2gb(cur[16 * k:16 * k + 16]) for k in range(32))
    fr = rom.b(0x7E, 0xDCF2, 8)                 # the hand (FD5EB: frame 3E/DCF2, tiles + $E4,
    cv = lambda a: ((a & 3) + 4) | 8 | ((a & 0x40) >> 1) | ((a & 0x80) >> 1)   # OBJ palette 3 -> 7)
    b[0x1640:0x1648] = bytes((v + 0xE4) & 0xFF if k % 2 == 0 else cv(v) for k, v in enumerate(fr))
    for k, w in enumerate(commands(rom)[:7]):
        w = w[:8]
        b[0x1600 + 8 * k:0x1600 + 8 * k + 8] = w + b'\xFF' * (8 - len(w))
    t, _ = gb_text()
    b[GB_TEXT_AT - 0x4000:GB_TEXT_AT - 0x4000 + len(t)] = t
    return b
