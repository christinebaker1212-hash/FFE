; FF3's battle setup and choices (31/A400-31/AF76, 31/BEBF-31/BF52) as native code; memory as in
; batcore.s. ROM pointers in BZ ($24 here) keep their NES addresses (bank $30 data in B_BDAT).

section bank B_BAT, $6C00
; A = the byte at the NES ROM pointer [BZ+$24] + C (B_BDAT)
rom24:      ld a, [BZ + $24]
            add c
            ld l, a
            ld a, [BZ + $25]
            adc 0
            sub $40
            ld h, a
            ld a, B_BDAT
            jp far_byte

; ---- battle algorithm $01: init character / monster properties
fe_A400:    ld hl, B_CH                     ; 3 pages cleared
            ld bc, $300
.z:         xor a
            ld [hl+], a
            dec bc
            ld a, b
            or c
            jr nz, .z
            xor a
            ld [BZ + $52], a
.ch:        ld hl, BZ + $18                 ; $18-$4B cleared
            ld b, $34
            xor a
.cz:        ld [hl+], a
            dec b
            jr nz, .cz
            call fe_A482
            push af
            ld a, [BZ + $5F]                ; $18-$4B -> the record
            ld c, a
            %PZ $5B, 0
            ld a, l
            add c
            ld l, a
            ld a, h
            adc 0
            ld h, a
            ld de, BZ + $18
            ld b, $34
.cp:        ld a, [de]
            ld [hl+], a
            inc e
            dec b
            jr nz, .cp
            inc hl
            pop af
            ld [hl], a                      ; job experience modifiers (+$35)
            ld hl, BZ + $52
            inc [hl]
            ld a, [hl]
            cp 4
            jr nz, .ch
            xor a
            ld [BZ + $4B], a
.mo:        ld a, [BZ + $4B]
            ld e, a
            ld d, 0
            ld hl, $DDA7
            add hl, de
            ld a, [hl]
            cp $FF
            jr nz, .ld
            %PZ $5D, 1                      ; an empty slot: dead
            ld [hl], $80
            ld a, [BZ + $4B]
            or $80
            %STZ $5D, $2C
            ld a, [BZ + $4B]
            ld e, a
            ld d, 0
            ld hl, $DEC4
            add hl, de
            ld a, b
            ld [hl], a
            ld a, [BZ + $4B]                ; (FF3's LDX $4B sets Z: an empty slot 0 falls into
            and a                           ;   the load, type $80 at slot $2C: a record in
            jr nz, .nx                      ;   ROM, its writes lost)
            ld a, $80
            ld c, $2C
            call fe_A4F6
            jr .nx
.ld:        ld b, a
            ld a, [BZ + $4B]
            ld c, a
            ld a, b
            call fe_A4F6
.nx:        ld hl, BZ + $5D
            ld a, [hl]
            add $40
            ld [hl+], a
            ld a, [hl]
            adc 0
            ld [hl], a
            ld hl, BZ + $4B
            inc [hl]
            ld a, [hl]
            cp 8
            jr nz, .mo
            ld a, low(B_MO)
            ld [BZ + $5D], a
            ld a, high(B_MO)
            ld [BZ + $5E], a
            ret

; ---- $A482 load character properties ($18-$44); A = the job's experience modifiers
fe_A482:    call b_choff
            inc a
            ld c, a
            %PZ $57, 0
            ld a, l
            add c
            ld l, a
            ld a, h
            adc 0
            ld h, a
            ld a, [hl+]                     ; level, status
            ld [BZ + $18], a
            ld a, [hl]
            ld [BZ + $19], a
            ld a, $0C
            call b_addoff
            call .p57
            ld de, BZ + $1B                 ; hp (4)
            ld b, 4
.h:         ld a, [hl+]
            ld [de], a
            inc e
            dec b
            jr nz, .h
            ld a, [hl]                      ; job level
            ld [BZ + $27], a
            ld a, $30
            call b_addoff
            call .p57
            ld de, BZ + $1F                 ; mp (8, every second byte)
            ld b, 8
.m:         ld a, [hl+]
            ld [de], a
            inc hl
            inc e
            dec b
            jr nz, .m
            ld a, [BZ + $5F]
            call .p57
            ld a, [hl]                      ; job id x 5 + 39/BB1A
            ld c, a
            add a
            add a
            add c
            add $1A
            ld [BZ + $46], a
            ld a, 0
            adc $BB
            ld [BZ + $47], a
            ld a, 5
            ld [BZ + $4B], a
            ld a, $18
            ld [BZ + $4A], a
            ld a, B_BDAT3
            call b_ldrom
            ld hl, B_BUF
            ld de, BZ + $40
            ld b, 5
