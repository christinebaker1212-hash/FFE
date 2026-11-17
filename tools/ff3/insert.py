"""Insert the English script into the FF3 MMC5 ROM (tools/ff3_mmc5/build.py output).

usage: insert.py ff3_mmc5.nes OUT.nes

8KB banks: 0-63 the game's, 64 the ExRAM image (helpers of build.py, then the English
engine below), 65-125 free, 126/127 the fixed banks. Text: the five pointer tables stay
in bank $18 ($8000 story, $8200 system, $8400 and $8600 dialogue, $8800 names) in the
Japanese format (lo, hi: address lo | (hi & $1F | $80) << 8, bank (hi >> 5) + base), but
each table's strings are packed into banks of its own from a base bank (TBASE); the
three places that decode a text pointer add that base instead of $18.
English text in the dialogue tables is drawn one tile row per line (the Japanese spends
a row on dakuten); see EXRAM_SRC."""
import sys, os, json, re
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
from latin_font import tile
from asm6502 import asm

HDR = 16; B8 = 0x2000
FONT = 0x1B000                          # tile N = code N (PRG offset)
DLG_W = 26                              # dialogue window: 26 columns, 8 rows

def off(bank, cpu): return HDR + bank * B8 + (cpu & 0x1FFF)
def put(rom, bank, cpu, data): o = off(bank, cpu); rom[o:o + len(data)] = data
def get(rom, bank, cpu, n=1): o = off(bank, cpu); return bytes(rom[o:o + n])
FIX = 127                               # $E000 bank; 126 is $C000
def jsr(a): return bytes([0x20, a & 0xFF, a >> 8])
def jmp(a): return bytes([0x4C, a & 0xFF, a >> 8])

ENC = {chr(0x30 + i): 0x80 + i for i in range(10)}
for i in range(26):
    ENC[chr(65 + i)] = 0x8A + i; ENC[chr(97 + i)] = 0xA4 + i
ENC.update({'.': 0xBE, ',': 0xBF, "'": 0xC0, '"': 0xC1, '-': 0xC2, '…': 0xC3, '!': 0xC4, '?': 0xC5,
            '%': 0xC6, '/': 0xC7, ':': 0xC8, ';': 0xCB, '(': 0xCC, ')': 0xCD, '+': 0xCE, '&': 0xCF,
            ' ': 0xFF})
NEW_GLYPHS = [c for c in ENC if c != ' ']

def font(rom):
    for ch in NEW_GLYPHS:
        o = HDR + FONT + ENC[ch] * 16; rom[o:o + 16] = tile(ch, fg=3, bg=2)

TOKEN = re.compile(r'\{([0-9A-F]{2})(?::([0-9A-F]{2}))?\}|\[([0-9A-F]{2})\]')

def enc(s):
    out = bytearray(); i = 0
    while i < len(s):
        m = TOKEN.match(s, i)
        if m:
            if m.group(3): out.append(int(m.group(3), 16))
            else:
                out.append(int(m.group(1), 16))
                if m.group(2): out.append(int(m.group(2), 16))
            i = m.end(); continue
        if s[i] == '\n': out.append(0x01)
        elif s[i] == '‥': out.append(0xC3)
        else: out.append(ENC[s[i]])
        i += 1
    return bytes(out)

NAMES = {}
def vlen(s):
    """Displayed width: names inserted by codes count at their English length."""
    n = 0; i = 0
    while i < len(s):
        m = TOKEN.match(s, i)
        if m:
            c = m.group(1)
            if m.group(3): n += 1
            elif c == '18': n += vlen(NAMES[int(m.group(2), 16)])
            elif c in ('07', '10', '11', '12', '13'): n += 6
            elif c == '02': n += 16                       # item name
            elif c in ('03', '04', '05'): n += 6          # amounts
            elif c == '14': n = int(m.group(2), 16)       # column
            i = m.end(); continue
        n += 1; i += 1
    return n

SPEAKER = re.compile(r'^(\{1[0-3]:..\}|\{18:..\}|\{07\}|[A-Z][\w\'.-]*(?: [A-Z][\w\'.-]*)*): "')
COLTOK = re.compile(r'^\{14:..\}')

def paragraphs(text):
    """Japanese line breaks are layout, except blank lines, speaker turns and lines that
    open a quotation, which start a new paragraph; an indented continuation line ({14:xx}
    or a leading space) joins the speech it continues."""
    paras = []
    for line in text.split('\n'):
        cont = COLTOK.match(line) or line.startswith(' ')
        body = COLTOK.sub('', line).strip(' ') if cont else line
        if paras and line and paras[-1] and not SPEAKER.match(body) and not body.startswith('"'):
            paras[-1] += ' ' + body
        else: paras.append(body if line else '')
    return paras

def flow(para, width):
    words = para.split(' ')
    lines = []; line = ''
    for w in words:
        if not w: continue
        if not line: line = w
        elif vlen(line) + 1 + vlen(w) <= width: line += ' ' + w
        else: lines.append(line); line = w
    lines.append(line)
    return lines

