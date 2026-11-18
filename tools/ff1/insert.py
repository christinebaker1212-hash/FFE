"""Insert the English FF1 script into the MMC5 FF1 ROM (from tools/split/build_mmc5.py).

usage: insert.py ff1_mmc5.nes OUT.nes [--report FILE]

Done so far: Latin font, dialogue (table at 0x28000 in the original), menu engine,
English item names, menu strings, item screen.
- Dialogue lines are set one tile row apart instead of two (English has no dakuten row),
  starting one row higher, so the original window (25 columns of text) holds 9 lines.
  Text is reflowed to that width; every string is checked to fit.
- Dialogue moves to the free MMC5 banks 16 (ids 0-127) and 17 (ids 128-255); each bank
  also holds the English item-name table at $B700 used by the {02} insert.
"""
import sys, os, json, re
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
from latin_font import tile, narrow_label
from asm6502 import asm

HDR = 16; BANK = 0x4000
W, H = 25, 9                      # dialogue window text area (columns, lines)

ENC = {chr(0x30 + i): 0x80 + i for i in range(10)}           # digit tiles (redrawn to the new baseline)
for i in range(26):
    ENC[chr(65 + i)] = 0x8A + i; ENC[chr(97 + i)] = 0xA4 + i
ENC.update({'.': 0xBE, ',': 0xBF, "'": 0xC0, '"': 0xC1, '-': 0xC2, '…': 0xC3, '!': 0xC4, '?': 0xC5,
            ':': 0xCA, ';': 0xCB, '(': 0xCC, ')': 0xCD, '%': 0xCE, '&': 0xCF, '+': 0xD0,
            '[': 0xD1, ']': 0xD2, '/': 0x7A, ' ': 0xFF})
NEW_GLYPHS = [c for c in ENC if c not in ' /']

SPECIAL = {0xC6: 'L', 0xC7: 'E', 0xC8: 'H', 0xC9: 'P'}   # letter tiles the game uses directly

def font(rom):
    for ch in NEW_GLYPHS:
        o = HDR + 0x24000 + ENC[ch] * 16
        rom[o:o + 16] = tile(ch, fg=3, bg=2)
    for code, ch in SPECIAL.items():          # same glyphs, so 'HP' or 'L2' match the text
        o = HDR + 0x24000 + code * 16
        rom[o:o + 16] = tile(ch, fg=3, bg=2)

ITEM_MAX = 18                     # longest English item name ({02} insert), set in main

def vlen(s):                      # displayed width: {02} counts as the longest item name
    return len(s.replace('{02}', '#' * ITEM_MAX))

def wrap(text, width=W):
    """Reflow: the Japanese line breaks in FF1 windows are layout breaks."""
    lines = []; line = ''
    for w in text.replace('\n', ' ').split(' '):
        if not w: continue
        if not line: line = w
        elif vlen(line) + 1 + vlen(w) <= width: line += ' ' + w
        else: lines.append(line); line = w
    lines.append(line)
    return lines

def enc(s):
    out = bytearray(); i = 0
    while i < len(s):
        if s[i] == '{':
            j = s.index('}', i); out.append(int(s[i+1:j], 16)); i = j + 1
        elif s[i] == '\n': out.append(0x01); i += 1
        else: out.append(ENC[s[i]]); i += 1
    return bytes(out)

class Bank:
    def __init__(self, rom, n, keep=False):
        self.rom, self.base = rom, HDR + n * BANK
        if not keep: rom[self.base:self.base + BANK] = b'\xFF' * BANK
        self.free = [(0x8200, 0xB700), (0xB900, 0xC000)]
    def put_ptr(self, cpu, val):
        o = self.base + cpu - 0x8000; self.rom[o] = val & 0xFF; self.rom[o + 1] = val >> 8
    def alloc(self, data):
        for k, (a, b) in enumerate(self.free):
            if b - a >= len(data):
                o = self.base + a - 0x8000; self.rom[o:o + len(data)] = data
                self.free[k] = (a + len(data), b); return a
        raise SystemExit('bank full')

def put(rom, cpu, data):                  # fixed bank lives in banks 15 and 31
    for bank in (15, 31):
        o = HDR + bank * BANK + cpu - 0xC000
        rom[o:o + len(data)] = data

def insert_dialogue(rom, report):
    if '--gb' in sys.argv: sys.path.insert(0, os.path.dirname(__file__))
    dia = json.load(open('script/ff1/dialogue.json'))
    items = json.load(open('script/ff1/items.json'))
    global ITEM_MAX; ITEM_MAX = max(len(e['en']) for e in items)
    bad = 0
    for half, bank_no in ((0, 16), (1, 17)):
        bank = Bank(rom, bank_no)
        for e in items:                   # {02} item-name table at $B700 (same layout as original)
            bank.put_ptr(0xB700 + 2 * e['id'], bank.alloc(enc(e['en'] or ' ') + b'\0'))
        for e in dia[half * 128:(half + 1) * 128]:
            if '--gb' in sys.argv:            # GB: 18 columns, pages of 6 lines (code 05)
                import gb_layout
                lines = wrap(e['en'], gb_layout.DLG_W)
                pages = ['\n'.join(lines[k:k + gb_layout.DLG_H]) for k in range(0, len(lines), gb_layout.DLG_H)]
                if max(vlen(l) for l in lines) > gb_layout.DLG_W:
                    bad += 1; report.append('DOES NOT FIT dialogue %d (GB)' % e['id'])
                data = b''.join(enc(p) + (bytes([gb_layout.DLG_PAGE]) if k < len(pages) - 1 else b'')
                                for k, p in enumerate(pages))
                bank.put_ptr(0x8000 + 2 * e['id'], bank.alloc(data + b'\0'))
                continue
            lines = wrap(e['en'])
            if len(lines) > H or max(vlen(l) for l in lines) > W:
                bad += 1; report.append('DOES NOT FIT dialogue %d (%d lines)' % (e['id'], len(lines)))
            bank.put_ptr(0x8000 + 2 * e['id'], bank.alloc(enc('\n'.join(lines)) + b'\0'))
        report.append('bank %d free: %s' % (bank_no, [b - a for a, b in bank.free]))
    # $DB58: pick bank 16/17 from the id (helper in ExRAM: 'dlgbank')
    put(rom, 0xDB58, jmp(DLG_LABEL[0]))
    put(rom, 0xDC81, bytes([0x69, 0x01]))     # newline: 1 tile row (was 2)
    put(rom, 0xD52E, bytes([0x69, 0x03]))     # first line one row higher (was row 4)
    return bad

# ---------------------------------------------------------------------------------
# Menu engine. The menu text drawer ($DEB6/$DECE) writes every character as a vertical
# pair (dakuten row above, character below). English needs no dakuten row, so new
# control codes (05-0B, unused in the original) let a menu use it:
#   05 upper row only (remembers the column)   06 back to that column, lower row only
#   07 previous mode    08 newline of ONE tile row    09 lower row only    0B normal
#   0C skip one column without drawing      0D nn  go to column nn of the row
#   0E/0F third row of a wrapped name (upper row of the next line) / back
#   0A nn  inserted item names use the pre-wrapped table (bank 10 $B400, built for
#          WRAP_WIDTH columns): split at spaces or marked hyphen points onto the upper
#          and lower rows of the line and, if needed, the upper row of the next line.
# Helper code and variables live in MMC5 ExRAM ($5C00, mode 2), copied at reset from the
# first 1KB of CODE_BANK.
CODE_BANK = 18                        # 16KB bank: ExRAM image + menu strings
EX = dict(MODE=0x5C00, PREV=0x5C01, SAVEX=0x5C02, WRAPW=0x5C03, TMP=0x5C04, BUF=0x5C10,
          SLOT=0x5C40, SV54=0x5C05, SV55=0x5C06, SAVEX2=0x5C07, MI=0x5C08, ML=0x5C09, MS=0x5C0A, MT=0x5C0B,
          MU=0x5C0C, MR=0x5C0D, FLIP=0x5C0E, OVF=0x5C0F, MENUBANK=CODE_BANK)
