; ---- battle logic (FF3 banks $30 / $31 / $34 / $35) written for the GB, as FF3 does it. FF3's
; zero page lives at BZ, its pointers there hold GB addresses ($57 = $6100 -> GS + $100, $59 =
; $6200 -> GS + $200, $5B = $7575 / $5D = $7675 -> W7 + ...). X / Y of the 6502 code are kept in
; RAM or registers as each routine needs; (zp),y through zpy.

; 34/88E1: the character / monster pointers
ptr_init:   ld a, $57
            ld hl, GS + $100
            call zpset
            ld a, $59
            ld hl, GS + $200
            call zpset
            ld a, $5B
            ld hl, W7 + $7575
            call zpset
            ld a, $5D
            ld hl, W7 + $7675
            jp zpset

; 31/BE9D calculate pointer: $1C = $18 * $1A + ($20:$21) (sizes and indexes < 256)
calc_ptr:   xor a
            ld [BZ + $19], a
            ld [BZ + $1B], a
            call bmul16
            ld a, [BZ + $1C]
            ld l, a
            ld a, [BZ + $1D]
            ld h, a
            ld a, [BZ + $20]
            ld e, a
            ld a, [BZ + $21]
            ld d, a
            add hl, de
            ld a, l
            ld [BZ + $1C], a
            ld a, h
            ld [BZ + $1D], a
            ret

; ---- 34/9CE3 init characters / monsters (874D, 31/A400, 87BE, 9474, 9D06; the equipment
; update per member: btleq.s)
init_cm:    call cm_874D
            call init_props
            call cm_87BE
            call near_fatal
            call stat_disp_all
            xor a
.e:         ld [BZ + $52], a
            call beq_update
            ld a, [BZ + $52]
            inc a
            cp 4
            jr nz, .e
            xor a
            ld [BZ + $52], a
            ret

; 34/874D
cm_874D:    ld a, [W7 + $7CEF]
            ld [W7 + $7CE3], a
            call ptr_init
            ld a, $6E                       ; $5D / $6E = $7675
            ld hl, W7 + $7675
            call zpset
            xor a
            ld hl, W7 + $78F0
            ld b, $10
            call .clr
            ld hl, W7 + $7AC3
            ld b, 8
            call .clr
            ld hl, W7 + $78C9
            ld b, 6
            call .clr
            ld hl, W7 + $7EC4
            ld b, 8
            call .clr
            ld hl, W7 + $7CE4
            ld b, 4
            call .clr
            ld a, $FF
            ld [W7 + $7EE1], a
            ld [W7 + $7BE2], a
            ld [W7 + $78CF], a              ; 87AA: commands reset, $52-$54 = 0 (X = $FF + 1)
            ld [W7 + $78D0], a
            ld [W7 + $78D1], a
            ld [W7 + $78D2], a
            xor a
            ld [BZ + $52], a
            ld [BZ + $53], a
            ld [BZ + $54], a
            ld [W7 + $7BE1], a              ; (87AA leaves X = 0 for these)
            ld [W7 + $7CE8], a
            ld [W7 + $7CEC], a
            ld [W7 + $78D3], a
            ld [W7 + $78B7], a
            ld [BZ + $72], a
            ld [W7 + $7CEB], a
            ld [BZ + $54], a
            ret
.clr:       ld [hl+], a
            dec b
            jr nz, .clr
            ret

; ---- 31/A400 init character / monster properties
init_props: ld hl, W7 + $7575               ; clear $7575-$7874
            ld de, $300
            call memclr
            xor a
.c:         ld [BZ + $52], a
            ld hl, BZ + $18                 ; clear $18-$4B
            ld de, $34
            call memclr
            call load_chr                   ; -> A = job experience modifiers
            push af
            call chr_ofs
            ld c, a
            ld a, $5B
            call zpy
            ld d, h
            ld e, l
            ld hl, BZ + $18
            ld bc, $34
            call memcpy
            inc de
            pop af
            ld [de], a                      ; (+$35)
            ld a, [BZ + $52]
            inc a
            cp 4
            jr nz, .c
            xor a
