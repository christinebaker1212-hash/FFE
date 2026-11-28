; FF3 bank $3B translated routine by routine (docs/ff3-gb-rewrite.md); GB bank GB_3B.

section bank GB_3B, $4000
; ---- 3B/BE00 update map background tilemap (native): FF3's buffered row (moving vertically: 16
; metatiles from column $31, $0780 / $0790 the upper tiles, $07A0 / $07B0 the lower) or column
; (horizontally: 15 metatiles from row $30, $0780 / $07A0 the left tiles, $0790 / $07B0 the right) into
; the GB map at FF3's nametable position (metatile row $30 0-14, column $31 0-31), with their CGB
; attributes from FF3's shadow. RAM ($80-$82) and the registers as FF3's routine leaves them.
f3B_BE00:   ld a, [BZ + $30]
            ld e, a
            ld hl, $BF61                    ; (3B/BF61 / BF71: the rows' nametable addresses, for
            call n_rdx                      ;   the RAM FF3 leaves in $80 / $81)
            ld [BZ + $80], a
            ld hl, $BF71
            call n_rdx
            ld [BZ + $81], a
            ld a, [BZ + $31]
            cp $10
            jr nc, .r
            ld e, a
            add a
            ld hl, BZ + $80
            or [hl]
            ld [hl], a
            jr .d
.r:         and $0F
            ld e, a
            add a
            ld hl, BZ + $80
            or [hl]
            ld [hl], a
            ld a, [BZ + $81]
            add 4
            ld [BZ + $81], a
.d:         ld a, [BZ + $2D]
            and 2
            jr nz, .horz
            ld a, e                         ; vertical: $82 = 16 - X (as FF3)
            xor $0F
            inc a
            ld [BZ + $82], a
            ld a, [BZ + $80]                ; ($80 + $20: FF3's second row address)
            add $20
            ld [BZ + $80], a
            ld a, [BZ + $30]                ; GB: rows 2 $30 / + 1, columns 2 ($31 + i) (i < 16)
            add a
            ld d, a
            ld hl, NR2 + $0780
            call .row
            inc d
            ld hl, NR2 + $07A0
            call .row
            ld c, $10                       ; (Y, A, carry as FF3 leaves them)
            ld a, [NR2 + $07BF]
            scf
            ret
.row:       ld a, [BZ + $31]
            add a
            ld e, a
            ld c, 0
.rl:        push hl
            ld a, l
            add c
            ld l, a
            ld a, [hl]
            ld b, a
            ld a, l
            add $10
            ld l, a
            ld a, b
            call gbv_cell
            inc e
            ld a, [hl]
            call gbv_cell
            inc e
            ld a, e                         ; (column mod 64: the two nametables)
            and 63
            ld e, a
            pop hl
            inc c
            ld a, c
            cp $10
            jr c, .rl
            ret
.horz:      ld a, [BZ + $30]                ; horizontal: $82 = 15 - row (as FF3)
            ld b, a
            ld a, $0F
            sub b
            ld [BZ + $82], a
            ld a, [BZ + $31]                ; GB: columns 2 $31 / + 1, rows 2 ($30 + i) mod 30
            add a
            ld e, a
            ld hl, NR2 + $0780              ; left tiles: $0780 (upper), $07A0 (lower)
            call .col
            inc e
            ld hl, NR2 + $0790              ; right: $0790, $07B0
            call .col
            ld c, $0F
            ld a, $88
            scf
            ret
.col:       ld a, [BZ + $30]
            ld b, a
            ld c, 0
.cl:        ld a, b
            add a
            ld d, a
            push hl
            ld a, l
            add c
            ld l, a
            ld a, [hl]
            call gbv_cell
            inc d
            ld a, l
            add $20
            ld l, a
            ld a, [hl]
            call gbv_cell
            pop hl
            inc b
            ld a, b
            cp $0F
            jr c, .cn
            ld b, 0
.cn:        inc c
            ld a, c
            cp $0F
            jr c, .cl
            ret
