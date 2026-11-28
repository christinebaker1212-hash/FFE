"""FF3 native engine: build-time data for shops and inns (src/shop.s).

From the user's English ROM: every item name that is longer than ten letters drawn in the condensed
letters (tools/latin_font.py COND, else TIGHT) into ten tiles, so a shop list row holds the name and
its price (banks ITEMN_BANK0..+2: item i at bank + i // 102, $4000 + 160 (i % 102); GAME_BANK $7900:
1 if item i has such tiles); the shop's words (t8200 $0107-$010B, $012D / $012E: the shop names, Buy /
Sell / Exit, How many? and the quantities, at FF3's columns) and the inn's (Yes / No, $0106)."""
import os, re, sys
import text
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..'))

PER_BANK = 102
NAME_T = 10                             # tiles of a condensed name


def name_body(rom, i):
    """item i's name without its leading blank / icon, the "'s" ligature spelt out"""
    s = text.decode(text.item_name(rom, i)).lstrip(' ')
    s = re.sub(r'^\[[0-9A-F]{2}\]', '', s)
    return s.replace('[C9]', "'s")


def name_tiles(rom):
    """{bank offset: bytes}, flags (256 bytes)"""
    from latin_font import packed_label, COND, TIGHT
    banks = {k: bytearray(0x4000) for k in range(3)}
    flags = bytearray(256)
    for i in range(256):
        body = name_body(rom, i)
        if text.vlen(body) <= NAME_T: continue
        t = packed_label(body, NAME_T, COND, fg=3, bg=2) or packed_label(body, NAME_T, TIGHT, fg=3, bg=2)
        assert t, body
        flags[i] = 1
        o = 160 * (i % PER_BANK)
        banks[i // PER_BANK][o:o + 160] = b''.join(bytes(b for r in range(8) for b in (tl[r], tl[8 + r])) for tl in t)
    return banks, flags


def choices(s):
    """'{15:01}Buy{15:06}Sell...' -> [(column, word)]: FF3's column + 1 + the choice's index (room
    for the hand before each word)"""
    out = []
    for k, m in enumerate(re.finditer(r'\{15:([0-9A-F]{2})\}([^{\n]+)', s)):
        out.append((int(m.group(1), 16) + 1 + k, m.group(2).strip()))
    return out


def code_data(rom):
    def db(label, data):
        out = '%s:\n' % label
        for k in range(0, len(data), 16):
            out += '    db %s\n' % ', '.join(str(v) for v in data[k:k + 16])
        return out
    t = lambda i: text.decode(text.raw_string(rom, 't8200', i))
    def chdata(cs):
        b = bytearray([len(cs)])
        for col, w in cs: b += bytes([col]) + text.encode(w) + b'\0'
        return bytes(b)
    src = ''
    for k in range(4):                                       # shop types 7-10: the names joined
        nm = ' '.join(x.strip() for x in t(7 + k).replace('{0E}', '').split('\n') if x.strip())
        src += db('sh_title%d' % k, text.encode(nm) + b'\0')
    src += db('sh_main', chdata(choices(t(0x0B))))
    q4, q2 = t(0x2D).split('\n'), t(0x2E).split('\n')
    src += db('sh_qbuy', chdata(choices(q4[1])))
    src += db('sh_qsell', chdata(choices(q2[1])))
    how = re.sub(r'\{[^}]*\}', '', q4[0]).strip()
    src += db('sh_how', text.encode(how) + b'\0')
    yn = [re.sub(r'\{[^}]*\}', '', x).strip() for x in t(0x06).split('\n')]
    src += db('sh_yes', text.encode(yn[0]) + b'\0') + db('sh_no', text.encode(yn[1]) + b'\0')
    gil = re.sub(r'\{[^}]*\}', '', t(0x05)).strip()
    src += db('sh_gil', text.encode(gil) + b'\0')
    for k, (_, w) in enumerate(choices(t(0x24))):            # the fat chocobo: Deposit / Withdraw / Exit
        src += db('ch_w%d' % k, text.encode(w) + b'\0')
    return src


def ui_data(rom):
    """the rebuilt shop's words (shp.s, bank CODE13): FF3's messages $26-$2C and $6C (two lines;
    $2B split at its value), the shop names, the choices (Buy / Sell / Exit, 1 / 4 / 10, 1 / All)"""
    import ui
    t = lambda i: text.decode(text.raw_string(rom, 't8200', i))
    def lines_(raw):
        return b'\x01'.join(text.encode(ui.clean(x)) for x in raw.split('\n') if ui.clean(x))
    def wrap144(raw):
        if all(ui.width(text.encode(ui.clean(x))) <= 144 for x in raw.split('\n')):
            return lines(raw)
        lns, cur = [], []
        for wd in ui.clean(raw).split(' '):
            if cur and ui.width(text.encode(' '.join(cur + [wd]))) > 144:
                lns.append(' '.join(cur)); cur = []
            cur.append(wd)
        lns.append(' '.join(cur))
        return b'\x01'.join(text.encode(x) for x in lns)
    def lines(raw):
        return b'\x01'.join(text.encode(ui.clean(x)) for x in raw.split('\n') if ui.clean(x))
    def strtab(label, items):
        out = '%s:\n' % label + ''.join('    dw %s_%d\n' % (label, k) for k in range(len(items)))
        for k, b in enumerate(items):
            out += '%s_%d:\n    db %s\n' % (label, k, ', '.join(str(v) for v in bytes(b) + b'\0'))
        return out
    msgs = [lines(t(i)) for i in (0x26, 0x27, 0x28, 0x29, 0x2A)] + [b'', lines(t(0x2C)), lines(t(0x6C))]
    msgs += [wrap144(t(i)) for i in range(0x51, 0x59)]            # (the fat chocobo's: $51-$58)
    v = t(0x2B)
    a, _, b = v.partition('{04}')
    src = strtab('SP_MSG', msgs)
    src += 'SP_V1:\n    db %s\n' % ', '.join(str(x) for x in text.encode(ui.clean(a)) + b'\0')
    src += 'SP_V2:\n    db %s\n' % ', '.join(str(x) for x in b'\xff' + text.encode(ui.clean(b)) + b'\0')
    names = [text.encode(' '.join(x.strip() for x in t(7 + k).replace('{0E}', '').split('\n') if x.strip()))
             for k in range(4)]
    src += strtab('SP_TITLE', names)
    yn = [re.sub(r'\{[^}]*\}', '', x).strip() for x in t(0x06).split('\n')]
    sets = [choices(t(0x0B)), choices(t(0x2D).split('\n')[1]), choices(t(0x2E).split('\n')[1]),
            [(0, yn[0]), (0, yn[1])], choices(t(0x24).replace('\n', ''))]
    cols = [(3, 8, 13), (3, 8, 13), (3, 8, 13), (3, 8, 13), (3, 9, 16)]    # (the hand's 2 cells before)
    src += strtab('SP_SETS', [bytes([len(c)]) + bytes(cols[k]) + b'\0'.join(text.encode(w) for _, w in c)
                              for k, c in enumerate(sets)])
    # the inn's speech ($0104): re-wrapped to 144 pixels, its cost (6 digits wide) in one line
    sp = ui.clean(t(0x04).replace('[77][79]', 'HP').replace('{04}', '#'))
    lines, cur = [], []
    w = lambda ws: ui.width(text.encode(' '.join(ws).replace('#', ''))) + (26 if '#' in ws else 0)
    for wd in sp.split(' '):
        if cur and w(cur + [wd]) > 144:
            lines.append(cur); cur = []
        cur.append(wd)
    lines.append(cur)
    assert len(lines) <= 6, lines
    k = [i for i, l in enumerate(lines) if '#' in l][0]
    pre, _, suf = ' '.join(lines[k]).partition('#')
    src += strtab('IN_L', [text.encode(' '.join(l)) if i != k else b'' for i, l in enumerate(lines)])
    src += 'IN_NK:\n    db %d, %d\n' % (len(lines), k)
    src += 'IN_PRE:\n    db %s\n' % ', '.join(str(x) for x in text.encode(pre.rstrip()) + b'\xff\0')
    src += 'IN_SUF:\n    db %s\n' % ', '.join(str(x) for x in b'\xff' + text.encode(suf.strip()) + b'\0')
    src += strtab('IN_THX', [lines_(t(0x4F))])
    return src
