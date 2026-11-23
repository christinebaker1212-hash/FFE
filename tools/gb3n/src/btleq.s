; ---- 31/AA16 battle algorithm $05: update character equipment (member $52): the hands' types
; ($48 / $49: 1 weapon, 2 bow, 4 arrow, 8 harp, $80 shield), the items' properties (30/9400 + 8
; id -> $7400 + 8 n), stat bonuses (+5 each, capped at 99), attack / hit / defence / evasion /
; magic values into $34-$47 -> character properties +$12-$25 and $6100 + $1C-$2F, as FF3 does
; (its quirks kept: the element boosts cleared at 31/AF16, the discarded hit-count work).

beq_update:  call chr_ofs
            ld c, a
            ld a, $59
            call zpy
            ld de, W7 + $742F               ; equipment -> $742F.. and $24..
            ld b, 6
            push hl
.cp:        ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .cp
            pop hl
            ld de, BZ + $24
            ld bc, 6
            call memcpy
            ld hl, BZ + $24                 ; no armour piece -> $57
            ld b, 3
.na:        ld a, [hl]
            and a
            jr nz, .nn
            ld [hl], $57
.nn:        inc hl
            dec b
            jr nz, .na
            ld a, [BZ + $29]                ; arrows
            ld [W7 + $7433], a
            ld [BZ + $28], a
            xor a
            ld [BZ + $48], a
            ld [BZ + $49], a
            ld a, [BZ + $27]
            ld b, a
            ld a, [BZ + $28]
            or b
            ld a, 0
            jp z, .typ                      ; (unarmed)
            ld a, [BZ + $27]
            and a
            jr nz, .rh
            ld a, [BZ + $28]                ; left hand only
            cp $46
            jr nc, .l1
            ld a, 1
            ld [BZ + $49], a
            ld a, 2
            jp .typ
.l1:        cp $4A
            jr nc, .l2
            ld a, 8
            ld [BZ + $49], a
            ld a, 4
            jp .typ
.l2:        cp $4F
            jr nc, .l3
            xor a                           ; (a bow without an arrow)
            ld [BZ + $28], a
            ld a, 2
            jp .typ
.l3:        cp $58
            jr nc, .l4
            xor a                           ; (an arrow without a bow)
            ld [BZ + $28], a
            ld a, 2
            jp .typ
.l4:        ld a, $80
            ld [BZ + $49], a
            ld a, 2
            jp .typ
.rh:        cp $46                          ; right hand
            jr nc, .r1
            ld a, 1
            ld [BZ + $48], a
            ld a, [BZ + $28]
            and a
            jr z, .r0
            cp $58
            jr nc, .rs
            ld a, 1
            ld [BZ + $49], a
            jr .r0
.rs:        ld a, $80
            ld [BZ + $49], a
.r0:        ld a, 2
            jr .typ
.r1:        cp $4A
            jr nc, .r2
            ld a, 8
            ld [BZ + $48], a
            ld a, 4
            jr .typ
.r2:        cp $4F
            jr nc, .r3
            ld a, [BZ + $28]
            and a
            jr z, .r2n
            ld a, 2
            ld [BZ + $48], a
            ld a, 4
            ld [BZ + $49], a
            ld a, 6
            jr .typ
.r2n:       xor a
            ld [BZ + $27], a
            ld a, 2
            jr .typ
.r3:        cp $58
            jr nc, .r4
            ld a, [BZ + $28]
            and a
            jr z, .r3n
            ld a, 4
            ld [BZ + $48], a
            ld a, 2
            ld [BZ + $49], a
            ld a, 6
            jr .typ
.r3n:       xor a
            ld [BZ + $27], a
            ld a, 2
            jr .typ
.r4:        ld a, $80
            ld [BZ + $48], a
            ld a, [BZ + $28]
            and a
            jr z, .r4n
            cp $58
            jr nc, .r4s
            ld a, 1
            ld [BZ + $49], a
            jr .r4n
.r4s:       ld a, $80
            ld [BZ + $49], a
.r4n:       ld a, 2
.typ:       push af                         ; (the weapon type, later $32)
            xor a                           ; the five items' properties -> $7400 + 8 n
