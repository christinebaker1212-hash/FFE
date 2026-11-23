"""FF3 native engine: the cutscenes' data (FF3 bank 1F: the crystal prologue, the epilogue, the ending
and the end credits), made at build time from the user's English NES ROM.

- The code bank (CODE5) holds the cutscene code at $4000-$5FFF and a copy of NES bank 1F at
  $6000-$7FFF (NES address - $4000), so the scenes read FF3's tables (crystal parts, sparkles,
  palette sets, star tables, sprite lists) where FF3 keeps them.
- The data bank (CUTD) holds, at $4000, the directory of FF3's cutscene graphics (1F/A01B: 12
  entries of source, PPU address, tile count, bank), 8 bytes each: GB source address, VRAM bank,
  VRAM address, count (16-byte blocks), type (0 tiles, 1 a nametable: 32 x 30 tiles then their
  CGB attributes), converted to GB tiles. FF3 decompresses three of the sources at run time
  (1F/A27D, RLE with a byte table); here they are decompressed by the build.
- The text pages (1F/A5A6 page table, 1F/A5DF text pointers, the English pages in banks 90/91):
  laid out for the GB view (20 x 18 cells at the scene's camera) as blocks of rows (screen row,
  row count, 20 tiles a row). The staff pages as they are (FF3's columns minus the camera's);
  the story pages re-wrapped at 18 columns from the script (script/ff3/epilogue.json, the same
  text the English NES pages hold) and centred."""
import json, os, re, textwrap
import text

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..', '..')
B1F = 0x1F
EPI_BANK = 90                   # (tools/ff3/insert.py: the English pages)
BLANK = 0xFF                    # (the font's space)
PRO_CAMX, PRO_CAMY = 48, 32     # prologue view: NES cols 6-25, rows 4-21
EPI_CAMX, EPI_CAMY = 48, 48     # epilogue: the stars' centre (128, 120) in the middle


def enc_entry(rom, i):
    e = rom.b(B1F, 0xA01B + 6 * i, 6)
    return e[0] | e[1] << 8, e[2] | e[3] << 8, e[4], e[5]


def decompress(rom, i):
    """1F/A27D: header (count of RLE byte values, size lo / hi), the RLE values, then the data"""
    p = rom.u8(B1F, 0xA932 + 2 * i) | rom.u8(B1F, 0xA933 + 2 * i) << 8
    rd = lambda a: rom.u8(B1F, a)
    n = rd(p)
    rle = set(rd(p + 3 + k) for k in range(n))
    size = rd(p + 1) | rd(p + 2) << 8
    a = p + 3 + n
    end = a + size
    out = bytearray()
    while a != end:
        v = rd(a)
        if v in rle:
            c = rd(a + 1) or 256
            out += bytes([v]) * c
            a += 2
        else:
            out.append(v); a += 1
    return bytes(out)


def entry_src(rom, i):
    """the bytes FF3 copies for cutscene graphics entry i (its decompressed source for $7575)"""
    src, ppu, n, bank = enc_entry(rom, i)
    if src == 0x7575:
        dec = {5: 1, 6: 2, 8: 4}[i]
        return (decompress(rom, dec) + bytes(16 * n))[:16 * n]
    if src == 0x7900:
        return bytes(16 * n)            # (the cleared text buffer: blank tiles)
    o = bank * 0x4000 + (src - 0x8000)
    return rom.prg[o:o + 16 * n]


