; ---- the other actions (35/A68A asleep / paralysed, A7DF / A7EA rows, A8BF run, A93B escape,
; A9D8 / AA11 jump, AA5D terrain, AB73 peep, AB0C scan, ABA4 steal, AC6F buildup, ACD5 sing,
; AD16 scare, AD75 cheer, A3BB item) and 31/A65E do item effect, ported from the disassembly.

; 34/91CE clear target message
clr_tgt:    ld a, $FF
            ld [W7 + $78D8], a
            ret

; the attacker's buffer offset x 2 + 1 (status 2) -> HL = $F0 + it
atk_f0:     call atk_flags
            and 7
            add a, a
            inc a
            ld e, a
            ld d, 0
            ld hl, BZ + $F0
            add hl, de
            ret

; 35/A68A action $01: asleep / paralysed (members: sleep rate + 50, monsters: level + 50 in 100
; to wake; the counter in bits 3-4)
act_sleep:  call clr_tgt
            call atk_f0
            push hl
            ld c, 2
            ld a, $6E
            call zpy
            ld a, [hl]
            pop hl
            ld [hl], a
            call atk_flags
            ld c, $2B
            bit 7, a
            jr z, .p
            ld c, 0
.p:         ld a, $6E
            call zpy
            ld a, [hl]
            add a, $32
            ld [BZ + $24], a
            ld a, 100
            call rnd_0a
            ld b, a
            ld a, [BZ + $24]
            ld c, a
            ld a, b
            cp c
            jr nc, .stay
            call atk_f0                     ; 35/A6C6
            ld a, [hl]
            and $18
            sub 8
            and $18
            jr nz, .cnt
            ld a, [hl]
            push af
            and 7
            ld [hl], a
            push af
            ld c, 2
            ld a, $6E
            call zpy
            pop af
            ld [hl], a
            pop af
            ld b, 0
.f:         add a, a
            jr c, .f1
            inc b
            jr .f
.f1:        ld a, b
            add a, $54
            ld [W7 + $78D7], a
            ret
.cnt:       ld a, [hl]
            sub 8
            ld [hl], a
            push af
            ld c, 2
            ld a, $6E
            call zpy
            pop af
            ld [hl], a
.stay:      call atk_f0                     ; 35/A700
            ld a, [hl]
            ld b, 0
.g:         add a, a
            jr c, .g1
            inc b
            jr .g
.g1:        ld a, b
            add a, $5E
            ld [W7 + $78D7], a
            ret

