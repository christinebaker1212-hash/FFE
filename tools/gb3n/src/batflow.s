; FF3's battle flow (34/8074-35/BFFF, the rules; the screen is ours) as native code; memory as in
; batcore.s. Part 1: attack order, executing an action, fight / magic / item, battle over.

section bank B_BAT2, $4000
; ---- $8F57 FF3's sort (recursive, largest first): keys [BZ+$1C] + Y, values [BZ+$1E] + Y for
; Y = [BZ+$1A] .. [BZ+$22] (the values set to 0, 1, ... first)
fe_8F57:    ld a, [BZ + $1A]
            ld c, a
            ld a, [BZ + $22]
            push af
            sub c
            inc a
            ld [BZ + $18], a
            ld b, 1                         ; values[1 ..] = 0, 1, ...
            ld c, 0
.v:         ld a, b
            call qs_val
            ld [hl], c
            inc b
            inc c
            ld a, [BZ + $18]
            cp c
            jr nz, .v
            pop af
fe_8F6F:    ld [BZ + $1B], a
            ld a, [BZ + $18]
            push af
            ld a, [BZ + $19]
            push af
            push bc                         ; (C = FF3's X)
            ld a, [BZ + $1A]
            ld c, a
            ld [BZ + $18], a
            ld a, [BZ + $1B]
            ld b, a
            ld [BZ + $19], a
            ld a, [BZ + $1A]
            call qs_key
            ld a, [hl]
            ld [BZ + $20], a
.l87:       ld a, [BZ + $1B]
            ld b, a
            ld hl, BZ + $1A
            cp [hl]
            jr c, .d3
.l8d:       ld a, b                         ; from the top: skip keys below the pivot
            call qs_key
            ld a, [hl]
            ld hl, BZ + $20
            cp [hl]
            jr nc, .f96
            dec b
            jr .l8d
.f96:       ld a, b
            ld [BZ + $1B], a
            ld a, [BZ + $1A]
            ld b, a
.l9a:       ld a, b                         ; from the bottom: skip keys above it
            call qs_key
            ld a, [hl]
            ld hl, BZ + $20
            cp [hl]
            jr z, .fa5
            jr c, .fa5
            inc b
            jr .l9a
.fa5:       ld a, b
            ld [BZ + $1A], a
            ld a, [BZ + $1B]
            ld b, a
            ld hl, BZ + $1A
            cp [hl]
            jr c, .d3
            ld a, [BZ + $1B]                ; swap the pairs at $1A and $1B
            call qs_key
            ld d, h
            ld e, l
            ld a, [BZ + $1A]
            call qs_key
            ld a, [de]
            ld c, [hl]
            ld [hl], a
            ld a, c
            ld [de], a
            ld a, [BZ + $1B]
            call qs_val
            ld d, h
            ld e, l
            ld a, [BZ + $1A]
            call qs_val
            ld a, [de]
            ld c, [hl]
            ld [hl], a
            ld a, c
            ld [de], a
            ld hl, BZ + $1B
            dec [hl]
            ld hl, BZ + $1A
            inc [hl]
            jr .l87
.d3:        ld a, [BZ + $1A]
            ld c, a
            ld a, [BZ + $18]
            cp b
            jr nc, .e3
            ld [BZ + $1A], a
            ld a, b
            push bc
            call fe_8F6F
            pop bc
.e3:        ld a, [BZ + $19]
            ld e, a
            ld a, c
            cp e
            jr nc, .x
            ld [BZ + $1A], a
            ld a, e
            push bc
            call fe_8F6F
            pop bc
.x:         pop bc
            pop af
            ld [BZ + $19], a
            pop af
            ld [BZ + $18], a
            ret
qs_key:     ld hl, BZ + $1C                 ; HL = [ptr] + A
            jr qs_p
qs_val:     ld hl, BZ + $1E
qs_p:       add [hl]
            inc l
            ld h, [hl]
            ld l, a
            ret nc
            inc h
            ret

; ---- $9777 determine attack order -> $7ACB (ends with $FF)
fe_9777:    ld b, 0                         ; 12 random keys
.r:         push bc
            ld a, $FF
            call b_rnd
            pop bc
            ld e, a
            ld c, b
            ld hl, B_BUF
            call add_hc
            ld [hl], e
            ld hl, $D40C
            call add_hc
            ld [hl], b
            inc b
            ld a, b
            cp $0C
            jr nz, .r
            ld a, 1
            ld [BZ + $1A], a
            ld hl, $D3FF
            ld a, $0B
            call qs_ptrs
            ld a, $0C
            ld [BZ + $22], a
            call fe_8F57
            ld hl, $D40C
            ld de, $DACB
            ld b, $0C
.c:         ld a, [hl+]
            or $80
            ld [de], a
            inc de
            dec b
            jr nz, .c
            xor a                           ; the characters: agility + random (0 .. 2 x agility)
            ld [BZ + $52], a
.ch:        call b_choff
            add $18
            ld c, a
            call p57
            ld a, [hl]
            ld [BZ + $3C], a
            add a
            call b_rnd
            ld hl, BZ + $3C
            add [hl]
            ld c, a
            ld a, [BZ + $52]
            ld e, a
            ld d, 0
            ld hl, B_BUF
            add hl, de
            ld [hl], c
            ld hl, $D404
            add hl, de
            ld [hl], e
            ld hl, BZ + $52
            inc [hl]
            ld a, [hl]
            cp 4
            jr nz, .ch
            ld a, 1
            ld [BZ + $1A], a
            ld hl, $D3FF
            ld a, $03
            call qs_ptrs
            ld a, 4
            ld [BZ + $22], a
            call fe_8F57
            ld b, 0                         ; the characters into the places of entries $88-$8B
            ld c, $FF
.pl:        inc c
            ld hl, $DACB
            call add_hc
            ld a, [hl]
            cp $88
            jr c, .pl
            push hl
            ld hl, $D404
            ld a, l
            add b
            ld l, a
            ld a, [hl]
            pop hl
            ld [hl], a
            inc b
            ld a, b
            cp 4
            jr nz, .pl
            ld hl, $DACB                    ; -> $7400, then only those able to act
            ld de, B_BUF
            ld b, $0C
.cp:        ld a, [hl+]
            ld [de], a
            inc e
            dec b
            jr nz, .cp
            xor a
            ld [BZ + $24], a
            ld [BZ + $25], a
.f:         ld a, [BZ + $25]
            ld c, a
            ld hl, B_BUF
            call add_hc
            ld a, [hl]
            bit 7, a
            jr nz, .mo
            ld [BZ + $52], a
            call b_choff
            inc a
            ld c, a
            call p5b
            ld a, [hl]
            and $C0
            jr nz, .nx
            jr .keep
.mo:        and $7F
            ld b, $40
            call b_mul
            ld a, [BZ + $1A]
            add low(B_MO)
            ld [BZ + $1A], a
            ld l, a
            ld a, [BZ + $1B]
            adc high(B_MO)
            ld [BZ + $1B], a
            ld h, a
            inc hl
            ld a, [hl]
            and $E8
            jr nz, .nx
.keep:      ld a, [BZ + $25]
            ld c, a
            ld hl, B_BUF
            call add_hc
            ld a, [hl]
            push af
            ld a, [BZ + $24]
            ld c, a
            ld hl, $DACB
            call add_hc
            pop af
            ld [hl], a
            ld hl, BZ + $24
            inc [hl]
.nx:        ld hl, BZ + $25
            inc [hl]
            ld a, [hl]
            cp $0C
            jr nz, .f
            ld a, [BZ + $24]
            ld c, a
            ld hl, $DACB
            call add_hc
            ld [hl], $FF
            ret
; keys at HL ($73FF), values at HL + 1 + A ($740B / $7403)
qs_ptrs:    push af
            ld a, l
            ld [BZ + $1C], a
            ld a, h
            ld [BZ + $1D], a
            pop af
            inc a
            add l
            ld [BZ + $1E], a
            ld a, h
            adc 0
            ld [BZ + $1F], a
            ret
add_hc:     ld a, l                         ; HL += C
            add c
            ld l, a
            ret nc
            inc h
            ret

; ---- $9DE4 execute action ($7ACB + [$7AC2])
fe_9DE4:    ld a, [$DAC2]
            ld c, a
            ld hl, $DACB
            call add_hc
            ld a, [hl]
            push af
            push af
            bit 7, a
            jr z, .ch
            and $7F
            add 4
.ch:        ld [BZ + $18], a
            ld [BZ + $26], a
            ld a, $40
            ld [BZ + $1A], a
            ld a, low(B_CH)
            ld [BZ + $20], a
            ld a, high(B_CH)
            ld [BZ + $21], a
            call b_calcp
            ld a, [BZ + $1C]
            ld [BZ + $6E], a
            ld a, [BZ + $1D]
            ld [BZ + $6F], a
            ld a, [BZ + $26]
            cp $0C
            jr c, .ns
            pop af                          ; the summon
            pop af
            jr fe_9E5F
.ns:        cp 4
            jr c, .m
            sub 4
            or $80
.m:         ld [$D8D6], a
            pop af
            and $7F
            ld b, a
            xor a
            call b_setbit
            ld [$DE98], a
            pop af
            bit 7, a
            jr z, fe_9E5F
            ld hl, $DE9A                    ; a monster acts
            set 7, [hl]
            ld a, [$DCED]
            cp $55
            jr nz, .b79
            ld a, [$DCEE]
            and a
            jr z, .hp
            jr fe_9E5F
.b79:       cp $79
            jr z, .b90
            cp $90
            jr nz, fe_9E5F
.b90:       ld a, [$DCEE]
            and a
            jr z, fe_9E5F
.hp:        %LDZ $6E, 6                     ; (these bosses: hp high byte = max)
            %STZ $6E, 4
fe_9E5F:    %LDZ $6E, 1
            and $C0
            jr z, .alive
            xor a
            ld [$DE98], a
            ld [$DEC2], a
            dec a
            ld [$D8D6], a
            ld [$D8D8], a
            ld [$DCEB], a
            xor a
            call fe_9F7B
            jp .flags
.alive:     %LDZ $6E, 2
            and $C0
            jr z, .tg
            ld a, 1
            call fe_9F7B
            call fe_91CE
            call fe_9F87
.tg:        %LDZ $6E, $2F
            ld [$DE99], a
            ld [$DE9B], a
            and a
            jr nz, .t1
            call fe_9F87
.t1:        ld b, 0                         ; X = the first target's bit
.t2:        add a
            jr c, .t3
            inc b
            jr nz, .t2
.t3:        %LDZ $6E, $30
            bit 7, a
            jr z, .tc
            ld hl, $DE9A
            set 6, [hl]
            ld a, b
            or $80
            ld [$D8D8], a
            ld a, b
            add 4
            ld b, a
            jr .t4
.tc:        ld a, b
            ld [$D8D8], a
.t4:        %LDZ $6E, $30
            and $40
            jr z, .t5
            ld a, $88
            ld [$D8D8], a
.t5:        ld a, b
            ld [BZ + $18], a
            ld a, $40
            ld [BZ + $1A], a
            ld a, low(B_CH)
            ld [BZ + $20], a
            ld a, high(B_CH)
            ld [BZ + $21], a
            call b_calcp
            ld a, [BZ + $1C]
            ld [BZ + $70], a
            ld a, [BZ + $1D]
            ld [BZ + $71], a
.flags:     call b_aflags
            and $10
            jr z, .nm
            %LDZ $6E, $2E                   ; magic
            ld [BZ + $1A], a
            jp .mag
.nm:        call b_aflags
            and 8
            jr z, .cmd
            %LDZ $6E, $2E                   ; an item
            ld [BZ + $1A], a
            jr .itm
.cmd:       %LDZ $6E, $2E
            ld [BZ + $1A], a
            cp $13
            jr c, .go
            cp $46
            jr nc, .spl
.itm:       ld a, $13
            jr .go
.spl:       call b_aflags                   ; a character's spell: 1 mp of its level
            bit 7, a
            jr nz, .mag
            and 7
            ld [BZ + $52], a
            ld e, a
            ld d, 0
            ld hl, $DAC7
            add hl, de
            ld a, [hl]
            add 7
            ld c, a
            %PZ $6E, 0
            call add_hc
            dec [hl]
            ld a, [BZ + $1A]
            cp $CE
            jp z, fe_9FD6
            cp $D5
            jp z, fe_9FD6
            cp $DC
            jp z, fe_9FD6
            cp $E3
            jp z, fe_9FD6
            cp $EA
            jp z, fe_9FD6
            cp $F1
            jp z, fe_9FD6
            cp $F8
            jp z, fe_9FD6
            cp $FF
            jp z, fe_9FD6
.mag:       ld a, $14
.go:        ld [$DEC2], a
            add a
            ld l, a
            ld h, 0
            ld de, act_table
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            jp hl
act_table:  dw fe_9FA8, fe_A68A, fe_A7DF, fe_A7EA, fe_A104, fe_A881, fe_A8BF, fe_A93B
            dw fe_A9D8, fe_AA11, fe_9FA8, fe_AA5D, fe_AB73, fe_AB0C, fe_ABA4, fe_AC6F
            dw fe_ACD5, fe_AD16, fe_AD75, fe_A3BB, fe_A367

; $9F7B set command id A (the magic / item flags cleared)
fe_9F7B:    %STZ $6E, $2E
            call b_aflags
            and $E7
            ld [hl], a
            ret
; $9F87 set self-target; A = the target mask
fe_9F87:    call b_aflags
            push af
            and 7
            ld b, a
            xor a
            call b_setbit
            %STZ $6E, $2F
            ld [$DE99], a
            ld [$DE9B], a
            pop af
            and $80
            %STZ $6E, $30
            %LDZ $6E, $2F
            ret
; $9FA8 action: no effect
fe_9FA8:    ld hl, $DCEB
            inc [hl]
            ret
; $91CE clear target message
fe_91CE:    ld a, $FF
            ld [$D8D8], a
            ret

; ---- $9FD6 calculate summon properties: the summon at $7875 acts in the caster's place
fe_9FD6:    ld hl, $D875
            ld b, $40
            xor a
            ld [$DE93], a
.z:         ld [hl+], a
            dec b
            jr nz, .z
            ld a, 2
            ld [BZ + $30], a
            call b_aflags
            and 7
            ld [BZ + $52], a
            call b_choff
            ld c, a
            call p57
            ld a, [hl]                      ; Summoner / Sage: the 3rd attack, else 1st or 2nd
            cp $13
            jr z, .s3
            cp $14
            jr z, .s3
            ld a, $63
            call b_rnd
            cp $32
            jr nc, .s1
            ld hl, BZ + $30
            dec [hl]
.s1:        ld hl, BZ + $30
            dec [hl]
.s3:        ld a, [BZ + $52]
            ld e, a
            ld d, 0
            ld hl, $DAC7
            add hl, de
            ld a, [hl]
            and 7
            ld [BZ + $1A], a
            swap a
            ld hl, BZ + $30
            or [hl]
            ld [$DE94], a
            ld a, low($D875)
            ld [BZ + $6E], a
            ld a, high($D875)
            ld [BZ + $6F], a
            ld a, $0F                       ; job level, intellect, spirit x 2 (reversed)
            call b_addoff
            ld c, a
            call p5b
            ld b, 3
            ld de, BZ + $1A
.c:         ld a, [hl+]
            add a
            ld [de], a
            dec e
            dec b
            jr nz, .c
            ld a, 1
            call b_addoff
            ld c, a
            call p5b
            ld a, [hl]
            and $30
            %STZ $6E, 1
            %PZ $6E, $0F
            ld de, BZ + $1A
            ld b, 3
.c2:        ld a, [de]
            ld [hl+], a
            dec e
            dec b
            jr nz, .c2
            ld a, [BZ + $1A]
            %STZ $6E, 0
            ld a, 3
            %STZ $6E, 3
            ld a, [$DAC2]
            ld c, a
            ld hl, $DACB
            call add_hc
            ld [hl], $88
            call b_aflags
            or $90
            ld [hl], a
            ld a, [BZ + $52]
            ld e, a
            ld d, 0
            ld hl, $DAC7
            add hl, de
            ld a, [hl]
            and 7
            ld [BZ + $18], a
            ld c, a
            add a
            add c
            ld hl, BZ + $30
            add [hl]
            push af
            add $5B
            ld [BZ + $18], a
            ld [BZ + $26], a
            ld a, 8
            ld [BZ + $1A], a
            ld a, $C0
            ld [BZ + $20], a
            ld a, $98
            ld [BZ + $21], a
            ld b, 0
            ld a, B_BDAT
            call b_ldarr
            ld a, [$D405]
            bit 7, a
            jr z, .en
            ld a, $40
            ld [BZ + $28], a
            ld a, $F0
            ld [BZ + $27], a
            jr .set
.en:        and $40
            jr z, .one
            ld a, $C0
            ld [BZ + $28], a
            ld a, $FF
            ld [BZ + $27], a
            jr .set
.one:       ld a, 7
            call b_rnd
            ld [BZ + $27], a
            ld b, $40
            call b_mul
            ld a, [BZ + $1A]
            add low(B_MO)
            ld [BZ + $1A], a
            ld l, a
            ld a, [BZ + $1B]
            adc high(B_MO)
            ld [BZ + $1B], a
            ld h, a
            inc hl
            ld a, [hl]
            and $E0
            jr nz, .one
            ld a, [BZ + $27]
            ld b, a
            xor a
            call b_setbit
            ld [BZ + $27], a
            ld a, $80
            ld [BZ + $28], a
.set:       %PZ $6E, $2E
            ld a, [BZ + $26]
            ld [hl+], a
            ld a, [BZ + $27]
            ld [hl+], a
            ld a, [BZ + $28]
            ld [hl], a
            ld a, low(B_MO)
            ld [BZ + $5D], a
            ld a, high(B_MO)
            ld [BZ + $5E], a
            pop af
            push af
            add $78
            ld [$D8DA], a
            pop af
            add $21
            ld [$D8D9], a
            jp fe_9DE4

; ---- action $04: fight
fe_A104:    call b_aflags
            bit 7, a
            jp z, .chr
            %LDZ $70, $2C                   ; a monster: a Knight covers a near-fatal ally
            and 7
            ld [BZ + $18], a
            ld b, a
            ld a, [$DCEC]
            call b_chkbit
            jp z, .go
            %LDZ $70, 1
            and $C0
            jp nz, .go
            inc hl
            ld a, [hl]
            and $21
            jp nz, .go
            xor a
            ld [BZ + $52], a
            ld [BZ + $22], a
.k:         ld a, [BZ + $52]
            add a
            ld [BZ + $19], a
            ld e, a
            ld d, high(BZ)
            ld a, e
            add $24
            ld e, a
            ld a, [BZ + $52]
            add a
            ld [de], a
            call b_choff
            ld c, a
            call p57
            ld a, [hl]
            cp 7
            jr nz, .nk
            inc c
            call p5b
            ld a, [hl+]
            and $C1
            jr nz, .nk
            ld a, [hl]
            and $E0
            jr nz, .nk
            ld a, [BZ + $5F]
            add 3
            ld c, a
            call p5b
            ld a, [BZ + $19]
            add low(BZ + $1A)
            ld e, a
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl]
            ld [de], a
            ld hl, BZ + $22
            inc [hl]
            jr .kn
