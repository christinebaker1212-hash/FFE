"""Game Boy layout for the FF1 English build (applied by `insert.py --gb`).

The GB shows a 20x18-tile part of the NES nametable chosen per screen (camera, see below).
Each screen is re-laid out inside that view in FF1's own code, following the owner's
decisions in CLAUDE.md (SaGa 3 / GB RPG style).

Camera: the NES code selects the GB view per screen by writing tile coordinates to
$5800 (X) / $5801 (Y) (unmapped on the MMC5; the GB runtime moves its view). Default
(field, until a screen sets its own): X = 6, Y = 6. Bit 7 of the $5800 value selects the
runtime's fixed battle palette on DMG (one BG palette for the whole screen there).

Battle (mock-up 12/13, approved): camera (1, 6), so GB = NES - (1, 6):
  enemy area     GB cols 1-14, rows 0-11 (NES enemy box interior, unchanged)
  party sprites  NES x = 140 (GB 132), the acting member steps to 132 (GB 124)
  bottom, GB rows 12-17 (panel rows 0-5):
    left window   GB cols 0-7: enemy names / commands (commands over the names)
    party window  GB cols 8-19: one line per member: name, HP cur/max, status
    message window GB cols 0-19 over both while a message shows (style A:
                  "attacker -> target", then action / result lines indented)
  All window text is drawn in the small proportional font (VWF below).
"""
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from asm6502 import asm
HDR = 16
BANK = 0x4000


def fixed(rom, cpu):
    """file offsets of a fixed-bank address (copies in banks 15 and 31)"""
    return [HDR + b * BANK + cpu - 0xC000 for b in (15, 31)]


def put(rom, cpu, data, expect=None):
    for o in fixed(rom, cpu):
        if expect is not None and bytes(rom[o:o + len(expect)]) != expect:
            raise SystemExit('gb_layout: unexpected bytes at $%04X' % cpu)
        rom[o:o + len(data)] = data


def bank_off(bank, cpu):
    return HDR + bank * BANK + cpu - 0x8000


def battle_frames(rom):
    """$F2DC-$F30B draws the enemy box (1,1,16,18), the party box (17,1,8,18) and the four
    6x7 HP boxes; the GB layout has no frames there. The freed bytes hold the battle
    camera (X = 1: NES cols 1-20) and a wrapper for the two battle calls from the field
    (overworld $C1D6, dungeons $C935) that sets the field camera (X = 6) again after the
    battle, keeping A and the flags (the dungeon caller branches on carry)."""
    put(rom, 0xF2DC, bytes([0xA9, 0x81, 0x8D, 0x00, 0x58,      # LDA #$81 / STA $5800 (bit 7:
                                                                #   the runtime's battle DMG palette)
                            0x4C, 0x0C, 0xF3]),                 # JMP $F30C
        expect=bytes([0xA9, 0x01, 0x8D, 0x38, 0x00]))
    wrap = 0xF2E4
    put(rom, wrap, bytes([0x20, 0x00, 0xF2,                    # JSR $F200 (battle)
                          0x08, 0x48,                          # PHP / PHA
                          0xA9, 0x06, 0x8D, 0x00, 0x58,        # LDA #6 / STA $5800
                          0x68, 0x28, 0x60]))                  # PLA / PLP / RTS
    for site in (0xC1D6, 0xC935):
        put(rom, site, bytes([0x20, wrap & 0xFF, wrap >> 8]), expect=bytes([0x20, 0x00, 0xF2]))


MUSIC = 0xF2F1      # in the freed battle-frame bytes (after the wrapper, up to $F30B)


def music_trampoline(rom):
    """Far code (mapped at $C000-$DFFF) cannot call the music driver $C009 (bank 62 at
    $C000) directly: MUSIC maps bank 62, runs $F48B (as $F47D does: $4B fix-up, then
    JMP $C009) and maps the far bank again (farcur in ExRAM)."""
    farcur = sys.modules['__main__'].LABELS_EX['farcur']
    put(rom, MUSIC, bytes([0xA9, 0x80 + 62, 0x8D, 0x16, 0x51,          # LDA #$BE / STA $5116
                           0x20, 0x8B, 0xF4,                             # JSR $F48B
                           0xAD, farcur & 0xFF, farcur >> 8,             # LDA farcur
                           0x8D, 0x16, 0x51, 0x60]))                     # STA $5116 / RTS


# Small-font (variable-width) battle text for the GB layout. All battle window text is
# drawn into fixed BG tiles (the font tiles $80-$EF are free in battle: the field reloads
# the whole BG pattern table after a battle):
#   party window   tiles $80-$A7: member m's line = $80 + 10m (10 tiles, 80 px)
#   panel text     tiles $A8-$EF: panel row r (1-4), column c (2-19) = $A8 + 18(r-1) + c-2,
#                  except the 9-column left window (names / commands): its own 28 tiles
#                  (LPOOL: $F0-$F6, hidden backdrop $01-$11, $7A-$7D)
# The panel image ($691E, 32 bytes per row, NES rows 18-29) gets these tile numbers; the
# glyphs are rendered into a 1-bit line buffer and uploaded in vblank (both planes = ink:
# ink colour 3 on colour 0, like the battle's blank tile $FF).
PANEL = 0x691E
GLYPH_FIRST = 0x7A                       # glyph table covers codes $7A-$FF
DIG3 = 0xD3                              # 3-px digits $D3-$DC, small '/' $DD, arrow $DE
SLASH3, ARROW = 0xDD, 0xDE
STATUS_WORDS = ['Stone', 'Poison', 'Blind', 'Numb', 'Sleep', 'Mute']   # status bits 1-6
FAR_GB = ['party_line', 'party_stamp', 'dlgpage', 'dlghide', 'magpatch']   # far routines added for the GB layout (after boxline etc.)