.it:        ld [W7 + $7570], a
            ld e, a
            ld d, 0
            ld hl, BZ + $24
            add hl, de
            ld l, [hl]
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, BD2_ITEM
            add hl, de
            ld a, [W7 + $7570]
            add a, a
            add a, a
            add a, a
            ld e, a
            ld d, 0
            push hl
            ld hl, EQ_P
            add hl, de
            ld d, h
            ld e, l
            pop hl
            ld bc, 8
            ld a, BDATA2_BANK
            call rd_copy
            ld a, [W7 + $7570]
            inc a
            cp 5
            jr nz, .it
            ld hl, BZ + $34                 ; clear $34-$47
            ld de, $14
            call memclr
            ld a, [EQ_P + $06]              ; element boosts: the five items' byte 6 and 7 << 5
            ld b, a
            ld a, [EQ_P + $0E]
            or b
            ld b, a
            ld a, [EQ_P + $16]
            or b
            ld b, a
            ld a, [EQ_P + $1E]
            or b
            ld b, a
            ld a, [EQ_P + $26]
            or b
            and 7
            swap a
            add a, a
            ld [BZ + $24], a
            ld a, [BZ + $5F]
            add a, $0F
            ld c, a
            ld a, $59
            call zpy
            ld a, [hl]
            and $F9
            ld b, a
            ld a, [BZ + $24]
            or b
            ld [hl], a
            ld a, [BZ + $5F]                ; base stats ($6112-) -> $2C-$30
            add a, $12
            ld c, a
            ld a, $57
            call zpy
            ld de, BZ + $2C
            ld b, 5
.bs:        ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .bs
            ld a, [EQ_P + $06]
            call beq_bonus
            ld a, [EQ_P + $0E]
            call beq_bonus
            ld a, [EQ_P + $16]
            call beq_bonus
            ld a, [EQ_P + $1E]
            call beq_bonus
            ld a, [EQ_P + $26]
            call beq_bonus
            ld a, [BZ + $5F]                ; capped at 99 -> $6100 + $12.. and $7428..
            add a, $12
            ld c, a
            ld a, $57
            call zpy
            ld de, BZ + $2C
            ld bc, W7 + $7428
            ld a, 5
            ld [btl_n2], a
.cap:       ld a, [de]
            cp $63
            jr c, .c1
            ld a, $63
.c1:        ld [hl+], a
            ld [bc], a
            inc bc
            inc de
            ld a, [btl_n2]
            dec a
            ld [btl_n2], a
            jr nz, .cap
            pop af
            ld [BZ + $32], a
            ld a, [EQ_P + $1F]              ; attack elements (a $80 flag: none)
            bit 7, a
            ld a, 0
            jr nz, .e1
            ld a, [EQ_P + $18]
.e1:        ld [BZ + $38], a
            ld a, [EQ_P + $27]
            bit 7, a
            ld a, 0
            jr nz, .e2
            ld a, [EQ_P + $20]
.e2:        ld [BZ + $3D], a
            ld a, [BZ + $5F]                ; hit multiplier: level / 16 + agility / 16 + 1
            inc a
            ld c, a
            ld a, $57
            call zpy
            ld a, [hl]
            ld [W7 + $742E], a
            swap a
            and $0F
            ld b, a
            ld a, [W7 + $7429]
            swap a
            and $0F
            scf
            adc a, b
            ld [BZ + $39], a
            ld [BZ + $3E], a
            ld a, [BZ + $5F]
            add a, $10
            ld c, a
            ld a, $57
            call zpy
            ld a, [hl]                      ; job level / 4 -> $25, agility / 4 -> $24
            ld [W7 + $742D], a
            srl a
            srl a
            ld [BZ + $25], a
            ld a, [W7 + $7429]
            srl a
            srl a
            ld [BZ + $24], a
            ld a, [BZ + $32]
            and 6
            cp 6
            jr nz, .hit
            ld a, [BZ + $48]                ; bow and arrow: the bow's hit %
            and 2
            jr z, .hb
            ld a, [EQ_P + $19]
            and a
            jr nz, .hc
.hb:        ld a, [EQ_P + $21]
.hc:        call beq_hit
            ld [BZ + $3A], a
            xor a
            ld [BZ + $3F], a
            jr .atk
.hit:       ld a, [BZ + $48]
            bit 7, a
            ld a, 0
            jr nz, .h1
            ld a, [EQ_P + $19]
            call beq_hit
.h1:        ld [BZ + $3A], a
            ld a, [BZ + $49]
            bit 7, a
            ld a, 0
            jr nz, .h2
            ld a, [EQ_P + $21]
            call beq_hit