.nk:        ld a, [BZ + $19]
            add low(BZ + $1A)
            ld l, a
            ld h, high(BZ)
            xor a
            ld [hl+], a
            ld [hl], a
.kn:        ld hl, BZ + $52
            inc [hl]
            ld a, [hl]
            cp 4
            jr nz, .k
            ld a, [BZ + $22]
            and a
            jp z, .go
            call fe_A30F
            ld a, [BZ + $52]
            ld b, a
            xor a
            call b_setbit
            ld [$DE99], a
            ld [$DEDF], a
            ld a, [BZ + $18]
            ld b, a
            xor a
            call b_setbit
            ld [$DEE0], a
            ld a, [BZ + $5F]
            add low(B_CH)
            ld [BZ + $70], a
            ld a, 0
            adc high(B_CH)
            ld [BZ + $71], a
            %LDZ $70, $33
            ld [$DCEA], a
            and $FE
            ld [hl], a
            jr .go
.chr:       push af                         ; a character: the weapons for the swing
            %LDZ $6E, 1
            and $28
            jr z, .w
            pop af
            xor a
            ld [$DE1F], a
            ld [$DE20], a
            jr .go
.w:         pop af
            and 7
            ld [BZ + $52], a
            call b_choff
            add 3
            ld c, a
            call p59
            ld a, [hl+]
            ld [$DE1F], a
            inc hl
            ld a, [hl]
            ld [$DE20], a
            ld a, [$DE1F]
            and a
            jr z, .w1
            cp $58
            jr c, .w2
            xor a
            ld [$DE1F], a
            jr .w2
