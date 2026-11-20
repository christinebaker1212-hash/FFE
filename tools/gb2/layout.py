"""FF2 GB layout: NES-side re-layout of the English FF2 build for the Game Boy's 160x144.

Applied after tools/ff2/insert.py: build/ff2_en.nes -> build/ff2_gb.nes (still an NES ROM:
it runs in cynes, and the GB build of it is checked against it frame by frame). The GB
runtime reads the camera registers written here ($5800-$5805, nothing on the NES; see
tools/gb2/rt/ff2.s). Owner's layouts: docs/ff2-gb-screens.md.

usage: layout.py build/ff2_en.nes build/ff2_gb.nes

Free space used: fixed bank $F800-$F84F (unused code, rom-map.txt) and $FFD0-$FFF9 (the
rom-info block), bank 23 (empty). RAM in battle: $7800-$78DF (the box save stack the
English patch moved to ExRAM: line buffer 136 bytes, tile pool lists 77), $75C0-$75FF, $7FDF-$7FFF (never written by the game), zero
page $D2-$D7 (unused per ram-map.txt) for the renderer's pointers."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
from asm6502 import asm

HDR, BANK = 16, 0x4000


def put(rom, bank, cpu, data, old=None):
    base = 0xC000 if bank == 31 else 0x8000
    o = HDR + bank * BANK + cpu - base
    if old is not None:
        assert rom[o:o + len(old)] == old, ('%02X/%04X' % (bank, cpu), rom[o:o + len(old)].hex(), old.hex())
    rom[o:o + len(data)] = data


# ---------------------------------------------------------------- battle
# GB view (docs/ff2-gb-screens.md): GB lines 0-95 = NES x 20-179, y 48-143 (enemy area +
# party column); lines 96-143 = the windows (second camera).
CAM_BATTLE = dict(x=2, fine=4, y=6, line=96, x2=0, y2=6)
# field camera (tiles): the player sprite (NES x 112-127, y 109-124) centred: x 5 exactly; y 6
# leaves it 3 px above centre (45 px would centre it but puts the 8-px window grid 5 px off
# the screen's). The field windows (dialogue, keyword, shop) are laid out for it.
FIELD_CAM = dict(x=5, y=6)

FIX_SRC = '''
    org $F800
gbf:                    ; X = GB routine index (bank 23 code; its bank to return to: RETB)
    stx GBIDX
    lda #23
    jsr $FA7F           ; (switch with $3E set: the battle NMI's return (long) restores it)
    jsr $8000           ; bank 23 dispatcher
    lda GBRB
    jmp $FA7F
btlcam:                 ; fix:FAB9 (JMP $9639, init battle): battle cameras first
    lda #CX
    sta $5800
    lda #CF
    sta $5802
    lda #CY
    sta $5801
    lda #CY2
    sta $5805
    lda #CL
    sta $5803
    lda #0              ; (second camera X = 0)
    sta $5804
    sta GBPOOL          ; tile pool: made again for this battle
    jmp $9639
fieldcam:               ; fix:FA0F (return from battle; LDA #$0E / JSR $FE1A): no fine X,
    lda #0              ;   no split (the field camera: the map reload after a battle, b0:9C03
                        ;   / b0:9C06 stubs, field_tileset())
    sta $5802
    sta $5803
    lda $FD             ; the field's $2000 (BG table 0) before the field reloads its tiles
    sta $2000           ;   (fix:E512; the GB sends a tile to BG or sprites by $2000 bit 4)
    lda #$0E
    jmp $FE1A
wattr:                  ; fix:D13D (window attributes): metatiles the window covers, for a
    lda $38             ;   window on an odd column too (the field camera is odd): A =
    adc $3C             ;   (($38 + $3C + 1) >> 1) - ($38 >> 1); carry = $38 & 1 on entry
    lsr a
    sec
    sbc $31
    rts
end:
'''


# Battle RAM (free in battle, see the module docstring)
RAM = dict(MV=0x75F0, GBIDX=0x7FDF, GBRB=0x7FE0, GBPOOL=0x7FE1, VX=0x7FE2, VN=0x7FE3, VT=0x7FE4, VC=0x7FE5,
           VSH=0x7FE6, VCNT=0x7FE7, VP=0xD2, VQ=0xD4, VS=0xD6, VNUM=0x7FEC, VPAD=0x7FEE, VDIG=0x7FEF,
           VROW=0x7FF0, VCOL=0x7FF1, VW=0x7FF2, VH=0x7FF3, VLINE=0x7FF4, VSV=0x7FF5, VI=0x7FF6,
           NL=0x7FF7, NS=0x7FF8, VSQZ=0x7FF9, VI0=0x7FFA, VI1=0x7FFB, VCX=0x7FFC, VFILL=0x7FFD, VLN=0x7FFE,
           USED=0x75C0, VBUF=0x7800, BLANKT=0x7888, FTILE=0x7889, PTILE=0x7891, LTILE=0x78B9, XTILE=0x78D1,
           NTBUF=0x78D5, ATKBUF=0x75E0, MOPEN=0x75F0, MLINE=0x75F1, MPAGE=0x75F2,
           LSHOW=0x75C0, LNAV=0x75DC, LBASE=0x75DD, LDGAP=0x7FE8, LCOV=0x7FFF, GBARG=0x7FE9, MSCR=0x7FEA, TBLHI=0x7FEB, MSLOT=0x75F8, SLOTP=0x75FC,
           LWID=0x75E0, LRING=0x75F4, LSCR=0x75F5)    # (L*: treasure screen, after the battle)
# fixed-bank entries (5 bytes each, at $FFD0 and $FEEC): routine, bank to return to (bank 23 RETB), the NES routine replaced
ENTRIES = [('gb_party', 0x0C, 0x912A), ('gb_names', 0x0C, 0x910D), ('gb_names', 0x0C, 0x981D),
           ('gb_cmds', 0x0C, 0x982C), ('gb_msgopen', 0x05, 0xAA57), ('gb_msgclose', 0x05, 0xAB4F),
           ('gb_magic', 0x0C, None), ('gb_magcost', 0x0C, None), ('gb_gear', 0x0C, None),
           ('gb_lootscr', 0x05, None), ('gb_lootf', 0x05, None), ('gb_lootnav', 0x05, None)]
# (None: called from a patched JSR, not replacing a routine)

ENT_SRC = '''
    org $FFD0
'''

B23_SRC = '''
    org $8000
gbdisp:                 ; dispatch GBIDX (word table: entries of the code map)
    ldx GBIDX
    lda RETB,x          ; (bank of the caller, for gbf's return)
    sta GBRB
    txa
    asl a
    tax
    lda gbtab,x
    sta $00
    lda gbtab+1,x
    sta $01
    jmp ($0000)
gbtab:
    .dw GBTAB

; ---- tile pool: table-1 tiles this battle's battlefield does not use
poolinit:
    lda #$10            ; (battle windows: pattern table 1)
    sta TBLHI
    lda GBPOOL
    beq .go
    rts
.go:
    lda #0
    sta LCOV
    ldx #31
.c:
    sta USED,x
    dex
    bpl .c
    lda #$FF            ; $00-$1F: backdrop and fixed battle tiles
    sta USED
    sta USED+1
    sta USED+2
    sta USED+3
    ldy #7
.slot:
    lda $7B62,y         ; monster in this slot?
    bmi .ns
    lda $7B72,y         ; graphics id
    cmp #9
    bcs .boss
    tax
    lda FIRST,x
    sta VT
    lda $7B8A,y         ; width * height tiles from the first
    sta VCNT
    lda #0
    ldx $7B82,y
.mul:
    clc
    adc VCNT
    dex
    bne .mul
    tax
.mk:
    lda VT
    jsr usemark
    inc VT
    dex
    bne .mk
.ns:
    dey
    bpl .slot
    jmp .alloc
.boss:                  ; boss: a precomputed bitmap of its tilemap
    sec
    sbc #9
    asl a
    asl a
    asl a
    asl a
    asl a
    tax
    ldy #0
.bl:
    lda BOSSUSED,x
    ora USED,y
    sta USED,y
    inx
    iny
    cpy #32
    bne .bl
.alloc:                 ; pool: free tiles from $FF down
    ldx #0
    lda #$FF
    sta VT
.al:
    lda VT
    jsr usetest
    bne .an
    lda VT
    sta BLANKT,x        ; blank, 8 frame tiles, party 40, left 24, extra 4 (the message
    inx                 ;   window's 4 x 17 text tiles = party + left + extra)
    cpx #77
    beq .done
.an:
    dec VT
    lda VT
    cmp #$1F
    bne .al
.done:
    lda #0
    sta MOPEN
    lda #1
    sta GBPOOL
    jsr frames          ; frame tiles into the pool
    jmp blank           ; blank tile (BLANKT) over the window rows 18-23

usemark:                ; A = tile: mark used (X, Y kept)
    pha
    sty VSH
    pha
    lsr a
    lsr a
    lsr a
    tay
    pla
    and #7
    sta VC
    lda #$80
.s:
    dec VC
    bmi .o
    lsr a
    jmp .s
.o:
    ora USED,y
    sta USED,y
    ldy VSH
    pla
    rts
usetest:                ; A = tile: Z clear if used (X kept)
    sty VSH
    pha
    lsr a
    lsr a
    lsr a
    tay
    pla
    and #7
    sta VC
    lda #$80
.s:
    dec VC
    bmi .o
    lsr a
    jmp .s
.o:
    and USED,y
    ldy VSH
    and #$FF
    rts

; ---- CHR upload (in vblank, after the game's frame wait): VN tiles of VBUF (1 bit per
; pixel) as ink colour 3 on window colour 2 into pattern table 1 at the tiles listed at
; (VP), at most 6 per frame; then the battle scroll as fix:FD46 leaves it
vupload:
    lda #0
    sta VC
.frame:
    jsr $FA2A           ; wait for vblank
    lda #6
    sta VCNT
.tile:
    lda VC
    cmp VN
    bcs .end
    tay
    lda (VP),y
    jsr vtile
    inc VC
    dec VCNT
    bne .tile
    jsr scroll
    jmp .frame
.end:
    jmp scroll
vtile:                  ; A = tile: its 16 bytes (plane 0 VBUF + 8 VC, plane 1 $FF) to the
    pha                 ;   pattern table. On the GB native (hle_vtile, rt/ff2_banked.s:
    lsr a               ;   one tile write, one re-coding mark). Exit: A = $FF, X = 8 VC + 8,
    lsr a               ;   Y = 0, Z = 1, N = 0, C = 0.
    lsr a
    lsr a
    ora TBLHI
    sta $2006
    pla
    asl a
    asl a
    asl a
    asl a
    sta $2006
    lda VC
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
    lda #$FF
    ldy #8
.p1:
    sta $2007
    dey
    bne .p1
    clc
    rts
scroll:
    lda MSCR            ; field menu (camera 1 / 1): its $2000, no scroll, the music
    beq .b
    lda $FF
    sta $2000
    lda #0
    sta $2005
    sta $2005
    jmp $C74F
.b:
    lda $3B
    sta $2000
    lda $39
    sta $2005
    lda $37
    sta $2005
    rts

frames:                 ; the 8 frame tiles (ROM font $F7-$FE, copied at build time) to FTILE
    lda #<FRAMEGFX
    sta VQ
    lda #>FRAMEGFX
    sta VQ+1
    lda #0
    sta VC
.f:
    jsr $FA2A
    ldy VC
    lda FTILE,y
    pha
    lsr a
    lsr a
    lsr a
    lsr a
    ora #$10
    sta $2006
    pla
    asl a
    asl a
    asl a
    asl a
    sta $2006
    ldy #0
.b:
    lda (VQ),y
    sta $2007
    iny
    cpy #16
    bne .b
    clc
    lda VQ
    adc #16
    sta VQ
    lda VQ+1
    adc #0
    sta VQ+1
    jsr scroll
    inc VC
    lda VC
    cmp #8
    bne .f
    rts

blank:                  ; tile BLANKT = window colour 2; NES rows 18-23 cols 0-31 filled with it
    jsr $FA2A
    lda BLANKT
    jsr tileaddr
    lda #0
    ldx #8
.p0:
    sta $2007
    dex
    bne .p0
    lda #$FF
    ldx #8
.p1:
    sta $2007
    dex
    bne .p1
    jsr scroll
    lda #18
    sta VLINE
.r:
    jsr $FA2A
    lda #$22            ; row 18 = $2240, row k = $2000 + 32k
    sta VSH
    lda VLINE
    asl a
    asl a
    asl a
    asl a
    asl a
    sta VT
    lda VLINE
    lsr a
    lsr a
    lsr a
    ora #$20
    sta $2006
    lda VT
    sta $2006
    lda BLANKT
    ldx #32
.f:
    sta $2007
    dex
    bne .f
    jsr scroll
    inc VLINE
    lda VLINE
    cmp #24
    bne .r
    rts
tileaddr:               ; A = tile: PPU address of its pattern (table TBLHI)
    pha
    lsr a
    lsr a
    lsr a
    lsr a
    ora TBLHI
    sta $2006
    pla
    asl a
    asl a
    asl a
    asl a
    sta $2006
    rts

; ---- small-font renderer: VBUF holds VN tiles of one text line (tile-major, 8 rows)
vclear:
    lda VN
    asl a
    asl a
    asl a
    tax
    lda #0
    sta VX
.c:
    dex
    sta VBUF,x
    bne .c
    rts
vchar:                  ; A = code: draw its glyph at VX (columns, bit 7 = top row)
    tax
    lda GW,x            ; width (0: no glyph)
    beq .sp
    sta VCNT
    lda GOFF,x
    sta VQ
    lda GHI,x
    sta VQ+1
    ldy #0
.col:
    lda VX
    lsr a
    lsr a
    lsr a
    cmp VN
    bcs .full
    asl a
    asl a
    asl a
    sta VT              ; VBUF offset of the tile
    lda VX
    and #7
    tax
    lda BIT,x
    sta VC              ; pixel bit
    lda (VQ),y
    sta VSH
    ldx VT
.row:
    asl VSH
    bcc .n
    lda VBUF,x
    ora VC
    sta VBUF,x
.n:
    inx
    txa
    and #7
    bne .row
    inc VX
    iny
    dec VCNT
    bne .col
    lda VSQZ            ; 1-px gap (none in a squeezed name)
    bne .full
    inc VX
.full:
    rts
.sp:
    lda VX
    clc
    adc #2
    sta VX
    rts
vstr:                   ; draw the 0-terminated codes at (VQ+... in VP) -> VX
    ldy #0
.l:
    lda (VP),y
    beq .e
    sty VDIG
    jsr vchar
    ldy VDIG
    iny
    bne .l
.e:
    rts
vwidth:                 ; A = code -> A = its advance (pixels)
    tax
    lda GW,x
    beq .sp
    clc
    adc #1
    rts
.sp:
    lda #2
    rts
vnum:                   ; VNUM (16 bits) in small digits, right edge at A (pixels)
    sta VPAD
    ldx #0
.d:                     ; digits into NTBUF (most significant first), at least one
    lda #0
    sta VDIG
.sub:
    lda VNUM
    sec
    sbc POW,x
    tay
    lda VNUM+1
    sbc POWH,x
    bcc .nd
    sta VNUM+1
    sty VNUM
    inc VDIG
    jmp .sub
.nd:
    lda VDIG
    sta NTBUF,x
    inx
    cpx #4
    bne .d
    ldx #0              ; skip leading zeros (keep the last)
.z:
    lda NTBUF,x
    bne .w
    inx
    cpx #3
    bne .z
.w:
    stx VI
    lda VPAD            ; VX = right edge - 4 * digits
    ldy VI
.wx:
    cpy #4
    beq .wd
    sec
    sbc #4
    iny
    bne .wx
.wd:
    sta VX
.dr:
    ldx VI
    cpx #4
    beq .ok
    lda NTBUF,x
    clc
    adc #$10            ; small digits: codes $10-$19
    jsr vchar
    inc VI
    jmp .dr
.ok:
    rts

; ---- window frame + text tiles into the nametable. VROW/VCOL = NES row/column of the top
; left corner, VW/VH = size, (VP) = the text tiles, row-major, (VW-2) per text row
ntwin:
    lda #0
    sta VLINE
.row:
    jsr $FA2A
    lda VROW            ; PPU address of the row
    clc
    adc VLINE
    sta VSH
    lda #0
    sta VT
    ldx #5
.sh:
    asl VSH
    rol VT
    dex
    bne .sh
    lda VT
    ora #$20
    sta $2006
    lda VSH
    ora VCOL
    sta $2006
    lda VLINE
    beq .top
    clc
    adc #1
    cmp VH
    beq .bot
    lda FTILE+3         ; left side, text (or blank: VFILL), right side
    sta $2007
    ldx VW
    dex
    dex
.t:
    lda VFILL
    beq .tt0
    lda BLANKT
    bne .t2
.tt0:
    ldy #0
    lda (VP),y
    inc VP
    bne .t2
    inc VP+1
.t2:
    sta $2007
    dex
    bne .t
    lda FTILE+4
    jmp .end
.top:
    lda FTILE+0
    sta $2007
    ldx VW
    dex
    dex
    lda FTILE+1
.tt:
    sta $2007
    dex
    bne .tt
    lda FTILE+2
    jmp .end
.bot:
    lda FTILE+5
    sta $2007
    ldx VW
    dex
    dex
    lda FTILE+6
.bb:
    sta $2007
    dex
    bne .bb
    lda FTILE+7
.end:
    sta $2007
    jsr scroll
    inc VLINE
    lda VLINE
    cmp VH
    beq .x
    jmp .row
.x:
    rts

; ---- party window (replaces b12:912A): GB cols 8-19, rows 12-17 = NES rows 18-23; one
; line per member: name (condensed letters), HP current/max and MP in 3-px digits
gb_party:
    jsr poolinit
    lda #0
    sta VLINE
.mem:
    lda #10
    sta VN
    jsr vclear
    lda VLINE           ; members 0-3: properties $6100 + 64 * i, battle stats $7D7A + 48 * i
    asl a
    asl a
    asl a
    asl a
    asl a
    asl a
    clc
    adc #2
    sta VP
    lda #$61
    sta VP+1
    lda VLINE
    cmp #3
    bne .shown
    lda $6235           ; slot 4: hidden when bit 7 is set (as b12:9510)
    bpl .shown
    jmp .up
.shown:
    lda #1
    sta VX
    ldy #0
.nm:
    lda (VP),y
    cmp #$FF
    beq .nd
    sty VDIG
    jsr vchar
    ldy VDIG
    iny
    cpy #6
    bne .nm
.nd:
    ldx VLINE           ; battle stats: +$0A current HP, +$0C current MP, +$0E max HP
    lda STATOFS,x
    sta VS
    lda #$7D
    clc
    adc STATHI,x
    sta VS+1
    ldy #$0A            ; current HP
    lda (VS),y
    sta VNUM
    iny
    lda (VS),y
    sta VNUM+1
    lda #48
    jsr vnum
    ldx VLINE           ; status ($7BA6 + member: text id, $F6 none, as b12:956D): the word
    lda $7BA6,x         ;   in place of the maximum HP and MP (30 px)
    cmp #$F6
    beq .nost
    sec
    sbc #$F0
    tax
    lda STLO,x
    sta VS
    lda STHI,x
    sta VS+1
    lda STGAP,x
    sta LDGAP
    lda #50
    sta VX
    jsr vfit
    jmp .up
.nost:
    lda #$1A            ; small '/'
    jsr vchar
    ldy #$0E            ; max HP
    lda (VS),y
    sta VNUM
    iny
    lda (VS),y
    sta VNUM+1
    lda #66
    jsr vnum
    ldy #$0C            ; current MP
    lda (VS),y
    sta VNUM
    iny
    lda (VS),y
    sta VNUM+1
    lda #80
    jsr vnum
.up:
    lda VLINE           ; upload this line's 10 tiles
    asl a
    sta VSH
    asl a
    asl a
    clc
    adc VSH             ; * 10
    clc
    adc #<PTILE
    sta VP
    lda #>PTILE
    adc #0
    sta VP+1
    jsr vupload
    inc VLINE
    lda VLINE
    cmp #4
    beq .win
    jmp .mem
.win:
    lda #18
    sta VROW
    lda #8
    sta VCOL
    lda #12
    sta VW
    lda #6
    sta VH
    lda #<PTILE
    sta VP
    lda #>PTILE
    sta VP+1
    jmp ntwin

; ---- enemy names window (replaces b12:910D): GB cols 0-7, rows 12-17 = NES rows 18-23;
; the monster types of $7B4E-$7B51 (bit 7 set: none), one line each; a name wider than the
; 48-px line wraps at a space onto the next line (NWRAP: byte index of that space), unless
; that makes more than 4 lines: then such names are drawn squeezed (no letter gaps)
gb_names:
    jsr poolinit
    lda #1
    sta VCX
    lda #0
    sta VSQZ
    sta NL
    ldx #3
.cnt:
    lda $7B4E,x
    bmi .cn
    tay
    inc NL
    lda NWRAP,y
    beq .cn
    inc NL
.cn:
    dex
    bpl .cnt
    lda NL
    cmp #5
    bcc .nsq
    lda #1
    sta NS              ; (squeeze the wrapped names)
    bne .go
.nsq:
    lda #0
    sta NS
.go:
    lda #0
    sta NL
    sta VI              ; slot
.slot:
    ldx VI
    lda $7B4E,x
    bmi .next
    tay
    lda NPLO,y
    sta VP
    lda NPHI,y
    sta VP+1
    lda NSQ,y           ; 1: one wide word, squeezed
    cmp #1
    beq .sq
    lda NWRAP,y
    beq .whole
    ldx NS              ; more than 4 lines: the wrapped name on one line, squeezed
    bne .sq
    sta VI1             ; first line: bytes 0 .. NWRAP-1
    lda #0
    sta VI0
    jsr nline
    ldx VI
    ldy $7B4E,x
    lda NSQ,y           ; 2: its second line squeezed
    lsr a
    sta VSQZ
    lda NWRAP,y
    clc
    adc #1
    sta VI0
    lda #$FF
    sta VI1
    jsr nline
    lda #0
    sta VSQZ
    jmp .next
.sq:
    lda #1
    sta VSQZ
.whole:
    lda #0
    sta VI0
    lda #$FF
    sta VI1
    jsr nline
    lda #0
    sta VSQZ
.next:
    inc VI
    lda VI
    cmp #4
    bne .slot
.rest:                  ; empty lines below
    lda NL
    cmp #4
    bcs gb_names_win
    lda #0
    sta VI0
    sta VI1
    jsr nline
    jmp .rest
gb_names_win:
    lda #18
    sta VROW
    lda #0
    sta VCOL
    lda #8
    sta VW
    lda #6
    sta VH
    lda #<LTILE
    sta VP
    lda #>LTILE
    sta VP+1
    jmp ntwin
; ---- command window (replaces b12:982C, the slide to the commands pane): over the names
; window, Fight / Run / Magic / Gear from x 9 (the hand cursor at the screen edge left of it)
gb_cmds:
    jsr poolinit
    lda #0
    sta NL
    sta VSQZ
.c:
    ldx NL
    lda CMDLO,x
    sta VP
    lda CMDHI,x
    sta VP+1
    lda #0
    sta VI0
    lda #$FF
    sta VI1
    lda #9
    sta VCX
    jsr nline
    lda NL
    cmp #4
    bne .c
    lda #1
    sta VCX
    lda LCOV            ; back from the magic list / Gear window (full width): the party
    beq .w              ;   window again first (the command window covers the names)
    lda #0
    sta LCOV
    lda #1
    sta VFILL
    lda #18
    sta VROW
    lda #0
    sta VCOL
    lda #20
    sta VW
    lda #6
    sta VH
    jsr ntwin
    lda #0
    sta VFILL
    jsr gb_party
    lda #1
    sta VCX
.w:
    jmp gb_names_win
nline:                  ; one names line NL from (VP) bytes VI0 .. VI1-1 (or the 0), uploaded
    lda NL
    cmp #4
    bcs .x
    lda VP
    pha
    lda VP+1
    pha
    lda #6
    sta VN
    jsr vclear
    lda VCX             ; (pen start: 1, the commands 9)
    sta VX
    ldy VI0
.l:
    cpy VI1
    bcs .up
    lda (VP),y
    beq .up
    sty VDIG
    jsr vchar
    ldy VDIG
    iny
    bne .l
.up:
    lda NL              ; upload to LTILE + 6 * NL
    asl a
    sta VSH
    asl a
    clc
    adc VSH
    clc
    adc #<LTILE
    sta VP
    lda #>LTILE
    adc #0
    sta VP+1
    jsr vupload
    pla
    sta VP+1
    pla
    sta VP
    inc NL
.x:
    rts

; ---- message window (replaces bank 5 AA57 open / AB4F close; box $64: 0 attacker, 1
; target, 2 action, 3 result, 4 message; the box's text is in the English buffer BUF):
; full width (GB rows 12-17; 17 text tiles = 136 px a line), style A: line 1 "attacker > target", lines 2-3 action and
; result indented, a message on the next free line; when the last box closes, the names and
; party windows come back (their tiles are the message lines' tiles)
gb_msgopen:
    jsr poolinit
    lda MOPEN
    bne .have
    lda #0
    sta MLINE
    lda #1              ; frame, blank lines
    sta VFILL
    lda #18
    sta VROW
    lda #0
    sta VCOL
    lda #20
    sta VW
    lda #6
    sta VH
    jsr ntwin
    lda #0
    sta VFILL
.have:
    inc MOPEN
    lda $64
    beq .atk
    cmp #1
    beq .tgt
    cmp #4
    beq .msg
    sec                 ; 2 action -> line 1, 3 result -> line 2
    sbc #1
    sta VLN
    lda #7
    sta VCX
    jmp .one
.msg:
    lda MLINE
    cmp #4
    bcc .m1
    lda #3
.m1:
    sta VLN
    lda #1
    sta VCX
    jmp .one
.atk:
    ldx #0              ; keep the attacker's name for the target line
.ak:
    lda BUF,x
    sta ATKBUF,x
    beq .ak1
    inx
    cpx #15
    bne .ak
    lda #0
    sta ATKBUF,x
.ak1:
    lda #0
    sta VLN
    lda #1
    sta VCX
.one:
    jsr linestart
    lda #<BUF
    sta VP
    lda #>BUF
    sta VP+1
    jsr vstrp
    jmp lineend
.tgt:
    lda #0
    sta VLN
    lda #1
    sta VCX
    jsr linestart
    lda #<ATKBUF
    sta VP
    lda #>ATKBUF
    sta VP+1
    jsr vstrp
    lda #$FF            ; " > "
    jsr vchar
    lda #$1B
    jsr vchar
    lda #$FF
    jsr vchar
    lda #<BUF
    sta VP
    lda #>BUF
    sta VP+1
    jsr vstrp
    jmp lineend
linestart:              ; message line VLN: clear its 17 tiles, pen at VCX
    lda #17
    sta VN
    jsr vclear
    lda VCX
    sta VX
    rts
vstrp:                  ; codes at (VP) up to 0 (control codes < $10 skipped)
    ldy #0
.l:
    lda (VP),y
    beq .e
    cmp #$10
    bcc .n
    sty VDIG
    jsr vchar
    ldy VDIG
.n:
    iny
    cpy #63
    bne .l
.e:
    rts
lineend:                ; upload line VLN (tiles PTILE + 17 * VLN) and write its row
    lda VLN
    asl a
    asl a
    asl a
    asl a
    clc
    adc VLN             ; * 17
    clc
    adc #<PTILE
    sta VP
    lda #>PTILE
    adc #0
    sta VP+1
    lda VP
    pha
    lda VP+1
    pha
    jsr vupload
    pla
    sta VP+1
    pla
    sta VP
    jsr $FA2A           ; the row: NES row 19 + VLN, cols 1-18
    lda VLN
    clc
    adc #19
    sta VSH
    lda #0
    sta VT
    ldx #5
.sh:
    asl VSH
    rol VT
    dex
    bne .sh
    lda VT
    ora #$20
    sta $2006
    lda VSH
    ora #1
    sta $2006
    ldy #0
.w:
    lda (VP),y
    sta $2007
    iny
    cpy #17
    bne .w
    lda BLANKT          ; (the 18th cell)
    sta $2007
    jsr scroll
    lda VLN             ; next free line
    clc
    adc #1
    cmp MLINE
    bcc .x
    sta MLINE
.x:
    rts
gb_msgclose:
    dec MOPEN
    bne .x
    lda #1              ; blank the message window first (its tiles are about to become the
    sta VFILL           ;   names' and the party's again), then those two windows
    lda #18
    sta VROW
    lda #0
    sta VCOL
    lda #20
    sta VW
    lda #6
    sta VH
    jsr ntwin
    lda #0
    sta VFILL
    jsr gb_names
    jmp gb_party
.x:
    rts

; ---- battle magic list (b12:9DE3 open + 9EF5 cost; owner-approved layout): full-width
; window, spell names in two columns (pen 9 / 81), three rows a page (cursor row $54 / 3),
; line 4 "MP cur/max" and "MP Cost n" (n = $77, set by b12:9EF5 for the spell under the
; cursor); no spells ($76 = 0): "Magic can't be used" as on the NES
gb_magic:
    jsr poolinit
    lda #1
    sta LCOV
    lda #1              ; frame with blank lines (as the message window)
    sta VFILL
    lda #18
    sta VROW
    lda #0
    sta VCOL
    lda #20
    sta VW
    lda #6
    sta VH
    jsr ntwin
    lda #0
    sta VFILL
    lda $76
    bne .has
    lda #0
    sta VLN
    lda #9
    sta VCX
    jsr linestart
    lda #<NOMAGIC
    sta VP
    lda #>NOMAGIC
    sta VP+1
    jsr vstrp
    jmp lineend
.has:
    lda #$FF
    sta MPAGE
    lda #0
    sta $77             ; (no cost shown until b12:9EF5 sets it)
    jsr magpage
    jmp magmp
gb_magcost:             ; b12:9EF5's display part: page turn, then the MP line
    jsr magpage
    jmp magmp
magpage:                ; draw the page of cursor row $54 if it is not the one shown
    lda $54
    ldx #0
.d:
    cmp #3
    bcc .p
    sbc #3
    inx
    bne .d
.p:
    cpx MPAGE
    bne .new
    rts
.new:
    stx MPAGE
    txa                 ; first spell index of the page = page * 6
    asl a
    sta VI
    asl a
    clc
    adc VI
    sta VI
    lda #0
    sta VLN
.ln:
    lda #9
    sta VCX
    jsr linestart
    jsr magname         ; column 1: spell VI
    inc VI
    lda #81
    sta VX
    jsr magname         ; column 2: spell VI + 1
    inc VI
    jsr lineend
    inc VLN
    lda VLN
    cmp #3
    bne .ln
    rts
magname:                ; draw the name of spell slot VI (character $9E: list $7CE3) at VX
    lda VI
    cmp #16
    bcs .x
    tax
    lda $7CE3,x
    beq .x
    tax
    lda NMLO,x
    sta VP
    lda NMHI,x
    sta VP+1
    jmp vstrp
.x:
    rts
magmp:                  ; line 4: "MP" cur/max, "MP Cost" n
    lda #3
    sta VLN
    lda #9
    sta VCX
    jsr linestart
    lda #<MPLAB
    sta VP
    lda #>MPLAB
    sta VP+1
    jsr vstrp
    ldy #$0C            ; current MP (battle stats at ($80))
    lda ($80),y
    sta VNUM
    iny
    lda ($80),y
    sta VNUM+1
    lda VX
    clc
    adc #18
    jsr vnum
    lda #$1A
    jsr vchar
    ldy #$10            ; max MP
    lda ($80),y
    sta VNUM
    iny
    lda ($80),y
    sta VNUM+1
    lda VX
    clc
    adc #13
    jsr vnum
    lda #81
    sta VX
    lda #<COSTLAB
    sta VP
    lda #>COSTLAB
    sta VP+1
    jsr vstrp
    lda $77
    beq .e
    sta VNUM
    lda #0
    sta VNUM+1
    lda VX
    clc
    adc #10
    jsr vnum
.e:
    jmp lineend

; ---- Gear window (b12:A058, the window open of b12:A020; owner-approved layout): Right
; Hand + weapon, Left Hand + weapon, Items + item 1, item 2 below it (character properties
; at ($7A): +$1C right hand, +$1D left hand, +$1E / +$1F items); labels at pen 9, names 58
gb_gear:
    jsr poolinit
    lda #1
    sta LCOV
    lda #1
    sta VFILL
    lda #18
    sta VROW
    lda #0
    sta VCOL
    lda #20
    sta VW
    lda #6
    sta VH
    jsr ntwin
    lda #0
    sta VFILL
    sta VLN
.ln:
    lda #9
    sta VCX
    jsr linestart
    ldx VLN
    lda GLABLO,x
    sta VP
    lda GLABHI,x
    sta VP+1
    jsr vstrp
    lda #58
    sta VX
    lda VLN
    clc
    adc #$1C
    tay
    lda ($7A),y
    tax
    lda NMLO,x
    sta VP
    lda NMHI,x
    sta VP+1
    jsr vstrp
    jsr lineend
    inc VLN
    lda VLN
    cmp #4
    bne .ln
    rts

; ---- treasure screen (bank 5 $9F09: after a battle that left items). Owner's layout
; (mock-up ff2_mock7): treasure window (GB 0,0,20,7): title, Drop, Done on line 1, the 8
; treasure slots in two columns; inventory window (GB 0,6,20,12): two columns, 10 of the
; 16 rows (scroll $73, 0-6). NES nametable 0, camera (1, 0): GB column c = NES column c+1.
; Cells 0-7 treasure, 8-27 inventory (row-major, two per row), 28-30 the titles; each has
; its own tiles (LCT), position (LCR / LCC) and length (LCN); a cell is drawn again when
; the item id it shows (LSHOW) changes.
gb_lootscr:             ; b5:9FDA (after the fade out, before the fade in)
    lda #$10
    sta TBLHI
    lda #0
    sta $2005
    sta $2005
    lda #1
    sta $5800
    lda #0
    sta $5801
    sta $5802
    sta $5803
    lda #$FF
    sta BLANKT
    ldx #7
.ft:
    txa
    clc
    adc #$F7
    sta FTILE,x
    dex
    bpl .ft
    jsr frames
    jsr lblank
    lda #1
    sta VFILL
    lda #0
    sta VROW
    lda #1
    sta VCOL
    lda #20
    sta VW
    lda #7
    sta VH
    jsr ntwin
    lda #6
    sta VROW
    lda #12
    sta VH
    jsr ntwin
    lda #0
    sta VFILL
    jsr lattr
    ldx #28
.tt:
    stx VI
    lda LTITLE-28,x
    jsr lcell
    ldx VI
    inx
    cpx #31
    bne .tt
    ldx #27
    lda #$FE
.c:
    sta LSHOW,x
    dex
    bpl .c
    lda #0              ; (b5:A011 sets the scroll to 0 before the menu as well)
    sta $73
    sta LSCR
    sta LRING
    jsr lsync
    lda #0
    sta $00
    rts
lblank:                 ; tile $FF: window colour 2
    jsr $FA2A
    lda #$FF
    jsr tileaddr
    lda #0
    ldx #8
.p0:
    sta $2007
    dex
    bne .p0
    lda #$FF
    ldx #8
.p1:
    sta $2007
    dex
    bne .p1
    jmp scroll
lattr:                  ; nametable 0 attributes: palette 0 (two frames)
    lda #0
    sta VLINE
.h:
    jsr $FA2A
    lda #$23
    sta $2006
    lda VLINE
    ora #$C0
    sta $2006
    lda #0
    ldx #32
.a:
    sta $2007
    dex
    bne .a
    jsr scroll
    lda VLINE
    clc
    adc #32
    sta VLINE
    cmp #64
    bne .h
    rts
gb_lootf:               ; b5 loot menu frame loop: cells whose item changed
lsync:
    ldx #0
.t:
    stx VI
    lda $7B6A,x
    cmp LSHOW,x
    beq .tn
    sta LSHOW,x
    jsr lcell
.tn:
    ldx VI
    inx
    cpx #8
    bne .t
    lda $73             ; scrolled by one row: the rows' tiles stay, the nametable rows are
    sec                 ;   pointed one row on (ring of 10 row blocks) and only the new row
    sbc LSCR            ;   is drawn
    beq .same
    cmp #1
    beq .down
    cmp #$FF
    bne .same
    lda LRING           ; up: content moves down
    clc
    adc #9
    cmp #10
    bcc .u1
    sbc #10
.u1:
    sta LRING
    ldy #19
.us:
    lda LSHOW+6,y
    sta LSHOW+8,y
    lda LWID-2,y
    sta LWID,y
    dey
    cpy #2
    bcs .us
    lda #$FE
    sta LSHOW+8
    sta LSHOW+9
    lda #0
    sta LWID
    sta LWID+1
    jmp .rows
.down:
    ldy LRING           ; down: content moves up
    iny
    cpy #10
    bcc .d1
    ldy #0
.d1:
    sty LRING
    ldy #0
.ds:
    lda LSHOW+10,y
    sta LSHOW+8,y
    lda LWID+2,y
    sta LWID,y
    iny
    cpy #18
    bne .ds
    lda #$FE
    sta LSHOW+26
    sta LSHOW+27
    lda #0
    sta LWID+18
    sta LWID+19
.rows:
    jsr lrows
.same:
    lda $73
    sta LSCR
    asl a
    sta LBASE
    ldx #8
.i:
    stx VI
    txa
    sec
    sbc #8
    clc
    adc LBASE
    tay
    lda $6060,y
    ldx VI
    cmp LSHOW,x
    beq .in
    sta LSHOW,x
    jsr lcell
.in:
    ldx VI
    inx
    cpx #28
    bne .i
    rts
lcell:                  ; cell VI shows the name of item A (narrow letters / dropped gaps
    tax                 ;   for long names: LFLO / LFHI, LGAP, made at build time)
    lda LFLO,x
    sta VS
    lda LFHI,x
    sta VS+1
    lda LGAP,x
    sta LDGAP
    ldx VI
    lda LCN,x
    sta VN
    jsr vclear
    jsr vfit
    lda VX              ; tiles used: (VX + 6) / 8 (VX includes the last letter's gap)
    jmp lcell2
vfit:                   ; draw (VS) at VX, no letter gap after the characters from length -
    ldy #0              ;   LDGAP to length - 2
.n:
    lda (VS),y
    beq .nd
    iny
    bne .n
.nd:
    sty VI1             ; length; no letter gap after the characters VI0 .. VI1-2
    tya
    sec
    sbc LDGAP
    sta VI0
    ldy #0
.l:
    cpy VI1
    beq .e
    lda #0
    cpy VI0
    bcc .g
    iny
    cpy VI1
    dey
    bcs .g
    lda #1
.g:
    sta VSQZ
    lda (VS),y
    sty VDIG
    jsr vchar
    ldy VDIG
    iny
    bne .l
.e:
    lda #0
    sta VSQZ
    rts
lcell2:
    clc
    adc #6
    lsr a
    lsr a
    lsr a
    cmp VN
    bcc .w
    lda VN
.w:
    sta VW
    ldx VI
    cpx #8
    bcc .fx
    cpx #28
    bcs .fx
    sta LWID-8,x
    txa
    jsr ringbase
    jmp .bs
.fx:
    lda LCT,x
.bs:
    sta VSV
    ldy #0              ; tile numbers of the cell -> NTBUF
.tl:
    tya
    clc
    adc VSV
    sta NTBUF,y
    iny
    cpy #8
    bne .tl
    lda VW
    beq .nt
    sta VN
    lda #<NTBUF
    sta VP
    lda #>NTBUF
    sta VP+1
    jsr vupload
.nt:
    jsr $FA2A           ; the cell's row: its tiles, then blank ($FF)
    ldx VI
    lda LCR,x
    sta VSH
    lda #0
    sta VT
    ldy #5
.sh:
    asl VSH
    rol VT
    dey
    bne .sh
    lda VT
    ora #$20
    sta $2006
    lda VSH
    ora LCC,x
    sta $2006
    lda LCN,x
    sta VN
    ldy #0
.c:
    lda #$FF
    cpy VW
    bcs .b
    lda NTBUF,y
.b:
    sta $2007
    iny
    cpy VN
    bne .c
    jmp scroll

ringbase:               ; A = inventory cell (8-27) -> its first tile: $40 + 16 * ((row +
    sec                 ;   LRING) mod 10) + 8 * column
    sbc #8
    pha
    lsr a
    clc
    adc LRING
    cmp #10
    bcc .m
    sbc #10
.m:
    asl a
    asl a
    asl a
    asl a
    sta VT
    pla
    and #1
    asl a
    asl a
    asl a
    ora VT
    clc
    adc #$40
    rts
lrows:                  ; the 10 inventory rows' nametable entries (2 rows a frame: the
    lda #0              ;   NES vblank)
    sta VLINE
.f:
    jsr $FA2A
    lda #2
    sta VCNT
.r:
    lda VLINE
    clc
    adc #7
    sta VSH
    lda #0
    sta VT
    ldy #5
.sh:
    asl VSH
    rol VT
    dey
    bne .sh
    lda VT
    ora #$20
    sta $2006
    lda VSH
    ora #2
    sta $2006
    lda VLINE
    asl a
    sta VI0
    jsr lrowcell
    lda #$FF
    sta $2007
    sta $2007
    inc VI0
    jsr lrowcell
    inc VLINE
    dec VCNT
    bne .r
    jsr scroll
    lda VLINE
    cmp #10
    bne .f
    rts
lrowcell:               ; cell 8 + VI0: its tiles (LWID of them), then blank
    lda VI0
    clc
    adc #8
    jsr ringbase
    sta VSV
    ldx VI0
    lda LWID,x
    sta VW
    ldy #0
.l:
    lda #$FF
    cpy VW
    bcs .b
    tya
    clc
    adc VSV
.b:
    sta $2007
    iny
    cpy #8
    bne .l
    rts

gb_lootnav:             ; b5 loot menu: right / left / down / up (replaces b5:A1DE-A285).
    lda #0              ;   GB grid: Drop Done / 4 treasure rows / inventory rows; LNAV = 1
    sta LNAV            ;   when the cursor moved ($72 window column, $74 row, $73 scroll)
    lda $34
    cmp #$80
    beq .right
    cmp #$40
    beq .left
    cmp #$20
    beq .down
    cmp #$10
    bne .x
    jmp .up
.x:
    rts
.moved:
    lda #1
    sta LNAV
    rts
.right:
    lda $72
    bne .r1
    lda $74
    and #1
    bne .x
    inc $74
    jmp .moved
.r1:
    cmp #1
    bne .x
    inc $72
    jmp .moved
.left:
    lda $72
    bne .l1
    lda $74
    and #1
    beq .x
    dec $74
    jmp .moved
.l1:
    cmp #2
    bne .x
    dec $72
    jmp .moved
.down:
    lda $72
    bne .d1
    lda $74
    cmp #8
    bcc .d0
    sbc #8              ; Drop / Done -> treasure slot 0 / 1
    sta $74
    jmp .moved
.d0:
    cmp #6
    bcs .dinv
    adc #2
    sta $74
    jmp .moved
.dinv:                  ; -> inventory (not while an inventory item waits for its slot)
    lda $50
    beq .di
    lda $54
    bne .x
.di:
    lda $74
    and #1
    clc
    adc #1
    sta $72
    lda #0
    sta $74
    jmp .moved
.d1:
    lda $74
    cmp #9
    bcs .dscr
    inc $74
    jmp .moved
.dscr:
    lda $73
    cmp #6
    bcs .x
    inc $73
    jmp .scr
.up:
    lda $72
    bne .u1
    lda $74
    cmp #8
    bcs .x2
    cmp #2
    bcs .u0
    adc #8              ; slot 0 / 1 -> Drop / Done
    sta $74
    jmp .moved
.u0:
    sbc #2
    sta $74
    jmp .moved
.u1:
    lda $74
    beq .uscr
    dec $74
    jmp .moved
.uscr:
    lda $73
    beq .utr
    dec $73
    jmp .scr
.utr:                   ; -> treasure (not while a treasure item waits for its slot)
    lda $50
    beq .ut
    lda $54
    beq .x2
.ut:
    lda $72
    clc
    adc #5
    sta $74
    lda #0
    sta $72
    jmp .moved
.scr:                   ; window offset as b5:A3E9 keeps it ($22 per row)
    lda $73
    asl a
    sta VT
    asl a
    asl a
    asl a
    asl a
    clc
    adc VT
    sta $A7
    jmp .moved
.x2:
    rts


BIT:    .db $80, $40, $20, $10, $08, $04, $02, $01
POW:    .db <1000, <100, <10, <1
POWH:   .db >1000, >100, >10, >1
STATOFS: .db $7A, $AA, $DA, $0A
STATHI:  .db 0, 0, 0, 1
'''


def glyph_tables(rom=None):
    """glyph data for the small-font renderer (bank 23): code -> width, columns (bit 7 =
    top row); letters condensed (tools/latin_font.py COND, else G), 3-px digits at codes
    $10-$19, small '/' at $1A (FF1's battle digits)"""
    sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'ff2'))
    from latin_font import _glyph_cols, COND, G
    import importlib.util
    spec = importlib.util.spec_from_file_location('ff2insert', os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'ff2', 'insert.py'))
    ins = importlib.util.module_from_spec(spec); spec.loader.exec_module(ins)
    DIG3 = {'0': ["###", "#.#", "#.#", "#.#", "#.#", "#.#", "###"], '1': [".#.", "##.", ".#.", ".#.", ".#.", ".#.", "###"],
            '2': ["###", "..#", "..#", "###", "#..", "#..", "###"], '3': ["###", "..#", "..#", ".##", "..#", "..#", "###"],
            '4': ["#.#", "#.#", "#.#", "###", "..#", "..#", "..#"], '5': ["###", "#..", "#..", "###", "..#", "..#", "###"],
            '6': ["###", "#..", "#..", "###", "#.#", "#.#", "###"], '7': ["###", "..#", "..#", ".#.", ".#.", ".#.", ".#."],
            '8': ["###", "#.#", "#.#", "###", "#.#", "#.#", "###"], '9': ["###", "#.#", "#.#", "###", "..#", "..#", "###"],
            '/': ["..#", "..#", ".#.", ".#.", ".#.", "#..", "#.."]}
    glyph = {}
    for ch, code in ins.ENC.items():
        if ch == ' ': continue
        cols = _glyph_cols(ch, COND if ch in COND else G)
        glyph[code] = [sum(b << (7 - r) for r, b in enumerate(c)) for c in cols]
    for i, ch in enumerate('0123456789/'):
        art = DIG3[ch]
        glyph[0x10 + i] = [sum((1 << (7 - (r + 1))) for r in range(7) if art[r][c] == '#') for c in range(3)]
    arrow = ["......", "...#..", "....#.", "######", "....#.", "...#..", "......"]   # FF1's battle arrow
    glyph[0x1B] = [sum((1 << (7 - (r + 1))) for r in range(7) if arrow[r][c] == '#') for c in range(6)]
    from latin_font import NARROW
    for i, ch in enumerate(sorted(NARROW)):          # narrow letters (long item names): $20 + i
        glyph[NARROW_CODE + i] = [sum(b << (7 - r) for r, b in enumerate(c)) for c in _glyph_cols(ch, NARROW)]
    if rom is not None:                              # item type icons $6E-$75: the ROM font's
        b9 = rom[HDR + 9 * BANK:HDR + 10 * BANK]     #   tiles (bank 9 $8320, plane 0 = ink),
        for t in range(0x6E, 0x76):                  #   empty columns trimmed
            rows = b9[0x0320 + 16 * t:0x0320 + 16 * t + 8]
            cols = [sum(((rows[r] >> (7 - c)) & 1) << (7 - r) for r in range(8)) for c in range(8)]
            while cols and not cols[0]: cols.pop(0)
            while cols and not cols[-1]: cols.pop()
            glyph[t] = cols
    glyph[THIN_SPACE] = [0]                          # 1-px space (long names, see loot_data)
    return glyph