EXRAM_SRC = '''
    org $5C60
BCMDS
dlgbank:        ; $DB58 (dialogue A = id): bank 16 for ids 0-127, 17 for 128-255
    tax
    asl a
    lda #16
    adc #0
    sta $57
    jsr $FE03
    jmp $DB60
partynames:     ; the four names, one per line (shop 'who?' list, was bank 14 $A90E)
    .db $10, 0, 1, $11, 0, 1, $12, 0, 1, $13, 0, 0
clr20:          ; 20 blanks, lower row only
    .db 9, $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF, 0
h_entry:        ; $DEB6 (menu string drawer entry)
    lda #0
    sta MODE
    sta WRAPW
    lda $57
    jsr $FE03
    jmp $DEBB
h_end:          ; end of a drawn string: the caller's bank becomes the current bank
    lda $58
    sta $57
    jmp $FE03
h_char:         ; $DEDE, A = character
    ldy MODE
    bne .sp
    ldy #$FF
    jmp $DEF1
.sp:
    ldx $2002
    dey
    bne .low
    ldx $55
    stx $2006
    ldx $54
    stx $2006
    sta $2007
    jmp $DF04
.low:
    pha
    lda $54
    clc
    adc #$20
    tax
    lda $55
    adc #0
    sta $2006
    stx $2006
    pla
    sta $2007
    jmp $DF04
h_code:         ; codes 05-0F
    sec
    sbc #5
    asl a
    tax
    lda .tab+1,x
    pha
    lda .tab,x
    pha
    rts
.tab:
    .dw .c5-1, .c6-1, .c7-1, .c8-1, .c9-1, .ca-1, .cb-1, .cc-1, .cd-1, .ce-1, .cf-1
.ce:            ; 0E: third row of a name = upper row of the next line, same column
    lda $54
    sta SV54
    lda $55
    sta SV55
    lda SAVEX
    clc
    adc #$40
    sta $54
    bcc .cex
    inc $55
.cex:
    lda #1
    sta MODE
    jmp $DEC7
.cf:            ; 0F: back after the third row, lower row only
    lda SV54
    sta $54
    lda SV55
    sta $55
    lda #2
    sta MODE
    jmp $DEC7
.cd:
    lda ($3E),y
    inc $3E
    bne .cdx
    inc $3F
.cdx:
    sta TMP
    lda $54
    and #$E0
    ora TMP
    sta $54
    jmp $DEC7
.cc:
    inc $54
    jmp $DEC7
.c5:
    lda MODE
    sta PREV
    lda $54
    sta SAVEX
    lda #1
    bne .setm
.c6:
    lda SAVEX
    sta $54
    lda #2
    bne .setm
.c7:
    lda PREV
    jmp .setm
.c9:
    lda #2
    bne .setm
.cb:
    lda #0
    sta WRAPW
.setm:
    sta MODE
    jmp $DEC7
.c8:
    lda $54
    and #$E0
    ora $3A
    clc
    adc #$20
    sta $54
    bcc .c8x
    inc $55
.c8x:
    jmp $DEC7
.ca:
    lda ($3E),y
    inc $3E
    bne .cax
    inc $3F
.cax:
    sta WRAPW
    jmp $DEC7
h_name:         ; $E0A3: item name at ($3E) in bank 10; X = 2*id, C = id bit 7.
    ldy WRAPW   ; With a wrap width set, use the pre-wrapped copy ($B400 table,
    beq .plain  ; codes 05/06/0E/0F place up to three rows)
    bcs .hi
    lda $B400,x
    sta $3E
    lda $B401,x
    sta $3F
    jmp $DECE
.hi:
    lda $B500,x
    sta $3E
    lda $B501,x
    sta $3F
.plain:
    jmp $DECE

barhl:          ; bank 14 $BF0A: highlight the chosen Equip/Swap/Drop
    lda $64
    asl a
    asl a
    clc
    adc $64
    tax
    lda #$C3
    jsr $BF41
    ldy #5
.l:
    lda .t,x
    sta $2007
    inx
    dey
    bne .l
    lda #0
    sta $2006
    sta $2006
    rts
.t:
    .db $AF, $EF, $FF, $FF, $FF     ; cols 12-17
    .db $FF, $FF, $AF, $FF, $FF     ; cols 20-23
    .db $FF, $FF, $FF, $BF, $EF     ; cols 26-29
magpre:         ; bank 14 $A99C: magic shop list, same name wrapping as the item list
    lda #0
    sta $63
    lda #$0A
    sta $0310
    sta $0311
    ldy #2
    rts
shoplist:       ; bank 14 $A86A: shop item list string at $0310
    lda #0
    sta $63
    lda #$0A            ; wrap width 10: long names on the two rows of the name line
    sta $0310
    sta $0311
    ldy #2
.sl:
    ldx $63
    lda $0300,x
    beq .se
    sta $0311,y
    sta $0316,y
    lda #2
    sta $0310,y
    lda #3
    sta $0315,y
    lda #1
    sta $0312,y
    sta $0317,y
    lda #$0D            ; price at column 26 (5 characters, right edge 30)
    sta $0313,y
    lda #26
    sta $0314,y
    tya
    clc
    adc #8
    tay
    inc $63
    lda $63
    cmp #5
    bcc .sl
.se:
    lda #0
    sta $0310,y
    jmp $A8A9
farjsr:         ; X = far routine number: map FAR8 at $C000, call it, restore the previous
    lda farcur  ;   mapping (calls may nest)
    pha
    lda #$80+FAR8
    sta farcur
    sta $5116
    jsr .go
    pla
    sta farcur
    sta $5116
    rts
.go:
    lda FARHI,x
    pha
    lda FARLO,x
    pha
    rts
farcur:
    .db $80+62
magflip:        ; after magdown/magup: redraw the magic window if the page changed
    lda FLIP
    beq .r
    lda #0
    sta FLIP
    lda #1
    jsr $F20F
    jsr $F21B
.r:
    rts
magcur:         ; bank 14 $B829: magic list cursor, level L spell c on row 4+3L+c
    lda $62
    and #3
    asl a
    asl a
    asl a
    sta TMP
    lda $62
    lsr a
    lsr a
    tax
    lda .my,x
    clc
    adc TMP
    sta $41
    lda #80
    sta $40
    jmp $ED24
.my:
    .db 32, 56, 80, 104, 128, 152, 176, 200
m_setbank:      ; bank 14 $B957: menu strings are read from MENUBANK
    lda #$0E
    sta $58
    lda #MENUBANK
    sta $57
    rts
m_copy:         ; bank 14 $B96E: copy Y+1 bytes of menu string A to $6C00 (code 10 -> 10|$66)
    asl a
    tax
    lda $8500,x
    sta $10
    lda $8501,x
    sta $11
    lda #MENUBANK
    sta $57
    jsr $FE03
.l:
    lda ($10),y
    cmp #$10
    bne .s
    ora $66
.s:
    sta $6C00,y
    dey
    cpy #$FF
    bne .l
    lda #$0E
    sta $57
    jsr $FE03
    lda #0
    sta $3E
    lda #$6C
    sta $3F
    jmp $B957
'''
INIT_SRC = '''
    org $DD47
init:           ; called once from reset ($FDF0 has set PRG mode 2 and $5116 first)
    lda #1
    sta $5103
    asl a
    sta $5102
    sta $5104               ; ExRAM mode 2: plain RAM
    lda #$80+CODE2
    sta $5115
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

FAR_SRC = '''
    org $C000
boxline:        ; $F9B9 (far): decoded battle line ($6CD4 pairs) into the box image at ($8A).
    ldx #0      ;   Width = cells up to the box frame; a longer line is split at a
    ldy #0      ;   space onto the two rows (upper row first) of the Japanese line.
.cnt:
    lda $6CD5,x
    beq .gotn
    inx
    inx
    iny
    bne .cnt
.gotn:
    sty TMP
    ldy #0
.w:
    lda ($8A),y
    cmp #$F7
    bcc .wn
    cmp #$FF
    bcc .wend
.wn:
    iny
    cpy #32
    bne .w
.wend:
    sty SAVEX
    tya
    clc
    adc #$20
    sta SAVEX2
    ldx #1      ; a marker $FE in the line: split there (upper row / lower row)
    ldy #0
.fe:
    lda $6CD4,x
    beq .nofe
    cmp #$FE
    beq .gotfe
    inx
    inx
    iny
    bne .fe
.gotfe:
    jmp .sp
.nofe:
    lda TMP
    cmp SAVEX
    bcc .one
    beq .one
    ldy SAVEX
.f:
    tya
    asl a
    tax
    lda $6CD5,x
    cmp #$FF
    beq .sp
    dey
    bne .f
    lda #1      ; no space to split at: overflow (checked by the test harness)
    sta OVF
    jmp .one
.sp:
    sty PREV
    ldy #0
    ldx #1
.u:
    cpy PREV
    beq .ue
    lda $6CD4,x
    sta ($8A),y
    inx
    inx
    iny
    bne .u
.ue:
    inx
    inx
    ldy #$20
.l:
    lda $6CD4,x
    beq .done
    sta ($8A),y
    inx
    inx
    iny
    cpy SAVEX2
    bcc .l
    lda $6CD4,x
    beq .done
    lda #1      ; second row longer than the box: overflow
    sta OVF
    bne .l
