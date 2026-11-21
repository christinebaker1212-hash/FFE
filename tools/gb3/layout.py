"""FF3 GBC screen layouts on the NES side (after tools/ff3/insert.py), as FF1 / FF2 do: the game
code itself draws its screens for a 160x144 view, so the GB build can still be checked frame
by frame against this "GB-layout" NES ROM.

usage: layout.py EN.nes OUT.nes        (EN.nes = the English build, build/ff3_en.nes)

Patches are matched by their original bytes (a wrong address stops the build). Owner's
decisions: docs/ff3-gb-plan.md section 6.

Battle (decision 3, with FF1 / FF2's battle rules):
- cameras (GB runtime registers, open bus on the NES): battlefield camera NES x 20 / y 48
  and window camera col 2 / row 7, split at GB line 96 (GB runtime, $5806 = 1); field camera
  back after the battle ($5806 = 0)
- party column GB x 140-159: front row NES x 160, back row 164; members 24 px apart from NES
  y 47 (GB rows 0-11, every sprite whole); acting members step 8 px (back row 12)
- battle windows from NES row 19 as FF3 (GB row 12; the window camera is col 2 / row 7: NES
  row 18 belongs to the enemy animations and is not shown), 6 rows high, one tile row per
  text line (the English text has no dakuten row): 4 text rows; party window cols 2-21 (GB
  0-19), command and enemy-name windows cols 2-11 (GB 0-9); battle messages in one
  full-width window (see MSG_SRC)
"""
import os, sys, re
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..'))
sys.path.insert(0, HERE)
from asm6502 import asm
B8 = 0x2000
FONT = 0x1B000                          # English font: tile N = code N (PRG offset)
ARROW = 0xCA                            # unused code (Japanese katakana A): the message arrow
ARROW_ROWS = ['........', '..#.....', '..##....', '#####...', '..##....', '..#.....', '........',
              '........']

# battle message window (bank 52, in place of FF3's open / close message window routines
# $8D1B-$8E82 and their box table $8E83-$8EAF): one full-width window, NES rows 19-24 cols
# 2-21 (GB rows 12-17), 4 lines of 18 columns. The first window opened saves the area and
# draws an empty frame (a row per frame); each message then takes the next free line(s),
# word-wrapped (a message needing more lines than are free covers the last ones); the target
# goes on the attacker's line after an arrow when it fits. Closing a window blanks its cells;
# closing the last one restores the area. State in the English box save buffer (ExRAM $5E90,
# free: FF3's boxes saved there).
MSG_SRC = '''
MCNT  = $5E90       ; windows open
MUSED = $5E91       ; lines in use (0-4)
MALEN = $5E92       ; attacker's length on line 0 (0: none)
MFIRST = $5E93      ; per window id (5): first line,
MNUM  = $5E98       ;   number of lines,
MCOL  = $5E9D       ;   first column
NW    = $5F2C       ; enemy-names window: text width (8-18)
MLINE = $5EA2       ; line image (18)
MSAVE = $5EB4       ; the area under the window (6 x 20)
WAIT1 = $8185       ; wait one frame
PPUREG = $8D03      ; ppu control / mask / scroll again
SETADR = $F8E0      ; ppu address A (high) X (low)
    org $8D1B
msgopen:            ; A = window id: 0 attacker, 1 action, 2 target, 3 status, 4 message
    sta $1E
    lda MCNT
    bne .o1
    sta MUSED
    sta MALEN
    sta $1F
    sta $1D
.f:
    jsr WAIT1
    jsr maddr
    lda $2007
    ldx #20
    ldy $1D
.r:
    lda $2007
    sta MSAVE,y
    iny
    dex
    bne .r
    sty $1D
    jsr maddr
    ldy $1F
    lda FL,y
    sta $2007
    lda FM,y
    ldx #18
.m:
    sta $2007
    dex
    bne .m
    lda FR,y
    sta $2007
    jsr PPUREG
    inc $1F
    lda $1F
    cmp #6
    bne .f
.o1:
    inc MCNT
    ldx $1E
    lda #0
    sta MCOL,x
    cpx #2
    bne .nl
    ldy #0              ; target: the arrow in front
    lda #ARROW
.i:
    ldx $7AD7,y
    sta $7AD7,y
    iny
    txa
    bne .i
    sta $7AD7,y
    lda MALEN           ; on the attacker's line when it fits
    beq .nl
    jsr mlen
    sec
    adc MALEN
    cmp #19
    bcs .nl
    jsr mclr
    ldy MALEN
    iny
    ldx #0
.a:
    lda $7AD7,x
    beq .ad
    sta MLINE,y
    inx
    iny
    bne .a
.ad:
    lda MALEN
    sta $1D
    sta MCOL+2
    lda #0
    sta $1F
    sta MFIRST+2
    lda #1
    sta MNUM+2
    jmp mput
.nl:
    lda #0              ; lines needed
    sta $1B
    sta $19
.cn:
    jsr mline
    inc $19
    ldx $1B
    lda $7AD7,x
    bne .cn
    lda $19
    cmp #5
    bcc .c4
    lda #4
    sta $19
.c4:
    clc
    adc MUSED
    cmp #5
    lda MUSED
    bcc .st
    lda #4
    sec
    sbc $19
.st:
    sta $1F
    ldx $1E
    sta MFIRST,x
    lda $19
    sta MNUM,x
    clc
    adc $1F
    sta MUSED
    cpx #0              ; the attacker alone on line 0: its length
    bne .dr
    lda $1F
    ora #0
    bne .dr
    jsr mlen
    sta MALEN
.dr:
    lda #0
    sta $1B
    sta $1D
.dl:
    jsr mline
    jsr mput
    inc $1F
    dec $19
    bne .dl
    rts

msgclose:           ; A = window id
    tax
    dec MCNT
    beq .rs
    lda MNUM,x
    sta $19
    lda MFIRST,x
    sta $1F
    lda MCOL,x
    sta $1D
    bne .bl
    lda $1F
    clc
    adc $19
    cmp MUSED
    bne .bl
    lda $1F
    sta MUSED
.bl:
    jsr mclr
.b2:
    jsr mput
    inc $1F
    dec $19
    bne .b2
    rts
.rs:
    lda #0              ; the last one: the area back
    sta $1F
    sta $1D
.r:
    jsr WAIT1
    jsr maddr
    ldx #20
    ldy $1D
.rl:
    lda MSAVE,y
    sta $2007
    iny
    dex
    bne .rl
    sty $1D
    jsr PPUREG
    inc $1F
    lda $1F
    cmp #6
    bne .r
    rts


tgtnames:           ; choose targets (battle graphics $10) with the enemy-names window shown
    jsr $9D9E       ;   over the command window (owner: names while targeting; FF3 redraws
    lda #$10        ;   the command window after the command or a cancel)
    jmp $FA0E
nload:              ; monster name of type X -> $7AD7
    lda #$40
    sta $18
    lda #$8A
    sta $19
    lda $7D6B,x
    ldx #0
    jmp $A609
nadv:               ; text buffer offset + one row of the names window
    lda NW
    jmp $A558
'''
MSG_END = 0x8EB0

# enemy-names window (FF3 $9D9E "update monster names", bank 52), one name per row and as wide
# as the longest name shown (8-18 columns; a longer name takes two rows): pass 1 in place of
# FF3's routine, pass 2 in the NOP space after the English text converter ($9716-$9753)
NAMES1_SRC = '''
NW = $5F2C
    org $9D9E
gbnames:
    jsr $9754       ; init text buffer
    lda #8
    sta NW
    ldx #3
.l1:
    lda $7DCE,x     ; monsters of type X left
    beq .n1
    stx $24
    jsr nload
    jsr mlen
    ldx $24
    cmp #19
    bcc .c
    lda #18
.c:
    cmp NW
    bcc .n1
    sta NW
.n1:
    dex
    bpl .l1
    lda #0
    sta $24
    jmp names2
winh:               ; menu window height (FF3 $8BC3: 4 rows on the GB): $1A bit 7 = a list
    lda $1A         ;   window, 8 rows (the item / magic lists), and the GB's tall list camera
    and #$80        ;   ($5807; open bus on the NES)
    sta $5807
    asl a
    lda #4
    bcc .h
    asl a
.h:
    sta $30
    rts
'''
NAMES2_SRC = '''
NW = $5F2C
    org $9716
names2:
.l2:
    ldx $24
    lda $7DCE,x
    beq .n2
    jsr nload
    jsr mlen
    cmp NW
    beq .s
    bcc .s
    jsr nadv        ; (two rows: the first part goes on the row above)
.s:
    lda NW
    sta $18
    jsr bconvb
    jsr nadv
.n2:
    inc $24
    lda $24
    cmp #4
    bne .l2
    lda #2          ; window cols 2 .. 3 + NW
    sta $18
    lda NW          ; (carry set by CMP #4)
    adc #2
    sta $19
    lda #3
    sta $1A
    jmp $8B38       ; open menu window
'''
MSGX_SRC = '''
MLINE = $5EA2
WAIT1 = $8185
PPUREG = $8D03
SETADR = $F8E0
    org $5F30           ; (ExRAM, after MSAVE: the window's helpers)
maddr:              ; ppu address of window row $1F, column 0 ($2262 + 32 row)
    lda $1F
    asl a
    asl a
    asl a
    asl a
    asl a
    clc
    adc #$62
    tax
    lda #$22
    adc #0
    jmp SETADR

mput:               ; MLINE from column $1D on to text line $1F (0-3), in a frame
    jsr WAIT1
    lda $1F
    asl a
    asl a
    asl a
    asl a
    asl a
    clc
    adc #$83
    adc $1D
    tax
    lda #$22
    adc #0
    jsr SETADR
    ldy $1D
.p:
    lda MLINE,y
    sta $2007
    iny
    cpy #18
    bne .p
    jmp PPUREG

mclr:
    ldy #17
    lda #$FF
.c:
    sta MLINE,y
    dey
    bpl .c
    rts

mlen:               ; A = length of the text at $7AD7
    ldx #0
.l:
    lda $7AD7,x
    beq .e
    inx
    bne .l
.e:
    txa
    rts

mline:              ; MLINE = the next line of the text from $7AD7 + $1B (words; a word
    jsr mclr        ;   longer than the line is cut)
    ldy #0
    ldx $1B
.sk:
    lda $7AD7,x
    cmp #$FF
    bne .w
    inx
    bne .sk
.w:
    lda $7AD7,x
    beq .x
    stx $1A
    lda #0
    sta $1C
.wl:
    lda $7AD7,x
    beq .we
    cmp #$FF
    beq .we
    inx
    inc $1C
    bne .wl
.we:
    tya
    clc
    adc $1C
    cmp #19
    bcc .put
    cpy #0
    bne .br
    lda #18
    sta $1C
.put:
    ldx $1A
.pc:
    lda $7AD7,x
    sta MLINE,y
    inx
    iny
    dec $1C
    bne .pc
    lda $7AD7,x
    beq .x
    cmp #$FF
    bne .x
    inx
    iny
    cpy #18
    bcc .w
    bcs .x
.br:
    ldx $1A
.x:
    stx $1B
    rts

FL: .db $F7, $FA, $FA, $FA, $FA, $FC
FM: .db $F8, $FF, $FF, $FF, $FF, $FD
FR: .db $F9, $FB, $FB, $FB, $FB, $FE
'''
MSGX_END = 0x6000


EXRAM = 128                             # ff3src / ff3en index of the ExRAM image


class Rom:
    def module(self, src, syms=None):
        """assemble a code module, as tools/gb3/ff3en.py records insert.py's: org, bytes,
        labels, insns (instruction starts)"""
        import ff3en
        m = asm(src, syms=syms)
        msrc, n = ff3en.marked(src)
        m2 = asm(msrc, syms=syms)
        assert m2.bytes == m.bytes
        insns = sorted(v for k, v in m2.labels.items() if re.search(r'\.__i\d+$', k))
        assert len(insns) == n
        labels = {k: v for k, v in m.labels.items() if syms is None or k not in syms}
        return dict(org=m.org, bytes=bytes(m.bytes), labels=labels, insns=insns)

    def __init__(self, data):
        self.d = bytearray(data); self.log = []; self.mods = []

    def off(self, bank, addr):
        return 16 + bank * B8 + (addr & 0x1FFF)

    def patch(self, bank, addr, old, new, why):
        """bytes at CPU addr in 8 KB bank: old (hex) -> new (hex)"""
        old = bytes.fromhex(old.replace(' ', '')); new = bytes.fromhex(new.replace(' ', ''))
        o = self.off(bank, addr)
        if self.d[o:o + len(old)] != old:
            raise SystemExit('layout: %02X:%04X is %s, expected %s (%s)' % (
                bank, addr, self.d[o:o + len(old)].hex(), old.hex(), why))
        self.d[o:o + len(new)] = new
        self.log.append((bank, addr, why))


TRAMP_SRC = '''
    org $5E7F
gbbon:              ; battle start: the GB's battle cameras
    lda #1
    bne gbcam
gbboff:             ; battle end: the field camera
    lda #0
gbcam:
    sta $5806       ; (GB runtime: camera set; open bus on the NES)
    jmp $FA1D       ; reset ppu control (the call this replaces)
'''


