; FF3's minimap (Sight, the Midgard Bread: 3A/88A3), bank B_MINI. Data from tools/gb3n/minimap.py
; (FF3's own screen set-up run at build time): $4000 the screen's tiles (VRAM bank 0 from tile 0),
; $4600 OBJ tiles (the marker, a town), $4700 / $4900 the 20 x 18 map / attributes (FF3's rows 3-5
; and 9-23, columns 6-25), $4A80 / $4AC0 rows 0-2 before the logo, $4B00 + 32 w BG palettes,
; $4C00 + 128 w the pixel colours (3A/8080 / 8100), $4E80 the marker's sprites.
; The picture: one pixel a world cell, 128 x 112 around the party (at 63, 56), the colour from bits
; 0-1 or 2-3 of the cell's byte in a checkerboard, bit 4 a town's sprite (3A/8A4E); drawn 8 rows at
; a time with FF3's noise (period 0 / 4 every 4 rows), into tiles 0-223 of VRAM bank 1; then the
; logo, the sprites, the song again; the marker flashes (3A/8984) and goes behind the picture while
; A or a direction is held (3A/891D); B returns.

MM_TILES   = $4000
MM_OBJT    = $4600
MM_MAP     = $4700
MM_ATTR    = $4900
MM_PRE     = $4A80
MM_PREA    = $4AC0
MM_PAL     = $4B00
MM_COL     = $4C00
MM_OAM     = $4E80
MM_BUF     = SCRATCH                ; (work RAM bank 1) a strip: 16 tiles
MM_ROW     = SCRATCH + $100         ; the row's 128 cells

section bank B_MINI, $6000
mm_show:    ld a, 4                         ; the song stopped (3A/88B0), FF3's noise on
            ld [M_CTRL], a
            call snd_frame
            ld a, $80
            ldh [$FF21], a
            ld a, [snd_ntab]
            ldh [$FF22], a
            ld a, $80
            ldh [$FF23], a
            call wait_vbl                   ; the screen (the LCD off in V-Blank)
            xor a
            ldh [rLCDC], a
            ld hl, MM_TILES                 ; tiles: the screen's (bank 0 from $9000), OBJ ($8000)
            ld de, $9000
            ld bc, $600
            call memcpy
            ld hl, MM_OBJT
            ld de, $8000
            ld bc, $20
            call memcpy
            ld a, 1                         ; the picture's tiles (bank 1: 0-127 at $9000,
            ldh [rVBK], a                   ;   128-223 at $8800) cleared
            ld hl, $8800
            ld de, $600
            call memclr
            ld hl, $9000
            ld de, $800
            call memclr
            ld hl, MM_ATTR                  ; attributes (bank 1), rows 0-2 FF3's first ones
            ld de, $9800
            call mm_rows
            xor a
            ldh [rVBK], a
            ld hl, MM_MAP
            ld de, $9800
            call mm_rows
            ld hl, MM_PRE
            ld de, $9800
            ld b, 3
            call mm_rowsb
            ld hl, oam_buf                  ; no sprites yet
            ld b, 160
            xor a
.oc:        ld [hl+], a
            dec b
            jr nz, .oc
            call hram_dma
            ld a, [world]                   ; BG palettes for the world
            cp 5
            jr c, .w
            ld a, 4
.w:         ld [mm_w], a
            swap a
            add a
            ld l, a
            ld h, high(MM_PAL)
            ld a, $80
            ldh [rBCPS], a
            ld b, 32
.p:         ld a, [hl+]
            ldh [rBCPD], a
            dec b
            jr nz, .p
            call mm_opal
            xor a
            ldh [rSCX], a
            ldh [rSCY], a
            ld a, LCDC_ON & $FD             ; (no sprites while it draws)
            ldh [rLCDC], a
            ld a, [pos_x]                   ; the corner: FF3's ($27 - $39 + 1, $28 - $31)
            sub 63
            ld [mm_x0], a
            ld a, [pos_y]
            sub 56
            ld [mm_y0], a
            xor a
            ld [mm_r], a
            ld a, 16
            ld [mm_n], a
