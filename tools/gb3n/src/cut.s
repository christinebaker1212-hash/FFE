; FF3's cutscenes (NES bank $1F) as native code: the prologue (1F/A326), the epilogue (1F/B146) and
; the ending (1F/B5B6, src/cutend.s). B_CUT $4000-$5FFF holds NES bank $1F as it is (an NES address
; a reads at a - $6000), the code is at $6000; graphics and texts (converted at build time) are in
; B_CUTG (tools/gb3n/cutdata.py).
; The screen keeps FF3's picture through a camera: an NES sprite at (x, y) shows at (x - camx,
; y + 1 - camy); FF3's palettes ($7CF7: 32 NES colours) become the Color's palettes each frame they
; change, with FF3's greyscale / tint bits ($09). The texts are placed for the 20 x 18 screen.
; Memory (the field's map tables, rebuilt when the cutscene ends): $C400 BG map shadow (32 x 32),
; $C800 NES-style sprite list, $C900 sine table, $CA00 random table, $CB00 palettes, $CC00 stars.

C_BG       = $C400          ; BG map shadow (32 x 32; GDMA to $9800 when changed)
C_OAM      = $C800          ; FF3's $0200 (64 x y, tile, attributes, x)
C_SINT     = $C900          ; FF3's $7200 (sine, 10/9A80)
C_RNG      = $CA00          ; FF3's $7BE3 (the cutscene random table, 3F/FC27)
C_PAL      = $CB00          ; FF3's $7CF7 (32 NES colours)
C_PALS     = $CB20          ; FF3's $7E78 (fade target)
C_RGBW     = $CB40          ; NES colour -> RGB555 (64 x 2)
C_CGB      = $CBC0          ; the Color's palettes (BG 0-3, OBJ 0-3)
C_POS      = $CC00          ; FF3's $7300 (sprite block positions)
ST_A       = $CC00          ; FF3's $7575: stars' angle
ST_B       = $CC40          ; $75B5: angle + $40
ST_D       = $CC80          ; $75F5: distance step
ST_S       = $CCC0          ; $7635: speed
ST_C       = $CD00          ; $7675: speed accumulator
ST_L       = $CD40          ; $76B5: brightness
C_TXT      = $CC00          ; the credits' 18 x 14 text box (FF3's $7900 rows)
LCDC_CUT   = $93            ; LCD on, BG tiles $8000, BG map $9800, sprites 8 x 8, BG on

section bank B_CUT, $6000
; ---- the prologue ($DB: 1F/A0A4)
cut_pro:    call c_init
            xor a                           ; 1F/A3CA: palette set 0
            call c_palset
            call c_gfx                      ; 1F/A3CF: cutscene graphics 0-4
            ld a, $14
            call mus_play
            call c_on                       ; 1F/A0AD
            call c_flash
            call c_flash
            call c_flash
            ld a, 2                         ; 1F/A41C: the full crystal
            call c_crys
            ld a, 1
            ld [c_tint], a
            xor a
            call c_fadein
            call c_spark                    ; 1F/A3FB
            xor a
            call c_ptext
            ld a, 1
            call c_ptext
            ld a, $30
            ld [C_PAL + 3], a
            ld a, 1
            call c_fadein
            ld a, $F0
            call c_wait
            ld a, $64
            call c_wait
            ld a, 1
            call c_fadeout
            ld a, 2
            call c_ptext
            ld a, 3
            call c_ptext
            call c_up                       ; 1F/A3AC
            ld a, 9
            ld [c_4b], a
            ld a, 4
            ld [c_4a], a
.t:         ld a, [c_4a]                    ; 1F/A395: texts 4-12 one at a time
            call c_ptext
            ld hl, c_4a
            inc [hl]
            ld a, $30
            ld [C_PAL + 3], a
            ld a, 1
            call c_fadein
            ld a, $EC
            call c_wait
            ld a, 1
            call c_fadeout
            ld hl, c_4b
            dec [hl]
            jr nz, .t
            ld a, $0C                       ; the music fades out
            ld [M_CTRL], a
            ld a, $78
            call c_wait
            xor a
            call c_fadeout
            jp c_deinit

; flash the crystal (1F/A42E)
c_flash:    ld a, $3C
            call c_wait
            xor a                           ; bottom left part
            call c_crys
            call c_fr_oc
            ld a, 3
            call c_wait
            ld a, 1                         ; top right part
            call c_crys
            call c_fr_oc
            ld a, 3
            call c_wait
            call c_oclr
            call c_fr_oc
            ld a, $3C
            jp c_wait