.w1:        ld a, [$DE20]
            cp $4A
            jr c, .go
            xor a
            ld [$DE20], a
            jr .go
.w2:        ld a, [$DE20]
            and a
            jr z, .w3
            cp $58
            jr c, .go
            xor a
            ld [$DE20], a
            jr .go
.w3:        ld a, [$DE1F]
            cp $4A
            jr c, .go
            xor a
            ld [$DE1F], a
.go:        call x_9E8A
            ld a, [$DEDF]
            and a
            jr z, .hits
            ld a, $52                       ; "Knight guards ally"
            call msg_set
            ld a, [$DCEA]
            %STZ $70, $33
.hits:      ld a, [BZ + $7C]                ; hits shown (max 32)
            ld hl, BZ + $7D
            add [hl]
            cp $21
            jr c, .h
            ld a, $20
.h:         ld [$D8D7], a
            and a
            jp z, .dead
            ld c, 1                         ; asleep / confused targets wake (status 2 $18)
            call st_t
            dec hl
            bit 7, [hl]
            inc hl
            jp nz, .dead
            ld a, [hl]
            and $18
            jp z, .dead
            sub 8
            and $18
            jr nz, .dec
            ld a, [hl]
            push af
            and 7
            ld [hl], a
            push hl
            %STZ $70, 2
            pop hl
            push hl
            %LDZ $6E, $2C
            and $87
            ld [BZ + $18], a
            %LDZ $70, $2C
            and $87
            ld e, a
            ld a, [BZ + $18]
            cp e
            pop hl
            jr nz, .nself
            ld a, [hl]
            push af
            ld c, 1
            call st_a
            pop af
            ld [hl], a
            %STZ $6E, 2