.h2:        ld [BZ + $3F], a
.atk:       ld a, [BZ + $5F]                ; the weapons' bonus attack -> +$38 / $39
            add a, $38
            ld c, a
            ld a, $5B
            call zpy
            ld a, [EQ_P + $1D]
            and $7F
            ld [hl+], a
            ld a, [EQ_P + $25]
            and $7F
            ld [hl], a
            ld a, [BZ + $5F]                ; monk / black belt unarmed
            ld c, a
            ld a, $57
            call zpy
            ld a, [hl]
            cp 2
            jr z, .mk
            cp $0D
            jr nz, .wp
.mk:        ld a, [BZ + $32]
            and 6
            jr nz, .wp
            ld a, [W7 + $7428]              ; strength / 4 + level * 3 / 2 + job level / 4 + 2
            srl a
            srl a
            ld [BZ + $24], a
            ld a, [W7 + $742E]
            srl a
            ld b, a
            ld a, [W7 + $742E]
            add a, b
            ld [BZ + $25], a
            ld a, [W7 + $742D]
            srl a
            srl a
            ld b, a
            ld a, [BZ + $24]
            add a, b
            ld b, a
            ld a, [BZ + $25]
            add a, b
            add a, 2
            ld [BZ + $3B], a
            ld [BZ + $40], a
            jp .ad3d
.wp:        ld a, [BZ + $32]
            and 6
            cp 6
            jr nz, .ws
            ld a, [BZ + $48]                ; bow and arrow: the arrow's attack + the bow's / 2
            and 4
            jr z, .wb
            ld a, [EQ_P + $1A]
            ld [BZ + $24], a
            ld a, [EQ_P + $22]
            srl a
            ld [BZ + $25], a
            jr .wc
.wb:        ld a, [EQ_P + $22]
            ld [BZ + $24], a
            ld a, [EQ_P + $1A]
            srl a
            ld [BZ + $25], a
.wc:        ld a, [W7 + $7428]
            srl a
            srl a
            ld b, a
            ld a, [BZ + $24]
            add a, b
            ld b, a
            ld a, [BZ + $25]
            add a, b
            ld [BZ + $3B], a
            xor a
            ld [BZ + $40], a
            jp .ad3d
.ws:        ld a, [BZ + $48]
            ld b, a
            ld a, [BZ + $49]
            or b
            jr nz, .w2
            ld a, [W7 + $7428]              ; unarmed: strength / 4 + right attack + job lv / 4
            srl a
            srl a
            ld b, a
            ld a, [EQ_P + $1A]
            add a, b
            ld b, a
            ld a, [BZ + $25]
            add a, b
            ld [BZ + $3B], a
            ld [BZ + $40], a
            jp .ad3d
.w2:        ld a, [BZ + $48]
            bit 7, a
            jr z, .w3
.w0:        xor a
            ld [BZ + $39], a
            ld [BZ + $3A], a
            ld [BZ + $3B], a
            jr .w4
.w3:        ld a, [BZ + $49]
            bit 7, a
            jr nz, .w3a
            ld a, [BZ + $48]
            and a
            jr z, .w0
.w3a:       ld a, [W7 + $7428]
            srl a
            srl a
            ld b, a
            ld a, [BZ + $25]
            add a, b
            ld b, a
            ld a, [EQ_P + $1A]
            add a, b
            ld [BZ + $3B], a
.w4:        ld a, [BZ + $49]
            bit 7, a
            jr z, .w5
.w6:        xor a
            ld [BZ + $3E], a
            ld [BZ + $3F], a
            ld [BZ + $40], a
            jr .ad3d
.w5:        ld a, [BZ + $48]
            bit 7, a
            jr nz, .w5a
            ld a, [BZ + $49]
            and a
            jr z, .w6
.w5a:       ld a, [W7 + $7428]
            srl a
            srl a
            ld b, a
            ld a, [BZ + $25]
            add a, b
            ld b, a
            ld a, [EQ_P + $22]
            add a, b
            ld [BZ + $40], a
.ad3d:      ld a, [BZ + $39]                ; no right hand values: the left hand's move over
            ld b, a
            ld a, [BZ + $3A]
            or b
            ld b, a
            ld a, [BZ + $3B]
            or b
            jr nz, .ad59
            ld a, [BZ + $3E]
            ld [BZ + $39], a
            ld a, [BZ + $3F]
            ld [BZ + $3A], a
            ld a, [BZ + $40]
            ld [BZ + $3B], a
            xor a
            ld [BZ + $3E], a
            ld [BZ + $3F], a
            ld [BZ + $40], a