; the crystal sprites: part A (1F/A458: width, height, tiles / attributes, count, x, y, OAM offset)
c_crys:     add a
            add a
            add a
            add low($A4AB - $6000)
            ld l, a
            ld h, high($A4AB - $6000)
            ld a, [hl+]
            ld [c_8c], a                    ; width
            ld a, [hl+]
            ld [c_8d], a                    ; height
            push hl
            call c_ipos                     ; 1F/A23A
            pop hl
            ld a, [hl+]                     ; tile / attribute pointers (1F/A4C3 / A4C9)
            ld e, a
            ld d, 0
            push hl
            ld hl, $A4C3 - $6000
            add hl, de
            ld a, [hl+]
            ld [c_7e], a
            ld a, [hl]
            ld [c_7f], a
            ld hl, $A4C9 - $6000
            add hl, de
            ld a, [hl+]
            ld [c_86], a
            ld a, [hl]
            ld [c_87], a
            pop hl
            ld a, [hl+]
            ld [c_82], a                    ; attributes
            ld a, [hl+]
            ld [c_80], a                    ; count
            ld a, [hl+]
            ld [c_8c], a                    ; x
            ld a, [hl+]
            ld [c_8d], a                    ; y
            ld a, [hl]
            ld [c_c8], a                    ; OAM offset
            jp c_blk

; positions of a w x h block of sprites ($7300: y, -, -, x per sprite) (1F/A23A)
c_ipos:     ld hl, C_POS
            ld b, 0
            ld a, $F0
.c:         ld [hl+], a
            dec b
            jr nz, .c
            ld hl, C_POS
            ld d, 0                         ; y
            ld a, [c_8d]
            ld c, a
.y:         ld a, [c_8c]
            ld b, a
            ld e, 0                         ; x
.x:         ld a, d
            ld [hl+], a
            inc hl
            inc hl
            ld a, e
            ld [hl+], a
            ld a, e
            add 8
            ld e, a
            dec b
            jr nz, .x
            ld a, d
            add 8
            ld d, a
            dec c
            jr nz, .y
            ret

; a block of sprites into the sprite list (1F/A1F5): positions + ($8C, $8D), tiles at [$7E],
; attributes at [$86]
c_blk:      ld a, [c_c8]
            ld e, a
            ld d, high(C_OAM)
            ld hl, C_POS
            ld a, [c_80]
            ld b, a
.p:         ld a, [c_8d]
            add [hl]
            ld [de], a
            inc hl
            inc hl
            inc hl
            inc e
            inc e
            ld a, [c_82]
            ld [de], a
            inc e
            ld a, [c_8c]
            add [hl]
            ld [de], a
            inc hl
            inc e
            dec b
            jr nz, .p
            ld a, [c_c8]
            ld e, a
            ld a, [c_80]
            ld b, a
            ld a, [c_7f]                    ; (the NES addresses: - $6000 here)
            sub $60
            ld [c_7f], a
            ld a, [c_87]
            sub $60
            ld [c_87], a
.t:         ld a, [c_7e]
            ld l, a
            ld a, [c_7f]
            ld h, a
            ld a, [hl+]
            inc e
            ld [de], a
            ld a, l
            ld [c_7e], a
            ld a, h
            ld [c_7f], a
            ld a, [c_86]
            ld l, a
            ld a, [c_87]
            ld h, a
            ld a, [hl+]
            inc e
            ld [de], a
            ld a, l
            ld [c_86], a
            ld a, h
            ld [c_87], a
            inc e
            inc e
            dec b
            jr nz, .t
            ld a, e
            ld [c_c8], a
            ret

; the sparkle (1F/A3FB): 64 frames, a sprite every 4
c_spark:    xor a
            ld [c_cnt], a
.l:         call c_fr
            ld a, [c_cnt]
            and $1C
            add low($A3DB - $6000)
            ld l, a
            ld h, high($A3DB - $6000)
            ld de, C_OAM
            ld b, 4
.c:         ld a, [hl+]
            ld [de], a
            inc e
            dec b
            jr nz, .c
            ld hl, c_cnt
            inc [hl]
            bit 6, [hl]
            jr z, .l
            ret

