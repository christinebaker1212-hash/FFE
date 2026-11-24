"""FF1 native build: text. The font is our own (tools/latin_font.py), the window frame
tiles come from the user's ROM (FF1's menu graphics, $F7-$FF); the English text comes from
the project's translation (translations/ff1_*.py), wrapped for the Game Boy layouts.
Native encoding: ASCII $20-$7E ('…' = $7F), frame tiles $10-$18 (FF1 $F7-$FF), controls:
$00 end, $0A next line, $0C next page (wait for A), $02 the item name (treasure)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..'))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'translations'))
import latin_font
import data

MENU_CHR = 0x8800                      # BANK_MENUCHR (9): FF1's menu tiles $80-$FF
WIN_PAL = (0x0F, 0x00, 0x01, 0x30)     # FF1's window colours: outside, border, inside, text
DMG_WIN = (3, 2, 3, 0)                 # DMG: black window, dark grey border, white text
DLG_W, DLG_H = 18, 6                   # dialogue box text area (the approved layout)


def code_of(ch):
    return 0x7F if ch == '…' else ord(ch)


def font_tiles(rom, ff3=None):
    """{code: NES tile} for the frame, the glyphs (colour 2 background, 3 ink) and FF3's
    icons (names.ICONS)"""
    import names
    menu = rom.rd(9, MENU_CHR, 0x800)
    out = {}
    for i, t in enumerate(range(0xF7, 0x100)):
        out[0x10 + i] = menu[(t - 0x80) * 16:(t - 0x80) * 16 + 16]
    out[0x20] = menu[(0xFF - 0x80) * 16:(0xFF - 0x80) * 16 + 16]   # space = the blank inside
    for ch in latin_font.G:
        out[code_of(ch)] = latin_font.tile(ch, fg=3, bg=2)
    out.update(names.icon_tiles(ff3))
    out[0x0A] = names.own_tile(PIP_FULL)     # magic shops: a level's slot used / free
    out[0x0B] = names.own_tile(PIP_FREE)
    return out


PIP_FULL = ['........', '..###...', '.#####..', '.#####..', '.#####..', '..###...', '........', '........']
PIP_FREE = ['........', '..###...', '.#...#..', '.#...#..', '.#...#..', '..###...', '........', '........']


DMG_ICON = (2, 1, 3, 0)                # DMG icons: outlines dark grey, details light grey


def font_banks(rom, ff3=None):
    """the font for DMG (pre-shaded) and CGB (as it is), 128 tiles by code"""
    import names
    f = font_tiles(rom, ff3)
    dmg = bytearray(2048); cgb = bytearray(2048)
    for code, t16 in f.items():
        dmg[16 * code:16 * code + 16] = data.gb_tile(t16, DMG_ICON if code in names.ICON_CODES else DMG_WIN)
        cgb[16 * code:16 * code + 16] = data.gb_tile(t16)
    return bytes(dmg), bytes(cgb)


def field_codes():
    """the font codes the field needs (DMG: loaded into each map's free tiles): the frame, the
    letters the dialogue and the item names use, and the icons"""
    import ff1_dialogue, ff1_items, names
    used = set()
    for t in list(ff1_dialogue.D.values()) + list(ff1_items.T.values()):
        t = t.replace('{02}', '')
        used |= set(code_of(ch) for ch in t if ch != '\n')
    used.add(0x20)
    return list(range(0x10, 0x19)) + sorted(c for c in used if 0x20 <= c < 0x80) + names.ICON_CODES


def win_palette():
    return b''.join(data.rgb555(c).to_bytes(2, 'little') for c in WIN_PAL)


def wrap(text, width=DLG_W):
    lines = []
    for para in text.split('\n'):
        line = ''
        for w in para.split(' '):
            if not w: continue
            if not line: line = w
            elif len(line) + 1 + len(w) <= width: line += ' ' + w
            else: lines.append(line); line = w
        if line: lines.append(line)
    return lines


SENT_END = '.!?'
CLOSERS = '.!?,;:~\'")]-'


STARTERS = {'At', 'If', 'This', 'These', 'That', 'Who', 'What', 'Where', 'When', 'Why', 'How', 'Uh',
            'Oh', 'Ohh', 'Anyone', 'Anything', 'Now', 'Well', 'Then', 'But', 'So', 'Yes', 'No', 'Please',
            'Thank', 'Hey', 'Look', 'Go', 'The', 'It', 'You', 'We', 'He', 'She', 'They', 'There', 'Here',
            'My', 'Our', 'Your'}
I_JOIN = {'and', 'or', 'but', 'shall', 'will', 'can', 'if', 'that', 'when', 'as', 'than', 'so'}


def _sentence_break(prev, nxt):
    """a translation line break that is the sentence break: the line has no closing punctuation
    and the next begins a sentence (an opener; "I" unless after a conjunction); signs in capitals
    keep their lines"""
    if prev[-1] in CLOSERS:
        return False
    if prev.isupper() and nxt.isupper():
        return True
    w = nxt.split()[0]
    if w == 'I' or w.startswith("I'"):
        return prev.split()[-1].lower() not in I_JOIN
    return w.strip(',.!?') in STARTERS


def paragraphs(text):
    """the text's lines joined with spaces, except where a line has no closing punctuation and
    the next begins with a capital: there the translation's line break is the sentence break
    ("...in the way / At this rate..."), so it stays a line break (no words added)"""
    out = []
    for ln in text.split('\n'):
        ln = ln.strip()
        if not ln: continue
        if out and out[-1] and not _sentence_break(out[-1], ln):
            out[-1] += ' ' + ln
        else:
            out.append(ln)
    return out


def wrap_bal(para, width=DLG_W):
    """the greedy wrap's number of lines, the breaks chosen so that the last line is not a lone
    short word and no line ends on the first word of a new sentence"""
    greedy = wrap(para, width)
    n = len(greedy)
    words = para.split()
    if n <= 1 or len(words) > 60:
        return greedy
    W = len(words)
    INF = float('inf')
    def cost(i, j, last):                       # words i..j-1 on one line
        ln = len(' '.join(words[i:j]))
        if ln > width: return INF
        if last:
            return (10 if ln <= 5 else 4) * max(0, 8 - ln) ** 2
        c = (width - ln) ** 2
        if words[j - 1][-1] not in SENT_END:            # (lines end at sentences' ends where
            c += 20                                     #   that costs little)
        if j - i > 1 and words[j - 2][-1] in SENT_END:   # ends on a new sentence's first word
            c += 40
        return c
    best = {(W, 0): (0, None)}
    from functools import lru_cache
    @lru_cache(None)
    def f(i, k):                                # words i.. on k lines
        if k == 1:
            return (cost(i, W, True), None)
        r = (INF, None)
        for j in range(i + 1, W - k + 2):
            c = cost(i, j, False)
            if c == INF: break
            t = f(j, k - 1)[0]
            if c + t < r[0]: r = (c + t, j)
        return r
    if f(0, n)[0] == INF:
        return greedy
    out, i, k = [], 0, n
    while k > 1:
        j = f(i, k)[1]
        out.append(' '.join(words[i:j])); i = j; k -= 1
    out.append(' '.join(words[i:]))
    return out


def layout(text, width=DLG_W):
    """the lines of a text for a window `width` columns wide (item names, {02}, on a line of
    their own)"""
    lines = []
    for i, part in enumerate(text.split('{02}')):
        if i: lines.append('\x02')
        for para in paragraphs(part):
            lines += wrap_bal(para, width)
    return lines


def paginate(lines, h=DLG_H):
    """pages of at most h lines: as few pages as the lines need, the lines spread evenly over
    them, a page break after a sentence's end where one is near"""
    n = len(lines)
    if n <= h:
        return [lines]
    P = -(-n // h)
    INF = float('inf')
    from functools import lru_cache
    @lru_cache(None)
    def f(i, p):                                # lines i.. on p pages
        if p == 1:
            sz = n - i
            return (INF, None) if sz > h or sz < 1 else ((sz - n / P) ** 2 * 4, None)
        r = (INF, None)
        for j in range(i + 1, min(n, i + h) + 1):
            sz = j - i
            c = (sz - n / P) ** 2 * 4
            prev = lines[j - 1]
            if not (prev and prev[-1] in SENT_END):
                c += 30
            t = f(j, p - 1)[0]
            if c + t < r[0]: r = (c + t, j)
        return r
    out, i, p = [], 0, P
    while p > 1:
        j = f(i, p)[1]
        out.append(lines[i:j]); i = j; p -= 1
    out.append(lines[i:])
    return out


def _chunks(text):
    """the text as sentences: (sentence, starts a new line); item names ({02}) as '\x02'"""
    import re
    out = []
    for i, part in enumerate(text.split('{02}')):
        if i: out.append(('\x02', True))
        for pi, para in enumerate(paragraphs(part)):
            for si, sen in enumerate(re.split(r'(?<=[.!?])\s+(?=\S)', para)):
                out.append((sen, si == 0 and (pi > 0 or i > 0)))
    return out


def _page_lines(chunks, width):
    lines, para = [], ''
    for sen, nl in chunks:
        if sen == '\x02':
            if para: lines += wrap_bal(para, width); para = ''
            lines.append('\x02'); continue
        if nl and para:
            lines += wrap_bal(para, width); para = ''
        para = (para + ' ' + sen).strip()
    if para: lines += wrap_bal(para, width)
    return lines


def layout_pages(text, width=DLG_W, h=DLG_H):
    """pages of at most h lines made of whole sentences (as few pages as possible, their sizes
    even), each page wrapped on its own; a sentence too long for a page: line-level paging"""
    ch = _chunks(text)
    if not ch:
        return [[]]
    from functools import lru_cache
    n = len(ch)
    @lru_cache(None)
    def f(i):
        if i == n:
            return (0, 0, None)
        best = None
        for j in range(i + 1, n + 1):
            L = _page_lines(ch[i:j], width)
            if len(L) > h:
                break
            r = f(j)
            if r is None: continue
            cand = (r[0] + 1, r[1] + len(L) ** 2, j)
            if best is None or cand[:2] < best[:2]:
                best = cand
        return best
    r = f(0)
    if r is None:
        return paginate(layout(text, width), h)
    pages, i = [], 0
    while i < n:
        j = f(i)[2]
        pages.append(_page_lines(ch[i:j], width)); i = j
    return pages


def encode_dialogue(text):
    """reflowed as the GB layout (the Japanese breaks are layout breaks): 18 columns, pages of
    6 lines"""
    out = bytearray()
    for pi, page in enumerate(layout_pages(text)):
        for li, ln in enumerate(page):
            if pi or li:
                out.append(0x0A if li else 0x0C)
            for ch in ln:
                out.append(0x02 if ch == '\x02' else code_of(ch))
    return bytes(out) + b'\0'


def dialogue_banks(bank0):
    """all dialogue: a table (256 x bank, address) at bank0 $4000, the strings after it and in
    the next banks (a string never crosses a bank): {bank: bytes}"""
    import ff1_dialogue
    tbl = bytearray(768); banks = {bank0: bytearray()}
    b, addr = bank0, 0x4300
    for k in range(256):
        s = encode_dialogue(ff1_dialogue.D.get(k, ''))
        if addr + len(s) > 0x8000:
            b += 1; addr = 0x4000; banks[b] = bytearray()
        tbl[3 * k:3 * k + 3] = bytes([b, addr & 0xFF, addr >> 8])
        banks[b] += s; addr += len(s)
    out = {}
    for bk, body in banks.items():
        start = 0x4300 if bk == bank0 else 0x4000
        blob = bytearray(b'\xff' * 0x4000)
        if bk == bank0: blob[0:768] = tbl
        blob[start - 0x4000:start - 0x4000 + len(body)] = body
        out[bk] = bytes(blob)
    return out
