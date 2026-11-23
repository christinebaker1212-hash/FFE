; ---- battle animations (FF3 2F/AF4E battle graphics, 33 animation functions, 32 sprite helpers),
; bank CODE7: this code at $4000, NES 32/9400-9FFF at $5400 and 33 at $6000 (NES - $4000), so
; FF3's frame / sprite / hit tables are read where FF3 keeps them. Sprites are built in FF3's
; screen coordinates and placed for the GB layout: those of a member relative to its sprite in
; the party column (btlgfx chr_draw1), those on monsters by the battlefield's view; into OAM
; 24-39 (the damage numerals' slots: never at the same time). FF3's random calls in the
; animations (counter 0) are kept: the battle's later rolls depend on them, as on the NES.
N32        = -$4000             ; 32 / 33 address + N32 = the copy here
BA_OAM     = NUM_OAM            ; OAM 24-39
BD_AA      = $6F00              ; BDATA: 34/83F8 the attack animation ids
BA_TIL     = $39                ; FF3's sprite tiles: member animation $39-$48, weapons $49 / $51

; ---- 34/8411 show animation (action script $0B): FF3's attack animation id by $7EC2
; (34/83F8, + 1 for a summon's magic), then its routine; those not done yet: a pause
ba_show:    ld a, [W7 + $7E9A]              ; (FF3: rol x 3 through carry = bit 6)
            rlca
            rlca
            and 1
            ld [W7 + $7E6F], a              ; (the target a monster)
            ld a, [W7 + $7EC2]
            ld e, a
            ld d, 0
            ld hl, BD_AA                    ; (BDATA $6F00: 34/83F8)
            add hl, de
            call bd_rd
            cp 1
            jr nz, .s
            ld hl, W7 + $7EC3
            add a, [hl]
.s:         ld [W7 + $7E97], a
            and a
            jp z, ba_fightm
            cp 1
            jp z, mx_magic                  ; (btlfx.s)
            cp $10
            jp z, mx_ineff
            cp $0E
            jp c, mx_other                  ; (2-$0D: btlfx.s)
            ld b, 12                        ; (others: for now a pause)
.w:         call wait_vbl
            dec b
            jr nz, .w
            ret

; 34/8613 attack animation 0: fight
ba_fightm:  call ba_mpos
            xor a
            ld [W7 + $7E96], a
            ld a, [W7 + $7E98]              ; attacker id
            call ba_maskid
            ld [ba_att], a
            ld a, [W7 + $7E9A]
            bit 7, a
            jr z, .chr
            call ba_mflash                  ; a monster: its flash, then on a monster ($20) or a
            ld a, [W7 + $7E99]              ;   member ($14)
            call ba_maskid
            ld b, a
            ld a, [W7 + $7E6F]
            and a
            jr z, .mc
            ld a, b
            ld [BZ + $B8], a
            jp ba_g20
.mc:        ld a, b
            ld [BZ + $52], a
            jp ba_g14
.chr:       ld a, [ba_att]
            ld [BZ + $52], a
            ld [BZ + $95], a
            ld a, [W7 + $7E99]
            call ba_maskid
            ld b, a
            ld a, [W7 + $7E6F]
            and a
            jr z, .cc
            ld a, b                         ; a member on a monster
            ld [BZ + $B8], a
            jp ba_g12
.cc:        push bc                         ; a member on a member: the swing without hits,
            ld hl, W7 + $7E96               ;   then the target hit
            inc [hl]
            ld a, [BZ + $BB]
            push af
            ld a, [BZ + $BC]
            push af
            xor a
            ld [BZ + $BB], a
            ld [BZ + $BC], a
            call ba_g12
            pop af
            ld [BZ + $BC], a
            pop af
            ld [BZ + $BB], a
            pop bc
            ld a, b
            ld [BZ + $52], a
            ld a, [BZ + $BB]
            ld hl, BZ + $BC
            or [hl]
            ret z
            jp ba_g14
; 34/86AB the index of the bit set in A (attacker / target masks)
ba_maskid:  ld b, 0                         ; (FD24's order: $80 = 0, $40 = 1, ..)
.l:         add a, a
            jr c, .d
            inc b
            ld c, a
            ld a, b
            cp 8
            ld a, c
            jr nz, .l
.d:         ld a, b
            ret

; ---- 2F/B252 battle graphics $12: a member's fight
ba_g12:     ld a, [BZ + $95]
            call ba_stepf                   ; 2F/B38E
            call ba_cgfx                    ; 2F/A9CF
            call ba_wprop                   ; 2F/A8EA
            call ba_weapon                  ; 33/A0C0
            ld a, [BZ + $95]
            jp ba_stepb                     ; 2F/B3C7

; 2F/B38E / B352 the member steps forward / back: 16 (front row) or 32 (back row) pixels; a
; confused one the other way ($F0); then 33/BE9A the walk
ba_stepf:   xor a
            jr ba_step
ba_stepb:   ld a, 1
ba_step:    ld [W7 + $7D7D], a
            ld a, [BZ + $95]
            ld c, a
            ld b, 0
            ld hl, W7 + $7D9B
            add hl, bc
            add hl, bc
            ld a, [hl]
            and 8
            ld d, $F0
            jr z, .nc
            ld a, [W7 + $7D7D]              ; (confused: the other way, $F0)
            xor 1
            ld [W7 + $7D7D], a
            jr .go
.nc:        ld hl, W7 + $7D8F
            add hl, bc
            ld a, [hl]
            and 1
            ld d, $10
            jr z, .go
            ld d, $20
.go:        ld hl, W7 + $7D7F
            add hl, bc
            ld a, [W7 + $7D7D]              ; (step back: +, forward: -; FF3 compares the
            and a                           ;   direction after the confused swap only for the
            ld a, [hl]                      ;   distance's sign)
            jr nz, .b
            sub d
            jr .s
.b:         add a, d
.s:         ld [hl], a
            xor a
            ld [W7 + $7CF4], a
ba_walk:                                    ; (2F/AF30: all members to their $7D7F)
.mv:        ld c, 0                         ; 33/BE9A: each member a step, drawn, a frame
.m:         push bc
            call ba_move1
            pop bc
            inc c
            ld a, c
            cp 4
            jr nz, .m
            call chr_draw
            ld hl, W7 + $7CF4
            inc [hl]
            call wait_vbl
            ld c, 0                         ; until all are at their destinations
.d:         ld b, 0
            ld hl, BZ + $C0
            add hl, bc
            ld a, [hl]
            ld hl, W7 + $7D7F
            add hl, bc
            cp [hl]
            jr nz, .mv
            inc c
            ld a, c
            cp 4
            jr nz, .d
            ret
; 33/BD45 member C a step (2 pixels; toad / mini 2 / 1 with their hops), its walking frame
ba_move1:   ld b, 0
            ld hl, W7 + $7D7F
            add hl, bc
            ld a, [hl]
            ld hl, BZ + $C0
            add hl, bc
            cp [hl]
            ret z
            ld a, [W7 + $7D7D]
            and a
            ld d, $FF
            ld e, 0
            jr z, .sp
            ld d, 1
            ld e, $80
.sp:        ld hl, W7 + $7D9B
            add hl, bc
            add hl, bc
            ld a, [hl]
            push af
            and 5
            jr z, .norm
            and 4
            jr z, .mini
            pop af                          ; toad: hops (33/BDE9 / BDF1), 2 x speed
            ld a, [W7 + $7CF4]
            and 7
            push de
            ld e, a
            ld d, 0
            ld hl, $BDE9 + N32
            add hl, de
            ld a, [hl]
            ld hl, BZ + $C4
            add hl, bc
            add a, [hl]
            ld [hl], a
            ld hl, $BDF1 + N32
            add hl, de
            ld a, [hl]
            pop de
            or e
            ld hl, W7 + $7D83
            add hl, bc
            ld [hl], a
            jr .x2
.mini:      pop af                          ; mini: frames $0A / $0B, 1 x speed
            push af
            ld a, [W7 + $7CF4]
            and 4
            rrca
            rrca
            add a, $0A
            call .fr
            pop af
            ld hl, BZ + $C0
            add hl, bc
            ld a, [hl]
            add a, d
            ld [hl], a
            ret
.norm:      ld a, [W7 + $7CF4]              ; frames 1 / 2 every 4
            and 4
            rrca
            rrca
            inc a
            call .fr
            pop af
.x2:        ld hl, BZ + $C0
            add hl, bc
            ld a, [hl]
            add a, d
            add a, d
            ld [hl], a
            ret
.fr:        ld hl, W7 + $7D83               ; (A = frame; flipped when confused and not ...)
            add hl, bc
            ld [hl], a
            ld hl, W7 + $7DC1
            add hl, bc
            ld a, [hl]
            and a
            ret nz
            ld hl, W7 + $7D9B
            add hl, bc
            add hl, bc
            ld a, [hl]
            and 8
            ret z
            ld hl, W7 + $7D83
            add hl, bc
            ld a, [hl]
            xor $80
            ld [hl], a
            ret

; ---- graphics for the animation
; 2F/AB3D the member's graphics in CHGFX_BANK: job x $2A0 (toad $3F80, mini $3F00) -> HL (GB)
ba_cptr:    ld c, a
            ld b, 0
            ld hl, W7 + $7D9B               ; (2F/AB3D by $7D8B job; toad / mini by status)
            add hl, bc
            add hl, bc
            ld a, [hl]
            ld hl, $7F80
            bit 2, a
            ret nz
            ld hl, $7F00
            bit 0, a
            ret nz
            ld hl, W7 + $7D8B
            add hl, bc
            ld l, [hl]
            ld h, 0
            add hl, hl                      ; x $2A0 = x 672: x 32 x 21
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld d, h
            ld e, l
            add hl, hl
            add hl, hl
            add hl, de                      ; x 5
            add hl, hl
            add hl, hl                      ; x 20
            add hl, de                      ; x 21
            ld de, $4000
            add hl, de
            ret
; 2F/A9CF the member's animation tiles ($E0 on, 16) -> sprite tiles $39 (4 a frame as FF969)
ba_cgfx:    ld a, [BZ + $95]
            call ba_cptr
            ld de, $E0
            add hl, de
            ld b, 16
ba_tiles:   ld a, CHGFX_BANK
            ld de, $8000 + 16 * BA_TIL
ba_tiles2:  ld [vc_src], a
            ld a, 1                         ; (the numerals' tiles to be loaded again: sc_num)
            ld [ba_dirty], a
            push bc
            ld a, 1
            call vcopyx
            pop bc
            ld a, b                         ; (FF969: 4 tiles a frame)
            srl a
            srl a
            dec a
            ret z
            ret c
            ld b, a
.w:         call wait_vbl
            dec b
            jr nz, .w
            ret
; 2F/A963 the victory: each member's cheer tiles ($180 on, 6) -> $39 + 6 member
ba_vgfx:    ld c, 0
.l:         push bc
            ld b, 0
            ld hl, W7 + $7D8B
            add hl, bc
            ld a, [hl]
            inc a
            jr z, .n
            ld a, c
            call ba_cptr
            ld de, $180
            add hl, de
            pop bc
            push bc
            ld a, c
            add a, a
            add a, c
            add a, a
            add a, $39
            ld e, a
            ld d, 0
            push hl
            ld l, e
            ld h, d
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, $8000
            add hl, de
            ld d, h
            ld e, l
            pop hl
            ld b, 6
            ld a, CHGFX_BANK
            call ba_tiles2
.n:         pop bc
            inc c
            ld a, c
            cp 4
            jr nz, .l
            ret
; 2F/A9B1 the member's hit tiles ($1E0 on, 6) -> $39
ba_hgfx:    ld a, [BZ + $52]
            call ba_cptr
            ld de, $1E0
            add hl, de
            ld b, 6
            jr ba_tiles
; 2F/A8EA the weapons' animation types, graphics and palettes (2E/9098: 3 bytes a weapon) ->
; $7E1F / $7E20, tiles at $49 / $51 (2B/B000 + 16 graphic), $7E17 / $7E18
ba_wprop:   ld a, [W7 + $7E1F]
            call .one
            ld [W7 + $7E1F], a
            ld a, [ba_t + 1]
            ld [W7 + $7E13], a
            ld a, [ba_t + 2]
            ld [W7 + $7E14], a
            ld [W7 + $7E17], a
            ld a, [W7 + $7E20]
            call .one
            ld [W7 + $7E20], a
            ld a, [ba_t + 1]
            ld [W7 + $7E15], a
            ld a, [ba_t + 2]
            ld [W7 + $7E16], a
            ld [W7 + $7E18], a
            ld a, [W7 + $7E13]
            ld de, $8000 + 16 * $49
            call .gfx
            ld a, [W7 + $7E15]
            ld de, $8000 + 16 * $51
.gfx:       ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld bc, $4000
            add hl, bc
            ld b, 8
            ld a, CUTD2
            jp ba_tiles2
.one:       ld l, a                         ; 3 x weapon -> CUTD2 $5000 (2E/9098)
            ld h, 0
            ld d, h
            ld e, l
            add hl, hl
            add hl, de
            ld de, $5000
            add hl, de
            ld de, ba_t
            ld bc, 3
            ld a, CUTD2
            call rd_copy
            ld a, [ba_t]
            ret

; ---- 33/A0C0 animation function $04: the weapon animation (right hand, then left)
ba_weapon:  ld a, [BZ + $95]                ; (33/A6C3: confused -> no hits)
            ld c, a
            ld b, 0
            ld hl, W7 + $7D9B
            add hl, bc
            add hl, bc
            bit 3, [hl]
            jr z, .nc
            xor a
            ld [BZ + $BB], a
            ld [BZ + $BC], a
.nc:        xor a                           ; right hand first
            ld [BZ + $CD], a
            ld a, [W7 + $7E1F]              ; bow + arrow: the bow's hand alone
            cp 3
            jr nz, .a1
            ld a, [W7 + $7E20]
            cp 8
            jr nz, .nb
            xor a
            jr .ba
.a1:        cp 8
            jr nz, .nb
            ld a, [W7 + $7E20]
            cp 3
            jr nz, .nb
            ld a, 1
.ba:        ld [BZ + $CD], a
            call ba_bc                      ; 33/A24C
            ld a, 3
            jr ba_whand
.nb:        ld a, [W7 + $7E1F]              ; a harp: the right hand's hits for both
            cp 4
            jr z, .hp
            ld a, [W7 + $7E20]
            cp 4
            jr nz, .two
.hp:        call ba_bc
.two:       ld a, [W7 + $7E1F]
            call ba_whand
            ld a, 1
            ld [BZ + $CD], a
            ld a, [W7 + $7E20]
ba_bc:      ld a, [BZ + $BB]                ; 33/A24C
            ld [BZ + $BC], a
            ret
; 33/A094 one hand's animation by type (the hits capped by 33/A077)
ba_whand:   ld [ba_wt], a
            xor a
            ld [BZ + $B7], a
            ld a, [BZ + $CD]
            ld c, a
            ld b, 0
            ld hl, BZ + $BB
            add hl, bc
            ld a, [ba_wt]
            ld e, a
            ld d, 0
            push hl
            ld hl, $A077 + N32
            add hl, de
            ld a, [hl]
            pop hl
            ld d, a
            ld a, [hl]
            cp d
            jr c, .ok
            ld a, d
            dec a
            ld [hl], a
.ok:        ld a, [ba_wt]
            cp 1
            jr z, ba_w12                    ; 1: blades (slice)
            cp 2
            jr z, ba_w12                    ; 2: blunt
            cp 9
            jr z, ba_w9                     ; 9: claw
            cp 3
            jp z, ba_w3                     ; 3: bow
            cp 4
            jp z, ba_w4                     ; 4: harp
            cp 5
            jp z, ba_w5                     ; 5: boomerang
            cp 6
            jp z, ba_w6                     ; 6: full moon
            cp 7
            jp z, ba_w7                     ; 7: shuriken
            cp 8                            ; 8: an arrow alone: as bare hands (33/A2F2)
            jr z, .un
            and a
            ret nz
.un:
            ld a, [W7 + $7E1F]              ; 0: bare hands, when both hands are empty
            ld hl, W7 + $7E20
            or [hl]
            ret nz
            jr ba_w9

; 33/A365 / A36F: blades / blunt weapons: 8 frames a hit, back (frames 0-3), forward + the hit
; animation (4-7: slice 0 / strike 1)
ba_w12:     sub 1                           ; (1 -> hit 0, 2 -> hit 1)
            ld [BZ + $BA], a
            call ba_hits                    ; A245
            call ba_hpal                    ; A438
            call ba_save                    ; A40F
            call ba_clr
.h:         xor a                           ; A384
            ld [BZ + $B6], a
            ld [BZ + $B9], a
            ld a, $B6
            ld [S49], a
.f:         call ba_reset
            ld a, [BZ + $B6]
            and 4
            jr nz, .fw
            ld a, [BZ + $CD]
            and a
            jr z, .rb
            ld b, 2                         ; left hand back: anim 2, frame 7
            ld a, 7
            call ba_af
            jr .w
.rb:        ld b, 5                         ; right hand back: frame 0, anim 5
            xor a
            call ba_fa
            jr .w
.fw:        ld a, [BZ + $CD]
            and a
            jr z, .rf
            ld b, 3                         ; left forward: anim 3, frame 6
            ld a, 6
            call ba_af
            jr .ht
.rf:        ld b, 1                         ; right forward: frame 1, anim 1
            ld a, 1
            call ba_fa
.ht:        ld a, [BZ + $BA]
            call ba_hit
.w:         call ba_vblc
            call ba_inc
            and 8
            jr z, .f
            ld hl, BZ + $BD
            ld a, [hl]
            and a
            jr z, .e
            dec [hl]
            jr nz, .h
.e:         jp ba_end

; 33/A2FB claw / bare hands: per frame the frame (toad / mini: theirs), a small random offset,
; hit animation 2; 8 frames a hit
ba_w9:      call ba_hits
            call ba_hpal
            call ba_save
            call ba_clr
.h:         xor a
            ld [BZ + $B6], a
            ld a, $8A
            ld [S49], a
.f:         call ba_reset
            ld a, [BZ + $CD]
            and a
            ld a, 5
            ld e, 4
            jr z, .r
            ld a, 6
            ld e, $0D
.r:         push de
            call ba_tmfr                    ; A2D9
            call ba_rnd255
            and 1
            ld [BZ + $7E], a
            call ba_rnd255
            and 1
            ld [BZ + $7F], a
            pop de
            call ba_tm
            jr nz, .nt
            ld a, e
            call ba_aspr                    ; 32/92A1 (with the offset)
.nt:        ld a, 2
            call ba_hit
            call ba_vblc
            call ba_inc
            and 8
            jr z, .f
            ld hl, BZ + $BD
            ld a, [hl]
            and a
            jr z, .e
            dec [hl]
            jr nz, .h
.e:         jp ba_end
; 33/A2D9 the attacker's frame A (toad / mini: $0A / $0D by the frame)
ba_tmfr:    push af
            call ba_tm
            jr z, .n
            pop af
            ld a, [BZ + $B6]
            and 2
            ld a, $0A
            jr nz, .s
            ld a, $0D
            jr .s
.n:         pop af
.s:         jp ba_cfr
; 33/A2CF toad or mini: NZ
ba_tm:      ld a, [BZ + $95]
            ld c, a
            ld b, 0
            ld hl, W7 + $7D9B
            add hl, bc
            add hl, bc
            ld a, [hl]
            and 5
            ret

; 33/A245 the hand's hits -> $BD; 33/A438 the hand's palette -> sprite palette 3 (33/AB08)
ba_hits:    ld a, [BZ + $CD]
            ld c, a
            ld b, 0
            ld hl, BZ + $BB
            add hl, bc
            ld a, [hl]
            ld [BZ + $BD], a
            ret
ba_hpal:    ld a, [BZ + $CD]
            and 1
            ld c, a
            ld b, 0
            ld hl, W7 + $7E17
            add hl, bc
            ld a, [hl]
ba_pal3:    ld l, a                         ; general palette A (00/9100 / 9200 / 9300) ->
            ld h, high(BD_GPAL)             ;   sprite palette 3 colours 1-3, shown next frame
            ld a, BDATA_BANK
            call rd_byte
            ld [W7 + $7CF7 + $1D], a
            dec hl
            inc h
            ld a, BDATA_BANK
            call rd_byte
            ld [W7 + $7CF7 + $1E], a
            dec hl
            inc h
            ld a, BDATA_BANK
            call rd_byte
            ld [W7 + $7CF7 + $1F], a
            jp ba_vblc
; 33/A40F / A41D the members' frames saved / restored ($7D83 <-> $7D87)
ba_save:    ld hl, W7 + $7D83
            ld de, W7 + $7D87
            ld bc, 4
            jp memcpy
ba_rest:    ld hl, W7 + $7D87
            ld de, W7 + $7D83
            ld bc, 4
            jp memcpy
; 33/A3F9 the attacker's 6 sprites hidden (re-drawn by chr_draw)
ba_clr:     ret
; 33/A05E the animation sprites cleared
ba_reset:   xor a
            ld [s16_n], a
            ld a, low(BA_OAM)
            ld [ba_p], a
            ld hl, BA_OAM
            ld b, 16
.c:         ld [hl], 0
            inc l
            inc l
            inc l
            inc l
            dec b
            jr nz, .c
            ret
; 32/8AE6 the frame counter + 1 -> A
ba_inc:     ld hl, BZ + $B6
            inc [hl]
            ld a, [hl]
            ret
; 33/AC35 the end: the sound off, the frames back, drawn, a frame
ba_end:     ld a, $FF
            ld [S49], a
            call ba_rest
            call ba_reset
            call chr_draw
            jp wait_vbl
; a frame with the palettes (FF8B0): FF3's $7CF7 -> the CGB ones
ba_vblc:    ld hl, W7 + $7CF7
            ld bc, pal_sh
            call .p8
            ld hl, W7 + $7CF7 + 16
            ld bc, pal_sh + 64
            call .p8
            ld a, 1
            ldh [pal_dirty], a
            jp wait_vbl
.p8:        ld a, 16                        ; 16 NES colours [HL] -> RGB555 [BC]
.c:         push af
            push bc
            call nes_col
            pop bc
            ld [bc], a
            inc bc
            ld a, d
            ld [bc], a
            inc bc
            pop af
            dec a
            jr nz, .c
            ret
; 33/A44F random 0-255 (counter 0)
ba_rnd255:  xor a
            ld [BZ + $21], a
            ld b, 0
            ld a, $FF
            jp rnd_xa

; 33/A065: B = animation frame, A = attacker frame (animation first); A06E the other order
ba_af:      push af
            ld a, b
            call ba_aspr0
            pop af
            jp ba_cfr
ba_fa:      push bc
            call ba_cfr
            pop bc
            ld a, b
            jp ba_aspr0
; 33/A3DD the attacker's frame A, all drawn
ba_cfr:     ld e, a
            ld a, [BZ + $95]
            ld c, a
            ld b, 0
            ld hl, W7 + $7D83
            add hl, bc
            ld [hl], e
            jp chr_draw

; 32/9299 / 92A1 / 9357 an animation sprite (4 sprites) of frame A by the attacker ($7E / $7F
; offset): 32/950E + 4 frame: layout (32/943D), tiles (32/968A + 4 n), dx, dy; flipped when the
; attacker faces right (confused); palette 3, or the member's for frames 4 / $0D
ba_aspr0:   push af
            xor a
            ld [BZ + $7E], a
            ld [BZ + $7F], a
            pop af
ba_aspr:    ld [BZ + $8E], a
            ld a, [BZ + $95]
            ld c, a
            ld b, 0
            ld hl, W7 + $7D9B
            add hl, bc
            add hl, bc
            ld a, [hl]
            and 8
            rrca
            rrca
            rrca
            ld [BZ + $8F], a                ; h-flip
            ld hl, BZ + $C0
            add hl, bc
            ld a, [BZ + $7E]
            add a, [hl]
            ld [BZ + $8C], a
            ld hl, BZ + $C4
            add hl, bc
            ld a, [BZ + $7F]
            add a, [hl]
            ld [BZ + $8D], a
            xor a                           ; (relative to the attacker)
            ld [ba_mode], a
; 32/9357 frame $8E at ($8C, $8D), h-flip $8F
ba_spr:     ld a, [BZ + $8E]
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            ld de, $950E + N32
            add hl, de                      ; HL = the frame's 4 bytes
            push hl
            ld a, [BZ + $8E]                ; palette: the member's for frames 4 / $0D, else 3
            cp 4
            jr z, .mp
            cp $0D
            jr nz, .p3
.mp:        ld a, [BZ + $95]
            ld c, a
            ld b, 0
            ld hl, W7 + $7D93
            add hl, bc
            ld a, [hl]
            ld hl, W7 + $7D97
            add hl, bc
            or [hl]
            jr .pp
.p3:        ld a, 3
.pp:        ld [ba_pal], a
            pop hl
            ld a, [hl+]                     ; layout index, tiles index, dx, dy
            ld [ba_t], a
            ld a, [hl+]
            ld e, a
            ld a, [BZ + $8F]
            and a
            jr z, .nf
            push hl
            ld d, 0
            ld hl, $9503 + N32
            add hl, de
            ld e, [hl]
            pop hl
.nf:        ld a, [hl+]                     ; x = $8C + dx (flipped: - dx)
            ld b, a
            ld a, [BZ + $8F]
            and a
            ld a, b
            jr z, .x
            cpl
            inc a
.x:         ld b, a
            ld a, [BZ + $8C]
            add a, b
            ld [BZ + $90], a
            ld a, [hl]                      ; y = $8D + dy
            ld b, a
            ld a, [BZ + $8D]
            add a, b
            ld [BZ + $91], a
            ld d, 0                         ; layout: 32/943D[e] -> 4 x (dy, -, attributes, dx)
            ld hl, $943D + N32
            add hl, de
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld de, N32
            add hl, de
            ld a, [ba_t]                    ; tiles 32/968A + 4 layout index
            add a, a
            add a, a
            ld e, a
            ld d, 0
            push hl
            ld hl, $968A + N32
            add hl, de
            ld d, h
            ld e, l
            pop hl
            ld b, 4
.s:         push bc
            ld a, [BZ + $91]
            add a, [hl]
            inc hl
            ld c, a                         ; y
            inc hl
            ld a, [ba_pal]
            or [hl]
            inc hl
            ld [ba_t + 1], a                ; attributes
            ld a, [BZ + $90]
            add a, [hl]
            inc hl
            ld b, a                         ; x
            ld a, [de]
            inc de
            push de
            push hl
            ld d, a
            ld a, [ba_t + 1]
            ld e, a
            call ba_put
            pop hl
            pop de
            pop bc
            dec b
            jr nz, .s
            ret

; FF3 sprite (B = x, C = y, D = tile, E = attributes) -> the next animation OAM slot; ba_mode 0:
; relative to the attacker ($95) in the party column, 1: on the battlefield, 2: a projectile
ba_put:     ld a, d
            and a
            ret z                           ; (tile 0: none)
            ld a, [ba_mode]
            and a
            jr z, .pc
            cp 2
            jr z, .pj
            jr .bf
.pj:        call ba_back                    ; projectiles: x <= 128 as the battlefield (x - 12),
            ld a, b                         ;   x >= 192 as the party column, between them
            jr nz, .j0                      ;   compressed (116 + 3 (x - 128) / 8); y - 32
            ld a, 240
            sub b
.j0:        cp 128
            jr nc, .j1
            sub 12
            jr .j3
.j1:        cp 192
            jr nc, .j2
            sub 128
            ld h, a
            add a, a
            add a, h
            srl a
            srl a
            srl a
            add a, 116
            jr .j3
.j2:        sub 208
            sra a
            add a, 148
.j3:        ld b, a
            ld a, c
            sub 32
            ld c, a
            call ba_back
            jr nz, .w
            ld a, 168
            sub b
            ld b, a
            ld a, e
            xor $40
            ld e, a
            jr .w
.pc:
            ld a, [BZ + $95]                ; the party column: y - (4 m + $1B); x - C0 + base
            ld l, a
            add a, a
            add a, a
            add a, $1B
            ld h, a
            ld a, c
            sub h
            ld c, a
            ld h, high(BZ + $C0)
            ld a, l
            add a, low(BZ + $C0)
            ld l, a
            ld a, b
            sub [hl]                        ; dx from the member
            ld b, a
            call ba_bx                      ; A = the member's GB x base
            add a, b
            ld b, a
            call ba_back
            jr nz, .w
            ld a, 168                       ; (a back attack: mirrored)
            sub b
            ld b, a
            ld a, e
            xor $40
            ld e, a
            jr .w
.bf:        ld a, c                         ; the battlefield: (x - 12, y - 32)
            sub 32
            ld c, a
            call ba_back
            ld a, b
            jr nz, .b1
            cpl                             ; (a back attack: 180 - x, flipped)
            add a, 181
            ld b, a
            ld a, e
            xor $40
            ld e, a
            jr .w
.b1:        sub 12
            ld b, a
.w:         ld a, e                         ; FF3 attributes -> GB (palette + 4: OBJ palettes are
            and 3                           ;   the sprite ones; bank 1; flips; behind)
            or 8
            bit 6, e
            jr z, .h
            or $20
.h:         bit 7, e
            jr z, .v
            or $40
.v:         bit 5, e
            jr z, .p
            or $80
.p:         ld e, a
            ld a, [s16_on]                  ; (the 8 x 16 mode: into its list, btlfx.s)
            and a
            jr nz, .s16
            ld a, [ba_p]
            cp low(BA_OAM) + 64
            ret nc
            ld l, a
            ld h, high(BA_OAM)
            ld a, c
            ld [hl+], a
            ld a, b
            ld [hl+], a
            ld a, d
            ld [hl+], a
            ld a, e
            ld [hl+], a
            ld a, l
            ld [ba_p], a
            ret
.s16:       ld a, [s16_n]
            cp 40
            ret nc
            ld l, a
            inc a
            ld [s16_n], a
            ld h, 0
            add hl, hl
            add hl, hl
            ld a, l
            add a, low(s16_in)
            ld l, a
            ld a, h
            adc a, high(s16_in)
            ld h, a
            ld a, c
            ld [hl+], a
            ld a, b
            ld [hl+], a
            ld a, d
            ld [hl+], a
            ld [hl], e
            ret
; the attacker's GB x base: 140 + (x - 208) / 2 + 8 (a back attack: from 240 - x)
ba_bx:      ld a, [hl]
            push bc
            ld b, a
            call ba_back
            ld a, b
            jr nz, .n
            ld a, 240
            sub b
.n:         sub 208
            sra a
            add a, 140 + 8
            pop bc
            ret
ba_back:    ld a, [W7 + $78C3]
            cp $88
            ret

; ---- 32/97B2 the hit animation A on the target ($B8): only with hits; a crit flashes the
; backdrop orange once ($CB)
ba_hit:     push af
            ld a, [BZ + $CD]
            ld c, a
            ld b, 0
            ld hl, BZ + $BB
            add hl, bc
            ld a, [hl]
            and a
            jr nz, .h
            pop af
            ret
.h:         ld a, [BZ + $CB]
            and a
            jr z, .nc
            ld a, [BZ + $B7]
            and a
            jr nz, .nc
            ld a, $27
            call ba_bkd
            ld a, $0F
            ld [BZ + $B7], a
            call ba_bkd
.nc:        pop af
            and a
            jr z, ba_slice
            cp 3
            jp z, ba_hit3
            cp 4
            jp z, ba_hit4
            cp 5
            jp z, ba_hit5
            ld e, $10                       ; 1: strike $10 / $11, 2: claw $12 / $13
            cp 1
            jr z, .t
            ld e, $12
.t:         push de
            call ba_hpos
            pop de
            ld a, [BZ + $CD]
            add a, e
            ld [BZ + $8E], a
            ld a, 1
            ld [ba_mode], a
            jp ba_spr
; 32/98E8 the strike / claw position: every other frame a new random one around the target's
; centre ($BE / $BF)
ba_hpos:    xor a
            ld [BZ + $8F], a
            ld a, [BZ + $B6]
            and 1
            jr nz, .k
            call ba_tctr
            call ba_rnd255
            and $1F
            ld hl, BZ + $8C
            add a, [hl]
            ld [BZ + $BE], a
            call ba_rnd255
            and $1F
            ld hl, BZ + $8D
            add a, [hl]
            ld [BZ + $BF], a
.k:         ld a, [BZ + $BE]
            ld [BZ + $8C], a
            ld a, [BZ + $BF]
            ld [BZ + $8D], a
            ret
; the target's centre ($7DD7 + 2 slot) -> $8C / $8D
ba_tctr:    ld a, [BZ + $B8]
            and 7
            add a, a
            ld e, a
            ld d, 0
            ld hl, W7 + $7DD7
            add hl, de
            ld a, [hl+]
            ld [BZ + $8C], a
            ld a, [hl]
            ld [BZ + $8D], a
            ret
; 32/991F hit 0 (slice): 12 sprites (32/99D1 offsets, 32/99E9 tiles + 8 for the left hand)
; around the target's centre + 8 down, masked by 32/9968[$B9] as the cut goes on
ba_slice:   call ba_tctr
            ld a, [BZ + $8D]
            add a, 8
            ld [BZ + $8D], a
            ld a, [BZ + $B9]
            ld e, a
            ld d, 0
            ld hl, $9968 + N32
            add hl, de
            ld a, [hl]
            ld [ba_t + 2], a                ; (mask: a bit a pair of sprites)
            ld hl, BZ + $B9
            inc [hl]
            ld a, 1
            ld [ba_mode], a
            ld hl, $99D1 + N32
            ld de, $99E9 + N32
            ld b, 12
.s:         push bc
            ld a, b                         ; (pairs: the mask's bits from the top)
            dec a
            srl a
            ld c, a
            ld a, [ba_t + 2]
.m:         dec c
            jr z, .m1
            bit 7, c
            jr nz, .m1
            add a, a
            jr .m
.m1:        ld c, a
            ld a, [hl+]                     ; dx
            push hl
            ld hl, BZ + $8C
            add a, [hl]
            pop hl
            ld [ba_t], a
            ld a, [hl+]                     ; dy
            push hl
            ld hl, BZ + $8D
            add a, [hl]
            pop hl
            push hl
            push de
            ld [ba_t + 1], a
            ld a, [de]                      ; tile (+ 8 left), masked -> 0
            and a
            jr z, .t
            ld b, a
            ld a, [BZ + $CD]
            and a
            ld a, b
            jr z, .t
            add a, 8
.t:         bit 7, c                        ; (the masked pairs: 6 - pair index from the top)
            jr z, .t1
            xor a
.t1:        ld d, a
            ld e, 3
            ld a, [ba_t]
            ld b, a
            ld a, [ba_t + 1]
            ld c, a
            call ba_put
            pop de
            inc de
            pop hl
            pop bc
            dec b
            jr nz, .s
            ret
; 32/97AC the backdrop colour A (BG colour 0), shown a frame
ba_bkd:     ld [W7 + $7CF7], a
            ld [W7 + $7CF7 + 4], a
            ld [W7 + $7CF7 + 8], a
            ld [W7 + $7CF7 + 12], a
            jp ba_vblc


; ---- the ranged and other weapons (33/A125-A2F1, A4D4-A7A4)
; 33/A251 bow (and arrows): the hands' hit palettes swapped, 16 frames of drawing, the arrow
ba_w3:      call ba_hits
            ld a, [W7 + $7E17]
            ld b, a
            ld a, [W7 + $7E18]
            ld [W7 + $7E17], a
            ld a, b
            ld [W7 + $7E18], a
            call ba_hpal
            call ba_save
            xor a
            ld [BZ + $B6], a
            ld a, $AF
            ld [S49], a
.f:         call ba_reset
            ld a, [BZ + $B6]
            and 8
            jr nz, .f2
            ld a, [BZ + $CD]
            and a
            jr z, .r1
            ld b, $0B                       ; left: frame 6, anim $0B, then anim 7
            ld a, 6
            call ba_fa
            ld a, 7
            call ba_aspr0
            jr .w
.r1:        ld a, 5
            call ba_aspr0
            ld b, 9
            ld a, 1
            call ba_af
            jr .w
.f2:        ld a, [BZ + $CD]
            and a
            jr z, .r2
            ld b, $0C
            ld a, 6
            call ba_fa
            ld a, 8
            call ba_aspr0
            jr .w
.r2:        ld a, 6
            call ba_aspr0
            ld b, $0A
            ld a, 1
            call ba_af
.w:         call ba_vblc
            call ba_inc
            and $10
            jr z, .f
            call ba_arrow                   ; 33/A6D2
            jp ba_end

; 33/A1A5 harp: per hit 16 frames, the strike every 8
ba_w4:      call ba_hits
            call ba_hpal
            call ba_save
            ld a, $8B
            ld [S49], a
.h:         xor a
            ld [BZ + $B6], a
            ld [BZ + $B9], a
.f:         call ba_reset
            ld a, [BZ + $CD]
            and a
            jr z, .r
            ld b, $0F
            ld a, 6
            call ba_fa
            jr .t
.r:         ld b, $0E
            ld a, 7
            call ba_af
.t:         ld a, [BZ + $B6]
            and 8
            jr z, .w
            ld a, 1
            call ba_hit
.w:         call ba_vblc
            call ba_inc
            and $10
            jr z, .f
            ld hl, BZ + $BD
            ld a, [hl]
            and a
            jr z, .e
            dec [hl]
            jr nz, .h
.e:         ld a, $FF                       ; (33/AC3A: no sound stop)
            call ba_rest
            call ba_reset
            call chr_draw
            jp wait_vbl

; 33/A125 / A12C full moon / boomerang: 16 frames of the throw, then the flight
ba_w6:      ld a, 4
            jr ba_w56
ba_w5:      xor a
ba_w56:     ld [BZ + $89], a
            call ba_hits
            call ba_hpal
            call ba_save
            xor a
            ld [BZ + $B6], a
            ld a, $BB
            ld [S49], a
.f:         call ba_reset
            ld a, [BZ + $89]
            cp 4
            ld a, $14
            jr z, .o
            xor a
.o:         ld [BZ + $88], a
            ld a, [BZ + $B6]
            and 8
            jr nz, .f2
            ld a, [BZ + $CD]
            and a
            jr z, .r1
            ld a, [BZ + $88]
            add a, $22
            ld b, a
            ld a, 7
            call ba_af
            jr .w
.r1:        ld a, [BZ + $88]
            add a, $20
            ld b, a
            ld a, 5
            call ba_fa
            jr .w
.f2:        ld a, [BZ + $CD]
            and a
            jr z, .r2
            ld a, [BZ + $88]
            add a, $23
            ld b, a
            ld a, 6
            call ba_af
            jr .w
.r2:        ld a, [BZ + $88]
            add a, $21
            ld b, a
            ld a, 1
            call ba_fa
.w:         call ba_vblc
            call ba_inc
            and $10
            jr z, .f
            call ba_boom                    ; 33/A4D4
            jp ba_end

; 33/A1EF shuriken: 16 frames of the throw, then the flight
ba_w7:      call ba_hits
            call ba_hpal
            call ba_save
            xor a
            ld [BZ + $B6], a
            ld a, $AF
            ld [S49], a
.f:         call ba_reset
            ld a, [BZ + $B6]
            and 8
            jr nz, .f2
            ld a, [BZ + $CD]
            and a
            jr z, .r1
            ld b, $1E
            ld a, 7
            call ba_fa
            jr .w
.r1:        ld b, $18
            ld a, 5
            call ba_fa
            jr .w
.f2:        ld a, [BZ + $CD]
            and a
            jr z, .r2
            ld b, $1F
            ld a, 6
            call ba_fa
            jr .w
.r2:        ld b, $19
            ld a, 1
            call ba_fa
.w:         call ba_vblc
            call ba_inc
            and $10
            jr z, .f
            call ba_shur                    ; 33/A5FE
            jp ba_end

; 33/A6C3 the attacker confused: carry; with $7E96 (member on member) also carry
ba_noproj:  ld a, [W7 + $7E96]
            and a
            scf
            ret nz
            ld a, [BZ + $95]
            ld c, a
            ld b, 0
            ld hl, W7 + $7D9B
            add hl, bc
            add hl, bc
            bit 3, [hl]
            scf
            ret nz
            and a
            ret
; the flight's set-up: vectors reset, the angle to the target (33/A7A5), amplitude A
ba_vstart:  push af
            call ba_vreset
            call ba_angle
            ld b, a                         ; 33/BFB1: both angles + A
            ld hl, W7 + $7E3A
            add a, [hl]
            ld [hl], a
            ld hl, W7 + $7E44
            ld a, [hl]
            add a, b
            ld [hl], a
            pop af
            ld [W7 + $7E26], a
            ld [W7 + $7E30], a
            xor a
            ld [BZ + $B6], a
            ret
; the projectile's x reached the target's centre? (x = C0 - 16 + vx): carry if not yet
ba_reach:   call ba_vx
            ld b, a
            ld a, [BZ + $95]
            ld c, a
            ld hl, BZ + $C0
            ld a, l
            add a, c
            ld l, a
            ld a, [hl]
            sub $10
            add a, b
            ld b, a
            call ba_tctr
            ld a, [BZ + $8C]
            cp b
            ret
; 33/A6D2 the arrow: flies at 16 a frame to the target; then the first hit's arrow at the target
; (32/987C), the rest by hit animation 3
ba_arrow:   call ba_noproj
            ret c
            ld a, $10
            call ba_vstart
.f:         call ba_reset
            ld a, [BZ + $CD]
            and a
            jr z, .r
            ld a, 6
            call ba_cfr
            ld a, $16
            call ba_proj
            ld a, 8
            call ba_aspr0
            jr .w
.r:         ld a, 6
            call ba_aspr0
            ld a, $14
            call ba_proj
            ld a, 1
            call ba_cfr
.w:         call wait_vbl
            ld hl, BZ + $B6
            inc [hl]
            call ba_reach
            jr nc, .hit
            ld a, $10
            call ba_vdadd
            jr .f
.hit:       call ba_reset
            ld a, [BZ + $CD]
            and a
            jr z, .r2
            ld b, 8
            ld a, 6
            call ba_fa
            jr .h
.r2:        ld b, 6
            ld a, 1
            call ba_af
.h:         call ba_first
            jr z, .w2
            call ba_arr1                    ; 32/987C
            ld hl, BZ + $BD
            dec [hl]
.w2:        call wait_vbl
            ld a, [BZ + $BD]
            and a
            ret z
            ld a, 3
            jp ba_hit
; the hand has hits (NZ)
ba_first:   ld a, [BZ + $CD]
            ld c, a
            ld b, 0
            ld hl, BZ + $BB
            add hl, bc
            ld a, [hl]
            and a
            ret
; the projectile's end at (C0 - 16 + vx, C4 + 8 + vy)
ba_pend:    call ba_vy
            ld b, a
            ld a, [BZ + $95]
            ld c, a
            ld hl, BZ + $C4
            ld a, l
            add a, c
            ld l, a
            ld a, [hl]
            add a, 8
            add a, b
            ld [BZ + $8D], a
            call ba_vx
            ld b, a
            ld a, [BZ + $95]
            ld c, a
            ld hl, BZ + $C0
            ld a, l
            add a, c
            ld l, a
            ld a, [hl]
            sub $10
            add a, b
            ld [BZ + $8C], a
            ret
ba_arr1:    call ba_pend
            ld a, [BZ + $CD]
            and a
            ld a, $52
            jr z, ba_one
            ld a, $4A
            jr ba_one
ba_shu1:    call ba_pend
            ld a, [BZ + $CD]
            and a
            ld a, $4B
            jr z, ba_one
            ld a, $53
; 32/988C one sprite (tile A) at ($8C, $8D) on the battlefield, sound $5A, then 6 frames
ba_one:     ld d, a
            ld a, $DA
            ld [S49], a
            ld a, 1
            ld [ba_mode], a
            ld a, [BZ + $8C]
            ld b, a
            ld a, [BZ + $8D]
            ld c, a
            ld e, 3
            call ba_put
            ld b, 6
.w:         push bc
            call wait_vbl
            pop bc
            dec b
            jr nz, .w
            ret
; 32/9823 hits 3 / 4 (arrows / shuriken): each remaining hit a sprite around the target's centre
; (random 0-$18 and 0-$26 less $10, a random 0-255 between them, as FF3)
ba_hit4:    ld a, 1
            jr ba_h34
ba_hit3:    xor a
ba_h34:     ld [ba_t + 3], a
.l:         call ba_tctr
            xor a
            ld [BZ + $21], a
            ld b, 0
            ld a, $18
            call rnd_xa
            ld hl, BZ + $8C
            add a, [hl]
            sub $10
            ld [hl], a
            call ba_rnd255
            xor a
            ld [BZ + $21], a
            ld b, 0
            ld a, $26
            call rnd_xa
            ld hl, BZ + $8D
            add a, [hl]
            sub $10
            ld [hl], a
            ld a, [ba_t + 3]
            and a
            ld a, [BZ + $CD]
            jr z, .ar
            and a                           ; shuriken $4B / $53
            ld a, $4B
            jr z, .t
            ld a, $53
            jr .t
.ar:        and a                           ; arrow $52 / $4A
            ld a, $52
            jr z, .t
            ld a, $4A
.t:         call ba_one
            ld hl, BZ + $BD
            dec [hl]
            jr nz, .l
            ret
; 32/97EB hit 5 (boomerang): frame $10 / $11 at the target's centre + 16
ba_hit5:    call ba_tctr
            ld a, [BZ + $8C]
            add a, $10
            ld [BZ + $8C], a
            ld a, [BZ + $8D]
            add a, $10
            ld [BZ + $8D], a
            xor a
            ld [BZ + $8F], a
            ld a, [BZ + $CD]
            add a, $10
            ld [BZ + $8E], a
            ld a, 1
            ld [ba_mode], a
            jp ba_spr
; 33/A5FE the shuriken: 8 a frame + 16, then its first hit, the rest by hit animation 4
ba_shur:    call ba_noproj
            ret c
            ld a, 8
            call ba_vstart
.f:         call ba_reset
            ld a, [BZ + $CD]
            and a
            jr z, .r
            ld a, 6
            call ba_cfr
            ld a, $1C
            call ba_proj
            jr .w
.r:         ld a, 1
            call ba_cfr
            ld a, $1A
            call ba_proj
.w:         call wait_vbl
            ld hl, BZ + $B6
            inc [hl]
            call ba_reach
            jr nc, .hit
            ld a, $10
            call ba_vdadd
            jr .f
.hit:       call ba_reset
            ld a, [BZ + $CD]
            and a
            ld a, 1
            jr z, .h1
            ld a, 6
.h1:        call ba_cfr
            call ba_first
            jr z, .w2
            call ba_shu1
            ld hl, BZ + $BD
            dec [hl]
.w2:        call wait_vbl
            ld a, [BZ + $BD]
            and a
            ret z
            ld a, 4
            jp ba_hit
; 33/A4D4 the boomerang / full moon: out to the target (the distance growing, slowing near
; half way), back with its hits (hit animation 5)
ba_boom:    call ba_noproj
            ret c
            ld hl, BZ + $BD
            sla [hl]
            sla [hl]
            sla [hl]
            xor a
            ld [BZ + $88], a
            ld a, [BZ + $95]                ; $8A = (C0 + $16 - target centre x) / 2
            ld c, a
            ld b, 0
            ld hl, BZ + $C0
            add hl, bc
            ld a, [hl]
            add a, $16
            push af
            call ba_tctr
            pop af
            ld hl, BZ + $8C
            sub [hl]
            srl a
            ld [BZ + $8A], a
            ld a, $10
            ld [BZ + $8B], a
            ld a, $10
            call ba_vstart
.o:         call ba_reset
            call .spr
            call wait_vbl
            ld hl, BZ + $B6
            inc [hl]
            call ba_vx                      ; reached: x = C0 - 16 + vx <= centre
            ld b, a
            ld a, [BZ + $95]
            ld c, a
            ld hl, BZ + $C0
            ld a, l
            add a, c
            ld l, a
            ld a, [hl]
            sub $10
            add a, b
            ld b, a
            call ba_tctr
            ld a, [BZ + $8C]
            cp b
            jr nc, .back
            ld a, [W7 + $7E26]
            ld hl, BZ + $8A
            cp [hl]
            jr c, .o1
            ld hl, BZ + $8B
            dec [hl]
            ld hl, BZ + $88
            inc [hl]
            inc [hl]
            jr .o2
.o1:        ld hl, BZ + $88
            dec [hl]
            dec [hl]
            ld hl, BZ + $8B
            inc [hl]
.o2:        ld a, [BZ + $8B]
            srl a
            srl a
            call ba_vdadd
            call .fm
            jr .o
.back:      ld a, $DB
            ld [S49], a
            xor a
            ld [BZ + $88], a
.b:         call ba_reset
            call .spr
            ld a, [BZ + $BD]
            and a
            jr z, .b1
            ld a, 5
            call ba_hit
            ld hl, BZ + $BD
            dec [hl]
.b1:        call wait_vbl
            ld hl, BZ + $B6
            inc [hl]
            ld a, [W7 + $7E26]
            cp 8
            ret c
            ld hl, BZ + $8A
            cp [hl]
            jr c, .b2
            ld hl, BZ + $8B
            inc [hl]
            ld hl, BZ + $88
            inc [hl]
            inc [hl]
            jr .b3
.b2:        ld hl, BZ + $88
            dec [hl]
            dec [hl]
            ld hl, BZ + $8B
            dec [hl]
.b3:        ld a, [BZ + $8B]
            srl a
            srl a
            call ba_vdsub
            call .fm
            jr .b
.fm:        ld a, [BZ + $89]                ; (the full moon: no rise)
            cp 4
            ret nz
            xor a
            ld [BZ + $88], a
            ret
.spr:       ld a, [BZ + $CD]                ; frame 6 / 1, the boomerang $2C / $24 (33/A4B1)
            and a
            jr z, .s1
            ld a, 6
            call ba_cfr
            ld a, $2C
            jr ba_projb
.s1:        ld a, 1
            call ba_cfr
            ld a, $24
; 33/A4B1 the boomerang sprite: frame A + (B6 / 2 & 3) + $89, at (vx, vy + $88)
ba_projb:   ld [BZ + $82], a
            call ba_vy
            ld hl, BZ + $88
            add a, [hl]
            ld [BZ + $7F], a
            call ba_vx
            ld [BZ + $7E], a
            ld a, [BZ + $B6]
            srl a
            and 3
            ld hl, BZ + $82
            add a, [hl]
            ld hl, BZ + $89
            add a, [hl]
            jr ba_proj2
; 33/A493 a projectile: frame A + (B6 / 4 & 1) at (vx, vy) from the attacker
ba_proj:    ld [BZ + $82], a
            call ba_vy
            ld [BZ + $7F], a
            call ba_vx
            ld [BZ + $7E], a
            ld a, [BZ + $B6]
            srl a
            srl a
            and 1
            ld hl, BZ + $82
            add a, [hl]
ba_proj2:   call ba_aspr0x
            ld a, 2                         ; (in flight: the compressed mapping)
            ld [ba_mode], a
            jp ba_spr
; ba_aspr without drawing: $8C / $8D / $8E / $8F set
ba_aspr0x:  ld [BZ + $8E], a
            ld a, [BZ + $95]
            ld c, a
            ld b, 0
            ld hl, W7 + $7D9B
            add hl, bc
            add hl, bc
            ld a, [hl]
            and 8
            rrca
            rrca
            rrca
            ld [BZ + $8F], a
            ld hl, BZ + $C0
            add hl, bc
            ld a, [BZ + $7E]
            add a, [hl]
            ld [BZ + $8C], a
            ld hl, BZ + $C4
            add hl, bc
            ld a, [BZ + $7F]
            add a, [hl]
            ld [BZ + $8D], a
            ret

; ---- 33's vectors (vector 0): $7E26 / $7E30 amplitudes (y / x), $7E3A / $7E44 angles
ba_vreset:  ld hl, W7 + $7E3A               ; 33/BF5F
            ld b, 10
.c:         ld [hl], 0
            inc hl
            dec b
            jr nz, .c
            ld b, 10
.d:         ld [hl], $40
            inc hl
            dec b
            jr nz, .d
            ret
ba_vx:      ld a, [W7 + $7E30]              ; 33/BF6F
            ld e, a
            ld a, [W7 + $7E44]
            jr ba_vmul
ba_vy:      ld a, [W7 + $7E26]              ; 33/BF7B
            ld e, a
            ld a, [W7 + $7E3A]
; 33/BFC6 E x sin(A) (10/9A80, signed): FF3's ((2 s) & $FF) x E / 256, the sign put back
ba_vmul:    ld l, a
            ld h, 0
            ld bc, CUT_SINE
            add hl, bc
            ld a, CUTD
            call rd_byte
            bit 7, a
            jr z, .p
            cpl
            call .m
            cpl
            inc a
            ret
.p:
.m:         add a, a                        ; (2 s) x E >> 8
            ld d, a
            xor a
            ld b, 8
.l:         srl d
            jr nc, .n
            add a, e
.n:         rra
            dec b
            jr nz, .l
            ret
ba_vdadd:   ld b, a                         ; 33/BF87
            ld hl, W7 + $7E26
            ld a, [hl]
            add a, b
            ld [hl], a
            ld hl, W7 + $7E30
            ld a, [hl]
            add a, b
            ld [hl], a
            ret
ba_vdsub:   ld b, a                         ; 33/BF9C
            ld hl, W7 + $7E26
            ld a, [hl]
            sub b
            ld [hl], a
            ld hl, W7 + $7E30
            ld a, [hl]
            sub b
            ld [hl], a
            ret
; 33/A7A5 the angle from the attacker to the target ($B8): 33/A7E1[tilemap] + 33/A7D7[tilemap]
; x attacker + target
ba_angle:   ld a, [W7 + $7D7B]
            ld e, a
            ld d, 0
            ld hl, $A7D7 + N32
            add hl, de
            ld a, [hl]
            ld e, a
            ld a, [BZ + $95]
            ld d, a
            xor a
            inc d
.m:         dec d
            jr z, .m1
            add a, e
            jr .m
.m1:        ld b, a
            ld a, [BZ + $B8]
            add a, b
            ld c, a
            ld a, [W7 + $7D7B]
            add a, a
            ld e, a
            ld d, 0
            ld hl, $A7E1 + N32
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld b, 0
            add hl, bc
            ld de, N32
            add hl, de
            ld a, [hl]
            ret

; ---- 2F/B226 battle graphics $14: a member hit ($52): its hit tiles, then 33/A8B8: frame 4
; (toad / mini $0F) pushed back 8 (a crit 16, sound $46), shaken 4 times, back
ba_g14:     call ba_hgfx
            ld a, [BZ + $BB]
            ld hl, BZ + $BC
            or [hl]
            ret z
            ld a, [BZ + $52]
            ld [BZ + $95], a
            ld e, $B0
            ld a, [BZ + $CB]
            and a
            ld d, 8
            jr z, .s
            ld e, $C6
            ld d, $10
.s:         ld a, e
            ld [S49], a
            push de
            call ba_save
            call ba_tm
            pop de
            ld a, 4
            jr z, .f
            ld a, $0F
.f:         ld e, a                         ; (D: the push distance)
            ld a, [BZ + $95]
            ld c, a
            ld b, 0
            ld hl, W7 + $7D83
            add hl, bc
            ld [hl], e
            ld hl, BZ + $C0
            add hl, bc
            ld a, [hl]
            add a, d
            ld [hl], a
            push de
            call .w2
            ld b, 4
.k:         push bc
            ld a, [BZ + $95]
            ld c, a
            ld b, 0
            ld hl, BZ + $C0
            add hl, bc
            inc [hl]
            call .w2
            ld a, [BZ + $95]
            ld c, a
            ld b, 0
            ld hl, BZ + $C0
            add hl, bc
            dec [hl]
            call .w2
            pop bc
            dec b
            jr nz, .k
            pop de
            ld a, [BZ + $95]
            ld c, a
            ld b, 0
            ld hl, BZ + $C0
            add hl, bc
            ld a, [hl]
            sub d
            ld [hl], a
            call ba_rest
.w2:        ld b, 2                         ; 33/A91C: drawn, 2 frames
.w:         push bc
            call chr_draw
            call wait_vbl
            pop bc
            dec b
            jr nz, .w
            ret

; ---- 2F/B004 battle graphics $20 (a monster on a monster) / 33/A899: the claw hit animation
; on the target, 8 frames a hit
ba_g20:     xor a
            ld [W7 + $7E1F], a
            ld [W7 + $7E20], a
            call ba_wprop
            xor a
            ld [BZ + $CD], a
            ld [BZ + $C9], a
            ld a, [BZ + $BB]
            and a
            ret z
            ld [BZ + $BD], a
            call ba_hpal
.h:         xor a
            ld [BZ + $B6], a
.f:         call wait_vbl
            call ba_reset
            ld a, 2
            call ba_hit
            call ba_inc
            and 8
            jr z, .f
            ld hl, BZ + $BD
            dec [hl]
            jr nz, .h
            jp ba_reset

; ---- 2F/B01F battle graphics $1F: the attacking monster flashes (palette 3 on odd frames, 8
; frames; not for flare wave)
ba_mflash:  ld a, [W7 + $7E98]              ; (34/8545: the attacker, palette 3)
            ld [W7 + $7E8F], a
            ld a, 3
            ld [W7 + $7E90], a
            ld a, [W7 + $7E9D]              ; 2F/B024 (not for flare wave): 8 frames, the flash
            cp 9                            ;   every other (the attribute table pushed each)
            ret z
            xor a
            ld [BZ + $B6], a
.f:         ld a, [BZ + $B6]
            and 1
            jr nz, .n
            call mon_flash
            jr .p
.n:         call mon_attrs
.p:         call attr_push
            ld hl, BZ + $B6
            inc [hl]
            ld a, [hl]
            cp 8
            jr nz, .f
            ret

; ---- 2F/BDB6 the monsters' position data: centres $7DD7 / $7DD8, front x $7DF7 / $7DE7, top
; $7DF8, centre y $7DE8, bottom $7E07, from the tilemap's position data (2F/A5E6) and sizes
ba_mpos:    ld hl, W7 + $7DD7
            ld b, $30
.c:         ld [hl], 0
            inc hl
            dec b
            jr nz, .c
            ld a, [W7 + $7D7B]              ; (pos_ptr)
            add a, a
            add a, low(TB_POS)
            ld l, a
            ld h, high(TB_POS)
            call bd_rd
            ld e, a
            call bd_rd
            ld d, a
            ld hl, BD_2F - $A4A4
            add hl, de
            ld c, 0                         ; (2 x slot)
.m:         push hl
            call bd_rd
            cp $FF
            jp z, .end
            dec a
            add a, a
            add a, a
            add a, a
            ld [ba_t], a                    ; front x
            call bd_rd
            dec a
            add a, a
            add a, a
            add a, a
            dec a
            ld [ba_t + 1], a                ; top y
            call bd_rd                      ; size: width, height (TB_SIZE)
            add a, a
            add a, low(TB_SIZE)
            ld l, a
            ld h, high(TB_SIZE)
            call bd_rd
            and $FE
            add a, a
            add a, a
            ld [ba_t + 2], a                ; (width & $FE) x 4
            call bd_rd
            ld d, a
            and $FE
            add a, a
            add a, a
            ld e, a                         ; (height & $FE) x 4
            ld a, d
            add a, a
            add a, a
            add a, a
            ld d, a                         ; height x 8
            ld b, 0
            ld hl, W7 + $7DF7
            add hl, bc
            ld a, [ba_t]
            ld [hl], a
            ld hl, W7 + $7DE7
            add hl, bc
            ld [hl], a
            ld hl, ba_t + 2
            add a, [hl]
            add a, 8
            ld hl, W7 + $7DD7
            add hl, bc
            ld [hl+], a
            ld a, [ba_t + 1]
            add a, e
            ld [hl], a                      ; $7DD8 centre y
            ld hl, W7 + $7DE8
            add hl, bc
            ld [hl], a
            ld hl, W7 + $7DF8
            add hl, bc
            ld a, [ba_t + 1]
            ld [hl], a
            add a, d
            push af
            ld a, c
            srl a
            ld e, a
            ld d, 0
            ld hl, W7 + $7E07
            add hl, de
            pop af
            ld [hl], a
            pop hl
            inc hl
            inc hl
            inc hl
            inc c
            inc c
            jp .m
.end:       pop hl
            ld a, [W7 + $7D7B]
            cp 9
            ret nz
            ld a, $58                       ; (a boss: monster 0 at (88, 80))
            ld [W7 + $7DD7], a
            ld a, $50
            ld [W7 + $7DD8], a
            ret

section wram, $DFAA             ; (WRAM bank 3: free between btl_oa and mon_rec)
ba_att:     ds 1
ba_wt:      ds 1
ba_p:       ds 1
ba_pal:     ds 1
ba_mode:    ds 1
ba_t:       ds 4
ba_dirty:   ds 1
