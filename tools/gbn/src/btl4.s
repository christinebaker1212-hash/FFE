; FF1 native engine: battle animations (bank 6). Our own code, written from what FF1's
; battle drawing does (disassembly bank 0C: SetNaturalPose, DrawCharacter, CharacterWalkAnimation,
; WalkForwardAndStrike, PrepAttackSprite_A/BFrame, DoMagicFlash, DrawExplosions, the enemy
; erase, BattleScreenShake, PlayFanfareAndCheer); graphics and the pose tables from the ROM
; (battle.obj_bank). No blinking of members, targets or enemies (owner's decision): FF1's
; FlashCharacterSprite is left out.
;
; Sprites: OAM 0-3 the cursor or the weapon / spell graphic, 4-27 the members (6 each),
; 28-39 the explosions. The weapon / spell / explosion tiles are staged into tiles
; BT_FX ($D8-$EF: the message window's rows 3-4, unused while an animation runs: at most
; two message rows show then).

BOBJ_BANK  = 96
BO_DMG     = $4000
BO_CGB     = $4800
BO_POSE    = $5000          ; FF1 lut_CharacterPoseTSA (8 x 4)
BO_SWING   = $5020          ; FF1 lut_WeaponSwingTSA (2 x 8)
BT_FX      = $D8            ; weapon / spell A frame ($D8), spell B frame ($DC), explosions
BT_FXE     = $E0            ;   ($E0 / $E4 / $E8 for FF1's $F4 / $F8 / $FC)
P_STAND    = $00            ; FF1's poses (TSA offsets)
P_WALK     = $04
P_ATKB     = $08
P_ATKF     = $0C
P_CHEER    = $10
P_CROUCH   = $18
P_DEAD     = $80            ; (ours: the lying graphic)
P_STONE    = $40            ; (ours: crouching in the stone palette)

section bank 6, $6D00

; ---- FF1 SetNaturalPose for every member, then all drawn
bt_party_upd:
            xor a
.m:         push af
            call bt_natural
            pop af
            push af
            call bt_dm
            pop af
            inc a
            cp 4
            jr c, .m
            ret

; FF1 SetNaturalPose: dead lying, stone, poison / paralysis / sleep or HP under a quarter of
; the maximum crouching, else standing; x back in the column
bt_natural: push af
            ld e, a
            ld d, 0
            ld hl, bt_px
            add hl, de
            ld [hl], PARTY_X
            pop af
            push de
            call ch_rec
            pop de
            inc hl
            ld a, [hl]
            ld b, P_DEAD
            bit 0, a                        ; (AIL_DEAD)
            jr nz, .s
            ld b, P_STONE | P_CROUCH
            bit 1, a                        ; (AIL_STONE)
            jr nz, .s
            ld b, P_CROUCH
            and AIL_POISON | AIL_STUN | AIL_SLEEP
            jr nz, .s
            dec hl
            ld a, l
            add a, CH_MAXHP
            ld l, a
            ld a, [hl+]                     ; max / 4
            ld c, a
            ld a, [hl]
            srl a
            rr c
            srl a
            rr c
            dec hl
            dec hl
            ld a, [hl-]                     ; HP high: over 255 standing
            and a
            ld b, P_STAND
            jr nz, .s
            ld a, [hl]
            cp c
            jr nc, .s
            ld b, P_CROUCH
.s:         ld hl, bt_pose
            add hl, de
            ld [hl], b
            ret

; ---- FF1 DrawCharacter: member A at (bt_px, 24 A) in its pose -> OAM 4 + 6 A
bt_dm:      ld [bt_at], a
            ld e, a
            ld d, 0
            ld hl, bt_px
            add hl, de
            ld a, [hl]
            add a, 8
            ld b, a                         ; B = OAM x
            ld a, e
            add a, a
            add a, e
            add a, a
            add a, a
            add a, a
            ld c, a
            add a, 16
            ld [bt_ay], a                   ; OAM y
            ld a, c                         ; OAM 4 + 6 A: oam_buf + 16 + 24 A
            add a, 16
            ld l, a
            ld h, high(oam_buf)
            push hl
            ld a, e
            call ch_rec
            ld e, [hl]
            ld d, 0
            ld hl, cls_pal
            add hl, de
            ld a, [hl]
            ld [bt_aa], a                   ; attributes: the class's palette (CGB)
            ld a, [bt_at]
            ld e, a
            ld hl, bt_pose
            add hl, de
            ld a, [hl]
            pop hl
            bit 7, a
            jr nz, .dead
            bit 6, a
            jr z, .np
            push af                         ; stone: FF1's grey palette (CGB 3, DMG OBP1)
            ldh a, [is_cgb]
            and a
            ld a, $10
            jr z, .sp
            ld a, 3
.sp:        ld [bt_aa], a
            pop af
.np:        and $1F
            push hl
            ld e, a
            ld d, 0
            ld hl, bt_tsa
            add hl, de
            ld d, h
            ld e, l
            pop hl
            ld a, [bt_at]                   ; tiles: 32 A + the TSA's
            swap a
            add a, a
            ld [bt_t + 15], a
            ld a, [bt_ay]
            ld c, a
            ld a, 3
.r:         push af
            ld a, [de]
            inc de
            push de
            ld d, a
            ld a, [bt_t + 15]
            add a, d
            ld d, a
            call .two
            pop de
            ld a, c
            add a, 8
            ld c, a
            pop af
            dec a
            jr nz, .r
            ret
.two:       ld a, c                         ; two sprites: (B, C) and (B + 8, C), tiles D, D + 1
            ld [hl+], a
            ld a, b
            ld [hl+], a
            ld a, d
            ld [hl+], a
            ld a, [bt_aa]
            ld [hl+], a
            ld a, c
            ld [hl+], a
            ld a, b
            add a, 8
            ld [hl+], a
            ld a, d
            inc a
            ld [hl+], a
            ld a, [bt_aa]
            ld [hl+], a
            ret
.dead:      ld a, [bt_at]                   ; lying: tiles 32 A + $1A, 3 x 2, a tile left and
            swap a                          ;   one lower (FF1)
            add a, a
            add a, $1A
            ld d, a
            ld a, b
            sub 8
            ld b, a
            ld a, [bt_ay]
            add a, 8
            ld c, a
            ld e, 2
.dr:        ld a, c
            ld [hl+], a
            ld a, b
            ld [hl+], a
            ld a, d
            ld [hl+], a
            ld a, [bt_aa]
            ld [hl+], a
            ld a, c
            ld [hl+], a
            ld a, b
            add a, 8
            ld [hl+], a
            ld a, d
            inc a
            ld [hl+], a
            ld a, [bt_aa]
            ld [hl+], a
            ld a, c
            ld [hl+], a
            ld a, b
            add a, 16
            ld [hl+], a
            ld a, d
            add a, 2
            ld [hl+], a
            ld a, [bt_aa]
            ld [hl+], a
            ld a, d
            add a, 3
            ld d, a
            ld a, c
            add a, 8
            ld c, a
            dec e
            jr nz, .dr
            ret

; two frames (FF1 UpdateSprites_TwoFrames)
bt_2f:      call bt_frame
            jp bt_frame

; ---- FF1 CharacterWalkAnimation: member A walks 8 pixels (B = -2 left / 2 right), 2 pixels
; every 2 frames, the walking pose every other step
bt_walk:    ld [bt_am], a
            ld a, b
            ld [bt_ad], a
            ld a, 4
.l:         push af
            and 2                           ; stand / walk
            add a, a
            ld b, a
            ld a, [bt_am]
            ld e, a
            ld d, 0
            ld hl, bt_pose
            add hl, de
            ld [hl], b
            ld hl, bt_px
            add hl, de
            ld a, [bt_ad]
            add a, [hl]
            ld [hl], a
            ld a, [bt_am]
            call bt_dm
            call bt_2f
            pop af
            dec a
            jr nz, .l
            ret
; command input: the member steps forward / back (walking)
bt_step_fwd:
            ld b, -2
            jr bt_walk
bt_step_back:
            push af
            ld b, 2
            call bt_walk
            pop af
            call bt_natural
            ld a, [bt_am]
            jp bt_dm

; ---- the variable palette (FF1 UpdateVariablePalette): A = colour c, B = 0 weapon (c,
; c - $10, c - $20), 1 spell (c, c - $10, white); CGB OBJ palette 2 colours 1-3
bt_vpal:    ld [bt_vc], a
            ld c, a
            ldh a, [is_cgb]
            and a
            ret z
            ld hl, scr_buf
            ld a, c
            ld [hl+], a
            sub $10
            ld [hl+], a
            dec b
            ld a, $30
            jr z, .k2
            ld a, c
            sub $20
.k2:        ld [hl], a
            call wait_vbl
            ld a, $80 | (2 * 8 + 2)
            ldh [rOCPS], a
            ld hl, scr_buf
            ld b, 3
.c:         ld a, [hl+]
            push hl
            push bc
            call nes_rgb                     ; DE = RGB555
            ld a, e
            ldh [rOCPD], a
            ld a, d
            ldh [rOCPD], a
            pop bc
            pop hl
            dec b
            jr nz, .c
            ret

; ---- tiles from the object graphics: A = first ($80-$FF), B = count, C = destination tile
bt_fxload:  push bc
            sub $80
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ldh a, [is_cgb]
            and a
            ld de, BO_DMG
            jr z, .d
            ld de, BO_CGB
.d:         add hl, de
            ld a, b
            swap a
            ld c, a
            and $0F
            ld b, a
            ld a, c
            and $F0
            ld c, a                         ; BC = 16 count
            push bc
            push hl
            call bt_flush                   ; (a previous upload first)
            pop hl
            pop bc
            ld de, bt_stage
            ld a, BOBJ_BANK
            call far_copy
            pop bc
            ld a, c                         ; staged: uploaded in the next V-Blanks
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, $8000
            add hl, de
            ld a, l
            ld [bt_updst], a
            ld a, h
            ld [bt_updst + 1], a
            ld a, low(bt_stage)
            ld [bt_upsrc], a
            ld a, high(bt_stage)
            ld [bt_upsrc + 1], a
            ld a, b
            ld [bt_upn], a
            jp bt_flush

; ---- FF1 WalkForwardAndStrike with a weapon: member A, graphic [bt_ag] (0: none drawn),
; palette colour [bt_ac]
bt_strike:  ld [bt_am], a
            ld a, [bt_ag]
            and a
            jr z, .nl
            ld b, 4                         ; the weapon's 4 tiles
            ld c, BT_FX
            call bt_fxload
            ld a, [bt_ac]
            ld b, 0
            call bt_vpal
.nl:        ld a, [bt_am]
            ld b, -2
            call bt_walk
            ld a, 8                         ; 8 x: A frame (arm forward, weapon left of the
.l:         push af                         ;   member) / B frame (arm back, weapon behind the
            and 2                           ;   head, its lower-left tile hidden)
            ld a, [bt_am]
            ld e, a
            ld d, 0
            ld hl, bt_pose
            add hl, de
            jr z, .b
            ld [hl], P_ATKF
            call bt_dm
            ld a, [bt_ag]
            and a
            jr z, .f
            ld a, [bt_am]
            call bt_mxy
            ld a, b
            sub 16
            ld b, a
            ld hl, bt_swing
            call bt_obj4
            jr .f
.b:         ld [hl], P_ATKB
            call bt_dm
            ld a, [bt_ag]
            and a
            jr z, .f
            ld a, [bt_am]
            call bt_mxy
            ld a, b
            add a, 8
            ld b, a
            ld a, c
            sub 8
            ld c, a
            ld hl, bt_swing + 8
            call bt_obj4
            ld a, $FF                       ; (FF1 hideLL)
            ld [oam_buf + 8], a
.f:         call bt_2f
            pop af
            dec a
            jr nz, .l
            call bt_obj_off
            call bt_frame
            ld a, [bt_am]
            ld e, a
            ld d, 0
            ld hl, bt_pose
            add hl, de
            ld [hl], P_STAND
            call bt_dm
            call bt_2f
            ld a, [bt_am]
            ld b, 2
            call bt_walk
            ld a, [bt_am]
            call bt_natural
            ld a, [bt_am]
            call bt_dm
            jp bt_2f

; ---- FF1 WalkForwardAndCastMagic: member A, spell graphic [bt_ag] (0: an item's spell, not
; drawn, no flash), colour [bt_ac]; the caster cheers, the spell's two frames beside it, the
; screen's background flashes the spell's colour (FF1 DoMagicFlash)
bt_cast_anim:
            ld [bt_am], a
            ld a, [bt_ag]
            and a
            jr z, .nl
            ld b, 8                         ; the spell's 8 tiles (two frames)
            ld c, BT_FX
            call bt_fxload
            ld a, [bt_ac]
            ld b, 1
            call bt_vpal
.nl:        ld a, [bt_am]
            ld b, -2
            call bt_walk
            ld a, 8
.l:         push af
            ld a, [bt_am]
            ld e, a
            ld d, 0
            ld hl, bt_pose
            add hl, de
            ld [hl], P_CHEER
            call bt_dm
            ld a, [bt_ag]
            and a
            jr z, .f
            pop af
            push af
            and 2                           ; frame A (tiles + 0) / B (+ 4)
            xor 2
            add a, a
            add a, BT_FX
            ld [bt_t + 14], a
            ld a, [bt_am]
            call bt_mxy
            ld a, b
            sub 16
            ld b, a
            call bt_obj16
            call bt_flash
.f:         call bt_2f
            pop af
            dec a
            jr nz, .l
            call bt_obj_off
            call bt_frame
            ld a, [bt_am]
            ld e, a
            ld d, 0
            ld hl, bt_pose
            add hl, de
            ld [hl], P_STAND
            call bt_dm
            call bt_2f
            ld a, [bt_am]
            ld b, 2
            call bt_walk
            ld a, [bt_am]
            call bt_natural
            ld a, [bt_am]
            call bt_dm
            jp bt_2f

; member A's OAM position -> B = x, C = y (OAM coordinates)
bt_mxy:     ld e, a
            ld d, 0
            ld hl, bt_px
            add hl, de
            ld a, [hl]
            add a, 8
            ld b, a
            ld a, e
            add a, a
            add a, e
            add a, a
            add a, a
            add a, a
            add a, 16
            ld c, a
            ret
; the weapon graphic (FF1's swing TSA at HL: 4 tiles, 4 attributes) at (B, C) -> OAM 0-3
bt_obj4:    ld de, oam_buf
            ld a, c                         ; y
            ld [de], a
            inc de
            ld a, b
            ld [de], a
            inc de
            call .tile
            ld a, c
            ld [de], a
            inc de
            ld a, b
            add a, 8
            ld [de], a
            inc de
            call .tile
            ld a, c
            add a, 8
            ld [de], a
            inc de
            ld a, b
            ld [de], a
            inc de
            call .tile
            ld a, c
            add a, 8
            ld [de], a
            inc de
            ld a, b
            add a, 8
            ld [de], a
            inc de
.tile:      ld a, [hl]                      ; tile BT_FX + TSA, attributes: FF1 $40 flip ->
            add a, BT_FX                    ;   GB $20; palette 2
            ld [de], a
            inc de
            push hl
            inc hl
            inc hl
            inc hl
            inc hl
            ld a, [hl]
            pop hl
            inc hl
            and $40
            srl a
            or 2
            ld [de], a
            inc de
            ret
; a 16 x 16 graphic, tiles [bt_t + 14] .. + 3 at (B, C), palette 2 -> OAM 0-3
bt_obj16:   ld hl, oam_buf
            ld a, [bt_t + 14]
            ld d, a
            ld e, 2
.r:         ld a, c
            ld [hl+], a
            ld a, b
            ld [hl+], a
            ld a, d
            ld [hl+], a
            inc d
            ld a, 2
            ld [hl+], a
            ld a, c
            ld [hl+], a
            ld a, b
            add a, 8
            ld [hl+], a
            ld a, d
            ld [hl+], a
            inc d
            ld a, 2
            ld [hl+], a
            ld a, c
            add a, 8
            ld c, a
            dec e
            jr nz, .r
            ret
bt_obj_off: xor a                           ; OAM 0-3 hidden
            ld [oam_buf], a
            ld [oam_buf + 4], a
            ld [oam_buf + 8], a
            ld [oam_buf + 12], a
            ret

; FF1 DoMagicFlash: a normal frame, two with the background colour flashed (the spell's colour;
; white becomes grey), then back (CGB: colour 0 of the BG palettes; DMG: black shown dark grey)
bt_flash:   call bt_frame
            ld a, [bt_vc]
            cp $20
            jr nz, .c
            ld a, $10
.c:         call .set
            call bt_frame
            ld a, $0F
.set:       ld c, a
            ldh a, [is_cgb]
            and a
            jr nz, .cgb
            call wait_vbl
            ld a, c
            cp $0F
            ld a, %11100100
            jr z, .d
            ld a, %10100100
.d:         call bgp_w
            ret
.cgb:       ld a, c
            call nes_rgb
            call wait_vbl
            ld b, 4
            ld c, $80
.p:         ld a, c
            call bcps_w
            ld a, e
            call bcpd_w
            ld a, d
            call bcpd_w
            ld a, c
            add a, 8
            ld c, a
            dec b
            jr nz, .p
            ret

; ---- FF1 DrawExplosions on enemy slot A: explosion graphics at random places on it, three
; at a time, a frame each (small 6 x 3, large 8 x 3, fiends / Chaos 20 x 3); FF1's RandAX
; (the battle RNG) for the graphic and the place
bt_explode: push af
            ld a, $F4                       ; (the graphics: message rows may have used them)
            ld b, 12
            ld c, BT_FXE
            call bt_fxload
            pop af
            ld e, a
            ld a, [bt_type]
            cp 3
            jr c, .one
            ld a, 24 + 8                    ; fiends / Chaos: NES x $20-$60, y $40-$78
            ld [bt_ex], a
            ld a, 88 + 8
            ld [bt_ex + 1], a
            ld a, 16 + 16
            ld [bt_ey], a
            ld a, 72 + 16
            ld [bt_ey + 1], a
            ld a, 20
            jr .go
.one:       ld a, e
            call bt_epos                    ; cell (B, C), size E
            ld a, b
            add a, a
            add a, a
            add a, a
            add a, 8
            ld [bt_ex], a
            ld d, a
            ld a, c
            add a, a
            add a, a
            add a, a
            add a, 16
            ld [bt_ey], a
            ld h, a
            ld a, e
            cp 6
            ld a, 24
            ld l, 6
            jr c, .sz
            ld a, 40
            ld l, 8
.sz:        ld b, a
            add a, d
            ld [bt_ex + 1], a
            ld a, b
            add a, h
            ld [bt_ey + 1], a
            ld a, l
.go:        ld [bt_exn], a
.l:         xor a
.s:         push af
            ld [bt_exs], a
            ld a, 0                         ; the graphic: $E0 + 4 random(0-2)
            ld b, 2
            call bt_randab
            add a, a
            add a, a
            add a, BT_FXE
            ld [bt_t + 14], a
            ld a, [bt_ex]
            ld b, a
            ld a, [bt_ex + 1]
            ld c, a
            ld a, b
            ld b, c
            call bt_randab
            ld [bt_t + 13], a
            ld a, [bt_ey]
            ld b, a
            ld a, [bt_ey + 1]
            ld c, a
            ld a, b
            ld b, c
            call bt_randab
            ld c, a
            ld a, [bt_t + 13]
            ld b, a
            ld a, [bt_exs]                   ; OAM 28 + 4 slot
            add a, a
            add a, a
            add a, a
            add a, a
            add a, 112
            ld l, a
            ld h, high(oam_buf)
            ld a, [bt_t + 14]
            ld d, a
            ld e, 2
.r:         ld a, c
            ld [hl+], a
            ld a, b
            ld [hl+], a
            ld a, d
            ld [hl+], a
            inc d
            ld a, 2
            ld [hl+], a
            ld a, c
            ld [hl+], a
            ld a, b
            add a, 8
            ld [hl+], a
            ld a, d
            ld [hl+], a
            inc d
            ld a, 2
            ld [hl+], a
            ld a, c
            add a, 8
            ld c, a
            dec e
            jr nz, .r
            call bt_frame
            pop af
            inc a
            cp 3
            jr c, .s
            ld hl, bt_exn
            dec [hl]
            jr nz, .l
            ld hl, oam_buf + 112            ; all gone, a frame
            ld b, 12
            xor a
.c:         ld [hl+], a
            inc l
            inc l
            inc l
            dec b
            jr nz, .c
            jp bt_frame

; ---- FF1 BattleScreenShake: 6 x (2 frames, then the scroll at random 0-3 / 0-3; the battle
; RNG), then the scroll back
bt_shake:   ld a, 6
.l:         push af
            call bt_2f
            call bt_rng
            and 3
            ldh [scx], a
            call bt_rng
            and 3
            ldh [scy], a
            pop af
            dec a
            jr nz, .l
            call bt_frame
            xor a
            ldh [scx], a
            ldh [scy], a
            jp bt_frame

; ---- FF1 PlayFanfareAndCheer: 64 x 2 frames, all cheering / standing by turns every 8
; (the dead and stone keep their pose)
bt_cheer:   ld a, $40
.l:         push af
            and 8
            add a, a                        ; P_CHEER / P_STAND
            ld c, a
            xor a
.m:         push af
            push bc
            ld e, a
            ld d, 0
            ld hl, bt_pose
            add hl, de
            ld a, [hl]
            and P_DEAD | P_STONE
            jr nz, .k
            ld [hl], c
.k:         pop bc
            pop af
            push af
            push bc
            call bt_dm
            pop bc
            pop af
            inc a
            cp 4
            jr c, .m
            call bt_2f
            pop af
            dec a
            jr nz, .l
            jp bt_party_upd

; ---- the enemy erased row by row, a frame each (FF1 EraseSmallEnemy and its kin)
bt_erase_rows:
            ld [bt_t + 4], a
            call bt_epos
            ld a, e
            ld [bt_t + 5], a
            ld d, e
.r:         push bc
            push de
            call cell_addr
.c:         call bt_bd_put                  ; (the scenery back in the strip)
            inc hl
            dec d
            jr nz, .c
            call bt_flush
            call wait_vbl
            pop de
            pop bc
            push bc
            push de
            ld a, c
            call sf_one
            pop de
            pop bc
            inc c
            ld hl, bt_t + 5
            dec [hl]
            jr nz, .r
            jp bt_bd_sgb                    ; (SGB: the strip's palettes again)

; ---- FF1 ChaosDeath: the fanfare's first 110 frames, the music stopped, a low rumble
; (noise period 15) fading out; 8 x 256 frames: each a random tile 0-$79 (FF1's RandAX on the
; battle RNG) loses one pixel row (per tile a random row, moved on each pass), the screen
; shaking by 0-3 pixels; then the rumble's booms, 2 seconds, silence
bt_chaos_death:
            ld a, 110
.w:         push af
            call bt_frame
            pop af
            dec a
            jr nz, .w
            ld a, $80
            call snd_track
            xor a
            ld [bt_cdn], a
            ld a, SND_BANK                  ; the noise's period ($0F: the lowest)
            ld hl, SFX_NZ + 15
            ld [fc_bank], a
            call far_byte
            ld [bt_cdp], a
            call bt_cd_noise
            ld hl, bt_line                  ; the rows to erase: 256 random values
            ld b, 0
.f:         call bt_rng
            ld [hl+], a
            dec b
            jr nz, .f
            ld a, 8
.o:         push af
            xor a
.i:         push af
            cp $80
            call z, bt_cd_noise
            xor a                           ; the tile: RandAX(0, $79)
            ld b, $79
            call bt_randab
            ld [bt_cdr], a
            ld l, a
            ld h, high(bt_line)
            ld a, [hl]
            and 7
            add a, a
            ld e, a                         ; VRAM $9000 + 16 tile + 2 row
            ld a, [bt_cdr]
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld d, 0
            add hl, de
            ld de, $9000
            add hl, de
            push hl
            call wait_vbl
            pop hl
            ldh a, [is_cgb]                 ; erased to the battlefield's black (CGB colour
            and a                           ;   0; DMG shade 3)
            ld a, $FF
            jr z, .e
            xor a
.e:         ld [hl+], a
            ld [hl], a
            ld a, [bt_cdq]                  ; shake: x from the previous value, y from this
            and 3
            ldh [scx], a
            ld a, [bt_cdr]
            ld [bt_cdq], a
            and 3
            ldh [scy], a
            pop af
            dec a
            jr nz, .i
            ld hl, bt_line                  ; each tile's row moves on
            ld b, 0
.n:         inc [hl]
            inc hl
            dec b
            jr nz, .n
            call bt_cd_noise
            pop af
            dec a
            jr nz, .o
            xor a
            ldh [scx], a
            ldh [scy], a
            ld a, 120                       ; 2 seconds of the booms
.b:         push af
            and $3F
            jr nz, .bn
            ld a, $F4                       ; (FF1's looping envelope: a boom a second)
            ldh [$FF21], a
            ld a, [bt_cdp]
            ldh [$FF22], a
            ld a, $80
            ldh [$FF23], a
.bn:        call wait_vbl
            pop af
            dec a
            jr nz, .b
            xor a
            ldh [$FF21], a
            ret
; FF1 ChaosDeath_FadeNoise: the rumble one step quieter (15, 14, .. 0)
bt_cd_noise:
            ld a, [bt_cdn]
            cp 16
            ret nc
            ld b, a
            inc a
            ld [bt_cdn], a
            ld a, 15
            sub b
            swap a
            ldh [$FF21], a                  ; constant volume
            and a
            ret z
            ld a, [bt_cdp]
            ldh [$FF22], a
            ld a, $80
            ldh [$FF23], a
            ret

section wram, $C700
bt_px:      ds 4                            ; members' x (screen)
bt_pose:    ds 4                            ; FF1 btl_chardraw_pose (+ P_DEAD / P_STONE)
bt_at:      ds 1
bt_ay:      ds 1
bt_aa:      ds 1
bt_am:      ds 1                            ; the animated member, direction
bt_ad:      ds 1
bt_ag:      ds 1                            ; weapon / spell graphic, colour
bt_ac:      ds 1
bt_vc:      ds 1
bt_ex:      ds 2                            ; explosion area (OAM coordinates), count, slot
bt_ey:      ds 2
bt_exn:      ds 1
bt_exs:      ds 1
bt_cdn:     ds 1                            ; (Chaos' dissolve: rumble step, period, tiles)
bt_cdp:     ds 1
bt_cdr:     ds 1
bt_cdq:     ds 1
bt_tsa:     ds 48                           ; the pose and swing tables (from the object bank)
bt_swing    = bt_tsa + $20
