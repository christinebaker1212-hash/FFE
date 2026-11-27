"""FF3's cutscenes (NES bank $1F: prologue, epilogue, ending) at build time: every byte from the
user's English NES ROM. The tables of bank $1F are kept as they are (the native code in
src/cut.s reads them at their listing addresses: CR(a) = a - $6000 in bank B_CUTD), the graphics
are converted to GB tiles, the text pages are drawn as FF3's English text drawer does (34/966A:
the first line one row down, a line two rows, $02 n a tab, any other byte a tile) and placed for
the 20 x 18 screen (lines re-centred; lines too wide for 20 columns re-flowed at the spaces).

The end credits' cast pages (ids 1-8) were never translated (the English NES build shows the
Japanese bytes as Latin letters): script/ff3/cast.json gives them in the translation's names."""
import json, os, sys, importlib.util
HERE = os.path.dirname(os.path.abspath(__file__))
_sp = importlib.util.spec_from_file_location('gb3n_tiles', os.path.join(HERE, 'tiles.py'))
tiles = importlib.util.module_from_spec(_sp); _sp.loader.exec_module(tiles)
import data
ROOT = os.path.join(HERE, '..', '..')
B8 = 0x2000

# NES bank $1F addresses the code reads
A_TEXTPOS, A_TEXTPTR, A_TEXTBANK = 0xA5A6, 0xA5DF, 0xA56C
A_COMP = 0xA932
A_CREDPTR = 0x9640              # 10/9640: end credits text pointers (16 KB bank 8)
CAM_Y_PRO = 32                  # the prologue's view: NES y 32-175 (the crystal and its texts)
PRO_SHIFT = 4                   # (NES row r shows at GB row r - 4)
W = 20