.done:
    rts
.one:
    ldy #0
    ldx #0
.o1:
    lda $6CD4,x
    beq .o2
    sta ($8A),y
    iny
    inx
    inx
    bne .o1
.o2:
    ldy #$20
    ldx #0
.o3:
    lda $6CD5,x
    beq .done
    sta ($8A),y
    iny
    inx
    inx
    bne .o3
magpage:        ; $F75C (far): battle magic list, two levels per page ($6AF8 = 0-3). Per level
    ldy #5      ;   two queued lines (marker $FE = start of the line's lower row):
.c:             ;   'L1  <spell 1>' / '    <spell 2>', then '    <spell 3>' / blank,
    lda $FA08,y ;   and the level's MP count in its own record at the right edge
    sta $6A9D,y
    dey
    bne .c
    lda #23     ; one column wider (right frame in line with the command boxes)
    sta $6AA1
    jsr $F688
    jsr $F74F
    lda $6B7A
    jsr $F88F
    clc
    adc #0
    sta $88
    lda #0
    adc #$63
    sta $89
    lda #0
    sta MI
    sta MU          ; output offset in $6AFA
.lv:
    lda $6AF8
    asl a
    clc
    adc MI
    sta ML
    ; ---- line 1
    lda MU
    sta MT          ; start of this string
    ldx MU
    lda #$C6
    sta $6AFA,x
    inx
    lda ML
    clc
    adc #$81
    sta $6AFA,x
    inx
    lda #$FF
    sta $6AFA,x
    inx
    sta $6AFA,x
    inx
    lda #0
    jsr .spell
    lda #$FE
    sta $6AFA,x
    inx
    lda #$FF
    sta $6AFA,x
    inx
    sta $6AFA,x
    inx
    sta $6AFA,x
    inx
    sta $6AFA,x
    inx
    lda #1
    jsr .spell
    lda #0
    sta $6AFA,x
    inx
    stx MU
    lda MI
    asl a
    asl a
    clc
    adc #2
    jsr .queue
    ; ---- MP count (upper row of line 1, column 23)
    lda MU
    sta MT
    ldx MU
    lda ML
    clc
    adc #$20
    tay
    lda ($88),y
    clc
    adc #$80
    sta $6AFA,x
    inx
    lda #$FE
    sta $6AFA,x
    inx
    lda #0
    sta $6AFA,x
    inx
    stx MU
    lda #23
    sta $6A9F
    lda MI
    asl a
    asl a
    clc
    adc #2
    jsr .queuex
    ; ---- line 2
    lda MU
    sta MT
    ldx MU
    lda #$FF
    sta $6AFA,x
    inx
    sta $6AFA,x
    inx
    sta $6AFA,x
    inx
    sta $6AFA,x
    inx
    lda #2
    jsr .spell
    lda #$FE    ; third spell on the upper row; lower row stays blank
    sta $6AFA,x
    inx
    lda #0
    sta $6AFA,x
    inx
    stx MU
    lda MI
    asl a
    asl a
    clc
    adc #4
    jsr .queue
    inc MI
    lda MI
    cmp #2
    beq .done
    jmp .lv
.done:
    rts
.spell:         ; A = slot: append 0E <name index> if the slot holds a spell
    sta MS
    stx MR
    lda ML
    asl a
    asl a
    clc
    adc MS
    tay
    lda ($88),y
    ldx MR
    cmp #0
    beq .sx
    clc         ; battle spell bytes are spell numbers: name index = byte + $AF
    adc #$AF
    pha
    lda #$0E
    sta $6AFA,x
    inx
    pla
    sta $6AFA,x
    inx
.sx:
    rts
.queue:         ; A = y: queue text record 01 3 y ptr(MT)
    pha
    lda #3
    sta $6A9F
    pla
.queuex:        ; A = y, x already in $6A9F
    sta $6AA0
    lda #1
    sta $6A9E
    lda MT
    clc
    adc #$FA
    sta $6AA1
    lda #0
    adc #$6A
    sta $6AA2
    jmp $F688
magdown:        ; bank 12 $9CB4 (far): down = next spell, then next level / page
    lda $6AAA
    cmp #2
    bcs .lv
    inc $6AAA
    rts
.lv:
    lda $6AAB
    and #1
    beq .inc
    lda $6AF8
    cmp #3
    beq .ret
    inc $6AF8
    inc FLIP    ; page redraw happens in magflip (needs the fixed bank at $C000)
.inc:
    lda #0
    sta $6AAA
    inc $6AAB
.ret:
    rts
magup:          ; bank 12 $9CD2 (far)
    lda $6AAA
    beq .lv
    dec $6AAA
    rts
.lv:
    lda $6AAB
    and #1
    bne .dec
    lda $6AF8
    beq .ret
    dec $6AF8
    inc FLIP
.dec:
    lda #2
    sta $6AAA
    dec $6AAB
.ret:
    rts
itemlist:       ; $F896 (far): battle Item list. The Japanese shows weapons and armour in two
    ldy #5      ;   columns; the English names need the full width, so one column of eight
.c:             ;   rows (record j: slot 2j on the upper row, 2j+1 on the lower; slots 0-3
    lda $FA08,y ;   weapons $6118, 4-7 armour $611C)
    sta $6A9D,y
    dey
    bne .c
    jsr $F688
    jsr $F74F
    inc $6A9E
    inc $6A9F
    inc $6AA0
    lda $6B7A
    jsr $F88F
    sta MR
    lda #0
    sta MI
    sta MU
.j:
    lda MU
    sta MT
    tax
    lda MI
    asl a
    sta MS
    jsr .ent
    lda #$FE
    sta $6AFA,x
    inx
    inc MS
    jsr .ent
    lda #0
    sta $6AFA,x
    inx
    stx MU
    lda MT
    clc
    adc #$FA
    sta $6AA1
    lda #0
    adc #$6A
    sta $6AA2
    jsr $F688
    inc $6AA0
    inc $6AA0
    inc MI
    lda MI
    cmp #4
    bne .j
    rts
.ent:           ; ' <name of slot MS>' at X
    lda #$FF
    sta $6AFA,x
    inx
    stx ML
    lda MR
    clc
    adc MS
    tay
    lda $6118,y
    ldx ML
    cmp #0
    beq .e
    and #$7F
    clc
    adc #$1B    ; weapon names
    ldy MS
    cpy #4
    bcc .w
    adc #$43-$1B-1  ; armour names (carry is set here)
.w:
    pha
    lda #$0E
    sta $6AFA,x
    inx
    pla
    sta $6AFA,x
    inx
.e:
    rts
itemmove:       ; bank 12 $9D8C (far): cursor moves of the Item / Drink lists
    lda $68B3   ;   ($6AAA column, $6AAB row; the Item list is told apart by its cursor x)
    and #$F0
    tay
    lda $6AAC
    cmp #$10
    beq .item
    cpy #$80
    beq .r
    cpy #$40
    beq .l
    cpy #$20
    beq .d
    cpy #$10
    beq .u
    rts
.r:
    inc $6AAA
    rts
.l:
    dec $6AAA
    rts
.d:
    inc $6AAB
    rts
.u:
    dec $6AAB
    rts
.item:          ; one list of 8: weapons 0-3 (column 0), then armour 0-3 (column 1)
    cpy #$20
    beq .id
    cpy #$10
    beq .iu
    cpy #0
    beq .ix
    lda $6AAA   ; left / right: the same row of the other group
    eor #1
    sta $6AAA
.ix:
    rts
.id:
    lda $6AAB
    cmp #3
    bne .d
    lda #0
    beq .iw
.iu:
    lda $6AAB
    bne .u
    lda #3
.iw:            ; past either end of a group: the other group's first / last row
    sta $6AAB
    lda $6AAA
    eor #1
    sta $6AAA
    rts
