; ---- special animations ($EF, FF3 3B/A4FA) and the world map's objects (3E/D85A), bank CODE6:
; this code at $4000, then NES tables at their NES address minus a constant: 3E/DCAA (vehicle
; frames) at $53C0, 3C/8400-87FF (sprite lists) at $5400 (NES - $3000), 3A/9800-9FFF at $5800
; and 3B at $6000 (NES - $4000). Sprites are placed in FF3's screen coordinates (256 x 240, the
; party at (112, 108)) and turned into GB OAM entries (x - 32, y - 31, bank 1 tiles, FF3's
; attributes converted), into the free OAM slots from an_p on (40 at most).
N3A        = -$4000             ; 3A / 3B address + N3A = the copy here
N3C        = -$3000
DCAA       = $53C0

; ---- sprites
; the frame: a V-Blank, OAM cleared, the party (A = 0: on foot, else as it is) at 0-3
an_begin:   push af
            call wait_vbl
            ld hl, oam_buf
            ld b, 40
.c:         ld [hl], 0
            inc l
            inc l
            inc l
            inc l
            dec b
            jr nz, .c
            pop af
            and a
            jr nz, .p
            ld a, [GS + $0F]                ; (Y = 0: the walker)
            push af
            xor a
            ld [GS + $0F], a
            call make_oam
            pop af
            ld [GS + $0F], a
            jr .q