.nself:     pop af
            ld b, 0
.f:         add a
            jr c, .fd
            inc b
            jr .f
.fd:        ld a, b
            add 2
            ld [$D8D9], a
            %LDZ $70, $2C
            and $E7
            ld [hl], a
            xor a
            %STZ $70, $2E
            jr .dead
.dec:       ld a, [hl]
            sub 8
            ld [hl], a
            %STZ $70, 2
.dead:      ld c, 0
            call st_t
            bit 7, [hl]
            jr z, .ar
            call msg_at                     ; "Slain" / "Defeated"
            ld [hl], $1A
            push hl
            %LDZ $70, $2C
            pop hl
            bit 7, a
            jr z, .ar
            inc [hl]
.ar:        xor a
            ld [$D8D5], a
            ld [BZ + $24], a
            call b_aflags
            bit 7, a
            ret nz
            and 7                           ; arrows / shuriken used up
            ld [BZ + $52], a
            call b_choff
            add $31
            ld c, a
            call p5b
            ld a, [hl]
            and 4
            jr z, .a1
            push bc
            ld a, 4
            call fe_A353
            pop bc
.a1:        inc c
            call p5b
            ld a, [hl]
            and 4
            jr z, .a2
            ld a, 6
            call fe_A353
.a2:        ld a, [BZ + $5F]
            add 3
            ld c, a
            call p59
            ld a, [hl]
            cp $41
            jr nz, .a3
            ld a, 4
            call fe_A353