; the crystal up 48 lines (1F/A3AC)
c_up:       ld b, $30
.f:         push bc
            call c_fr
            ld hl, C_OAM + 8
.s:         dec [hl]
            ld a, l
            add 4
            ld l, a
            cp $78                          ; ($0208 + X for X < $70)
            jr nz, .s
            pop bc
            dec b
            jr nz, .f
            jp c_fr

; a prologue text (1F/A52D): the text's colour black, a frame, then its rows into the map
c_ptext:    push af
            ld a, $0F
            ld [C_PAL + 3], a
            call c_fr_oc
            pop af
            ld hl, C_PRO
            call c_page                     ; (SCRATCH: r0, r1, lines)
            ld hl, SCRATCH
            ld a, [hl+]
            ld c, a                         ; rows r0 - r1: $FF
            ld a, [hl+]
            sub c
            inc a
            ld b, a
            push hl
.r:         ld a, c
            call c_rowp
            ld e, 20
            ld a, $FF
.f:         ld [hl+], a
            dec e
            jr nz, .f
            inc c
            dec b
            jr nz, .r
            pop hl
            call c_lines
            ld a, 1
            ld [c_bgd], a
            ret
; page A of the table at HL (B_CUTG) -> SCRATCH (256 bytes)
c_page:     add a
            ld e, a
            ld d, 0
            add hl, de
            push hl
            ld a, B_CUTG
            call far_byte
            ld e, a
            pop hl
            inc hl
            ld a, B_CUTG
            call far_byte
            ld h, a
            ld l, e
            ld de, SCRATCH
            ld bc, 256
            ld a, B_CUTG
            jp far_copy
; lines at HL (row, column, count, tiles; $FF ends) into the map
c_lines:    ld a, [hl+]
            cp $FF
            ret z
            push hl
            call c_rowp
            ld d, h
            ld e, l
            pop hl
            ld a, [hl+]
            add e
            ld e, a
            jr nc, .c
            inc d
.c:         ld a, [hl+]
            ld b, a
.t:         ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .t
            jr c_lines
; HL = the map row A (C_BG + 32 x (A & 31))
c_rowp:     push de
            and 31
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, C_BG
            add hl, de
            pop de
            ret

; ---- frames
c_fr_oc:    ld a, 1                         ; FF3's F8B0: sprites and colours
            jr c_frx
c_fr:       xor a                           ; F8C5: sprites only
c_frx:      ld [c_pup], a
            call c_obj
            ld a, [c_pup]
            and a
            call nz, c_pcalc
            call wait_vbl
            call hram_dma
            ld a, [c_bgd]
            and a
            jr z, .nb
            xor a
            ld [c_bgd], a
            ldh [rVBK], a
            ld a, high(C_BG)
            ldh [rHDMA1], a
            xor a
            ldh [rHDMA2], a
            ld a, $98
            ldh [rHDMA3], a
            xor a
            ldh [rHDMA4], a
            ld a, 63
            ldh [rHDMA5], a
.nb:        ld a, [c_pup]
            and a
            call nz, c_pload
            ld a, [c_bgcx]
            ld b, a
            ld a, [c_scx]
            add b
            ldh [rSCX], a
            ld a, [c_bgcy]
            ld b, a
            ld a, [c_scy]
            add b
            ldh [rSCY], a
            ld a, [c_split]
            and a
            jr z, .ns
            ld a, $40                       ; (the ending's band: the blank map $9C00 above line
            ldh [rSTAT], a                  ;   c_top and from line c_bot: stat_isr switches)
            ld a, [c_bot]
            ld [c_lyb], a
            ld a, [c_top]
            and a
            jr z, .t0
            ldh [rLYC], a
            ld a, LCDC_CUT | $08
            jr .lc
.t0:        ld a, [c_bot]
            ldh [rLYC], a
            ld a, $FF
            ld [c_lyb], a
            ld a, LCDC_CUT
.lc:        ldh [rLCDC], a
            jr .sn
.ns:        xor a
            ldh [rSTAT], a
            ld a, LCDC_CUT
            ldh [rLCDC], a
.sn:        call snd_frame
            jp read_pad
; A frames (F8C5 each: 1F/A1EE)
c_wait:     push af
            call c_fr
            pop af
            dec a
            jr nz, c_wait
            ret

; ---- FF3's sprite list -> the Color's OAM through the camera (40 at most)
c_obj:      ld hl, C_OAM
            ld de, oam_buf
            ld b, 64