def nt_convert(nt):
    """a NES nametable (960 tiles + 64 attribute bytes) -> 960 tiles + 960 CGB attributes"""
    tiles = nt[:960]
    att = bytearray(960)
    for r in range(30):
        for c in range(32):
            a = nt[960 + (r // 4) * 8 + c // 4]
            sh = ((r & 2) << 1) | (c & 2)
            att[32 * r + c] = (a >> sh) & 3
    return bytes(tiles) + bytes(att)


def nes_page(rom, t):
    """English page t (bank 90/91 via 1F/A5DF) -> list of (row offset, column, tiles), as bconv
    draws it: the text on the lower row of each two-row line"""
    p = rom.u8(B1F, 0xA5DF + 2 * t) | rom.u8(B1F, 0xA5E0 + 2 * t) << 8
    o = rom.pa(EPI_BANK + (p >= 0xA000), p)
    lines, row, col, cur = [], 1, 0, []
    while True:
        c = rom.prg[o]; o += 1
        if c == 0: break
        if c == 1:
            if cur: lines.append((row, start, cur))
            cur = []; row += 2; col = 0; continue
        if c == 2:
            col += rom.prg[o]; o += 1; continue
        if not cur: start = col
        cur.append(c); col += 1
    if cur: lines.append((row, start, cur))
    return lines


def story_lines(k):
    e = json.load(open(os.path.join(ROOT, 'script', 'ff3', 'epilogue.json')))[k]
    para = ' '.join(re.sub(r'^\{COL:..\}', '', l).strip() for l in e['en'].split('\n') if l.strip())
    return textwrap.wrap(para, 18)


def block(rows, first, height):
    """rows: {screen row: (col, tiles)} -> bytes: first row, height, 20 tiles a row"""
    out = bytearray([first, height])
    for r in range(first, first + height):
        line = bytearray([BLANK] * 20)
        if r in rows:
            c, t = rows[r]
            assert 0 <= c and c + len(t) <= 20, (r, c, len(t))
            line[c:c + len(t)] = t
        out += line
    return bytes(out)


def centred(lines, top, height):
    """story lines (ASCII) centred in screen rows top..top+height-1: double-spaced when they fit"""
    n = len(lines)
    sp = 2 if 2 * n - 1 <= height else 1
    assert sp * (n - 1) + 1 <= height, lines
    r0 = top + (height - (sp * (n - 1) + 1)) // 2
    rows = {}
    for k, l in enumerate(lines):
        b = text.encode(l)
        rows[r0 + sp * k] = ((20 - len(b)) // 2, b)
    return block(rows, top, height)


def pages(rom):
    """the GB page blocks by FF3's page index (1F/A5A6: column, row, text id)"""
    tab = [rom.b(B1F, 0xA5A6 + 3 * i, 3) for i in range(20)]
    out = []
    camc, camr = PRO_CAMX // 8, PRO_CAMY // 8
    for idx in range(20):
        col, row, tid = tab[idx]
        if idx < 4:                                     # title / copyright and their clears
            rows = {}
            for dr, c, t in nes_page(rom, tid):
                rows[row + dr - camr] = (c - camc, bytes(t))
            out.append(block(rows, row + 1 - camr, 1))
        elif idx < 13:                                  # staff pages / the opening story
            if tid <= 8:
                ls = nes_page(rom, tid)
                n = len(ls)
                r0 = 7 + (11 - (2 * n - 1)) // 2
                rows = {r0 + (dr - 1): (c - camc, bytes(t)) for dr, c, t in ls}
                out.append(block(rows, 7, 11))
            else:
                out.append(centred(story_lines(tid - 9), 7, 11))
        elif idx < 19:                                  # the epilogue's pages (scrolled in)
            if tid == 2:
                out.append(block({}, 0, 18))
            else:
                out.append(centred(story_lines(tid - 9), 0, 18))
        else:
            out.append(b'')
    return out


def pack2(rom):
    """the second data bank: $4000 weapon tiles (2B/B000, 256, GB format), $5000 weapon
    properties (2E/9098, 3 bytes each), $5300 the end credits' 31 strings (10/9640 pointers;
    GB addresses), the strings after"""
    from data import nes2gb
    d = bytearray(0x4000)
    src = rom.b(0x2B, 0xB000, 0x1000)
    d[0:0x1000] = b''.join(nes2gb(src[16 * t:16 * t + 16]) for t in range(256))
    d[0x1000:0x1300] = rom.b(0x2E, 0x9098, 0x300)
    a = 0x1340
    for i in range(31):
        p = rom.u8(0x10, 0x9640 + 2 * i) | rom.u8(0x10, 0x9641 + 2 * i) << 8
        st = bytearray()
        while True:
            c = rom.u8(0x10, p); p += 1; st.append(c)
            if c == 0: break
            if c == 2: st.append(rom.u8(0x10, p)); p += 1
        d[0x1300 + 2 * i] = (0x4000 + a) & 0xFF; d[0x1301 + 2 * i] = (0x4000 + a) >> 8
        d[a:a + len(st)] = st
        a += len(st)
    assert a <= 0x3F00
    d[0x3F00:0x3FFC] = rom.b(0x3B, 0xADB1, 0xFC)                # $7F00: 3B/ADB1 the people's dance
    return d


def pack(rom, data_bank):
    """-> (the code bank's upper half: NES bank 1F, the data bank, syms)"""
    upper = bytearray(rom.b(B1F, 0xA000, 0x2000))
    d = bytearray(0x4000)
    a = 0x100
    from data import nes2gb
    for i in range(12):
        src, ppu, n, bank = enc_entry(rom, i)
        raw = entry_src(rom, i)
        if ppu >= 0x2000:
            blob = nt_convert(raw[:1024]); typ = 1
            vb, va, cnt = 0, 0x9800, len(blob) // 16
        else:
            blob = b''.join(nes2gb(raw[16 * t:16 * t + 16]) for t in range(n)); typ = 0
            vb, va = (1, 0x8000 + ppu - 0x1000) if ppu >= 0x1000 else (0, 0x8000 + ppu)
            cnt = n
        d[8 * i:8 * i + 8] = bytes([(0x4000 + a) & 0xFF, (0x4000 + a) >> 8, vb, va & 0xFF, va >> 8,
                                    cnt & 0xFF, typ, 0])
        d[a:a + len(blob)] = blob
        a += len(blob)
    pg = pages(rom)
    ptab = a
    a += 2 * len(pg)
    for i, b in enumerate(pg):
        d[ptab + 2 * i] = (0x4000 + a) & 0xFF; d[ptab + 2 * i + 1] = (0x4000 + a) >> 8
        d[a:a + len(b)] = b
        a += len(b)
    sine = a                                            # 10/9A80 the stars' sine table
    d[a:a + 256] = rom.b(0x10, 0x9A80, 256)
    a += 256
    assert a <= 0x4000, hex(a)
    return upper, d, {'CUT_PAGES': 0x4000 + ptab, 'CUT_SINE': 0x4000 + sine}