'''
FAR_ROUTINES = ['boxline', 'magpage', 'magdown', 'magup', 'itemlist', 'itemmove']
FAR8 = 40                              # 8KB bank (first half of 16KB bank 20)

def jmp(a): return bytes([0x4C, a & 0xFF, a >> 8])
def jsr(a): return bytes([0x20, a & 0xFF, a >> 8])

def bank_put(rom, bank, cpu, data):
    o = HDR + bank * BANK + cpu - 0x8000
    rom[o:o + len(data)] = data

def menu_engine(rom, report):
    cmds = json.load(open('script/ff1/battle_cmds.json'))
    bc = ''.join('bcmd%d:\n    .db %s, 0\n' % (e['id'], ', '.join(str(b) for b in enc(e['en']))) for e in cmds)
    src = FAR_SRC
    if '--gb' in sys.argv:                     # GB layout: its own battle line writer
        sys.path.insert(0, os.path.dirname(__file__))
        import gb_layout
        a, b = src.index('boxline:'), src.index('magpage:')
        src = src[:a] + src[b:] + gb_layout.far_source(ENC)    # small-font battle text
        a, b = src.index('magpage:'), src.index('magdown:')
        src = src[:a] + gb_layout.MAGPAGE + src[b:]             # magic list rows
        a, b = src.index('itemlist:'), src.index('itemmove:')
        src = src[:a] + gb_layout.ITEMLIST + src[b:]            # item list pages
        for old, new in gb_layout.ITEMMOVE_PATCH:
            assert old in src
            src = src.replace(old, new)
        for r in gb_layout.FAR_GB:
            if r not in FAR_ROUTINES: FAR_ROUTINES.append(r)
    far = asm(src, syms=EX)
    assert far.org + len(far.bytes) <= 0xE000
    o = HDR + FAR8 * 0x2000
    rom[o:o + 0x2000] = far.bytes + b'\xFF' * (0x2000 - len(far.bytes))
    tabs = '\nFARLO:\n    .db ' + ', '.join('<(%d-1)' % far.labels[r] for r in FAR_ROUTINES) + \
           '\nFARHI:\n    .db ' + ', '.join('>(%d-1)' % far.labels[r] for r in FAR_ROUTINES) + '\n'
    ex = asm(EXRAM_SRC.replace('BCMDS', bc) + tabs, syms=dict(EX, FAR8=FAR8))
    FAR_LABELS.update(far.labels)
    img = bytearray(0x400); img[0x60:0x60 + len(ex.bytes)] = ex.bytes
    assert 0x60 + len(ex.bytes) <= 0x400
    bank_put(rom, CODE_BANK, 0x8000, bytes(img))
    L = ex.labels
    LABELS_EX.update(L)
    DLG_LABEL[0] = L['dlgbank']
    init = asm(INIT_SRC, syms={'CODE2': CODE_BANK * 2})
    assert init.org + len(init.bytes) <= 0xDDAB      # dakuten tables $DD47-$DDAA (unused in English)
    put(rom, init.org, init.bytes)
    # PRG mode 2: $8000 16KB ($5115, as the game uses it), $C000 8KB ($5116, normally
    # the first half of the fixed bank; the far-code bank is mapped there by farjsr),
    # $E000 8KB ($5117, power-on last bank). Set from $FDF0, which lies in $E000-$FFFF.
    put(rom, 0xFDF0, bytes([0xA9, 0x80 + 62, 0x8D, 0x16, 0x51, 0xA9, 0x02, 0x8D, 0x00, 0x51])
        + jmp(init.labels['init']))
    put(rom, 0xDEB6, jmp(L['h_entry']) + b'\xEA\xEA')
    put(rom, 0xDEB1, jmp(L['h_end']) + b'\xEA\xEA')
    put(rom, 0xDEDE, jmp(L['h_char']) + jmp(L['h_code']))   # $DEE1: JMP h_code
    put(rom, 0xDF4D, bytes([0x90, (0xDEE1 - 0xDF4F) & 0xFF]))  # BCC $DEE1 (codes 05-0F)
    put(rom, 0xE0A3, jsr(L['h_name']))
    bank_put(rom, 14, 0xB957, jsr(L['m_setbank']) + b'\xEA\xEA\xEA')
    bank_put(rom, 14, 0xB829, jmp(L['magcur']))
    bank_put(rom, 14, 0xB96E, jmp(L['m_copy']))      # $B96C LDY #$7F kept; $BA89 enters at $B96E
    report.append('ExRAM code: %d bytes' % len(ex.bytes))
    return L

def insert_names(rom, report):
    """English item/weapon/armor/magic/class names: bank 10, table $B700 (as before),
    strings in the space the Japanese dialogue left ($8000-$B5FF)."""
    items = json.load(open('script/ff1/items.json'))
    bank = Bank(rom, 10, keep=True)
    bank.free = [(0x8000, 0xB600)]
    for e in items:
        bank.put_ptr(0xB700 + 2 * e['id'], bank.alloc(enc(e['en']) + b'\0'))
    sold = shop_items(rom)
    for e in items:
        lines = wrap_name(e['en'], WRAP_WIDTH)
        fits = len(lines) <= 3 and max(len(l) for l in lines) <= WRAP_WIDTH
        assert fits or e['id'] not in sold, ('shop name does not fit', e['en'], lines)
        if not fits: lines = [e['en']]          # never shown in a shop list
        if len(lines) == 1: data = enc(lines[0])
        else:
            data = b'\x05' + enc(lines[0]) + b'\x06' + enc(lines[1])
            if len(lines) == 3: data += b'\x0E' + enc(lines[2]) + b'\x0F'
        bank.put_ptr(0xB400 + 2 * e['id'], bank.alloc(data + b'\0'))
    NAMES_FREE[:] = bank.free
    report.append('bank 10 names free: %d' % sum(b - a for a, b in bank.free))

WRAP_WIDTH = 9                  # shop list column width
def shop_items(rom):
    """Item ids sold in shops (inventory table bank 14 $8300, 5 per shop, shops 0-70)."""
    sold = set()
    for s in range(71):
        o = HDR + 14 * BANK + 0x0300 + 2 * s
        p = rom[o] | rom[o + 1] << 8
        if not 0x8000 <= p < 0xC000: continue
        q = HDR + 14 * BANK + p - 0x8000
        for v in rom[q:q + 5]:
            if v == 0: break
            sold.add(v)
    return sold

def wrap_name(name, W):
    """Greedy wrap at spaces (never inside a word); at most 3 rows."""
    lines = []; line = ''
    for w in name.split(' '):
        if not line: line = w
        elif len(line) + 1 + len(w) <= W: line += ' ' + w
        else: lines.append(line); line = w
    lines.append(line)
    return lines

def insert_menu_strings(rom, report):
    menu = json.load(open('script/ff1/menu.json'))
    bank = Bank(rom, CODE_BANK, keep=True)
    bank.free = [(0x8400, 0xC000)]
    for e in menu:
        o = HDR + 14 * BANK + 0x0500 + 2 * e['id']
        txt = MENU_OVERRIDE.get(e['id'], e['en'])
        if e['id'] in DESC_IDS:
            lines = desc_flow(txt)
            assert len(lines) <= 4 and max(map(len, lines)) <= 29, (e['id'], lines)
            txt = '{09}' + '{08}'.join(' ' + l for l in lines)
        # codes 10-13 take a parameter; in ' {10}' the extractor read the parameter 00
        # (= character name) as the end of the string, so it is restored here
        if re.search(r'\{1[0-3]\}$', txt): txt += '{00}'
        a = bank.alloc(enc(txt) + b'\0')
        rom[o] = a & 0xFF; rom[o + 1] = a >> 8
    SHOP_FREE[:] = bank.free

def magic_list():
    # 8 levels x 3 tile rows (lower row only), one spell per row at column 12; the level
    # and MP ('L1 c/m') beside the second spell (the first row of L1 lies under the
    # title box). Copied by $B96E with Y=$C0: at most 193 bytes.
    out = '{09}'
    for L in range(8):
        cur, mx, s0 = 0x2C + L, 0x34 + L, 0x14 + 3 * L
        out += '{0D}{0C}{10}{%02X}{08}' % s0
        out += ' L%d {10}{%02X}/{10}{%02X}{0D}{0C}{10}{%02X}{08}' % (L + 1, cur, mx, s0 + 1)
        out += '{0D}{0C}{10}{%02X}' % (s0 + 2)
        if L < 7: out += '{08}'
    assert len(enc(out)) <= 192, len(enc(out))
    return out

# item/magic descriptions and prompts: window 8 (full width, bottom); 4 one-row lines of
# up to 29 letters, reflowed (the Japanese breaks are layout breaks); a final
# 'A button...Yes  B button...No' prompt keeps its own line
DESC_IDS = set(range(4, 35)) | set(range(43, 52)) | {63}
def desc_flow(t, W=29):
    parts = t.split('\n')
    if 'A button' in parts[-1]: body, tail = ' '.join(parts[:-1]), [parts[-1].strip()]
    else: body, tail = ' '.join(parts), []
    out = []; line = ''
    for w in body.split(' '):
        if not w: continue
        if not line: line = w
        elif len(line) + 1 + len(w) <= W: line += ' ' + w
        else: out.append(line); line = w
    out.append(line)
    return out + tail

MENU_OVERRIDE = {
    3: 'Items', 52: 'Weapons', 62: 'Armor',
    42: magic_list(),
    # status screen (windows in status_screen()); values at fixed columns ({0D}{col})
    1: '{04}Gil',
    2: '  Items\n  Magic\n  Weapons\n  Armor\n  Status',
    35: '{10}{00}',
    36: '       {10}{01}',
    37: '',
    38: '{09}{0D}{04}Level{0D}{1A}{10}{03}{08}{0D}{04}Experience EP{0D}{16}{10}{04}{08}'
        '{0D}{04}Until next level{0D}{16}{10}{42}',
    39: '{0D}{01}Strength{0D}{0E}{10}{07}\n{0D}{01}Agility{0D}{0E}{10}{08}\n'
        '{0D}{01}Intelligence{0D}{0E}{10}{09}\n{0D}{01}Vitality{0D}{0E}{10}{0A}\n'
        '{0D}{01}Luck{0D}{0E}{10}{0B}',
    40: '{0D}{12}Weapon{0D}{1B}{10}{3C}\n{0D}{12}Hit Rate{0D}{1B}{10}{3D}\n'
        '{0D}{12}Armor{0D}{1B}{10}{3E}\n{0D}{12}Evasion{0D}{1B}{10}{3F}',
    53: '  Equip   Swap  Drop',     # Equip 12-16, Swap 20-23, Drop 26-29 (highlight blocks)
}

ITEM_SRC = '''
    org $EFF2
