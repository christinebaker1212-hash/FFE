; btlsum.s (CODE9): the summons (FF3 34/85ED, 2F/B050, 33/AFB0, 32/8CEF and the summons' attacks
; 32/8115-). Bank 32 is copied at $6000 (build.py); FXD holds 2A/9440-95FF (the creatures' sizes,
; places, palettes and layouts) and 2F/AFC0 (their sounds). The creature is drawn in the 8 x 16
; sprite mode (btlfx.s) with the party hidden as FF3 does (its sprites cleared): the largest
; (8 x 9 cells) is 40 pairs.
N32S       = $6000 - $8000      ; 32 address + N32S = the copy here
F2A        = $5800 - $9440      ; FXD: 2A/9440-95FF at $5800
F2FS       = $59C0 - $AFC0      ; FXD: 2F/AFC0-AFD7 at $59C0
SM_OBJ     = W7 + $7900         ; the creature's sprites: y, tile, attributes, x (FF3's $7900)
sm_p       = W7 + $73E0         ; its 8 properties (2A/9440), the graphics entry (FF3's scratch $7300-)
sm_g       = W7 + $73E8

; ---- 34/85ED attack animation 2: summon
sm_main:    xor a
            ld [sm_fl], a
            ld a, [W7 + $7E99]              ; the target ($B8)
            call ba_maskid
            ld [BZ + $B8], a
            ld a, [W7 + $7E94]
            and $0F
            ld [W7 + $7E92], a
            ld a, [W7 + $7E94]
            swap a
            and $0F
            ld [W7 + $7E91], a
            ld e, a                         ; 2F/B050: the sound (2F/AFC0 + 3 summon + attack)
            add a, a
            add a, e
            ld e, a
            ld a, [W7 + $7E92]
            add a, e
            ld l, a
            ld h, 0
            ld de, $AFC0 + F2FS
            add hl, de
            ld a, FXD
            call rd_byte
            ld [BZ + $CA], a
            ld a, [W7 + $7E94]              ; (icy stare, thunderstorm, judgment bolt, slash: the
            cp $11                          ;   targets in palette 2; demon eye: 3)
            jr z, .p2
            cp $21
            jr z, .p2
            cp $22
            jr z, .p2
            cp $51
            jr z, .p2
            cp $60
            jr nz, .np
            ld a, 3
            jr .pf
.p2:        ld a, 2
.pf:        ld [W7 + $7E90], a
            call sm_asave                   ; (the attribute table kept: FF3's $7440)
            ld a, [W7 + $7E99]
            ld [W7 + $7E8F], a
            call mon_flash
            ld a, 1
            ld [sm_fl], a
.np:        call ba_stepf
            call ba_cgfx
            ld a, $9F
            ld [S49], a
            call sm_pre                     ; 33/AFB0
            call sm_anim                    ; 32/8CEF
            call chr_gfx                    ; (2F/AA78: the party's tiles again)
            call chr_draw
            ld a, [W7 + $7EE2]              ; (chocobo dash: the party has run)
            and a
            ret nz
            call sm_cyc                     ; 32/8CBA
            call mon_count
            call ba_stepb
            ld a, 1
            ld [ba_dirty], a
            jp ui_hand

; 33/AFB0 the summon's casting: 40 frames of the spinning thing (33/B1EE), then its 4 sprites
; fly apart for 40 frames (33/AFF2 deltas, 33/B02A tiles)
sm_pre:     ld a, 4
            call sm_gfx0
            ld a, [W7 + $7E91]              ; the palette: 2E/8043 + summon (FXD 2E/8040 copy)
            ld l, a
            ld h, 0
            ld de, $8043 + F2E8
            add hl, de
            ld a, FXD
            call rd_byte
            call ba_pal3
            call ba_save
            call s16_start
            xor a
            ld [BZ + $B6], a
.a:         call mx_cast
            call mx_sfr
            call mx_wait
            call ba_inc
            cp $28
            jr nz, .a
            xor a
            ld [BZ + $B6], a
            call ba_reset
            ld a, $5B
            call ba_aspr0
            call ba_tm                      ; (33/AFA2: the casting pose, the sprites kept)
            ld a, 8
            jr z, .c
            ld a, $0E
.c:         call ba_cfr
.b:         call mx_wait
            call .mv
            call ba_inc
            cp $28
            jr nz, .b
            call ba_reset
            call s16_stop
            jp mx_jend
.mv:        ld a, [BZ + $B6]                ; (bank 3 read first: the counter, the table)
            push af
            ld a, [W7 + $78C3]              ; 33/B066: the deltas (33/AFF2 / B002 back attack;
            cp $88                          ;   bank 33 read from CODE8's copy)
            ld hl, $AFF2 - $4000
            jr nz, .t
            ld hl, $B002 - $4000
.t:         ld a, 5                         ; (the sprites in WRAM 5)
            ldh [rSVBK], a
            ld b, 8
.m:         push bc
            ld a, CODE8
            call rd_byte                    ; FF3 OAM byte offset: sprite (/ 4), field (0 y, 3 x)
            ld c, a
            ld a, CODE8
            call rd_byte
            ld b, c
            pop de
            ld c, b
            ld b, d
            push hl
            push bc
            ld d, a
            ld a, c
            and $FC
            ld l, a
            ld h, 0
            ld a, c
            and 3
            jr z, .y
            inc l                           ; (s16_in: y, x, tile, attributes)
.y:         ld bc, S16_IN
            add hl, bc
            ld a, [hl]
            add a, d
            ld [hl], a
            pop bc
            pop hl
            dec b
            jr nz, .m
            pop af
            ld e, a                         ; (E = the counter)
            ld hl, S16_IN                   ; 33/B02A: off the screen: hidden; tiles $55 + B6 / 8
            ld b, 4
.s:         ld a, [hl+]
            ld c, a
            ld a, [hl+]
            cp 8
            jr c, .h
            cp 168
            jr nc, .h
            ld a, c
            cp 8
            jr c, .h
            cp 160
            jr nc, .h
            ld a, [hl]
            and a
            jr z, .n
            cp $58
            jr z, .n
            ld a, e
            and $18
            rrca
            rrca
            rrca
            add a, $55
            ld [hl], a
            jr .n
.h:         ld [hl], 0
.n:         inc hl
            inc hl
            dec b
            jr nz, .s
            ld a, 3
            ldh [rSVBK], a
            ret

; ---- 32/8CEF the summon: the party's palettes cycled and faded, the creature (2A/9440 + 8
; summon: graphics, 3 palettes, size, place, layout) comes in, its attack, it goes
sm_anim:    call sm_cyc
            call sm_fade
            call s16_start
            ld a, 1
            ldh [s16_np], a
            ld a, [W7 + $7E91]
            and 7
            add a, a
            add a, a
            add a, a
            ld l, a
            ld h, 0
            ld de, $9440 + F2A
            add hl, de
            ld de, sm_p
            ld bc, 8
            ld a, FXD
            call rd_copy
            ld a, [sm_p]                    ; graphics $0A + 16 index
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld a, $0A
            call sm_gfx
            ld a, [W7 + $7E92]              ; the palettes: sm_p[1 + attack], then the next two
            ld e, a
            ld d, 0
            ld hl, sm_p + 1
            add hl, de
            ld a, [hl]
            ld c, $11
            call sm_pal
            inc a
            ld c, $15
            call sm_pal
            inc a
            ld c, $19
            call sm_pal
            call sm_build
            ld a, $50                       ; 32/8E56: in from x + $50, 8 a frame
            ld [sm_x], a
.in:        call sm_drawb
            call ba_vblc
            ld a, [sm_x]
            sub 8
            ld [sm_x], a
            jr nz, .in
            call sm_drawb
            call ba_vblc
            call sm_attack                  ; 32/8115
            call sm_fade
            call mx_eclr
            call s16_build
            ld hl, W7 + $7D07               ; the sprite palettes black
            ld b, 16
            ld a, $0F
.k:         ld [hl+], a
            dec b
            jr nz, .k
            call ba_vblc
            xor a
            ldh [s16_np], a
            jp s16_stop
; 32/8E36 out: to x + $50
sm_out:     xor a
            ld [sm_x], a
.o:         call sm_drawb
            call ba_vblc
            ld a, [sm_x]
            add a, 8
            ld [sm_x], a
            cp $50
            jr nz, .o
            call sm_drawb
            jp ba_vblc

; the creature's list ($7900): width x height cells from its layout (2A, $FF none; $3F tile
; + $39, palette bits 7-6), x = column 8 + place-hi 8 + $B0, y = row 8 + place-lo 8 + $28
sm_build:   ld a, [sm_p + 4]
            and $0F
            ld [sm_h], a
            ld a, [sm_p + 4]
            swap a
            and $0F
            ld [sm_w], a
            ld a, [sm_p + 5]
            swap a
            and $0F
            add a, a
            add a, a
            add a, a
            add a, $B0
            ld [sm_x0], a
            ld a, [sm_p + 5]
            and $0F
            add a, a
            add a, a
            add a, a
            add a, $28
            ld [sm_y0], a
            ld a, [sm_p + 6]
            ld l, a
            ld a, [sm_p + 7]
            ld h, a
            ld de, F2A
            add hl, de
            ld de, SM_OBJ
            xor a
            ld [sm_n], a
            ld a, [sm_y0]
            ld c, a
            ld a, [sm_h]
            ld b, a
.r:         push bc
            ld a, [sm_x0]
            ld [sm_t], a
            ld a, [sm_w]
            ld b, a
.c:         push bc
            ld a, FXD
            call rd_byte
            pop bc
            push hl
            ld h, d
            ld l, e
            ld [hl], c                      ; y
            inc hl
            cp $FF
            jr nz, .t
            ld [hl], 0
            inc hl
            ld [hl], 0
            jr .x
.t:         push af
            and $3F
            add a, $39
            ld [hl+], a                     ; tile
            pop af
            rlca
            rlca
            and 3
            ld [hl], a                      ; palette
.x:         inc hl
            ld a, [sm_t]
            ld [hl+], a                     ; x
            ld d, h
            ld e, l
            pop hl
            ld a, [sm_t]
            add a, 8
            ld [sm_t], a
            ld a, [sm_n]
            inc a
            ld [sm_n], a
            dec b
            jr nz, .c
            pop bc
            ld a, c
            add a, 8
            ld c, a
            dec b
            jr nz, .r
            ret
; 32/8E76 the creature at x + sm_x, y + sm_y (off the right: hidden; mode 3: the party's side)
sm_draw:    call mx_eclr
            ld a, 3
            ld [ba_mode], a
            ld hl, SM_OBJ
            ld a, [sm_n]
            and a
            ret z
            ld b, a
.s:         push bc
            ld a, [hl+]
            ld c, a
            ld a, [hl+]
            ld d, a
            ld a, [hl+]
            ld e, a
            ld a, [hl+]
            push hl
            ld hl, sm_x
            add a, [hl]
            jr c, .n
            ld b, a
            ld a, [sm_y]
            add a, c
            dec a
            cp $98
            jr nc, .n
            ld c, a
            call mx_put
.n:         pop hl
            pop bc
            dec b
            jr nz, .s
            ret
sm_drawb:   call sm_draw
            jp s16_build

; ---- 32/8115 the attacks (summon x 3 + attack: 32/80DA)
sm_attack:  ld a, [W7 + $7E91]
            ld e, a
            add a, a
            add a, e
            ld e, a
            ld a, [W7 + $7E92]
            add a, e
            add a, a
            ld e, a
            ld d, 0
            ld hl, sm_tab
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            call sm_jhl
            ld a, [sm_fl]                   ; (the flash kept: the attribute table back)
            and a
            ret z
            xor a
            ld [sm_fl], a
            call sm_arest
            jp attr_push
; the attribute table ($7D27, 64) kept in WRAM 7 / back (attr_push builds its rows at $7300-)
sm_asave:   ld hl, W7 + $7D27
            ld de, $D000
            jr sm_a7
sm_arest:   ld hl, $D000
            ld de, W7 + $7D27
            ld a, 7
            ld c, 3
            jr sm_a7b
sm_a7:      ld a, 3
            ld c, 7
sm_a7b:     ld b, $40
.l:         ldh [rSVBK], a
            push af
            ld a, [hl+]
            push af
            ld a, c
            ldh [rSVBK], a
            pop af
            ld [de], a
            inc de
            pop af
            dec b
            jr nz, .l
            ld a, 3
            ldh [rSVBK], a
            ret
sm_jhl:     jp hl
sm_tab:     dw sm_dash, sm_shk, sm_kick, sm_hold, sm_icy, sm_hold
            dw sm_mind, sm_thun, sm_thun, sm_heal, sm_hold, sm_hold
            dw sm_clob, sm_stomp, sm_quake, sm_prot, sm_slash, sm_zan
            dw sm_demon, sm_hold, sm_tidal, sm_aura, sm_rend, sm_mega
; (not yet ported: the creature holds 48 frames, then goes)
sm_hold:    ld b, 48
.w:         push bc
            call mx_wait
            pop bc
            dec b
            jr nz, .w
            ret
; $00 chocobo dash: 16 frames, then (not for the party's escape check $7E93) it runs off
sm_dash:    call sm_w16
            ld a, [W7 + $7E93]
            and a
            ret nz
            ld hl, BZ + $C9
            inc [hl]
            call sm_out
            ld hl, W7 + $7EE2
            inc [hl]
            ret
; $01 the chocobo shaken (FF3's random table) 32 frames
sm_shk:     xor a
            ld [BZ + $B6], a
            ld hl, BZ + $C9
            inc [hl]
.f:         ld a, [BZ + $B6]
            ld e, a
            ld d, 0
            ld hl, W7 + $7BE3
            add hl, de
            ld a, [hl]
            and 3
            ld [sm_y], a
            call sm_drawb
            call mx_wait
            call ba_inc
            cp $20
            jr nz, .f
            xor a
            ld [sm_y], a
            ret
; $02 chocobo kick: its frames swapped every 4 frames, 16 strikes (hit animation 1), 64 frames
sm_kick:    ld a, 9
            call sm_gfx0
            ld a, $BD
            call ba_pal3
            xor a
            ld [BZ + $CD], a
            ld a, $10
            ld [BZ + $BB], a
            ld [BZ + $BC], a
            call ba_hits
            xor a
            ld [BZ + $B6], a
            ld hl, BZ + $C9
            inc [hl]
.f:         ld a, [BZ + $B6]                ; (32/8B37: the 9 tiles, or the 9 after)
            and 4
            ld e, 9
            jr z, .t
            ld e, 0
.t:         ld d, 0
            ld hl, $8B37 + N32S
            add hl, de
            ld de, SM_OBJ + 1
            ld b, 9
.c:         ld a, [hl+]
            ld [de], a
            inc de
            inc de
            inc de
            inc de
            dec b
            jr nz, .c
            call sm_draw
            ld a, 1
            call ba_hit
            call mx_wait
            call ba_inc
            cp $40
            jr nz, .f
            ret
; $06 mind blast: BG palettes 0 / 1 lit in white for 48 frames
sm_mind:    ld hl, BZ + $C9
            inc [hl]
            ld a, $30
            jr sm_bgfl
; (32/8B99: palettes kept, BG palettes 0 and 1 cycled in A's hue 48 frames, back)
sm_bgfl:    ld [sm_t], a
            call sm_psave
            xor a
            ld [BZ + $B6], a
.f:         ld c, 0
            call sm_cyc1
            ld c, 4
            call sm_cyc1
            call sm_drawb
            call ba_vblc
            call ba_inc
            cp $30
            jr nz, .f
            jp sm_8547
; 32/87AD palette C's colours 1-3 in hue sm_t, the brightness rows stepping by the counter
sm_cyc1:    ld a, [BZ + $B6]
            and 3
            swap a
            ld d, a
            ld a, [sm_t]
            and $0F
            ld e, a
            ld b, 0
            ld hl, W7 + $7CF8
            add hl, bc
            ld a, d
            or e
            ld [hl+], a
            ld a, d
            add a, $10
            and $30
            or e
            ld [hl+], a
            ld a, d
            add a, $20
            and $30
            or e
            ld [hl], a
            ret
; 32/8B81 / 8B8D the palettes kept / back ($7E77)
sm_psave:   ld hl, W7 + $7CF7
            ld de, W7 + $7E78
            ld bc, 16
            jp memcpy
sm_prest:   ld hl, W7 + $7E78
            ld de, W7 + $7CF7
            ld bc, 16
            jp memcpy
; $07 / $08 thunderstorm / judgment bolt: the backdrop flashed ($29), 8 frames of palette 2
; lit ($27), then the bolt's hit frames (spell $2A) on the targets
sm_thun:    call sm_psave
            ld a, $29
            ld b, $10
            call sm_bkfl
            ld a, $27
            ld [sm_t], a
            xor a
            ld [BZ + $B6], a
.f:         ld c, 8
            call sm_cyc1
            call sm_drawb
            call ba_vblc
            call ba_inc
            cp 8
            jr nz, .f
            call mx_eclr
            call sm_8547
            call ba_vblc
            call mx_eclr
            ld a, $2A
            jp mx_b943
; $04 icy stare / $10 slash: 48 frames, BG palette 2 in palette $E8 every other 4 frames
sm_icy:
sm_slash:   ld hl, BZ + $C9
            inc [hl]
            call sm_psave
            call attr_push
            xor a
            ld [BZ + $B6], a
.f:         ld a, [BZ + $B6]
            and 4
            jr nz, .r
            ld a, $E8
            ld c, $09
            call sm_pal
            jr .s
.r:         call sm_prest
.s:         call sm_drawb
            call ba_vblc
            call ba_inc
            cp $30
            jr nz, .f
            ret
; $12 demon eye: (hit) the backdrop flashed light blue, the attributes shown, 16 frames
sm_demon:   ld a, [W7 + $7E9B]
            and a
            ret z
            ld hl, BZ + $C9
            inc [hl]
            ld a, $31
            ld b, $20
            call sm_bkfl
            call attr_push
            jp sm_w16
; $0F protective light: blue-green; $15 aura: light blue
sm_prot:    ld a, $2B
            jr sm_fl2
sm_aura:    ld a, $31
sm_fl2:     ld b, $20
            jp sm_bkfl
; $11 zantetsuken: (not the escape check) 16 frames, the slash (the monsters' palettes faded),
; then every target's experience counted and all monster slots cleared (FF3 skips the death
; animation)
sm_zan:     ld a, [W7 + $7E93]
            and a
            ret nz
            call sm_w16
            ld hl, BZ + $C9
            inc [hl]
            xor a                           ; (32/8BBC: 96 frames; the last 32 fade the monsters'
            ld [BZ + $B6], a                ;   palettes every 8: FF3 slices the screen meanwhile)
.f:         ld a, [BZ + $B6]
            and $C0
            jr z, .n
            ld a, [BZ + $B6]
            and 7
            jr nz, .n
            ld hl, W7 + $7CF7               ; (32/8C70: BG colours - $10, or black)
            ld b, 8
.c:         ld a, [hl]
            and $F0
            ld a, $0F
            jr z, .k
            ld a, [hl]
            sub $10
.k:         ld [hl+], a
            dec b
            jr nz, .c
.n:         call sm_drawb
            call ba_vblc
            call ba_inc
            cp $60
            jr nz, .f
            ld a, [W7 + $7E99]
            ld c, a
            ld b, 0
.t:         sla c
            jr nc, .t1
            ld e, b
            ld d, 0
            ld hl, W7 + $7DA7
            add hl, de
            ld a, [hl]
            cp $FF
            jr z, .t1
            ld e, a
            ld hl, W7 + $7DD3
            add hl, de
            inc [hl]
.t1:        inc b
            ld a, b
            cp 8
            jr nz, .t
            ld hl, W7 + $7DA7
            ld b, 8
            ld a, $FF
.z:         ld [hl+], a
            dec b
            jr nz, .z
            jp mon_redraw
; $14 tidal wave: graphics $11 + $B160, 60 frames, Leviathan leaves, 16 frames, then 63 frames
; of the battlefield shaken (FF3's random each frame: the waves' sprites later)
sm_tidal:   ld hl, $B160
            ld a, $11
            call sm_gfx
            ld b, 60
.w:         push bc
            call mx_wait
            pop bc
            dec b
            jr nz, .w
            call sm_out
            call sm_w16
            call mx_eclr
            ld a, $BC
            call ba_pal3
            ld hl, BZ + $C9
            inc [hl]
            ldh a, [scx]
            ld [sm_t], a
            ld b, 63
.s:         push bc
            call mx_wait
            call ba_rnd255
            and 3
            ld hl, sm_t
            add a, [hl]
            ldh [scx], a
            pop bc
            dec b
            jr nz, .s
            ld a, [sm_t]
            ldh [scx], a
            ret

; $17 mega flare: 60 frames, 16 of the backdrop white (FF3 tints the screen), then 64 frames of
; two explosions at FF3's random places (32/85F8 / 8600, a new place each 4th step) with BG
; palettes 0 / 1 lit red; the end restores the palettes (32/8547 runs the explosion step once
; more, as FF3)
sm_mega:    ld b, 60
.w:         push bc
            call mx_wait
            pop bc
            dec b
            jr nz, .w
            xor a
            ld [W7 + $7ED5], a
            call sm_psave
            xor a
            ld [BZ + $B6], a
            ld hl, BZ + $C9
            inc [hl]
.t:         ld a, $30
            call ba_bkd
            call ba_inc
            and $10
            jr z, .t
            ld a, $0F                       ; (the backdrop black again: all four BG palettes)
            ld [W7 + $7CF7], a
            ld [W7 + $7CF7 + 4], a
            ld [W7 + $7CF7 + 8], a
            ld [W7 + $7CF7 + 12], a
            ld hl, $B1C0
            ld a, $11
            call sm_gfx
            ld a, $BD
            call ba_pal3
            call sm_pos1
            call sm_pos2
            ld a, 2
            ld [BZ + $90], a
            xor a
            ld [BZ + $91], a
.f:         call sm_854d
            call s16_build
            ld a, [BZ + $8F]
            push af
            ld a, $16
            ld [sm_t], a
            ld c, 0
            call sm_cyc1
            ld c, 4
            call sm_cyc1
            pop af
            ld [BZ + $8F], a
            call ba_vblc
            call ba_inc
            cp $40
            jr nz, .f
            call mx_eclr
; 32/8547 the palettes back, then the explosion step once more (FF3 falls through)
sm_8547:    call sm_prest
; 32/854D: (cannon: the animation sprites; mega flare: all) cleared; on even steps $90 / $91
; advance (0: a new random place), the explosions drawn (32/8F8F frames)
sm_854d:    call mx_eclr
            ld a, [BZ + $B6]
            and 1
            jr nz, .d
            ld hl, BZ + $90
            inc [hl]
            ld a, [hl]
            and 3
            ld [hl], a
            call z, sm_pos1
            ld hl, BZ + $91
            inc [hl]
            ld a, [hl]
            and 3
            ld [hl], a
            call z, sm_pos2
.d:         ld a, 1
            ld [ba_mode], a
            ld a, [BZ + $90]
            ld c, a
            ld a, [BZ + $8C]
            ld [BZ + $80], a
            ld a, [BZ + $8D]
            ld [BZ + $81], a
            call .ex
            ld a, [W7 + $7ED5]
            and a
            ret nz
            ld a, [BZ + $91]
            ld c, a
            ld a, [BZ + $8E]
            ld [BZ + $80], a
            ld a, [BZ + $8F]
            ld [BZ + $81], a
.ex:        ld a, c                         ; frame C: 32/8F8F + 2 C (tiles + $38 for the cannon)
            add a, a
            ld e, a
            ld d, 0
            ld hl, $8F8F + N32S
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld de, N32S
            add hl, de
            jp sm_list
; 32/85F8 / 8600 a random place: x 16-128, y 47-111 (FF3's random, counter 0) -> $8C / $8D, $8E / $8F
sm_pos1:    call sm_rpos
            ld a, b
            ld [BZ + $8C], a
            ld a, c
            ld [BZ + $8D], a
            ret
sm_pos2:    call sm_rpos
            ld a, b
            ld [BZ + $8E], a
            ld a, c
            ld [BZ + $8F], a
            ret
sm_rpos:    xor a
            ld [BZ + $21], a
            ld b, $10
            ld a, $80
            call rnd_xa
            push af
            xor a
            ld [BZ + $21], a
            ld b, $2F
            ld a, $6F
            call rnd_xa
            ld c, a
            pop af
            ld b, a
            ret

; 32/8781 the backdrop A every 4 frames for B frames
sm_bkfl:    ld [sm_t], a
.f:         push bc
            call sm_drawb
            pop bc
            push bc
            ld a, b
            and 3
            ld a, $0F
            jr nz, .c
            ld a, [sm_t]
.c:         call ba_bkd
            pop bc
            dec b
            jr nz, .f
            ret
; $09 healing light: the backdrop flashed light blue; $16 rend: red, then light blue
sm_rend:    ld hl, BZ + $C9
            inc [hl]
            ld a, $16
            ld b, $20
            call sm_bkfl
sm_heal:    ld hl, BZ + $C9
            inc [hl]
            ld a, $31
            ld b, $20
            call sm_bkfl
            ret
; $0E earthen fury: the earthquake (32/8C8D)
sm_quake:   call mx_shake
            ret
; $0C / $0D clobber / stomp: the fist / foot (graphics $11 + $B300 / $B390, tiles 1-) hitting
; around the target (FF3's random every 4 frames) for 64 frames, sprites 32/90AD
sm_stomp:   ld hl, $B390
            jr sm_cl0
sm_clob:    ld hl, $B300
sm_cl0:     push hl
            ld a, $EC
            call ba_pal3
            pop hl
            ld a, $11
            call sm_gfx
            call ba_vblc
            ld a, [BZ + $B8]
            add a, a
            ld e, a
            ld d, 0
            ld hl, W7 + $7DD7
            add hl, de
            ld a, [hl+]
            sub $18
            ld [BZ + $8C], a
            ld a, [hl]
            sub $18
            ld [BZ + $8D], a
            xor a
            ld [BZ + $B6], a
            ld hl, BZ + $C9
            inc [hl]
.f:         ld a, [BZ + $B6]
            and 3
            jr nz, .d
            xor a
            ld [BZ + $21], a
            ld b, 0
            ld a, $18
            call rnd_xa
            ld [BZ + $8E], a
            xor a
            ld [BZ + $21], a
            ld b, 0
            ld a, $18
            call rnd_xa
            ld [BZ + $8F], a
.d:         call sm_draw
            ld a, 1
            ld [ba_mode], a
            ld a, [BZ + $8C]
            ld hl, BZ + $8E
            add a, [hl]
            ld [BZ + $80], a
            ld a, [BZ + $8D]
            ld hl, BZ + $8F
            add a, [hl]
            ld [BZ + $81], a
            ld hl, $90AD + N32S
            call sm_list
            call mx_wait
            call ba_inc
            cp $40
            jr nz, .f
            ret
; 32/85B7 the sprite list at HL (y, tile, flags, x; $FF ends) at ($80, $81)
sm_list:    ld a, [hl]
            cp $FF
            ret z
            ld a, [hl+]
            ld c, a
            ld a, [BZ + $81]
            add a, c
            ld c, a
            ld a, [hl+]
            ld d, a
            ld a, [hl+]
            ld e, a
            ld a, [hl+]
            ld b, a
            ld a, [BZ + $80]
            add a, b
            ld b, a
            push hl
            call mx_put
            pop hl
            jr sm_list
sm_w16:     ld b, 16
.w:         push bc
            call mx_wait
            pop bc
            dec b
            jr nz, .w
            ret

; 32/8CBA the sprite palettes' colours shifted 16 times (33/A46A); 32/8CA7 faded out (FFA87)
sm_cyc:     ld b, 16
.l:         push bc
            ld hl, W7 + $7CF7 + $10
            ld c, 4
.p:         inc hl
            ld b, 3
.q:         ld a, [hl]
            ld d, a
            and $F0
            ld e, a
            ld a, d
            add a, 2
            and $0F
            or e
            ld d, a
            and $CF
            ld e, a
            ld a, d
            add a, $10
            and $30
            or e
            ld [hl+], a
            dec b
            jr nz, .q
            dec c
            jr nz, .p
            call ba_vblc
            pop bc
            dec b
            jr nz, .l
            ret
sm_fade:    ld b, 16
.l:         push bc
            call ba_vblc
            ld hl, W7 + $7CF7 + $10
            ld b, 16
.c:         ld a, [hl]
            cp $0F
            jr z, .n
            ld c, a
            and $30
            ld a, $0F
            jr z, .s
            ld a, c
            sub $10
.s:         ld [hl], a
.n:         inc hl
            dec b
            jr nz, .c
            pop bc
            dec b
            jr nz, .l
            ret
; general palette A (00/9100: colours 1-3) -> FF3 palette byte C.. C + 2; A kept
sm_pal:     push af
            ld l, a
            ld h, high(BD_GPAL)
            ld b, 3
.c:         push bc
            push hl
            ld a, BDATA_BANK
            call rd_byte
            pop hl
            pop bc
            push hl
            ld e, c
            ld d, 0
            ld hl, W7 + $7CF7
            add hl, de
            ld [hl], a
            pop hl
            inc h
            inc c
            dec b
            jr nz, .c
            pop af
            ret
; 33/BF1E / BF24 animation graphics A (+ HL) as btlfx.s's mx_gfx (CODE9's own: HL is passed)
sm_gfx0:    ld hl, 0
sm_gfx:     ld [sm_t], a
            push hl
            ld e, a
            add a, a
            add a, e
            add a, a
            ld e, a
            ld d, 0
            ld hl, $BEB2 - $4000            ; (33/BEB2 from CODE8's copy)
            add hl, de
            ld de, sm_g
            ld bc, 6
            ld a, CODE8
            call rd_copy
            ld a, [sm_g]
            ld c, a
            ld a, [sm_g + 1]
            ld b, a
            ld a, [sm_g + 2]
            ld e, a
            ld a, [sm_g + 3]
            add a, $70
            ld d, a
            ld a, [sm_g + 4]
            ld [sm_t], a
            ld a, [sm_g + 5]
            cp $15
            ld a, MAGG
            jr z, .b
            ld a, MGFX_BANK0 + 4
.b:         ld [vc_src], a
            pop hl
            add hl, bc
            ld a, h
            sub $40
            ld h, a
            ld a, 1
            ld [ba_dirty], a
            ld a, [sm_t]
            ld b, a
            push bc
            ld a, 1
            call vcopyx
            pop bc
            ld a, b
            srl a
            srl a
            dec a
            ret z
            ret c
            ld b, a
.w:         push bc
            call mx_wait
            pop bc
            dec b
            jr nz, .w
            ret

section wram, $DF64                 ; (free: between fx_b and btl_atk)
sm_x:       ds 1
sm_y:       ds 1
sm_n:       ds 1
sm_w:       ds 1
sm_h:       ds 1
sm_t:       ds 1
sm_x0:      ds 1
sm_y0:      ds 1
sm_fl:      ds 1