.j:         ld a, [hl+]
            ld [de], a
            inc e
            dec b
            jr nz, .j
            ld a, [BZ + $44]
            push af
            ld a, [BZ + $52]
            ld [BZ + $44], a
            xor a
            ld [BZ + $46], a
            ld [BZ + $47], a
            pop af
            ret
.p57:       ld c, a                         ; HL = [$57] + A
            %PZ $57, 0
            ld a, l
            add c
            ld l, a
            ld a, h
            adc 0
            ld h, a
            ret

; ---- $A4F6 load monster properties: A = the type, C = the slot
fe_A4F6:    ld e, a
            ld d, 0
            ld hl, $DD6B
            add hl, de
            ld a, [hl]
            ld [BZ + $26], a
            ld a, c
            ld [BZ + $27], a
fe_A4FE:    ld a, [BZ + $26]
            push af
            ld [BZ + $1A], a
            ld a, $10
            ld [BZ + $18], a
            xor a
            ld [BZ + $20], a
            ld a, $80
            ld [BZ + $21], a
            call b_calcp
            ld a, [BZ + $1C]
            ld [BZ + $24], a
            ld a, [BZ + $1D]
            ld [BZ + $25], a
            ld a, [BZ + $27]
            ld [BZ + $1A], a
            ld a, $40
            ld [BZ + $18], a
            ld a, low(B_MO)
            ld [BZ + $20], a
            ld a, high(B_MO)
            ld [BZ + $21], a
            call b_calcp
            ld a, [BZ + $1C]
            ld [BZ + $5D], a
            ld a, [BZ + $1D]
            ld [BZ + $5E], a
            ld a, [BZ + $27]
            or $80
            and $E7
            %STZ $5D, $2C
            ld c, 0                         ; level
            call rom24
            %STZ $5D, 0
            ld c, 1                         ; hp
            call rom24
            ld [BZ + $18], a
            ld c, 2
            call rom24
            ld [BZ + $19], a
            %PZ $5D, 3
            ld a, [BZ + $18]
            ld [hl+], a
            inc hl
            ld [hl-], a
            ld a, [BZ + $19]
            ld [hl+], a
            inc hl
            ld [hl], a
            ld c, 3                         ; special attack rate
            call rom24
            %STZ $5D, $37
            ld c, 4
            call rom24
            %STZ $5D, $0F
            ld a, 5
            ld [BZ + $4A], a
            ld a, $12                       ; magic defence, attack, defence sets
            ld [BZ + $49], a
            call fe_A614
            ld a, $16
            ld [BZ + $49], a
            call fe_A614
            ld a, $20
            ld [BZ + $49], a
            call fe_A614
            %LDZ $5D, $19                   ; +$29 = attack / 2, +$28 = 5
            srl a
            %STZ $5D, $29
            ld a, 5
            %STZ $5D, $28
            ld c, 7                         ; intellect x 6, spirit x 6
            call rom24
            push af
            and $0F
            add a
            ld c, a
            add a
            add c
            %STZ $5D, $10
            pop af
            and $F0
            srl a
            srl a
            ld c, a
            srl a
            add c
            %STZ $5D, $11
            ld c, $0E                       ; the special attack script (30/9200, 8 bytes)
            call rom24
            ld [BZ + $1A], a
            ld a, 8
            ld [BZ + $18], a
            xor a
            ld [BZ + $20], a
            ld a, $92
            ld [BZ + $21], a
            call b_calcp
            ld a, [BZ + $1C]
            ld l, a
            ld a, [BZ + $1D]
            sub $40
            ld h, a
            ld de, BZ + $26
            ld b, 8
.s:         push bc
            ld a, B_BDAT
            call far_byte
            ld [de], a
            inc e
            inc hl
            pop bc
            dec b
            jr nz, .s
            %PZ $5D, $38
            ld de, BZ + $26
            ld b, 8
.s2:        ld a, [de]
            ld [hl+], a
            inc e
            dec b
            jr nz, .s2
            ld c, $0F                       ; item set
            call rom24
            %STZ $5D, $36
            ld a, [BZ + $26]
            %STZ $5D, $35
            pop af
            cp $D2
            jr z, .bs
            cp $B4
            jr nz, .x