def battle(r):
    B2F, B34, B7F, B40 = 0x2F, 0x34, 0x7F, 0x40
    # cameras: two trampolines in the ExRAM image's free bytes ($5E7F-$5E8F; the English
    # engine's box save buffer starts at $5E90), called instead of "reset ppu control"
    # ($FA1D) at the start and the end of a battle ($FA26)
    t = r.module(TRAMP_SRC)
    assert t['org'] + len(t['bytes']) <= 0x5E90
    r.patch(B40, 0x827F, 'FF' * len(t['bytes']), t['bytes'].hex(), 'battle camera trampolines (ExRAM $5E7F)')
    r.mods.append(dict(t, where=(EXRAM, t['org'] - 0x5C00)))
    r.patch(B7F, 0xFA2F, '20 1D FA', '20 7F 5E', 'battle start: battle cameras')
    r.patch(B7F, 0xFA73, '20 1D FA', '20 83 5E', 'battle end: field camera')
    # party column: x by row (front, back) and members 24 px apart
    r.patch(B2F, 0xB516, 'D0 E0', 'A0 A4', 'party x: front 160 / back 164 (GB 140 / 144)')
    for a in (0xB51E, 0xB526):
        r.patch(B2F, a, '2C 48 64 80', '2F 47 5F 77', 'party y: 24 px apart from 47')
    # step forward / back: 8 px (front row), 12 (back row), 8 confused
    r.patch(B2F, 0xB3B8, '10', '08', 'step forward (front row) 8 px')
    r.patch(B2F, 0xB3B1, '20', '0C', 'step forward (back row) 12 px')
    r.patch(B2F, 0xB37C, '10', '08', 'step back (front row) 8 px')
    r.patch(B2F, 0xB375, '20', '0C', 'step back (back row) 12 px')
    r.patch(B2F, 0xB362, 'F0', 'F8', 'confused: step back 8 px')
    r.patch(B2F, 0xB39E, 'F0', 'F8', 'confused: step back 8 px')
    # battle windows: FF3's rows from 19 (row 18 is the enemy animations': hidden on the
    # GB), 4 rows of text (one tile row per line)
    r.patch(B34, 0x8BC3, 'A9 08 85 30', 'A9 04 85 30', 'windows: 4 rows (list windows: 8, battle_messages)')
    r.patch(B34, 0x966A, 'A5 18', 'A9 00', 'text lines in the first buffer row (bconv)')
    r.patch(B34, 0x969C, 'A5 18', 'A9 00', 'text lines in the first buffer row (bconvb)')
    r.patch(B34, 0x967E, '0A', 'EA', 'bconv newline: one buffer row (was two)')
    r.patch(B34, 0x9BB0, 'A9 77 8D 0A 72 A9 79 8D 0B 72', 'EA' * 10, 'no HP header (on line 1 now)')
    r.patch(B34, 0x9CD4, 'A9 0B 85 18 A9 1E', 'A9 02 85 18 A9 15', 'party window cols 2-21')
    # cursors: command hand at NES x 16-31 (GB 0-15, over the window frame at the screen edge,
    # as FF1) beside the text (col 4), one row per command
    r.patch(B34, 0x8B00, 'A8 10 B8 10 C8 10 D8 10', 'A0 18 A8 18 B0 18 B8 18', 'command cursor')
    for a in (0x9AD8, 0x9DD5):
        r.patch(B34, a, 'A9 01 85 18 A9 0A', 'A9 02 85 18 A9 0B', 'command / names window cols 2-11')


# battle item list (owner, 2026-11-20): pages instead of FF3's sideways scroll. The cursor
# column ($63) is always the left one ($66); its window at cols 2-16, the next column at
# cols 17-31 (its edge shows at the GB's right); both are 8-row list windows ($1A bit 7: the
# GB's tall list camera). The page routines take the place of the scroll routines.
ITEMPG_SRC = '''
POSI = $5F2D
    org $B2A7
pgright:            ; (scroll item list right) next page
    inc $66
    jmp pgdraw
pgleft:             ; (scroll item list left) previous page
    dec $66
pgdraw:
    lda $66
    ldx #0
    jsr drawcol
    lda $66
    clc
    adc #1
    ldx #1
    jsr drawcol
    lda $67         ; the selected item's cursor (cursor 1): on its page only
    beq .hide
    lda $69
    cmp $66
    bne .hide
    lda #$A8
    ldx $68
    beq .y
    clc
.yl:
    adc #$10
    dex
    bne .yl
.y:
    sta $1C
    lda #$1C
    sta $1D
    lda #1
    sta $1A
    jmp $892E
.hide:
    lda $1C
    pha
    lda #$F0
    sta $1C
    lda #1
    sta $1A
    jsr $892E
    pla
    sta $1C
    rts
drawcol:            ; column A (0 = the hands, 1-8 inventory, 9 = none) at position X
    stx POSI        ;   (0 left, 1 right)
    cmp #9
    bcs .blank
    tax
    beq .eq
    dex
    txa
    asl a
    asl a
    asl a
    sta $3D
    jsr $B48B       ; draw inventory column (text)
    jmp posopen
.eq:
    jmp $B419       ; draw equipped items (its window: posopen)
.blank:
    lda #$FF
    ldx #7
.b:
    sta $34,x
    dex
    bpl .b
    jsr $B1D8       ; (blank rows)
posopen:
    ldx POSI
    lda POSL,x
    sta $18
    lda POSR,x
    sta $19
    lda #$83        ; both borders, list window
    sta $1A
    jmp $8B38
redrawk:            ; (after an item use / swap) column X again, if shown
    txa
    ldx #0
    cmp $66
    beq .go
    inx
    sec
    sbc #1
    cmp $66
    bne .no
    adc #0
.go:
    jmp drawcol
.no:
    rts
redraw0:
    ldx #0
    jmp redrawk
iteminit:           ; the first page: columns 1 and 2
    lda #1
    sta $66
    ldx #0
    jsr drawcol
    lda #2
    ldx #1
    jmp drawcol
POSL:
    .db $02, $11
POSR:
    .db $10, $1F
RHT:                ; the hands' labels (FF3 wrote Japanese "right hand" / "left hand" codes
    .db $9B, $BE, $91, $A4, $B1, $A7    ;   that the English font shows as "fGS" / "aPnS"):
LHT:                ;   "R.Hand", "L.Hand"
    .db $95, $BE, $91, $A4, $B1, $A7
'''


def items_pages(r):
    B35 = 0x35
    m = r.module(ITEMPG_SRC)
    assert m['org'] + len(m['bytes']) <= 0xB419, hex(m['org'] + len(m['bytes']))
    o = r.off(B35, 0xB2A7)
    assert r.d[o:o + 4].hex() == 'a566c906'
    r.d[o:r.off(B35, 0xB419)] = m['bytes'] + b'\xEA' * (0xB419 - 0xB2A7 - len(m['bytes']))
    r.mods.append(dict(m, where=(B35, 0xB2A7 & 0x1FFF)))
    r.log.append((B35, 0xB2A7, 'item list pages (in place of the scroll routines)'))
    L = m['labels']
    j = lambda a: '%02X %02X' % (a & 0xFF, a >> 8)
    patch = r.patch
    # POSI ($5F2D) is read by the first "draw equipped items" of the menu before a page is drawn
    r.patch(0x40, 0x832D, 'FF', '00', 'item page position = 0 at reset (ExRAM image)')
    patch(B35, 0xAF16, '20 62 B3', '20 ' + j(L['pgleft']), 'item list: previous page')
    patch(B35, 0xAF41, '20 A7 B2', '20 ' + j(L['pgright']), 'item list: next page')
    patch(B35, 0xAF37, 'A5 66 C9 07', 'A5 66 C9 08', 'item list: page to the last column too')
    patch(B35, 0xADB9, 'A9 78 85 10', 'A9 00 85 10', 'item list: no scroll')
    init = r.off(B35, 0xAE40)
    assert r.d[init:init + 7].hex() == 'a900853d208bb4' and r.d[r.off(B35, 0xAE77):r.off(B35, 0xAE7A)].hex() == '20388b'
    r.d[init:r.off(B35, 0xAE7A)] = bytes.fromhex('20' + j(L['iteminit']).replace(' ', '')) + b'\xEA' * (0xAE7A - 0xAE40 - 3)
    r.log.append((B35, 0xAE40, 'item list: first page'))
    patch(B35, 0xB47C, 'A9 01 85 18 A9 0F 85 19 A9 03 85 1A 4C 38 8B',
            '4C ' + j(L['posopen']) + ' EA' * 12, 'equipped items: page position')
    patch(B35, 0xB601, 'CA 8A 20 3F FD', '4C ' + j(L['redrawk']) + ' EA EA', 'item list: redraw a shown column')
    patch(B35, 0xB5F9, 'A9 FF 8D 73 75 4C 19 B4', 'A9 FF 8D 73 75 4C ' + j(L['redraw0']), 'item list: redraw the hands if shown')
    patch(B35, 0xB4E8, 'A9 08', 'A9 18', 'item cursor: hand over the window frame')
    r.patch(0x34, 0x8B28, 'A8 08 B8 08 C8 08 D8 08', 'A8 18 B8 18 C8 18 D8 18', 'item list cursor table: x')
    patch(B35, 0xAF3D, 'C5 63 F0 03', 'C5 63 EA EA', 'item list: right always turns the page')
    lab = ('A2 05 BD %s 9D 0D 72 BD %s 9D 41 72 CA 10 F1' % (j(L['RHT']), j(L['LHT'])))
    patch(B35, 0xB449, 'A9 C0 8D 01 72 8D 35 72 A9 9C 8D 0F 72 8D 44 72 A9 A9 8D 0D 72 A9 90 8D 0E 72 '
          'A9 A4 8D 41 72 A9 99 8D 42 72 A9 B1 8D 43 72', lab + ' EA' * (41 - 17),
          'the hands: English labels R.Hand / L.Hand')


# battle magic list (owner, 2026-11-20: "a level line, then one spell per row"): per level a
# line "Lv<n>  MP cur/max" and its three spells one per row (4 rows of 18), 2 levels per page.
# The level rows come from MGROW (bank 87, in place of the English row converter mconv, through
# its far-call entry $A009); the menu's input goes through MAGIN (bank 53, free space after the
# item pages) instead of the generic list cursor: up / down step through the spells (into the
# next level after the third), left / right jump a level; the hand from the menu's own state.
MGROW_SRC = """
MAGN = $5E34        ; (English: the level row's three names, 16 bytes each, and marks)
MAGM = $5E64
    org $B2E0
mgrow:
    ldy #0          ; row 0: Lv<n> .. MP cur/max
    lda #$95
    sta ($4E),y
    iny
    lda #$B9
    sta ($4E),y
    iny
    lda $7AD7
    sta ($4E),y
    ldy #10
    lda #$96
    sta ($4E),y
    iny
    lda #$99
    sta ($4E),y
    ldy #13
    ldx #2
.m:
    lda $7AD7,x
    sta ($4E),y
    iny
    inx
    cpx #7
    bne .m
    lda $4E         ; rows 1-3: mark, then the spell (icon and name)
    sta $1E
    lda $4F
    sta $1F
    lda #0
    sta $1C
.k:
    clc
    lda $1E
    adc #18
    sta $1E
    bcc .k1
    inc $1F
.k1:
    ldx $1C
    ldy #0
    lda MAGM,x
    sta ($1E),y
    lda #$FF
    sta MAGM,x
    txa
    asl a
    asl a
    asl a
    asl a
    tax
    ldy #1
.c:
    lda MAGN,x
    beq .e
    sta ($1E),y
    inx
    iny
    cpy #18
    bne .c
.e:
    lda $1C
    asl a
    asl a
    asl a
    asl a
    tax
    lda #0
    sta MAGN,x
    inc $1C
    lda $1C
    cmp #3
    bne .k
    rts
"""
MAGIN_SRC = """
    org $B370
magin:              ; (magic menu: in place of the generic list input, $899E)
    lda $25         ; the hand: level row $25 (32 px each), spell $26 (8 px)
    asl a
    asl a
    asl a
    asl a
    asl a
    sta $1C
    lda $26
    asl a
    asl a
    asl a
    clc
    adc $1C
    adc #$A8
    sta $1C
    lda #$18
    sta $1D
    lda #0
    sta $1A
    jsr $892E
.w:
    jsr $8185
    jsr $FBAA
    lda $12
    beq .w
    pha
    jsr $9B79
    pla
    cmp #$20        ; down: the next spell; after the third, the next level
    bne .u
    lda $26
    cmp #2
    bcs .dl
    lda #$80
    bne .x
.dl:
    lda $24
    cmp #7
    beq .no
    cmp $46
    beq .no
    lda #0
    sta $26
    lda #$20
    bne .x
.u:
    cmp #$10        ; up: the previous spell; before the first, the level above
    bne .l
    lda $26
    beq .ul
    lda #$40
    bne .x
.ul:
    lda $24
    beq .no
    lda #2
    sta $26
    lda #$10
    bne .x
.l:
    cmp #$40        ; left / right: a level up / down
    bne .r
    lda #$10
    bne .x
.r:
    cmp #$80
    bne .x
    lda #$20
    bne .x
.no:
    lda #$04        ; (Select: nothing in the magic menu)
.x:
    sta $12
    rts
"""


def magic_rows(r):
    B87, B35 = 87, 0x35
    g = r.module(MGROW_SRC)
    o = r.off(B87, g['org'])
    assert set(r.d[o:o + len(g['bytes'])]) == {0xFF}
    r.d[o:o + len(g['bytes'])] = g['bytes']
    r.mods.append(dict(g, where=(B87, g['org'] & 0x1FFF)))
    j = lambda a: '%02X %02X' % (a & 0xFF, a >> 8)
    r.patch(B87, 0xA009, '4C C6 A2', '4C ' + j(g['labels']['mgrow']), 'magic level rows: GB layout (mgrow)')
    m = r.module(MAGIN_SRC)
    assert m['org'] + len(m['bytes']) <= 0xB419
    o = r.off(B35, m['org'])
    assert set(r.d[o:o + len(m['bytes'])]) == {0xEA}
    r.d[o:o + len(m['bytes'])] = m['bytes']
    r.mods.append(dict(m, where=(B35, m['org'] & 0x1FFF)))
    r.patch(B35, 0xB7C3, '20 9E 89', '20 ' + j(m['labels']['magin']), 'magic menu input: spells in list order')
    r.patch(B35, 0xB785, 'A9 1C 20 58 A5', 'A9 48 20 58 A5', 'magic list: 4 rows of 18 per level')
    r.patch(B35, 0xB80B, 'E9 38', 'E9 48', 'magic list scroll up: one level')
    r.patch(B35, 0xB844, '69 38', '69 48', 'magic list scroll down: one level')
    r.patch(B35, 0xB83B, '04', '02', 'magic list: 2 levels per page')
    for a in (0xB796, 0xB818, 0xB851):
        r.patch(B35, a, 'A9 01 85 18 A9 1E 85 19 A9 03 85 1A', 'A9 02 85 18 A9 15 85 19 A9 83 85 1A',
                'magic window: cols 2-21, list window')
    r.patch(0x34, 0x8B08, 'A8 08', 'A8 18', 'magic cursor: first position (hand at the screen edge)')


