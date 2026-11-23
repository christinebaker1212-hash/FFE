; ---- battle animations (FF3 2F/AF4E battle graphics, 33 animation functions, 32 sprite helpers),
; bank CODE7: this code at $4000, NES 32/9000-9FFF at $5000 and 33 at $6000 (NES - $4000), so
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
.nc:        xor a
            ld [BZ + $CD], a
            ld a, [W7 + $7E1F]
            call ba_whand
            ld a, 1
            ld [BZ + $CD], a
            ld a, [W7 + $7E20]
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
            and a
            ret nz                          ; (3-8: bows, harp, thrown: later)
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
ba_reset:   ld a, low(BA_OAM)
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
; relative to the attacker ($95) in the party column, 1: on the battlefield
ba_put:     ld a, d
            and a
            ret z                           ; (tile 0: none)
            ld a, [ba_mode]
            and a
            jr nz, .bf
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
.w:         ld a, [ba_p]
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
            ld a, e                         ; FF3 attributes -> GB (palette + 4: OBJ palettes are
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
.p:         ld [hl+], a
            ld a, l
            ld [ba_p], a
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
            ret nc                          ; (3-5: later)
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
ba_mflash:  ld a, [W7 + $7E9D]
            cp 9
            ret z
            ld b, 8                         ; (the cells: the attribute rewrite comes with the
.f:         push bc                         ;   monster palettes' port; the frames are kept)
            call wait_vbl
            pop bc
            dec b
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