loop:
    ldx $62
    lda $0300,x
    bne .go
    jmp $EFE5
.go:
    sta $0322
    ldy #$09            ; lower row only (one item per tile row)
    sty $0320
    ldy #$02            ; insert item name
    sty $0321
    ldy #3
    cmp #$16
    bcc .end
    tax
    lda $6020,x
    sta $10
    lda #$0E
    sta $58
    jsr $FE03
    jsr $8E66
    lda #$FF
    sta $0323
    lda $5E
    sta $0324
    lda $5F
    sta $0325
    ldy #6
.end:
    lda #0
    sta $0320,y
    lda #$20
    sta $3E
    lda #$03
    sta $3F
    lda #3
    sta $3A
    lda $62
    clc
    adc #5
    sta $3B
    jsr $DEB6
    inc $62
    jmp loop
'''

def item_screen(rom):
    """Item list: one item per tile row, 23 rows, full-width window (was 3 columns of
    7-kana names at two rows per item), so every English name and count fits."""
    cur = []
    for i in range(23):
        cur += [8, (5 + i) * 8]
    code = asm(ITEM_SRC)
    assert code.org + len(code.bytes) <= 0xF05B, hex(code.org + len(code.bytes))
    put(rom, code.org, code.bytes)
    put(rom, 0xEFA7, bytes([0xA9, 0x00, 0x85, 0x38, 0xA9, 0x04, 0x85, 0x39,
                            0xA9, 0x20, 0x85, 0x3C, 0xA9, 0x19, 0x85, 0x3D]))   # window (0,4) 32x25
    bank_put(rom, 14, 0xB7F9, bytes(cur))                     # cursor positions
    for a in (0xB5D7, 0xB5DD, 0xB5E2, 0xB5E4, 0xB5ED, 0xB5F5, 0xB5FA, 0xB600):
        o = HDR + 14 * BANK + a - 0x8000
        assert rom[o] == 3, hex(a); rom[o] = 1               # cursor moves: one column

SLOT_SRC = '''
    org $ED84
loop:
    pha
    tax
    asl a
    tay
    lda postab,y
    sta $3A
    lda postab+1,y
    sta $3B
    lda #<clr20         ; clear the row first
    sta $3E
    lda #>clr20
    sta $3F
    txa
    pha
    jsr $DEB6
    pla
    tax
    lda #$09
    sta SLOT
    lda #$FF
    sta SLOT+1
    sta SLOT+2
    lda #0
    sta SLOT+3
    lda $0300,x
    sta $12
    and #$7F
    beq .draw
    clc
    adc $67
    sta SLOT+4
    lda #2
    sta SLOT+3
    lda #0
    sta SLOT+5
    lda $12
    bpl .draw
    lda #$C7            ; E- : equipped
    sta SLOT+1
    lda #$C2
    sta SLOT+2
.draw:
    lda #<SLOT
    sta $3E
    lda #>SLOT
    sta $3F
    jsr $DEB6
    pla
    clc
    adc #1
    cmp #$10
    bcc loop
    lda #$0E
    sta $57
    sta $58
    jmp $FE03
