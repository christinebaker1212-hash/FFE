; FF3's battle main loop bookkeeping (34/81A0-34/88E1, 34/9474, 34/9AE7, 34/9CE3) as native code.

section bank B_BAT2, $7400
; $81A0 defence back after defending ($7CE4)
fe_81A0:    xor a
            ld [BZ + $52], a
.c:         call b_choff
            add $23
            ld c, a
            call p5b
            ld a, [BZ + $52]
            ld e, a
            ld d, 0
            push hl
            ld hl, $DCE4
            add hl, de
            ld a, [hl]
            and a
            jr z, .n
            ld [hl], 0
            pop hl
            ld [hl], a
            push hl
.n:         pop hl
            ld hl, BZ + $52
            inc [hl]
            ld a, [hl]
            cp 4
            jr nz, .c
            xor a
            ld [BZ + $52], a
            ret

; $81C3 a turn's start: commands, flags
fe_81C3:    call fe_88E1
            ld a, $FF
            ld hl, $DAC3
            ld b, 4
.c:         ld [hl+], a
            dec b
            jr nz, .c
            ld b, $FF
            call fe_87AA
            ld a, b
            ld [$DAC2], a
            ld [BZ + $74], a
            ld hl, $DBE2
            inc [hl]
            ld hl, B_CH
            ld b, $0C
.r:         push hl
            ld de, $2C
            add hl, de
            ld a, [hl]
            and $E7
            ld [hl], a
            pop hl
            push hl
            inc hl
            inc hl
            bit 0, [hl]
            jr nz, .j
            ld de, $2E - 2
            add hl, de
            xor a
            ld [hl+], a
            ld [hl+], a
            ld [hl], a
.j:         pop hl
            ld de, $40
            add hl, de
            dec b
            jr nz, .r
            ret

; $8213 an action's start: numerals, messages, graphics flags
fe_8213:    ld hl, $DE4F
            ld b, $20
            ld a, $FF
.z:         ld [hl+], a
            dec b
            jr nz, .z
            ld [$D8D6], a
            ld [$D8D7], a
            ld [$D8D8], a
            ld [$D8D9], a
            ld [$DE88], a
            ld hl, $D8DA
            ld b, 10
.m:         ld [hl+], a
            dec b
            jr nz, .m
            ld [$DEE1], a
            xor a
            ld [$D8EE], a
            ld [$DE98], a
            ld [$DE99], a
            ld [$DE9A], a
            ld [$DE1F], a
            ld [$DE20], a
            ld [BZ + $BB], a
            ld [BZ + $BC], a
            ld [$DE93], a
            ld [$D8D4], a
            ld [$DEC2], a
            ld [$DE0F], a
            ld [$DE10], a
            ld [$DE11], a
            ld [$DE12], a
            ld [BZ + $72], a
            ld [$DEDF], a
            ld hl, BZ + $E0
            ld b, $20
.s:         ld [hl+], a
            dec b
            jr nz, .s
            ret

; $8271 the number of times each command was used ($78F0 + 4 x character + slot)
fe_8271:    ld b, 0
.c:         ld hl, $DAC3
            ld a, l
            add b
            ld l, a
            ld a, [hl]
            cp $FF
            jr z, .n
            ld c, a
            ld a, b
            add a
            add a
            add c
            ld e, a
            ld d, 0
            ld hl, $D8F0
            add hl, de
            inc [hl]
.n:         inc b
            ld a, b
            ld [BZ + $52], a
            cp 4
            jr nz, .c
            ret

; $8295 update monster rows (+$33 bit 0: back row)
fe_8295:    call fe_86B9
            ld hl, B_MO + $33
            ld a, [BZ + $18]
            ld b, 8
.m:         add a
            push af
            jr nc, .bk
            res 0, [hl]
            jr .n
.bk:        set 0, [hl]
.n:         ld de, $40
            add hl, de
            pop af
            dec b
            jr nz, .m
            ld a, l
            sub $33
            ld [BZ + $1A], a
            ld a, h
            sbc 0
            ld [BZ + $1B], a
            ret
; $86B9 determine monster rows: [BZ+$18] = the front row's slots (bit 7 = slot 0)
fe_86B9:    xor a
            ld [BZ + $18], a
            call fe_86EA
            ld b, 7
.c:         call fe_8705
            jr nc, .n
            ld hl, BZ + $1B
            cp [hl]
            ret z
            ld a, [BZ + $18]
            push bc
            call b_setbit
            pop bc
            ld [BZ + $18], a
.n:         dec b
            bit 7, b
            jr z, .c
            ret
