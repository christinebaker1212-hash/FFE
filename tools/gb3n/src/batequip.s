; FF3's battle algorithm $05: update character equipment (31/AA16-31/AF76) as native code: the
; character [BZ+$52]'s battle values from their job, stats and equipment (30/9400 properties).

section bank B_BAT, $7800
fe_AA16:    call b_choff
            ld c, a
            call p59                        ; the equipment (6) -> $742F and $24
            ld de, $D42F
            ld b, 6
.e:         ld a, [hl+]
            ld [de], a
            push hl
            ld l, e
            ld h, high(BZ)
            ld a, l
            sub low($D42F) - $24
            ld l, a
            ld a, [de]
            ld [hl], a
            pop hl
            inc e
            dec b
            jr nz, .e
            ld hl, BZ + $26                 ; no helmet / armour / gloves: item $57
            ld b, 3
.n:         ld a, [hl]
            and a
            jr nz, .n1
            ld [hl], $57
.n1:        dec l
            dec b
            jr nz, .n
            ld a, [BZ + $29]                ; the left hand's item
            ld [$D433], a
            ld [BZ + $28], a
            xor a
            ld [BZ + $48], a
            ld [BZ + $49], a
            ld a, [BZ + $27]
            ld hl, BZ + $28
            or [hl]
            ld a, 0
            jp z, .typ                      ; unarmed
            ld a, [BZ + $27]
            and a
            jr nz, .right
            ld a, [BZ + $28]                ; the left hand only
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
            jr c, .lx
            cp $58
            jr nc, .l4
.lx:        xor a                           ; a bow without arrows / arrows without a bow
            ld [BZ + $28], a
            ld a, 2
            jp .typ
.l4:        ld a, $80
            ld [BZ + $49], a
            ld a, 2
            jp .typ
.right:     cp $46
            jr nc, .r1
            ld a, 1
            ld [BZ + $48], a
            ld a, [BZ + $28]
            and a
            jr z, .r0
            cp $58
            ld a, 1
            jr c, .r00
            ld a, $80
.r00:       ld [BZ + $49], a
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
            ld a, [BZ + $28]                ; a bow
            and a
            jr z, .r2x
            ld a, 2
            ld [BZ + $48], a
            ld a, 4
            ld [BZ + $49], a
            ld a, 6
            jr .typ
.r2x:       xor a
            ld [BZ + $27], a
            ld a, 2
            jr .typ
.r3:        cp $58
            jr nc, .r4
            ld a, [BZ + $28]                ; arrows
            and a
            jr z, .r2x
            ld a, 4
            ld [BZ + $48], a
            ld a, 2
            ld [BZ + $49], a
            ld a, 6
            jr .typ
.r4:        ld a, $80                       ; a shield
            ld [BZ + $48], a
            ld a, [BZ + $28]
            and a
            jr z, .r40
            cp $58
            ld a, 1
            jr c, .r41
            ld a, $80
.r41:       ld [BZ + $49], a
.r40:       ld a, 2
.typ:       push af
            xor a                           ; the 5 items' properties -> $7400-$7427
            ld [$D570], a
            ld [$D571], a
.it:        xor a
            ld [BZ + $20], a
            ld a, $94
            ld [BZ + $21], a
            ld a, [$D570]
            add low(BZ + $24)
            ld l, a
            ld h, high(BZ)
            ld a, [hl]
            ld [BZ + $18], a
            ld a, 8
            ld [BZ + $1A], a
            ld a, [$D571]
            ld b, a
            ld a, B_BDAT
            call b_ldarr
            ld a, b
            ld [$D571], a
            ld hl, $D570
            inc [hl]
            ld a, [hl]
            cp 5
            jr nz, .it
            ld hl, BZ + $34                 ; $34-$47 cleared
            ld b, $14
            xor a