def battle_messages(r):
    B34 = 0x34
    x = r.module(MSGX_SRC)
    assert x['org'] + len(x['bytes']) <= MSGX_END, hex(x['org'] + len(x['bytes']))
    xo = r.off(0x40, x['org'] - 0x5C00 + 0x8000)
    assert set(r.d[xo:xo + len(x['bytes'])]) == {0xFF}
    r.d[xo:xo + len(x['bytes'])] = x['bytes']
    r.log.append((0x40, x['org'], 'message window helpers in ExRAM (%d bytes)' % len(x['bytes'])))
    r.mods.append(dict(x, where=(EXRAM, x['org'] - 0x5C00)))
    r.patch(0x40, 0x8290, 'FF', '00', 'MCNT = 0 at reset (ExRAM image)')
    syms = {k: v for k, v in x['labels'].items() if '.' not in k}
    syms['ARROW'] = ARROW
    m = r.module(MSG_SRC, syms)
    assert m['org'] == 0x8D1B and m['org'] + len(m['bytes']) <= MSG_END, hex(m['org'] + len(m['bytes']))
    m['bytes'] += b'\xEA' * (MSG_END - 0x8D1B - len(m['bytes']))       # (the old routines' rest)
    o = r.off(B34, 0x8D1B)
    if r.d[o:o + 5].hex() != '8518203ffd' or r.d[r.off(B34, 0x8E83):r.off(B34, 0x8E85)].hex() != '6122':
        raise SystemExit('layout: open message window / box table not found')
    r.d[o:r.off(B34, MSG_END)] = m['bytes']
    r.log.append((B34, 0x8D1B, 'message window routines'))
    r.mods.append(dict(m, where=(B34, 0x8D1B & 0x1FFF)))
    # enemy-names window
    syms2 = dict(syms, **{k: v for k, v in m['labels'].items() if '.' not in k})
    syms2['bconvb'] = 0x969C
    syms2['names2'] = 0x9716
    n1 = r.module(NAMES1_SRC, syms2)
    n2 = r.module(NAMES2_SRC, syms2)
    assert n1['org'] + len(n1['bytes']) <= 0x9DE4, hex(n1['org'] + len(n1['bytes']))
    assert n2['org'] + len(n2['bytes']) <= 0x9754, hex(n2['org'] + len(n2['bytes']))
    o1 = r.off(B34, 0x9D9E)
    assert r.d[o1:o1 + 8].hex() == '205497a9008524a2'
    r.d[o1:o1 + len(n1['bytes'])] = n1['bytes']
    r.d[o1 + len(n1['bytes']):r.off(B34, 0x9DE4)] = b'\xEA' * (0x9DE4 - 0x9D9E - len(n1['bytes']))
    o2 = r.off(B34, 0x9716)
    assert set(r.d[o2:r.off(B34, 0x9754)]) == {0xEA}
    r.d[o2:o2 + len(n2['bytes'])] = n2['bytes']
    r.mods += [dict(n1, where=(B34, 0x9D9E & 0x1FFF)), dict(n2, where=(B34, 0x9716 & 0x1FFF))]
    r.log.append((B34, 0x9D9E, 'enemy-names window as wide as the longest name'))
    t = m['labels']['tgtnames']
    for a in (0xA84E, 0xA9AF, 0xB9D4):
        r.patch(0x35, a, 'A9 10 20 0E FA', '20 %02X %02X EA EA' % (t & 0xFF, t >> 8), 'names while targeting')
    w = n1['labels']['winh']
    r.patch(B34, 0x8BC3, 'A9 04 85 30', '20 %02X %02X EA' % (w & 0xFF, w >> 8), 'window height: 4, list windows 8')
    items_pages(r)
    # the close call ($94DF LDA $4B / JSR $8E14) -> msgclose
    c = m['labels']['msgclose']
    r.patch(B34, 0x94E0, '4B 20 14 8E', '4B 20 %02X %02X' % (c & 0xFF, c >> 8), 'close message window')
    # box texts: never split (one row of 64 in the buffer; the window wraps them itself)
    for a in (0x9091, 0x90C1, 0x9168, 0x91BF, 0x91EF, 0x9253, 0x9313):
        o = r.off(B34, a)
        assert r.d[o] == 0xA9 and r.d[o + 2:o + 4] == bytes([0x85, 0x18]), hex(a)
        r.d[o + 1] = 0x40
    r.log.append((B34, 0x9091, 'box text widths 64'))
    # the arrow glyph
    lo = bytearray(8); hi = bytearray(8)
    for y, row in enumerate(ARROW_ROWS):
        for x in range(8):
            c = 3 if row[x] == '#' else 2
            if c & 1: lo[y] |= 0x80 >> x
            if c & 2: hi[y] |= 0x80 >> x
    o = 16 + FONT + ARROW * 16
    r.d[o:o + 16] = bytes(lo + hi)
    r.log.append((0, 0, 'arrow glyph $%02X' % ARROW))


# minimap (the Sight spell on the overworld; its last screen setup, bank 58 $8C3F, before it
# shows): a 16 x 16-tile map at NES cols
# 8-23, rows 10-23 (sea x 64-191, y 80-191) in a frame: camera (48, 64) centres it; the runtime goes back to the field
# camera when the screen goes off after it (the menu it returns to)
MINI_SRC = '''
    org $5FF0
minicam:
    lda #48
    sta $5802       ; (GB runtime: screen camera X / Y, pixels; open bus on the NES)
    lda #64
    sta $5803
    jmp $FF00       ; wait for vblank (the call this replaces)
'''


def field(r):
    m = r.module(MINI_SRC)
    assert m['org'] + len(m['bytes']) <= 0x6000
    xo = r.off(0x40, m['org'] - 0x5C00 + 0x8000)
    assert set(r.d[xo:xo + len(m['bytes'])]) == {0xFF}
    r.d[xo:xo + len(m['bytes'])] = m['bytes']
    r.mods.append(dict(m, where=(EXRAM, m['org'] - 0x5C00)))
    r.log.append((0x40, m['org'], 'minimap camera (ExRAM)'))
    r.patch(0x3A, 0x8C3F, '20 00 FF', '20 F0 5F', 'minimap: its camera')
    if os.environ.get('GB3_TEST_MINI'):      # (test builds only: Select on the field shows the
        r.patch(0x7F, 0xE36B, '4C 2C F7', '4C 63 C0', 'TEST: Select = minimap')   # minimap)


# field text windows (bank 127 $EDB2: left, top, width, height in screen tiles for the windows
# 0 dialogue, 1 yes / no, 2 item select, 3 gil, 4 map title) inside the GB view of the field
# camera (40, 45): screen cols 5-24, rows 6-23. Dialogue as FF1's (owner-approved there): a box
# across the top, 4 lines of 18 above the centred party (rows 6-11); the English dialogue text
# re-wrapped at 18 columns (tools/ff3/insert.py's table builder run again with that width).
FIELD_WINDOWS = {   # id: (left, top, width, height)       (NES: 2,2,28,10 / 2,18,8,10 / ...)
    0: (5, 6, 20, 6), 1: (17, 14, 8, 8), 2: (5, 12, 20, 10), 3: (13, 18, 12, 4), 4: (5, 6, 20, 4)}
# (even heights from even rows: a window's last row must not share an attribute quadrant with
# the map row below it)
DLG_W_GB = 18
# field messages of the t8200 table (dialogue ids $0100+: chests, doors, the inn, Mini / Warp
# refusals): the NES prints them in the two-row (dakuten) mode, two lines per page in its 28-column
# window, which the GB window cut ("Inside the treasu"; a one-line page repeated its line). On the
# GB: the English one-row mode ({0E}), 18 columns, four lines a page. ({02} item / spell name,
# {03} / {04} Gil amounts; [77][79] the two HP tiles.)
FIELD_MSGS = {
    1: 'From inside the\ntreasure chest,\nyou got\n{03} Gil!',
    2: 'Inside the\ntreasure chest\nthere was\n{02}!\nSuddenly, monsters\nappeared!!',
    3: 'The door is\nlocked!',
    4: 'Innkeeper:\n"Welcome! To\nrestore your\nparty\'s [77][79], it\nwill cost\n{04} Gil.\nWill you stay the\nnight?"',
    89: 'Inside the\ntreasure chest\nthere was\n{02}!',
    118: 'In a place like\nthis,\n{02}!',
    119: "It's too cramped\nhere to become\nbig.",
    120: 'Warping impossible',
    121: 'Magic cannot be\nused',
    122: "With the Thief's\nspecial ability,\nthe lock opened\njust like that!",
}


def dialogue(r):
    import importlib.util, json
    spec = importlib.util.spec_from_file_location('ff3insert', os.path.join(HERE, '..', 'ff3', 'insert.py'))
    ins = importlib.util.module_from_spec(spec); spec.loader.exec_module(ins)
    for e in json.load(open('script/ff3/names8800.json')): ins.NAMES[e['id']] = e['en']
    def flow_gb(para, width, _flow=ins.flow):
        lines = _flow(para, width)
        if all(ins.vlen(l) <= width for l in lines): return lines
        # a word longer than the line: break it after a hyphen (greedy fill)
        toks = []
        for w in para.split(' '):
            if not w: continue
            if ins.vlen(w) <= width: toks.append((w, True)); continue
            parts = re.split(r'(?<=-)', w)
            for k, pt in enumerate(parts):
                if pt: toks.append((pt, k == 0))
        out = []; cur = ''
        for t, sp in toks:
            cand = (cur + (' ' if sp and cur else '') + t) if cur else t
            if ins.vlen(cand) <= width: cur = cand
            else: out.append(cur); cur = t
        if cur: out.append(cur)
        assert all(ins.vlen(l) <= width for l in out), out
        return out
    ins.flow = flow_gb
    _load = ins.load_rows
    ins.NARRATION = {('t8000', t): 0 for t in PROPHECY_IDS}      # (pages laid out already)
    ins.centred = (lambda f: lambda text, width: text if width == 0 else f(text, width))(ins.centred)
    def load_gb(name):
        rows = _load(name)
        if name == 't8000':                                    # opening prophecy: 5 GB pages
            pt = prophecy_text(rows, ins)
            for e in rows:
                if e['id'] in pt: e['en'] = pt[e['id']]
        for e in rows:                                        # Nintendo terminology (release
            if isinstance(e.get('en'), str):                  #   checklist 4; tools/gb/termcheck.py)
                e['en'] = e['en'].replace('A button', 'A Button').replace('B button', 'B Button')
        if name == 't8200':
            for e in rows:
                if e['id'] in MENU_TEXT: e['en'] = MENU_TEXT[e['id']]
                if e['id'] in FIELD_MSGS:
                    assert all(ins.vlen(re.sub(r'\{0[234]\}', 'X' * 5, l)) <= 18 or '{02}' in l
                               for l in FIELD_MSGS[e['id']].split('\n')), e['id']
                    e['en'] = '{0E}' + FIELD_MSGS[e['id']]
                if e['id'] == 0x21:                          # name entry grid: no middle gap
                    e['en'] = re.sub(r'\{17:([0-9A-F]{2})\}', lambda mm: '{17:%02X}' % MENU_TEXT_NAME_GRID.get(
                        int(mm.group(1), 16), int(mm.group(1), 16)), e['en'])
        return rows
    ins.load_rows = load_gb
    for e in json.load(open('script/ff3/t8200.json')):        # equip messages (window $1E):
        if e['id'] in EQUIP_MSGS:                             #   18 columns
            t = e['en']; assert t.startswith('{0E}'), t
            MENU_TEXT[e['id']] = '{0E}' + '\n'.join(flow_gb(t[4:].replace('\n', ' '), 18))
    MENU_TEXT[0x4E] = '{0E}You can turn the\npower off now.'  # (the NES's "Hold RESET while you turn
                                                         #   the power off": a Game Boy has no RESET)
    ins.layout.__defaults__ = (DLG_W_GB,)
    rep = []
    ins.put_tables(r.d, rep)
    r.log.append((0, 0, 'dialogue text re-wrapped at %d columns' % DLG_W_GB))
    old = r.d[r.off(0x7F, 0xEDB2):r.off(0x7F, 0xEDB2) + 20]
    assert old.hex() == '0202021202' '0212120e02' '1c081c0c1c' '0a0a0a0404', old.hex()
    new = bytearray(20)
    for k, (x, y, w, h) in FIELD_WINDOWS.items():
        new[k], new[5 + k], new[10 + k], new[15 + k] = x, y, w, h
    r.d[r.off(0x7F, 0xEDB2):r.off(0x7F, 0xEDB2) + 20] = new
    r.log.append((0x7F, 0xEDB2, 'field text windows inside the GB view'))
    # the windows start at an odd column (the GB view's first, col 5): their attributes need
    # one more 16 x 16 quadrant than width / 2 (helper in the unreferenced code at $F435)
    r.patch(0x7F, 0xF435, 'A6 3B CA 10 02 A6 3B A5', 'A5 3C 4A 69 01 85 86 60', 'window quadrants: width / 2 + 1')
    r.patch(0x7E, 0xC99D, 'A5 3C 4A 85 86', '20 35 F4 EA EA', 'window attributes: one more quadrant')
    r.patch(0x7E, 0xC9B0, 'AA CA', 'AA EA', 'window attribute update: one more quadrant')
    # closing: the map redrawn under the windows, upward from the bottom metatile row (count,
    # start = bottom / 2 + 1; FF3: rows 2-11 -> 5, 6 and rows 14-27 -> 7, 14)
    r.patch(0x7E, 0xC9B9, 'A9 05 85 66 A2 06', 'A9 03 85 66 A2 06', 'close dialogue: rows 6-11')
    r.patch(0x7E, 0xC9C4, 'A9 07 85 66 A2 0E', 'A9 05 85 66 A2 0B', 'close lower windows: rows 12-21')