.bs:        %MOVZ $6E, $5D
            call fe_B57A
.x:         xor a
            %STZ $5D, 1
            ret

; $A614 load monster stat values: element, a 3-byte set (30/9000), status at [BZ+$49]
fe_A614:    ld a, [BZ + $4A]
            ld c, a
            call rom24
            ld hl, BZ + $4A
            inc [hl]
            ld b, a
            ld a, [BZ + $49]
            ld c, a
            ld a, b
            call .st5d
            ld hl, BZ + $49
            inc [hl]
            ld a, [BZ + $4A]
            ld c, a
            call rom24
            ld hl, BZ + $4A
            inc [hl]
            ld [BZ + $1A], a
            ld a, 3
            ld [BZ + $18], a
            xor a
            ld [BZ + $20], a
            ld a, $90
            ld [BZ + $21], a
            call b_calcp
            ld a, [BZ + $1C]
            ld l, a
            ld a, [BZ + $1D]
            sub $40
            ld h, a
            ld de, BZ + $18
            ld b, 3
.c:         push bc
            ld a, B_BDAT
            call far_byte
            ld [de], a
            inc e
            inc hl
            pop bc
            dec b
            jr nz, .c
            ld de, BZ + $18
            ld b, 3
.c2:        ld a, [BZ + $49]
            ld c, a
            ld a, [de]
            call .st5d
            ld hl, BZ + $49
            inc [hl]
            inc e
            dec b
            jr nz, .c2
            ld a, [BZ + $4A]
            ld c, a
            call rom24
            ld hl, BZ + $4A
            inc [hl]
            ld b, a
            ld a, [BZ + $49]
            ld c, a
            ld a, b
.st5d:      push de                         ; [[$5D] + C] = A
            push bc
            ld d, a
            %PZ $5D, 0
            ld a, l
            add c
            ld l, a
            ld a, h
            adc 0
            ld h, a
            ld [hl], d
            ld a, d
            pop bc
            pop de
            ret

; ---- battle algorithm $04: do item effect ($1A = the item)
fe_A65E:    ld a, 1
            ld [$D8D5], a
            ld a, $14
            ld [$DEC2], a
            ld a, 1
            ld [BZ + $72], a
            ld a, [BZ + $1A]
            ld [$D8D7], a
            cp $98
            jr nc, .itm
            ld b, 8                         ; a weapon / armour: its spell (30/9400 + 8 n, byte 4)
            call b_mul
            ld a, [BZ + $1A]
            add 4
            ld l, a
            ld a, [BZ + $1B]
            adc $94 - $40
            ld h, a
            ld a, B_BDAT
            call far_byte
            and $7F
            cp $7F
            jr z, .none
            ld [BZ + $1A], a
            ld a, 1
            jr .go
.itm:       cp $C8
            jr nc, .none
            sub $98                         ; 2E/91A0: the item's spell
            add $A0
            ld [BZ + $46], a
            ld a, 0
            adc $91
            ld [BZ + $47], a
            ld a, 1
            ld [BZ + $4B], a
            ld a, $18
            ld [BZ + $4A], a
            ld a, B_BDAT2
            call b_ldrom
            ld a, [B_BUF]
            ld [BZ + $1B], a
            cp $7F
            jr z, .none
            ld a, [$DED8]
            and $10
            jr z, .use
            ld a, [BZ + $1A]
            cp $AD
            jr z, .none
.use:       ld hl, $D0C0                    ; one fewer in the inventory
            ld a, [BZ + $1A]
            ld c, a