postab:
'''

def equip_screens(rom, labels):
    """Weapon/armor lists: each character's four slots in four rows of one column
    (were 2 x 2 names of 7 kana), so names up to 18 letters fit beside the E- mark."""
    pos = []; cur = []
    for c in range(4):
        for k in range(4):
            y = 6 + 6 * c + k
            pos += [10, y]; cur += [0x40, y * 8]
    code = asm(SLOT_SRC, syms=dict(EX, clr20=labels['clr20']))
    data = code.bytes + bytes(pos)
    assert code.org + len(data) <= 0xEE21, hex(code.org + len(data))
    put(rom, code.org, data)
    bank_put(rom, 14, 0xBED9, bytes(cur))
    for a, old, new in ((0xBD96, 1, 4), (0xBDA0, 2, 1), (0xBDAA, 2, 1)):   # cursor: up/down 1 row,
        o = HDR + 14 * BANK + a - 0x8000                                    # left/right other character
        assert rom[o] == old, hex(a); rom[o] = new
    # windows (x, y, w, h): title box wide enough for 'Weapons', command bar beside it,
    # name boxes aligned with the title box (they share column 8 with the slot windows)
    bank_put(rom, 14, 0xBE8F, bytes([0, 1, 9, 4, 9, 1, 22, 4]))
    for c in range(4):
        bank_put(rom, 14, 0xBE8F + 4 * (2 + 2 * c), bytes([0, 5 + 6 * c, 9, 4]))
    # command bar: cursor columns 10/18/24 and the red highlight of the chosen command
    # over its whole word (5 attribute bytes $23C3-$23C7 instead of 4)
    bank_put(rom, 14, 0xBF07, bytes([80, 144, 192]))
    bank_put(rom, 14, 0xBF0A, jmp(labels['barhl']))

def main_menu(rom, labels):
    """Main menu windows (table bank 14 $BAB5, x y w h): Gil window and command window
    extended to the left screen edge so 'Gil' and 'Weapons' fit; command cursor one
    column left. Battle command words (fixed-bank strings, table $FA1B) move to ExRAM."""
    bank_put(rom, 14, 0xBAB5 + 4 * 5, bytes([0, 10, 11, 5]))
    bank_put(rom, 14, 0xBAB5 + 4 * 6, bytes([0, 15, 11, 14]))
    o = HDR + 14 * BANK + 0xB7D5 - 0x8000
    assert rom[o] == 0x10; rom[o] = 0x08
    bank_put(rom, 14, 0xBAB5 + 4 * 0, bytes([1, 2, 10, 8]))   # orb window, right edge aligned
    bank_put(rom, 14, 0xBAB5 + 4 * 8, bytes([0, 22, 32, 7]))  # description window, full width
    bank_put(rom, 14, 0xBAB5 + 4 * 9, bytes([1, 2, 30, 27]))  # magic list window, full height
    # character windows: the mages' 'まほう' label was built from immediates at $B9EF
    m = labels['bcmd1']
    code = asm('''
        org $B9EF
        lda #<M
        sta $3E
        lda #>M
        sta $3F
        dec $3B
        jsr $DEB6
        lda #3
        sta $3F
    ''', syms={'M': m}).bytes
    assert len(code) <= 0xBA0C - 0xB9EF
    bank_put(rom, 14, 0xB9EF, code + b'\xEA' * (0xBA0C - 0xB9EF - len(code)))
    cmds = json.load(open('script/ff1/battle_cmds.json'))
    for e in cmds:
        a = labels['bcmd%d' % e['id']]
        put(rom, 0xFA1B + 5 * e['id'], bytes([a & 0xFF, a >> 8]))   # records: 01 x y ptr

SHOP_TITLES = {0: ['Weapon', 'Shop'], 1: ['Armor', 'Shop'], 2: ['White', 'Magic', 'Shop'],
               3: ['Black', 'Magic', 'Shop'], 4: ['Church'], 5: ['Inn'], 6: ['Item', 'Shop'],
               7: ['Caravan']}
SHOP_SPEECH = set(range(9, 38)) - {10, 11, 15, 18, 36}


def flow(text, width):
    lines = []; line = ''
    for w in text.replace('\n', ' ').split(' '):
        if not w: continue
        if not line: line = w
        elif len(line) + 1 + len(w) <= width: line += ' ' + w
        else: lines.append(line); line = w
    lines.append(line)
    return lines

def shops(rom, labels):
    """Shops: strings to MENUBANK (table bank 14 $8000), wider speech window with one-row
    lines, title box of up to three short lines, item list with two-row names and the
    price at column 24 in a wider list window, Gil window one column wider."""
    shop = json.load(open('script/ff1/shop.json'))
    bank = Bank(rom, CODE_BANK, keep=True)
    bank.free = SHOP_FREE[:]
    for e in shop:
        txt = e['en']
        if e['id'] in SHOP_TITLES:
            t = SHOP_TITLES[e['id']]
            assert ' '.join(t).replace(' ', '') == txt.replace(' ', ''), (t, txt)
            txt = '{09}' + ('{08}' if len(t) == 1 else '') + '{08}'.join(
                ' ' * ((7 - len(w)) // 2) + w for w in t)
        elif e['id'] in SHOP_SPEECH:
            head = '{08}' if txt.startswith('\n') else ''      # price is printed on line 1
            lines = flow(txt, 9)
            assert len(lines) + (1 if head else 0) <= 9, (e['id'], lines)
            txt = '{09}' + head + '{08}'.join(lines)
        a = bank.alloc(enc(txt) + b'\0')
        o = HDR + 14 * BANK + 2 * e['id']
        rom[o] = a & 0xFF; rom[o + 1] = a >> 8
    SHOP_FREE[:] = bank.free
    bank_put(rom, 14, 0xAA45, jsr(labels['m_setbank']) + b'\xEA\xEA\xEA')
    pn = labels['partynames']
    bank_put(rom, 14, 0xA8FC, bytes([0xA9, pn & 0xFF, 0x85, 0x3E, 0xA9, pn >> 8, 0x85, 0x3F]))
    # windows x[5] y[5] w[5] h[5]: speech, title, list, menu, gold
    win = [(0, 4, 11, 12), (11, 0, 9, 6), (21, 2, 11, 22), (6, 18, 9, 10), (18, 24, 11, 4)]
    for k in range(4):
        bank_put(rom, 14, 0xAC53 + 5 * k, bytes(w[k] for w in win))
    bank_put(rom, 14, 0xA86A, jmp(labels['shoplist']))
    bank_put(rom, 14, 0xA99C, jsr(labels['magpre']) + b'\xEA\xEA\xEA')
    o = HDR + 14 * BANK + 0xAA84 - 0x8000            # price redraw reads entry i of the list
    assert rom[o] == 0x15; rom[o] = 0x17             # string, now 2 bytes further on
    bank_put(rom, 14, 0xA992, bytes([160, 24, 160, 56, 160, 88, 160, 120, 160, 152]))

SHOP_FREE = []

def drink_window(rom):
    """Battle Drink list ($F919): Potion / Antidote with their counts. The Japanese names
    are padded so the counts share a column; the English names are padded to the longer
    one and the window is widened to hold it plus a two-digit count."""
    names = {e['id']: e['en'] for e in json.load(open('script/ff1/items.json'))}
    ents = [(0x19, 0x6BAF, 0x6AFA), (0x1A, 0x6BB0, 0x6B1A)]     # name, count, string
    L = max(len(names[n]) for n, _, _ in ents)
    width = 1 + L + 1 + 2                       # cursor gap, name, space, count (max 99)
    src = """
    org $F919
    ldy #5
.c: lda $FA0D,y
    sta $6A9D,y
    dey
    bne .c
    jsr $F688
    jsr $F74F
    inc $6A9E
    inc $6A9F
    inc $6AA0
"""
    put(rom, 0xFA11, bytes([width + 2]))       # window record 00 3 1 w 6 (read only here)
    for k, (n, cnt, buf) in enumerate(ents):
        num = buf + 1 + 2 + (L - len(names[n]) + 1)     # position of code 11
        src += """
    lda $%04X
    beq .z%d
    sta $%04X
    lda #$11
    sta $%04X
    lda #$%02X
    sta $%04X
    lda #$0E
    sta $%04X
.z%d:
    lda #0
    sta $%04X
    sta $%04X
    lda #$%02X
    sta $6AA1
    lda #$%02X
    sta $6AA2
    jsr $F688
""" % (cnt, k, num + 1, num, n, buf + 2, buf + 1, k, num + 2, num + 3, buf & 0xFF, buf >> 8)
        if k == 0: src += "    inc $6AA0\n    inc $6AA0\n"
    src += "    jmp $F640\n"
    code = asm(src)
    assert code.org + len(code.bytes) <= 0xF994, hex(code.org + len(code.bytes))
    put(rom, code.org, code.bytes)

# victory / level-up strings of the bank 11 table: number codes 0C lo hi kept
DIRECT_STRINGS = {
    bytes([0x0C, 0x78, 0x68, 0xC9]): bytes([0x0C, 0x78, 0x68]) + enc('P'),          # 7P
    bytes([0x60, 0xC2, 0xF2, 0x6A]): enc('Gold'),                                  # ゴールド
    bytes([0x0C, 0x76, 0x68, 0x5D, 0xF2]): bytes([0x0C, 0x76, 0x68]) + enc(' Gil'),  # 30ギル
    bytes([0x02, 0xFF, 0xC6, 0x0C, 0x7A, 0x68]): bytes([0x02, 0xFF]) + enc('L') + bytes([0x0C, 0x7A, 0x68]),
}

BATTLE_BANK = 19
NARROW_NAMES = {'Tyrannosaurus': (7, 0xEB)}   # tiles $EB-$F1
STATUS_LABELS = [(65, 'Stone'), (66, 'Poison'), (67, 'Darkness'), (68, 'Paralysis'), (69, 'Sleep'),
                 (70, 'Silence')]

STORY_W, STORY_ROWS = 20, 9     # box x=2 w=22 (was x=4 w=18); text rows y+2..y+10
def story(rom, report):
    """Bridge / ending story pages (25, table bank 13 $A800, drawn by the menu text drawer
    in an 18x12 box at (4,4) over the title picture). English needs more room: the box is
    22 wide at (2,4) (same centre, so the staff credit pages that share it stay centred;
    the sky left of it and the birds right of it stay as they are) and lines are one tile
    row each (the Japanese spends a row on dakuten). Pages are centred vertically, as the
    Japanese does with leading blank lines. The box palette (attributes) is extended to the
    new columns when the scene is set up. Strings and table go to BATTLE_BANK."""
    bank = Bank(rom, BATTLE_BANK, keep=True); bank.free = BATTLE_FREE[:]
    ptrs = []
    for e in json.load(open('script/ff1/story.json')):
        body = ' '.join(e['en'].strip('\n').split('\n'))
        lines = flow(body, STORY_W)
        assert len(lines) <= STORY_ROWS and max(len(l) for l in lines) <= STORY_W, lines
        pad = (STORY_ROWS - len(lines)) // 2
        txt = '{09}' + '{08}' * pad + '{08}'.join(lines)
        ptrs.append(bank.alloc(enc(txt) + b'\0'))
    tab = bank.alloc(b''.join(bytes([a & 0xFF, a >> 8]) for a in ptrs))
    BATTLE_FREE[:] = bank.free
    code = asm('''
    org $F770       ; (free: the Japanese battle magic list builder, now far code)
geom:           ; bank 13 $B8E3: page box
    lda #1
    sta $FF
    sta $2000
    sta $37
    lda #$0D
    sta $57
    sta $58
setbox:         ; bank 13 $B827 too (the box after the ending pages)
    lda #2
    sta $38
    lda #4
    sta $39
    lda #22
    sta $3C
    lda #12
    sta $3D
    rts
storyptr:       ; bank 13 $BA5F: page $66 from the table in the text bank
    lda $66
    asl a
    tax
    lda #BB
    sta $57
    jsr $FE03
    lda TAB,x
    sta $3E
    lda TAB+1,x
    sta $3F
    lda #$0D
    jsr $FE03
    jmp $C003
scene:          ; bank 13 $B899 (rendering off): as the Japanese, plus the box palette on
    lda #0      ;   columns 2-3 and 20-23 of rows 4-15 in nametable 0
    sta $2001
    sta $66
    ldx #0
    lda $2002
    lda #$27
    sta $2006
    lda #$C0
    sta $2006
.c:
    lda $BA7F,x
    sta $2007
    inx
    cpx #$20
    bcc .c
    ldx #0
.a:
    lda #$23
    sta $2006
    lda .al,x
    sta $2006
    lda .av,x
    sta $2007
    inx
    cpx #6
    bne .a
    lda #0
    sta $FF
    sta $2000
    rts
.al:
    .db $C8, $CD, $D0, $D5, $D8, $DD
.av:
    .db $DD, $FF, $DD, $FF, $DD, $FF
