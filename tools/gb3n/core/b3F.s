; FF3 bank $3F (the fixed bank) translated routine by routine (docs/ff3-gb-rewrite.md). Each fBB_AAAA
; does what FF3's routine at BB/AAAA does to RAM, A, X (E), Y (C) and the carry.

section bank 0, $1000
; ---- 3F/FC92 divide (16-bit): +$1C = +$18 / +$1A, +$1E = the remainder (X ends 0)
f3F_FC92:   push af                         ; (the caller's carry: the first ROL takes it)
            xor a
            ld [BZ + $1D], a
            ld [BZ + $1C], a
            ld [BZ + $1F], a
            ld [BZ + $1E], a
            ld a, [BZ + $18]
            ld hl, BZ + $19
            or [hl]
            jr z, .x
            ld a, [BZ + $1A]
            ld hl, BZ + $1B
            or [hl]
            jr z, .x
            ld e, $10
            pop af
.l:         ld hl, BZ + $18                 ; ROL $18, $19, $1E, $1F (the carry in: the last bit)
            rl [hl]
            inc l
            rl [hl]
            ld l, low(BZ + $1E)
            rl [hl]
            inc l
            rl [hl]
            ld a, [BZ + $1E]                ; $1E/$1F -= $1A/$1B
            ld hl, BZ + $1A
            sub [hl]
            ld [BZ + $1E], a
            ld a, [BZ + $1F]
            inc l
            sbc [hl]
            ld [BZ + $1F], a
            jr nc, .ok                      ; (no borrow: the 6502's carry set)
            ld a, [BZ + $1E]                ; borrow: add it back, carry clear
            ld hl, BZ + $1A
            add [hl]
            ld [BZ + $1E], a
            ld a, [BZ + $1F]
            inc l
            adc [hl]
            ld [BZ + $1F], a
            and a                           ; (CLC)
            jr .q
.ok:        scf
.q:         ld hl, BZ + $1C                 ; ROL $1C, $1D
            rl [hl]
            inc l
            rl [hl]
            dec e
            jr nz, .l
            ret
.x:         pop af                          ; (a zero operand: A = 0, the carry as it came)
            ld a, 0
            ret

; ---- 3F/FCD6 multiply: +$1A = A x X (X ends 0; $18 = A, $19 = X shifted out)
f3F_FCD6:   ld [BZ + $18], a
            ld a, e
            ld [BZ + $19], a
            ld e, 8
            ld a, 0                         ; (LDA #0: the carry stays, the first ROR takes it)
            ld [BZ + $1B], a
            ld [BZ + $1A], a
.l:         ld hl, BZ + $19
            rr [hl]
            jr nc, .n
            ld a, [BZ + $18]
            ld hl, BZ + $1B
            add [hl]
            ld [hl], a
.n:         ld hl, BZ + $1B                 ; ROR $1B, $1A (the carry from the add)
            rr [hl]
            dec l
            rr [hl]
            dec e
            jr nz, .l
            ret

; ---- 3F/FCF5 multiply (16-bit): +++$1C = +$18 x +$1A (X ends 0)
f3F_FCF5:   ld e, $10
            ld a, 0                         ; (the carry stays: the first ROR takes it)
            ld [BZ + $1D], a
            ld [BZ + $1C], a
            ld [BZ + $1F], a
            ld [BZ + $1E], a
.l:         ld hl, BZ + $1B                 ; ROR $1B, $1A
            rr [hl]
            dec l
            rr [hl]
            jr nc, .n
            ld a, [BZ + $18]
            ld hl, BZ + $1E
            add [hl]
            ld [hl+], a
            ld a, [BZ + $19]
            adc [hl]
            ld [hl], a
.n:         ld hl, BZ + $1F                 ; ROR $1F, $1E, $1D, $1C
            rr [hl]
            dec l
            rr [hl]
            dec l
            rr [hl]
            dec l
            rr [hl]
            dec e
            jr nz, .l
            ret

; ---- 3F/FD20 set bit: A |= the mask of bit X (bit 0 = $80); FD2C clear; FD38 check. As the 6502:
; Z from the result, the carry untouched (masks on page boundaries: no flag-changing address sums)
f3F_FD20:   ld h, high(f3F_bits)
            ld l, e
            jr c, .c
            or [hl]
            ret
.c:         or [hl]
            scf
            ret
f3F_FD2C:   ld h, high(f3F_ibits)
            ld l, e
            jr c, .c
            and [hl]
            ret
.c:         and [hl]
            scf
            ret
f3F_FD38:   ld h, high(f3F_bits)
            ld l, e
            jr c, .c
            and [hl]
            ret
.c:         and [hl]
            scf
            ret
section bank 0, $1F00
f3F_bits:   db $80, $40, $20, $10, $08, $04, $02, $01
section bank 0, $1E00
f3F_ibits:  db $7F, $BF, $DF, $EF, $F7, $FB, $FD, $FE
section bank 0, $1200

; ---- 3F/FD3C asl (x 64 as six ASLs: the carry is bit 2 of A); 3F/FD43 lsr
f3F_FD3C:   sla a
            sla a
            sla a
            sla a
            sla a
            sla a
            ret
f3F_FD43:   srl a
            srl a
            srl a
            srl a
            srl a
            srl a
            ret

; ---- 3F/FBEF random (X..A): A = X + (A - X + 1) x rng / 256 rounded; $1A selects the counter ($21)
f3F_FBEF:   ld b, a
            ld a, e
            ld [BZ + $20], a
            cp $FF                          ; X = $FF: A = $FF (CPX: the carry set)
            jr nz, .a
            scf
            ret
.a:         ld a, b
            and a                           ; A = 0 or A = X: A, the carry set (CMP equal)
            jr z, .eq
            ld hl, BZ + $20
            cp [hl]
            jr z, .eq
            sub [hl]                        ; (SEC: SBC)
            ld [BZ + $18], a
            ld a, $80
            ld [BZ + $1A], a
            add a                           ; ASL: A = 0, the carry set
            ld [BZ + $19], a
            ld a, [BZ + $21]                ; the counter $15 + [$21]
            add low(BZ + $15)
            ld l, a
            ld h, high(BZ)
            ld a, [hl]
            inc [hl]
            ld l, a                         ; the table $7BE3 + counter
            ld h, 0
            ld de, $7BE3 - $7400 + $D400
            add hl, de
            ld a, [hl]
            ld [BZ + $1B], a
            scf                             ; (the ASL's carry, kept on the 6502 through here)
            call f3F_FCF5
            ld a, [BZ + $1E]
            ld e, a
            ld a, [BZ + $1D]
            bit 7, a
            jr z, .r
            inc e
.r:         ld a, e
            ld hl, BZ + $20
            add [hl]                        ; (CLC: ADC)
            ret
.eq:        scf
            ret

; ==== the field: tiles and people (3F/E3F1-E54B). NES $7000 people table -> $C000, the map
; $7400-$77FF -> $D400, the tile properties $0400 / $0500 -> $C800 / $C900.
section bank 0, $1400
; ---- 3F/E4E9 get tile in facing direction: A = direction bits (r l d u) -> X, Y offsets, $84 / $85
; = the party's position + offset (mod 64); A = $85, the carry from the last ADC
f3F_E4E9:   srl a
            jr c, .r
            srl a
            jr c, .l
            srl a
            jr c, .d
            ld e, 7                         ; up
            ld c, 6
            jr .go
.d:         ld e, 7
            ld c, 8
            jr .go
.r:         ld e, 8
            ld c, 7
            jr .go
.l:         ld e, 6
            ld c, 7
.go:        ld a, [BZ + $29]
            add e
            and $3F
            ld [BZ + $84], a
            ld a, [BZ + $2A]
            add c
            push af
            and $3F
            ld [BZ + $85], a
            ld b, a
            pop af                          ; (the ADC's carry; AND keeps it on the 6502)
            ld a, b
            ret

; ---- 3F/E51C get tile properties: Y = the tile at ($84, $85) (outside 0-31: the fill tile $4C;
; $80 / $81 = its NES address in $7400-$77FF), $44 / $45 = its properties bytes; A = $45
f3F_E51C:   push af                         ; (the caller's flags: the off-map path keeps them)
            ld a, [BZ + $4C]
            ld c, a
            ld a, [BZ + $84]
            ld hl, BZ + $85
            or [hl]
            and $20
            jr nz, .p
            pop af
            ld a, [BZ + $85]
            and $1F
            srl a
            srl a
            srl a
            or $74
            ld [BZ + $81], a
            ld a, [BZ + $85]
            sla a
            sla a
            sla a
            sla a
            sla a
            push af                         ; (the last ASL's carry: ORA keeps it on the 6502)
            ld hl, BZ + $84
            or [hl]
            ld [BZ + $80], a
            ld l, a
            ld a, [BZ + $81]
            add $D4 - $74
            ld h, a
            ld c, [hl]
.p:         ld b, 0                         ; (the flags to return with are on the stack)
            ld hl, $C800
            add hl, bc
            ld a, [hl]
            ld [BZ + $44], a
            inc h
            ld a, [hl]
            ld [BZ + $45], a
            ld b, a
            pop af
            ld a, b
            ret

; ---- 3F/E3F1 check if player is touching an npc ($84, $85): the carry set when one blocks
; (its $700B & 3, $700D = 1); else the carry clear (a person behind a counter: $700D = 1)
f3F_E3F1:   ld e, 0
.a:         ld d, high($C000)
            ld a, e
            add 6
            ld l, a
            ld h, high($C100)               ; ($7106 + X)
            ld a, [hl]
            and a
            jr z, .a1
            ld a, [BZ + $A5]
            and a
            jr z, .a1
            cp [hl]
            jr nz, .an
.a1:        ld l, e
            ld h, d
            ld a, [hl]                      ; $7000
            and a
            jr z, .an
            inc l
            inc l
            ld a, [BZ + $84]
            cp [hl]                         ; $7002
            jr nz, .an
            inc l
            ld a, [BZ + $85]
            cp [hl]
            jr nz, .an
            ld a, e
            add $0B
            ld l, a
            ld a, [hl]
            and 3
            ld [hl+], a
            inc l
            ld a, 1
            ld [hl], a                      ; $700D
            scf
            ret
.an:        ld a, e
            add $10
            ld e, a
            cp $C0
            jr c, .a
            ld e, 0                         ; (the carry clear here: CMP #$C0 with $C0)
.b:         ld h, high($C000)
            ld a, [BZ + $A5]
            and a
            jr z, .b1
            ld a, e
            add 6
            ld l, a
            ld h, high($C100)
            ld a, [hl]
            and a
            jr z, .b0
            ld b, a
            ld a, [BZ + $A5]
            cp b
            jr nz, .bn
.b0:        ld h, high($C000)
.b1:        ld l, e
            ld a, [hl]
            and a
            jr z, .bn
            ld a, e
            add 8
            ld l, a
            bit 7, [hl]                     ; $7008: BMI
            jr nz, .x1
            inc l
            bit 7, [hl]                     ; $7009: BPL
            jr z, .x0
            ld a, e                         ; x == $84 and y + 1 == $85
            add 4
            ld l, a
            ld a, [BZ + $84]
            cp [hl]
            jr nz, .bn
            inc l
            ld a, [hl]
            inc a
            and $3F
            ld b, a
            ld a, [BZ + $85]
            cp b
            jr nz, .bn
            jr .hit
.x1:        ld a, e                         ; x + 1 == $84 and y == $85
            add 4
            ld l, a
            ld a, [hl]
            inc a
            and $3F
            ld b, a
            ld a, [BZ + $84]
            cp b
            jr nz, .bn
            inc l
            ld a, [BZ + $85]
            cp [hl]
            jr nz, .bn
            jr .hit
.x0:        ld a, e                         ; x == $84 and y == $85
            add 4
            ld l, a
            ld a, [BZ + $84]
            cp [hl]
            jr nz, .bn
            inc l
            ld a, [BZ + $85]
            cp [hl]
            jr nz, .bn
.hit:       ld a, e
            add $0D
            ld l, a
            ld a, 1
            ld [hl], a
            and a                           ; (CLC)
            ret
.bn:        ld a, e
            add $10
            ld e, a
            cp $C0
            jr c, .b
            and a                           ; (CLC: A = $C0)
            ret

; ---- 3F/E494 check npcs ($84, $85): the carry set when a person is there (one not moving by
; script: $700D |= $80, they face the party); X = its slot
f3F_E494:   ld e, 0
.l:         ld a, e
            add 6
            ld l, a
            ld h, high($C100)
            ld a, [hl]
            and a
            jr z, .z
            cp 3
            jr z, .z
            ld a, [BZ + $A5]
            and a
            jr z, .z
            cp [hl]
            jr nz, .n
.z:         ld h, high($C000)
            ld l, e
            ld a, [hl]
            and a
            jr z, .n
            ld a, e                         ; x + ($7006 >= 8) == $84
            add 4
            ld b, a
            ld a, e
            add 6
            ld l, a
            ld a, [hl]
            cp 8                            ; (the 6502's carry: >= 8)
            ccf
            ld l, b
            ld a, [hl]
            adc 0
            and $3F
            ld b, a
            ld a, [BZ + $84]
            cp b
            jr nz, .n
            ld a, e                         ; y + ($7007 >= 8) == $85
            add 7
            ld l, a
            ld a, [hl]
            cp 8
            ccf
            dec l                           ; (DEC: the carry kept)
            dec l
            ld a, [hl]
            adc 0
            and $3F
            ld b, a
            ld a, [BZ + $85]
            cp b
            jr nz, .n
            ld a, e
            inc a
            ld l, a
            ld a, [hl]                      ; $7001 & $30
            and $30
            jr nz, .s
            ld a, e
            add $0D
            ld l, a
            ld a, [hl]
            or $80
            ld [hl], a
.s:         scf
            ret
.n:         ld a, e
            add $10
            ld e, a
            cp $C0
            jr c, .l
            and a
            ret