.f:         ld a, [hl+]
            cp c
            jr z, .fd
            inc hl
            ld a, l
            and a
            jr nz, .f
            dec h                           ; (FF3's X wraps inside one page)
            jr .f
.fd:        dec [hl]
            jr nz, .q
            dec hl
            ld [hl], 0
.q:         ld a, [BZ + $1B]
            ld [BZ + $1A], a
            ld a, [$D8D7]
            cp $A6
            jr nc, .mul
            xor a
            jr .go
.mul:       sub $A6                         ; 01/A35E: the item's multiplier
            add $5E
            ld [BZ + $46], a
            ld a, $A3
            adc 0
            ld [BZ + $47], a
            ld a, $18
            ld [BZ + $4A], a
            ld a, 1
            ld [BZ + $4B], a
            ld a, B_BDAT2
            call b_ldrom
            ld a, [B_BUF]
.go:        ld [BZ + $30], a
            ld [BZ + $7C], a
            jp fe_AF77
.none:      ld a, 1
            ld [$D8D5], a
            ld a, $18
            ld [$DEC2], a
            ld a, $51                       ; "Nothing happens"
            ld [$D8DA], a
            ret

; ---- battle algorithm $02: choose monster actions
fe_A732:    xor a
            ld [BZ + $4A], a
            ld [BZ + $69], a
.mo:        xor a
            ld [BZ + $53], a
            ld a, [BZ + $4A]
            ld [BZ + $18], a
            ld a, $40
            ld [BZ + $1A], a
            ld a, low(B_MO)
            ld [BZ + $20], a
            ld a, high(B_MO)
            ld [BZ + $21], a
            call b_calcp
            ld a, [BZ + $1C]
            ld [BZ + $24], a
            ld a, [BZ + $1D]
            ld [BZ + $25], a
            call m_flags
            and $EF
            ld [hl], a
            %PZ $24, $2F
            xor a
            ld [hl+], a
            ld [hl], a
            %LDZ $24, 1
            and $E8
            jr z, .alive
            xor a
            jp .set
.alive:     inc hl
            ld a, [hl]
            and $E0
            jr z, .norm
            and $20
            jr z, .slp
            ld hl, BZ + $53
            inc [hl]
            jr .who
.slp:       ld a, 1
            jp .set
.norm:      ld a, [$DED8]
            bit 7, a
            jr nz, .who
            ld de, BZ + $28                 ; the characters' levels, lowest first
            ld hl, B_CH
            ld b, 4
.lv:        ld a, [hl]
            ld [de], a
            inc e
            ld a, l
            add $40
            ld l, a
            ld a, h
            adc 0
            ld h, a
            dec b
            jr nz, .lv
            call fe_A8EC
            %LDZ $24, 0
            add $0F
            ld hl, BZ + $28
            cp [hl]
            jr nc, .who
            ld a, [$DED8]
            and 1
            jr nz, .who
            ld a, $64
            call b_rnd
            ld c, a
            %LDZ $24, $22
            ld b, a
            ld a, c
            cp b
            jr c, .who
            ld a, 6                         ; run
            jp .set
.who:       ld a, [BZ + $4A]
            ld e, a
            ld d, 0
            ld hl, $DDA7
            add hl, de
            ld e, [hl]
            ld hl, $DD6B
            add hl, de
            ld a, [hl]
            cp $D2
            jr z, .amon
            cp $B4
            jr nz, .spec
.amon:      ld a, [$DBE2]
            cp 2
            jr nz, .spec
            call m_flags
            or $10
            ld [hl], a
            ld a, $4D                       ; barrier shift
            jp .set
.spec:      %LDZ $24, $37
            and a
            jr z, .fight
            ld a, $64
            call b_rnd
            ld c, a
            %LDZ $24, $37
            ld b, a
            ld a, c
            cp b
            jr c, .sp
.fight:     ld a, [BZ + $53]
            and a
            jr z, .pick
            call fe_A8CD
            ld a, 4
            jp .set
.pick:      xor a                           ; a random living character
            ld hl, BZ + $65
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl], a
.p:         xor a
            ld [BZ + $21], a
            ld b, 0
            ld a, 3
            call b_rndx
            ld [BZ + $22], a
.p2:        ld a, 3
            call b_rnd
            ld hl, BZ + $22
            cp [hl]
            jr z, .p2
            ld [hl], a
            ld [BZ + $52], a
            call b_choff
            inc a
            ld c, a
            %PZ $5B, 0
            ld a, l
            add c
            ld l, a
            ld a, h
            adc 0
            ld h, a
            ld a, [hl+]
            and $C0
            jr nz, .bad
            ld a, [hl]
            and 1
            jr z, .good
.bad:       ld a, [BZ + $22]
            add low(BZ + $65)
            ld l, a
            ld h, high(BZ)
            ld [hl], 1
            ld a, [BZ + $65]
            ld hl, BZ + $66
            add [hl]
            inc l
            add [hl]
            inc l
            add [hl]
            cp 4
            jr nz, .p
            xor a
            jr .set
.good:      ld a, [BZ + $52]
            call fe_A8E1
            ld a, 4
            jr .set