.strip:     ld b, 8                         ; eight rows, then into VRAM
.rw:        push bc
            call mm_row
            ld a, [mm_r]                    ; (3A/88E8: the noise's period every 4 rows)
            and 4
            ld l, a
            ld h, high(snd_ntab)
            ld a, low(snd_ntab)
            add l
            ld l, a
            ld a, [hl]
            ldh [$FF22], a
            ld hl, mm_r
            inc [hl]
            pop bc
            dec b
            jr nz, .rw
            call wait_vbl
            ld a, 1
            ldh [rVBK], a
            ld a, [mm_r]                    ; strip k = r / 8 - 1: tiles 16 k (bank 1, $8800 mode:
            sub 8                           ;   $9000 + 256 k for k < 8, $8800 + 256 (k - 8))
            rrca
            rrca
            rrca
            and 15
            cp 8
            jr nc, .hi
            add $90
            jr .hs
.hi:        add $80
.hs:        ldh [rHDMA3], a
            xor a
            ldh [rHDMA4], a
            ld a, high(MM_BUF)
            ldh [rHDMA1], a
            xor a
            ldh [rHDMA2], a
            ld a, 15                        ; 256 bytes
            ldh [rHDMA5], a
            xor a
            ldh [rVBK], a
            ld b, 3                         ; (FF3's pace: about four frames a strip)
.wt:        push bc
            call wait_vbl
            pop bc
            dec b
            jr nz, .wt
            ld a, [mm_r]
            cp 112
            jp c, .strip
            xor a                           ; the noise off (3A/8900), the logo, the sprites
            ldh [$FF21], a
            call wait_vbl
            ld a, 1
            ld [guard_on], a
            ld a, $20
            ldh [rSTAT], a
            ld a, 1
            ldh [rVBK], a
            ld hl, MM_ATTR
            ld de, $9800
            ld b, 3
            call mm_rowsb
            xor a
            ldh [rVBK], a
            ld hl, MM_MAP
            ld de, $9800
            ld b, 3
            call mm_rowsb
            xor a
            ldh [rSTAT], a
            ld [guard_on], a
            ld hl, MM_OAM
            ld de, oam_buf
            ld bc, 16
            call memcpy
            ld a, 1                         ; the song again (3A/88C5)
            ld [M_CTRL], a
            ld a, LCDC_ON
            ldh [rLCDC], a
.lp:        call wait_vbl                   ; (3A/8947)
            call hram_dma
            call mm_opal
            ld hl, frame
            inc [hl]
            call snd_frame
            call read_pad
            ldh a, [pad]                    ; A or a direction held: the marker behind the
            and PAD_A | $F0                 ;   picture (3A/891D)
            ld b, 0
            jr z, .pr
            ld b, $80
.pr:        ld hl, oam_buf + 3
            ld c, 4
.pa:        ld a, [hl]
            and $7F
            or b
            ld [hl], a
            ld a, l
            add 4
            ld l, a
            dec c
            jr nz, .pa
            ldh a, [pad_new]
            and PAD_B
            jr z, .lp
            ret

; 18 rows of 20 from HL to DE (32 apart)
mm_rows:    ld b, 18
mm_rowsb:   ld c, 20
.c:         ld a, [hl+]
            ld [de], a
            inc de
            dec c
            jr nz, .c
            ld a, e
            add 12
            ld e, a
            jr nc, .n
            inc d
.n:         dec b
            jr nz, mm_rowsb
            ret

; OBJ palette 0 (3A/8984): colour 1 $0F / $37 every 8 frames, colour 2 $00 $10 $20 $0F every 16,
; colour 3 $0F (V-Blank)
mm_opal:    ld a, $80
            ldh [rOCPS], a
            xor a
            ldh [rOCPD], a
            ldh [rOCPD], a
            ld a, [frame]
            and 8
            ld a, $0F
            jr nz, .c1
            ld a, $37
.c1:        call .c
            ld a, [frame]
            and $30
            cp $30
            jr nz, .c2
            ld a, $0F
.c2:        call .c
            ld a, $0F
.c:         add a
            ld l, a
            ld h, high(I_RGB)
            ld a, low(I_RGB)
            add l
            ld l, a
            push hl
            ld a, B_MAPINFO
            call far_byte
            ldh [rOCPD], a
            pop hl
            inc hl
            ld a, B_MAPINFO
            call far_byte
            ldh [rOCPD], a
            ret

; picture row mm_r into the strip (3A/8A4E): the world's row, 128 cells from mm_x0
mm_row:     ld a, [world]                   ; (src/world.s: world map wi row y in bank
            and a                           ;   B_WORLD0 + 4 wi + y / 64 at $4000 + 256 (y & 63))
            jr z, .w
            dec a
.w:         add a
            add a
            ld c, a
            ld a, [mm_y0]
            ld hl, mm_r
            add [hl]
            ld b, a
            rlca
            rlca
            and 3
            add c
            add B_WORLD0
            ld [mm_bk], a
            ld a, b
            and 63
            add $40
            ld h, a
            ld a, [mm_x0]
            ld l, a
            cpl                             ; the cells to the row's end: 256 - x0
            inc a
            jr z, .one
            cp 128
            jr nc, .one
            ld c, a                         ; (wrapping: two copies)
            ld b, 0
            push hl
            push bc
            ld de, MM_ROW
            ld a, [mm_bk]
            call far_copy
            pop bc
            pop hl
            ld l, 0
            ld a, MM_ROW & $FF
            add c
            ld e, a
            ld d, high(MM_ROW)
            ld a, 128
            sub c
            ld c, a
            ld a, [mm_bk]
            call far_copy
            jr .px
.one:       ld de, MM_ROW
            ld bc, 128
            ld a, [mm_bk]
            call far_copy
.px:        ld a, [mm_r]                    ; the pixels: DE = the strip's row, C = the cell
            and 7
            add a
            ld e, a
            ld d, high(MM_BUF)
            ld c, 0
.tile:      ld b, 8                         ; 8 pixels into H (plane 0), L (plane 1)
.pix:       push hl
            push bc
            ld a, c
            add low(MM_ROW)
            ld l, a
            ld h, high(MM_ROW)
            ld a, [hl]
            and $7F
            ld l, a
            ld a, [mm_w]
            rra                             ; (128 a world: $C00 + 128 w)
            ld h, a
            ld a, 0
            rra
            add l
            ld l, a
            ld a, h
            adc high(MM_COL)
            ld h, a
            ld a, [hl]
            pop bc
            pop hl
            bit 4, a
            call nz, mm_town
            ld b, a
            ld a, [mm_r]
            add c
            rra
            ld a, b
            jr c, .lo2
            rra
            rra
.lo2:       rra
            rl h
            rra
            rl l
            inc c
            ld a, c
            and 7
            jr nz, .pix
            ld a, h
            ld [de], a
            inc e
            ld a, l
            ld [de], a
            ld a, e
            add 15
            ld e, a
            ld a, c
            cp 128
            jr c, .tile
            ret
; a town at cell C of row mm_r (3A/8AD2: tile 1, palette 0, NES (60 + c, 76 + r)); 36 at most
mm_town:    push af
            push hl
            ld a, [mm_n]
            cp 160
            jr nc, .x
            ld l, a
            add 4
            ld [mm_n], a
            ld h, high(oam_buf)
            ld a, [mm_r]
            add $4C - 48 + 16
            ld [hl+], a
            ld a, c
            add $3C - 48 + 8
            ld [hl+], a
            ld a, 1
            ld [hl+], a
            ld [hl], 0
.x:         pop hl
            pop af
            ret

section wram, $C0EB
mm_w:       ds 1
mm_x0:      ds 1
mm_y0:      ds 1
mm_r:       ds 1
mm_n:       ds 1
mm_bk:      ds 1