VWF_SRC = """
VBUF = $6E00        ; line buffer: 18 tiles x 8 rows, 1 bit per pixel, tile-major
VX = $6E90          ; pen x (pixels)
VN = $6E91          ; tiles in the line
VT = $6E92          ; first BG tile number of the line
VCNT = $6E93
VSH = $6E94
VOFF = $6E95
VLO = $6E96
VT2 = $6E97
VUP = $6E98
VC = $6E99
VSV = $6EAC         ; 4 bytes: caller's $88-$8B
VROW = $6E9C        ; panel row / column of the text being drawn
VCOL = $6E9D
VW = $6E9E          ; tiles to the frame
VIND = $6E9F        ; indent (pixels) of the line
VLINE = $6EA0       ; next free row of the message window (0 = no message window yet)
VHI = $6EA1
VZ = $6EA2
VPM = $6EA3
VA = $6EA4          ; 2 bytes: panel address of the current row
VEND = $6EA6        ; string index where the current row ends
VNEXT = $6EA7       ; string index where the next row starts
VC0 = $6EA8         ; string index where the current row starts
VLIM = $6EA9        ; pixels available in the row
VBRK = $6EAA        ; last space that fits
VRC = $6EAB         ; row count
VNROW = $0343       ; next free row of a column-2 list (enemy names)
VTV = $0345         ; 1: the next message line is not indented (end-of-battle "target")
VSQ = $0346         ; letter gaps still to drop in a squeezed word
VTID = $0350        ; BG tile number of each tile of the line being uploaded (up to 18)
VSTR = $6EB0        ; text being drawn (codes, 0-terminated, up to 47)
VTGT = $6EE0        ; target name (15 codes + 0)
VATK = $6EF0        ; attacker's name (row 1 of the message window), 15 codes + 0

vsave:
    ldx #3
.l:
    lda $88,x
    sta VSV,x
    dex
    bpl .l
    rts
vrest:
    ldx #3
.l:
    lda VSV,x
    sta $88,x
    dex
    bpl .l
    rts

vclear:             ; clear VN tiles of the buffer, VX = 0
    lda VN
    asl a
    asl a
    asl a
    tax
    lda #0
    sta VX
.l:
    dex
    sta VBUF,x
    cpx #0
    bne .l
    rts

vchar:              ; A = code: draw at VX, advance (glyph width + 1; space 3)
    cmp #$FD        ; $FD x: pen to pixel x (handled by vstr)
    bne .nfd
    rts
.nfd:
    cmp #$FF
    bne .g
    lda VX
    clc
    adc #3
    sta VX
    rts
.g:
    sec
    sbc #GFIRST
    bcs .g2
    rts
.g2:
    tax
    lda GW,x
    bne .g3
    rts
.g3:
    sta VCNT
    lda #0
    sta $89
    txa
    asl a
    rol $89
    asl a
    rol $89
    asl a
    rol $89
    clc
    adc #<GR
    sta $88
    lda $89
    adc #>GR
    sta $89
    lda VX
    and #7
    sta VSH
    lda VX
    lsr a
    lsr a
    lsr a
    cmp VN
    bcs .adv
    sta VT2
    asl a
    asl a
    asl a
    sta VOFF
    ldy #0
.row:
    lda #0
    sta VLO
    lda ($88),y
    beq .nx
    ldx VSH
    beq .ns
.sh:
    lsr a
    ror VLO
    dex
    bne .sh
.ns:
    pha
    tya
    clc
    adc VOFF
    tax
    pla
    ora VBUF,x
    sta VBUF,x
    lda VLO
    beq .nx
    ldx VT2
    inx
    cpx VN
    bcs .nx
    tya
    clc
    adc VOFF
    adc #8
    tax
    lda VLO
    ora VBUF,x
    sta VBUF,x
.nx:
    iny
    cpy #8
    bne .row
.adv:
    lda VSQ         ; squeezed word: no gap after this letter
    beq .gap
    dec VSQ
    lda VX
    clc
    adc VCNT
    sta VX
    rts
.gap:
    lda VX
    sec
    adc VCNT
    sta VX
.r:
    rts

vstr:               ; draw VSTR from index A up to (not including) index VEND or a 0;
    sta VC          ;   $FD x moves the pen to pixel x
.l:
    ldx VC
    cpx VEND
    bcs .r
    lda VSTR,x
    beq .r
    cmp #$FD
    bne .c
    lda VSTR+1,x    ; $FD $80+n: pen to tile n of the row (codes >= $7A pass the decoder)
    sec
    sbc #$80
    asl a
    asl a
    asl a
    sta VX
    inc VC
    bne .n
.c:
    jsr vchar
.n:
    inc VC
    bne .l
.r:
    rts

vwidth:             ; A = width in pixels of VSTR from index X up to the next 0 / $FE
    lda #0
    sta VLO
.l:
    lda VSTR,x
    beq .e
    cmp #$FE
    beq .e
    jsr vcw
    clc
    adc VLO
    sta VLO
    inx
    bne .l
.e:
    lda VLO
    rts

vcw:                ; A = code -> advance in pixels (glyph width + 1, space 3); keeps X
    cmp #$FF
    beq .sp
    sec
    sbc #GFIRST
    bcc .z
    tay
    lda GW,y
    beq .z
    clc
    adc #1
    rts
.sp:
    lda #3
    rts
.z:
    lda #0
    rts

vupload:            ; VN tiles of the buffer -> BG tiles VTID[0..VN-1], 4 tiles per vblank
    lda #0
    sta VUP
.chunk:
    jsr $F499
    lda #4
    sta VCNT
.tile:
    lda $2002
    ldx VUP
    lda VTID,x
    sta VLO
    lda #0
    sta VHI
    lda VLO
    asl a
    rol VHI
    asl a
    rol VHI
    asl a
    rol VHI
    asl a
    rol VHI
    tax
    lda VHI
    sta $2006
    stx $2006
    lda VUP
    asl a
    asl a
    asl a
    tax
    ldy #8
.p0:
    lda VBUF,x
    sta $2007
    inx
    dey
    bne .p0
    txa             ; plane 1 = plane 0: ink colour 3 on colour 0, as FF1's battle blank
    sec             ;   tile $FF (written at $F36C) - the same black on the NES, and one
    sbc #8          ;   shade on the GB
    tax
    ldy #8
.p1:
    lda VBUF,x
    sta $2007
    inx
    dey
    bne .p1
    inc VUP
    lda VUP
    cmp VN
    beq .done
    dec VCNT
    bne .tile
    jsr vpost
    jmp .chunk
.done:
vpost:              ; after the PPU writes: as $F47D (mask, scroll 0, music), but the music
    lda $68B8       ;   driver $C009 lies in bank 62, which the far bank replaces at $C000:
    sta $2001       ;   it is called through the fixed-bank trampoline MUSIC
    lda #0
    sta $2005
    sta $2005
    jmp MUSIC

; ---- party window -------------------------------------------------------------------
party_stamp:        ; panel cleared ($F618): party window into the panel image, cols 9-20,
    lda #0          ;   rows 0-5 (tiles $80 + 10m for member m's line); no message window yet
    sta VLINE
    ldx #0
.top:
    lda PSTAMP,x
    sta $691E+9,x
    lda PSTAMP+12,x
    sta $691E+5*32+9,x
    inx
    cpx #12
    bne .top
    lda #$80
    ldy #0
.rows:
    ldx PROWS,y
    pha
    lda #$FA
    sta $691E+9,x
    lda #$FB
    sta $691E+20,x
    pla
.cells:
    sta $691E+10,x
    clc
    adc #1
    inx
    pha
    txa
    and #31
    cmp #10
    pla
    bcc .cells
    iny
    cpy #4
    bne .rows
    rts
PSTAMP:
    .db $F7, $F8, $F8, $F8, $F8, $F8, $F8, $F8, $F8, $F8, $F8, $F9
    .db $FC, $FD, $FD, $FD, $FD, $FD, $FD, $FD, $FD, $FD, $FD, $FE
PROWS:
    .db 32, 64, 96, 128

party_line:         ; member $685E: name, HP current/max, status word -> tiles $80 + 10m
    lda $685E       ;   (farjsr uses A, so the member comes from RAM)
    sta VPM
    jsr vsave
    lda #10
    sta VN
    lda VPM
    asl a
    sta VT
    asl a
    asl a
    adc VT
    adc #$80
    sta VT
    ldx #0
.id:
    sta VTID,x
    clc
    adc #1
    inx
    cpx #10
    bne .id
    jsr vclear
    jsr pmx         ; X = member * 64 (character data $6100 + X)
    ldy #0
.nm:
    lda $6102,x
    sta VSTR,y
    inx
    iny
    cpy #4
    bne .nm
    lda #0
    sta VSTR,y
    lda #64
    sta VEND
    lda #0
    jsr vstr
    ; HP "cur/max" in 3-px digits, right edge at x = 52
    jsr pmx
    ldy #8
    lda $610A,x
    sta VLO
    lda $610B,x
    sta VHI
    jsr dec3
    lda #SLASH3
    sta VSTR,y
    iny
    lda $610C,x
    sta VLO
    lda $610D,x
    sta VHI
    jsr dec3
    lda #0
    sta VSTR,y
    ldx #8
    jsr vwidth
    sec
    sbc #1          ; no gap after the last digit
    sta VLO
    lda #52
    sec
    sbc VLO
    sta VX
    lda #8
    jsr vstr
    ; status: lowest set bit 1-6 of the ailments byte (bit 0, dead: no word)
    jsr pmx
    lda $6101,x
    lsr a
    bcs .up
    ldy #0
.bit:
    lsr a
    bcs .word
    iny
    cpy #6
    bne .bit
    beq .up
.word:
    ldx STW,y
    ldy #0
.wc:
    lda STWORDS,x
    sta VSTR,y
    beq .wd
    inx
    iny
    bne .wc
.wd:
    lda #54
    sta VX
    lda #0
    jsr vstr
.up:
    jsr vupload
    jmp vrest

pmx:
    lda VPM
    asl a
    asl a
    asl a
    asl a
    asl a
    asl a
    tax
    rts

dec3:               ; VLO/VHI (< 1000) -> 3-px digit codes at VSTR,Y (no leading zeros); keeps X
    txa
    pha
    lda #0
    sta VZ
    ldx #0
.h:
    lda VLO
    sec
    sbc #100
    sta VCNT
    lda VHI
    sbc #0
    bcc .hd
    sta VHI
    lda VCNT
    sta VLO
    inx
    bne .h
.hd:
    txa
    jsr .dig
    ldx #0
.t:
    lda VLO
    sec
    sbc #10
    bcc .td
    sta VLO
    inx
    bne .t
.td:
    txa
    jsr .dig
    lda #1
    sta VZ
    lda VLO
    jsr .dig
    pla
    tax
    rts
.dig:
    bne .w
    ldx VZ
    beq .s
.w:
    clc
    adc #DIG3
    sta VSTR,y
    iny
    lda #1
    sta VZ
.s:
    rts


VBOX = $0344        ; box count saved while the names show during enemy targeting

; ---- panel text (replaces the English patch's boxline) ---------------------------------
; Input: decoded line at $6CD4 (pairs: dakuten, code; 0 ends), ($8A) = panel image cell of
; the text record. Column 21 = "-> target" after the attacker on row 1 of the message
; window; column 22 = next line of the message window (indented 8 px from row 2 on).
boxline:
    jsr vsave
    lda $8A
    sec
    sbc #<$691E
    sta VLO
    lda $8B
    sbc #>$691E
    sta VHI
    lda VLO
    and #31
    sta VCOL
    lda VLO
    lsr VHI
    ror a
    lsr a
    lsr a
    lsr a
    lsr a
    sta VROW
    ldx #1          ; copy the codes to VSTR
    ldy #0
.cp:
    lda $6CD4,x
    sta VSTR,y
    beq .cpd
    inx
    inx
    iny
    cpy #47
    bne .cp
    lda #0
    sta VSTR,y
.cpd:
    lda #0
    sta VIND
    lda VCOL
    cmp #21
    bne .n21
    jmp .target
.n21:
    cmp #23
    bne .n22
    lda #6          ; column 23 = column 6 with a 3-px indent ("Run": the hand fits between
    sta VCOL        ;   "Fight" and "Run" without touching either)
    lda #3
    sta VIND
    jsr vtext
    jmp vrest
.n22:
    cmp #22
    bne .plain
    jmp .next
.plain:
    lda VROW        ; a plain text record: rows 1-4, columns 2-19 only
    beq .out
    cmp #5
    bcs .out
    lda VCOL
    cmp #2
    bcc .out
    cmp #20
    bcs .out
    cmp #2          ; keep what is written at row 1 column 2 (the attacker, in a message)
    bne .pl
    lda VROW
    cmp #1
    bne .pl
    ldx #0
.sv:
    lda VSTR,x
    sta VATK,x
    beq .sve
    inx
    cpx #15
    bne .sv
    lda #0
    sta VATK,x
.sve:
    jsr vtext       ; the attacker: following lines start below it
    lda VROW
    clc
    adc #1
    sta VLINE
    sta VNROW
    jmp vrest
.pl:
    lda VCOL        ; column 2 lists (enemy names): a name that wrapped pushes the next
    cmp #2          ;   one down (row 1 starts a list)
    bne .pl2
    lda VROW
    cmp VNROW
    bcs .pl1
    lda VNROW
    sta VROW
.pl1:
    jsr vtext
    lda VROW
    clc
    adc #1
    sta VNROW
    jmp vrest
.pl2:
    jsr vtext
.out:
    jmp vrest
.target:            ; row 1 = attacker + " -> " + target
    lda $57         ; end of battle (bank 11 code: experience / gold): the "target" is a
    cmp #11         ;   line of its own, not indented
    bne .tg0
    lda #1
    sta VTV
    jmp .next
.tg0:
    ldx #0
.tg:
    lda VSTR,x
    sta VTGT,x
    beq .tgd
    inx
    cpx #15
    bne .tg
    lda #0
    sta VTGT,x
.tgd:
    ldx #0          ; an empty target (spaces only): the attacker alone
.te:
    lda VTGT,x
    beq .ca0
    cmp #$FF
    bne .ca1
    inx
    bne .te
.ca0:
    ldx #0
.cz:
    lda VATK,x
    sta VSTR,x
    beq .ctd
    inx
    bne .cz
.ca1:
    ldx #0
.ca:
    lda VATK,x
    beq .cae
    sta VSTR,x
    inx
    bne .ca
.cae:
    lda #$FF
    sta VSTR,x
    inx
    lda #ARR
    sta VSTR,x
    inx
    lda #$FF
    sta VSTR,x
    inx
    ldy #0
.ct:
    lda VTGT,y
    sta VSTR,x
    beq .ctd
    inx
    iny
    bne .ct
.ctd:
    lda #1
    sta VROW
    lda #2
    sta VCOL
    jsr vtext
    jmp vrest
.next:
    lda $691E+1     ; a full-width window has its top edge at column 9
    cmp #$F7
    bne .open
    lda $691E+9
    cmp #$F8
    beq .have
.open:
    jsr msgwin
    lda #1
    sta VLINE
.have:
    lda VLINE
.nw:
    cmp #2
    bcc .ni
    ldx VTV
    bne .ni
    lda #8
    sta VIND
.ni:
    lda #0
    sta VTV
    jsr vrows       ; rows the text needs
    clc
    adc VLINE
    cmp #6
    bcc .fit
    jsr msgclr      ; does not fit: clear rows 2-4, continue at row 2
    lda #2
    sta VLINE
    lda #8
    sta VIND
.fit:
    lda VLINE
    sta VROW
    lda #2
    sta VCOL
    jsr vtext
    lda VROW
    clc
    adc #1
    sta VLINE
    jmp vrest

vaddr:              ; ($8A) = panel cell (VROW, VCOL)
    lda #0
    sta $8B
    lda VROW
    asl a
    asl a
    asl a
    asl a
    asl a
    rol $8B
    clc
    adc VCOL
    bcc .a
    inc $8B
.a:
    clc
    adc #<$691E
    sta $8A
    lda $8B
    adc #>$691E
    sta $8B
    rts

vtext:              ; VSTR at panel (VROW, VCOL), word-wrapped to the frame (rows <= 4)
    jsr vaddr
    ldy #0          ; cells to the frame
.w:
    lda ($8A),y
    cmp #$F7
    bcc .wn
    cmp #$FF
    bcc .we
.wn:
    iny
    cpy #20
    bne .w
.we:
    sty VW
    lda #20         ; never past column 19: the row's 18 tiles end there
    sec
    sbc VCOL
    cmp VW
    bcs .wk
    sta VW
.wk:
    lda #0
    sta VC0
.row:
    lda VW
    beq .done
    sta VN
    jsr vtids       ; tile numbers of the row's cells
    jsr vbreak
    jsr vclear
    lda VIND
    sta VX
    lda VC0
    jsr vstr
    jsr vupload
    ldy #0          ; the row's cells show the tiles
.c:
    lda VTID,y
    sta ($8A),y
    iny
    cpy VN
    bne .c
    ldx VNEXT
    stx VC0
    lda VSTR,x
    beq .done
    lda VROW
    cmp #4
    bcs .done
    inc VROW
    lda $8A
    clc
    adc #32
    sta $8A
    bcc .row
    inc $8B
    bne .row
.done:
    rts

vtids:              ; VTID[k] for the VN cells from (VROW, VCOL): in the 9-column left window
    lda $691E+9     ;   (top-right corner $F9 at column 9: names / commands) its own 28
    cmp #$F9        ;   tiles (LPOOL), so a message or list drawn over it never shows in it
    bne .full       ;   while the panel is copied; elsewhere $A8 + 18(row-1) + col-2
    lda VCOL
    cmp #9
    bcs .full
    lda VROW        ; LPOOL index = 7(row-1) + col-2
    sec
    sbc #1
    sta VLO
    asl a
    asl a
    asl a
    sec
    sbc VLO
    clc
    adc VCOL
    sec
    sbc #2
    tax
    ldy #0
.l:
    lda LPOOL,x
    sta VTID,y
    inx
    iny
    cpy VN
    bne .l
    rts
.full:
    lda VROW
    sec
    sbc #1
    asl a
    sta VLO
    asl a
    asl a
    asl a
    clc
    adc VLO
    adc VCOL
    adc #$A8-2
    ldy #0
.f:
    sta VTID,y
    clc
    adc #1
    iny
    cpy VN
    bne .f
    rts
LPOOL:              ; tiles never shown in battle: font $F0-$F6, backdrop $01-$11 (NES rows
    .db $F0, $F1, $F2, $F3, $F4, $F5, $F6   ;   2-5, outside the GB view), $7A-$7D
    .db $01, $02, $03, $04, $05, $06, $07
    .db $08, $09, $0A, $0B, $0C, $0D, $0E
    .db $0F, $10, $11, $7A, $7B, $7C, $7D

vbreak:             ; row from VC0 in VW tiles less VIND: VEND = end, VNEXT = next start
    lda VW
    asl a
    asl a
    asl a
    sec
    sbc VIND
    sta VLIM
    ldx VC0
    lda #0
    sta VLO
    sta VSQ
    lda #$FF
    sta VBRK
.l:
    lda VSTR,x
    beq .all
    cmp #$FE
    beq .fe
    cmp #$FD
    bne .nf
    inx
    lda VSTR,x
    sec
    sbc #$80
    asl a
    asl a
    asl a
    sta VLO
    jmp .ok
.nf:
    cmp #$FF
    bne .ch
    stx VBRK
.ch:
    jsr vcw
    clc
    adc VLO
    sta VLO
    beq .ok
    sec
    sbc #1
    cmp VLIM
    beq .ok
    bcs .over
.ok:
    inx
    bne .l
.all:
    stx VEND
    stx VNEXT
    rts
.fe:
    stx VEND
    inx
    stx VNEXT
    rts
.over:
    lda VBRK
    cmp #$FF
    beq .cut
    sta VEND
    tax
    inx
    stx VNEXT
    rts
.cut:               ; one word wider than the row: if dropping some of its 1-px letter
    stx VSQ         ;   gaps makes it fit, squeeze it (VSQ = gaps to drop), else cut it
    ldx VC0
    lda #0
    sta VLO         ; width of the whole word
    sta VCNT        ; letters
.sw:
    lda VSTR,x
    beq .swe
    cmp #$FF
    beq .swe
    cmp #$FE
    beq .swe
    jsr vcw
    clc
    adc VLO
    sta VLO
    inc VCNT
    inx
    bne .sw
.swe:
    lda VLO         ; overflow = width - 1 - limit
    sec
    sbc #1
    sec
    sbc VLIM
    bcc .sq         ; (fits after all)
    sta VLO
    lda VCNT
    sec
    sbc #1          ; gaps
    cmp VLO
    bcc .nosq
.sq:
    lda VLO
    bcs .sq2
    lda #0
.sq2:
    sta VLO
    stx VEND        ; the whole word on this row, VLO gaps dropped
    lda VSTR,x
    beq .sq3
    inx             ; skip the space after it
.sq3:
    stx VNEXT
    lda VLO
    sta VSQ
    rts
.nosq:
    ldx VSQ         ; cut at the overflowing letter
    lda #0
    sta VSQ
    cpx VC0
    bne .c2
    inx
.c2:
    stx VEND
    stx VNEXT
    rts

vrows:              ; A = rows VSTR needs in the message window (18 tiles, indent VIND)
    lda #18
    sta VW
    lda #0
    sta VC0
    sta VRC
.l:
    inc VRC
    jsr vbreak
    ldx VNEXT
    stx VC0
    lda VSTR,x
    bne .l
    lda VRC
    rts

msgwin:             ; full-width message window (cols 1-20, rows 0-5) into the panel image
    ldx #0
.l:
    lda MWROW,x
    sta $691E+1,x
    lda MWROW+20,x
    sta $691E+32+1,x
    sta $691E+64+1,x
    sta $691E+96+1,x
    sta $691E+128+1,x
    lda MWROW+40,x
    sta $691E+160+1,x
    inx
    cpx #20
    bne .l
    rts
msgclr:             ; message window rows 2-4 blank
    ldx #17
    lda #$FF
.l:
    sta $691E+64+2,x
    sta $691E+96+2,x
    sta $691E+128+2,x
    dex
    bpl .l
    rts
MWROW:
    .db $F7, $F8, $F8, $F8, $F8, $F8, $F8, $F8, $F8, $F8, $F8, $F8, $F8, $F8, $F8, $F8, $F8, $F8, $F8, $F9
    .db $FA, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FB
    .db $FC, $FD, $FD, $FD, $FD, $FD, $FD, $FD, $FD, $FD, $FD, $FD, $FD, $FD, $FD, $FD, $FD, $FD, $FD, $FE
"""