''', syms={'TAB': tab, 'BB': BATTLE_BANK})
    assert code.org + len(code.bytes) <= 0xF88F, hex(code.org + len(code.bytes))
    put(rom, code.org, code.bytes)
    L = code.labels
    o = HDR + 13 * BANK - 0x8000
    assert rom[o + 0xB8E3:o + 0xB8E5] == b'\xa9\x01' and rom[o + 0xB900:o + 0xB903] == b'\x20\x06\xc0'
    rom[o + 0xB8E3:o + 0xB900] = jsr(L['geom']) + jmp(0xB900) + b'\xEA' * 23
    assert rom[o + 0xBA5F:o + 0xBA61] == b'\xa5\x66'
    rom[o + 0xBA5F:o + 0xBA62] = jmp(L['storyptr'])
    assert rom[o + 0xB827:o + 0xB829] == b'\xa9\x04'
    rom[o + 0xB827:o + 0xB835] = jsr(L['setbox']) + b'\xEA' * 11
    assert rom[o + 0xB899:o + 0xB89B] == b'\xa9\x00'
    rom[o + 0xB899:o + 0xB89C] = jmp(L['scene'])
    # nametable 1 attributes (written by scene from $BA7F): the same box columns
    for g in range(1, 4):
        k = o + 0xBA7F + 8 * g
        assert rom[k:k + 8] == bytes([0x55, 0, 0, 0, 0, 0x44, 0x55, 0x55])
        rom[k] = 0x11; rom[k + 5] = 0x00

def prologue(rom):
    """Opening text (bank 13 $BF20, drawn by bank 14 $A142 from column 1 row 9; seven
    lines of two tile rows (dakuten + kana) in rows 9-22, faded in top to bottom by
    attribute bands of two rows from row 8). Each Japanese line becomes one or two centred
    English lines of 30 followed by a blank row (rows 4+3k..6+3k), so the block keeps the
    Japanese spacing; the fade starts at row 4 and also fades rows 22-23 (the Japanese
    showed its last band at once). String in BATTLE_BANK."""
    e = json.load(open('script/ff1/prologue.json'))[0]
    out = []
    for line in e['en'].split('\n'):
        if len(line) <= 30: ls = [line, '']
        else:                                    # two balanced halves
            w = line.split(' ')
            ls = min(([' '.join(w[:k]), ' '.join(w[k:])] for k in range(1, len(w))),
                     key=lambda p: max(len(p[0]), len(p[1])))
            assert max(len(l) for l in ls) <= 30, ls
        out += [' ' * ((30 - len(l)) // 2) + l if l else '' for l in ls] + ['']
    assert len(out) == 21
    bank = Bank(rom, BATTLE_BANK, keep=True); bank.free = BATTLE_FREE[:]
    a = bank.alloc(enc('{09}' + '{08}'.join(out)) + b'\0')
    BATTLE_FREE[:] = bank.free
    o = HDR + 14 * BANK - 0x8000
    assert rom[o + 0xA142:o + 0xA150] == bytes.fromhex('a920853ea9bf853fa9008537a90d')
    rom[o + 0xA143] = a & 0xFF; rom[o + 0xA147] = a >> 8; rom[o + 0xA14F] = BATTLE_BANK
    assert rom[o + 0xA157] == 9; rom[o + 0xA157] = 4              # first text row 4
    assert rom[o + 0xA288] == 0xD0; rom[o + 0xA288] = 0xC8        # fade from row 4
    assert rom[o + 0xA2A9] == 0xE8; rom[o + 0xA2A9] = 0xF8        # fade the last band too

NAME_GRID = ['ABCDEFGHIJ', 'KLMNOPQRST', "UVWXYZ'.,-", 'abcdefghij', 'klmnopqrst',
             'uvwxyz!?&\u2026', '0123456789', '():;/+%"[]', '          ']
def name_grid(rom):
    """Name entry grid (bank 14 $A013: 9 rows of 10 cells, 'char sep' pairs, sep FF or
    01 at a row end; the chosen character is read back from the same string). Latin
    letters, digits and punctuation in the same layout; the last row is spaces (the
    Japanese grid ends with one space cell)."""
    data = bytearray()
    for r, row in enumerate(NAME_GRID):
        assert len(row) == 10
        for c, ch in enumerate(row):
            data += enc(ch) + (b'\x01' if c == 9 and r < 8 else b'\x00' if c == 9 else b'\xFF')
    o = HDR + 14 * BANK + 0xA013 - 0x8000
    assert len(data) == 180 and rom[o] == 0x8A and rom[o + 179] == 0
    rom[o:o + 180] = data

def class_select(rom):
    """New-game class boxes (bank 14 $9ECB: the class name is drawn from a string built at
    $5E = 02 F0+class, in an 8-wide box). 'Red Magician' etc. need the two-row form of the
    name ({0A}: pre-wrapped name table), so the string comes from a table of six in
    BATTLE_BANK instead."""
    bank = Bank(rom, BATTLE_BANK, keep=True); bank.free = BATTLE_FREE[:]
    # clear both rows of the 8 cells first (the Japanese names were padded to clear the
    # previous one): 05 07 = save the column, both rows; 06 = back, lower row
    base = bank.alloc(b''.join(bytes([0x05, 0x07] + [0xFF] * 8 + [0x06, 0x0A, WRAP_WIDTH, 0x02, 0xF0 + c, 0])
                               for c in range(6)))
    BATTLE_FREE[:] = bank.free
    code = asm('''
    org $9ED6
    lda $0300,x
    asl a
    asl a
    asl a
    asl a
    clc
    adc #<BASE
    sta $3E
    lda #>BASE
    adc #0
    sta $3F
    lda #BB
    sta $57
    lda #$0E
    sta $58