.p:         call make_oam
.q:         ld a, 16
            ld [an_p], a
            ld hl, fcnt                     ; (FF3's $F0: a frame)
            inc [hl]
            ret
; FF3 sprite (B = x, C = y, D = tile, E = attributes) -> the next free GB OAM slot
an_put:     ld a, c
            cp $EF
            ret nc
            sub 40                          ; on screen: y 40..190, x 33..199
            ret c
            cp 151
            ret nc
            ld a, b
            sub 33
            ret c
            cp 167
            ret nc
            ld a, [an_p]
            ld l, a
            ld h, high(oam_buf)
.f:         ld a, l                         ; (a free slot: y = 0 or hidden below)
            cp 160
            ret nc
            ld a, [hl]
            and a
            jr z, .w
            cp 160
            jr nc, .w
            inc l
            inc l
            inc l
            inc l
            jr .f
.w:         ld a, c
            sub 31
            ld [hl+], a
            ld a, b
            sub 32
            ld [hl+], a
            ld a, d
            ld [hl+], a
            ld a, e                         ; palette (+4: the OBJ palettes), bank 1, flips, behind
            and 3
            or 8
            bit 6, e
            jr z, .h
            or $20
.h:         bit 7, e
            jr z, .v
            or $40
.v:         bit 5, e
            jr z, .b
            or $80
.b:         ld [hl+], a
            ld a, l
            ld [an_p], a
            ret
; FDA3A a 2 x 2 object sprite at (an_x, an_y): HL = 8 bytes (TL, BL, TR, BR: tile, attributes),
; tiles + an_t
an_obj:     ld a, [an_x]
            ld b, a
            ld a, [an_y]
            ld c, a
            call .one                       ; TL
            ld a, c
            add a, 8
            ld c, a
            call .one                       ; BL
            ld a, c
            sub 8
            ld c, a
            ld a, b
            add a, 8
            ld b, a
            call .one                       ; TR
            ld a, c
            add a, 8
            ld c, a
.one:       ld a, [an_t]
            add a, [hl]
            inc hl
            ld d, a
            ld a, [hl+]
            ld e, a
            push hl
            push bc
            call an_put
            pop bc
            pop hl
            ret
; 3C/87CD a sprite list at HL (NES 3C address): dy, tile, attributes, dx (signed, adding up),
; $FF ends; sprites past the screen's 0-255 skipped (16-bit positions), from (an_x, an_y)
an_list:    ld de, N3C
            add hl, de
            ld a, [an_x]
            ld [an_lx], a
            xor a
            ld [an_lx + 1], a
            ld [an_ly + 1], a
            ld a, [an_y]
            ld [an_ly], a
.l:         ld a, [hl+]
            cp $FF
            ret z
            ld de, an_ly
            call .add
            ld a, [hl+]
            ld [an_lt], a
            ld a, [hl+]
            ld [an_la], a
            ld a, [hl+]
            ld de, an_lx
            call .add
            ld a, [an_lx + 1]
            ld b, a
            ld a, [an_ly + 1]
            or b
            jr nz, .l
            push hl
            ld a, [an_lx]
            ld b, a
            ld a, [an_ly]
            ld c, a
            ld a, [an_lt]
            ld d, a
            ld a, [an_la]
            ld e, a
            call an_put
            pop hl
            jr .l
.add:       ld b, 0                         ; [DE] (16 bits) += A (signed)
            bit 7, a
            jr z, .a1
            dec b
.a1:        ld c, a
            ld a, [de]
            add a, c
            ld [de], a
            inc de
            ld a, [de]
            adc a, b
            ld [de], a
            ret

; 3A/9DA4 the projectile position: radius an_r, angle an_a (low: sine index, high & 3: the
; quadrant) -> (an_x, an_y) around (116, 116)
an_proj:    ld a, [an_a]
            call .sin
            ld [an_lt], a                   ; (x part)
            ld a, [an_a]
            cpl
            call .sin
            ld [an_la], a                   ; (y part)
            ld a, [an_a + 1]
            and 3
            jr z, .q
            dec a
            jr nz, .q2
            ld a, [an_lt]                   ; 1: (x, y) = (y, -x)
            ld b, a
            ld a, [an_la]
            ld [an_lt], a
            ld a, b
            cpl
            inc a
            ld [an_la], a
            jr .q
.q2:        dec a
            jr nz, .q3
            ld a, [an_lt]                   ; 2: (-x, -y)
            cpl
            inc a
            ld [an_lt], a
            ld a, [an_la]
            cpl
            inc a
            ld [an_la], a
            jr .q
.q3:        ld a, [an_la]                   ; 3: (x, y) = (-y, x)
            ld b, a
            ld a, [an_lt]
            ld [an_la], a
            ld a, b
            cpl
            inc a
            ld [an_lt], a
.q:         ld a, [an_lt]
            add a, $74
            ld [an_x], a
            ld a, [an_la]
            add a, $74
            ld [an_y], a
            ret
.sin:       ld l, a                         ; 3A/9E3E[A] x an_r, the product's high byte
            ld h, 0
            ld de, $9E3E + N3A
            add hl, de
            ld e, [hl]
            ld a, [an_r]
            ld d, a
            ld hl, 0
            ld b, 8
.m:         add hl, hl
            sla e
            jr nc, .m1
            ld a, l
            add a, d
            ld l, a
            jr nc, .m1
            inc h
.m1:        dec b
            jr nz, .m
            ld a, h
            ret

; 3A/999C the explosion: frame A (mod 5) at (B, C): its five pieces (3A/99DA: dx, dy, piece,
; adding up), each a 2 x 2 sprite of 3A/9A48 + 8 piece
an_expl:    ld e, a
            ld a, b
            ld [an_x], a
            ld a, c
            ld [an_y], a
            ld a, e
.m5:        cp 5
            jr c, .f
            sub 5
            jr .m5
.f:         add a, a
            ld l, a
            ld h, 0
            ld de, $99DA + N3A
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld de, N3A
            add hl, de
            xor a
            ld [an_t], a
.p:         ld a, [hl+]
            cp $FF
            ret z
            ld b, a
            ld a, [an_x]
            add a, b
            ld [an_x], a
            ld a, [hl+]
            ld b, a
            ld a, [an_y]
            add a, b
            ld [an_y], a
            ld a, [hl+]
            push hl
            add a, a
            add a, a
            add a, a
            add a, low($9A48 + N3A)
            ld l, a
            ld a, high($9A48 + N3A)
            adc a, 0
            ld h, a
            call an_obj
            pop hl
            jr .p

; ---- the special animations (fx.s: fx_special calls spa_* -> these by far call)
; 5-8 (3B/A806 / A819): 128 frames, explosions at (64, 80) and (118, 84), frame / 4
an_statue:  xor a
            ld [an_bc], a
.f:         ld a, [GS + $0F]
            call an_begin
            call an_inv
            ld a, [an_bc]
            srl a
            srl a
            push af
            ld bc, $4050
            call an_expl
            pop af
            ld bc, $7654
            call an_expl
            ld hl, an_bc
            inc [hl]
            bit 7, [hl]
            jr z, .f
            ret
an_inv:     jp inv_parked                   ; (the parked Invincible: before the sprites)

; 1 (3A/9AB8): the vehicle's sprites (OAM 32-35, 3A/9B04 the airship's) break up while the
; boulder at (80, 80) explodes, 128 frames
an_burst:   call an_grab                    ; (the vehicle as drawn: the party's sprites)
            ld hl, $9B04 + N3A
            ld bc, 16
            call memcpy
            xor a
            ld [an_bc], a
.f:         ld a, [GS + $0F]
            call an_begin
            xor a
            ld [an_ab0], a
            call an_brk
            ld a, [an_bc]
            srl a
            srl a
            ld bc, $5050
            call an_expl
            ld hl, an_bc
            bit 7, [hl]
            jr z, .f
            ret
; the party's four GB sprites (OAM 0-3) -> an_ab in FF3's form (y + 31, tile, attributes, x + 32);
; DE = an_ab + 16
an_grab:    ld hl, oam_buf
            ld de, an_ab
            ld b, 4
.g:         ld a, [hl+]
            add a, 31 - 16 + 16
            sub 16
            ld [de], a
            inc de
            ld a, [hl+]
            add a, 32
            ld c, a                         ; (x, stored last)
            ld a, [hl+]
            ld [de], a                      ; tile
            inc de
            ld a, [hl+]
            push bc
            ld c, a
            and 3
            bit 5, c
            jr z, .h
            or $40
.h:         bit 6, c
            jr z, .v
            or $80
.v:         bit 7, c
            jr z, .p
            or $20
.p:         pop bc
            ld [de], a
            inc de
            ld a, c
            ld [de], a
            inc de
            dec b
            jr nz, .g
            ret

; 3A/9B73 the pieces (3A/9B2E from an_ab0: piece, table; each moved by 3A/9CB4 on the frames
; its 3A/9C24 bit allows), an_bc + 1
an_brk:     ld a, [an_ab0]
            ld e, a
            ld d, 0
            ld hl, $9B2E + N3A
            add hl, de
            ld a, [hl+]
            cp $FF
            jr z, .e
            add a, a
            add a, a
            ld [an_lt], a                   ; (sprite offset)
            ld a, [hl]
            ld [an_la], a                   ; (table)
            call .one
            ld hl, an_ab0
            inc [hl]
            inc [hl]
            jr an_brk
.e:         ld hl, an_bc
            inc [hl]
            ld hl, an_ab                    ; the pieces as they are now
            ld b, 8
.d:         push bc
            ld a, [hl+]
            ld c, a
            ld a, [hl+]
            ld d, a
            ld a, [hl+]
            ld e, a
            ld a, [hl+]
            ld b, a
            push hl
            call an_put
            pop hl
            pop bc
            dec b
            jr nz, .d
            ret
.one:       ld a, [an_bc]
            and 7
            ld e, a
            ld d, 0
            ld hl, $9C1C + N3A
            add hl, de
            ld c, [hl]
            ld a, [an_bc]
            rrca
            rrca
            rrca
            and $1F
            ld e, a
            ld hl, $9C24 + N3A
            add hl, de
            ld a, [hl]
            and c
            ret z
            ld a, [an_la]
            swap a
            and $F0
            ld b, a
            ld a, [an_bc]
            add a, a
            and $0F
            or b
            ld e, a
            ld d, 0
            ld hl, $9CB4 + N3A
            add hl, de
            ld a, [an_lt]
            add a, low(an_ab)
            ld c, a
            ld b, high(an_ab)
            ld a, [hl+]                     ; x
            and a
            jr z, .y
            push hl
            ld h, b
            ld l, c
            inc l
            inc l
            inc l
            bit 7, a
            jr nz, .xm
            add a, [hl]
            ld [hl], a
            jr nc, .x1
            jr .gone
.xm:        ld a, [hl]
            sub 1
            ld [hl], a
            jr nc, .x1
.gone:      dec l
            dec l
            dec l
            ld [hl], $F8
.x1:        pop hl
.y:         ld a, [hl]
            and a
            ret z
            ld h, b
            ld l, c
            ld a, [hl]
            sub 1
            cp $F0
            jr c, .y1
            ld a, $F8
.y1:        ld [hl], a
            ret

; 4: 3B/A3EA Saronia's four cannon balls, then 3A/9A7B the airship shot down (128 frames: an
; explosion at (96, 72), the pieces from 3A/9B2E + $11)
an_saronia: ld hl, .balls
            ld b, 4
