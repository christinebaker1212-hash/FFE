; ---- 31/A732 battle algorithm $02: choose monster actions (each slot's command +$2E, target
; +$2F / +$30): nothing (dead, stone, toad, mini), asleep / paralysed, run (much stronger party),
; barrier shift (Hein / Amon every 3 turns), a special attack (its rate; bosses in script order),
; else fight a random living, not jumping member (confused: a random monster).
BD2_ATK    = $58C0              ; BDATA2: 30/98C0 attack properties (8 bytes)

mon_think:  xor a
            ld [BZ + $4A], a
            ld [BZ + $69], a
.m:         xor a
            ld [BZ + $53], a                ; (confused)
            ld a, [BZ + $4A]                ; $24 = $7675 + $40 slot
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
            ld a, $24
            call zpset
            call ai_flags
            and $EF
            ld [hl], a
            ld c, $2F
            ld a, $24
            call zpy
            xor a
            ld [hl+], a
            ld [hl], a
            ld c, 1
            ld a, $24
            call zpy
            ld a, [hl+]
            and $E8
            jr z, .a1
            xor a                           ; dead, stone, toad, mini: nothing
            jp .set
.a1:        ld a, [hl]
            and $E0
            jr z, .a2
            and $20
            jr z, .slp
            ld hl, BZ + $53
            inc [hl]
            jp .spc
.slp:       ld a, 1
            jp .set
.a2:        ld a, [W7 + $7ED8]
            bit 7, a
            jp nz, .spc                     ; (a boss battle)
            ld c, 0                         ; the members' levels -> $28-$2B, sorted
            ld a, $5B
            call zpy
            ld de, BZ + $28
            ld b, 4
