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
            call cs_palc
            ld a, [cs_cx]
            ldh [scx], a
            ldh [rSCX], a
            ld a, [cs_cy]
            ldh [scy], a
            ldh [rSCY], a
            ret
; 1F/A0AD screen on
cs_on:      ld a, LCDC_ON
            ldh [rLCDC], a
            ld a, 1
            ld [lcd_is], a
            ret
; the scene's end: the screen black (on: the map is loaded behind it), the field's WRAM bank
cs_end:     call pal_black
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
            jp vcopyx
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
            and $3F
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
            jp wait_vbl
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

cut_epi:    ret
cut_end:    ret

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