.b:         push bc
            ld a, [hl+]
            ld [an_a], a
            ld a, [hl+]
            ld [an_a + 1], a
            ld a, [hl+]
            ld [an_r], a
            ld a, [hl+]
            ld [an_sp], a
            push hl
            call an_ball
            pop hl
            pop bc
            dec b
            jr nz, .b
            call an_grab
            ld hl, $9B04 + N3A
            ld bc, 16
            call memcpy
            xor a
            ld [an_bc], a
.f:         ld a, [GS + $0F]
            call an_begin
            ld a, $11
            ld [an_ab0], a
            call an_brk
            ld a, [an_bc]
            srl a
            srl a
            ld bc, $6048
            call an_expl
            ld hl, an_bc
            bit 7, [hl]
            jr z, .f
            ret
.balls:     db $00, $01, $FF, $02
            db $00, $03, $E8, $82
            db $80, $01, $FF, $04
            db $50, $02, $FF, $84
; 3B/A433 a ball: the angle +/- 2 a frame, the radius - speed until < $20; tile $B5
an_ball:    ld a, [GS + $0F]
            call an_begin
            call an_proj
            ld a, [an_x]
            ld b, a
            ld a, [an_y]
            ld c, a
            ld de, $B503
            call an_put
            ld a, [an_sp]
            bit 7, a
            ld hl, an_a
            ld a, [hl]
            jr nz, .m
            add a, 2
            ld [hl+], a
            jr nc, .r
            inc [hl]
            jr .r
.m:         sub 2
            ld [hl+], a
            jr nc, .r
            dec [hl]
.r:         ld a, [an_sp]
            and $0F
            ld b, a
            ld a, [an_r]
            sub b
            ld [an_r], a
            cp $20
            jr nc, an_ball
            ld hl, GS + $2F                 ; (the walker spins)
            set 6, [hl]
            xor a
            ld [spin_c], a
            ret

