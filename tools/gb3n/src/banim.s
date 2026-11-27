; FF3's battle animations (banks $2F / $32 / $33) as native code, bank B_BSCR. Tables from the
; ROM (build.py ROMDATA): an_blob = 32/943D-97B1 (the animation sprites' layouts, their flips,
; the frame records 950E (tile group, layout, x, y) and the tile groups 968A), the slice hit
; (32/99D1 positions, 99E9 tiles, 9968 masks), the weapons' animation / graphics / palette
; (2E/9098), the most hits shown per animation (33/A077), the animation by action (34/83F8).
; Graphics: the weapon's 8 tiles from NES 2B/B000 (bank B_ANIM) at OBJ $49 (right) / $51 (left),
; the character's 16 animation tiles (its job's from tile 14) at OBJ $39 (2F/A9CF).
; Animation sprites take OAM entries 24-39.

AN_REC     = an_blob + ($950E - $943D)
AN_TILES   = an_blob + ($968A - $943D)
AN_FLIP    = an_blob + ($9503 - $943D)
AN_OAM     = oam_buf + 4 * 24

section bank B_BANIM, $4000
; calls into the battle screen's bank (BC, DE kept)
xb_party:   ld hl, bs_party
xb_go:      ld a, B_BSCR
            jp far_call
xb_jobaddr: ld hl, bs_jobaddr
            jr xb_go
xb_vrows:   ld hl, bs_vrows
            jr xb_go
xb_srect:   ld hl, bs_srectx
            jr xb_go
; HL += A
an_hla:     add l
            ld l, a
            ret nc
            inc h
            ret
; ---- the animation of the action ($7EC2 -> 34/83F8): A = FF3's attack animation id

; ---- battle graphics $12, a character's fight (2F/B24F, 33/A0C0): stepping forward, each hand's
; swings (8 frames a hit: arm back, then forward with the hit on the target), back
an_fight:   ld a, [$D8D6]
            ld [an_c], a
            ld a, [$DE99]                   ; the target slot (34/86AB)
            call an_slot
            ld [an_t], a
            call an_cgfx                    ; the character's animation tiles
            call an_wgfx                    ; the weapons' tiles and palettes (2F/A8EA)
            call an_savepal
            ld a, [$D8D6]
            ld [bs_act], a
            call xb_party
            ld a, [an_c]                    ; confused: no hits shown (33/A6C3)
            add a
            ld hl, $D8BB
            call an_hla
            bit 3, [hl]
            jr z, .nc
            xor a
            ld [BZ + $BB], a
            ld [BZ + $BC], a
.nc:        xor a                           ; right hand first, then the left
            ld [an_h], a
            ld a, [an_t1]
            call an_hand
            ld a, 1
            ld [an_h], a
            ld a, [an_t2]
            call an_hand
            call an_restpal
            ld a, $FF
            ld [bs_act], a
            jp xb_party

; one hand (33/A094): A = its animation (0 fist .. 9 claw); hits limited to 33/A077's - 1
an_hand:    ld [an_a], a
            ld hl, an_max
            call an_hla
            ld b, [hl]
            ld a, [an_h]
            add low(BZ + $BB)
            ld l, a
            ld h, high(BZ)
            ld a, [hl]
            cp b
            jr c, .n
            ld a, b
            dec a
            ld [hl], a
.n:         ld [an_n], a                    ; FF3's $BD
            ld a, [an_a]
            cp 1
            jr z, an_blade
            cp 2
            jr z, an_blunt
            and a
            jr z, an_fist
            cp 9
            jr z, an_claw
            ret                             ; (bows, harp, boomerang, moon, shuriken: later)
; 0: no weapon: a claw swing unless the other hand holds one (33/A2F2)
an_fist:    ld a, [$DE1F]
            ld hl, $DE20
            or [hl]
            ret nz
