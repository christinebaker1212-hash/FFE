; btlfx.s (CODE8): the 8 x 16 sprite mode and the magic animations (FF3 34/8577, 2F/B15E,
; 33/AF6F-BC88). The data: bank 33 at $6000 (build.py), FXD: 00/9700-9FFF (the hit frames),
; 06/8C00-9FFF (the spells' frame lists), 2E/9100-95FF (the graphics properties), 34/83A0 (the
; sounds); MAGG: NES banks $2A-$2B (FF3's bank 15: the magic graphics) as GB tiles.
;
; The GB has 40 sprites; FF3's spells draw up to 36 next to the party's 24, so while a spell
; shows, the sprites are 8 x 16: the party's and the effect's 8 x 8 sprites are paired
; (vertical neighbours of one palette), each pair's two tiles composed (flips put into the
; pixels) from a WRAM mirror of the sprite tiles into VRAM bank 1 tiles S16_T0- (34 pairs).
N33        = -$4000             ; 33 address + N33 = the copy here
FX_REV     = $5F00              ; (build.py: the bit-reversed bytes)
F00        = $4000 - $9700      ; FXD: 00/9700-A1FF at $4000 (the hit frames)
F06        = $4B00 - $8C00      ; FXD: 06/8C00-91FF at $4B00 (the spells' frame lists)
F2E        = $5100 - $9100      ; FXD: 2E/9100-95FF at $5100 (the graphics properties)
F34        = $5600 - $83A0      ; FXD: 34/83A0- at $5600 (the sounds)
NSLOT      = 34

; ---- the mode on: the slots emptied, the first picture built, then shown from the V-Blank
s16_start:  ldh a, [rSVBK]
            push af
            ld a, 5
            ldh [rSVBK], a
            ld hl, S16_K
            ld b, NSLOT * 4
            ld a, $FF
.k:         ld [hl+], a
            dec b
            jr nz, .k
            pop af
            ldh [rSVBK], a
            xor a
            ld [s16_n], a
            ld [s16_lo], a
            ld [s16_hi], a
            ld [s16_front], a
            ld [s16_lock], a
            dec a
            ld [s16_sum], a
            call s16_build
            ld a, 1
            ld [s16_on], a
            ret
; the mode off: 8 x 8 sprites from the next V-Blank; the tiles under the slots back from the
; mirror (two V-Blanks of 34 tiles)
s16_stop:   xor a
            ld [s16_on], a
            ld [s16_n], a
            ld hl, S16_MIR                  ; VRAM bank 1 tiles $00-$7F from the mirror (4 x 32)
            ld de, $8000
            ld b, 4
.r:         push bc
            push hl
            push de
            call wait_vbl
            pop de
            pop hl
            call .h
            ld bc, $200
            add hl, bc
            ld a, d
            add a, 2
            ld d, a
            pop bc
            dec b
            jr nz, .r
            ret
.h:         ldh a, [rSVBK]
            push af
            ld a, 5
            ldh [rSVBK], a
            ld a, h
            ldh [rHDMA1], a
            ld a, l
            ldh [rHDMA2], a
            ld a, d
            ldh [rHDMA3], a
            ld a, e
            ldh [rHDMA4], a
            ld a, 1
            ldh [rVBK], a
            ld a, 32 - 1
            ldh [rHDMA5], a
            xor a
            ldh [rVBK], a
            pop af
            ldh [rSVBK], a
            ret

; a frame: the picture built, FF3's pending sound effect started (FFAF2), V-Blank
mx_wait:    call s16_build
            ld a, [BZ + $C9]
            and a
            jr z, .w
            ld a, [BZ + $CA]
            or $80
            ld [S49], a
            xor a
            ld [BZ + $C9], a
.w:         jp wait_vbl

; ---- the picture: the party's sprites (OAM 0-23) and the effect's (s16_in) as 8 x 16 pairs
s16_build:  ld hl, oam_buf                  ; (nothing changed: the last picture stays)
            ld bc, 0
            ld e, 96
.h1:        ld a, [hl+]
            add a, c
            ld c, a
            ld a, b
            rlca
            xor c
            ld b, a
            dec e
            jr nz, .h1
            ld a, [s16_n]
            and a
            jr z, .h3
            add a, a
            add a, a
            ld e, a
            ld hl, s16_in
.h2:        ld a, [hl+]
            add a, c
            ld c, a
            ld a, b
            rlca
            xor c
            ld b, a
            dec e
            jr nz, .h2
.h3:        ld a, [s16_n]
            xor b
            ld b, a
            ld a, [s16_sum]
            cp c
            jr nz, .ch
            ld a, [s16_sum + 1]
            cp b
            ret z
.ch:        ld a, c
            ld [s16_sum], a
            ld a, b
            ld [s16_sum + 1], a
            ld a, 1
            ld [s16_lock], a
            ldh a, [rSVBK]
            push af
            ld a, 5
            ldh [rSVBK], a
            xor a                           ; gather (the effect first when in front)
            ld [s16_wn], a
            ld de, S16_W
            ld a, [s16_front]
            and a
            jr z, .pf
            call .gfx
            call .gpt
            jr .g1
.pf:        call .gpt
            call .gfx
.g1:        xor a                           ; pairs
            ld [s16_pn], a
            ld hl, S16_U
            ld b, NSLOT
.u:         ld [hl+], a
            dec b
            jr nz, .u
            ld [s16_i], a
.pi:        ld a, [s16_i]
            ld hl, s16_wn
            cp [hl]
            jp nc, .pd
            call .wp                        ; HL = W[i]
            ld a, [hl]
            and a
            jp z, .pn                       ; (taken)
            ld [hl], 0                      ; (y 0: taken)
            ld b, a                         ; B = y, C = x, D = tile, E = attributes
            inc hl
            ld a, [hl+]
            ld c, a
            ld a, [hl+]
            ld d, a
            ld e, [hl]
            ld a, [s16_i]                   ; the partner: x the same, the group the same, y +- 8
            inc a
            ld [s16_j], a
.pj:        ld a, [s16_j]
            ld hl, s16_wn
            cp [hl]
            jr nc, .single
            call .wp
            ld a, [hl+]
            and a
            jr z, .pjn
            push af
            ld a, [hl+]
            cp c
            jr nz, .pjx
            inc hl
            ld a, [hl]
            xor e
            and $9F
            jr nz, .pjx
            pop af
            push af
            sub b
            cp 8
            jr z, .bot
            cp -8
            jr z, .top
.pjx:       pop af
.pjn:       ld hl, s16_j
            inc [hl]
            jr .pj
.bot:       pop af                          ; the partner below (HL -> its attributes): W[i] top
            ld a, [hl-]
            ld [s16_t + 3], a
            ld a, [hl-]
            ld [s16_t + 2], a
            dec hl
            ld [hl], 0
            ld a, d
            ld [s16_t], a
            ld a, e
            ld [s16_t + 1], a
            jr .key
.top:       pop af                          ; the partner above: it is the top
            ld a, d
            ld [s16_t + 2], a
            ld a, e
            ld [s16_t + 3], a
            ld a, [hl-]
            ld [s16_t + 1], a
            ld e, a
            ld a, [hl-]
            ld [s16_t], a
            dec hl
            ld [hl], 0
            ld a, b
            sub 8
            ld b, a
            jr .key
.single:    ld a, d
            ld [s16_t], a
            ld a, e
            ld [s16_t + 1], a
            ld a, $FF
            ld [s16_t + 2], a
            ld [s16_t + 3], a
.key:       ld a, [s16_pn]                  ; the pair: y, x, attributes, slot $FF, key
            cp NSLOT
            jr nc, .pn
            inc a
            ld [s16_pn], a
            dec a
            push de
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, S16_PL
            add hl, de
            pop de
            ld a, b
            ld [hl+], a
            ld a, c
            ld [hl+], a
            ld a, e
            and $87
            or 8
            ld [hl+], a
            ld a, $FF
            ld [hl+], a
            ld a, [s16_t]
            ld [hl+], a
            ld a, [s16_t + 1]
            and $60
            ld [hl+], a
            ld a, [s16_t + 2]
            ld [hl+], a
            ld a, [s16_t + 3]
            and $60
            ld [hl], a
.pn:        ld hl, s16_i
            inc [hl]
            jp .pi
.pd:        ld a, [s16_pn]                  ; the keys found in the slots
            and a
            jp z, .out
            ld hl, S16_PL
            ld b, a
.l1:        push bc
            push hl
            inc hl
            inc hl
            inc hl
            push hl                         ; (-> the slot)
            inc hl
            ld de, S16_K
            ld c, 0
.l2:        ld a, [de]
            cp [hl]
            jr nz, .l3
            push hl
            push de
            inc hl
            inc de
            ld a, [de]
            cp [hl]
            jr nz, .l4
            inc hl
            inc de
            ld a, [de]
            cp [hl]
            jr nz, .l4
            inc hl
            inc de
            ld a, [de]
            cp [hl]
            jr nz, .l4
            pop de
            pop hl
            pop hl                          ; found: slot C
            ld [hl], c
            ld hl, S16_U
            ld b, 0
            add hl, bc
            ld [hl], 1
            jr .l5
.l4:        pop de
            pop hl
.l3:        inc de
            inc de
            inc de
            inc de
            inc c
            ld a, c
            cp NSLOT
            jr nz, .l2
            pop hl
.l5:        pop hl
            ld de, 8
            add hl, de
            pop bc
            dec b
            jr nz, .l1
            ld a, [s16_pn]                  ; the others: a free slot, composed
            ld b, a
            ld hl, S16_PL
.a1:        push bc
            push hl
            inc hl
            inc hl
            inc hl
            ld a, [hl]
            inc a
            jr nz, .a5
            push hl
            ld de, S16_U
            ld c, 0
.a2:        ld a, [de]
            and a
            jr z, .a3
            inc de
            inc c
            ld a, c
            cp NSLOT
            jr nz, .a2
            pop hl
            jr .a5
.a3:        ld a, 1
            ld [de], a
            pop hl
            ld [hl], c
            inc hl
            push hl
            ld l, c                         ; the key -> S16_K + 4 slot
            ld h, 0
            add hl, hl
            add hl, hl
            ld de, S16_K
            add hl, de
            ld d, h
            ld e, l
            pop hl
            push hl
            ld a, [hl+]
            ld [de], a
            inc de
            ld a, [hl+]
            ld [de], a
            inc de
            ld a, [hl+]
            ld [de], a
            inc de
            ld a, [hl]
            ld [de], a
            pop hl
            call s16_comp                   ; HL -> the key, C = slot
            ld a, [s16_hi]                  ; dirty: lo..hi
            ld b, a
            ld a, [s16_lo]
            cp b
            jr c, .a4
            ld a, c                         ; (nothing pending: lo = hi = slot)
            ld [s16_lo], a
            inc a
            ld [s16_hi], a
            jr .a5
.a4:        ld a, [s16_lo]
            cp c
            jr c, .a6
            ld a, c
            ld [s16_lo], a
.a6:        ld a, [s16_hi]
            dec a
            cp c
            jr nc, .a5
            ld a, c
            inc a
            ld [s16_hi], a
.a5:        pop hl
            ld de, 8
            add hl, de
            pop bc
            dec b
            jr nz, .a1
.out:       ld hl, S16_PL                   ; the OAM: y + 16, x + 8 as given (GB), the slot's tile
            ld de, S16_OAM
            ld a, [s16_pn]
            and a
            jr z, .o2
            ld b, a
.o1:        ld a, [hl+]
            ld [de], a
            inc de
            ld a, [hl+]
            ld [de], a
            inc de
            ld a, [hl+]
            ld c, a
            ld a, [hl+]
            cp NSLOT
            jr c, .o3
            dec de                          ; (no slot: hidden)
            dec de
            xor a
            ld [de], a
            inc de
            inc de
.o3:        add a, a
            add a, S16_T0
            ld [de], a
            inc de
            ld a, c
            ld [de], a
            inc de
            inc hl
            inc hl
            inc hl
            inc hl
            dec b
            jr nz, .o1
.o2:        ld a, e                         ; the rest hidden
            cp 160
            jr nc, .o4
            xor a
            ld [de], a
            inc de
            inc de
            inc de
            inc de
            jr .o2
.o4:        pop af
            ldh [rSVBK], a
            xor a
            ld [s16_lock], a
            ret
.wp:        ld l, a                         ; HL = S16_W + 4 A
            ld h, 0
            add hl, hl
            add hl, hl
            ld a, l
            add a, low(S16_W)
            ld l, a
            ld a, h
            adc a, high(S16_W)
            ld h, a
            ret
.gpt:       ld hl, oam_buf                  ; the party: OAM 0-23 shown ones
            ld b, 24
            jr .gc
.gfx:       ld a, [s16_n]
            and a
            ret z
            ld b, a
            ld hl, s16_in
.gc:        ld a, [hl]
            and a
            jr z, .gs
            cp 160
            jr nc, .gs
            ld a, [s16_wn]
            cp 64
            ret nc
            inc a
            ld [s16_wn], a
            ld a, [hl+]
            ld [de], a
            inc de
            ld a, [hl+]
            ld [de], a
            inc de
            ld a, [hl+]
            ld [de], a
            inc de
            ld a, [hl+]
            ld [de], a
            inc de
            jr .gn
.gs:        inc hl
            inc hl
            inc hl
            inc hl
.gn:        dec b
            jr nz, .gc
            ret

; slot C's two tiles from the key [HL] (top tile, flips, bottom tile, flips; $FF: blank)
s16_comp:   push bc
            ld l, c                         ; DE = S16_STG + 32 slot
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, S16_STG
            add hl, de
            ld d, h
            ld e, l
            ld l, c                         ; HL = S16_K + 4 slot
            ld h, 0
            add hl, hl
            add hl, hl
            ld bc, S16_K
            add hl, bc
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld c, a
            push hl
            call .tile
            pop hl
            ld a, [hl+]
            ld b, a
            ld c, [hl]
            call .tile
            pop bc
            ret
; tile B (flips C: $20 h, $40 v) -> 16 bytes at DE
.tile:      ld a, b
            cp $80
            jr c, .t1
            xor a                           ; (blank)
            ld b, 16
.z:         ld [de], a
            inc de
            dec b
            jr nz, .z
            ret
.t1:        ld l, b
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld a, h
            add a, high(S16_MIR)
            ld h, a
            ld b, 8
            bit 6, c
            jr z, .r
            ld a, l
            add a, 14
            ld l, a
.r:         ld a, [hl+]
            call .rv
            ld [de], a
            inc de
            ld a, [hl+]
            call .rv
            ld [de], a
            inc de
            bit 6, c
            jr z, .r1
            ld a, l
            sub 4
            ld l, a
.r1:        dec b
            jr nz, .r
            ret
.rv:        bit 5, c
            ret z
            push hl
            ld l, a
            ld h, high(FX_REV)
            ld a, [hl]
            pop hl
            ret

; ---- 34/8577 attack animation 1: magic (and $10: ineffective, 34/8555)
mx_ineff:   ld hl, BZ + $CC
            inc [hl]
            ld a, [W7 + $7E9A]
            bit 7, a
            jr z, .c
            call ba_mflash
            jr .x
.c:         xor a
            ld [W7 + $7E9B], a
            ld [W7 + $7E88], a
            ld [W7 + $7E9D], a
            call mx_magic
.x:         xor a
            ld [BZ + $CC], a
            ret
mx_magic:   ld a, [W7 + $7E88]              ; the spell's sound
            ld l, a
            ld h, 0
            ld de, $83A0 + F34
            add hl, de
            ld a, FXD
            call rd_byte
            ld [BZ + $CA], a
            xor a
            ld [BZ + $C9], a
            ld a, [W7 + $7E9A]
            bit 7, a
            call nz, ba_mflash
            ld a, [W7 + $7E98]              ; the animation's attacker ($52 / $95)
            call ba_maskid
            ld [BZ + $52], a
            ld [BZ + $95], a
            ld a, [W7 + $7E99]
            ld [W7 + $7E89], a
            call ba_mpos
            ld a, [W7 + $7E9A]              ; 2F/B15E: a member steps forward, its casting tiles
            bit 7, a
            jr nz, .m
            call ba_stepf
            call ba_cgfx
            call s16_start
            call mx_anim
            call ba_reset
            call s16_stop
            call ba_stepb
            jr .e
.m:         call s16_start
            call mx_anim
            call ba_reset
            call s16_stop
.e:         ld a, 1                         ; (the numerals' tiles again: sc_num)
            ld [ba_dirty], a
            xor a
            ld [BZ + $CC], a
            ret

; 33/BAFD the magic animation by type ($7E9D)
mx_anim:    ld a, [W7 + $7E9D]
            cp $13
            jr c, .t
            xor a
.t:         ld e, a
            ld d, 0
            ld hl, mx_tab
            add hl, de
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            call .j
            call ba_reset
            jp mx_wait
.j:         jp hl
mx_tab:     dw mx_norm, mx_norm, mx_norm, mx_norm, mx_norm, mx_life, mx_summ, mx_norm
            dw mx_norm, mx_norm, mx_norm, mx_norm, mx_norm, mx_norm, mx_norm, mx_none
            dw mx_norm, mx_norm, mx_norm
mx_none:    ret
; $06 summon / split: the sound
mx_summ:    ld a, [W7 + $7E99]
            inc a
            ret z
            ld hl, BZ + $C9
            inc [hl]
            ret
; $05 life: 16 frames fewer when hit, else the missed targets shown
mx_life:    ld a, [W7 + $7E9B]
            and a
            jr z, .m
            ld a, $10
            jr .s
.m:         ld a, [W7 + $7E99]
            ld [W7 + $7E9B], a
            xor a
.s:         ld [W7 + $7ECC], a
            jr mx_n2
; $00 normal: the casting, the flight, the hit
mx_norm:    xor a
            ld [W7 + $7ECC], a
mx_n2:      call mx_pre
            call mx_proj
            call ba_end
            jp mx_hit

; ---- 33/B09B the casting (black: bubbles, white: stars)
mx_pre:     call mx_props
            ld a, [W7 + $7E8B]
            and $80
            ld [mx_wh], a
            ld a, 5
            jr z, .b
            ld a, 6
.b:         call mx_gfx
            ld a, [W7 + $7E8D]              ; 33/AF94: the palette, the frames saved
            call ba_pal3
            call ba_save
            ld a, [W7 + $7E9A]
            bit 7, a
            ret nz
            xor a
            ld [BZ + $B6], a
            ld a, [BZ + $CC]
            and a
            jr z, .ef
.i:         call mx_cast                    ; (ineffective: 32 frames of the pose)
            call mx_wait
            call ba_inc
            cp $20
            jr nz, .i
            ret
.ef:        ld a, $A1
            ld [S49], a
            ld a, [mx_wh]
            and a
            jr nz, .wh
.k:         call mx_cast                    ; black: 44 frames
            call mx_bfr
            call mx_bub
            call mx_wait
            call ba_inc
            cp $2C
            jr nz, .k
            ret
.wh:        call mx_vres                    ; white: 8 stars around the caster, 48 frames, then
            ld a, $10                       ;   closing in
            call mx_vdall
            call mx_vcirc
.w1:        call mx_cast
            call mx_wfr
            call mx_star
            call mx_wait
            call ba_inc
            cp $30
            jr nz, .w1
.w2:        call mx_cast
            call mx_star
            ld e, 0
.w3:        ld a, 1
            call mx_vdsub
            inc e
            ld a, e
            cp 8
            jr nz, .w3
            call mx_wait
            ld hl, BZ + $B6
            inc [hl]
            ld a, [W7 + $7E26]
            and a
            jr nz, .w2
            ret
; 33/AF9F the casting pose (toad / mini: $0E)
mx_cast:    call ba_reset
            call ba_tm
            ld a, 8
            jr z, .c
            ld a, $0E
.c:         jp ba_cfr
; 33/B1CD / B1C3 / B1B9 the black / white / summon casting frame (33/B1D7 / B1E2 / B1EE by
; the frame counter / 4)
mx_bfr:     ld hl, $B1D7 + N33
            jr mx_fr
mx_wfr:     ld hl, $B1E2 + N33
            jr mx_fr
mx_sfr:     ld hl, $B1EE + N33
mx_fr:      ld a, [BZ + $B6]
            srl a
            srl a
            ld e, a
            ld d, 0
            add hl, de
            ld a, [hl]
            jp ba_aspr0
; 33/B1F8 the black magic bubbles: a 4 x 4 grid around the caster, every 2 frames the other
; half of 33/AEB2's tiles
mx_bub:     xor a
            ld [ba_mode], a
            ld a, [BZ + $B6]
            and 2
            add a, a
            add a, a
            add a, a                        ; (0 / 16)
            ld [mx_t], a
            ld b, 16
.l:         push bc
            ld a, [mx_t]
            ld e, a
            ld d, 0
            ld hl, $AEB2 + N33
            add hl, de
            ld a, [hl]
            push af
            and $0F
            add a, $49
            ld d, a                         ; tile
            pop af
            and $C0
            or 3
            ld [mx_t + 1], a
            ld a, e                         ; y = (i & $0C) * 2 - 4 + C4
            and $0C
            add a, a
            sub 4
            ld c, a
            ld a, [BZ + $95]
            ld hl, BZ + $C4
            add a, l
            ld l, a
            ld a, [hl]
            add a, c
            ld c, a
            ld a, e                         ; x = (i & 3) * 8 - 8 + C0
            and 3
            add a, a
            add a, a
            add a, a
            sub 8
            ld b, a
            ld a, [BZ + $95]
            ld hl, BZ + $C0
            add a, l
            ld l, a
            ld a, [hl]
            add a, b
            ld b, a
            ld a, [mx_t + 1]
            ld e, a
            call ba_put
            ld hl, mx_t
            inc [hl]
            pop bc
            dec b
            jr nz, .l
            ret
; 33/B134 the white magic stars: vectors 0-7 around the caster + (4, 6), tile $49, flipped
; every 4 frames and for odd stars
mx_star:    xor a
            ld [ba_mode], a
            ld [mx_t], a
.l:         ld a, [mx_t]
            ld e, a
            call mx_vx
            ld b, a
            ld a, [BZ + $95]
            ld hl, BZ + $C0
            add a, l
            ld l, a
            ld a, [hl]
            add a, 4
            add a, b
            ld b, a
            push bc
            call mx_vy
            ld c, a
            ld a, [BZ + $95]
            ld hl, BZ + $C4
            add a, l
            ld l, a
            ld a, [hl]
            add a, 6
            add a, c
            pop bc
            ld c, a
            ld a, [BZ + $B6]                ; (bit 1 of the counter: v-flip; odd stars: v-flip)
            and 2
            rrca
            rrca
            ld d, a
            ld a, [mx_t]
            rrca
            and $80
            xor d
            or 3
            ld e, a
            ld d, $49
            call ba_put
            ld hl, mx_t
            inc [hl]
            ld a, [hl]
            cp 8
            jr nz, .l
            ld e, 0
.a:         ld a, 4
            call mx_vaadd
            inc e
            ld a, e
            cp 8
            jr nz, .a
            ret

; ---- 33/B276 the flight: a sprite to each target (members on monsters only), 16 a frame
mx_proj:    ld a, [W7 + $7E9A]
            and $C0
            cp $40
            ret nz
            ld a, [BZ + $CC]
            and a
            ret nz
            call mx_cast
            call mx_wait
            call mx_vres
            ld a, [W7 + $7E89]
            ld [mx_t], a
            ld e, 0
.i:         push de
            call mx_angle
            pop de
            call mx_vaadd
            ld hl, W7 + $7E26
            ld d, 0
            add hl, de
            xor a
            ld [hl], a
            ld hl, W7 + $7E30
            add hl, de
            ld [hl], a
            ld hl, mx_t
            sla [hl]
            ld a, 0
            jr c, .on
            dec a
.on:        ld hl, W7 + $7300
            add hl, de
            ld [hl], a
            ld hl, W7 + $7308               ; (drawn: shown till the end)
            add hl, de
            ld [hl], a
            inc e
            ld a, e
            cp 8
            jr nz, .i
            xor a
            ld [BZ + $B6], a
.f:         call ba_reset
            call mx_cast
            ld e, 0
.p:         ld hl, W7 + $7300
            ld d, 0
            add hl, de
            ld a, [hl]
            inc a
            jr z, .pd
            push de
            call mx_vy
            ld [mx_t + 1], a
            call mx_vx
            ld [mx_t + 2], a
            ld a, $10
            call mx_vdadd
            ld a, [BZ + $95]
            ld hl, BZ + $C0
            add a, l
            ld l, a
            ld a, [mx_t + 2]
            add a, [hl]
            sub $10
            ld [BZ + $8C], a
            ld a, [BZ + $95]
            ld hl, BZ + $C4
            add a, l
            ld l, a
            ld a, [mx_t + 1]
            add a, [hl]
            adc a, 8
            ld [BZ + $8E], a
            pop de
            push de
            ld hl, W7 + $7310               ; (its place kept)
            add hl, de
            add hl, de
            ld a, [BZ + $8C]
            ld [hl+], a
            ld a, [BZ + $8E]
            ld [hl], a
            ld a, e                         ; the centre reached: done
            add a, a
            ld e, a
            ld hl, W7 + $7DD7
            add hl, de
            ld a, [BZ + $8C]
            ld b, a
            ld a, [hl]
            cp b
            pop de
            jr c, .pd
            ld hl, W7 + $7300
            ld d, 0
            add hl, de
            ld [hl], $FF
.pd:        call .spr
            inc e
            ld a, e
            cp 8
            jr nz, .p
            ld hl, BZ + $B6
            inc [hl]
            call mx_wait
            ld hl, W7 + $7300
            ld b, 8
.c:         ld a, [hl+]
            inc a
            jr nz, .f
            dec b
            jr nz, .c
            ld b, 10
.w:         push bc
            call ba_reset
            call mx_cast
            ld e, 0
.w1:        call .spr
            inc e
            ld a, e
            cp 8
            jr nz, .w1
            call mx_wait
            pop bc
            dec b
            jr nz, .w
            ret
.spr:       ld hl, W7 + $7308               ; 33/B322 projectile E at its place: tile $58, v-flip
            ld d, 0                         ;   every frame
            add hl, de
            ld a, [hl]
            inc a
            ret z
            push de
            ld hl, W7 + $7310
            add hl, de
            add hl, de
            ld a, [hl+]
            ld b, a
            ld c, [hl]
            ld a, 2
            ld [ba_mode], a
            ld a, [BZ + $B6]
            rrca
            and $80
            or 3
            ld e, a
            ld d, $58
            call ba_put
            pop de
            ret

; ---- 33/B68D the hit: the spell's frame list (06/8C00), every target hit in turn
mx_hit:     ld a, [W7 + $7E9B]
            ld [W7 + $7E89], a
            call mx_mgfx
            ld a, [W7 + $7E88]
            ld l, a
            ld h, 0
            add hl, hl
            ld de, $8C00 + F06
            add hl, de
            ld a, FXD
            call rd_byte
            ld e, a
            ld a, FXD
            call rd_byte
            ld d, a
            ld hl, F06
            add hl, de
            ld de, W7 + $7300
            ld bc, 256
            ld a, FXD
            call rd_copy
            ld a, [W7 + $7ECC]
            ld b, a
            ld a, [W7 + $7300]
            sub b
            ld [W7 + $7300], a
            xor a
            ld [BZ + $90], a
            ld a, [W7 + $7E89]
            ld [BZ + $91], a
.t:         ld hl, BZ + $91
            sla [hl]
            jr nc, .n
            call mx_hit1
            jr .x
.n:         ld hl, W7 + $7EB8
            sla [hl]
.x:         ld hl, BZ + $90
            inc [hl]
            ld a, [hl]
            cp 8
            jr nz, .t
            ret
; 33/B64F one target (reflected: the reflection, then on the one reflected onto)
mx_hit1:    ld hl, W7 + $7EB8
            sla [hl]
            jr nc, mx_hit2
            ld a, $B1
            call ba_pal3
            call mx_refl
            ld a, [W7 + $7E8D]
            call ba_pal3
            ld a, [BZ + $90]
            push af
            ld a, [W7 + $7E9A]
            push af
            xor $40
            ld [W7 + $7E9A], a
            ld a, [BZ + $90]
            ld e, a
            ld d, 0
            ld hl, W7 + $7EB9
            add hl, de
            ld a, [hl]
            call ba_maskid
            ld [BZ + $90], a
            call mx_hit2
            pop af
            ld [W7 + $7E9A], a
            pop af
            ld [BZ + $90], a
            ret
; 33/B6F3 the frames on target $90
mx_hit2:    ld hl, BZ + $C9
            inc [hl]
            ld a, 1
            ld [W7 + $7E9C], a
.f:         call mx_hfr
            ld hl, W7 + $7E9C
            inc [hl]
            ld a, [hl]
            dec a
            ld hl, W7 + $7300
            cp [hl]
            jr nz, .f
            call ba_reset
            jp mx_wait
; 33/B711 one frame: 36 sprites (6 x 6) at the target; on a monster in front of the party and
; 4 frames, on a member 1 (FF3 waits only for monsters: the frames follow each other at once)
mx_hfr:     call ba_reset
            call mx_frd
            ld a, [W7 + $7E9A]
            bit 6, a
            jr nz, .m
            ld a, [BZ + $90]                ; a member: C0 - 16, C4 - 12 (- 12 more: bit 5)
            ld hl, BZ + $C0
            add a, l
            ld l, a
            ld a, [hl]
            sub $10
            ld [BZ + $8C], a
            ld a, [BZ + $90]
            ld hl, BZ + $C4
            add a, l
            ld l, a
            ld a, [hl]
            sub $0C
            ld [BZ + $8D], a
            ld a, [W7 + $7E8B]
            and $20
            jr z, .l
            ld a, [BZ + $8D]
            sub $0C
            ld [BZ + $8D], a
.l:         ld a, [W7 + $7E9D]
            cp 5
            jr nz, .d
            ld a, [BZ + $8C]
            sub 8
            ld [BZ + $8C], a
            jr .d
.m:         ld a, [BZ + $90]                ; a monster: its centre - (24, 16)
            add a, a
            ld e, a
            ld d, 0
            ld hl, W7 + $7DD7
            add hl, de
            ld a, [hl+]
            sub $18
            ld [BZ + $8C], a
            ld a, [hl]
            sub $10
            ld [BZ + $8D], a
.d:         ld a, [W7 + $7E9A]              ; the mode: a monster's battlefield, or the member's
            bit 6, a                        ;   place (as the attacker's: $95 = the target)
            ld a, 1
            jr nz, .md
            xor a
.md:        ld [ba_mode], a
            ld [s16_front], a
            ld a, [BZ + $95]
            push af
            ld a, [BZ + $90]
            ld [BZ + $95], a
            ld hl, W7 + $7924
            ld b, 36
.s:         push bc
            ld a, [hl+]
            push hl
            ld hl, BZ + $8D
            add a, [hl]
            ld c, a
            pop hl
            ld a, [hl+]
            ld d, a
            ld a, [hl+]
            ld e, a
            ld a, [hl+]
            push hl
            ld hl, BZ + $8C
            add a, [hl]
            ld b, a
            call ba_put
            pop hl
            pop bc
            dec b
            jr nz, .s
            pop af
            ld [BZ + $95], a
            ld a, [W7 + $7E9A]
            bit 6, a
            ld b, 1
            jr z, .w
            ld b, 4
.w:         push bc
            call mx_wait
            pop bc
            dec b
            jr nz, .w
            xor a
            ld [s16_front], a
            ret
; 33/B7CF the frame's data: 06 list entry ($FF: v-flip the next), 00/9708 frame -> 36 tiles,
; positions by the flips (33/B89B), $7924: y, tile, flags, x
mx_frd:     xor a
            ld [BZ + $87], a
            ld a, [W7 + $7E9C]
            ld e, a
            ld d, 0
            ld hl, W7 + $7300
            add hl, de
            ld a, [hl+]
            cp $FF
            jr nz, .f
            ld a, 2
            ld [BZ + $87], a
            push hl
            ld hl, W7 + $7E9C
            inc [hl]
            pop hl
            ld a, [hl]
.f:         ld b, a
            and $7F
            ld [BZ + $86], a
            ld a, b
            rlca
            and 1
            ld hl, BZ + $87
            or [hl]
            ld [hl], a
            ld a, [BZ + $86]
            ld l, a
            ld h, 0
            add hl, hl
            ld de, $9708 + F00
            add hl, de
            ld a, FXD
            call rd_byte
            ld e, a
            ld a, FXD
            call rd_byte
            ld d, a
            ld hl, F00
            add hl, de
            ld de, W7 + $7900
            ld bc, 40
            ld a, FXD
            call rd_copy
            ld a, [W7 + $7E9A]
            bit 6, a
            jr nz, .mt
            ld a, [BZ + $87]                ; (a member: h-flipped again)
            xor 1
            ld [BZ + $87], a
.mt:        ld a, [BZ + $87]                ; positions: 33/B89B + 4 flips (x0, dx, y0, dy)
            add a, a
            add a, a
            ld e, a
            ld d, 0
            ld hl, $B89B + N33
            add hl, de
            ld a, [hl+]
            ld [mx_t], a
            ld a, [hl+]
            ld [mx_t + 1], a
            ld a, [hl+]
            ld c, a
            ld a, [hl]
            ld [mx_t + 2], a
            ld a, [BZ + $87]                ; the frame's flips: 33/B8AB
            ld e, a
            ld hl, $B8AB + N33
            add hl, de
            ld a, [hl]
            ld [mx_t + 3], a
            ld hl, W7 + $7924
            ld b, 6
.r:         ld a, [mx_t]
            ld d, a
            ld e, 6
.c:         ld a, c
            ld [hl+], a
            inc hl
            ld a, [mx_t + 3]
            ld [hl+], a
            ld a, d
            ld [hl+], a
            ld a, [mx_t + 1]
            add a, d
            ld d, a
            dec e
            jr nz, .c
            ld a, [mx_t + 2]
            add a, c
            ld c, a
            dec b
            jr nz, .r
            ld hl, W7 + $7900               ; the tiles: rvhttttt ($7F blank; r: the next byte
            ld de, W7 + $7925               ;   repeats it)
            ld c, 36
.t:         ld a, [hl+]
            bit 7, a
            jr nz, .rp
            call .one
            dec c
            jr nz, .t
            ret
.rp:        ld b, [hl]
            inc hl
.rr:        push af
            call .one
            pop af
            dec c
            ret z
            dec b
            jr nz, .rr
            jr .t
.one:       push hl                         ; (A: the byte) -> tile, flags at DE; DE + 4
            ld l, a
            and $7F
            cp $7F
            ld a, 0
            jr z, .o1
            ld a, l
            and $1F
            add a, $49
.o1:        ld [de], a
            inc de
            ld a, l
            add a, a
            and $C0
            ld l, a
            ld a, [de]
            xor l
            or 3
            ld [de], a
            inc de
            inc de
            inc de
            pop hl
            ret
; 33/B5BB the reflection: 4 frames of the wall (32/9453 at a monster, 32/9473 at a member)
mx_refl:    ret

; ---- 33/AF6F the spell's graphics properties (2E/91D0 + 3 spell) -> $7E8B-$7E8D
mx_props:   ld a, [W7 + $7E88]
            ld l, a
            ld h, 0
            ld d, h
            ld e, l
            add hl, hl
            add hl, de
            ld de, $91D0 + F2E
            add hl, de
            ld de, W7 + $7E8B
            ld bc, 3
            ld a, FXD
            jp rd_copy
; 33/B589 the hit's graphics: 24 tiles from 15/9600 (or A600: bit 6) + 16 x $7E8C at $49, then
; graphics 8 (15/A740: 8 tiles at $61)
mx_mgfx:    ld a, [W7 + $7E8B]
            and $40
            ld hl, $9600
            jr z, .a
            ld hl, $A600
.a:         ld a, [W7 + $7E8C]
            ld e, a
            ld d, 0
            ld b, 4
.m:         sla e
            rl d
            dec b
            jr nz, .m
            add hl, de
            ld a, 7
            call mx_gfxo
            ld a, 8
            jp mx_gfx
; 33/BF1E / BF24 animation graphics A (33/BEB2: source, ppu, tiles, bank; + HL) -> VRAM bank 1
mx_gfx:     ld hl, 0
mx_gfxo:    push hl                         ; (the offset)
            ld e, a
            add a, a
            add a, e
            add a, a
            ld e, a
            ld d, 0
            ld hl, $BEB2 + N33
            add hl, de
            ld a, [hl+]                     ; the source
            ld [mx_s], a
            ld a, [hl+]
            ld [mx_s + 1], a
            ld a, [hl+]                     ; ppu $1xx0 -> VRAM $8xx0
            ld e, a
            ld a, [hl+]
            add a, $70
            ld d, a
            ld a, [hl+]
            ld b, a                         ; tiles
            ld a, [hl]                      ; the bank: 15 -> MAGG, 06 -> MGFX_BANK0 + 4
            cp $15
            ld a, MAGG
            jr z, .b
            ld a, MGFX_BANK0 + 4
.b:         ld [vc_src], a
            pop hl
            ld a, [mx_s]
            add a, l
            ld l, a
            ld a, [mx_s + 1]
            adc a, h
            sub $40                         ; (NES $8000- -> GB $4000-)
            ld h, a
            ld a, 1
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
.w:         push bc
            call mx_wait
            pop bc
            dec b
            jr nz, .w
            ret

; ---- 33's vectors (33/BF5F-BFE4), vector E: $7E26 / $7E30 + E amplitudes (y / x), $7E3A /
; $7E44 + E angles; BC, DE kept
mx_vres:    ld hl, W7 + $7E3A
            ld b, 10
            xor a
.z:         ld [hl+], a
            dec b
            jr nz, .z
            ld b, 10
            ld a, $40
.f:         ld [hl+], a
            dec b
            jr nz, .f
            ret
mx_vx:      push bc
            push de
            ld d, 0
            ld hl, W7 + $7E30
            add hl, de
            ld c, [hl]
            ld hl, W7 + $7E44
            jr mx_vm
mx_vy:      push bc
            push de
            ld d, 0
            ld hl, W7 + $7E26
            add hl, de
            ld c, [hl]
            ld hl, W7 + $7E3A
mx_vm:      add hl, de
            ld l, [hl]                      ; 33/BFC6: C x sin(angle), FF3's ((2 s) & $FF) x C / 256
            ld h, 0
            ld de, CUT_SINE
            add hl, de
            ld a, CUTD
            call rd_byte
            ld e, c
            bit 7, a
            jr z, .p
            cpl
            call .m
            cpl
            inc a
            jr .x
.p:         call .m
.x:         pop de
            pop bc
            ret
.m:         add a, a
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
mx_vdadd:   push bc                         ; 33/BF87: both amplitudes + A
            ld b, a
            ld c, 0
            jr mx_va
mx_vdsub:   push bc                         ; 33/BF9C: - A
            cpl
            inc a
            ld b, a
            ld c, 0
            jr mx_va
mx_vaadd:   push bc                         ; 33/BFB1: both angles + A
            ld b, a
            ld c, $3A - $26
mx_va:      push de
            ld d, 0
            ld hl, W7 + $7E26
            ld a, l
            add a, c
            ld l, a
            add hl, de
            ld a, [hl]
            add a, b
            ld [hl], a
            ld a, l
            add a, 10
            ld l, a
            ld a, [hl]
            add a, b
            ld [hl], a
            pop de
            pop bc
            ret
mx_vdall:   ld hl, W7 + $7E26               ; 33/B35C: amplitudes 0-7 = A
            ld b, 8
.a:         ld [hl+], a
            dec b
            jr nz, .a
            ld hl, W7 + $7E30
            ld b, 8
.b:         ld [hl+], a
            dec b
            jr nz, .b
            ret
mx_vcirc:   ld e, 0                         ; 33/B362: angles + 32 E
.l:         ld a, e
            swap a
            add a, a
            call mx_vaadd
            inc e
            ld a, e
            cp 8
            jr nz, .l
            ret
; 33/A7A5 the angle from the attacker ($95) to target E: 33/A7E1[tilemap] + A7D7[tilemap] x
; attacker + E
mx_angle:   push de
            ld a, [W7 + $7D7B]
            ld c, a
            ld b, 0
            ld hl, $A7D7 + N33
            add hl, bc
            ld d, [hl]
            ld a, [BZ + $95]
            inc a
            ld l, a
            xor a
.m:         dec l
            jr z, .m1
            add a, d
            jr .m
.m1:        add a, e
            ld e, a
            ld d, 0
            ld hl, $A7E1 + N33
            add hl, bc
            add hl, bc
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            add hl, de
            ld de, N33
            add hl, de
            ld a, [hl]
            pop de
            ret

section wram, $DFB4
mx_wh:      ds 1
mx_t:       ds 4
mx_s:       ds 2