; $86EA find back row: the front monster's row [$1A], the back row value [$1B] = it - 2
fe_86EA:    ld b, 7
.c:         call fe_8705
            jr nc, .n
            ld [BZ + $1A], a
            sub 2
            ld [BZ + $1B], a
            ret
.n:         dec b
            bit 7, b
            jr z, .c
            ret
; $8705 get monster row of slot B: A = the row, carry clear if the slot is empty
fe_8705:    ld a, b
            ld [BZ + $7F], a
            ld e, a
            ld d, 0
            ld hl, $DDA7
            add hl, de
            ld a, [hl]
            cp $FF
            jr z, .e
            ld a, [$DD7B]                   ; the formation's 2-bit rows (FF3's table at $8739)
            add a
            ld e, a
            ld hl, mon_rows
            add hl, de
            ld a, [hl+]
            ld [BZ + $80], a
            ld a, [hl]
            ld [BZ + $81], a
            ld c, b
            inc c
.s:         ld hl, BZ + $81
            sla [hl]
            dec l
            rl [hl]
            ld hl, BZ + $7E
            rl [hl]
            ld hl, BZ + $81
            sla [hl]
            dec l
            rl [hl]
            ld hl, BZ + $7E
            rl [hl]
            dec c
            jr nz, .s
            ld a, [BZ + $7E]
            and 3
            scf
            ret
.e:         and a
            ret

; $82CE display battle type message (strike first / ambushed / back attack)
fe_82CE:    ld a, [$D8BA]
            and a
            jr z, .x
            bit 7, a
            jr nz, .amb
            and 8
            jr nz, .x
            ld a, $17                       ; "Strike first!"
            jr .m
.amb:       and 8
            ld a, $18                       ; "Ambushed!"
            jr z, .m
            ld a, $19                       ; "Back attack!"
.m:         ld [$D8DA], a
            ld a, 2
            ld [$D8D5], a
            ld [$DEC2], a
            call bat_script
.x:         ld a, [$D8BA]
            and 9
            ld [$D8BA], a
            ret

; $8306 end of battle: equipment, then status / hp / mp back to the save page
fe_8306:    xor a
            ld [BZ + $52], a
.e:         call x_AA16
            ld hl, BZ + $52
            inc [hl]
            ld a, [hl]
            cp 4
            jr nz, .e
            xor a
            ld [BZ + $52], a
.c:         call b_choff
            inc a
            ld c, a
            call p5b
            ld a, [hl]
            and $FE
            ld [BZ + $18], a
            inc hl
            inc hl
            ld a, [hl+]
            ld [BZ + $19], a
            ld a, [hl]
            ld [BZ + $1A], a
            ld a, 7
            call b_addoff
            ld c, a
            call p5b
            ld de, BZ + $1B
            ld b, 8
.mp:        ld a, [hl+]
            ld [de], a
            inc e
            dec b
            jr nz, .mp
            ld a, 2
            call b_addoff
            ld c, a
            call p57
            ld a, [BZ + $18]
            ld [hl], a
            ld a, $0C
            call b_addoff
            ld c, a
            call p57
            ld a, [BZ + $19]
            ld [hl+], a
            ld a, [BZ + $1A]
            ld [hl], a
            ld a, $30
            call b_addoff
            ld c, a
            call p57
            ld de, BZ + $1B
            ld b, 8
.m2:        ld a, [de]
            ld [hl+], a
            inc hl
            inc e
            dec b
            jr nz, .m2
            ld hl, BZ + $52
            inc [hl]
            ld a, [hl]
            cp 4
            jr nz, .c
            ret

; $8374 used items back to the pack; [BZ+$74] set if someone tries to run
fe_8374:    xor a
            ld [BZ + $52], a
            ld [BZ + $74], a
.c:         call b_choff
            add $3F
            ld c, a
            call p5b
            ld a, [hl]
            and a
            call nz, fe_9AE7
            call b_choff
            add $2E
            ld c, a
            call p5b
            ld a, [hl]
            cp 6
            jr z, .run
            cp 7
            jr nz, .n
.run:       ld hl, BZ + $74
            inc [hl]
.n:         ld hl, BZ + $52
            inc [hl]
            ld a, [hl]
            cp 4
            jr nz, .c
            ret
; (the battle screen's call: character [$52]'s pending item)
fe_9AE7_a:  call b_choff
            add $3F
            ld c, a
            call p5b
            ld a, [hl]
            jp fe_9AE7

; terrain targets (35/AA22): [bs_n] = the mask, [bs_t] = the flags
fe_AAC3_t:  call fe_AAC3
            sub $50
            inc a
            ld b, a
            ld a, [terr_bits]
