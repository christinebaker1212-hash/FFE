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
            ld hl, W7 + $7D27               ; (the attribute table kept: $7440)
            ld de, W7 + $7440
            ld bc, $40
            call memcpy
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
.in:        call sm_draw
            call ba_vblc
            ld a, [sm_x]
            sub 8
            ld [sm_x], a
            jr nz, .in
            call sm_draw
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
.o:         call sm_draw
            call ba_vblc
            ld a, [sm_x]
            add a, 8
            ld [sm_x], a
            cp $50
            jr nz, .o
            call sm_draw
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
            jp s16_build

; ---- 32/8115 the attacks (summon x 3 + attack): for now the creature stays 48 frames, the
; summon's flash for those that flash, then goes
sm_attack:  ld b, 48
.w:         push bc
            call mx_wait
            pop bc
            dec b
            jr nz, .w
            ld a, [sm_fl]                   ; (the flash kept: the attribute table back)
            and a
            jr z, .o
            xor a
            ld [sm_fl], a
            ld hl, W7 + $7440
            ld de, W7 + $7D27
            ld bc, $40
            call memcpy
            xor a
            ld [W7 + $7E8F], a
            call attr_push
.o:         jp sm_out

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
