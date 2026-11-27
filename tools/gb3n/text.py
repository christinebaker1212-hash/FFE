"""FF3's English text for the Game Boy Color build (build time): the project's translation
(script/ff3/*.json) encoded for our font and wrapped for the GB windows. The paragraph rules
are the English inserter's (tools/ff3/insert.py, imported, not changed).

GB text format (src/text.s): bytes 32-126 our font (tile = ASCII), 127 the ellipsis glyph;
$00 end, $0A new line, $0C new page (A to continue), $10-$13 member 0-3's name, $14-$17 member
0-3's job. Strings of a table: an index (bank, address lo, hi per id) in B_TEXT, the strings in
the banks after it."""
import os, sys, json, re
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..', '..')
sys.path.insert(0, os.path.join(HERE, '..', 'ff3'))
sys.path.insert(0, os.path.join(HERE, '..'))
import insert as ff3ins

DLG_COLS, DLG_LINES = 18, 6
TABLES = ['t8000', 't8200', 't8400', 't8600', 'names8800']
TOKEN = re.compile(r'\{([0-9A-F]{2})(?::([0-9A-F]{2}))?\}|\[([0-9A-F]{2})\]')
ELLIPSIS = 127


def load(name):
    return {e['id']: e['en'] for e in json.load(open(os.path.join(ROOT, 'script', 'ff3', name + '.json')))}


NAMES = load('names8800')


def plain(s):
    """the string with icon pairs as words, name-table inserts expanded, indents dropped"""
    s = s.replace('[77][79]', 'HP').replace('[78][79]', 'MP').replace('‥', '…')
    s = re.sub(r'\{18:([0-9A-F]{2})\}', lambda m: plain(NAMES.get(int(m.group(1), 16), '')), s)
    s = re.sub(r'\{0C\}', '', s)
    return s


def vlen(s):
    n = 0; i = 0
    while i < len(s):
        m = TOKEN.match(s, i)
        if m:
            if m.group(1) and m.group(1)[0] == '1' and m.group(1) <= '13': n += 6
            i = m.end(); continue
        n += 1; i += 1
    return n


def wrap(s, cols=DLG_COLS):
    ff3ins.vlen = vlen                        # (the inserter's flow counts with our widths)
    lines = []
    for p in ff3ins.paragraphs(plain(s)):
        lines += ff3ins.flow(p, cols) if p.strip() else ['']
    while lines and not lines[-1].strip(): lines.pop()
    return [re.sub(r'\{14:..\}', '', l) for l in lines]


def encode_lines(lines, per_page=DLG_LINES):
    out = bytearray()
    for k, line in enumerate(lines):
        if k:
            out.append(0x0C if k % per_page == 0 else 0x0A)
        i = 0
        while i < len(line):
            m = TOKEN.match(line, i)
            if m:
                c = m.group(1)
                if c and '10' <= c <= '13':
                    out.append((0x10 if m.group(2) == '02' else 0x14) + int(c, 16) - 0x10)
                i = m.end(); continue
            ch = line[i]
            out.append(ELLIPSIS if ch == '…' else (ord(ch) if 32 <= ord(ch) < 127 else ord('?')))
            i += 1
    out.append(0)
    return bytes(out)


def dialogue(s):
    return encode_lines(wrap(s))


def banks(first_bank):
    """{bank: bytes}, the index layout {table: index address in B_TEXT}"""
    blank = lambda: bytearray(b'\xff' * 0x4000)
    idx = blank(); out = {first_bank: idx}
    at_idx = 0; layout = {}
    bank, at = first_bank + 1, 0
    for t in TABLES[:4]:
        tab = load(t)
        n = max(tab) + 1
        layout[t] = 0x4000 + at_idx
        for i in range(n):
            enc = dialogue(tab.get(i, ''))
            if at + len(enc) > 0x4000: bank, at = bank + 1, 0
            out.setdefault(bank, blank())[at:at + len(enc)] = enc
            idx[at_idx:at_idx + 3] = bytes([bank, (0x4000 + at) & 0xFF, (0x4000 + at) >> 8])
            at_idx += 3; at += len(enc)
    return out, layout, bank