.s:         add a
            dec b
            jr nz, .s
            jr nc, .all
            ld hl, fe_A2E9
            call alg_call
            ld a, [$DE99]
            ld [bs_n], a
            ld a, $80
            ld [bs_t], a
            ret
.all:       ld a, $FF
            ld [bs_n], a
            ld a, $C0
            ld [bs_t], a
            ret
terr_bits:  ds 1                            ; (35/AB06, from the ROM: ROMDATA)

; $9AE7 return used item A (HL at the record's +$3F) to the inventory
fe_9AE7:    ld [BZ + $18], a
            ld [hl], 0
            dec hl
            ld a, [hl]
            and a
            jr nz, .x
            push hl
            ld b, 0
            ld a, [BZ + $18]
            ld c, a
.f:         call inv_x
            ld a, [hl+]
            cp c
            jr nz, .nf
            inc [hl]
            jr .d
.nf:        inc b
            inc b
            ld a, b
            cp $40
            jr nz, .f
            ld b, 0
.e:         call inv_x
            ld a, [hl]
            and a
            jr z, .p
            inc b
            inc b
            jr nz, .e
.p:         ld [hl], c
            inc hl
            inc [hl]
.d:         pop hl
.x:         ld [hl], 0
            ret

; $874D battle start: counters cleared
fe_874D:    ld a, [$DCEF]
            ld [$DCE3], a
            call fe_88E1
            ld a, low(B_MO)
            ld [BZ + $5D], a
            ld [BZ + $6E], a
            ld a, high(B_MO)
            ld [BZ + $5E], a
            ld [BZ + $6F], a
            xor a
            ld hl, $D8F0
            ld b, $10
.a:         ld [hl+], a
            dec b
            jr nz, .a
            ld hl, $DAC3
            ld b, 8
.b:         ld [hl+], a
            dec b
            jr nz, .b
            ld hl, $D8C9
            ld b, 6
.c:         ld [hl+], a
            dec b
            jr nz, .c
            ld hl, $DEC4
            ld b, 8
.d:         ld [hl+], a
            dec b
            jr nz, .d
            ld hl, $DCE4
            ld b, 4
.e:         ld [hl+], a
            dec b
            jr nz, .e
            ld a, $FF
            ld [$DEE1], a
            ld [$DBE2], a
            ld b, a
            call fe_87AA
            ld a, b
            ld [$DBE1], a
            ld [$DCE8], a
            ld [$DCEC], a
            ld [$D8D3], a
            ld [$D8B7], a
            ld [BZ + $72], a
            ld [$DCEB], a
            ret
; $87AA characters' commands reset (B = X): $78CF-$78D2 = X, then X + 1 -> $52, $53, $54
fe_87AA:    ld hl, $D8CF
            ld a, b
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl], a
            inc b
            ld a, b
            ld [BZ + $52], a
            ld [BZ + $53], a
            ld [BZ + $54], a
            ret

; $87BE battle flags; first strike / ambush / back attack by the levels
fe_87BE:    ld hl, $DED8
            res 6, [hl]
            ld a, [$DCEE]
            and a
            jr z, .w
            set 4, [hl]
.w:         ld a, [$D4C6]
            cp 7
            jr nz, .v
            set 6, [hl]
.v:         bit 1, [hl]
            jr z, .r
            ld hl, $D8B7
            inc [hl]
.r:         ld hl, $DED8                    ; rotate the flags by one (bit 0 -> bit 7)
            ld a, [hl]
            rrca
            ld [hl], a
            %MOVZ $24, $5B
            xor a
            ld [BZ + $2A], a
            ld [BZ + $2B], a
            ld [$D8C3], a
            ld [$D8BA], a
            ld a, [$DED8]
            bit 7, a
            ret nz
            and $20
            ret nz
            ld a, 4
            ld [BZ + $26], a
            call fe_886F
            ld [BZ + $28], a
            ld a, $64
            call b_rnd
            ld hl, BZ + $28
            cp [hl]
            jr nc, .c1
            ld hl, BZ + $2A
            inc [hl]
.c1:        ld a, low(B_MO)
            ld [BZ + $24], a
            ld a, high(B_MO)
            ld [BZ + $25], a
            ld a, 8
            ld [BZ + $26], a
            call fe_886F
            ld [BZ + $29], a
            ld a, $64
            call b_rnd
            ld hl, BZ + $29
            cp [hl]
            jr nc, .c2
            ld hl, BZ + $2B
            inc [hl]