# Battle magic list for the GB layout (replaces the English magpage in the far code): the
# full-width window, two levels per page, each on two rows:
#   row 1: spell 1 (column 2)  spell 2 (column 12)
#   row 2: spell 3 (column 2)  "L<n>  MP <count>" (column 13)
# (spells up to 64 px; FF1's 16-px hand sits left of each spell, cut off at the screen
# edge for the left column)
# Positions use the $FD $80+n pen code of the small-font text (n = tiles from the record).
MAGPAGE = """LETM = $96
LETP = $99
magpage:
    ldy #5
.c:
    lda $FA08,y
    sta $6A9D,y
    dey
    bne .c
    lda #1
    sta $6A9F
    lda #0
    sta $6AA0
    lda #20
    sta $6AA1
    lda #6
    sta $6AA2
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
    sta MU
.lv:
    lda $6AF8
    asl a
    clc
    adc MI
    sta ML
    lda MU          ; ---- row 1: spell 1, spell 2
    sta MT
    ldx MU
    lda #0
    jsr .spell
    lda #$FD
    sta $6AFA,x
    inx
    lda #$8A
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
    clc
    adc #1
    jsr .queue
    lda MU          ; ---- row 2: spell 3, "L<n>  MP <count>"
    sta MT
    ldx MU
    lda #2
    jsr .spell
    lda #$FD
    sta $6AFA,x
    inx
    lda #$8B
    sta $6AFA,x
    inx
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
    lda #LETM
    sta $6AFA,x
    inx
    lda #LETP
    sta $6AFA,x
    inx
    lda #$FF
    sta $6AFA,x
    inx
    lda ML
    clc
    adc #$20
    tay
    lda ($88),y
    clc
    adc #$80
    sta $6AFA,x
    inx
    lda #0
    sta $6AFA,x
    inx
    stx MU
    lda MI
    asl a
    clc
    adc #2
    jsr .queue
    inc MI
    lda MI
    cmp #2
    beq .done
    jmp .lv
.done:
    rts
.spell:             ; A = slot: append 0E <name index> if the slot holds a spell
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
    clc
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
.queue:             ; A = row: queue text record 01 2 row ptr(MT)
    sta $6AA0
    lda #2
    sta $6A9F
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
"""


# Battle Item list for the GB layout (replaces the English itemlist): one group per page,
# weapons (slots 0-3, $6118) or armour (4-7, $611C) as chosen by the cursor column $6AAA,
# one name per row at column 2 (names up to 75 px), the group's name at column 15 of row 1.
# Left / right (itemmove) switches the group and sets FLIP; the page is redrawn by
# ITEMFLIP in the fixed bank after farjsr returns (the redraw reaches the music driver).
ITEMLIST = """LETW = $A0
itemlist:
    ldy #5
.c:
    lda $FA08,y
    sta $6A9D,y
    dey
    bne .c
    lda #1
    sta $6A9F
    lda #0
    sta $6AA0
    lda #20
    sta $6AA1
    lda #6
    sta $6AA2
    jsr $F688
    jsr $F74F
    lda $6B7A
    jsr $F88F
    sta MR
    lda $6AAA       ; group: 0 weapons, 1 armour
    asl a
    asl a
    sta MS          ; first slot
    lda #0
    sta MI
    sta MU
.j:
    lda MU
    sta MT
    tax
    jsr .ent
    lda #0
    sta $6AFA,x
    inx
    stx MU
    lda #2
    ldy MI
    iny
    jsr .queue
    inc MS
    inc MI
    lda MI
    cmp #4
    bne .j
    lda MU          ; group name at column 15, row 1
    sta MT
    tax
    ldy #0
    lda $6AAA
    beq .wn
    ldy #GRP_ARMOR-GRP_WEAPONS
.wn:
    lda GRP_WEAPONS,y
    sta $6AFA,x
    beq .wd
    inx
    iny
    bne .wn
.wd:
    lda #15
    ldy #1
.queue:             ; A = column, Y = row: queue text record 01 A Y ptr(MT)
    sta $6A9F
    sty $6AA0
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
.ent:               ; name of slot MS at X (none: empty row)
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
    adc #$1B
    ldy MS
    cpy #4
    bcc .w
    adc #$43-$1B-1
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
"""


def glyph_tables(enc):
    """GW (width) and GR (8 row bytes) for codes $7A-$FF, as assembler source."""
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
    import latin_font as L
    code_ch = {v: k for k, v in enc.items() if k != ' '}
    code_ch.update({0xC6: 'L', 0xC7: 'E', 0xC8: 'H', 0xC9: 'P'})
    dig3 = {
        '0': ["###", "#.#", "#.#", "#.#", "#.#", "#.#", "###"],
        '1': [".#.", "##.", ".#.", ".#.", ".#.", ".#.", "###"],
        '2': ["###", "..#", "..#", "###", "#..", "#..", "###"],
        '3': ["###", "..#", "..#", ".##", "..#", "..#", "###"],
        '4': ["#.#", "#.#", "#.#", "###", "..#", "..#", "..#"],
        '5': ["###", "#..", "#..", "###", "..#", "..#", "###"],
        '6': ["###", "#..", "#..", "###", "#.#", "#.#", "###"],
        '7': ["###", "..#", "..#", ".#.", ".#.", ".#.", ".#."],
        '8': ["###", "#.#", "#.#", "###", "#.#", "#.#", "###"],
        '9': ["###", "#.#", "#.#", "###", "..#", "..#", "###"],
        '/': ["..#", "..#", ".#.", ".#.", ".#.", "#..", "#.."]}
    arrow = ["......", "...#..", "....#.", "######", "....#.", "...#..", "......"]
    gw, gr = [], []
    for code in range(GLYPH_FIRST, 0x100):
        rows = None
        if DIG3 <= code < DIG3 + 10: rows = dig3[str(code - DIG3)]
        elif code == SLASH3: rows = dig3['/']
        elif code == ARROW: rows = arrow
        if rows is not None:
            cols = [[1 if y < 7 and rows[y][x] == '#' else 0 for y in range(8)] for x in range(len(rows[0]))]
        elif code in code_ch and code < 0xF7:
            ch = code_ch[code]
            cols = L._glyph_cols(ch, L.COND if ch in L.COND else L.G)
        else:
            cols = []
        assert len(cols) <= 8, (hex(code), len(cols))
        gw.append(len(cols))
        for y in range(8):
            gr.append(sum(cols[x][y] << (7 - x) for x in range(len(cols))))
    out = 'GFIRST = $%02X\nARR = $%02X\nDIG3 = $%02X\nSLASH3 = $%02X\nGW:\n' % (GLYPH_FIRST, ARROW, DIG3, SLASH3)
    for k in range(0, len(gw), 16): out += '    .db ' + ', '.join(str(v) for v in gw[k:k + 16]) + '\n'
    out += 'GR:\n'
    for k in range(0, len(gr), 16): out += '    .db ' + ', '.join(str(v) for v in gr[k:k + 16]) + '\n'
    words = ''
    offs = []
    for w in STATUS_WORDS:
        offs.append(len(words.split(',')) - 1 if words else 0)
        words += ', '.join(str(b) for b in enc_word(enc, w)) + ', 0, '
    data = [b for w in STATUS_WORDS for b in list(enc_word(enc, w)) + [0]]
    offs, k = [], 0
    for w in STATUS_WORDS:
        offs.append(k); k += len(w) + 1
    out += 'STW:\n    .db ' + ', '.join(map(str, offs)) + '\nSTWORDS:\n    .db ' + ', '.join(map(str, data)) + '\n'
    for lab, w in (('GRP_WEAPONS', 'Weapons'), ('GRP_ARMOR', 'Armor')):
        out += '%s:\n    .db %s, 0\n' % (lab, ', '.join(str(b) for b in enc_word(enc, w)))
    return out