def balanced(para, width):
    """The fewest lines, as even as possible (the longest line shortest)."""
    words = [w for w in para.split(' ') if w]
    n = len(flow(para, width))
    best = None
    def rec(i, k, acc):
        nonlocal best
        if k == 1:
            l = ' '.join(words[i:])
            if vlen(l) <= width:
                cand = acc + [l]
                if best is None or max(map(vlen, cand)) < max(map(vlen, best)): best = cand
            return
        for j in range(i + 1, len(words) - k + 2):
            l = ' '.join(words[i:j])
            if vlen(l) > width: break
            rec(j, k - 1, acc + [l])
    rec(0, n, [])
    return best or flow(para, width)

def layout(text, width=DLG_W):
    lines = []
    for p in paragraphs(text):
        lines += flow(p, width) if p.strip() else ['']
    for l in lines: assert vlen(l) <= width, (l, vlen(l))
    return '\n'.join(lines)

NARRATION = {('t8000', 0): 28, ('t8000', 1): 28}   # opening (window $25: 28 x 26), centred

def centred(text, width):
    lines = []                          # each Japanese line a unit (the fade-in pacing)
    for p in text.split('\n'):
        p = COLTOK.sub('', p).strip(' ')
        for l in (balanced(p, width) if p else ['']):
            lines.append(' ' * ((width - vlen(l)) // 2) + l)
    return '\n'.join(lines)

# ---- tables -------------------------------------------------------------------------
TABLES = [('t8000', 0x8000, 65), ('t8400', 0x8400, 71), ('t8600', 0x8600, 75),
          ('t8200', 0x8200, 79), ('names8800', 0x8800, 81)]
DIALOGUE = ('t8000', 't8400', 't8600')
ONE_BANKS = (65, 79)                    # banks drawn one row per line (dialogue tables)

def put_tables(rom, report):
    for name, table, base in TABLES:
        rows = json.load(open('script/ff3/%s.json' % name))
        lin = 0; blob = bytearray()
        for e in rows:
            t = e['en'] or ''
            if (name, e['id']) in NARRATION: t = centred(t, NARRATION[name, e['id']])
            elif name in DIALOGUE and t: t = layout(t)
            data = enc(t) + b'\0'
            b, a = lin >> 13, 0x8000 + (lin & 0x1FFF)
            assert b < 8
            put(rom, 0x18, table + 2 * e['id'], bytes([a & 0xFF, (b << 5) | ((a >> 8) & 0x1F)]))
            blob += data; lin += len(data)
        nb = (len(blob) + B8 - 1) // B8
        nxt = [b for _, _, b in TABLES if b > base]
        assert not nxt or base + nb < min(nxt), name          # (+1 bank: the last string's spill)
        o = off(base, 0x8000); rom[o:o + len(blob)] = blob
        report.append('%s: %d bytes in banks %d-%d' % (name, len(blob), base, base + nb - 1))

# ---- engine -------------------------------------------------------------------------
EXRAM_ORG = 0x5C90                      # after build.py's MMC5 helpers ($5C00-$5C88)
EXRAM_SRC = '''
    org $5C90
TMP:    .ds 1
ONE:    .ds 1
ONEP:   .ds 1   ; ONE of the last drawing (the page scroll runs after it)
    .ds 13
tbase:          ; $EEBB: bank of a text pointer = (hi >> 5) + the table's base bank
    sta TMP     ;   (table by $95: $80 story, $82 system, $84/$86 dialogue, $88+ names)
    lda $95
    and #$FE
    sec
    sbc #$80
    lsr a
    tax
    lda TMP
    clc
    adc TBASE,x
    rts
TBASE:
    .db B0, B1, B2, B3, B4, B4, B4, B4
nbase:          ; $F0D2 (code 18: name table)
    clc
    adc #B4
    rts
sbase:          ; $D1DA (system string copied to RAM)
    clc
    adc #B1
    rts
onerow:         ; C = 1 in one-row mode
    lda ONE
    cmp #1
    rts
txton:          ; $EEC0 (text drawing starts): one row per line for the English
    lda $93     ;   dialogue banks
    jsr $FF03
    lda #0
    sta ONE
    lda $93
    cmp #R0
    bcc .x
    cmp #R1
    bcs .x
    inc ONE
.x:
    rts
txtend:         ; $EEEC (end of the text): in one-row mode blank the window's rows below
    lda ONE     ;   it (a scroll redraws from a later line)
    beq txtoff
.c:
    lda $1F
    clc
    adc #1
    cmp $3D
    bcs txtoff
    inc $1F
    lda #0
    jsr $F692
    jmp .c
txtoff:         ; $EEF3 (window full)
    lda ONE
    sta ONEP
    lda #0
    sta ONE
    lda $57
    jmp $FF03
h_nl:           ; $EF4C newline: one row (or two, Japanese layout)
    inc $1F
    jsr onerow
    bcs .r
    inc $1F
.r:
    rts
h_sub:          ; $EE86/$EE90 (paged text): rows scrolled per line
    sta TMP
    lda ONEP
    cmp #1
    lda TMP
    bcc .two
    sec
    sbc #1
    rts
.two:
    sec
    sbc #2
    rts
h_ypos:         ; $F086: row of a recorded position ($98 + $1F assumes the dakuten row)
    lda $98
    clc
    adc $1F
    ldx ONE
    beq .r
    sec
    sbc #1
.r:
    rts
h_flush:        ; $F6AE line flush: lower-row buffer only, on row $3B
    lda $38
    sta $3A
    jsr onerow
    bcs .one
    jmp $F6B2
.one:
    jsr $F40A
    ldx #0
.a:
    lda $07A0,x
    sta $2007
    inx
    cpx $91
    bcc .a
    cpx $3C
    bcs .d
    lda $3A
    and #$20
    eor #$20
    sta $3A
    jsr $F40A
    ldx $91
.b:
    lda $07A0,x
    sta $2007
    inx
    cpx $3C
    bcc .b
.d:
    jmp $F715
'''

COPIER = 0x9F00                         # bank 64: copies the 1KB ExRAM image at reset
COPIER_SRC = '''
    org $9F00
    ldx #0
.l:
    lda $8000,x
    sta $5C00,x
    lda $8100,x
    sta $5D00,x
    lda $8200,x
    sta $5E00,x
    lda $8300,x
    sta $5F00,x
    inx
    bne .l
    rts
'''

def engine(rom, report):
    bases = {n: b for n, _, b in TABLES}
    ex = asm(EXRAM_SRC, syms={'B0': bases['t8000'], 'B1': bases['t8200'], 'B2': bases['t8400'],
                              'B3': bases['t8600'], 'B4': bases['names8800'],
                              'R0': ONE_BANKS[0], 'R1': ONE_BANKS[1]})
    assert ex.org + len(ex.bytes) <= 0x6000
    assert set(get(rom, 64, 0x8090, 0x370)) == {0xFF}
    put(rom, 64, ex.org - 0x5C00 + 0x8000, ex.bytes)
    report.append('ExRAM code: %d bytes (to $%04X)' % (len(ex.bytes), ex.org + len(ex.bytes)))
    L = ex.labels
    cp = asm(COPIER_SRC); put(rom, 64, cp.org, cp.bytes)
    # reset: the 255-byte helper copy loop -> JSR to the 1KB copier (bank 64 is at $8000)
    o = bytes(rom[off(FIX, 0xFF48):off(FIX, 0xFFB9)])
    k = o.find(bytes([0xBD, 0xFF, 0x7F, 0x9D, 0xFF, 0x5B, 0xCA, 0xD0, 0xF7])) - 2
    assert k > 0 and o[k] == 0xA2
    put(rom, FIX, 0xFF48 + k, jsr(COPIER) + b'\xEA' * 8)
    # text pointer banks
    for bank, a, h in ((FIX, 0xEEBB, 'tbase'), (FIX, 0xF0D2, 'nbase'), (126, 0xD1DA, 'sbase')):
        assert get(rom, bank, a, 3) == b'\x18\x69\x18', hex(a)
        put(rom, bank, a, jsr(L[h]))
    # one row per line
    assert get(rom, FIX, 0xEEC0, 5) == b'\xa5\x93\x20\x03\xff'
    put(rom, FIX, 0xEEC0, jsr(L['txton']) + b'\xEA\xEA')
    for a, h in ((0xEEEC, 'txtend'), (0xEEF3, 'txtoff')):
        assert get(rom, FIX, a, 5) == b'\xa5\x57\x20\x03\xff', hex(a)
        put(rom, FIX, a, jsr(L[h]) + b'\xEA\xEA')
    assert get(rom, FIX, 0xEF4C, 4) == b'\xe6\x1f\xe6\x1f'
    put(rom, FIX, 0xEF4C, jsr(L['h_nl']) + b'\xEA')
    for a in (0xEE86, 0xEE90):
        assert get(rom, FIX, a, 3) == b'\x38\xe9\x02', hex(a)
        put(rom, FIX, a, jsr(L['h_sub']))
    assert get(rom, FIX, 0xF086, 5) == b'\xa5\x98\x18\x65\x1f'
    put(rom, FIX, 0xF086, jsr(L['h_ypos']) + b'\xEA\xEA')
    assert get(rom, FIX, 0xF6AE, 4) == b'\xa5\x38\x85\x3a'
    put(rom, FIX, 0xF6AE, jmp(L['h_flush']) + b'\xEA')

if __name__ == '__main__':
    rom = bytearray(open(sys.argv[1], 'rb').read())
    report = []
    for e in json.load(open('script/ff3/names8800.json')): NAMES[e['id']] = e['en']
    font(rom)
    put_tables(rom, report)
    engine(rom, report)
    open(sys.argv[2], 'wb').write(rom)
    print('\n'.join(report))
