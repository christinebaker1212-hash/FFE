; FF3's ending (1F/B5B6) and end credits (1F/B94A) as native code (see src/cut.s). The camera is
; (48, 48) for the scene, its sprites and the credits; the credits' 18 x 14 text box (NES columns
; 7-24, rows 8-21) shows at GB columns 1-18, rows 2-15.

; ---- the ending ($DD: 1F/A012)
cut_end:    call c_init
            call c_egfx                     ; 1F/B7B0
            ld a, 3
            call c_palset
            ld a, 4                         ; the music stops
            ld [M_CTRL], a
            call c_on
            ld a, 48
            ld [c_bgcx], a
            ld [c_bgcy], a
            ld a, 2                         ; the scene opens from the middle (two line splits:
            ld [c_90], a                    ;   lines $03 to $03 + $90 show it)
            ld a, $78
            ld [c_03], a
            ld a, 1
            ld [c_split], a
.w:         call c_band
            call c_fr_oc
            ld hl, c_90
            inc [hl]
            inc [hl]
            ld hl, c_03
            dec [hl]
            ld a, [hl]
            cp 8
            jr nz, .w
            xor a
            ld [c_split], a
            ld [c_cnt], a                   ; 1F/B607
            ld [c_bri], a
            ld [c_91], a
            ld a, $F6
            ld [c_9e], a
            ld a, $58
            ld [c_9d], a
.sc:        call c_newfr                    ; 1F/B616
            call c_evts
            ld b, 0
.ob:        push bc                         ; the four objects drifting left (1F/B783)
            ld a, b
            add a
            add a
            add low($B7A0 - $6000)
            ld l, a
            ld a, high($B7A0 - $6000)
            adc 0
            ld h, a
            ld a, [c_90]
            add [hl]
            ld [c_8c], a
            inc hl
            ld a, [hl+]
            ld [c_8d], a
            inc hl
            ld a, [hl]
            call c_def
            pop bc
            inc b
            ld a, b
            cp 4
            jr nz, .ob
            ld hl, c_cnt
            inc [hl]
            jr nz, .n
            ld hl, c_bri
            inc [hl]
.n:         ld a, [c_cnt]
            and 7
            jr nz, .m
            ld hl, c_90
            dec [hl]
.m:         ld a, [c_bri]
            cp $0C
            jr nz, .sc
            xor a                           ; 1F/B63A: the crystal fades, the sprites stay lit
            ld [c_cnt], a
.f:         call c_newfr
            call c_crys2
            ld a, [c_cnt]
            and 7
            jr nz, .fn
            xor a
            call c_fade1
            ld hl, $B6AE - $6000
            ld de, C_PAL + $10
            ld b, 8
.fc:        ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .fc
.fn:        ld hl, c_cnt
            inc [hl]
            bit 5, [hl]
            jr z, .f
            call c_newfr                    ; 1F/B662: the flash
            xor a
            ld [c_cnt], a
            ld a, $3C
            ld [c_90], a
.fl:        call c_fr_oc
            ld a, [c_cnt]                   ; (1F/B680: black / grey every 4 frames)
            and 4
            add a
            add low($B69E - $6000)
            ld l, a
            ld h, high($B69E - $6000)
            ld de, C_PAL
            ld b, 8
.fp:        ld a, [hl+]
            ld [de], a
            push hl
            ld hl, 8
            add hl, de
            ld [hl], a
            ld hl, 16
            add hl, de
            ld [hl], a
            ld hl, 24
            add hl, de
            ld [hl], a
            pop hl
            inc de
            dec b
            jr nz, .fp
            ld hl, c_cnt
            inc [hl]
            ld hl, c_90
            dec [hl]
            jr nz, .fl
            ld a, $1E
            call c_wait
            jp c_cred

; the band's lines on the GB (NES line - 48)
c_band:     ld a, [c_03]
            sub 48
            jr nc, .t
            xor a
.t:         ld [c_top], a
            ld a, [c_03]
            ld b, a
            ld a, [c_90]
            add b
            jr c, .off
            sub 48
            jr c, .z
            cp 144
            jr c, .b