NARROW_CODE = 0x20
THIN_SPACE = 0x3F


def narrow_codes():
    """English code -> its narrow letter's code (glyph_tables)"""
    from latin_font import NARROW
    import importlib.util
    spec = importlib.util.spec_from_file_location('ff2insert', os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'ff2', 'insert.py'))
    ins = importlib.util.module_from_spec(spec); spec.loader.exec_module(ins)
    return {ins.ENC[ch]: NARROW_CODE + i for i, ch in enumerate(sorted(NARROW))}


def names_data(rom):
    """monster names for the names window: the English strings (bank 21 table $AC44, as
    insert.py placed them), and per monster the byte index of the space to wrap at when the
    name is wider than the 48-px line (0: fits; $FF: one word, drawn squeezed)"""
    from latin_font import _glyph_cols, COND, G
    import importlib.util
    spec = importlib.util.spec_from_file_location('ff2insert', os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'ff2', 'insert.py'))
    ins = importlib.util.module_from_spec(spec); spec.loader.exec_module(ins)
    dec = {v: k for k, v in ins.ENC.items()}
    def width(codes):
        t = 0
        for i, c in enumerate(codes):
            if i: t += 1
            ch = dec.get(c, ' ')
            t += 2 if ch == ' ' else len(_glyph_cols(ch, COND if ch in COND else G))
        return t
    b21 = rom[HDR + 21 * BANK:HDR + 22 * BANK]
    strs, wrap, squeeze = [], [], []
    for m in range(128):
        p = b21[0x2C44 + 2 * m] | b21[0x2C44 + 2 * m + 1] << 8
        o = p - 0x8000; e = b21.index(0, o)
        cs = bytes(b21[o:e]); strs.append(cs)
        k, q = 0, 0
        if width(cs) > 48:
            sq = lambda c: width(c) - max(0, len(c) - 1)       # squeezed: no letter gaps
            sp = [i for i, c in enumerate(cs) if c == 0xFF and width(cs[:i]) <= 48]
            if sp:
                k = sp[-1]
                if width(cs[k + 1:]) > 48:
                    q = 2; assert sq(cs[k + 1:]) <= 48, cs      # second line squeezed
            else:
                q = 1; assert sq(cs) <= 48, cs                  # one word: squeezed
        wrap.append(k); squeeze.append(q)
    out = '\nNWRAP:\n' + ''.join('    .db %s\n' % ', '.join(str(v) for v in wrap[i:i + 16]) for i in range(0, 128, 16))
    out += 'NSQ:\n' + ''.join('    .db %s\n' % ', '.join(str(v) for v in squeeze[i:i + 16]) for i in range(0, 128, 16))
    out += 'NPLO:\n' + ''.join('    .db %s\n' % ', '.join('<NAME%d' % k for k in range(i, i + 16)) for i in range(0, 128, 16))
    out += 'NPHI:\n' + ''.join('    .db %s\n' % ', '.join('>NAME%d' % k for k in range(i, i + 16)) for i in range(0, 128, 16))
    for m, cs in enumerate(strs):
        out += 'NAME%d: .db %s\n' % (m, ', '.join('$%02X' % c for c in cs + b'\0'))
    b10 = rom[HDR + 10 * BANK:HDR + 11 * BANK]   # names (items, spells; bank 10 table $8200)
    out += 'NMLO:\n' + ''.join('    .db %s\n' % ', '.join('<NM%d' % k for k in range(i, i + 16)) for i in range(0, 256, 16))
    out += 'NMHI:\n' + ''.join('    .db %s\n' % ', '.join('>NM%d' % k for k in range(i, i + 16)) for i in range(0, 256, 16))
    for k in range(256):
        p = b10[0x0200 + 2 * k] | b10[0x0200 + 2 * k + 1] << 8
        o = p - 0x8000; cs = bytes(b10[o:b10.index(0, o)])
        out += 'NM%d: .db %s\n' % (k, ', '.join('$%02X' % c for c in cs + b'\0'))
    def bmsg(k):                                # battle_msgs k (bank 21 $B295)
        p = b21[0x3295 + 2 * k] | b21[0x3295 + 2 * k + 1] << 8
        o = p - 0x8000; return bytes(b21[o:b21.index(0, o)])
    out += 'COSTLAB: .db %s\n' % ', '.join('$%02X' % c for c in bmsg(7) + b'\0')
    for k, lab in enumerate((bmsg(4), bmsg(5), bmsg(6), b'')):     # Right Hand, Left Hand, Items
        out += 'GLAB%d: .db %s\n' % (k, ', '.join('$%02X' % c for c in lab + b'\0'))
    out += 'GLABLO: .db <GLAB0, <GLAB1, <GLAB2, <GLAB3\nGLABHI: .db >GLAB0, >GLAB1, >GLAB2, >GLAB3\n'
    out += 'NOMAGIC: .db %s\n' % ', '.join('$%02X' % c for c in bmsg(8) + b'\0')
    out += 'MPLAB: .db %s\n' % ', '.join('$%02X' % c for c in bytes([ins.ENC['M'], ins.ENC['P']]) + b'\0')
    cmds = []                                   # battle commands: battle_msgs 0-3 (bank 21 $B295)
    for k in range(4):
        p = b21[0x3295 + 2 * k] | b21[0x3295 + 2 * k + 1] << 8
        o = p - 0x8000; cmds.append(bytes(b21[o:b21.index(0, o)]))
        assert width(cmds[-1]) <= 48 - 8, cmds[-1]
    out += 'CMDLO: .db %s\nCMDHI: .db %s\n' % (', '.join('<CMD%d' % k for k in range(4)), ', '.join('>CMD%d' % k for k in range(4)))
    for k, cs in enumerate(cmds):
        out += 'CMD%d: .db %s\n' % (k, ', '.join('$%02X' % c for c in cs + b'\0'))
    return out


