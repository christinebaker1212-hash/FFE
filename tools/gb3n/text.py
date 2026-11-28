"""FF3 native engine: the English dialogue for the Game Boy Color window, laid out at build time.

Every string is read from the user's English NES ROM (the dialogue tables at bank $18: t8000 event
dialogue, t8200 field / system messages, t8400 / t8600 people of world 0 / the other worlds; the
English insert's pointer format: low byte, (bank offset << 5) | high 5 bits, bank offset from the
table's base bank). The NES layout (26 columns) is undone into paragraphs, then laid out again for
the GB window (owner, 2026-11-22: "all dialogue spaced out in a way that is pleasant to read when
dialogue advances, line breaking in appropriate places"):
- 18 columns, 4 lines a page;
- each paragraph's lines balanced (the fewest lines, the longest as short as possible);
- whole paragraphs on a page when they fit; a page never starts or ends with a blank line;
- a paragraph longer than a page is split after a sentence end where one falls in the page,
  else after the page's last line.
Output format (GB): character codes as the NES English font ($80-$FF, $FF space; tile n = code n),
$01 new line, $0B new page (wait for a button, clear), $00 end; FF3's other codes kept
($02-$0F, $10-$27 with one parameter byte)."""
import os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'ff3'))

TABLES = (('t8000', 0x8000, 66), ('t8200', 0x8200, 80), ('t8400', 0x8400, 72), ('t8600', 0x8600, 76),
          ('names8800', 0x8800, 82))      # (names8800: the battle strings $0400-$07FF, 1024 ids)
NES_W = 26
MENU_W = 20                     # (the NES menu windows' text width, {0E} strings)
GB_W = 18
GB_LINES = 4
PAGE = 0x0B

# the English insert's character set (tools/ff3/insert.py ENC), inverted
DEC = {0x80 + i: chr(0x30 + i) for i in range(10)}
for i in range(26):
    DEC[0x8A + i] = chr(65 + i); DEC[0xA4 + i] = chr(97 + i)
DEC.update({0xBE: '.', 0xBF: ',', 0xC0: "'", 0xC1: '"', 0xC2: '-', 0xC3: '…', 0xC4: '!', 0xC5: '?',
            0xC6: '%', 0xC7: '/', 0xC8: ':', 0xCB: ';', 0xCC: '(', 0xCD: ')', 0xCE: '+', 0xCF: '&',
            0xFF: ' '})
ENC = {v: k for k, v in DEC.items()}
TOKEN = re.compile(r'\{([0-9A-F]{2})(?::([0-9A-F]{2}))?\}|\[([0-9A-F]{2})\]')


def raw_string(rom, table, i):
    t, base = {n: (a, b) for n, a, b in TABLES}[table]
    po = rom.pa(0x18, t) + 2 * i
    lo, hi = rom.prg[po], rom.prg[po + 1]
    o = rom.pa(base + (hi >> 5), ((hi & 0x1F) | 0x80) << 8 | lo)
    out = bytearray()
    while rom.prg[o]:
        c = rom.prg[o]; out.append(c); o += 1
        if 0x10 <= c < 0x28 and c != 0x1D:          # (a parameter byte, which may be 0)
            out.append(rom.prg[o]); o += 1
    return bytes(out)


def item_name(rom, i):
    """an item / spell name (names table 18/8800 + 2 i, base bank 82), encoded, no terminator"""
    po = rom.pa(0x18, 0x8800) + 2 * i
    lo, hi = rom.prg[po], rom.prg[po + 1]
    o = rom.pa(82 + (hi >> 5), ((hi & 0x1F) | 0x80) << 8 | lo)
    out = bytearray()
    while rom.prg[o]:
        c = rom.prg[o]; o += 1
        if c >= 0x28: out.append(c)
    return bytes(out)


def decode(b):
    """NES bytes -> the insert's text form ('{XX}', '{XX:YY}', '[XX]', '\\n')"""
    s = []; k = 0
    while k < len(b):
        c = b[k]; k += 1
        if c == 0x01: s.append('\n')
        elif c < 0x10: s.append('{%02X}' % c)
        elif c < 0x28:
            if c == 0x1D: s.append('{1D}')
            else: s.append('{%02X:%02X}' % (c, b[k])); k += 1
        elif c in DEC: s.append(DEC[c])
        else: s.append('[%02X]' % c)
    return ''.join(s)