.l:         ld a, [hl+]                     ; y: hidden from $EF
            cp $EF
            jr nc, .n3
            add 17
            push hl
            ld hl, c_camy
            sub [hl]
            pop hl
            jr c, .n3
            jr z, .n3
            cp 160
            jr nc, .n3
            ld [c_gy], a
            inc hl                          ; x
            inc hl
            ld a, [hl]
            push hl
            ld hl, c_camx
            sub [hl]
            pop hl
            jr nc, .xp
            cp $F9
            jr c, .n0
            jr .xo
.xp:        cp 160
            jr nc, .n0
.xo:        add 8
            ld [c_gx], a
            ld a, [c_gy]                    ; y, x, tile, attributes
            ld [de], a
            inc e
            ld a, [c_gx]
            ld [de], a
            inc e
            dec hl
            dec hl
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld c, a
            and 3
            or $08
            bit 7, c
            jr z, .v
            or $40
.v:         bit 6, c
            jr z, .h
            or $20
.h:         bit 5, c
            jr z, .p
            or $80
.p:         ld [de], a
            inc e
            inc hl
            ld a, e
            cp 160
            jr z, .full
            dec b
            jr nz, .l
            jr .full
.n3:        inc hl
            inc hl
.n0:        inc hl
            dec b
            jr nz, .l
.full:      ld a, e                         ; the rest hidden
            cp 160
            ret nc
            xor a
.z:         ld [de], a
            inc e
            ld a, e
            cp 160
            ret nc
            xor a
            jr .z

; ---- FF3's colours -> the Color's palettes (rendering off: black; $09 bit 0 greyscale, bits
; 5-7 the tint)
c_pcalc:    ld de, C_CGB
            ld b, 0                         ; BG palettes 0-3 (colour 0: the backdrop $7CF7)
.bg:        ld a, b
            and 3
            jr nz, .b1
            ld a, [C_PAL]
            jr .b2
.b1:        ld a, b
            ld hl, C_PAL
            add l
            ld l, a
            ld a, [hl]
.b2:        call c_rgb
            inc b
            ld a, b
            cp 16
            jr nz, .bg
.ob:        ld a, b                         ; OBJ palettes 0-3
            ld hl, C_PAL
            add l
            ld l, a
            ld a, [hl]
            call c_rgb
            inc b
            ld a, b
            cp 32
            jr nz, .ob
            ret
; NES colour A -> [DE] (2 bytes)
c_rgb:      push bc
            ld c, a
            ld a, [c_mask]
            and $18
            jr z, .blk
            ld a, [c_mask]
            rra
            ld a, c
            jr nc, .ng
            and $30
.ng:        and $3F
            add a
            ld l, a
            ld h, high(C_RGBW)
            ld a, l
            add low(C_RGBW)
            ld l, a
            ld a, [hl+]
            ld c, a
            ld b, [hl]
            ld a, [c_mask]
            and $E0
            jr z, .st
            ld h, b                         ; the tint: each channel x 3/4
            ld l, c
            srl h
            rr l
            srl h
            rr l
            ld a, l
            and $E7
            ld l, a
            ld a, h
            and $1C
            ld h, a
            ld a, c
            sub l
            ld c, a
            ld a, b
            sbc h
            ld b, a
.st:        ld a, c
            ld [de], a
            inc de
            ld a, b
            ld [de], a
            inc de
            pop bc
            ret
.blk:       xor a
            ld [de], a
            inc de
            ld [de], a
            inc de
            pop bc
            ret
c_pload:    ld hl, C_CGB                    ; (V-Blank)
            ld a, $80
            ldh [rBCPS], a
            ld b, 32
.b:         ld a, [hl+]
            ldh [rBCPD], a
            dec b
            jr nz, .b
            ld a, $80
            ldh [rOCPS], a
            ld b, 32
.o:         ld a, [hl+]
            ldh [rOCPD], a
            dec b
            jr nz, .o
            ret

; ---- palettes (1F/B340): set A's eight palettes from 1F/B284
c_palset:   add a
            add a
            add a
            add low($B300 - $6000)
            ld l, a
            ld h, high($B300 - $6000)
            ld de, C_PAL
            ld b, 8
.p:         ld a, [hl+]
            push hl
            add a
            add a
            add low($B284 - $6000)
            ld l, a
            ld a, high($B284 - $6000)
            adc 0
            ld h, a
            ld c, 4
