; FF3's special animations (event command $EF, 3B/A4FA) and the world-3 tile swaps (3B/A9BA,
; 3A/8FD1), with the world-map sprite helpers of src/wspr.s. NES screen (x, y) shows at GB
; (x - 48, y + 1 - 48). Each animation leaves FF3's game state as FF3 does.

section bank B_WSPR, $6C00
sa_run:     xor a                           ; (3B/B6B4: $BC, $F0 from 0)
            ld [sa_bc], a
            ld [frame], a
            ld a, [ev_arg]
            cp 16
            ret nc
            add a
            ld e, a
            ld d, 0
            ld hl, .t
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            jp hl
.t:         dw sa_0, sa_1, sa_2, sa_3, sa_4, sa_5, sa_6, sa_7
            dw sa_8, sa_9, sa_a, sa_b, sa_c, sa_d, sa_e, sa_x
sa_x:       ret

; ---- frames and sprites
sa_fr:      call wait_vbl                   ; (3B/A85A: OAM, the frame counter, the sound)
            call hram_dma
            ld hl, frame
            inc [hl]
            call snd_frame
            jp read_pad
sa_reset:   ld hl, oam_buf                  ; (3B/A842)
            ld b, 160
            xor a
.c:         ld [hl+], a
            dec b
            jr nz, .c
            ld [ws_n], a
            ret
sa_party:   %FAR B_FIELD, party_oam         ; (3E/C01B)
            ld a, 16
            ld [ws_n], a
            jp ws_pty
; an NES sprite: B = y, C = x, D = tile, E = attributes
sa_nspr:    ld a, b
            cp $EF
            ret nc
            sub 47
            ld b, a
            ld a, c
            sub 48
            ld c, a
            jp ws_spr
; NES (A = x, [sa_41] = y) -> ws_x / ws_y
sa_at:      sub 48
            ld [ws_x], a
            ld a, [sa_41]
            sub 47
            ld [ws_y], a
            ret
sa_inc:     ld hl, sa_bc
            inc [hl]
            ret

; ---- 0: the Enterprise comes down (3B/A8A9); the party aboard it after
sa_0:       call sa_reset
            ld a, $6F
            ld [sa_62], a
.l:         call sa_fr
            call sa_reset
            ld hl, sa_a906                  ; (3B/A8EB: two sets of 10 by $BC bit 2)
            ld a, [sa_bc]
            and 4
            jr nz, .k
            ld hl, sa_a906 + 40
.k:         ld b, 10
.s:         push bc
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld d, a
            ld a, [hl+]
            ld e, a
            ld a, [hl+]
            ld c, a
            push hl
            call sa_nspr
            pop hl
            pop bc
            dec b
            jr nz, .s
            ld a, [sa_62]                   ; (3B/A956: the airship at ($70, $62), two frames)
            ld [sa_41], a
            ld a, $70
            call sa_at
            ld a, $68
            ld [ws_toff], a
            ld a, [frame]
            and 8
            ld e, a
            ld d, 0
            ld hl, sa_a99a
            add hl, de
            call ws_obj
            call sa_inc
            ld a, [frame]
            and 3
            jr nz, .l
            ld hl, sa_62
            dec [hl]
            ld a, [hl]
            cp $60
            jr nc, .l
            ld a, DIR_L
            ld [facing], a
            ld a, 1
            ld [SRAM_PAGE + $00], a
            xor a
            ld [SRAM_PAGE + $03], a
            ld a, 5
            ld [sa_veh], a
            jp sa_setveh

; the party's vehicle (FF3's $42 / $46), its song
sa_setveh:  ld a, [sa_veh]
            ld [sa_tmp], a
            %FAR B_FIELD, sa_vset
            ret

; ---- 1: the airship hits the boulder (3A/9AB8): the party's sprites and the boulder's break up
sa_1:       call sa_grab                    ; (3A/9AF2)
            ld hl, sa_9b04
            ld de, sa_oam + 16
            ld bc, 16
            call memcpy
