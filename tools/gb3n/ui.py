"""FF3 native engine: build-time data for the menus' UI library (src/ui.s, bank CODE11).

Owner (2026-11-28): one small font in every menu, Nintendo-level polish. The small font is FF1's
battle font (tools/latin_font.py: the condensed letters where there is one, the regular ones for
the rest; 3-pixel digits), our own drawing, no game data. The window frames and the item icons come
from the user's ROM (FF3's font, 0D/B500) at build time.

Glyph table U_GLY: FF3 text codes $80-$CF (digits, letters, signs), 9 bytes each: the width in
pixels, then 8 rows (left-aligned bits). Code $FF (space): 3 pixels. Icons ($60-$7F) are cells of
their own (ui.s)."""
import os, sys
import text

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..'))
import latin_font as L

DIG = {
    '0': ["###", "#.#", "#.#", "#.#", "#.#", "#.#", "###"], '1': [".#.", "##.", ".#.", ".#.", ".#.", ".#.", "###"],
    '2': ["###", "..#", "..#", "###", "#..", "#..", "###"], '3': ["###", "..#", "..#", ".##", "..#", "..#", "###"],
    '4': ["#.#", "#.#", "#.#", "###", "..#", "..#", "..#"], '5': ["###", "#..", "#..", "###", "..#", "..#", "###"],
    '6': ["###", "#..", "#..", "###", "#.#", "#.#", "###"], '7': ["###", "..#", "..#", ".#.", ".#.", ".#.", ".#."],
    '8': ["###", "#.#", "#.#", "###", "#.#", "#.#", "###"], '9': ["###", "#.#", "#.#", "###", "..#", "..#", "###"],
    '/': ["..#", "..#", ".#.", ".#.", ".#.", "#..", "#.."]}
FIRST, LAST = 0x80, 0xCF


def glyph_cols(ch):
    """pixel columns (8 rows each) of a character in the small font"""
    if ch in DIG:
        r = DIG[ch]
        return [[1 if y < 7 and r[y][x] == '#' else 0 for y in range(8)] for x in range(3)]
    if ch == '…':
        return [[0, 0, 0, 0, 0, 0, 1, 0]] * 1 + [[0] * 8] + [[0, 0, 0, 0, 0, 0, 1, 0]] + [[0] * 8] + \
               [[0, 0, 0, 0, 0, 0, 1, 0]]
    if ch in L.COND:
        return L._glyph_cols(ch, L.COND)
    if ch in L.G:
        return L._glyph_cols(ch, L.G)
    return []


def width(s):
    """the width in pixels of a string (FF3 codes) in the small font, as ui.s measures it"""
    w = 0
    for c in s:
        if c == 0xFF: w += 3
        elif 0x50 <= c < 0x70: w = (w + 7) // 8 * 8 + 8
        elif FIRST <= c <= LAST: w += len(glyph_cols(text.DEC.get(c, ''))) + 1
    return w


ARROW = 0xC9                    # (a code FF3's font leaves free: our arrow for the previews)
ARROW_G = ["....", "#...", ".#..", "..#.", ".#..", "#...", "...."]


def glyphs():
    out = bytearray()
    for c in range(FIRST, LAST + 1):
        if c == ARROW:
            cols = [[1 if y < 7 and ARROW_G[y][x] == '#' else 0 for y in range(8)] for x in range(3)]
        else:
            cols = glyph_cols(text.DEC.get(c, ''))
        assert len(cols) <= 8, (hex(c), len(cols))
        out.append(len(cols))
        for y in range(8):
            out.append(sum(cols[x][y] << (7 - x) for x in range(len(cols))))
    return bytes(out)


# the UI's palettes (CGB BG 0-7 while a menu covers the screen): colour 0 the letters' shadow
# (black), 1 the frame's dark line, 2 the window's fill, 3 the ink; one palette per ink colour
INKS = {'white': 0x30, 'label': 0x21, 'yellow': 0x38, 'green': 0x2A, 'grey': 0x10, 'red': 0x16,
        'icon': None, 'black': 0x0F}
PAL_ORDER = ('white', 'white', 'label', 'yellow', 'green', 'grey', 'red', 'black')   # (ui.s UP_*)
FILL, LINE, SHADOW = 0x02, 0x00, 0x0F