.ad59:      ld a, [BZ + $48]                ; weapon statuses
            bit 7, a
            jr nz, .s1
            ld a, [EQ_P + $1B]
            ld [BZ + $3C], a
.s1:        ld a, [BZ + $49]
            bit 7, a
            jr nz, .s2
            ld a, [EQ_P + $23]
            ld [BZ + $41], a
            ld a, [BZ + $49]
            and 8
            jr z, .s2
            ld a, [BZ + $41]
            ld [BZ + $3C], a
.s2:        ld a, [BZ + $32]
            and 6
            cp 6
            jr nz, .s3
            ld a, [BZ + $3D]
            ld b, a
            ld a, [BZ + $38]
            or b
            ld [BZ + $38], a
            ld a, [BZ + $41]
            ld b, a
            ld a, [BZ + $3C]
            or b
            ld [BZ + $3C], a
.s3:        ld a, [BZ + $48]                ; (31/AD89-ADEA: work FF3 discards, but the bow
            ld b, a                         ;   path clears $3E)
            ld a, [BZ + $49]
            or b
            jr z, .ade
            ld a, [BZ + $32]
            and 6
            cp 6
            jr nz, .ade
            xor a
            ld [BZ + $3E], a
.ade:       xor a                           ; absorbed elements: shields' + armour's byte 0
            ld [BZ + $24], a
            ld [BZ + $25], a
            ld [BZ + $26], a
            ld a, [BZ + $48]
            bit 7, a
            jr z, .ab1
            ld a, [EQ_P + $18]
            ld [BZ + $24], a
            ld hl, BZ + $26
            inc [hl]
.ab1:       ld a, [BZ + $49]
            bit 7, a
            jr z, .ab2
            ld a, [EQ_P + $20]
            ld [BZ + $25], a
            ld hl, BZ + $26
            inc [hl]
.ab2:       ld a, [BZ + $24]
            ld b, a
            ld a, [BZ + $25]
            or b
            ld b, a
            ld a, [EQ_P + $00]
            or b
            ld b, a
            ld a, [EQ_P + $08]
            or b
            ld b, a
            ld a, [EQ_P + $10]
            or b
            ld [BZ + $42], a
            ld a, [W7 + $742E]              ; evade multiplier: (level / 16 + 1) * shields +
            swap a                          ;   agility / 16
            and $0F
            inc a
            ld c, a
            ld a, [BZ + $26]
            ld b, a
            ld a, c
            call bmul8                      ; (FFCD6: the low byte in $1A)
            ld c, a
            ld a, [W7 + $7429]
            swap a
            and $0F
            add a, c
            ld [BZ + $43], a
            xor a
            ld [BZ + $24], a
            ld [BZ + $25], a
            ld a, [BZ + $48]
            bit 7, a
            jr z, .ev1
            ld a, [EQ_P + $19]
            ld [BZ + $24], a
.ev1:       ld a, [BZ + $49]
            bit 7, a
            jr z, .ev2
            ld a, [EQ_P + $21]
            ld [BZ + $25], a
.ev2:       ld a, [W7 + $7429]              ; evade %: agility / 4 + shields + armour, <= 99
            srl a
            srl a
            ld hl, BZ + $24
            add a, [hl]
            inc hl
            add a, [hl]
            ld hl, EQ_P + $01
            add a, [hl]
            ld hl, EQ_P + $09
            add a, [hl]
            ld hl, EQ_P + $11
            add a, [hl]
            cp $63
            jr c, .ev3
            ld a, $63
.ev3:       ld [BZ + $44], a
            xor a
            ld [BZ + $24], a
            ld [BZ + $25], a
            ld a, [BZ + $48]
            bit 7, a
            jr z, .df1
            ld a, [EQ_P + $1A]
            ld [BZ + $24], a
.df1:       ld a, [BZ + $49]
            bit 7, a
            jr z, .df2
            ld a, [EQ_P + $22]
            ld [BZ + $25], a
.df2:       ld a, [W7 + $742A]              ; defence: vitality / 2 + shields + armour
            srl a
            ld hl, BZ + $24
            add a, [hl]
            inc hl
            add a, [hl]
            ld hl, EQ_P + $02
            add a, [hl]
            ld hl, EQ_P + $0A
            add a, [hl]
            ld hl, EQ_P + $12
            add a, [hl]
            ld [BZ + $45], a
            xor a
            ld [BZ + $24], a
            ld [BZ + $25], a
            ld a, [BZ + $48]
            bit 7, a
            jr z, .sr1
            ld a, [EQ_P + $1B]
            ld [BZ + $24], a