.a3:        ld a, 5
            call b_addoff
            ld c, a
            call p59
            ld a, [hl]
            cp $41
            jr nz, .a4
            ld a, 6
            call fe_A353
.a4:        ld a, [BZ + $24]
            and a
            ret z
            jp x_AA16

; $A30F find highest hp value ($1A + 2i, with $24 + 2i alongside): A = X = that character
fe_A30F:    ld b, 2                         ; (sorts the four so the highest ends first)
.o:         ld a, [BZ + $1A]
            ld c, a
            ld a, b
            add low(BZ + $1A)
            ld l, a
            ld h, high(BZ)
            ld a, c
            sub [hl]
            inc l
            ld a, [BZ + $1B]
            sbc [hl]
            jr nc, .n
            dec l
            ld e, l
            ld d, h
            ld hl, BZ + $1A
            ld a, [de]                      ; swap hp
            ld c, [hl]
            ld [hl+], a
            ld a, c
            ld [de], a
            inc e
            ld a, [de]
            ld c, [hl]
            ld [hl], a
            ld a, c
            ld [de], a
            ld a, b                         ; swap $24 and $24 + X
            add low(BZ + $24)
            ld e, a
            ld hl, BZ + $24
            ld a, [de]
            ld c, [hl]
            ld [hl], a
            ld a, c
            ld [de], a
.n:         inc b
            inc b
            ld a, b
            cp 8
            jr nz, .o
            ld a, [BZ + $24]
            srl a
            ld [BZ + $52], a
            jp b_choff

; $A353 one fewer arrow / shuriken (A = 4 right hand, 6 left); [BZ+$24] set when gone
fe_A353:    call b_addoff
            ld c, a
            call p59
            dec [hl]
            ret nz
            dec hl
            ld [hl], 0
            ld hl, BZ + $24
            inc [hl]
            ret

; ---- action $14: magic
fe_A367:    ld a, [BZ + $1A]
            push af
            push af
            call b_aflags
            and $10
            jr z, .sp
            ld a, [BZ + $1A]
            or $80
            ld [$D8D7], a
            jr .v
.sp:        pop af
            ld a, [BZ + $1A]
            sub $C8
            push af
            or $80
            ld [$D8D7], a
.v:         pop af
            cp 4
            jr z, .x
            cp $19
            jr z, .x
            cp $12
            jr z, .t
            cp $0B
            jr nz, .val
.t:         %LDZ $70, 1
            bit 7, a
            jr z, .x
.val:       call fe_A3D7
.x:         pop af
            ld [BZ + $1A], a
            ld a, 1
            ld [$D8D5], a
            ld a, [$D8D9]
            cp $FF
            jp z, x_AF77
            ld [$D8D7], a
            ld a, $FF
            ld [$D8D9], a
            jp x_AF77

; ---- action $13: item
fe_A3BB:    ld a, [BZ + $1A]
            push af
            cp $A9
            jr z, .x
            cp $AA
            jr nz, .val
            %LDZ $70, 1
            bit 7, a
            jr z, .x
.val:       call fe_A3D7
.x:         pop af
            ld [BZ + $1A], a
            ld hl, BZ + $CC
            inc [hl]
            jp x_A65E

; $A3D7 validate targets: dead / stone / jumping ones off $7E99
fe_A3D7:    xor a
            ld [BZ + $24], a
.t:         ld a, [$DE9A]
            and $40
            ld a, [BZ + $24]
            jr z, .c
            add 4
.c:         ld b, $40
            call b_mul
            ld a, [BZ + $1A]
            add low(B_CH)
            ld [BZ + $1A], a
            ld l, a
            ld a, [BZ + $1B]
            adc high(B_CH)
            ld [BZ + $1B], a
            ld h, a
            ld a, [BZ + $24]
            ld b, a
            ld a, [$DE99]
            push hl
            call b_chkbit
            pop hl
            jr z, .n
            inc hl
            ld a, [hl+]
            and $C0
            jr nz, .rm
            ld a, [hl]
            and 1
            jr z, .n
.rm:        ld a, [BZ + $24]
            ld b, a
            ld a, [$DE99]
            call b_clrbit
            ld [$DE99], a
.n:         ld hl, BZ + $24
            inc [hl]
            ld a, [hl]
            cp 8
            jr nz, .t
            ld a, [$DE99]
            ld [$DE9B], a
            jp b_aflags

; ---- $A458 check if battle is over: $78D3 $80 defeat / $40 victory
fe_A458:    ld a, [$D8D3]
            and 2
            ret nz
            xor a
            ld [BZ + $52], a
.c:         call b_choff
            inc a
            ld c, a
            call p5b
            ld a, [hl]
            and $C0
            jr z, .alive
            ld hl, BZ + $52
            inc [hl]
            ld a, [hl]
            cp 4
            jr nz, .c
            ld a, $80
            jr .s
.alive:     ld a, [$DDD2]
            and a
            ret nz
            ld a, $40
.s:         ld [$D8D3], a
            ret

; ---- $A487 init cannon blast (250-312 damage to each living monster)
fe_A487:    ld hl, $DE4F
            ld b, $20
            ld a, $FF
.z:         ld [hl+], a
            dec b
            jr nz, .z
            ld a, $15
            ld [$DEC2], a
            xor a
            ld [BZ + $47], a
            ld hl, BZ + $E0
            ld b, $20
.z2:        ld [hl+], a
            dec b
            jr nz, .z2
            ld a, low(B_MO)
            ld [BZ + $2C], a
            ld a, high(B_MO)
            ld [BZ + $2D], a
