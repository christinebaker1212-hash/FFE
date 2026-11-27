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

section bank B_BSCR, $6A00
; ---- the animation of the action ($7EC2 -> 34/83F8): A = FF3's attack animation id
an_kind:    ld a, [$DEC2]
            ld hl, an_ids
            call bs_hl_a
            ld a, [hl]
            ret

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
            call bs_party
            ld a, [an_c]                    ; confused: no hits shown (33/A6C3)
            add a
            ld hl, $D8BB
            call bs_hl_a
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
            jp bs_party

; one hand (33/A094): A = its animation (0 fist .. 9 claw); hits limited to 33/A077's - 1
an_hand:    ld [an_a], a
            ld hl, an_max
            call bs_hl_a
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
            call bs_party
            jp an_frame

; the attacker's frame A this frame (keeps BC)
an_cframe:  ld [an_cf], a
            push bc
            call bs_party
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
            call bs_jobaddr                 ; the hit tiles (2F/A9B1)
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
            call bs_hl_a
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
.w2:        call bs_party                   ; two frames
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
            call bs_hl_a
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
            call bs_hl_a
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
            call bs_hl_a
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
            call bs_hl_a
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
            call bs_hl_a
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
            ret
; a frame of the animation (FF3's $F8B0 + $8AE6): V-Blank, the windows' rows, sprites, sound
an_frame:   call wait_vbl
            call bs_vrows
            call hram_dma
            call snd_frame
            call read_pad
            ld hl, an_f
            inc [hl]
            ret
; the target's centre (FF3's $7DD7 / $7DD8) on the screen -> D, E
an_tcen:    ld a, [an_t]
            ld [fl_s], a
            call bs_srect
            ld de, $4030
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
            call bs_jobaddr
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
            jr z, .p
            ld a, [an_p2]
.p:         ld e, a
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

section bank B_BSCR, $7600
an_blob:    ds $375                         ; (32/943D-97B1)
sl_pos:     ds 24                           ; (32/99D1)
sl_tile:    ds 12                           ; (32/99E9)
sl_mask:    ds 4                            ; (32/9968)
an_max:     ds 9                            ; (33/A077)
an_ids:     ds 25                           ; (34/83F8)
wp_prop:    ds 3 * $60                      ; (2E/9098)

section wram, $CECC
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
an_dx:      ds 1