; 0 (3B/A8A9): the Enterprise comes down: 3B/A906 (two sets of 10 sprites, every 4 frames) and
; the ship at (112, $6F down to $60), every 4 frames a line
an_enter:   ld a, $6F
            ld [an_62], a
            xor a
            ld [an_bc], a
.f:         ld a, [GS + $0F]
            call an_begin
            ld a, [an_bc]                   ; 3B/A8EB
            and 4
            ld hl, $A906 + $28 + N3A
            jr z, .s
            ld hl, $A906 + N3A
.s:         ld b, 10
.l:         push bc
            ld a, [hl+]
            ld c, a
            ld a, [hl+]
            ld d, a
            ld a, [hl+]
            ld e, a
            ld a, [hl+]
            ld b, a
            push hl
            call an_put
            pop hl
            pop bc
            dec b
            jr nz, .l
            ld a, $70                       ; 3B/A956: 3B/A99A / A9A2 by the frame, tiles + $68
            ld [an_x], a
            ld a, [an_62]
            ld [an_y], a
            ld a, $68
            ld [an_t], a
            ld a, [fcnt]
            and 8
            add a, low($A99A + N3A)
            ld l, a
            ld a, high($A99A + N3A)
            adc a, 0
            ld h, a
            call an_obj
            ld hl, an_bc
            inc [hl]
            ld a, [fcnt]
            and 3
            jr nz, .f
            ld hl, an_62
            dec [hl]
            ld a, [hl]
            cp $60
            jr nc, .f
            ret

; 9 (3B/A66A): the Invincible rises: 64 frames of the sea parting (3B/A6D4, three sprites,
; every 8 frames, odd frames none), then 64 steps of 4 frames rising (3B/A77A spray, the ship by
; the 3C/8857 lists)
an_rise:    xor a
            ld [an_bc], a
.f:         ld a, [GS + $0F]
            call an_begin
            ld a, [an_bc]                   ; 3B/A6AF
            rrca
            rrca
            rrca
            bit 7, a                        ; (the bit shifted out: odd groups draw nothing)
            jr nz, .n
            and 7
            ld b, a
            add a, a
            add a, b
            add a, a
            add a, a                        ; 12 x
            ld e, a
            ld d, 0
            ld hl, $A6D4 + N3A
            add hl, de
            ld b, 3
.l:         push bc
            ld a, [hl+]
            ld c, a
            ld a, [hl+]
            ld d, a
            ld a, [hl+]
            ld e, a
            ld a, [hl+]
            ld b, a
            push hl
            call an_put
            pop hl
            pop bc
            dec b
            jr nz, .l
.n:         ld hl, an_bc
            inc [hl]
            ld a, [hl]
            cp $40
            jr c, .f
            xor a
            ld [an_bc], a
.g:         ld a, [GS + $0F]
            call an_begin
            ld a, [an_bc]                   ; 3B/A7E2 the ship at (bc ^ $3F + $70, (bc ^ $3F) / 2
            xor $3F                         ;   + $5F), frame (bc & 2) << 4 | 4 (GB OAM: - 32,
            ld b, a                         ;   - 31)
            srl a
            add a, $5F - 31
            ld c, a
            ld a, b
            add a, $70 - 32
            ld b, a
            ld a, [an_bc]
            and 2
            swap a
            or 4
            call inv_draw
            ld a, [an_bc]                   ; 3B/A734 the spray
            xor $3F
            add a, $68
            ld [an_x], a
            ld a, $70
            ld [an_y], a
            ld hl, $A77A + N3A
            ld b, 24
.s:         push bc
            ld a, [hl+]
            ld b, a
            ld a, [an_y]
            add a, b
            ld [an_y], a
            ld c, a
            ld a, [hl+]
            ld d, a
            ld a, [hl+]
            ld e, a
            ld a, [hl+]
            ld b, a
            ld a, [an_x]
            add a, b
            ld [an_x], a
            ld b, a
            push hl
            call an_put
            pop hl
            pop bc
            dec b
            jr nz, .s
            ld a, 4
.w:         push af                         ; (4 frames a step)
            call wait_vbl
            pop af
            dec a
            jr nz, .w
            ld hl, an_bc
            inc [hl]
            ld a, [hl]
            cp $40
            jr c, .g
            ret

; C (3B/A264): Bahamut flies from (an_e6, an_e7) to (112, 112), 2 pixels a step on the longer
; axis (a line), drawn by the 3C/88DB lists
an_bahamut: xor a
            ld [an_64], a
            ld [an_65], a
            ld a, [an_e6]
            and $FE
            sub $70
            jr nc, .x
            cpl
            inc a
            ld hl, an_64
            dec [hl]
.x:         ld [an_62], a
            ld a, [an_e7]
            and $FE
            sub $70
            jr nc, .y
            cpl
            inc a
            ld hl, an_65
            dec [hl]