.l:         call sa_fr
            call sa_reset
            xor a
            call sa_blow                    ; (3A/9B73 from pair 0)
            ld a, [sa_bc]                   ; the boulder's explosion at (80, 80) (3A/9B14)
            srl a
            srl a
            ld b, $50
            ld c, $50
            call sa_expl
            call sa_draw8
            ld a, [sa_bc]
            bit 7, a
            jr z, .l
            ld hl, SRAM_PAGE + $20          ; the boulder gone, the party spins, the airship at
            res 0, [hl]                     ;   (80, 80)
            ld hl, SRAM_PAGE + $2F
            set 6, [hl]
            ld a, $50
            ld [SRAM_PAGE + $01], a
            ld [SRAM_PAGE + $02], a
            ld a, 1
            ld [SRAM_PAGE + $00], a
            xor a
            ld [sa_veh], a
            jp sa_setveh
; the party's four sprites (GB OAM 0-3, NES coordinates) into sa_oam 0-3
sa_grab:    call sa_reset
            call sa_party
            ld hl, oam_buf
            ld de, sa_oam
            ld b, 4
.c:         ld a, [hl+]                     ; (y, x, tile, GB attributes -> NES y, tile, -, x)
            add 47 - 16
            ld [de], a
            inc de
            ld a, [hl+]
            add 48 - 8
            ld c, a
            ld a, [hl+]
            ld [de], a
            inc de
            ld a, [hl+]
            ld [sa_ga], a
            and 7
            ld [de], a                      ; (palette; flips kept apart: NES bits 6 / 7)
            ld a, [sa_ga]
            bit 5, a
            jr z, .h
            ld a, [de]
            or $40
            ld [de], a
.h:         ld a, [sa_ga]
            bit 6, a
            jr z, .v
            ld a, [de]
            or $80
            ld [de], a
.v:         inc de
            ld a, c
            ld [de], a
            inc de
            dec b
            jr nz, .c
            ret
; sa_oam's first 8 sprites to the screen
sa_draw8:   ld hl, sa_oam
            ld b, 8
.c:         push bc
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld d, a
            ld a, [hl+]
            ld e, a
            ld a, [hl+]
            ld c, a
            push hl
            call sa_nspr
            pop hl
            pop bc
            dec b
            jr nz, .c
            ret
; the exploding sprites (3A/9B73): pairs (sprite, variant) from 3A/9B2E + A, then $BC + 1
sa_blow:    ld e, a
            ld d, 0
            ld hl, sa_9b2e
            add hl, de
.p:         ld a, [hl+]
            cp $FF
            jr z, .e
            and 7
            add a
            add a
            ld [sa_81], a
            ld a, [hl+]
            ld [sa_80], a
            push hl
            call sa_blow1
            pop hl
            jr .p
.e:         jp sa_inc
; one sprite (3A/9B96): moved out on frames 3A/9C24's bits allow, flips every 32 frames, the y
; offset of 3A/9C34 by frame
sa_blow1:   ld a, [sa_81]
            ld l, a
            ld h, high(sa_oam)
            ld a, l
            add low(sa_oam)
            ld l, a
            jr nc, .h0
            inc h
.h0:        push hl
            ld a, [sa_bc]
            and 7
            ld e, a
            ld d, 0
            ld hl, sa_9c1c
            add hl, de
            ld b, [hl]
            ld a, [sa_bc]
            srl a
            srl a
            srl a
            ld e, a
            ld hl, sa_9c1c + 8
            add hl, de
            ld a, [hl]
            and b
            pop hl
            jr z, .fl
            ld a, [sa_80]                   ; the move: 3A/9CB4 [variant x 16 + (2 $BC & 15)]
            swap a
            and $F0
            ld b, a
            ld a, [sa_bc]
            add a
            and $0F
            or b
            ld e, a
            ld d, 0
            push hl
            ld hl, sa_9cb4
            add hl, de
            ld a, [hl+]
            ld b, a
            ld c, [hl]
            pop hl
            ld a, b                         ; x
            and a
            jr z, .y
            push hl
            inc hl
            inc hl
            inc hl
            bit 7, b
            jr nz, .xl
            ld a, [hl]
            add b
            ld [hl], a
            pop hl
            jr nc, .y
            ld [hl], $F8
            jr .y