.m:         ld [BZ + $4B], a
            ld e, a
            ld d, 0
            ld hl, W7 + $7DA7
            add hl, de
            ld a, [hl]
            cp $FF
            jr nz, .ld
            ld c, 1                         ; an empty slot: dead, slot | $80
            ld a, $5D
            call zpy
            ld [hl], $80
            ld c, $2C
            ld a, $5D
            call zpy
            ld a, [BZ + $4B]
            or $80
            ld [hl], a
            ld e, a
            ld a, [BZ + $4B]
            ld c, a
            ld b, 0
            ld hl, W7 + $7EC4
            add hl, bc
            ld [hl], e
            jr .nx
.ld:        ld c, a                         ; A = type, (Y = slot)
            ld a, [BZ + $4B]
            ld b, a
            ld a, c
            call load_mon
.nx:        ld a, $5D
            call zpadd40
            ld a, [BZ + $4B]
            inc a
            cp 8
            jr nz, .m
            ld a, $5D
            ld hl, W7 + $7675
            jp zpset

; 31/A482 load character properties into $18-$47; A = job experience modifiers
load_chr:   call chr_ofs
            inc a
            ld c, a
            ld a, $57
            call zpy
            ld a, [hl+]                     ; level, status
            ld [BZ + $18], a
            ld a, [hl]
            ld [BZ + $19], a
            ld a, [BZ + $5F]
            add a, $0C
            ld c, a
            ld a, $57
            call zpy
            ld de, BZ + $1B                 ; current / max hp
            ld b, 4
.h:         ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .h
            ld a, [hl]                      ; job level
            ld [BZ + $27], a
            ld a, [BZ + $5F]
            add a, $30
            ld c, a
            ld a, $57
            call zpy
            ld de, BZ + $1F                 ; mp (8, every other byte)
            ld b, 8
.p:         ld a, [hl+]
            ld [de], a
            inc de
            inc hl
            dec b
            jr nz, .p
            ld a, [BZ + $5F]
            ld c, a
            ld a, $57
            call zpy
            ld a, [hl]                      ; job -> 39/BB1A + 5 job -> $40-$44
            ld [BZ + $46], a
            ld l, a
            ld h, 0
            ld d, h
            ld e, l
            add hl, hl
            add hl, hl
            add hl, de
            ld de, JB_MODS
            add hl, de
            ld de, BZ + $40
            ld bc, 5
            ld a, JOB_BANK
            call rd_copy
            ld a, [BZ + $44]
            push af
            ld a, [BZ + $52]
            ld [BZ + $44], a                ; attacker flags = slot
            xor a
            ld [BZ + $46], a
            ld [BZ + $47], a
            pop af
            ret