def loot_data(rom, gw):
    """treasure screen tables: cells (tiles, NES row / column, length) and, per item, the
    string to draw in a 64-px cell: the English name, or for a wider one the name in the
    narrow letters with the letter gaps after its last LGAP-1 characters dropped"""
    b10 = rom[HDR + 10 * BANK:HDR + 11 * BANK]
    nar = narrow_codes()
    cells = [(8 * k, 2 + k // 2, 2 + 10 * (k % 2), 8) for k in range(8)]
    cells += [(0x40 + 8 * j, 7 + j // 2, 2 + 10 * (j % 2), 8) for j in range(20)]
    cells += [(0xE0, 1, 2, 8), (0xE8, 1, 12, 5), (0xEC, 1, 17, 3)]      # .. Treasure .., Drop, Done
    def ink(cs, gap):                       # pixel columns used (as vfit draws it)
        x, last, n = 0, 0, len(cs)
        for i, c in enumerate(cs):
            if gw[c] == 0: x += 2; continue
            x += gw[c]; last = x
            if not (n - gap <= i < n - 1): x += 1
        return last
    out = ''
    for nm, k in (('LCT', 0), ('LCR', 1), ('LCC', 2), ('LCN', 3)):
        out += nm + ': .db ' + ', '.join(str(c[k]) for c in cells) + '\n'
    out += 'LTITLE: .db $E8, $E9, $EA\n'
    lo, hi, gaps, fits = [], [], [], ''
    for k in range(256):
        p = b10[0x0200 + 2 * k] | b10[0x0200 + 2 * k + 1] << 8
        o = p - 0x8000; cs = bytes(b10[o:b10.index(0, o)])
        if ink(cs, 0) <= 64:
            lo.append('<NM%d' % k); hi.append('>NM%d' % k); gaps.append(0); continue
        cs = bytes(nar.get(c, c) for c in cs)
        if ink(cs, len(cs)) > 64:           # still too wide: thin spaces (1 px where squeezed)
            cs = bytes(THIN_SPACE if c == 0xFF else c for c in cs)
        g = 0
        while ink(cs, g) > 64:
            g += 1
            assert g <= len(cs), k
        lo.append('<FIT%d' % k); hi.append('>FIT%d' % k); gaps.append(g)
        fits += 'FIT%d: .db %s\n' % (k, ', '.join('$%02X' % c for c in cs + b'\0'))
    for nm, v in (('LFLO', lo), ('LFHI', hi), ('LGAP', [str(x) for x in gaps])):
        out += nm + ':\n' + ''.join('    .db %s\n' % ', '.join(v[i:i + 16]) for i in range(0, 256, 16))
    # battle status words (text ids $F0-$FD, script/ff2/system.json 240-253, the English the
    # NES build draws): 30 px in the party line
    import json, importlib.util
    spec = importlib.util.spec_from_file_location('ff2insert', os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'ff2', 'insert.py'))
    ins = importlib.util.module_from_spec(spec); spec.loader.exec_module(ins)
    words = {e['id']: e['en'] for e in json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'script', 'ff2', 'system.json'))) if 240 <= e['id'] <= 253}
    sl, sh, sg = [], [], []
    for k in range(14):
        cs = bytes(ins.ENC[ch] for ch in words.get(240 + k, ''))
        g = 0
        if ink(cs, 0) > 30:
            cs = bytes(nar.get(c, c) for c in cs)
            while ink(cs, g) > 30:
                g += 1
                assert g <= len(cs), words[240 + k]
        fits += 'ST%d: .db %s\n' % (k, ', '.join('$%02X' % c for c in cs + b'\0'))
        sl.append('<ST%d' % k); sh.append('>ST%d' % k); sg.append(str(g))
    out += 'STLO: .db %s\nSTHI: .db %s\nSTGAP: .db %s\n' % (', '.join(sl), ', '.join(sh), ', '.join(sg))
    return out + fits


def menu_data(rom):
    """main menu tables from the user's ROM: the 12 portraits (bank 9, pointers fix:E76A,
    192 bytes each), their palette indices (b14:890B), the status words of text ids
    $F6-$FD (bank 10 table $8400, 5 cells), and the attribute quads of the portrait boxes"""
    import importlib.util
    ins = _insert_module()
    b9 = rom[HDR + 9 * BANK:HDR + 10 * BANK]
    fix = rom[HDR + 31 * BANK:HDR + 32 * BANK]
    b10 = rom[HDR + 10 * BANK:HDR + 11 * BANK]
    b14 = rom[HDR + 14 * BANK:HDR + 15 * BANK]
    out = 'PORTG:\n'
    for i in range(12):
        o = fix[0x276A + i] * 16
        out += ''.join('    .db %s\n' % ', '.join('$%02X' % v for v in b9[o + j:o + j + 16]) for j in range(0, 192, 16))
    out += 'PGLO: .db %s\nPGHI: .db %s\n' % (', '.join('<(PORTG+%d)' % (192 * i) for i in range(12)),
                                              ', '.join('>(PORTG+%d)' % (192 * i) for i in range(12)))
    out += 'PALID: .db %s\n' % ', '.join('$%02X' % v for v in b14[0x090B:0x0917])
    stw = []
    for k in range(8):
        i = 0xF6 + k
        p = b10[0x0400 + 2 * i] | b10[0x0400 + 2 * i + 1] << 8
        o = p - 0x8000; cs = bytes(b10[o:b10.index(0, o)])
        assert len(cs) <= 5, cs
        stw += list(cs) + [0xFF] * (5 - len(cs))
    out += 'STW: .db %s\n' % ', '.join('$%02X' % v for v in stw)
    qi, qs, qm = [], [], []
    for k in range(4):
        for qy in (1 + 2 * k, 2 + 2 * k):
            for qx in (1, 2):
                sh = ((qy & 1) * 2 + (qx & 1)) * 2
                qi.append((qy >> 1) * 8 + (qx >> 1)); qs.append(sh); qm.append(~(3 << sh) & 0xFF)
    for nm, v in (('QIDX', qi), ('QSH', qs), ('QMSK', qm)):
        out += '%s: .db %s\n' % (nm, ', '.join(str(x) for x in v))
    out += 'SPEEDW: .db %s\n' % ', '.join('$%02X' % v for v in ins.enc('Speed '))
    assert all(ins.ENC[str(d)] == ins.ENC['0'] + d for d in range(10))
    return out, dict(CHH=ins.ENC['H'], CHM=ins.ENC['M'], CHP=ins.ENC['P'], CH1=ins.ENC['1'])


