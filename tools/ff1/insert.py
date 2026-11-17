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
#   0C skip one column without drawing      0D nn  go to column nn of the row
#   0E/0F third row of a wrapped name (upper row of the next line) / back
#   0A nn  inserted item names use the pre-wrapped table (bank 10 $B400, built for
#          WRAP_WIDTH columns): split at spaces or marked hyphen points onto the upper
#          and lower rows of the line and, if needed, the upper row of the next line.
# Helper code and variables live in MMC5 ExRAM ($5C00, mode 2), copied at reset from the
# first 1KB of CODE_BANK.
CODE_BANK = 18                        # 16KB bank: ExRAM image + menu strings
EX = dict(MODE=0x5C00, PREV=0x5C01, SAVEX=0x5C02, WRAPW=0x5C03, TMP=0x5C04, BUF=0x5C10,
          SLOT=0x5C40, SV54=0x5C05, SV55=0x5C06, MENUBANK=CODE_BANK)
EXRAM_SRC = '''
    org $5C60
BCMDS
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
    cmds = json.load(open('script/ff1/battle_cmds.json'))
    bc = ''.join('bcmd%d:\n    .db %s, 0\n' % (e['id'], ', '.join(str(b) for b in enc(e['en']))) for e in cmds)
    ex = asm(EXRAM_SRC.replace('BCMDS', bc), syms=EX)
    img = bytearray(0x400); img[0x60:0x60 + len(ex.bytes)] = ex.bytes
    assert 0x60 + len(ex.bytes) <= 0x400
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
        put(rom, 0xFA1B + 5 * e['id'] + 3, bytes([a & 0xFF, a >> 8]))

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
    bad = insert_dialogue(rom, report)
    open(sys.argv[2], 'wb').write(rom)
    print('\n'.join(report)); print('strings not fitting:', bad)
