; ---- 35/B648 battle command $15: magic. FF3's list kept: $7400 + 3 row + column = the spells
; (row 0 = the highest level with MP, $46), learned from the save block's bits (+7 + level),
; those the job can't cast removed ($FF); $24 the row, $26 the column. On the GB (the owner's
; design): the tall window, per level a line "Lv n  MP cur/max" and its spells one a row, two
; levels a page; up / down step through the spells, left / right a level.
MG_ROW     = BZ + $24
MG_COL     = BZ + $26

bmagic_menu: ld a, [W7 + $7ED8]
            and $40
            jr z, .ok
            ld a, $86                       ; (no magic in this battle)
            ld [S49], a
            ld a, 2
            ret
.ok:        ld hl, W7 + $7400
            ld b, $18
            ld a, $FF
.c:         ld [hl+], a
            dec b
            jr nz, .c
            ld a, [BZ + $5F]                ; the highest level with max MP (+$31 + 2 level)
            add a, $3F
            ld c, a
            ld a, $57
            call zpy
            ld b, 7
.h:         ld a, [hl]
            and a
            jr nz, .h1
            dec b
            dec hl
            dec hl
            jr .h
.h1:        ld a, b
            ld [BZ + $46], a
            ld [BZ + $27], a
            ld c, a                         ; $18 = (7 - level) x 7
            ld a, 7
            sub c
            ld [BZ + $18], a
            ld b, a
            add a, a
            ld [BZ + $19], a
            add a, a
            add a, b
            ld hl, BZ + $19
            add a, [hl]
            ld [BZ + $18], a
            xor a
            ld [MG_ROW], a
.lv:        ld a, 3
            ld [BZ + $25], a
            ld a, [BZ + $5F]                ; the learned bits (+7 + level)
            add a, 7
            ld hl, BZ + $27
            add a, [hl]
            ld c, a
            ld a, $59
            call zpy
            ld a, [hl]
            ld b, a
            ld a, 7
            ld [BZ + $1C], a
.bit:       srl b
            jr nc, .nb
            ld a, [MG_ROW]                  ; a learned spell -> the list
            ld e, a
            ld d, 0
            ld hl, W7 + $7400
            add hl, de
            ld a, [BZ + $18]
            ld [hl], a
            ld hl, BZ + $18
            inc [hl]
            ld hl, MG_ROW
            inc [hl]
            ld hl, BZ + $25
            dec [hl]
            ld hl, BZ + $1C
            dec [hl]
            jr nz, .bit
.nb:        ld hl, BZ + $18
            inc [hl]
            ld hl, BZ + $1C
            dec [hl]
            jr nz, .bit
            ld a, [BZ + $25]
            ld hl, MG_ROW
            add a, [hl]
            ld [hl], a
            ld hl, BZ + $27
            dec [hl]
            bit 7, [hl]
            jr z, .lv
            ld hl, W7 + $7400               ; (the list as learned: shown with X marks)
            ld de, bmg_shown
            ld bc, $18
            call memcpy
            xor a                           ; the job's spells only (35/B734)
            ld [BZ + $26], a
.cj:        ld a, [BZ + $26]
            ld e, a
            ld d, 0
            ld hl, W7 + $7400
            add hl, de
            ld a, [hl]
            cp $FF
            jr z, .cn
            push hl
            add a, $C8
            call b_can
            pop hl
            jr nz, .cn
            ld [hl], $FF
.cn:        ld hl, BZ + $26
            inc [hl]
            ld a, [hl]
            cp $18
            jr nz, .cj
            xor a
            ld [MG_ROW], a
            ld [BZ + $25], a
            ld [MG_COL], a
            call tall_open
.l:         call bmg_draw
.in:        call b_keys
            ld a, [btl_new]
            and a
            jr z, .in
            ld b, a
            ld a, $98
            ld [S49], a
            ld a, b
            cp 1
            jr z, .a
            cp 2
            jp z, .b
            cp $80
            jr z, .down
            cp $40
            jr z, .up
            cp $20
            jr z, .left
            cp $10
            jr nz, .in
            call .nextlv                    ; right: the next level down
            jr .l