; 31/A4F6 load monster properties: A = type, B = slot
load_mon:   ld e, a
            ld d, 0
            ld hl, W7 + $7D6B
            add hl, de
            ld a, [hl]
            ld [BZ + $26], a
            ld a, b
            ld [BZ + $27], a
            ld a, [BZ + $26]
            push af
            ld l, a                         ; $24 = 30/8000 + 16 id (-> BDATA2)
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, BD2_MON
            add hl, de
            ld de, mon_rec
            ld bc, 16
            ld a, BDATA2_BANK
            call rd_copy
            ld a, [BZ + $27]                ; $5D = $7675 + $40 slot
            rrca
            rrca
            ld l, a
            and $C0
            ld e, a
            ld a, l
            and 3
            ld d, a
            ld hl, W7 + $7675
            add hl, de
            ld a, $5D
            call zpset
            ld a, [BZ + $27]
            or $80
            and $E7
            ld c, $2C
            push af
            ld a, $5D
            call zpy
            pop af
            ld [hl], a                      ; slot
            ld c, 0
            ld a, $5D
            call zpy
            ld a, [mon_rec]                 ; level
            ld [hl], a
            ld a, [mon_rec + 1]             ; hp -> +3 / +5, hi +4 / +6
            ld [BZ + $18], a
            ld a, [mon_rec + 2]
            ld [BZ + $19], a
            inc hl
            inc hl
            inc hl
            ld a, [BZ + $18]
            ld [hl+], a
            ld a, [BZ + $19]
            ld [hl+], a
            ld a, [BZ + $18]
            ld [hl+], a
            ld a, [BZ + $19]
            ld [hl], a
            ld c, $37                       ; special attack rate
            ld a, $5D
            call zpy
            ld a, [mon_rec + 3]
            ld [hl], a
            ld c, $0F                       ; job level
            ld a, $5D
            call zpy
            ld a, [mon_rec + 4]
            ld [hl], a
            ld a, 5
            ld [BZ + $4A], a
            ld a, $12                       ; magic defence stats
            ld [BZ + $49], a
            call mon_stats
            ld a, $16                       ; attack stats
            ld [BZ + $49], a
            call mon_stats
            ld a, $20                       ; defence stats
            ld [BZ + $49], a
            call mon_stats
            ld c, $19                       ; strength = attack power / 2 -> +$29; +$28 = 5
            ld a, $5D
            call zpy
            ld a, [hl]
            srl a
            ld c, $29
            push af
            ld a, $5D
            call zpy
            pop af
            ld [hl-], a
            ld [hl], 5
            ld a, [mon_rec + 7]             ; intellect = (lo) * 6 -> +$10, spirit -> +$11
            push af
            and $0F
            add a, a
            ld b, a
            add a, a
            add a, b
            ld c, $10
            push af
            ld a, $5D
            call zpy
            pop af
            ld [hl+], a
            pop af
            and $F0
            srl a                           ; (hi >> 2) + (hi >> 3)
            srl a
            ld b, a
            srl a
            add a, b
            ld [hl], a
            ld a, [mon_rec + $0E]           ; special attack script: 30/9200 + 8 id -> +$38
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, BD2_SPEC
            add hl, de
            ld de, BZ + $26
            ld bc, 8
            ld a, BDATA2_BANK
            call rd_copy
            ld c, $38
            ld a, $5D
            call zpy
            ld d, h
            ld e, l
            ld hl, BZ + $26
            ld bc, 8
            call memcpy
            ld c, $36                       ; item set -> +$36, +$35 = script byte 0
            ld a, $5D
            call zpy
            ld a, [mon_rec + $0F]
            ld [hl-], a
            ld a, [BZ + $26]
            ld [hl], a
            pop af                          ; (monster id) $D2 / $B4: random weak element
            cp $D2
            jr z, .s
            cp $B4
            jr nz, .x
.s:         ld a, [BZ + $5D]
            ld [BZ + $6E], a
            ld a, [BZ + $5E]
            ld [BZ + $6F], a
            call mon_b57a
.x:         ld c, 1
            ld a, $5D
            call zpy
            ld [hl], 0
            ret