.c:         ld a, [hl+]
            ld [de], a
            inc de
            dec c
            jr nz, .c
            pop hl
            dec b
            jr nz, .p
            ret

; fade out (3F/FA87): A = 0 all, 1 BG, 2 sprites: each colour one step darker ($0x: black)
c_fade1:    add a
            add low(c_ftab)
            ld l, a
            ld h, high(c_ftab)
            jr nc, .h
            inc h
.h:         ld a, [hl+]
            ld c, [hl]
            ld hl, C_PAL
            add l
            ld l, a
.l:         ld a, [hl]
            cp $0F
            jr z, .n
            ld b, a
            and $30
            jr nz, .d
            ld a, $0F
            jr .s
.d:         sub $10
            ld e, a
            ld a, b
            and $0F
            or e
.s:         ld [hl], a
.n:         inc l
            ld a, l
            sub low(C_PAL)
            cp c
            jr nz, .l
            ret
c_ftab:     db $00, $20, $00, $10, $10, $20

; decrease brightness (1F/A0C7): every other call the tint instead when [$CC] is set
c_dec:      push af
            ld hl, c_bri
            inc [hl]
            ld a, [hl]
            and 1
            jr nz, .f
            ld a, [c_tint]
            and a
            jr z, .f
            ld a, [c_mask]
            or $E0
            ld [c_mask], a
            pop af
            ret
.f:         ld a, [c_mask]
            and $1F
            ld [c_mask], a
            pop af
            jp c_fade1

; fade out (1F/A0E8): a step every 8 frames for 80 frames
c_fadeout:  ld [c_90], a
            xor a
            ld [c_bri], a
            ld [c_cnt], a
.l:         call c_fr_oc
            ld a, [c_cnt]
            and 7
            jr nz, .n
            ld a, [c_90]
            call c_dec
.n:         ld hl, c_cnt
            inc [hl]
            ld a, [hl]
            cp $50
            jr nz, .l
            xor a
            ld [c_tint], a
            ret

; fade in (1F/A10A): from black to the palettes in 112 frames
c_fadein:   ld [c_90], a
            ld hl, C_PAL
            ld de, C_PALS
            ld b, 32
.cp:        ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .cp
            xor a
            ld [c_cnt], a
            ld a, [c_90]                    ; (1F/A1BC: the faded range black)
            add a
            add low(c_ftab)
            ld l, a
            ld h, high(c_ftab)
            jr nc, .h
            inc h
.h:         ld a, [hl+]
            ld c, [hl]
            ld b, a
            ld hl, C_PAL
            add l
            ld l, a
.k:         ld a, $0F
            ld [hl+], a
            inc b
            ld a, b
            cp c
            jr nz, .k
            ld a, $0D
            ld [c_18], a
.l:         call c_fr_oc
            ld a, [c_cnt]
            and 7
            jr nz, .n
            ld hl, C_PALS
            ld de, C_PAL
            ld b, 32
.rs:        ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .rs
            xor a
            ld [c_bri], a
            ld a, [c_18]
            and a
            jr z, .n
            ld [c_19], a
.d:         ld a, [c_90]
            call c_dec
            ld hl, c_19
            dec [hl]
            jr nz, .d
            ld hl, c_18
            dec [hl]
.n:         ld hl, c_cnt
            inc [hl]
            ld a, [hl]
            cp $70
            jr nz, .l
            xor a
            ld [c_tint], a
            ret

; ---- start / end
c_init:     call wait_vbl
            call pal_black
            call c_oclr
            call c_obj
            call hram_dma
            call c_gon
            ld hl, c_vars
            ld de, c_vend - c_vars
            call memclr
            ld a, 48
            ld [c_camx], a
            ld [c_camy], a
            xor a
            ldh [rSCX], a
            ldh [rSCY], a
            ld a, LCDC_CUT
            ldh [rLCDC], a
            ld a, 1                         ; VRAM bank 1: sprite tiles and the BG attributes
            ldh [rVBK], a
            ld hl, $8000
            ld de, $1000
            call memclr
            ld hl, $9800
            ld de, $0800
            call memclr
            xor a
            ldh [rVBK], a
            ld hl, $8000
            ld de, $2000
            call memclr
            ld hl, C_SIN                    ; the sine and colour tables into work RAM
            ld de, C_SINT
            ld bc, 256
            ld a, B_CUTG
            call far_copy
            ld hl, C_RGB
            ld de, C_RGBW
            ld bc, 128
            ld a, B_CUTG
            call far_copy
            ld hl, BZ                       ; FF3's random table (3F/FC27; seed: a sum, as FF3's
            xor a                           ;   zero page sum)
            ld b, a