.lv:        ld a, [hl]
            ld [de], a
            inc de
            push de
            ld de, $40
            add hl, de
            pop de
            dec b
            jr nz, .lv
            call ai_sort
            ld c, 0
            ld a, $24
            call zpy
            ld a, [hl]
            add a, $0F
            jr c, .spc                      ; (level + 15 carries: not weaker)
            ld b, a
            ld a, [BZ + $28]
            ld c, a
            ld a, b
            cp c
            jr nc, .spc
            ld a, [W7 + $7ED8]
            and 1
            jr nz, .spc                     ; (can't run)
            ld a, 100
            call rnd_0a
            ld b, a
            ld c, $22
            ld a, $24
            call zpy
            ld a, b
            cp [hl]
            jr c, .spc
            ld a, 6                         ; run
            jp .set
.spc:       ld a, [BZ + $4A]                ; Hein ($D2) / Amon ($B4): barrier shift every 3 turns
            ld e, a
            ld d, 0
            ld hl, W7 + $7DA7
            add hl, de
            ld e, [hl]
            ld hl, W7 + $7D6B
            add hl, de
            ld a, [hl]
            cp $D2
            jr z, .hein
            cp $B4
            jr nz, .rate
.hein:      ld a, [W7 + $7BE2]
            cp 2
            jr nz, .rate
            call ai_flags
            or $10
            ld [hl], a
            ld a, $4D
            jp .set
.rate:      ld c, $37                       ; special attack rate
            ld a, $24
            call zpy
            ld a, [hl]
            and a
            jr z, .fight
            ld a, 100
            call rnd_0a
            ld b, a
            ld c, $37
            ld a, $24
            call zpy
            ld a, b
            cp [hl]
            jp c, .special
.fight:     ld a, [BZ + $53]
            and a
            jr z, .f1
            call ai_rndmon                  ; (confused: a random monster)
            ld a, 4
            jp .set
.f1:        xor a                           ; $65-$69 cleared
            ld hl, BZ + $65
            ld b, 5
.cl:        ld [hl+], a
            dec b
            jr nz, .cl
.f2:        xor a                           ; a member: random (0..3) with counter 0, then
            ld [BZ + $21], a                ;   another different one with counter 1
            ld b, 0
            ld a, 3
            call rnd_xa
            ld [BZ + $22], a
.f3:        ld a, 3
            call rnd_0a
            ld b, a
            ld a, [BZ + $22]
            cp b
            jr z, .f3
            ld a, b
            ld [BZ + $22], a
            ld [BZ + $52], a
            call chr_ofs
            inc a
            ld c, a
            ld a, $5B
            call zpy
            ld a, [hl+]
            and $C0
            jr nz, .f4
            ld a, [hl]
            and 1
            jr z, .f5
.f4:        ld a, [BZ + $22]                ; (dead / stone / jumping: marked; all four: nothing)
            ld e, a
            ld d, 0
            ld hl, BZ + $65
            add hl, de
            ld [hl], 1
            ld a, [BZ + $65]
            ld hl, BZ + $66
            add a, [hl]
            inc hl
            add a, [hl]
            inc hl
            add a, [hl]
            cp 4
            jr nz, .f2
            xor a
            jr .set
.f5:        ld a, [BZ + $52]
            call ai_target
            ld a, 4
            jr .set
.special:   call ai_flags                   ; 31/A85F: using magic
            or $10
            ld [hl], a
            ld a, [W7 + $7ED8]
            bit 7, a
            jr z, .sp_r
            ld a, [W7 + $78B7]              ; bosses: the script in order
            dec a
            add a, $38
            ld c, a
            ld a, $24
            call zpy
            ld a, [hl]
            push af
            and $7F
            ld [ai_cmd], a
            pop af
            call ai_spec
            ld a, [BZ + $69]
            and a
            jr nz, .sp_n
            ld hl, W7 + $78B7
            inc [hl]
            ld a, [hl]
            cp 9
            jr nz, .sp_ok
            ld [hl], 1
.sp_ok:     ld a, [ai_cmd]
            jr .set
.sp_r:      ld a, 7                         ; others: one of the eight at random
            call rnd_0a
            add a, $38
            ld c, a
            ld a, $24
            call zpy
            ld a, [hl]
            push af
            and $7F
            ld [ai_cmd], a
            pop af
            call ai_spec
            ld a, [BZ + $69]
            and a
            jr z, .sp_ok
.sp_n:      call ai_flags                   ; (no valid target: nothing)
            and $EF
            ld [hl], a
            xor a
.set:       push af
            ld c, $2E
            ld a, $24
            call zpy
            pop af
            ld [hl], a
            ld a, [BZ + $4A]
            inc a
            ld [BZ + $4A], a
            cp 8
            jp nz, .m
            ret

; 31/A8C8 get flags: HL = monster + $2C, A = its value
ai_flags:   ld c, $2C
            ld a, $24
            call zpy
            ld a, [hl]
            ret

; 31/A8CD target a random monster: +$30 = $80, +$2F = its bit
ai_rndmon:  ld c, $30
            ld a, $24
            call zpy
            ld [hl], $80
.r:         ld a, 7
            call rnd_0a
            ld e, a
            ld d, 0
            ld hl, W7 + $7DA7
            add hl, de
            ld a, [hl]
            cp $FF
            jr z, .r
            ld a, e
            ; (fall through)
; 31/A8E1 set target: +$2F = $80 >> A
ai_target:  call bitmask
            push af
            ld c, $2F
            ld a, $24
            call zpy
            pop af
            ld [hl], a
            ret

; 31/A8EC sort the members' levels $28-$2B: for Y 0-2, X Y+1-3, swap when [Y] >= [X] ($2C-$2F
; swapped alike)
ai_sort:    ld b, 0                         ; Y
.o:         ld c, b
.i:         inc c                           ; X
            ld a, c
            cp 4
            jr z, .on
            ld a, b
            add a, low(BZ + $28)
            ld l, a
            ld h, high(BZ + $28)
            ld a, c
            add a, low(BZ + $28)
            ld e, a
            ld d, h
            ld a, [de]
            cp [hl]
            jr z, .sw
            jr nc, .i                       ; ([Y] < [X]: kept)