def bank23(rom, L, extra=''):
    """bank 23 source + data from the user's ROM (first monster tiles, boss tilemaps, frame
    tiles) and the glyph tables"""
    b11 = rom[HDR + 11 * BANK:HDR + 12 * BANK]
    first = b11[0x9FA5 - 0x8000:0x9FA5 - 0x8000 + 9]
    boss = []
    for k in range(6):                                  # boss tilemaps (b11:8DDE, 144 each)
        used = bytearray(32)
        for t in b11[0x8DDE - 0x8000 + 144 * k:0x8DDE - 0x8000 + 144 * (k + 1)]: used[t >> 3] |= 0x80 >> (t & 7)
        boss.append(bytes(used))
    b9 = rom[HDR + 9 * BANK:HDR + 10 * BANK]
    frame = b''.join(b9[0x0320 + 16 * t:0x0320 + 16 * t + 16] for t in range(0xF7, 0xFF))
    g = glyph_tables(rom)
    gw = bytes(len(g.get(c, [])) for c in range(256))
    data, offs = bytearray(), []
    for c in range(256):
        offs.append(len(data)); data += bytes(g.get(c, []))
    nsrc = names_data(rom) + loot_data(rom, gw)
    src = B23_SRC.replace('GBTAB', ', '.join(name for name, rb, nes in ENTRIES)) + nsrc + extra + '\nFIRST: .db ' + ', '.join('$%02X' % v for v in first)
    src += '\nBOSSUSED:\n' + ''.join('    .db %s\n' % ', '.join('$%02X' % v for v in b) for b in boss)
    src += 'FRAMEGFX:\n' + ''.join('    .db %s\n' % ', '.join('$%02X' % v for v in frame[i:i + 16]) for i in range(0, 128, 16))
    src += 'GW:\n' + ''.join('    .db %s\n' % ', '.join('$%02X' % v for v in gw[i:i + 16]) for i in range(0, 256, 16))
    src += 'GLYPHS:\n' + ''.join('    .db %s\n' % ', '.join('$%02X' % v for v in data[i:i + 16]) for i in range(0, len(data), 16))
    src += 'GOFF:\n' + ''.join('    .db %s\n' % ', '.join('<(GLYPHS+%d)' % o for o in offs[i:i + 16]) for i in range(0, 256, 16))
    src += 'GHI:\n' + ''.join('    .db %s\n' % ', '.join('>(GLYPHS+%d)' % o for o in offs[i:i + 16]) for i in range(0, 256, 16))
    return asm(src, syms=dict(RAM, BUF=0x5E40, **L))


def glyph_src(rom):
    """the small-font glyph tables (GW, GLYPHS, GOFF, GHI)"""
    g = glyph_tables(rom)
    gw = bytes(len(g.get(c, [])) for c in range(256))
    data, offs = bytearray(), []
    for c in range(256):
        offs.append(len(data)); data += bytes(g.get(c, []))
    src = 'GW:\n' + ''.join('    .db %s\n' % ', '.join('$%02X' % v for v in gw[i:i + 16]) for i in range(0, 256, 16))
    src += 'GLYPHS:\n' + ''.join('    .db %s\n' % ', '.join('$%02X' % v for v in data[i:i + 16]) for i in range(0, len(data), 16))
    src += 'GOFF:\n' + ''.join('    .db %s\n' % ', '.join('<(GLYPHS+%d)' % o for o in offs[i:i + 16]) for i in range(0, 256, 16))
    src += 'GHI:\n' + ''.join('    .db %s\n' % ', '.join('>(GLYPHS+%d)' % o for o in offs[i:i + 16]) for i in range(0, 256, 16))
    return src


def bank24(rom):
    """bank 24: the main menu (MENU_SRC) with the renderer core of B23_SRC (vupload ..
    ntwin), its tables and the menu data"""
    core = B23_SRC[B23_SRC.index('vupload:'):B23_SRC.index('frames:')] + \
        B23_SRC[B23_SRC.index('tileaddr:'):B23_SRC.index('; ---- party window')]
    tabs = B23_SRC[B23_SRC.index('BIT:    .db'):]
    mdata, msyms = menu_data(rom)
    src = '    org $8000\n    jmp gb_menu\n' + core + MENU_SRC + tabs + mdata + glyph_src(rom) + prophecy_data(rom)
    return asm(src, syms=dict(RAM, **msyms, **PROPH_RAM, **EPI_SYMS, FCX=FIELD_CAM['x'], FCY=FIELD_CAM['y']))


EPI = dict(x=6, y=9, w=20, h=16)     # epilogue window (b14:BAAF; NES (4,4,24,24)): text NES cols 6-25
EPI_SYMS = dict(EW_X=EPI['x'], EW_Y=EPI['y'], EW_W=EPI['w'], EW_H=EPI['h'], EVB=20, EP2=0xBFF0)   # EP2: page 2's
#   address (data in bank 24 outside the code module, written by dialogue())
B24L = [None]           # bank 24 labels (set by battle())
NATIVE_EXT = {}         # name -> (bank, address, GB routine, flags): native replacements of our
                        #   own NES routines, for the translator (<rom>.ext.json, build.py)


PROPH_RAM = dict(ROWX=0x75C0, PPG=0xD2, PRP=0xD4, PP=0x7600, PN=0x7601, PI=0x7602, PJ=0x7603, PH=0x7604, PK=0x7605,
                 PCNT=0x7606, PEXIT=0x7607, PAR=0x7608, PATT=0x7609, PRM=0x760A, PRLEN=0x760B,
                 PRA=0x760C, P64=0x760E)     # (prophecy; $7600 page: the menus' save area)