; 35/A7DF / A7EA actions $02 / $03: front / back row (battle row and the save block's)
act_front:  ld a, $3B
            jr act_row
act_back:   ld a, $3C
act_row:    ld [W7 + $78D7], a
            call clr_tgt
            ld a, 1
            ld [W7 + $78D5], a
            ld c, $33
            ld a, $6E
            call zpy
            call .t
            call atk_flags
            and 7
            ld [BZ + $52], a
            call chr_ofs
            add a, $0F
            ld c, a
            ld a, $59
            call zpy
.t:         ld a, [hl]
            and 1
            xor 1
            ld [BZ + $18], a
            ld b, a
            ld a, [hl]
            and $FE
            or b
            ld [hl], a
            ret

; 35/A8BF action $06: run (members: run rate + 25 - the monsters' average level in 100; can't
; run battles; monsters: their run rate)
act_run:    ld a, 1
            ld [W7 + $78D5], a
            ld a, $3F
            ld [W7 + $78D7], a
            call clr_tgt
            call atk_flags
            bit 7, a
            jr nz, run_mon
            xor a
            ld [BZ + $18], a
            ld [BZ + $19], a
            ld [BZ + $1A], a
            ld [BZ + $1B], a
            ld hl, W7 + $7675
            ld de, W7 + $7DA7
            ld b, 8
.s:         ld a, [de]
            inc de
            cp $FF
            jr z, .s1
            ld a, [BZ + $18]
            add a, [hl]
            ld [BZ + $18], a
            ld a, [BZ + $19]
            adc a, 0
            ld [BZ + $19], a
            ld a, [BZ + $1A]
            inc a
            ld [BZ + $1A], a
.s1:        push bc
            ld bc, $40
            add hl, bc
            pop bc
            dec b
            jr nz, .s
            ld a, l
            ld [BZ + $24], a
            ld a, h
            ld [BZ + $25], a
            call bdiv16
            ld c, $2A
            ld a, $6E
            call zpy
            ld a, [hl]
            add a, $19
            ld b, a
            ld a, [BZ + $1C]
            ld c, a
            ld a, b
            sub c
            jr nc, .p
            xor a
.p:         ld [BZ + $24], a
            ld a, 100
            call rnd_0a
            ld b, a
            ld a, [BZ + $24]
            ld c, a
            ld a, b
            cp c
            jr c, run_ok
            ld a, [W7 + $78BA]
            and 1
            jr nz, run_ok
run_no:     ld a, $1F                       ; Can't run
            ld [W7 + $78DA], a
            ret
run_mon:    ld c, $22                       ; 35/A978
            ld a, $6E
            call zpy
            ld a, [hl]
            ld [BZ + $24], a
            ld a, 100
            call rnd_0a
            ld b, a
            ld a, [BZ + $24]
            ld c, a
            ld a, b
            cp c
            jr nc, run_no
            ld a, $1E                       ; Ran away
            ld [W7 + $78DA], a
            call atk_flags
            and 7
            push af
            add a, a
            ld e, a
            ld d, 0
            ld hl, BZ + $F0
            add hl, de
            set 7, [hl]
            pop af
            call bitmask
            ld [W7 + $78D4], a
            ret
; 35/A93B action $07: escape
act_escape: ld a, 1
            ld [W7 + $78D5], a
            ld a, $40
            ld [W7 + $78D7], a
            call clr_tgt
run_ok:     ld a, [W7 + $7ED8]              ; 35/A948 (not in can't run battles, nor with a
            and 1                           ;   member paralysed)
            jr nz, run_no
            xor a
.m:         ld [BZ + $52], a
            call chr_ofs
            add a, 2
            ld c, a
            ld a, $5B
            call zpy
            ld a, [hl]
            and $20
            jr nz, run_no
            ld a, [BZ + $52]
            inc a
            cp 4
            jr nz, .m
            ld a, $1E
            ld [W7 + $78DA], a
            ld a, 2
            ld [W7 + $78D3], a
            ld a, $F0
            ld [W7 + $78D4], a
            ret

; 35/A9D8 action $08: jump (up: 3x next time, jumping, the next action jump 2)
act_jump:   ld a, 1
            ld [W7 + $78D5], a
            ld a, $41
            ld [W7 + $78D7], a
            ld c, 1
            ld a, $6E
            call zpy
            ld a, [hl]
            and $28
            jr z, .j
            ld a, $18
            ld [W7 + $7EC2], a
            ld a, $3B
            ld [W7 + $78DA], a
            ret
.j:         ld c, $27
            ld a, $6E
            call zpy
            ld [hl], 2
            call atk_f0
            set 0, [hl]
            ld c, $29
            ld a, $6E
            call zpy
            ld [hl], 9
            ret
; 35/AA11 action $09: jump 2 (down: the fight effect, 3x)
act_jump2:  ld c, 2
            ld a, $6E
            call zpy
            res 0, [hl]
            ld c, $27
            ld a, $6E
            call zpy
            ld [hl], 2
            jp fight_eff

; 35/AA5D action $0B: terrain (the map's attack as magic; nothing hit: backfire, max hp / 4)
act_terrain: call atk_flags
            or $10
            ld [hl], a
            call terr_atk
            push af
            ld c, $2E
            ld a, $6E
            call zpy
            pop af
            ld [hl], a
            ld [BZ + $1A], a
            call act_magic
            ld hl, BZ + $CC
            inc [hl]
            ld a, $14
            ld [W7 + $7EC2], a
            ld a, [W7 + $7E9B]
            and a
            ret nz
            call atk_flags
            and 7
            add a, a
            ld [btl_tmp], a
            ld c, 5
            ld a, $6E
            call zpy
            ld a, [hl+]
            ld e, a
            ld d, [hl]
            srl d
            rr e
            srl d
            rr e
            ld a, e
            ld [BZ + $18], a
            ld a, d
            ld [BZ + $19], a
            ld c, 3
            ld a, $6E
            call zpy
            ld a, [hl]
            sub e
            ld [hl+], a
            ld a, [hl]
            sbc d
            ld [hl], a
            jr nc, .a
            xor a
            ld [hl-], a
            ld [hl], a
            ld a, [btl_tmp]
            ld e, a
            ld d, 0
            ld hl, BZ + $F0
            add hl, de
            ld [hl], $80
.a:         ld a, [btl_tmp]
            ld e, a
            ld d, 0
            ld hl, W7 + $7E5F
            add hl, de
            ld a, [BZ + $18]
            ld [hl+], a
            ld a, [BZ + $19]
            ld [hl], a
            ld a, 3
            ld [BZ + $54], a
            ret
; 35/AAC3 get terrain attack: by the battle bg (8+), else the map's (01/A24E: low nibble on
; the floating continent, high on the surface world) + $50
terr_atk:   ld a, [W7 + $7CE3]
            cp 8
            jr c, .a
            cp $12
            ld a, $55
            ret z
            ld a, [W7 + $74C8]
            ld e, a
            ld d, 0
            ld hl, BD_TERR
            add hl, de
            call bd_rd
            ld [W7 + $7400], a
            ld b, a
            ld a, [W7 + $7ED8]
            and 8
            ld a, b
            jr nz, .s
            and $0F
            jr .a
.s:         swap a
            and $0F
.a:         add a, $50
            ret

; 35/AB0C action $0D: scan (the target's weaknesses as messages)
act_scan:   call act_inef
            ld a, 1
            ld [W7 + $78D5], a
            ld a, $46
            ld [W7 + $78D7], a
            ld c, 1
            ld a, $70
            call zpy
            bit 7, [hl]
            jr z, .s
            ld a, $3B
            ld [W7 + $78DA], a
            ret
.s:         ld c, $12
            ld a, $70
            call zpy
            ld a, [hl]
            ld hl, W7 + $7400
            ld c, 0
            ld b, 7
.e:         add a, a
            jr nc, .e1
            ld [hl], c
            inc hl
.e1:        inc c
            dec b
            jr nz, .e
            ld [hl], $FF
            ld a, [W7 + $7400]
            bit 7, a
            jr z, .w
            ld a, $43                       ; No weak point
            call .q
            ret
.w:         ld hl, W7 + $7400
.l:         ld a, [hl+]
            cp $FF
            ret z
            add a, $48
            push hl
            call .q
            pop hl
            jr .l
.q:         push af
            ld a, [W7 + $78EE]
            ld e, a
            ld d, 0
            ld hl, W7 + $78DA
            add hl, de
            pop af
            ld [hl], a
            ld hl, W7 + $78EE
            inc [hl]
            ret
; 35/AB66 do ineffective action
act_inef:   ld a, $18
            ld [W7 + $7EC2], a
            ld hl, BZ + $CC
            inc [hl]
            ret

; 35/AB73 action $0C: peep (the target's hp)
act_peep:   call act_inef
            ld c, 3
            ld a, $70
            call zpy
            ld de, W7 + $78E4
            ld bc, 4
            call memcpy
            ld c, 1
            ld a, $70
            call zpy
            ld a, $3B
            bit 7, [hl]
            jr nz, .m
            ld a, $3F
.m:         ld [W7 + $78DA], a
            ld a, 1
            ld [W7 + $78D5], a
            ld a, $45
            ld [W7 + $78D7], a
            ret

; 35/ABA4 action $0E: steal ((level + job level) in 255; the item set's items 0-3 at 48 48 48
; 112 / 256)
act_steal:  call act_inef
            ld a, $47
            ld [W7 + $78D7], a
            ld a, 1
            ld [W7 + $78D5], a
            call tgt_flags
            bit 7, a
            jr nz, .m
.no:        ld a, $35                       ; Can't steal
            ld [W7 + $78DA], a
            ret
.m:         ld c, 0
            ld a, $6E
            call zpy
            ld a, [hl]
            ld c, $0F
            push af
            ld a, $6E
            call zpy
            pop af
            add a, [hl]
            ld [BZ + $24], a
            ld a, $FF
            call rnd_0a
            ld b, a
            ld a, [BZ + $24]
            ld c, a
            ld a, b
            cp c
            jr nc, .no
            ld c, 1
            ld a, $70
            call zpy
            ld a, [hl]
            and $E8
            jr nz, .no
            ld c, $36
            ld a, $70
            call zpy
            ld a, [hl]
            and $1F
            ld [BZ + $18], a
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, BD_MITEMS
            add hl, de
            ld de, W7 + $7400
            ld bc, 8
            ld a, BDATA_BANK
            call rd_copy
            ld a, $FF
            call rnd_0a
            ld b, 0
            cp $30
            jr c, .i
            inc b
            cp $60
            jr c, .i
            inc b
            cp $90
            jr c, .i
            inc b
.i:         ld e, b
            ld d, 0
            ld hl, W7 + $7400
            add hl, de
            ld a, [hl]
            and a
            jr z, .no
            ld [BZ + $25], a
            ld b, a
            ld hl, GS + $C0                 ; the inventory: the same item + 1 (99), else a free pair
            ld c, $20
.f:         ld a, [hl+]
            cp b
            jr nz, .fn
            inc [hl]
            ld a, [hl]
            cp $64
            jr c, .ok
            dec [hl]
            jr .no
.fn:        inc hl
            dec c
            jr nz, .f
            ld hl, GS + $C0
            ld c, $20
.e:         ld a, [hl]
            and a
            jr z, .put
            inc hl
            inc hl
            dec c
            jr nz, .e
            jr .no
.put:       ld [hl], b
            inc hl
            inc [hl]
.ok:        ld a, [BZ + $25]
            ld [W7 + $78E4], a
            ld a, $29                       ; Found
            ld [W7 + $78DA], a
            ret

; 35/AC6F action $0F: buildup (+1; a third: overloaded, hp / 2)
act_build:  ld a, $48
            ld [W7 + $78D7], a
            ld a, 1
            ld [W7 + $78D5], a
            ld c, 1
            ld a, $6E
            call zpy
            ld a, [hl]
            and $28
            jr nz, .inef
            ld c, $27
            ld a, $6E
            call zpy
            ld a, [hl]
            inc a
            cp 3
            jr c, .ok
            ld [hl], 0
            ld c, 3
            ld a, $6E
            call zpy
            inc hl
            srl [hl]
            dec hl
            rr [hl]
            ld a, [hl+]
            or [hl]
            jr nz, .o
            call atk_flags
            and 7
            add a, a
            ld e, a
            ld d, 0
            ld hl, BZ + $F0
            add hl, de
            set 7, [hl]
.o:         ld a, 1
            ld [W7 + $7E93], a
            ld a, $2F                       ; Overloaded!
            ld [W7 + $78DA], a
            ret
.ok:        ld [hl], a
            xor a
            ld [W7 + $7E93], a
            ret
.inef:      ld a, $3B
            ld [W7 + $78DA], a
            ret

; 35/ACD5 action $10: sing (a harp in a hand: fight with it; else "Needs a harp!")
act_sing:   call atk_flags
            and 7
            ld [BZ + $52], a
            call chr_ofs
            add a, 3
            ld c, a
            ld a, $59
            call zpy
            ld a, [hl+]
            cp $46
            jr c, .l
            cp $4A
            jp c, act_fight
.l:         inc hl
            ld a, [hl]
            cp $46
            jr c, .n
            cp $4A
            jp c, act_fight
.n:         ld a, 1
            ld [W7 + $78D5], a
            ld a, $42
            ld [W7 + $78DA], a
            ld a, $18
            ld [W7 + $7EC2], a
            ret

; 35/AD16 action $11: scare (every monster's level = the first's - 3; not in can't run battles)
act_scare:  ld a, 1
            ld [W7 + $78D5], a
            ld a, $4A
            ld [W7 + $78D7], a
            ld a, [W7 + $7ED8]
            and 1
            jr z, .s
            ld a, $3B
            ld [W7 + $78DA], a
            ret
.s:         ld a, 3
            ld [BZ + $24], a
            ld a, 7
            ld [BZ + $25], a
            ld c, 0
            ld a, $5D
            call zpy
            ld a, [hl]
            sub 3
            jr nc, .p
            xor a
.p:         ld [BZ + $24], a
            ld b, 8
            ld de, $40
.l:         ld [hl], a
            add hl, de
            dec b
            jr nz, .l
            ld a, $FF
            ld [BZ + $25], a
            ld hl, W7 + $7675
            ld a, $5D
            call zpset
            ld a, $32
            ld [W7 + $78DA], a
            jp clr_tgt

; 35/AD75 action $12: cheer (the members' attack + 10; at 255 the target message goes)
act_cheer:  ld a, 1
            ld [W7 + $78D5], a
            ld a, $4B
            ld [W7 + $78D7], a
            ld a, $31
            ld [W7 + $78DA], a
            ld hl, W7 + $7575 + $19
            ld b, 4
            ld de, $40
.l:         ld a, [hl]
            add a, $0A
            jr nc, .s
            ld a, $FF
            ld [W7 + $78D8], a
.s:         ld [hl], a
            add hl, de
            dec b
            jr nz, .l
            ld de, $FFE7                    ; (-$19: $18 = $7675 as FF3 leaves it)
            add hl, de
            ld a, l
            ld [BZ + $18], a
            ld a, h
            ld [BZ + $19], a
            ret

; 35/A3BB action $13: item ($1A: the item; phoenix down / soft keep dead targets)
act_item:   ld a, [BZ + $1A]
            push af
            cp $A9
            jr z, .go
            cp $AA
            jr nz, .val
            ld c, 1
            ld a, $70
            call zpy
            bit 7, [hl]
            jr z, .go
.val:       call val_tgts
.go:        pop af
            ld [BZ + $1A], a
            ld hl, BZ + $CC
            inc [hl]
            ; (fall through)
; 31/A65E do item effect: a weapon / armour's spell (power 1), an item's spell (2E/91A0) with its
; multiplier (01/A35E; key items 0), the item used up; else "Nothing happens"
item_eff:   ld a, 1
            ld [W7 + $78D5], a
            ld a, $14
            ld [W7 + $7EC2], a
            ld a, 1
            ld [BZ + $72], a
            ld a, [BZ + $1A]
            ld [W7 + $78D7], a
            cp $98
            jr nc, .it
            ld l, a                         ; the weapon / armour's +4
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, BD2_ITEM + 4
            add hl, de
            ld a, BDATA2_BANK
            call rd_byte
            and $7F
            cp $7F
            jr z, .none
            ld [BZ + $1A], a
            ld a, 1
            jr .go
.it:        cp $C8
            jr nc, .none
            sub $98
            ld e, a
            ld d, 0
            ld hl, BD_ITSPL
            add hl, de
            call bd_rd
            ld [W7 + $7400], a
            ld [BZ + $1B], a
            cp $7F
            jr z, .none
            ld a, [W7 + $7ED8]
            and $10
            jr z, .use
            ld a, [BZ + $1A]
            cp $AD
            jr z, .none                     ; (the luck mallet where mini can't be used)
.use:       ld a, [BZ + $1A]                ; one used up
            ld b, a
            ld hl, GS + $C0
.f:         ld a, [hl+]
            cp b
            jr z, .f1
            inc hl
            jr .f
.f1:        dec [hl]
            jr nz, .k
            dec hl
            ld [hl], 0
.k:         ld a, [BZ + $1B]
            ld [BZ + $1A], a
            ld a, [W7 + $78D7]
            cp $A6
            ld a, 0
            jr c, .go
            ld a, [W7 + $78D7]
            sub $A6
            ld e, a
            ld d, 0
            ld hl, BD_ITMUL
            add hl, de
            call bd_rd
            ld [W7 + $7400], a
.go:        ld [BZ + $30], a
            ld [BZ + $7C], a
            jp magic_eff
.none:      ld a, 1
            ld [W7 + $78D5], a
            ld a, $18
            ld [W7 + $7EC2], a
            ld a, $51                       ; Nothing happens
            ld [W7 + $78DA], a
            ret
