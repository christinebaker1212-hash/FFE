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
fieldcam:               ; fix:FA0F (return from battle; LDA #$0E / JSR $FE1A): field camera
    lda #6
    sta $5800
    sta $5801
    lda #0
    sta $5802
    sta $5803
    lda $FD             ; the field's $2000 (BG table 0) before the field reloads its tiles
    sta $2000           ;   (fix:E512; the GB sends a tile to BG or sprites by $2000 bit 4)
    lda #$0E
    jmp $FE1A
end:
'''


# Battle RAM (free in battle, see the module docstring)
RAM = dict(GBIDX=0x7FDF, GBRB=0x7FE0, GBPOOL=0x7FE1, VX=0x7FE2, VN=0x7FE3, VT=0x7FE4, VC=0x7FE5,
           VSH=0x7FE6, VCNT=0x7FE7, VP=0xD2, VQ=0xD4, VS=0xD6, VNUM=0x7FEC, VPAD=0x7FEE, VDIG=0x7FEF,
           VROW=0x7FF0, VCOL=0x7FF1, VW=0x7FF2, VH=0x7FF3, VLINE=0x7FF4, VSV=0x7FF5, VI=0x7FF6,
           NL=0x7FF7, NS=0x7FF8, VSQZ=0x7FF9, VI0=0x7FFA, VI1=0x7FFB, VCX=0x7FFC, VFILL=0x7FFD, VLN=0x7FFE,
           USED=0x75C0, VBUF=0x7800, BLANKT=0x7888, FTILE=0x7889, PTILE=0x7891, LTILE=0x78B9, XTILE=0x78D1,
           NTBUF=0x78D5, ATKBUF=0x75E0, MOPEN=0x75F0, MLINE=0x75F1, MPAGE=0x75F2,
           LSHOW=0x75C0, LNAV=0x75DC, LBASE=0x75DD, LDGAP=0x7FE8, LCOV=0x7FFF,
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
    inc VC
    dec VCNT
    bne .tile
    jsr scroll
    jmp .frame
.end:
    jmp scroll
scroll:
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
tileaddr:               ; A = table-1 tile: PPU address of its pattern
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


def battle(rom):
    c = CAM_BATTLE
    assert c['x2'] == 0
    f = asm(FIX_SRC, syms=dict(RAM, CX=c['x'], CF=c['fine'], CY=c['y'], CX2=c['x2'], CY2=c['y2'], CL=c['line']))
    assert f.org + len(f.bytes) <= 0xF850
    put(rom, 31, f.org, f.bytes)
    put(rom, 31, 0xFAB9, bytes([0x4C]) + f.labels['btlcam'].to_bytes(2, 'little'), old=bytes.fromhex('4c3996'))
    put(rom, 31, 0xFA0F, bytes([0x20]) + f.labels['fieldcam'].to_bytes(2, 'little') + b'\xEA\xEA',
        old=bytes.fromhex('a90e201afe'))
    # party: y = slot * 24 + 48 (NES: * 27 + 44), base x 156 front / 160 back (NES 208 / 224):
    # GB x 140 / 144, every member in a 24-px slot of the 96-px battlefield
    put(rom, 11, 0x9B68, bytes([0xA2, 24]), old=bytes([0xA2, 0x1B]))
    put(rom, 11, 0x9B6F, bytes([0x69, 48]), old=bytes([0x69, 0x2C]))
    put(rom, 11, 0xA102, bytes([0xA9, 156]), old=bytes([0xA9, 0xD0]))
    put(rom, 11, 0xA109, bytes([0xA9, 160]), old=bytes([0xA9, 0xE0]))
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
    labels = {}
    for org, end, ks in ((0xFFD0, 0xFFFA, range(0, 8)), (0xFEEC, 0xFF00, range(8, 12))):   # (free:
        ent = 'org $%04X\n' % org                                                          #  rom info,
        for k in ks:                                                                        #  zeros)
            if k < len(ENTRIES): ent += 'e%d:\n    ldx #%d\n    jmp gbf\n' % (k, k)
        e = asm(ent, syms=dict(gbf=f.labels['gbf']))
        assert e.org + len(e.bytes) <= end
        put(rom, 31, e.org, e.bytes); labels.update(e.labels)
    assert len(ENTRIES) <= 12
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


def apply(rom):
    battle(rom)


if __name__ == '__main__':
    rom = bytearray(open(sys.argv[1], 'rb').read())
    apply(rom)
    open(sys.argv[2], 'wb').write(rom)
    print('wrote', sys.argv[2])
