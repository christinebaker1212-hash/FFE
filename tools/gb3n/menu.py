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
import os, re, sys
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
    's_opt': 'Options', 's_sus': 'Suspend', 's_ext': 'Extras', 's_spd': 'Battle Speed', 's_bgm': 'Music Volume',
    's_sfx': 'Sound Volume', 's_sq1': 'Create a Suspend', 's_sq2': 'Point and return',
    's_sq3': 'to the Title?', 's_sq4': '', 's_yes': 'Yes', 's_no': 'No', 's_cap': 'Capacity',
    's_off': 'You can turn the', 's_off2': 'power off now.',
    's_cs1': 'Continue from', 's_cs2': 'Suspend point?',
}
GB_TEXT_AT = 0x5800


def rom_words(rom):
    """words of the ROM's menu strings: the magic menu's Use / Swap / Item (t8200 $36)"""
    t = text.decode(text.raw_string(rom, 't8200', 0x36))
    w = [x.strip() for x in re.split(r'\{[^}]*\}', t) if x.strip()]
    assert len(w) == 3, w
    d = {'s_use': w[0], 's_swap': w[1], 's_item': w[2]}
    t = text.decode(text.raw_string(rom, 't8200', 0x3E))       # equip: Attack… / Defense… / Remove
    m = re.search(r'(Attack…)', t); n = re.search(r'(Defense…)', t); r = re.search(r'(Remove [A-Za-z]+)', t)
    assert m and n and r, t
    d.update(s_atk=m.group(1), s_def=n.group(1), s_rem=r.group(1))
    for k, i in (('s_head', 0xDD), ('s_body', 0xDE), ('s_arms', 0xDF), ('s_rh', 0xE0), ('s_lh', 0xE1)):
        d[k] = text.decode(text.raw_string(rom, 't8200', i)).strip()
    return d


def gb_text(rom=None):
    """(bytes at MENU_BANK $5800, {label: address})"""
    out = bytearray(); syms = {}
    for k, v in list(GB_TEXT.items()) + list((rom_words(rom) if rom else {}).items()):
        syms[k] = 0x4000 + GB_TEXT_AT - 0x4000 + len(out) + 0x0000
        out += text.encode(v) + b'\0'
    return bytes(out), syms


STATUS_COND = ('Proficiency', 'Strength', 'Agility', 'Stamina', 'Intelligence', 'Spirit')
STATUS_BIG = ('To next level', 'Attack', 'Hit rate', 'Defense', 'Evasion rate', 'Magic defense',
              'Magic evasion')
STATUS_AT = 0x5900                              # big-font labels (codes), then condensed tiles


def status_labels(rom):
    """the status screen's words from t8200 $0147 (the ROM's English); "Magic evasion rate" as
    "Magic evasion" (owner-approved mock S5)"""
    t = text.decode(text.raw_string(rom, 't8200', 0x47))
    words = [w.strip(' .…') for w in re.split(r'\{[^}]*\}|\[[^]]*\]|\n|…', t)]
    words = [w for w in words if w and not w.isdigit() and w not in ('x',)]
    for w in STATUS_COND + STATUS_BIG[:-1]: assert w in words, (w, words)
    assert 'Magic evasion rate' in words
    return words


def status_pack(rom):
    """(bytes, {label: address}): codes of STATUS_BIG (0-terminated), then for each condensed
    word: count, tiles (GB format)"""
    from latin_font import packed_label, COND
    status_labels(rom)
    out = bytearray(); syms = {}
    for k, w in enumerate(STATUS_BIG):
        syms['st_b%d' % k] = STATUS_AT + len(out)
        out += text.encode(w) + b'\0'
    for k, w in enumerate(STATUS_COND):
        while (STATUS_AT + len(out) + 1) % 16: out.append(0)        # (DMA: tiles 16-aligned)
        syms['st_c%d' % k] = STATUS_AT + len(out)
        t = None
        for n in range(1, 10):
            t = packed_label(w, n, COND, fg=3, bg=2)
            if t: break
        out.append(len(t))
        out += b''.join(bytes(b for r in range(8) for b in (tl[r], tl[8 + r])) for tl in t)
    return bytes(out), syms