def enc_word(enc, w):
    return bytes(enc[c] for c in w)


def far_source(enc):
    return 'MUSIC = $%04X\n' % MUSIC + VWF_SRC + DLG_SRC + glyph_tables(enc) + magpatch_source(enc)


# ---- field dialogue ----------------------------------------------------------------
# NES: box metatile columns 1-14 (tile columns 2-29), tile rows 2-12, text 25 columns x 9
# lines from (4, 3). GB: the top of the GB view, columns 6-25 and tile rows 6-13 (frame,
# 6 text lines, frame), text 18 columns from (7, 7); the party (screen rows 14-15) stays
# visible below. Text is wrapped at 18 columns by insert.py --gb and split into pages of
# 6 lines by code $05: wait for A, clear the text, go on at the first line.
DLG_W, DLG_H = 18, 6
DLG_PAGE = 0x05

DLG_SRC = """
DGN = $0347         ; rows left to clear
DGT = $0348
dlgpage:            ; page break in a dialogue (printer at $DB8E; $38/$39 = text origin)
dgw0:
    jsr dgframe
    bmi dgw0        ; A still held: wait for its release
dgw1:
    jsr dgframe
    bpl dgw1        ; wait for A
dgw2:
    jsr dgframe
    bmi dgw2
    lda $39         ; clear the 6 text rows (one per frame)
    sta $3B
    lda #6
    sta DGN
dgr:
    jsr $FE00
    lda $38
    sta $3A
    jsr dgaddr
    ldx #18
dgc:
    lda #$FF
    sta $2007
    lda $3A         ; next column; the other nametable at 32 / 0 (as the printer)
    clc
    adc #1
    and #$3F
    sta $3A
    and #$1F
    bne dgc1
    jsr dgaddr
dgc1:
    dex
    bne dgc
    jsr MUSIC
    jsr dgscroll
    lda $3B
    clc
    adc #1
    cmp #30
    bcc dgr1
    sbc #30
dgr1:
    sta $3B
    dec DGN
    bne dgr
    jmp dlghide     ; (people over the box hidden again)
dlghide:            ; dialogue box opening: sprites over the box rows (NES y 48-111) hidden
    ldx #0          ;   (the field rebuilds the sprites when the box closes)
dh1:
    lda $0200,x
    clc
    adc #16
    cmp #48         ; top (y + 1) >= 33 and < 112
    bcc dh2
    cmp #127
    bcs dh2
    lda #$F0
    sta $0200,x
dh2:
    inx
    inx
    inx
    inx
    bne dh1
    lda #2          ; to the screen now (the next OAM upload is after the dialogue)
    sta $4014
    rts
dgframe:            ; next frame (music, scroll), then the pad: A = buttons, N = A button
    jsr $FE00
    jsr MUSIC
    jsr dgscroll
    lda #1
    sta $4016
    lda #0
    sta $4016
    ldx #8
dgp:
    lda $4016
    and #3
    cmp #1
    rol $20
    dex
    bne dgp
    lda $20
    rts
dgscroll:           ; as $CCA3 (field scroll)
    lda $FD
    sta $FF
    sta $2000
    lda $29
    asl a
    asl a
    asl a
    asl a
    ora $35
    sta $2005
    lda $2F
    asl a
    asl a
    asl a
    asl a
    ora $36
    sta $2005
    rts
dgaddr:             ; PPU address of column $3A (0-63), row $3B (as $DC8E); keeps X
    lda $2002
    lda $3B
    lsr a
    lsr a
    lsr a
    ora #$20
    pha
    lda $3A
    cmp #$20
    pla
    bcc dga1
    ora #$04
dga1:
    sta $2006
    lda $3B
    asl a
    asl a
    asl a
    asl a
    asl a
    sta DGT
    lda $3A
    and #$1F
    ora DGT
    sta $2006
    rts
"""


def dialogue(rom):
    """Field dialogue box for the GB view (see DLG_SRC): the box builder $D54B rewritten
    (table-driven: upper / lower tile row of each box metatile row), the text origin
    ($D520) and the page-break code in the printer's dispatch ($DBE8)."""
    main = sys.modules['__main__']
    farjsr = main.LABELS_EX['farjsr']
    page = main.FAR_ROUTINES.index('dlgpage')
    src = """
dbuild:             ; box metatile row $1C (6 = lowest .. 1): upper / lower tile row kinds
    dec $1C
    beq dbret
    lda $1C
    cmp #6
    bne db0
    ldx #HIDE       ; first row: people over the box hidden
    jsr FARJSR
db0:
    ldx $1C
    lda dupk,x
    beq dblo
    ldx #0
    jsr dfill
dblo:
    ldx $1C
    lda dlok,x
    beq dbret
    ldx #$20
    jmp dfill
dbret:
    rts
dfill:              ; A = 1 top, 2 middle, 3 bottom; X = 0 upper / $20 lower tile row:
    tay             ;   left edge in metatile 3, fill to metatile 12, right edge in 12
    lda dkl-1,y
    sta $0783,x
    lda dkr-1,y
    sta $079C,x
    lda dkf-1,y
    ldy #9
df1:
    sta $0784,x
    sta $0793,x
    inx
    dey
    bne df1
    rts
dkl:
    .db $F7, $FA, $FC
dkf:
    .db $F8, $FF, $FD
dkr:
    .db $F9, $FB, $FE
dupk:
    .db 0, 0, 0, 1, 2, 2, 2
dlok:
    .db 0, 0, 0, 2, 2, 2, 3
dchk:               ; printer dispatch ($DBE8): 01 newline, 05 page break, else as before
    cmp #$01
    bne dchk5
    jsr $DC6D
    jmp $DB8E
dchk5:
    cmp #$05
    bne dchk9
    ldx #PAGE
    jsr FARJSR
    lda $38
    sta $3A
    lda $39
    sta $3B
    lda #5
    sta $17
    jsr $DC8E
    jmp $DB8E
dchk9:
    jmp $DBF2
dstart:             ; text about to be printed (A = dialogue id): people over the box hidden
    pha
    ldx #HIDE
    jsr FARJSR
    pla
    jmp $DB58
dbend:
"""
    r = asm(src, syms={'PAGE': page, 'HIDE': main.FAR_ROUTINES.index('dlghide'), 'FARJSR': farjsr}, org=0xD54B)
    assert r.org == 0xD54B and r.org + len(r.bytes) <= 0xD5E4, hex(r.org + len(r.bytes))
    put(rom, 0xD54B, r.bytes, expect=bytes([0xC6, 0x1C, 0xF0, 0x4C]))
    put(rom, 0xD520, bytes([0xA5, 0x29, 0x18, 0x69, 0x13, 0x29, 0x1F, 0x38, 0x2A, 0x85, 0x38,   # col ((x+19)&31)*2+1
                            0xA5, 0x2F, 0x0A, 0x69, 0x07, 0xC9, 0x1E, 0x90, 0x02, 0xE9, 0x1E,   # row y*2+7 mod 30
                            0x85, 0x39, 0xA9, 0x80, 0x85, 0x37, 0x68, 0x4C]) + r.labels['dstart'].to_bytes(2, 'little'),
        expect=bytes([0xA5, 0x29, 0x18, 0x69, 0x12, 0x29, 0x1F, 0x0A, 0x85, 0x38]))
    put(rom, 0xDBE8, bytes([0x4C]) + r.labels['dchk'].to_bytes(2, 'little'),
        expect=bytes([0xC9, 0x01, 0xD0, 0x06]))

def battle_panel(rom):
    """Bottom panel (25x12 image at $691E, NES rows 18-29; the GB shows panel rows 0-5,
    cols 1-20). Box records: type 0 = frame (x y w h), type 1 = text (x y, pointer).
    Windows are 6 rows high (panel rows 0-5 = GB rows 12-17), 4 text rows (rows 1-4)."""
    put(rom, 0xF625, bytes([0x60]), expect=bytes([0xA9, 0xFD]))      # (replaced by the hook)
    # enemy names: left window (cols 1-9; it covers the party window's left frame while
    # open), names at column 2, rows 1-4
    put(rom, 0xF9DC, bytes([0, 1, 0, 9, 6]), expect=bytes([0, 1, 0, 12, 10]))
    put(rom, 0xF6CC, bytes([0xEA] * 3), expect=bytes([0xEE, 0x9F, 0x6A]))      # text x = box x + 1
    put(rom, 0xF6D2, bytes([0xEA] * 3), expect=bytes([0xCE, 0xA0, 0x6A]))      # no DEC $6AA0
    put(rom, 0xF6D7, bytes([0xEA] * 3), expect=bytes([0xEE, 0xA0, 0x6A]))      # one INC $6AA0
    # command window over the names: Fight Run / Magic / Medicine / Items
    cmd = fixed(rom, 0xFA13)[0]
    ptr = [bytes(rom[cmd + 5 * k + 3:cmd + 5 * k + 5]) for k in range(1, 6)]   # Fight Magic Medicine Items Run
    rec = bytes([0, 1, 0, 9, 6])
    for k, (x, y) in enumerate(((2, 1), (2, 2), (2, 3), (2, 4), (23, 1))):     # 23: Run, see boxline
        rec += bytes([1, x, y]) + ptr[k]
    put(rom, 0xFA13, rec)
    # battle messages (style A): attacker = full-width window, text at (2, 1); action,
    # result and the single message go to the next line (marker column 22), the target
    # after the attacker (marker column 21); their boxes are drawn in hidden panel rows
    # 8-10 (a box must be at least 3 rows high: the frame drawer $F593 draws h-2 middle
    # rows, and h = 2 wraps to 255 rows and overwrites RAM)
    msg = bytes([0, 1, 0, 20, 6, 1, 2, 1,
                 0, 1, 8, 20, 3, 1, 22, 9,
                 0, 1, 8, 20, 3, 1, 21, 9,
                 0, 1, 8, 20, 3, 1, 22, 9,
                 0, 1, 8, 20, 3, 1, 22, 9])
    put(rom, 0xF9E1, msg)
    # item / medicine list window: the full-width window
    put(rom, 0xFA0E, bytes([0, 1, 0, 20, 6]))


def cursors(rom):
    """Cursor positions (sprite x, y), bank 12: command window $9F75 (Fight / Magic /
    Medicine / Items, then Run for each row), party targets $9F85 (16 px left of the
    sprites). Command text is at panel col 2, rows 1-4 (NES rows 19-22), "Run" at x 51;
    the 16-px hand (owner: FF1's large hand, never over text, may be cut off at the left
    screen edge) ends where the text starts, 2 px above the text row: x 0 (half off the
    GB screen) and x 35 (its left column clears the tail of the "t" of "Fight")."""
    cmd = bytes([0, 150, 0, 158, 0, 166, 0, 174] + [35, 150] * 4)
    put_bank(rom, 12, 0x9F75, cmd, bytes.fromhex('609e60ae60be60ce909e909e909e909e'))
    party = bytes(sum(([140 - 16, y] for y in (0x34, 0x4C, 0x64, 0x7C)), []) * 2)
    put_bank(rom, 12, 0x9F85, party, bytes.fromhex('a034a04ca064a07c' * 2))


