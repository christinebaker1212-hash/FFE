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
