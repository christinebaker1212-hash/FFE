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
import sys, os, json
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
from latin_font import tile
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

def font(rom):
    for ch in NEW_GLYPHS:
        o = HDR + 0x24000 + ENC[ch] * 16
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
    dia = json.load(open('script/ff1/dialogue.json'))
    items = json.load(open('script/ff1/items.json'))
    global ITEM_MAX; ITEM_MAX = max(len(e['en']) for e in items)
    bad = 0
    for half, bank_no in ((0, 16), (1, 17)):
        bank = Bank(rom, bank_no)
        for e in items:                   # {02} item-name table at $B700 (same layout as original)
            bank.put_ptr(0xB700 + 2 * e['id'], bank.alloc(enc(e['en'] or ' ') + b'\0'))
        for e in dia[half * 128:(half + 1) * 128]:
            lines = wrap(e['en'])
            if len(lines) > H or max(vlen(l) for l in lines) > W:
                bad += 1; report.append('DOES NOT FIT dialogue %d (%d lines)' % (e['id'], len(lines)))
            bank.put_ptr(0x8000 + 2 * e['id'], bank.alloc(enc('\n'.join(lines)) + b'\0'))
        report.append('bank %d free: %s' % (bank_no, [b - a for a, b in bank.free]))
    # $DB58: pick bank 16/17 from the id (trampoline in the free bytes at $F41E)
    put(rom, 0xDB58, bytes([0x4C, 0x1E, 0xF4]))
    put(rom, 0xF41E, bytes([0xAA, 0x0A, 0xA9, 0x10, 0x69, 0x00,   # TAX / ASL / LDA #16 / ADC #0
                            0x85, 0x57, 0x20, 0x03, 0xFE,         # STA $57 / JSR $FE03 (switch)
                            0x4C, 0x60, 0xDB]))                   # JMP $DB60
    put(rom, 0xDC81, bytes([0x69, 0x01]))     # newline: 1 tile row (was 2)
    put(rom, 0xD52E, bytes([0x69, 0x03]))     # first line one row higher (was row 4)
    return bad

# ---------------------------------------------------------------------------------
# Menu engine. The menu text drawer ($DEB6/$DECE) writes every character as a vertical
# pair (dakuten row above, character below). English needs no dakuten row, so new
# control codes (05-0B, unused in the original) let a menu use it:
#   05 upper row only (remembers the column)   06 back to that column, lower row only
#   07 previous mode    08 newline of ONE tile row    09 lower row only    0B normal
#   0A nn  wrap width: an item name inserted afterwards that is longer than nn is split
#          at a space onto the upper and lower row of its cell (two-line names).
# Helper code and variables live in MMC5 ExRAM ($5C00, mode 2), copied at reset from the
# first 1KB of CODE_BANK.
CODE_BANK = 18                        # 16KB bank: ExRAM image + menu strings
EX = dict(MODE=0x5C00, PREV=0x5C01, SAVEX=0x5C02, WRAPW=0x5C03, TMP=0x5C04, BUF=0x5C10,
          MENUBANK=CODE_BANK)
