; ---- the action phase: 34/9777 determine attack order, 34/9DE4 execute action (the attacker /
; target pointers $6E / $70, the action id $7EC2 and its routine)

; 34/9777: 12 random keys (counter 1) sorted (34/8F57) give the monster places ($80 | slot;
; $88-$8B places for members); the members by agility + random (0..2 agility) fill those; the
; dead / stone members and dead / stone / toad / mini monsters are dropped; $FF ends ($7ACB)
atk_order:  xor a
.k:         ld [btl_m], a
            ld a, $FF
            call rnd_0a
            ld b, a
            ld a, [btl_m]
            ld e, a
            ld d, 0
            ld hl, W7 + $7400
            add hl, de
            ld [hl], b
            ld hl, W7 + $740C
            add hl, de
            ld [hl], e
            ld a, e
            inc a
            cp 12
            jr nz, .k
            ld a, 1                         ; sort 1-12: keys $73FF + i, indexes $740B + i
            ld [BZ + $1A], a
            ld hl, W7 + $73FF
            ld a, $1C
            call zpset
            ld hl, W7 + $740B
            ld a, $1E
            call zpset
            ld a, 12
            ld [BZ + $22], a
            call qsort
            ld hl, W7 + $740C               ; $7ACB = index | $80
            ld de, W7 + $7ACB
            ld b, 12
.c:         ld a, [hl+]
            or $80
            ld [de], a
            inc de
            dec b
            jr nz, .c
            xor a                           ; members: agility + random (0..2 agility)
.a:         ld [BZ + $52], a
            call chr_ofs
            add a, $18
            ld c, a
            ld a, $57
            call zpy
            ld a, [hl]
            ld [BZ + $3C], a
            add a, a
            call rnd_0a
            ld b, a
            ld a, [BZ + $3C]
            add a, b
            ld b, a
            ld a, [BZ + $52]
            ld e, a
            ld d, 0
            ld hl, W7 + $7400
            add hl, de
            ld [hl], b
            ld hl, W7 + $7404
            add hl, de
            ld [hl], e
            ld a, e
            inc a
            cp 4
            jr nz, .a
            ld a, 1                         ; sort 1-4: indexes $7403 + i
            ld [BZ + $1A], a
            ld hl, W7 + $73FF
            ld a, $1C
            call zpset
            ld hl, W7 + $7403
            ld a, $1E
            call zpset
            ld a, 4
            ld [BZ + $22], a
            call qsort
            ld b, 0                         ; the members into the places >= $88 in order
            ld c, $FF
.p:         inc c
            ld a, c
            ld e, a
            ld d, 0
            ld hl, W7 + $7ACB
            add hl, de
            ld a, [hl]
            cp $88
            jr c, .p
            push hl
            ld e, b
            ld hl, W7 + $7404
            add hl, de
            ld a, [hl]
            pop hl
            ld [hl], a
            inc b
            ld a, b
            cp 4
            jr nz, .p
            ld hl, W7 + $7ACB
            ld de, W7 + $7400
            ld bc, 12
            call memcpy
            xor a
            ld [BZ + $24], a                ; (Y out)
            ld [BZ + $25], a                ; (X in)
.f:         ld a, [BZ + $25]
            ld e, a
            ld d, 0
            ld hl, W7 + $7400
            add hl, de
            ld a, [hl]
            bit 7, a
            jr nz, .fm
            rrca                            ; a member: dead / stone dropped
            rrca
            inc a
            ld e, a
            ld hl, W7 + $7575
            add hl, de
            ld a, [hl]
            and $C0
            jr nz, .fn
            jr .fk
.fm:        and $7F                         ; a monster: dead / stone / toad / mini dropped
            rrca
            rrca
            ld l, a
            and $C0
            inc a
            ld e, a
            ld a, l
            and 3
            ld d, a
            ld hl, W7 + $7675
            add hl, de
            ld a, [hl]
            and $E8
            jr nz, .fn