.z:         ld [hl+], a
            dec b
            jr nz, .z
            ld a, [$D406]                   ; element boosts (lost by the bug at $AF16)
            ld hl, $D40E
            or [hl]
            ld hl, $D416
            or [hl]
            ld hl, $D41E
            or [hl]
            ld hl, $D426
            or [hl]
            and 7
            swap a
            add a
            ld [BZ + $24], a
            ld a, $0F
            call b_addoff
            ld c, a
            call p59
            ld a, [hl]
            and $F9
            ld b, a
            ld a, [BZ + $24]
            or b
            ld [hl], a
            ld a, $12                       ; base stats -> $2C-$30
            call b_addoff
            ld c, a
            call p57
            ld de, BZ + $2C
            ld b, 5
.bs:        ld a, [hl+]
            ld [de], a
            inc e
            dec b
            jr nz, .bs
            push hl
            ld a, [$D406]
            call fe_AF63
            ld a, [$D40E]
            call fe_AF63
            ld a, [$D416]
            call fe_AF63
            ld a, [$D41E]
            call fe_AF63
            ld a, [$D426]
            call fe_AF63
            pop hl
            ld de, BZ + $2C                 ; (max 99) -> the save page and $7428
            ld bc, $D428
.cp:        ld a, [de]
            cp $63
            jr c, .cp1
            ld a, $63
.cp1:       ld [hl+], a
            ld [bc], a
            inc c
            inc e
            ld a, e
            cp low(BZ + $31)
            jr nz, .cp
            pop af                          ; weapon type: 2 normal, 4 harp, 6 bow and arrows
            ld [BZ + $32], a
            ld a, [$D41F]                   ; the hands' elements ($38 / $3D)
            bit 7, a
            ld a, 0
            jr nz, .e1
            ld a, [$D418]
.e1:        ld [BZ + $38], a
            ld a, [$D427]
            bit 7, a
            ld a, 0
            jr nz, .e2
            ld a, [$D420]
.e2:        ld [BZ + $3D], a
            ld a, [BZ + $5F]                ; level / 16 + agility / 16 + 1 -> $39 / $3E
            inc a
            ld c, a
            call p57
            ld a, [hl]
            ld [$D42E], a
            swap a
            and 15
            ld [BZ + $26], a
            ld a, [$D429]
            swap a
            and 15
            scf
            ld hl, BZ + $26
            adc [hl]
            ld [BZ + $39], a
            ld [BZ + $3E], a
            ld a, $10                       ; job level / 4 -> $25, agility / 4 -> $24
            call b_addoff
            ld c, a
            call p57
            ld a, [hl]
            ld [$D42D], a
            srl a
            srl a
            ld [BZ + $25], a
            ld a, [$D429]
            srl a
            srl a
            ld [BZ + $24], a
            ld a, [BZ + $32]                ; hit % ($3A / $3F)
            and 6
            cp 6
            jr nz, .h2
            ld a, [BZ + $48]
            and 2
            jr z, .hb
            ld a, [$D419]
            and a
            jr nz, .hc
.hb:        ld a, [$D421]
.hc:        call .h99
            ld [BZ + $3A], a
            xor a
            ld [BZ + $3F], a
            jr .atk
.h2:        ld a, [BZ + $48]
            bit 7, a
            ld a, 0
            jr nz, .h3
            ld a, [$D419]
            call .h99
.h3:        ld [BZ + $3A], a
            ld a, [BZ + $49]
            bit 7, a
            ld a, 0
            jr nz, .h4
            ld a, [$D421]
            call .h99
.h4:        ld [BZ + $3F], a
.atk:       ld a, $38                       ; bonus attack (+$38 / +$39 of the record)
            call b_addoff
            ld c, a
            call p5b
            ld a, [$D41D]
            and $7F
            ld [hl+], a
            ld a, [$D425]
            and $7F
            ld [hl], a
            ld a, [BZ + $5F]                ; the job: Monk / Black Belt unarmed
            ld c, a
            call p57
            ld a, [hl]
            cp 2
            jr z, .mk
            cp $0D
            jr nz, .na