# field main menu (owner, 2026-11-20: mock-up N5B): party window on the left (GB cols 0-12),
# one block per member: name + level / job (condensed) / HP (green) / MP of the 8 levels, the
# member's lines pulled up 0 / 1 / 1 / 2 px and 3 px between members; commands top right, Gil
# and Capacity in 4-px digits below them, the guest's name at the bottom right. NES side (this
# ROM): camera (24, 0); party window (3, 0, 13, 22) with a blank row after each member (NES
# rows 1-4 + 5i, spacer 5 + 5i); the right windows at NES cols 16-22. GB side (runtime, $5808 =
# menu mode): the right windows on the GB window layer, the party window's pixel offsets by
# SCY changes at fixed lines, the HP rows' palettes per tile ($5809 = member * 4 + palette;
# FF3 colours them by attribute quadrant, which here would also take the frame or the job /
# MP line). Text: one row per line ({0E}: the English one-row mode).
MENU_WINDOWS = {0: (3, 0, 13, 22), 1: (16, 0, 7, 9), 2: (16, 13, 7, 5), 3: (16, 9, 7, 4)}
JBGO, JBTAIL = 0x5D4E, 0x5D60           # ExRAM (tools/ff3/insert.py): bank 88 call / its return


def menu_party_text():
    out = ['{0E}']
    for i in range(4):
        c = '%02X' % (0x10 + i)
        mp = ''         # (the MP cells: SMALLNUM, small digits with slashes)
        out.append('{%s:02}{14:07}{%s:00}\n{%s:01}\n{14:02}{%s:30}/{%s:31}{14:00}[77][79]\n'
                   '%s{14:00}[78][79]' % (c, c, c, c, c, mp))
        if i < 3: out.append('\n\n')
    return ''.join(out)


MENU_TEXT = {   # t8200 ids (GB layout; the MP of a level: 2 cells "_n", written right to left)
    0x30: menu_party_text(),
    0x31: '{0E}{15:00}Item\n{15:00}Magic\n{15:00}Equip\n{15:00}[E1][E2][E3][E4]\n{15:00}Order\n'
          '{15:00}Job\n{15:00}Save',
    0x32: '{0E}{07}',
    0x33: '{0E}{14:01}[7B][7C][7D][7E]\n{14:03}[7F][CA]',   # (tiles drawn by SMALLNUM)
    # the guest's name (code 07, only in the main menu's guest window, 5 columns): the given
    # name alone (owner-approved mock-up: "Sara")
    0xF8: 'Sara', 0xF9: 'Cid', 0xFD: 'Alus',

}

MENU_HP_SRC = '''
    org $95B2
hppal:              ; (was: HP text attributes) menu mode on and the members' HP palettes
    ldy #12         ;   (bank 88 hppal8)
    lda #$FB
    jmp JBGO
stcam:              ; status / equip / item screens: their camera (windows from NES 1, 1)
    lda #8
    sta $5802
    sta $5803
    jmp $956F
stpost:             ; status text drawn: HP palette, condensed words and MP digits (bank 88)
    ldy #12
    lda #$FD
    jmp JBGO
stsel:              ; select character ($A715, item / magic targets): the party window on
    sta $79F0       ;   demand and its HP palettes (the STA this replaces: A = 0)
    jsr $A328
    ldy #12
    lda #$FC
    jmp JBGO
jmove:              ; job list cursor: FF3's move (one job a step), then left / right turn the
    jsr $91A3       ;   page (bank 88 jkey; the redraw in jmv2)
    ldy #12
    lda #$F7
    jsr JBGO
    jmp JMV2
mmove:              ; magic spell cursor: FF3's move (one spell a step), then left / right
    jsr $91D9       ;   turn the page (bank 88 sets MPG bit 7: redraw)
    ldy #12
    lda #$F9
    jsr JBGO
    lda MPG
    bpl .r
    and #$7F
    sta MPG
    ldx #8
    lda #$3C
    jsr $A875
    lda #0
    sta $79F0
.r:
    rts
mnuoff:             ; close menu ($A685's last step, the screen clear): then the GB's menu
    jsr $F465       ;   mode off and the word tiles back
    lda #0
    sta $5808
    ldy #12
    lda #$FE
    jmp JBGO
'''

SMALLNUM_SRC = '''
SNB = $5EB4         ; ExRAM (battle only: the message window's save area): 6 tiles' plane 0
DG = $5EE4          ; 12 characters: Gil (7 digits, G), Capacity (3 digits, C)
MPC = $5EF0         ; MP cell codes (4 x 8)
RST = $5FFE         ; $A5: the MP tiles are in the word tiles' place (ExRAM image: $FF)
WST = $5FFD         ; $A5: the status words are on job-name tiles
MPG = $5FFF         ; magic list: page (bits 0-1), last left / right (4-5), redraw (7)
WT = $5EB4          ; status: the word tiles' numbers (WN)
    org $85E0
disp2:              ; bank 88 $8004 (JOBF dispatch, Y = 12: was JMP sq): A = $FF -> smallnum,
    cmp #$FF        ;   $FE -> restore (numsq passes a text column)
    beq smallnum
    cmp #$FE
    bne .q
    jmp restore
.q:
    cmp #$FD
    bne .q2
    jmp status
.q2:
    cmp #$FC
    bne .q3
    jmp cwpal
.q3:
    cmp #$FB
    bne .q4
    jmp hppal8
.q4:
    cmp #$3C        ; (copied character strings: the magic list / the job list)
    bne .q5
    jmp mgpage
.q5:
    cmp #$4A
    bne .q7
    jmp jgpage
.q7:
    cmp #$F7
    bne .q8
    jmp jkey
.q8:
    cmp #$F6
    bne .q9
    jmp jsel8
.q9:
    cmp #$F9
    bne .q10
    jmp mgkey
.q10:
    cmp #$F5
    bne .q11
    jmp nmcam
.q11:
    cmp #$F4
    bne .q6
    lda #8          ; shopcam: the shop's GB camera (8, 8), then the NES's scroll 0 / rendering
    sta $5802
    sta $5803
    lda #0
    sta $2005
    sta $2005
    lda #$1E
    sta $2001
    jmp JBTAIL
.q6:
    jmp SQ
nmcam:              ; name entry (each frame, via the character sprite routine 3D:B886): the
    lda #$88        ;   sprite inside the name window (x 136, y 8), the GB camera (32, 0)
    sta $40         ;   (tools/gb3/layout.py name_entry); X kept
    lda #$08
    sta $41
    lda #32
    sta $5802
    lda #0
    sta $5803
    jmp JBTAIL
smallnum:           ; Gil and Capacity in 4-px digits -> tiles $7B-$7F, $CA (main menu)
    lda $601C
    sta $80
    lda $601D
    sta $81
    lda $601E
    sta $82
    lda #0
    sta $85
    tax
    jsr conv
    lda $601B
    sta $80
    lda #0
    sta $81
    sta $82
    lda #8
    sta $85
    ldx #4
    jsr conv
    lda #11
    sta DG+7
    lda #12
    sta DG+11
    ldy #0
    lda #6
    sta $87
    jsr blank
    ldy #8
    lda #10
    sta $87
    jsr blank
    lda #0
    sta $88
    tax
.t:
    ldy $88
    lda DG,y
    asl a
    asl a
    asl a
    sta $83
    lda DG+1,y
    asl a
    asl a
    asl a
    sta $84
    lda #8
    sta $85
.r:
    ldy $84
    lda GL,y
    lsr a
    lsr a
    lsr a
    lsr a
    sta $86
    ldy $83
    lda GL,y
    ora $86
    sta SNB,x
    inx
    inc $83
    inc $84
    dec $85
    bne .r
    inc $88
    inc $88
    lda $88
    cmp #12
    bcc .t
    jsr $FF00       ; wait for vblank
    lda $FF         ; (increment 1)
    and #$FB
    sta $2000
    lda $2002
    lda #$07
    sta $2006
    lda #$B0
    sta $2006
    ldx #0
.u:
    ldy #8
.p0:
    lda SNB,x
    sta $2007
    inx
    dey
    bne .p0
    ldy #8
    lda #$FF
.p1:
    sta $2007
    dey
    bne .p1
    cpx #40
    bcc .u
    lda #$0C
    sta $2006
    lda #$A0
    sta $2006
    ldy #8
.q0:
    lda SNB,x
    sta $2007
    inx
    dey
    bne .q0
    ldy #8
    lda #$FF
.q1:
    sta $2007
    dey
    bne .q1
    jsr fin
    ; MP of the 8 levels per member (owner: the small digits with slashes)
    ldx #0
    ldy #0
.mm:
    jsr mpcodes
    txa
    clc
    adc #$40
    tax
    bne .mm
    jsr mptiles
    jsr $FF00       ; the MP cells (NES rows 4 + 5 m, cols 6-13)
    jsr inc1
    ldx #0
    ldy #0
.nr:
    lda NTH,y
    sta $2006
    lda NTL,y
    sta $2006
    lda #8
    sta $85
.nc:
    lda MPC,x
    sta $2007
    inx
    dec $85
    bne .nc
    iny
    cpy #4
    bcc .nr
    jsr fin
    jmp JBTAIL
mpcodes:            ; member X ($00/$40/..): its 8 MP cell codes to MPC + Y (Y advanced, X kept):
    lda #0          ;   "d/" ($E5 + d) for levels 1-7, "d" (DTILE) for level 8; MP at $6130 + X + 2l
    sta $85
.ml:
    stx $86
    lda $85
    asl a
    clc
    adc $86
    tax
    lda $6130,x
    cmp #10
    bcc .ok
    lda #9
.ok:
    ldx $85
    cpx #7
    bcs .la
    clc
    adc #$E5
    bne .st
.la:
    tax
    lda DTILE,x
.st:
    sta MPC,y
    iny
    ldx $86
    inc $85
    lda $85
    cmp #8
    bcc .ml
    rts
mptiles:            ; the 20 MP tiles over the word tiles $E5-$F6, $C9, $CF (unless there)
    lda RST
    cmp #$A5
    bne .u
    rts
.u:
    lda #$0E        ; $E5-$EE ("0/" - "9/"), 5 tiles per vblank
    ldy #$50
    ldx #0
    jsr tiles5
    lda #$0E
    ldy #$A0
    ldx #40
    jsr tiles5
    lda #$0E        ; $EF-$F3, $F4-$F6 ("0" - "7")
    ldy #$F0
    ldx #80
    jsr tiles5
    jsr $FF00
    jsr inc1
    lda #$0F
    sta $2006
    lda #$40
    sta $2006
    ldx #120
    ldy #3
    jsr tiles
    lda #$0C        ; $C9 ("8"), $CF ("9")
    sta $2006
    lda #$90
    sta $2006
    ldy #1
    jsr tiles
    lda #$0C
    sta $2006
    lda #$F0
    sta $2006
    ldy #1
    jsr tiles
    jsr fin
    lda #$A5
    sta RST
    rts
hpp:                ; member X: HP palette (0 green, 1 orange: a status, 2 pink: dead / stone)
    lda $6102,x
    and #$FE
    beq .r
    and #$C0
    cmp #$01
    lda #2
    bcs .r
    lda #1
.r:
    rts
hppal8:             ; main menu: menu mode on, member m's palette p -> $5809 = 4m + p
    lda #1
    sta $5808
    ldx #0
    ldy #0
.m:
    jsr hpp
    sta $80
    tya
    ora $80
    sta $5809
    iny
    iny
    iny
    iny
    txa
    clc
    adc #$40
    tax
    bne .m
    jmp JBTAIL
cwpal:              ; item / magic party window: HP palettes of rows 13-16 (cols 9-19)
    ldx #0
    ldy #13
.m:
    jsr hpp
    ora #11 * 4
    sty $580A
    pha
    lda #9
    sta $580B
    pla
    sta $580C
    iny
    txa
    clc
    adc #$40
    tax
    bne .m
    jmp JBTAIL
status:             ; status screen (A = $FD): HP palette, condensed words and the MP cells of
    ldx $7F         ;   member $7F; the words on job-name tiles the member's job does not use
    jsr hpp
    ora #11 * 4
    ldy #6
    sty $580A
    ldy #2
    sty $580B
    sta $580C
    lda $84
    pha
    lda $85
    pha
    ldx $7F
    ldy #0
    jsr mpcodes
    jsr mptiles
    jsr wslots
    lda #<WD
    sta $84
    lda #>WD
    sta $85
    lda #0
    sta $88
.u:
    jsr $FF00
    jsr inc1
    lda #5
    sta $87
.v:
    ldy $88
    lda WT,y
    jsr tadr
    ldy #0
.b:
    lda ($84),y
    sta $2007
    iny
    cpy #16
    bne .b
    lda $84
    clc
    adc #16
    sta $84
    bcc .n
    inc $85
.n:
    inc $88
    lda $88
    cmp #WN
    beq .d
    dec $87
    bne .v
    jsr fin
    jmp .u
.d:
    jsr fin
    lda #$A5
    sta WST
    jsr $FF00       ; the cells: words, then the MP row
    jsr inc1
    ldx #0
.w:
    lda CH,x
    sta $2006
    lda CL,x
    sta $2006
    ldy CK,x
    lda CN,x
    sta $87
.c:
    lda WT,y
    sta $2007
    iny
    dec $87
    bne .c
    inx
    cpx #7
    bne .w
    lda #$20
    sta $2006
    lda #$E4
    sta $2006
    ldy #0
.m:
    lda MPC,y
    sta $2007
    iny
    cpy #8
    bne .m
    jsr fin
    pla
    sta $85
    pla
    sta $84
    jmp JBTAIL
wslots:             ; WT = the tiles for the WN word tiles: 1, 2, .. skipping the job's
    ldx $7F         ;   (JTS / JTL by the job of member $7F)
    lda $6100,x
    tax
    lda JTS,x
    sta $86
    lda JTL,x
    sta $87
    ldy #0
.l:
    tya
    clc
    adc #1
    ldx $87
    beq .s
    cmp $86
    bcc .s
    clc
    adc $87
.s:
    sta WT,y
    iny
    cpy #WN
    bne .l
    rts
tadr:               ; PPU address of BG tile A (pattern table 0)
    pha
    lsr a
    lsr a
    lsr a
    lsr a
    sta $2006
    pla
    asl a
    asl a
    asl a
    asl a
    sta $2006
    rts
jkey:               ; job list: left / right (new press) turn the page (jobs 13-22 on page 2
    lda $20         ;   once available: $F38A >= 12); a turn puts the cursor on the first
    and #$03        ;   entry and sets MPG bit 7 (redraw)
    tax
    asl a
    asl a
    asl a
    asl a
    sta $86
    lda MPG
    and #$30
    cmp $86
    beq .x
    lda MPG
    and #$CF
    ora $86
    sta MPG
    txa
    beq .x
    lsr a
    bcs .rt
    lda MPG         ; left: back to page 1
    and #$03
    beq .x
    dec MPG
    jmp .f
.rt:
    lda MPG
    and #$03
    bne .x
    jsr $F38A
    cmp #12
    bcc .x
    inc MPG
.f:
    lda #0
    sta $78F0
    lda MPG
    ora #$80
    sta MPG
.x:
    jmp JBTAIL
jsel8:              ; the chosen job: cursor index + 12 on page 2 (was LDA $78F0 LSR LSR)
    lda $78F0
    lsr a
    lsr a
    sta $8F
    lda MPG
    and #$03
    beq .x
    lda $8F
    clc
    adc #12
    sta $8F
.x:
    jmp JBTAIL
jgpage:             ; job list copied to $7B01: on page 2 the job numbers + 12 (codes 1E / 1F
    lda MPG         ;   jj, character code 10 + level $48-$5D)
    and #$7F
    sta MPG
    and #$03
    beq .x
    ldx #0
.l:
    lda $7B01,x
    beq .x
    cmp #$1E
    beq .a
    cmp #$1F
    beq .a
    cmp #$14
    beq .k
    cmp #$15
    beq .k
    cmp #$10
    bcc .n
    cmp #$14
    bcs .n
    lda $7B02,x
    cmp #$48
    bcc .k
.a:
    lda $7B02,x
    clc
    adc #12
    sta $7B02,x
.k:
    inx
.n:
    inx
    bne .l
.x:
    jmp JBTAIL
mgkey:              ; magic list: left / right (new press, MPG bits 4-5 = last) turn the page
    lda $20         ;   (MPG bits 0-1, 3 pages); a change sets bit 7 (redraw)
    and #$03
    tax
    asl a
    asl a
    asl a
    asl a
    sta $86
    lda MPG
    and #$30
    cmp $86
    beq .x
    lda MPG
    and #$CF
    ora $86
    sta MPG
    txa
    beq .x
    lsr a
    lda MPG
    and #$03
    bcs .rt
    cmp #0
    beq .x
    dec MPG
    bne .f
    beq .f
.rt:
    cmp #2
    bcs .x
    inc MPG
.f:
    lda MPG
    ora #$80
    sta MPG
.x:
    jmp JBTAIL
mgpage:             ; magic list copied to $7B01: levels / MP / spells moved by 3 page levels;
    lda MPG         ;   a level past the 8th ends the text
    and #$03
    sta $86
    asl a
    adc $86
    sta $86         ; 3 * page (levels)
    asl a
    adc $86
    sta $87         ; 9 * page (spells)
    ldx #0
.l:
    lda $7B01,x
    beq .x
    cmp #$95        ; "L": the level line "Lv<d>"; past level 8: end here
    bne .c
    lda $7B03,x
    clc
    adc $86
    cmp #$89
    bcc .lv
    lda #0
    sta $7B01,x
    beq .x
.lv:
    sta $7B03,x
    inx
    inx
    inx
    bne .l
.c:
    cmp #$10
    bcc .n
    cmp #$14
    bcs .n
    lda $7B02,x     ; character code 10-13 xx: MP ($80-$8F) + 3 p, spells ($08-$1F) + 9 p
    cmp #$80
    bcc .sp
    clc
    adc $86
    sta $7B02,x
    bne .k
.sp:
    clc
    adc $87
    sta $7B02,x
.k:
    inx
.n:
    inx
    bne .l
.x:
    jmp JBTAIL
restore:            ; menu closed: the word tiles under the MP tiles back (from the font)
    lda #0          ;   (and the magic list's page back to the first; the GB runtime's
    sta MPG         ;   condensed-name tiles off: $580F)
    sta $580F
    lda WST         ; (status: the job-name tiles under its words first, from JDATA)
    cmp #$A5
    bne .nw
    lda #0
    sta WST
    lda $84
    pha
    lda $85
    pha
    jsr wslots
    lda #0
    sta $88
.ru:
    jsr $FF00
    jsr inc1
    lda #5
    sta $87
.rv:
    ldy $88
    lda WT,y
    jsr tadr
    lda WT,y        ; ($84) = JDATA + (t - 1) * 16
    sec
    sbc #1
    pha
    asl a
    asl a
    asl a
    asl a
    sta $84
    pla
    lsr a
    lsr a
    lsr a
    lsr a
    clc
    adc #>JDATA
    sta $85
    ldy #0
.rb:
    lda ($84),y
    sta $2007
    iny
    cpy #16
    bne .rb
    inc $88
    lda $88
    cmp #WN
    beq .rd
    dec $87
    bne .rv
    jsr fin
    jmp .ru
.rd:
    jsr fin
    pla
    sta $85
    pla
    sta $84
.nw:
    lda RST
    cmp #$A5
    beq .r
    jmp JBTAIL
.r:
    lda #0
    sta RST
    lda #$0E
    ldx #0
    ldy #$50
    jsr rest5
    lda #$0E
    ldx #80
    ldy #$A0
    jsr rest5
    lda #$0E
    ldx #160
    ldy #$F0
    jsr rest5
    jsr $FF00
    jsr inc1
    lda #$0F
    sta $2006
    lda #$40
    sta $2006
    ldx #0
.r2:
    lda RT2,x
    sta $2007
    inx
    cpx #48
    bne .r2
    lda #$0C
    sta $2006
    lda #$90
    sta $2006
.r3:
    lda RT2,x
    sta $2007
    inx
    cpx #64
    bne .r3
    lda #$0C
    sta $2006
    lda #$F0
    sta $2006
.r4:
    lda RT2,x
    sta $2007
    inx
    cpx #80
    bne .r4
    jsr fin
    jmp JBTAIL
rest5:              ; next vblank: 5 tiles (80 bytes) from RT1 + X to PPU A:Y
    pha
    jsr $FF00
    jsr inc1
    pla
    sta $2006
    sty $2006
    ldy #80
.l:
    lda RT1,x
    sta $2007
    inx
    dey
    bne .l
    jmp fin
tiles5:             ; next vblank: 5 tiles from MPT + X to PPU A:Y
    pha
    jsr $FF00
    jsr inc1
    pla
    sta $2006
    sty $2006
    ldy #5
    jsr tiles
    jmp fin
tiles:              ; Y tiles: 8 plane-0 bytes from MPT + X each, plane 1 $FF
    sty $86
.t:
    lda #8
    sta $85
.a:
    lda MPT,x
    sta $2007
    inx
    dec $85
    bne .a
    lda #$FF
    ldy #8
.b:
    sta $2007
    dey
    bne .b
    dec $86
    bne .t
    rts
inc1:
    lda $FF
    and #$FB
    sta $2000
    lda $2002
    rts
fin:
    lda $FF         ; (after the address writes: they set the scroll's nametable bits)
    sta $2000
    lda #0
    sta $2005
    sta $2005
    rts
NTH:
    .db $20, $21, $21, $22
NTL:
    .db $86, $26, $C6, $66
DTILE:
    .db $EF, $F0, $F1, $F2, $F3, $F4, $F5, $F6, $C9, $CF
CH:                 ; status words: PPU address, first word tile, count (STATUS_WORDS)
    .db $20, $20, $21, $21, $21, $21, $21
CL:
    .db $82, $A2, $02, $0B, $22, $2B, $42
conv:               ; $80-$82 -> digits from power X (0: 10^6) on, to DG + $85
    lda #0
    sta $86
.s:
    lda $80
    sec
    sbc P0,x
    sta $83
    lda $81
    sbc P1,x
    sta $84
    lda $82
    sbc P2,x
    bcc .n
    sta $82
    lda $84
    sta $81
    lda $83
    sta $80
    inc $86
    bne .s
.n:
    ldy $85
    lda $86
    sta DG,y
    inc $85
    inx
    cpx #7
    bcc conv
    rts
blank:              ; leading zeros DG + Y .. $87 - 1 -> blank (10)
    lda DG,y
    bne .x
    lda #10
    sta DG,y
    iny
    cpy $87
    bcc blank
.x:
    rts
P0:
    .db $40, $A0, $10, $E8, $64, $0A, $01
P1:
    .db $42, $86, $27, $03, $00, $00, $00
P2:
    .db $0F, $01, $00, $00, $00, $00, $00
GL:
'''