.left:      ld a, [MG_ROW]
            and a
            jr z, .l
            dec a
            ld [MG_ROW], a
            jr .l
.down:      ld a, [MG_COL]
            cp 2
            jr z, .dl
            inc a
            ld [MG_COL], a
            jr .l
.dl:        call .nextlv
            jr nz, .l
            xor a
            ld [MG_COL], a
            jr .l
.up:        ld a, [MG_COL]
            and a
            jr z, .ul
            dec a
            ld [MG_COL], a
            jr .l
.ul:        ld a, [MG_ROW]
            and a
            jr z, .l
            dec a
            ld [MG_ROW], a
            ld a, 2
            ld [MG_COL], a
            jr .l
; (35/B82C: not below row 7 nor the last level) Z if moved
.nextlv:    ld a, [MG_ROW]
            cp 7
            jr z, .nn
            ld hl, BZ + $46
            cp [hl]
            jr z, .nn
            inc a
            ld [MG_ROW], a
            xor a
            ret
.nn:        or 1
            ret
.a:         ld a, [MG_ROW]                  ; 35/B877
            ld b, a
            add a, a
            add a, b
            ld hl, MG_COL
            add a, [hl]
            ld e, a
            ld d, 0
            ld hl, W7 + $7400
            add hl, de
            ld a, [hl]
            cp $FF
            jr z, .err
            ld [bmg_id], a
            ld a, [W7 + $7ED8]
            and $10
            jr z, .m
            ld a, [bmg_id]
            cp $2F
            jr z, .err                      ; (mini where it can't be used)
.m:         ld a, [MG_ROW]                  ; the level, its MP
            ld b, a
            ld a, [BZ + $46]
            sub b
            ld [BZ + $47], a
            ld b, a
            ld a, [BZ + $52]
            ld e, a
            ld d, 0
            ld hl, W7 + $7AC7
            add hl, de
            ld [hl], b
            ld a, [BZ + $5F]
            add a, 7
            add a, b
            ld c, a
            ld a, $5B
            call zpy
            ld a, [hl]
            and a
            jr nz, .t
.err:       ld a, $86
            ld [S49], a
            jp .in
.t:         ld a, $85
            ld [S49], a
            ld a, [bmg_id]
            call bmg_spell                   ; 35/B953 -> 0 / 1 / 2
            and a
            jr z, .set
            cp 1
            jr z, .err
            jr .b                           ; (cancelled)
.set:       ld a, [bmg_id]
            add a, $C8
            push af
            ld a, [BZ + $52]
            ld e, a
            ld d, 0
            ld hl, W7 + $78CF
            add hl, de
            pop af
            ld [hl], a
            push af
            ld a, [BZ + $5F]
            add a, $2E
            ld c, a
            ld a, $5B
            call zpy
            pop af
            ld [hl], a
            cp $FF
            jr nz, .s1
            ld a, [BZ + $52]
            call bitmask
            ld b, a
            ld a, [W7 + $7BE1]
            or b
            ld [W7 + $7BE1], a
.s1:        ld hl, BZ + $52
            inc [hl]
.b:         call tall_close
            ld a, 2
            ret

; 35/B953 get magic targets: the spell's properties -> $7478; 1 if the job can't cast it
bmg_spell:   ld [BZ + $18], a
            ld [W7 + $7CE8], a
            push af
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, BD2_ATK
            add hl, de
            ld de, W7 + $7478
            ld bc, 8
            ld a, BDATA2_BANK
            call rd_copy
            pop af
            add a, $C8
            call b_can
            jr nz, .c
            ld a, 1
            ret
.c:         ld a, [W7 + $747C]
            cp 1
            jr nz, .t
            ld a, $FF
            ld [W7 + $7CE8], a
.t:         call tall_close
            jp mg_targets

; the list: two levels a page (the cursor's level first when it is odd)
bmg_draw:    ld bc, $0000
            ld de, $140A
            call w_box
            ld a, [MG_ROW]
            and $FE
            ld [btl_k], a
            ld c, 1
            call bmg_lvl
            ld a, [btl_k]
            inc a
            ld b, a
            ld a, [BZ + $46]
            cp b
            jr c, .one
            ld a, b
            ld [btl_k], a
            ld c, 5
            call bmg_lvl
            jr .h
.one:       ld c, 5                         ; (no level there: blank lines)
            ld b, 4
.bl:        push bc
            call bmg_blank
            ld b, 1
            call cv_line
            pop bc
            inc c
            dec b
            jr nz, .bl
.h:         ld a, [MG_ROW]                  ; the hand: line 2 + column (+ 4 on the odd level)
            and 1
            add a, a
            add a, a
            ld b, a
            ld a, [MG_COL]
            add a, b
            inc a
            add a, a
            add a, a
            add a, a
            add a, 64 + 8
            ld c, a
            ld b, 0
            call b_hand
            jp wait_vbl

bmg_blank:   ld hl, win_buf
            ld b, 18
            ld a, $FF
.b:         ld [hl+], a
            dec b
            jr nz, .b
            ld [hl], 0
            ret

; row btl_k (a level) at canvas row C: "Lv n  MP cur/max", its three spells
bmg_lvl:     push bc
            call bmg_blank
            ld a, $95                       ; L v
            ld [win_buf], a
            ld a, $B9
            ld [win_buf + 1], a
            ld a, [btl_k]                   ; level = $46 - row + 1
            ld b, a
            ld a, [BZ + $46]
            sub b
            ld [btl_tmp + 2], a
            inc a
            add a, $80
            ld [win_buf + 2], a
            ld a, $96                       ; M P
            ld [win_buf + 5], a
            ld a, $99
            ld [win_buf + 6], a
            ld a, [BZ + $5F]                ; current (+7 + level), max (+$31 + 2 level)
            add a, 7
            ld hl, btl_tmp + 2
            add a, [hl]
            ld c, a
            ld a, $5B
            call zpy
            ld a, [hl]
            ld hl, win_buf + 8
            call bmg_num
            ld a, $C7
            ld [win_buf + 10], a
            ld a, [btl_tmp + 2]
            add a, a
            ld b, a
            ld a, [BZ + $5F]
            add a, $31
            add a, b
            ld c, a
            ld a, $57
            call zpy
            ld a, [hl]
            ld hl, win_buf + 11
            call bmg_num
            pop bc
            push bc
            ld b, 1
            call cv_line
            pop bc
            inc c
            xor a
.s:         ld [btl_n2], a
            push bc
            call bmg_blank
            ld a, [btl_k]
            ld b, a
            add a, a
            add a, b
            ld hl, btl_n2
            add a, [hl]
            ld e, a
            ld d, 0
            ld hl, W7 + $7400
            add hl, de
            ld a, [hl]
            cp $FF
            jr nz, .ok
            ld hl, bmg_shown                 ; (not castable: X and the name)
            add hl, de
            ld a, [hl]
            cp $FF
            jr z, .p
            ld b, a
            ld a, $73
            ld [win_buf + 1], a
            ld a, b
.ok:        add a, $C8                      ; spell names $04C8 +
            ld b, 0
            jr nc, .n
            inc b
.n:         call bstr
            ld hl, btl_str
            ld de, win_buf + 2
            ld b, 15
.cp:        ld a, [hl+]
            and a
            jr z, .p
            ld [de], a
            inc de
            dec b
            jr nz, .cp
.p:         pop bc
            push bc
            ld b, 1
            call cv_line
            pop bc
            inc c
            ld a, [btl_n2]
            inc a
            cp 3
            jr nz, .s
            ret

; A (0-99) as two cells at HL (a blank for tens of 0)
bmg_num:     ld b, $80
.d:         cp 10
            jr c, .d1
            sub 10
            inc b
            jr .d
.d1:        add a, $80
            push af
            ld a, b
            cp $80
            jr nz, .t
            ld a, $FF
.t:         ld [hl+], a
            pop af
            ld [hl], a
            ret

section wram, $DF20
bmg_shown:   ds $18              ; (WRAM bank 3, FF3's unused $7F20-)
bmg_id:     ds 1