.off:       ld a, $FF
.b:         ld [c_bot], a
            ret
.z:         xor a
            jr .b

; a frame with the sprite list cleared after (1F/B5AB)
c_newfr:    call c_fr_oc
            call c_oclr
            xor a
            ld [c_c8], a
            ret

; the scene's events by time ($B7: 256-frame steps; 1F/B6D1)
c_evts:     ld a, [c_91]
            and a
            jr z, .a
            call c_crys2
            ld a, [c_bri]
            cp 5
            ld a, [c_mask]
            jr nc, .g0
            xor 1                           ; (greyscale every other frame)
            jr .g1
.g0:        and $FE
.g1:        ld [c_mask], a
.a:         ld a, [c_bri]
            cp 6
            jr z, .inv
            cp 7
            jr nz, .b2
            ld a, [c_cnt]
            and a
            jr nz, .inv
            ld a, $FF
            ld [M_SFX], a
            ld a, $3B
            call mus_play
.inv:       ld a, [c_cnt]                   ; the Invincible flies off (up and left)
            push af
            and 1
            jr z, .x
            ld hl, c_9e
            dec [hl]
.x:         ld a, [c_9e]
            ld [c_8c], a
            pop af
            and 7
            jr nz, .y
            ld hl, c_9d
            dec [hl]
.y:         ld a, [c_9d]
            ld [c_8d], a
            ld a, [c_cnt]
            and 8
            rrca
            rrca
            rrca
            add 9
            call c_def
.b2:        ld a, [c_bri]
            cp 2
            jr nz, .b3
            ld a, [c_cnt]                   ; (1F/B6C8: the scene shakes)
            and 3
            ld [c_scx], a
.b3:        ld a, [c_bri]
            cp 3
            jr nz, .b4
            ld a, [c_cnt]
            bit 7, a
            jr nz, .p
            ld a, $30
            ld [c_8c], a
            ld [c_8d], a
            ld a, [c_91]
            and a
            ret nz
            ld a, [c_cnt]
            and $38
            rrca
            rrca
            rrca
            add 2
            cp 7
            jr nz, .d
            ld hl, c_91
            inc [hl]
.d:         jp c_def
.p:         cp $80
            jr nz, .p2
            ld a, 1
            jp c_pfade
.p2:        cp $C0
            ret nz
            xor a
            jp c_pfade
.b4:        cp 4
            ret nz
            ld a, [c_cnt]
            cp $80
            ret nz
            ld a, 2
            jp c_palset
; palette set 1, then A steps darker (1F/B596)
c_pfade:    push af
            ld a, 1
            call c_palset
            pop af
            and a
            ret z
.l:         push af
            xor a
            call c_fade1
            pop af
            dec a
            jr nz, .l
            ret
; the crystal's glow at ($30, $30) (1F/B6B6)
c_crys2:    ld a, $30
            ld [c_8c], a
            ld [c_8d], a
            ld a, [c_cnt]
            and 4
            rrca
            rrca
            add 7
            ; fall through
; sprite group A (1F/B7C9: y, tile, attributes, x per sprite from 1F/B805; $FF ends) at ($8C, $8D)
c_def:      add a
            add low($B805 - $6000)
            ld l, a
            ld a, high($B805 - $6000)
            adc 0
            ld h, a
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld a, h
            sub $60
            ld h, a
            ld a, [c_c8]
            ld e, a
            ld d, high(C_OAM)
.l:         ld a, [hl+]
            cp $FF
            jr z, .e
            ld b, a
            ld a, [c_8d]
            add b
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [c_8c]
            add [hl]
            inc hl
            ld [de], a
            inc e
            jr .l
.e:         ld a, e
            ld [c_c8], a
            ret