def code_data(rom, rgb555):
    """the small tables the menu code (bank CODE1) reads, as labelled assembly data next to it"""
    def db(label, data):
        out = '%s:\n' % label
        for k in range(0, len(data), 16):
            out += '    db %s\n' % ', '.join(str(v) for v in data[k:k + 16])
        return out
    pal = rom.b(0x7F, 0xE1BC, 32)
    pals = bytearray()
    for c in pal:
        v = rgb555(c); pals += bytes([v & 0xFF, v >> 8])
    dig = bytes(int(DIG[d][y].replace('#', '1').replace('.', '0'), 2) for d in '0123456789' for y in range(5))
    fr = rom.b(0x7E, 0xDCF2, 8)
    cv = lambda a: ((a & 3) + 4) | 8 | ((a & 0x40) >> 1) | ((a & 0x80) >> 1)
    hand = bytes((v + 0x10) & 0xFF if k % 2 == 0 else cv(v) for k, v in enumerate(fr))   # (tiles $10-)
    cmd = bytearray()
    for w in commands(rom)[:7]:
        w = w[:8]; cmd += w + b'\xFF' * (8 - len(w))
    names, tiles = job_names(rom)
    counts = bytes(min(len(t), 12) for t in tiles)
    src = db('MD_PALS', pals) + db('MD_DIGITS', dig) + db('MD_HAND', hand) + db('MD_CMD', cmd)
    src += db('MD_COUNTS', counts) + db('MD_EXP', rom.b(0x39, 0x80B0, 3 * 99))
    src += db('MD_MASKS', rom.equip_masks())
    for k, v in list(GB_TEXT.items()) + list(rom_words(rom).items()):
        src += db(k, text.encode(v) + b'\0')
    for k, w in enumerate(STATUS_BIG):
        src += db('st_b%d' % k, text.encode(w) + b'\0')
    return src


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
    b[0x1C00:0x1C00 + 3 * 99] = rom.b(0x39, 0x80B0, 3 * 99)    # $5C00: EXP for each level
    ic = rom.prg[0x0D * 0x2000 + 0x1500:0x0D * 0x2000 + 0x1700]  # $5E00: item icons (0D/B500)
    b[0x1E00:0x2000] = b''.join(nes2gb(ic[16 * k:16 * k + 16]) for k in range(32))
    b[0x2000:0x2300] = rom.equip_masks()                       # $6000: job masks per item / spell
    f = rom.prg[0x0D * 0x2000 + 0x1700:0x0D * 0x2000 + 0x1700 + 144 * 16]   # $6400: the font ($70-)
    b[0x2400:0x2400 + 144 * 16] = b''.join(nes2gb(f[16 * k:16 * k + 16]) for k in range(144))
    b[0x2E00:0x2E40] = b[0x1400 + 0x40:0x1400 + 0x80]          # $6E00: the hand's 4 tiles ($E4-)
    # $6D00: the Color-only message (row, column, codes, 0; 0 ends); TM: this project's glyph
    tm = ['###.#..#', '.#..####', '.#..#..#', '.#..#..#', '........', '........', '........', '........']
    lo = bytes(int(r.replace('#', '1').replace('.', '0'), 2) for r in tm)
    b[0x2400 + (0x7F - 0x70) * 16:0x2400 + (0x7F - 0x70) * 16 + 16] = bytes(x for r in range(8) for x in (lo[r], 0xFF))
    ar = ['........', '..#.....', '..##....', '#####...', '..##....', '..#.....', '........', '........']
    lo = bytes(int(r.replace('#', '1').replace('.', '0'), 2) for r in ar)   # $CA: the battle arrow
    b[0x2400 + (0xCA - 0x70) * 16:0x2400 + (0xCA - 0x70) * 16 + 16] = bytes(x for r in range(8) for x in (lo[r], 0xFF))
    msg = ['This Game Pak is', 'designed only for', 'use with the Game', 'Boy Color\x7f', 'system.']
    out = bytearray()
    for k, l in enumerate(msg):
        enc = bytes(0x7F if ch == '\x7f' else text.ENC[ch] for ch in l)
        out += bytes([5 + 2 * k, (20 - len(enc)) // 2]) + enc + b'\0'
    out += b'\0'
    b[0x2D00:0x2D00 + len(out)] = out
    t, _ = status_pack(rom)
    assert STATUS_AT + len(t) <= 0x5C00
    b[STATUS_AT - 0x4000:STATUS_AT - 0x4000 + len(t)] = t
    return b