SMALL_GLYPHS = {   # 3 x 7 (owner-approved mock-up N5B: tools/gb3/mockup.py DIG3)
    '0': ["###", "#.#", "#.#", "#.#", "#.#", "#.#", "###"], '1': [".#.", "##.", ".#.", ".#.", ".#.", ".#.", "###"],
    '2': ["###", "..#", "..#", "###", "#..", "#..", "###"], '3': ["###", "..#", "..#", ".##", "..#", "..#", "###"],
    '4': ["#.#", "#.#", "#.#", "###", "..#", "..#", "..#"], '5': ["###", "#..", "#..", "###", "..#", "..#", "###"],
    '6': ["###", "#..", "#..", "###", "#.#", "#.#", "###"], '7': ["###", "..#", "..#", ".#.", ".#.", ".#.", ".#."],
    '8': ["###", "#.#", "#.#", "###", "#.#", "#.#", "###"], '9': ["###", "#.#", "#.#", "###", "..#", "..#", "###"],
    ' ': ["..."] * 7, 'G': ["###", "#..", "#..", "#.#", "#.#", "#.#", "###"],
    '/': ["..#", "..#", ".#.", ".#.", ".#.", "#..", "#.."],
    'C': ["###", "#..", "#..", "#..", "#..", "#..", "###"]}


def small_glyph_table():
    out = []
    for ch in '0123456789 GC':
        rows = [sum(0x80 >> x for x, v in enumerate(row) if v == '#') for row in SMALL_GLYPHS[ch]] + [0]
        out.append('    .db ' + ', '.join('$%02X' % b for b in rows))
    return '\n'.join(out) + '\n'


STATUS_WORDS = ['Proficiency', 'To next level', 'Strength', 'Agility', 'Stamina', 'Intelligence', 'Spirit']
STATUS_TEXT = ('{0E}{10:02}{14:07}{10:01}\n'                               # name, job
               'Lv{14:02}{10:3E}{14:07}[76][7A][79]{14:0A}{10:32}\n'       # level, EXP
               '{14:0F}{10:3D}\n'                                          # (Proficiency) value
               '{14:0B}{10:FF}\n'                                          # (To next level) value
               '{14:02}{10:30}/{10:31}{14:00}[77][79]\n'                   # HP
               '[78][79]\n'                                                # MP (cells: SMALLNUM)
               '{14:06}{10:38}{14:0F}{10:39}\n{14:06}{10:3A}{14:0F}{10:3B}\n{14:06}{10:3C}\n\n'
               'Attack {10:46}x{14:0D}{10:33}\nHit rate{14:0D}{10:42}\n'
               'Defense {10:47}x{14:0D}{10:34}\nEvasion rate{14:0D}{10:41}\n'
               'Magic defense{14:0D}{10:36}\nMagic evasion{14:0D}{10:40}')


MENU_TEXT[0x47] = STATUS_TEXT
# equip (owner-approved mock-up S4): name / Attack / Defense / the 5 slots / Remove Equipment in
# window 4 (1, 1, 20, 11), the item list one item per row in window $1C (1, 12, 20, 7)
MENU_TEXT[0x3E] = ('{0E}{10:02}\n{14:01}Attack‥{14:0E}{10:33}\n{14:01}Defense‥{14:0E}{10:34}\n'
                   '{15:01}{10:06}{10:43}\n{15:01}{10:07}{10:44}\n{15:01}{10:03}\n{15:01}{10:04}\n'
                   '{15:01}{10:05}\n{15:01}Remove Equipment')
EQUIP_MSGS = [0x6E, 0x6F] + list(range(0x3F, 0x47)) + list(range(0x5B, 0x66)) + [   # (+ item prompts,
    0x67, 0x68, 0x6B, 0x73, 0x74, 0x75, 0x3A, 0x71, 0x4E]                            #   magic, job, save messages)
# magic (owner-approved mock-up S3): header $24 (1, 1, 20, 4): name / Use Swap Item; list in
# window 8 (1, 4, 20, 15): per level "Lv<n>  MP cur/max" and its 3 spells one per row, 3 levels
# a page (bank 88 mgpage moves the copied text's level / MP / spell numbers by the page;
# left / right turn it)
MENU_TEXT[0x36] = '{0E}{14:01}{10:02}\n{15:01}Use{15:07}Swap{15:0D}Item'
MENU_TEXT[0x3C] = '{0E}' + '\n'.join(
    '{14:01}Lv%d{14:08}MP{14:0C}{10:%02X}/{10:%02X}\n' % (l + 1, 0x80 + l, 0x88 + l)
    + '\n'.join('{16:01}{10:%02X}' % (8 + 3 * l + k) for k in range(3)) for l in range(3))
