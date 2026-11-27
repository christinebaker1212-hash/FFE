; Back attacks (FF3's $78C3 = $88): FF3 keeps every position in the normal layout and mirrors at
; the output (33/B19B: a sprite's x = $F7 - x, flipped; 33/AC93: a damage number as a whole
; block; 3F/F942: the monsters' tiles flipped). Here the same: the battlefield's rows 0-11 are
; written to VRAM mirrored (column 19 - c, the tiles' x-flip toggled), the top window's cells
; (rows 0-3, columns 0-17 while it shows) in place; the sprites mirrored around each OAM transfer
; (digit / "Miss" sprites moved as whole runs, not flipped).

section bank B_BSCR, $5300
; HL = the VRAM map address of cell (row D, column E), B = the attributes' x-flip toggle;
; Z: the cell is not shown (under the top window in a back attack)
bs_mcell:   ld b, 0
            ld a, [bs_bk]
            and a
            jr z, .n
            ld a, d
            cp 12
            jr nc, .n
            ld a, 19
            sub e
            ld e, a
            ld b, $20
            ld a, d
            cp 4
            jr nc, .n
            ld a, [bs_topon]
            and a
            jr z, .n
            ld a, e
            cp 2
            jr c, .n
            xor a                           ; (Z)
            ret
.n:         ld l, d
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld a, e
            call bs_hl_a
            ld a, h
            add $98
            ld h, a
            or 1                            ; (NZ)
            ret
; row C (0-11) mirrored: VRAM column x shows column 19 - x, its x-flip toggled; while the top window
; shows, its rows 0-3 are VRAM columns 0-1 = columns 19-18 mirrored, 2-19 = the window (0-17) in place
; (the window beside the party, as the party's columns beside it in the normal layout)
bs_vrowm:   ld a, c
            ld [bs_mrow], a
            add a                           ; 20 row
            add a
            ld l, a
            add a
            add a
            add l
            ld [bs_mrof], a
            ld l, c                         ; DE = the VRAM row
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, $9800
            add hl, de
            ld d, h
            ld e, l
            xor a
            ldh [rVBK], a
            ld c, a
            ld hl, SH_T
            call .row
            ld a, 1
            ldh [rVBK], a
            ld c, $20
            ld hl, SH_A
            call .row
            xor a
            ldh [rVBK], a
            ret
.row:       push de
            ld a, [bs_mrof]
            add l
            ld l, a
            adc h
            sub l
            ld h, a
            ld a, [bs_mrow]
            cp 4
            jr nc, .m
            ld a, [bs_topon]
            and a
            jr nz, .w
.m:         ld a, 19
            add l
            ld l, a
            adc h
            sub l
            ld h, a
            ld b, 20
.r:         ld a, [hl-]
            xor c
            ld [de], a
            inc e
            dec b
            jr nz, .r
            pop de
            ret
.w:         push hl
            ld a, 19
            add l
            ld l, a
            adc h
            sub l
            ld h, a
            ld a, [hl-]
            xor c
            ld [de], a
            inc e
            ld a, [hl]
            xor c
            ld [de], a
            inc e
            pop hl
            ld b, 18
.c:         ld a, [hl+]
            ld [de], a
            inc e
            dec b
            jr nz, .c
            pop de
            ret
; (the frame's: mirrored before the wait for V-Blank, back after the transfer)
bs_opre:    ld a, [bs_bk]
            and a
            ret z
            jp bk_oam

; mirror the OAM buffer (its own inverse): x = 168 - x, flipped; digits / "Miss" ($E0-$ED) in runs
; (same y, 8 apart) moved as a block; sprites below the battlefield (the windows' hands) left
bk_oam:     ld hl, oam_buf
            ld b, 40
.e:         ld a, [hl]
            and a
            jr z, .nx
            cp 16 + 96                      ; (the battlefield's only: not the windows' hands)
            jr nc, .nx
            inc hl
            inc hl
            ld a, [hl-]
            dec hl
            sub $E0
            cp $0E
            jr c, .dg
            inc hl                          ; x
            ld a, 168
            sub [hl]
            ld [hl+], a
            inc hl
            ld a, [hl]
            xor $20
            ld [hl-], a
            dec hl
            dec hl
.nx:        ld a, l
            add 4
            ld l, a
            dec b
            jr nz, .e
            ret
.dg:        ld d, [hl]                      ; a run: D = y, E = its first x, C = its length
            inc hl
            ld e, [hl]
            dec hl
            push hl
            ld c, 1
.r:         ld a, b
            cp c
            jr z, .end
            pop hl
            push hl
            ld a, c
            add a
            add a
            add l
            ld l, a
            ld a, [hl+]
            cp d
            jr nz, .end
            ld a, c
            add a
            add a
            add a
            add e
            cp [hl]
            jr nz, .end
            inc hl
            ld a, [hl]
            sub $E0
            cp $0E
            jr nc, .end
            inc c
            jr .r
.end:       pop hl                          ; delta = 168 - 2 first - 8 (n - 1)
            ld a, c
            dec a
            add a
            add a
            add a
            ld d, a
            ld a, e
            add a
            add d
            ld d, a
            ld a, 168
            sub d
            ld d, a
            ld e, c
.m:         inc hl
            ld a, [hl]
            add d
            ld [hl+], a
            inc hl
            inc hl
            dec e
            jr nz, .m
            ld a, b
            sub c
            ld b, a
            jr nz, .e
            ret

section bank B_BANIM, $7A00
; (the animation bank's copies)
an_opre:    ld a, [bs_bk]
            and a
            ret z
            jp ak_oam
an_mcell:   ld b, 0
            ld a, [bs_bk]
            and a
            jr z, .n
            ld a, d
            cp 12
            jr nc, .n
            ld a, 19
            sub e
            ld e, a
            ld b, $20
            ld a, d
            cp 4
            jr nc, .n
            ld a, [bs_topon]
            and a
            jr z, .n
            ld a, e
            cp 2
            jr c, .n
            xor a
            ret
.n:         ld l, d
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld a, e
            call an_hla
            ld a, h
            add $98
            ld h, a
            or 1
            ret
; mirror the OAM buffer (its own inverse): x = 168 - x, flipped; digits / "Miss" ($E0-$ED) in runs
; (same y, 8 apart) moved as a block
ak_oam:     ld hl, oam_buf
            ld b, 40
.e:         ld a, [hl]
            and a
            jr z, .nx
            cp 16 + 96                      ; (the battlefield's only: not the windows' hands)
            jr nc, .nx
            inc hl
            inc hl
            ld a, [hl-]
            dec hl
            sub $E0
            cp $0E
            jr c, .dg
            inc hl                          ; x
            ld a, 168
            sub [hl]
            ld [hl+], a
            inc hl
            ld a, [hl]
            xor $20
            ld [hl-], a
            dec hl
            dec hl
.nx:        ld a, l
            add 4
            ld l, a
            dec b
            jr nz, .e
            ret
.dg:        ld d, [hl]                      ; a run: D = y, E = its first x, C = its length
            inc hl
            ld e, [hl]
            dec hl
            push hl
            ld c, 1
.r:         ld a, b
            cp c
            jr z, .end
            pop hl
            push hl
            ld a, c
            add a
            add a
            add l
            ld l, a
            ld a, [hl+]
            cp d
            jr nz, .end
            ld a, c
            add a
            add a
            add a
            add e
            cp [hl]
            jr nz, .end
            inc hl
            ld a, [hl]
            sub $E0
            cp $0E
            jr nc, .end
            inc c
            jr .r
.end:       pop hl                          ; delta = 168 - 2 first - 8 (n - 1)
            ld a, c
            dec a
            add a
            add a
            add a
            ld d, a
            ld a, e
            add a
            add d
            ld d, a
            ld a, 168
            sub d
            ld d, a
            ld e, c
.m:         inc hl
            ld a, [hl]
            add d
            ld [hl+], a
            inc hl
            inc hl
            dec e
            jr nz, .m
            ld a, b
            sub c
            ld b, a
            jr nz, .e
            ret

section wram, $C5D2
bs_bk:      ds 1                            ; (1: a back attack)
bs_mrow:    ds 1
bs_mrof:    ds 1
bs_mtb:     ds 1
bs_rr:      ds 1
bs_rh:      ds 1
bs_rc:      ds 1
bs_rw:      ds 1
