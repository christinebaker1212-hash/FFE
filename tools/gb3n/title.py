"""FF3 native engine: build-time data for the boot screens (prophecy, load menu, name entry).

From the user's English ROM: the prophecy narration (t8000 entries 0 and 1, centred at 28 columns on
the NES), unwrapped and laid out again as GB pages (centred lines of up to 18 columns, a page ending
at a sentence: the owner's pleasant-reading rule); the name entry's letter grid (t8200 $21: ten
letters a row); "New Game" (t8200 $22)."""
import os, re
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


FF3_HEROES = ('Luneth', 'Arc', 'Refia', 'Ingus')
FF1_EXTRAS = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'gbn', 'src', 'extras.s')


def preset_groups():
    """the four members' preset names (owner, 2026-11-28): FF1's six job lists (tools/gbn/src/
    extras.s np_0-np_5, read here, not copied), lists 0-3 for members 1-4, the names of lists 4-5
    dealt out evenly over the four; FF3's Luneth / Arc / Refia / Ingus first in members 1-4's"""
    src = open(FF1_EXTRAS).read()
    lists = []
    for k in range(6):
        m = re.search(r'^np_%d:\s+db (\d+)\n((?:\s+db [\d, ]+\n)+)' % k, src, re.M)
        assert m, 'FF1 preset list %d not found' % k
        rows = [bytes(int(v) for v in l.split('db')[1].split(',')) for l in m.group(2).strip().split('\n')]
        assert len(rows) == int(m.group(1))
        lists.append([r.decode('ascii').rstrip() for r in rows])
    seen = set(FF3_HEROES)
    def new(names):
        out = [n for n in names if n not in seen]
        seen.update(out)
        return out
    groups = [[h] + new(lists[k]) for k, h in enumerate(FF3_HEROES)]
    for i, n in enumerate(new(lists[4] + lists[5])):     # (each name once: FF3 refuses a name twice)
        groups[i % 4].append(n)
    return groups


def code_data(rom):
    def db(label, data):
        out = '%s:\n' % label
        for k in range(0, len(data), 16):
            out += '    db %s\n' % ', '.join(str(v) for v in data[k:k + 16])
        return out
    ng = text.decode(text.raw_string(rom, 't8200', 0x22))
    ng = re.sub(r'\{[^}]*\}', '', ng).strip()
    tail = '0123456789' + ".,'-!?&/:"
    g0 = text.encode('ABCDEFGHIJKLMNOPQRSTUVWXYZ' + tail)
    g1 = text.encode('abcdefghijklmnopqrstuvwxyz' + tail)
    assert len(g0) == len(g1) == 45
    job = text.encode(re.sub(r'\{[^}]*\}', '', text.decode(text.raw_string(rom, 't8200', 0xE2))).strip())
    return (db('TL_G0', g0) + db('TL_G1', g1) +
            db('TL_H0', text.encode('SELECT: abc')) + db('TL_H1', text.encode('SELECT: ABC')) +
            db('TL_H2', text.encode('B:Delete  START:OK')) + db('TL_JOB', job) +
            'TL_JOBE:\n' + db('s_newgame', text.encode(ng) + b'\0') )


def pro_data(rom):
    """the prophecy pages (TL_PRO .. TL_PRO_END; bank CODE10, copied to WRAM by tl_prophecy)"""
    pro = bytearray()
    for pg in prophecy_pages(rom):
        pro += text.encode('\n'.join(pg)) + b'\x0B'
    pro[-1] = 0
    return 'TL_PRO:\n' + ''.join('    db %s\n' % ', '.join(str(v) for v in pro[k:k + 16])
                                  for k in range(0, len(pro), 16)) + 'TL_PRO_END:\n'


def presets():
    """TL_PN: four pointers, each list: the count, then 6 codes a name ($FF after it)"""
    out = 'TL_PN: dw TL_PN0, TL_PN1, TL_PN2, TL_PN3\n'
    for k, g in enumerate(preset_groups()):
        b = bytearray([len(g)])
        for n in g:
            e = text.encode(n)
            assert len(e) <= 6, n
            b += e + b'\xFF' * (6 - len(e))
        out += 'TL_PN%d:\n' % k + ''.join('    db %s\n' % ', '.join(str(v) for v in b[i:i + 16])
                                          for i in range(0, len(b), 16))
    return out


def ne_data(rom):
    """the rebuilt name entry's letters and hints (nme.s, bank CODE13)"""
    def db(label, data):
        return '%s:\n' % label + ''.join('    db %s\n' % ', '.join(str(v) for v in data[k:k + 16])
                                         for k in range(0, len(data), 16))
    tail = '0123456789' + ".,'-!?&/:"
    return (db('TL_G0N', text.encode('ABCDEFGHIJKLMNOPQRSTUVWXYZ' + tail)) +
            db('TL_G1N', text.encode('abcdefghijklmnopqrstuvwxyz' + tail)) +
            db('TL_H0N', text.encode('SELECT: abc') + b'\0') + db('TL_H1N', text.encode('SELECT: ABC') + b'\0') +
            db('TL_H2N', text.encode('B: Delete   START: OK') + b'\0'))