.m:         %LDZ $2C, 1
            bit 7, a
            jr nz, .n
            ld a, $3E
            call b_rnd
            add $FA
            ld [BZ + $24], a
            ld a, 0
            adc 0
            ld [BZ + $25], a
            ld a, [BZ + $47]
            add a
            ld e, a
            ld d, 0
            ld hl, $DE4F
            add hl, de
            ld a, [BZ + $24]
            ld [hl+], a
            ld a, [BZ + $25]
            ld [hl], a
            %PZ $2C, 3
            ld a, [BZ + $24]
            ld c, a
            ld a, [hl]
            sub c
            ld [hl+], a
            ld a, [BZ + $25]
            ld c, a
            ld a, [hl]
            sbc c
            ld [hl], a
            jr nc, .n
            %PZ $2C, 1
            ld [hl], $80
            ld a, [BZ + $47]
            add a
            add low(BZ + $E0)
            ld l, a
            ld h, high(BZ)
            ld [hl], $80
.n:         ld hl, BZ + $2C
            ld a, [hl]
            add $40
            ld [hl+], a
            ld a, [hl]
            adc 0
            ld [hl], a
            ld hl, BZ + $47
            inc [hl]
            ld a, [hl]
            cp 8
            jr nz, .m
            ld a, $40
            ld [$DE9A], a
            ret

; the algorithms in B_BAT, called from here
x_9E8A:     ld hl, fe_9E8A
            jp alg_call
x_AF77:     ld hl, fe_AF77
            jp alg_call
x_A65E:     ld hl, fe_A65E
            jp alg_call
x_AA16:     ld hl, fe_AA16
            jp alg_call

; ---- action $01: asleep / paralysed (wake up by chance)
fe_A68A:    call fe_91CE
            call b_aflags
            push af
            %LDZ $6E, 2
            push af
            call fa_st
            pop af
            ld [hl], a
            pop af
            bit 7, a
            jr nz, .mo
            %LDZ $6E, $2B                   ; sleep probability + 50
            add $32
            jr .r
.mo:        %LDZ $6E, 0                     ; level + 50
            add $32
.r:         ld [BZ + $24], a
            ld a, $64
            call b_rnd
            ld hl, BZ + $24
            cp [hl]
            jr nc, .stay
            call fa_st
            ld a, [hl]
            and $18
            sub 8
            and $18
            jr nz, .dec
            ld a, [hl]
            push af
            and 7
            ld [hl], a
            %STZ $6E, 2
            pop af
            ld b, 0
.f:         add a
            jr c, .fd
            inc b
            jr .f
.fd:        ld a, b
            add $54
            ld [$D8D7], a
            ret
.dec:       ld a, [hl]
            sub 8
            ld [hl], a
            %STZ $6E, 2
.stay:      call fa_st
            ld a, [hl]
            ld b, 0
.g:         add a
            jr c, .gd
            inc b
            jr nz, .g
.gd:        ld a, b
            add $5E
            ld [$D8D7], a
            ret
; HL = the attacker's status 2 in the buffer ($F0 + slot x 2 + 1, from its flags)
fa_st:      call b_aflags
            and 7
            add a
            inc a
            add low(BZ + $F0)
            ld l, a
            ld h, high(BZ)
            ret

; ---- actions $02 / $03: change to the front / back row
fe_A7DF:    ld a, $3B                       ; "Advance"
            jr fe_A7EA.go
fe_A7EA:    ld a, $3C                       ; "Fall back"
.go:        ld [$D8D7], a
            call fe_91CE
            ld a, 1
            ld [$D8D5], a
            %PZ $6E, $33
            ld a, [hl]
            xor 1
            ld [hl], a
            call b_aflags
            and 7
            ld [BZ + $52], a
            call b_choff
            add $0F
            ld c, a
            call p59
            ld a, [hl]
            xor 1
            ld [hl], a
            ret

; ---- action $05: defend (defence x 2, the old value in $7CE4)
fe_A881:    ld a, $3E                       ; "Defend"
            ld [$D8D7], a
            call fe_91CE
            ld a, 1
            ld [$D8D5], a
            %LDZ $6E, $23
            ld c, a
            call b_aflags
            and 7
            ld e, a
            ld d, 0
            ld hl, $DCE4
            add hl, de
            ld [hl], c
            ld a, c
            cp $80
            ld a, $FF
            jr nc, .s
            ld a, c
            add a
.s:         %STZ $6E, $23
            ret

; ---- action $06: run; $07: escape
fe_A8BF:    ld a, 1
            ld [$D8D5], a
            ld a, $3F                       ; "Run"
            ld [$D8D7], a
            call fe_91CE
            call b_aflags
            bit 7, a
            jp nz, fe_A978
            xor a                           ; the monsters' average level
            ld [BZ + $18], a
            ld [BZ + $19], a
            ld [BZ + $1A], a
            ld [BZ + $1B], a
            ld hl, B_MO
            ld de, $DDA7
            ld b, 8
.l:         ld a, [de]
            inc de
            cp $FF
            jr z, .n
            ld a, [BZ + $18]
            add [hl]
            ld [BZ + $18], a
            ld a, [BZ + $19]
            adc 0
            ld [BZ + $19], a
            ld a, [BZ + $1A]
            inc a
            ld [BZ + $1A], a
.n:         ld a, l
            add $40
            ld l, a
            ld a, h
            adc 0
            ld h, a
            dec b
            jr nz, .l
            call b_div16
            %LDZ $6E, $2A                   ; run probability + 25 - average level
            add $19
            ld hl, BZ + $1C
            sub [hl]
            jr nc, .p
            xor a
.p:         ld [BZ + $24], a
            ld a, $64
            call b_rnd
            ld hl, BZ + $24
            cp [hl]
            jr c, fe_A948
            ld a, [$D8BA]
            and 1
            jr nz, fe_A948
fe_A935:    ld a, $1F                       ; "Can't run"
            ld [$D8DA], a
            ret
fe_A93B:    ld a, 1
            ld [$D8D5], a
            ld a, $40                       ; "Escape"
            ld [$D8D7], a
            call fe_91CE
fe_A948:    ld a, [$DED8]
            and 1
            jr nz, fe_A935
            ld b, 0                         ; nobody confused ($52 = X, left at 3)