''', syms={'BASE': base, 'BB': BATTLE_BANK})
    o = HDR + 14 * BANK - 0x8000
    assert rom[o + 0x9ED6:o + 0x9EDC] == bytes.fromhex('bd0003186 9f0'.replace(' ', '')) and rom[o + 0x9EF0] == 0x8A
    n = len(code.bytes); assert n <= 0x9EF0 - 0x9ED6, n
    rom[o + 0x9ED6:o + 0x9EF0] = code.bytes + b'\xEA' * (0x9EF0 - 0x9ED6 - n)

TITLE_MENU = [' Continue', 'Start Over', ' Message Speed']
def title_menu(rom):
    """Title menu (bank 14 $A16F): three boxes, (11,10) and (11,15) 10 wide, (8,20) 16 wide
    with the speed digit at $22D5; cursor at x=$48 left of the boxes, on the first two
    only. English: boxes 1-2 at x=10 width 12 ('Start Over'), box 3 at x=6 width 20
    ('Message Speed', a space, the digit at column 23), all on the original centre; the
    cursor 8 pixels further left. The strings (25 bytes in the Japanese, followed by the
    cursor table) go to free fixed-bank space, readable whatever bank is mapped."""
    data = [enc(t) + b'\0' for t in TITLE_MENU]
    at = 0xF8B0
    o = HDR + 14 * BANK - 0x8000
    for k, (lo, hi) in enumerate(((0xA18C, 0xA190), (0xA1A2, 0xA1A6), (0xA1BC, 0xA1C0))):
        assert rom[o + lo - 1] == 0xA9 and rom[o + hi - 1] == 0xA9 and rom[o + hi] == 0xA2
        rom[o + lo] = at & 0xFF; rom[o + hi] = at >> 8
        put(rom, at, data[k]); at += len(data[k])
    assert at <= 0xF919
    for a, old, new in ((0xA179, 0x0B, 10), (0xA185, 0x0A, 12), (0xA1B1, 0x08, 6), (0xA1B5, 0x10, 20),
                        (0xA1D4, 0x48, 0x40), (0xA257, 0xD5, 0xD7)):
        assert rom[o + a] == old, hex(a); rom[o + a] = new

def battle(rom, labels, report):
    """Battle text. Messages (table $8F4E+2) and monster names (table $94E0) move to
    BATTLE_BANK at the same addresses; names may be longer than 8 letters; enemy attack
    names (bank 10, table $B600) in English; the decoder copies up to 64 bytes (ExRAM
    $5F80 instead of 32 at $6D54); each line is fitted to its box by boxline."""
    bank = Bank(rom, BATTLE_BANK)
    bank.free = [(0x8000, 0x8F4E), (0x8FF0, 0x94E0), (0x95E0, 0xC000)]
    # status words in the 4-column HP windows: drawn as narrow-letter tiles $D3-$EA
    labels4 = {}
    for k, (mid, word) in enumerate(STATUS_LABELS):
        codes = bytes(range(0xD3 + 4 * k, 0xD7 + 4 * k))
        for t, data in enumerate(narrow_label(word, 4, fg=3, bg=2)):
            o = HDR + 0x24000 + codes[t] * 16
            rom[o:o + 16] = data
        labels4[mid] = codes
    for e in json.load(open('script/ff1/battle_msgs.json')):
        if e['id'] in labels4: data = labels4[e['id']]
        else:
            data = enc(e['en'])
            jlen = len(e['ja'])                    # the Japanese pads with spaces to clear
            if len(data) < jlen: data += b'\xFF' * (jlen - len(data))
        bank.put_ptr(0x8F50 + 2 * e['id'], bank.alloc(data + b'\0'))
    for e in json.load(open('script/ff1/monsters.json')):
        if e['en'] in NARROW_NAMES and '--gb' not in sys.argv:   # one word wider than any name box (GB: small font)
            n, base = NARROW_NAMES[e['en']]
            for t, data in enumerate(narrow_label(e['en'], n, fg=3, bg=2)):
                o = HDR + 0x24000 + (base + t) * 16
                rom[o:o + 16] = data
            data = bytes(range(base, base + n))
        else: data = enc(e['en'])
        bank.put_ptr(0x94E0 + 2 * e['id'], bank.alloc(data + b'\0'))
    # battle boxes (type x y w h, text 01 x y): attacker/action and target/result pairs
    # 10 columns each inside (were 8 + 10 / 8 + 9); enemy list 10 (was 9); the command
    # window starts one column further right (its text keeps column 14)
    put(rom, 0xF9E1, bytes([0, 1, 1, 12, 4, 1, 2, 2,   0, 13, 1, 12, 4, 1, 14, 2,
                            0, 1, 4, 12, 4, 1, 2, 5,   0, 13, 4, 12, 4, 1, 14, 5]))
    put(rom, 0xF9DC, bytes([0, 1, 0, 12, 10]))
    put(rom, 0xFA13, bytes([0, 13, 0, 12, 10]))
    drink_window(rom)
    # strings the battle code passes by pointer into ROM (bank 11 table $A00E, bank 12
    # $A048): the decoder could read them with any bank mapped (the Japanese kept them in
    # the message bank). Copies go to BATTLE_BANK, and a stub before the decoder maps
    # BATTLE_BANK whenever a line's pointer is in $8000-$BFFF.
    b11 = HDR + 11 * BANK - 0x8000
    for k in range(10):
        t = 0xA00E + 2 * k
        a = rom[b11 + t] | rom[b11 + t + 1] << 8
        e = rom.index(0, b11 + a)
        data = bytes(rom[b11 + a:e])
        data = DIRECT_STRINGS.get(data, data)
        n = bank.alloc(data + b'\0')
        rom[b11 + t] = n & 0xFF; rom[b11 + t + 1] = n >> 8
    n = bank.alloc(enc('Cannot be used!') + b'\0')         # つかえません !
    o = HDR + 12 * BANK + 0x96FE - 0x8000
    assert rom[o:o + 6] == bytes([0xA9, 4, 0xA2, 0x48, 0xA0, 0xA0])
    rom[o + 3] = n & 0xFF; rom[o + 5] = n >> 8
    stub = asm('''
    org $F8A0       ; (free: the item list builder moved to far code)
    cpy #$80
    bcc .go
    cpy #$C0
    bcs .go
    lda #%d
    jsr $FE03
.go:
    jmp $FA4F
''' % BATTLE_BANK)
    put(rom, stub.org, stub.bytes)
    o = HDR + 15 * BANK + 0xF9B6 - 0xC000
    assert rom[o:o + 3] == b'\x20\x4f\xfa'
    put(rom, 0xF9B6, jsr(stub.org))
    b10 = Bank(rom, 10, keep=True); b10.free = NAMES_FREE[:]
    for e in json.load(open('script/ff1/enemy_attacks.json')):
        b10.put_ptr(0xB600 + 2 * e['id'], b10.alloc(enc(e['en']) + b'\0'))
    for a, old, new in ((0xFC1C, 0x0B, BATTLE_BANK), (0xFC71, 0x0B, BATTLE_BANK), (0xFC83, 0x08, 0x20),
                        (0xFA60, 0x54, 0x80), (0xFA61, 0x6D, 0x5F), (0xFA64, 0x20, 0x40),
                        (0xFA68, 0x54, 0x80), (0xFA6C, 0x6D, 0x5F)):
        for bk in (15, 31):
            o = HDR + bk * BANK + a - 0xC000
            assert rom[o] == old, (hex(a), rom[o]); rom[o] = new
    put(rom, 0xF9B9, farhook('boxline'))
    assert max(labels.values()) < 0x5F80, hex(max(labels.values()))
    # battle magic list: 2 levels per page, 4 pages
    put(rom, 0xF75C, bytes([0xA2, FAR_ROUTINES.index('magpage')]) + jsr(labels['farjsr']) + jmp(0xF640))
    for a, r in ((0x9CB4, 'magdown'), (0x9CD2, 'magup')):
        bank_put(rom, 12, a, bytes([0xA2, FAR_ROUTINES.index(r)]) + jsr(labels['farjsr'])
                 + jmp(labels['magflip']))
    bank_put(rom, 12, 0x9CF0, b'\x60')                 # left/right: no move
    bank_put(rom, 12, 0x9CFE, b'\x60')
    for a, old, new in ((0x9C36, 3, 1), (0x9C81, 3, 1), (0x951C, 1, 3), (0x951E, 0x0A, 0xEA)):
        o = HDR + 12 * BANK + a - 0x8000
        assert rom[o] == old, hex(a); rom[o] = new
    cur = bytearray(32)
    for c in range(3):
        for r in range(2):
            k = r + 4 * c
            cur[2 * k] = 40; cur[2 * k + 1] = (158 if r == 0 else 190) + 8 * c
    bank_put(rom, 12, 0x9FBF, bytes(cur[:24]))
    # battle Item list: one column of 8 rows (cursor table: column*8 + row*2 -> x, y)
    put(rom, 0xF896, bytes([0xA2, FAR_ROUTINES.index('itemlist')]) + jsr(labels['farjsr']) + jmp(0xF640))
    bank_put(rom, 12, 0x9D8C, bytes([0xA2, FAR_ROUTINES.index('itemmove')]) + jmp(labels['farjsr']))
    o = HDR + 12 * BANK + 0x9FD7 - 0x8000
    assert rom[o:o + 2] == b'\x10\xa6'
    rom[o:o + 16] = bytes(v for r in range(8) for v in (0x10, 0x9E + 8 * r))
    BATTLE_FREE[:] = bank.free
    report.append('battle bank free: %d' % sum(b - a for a, b in bank.free))

NAMES_FREE = []
BATTLE_FREE = []
DLG_LABEL = [0]
FAR_LABELS = {}

def farhook(name):
    return bytes([0xA2, FAR_ROUTINES.index(name)]) + jmp(LABELS_EX['farjsr'])
LABELS_EX = {}

def status_screen(rom):
    """Status windows (x, y, w, h), table at bank 14 $B53A, drawn in this order with
    strings 35-40: name; class (wide enough for 'White Magician'); the old level window
    now coincides with the experience window, which shows Level/Experience/Next in three
    one-row lines; attribute and battle windows wider for the English labels."""
    t = [0, 3, 6, 5,   6, 3, 26, 5,   2, 8, 28, 7,   2, 8, 28, 7,   0, 15, 17, 13,   17, 15, 15, 13]
    bank_put(rom, 14, 0xB53A, bytes(t))

if __name__ == '__main__':
    rom = bytearray(open(sys.argv[1], 'rb').read())
    report = []
    font(rom)
    labels = menu_engine(rom, report)
    main_menu(rom, labels)
    insert_names(rom, report)
    insert_menu_strings(rom, report)
    item_screen(rom)
    equip_screens(rom, labels)
    status_screen(rom)
    shops(rom, labels)
    battle(rom, labels, report)
    story(rom, report)
    prologue(rom)
    name_grid(rom)
    class_select(rom)
    title_menu(rom)
    bad = insert_dialogue(rom, report)
    if '--gb' in sys.argv:                     # Game Boy layout variant (tools/ff1/gb_layout.py)
        sys.path.insert(0, os.path.dirname(__file__))
        import gb_layout
        gb_layout.apply(rom, report)
    open(sys.argv[2], 'wb').write(rom)
    if '--gb' in sys.argv:                     # far-code entry points (farjsr's RTS dispatch) for
        with open(sys.argv[2] + '.far', 'w') as fh:     # the recompiler (tools/gb/build.py)
            fh.write(''.join('%04X %s\n' % (FAR_LABELS[r], r) for r in FAR_ROUTINES))
    print('\n'.join(report)); print('strings not fitting:', bad)