def magic_cursor(rom):
    """Magic list cursor (bank 12 $9FBF, entry slot*4 + level-on-page: x, y), for
    MAGPAGE's rows: slots 0 / 1 on row 1 + 2r (columns 2 / 12), slot 2 on row 2 + 2r."""
    cur = bytearray(24)
    for slot in range(3):
        for r in range(2):
            k = r + 4 * slot
            cur[2 * k] = (0, 80, 0)[slot]
            cur[2 * k + 1] = 150 + 16 * r + (8 if slot == 2 else 0)
    o = bank_off(12, 0x9FBF); rom[o:o + 24] = cur


# itemmove (English far code): switching the group also asks for a page redraw
ITEMMOVE_PATCH = [
    ("""    lda $6AAC
    cmp #$10
    beq .item""", """    lda $6AAC
    cmp #1      ; GB: the Item list's cursor x is 1 (hand cut off at the screen edge)
    beq .item"""),
    ("""    lda $6AAA   ; left / right: the same row of the other group
    eor #1
    sta $6AAA
.ix:""", """    lda $6AAA   ; left / right: the same row of the other group
    eor #1
    sta $6AAA
    inc FLIP    ; GB: one group per page
.ix:"""),
    ("""    sta $6AAB
    lda $6AAA
    eor #1
    sta $6AAA
    rts""", """    sta $6AAB
    lda $6AAA
    eor #1
    sta $6AAA
    inc FLIP
    rts"""),
]
ITEMFLIP = 0xF633   # fixed bank, after the panel-clear hook ($F625-$F632)


def item_list(rom):
    """Item list paging: cursor table $9FD7 (column*8 + row*2 -> x, y): both groups at
    x 1 (hand cut off at the screen edge; itemmove tells the Item list apart by x = 1),
    rows 1-4. b12:$9D8C (itemmove via farjsr) gets
    JSR + JMP ITEMFLIP (the old routine's dead bytes $9D91-$9D93 are overwritten).
    ITEMFLIP: if FLIP, clear it, drop the item window and draw the other group's page."""
    main = sys.modules['__main__']
    farjsr, flip = main.LABELS_EX['farjsr'], main.EX['FLIP']
    o = bank_off(12, 0x9FD7)
    rom[o:o + 16] = bytes(v for c in range(2) for r in range(4) for v in (1, 150 + 8 * r))
    put_bank(rom, 12, 0x9D8C, bytes([0xA2, main.FAR_ROUTINES.index('itemmove'), 0x20, farjsr & 0xFF, farjsr >> 8,
                                     0x4C, ITEMFLIP & 0xFF, ITEMFLIP >> 8]),
             bytes([0xA2, main.FAR_ROUTINES.index('itemmove'), 0x4C, farjsr & 0xFF, farjsr >> 8, 0xC9, 0x80, 0xF0]))
    rts = ITEMFLIP - 1                         # the panel-clear hook's RTS
    put(rom, ITEMFLIP, bytes([0xAD, flip & 0xFF, flip >> 8,                    # LDA FLIP
                              0xF0, (rts - (ITEMFLIP + 5)) & 0xFF,             # BEQ (RTS)
                              0xA9, 0x00, 0x8D, flip & 0xFF, flip >> 8,        # LDA #0 / STA FLIP
                              0x4C, 0x00, 0xF3]))                              # JMP $F300
    put(rom, 0xF300, bytes([0xA9, 0x01, 0x20, 0x0F, 0xF2,                     # LDA #1 / JSR $F20F
                            0x4C, 0x21, 0xF2]))                                 # JMP $F221 (itemlist)


def enemy_target(rom):
    """While an enemy target is chosen (loop b12:$9B55-$9BA6) the enemy-names window shows
    instead of the command window (owner): on entry ($9B55 JSR $9BCB -> stub $AB07) the box
    count is saved and only box 0 (the names) is drawn again ($F652 draws all boxes but the
    last); on exit ($9B9C JSR $97B2 -> stub $9D94, in the dead bytes of the old itemmove)
    all saved boxes are redrawn. (No blinking: owner, 2026-11-18.)"""
    vbox = 0x0344
    put_bank(rom, 12, 0x9B55, bytes([0x20, 0x07, 0xAB]), bytes([0x20, 0xCB, 0x9B]))
    put_bank(rom, 12, 0xAB07, bytes([0xAD, 0xA3, 0x6A, 0x8D, vbox & 0xFF, vbox >> 8,   # LDA $6AA3 / STA VBOX
                                     0xA9, 0x02, 0x8D, 0xA3, 0x6A,                     # LDA #2 / STA $6AA3
                                     0x20, 0x52, 0xF6,                                 # JSR $F652
                                     0x4C, 0xCB, 0x9B]),                               # JMP $9BCB
             bytes(rom[bank_off(12, 0xAB07):bank_off(12, 0xAB07) + 17]))
    put_bank(rom, 12, 0x9B9C, bytes([0x20, 0x94, 0x9D]), bytes([0x20, 0xB2, 0x97]))
    put_bank(rom, 12, 0x9D94, bytes([0x20, 0xB2, 0x97,                                 # JSR $97B2
                                     0xAD, vbox & 0xFF, vbox >> 8, 0x18, 0x69, 0x01,   # LDA VBOX / CLC / ADC #1
                                     0x8D, 0xA3, 0x6A,                                 # STA $6AA3
                                     0x4C, 0x52, 0xF6]),                               # JMP $F652
             bytes(rom[bank_off(12, 0x9D94):bank_off(12, 0x9D94) + 15]))


def medicine_list(rom):
    """Medicine list ($F919): Potion on row 1, Antidote on row 2 (single spacing: the second
    INC $6AA0 at $F962 is dropped); cursor table b12:$9FE7 (copied by $9C06): hand at x 0
    (cut off at the screen edge), rows 1 / 2 (y 150 / 158)."""
    put(rom, 0xF962, bytes([0xEA] * 3), expect=bytes([0xEE, 0xA0, 0x6A]))
    put_bank(rom, 12, 0x9FE7, bytes([0, 150, 0, 158] * 4), bytes.fromhex('18a618b6' * 4))


def hooks(rom):
    """Calls into the far-code routines: the party window is stamped into the panel image
    whenever the panel is cleared ($F618, freed bytes $F625-$F63F; X, Y = 0 and A = 0 as
    before), and each member's HP box update (b12:AA5B, one member per frame) draws the
    member's line in the party window instead."""
    main = sys.modules['__main__']
    farjsr = main.LABELS_EX['farjsr']
    idx = main.FAR_ROUTINES.index
    put(rom, 0xF625, bytes([0x8A, 0x48, 0xA2, idx('party_stamp'), 0x20, farjsr & 0xFF, farjsr >> 8,
                            0x68, 0xAA, 0xA0, 0x00, 0xA9, 0x00, 0x60]))
    put_bank(rom, 12, 0xAA5B, bytes([0xAD, 0x5E, 0x68, 0xA2, idx('party_line'), 0x20, farjsr & 0xFF,
                                     farjsr >> 8, 0x4C, 0xE8, 0xAA]), bytes([0xAD, 0x5E, 0x68, 0x20, 0x45, 0xA1]))


def put_bank(rom, bank, cpu, data, expect):
    o = bank_off(bank, cpu)
    if bytes(rom[o:o + len(expect)]) != expect:
        raise SystemExit('gb_layout: unexpected bytes at b%02d:%04X' % (bank, cpu))
    rom[o:o + len(data)] = data


def party_sprites(rom):
    """Party sprites at NES x = 140 (GB x = 132) instead of 176, beside the enemy area
    (NES cols 2-15 end at x = 127, so the step forward to 132 never overlaps an enemy);
    y stays 48/72/96/120 (GB rows 0-11). The acting member steps 8 px forward ($9951) and
    back ($997C); all other code reads $6AD3."""
    put_bank(rom, 12, 0x9740, bytes([0xA9, 0x8C]), bytes([0xA9, 0xB0]))
    put_bank(rom, 12, 0x9951, bytes([0xA9, 0x84]), bytes([0xA9, 0xA8]))
    put_bank(rom, 12, 0x997C, bytes([0xA9, 0x8C]), bytes([0xA9, 0xB0]))


def apply(rom, report):
    battle_frames(rom)
    battle_panel(rom)
    party_sprites(rom)
    cursors(rom)
    magic_cursor(rom)
    item_list(rom)
    medicine_list(rom)
    enemy_target(rom)
    hooks(rom)
    music_trampoline(rom)
    dialogue(rom)
    main_menu(rom)
    item_menu(rom)
    magic_menu(rom)
    equip_menu(rom)
    status_menu(rom)
    shop_menu(rom)
    report.append('GB layout applied')


# ---- main menu ----------------------------------------------------------------------
# GB (camera 0, 0 = NES columns 0-19, rows 0-17): party window (0, 0, 20, 10) with two
# lines per member (name, level, HP current/max; class or status), commands + Gil
# (0, 9, 12, 9; its top line on the party window's bottom line): commands rows 11-15, Gil
# row 16; orbs window (12, 10, 8, 8) with the orbs 2 x 2 centred (columns 14-17, rows
# 12-15: whole attribute quadrants, two attribute bytes). No class sprites; the cursor
# points at the member lines / commands. Mock-up: tools/gb/mockup.py main_menu.
CAM = {}            # camera stubs in bank 14 (main_menu)
MENU_GB = {}        # menu string overrides for insert.py --gb (id -> text), set by menu_strings()


def menu_strings(enc_txt):
    """Command list one per row (upper row only, one-row newlines); Gil on the window's
    fifth text row (below the orbs). Magic list: one page of three levels (magic_tpl)."""
    MENU_GB[42] = magic_tpl()
    MENU_GB[53] = '{09} Equip  Swap  Drop'  # GB equip screen: Equip / Swap / Drop at GB columns 2 / 9 / 15
    # the equip screen's title and names in lower-row mode (one row: titlexy / memwins put
    # them on the window's first text row)
    MENU_GB[52] = '{09}Weapons'
    MENU_GB[62] = '{09}Armor'
    MENU_GB[3] = '{09}Items'                # title windows 7 (titlexy / mtitle)
    # status screen (status_menu): the top window's text in string 38, stats 39, battle 40
    # (upper-row mode: from the window's first text row; values right-aligned by column)
    MENU_GB[35] = MENU_GB[36] = MENU_GB[37] = ''
    MENU_GB[38] = ('{05}{10}{00}{0D}{07}Level{0D}{0D}{10}{03}{08}{10}{01}{08}Experience EP{08}'
                   '{0D}{0D}{10}{04}{08}Until next level{08}{0D}{0E}{10}{42}')
    MENU_GB[39] = '{05}' + '{08}'.join('{0D}{01}%s{0D}{11}{10}{%02X}' % (w, 7 + i) for i, w in
                                     enumerate(('Strength', 'Agility', 'Intelligence', 'Vitality', 'Luck')))
    MENU_GB[40] = '{05}' + '{08}'.join('{0D}{01}%s{0D}{10}{10}{%02X}' % (w, 0x3C + i) for i, w in
                                     enumerate(('Weapon', 'Hit Rate', 'Armor', 'Evasion')))
    MENU_GB[41] = '{09} {10}'
    for i in range(4):
        MENU_GB[54 + 2 * i] = '{09} {%02X}' % (0x10 + i)
    MENU_GB[2] = ('{05}' + '{08}'.join('  ' + w for w in ('Items', 'Magic', 'Weapons', 'Armor', 'Status'))
                  + '{08}{04}Gil')      # Gil below the commands (amount 6 wide + 'Gil': 9 of 10 columns)