.fk:        ld a, [BZ + $25]
            ld e, a
            ld d, 0
            ld hl, W7 + $7400
            add hl, de
            ld b, [hl]
            ld a, [BZ + $24]
            ld e, a
            ld hl, W7 + $7ACB
            add hl, de
            ld [hl], b
            inc a
            ld [BZ + $24], a
.fn:        ld a, [BZ + $25]
            inc a
            ld [BZ + $25], a
            cp 12
            jr nz, .f
            ld a, [BZ + $24]
            ld e, a
            ld d, 0
            ld hl, W7 + $7ACB
            add hl, de
            ld [hl], $FF
            ret

; 34/8F57: sort descending keys [$1C] + i, i = $1A..$22, carrying indexes [$1E] + i (set to
; 0..n-1 first): FF3's recursive partition, kept step for step
qsort:      ld a, [BZ + $22]
            push af
            ld b, a
            ld a, [BZ + $1A]
            ld c, a
            ld a, b
            sub c
            inc a
            ld [BZ + $18], a                ; n
            ld b, a
            ld c, 1
            xor a
.i:         push af
            push bc
            call qs_idx                     ; [$1E] + C = A
            pop bc
            pop af
            ld [hl], a
            inc a
            inc c
            dec b
            jr nz, .i
            pop af
            ; (fall through: 8F6F with A = hi)
qs_part:    ld [BZ + $1B], a
            ld a, [BZ + $18]
            push af
            ld a, [BZ + $19]
            push af
            ld a, [qs_x]
            push af
            ld a, [BZ + $1A]
            ld [BZ + $18], a
            ld a, [BZ + $1B]
            ld [BZ + $19], a
            ld a, [BZ + $1A]
            ld c, a
            call qs_key
            ld a, [hl]
            ld [BZ + $20], a                ; pivot = key[lo]
.lp:        ld a, [BZ + $1B]                ; 8F87
            ld c, a
            ld a, [BZ + $1A]
            ld b, a
            ld a, c
            cp b
            jr c, .rec                      ; (Y = $1B < $1A)
.dn:        push bc                         ; while key[y] < pivot: y--
            call qs_key
            pop bc
            ld a, [BZ + $20]
            ld b, a
            ld a, [hl]
            cp b
            jr nc, .d1
            dec c
            jr .dn
.d1:        ld a, c
            ld [BZ + $1B], a
            ld a, [BZ + $1A]
            ld c, a
.up:        push bc                         ; while key[y] > pivot: y++
            call qs_key
            pop bc
            ld a, [BZ + $20]
            ld b, a
            ld a, [hl]
            cp b
            jr z, .u1
            jr c, .u1
            inc c
            jr .up
.u1:        ld a, c
            ld [BZ + $1A], a
            ld a, [BZ + $1B]
            ld c, a
            ld a, [BZ + $1A]
            ld b, a
            ld a, c
            cp b
            jr c, .rec
            ld a, [BZ + $1B]                ; swap key / index at $1A and $1B
            ld c, a
            call qs_key
            ld a, [hl]
            ld [qs_t], a                    ; (X)
            call qs_idx
            ld a, [hl]
            ld [BZ + $21], a
            ld a, [BZ + $1A]
            ld c, a
            call qs_key
            ld a, [hl]
            push af
            ld a, [BZ + $1B]
            ld c, a
            call qs_key
            pop af
            ld [hl], a
            ld a, [BZ + $1A]
            ld c, a
            call qs_idx
            ld a, [hl]
            push af
            ld a, [BZ + $1B]
            ld c, a
            call qs_idx
            pop af
            ld [hl], a
            ld a, [BZ + $1A]
            ld c, a
            call qs_idx
            ld a, [BZ + $21]
            ld [hl], a
            ld a, [BZ + $1A]
            ld c, a
            call qs_key
            ld a, [qs_t]
            ld [hl], a
            ld hl, BZ + $1B
            dec [hl]
            ld hl, BZ + $1A
            inc [hl]
            jp .lp