.sum:       add [hl]
            inc l
            dec b
            jr nz, .sum
            ld [bs_seed], a
            ld a, 2
            ldh [rSVBK], a
            %FAR B_BAT2, fe_FC27s
            ld hl, RNG_TAB
            ld de, C_RNG
            ld bc, 256
            call memcpy
            ld a, 1
            ldh [rSVBK], a
            ld hl, C_BG
            ld de, $400
            call memclr
            jp c_goff
; the screen on (1F/A0AD)
c_on:       ld a, $1E
            ld [c_mask], a
            ret
c_oclr:     ld hl, C_OAM
            ld b, 0
            ld a, $F0
.c:         ld [hl+], a
            dec b
            jr nz, .c
            ret
; graphics loads behind the line guard (screen black meanwhile or not: the guard keeps VRAM
; writes in H-Blank / V-Blank): HL = source (B_CUTG), DE = destination, BC = bytes, A = VRAM bank
c_load:     push af
            call c_gon
            pop af
            ldh [rVBK], a
            ld a, B_CUTG
            call far_copy
            xor a
            ldh [rVBK], a
            jp c_goff
; cutscene graphics 0-4 (1F/A3CF): the text tiles (BG $70-$FF), the cutscene fonts (BG $60 /
; $18), the prologue's sprites (OBJ $00)
c_gfx:      ld hl, CG_TXT
            ld de, $8700
            ld bc, $900
            xor a
            call c_load
            ld hl, CG_FONT1
            ld de, $8600
            ld bc, $1A * 16
            xor a
            call c_load
            ld hl, CG_FONT2
            ld de, $8180
            ld bc, $0A * 16
            xor a
            call c_load
            ld hl, CG_PSPR
            ld de, $8000
            ld bc, $50 * 16
            ld a, 1
            jp c_load
; the end: black, the sprite tiles the field keeps blank (VRAM bank 1 tile 1) cleared, the window
; map again; the caller reloads the map
c_deinit:   call wait_vbl
            call pal_black
            xor a
            ld [c_split], a
            ldh [rSTAT], a
            ldh [rSCX], a
            ldh [rSCY], a
            call c_oclr
            call c_obj
            call hram_dma
            call c_gon
            ld a, 1
            ldh [rVBK], a
            ld hl, $8000
            ld de, $1000
            call memclr
            xor a
            ldh [rVBK], a
            ld hl, $9C00
            ld de, $400
            call memclr
            ld a, LCDC_ON
            ldh [rLCDC], a
            %FAR B_FIELD, win_init
            jp c_goff
; VRAM writes from here behind the line guard (a mode-2 interrupt holds the CPU until H-Blank),
; the first one in H-Blank / V-Blank too
c_gon:      ld a, 1
            ld [guard_on], a
            ldh [snd_isr], a
            ld a, $20
            ldh [rSTAT], a
.w:         ldh a, [rSTAT]
            and 3
            cp 2
            jr nc, .w
            ret
c_goff:     xor a
            ldh [snd_isr], a
            ldh [rSTAT], a
            ld [guard_on], a
            ret

; ---- the epilogue ($DC: 1F/B146)
cut_epi:    call c_init
            ld a, 6
            call c_palset
            call c_gfx
            call c_stgfx                    ; 1F/B12D
            ld a, $3C
            call mus_play
            call c_on
            call c_fr_oc
            call c_stinit                   ; 1F/B3EA
            call c_fr_oc
            call c_sobj
            xor a
            ld [c_tint], a
            ld [c_7ec2], a
            call c_fadein
            ld a, 17                        ; (the screen's rows are blank: rows below come in
            ld [c_vdone], a                 ;   as it scrolls)
            xor a
            ld [c_98], a
.pg:        call c_fr_oc
            call c_sobj
            call c_stmove
            ld a, 6                         ; 1F/B212: FF3 copies the page in 6 frames
            call c_sfr
            call c_escroll                  ; 1F/B1E7: 240 lines up
            ld a, [c_98]
            cp 5
            jr z, .last
            ld a, $64
            call c_sfr