.c:         ld a, b
            ld [BZ + $52], a
            call b_choff
            add 2
            ld c, a
            call p5b
            bit 5, [hl]
            jr nz, fe_A935
            inc b
            ld a, b
            cp 4
            jr nz, .c
            ld a, $1E                       ; "Ran away..."
            ld [$D8DA], a
            ld a, 2
            ld [$D8D3], a
            ld a, $F0
            ld [$D8D4], a
            ret
; a monster runs (by its evasion)
fe_A978:    %LDZ $6E, $22
            ld [BZ + $24], a
            ld a, $64
            call b_rnd
            ld hl, BZ + $24
            cp [hl]
            jr c, .ok
            ld a, $1F
            ld [$D8DA], a
            ret
.ok:        ld a, $1E
            ld [$D8DA], a
            call b_aflags
            and 7
            push af
            add a
            add low(BZ + $F0)
            ld l, a
            ld h, high(BZ)
            set 7, [hl]
            pop af
            ld b, a
            xor a
            call b_setbit
            ld [$D8D4], a
            ret

; ---- action $08: jump 1; $09: jump 2
fe_A9D8:    ld a, 1
            ld [$D8D5], a
            ld a, $41                       ; "Jump"
            ld [$D8D7], a
            %LDZ $6E, 1
            and $28
            jr z, .j
            ld a, $18
            ld [$DEC2], a
            ld a, $3B                       ; "Ineffective"
            ld [$D8DA], a
            ret
.j:         ld a, 2
            %STZ $6E, $27
            call b_aflags
            and 7
            add a
            inc a
            add low(BZ + $F0)
            ld l, a
            ld h, high(BZ)
            set 0, [hl]
            ld a, 9
            %STZ $6E, $2E
            ret
fe_AA11:    %PZ $6E, 2
            res 0, [hl]
            ld a, 2
            %STZ $6E, $27
            jp x_9E8A

; ---- action $0B: terrain
fe_AA5D:    call b_aflags
            or $10
            ld [hl], a
            call fe_AAC3
            %STZ $6E, $2E
            ld [BZ + $1A], a
            call fe_A367
            ld hl, BZ + $CC
            inc [hl]
            ld a, $14
            ld [$DEC2], a
            ld a, [$DE9B]
            and a
            ret nz
            call b_aflags                   ; nothing hit: it backfires (max hp / 4)
            and 7
            add a
            ld [fe_x], a
            %PZ $6E, 5
            ld a, [hl+]
            ld [BZ + $18], a
            ld a, [hl]
            ld [BZ + $19], a
            ld hl, BZ + $19
            srl [hl]
            dec l
            rr [hl]
            inc l
            srl [hl]
            dec l
            rr [hl]
            %PZ $6E, 3
            ld a, [BZ + $18]
            ld c, a
            ld a, [hl]
            sub c
            ld [hl+], a
            ld a, [BZ + $19]
            ld c, a
            ld a, [hl]
            sbc c
            ld [hl], a
            jr nc, .al
            xor a
            ld [hl-], a
            ld [hl], a
            ld a, [fe_x]
            add low(BZ + $F0)
            ld l, a
            ld h, high(BZ)
            ld [hl], $80
.al:        ld a, [fe_x]
            ld e, a
            ld d, 0
            ld hl, $DE5F
            add hl, de
            ld a, [BZ + $18]
            ld [hl+], a
            ld a, [BZ + $19]
            ld [hl], a
            ld a, 3
            ld [BZ + $54], a
            ret
; $AAC3 the terrain's attack (01/A24E by map: low / high nibble by world)
fe_AAC3:    ld a, [$DCE3]
            cp 8
            jr c, .x
            cp $12
            jr nz, .m
            ld a, $55
            ret
.m:         ld a, [$D4C8]
            add $4E
            ld [BZ + $46], a
            ld a, $A2
            adc 0
            ld [BZ + $47], a
            ld a, 1
            ld [BZ + $4B], a
            ld a, $1A
            ld [BZ + $4A], a
            ld a, B_BDAT2
            call b_ldrom
            ld a, [$DED8]
            and 8
            ld a, [B_BUF]
            jr nz, .hi
            and $0F
            jr .x
.hi:        swap a
            and $0F
.x:         add $50
            ret

; ---- action $0D: scan; $0C: peep; $0E: steal
fe_AB0C:    call fe_AB66
            ld a, 1
            ld [$D8D5], a
            ld a, $46                       ; "Scan"
            ld [$D8D7], a
            %LDZ $70, 1
            bit 7, a
            jr z, .w
            ld a, $3B
            ld [$D8DA], a
            ret
.w:         %LDZ $70, $12                   ; weak elements -> messages (FF3: after the first
            ld b, 0                         ;   one found the loop shifts its counter, not the
            ld de, B_BUF                    ;   element byte)
.e:         add a
            jr nc, .ne
            ld a, b
            ld [de], a
            inc e
.ne:        inc b
            ld c, a
            ld a, b
            cp 7
            ld a, c
            jr nz, .e
            ld a, $FF
            ld [de], a
            ld b, 0
            ld a, [$D8EE]                   ; (every message to the same slot; the count on)
            add low($D8DA)
            ld e, a
            ld a, high($D8DA)
            adc 0
            ld d, a
            ld a, [B_BUF]
            bit 7, a
            jr z, .l
            dec b
            ld a, $43                       ; "No weak point found"
            jr .q
.l:         ld a, b
            add low(B_BUF)
            ld l, a
            ld h, high(B_BUF)
            ld a, [hl]
            cp $FF
            ret z
            add $48
.q:         ld [de], a
            ld hl, $D8EE
            inc [hl]
            inc b
            jr .l
fe_AB66:    ld a, $18
            ld [$DEC2], a
            ld hl, BZ + $CC
            inc [hl]
            ret
fe_AB73:    call fe_AB66
            %PZ $70, 3
            ld de, $D8E4
            ld b, 4
.c:         ld a, [hl+]
            ld [de], a
            inc e
            dec b
            jr nz, .c
            %LDZ $70, 1
            bit 7, a
            ld a, $3B
            jr nz, .s
            ld a, $3F