def palettes(rom, rgb555):
    """16 palettes x 4 colours as RGB555 (BG 0-7, OBJ 0-7): BG by PAL_ORDER; the icon palette is
    FF3's menu window palette (fix:E1BC, its icons' colours); OBJ 7 the hand"""
    out = bytearray()
    win = rom.b(0x7F, 0xE1BC, 4)
    for k in PAL_ORDER:
        cols = [SHADOW, LINE, FILL, INKS[k]]
        for c in cols:
            v = rgb555(c); out += bytes([v & 0xFF, v >> 8])
    for k in range(8):                                  # OBJ: members 0-3 (set by ui.s), 7 the hand
        cols = [0x0F, 0x0F, 0x10, 0x30]
        for c in cols:
            v = rgb555(c); out += bytes([v & 0xFF, v >> 8])
    return bytes(out)


def strtab(label, strings):
    """a table of words (pointers) then the strings, 0-terminated"""
    out = '%s:\n' % label + ''.join('    dw %s_%d\n' % (label, k) for k in range(len(strings)))
    for k, b in enumerate(strings):
        out += '%s_%d:\n    db %s\n' % (label, k, ', '.join(str(v) for v in bytes(b) + b'\0'))
    return out


def clean(s):
    import re
    s = re.sub(r'\{[^}]*\}|\[[^]]*\]', '', s)
    return ' '.join(s.split())


def titles(rom, group_world):
    import re
    """map title id -> its name (t8200 id), for every id the maps use; others empty"""
    ids = set()
    for g in range(3):
        for mid in range(256):
            ids.add(rom.map_props(mid, group_world(g))[2])
    out = []
    for t in range(256):
        nm = re.sub(r',? Part \d+$', '', clean(text.decode(text.raw_string(rom, 't8200', t))))
        e = text.encode(nm)
        if width(e) > 46:                               # (two lines in the place window)
            ws = nm.split(' ')
            for k in range(len(ws) - 1, 0, -1):
                if width(text.encode(' '.join(ws[:k]))) <= 46:
                    e = text.encode(' '.join(ws[:k])) + b'\x01' + text.encode(' '.join(ws[k:]))
                    break
        out.append(e if t in ids else b'')
    return out


GB_WORDS = {'U_LV': 'LV', 'U_HP': 'HP', 'U_GIL': 'Gil', 'U_CAP': 'Capacity', 'U_CONFIG': 'Config',
            'U_WORLD': 'World Map', 'U_OPT': 'Optimize', 'U_REMOVE': 'Remove'}


def code_data(rom, rgb555, group_world):
    import menu
    def db(label, data):
        return '%s:\n' % label + ''.join('    db %s\n' % ', '.join(str(v) for v in data[k:k + 16])
                                         for k in range(0, len(data), 16))
    names, _ = menu.job_names(rom)
    cmds = [bytes(c for c in w if c != 0xFF or True) for w in menu.commands(rom)[:7]]
    cmds = [w.rstrip(b'\xFF') for w in cmds] + [text.encode(GB_WORDS['U_CONFIG'])]
    cmds[3] = text.encode('Status')                     # (FF3 draws it in tiles $E1-$E4)
    src = db('U_GLY', glyphs()) + db('U_PALS', palettes(rom, rgb555))
    src += db('U_PFREE', rom.b(0x2E, 0x9E4A, 4)) + db('U_PJOB', rom.b(0x2E, 0x9E4E, 22))
    src += strtab('U_JOBN', [text.encode(n) for n in names])
    src += strtab('U_CMD', cmds)
    src += strtab('U_TITLE', titles(rom, group_world))
    for k, v in GB_WORDS.items():
        src += db(k, text.encode(v) + b'\0')
    w = menu.rom_words(rom)                             # (FF3's: the slots, Remove Equipment)
    slots = [w['s_rh'], w['s_lh'], w['s_head'], w['s_body'], w['s_arms']]
    src += strtab('U_SLOTN', [text.encode(x) for x in slots])
    src += db('U_REM', text.encode(w['s_rem']) + b'\0')
    src += db('U_ATK', text.encode(w['s_atk'].rstrip('…').strip()) + b'\0')
    src += db('U_ARROW', bytes([ARROW, 0]))
    src += db('U_DEF', text.encode(w['s_def'].rstrip('…').strip()) + b'\0')
    return src