.y:         ld [an_63], a
            xor a
            ld [an_61], a
.f:         ld a, [GS + $0F]
            call an_begin
            call .step
            ld a, [an_e6]
            ld [an_x], a
            ld a, [an_e7]
            ld [an_y], a
            call an_bah
            ld a, [an_e6]
            cp $70
            jr nz, .f
            ld a, [an_e7]
            cp $70
            jr nz, .f
            ld hl, GS + $2F
            set 6, [hl]
            ret
.step:      ld a, [an_62]                   ; 3B/A2C0
            ld b, a
            ld a, [an_63]
            cp b
            jr z, .sx
            jr nc, .sy
.sx:        call .mx                        ; x the longer: x, and y on the error's overflow
            ld a, [an_63]
            ld b, a
            ld a, [an_61]
            add a, b
            ld b, a
            ld a, [an_62]
            ld c, a
            ld a, b
            cp c
            jr c, .s1
            sub c
            ld [an_61], a
            jr .my
.sy:        call .my
            ld a, [an_62]
            ld b, a
            ld a, [an_61]
            add a, b
            ld b, a
            ld a, [an_63]
            ld c, a
            ld a, b
            cp c
            jr c, .s1
            sub c
            ld [an_61], a
            jr .mx
.s1:        ld [an_61], a
            ret
.mx:        ld a, [an_e6]
            and $FE
            cp $70
            ret z
            ld b, a
            ld a, [an_64]
            and a
            ld a, b
            jr z, .mx1
            add a, 4
.mx1:       sub 2
            ld [an_e6], a
            ret
.my:        ld a, [an_e7]
            and $FE
            cp $70
            ret z
            ld b, a
            ld a, [an_65]
            and a
            ld a, b
            jr z, .my1
            add a, 4
.my1:       sub 2
            ld [an_e7], a
            ret
; 3C/88DB Bahamut at (an_x, an_y): list 3C/8619 or 865A (frames & $10), its shadow 24 below
; every other frame (3C/8608)
an_bah:     ld a, [fcnt]
            and $10
            ld hl, $8619
            jr z, .l
            ld hl, $865A
.l:         ld a, [an_x]
            push af
            ld a, [an_y]
            push af
            call an_list
            pop af
            add a, $18
            ld [an_y], a
            pop af
            ld [an_x], a
            ld a, [fcnt]
            rra
            ret nc
            ld hl, $8608
            jp an_list

; A (3B/A31F): Bahamut circling in: radius $FF down to $60 (angle +2), then a quarter turn and
; more (angle +4) until the angle is $x200 and its low byte 0
an_circa:   ld a, $B0
            ld [an_a], a
            ld a, 1
            ld [an_a + 1], a
            ld a, $FF
            ld [an_r], a
.f:         ld a, [GS + $0F]
            call an_begin
            call an_bpos
            ld hl, an_a
            ld a, [hl]
            add a, 2
            ld [hl+], a
            jr nc, .f1
            inc [hl]
.f1:        ld hl, an_r
            dec [hl]
            ld a, [hl]
            cp $60
            jr nc, .f
.g:         ld a, [GS + $0F]
            call an_begin
            call an_bpos
            ld hl, an_a
            ld a, [hl]
            add a, 4
            ld [hl+], a
            jr nc, .g1
            inc [hl]
.g1:        ld a, [an_a + 1]
            and 3
            cp 2
            jr nz, .g
            ld a, [an_a]
            and a
            jr nz, .g
            ret
an_bpos:    call an_proj                    ; 3B/A3D6
            ld a, [an_x]
            sub 12
            ld [an_x], a
            ld a, [an_y]
            sub 12
            ld [an_y], a
            jp an_bah