.xl:        ld a, [hl]
            sub 1
            ld [hl], a
            pop hl
            jr nc, .y
            ld [hl], $F8
.y:         ld a, c
            and a
            jr z, .fl
            ld a, [hl]
            sub 1
            cp $F0
            jr c, .ys
            ld a, $F8
.ys:        ld [hl], a
.fl:        inc hl                          ; flips by $BC bits 5-6
            inc hl
            ld a, [hl]
            and $3F
            ld b, a
            ld a, [sa_bc]
            and $60
            add a
            or b
            ld [hl-], a
            dec hl
            ld a, [hl]
            cp $F0
            ret nc
            push hl
            ld a, [sa_bc]
            ld e, a
            ld d, 0
            ld hl, sa_9c34
            add hl, de
            ld b, [hl]
            pop hl
            ld a, [hl]
            add b
            cp $F0
            jr c, .s
            ld a, $F8
.s:         ld [hl], a
            ret
; an explosion's blasts (3A/999C): A = frame, B = NES x, C = NES y; 3A/99E4 lists of (dx, dy,
; frame), each a 2 x 2 of 3A/9A48
sa_expl:    ld d, a
            ld a, b
            ld [sa_40], a
            ld a, c
            ld [sa_41], a
            ld a, d
.m:         cp 5
            jr c, .k
            sub 5
            jr .m
.k:         swap a
            ld e, a
            ld d, 0
            ld hl, sa_99e4
            add hl, de
.b:         ld a, [hl+]
            cp $FF
            ret z
            ld b, a
            ld a, [sa_40]
            add b
            ld [sa_40], a
            ld a, [hl+]
            ld b, a
            ld a, [sa_41]
            add b
            ld [sa_41], a
            ld a, [hl+]
            push hl
            add a
            add a
            add a
            ld e, a
            ld d, 0
            ld hl, sa_9a48
            add hl, de
            push hl
            ld a, [sa_40]
            call sa_at
            xor a
            ld [ws_toff], a
            pop hl
            call ws_obj
            pop hl
            jr .b

; ---- 2: six lights circle in (3B/A609), then the flashing party (3B/A5BE)
sa_2:       ld a, $FF
            ld [sa_65], a
            call sa_reset
.l:         call sa_fr
            call sa_reset
            call sa_party
            call ws_inv
            ld a, 6                         ; (3B/AB1B)
            ld [sa_8f], a
            ld a, $60
            ld [ws_ang], a
            ld a, 1
            ld [ws_ang + 1], a
.s:         ld a, [sa_65]
            ld [ws_rad], a
            call ws_proj
            ld a, [sa_bc]
            srl a
            srl a
            and 3
            ld e, a
            ld d, 0
            ld hl, sa_ab61
            add hl, de
            ld a, [hl]
            ld [sa_ga], a
            ld hl, sa_ab61 + 4
            add hl, de
            ld d, [hl]
            ld a, [sa_ga]
            ld e, a
            ld a, [ws_py]
            ld b, a
            ld a, [ws_px]
            ld c, a
            call sa_nspr
            call sa_ang40
            ld hl, sa_8f
            dec [hl]
            jr nz, .s
            call sa_inc
            ld hl, sa_65
            dec [hl]
            ld a, [hl]
            cp $0C
            jr nc, .l
            jp sa_flash
; angle + $40
sa_ang40:   ld a, [ws_ang]
            add $40
            ld [ws_ang], a
            ret nc
            ld hl, ws_ang + 1
            inc [hl]
            ret