def main_menu(rom):
    B = 14
    def wput(i, geom):
        put_bank(rom, B, 0xBAB5 + 4 * i, bytes(geom), bytes(rom[bank_off(B, 0xBAB5 + 4 * i):bank_off(B, 0xBAB5 + 4 * i) + 4]))
    wput(1, (0, 0, 20, 10))                 # party
    wput(6, (0, 9, 12, 9))                  # commands + Gil
    wput(0, (12, 10, 8, 8))                 # orbs
    # $B84D: orbs, commands (the Gil window 5 is not drawn: Gil is in the command string);
    # member windows 2-4 not drawn (the party window holds all)
    put_bank(rom, B, 0xB853, bytes([0xEA, 0xEA, 0xEA]), bytes([0x20, 0x81, 0xB8]))
    for a in (0xB865, 0xB86F, 0xB879):
        put_bank(rom, B, a, bytes([0xEA, 0xEA, 0xEA]), bytes([0x20, 0x02, 0xB9]))
    # orbs: rows 12-15, columns 14-17 ($218E, $2190, $21CE, $21D0); attributes: orbattr
    for a, v in ((0xB891, 0x8E), (0xB89B, 0x90), (0xB8A5, 0xCE), (0xB8AF, 0xD0)):
        put_bank(rom, B, a, bytes([v]), bytes(rom[bank_off(B, a):bank_off(B, a) + 1]))
    put_bank(rom, B, 0xB8DF, bytes([0x21]), bytes([0x20]))
    put_bank(rom, B, 0xB8EF, bytes([0x21]), bytes([0x20]))

    # no class sprites ($B648: four sprites via $EC8C)
    put_bank(rom, B, 0xB648, bytes([0x60]), bytes([0xA9]))
    # cursors: commands (x 0, rows 11-15 -> y 87 + 8i), members (x 0, rows 1+2m -> y 7 + 16m)
    put_bank(rom, B, 0xB7D5, bytes([0x00]), bytes([0x08]))
    put_bank(rom, B, 0xB7F4, bytes([87, 95, 103, 111, 119]), bytes([0x90, 0xA0, 0xB0, 0xC0, 0xD0]))
    put_bank(rom, B, 0xB7EC, bytes([0, 7, 0, 23, 0, 39, 0, 55]), bytes([0x48, 0x10, 0x98, 0x10]))
    # member lines: $B995 rewritten (A = member * $40)
    import json
    sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__))))
    main = sys.modules['__main__']
    ENC = main.ENC
    # line 1: name (col 2), L + level (cols 7-9), HP current/max (cols 11-17);
    # line 2: the class, or the status word (Stone / Poison) instead while afflicted
    tpl = bytes([0x05, 0x10, 0x00, 0x0D, 7, ENC['L'], 0x10, 0x03, 0x0D, 11, 0x10, 0x05, ENC['/'], 0x10, 0x06,
                 0x08, 0x0D, 3, 0x10, 0x01, 0x00])
    st = len(tpl) - 2                       # offset of the parameter of the second line's code
    src = """
mbuild:             ; A = member * $40: two lines at rows 1 + 2m / 2 + 2m of the party window
    rol a
    rol a
    rol a
    and #3
    tax
    asl a           ; (upper-row mode writes at row $3B - 1)
    clc
    adc #2
    sta $3B
    lda #2
    sta $3A
    txa
    ora #$10
    sta $10
    ldy #0
mb1:
    lda mtpl,y
    cmp #$10        ; member code (parameters here are never $10)
    bne mb2
    lda $10
mb2:
    sta $0300,y
    iny
    cpy #TL
    bne mb1
    txa             ; status 2 / 3 (Stone, Poison): the status word instead of the class
    ror a
    ror a
    ror a
    and #$C0
    tay
    lda $6101,y
    cmp #2
    bcc mb3
    lda #2
    sta $0300 + ST
mb3:
    lda #0
    sta $3E
    lda #3
    sta $3F
    jmp $B957
orbattr:            ; $B8B8: orb palettes ($17: orb n in bits 2n) into the right quadrants of
    lda $2002       ;   $23DB (orbs 0 / 2) and the left ones of $23DC (orbs 1 / 3)
    lda #$23
    sta $2006
    lda #$DB
    sta $2006
    lda $17         ;   (the other quadrants: window palette 3)
    and #$33
    asl a
    asl a
    ora #$33
    sta $2007
    lda $17
    and #$CC
    lsr a
    lsr a
    ora #$CC
    sta $2007
    rts
mtpl:
    .db %s
""" % ', '.join('$%02X' % b for b in tpl)
    r = asm(src, syms={'TL': len(tpl), 'ST': st}, org=0xB995)
    assert r.org + len(r.bytes) <= 0xBA80, hex(r.org + len(r.bytes))
    put_bank(rom, B, 0xB995, r.bytes, bytes([0x48, 0xAA, 0xA9, 0x03]))
    put_bank(rom, B, 0xB8B8, bytes([0x4C]) + r.labels['orbattr'].to_bytes(2, 'little'), bytes([0xAD, 0x02, 0x20]))
    # camera: menu screens (clear $9C02) at the field camera, the main menu at 0, 0, and
    # back to the field camera when the menu closes ($AE15)
    src = """
camfield:
    lda #6
    sta $5800
    sta $5801
    lda $2002
    rts
cammenu:
    jsr $9C02
    lda #0
    sta $5800
    sta $5801
    rts
camexit:
    jsr camfield
    lda #0
    sta $2001
    rts
"""
    r = asm(src, org=0xB82C)
    assert r.org + len(r.bytes) <= 0xB84D, hex(r.org + len(r.bytes))
    put_bank(rom, B, 0xB82C, r.bytes, bytes(rom[bank_off(B, 0xB82C):bank_off(B, 0xB82C) + 2]))
    CAM['menu'] = r.labels['cammenu']
    put_bank(rom, B, 0x9C02, bytes([0x20]) + r.labels['camfield'].to_bytes(2, 'little'), bytes([0xAD, 0x02, 0x20]))
    put_bank(rom, B, 0xB84D, bytes([0x20]) + r.labels['cammenu'].to_bytes(2, 'little'), bytes([0x20, 0x02, 0x9C]))
    put_bank(rom, B, 0xAE15, bytes([0x20]) + r.labels['camexit'].to_bytes(2, 'little') + bytes([0xEA, 0xEA]),
             bytes([0xA9, 0x00, 0x8D, 0x01, 0x20]))


# Items screen (camera 0, 0): title window 7 (0,0,8,3); list window (0,3,20,15) with 13
# items per page (rows 4-16, names from column 3, the hand at the screen edge); the list
# turns to the next / previous page when the cursor passes its end (at most 23 items:
# 17 key items + 6 others = 2 pages) and is redrawn when the cursor moves after a
# description (window 8, (0,9,20,9): up to 7 lines of 18 letters) covered it.
ITEM_PAGE = 13
IPAGE, IROW, IDESC = 0x0340, 0x0341, 0x0342        # page start, row counter, description shown
ITEM_FIX = """
itemscr:            ; $EFA7 (bank 14 $B13C, LCD off): window, item list, first page
    lda #0
    sta IPAGE
    sta IDESC
    sta $5800       ; GB camera (0, 0)
    sta $5801
    jsr listwin
    ldx #0          ; list of item numbers held: $0300 (key items 1-17, then $16-$1B)
    ldy #1
ib1:
    lda $6020,y
    beq ib2
    tya
    sta $0300,x
    inx
ib2:
    iny
    cpy #$12
    bcc ib1
    cpy #$16
    bcc ib2
    cpy #$1C
    bcc ib1
    cpx #0
    bne ib3
    sec
    rts
ib3:
    stx $63
    lda #0
    sta $0300,x
    jsr drawpage
    clc
    rts
drawpage:           ; items IPAGE .. IPAGE+12 at rows 4-16, column 3
    lda #0
    sta IROW
dp1:
    lda IPAGE
    clc
    adc IROW
    tax
    lda $0300,x
    beq dp3
    sta $0322
    ldy #$09        ; lower row only
    sty $0320
    ldy #$02        ; item name
    sty $0321
    ldy #3
    cmp #$16
    bcc dp2
    tax             ; count after the name
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
dp2:
    lda #0
    sta $0320,y
    lda #$20
    sta $3E
    lda #$03
    sta $3F
    lda #3
    sta $3A
    lda IROW
    clc
    adc #4
    sta $3B
    jsr $DEB6
    inc IROW
    lda IROW
    cmp #PAGE
    bcc dp1
dp3:
    rts
"""
ITEM_B14 = """
pagechk:            ; $B621 (cursor moved, $62 set): turn the page / remove a description
    ldy #0
    lda $62
    cmp #PAGE
    bcc pc1
    ldy #PAGE
pc1:
    lda IDESC
    bne pc2
    cpy IPAGE
    beq pc3
pc2:
    sty IPAGE
    lda #0
    sta IDESC
    lda #1
    sta $37
    jsr listwin
    jsr drawpage
pc3:
    jmp $B784
deschk:             ; $B93E: every description window marks the list as covered
    pha
    lda #1
    sta $37
    sta IDESC
    jmp $B943
listwin:            ; list window (0, 3, 20, 15): frame, interior cleared
    lda #0
    sta $38
    lda #3
    sta $39
    lda #20
    sta $3C
    lda #15
    sta $3D
    lda #$0E
    sta $57
    jmp $E0F2
curpos:             ; bank 14 $B7DB: hand at x 0, row 4 + cursor - page
    lda $62
    sec
    sbc IPAGE
    asl a
    asl a
    asl a
    adc #31
    sta $41
    lda #0
    sta $40
    jmp $ED24
"""


def item_menu(rom):
    B = 14
    def wput(i, geom):
        put_bank(rom, B, 0xBAB5 + 4 * i, bytes(geom), bytes(rom[bank_off(B, 0xBAB5 + 4 * i):bank_off(B, 0xBAB5 + 4 * i) + 4]))
    wput(7, (0, 0, 8, 3))                   # title
    wput(8, (0, 9, 20, 9))                  # descriptions / prompts
    syms = {'IPAGE': IPAGE, 'IROW': IROW, 'IDESC': IDESC, 'PAGE': ITEM_PAGE}
    q0 = asm(ITEM_B14, syms=dict(syms, drawpage=0), org=0xBA14)       # member-window code)
    r = asm(ITEM_FIX, syms=dict(syms, listwin=q0.labels['listwin']), org=0xEFA7)
    assert r.org + len(r.bytes) <= 0xF05B, hex(r.org + len(r.bytes))
    put(rom, 0xEFA7, r.bytes, bytes([0xA9, 0x00, 0x85, 0x38]))
    q = asm(ITEM_B14, syms=dict(syms, drawpage=r.labels['drawpage']), org=0xBA14)   # after mbuild (old
    assert q.org + len(q.bytes) <= 0xBA80, hex(q.org + len(q.bytes))
    put_bank(rom, B, q.org, q.bytes, bytes(rom[bank_off(B, q.org):bank_off(B, q.org) + len(q.bytes)]))
    put_bank(rom, B, 0xB7DB, bytes([0x4C]) + q.labels['curpos'].to_bytes(2, 'little'), bytes([0xA5, 0x62, 0x0A]))
    put_bank(rom, B, 0xB623, bytes([0x4C]) + q.labels['pagechk'].to_bytes(2, 'little'), bytes([0x4C, 0x84, 0xB7]))
    put_bank(rom, B, 0xB93E, bytes([0x4C]) + q.labels['deschk'].to_bytes(2, 'little'), bytes([0x48, 0xA9, 0x01]))


# Magic screen (camera 0, 0): title window 7 (member name), list window 9 (0,3,20,15)
# with three levels per page: a level line ("L1" and "MP cur/max") and the three spells
# below it from column 3 (rows 5-16). The cursor moves as on the NES (up/down: levels,
# left/right: spells of the level); a level on another page turns the page. String 42 is
# the page of levels 1-3; for the other pages magpatch (far code) adds 3 * page to the
# level digits / MP parameters and 9 * page to the spell parameters in the copy at $6C00
# (and cuts the third level on page 3).
MPAGE, MLAST, MD1, MD3 = 0x0349, 0x034A, 0x034C, 0x034D