; B (3B/A377): Bahamut circling in (radius - 3, angle + 1) to $30, then out (radius + 2, angle +
; 2) to $F8 with the party carried (3B/A96A: the party's sprite above it)
an_circb:   ld a, $50
            ld [an_a], a
            ld a, 1
            ld [an_a + 1], a
            ld a, $FF
            ld [an_r], a
.f:         xor a
            call an_begin
            call an_bpos
            ld hl, an_a
            inc [hl]
            jr nz, .f1
            inc hl
            inc [hl]
.f1:        ld a, [an_r]
            sub 3
            ld [an_r], a
            cp $30
            jr nc, .f
.g:         ld a, 1                         ; (the party not drawn: carried)
            call an_begin
            xor a
            ld hl, oam_buf
            ld [hl], a
            ld [oam_buf + 4], a
            ld [oam_buf + 8], a
            ld [oam_buf + 12], a
            call an_bpos
            ld a, [an_x]                    ; 3B/A96A the party on its back
            sub 4
            ld [an_x], a
            ld a, [an_y]
            sub 10
            ld [an_y], a
            ld a, [fcnt]
            rrca
            jr nc, .g0
            ld a, [an_x]
            sub $10
            ld [an_x], a
.g0:        xor a
            ld [an_t], a
            ld a, [fcnt]
            and 8
            add a, low($A9AA + N3A)
            ld l, a
            ld a, high($A9AA + N3A)
            adc a, 0
            ld h, a
            call an_obj
            ld hl, an_a
            ld a, [hl]
            add a, 2
            ld [hl+], a
            jr nc, .g1
            inc [hl]
.g1:        ld a, [an_r]
            add a, 2
            ld [an_r], a
            cp $F8
            jr c, .g
            ret

; D (3B/A1F7): eight stars (the first person's sprite) circling in: radius $EA - 2 a frame to
; $0C, the angle + 4, $80 apart
an_stars:   xor a
            ld [an_a], a
            ld [an_a + 1], a
            ld a, $EA
            ld [an_r], a
.f:         xor a
            call an_begin
            ld a, [an_a]
            push af
            ld a, [an_a + 1]
            push af
            ld b, 8
.s:         push bc
            call an_proj
            ld a, [an_x]
            sub 4
            ld b, a
            ld a, [an_y]
            sub 4
            ld c, a
            call an_npc0
            ld hl, an_a
            ld a, [hl]
            add a, $80
            ld [hl+], a
            jr nc, .s1
            inc [hl]
.s1:        pop bc
            dec b
            jr nz, .s
            pop af
            ld [an_a + 1], a
            pop af
            ld [an_a], a
            ld hl, an_a
            ld a, [hl]
            add a, 4
            ld [hl+], a
            jr nc, .f1
            inc [hl]
.f1:        ld a, [an_r]
            sub 2
            ld [an_r], a
            cp $0C
            jr nc, .f
            ret
; the first person's 2 x 2 sprite (its tiles $20-, its current frame) at FF3 (B, C)
an_npc0:    ld a, [N_OB2 + 5]               ; frame data N_ANIM + palette offset + animation
            ld e, a
            ld a, [N_OBJ + $0E]
            add a, e
            ld l, a
            ld h, high(N_ANIM)
            ld a, b
            ld [an_x], a
            ld a, c
            ld [an_y], a
            ld de, an_lt                    ; (the frame copied: N_ANIM is in WRAM bank 1)
            push de
            ld bc, 8
            call memcpy
            pop hl
            ld a, $20
            ld [an_t], a
            jp an_objg
; an_obj for a frame already in GB attributes (N_ANIM): converted back to FF3's
an_objg:    ld b, 4
            push hl
.c:         inc hl
            ld a, [hl]
            ld e, a
            and 3                           ; GB palette -> FF3: bits 0-1; flips 5/6 -> 6/7; 7 -> 5
            bit 5, e
            jr z, .h
            or $40
.h:         bit 6, e
            jr z, .v
            or $80
.v:         bit 7, e
            jr z, .p
            or $20
.p:         ld [hl+], a
            dec b
            jr nz, .c
            pop hl
            jp an_obj

; 2 / 3 (3B/A609, A631) then 3B/A5BE
; 2: six lights circling in (radius $FF - 1 a frame to $0C; 3B/AB61 / AB65 by the frame)
an_six:     ld a, $FF
            ld [an_r], a
            xor a
            ld [an_bc], a
.f:         ld a, [GS + $0F]
            call an_begin
            call an_inv
            ld a, $60                       ; 3B/AB1B
            ld [an_a], a
            ld a, 1
            ld [an_a + 1], a
            ld b, 6
.s:         push bc
            call an_proj
            ld a, [an_bc]
            rrca
            rrca
            and 3
            ld e, a
            ld d, 0
            ld hl, $AB65 + N3A
            add hl, de
            ld a, [hl]
            ld d, a
            ld hl, $AB61 + N3A
            ld a, [an_bc]
            rrca
            rrca
            and 3
            add a, l
            ld l, a
            ld e, [hl]
            ld a, [an_x]
            ld b, a
            ld a, [an_y]
            ld c, a
            call an_put
            ld hl, an_a
            ld a, [hl]
            add a, $40
            ld [hl+], a
            jr nc, .s1
            inc [hl]
.s1:        pop bc
            dec b
            jr nz, .s
            ld hl, an_bc
            inc [hl]
            ld hl, an_r
            dec [hl]
            ld a, [hl]
            cp $0C
            jr nc, .f
            jp an_5be
; 3: sixteen lights (tile $83) circling in: radius $EA - 2 a frame to $0C, the angle + 4
an_sixteen: xor a
            ld [an_62], a
            ld [an_63], a
            ld a, $EA
            ld [an_r], a
.f:         ld a, [GS + $0F]
            call an_begin
            call an_inv
            ld a, [an_62]                   ; 3B/AADE
            ld [an_a], a
            ld a, [an_63]
            ld [an_a + 1], a
            ld b, 16
.s:         push bc
            call an_proj
            ld a, [an_x]
            ld b, a
            ld a, [an_y]
            ld c, a
            ld de, $8302
            call an_put
            ld hl, an_a
            ld a, [hl]
            add a, $40
            ld [hl+], a
            jr nc, .s1
            inc [hl]
.s1:        pop bc
            dec b
            jr nz, .s
            ld hl, an_62
            ld a, [hl]
            add a, 4
            ld [hl+], a
            jr nc, .s2
            inc [hl]
.s2:        ld a, [an_r]
            sub 2
            ld [an_r], a
            cp $0C
            jr nc, .f
; 3B/A5BE: 128 frames, every other 8 the party's light (3B/A5F9)
an_5be:     xor a
            ld [an_bc], a
            ld hl, GS + $2F
            set 6, [hl]
.f:         ld a, [GS + $0F]
            call an_begin
            call an_inv
            ld a, [an_bc]
            and 8
            jr nz, .n
            ld hl, $A5F9 + N3A
            ld b, 4
.l:         push bc
            ld a, [hl+]
            ld c, a
            ld a, [hl+]
            ld d, a
            ld a, [hl+]
            ld e, a
            ld a, [hl+]
            ld b, a
            push hl
            call an_put
            pop hl
            pop bc
            dec b
            jr nz, .l
.n:         ld hl, an_bc
            inc [hl]
            bit 7, [hl]
            jr z, .f
            ret

; ---- the world map's objects each frame (3E/D85A), after the parked vehicles: worlds 0-1 the
; Leviathan's shadow, the boulder / whirlpool / Hein's castle, Bahamut circling; worlds 2-3 the
; floating continent overhead; and the chocobo running off
w_objs:     ld a, 32                        ; (from slot 8 on: the free slots)
            ld [an_p], a
            call w_choco
            ld a, [cur_world]
            srl a
            jr nz, .surf
            call w_lev
            call w_misc
            jp w_bah
.surf:      cp 1
            ret nz
            jp w_float

; FF3 tile (B, C) -> screen (B, C) as 3E/DBE4 (the view's 16 x 16 tiles, the step offset); carry:
; not on screen
w_pos:      ld a, [mdx]                     ; the party's step: view = (party - 7) x 16 + mdx mcount
            ld d, a
            ld a, [mcount]
            ld e, a
            ld a, [px]
            sub 7
            ld h, a
            ld a, b
            sub h
            cp 16
            ccf
            ret c
            swap a
            ld b, a
            ld a, d
            call .off
            ld a, b
            sub l
            ret c                           ; (left of the screen)
            cp $F8
            ccf
            ret c
            ld b, a
            ld a, [mdy]
            ld d, a
            ld a, [py]
            sub 7
            ld h, a
            ld a, c
            sub h
            cp 16
            ccf
            ret c
            swap a
            ld c, a
            ld a, d
            call .off
            ld a, c
            sub l
            cp $EC
            ccf
            ret c
            ld c, a
            and a
            ret
.off:       ld l, 0                         ; L = the sub-tile offset (signed step x mcount)
            and a
            ret z
            ld l, e
            bit 7, a
            ret z
            ld a, l
            cpl
            inc a
            ld l, a
            ret

; 3E/DAA3 the chocobo running off: x + 2 a frame to $F8, y wavering by 128 frames
w_choco:    ld a, [ch_b0]
            bit 7, a
            ret z
            ld a, [ch_b1]
            add a, 2
            ld [ch_b1], a
            cp $F8
            jr c, .r
            xor a
            ld [ch_b0], a
            ret
.r:         ld [an_x], a
            and 8
            ld e, a
            ld a, [fcnt]
            bit 7, a
            ld a, 1
            jr nz, .u
            ld a, -1
.u:         ld hl, ch_b2
            add a, [hl]
            ld [hl], a
            ld [an_y], a
            ld a, $38
            ld [an_t], a
            ld d, 0
            ld hl, DCAA
            add hl, de
            jp an_obj

; 3C/8908 the Leviathan's shadow (world 0-1, $6020 bit 1): to and fro ($B3: 0-$BF, a step every
; other frame) around tile ($20 + d / 16, $35)
w_lev:      ld a, [GS + $20]
            bit 1, a
            ret z
            ld a, [fcnt]
            rrca
            ld a, [lev_b3]
            adc a, 0
            cp $C0
            jr c, .s
            xor a
.s:         ld [lev_b3], a
            cp $60
            jr c, .d
            sub $60
            ld b, a
            ld a, $60
            sub b
.d:         ld [an_lt], a                   ; (d)
            swap a
            and $0F
            add a, $20
            ld b, a
            ld c, $35
            call w_pos
            ret c
            ld a, [an_lt]
            and $0F
            add a, b
            ret c
            ld [an_x], a
            ld a, c
            ld [an_y], a
            ld a, [lev_b3]
            ld b, a
            srl a
            srl a
            srl a
            srl a                           ; (bit 3 of B3 -> carry)
            ld a, 0
            jr c, .l
            ld a, $21
.l:         ld c, a
            ld a, b
            cp $60
            ld a, c
            jr c, .l1
            add a, $42
.l1:        add a, $1D
            ld l, a
            ld h, $87
            jp an_list

; 3E/D537 the floating continent's things: the boulder at (81, 54) ($6020 bit 0, tiles $90),
; else the whirlpool at (67, 32) (bit 2, tiles $B0 | frame), else Hein's castle (bit 3; object
; command 0: around (45, 86), 3C/88C2)
w_misc:     ld a, [GS + $20]
            bit 0, a
            jr z, .wh
            ld bc, $5136
            call w_pos
            ret c
            ld a, $90
            jr .obj
.wh:        bit 2, a
            jr z, .hc
            ld bc, $4320
            call w_pos
            ret c
            ld a, [fcnt]
            rrca
            and $0C
            or $B0
.obj:       ld [an_t], a                    ; 3E/D603: a 2 x 2 sprite of tiles A + (0, 1, 2, 3)
            ld a, b
            ld [an_x], a
            ld a, c
            ld [an_y], a
            ld hl, .sq
            jp an_obj
.sq:        db 0, 3, 1, 3, 2, 3, 3, 3
.hc:        bit 3, a
            ret z
            ld a, 1                         ; object command 0: speed 1, radius $40
            ld b, $40
            call w_orbit
            ld a, [an_lx]
            add a, $2D
            ld b, a
            ld a, [an_ly]
            add a, $56
            ld c, a
            call w_pos
            ret c
            ld a, [an_lx + 1]
            add a, b
            ret c
            ld [an_x], a
            ld a, [an_ly + 1]
            add a, c
            ret c
            ld [an_y], a
            ld a, [fcnt]                    ; 3C/88C2: list 3C/865A / 869B
            and 8
            ld a, $5A
            jr z, .h
            ld a, $9B
.h:         ld l, a
            ld h, $86
            jp an_list
; 3B/A4C3 an orbit: angle - A, radius B -> (tile, sub) in an_lx / an_lx + 1, an_ly / an_ly + 1
w_orbit:    ld c, a
            ld a, b
            ld [an_r], a
            ld hl, hc_bd
            ld a, [hl]
            sub c
            ld [hl+], a
            ld [an_a], a
            ld a, [hl]
            sbc a, 0
            ld [hl], a
            ld [an_a + 1], a
            call an_proj
            ld a, [an_x]
            sub $54
            ld b, a
            and $0F
            ld [an_lx + 1], a
            ld a, b
            swap a
            and $0F
            ld [an_lx], a
            ld a, [an_y]
            sub $54
            ld b, a
            and $0F
            ld [an_ly + 1], a
            ld a, b
            swap a
            and $0F
            ld [an_ly], a
            ret
; 3E/D5A3 Bahamut circling ($602F bit 1; object command 2: speed 2, radius $30), its place kept
; for the attack (an_e6 / an_e7)
w_bah:      ld a, [GS + $2F]
            bit 1, a
            ret z
            ld a, 2
            ld b, $30
            call w_orbit
            ld a, [an_lx]
            add a, $2D
            ld b, a
            ld a, [an_ly]
            add a, $56
            ld c, a
            call w_pos
            ret c
            ld a, [an_lx + 1]
            add a, b
            ret c
            ld [an_x], a
            ld [an_e6], a
            ld a, [an_ly + 1]
            add a, c
            ret c
            ld [an_y], a
            ld [an_e7], a
            jp an_bah
; 3C/8887 the floating continent overhead (worlds 2-3): tile (32, 223), list 3C/86DC, its
; shadow; not while aboard the Invincible
w_float:    ld bc, $20DF
            call w_pos
            ret c
            ld a, b
            ld [an_x], a
            ld a, c
            ld [an_y], a
            ld hl, $86DC
            ld a, [an_x]
            push af
            ld a, [an_y]
            push af
            call an_list
            pop af
            add a, $18
            ld [an_y], a
            pop af
            ld [an_x], a
            ld a, [fcnt]
            rra
            ret nc
            ld hl, $8608
            jp an_list

section wram, $CC18
ch_b0:      ds 1                ; FF3 $B0-$B2 the chocobo running off
ch_b1:      ds 1
ch_b2:      ds 1
lev_b3:     ds 1                ; $B3 the Leviathan's shadow
hc_bd:      ds 2                ; $BD / $BE the orbit's angle
an_e6:      ds 1                ; $E6 / $E7 Bahamut's place
an_e7:      ds 1
section wram, $DE00             ; (WRAM bank 1: free above the map's tables)
an_p:       ds 1
an_x:       ds 1
an_y:       ds 1
an_t:       ds 1
an_r:       ds 1
an_a:       ds 2
an_sp:      ds 1
an_bc:      ds 1
an_61:      ds 1
an_62:      ds 1
an_63:      ds 1
an_64:      ds 1
an_65:      ds 1
an_lx:      ds 2
an_ly:      ds 2
an_lt:      ds 8
an_la:      ds 1
an_ab0:     ds 1
an_ab:      ds 32