; the party flashes for 128 frames, spinning (3B/A5BE)
sa_flash:   xor a
            ld [sa_bc], a
            call sa_reset
            ld hl, SRAM_PAGE + $2F
            set 6, [hl]
.l:         call sa_fr
            call sa_reset
            call sa_party
            ld a, [sa_bc]                   ; (3B/A5E3: every other 8 frames the sprites of
            and 8                           ;   3B/A5F9 first, the party after them)
            jr nz, .n
            ld hl, oam_buf
            ld de, oam_buf + 16
            ld bc, 16
            call memcpy
            xor a
            ld [ws_n], a
            ld hl, sa_a5f9
            ld b, 4
.s:         push bc
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld d, a
            ld a, [hl+]
            ld e, a
            ld a, [hl+]
            ld c, a
            push hl
            call sa_nspr
            pop hl
            pop bc
            dec b
            jr nz, .s
            ld a, 32
            ld [ws_n], a
.n:         call ws_inv
            call sa_inc
            ld a, [sa_bc]
            bit 7, a
            jr z, .l
            ret

; ---- 3: sixteen stars close in (3B/A631), then the flashing party
sa_3:       xor a
            ld [sa_62], a
            ld [sa_63], a
            ld a, $EA
            ld [sa_65], a
            call sa_reset
.l:         call sa_fr
            call sa_reset
            call sa_party
            call ws_inv
            ld a, [sa_62]                   ; (3B/AADE: 16 stars, tile $83)
            ld [ws_ang], a
            ld a, [sa_63]
            ld [ws_ang + 1], a
            ld a, [sa_65]
            ld [ws_rad], a
            ld a, 16
            ld [sa_8f], a
.s:         call ws_proj
            ld a, [ws_py]
            ld b, a
            ld a, [ws_px]
            ld c, a
            ld de, $8302
            call sa_nspr
            call sa_ang40
            ld hl, sa_8f
            dec [hl]
            jr nz, .s
            call sa_inc
            ld a, [sa_62]
            add 4
            ld [sa_62], a
            jr nc, .a
            ld hl, sa_63
            inc [hl]
.a:         ld a, [sa_65]
            sub 2
            ld [sa_65], a
            cp $0C
            jr nc, .l
            jp sa_flash

; ---- 4: the cannonballs and the airship shot down in Saronia (3B/A3EA, 3A/9A7B)
sa_4:       ld hl, .b
.n:         ld a, [hl+]
            cp $FF
            jr z, .down
            ld [sa_66], a
            ld a, [hl+]
            ld [sa_67], a
            ld a, [hl+]
            ld [sa_65], a
            ld a, [hl+]
            ld [sa_62], a
            push hl
            call sa_ball
            pop hl
            jr .n
.b:         db $00, $01, $FF, $02, $00, $03, $E8, $82, $80, $01, $FF, $04, $50, $02, $FF, $84, $FF
.down:      ld hl, SRAM_PAGE + $2F          ; (the party spins)
            set 6, [hl]
            xor a
            ld [v_spin], a
            ld [sa_bc], a
            call sa_grab
.l:         call sa_fr                      ; (3A/9A7B)
            ld hl, oam_buf + 16
            ld b, 160 - 16
            xor a
