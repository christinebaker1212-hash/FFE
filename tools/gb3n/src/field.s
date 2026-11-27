; FF3 normal maps on the Game Boy Color: a map drawn into the BG ring, the party walking on it.
; Written from FF3's field code as the listing describes it ($3E $CDA3 init player movement,
; $3F $E5EB update player movement, $3E $C65D check destination tile, $3E $D8D3 player sprite).
;
; A map's data bank (made by tools/gb3n/build.py from the user's ROM):
;   $4000 the 256 BG tiles (Game Boy format)       $5000 metatile corner tiles UL, UR, DL, DR
;   $5200 metatile palette (CGB attribute byte)     $5300 the four BG palettes (RGB555)
;   $5400 the 32 x 32 metatile map (decompressed)   $5800 start x, y; $5802 fill metatile;
;   $5880 tile properties 1, $5900 2 (128 each)
;   $5A00 the walking character's 16 tiles          $5B00 its two sprite palettes (RGB555)
;   $5B10 FF3's player sprite poses (64: 4 directions x 2 frames x 4 tiles + attributes)

M_TILES    = $4000
M_QUAD     = $5000
M_ATTR     = $5200
M_PALS     = $5300
M_MAP      = $5400
M_START    = $5800
M_FILL     = $5802
M_PROP1    = $5880
M_PROP2    = $5900
M_PCHR     = $5A00
M_PPAL     = $5B00
M_POSE     = $5B10
VIEW_X     = 4              ; the party's metatile column / row on screen (10 x 9 visible)
VIEW_Y     = 4
DIR_R      = 1              ; facing (FF3's ----udlr)
DIR_L      = 2
DIR_D      = 4
DIR_U      = 8

section bank 0, $2800
; ---- start on map bank A: draw it whole (LCD off), the party at its start position
map_enter:  ld [map_bank], a
            ld [MBC5_BANKL], a
            ld a, $80                       ; BG palettes 0-3
            ldh [rBCPS], a
            ld hl, M_PALS
            ld b, 32
.pl:        ld a, [hl+]
            ldh [rBCPD], a
            dec b
            jr nz, .pl
            ld a, $80                       ; OBJ palettes 0-1: the walking character
            ldh [rOCPS], a
            ld hl, M_PPAL
            ld b, 16
.po:        ld a, [hl+]
            ldh [rOCPD], a
            dec b
            jr nz, .po
            xor a
            ldh [rVBK], a
            ld hl, M_TILES                  ; BG tiles at $8000 (tiles 0-255)
            ld de, $8000
            ld bc, $1000
            call memcpy
            ld a, 1                         ; the walking character's tiles: VRAM bank 1 $8000
            ldh [rVBK], a                   ;   (sprite tiles 0-15, bank 1)
            ld hl, M_PCHR
            ld de, $8000
            ld bc, $100
            call memcpy
            xor a
            ldh [rVBK], a
            ld a, [M_START]
            ld [pos_x], a
            ld a, [M_START + 1]
            ld [pos_y], a
            ld a, DIR_D
            ld [facing], a
            xor a
            ld [step], a
            ld [line_n], a
            call cam_set
            ld c, 0                         ; the 16 rows of the ring, a row at a time
.row:       push bc
            ld a, [cam_y]
            add c
            ld e, a
            ld a, [cam_x]
            ld d, a
            call line_row
            call line_flush
            pop bc
            inc c
            ld a, c
            cp 16
            jr nz, .row
            call scroll_set
            call party_oam
            ret

; ---- one field frame (after the frame wait): V-Blank work, then the walking
field_vbl:  ld a, [line_n]                  ; a pending row / column into the ring
            and a
            call nz, line_flush
            call scroll_set
            jp hram_dma

field_step: ld a, [step]
            and a
            jr nz, .walk
            ldh a, [pad]                    ; a direction held: FF3's order right, left, down, up
            ld b, DIR_R
            bit 4, a
            jr nz, .dir
            ld b, DIR_L
            bit 5, a
            jr nz, .dir
            ld b, DIR_D
            bit 7, a
            jr nz, .dir
            ld b, DIR_U
            bit 6, a
            jr z, .done
.dir:       ld a, b
            ld [facing], a
            call dest_cell                  ; D, E = the metatile ahead
            call map_mt
            call passable
            jr c, .done
            call edge_line                  ; the row / column coming into view
            ld a, 1
            ld [step], a
            jr .done
.walk:      inc a                           ; a pixel a frame, 16 to a step
            ld [step], a
            cp 17
            jr nz, .done
            xor a
            ld [step], a
            call dest_cell
            ld a, d
            ld [pos_x], a
            ld a, e
            ld [pos_y], a
            call cam_set
.done:      jp party_oam

; can the party step onto metatile A? carry set if not ($3F $E396 check tile passability):
; property 1 bit 7 a trigger tile (passable; exits / events: next step), the low three bits
; 0 stairs (both levels, z cleared), 4+ a bridge, 3 impassable, 1 / 2 a level: impassable
; when it and the current level z make 3, else z becomes it
passable:   ld c, a
            ld b, high(M_PROP1)
            ld a, [bc]
            bit 7, a
            jr nz, .ok
            and 7
            jr z, .st
            cp 4
            jr nc, .ok
            cp 3
            jr z, .no
            ld b, a
            ld a, [z_lev]
            or b
            cp 3
            jr z, .no
            ld [z_lev], a
.ok:        and a
            ret
.st:        xor a
            ld [z_lev], a
            ret
.no:        scf
            ret

; D, E = the cell ahead of the party (coordinates wrap at 64, as FF3's AND $3F)
dest_cell:  ld a, [pos_x]
            ld d, a
            ld a, [pos_y]
            ld e, a
            ld a, [facing]
            rra
            jr c, .r
            rra
            jr c, .l
            rra
            jr c, .d
            dec e
            jr .m
.r:         inc d
            jr .m
.l:         dec d
            jr .m
.d:         inc e
.m:         ld a, d
            and 63
            ld d, a
            ld a, e
            and 63
            ld e, a
            ret

cam_set:    ld a, [pos_x]
            sub VIEW_X
            ld [cam_x], a
            ld a, [pos_y]
            sub VIEW_Y
            ld [cam_y], a
            ret

; SCX / SCY: the camera's ring position plus the step's pixels in the facing direction
scroll_set: ld a, [step]
            and a
            jr z, .s0
            dec a
.s0:        ld b, a                         ; B = pixels walked (0-15)
            ld a, [cam_x]
            swap a
            and $F0
            ld c, a
            ld a, [cam_y]
            swap a
            and $F0
            ld d, a
            ld a, [facing]
            rra
            jr c, .r
            rra
            jr c, .l
            rra
            jr c, .d
            ld a, d                         ; up
            sub b
            ld d, a
            jr .w
.r:         ld a, c
            add b
            ld c, a
            jr .w
.l:         ld a, c
            sub b
            ld c, a
            jr .w
.d:         ld a, d
            add b
            ld d, a
.w:         ld a, c
            ldh [rSCX], a
            ld a, d
            ldh [rSCY], a
            ret

; queue the row / column entering the view for the step just started
edge_line:  ld a, [cam_x]
            ld d, a
            ld a, [cam_y]
            ld e, a
            ld a, [facing]
            rra
            jr c, .r
            rra
            jr c, .l
            rra
            jr c, .d
            dec e                           ; up: the row above
            jp line_row
.d:         ld a, e
            add 9
            ld e, a
            jp line_row
.r:         ld a, d
            add 10
            ld d, a
            jp line_col
.l:         dec d
            jp line_col

; build the 16 cells of the row at map y = E from x = D (line_row) or the column at x = D from
; y = E (line_col) into line_buf: per cell its BG map address, 4 tiles and the palette
line_row:   ld a, 1
            jr line_go
line_col:   xor a
line_go:    ld [line_dir], a
            ld hl, line_buf
            ld b, 16
.c:         push bc
            push de
            push hl
            call map_mt
            pop hl
            pop de
            push de
            call cell_buf
            pop de
            ld a, [line_dir]
            and a
            jr z, .y
            inc d
            jr .n
.y:         inc e
.n:         pop bc
            dec b
            jr nz, .c
            ld a, 16
            ld [line_n], a
            ret

; A = the metatile at map (D, E) (0-63; outside the 32 x 32 map: the fill metatile)
map_mt:     ld a, d
            or e
            and $20
            jr z, .in
            ld a, [M_FILL]
            ret
.in:        ld a, e
            and 31
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld a, d
            and 31
            add l
            ld l, a
            ld a, h
            adc high(M_MAP)
            ld h, a
            ld a, [hl]
            and $7F
            ret

; metatile A at map (D, E) -> 7 bytes at HL: BG map address (lo, hi), UL, UR, DL, DR, palette
cell_buf:   and $7F
            ld c, a
            push hl
            ld a, e                         ; $9800 + 64 * (y & 15) + 2 * (x & 15)
            and 15
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld a, d
            and 15
            add a
            add l
            ld e, a
            ld a, h
            adc $98
            ld d, a
            pop hl
            ld a, e
            ld [hl+], a
            ld a, d
            ld [hl+], a
            ld b, high(M_QUAD)
            ld a, [bc]
            ld [hl+], a
            ld a, c
            add $80
            ld c, a
            ld a, [bc]
            ld [hl+], a
            inc b
            ld a, c
            sub $80
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, c
            add $80
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, c
            sub $80
            ld c, a
            ld b, high(M_ATTR)
            ld a, [bc]
            ld [hl+], a
            ret

; write line_buf's cells into the BG map (in V-Blank or with the LCD off)
line_flush: ld hl, line_buf
            ld a, [line_n]
            ld b, a
.c:         ld a, [hl+]
            ld e, a
            ld a, [hl+]
            ld d, a
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            ld a, e
            add 31
            ld e, a
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            ld a, [hl+]                     ; the palette, VRAM bank 1
            ld c, a
            ld a, 1
            ldh [rVBK], a
            ld a, c
            ld [de], a
            dec e
            ld [de], a
            ld a, e
            sub 32
            ld e, a
            ld a, c
            ld [de], a
            inc e
            ld [de], a
            xor a
            ldh [rVBK], a
            dec b
            jr nz, .c
            xor a
            ld [line_n], a
            ret

; the walking character into OAM entries 0-3 (FF3: x $70 on the NES; here the party's cell)
party_oam:  ld a, [step]                    ; the pose: facing, and the second frame from
            and a                           ;   pixel 8 of a step (FF3: fine scroll & 8)
            jr z, .f0
            dec a
.f0:        and 8
            ld b, a
            ld a, [facing]
            ld c, $00
            rra
            jr c, .p
            ld c, $10
            rra
            jr c, .p
            ld c, $30
            rra
            jr c, .p
            ld c, $20
.p:         ld a, c
            or b
            add low(M_POSE)
            ld l, a
            ld a, high(M_POSE)
            adc 0
            ld h, a
            ld d, VIEW_X * 16 + 8           ; D = x, E = y (OAM: +8 / +16)
            ld e, VIEW_Y * 16 + 16
            ld a, b                         ; FF3: the second frame bobs a pixel (up, or left
            and a                           ;   while walking up / down)
            jr z, .nb
            ld a, [facing]
            and DIR_U | DIR_D
            jr z, .bu
            dec d
            jr .nb
.bu:        dec e
.nb:        ld bc, oam_buf
            call .spr                       ; UL
            ld a, e
            add 8
            ld e, a
            call .spr                       ; DL
            ld a, e
            sub 8
            ld e, a
            ld a, d
            add 8
            ld d, a
            call .spr                       ; UR
            ld a, e
            add 8
            ld e, a
            jp .spr                         ; DR
.spr:       ld a, e                         ; one 8 x 8 part: y, x, tile, attributes
            ld [bc], a
            inc c
            ld a, d
            ld [bc], a
            inc c
            ld a, [hl+]
            ld [bc], a
            inc c
            ld a, [hl+]                     ; NES attributes -> Color: palette (bits 0-1),
            push af                         ;   flip H ($40 -> $20), behind BG ($20 -> $80),
            and 3                           ;   tiles in VRAM bank 1
            or $08
            ld [tmp], a
            pop af
            push af
            and $40
            rra
            push hl
            ld hl, tmp
            or [hl]
            ld [hl], a
            pop hl
            pop af
            and $20
            add a
            add a
            push hl
            ld hl, tmp
            or [hl]
            pop hl
            ld [bc], a
            inc c
            ret

dma_rom:    ld a, high(oam_buf)
            ldh [rDMA], a
            ld a, 40
.w:         dec a
            jr nz, .w
            ret
dma_end:

section wram, $C000
oam_buf:    ds 160
section wram, $C100
map_bank:   ds 1
pos_x:      ds 1
pos_y:      ds 1
cam_x:      ds 1
cam_y:      ds 1
facing:     ds 1
step:       ds 1                            ; 0 standing, 1-16 walking (pixels + 1)
line_n:     ds 1                            ; cells pending in line_buf
line_dir:   ds 1
tmp:        ds 1
z_lev:      ds 1                            ; FF3's $A5: the z-level walked on (0 both)
line_buf:   ds 7 * 16
