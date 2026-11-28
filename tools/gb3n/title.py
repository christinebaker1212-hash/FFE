"""FF3 native engine: build-time data for the boot screens (prophecy, load menu, name entry).

From the user's English ROM: the prophecy narration (t8000 entries 0 and 1, centred at 28 columns on
the NES), unwrapped and laid out again as GB pages (centred lines of up to 18 columns, a page ending
at a sentence: the owner's pleasant-reading rule); the name entry's letter grid (t8200 $21: ten
letters a row); "New Game" (t8200 $22)."""
import re
import text

PRO_W = 18
PRO_LINES = 8


def prophecy_pages(rom):
    """[[line, ...] per page] (centred with leading blanks)"""
    pages = []
    for tid in (0, 1):
        t = text.decode(text.raw_string(rom, 't8000', tid))
        body = ' '.join(l.strip() for l in t.split('\n') if l.strip())
        for pg in text.pages([body], PRO_W, PRO_LINES):
            pages.append([' ' * ((PRO_W - text.vlen(l)) // 2) + l for l in pg])
    return pages


def grid(rom):
    """80 font codes (8 rows of 10)"""
    s = text.raw_string(rom, 't8200', 0x21)
    cells = []; k = 0
    while k < len(s):
        c = s[k]; k += 1
        if c == 0x17:
            k += 1
            cells.append(s[k] if k < len(s) else 0xFF); k += 1
    cells = (cells + [0xFF] * 80)[:80]
    return bytes(cells)


def code_data(rom):
    def db(label, data):
        out = '%s:\n' % label
        for k in range(0, len(data), 16):
            out += '    db %s\n' % ', '.join(str(v) for v in data[k:k + 16])
        return out
    pro = bytearray()
    for pg in prophecy_pages(rom):
        pro += text.encode('\n'.join(pg)) + b'\x0B'
    pro[-1] = 0
    ng = text.decode(text.raw_string(rom, 't8200', 0x22))
    ng = re.sub(r'\{[^}]*\}', '', ng).strip()
    tail = '0123456789' + ".,'-!?&/:"
    g0 = text.encode('ABCDEFGHIJKLMNOPQRSTUVWXYZ' + tail)
    g1 = text.encode('abcdefghijklmnopqrstuvwxyz' + tail)
    assert len(g0) == len(g1) == 45
    job = text.encode(re.sub(r'\{[^}]*\}', '', text.decode(text.raw_string(rom, 't8200', 0xE2))).strip())
    return (db('TL_PRO', pro) + db('TL_G0', g0) + db('TL_G1', g1) +
            db('TL_H0', text.encode('SELECT: abc')) + db('TL_H1', text.encode('SELECT: ABC')) +
            db('TL_H2', text.encode('B:Delete  START:OK')) + db('TL_JOB', job) +
            'TL_JOBE:\n' + db('s_newgame', text.encode(ng) + b'\0'))
