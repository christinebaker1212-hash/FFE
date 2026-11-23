; ---- 35/BB49 battle victory: each monster type's experience (split among the living), gil,
; capacity and item drops; the messages; each living member's job experience (commands used x
; the job's multipliers) and job level, experience and level ups (39/A0B0, max hp from vitality,
; the job's stat bonuses 39/A1D6, MP); then the end of the battle (34/8306, 8170): equipment,
; status / hp / mp back to the save block, rows, the inventory consolidated.
BD_MITEMS  = $7100              ; BDATA: 10/9B80 monster item sets (8 bytes)
BD_MEXPID  = $7200              ;   10/9C80 monster experience id
BD_MEXP    = $7300              ;   10/9D80 experience values (2 bytes)
BD2_GOLD   = $5C58              ; BDATA2: 30/9C58 monster gold (2 bytes)
JB_CP      = $52AE              ; JOB_BANK: 39/B2AE monster capacity
JB_LVEXP   = $40B0              ;   39/A0B0 experience by level (3 bytes)
JB_LVBON   = $41D6              ;   39/A1D6 level up bonuses (job x 196 + level x 2)

victory:    xor a
            ld [W7 + $7570], a
            ld [W7 + $7571], a
            ld [BZ + $52], a
            ld b, a                         ; living members -> $53
.lv:        push bc
            call chr_ofs
            inc a
            ld c, a
            ld a, $5B
            call zpy
            pop bc
            ld a, [hl]
            and $C0
            jr nz, .lv1
            inc b
.lv1:       ld a, [BZ + $52]
            inc a
            ld [BZ + $52], a
            cp 4
            jr nz, .lv
            ld a, b
            ld [BZ + $53], a
            xor a
            ld [BZ + $52], a
            ld hl, W7 + $7400               ; $7400-$7433 cleared, $7434-$747F $FF
            ld b, $34
.c0:        ld [hl+], a
            dec b
            jr nz, .c0
            ld a, $FF
            ld b, $80 - $34
.c1:        ld [hl+], a
            dec b
            jr nz, .c1