.c2:        ld hl, BZ + $2A
            inc [hl]
            inc l
            inc [hl]
            ld a, [BZ + $2B]
            ld hl, BZ + $2A
            cp [hl]
            ret z
            jr nc, .mon
            ld hl, $D8BA                    ; the characters strike first
            inc [hl]
            ret
.mon:       ld hl, BZ + $29
            srl [hl]
            srl [hl]
            ld a, [BZ + $28]
            call b_rnd
            ld hl, BZ + $29
            cp [hl]
            jr c, .back
            ld a, $80                       ; ambush
            jr .s
.back:      call fe_88A4
            ld a, $88                       ; back attack
.s:         ld [$D8C3], a
            ld [$D8BA], a
            ret
; $886F average level of [BZ+$26] records from [BZ+$24] (non-zero levels)
fe_886F:    xor a
            ld [BZ + $18], a
            ld [BZ + $19], a
            ld [BZ + $1A], a
            ld [BZ + $1B], a
            ld b, 0
.c:         %LDZ $24, 0
            and a
            jr z, .n
            ld hl, BZ + $18
            add [hl]
            ld [hl+], a
            ld a, 0
            adc [hl]
            ld [hl+], a
            inc [hl]
.n:         ld hl, BZ + $24
            ld a, [hl]
            add $40
            ld [hl+], a
            ld a, [hl]
            adc 0
            ld [hl], a
            inc b
            ld a, [BZ + $26]
            cp b
            jr nz, .c
            call b_div16
            ld a, [BZ + $1C]
            ret
; $88A4 toggle front / back row for all characters
fe_88A4:    xor a
            ld [BZ + $52], a
.c:         call b_choff
            add $0F
            ld c, a
            call p59
            ld a, [hl]
            xor 1
            ld [hl], a
            and 1
            ld [BZ + $21], a
            ld a, $33
            call b_addoff
            ld c, a
            call p5b
            ld a, [hl]
            xor 1
            ld [hl], a
            and 1
            ld [BZ + $21], a
            ld hl, BZ + $52
            inc [hl]
            ld a, [hl]
            cp 4
            jr nz, .c
            xor a
            ld [BZ + $52], a
            ret
; $88E1 init character / monster pointers
fe_88E1:    ld hl, BZ + $57
            ld a, low($D100)
            ld [hl+], a
            ld a, high($D100)
            ld [hl+], a
            ld a, low($D200)
            ld [hl+], a
            ld a, high($D200)
            ld [hl+], a
            ld a, low(B_CH)
            ld [hl+], a
            ld a, high(B_CH)
            ld [hl+], a
            ld a, low(B_MO)
            ld [hl+], a
            ld a, high(B_MO)
            ld [hl], a
            ret

; $9474 update near fatal (hp at most max / 4: status 1 bit 0, $7CEC)
fe_9474:    xor a
            ld [BZ + $52], a
.c:         call b_choff
            inc a
            ld c, a
            call p5b
            bit 7, [hl]
            jr nz, .n
            inc hl
            inc hl
            ld de, BZ + $18
            ld b, 4
.h:         ld a, [hl+]
            ld [de], a
            inc e
            dec b
            jr nz, .h
            ld hl, BZ + $1B
            srl [hl]
            dec l
            rr [hl]
            inc l
            srl [hl]
            dec l
            rr [hl]
            ld a, [BZ + $18]
            ld c, a
            ld a, [BZ + $1A]
            sub c
            ld a, [BZ + $19]
            ld c, a
            ld a, [BZ + $1B]
            sbc c
            push af
            ld a, [BZ + $5F]
            inc a
            ld c, a
            call p5b
            pop af
            ld a, [BZ + $52]
            ld b, a
            jr c, .clr
            set 0, [hl]
            ld a, [$DCEC]
            call b_setbit
            jr .s
.clr:       res 0, [hl]
            ld a, [$DCEC]
            call b_clrbit
.s:         ld [$DCEC], a
.n:         ld hl, BZ + $52
            inc [hl]
            ld a, [hl]
            cp 4
            jr nz, .c
            ret

; $9CE3 init characters / monsters
fe_9CE3:    call fe_874D
            call x_A400
            call fe_87BE
            call fe_9474
            call fe_9D06
            xor a
            ld [BZ + $52], a
.e:         call x_AA16
            ld hl, BZ + $52
            inc [hl]
            ld a, [hl]
            cp 4
            jr nz, .e
            xor a
            ld [BZ + $52], a
            ret
x_A400:     ld hl, fe_A400
            jp alg_call

mon_rows:   ds 20                           ; (FF3's 34/8739, from the ROM: ROMDATA)
