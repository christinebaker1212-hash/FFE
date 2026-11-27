;  FF3's battle helpers shared by the battle banks (bank 0): the fixed bank's random, multiply,
; divide, bit masks and table loads, pointers, the message queue; and the dispatcher that calls
; the algorithms in B_BAT from other banks (as FF3's $FDF3 "do battle algorithm").

section bank 0, $0450
; ---- random (X..A) ($FBEF): A = top, B = X; uses rng counter [BZ+$21]
b_rndx:     ld c, a
            ld a, b
            ld [BZ + $20], a
            cp $FF
            ret z                           ; (X = $FF: A = $FF)
            ld a, c
            and a
            ret z
            cp b
            ret z
            sub b
            ld [BZ + $18], a                ; d = A - X
            ld e, a
            xor a
            ld [BZ + $19], a
            ld a, $80
            ld [BZ + $1A], a
            ld a, [BZ + $21]                ; t = table[counter++]
            add low(BZ + $15)
            ld l, a
            ld h, high(BZ)
            ld a, [hl]
            inc [hl]
            ld c, a
            ld b, 0
            ld hl, RNG_TAB
            add hl, bc
            ld a, [hl]
            ld [BZ + $1B], a
            push de
            call mul8                       ; HL = d * t
            pop de
            srl e                           ; + d / 2: the product's bytes 1-2 (d * (256 t + 128))
            ld a, l
            add e
            ld l, a
            ld a, h
            adc 0
            ld [BZ + $1E], a
            ld a, l
            ld [BZ + $1D], a
            ld a, [BZ + $1E]
            bit 7, l
            jr z, .r
            inc a
.r:         ld hl, BZ + $20
            add [hl]
            ret
; random (0..A) ($BEB4): counter 1
b_rnd:      ld c, a
            ld a, 1
            ld [BZ + $21], a
            ld a, c
            ld b, 0
            jr b_rndx

; HL = A * E (8 x 8)
mul8:       ld h, a
            ld l, 0
            ld d, l
            ld b, 8
.m:         add hl, hl
            jr nc, .n
            add hl, de
.n:         dec b
            jr nz, .m
            ret

; $FCD6 multiply: [BZ+$1A] (16) = A * X (B)
b_mul:      ld [BZ + $18], a
            ld e, b
            ld a, b
            ld [BZ + $19], a
            ld a, [BZ + $18]
            call mul8
            ld a, l
            ld [BZ + $1A], a
            ld a, h
            ld [BZ + $1B], a
            ret

; $FCF5 multiply (16-bit): [BZ+$1C] (32) = [BZ+$18] (16) * [BZ+$1A] (16)
b_mul16:    ld hl, BZ + $1C
            xor a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl], a
            ld a, [BZ + $1A]
            ld c, a
            ld a, [BZ + $1B]
            ld b, a                         ; BC = multiplier
            ld a, 16
.m:         push af
            ld hl, BZ + $1C                 ; result <<= 1 (from the top bit down)
            sla [hl]
            inc l
            rl [hl]
            inc l
            rl [hl]
            inc l
            rl [hl]
            sla c
            rl b
            jr nc, .n
            ld hl, BZ + $1C                 ; + multiplicand
            ld a, [BZ + $18]
            add [hl]
            ld [hl+], a
            ld a, [BZ + $19]
            adc [hl]
            ld [hl+], a
            ld a, 0
            adc [hl]
            ld [hl+], a
            ld a, 0
            adc [hl]
            ld [hl], a
.n:         pop af
            dec a
            jr nz, .m
            ret

; $FC92 divide (16-bit): [BZ+$1C] = [BZ+$18] / [BZ+$1A], [BZ+$1E] = remainder (0 if either is 0)
b_div16:    xor a
            ld [BZ + $1C], a
            ld [BZ + $1D], a
            ld [BZ + $1E], a
            ld [BZ + $1F], a
            ld a, [BZ + $18]
            ld e, a
            ld a, [BZ + $19]
            ld d, a
            or e
            ret z
            ld a, [BZ + $1A]
            ld c, a
            ld a, [BZ + $1B]
            ld b, a
            or c
            ret z
            ld hl, 0                        ; remainder
            ld a, 16
.d:         push af
            sla e                           ; dividend -> remainder
            rl d
            rl l
            rl h
            ld a, l
            sub c
            ld l, a
            ld a, h
            sbc b
            ld h, a
            jr nc, .q
            add hl, bc
            scf
.q:         ccf                             ; (carry set: the quotient bit is 1)
            ld a, [BZ + $1C]
            rla
            ld [BZ + $1C], a
            ld a, [BZ + $1D]
            rla
            ld [BZ + $1D], a
            pop af
            dec a
            jr nz, .d
            ld a, l
            ld [BZ + $1E], a
            ld a, h
            ld [BZ + $1F], a
            ret

; set / clear / check bit X (B) in A ($FD20 / $FD2C / $FD38: bit 7 first)
b_setbit:   push hl
            ld hl, bit_mask
            jr b_bit
b_clrbit:   push hl
            ld hl, bit_inv
            ld c, a
            ld a, l
            add b
            ld l, a
            ld a, h
            adc 0
            ld h, a
            ld a, c
            and [hl]
            pop hl
            ret
b_chkbit:   push hl
            ld hl, bit_mask
            ld c, a
            ld a, l
            add b
            ld l, a
            ld a, h
            adc 0
            ld h, a
            ld a, c
            and [hl]
            pop hl
            ret