.rec:       ld a, [BZ + $1A]                ; 8FD3: X = $1A, Y = $1B
            ld [qs_x], a
            ld a, [BZ + $18]
            ld b, a
            ld a, [BZ + $1B]
            cp b
            jr z, .r2
            jr c, .r2
            ld a, b                         ; sort lo .. Y
            ld [BZ + $1A], a
            ld a, [BZ + $1B]
            call qs_part
.r2:        ld a, [BZ + $19]                ; 8FE3: X < $19: sort X .. hi
            ld b, a
            ld a, [qs_x]
            cp b
            jr nc, .ret
            ld [BZ + $1A], a
            ld a, [BZ + $19]
            call qs_part
.ret:       pop af
            ld [qs_x], a
            pop af
            ld [BZ + $19], a
            pop af
            ld [BZ + $18], a
            ret
; HL = [$1C] + C / [$1E] + C
qs_key:     ld a, $1C
            jp zpy
qs_idx:     ld a, $1E
            jp zpy

; ---- 34/9DE4 execute action ($7ACB + $7AC2): the attacker ($6E), its display ids, the target
; ($70), the action id ($7EC2) and its routine (34/9FAC)
exec_action:
            ld a, [W7 + $7AC2]
            ld e, a
            ld d, 0
            ld hl, W7 + $7ACB
            add hl, de
            ld a, [hl]
            ld [btl_atk], a
            bit 7, a
            jr z, .c
            and $7F
            add a, 4
.c:         ld [BZ + $26], a
            call rec_ptr                    ; HL = $7575 + 64 A
            ld a, $6E
            call zpset
            ld a, [BZ + $26]
            cp $0C
            jr nc, .live
            cp 4
            jr c, .s1
            sub 4
            or $80
.s1:        ld [W7 + $78D6], a
            ld a, [btl_atk]
            and $7F
            call bitmask
            ld [W7 + $7E98], a
            ld a, [btl_atk]
            bit 7, a
            jr z, .live
            ld a, [W7 + $7E9A]
            or $80
            ld [W7 + $7E9A], a
            ld a, [W7 + $7CED]              ; (battles $55 / $79 / $90: max HP into the hi byte)
            cp $55
            jr nz, .b1
            ld a, [W7 + $7CEE]
            and a
            jr z, .b3
            jr .live
.b1:        cp $79
            jr z, .b2
            cp $90
            jr nz, .live
.b2:        ld a, [W7 + $7CEE]
            and a
            jr z, .live
.b3:        ld c, 6
            ld a, $6E
            call zpy
            ld a, [hl]
            ld c, 4
            push af
            ld a, $6E
            call zpy
            pop af
            ld [hl], a
.live:      ld c, 1
            ld a, $6E
            call zpy
            ld a, [hl+]
            and $C0
            jr z, .alive
            xor a                           ; dead / stone: nothing
            ld [W7 + $7E98], a
            ld [W7 + $7EC2], a
            dec a
            ld [W7 + $78D6], a
            ld [W7 + $78D8], a
            ld [W7 + $7CEB], a
            xor a
            call set_cmd
            jp .kind
.alive:     ld a, [hl]
            and $C0
            jr z, .t
            ld a, 1                         ; asleep / paralysed
            call set_cmd
            ld a, $FF
            ld [W7 + $78D8], a
            call self_tgt
.t:         ld c, $2F
            ld a, $6E
            call zpy
            ld a, [hl]
            ld [W7 + $7E99], a
            ld [W7 + $7E9B], a
            and a
            jr nz, .t1
            call self_tgt
.t1:        ld b, 0                         ; the first target's index
.t2:        add a, a
            jr c, .t3
            inc b
            jr .t2