.z:         ld [hl+], a
            dec b
            jr nz, .z
            ld a, 16
            ld [ws_n], a
            ld a, [sa_bc]
            srl a
            srl a
            ld b, $60
            ld c, $48
            call sa_expl
            ld a, $11
            call sa_blow
            xor a
            ld [ws_n], a
            ld hl, sa_oam                   ; (the party's four, breaking up, over OAM 0-3)
            ld b, 4
.d:         push bc
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld d, a
            ld a, [hl+]
            ld e, a
            ld a, [hl+]
            ld c, a
            push hl
            call sa_nspr
            pop hl
            pop bc
            dec b
            jr nz, .d
            ld a, [sa_bc]
            bit 7, a
            jr z, .l
            xor a                           ; no vehicle; the airship hidden at (83, 71), world 3
            ld [SRAM_PAGE + $00], a
            ld a, $53
            ld [SRAM_PAGE + $01], a
            ld a, $47
            ld [SRAM_PAGE + $02], a
            ld a, 3
            ld [SRAM_PAGE + $03], a
            xor a
            ld [sa_veh], a
            jp sa_setveh
; a cannonball (3B/A433): angle +/- 2 a frame, the radius down by the speed
sa_ball:    xor a
            ld [sa_bc], a
.l:         call sa_fr
            call sa_reset
            call sa_party
            ld a, [sa_66]
            ld [ws_ang], a
            ld a, [sa_67]
            ld [ws_ang + 1], a
            ld a, [sa_65]
            ld [ws_rad], a
            call ws_proj
            ld a, [ws_py]
            ld b, a
            ld a, [ws_px]
            ld c, a
            ld de, $B503
            call sa_nspr
            call sa_inc
            ld a, [sa_62]
            bit 7, a
            ld a, [sa_66]
            jr nz, .m
            add 2
            ld [sa_66], a
            jr nc, .r
            ld hl, sa_67
            inc [hl]
            jr .r
.m:         sub 2
            ld [sa_66], a
            jr nc, .r
            ld hl, sa_67
            dec [hl]
.r:         ld a, [sa_62]
            and $0F
            ld b, a
            ld a, [sa_65]
            sub b
            ld [sa_65], a
            cp $20
            jr nc, .l
            ret

; ---- 5-8: a statue blown up (3B/A806) and its cell cleared (tile 0 over $40-$43); E: Saronia's
; gate opened (tile 3 over $4A)
sa_5:       ld b, 2
            ld c, $40
            jr sa_stat
sa_6:       ld b, 4
            ld c, $41
            jr sa_stat
sa_7:       ld b, 8
            ld c, $42
            jr sa_stat
sa_8:       ld b, $10
            ld c, $43
sa_stat:    push bc
            call sa_reset
.l:         call sa_fr
            call sa_reset
            ld a, 96                        ; (the blasts from sprite 24: 3B/A819)
            ld [ws_n], a
            ld a, [sa_bc]
            srl a
            srl a
            push af
            ld b, $40
            ld c, $50
            call sa_expl
            pop af
            ld b, $76
            ld c, $54
            call sa_expl
            %FAR B_FIELD, party_oam
            ld a, [ws_n]
            cp 96
            jr nc, .i
            ld a, 16
            ld [ws_n], a
.i:         call ws_inv
            call sa_inc
            ld a, [sa_bc]
            bit 7, a
            jr z, .l
            pop bc
            ld a, [SRAM_PAGE + $2E]
            or b
            ld [SRAM_PAGE + $2E], a
            ld a, c
            ld c, 0
            jr sa_swap
sa_e:       ld hl, SRAM_PAGE + $2E
            set 5, [hl]
            ld a, $4A
            ld c, 3
; metatile C's tables over A's (3B/A9D2), then the view drawn again
sa_swap:    call ws_tswap
            %FAR B_FIELD, sa_redraw
            ret
; metatile C -> A in the 7 tables (W_UL ...)
ws_tswap:   ld l, c
            ld e, a
            ld h, W_UL
            ld d, h
            ld b, 7
.c:         ld a, [hl]
            ld [de], a
            inc h
            inc d
            dec b
            jr nz, .c
            ret
; at a world load: world 3's swaps by the $602E flags (3A/8FD1)
ws_tswaps:  ld a, [world]
            cp 3
            ret nz
            ld a, [SRAM_PAGE + $2E]
            ld b, a
            ld c, $40
            ld e, 2
.s:         ld a, b
            and e
            jr z, .n
            push bc
            push de
            ld a, c
            ld c, 0
            call ws_tswap
            pop de
            pop bc
.n:         inc c
            sla e
            ld a, e
            cp $20
            jr nz, .s
            bit 5, b
            ret z
            ld a, $4A
            ld c, 3
            jp ws_tswap

; ---- 9: the Invincible rises from the sea (3B/A66A); the party aboard after
sa_9:       call sa_reset
.l1:        call sa_fr
            call sa_reset
            ld a, [sa_bc]                   ; (3B/A6AF: three sprites, blinking every 4 frames)
            bit 2, a
            jr nz, .n1
            srl a
            srl a
            srl a
            and 7
            add a
            add a
            and $1C
            ld b, a
            add a
            add b
            ld e, a
            ld d, 0
            ld hl, sa_a6d4
            add hl, de
            ld b, 3
.s1:        push bc
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld d, a
            ld a, [hl+]
            ld e, a
            ld a, [hl+]
            ld c, a
            push hl
            call sa_nspr
            pop hl
            pop bc
            dec b
            jr nz, .s1
.n1:        call sa_inc
            ld a, [sa_bc]
            cp $40
            jr c, .l1
            xor a
            ld [sa_bc], a
.l2:        call sa_fr
            call sa_reset
            ld a, [sa_bc]                   ; (3B/A734: the wake, 24 sprites of 3B/A77A)
            xor $3F
            add $68
            ld [sa_40], a
            ld a, $70
            ld [sa_41], a
            ld hl, sa_a77a
            ld a, 4 * 4
            ld [ws_n], a
            ld b, 24
.s2:        push bc
            ld a, [hl+]
            ld b, a
            ld a, [sa_41]
            add b
            ld [sa_41], a
            ld a, [hl+]
            ld d, a
            ld a, [hl+]
            ld e, a
            ld a, [hl+]
            ld b, a
            ld a, [sa_40]
            add b
            ld [sa_40], a
            ld c, a
            ld a, [sa_41]
            ld b, a
            push hl
            call sa_nspr
            pop hl
            pop bc
            dec b
            jr nz, .s2
            ld a, [sa_bc]                   ; (3B/A7E2: the Invincible rising)
            xor $3F
            ld b, a
            add $70
            sub 48
            ld [ws_x], a
            ld a, b
            srl a
            add $5F
            sub 47
            ld [ws_y], a
            ld a, [sa_bc]
            and 2
            swap a
            or 4
            call ws_invx
            ld a, [frame]
            and 3
            jr nz, .l2
            call sa_inc
            ld a, [sa_bc]
            cp $40
            jr c, .l2
            ld a, DIR_L
            ld [facing], a
            ld a, 1
            ld [SRAM_PAGE + $04], a
            ld a, 7
            ld [sa_veh], a
            jp sa_setveh

; ---- A / B: the flying castle along a spiral (3B/A31F, 3B/A377); C: Bahamut flies to the party
; (3B/A264); D: stars circling in (3B/A1F7)
sa_a:       ld a, $B0
            ld [sa_66], a
            ld a, 1
            ld [sa_67], a
            ld a, $FF
            ld [sa_65], a
.l1:        call sa_fr
            call sa_reset
            call sa_party
            call sa_spir
            ld a, 2
            call sa_add66
            ld hl, sa_65
            dec [hl]
            ld a, [hl]
            cp $60
            jr nc, .l1
.l2:        call sa_fr
            call sa_reset
            call sa_party
            call sa_spir
            ld a, 4
            call sa_add66
            ld a, [sa_67]
            and 3
            cp 2
            jr nz, .l2
            ld a, [sa_66]
            and a
            jr nz, .l2
            ret
sa_b:       ld a, $50
            ld [sa_66], a
            ld a, 1
            ld [sa_67], a
            ld a, $FF
            ld [sa_65], a
.l1:        call sa_fr
            call sa_reset
            xor a                           ; (the party on foot: 3E/C01B with Y = 0)
            ld [v_spin], a
            call sa_party
            call sa_spir
            ld a, 1
            call sa_add66
            ld a, [sa_65]
            sub 3
            ld [sa_65], a
            cp $30
            jr nc, .l1
.l2:        call sa_fr
            call sa_reset
            ld a, 32                        ; (the castle from sprite 8, then 3B/A96A at sprite 0)
            ld [ws_n], a
            call sa_spir
            xor a
            ld [ws_n], a
            ld a, [frame]                   ; (FF3's $40 / $41 where the castle's lists left them:
            rra                             ;   its shadow's end on odd frames)
            jr nc, .ns
            ld a, [ws_lx]
            add 48
            ld [sa_40], a
            ld a, [ws_ly]
            add 47
            ld [sa_41], a
            jr .go
.ns:        ld a, [ws_x]
            add 48
            ld [sa_40], a
            ld a, [ws_y]
            add 47
            ld [sa_41], a
.go:        ld a, [sa_40]                   ; (3B/A96A: - 4 / - 10, - 16 more on odd frames)
            sub 4
            ld b, a
            ld a, [frame]
            rra
            ld a, b
            jr nc, .e
            sub $10
.e:         ld [sa_40], a
            ld a, [sa_41]
            sub $0A
            ld [sa_41], a
            ld a, [sa_40]
            call sa_at
            xor a
            ld [ws_toff], a
            ld a, [frame]
            and 8
            ld e, a
            ld d, 0
            ld hl, sa_a99a + 16
            add hl, de
            call ws_obj
            ld a, 2
            call sa_add66
            ld a, [sa_65]
            add 2
            ld [sa_65], a
            cp $F8
            jr c, .l2
            ret
sa_add66:   ld hl, sa_66
            add [hl]
            ld [hl], a
            ret nc
            inc hl
            inc [hl]
            ret
; the castle at the spiral's point - 12 (3B/A3D6, 3C/88DB)
sa_spir:    ld a, [sa_66]
            ld [ws_ang], a
            ld a, [sa_67]
            ld [ws_ang + 1], a
            ld a, [sa_65]
            ld [ws_rad], a
            call ws_proj
            ld a, [ws_px]
            sub $0C
            ld [sa_40], a
            ld a, [ws_py]
            sub $0C
            ld [sa_41], a
sa_cast:    ld a, [sa_40]                   ; (3C/88DB at (sa_40, sa_41))
            call sa_at
            ld a, [frame]
            and $10
            jr z, .a
            ld a, $41
.a:         add $19
            ld l, a
            ld h, 0
            ld de, $8600 + WS_3C
            add hl, de
            jp ws_withsh
sa_c:       ld a, [ws_e6]                   ; from Hein's castle's place to the party's, 2 pixels a
            and $FE                         ;   step along the longer side (3B/A2C0)
            sub $70
            ld b, 0
            jr nc, .x
            cpl
            inc a
            dec b
.x:         ld [sa_62], a
            ld a, b
            ld [sa_64], a
            ld a, [ws_e7]
            and $FE
            sub $70
            ld b, 0
            jr nc, .y
            cpl
            inc a
            dec b
.y:         ld [sa_63], a
            ld a, b
            ld [sa_65], a
            xor a
            ld [sa_61], a
.l:         call sa_fr
            call sa_reset
            call sa_party
            call sa_step
            ld a, [ws_e6]
            ld [sa_40], a
            ld a, [ws_e7]
            ld [sa_41], a
            call sa_cast
            ld a, [ws_e6]
            cp $70
            jr nz, .l
            ld a, [ws_e7]
            cp $70
            jr nz, .l
            ld hl, SRAM_PAGE + $2F
            set 6, [hl]
            ret
sa_step:    ld a, [sa_62]
            ld b, a
            ld a, [sa_63]
            cp b
            jr c, .xm                       ; (x the longer: x every step, y by the error)
            jr z, .xm
            call .sy
            ld a, [sa_61]
            add b
            ld hl, sa_63
            cp [hl]
            jr c, .ys
            sub [hl]
            ld [sa_61], a
            jr .sx
.ys:        ld [sa_61], a
            ret
.xm:        call .sx
            ld a, [sa_63]
            ld b, a
            ld a, [sa_61]
            add b
            ld hl, sa_62
            cp [hl]
            jr c, .ys
            sub [hl]
            ld [sa_61], a
.sy:        ld a, [ws_e7]
            and $FE
            cp $70
            ret z
            ld a, [sa_65]
            bit 7, a
            ld a, [ws_e7]
            jr nz, .yp
            sub 2
            ld [ws_e7], a
            ret
.yp:        add 2
            ld [ws_e7], a
            ret
.sx:        ld a, [ws_e6]
            and $FE
            cp $70
            ret z
            ld a, [sa_64]
            bit 7, a
            ld a, [ws_e6]
            jr nz, .xp
            sub 2
            ld [ws_e6], a
            ret
.xp:        add 2
            ld [ws_e6], a
            ret
sa_d:       xor a
            ld [NPC2 + 1], a
            ld [sa_62], a
            ld [sa_63], a
            ld a, $EA
            ld [sa_65], a
            call sa_reset
.l:         call sa_fr
            call sa_reset
            xor a
            ld [v_spin], a
            call sa_party
            ld a, [sa_62]                   ; (3B/A230: eight of person 0, - 4 / - 4)
            ld [ws_ang], a
            ld a, [sa_63]
            ld [ws_ang + 1], a
            ld a, [sa_65]
            ld [ws_rad], a
            ld a, 8
            ld [sa_8f], a
.s:         call ws_proj
            ld a, [ws_px]
            sub 4 + 48
            ld [ws_x], a
            ld a, [ws_py]
            sub 4 + 47
            ld [ws_y], a
            call sa_npc0
            ld a, [ws_ang]
            add $80
            ld [ws_ang], a
            jr nc, .k
            ld hl, ws_ang + 1
            inc [hl]
.k:         ld hl, sa_8f
            dec [hl]
            jr nz, .s
            ld a, [sa_62]
            add 4
            ld [sa_62], a
            jr nc, .a
            ld hl, sa_63
            inc [hl]
.a:         ld a, [sa_65]
            sub 2
            ld [sa_65], a
            cp $0C
            jr nc, .l
            ret
; person 0's sprite (its pose, facing, palette pair) at (ws_x, ws_y)
sa_npc0:    ld a, [NPC2 + 5]
            ld b, a
            ld a, [NPC1 + 14]
            add b
            ld l, a
            ld h, high(npc_poses)
            ld a, 32
            ld [ws_toff], a
            jp ws_obj

section bank B_WSPR, $5D00
sa_a5f9:    ds 16                           ; (from the ROM: build.py ROMDATA)
sa_a6d4:    ds 96
sa_a77a:    ds 96
sa_a906:    ds 80
sa_a99a:    ds 32
sa_ab61:    ds 8
sa_99e4:    ds 80
sa_9a48:    ds 40
sa_9b04:    ds 16
sa_9b2e:    ds 26
sa_9c1c:    ds 24
section bank B_WSPR, $7D80
sa_9c34:    ds 128
sa_9cb4:    ds 240

section wram, $CF60
sa_bc:      ds 1
sa_40:      ds 1
sa_41:      ds 1
sa_61:      ds 1
sa_62:      ds 1
sa_63:      ds 1
sa_64:      ds 1
sa_65:      ds 1
sa_66:      ds 1
sa_67:      ds 1
sa_80:      ds 1
sa_81:      ds 1
sa_8f:      ds 1
sa_ga:      ds 1
sa_veh:     ds 1
sa_tmp:     ds 1
sa_oam:     ds 32