b_bit:      ld c, a
            ld a, l
            add b
            ld l, a
            ld a, h
            adc 0
            ld h, a
            ld a, c
            or [hl]
            pop hl
            ret
bit_mask:   db $80, $40, $20, $10, $08, $04, $02, $01
bit_inv:    db $7F, $BF, $DF, $EF, $F7, $FB, $FD, $FE

; $FDA6 load array item: [BZ+$18] index, [BZ+$1A] size, [BZ+$20] NES address, A = GB bank (the
; NES bank's copy), B = X: the destination offset in B_BUF; returns B = X after the copy
b_ldarr:    push af
            push bc
            xor a
            ld [BZ + $19], a
            ld [BZ + $1B], a
            ld a, [BZ + $1A]
            push af
            call b_mul16
            ld hl, BZ + $1C
            ld a, [BZ + $20]
            add [hl]
            ld [hl+], a
            ld a, [BZ + $21]
            adc [hl]
            ld [hl], a
            pop af
            ld [BZ + $1A], a
            ld c, a                         ; C = size
            pop de                          ; D = X
            pop af                          ; A = bank
            ld b, a
            ld a, [BZ + $1C]
            ld l, a
            ld a, [BZ + $1D]
            sub $40
            ld h, a
            ld e, d
            ld d, high(B_BUF)
.c:         push bc
            ld a, b
            call far_byte
            ld [de], a
            inc de
            inc hl
            pop bc
            dec c
            jr nz, .c
            ld b, e
            ret

; $FDDC load rom data to buffer: [BZ+$46] NES address, [BZ+$4B] size, A = GB bank -> B_BUF
b_ldrom:    ld b, a
            ld a, [BZ + $46]
            ld l, a
            ld a, [BZ + $47]
            sub $40
            ld h, a
            ld de, B_BUF
            ld a, [BZ + $4B]
            ld c, a
.c:         push bc
            ld a, b
            call far_byte
            ld [de], a
            inc de
            inc hl
            pop bc
            dec c
            jr nz, .c
            ret

; ---- small helpers of bank $31
; $BE90 get character offset: [BZ+$5F] = A = [BZ+$52] * $40
b_choff:    ld a, [BZ + $52]
            rrca
            rrca
            and $C0
            ld [BZ + $5F], a
            ret
; $BE98 add character offset: A += [BZ+$5F] (-> Y)
b_addoff:   ld hl, BZ + $5F
            add [hl]
            ret

; $BE9D calculate pointer: [BZ+$1C] = [BZ+$18] * [BZ+$1A] + [BZ+$20]
b_calcp:    xor a
            ld [BZ + $19], a
            ld [BZ + $1B], a
            call b_mul16
            ld hl, BZ + $1C
            ld a, [BZ + $20]
            add [hl]
            ld [hl+], a
            ld a, [BZ + $21]
            adc [hl]
            ld [hl], a
            ret

; HL in FF3's ROM range (an NES pointer past $7FFF, GB $E000+): a dummy (writes there do nothing)
wchk:       ld a, h
            cp $E0
            ret c
            ld hl, W_DUMMY
            ret
W_DUMMY    = $C5A0

; A = the attacker's flags (+$2C) ($A2B5) / the target's ($BC25)
b_aflags:   %LDZ $6E, $2C
            ret
b_tflags:   %LDZ $70, $2C
            ret

; HL = the status buffer entry of the target (BZ+$E0+[$64] + C) / attacker ($F0+[$62] + C)
st_t:       ld a, [BZ + $64]
            add $E0
            jr st_x
st_a:       ld a, [BZ + $62]
            add $F0
st_x:       add c
            ld l, a
            ld h, high(BZ)
            ret

; FF3's carry after its last arithmetic (6502 sense: set = no borrow), kept where it is read later
fe_cyset:   push af
            ld a, 0
            jr nc, .c
            inc a
.c:         ld [fe_cy], a
            pop af
            ret

; the message queue ($78DA + [$78EE]): msg_q adds message A; msg_set sets it without moving on;
; msg_at: HL = the queue entry now
msg_q:      call msg_set
            ld hl, $D8EE
            inc [hl]
            ret
msg_set:    push af
            call msg_at
            pop af
            ld [hl], a
            ret
msg_at:     ld a, [$D8EE]
            add low($D8DA)
            ld l, a
            ld a, high($D8DA)
            adc 0
            ld h, a
            ret

; HL = [$57] / [$59] / [$5B] + C
p57:        ld a, [BZ + $57]
            add c
            ld l, a
            ld a, [BZ + $58]
            adc 0
            ld h, a
            ret
p59:        ld a, [BZ + $59]
            add c
            ld l, a
            ld a, [BZ + $5A]
            adc 0
            ld h, a
            ret
p5b:        ld a, [BZ + $5B]
            add c
            ld l, a
            ld a, [BZ + $5C]
            adc 0
            ld h, a
            ret

; ---- call routine HL in bank A from another bank (A / flags not kept)
far_call:   ld [fc_bank], a
            ldh a, [rombank]
            push af
            ld a, [fc_bank]
            call sbank
            call alg_call.go
            pop af
            jp sbank
; ---- call routine HL in B_BAT from another bank (A / flags not kept)
alg_call:   ldh a, [rombank]
            push af
            ld a, B_BAT
            call sbank
            call .go
            pop af
            jp sbank
.go:        jp hl

section wram, $C502
fc_bank:    ds 1
