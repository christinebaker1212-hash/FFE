; FF2 native routines outside bank 0 (appended after native.s: section bank HLE_BANK),
; reached through bank-0 stubs (rt/ff2.s, rt_fcs). Keep C (Y).
; fix:FC79 multiply: +$02 <- A * X (FF2's shift-and-add, step for step: $00 = A, $01
; rotated, A / C / X as the NES leaves them). Keeps C (Y).
hle_mul8_b:   ld [NES_RAM + $00], a
            ld b, a                         ; $00
            ld h, e                         ; $01
            ld e, 8
            ld l, 0                         ; $02
            ld d, 0                         ; $03
            ld a, 0                         ; (LDA #$00: carry kept)
.lp:        rr h                            ; ROR $01
            jr nc, .n
            ld a, b                         ; CLC / LDA $00 / ADC $03 / STA $03
            add a, d
            ld d, a
.n:         rr d                            ; ROR $03
            rr l                            ; ROR $02
            dec e                           ; DEX (carry kept)
            jr nz, .lp
            push af
            ld a, h
            ld [NES_RAM + $01], a
            ld a, l
            ld [NES_RAM + $02], a
            ld a, d
            ld [NES_RAM + $03], a
            xor a
            ldh [nzv], a
            ld b, 0
            ld d, 0
            pop af                          ; A, Z = 1, C from the last ROR
            ret

; fix:FC98 multiply (16-bit): +++$04 <- +$00 * +$02 (step for step, in NES RAM)
hle_mul16_b:  ld hl, NES_RAM + $04
            ld a, 0
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl], a
            ld e, 16
.lp:        ld hl, NES_RAM + $03
            rr [hl]                         ; ROR $03
            dec l
            rr [hl]                         ; ROR $02
            jr nc, .n
            ld a, [NES_RAM + $00]           ; CLC / $06 += $00 / $07 += $01 + carry
            ld hl, NES_RAM + $06
            add a, [hl]
            ld [hl+], a
            ld a, [NES_RAM + $01]
            adc a, [hl]
            ld [hl], a
.n:         ld hl, NES_RAM + $07
            rr [hl]                         ; ROR $07 / $06 / $05 / $04
            dec l
            rr [hl]
            dec l
            rr [hl]
            dec l
            rr [hl]
            dec e
            jr nz, .lp
            push af
            xor a
            ldh [nzv], a
            pop af                          ; A, Z = 1, C from the last ROR
            ret

; fix:FCC3 divide (16-bit): +$04 = +$00 / +$02, +$06 = remainder (step for step; a zero
; +$00 or +$02 returns at once with A = 0, Z = 1, X and C unchanged)
hle_div16_b:  push af                         ; caller's carry
            ld hl, NES_RAM + $04
            ld a, 0
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl], a
            ld a, [NES_RAM + $00]
            ld hl, NES_RAM + $01
            or [hl]
            jr z, .zero
            ld a, [NES_RAM + $02]
            inc l
            inc l                           ; $03
            or [hl]
            jr z, .zero
            pop af                          ; the carry into the first ROL $00
            ld e, 16
.lp:        ld hl, NES_RAM + $00
            rl [hl]                         ; ROL $00 / $01 / $06 / $07
            inc l
            rl [hl]
            ld hl, NES_RAM + $06
            rl [hl]
            inc l
            rl [hl]
            ld a, [NES_RAM + $06]           ; SEC / $06 -= $02 / $07 -= $03
            ld hl, NES_RAM + $02
            sub [hl]
            ld d, a
            ld a, [NES_RAM + $07]
            inc l
            sbc a, [hl]
            jr c, .neg                      ; borrow: the NES adds it back (no change), CLC
            ld [NES_RAM + $07], a           ; no borrow: stored, NES carry set
            ld hl, NES_RAM + $06
            ld [hl], d
            scf
            jr .rol
.neg:       ld a, [NES_RAM + $07]           ; (A = $07 as the NES leaves it)
            scf
            ccf
.rol:       ld hl, NES_RAM + $04
            rl [hl]                         ; ROL $04 / $05
            inc l
            rl [hl]
            dec e
            jr nz, .lp
            push af
            xor a
            ldh [nzv], a
            ld d, 0
            pop af                          ; A = $07, Z = 1, C from ROL $05
            ret
.zero:      xor a
            ldh [nzv], a
            pop af                          ; caller's carry
            ld a, 1
            dec a                           ; A = 0, Z = 1 (carry kept)
            ret

