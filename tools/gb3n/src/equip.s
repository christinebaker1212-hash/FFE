; ---- FF3 31/AA16 "update character equipment" (battle algorithm $05), written for the GB: from
; the member's equipment ($6200-$6205) and stats, the weapon type, the modified stats ($6117-$611B,
; capped at 99), and the 20 battle values $34-$47 -> $611C-$612F (FF3 also copies them to its battle
; block $7575 + $12; the battle module recomputes them). FF3's zero-page temporaries are HRAM
; (Z_xx = FF3 $xx), its item-property buffer $7400-$7433 is T74 (item properties 30/9400: GAME_BANK
; $6000 + 8 id). Bugs kept: the element boosts are cleared at 31/AF16 (and #$01).
Z_BASE     = $FFB0              ; FF3 $18 -> $FFB0
T74        = $C0A0              ; FF3 $7400

; A = member (0-3)
eq_calc:    rrca
            rrca
            ldh [Z_5F], a                   ; (the character offset)
            ld l, a                         ; equipment: $24-$29 (helmet, armor, gloves, right,
            ld h, high(GS + $200)           ;   (right arrow), left)
            ld c, low(Z_24)
            ld b, 6
.cp:        ld a, [hl+]
            ldh [c], a
            inc c
            dec b
            jr nz, .cp
            ld c, low(Z_26)                 ; no armour: $57
.na:        ldh a, [c]
            and a
            jr nz, .na2
            ld a, $57
            ldh [c], a
.na2:       dec c
            ld a, c
            cp low(Z_24) - 1
            jr nz, .na
            ldh a, [Z_29]                   ; $28 = the left hand
            ld [T74 + $33], a
            ldh [Z_28], a
            xor a
            ldh [Z_48], a
            ldh [Z_49], a
            ldh a, [Z_27]                   ; the hands (31/AA44-AB08) -> A = weapon type
            ld b, a
            ldh a, [Z_28]
            or b
            jr nz, .armed
            xor a
            jp .wt
.armed:     ld a, b
            and a
            jr nz, .right
            ldh a, [Z_28]                   ; left hand only
            cp $46
            jr nc, .l1
            ld a, 1
            ldh [Z_49], a
            ld a, 2
            jp .wt
.l1:        cp $4A
            jr nc, .l2
            ld a, 8
            ldh [Z_49], a
            ld a, 4
            jp .wt
.l2:        cp $4F
            jr nc, .l3
            xor a
            ldh [Z_28], a
            ld a, 2
            jp .wt
.l3:        cp $58
            jr nc, .l4
            xor a
            ldh [Z_28], a
            ld a, 2
            jp .wt
.l4:        ld a, $80
            ldh [Z_49], a
            ld a, 2
            jp .wt
.right:     cp $46
            jr nc, .r2
            ld a, 1
            ldh [Z_48], a
            ldh a, [Z_28]
            and a
            jr z, .r1
            cp $58
            jr nc, .r0
            ld a, 1
            ldh [Z_49], a
            jr .r1
.r0:        ld a, $80
            ldh [Z_49], a
.r1:        ld a, 2
            jp .wt
.r2:        cp $4A
            jr nc, .r3
            ld a, 8
            ldh [Z_48], a
            ld a, 4
            jp .wt
.r3:        cp $4F
            jr nc, .r5
            ldh a, [Z_28]
            and a
            jr z, .r4
            ld a, 2
            ldh [Z_48], a
            ld a, 4
            ldh [Z_49], a
            ld a, 6
            jr .wt
.r4:        xor a
            ldh [Z_27], a
            ld a, 2
            jr .wt
.r5:        cp $58
            jr nc, .r7
            ldh a, [Z_28]
            and a
            jr z, .r6
            ld a, 4
            ldh [Z_48], a
            ld a, 2
            ldh [Z_49], a
            ld a, 6
            jr .wt
.r6:        xor a
            ldh [Z_27], a
            ld a, 2
            jr .wt
.r7:        ld a, $80
            ldh [Z_48], a
            ldh a, [Z_28]
            and a
            jr z, .r9
            cp $58
            jr nc, .r8
            ld a, 1
            ldh [Z_49], a
            jr .r9
.r8:        ld a, $80
            ldh [Z_49], a
.r9:        ld a, 2
.wt:        ldh [Z_32], a                   ; (pushed by FF3; kept here)
            ld de, T74                      ; the 5 items' properties -> $7400-$7427
            ld c, low(Z_24)
.it:        ldh a, [c]
            push bc
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            ld bc, $6000
            add hl, bc
            ld bc, 8
            ld a, GAME_BANK
            call rd_copy                    ; (DE advanced)
            pop bc
            inc c
            ld a, c
            cp low(Z_29)
            jr nz, .it
            ld c, low(Z_34)                 ; $34-$47 cleared
            ld b, $14
            xor a
.cl:        ldh [c], a
            inc c
            dec b
            jr nz, .cl
            ld a, [T74 + $06]               ; element boost bits -> $620F (bits 5-7 of the
            ld b, a                         ;   or of the 5 items' byte 6 & 7, asl 5)
            ld a, [T74 + $0E]
            or b
            ld b, a
            ld a, [T74 + $16]
            or b
            ld b, a
            ld a, [T74 + $1E]
            or b
            ld b, a
            ld a, [T74 + $26]
            or b
            and 7
            swap a
            add a, a
            ld b, a
            call eq_p2                      ; HL = $6200 + offset + $0F
            ld a, [hl]
            and $F9
            or b
            ld [hl], a
            call eq_p1                      ; base stats $6112-$6116 -> $2C-$30
            ld a, l
            add a, $12
            ld l, a
            ld c, low(Z_2C)
            ld b, 5
.bs:        ld a, [hl+]
            ldh [c], a
            inc c
            dec b
            jr nz, .bs
            ld a, [T74 + $06]               ; stat bonuses (31/AF63)
            call eq_bonus
            ld a, [T74 + $0E]
            call eq_bonus
            ld a, [T74 + $16]
            call eq_bonus
            ld a, [T74 + $1E]
            call eq_bonus
            ld a, [T74 + $26]
            call eq_bonus
            call eq_p1                      ; capped at 99 -> $6117-$611B and $7428-$742C
            ld a, l
            add a, $17
            ld l, a
            ld de, T74 + $28
            ld c, low(Z_2C)
            ld b, 5
.ms:        ldh a, [c]
            cp 99
            jr c, .m9
            ld a, 99
.m9:        ld [hl+], a
            ld [de], a
            inc de
            inc c
            dec b
            jr nz, .ms
            ld a, [T74 + $1F]               ; attack elements: right ($38), left ($3D)
            bit 7, a
            ld a, 0
            jr nz, .e1
            ld a, [T74 + $18]
.e1:        ldh [Z_38], a
            ld a, [T74 + $27]
            bit 7, a
            ld a, 0
            jr nz, .e2
            ld a, [T74 + $20]
.e2:        ldh [Z_3D], a
            call eq_p1                      ; level -> $742E; hit multiplier $39 / $3E =
            inc l                           ;   level / 16 + agility / 16 + 1
            ld a, [hl]
            ld [T74 + $2E], a
            swap a
            and $0F
            ldh [Z_26], a
            ld a, [T74 + $29]
            swap a
            and $0F
            scf
            ld b, a
            ldh a, [Z_26]
            adc a, b
            ldh [Z_39], a
            ldh [Z_3E], a
            call eq_p1                      ; job level -> $742D; $25 = job level / 4,
            ld a, l                         ;   $24 = agility / 4
            add a, $10
            ld l, a
            ld a, [hl]
            ld [T74 + $2D], a
            srl a
            srl a
            ldh [Z_25], a
            ld a, [T74 + $29]
            srl a
            srl a
            ldh [Z_24], a
            ldh a, [Z_32]                   ; hit % ($3A / $3F)
            and 6
            cp 6
            jr nz, .h2
            ldh a, [Z_48]                   ; bow and arrow: the bow's hit %
            and 2
            jr z, .h0
            ld a, [T74 + $19]
            and a
            jr nz, .h1
.h0:        ld a, [T74 + $21]
.h1:        call eq_hit
            ldh [Z_3A], a
            xor a
            ldh [Z_3F], a
            jr .h9
.h2:        ldh a, [Z_48]
            bit 7, a
            ld a, 0
            jr nz, .h3
            ld a, [T74 + $19]
            call eq_hit
.h3:        ldh [Z_3A], a
            ldh a, [Z_49]
            bit 7, a
            ld a, 0
            jr nz, .h4
            ld a, [T74 + $21]
            call eq_hit
.h4:        ldh [Z_3F], a
.h9:        ld a, [T74 + $1D]               ; bonus attack -> $7575 + $38 / $39 (battle block:
            and $7F                         ;   eq_bonus_r / l for the battle module)
            ld [eq_bonr], a
            ld a, [T74 + $25]
            and $7F
            ld [eq_bonl], a
            call eq_p1                      ; attack ($3B / $40): Monk / Karateka (jobs 2 / $D)
            ld a, [hl]                      ;   unarmed
            cp 2
            jr z, .mk
            cp $0D
            jr nz, .a1
.mk:        ldh a, [Z_32]
            and 6
            jr nz, .a1
            ld a, [T74 + $28]               ; strength / 4 + level * 1.5 + job level / 4 + 2
            srl a
            srl a
            ldh [Z_24], a
            ld a, [T74 + $2E]
            ld b, a
            srl a
            add a, b
            ldh [Z_25], a
            ld a, [T74 + $2D]
            srl a
            srl a
            ld b, a
            ldh a, [Z_24]
            add a, b
            ld b, a
            ldh a, [Z_25]
            add a, b
            add a, 2
            ldh [Z_3B], a
            ldh [Z_40], a
            jp .a9
.a1:        ldh a, [Z_32]
            and 6
            cp 6
            jr nz, .a3
            ldh a, [Z_48]                   ; bow and arrow
            and 4
            jr z, .a2
            ld a, [T74 + $1A]
            ldh [Z_24], a
            ld a, [T74 + $22]
            srl a
            ldh [Z_25], a
            jr .a2b
.a2:        ld a, [T74 + $22]
            ldh [Z_24], a
            ld a, [T74 + $1A]
            srl a
            ldh [Z_25], a
.a2b:       ld a, [T74 + $28]
            srl a
            srl a
            ld b, a
            ldh a, [Z_24]
            add a, b
            ld b, a
            ldh a, [Z_25]
            add a, b
            ldh [Z_3B], a
            xor a
            ldh [Z_40], a
            jp .a9
.a3:        ldh a, [Z_48]
            ld b, a
            ldh a, [Z_49]
            or b
            jr nz, .a4
            ld a, [T74 + $28]               ; unarmed: strength / 4 + $741A + $25
            srl a
            srl a
            ld b, a
            ld a, [T74 + $1A]
            add a, b
            ld b, a
            ldh a, [Z_25]
            add a, b
            ldh [Z_3B], a
            ldh [Z_40], a
            jp .a9
.a4:        ldh a, [Z_48]
            bit 7, a
            jr nz, .a5
            ldh a, [Z_49]
            bit 7, a
            jr nz, .a6
            ldh a, [Z_48]
            and a
            jr nz, .a6
.a5:        xor a
            ldh [Z_39], a
            ldh [Z_3A], a
            ldh [Z_3B], a
            jr .a7
.a6:        ld a, [T74 + $28]
            srl a
            srl a
            ld b, a
            ldh a, [Z_25]
            add a, b
            ld b, a
            ld a, [T74 + $1A]
            add a, b
            ldh [Z_3B], a
.a7:        ldh a, [Z_49]
            bit 7, a
            jr nz, .a8
            ldh a, [Z_48]
            bit 7, a
            jr nz, .a8b
            ldh a, [Z_49]
            and a
            jr nz, .a8b
.a8:        xor a
            ldh [Z_3E], a
            ldh [Z_3F], a
            ldh [Z_40], a
            jr .a9
.a8b:       ld a, [T74 + $28]
            srl a
            srl a
            ld b, a
            ldh a, [Z_25]
            add a, b
            ld b, a
            ld a, [T74 + $22]
            add a, b
            ldh [Z_40], a
.a9:        ldh a, [Z_39]                   ; no right-hand attack: the left hand's values
            ld b, a
            ldh a, [Z_3A]
            or b
            ld b, a
            ldh a, [Z_3B]
            or b
            jr nz, .s0
            ldh a, [Z_3E]
            ldh [Z_39], a
            ldh a, [Z_3F]
            ldh [Z_3A], a
            ldh a, [Z_40]
            ldh [Z_3B], a
            xor a
            ldh [Z_3E], a
            ldh [Z_3F], a
            ldh [Z_40], a
.s0:        ldh a, [Z_48]                   ; weapon status ($3C / $41)
            bit 7, a
            jr nz, .s1
            ld a, [T74 + $1B]
            ldh [Z_3C], a
.s1:        ldh a, [Z_49]
            bit 7, a
            jr nz, .s2
            ld a, [T74 + $23]
            ldh [Z_41], a
            ldh a, [Z_49]
            and 8
            jr z, .s2
            ldh a, [Z_41]
            ldh [Z_3C], a
.s2:        ldh a, [Z_32]
            and 6
            cp 6
            jr nz, .s3
            ldh a, [Z_3D]
            ld b, a
            ldh a, [Z_38]
            or b
            ldh [Z_38], a
            ldh a, [Z_41]
            ld b, a
            ldh a, [Z_3C]
            or b
            ldh [Z_3C], a
.s3:        call eq_def2                    ; (31/AD89-ADEA: $24 / $25 from the battle block's
                                            ;   +$33 / +$34: their results unused below)
            xor a                           ; shields: $24 / $25 elements, $26 count
            ldh [Z_24], a
            ldh [Z_25], a
            ldh [Z_26], a
            ldh a, [Z_48]
            bit 7, a
            jr z, .d1
            ld a, [T74 + $18]
            ldh [Z_24], a
            call .inc26
.d1:        ldh a, [Z_49]
            bit 7, a
            jr z, .d2
            ld a, [T74 + $20]
            ldh [Z_25], a
            call .inc26
.d2:        ldh a, [Z_24]                   ; absorbed elements ($42)
            ld b, a
            ldh a, [Z_25]
            or b
            ld b, a
            ld a, [T74 + $00]
            or b
            ld b, a
            ld a, [T74 + $08]
            or b
            ld b, a
            ld a, [T74 + $10]
            or b
            ldh [Z_42], a
            ld a, [T74 + $2E]               ; evade multiplier ($43) = (level / 16 + 1) * shields
            swap a                          ;   + agility / 16 (fix:FCD6: low byte)
            and $0F
            inc a
            ld c, a
            ldh a, [Z_26]
            ld e, a
            call mul8
            ld a, [T74 + $29]
            swap a
            and $0F
            add a, l
            ldh [Z_43], a
            xor a                           ; evade % ($44): agility / 4 + shields' + armour's
            ldh [Z_24], a
            ldh [Z_25], a
            ldh a, [Z_48]
            bit 7, a
            jr z, .v1
            ld a, [T74 + $19]
            ldh [Z_24], a
.v1:        ldh a, [Z_49]
            bit 7, a
            jr z, .v2
            ld a, [T74 + $21]
            ldh [Z_25], a
.v2:        ld a, [T74 + $29]
            srl a
            srl a
            ld b, a
            ldh a, [Z_24]
            add a, b
            ld b, a
            ldh a, [Z_25]
            add a, b
            ld b, a
            ld a, [T74 + $01]
            add a, b
            ld b, a
            ld a, [T74 + $09]
            add a, b
            ld b, a
            ld a, [T74 + $11]
            add a, b
            cp 99
            jr c, .v9
            ld a, 99
.v9:        ldh [Z_44], a
            xor a                           ; defense ($45): vitality / 2 + shields' + armour's
            ldh [Z_24], a
            ldh [Z_25], a
            ldh a, [Z_48]
            bit 7, a
            jr z, .f1
            ld a, [T74 + $1A]
            ldh [Z_24], a
.f1:        ldh a, [Z_49]
            bit 7, a
            jr z, .f2
            ld a, [T74 + $22]
            ldh [Z_25], a
.f2:        ld a, [T74 + $2A]
            srl a
            ld b, a
            ldh a, [Z_24]
            add a, b
            ld b, a
            ldh a, [Z_25]
            add a, b
            ld b, a
            ld a, [T74 + $02]
            add a, b
            ld b, a
            ld a, [T74 + $0A]
            add a, b
            ld b, a
            ld a, [T74 + $12]
            add a, b
            ldh [Z_45], a
            xor a                           ; status resistance ($46)
            ldh [Z_24], a
            ldh [Z_25], a
            ldh a, [Z_48]
            bit 7, a
            jr z, .t1
            ld a, [T74 + $1B]
            ldh [Z_24], a
.t1:        ldh a, [Z_49]
            bit 7, a
            jr z, .t2
            ld a, [T74 + $23]
            ldh [Z_25], a
.t2:        ldh a, [Z_24]
            ld b, a
            ldh a, [Z_25]
            or b
            ld b, a
            ld a, [T74 + $03]
            or b
            ld b, a
            ld a, [T74 + $0B]
            or b
            ld b, a
            ld a, [T74 + $13]
            or b
            ldh [Z_46], a
            ldh a, [Z_42]                   ; $34: weak elements = the rotated absorbed set,
            srl a                           ;   minus the absorbed
            and $28
            ldh [Z_24], a
            ldh a, [Z_42]
            add a, a
            and $50
            ld b, a
            ldh a, [Z_24]
            or b
            ld b, a
            ldh a, [Z_42]
            cpl
            and b
            ldh [Z_34], a
            ld a, [T74 + $29]               ; m.evade mult ($35) = agility / 32 + (int + spr) / 32
            swap a
            rrca
            and 7
            ldh [Z_25], a
            ld a, [T74 + $2B]
            ld b, a
            ld a, [T74 + $2C]
            add a, b                        ; (8 bits, as FF3)
            ldh [Z_26], a
            swap a
            rrca
            and 7
            ld b, a
            ldh a, [Z_25]
            add a, b
            ldh [Z_35], a
            ldh a, [Z_26]                   ; m.evade % ($36) = (int + spr) / 2
            srl a
            ldh [Z_36], a
            ld a, [T74 + $04]               ; m.defense ($37): armour's + shields'
            ld b, a
            ld a, [T74 + $0C]
            add a, b
            ld b, a
            ld a, [T74 + $14]
            add a, b
            ldh [Z_37], a
            ldh a, [Z_48]
            bit 7, a
            jr z, .g1
            ld a, [T74 + $1C]
            ld b, a
            ldh a, [Z_37]
            add a, b
            ldh [Z_37], a
.g1:        ldh a, [Z_49]
            bit 7, a
            jr z, .g2
            ld a, [T74 + $24]
            ld b, a
            ldh a, [Z_37]
            add a, b
            ldh [Z_37], a
.g2:        call eq_p2                      ; $620F = row & 1 | weapon type (the bug: the
            ld a, [hl]                      ;   element boosts dropped)
            and 1
            ld b, a
            ldh a, [Z_32]
            or b
            ld [hl], a
            ld [eq_type], a
            call eq_p1                      ; $34-$47 -> $611C-$612F
            ld a, l
            add a, $1C
            ld l, a
            ld c, low(Z_34)
            ld b, $14
.out:       ldh a, [c]
            ld [hl+], a
            inc c
            dec b
            jr nz, .out
            ldh a, [Z_48]
            ld [eq_hr], a
            ldh a, [Z_49]
            ld [eq_hl], a
            ret
.inc26:     ldh a, [Z_26]
            inc a
            ldh [Z_26], a
            ret

; HL = $6100 / $6200 + the character offset
eq_p1:      ldh a, [Z_5F]
            ld l, a
            ld h, high(GS + $100)
            ret
eq_p2:      ldh a, [Z_5F]
            add a, $0F
            ld l, a
            ld h, high(GS + $200)
            ret
; 31/AF63: each set bit of A (bits 7-3) adds 5 to the stat ($2C-$30)
eq_bonus:   ld c, low(Z_2C)
            ld b, 5
.l:         add a, a
            jr nc, .n
            push af
            ldh a, [c]
            add a, 5
            ldh [c], a
            pop af
.n:         inc c
            dec b
            jr nz, .l
            ret
; hit %: A + $24 + $25, at most 99
eq_hit:     ld b, a
            ldh a, [Z_24]
            add a, b
            ld b, a
            ldh a, [Z_25]
            add a, b
            cp 99
            ret c
            ld a, 99
            ret
; 31/AD89-ADEA: the temporaries it computes are cleared at ADEA; what stays is $3E = 0 (the
; second hand's hit multiplier) unless both hands hold weapons (or none)
eq_def2:    ldh a, [Z_48]
            ld b, a
            ldh a, [Z_49]
            or b
            ret z
            ldh a, [Z_32]
            and 6
            cp 6
            jr z, .z
            ld a, b
            bit 7, a
            jr nz, .z
            and a
            jr z, .z
            ldh a, [Z_49]
            bit 7, a
            jr nz, .z
            and a
            ret nz
.z:         xor a
            ldh [Z_3E], a
            ret


; ---- the Equip menu (FF3 3C/9BB5; owner-approved mock S4): name, Attack… / Defense… on top;
; the slots (right hand, left hand, head, body, arms: empty ones by their label, t8200 $DD-$E1)
; and Remove Equipment; A on a filled slot takes the item off (3C/9D68), on an empty one opens the
; inventory items for that slot (3C/9C3C: the class check, the weapon combinations 3C/9D4B, arrows
; up to 20); every change recomputes the values (eq_calc, as FD10B)
EQ_SLOT:    db 3, 5, 0, 1, 2                ; (rows -> $6200 slots)

equip_menu: ld [m_i], a
            rrca
            rrca
            ld [m_ch], a
            ld [mg_caster], a
            xor a
            ld [e_row], a
.redraw:    ld a, [m_i]
            call eq_calc
            call e_draw
.l:         ld a, [e_row]
            add a, 5
            add a, a
            add a, a
            add a, a
            add a, 16 - 4
            ld c, a
            ld b, 8
            call cursor_at
            call wait_vbl
            call read_pad
            call m_keys
            ld a, [m_new]
            bit 1, a
            jp nz, cur_hide
            bit 0, a
            jr nz, .a
            ld b, a
            ld a, [e_row]
            bit 6, b
            jr z, .d
            and a
            jr z, .l
            dec a
            jr .s
.d:         bit 7, b
            jr z, .l
            cp 5
            jr z, .l
            inc a
.s:         ld [e_row], a
            jr .l
.a:         ld a, [e_row]
            cp 5
            jr nz, .one
            ld b, 5                         ; Remove Equipment: each slot (3C/9DA2)
.all:       push bc
            ld a, b
            dec a
            call e_take
            pop bc
            jr c, .full
            dec b
            jr nz, .all
            jr .redraw
.full:      ld a, $6B
            call m_msgbox
            jr .redraw
.one:       call e_slotof
            ld [e_slot], a
            ld l, a
            ld a, [m_ch]
            add a, l
            ld l, a
            ld h, high(GS + $200)
            ld a, [hl]
            and a
            jr z, .list
            ld a, [e_row]                   ; filled: off to the inventory
            call e_take
            jr c, .full
            jr .redraw
.list:      call e_list
            jp .redraw

; A = row -> A = slot
e_slotof:   push hl
            ld l, a
            ld h, 0
            ld de, EQ_SLOT
            add hl, de
            ld a, [hl]
            pop hl
            ret

; row A's item to the inventory (count: the weapon slots' $6201 / $6206, else 1); carry: full
e_take:     call e_slotof
            ld b, a
            ld a, [m_ch]
            add a, b
            ld l, a
            ld h, high(GS + $200)
            ld a, [hl]
            and a
            ret z
            ld [ev_par], a
            ld c, 1
            ld a, b
            cp 3
            jr c, .q
            inc l
            ld c, [hl]
            dec l
.q:         push hl
            push bc
            call ev_find
            pop bc
            jr c, .f
            ld a, [ev_par]
            ld [hl], a
            ld a, l
            add a, $20
            ld l, a
            ld a, [hl]
            add a, c
            cp 99
            jr c, .q9
            ld a, 99
.q9:        ld [hl], a
            pop hl
            ld [hl], 0
            ld a, b
            cp 3
            jr c, .ok                       ; (no count byte; carry clear: taken. It returned
            inc l                           ;   carry here, read as a full bag: head / body /
            ld [hl], 0                      ;   arms showed the full-bag message)
.ok:        and a
            ret
.f:         pop hl
            scf
            ret


; ---- for the rebuilt Equip screen (eqm.s, bank CODE11; reached by far_call): m_i = the member,
; e_row = the row (0 right hand, 1 left, 2 head, 3 body, 4 arms). Results in u_eatk / u_edef /
; u_eres (ui.s).
eqx_m:      ld a, [m_i]
            rrca
            rrca
            ld [m_ch], a
            ld [mg_caster], a
            ret
; Attack / Defense now -> u_eatk / u_edef
eqx_vals:   call eqx_m
            ld a, [m_i]
            call eq_calc
            call st_atk
            ld a, e
            ld [u_eatk], a
            ld a, d
            ld [u_eatk + 1], a
            call st_def
            ld a, e
            ld [u_edef], a
            ld a, d
            ld [u_edef + 1], a
            ret
; the values with item e_item (0: none) in row e_row's slot (the slot put back after)
eqx_prev:   call eqx_m
            ld a, [e_row]
            call e_slotof
            ld b, a
            ld a, [m_ch]
            add a, b
            ld l, a
            ld h, high(GS + $200)
            ld a, [hl]
            push af
            push hl
            ld a, [e_item]
            ld [hl], a
            call eqx_vals
            pop hl
            pop af
            ld [hl], a
            ld a, [u_eatk]
            ld [u_patk], a
            ld a, [u_eatk + 1]
            ld [u_patk + 1], a
            ld a, [u_edef]
            ld [u_pdef], a
            ld a, [u_edef + 1]
            ld [u_pdef + 1], a
            jp eqx_vals
; the row's item to the bag; u_eres $FF if the bag is full
eqx_take:   call eqx_m
            ld a, [e_row]
            call e_take
            sbc a, a
            ld [u_eres], a
            ret
; the bag's items for row e_row that the member's job can wear (owner: the others not shown)
; -> e_ids (bag indexes), e_cnt
eqx_list:   call eqx_m
            ld a, [e_row]
            call e_slotof
            ld [e_slot], a
            ld hl, e_ids
            ld bc, 0
.f:         ld a, c
            add a, low(GS + $C0)
            ld e, a
            ld d, high(GS + $C0)
            ld a, [de]
            and a
            jr z, .n
            push af
            call e_fits
            jr nc, .np
            pop af
            push hl
            push bc
            call can_equip
            pop bc
            pop hl
            jr z, .n
            ld [hl], c
            inc hl
            inc b
            jr .n
.np:        pop af
.n:         inc c
            ld a, c
            cp 32
            jr nz, .f
            ld a, b
            ld [e_cnt], a
            ret
; bag index e_inv into row e_row (what is there first to the bag); u_eres 0 done, 1 not with
; the other hand's weapon (3C/9D4B), $FF the bag full
eqx_put:    call eqx_m
            ld a, [e_row]
            call e_slotof
            ld [e_slot], a
            ld a, [e_inv]
            add a, low(GS + $C0)
            ld l, a
            ld h, high(GS + $C0)
            ld a, [hl]
            ld [e_item], a
            ld a, [e_slot]
            cp 3
            jr c, .tk
            xor 6                           ; the other hand: the combination table
            ld b, a
            ld a, [m_ch]
            add a, b
            ld l, a
            ld h, high(GS + $200)
            ld a, [hl]
            and a
            jr z, .tk
            call e_wtype
            ld b, a
            ld a, [e_item]
            call e_wtype
            add a, a
            add a, a
            or b
            ld l, a
            ld h, 0
            ld de, e_list.comb
            add hl, de
            ld a, [hl]
            and a
            ld a, 1
            jr nz, .r
.tk:        ld a, [e_item]                  ; (the bag index can move when the old item goes in:
            push af                         ;   found again after)
            ld a, [e_row]
            call e_take
            pop bc
            ld a, $FF
            jr c, .r
            ld c, 0
.fi:        ld a, c
            add a, low(GS + $C0)
            ld l, a
            ld h, high(GS + $C0)
            ld a, [hl]
            cp b
            jr z, .got
            inc c
            ld a, c
            cp 32
            jr nz, .fi
            xor a
            jr .r
.got:       ld a, c
            ld [e_inv], a
            call e_list.put
            xor a
.r:         ld [u_eres], a
            ret
; Optimize: each slot the strongest the job can wear (item byte 2: attack / defense); the right
; hand a weapon (not arrows), the left the bow's arrows, else a shield
eqx_opt:    call eqx_m
            ld a, 2                         ; head, body, arms
.ar:        ld [e_row], a
            call .best0
            ld a, [e_row]
            inc a
            cp 5
            jr nz, .ar
            xor a                           ; the hands: both off first
            ld [e_row], a
            call e_take
            ld a, 1
            ld [e_row], a
            call e_take
            xor a
            ld [e_row], a
            ld a, $00                       ; right: weapons $01-$4E, $57 (not arrows, shields)
            ld [eqx_lo], a
            ld a, $4F
            ld [eqx_hi], a
            call .best
            ld a, 1
            ld [e_row], a
            ld a, [m_ch]                    ; left: arrows for a bow, else a shield
            add a, 3
            ld l, a
            ld h, high(GS + $200)
            ld a, [hl]
            cp $4A
            jr c, .sh
            cp $4F
            jr nc, .sh
            ld a, $4F
            ld [eqx_lo], a
            ld a, $57
            ld [eqx_hi], a
            jr .best
.sh:        ld a, $58
            ld [eqx_lo], a
            ld a, $62
            ld [eqx_hi], a
            jr .best
.best0:     xor a                           ; (armour: any fitting id)
            ld [eqx_lo], a
            ld a, $FF
            ld [eqx_hi], a
            ld a, [e_row]
            call e_take
; the strongest bag item for row e_row with an id in [eqx_lo, eqx_hi) the job can wear, put on
.best:      ld a, [e_row]
            call e_slotof
            ld [e_slot], a
            ld a, $FF
            ld [e_inv], a
            xor a
            ld [e_tmp], a                   ; (the best value + 1)
            ld c, 0
.bl:        push bc
            ld a, c
            add a, low(GS + $C0)
            ld l, a
            ld h, high(GS + $C0)
            ld a, [hl]
            and a
            jr z, .bn
            ld b, a
            ld a, [eqx_lo]                  ; (b < lo or b >= hi: skipped)
            ld c, a
            ld a, b
            cp c
            jr c, .bn
            ld a, [eqx_hi]
            ld c, a
            ld a, b
            cp c
            jr nc, .bn
            push af
            call e_fits
            jr nc, .bp
            pop af
            push af
            call can_equip
            jr z, .bp
            pop af
            ld l, a                         ; its byte 2 (GAME_BANK $6000 + 8 id + 2)
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, $6002
            add hl, de
            ld a, GAME_BANK
            call rd_byte
            inc a
            ld b, a
            ld a, [e_tmp]
            cp b
            jr nc, .bn
            ld a, b
            ld [e_tmp], a
            pop bc
            push bc
            ld a, c
            ld [e_inv], a
            jr .bn
.bp:        pop af
.bn:        pop bc
            inc c
            ld a, c
            cp 32
            jr nz, .bl
            ld a, [e_inv]
            cp $FF
            ret z
            add a, low(GS + $C0)            ; (its id, for the put)
            ld l, a
            ld h, high(GS + $C0)
            ld a, [hl]
            ld [e_item], a
            jp e_list.put

; the screen
e_draw:     call m_clear
            ld bc, $0000
            ld de, $1404
            call m_box
            ld a, [m_ch]
            add a, 6
            ld l, a
            ld h, high(GS + $100)
            ld bc, $0101
            ld e, 6
            call m_codes
            ld hl, s_atk
            ld bc, $0202
            call m_str
            call st_atk
            ld bc, $1102
            call m_dec
            ld hl, s_def
            ld bc, $0203
            call m_str
            call st_def
            ld bc, $1103
            call m_dec
            ld bc, $0004
            ld de, $1408
            call m_box
            xor a
.r:         ld [e_tmp], a
            add a, 5
            ld c, a
            ld a, [e_tmp]
            call e_slotof
            ld b, a
            ld a, [m_ch]
            add a, b
            ld l, a
            ld h, high(GS + $200)
            ld a, [hl]
            and a
            jr z, .lab
            push hl
            ld b, 2
            call it_name
            pop hl
            ld a, [e_tmp]                   ; (the hands: ": count")
            cp 2
            jr nc, .nx
            inc l
            ld e, [hl]
            ld d, 0
            ld b, 16
            ld a, $C8
            call m_put
            ld b, 18
            call m_dec
            jr .nx
.lab:       ld a, [e_tmp]
            add a, a
            ld l, a
            ld h, 0
            ld de, .labs
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld b, 3
            call m_str
.nx:        ld a, [e_tmp]
            inc a
            cp 5
            jr nz, .r
            ld hl, s_rem
            ld bc, $020A
            call m_str
            ld a, 1
            ld [m_dirty], a
            ret
.labs:      dw s_rh, s_lh, s_head, s_body, s_arms

; the inventory items for slot e_slot (hands: weapons and shields $00-$61; head $62-$71; body
; $72-$8A; arms $8B-$97), one a row in the lower window; A equips (3C/9C3C)
e_list:     ld bc, $000C                    ; the list window (rows 12-17)
            ld de, $1406
            call m_box
            ld hl, e_ids                    ; the matching slots
            ld b, 0
            ld c, 0
.f:         ld a, c
            add a, low(GS + $C0)
            ld e, a
            ld d, high(GS + $C0)
            ld a, [de]
            and a
            jr z, .n
            call e_fits
            jr nc, .n
            ld [hl], c
            inc hl
            inc b
.n:         inc c
            ld a, c
            cp 32
            jr nz, .f
            ld a, b
            ld [e_cnt], a
            and a
            ret z
            xor a
            ld [e_sel], a
            ld [e_top], a
.draw:      call e_ldraw
.l:         ld a, [e_sel]
            ld b, a
            ld a, [e_top]
            ld c, a
            ld a, b
            sub c
            add a, 13
            add a, a
            add a, a
            add a, a
            add a, 16 - 4
            ld c, a
            ld b, 8
            call cursor_at
            call wait_vbl
            call read_pad
            call m_keys
            ld a, [m_new]
            bit 1, a
            ret nz
            bit 0, a
            jr nz, .a
            ld b, a
            ld a, [e_sel]
            bit 6, b
            jr z, .d
            and a
            jr z, .l
            dec a
            ld [e_sel], a
            ld b, a
            ld a, [e_top]
            cp b
            jr c, .l
            jr z, .l
            ld a, b
            ld [e_top], a
            jr .draw
.d:         bit 7, b
            jr z, .l
            inc a
            ld b, a
            ld a, [e_cnt]
            cp b
            jr z, .l
            ld a, b
            ld [e_sel], a
            ld a, [e_top]
            add a, 3
            cp b
            jr nc, .l
            ld a, b
            sub 3
            ld [e_top], a
            jr .draw
.a:         ld a, [e_sel]
            ld l, a
            ld h, 0
            ld de, e_ids
            add hl, de
            ld a, [hl]
            ld [e_inv], a
            add a, low(GS + $C0)
            ld l, a
            ld h, high(GS + $C0)
            ld a, [hl]
            ld [e_item], a
            call can_equip
            jr z, .cant
            ld a, [e_slot]
            cp 3
            jr c, .put
            xor 6                           ; the other hand: the combination table 3C/9D4B
            ld b, a
            ld a, [m_ch]
            add a, b
            ld l, a
            ld h, high(GS + $200)
            ld a, [hl]
            and a
            jr z, .put
            call e_wtype
            ld b, a
            ld a, [e_item]
            call e_wtype
            add a, a
            add a, a
            or b
            ld l, a
            ld h, 0
            ld de, .comb
            add hl, de
            ld a, [hl]
            and a
            jr nz, .cant
.put:       ld a, [e_inv]                   ; the count: arrows up to 20, else 1
            add a, low(GS + $E0)
            ld l, a
            ld h, high(GS + $E0)
            ld c, 1
            ld a, [e_item]
            cp $4F
            jr c, .q
            cp $57
            jr nc, .q
            ld a, [hl]
            ld c, a
            cp 21
            jr c, .q
            ld c, 20
.q:         ld a, [hl]                      ; from the inventory
            sub c
            ld [hl], a
            jr nz, .k
            ld a, l
            sub $20
            ld l, a
            ld [hl], 0
.k:         ld a, [e_slot]
            ld b, a
            ld a, [m_ch]
            add a, b
            ld l, a
            ld h, high(GS + $200)
            ld a, [e_item]
            ld [hl], a
            ld a, b
            cp 3
            ret c
            inc l
            ld [hl], c
            ret
.cant:      ld a, $6F                       ; "Can't equip."
            jp m_msgbox
.comb:      db 0, 1, 1, 1, 1, 1, 0, 1, 1, 0, 1, 1, 1, 1, 1, 1
; 3C/9D2F: 3 harp, 1 bow, 2 arrows, 0 other
e_wtype:    cp $46
            jr c, .o
            cp $4A
            jr nc, .b
            ld a, 3
            ret
.b:         cp $4F
            jr nc, .ar
            ld a, 1
            ret
.ar:        cp $57
            jr nc, .o
            ld a, 2
            ret
.o:         xor a
            ret
; does item A fit slot e_slot? (carry)
e_fits:     ld e, a
            ld a, [e_slot]
            cp 3
            jr nc, .w
            and a
            jr nz, .b
            ld a, e                         ; head $62-$71
            cp $62
            ccf
            ret nc
            cp $72
            ret
.b:         dec a
            jr nz, .g
            ld a, e                         ; body $72-$8A
            cp $72
            ccf
            ret nc
            cp $8B
            ret
.g:         ld a, e                         ; arms $8B-$97
            cp $8B
            ccf
            ret nc
            cp $98
            ret
.w:         ld a, e                         ; hands: $00-$61
            cp $62
            ret
; the list rows (4 visible, rows 13-16)
e_ldraw:    ld a, [e_top]
            ld [e_tmp], a
            ld c, 13
.r:         push bc
            ld b, 1                         ; (clear the row)
            ld e, 18
            ld a, $FF
.cl:        call m_put
            inc b
            dec e
            jr nz, .cl
            pop bc
            ld a, [e_tmp]
            ld b, a
            ld a, [e_cnt]
            cp b
            jr z, .n
            jr c, .n
            push bc
            ld l, b
            ld h, 0
            ld de, e_ids
            add hl, de
            ld a, [hl]
            call it_row
            pop bc
.n:         ld hl, e_tmp
            inc [hl]
            inc c
            ld a, c
            cp 17
            jr nz, .r
            ld a, 1
            ld [m_dirty], a
            ret

section wram, $C0D8
eq_bonr:    ds 1                            ; bonus attack right / left (battle block +$38 / $39)
eq_bonl:    ds 1
eq_type:    ds 1                            ; weapon type (battle block +$33)
eq_hr:      ds 1                            ; hand types (+$31 / $32)
eq_hl:      ds 1

section wram, $CEC0
e_row:      ds 1
e_slot:     ds 1
e_tmp:      ds 1
e_cnt:      ds 1
e_sel:      ds 1
e_top:      ds 1
e_inv:      ds 1
e_item:     ds 1
e_ids:      ds 32