; the ending's graphics: BG tiles, sprites, the scene's map and colours (1F/B7B0)
c_egfx:     ld hl, CG_EBG
            ld de, $8000
            ld bc, CG_EBG_N * 16
            xor a
            call c_load
            ld hl, CG_ESPR
            ld de, $8000
            ld bc, $30 * 16
            ld a, 1
            call c_load
            ld hl, C_EMAP
            ld de, C_BG
            ld bc, 32 * 30
            ld a, B_CUTG
            call far_copy
            ld hl, C_EATR
            ld de, $9800
            ld bc, 32 * 30
            ld a, 1
            call c_load
            ld a, 1
            ld [c_bgd], a
            ret

; ---- the end credits (1F/B94A)
c_cred:     ld a, 1
            ld [c_tint], a
            xor a
            ld [c_scx], a
            ld [c_bgcx], a
            ld [c_bgcy], a
            ld hl, C_BG                     ; (the credits' screen: blank, tiles 0-3 cleared)
            ld de, $400
            call memclr
            ld a, 1
            ld [c_bgd], a
            call c_gon
            xor a
            ldh [rVBK], a
            ld hl, $8000
            ld de, $40
            call memclr
            call c_goff
            ld hl, CG_TXT
            ld de, $8700
            ld bc, $900
            xor a
            call c_load
            ld hl, CG_EFONT
            ld de, $80D0
            ld bc, $1C * 16
            xor a
            call c_load
            xor a
            ld [c_cnt], a
            ld [c_c2], a
            ld [c_c5], a
            ld [c_c4], a
            ld [c_tid], a
            ld [c_ac], a
            call c_oclr
            call c_p4
            call c_text                     ; 1F/BD41: "CAST"
            xor a
            call c_fadeout
            call c_oclr
            call c_p4
            call c_party                    ; 1F/BC02
            xor a                           ; (all palettes black)
            ld hl, C_PAL
            ld b, 32
.k:         ld a, $0F
            ld [hl+], a
            dec b
            jr nz, .k
            call c_fr
            call c_guests                   ; 1F/BCCD
            call c_oclr
            call c_p4
            call c_text                     ; "STAFF"
            xor a
            call c_fadeout
            ld hl, c_c4
            inc [hl]
            ld hl, c_ac
            inc [hl]
            call c_staff                    ; 1F/BBAB
            ld hl, CG_EGFX                  ; 1F/B9B8: The End
            ld de, $8E00
            ld bc, $18 * 16
            xor a
            call c_load
            call c_p4
            ld hl, C_TXT
            ld b, 18 * 14
            xor a
.cl:        ld [hl+], a
            dec b
            jr nz, .cl
            ld hl, $BA23 - $6000            ; (1F/BA09: three rows of ten at row 6, column 4)
            ld de, C_TXT + 6 * 18 + 4
            call .row
            ld de, C_TXT + 7 * 18 + 4
            call .row
            ld de, C_TXT + 8 * 18 + 4
            call .row
            call c_tcopy
            ld a, 7
            call c_palset
            xor a
            call c_fadein
            ld b, 10
.wt:        push bc
            ld a, $32
            call c_wait
            pop bc
            dec b
            jr nz, .wt
            ld a, 1
            ld [c_7ec2], a
            call c_stgfx
            call c_stinit
            xor a
            ld [c_cnt], a
            ld a, 48
            ld [c_camx], a
            ld [c_camy], a
.end:       call c_fr                       ; the end: the stars behind the words for good
            call c_sobj
            call c_stmove
            ld hl, c_cnt
            inc [hl]
            jr .end
.row:       ld b, 10
.r:         ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .r
            ret

; palette set 4 and a frame (1F/B942)
c_p4:       ld a, 4
            call c_palset
            jp c_fr_oc
; the next credits text, copied a row a frame, palette set 5, faded in, 130 frames (1F/BD41)
c_text:     call c_tload
            call c_tcopy
            ld a, 5
            call c_palset
            xor a
            call c_fadein
            ld a, $82
            jp c_wait
; the next credits text into the box (1F/BA41)
c_tload:    call c_tclr
            ld a, [c_tid]
            inc a
            ld [c_tid], a
            dec a
            ld hl, C_CRED
            call c_page
            ld hl, SCRATCH
.l:         ld a, [hl+]
            cp $FF
            ret z
            ld e, a                         ; row x 18 + column
            ld d, 0
            push hl
            ld h, d
            ld l, e
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, de
            add hl, hl
            ld d, h
            ld e, l
            pop hl
            ld a, [hl+]
            add e
            ld e, a
            ld a, d
            adc 0
            ld d, a
            push hl
            ld hl, C_TXT
            add hl, de
            ld d, h
            ld e, l
            pop hl
            ld a, [hl+]
            ld b, a
.t:         ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .t
            jr .l
c_tclr:     ld hl, C_TXT
            ld b, 18 * 14
            ld a, $FF
.c:         ld [hl+], a
            dec b
            jr nz, .c
            ret
; the box onto the screen a row a frame (1F/BA95: 14 frames)
c_tcopy:    ld c, 0
.r:         push bc
            ld a, c
            call c_trow
            call c_fr
            pop bc
            inc c
            ld a, c
            cp 14
            jr nz, .r
            ret
; box row A -> map row 2 + A, columns 1-18
c_trow:     ld c, a
            add 2
            call c_rowp
            inc hl
            ld d, h
            ld e, l
            ld a, c
            ld l, a
            ld h, 0
            ld b, h
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, bc
            add hl, hl
            ld bc, C_TXT
            add hl, bc
            ld b, 18
.c:         ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .c
            ld a, 1
            ld [c_bgd], a
            ret
; box column A -> map column 1 + A, rows 2-15
c_tcol:     ld e, a
            ld d, 0
            ld hl, C_TXT
            add hl, de
            push hl
            ld a, 2
            call c_rowp
            inc hl
            add hl, de
            ld d, h
            ld e, l
            pop hl
            ld b, 14
.c:         ld a, [hl]
            ld [de], a
            ld a, l
            add 18
            ld l, a
            jr nc, .n
            inc h
.n:         ld a, e
            add 32
            ld e, a
            jr nc, .m
            inc d
.m:         dec b
            jr nz, .c
            ld a, 1
            ld [c_bgd], a
            ret

; ---- the party (1F/BC02): each member walks in with the weapon, name and level, and off
c_party:    xor a
            ld [c_c6], a
            ld [c_c5], a
.m:         ld a, [c_c5]                    ; the job ($6100 + 64 x member)
            ld l, a
            ld h, high(SRAM_PAGE + $100)
            ld a, [hl]
            ld [c_c3], a
            ld a, $F0
            ld [c_c0], a
            ld a, $68
            ld [c_c1], a
            ld a, [c_c3]
            call c_jgfx
            xor a
            ld [c_cnt], a
.in:        call c_walk
            ld a, [c_c0]
            cp $78
            jr nz, .in
            xor a
            ld [c_95], a
            call c_attack                   ; 1F/BD6E
            call c_pose1
            call c_name                     ; 1F/BC67
            call c_cheer                    ; 1F/BD9D
            call c_pose1
            ld a, 1
            call c_fadeout
            xor a
            ld [c_cnt], a
.out:       call c_walk
            ld a, [c_c0]
            and a
            jr nz, .out
            call c_oclr
            call c_fr_oc
            ld a, [c_c5]
            add $40
            ld [c_c5], a
            jr nz, .m
            ret
; a job's battle graphics (1F/BE3A: OBJ $00, 42 tiles) and its weapon (1F/BDEA: OBJ $80, 4
; tiles; its colours into $7CF0-$7CF2)
c_jgfx:     push af
            ld l, a                         ; job x $2A0
            ld h, 0
            ld d, h
            ld e, l
            add hl, hl
            add hl, hl
            add hl, de                      ; x 5
            add hl, hl
            add hl, hl
            add hl, de                      ; x 21
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl                      ; x 672
            ld de, $4000
            add hl, de
            ld a, B_CGFX
            ld de, $8000
            ld bc, $2A * 16
            call c_load2
            pop af
            ld l, a                         ; weapon: job x 68
            ld h, 0
            add hl, hl
            add hl, hl
            ld d, h
            ld e, l
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, de
            ld de, CG_WPN
            add hl, de
            push hl
            ld de, $8800
            ld bc, 64
            ld a, 1
            call c_load
            pop hl
            ld de, 64
            add hl, de
            ld de, c_wcol
            ld bc, 3
            ld a, B_CUTG
            jp far_copy
