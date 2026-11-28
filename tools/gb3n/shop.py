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