def encode(s):
    out = bytearray(); i = 0
    while i < len(s):
        m = TOKEN.match(s, i)
        if m:
            if m.group(3): out.append(int(m.group(3), 16))
            else:
                out.append(int(m.group(1), 16))
                if m.group(2): out.append(int(m.group(2), 16))
            i = m.end(); continue
        ch = s[i]
        out.append(0x01 if ch == '\n' else PAGE if ch == '\f' else ENC[ch])
        i += 1
    return bytes(out)


def vlen(s):
    """displayed width (names and amounts inserted by codes at their widest)"""
    n = 0; i = 0
    while i < len(s):
        m = TOKEN.match(s, i)
        if m:
            c = m.group(1)
            if m.group(3): n += 1
            elif c in ('07', '0C', '10', '11', '12', '13'): n += 6        # names
            elif c in ('02', '18'): n += 16                              # item names
            elif c in ('03', '04', '05'): n += 6                         # amounts
            elif c == '08': n += 4
            elif c == '14': n = int(m.group(2), 16)                      # column
            i = m.end(); continue
        n += 1; i += 1
    return n


def first_word(line):
    return line.split(' ')[0] if line else ''


SPEAKER = re.compile(r'^(\{1[0-3]:..\}|\{07\}|\{0C\}|[A-Z][\w\'.-]*(?: (?:of|the|[A-Z0-9][\w\'.-]*))*): "')


def flow(para, width):
    words = [w for w in para.split(' ') if w]
    lines = []; line = ''
    for w in words:
        if not line: line = w
        elif vlen(line) + 1 + vlen(w) <= width: line += ' ' + w
        else: lines.append(line); line = w
    if line: lines.append(line)
    out = []
    for l in lines:                         # a word wider than the line: break after a hyphen,
        while vlen(l) > width:              #   else hard
            cut = max((m.end() for m in re.finditer('-', l) if vlen(l[:m.end()]) <= width), default=0)
            if not cut:
                cut = width
                while vlen(l[:cut]) > width: cut -= 1
            out.append(l[:cut]); l = l[cut:]
        out.append(l)
    return out


def balanced(para, width):
    """the fewest lines; among those the least ragged (sum of the squared slack of the lines, the
    last line's counted half)"""
    words = [w for w in para.split(' ') if w]
    base = flow(para, width)
    n = len(base)
    if n <= 1 or any(vlen(w) > width for w in words): return base
    W = len(words)
    L = [[0] * (W + 1) for _ in range(W + 1)]
    for a in range(W):
        for b in range(a + 1, W + 1):
            L[a][b] = vlen(' '.join(words[a:b]))
    INF = float('inf')
    # best[k][i]: cost of words[i:] in k lines
    best = [[INF] * (W + 1) for _ in range(n + 1)]
    nxt = [[0] * (W + 1) for _ in range(n + 1)]
    for i in range(W):
        if L[i][W] <= width: best[1][i] = (width - L[i][W]) ** 2 / 2     # (a short last line too)
    for k in range(2, n + 1):
        for i in range(W):
            for j in range(i + 1, W):
                if L[i][j] > width: break
                c = best[k - 1][j]
                if c == INF: continue
                c += (width - L[i][j]) ** 2
                if c < best[k][i]: best[k][i] = c; nxt[k][i] = j
    if best[n][0] == INF: return base
    out = []; i = 0
    for k in range(n, 1, -1):
        j = nxt[k][i]; out.append(' '.join(words[i:j])); i = j
    out.append(' '.join(words[i:]))
    return out


SENT_SPLIT = re.compile(r'(?<=[.!?…])(["\')]*) +(?=["(A-Z{])')
CLAUSE_SPLIT = re.compile(r'(?<=[,;:]) +')


def units(p, width, lines):
    """a paragraph -> sentences (a sentence longer than a page -> clauses)"""
    sents = []
    pos = 0
    for m in SENT_SPLIT.finditer(p):
        sents.append(p[pos:m.start()] + m.group(1)); pos = m.end()
    sents.append(p[pos:])
    out = []
    for st in sents:
        if len(balanced(st, width)) <= lines: out.append(st); continue
        cur = ''
        for c in CLAUSE_SPLIT.split(st):
            cand = cur + ' ' + c if cur else c
            if not cur or len(balanced(cand, width)) <= lines: cur = cand
            else: out.append(cur); cur = c
        if cur: out.append(cur)
    return out