; 31/A614 load monster stat values: element (+$49), the stat set's 3 bytes, status
mon_stats:  ld a, [BZ + $4A]
            ld e, a
            ld d, 0
            ld hl, mon_rec
            add hl, de
            ld a, [hl+]                     ; element
            push hl
            push af
            ld a, [BZ + $49]
            ld c, a
            ld a, $5D
            call zpy
            pop af
            ld [hl], a
            ld hl, BZ + $49
            inc [hl]
            pop hl
            ld a, [hl]                      ; stat set -> 30/9000 + 3 index
            ld e, a
            ld d, 0
            ld h, d
            ld l, e
            add hl, hl
            add hl, de
            ld de, BD2_STAT
            add hl, de
            ld de, BZ + $18
            ld bc, 3
            ld a, BDATA2_BANK
            call rd_copy
            ld a, [BZ + $49]
            ld c, a
            ld a, $5D
            call zpy
            ld a, [BZ + $18]
            ld [hl+], a
            ld a, [BZ + $19]
            ld [hl+], a
            ld a, [BZ + $1A]
            ld [hl+], a
            ld a, [BZ + $49]
            add a, 3
            ld [BZ + $49], a
            ld a, [BZ + $4A]                ; status (the record's next byte after the set)
            add a, 2
            ld [BZ + $4A], a
            ld e, a
            ld d, 0
            ld hl, mon_rec
            add hl, de
            ld a, [hl]
            push af
            ld hl, BZ + $4A
            inc [hl]
            ld a, [BZ + $49]
            ld c, a
            ld a, $5D
            call zpy
            pop af
            ld [hl], a
            ret

; 31/B57A: a random weak element ($12) and the rest strong ($20) for the monsters that change
mon_b57a:   ld a, 1
            ld [BZ + $21], a
            ld b, 3
            ld a, 5
            call rnd_xa
            ld [BZ + $24], a
.r:         ld a, 1
            ld [BZ + $21], a
            ld b, 3
            ld a, 5
            call rnd_xa
            ld b, a
            ld a, [BZ + $24]
            cp b
            jr z, .r
            ld a, b
            call bitmask                    ; A = $80 >> B
            ld c, $12
            push af
            ld a, $6E
            call zpy
            pop af
            ld [hl], a
            cpl
            ld c, $20
            push af
            ld a, $6E
            call zpy
            pop af
            ld [hl], a
            ret
; ---- 34/87BE: flags, strike first / ambush / back attack (FF3's level contest)
cm_87BE:    ld a, [W7 + $7ED8]
            and $BF
            ld [W7 + $7ED8], a
            ld a, [W7 + $7CEE]
            and a
            jr z, .a
            ld a, [W7 + $7ED8]
            or $10
            ld [W7 + $7ED8], a
.a:         ld a, [W7 + $74C6]              ; (the vehicle: the Invincible enables the cannon)
            cp 7
            jr nz, .b
            ld a, [W7 + $7ED8]
            or $40
            ld [W7 + $7ED8], a
.b:         ld a, [W7 + $7ED8]
            and 2
            jr z, .c
            ld hl, W7 + $78B7
            inc [hl]
.c:         ld a, [W7 + $7ED8]              ; rotate the flags right by one (bit 0 -> bit 7)
            rrca
            ld [W7 + $7ED8], a
            ld a, [BZ + $5B]
            ld [BZ + $24], a
            ld a, [BZ + $5C]
            ld [BZ + $25], a
            xor a
            ld [BZ + $2A], a
            ld [BZ + $2B], a
            ld [W7 + $78C3], a
            ld [W7 + $78BA], a
            ld a, [W7 + $7ED8]
            bit 7, a
            ret nz                          ; (a boss battle)
            and $20
            ret nz                          ; (the Invincible)
            ld a, 4
            ld [BZ + $26], a
            call avg_lvl
            ld [BZ + $28], a
            ld a, 100
            call rnd_0a
            ld b, a
            ld a, [BZ + $28]
            ld c, a
            ld a, b
            cp c
            jr nc, .d
            ld hl, BZ + $2A
            inc [hl]
.d:         ld a, $24
            ld hl, W7 + $7675
            call zpset
            ld a, 8
            ld [BZ + $26], a
            call avg_lvl
            ld [BZ + $29], a
            ld a, 100
            call rnd_0a
            ld b, a
            ld a, [BZ + $29]
            ld c, a
            ld a, b
            cp c
            jr nc, .e
            ld hl, BZ + $2B
            inc [hl]
.e:         ld hl, BZ + $2A
            inc [hl]
            ld hl, BZ + $2B
            inc [hl]
            ld a, [BZ + $2A]
            ld b, a
            ld a, [BZ + $2B]
            cp b
            ret z
            jr nc, .mon
            ld hl, W7 + $78BA               ; characters strike first
            inc [hl]
            ret
.mon:       ld a, [BZ + $29]                ; ambush / back attack
            srl a
            srl a
            ld [BZ + $29], a
            ld a, [BZ + $28]
            call rnd_0a
            ld b, a
            ld a, [BZ + $29]
            ld c, a
            ld a, b
            cp c
            jr c, .back
            ld a, $80
            jr .set
.back:      call row_toggle
            ld a, $88
.set:       ld [W7 + $78C3], a
            ld [W7 + $78BA], a
            ret

; 34/886F: the average level of the $26 records from pointer $24 (a level of 0 not counted)
avg_lvl:    xor a
            ld [BZ + $18], a
            ld [BZ + $19], a
            ld [BZ + $1A], a
            ld [BZ + $1B], a
            ld a, [BZ + $24]
            ld l, a
            ld a, [BZ + $25]
            ld h, a
            ld a, [BZ + $26]
            ld b, a
.l:         ld a, [hl]
            and a
            jr z, .n
            push hl
            ld hl, BZ + $18
            add a, [hl]
            ld [hl+], a
            jr nc, .k
            inc [hl]
.k:         ld hl, BZ + $1A
            inc [hl]
            pop hl
.n:         ld de, $40
            add hl, de
            dec b
            jr nz, .l
            ld a, l
            ld [BZ + $24], a
            ld a, h
            ld [BZ + $25], a
            call bdiv16
            ld a, [BZ + $1C]
            ret

; 34/88A4: every member's row toggled ($620F bit 0, $7D8F)
row_toggle: ld hl, GS + $20F
            ld de, W7 + $7D8F
            ld b, 4
.l:         ld a, [hl]
            xor 1
            ld [hl], a
            and 1
            ld [de], a
            inc de
            ld a, l
            add a, $40
            ld l, a
            dec b
            jr nz, .l
            ret

; ---- 34/9474 update near fatal (hp <= max / 4) for the four members
near_fatal: xor a
.m:         ld [BZ + $52], a
            call chr_ofs
            inc a
            ld c, a
            ld a, $5B
            call zpy
            ld a, [hl]
            bit 7, a
            jr nz, .n                       ; (dead)
            inc hl
            inc hl
            ld a, [hl+]                     ; hp
            ld e, a
            ld a, [hl+]
            ld d, a
            ld a, [hl+]                     ; max / 4
            ld c, a
            ld a, [hl]
            ld b, a
            srl b
            rr c
            srl b
            rr c
            ld a, c                         ; max / 4 - hp: no borrow -> near fatal
            sub e
            ld a, b
            sbc d
            push af
            call chr_ofs
            inc a
            ld c, a
            ld a, $5B
            call zpy
            pop af
            jr c, .clr
            set 0, [hl]
            ld a, [BZ + $52]
            call bitmask
            ld b, a
            ld a, [W7 + $7CEC]
            or b
            ld [W7 + $7CEC], a
            jr .n
.clr:       res 0, [hl]
            ld a, [BZ + $52]
            call bitmask
            cpl
            ld b, a
            ld a, [W7 + $7CEC]
            and b
            ld [W7 + $7CEC], a
.n:         ld a, [BZ + $52]
            inc a
            cp 4
            jr nz, .m
            ret


; 34/9D06 / 9D1D update character status for display: $78BB + 2 m (graphics), $78C4 + m (the
; first status to name in the hp window, $FF none)
stat_disp_all:
            xor a
.m:         ld [BZ + $52], a
            call chr_ofs
            call stat_disp
            ld a, [BZ + $52]
            inc a
            cp 4
            jr nz, .m
            xor a
            ld [BZ + $52], a
            ret
stat_disp:  ld a, [BZ + $5F]
            inc a
            ld c, a
            ld a, $5B
            call zpy
            ld a, [hl+]                     ; status 1
            ld [BZ + $1C], a
            ld d, a
            and $C0
            ld [BZ + $1A], a
            ld a, [hl]                      ; status 2
            ld [BZ + $1D], a
            and $E0
            srl a
            srl a
            ld hl, BZ + $1A
            or [hl]
            ld [hl], a
            xor a
            ld [BZ + $1B], a
            ld a, d                         ; the low 3 bits of (status 1 and $3F) into $1B's top
            and $3F
            ld e, 3
.r:         srl a
            ld hl, BZ + $1B
            rr [hl]
            dec e
            jr nz, .r
            ld hl, BZ + $1A
            or [hl]
            ld [hl], a
            ld a, [BZ + $52]
            add a, a
            ld e, a
            ld d, 0
            ld hl, W7 + $78BB
            add hl, de
            ld a, [BZ + $1A]
            ld [hl+], a
            ld a, [BZ + $1B]
            ld [hl], a
            ld a, [BZ + $1C]
            and $C0
            jr nz, .none
            ld a, [BZ + $1C]
            and $10
            srl a
            ld b, a
            ld a, [BZ + $1C]
            and 7
            or b
            add a, a
            ld b, a
            ld a, [BZ + $1D]
            and $E0
            or b
            ld b, a
            ld a, [BZ + $1D]
            and 6
            jr z, .k
            set 0, b
.k:         ld a, b
            ld [BZ + $1C], a
            ld c, 0
            and a
            jr z, .none
.f:         add a, a
            jr c, .st
            inc c
            ld b, a
            ld a, c
            cp 8
            ret z
            ld a, b
            jr .f
.none:      ld c, $FF
.st:        ld a, [BZ + $52]
            ld e, a
            ld d, 0
            ld hl, W7 + $78C4
            add hl, de
            ld [hl], c
            ret

section wram, $DFC0
mon_rec:    ds 16
