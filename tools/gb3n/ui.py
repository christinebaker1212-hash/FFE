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
        lines, cur = [], []                             # (up to 4 lines of 48 pixels: the place
        for wd in nm.replace('Underground', 'Under- ground').split(' '):   #   window, mm.s; the one
                                                        #   word wider than it hyphenated)
            if cur and width(text.encode(' '.join(cur + [wd]))) > 48:
                lines.append(' '.join(cur)); cur = []
            cur.append(wd)
        lines.append(' '.join(cur))
        if t in ids:
            assert len(lines) <= 4 and all(width(text.encode(x)) <= 48 for x in lines), nm
        e = b'\x01'.join(text.encode(x) for x in lines)
        out.append(e if t in ids else b'')
    return out


GB_WORDS = {'U_LV': 'LV', 'U_HP': 'HP', 'U_GIL': 'Gil', 'U_CAP': 'Capacity', 'U_CONFIG': 'Config',
            'U_WORLD': 'World Map', 'U_OPT': 'Optimize', 'U_REMOVE': 'Remove', 'U_COST': 'Cost'}


def sight_data(rom, rgb555):
    """the Sight spell's minimap (sight.s, FF3 3A/88A3): colours by metatile (3A/8080; 3A/8100 for
    metatiles 64-127 on world sets 1 / 2), the map's palette (3A/8050; 3A/8060 + 4 on set 2), the
    sprites' colours (3A/8986: $0F, $37, $00, $10, $20), their tiles 1 / 2 (3A/8180)"""
    from data import nes2gb
    col, pal = bytearray(), bytearray()
    for k in range(3):
        t = bytearray(rom.b(0x3A, 0x8080, 128))
        if k:
            t[64:128] = rom.b(0x3A, 0x8100 + (0x40 if k == 2 else 0), 64)
        col += t
        p = rom.b(0x3A, 0x8050, 4) if k == 0 else rom.b(0x3A, 0x8060 + ((k << 1) & 4), 4)
        for c in p:
            v = rgb555(c); pal += bytes([v & 0xFF, v >> 8])
    w = lambda c: bytes([rgb555(c) & 0xFF, rgb555(c) >> 8])
    fl = w(0x0F) + w(0x37) + w(0x00) + w(0x0F) + w(0x0F) + w(0x37) + w(0x00) + w(0x10) + w(0x20) + w(0x0F)
    spr = rom.b(0x3A, 0x8180 + 16, 32)
    spr = nes2gb(spr[:16]) + nes2gb(spr[16:])
    def db(label, data):
        return '%s:\n' % label + ''.join('    db %s\n' % ', '.join(str(v) for v in data[k:k + 16])
                                         for k in range(0, len(data), 16))
    return db('SG_COL', col) + db('SG_PAL', pal) + db('SG_FL', fl), spr


def code_data(rom, rgb555, group_world, bank):
    import re
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
    def wrap(i):                                        # (FF3's message, re-wrapped to the window's
        raw = text.decode(text.raw_string(rom, 't8200', i)).replace('[77][79]', 'HP')
        keep = [clean(x) for x in raw.split('\n') if clean(x)]
        if all(width(text.encode(x)) <= 144 for x in keep):  #   144 pixels; FF3's own lines when
            return b'\x01'.join(text.encode(x) for x in keep)   #   they fit)
        t = clean(raw)
        lines, cur = [], []
        for wd in t.split(' '):
            if cur and width(text.encode(' '.join(cur + [wd]))) > 144:
                lines.append(' '.join(cur)); cur = []
            cur.append(wd)
        lines.append(' '.join(cur))
        return b'\x01'.join(text.encode(x) for x in lines)
    msgs = [wrap(i) for i in range(0x5A, 0x7A)]         # (FF3's prompts / messages $5A-$79)
    src += strtab('U_MSG', msgs)
    src += db('U_MJOB', wrap(0x3A) + b'\0')              # (the Job screen: $013A)
    src += db('U_ITEMW', text.encode(clean(text.decode(text.raw_string(rom, 't8200', 0x35)))) + b'\0')
    src += db('U_DEF', text.encode(w['s_def'].rstrip('…').strip()) + b'\0')
    sd, spr = sight_data(rom, rgb555)
    src += sd
    lab = menu.status_labels(rom)                      # (the Status screen: FF3's words, t8200 $47)
    stw = ['Proficiency', 'Strength', 'Agility', 'Stamina', 'Intelligence', 'Spirit', 'To next level',
           'Attack', 'Hit rate', 'Defense', 'Evasion rate', 'Magic defense']
    for x in stw: assert x in lab, x
    stw += ['Magic evasion', 'EXP', 'MP']
    src += strtab("U_STW", [text.encode(x) for x in stw])
    sv = text.decode(text.raw_string(rom, 't8200', 0x4C))  # (the file screen: FF3's $4B-$4D, Yes / No)
    m = re.match(r'(.*?)\{15:[0-9A-F]+\}(\w+)\{15:[0-9A-F]+\}(\w+)', sv, re.S)
    assert m, sv
    src += db('U_SV0', text.encode(clean(text.decode(text.raw_string(rom, 't8200', 0x4B)))) + b'\0')
    src += db('U_SV1', text.encode(clean(m.group(1))) + b'\0')
    src += db('U_YES', text.encode(m.group(2)) + b'\0') + db('U_NO', text.encode(m.group(3)) + b'\0')
    src += db('U_SV2', text.encode(clean(text.decode(text.raw_string(rom, 't8200', 0x4D)))) + b'\0')
    gt = menu.GB_TEXT
    src += db('U_OFF', text.encode(gt['s_off']) + b'\x01' + text.encode(gt['s_off2']) + b'\0')
    src += db('U_SUS', text.encode(gt['s_cs1']) + b'\x01' + text.encode(gt['s_cs2']) + b'\0')
    src += db('U_SPD', text.encode(gt['s_spd']) + b'\0')
    ng = re.sub(r'\{[^}]*\}', '', text.decode(text.raw_string(rom, 't8200', 0x22))).strip()
    src += db('U_NEWG', text.encode(ng) + b'\0')
    for k, v in (('U_USE', 's_use'), ('U_SWAP', 's_swap'), ('U_MITEM', 's_item')):
        src += db(k, text.encode(w[v]) + b'\0')          # (the Magic screen: FF3's Use / Swap / Item)
    # (tiles copied by DMA: 16-byte aligned, at the bank's end)
    src += 'section bank %d, $7FD0\n' % bank + db('U_ZTILE', bytes(16)) + db('SG_SPR', spr)
    return src