.sr1:       ld a, [BZ + $49]
            bit 7, a
            jr z, .sr2
            ld a, [EQ_P + $23]
            ld [BZ + $25], a
.sr2:       ld a, [BZ + $24]                ; status resistance
            ld b, a
            ld a, [BZ + $25]
            or b
            ld hl, EQ_P + $03
            or [hl]
            ld hl, EQ_P + $0B
            or [hl]
            ld hl, EQ_P + $13
            or [hl]
            ld [BZ + $46], a
            ld a, [BZ + $42]                ; weak elements: the absorbed ones' neighbours, not
            srl a                           ;   themselves (FF3's bits)
            and $28
            ld b, a
            ld a, [BZ + $42]
            add a, a
            and $50
            or b
            ld b, a
            ld a, [BZ + $42]
            cpl
            and b
            ld [BZ + $34], a
            ld a, [W7 + $7429]              ; m.evade mult = agility / 32 + (int + spr) / 32
            swap a
            rrca
            and 7
            ld b, a
            ld a, [W7 + $742B]
            ld c, a
            ld a, [W7 + $742C]
            add a, c
            ld [BZ + $26], a
            swap a
            rrca
            and 7
            add a, b
            ld [BZ + $35], a
            ld a, [BZ + $26]                ; m.evade % = (int + spr) / 2
            srl a
            ld [BZ + $36], a
            ld a, [EQ_P + $04]              ; m.defence: armour + shields
            ld hl, EQ_P + $0C
            add a, [hl]
            ld hl, EQ_P + $14
            add a, [hl]
            ld [BZ + $37], a
            ld a, [BZ + $48]
            bit 7, a
            jr z, .md1
            ld a, [EQ_P + $1C]
            ld hl, BZ + $37
            add a, [hl]
            ld [hl], a
.md1:       ld a, [BZ + $49]
            bit 7, a
            jr z, .md2
            ld a, [EQ_P + $24]
            ld hl, BZ + $37
            add a, [hl]
            ld [hl], a
.md2:       ld a, [BZ + $5F]                ; $620F: the row bit only (FF3's mask) | weapon type
            add a, $0F
            ld c, a
            ld a, $59
            call zpy
            ld a, [hl]
            and 1
            ld b, a
            ld a, [BZ + $32]
            or b
            ld [hl], a
            push af
            ld a, [BZ + $5F]
            add a, $33
            ld c, a
            ld a, $5B
            call zpy
            pop af
            ld [hl], a
            ld a, [BZ + $5F]                ; $34-$47 -> properties +$12.., $6100 + $1C..
            add a, $12
            ld c, a
            ld a, $5B
            call zpy
            push hl
            ld a, [BZ + $5F]
            add a, $1C
            ld c, a
            ld a, $57
            call zpy
            ld d, h
            ld e, l
            pop hl
            ld bc, BZ + $34
            ld a, $14
            ld [btl_n2], a
.cpy:       ld a, [bc]
            ld [hl+], a
            ld [de], a
            inc de
            inc bc
            ld a, [btl_n2]
            dec a
            ld [btl_n2], a
            jr nz, .cpy
            ld a, [BZ + $5F]                ; intelligence, spirit -> +$10 / $11
            add a, $10
            ld c, a
            ld a, $5B
            call zpy
            ld a, [W7 + $742B]
            ld [hl+], a
            ld a, [W7 + $742C]
            ld [hl], a
            ld a, [BZ + $5F]                ; hand types -> +$31 / $32
            add a, $31
            ld c, a
            ld a, $5B
            call zpy
            ld a, [BZ + $48]
            ld [hl+], a
            ld a, [BZ + $49]
            ld [hl], a
            ret

; hit %: A + agility / 4 ($24) + job level / 4 ($25), capped at 99
beq_hit:     ld hl, BZ + $24
            add a, [hl]
            inc hl
            add a, [hl]
            cp $63
            ret c
            ld a, $63
            ret

; 31/AF63: each set bit of A (msb first) adds 5 to stat $2C + n
beq_bonus:   ld hl, BZ + $2C
            ld b, 5
.l:         add a, a
            jr nc, .n
            push af
            ld a, [hl]
            add a, 5
            ld [hl], a
            pop af
.n:         inc hl
            dec b
            jr nz, .l
            ret