.mk:        ld a, [BZ + $32]
            and 6
            jr nz, .na
            ld a, [$D428]
            srl a
            srl a
            ld [BZ + $24], a
            ld a, [$D42E]
            srl a
            ld hl, $D42E
            add [hl]
            ld [BZ + $25], a
            ld a, [$D42D]
            srl a
            srl a
            ld hl, BZ + $24
            add [hl]
            inc l
            adc [hl]
            adc 2
            ld [BZ + $3B], a
            ld [BZ + $40], a
            jp .def
.na:        ld a, [BZ + $32]
            and 6
            cp 6
            jr nz, .nb
            ld a, [BZ + $48]                ; bow and arrows
            and 4
            jr z, .ar
            ld a, [$D41A]
            ld [BZ + $24], a
            ld a, [$D422]
            srl a
            ld [BZ + $25], a
            jr .ab
.ar:        ld a, [$D422]
            ld [BZ + $24], a
            ld a, [$D41A]
            srl a
            ld [BZ + $25], a
.ab:        call .str4
            ld hl, BZ + $24
            add [hl]
            inc l
            adc [hl]
            ld [BZ + $3B], a
            xor a
            ld [BZ + $40], a
            jp .def
.nb:        ld a, [BZ + $48]
            ld hl, BZ + $49
            or [hl]
            jr nz, .nc
            call .str4                      ; unarmed
            ld hl, $D41A
            add [hl]
            ld hl, BZ + $25
            adc [hl]
            ld [BZ + $3B], a
            ld [BZ + $40], a
            jp .def
.nc:        ld a, [BZ + $48]
            bit 7, a
            jr nz, .rz
            ld a, [BZ + $49]
            bit 7, a
            jr nz, .rw
            ld a, [BZ + $48]
            and a
            jr z, .rz
.rw:        call .str4
            ld hl, BZ + $25
            add [hl]
            ld hl, $D41A
            adc [hl]
            ld [BZ + $3B], a
            jr .lh
.rz:        xor a
            ld [BZ + $39], a
            ld [BZ + $3A], a
            ld [BZ + $3B], a
.lh:        ld a, [BZ + $49]
            bit 7, a
            jr nz, .lz
            ld a, [BZ + $48]
            bit 7, a
            jr nz, .lw
            ld a, [BZ + $49]
            and a
            jr z, .lz
.lw:        call .str4
            ld hl, BZ + $25
            add [hl]
            ld hl, $D422
            adc [hl]
            ld [BZ + $40], a
            jr .def
.lz:        xor a
            ld [BZ + $3E], a
            ld [BZ + $3F], a
            ld [BZ + $40], a
.def:       ld a, [BZ + $39]                ; no right hand values: the left hand's instead
            ld hl, BZ + $3A
            or [hl]
            inc l
            or [hl]
            jr nz, .st
            ld hl, BZ + $3E
            ld de, BZ + $39
            ld b, 3
.mv:        ld a, [hl]
            ld [de], a
            xor a
            ld [hl+], a
            inc e
            dec b
            jr nz, .mv
.st:        ld a, [BZ + $48]                ; weapon status ($3C / $41)
            bit 7, a
            jr nz, .s1
            ld a, [$D41B]
            ld [BZ + $3C], a
.s1:        ld a, [BZ + $49]
            bit 7, a
            jr nz, .s2
            ld a, [$D423]
            ld [BZ + $41], a
            ld a, [BZ + $49]
            and 8
            jr z, .s2
            ld a, [BZ + $41]
            ld [BZ + $3C], a
.s2:        ld a, [BZ + $32]
            and 6
            cp 6
            jr nz, .lvl
            ld a, [BZ + $38]
            ld hl, BZ + $3D
            or [hl]
            ld [BZ + $38], a
            ld a, [BZ + $3C]
            ld hl, BZ + $41
            or [hl]
            ld [BZ + $3C], a