.type:      ld a, [W7 + $7570]              ; each type with experience
            ld e, a
            ld d, 0
            ld hl, W7 + $7DD3
            add hl, de
            ld a, [hl]
            ld [BZ + $2C], a
            and a
            jp z, .ntype
            ld hl, W7 + $7D6B
            add hl, de
            ld a, [hl]
            ld [BZ + $32], a
            ld [BZ + $18], a
            ld e, a                         ; experience id -> $7400
            ld d, 0
            ld hl, BD_MEXPID
            add hl, de
            call bd_rd
            ld [W7 + $7400], a
            ld [BZ + $18], a
            ld l, a                         ; experience -> $7401
            ld h, 0
            add hl, hl
            ld de, BD_MEXP
            add hl, de
            ld de, W7 + $7401
            ld bc, 2
            ld a, BDATA_BANK
            call rd_copy
            ld a, [BZ + $32]                ; monster properties -> $7403
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, BD2_MON
            add hl, de
            ld de, W7 + $7403
            ld bc, 16
            ld a, BDATA2_BANK
            call rd_copy
            ld a, [W7 + $7412]              ; item set -> $7413
            and $1F
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, BD_MITEMS
            add hl, de
            ld de, W7 + $7413
            ld bc, 8
            ld a, BDATA_BANK
            call rd_copy
            ld a, [BZ + $32]                ; gold -> $741B
            ld l, a
            ld h, 0
            add hl, hl
            ld de, BD2_GOLD
            add hl, de
            ld de, W7 + $741B
            ld bc, 2
            ld a, BDATA2_BANK
            call rd_copy
            ld a, [BZ + $32]                ; capacity -> $741D
            ld e, a
            ld d, 0
            ld hl, JB_CP
            add hl, de
            ld a, JOB_BANK
            call rd_byte
            ld [W7 + $741D], a
            ld a, [BZ + $32]                ; (FFDA6's last $18 / $1A / $20 / $21)
            ld [BZ + $18], a
            ld a, 1
            ld [BZ + $1A], a
            ld a, $AE
            ld [BZ + $20], a
            ld a, $B2
            ld [BZ + $21], a
            ld a, [W7 + $7401]              ; experience / the living
            ld [BZ + $18], a
            ld a, [W7 + $7402]
            ld [BZ + $19], a
            ld a, [BZ + $53]
            ld [BZ + $1A], a
            xor a
            ld [BZ + $1B], a
            call bdiv16
            ld a, [BZ + $1C]
            ld [W7 + $7401], a
            ld a, [BZ + $1D]
            ld [W7 + $7402], a
.mon:       ld hl, W7 + $7424               ; each monster of the type: experience, gil
            ld a, [W7 + $7401]
            add a, [hl]
            ld [hl+], a
            ld a, [W7 + $7402]
            adc a, [hl]
            ld [hl+], a
            ld a, 0
            adc a, [hl]
            ld [hl+], a
            ld a, [W7 + $741B]
            add a, [hl]
            ld [hl+], a
            ld a, [W7 + $741C]
            adc a, [hl]
            ld [hl+], a
            ld a, 0
            adc a, [hl]
            ld [hl], a
            ld a, [W7 + $7412]              ; a drop: (0..6) < the set's rate
            swap a
            rrca
            and 7
            ld [BZ + $2E], a
            ld a, 6
            call rnd_0a
            ld b, a
            ld a, [BZ + $2E]
            ld c, a
            ld a, b
            cp c
            jr nc, .cp
            ld a, $FF                       ; which of the 8 (48 48 48 48 24 24 12 4 / 256)
            call rnd_0a
            ld hl, drop_t
            ld b, 0
.dp:        cp [hl]
            jr c, .dp1
            inc hl
            inc b
            ld c, a
            ld a, b
            cp 7
            ld a, c
            jr nz, .dp
.dp1:       ld e, b
            ld d, 0
            ld hl, W7 + $7413
            add hl, de
            ld a, [hl]
            and a
            jr z, .cp
            call give_item
            jr nc, .cp
            ld b, a
            ld a, [W7 + $7571]
            cp $30
            jr nc, .cp
            ld e, a
            ld d, 0
            ld hl, W7 + $7434
            add hl, de
            ld [hl], b
            ld hl, W7 + $7571
            inc [hl]
.cp:        ld a, [W7 + $741D]
            ld b, a
            ld a, [W7 + $742A]
            add a, b
            ld [W7 + $742A], a
            ld hl, BZ + $2C
            dec [hl]
            jp nz, .mon
.ntype:     ld hl, W7 + $7570
            inc [hl]
            ld a, [hl]
            cp 4
            jp nz, .type
            ld hl, GS + $1C                 ; gil
            ld a, [W7 + $7427]
            add a, [hl]
            ld [hl+], a
            ld a, [W7 + $7428]
            adc a, [hl]
            ld [hl+], a
            ld a, [W7 + $7429]
            adc a, [hl]
            ld [hl], a
            ld a, [W7 + $742A]              ; capacity / 4 + 1 (255 at most)
            and a
            jr z, .msg
            srl a
            srl a
            inc a
            ld [W7 + $742A], a
            ld b, a
            ld a, [GS + $1B]
            add a, b
            jr nc, .cp1
            ld a, $FF
.cp1:       ld [GS + $1B], a
.msg:       ld a, 2                         ; Gil, Capacity, EXP, the items found
            ld [W7 + $78D5], a
            ld [W7 + $7EC2], a
            ld a, [W7 + $7427]
            ld [W7 + $78E4], a
            ld a, [W7 + $7428]
            ld [W7 + $78E5], a
            ld a, $2D
            call .say
            ld a, [W7 + $742A]
            ld [W7 + $78E4], a
            xor a
            ld [W7 + $78E5], a
            ld a, $2E
            call .say
            ld a, [W7 + $7424]
            ld [W7 + $78E4], a
            ld a, [W7 + $7425]
            ld [W7 + $78E5], a
            ld a, $40
            call .say
            xor a
            ld [BZ + $3C], a
.it:        ld a, [BZ + $3C]
            ld e, a
            ld d, 0
            ld hl, W7 + $7434
            add hl, de
            ld a, [hl]
            cp $FF
            jr z, .chr
            ld [W7 + $78E4], a
            ld a, $29
            call .say
            ld hl, BZ + $3C
            inc [hl]
            jr .it
.chr:       call chr_ofs                    ; each living member
            inc a
            ld c, a
            ld a, $5B
            call zpy
            ld a, [hl]
            and $C0
            jp nz, .next
            xor a
            ld [BZ + $1E], a
            ld [BZ + $1F], a
            ld [BZ + $20], a
            ld a, [BZ + $52]
            add a, a
            add a, a
            ld [BZ + $1C], a
            ld a, [BZ + $5F]
            add a, $35
            ld c, a
            ld a, $5B
            call zpy
            ld a, [hl]
            ld [BZ + $22], a
.je:        ld a, [BZ + $22]                ; job experience: uses x 2 bits each
            ld b, 0
            add a, a
            rl b
            add a, a
            rl b
            ld [BZ + $22], a
            ld a, b
            ld [BZ + $23], a
            ld b, a
            ld a, [BZ + $1C]
            ld e, a
            ld d, 0
            ld hl, W7 + $78F0
            add hl, de
            ld a, [hl]
            call bmul8
            ld [BZ + $1A], a
            ld e, a
            ld a, b
            ld [BZ + $1B], a
            ld d, a
            ld a, [BZ + $1E]
            add a, e
            ld [BZ + $1E], a
            ld a, [BZ + $1F]
            adc a, d
            ld [BZ + $1F], a
            ld hl, BZ + $1C
            inc [hl]
            ld hl, BZ + $20
            inc [hl]
            ld a, [hl]
            cp 4
            jr nz, .je
            ld hl, BZ + $1E                 ; x 4, + the job experience
            sla [hl]
            inc hl
            rl [hl]
            dec hl
            sla [hl]
            inc hl
            rl [hl]
            ld a, [BZ + $5F]
            add a, $11
            ld c, a
            ld a, $57
            call zpy
            ld a, [BZ + $1E]
            add a, [hl]
            ld [BZ + $1E], a
            ld [hl], a
            ld a, [BZ + $1F]
            adc a, 0
            ld [BZ + $1F], a
            ld a, [BZ + $1E]
            sub $64
            ld a, [BZ + $1F]
            sbc 0
            jr c, .ex
            ld [hl], 0                      ; 100: the job level + 1 (99 at most)
            dec hl
            ld a, [hl]
            inc a
            cp $63
            jr nc, .ex
            ld [hl], a
            ld a, 4
            ld [W7 + $78D5], a
            ld a, [BZ + $52]
            ld [W7 + $78D6], a
            ld a, $22                       ; Skill up!
            ld [W7 + $78DA], a
            call act_script
.ex:        ld a, [BZ + $5F]                ; experience (9,999,999 at most)
            add a, 3
            ld c, a
            ld a, $57
            call zpy
            ld a, [W7 + $7424]
            add a, [hl]
            ld [BZ + $2F], a
            ld [hl+], a
            ld a, [W7 + $7425]
            adc a, [hl]
            ld [BZ + $30], a
            ld [hl+], a
            ld a, [W7 + $7426]
            adc a, [hl]
            ld [BZ + $31], a
            ld [hl-], a
            dec hl
            ld a, [hl+]                     ; (FF3: sbc with the carry of the last adc)
            ccf
            sbc $7F
            ld a, [hl+]
            sbc $96
            ld a, [hl]
            sbc $98
            jr c, .lvl
            ld a, $98
            ld [hl-], a
            ld [BZ + $31], a
            ld a, $99
            ld [hl-], a
            ld [BZ + $30], a
            ld a, $7F
            ld [hl], a
            ld [BZ + $2F], a
.lvl:       ld a, [BZ + $5F]                ; the next level's experience (39/A0B0 + 3 level)
            inc a
            ld c, a
            ld a, $57
            call zpy
            ld a, [hl]
            ld [BZ + $18], a
            ld l, a
            ld h, 0
            ld e, l
            ld d, h
            add hl, hl
            add hl, de
            ld de, JB_LVEXP
            add hl, de
            ld de, W7 + $741E
            ld bc, 3
            ld a, JOB_BANK
            call rd_copy
            ld a, 3
            ld [BZ + $1A], a
            ld a, [BZ + $2F]
            ld hl, W7 + $741E
            sub [hl]
            inc hl
            ld a, [BZ + $30]
            sbc [hl]
            inc hl
            ld a, [BZ + $31]
            sbc [hl]
            jp c, .next
            ld a, [BZ + $5F]
            inc a
            ld c, a
            ld a, $57
            call zpy
            ld a, [hl]
            ld [BZ + $32], a
            inc a
            cp $63
            jp nc, .next
            ld [hl], a
            ld a, [BZ + $5F]                ; max hp + vitality x (1..1.5) + level x 2
            add a, $14
            ld c, a
            ld a, $57
            call zpy
            ld a, [hl]
            ld [BZ + $24], a
            srl a
            call rnd_0a
            ld b, a
            ld a, [BZ + $24]
            add a, b
            ld [BZ + $24], a
            ld a, [BZ + $5F]
            inc a
            ld c, a
            ld a, $57
            call zpy
            ld a, [hl]
            add a, a
            ld b, a
            ld a, [BZ + $24]
            add a, b
            ld [BZ + $24], a
            ld b, a
            ld a, [BZ + $5F]
            add a, $0E
            ld c, a
            ld a, $57
            call zpy
            ld a, [hl]
            add a, b
            ld [hl+], a
            ld a, [hl]
            adc a, 0
            ld [hl-], a
            ld a, [hl+]
            sub $0F
            ld a, [hl]
            sbc $27
            jr c, .bon
            ld [hl], $27
            dec hl
            ld [hl], $0F
.bon:       ld a, [BZ + $5F]                ; the job's bonuses at the old level
            ld c, a
            ld a, $57
            call zpy
            ld a, [hl]
            ld [BZ + $18], a
            ld a, $C4
            ld [BZ + $1A], a
            xor a
            ld [BZ + $19], a
            ld [BZ + $1B], a
            call bmul16
            ld a, [BZ + $1C]
            ld l, a
            ld a, [BZ + $1D]
            ld h, a
            ld de, JB_LVBON
            add hl, de
            ld a, [BZ + $32]
            add a, a
            ld e, a
            ld d, 0
            add hl, de
            ld de, W7 + $7421
            ld bc, 2
            ld a, JOB_BANK
            call rd_copy
            ld a, [W7 + $7421]
            call lv_stats
            ld a, [BZ + $5F]                ; MP: + 1 for each bit of $7422 (99 at most)
            add a, $31
            ld c, a
            ld a, $57
            call zpy
            ld b, 8
.mp:        ld a, [W7 + $7422]
            srl a
            ld [W7 + $7422], a
            jr nc, .mp1
            ld a, [hl]
            inc a
            cp $64
            jr nc, .mp1
            ld [hl], a
.mp1:       inc hl
            inc hl
            dec b
            jr nz, .mp
            ld a, 4                         ; Level up!
            ld [W7 + $78D5], a
            ld a, [BZ + $52]
            ld [W7 + $78D6], a
            ld a, $20
            ld [W7 + $78DA], a
            call act_script
.next:      ld a, [BZ + $52]
            inc a
            ld [BZ + $52], a
            cp 4
            jp nz, .chr
            ret
.say:       ld [W7 + $78DA], a
            jp act_script
drop_t:     db $30, $60, $90, $C0, $D8, $F0, $FC

; 35/BF7C add level up stat bonuses: A = 5 stat bits + the amount (bits 0-2), to the stats
; ($12-) and their base copies (+5), 99 at most
lv_stats:   ld [BZ + $19], a
            and 7
            ld [BZ + $18], a
            ld a, [BZ + $5F]
            add a, $12
            ld c, a
            ld a, $57
            call zpy
            ld b, 5
.s:         ld a, [BZ + $19]
            add a, a
            ld [BZ + $19], a
            jr nc, .n
            push hl
            call .add
            ld de, 5
            add hl, de
            call .add
            pop hl
.n:         inc hl
            dec b
            jr nz, .s
            ret
.add:       ld a, [BZ + $18]
            add a, [hl]
            cp $64
            jr c, .a
            ld a, $63
.a:         ld [hl], a
            ret

; 35/BFB3 give item A (the inventory as pairs at $60C0): carry clear if full; A kept
give_item:  ld [BZ + $18], a
            ld b, a
            ld hl, GS + $C0
            ld c, 0
.f:         ld a, [hl]
            cp b
            jr nz, .fn
            inc hl
            inc c
            ld a, [hl]
            inc a
            cp $64
            jr nc, .e0                      ; (99: FF3 goes on looking from the odd byte)
            ld [hl], a
            jr .ok
.fn:        inc hl
            inc hl
            inc c
            inc c
            ld a, c
            cp $40
            jr nz, .f
            ld c, 0
.e0:        ld a, c
            ld e, a
            ld d, 0
            ld hl, GS + $C0
            add hl, de
.e:         ld a, [hl]
            and a
            jr nz, .en
            ld [hl], b
            inc hl
            inc [hl]
            jr .ok
.en:        inc hl
            inc hl
            inc c
            inc c
            ld a, c
            cp $40
            jr nz, .e
            ld a, b
            and a
            ret
.ok:        ld a, b
            scf
            ret

; ---- 34/8306: equipment updated, each member's status, hp and MP back to the save block
btl_save:   xor a
            ld [BZ + $52], a
.e:         call beq_update
            ld hl, BZ + $52
            inc [hl]
            ld a, [hl]
            cp 4
            jr nz, .e
            xor a
            ld [BZ + $52], a
.m:         call chr_ofs
            inc a
            ld c, a
            ld a, $5B
            call zpy
            ld a, [hl+]
            and $FE
            ld [BZ + $18], a
            inc hl
            ld a, [hl+]
            ld [BZ + $19], a
            ld a, [hl+]
            ld [BZ + $1A], a
            inc hl
            inc hl
            ld de, BZ + $1B                 ; MP (+7..)
            ld bc, 8
            call memcpy
            ld a, [BZ + $5F]
            add a, 2
            ld c, a
            ld a, $57
            call zpy
            ld a, [BZ + $18]
            ld [hl], a
            ld a, [BZ + $5F]
            add a, $0C
            ld c, a
            ld a, $57
            call zpy
            ld a, [BZ + $19]
            ld [hl+], a
            ld a, [BZ + $1A]
            ld [hl], a
            ld a, [BZ + $5F]
            add a, $30
            ld c, a
            ld a, $57
            call zpy
            ld de, BZ + $1B
            ld b, 8
.mp:        ld a, [de]
            inc de
            ld [hl+], a
            inc hl
            dec b
            jr nz, .mp
            ld hl, BZ + $52
            inc [hl]
            ld a, [hl]
            cp 4
            jr nz, .m
            ret

; 34/88A4 toggle front / back row for all members (the save block's and the battle's)
rows_flip:  xor a
            ld [BZ + $52], a
.m:         call chr_ofs
            add a, $0F
            ld c, a
            ld a, $59
            call zpy
            call .t
            call chr_ofs
            add a, $33
            ld c, a
            ld a, $5B
            call zpy
            call .t
            ld hl, BZ + $52
            inc [hl]
            ld a, [hl]
            cp 4
            jr nz, .m
            xor a
            ld [BZ + $52], a
            ret
.t:         ld a, [hl]
            and 1
            xor 1
            ld [BZ + $21], a
            ld b, a
            ld a, [hl]
            and $FE
            or b
            ld [hl], a
            ret

; 31/BEBF consolidate inventory: like items together (99 at most), sorted by id from $FF down
consol:     ld hl, W7 + $7280
            ld de, $0200
            call memclr
            ld hl, GS + $C0
            ld b, $20
.c:         ld a, [hl+]
            ld e, a
            ld d, 0
            push hl
            ld hl, W7 + $7280
            add hl, de
            ld [hl], a
            pop hl
            ld a, [hl+]
            push hl
            ld hl, W7 + $7380
            add hl, de
            add a, [hl]
            cp $64
            jr c, .c1
            ld a, $63
.c1:        ld [hl], a
            pop hl
            dec b
            jr nz, .c
            ld hl, GS + $C0
            ld de, $40
            call memclr
            ld de, GS + $C0
            ld c, $FF
.s:         ld b, 0
            ld hl, W7 + $7280
            add hl, bc
            ld a, [hl]
            and a
            jr z, .n
            ld [de], a
            inc de
            ld hl, W7 + $7380
            add hl, bc
            ld a, [hl]
            and a
            jr nz, .q
            dec de
            xor a
            ld [de], a
            jr .n
.q:         ld [de], a
            inc de
.n:         dec c
            jr nz, .s
            ret

; 3C/BC12 / BC2D: the inventory ids / quantities ($60C0 / $60E0) as pairs for the battle, and
; back (through $7400 as FF3)
inv_pair:   ld hl, GS + $C0
            ld de, W7 + $7400
            ld bc, $40
            call memcpy
            ld hl, W7 + $7400
            ld de, GS + $C0
            ld b, $20
.p:         ld a, [hl]
            ld [de], a
            inc de
            push hl
            ld a, l
            add a, $20
            ld l, a
            ld a, [hl]
            pop hl
            ld [de], a
            inc de
            inc hl
            dec b
            jr nz, .p
            ret
inv_unpair: ld hl, GS + $C0
            ld de, W7 + $7400
            ld bc, $40
            call memcpy
            ld hl, W7 + $7400
            ld de, GS + $C0
            ld b, $20
.p:         ld a, [hl+]
            ld [de], a
            push de
            ld a, e
            add a, $20
            ld e, a
            ld a, [hl+]
            ld [de], a
            pop de
            inc de
            dec b
            jr nz, .p
            ret
