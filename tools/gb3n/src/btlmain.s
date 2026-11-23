; ---- 34/8074 battle main: the turn loop (monster actions, the members' commands, the order, the
; actions with their scripts, poison, the end), written for the GB.

; 34/81C3: the turn's start (action queue, the records' commands cleared unless jumping)
turn_start: call ptr_init
            ld hl, W7 + $7AC3
            ld a, $FF
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl], a
            ld [W7 + $78CF], a              ; 87AA
            ld [W7 + $78D0], a
            ld [W7 + $78D1], a
            ld [W7 + $78D2], a
            xor a
            ld [BZ + $52], a
            ld [BZ + $53], a
            ld [BZ + $54], a
            ld [W7 + $7AC2], a
            ld [BZ + $74], a
            ld hl, W7 + $7BE2
            inc [hl]
            ld hl, W7 + $7575               ; the 12 records
            ld b, 12
.r:         push hl
            ld de, $2C
            add hl, de
            ld a, [hl]
            and $E7
            ld [hl], a
            pop hl
            push hl
            inc hl
            inc hl
            ld a, [hl]
            and 1
            jr nz, .n
            pop hl
            push hl
            ld de, $2E
            add hl, de
            xor a
            ld [hl+], a                     ; +$2E-$30 cleared
            ld [hl+], a
            ld [hl], a
.n:         pop hl
            ld de, $40
            add hl, de
            dec b
            jr nz, .r
            xor a
            ld [W7 + $78D4], a
            ld [W7 + $7EC2], a
            ld hl, W7 + $7E0F
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl], a
            ld [BZ + $72], a
            ld [W7 + $7EDF], a
            ld hl, BZ + $E0
            ld b, $20
.c:         ld [hl+], a
            dec b
            jr nz, .c
            ret

; 34/81A0: saved defence values put back
def_restore:
            xor a
.m:         ld [BZ + $52], a
            call chr_ofs
            add a, $23
            ld c, a
            ld a, $5B
            call zpy
            ld a, [BZ + $52]
            ld e, a
            ld d, 0
            push hl
            ld hl, W7 + $7CE4
            add hl, de
            ld a, [hl]
            and a
            jr z, .n
            ld [hl], 0
            pop hl
            ld [hl], a
            push hl
.n:         pop hl
            ld a, [BZ + $52]
            inc a
            cp 4
            jr nz, .m
            xor a
            ld [BZ + $52], a
            ret

; 34/8213: the action's buffers reset
act_reset:  ld a, $FF
            ld hl, W7 + $7E4F
            ld b, $20
.d:         ld [hl+], a
            dec b
            jr nz, .d
            ld [W7 + $78D6], a
            ld [W7 + $78D7], a
            ld [W7 + $78D8], a
            ld [W7 + $78D9], a
            ld [W7 + $7E88], a
            ld hl, W7 + $78DA
            ld b, 10
.q:         ld [hl+], a
            dec b
            jr nz, .q
            ld [W7 + $7EE1], a
            xor a
            ld [W7 + $78EE], a
            ld [W7 + $7E98], a
            ld [W7 + $7E99], a
            ld [W7 + $7E9A], a
            ld [W7 + $7E1F], a
            ld [W7 + $7E20], a
            ld [BZ + $BB], a
            ld [BZ + $BC], a
            ld [W7 + $7E93], a
            ld [W7 + $78D4], a
            ld [W7 + $7EC2], a
            ld hl, W7 + $7E0F
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl], a
            ld [BZ + $72], a
            ld [W7 + $7EDF], a
            ld hl, BZ + $E0                 ; the status buffers
            ld b, $20
.e:         ld [hl+], a
            dec b
            jr nz, .e
            ret
