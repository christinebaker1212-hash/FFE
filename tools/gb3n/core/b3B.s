; FF3 bank $3B translated routine by routine (docs/ff3-gb-rewrite.md); GB bank GB_3B.

section bank GB_3B, $4000
; ---- 3B/BE00 update map background tilemap: the row (moving vertically) or column (horizontally)
; in $0780-$07BF to the nametables at FF3's metatile position ($30 row 0-14, $31 column 0-31; the
; second 16 columns in the right-hand nametable); $80 / $81 / $82 as FF3 leaves them
f3B_BE00:   ld a, [BZ + $30]
            ld e, a
            ld hl, $BF61                    ; (3B/BF61 / BF71: the rows' nametable addresses)
            call n_rdx
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
            jp nz, .horz
            ld a, e                         ; vertical: $82 = 16 - X
            xor $0F
            inc a
            ld [BZ + $82], a
            call ppu_2002
            ld a, [BZ + $81]
            call ppu_2006
            ld a, [BZ + $80]
            call ppu_2006
            ld c, 0
            ld hl, NR2 + $0780
            call .pair                      ; $0780 / $0790 up to $82
            ld a, c
            cp $10
            jr nc, .v2
            ld a, [BZ + $81]
            xor 4
            call ppu_2006
            ld a, [BZ + $80]
            and $E0
            call ppu_2006
            ld hl, NR2 + $0780
            call .pair16
.v2:        ld a, [BZ + $80]
            add $20
            ld [BZ + $80], a
            ld a, [BZ + $81]
            call ppu_2006
            ld a, [BZ + $80]
            call ppu_2006
            ld c, 0
            ld hl, NR2 + $07A0
            call .pair
            ld a, c
            cp $10
            jr nc, .vx
            ld a, [BZ + $81]
            xor 4
            call ppu_2006
            ld a, [BZ + $80]
            and $E0
            call ppu_2006
            ld hl, NR2 + $07A0
            call .pair16
.vx:        ld a, d                         ; (as the 6502 leaves it: A = the last byte, the carry
            scf                             ;   from CPY #$10)
            ret
; [HL + Y], [HL + $10 + Y] to $2007 while Y < $82 (.pair) / Y < 16 (.pair16)
.pair:      ld a, [BZ + $82]
            ld b, a
            jr .p
.pair16:    ld b, $10
.p:         ld a, c
            cp b
            ret nc
.pl:        push hl
            ld a, l
            add c
            ld l, a
            ld a, [hl]
            call ppu_2007
            ld a, l
            add $10
            ld l, a
            ld a, [hl]
            ld d, a
            call ppu_2007
            pop hl
            inc c
            ld a, c
            cp b
            jr c, .pl
            ret
.horz:      ld a, [BZ + $30]                ; horizontal: $82 = 15 - row, columns of 15 metatiles
            ld b, a
            ld a, $0F
            sub b
            ld [BZ + $82], a
            call ppu_2002
            ld a, [BZ + $81]
            call ppu_2006
            ld a, [BZ + $80]
            call ppu_2006
            ld a, 4                         ; (address step 32)
            call ppu_2000
            ld c, 0
            ld hl, NR2 + $0780
            call .col
            ld a, c
            cp $0F
            jr nc, .h2
            ld a, [BZ + $81]
            and $24
            call ppu_2006
            ld a, [BZ + $80]
            and $1F
            call ppu_2006
            ld hl, NR2 + $0780
            call .col15
.h2:        ld c, 0
            ld a, [BZ + $81]
            call ppu_2006
            ld a, [BZ + $80]
            inc a
            call ppu_2006
            ld hl, NR2 + $0790
            call .col
            ld a, c
            cp $0F
            jr nc, .h3
            ld a, [BZ + $81]
            and $24
            call ppu_2006
            ld a, [BZ + $80]
            inc a
            and $1F
            call ppu_2006
            ld hl, NR2 + $0790
            call .col15
.h3:        ld a, $88
            scf                             ; (the carry from CPY #$0F)
            jp ppu_2000
; [HL + Y], [HL + $20 + Y] to $2007 while Y < $82 (.col) / Y < 15 (.col15)
.col:       ld a, [BZ + $82]
            ld b, a
            jr .c0
.col15:     ld b, $0F
.c0:        ld a, c
            cp b
            ret nc
.cl:        push hl
            ld a, l
            add c
            ld l, a
            ld a, [hl]
            call ppu_2007
            ld a, l
            add $20
            ld l, a
            ld a, [hl]
            call ppu_2007
            pop hl
            inc c
            ld a, c
            cp b
            jr c, .cl
            ret
