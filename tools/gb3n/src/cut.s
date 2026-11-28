; ---- the cutscenes (FF3 bank 1F, entered from event commands $DB / $DC / $DD): the crystal
; prologue (1F/A326), the epilogue (1F/B146), the ending (1F/B5B6) and the end credits (1F/B94A).
; Bank CODE5: this code at $4000, NES bank 1F at $6000 (FF3's tables at NES address - $4000);
; the graphics (converted at build time, cut.py) in bank CUTD. The scenes keep FF3's timing (its
; frame counts, fades every 8 frames, 112-frame fade-ins) and its data; the picture is laid out
; for the GB view (the camera cs_cx / cs_cy over FF3's 256 x 240 screen, text pages re-laid out
; by cut.py). FF3's sprite list (64 entries as FF3 keeps them: y, tile, attributes, x) is turned
; into the GB OAM every frame (camera, culling, the attributes); its palettes (32 NES colours as
; FF3 keeps them at $7CF7, with FF3's fades) into the CGB palettes.
; RAM: WRAM bank 4 while a scene runs.
N1F        = -$4000             ; NES bank 1F address + N1F = the copy in this bank
CS_OAM     = $D000              ; FF3's sprite list ($0200, 256 bytes)
CS_ROWS    = $D100              ; a page's rows (32 cells each), the DMA source

; the scene's camera B = x, C = y; the LCD off, VRAM / sprites / palettes cleared
cs_init:    push bc
            call pal_black
            call wait_vbl
            call lcd_off
            xor a
            ld [lcd_is], a
            ld a, 4
            ldh [rSVBK], a
            pop bc
            ld a, b
            ld [cs_cx], a
            ld a, c
            ld [cs_cy], a
            ld a, 1
            ldh [rVBK], a
            ld hl, $8000
            ld de, $2000
            call memclr
            xor a
            ldh [rVBK], a
            ld hl, $8000
            ld de, $2000
            call memclr
            call cs_oclr
            ld hl, oam_buf
            ld de, 160
            call memclr
            ld hl, cs_pal
            ld b, 32
            ld a, $0F
.p:         ld [hl+], a
            dec b
            jr nz, .p
            xor a
            ld [cs_cc], a
            ld [cs_b6], a
            ld [cs_b7], a
            ld [cs_slow], a
            call cs_palc
            ld a, [cs_cx]
            ldh [scx], a
            ldh [rSCX], a
            ld a, [cs_cy]
            ldh [scy], a
            ldh [rSCY], a
            ret
; FF969 copies 4 tiles a frame while the screen is on: the frames beyond the DMA's one for A
cs_tw:      ld b, a
            ld a, [lcd_is]
            and a
            ret z
            ld a, b
            add a, 3
            rrca
            rrca
            and $3F
            dec a
            ret z
            ld b, a
            jp cs_wait
; 1F/A0AD screen on
cs_on:      ld a, LCDC_ON
            ldh [rLCDC], a
            ld a, 1
            ld [lcd_is], a
            ret
; the scene's end: the screen black (on: the map is loaded behind it), the field's WRAM bank
cs_end:     xor a
            ld [cs_slow], a
            call pal_black
            xor a
            ldh [scx], a
            ldh [scy], a
            ld hl, oam_buf
            ld de, 160
            call memclr
            ld a, 1
            ldh [rSVBK], a
            ret

; 1F/A1D1 clear the sprite list
cs_oclr:    ld hl, CS_OAM
            ld a, $F0
.c:         ld [hl+], a
            inc l
            dec l
            jr nz, .c
            ret

; 1F/A063 cutscene graphics A: from the directory in CUTD (LCD off: copied, on: by DMA)
cs_gfx:     add a, a
            add a, a
            add a, a
            ld l, a
            ld h, $40
            ld de, cs_tmp
            ld bc, 8
            ld a, CUTD
            call rd_copy
            ld a, [cs_tmp + 6]
            and a
            jr nz, .nt
            ld a, CUTD
            ld [vc_src], a
            ld hl, cs_tmp
            ld a, [hl+]
            ld e, a
            ld a, [hl+]
            ld d, a
            ld a, [hl+]
            push af
            ld a, [hl+]
            ld c, a
            ld a, [hl+]
            ld b, a
            ld a, [hl]
            ld h, d
            ld l, e
            ld d, b
            ld e, c
            ld b, a
            pop af
            push bc
            call vcopyx
            pop bc
            ld a, b
            jp cs_tw
.nt:        ld hl, cs_tmp                   ; a nametable (LCD off): tiles, then attributes
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            push hl
            ld de, $9800
            ld bc, 960
            ld a, CUTD
            call rd_copy
            pop hl
            ld bc, 960
            add hl, bc
            ld a, 1
            ldh [rVBK], a
            ld de, $9800
            ld a, CUTD
            call rd_copy
            xor a
            ldh [rVBK], a
            ret

; 1F/B340 palette set A: 8 palettes, each 4 colours from 1F/B284 + 4 (1F/B300 + 8 set + n)
cs_palset:  add a, a
            add a, a
            add a, a
            add a, low($B300 + N1F)
            ld e, a
            ld a, high($B300 + N1F)
            adc a, 0
            ld d, a
            ld hl, cs_pal
            ld b, 8
.p:         ld a, [de]
            inc de
            push de
            push bc
            add a, a
            add a, a
            add a, low($B284 + N1F)
            ld e, a
            ld a, high($B284 + N1F)
            adc a, 0
            ld d, a
            ld c, 4
.c:         ld a, [de]
            inc de
            ld [hl+], a
            dec c
            jr nz, .c
            pop bc
            pop de
            dec b
            jr nz, .p
            ret

; FF3's palettes -> the CGB ones (BG colour 0: the backdrop, $3F10's mirror; sprite colours as
; FF3's), shown at the next V-Blank
cs_palc:    ld de, pal_sh
            ld c, 0                         ; BG palettes 0-3
.bg:        ld a, [cs_pal + 16]
            call .col
            ld a, c
            add a, a
            add a, a
            inc a
            ld l, a
            ld h, 0
            push bc
            ld bc, cs_pal
            add hl, bc
            pop bc
            ld b, 3
.b3:        ld a, [hl+]
            push hl
            call .col
            pop hl
            dec b
            jr nz, .b3
            inc c
            ld a, c
            cp 4
            jr nz, .bg
            ld de, pal_sh + 64
            ld hl, cs_pal + 16
            ld b, 16
.ob:        ld a, [hl+]
            push hl
            call .col
            pop hl
            dec b
            jr nz, .ob
            ld a, 1
            ldh [pal_dirty], a
            ret
.col:       push bc                         ; NES colour A -> [DE++] (RGB555)
            push de
            ld b, a
            ld a, [cs_grey]                 ; (FF3's greyscale: the hue cleared)
            and a
            ld a, b
            jr z, .c0
            and $30
.c0:        and $3F
            add a, a
            ld l, a
            ld h, 0
            ld de, NES_RGB
            add hl, de
            ld a, [hl+]
            ld b, [hl]
            pop de
            ld [de], a
            inc de
            ld a, b
            ld [de], a
            inc de
            pop bc
            ret

; FF3's sprite list -> the GB OAM (the camera; off-screen entries and y >= $EF skipped; 40 at
; most; NES attributes: palette, H flip bit 6 -> 5, V flip bit 7 -> 6, behind bit 5 -> 7)
cs_oamc:    ld hl, CS_OAM
            ld de, oam_buf
            ld c, 40
.l:         ld a, [hl+]                     ; y
            cp $EF
            jr nc, .skip3
            inc a                           ; (FF3's y + 1 = the first line)
            ld b, a
            ld a, [cs_cy]
            ld [cs_t + 3], a
            ld a, b
            push hl
            ld hl, cs_t + 3
            sub [hl]                        ; screen y (mod 256)
            pop hl
            jr nc, .y1
            cp $F9                          ; above: -7..-1 shown in part
            jr c, .skip3
            jr .y2
.y1:        cp 144
            jr nc, .skip3
.y2:        add a, 16
            ld [cs_t], a
            ld a, [hl+]                     ; tile
            ld [cs_t + 1], a
            ld a, [hl+]                     ; attributes
            ld b, a
            and 3
            or 8
            bit 6, b
            jr z, .h
            or $20
.h:         bit 7, b
            jr z, .v
            or $40
.v:         bit 5, b
            jr z, .p
            or $80
.p:         ld [cs_t + 2], a
            ld a, [hl+]                     ; x
            ld b, a
            ld a, [cs_cx]
            ld [cs_t + 3], a
            ld a, b
            push hl
            ld hl, cs_t + 3
            sub [hl]
            pop hl
            jr nc, .x1
            cp $F9
            jr c, .next
            jr .x2
.x1:        cp 160
            jr nc, .next
.x2:        add a, 8
            ld b, a
            ld a, [cs_t]
            ld [de], a
            inc e
            ld a, b
            ld [de], a
            inc e
            ld a, [cs_t + 1]
            ld [de], a
            inc e
            ld a, [cs_t + 2]
            ld [de], a
            inc e
            dec c
            jr z, .done
            jr .next
.skip3:     inc l
            inc l
            inc l
.next:      ld a, l
            and a
            jr nz, .l
.done:      xor a                           ; the rest hidden
.z:         ld a, c
            and a
            ret z
            xor a
            ld [de], a
            inc e
            inc e
            inc e
            inc e
            dec c
            jr .z

; FF8C5: a frame (the sprites); FF8B0: a frame with the palettes
cs_vbl:     call cs_oamc
            ld a, [cs_slow]                 ; (FF3's star scenes: 2 frames an iteration, as on
            and a                           ;   the NES, where they take that long: the second
            jp z, wait_vbl                  ;   V-Blank since the last one)
.w:         ldh a, [vbl_cnt]
            ld hl, cs_last
            sub [hl]
            cp 2
            jr nc, .ok
            halt
            jr .w
.ok:        ldh a, [vbl_cnt]
            ld [cs_last], a
            ret
cs_vblc:    call cs_palc
            jr cs_vbl
; 1F/A1EE B frames
cs_wait:    push bc
            call cs_vbl
            pop bc
            dec b
            jr nz, cs_wait
            ret

; FA81 the fade ranges: 0 all, 1 BG, 2 sprites -> B = first, C = end
cs_range:   ld bc, $0020
            and a
            ret z
            ld bc, $0010
            dec a
            ret z
            ld bc, $1020
            ret
; FFA87 darken palettes A one step (each colour a brightness row down, black below row 0)
cs_dark:    call cs_range
.l:         ld a, b
            add a, low(cs_pal)
            ld l, a
            ld a, high(cs_pal)
            adc a, 0
            ld h, a
            ld a, [hl]
            cp $0F
            jr z, .n
            sub $10
            jr nc, .s
            ld a, $0F
.s:         ld [hl], a
.n:         inc b
            ld a, b
            cp c
            jr nz, .l
            ret
; 1F/A0C7 decrease brightness (with $CC: every other call FF3 tints the screen instead)
cs_dim:     push af
            ld hl, cs_b7
            inc [hl]
            ld a, [hl]
            and 1
            jr nz, .f
            ld a, [cs_cc]
            and a
            jr z, .f
            pop af
            ret
.f:         pop af
            jp cs_dark
; 1F/A0E8 fade out palettes A (a step every 8 frames, 80 frames)
cs_fout:    ld [cs_ft], a
            xor a
            ld [cs_b7], a
            ld [cs_b6], a
.l:         call cs_vblc
            call cs_fhook
            ld a, [cs_b6]
            and 7
            jr nz, .n
            ld a, [cs_ft]
            call cs_dim
.n:         ld hl, cs_b6
            inc [hl]
            ld a, [hl]
            cp $50
            jr nz, .l
            xor a
            ld [cs_cc], a
            ret
; 1F/A10A fade in palettes A (112 frames: from black, the target a step brighter every 8)
cs_fin:     ld [cs_ft], a
            ld hl, cs_pal
            ld de, cs_tgt
            ld bc, 32
            call memcpy
            xor a
            ld [cs_b6], a
            ld a, [cs_ft]                   ; 1F/A1BC the range black
            call cs_range
            ld a, b
            add a, low(cs_pal)
            ld l, a
            ld h, high(cs_pal)
            ld a, c
            sub b
            ld b, a
            ld a, $0F
.c:         ld [hl+], a
            dec b
            jr nz, .c
            ld a, 13
            ld [cs_18], a
.l:         call cs_vblc
            call cs_fhook
            ld a, [cs_b6]
            and 7
            jr nz, .n
            ld hl, cs_tgt
            ld de, cs_pal
            ld bc, 32
            call memcpy
            xor a
            ld [cs_b7], a
            ld a, [cs_18]
            and a
            jr z, .n
            ld [cs_19], a
.d:         ld a, [cs_ft]
            call cs_dim
            ld hl, cs_19
            dec [hl]
            jr nz, .d
            ld hl, cs_18
            dec [hl]
.n:         ld hl, cs_b6
            inc [hl]
            ld a, [hl]
            cp $70
            jr nz, .l
            xor a
            ld [cs_cc], a
            ret
cs_fhook:   ld a, [cs_hook]                 ; (the scene's work during a fade: none here)
            ret

; page A of cut.py's blocks -> the BG map at the camera (one DMA in a V-Blank)
cs_page:    add a, a
            ld l, a
            ld h, 0
            ld de, CUT_PAGES
            add hl, de
            ld de, cs_tmp
            ld bc, 2
            ld a, CUTD
            call rd_copy
            ld hl, cs_tmp
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld a, CUTD
            call rd_byte                    ; first row, count
            ld [cs_t], a
            ld a, CUTD
            call rd_byte
            ld [cs_t + 1], a
            ld de, CS_ROWS
            ld a, [cs_t + 1]
            ld b, a
.r:         push bc
            ld a, [cs_cx]                   ; (row: blank around the 20 cells at the camera)
            rrca
            rrca
            rrca
            and $1F
            ld c, a
            ld a, $FF
.b1:        ld [de], a                      ; (cs_cx / 8 = 6: cells 0-5)
            inc de
            dec c
            jr nz, .b1
            push hl
            ld bc, 20
            ld a, CUTD
            call rd_copy
            pop hl
            ld bc, 20
            add hl, bc
            ld c, 6
            ld a, $FF
.b2:        ld [de], a
            inc de
            dec c
            jr nz, .b2
            pop bc
            dec b
            jr nz, .r
            ld a, [cs_cy]                   ; map row = cy / 8 + first
            rrca
            rrca
            rrca
            and $1F
            ld b, a
            ld a, [cs_t]
            add a, b
            and $1F
            ld l, a                         ; DE = $9800 + 32 row
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, $9800
            add hl, de
            ld a, [cs_t + 1]
            add a, a                        ; (32 bytes a row = 2 blocks)
            ld b, a
            ld d, h
            ld e, l
            ld hl, CS_ROWS
; B blocks HL (WRAM) -> DE (VRAM bank 0) in the next V-Blank
cs_dma:     push bc
            push de
            push hl
            call cs_vbl
            pop hl
            pop de
            pop bc
            ld a, h
            ldh [rHDMA1], a
            ld a, l
            ldh [rHDMA2], a
            ld a, d
            ldh [rHDMA3], a
            ld a, e
            ldh [rHDMA4], a
            ld a, b
            dec a
            ldh [rHDMA5], a
            ret

; ---- the prologue (1F/A326): the crystal, the title, the staff and the opening story
cut_pro:    ld bc, 48 * 256 + 32
            call cs_init
            xor a                           ; 1F/A3CA palette set 0
            call cs_palset
            xor a                           ; 1F/A3CF graphics 0-4
.g:         push af
            call cs_gfx
            pop af
            inc a
            cp 5
            jr nz, .g
            ld a, $14
            call snd_song
            call cs_on
            call pro_flash                  ; 1F/A428 the crystal flashes (3 times)
            call pro_flash
            call pro_flash
            ld a, 2                         ; 1F/A41C the whole crystal, faded in
            call pro_part
            ld a, 1
            ld [cs_cc], a
            xor a
            call cs_fin
            call pro_spark                  ; 1F/A3FB
            xor a
            call cs_text
            ld a, 1
            call cs_text
            ld a, $30
            ld [cs_pal + 3], a
            ld a, 1
            call cs_fin
            ld b, $F0
            call cs_wait
            ld b, $64
            call cs_wait
            ld a, 1
            call cs_fout
            ld a, 2
            call cs_text
            ld a, 3
            call cs_text
            call pro_up                     ; 1F/A3AC
            ld a, 4                         ; texts 4-12
            ld [cs_k], a
.t:         ld a, [cs_k]                    ; 1F/A395
            call cs_text
            ld hl, cs_k
            inc [hl]
            ld a, $30
            ld [cs_pal + 3], a
            ld a, 1
            call cs_fin
            ld b, $EC
            call cs_wait
            ld a, 1
            call cs_fout
            ld a, [cs_k]
            cp 13
            jr nz, .t
            ld a, $0C                       ; the music fades out
            ld [S42], a
            ld b, $78
            call cs_wait
            xor a
            call cs_fout
            jp cs_end

; 1F/A52D page A: the text colour black, a frame, the page
cs_text:    push af
            ld a, $0F
            ld [cs_pal + 3], a
            call cs_vblc
            pop af
            jp cs_page

; 1F/A42E a flash: 60 frames, the bottom left part, the top right part, gone, 60 frames
pro_flash:  ld b, $3C
            call cs_wait
            xor a
            call pro_part
            call cs_vblc
            ld b, 3
            call cs_wait
            ld a, 1
            call pro_part
            call cs_vblc
            ld b, 3
            call cs_wait
            call cs_oclr
            call cs_vblc
            ld b, $3C
            jp cs_wait

; 1F/A458 crystal part A (1F/A4AB: width, height, list index, -, count, x, y, list offset):
; sprite k at (x + 8 (k mod width), y + 8 (k / width)), tiles / attributes from 1F/A4C3 / A4C9
pro_part:   add a, a
            add a, a
            add a, a
            add a, low($A4AB + N1F)
            ld l, a
            ld a, high($A4AB + N1F)
            adc a, 0
            ld h, a
            ld a, [hl+]
            ld [cs_w], a
            inc hl
            ld a, [hl+]                     ; list index
            ld c, a
            inc hl
            ld a, [hl+]
            ld [cs_n], a
            ld a, [hl+]
            ld [cs_x], a
            ld a, [hl+]
            ld [cs_y], a
            ld a, [hl]
            ld e, a                         ; DE = the sprite list entry
            ld d, high(CS_OAM)
            ld b, 0
            ld hl, $A4C3 + N1F
            add hl, bc
            ld a, [hl+]
            ld [cs_p], a
            ld a, [hl]
            ld [cs_p + 1], a
            ld hl, $A4C9 + N1F
            add hl, bc
            ld a, [hl+]
            ld [cs_q], a
            ld a, [hl]
            ld [cs_q + 1], a
            xor a
            ld [cs_r], a                    ; row
            ld [cs_c], a                    ; column
.s:         ld a, [cs_r]                    ; y
            add a, a
            add a, a
            add a, a
            ld b, a
            ld a, [cs_y]
            add a, b
            ld [de], a
            inc e
            ld hl, cs_p                     ; tile
            call .nx
            ld [de], a
            inc e
            ld hl, cs_q                     ; attributes
            call .nx
            ld [de], a
            inc e
            ld a, [cs_c]                    ; x
            add a, a
            add a, a
            add a, a
            ld b, a
            ld a, [cs_x]
            add a, b
            ld [de], a
            inc e
            ld hl, cs_c
            inc [hl]
            ld a, [cs_w]
            cp [hl]
            jr nz, .k
            ld [hl], 0
            ld hl, cs_r
            inc [hl]
.k:         ld hl, cs_n
            dec [hl]
            jr nz, .s
            ret
.nx:        ld a, [hl+]                     ; [ptr++] (an NES address in bank 1F)
            ld c, a
            ld b, [hl]
            inc bc
            ld [hl], b
            dec hl
            ld [hl], c
            dec bc
            ld hl, N1F
            add hl, bc
            ld a, [hl]
            ret

; 1F/A3FB the sparkle: sprite 0 from 1F/A3DB + (frame & $1C), 64 frames
pro_spark:  xor a
            ld [cs_b6], a
.l:         call cs_vbl
            ld a, [cs_b6]
            and $1C
            add a, low($A3DB + N1F)
            ld l, a
            ld a, high($A3DB + N1F)
            adc a, 0
            ld h, a
            ld de, CS_OAM
            ld bc, 4
            call memcpy
            ld hl, cs_b6
            inc [hl]
            ld a, [hl]
            and $40
            jr z, .l
            ret

; 1F/A3AC the crystal up 48 lines (sprites 2-29)
pro_up:     ld c, $30
.f:         push bc
            call cs_vbl
            ld hl, CS_OAM + 8
            ld b, 28
.s:         dec [hl]
            inc l
            inc l
            inc l
            inc l
            dec b
            jr nz, .s
            pop bc
            dec c
            jr nz, .f
            jp cs_vbl

; ---- the epilogue (1F/B146): the stars, five story pages scrolled up from below (FF3 writes
; each into the other nametable and scrolls 240 lines; here the pages lie in a virtual column,
; page p at rows 30 (p + 1) to + 17, and every row is written into the 32-row BG ring as it comes
; into view), then the stars rush out (1F/B1A1)
ST_A       = $D500              ; $7575 angle (y), $75B5 (x), $75F5 radius index, $7635 speed,
ST_B       = $D540              ;   $7675 fraction, $76B5 age
ST_R       = $D580
ST_S       = $D5C0
ST_F       = $D600
ST_AGE     = $D640
ST_SIN     = $D700              ; $7200 the sine table (10/9A80)

cut_epi:    ld bc, 48 * 256 + 48
            call cs_init
            ld a, 6
            call cs_palset
            xor a                           ; graphics 0-4, the stars (B12D: 5)
.g:         push af
            call cs_gfx
            pop af
            inc a
            cp 6
            jr nz, .g
            ld a, $30
            ld [cs_pal + 3], a
            xor a
            ld [ep_v], a
            ld [ep_v + 1], a
            ld [ep_pend], a
            ld [st_end], a
            ld a, 19
            ld [ep_next], a
            ld a, $3C
            call snd_song
            call cs_on
            call cs_vblc
            call st_init                    ; 1F/B3EA
            call cs_vblc
            call st_draw
            xor a
            ld [cs_cc], a
            call cs_fin
            ld a, 1
            ld [cs_slow], a
            ldh a, [vbl_cnt]
            ld [cs_last], a
            ld a, $0D
            ld [cs_k], a
.p:         call cs_vblc                    ; 1F/B178
            call st_draw
            call st_move
            ld b, 6                         ; 1F/B212: the page written over 6 frames
.w:         push bc
            call ep_frame
            pop bc
            dec b
            jr nz, .w
            ld bc, 240                      ; 1F/B1E7: scrolled 240 lines
.s:         push bc
            ld hl, ep_v
            inc [hl]
            jr nz, .s1
            inc hl
            inc [hl]
.s1:        ld a, [ep_v]
            ldh [scy], a
            call ep_frame
            pop bc
            dec bc
            ld a, b
            or c
            jr nz, .s
            call cs_vblc
            ld a, [cs_k]
            cp $12
            jr z, .n
            ld b, 100                       ; 1F/B1D6
.h:         push bc
            call cs_vblc
            call st_draw
            call st_move
            pop bc
            dec b
            jr nz, .h
.n:         ld hl, cs_k
            inc [hl]
            ld a, [hl]
            cp $13
            jr nz, .p
            ld a, 1                         ; 1F/B1A1 the stars rush out: speed 1-8, then fewer
            ld [ep_cc], a
            xor a
            ld [ep_cd], a
.f:         call cs_vblc
            call st_draw
            ld hl, ST_A                     ; 1F/B406 every star 2 on
            ld b, 128
.f2:        inc [hl]
            inc [hl]
            inc l
            dec b
            jr nz, .f2
            ld a, [ep_cc]
.f3:        push af
            call st_move
            pop af
            dec a
            jr nz, .f3
            ld a, [ep_cc]
            cp 8
            jr z, .c
            ld a, [ep_cd]
            sub 8
            ld [ep_cd], a
            jr nz, .f
            ld hl, ep_cc
            inc [hl]
            ld a, [hl]
            cp 8
            jr nz, .f
.c:         ld hl, st_cnt
            dec [hl]
            jr nz, .f
            jp cs_end

; a frame of the scroll: the row coming into view written in the V-Blank, the stars
ep_frame:   call ep_prep
            call cs_vbl
            ld a, [ep_pend]
            and a
            jr z, .s
            xor a
            ld [ep_pend], a
.ly:        ldh a, [rLY]                    ; (in the V-Blank: a late frame waits for it)
            cp 144
            jr c, .ly
            cp 152
            jr nc, .ly
            ld a, [ep_dst]
            ld e, a
            ld a, [ep_dst + 1]
            ld d, a
            ld hl, CS_ROWS
            ld a, h
            ldh [rHDMA1], a
            ld a, l
            ldh [rHDMA2], a
            ld a, d
            ldh [rHDMA3], a
            ld a, e
            ldh [rHDMA4], a
            ld a, 1                         ; (2 blocks)
            ldh [rHDMA5], a
.s:         call st_draw
            jp st_move
; the next row (ep_next) when it is within 152 lines of the view's top: its 32 cells -> CS_ROWS
ep_prep:    ld a, [ep_next]                 ; HL = 8 row
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            ld a, [ep_v]                    ; DE = V + 152
            add a, 152
            ld e, a
            ld a, [ep_v + 1]
            adc a, 0
            ld d, a
            ld a, e                         ; DE - HL < 0: not yet
            sub l
            ld a, d
            sbc a, h
            ret c
            ld a, [ep_next]
            ld c, a
            inc a
            ld [ep_next], a
            ld a, c                         ; destination $9800 + 32 (row & 31)
            and $1F
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, $9800
            add hl, de
            ld a, l
            ld [ep_dst], a
            ld a, h
            ld [ep_dst + 1], a
            ld b, 0                         ; q = row / 30, k = row mod 30
            ld a, c
.q:         cp 30
            jr c, .q1
            sub 30
            inc b
            jr .q
.q1:        ld c, a                         ; C = k, B = q
            ld hl, CS_ROWS
            ld a, $FF
            ld d, 32
.bl:        ld [hl+], a
            dec d
            jr nz, .bl
            ld a, 1
            ld [ep_pend], a
            ld a, b                         ; page p = q - 1 (0-5), rows 0-17
            and a
            ret z
            cp 7
            ret nc
            ld a, c
            cp 18
            ret nc
            ld a, b
            add a, 12                       ; page index 13 + p
            add a, a
            ld l, a
            ld h, 0
            ld de, CUT_PAGES
            add hl, de
            push bc
            ld de, cs_tmp
            ld bc, 2
            ld a, CUTD
            call rd_copy
            pop bc
            ld hl, cs_tmp                   ; + 2 + 20 k
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            inc hl
            inc hl
            ld a, c
            and a
            jr z, .k0
            ld de, 20
.k:         add hl, de
            dec c
            jr nz, .k
.k0:        ld de, CS_ROWS + 6
            ld bc, 20
            ld a, CUTD
            jp rd_copy

; 1F/B476 + B3EA: angles 0 / $40, radius index 1, speed $FF, the sine table, 63 stars shown
st_init:    ld hl, ST_A
            ld b, 64
.a:         xor a
            ld [hl+], a
            dec b
            jr nz, .a
            ld b, 64
            ld a, $40
.b:         ld [hl+], a
            dec b
            jr nz, .b
            ld b, 64
            ld a, 1
.r:         ld [hl+], a
            dec b
            jr nz, .r
            ld b, 64
            ld a, $FF
.s:         ld [hl+], a
            dec b
            jr nz, .s
            ld hl, CUT_SINE
            ld de, ST_SIN
            ld bc, 256
            ld a, CUTD
            call rd_copy
            ld a, $3F
            ld [st_cnt], a
            jp st_move

; 1F/B413 move: fraction += speed; on a carry the star ages and comes in (radius index - 1);
; at 0 it starts again (1F/B4FA / B50A by $B7, the angle from the random table by $B6)
st_move:    ld c, 0
.l:         ld b, high(ST_F)
            ld a, c
            add a, low(ST_F)
            ld l, a
            ld h, b
            ld a, c
            add a, low(ST_S)
            ld e, a
            ld d, high(ST_S)
            ld a, [de]
            add a, [hl]
            ld [hl], a
            jr nc, .n
            ld a, c
            add a, low(ST_AGE)
            ld l, a
            ld h, high(ST_AGE)
            inc [hl]
            ld a, c
            add a, low(ST_R)
            ld l, a
            ld h, high(ST_R)
            ld a, [hl]
            dec a
            and $7F
            ld [hl], a
            jr nz, .n
            ld a, [cs_b7]                   ; a new star
            ld e, a
            inc a
            ld [cs_b7], a
            ld a, e
            and $0F
            ld e, a
            ld d, 0
            push hl
            ld hl, $B4FA + N1F
            add hl, de
            ld a, [hl]
            pop hl
            ld [hl], a                      ; radius index
            push hl
            ld hl, $B50A + N1F
            add hl, de
            ld a, [hl]
            pop hl
            ld e, a
            ld a, c
            add a, low(ST_S)
            ld l, a
            ld h, high(ST_S)
            ld [hl], e
            ld a, c
            add a, low(ST_AGE)
            ld l, a
            ld h, high(ST_AGE)
            ld [hl], 0
            ld hl, cs_b6
            inc [hl]
            ld l, [hl]
            ld h, high(N_RNG)
            ld a, [hl]
            ld e, a
            ld a, c
            add a, low(ST_A)
            ld l, a
            ld h, high(ST_A)
            ld [hl], e
            ld a, e
            add a, $40
            ld e, a
            ld a, c
            add a, low(ST_B)
            ld l, a
            ld h, high(ST_B)
            ld [hl], e
.n:         inc c
            ld a, c
            cp $3F
            jr nz, .l
            ret

; 1F/B39F the stars -> the sprite list: y = $78 + f(angle A), x = $80 + f(angle B), the tile by
; age (1F/B370), palette 2 (0 for every 16th), behind the BG at the end (1F/B38B)
st_draw:    call cs_oclr
            ld a, [st_cnt]
            and a
            ret z
            ld c, 0
            ld de, CS_OAM
.l:         ld a, c
            add a, low(ST_A)
            ld l, a
            ld h, high(ST_A)
            ld a, [hl]
            call st_f
            add a, $78
            ld [de], a
            inc e
            ld a, c                         ; tile by age
            add a, low(ST_AGE)
            ld l, a
            ld h, high(ST_AGE)
            ld a, [hl]
            ld b, 1
            cp $78
            jr nc, .t
            inc b
            cp $64
            jr nc, .t
            inc b
            cp $3C
            jr nc, .t
            inc b
.t:         ld a, b
            ld [de], a
            inc e
            ld a, c
            and $0F
            jr z, .p
            ld a, 2
.p:         ld b, a
            ld a, [st_end]
            and a
            jr z, .p1
            set 5, b
.p1:        ld a, b
            ld [de], a
            inc e
            ld a, c
            add a, low(ST_B)
            ld l, a
            ld h, high(ST_B)
            ld a, [hl]
            call st_f
            add a, $80
            ld [de], a
            inc e
            inc c
            ld a, [st_cnt]
            cp c
            jr nz, .l
            ret
; 1F/B4A6 f(angle A) for star C: sine (signed by bit 7) x (1F/B51A[radius index] / 2), FF3's
; 8-bit product (1F/B4E1: (2 s and $FF) x amplitude / 256)
st_f:       push de
            ld l, a
            ld h, high(ST_SIN)
            ld a, [hl]
            ld d, a                         ; (D bit 7: the sign)
            bit 7, a
            jr z, .pos
            cpl
.pos:       add a, a
            ld e, a
            ld a, c
            add a, low(ST_R)
            ld l, a
            ld h, high(ST_R)
            ld l, [hl]
            ld h, 0
            push bc
            ld bc, $B51A + N1F
            add hl, bc
            pop bc
            ld a, [hl]
            srl a
            ld h, a                         ; H x E -> A (high byte)
            ld l, 0
            xor a
            ld b, 8
.m:         srl e
            jr nc, .m1
            add a, h
.m1:        rra
            rr l
            dec b
            jr nz, .m
            bit 7, d
            jr z, .x
            cpl
            inc a
.x:         pop de
            ret
; ---- the ending (1F/B5B6): the land revealed from the middle, the clouds drifting, the crystal,
; night to dawn to day, the birds, a flash; then the end credits (1F/B94A)
CS_TXT     = $D100              ; $7900 the credits' text buffer (32 x 16)
CS_Z       = $D800              ; a zero buffer (DMA source)

cut_end:    ld bc, 48 * 256 + 40
            call cs_init
            ld a, 6                         ; 1F/B7B0 the land's tiles, the sprites
            call cs_gfx
            ld a, 7
            call cs_gfx
            ld hl, $4000 + 8 * 8            ; (the picture: entry 8, revealed row by row)
            ld de, en_src
            ld bc, 2
            ld a, CUTD
            call rd_copy
            ld hl, en_wipe.out              ; (rows out of the view: now, the LCD off)
            ld b, 12
.o:         ld a, [hl+]
            push hl
            push bc
            call en_row
            pop bc
            pop hl
            dec b
            jr nz, .o
            ld a, 3
            call cs_palset
            ld a, 4                         ; the music stops
            ld [S42], a
            call cs_on
            ld a, 2
            ld [en_90], a
            ld a, 16
            ld [en_top], a
            ld a, 15
            ld [en_bot], a
            xor a
            ld [en_f], a
            ld [en_sx], a
            ld [cs_grey], a
            call cs_vblc
.w:         call cs_vbl                     ; 1F/B5D6 the band grows a line a frame each way
            call en_wipe
            ld hl, en_90
            inc [hl]
            inc [hl]
            ld hl, en_f
            inc [hl]
            ld a, [hl]
            cp 112
            jr nz, .w
            xor a
            ld [cs_b6], a
            ld [cs_b7], a
            ld [en_91], a
            ld a, $F6
            ld [en_9e], a
            ld a, $58
            ld [en_9d], a
.l1:        call en_frm                     ; 1F/B616
            call en_ev
            ld c, 0
.ob:        push bc                         ; 1F/B783 the clouds (1F/B7A0: x + $90, y, -, list)
            ld a, c
            add a, a
            add a, a
            ld l, a
            ld h, 0
            ld de, $B7A0 + N1F
            add hl, de
            ld a, [en_90]
            add a, [hl]
            ld [en_x], a
            inc hl
            ld a, [hl+]
            ld [en_y], a
            inc hl
            ld a, [hl]
            call cs_slist
            pop bc
            inc c
            ld a, c
            cp 4
            jr nz, .ob
            ld hl, cs_b6
            inc [hl]
            jr nz, .b6
            ld hl, cs_b7
            inc [hl]
.b6:        ld a, [cs_b6]
            and 7
            jr nz, .l1
            ld hl, en_90
            dec [hl]
            ld a, [cs_b7]
            cp 12
            jr nz, .l1
            xor a
            ld [cs_b6], a
.l2:        call en_frm                     ; 1F/B63D the land fades, the crystal stays
            call en_cry
            ld a, [cs_b6]
            and 7
            jr nz, .l2n
            xor a
            call cs_dark
            ld hl, $B6AE + N1F
            ld de, cs_pal + 16
            ld bc, 8
            call memcpy
.l2n:       ld hl, cs_b6
            inc [hl]
            ld a, [hl]
            and $20
            jr z, .l2
            call en_frm
            ld a, $3C
            ld [en_90], a
            xor a
            ld [cs_b6], a
.l3:        call cs_vblc                    ; 1F/B680 the flash (every 4 frames)
            ld a, [cs_b6]
            and 4
            add a, a
            add a, low($B69E + N1F)
            ld l, a
            ld a, high($B69E + N1F)
            adc a, 0
            ld h, a
            ld de, cs_pal
            ld b, 4
.fl:        push bc
            push hl
            ld bc, 8
            call memcpy
            pop hl
            pop bc
            dec b
            jr nz, .fl
            ld hl, cs_b6
            inc [hl]
            ld hl, en_90
            dec [hl]
            jr nz, .l3
            ld b, $1E
            call cs_wait
            jp cr_go

; 1F/B5AB a frame (palettes), the sprite list cleared
en_frm:     call cs_vblc
            call cs_oclr
            xor a
            ld [cs_c8], a
            ret
; 1F/B6B6 the crystal at (48, 48): list 7 / 8 (every 4 frames)
en_cry:     ld a, $30
            ld [en_x], a
            ld [en_y], a
            ld a, [cs_b6]
            and 4
            rrca
            rrca
            add a, 7
            jp cs_slist
; the wipe's rows: the band (NES lines 120 - f - 1 .. 119 + f + 1); rows out of the view first
en_wipe:    ld a, [en_f]
            inc a
            ld b, a
            ld a, 120
            sub b
            rrca
            rrca
            rrca
            and $1F
            ld c, a                         ; the top row
            ld hl, en_top
            ld a, [hl]
            cp c
            jr z, .t
            jr c, .t
            dec [hl]
            ld a, [hl]
            call en_row
.t:         ld a, [en_f]
            add a, 120
            rrca
            rrca
            rrca
            and $1F
            ld c, a
            ld hl, en_bot
            ld a, [hl]
            cp c
            ret nc
            inc [hl]
            ld a, [hl]
            jp en_row
.out:       db 0, 1, 2, 3, 4, 23, 24, 25, 26, 27, 28, 29
; picture row A -> the BG map (tiles, then the CGB attributes)
en_row:     ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            push hl
            ld de, $9800
            add hl, de
            ld d, h
            ld e, l
            pop hl
            push de
            ld a, [en_src]
            ld c, a
            ld a, [en_src + 1]
            ld b, a
            add hl, bc
            push hl
            ld bc, 32
            ld a, CUTD
            call rd_copy
            pop hl
            ld bc, 960
            add hl, bc
            pop de
            ld a, 1
            ldh [rVBK], a
            ld bc, 32
            ld a, CUTD
            call rd_copy
            xor a
            ldh [rVBK], a
            ret

; 1F/B6D1 the flyover's events by time ($B7 = frames / 256)
en_ev:      ld a, [en_91]
            and a
            jr z, .t6
            call en_cry
            ld a, [cs_b7]                   ; (until $B7 = 5: greyscale every other frame)
            cp 5
            ld a, 0
            jr nc, .g
            ld a, [cs_grey]
            xor 1
.g:         ld [cs_grey], a
.t6:        ld a, [cs_b7]
            cp 6
            jr z, .b705
            cp 7
            jr nz, .b72a
            ld a, [cs_b6]
            and a
            jr nz, .b705
            ld a, $FF                       ; (B7 = 7: a sound, song $3B)
            ld [S49], a
            ld a, $3B
            call snd_song
.b705:      ld a, [cs_b6]                   ; the birds: left a pixel every 2 frames, up every 8
            bit 0, a
            jr z, .b1
            ld hl, en_9e
            dec [hl]
.b1:        ld a, [en_9e]
            ld [en_x], a
            ld a, [cs_b6]
            and 7
            jr nz, .b2
            ld hl, en_9d
            dec [hl]
.b2:        ld a, [en_9d]
            ld [en_y], a
            ld a, [cs_b6]
            and 8
            rrca
            rrca
            rrca
            add a, 9
            call cs_slist
.b72a:      ld a, [cs_b7]
            cp 2
            jr nz, .b733
            ld a, [cs_b6]                   ; (B7 = 2: the picture shakes)
            and 3
            ld [en_sx], a
            add a, 48
            ldh [scx], a
.b733:      ld a, [cs_b7]
            cp 3
            jr nz, .b771
            ld a, [cs_b6]
            bit 7, a
            jr nz, .b75b
            ld a, $30                       ; the crystal appears (lists 2-6, then 7)
            ld [en_x], a
            ld [en_y], a
            ld a, [en_91]
            and a
            ret nz
            ld a, [cs_b6]
            and $38
            rrca
            rrca
            rrca
            add a, 2
            cp 7
            jr nz, .b757
            ld hl, en_91
            inc [hl]
.b757:      jp cs_slist
.b75b:      cp $80                          ; dawn: palette set 1 a step dark, then set 1
            jr nz, .b767
            ld a, 1
            call cs_palset
            xor a
            jp cs_dark
.b767:      cp $C0
            ret nz
            ld a, 1
            jp cs_palset
.b771:      cp 4
            ret nz
            ld a, [cs_b6]
            cp $80
            ret nz
            ld a, 2                         ; day
            jp cs_palset

; 1F/B7C9 sprite list A (1F/B805) at (en_x, en_y), appended at cs_c8
cs_slist:   add a, a
            ld l, a
            ld h, 0
            ld de, $B805 + N1F
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld de, N1F
            add hl, de
            ld a, [cs_c8]
            ld e, a
            ld d, high(CS_OAM)
.l:         ld a, [hl+]
            cp $FF
            jr z, .e
            ld b, a
            ld a, [en_y]
            add a, b
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [en_x]
            add a, b
            ld [de], a
            inc e
            jr .l
.e:         ld a, e
            ld [cs_c8], a
            ret

; ---- the end credits (1F/B94A): the party, the cast, the staff, THE END
cr_go:      ld a, 1
            ld [cs_cc], a
            xor a
            ld [cs_grey], a
            ld a, 48                        ; (the credits' view: NES rows 6-23, cols 6-25)
            ld [cs_cy], a
            ldh [scy], a
            ld a, 48
            ld [cs_cx], a
            ldh [scx], a
            call cr_clr
            ld a, 9                         ; tiles 0-3 blank, the font, the romaji
            call cs_gfx
            xor a
            call cs_gfx
            ld a, 1
            call cs_gfx
            ld a, 10
            call cs_gfx
            xor a
            ld [cs_b6], a
            ld [cr_c2], a
            ld [cr_c5], a
            ld [cr_c4], a
            ld [cr_id], a
            ld [cr_ac], a
            call cs_oclr
            call cr_b942
            call cr_bd41                    ; "CAST"
            xor a
            call cs_fout
            call cs_oclr
            call cr_b942
            call cr_party                   ; 1F/BC02
            ld hl, cs_pal                   ; 1F/A1BC all black
            ld b, 32
            ld a, $0F
.k:         ld [hl+], a
            dec b
            jr nz, .k
            call cs_vbl
            call cr_cast                    ; 1F/BCCD
            call cs_oclr
            call cr_b942
            call cr_bd41                    ; "STAFF"
            xor a
            call cs_fout
            ld a, 1
            ld [cr_c4], a
            ld [cr_ac], a
            call cr_staff                   ; 1F/BBAB
            ld a, 11                        ; THE END
            call cs_gfx
            call cr_b942
            ld hl, CS_TXT
            ld de, $200
            call memclr
            ld hl, $BA23 + N1F
            ld de, CS_TXT + 6 * 32 + 4
            ld bc, 10
            call memcpy
            ld hl, $BA2D + N1F
            ld de, CS_TXT + 7 * 32 + 4
            ld bc, 10
            call memcpy
            ld hl, $BA37 + N1F
            ld de, CS_TXT + 8 * 32 + 4
            ld bc, 10
            call memcpy
            call cr_put
            ld a, 7
            call cs_palset
            xor a
            call cs_fin
            ld c, 10
.wt:        ld b, $32
            push bc
            call cs_wait
            pop bc
            dec c
            jr nz, .wt
            ld a, 1                         ; the stars behind THE END, for ever
            ld [st_end], a
            ld a, 5
            call cs_gfx
            ld a, $30
            ld [cs_pal + 3], a
            call st_init
            xor a
            ld [cs_b6], a
            ld a, 1
            ld [cs_slow], a
            ldh a, [vbl_cnt]
            ld [cs_last], a
.end:       call cs_vbl
            call st_draw
            call st_move
            jr .end

; the BG map cleared (tiles and attributes: 4 V-Blanks of DMA)
cr_clr:     ld hl, CS_Z
            ld de, $400
            call memclr
            ld de, $9800
            call .two
            ld a, 1
            ldh [rVBK], a
            ld de, $9800
            call .two
            xor a
            ldh [rVBK], a
            ret
.two:       ld b, 2
.h:         push bc
            push de
            ldh a, [rVBK]
            push af
            call cs_vbl
            pop af
            ldh [rVBK], a
            pop de
            ld hl, CS_Z
            ld a, h
            ldh [rHDMA1], a
            ld a, l
            ldh [rHDMA2], a
            ld a, d
            ldh [rHDMA3], a
            ld a, e
            ldh [rHDMA4], a
            ld a, 63
            ldh [rHDMA5], a
            ld hl, $400
            add hl, de
            ld d, h
            ld e, l
            pop bc
            dec b
            jr nz, .h
            ret

; 1F/B942 palette set 4, a frame
cr_b942:    ld a, 4
            call cs_palset
            jp cs_vblc
; 1F/BD41 the next text, palette set 5, all faded in, 130 frames; 1F/BD56 the BG only
cr_bd41:    call cr_text
            call cr_put
            ld a, 5
            call cs_palset
            xor a
cr_bd4e:    call cs_fin
            ld b, $82
            jp cs_wait
cr_bd56:    ld a, 5
            call cs_palset
            ld a, 1
            jr cr_bd4e

; 1F/BA41 the next credits string (10/9640) into the text buffer
cr_text:    call cr_bclr
            ld a, [cr_id]
            ld l, a
            inc a
            ld [cr_id], a
            ld h, 0
            add hl, hl
            ld de, $5300
            add hl, de
            ld de, cs_tmp
            ld bc, 2
            ld a, CUTD2
            call rd_copy
            ld hl, cs_tmp
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld de, cr_str
            ld bc, 254
            ld a, CUTD2
            call rd_copy
            ld hl, cr_str
; FF3's text drawer (bconv): 00 end, 01 a new two-row line, 02 n n cells on, else a tile (on
; the lower row of the line), into the 32-wide buffer
cr_bconv:   ld de, CS_TXT + 32
            ld c, 0
.l:         ld a, [hl+]
            and a
            ret z
            cp 1
            jr nz, .n2
            ld a, e
            add a, 64
            ld e, a
            jr nc, .n1
            inc d
.n1:        ld c, 0
            jr .l
.n2:        cp 2
            jr nz, .t
            ld a, [hl+]
            add a, c
            ld c, a
            jr .l
.t:         push hl
            ld b, a
            ld a, e
            add a, c
            ld l, a
            ld a, d
            adc a, 0
            ld h, a
            ld [hl], b
            pop hl
            inc c
            jr .l
cr_bclr:    ld hl, CS_TXT                   ; 1F/A51F the buffer blank ($FF)
            ld bc, $200
.c:         ld a, $FF
            ld [hl+], a
            dec bc
            ld a, b
            or c
            jr nz, .c
            ret
; 1F/BA95 the buffer's 14 x 18 cells -> NES rows 8-21, cols 7-24 (a row a frame)
cr_put:     ld hl, CS_TXT
            ld de, $9800 + 8 * 32 + 7
            ld c, 14
.r:         push bc
            push de
            push hl
            call cs_vbl
            pop hl
            pop de
            push de
            push hl
            ld b, 18
.c:         ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .c
            pop hl
            ld bc, 32
            add hl, bc
            pop de
            ld a, e
            add a, 32
            ld e, a
            jr nc, .n
            inc d
.n:         pop bc
            dec c
            jr nz, .r
            ret

; 1F/BC02 each member: walks in, swings, name and level, cheers, walks out
cr_party:   xor a
            ld [cr_c5], a
.m:         ld a, [cr_c5]
            ld l, a
            ld h, high(GS + $100)
            ld a, [hl]                      ; job
            ld [cr_c3], a
            call cr_jobw
            ld a, $68
            ld [cr_c1], a
            ld a, $F0
            ld [cr_c0], a
            xor a
            ld [cs_b6], a
.w1:        call cr_walk
            ld a, [cr_c0]
            cp $78
            jr nz, .w1
            xor a
            ld [cr_95], a
            call cr_swing
            call cr_still
            call cr_name
            call cr_cheer
            call cr_still
            ld a, 1
            call cs_fout
            xor a
            ld [cs_b6], a
.w2:        call cr_walk
            ld a, [cr_c0]
            and a
            jr nz, .w2
            call cs_oclr
            call cs_vblc
            ld a, [cr_c5]
            add a, $40
            ld [cr_c5], a
            jr nz, .m
            ret
; job cr_c3's sprites (1F/BE3A) and weapon (1F/BDEA, by 1F/BFC2)
cr_jobw:    ld a, [cr_c3]
            ld l, a                         ; 42 tiles of the characters' bank: job x 672
            ld h, 0
            ld d, h
            ld e, l
            add hl, hl                      ; x 42 = x 32 + x 8 + x 2
            add hl, hl
            add hl, hl
            push hl
            add hl, hl
            add hl, hl
            pop bc
            add hl, bc
            ld b, d
            ld c, e
            add hl, bc
            add hl, bc
            add hl, hl                      ; x 16
            add hl, hl
            add hl, hl
            add hl, hl
            ld bc, $4000
            add hl, bc
            ld a, CHGFX_BANK
            ld [vc_src], a
            ld de, $8000
            ld b, 42
            ld a, 1
            call vcopyx
            ld a, 42
            call cs_tw
            ld a, [cr_c3]
            ld e, a
            ld d, 0
            ld hl, $BFC2 + N1F
            add hl, de
            ld a, [hl]
            ld l, a                         ; 2E/9098 + 3 n: -, tile, general palette
            ld h, 0
            ld d, h
            ld e, l
            add hl, hl
            add hl, de
            ld de, $5000
            add hl, de
            ld de, cs_tmp
            ld bc, 3
            ld a, CUTD2
            call rd_copy
            ld a, [cs_tmp + 2]              ; FF877: 00/9100 / 9200 / 9300 + n
            ld l, a
            ld h, high(BD_GPAL)
            ld a, BDATA_BANK
            call rd_byte
            ld [cr_gp], a
            dec hl
            inc h
            ld a, BDATA_BANK
            call rd_byte
            ld [cr_gp + 1], a
            dec hl
            inc h
            ld a, BDATA_BANK
            call rd_byte
            ld [cr_gp + 2], a
            ld a, [cs_tmp + 1]              ; 4 tiles of 2B/B000 -> sprite tiles $80-$83
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld bc, $4000
            add hl, bc
            ld a, CUTD2
            ld [vc_src], a
            ld de, $8800
            ld b, 4
            ld a, 1
            jp vcopyx
; 1F/BDBB a walking frame: 2 pixels left
cr_walk:    call en_frm
            call cr_draw
            ld a, [cs_b6]
            and 4
            rrca
            rrca
            ld [cr_c2], a
            ld hl, cr_c0
            dec [hl]
            dec [hl]
            ld hl, cs_b6
            inc [hl]
            ret
; 1F/BED6 standing
cr_still:   call cs_oclr
            xor a
            ld [cs_c8], a
            ld a, 1
            ld [cr_c2], a
; 1F/BEE1 the character (6 sprites: 1F/BF35 frame cr_c2, 1F/BF5F palette by cr_c3, offsets
; 1F/BF7D / BF83), and its mirror image when cr_c4 is set
cr_draw:    xor a
            call .one
            ld a, [cr_c4]
            and a
            ret z
.one:       ld [cr_cd], a
            ld a, [cr_c2]
            ld l, a
            add a, a
            add a, l
            add a, a
            add a, low($BF35 + N1F)
            ld l, a
            ld a, high($BF35 + N1F)
            adc a, 0
            ld h, a
            push hl
            ld a, [cr_c3]
            ld e, a
            ld d, 0
            ld hl, $BF5F + N1F
            add hl, de
            ld a, [hl]
            ld [cs_t + 2], a
            pop hl
            ld a, [cs_c8]
            ld e, a
            ld d, high(CS_OAM)
            ld c, 0
.s:         push hl
            ld hl, $BF83 + N1F
            ld b, 0
            add hl, bc
            ld a, [cr_c1]
            add a, [hl]
            ld [de], a
            inc e
            pop hl
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [cs_t + 2]
            ld [de], a
            inc e
            push hl
            ld hl, $BF7D + N1F
            add hl, bc
            ld a, [cr_c0]
            add a, [hl]
            ld [de], a
            call cr_mir
            inc e
            pop hl
            inc c
            ld a, c
            cp 6
            jr nz, .s
            ld a, e
            ld [cs_c8], a
            ret
; 1F/BEBE a mirrored sprite: x = (x xor $FF) - 8, H flip toggled ([DE] = x)
cr_mir:     ld a, [cr_cd]
            and a
            ret z
            ld a, [de]
            cpl
            sub 8
            ld [de], a
            dec e
            ld a, [de]
            xor $40
            ld [de], a
            inc e
            ret
; 1F/BE80 the weapon (4 sprites, 1F/BF89 lists by frame), and its mirror
cr_wpnd:    xor a
            call .one
            ld a, [cr_c4]
            and a
            ret z
.one:       ld [cr_cd], a
            ld a, [cs_b6]
            and 4
            rrca
            add a, low($BF89 + N1F)
            ld l, a
            ld a, high($BF89 + N1F)
            adc a, 0
            ld h, a
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld bc, N1F
            add hl, bc
            ld a, [cs_c8]
            ld e, a
            ld d, high(CS_OAM)
            ld c, 4
.s:         ld a, [cr_c1]
            add a, [hl]
            inc hl
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [cr_c0]
            add a, [hl]
            inc hl
            ld [de], a
            call cr_mir
            inc e
            dec c
            jr nz, .s
            ld a, e
            ld [cs_c8], a
            ret
; 1F/BD6E the swing: until $95 = 9 (1F/BB15: every 8 frames; the staff pages: a text column
; pair every 4 frames, from both edges in)
cr_swing:   xor a
            ld [cs_b6], a
            ld hl, cr_gp                    ; 1F/BD60 the weapon's colours: sprite palette 3
            ld de, cs_pal + 29
            ld bc, 3
            call memcpy
.l:         call cr_bb15
            call cs_oclr
            xor a
            ld [cs_c8], a
            call cr_draw
            call cr_wpnd
            ld a, [cs_b6]
            and 4
            rrca
            rrca
            add a, 2
            ld [cr_c2], a
            ld hl, cs_b6
            inc [hl]
            ld a, [cr_95]
            cp 9
            jr nz, .l
            call en_frm
            jp cr_draw
cr_bb15:    ld a, [cr_ac]
            and a
            jr nz, .rv
            ld a, [cs_b6]
            and 7
            jr nz, .f
            ld hl, cr_95
            inc [hl]
.f:         jp cs_vblc
.rv:        ld a, [cs_b6]
            and 3
            jr nz, .f
            call cs_vbl
            ld a, [cr_95]                   ; left: map col 7 + k <- col k; right: 24 - k <- 17 - k
            ld c, a
            ld b, 0
            ld hl, CS_TXT
            add hl, bc
            ld de, $9800 + 8 * 32 + 7
            ld a, e
            add a, c
            ld e, a
            call .col
            ld a, 17
            sub c
            ld l, a
            ld h, 0
            ld de, CS_TXT
            add hl, de
            ld a, 24
            sub c
            add a, low($9800 + 8 * 32)
            ld e, a
            ld d, high($9800 + 8 * 32)
            call .col
            ld hl, cr_95
            inc [hl]
            ret
.col:       ld b, 14
.c:         ld a, [hl]
            ld [de], a
            ld a, l
            add a, 32
            ld l, a
            jr nc, .c1
            inc h
.c1:        ld a, e
            add a, 32
            ld e, a
            jr nc, .c2
            inc d
.c2:        dec b
            jr nz, .c
            ret
; 1F/BD9D the cheer: 128 frames (frames 4 / 5 every 16)
cr_cheer:   xor a
            ld [cs_b6], a
.l:         call en_frm
            call cr_draw
            ld a, [cs_b6]
            and $10
            swap a
            add a, 4
            ld [cr_c2], a
            ld hl, cs_b6
            inc [hl]
            bit 7, [hl]
            jr z, .l
            ret
; 1F/BC67 the member's name and "lv" + level (+ 1, two digits)
cr_name:    call cr_bclr
            ld hl, cr_str
            ld a, 1
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld a, 2
            ld [hl+], a
            ld a, 6
            ld [hl+], a
            ld d, h
            ld e, l
            ld a, [cr_c5]
            add a, 6
            ld l, a
            ld h, high(GS + $100)
            ld bc, 6
            call memcpy
            ld h, d
            ld l, e
            ld a, 1
            ld [hl+], a
            ld a, 2
            ld [hl+], a
            ld a, 7
            ld [hl+], a
            ld a, $18
            ld [hl+], a
            ld a, $22
            ld [hl+], a
            push hl
            ld a, [cr_c5]
            inc a
            ld l, a
            ld h, high(GS + $100)
            ld a, [hl]
            inc a
            ld b, $80
.d:         cp 10
            jr c, .d1
            sub 10
            inc b
            jr .d
.d1:        pop hl
            ld [hl], b
            inc hl
            add a, $80
            ld [hl+], a
            ld [hl], 0
            ld hl, cr_str
            call cr_bconv
            call cr_put
            jp cr_bd56
; 1F/BCCD the cast: 8 people (1F/BDD0 graphics, 1F/BF75 palettes), the fourth pair of two
cr_cast:    xor a
            ld [cr_c5], a
            ld a, 1
            ld [cr_c2], a
            call cs_oclr
            call cs_vblc
.l:         ld a, [cr_c5]
            ld e, a
            ld d, 0
            ld hl, $BDD0 + N1F
            add hl, de
            ld a, [hl]
            ld l, a                         ; 1F/BDD8: 6 tiles at $BA20 + $60 id (bank $14)
            ld h, 0
            ld d, h
            ld e, l
            add hl, hl
            add hl, de
            add hl, hl                      ; 6 id
            ld de, $3A2
            add hl, de
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, $4000
            add hl, de
            ld a, CHGFX_BANK
            ld [vc_src], a
            ld de, $8000
            ld b, 6
            ld a, 1
            call vcopyx
            ld a, 6
            call cs_tw
            ld a, $78
            ld [cr_c0], a
            ld a, $68
            ld [cr_c1], a
            ld a, 4
            call cs_palset
            xor a
            ld [cs_c8], a
            call cs_oclr
            ld a, [cr_c5]
            ld e, a
            ld d, 0
            ld hl, $BF75 + N1F
            add hl, de
            ld a, [hl]
            ld [cr_c3], a
            ld a, [cr_c5]
            cp 4
            jr nz, .one
            ld a, $84                       ; 1F/BD20
            ld [cr_c0], a
            ld a, 1
            ld [cr_c2], a
            ld [cr_c4], a
            call cr_draw
            ld a, $94
            ld [cr_c0], a
            ld a, 6
            ld [cr_c2], a
            call cr_draw
            xor a
            ld [cr_c4], a
            ld a, 1
            ld [cr_c2], a
            jr .t
.one:       call cr_draw
.t:         call cr_bd41
            xor a
            call cs_fout
            ld hl, cr_c5
            inc [hl]
            ld a, [hl]
            cp 8
            jr nz, .l
            ret
; 1F/BBAB the staff: 20 pages, a job on each side (1F/BFAD), the text revealed column by column
cr_staff:   xor a
            ld [cr_c6], a
            call cr_b942
.p:         ld a, $F0
            ld [cr_c0], a
            ld a, $68
            ld [cr_c1], a
            ld a, [cr_c6]
            ld e, a
            ld d, 0
            ld hl, $BFAD + N1F
            add hl, de
            ld a, [hl]
            ld [cr_c3], a
            call cr_jobw
            xor a
            ld [cs_b6], a
.w:         call cr_walk
            ld a, [cr_c0]
            cp $C0
            jr nz, .w
            call cr_still
            call cr_bclr                    ; 1F/BADC the text area blank, palette set 5
            call cr_put
            ld a, 5
            call cs_palset
            call cs_vblc
            xor a
            ld [cr_95], a
            call cr_text
            call cr_swing
            call cr_cheer
            call cr_still
            ld b, $3C
            call cs_wait
            xor a
            call cs_fout
            call cs_oclr
            call cr_b942
            ld hl, cr_c6
            inc [hl]
            ld a, [hl]
            cp 20
            jr nz, .p
            ret

section wram, $D400
cs_pal:     ds 32               ; FF3's $7CF7 palettes
cs_tgt:     ds 32               ; $7E77 the fade-in target
cs_tmp:     ds 8
cs_t:       ds 4
cs_cx:      ds 1
cs_cy:      ds 1
cs_cc:      ds 1                ; $CC tint
cs_b6:      ds 1                ; $B6 frame counter
cs_b7:      ds 1                ; $B7 brightness counter
cs_ft:      ds 1                ; $90 fade type
cs_18:      ds 1
cs_19:      ds 1
cs_hook:    ds 1
cs_k:       ds 1
cs_w:       ds 1
cs_n:       ds 1
cs_x:       ds 1
cs_y:       ds 1
cs_p:       ds 2
cs_q:       ds 2
cs_r:       ds 1
cs_c:       ds 1
ep_v:       ds 2                ; the scroll (lines)
ep_next:    ds 1                ; the next row to write
ep_pend:    ds 1
ep_dst:     ds 2
ep_cc:      ds 1
ep_cd:      ds 1
st_cnt:       ds 1                ; $CB stars shown
st_end:     ds 1                ; $7EC2 (the end: stars behind the text)
cs_slow:    ds 1
cs_last:    ds 1
en_src:     ds 2
en_90:      ds 1
en_91:      ds 1
en_9d:      ds 1
en_9e:      ds 1
en_top:     ds 1
en_bot:     ds 1
en_f:       ds 1
en_sx:      ds 1
en_x:       ds 1
en_y:       ds 1
cs_c8:      ds 1
cs_grey:    ds 1
cr_c0:      ds 1
cr_c1:      ds 1
cr_c2:      ds 1
cr_c3:      ds 1
cr_c4:      ds 1
cr_c5:      ds 1
cr_c6:      ds 1
cr_cd:      ds 1
cr_95:      ds 1
cr_ac:      ds 1
cr_id:      ds 1
cr_gp:      ds 3
section wram, $DC00
cr_str:     ds 256