; HL (bank A) -> VRAM bank 1 DE, BC bytes (behind the guard)
c_load2:    push af
            call c_gon
            ld a, 1
            ldh [rVBK], a
            pop af
            call far_copy
            xor a
            ldh [rVBK], a
            jp c_goff
; a walking frame (1F/BDBB): 2 pixels left
c_walk:     call c_newfr
            call c_char
            ld a, [c_cnt]
            and 4
            rrca
            rrca
            ld [c_c2], a
            ld hl, c_c0
            dec [hl]
            dec [hl]
            ld hl, c_cnt
            inc [hl]
            ret
; the attack with the weapon while the text comes in (1F/BD6E)
c_attack:   xor a
            ld [c_cnt], a
            ld a, [c_wcol]                  ; (1F/BD60: the weapon's colours: OBJ palette 3)
            ld [C_PAL + $1D], a
            ld a, [c_wcol + 1]
            ld [C_PAL + $1E], a
            ld a, [c_wcol + 2]
            ld [C_PAL + $1F], a
.l:         call c_rev                      ; 1F/BB15
            call c_oclr
            xor a
            ld [c_c8], a
            call c_char
            call c_weap
            ld a, [c_cnt]
            and 4
            rrca
            rrca
            add 2
            ld [c_c2], a
            ld hl, c_cnt
            inc [hl]
            ld a, [c_95]
            cp 9
            jr nz, .l
            call c_newfr
            jp c_char
; the frame of the attack (1F/BB15): the first pages show the box at once (a step every 8 frames),
; the staff pages reveal it from both edges, two columns every 4 frames
c_rev:      ld a, [c_ac]
            and a
            jr nz, .r
            ld a, [c_cnt]
            and 7
            jr nz, .f
            ld hl, c_95
            inc [hl]
.f:         jp c_fr_oc
.r:         ld a, [c_cnt]
            and 3
            jr nz, .f
            ld a, [c_95]
            call c_tcol
            ld a, [c_95]
            ld b, a
            ld a, 17
            sub b
            call c_tcol
            ld hl, c_95
            inc [hl]
            jp c_fr
; the cheer: 128 frames (1F/BD9D)
c_cheer:    xor a
            ld [c_cnt], a
.l:         call c_newfr
            call c_char
            ld a, [c_cnt]
            and $10
            swap a
            add 4
            ld [c_c2], a
            ld hl, c_cnt
            inc [hl]
            bit 7, [hl]
            jr z, .l
            ret
; standing (1F/BED6)
c_pose1:    call c_oclr
            xor a
            ld [c_c8], a
            ld a, 1
            ld [c_c2], a
            jp c_char
; the member's name and level (1F/BC67): row 9 column 6 the name, row 11 column 7 "LV" + 2 digits
c_name:     call c_tclr
            ld a, [c_c5]
            add 6
            ld l, a
            ld h, high(SRAM_PAGE + $100)
            ld de, C_TXT + 9 * 18 + 6
            ld b, 6
.n:         ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .n
            ld hl, C_TXT + 11 * 18 + 7
            ld a, $18
            ld [hl+], a
            ld a, $22
            ld [hl+], a
            push hl
            ld a, [c_c5]
            inc a
            ld l, a
            ld h, high(SRAM_PAGE + $100)
            ld a, [hl]
            inc a
            ld b, 0
.d:         cp 10
            jr c, .e
            sub 10
            inc b
            jr .d
.e:         pop hl
            ld c, a
            ld a, b
            add $80
            ld [hl+], a
            ld a, c
            add $80
            ld [hl], a
            call c_tcopy
            ld a, 5                         ; 1F/BD56
            call c_palset
            ld a, 1
            jp c_fadein
; the character (1F/BEE1): 6 sprites, pose $C2, job palette; mirrored too when $C4
c_char:     xor a
            ld [c_cd], a
            call .one
            ld a, [c_c4]
            and a
            ret z
            ld [c_cd], a
.one:       ld a, [c_c2]                    ; tiles: 1F/BF35 + 6 x pose
            ld b, a
            add a
            add b
            add a
            add low($BF35 - $6000)
            ld e, a
            ld a, high($BF35 - $6000)
            adc 0
            ld d, a
            ld a, [c_c3]                    ; palette: 1F/BF5F + job
            add low($BF5F - $6000)
            ld l, a
            ld a, high($BF5F - $6000)
            adc 0
            ld h, a
            ld a, [hl]
            ld [c_80], a
            ld b, 0
.s:         ld a, [c_c8]
            ld l, a
            ld h, high(C_OAM)
            push hl
            ld a, b
            add low($BF83 - $6000)
            ld c, a
            push de
            ld d, high($BF83 - $6000)
            ld e, c
            ld a, [de]
            pop de
            ld c, a
            ld a, [c_c1]
            add c
            ld [hl+], a
            ld a, [de]
            inc de
            ld [hl+], a
            ld a, [c_80]
            ld [hl+], a
            ld a, b
            add low($BF7D - $6000)
            ld c, a
            push de
            ld d, high($BF7D - $6000)
            ld e, c
            ld a, [de]
            pop de
            ld c, a
            ld a, [c_c0]
            add c
            ld [hl], a
            pop hl
            call c_mirror
            ld a, [c_c8]
            add 4
            ld [c_c8], a
            inc b
            ld a, b
            cp 6
            jr nz, .s
            ret
; mirrored copy (1F/BEBE): x = 247 - x, flipped
c_mirror:   ld a, [c_cd]
            and a
            ret z
            inc l
            inc l
            ld a, [hl]
            xor $40
            ld [hl+], a
            ld a, [hl]
            cpl
            sub 8
            ld [hl], a
            ret
; the weapon (1F/BE80): 4 sprites, two frames by $B6 bit 2
c_weap:     xor a
            ld [c_cd], a
            call .one
            ld a, [c_c4]
            and a
            ret z
            ld [c_cd], a
.one:       ld a, [c_cnt]
            and 4
            rrca
            ld e, a
            ld d, 0
            ld hl, $BF89 - $6000
            add hl, de
            ld a, [hl+]
            ld e, a
            ld a, [hl]
            sub $60
            ld d, a
            ld b, 4
.s:         ld a, [c_c8]
            ld l, a
            ld h, high(C_OAM)
            push hl
            ld a, [de]
            inc de
            ld c, a
            ld a, [c_c1]
            add c
            ld [hl+], a
            ld a, [de]
            inc de
            ld [hl+], a
            ld a, [de]
            inc de
            ld [hl+], a
            ld a, [de]
            inc de
            ld c, a
            ld a, [c_c0]
            add c
            ld [hl], a
            pop hl
            call c_mirror
            ld a, [c_c8]
            add 4
            ld [c_c8], a
            dec b
            jr nz, .s
            ret

; ---- the guests (1F/BCCD): eight, each with a cast page
c_guests:   xor a
            ld [c_c5], a
            inc a
            ld [c_c2], a
            call c_oclr
            call c_fr_oc
.g:         ld a, [c_c5]                    ; graphics: 16 KB bank $14 $BA20 + 96 x id (42 tiles)
            add low($BDD0 - $6000)
            ld l, a
            ld a, high($BDD0 - $6000)
            adc 0
            ld h, a
            ld a, [hl]
            ld [c_c3], a
            ld a, $78
            ld [c_c0], a
            ld a, $68
            ld [c_c1], a
            ld a, [c_c3]
            ld l, a
            ld h, 0
            add hl, hl
            ld d, h
            ld e, l
            add hl, hl
            add hl, de                      ; x 6
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl                      ; x 96
            ld de, $4000 + $3A20
            add hl, de
            push hl                         ; (no further than the bank's end: $8000 - HL)
            ld a, l
            cpl
            ld c, a
            ld a, h
            cpl
            ld b, a
            inc bc
            ld a, b
            sub $80
            ld b, a
            cp 2
            jr c, .ok
            jr nz, .cap
            ld a, c
            cp $A0
            jr c, .ok
.cap:       ld bc, $2A * 16
.ok:        pop hl
.full:      ld a, B_CGFX
            ld de, $8000
            call c_load2
            ld a, 4
            call c_palset
            xor a
            ld [c_c8], a
            call c_oclr
            ld a, [c_c5]
            add low($BF75 - $6000)
            ld l, a
            ld a, high($BF75 - $6000)
            adc 0
            ld h, a
            ld a, [hl]
            ld [c_c3], a
            ld a, [c_c5]
            cp 4
            jr nz, .one
            ld a, $84                       ; (1F/BD20: the pair)
            ld [c_c0], a
            ld a, 1
            ld [c_c2], a
            ld [c_c4], a
            call c_char
            ld a, $94
            ld [c_c0], a
            ld a, 6
            ld [c_c2], a
            call c_char
            xor a
            ld [c_c4], a
            inc a
            ld [c_c2], a
            jr .t
.one:       call c_char
.t:         call c_text
            xor a
            call c_fadeout
            ld hl, c_c5
            inc [hl]
            ld a, [hl]
            cp 8
            jr nz, .g
            ret

; ---- the staff pages (1F/BBAB): 20, each with a pair of jobs from both edges
c_staff:    xor a
            ld [c_c6], a
.p:         call c_p4
            ld a, $F0
            ld [c_c0], a
            ld a, $68
            ld [c_c1], a
            ld a, [c_c6]
            add low($BFAD - $6000)
            ld l, a
            ld a, high($BFAD - $6000)
            adc 0
            ld h, a
            ld a, [hl]
            ld [c_c3], a
            call c_jgfx
            xor a
            ld [c_cnt], a
.in:        call c_walk
            ld a, [c_c0]
            cp $C0
            jr nz, .in
            call c_pose1
            call c_tclr                     ; 1F/BADC: the box blank, palette set 5
            call c_tcopy
            ld a, 5
            call c_palset
            call c_fr_oc
            xor a
            ld [c_95], a
            call c_tload                    ; (the text comes in by the reveal)
            call c_attack
            call c_cheer
            call c_pose1
            ld a, $3C
            call c_wait
            xor a
            call c_fadeout
            call c_oclr
            call c_p4
            ld hl, c_c6
            inc [hl]
            ld a, [hl]
            cp 20
            jr nz, .p
            ret

section wram, $CF00
c_vars:
c_cnt:      ds 1            ; $B6
c_bri:      ds 1            ; $B7
c_tint:     ds 1            ; $CC
c_cd:       ds 1            ; $CD
c_mask:     ds 1            ; $09
c_scx:      ds 1
c_scy:      ds 1
c_camx:     ds 1
c_camy:     ds 1
c_pup:      ds 1
c_bgd:      ds 1
c_split:    ds 1
c_top:      ds 1
c_bot:      ds 1
c_lyb:      ds 1
c_90:       ds 1
c_18:       ds 1
c_19:       ds 1
c_c8:       ds 1
c_cb:       ds 1
c_88:       ds 1
c_98:       ds 1
c_4a:       ds 1
c_4b:       ds 1
c_7e:       ds 1
c_7f:       ds 1
c_80:       ds 1
c_82:       ds 1
c_86:       ds 1
c_87:       ds 1
c_8c:       ds 1
c_8d:       ds 1
c_7ec2:     ds 1
c_tmp:      ds 1
c_gx:       ds 1
c_gy:       ds 1
c_vy:       ds 2
c_vdone:    ds 1
c_v:        ds 1
c_s:        ds 1
c_bgcx:     ds 1
c_bgcy:     ds 1
c_03:       ds 1
c_91:       ds 1
c_9d:       ds 1
c_9e:       ds 1
c_c0:       ds 1
c_c1:       ds 1
c_c2:       ds 1
c_c3:       ds 1
c_c4:       ds 1
c_c5:       ds 1
c_c6:       ds 1
c_ac:       ds 1
c_95:       ds 1
c_tid:      ds 1
c_wcol:     ds 3
c_vend:
