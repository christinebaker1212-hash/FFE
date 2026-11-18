"""Game Boy layout for the FF1 English build (applied by `insert.py --gb`).

The GB shows a 20x18-tile part of the NES nametable chosen per screen (camera, see below).
Each screen is re-laid out inside that view in FF1's own code, following the owner's
decisions in CLAUDE.md (SaGa 3 / GB RPG style).

Camera: the NES code selects the GB view per screen by writing tile coordinates to
$5800 (X) / $5801 (Y) (unmapped on the MMC5; the GB runtime moves its view). Default
(field, until a screen sets its own): X = 6, Y = 6.

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
    put(rom, 0xF2DC, bytes([0xA9, 0x01, 0x8D, 0x00, 0x58,      # LDA #1 / STA $5800
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
#   panel text     tiles $A8-$EF: panel row r (1-4), column c (2-19) = $A8 + 18(r-1) + c-2
# The panel image ($691E, 32 bytes per row, NES rows 18-29) gets these tile numbers; the
# glyphs are rendered into a 1-bit line buffer and uploaded in vblank (plane 0 = ink,
# plane 1 = $FF: ink colour 3 on colour 2, as the font).
PANEL = 0x691E
GLYPH_FIRST = 0x7A                       # glyph table covers codes $7A-$FF
DIG3 = 0xD3                              # 3-px digits $D3-$DC, small '/' $DD, arrow $DE
SLASH3, ARROW = 0xDD, 0xDE
STATUS_WORDS = ['Stone', 'Poison', 'Blind', 'Numb', 'Sleep', 'Mute']   # status bits 1-6
FAR_GB = ['party_line', 'party_stamp']   # far routines added for the GB layout (after boxline etc.)

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
    lda VX
    sec
    adc VCNT
    sta VX
.r:
    rts

vstr:               ; draw VSTR from index A up to (not including) index VEND or a 0
    sta VC
.l:
    ldx VC
    cpx VEND
    bcs .r
    lda VSTR,x
    beq .r
    jsr vchar
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

vupload:            ; VN tiles of the buffer -> BG tiles VT.., 4 tiles per vblank
    lda #0
    sta VUP
.chunk:
    jsr $F499
    lda $2002
    lda VT
    clc
    adc VUP
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
    lda #4
    sta VCNT
.tile:
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
    ldy #8
    lda #$FF
.p1:
    sta $2007
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
    beq .target
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
    beq .pl
    inx
    cpx #15
    bne .sv
    lda #0
    sta VATK,x
.pl:
    jsr vtext
.out:
    jmp vrest
.target:            ; row 1 = attacker + " -> " + target
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
    lda VLINE
    bne .nw
    jsr msgwin
    lda #1
    sta VLINE
.nw:
    cmp #2
    bcc .ni
    lda #8
    sta VIND
.ni:
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
    lda #0
    sta VC0
.row:
    lda VW
    beq .done
    sta VN
    lda VROW        ; tiles $A8 + 18(row-1) + col-2
    sec
    sbc #1
    asl a
    sta VT
    asl a
    asl a
    asl a
    clc
    adc VT
    adc VCOL
    adc #$A8-2
    sta VT
    jsr vbreak
    jsr vclear
    lda VIND
    sta VX
    lda VC0
    jsr vstr
    jsr vupload
    ldy #0          ; the row's cells show the tiles
    lda VT
.c:
    sta ($8A),y
    clc
    adc #1
    iny
    cpy VN
    bne .c
    lda VROW
    clc
    adc #1
    cmp VLINE
    bcc .nl
    sta VLINE
.nl:
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
    lda #$FF
    sta VBRK
.l:
    lda VSTR,x
    beq .all
    cmp #$FE
    beq .fe
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
.cut:               ; one word wider than the row: cut it
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
    return out


def enc_word(enc, w):
    return bytes(enc[c] for c in w)


def far_source(enc):
    return 'MUSIC = $%04X\n' % MUSIC + VWF_SRC + glyph_tables(enc)

def battle_panel(rom):
    """Bottom panel (25x12 image at $691E, NES rows 18-29; the GB shows panel rows 0-5,
    cols 1-20). Box records: type 0 = frame (x y w h), type 1 = text (x y, pointer).
    Windows are 6 rows high (panel rows 0-5 = GB rows 12-17), 4 text rows (rows 1-4)."""
    put(rom, 0xF625, bytes([0x60]), expect=bytes([0xA9, 0xFD]))      # (replaced by the hook)
    # enemy names: left window (cols 1-8), names at column 2, rows 1-4
    put(rom, 0xF9DC, bytes([0, 1, 0, 8, 6]), expect=bytes([0, 1, 0, 12, 10]))
    put(rom, 0xF6CC, bytes([0xEA] * 3), expect=bytes([0xEE, 0x9F, 0x6A]))      # text x = box x + 1
    put(rom, 0xF6D2, bytes([0xEA] * 3), expect=bytes([0xCE, 0xA0, 0x6A]))      # no DEC $6AA0
    put(rom, 0xF6D7, bytes([0xEA] * 3), expect=bytes([0xEE, 0xA0, 0x6A]))      # one INC $6AA0
    # command window over the names: Fight Run / Magic / Medicine / Items
    cmd = fixed(rom, 0xFA13)[0]
    ptr = [bytes(rom[cmd + 5 * k + 3:cmd + 5 * k + 5]) for k in range(1, 6)]   # Fight Magic Medicine Items Run
    rec = bytes([0, 1, 0, 8, 6])
    for k, (x, y) in enumerate(((2, 1), (2, 2), (2, 3), (2, 4), (6, 1))):
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
    hooks(rom)
    music_trampoline(rom)
    report.append('GB layout applied')
