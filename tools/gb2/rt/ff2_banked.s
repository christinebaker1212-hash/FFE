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

; fix:FC98 multiply (16-bit): +++$04 <- +$00 * +$02, FF2's steps in registers ($07 B, $06 C,
; $05 D, $04 E, $03 H, $02 L; RORs through the carry as on the NES; A = the last $07 sum)
hle_mul16_b:
            push bc
            push de
            ld a, [NES_RAM + $02]
            ld l, a
            ld a, [NES_RAM + $03]
            ld h, a
            ld bc, 0
            ld de, 0
            ld a, 0
            ldh [tmp_lo], a                 ; (A at exit)
            ld a, 16
            ldh [uw_y], a
.lp:        rr h                            ; ROR $03 / $02
            rr l
            jr nc, .n
            ld a, [NES_RAM + $00]           ; CLC / $06 += $00 / $07 += $01 + carry
            add a, c
            ld c, a
            ld a, [NES_RAM + $01]
            adc a, b
            ld b, a
            ldh [tmp_lo], a
.n:         rr b                            ; ROR $07 / $06 / $05 / $04
            rr c
            rr d
            rr e
            ldh a, [uw_y]                   ; DEX (carry kept)
            dec a
            ldh [uw_y], a
            jr nz, .lp
            ld a, l
            ld [NES_RAM + $02], a
            ld a, h
            ld [NES_RAM + $03], a
            ld a, e
            ld [NES_RAM + $04], a
            ld a, d
            ld [NES_RAM + $05], a
            ld a, c
            ld [NES_RAM + $06], a
            ld a, b
            ld [NES_RAM + $07], a
            ld a, 0
            ldh [nzv], a
            pop de
            pop bc
            ld e, 0                         ; X = 0
            ldh a, [tmp_lo]                 ; A; Z = 1 and C from the last ROR still set
            ret

; fix:FCC3 divide (16-bit): +$04 = +$00 / +$02, +$06 = remainder. FF2's restoring division
; (16-bit remainder register: an overflowing shift loses its top bit) in registers: divisor
; BC, dividend / quotient DE, remainder HL; as the NES leaves them: $00 = 0, $01 = $80 if the
; carry was set on entry (it is rotated in first, then only zeros), A = $07, C = 0. A zero
; +$00 or +$02: A = 0, Z = 1, X and C unchanged. (Checked against a model of the 6502
; routine on 200000 random cases.)
hle_div16_b:
            push af                         ; caller's carry
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
            pop af
            ld a, 0                         ; the final $01: $80 if the entry carry was set
            jr nc, .c0
            ld a, $80
.c0:        ldh [tmp_lo], a
            push bc
            push de
            ld a, [NES_RAM + $02]
            ld c, a
            ld a, [NES_RAM + $03]
            ld b, a
            ld a, [NES_RAM + $00]
            ld e, a
            ld a, [NES_RAM + $01]
            ld d, a
            ld hl, 0
            ld a, 16
            ldh [uw_y], a
.lp:        sla e                           ; dividend bit out, quotient bit 0 in
            rl d
            rl l                            ; into the remainder (its top bit lost)
            rl h
            ld a, l                         ; remainder - divisor
            sub c
            ldh [wtmp], a
            ld a, h
            sbc a, b
            jr c, .no
            ld h, a                         ; fits: subtracted, quotient bit 1
            ldh a, [wtmp]
            ld l, a
            inc e
.no:        ldh a, [uw_y]
            dec a
            ldh [uw_y], a
            jr nz, .lp
            ld a, e
            ld [NES_RAM + $04], a
            ld a, d
            ld [NES_RAM + $05], a
            ld a, l
            ld [NES_RAM + $06], a
            ld a, h
            ld [NES_RAM + $07], a
            xor a
            ld [NES_RAM + $00], a
            ldh [nzv], a
            ldh a, [tmp_lo]
            ld [NES_RAM + $01], a
            pop de
            pop bc
            ld e, 0                         ; X = 0
            ld a, 1
            dec a                           ; Z = 1
            scf
            ccf                             ; C = 0
            ld a, h                         ; A = $07 (flags kept)
            ret
.zero:      xor a
            ldh [nzv], a
            pop af                          ; caller's carry
            ld a, 1
            dec a                           ; A = 0, Z = 1 (carry kept)
            ret

; b11:97D5 init rng: A + carry + the 256 zero-page bytes (ADC chain) -> $42; k = (A & 2) + 3
; -> $0A; 256 entries of x = k * x mod 1024 folded above 512 (x = 1024 - x), table $7A48 + n
; = (x >> 1) & $FF. The NES computes it with the 16-bit multiply / divide; the end state is
; theirs: $00-$02 = 0, $03 = 4, $04 / $05 = the last quotient, $06 / $07 = $08 / $09 = the
; last x, A = the last entry, X = Y = 0, Z = 1, N = 0, C = x bit 0. (Checked against a
; model of the 6502 routine on 300 random zero pages.)
hle_initrng_b:
            push bc
            push de
            ld hl, NES_RAM
            ld b, 0
.sum:       adc a, [hl]                     ; (inc l / dec b keep the carry)
            inc l
            dec b
            jr nz, .sum
            ld [NES_RAM + $42], a
            and 2
            add a, 3
            ld [NES_RAM + $0A], a
            ldh [wtmp], a                   ; k
            ld de, 1                        ; x
            ld hl, $A000 + $7A48 - $6000    ; table (cart RAM bank 0)
            ld c, 0                         ; 256 entries
.lp:        push hl
            ld h, d
            ld l, e
            add hl, hl                      ; 2x
            ldh a, [wtmp]
            cp 3
            jr z, .k3
            add hl, hl                      ; 4x
.k3:        add hl, de                      ; p = k * x (< 5120)
            ld a, h
            srl a
            srl a
            ldh [uw_y], a                   ; q = p >> 10
            ld a, h
            and 3
            ld h, a                         ; x = p & 1023
            cp 2
            jr c, .ok
            jr nz, .fold                    ; >= 768
            ld a, l
            and a
            jr z, .ok                       ; = 512: kept
.fold:      xor a                           ; > 512: 1024 - x
            sub l
            ld l, a
            ld a, 4
            sbc a, h
            ld h, a
.ok:        ld d, h
            ld e, l
            ld a, h                         ; entry = (x >> 1) & $FF
            srl a
            ld a, l
            rra
            pop hl
            ld [hl+], a
            dec c
            jr nz, .lp
            xor a
            ld [NES_RAM + $00], a
            ld [NES_RAM + $01], a
            ld [NES_RAM + $02], a
            ld [NES_RAM + $05], a
            ldh [nzv], a
            ld a, 4
            ld [NES_RAM + $03], a
            ldh a, [uw_y]
            ld [NES_RAM + $04], a
            ld a, e
            ld [NES_RAM + $06], a
            ld [NES_RAM + $08], a
            ld a, d
            ld [NES_RAM + $07], a
            ld [NES_RAM + $09], a
            pop de
            pop bc
            ld c, 0                         ; Y = 0
            ld e, 0                         ; X = 0
            ld a, [NES_RAM + $07]           ; A = the last entry, C = x bit 0
            srl a
            ld a, [NES_RAM + $06]
            rra
            ld l, 0
            inc l
            dec l                           ; Z = 1 (carry kept)
            ret