def gbt(nes):
    return b''.join(tiles.gb(nes[16 * i:16 * i + 16]) for i in range(len(nes) // 16))


def decompress(rom, i):
    """1F/A27D: a header (count of run values, 16-bit size), the run values, the data"""
    p = rom.rd(0x1F, A_COMP + 2 * i, 2)
    a = p[0] | p[1] << 8
    h = rom.rd(0x1F, a, 3)
    runs = set(rom.rd(0x1F, a + 3, h[0])) if h[0] else set()
    src = rom.rd(0x1F, a + 3 + h[0], h[1] | h[2] << 8)
    out = bytearray(); k = 0
    while k < len(src):
        v = src[k]
        if v in runs:
            out += bytes([v]) * src[k + 1]; k += 2
        else:
            out.append(v); k += 1
    return bytes(out)


def rd16(rom, bank16, addr, n):
    """a 16 KB NES bank as mapped at $8000"""
    o = bank16 * 0x4000 + (addr - 0x8000)
    return rom.prg[o:o + n]


def lines_of(s):
    """an English text page -> lines (lists of tile codes, the tab kept as the start column) and
    the row of each line (FF3: 1 + 2 * newlines)"""
    out = []; row = 1; col = 0; cur = []; k = 0
    while k < len(s) and s[k]:
        c = s[k]
        if c == 1:
            if cur: out.append((row, col, cur))
            row += 2; col = 0; cur = []; k += 1; continue
        if c == 2:
            if cur:
                cur += [0xFF] * s[k + 1]
            else:
                col += s[k + 1]
            k += 2; continue
        cur.append(c); k += 1
    if cur: out.append((row, col, cur))
    return out


def strip(l):
    while l and l[-1] == 0xFF: l = l[:-1]
    while l and l[0] == 0xFF: l = l[1:]
    return l


def reflow(lines, width):
    words = []
    for l in lines:
        words += [w for w in _split(l) if w]
    out = []; cur = []
    for w in words:
        if cur and len(cur) + 1 + len(w) > width:
            out.append(cur); cur = []
        cur = cur + [0xFF] + w if cur else list(w)
    if cur: out.append(cur)
    return _balance(out, words, width)


def _split(l):
    ws = []; cur = []
    for c in l:
        if c == 0xFF:
            ws.append(cur); cur = []
        else:
            cur.append(c)
    ws.append(cur)
    return ws


def _balance(out, words, width):
    """the same number of lines, the longest as short as it can be"""
    n = len(out)
    best = out
    for wmax in range(width, 0, -1):
        lines = []; cur = []
        for w in words:
            if cur and len(cur) + 1 + len(w) > wmax:
                lines.append(cur); cur = []
            cur = cur + [0xFF] + w if cur else list(w)
        if cur: lines.append(cur)
        if len(lines) > n or any(len(l) > wmax for l in lines): break
        best = lines
    return best


def page_lines(s, width):
    """the page's lines centred for `width` columns; re-flowed if one is wider"""
    ls = [strip(l) for _, _, l in lines_of(s)]
    ls = [l for l in ls if l]
    if any(len(l) > width for l in ls):
        ls = reflow(ls, width)
    return ls


def placed(rows):
    """[(row, col, codes)] -> bytes: row, col, n, codes...; $FF ends"""
    out = bytearray()
    for r, c, l in rows:
        out += bytes([r, c, len(l)]) + bytes(l)
    return bytes(out) + b'\xFF'


def cast_pages():
    """script/ff3/cast.json -> the eight cast pages as English tile codes (tools/ff3/insert.ENC)"""
    import sys
    sys.path.insert(0, os.path.join(ROOT, 'tools', 'ff3'))
    sys.path.insert(0, os.path.join(ROOT, 'tools'))
    from insert import ENC
    out = {}
    for e in json.load(open(os.path.join(ROOT, 'script', 'ff3', 'cast.json'))):
        out[e['id']] = [[ENC[ch] for ch in line] for line in e['en'].split('\n')]
    return out


def build(rom):
    """-> (NES bank $1F as it is: 8 KB for B_CUT $4000-$5FFF, the graphics / texts bank B_CUTG,
    equates)"""
    eq = {}
    d = bytearray(0x4000)
    pos = 0

    def put(name, blob, align=1):
        nonlocal pos
        pos = (pos + align - 1) // align * align
        assert pos + len(blob) <= 0x4000, name
        d[pos:pos + len(blob)] = blob
        eq[name] = 0x4000 + pos
        pos += len(blob)
    rd = lambda b8, a, n: rom.rd(b8, a, n)
    put('C_SIN', rd(0x10, 0x9A80, 256), 256)                               # 10/9A80
    put('C_RGB', b''.join(data.rgb555(c).to_bytes(2, 'little') for c in range(64)))
    put('CG_TXT', gbt(rd(0x0D, 0xB700, 0x500) + rd(0x0D, 0xBC00, 0x400)))   # BG $70-$FF (ids 0 / 1)
    put('CG_FONT1', gbt(rd(0x10, 0x8E00, 0x1A * 16)))                      # BG $60 (id 2)
    put('CG_FONT2', gbt(rd(0x10, 0x8FA0, 0x0A * 16)))                      # BG $18 (id 3)
    put('CG_PSPR', gbt(rd(0x10, 0x8E00, 0x50 * 16)))                       # OBJ $00 (id 4)
    put('CG_STAR', gbt(decompress(rom, 1)[:0x40]))                         # OBJ $01 (id 5)
    put('CG_EFONT', gbt(rd(0x10, 0x8E00, 0x1C * 16)))                      # BG $0D (id A)
    put('CG_EGFX', gbt(rd(0x10, 0x94C0, 0x18 * 16)))                       # BG $E0 (id B)
    put('CG_ESPR', gbt(rd(0x10, 0x9290, 0x30 * 16)))                       # OBJ $00 (id 7)
    g = decompress(rom, 2)
    put('CG_EBG', gbt(g[:len(g) // 16 * 16]))                              # BG $00 (id 6)
    eq['CG_EBG_N'] = len(g) // 16
    # the credits' weapons (1F/BDEA): per job its weapon animation's 4 tiles (16 KB bank $15
    # $B000 + 16 x graphic, 2E/9098 + 3 x id byte 0) and its palette's colours 1-3 (00/9100..)
    wp = bytearray()
    for j in range(22):
        wid = rd(0x1F, 0xBFC2 + j, 1)
        pr = rd(0x2E, 0x9098 + 3 * wid, 3)
        wp += gbt(rd16(rom, 0x15, 0xB000 + 16 * pr[0], 64))
        wp += bytes([rd(0x00, 0x9100 + pr[1], 1), rd(0x00, 0x9200 + pr[1], 1), rd(0x00, 0x9300 + pr[1], 1), 0])
    put('CG_WPN', bytes(wp))
    tput = put
    # the ending's tilemap: NES nametable 0 (32 x 30) as GB map rows + CGB attributes (palette
    # per cell from the attribute bytes)
    m = decompress(rom, 4)
    tm = bytearray(); at = bytearray()
    for ty in range(30):
        for tx in range(32):
            tm.append(m[ty * 32 + tx])
            a = m[0x3C0 + (ty // 4) * 8 + tx // 4]
            at.append((a >> (((ty % 4) // 2) * 4 + ((tx % 4) // 2) * 2)) & 3)
    tput('C_EMAP', bytes(tm)); tput('C_EATR', bytes(at))
    # the cutscene texts (pointers 1F/A5DF into 16 KB bank [1F/A56C] at $8000)
    tb = rd(0x1F, A_TEXTBANK, 1)
    nptr = 19
    ptr = [rd(0x1F, A_TEXTPTR + 2 * i, 2) for i in range(nptr)]
    ptr = [p[0] | p[1] << 8 for p in ptr]
    pos3 = [rd(0x1F, A_TEXTPOS + 3 * n, 3) for n in range(19)]

    def text(tid):
        return rd16(rom, tb, ptr[tid], 255)
    # prologue entries 0-12: GB rows (NES row - 4), two rows a line where they fit
    pro = []
    for n in range(13):
        y, tid = pos3[n][1], pos3[n][2]
        ls = page_lines(text(tid), W)
        base = y - PRO_SHIFT + 1                # (FF3 draws the first line one row down)
        step = 2 if len(ls) <= 5 else 1         # (two rows a line as FF3 where they fit)
        if ls: base = min(base, 17 - step * (len(ls) - 1))
        rows = [(base + step * i, (W - len(l)) // 2, l) for i, l in enumerate(ls)]
        r0 = max(0, min([y - PRO_SHIFT] + [r for r, _, _ in rows]))    # rows cleared first: the
        r1 = min(17, max([y - PRO_SHIFT + 7] + [r for r, _, _ in rows]))  # NES block's and the lines'
        if n >= 4: r0, r1 = min(r0, 7), 17          # (pages under the crystal: the whole text area)
        pro.append(bytes([r0, r1]) + placed(rows))
    # epilogue entries 13-18: rows from the page's top; byte 0 = the page's height in rows
    epi = []
    for n in range(13, 19):
        tid = pos3[n][2]
        ls = page_lines(text(tid), W)
        assert len(ls) <= 12, ('epilogue page too tall', n, len(ls))
        epi.append(bytes([max(len(ls), 1)]) + placed([(i, (W - len(l)) // 2, l) for i, l in enumerate(ls)]))
    # end credits (10/9640): pages as FF3 draws them into its 32-wide buffer; the 18 x 14 box
    # (columns 0-17, rows 0-13) is what the screen shows
    cast = cast_pages()
    cp = rd(0x10, A_CREDPTR, 64)
    cred = []
    for i in range(30):
        a = cp[2 * i] | cp[2 * i + 1] << 8
        if i in cast:
            rows = [(9 + 2 * (k - len(cast[i]) + 1), (18 - len(l)) // 2, l) for k, l in enumerate(cast[i])]
        else:
            s = rom.prg[0x10 * B8 + (a - 0x8000):][:254]
            rows = []
            for r, c, l in lines_of(s):
                l = l[:max(0, 18 - c)]
                if r < 14 and l: rows.append((r, c, l))
        cred.append(placed(rows))
    for name, pages in (('C_PRO', pro), ('C_EPI', epi), ('C_CRED', cred)):
        tbl = bytearray(); body = bytearray()
        base = 0x4000 + pos + 2 * len(pages)
        for p in pages:
            a = base + len(body)
            tbl += bytes([a & 0xFF, a >> 8]); body += p
        tput(name, bytes(tbl) + bytes(body))
    return rom.rd(0x1F, 0xA000, 0x2000), bytes(d), ''.join('%s = $%04X\n' % (k, v) for k, v in eq.items())