def magic_tpl():
    out = '{09}'
    for k in range(3):
        out += '{0D}{01}L%d{0D}{0B}MP {10}{%02X}/{10}{%02X}{08}' % (k + 1, 0x2C + k, 0x34 + k)
        for c in range(3):
            out += '{0D}{03}{10}{%02X}{08}' % (0x14 + 3 * k + c)
    return out


def enc_str(enc, s):
    out = bytearray(); i = 0
    while i < len(s):
        if s[i] == '{':
            j = s.index('}', i); out.append(int(s[i + 1:j], 16)); i = j + 1
        else: out.append(enc[s[i]]); i += 1
    return bytes(out)


def magpatch_source(enc):
    t = magic_tpl()
    b = enc_str(enc, t)
    offs, muls = [], []
    for k in range(3):                      # find each level's patchable bytes
        i = b.index(bytes([enc['L'], enc[str(k + 1)]])) + 1
        offs.append(i); muls.append(0)
        for v, m in ((0x2C + k, 0), (0x34 + k, 0)) + tuple((0x14 + 3 * k + c, 1) for c in range(3)):
            j = b.index(bytes([0x10, v])) + 1
            offs.append(j); muls.append(m)
    blk3 = enc_str(enc, t[:t.index('{0D}{01}L3')]).__len__()
    assert len(b) + 1 <= 0xC1
    return """
magpatch:           ; (far, every menu string) the magic list page MPAGE in the copy of
    lda $6C00       ;   string 42 at $6C00 (recognised by its start: 09 0D 01 'L')
    cmp #$09
    bne mp4
    lda $6C01
    cmp #$0D
    bne mp4
    lda $6C02
    cmp #$01
    bne mp4
    lda $6C03
    cmp #%d
    bne mp4
    lda MPAGE
    asl a
    adc MPAGE
    sta MD1         ; 3 * page
    asl a
    adc MD1
    sta MD3         ; 9 * page
    ldx #%d
mp1:
    ldy MPOFS,x
    lda MPMUL,x
    bne mp2
    lda $6C00,y
    clc
    adc MD1
    jmp mp3
mp2:
    lda $6C00,y
    clc
    adc MD3
mp3:
    sta $6C00,y
    dex
    bpl mp1
    lda MPAGE
    cmp #2
    bne mp4
    lda #0
    sta $6C00 + %d
mp4:
    rts
MPOFS:
    .db %s
MPMUL:
    .db %s
""".replace('MPAGE', '$%04X' % MPAGE).replace('MD1', '$%04X' % MD1).replace('MD3', '$%04X' % MD3) % (
        enc['L'], len(offs) - 1, blk3, ', '.join(map(str, offs)), ', '.join(map(str, muls)))


def exram_source(far_routines):
    """GB menu code in ExRAM (reachable from every bank)."""
    return """
gbmagcur:           ; bank 14 $B829 (each frame of the magic list): page, then the hand
    lda $62
    lsr a
    lsr a
    tax
    lda gbmpg,x
    cmp MPAGE
    bne gbm1
    ldy IDESC
    beq gbm2
    ldy $62
    cpy MLAST
    beq gbm2
gbm1:
    sta MPAGE
    lda #0
    sta IDESC
    lda #1
    sta $37
    lda #9
    jsr $B902
    ldy #$C0
    lda #$2A
    jsr $B96E
gbm2:
    lda $62
    sta MLAST
    lsr a
    lsr a
    tax
    lda gbmky,x
    sta $41
    lda $62
    and #3
    asl a
    asl a
    asl a
    adc $41
    sta $41
    lda #0
    sta $40
    jmp $ED24
gbmpg:
    .db 0, 0, 0, 1, 1, 1, 2, 2
gbmky:              ; y of spell 1 of level L: row 6 + 4 * (L - 3 * page) -> 8 * row - 1
    .db 47, 79, 111, 47, 79, 111, 47, 79
gbmagini:           ; bank 14 $BA80 (magic list, LCD off): page 1
    lda #0
    sta MPAGE
    sta IDESC
    lda #9
    jmp $B902
gbm957:             ; bank 14 $B957 (each menu string): the magic list page
    ldx #MAGPATCH
    jmp farjsr
""".replace('MPAGE', '$%04X' % MPAGE).replace('MLAST', '$%04X' % MLAST)\
        .replace('IDESC', '$%04X' % IDESC).replace('MAGPATCH', str(far_routines.index('magpatch')))


def magic_menu(rom):
    B = 14
    main = sys.modules['__main__']
    ex = main.LABELS_EX
    put_bank(rom, B, 0xBAB5 + 4 * 9, bytes((0, 3, 20, 15)), bytes(rom[bank_off(B, 0xBAB5 + 36):bank_off(B, 0xBAB5 + 40)]))
    put_bank(rom, B, 0xBA80, bytes([0x20]) + ex['gbmagini'].to_bytes(2, 'little') + bytes([0xEA, 0xEA]),
             bytes([0xA9, 0x09, 0x20, 0x02, 0xB9]))
    put_bank(rom, B, 0xAEB3, bytes([0x20]) + CAM['menu'].to_bytes(2, 'little'), bytes([0x20, 0x02, 0x9C]))
    put_bank(rom, B, 0xB829, bytes([0x4C]) + ex['gbmagcur'].to_bytes(2, 'little'), bytes([0x4C]))
    ms = bytes([0x20]) + ex['m_setbank'].to_bytes(2, 'little')
    put_bank(rom, B, 0xB957, bytes([0x20]) + ex['gbm957'].to_bytes(2, 'little') + ms, ms + bytes([0xEA, 0xEA, 0xEA]))


# Weapons / Armor screens (camera X = 1, Y = 0: GB column = NES column - 1; the hands at
# NES x 0 show cut off at the left screen edge). Top window 0 = NES (1,0,20,4): title
# (row 1) and "Equip  Swap  Drop" (row 2; the chosen command's attribute highlight, barhl,
# moved there). Two members per page: windows (1,4,20,7) / (1,11,20,7), name on the first
# row, the four slots below ("E" mark + up to 17 letters from GB column 1). The slot
# cursor on a member of the other page turns the page (members, names, slots redrawn).
# Swap shows both hands without blinking (the held slot's hand 4 px right).
EPAGE, EROW = 0x034E, 0x034F
EQ_ROWS = [6, 7, 8, 9, 13, 14, 15, 16]     # slot rows of the page's 8 slots
EQ_FIX = """
    org $ED84
eloop:              ; A = slot: draws slots A..15 that are on page EPAGE
    pha
    lsr a
    lsr a
    lsr a
    cmp EPAGE
    bne enext
    pla
    pha
    and #7
    tax
    lda erows,x
    sta $3B
    lda #2
    sta $3A
    lda #<eclr      ; clear the row first
    sta $3E
    lda #>eclr
    sta $3F
    jsr $DEB6
    pla
    pha
    tax
    lda #$09
    sta SLOT
    lda #$FF
    sta SLOT+1
    lda #0
    sta SLOT+2
    lda $0300,x
    sta $12
    and #$7F
    beq edraw
    clc
    adc $67
    sta SLOT+3
    lda #2
    sta SLOT+2
    lda #0
    sta SLOT+4
    lda $12
    bpl edraw
    lda #$C7        ; E : equipped
    sta SLOT+1
edraw:
    lda #<SLOT
    sta $3E
    lda #>SLOT
    sta $3F
    jsr $DEB6
enext:
    pla
    clc
    adc #1
    cmp #$10
    bcc eloop
    lda #$0E
    sta $57
    sta $58
    jmp $FE03
erows:
    .db %s
eclr:               ; 18 blanks, lower row only
    .db 9, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, 0
""" % ', '.join(map(str, EQ_ROWS))
EQ_WIN = """
    org $BE25
    jsr memwins
    jmp $BE61
memwins:            ; the page's two members: windows 1 / 2 ((1, 4 / 11, 20, 7)), the name on
    ldx #0          ;   the first text row (the window drawer leaves $3B = y + 2)
mw1:
    stx EROW
    inx
    txa
    jsr $BE71
    lda EPAGE
    asl a
    ora EROW
    asl a
    adc #$36        ; string 54 + 2 * member
    dec $3B
    jsr $B94B
    ldx EROW
    inx
    cpx #2
    bcc mw1
    rts
slotpos:            ; A = slot -> $41 = 8 * row - 1
    and #7
    tax
    lda erows,x
    asl a
    asl a
    asl a
    sbc #0
    sta $41
    rts
titlexy:            ; $BE18: the title on the top window's first text row
    dec $3B
    jmp $B94B
"""
EQ_CUR_A = """
heldhand:           ; A = held slot: its hand 4 px right, if on this page
    tay
    lsr a
    lsr a
    lsr a
    cmp EPAGE
    bne hh1
    tya
    jsr slotpos
    lda #4
    sta $40
    jmp $ED24
hh1:
    rts
"""
EQ_CUR_B = """
    org $BEB7
    lda $63         ; swap (second choice): the held slot's hand, then the cursor
    jsr heldhand
    jmp $BEC8
cmdxy:              ; $BE1B: the command string at (2, 2) inside the top window
    lda #2
    sta $3A
    sta $3B
    rts
"""
EQ_CAM = """
camequip:           ; $BE06: camera X = 1, Y = 0, page 1
    jsr $9C02
    lda #1
    sta $5800
    lda #0
    sta $5801
    sta EPAGE
    rts
"""
EQ_CUR_C = """
slotcur:            ; $BEC8: hand at the slot cursor $62 (turns the page first)
    lda $62
    lsr a
    lsr a
    lsr a
    cmp EPAGE
    beq sc1
    sta EPAGE
    jsr memwins
    jsr $ED69
sc1:
    lda $62
    jsr slotpos
    lda #0
    sta $40
    jsr $ED24
    jmp $BEF9       ; and the hand at the chosen command (no colour highlight)
"""


