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
from latin_font import tile, packed_label, COND, TIGHT
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

# "'s" as one tile (code $C9, unused): only in "Little People's Bread", whose second word
# pair needs 13 cells in the 13-wide battle item entry
LIG_S = 0xC9
LIG_NAMES = {164}
LIG_ROWS = ["##......", ".#......", "#..#####", "..#.....", "...####.", ".......#", "..#####.", "........"]

def font(rom):
    for ch in NEW_GLYPHS:
        o = HDR + FONT + ENC[ch] * 16; rom[o:o + 16] = tile(ch, fg=3, bg=2)
    lo = bytearray(8); hi = bytearray(8)
    for y, r in enumerate(LIG_ROWS):
        for x in range(8):
            c = 3 if r[x] == '#' else 2
            if c & 1: lo[y] |= 0x80 >> x
            if c & 2: hi[y] |= 0x80 >> x
    o = HDR + FONT + LIG_S * 16; rom[o:o + 16] = bytes(lo + hi)

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

SPEAKER = re.compile(r'^(\{1[0-3]:..\}|\{18:..\}|\{07\}|[A-Z][\w\'.-]*(?: (?:of|the|[A-Z0-9][\w\'.-]*))*): "')
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
TABLES = [('t8000', 0x8000, 66), ('t8400', 0x8400, 72), ('t8600', 0x8600, 76),
          ('t8200', 0x8200, 80), ('names8800', 0x8800, 82)]  # even: the battle maps 16KB
DIALOGUE = ('t8000', 't8400', 't8600')
ONE_BANKS = (66, 80)                    # banks drawn one row per line (dialogue tables)

def load_rows(name):
    rows = json.load(open('script/ff3/%s.json' % name))
    if name == 'names8800' and os.environ.get('FF3_TEST_GOBLIN'):     # test builds only
        for e in rows:
            if e['id'] == 0x120: e['en'] = os.environ['FF3_TEST_GOBLIN']
    return rows

def put_tables(rom, report):
    for name, table, base in TABLES:
        rows = load_rows(name)
        lin = 0; blob = bytearray()
        for e in rows:
            t = e['en'] or ''
            if (name, e['id']) in NARRATION: t = centred(t, NARRATION[name, e['id']])
            elif name in DIALOGUE and t: t = layout(t)
            data = enc(t) + b'\0'
            if name == 'names8800' and e['id'] in LIG_NAMES:
                data = data.replace(enc("'s"), bytes([LIG_S]))
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
TB16:   .ds 1   ; battle string copy: the table's base in 16KB banks
BLEN:   .ds 1   ; battle box text: length, split index, first part's length, cost
BSPL:   .ds 1
BL1:    .ds 1
BCOST:  .ds 1
BX:     .ds 1
ISAV:   .ds 1   ; status slot: index and table of the copied word, its first tile
TSAV:   .ds 1
TCODE:  .ds 1
ENEXT:  .ds 1   ; enemy list: next free tile of the pool
MX:     .ds 1   ; magic window: column of the spell being copied
    .ds 2
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
tsel:           ; bank 53 $A616 (battle string copy): bank EB
    ldx #$12
    bne far87
btidyf:         ; bank 52 converter: btidy (bank EB)
    ldx #6
    bne far87