MENU_TEXT[0x35] = '{0E}Item'
# job (owner's choice, mock-up J1): header window $0C (1, 1, 20, 4): name + job, Capacity;
# list window $0E (1, 4, 20, 15): "Lv  CP" and one job a row (name, level, CP cost), 12 a page
# (page 2: the same text with the job numbers + 12, bank 88 jgpage; left / right turn it)
MENU_TEXT[0x72] = '{0E}Not enough\nCapacity!'       # (was 25 columns with its leading blanks)
# save (owner's choice, mock-up V1): prompt window $10 (1, 1, 20, 5); the three files one line
# each in window $11 (1, 5, 20, 5) (files 2 / 3 print into it at rows 7 / 8: windows $12 / $13
# only place their text); the chosen file's party in window $1F (1, 9, 20, 10), drawn by
# `svdet` (in place of the slot sprites routine $8241) when the cursor moves
MENU_TEXT[0x25] = '{0E}{10:02}{14:07}Lv{10:3E}{14:0F}{0D}'
MENU_TEXT[0x7B] = '{0E}' + '\n'.join('{1%d:02}{14:07}Lv{1%d:3E}\n{14:01}[77][79]{14:03}{1%d:30}/{1%d:31}'
                                     % (m, m, m, m) for m in range(4))
MENU_TEXT[0x4C] = '{0E}This erases old\ndata.\n{15:08}Yes{15:0D}No'
MENU_TEXT[0x4D] = '{0E}Saving is\ncomplete.'
MENU_TEXT[0x48] = '{0E}{10:02}{14:07}{10:01}\nCapacity{14:0E}{08}'
MENU_TEXT[0x4A] = '{0E}{14:08}Lv{14:0C}CP\n' + '\n'.join(
    '{15:01}{1E:%02X}{14:08}{10:%02X}{14:0A}{1F:%02X}' % (j, 0x48 + j, j) for j in range(12))
MENU_TEXT[0x3D] = '{0E}' + '\n'.join('{17:01}{1A:%02X}{14:0F}{1C:%02X}' % (i, i) for i in range(32)) + '\n{17:01}{0F}'
MENU_TEXT[0x3B] = '{0E}' + '\n'.join('{1%d:02}{14:07}[77][79]{14:09}{1%d:30}/{1%d:31}' % (m, m, m) for m in range(4))
MENU_TEXT[0x2F] = '{0E}' + '\n'.join('{17:01}{20:%02X}{14:0F}{1C:%02X}' % (i, i) for i in range(32))
# shop buy list (window $18): one item a row, the price (6 digits) at column 10, no "Gil" (the Gil
# window shows it), the party sprites right of it
MENU_TEXT[0x20] = '{0E}' + '\n'.join('{16:01}{19:%02X}{14:0A}{21:%02X}' % (i, i) for i in range(8))


def status_words():
    """the condensed status words (owner-approved mock-up S5): NES tiles, counts"""
    from latin_font import packed_label, COND
    tiles = []; counts = []
    for w in STATUS_WORDS:
        for n in range(2, 9):
            t = packed_label(w, n, COND, fg=3, bg=2)
            if t: break
        tiles += t; counts.append(n)
    return b''.join(tiles), counts


def job_tiles():
    """tools/ff3/insert.py field_names: first tile and count of each job's condensed name
    (jobs 0-21; 0, 0 for names of 7 letters or fewer)"""
    import json
    from latin_font import packed_label, COND, TIGHT
    jobs = {e['id']: e['en'] for e in json.load(open('script/ff3/t8200.json'))}
    st, ln = [], []; tile_no = 1
    for j in range(22):
        name = jobs[226 + j].rstrip(' ')
        if len(name) <= 7: st.append(0); ln.append(0); continue
        for n in range(4, 8):
            t = packed_label(name, n, COND, fg=3, bg=2)
            if t: break
        else:
            for n in range(4, 8):
                t = packed_label(name, n, TIGHT, fg=3, bg=2)
                if t: break
        st.append(tile_no); ln.append(n); tile_no += n
    return st, ln, tile_no - 1


def mp_tiles():
    """plane 0 of the 20 MP tiles: "0/" .. "9/" then "0" .. "9" (3-px digits, 4 px a cell)"""
    g = lambda ch: [sum(0x80 >> x for x, v in enumerate(row) if v == '#') for row in SMALL_GLYPHS[ch]] + [0]
    out = bytearray()
    for d in '0123456789': out += bytes(a | (b >> 4) for a, b in zip(g(d), g('/')))
    for d in '0123456789': out += bytes(g(d))
    return bytes(out)