.t3:        ld c, $30
            push bc
            ld a, $6E
            call zpy
            pop bc
            ld a, [hl]
            bit 7, a
            jr z, .tc
            ld a, [W7 + $7E9A]
            or $40
            ld [W7 + $7E9A], a
            ld a, b
            or $80
            ld [W7 + $78D8], a
            ld a, b
            add a, 4
            ld b, a
            jr .t4
.tc:        ld a, b
            ld [W7 + $78D8], a
.t4:        ld a, [hl]
            and $40
            jr z, .t5
            ld a, $88
            ld [W7 + $78D8], a
.t5:        ld a, b
            call rec_ptr
            ld a, $70
            call zpset
.kind:      call atk_flags                  ; magic, item / song, command
            bit 4, a
            jr z, .k1
            ld c, $2E
            ld a, $6E
            call zpy
            ld a, [hl]
            ld [BZ + $1A], a
            jr .magic
.k1:        bit 3, a
            jr z, .k2
            ld c, $2E
            ld a, $6E
            call zpy
            ld a, [hl]
            ld [BZ + $1A], a
            ld a, $13
            jr .go
.k2:        ld c, $2E
            ld a, $6E
            call zpy
            ld a, [hl]
            ld [BZ + $1A], a
            cp $13
            jr c, .go
            cp $46
            jr c, .k3
            call atk_flags                  ; (harps: a spell cast; members lose 1 MP)
            bit 7, a
            jr nz, .magic
            and 7
            ld [BZ + $52], a
            ld e, a
            ld d, 0
            ld hl, W7 + $7AC7
            add hl, de
            ld a, [hl]
            add a, 7
            ld c, a
            ld a, $6E
            call zpy
            dec [hl]
            jr .magic                       ; (summons: later)
.k3:        ld a, $13
            jr .go
.magic:     ld a, $14
.go:        ld [W7 + $7EC2], a
            add a, a
            ld e, a
            ld d, 0
            ld hl, act_tab
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            jp hl
act_tab:    dw act_none, act_none, act_none, act_none, act_fight, act_defend, act_none, act_none
            dw act_none, act_none, act_none, act_none, act_none, act_none, act_none, act_none
            dw act_none, act_none, act_none, act_none, act_none
act_none:   ret

; 34/9F7B set command id A (magic / item flags cleared)
set_cmd:    push af
            ld c, $2E
            ld a, $6E
            call zpy
            pop af
            ld [hl], a
            call atk_flags
            and $E7
            ld [hl], a
            ret

; 34/9F87 set self-target: +$2F = the attacker's bit, +$30 = monster flag; A = the mask
self_tgt:   call atk_flags
            push af
            and 7
            call bitmask
            push af
            ld c, $2F
            ld a, $6E
            call zpy
            pop af
            ld [hl+], a
            ld [W7 + $7E99], a
            ld [W7 + $7E9B], a
            pop af
            and $80
            ld [hl-], a
            ld a, [hl]
            ret

; 35/A881 action $05 defend: "Defend" (message $3E -> $78D7), defence doubled ($FF if >= $80),
; the old value kept ($7CE4 + slot)
act_defend: ld a, $3E
            ld [W7 + $78D7], a
            ld a, $FF
            ld [W7 + $78D8], a
            ld a, 1
            ld [W7 + $78D5], a
            ld c, $23
            ld a, $6E
            call zpy
            ld a, [hl]
            push af
            call atk_flags
            and 7
            ld e, a
            ld d, 0
            ld hl, W7 + $7CE4
            add hl, de
            pop af
            ld [hl], a
            cp $80
            jr c, .d
            ld a, $FF
            jr .s
.d:         add a, a
.s:         push af
            ld c, $23
            ld a, $6E
            call zpy
            pop af
            ld [hl], a
            ret

section wram, $DF70
btl_atk:    ds 1
qs_x:       ds 1
qs_t:       ds 1