.lvl:       ld a, [BZ + $5F]                ; (A = Y from the last JSR: the record's offset + 0)
            ld c, a
            call p5b
            ld a, [hl+]
            ld [BZ + $24], a
            ld a, [hl]
            ld [BZ + $25], a
            ld a, [BZ + $48]
            ld hl, BZ + $49
            or [hl]
            jr z, .mvz
            ld a, [BZ + $32]
            and 6
            cp 6
            jr z, .mv6
            ld a, [BZ + $48]
            bit 7, a
            jr nz, .mv5
            and a
            jr z, .mv5
            ld a, [BZ + $49]
            bit 7, a
            jr nz, .mv5
            and a
            jr z, .mv5
.mvz:       jr .el
.mv5:       ld hl, BZ + $24
            sla [hl]
            ld a, [BZ + $48]
            bit 7, a
            ld a, [$D41A]
            jr z, .mv5a
            ld a, [$D422]
.mv5a:      srl a
            ld hl, BZ + $25
            add [hl]
            ld [hl], a
.mv6:       xor a
            ld [BZ + $3E], a
            ld a, [BZ + $24]
            add a
            ld hl, BZ + $24
            add [hl]
            ld [hl], a
            ld a, [BZ + $48]
            and 4
            ld a, [$D41A]
            jr nz, .mv6a
            ld a, [$D422]
.mv6a:      ld hl, BZ + $25
            add [hl]
            ld [hl], a
.el:        xor a                           ; absorbed elements ($42)
            ld [BZ + $24], a
            ld [BZ + $25], a
            ld [BZ + $26], a
            ld a, [BZ + $48]
            bit 7, a
            jr z, .el1
            ld a, [$D418]
            ld [BZ + $24], a
            ld hl, BZ + $26
            inc [hl]
.el1:       ld a, [BZ + $49]
            bit 7, a
            jr z, .el2
            ld a, [$D420]
            ld [BZ + $25], a
            ld hl, BZ + $26
            inc [hl]
.el2:       ld a, [BZ + $24]
            ld hl, BZ + $25
            or [hl]
            ld hl, $D400
            or [hl]
            ld hl, $D408
            or [hl]
            ld hl, $D410
            or [hl]
            ld [BZ + $42], a
            ld a, [$D42E]                   ; evade multiplier: (level / 16 + 1) x shields + agility / 16
            swap a
            and 15
            inc a
            ld b, a
            ld a, [BZ + $26]
            ld e, b
            call mul8
            ld a, l
            ld [BZ + $1A], a
            ld a, h
            ld [BZ + $1B], a
            ld a, [$D429]
            swap a
            and 15
            ld hl, BZ + $1A
            add [hl]
            ld [BZ + $43], a
            xor a                           ; evade %
            ld [BZ + $24], a
            ld [BZ + $25], a
            ld a, [BZ + $48]
            bit 7, a
            jr z, .ev1
            ld a, [$D419]
            ld [BZ + $24], a
.ev1:       ld a, [BZ + $49]
            bit 7, a
            jr z, .ev2
            ld a, [$D421]
            ld [BZ + $25], a
.ev2:       ld a, [$D429]
            srl a
            srl a
            ld hl, BZ + $24
            add [hl]
            inc l
            adc [hl]
            ld hl, $D401
            adc [hl]
            ld hl, $D409
            adc [hl]
            ld hl, $D411
            adc [hl]
            cp $63
            jr c, .ev3
            ld a, $63
.ev3:       ld [BZ + $44], a
            xor a                           ; defence
            ld [BZ + $24], a
            ld [BZ + $25], a
            ld a, [BZ + $48]
            bit 7, a
            jr z, .df1
            ld a, [$D41A]
            ld [BZ + $24], a
.df1:       ld a, [BZ + $49]
            bit 7, a
            jr z, .df2
            ld a, [$D422]
            ld [BZ + $25], a
.df2:       ld a, [$D42A]
            srl a
            ld hl, BZ + $24
            add [hl]
            inc l
            adc [hl]
            ld hl, $D402
            adc [hl]
            ld hl, $D40A
            adc [hl]
            ld hl, $D412
            adc [hl]
            ld [BZ + $45], a
            xor a                           ; status resistance
            ld [BZ + $24], a
            ld [BZ + $25], a
            ld a, [BZ + $48]
            bit 7, a
            jr z, .sr1
            ld a, [$D41B]
            ld [BZ + $24], a
.sr1:       ld a, [BZ + $49]
            bit 7, a
            jr z, .sr2
            ld a, [$D423]
            ld [BZ + $25], a
.sr2:       ld a, [BZ + $24]
            ld hl, BZ + $25
            or [hl]
            ld hl, $D403
            or [hl]
            ld hl, $D40B
            or [hl]
            ld hl, $D413
            or [hl]
            ld [BZ + $46], a
            ld a, [BZ + $42]                ; weak elements ($34)
            srl a
            and $28
            ld [BZ + $24], a
            ld a, [BZ + $42]
            add a
            and $50
            ld hl, BZ + $24
            or [hl]
            ld [BZ + $34], a
            ld a, [BZ + $42]
            cpl
            ld hl, BZ + $34
            and [hl]
            ld [hl], a
            ld a, [$D429]                   ; m.evade multiplier and %
            swap a
            srl a
            and 7
            ld [BZ + $25], a
            ld a, [$D42B]
            ld hl, $D42C
            add [hl]
            ld [BZ + $26], a
            swap a
            srl a
            and 7
            ld hl, BZ + $25
            add [hl]
            ld [BZ + $35], a
            ld a, [BZ + $26]
            srl a
            ld [BZ + $36], a
            ld a, [$D404]                   ; m.defence
            ld hl, $D40C
            add [hl]
            ld hl, $D414
            adc [hl]
            ld [BZ + $37], a
            ld a, [BZ + $48]
            bit 7, a
            jr z, .md1
            ld a, [$D41C]
            ld hl, BZ + $37
            add [hl]
            ld [hl], a
.md1:       ld a, [BZ + $49]
            bit 7, a
            jr z, .md2
            ld a, [$D424]
            ld hl, BZ + $37
            add [hl]
            ld [hl], a
.md2:       ld a, $0F                       ; the row and weapon type (the element bits lost)
            call b_addoff
            ld c, a
            call p59
            ld a, [hl]
            and 1
            ld b, a
            ld a, [BZ + $32]
            or b
            ld [hl], a
            push af
            ld a, $33
            call b_addoff
            ld c, a
            call p5b
            pop af
            ld [hl], a
            ld a, $12                       ; $34-$47 -> the record +$12 and the save page +$1C
            call b_addoff
            ld c, a
            call p5b
            push hl
            ld a, $12 + $0A
            call b_addoff
            ld c, a
            call p57
            ld d, h
            ld e, l
            pop hl
            ld bc, BZ + $34
.cp2:       ld a, [bc]
            ld [hl+], a
            ld [de], a
            inc de
            inc c
            ld a, c
            cp low(BZ + $48)
            jr nz, .cp2
            ld a, $10                       ; intellect, spirit
            call b_addoff
            ld c, a
            call p5b
            ld a, [$D42B]
            ld [hl+], a
            ld a, [$D42C]
            ld [hl], a
            ld a, $31                       ; the hands' item types
            call b_addoff
            ld c, a
            call p5b
            ld a, [BZ + $48]
            ld [hl+], a
            ld a, [BZ + $49]
            ld [hl], a
            ret
; A + $24 + $25 at most 99
.h99:       ld hl, BZ + $24
            add [hl]
            inc l
            adc [hl]
            cp $63
            ret c
            ld a, $63
            ret
; A = strength / 4 (clear carry)
.str4:      ld a, [$D428]
            srl a
            srl a
            and a
            ret

; $AF63 apply equipment stat bonus: bits 7-3 of A: +5 to $2C-$30
fe_AF63:    ld hl, BZ + $2C
            ld b, 5
.b:         add a
            jr nc, .n
            push af
            ld a, [hl]
            add 5
            ld [hl], a
            pop af
.n:         inc l
            dec b
            jr nz, .b
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