; 9: claw (33/A2FB): the attacker's frame 4 / $0D with random hits (hit animation 2)
an_claw:
.k:         ld a, $0A                       ; (FF3's sound $8A)
            call bs_sfx
            xor a
            ld [an_f], a
.f:         call an_clr
            ld a, [an_h]
            and a
            ld a, 5
            ld c, 4
            jr z, .r
            ld a, 6
            ld c, $0D
.r:         push bc
            call an_cframe                  ; (33/A2D9: the attacker's frame)
            call an_r01                     ; random 0 / 1 offsets (33/A44F)
            ld [an_ox], a
            call an_r01
            ld [an_oy], a
            pop bc
            ld a, c
            call an_mypos                   ; the frame at the attacker + offsets
            ld a, [an_ox]
            add d
            ld d, a
            ld a, [an_oy]
            add e
            ld e, a
            ld a, c
            ld b, 0
            call an_spr
            ld a, 2
            call an_hit
            call an_frame
            ld a, [an_f]
            and 8
            jr z, .f
            jp an_next
; 1: axe, spear, knife, sword (slice); 2: nunchaku, rod, staff, hammer (33/A365, A379)
an_blade:   xor a
            jr an_swing
an_blunt:   ld a, 1
an_swing:   ld [an_hk], a
            call an_hitpal                  ; (33/A438: the hand's palette)
.k:         xor a
            ld [an_f], a
            ld [an_b9], a
            ld a, $36                       ; (FF3's sound $B6)
            call bs_sfx
.f:         call an_clr
            ld a, [an_f]
            and 4
            jr nz, .fw
            ld a, [an_h]                    ; arm back: right frame 5 / weapon 0, left 7 / 2
            and a
            ld a, 5
            ld c, 0
            jr z, .b
            ld a, 7
            ld c, 2
.b:         call an_cframe
            ld a, c
            call an_wspr
            jr .w
.fw:        ld a, [an_h]                    ; forward: right 1 / 1, left 6 / 3, and the hit
            and a
            ld a, 1
            ld c, 1
            jr z, .b2
            ld a, 6
            ld c, 3
.b2:        call an_cframe
            ld a, c
            call an_wspr
            ld a, [an_hk]
            call an_hit
.w:         call an_frame
            ld a, [an_f]
            and 8
            jr z, .f
            jp an_next
; the next hit, or done (33/A3D2): passes = the hits, at least one
an_next:    ld a, [an_n]
            and a
            jr z, .x
            dec a
            ld [an_n], a
            jr z, .x
            ld a, [an_a]
            cp 9
            jp z, an_claw.k
            and a
            jp z, an_claw.k
            jp an_swing.k
.x:         call an_clr                     ; (33/AC35)
            ld a, $FF
            ld [an_cf], a
            call xb_party
            jp an_frame

; the attacker's frame A this frame (keeps BC)
an_cframe:  ld [an_cf], a
            push bc
            call xb_party
            pop bc
            ret
; the weapon's animation sprite frame A at the attacker (33/A3EB)
an_wspr:    push af
            call an_mypos
            pop af
            ld b, 0
            jp an_spr
; DE = the attacker's place on the screen (x, y)
an_mypos:   ld a, [an_c]
            ld b, a
            add a
            add a
            add a
            ld e, a
            add a
            add e
            ld e, a                         ; 24 i
            ld d, 136                       ; (stepped forward)
            ret
; two random bits (33/A44F & 1: FF3's rng 0)
an_r01:     xor a
            ld [BZ + $21], a
            ld b, 0
            ld a, $FF
            call b_rndx
            and 1
            ret

; ---- battle graphics $14, a member hit (2F/B201, 33/A8B8): its hit pose (job tiles 30-35 at OBJ
; $39; toad / mini frame $0F), knocked back, shaken four times, back; a critical hit knocks
; further with its own sound. (The GB's party column is at the screen's edge: the knock-back is
; half FF3's, 4 / 8 pixels.)
an_chit:    ld a, [BZ + $BB]                ; (no hits: nothing)
            ld hl, BZ + $BC
            or [hl]
            ret z
            ld a, [$DE99]
            call an_slot
            cp 4
            ret nc
            ld [an_hc], a
            ld [an_c], a
            ld c, a
            call xb_jobaddr                 ; the hit tiles (2F/A9B1)
            ld a, [bs_ja]
            ld l, a
            ld a, [bs_ja + 1]
            ld h, a
            ld de, 30 * 16
            add hl, de
            ld de, $8000 + 16 * $39
            ld bc, 6 * 16
            ld a, B_CGFX
            call an_vcopy
            ld a, [BZ + $CB]
            and a
            ld b, 4
            ld a, $30                       ; (FF3's sound $B0; a critical hit $C6)
            jr z, .s
            ld b, 8
            ld a, $46
.s:         push bc
            call bs_sfx
            ld a, [an_hc]                   ; frame 4 (toad / mini $0F)
            add a
            ld hl, $D8BB
            call an_hla
            ld a, [hl]
            and 5
            ld a, 4
            jr z, .f
            ld a, $0F
.f:         ld [an_cf], a
            pop bc
            ld a, b
            ld [an_dx], a
            call .w2
            ld b, 4
.k:         push bc
            ld hl, an_dx
            inc [hl]
            call .w2
            ld hl, an_dx
            dec [hl]
            call .w2
            pop bc
            dec b
            jr nz, .k
            xor a
            ld [an_dx], a
            ld a, $FF
            ld [an_cf], a
            ld [an_hc], a
.w2:        call xb_party                   ; two frames
            call an_frame
            jp an_frame

; ---- a hit animation (32/97B2): A = 0 slice, 1 blunt, 2 claw; none for a hand without hits; a
; critical hit flashes the backdrop orange once ($CB, $B7)
an_hit:     ld [an_k], a
            ld a, [an_h]
            add low(BZ + $BB)
            ld l, a
            ld h, high(BZ)
            ld a, [hl]
            and a
            ret z
            ld a, [an_k]
            and a
            jr z, an_slice
            dec a
            ld c, $10
            jr z, .bl
            ld c, $12
.bl:        ld a, [an_h]                    ; (32/98E0 / 98D1: frame $10 / $12, +1 left)
            add c
            ld [an_hf], a
            ld a, [an_f]                    ; a new place every other frame (32/98E8)
            rra
            jr c, .p
            call an_tcen
            ld a, d
            sub 16
            ld d, a
            ld a, e
            sub 16
            ld e, a
            push de
            xor a
            ld [BZ + $21], a
            ld b, 0
            ld a, $FF
            call b_rndx
            and $1F
            pop de
            push af
            add d
            ld [an_bx], a
            push de
            xor a
            ld [BZ + $21], a
            ld b, 0
            ld a, $FF
            call b_rndx
            and $1F
            pop de
            add e
            ld [an_by], a
            pop af
.p:         ld a, [an_bx]
            ld d, a
            ld a, [an_by]
            ld e, a
            ld a, [an_hf]
            ld b, 0
            jp an_spr
; 0: slice (32/991F): 12 sprites in a diagonal from the target's centre, two pairs a frame
an_slice:   call an_tcen
            ld a, e
            add 8
            ld e, a
            ld a, [an_b9]
            ld hl, sl_mask
            call an_hla
            ld a, [hl]
            ld [an_k], a
            ld hl, an_b9
            inc [hl]
            ld hl, sl_pos
            ld bc, sl_tile
            ld a, 6
.pr:        push af
            ld a, [an_k]
            add a
            ld [an_k], a
            jr c, .skip
            call .one
            call .one
            jr .nx
.skip:      inc hl
            inc hl
            inc hl
            inc hl
            inc bc
            inc bc
.nx:        pop af
            dec a
            jr nz, .pr
            ret
.one:       push hl                         ; x, y offsets; the tile (+8 left), palette 3
            ld a, [hl+]
            add d
            add 8
            ld [an_ox], a
            ld a, [hl]
            add e
            add 17
            ld [an_oy], a
            ld a, [bc]
            and a
            jr z, .t
            push hl
            ld hl, an_h
            bit 0, [hl]
            pop hl
            jr z, .t
            add 8
.t:         ld [an_k2], a
            push bc
            call an_slot_oam
            jr c, .full
            ld a, [an_oy]
            ld [hl+], a
            ld a, [an_ox]
            ld [hl+], a
            ld a, [an_k2]
            ld [hl+], a
            ld [hl], $0B
.full:      pop bc
            pop hl
            inc hl
            inc hl
            inc bc
            ret

; ---- an animation sprite frame (32/9357): A = frame, B = flipped, (D, E) = the place; four
; sprites from the frame record's layout and tile group, palette 3 (the attacker's for frames 4
; and $0D)
an_spr:     ld [an_k], a
            ld a, b
            ld [an_fl], a
            ld a, [an_k]
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            ld bc, AN_REC
            add hl, bc
            ld a, [hl+]
            add a
            add a
            ld [an_ti], a                   ; the tile group x 4
            ld a, [hl+]
            ld c, a                         ; the layout
            ld a, [an_fl]
            and a
            ld a, [hl+]
            jr z, .x
            cpl                             ; flipped: x the other way, the flipped layout
            inc a
            push hl
            push af
            ld a, c
            ld hl, AN_FLIP
            call an_hla
            ld c, [hl]
            pop af
            pop hl
.x:         add d
            ld d, a
            ld a, [hl]
            add e
            ld e, a
            ld a, c                         ; HL = the layout (NES pointer - $943D)
            add a
            ld hl, an_blob
            call an_hla
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld bc, an_blob - $943D
            add hl, bc
            ld a, [an_k]                    ; palette
            cp 4
            jr z, .cp
            cp $0D
            jr nz, .p3
.cp:        ld a, [an_c]
            push hl
            ld hl, $DD93
            call an_hla
            ld a, [hl]
            pop hl
            and 3
            jr .pa
.p3:        ld a, 3
.pa:        ld [an_pal], a
            ld b, 4
.s:         push bc
            push hl
            call an_slot_oam
            ld b, h
            ld c, l
            pop hl
            jr c, .full
            ld a, [hl+]                     ; y
            add e
            add 17
            ld [bc], a
            inc bc
            inc hl                          ; (the layout's tile: 32/968A's instead)
            ld a, [hl+]                     ; flags
            ld [an_k2], a
            ld a, [hl+]                     ; x
            add d
            add 8
            ld [bc], a
            inc bc
            push hl
            ld a, [an_ti]
            ld hl, AN_TILES
            call an_hla
            ld a, [hl]
            ld [bc], a
            inc bc
            ld hl, an_ti
            inc [hl]
            ld a, [an_k2]                   ; NES flags -> the Color's: flips, palette, bank 1
            and $C0
            rra
            ld hl, an_pal
            or [hl]
            or $08
            ld [bc], a
            pop hl
            pop bc
            dec b
            jr nz, .s
            ret
.full:      pop bc
            ret

; the next free animation OAM entry -> HL (C: none left)
an_slot_oam: ld hl, AN_OAM
            ld a, [an_bgm]                  ; (the party in the BG: any free entry)
            and a
            jr z, .l
            ld hl, oam_buf
.l:         ld a, [hl]
            and a
            ret z
            ld a, l
            add 4
            ld l, a
            cp low(oam_buf + 160)
            jr nz, .l
            scf
            ret
; the animation sprites off
an_clr:     ld hl, AN_OAM
            ld b, 64
            xor a
.l:         ld [hl+], a
            dec b
            jr nz, .l
            ld a, [an_bgm]                  ; (and the entries of members in the BG)
            and a
            ret z
            ld c, a
            ld hl, oam_buf
.m:         ld b, 24
            srl c
            jr nc, .k
            xor a
.z:         ld [hl+], a
            dec b
            jr nz, .z
            jr .n
.k:         ld a, l
            add 24
            ld l, a
.n:         ld a, c
            and a
            jr nz, .m
            ret
; a frame of the animation (FF3's $F8B0 + $8AE6): V-Blank, the windows' rows, sprites, sound
an_frame:   call wait_vbl
            call xb_vrows
            call hram_dma
            call snd_frame
            call read_pad
            ld hl, an_f
            inc [hl]
            ret
; the target's centre (FF3's $7DD7 / $7DD8) on the screen -> D, E
an_tcen:    ld a, [an_t]
            ld [fl_s], a
            call xb_srect
            ld de, $4030
            ld a, [an_src]
            rra
            ret c
            ld a, [fl_x]
            add a
            add a
            add a
            ld d, a
            ld a, [fl_w]
            add a
            add a
            add d
            ld d, a
            ld a, [fl_y]
            add a
            add a
            add a
            ld e, a
            ld a, [fl_h]
            add a
            add a
            add e
            ld e, a
            ret
; A = the slot of the bit set in mask A (34/86AB), 0 if none
an_slot:    ld b, 0
.l:         add a
            jr c, .x
            inc b
            ld c, a
            ld a, b
            cp 8
            ld a, c
            jr c, .l
            ld b, 0
.x:         ld a, b
            ret
; a sound effect A (work RAM bank 1 for the driver's request)
bs_sfx:     push af
            ld a, 1
            ldh [rSVBK], a
            pop af
            call sfx_play
            ld a, 2
            ldh [rSVBK], a
            ret
; BC bytes from bank A at HL to VRAM bank 1 DE, behind the line guard
an_vcopy:   push af
            push hl
            push de
            push bc
            call wait_vbl
            ld a, 1
            ld [guard_on], a
            ld a, $20
            ldh [rSTAT], a
            ld a, 1
            ldh [rVBK], a
            pop bc
            pop de
            pop hl
            pop af
            call far_copy
            xor a
            ldh [rVBK], a
            ldh [rSTAT], a
            ld [guard_on], a
            ret
; the attacker's 16 animation tiles: its job's from tile 14 to OBJ $39 (2F/A9CF)
an_cgfx:    ld a, [an_c]
            ld c, a
            call xb_jobaddr
            ld a, [bs_ja]
            ld l, a
            ld a, [bs_ja + 1]
            ld h, a
            ld de, 14 * 16
            add hl, de
            ld de, $8000 + 16 * $39
            ld bc, 16 * 16
            ld a, B_CGFX
            jp an_vcopy
; the weapons (2F/A8EA): animation, graphics (8 tiles from 2B/B000 + 16 g: right at OBJ $49, left
; $51), palette
an_wgfx:    ld a, [$DE1F]
            ld de, $8000 + 16 * $49
            call .one
            ld [an_t1], a
            ld a, b
            ld [an_p1], a
            ld a, [$DE20]
            ld de, $8000 + 16 * $51
            call .one
            ld [an_t2], a
            ld a, b
            ld [an_p2], a
            ret
.one:       ld l, a
            ld h, 0
            ld b, h
            ld c, l
            add hl, hl
            add hl, bc
            ld bc, wp_prop
            add hl, bc
            ld a, [hl+]
            push af
            ld a, [hl+]
            ld c, [hl]
            push bc
            ld l, a                         ; tiles: 16 x g bytes
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld bc, $4000
            add hl, bc
            ld bc, 8 * 16
            ld a, B_ANIM
            call an_vcopy
            pop bc
            ld b, c
            pop af
            ret
; OBJ palette 3 from the hand's weapon palette (33/A438 -> AB08: FF3's general palette, colours
; 1-3), V-Blank
an_hitpal:  ld a, [an_h]
            and a
            ld a, [an_p1]
            jr z, an_gpal3
            ld a, [an_p2]
; OBJ palette 3, colours 1-3, from FF3's general palette A (V-Blank)
an_gpal3:   ld e, a
            ld d, 0
            push de
            call wait_vbl
            pop de
            ld a, $80 | 3 * 8 + 2
            ldh [rOCPS], a
            ld hl, A_GPAL
            call .c
            ld hl, A_GPAL + $100
            call .c
            ld hl, A_GPAL + $200
.c:         add hl, de
            push de
            ld a, B_MAPAUX
            call far_byte
            and $3F
            add a
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
            pop de
            ret
; OBJ palette 3 kept / put back (the cursor's)
an_savepal: call wait_vbl
            ld hl, an_sp
            ld c, 0
.l:         ld a, c
            or $80 | 3 * 8
            and $BF
            ldh [rOCPS], a
            ldh a, [rOCPD]
            ld [hl+], a
            inc c
            ld a, c
            cp 8
            jr nz, .l
            ret
an_restpal: call wait_vbl
            ld a, $80 | 3 * 8
            ldh [rOCPS], a
            ld hl, an_sp
            ld b, 8
.l:         ld a, [hl+]
            ldh [rOCPD], a
            dec b
            jr nz, .l
            ret

; ---- battle graphics $1D, magic (2F/B15E): a character steps forward and casts (33/B09B: the
; spell's properties 2E/91D0, black / white graphics set 5 / 6, the spell's palette as OBJ
; palette 3; black: the cast pose, the hands' frames 33/B1D7 and the bubbles over the caster 44
; frames; white: the stars circling 48 frames, then closing in; ineffective: the pose 32 frames)
an_magic:   ld a, [$D8D6]
            ld [an_c], a
            ld [bs_act], a
            call an_cgfx
            call an_mprop
            ld a, [an_m0]
            rlca
            and 1
            add 5
            call an_lgfx
            call an_savepal
            ld a, [an_m2]
            call an_gpal3
            xor a
            ld [an_f], a
            ld a, [BZ + $CC]                ; ineffective: the pose only
            and a
            jr z, .bw
.in:        call an_cast
            call an_frame
            ld a, [an_f]
            cp $20
            jr nz, .in
            jr .x
.bw:        ld a, $21                       ; (FF3's sound $A1)
            call bs_sfx
            ld a, [an_m0]
            bit 7, a
            jr nz, .wh
.bk:        call an_cast                    ; black
            ld a, [an_f]
            rra
            rra
            and $3F
            ld hl, mg_blk
            call an_hla
            ld a, [hl]
            call an_wspr0
            call an_bubbles
            call an_frame
            ld a, [an_f]
            cp $2C
            jr nz, .bk
            jr .x
.wh:        ld b, 8                         ; white: 8 stars at distance 16, round the circle
            ld hl, an_vd
            xor a
.v:         ld [hl], $10
            inc hl
            ld [hl+], a                     ; (angle: y from 32 i, x from $40 + 32 i)
            push af
            add $40
            ld [hl+], a
            pop af
            add $20
            dec b
            jr nz, .v
.w:         call an_cast
            ld a, [an_f]
            rra
            rra
            and $3F
            ld hl, mg_wht
            call an_hla
            ld a, [hl]
            call an_wspr0
            call an_stars
            call an_frame
            ld a, [an_f]
            cp $30
            jr nz, .w
.cl:        call an_cast                    ; closing in
            call an_stars
            ld hl, an_vd
            ld b, 8
.d:         dec [hl]
            inc hl
            inc hl
            inc hl
            dec b
            jr nz, .d
            call an_frame
            ld a, [an_vd]
            and a
            jr nz, .cl
.x:         call an_proj
            call an_clr
            ld a, $FF
            ld [an_cf], a
            ld [bs_act], a
            call xb_party
            call an_mhit
            call an_restpal
            jp xb_party
; ---- the spell's projectile (33/B276): a member's spell on monsters, not ineffective: from the
; caster (x - 16, y + 8) one sprite (tile $58, v-flipped every other two frames) to each target
; at 16 pixels a frame, gone at the target; then 10 frames. (FF3 aims by angle tables made for
; its NES layout, 33/A7D7; here the line runs to the target's centre on the GB's layout.)
; an_vd: per target dx, dy (signed), frames (0: none)
an_proj:    ld a, [$DE9A]
            and $C0
            cp $40
            ret nz
            ld a, [BZ + $CC]
            and a
            ret nz
            ld a, [an_c]                    ; the start
            ld b, a
            add a
            add b
            add a
            add a
            add a
            add 8
            ld [an_py], a
            ld a, [$DE99]
            ld [an_tm], a
            xor a
            ld [an_t], a
            ld [an_pn], a
            ld hl, an_vd
.t:         push hl
            ld a, [an_tm]
            add a
            ld [an_tm], a
            jr nc, .z
            call an_tcen
            ld a, AN_PX                     ; dx (none if the target is not to the left)
            sub d
            jr nc, .dx
            xor a
.dx:        ld [an_ox], a
            ld b, a
            ld a, e
            sub 4
            ld hl, an_py
            sub [hl]
            ld [an_oy], a                   ; dy
            bit 7, a
            jr z, .ay
            cpl
            inc a
.ay:        ld d, a                         ; |dy|; length ~ max + min / 2
            ld a, b
            cp d
            jr nc, .mx
            ld e, b
            ld b, d
            ld d, e
.mx:        srl d
            ld a, b
            add d
            jr nc, .ln
            ld a, $FF
.ln:        add 15
            jr nc, .l2
            ld a, $FF
.l2:        swap a
            and $0F
            jr nz, .nn
            inc a
.nn:        ld c, a                         ; frames
            pop hl
            push hl
            ld a, [an_ox]
            ld [hl+], a
            ld a, [an_oy]
            ld [hl+], a
            ld a, c
            ld [hl], a
            ld hl, an_pn
            cp [hl]
            jr c, .z0
            ld [hl], a
            jr .z0
.z:         xor a                           ; (no target)
            ld [hl+], a
            ld [hl+], a
            ld [hl], a
.z0:        pop hl
            inc hl
            inc hl
            inc hl
            ld a, [an_t]
            inc a
            ld [an_t], a
            cp 8
            jr nz, .t
            ld a, [an_pn]
            and a
            ret z
            ld a, 1
            ld [an_k3], a
.f:         call an_cast
            ld hl, an_vd
            ld b, 8
.o:         push bc
            push hl
            ld a, [an_k3]
            ld b, a
            ld a, [hl+]
            ld d, a                         ; dx
            ld a, [hl+]
            ld c, a                         ; dy
            ld a, [hl]
            ld e, a                         ; frames
            cp b
            jr c, .on                       ; (gone at its target)
            call an_pspr
.on:        pop hl
            inc hl
            inc hl
            inc hl
            pop bc
            dec b
            jr nz, .o
            call an_frame
            ld hl, an_k3
            inc [hl]
            ld a, [an_pn]
            cp [hl]
            jr nc, .f
            ld b, 10
.w:         push bc
            call an_cast
            call an_frame
            pop bc
            dec b
            jr nz, .w
            ret
; the sprite at frame k (B) of E: (AN_PX - D k / E, an_py + C k / E)
an_pspr:    push bc
            ld a, d
            call .sc
            ld b, a
            ld a, AN_PX
            sub b
            ld [an_ox], a
            pop bc
            ld a, c
            bit 7, a
            jr z, .p
            cpl
            inc a
            call .sc
            cpl
            inc a
            jr .y
.p:         call .sc
.y:         ld hl, an_py
            add [hl]
            ld [an_oy], a
            call an_slot_oam
            ret c
            ld a, [an_oy]
            add 17
            ld [hl+], a
            ld a, [an_ox]
            add 8
            ld [hl+], a
            ld a, $58
            ld [hl+], a
            ld a, [an_k3]
            add a
            add a
            add a
            add a
            add a
            and $40
            or $0B
            ld [hl], a
            ret
; A * B / E
.sc:        push de
            push bc
            ld c, e
            ld e, b
            call mul8                       ; HL = A * E
            ld b, 16                        ; HL / C
            xor a
.d:         add hl, hl
            rla
            cp c
            jr c, .n
            sub c
            inc l
.n:         dec b
            jr nz, .d
            ld a, l
            pop bc
            pop de
            ret
AN_PX      = 136 - 16

; ---- the party in the BG while a large effect runs (the GB has 40 sprites, FF3's spell frames
; take up to 36 besides the party's 24): each member standing on whole cells clear of windows
; is copied into the BG (its six tiles to VRAM bank 1 BG tiles $90 + 6 c.., its palette to BG
; palette 2 + p), its sprites hidden; the effect may then use every free entry. an_bgoff puts
; the sprites back first, then the monster area's cells.
an_bgon:    xor a
            ld [an_bgm], a
            call wait_vbl                   ; OBJ palettes 0-3 -> BG palettes 2-5
            ld c, 0
.p:         ld a, c
            ldh [rOCPS], a
            ldh a, [rOCPD]
            ld b, a
            ld a, c
            add 16
            ldh [rBCPS], a
            ld a, b
            ldh [rBCPD], a
            inc c
            ld a, c
            cp 32
            jr nz, .p
            ld a, 1
            ld [guard_on], a
            ld a, $20
            ldh [rSTAT], a
            ld c, 0
.c:         push bc
            call an_bgok
            pop bc
            jr c, .n
            push bc
            call an_bgch
            pop bc
            ld a, c
            ld hl, bit_rev
            call an_hla
            ld a, [an_bgm]
            or [hl]
            ld [an_bgm], a
.n:         inc c
            ld a, c
            cp 4
            jr nz, .c
            call an_bgw
            xor a
            ldh [rSTAT], a
            ld [guard_on], a
            call an_clr                     ; the sprites off
            jp an_frame
bit_rev:    db 1, 2, 4, 8
; member C's six entries (oam_buf + 24 C): C set if one is off the cells or on a window
an_bgok:    ld a, c
            add a
            ld b, a
            add a
            add b
            add a
            add a
            ld l, a
            ld h, high(oam_buf)
            ld b, 6
.e:         ld a, [hl+]
            and a
            jr z, .s3
            sub 16
            ld d, a
            and 7
            jr nz, .no
            ld a, [hl]
            sub 8
            ld e, a
            and 7
            jr nz, .no
            ld a, d
            cp 96
            jr nc, .no
            ld a, e
            cp 128
            jr c, .no
            cp 160
            jr nc, .no
            push hl
            call an_cell
            ld a, [hl]
            ld de, MON_T - SH_T
            add hl, de
            cp [hl]
            pop hl
            jr nz, .no
.s3:        inc hl
            inc hl
            inc hl
            dec b
            jr nz, .e
            and a
            ret
.no:        scf
            ret
; HL = SH_T + 20 (D / 8) + E / 8
an_cell:    ld a, d
            rrca
            rrca
            rrca
            and $1F
            ld l, a
            add a
            add a
            add l                           ; 5 row
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl                      ; 20 row
            ld a, e
            rrca
            rrca
            rrca
            and $1F
            call an_hla
            ld a, h
            add high(SH_T)
            ld h, a
            ld a, l
            add low(SH_T)
            ld l, a
            ret nc
            inc h
            ret
; member C into the BG (under the guard)
an_bgch:    ld a, c
            add a
            ld b, a
            add a
            add b
            ld [an_bgt], a                  ; 6 C
            add a
            add a
            ld l, a
            ld h, high(oam_buf)
            ld b, 6
.e:         push bc
            ld a, [hl+]
            and a
            jr z, .sk
            sub 16
            ld d, a
            ld a, [hl+]
            sub 8
            ld e, a
            ld a, [hl+]                     ; tile -> BG tile $90 + 6 C + j (bank 1)
            ld c, a
            ld a, [hl]
            ld [an_bga], a
            push hl
            push de
            ld l, c
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, $8000
            add hl, de
            ld a, [an_bgt]
            add $90
            ld [an_bgi], a
            ld e, a
            ld d, 0
            sla e
            rl d
            sla e
            rl d
            sla e
            rl d
            sla e
            rl d
            ld a, d
            add $80
            ld d, a
            ld a, 1
            ldh [rVBK], a
            ld b, 16
.cp:        ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .cp
            xor a
            ldh [rVBK], a
            pop de
            call an_cell                    ; the cell
            ld a, [an_bgi]
            ld [hl], a
            ld bc, SH_A - SH_T
            add hl, bc
            ld a, [an_bga]
            and $67
            add 2
            or $08
            ld [hl], a
            pop hl
            inc hl
            jr .nx
.sk:        inc hl
            inc hl
            inc hl
.nx:        ld a, [an_bgt]
            inc a
            ld [an_bgt], a
            pop bc
            dec b
            jr nz, .e
            ret
; the sprites back (bs_party), then the cells (MON_T, rows 0-11 columns 16-19)
an_bgoff:   ld a, [an_bgm]
            and a
            ret z
            xor a
            ld [an_bgm], a
            call xb_party
            call an_frame
            ld hl, SH_T + 16
            ld de, MON_T + 16
            ld b, 12
.r:         push bc
            ld b, 4
.c:         ld a, [de]
            ld [hl], a
            push hl
            push de
            ld bc, SH_A - SH_T
            add hl, bc
            ld a, e                         ; (MON_A - MON_T = 240)
            add 240
            ld e, a
            ld a, d
            adc 0
            ld d, a
            ld a, [de]
            ld [hl], a
            pop de
            pop hl
            inc hl
            inc de
            dec b
            jr nz, .c
            ld a, l
            add 16
            ld l, a
            jr nc, .r1
            inc h
.r1:        ld a, e
            add 16
            ld e, a
            jr nc, .r2
            inc d
.r2:        pop bc
            dec b
            jr nz, .r
            call wait_vbl
            ld a, 1
            ld [guard_on], a
            ld a, $20
            ldh [rSTAT], a
            call an_bgw
            xor a
            ldh [rSTAT], a
            ld [guard_on], a
            ret
; the cells of rows 0-11, columns 16-19 to VRAM (under the guard)
an_bgw:     ld hl, SH_T + 16
            ld de, $9800 + 16
            ld c, 12
.r:         push hl
            push de
            ld b, 4
.t:         ld a, [hl+]
            ld [de], a
            inc e
            dec b
            jr nz, .t
            pop de
            pop hl
            push hl
            push de
            ld a, 1
            ldh [rVBK], a
            ld a, l
            add low(SH_A - SH_T)
            ld l, a
            ld a, h
            adc high(SH_A - SH_T)
            ld h, a
            ld b, 4
.a:         ld a, [hl+]
            ld [de], a
            inc e
            dec b
            jr nz, .a
            xor a
            ldh [rVBK], a
            pop de
            pop hl
            ld a, l
            add 20
            ld l, a
            jr nc, .h
            inc h
.h:         ld a, e
            add 32
            ld e, a
            jr nc, .h2
            inc d
.h2:        dec c
            jr nz, .r
            ret
; the spell $7E88's graphics properties (33/AF6F: 2E/91D0)
an_mprop:   ld a, [$DE88]
            ld l, a
            ld h, 0
            ld b, h
            ld c, l
            add hl, hl
            add hl, bc
            ld bc, mg_prop
            add hl, bc
            ld a, [hl+]
            ld [an_m0], a
            ld a, [hl+]
            ld [an_m1], a
            ld a, [hl]
            ld [an_m2], a
            ret
; a monster's spell (2F/B15E: no casting, the hit only)
an_mmon:    call an_mprop
            call an_savepal
            ld a, [an_m2]
            call an_gpal3
            call an_mhit
            jp an_restpal

; ---- the spell's hit animation (33/B68D) on each target hit ($7E9B): its 24 tiles (2A/9600 or
; 2B/A600 by property 0 bit 6, from property 1) and set 8; its frame list (06/8C00): per entry
; a 6 x 6 frame (00/9708; bit 7 h-flip, $FF before: v-flip), 4 frames each, at the target (a
; monster: its centre - (24, 16); a member: (x - 16, y - 12), 12 higher for property 0 bit 5, 8
; left for Life). Life on no one shows on the missed targets; on someone, without its last 16
; frames. The spell's sound (34/83A0) with the first target. Blank tiles take no sprite.
; Animation types other than normal (0), Life (5), Break (7), Toad (8) and Mini (13) have their
; own routines (33/BC2B) and are not shown here yet.
an_mhit:    ld a, [$DE9D]
            ld c, 0
            and a
            jr z, .ty
            cp 7
            jr z, .ty
            cp 8
            jr z, .ty
            cp 13
            jr z, .ty
            cp 5
            ret nz
            ld a, [$DE9B]                   ; Life (33/B922)
            and a
            ld c, 16
            jr nz, .ty
            ld a, [$DE99]
            ld [$DE9B], a
            ld c, 0
.ty:        ld a, c
            ld [an_lskip], a
            ld a, [$DE9B]
            and a
            ret z
            ld [an_tm], a
            ld a, [BZ + $CC]                ; (ineffective: the pose only)
            and a
            ret nz
            ld a, [an_m0]                   ; the tiles (33/B589)
            and $40
            ld hl, $4000 + $1600
            jr z, .g
            ld hl, $4000 + $2600
.g:         ld a, [an_m1]
            ld e, a
            ld d, 0
            sla e
            rl d
            sla e
            rl d
            sla e
            rl d
            sla e
            rl d
            add hl, de
            ld de, $8000 + 16 * $49
            ld bc, 24 * 16
            ld a, B_MAGIC
            call an_vcopy
            ld a, 8
            call an_lgfx
            call an_bgon
            ld a, [$DE88]                   ; the list
            add a
            ld l, a
            ld a, 0
            adc $4E
            ld h, a
            ld de, an_lp
            ld bc, 2
            ld a, B_ANIM
            call far_copy
            ld a, [$DE88]                   ; the sound
            cp MG_NSND
            jr nc, .ns
            ld hl, mg_snd
            call an_hla
            ld a, [hl]
            call bs_sfx
.ns:        xor a
            ld [an_t], a
.t:         ld a, [an_tm]
            add a
            ld [an_tm], a
            jr nc, .nx
            call an_mone
.nx:        ld hl, an_t
            inc [hl]
            ld a, [hl]
            cp 8
            jr nz, .t
            call an_clr
            call an_frame
            jp an_bgoff
; target an_t: the list's frames
an_mone:    ld a, [$DE9A]                   ; the place
            bit 6, a
            jr z, .ch
            call an_tcen
            ld a, d
            sub 24
            ld [an_bx], a
            ld a, e
            sub 16
            ld [an_by], a
            jr .go
.ch:        ld a, [an_t]
            ld b, a
            add a
            add b
            add a
            add a
            add a
            sub 12
            ld e, a
            ld a, [an_m0]
            bit 5, a
            jr z, .e
            ld a, e
            sub 12
            ld e, a
.e:         ld a, e
            ld [an_by], a
            ld b, 144 - 16
            ld a, [$DE9D]
            cp 5
            ld a, b
            jr nz, .x
            sub 8
.x:         ld [an_bx], a
.go:        ld hl, 0                        ; the list's length (less Life's last 16)
            call .byte
            ld hl, an_lskip
            sub [hl]
            ret c
            ret z
            ld [an_n], a
            ld a, 1
            ld [an_k3], a
.f:         ld c, 0                         ; C = the flips (33/B7CF)
            call .cur
            cp $FF
            jr nz, .nf
            ld c, 2
            ld hl, an_k3
            inc [hl]
            call .cur
.nf:        ld b, a
            rlca
            and 1
            or c
            ld c, a
            ld a, [$DE9A]                   ; a member: flipped the other way (33/B7CB)
            bit 6, a
            jr nz, .mf
            ld a, c
            xor 1
            ld c, a
.mf:        ld a, c
            ld [an_fl], a
            ld a, b
            and $7F
            call an_mframe
            ld b, 4
.w:         push bc
            call an_frame
            pop bc
            dec b
            jr nz, .w
            ld hl, an_k3
            inc [hl]
            ld a, [an_n]
            inc a
            cp [hl]
            jr nz, .f
            ret
.cur:       ld a, [an_k3]
            ld l, a
            ld h, 0
.byte:      ld a, [an_lp]
            add l
            ld l, a
            ld a, [an_lp + 1]
            adc h
            ld h, a
            ld a, B_ANIM
            jp far_byte
; frame A (00/9708) at (an_bx, an_by), flips an_fl (33/B8AF): 36 tiles (rvhttttt, r: repeated by
; the next byte) in a 6 x 6 grid from 33/B89B's corner and steps; tile $7F blank, else + $49
an_mframe:  add a
            ld l, a
            ld h, $4D
            ld de, an_fp
            ld bc, 2
            ld a, B_ANIM
            call far_copy
            call an_clr
            ld a, [an_fl]                   ; x0, dx, y0, dy
            add a
            add a
            ld hl, mf_grid
            call an_hla
            ld a, [hl+]
            ld [an_gx0], a
            ld [an_gx], a
            ld a, [hl+]
            ld [an_gdx], a
            ld a, [hl+]
            ld [an_gy], a
            ld a, [hl]
            ld [an_gdy], a
            ld a, [an_fl]
            ld hl, mf_flip
            call an_hla
            ld a, [hl]
            ld [an_gfl], a
            xor a
            ld [an_cnt], a
            ld [an_rep], a
.l:         ld a, [an_rep]                  ; a repeated tile still going
            and a
            jr nz, .rp
            call .next
            bit 7, a
            jr z, .one
            ld [an_cur], a
            call .next
            ld [an_rep], a
.rp:        ld hl, an_rep
            dec [hl]
            ld a, [an_cur]
            jr .put
.one:       ld [an_cur], a
.put:       call .spr
            ld hl, an_cnt
            inc [hl]
            ld a, [hl]
            cp 36
            ret z
            ld a, [an_gx]                   ; the next column / row
            ld hl, an_gdx
            add [hl]
            ld [an_gx], a
            ld a, [an_cnt]
.m6:        sub 6
            jr z, .row
            jr nc, .m6
            jr .l
.row:       ld a, [an_gx0]
            ld [an_gx], a
            ld a, [an_gy]
            ld hl, an_gdy
            add [hl]
            ld [an_gy], a
            jr .l
.next:      ld a, [an_fp]
            ld l, a
            ld a, [an_fp + 1]
            ld h, a
            ld a, B_ANIM
            call far_byte
            ld hl, an_fp
            inc [hl]
            ret nz
            inc hl
            inc [hl]
            ret
.spr:       ld b, a                         ; (33/B866)
            and $7F
            cp $7F
            ret z
            call an_slot_oam
            ret c
            ld a, [an_gy]
            ld c, a
            ld a, [an_by]
            add c
            add 17
            ld [hl+], a
            ld a, [an_gx]
            ld c, a
            ld a, [an_bx]
            add c
            add 8
            ld [hl+], a
            ld a, b
            and $1F
            add $49
            ld [hl+], a
            ld a, b                         ; the tile's flips xor the frame's; NES -> Color bits
            add a
            and $C0
            ld c, a
            ld a, [an_gfl]
            xor c
            and $C0
            rra
            or $0B
            ld c, a
            ld a, [$DE9A]                   ; a member target: behind the party (NES order)
            cpl
            and $40
            add a
            or c
            ld [hl], a
            ret

; the cast pose (33/AF9F: frame 8, toad / mini $0E)
an_cast:    call an_clr
            ld a, [an_c]
            add a
            ld hl, $D8BB
            call an_hla
            ld a, [hl]
            and 5
            ld a, 8
            jr z, .p
            ld a, $0E
.p:         jp an_cframe
; animation frame A at the caster (no offset: 32/9299)
an_wspr0:   push af
            call an_mypos
            pop af
            ld b, 0
            jp an_spr
; the bubbles (33/B1F8): a 4 x 4 block over the caster from 33/AEB2's tiles and flips, the second
; set every other two frames
an_bubbles: call an_mypos
            ld a, [an_f]
            and 2
            add a
            add a
            add a                           ; 0 / 16
            ld c, a
            ld b, 0
.l:         push bc
            push de
            call an_slot_oam
            jr c, .full
            ld a, b                         ; y = 8 (i / 4) - 4
            srl a
            srl a
            add a
            add a
            add a
            sub 4
            add e
            add 17
            ld [hl+], a
            ld a, b                         ; x = 8 (i & 3) - 8
            and 3
            add a
            add a
            add a
            sub 8
            add d
            add 8
            ld [hl+], a
            ld a, c
            add b
            push hl
            ld hl, mg_bub
            call an_hla
            ld a, [hl]
            pop hl
            ld e, a
            and $0F
            add $49
            ld [hl+], a
            ld a, e
            and $C0
            rra
            or $0B
            ld [hl], a
            pop de
            pop bc
            inc b
            ld a, b
            cp 16
            jr nz, .l
            ret
.full:      pop de
            pop bc
            ret
; the white magic stars (33/B134): 8 at the caster's (x + 4, y + 6) + the vectors; tile $49, palette
; 3, flipped by the frame / 4 and the star; each angle on 4
an_stars:   call an_mypos
            ld a, d
            add 4
            ld [an_ox], a
            ld a, e
            add 6
            ld [an_oy], a
            ld hl, an_vd
            ld c, 0
.l:         push bc
            push hl
            ld a, [hl+]
            ld [an_k], a                    ; distance
            ld a, [hl+]                     ; y angle
            ld b, a
            ld a, [hl]
            ld [an_k2], a                   ; x angle
            ld a, b
            call an_smul
            ld hl, an_oy
            add [hl]
            add 17
            ld [an_by], a
            ld a, [an_k2]
            call an_smul
            ld hl, an_ox
            add [hl]
            add 8
            ld [an_bx], a
            call an_slot_oam
            jr c, .n
            ld a, [an_by]
            ld [hl+], a
            ld a, [an_bx]
            ld [hl+], a
            ld a, $49
            ld [hl+], a
            ld a, [an_f]
            rra
            rra
            pop de                          ; (the star's index from the stack)
            pop bc
            push bc
            push de
            xor c
            and 1
            rrca
            rrca                            ; vertical flip: bit 6
            or $0B
            ld [hl], a
.n:         pop hl
            inc hl                          ; angles + 4
            ld a, [hl]
            add 4
            ld [hl+], a
            ld a, [hl]
            add 4
            ld [hl+], a
            pop bc
            inc c
            ld a, c
            cp 8
            jr nz, .l
            ret
; A = sin(angle A) x [an_k] (33/BFC6: 256 sin, its size x 2 x the distance / 256, the sign kept)
an_smul:    ld hl, an_sin
            call an_hla
            ld a, [hl]
            bit 7, a
            jr z, .p
            cpl
            call .m
            cpl
            inc a
            ret
.p:
.m:         add a
            ld e, a
            ld a, [an_k]
            ld d, a
            xor a
            ld b, 8
.ml:        srl e
            jr nc, .ms
            add d
.ms:        rra
            dec b
            jr nz, .ml
            ret
; animation graphics set A (33/BF1E, table made by build.py in B_ANIM $4F00)
an_lgfx:    add a
            add a
            ld l, a
            ld h, $4F
            ld de, an_tmp
            ld bc, 4
            ld a, B_ANIM
            call far_copy
            ld a, [an_tmp + 3]
            and a
            ret z
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld b, h
            ld c, l
            ld a, [an_tmp + 2]
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, $8000
            add hl, de
            ld d, h
            ld e, l
            ld a, [an_tmp]
            ld l, a
            ld a, [an_tmp + 1]
            ld h, a
            ld a, B_ANIM
            jp an_vcopy

section bank B_BANIM, $7000
an_blob:    ds $375                         ; (32/943D-97B1)
mg_prop:    ds 3 * $60                      ; (2E/91D0)
mg_blk:     ds 11                           ; (33/B1D7)
mg_wht:     ds 12                           ; (33/B1E2)
mg_bub:     ds 32                           ; (33/AEB2)
mf_grid:    ds 16                           ; (33/B89B)
mf_flip:    ds 4                            ; (33/B8AB)
mg_snd:     ds MG_NSND                      ; (34/83A0: each spell's sound)
MG_NSND    = $58
sl_pos:     ds 24                           ; (32/99D1)
sl_tile:    ds 12                           ; (32/99E9)
sl_mask:    ds 4                            ; (32/9968)
an_max:     ds 9                            ; (33/A077)
an_ids:     ds 25                           ; (34/83F8)
wp_prop:    ds 3 * $60                      ; (2E/9098)

section bank B_BANIM, $7F00
an_sin:     ds 256                          ; (10/9A80)

section wram, $CD00
an_c:       ds 1
an_t:       ds 1
an_h:       ds 1
an_a:       ds 1
an_n:       ds 1
an_f:       ds 1
an_b9:      ds 1
an_hk:      ds 1
an_k:       ds 1
an_k2:      ds 1
an_fl:      ds 1
an_ti:      ds 1
an_tg:      ds 1
an_pal:     ds 1
an_hf:      ds 1
an_bx:      ds 1
an_by:      ds 1
an_ox:      ds 1
an_oy:      ds 1
an_cf:      ds 1
an_t1:      ds 1
an_t2:      ds 1
an_p1:      ds 1
an_p2:      ds 1
an_sp:      ds 8
an_hc:      ds 1
an_m0:      ds 1
an_m1:      ds 1
an_lskip:   ds 1
an_src:     ds 1
an_bgm:     ds 1
an_bgt:     ds 1
an_bga:     ds 1
an_bgi:     ds 1
an_pn:      ds 1
an_py:      ds 1
an_lp:      ds 2
an_fp:      ds 2
an_gfl:     ds 1
an_tm:      ds 1
an_k3:      ds 1
an_gx0:     ds 1
an_gdx:     ds 1
an_gx:      ds 1
an_gy:      ds 1
an_gdy:     ds 1
an_cnt:     ds 1
an_rep:     ds 1
an_cur:     ds 1
an_m2:      ds 1
an_tmp:     ds 4
an_vd:      ds 24                           ; 8 x (distance, y angle, x angle)
an_dx:      ds 1
