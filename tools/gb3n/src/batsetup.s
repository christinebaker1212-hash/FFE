; FF3's battle setup (2E/9E8E logic, 2F/A02A-2F/A361, 2F/B909, 3F/FC27) and the magic message
; (35/A56F) as native code. Data: NES banks $2E (B_BDAT2 $4000) and $2F (B_BSET $6000).

section bank B_BAT2, $5300
; ---- the battle's setup in FF3's order (2E/9F28-9F34), the seed in bs_seed
fe_setup_all:
            ld a, [bs_seed]
            call fe_FC27
            call fe_A02A
            call fe_9FAA
            call fe_A31F
            jp fe_B909

; ---- $FC27 init rng: the battle random table at $7BE3 (seed: a sum, as FF3's zero page sum)
fe_FC27:    ld [BZ + $15], a                ; A = the seed
            ld [BZ + $16], a
            ld [BZ + $17], a
            and 2
            add 3
            ld [BZ + $22], a                ; multiplier 3 or 5
            ld a, 1
            ld [BZ + $20], a
            xor a
            ld [BZ + $21], a
            ld b, 0                         ; x(n + 1) = x(n) * k mod 1024, folded at 512
.r:         push bc
            ld a, [BZ + $22]
            ld [BZ + $18], a
            xor a
            ld [BZ + $19], a
            ld a, [BZ + $20]
            ld [BZ + $1A], a
            ld a, [BZ + $21]
            ld [BZ + $1B], a
            call b_mul16
            ld a, [BZ + $1C]
            ld [BZ + $18], a
            ld a, [BZ + $1D]
            ld [BZ + $19], a
            xor a
            ld [BZ + $1A], a
            ld a, 4
            ld [BZ + $1B], a
            call b_div16
            ld a, [BZ + $1F]                ; (FF3: remainder - $200, compared through its carry)
            sub 2
            ld c, a
            ld a, [BZ + $1E]
            or c
            jr z, .s
            ld a, [BZ + $1F]
            cp 2
            jr c, .s
            xor a
            ld hl, BZ + $1E
            sub [hl]
            ld [hl+], a
            ld a, 4
            sbc [hl]
            ld [hl], a
.s:         ld a, [BZ + $1F]
            ld [BZ + $21], a
            srl a
            ld a, [BZ + $1E]
            ld [BZ + $20], a
            rra
            pop bc
            ld e, a
            ld c, b
            ld hl, RNG_TAB
            call add_hc
            ld [hl], e
            inc b
            jr nz, .r
            ret

; ---- $A02A load monster set ($7CED battle id): set, ids, attributes, counts
fe_A02A:    ld a, [$DCED]                   ; 2E/8000 + 2 x battle id
            ld l, a
            ld a, [$DCEE]
            ld h, a
            add hl, hl
            ld de, $8000 - $4000
            add hl, de
            ld a, B_BDAT2
            call far_byte
            ld [$DD67], a
            inc hl
            ld a, B_BDAT2
            call far_byte
            ld [$DD68], a
            ld a, [$DD67]                   ; 2E/8400 + 6 x set: palettes, 4 monster ids
            ld l, a
            ld h, 0
            add hl, hl
            ld d, h
            ld e, l
            add hl, hl
            add hl, de
            ld de, $8400 - $4000
            add hl, de
            ld de, $DD69
            ld bc, 6
            ld a, B_BDAT2
            call far_copy
            ld b, 0                         ; graphics attributes ($7D73 + 2 x)
.a:         ld a, b
            ld e, a
            ld d, 0
            ld hl, $DD6B
            add hl, de
            ld a, [hl]
            call fe_A0E7
            ld a, b
            add a
            ld e, a
            ld hl, $DD73
            add hl, de
            ld a, [BZ + $7E]
            ld [hl+], a
            ld a, [BZ + $7F]
            ld [hl], a
            inc b
            ld a, b
            cp 4
            jr nz, .a
            ld a, [$DD68]                   ; counts (2E/8A00 + 4 x id), randomized
            and $3F
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            ld de, $8A00 - $4000
            add hl, de
            ld de, $DD6F
            ld bc, 4
            ld a, B_BDAT2
            call far_copy
            ld c, 0
.n:         ld hl, $DD6F
            call add_hc
            ld a, [hl]
            push hl
            push bc
            call fe_A0C8
            pop bc
            pop hl
            ld [hl], a
            inc c
            ld a, c
            cp 4
            jr nz, .n
            ret
; $A0C8 randomize monster count A (high nibble min, low nibble max; rng 0)
fe_A0C8:    ld [BZ + $7E], a
            xor a
            ld [BZ + $21], a
            ld a, [BZ + $7E]
            swap a
            and $0F
            ld b, a
            ld a, [BZ + $7E]
            and $0F
            call b_rndx
            ld [BZ + $7E], a
            ret
; $A0E7 monster graphics attribute: [$7E] = 2E/8B00 (size, graphics id), [$7F] = the id with
; the size offset, bit 7 for bosses (2E/8F00)
fe_A0E7:    cp $FF
            jr nz, .m
            ld [BZ + $7E], a
            ld [BZ + $7F], a
            ret
.m:         push bc
            ld [BZ + $81], a
            ld e, a
            ld d, 0
            ld hl, $8B00 - $4000
            add hl, de
            ld a, B_BDAT2
            call far_byte
            ld [BZ + $7E], a
            and $1F
            ld [BZ + $80], a
            ld a, [BZ + $7E]
            and $E0
            ld c, $10
            cp $20
            jr z, .o
            ld c, $18
            cp $60
            jr z, .o
            ld c, 0
.o:         ld a, [BZ + $80]
            add c
            ld [BZ + $7F], a
            ld a, [BZ + $81]
            and 7
            ld b, a
            ld a, [BZ + $81]
            srl a
            srl a
            srl a
            ld e, a
            ld d, 0
            ld hl, $8F00 - $4000
            add hl, de
            ld a, B_BDAT2
            call far_byte
            inc b
            xor a
            ld [BZ + $80], a
.s:         add a                           ; (the bit for this monster -> $80 bit 7)
            push af
            ld hl, BZ + $80
            rr [hl]
            pop af
            dec b
            jr nz, .s
            pop bc                          ; (FF3 ORs the boss bit into A, then drops it)
            ret

; ---- $9FAA the monster tilemap id ($7D7B) from the monsters' sizes and counts
fe_9FAA:    ld a, [$DD73]
            and $E0
            ld [BZ + $7E], a
            and $C0
            ld a, 0
            jr z, .s
            ld a, [BZ + $7E]
            cp $A0
            ld a, 7
            jr z, .s
            ld a, [BZ + $7E]
            and $C0
            cp $C0
            ld a, 9
            jr z, .s
            ld a, [BZ + $7E]
            and $C0
            cp $40
            jr nz, .l
            ld a, [$DD77]
            and $C0
            ld a, 3
            jr nz, .s
            ld a, 1
            jr .s
.l:         ld a, [$DD6F]
            cp 1
            jr nz, .c2
            ld a, [$DD75]
            and $C0
            ld a, 2
            jr z, .s
            ld a, [$DD75]
            and $C0
            cp $40
            ld a, 4
            jr z, .s
            ld a, [$DD75]
            and $E0
            cp $A0
            ld a, 8
            jr z, .s
.c2:        ld a, [$DD6F]
            cp 2
            jr nz, .d
            ld a, [$DD75]
            and $C0
            cp $40
            ld a, 5
            jr z, .s
.d:         ld a, 6
.s:         ld [$DD7B], a
            ret

; ---- $A31F init monster slots ($7DA7 / $7DAF types from the tilemap's starting slots, 2F/A4DA)
fe_A31F:    ld hl, $DDA7
            ld b, $10
            ld a, $FF
.z:         ld [hl+], a
            dec b
            jr nz, .z
            ld a, [$DD7B]
            add a
            add a
            add low($A4DA - $4000)
            ld l, a
            ld a, high($A4DA - $4000)
            adc 0
            ld h, a
            ld de, SET_TMP                  ; (the 4 bytes: our copy)
            ld bc, 4
            ld a, B_BSET
            call far_copy
            ld c, 0                         ; Y
.t:         ld a, c
            add low(SET_TMP)
            ld l, a
            ld h, high(SET_TMP)
            ld a, [hl]
            cp $FF
            jr z, .k
            ld [BZ + $8C], a
.k:         ld hl, $DD6F
            call add_hc
            ld a, [hl]
            and a
            jr z, .n
            ld [BZ + $82], a
.p:         ld a, [BZ + $8C]
            ld e, a
            ld d, 0
            ld hl, $DDA7
            add hl, de
            ld [hl], c
            ld hl, $DDAF
            add hl, de
            ld [hl], c
            ld hl, BZ + $8C
            inc [hl]
            ld hl, BZ + $82
            dec [hl]
            jr nz, .p
.n:         inc c
            ld a, c
            cp 4
            jr nz, .t
            ret

; ---- $B909 the number of monsters of each type ($7DCE + type) and in all ($7DD2)
fe_B909:    xor a
            ld [BZ + $80], a
            ld c, 0
.t:         ld a, c
            ld [BZ + $7E], a
            ld b, 0
            ld hl, $DDA7
            ld e, 8
.c:         ld a, [hl+]
            cp c
            jr nz, .n
            inc b
.n:         dec e
            jr nz, .c
            ld a, b
            ld [BZ + $7F], a
            push bc
            ld hl, $DDCE
            ld b, 0
            add hl, bc
            pop bc
            ld a, b
            ld [hl], a
            ld hl, BZ + $80
            add [hl]
            ld [hl], a
            inc c
            ld a, c
            cp 4
            jr nz, .t
            ld a, [BZ + $80]
            ld [$DDD2], a
            ret

; ---- $A56F show magic message (after an action: "Ineffective", spell messages, absorbed ...)
fe_A56F:    ld a, [$DE88]
            ld [BZ + $24], a
            cp $FF
            jp z, .msg
            cp $5B
            jp nc, .msg
            ld a, [$D8DA]
            cp $44
            ret z
            ld a, [$DE9B]
            and a
            jr nz, .k
            ld a, [BZ + $54]
            cp 3
            jp z, .msg
            call msg_at                     ; "Ineffective" (FF3's BEQ tests LDX $78EE: on
            ld [hl], $3B                    ;   only when the queue is empty)
            ld a, [$D8EE]
            and a
            jp z, .msg
            ld a, $3B
.k:         ld a, [BZ + $54]
            cp 5
            jr z, .l5
            cp 4
            jr nz, .s
            ld a, 1                         ; life on an undead: the death spell's message
            jr .l
.l5:        ld a, $34                       ; death on an undead: life's
.l:         ld [BZ + $24], a
            xor a
            ld [BZ + $54], a
.s:         call msg_at
            ld a, [hl]
            and a
            jr nz, .bit
            ld [hl], $FF                    ; (FF3: STA, then its BEQ sees LDA #$FF: on)
            jr .k
.bit:       ld a, [BZ + $24]                ; a message for this spell? (35/A5FD bits)
            srl a
            srl a
            srl a
            ld e, a
            ld d, 0
            ld hl, mmsg_bits
            add hl, de
            ld a, [BZ + $24]
            and 7
            inc a
            ld b, a
            ld a, [hl]
.sh:        add a
            dec b
            jr nz, .sh
            jr nc, .msg
            call msg_at
            ld a, [BZ + $24]
            add $20
            ld [hl], a
.msg:       call msg_at
            ld a, [BZ + $54]
            and a
            jr z, .x
            cp 2
            ld a, 1                         ; "Absorbed!"
            jr z, .p
            ld a, [BZ + $54]
            cp 1
            ld a, $45                       ; "Damages undead"
            jr z, .p
            ld a, $4F                       ; "Backfired!"
.p:         ld [hl], a
.x:         xor a
            ld [BZ + $54], a
            ret
mmsg_bits:  ds 9                            ; (35/A5FD, from the ROM: ROMDATA)
SET_TMP    = $C510
