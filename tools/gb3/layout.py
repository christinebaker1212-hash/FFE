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


def apply(data):
    """English NES ROM bytes -> (GB-layout ROM bytes, code modules for tools/gb3/ff3src.py)"""
    r = Rom(data)
    battle(r)
    battle_messages(r)
    magic_rows(r)
    field(r)
    dialogue(r)
    return bytes(r.d), r.mods, r.log


def main():
    src, out = sys.argv[1], sys.argv[2]
    d, mods, log = apply(open(src, 'rb').read())
    open(out, 'wb').write(d)
    print('layout: %d patches, %d code modules -> %s' % (len(log), len(mods), out))


if __name__ == '__main__':
    main()