def equip_menu(rom):
    B = 14
    main = sys.modules['__main__']
    syms = {'EPAGE': EPAGE, 'EROW': EROW, 'SLOT': main.EX['SLOT']}
    f = asm(EQ_FIX, syms=syms)
    assert f.org + len(f.bytes) <= 0xEE21, hex(f.org + len(f.bytes))
    put(rom, 0xED84, f.bytes, bytes([0x48, 0xAA, 0x0A]))
    syms.update(erows=f.labels['erows'])
    w = asm(EQ_WIN, syms=syms)
    assert w.org + len(w.bytes) <= 0xBE61, hex(w.org + len(w.bytes))
    put_bank(rom, B, 0xBE25, w.bytes, bytes([0xA9, 0x03, 0x20, 0x71, 0xBE]))
    syms.update(memwins=w.labels['memwins'], slotpos=w.labels['slotpos'])
    ca = asm(EQ_CUR_A, syms=syms, org=0xBE9B)         # window table entries 3-9 (not used)
    assert ca.org + len(ca.bytes) <= 0xBEB7, hex(ca.org + len(ca.bytes))
    syms.update(ca.labels)
    cb = asm(EQ_CUR_B, syms=syms)
    assert cb.org + len(cb.bytes) <= 0xBEC8, hex(cb.org + len(cb.bytes))
    cc = asm(EQ_CUR_C, syms=syms, org=0xBEC8)         # + the old slot cursor table
    assert cc.org + len(cc.bytes) <= 0xBEF9, hex(cc.org + len(cc.bytes))
    old = bytes(rom[bank_off(B, 0xBE93):bank_off(B, 0xBEF9)])
    assert old[0x24:0x26] == bytes([0xA5, 0xF0]), old[0x24:0x26].hex()     # $BEB7: LDA $F0
    new = bytearray(old)
    new[0:8] = bytes([1, 4, 20, 7, 1, 11, 20, 7])     # windows 1 / 2: the page's members
    new[8:8 + len(ca.bytes)] = ca.bytes
    new[0x24:0x24 + len(cb.bytes)] = cb.bytes
    new[0x35:0x35 + len(cc.bytes)] = cc.bytes
    put_bank(rom, B, 0xBE93, bytes(new), old)
    # window 0: the top window (1,0,20,4); the command string's position instead of window 1
    put_bank(rom, B, 0xBE8F, bytes([1, 0, 20, 4]), bytes([0, 1, 9, 4]))
    put_bank(rom, B, 0xBE1B, bytes([0x20]) + cb.labels['cmdxy'].to_bytes(2, 'little') + bytes([0xEA, 0xEA]),
             bytes([0xA9, 0x01, 0x20, 0x71, 0xBE]))
    put_bank(rom, B, 0xBE18, bytes([0x20]) + w.labels['titlexy'].to_bytes(2, 'little'), bytes([0x20, 0x4B, 0xB9]))
    # title window 7 (Items, magic: member name): on its text row, not on the bottom frame
    put_bank(rom, B, 0xB937, bytes([0x4C]) + w.labels['titlexy'].to_bytes(2, 'little'), bytes([0x4C, 0x4B, 0xB9]))
    m = asm('''
mtitle:             ; $AEC1: the magic screen's title (member name) one row up
    dec $3B
    jmp $B96C
''', org=0xBA73)
    assert m.org + len(m.bytes) <= 0xBA80
    put_bank(rom, B, 0xBA73, m.bytes, bytes(rom[bank_off(B, 0xBA73):bank_off(B, 0xBA73) + len(m.bytes)]))
    put_bank(rom, B, 0xAEC1, bytes([0x20]) + m.labels['mtitle'].to_bytes(2, 'little'), bytes([0x20, 0x6C, 0xB9]))
    ce = asm(EQ_CAM, syms=syms, org=0xBF0D)          # old highlight code (dead: $BF0A jumped to ExRAM)
    assert ce.org + len(ce.bytes) <= 0xBF41
    put_bank(rom, B, ce.org, ce.bytes, bytes(rom[bank_off(B, ce.org):bank_off(B, ce.org) + len(ce.bytes)]))
    put_bank(rom, B, 0xBE06, bytes([0x20]) + ce.labels['camequip'].to_bytes(2, 'little'), bytes([0x20, 0x02, 0x9C]))
    # command hands (GB x 0 / 56 / 104 -> NES x 8 / 64 / 112) on row 2
    put_bank(rom, B, 0xBF07, bytes([8, 64, 112]), bytes([80, 144, 192]))
    put_bank(rom, B, 0xBF00, bytes([0xA9, 15]), bytes([0xA9, 0x14]))
    # no colour highlight of the chosen command (on the plain Game Boy the shading codes a
    # tile for one palette only, so letters shared with the red word vanished elsewhere):
    # its hand stays instead (slotcur)
    put_bank(rom, B, 0xBF0A, bytes([0x60]), bytes([0x4C]))
    # top window attributes: all palette 3 ($BE61 wrote the old title box's $7F $DF)
    put_bank(rom, B, 0xBE66, bytes([0xA9, 0xFF, 0x8D, 0x07, 0x20, 0xA9, 0xFF]), bytes([0xA9, 0x7F, 0x8D, 0x07, 0x20, 0xA9, 0xDF]))





# Status screen (camera 0, 0; table bank 14 $B53A, windows drawn with strings 35-40):
# windows 0-3 = the top window (0,0,20,8) (strings 35-37 empty, 38: name + Level, class,
# Experience EP / value, Until next level / value), windows 4 = (0,7,20,11) with the
# stats (39, rows 8-12) and the battle values (40, rows 13-16: window 5 is not drawn, the
# string's row is set by statrow). Class sprite at the right of rows 1-3.
def status_menu(rom):
    B = 14
    top, bot = [0, 0, 20, 8], [0, 7, 20, 11]
    put_bank(rom, B, 0xB53A, bytes(top * 4 + bot * 2), bytes(rom[bank_off(B, 0xB53A):bank_off(B, 0xB53A) + 24]))
    r = asm("""
statrow:            ; $B4FE (instead of window 5): string 40 from row 13
    lda #14
    sta $3B
    rts
""", org=0xBA78)
    assert r.org + len(r.bytes) <= 0xBA80
    put_bank(rom, B, r.org, r.bytes, bytes(rom[bank_off(B, r.org):bank_off(B, r.org) + len(r.bytes)]))
    put_bank(rom, B, 0xB4FE, bytes([0x20]) + r.labels['statrow'].to_bytes(2, 'little') + bytes([0xEA, 0xEA]),
             bytes([0xA2, 0x14, 0x20, 0x23, 0xB5]))
    put_bank(rom, B, 0xB4C9, bytes([0x20]) + CAM['menu'].to_bytes(2, 'little'), bytes([0x20, 0x02, 0x9C]))
    put_bank(rom, B, 0xB50B, bytes([0xA9, 128, 0x85, 0x40, 0xA9, 7]), bytes([0xA9, 0x58, 0x85, 0x40, 0xA9, 0x20]))


# Shops (owner, 2026-11-18: SaGa style, no shop scene, Gil always shown). Camera X = 1
# (GB column = NES column - 1; the list hand at NES x 0 is cut off at the screen edge),
# positions below in GB columns.
#   window 0 speech (0,0,20,6): up to 4 lines of 18 (upper-row mode from row 1)
#   window 2 list   (0,5,20,12): shares the speech window's bottom border; 5 items x 2
#                   rows: name from column 1, price below right-aligned to column 18
#                   (magic shops: "L3" and the price); the price question: line 1
#                   empty, the price before "Gil, see." on line 2
#   window 4 Gil    (0,15,11,3): over the list's bottom-left corner (the last price
#                   row is empty there), drawn again after every list draw
#   window 1 title  (0,6,10,5), window 3 menu / Yes-No / names (10,6,10,6)
# All in the window palette (no scene: the 10x10 picture, the party sprites, the title
# and Gil palettes are dropped).
SHOP = {}
SHOP_WIN = [(1, 0, 20, 6), (1, 6, 10, 5), (1, 5, 20, 12), (11, 6, 10, 6), (1, 15, 11, 3)]   # NES x (camera X 1)


def shop_text(i, en, txt):
    """GB form of shop string i (en: the script text; txt: the NES layout's form)"""
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    main = sys.modules['__main__']
    if i in main.SHOP_TITLES:                 # title: up to 3 words centred in 8 columns
        t = main.SHOP_TITLES[i]
        return '{05}' + ('{08}' if len(t) == 1 else '') + '{08}'.join(' ' * ((8 - len(w)) // 2) + w for w in t)
    if i in main.SHOP_SPEECH:
        if en.startswith('\n'):                # the price (5 wide) is drawn at the start of
            words = en.split()                  #   line 2 (row 2; one row higher its blank upper
                                                #   row would cut the frame): text from GB col 7
            first = ''
            while words and len((first + ' ' + words[0]).strip()) <= 12:
                first = (first + ' ' + words.pop(0)).strip()
            lines = ['', '{0D}{08}' + first] + (main.flow(' '.join(words), 18) if words else [])
        else:
            lines = main.flow(en, 18)
        assert len(lines) <= 4, (i, lines)
        return '{05}' + '{08}'.join(lines)
    if i in (10, 11, 15, 36):                 # menus: one word per row
        return '{05}' + '{08}'.join(' ' + w for w in en.split('\n'))
    return txt


SHOPLIST_PATCH = [
    ("""    lda #$0A            ; wrap width 10: long names on the two rows of the name line
    sta $0310""", """    lda #$05            ; GB: upper-row mode, one-row lines
    sta $0310"""),
    ("""    lda #1
    sta $0312,y
    sta $0317,y
    lda #$0D            ; price at column 26 (5 characters, right edge 30)
    sta $0313,y
    lda #26""", """    lda #8
    sta $0312,y
    sta $0317,y
    lda #$0D            ; GB: price at NES column 15 (GB 14-18)
    sta $0313,y
    lda #15"""),
    ("""magpre:         ; bank 14 $A99C: magic shop list, same name wrapping as the item list
    lda #0
    sta $63
    lda #$0A""", """magpre:         ; bank 14 $A99C: magic shop list, same name wrapping as the item list
    lda #0
    sta $63
    lda #$05"""),
]

SHOP_B14 = """
goldwin:            ; $A804: the Gil window, amount and 'Gil' on its text row
    jsr $AA4E
    dec $3B
    rts
lgold:              ; after the list ($A8C1 / $A9FF): the Gil window over it again
    jsr $A802
    jmp $A925
camshop:            ; $A78E: camera X = 1, Y = 0
    jsr $9C02
    lda #1
    sta $5800
    lda #0
    sta $5801
    rts
"""


def shop_menu(rom):
    B = 14
    main = sys.modules['__main__']
    old = bytes(rom[bank_off(B, 0xAC53):bank_off(B, 0xAC53) + 20])
    new = bytes(w[k] for k in range(4) for w in SHOP_WIN)
    put_bank(rom, B, 0xAC53, new, old)
    put_bank(rom, B, 0xAC6F, b'\xFF' * 64, bytes(rom[bank_off(B, 0xAC6F):bank_off(B, 0xAC6F) + 64]))
    put_bank(rom, B, 0xA7C8, b'\xEA\xEA\xEA', bytes([0x20, 0xCF, 0xDC]))       # no scene
    put_bank(rom, B, 0xAA0D, b'\x60', bytes([0xA9]))                              # no party sprites
    for a in (0xA8BE, 0xA9FC):                      # window 3 is not erased under the list
        put_bank(rom, B, a, b'\xEA\xEA\xEA', bytes([0x20, 0xD5, 0xE1]))
    put_bank(rom, B, 0xA9B9, bytes([0xA9, 0x08]), bytes([0xA9, 0x01]))            # magic list: one-row lines
    r = asm(SHOP_B14, org=0xA86D)                   # old list builder (A86A jumps to ExRAM)
    assert r.org + len(r.bytes) <= 0xA8A9
    put_bank(rom, B, r.org, r.bytes, bytes(rom[bank_off(B, r.org):bank_off(B, r.org) + len(r.bytes)]))
    put_bank(rom, B, 0xA78E, bytes([0x20]) + r.labels['camshop'].to_bytes(2, 'little'), bytes([0x20, 0x02, 0x9C]))
    put_bank(rom, B, 0xA804, bytes([0x20]) + r.labels['goldwin'].to_bytes(2, 'little'), bytes([0x20, 0x4E, 0xAA]))
    for a in (0xA8C1, 0xA9FF):
        put_bank(rom, B, a, bytes([0x4C]) + r.labels['lgold'].to_bytes(2, 'little'), bytes([0x4C, 0x25, 0xA9]))
    # cursors (NES x): menu window (GB x 80, rows 7-10), list (cut off, name rows 6, 8, .. 14)
    put_bank(rom, B, 0xA98A, bytes([88, 55, 88, 63, 88, 71, 88, 79]), bytes(rom[bank_off(B, 0xA98A):bank_off(B, 0xA98A) + 8]))
    put_bank(rom, B, 0xA992, bytes([0, 47, 0, 63, 0, 79, 0, 95, 0, 111]), bytes(rom[bank_off(B, 0xA992):bank_off(B, 0xA992) + 10]))
    a = SHOP['names']                               # party names, one row each
    put_bank(rom, B, 0xA8FC, bytes([0xA9, a & 0xFF, 0x85, 0x3E, 0xA9, a >> 8]), bytes(rom[bank_off(B, 0xA8FC):bank_off(B, 0xA8FC) + 6]))