.sw:        ld a, [de]
            push bc
            ld c, [hl]
            ld [hl], a
            ld a, c
            ld [de], a
            ld a, l
            add a, 4
            ld l, a
            ld a, e
            add a, 4
            ld e, a
            ld a, [de]
            ld c, [hl]
            ld [hl], a
            ld a, c
            ld [de], a
            pop bc
            jr .i
.on:        inc b
            ld a, b
            cp 3
            jr nz, .o
            ret

; 31/A91B choose target (monster special attack A, bit 7: the whole side)
ai_spec:    ld [BZ + $46], a
            and $7F
            ld l, a                         ; attack properties: 30/98C0 + 8 id -> $7400
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, BD2_ATK
            add hl, de
            ld de, W7 + $7400
            ld bc, 8
            ld a, BDATA2_BANK
            call rd_copy
            xor a
            ld hl, BZ + $62
            ld b, 8
.c:         ld [hl+], a
            dec b
            jr nz, .c
            ld a, [W7 + $7405]
            bit 7, a
            jp nz, .mon                     ; (targets its own side)
            ld a, [BZ + $53]
            and a
            jp nz, .mon                     ; (confused)
            ld a, [W7 + $7405]
            and $40
            jr z, .single
.multi:     ld [BZ + $63], a
.mm:        ld a, [BZ + $64]
            call ai_valid
            jr nz, .mn
            ld a, [BZ + $64]
            call bitmask
            ld b, a
            ld a, [BZ + $62]
            or b
            ld [BZ + $62], a
.mn:        ld hl, BZ + $64
            inc [hl]
            ld a, [hl]
            cp 4
            jr nz, .mm
            ld a, [BZ + $62]
            and a
            jr nz, .m2
            ld hl, BZ + $69
            inc [hl]
.m2:        ld a, $F0
            ld [BZ + $62], a
            jr .done
.single:    ld a, [BZ + $46]
            bit 7, a
            jr z, .s1
            ld a, $40
            jr .multi
.s1:        ld a, 3
            call rnd_0a
            ld [BZ + $22], a
.s2:        ld a, 3
            call rnd_0a
            ld b, a
            ld a, [BZ + $22]
            cp b
            jr z, .s2
            ld e, b
            ld d, 0
            ld hl, BZ + $65
            add hl, de
            ld [hl], 1
            push de
            ld a, e
            call ai_valid
            pop de
            jr z, .s3
            ld a, [BZ + $65]
            ld hl, BZ + $66
            add a, [hl]
            inc hl
            add a, [hl]
            inc hl
            add a, [hl]
            cp 4
            jr nz, .single
            ld hl, BZ + $69
            inc [hl]
            jr .done
.s3:        ld a, e
            call bitmask
            ld b, a
            ld a, [BZ + $62]
            or b
            ld [BZ + $62], a
            jr .done
.mon:       ld a, $80                       ; monster targets (cures, confused)
            ld [BZ + $63], a
            ld a, [W7 + $7405]
            and $40
            jr z, .mo1
            ld b, a
            ld a, [BZ + $63]
            or b
            ld [BZ + $63], a
            ld a, $FF
            ld [BZ + $62], a
            jr .done
.mo1:       ld a, 12
            call rnd_0a
            cp 4
            jr c, .mo1
            ld [BZ + $22], a
            call ai_valid
            jr nz, .mo1
            ld a, [BZ + $22]
            sub 4
            call bitmask
            ld b, a
            ld a, [BZ + $62]
            or b
            ld [BZ + $62], a
.done:      ld c, $2F
            ld a, $24
            call zpy
            ld a, [BZ + $62]
            ld [hl+], a
            ld a, [BZ + $63]
            ld [hl], a
            ret

; 31/A9F7 validate target A (an index into the $7575 records: members 0-3, monsters 4-11):
; NZ if dead / stone / jumping
ai_valid:   rrca
            rrca
            ld l, a
            and $C0
            ld e, a
            ld a, l
            and 3
            ld d, a
            ld hl, W7 + $7575 + 1
            add hl, de
            ld a, [hl+]
            and $C0
            ret nz
            ld a, [hl]
            and 1
            ret

section wram, $DFD0
ai_cmd:     ds 1