slotcopy:       ; bank 52 status line ($9C2E spell, $9C47 command, $9C79 ailment: JSR $A609)
    sta ISAV
    pha
    lda $19
    sta TSAV
    pla
    jsr $A609
    inc $A9         ; (the IRQ runs the sound driver, which maps its own banks, only
    lda #$80+SB     ;   while $A9 = 0, as during the game's bank switches)
    sta $5115
    jsr $A000
    lda #$80+53
    sta $5115
    dec $A9
    rts
encopy:         ; bank 52 enemy list ($9DBE: JSR $A609, monster A): the name; compact
    sta ISAV    ;   tiles for a word too wide for the list (enfix, bank EB)
    jsr $A609
    ldx #0
    beq far87
itemcopy:       ; bank 53 $B20C (battle item entry: JSR $A609, name from X 1): the name
    jsr $A609   ;   also kept whole at ITMN (the ':' and count overwrite its tail): bank EB
    ldx #$0F
    bne far87
itemconv:       ; bank 53 $B22F (JSR $966A, 13 wide): the entry over its two rows (bank EB)
    ldx #3
    bne far87
magcopy:        ; bank 53 $B76C (magic window: JSR $A609, spell at X 9/16/23): the name
    stx MX      ;   and mark kept by column (bank EB)
    jsr $A609
    ldx #$0C
    bne far87
magconv:        ; bank 53 $B782 (JSR $966A, 28 wide): the level row over its two rows
    ldx #9
far87:          ; call bank EB at $A000 + X (mapped at $A000 in place of bank 53)
    stx FV
    inc $A9         ; (the IRQ runs the sound driver, which maps its own banks, only
    lda #$80+EB     ;   while $A9 = 0, as during the game's bank switches)
    sta $5115
    jsr .j
    lda #$80+53
    sta $5115
    dec $A9
    rts
.j:
    jmp (FV)
FV:
    .db 0, $A0
sname:          ; $F2FE (codes 10-13 xx 01: a job, t8200 226 +): the Japanese continues
    pha         ;   in the code 18 name decode ($F0C5), whose base is the name table's;
    and #$1F    ;   here the system table's
    ora #$80
    sta $3F
    pla
    lsr a
    lsr a
    lsr a
    lsr a
    lsr a
    jsr sbase
    jmp $F0D5
ailsel:         ; $F2BB (codes 10-13 xx 00, an ailment in place of LV): bank JB
    ldy #6
    bne jbgo
spellh:         ; $F384 (codes 10-13 xx 08-1F, a spell in the magic screen): bank JB
    ldy #9
    bne jbgo
jobname:        ; $F30D (codes 10-13 xx 01, the job): bank JB
    ldy #3
jbgo:
    pha
    lda #$80+JB
    sta $5114
    pla
    jmp $8000
jobload:        ; $DD0C (menu graphics loaded, rendering off): the job names' tiles
    jsr $DFF8
    ldy #0
    jsr jbgo
    lda #$80+60
    sta $5114
    rts
copy16:         ; $D1E0 (system string copied to $7B01 for the selected character: code 10
    ldy #0      ;   becomes $9E): 16-bit (the English status screen is longer than 255);
    sty $7B00   ;   the loop is in place of the Japanese one (CPYL)
    lda #$01
    sta $82
    lda #$7B
    sta $83
    jmp $D1E3
cpyw:
    sta ($82),y
    iny
    bne .x
    inc $81
    inc $83
.x:
    rts
onerow:         ; C = 1 in one-row mode
    lda ONE
    cmp #1
    rts
txton:          ; $EEC0 (text drawing starts): one row per line for the English
    lda $93     ;   dialogue banks, and for a text starting with code 0E (ignored by
    jsr $FF03   ;   the game: the windows laid out anew, as the status screen)
    ldy #0
    sty ONE
    lda ($3E),y
    cmp #$0E
    beq .o
    lda $93
    cmp #R0
    bcc .x
    cmp #R1
    bcs .x
.o:
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
    ldx ONE         ; (one row: the text is on row $98 + $1F - 1, the cursor's upper half
    beq .r          ;   on the row above it, as above a Japanese line)
    sec
    sbc #2
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
MAGN:   .ds 48  ; magic window: the three names of a level row (16 each)
MAGM:   .ds 3   ;   and their marks
ITMN:   .ds 24  ; battle item entry: the whole name
'''

BCOPY_SRC = '''
    org $A621       ; bank 53: the pointer is a linear offset into the table's 64KB from
    lda $1C         ;   its base: 16KB bank TB16 + (offset >> 14), address $8000 + offset
    pha             ;   & $3FFF (the Japanese hard-codes base $0C, i.e. bank $18)
    clc
    adc TB16
    tay
    pla
    asl a
    asl a
    asl a
    asl a
    asl a
    asl a
    sta $1A
    pla
    sta $19
    pla
    sta $18
    lda #$80
    sec
    sbc $1A
    clc
    adc $19
    sta $19
    pla
    tax
    tya
    jmp $FD4A
'''

# battle boxes (bank 52 $8E83, 9 bytes each: top-left name table address, interior
# width, save buffer; bottom-left address, save pointer of the bottom row): attacker,
# action, target, result, message. The Japanese 8/8/8/8/17 columns hold English as two
# rows (the dakuten row and the main row): names 12, actions 15, messages 28 (the action
# boxes right of the name boxes sharing a border; the message box under both, as wide).
BOXES = [(1, 19, 12), (14, 19, 15), (1, 22, 12), (14, 22, 15), (1, 25, 28)]
BOX_SAVE = 0x5E90                      # ExRAM: 4 rows x (width + 2) per box, 368 bytes
BOX_CALLS = [(0x9091, 0), (0x90C1, 1), (0x9168, 1), (0x91BF, 2), (0x91EF, 3), (0x9253, 4), (0x9313, 4)]

BCONV_SRC = '''
    org $966A       ; bank 52: battle text ($7AD7, 0-terminated) into the box buffer ($4E),
bconv:              ;   rows $18 wide; the Japanese converter (dakuten on the row above) is
    lda $18         ;   replaced. Lists and layouts are copied as the Japanese lays them
    jsr $A558       ;   out (01 newline: two rows, 02 xx: skip xx columns)
    ldx #0
    ldy #0
.r:
    lda $7AD7,x
    beq .x
    cmp #1
    bne .r2
    lda $18
    asl a
    jsr $A558
    inx
    ldy #0
    beq .r
.r2:
    cmp #2
    bne .r3
    inx
    tya
    clc
    adc $7AD7,x
    tay
    inx
    bne .r
.r3:
    sta ($4E),y
    inx
    iny
    bne .r
.x:
    rts
bconvb:             ; box texts and command entries (call sites patched): the text is
    lda $18         ;   tidied and, wider than the box, split over the box's two rows at
    jsr $A558       ;   the most even space (or after a hyphen)
    jsr btidyf
.w:
    ldx #0
    lda BSPL
    cmp #$FF
    beq .o
    sec             ; first part on the row above
    lda $4E
    sbc $18
    sta $1E
    lda $4F
    sbc #0
    sta $1F
    ldy #0
.u:
    cpy BL1
    beq .ud
    lda $7AD7,y
    sta ($1E),y
    iny
    bne .u
.ud:
    ldx BSPL
    inx
.o:
    ldy #0
.l:
    cpy $18
    beq .x2
    lda $7AD7,x
    beq .x2
    sta ($4E),y
    inx
    iny
    bne .l
.x2:
    rts
trsfix:             ; bank 52 $9340 (treasure: "Treasure:" + the item's name): the Japanese
    ldx #0          ;   blanks the name's icon at a fixed column ($7ADC); here the cell
.f:                 ;   after the colon, an icon made a space or a space put in before
    lda $7AD7,x     ;   a name without one
    beq .d
    inx
    cmp #$C8
    bne .f
    lda $7AD7,x
    beq .d
    cmp #$80
    bcs .i
    lda #$FF
    sta $7AD7,x
.d:
    rts
.i:
    lda #$FF
.s:
    ldy $7AD7,x
    sta $7AD7,x
    inx
    tya
    bne .s
    sta $7AD7,x
    rts
'''

# status window slot (5 cells after '/'): a word longer than 5 letters ("/" and the word)
# is drawn on 6 tiles of its own in condensed letters (tight ones if needed), uploaded to
# the line's tile slots (6 per line from SLOT0) when the line is built
SLOT_BANK, SLOT0 = 86, 0xD0
ENEMY_BANK = 87
SLOT_SRC = '''
    org $A000
slotfix:
    lda TSAV
    ldx ISAV
    cmp #$89
    bne .c
    lda SPL,x
    sta $1E
    lda SPH,x
    jmp .g
.c:
    cmp #$8C
    bne .a
    lda CML,x
    sta $1E
    lda CMH,x
    jmp .g
.a:
    lda AIL,x
    sta $1E
    lda AIH,x
.g:
    sta $1F
    bne .k
    lda TSAV        ; as drawn by the game: a spell's icon gives way to '/'
    cmp #$89
    bne .r
    lda #$C7
    sta $7AE3
.r:
    rts
.k:
    lda $52
    asl a
    adc $52
    asl a
    clc
    adc #SLOT0
    sta TCODE
    jsr $FB80       ; next vertical blank
    lda TCODE       ; (battle windows use the $1000 pattern table, below the split)
    lsr a
    lsr a
    lsr a
    lsr a
    ora #$10
    pha
    lda TCODE
    asl a
    asl a
    asl a
    asl a
    tax
    pla
    jsr $F8E0
    ldy #0
.u:
    lda ($1E),y
    sta $2007
    iny
    cpy #96
    bne .u
    jsr $8D03
    ldx #0
    lda TCODE
.t:
    sta $7AE3,x
    clc
    adc #1
    inx
    cpx #6
    bne .t
    lda #0
    sta $7AE9
    rts
'''

# enemy list (bank 52 $9D9E, 8 columns, two rows a name): a word wider than 8 is drawn
# on compact tiles from a pool (codes not used by the English font), uploaded when the
# list is built; record: tile count, tiles, the name with codes 1..n for them
EN_POOL = list(range(0xE8, 0xF7)) + list(range(0x7B, 0x80))
ENFIX_SRC = '''
    org $A000
    jmp enfix
    jmp iconv
    jmp btidy
    jmp mconv
    jmp magcp
    jmp itemcp
    jmp tselb
tselb:          ; (tsel; $1A/$1B = address of the pointer entry): the table's 16KB base
    lda $1B     ;   bank; then $1A/$1B = $4000 as the Japanese
    and #$FE
    sec
    sbc #$80
    lsr a
    tax
    lda TBASE,x
    lsr a
    sta TB16
    lda #0
    sta $1A
    lda #$40
    sta $1B
    rts
itemcp:         ; (itemcopy) the whole name at ITMN
    ldx #0
.l:
    lda $7AD8,x
    sta ITMN,x
    beq .r
    inx
    bne .l
.r:
    rts
magcp:          ; (magcopy) name and mark (X - 1) kept by column (MAGN + 16k, MAGM + k)
    lda MX
    sec
    sbc #9
    ldx #0
.d:
    cmp #7
    bcc .k
    sbc #7
    inx
    bne .d
.k:
    ldy MX
    lda $7AD6,y     ; (only $73 is a mark: a usable spell leaves the previous name's tail)
    cmp #$73
    beq .m
    lda #$FF
.m:
    sta MAGM,x
    txa
    asl a
    asl a
    asl a
    asl a
    tax
.c:
    lda $7AD7,y
    sta MAGN,x
    beq .r
    inx
    iny
    bne .c
.r:
    rts
enfix:
    lda $24
    bne .a
    sta ENEXT
.a:
    ldx ISAV
    lda ENL,x
    sta $1E
    lda ENH,x
    sta $1F
    ora $1E
    bne .h
    rts
.h:
    ldy #0
    lda ($1E),y
    sta $1C
    clc
    adc ENEXT
    cmp #NPOOL+1
    bcc .ok
    rts
.ok:
    lda #1
    sta $1B
    lda #0
    sta $1A
.t:
    lda $1A
    cmp $1C
    beq .s0
    and #3
    bne .w
    jsr $FB80       ; four tiles a vertical blank
.w:
    lda $1A
    clc
    adc ENEXT
    tax
    lda POOL,x
    pha
    lsr a
    lsr a
    lsr a
    lsr a
    ora #$10
    sta $1D
    pla
    asl a
    asl a
    asl a
    asl a
    tax
    lda $1D
    jsr $F8E0
    ldy $1B
    ldx #16
.b:
    lda ($1E),y
    sta $2007
    iny
    dex
    bne .b
    sty $1B
    inc $1A
    lda $1A
    and #3
    bne .t
    jsr $8D03
    jmp .t
.s0:
    jsr $8D03
    ldy $1B
    ldx #0
.c:
    lda ($1E),y
    beq .e
    cmp #16         ; codes 1..15: the record's tiles
    bcs .d
    clc
    adc ENEXT
    sty $1B
    tay
    lda POOL-1,y
    ldy $1B
.d:
    sta $7AD7,x
    iny
    inx
    bne .c
.e:
    sta $7AD7,x
    lda ENEXT
    clc
    adc $1C
    sta ENEXT
.r:
    rts
iconv:              ; battle item entry ($7AD7: mark, ':' at $0A, count at $0B/$0C; the
    clc             ;   name with its icon at ITMN), rows 13 wide at ($4E): one row as the
    lda $4E         ;   Japanese when the name fits 9; else over the entry's two rows:
    adc #13         ;   (A) part 1 above, part 2 and ':' count on the main row, or (B) part
    sta $4E         ;   1 and ':' count above, part 2 (up to 13) on the main row
    bcc .a0
    inc $4F
.a0:
    sec
    lda $4E
    sbc #13
    sta $1E
    lda $4F
    sbc #0
    sta $1F
    ldx #0
.n:
    lda ITMN,x
    beq .n2
    inx
    bne .n
.n2:
    stx $1C         ; name length
    lda $7AD7       ; mark
    ldy #0
    cpx #10
    bcs .sp
    sta ($4E),y     ; one row: mark, name, ':' count
    jsr .name1
    jmp .cnt
.sp:
    ldx #0          ; split: a space (part 1 = x) or a hyphen (x + 1)
.s:
    lda ITMN,x
    beq .raw
    cmp #$FF
    beq .s1
    cmp #$C2
    bne .s9
    inx
    stx $1A
    dex
    jmp .s2
.s1:
    stx $1A
.s2:
    lda $1C         ; part 2 length = L - x - 1
    clc
    sbc $1A
    adc #0
    stx $1D
    sec
    lda $1C
    sbc $1D
    sec
    sbc #1
    sta $1B         ; part 2 length
    lda $1A
    cmp #13
    bcs .s9
    lda $1B
    cmp #10
    bcs .tb
    jmp .la         ; (A)
.tb:
    lda $1A
    cmp #10
    bcs .s9
    lda $1B
    cmp #14
    bcs .s9
    jmp .lb         ; (B)
.s9:
    inx
    bne .s
.raw:
    lda $7AD7
    ldy #0
    sta ($4E),y
    jsr .name1
    jmp .cnt
.la:                ; (A) upper: mark, part 1; main: part 2 from 1, ':' count
    lda $7AD7
    ldy #0
    sta ($1E),y
    jsr .up1
    ldx $1D
    inx
    ldy #1
.la2:
    lda ITMN,x
    beq .cnt
    sta ($4E),y
    inx
    iny
    bne .la2
.lb:                ; (B) upper: mark, part 1, ':' count; main: part 2 (from 0 if 13)
    lda $7AD7
    ldy #0
    sta ($1E),y
    jsr .up1
    ldy #10
    lda #$C8
    sta ($1E),y
    iny
    lda $7AE2
    sta ($1E),y
    iny
    lda $7AE3
    sta ($1E),y
    ldx $1D
    inx
    ldy #1
    lda $1B
    cmp #13
    bne .lb2
    dey
.lb2:
    lda ITMN,x
    beq .x
    sta ($4E),y
    inx
    iny
    bne .lb2
.x:
    rts
.cnt:
    ldy #10
    lda #$C8
    sta ($4E),y
    iny
    lda $7AE2
    sta ($4E),y
    iny
    lda $7AE3
    sta ($4E),y
    rts
.name1:             ; the whole name on the main row from column 1 (up to 9)
    ldx #0
    ldy #1
.nm:
    lda ITMN,x
    beq .nr
    cpy #10
    beq .nr
    sta ($4E),y
    inx
    iny
    bne .nm
.nr:
    rts
.up1:               ; part 1 (length $1A) on the upper row from column 1
    ldx #0
    ldy #1
.u:
    cpx $1A
    beq .ur
    lda ITMN,x
    sta ($1E),y
    inx
    iny
    bne .u
.ur:
    rts
btidy:          ; bank 52 converter: tidy BUF ($7AD7) and choose the split (BSPL, BL1)
    ldx #0          ; tidy: no trailing or double spaces; leading spaces dropped in the
    ldy #0          ;   boxes (12 or more wide), one kept in a list entry (the cursor column)
    lda #0
    sta TMP
    lda $18
    cmp #12
    bcc .n
    dec TMP
.n:
    lda $7AD7,x
    beq .e
    inx
    cmp #$FF
    bne .c
    cmp TMP
    beq .n
.c:
    sta TMP
    sta $7AD7,y
    iny
    bne .n
.e:
    lda TMP
    cmp #$FF
    bne .t
    cpy #0
    beq .t
    dey
.t:
    lda #0
    sta $7AD7,y
    sty BLEN
    lda #$FF
    sta BCOST
    sta BSPL
    cpy $18
    beq .r
    bcc .r
    ldx #0          ; split candidates: a space (first part x long) or a hyphen (x+1)
.p:
    lda $7AD7,x
    beq .r
    cmp #$FF
    beq .sp
    cmp #$C2
    bne .nx
    txa
    clc
    adc #1
    bne .k
.sp:
    txa
.k:
    sta TMP
    cmp $18
    beq .k1
    bcs .r
.k1:
    stx BX          ; (rest = BLEN - x - 1)
    lda BLEN
    clc
    sbc BX
    cmp $18
    beq .k2
    bcs .nx
.k2:
    cmp TMP
    bcs .m
    lda TMP
.m:
    cmp BCOST
    bcs .nx
    sta BCOST
    stx BSPL
    lda TMP
    sta BL1
    jmp .nx2
.nx:
.nx2:
    inx
    bne .p
.r:
    rts
mconv:              ; magic window level row: upper row: mark 1, the level and MP ($7AD7
    clc             ;   X 0-6) from X 2, marks 2 and 3 at X 9 and 18; main row: the three
    lda $4E         ;   spells (icon and name) at X 0, 9, 18 (names over 8 letters on
    adc #28         ;   compact tiles)
    sta $4E
    bcc .a
    inc $4F
.a:
    sec
    lda $4E
    sbc #28
    sta $1E
    lda $4F
    sbc #0
    sta $1F
    ldy #2
    ldx #0
.p:
    lda $7AD7,x
    sta ($1E),y
    inx
    iny
    cpx #7
    bne .p
    ldx #0          ; column k
.k:
    lda MXCOL,x
    tay
    lda MAGM,x
    sta ($1E),y
    lda #$FF
    sta MAGM,x
    stx $1C
    txa
    asl a
    asl a
    asl a
    asl a
    tax             ; name buffer
    lda MAGN,x
    bne .h
    jmp .nx
.h:
    lda #0          ; length
    sta $1D
.l:
    lda MAGN,x
    beq .le
    inx
    inc $1D
    bne .l
.le:
    lda $1C
    asl a
    asl a
    asl a
    asl a
    tax
    lda $1D
    cmp #10
    bcs .long
.w:
    lda MAGN,x
    beq .wd
    sta ($4E),y
    inx
    iny
    bne .w
.wd:
    jmp .nx0
.long:              ; icon, then the word's tiles (uploaded now)
    lda MAGN,x
    sta ($4E),y
    iny
    lda $1D
    cmp #12
    beq .cat
    lda #<LEVT
    sta $1A
    lda #>LEVT
    sta $1B
    lda #LEV0
    ldx #LEVN
    bne .up
.cat:
    lda #<CATT
    sta $1A
    lda #>CATT
    sta $1B
    lda #CAT0
    ldx #CATN
.up:
    sty $1D         ; (column of the word)
    pha
    stx $18         ; ($18: tile count; restored below to 28)
    jsr $FB80
    pla
    pha
    lsr a
    lsr a
    lsr a
    lsr a
    ora #$10
    tay
    pla
    pha
    asl a
    asl a
    asl a
    asl a
    tax
    tya
    jsr $F8E0
    lda $18
    asl a
    asl a
    asl a
    asl a
    tax
    ldy #0
.ub:
    lda ($1A),y
    sta $2007
    iny
    dex
    bne .ub
    jsr $8D03
    pla             ; first tile code
    ldy $1D
    ldx $18
.uc:
    sta ($4E),y
    clc
    adc #1
    iny
    dex
    bne .uc
    lda #28
    sta $18
.nx0:
    ldx $1C
    txa
    asl a
    asl a
    asl a
    asl a
    tax
    lda #0
    sta MAGN,x
.nx:
    ldx $1C
    inx
    cpx #3
    beq .r
    jmp .k
.r:
    rts
MXCOL:
    .db 0, 9, 18
POOL:
'''

def enemy_records(names):
    out = {}
    for i in range(0xF0):
        n = re.sub(r'\[..\]', '', names.get(0x120 + i) or '')
        if not n: continue
        def fits(n, w=8):
            if len(n) <= w: return True
            return any((c == ' ' and k <= w and len(n) - k - 1 <= w) or (c == '-' and k + 1 <= w and len(n) - k - 1 <= w)
                       for k, c in enumerate(n))
        if fits(n): continue
        words = n.split(' ')
        best = min(((' '.join(words[:k]), ' '.join(words[k:])) for k in range(1, len(words))),
                   key=lambda p: max(len(p[0]), len(p[1])), default=None) if len(words) > 1 else None
        rows = list(best) if best else [n]
        tiles = []; text = bytearray()
        for r in rows:
            if text: text.append(0xFF)
            if len(r) <= 8: text += enc(r); continue
            t = None
            for k in range(1, 9):
                t = packed_label(r, k, COND, fg=3, bg=2)
                if t: break
            if not t:
                for k in range(1, 9):
                    t = packed_label(r, k, TIGHT, fg=3, bg=2)
                    if t: break
            assert t, r
            text += bytes(range(len(tiles) + 1, len(tiles) + 1 + len(t))); tiles += t
        assert len(tiles) <= 12, (n, len(tiles))
        out[i] = bytes([len(tiles)]) + b''.join(tiles) + bytes(text) + b'\0'
    return out

def slot_words(rom, L):
    names = {e['id']: e['en'] for e in load_rows('names8800')}
    sysx = {e['id']: e['en'] for e in json.load(open('script/ff3/t8200.json'))}
    clean = lambda t: re.sub(r'\[..\]|\{..(:..)?\}', '', t or '').strip()
    groups = [('SP', [names.get(0xC8 + i) for i in range(56)]),
              ('CM', [names.get(0x220 + i) for i in range(32)]),
              ('AI', [sysx.get(0x16 + i) for i in range(10)])]
    code = asm(SLOT_SRC + ''.join('%sL: .ds %d\n%sH: .ds %d\n' % (g, len(w), g, len(w)) for g, w in groups),
               syms=dict(L, SLOT0=SLOT0))
    base = code.org + len(code.bytes)
    data = bytearray(); ptrs = {}
    for g, words in groups:
        for i, w in enumerate(words):
            w = clean(w)
            if len(w) <= 5: continue
            if g == 'CM' and not 0x222 <= 0x220 + i <= 0x236 or g == 'CM' and 0x220 + i in (0x229, 0x233):
                continue                    # messages in the same block, never in the slot
            t = packed_label('/' + w, 6, COND, fg=3, bg=2) or packed_label('/' + w, 6, TIGHT, fg=3, bg=2)
            assert t, w
            ptrs[g, i] = base + len(data); data += b''.join(t)
    img = bytearray(code.bytes)
    for g, words in groups:
        lo = code.labels[g + 'L'] - code.org; hi = code.labels[g + 'H'] - code.org
        for i in range(len(words)):
            a = ptrs.get((g, i), 0); img[lo + i] = a & 0xFF; img[hi + i] = a >> 8
    assert base + len(data) <= 0xC000
    put(rom, SLOT_BANK, code.org, bytes(img) + bytes(data))
    # enemy list, bank ENEMY_BANK
    lev = packed_label('Leviathan', 5, COND, fg=3, bg=2) or packed_label('Leviathan', 6, COND, fg=3, bg=2)
    cat = packed_label('Catastrophe', 6, TIGHT, fg=3, bg=2)
    assert lev and cat and len(lev) + len(cat) <= 24
    longs = [re.sub(r'\[..\]', '', names[0xC8 + i] or '') for i in range(56)]
    assert sorted(len(w) for w in longs if len(w) > 8) == [9, 11], longs
    en = asm(ENFIX_SRC + ''.join('    .db $%02X\n' % c for c in EN_POOL) + 'ENL: .ds 240\nENH: .ds 240\n'
             + 'LEVT: .ds %d\nCATT: .ds %d\n' % (16 * len(lev), 16 * len(cat)),
             syms=dict(L, NPOOL=len(EN_POOL), LEV0=0xD0, LEVN=len(lev), CAT0=0xD0 + len(lev), CATN=len(cat)))
    img = bytearray(en.bytes); base = en.org + len(img); data = bytearray()
    k = en.labels['LEVT'] - en.org; img[k:k + 16 * len(lev)] = b''.join(lev)
    k = en.labels['CATT'] - en.org; img[k:k + 16 * len(cat)] = b''.join(cat)
    for i, rec in enemy_records(names).items():
        a = base + len(data); data += rec
        img[en.labels['ENL'] - en.org + i] = a & 0xFF; img[en.labels['ENH'] - en.org + i] = a >> 8
    assert base + len(data) <= 0xC000
    put(rom, ENEMY_BANK, en.org, bytes(img) + bytes(data))
    return len(ptrs)

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

# field menus: a job name longer than its 7 cells is drawn in condensed letters on tiles of
# its own, all of them at tiles $01.. (map tiles, unused in the menus, which reload them on
# leaving), uploaded with the menu graphics ($DD06, rendering off); the
# ailments shown in place of LV, and "Status" in the 5-cell command window, have condensed
# glyphs of their own in the font's unused codes from $D0
JOB_BANK = 88
STATIC_WORDS = [('Death', 3), ('Stone', 3), ('Silence', 4), ('Blind', 3), ('Poison', 4), ('Status', 4),
                ('Leviathan', 6), ('Catastrophe', 6)]
LONG_SPELLS = {213: 'Leviathan', 220: 'Catastrophe'}     # names table ids; the others fit 8
FIELD_AIL = {22: 'Death', 23: 'Stone', 28: 'Silence', 30: 'Blind', 31: 'Poison'}
JOBF_SRC = '''
    org $8000
disp:
    cpy #3
    bne .a
    jmp jobn
.a:
    cpy #9
    bne .b
    jmp spl
.b:
    cpy #6
    bne jload
    jmp ails
spl:                ; spell $84 (mark if $B9): Leviathan, Catastrophe condensed
    ldx #0
    lda $84
    cmp #LEVI
    beq .k
    ldx #SPN
    cmp #CATA
    beq .k
    jmp $F09D
.k:
    ldy $90
    lda #$72
    sta $07A0,y
    lda $B9
    beq .i
    lda #$73
    sta $07A0,y
.i:
    lda #0
    sta $B9
    lda #$FF
    sta $0780,y
    iny
    sty $90
    lda SPC,x
    ldy #SPN
    jmp put
jload:              ; the condensed job names' tiles to tiles $01..
    lda $84
    pha
    lda $85
    pha
    lda #<JDATA
    sta $84
    lda #>JDATA
    sta $85
    lda $2002
    lda #$00
    sta $2006
    lda #$10
    sta $2006
    ldx #JTILES
.t:
    ldy #0
.l:
    lda ($84),y
    sta $2007
    iny
    cpy #16
    bne .l
    lda $84
    clc
    adc #16
    sta $84
    bcc .n
    inc $85
.n:
    dex
    bne .t
    pla
    sta $85
    pla
    sta $84
    rts
jobn:               ; A = job + $E2: a condensed name (codes JC, JN of them) or the system
    sec             ;   string as the Japanese; either 7 cells
    sbc #$E2
    tay
    lda JN,y
    bne .k
    tya
    clc
    adc #$E2
.p:
    tax             ; as the Japanese ($F2D8): the system string
    jsr $F3E4
    jmp $F2DC
.k:
    tax
    lda JC,y
    ldy $90
.w:
    sta $07A0,y
    pha
    lda #$FF
    sta $0780,y
    pla
    clc
    adc #1
    iny
    dex
    bne .w
    lda #$FF
.f:
    cpy $90         ; (pad to 7)
    beq .x
    tya
    sec
    sbc $90
    cmp #7
    bcs .x
    lda #$FF
    sta $07A0,y
    sta $0780,y
    iny
    bne .f
.x:
    sty $90
    jmp $F291
ails:               ; A = ailments ($6102 & $FE): the first set, as the Japanese
    ldy #22
    asl a
    bcs .f
    ldy #23
    asl a
    bcs .f
    ldy #27
    asl a
    bcs .f
    iny
    asl a
    bcs .f
    iny
    asl a
    bcs .f
    iny
    asl a
    bcs .f
    iny
.f:
    tya
    sec
    sbc #22
    tax
    lda AN,x
    bne .k
    tya
    jmp jobn.p
.k:
    tay
    lda AC,x
put:                ; Y codes from A into the line at $90 (the row above blank)
    ldx $90
.w:
    sta $07A0,x
    pha
    lda #$FF
    sta $0780,x
    pla
    clc
    adc #1
    inx
    dey
    bne .w
    stx $90
    jmp $F291
'''

CPYL_SRC = '''
    org $D1E3
.l:
    lda ($80),y
    cmp #$28
    bcs .s
    cmp #$10
    bcc .s
    bne .c
    lda $9E
.c:
    jsr cpyw
    lda ($80),y
    jsr cpyw
    jmp .l
.s:
    jsr cpyw
    cmp #0
    bne .l
'''

def field_names(rom, L):
    from latin_font import packed_label
    jobs = {e['id']: e['en'] for e in json.load(open('script/ff3/t8200.json'))}
    # static condensed words in the font
    code = 0xD0; codes = {}
    for w, n in STATIC_WORDS:
        t = packed_label(w, n, COND, fg=3, bg=2) or packed_label(w, n, TIGHT, fg=3, bg=2)
        assert t, w
        codes[w] = code
        for k, b in enumerate(t): o = HDR + FONT + (code + k) * 16; rom[o:o + 16] = b
        code += n
    assert code <= 0xF7
    st = codes['Status']
    assert ''.join('[%02X]' % (st + k) for k in range(4)) in jobs[49]
    an = [0] * 10; ac = [0] * 10
    for i, w in FIELD_AIL.items():
        assert jobs[i] == w, (i, jobs[i])
        an[i - 22] = dict(STATIC_WORDS)[w]; ac[i - 22] = codes[w]
    # jobs longer than 7 letters: condensed (COND, else TIGHT) on as few tiles as hold them,
    # all of them at tiles $01.. in the menus (63 free)
    data = bytearray(); jn = []; jc = []; tile_no = 1
    for j in range(22):
        name = jobs[226 + j].rstrip(' ')
        if len(name) <= 7:
            jn.append(0); jc.append(0); continue
        for n in range(4, 8):
            t = packed_label(name, n, COND, fg=3, bg=2)
            if t: break
        else:
            for n in range(4, 8):
                t = packed_label(name, n, TIGHT, fg=3, bg=2)
                if t: break
        assert t, name
        jn.append(n); jc.append(tile_no); tile_no += n; data += b''.join(t)
    assert tile_no <= 0x40, tile_no
    jdata = 0x8200
    names = {e['id']: e['en'] for e in json.load(open('script/ff3/names8800.json'))}
    for i in range(200, 256):
        nm = re.sub(r'\[..\]', '', names[i])
        assert len(nm) <= 8 or LONG_SPELLS.get(i) == nm, (i, nm)
    spn = dict(STATIC_WORDS)['Leviathan']; assert dict(STATIC_WORDS)['Catastrophe'] == spn
    L = dict(L, LEVI=213, CATA=220, SPN=spn)
    L = dict(L, JDATA=jdata, JTILES=len(data) // 16)
    tables = ('SPC:\n    .db $%02X, 0, 0, 0, 0, 0, $%02X\n' % (codes['Leviathan'], codes['Catastrophe']) if spn == 6 else None) + ('JN:\n    .db %s\nJC:\n    .db %s\nAN:\n    .db %s\nAC:\n    .db %s\n' %
              tuple(', '.join('$%02X' % v for v in tb) for tb in (jn, jc, an, ac)))
    jb = asm(JOBF_SRC + tables, syms=L)
    assert jb.org + len(jb.bytes) <= jdata
    put(rom, JOB_BANK, jb.org, jb.bytes); put(rom, JOB_BANK, jdata, bytes(data))
    assert get(rom, FIX, 0xF2BB, 2) == b'\xa0\x16' and get(rom, FIX, 0xF30D, 3) == b'\x4c\xd8\xf2'
    put(rom, FIX, 0xF2BB, jmp(L['ailsel']))
    put(rom, FIX, 0xF30D, jmp(L['jobname']))
    assert get(rom, FIX, 0xF197, 3) == b'\x4c\xd8\xf2'      # code 1E: a job in the job list
    put(rom, FIX, 0xF197, jmp(L['jobname']))
    assert get(rom, FIX, 0xF384, 3) == b'\x4c\x9d\xf0'
    put(rom, FIX, 0xF384, jmp(L['spellh']))
    assert get(rom, 126, 0xDD0C, 3) == b'\x4c\xf8\xdf'
    put(rom, 126, 0xDD0C, jmp(L['jobload']))

MENU_BANK = 60                         # field menus: banks 60/61 ($8000-$BFFF)
def menus(rom):
    # item menu: one column (t8200 #61), cursor moved 4 bytes (one recorded entry) a line
    for a in (0x9F01, 0x9F3E):
        assert get(rom, 60, a, 4) == b'\xa9\x08\x20\x0d', hex(a)
        put(rom, 60, a + 1, b'\x04')
    # equipment: one column (#62: cursor step 4; "Remove Equipment", entry 4 in the
    # Japanese, is entry 5; the portrait at the window's right), candidates one column (#47)
    assert get(rom, 60, 0x9BEE, 4) == b'\xa9\x08\x20\xa3' and get(rom, 60, 0x9C21, 4) == b'\xa9\x08\x20\x0d'
    put(rom, 60, 0x9BEF, b'\x04'); put(rom, 60, 0x9C22, b'\x04')
    assert get(rom, 60, 0x9D9E, 2) == b'\xc9\x10' and get(rom, 60, 0x9D5B, 2) == b'\xa9\x80'
    put(rom, 60, 0x9D9F, b'\x14'); put(rom, 60, 0x9D5C, b'\xd8')
    # the equipment message window ($1E, 17 x 1 inside): the screen's width, two one-row lines
    assert get(rom, 61, 0xAB43 + 0x1E) == b'\x13'
    put(rom, 61, 0xAB43 + 0x1E, b'\x1e')

def engine(rom, report):
    bases = {n: b for n, _, b in TABLES}
    ex = asm(EXRAM_SRC, syms={'B0': bases['t8000'], 'B1': bases['t8200'], 'B2': bases['t8400'],
                              'B3': bases['t8600'], 'B4': bases['names8800'],
                              'R0': ONE_BANKS[0], 'R1': ONE_BANKS[1], 'SB': SLOT_BANK, 'EB': ENEMY_BANK,
                              'JB': JOB_BANK})
    assert ex.org + len(ex.bytes) <= BOX_SAVE, hex(ex.org + len(ex.bytes))
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
    # battle string copy (bank 53 $A609)
    assert get(rom, 53, 0xA616, 8).hex() == 'a900851aa940851b'
    put(rom, 53, 0xA616, jsr(L['tsel']) + b'\xEA' * 5)
    assert get(rom, 53, 0xA669, 3) == b'\x4c\x4a\xfd'
    bc = asm(BCOPY_SRC, syms=L)
    assert bc.org + len(bc.bytes) <= 0xA66C
    put(rom, 53, bc.org, bc.bytes + b'\xEA' * (0xA66C - bc.org - len(bc.bytes)))
    # battle boxes
    bc = asm(BCONV_SRC, syms=L); BL = bc.labels
    assert bc.org + len(bc.bytes) <= 0x9754, hex(bc.org + len(bc.bytes))
    put(rom, 52, bc.org, bc.bytes + b'\xEA' * (0x9754 - bc.org - len(bc.bytes)))
    report.append('battle converter: %d bytes' % len(bc.bytes))
    assert get(rom, 52, 0x9340, 5).hex() == 'a9ff8ddc7a'      # treasure: icon blanked at $7ADC
    put(rom, 52, 0x9340, jsr(BL['trsfix']) + b'\xEA\xEA')
    save = BOX_SAVE
    assert get(rom, 52, 0x8E83, 5).hex() == '612208f57a'
    for k, (x, y, w) in enumerate(BOXES):
        top = 0x2000 + 32 * y + x; bot = top + 96; end = save + 3 * (w + 2)
        put(rom, 52, 0x8E83 + 9 * k, bytes([top & 0xFF, top >> 8, w, save & 0xFF, save >> 8,
                                             bot & 0xFF, bot >> 8, end & 0xFF, end >> 8]))
        save += 4 * (w + 2)
    assert save <= 0x6000, hex(save)
    # status window slot
    n = slot_words(rom, L)
    report.append('status slot: %d compact words' % n)
    assert get(rom, 52, 0x9C2E, 8).hex() == '2009a6a9c78de37a'
    put(rom, 52, 0x9C2E, jsr(L['slotcopy']) + b'\xEA' * 5)
    for a in (0x9C47, 0x9C79):
        assert get(rom, 52, a, 3) == b'\x20\x09\xa6', hex(a)
        put(rom, 52, a, jsr(L['slotcopy']))
    # battle string copy ($FD4A): the terminating 0 is copied too (an English name longer
    # than the Japanese field ran into the field's old contents)
    assert get(rom, FIX, 0xFD4F, 11).hex() == 'b118f0079dd77ae8c8d0f5'
    put(rom, FIX, 0xFD4F, bytes.fromhex('b1189dd77af004e8c8d0f5'))
    # command window (bank 52 $9A98: four commands, each converted 5 wide, window x 4-10):
    # from x 1, 8 wide inside
    for a, old, new in ((0x9AC4, 5, 8), (0x9ACB, 5, 8), (0x9AD8, 4, 1)):
        assert get(rom, 52, a, 2) == bytes([0xA9, old]), hex(a)
        put(rom, 52, a + 1, bytes([new]))
    assert get(rom, 52, 0x8B00, 8).hex() == 'a828b828c828d828'          # its cursor x: 3 columns left
    for k in range(4): put(rom, 52, 0x8B01 + 2 * k, b'\x10')
    for a, k in BOX_CALLS:
        assert get(rom, 52, a + 2, 5) == b'\x85\x18\x20\x6a\x96', hex(a)
        put(rom, 52, a + 1, bytes([BOXES[k][2]]))
        put(rom, 52, a + 4, jsr(BL['bconvb']))
    assert get(rom, 52, 0x9AC8, 3) == b'\x20\x6a\x96'
    put(rom, 52, 0x9AC8, jsr(BL['bconvb']))
    # battle item window entries (bank 53 $B1D8)
    assert get(rom, 53, 0xB20C, 3) == b'\x20\x09\xa6' and get(rom, 53, 0xB22F, 3) == b'\x20\x6a\x96'
    put(rom, 53, 0xB20C, jsr(L['itemcopy'])); put(rom, 53, 0xB22F, jsr(L['itemconv']))
    # battle magic window (bank 53 $B6DC: per level row)
    assert get(rom, 53, 0xB76C, 3) == b'\x20\x09\xa6' and get(rom, 53, 0xB782, 3) == b'\x20\x6a\x96'
    put(rom, 53, 0xB76C, jsr(L['magcopy'])); put(rom, 53, 0xB782, jsr(L['magconv']))
    assert get(rom, 52, 0x8B08, 24).hex() == 'a850b850c850d850a888b888c888d888a8c0b8c0c8c0d8c0'
    for k, x in enumerate((0x08, 0x50, 0x98)):
        for r in range(4): put(rom, 52, 0x8B09 + 8 * k + 2 * r, bytes([x]))
    # enemy list: names over the entry's two rows, compact tiles for a too-wide word
    assert get(rom, 52, 0x9DBE, 10).hex() == '2009a6a9088518206a96'
    put(rom, 52, 0x9DBE, jsr(L['encopy'])); put(rom, 52, 0x9DC5, jsr(BL['bconvb']))
    # one row per line
    assert get(rom, FIX, 0xEEC0, 5) == b'\xa5\x93\x20\x03\xff'
    put(rom, FIX, 0xEEC0, jsr(L['txton']) + b'\xEA\xEA')
    for a, h in ((0xEEEC, 'txtend'), (0xEEF3, 'txtoff')):
        assert get(rom, FIX, a, 5) == b'\xa5\x57\x20\x03\xff', hex(a)
        put(rom, FIX, a, jsr(L[h]) + b'\xEA\xEA')
    assert get(rom, FIX, 0xEF4C, 4) == b'\xe6\x1f\xe6\x1f'
    put(rom, FIX, 0xEF4C, jsr(L['h_nl']) + b'\xEA')
    assert get(rom, FIX, 0xF2FE, 3) == b'\x4c\xc5\xf0'
    put(rom, FIX, 0xF2FE, jmp(L['sname']))
    # code 09 (flush, then one row down: the menus' packed rows) entered the Japanese
    # newline's second INC $1F ($EFE1 JMP $EF4E); its own entry now sits in the NOPs the
    # MMC5 build left after the reset copier call ($FF8C-$FF93), skipped at reset
    assert get(rom, FIX, 0xEFE1, 3) == b'\x4c\x4e\xef' and get(rom, FIX, 0xFF8C, 8) == b'\xEA' * 8
    put(rom, FIX, 0xFF8C, jmp(0xFF94) + b'\xe6\x1f' + jmp(0xEF50))
    put(rom, FIX, 0xEFE1, jmp(0xFF8F))
    for a in (0xEE86, 0xEE90):
        assert get(rom, FIX, a, 3) == b'\x38\xe9\x02', hex(a)
        put(rom, FIX, a, jsr(L['h_sub']))
    assert get(rom, FIX, 0xF086, 5) == b'\xa5\x98\x18\x65\x1f'
    put(rom, FIX, 0xF086, jsr(L['h_ypos']) + b'\xEA\xEA')
    assert get(rom, FIX, 0xF6AE, 4) == b'\xa5\x38\x85\x3a'
    put(rom, FIX, 0xF6AE, jmp(L['h_flush']) + b'\xEA')
    field_names(rom, L)
    assert get(rom, 126, 0xD1E0, 3) == b'\xa0\x00\x8c' and get(rom, 126, 0xD208, 5) == b'\xa9\x3c\x4c\x03\xff'
    cl = asm(CPYL_SRC, syms=L); assert cl.org + len(cl.bytes) <= 0xD208
    put(rom, 126, 0xD1E0, jmp(L['copy16']))
    put(rom, 126, cl.org, cl.bytes + b'\xEA' * (0xD208 - cl.org - len(cl.bytes)))

if __name__ == '__main__':
    rom = bytearray(open(sys.argv[1], 'rb').read())
    report = []
    for e in json.load(open('script/ff3/names8800.json')): NAMES[e['id']] = e['en']
    font(rom)
    put_tables(rom, report)
    engine(rom, report)
    menus(rom)
    open(sys.argv[2], 'wb').write(rom)
    print('\n'.join(report))