.sp:        call m_flags                    ; a special attack
            or $10
            ld [hl], a
            ld a, [$DED8]
            bit 7, a
            jr z, .rnd
            ld a, [$D8B7]                   ; a boss: its script in order
            add $38 - 1
            ld c, a
            %PZ $24, 0
            ld a, l
            add c
            ld l, a
            ld a, h
            adc 0
            ld h, a
            ld a, [hl]
            push af
            and $7F
            ld [fe_x], a
            pop af
            call fe_A91B
            ld a, [BZ + $69]
            and a
            jr nz, .none
            ld hl, $D8B7
            inc [hl]
            ld a, [hl]
            cp 9
            jr nz, .b
            ld [hl], 1
.b:         ld a, [fe_x]
            jr .set
.rnd:       ld a, 7
            call b_rnd
            add $38
            ld c, a
            %PZ $24, 0
            ld a, l
            add c
            ld l, a
            ld a, h
            adc 0
            ld h, a
            ld a, [hl]
            push af
            and $7F
            ld [fe_x], a
            pop af
            call fe_A91B
            ld a, [BZ + $69]
            and a
            ld a, [fe_x]
            jr z, .set
.none:      call m_flags
            and $EF
            ld [hl], a
            xor a
.set:       %STZ $24, $2E
            ld hl, BZ + $4A
            inc [hl]
            ld a, [hl]
            cp 8
            jp nz, .mo
m_flags:    %LDZ $24, $2C
            ret

; $A8CD target a random monster; $A8E1 set target A
fe_A8CD:    %PZ $24, $30
            ld [hl], $80
.r:         ld a, 7
            call b_rnd
            ld e, a
            ld d, 0
            ld hl, $DDA7
            add hl, de
            ld a, [hl]
            cp $FF
            jr z, .r
            ld a, e
fe_A8E1:    ld b, a
            xor a
            call b_setbit
            %STZ $24, $2F
            ret

; $A8EC sort the characters' levels ($28-$2B) with $2C-$2F alongside, lowest first
fe_A8EC:    ld de, BZ + $28                 ; (Y)
.o:         ld l, e
            ld h, d
            inc l                           ; (X = Y + 1)
.i:         ld a, [de]
            cp [hl]
            jr c, .n
            ld b, a                         ; swap levels
            ld a, [hl]
            ld [de], a
            ld [hl], b
            set 2, e                        ; and $2C+
            set 2, l
            ld a, [de]
            ld b, a
            ld a, [hl]
            ld [de], a
            ld [hl], b
            res 2, e
            res 2, l
.n:         inc l
            ld a, l
            cp low(BZ + $2C)
            jr nz, .i
            inc e
            ld a, e
            cp low(BZ + $2B)
            jr nz, .o
            ret

; ---- $A91B choose target (monster special attack): A = the script byte
fe_A91B:    ld [BZ + $46], a
            and $7F
            ld [BZ + $18], a
            ld a, 8
            ld [BZ + $1A], a
            ld a, $C0
            ld [BZ + $20], a
            ld a, $98
            ld [BZ + $21], a
            ld b, 0
            ld a, B_BDAT
            call b_ldarr
            xor a
            ld hl, BZ + $62
            ld b, 8
.z:         ld [hl+], a
            dec b
            jr nz, .z
            ld a, [$D405]
            bit 7, a
            jp nz, .mon
            ld a, [BZ + $53]
            and a
            jp nz, .mon
            ld a, [$D405]
            and $40
            jr z, .one
.all:       ld [BZ + $63], a                ; every living character
.al:        ld a, [BZ + $64]
            call fe_A9F7
            jr nz, .an
            ld a, [BZ + $64]
            ld b, a
            ld a, [BZ + $62]
            call b_setbit
            ld [BZ + $62], a
.an:        ld hl, BZ + $64
            inc [hl]
            ld a, [hl]
            cp 4
            jr nz, .al
            ld a, [BZ + $62]
            and a
            jr nz, .f0
            ld hl, BZ + $69
            inc [hl]
.f0:        ld a, $F0
            ld [BZ + $62], a
            jp .tg
.one:       ld a, [BZ + $46]
            bit 7, a
            jr z, .r
            ld a, $40
            jr .all
.r:         ld a, 3
            call b_rnd
            ld [BZ + $22], a
.r2:        ld a, 3
            call b_rnd
            ld hl, BZ + $22
            cp [hl]
            jr z, .r2
            ld e, a
            add low(BZ + $65)
            ld l, a
            ld h, high(BZ)
            ld [hl], 1
            ld a, e
            push af
            call fe_A9F7
            jr z, .ok
            pop af
            ld a, [BZ + $65]
            ld hl, BZ + $66
            add [hl]
            inc l
            add [hl]
            inc l
            add [hl]
            cp 4
            jr nz, .one
            ld hl, BZ + $69
            inc [hl]
            jr .tg