.last:      ld hl, c_98
            inc [hl]
            ld a, [hl]
            cp 6
            jr nz, .pg
            ld a, 1                         ; the stars faster and gone (1F/B199)
            ld [c_tint], a
            xor a
            ld [c_cd], a
.f:         call c_fr_oc
            call c_sobj
            ld b, 2                         ; 1F/B406: the angles + 2
            ld hl, ST_A
.ag:        ld a, [hl]
            add b
            ld [hl+], a
            ld a, l
            cp low(ST_A) + 64
            jr nz, .ag
            ld hl, ST_B
.bg:        ld a, [hl]
            add b
            ld [hl+], a
            ld a, l
            cp low(ST_B) + 64
            jr nz, .bg
            ld a, [c_tint]
            ld [c_88], a
.mv:        call c_stmove
            ld hl, c_88
            dec [hl]
            jr nz, .mv
            ld a, [c_tint]
            cp 8
            jr z, .cb
            ld a, [c_cd]
            sub 8
            ld [c_cd], a
            jr nz, .f
            ld hl, c_tint
            inc [hl]
            ld a, [hl]
            cp 8
            jr nz, .f
.cb:        ld hl, c_cb
            dec [hl]
            jr nz, .f
            xor a
            ld [c_tint], a
            jp c_deinit
; A frames with the stars (1F/B1D6)
c_sfr:      push af
            call c_fr_oc
            call c_sobj
            call c_stmove
            pop af
            dec a
            jr nz, c_sfr
            ret
; the page scrolls in: 240 frames (no colour update), the rows coming in drawn as they come
c_escroll:  xor a
            ld [c_s], a
.l:         call c_ecatch
            call c_fr
            call c_sobj
            call c_stmove
            ld hl, c_vy                     ; the screen's top line (Y), SCY = Y mod 256
            inc [hl]
            jr nz, .n
            inc hl
            inc [hl]
.n:         ld a, [c_vy]
            ld [c_scy], a
            ld hl, c_s
            inc [hl]
            ld a, [hl]
            cp $F0
            jr nz, .l
            jp c_fr_oc
; rows reaching the screen's bottom: a page's line or blank (virtual row v: page v / 30 - 1,
; its lines from row 30 (k + 1) + (18 - h) / 2)
c_ecatch:   ld a, [c_vy]                    ; vb = (Y + 143) / 8
            add 143
            ld l, a
            ld a, [c_vy + 1]
            adc 0
            ld h, a
            srl h
            rr l
            srl h
            rr l
            srl h
            rr l
            ld a, [c_vdone]
            cp l
            ret nc
            inc a
            ld [c_vdone], a
            call c_erow
            jr c_ecatch
c_erow:     ld [c_v], a
            call c_rowp                     ; the row blank first
            ld b, 32
            xor a
.c:         ld [hl+], a
            dec b
            jr nz, .c
            ld a, 1
            ld [c_bgd], a
            ld a, [c_v]                     ; k = v / 30, r = v mod 30
            ld b, 0
.dv:        cp 30
            jr c, .dd
            sub 30
            inc b
            jr .dv
.dd:        ld c, a                         ; (C = r)
            ld a, b
            and a
            ret z
            dec a
            cp 6
            ret nc
            push bc
            ld hl, C_EPI
            call c_page
            pop bc
            ld a, [SCRATCH]                 ; h, top = (18 - h) / 2
            ld d, a
            ld a, 18
            sub d
            srl a
            ld e, a
            ld a, c
            sub e
            ret c
            cp d
            ret nc
            ld c, a                         ; line row C
            ld hl, SCRATCH + 1
.f:         ld a, [hl+]
            cp $FF
            ret z
            cp c
            jr z, .w
            inc hl
            ld a, [hl+]
            add l
            ld l, a
            jr nc, .f
            inc h
            jr .f
.w:         ld a, [hl+]                     ; column, count, tiles
            ld e, a
            ld a, [hl+]
            ld b, a
            push hl
            ld a, [c_v]
            call c_rowp
            ld a, l
            add e
            ld l, a
            ld d, h
            ld e, l
            pop hl
.t:         ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .t
            ret

; the star graphics (1F/B12D: cutscene graphics 5 at OBJ $01) and the text colour
c_stgfx:    ld hl, CG_STAR
            ld de, $8010
            ld bc, $40
            ld a, 1
            call c_load
            ld a, $30
            ld [C_PAL + 3], a
            ret