def main_menu(r):
    B3C, B3D, B88 = 0x3C, 0x3D, 88
    def find(bank, lo, hi, pat):
        b = bytes.fromhex(pat.replace(' ', '')); o = r.off(bank, lo)
        i = bytes(r.d[o:o + hi - lo]).find(b); assert i >= 0, pat
        assert bytes(r.d[o + i + 1:o + hi - lo]).find(b) < 0, pat
        return lo + i
    j = lambda a: '%02X %02X' % (a & 0xFF, a >> 8)
    # windows (bank 61 $AAF7 x, $AB1D y, $AB43 w, $AB69 h; ids 0-4 of the main menu)
    olds = {0xAAF7: '0117170911', 0xAB1D: '0101121a1a', 0xAB43: '160808080c', 0xAB69: '1b11090303'}
    for k, t in enumerate((0xAAF7, 0xAB1D, 0xAB43, 0xAB69)):
        b = bytearray.fromhex(olds[t])
        for w, rect in MENU_WINDOWS.items(): b[w] = rect[k]
        r.patch(B3D, t, olds[t], b.hex(), 'main menu windows (GB layout)')
    hp = r.module(MENU_HP_SRC, syms={'JBGO': JBGO, 'MPG': 0x5FFF, 'JMV2': 0x9698})
    assert hp['org'] + len(hp['bytes']) <= 0x960C + 16
    o = r.off(B3C, 0x95B2)
    r.d[o:o + len(hp['bytes'])] = hp['bytes']
    end = r.off(B3C, 0x961C)
    r.d[o + len(hp['bytes']):end] = b'\xea' * (end - o - len(hp['bytes']))
    r.mods.append(dict(hp, where=(B3C, 0x95B2 & 0x1FFF)))
    r.log.append((B3C, 0x95B2, 'main menu: HP palettes per member for the GB ($5809), menu mode on'))
    r.patch(B3D, 0xA693, '4C 65 F4', '4C ' + j(hp['labels']['mnuoff']), 'close menu: then GB menu mode off, word tiles back')
    font = lambda c: bytes(r.d[16 + FONT + c * 16:16 + FONT + c * 16 + 16])
    words = list(range(0xE5, 0xF7)) + [0xC9, 0xCF]
    assert all(font(c)[8:] == b'\xff' * 8 for c in words)
    rt = b''.join(font(c) for c in words)
    dbs = lambda lab, b: lab + ':\n' + ''.join('    .db ' + ', '.join('$%02X' % v for v in b[k:k + 16]) + '\n'
                                              for k in range(0, len(b), 16))
    wd, wc = status_words()
    js, jl, jt = job_tiles()
    wn = sum(wc)
    assert wn + max(jl) <= jt, (wn, jt)            # (the words fit on job tiles beside any job)
    jd = 0x8200                                     # insert.py: JDATA (bank 88), the job tiles
    assert r.d[r.off(B88, jd):r.off(B88, jd) + 16] == bytes(r.d[r.off(B88, jd):r.off(B88, jd) + 16])
    ck = [sum(wc[:i]) for i in range(len(wc))]
    tabs = dbs('WD', wd) + dbs('JTS', bytes(js)) + dbs('JTL', bytes(jl)) + dbs('CK', bytes(ck)) + dbs('CN', bytes(wc))
    sm = r.module(SMALLNUM_SRC + small_glyph_table() + dbs('MPT', mp_tiles()) + dbs('RT1', rt[:240])
                  + dbs('RT2', rt[240:]) + tabs, syms={'JBTAIL': JBTAIL, 'SQ': 0x801C, 'WN': wn, 'JDATA': jd})
    o = r.off(B88, sm['org'])
    assert sm['org'] + len(sm['bytes']) <= 0xA000
    assert set(r.d[o:o + len(sm['bytes'])]) == {0xFF}
    r.d[o:o + len(sm['bytes'])] = sm['bytes']
    r.mods.append(dict(sm, where=(B88, sm['org'] & 0x1FFF)))
    r.patch(B88, 0x8004, '4C 1C 80', '4C ' + j(sm['labels']['disp2']), 'job bank dispatch: smallnum (Y = 12, A = $FF)')
    r.patch(B3D, 0xA589, 'A2 03 A9 33 20 66 A6 A2 04 A9 34 20 66 A6',
            'A2 03 A9 33 20 66 A6 A0 0C A9 FF 20 ' + j(JBGO), 'main menu: Gil + Capacity window, 4-px digits')
    # status screen (owner-approved mock-up S5): window $1D at (1, 1, 20, 18), camera (8, 8),
    # no label window, no class sprite; the condensed words and the MP digits from bank 88
    r.patch(B3D, 0xAAF7 + 0x1D, '01', '01', 'status window x'); r.patch(B3D, 0xAB1D + 0x1D, '01', '01', 'status window y')
    r.patch(B3D, 0xAB43 + 0x1D, '1E', '14', 'status window: 20 wide')
    r.patch(B3D, 0xAB69 + 0x1D, '1C', '12', 'status window: 18 high')
    r.patch(B3D, 0xA841, '20 6F 95', '20 ' + j(hp['labels']['stcam']), 'status: GB camera (8, 8)')
    r.patch(B3D, 0xA86B, 'A2 1C 20 F1 AA', 'EA EA 4C ' + j(hp['labels']['stpost']), 'status: words + MP digits, no label window')
    r.patch(B3D, 0xA852, '20 29 81', 'EA EA EA', 'status: no class sprite')
    # equip: its own windows (4 and $1C: no longer opened by the main menu / status), camera
    # (8, 8) through stcam, no class sprite
    for t, k in ((0xAAF7, 0), (0xAB1D, 1), (0xAB43, 2), (0xAB69, 3)):
        r.d[r.off(B3D, t + 4)] = (1, 1, 20, 11)[k]
        r.d[r.off(B3D, t + 0x1C)] = (1, 12, 20, 7)[k]
    r.log.append((B3D, 0xAAF7, 'equip windows 4 / $1C'))
    for t, k in ((0xAAF7, 0), (0xAB1D, 1), (0xAB43, 2), (0xAB69, 3)):
        r.d[r.off(B3D, t + 0x1E)] = (1, 12, 20, 4)[k]
    r.patch(B3C, 0x9BBF, '20 6F 95', '20 ' + j(hp['labels']['stcam']), 'equip: GB camera (8, 8)')
    r.patch(B3C, 0x9BE1, 'A2 0A', 'A2 04', 'equip: window 4')
    r.patch(B3C, 0x9C0A, 'A2 0B', 'A2 1C', 'equip: item list window $1C')
    for a in (0x9BF3, 0x9C26):
        r.patch(B3C, a, '20 5B 9D', 'EA EA EA', 'equip: no class sprite')
    # item screen (owner-approved mock-ups S1 / S2): label 5 (1, 1, 20, 3), list 6 (1, 3, 20,
    # 16) one item a row, the party window 7 (1, 12, 20, 7) only while a target is chosen
    # (stuse; FF3 redraws the list after it), the prompt window $15 (1, 1, 20, 4) over the label
    for w, rect in ((5, (1, 1, 20, 3)), (6, (1, 3, 20, 16)), (7, (1, 12, 20, 7)), (0x15, (1, 9, 20, 4))):
        for t, k in ((0xAAF7, 0), (0xAB1D, 1), (0xAB43, 2), (0xAB69, 3)):
            r.d[r.off(B3D, t + w)] = rect[k]
    r.log.append((B3D, 0xAAF7, 'item windows 5 / 6 / 7 / $15'))
    r.patch(B3C, 0x9ECC, '20 6F 95 20 28 A3', '20 ' + j(hp['labels']['stcam']) + ' EA EA EA',
            'item: GB camera (8, 8), no party window until a target is chosen')
    a = find(B3C, 0x9880, 0x98A0, 'A6 8F A9 00 9D 00 7C 60')
    st = r.module('''
    org $%04X
stmr:               ; (the unused "delete spell" routine) magic list redrawn with its frame,
    lda #0          ;   the party window's palettes undone
    sta $5808
    jmp $AAF1
''' % a)
    assert len(st['bytes']) == 8
    r.d[r.off(B3C, a):r.off(B3C, a) + 8] = st['bytes']
    r.mods.append(dict(st, where=(B3C, a & 0x1FFF)))
    cl = r.module('''
    org $9D5B
stcl:               ; (equip's class sprite routine, no longer called) item menu redrawn after
    lda #0          ;   a target choice: the party window's HP palettes undone ($5808 = 0
    sta $5808       ;   rebuilds rows with set palettes)
    jmp $F44B       ; close menu 1 (the call this replaces)
''')
    assert r.d[r.off(B3C, 0x9D5B):r.off(B3C, 0x9D5B) + 4] == bytes.fromhex('a9d88540')
    r.d[r.off(B3C, 0x9D5B):r.off(B3C, 0x9D5B) + 8] = cl['bytes']
    r.mods.append(dict(cl, where=(B3C, 0x9D5B & 0x1FFF)))
    r.patch(B3D, 0xAA8E, '20 4B F4', '20 ' + j(cl['labels']['stcl']), 'item menu redraw: party window palettes undone')
    r.patch(B3D, 0xAA93, '20 A0 AA', '20 F1 AA', 'item menu redraw: the list window with its frame (the party window covered it)')
    r.patch(B3D, 0xA74F, '01 17 00 00 0F 17 00 00 01 1A 00 00 0F 1A 00 00',
            '00 0D 00 00 00 0E 00 00 00 0F 00 00 00 10 00 00', 'select character: hand at each line of window 7')
    for bank, a in ((B3C, 0x9F08), (B3C, 0x9F45), (B3D, 0xA733)):
        r.patch(bank, a, '20 00 80', 'EA EA EA', 'item: no class sprites')
    # magic: windows, no class sprites / party window until a target, one spell a cursor step
    for w, rect in ((8, (1, 4, 20, 15)), (0x24, (1, 1, 20, 4))):
        for t, k in ((0xAAF7, 0), (0xAB1D, 1), (0xAB43, 2), (0xAB69, 3)):
            r.d[r.off(B3D, t + w)] = rect[k]
    r.log.append((B3D, 0xAAF7, 'magic windows 8 / $24'))
    a = find(B3C, 0x9761, 0x9770, '20 85 A6 20 6F 95')
    r.patch(B3C, a + 3, '20 6F 95', '20 ' + j(hp['labels']['stcam']), 'magic: GB camera (8, 8)')
    a = find(B3C, 0x9761, 0x97A0, '20 98 D1 20 28 A3')
    r.patch(B3C, a + 3, '20 28 A3', 'EA EA EA', 'magic: no party window until a target is chosen')
    a = find(B3C, 0x9761, 0x97A0, 'A2 06 20 F1 AA A9 3C')
    r.patch(B3C, a, 'A2 06', 'A2 08', 'magic: list window 8')
    a = find(B3C, 0x9761, 0x97B0, 'A2 06 20 A6 AA A9 3C')
    r.patch(B3C, a, 'A2 06 20 A6 AA', 'A2 08 20 ' + j(st['labels']['stmr']), 'magic: list window 8, redrawn with its frame (party window palettes undone)')
    for a in (find(B3C, 0x979C, 0x97C0, 'A9 03 20 00 80'), find(B3C, 0x97D9, 0x97F0, 'A9 03 20 00 80')):
        r.patch(B3C, a + 2, '20 00 80', 'EA EA EA', 'magic: no class sprites')
    a = find(B3C, 0x97D9, 0x97F0, 'A9 0C 20 D9 91')
    r.patch(B3C, a, 'A9 0C 20 D9 91', 'A9 04 20 ' + j(hp['labels']['mmove']), 'magic: one spell a step, left / right turn the page')
    r.patch(B3D, 0xA717, '8D F0 79', '20 ' + j(hp['labels']['stsel']), 'select character: the party window first')
    # job screen
    for w, rect in ((0x0C, (1, 1, 20, 4)), (0x0E, (1, 4, 20, 15)), (0x20, (1, 8, 20, 6))):
        for t, k in ((0xAAF7, 0), (0xAB1D, 1), (0xAB43, 2), (0xAB69, 3)):
            r.d[r.off(B3D, t + w)] = rect[k]
    r.log.append((B3D, 0xAAF7, 'job windows $0C / $0E, message $20'))
    r.patch(B3C, 0x9635, '20 85 A6 20 6F 95', '20 85 A6 20 ' + j(hp['labels']['stcam']), 'job: GB camera (8, 8)')
    r.patch(B3C, 0x964F, 'A2 0D 20 F1 AA A9 49 20 78 A6', 'EA EA EA EA EA EA EA EA EA EA', 'job: Capacity in the header (no CP window)')
    r.patch(B3C, 0x965E, 'A2 0E 20 A6 AA', 'A2 0E 20 ' + j(st['labels']['stmr']), 'job list redrawn with its frame (after a message)')
    r.patch(B3C, 0x966F, 'A9 08 20 A3 91', 'A9 04 20 ' + j(hp['labels']['jmove']), 'job: one job a step, left / right turn the page')
    for a in (0x9674, 0x96E2):
        r.patch(B3C, a, '20 98 96', 'EA EA EA', 'job: no class sprite')
    jm = r.module('''
    org $9698
jmv2:               ; (the job menu's class sprite routine, no longer called) page turned:
    lda MPG         ;   the job list redrawn
    bpl .r
    ldx #$0E
    lda #$4A
    jmp $A875
.r:
    rts
''', syms={'MPG': 0x5FFF})
    assert len(jm['bytes']) == 13 and r.d[r.off(B3C, 0x9698)] == 0xA9
    r.d[r.off(B3C, 0x9698):r.off(B3C, 0x9698) + 13] = jm['bytes']
    r.mods.append(dict(jm, where=(B3C, 0x9698 & 0x1FFF)))
    js = r.module('''
    org $96A5
jsel:               ; the chosen job (bank 88 jsel8: + 12 on page 2)
    ldy #12
    lda #$F6
    jsr JBGO
''', syms={'JBGO': JBGO})
    assert bytes(r.d[r.off(B3C, 0x96A5):r.off(B3C, 0x96A5) + 7]).hex() == 'adf0784a4a858f'
    r.d[r.off(B3C, 0x96A5):r.off(B3C, 0x96A5) + 7] = js['bytes']
    r.mods.append(dict(js, where=(B3C, 0x96A5 & 0x1FFF)))
    mp = r.module('''
    org $8ADE
mpage:              ; (the unused 2-digit + percent routine) character string copied ($A87A:
    pha             ;   JSR $D1B1): the magic / job list's page (bank 88, A = the string)
    jsr $D1B1
    pla
    cmp #$3C
    beq .m
    cmp #$4A
    bne .r
.m:
    ldy #12
    jmp JBGO
.r:
    rts
''', syms={'JBGO': JBGO})
    assert len(mp['bytes']) <= 24 and bytes(r.d[r.off(B3C, 0x8ADE):r.off(B3C, 0x8ADE) + 2]).hex() == 'a581'
    r.d[r.off(B3C, 0x8ADE):r.off(B3C, 0x8ADE) + len(mp['bytes'])] = mp['bytes']
    r.mods.append(dict(mp, where=(B3C, 0x8ADE & 0x1FFF)))
    r.patch(B3D, 0xA87A, '20 B1 D1', '20 ' + j(mp['labels']['mpage']), 'character string: the magic / job list page')
    # save screen (and the title's load menu: the same slot windows)
    for w, rect in ((0x10, (1, 1, 20, 5)), (0x11, (1, 5, 20, 5)), (0x12, (1, 6, 20, 5)), (0x13, (1, 7, 20, 5)),
                    (0x1F, (1, 9, 20, 10))):
        for t, k in ((0xAAF7, 0), (0xAB1D, 1), (0xAB43, 2), (0xAB69, 3)):
            r.d[r.off(B3D, t + w)] = rect[k]
    r.log.append((B3D, 0xAAF7, 'save windows $10-$13, $1F'))
    r.patch(B3D, 0xA8C0, '20 85 A6 20 6F 95', '20 85 A6 20 ' + j(hp['labels']['stcam']), 'save: GB camera (8, 8)')
    for a in (0xA9B4, 0xA9C0):
        r.patch(B3D, a + 2, '20 F1 AA', '20 A6 AA', 'save files 2 / 3: text in the list window (no window of their own)')
    r.patch(B3D, 0xAA3B, '01 07 00 00 01 0F 00 00 01 17 00 00', '00 06 00 00 00 07 00 00 00 08 00 00',
            'save / load: the hand at each file line')
    r.patch(B3C, 0x8B43, 'A2 19 A5 5D 9D 80 07 E8 A5 5E 9D 80 07 E8 A5 5F 9D 80 07',
            'A2 0F A5 5D 9D A0 07 E8 A5 5E 9D A0 07 E8 A5 5F 9D A0 07', 'save count: in the line at column 15 (one-row text)')
    lb = r.module('''
    org $A984
svlab:              ; (was the "Save" label window) the detail window's file: none yet
    lda #$FF
    sta $5FFF
    nop
    nop
    nop
    nop
    nop
''')
    assert bytes(r.d[r.off(B3D, 0xA984):r.off(B3D, 0xA984) + 10]).hex() == 'a20f20f1aaa938206ba6'
    r.d[r.off(B3D, 0xA984):r.off(B3D, 0xA984) + 10] = lb['bytes']
    r.mods.append(dict(lb, where=(B3D, 0xA984 & 0x1FFF)))
    sv = r.module('''
    org $8241
svdet:              ; (was: the slot's character sprites) A = the chosen file (0-2): when it
    cmp MPG         ;   changes, window $1F shows that file's party (the slot copied to $6000
    beq .r          ;   and back from FF3's backup at $7400, as the slot windows are drawn)
    sta MPG
    ldx #$1F
    jsr $AAF1
    ldx MPG
    lda $62         ; (valid files: bit 2 file 1, bit 1 file 2, bit 0 file 3)
    cpx #2
    beq .b
    lsr a
    cpx #1
    beq .b
    lsr a
.b:
    and #1
    beq .r
    txa
    asl a
    asl a
    clc
    adc #$64
    jsr $A9F9
    lda #$7B
    jsr $A678
    sec
    jsr $AA18
.r:
    rts
svdet1:             ; after saving (A = file + 1): that file valid ($62: bit 2 file 1 .. bit 0
    ldx #$FF        ;   file 3) and its party again (new data)
    stx MPG
    tax
    lda #8
.v:
    lsr a
    dex
    bne .v
    ora $62
    sta $62
    lda $79F0
    lsr a
    lsr a
    and #3
    jmp svdet
svcam:              ; save screen shown (FF3's graphics load switched rendering off / on):
    lda #8          ;   its camera (8, 8), then $959F (update ppu registers)
    sta $5802
    sta $5803
    jmp $959F
''', syms={'MPG': 0x5FFF})
    assert len(sv['bytes']) <= 0x82A8 - 0x8241 and bytes(r.d[r.off(B3C, 0x8241):r.off(B3C, 0x8241) + 2]).hex() == 'd00c'
    r.d[r.off(B3C, 0x8241):r.off(B3C, 0x8241) + len(sv['bytes'])] = sv['bytes']
    r.mods.append(dict(sv, where=(B3C, 0x8241 & 0x1FFF)))
    a = find(B3D, 0xA8C6, 0xA8F0, 'A9 02 8D 14 40 20 9F 95')
    r.patch(B3D, a + 5, '20 9F 95', '20 ' + j(sv['labels']['svcam']), 'save: GB camera once shown')
    end = r.off(B3C, 0x82A8)
    o = r.off(B3C, 0x8241) + len(sv['bytes'])
    r.d[o:end] = b'\xea' * (end - o)                  # (the old routine's rest: dead)
    a = find(B3D, 0xAA67, 0xAA90, '18 69 11 AA 20 F1 AA A9 25 20 6B A6 68 18 69 01 20 00 80')
    r.patch(B3D, a + 4, '20 F1 AA', '20 A6 AA', 'saved file: its line again in the list window')
    r.patch(B3D, a + 16, '20 00 80', '20 ' + j(sv['labels']['svdet1']), 'saved file: the detail window (no class sprites)')
    r.patch(B3D, 0xA705, '01 05 00 00 01 0B 00 00 01 11 00 00 01 17 00 00',
            '02 01 00 00 02 05 00 00 02 09 00 00 02 0D 00 00', 'character select: hand at each name (GB rows)')
    for a in (0xA5AC, 0xA6D0):
        r.patch(B3D, a, 'A9 00 20 00 80 A9 00 20 CB 80', 'A9 00 EA EA EA A9 00 EA EA EA',
                'main menu: no class sprites, no guest sprite')
    # owner: "the HP and MP font is off alignment with the other fonts": FF3's label glyphs
    # (L V E H M P) use pixel rows 1-7, the English font rows 0-6: moved up one row (the menu
    # screens draw these tiles from the font block); the level's "LV" in the English letters
    # "Lv" (as the battle magic list)
    for c in (0x5E, 0x5F, 0x76, 0x77, 0x78, 0x79):
        o = 16 + FONT + c * 16
        g = r.d[o:o + 16]
        assert g[0] == 0 and g[8:] == b'\xff' * 8, (hex(c), g.hex())
        r.d[o:o + 8] = g[1:8] + b'\0'
    r.log.append((0, FONT, 'label glyphs L V E H M P one row up (English font rows)'))
    r.patch(0x7F, 0xF2AC, 'A9 5E 9D A0 07 A9 5F', 'A9 95 9D A0 07 A9 B9', 'level label: "Lv" in the English font')


# opening prophecy (GB): the two narration pages (t8000 0, 1) as five of up to 16 lines, centred in
# 18 columns (window $25 from column 2: NES columns 2-19) and vertically in the GB view (camera
# x 8 / y 8: NES columns 1-20, rows 1-18); pages 2, 3, 5 in the empty dialogue entries 125, 130, 188 (unused, also
# empty in the Japanese). Source lines (each a unit, as the NES's centred()) per page:
PROPHECY_PAGES = [(0, (1, 2)), (0, (3, 4, 5, 6)), (0, (7, 8, 9, 10, 11, 12, 13)),
                  (1, (3, 4)), (1, (5, 6, 7))]
PROPHECY_IDS = (0, 125, 130, 1, 188)
PROPHECY_W = 18


