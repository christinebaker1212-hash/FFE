; btlfx.s (CODE8): the 8 x 16 sprite mode and the magic animations (FF3 34/8577, 2F/B15E,
; 33/AF6F-BC88). The data: bank 33 at $6000 (build.py), FXD: 00/9700-9FFF (the hit frames),
; 06/8C00-9FFF (the spells' frame lists), 2E/9100-95FF (the graphics properties), 34/83A0 (the
; sounds); MAGG: NES banks $2A-$2B (FF3's bank 15: the magic graphics) as GB tiles.
;
; The GB has 40 sprites; FF3's spells draw up to 36 next to the party's 24, so while a spell
; shows, the sprites are 8 x 16: the party's and the effect's 8 x 8 sprites are paired
; (vertical neighbours of one palette), each pair's two tiles composed (flips put into the
; pixels) from a WRAM mirror of the sprite tiles into 56 slots (VRAM bank 1 tiles $00-$6F, back
; from the mirror after; the least recently used slot taken for a new pair).
N33        = -$4000             ; 33 address + N33 = the copy here
FX_REV     = $5F00              ; (build.py: the bit-reversed bytes)
F00        = $4000 - $9700      ; FXD: 00/9700-A1FF at $4000 (the hit frames)
F06        = $4B00 - $8C00      ; FXD: 06/8C00-91FF at $4B00 (the spells' frame lists)
F2E        = $5100 - $9100      ; FXD: 2E/9100-95FF at $5100 (the graphics properties)
F34        = $5600 - $83A0      ; FXD: 34/83A0- at $5600 (the sounds)
F2E8       = $5660 - $8040      ; FXD: 2E/8040- at $5660 (the glare colours)
F32        = $56C0 - $91C0      ; FXD: 32/91C0-920F at $56C0 (the fireball frames)
F32B       = $5710 - $9450      ; FXD: 32/9450-948F at $5710 (the reflection)
NSLOT      = 56                  ; (tiles $00-$6F: the font is at $70-)
NPAIR      = 40

; ---- the mode on: the slots emptied, the first picture built, then shown from the V-Blank
s16_start:  ldh a, [rSVBK]
            push af
            ld a, 5
            ldh [rSVBK], a
            ld hl, S16_K0
            ld b, 0
            ld a, $FF
.k:         ld [hl+], a
            dec b
            jr nz, .k
            ld hl, S16_A
            ld b, NSLOT
            xor a
.a:         ld [hl+], a
            dec b
            jr nz, .a
            ldh [s16_fc], a
            ld a, $FF
            ld [s16_sum], a
            pop af
            ldh [rSVBK], a
            xor a
            ld [s16_n], a
            ld [s16_lo], a
            ld [s16_hi], a
            ld [s16_front], a
            ld [s16_lock], a
            dec a
            ldh [s16_pp], a
            call s16_build
            ld a, 1
            ld [s16_on], a
            ret
; the mode off: 8 x 8 sprites from the next V-Blank; the tiles under the slots back from the
; mirror (two V-Blanks of 34 tiles)
s16_stop:   xor a
            ld [s16_on], a
            ld [s16_n], a
            ld hl, S16_MIR                  ; VRAM bank 1 tiles $00-$6F from the mirror (4 x 28)
            ld de, $8000
            ld b, 4
.r:         push bc
            push hl
            push de
            call wait_vbl
            pop de
            pop hl
            call .h
            ld bc, $1C0
            add hl, bc
            ld a, e
            add a, $C0
            ld e, a
            ld a, d
            adc a, 1
            ld d, a
            pop bc
            dec b
            jr nz, .r
            ret
.h:         ldh a, [rSVBK]
            push af
            ld a, 6
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
            ld a, 28 - 1
            ldh [rHDMA5], a
            xor a
            ldh [rVBK], a
            pop af
            ldh [rSVBK], a
            ret

; a frame: the picture built, FF3's pending sound effect started (FFAF2), V-Blank
mx_wait:    call s16_build
            call mx_snd
            jp wait_vbl
mx_snd:     ld a, [BZ + $C9]
            and a
            jr z, .w
            ld a, [BZ + $CA]
            or $80
            ld [S49], a
            xor a
            ld [BZ + $C9], a
.w:         ret

; ---- the picture: the party's sprites (OAM 0-23) and the effect's (s16_in) as 8 x 16 pairs; the
; party's pairs kept while its sprites stay the same
s16_build:  ldh a, [rSVBK]                  ; (WRAM 5 throughout; the bank kept there)
            ld b, a
            ld a, 5
            ldh [rSVBK], a
            ld a, b
            ld [s16_bk], a
            ld hl, oam_buf                  ; the sums: the party's (with the hidden flag), the effect's
            ld e, 96
            call .sum
            ldh a, [s16_np]
            xor b
            ld b, a
            ld a, [s16_sum]
            cp c
            jr nz, .pc
            ld a, [s16_sum + 1]
            cp b
            jr z, .pk
.pc:        ld a, c                         ; (the party changed)
            ld [s16_sum], a
            ld a, b
            ld [s16_sum + 1], a
            ld a, $FF
            ldh [s16_pp], a
.pk:        ld a, [s16_n]
            add a, a
            add a, a
            ld e, a
            ld hl, S16_IN
            ld a, [s16_n]
            ld c, a
            ld b, a
            and a
            call nz, .sum0
            ldh a, [s16_pp]
            inc a
            jr z, .go
            ldh a, [s16_eh]
            cp c
            jr nz, .go
            ldh a, [s16_eh + 1]
            cp b
            jr nz, .go
            ld a, [s16_bk]
            ldh [rSVBK], a
            ret
.go:        ld a, c
            ldh [s16_eh], a
            ld a, b
            ldh [s16_eh + 1], a
            ld a, 1
            ld [s16_lock], a
            ldh a, [s16_fc]                 ; (a new build: slots with this count are used)
            inc a
            ldh [s16_fc], a
            ldh a, [s16_pp]
            inc a
            jr z, .np
            dec a                           ; the party's pairs kept: their slots used
            ld [s16_pn], a
            and a
            jr z, .fx
            ld b, a
            ld hl, S16_PL + 3
.k1:        ld a, [hl]
            cp NSLOT
            jr nc, .k2
            push hl
            ld e, a
            ld d, 0
            ld hl, S16_A
            add hl, de
            ldh a, [s16_fc]
            ld [hl], a
            pop hl
.k2:        ld de, 8
            add hl, de
            dec b
            jr nz, .k1
            jr .fx
.np:        xor a                           ; the party paired again (its shown sprites -> W)
            ld [s16_pn], a
            ld [s16_wn], a
            ldh a, [s16_np]
            and a
            jr nz, .np1
            ld hl, oam_buf
            ld b, 24
            call .gather
            call .pair
.np1:
            ld a, [s16_pn]
            ldh [s16_pp], a
.fx:        xor a                           ; the effect paired (after the party's)
            ld [s16_wn], a
            ld a, [s16_n]
            and a
            jr z, .look
            ld b, a
            ld hl, S16_IN
            call .gather
            call .pair
.look:      ld a, [s16_pn]                  ; the new pairs: their keys looked up in the slots
            and a
            jp z, .out
            ld b, a
            ld hl, S16_PL + 3
.l1:        ld a, [hl]
            inc a
            jr nz, .l5                      ; (a slot already)
            push bc
            push hl
            inc hl
            ld a, [hl+]                     ; B = top tile: K0 searched
            ld b, a
            ld de, S16_K0
            ld c, NSLOT
.l2:        ld a, [de]
            cp b
            jr z, .l3
.l2n:       inc e
            dec c
            jr nz, .l2
            jr .l4
.l3:        push hl                         ; (K1-K3 at +64 / +128 / +192)
            push de
            ld a, e
            add a, $40
            ld e, a
            ld a, [de]
            cp [hl]
            jr nz, .l3n
            inc hl
            ld a, e
            add a, $40
            ld e, a
            ld a, [de]
            cp [hl]
            jr nz, .l3n
            inc hl
            ld a, e
            add a, $40
            ld e, a
            ld a, [de]
            cp [hl]
            jr nz, .l3n
            pop de                          ; found: slot E - K0
            pop hl
            pop hl
            push hl
            ld a, e
            sub low(S16_K0)
            ld [hl], a
            ld e, a
            ld d, 0
            ld hl, S16_A
            add hl, de
            ldh a, [s16_fc]
            ld [hl], a
            jr .l4
.l3n:       pop de
            pop hl
            jr .l2n
.l4:        pop hl
            pop bc
.l5:        ld de, 8
            add hl, de
            dec b
            jr nz, .l1
            ld a, [s16_pn]                  ; the others: the least recently used slot, composed
            ld b, a
            ld hl, S16_PL + 3
.a1:        ld a, [hl]
            inc a
            jp nz, .a5
            push bc
            push hl
            ld hl, S16_A                    ; (the oldest: the largest count - its count)
            ld bc, $FF00                    ; (C = the best age, B = its slot)
            ld e, 0
            ldh a, [s16_fc]
            ld d, a
.a2:        ld a, d
            sub [hl]
            jr z, .a3                       ; (used this build)
            cp c
            jr c, .a3
            ld c, a
            ld b, e
.a3:        inc hl
            inc e
            ld a, e
            cp NSLOT
            jr nz, .a2
            ld a, b
            pop hl
            inc a
            jr z, .a4x                      ; (none free)
            dec a
            ld [hl], a                      ; the slot, its count, its key
            ld c, a
            ld e, a
            ld d, 0
            push hl
            ld hl, S16_A
            add hl, de
            ldh a, [s16_fc]
            ld [hl], a
            pop hl
            push hl
            inc hl
            ld de, S16_K0
            ld a, e
            add a, c
            ld e, a
            ld a, [hl+]
            ld [de], a
            ld a, e
            add a, $40
            ld e, a
            ld a, [hl+]
            ld [de], a
            ld a, e
            add a, $40
            ld e, a
            ld a, [hl+]
            ld [de], a
            ld a, e
            add a, $40
            ld e, a
            ld a, [hl]
            ld [de], a
            call s16_comp                   ; C = slot
            pop hl
            ld a, [s16_hi]                  ; dirty: lo..hi
            ld b, a
            ld a, [s16_lo]
            cp b
            jr c, .a6
            ld a, c                         ; (nothing pending: lo = slot, hi = slot + 1)
            ld [s16_lo], a
            inc a
            ld [s16_hi], a
            jr .a4x
.a6:        ld a, [s16_lo]
            cp c
            jr c, .a7
            ld a, c
            ld [s16_lo], a
.a7:        ld a, [s16_hi]
            dec a
            cp c
            jr nc, .a4x
            ld a, c
            inc a
            ld [s16_hi], a
.a4x:       pop bc
.a5:        ld de, 8
            add hl, de
            dec b
            jp nz, .a1
.out:       ld de, S16_OAM                  ; the OAM: the effect's pairs first when in front
            ld a, [s16_front]
            and a
            jr z, .of
            call .oe
            call .op
            jr .o2
.of:        call .op
            call .oe
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
.o4:        ld a, [s16_bk]
            ldh [rSVBK], a
            xor a
            ld [s16_lock], a
            ret
.op:        ld hl, S16_PL                   ; the party's pairs: 0 .. pp - 1
            ldh a, [s16_pp]
            and a
            ret z
            ld b, a
            jr .o1
.oe:        ldh a, [s16_pp]                 ; the effect's: pp .. pn - 1
            ld c, a
            ld a, [s16_pn]
            sub c
            ret z
            ret c
            ld b, a
            ld l, c
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            push de
            ld de, S16_PL
            add hl, de
            pop de
.o1:        ld a, e
            cp 160
            ret nc
            ld a, [hl+]
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
            ret
; a sum of E bytes at HL -> BC (.sum0: from BC)
.sum:       ld bc, 0
.sum0:      ld a, [hl+]
            add a, c
            ld c, a
            ld a, b
            rlca
            xor c
            ld b, a
            dec e
            jr nz, .sum0
            ret
; B sprites at HL (shown ones: y 1-159) -> W (s16_wn)
.gather:    ld de, S16_W
.gc:        ld a, [hl]
            and a
            jr z, .gs
            cp 160
            jr nc, .gs
            ld a, [s16_wn]
            cp 80
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
; W's sprites paired (x the same, palette / bank / priority the same, y 8 apart) -> PL
.pair:      ld hl, S16_W
            ld a, [s16_wn]
            and a
            ret z
            ld [s16_i], a                   ; (left)
.pi:        ld a, [hl]
            and a
            jp z, .pn
            ld [hl], 0                      ; (taken)
            ld b, a                         ; B = y, C = x, D = tile, E = attributes
            inc hl
            ld a, [hl+]
            ld c, a
            ld a, [hl+]
            ld d, a
            ld a, [hl-]
            ld e, a
            dec hl
            dec hl
            push hl                         ; (-> W[i])
            ld a, [s16_i]
            dec a
            jr z, .single
            ld [s16_j], a
            inc hl
            inc hl
            inc hl
            inc hl
.pj:        ld a, [hl]                      ; y_j
            and a
            jr z, .pjn
            inc hl
            ld a, [hl-]
            cp c
            jr nz, .pjn
            inc hl
            inc hl
            inc hl
            ld a, [hl-]
            dec hl
            dec hl
            xor e
            and $9F
            jr nz, .pjn
            ld a, [hl]
            sub b
            cp 8
            jr z, .bot
            cp -8
            jr z, .top
.pjn:       inc hl
            inc hl
            inc hl
            inc hl
            ld a, [s16_j]
            dec a
            ld [s16_j], a
            jr nz, .pj
.single:    ld a, d
            ld [s16_t], a
            ld a, e
            ld [s16_t + 1], a
            ld a, $FF
            ld [s16_t + 2], a
            ld [s16_t + 3], a
            jr .key
.bot:       ld [hl], 0                      ; the partner below: W[i] top
            inc hl
            inc hl
            ld a, [hl+]
            ld [s16_t + 2], a
            ld a, [hl]
            ld [s16_t + 3], a
            ld a, d
            ld [s16_t], a
            ld a, e
            ld [s16_t + 1], a
            jr .key
.top:       ld [hl], 0                      ; the partner above: it is the top
            ld a, d
            ld [s16_t + 2], a
            ld a, e
            ld [s16_t + 3], a
            inc hl
            inc hl
            ld a, [hl+]
            ld [s16_t], a
            ld a, [hl]
            ld [s16_t + 1], a
            ld e, a
            ld a, b
            sub 8
            ld b, a
.key:       ld a, [s16_pn]                  ; the pair: y, x, attributes, slot $FF, key
            cp NPAIR
            jr nc, .kx
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
.kx:        pop hl                          ; (-> W[i])
.pn:        inc hl
            inc hl
            inc hl
            inc hl
            ld a, [s16_i]
            dec a
            ld [s16_i], a
            jp nz, .pi
            ret

; slot C's two tiles from its key (top tile, flips, bottom tile, flips; $FF: blank), composed from
; the mirror into the staging (both WRAM 6)
s16_comp:   push bc
            ld hl, S16_K0                   ; (the key: B, C top; D, E bottom)
            ld a, l
            add a, c
            ld l, a
            ld a, [hl]
            ld [s16_t], a
            ld a, l
            add a, $40
            ld l, a
            ld a, [hl]
            ld [s16_t + 1], a
            ld a, l
            add a, $40
            ld l, a
            ld a, [hl]
            ld [s16_t + 2], a
            ld a, l
            add a, $40
            ld l, a
            ld a, [hl]
            ld [s16_t + 3], a
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
            ld a, [s16_t]
            ld b, a
            ld a, [s16_t + 1]
            ld c, a
            push bc
            ld a, [s16_t + 2]
            ld b, a
            ld a, [s16_t + 3]
            ld c, a
            ld a, 6
            ldh [rSVBK], a
            ld a, b
            ld [s16_x], a
            ld a, c
            ld [s16_x + 1], a
            pop bc
            call .tile
            ld a, [s16_x]
            ld b, a
            ld a, [s16_x + 1]
            ld c, a
            call .tile
            ld a, 5
            ldh [rSVBK], a
            pop bc
            ret
; tile B (flips C: $20 h, $40 v) -> 16 bytes at DE (WRAM 6)
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
.r:         bit 5, c
            jr nz, .rh
            ld a, [hl+]
            ld [de], a
            inc de
            ld a, [hl+]
            ld [de], a
            inc de
            jr .r1
.rh:        push bc
            ld b, high(FX_REV)
            ld c, [hl]
            inc hl
            ld a, [bc]
            ld [de], a
            inc de
            ld c, [hl]
            inc hl
            ld a, [bc]
            ld [de], a
            inc de
            pop bc
.r1:        bit 6, c
            jr z, .r2
            ld a, l
            sub 4
            ld l, a
.r2:        dec b
            jr nz, .r
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
            call ui_hand                    ; (and the hand's: the spells' tiles reach $68)
            xor a
            ld [BZ + $CC], a
            ld a, [W7 + $7E9A]              ; 34/859F: on monsters, the split / brak2 / toad / mini
            bit 6, a
            ret z
            ld a, [W7 + $7E9D]
            cp 6
            jr z, .sp
            cp 7
            jr z, .br
            cp 8
            jr z, .td
            cp $0D
            ret nz
.td:        ld a, [W7 + $7E9B]              ; toad / mini (2F/BABA): exp counted, slots cleared
            and a
            ret z
            ld [W7 + $7DCA], a
            ld c, a
            ld b, 0
.t1:        sla c
            jr nc, .t2
            push bc
            ld e, b
            ld d, 0
            ld hl, W7 + $7DA7
            add hl, de
            ld a, [hl]
            ld [hl], $FF
            cp $FF
            jr z, .t3
            ld e, a
            ld hl, W7 + $7DD3
            add hl, de
            inc [hl]
.t3:        pop bc
.t2:        inc b
            ld a, b
            cp 8
            jr nz, .t1
            jp mon_redraw
.br:        ld a, [W7 + $7E9B]              ; brak2: the hit ones in palette 3
            ld [W7 + $7E8F], a
            ld a, 3
            ld [W7 + $7E90], a
            call mon_flash
            jp attr_push
.sp:        ld a, [W7 + $7E99]              ; split (2F/B93A): the type into the first free slot
            cp $FF
            ret z
            ld c, a
            ld hl, W7 + $7DA7
            ld b, 0
.s1:        ld a, [hl]
            cp $FF
            jr z, .s2
            inc hl
            inc b
            ld a, b
            cp 6
            jr nz, .s1
            ret
.s2:        ld [hl], c
            ld e, b
            ld d, 0
            ld hl, W7 + $7ECD
            add hl, de
            ld [hl], c
            jp mon_redraw

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
mx_tab:     dw mx_norm, mx_kill, mx_quake, mx_meteo, mx_drain, mx_life, mx_summ, mx_norm
            dw mx_norm, mx_flare, mx_tsun, mx_glare, mx_expl, mx_norm, mx_eq, mx_none
            dw mx_flame, mx_bliz, mx_thun
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

; ---- the special spells
; 33/B911 the casting, the end, the hit's graphics
mx_b911:    call mx_pre
            call ba_end
            jp mx_mgfx
; $06 summon / split: the sound
; $01 kill: 8 sprites spiralling out around the caster (128 -> 188), then to the target
mx_kill:    call mx_pre
            ld a, [W7 + $7E9B]
            and a
            jp z, ba_end
            ld hl, BZ + $C9
            inc [hl]
            call mx_cast
            call mx_wait
            call mx_mgfx
            call mx_cast
            call mx_wait
            call mx_vres
            xor a
            call mx_vdall
            call mx_vcirc
            ld a, 2
            ld [ba_mode], a
            ld a, $80
            ld [BZ + $B6], a
.f:         call mx_eclr
            ld e, 0
.s:         call mx_kxy
            ld a, $FC
            call mx_vaadd
            ld a, [BZ + $B6]                ; x amplitude: sin(2 B6 & $7F) x B6 / 2 >> 8
            add a, a
            and $7F
            call mx_sin
            ld c, a
            ld a, [BZ + $B6]
            srl a
            call mx_mul
            ld hl, W7 + $7E30
            ld d, 0
            add hl, de
            ld [hl], a
            ld a, [BZ + $B6]                ; y: sin(B6 / 2 + $40 & $7F) x B6 / 2 >> 8
            srl a
            add a, $40
            and $7F
            call mx_sin
            ld c, a
            ld a, [BZ + $B6]
            srl a
            call mx_mul
            ld hl, W7 + $7E26
            ld d, 0
            add hl, de
            ld [hl], a
            inc e
            ld a, e
            cp 8
            jr nz, .s
            ld hl, BZ + $B6
            inc [hl]
            call mx_wait
            ld a, [BZ + $B6]
            cp $BC
            jr nz, .f
            xor a                           ; 33/B417: to the target (vector 8: 33/B413[attacker])
            ld [BZ + $B6], a
            ld [W7 + $7E2E], a
            ld [W7 + $7E38], a
            ld a, [BZ + $95]
            ld e, a
            ld d, 0
            ld hl, $B413 + N33
            add hl, de
            ld a, [hl]
            ld e, 8
            call mx_vaadd
.k:         call mx_eclr
            ld e, 0
.k1:        call mx_vx
            ld [BZ + $8C], a
            call mx_vy
            ld [BZ + $8E], a
            call mx_kbase
            push de
            ld e, 8
            call mx_vx
            ld hl, BZ + $8D
            add a, [hl]
            ld [hl], a
            call mx_vy
            ld hl, BZ + $8F
            add a, [hl]
            ld [hl], a
            pop de
            call mx_one
            ld a, $FC
            call mx_vaadd
            inc e
            ld a, e
            cp 8
            jr nz, .k1
            ld a, [W7 + $7E38]
            add a, 4
            ld [W7 + $7E38], a
            ld [W7 + $7E2E], a
            call mx_wait
            call ba_inc
            cp $30
            jr nz, .k
            jp ba_end
; (the spiral's place: vector E's offsets, the caster's C0 - 8 / C4 + 8)
mx_kxy:     call mx_vx
            ld [BZ + $8C], a
            call mx_vy
            ld [BZ + $8E], a
            call mx_kbase
            jp mx_one
mx_kbase:   ld a, [BZ + $95]
            ld hl, BZ + $C0
            add a, l
            ld l, a
            ld a, [hl]
            sub 8
            ld [BZ + $8D], a
            ld a, l
            add a, 4
            ld l, a
            ld a, [hl]
            add a, 8
            ld [BZ + $8F], a
            ret
; 33/B519 one sprite at ($8D + $8C, $8F + $8E) (signed offsets; off the frame: none), tile $49 / $4A
; every 2 frames, palette 3
mx_one:     push de
            ld a, [BZ + $8C]
            ld hl, BZ + $8D
            bit 7, a
            jr nz, .xn
            add a, [hl]
            jr c, .x
            jr .y
.xn:        add a, [hl]
            jr nc, .x
.y:         ld b, a
            ld a, [BZ + $8E]
            ld hl, BZ + $8F
            bit 7, a
            jr nz, .yn
            add a, [hl]
            jr c, .x
            cp $90
            jr nc, .x
            jr .d
.yn:        add a, [hl]
            jr nc, .x
.d:         ld c, a
            ld a, [BZ + $B6]
            and 2
            rrca
            add a, $49
            ld d, a
            ld e, 3
            call mx_put
.x:         pop de
            ret
; $04 drain: per target hit, 8 sprites closing in on it
mx_drain:   call mx_b911
            ld a, [W7 + $7E9B]
            and a
            ret z
            call mx_mgfx
            ld a, [W7 + $7E89]
            ld [W7 + $7E8A], a
            xor a
            ld [BZ + $8A], a
.t:         ld hl, W7 + $7E8A
            sla [hl]
            call c, .one
            ld hl, BZ + $8A
            inc [hl]
            ld a, [hl]
            cp 8
            jr nz, .t
            ret
.one:       ld hl, BZ + $C9
            inc [hl]
            call ba_reset
            call mx_wait
            call mx_vres
            ld a, $80
            call mx_vdall
            call mx_vcirc
            call mx_wait
            ld a, 2
            ld [ba_mode], a
.f:         call mx_eclr
            ld e, 0
.s:         call mx_vx
            ld [BZ + $8C], a
            call mx_vy
            ld [BZ + $8E], a
            ld a, [W7 + $7E9A]
            bit 6, a
            jr nz, .m
            ld a, [BZ + $8A]                ; a member: C0 + 4, C4 + 8
            ld hl, BZ + $C0
            add a, l
            ld l, a
            ld a, [hl]
            add a, 4
            ld [BZ + $8D], a
            ld a, l
            add a, 4
            ld l, a
            ld a, [hl]
            add a, 8
            ld [BZ + $8F], a
            jr .d
.m:         ld a, [BZ + $8A]                ; a monster: its centre
            add a, a
            ld c, a
            ld b, 0
            ld hl, W7 + $7DD7
            add hl, bc
            ld a, [hl+]
            ld [BZ + $8D], a
            ld a, [hl]
            ld [BZ + $8F], a
.d:         call mx_one
            ld a, $FC
            call mx_vaadd
            ld a, 4
            call mx_vdsub
            inc e
            ld a, e
            cp 8
            jr nz, .s
            ld hl, BZ + $B6
            inc [hl]
            call mx_wait
            ld a, [W7 + $7E26]
            cp 8
            jr nc, .f
            ret
; $02 quake: members shaken 16 times; on monsters the caster's frames $5C-$5E, then the earthquake
mx_quake:   call mx_b911
            ld a, [W7 + $7E9B]
            and a
            ret z
            ld hl, BZ + $C9
            inc [hl]
            ld a, [W7 + $7E9A]
            bit 6, a
            jr nz, .m
            ld b, 16
.l:         push bc
            ld c, 1
            call .sh
            ld c, -1
            call .sh
            pop bc
            dec b
            jr nz, .l
            ret
.sh:        ld hl, BZ + $C0
            ld b, 4
.s:         ld a, [hl]
            add a, c
            ld [hl+], a
            dec b
            jr nz, .s
            call chr_draw
            call mx_wait
            jp mx_wait
.m:         call ba_save
            call ba_reset
            call ba_tm
            ld a, 3
            jr z, .c
            ld a, $0C
.c:         call ba_cfr
            ld a, $5C
            call ba_aspr0
            ld a, $5D
            call ba_aspr0
            ld a, $5E
            call ba_aspr0
            call mx_shake
            jp ba_end
; $0E earthquake
mx_eq:      call mx_b911
            ld a, [W7 + $7E9B]
            and a
            ret z
; 32/8C8D the earthquake: 16 frames, then 64 of the battlefield shaken (x 0-3, FF3's random)
mx_shake:   ld b, 16
.w:         push bc
            call mx_wait
            pop bc
            dec b
            jr nz, .w
            ld hl, BZ + $C9
            inc [hl]
            ldh a, [scx]
            ld [mx_s], a
            ld b, $40
.f:         push bc
            call mx_wait
            call ba_rnd255
            and 3
            ld hl, mx_s
            add a, [hl]
            ldh [scx], a
            pop bc
            dec b
            jr nz, .f
            ld a, [mx_s]
            ldh [scx], a
            jp mx_wait
; $03 meteo / cave-in: 6 fireballs falling for 64 frames (x from FF3's random table)
mx_meteo:   call mx_b911
            ld a, [W7 + $7E9B]
            and a
            ret z
            ld hl, W7 + $7900
            ld b, 6
.i:         xor a
            ld [hl+], a
            dec b
            jr nz, .i
            ld b, 6                         ; ($790C: the counters from 33/B9E0)
            ld de, $B9E0 + N33
            ld hl, W7 + $790C
.i2:        ld a, [de]
            inc de
            ld [hl+], a
            dec b
            jr nz, .i2
            ld hl, W7 + $7912
            ld b, 6
            xor a
.i3:        ld [hl+], a
            dec b
            jr nz, .i3
            ld hl, BZ + $C9
            inc [hl]
            ld a, $40
            ld [BZ + $B6], a
            ld a, 2
            ld [ba_mode], a
.f:         call mx_wait
            call mx_eclr
            ld e, 0
.b:         ld d, 0
            ld hl, W7 + $790C
            add hl, de
            dec [hl]
            jr nz, .sh
            ld [hl], $0A                    ; a new fireball: y 8, x = random & $38 + 33/B9DA
            ld hl, W7 + $7906
            add hl, de
            ld [hl], 8
            ld hl, BZ + $90
            inc [hl]
            ld a, [hl]
            ld c, a
            ld b, 0
            ld hl, W7 + $7BE3
            add hl, bc
            ld a, [hl]
            and $38
            ld hl, $B9DA + N33
            add hl, de
            add a, [hl]
            ld hl, W7 + $7900
            add hl, de
            ld [hl], a
            ld hl, W7 + $7912
            add hl, de
            ld [hl], 1
.sh:        ld hl, W7 + $7912
            add hl, de
            ld a, [hl]
            and a
            jr z, .n
            ld hl, W7 + $7900
            add hl, de
            ld a, [hl]
            and a
            jr z, .off
            cp $F8
            jr z, .off
            ld hl, W7 + $7906
            add hl, de
            ld a, [hl]
            cp $88
            jr nc, .off
            push de
            call .draw
            pop de
            ld hl, W7 + $7900               ; x +- 8 (towards the target side), y + 12
            add hl, de
            ld a, [W7 + $7E9A]
            bit 6, a
            ld a, [hl]
            jr nz, .mm
            add a, 8
            jr .mx
.mm:        sub 8
.mx:        ld [hl], a
            ld hl, W7 + $7906
            add hl, de
            ld a, [hl]
            add a, $0C
            ld [hl], a
            jr .n
.off:       ld hl, W7 + $7912
            add hl, de
            ld [hl], 0
.n:         inc e
            ld a, e
            cp 6
            jr nz, .b
            ld hl, BZ + $B6
            dec [hl]
            jr nz, .f
            ret
.draw:      ld hl, W7 + $7900               ; 33/BA95: 32/91CB's 2 x 3 frame (by the side),
            add hl, de                      ;   tiles 33/B9CE (small every other frame)
            ld a, [hl]
            ld [BZ + $8C], a
            ld hl, W7 + $7906
            add hl, de
            ld a, [hl]
            ld [BZ + $8D], a
            ld hl, W7 + $790C
            add hl, de
            ld a, [hl]
            and 1
            ld c, 0
            jr z, .d0
            ld c, 6
.d0:        ld a, [W7 + $7E9A]
            and $40
            ld hl, $91EF + F32
            jr z, .d1
            ld hl, $91D7 + F32
.d1:        ld b, 6
.d2:        push bc
            push hl
            ld a, FXD
            call rd_byte                    ; y
            ld d, a
            ld a, [BZ + $8D]
            add a, d
            ld [mx_t], a
            inc hl
            ld a, FXD
            call rd_byte                    ; attributes
            or 3
            ld [mx_t + 1], a
            ld a, FXD
            call rd_byte                    ; x
            ld d, a
            ld a, [BZ + $8C]
            add a, d
            ld [mx_t + 2], a
            ld b, 0                         ; the tile: 33/B9CE + C
            ld hl, $B9CE + N33
            add hl, bc
            ld d, [hl]
            ld a, [mx_t + 2]
            ld b, a
            ld a, [mx_t]
            ld c, a
            ld a, [mx_t + 1]
            ld e, a
            call mx_put
            pop hl
            ld bc, 4
            add hl, bc
            pop bc
            inc c
            dec b
            jr nz, .d2
            ret
; $0A tsunami: 13 rows of waves for 88 frames (x from FF3's random table)
mx_tsun:    ld a, [W7 + $7E9B]
            and a
            ret z
            ld hl, W7 + $7BE3
            ld de, W7 + $7900
            ld b, 13
.i:         ld a, [hl+]
            and 7
            add a, $B0
            ld [de], a
            inc de
            dec b
            jr nz, .i
            ld a, $10
            call mx_gfx
            ld a, $BC
            call ba_pal3
            xor a
            ld [BZ + $B6], a
            ld hl, BZ + $C9
            inc [hl]
            ld a, 2
            ld [ba_mode], a
.f:         call mx_wait
            call mx_eclr
            ld a, [BZ + $B6]
            and 1
            add a, $2C
            ld [BZ + $8D], a
            ld e, 0
.r:         ld a, [BZ + $B6]
            and 3
            ld d, 0
            ld hl, W7 + $7900
            add hl, de
            add a, [hl]
            ld [BZ + $8C], a
            inc [hl]
            push de
            ld d, $4B                       ; 3 sprites $4B, $4A, $49 (x < $50: hidden)
            ld b, 3
.s:         push bc
            ld a, [BZ + $8C]
            cp $50
            jr c, .sx
            ld b, a
            ld a, [BZ + $8D]
            ld c, a
            ld e, $43
            push de
            call mx_put
            pop de
.sx:        ld a, [BZ + $8C]
            add a, 8
            ld [BZ + $8C], a
            dec d
            pop bc
            dec b
            jr nz, .s
            pop de
            ld a, [BZ + $8D]
            add a, 8
            ld [BZ + $8D], a
            inc e
            ld a, e
            cp 13
            jr nz, .r
            call ba_inc
            cp $58
            jr nz, .f
            ret
; $0B glare / mind blast / mega flare: the screen flashed in the spell's colour (2E/804B)
mx_glare:   ld a, [W7 + $7E9B]
            and a
            ret z
            ld hl, BZ + $C9
            inc [hl]
            ld a, [W7 + $7E88]
            sub $38
            ld l, a
            ld h, 0
            ld de, $804B + F2E8
            add hl, de
            ld a, FXD
            call rd_byte
            jr mx_fl1
; $0C explode: red
mx_expl:    ld a, [W7 + $7E99]
            and a
            ret z
            ld a, $16
mx_fl1:     ld hl, BZ + $C9
            inc [hl]
; 32/877F the backdrop flashed in A every 4 frames for 32 frames
mx_flash:   ld [mx_s], a
            ld b, $20
.f:         push bc
            call s16_build
            call mx_snd
            pop bc
            push bc
            ld a, b
            and 3
            ld a, $0F
            jr nz, .c
            ld a, [mx_s]
.c:         call ba_bkd
            pop bc
            dec b
            jr nz, .f
            ret
; $09 flare wave (the final boss): the casting, then red flashes (10/8BD5's cloud wave: later)
mx_flare:   ld a, [W7 + $7E9B]
            and a
            ret z
            call mx_b911
            ld hl, BZ + $C9
            inc [hl]
            ld a, $16
            jr mx_fl1
; $10-$12 enemy flame / blizzard / thunder: 6 x 16 sprites over the party's column (FF3 clears the
; party's sprites meanwhile), frames 06/8E20 + $60 n toggled every 4 frames, 32 frames
mx_flame:   xor a
            jr mx_emag
mx_bliz:    ld a, 2
            jr mx_emag
mx_thun:    ld a, 4
mx_emag:    push af
            call mx_b911
            pop af
            ld [mx_s], a
            ld a, [W7 + $7E9B]
            and a
            ret z
            ld hl, BZ + $C9
            inc [hl]
            ld a, 1
            ldh [s16_np], a
            xor a
            ld [BZ + $B6], a
            ld a, 3
            ld [ba_mode], a
.f:         call mx_wait
            ld a, [BZ + $B6]
            and 4
            rrca
            rrca
            ld hl, mx_s
            add a, [hl]
            call .fr
            call ba_inc
            and $20
            jr z, .f
            xor a
            ldh [s16_np], a
            ret
.fr:        cp 5                            ; (frame 5 is FF3's $7360 buffer: all $FF)
            jr nc, .x
            ld l, a                         ; 06/8E20 + $60 frame
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld d, h
            ld e, l
            add hl, hl
            add hl, de
            ld de, $8E20 + F06
            add hl, de
            push hl
            call mx_eclr
            pop hl
            ld c, $18                       ; y $18 + 8 row, x $C8 + 8 column
            ld b, 16
.r:         push bc
            ld b, $C8
            ld e, 6
.c:         push de
            push hl
            push bc
            ld a, FXD
            call rd_byte
            pop bc
            cp $FF
            jr z, .n
            push bc
            ld d, a
            and $C0
            or 3
            ld e, a
            ld a, d
            and $3F
            add a, $49
            ld d, a
            call mx_put
            pop bc
.n:         pop hl
            inc hl
            ld a, b
            add a, 8
            ld b, a
            pop de
            dec e
            jr nz, .c
            pop bc
            ld a, c
            add a, 8
            ld c, a
            dec b
            jr nz, .r
.x:         ret
; the effect's sprites cleared (FF3's sprites 6-13: the party stays)
mx_eclr:    xor a
            ld [s16_n], a
            ret
; A = sin(A) (FF3's table, signed) ; A x C >> 8 (unsigned)
mx_sin:     push hl
            push de
            ld l, a
            ld h, 0
            ld de, CUT_SINE
            add hl, de
            ld a, CUTD
            call rd_byte
            pop de
            pop hl
            ret
mx_mul:     push de
            ld d, a
            xor a
            ld b, 8
.l:         srl d
            jr nc, .n
            add a, c
.n:         rra
            dec b
            jr nz, .l
            pop de
            ret

; ---- 34/8411 attack animations 2-$0D (summon: later; cannon: a pause)
mx_other:   cp 2
            jr nz, .o
            ld a, [W7 + $7E98]              ; (2: the summon, btlsum.s)
            call ba_maskid
            ld [BZ + $52], a
            ld [BZ + $95], a
            jp sm_main
.o:         ld [mx_t], a
            ld a, [W7 + $7E98]              ; 34/8532: the attacker
            call ba_maskid
            ld [BZ + $52], a
            ld [BZ + $95], a
            ld a, [mx_t]
            sub 4
            jr c, .p                        ; (2-3)
            ld e, a
            ld d, 0
            ld hl, .t
            add hl, de
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            jp hl
.p:         ld b, 12
.w:         call wait_vbl
            dec b
            jr nz, .w
            ret
.t:         dw mx_front, mx_back, mx_defend, mx_jump1, mx_jump2, mx_build, mx_scare, mx_cheer
            dw .p, mx_run
; 2F/B443 / B42A the member to the front / back row (16 pixels, walked)
mx_front:   xor a
            ld b, $F0
            jr mx_row
mx_back:    ld a, 1
            ld b, $10
mx_row:     ld [W7 + $7D7D], a
            ld [mx_t + 1], a
            ld a, [BZ + $95]
            ld e, a
            ld d, 0
            ld hl, W7 + $7D7F
            add hl, de
            ld a, [hl]
            add a, b
            ld [hl], a
            ld hl, W7 + $7D8F
            add hl, de
            ld a, [mx_t + 1]
            ld [hl], a
            xor a
            ld [W7 + $7CF4], a
            jp ba_walk
; (A972: the attacker's frame A, B when toad / mini)
mx_tfr:     ld c, a
            push bc
            call ba_tm
            pop bc
            ld a, c
            jr z, .s
            ld a, b
.s:         jp ba_cfr
; the start: palette A, graphics B, frames saved, the counter 0, sound C
mx_jst:     push bc
            call ba_pal3
            pop bc
            push bc
            ld a, b
            call mx_gfx
            call ba_save
            xor a
            ld [BZ + $B6], a
            pop bc
            ld a, c
            ld [S49], a
            ret
; 33/AC3A the end: the frames back, drawn, a frame
mx_jend:    call ba_rest
            call chr_draw
            jp wait_vbl
; 33/ABF7 defend: 32 frames of the shield ($38-$3B)
mx_defend:  call ba_cgfx
            ld a, $C1
            ld bc, $03A0
            call mx_jst
.f:         call ba_reset
            ld a, 8
            ld b, $0E
            call mx_tfr
            ld a, [BZ + $B6]
            and $18
            rrca
            rrca
            rrca
            add a, $38
            call ba_aspr0
            call wait_vbl
            call ba_inc
            and $20
            jr z, .f
            jp mx_jend
; 33/A92B cheer: 32 frames, arms up / down every 8
mx_cheer:   call ba_cgfx
            ld a, $E5
            ld bc, $00CB
            call mx_jst
.f:         call ba_reset
            ld a, [BZ + $B6]
            and 8
            jr nz, .b
            ld a, 5
            ld b, $0E
            call mx_tfr
            xor a
            jr .s
.b:         ld a, 1
            ld b, $0A
            call mx_tfr
            ld a, 1
.s:         call ba_aspr0
            call wait_vbl
            call ba_inc
            and $20
            jr z, .f
            jp mx_jend
; 33/A988 scare: 32 frames, the face shaking (y +- 1 every 2 frames)
mx_scare:   call ba_stepf
            call ba_cgfx
            ld a, $F1
            ld bc, $018F
            call mx_jst
.f:         call ba_reset
            ld a, 8
            ld b, $0E
            call mx_tfr
            ld a, [BZ + $B6]
            and 2
            ld a, 1
            jr z, .y
            ld a, $FF
.y:         ld [BZ + $7F], a
            xor a
            ld [BZ + $7E], a
            ld a, 1
            call ba_aspr
            call wait_vbl
            call ba_inc
            and $20
            jr z, .f
            call mx_jend
            jp ba_stepb
; 33/AB27 buildup: 32 frames of the glow ($3C-$43); overloaded ($7E93): 8 frames of the burst
mx_build:   ld a, [W7 + $7E93]
            ld [W7 + $7E19], a
            call ba_stepf
            call ba_cgfx
            call ba_hgfx
            ld a, $BB
            ld bc, $02A1
            call mx_jst
.f:         call ba_reset
            ld a, 8
            ld b, $0E
            call mx_tfr
            ld a, [BZ + $B6]
            and 4
            add a, $3C
            ld [BZ + $88], a
            call ba_aspr0
            ld b, 3
.g:         push bc
            ld hl, BZ + $88
            inc [hl]
            ld a, [hl]
            call ba_aspr0
            pop bc
            dec b
            jr nz, .g
            call wait_vbl
            call ba_inc
            and $20
            jr z, .f
            ld a, [W7 + $7E19]
            and a
            jr z, .x
            ld a, $B0
            ld [S49], a
            xor a
            ld [BZ + $B6], a
.o:         call ba_reset
            call chr_draw
            ld a, 4
            ld b, $0F
            call mx_tfr
            ld a, [BZ + $B6]                ; the four sparks: (-n, -n), (n, -n), (-n, n), (n, n)
            cpl
            inc a
            ld c, a
            ld a, [BZ + $B6]
            ld b, a
            ld a, c
            ld d, c
            ld e, $44
            call .sp
            ld a, b
            ld d, c
            ld e, $45
            call .sp
            ld a, c
            ld d, b
            ld e, $46
            call .sp
            ld a, b
            ld d, b
            ld e, $47
            call .sp
            call wait_vbl
            call ba_inc
            and 8
            jr z, .o
.x:         call mx_jend
            jp ba_stepb
.sp:        push bc                         ; x offset A (confused: inverted), y D, frame E
            ld b, a
            call ba_conf
            ld a, b
            jr z, .s1
            cpl
.s1:        ld [BZ + $7E], a
            ld a, d
            ld [BZ + $7F], a
            ld a, e
            call ba_aspr
            pop bc
            ret
ba_conf:    ld a, [BZ + $95]                ; (33/ABE5: the attacker confused: NZ)
            ld e, a
            ld d, 0
            ld hl, W7 + $7D9B
            add hl, de
            add hl, de
            ld a, [hl]
            and 8
            ret
; 33/AAB8 jump 1: 16 frames crouched, then up off the screen ($7E22: where it left)
mx_jump1:   call ba_stepf
            call ba_cgfx
            call ba_save
            xor a
            ld [BZ + $B6], a
            ld a, [BZ + $95]
            ld e, a
            ld d, 0
            ld hl, BZ + $C0
            add hl, de
            ld a, [hl]
            ld [mx_t + 1], a
            ld a, $C4
            ld [S49], a
.c:         call ba_reset
            ld a, 3
            call ba_cfr
            call wait_vbl
            call ba_inc
            and $10
            jr z, .c
.u:         call ba_reset
            call .hl
            ld a, [hl]
            sub 8
            ld [hl], a
            ld a, l
            sub 4
            ld l, a
            dec [hl]
            dec [hl]
            ld a, 7
            call ba_cfr
            call wait_vbl
            call .hl
            ld a, [hl]
            cp $0A
            jr nc, .u
            ld a, l
            sub 4
            ld l, a
            ld a, [hl]
            ld [mx_t + 2], a
            ld a, [mx_t + 1]
            ld [hl], a
            ld a, [BZ + $95]
            ld e, a
            ld d, 0
            ld hl, W7 + $7E22
            add hl, de
            ld a, [mx_t + 2]
            ld [hl], a
            jp mx_jend
.hl:        ld a, [BZ + $95]                ; HL -> C4 + attacker
            add a, low(BZ + $C4)
            ld l, a
            ld h, high(BZ + $C4)
            ret
; 33/AA15 jump 2: down on the target ($B8) with the dragoon sprite, then back down to its row
mx_jump2:   ld a, [W7 + $7E99]
            call ba_maskid
            ld [BZ + $B8], a
            call ba_cgfx
            ld a, $0A                       ; (2F/A1B3 graphics $0A: the jump tiles 14/B9C0 -> $49)
            ld hl, $79C0
            ld de, $8000 + 16 * $49
            ld b, 6
            call mx_ctile
            ld a, $FD
            call ba_pal3
            call ba_save
            ld a, [BZ + $95]
            ld e, a
            ld d, 0
            ld hl, W7 + $7E22
            add hl, de
            ld a, [hl]
            ld [hl], 0
            ld hl, BZ + $C0
            add hl, de
            ld [hl], a
            ld a, [BZ + $B8]                ; $8E = centre x - 8 + (bottom - 8) / 4, $90 the steps
            ld e, a
            ld d, 0
            ld hl, W7 + $7E07
            add hl, de
            ld a, [hl]
            sub 8
            srl a
            srl a
            ld [BZ + $90], a
            ld b, a
            ld hl, W7 + $7DD7
            add hl, de
            add hl, de
            ld a, [hl]
            sub 8
            add a, b
            ld [BZ + $8E], a
            ld hl, BZ + $90
            srl [hl]
            ld a, [hl]
            ld [BZ + $91], a
            xor a
            ld [BZ + $7E], a
.d:         call .st
            ld a, [BZ + $7E]
            add a, 8
            ld [BZ + $7E], a
            ld hl, BZ + $91
            dec [hl]
            jr nz, .d
            ld a, [BZ + $90]
            ld [BZ + $91], a
            ld a, $B6
            ld [S49], a
.e:         call .st
            ld a, [BZ + $7E]
            sub 8
            ld [BZ + $7E], a
            ld hl, BZ + $91
            dec [hl]
            jr nz, .e
            call ba_reset
            ld b, 32
.w:         call wait_vbl
            dec b
            jr nz, .w
.l:         call ba_reset                   ; down to its row (33/AAA6)
            call mx_jump1.hl
            ld a, [hl]
            add a, 8
            ld [hl], a
            ld a, l
            sub 4
            ld l, a
            inc [hl]
            inc [hl]
            ld a, 8
            call ba_cfr
            call wait_vbl
            call mx_jump1.hl
            ld a, [BZ + $95]
            ld e, a
            ld d, 0
            push hl
            ld hl, $AAA6 + N33
            add hl, de
            ld a, [hl]
            pop hl
            cp [hl]
            jr nz, .l
            call mx_jend
            jp ba_stepb
.st:        call wait_vbl                   ; 33/AA02: the 6 sprites (32/91D7) at ($8E, $7E)
            ld a, [BZ + $8E]
            ld [BZ + $8C], a
            ld a, [BZ + $7E]
            ld [BZ + $8D], a
            call ba_reset
            ld a, 1
            ld [ba_mode], a
            ld hl, $91D7 + F32
            ld c, $49
            ld b, 6
.s:         push bc
            ld a, FXD
            call rd_byte
            ld b, a
            ld a, [BZ + $8D]
            add a, b
            ld [mx_t], a
            inc hl
            inc hl
            ld a, FXD
            call rd_byte
            ld b, a
            ld a, [BZ + $8C]
            add a, b
            pop de
            push de
            ld b, a
            ld a, [mx_t]
            ld c, a
            ld e, 3
            push hl
            call ba_put
            pop hl
            pop bc
            inc c
            dec b
            jr nz, .s
            ld hl, BZ + $8E
            dec [hl]
            dec [hl]
            ret
; B tiles from CHGFX_BANK HL -> VRAM bank 1 DE (FF969's 4 a frame)
mx_ctile:   ld a, CHGFX_BANK
            ld [vc_src], a
            ld a, 1
            ld [ba_dirty], a
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
.w:         call wait_vbl
            dec b
            jr nz, .w
            ret
; 34/84D7 run: a member's party (33/BC89: 32 frames turning round, then all walk off); monsters
; flash, then (2F/BB5E, as their deaths) vanish
mx_run:     ld a, [W7 + $7E9A]
            bit 7, a
            jr nz, .m
            ld a, [W7 + $78D4]
            and a
            ret z
            xor a
            ld [BZ + $B6], a
.f:         call ba_vblc                    ; (a different member flipped every 8 frames)
            ld a, [BZ + $B6]
            and $18
            rrca
            rrca
            ld e, a
            ld d, 0
            ld hl, W7 + $7D9B
            add hl, de
            ld a, [hl]
            and $C0
            jr nz, .n
            srl e
            ld hl, W7 + $7D83
            add hl, de
            set 7, [hl]
.n:         call chr_draw
            call ba_inc
            and $20
            jr z, .f
            ld a, $B3
            ld [S49], a
            ld c, 0
.o:         ld b, 0                         ; each: off the screen ($F0; back attack: 0, faced)
            ld hl, W7 + $7D9B
            add hl, bc
            add hl, bc
            ld a, [hl]
            and $C0
            jr nz, .dd
            ld a, [W7 + $78C3]
            cp $88
            ld a, $F0
            jr nz, .o1
            xor a
.o1:        ld hl, W7 + $7D7F
            add hl, bc
            ld [hl], a
            ld hl, W7 + $7D83
            add hl, bc
            res 7, [hl]
            ld hl, W7 + $7D9B
            add hl, bc
            add hl, bc
            set 3, [hl]
            jr .on
.dd:        ld hl, BZ + $C0                 ; (dead / stone: stay)
            add hl, bc
            ld a, [hl]
            ld hl, W7 + $7D7F
            add hl, bc
            ld [hl], a
.on:        inc c
            ld a, c
            cp 4
            jr nz, .o
            ld a, [W7 + $78C3]
            cp $88
            ld a, 1
            jr nz, .o2
            xor a
.o2:        ld [W7 + $7D7D], a
            xor a
            ld [W7 + $7CF4], a
            jp ba_walk
.m:         call ba_mflash
            ld a, [W7 + $78D4]
            and a
            ret z
            jp mon_run

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
.c:         ld e, a                         ; (the pose unchanged: not drawn again)
            ld a, [BZ + $95]
            ld c, a
            ld b, 0
            ld hl, W7 + $7D83
            add hl, bc
            ld a, [hl]
            cp e
            ret z
            ld a, e
            jp ba_cfr
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
            call mx_put
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
            call mx_put
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
            call mx_put
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
            call mx_put
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
mx_refl:    ld a, 4
            ld [BZ + $B6], a
.f:         call mx_wait
            call mx_eclr
            ld a, [BZ + $95]
            push af
            ld a, [W7 + $7E9A]
            bit 6, a
            jr nz, .m
            ld a, [BZ + $90]                ; a member: C0 - 16, C4 - 4 (placed by it)
            ld [BZ + $95], a
            ld hl, BZ + $C0
            add a, l
            ld l, a
            ld a, [hl]
            sub $10
            ld [BZ + $8C], a
            ld a, l
            add a, 4
            ld l, a
            ld a, [hl]
            sub 4
            ld [BZ + $8D], a
            xor a
            ld [ba_mode], a
            ld hl, $9473 + F32B
            jr .d
.m:         ld a, [BZ + $90]                ; a monster: its centre
            add a, a
            ld e, a
            ld d, 0
            ld hl, W7 + $7DD7
            add hl, de
            ld a, [hl+]
            ld [BZ + $8C], a
            ld a, [hl]
            ld [BZ + $8D], a
            ld a, 1
            ld [ba_mode], a
            ld hl, $9453 + F32B
.d:         call .four
            ld a, [BZ + $8D]
            add a, $10
            ld [BZ + $8D], a
            call .four
            pop af
            ld [BZ + $95], a
            ld hl, BZ + $B6
            dec [hl]
            jr nz, .f
            jp ba_reset
.four:      ld b, 4                         ; 4 sprites: dy, tile, attributes | 3, dx
.s:         push bc
            ld a, FXD
            call rd_byte
            ld c, a
            ld a, [BZ + $8D]
            add a, c
            ld [mx_t], a
            ld a, FXD
            call rd_byte
            ld d, a
            ld a, FXD
            call rd_byte
            or 3
            ld e, a
            ld a, FXD
            call rd_byte
            ld c, a
            ld a, [BZ + $8C]
            add a, c
            ld b, a
            ld a, [mx_t]
            ld c, a
            push hl
            call mx_put
            pop hl
            pop bc
            dec b
            jr nz, .s
            ret

; FF3 sprite (B = x, C = y, D = tile, E = FF3 attributes) -> s16_in, placed as btlanim.s's ba_put
; (ba_mode 0: by the member $95 in the party column, 1: the battlefield, 2: a projectile)
mx_put:     ld a, d
            and a
            ret z
            ld a, [ba_mode]
            and a
            jr z, .pc
            dec a
            jr z, .bf
            dec a
            jr z, .pj
            ld a, b                         ; 3: the party's column (enemy magic): x - 88, y - 32
            sub 88
            ld b, a
            ld a, c
            sub 32
            ld c, a
            jr .mir
.pj:        ld a, [W7 + $78C3]              ; 2: x <= 128 as the battlefield, >= 192 as the party
            cp $88                          ;   column, between them compressed; y - 32
            ld a, b
            jr nz, .j0
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
            jr .mir
.bf:        ld a, c                         ; 1: (x - 12, y - 32); a back attack: 180 - x
            sub 32
            ld c, a
            ld a, [W7 + $78C3]
            cp $88
            ld a, b
            jr nz, .b1
            cpl
            add a, 181
            ld b, a
            ld a, e
            xor $40
            ld e, a
            jr .w
.b1:        sub 12
            ld b, a
            jr .w
.pc:        ld a, [BZ + $95]                ; 0: y - (4 m + $1B); x - C0 + the member's base
            ld l, a
            add a, a
            add a, a
            add a, $1B
            ld h, a
            ld a, c
            sub h
            ld c, a
            ld a, l
            add a, low(BZ + $C0)
            ld l, a
            ld h, high(BZ + $C0)
            ld a, b
            sub [hl]
            ld b, a
            ld a, [W7 + $78C3]              ; (the base: 140 + (x - 208) / 2 + 8; back: 240 - x)
            cp $88
            ld a, [hl]
            jr nz, .n
            cpl
            add a, 241
.n:         sub 208
            sra a
            add a, 148
            add a, b
            ld b, a
.mir:       ld a, [W7 + $78C3]
            cp $88
            jr nz, .w
            ld a, 168                       ; (a back attack: mirrored)
            sub b
            ld b, a
            ld a, e
            xor $40
            ld e, a
.w:         ld a, e                         ; FF3 attributes -> GB
            and 3
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
            ld a, [s16_n]
            cp 80
            ret nc
            ld l, a
            inc a
            ld [s16_n], a
            ld h, 0
            add hl, hl
            add hl, hl
            push de
            ld de, S16_IN
            add hl, de
            pop de
            ld a, 5
            ldh [rSVBK], a
            ld a, c
            ld [hl+], a
            ld a, b
            ld [hl+], a
            ld a, d
            ld [hl+], a
            ld [hl], e
            ld a, 3
            ldh [rSVBK], a
            ret

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