.ok:        pop af
            ld b, a
            ld a, [BZ + $62]
            call b_setbit
            ld [BZ + $62], a
            jr .tg
.mon:       ld a, $80                       ; monsters (cures, or confused)
            ld [BZ + $63], a
            ld a, [$D405]
            and $40
            jr z, .m1
            ld hl, BZ + $63
            or [hl]
            ld [hl], a
            ld a, $FF
            ld [BZ + $62], a
            jr .tg
.m1:        ld a, $0C
            call b_rnd
            cp 4
            jr c, .m1
            ld [BZ + $22], a
            call fe_A9F7
            jr nz, .m1
            ld a, [BZ + $22]
            sub 4
            ld b, a
            ld a, [BZ + $62]
            call b_setbit
            ld [BZ + $62], a
.tg:        %PZ $24, $2F
            ld a, [BZ + $62]
            ld [hl+], a
            ld a, [BZ + $63]
            ld [hl], a
            ret

; $A9F7 validate target A (the character / record index): Z set when it can be targeted
fe_A9F7:    ld [BZ + $18], a
            ld a, $40
            ld [BZ + $1A], a
            ld a, low(B_CH)
            ld [BZ + $20], a
            ld a, high(B_CH)
            ld [BZ + $21], a
            call b_calcp
            ld a, [BZ + $1C]
            ld l, a
            ld a, [BZ + $1D]
            ld h, a
            inc hl
            ld a, [hl+]
            and $C0
            ret nz
            ld a, [hl]
            and 1
            ret

; ---- battle algorithm $06: choose random monster target (for the character in [BZ+$5F])
fe_A2E9:    ld a, low(B_MO)
            ld [BZ + $22], a
            ld a, high(B_MO)
            ld [BZ + $23], a
            ld a, [BZ + $5B]
            ld hl, BZ + $5F
            add [hl]
            ld [BZ + $6E], a
            ld a, [BZ + $5C]
            adc 0
            ld [BZ + $6F], a
            ld a, 7
            jp fe_A300

; ---- battle algorithm $08: consolidate inventory (via $7280 / $7380: our bank-2 copies)
fe_BEBF:    ld hl, INV_ID
            ld bc, $200
.z:         xor a
            ld [hl+], a
            dec bc
            ld a, b
            or c
            jr nz, .z
            ld de, $D0C0
            ld b, $20
.c:         ld a, [de]
            inc e
            ld l, a
            ld h, high(INV_ID)
            ld [hl], a
            inc h
            ld a, [de]
            inc e
            add [hl]
            cp $64
            jr c, .q
            ld a, $63
.q:         ld [hl], a
            dec b
            jr nz, .c
            ld hl, $D0C0
            ld b, $40
            xor a
.cl:        ld [hl+], a
            dec b
            jr nz, .cl
            ld de, $D0C0
            ld c, $FF
.s:         ld l, c
            ld h, high(INV_ID)
            ld a, [hl]
            and a
            jr z, .nx
            ld [de], a
            inc e
            inc h
            ld a, [hl]
            and a
            jr nz, .k
            dec e
            xor a
            ld [de], a
            jr .nx
.k:         ld [de], a
            inc e
.nx:        dec c
            jr nz, .s
            ret

; ---- battle algorithm $09: get confused attack (character [BZ+$52])
fe_BF17:    ld a, [BZ + $52]
            push af
.r:         ld a, 3
            call b_rnd
            ld [BZ + $26], a
            ld [BZ + $52], a
            call b_choff
            inc a
            ld c, a
            %PZ $5B, 0
            ld a, l
            add c
            ld l, a
            ld a, h
            adc 0
            ld h, a
            ld a, [hl+]
            and $C0
            jr nz, .r
            ld a, [hl]
            and 1
            jr nz, .r
            pop af
            ld [BZ + $52], a
            call b_choff
            add $2E
            ld c, a
            %PZ $5B, 0
            ld a, l
            add c
            ld l, a
            ld a, h
            adc 0
            ld h, a
            ld [hl], 4                      ; fight
            inc hl
            push hl
            ld a, [BZ + $26]
            ld b, a
            xor a
            call b_setbit
            pop hl
            ld [hl+], a
            ld [hl], 0
            ret

INV_ID     = $C600          ; (FF3's $7280 / $7380: in the field's map area during a battle)