def prophecy_text(rows, ins):
    """{t8000 id: GB page text} (rows: the script's t8000 entries; ins: tools/ff3/insert.py)"""
    src = {e['id']: (e['en'] or '').split('\n') for e in rows if e['id'] in (0, 1)}
    out = {}
    for (sid, ls), tid in zip(PROPHECY_PAGES, PROPHECY_IDS):
        body = '\n'.join(src[sid][k] for k in ls if k < len(src[sid]))
        lines = ins.centred(body, PROPHECY_W).split('\n')
        assert len(lines) <= 16, (tid, len(lines))
        out[tid] = '\n' * ((18 - len(lines)) // 2) + '\n'.join(lines)   # (text from NES row 1: view rows 1-18)
    return out


def prophecy(r):
    """five pages (loop count 2 -> 5, page -> text id table, the GB camera at each page), the
    fade-in up to the last row in view; the hidden developer message (L3A_980F, reached by a
    button combination on the title: undisclosed code, release checklist) off, its routine's
    space for the table"""
    B3A = 0x3A
    def find(bank, lo, hi, pat):
        b = bytes.fromhex(pat.replace(' ', '')); o = r.off(bank, lo)
        i = bytes(r.d[o:o + hi - lo]).find(b); assert i >= 0, pat
        return lo + i
    j = lambda v: '%02X %02X' % (v & 0xFF, v >> 8)
    a = find(B3A, 0x8780, 0x8798, 'A5 08 20 24 C0 20 D3 87 E6 08 A5 08 C9 02')
    m = r.module('''
    org $980F
devmsg:             ; (the developer message: off)
    rts
ptext:              ; prophecy page A (0-4): its text id, the GB camera (8, 8)
    tax
    lda #8
    sta $5802
    lda #8
    sta $5803
    lda PT,x
    jmp $C024
PT: .db %s
''' % ', '.join(str(v) for v in PROPHECY_IDS))
    o = r.off(B3A, 0x980F)
    assert bytes(r.d[o:o + 3]) == bytes.fromhex('200CC0')
    d0 = find(B3A, 0x9900, 0x999C, 'C0 30 0C 03 80 40 20 10 08 04 02 01')   # (its glyph data after the code)
    r.d[o:o + len(m['bytes'])] = m['bytes']
    r.d[o + len(m['bytes']):r.off(B3A, d0)] = b'\xea' * (d0 - 0x980F - len(m['bytes']))
    r.mods.append(dict(m, where=(B3A, 0x980F & 0x1FFF)))
    r.patch(B3A, a + 2, '20 24 C0', '20 ' + j(m['labels']['ptext']), 'prophecy: page -> text id, GB camera')
    r.patch(B3A, a + 12, 'C9 02', 'C9 %02X' % len(PROPHECY_IDS), 'prophecy: %d pages' % len(PROPHECY_IDS))
    b = find(B3A, 0x87D3, 0x87E6, '69 08 85 62 C9 F8')
    r.patch(B3A, b + 4, 'C9 F8', 'C9 E8', 'prophecy: fade-in up to NES row 19 (the GB view)')
    r.log.append((B3A, 0x980F, 'developer message off; prophecy page table'))


def name_entry(r):
    """name entry on 20 x 18: name window $22 (4, 0, 20, 4) with the character sprite inside,
    letter grid $23 (3, 4, 22, 14): 10 letters a row two columns apart (no middle gap; the cursor
    table follows the string's choice codes), camera (32, 0) - the grid's frames just past
    the screen edge"""
    B3D = 0x3D
    j = lambda v: '%02X %02X' % (v & 0xFF, v >> 8)
    # (the title's load menu: "New Game" in window $0C (1, 1, 20, 4, shared with the job
    # header), Text Speed beside it in window $21, the files below as on the save screen)
    for w, geo in ((0x22, (4, 0, 20, 4)), (0x23, (3, 4, 22, 14)), (0x21, (11, 1, 10, 4))):
        for t, k in ((0xAAF7, 0), (0xAB1D, 1), (0xAB43, 2), (0xAB69, 3)):
            r.d[r.off(B3D, t + w)] = geo[k]
    m = r.module('''
    org $B886
nmspr:              ; (was: x / y of the character sprite) camera and sprite position: bank 88
    ldy #12
    lda #$F5
    jsr $5D4E
    jmp $8236
    nop
''')
    o = r.off(B3D, 0xB886)
    assert bytes(r.d[o:o + 11]) == bytes.fromhex('A9A08540A92085414C3682'), bytes(r.d[o:o + 11]).hex()
    r.d[o:o + len(m['bytes'])] = m['bytes']
    r.mods.append(dict(m, where=(B3D, 0xB886 & 0x1FFF)))
    o = r.off(B3D, 0xB9CA)
    seg = bytes(r.d[o:o + 0x30])
    k = seg.find(bytes.fromhex('A9279D0002')); assert k >= 0
    r.patch(B3D, 0xB9CA + k, 'A9 27', 'A9 0F', 'name cursor: y (name window at row 0)')
    k = seg.find(bytes.fromhex('186948')); assert k >= 0
    r.patch(B3D, 0xB9CA + k, '18 69 48', '18 69 30', 'name cursor: x (name from NES column 6)')
    a = 0xBB7D + bytes(r.d[r.off(B3D, 0xBB7D):r.off(B3D, 0xBB7D) + 16]).find(bytes.fromhex('A9208D0620A97B'))
    r.patch(B3D, a + 5, 'A9 7B', 'A9 73', 'title: text speed digit at NES column 19 (in window $21)')
    r.log.append((B3D, 0xB895, 'name entry: GB layout'))


def shop(r):
    """shops on 20 x 18 (camera (8, 8)): title $14 (1, 1, 8, 4) and Gil $17 (8, 1, 13, 4) side by
    side, options $16 (1, 5, 20, 4), message $15 (1, 9, 20, 4) as before, buy list $18 and sell
    list $19 (1, 9, 20, 10): one item a row (8, as the NES's pages), the price in place of the
    NES's second row; the party sprites (who can equip) in the list window's right columns"""
    B3D = 0x3D
    for w, geo in ((0x14, (1, 1, 8, 4)), (0x17, (8, 1, 13, 4)), (0x16, (1, 5, 20, 4)),
                   (0x18, (1, 9, 20, 10)), (0x19, (1, 9, 20, 10))):
        for t, k in ((0xAAF7, 0), (0xAB1D, 1), (0xAB43, 2), (0xAB69, 3)):
            r.d[r.off(B3D, t + w)] = geo[k]
    m = r.module('''
    org $B369
shopini:            ; shop screen: as the NES ($FD / $FF / $2000), then bank 88 shopcam (camera
    lda #$88        ;   (8, 8), scroll 0, rendering on)
    sta $FD
    sta $FF
    sta $2000
    ldy #12
    lda #$F4
    jsr $5D4E
    rts
''')
    o = r.off(B3D, 0xB369)
    assert bytes(r.d[o:o + 23]) == bytes.fromhex('A98885FD85FF8D0020A9008D05208D0520A91E8D012060'), bytes(r.d[o:o+23]).hex()
    r.d[o:o + len(m['bytes'])] = m['bytes']
    r.d[o + len(m['bytes']):o + 23] = b'\xea' * (23 - len(m['bytes']))
    r.mods.append(dict(m, where=(B3D, 0xB369 & 0x1FFF)))
    o = r.off(B3D, 0xB335)                               # party sprites: x 144, y 72 + 16 k (24 px tall: overlapping, all on screen)
    seg = bytes(r.d[o:o + 0x34])
    for k, (y0, y1) in enumerate(((0x60, 0x48), (0x80, 0x58), (0xA0, 0x68), (0xC0, 0x78))):
        i = seg.find(bytes.fromhex('A9D88540A9%02X8541' % y0)); assert i >= 0, k
        r.patch(B3D, 0xB335 + i, 'A9 D8 85 40 A9 %02X 85 41' % y0, 'A9 90 85 40 A9 %02X 85 41' % y1,
                'shop: party sprite %d in the list window' % k)
    r.log.append((B3D, 0xAF1F, 'shops: GB layout'))


MENU_TEXT_NAME_GRID = {0x0C: 0x0B, 0x0E: 0x0D, 0x10: 0x0F, 0x12: 0x11, 0x14: 0x13}


def ending(r):
    """the crystal cutscene texts (opening credits after the Wind Crystal, the ending's scrolling
    pages; bank 1F L1F_A53D, page pointers $A5DF, pages in insert.py's EPI_BANK) on 20 x 18: the
    cutscenes at camera (48, 48) (NES cols 6-25, rows 6-23: the staff lines as they are), the title
    from row 7 (row 5 is above the view), the eight story pages wrapped at 18 and centred (opening
    pages <= 8 rows, ending pages <= 12 rows: what L1F_A581 / L1F_B212 copy).
    The ending scrolls each page in from the other nametable (horizontal mirroring, 480 lines);
    the GB map has 32 rows, so a page written there would land on the rows in view. On the GB
    the ending keeps vertical mirroring (one nametable, the scroll wraps at 240 as the runtime
    shows it) and every page goes to rows 18-29, out of the view (camera (48, 0): rows 0-17)
    while it is written; it scrolls in from the bottom as on the NES"""
    import importlib.util, json, textwrap
    spec = importlib.util.spec_from_file_location('ff3insert', os.path.join(HERE, '..', 'ff3', 'insert.py'))
    ins = importlib.util.module_from_spec(spec); spec.loader.exec_module(ins)
    B1F, EPI = 0x1F, ins.EPI_BANK
    rd = lambda b, a: r.d[r.off(b, a)]
    ptr = [rd(B1F, 0xA5DF + 2 * i) | rd(B1F, 0xA5E0 + 2 * i) << 8 for i in range(17)]
    assert ptr[0] == 0x8000
    def page(p):
        o = r.off(EPI + (p >= 0xA000), p); out = bytearray()
        while r.d[o]: out.append(r.d[o]); o += 1
        return bytes(out) + b'\x00'
    pages = [page(p) for p in ptr[:9]]                       # (title, staff: as they are)
    for k, e in enumerate(json.load(open('script/ff3/epilogue.json'))):
        para = ' '.join(re.sub(r'^\{COL:..\}', '', l).strip() for l in e['en'].split('\n') if l.strip())
        lines = textwrap.wrap(para, 18)
        assert len(lines) <= (8 if k < 3 else 12), (e['id'], lines)
        out = bytearray()
        for n, l in enumerate(lines):
            b = ins.enc(l); assert len(b) <= 18, l
            if n: out.append(0x01)
            out += bytes([0x02, 6 + (20 - len(b)) // 2]) + b
        if k >= 3: out = bytes([0x01]) * ((12 - len(lines)) // 2) + out   # (centred in rows 18-29)
        pages.append(bytes(out) + b'\x00')
    a = 0x8000; data = bytearray()
    for i, pg in enumerate(pages):
        r.d[r.off(B1F, 0xA5DF + 2 * i)] = a & 0xFF; r.d[r.off(B1F, 0xA5E0 + 2 * i)] = a >> 8
        data += pg; a += len(pg)
    assert len(data) + 255 <= 0x4000
    r.d[r.off(EPI, 0x8000):r.off(EPI, 0x8000) + len(data)] = data   # (EPI and EPI + 1 follow)
    r.log.append((EPI, 0x8000, 'ending: pages wrapped at 18 (%d bytes)' % len(data)))
    # the title (text 0) and its clear (entry 2) from row 7
    r.patch(B1F, 0xA5A6, '08 05 00', '08 07 00', 'ending: title from NES row 7')
    r.patch(B1F, 0xA5AC, '08 05 02', '08 07 02', 'ending: title clear from NES row 7')
    # camera (48, 48) for the opening and the ending cutscenes: a stub in the bank's free end
    m = r.module('''
    org $BFD8
ecam:                ; opening: camera (48, 48)
    lda #48
    sta $5803
    bne ecx
ecam2:               ; ending: camera (48, 0)
    lda #0
    sta $5803
ecx:
    lda #48
    sta $5802
    jmp $A16C
elock:               ; end credits (nametable 1 shown): the GB map shows nametable 1 only
    lda #2
    sta $580D
    lda #$01
    sta $CC
    rts
''')
    o = r.off(B1F, 0xBFD8)
    assert len(m['bytes']) <= 31 and not any(r.d[o:o + 31])
    r.d[o:o + len(m['bytes'])] = m['bytes']
    r.mods.append(dict(m, where=(B1F, 0xBFD8 & 0x1FFF)))
    r.patch(B1F, 0xA0A4, '20 6C A1', '20 D8 BF', 'opening cutscene: GB camera (48, 48)')
    # the final ending (cast, staff credits with a job sprite each side at NES x 47-207): camera
    # (47, 45), its stub over the Japanese pages' old place ($A601-$A931, dead since insert.py
    # moved the pages to EPI_BANK)
    m3 = r.module('''
    org $A601
ecam3:
    lda #47
    sta $5802
    lda #45
    sta $5803
    jmp $A16C
''')
    o = r.off(B1F, 0xA601)
    r.d[o:o + len(m3['bytes'])] = m3['bytes']
    r.mods.append(dict(m3, where=(B1F, 0xA601 & 0x1FFF)))
    r.patch(B1F, 0xA012, '20 6C A1', '20 01 A6', 'final ending: GB camera (47, 45)')
    r.patch(B1F, 0xB94A, 'A9 01 85 CC', '20 %02X BF EA' % (m['labels']['elock'] & 0xFF),
            'end credits: GB map locked to nametable 1')
    r.patch(B1F, 0xA009, '20 6C A1', '20 %02X BF' % (m['labels']['ecam2'] & 0xFF), 'ending cutscene: GB camera (48, 0)')
    for n in range(13, 19):                                   # ending pages: rows 18-29
        r.patch(B1F, 0xA5A6 + 3 * n + 1, '08', '12', 'ending page %d: NES rows 18-29' % (n - 13))
    if os.environ.get('GB3_TEST_END'):                        # (test builds: event $DB -> the ending)
        r.patch(B1F, 0xA000, '4C A4 A0', '4C 12 A0', 'TEST: the prologue event runs the ending')
    o = r.off(B1F, 0xB146); i = bytes(r.d[o:o + 0x40]).find(bytes.fromhex('207D5CA901'))
    assert i > 0
    r.patch(B1F, 0xB146 + i, '20 7D 5C', '20 83 5C', 'ending: vertical mirroring kept (one nametable)')


def apply(data):
    """English NES ROM bytes -> (GB-layout ROM bytes, code modules for tools/gb3/ff3src.py)"""
    r = Rom(data)
    battle(r)
    battle_messages(r)
    magic_rows(r)
    field(r)
    main_menu(r)
    name_entry(r)
    shop(r)
    prophecy(r)
    ending(r)
    dialogue(r)
    return bytes(r.d), r.mods, r.log


def main():
    src, out = sys.argv[1], sys.argv[2]
    d, mods, log = apply(open(src, 'rb').read())
    open(out, 'wb').write(d)
    print('layout: %d patches, %d code modules -> %s' % (len(log), len(mods), out))


if __name__ == '__main__':
    main()