def prophecy_pages():
    """the prophecy (system string 73) at 18 columns, one paragraph a page, lines centred
    in the GB view (camera 6 / 6): [[(nes_row, nes_col, text)]]"""
    import json, textwrap
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
    t = [e for e in json.load(open(os.path.join(root, 'script', 'ff2', 'system.json'))) if e['id'] == 73][0]['en']
    pages = []
    for para in t.split('\n\n'):
        lines = textwrap.wrap(' '.join(para.split()), 18, break_on_hyphens=False)
        assert len(lines) <= 18
        r0 = 6 + (18 - len(lines)) // 2
        pages.append([(r0 + i, 6 + (20 - len(l)) // 2, l) for i, l in enumerate(lines)])
    assert len(pages) == 3
    return pages


def prophecy_data(rom):
    """bank 24 data for gm_prophecy: the letter tiles $80-$CF (bank 9 $8320 + 16 n, the menu
    font), PGTAB -> per page: line count, per line half row (row / 2), name table address,
    length, codes"""
    ins = _insert_module()
    b9 = rom[HDR + 9 * BANK:HDR + 10 * BANK]
    font = b9[0x320 + 16 * 0x80:0x320 + 16 * 0xD0]
    out = 'PFONT:\n' + ''.join('    .db %s\n' % ', '.join('$%02X' % v for v in font[i:i + 16]) for i in range(0, len(font), 16))
    out += 'PGTAB: .dw PG0, PG1, PG2\n'
    for k, page in enumerate(prophecy_pages()):
        out += 'PG%d: .db %d\n' % (k, len(page))
        for i, (r, c, l) in enumerate(page):
            a = 0x2000 + 32 * r + c
            codes = ins.enc(l)
            assert all(0x80 <= b < 0xD0 or b == 0xFF for b in codes), l
            out += '    .db %d, $%02X, $%02X, %d\n    .dw PL%d_%d\n' % (r // 2, a & 0xFF, a >> 8, len(codes), k, i)
        for i, (r, c, l) in enumerate(page):
            out += 'PL%d_%d: .db %s\n' % (k, i, ', '.join('$%02X' % b for b in ins.enc(l)))
    return out


GBM = [None]            # the main menu's entry (set by battle(), used by main_menu())

# main menu code (bank 24, entry gbm at $F8F0: A = sub-command; the renderer core of
# B23_SRC assembled into this bank as well)
MENU_SRC = r'''
; ---- field main menu (owner-approved revision of option A, ff2_mock9 + portraits inside
; the frame): camera (1, 1): GB (x, y) = NES (x+1, y+1). Party window NES (1,1,12,18), per
; member k (rows 2+4k..5+4k): portrait box cols 2-4 (background tiles $01+12k..; its 2 x 2
; attribute quads, cols 2-5, get a palette of its own, column 5 the window palette back
; by the GB-only override $5806-$580A), name / HP / MP / status
; word in cols 6-11 (HP and MP small letters: tiles $31+12k..). Commands NES (13,1,8,7),
; Gil NES (13,15,8,4) (amount in small digits: tiles $61-$66).
; GBARG: 0 init (menu start, LCD off), 1 party window, 2 Gil amount, 3 attributes back to
; the window palette (before a sub-menu), 4 field camera (menu closed)
gb_menu:
    lda $57
    pha
    lda #24             ; (the music update's bank restore comes back here)
    sta $57
    lda #0
    sta TBLHI
    lda GBARG           ; (a word table: the translator finds its targets)
    asl a
    tax
    lda MJT,x
    sta $00
    lda MJT+1,x
    sta $01
    jsr .go
    pla
    sta $57
    lda #0
    sta MSCR
    lda #$10
    sta TBLHI
    rts
.go:
    jmp ($0000)
MJT:  .dw gm_init, gm_party, gm_gil, gm_attr, gm_exit, gm_tparty, gm_shoptext, gm_slot, gm_ngcam, gm_prophecy, gm_rowinit, gm_rowdraw, gm_epage

gm_exit:                ; back to the field camera
    lda #FCX
    sta $5800
    lda #FCY
    sta $5801
    lda #0
    sta $580A
    rts

gm_init:                ; LCD off (b14:ACE3): camera, portrait tiles, their palettes
    lda #1
    sta $5800
    sta $5801
    lda #0
    sta $5802
    sta $5803
    lda #$FF
    sta SLOTP
    sta SLOTP+1
    sta SLOTP+2
    lda #0
    sta VI
.mem:
    lda VI
    asl a
    asl a
    asl a
    asl a
    asl a
    asl a
    tax                 ; X = 64 * k
    lda #$FF
    ldy VI
    sta MSLOT,y
    lda $6235,x         ; hidden (as b14:8852)
    bpl .vis
    jmp .next
.vis:
    lda $6101,x         ; palette index / portrait as b14:8852 and fix:E6FA
    ldy #$0B            ; dead: cross portrait (id 9)
    sty VT
    ldy #9
    asl a
    bcs .got
    ldy #$0A            ; stone: own portrait
    sty VT
    ldy #0
    asl a
    bcs .own
    ldy #$09            ; toad: toad portrait (id 10)
    sty VT
    ldy #10
    asl a
    bcs .got
.own:
    lda $6100,x
    and #$0F
    tay
    ldx VT
    cpx #$0A
    beq .got
    sty VT              ; (normal: palette by character)
.got:
    sty VC              ; portrait id
    ldx VT
    lda PALID,x         ; sprite palette 0-3 -> BG slot 0-2
    sta VSH
    ldx #0
.sl:
    lda SLOTP,x
    cmp VSH
    beq .slot
    cmp #$FF
    beq .new
    inx
    cpx #3
    bne .sl
    ldx #0
    beq .slot
.new:
    lda VSH
    sta SLOTP,x
.slot:
    txa
    ldy VI
    sta MSLOT,y
    asl a
    asl a
    tay                 ; Y = 4 * slot, X = 4 * palette
    lda VSH
    asl a
    asl a
    tax
    lda $03D1,x
    sta $03C1,y
    lda $03D2,x
    sta $03C2,y
    lda $03D3,x
    sta $03C3,y
    ldx VC              ; tiles: PPU (1 + 12k) * 16, 192 bytes from PORTG + 192 * id
    lda PGLO,x
    sta VQ
    lda PGHI,x
    sta VQ+1
    lda VI
    asl a
    adc VI              ; 3k
    asl a
    asl a               ; 12k
    clc
    adc #1
    jsr tileaddr
    ldy #0
    jsr pcopy           ; (the 12 portrait tiles; native on the GB: NATIVE_EXT b24_pcopy)
.next:
    inc VI
    lda VI
    cmp #4
    beq .done
    jmp .mem
.done:
    jmp $DC30           ; palettes to the PPU (as b14:ACE3)

gm_party:               ; b14:AD0A (replaces the four member windows b14:B396)
    lda #1
    sta MSCR
    lda #5              ; GB-only palette override: NES column 5, rows 2-17 in the window
    sta $5806           ;   palette (the portrait boxes' attribute quads are 32 px wide,
    sta $5807           ;   the portraits 24: the box is the portrait's width)
    lda #2
    sta $5808
    lda #17
    sta $5809
    lda #$83
    sta $580A
    ldx #0              ; the renderer's RAM ($7800-$78FF, menu cursor data here) saved
.sv:
    lda $7800,x
    sta $7600,x
    inx
    bne .sv
    ldx #7
.ft:
    txa
    clc
    adc #$F7
    sta FTILE,x
    dex
    bpl .ft
    lda #$FF
    sta BLANKT
    ldx #0
.cl:
    sta $7700,x
    inx
    cpx #160
    bne .cl
    lda #0
    sta VFILL
    sta NL
.mem:
    ldx NL
    lda MSLOT,x
    cmp #$FF
    bne .shown
    jmp .next
.shown:
    lda MBASE,x         ; Y = buffer offset of the block (40k)
    sta VSV
    tay
    lda NL              ; portrait: tiles 1 + 12k + 3r + c, column 3 = tile 0 (black)
    asl a
    adc NL
    asl a
    asl a
    clc
    adc #1
    sta VT
    ldx #0
.pr:
    lda VT
    sta $7700,y
    inc VT
    lda VT
    sta $7701,y
    inc VT
    lda VT
    sta $7702,y
    inc VT
    lda #$FF            ; (column 3: window colour, GB-only palette override)
    sta $7703,y
    tya
    clc
    adc #10
    tay
    inx
    cpx #4
    bne .pr
    lda NL              ; X = 64 k
    asl a
    asl a
    asl a
    asl a
    asl a
    asl a
    sta VCX
    tax
    ldy VSV             ; name (row 0, cols 4-9)
    lda #6
    sta VCNT
.nm:
    lda $6102,x
    sta $7704,y
    inx
    iny
    dec VCNT
    bne .nm
    lda NL              ; HP / MP tiles $31 + 12k / $37 + 12k (rows 1 / 2)
    asl a
    adc NL
    asl a
    asl a
    clc
    adc #$31
    sta VT
    lda VSV
    clc
    adc #14
    tay
    ldx #0
.hm:
    lda VT
    sta $7700,y
    clc
    adc #6
    sta $770A,y
    inc VT
    iny
    inx
    cpx #6
    bne .hm
    ldx VCX             ; status word (row 3, cols 5-9) as fix:ED04
    lda $6101,x
    beq .st
    ldy #7
.sb:
    asl a
    bcs .st0
    dey
    bne .sb
.st0:
    tya
.st:
    sta VT              ; 5 * index
    asl a
    asl a
    clc
    adc VT
    tax
    lda VSV
    clc
    adc #35
    tay
    lda #5
    sta VCNT
.sw:
    lda STW,x
    sta $7700,y
    inx
    iny
    dec VCNT
    bne .sw
    ldx VCX             ; HP line
    lda #CHH
    sta VC
    lda $6108,x
    sta MV
    lda $6109,x
    sta MV+1
    lda $610A,x
    sta MV+2
    lda $610B,x
    sta MV+3
    jsr gm_line
    lda NL
    asl a
    adc NL
    asl a
    asl a
    clc
    adc #$31
    jsr gm_up
    ldx VCX             ; MP line
    lda #CHM
    sta VC
    lda $610C,x
    sta MV
    lda $610D,x
    sta MV+1
    lda $610E,x
    sta MV+2
    lda $610F,x
    sta MV+3
    jsr gm_line
    lda NL
    asl a
    adc NL
    asl a
    asl a
    clc
    adc #$37
    jsr gm_up
.next:
    inc NL
    lda NL
    cmp #4
    beq .win
    jmp .mem
.win:
    lda #1
    sta VROW
    sta VCOL
    lda #12
    sta VW
    lda #18
    sta VH
    lda #$00
    sta VP
    lda #$77
    sta VP+1
    jsr ntwin
    lda #9              ; the gap between the commands and Gil windows (NES cols 13-20,
    sta VLINE           ;   rows 9-14) black: other screens (save, target) drew there
.gap:
    jsr $FA2A
    lda VLINE
    sta VSH
    lda #0
    sta VT
    ldx #5
.sh:
    asl VSH
    rol VT
    dex
    bne .sh
    lda VT
    ora #$20
    sta $2006
    lda VSH
    ora #13
    sta $2006
    lda #0
    ldx #8
.z:
    sta $2007
    dex
    bne .z
    jsr scroll
    inc VLINE
    lda VLINE
    cmp #15
    bne .gap
    jsr gm_attr2
    ldx #0
.rs:
    lda $7600,x
    sta $7800,x
    inx
    bne .rs
    rts
gm_tparty:              ; item / spell target (b14:A909, A8E5, AC60 instead of b14:B396):
    lda #1              ;   window NES (1,13,20,6), member k on row 14+k: name cols 2-7,
    sta MSCR            ;   HP cur/max cols 8-12 (tiles $31+9k..), MP cols 15-18 (tiles
    ldx #0              ;   $36+9k..) or the status word cols 14-18
.sv:
    lda $7800,x
    sta $7600,x
    inx
    bne .sv
    ldx #7
.ft:
    txa
    clc
    adc #$F7
    sta FTILE,x
    dex
    bpl .ft
    lda #$FF
    sta BLANKT
    ldx #0
.cl:
    sta $7700,x
    inx
    cpx #72
    bne .cl
    lda #0
    sta VFILL
    sta NL
.mem:
    lda NL
    asl a
    asl a
    asl a
    asl a
    asl a
    asl a
    sta VCX
    tax
    lda $6235,x
    bpl .shown
    jmp .next
.shown:
    lda NL              ; buffer row: 18 * k
    asl a
    sta VSV
    asl a
    asl a
    asl a
    clc
    adc VSV
    sta VSV
    tay
    lda #6
    sta VCNT
.nm:
    lda $6102,x
    sta $7700,y
    inx
    iny
    dec VCNT
    bne .nm
    lda NL              ; tiles: HP $31 + 9k (5), MP $36 + 9k (4)
    asl a
    asl a
    asl a
    clc
    adc NL
    clc
    adc #$31
    sta VT
    lda VSV
    clc
    adc #6
    tay
    ldx #5
.ht:
    lda VT
    sta $7700,y
    inc VT
    iny
    dex
    bne .ht
    ldx VCX
    lda $6101,x         ; status: the word (cols 12-16 of the buffer row), else MP
    beq .mp
    ldy #7
.sb:
    asl a
    bcs .st0
    dey
    bne .sb
.st0:
    tya
    beq .mp
    sta VT
    asl a
    asl a
    clc
    adc VT
    tax
    lda VSV
    clc
    adc #12
    tay
    lda #5
    sta VCNT
.sw:
    lda STW,x
    sta $7700,y
    inx
    iny
    dec VCNT
    bne .sw
    jmp .hp
.mp:
    lda VSV
    clc
    adc #13
    tay
    lda VT              ; (VT = $36 + 9k)
    ldx #4
.mt:
    sta $7700,y
    clc
    adc #1
    iny
    dex
    bne .mt
    ldx VCX
    lda $610C,x
    sta MV
    lda $610D,x
    sta MV+1
    lda $610E,x
    sta MV+2
    lda $610F,x
    sta MV+3
    lda #4
    jsr gm_digits
    lda NL
    asl a
    asl a
    asl a
    clc
    adc NL
    clc
    adc #$36
    jsr gm_upn
.hp:
    ldx VCX
    lda $6108,x
    sta MV
    lda $6109,x
    sta MV+1
    lda $610A,x
    sta MV+2
    lda $610B,x
    sta MV+3
    lda #5
    jsr gm_digits
    lda NL
    asl a
    asl a
    asl a
    clc
    adc NL
    clc
    adc #$31
    jsr gm_upn
.next:
    inc NL
    lda NL
    cmp #4
    beq .win
    jmp .mem
.win:
    lda #13
    sta VROW
    lda #1
    sta VCOL
    lda #20
    sta VW
    lda #6
    sta VH
    lda #$00
    sta VP
    lda #$77
    sta VP+1
    jsr ntwin
    ldx #0
.rs:
    lda $7600,x
    sta $7800,x
    inx
    bne .rs
    rts
gm_digits:              ; A = tiles (VN): "cur/max" (MV, MV+2) right-aligned in them
    sta VN
    jsr vclear
    lda MV+2
    sta VNUM
    lda MV+3
    sta VNUM+1
    jsr ndig
    sta NS
    lda MV
    sta VNUM
    lda MV+1
    sta VNUM+1
    jsr ndig
    sta VCNT
    clc
    adc NS
    adc #1
    asl a
    asl a
    sta VT
    lda VN
    asl a
    asl a
    asl a
    sec
    sbc VT
    sta VT
    lda VCNT
    asl a
    asl a
    clc
    adc VT
    jsr vnum
    lda #$1A
    jsr vchar
    lda MV+2
    sta VNUM
    lda MV+3
    sta VNUM+1
    lda NS
    asl a
    asl a
    clc
    adc VX
    jmp vnum
gm_upn:                 ; VBUF's VN tiles to tiles A ..
    ldx #0
.l:
    sta NTBUF,x
    clc
    adc #1
    inx
    cpx VN
    bne .l
    lda #<NTBUF
    sta VP
    lda #>NTBUF
    sta VP+1
    jmp vupload
gm_ngcam:               ; b14:B656 (game load menu, before its graphics): camera 6 / 6, no
    lda #6              ;   split or palette override (a reset can come from a battle)
    sta $5800
    sta $5801
    lda #0
    sta $5802
    sta $5803
    sta $5804
    sta $5805
    sta $580A
    rts
gm_slot:                ; b14:B7EC (load menu slot $9E & 3, owner approved ff2_mock13):
    lda #1              ;   window NES (6, 7 + 3k, 20, 4): number, leader name, Speed n;
    sta MSCR            ;   HP / MP cur/max in 3-px digits (tiles $31 + 12k ..)
    ldx #0
.sv:
    lda $7800,x
    sta $7600,x
    inx
    bne .sv
    ldx #7
.ft:
    txa
    clc
    adc #$F7
    sta FTILE,x
    dex
    bpl .ft
    lda #$FF
    sta BLANKT
    ldx #35
.cl:
    sta $7700,x
    dex
    bpl .cl
    lda #0
    sta VFILL
    lda $9E
    and #3
    sta NL
    clc
    adc #CH1
    sta $7700
    ldx NL
    lda $88,x
    beq .full
    jmp .win
.full:
    lda NL
    asl a
    asl a
    asl a
    asl a
    asl a
    asl a
    sta VCX
    tax
    ldy #0
.nm:
    lda $6102,x
    sta $7702,y
    inx
    iny
    cpy #6
    bne .nm
    ldx #0
.sp:
    lda SPEEDW,x
    sta $770A,x
    inx
    cpx #6
    bne .sp
    ldx VCX
    lda $6110,x
    clc
    adc #CH1
    sta $7710
    lda NL              ; HP / MP tiles
    asl a
    adc NL
    asl a
    asl a
    clc
    adc #$31
    sta VT
    ldx #0
.ht:
    lda VT
    sta $7714,x
    clc
    adc #6
    sta $771D,x
    inc VT
    inx
    cpx #6
    bne .ht
    ldx VCX
    lda #CHH
    sta VC
    lda $6108,x
    sta MV
    lda $6109,x
    sta MV+1
    lda $610A,x
    sta MV+2
    lda $610B,x
    sta MV+3
    jsr gm_line
    lda NL
    asl a
    adc NL
    asl a
    asl a
    clc
    adc #$31
    jsr gm_up
    ldx VCX
    lda #CHM
    sta VC
    lda $610C,x
    sta MV
    lda $610D,x
    sta MV+1
    lda $610E,x
    sta MV+2
    lda $610F,x
    sta MV+3
    jsr gm_line
    lda NL
    asl a
    adc NL
    asl a
    asl a
    clc
    adc #$37
    jsr gm_up
.win:
    lda NL
    asl a
    adc NL
    adc #7
    sta VROW
    lda #6
    sta VCOL
    lda #20
    sta VW
    lda #4
    sta VH
    lda #$00
    sta VP
    lda #$77
    sta VP+1
    jsr ntwin
    ldx #0
.rs:
    lda $7600,x
    sta $7800,x
    inx
    bne .rs
    rts
gm_prophecy:            ; b14:B8DD (prophecy, owner approved ff2_mock13; rendering off,
    lda #<PFONT         ;   attributes $55, names $FF): a copy of the letter tiles $80-$CF in
    sta $00             ;   tiles $01-$50 (a band being faded in is drawn with them: one GB
    lda #>PFONT         ;   tile coding per palette on the plain Game Boy), then the pages
    sta $01
    lda #$00
    sta $2006
    lda #$10
    sta $2006
    ldx #5
    ldy #0
    jsr pages0          ; (native on the GB: NATIVE_EXT b24_pages0)
    jsr $FE00           ; (as b14:B8DD-B8EF)
    jsr $DC30
    lda #0
    sta $2005
    sta $2005
    lda #$0A
    sta $2001
    lda #0
    sta PP
    sta PEXIT
    sta PRLEN
    lda #$FF
    sta PAR
.page:
    lda PP
    asl a
    tax
    lda PGTAB,x
    sta PPG
    lda PGTAB+1,x
    sta PPG+1
    ldy #0
    lda (PPG),y
    sta PN
    lda #0
    sta PI
.half:                  ; lines PI .. PJ - 1 share a half attribute row (two NES rows)
    lda PI
    sta PJ
    jsr pline
    tay
    iny
    lda (PPG),y
    sta PH
.hj:
    inc PJ
    lda PJ
    cmp PN
    beq .hd
    jsr plinej
    tay
    iny
    lda (PPG),y
    cmp PH
    beq .hj
.hd:
    lda #0              ; draw them with the copy tiles
    sta PRM
    jsr pdraw
    lda PEXIT
    beq .k1
    rts
.k1:
    lda PH              ; fade the half in: attribute row PH / 2, top half $5A (the
    lsr a               ;   bottom hidden), bottom half $AF (the top shown)
    sta PAR
    lda #$5A
    bcc .a0
    lda #$AF
.a0:
    sta PATT
    jsr pfade
    lda PEXIT
    beq .k2
    rts
.k2:
    lda PH              ; shown: $5F / $FF, drawn with the font itself
    lsr a
    lda #$5F
    bcc .a1
    lda #$FF
.a1:
    sta PATT
    lda #1
    sta PRM
    jsr pdraw
    lda PEXIT
    beq .k3
    rts
.k3:
    lda PJ
    sta PI
    cmp PN
    bne .half
    lda PP              ; hold: 240 frames, the last page until A / B (as the NES)
    cmp #2
    beq .last
    lda #240
    sta PCNT
.hold:
    jsr pframe
    lda PEXIT
    beq .k4
    rts
.k4:
    dec PCNT
    bne .hold
    lda #2              ; clear: the lines blanked, attributes back to $55
    sta PRM
    lda #0
    sta PI
    lda PN
    sta PJ
    jsr pdraw
    lda PEXIT
    beq .k5
    rts
.k5:
    lda #$55
    sta PATT
    lda #1
    sta PAR
.ca:
    jsr pframe
    lda PEXIT
    beq .k6
    rts
.k6:
    inc PAR
    lda PAR
    cmp #6
    bne .ca
    lda #$FF
    sta PAR
    inc PP
    jmp .page
.last:
    jsr pframe
    lda PEXIT
    beq .last
.out:
    rts
pline:                  ; Y = 6 PI + 1 (the line's record), PPG + Y
    lda PI
    jmp pliney
plinej:
    lda PJ
pliney:
    sta PCNT
    asl a
    adc PCNT
    asl a
    rts                 ; (A = 6 n; callers add the field offset)
pdraw:                  ; draw lines PI .. PJ - 1 in mode PRM (0 copy tiles, 1 font, 2 blank),
    lda PI              ;   one a frame
    sta PK
.l:
    lda PK
    cmp PJ
    beq .e
    asl a
    adc PK
    asl a
    tay
    iny
    iny
    lda (PPG),y         ; +2 address low, +3 high, +4 length, +5/+6 codes
    sta PRA
    iny
    lda (PPG),y
    sta PRA+1
    iny
    lda (PPG),y
    sta PRLEN
    iny
    lda (PPG),y
    sta PRP
    iny
    lda (PPG),y
    sta PRP+1
    jsr pframe
    lda PEXIT
    bne .e
    inc PK
    jmp .l
.e:
    rts
pfade:                  ; b14:B965: palette 2 colour 3 up in four steps of 16 frames,
    lda #0              ;   alternating with the step below on odd frames
    sta P64
.lp:
    lda P64
    sta $03CB
.fr:
    jsr pframe
    lda PEXIT
    bne .e
    inc $F0
    lda $F0
    and #$0F
    bne .odd
    lda P64
    clc
    adc #$10
    sta P64
    cmp #$40
    bcc .lp
.e:
    rts
.odd:
    lsr a
    bcc .lp
    lda $03CB
    sec
    sbc #$10
    bpl .s
    lda #$01
.s:
    sta $03CB
    jmp .fr
pframe:                 ; one frame (b14:B9B0): a line (PRLEN), the attribute row (PAR),
    jsr $FE00           ;   palettes, scroll, music, joypad (A / B -> PEXIT)
    lda PRLEN
    beq .na
    lda PRA+1
    sta $2006
    lda PRA
    sta $2006
    ldy #0
.c:
    lda PRM
    cmp #2
    beq .bl
    lda (PRP),y
    ldx PRM
    bne .w
    cmp #$80
    bcc .w
    cmp #$D0
    bcs .w
    sbc #$7E            ; (carry clear: - $7F)
    jmp .w
.bl:
    lda #$FF
.w:
    sta $2007
    iny
    cpy PRLEN
    bne .c
    lda #0
    sta PRLEN
.na:
    lda PAR
    bmi .nb
    asl a
    asl a
    asl a
    ora #$C0
    tax
    lda #$23
    sta $2006
    stx $2006
    lda PATT
    ldx #8
.at:
    sta $2007
    dex
    bne .at
.nb:
    jsr $DC30
    lda $FF
    sta $2000
    lda #0
    sta $2005
    sta $2005
    sta $24
    sta $25
    jsr $C74F
    jsr $DBA2
    lda $24
    ora $25
    sta PEXIT
    rts
gm_rowinit:             ; fix:F110 (row menu, rendering off; owner approved ff2_mock14): the
    jsr gm_init         ;   portrait tiles / palettes as the main menu, camera 6 / 5; the
    lda #6              ;   portraits are drawn by gm_rowdraw from the first frame on (the
    sta $5800           ;   window, drawn after this, covers their cells)
    lda #5
    sta $5801
    ldx #3
    lda #$FF
.x:
    sta ROWX,x
    dex
    bpl .x
    ldx #63
.c:
    sta $77A0,x
    dex
    bpl .c
    rts
gm_rowdraw:             ; fix:F182 (in place of the sprite portraits fix:F212, each frame):
    lda #0              ;   a member whose x ($61 + k: $80 front, $A0 back) changed is moved
    sta VI              ;   (old cells blanked, new drawn, quads re-coloured), a row a frame
.m:
    ldx VI
    lda MSLOT,x
    cmp #$FF
    beq .n
    lda $61,x
    cmp ROWX,x
    beq .n
    lda #1              ; (rows written in vblanks: music and scroll as the menus)
    sta MSCR
    lda ROWX,x          ; old place (none yet: $FF): blank, window palette
    cmp #$FF
    beq .new
    sta VCX
    lda #$FF
    sta VC
    jsr rowcells
    lda #3
    sta VT
    jsr rowquads
.new:
    ldx VI
    lda $61,x
    sta ROWX,x
    jsr rowput2
    jsr gm_aw
    lda #0
    sta MSCR
.n:
    inc VI
    lda VI
    cmp #4
    bne .m
    rts
rowput2:                ; the same with a vblank wait per row
    ldx VI
    lda ROWX,x
    sta VCX
    lda #0
    sta VC
    jsr rowcells
rowq:
    ldx VI
    lda MSLOT,x
    sta VT
    jmp rowquads
rowcells:               ; member VI's 4 x 4 cells at x VCX: VC = 0 portrait tiles 1 + 12k +
    lda #0              ;   3r + c (column 3: tile 0, black in any palette), else the window
    sta VCNT            ;   tile $FF; a vblank per row
.r:
    jsr $FA2A
    lda VI              ; PPU $2000 + 32 (6 + 4k + r) + VCX / 8
    asl a
    asl a
    clc
    adc #6
    adc VCNT
    sta VSH
    lda #0
    sta VN
    ldx #5
.sh:
    asl VSH
    rol VN
    dex
    bne .sh
    lda VCX
    lsr a
    lsr a
    lsr a
    ora VSH
    tax
    lda VN
    ora #$20
    sta $2006
    stx $2006
    lda VI              ; first tile 1 + 12k + 3r
    asl a
    adc VI
    asl a
    asl a
    sta VN
    lda VCNT
    asl a
    adc VCNT
    adc VN
    adc #1
    ldx #0
.t:
    ldy VC
    bne .b
    cpx #3
    beq .z
    sta $2007
    jmp .tn
.z:
    ldy #0
    sty $2007
    jmp .tn
.b:
    ldy #$FF
    sty $2007
.tn:
    clc
    adc #1
    inx
    cpx #4
    bne .t
    jsr scroll
    inc VCNT
    lda VCNT
    cmp #4
    beq .rd
    jmp .r
.rd:
    rts
rowquads:               ; member VI's 4 quads at x VCX (cols VCX/8 .. +3, rows 6+4k .. +3)
    lda #0              ;   get palette VT in the attribute copy $77A0
    sta VCNT
.q:
    lda VI              ; qy = 3 + 2k + (n >> 1), qx = VCX / 16 + (n & 1)
    asl a
    clc
    adc #3
    sta VSH
    lda VCNT
    lsr a
    clc
    adc VSH
    sta VSH             ; qy
    lda VCX
    lsr a
    lsr a
    lsr a
    lsr a
    sta VN
    lda VCNT
    and #1
    clc
    adc VN
    sta VN              ; qx
    lda VSH             ; index (qy >> 1) * 8 + (qx >> 1)
    lsr a
    asl a
    asl a
    asl a
    sta VC
    lda VN
    lsr a
    clc
    adc VC
    tax
    lda VSH             ; shift ((qy & 1) * 2 + (qx & 1)) * 2
    and #1
    asl a
    sta VC
    lda VN
    and #1
    ora VC
    asl a
    tay
    lda #3              ; mask and value
    sta VC
    lda VT
    sta VN
.s:
    dey
    bmi .sd
    asl VC
    asl VN
    jmp .s
.sd:
    lda VC
    eor #$FF
    and $77A0,x
    ora VN
    sta $77A0,x
    inc VCNT
    lda VCNT
    cmp #4
    bne .q
    rts
gm_epage:               ; fix:F399 (ending, owner approved ff2_mock15): the epilogue's page 1
    jsr ewait           ;   held 2 of the NES's 4 waits (fix:F3B0), page 2 (EP2, in the event
    jsr ewait           ;   bank) drawn over it with b14:BAAF's window, held 2 waits
    lda #1
    sta $37
    lda #EW_X
    sta $38
    lda #EW_X-1
    sta $97
    lda #EW_Y
    sta $39
    lda #EW_Y+2
    sta $98
    lda #EW_W
    sta $3C
    lda #EW_H
    sta $3D
    lda #EVB
    sta $93
    lda EP2
    sta $3E
    lda EP2+1
    sta $3F
    jsr $EAAC
    jsr ewait
ewait:                  ; fix:F3BC (232 frames), its music update through fix:C74F: C746
    lda #232            ;   leaves the music bank in place (bank 24 is running here)
    sta VCNT
.l:
    jsr $FE00
    lda #2
    sta $4014
    jsr $C74F
    dec VCNT
    bne .l
    rts
gm_shoptext:            ; b14:90FD (shop list text, owner approved ff2_mock12): per item the
    ldx #0              ;   name (column 1, cursor spot) and the price under it at column
    ldy #0              ;   13, from the shop data at $7B00 (id, price index); into $7B20
    lda #$08            ;   (one row per line)
    sta $7B20,y
    iny
.it:
    lda #$16
    sta $7B20,y
    iny
    lda #$01
    sta $7B20,y
    iny
    lda #$18
    sta $7B20,y
    iny
    lda $7B00,x
    sta $7B20,y
    inx
    iny
    lda #$01
    sta $7B20,y
    iny
    lda #$14
    sta $7B20,y
    iny
    lda #$0D
    sta $7B20,y
    iny
    lda #$19
    sta $7B20,y
    iny
    lda $7B00,x
    sta $7B20,y
    inx
    iny
    lda #$01
    sta $7B20,y
    iny
    cpx #8
    bne .it
    dey
    lda #0
    sta $7B20,y
    rts
gm_up:                  ; VBUF's 6 tiles to tiles A .. A+5
    ldx #0
.l:
    sta NTBUF,x
    clc
    adc #1
    inx
    cpx #6
    bne .l
    lda #6
    sta VN
    lda #<NTBUF
    sta VP
    lda #>NTBUF
    sta VP+1
    jmp vupload
gm_line:                ; VC = label letter ('H' / 'M'); MV = current, MV+2 = maximum:
    lda #6              ;   "HP" / "MP", "cur/max" ending at the line's right edge
    sta VN
    jsr vclear
    lda VC
    jsr vchar
    lda #CHP
    jsr vchar
    lda MV+2
    sta VNUM
    lda MV+3
    sta VNUM+1
    jsr ndig
    sta NS
    lda MV
    sta VNUM
    lda MV+1
    sta VNUM+1
    jsr ndig            ; start = 48 - 4 (dc + dm + 1)
    sta VCNT
    clc
    adc NS
    adc #1
    asl a
    asl a
    sta VT
    lda #48
    sec
    sbc VT
    sta VT
    lda VCNT
    asl a
    asl a
    clc
    adc VT
    jsr vnum            ; current (VNUM still the current)
    lda #$1A
    jsr vchar
    lda MV+2
    sta VNUM
    lda MV+3
    sta VNUM+1
    lda NS
    asl a
    asl a
    clc
    adc VX
    jmp vnum
ndig:                   ; A = digits of VNUM (1-4)
    ldx #0
.c:
    lda VNUM
    cmp POW,x
    lda VNUM+1
    sbc POWH,x
    bcs .x
    inx
    cpx #3
    bne .c
.x:
    txa
    eor #$FF
    clc
    adc #5
    rts

gm_attr:                ; window palette everywhere (sub-menus draw anywhere)
    lda #1
    sta MSCR
    lda #0              ; (palette override off)
    sta $580A
    ldx #63
    lda #$FF
.c:
    sta $77A0,x
    dex
    bpl .c
    bmi gm_aw
gm_attr2:               ; window palette, portrait quads of shown members their slot
    ldx #63
    lda #$FF
.c:
    sta $77A0,x
    dex
    bpl .c
    lda #0
    sta VI
.m:
    ldx VI
    lda MSLOT,x
    cmp #$FF
    beq .n
    sta VC
    lda VI
    asl a
    asl a
    sta VCNT            ; quad entries 4k .. 4k+3
    ldy #4
.q:
    ldx VCNT
    lda QSH,x
    tax
    lda VC
.s:
    dex
    bmi .sd
    asl a
    jmp .s
.sd:
    sta VT
    ldx VCNT
    lda QIDX,x
    tax
    lda $77A0,x
    pha
    txa
    pha
    ldx VCNT
    lda QMSK,x
    sta VSH
    pla
    tax
    pla
    and VSH
    ora VT
    sta $77A0,x
    inc VCNT
    dey
    bne .q
.n:
    inc VI
    lda VI
    cmp #4
    bne .m
gm_aw:                  ; the 64 bytes to $23C0 in one vblank
    jsr $FA2A
    lda #$23
    sta $2006
    lda #$C0
    sta $2006
    ldx #0
.w:
    lda $77A0,x
    sta $2007
    inx
    cpx #64
    bne .w
    jmp scroll

gm_gil:                 ; Gil amount (24 bits, $601C) in small digits, right edge of the
    lda #1              ;   Gil window's first line (NES row 16, cols 14-19)
    sta MSCR
    ldx #0
.sv:
    lda $7800,x
    sta $7600,x
    inx
    bne .sv
    lda $601C
    sta MV
    lda $601D
    sta MV+1
    lda $601E
    sta MV+2
    ldx #0              ; 7 decimal digits into NTBUF+8..
.d:
    lda #0
    sta VDIG
.sub:
    lda MV
    sec
    sbc P24L,x
    sta VT
    lda MV+1
    sbc P24M,x
    sta VC
    lda MV+2
    sbc P24H,x
    bcc .nd
    sta MV+2
    lda VC
    sta MV+1
    lda VT
    sta MV
    inc VDIG
    jmp .sub
.nd:
    lda VDIG
    sta NTBUF+8,x
    inx
    cpx #7
    bne .d
    ldx #0
.z:
    lda NTBUF+8,x
    bne .nz
    inx
    cpx #6
    bne .z
.nz:
    stx VI              ; first digit shown
    lda #6
    sta VN
    jsr vclear
    lda #7              ; VX = 48 - 4 * digits
    sec
    sbc VI
    asl a
    asl a
    sta VT
    lda #48
    sec
    sbc VT
    sta VX
.dr:
    ldx VI
    cpx #7
    beq .up
    lda NTBUF+8,x
    clc
    adc #$10
    jsr vchar
    inc VI
    jmp .dr
.up:
    lda #$61
    jsr gm_up
    jsr $FA2A           ; the row: tiles $61-$66 at $220E
    lda #$22
    sta $2006
    lda #$0E
    sta $2006
    ldx #$61
.r:
    stx $2007
    inx
    cpx #$67
    bne .r
    jsr scroll
    ldx #0
.rs:
    lda $7600,x
    sta $7800,x
    inx
    bne .rs
    rts
P24L: .db $40, $A0, $10, $E8, $64, $0A, $01
P24M: .db $42, $86, $27, $03, $00, $00, $00
P24H: .db $0F, $01, $00, $00, $00, $00, $00
MBASE: .db 0, 40, 80, 120
pages0:                 ; X pages from ($00) + Y to the PPU ($01 advanced)
    lda ($00),y
    sta $2007
    iny
    bne pages0
    inc $01
    dex
    bne pages0
    rts
pcopy:                  ; 192 bytes from (VQ) + Y to the PPU
    lda (VQ),y
    sta $2007
    iny
    cpy #192
    bne pcopy
    rts
'''


def battle(rom):
    c = CAM_BATTLE
    assert c['x2'] == 0
    f = asm(FIX_SRC, syms=dict(RAM, FCX=FIELD_CAM['x'], FCY=FIELD_CAM['y'], CX=c['x'], CF=c['fine'], CY=c['y'], CX2=c['x2'], CY2=c['y2'], CL=c['line']))
    assert f.org + len(f.bytes) <= 0xF850
    put(rom, 31, f.org, f.bytes)
    put(rom, 31, 0xFAB9, bytes([0x4C]) + f.labels['btlcam'].to_bytes(2, 'little'), old=bytes.fromhex('4c3996'))
    put(rom, 31, 0xFA0F, bytes([0x20]) + f.labels['fieldcam'].to_bytes(2, 'little') + b'\xEA\xEA',
        old=bytes.fromhex('a90e201afe'))
    # text window attributes (fix:D13D / D157): the metatile count from the window's first to
    # its last column (wattr), so a window on an odd column (field windows under the odd
    # field camera) gets its last column's attributes too; D157 reuses that count ($86)
    w = asm('''
    org $D13D
    lda $37
    bne $D163
    lda $3B
    lsr a
    sta $30
    lda $38
    lsr a
    sta $31
    jsr WATTR
    sta $86
    lda #$01
    sta $2D
    jmp $D24E
    org $D157
    lda $37
    bne $D163
    ldx $86
    dex
    jmp $D308
    nop
    nop
''', syms=dict(WATTR=f.labels['wattr']))
    put(rom, 31, 0xD13D, w.bytes[:0xD157 - 0xD13D], old=bytes.fromhex('a537d022a5384a8531a53b4a8530a53c4a8586a901852d4c4ed2'))
    put(rom, 31, 0xD157, w.bytes[0xD157 - 0xD13D:], old=bytes.fromhex('a537d008a53c4aaaca4c08d3'))
    # party: y = slot * 24 + 48 (NES: * 27 + 44), base x 156 front / 160 back (NES 208 / 224):
    # GB x 140 / 144, every member in a 24-px slot of the 96-px battlefield
    put(rom, 11, 0x9B68, bytes([0xA2, 24]), old=bytes([0xA2, 0x1B]))
    put(rom, 11, 0x9B6F, bytes([0x69, 48]), old=bytes([0x69, 0x2C]))
    put(rom, 11, 0xA102, bytes([0xA9, 156]), old=bytes([0xA9, 0xD0]))
    put(rom, 11, 0xA109, bytes([0xA9, 160]), old=bytes([0xA9, 0xE0]))
    # big knock-back (b11:B11B: x to 240 in 4-px steps and back): to x 164, reached from both
    # base x (156 / 160); x 240 is off the GB view (its right edge is NES x 180)
    put(rom, 11, 0xB120, bytes([0xA9, 164]), old=bytes([0xA9, 0xF0]))
    # one BG pattern table: the menu area keeps table 1 (no switch at the split, fix:FD60
    # AND #$EF -> AND #$FF), the menu does not scroll (b12:9AC6 scroll menu -> RTS)
    put(rom, 31, 0xFD63, bytes([0xFF]), old=bytes([0xEF]))
    put(rom, 12, 0x9AC6, bytes([0x60]), old=bytes([0x20]))
    put(rom, 12, 0x904A, bytes([0x00]), old=bytes([0x01]))   # menu area: nametable 0 (not 1)
    # the NES windows no longer reach the nametable (b12:930C copy window tilemap -> RTS);
    # the GB windows are drawn by bank 23
    put(rom, 12, 0x930C, bytes([0x60]), old=bytes([0x18]))
    # b12:9B3E (clear the old menu area with $FF, 10 rows): only its $7CCA = 0 is kept
    put(rom, 12, 0x9B3E, bytes.fromhex('a9008dca7c60'), old=bytes.fromhex('2046fda98885'))
    # bank 5 message boxes: their nametable writes off (STA $2007 -> BIT $07FF; the save /
    # restore reads stay); the GB message window replaces them
    for a in (0xAB0D, 0xAB14, 0xAB1C, 0xAB2A, 0xAB34, 0xAB3D, 0xAB91):
        put(rom, 5, a, bytes([0x2C, 0xFF, 0x07]), old=bytes([0x8D, 0x07, 0x20]))
    # the NES command pane (b12:9147, drawn once into the hidden right half): not needed;
    # command cursor (b12:BFC5, x / y per command): hand at the screen edge, rows 19-22
    put(rom, 12, 0x9147, bytes([0x60]), old=bytes([0x20]))
    put(rom, 12, 0xBFC5, bytes([0x00, 147, 0x00, 155, 0x00, 163, 0x00, 171]), old=bytes.fromhex('c0a8c0b8c0c8c0d8'))
    # battle magic list: the MP window (b12:9DB5 JSR $9250) not drawn, the list window
    # (b12:9DE3 JSR $9250) -> GB magic window; b12:9EF5's cost digits (9F3E-9F59, PPU) ->
    # GB page / MP line; cursor table b12:BFD5 (row r, column c: entry 2r + c): x 0 / 72,
    # y on line r mod 3
    put(rom, 12, 0x9DB5, bytes([0x2C, 0x50, 0x92]), old=bytes([0x20, 0x50, 0x92]))
    cur = bytes(v for r in range(8) for c in range(2) for v in ((0, 72)[c], 147 + 8 * (r % 3)))
    put(rom, 12, 0xBFD5, cur)
    # bank 23 + entries
    rom[HDR + 23 * BANK:HDR + 24 * BANK] = b'\xFF' * BANK
    b23 = bank23(rom, dict(gbf=f.labels['gbf']),
                 '\nRETB: .db %s\n' % ', '.join('$%02X' % rb for name, rb, nes in ENTRIES))
    assert len(b23.bytes) <= BANK
    put(rom, 23, 0x8000, b23.bytes)
    NATIVE_EXT['b23_vtile'] = (23, b23.labels['vtile'], 'hle_vtile', 'NZC')
    labels = {}
    for org, end, ks in ((0xFFD0, 0xFFFA, range(0, 8)), (0xFEEC, 0xFF00, range(8, 12))):   # (free:
        ent = 'org $%04X\n' % org                                                          #  rom info,
        for k in ks:                                                                        #  zeros)
            if k < len(ENTRIES): ent += 'e%d:\n    ldx #%d\n    jmp gbf\n' % (k, k)
        e = asm(ent, syms=dict(gbf=f.labels['gbf']))
        assert e.org + len(e.bytes) <= end
        put(rom, 31, e.org, e.bytes); labels.update(e.labels)
    assert len(ENTRIES) <= 12
    g = asm('''
    org $F8F0
gbm:                    ; main menu (bank 24): A = sub-command; back to bank 14
    sta GBARG
    lda #24
    jsr $FA7F
    jsr $8000
    lda #$0E
    jmp $FA7F
''', syms=dict(RAM))
    assert g.org + len(g.bytes) <= 0xF900
    assert set(rom[HDR + 31 * BANK + 0x38F0:HDR + 31 * BANK + 0x38F0 + len(g.bytes)]) <= {0}
    put(rom, 31, g.org, g.bytes)
    GBM[0] = g.labels['gbm']
    b24 = bank24(rom)
    assert len(b24.bytes) <= BANK, len(b24.bytes)
    rom[HDR + 24 * BANK:HDR + 25 * BANK] = b'\xFF' * BANK
    put(rom, 24, 0x8000, b24.bytes)
    B24L[0] = b24.labels
    NATIVE_EXT['b24_vtile'] = (24, b24.labels['vtile'], 'hle_vtile', 'NZC')
    assert RAM['VQ'] == 0xD4                     # (hle_pcopy reads the pointer at $D4)
    NATIVE_EXT['b24_pcopy'] = (24, b24.labels['pcopy'], 'hle_pcopy', 'NZC')
    NATIVE_EXT['b24_pages0'] = (24, b24.labels['pages0'], 'hle_pages0', 'NZ')
    class E: pass
    e = E(); e.labels = labels
    for k, (name, rb, nes) in enumerate(ENTRIES):
        if nes is not None: put(rom, rb, nes, bytes([0x4C]) + e.labels['e%d' % k].to_bytes(2, 'little'))
    ent = {name: e.labels['e%d' % k] for k, (name, rb, nes) in enumerate(ENTRIES)}
    put(rom, 12, 0x9DE3, bytes([0x20]) + ent['gb_magic'].to_bytes(2, 'little'), old=bytes([0x20, 0x50, 0x92]))
    put(rom, 12, 0xA058, bytes([0x4C]) + ent['gb_gear'].to_bytes(2, 'little'), old=bytes([0x4C, 0x50, 0x92]))
    # Gear cursor (b12:BFCD: right hand, left hand, item 1, item 2): hand at the screen edge
    put(rom, 12, 0xBFCD, bytes(v for k in range(4) for v in (0, 147 + 8 * k)), old=bytes.fromhex('48b048c048d048d8'))
    put(rom, 12, 0x9F3E, bytes([0x20]) + ent['gb_magcost'].to_bytes(2, 'little') + bytes([0x4C, 0x5A, 0x9F]),
        old=bytes.fromhex('a9238d0620'))
    loot(rom, ent)
    gear_updown(rom)


def gear_updown(rom):
    """Gear window: FF2's cursor grid is 2 x 2 (hands, items: b12:9BA8 with $5D = 2 columns,
    $5C = 2 rows; left / right switch the column); the GB window lists the four lines one
    under the other, so up / down step through all four (column * 2 + row, wrapping) when
    the grid is 2 x 2 (only the Gear window calls b12:9BA8 so). The slot chosen ($53 / $54)
    means the same as on the NES. Code in the dead parts of b12:9147 (command pane) and
    b12:930C (window copy), both turned into RTS above."""
    a = asm('''
    org $9148
g22:                    ; C = 1 and A = column * 2 + row in a 2 x 2 grid, else C = 0
    lda $5D
    cmp #2
    bne no
    lda $5C
    cmp #2
    bne no
    lda $53
    asl a
    ora $54
    sec
    rts
no:
    clc
    rts
gvdown:
    jsr g22
    bcc dn
    adc #0
gset:
    and #3
    lsr a
    sta $53
    lda #0
    rol a
    sta $54
    rts
dn:
    inc $54
    lda $54
    cmp $5C
    bne dx
    lda #0
    sta $54
dx:
    rts
''')
    assert a.org + len(a.bytes) <= 0x9187, hex(a.org + len(a.bytes))
    put(rom, 12, a.org, a.bytes)
    b = asm('''
    org $930D
gvup:
    jsr G22
    bcc un
    sbc #1
    jmp GSET
un:
    dec $54
    bpl ux
    ldx $5C
    dex
    stx $54
ux:
    rts
''', syms=dict(G22=a.labels['g22'], GSET=a.labels['gset']))
    assert b.org + len(b.bytes) <= 0x934A
    put(rom, 12, b.org, b.bytes)
    # down (b12:9C20-9C2E) / up (9C33-9C3E) handlers -> the wrappers, then JMP $9C6C
    put(rom, 12, 0x9C20, bytes([0x20]) + a.labels['gvdown'].to_bytes(2, 'little') + bytes([0x4C, 0x6C, 0x9C]) + b'\xEA' * 9,
        old=bytes.fromhex('e654a554c55cd004a90085544c6c9c'))
    put(rom, 12, 0x9C33, bytes([0x20]) + b.labels['gvup'].to_bytes(2, 'little') + bytes([0x4C, 0x6C, 0x9C]) + b'\xEA' * 6,
        old=bytes.fromhex('c6541005a65cca86544c6c9c'))


def loot(rom, ent):
    """treasure screen (bank 5): drawn into nametable 0 with BG pattern table 1 (the GB
    has one BG table) by bank 23 after the fade out; the GB navigation; cursor positions"""
    put(rom, 5, 0x9FCF, bytes([0x09, 0x00, 0x29, 0xFF]), old=bytes.fromhex('090129ef'))
    put(rom, 5, 0x9FDA, bytes([0x20]) + ent['gb_lootscr'].to_bytes(2, 'little') + b'\xEA' * 9,
        old=bytes.fromhex('a9008d05208d0520a9008500'))
    # frame loop (A1D0-A1DD: OAM, joypad, wait for a press; A1DE-A285: right / left / down /
    # up) -> stub at A1DE: GB cells, the same waits, GB navigation, then A / B as before
    put(rom, 5, 0xA1D0, bytes([0x4C, 0xDE, 0xA1]) + b'\xEA' * 11, old=bytes.fromhex('208aa12046fd2034fcad3400f0f2'))
    stub = asm('''
    org $A1DE
st:
    jsr LOOTF
    jsr $A18A
    jsr $FD46
    jsr $FC34
    lda $34
    beq st
    jsr LOOTNAV
    lda LNAV
    beq ab
    jmp $A3A6
ab:
    lda $34
    jmp $A286
''', syms=dict(LOOTF=ent['gb_lootf'], LOOTNAV=ent['gb_lootnav'], LNAV=RAM['LNAV']))
    assert stub.org + len(stub.bytes) <= 0xA286
    put(rom, 5, 0xA1DE, stub.bytes + b'\xEA' * (0xA286 - 0xA1DE - len(stub.bytes)))
    # cursor (b5:A416, 3 columns x 12 rows of x, y; x = the hand's right half): hands at GB
    # x -8 / 72 (NES 8 / 88 with camera X = 1), Done at GB 112; y = GB text row * 8 - 5;
    # treasure slots rows 2-5, Drop / Done row 1, inventory rows 7-16
    col0 = [((8, 88)[k & 1], (2 + k // 2) * 8 - 5) for k in range(8)] + [(88, 3), (128, 3)] * 2
    tab = bytearray()
    for c in range(3):
        rows = col0 if c == 0 else [((8, 88)[c - 1], (7 + min(v, 9)) * 8 - 5) for v in range(12)]
        for x, y in rows[:12]: tab += bytes([x, y])
    put(rom, 5, 0xA416, bytes(tab))


# ---------------------------------------------------------------- field dialogue
# Owner's layout (ff2_mock2): the box over the top of the GB view (field camera 6 / 6: NES
# screen columns 6-25, rows 6-13), 18 columns x 6 lines inside, the party visible below.
DLG_GB_W = 18
DLG_WIN = dict(left=5, top=6, width=20, height=8)     # text window 0 (fix:E9AA table)
# system strings shown in window 0 on the field (chest, nothing there, lock, ship / airship
# talk, keywords, save, warp, prayer, magic); the shop ones go with the shop layout
SYS_FIELD = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 14, 15, 16, 17, 18, 19, 20, 22, 25, 63, 64, 68, 71, 72,
             76, 77}   # (5-16: shops, inn)


def _insert_module():
    import importlib.util
    spec = importlib.util.spec_from_file_location('ff2insert', os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'ff2', 'insert.py'))
    ins = importlib.util.module_from_spec(spec); spec.loader.exec_module(ins)
    return ins


def gb_wrap(ins, text, width=DLG_GB_W):
    """insert.py's layout() at the GB width; a line still too wide (one long name with
    punctuation: 3 lines in the whole script) loses its indent, then its trailing '...'
    goes to a line of its own"""
    lines = []
    for p in ins.paragraphs(text):
        for l in (ins.flow(p, width) if p.strip() else ['']):
            if ins.vlen(l) > width: l = l.lstrip(' ')
            if ins.vlen(l) > width and l.endswith('...'):
                lines += [l[:-3], '...']; continue
            lines.append(l)
    lines = [ins.fix_keyword_columns(l) for l in lines]
    for l in lines: assert ins.vlen(l) <= width, (l, ins.vlen(l))
    return '\n'.join(lines)


# keyword menus (owner approved ff2_mock8): window 1 (Ask / Learn / Items) and window 2
# (keyword / item list) in GB rows 10-17 under the dialogue box
KW_WIN = {1: dict(left=5, top=16, width=8, height=6), 2: dict(left=5, top=16, width=20, height=8)}
# item names wider than the 18 columns (owner: condensed letters on tiles of their own):
# the last word in the condensed letters on fewer tiles (1-px gaps), in
# font tiles unused by the English field text (kana $7B-$7F, $F0-$F6)
LONG_NAMES = {137: 'plate', 41: 'Bottle', 90: 'Earth'}     # Diamond Breastplate, Sulfuric
LONG_TILES = [0x7B, 0x7C, 0x7D, 0x7E, 0x7F, 0xF0, 0xF1, 0xF2, 0xF3, 0xF4, 0xF5, 0xF6]   #   Acid Bottle, Sword of the Earth


# main menu windows (b14 menu window table $B48C/$B4A5/$B4BE/$B4D7): 4 commands, 5 Gil
MM_WIN = {4: (13, 1, 8, 8), 5: (13, 15, 8, 4),      # (heights even: rows drawn in pairs)
          6: (1, 1, 8, 4), 7: (1, 3, 20, 16),      # items: title, list (14 rows; the list's
#                                                      top frame covers the title's lower rows)
          # magic / equip / status (ff2_mock10): top window 8 / 15 (NES 1,1,20,6) with the
          # portrait box 9 / 14 and the values 10 drawn inside it without frames (b14:B451),
          # list windows 11 / 12 (NES 1,6,20,13: 11 rows), equip's replacement list 13
          8: (1, 1, 20, 6), 9: (1, 1, 6, 6), 10: (5, 3, 15, 4), 11: (1, 6, 20, 13),
          12: (1, 6, 20, 13), 13: (1, 13, 20, 6), 14: (1, 1, 6, 6), 15: (1, 1, 20, 6)}
MM_CMDS = ['Items', 'Magic', 'Equip', 'Status', 'Save']


def main_menu(rom, ins, bank, sysone):
    """main menu (gb_menu in bank 23): hooks in bank 14, windows, strings 27 / 28"""
    m = asm('''
    org $87D0
mm_init:                ; b14:ACE3 (LCD off): portraits, palettes (gm_init ends with DC30)
    lda #0
    jmp GBM
mm_party:               ; b14:AD0A: the party window
    lda #1
    jmp GBM
mm_gil:                 ; b14:ADB3: commands text, then the Gil amount
    jsr $B3DF
    lda #2
    jmp GBM
mm_close:               ; b14:B380 (close menu, before every sub-menu): window palette
    jsr $C46E
    lda #3
    jmp GBM
mm_exit:                ; b14:AD8C (menu closed): field camera, then close menu
    lda #4
    jsr GBM
    jmp $B380
mm_save:                ; b14:B1D7 (save menu, no close menu): window palette, the party
    jsr $DA8F           ;   lines (as the target screen) under the message
    lda #3
    jsr GBM
    lda #5
    jmp GBM
''', syms=dict(GBM=GBM[0]))
    assert m.org + len(m.bytes) <= 0x8800
    assert set(rom[HDR + 14 * BANK + 0x07D0:HDR + 14 * BANK + 0x07D0 + len(m.bytes)]) <= {0, 0xFF}
    put(rom, 14, m.org, m.bytes)
    L = m.labels
    put(rom, 14, 0xACE3, bytes([0x20]) + L['mm_init'].to_bytes(2, 'little'), old=bytes.fromhex('2030dc'))
    put(rom, 14, 0xAD0A, bytes([0x20]) + L['mm_party'].to_bytes(2, 'little'), old=bytes.fromhex('2096b3'))
    put(rom, 14, 0xADB3, bytes([0x4C]) + L['mm_gil'].to_bytes(2, 'little'), old=bytes.fromhex('4cdfb3'))
    put(rom, 14, 0xB380, bytes([0x20]) + L['mm_close'].to_bytes(2, 'little'), old=bytes.fromhex('206ec4'))
    put(rom, 14, 0xAD8C, bytes([0x20]) + L['mm_exit'].to_bytes(2, 'little'), old=bytes.fromhex('2080b3'))
    put(rom, 14, 0xB1D7, bytes([0x20]) + L['mm_save'].to_bytes(2, 'little'), old=bytes.fromhex('208fda'))
    put(rom, 14, 0x8800, b'\x60', old=b'\xa2')             # no sprite portraits (main menu)
    for w, (x, y, wd, h) in MM_WIN.items():
        for base, v in ((0xB48C, x), (0xB4A5, y), (0xB4BE, wd), (0xB4D7, h)):
            put(rom, 14, base + w, bytes([v]))
    rom[sysone + 28 // 8] |= 1 << (28 % 8)                  # Gil window one row per line
    # item / spell target (owner approved ff2_mock11): b14:AEC8-AF49 (the original item
    # menu's body, dead since insert.py's item menu) for the hooks
    t = asm('''
    org $AEC8
st_list:                ; b14:B37D (status: after the top window and the portrait box): the
    jsr $B3DF           ;   page-1 list (window 11)
    lda #0
    sta SPAGE
    sta SPREV
st_draw:
    ldx #$0B
    jsr $B486
    lda SPAGE
    clc
    adc #SP1
    jmp $B3DF
st_keys:                ; b14:B1CB (status loop): Left / Right turn the page; A = A or B
    lda $20             ;   pressed (for the BEQ after it)
    and #$03
    cmp SPREV
    sta SPREV
    beq .ab
    cmp #0
    beq .ab
    lda SPAGE
    eor #1
    sta SPAGE
    jsr st_draw
.ab:
    lda $24
    ora $25
    rts
sv_back:                ; b14:AD82 (save menu closed): party window, then commands / Gil
    lda #1
    jsr GBM
    jmp $ADA2
tg_party:               ; b14:A909 / A8E5 / AC60 (instead of the member windows b14:B396)
    lda #0              ; (the list's hand, cursor 3, hidden: the description covers the
    sta $A4             ;   list; the item / magic menus set it again when they redraw)
    lda #5
    jmp GBM
mm_sel:                 ; b14:AD3C / AD4B / AD5A (main menu: character select b14:AE59)
    lda #0              ;   with the main menu's cursor table (AEAA: the target lines)
    sta $79F0
    ldx #$0F
.l:
    lda MMTAB,x
    sta $7900,x
    dex
    bpl .l
    jmp $AE69
MMTAB:
    .db MSX, MSY, 0, 0, MSX, MSY+4, 0, 0, MSX, MSY+8, 0, 0, MSX, MSY+12, 0, 0
''', syms=dict(GBM=GBM[0], MSX=MM_SEL_X, MSY=MM_SEL_Y, SPAGE=0x75F6, SPREV=0x75F7, SP1=ST_P1))
    assert t.org + len(t.bytes) <= 0xAF4A, hex(t.org + len(t.bytes))
    put(rom, 14, t.org, t.bytes)
    # equip hooks: b14:B396-B3C7 (the member windows, all callers replaced) and b14:8801-8832
    # (the main menu's sprite portraits, 8800 is an RTS now)
    ea = asm('    org $B396\n' + EQ_A)
    assert ea.org + len(ea.bytes) <= 0xB3C8, hex(ea.org + len(ea.bytes))
    put(rom, 14, ea.org, ea.bytes)
    eb = asm('    org $8801\n' + EQ_B)
    assert eb.org + len(eb.bytes) <= 0x8833, hex(eb.org + len(eb.bytes))
    put(rom, 14, eb.org, eb.bytes)
    t.labels.update(ea.labels); t.labels.update(eb.labels)
    for a in (0xA909, 0xA8E5, 0xAC60, 0xB226, 0xB25E):      # (+ the save menu's previews)
        put(rom, 14, a, bytes([0x20]) + t.labels['tg_party'].to_bytes(2, 'little'), old=bytes.fromhex('2096b3'))
    put(rom, 14, 0xB2C0, bytes([0x4C]) + t.labels['tg_party'].to_bytes(2, 'little'), old=bytes.fromhex('4c96b3'))
    # back from the save menu (b14:AD82 JSR ADA2): the party window again first
    put(rom, 14, 0xAD82, bytes([0x20]) + t.labels['sv_back'].to_bytes(2, 'little'), old=bytes.fromhex('20a2ad'))
    for a in (0xAD3C, 0xAD4B, 0xAD5A):
        put(rom, 14, a, bytes([0x20]) + t.labels['mm_sel'].to_bytes(2, 'little'), old=bytes.fromhex('2059ae'))
    put(rom, 14, 0xAEAA, bytes(v for k in range(4) for v in (TG_SEL_X, TG_SEL_Y + k, 0, 0)))
    put(rom, 14, 0xB04B, bytes([0x4C]) + t.labels['eq_init'].to_bytes(2, 'little'), old=bytes.fromhex('a20c20'))
    put(rom, 14, 0xB078, bytes([0x20]) + t.labels['eq_open'].to_bytes(2, 'little') + b'\xEA', old=bytes.fromhex('a90185a4'))
    put(rom, 14, 0xB08E, bytes([0x20]) + t.labels['eq_close'].to_bytes(2, 'little') + b'\xEA', old=bytes.fromhex('a90085a4'))
    put(rom, 14, 0xB0B0, bytes([0x20]) + t.labels['eq_upd'].to_bytes(2, 'little') + b'\xEA' * 7,
        old=bytes.fromhex('a20c2051b4a92420cdb3'))
    for a in (0xAF6B, 0xAF75, 0xB039, 0xB043, 0xB378):     # portrait box / values: no frame
        put(rom, 14, a, bytes([0x20, 0x51, 0xB4]), old=bytes.fromhex('2086b4'))
    put(rom, 14, 0xB37D, bytes([0x4C]) + t.labels['st_list'].to_bytes(2, 'little'), old=bytes.fromhex('4cdfb3'))
    put(rom, 14, 0xB1CB, bytes([0x20]) + t.labels['st_keys'].to_bytes(2, 'little') + b'\xEA\xEA\xEA',
        old=bytes.fromhex('a5240525f0ef')[:6])
    put(rom, 14, 0xB1D1 - 2, bytes([0xF0, (0xB1C0 - 0xB1D1) & 0xFF]))  # (BEQ $B1C0 after the JSR)
    put(rom, 14, 0x8834, bytes([0x0F]), old=bytes([0x0F]))
    put(rom, 14, 0x8838, bytes([0x14]), old=bytes([0x64]))    # magic / equip portrait: centred in its box
    shop_layout(rom, ins, bank, sysone)
    for sid in (40, 41, 42):
        rom[sysone + sid // 8] |= 1 << (sid % 8)
    for sid in (32, 33, 34, 35, 39, ST_P1, ST_P1 + 1):
        rom[sysone + sid // 8] |= 1 << (sid % 8)
    for sid, txt in sub_strings(ins).items():
        bank.put_ptr(0x8400 + 2 * sid, bank.alloc(ins.enc(txt) + b'\0'))
    for base, v in ((0xB48C, 1), (0xB4A5, 1), (0xB4BE, 20), (0xB4D7, 12)):   # window 16: description
        put(rom, 14, base + 16, bytes([v]))
    for sid in range(43, 63):
        rom[sysone + sid // 8] |= 1 << (sid % 8)
    rom[sysone + 31 // 8] |= 1 << (31 % 8)                  # items title one row per line
    t37 = '\n'.join(['{08}{17:00}{1A:%02X}' % i for i in range(32)] + ['{08}{17:00}{0F}'])
    bank.put_ptr(0x8400 + 2 * 37, bank.alloc(ins.enc(t37) + b'\0'))   # items from column 0 (18)
    t27 = '\n'.join('{15:00}' + c for c in MM_CMDS)
    t28 = '\n{14:03}Gil'
    for sid, t in ((27, t27), (28, t28)):
        bank.put_ptr(0x8400 + 2 * sid, bank.alloc(ins.enc(t) + b'\0'))


EQ_A = r'''
eq_init:                ; b14:B04B (equip): the replacement list (window 13) first, its text
    ldx #$0D            ;   variables saved (as b14:B05F), then the slots (window 12) over it
    jsr $B486
    lda #$25
    jsr $B3F0
    jsr $94EB
    ldx #$0C
    jsr $B486
    lda #$24
    jsr $B3CD
    jmp $B062
eq_open:                ; b14:B078 (a slot chosen): the replacement list opens (the slot's
    lda #1              ;   hand, cursor 2, hidden: the slot may be under the list); its text
    sta $A4             ;   by b14:B0BA (restore its variables, draw, JMP $B07C: where the
    lsr a               ;   caller goes next anyway)
    sta $A3
    ldx #$0D
    jsr $B486
    pla
    pla
    jmp $B0BA
'''
EQ_B = r'''
eq_close:               ; b14:B08E (B in the list): the slots again, their hand back
    lda #0
    sta $A4
    lda #1
    sta $A3
    ldx #$0C
    jsr $B486
    lda #$24
    jmp $B3CD
eq_upd:                 ; b14:B0B0 (equipment changed): slots text, the list's frame again
    ldx #$0C            ;   (b14:B0BA draws its text)
    jsr $B451
    lda #$24
    jsr $B3CD
    ldx #$0D
    jmp $B486
'''

SHOP_GIL = 82           # shop Gil window text (system string 28 is the main menu's now)
SHOP_LIST = dict(left=5, top=6, width=20, height=10)   # NES screen: GB (0,0,20,10)
SHOP_WIN3 = dict(left=13, top=16, width=12, height=4)  # Gil window: GB (8,10,12,4)


def shop_layout(rom, ins, bank, sysone):
    """shops (owner approved ff2_mock12): the buy list in a window of its own over the
    dialogue box (b14:90DB, after the prompt), its text built in bank 24 (b14:90FD), the Gil
    window 3 under the box beside Buy / Sell / Exit (window 1, as the keyword menu)"""
    L, T, W, H = SHOP_LIST['left'], SHOP_LIST['top'], SHOP_LIST['width'], SHOP_LIST['height']
    b = asm('''
    org $90FD
    lda #6              ; the list text (bank 24)
    jmp GBM
shop_l2:
    lda #TOP+2
    sta $98
    lda #WID
    sta $3C
    lda #HGT
    sta $3D
    ldx #4              ; sprites behind it (region 4; FF2's regions leave out the player:
    jsr $E843           ;   its sprites 0-3 hidden here, the field draws them again)
    lda #$F0
    sta $0200
    sta $0204
    sta $0208
    sta $020C
    jsr $E923
    lda #$20
    sta $3E
    lda #$7B
    sta $3F
    jmp $E7AC
''', syms=dict(GBM=GBM[0], TOP=T, WID=W, HGT=H))
    assert b.org + len(b.bytes) <= 0x9139, hex(b.org + len(b.bytes))
    put(rom, 14, b.org, b.bytes)
    a = asm('''
    org $90DB
shop_list:
    lda $29
    asl a
    clc
    adc #LFT
    and #$3F
    sta $38
    lda $2F
    asl a
    clc
    adc #TOP
    cmp #$1E
    bcc .y
    sbc #$1E
.y:
    sta $39
    lda #LFT-1
    sta $97
    jmp L2
''', syms=dict(LFT=L, TOP=T, L2=b.labels['shop_l2']))
    assert a.org + len(a.bytes) <= 0x90FD
    put(rom, 14, a.org, a.bytes)
    put(rom, 14, 0x9141, bytes([SHOP_GIL]), old=bytes([0x1C]))
    w = SHOP_WIN3
    for k, key in enumerate(('left', 'top', 'width', 'height')):
        put(rom, 31, 0xE9AA + 4 * k + 3, bytes([w[key]]))
    for wnd, (x0, y0, ww, hh) in ((3, (8 * w['left'], 8 * w['top'], w['width'], w['height'])),
                                  (4, (8 * L, 8 * T, W, H))):
        x1, y1 = x0 + 8 * ww, y0 + 8 * hh
        for k, v in enumerate((x0 - 6, x1 - 1, y0 - 6, y1 - 9)):
            put(rom, 31, 0xE892 + 6 * k + wnd, bytes([v]))
    # dialogue close (fix:D164: metatile rows X-$66 .. X-1 of the screen redrawn): rows 2-7
    # (tile rows 4-15): the dialogue box and the list window
    put(rom, 31, 0xD168, bytes([6]), old=bytes([5]))
    put(rom, 31, 0xD16C, bytes([8]), old=bytes([6]))
    for sid in (12, 23, 24, SHOP_GIL):
        rom[sysone + sid // 8] |= 1 << (sid % 8)
    t12 = "I'll buy it for\n{04} Gil.\nIs that all right?\n{16:03}Yes{16:08}No"
    t21 = '{08}Where are you\nheaded?\n' + '\n'.join('{16:01}%s{14:0E}%d' % (p, 100 * (k + 1)) for k, p in
                                                     enumerate(('Bafsk', 'Salamand', 'Semite Falls', 'Kashuon')))
    for sid, t in ((12, t12), (21, t21)):
        bank.put_ptr(0x8400 + 2 * sid, bank.alloc(ins.enc(t) + b'\0'))
    bank.put_ptr(0x8400 + 2 * SHOP_GIL, bank.alloc(ins.enc('{14:03}{05}\n{14:07}Gil') + b'\0'))


ST_P1 = 80              # status pages: system strings 80 / 81 (ids unused by the game)


# new-game screens (owner approved ff2_mock13): camera 6 / 6 (the boot camera), so the
# screens are laid out in NES cols 6-25, rows 6-23
NG_WIN = {22: (6, 6, 20, 6),            # name entry: portrait + name (GB 0,0,20,6)
          23: (6, 12, 20, 12)}          # letter grid (GB 0,6,20,12): 5 of its 9 rows shown
NG_LOAD = {21: (6, 20, 20, 4)}        # New Game window (GB 0,14,20,4)
NG_COLS = 9                             # letters a row (NES 10, in two groups of 5)


def new_game(rom, ins, bank, sysone):
    import json, re
    sys_en = {e['id']: e['en'] for e in json.load(open('script/ff2/system.json'))}
    for w, (x, y, wd, h) in NG_WIN.items():
        for base, v in ((0xB48C, x), (0xB4A5, y), (0xB4BE, wd), (0xB4D7, h)):
            put(rom, 14, base + w, bytes([v]))
    # name window (string 69): the portrait's 4 columns, the name from column 5 (GB col 6)
    t69 = sys_en[69]
    assert '{14:07}' in t69
    bank.put_ptr(0x8400 + 2 * 69, bank.alloc(ins.enc(t69.replace('{14:07}', '{14:05}')) + b'\0'))
    put(rom, 14, 0x8848, bytes([8 * 7]), old=bytes([0x44]))          # portrait x / y (GB 1, 1)
    put(rom, 14, 0x884C, bytes([8 * 7 - 1]), old=bytes([0x1F]))
    put(rom, 14, 0xB628, bytes([8 * 8 - 1]), old=bytes([0x27]))      # name cursor: row 8,
    put(rom, 14, 0xB63D, bytes([8 * 12]), old=bytes([0x78]))         #   from column 12
    # letter grid (string 70): the same letters in their order, NG_COLS a row two columns
    # apart from column 1 of the window; the cursor moves NG_COLS entries up / down
    ents = re.findall(r'\{17:[0-9A-F]{2}\}([^{\n]|\[[0-9A-F]{2}\])', sys_en[70].replace('\n', ''))
    assert len(ents) == 80, len(ents)
    rows = [ents[i:i + NG_COLS] for i in range(0, len(ents), NG_COLS)]
    t70 = '\n'.join(''.join('{17:%02X}%s' % (1 + 2 * c, ch) for c, ch in enumerate(r)) for r in rows)
    bank.put_ptr(0x8400 + 2 * 70, bank.alloc(ins.enc(t70) + b'\0'))
    put(rom, 14, 0xB566, bytes([4 * NG_COLS]), old=bytes([0x28]))
    # load menu: slot windows drawn by bank 24 (gm_slot, sub-command 7) in place of b14:B7EC
    # (window + string 74); the freed bytes call the camera reset (sub-command 8) at B656
    g = GBM[0]
    k = asm('''
    org $B7EC
    lda #7
    jmp GBM
ngcam:
    lda #8
    jsr GBM
    jmp $E491
''', syms=dict(GBM=g))
    assert k.org + len(k.bytes) <= 0xB7FC
    put(rom, 14, k.org, k.bytes, old=bytes.fromhex('a59e2903186911aa2086b4a94a4c45b8')[:len(k.bytes)])
    put(rom, 14, 0xB656, bytes([0x20]) + k.labels['ngcam'].to_bytes(2, 'little'), old=bytes.fromhex('2091e4'))
    rom[sysone + 75 // 8] |= 1 << (75 % 8)             # New Game line: one row (GB row 15)
    for w, (x, y, wd, h) in NG_LOAD.items():
        for base, v in ((0xB48C, x), (0xB4A5, y), (0xB4BE, wd), (0xB4D7, h)):
            put(rom, 14, base + w, bytes([v]))
    # cursor spots (b14:B7CE: column, character row): hand at NES column 5 (GB x -8)
    cur = bytes(v for r in [8, 11, 14, 17, 21] for v in (5, r, 0, 0))
    put(rom, 14, 0xB7CE, cur, old=bytes.fromhex('02040000020900000 20e000002130000 02190000'.replace(' ', '')))

    credits(rom)
    # prophecy: b14:B8DD-B8FC (frame, window 24 + string 73, the reveal b14:B932) -> bank 24
    p = asm('''
    org $B8DD
    lda #9
    jsr GBM
    jmp $B8FD
''', syms=dict(GBM=g))
    put(rom, 14, p.org, p.bytes, old=bytes.fromhex('2000fe2030dca900'))


def gb_credit_lines(codes):
    """one NES credit line -> GB lines of at most 18 tiles: leading / trailing blanks dropped;
    a longer line is split after the word BY (codes $02 $19)"""
    c = list(codes)
    while c and c[0] == 0: c.pop(0)
    while c and c[-1] == 0: c.pop()
    if len(c) <= 18: return [c]
    for k in range(len(c) - 2):
        if c[k:k + 3] == [0x02, 0x19, 0x00]: return [c[:k + 2], c[k + 3:]]
    return [c[:18], c[18:]]


NG_CREDIT_ROWS = [3, 6, 9, 11, 12, 14, 15]      # GB rows of the credit lines (ff2_mock13)


def credits(rom):
    """splash screen (fix:F476): the ROM's credit lines (data fix:F692) centred in the GB view
    (18 columns; a longer line split after BY); a new line starts at NES column 6 (GB 0) one
    row down (fix:F562 +$40 -> +$20), so blank rows are extra $FE codes. Every character,
    spaces too, takes a tile ($01-$7F), so the leading spaces now start at column 6."""
    o = HDR + 31 * BANK + 0xF692 - 0xC000
    lines, row, cur = [], 8, []
    while rom[o] != 0xFF:
        if rom[o] == 0xFE: lines.append(cur); cur = []
        else: cur.append(rom[o])
        o += 1
    lines.append(cur)
    gb = [sg for l in lines if any(l) for sg in gb_credit_lines(l)]
    assert len(gb) == len(NG_CREDIT_ROWS), [len(x) for x in gb]
    data, row = bytearray(), 8
    for sg, r in zip(gb, NG_CREDIT_ROWS):
        data += b'\xFE' * (r + 6 - row); row = r + 6
        data += bytes((20 - len(sg)) // 2) + bytes(sg)
    data += b'\xFE\xFF'                   # (the last new line clears the typing row)
    nchar = sum(1 for b in data if b < 0xFE)
    assert nchar < 0x80 and len(data) <= 0xF74E - 0xF692, (nchar, len(data))
    put(rom, 31, 0xF692, data)
    put(rom, 31, 0xF504, bytes([0x06]), old=bytes([0x02]))      # first line: $2106
    put(rom, 31, 0xF593, bytes([0x20]), old=bytes([0x40]))      # a new line one row down,
    put(rom, 31, 0xF595, bytes([0x06]), old=bytes([0x02]))      #   from column 6


def sub_strings(ins):
    """the sub-screens' strings: titles at column 4 of the top window (beside the portrait
    box), values without leading blanks, status split into the top window and two pages"""
    st = [('Strength', 0x26), ('Agility', 0x27), ('Stamina', 0x28), ('Intelligence', 0x29),
          ('Spirit', 0x2A), ('Magic Power', 0x2B)]
    cb = [('Attack', 0x24, ''), ('Hit Rate', 0x2D, '%'), ('Defense', 0x25, ''), ('Evasion', 0x2E, '%'),
          ('Magic Defense', 0x2F, '%')]
    p1 = ['%s{14:0E}..{10:%02X}' % (l, c) for l, c in st] + \
         [('%s{14:0C}{10:%02X}%s' if pc else '%s{14:0D}..{10:%02X}%s') % (l, c, pc) for l, c, pc in cb[:4]]
    md = ['%s' % cb[4][0], '{14:0C}{10:%02X}%s' % (cb[4][1], cb[4][2])]   # 19 wide: two rows, page 2
    # (attributes 2 digits after ".." at 14-15; attack / defense 3 wide; hit rate, evasion,
    # magic defense print " hits-percent" + % (6): cols 12-17)
    sk = ['{14:00}[%02X] {10:%02X}{14:09}[%02X] {10:%02X}' % (0x6E + 2 * r, 0x30 + 2 * r, 0x6F + 2 * r, 0x31 + 2 * r)
          for r in range(4)]
    import json, re
    sv = {e['id']: e['en'] for e in json.load(open('script/ff2/system.json')) if e['id'] in (40, 41, 42)}
    def lines(t):                       # each original line wrapped at 18 (no reflow: the
        out = []                        #   Japanese line breaks separate sentences here)
        for l in t.split('\n'):
            m = re.search(r'\{16:', l)
            text, spots = (l[:m.start()], l[m.start():]) if m else (l, '')
            if text.strip(): out += ins.flow(text.strip(), 18)
            if spots: out.append(spots)
        return '\n'.join(out)
    save = {40: lines(sv[40].replace('{16:09}Yes{16:0D}No', '\n{16:03}Yes{16:08}No')), 41: lines(sv[41]),
            # 42: "Save complete!" only: the rest ("hold down the RESET button while you turn the
            # power off") is about the Famicom; the Game Boy has no RESET button (Lot Check:
            # hardware named correctly in all text). (Before: the whole text flowed at 18.)
            42: sv[42].split('!')[0].strip() + '!'}
    out = {32: '{14:04}Magic\n{14:04}{10:02}', 34: '{14:04}Equip\n{14:04}{10:02}',
            33: 'HP {10:20}/{10:21}\nMP  {10:22}/ {10:23}',
            39: '{14:04}{10:02}\n{14:04}HP {10:20}/{10:21}\n{14:04}MP  {10:22}/ {10:23}\n{14:04}{10:00}',
            ST_P1: '\n'.join(p1), ST_P1 + 1: '\n'.join(md + ['', 'Skill Level'] + sk)}
    out.update(save)
    return out


MM_SEL_X, MM_SEL_Y = 0, 3
TG_SEL_X, TG_SEL_Y = 0, 14


def keyword_menus(rom, ins, bank):
    """windows 1 / 2 moved (table fix:E9AA, sprite regions fix:E892), the Ask / Learn /
    Items menu (system 26) one row per line (ExRAM SYSONE bit), the keyword / item lists
    (65 / 66) from column 0, the long item names"""
    import json
    from latin_font import left_label
    for wnd, w in KW_WIN.items():
        for k, key in enumerate(('left', 'top', 'width', 'height')):
            put(rom, 31, 0xE9AA + 4 * k + wnd, bytes([w[key]]))
        x0, y0 = 8 * w['left'], 8 * w['top']
        x1, y1 = x0 + 8 * w['width'], y0 + 8 * w['height']
        for k, v in enumerate((x0 - 6, x1 - 1, y0 - 6, y1 - 9)):
            put(rom, 31, 0xE892 + 6 * k + wnd, bytes([v]))
    import importlib.util                       # (the real assembler: a recording run of
    spec = importlib.util.spec_from_file_location(  #   ff2en must not see this module)
        'asm6502_plain', os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'asm6502.py'))
    a6 = importlib.util.module_from_spec(spec); spec.loader.exec_module(a6)
    ex = a6.asm(ins.EXRAM_SRC, syms={k: 0 for k in ('DB', 'DA', 'SB', 'SA', 'R0', 'R1', 'BT')})
    o = HDR + ins.CODE_BANK * BANK + ex.labels['SYSONE'] - ex.org
    assert rom[o + 27 // 8] & (1 << (27 % 8)), 'SYSONE not where expected'
    rom[o + 26 // 8] |= 1 << (26 % 8)
    for sid, n in ((65, 16), (66, 32)):
        t = '\n'.join('{08}{17:00}{%s:%02X}' % ('1B' if sid == 65 else '1A', i) for i in range(n))
        bank.put_ptr(0x8400 + 2 * sid, bank.alloc(ins.enc(t) + b'\0'))
    # the list window covers the Ask / Learn / Items window: its hand hidden while a list is
    # open (b14:955B / 9567 open window 2), and the list closed (fix:D16F, as the game
    # closes it when the conversation ends) before the menu opens again (the three
    # JMP $9174 after a list). Code in bank 14's unused $87BB-$87FF.
    k = asm('''
    org $87C0
kwopen:
    lda #0
    sta $A2
    lda #2
    sta $96
    rts
kwback:
    jsr $D16F
    jmp $9174
''')
    assert set(rom[HDR + 14 * BANK + 0x07C0:HDR + 14 * BANK + 0x07C0 + len(k.bytes)]) <= {0, 0xFF}
    put(rom, 14, k.org, k.bytes)
    for a in (0x955B, 0x9567):
        put(rom, 14, a, bytes([0x20]) + k.labels['kwopen'].to_bytes(2, 'little') + b'\xEA', old=bytes.fromhex('a9028596'))
    for a in (0x91A5, 0x91AF, 0x91B5):
        put(rom, 14, a, bytes([0x4C]) + k.labels['kwback'].to_bytes(2, 'little'), old=bytes.fromhex('4c7491'))
    main_menu(rom, ins, bank, o)
    new_game(rom, ins, bank, o)
    tiles = list(LONG_TILES)
    for e in json.load(open('script/ff2/names.json')):
        if e['id'] not in LONG_NAMES: continue
        name, tail = e['en'], LONG_NAMES[e['id']]
        assert name.endswith(tail)
        head = ins.enc(name[:-len(tail)])
        n = DLG_GB_W - len(head)
        assert 0 < n < len(tail), name
        codes = [tiles.pop(0) for _ in range(n)]
        t = left_label(tail, True, fg=3, bg=2)
        assert len(t) <= n, (name, len(t), n)
        t += [bytes(8) + b'\xFF' * 8] * (n - len(t))
        for c, data in zip(codes, t):
            q = HDR + ins.FONT + c * 16; rom[q:q + 16] = data
        bank.put_ptr(0x8200 + 2 * e['id'], bank.alloc(head + bytes(codes) + b'\0'))


def dialogue(rom):
    """Field text window 0 (dialogue, events) at DLG_WIN; dialogue and event text wrapped at
    18 columns (insert.py's paragraphs / flow, the same banks and bank split as insert.py),
    the ending moved after the events again (bank 14 $BACE pointer)."""
    import json
    ins = _insert_module()
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
    cwd = os.getcwd(); os.chdir(root)
    try:
        for e in json.load(open('script/ff2/names.json')): ins.NAMES[e['id']] = e['en']
        w = DLG_WIN
        for k, (key, v) in enumerate((('left', w['left']), ('top', w['top']), ('width', w['width']), ('height', w['height']))):
            put(rom, 31, 0xE9AA + 4 * k, bytes([v]), old=bytes([(2, 2, 0x1C, 0x0A)[k]]))
        # sprites behind window 0 (fix:E843, region table E892: x from / to, y from / to;
        # NES: x 10-238, y 10-86 for the box at 16-239 x 16-95): the GB box's region
        x0, y0 = 8 * w['left'], 8 * w['top']
        x1, y1 = x0 + 8 * w['width'], y0 + 8 * w['height']
        for k, (v, o) in enumerate(((x0 - 6, 0x0A), (x1 - 1, 0xEF), (y0 - 6, 0x0A), (y1 - 9, 0x57))):
            put(rom, 31, 0xE892 + 6 * k, bytes([v]), old=bytes([o]))
        free_ev = None
        for name, banks in (('dialogue_b', [ins.DB_BANK, ins.DB_BANK + 1]), ('dialogue_a', [ins.DA_BANK, ins.DA_BANK + 1]),
                            ('events', [ins.EV_BANK])):
            rows = json.load(open('script/ff2/%s.json' % name))
            size = {e['id']: len(ins.enc(ins.layout(e['en']))) + 1 for e in rows if e['en']}   # insert.py's split
            total = sum(size.values()); acc = 0; split = 256
            if len(banks) > 1:
                for i in sorted(size):
                    acc += size[i]
                    if acc > total / 2: split = i; break
            used = {}
            for b in banks:
                rom[HDR + b * BANK:HDR + (b + 1) * BANK] = b'\xFF' * BANK
                used[b] = ins.Bank(rom, b, [(0x8200, 0xC000)])
            for e in rows:
                b = banks[1 if e['id'] >= split else 0]
                txt = gb_wrap(ins, e['en']) if e['en'] else ''
                used[b].put_ptr(0x8000 + 2 * e['id'], used[b].alloc(ins.enc(txt) + b'\0'))
            if name == 'events': free_ev = used[banks[0]].free
        data = b''                                          # the ending (as insert.ending)
        assert ins.EV_BANK == EPI_SYMS['EVB']
        page2 = None
        for e in json.load(open('script/ff2/ending.json')):
            if not e['en'].strip():
                data += ins.enc(e['en']) + b'\0'; continue
            if e['id'] == 0:                            # GB (ff2_mock15): 20 columns, two
                W = EPI['w']                            #   pages of 11 rows, lines padded to
                lines = []                              #   the width (page 2 covers page 1)
                for line in e['en'].split('\n'):
                    lines += ins.balanced(line.strip(), W) if line.strip() else ['']
                while lines and not lines[-1]: lines.pop()
                cut = lines.index('', lines.index('') + 1)   # the second blank line
                p1, p2 = lines[:cut], lines[cut + 1:]          #   (after "Peace has returned ...")
                assert len(p1) <= 11 and len(p2) <= 10, (len(p1), len(p2))
                p2 = [''] * ((11 - len(p2)) // 2) + p2
                p2 += [''] * (11 - len(p2))
                pad = lambda l: (' ' * ((W - ins.vlen(l)) // 2) + l).ljust(W)
                data += ins.enc('\n'.join(pad(l) for l in p1)) + b'\0'
                page2 = ins.enc('\n'.join(pad(l) for l in p2)) + b'\0'
                continue
            lines = []
            for line in e['en'].split('\n'):
                for l in (ins.balanced(line.strip(), 24) if line.strip() else ['']):
                    lines.append(' ' * ((24 - ins.vlen(l)) // 2) + l if l else '')
            data += ins.enc('\n'.join(lines)) + b'\0'
        evb = ins.Bank(rom, ins.EV_BANK, free_ev)
        a = evb.alloc(data)
        put(rom, 14, 0xBAD2, bytes([a & 0xFF])); put(rom, 14, 0xBAD6, bytes([a >> 8]))
        a2 = evb.alloc(page2)
        put(rom, 24, EPI_SYMS['EP2'], a2.to_bytes(2, 'little'), old=b'\xFF\xFF')
        w = EPI                                         # the epilogue window (b14:BAAF)
        put(rom, 14, 0xBAB4, bytes([w['x']]), old=b'\x04')
        put(rom, 14, 0xBABD, bytes([w['y']]), old=b'\x04')
        put(rom, 14, 0xBAC6, bytes([w['w']]), old=b'\x18')
        put(rom, 14, 0xBACA, bytes([w['h']]), old=b'\x18')
        put(rom, 14, 0xBB2B, b'\x47', old=b'\x4A')      # credits 3 columns left ($2247)
        # field messages of the system table (bank 10 $8400) drawn in window 0: wrapped at
        # 18 too, into bank 10's space left after insert.py's names + system strings (its
        # allocations replayed on a scratch copy give the free list)
        scratch = bytearray(rom)
        b10 = ins.insert_names(scratch, [])
        ins.system_strings(scratch, [], b10)
        bank = ins.Bank(rom, 10, b10.free)
        keyword_menus(rom, ins, bank)
        for e in json.load(open('script/ff2/system.json')):
            if (e['id'] in SYS_FIELD or 43 <= e['id'] <= 62) and e['en']:
                t = '\n'.join(l.strip() for l in e['en'].split('\n'))
                t = gb_wrap(ins, t.replace('{02}', 'I' * 18)).replace('I' * 18, '{02}')   # item
                #   name counted as 18 (3 names are longer: 19-20, open point)
                bank.put_ptr(0x8400 + 2 * e['id'], bank.alloc(ins.enc(t) + b'\0'))
    finally:
        os.chdir(cwd)


def world_overview(rom):
    """world-map overview (B + Select with the ring, bank 9 $BA00; owner approved
    ff2_mock14): camera 6 / 9 (the globe NES y 80-207 centred, the logo above out of view),
    the field camera after. Stub in bank 9's stale data ($BE20, rom-map.txt)."""
    k = asm('''
    org $BE20
    lda #6
    sta $5800
    lda #9
    sta $5801
    jsr $BA00
    lda #FCX
    sta $5800
    lda #FCY
    sta $5801
    rts
''', syms=dict(FCX=FIELD_CAM['x'], FCY=FIELD_CAM['y']))
    assert k.org + len(k.bytes) <= 0xBE40
    put(rom, 9, k.org, k.bytes, old=bytes(len(k.bytes)))
    put(rom, 31, 0xC19F, bytes([0x20, 0x20, 0xBE]), old=bytes([0x20, 0x00, 0xBA]))

    row_menu(rom)


def row_menu(rom):
    """row menu (Select on the field, fix:F0E2; owner approved ff2_mock14): camera 6 / 5,
    portraits as background tiles (bank 24 gm_rowinit / gm_rowdraw), back row x $A0 (NES
    $A8: 4 columns right, on the 16 x 16 colour grid). Stubs in bank 14 $B845 (the load
    menu's old slot drawer, replaced by gm_slot)."""
    g = GBM[0]
    k = asm('''
    org $B845
rowin:
    lda #10
    jsr GBM
    jmp $DC30
rowdr:
    lda #11
    jmp GBM
rowex:
    lda #4
    jsr GBM
    lda #0
    sta $2001
    rts
epage:                  ; fix:F399 (ending: epilogue pages, bank 24 gm_epage)
    lda #12
    jmp GBM
''', syms=dict(GBM=g))
    assert k.org + len(k.bytes) <= 0xB87A
    put(rom, 14, k.org, k.bytes)
    L = k.labels
    put(rom, 31, 0xF110, bytes([0x20]) + L['rowin'].to_bytes(2, 'little'), old=bytes.fromhex('2030dc'))
    put(rom, 31, 0xF182, bytes([0x20]) + L['rowdr'].to_bytes(2, 'little'), old=bytes.fromhex('2012f2'))
    put(rom, 31, 0xF196, bytes([0x20]) + L['rowex'].to_bytes(2, 'little') + b'\xEA\xEA', old=bytes.fromhex('a9008d0120'))
    put(rom, 31, 0xF2B8, bytes([0x9F]), old=bytes([0xA7]))
    put(rom, 31, 0xF2BC, bytes([0xA0]), old=bytes([0xA8]))
    put(rom, 31, 0xF399, bytes([0x20]) + L['epage'].to_bytes(2, 'little'), old=bytes.fromhex('20b0f3'))


def field_tileset(rom):
    """GB-only register $580B when a normal map is (re)loaded: "init map" (fix:D09A, also run
    after a battle or menu) calls "load map palette" (b0:9C06) at fix:D0B4 once the tileset
    ($0500-$077F) and graphics are in; that call goes through a stub that writes $580B first.
    The world map's own call (fix:C864) is left alone (its tileset is not in RAM). The runtime
    fixes the DMG shading of the tileset's tiles at the next LCD-on (rt/ff2_banked.s
    tset_fix_b; docs/gb-native-presentation.md). Stub in bank 0's unused $83CA-$83FF."""
    k = asm('''
    org $83CA
tsetld:                 ; normal map (re)loaded: field camera, tileset to fix
    sta $580B
    pha
    lda #FCX
    sta $5800
    lda #FCY
    sta $5801
    pla
    jmp $9CC3
wmcam:                  ; b0:9C03 "init world map" (fix:C861): the field camera too (a loaded
    pha                 ;   game starts here from the load menu's camera)
    lda #FCX
    sta $5800
    lda #FCY
    sta $5801
    pla
    jmp $9CA5
''', syms=dict(FCX=FIELD_CAM['x'], FCY=FIELD_CAM['y']))
    assert k.org + len(k.bytes) <= 0x8400
    put(rom, 0, k.org, k.bytes, old=bytes(len(k.bytes)))
    put(rom, 31, 0xD0B4, bytes([0x20]) + k.labels['tsetld'].to_bytes(2, 'little'), old=bytes.fromhex('20069c'))
    put(rom, 0, 0x9C03, bytes([0x4C]) + k.labels['wmcam'].to_bytes(2, 'little'), old=bytes.fromhex('4ca59c'))


def apply(rom):
    battle(rom)
    dialogue(rom)
    world_overview(rom)
    field_tileset(rom)
    if os.environ.get('GB_END_TEST'):           # test builds only: Select on the field starts
        t = asm('    org $F0E2\n    jmp $F34D\n')       #   the ending (event $E7, fix:F34D)
        put(rom, 31, t.org, t.bytes)


if __name__ == '__main__':
    rom = bytearray(open(sys.argv[1], 'rb').read())
    apply(rom)
    open(sys.argv[2], 'wb').write(rom)
    import json
    with open(sys.argv[2] + '.ext.json', 'w') as fh: json.dump(NATIVE_EXT, fh, indent=1)
    print('wrote', sys.argv[2])