.s:         ld [$D8DA], a
            ld a, 1
            ld [$D8D5], a
            ld a, $45                       ; "Peep"
            ld [$D8D7], a
            ret
fe_ABA4:    call fe_AB66
            ld a, $47                       ; "Steal"
            ld [$D8D7], a
            ld a, 1
            ld [$D8D5], a
            %LDZ $70, $2C
            bit 7, a
            jr nz, .mo
.no:        ld a, $35                       ; "Can't steal"
            ld [$D8DA], a
            ret
.mo:        %LDZ $6E, 0                     ; (level + job level) / 256
            ld c, a
            %LDZ $6E, $0F
            add c
            ld [BZ + $24], a
            ld a, $FF
            call b_rnd
            ld hl, BZ + $24
            cp [hl]
            jr nc, .no
            %LDZ $70, 1
            and $E8
            jr nz, .no
            %LDZ $70, $36                   ; the monster's item set (10/9B80)
            and $1F
            ld [BZ + $18], a
            ld a, $80
            ld [BZ + $20], a
            ld a, $9B
            ld [BZ + $21], a
            ld a, 8
            ld [BZ + $1A], a
            ld b, 0
            ld a, B_EVENTS
            call b_ldarr
            ld a, $FF
            call b_rnd
            ld c, 0
            cp $30
            jr c, .it
            inc c
            cp $60
            jr c, .it
            inc c
            cp $90
            jr c, .it
            inc c
.it:        ld b, 0
            ld hl, B_BUF
            add hl, bc
            ld a, [hl]
            and a
            jr z, .no
            ld [BZ + $25], a
            ld a, [BZ + $25]                ; one more in the pack (max 99)
            ld c, a
            ld hl, $D0C0
            ld b, $20
.f3:        ld a, [hl+]
            cp c
            jr nz, .f4
            inc [hl]
            ld a, [hl]
            cp $64
            jr c, .got
            dec [hl]
            jr .no
.f4:        inc hl
            dec b
            jr nz, .f3
            ld hl, $D0C0                    ; a free slot
            ld b, $20
.f5:        ld a, [hl]
            and a
            jr z, .f6
            inc hl
            inc hl
            dec b
            jr nz, .f5
            jr .no
.f6:        ld a, c
            ld [hl+], a
            inc [hl]
.got:       ld a, [BZ + $25]
            ld [$D8E4], a
            ld a, $29                       ; "Found "
            ld [$D8DA], a
            ret

; ---- action $0F: buildup
fe_AC6F:    ld a, $48                       ; "BuildUp"
            ld [$D8D7], a
            ld a, 1
            ld [$D8D5], a
            %LDZ $6E, 1
            and $28
            jr nz, .tm
            %LDZ $6E, $27
            inc a
            cp 3
            jr c, .ok
            ld [hl], 0                      ; overload: hp / 2
            %PZ $6E, 3
            ld a, [hl+]
            ld [BZ + $18], a
            ld a, [hl]
            srl a
            ld [hl-], a
            ld a, [BZ + $18]
            rra
            ld [hl+], a
            or [hl]
            jr nz, .ov
            call b_aflags
            and 7
            add a
            add low(BZ + $F0)
            ld l, a
            ld h, high(BZ)
            set 7, [hl]
.ov:        ld a, 1
            ld [$DE93], a
            ld a, $2F                       ; "Overloaded!"
            ld [$D8DA], a
            ret
.ok:        ld [hl], a
            xor a
            ld [$DE93], a
            ret
.tm:        ld a, $3B
            ld [$D8DA], a
            ret

; ---- action $10: sing (a harp: fight)
fe_ACD5:    call b_aflags
            and 7
            ld [BZ + $52], a
            call b_choff
            add 3
            ld c, a
            call p59
            ld a, [hl]
            cp $46
            jr c, .l
            cp $4A
            jp c, fe_A104
.l:         inc hl
            inc hl
            ld a, [hl]
            cp $46
            jr c, .no
            cp $4A
            jp c, fe_A104
.no:        ld a, 1
            ld [$D8D5], a
            ld a, $42                       ; "Needs a harp!"
            ld [$D8DA], a
            ld a, $18
            ld [$DEC2], a
            ret

; ---- action $11: scare (FF3's loop sets every monster's level to the first one's - 3)
fe_AD16:    ld a, 1
            ld [$D8D5], a
            ld a, $4A                       ; "Scare"
            ld [$D8D7], a
            ld a, [$DED8]
            and 1
            jr z, .go
            ld a, $3B
            ld [$D8DA], a
            ret
.go:        ld a, 7
            ld [BZ + $25], a
            srl a
            ld [BZ + $24], a
            %LDZ $5D, 0
            ld hl, BZ + $24
            sub [hl]
            jr nc, .s
            xor a
.s:         ld [BZ + $24], a
.m:         ld a, [BZ + $24]
            %STZ $5D, 0
            ld hl, BZ + $5D
            ld a, [hl]
            add $40
            ld [hl+], a
            ld a, [hl]
            adc 0
            ld [hl], a
            ld hl, BZ + $25
            dec [hl]
            bit 7, [hl]
            jr z, .m
            ld a, low(B_MO)
            ld [BZ + $5D], a
            ld a, high(B_MO)
            ld [BZ + $5E], a
            ld a, $32                       ; "Scared the monsters"
            ld [$D8DA], a
            jp fe_91CE

; ---- action $12: cheer (attack + 10 for each character, max 255)
fe_AD75:    ld a, 1
            ld [$D8D5], a
            ld a, $4B                       ; "Cheer"
            ld [$D8D7], a
            ld a, $31                       ; "Roused the party!"
            ld [$D8DA], a
            ld hl, B_CH + $19
            ld b, 4
.c:         ld a, [hl]
            add $0A
            jr nc, .s
            ld a, $FF
            ld [$D8D8], a
.s:         ld [hl], a
            ld a, l
            add $40
            ld l, a
            ld a, h
            adc 0
            ld h, a
            dec b
            jr nz, .c
            ret
