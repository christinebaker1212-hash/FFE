; ---- sight.s (bank CODE11): the Sight spell's minimap (FF3 3A/88A3), from the Magic screen on a
; world map. 128 x 112 pixels, a pixel a world tile: columns px - 63 .. px + 64, rows py - 56 ..
; py + 55 (FF3: $27 - 56, $28 - 49; $27 = px - 7, $28 = py - 7). A tile's colour from FF3's table
; (3A/8080, 3A/8100 for metatiles 64-127 on worlds 2-4): even rows its bits 2-3, odd rows bits 0-1
; (FF3's dither); bit 4: a town, a dot sprite on it. The party: four corner sprites around its
; pixel. Colours 3A/8050 / 8060; the sprites' colours 1 / 2 flash (3A/8947); while A or the
; Control Pad is held the sprites go behind the map (3A/891D); B returns. Our frame: a window
; with the title, the map at cells 2-17, rows 3-16 (tiles: 173 at $53-$FF, 51 at $00-$32 of VRAM
; bank 1; the sprites' tiles $33 / $34). The bitmap is built in WRAM 5 (free outside battles).
SG_BMP     = $D000              ; WRAM 5: 224 tiles
SG_CT      = $DE00              ; WRAM 5: colour by metatile, even rows ($DE00) / odd rows ($DE80)
SG_ROW     = $DF00              ; WRAM 5: a world row (256)

wm_sight:   call u_hoff
            call oam_hide
            ld a, [cur_world]               ; the world's tables: k = w >> 1
            srl a
            ld [sg_k], a
            ld a, [cur_world]               ; its tilemap's first bank (WLD_BANK $7000 + 64 w)
            rrca
            rrca
            ld l, a
            and $3F
            ld h, a
            ld a, l
            and $C0
            ld l, a
            ld a, h
            add a, $70
            ld h, a
            ld a, WLD_BANK
            call rd_byte
            ld [sg_wb], a
            ld a, 5
            ldh [rSVBK], a
            call sg_tabs
            call sg_draw
            ld a, 2
            ldh [rSVBK], a
            call u_cls                      ; the window, the title, the map's cells
            ld bc, $0100
            ld de, $1212
            call u_box
            ld a, UP_LABEL
            ld [u_pal], a
            ld bc, $0201
            ld d, 16
            ld hl, U_WORLD
            call u_textc
            ld a, $0F                       ; (palette 7, VRAM bank 1)
            ld [u_at], a
            ld c, 3
            ld e, 0
.r:         ld b, 2
.c:         ld a, e
            cp 173
            jr c, .t
            sub 173
            jr .p
.t:         add a, $53
.p:         call u_cellt
            inc e
            inc b
            ld a, b
            cp 18
            jr nz, .c
            inc c
            ld a, c
            cp 17
            jr nz, .r
            call sg_up                      ; the bitmap and the sprites' tiles -> VRAM bank 1
            call u_flush
            ld hl, SG_PAL                   ; the map's colours -> BG 7; the sprites' OBJ 4
            ld a, [sg_k]
            add a, a
            add a, a
            add a, a
            ld e, a
            ld d, 0
            add hl, de
            ld a, 2
            ldh [rSVBK], a
            ld de, u_palt + 7 * 8
            ld bc, 8
            ld a, CODE12                    ; (SG_PAL, SG_COL: bank CODE12)
            call rd_copy
            ld hl, SG_FL
            ld de, u_palt + 64 + 4 * 8
            ld bc, 8
            call memcpy
            call sg_oam
            xor a
            ld [sg_f], a
            call u_fadein
.l:         call wait_vbl
            call u_keys
            ld a, [m_new]
            bit 1, a
            jr nz, .x
            call sg_flash
            ldh a, [pad]                    ; A or the Control Pad held: behind the map
            and $F1
            ld b, 0
            jr z, .pr
            ld b, $80
.pr:        ld hl, oam_buf + 3
            ld c, 40
.o:         ld a, [hl]
            and $7F
            or b
            ld [hl+], a
            inc hl
            inc hl
            inc hl
            dec c
            jr nz, .o
            jr .l
.x:         ld a, $85
            ld [S49], a
            call u_fadeout
            jp oam_hide

; the colour tables: SG_COL + 128 k (by metatile) -> SG_CT even rows (bits 2-3 -> 0-1, bit 4) and
; odd rows (bits 0-1, bit 4)
sg_tabs:    ld a, [sg_k]
            ld h, a
            ld l, 0
            srl h
            rr l
            ld de, SG_COL
            add hl, de
            ld de, SG_ROW                   ; (from CODE12 into the row buffer first)
            ld bc, 128
            ld a, CODE12
            call rd_copy
            ld hl, SG_ROW
            ld de, SG_CT
.l:         ld a, [hl+]
            ld c, a
            rrca
            rrca
            and 3
            ld b, a
            ld a, c
            and $10
            or b
            ld [de], a                      ; even
            set 7, e
            ld a, c
            and $13
            ld [de], a                      ; odd
            res 7, e
            inc e
            ld a, e
            cp 128
            jr nz, .l
            ret

; the bitmap: 112 rows of 128 pixels (16 tiles a row band, 2bpp); towns recorded as sprites
sg_draw:    ld hl, SG_BMP
            ld de, 224 * 16
            call memclr
            xor a
            ld [sg_n], a
            ld [sg_r], a
.row:       ld a, [py]                      ; the world row py - 56 + r
            sub 56
            ld b, a
            ld a, [sg_r]
            add a, b
            ld b, a                         ; (its bank: + y / 64; its address $4000 + 256 (y & 63))
            and $3F
            add a, $40
            ld h, a
            ld l, 0
            ld a, b
            rlca
            rlca
            and 3
            ld b, a
            ld a, [sg_wb]
            add a, b
            ld de, SG_ROW
            ld bc, 256
            call rd_copy
            ld a, [sg_r]                    ; the colour table of the row's parity
            and 1
            rrca
            ld [sg_par], a                  ; (0 or $80)
            ld a, [sg_r]                    ; the bitmap's row: tile band r / 8, line r & 7
            and $F8
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl                      ; 256 (r / 8)
            ld a, [sg_r]
            and 7
            add a, a
            add a, l
            ld l, a
            ld de, SG_BMP
            add hl, de
            ld a, l
            ld [sg_out], a
            ld a, h
            ld [sg_out + 1], a
            ld a, [px]                      ; the first column px - 63
            sub 63
            ld e, a
            ld d, high(SG_ROW)
            xor a
            ld [sg_c], a
.tile:      ld bc, 0                        ; 8 pixels: B low plane, C high plane
            ld a, 8
            ld [sg_t], a
.px:        ld a, [de]
            inc e
            and $7F
            ld l, a
            ld a, [sg_par]
            or l
            ld l, a
            ld h, high(SG_CT)
            ld a, [hl]
            rra
            rl b
            rra
            rl c
            bit 2, a                        ; (bit 4, shifted twice: a town)
            call nz, sg_town
            ld hl, sg_c
            inc [hl]
            ld hl, sg_t
            dec [hl]
            jr nz, .px
            ld a, [sg_out]                  ; the two bytes, then the next tile (+16)
            ld l, a
            ld a, [sg_out + 1]
            ld h, a
            ld a, b
            ld [hl+], a
            ld a, c
            ld [hl], a
            ld a, [sg_out]
            add a, 16
            ld [sg_out], a
            jr nc, .nc
            ld hl, sg_out + 1
            inc [hl]
.nc:        ld a, [sg_c]
            cp 128
            jr nz, .tile
            ld hl, sg_r
            inc [hl]
            ld a, [hl]
            cp 112
            jp nz, .row
            ret
; a town at pixel (sg_c, sg_r): a dot sprite (FF3: 8 x 8 centred), up to 36
sg_town:    push bc
            push de
            ld a, [sg_n]
            cp 36
            jr nc, .x
            inc a
            ld [sg_n], a
            dec a
            add a, a
            add a, a
            ld l, a
            ld h, high(oam_buf)
            ld a, [sg_r]                    ; y = 16 + 24 + r - 4
            add a, 36
            ld [hl+], a
            ld a, [sg_c]                    ; x = 8 + 16 + c - 4
            add a, 20
            ld [hl+], a
            ld a, $33
            ld [hl+], a
            ld a, 4 | 8
            ld [hl], a
.x:         pop de
            pop bc
            ret
; the party's four corners (3A/8040: around its pixel 63, 56)
sg_oam:     ld hl, oam_buf + 4 * 36
            ld de, SG_CORN
            ld b, 16
.l:         ld a, [de]
            ld [hl+], a
            inc de
            dec b
            jr nz, .l
            ret
SG_CORN:    db 16 + 24 + 48, 8 + 16 + 55, $34, 4 | 8 | $20
            db 16 + 24 + 48, 8 + 16 + 65, $34, 4 | 8
            db 16 + 24 + 57, 8 + 16 + 55, $34, 4 | 8 | $60
            db 16 + 24 + 57, 8 + 16 + 65, $34, 4 | 8 | $40

; the sprites' colours 1 / 2 (3A/8986): 1 black / light orange every 8 frames; 2 black, grey,
; light grey, white by frame / 16
sg_flash:   ld hl, sg_f
            inc [hl]
            ld a, [hl]
            ld c, a
            and 8
            ld hl, SG_FL + 8                ; (black)
            jr nz, .c1
            ld hl, SG_FL + 10               ; ($37)
.c1:        ld a, [hl+]
            ld [pal_sh + 64 + 4 * 8 + 2], a
            ld a, [hl]
            ld [pal_sh + 64 + 4 * 8 + 3], a
            ld a, c
            and $30
            swap a                          ; 0-3: $00, $10, $20, black
            add a, a
            add a, low(SG_FL + 12)
            ld l, a
            ld a, high(SG_FL + 12)
            adc a, 0
            ld h, a
            ld a, [hl+]
            ld [pal_sh + 64 + 4 * 8 + 4], a
            ld a, [hl]
            ld [pal_sh + 64 + 4 * 8 + 5], a
            ld a, 1
            ldh [pal_dirty], a
            ret

; the bitmap (WRAM 5) and the two sprite tiles -> VRAM bank 1, 16 tiles a V-Blank by DMA
sg_up:      ld de, $8000 + 16 * $53
            ld hl, SG_BMP
            ld b, 173
            call .run
            ld de, $8000
            ld hl, SG_BMP + 173 * 16
            ld b, 51
            call .run
            ld a, CODE11
            ld [vc_src], a
            ld hl, SG_SPR
            ld de, $8000 + 16 * $33
            ld b, 2
            ld a, 1
            jp vcopyx
.run:       ld a, b
            cp 16
            jr c, .n
            ld a, 16
.n:         ld c, a
            push bc
            push hl
            push de
            call wait_vbl
            pop de
            pop hl
            ld a, h
            ldh [rHDMA1], a
            ld a, l
            ldh [rHDMA2], a
            ld a, d
            ldh [rHDMA3], a
            ld a, e
            ldh [rHDMA4], a
            ld a, 5
            ldh [rSVBK], a
            ld a, 1
            ldh [rVBK], a
            ld a, c
            dec a
            ldh [rHDMA5], a
            xor a
            ldh [rVBK], a
            ld a, 2
            ldh [rSVBK], a
            ld a, c                         ; on: + 16 c
            swap a
            ld b, a
            and $F0
            ld c, a
            ld a, b
            and $0F
            ld b, a
            add hl, bc
            ld a, e
            add a, c
            ld e, a
            ld a, d
            adc a, b
            ld d, a
            pop bc
            ld a, b
            sub c
            ld b, a
            jr nz, .run
            ret

section wram, $C6B0                         ; (shares the Status screen's bytes: sts.s)
sg_k:       ds 1
sg_wb:      ds 1
sg_n:       ds 1
sg_r:       ds 1
sg_c:       ds 1
sg_t:       ds 1
sg_par:     ds 1
sg_out:     ds 2
sg_f:       ds 1