EXRAM_SRC = '''
    org $5C40
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
    cmp #5
    beq .c5
    cmp #6
    beq .c6
    cmp #7
    beq .c7
    cmp #8
    beq .c8
    cmp #9
    beq .c9
    cmp #$0A
    beq .ca
    cmp #$0B
    beq .cb
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
h_name:         ; $E0A3: draw item name at ($3E) (bank 10), wrapping onto two rows
    lda WRAPW
    beq .plain
    ldy #0
.len:
    lda ($3E),y
    beq .gl
    iny
    bne .len
.gl:
    cpy WRAPW
    bcc .plain
    beq .plain
    ldy WRAPW
.find:
    lda ($3E),y
    cmp #$FF
    beq .split
    dey
    bne .find
    beq .plain
.split:
    sty TMP
    ldx #0
    lda #5
    sta BUF,x
    inx
    ldy #0
.p1:
    cpy TMP
    beq .p1e
    lda ($3E),y
    sta BUF,x
    inx
    iny
    bne .p1
.p1e:
    lda #6
    sta BUF,x
    inx
    iny
.p2:
    lda ($3E),y
    beq .p2e
    sta BUF,x
    inx
    iny
    bne .p2
.p2e:
    sta BUF,x
    lda #<BUF
    sta $3E
    lda #>BUF
    sta $3F
.plain:
    jmp $DECE
m_setbank:      ; bank 14 $B957: menu strings are read from MENUBANK
    lda #$0E
    sta $58
    lda #MENUBANK
    sta $57
    rts
m_copy:         ; bank 14 $B96C: copy menu string A to $6C00 (code 10 -> 10|$66)
    asl a
    tax
    lda $8500,x
    sta $10
    lda $8501,x
    sta $11
    lda #MENUBANK
    sta $57
    jsr $FE03
    ldy #$7F
.l:
    lda ($10),y
    cmp #$10
    bne .s
    ora $66
.s:
    sta $6C00,y
    dey
    bpl .l
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
init:           ; replaces the MMC5 init chunk at $FDF0 (called once from reset)
    lda #1
    sta $5100
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

def jmp(a): return bytes([0x4C, a & 0xFF, a >> 8])
def jsr(a): return bytes([0x20, a & 0xFF, a >> 8])

def bank_put(rom, bank, cpu, data):
    o = HDR + bank * BANK + cpu - 0x8000
    rom[o:o + len(data)] = data

def menu_engine(rom, report):
    ex = asm(EXRAM_SRC, syms=EX)
    img = bytearray(0x400); img[0x40:0x40 + len(ex.bytes)] = ex.bytes
    assert 0x40 + len(ex.bytes) <= 0x400
    bank_put(rom, CODE_BANK, 0x8000, bytes(img))
    L = ex.labels
    init = asm(INIT_SRC, syms={'CODE2': CODE_BANK * 2})
    assert init.org + len(init.bytes) <= 0xDDAB      # dakuten tables $DD47-$DDAA (unused in English)
    put(rom, init.org, init.bytes)
    put(rom, 0xFDF0, jmp(init.labels['init']))
    put(rom, 0xDEB6, jmp(L['h_entry']) + b'\xEA\xEA')
    put(rom, 0xDEB1, jmp(L['h_end']) + b'\xEA\xEA')
    put(rom, 0xDEDE, jmp(L['h_char']) + jmp(L['h_code']))   # $DEE1: JMP h_code
    put(rom, 0xDF4D, bytes([0x90, (0xDEE1 - 0xDF4F) & 0xFF]))  # BCC $DEE1 (codes 05-0F)
    put(rom, 0xE0A3, jsr(L['h_name']))
    bank_put(rom, 14, 0xB957, jsr(L['m_setbank']) + b'\xEA\xEA\xEA')
    bank_put(rom, 14, 0xB96C, jmp(L['m_copy']))
    report.append('ExRAM code: %d bytes' % len(ex.bytes))

def insert_names(rom, report):
    """English item/weapon/armor/magic/class names: bank 10, table $B700 (as before),
    strings in the space the Japanese dialogue left ($8000-$B5FF)."""
    items = json.load(open('script/ff1/items.json'))
    bank = Bank(rom, 10, keep=True)
    bank.free = [(0x8000, 0xB600)]
    for e in items:
        bank.put_ptr(0xB700 + 2 * e['id'], bank.alloc(enc(e['en']) + b'\0'))
    report.append('bank 10 names free: %d' % sum(b - a for a, b in bank.free))

def insert_menu_strings(rom, report):
    menu = json.load(open('script/ff1/menu.json'))
    bank = Bank(rom, CODE_BANK, keep=True)
    bank.free = [(0x8400, 0xC000)]
    for e in menu:
        o = HDR + 14 * BANK + 0x0500 + 2 * e['id']
        a = bank.alloc(enc(MENU_OVERRIDE.get(e['id'], e['en'])) + b'\0')
        rom[o] = a & 0xFF; rom[o + 1] = a >> 8

MENU_OVERRIDE = {}

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

if __name__ == '__main__':
    rom = bytearray(open(sys.argv[1], 'rb').read())
    report = []
    font(rom)
    menu_engine(rom, report)
    insert_names(rom, report)
    insert_menu_strings(rom, report)
    item_screen(rom)
    bad = insert_dialogue(rom, report)
    open(sys.argv[2], 'wb').write(rom)
    print('\n'.join(report)); print('strings not fitting:', bad)