; the stars at the centre, their angles, the distance steps (1F/B3EA, 1F/B476)
c_stinit:   ld hl, ST_A
            ld b, 64
.a:         xor a
            ld [hl+], a
            dec b
            jr nz, .a
            ld hl, ST_B
            ld b, 64
.b:         ld a, $40
            ld [hl+], a
            dec b
            jr nz, .b
            ld hl, ST_D
            ld b, 64
.d:         ld a, 1
            ld [hl+], a
            dec b
            jr nz, .d
            ld hl, ST_S
            ld b, 64
.s:         ld a, $FF
            ld [hl+], a
            dec b
            jr nz, .s
            ld a, $3F
            ld [c_cb], a
            jp c_stmove
; the stars move (1F/B413)
c_stmove:   ld c, 0
.l:         ld b, 0
            ld hl, ST_C
            add hl, bc
            ld a, [hl]
            ld d, h
            ld e, l
            ld hl, ST_S
            add hl, bc
            add [hl]
            ld [de], a
            jr nc, .n
            ld hl, ST_L
            add hl, bc
            inc [hl]
            ld hl, ST_D
            add hl, bc
            ld a, [hl]
            dec a
            and $7F
            ld [hl], a
            jr nz, .n
            ld a, [c_bri]                   ; a new star: speed by $B7, angle from the table
            ld e, a
            inc a
            ld [c_bri], a
            ld a, e
            and $0F
            ld e, a
            ld d, 0
            push hl
            ld hl, $B4FA - $6000
            add hl, de
            ld a, [hl]
            pop hl
            ld [hl], a
            push hl
            ld hl, $B50A - $6000
            add hl, de
            ld a, [hl]
            ld hl, ST_S
            add hl, bc
            ld [hl], a
            ld hl, ST_L
            add hl, bc
            ld [hl], 0
            ld hl, c_cnt
            inc [hl]
            ld e, [hl]
            ld hl, C_RNG
            add hl, de
            ld a, [hl]
            ld hl, ST_A
            add hl, bc
            ld [hl], a
            add $40
            ld hl, ST_B
            add hl, bc
            ld [hl], a
            pop hl
.n:         inc c
            ld a, c
            cp $3F
            jr nz, .l
            ret
; the stars into the sprite list (1F/B39F)
c_sobj:     call c_oclr
            ld de, C_OAM
            ld c, 0
.s:         ld a, [c_cb]
            cp c
            ret z
            ld hl, ST_B                     ; x: the angle + $40
            call c_spos
            push af
            ld hl, ST_A                     ; y
            call c_spos
            add $78
            ld [de], a
            inc e
            ld b, 0                         ; the tile by brightness (1F/B370)
            ld hl, ST_L
            add hl, bc
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
            ld a, c                         ; attributes (1F/B38B): palette 2, every 16th 0
            and $0F
            jr z, .p0
            ld a, 2
.p0:        ld b, a
            ld a, [c_7ec2]
            and a
            ld a, b
            jr z, .pa
            or $20
.pa:        ld [de], a
            inc e
            pop af
            add $80
            ld [de], a
            inc e
            inc c
            jr .s
; a star's offset (1F/B4A1): the sine of [HL + C] x the radius (1F/B51A by distance, / 2)
c_spos:     ld b, 0
            add hl, bc
            ld a, [hl]
            ld l, a
            ld h, high(C_SINT)
            ld a, [hl]
            push af
            ld hl, ST_D
            add hl, bc
            ld a, [hl]
            add low($B51A - $6000)
            ld l, a
            ld a, high($B51A - $6000)
            adc 0
            ld h, a
            ld a, [hl]
            srl a
            ld b, a                         ; radius
            pop af
            bit 7, a
            jr z, .p
            cpl
            call c_mul
            cpl
            inc a
            ret
.p:         jp c_mul
; (A x 2) x B / 256 (1F/B4E1)
c_mul:      push de
            push hl
            push bc
            add a
            ld e, a
            ld d, 0
            ld h, d
            ld l, d
            ld a, b
            ld b, 8
.m:         add hl, hl
            rla
            jr nc, .s
            add hl, de
.s:         dec b
            jr nz, .m
            ld a, h
            pop bc
            pop hl
            pop de
            ret