def pages(paras, width=GB_W, lines=GB_LINES):
    """paragraphs -> pages of up to `lines` lines (see the module notes)"""
    out = []; page = []
    bal = lambda t: balanced(t, width)
    def flush():
        nonlocal page
        while page and page[-1] == '': page.pop()
        if page: out.append(page)
        page = []
    for p in paras:
        if p == '':
            if page and len(page) < lines: page.append('')
            continue
        us = units(p, width, lines); i = 0
        while i < len(us):
            room = lines - len(page)
            if page and len(bal(us[i])) > room:
                flush(); continue
            chunk = us[i]; i += 1
            ls = bal(chunk)
            if len(ls) > lines:                      # a clause longer than a page
                ls = flow(chunk, width)
                page += ls[:lines]; flush()
                us.insert(i, ' '.join(ls[lines:]))
                continue
            while i < len(us) and len(bal(chunk + ' ' + us[i])) <= room:
                chunk += ' ' + us[i]; i += 1
            page += bal(chunk)
    flush()
    return out


def gb_string(text):
    """the NES text -> GB pages (encoded)"""
    if not text: return b''
    one_row = text.startswith('{0E}')
    if one_row: text = text[4:]
    # column-set / multiple-choice strings (menus) are kept line for line
    if re.search(r'\{1[4-7]:', text):
        return encode(text)
    paras = paragraphs_simple(text, MENU_W if one_row else NES_W)
    return encode('\f'.join('\n'.join(p) for p in pages(paras)))


def paragraphs_simple(text, nes_w=NES_W):
    """undo the NES layout (insert.py flow at 26 columns; menu-window strings, {0E}, at 20): a line
    break where the next word would have fitted is a paragraph break; blank lines separate; a
    speaker turn starts a paragraph"""
    paras = []; cur = None; cur_last = ''
    for line in text.split('\n'):
        if line == '':
            if cur is not None: paras.append(cur); cur = None
            paras.append('')
            continue
        if cur is None:
            cur = line; cur_last = line; continue
        wrapped = vlen(cur_last) + 1 + vlen(first_word(line)) > nes_w
        if wrapped and not SPEAKER.match(line):
            cur += ' ' + line
        else:
            paras.append(cur); cur = line
        cur_last = line
    if cur is not None: paras.append(cur)
    while paras and paras[-1] == '': paras.pop()
    while paras and paras[0] == '': paras.pop(0)
    out = []
    for p in paras:                                  # no doubled blank lines
        if p == '' and out and out[-1] == '': continue
        out.append(p)
    return out


def pack(rom, bank0):
    """{bank: bytes}: an index at bank0 $4000 (4 tables x 256 ids x 3 bytes: bank, address) and
    the strings from bank0 $4C00 on"""
    banks = {bank0: bytearray(0x4000)}
    b, a = bank0, 0x0C00
    for t, (name, _, _) in enumerate(TABLES[:4]):
        for i in range(256):
            s = gb_string(decode(raw_string(rom, name, i))) + b'\0'
            if a + len(s) > 0x4000:
                b += 1; a = 0; banks[b] = bytearray(0x4000)
            banks[b][a:a + len(s)] = s
            e = 3 * (256 * t + i)
            banks[bank0][e:e + 3] = bytes([b, (0x4000 + a) & 0xFF, (0x4000 + a) >> 8])
            a += len(s)
    return banks


def pack_battle(rom, bank0):
    """the battle strings ($0400-$07FF, table names8800) as they are, then the t8200 strings
    ($0100-$01FF: status names) as ids 1024-1279: {bank: bytes}, an index at bank0 $4000 (1280
    ids x 3 bytes: bank, address), the strings from $4F00"""
    banks = {bank0: bytearray(0x4000)}
    b, a = bank0, 0x0F00
    for i in range(1280):
        s = raw_string(rom, 'names8800', i) if i < 1024 else raw_string(rom, 't8200', i - 1024)
        if len(s) > 120: s = b''                       # (past the table's real entries)
        s += b'\0'
        if a + len(s) > 0x4000:
            b += 1; a = 0; banks[b] = bytearray(0x4000)
        banks[b][a:a + len(s)] = s
        banks[bank0][3 * i:3 * i + 3] = bytes([b, (0x4000 + a) & 0xFF, (0x4000 + a) >> 8])
        a += len(s)
    return banks


if __name__ == '__main__':
    from data import Rom
    rom = Rom(sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', '..', 'build', 'ff3_en.nes'))
    tab = sys.argv[2] if len(sys.argv) > 2 else 't8400'
    ids = [int(x) for x in sys.argv[3].split(',')] if len(sys.argv) > 3 else range(1, 12)
    for i in ids:
        t = decode(raw_string(rom, tab, i))
        print('=== %s %d\n--- NES:\n%s' % (tab, i, t))
        g = gb_string(t)
        print('--- GB:'); print(decode(g).replace('{0B}', '\n........'))
