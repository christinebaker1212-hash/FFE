; FF2 native routines outside bank 0 (appended after native.s: section bank HLE_BANK),
; reached through bank-0 stubs (rt/ff2.s, rt_fcs). Keep C (Y).
; fix:FC79 multiply: +$02 <- A * X (FF2's shift-and-add, step for step: $00 = A, $01
; rotated, A / C / X as the NES leaves them). Keeps C (Y).
hle_mul8_b:   ld [NES_RAM + $00], a
            ld b, a                         ; $00
            ld h, e                         ; $01
            ld e, 8
            ld l, 0                         ; $02
            ld d, 0                         ; $03
            ld a, 0                         ; (LDA #$00: carry kept)
.lp:        rr h                            ; ROR $01
            jr nc, .n
            ld a, b                         ; CLC / LDA $00 / ADC $03 / STA $03
            add a, d
            ld d, a
.n:         rr d                            ; ROR $03
            rr l                            ; ROR $02
            dec e                           ; DEX (carry kept)
            jr nz, .lp
            push af
            ld a, h
            ld [NES_RAM + $01], a
            ld a, l
            ld [NES_RAM + $02], a
            ld a, d
            ld [NES_RAM + $03], a
            xor a
            ldh [nzv], a
            ld b, 0
            ld d, 0
            pop af                          ; A, Z = 1, C from the last ROR
            ret

; fix:FC98 multiply (16-bit): +++$04 <- +$00 * +$02, FF2's steps in registers ($07 B, $06 C,
; $05 D, $04 E, $03 H, $02 L; RORs through the carry as on the NES; A = the last $07 sum)
hle_mul16_b:
            push bc
            push de
            ld a, [NES_RAM + $02]
            ld l, a
            ld a, [NES_RAM + $03]
            ld h, a
            ld bc, 0
            ld de, 0
            ld a, 0
            ldh [tmp_lo], a                 ; (A at exit)
            ld a, 16
            ldh [uw_y], a
.lp:        rr h                            ; ROR $03 / $02
            rr l
            jr nc, .n
            ld a, [NES_RAM + $00]           ; CLC / $06 += $00 / $07 += $01 + carry
            add a, c
            ld c, a
            ld a, [NES_RAM + $01]
            adc a, b
            ld b, a
            ldh [tmp_lo], a
.n:         rr b                            ; ROR $07 / $06 / $05 / $04
            rr c
            rr d
            rr e
            ldh a, [uw_y]                   ; DEX (carry kept)
            dec a
            ldh [uw_y], a
            jr nz, .lp
            ld a, l
            ld [NES_RAM + $02], a
            ld a, h
            ld [NES_RAM + $03], a
            ld a, e
            ld [NES_RAM + $04], a
            ld a, d
            ld [NES_RAM + $05], a
            ld a, c
            ld [NES_RAM + $06], a
            ld a, b
            ld [NES_RAM + $07], a
            ld a, 0
            ldh [nzv], a
            pop de
            pop bc
            ld e, 0                         ; X = 0
            ldh a, [tmp_lo]                 ; A; Z = 1 and C from the last ROR still set
            ret

; fix:FCC3 divide (16-bit): +$04 = +$00 / +$02, +$06 = remainder. FF2's restoring division
; (16-bit remainder register: an overflowing shift loses its top bit) in registers: divisor
; BC, dividend / quotient DE, remainder HL; as the NES leaves them: $00 = 0, $01 = $80 if the
; carry was set on entry (it is rotated in first, then only zeros), A = $07, C = 0. A zero
; +$00 or +$02: A = 0, Z = 1, X and C unchanged. (Checked against a model of the 6502
; routine on 200000 random cases.)
hle_div16_b:
            push af                         ; caller's carry
            ld hl, NES_RAM + $04
            ld a, 0
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl], a
            ld a, [NES_RAM + $00]
            ld hl, NES_RAM + $01
            or [hl]
            jr z, .zero
            ld a, [NES_RAM + $02]
            inc l
            inc l                           ; $03
            or [hl]
            jr z, .zero
            pop af
            ld a, 0                         ; the final $01: $80 if the entry carry was set
            jr nc, .c0
            ld a, $80
.c0:        ldh [tmp_lo], a
            push bc
            push de
            ld a, [NES_RAM + $02]
            ld c, a
            ld a, [NES_RAM + $03]
            ld b, a
            ld a, [NES_RAM + $00]
            ld e, a
            ld a, [NES_RAM + $01]
            ld d, a
            ld hl, 0
            ld a, 16
            ldh [uw_y], a
.lp:        sla e                           ; dividend bit out, quotient bit 0 in
            rl d
            rl l                            ; into the remainder (its top bit lost)
            rl h
            ld a, l                         ; remainder - divisor
            sub c
            ldh [wtmp], a
            ld a, h
            sbc a, b
            jr c, .no
            ld h, a                         ; fits: subtracted, quotient bit 1
            ldh a, [wtmp]
            ld l, a
            inc e
.no:        ldh a, [uw_y]
            dec a
            ldh [uw_y], a
            jr nz, .lp
            ld a, e
            ld [NES_RAM + $04], a
            ld a, d
            ld [NES_RAM + $05], a
            ld a, l
            ld [NES_RAM + $06], a
            ld a, h
            ld [NES_RAM + $07], a
            xor a
            ld [NES_RAM + $00], a
            ldh [nzv], a
            ldh a, [tmp_lo]
            ld [NES_RAM + $01], a
            pop de
            pop bc
            ld e, 0                         ; X = 0
            ld a, 1
            dec a                           ; Z = 1
            scf
            ccf                             ; C = 0
            ld a, h                         ; A = $07 (flags kept)
            ret
.zero:      xor a
            ldh [nzv], a
            pop af                          ; caller's carry
            ld a, 1
            dec a                           ; A = 0, Z = 1 (carry kept)
            ret

; b11:97D5 init rng: A + carry + the 256 zero-page bytes (ADC chain) -> $42; k = (A & 2) + 3
; -> $0A; 256 entries of x = k * x mod 1024 folded above 512 (x = 1024 - x), table $7A48 + n
; = (x >> 1) & $FF. The NES computes it with the 16-bit multiply / divide; the end state is
; theirs: $00-$02 = 0, $03 = 4, $04 / $05 = the last quotient, $06 / $07 = $08 / $09 = the
; last x, A = the last entry, X = Y = 0, Z = 1, N = 0, C = x bit 0. (Checked against a
; model of the 6502 routine on 300 random zero pages.)
hle_initrng_b:
            push bc
            push de
            ld hl, NES_RAM
            ld b, 0
.sum:       adc a, [hl]                     ; (inc l / dec b keep the carry)
            inc l
            dec b
            jr nz, .sum
            ld [NES_RAM + $42], a
            and 2
            add a, 3
            ld [NES_RAM + $0A], a
            ldh [wtmp], a                   ; k
            ld de, 1                        ; x
            ld hl, $A000 + $7A48 - $6000    ; table (cart RAM bank 0)
            ld c, 0                         ; 256 entries
.lp:        push hl
            ld h, d
            ld l, e
            add hl, hl                      ; 2x
            ldh a, [wtmp]
            cp 3
            jr z, .k3
            add hl, hl                      ; 4x
.k3:        add hl, de                      ; p = k * x (< 5120)
            ld a, h
            srl a
            srl a
            ldh [uw_y], a                   ; q = p >> 10
            ld a, h
            and 3
            ld h, a                         ; x = p & 1023
            cp 2
            jr c, .ok
            jr nz, .fold                    ; >= 768
            ld a, l
            and a
            jr z, .ok                       ; = 512: kept
.fold:      xor a                           ; > 512: 1024 - x
            sub l
            ld l, a
            ld a, 4
            sbc a, h
            ld h, a
.ok:        ld d, h
            ld e, l
            ld a, h                         ; entry = (x >> 1) & $FF
            srl a
            ld a, l
            rra
            pop hl
            ld [hl+], a
            dec c
            jr nz, .lp
            xor a
            ld [NES_RAM + $00], a
            ld [NES_RAM + $01], a
            ld [NES_RAM + $02], a
            ld [NES_RAM + $05], a
            ldh [nzv], a
            ld a, 4
            ld [NES_RAM + $03], a
            ldh a, [uw_y]
            ld [NES_RAM + $04], a
            ld a, e
            ld [NES_RAM + $06], a
            ld [NES_RAM + $08], a
            ld a, d
            ld [NES_RAM + $07], a
            ld [NES_RAM + $09], a
            pop de
            pop bc
            ld c, 0                         ; Y = 0
            ld e, 0                         ; X = 0
            ld a, [NES_RAM + $07]           ; A = the last entry, C = x bit 0
            srl a
            ld a, [NES_RAM + $06]
            rra
            ld l, 0
            inc l
            dec l                           ; Z = 1 (carry kept)
            ret

; DMG / SGB: palettes fixed by the field tileset (rt_ppu_w1 at LCD-on after $580B). FF2's
; current map tileset is in NES RAM: metatile m's four tiles at $0500 / $0580 / $0600 /
; $0680 + m, its attribute (palette in bits 0-1) at $0700 + m. A tile drawn with one palette
; in every metatile gets TILE_PAL = palette | $80 (re-coded if its palette changes); a tile
; drawn with two keeps the cell lookups (bit 7 clear). dmg_cell / dmg_attr / the scan skip
; fixed tiles, dmg_markw (a new pattern) clears the bit. The tileset's palettes count as used.
tset_fix_b: xor a
            ld [TSET_PEND], a
            ld hl, TILE_PAL                 ; no tile fixed or seen
.c:         ld a, [hl]
            and 3
            ld [hl], a
            inc l
            jr nz, .c
            ld d, 0                         ; D = palettes the tileset uses (bits)
            ld c, 0                         ; C = metatile
.m:         ld h, high(NES_RAM) + 7
            ld l, c
            ld a, [hl]
            and 3
            ld e, a                         ; E = its palette
            ld hl, BIT_MASK
            add a, l
            ld l, a
            jr nc, .bm
            inc h
.bm:        ld a, [hl]
            or d
            ld d, a
            ld h, high(NES_RAM) + 5
            ld l, c
            call .t
            set 7, l
            call .t
            inc h
            res 7, l
            call .t
            set 7, l
            call .t
            inc c
            bit 7, c
            jr z, .m
            ld hl, TILE_PAL + $80           ; tiles $80-$FF the tileset does not use: the font
.f:         ld a, [hl]                      ;   and window frame, always drawn with the window
            bit 6, a                        ;   palette 3 (fix:E92A fills the window's
            jr nz, .fn                      ;   attribute buffer with $FF)
            and 3
            cp 3
            jr z, .f3
            ld a, l
            call dmg_mark
.f3:        ld [hl], $83
.fn:        inc l
            jr nz, .f
            set 3, d                        ; (palette 3 in use)
            ld hl, TILE_PAL                 ; (seen marks off)
.s:         res 6, [hl]
            inc l
            jr nz, .s
            ld c, 0                         ; the palettes in use
.pu:        srl d
            jr nc, .pn
            ld a, c
            call pal_mark
.pn:        inc c
            ld a, c
            cp 4
            jr nz, .pu
            ret
.t:         push hl                         ; tile [HL] with palette E
            ld l, [hl]
            ld h, high(TILE_PAL)
            ld a, [hl]
            bit 6, a
            jr z, .first
            bit 7, a                        ; seen before: a second palette makes it a
            jr z, .tx                       ;   cell-looked-up tile
            and 3
            cp e
            jr z, .tx
            res 7, [hl]
            jr .tx
.first:     and 3
            cp e
            jr z, .same
            ld a, l
            call dmg_mark
.same:      ld a, e
            or $C0
            ld [hl], a
.tx:        pop hl
            ret

; DMG palette maps (moved from rt/dmg_shade.s dmg_maps: bank 0 is full); see there.
dmg_maps_b: push bc
            push de
            push hl
            call bg_lmax
            and a
            jp z, .x
            ld [REF_LMAX], a                ; brightness the BGP fade level is measured from
            ld a, [PAL_SH]
            call lum
            ldh [sh_bk], a                  ; backdrop brightness
            ld hl, LVF                      ; levels present (other than the backdrop's)
            ld b, 9
            xor a
.cl:        ld [hl+], a
            dec b
            jr nz, .cl
            ld c, 0
.lv:        ld a, c
            and 3
            jr z, .mn
            ld a, [PAL_USED]                ; palettes no cell uses: their colours left out
            and a
            jr z, .lu
            ld b, a
            ld a, c
            srl a
            srl a
            inc a
.lb:        rr b
            dec a
            jr nz, .lb
            jr nc, .mn
.lu:
            ld l, c
            ld h, high(PAL_SH)
            ld a, [hl]
            call lum
            ld b, a
            ldh a, [sh_bk]
            cp b
            jr z, .mn
            ld a, b
            add a, low(LVF)
            ld l, a
            ld h, high(LVF)
            ld [hl], 1
.mn:        inc c
            ld a, c
            cp 16
            jr nz, .lv
            ld e, 0                         ; LSL = the levels present, ascending; E = count
            ld c, 0
.ls:        ld a, c
            add a, low(LVF)
            ld l, a
            ld h, high(LVF)
            ld a, [hl]
            and a
            jr z, .ln
            ld a, e
            add a, low(LSL)
            ld l, a
            ld h, high(LSL)
            ld [hl], c
            inc e
.ln:        inc c
            ld a, c
            cp 9
            jr nz, .ls
            xor a                           ; cuts (group ends): sh_s0 < sh_s1
            ldh [sh_s0], a
            inc a
            ldh [sh_s1], a
            ld a, e
            cp 4
            jr c, .asg
            ld a, $FF
            call .maxgap
            ld d, a
            call .maxgap
            cp d
            jr nc, .ord
            ld b, a
            ld a, d
            ld d, b
.ord:       ldh [sh_s1], a
            ld a, d
            ldh [sh_s0], a
.asg:       ld a, e                         ; number of values in use
            cp 4
            jr c, .ng
            ld a, 3
.ng:        ld [NGRP], a
            ld c, 0
.as:        ld a, c
            cp e
            jr z, .pm
            ld b, 1                         ; value = 1 + (i > cut 0) + (i > cut 1)
            ldh a, [sh_s0]
            cp c
            jr nc, .a1
            inc b
.a1:        ldh a, [sh_s1]
            cp c
            jr nc, .a2
            inc b
.a2:        ld a, c
            add a, low(LSL)
            ld l, a
            ld h, high(LSL)
            ld a, [hl]                      ; level
            ld d, a
            add a, low(LVMAP)
            ld l, a
            ld h, high(LVMAP)
            ld [hl], b
            ld a, b                         ; GLUM[value] = its brightest level
            add a, low(GLUM)
            ld l, a
            ld [hl], d
            inc c
            jr .as
.pm:        ld c, 0                         ; palette
.p:         ld a, c
            add a, a
            add a, a
            ld l, a
            ld h, high(PAL_SH)
            ld de, RT_BUF
            xor a
            ld [de], a                      ; colour 0 -> 0
            inc de
            ld b, 3
            ldh [sh_chg], a                 ; (0: all three like the backdrop so far)
.pc:        inc l
            ld a, [hl]
            push hl
            call lum
            ld h, a
            ldh a, [sh_bk]
            cp h
            ld a, 0
            jr z, .pz
            ld a, h
            add a, low(LVMAP)
            ld l, a
            ld h, high(LVMAP)
            ld a, [hl]
            ld h, a
            ld a, 1
            ldh [sh_chg], a
            ld a, h
.pz:        pop hl
            ld [de], a
            inc de
            dec b
            jr nz, .pc
            ldh a, [sh_chg]                 ; a palette that is all backdrop keeps its map
            and a
            jr z, .nx
            ld a, c                         ; compare with PAL_MAP[c]; copy; mark if changed
            add a, a
            add a, a
            add a, low(PAL_MAP)
            ld l, a
            ld h, high(PAL_MAP)
            ld de, RT_BUF
            ld b, 4
            xor a
            ldh [sh_chg], a                 ; sh_chg: indices whose value changed (bit i)
            inc a
            ldh [sh_l1], a                  ; (bit of the index being compared)
.cmp:       ld a, [de]
            cp [hl]
            jr z, .same
            ld [hl], a
            push bc
            ldh a, [sh_l1]
            ld b, a
            ldh a, [sh_chg]
            or b
            ldh [sh_chg], a
            pop bc
.same:      ldh a, [sh_l1]
            add a, a
            ldh [sh_l1], a
            inc de
            inc hl
            dec b
            jr nz, .cmp
            ldh a, [sh_chg]
            and a
            call nz, .markp
.nx:        inc c
            ld a, c
            cp 4
            jp nz, .p
            call spr_maps
.x:         pop hl
            pop de
            pop bc
            ret
.maxgap:    ; A = gap index to skip -> A = index i of the largest LSL[i+1] - LSL[i]
            ldh [sh_l1], a                  ;   (the first one of equal gaps); keeps D, E
            xor a
            ldh [sh_l2], a
            ldh [sh_l3], a
            ld c, 0
.mg:        ld a, c
            inc a
            cp e
            jr nc, .mgx
            ldh a, [sh_l1]
            cp c
            jr z, .mgn
            ld a, c
            add a, low(LSL)
            ld l, a
            ld h, high(LSL)
            ld a, [hl+]
            ld b, a
            ld a, [hl]
            sub b
            ld b, a
            ldh a, [sh_l2]
            cp b
            jr nc, .mgn
            ld a, b
            ldh [sh_l2], a
            ld a, c
            ldh [sh_l3], a
.mgn:       inc c
            jr .mg
.mgx:       ldh a, [sh_l3]
            ret
.markp:     ; queue every tile coded for palette C that uses an index in sh_chg
            push bc
            ld hl, TILE_PAL
.tk:        ld a, [hl]
            and 3
            cp c
            jr nz, .tn
            push hl
            ld a, l                         ; its TILE_USE nibble
            ld d, a
            srl a
            add a, low(TILE_USE)
            ld l, a
            ld h, high(TILE_USE)
            ld a, [hl]
            bit 0, d
            jr z, .te
            swap a
.te:        and $0F
            ld b, a
            ldh a, [sh_chg]
            and b
            pop hl
            jr z, .tn
            ld a, l
            call dmg_mark
.tn:        inc l
            jr nz, .tk
            pop bc
            ret

; BGP: value 0 = the backdrop's shade. Over a black backdrop, values 1-3 get dark grey /
; light grey / white (two values: dark grey / white); otherwise each value the shade of its
; brightest level. Darkened while the palettes are faded: one shade per two brightness
; levels the brightest BG colour is below REF_LMAX (its level when the maps were last
; computed). Returns A = BGP.

; ------------------------------------------------------------------ native field scroll
; fix:D21B "update map background" (once per step on a normal map): D66A writes the new row
; (vertical move: 2 x 16 metatiles = 64 tiles, wrapping into the other nametable) or column
; (horizontal: 2 x 15, $2000 = 4 while it writes) from the buffer $0780-$07BF, D2FE then the
; attribute bytes ($07D0 / $07E0 address, $07F0 value; 16 or 15 of them). Same writes, same
; NES RAM ($80-$82, $32), registers and flags as the NES; on a DMG / SGB each tile is shaded
; with its metatile's palette from the buffer ($07C0) instead of looking the cell up, and the
; attribute bytes only go to the shadow (the cells they change were just written). CGB: every
; write through rt_ppu_w7. (docs/gb-native-presentation.md, step 1)
MU_N       = $DCD4          ; wrap index
MU_YF      = $DCD5          ; Y at the end (16 / 15)
MU_BA      = $DCD6          ; buffer pair (low bytes in page $07)
MU_BB      = $DCD7
MU_P       = $DCD8          ; palette of the tile being written
MU_T       = $DCD9          ; the tile
MU_GH      = $DCDA          ; its GB map address
MU_GL      = $DCDB
MU_WH      = $DCDC          ; wrap address (columns)
MU_WL      = $DCDD
hle_mapupd_b:
            ld a, [NES_RAM + $30]           ; $80/$81 = $2000 + 64 * $30 + 2 * column
            ld l, a                         ;   (+ $400: nametable 1)
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld a, h
            add a, $20
            ld d, a
            ld a, [NES_RAM + $31]
            cp 16
            jr c, .c0
            and $0F
            inc d
            inc d
            inc d
            inc d
.c0:        add a, a
            or l
            ld e, a
            ld [NES_RAM + $80], a
            ld a, d
            ld [NES_RAM + $81], a
            ld a, [NES_RAM + $2D]
            and 2
            jp nz, .horiz
            ld a, e                         ; vertical: $82 = 16 - column
            and $1F
            srl a
            xor $0F
            inc a
            ld [NES_RAM + $82], a
            ld [MU_N], a
            ld a, $80
            ld [MU_BA], a
            ld a, $90
            ld [MU_BB], a
            call .vrow
            ld a, [NES_RAM + $80]
            add a, $20
            ld [NES_RAM + $80], a
            ld e, a
            ld a, [NES_RAM + $81]
            ld d, a
            ld a, $A0
            ld [MU_BA], a
            ld a, $B0
            ld [MU_BB], a
            call .vrow
            ld a, 16
            ld [MU_YF], a
            jp .attr
.vrow:      ld a, d                         ; y = 0..15: BA[y], BB[y] at (D, E), +1 each;
            xor 4                           ;   from y = $82 on in the other nametable's row
            ld [MU_WH], a                   ;   (its start: the row start's $81 ^ 4,
            ld a, e                         ;   $80 & $E0)
            and $E0
            ld [MU_WL], a
            ld b, 0
            ldh a, [lcd_on]                 ; LCD off: the cells inline (.coff)
            and a
            jr nz, .vl
.vo:        ld a, [MU_N]
            cp b
            jr nz, .vo1
            ld a, [MU_WH]
            ld d, a
            ld a, [MU_WL]
            ld e, a
.vo1:       ld a, [MU_BA]
            add a, b
            ld l, a
            ld h, high(NES_RAM) + 7
            ld a, [hl]
            call .coff
            inc e
            ld a, [MU_BB]
            add a, b
            ld l, a
            ld h, high(NES_RAM) + 7
            ld a, [hl]
            call .coff
            inc e
            inc b
            ld a, b
            cp 16
            jr nz, .vo
            jp .offx
.vl:        ld a, [MU_N]
            cp b
            jr nz, .vn
            ld a, [MU_WH]
            ld d, a
            ld a, [MU_WL]
            ld e, a
.vn:        call .pal
            ld a, [MU_BA]
            call .tile
            inc e
            ld a, [MU_BB]
            call .tile
            inc e
            inc b
            ld a, b
            cp 16
            jr nz, .vl
            ret
.horiz:     ld a, [NES_RAM + $30]           ; horizontal: $82 = 15 - $30
            ld b, a
            ld a, $0F
            sub b
            ld [NES_RAM + $82], a
            ld [MU_N], a
            ld a, 4
            call rt_ppu_w0
            ld a, $80
            ld [MU_BA], a
            ld a, $A0
            ld [MU_BB], a
            call .hcol
            ld a, [NES_RAM + $81]
            ld d, a
            ld a, [NES_RAM + $80]
            inc a
            ld e, a
            ld a, $90
            ld [MU_BA], a
            ld a, $B0
            ld [MU_BB], a
            call .hcol
            ld a, $88
            call rt_ppu_w0
            ld a, 15
            ld [MU_YF], a
            jp .attr
.hcol:      ld a, d                         ; y = 0..14: BA[y] at (D, E), BB[y] 32 below,
            and $24                         ;   64 further each; from y = $82 on from the top
            ld [MU_WH], a                   ;   of the same column
            ld a, e
            and $1F
            ld [MU_WL], a
            ld b, 0
            ldh a, [lcd_on]                 ; LCD off: the cells inline (.coff)
            and a
            jr nz, .hl
.ho:        ld a, [MU_N]
            cp b
            jr nz, .ho1
            ld a, [MU_WH]
            ld d, a
            ld a, [MU_WL]
            ld e, a
.ho1:       ld a, [MU_BA]
            add a, b
            ld l, a
            ld h, high(NES_RAM) + 7
            ld a, [hl]
            call .coff
            call .d32
            ld a, [MU_BB]
            add a, b
            ld l, a
            ld h, high(NES_RAM) + 7
            ld a, [hl]
            call .coff
            call .d32
            inc b
            ld a, b
            cp 15
            jr nz, .ho
            jp .offx
; LCD off: tile A to the cell at NES address (D, E): GB map, shadow, owner bit (own1 counted;
; CGB: CGB_SCAN on a change). Keeps B, D, E.
.coff:      ld c, a
            ld a, d
            and 3
            add a, $98
            ld h, a
            ld l, e
            ld [hl], c
            ld a, d
            and 7
            add a, high(NT_SH)
            ld h, a
            ld [hl], c
            ld a, e
            and 7
            ld l, a
            ld h, high(BITS8)
            ld c, [hl]
            ld a, e
            rrca
            rrca
            rrca
            and $1F
            ld l, a
            ld a, d
            and 3
            swap a
            add a, a
            or l
            ld l, a
            ld h, high(OWN)
            bit 2, d
            jr z, .k0
            ld a, [hl]
            and c
            ret nz
            ld a, [hl]
            or c
            ld [hl], a
            ldh a, [own1_lo]
            add a, 1
            ldh [own1_lo], a
            ldh a, [own1_hi]
            adc a, 0
            ldh [own1_hi], a
            jr .kch
.k0:        ld a, [hl]
            and c
            ret z
            ld a, c
            cpl
            and [hl]
            ld [hl], a
            ldh a, [own1_lo]
            sub 1
            ldh [own1_lo], a
            ldh a, [own1_hi]
            sbc a, 0
            ldh [own1_hi], a
.kch:       ld a, 1
            ld [CGB_SCAN], a                ; (DMG: harmless; the scan flag is set at the end)
            ret
.offx:      ldh a, [is_cgb]                 ; DMG / SGB: the scan when the LCD goes on
            and a
            ret nz
            ld a, 1
            ldh [dmg_scan], a
            ret
.hl:        ld a, [MU_N]
            cp b
            jr nz, .hn
            ld a, [MU_WH]
            ld d, a
            ld a, [MU_WL]
            ld e, a
.hn:        call .pal
            ld a, [MU_BA]
            call .tile
            call .d32
            ld a, [MU_BB]
            call .tile
            call .d32
            inc b
            ld a, b
            cp 15
            jr nz, .hl
            ret
.d32:       ld a, e
            add a, 32
            ld e, a
            ret nc
            inc d
            ret
.pal:       ld a, b                         ; MU_P = $07C0[y] & 3
            add a, $C0
            ld l, a
            ld h, high(NES_RAM) + 7
            ld a, [hl]
            and 3
            ld [MU_P], a
            ret
.tile:      add a, b                        ; tile $07xx[y] to (D, E)
            ld l, a
            ld h, high(NES_RAM) + 7
            ld a, [hl]
            jp mu_write
.attr:      ld a, [NES_RAM + $2D]           ; D2FE: X = $0F (vertical) / $0E .. 0
            and 2
            ld b, $0F
            jr z, .a0
            dec b
.a0:        ld a, b
            add a, $D0
            ld l, a
            ld h, high(NES_RAM) + 7
            ld d, [hl]
            add a, $10
            ld l, a
            ld e, [hl]
            add a, $10
            ld l, a
            ld a, [hl]
            call mu_attr
            dec b
            bit 7, b
            jr z, .a0
            ld a, e                         ; the PPU address left one past the last write
            add a, 1
            ldh [ppu_vl], a
            ld a, d
            adc a, 0
            and $3F
            ldh [ppu_vh], a
            xor a
            ldh [ppu_latch], a
            ldh [vbl_flag], a
            ld [NES_RAM + $32], a
            ldh [nzv], a                    ; N = 0
            ld b, a
            ld d, a
            ld e, $FF                       ; X = $FF
            ld a, [MU_YF]
            ld c, a                         ; Y
            xor a                           ; A = 0, Z = 1, carry = 1 (the last CPY)
            scf
            ret

; tile A to NES address (D, E) with palette MU_P: shadow, owner (CGB: the cell's palette from
; its new nametable), DMG / SGB shading, GB map (as rt_ppu_w7's nametable path). Keeps B-E.
mu_write:   push bc
            push de
            push hl
            ld [MU_T], a
            ldh a, [lcd_on]                 ; LCD off: GB map, shadow, owner bit directly
            and a
            jp z, .off
            ld a, d                         ; B = offset high (0-3), C = 4 for nametable 1,
            and 4                           ;   L = offset low
            ld c, a
            ld a, d
            and 3
            ld b, a
            add a, $98                      ; GB map address
            ld [MU_GH], a
            ld l, e
            ld a, e
            ld [MU_GL], a
            ld a, b
            or c
            add a, high(NT_SH)
            ld h, a
            ld a, [MU_T]
            ld d, a
            ld a, [hl]                      ; shadow; Z = the same tile
            ld [hl], d
            cp d
            push af
            call own_set                    ; (CGB: the cell's palette if the owner changed)
            pop af
            jr z, .vram
            ldh a, [is_cgb]                 ; CGB: no shading
            and a
            jr nz, .vram
            ldh a, [lcd_on]                 ; (LCD off: the scan when it goes on)
            and a
            jr nz, .sh
            inc a
            ldh [dmg_scan], a
            jr .vram
.sh:        ld l, d                         ; shading: fixed by the tileset or the same palette -
            ld h, high(TILE_PAL)            ;   a parked tile is marked again (the cell uses it
            ld a, [hl]                      ;   now: after a door the room's tiles are parked
            bit 7, a                        ;   when the LCD goes on, before the rows are
            jr nz, .pk                      ;   drawn); another palette - re-coded for this one
            ld a, [MU_P]
            cp [hl]
            jr z, .pk
            ld [hl], a
            ld a, d
            call dmg_mark
            jr .vram
.pk:        ld c, d
            call bm_addr
            ld a, l
            add a, low(DEFER_BM) - low(DIRTY_BM)
            ld l, a
            ld a, [hl]
            and b
            jr z, .vram
            ld a, b
            cpl
            and [hl]
            ld [hl], a
            ld a, d
            call dmg_mark
.vram:      ld a, [MU_GH]
            ld h, a
            ld a, [MU_GL]
            ld l, a
            ld a, [MU_T]
            ld d, a
            ldh a, [lcd_on]
            and a
            jr nz, .q
            ld [hl], d
            jr .x
.q:         ldh a, [q_tail]
            ld e, a
            inc a
            ld b, a
.f:         ldh a, [q_head]
            cp b
            jr nz, .r
            call q_drain1
            jr .f
.r:         ld a, l
            ld c, h
            ld h, high(QH)
            ld l, e
            ld [hl], c
            inc h
            ld [hl], a
            inc h
            ld [hl], d
            ld a, b
            ldh [q_tail], a
.x:         pop hl
            pop de
            pop bc
            ret

.off:       ld a, d                         ; GB map $9800 + offset (rows 0-29)
            and 3
            add a, $98
            ld h, a
            ld l, e
            ld a, [MU_T]
            ld [hl], a
            ld b, a
            ld a, d                         ; shadow (+ $400 for nametable 1)
            and 7
            add a, high(NT_SH)
            ld h, a
            ld [hl], b
            ld a, e                         ; owner: OWN + (offset high) * 32 + low / 8,
            and 7                           ;   bit low & 7 (set: nametable 1)
            ld l, a
            ld h, high(BITS8)
            ld c, [hl]
            ld a, e
            rrca
            rrca
            rrca
            and $1F
            ld l, a
            ld a, d
            and 3
            swap a
            add a, a
            or l
            ld l, a
            ld h, high(OWN)
            bit 2, d
            jr z, .o0
            ld a, [hl]                      ; nametable 1: 0 -> 1
            and c
            jr nz, .ok
            ld a, [hl]
            or c
            ld [hl], a
            ldh a, [own1_lo]
            add a, 1
            ldh [own1_lo], a
            ldh a, [own1_hi]
            adc a, 0
            ldh [own1_hi], a
            jr .chg
.o0:        ld a, [hl]                      ; nametable 0: 1 -> 0
            and c
            jr z, .ok
            ld a, c
            cpl
            and [hl]
            ld [hl], a
            ldh a, [own1_lo]
            sub 1
            ldh [own1_lo], a
            ldh a, [own1_hi]
            sbc a, 0
            ldh [own1_hi], a
.chg:       ldh a, [is_cgb]                 ; CGB: the cells' palettes when the LCD goes on
            and a
            jr z, .ok
            ld a, 1
            ld [CGB_SCAN], a
.ok:        ldh a, [is_cgb]                 ; DMG / SGB: the scan when the LCD goes on
            and a
            jr nz, .xo
            ld a, 1
            ldh [dmg_scan], a
.xo:        pop hl
            pop de
            pop bc
            ret

; attribute byte A to NES address (D, E): DMG / SGB the shadow only (and the SGB's attribute
; map again); CGB through rt_ppu_w7. Keeps B, C, D, E.
mu_attr:    push bc
            push de
            push hl
            ld [MU_T], a
            ldh a, [is_cgb]
            and a
            jr z, .dmg
            ld a, d
            and $3F
            ldh [ppu_vh], a
            ld a, e
            ldh [ppu_vl], a
            ld a, [MU_T]
            call rt_ppu_w7
            jr .x
.dmg:       ld a, d
            and 7
            add a, high(NT_SH)
            ld h, a
            ld l, e
            ld a, [MU_T]
            cp [hl]
            jr z, .x
            ld [hl], a
            ldh a, [lcd_on]
            and a
            jr nz, .on
            inc a
            ldh [dmg_scan], a
            jr .x
.on:        ldh a, [sgb_glob]
            and a
            jr nz, .x
            ld a, 1
            ldh [sgb_dirty], a
            ldh [sgb_adirty], a
.x:         pop hl
            pop de
            pop bc
            ret

; fix:C46E "clear OAM data" (every frame): $0200-$02FF = $F0, $26 = 0. Exit as the NES:
; A = 0, X = $FF, N = 0, Z = 1, carry as on entry.
hle_oamclr_b:
            push af                         ; (the caller's carry)
            ld hl, NES_RAM + $200
            ld a, $F0
            ld e, 16
.l:         ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            dec e
            jr nz, .l
            pop af
            ld a, 0
            ld [NES_RAM + $26], a
            ldh [nzv], a
            ld e, 1
            dec e                           ; Z = 1, carry kept
            ld e, $FF
            ret

; layout.py's vtile (banks 23 / 24): A = tile, X (E) = 8 VC: the tile's 16 bytes (plane 0
; from VBUF = NES $7800 + X, cart RAM bank 0; plane 1 $FF) to the pattern table at
; (TBLHI = NES $7FEB) * 256 + 16 * tile, then $2006 / $2007 as the NES leaves them. DMG BG
; tile: the shadow (cart RAM bank 1) and one re-coding mark; CGB BG tile: VRAM (LCD off) or
; the tile copy + HDMA mark; a sprite-table tile byte by byte through rt_ppu_w7. Exit: A =
; $FF, X = 8 VC + 8, Y = 0, Z = 1, N = 0, C = 0.
VT_BUF     = $DCDE          ; plane 0 (8)
hle_vtile_b:
            ld d, a                         ; D = tile
            ld a, [$BFE5]                   ; X = 8 VC (VC = NES $7FE5); VBUF + X -> VT_BUF
            add a, a                        ;   (cart RAM bank 0 is mapped)
            add a, a
            add a, a
            ld e, a
            ld l, a
            ld h, $B8
            push de
            ld de, VT_BUF
            ld b, 8
.cp:        ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .cp
            pop de
            ld a, d                         ; PPU address: TBLHI | tile >> 4, tile << 4
            swap a
            and $0F
            ld b, a
            ld a, [$BFEB]
            or b
            ldh [ppu_vh], a
            ld a, d
            swap a
            and $F0
            ldh [ppu_vl], a
            ldh a, [ppu_vh]                 ; BG = the table $2000 bit 4 selects (as rt_ppu_w7)
            and $10
            ld b, a
            ldh a, [ppu_ctrl]
            and $10
            xor b
            jr nz, .slow
            ldh a, [is_cgb]
            and a
            jr nz, .cgb
            ldh a, [ppu_vh]                 ; DMG: shadow $B000 + (vh & $0F) * 256 + vl
            and $0F
            add a, high(BG_SHADOW)
            ld h, a
            ldh a, [ppu_vl]
            ld l, a
            ld a, 1
            ld [$4000], a
            call .put
            xor a
            ld [$4000], a
            ld a, d
            call dmg_markw
            jr .done
.cgb:       ldh a, [lcd_on]
            and a
            jr z, .vram
            ldh a, [ppu_vh]                 ; CGB, LCD on: the tile copy (WRAM 2), HDMA mark
            and $0F
            add a, $D0
            ld h, a
            ldh a, [ppu_vl]
            ld l, a
            ld a, 2
            ldh [$FF70], a
            call .put
            ld a, 1
            ldh [$FF70], a
            ld a, d
            ld hl, BG_DIRTY
            call hd_mark
            jr .done
.vram:      ldh a, [ppu_vh]                 ; CGB, LCD off: VRAM (tiles 0-127 $9000, 128-255 $8800)
            and $0F
            cp $08
            ld b, $90
            jr c, .v0
            ld b, $80
.v0:        add a, b
            ld h, a
            ldh a, [ppu_vl]
            ld l, a
            call .put
            jr .done
.slow:      ld hl, VT_BUF                   ; (sprite table: byte by byte)
            ld b, 8
.s0:        ld a, [hl+]
            call rt_ppu_w7
            dec b
            jr nz, .s0
            ld b, 8
            ld a, $FF
.s1:        call rt_ppu_w7
            dec b
            jr nz, .s1
            jr .x
.done:      ldh a, [ppu_vl]                 ; PPU address left 16 on
            add a, 16
            ldh [ppu_vl], a
            ldh a, [ppu_vh]
            adc a, 0
            and $3F
            ldh [ppu_vh], a
.x:         ld a, e
            add a, 8
            ld e, a                         ; X
            ld bc, 0                        ; Y = 0 (B = 0)
            ld d, b
            xor a
            ldh [nzv], a                    ; N = 0, Z = 1, C = 0
            ld a, $FF                       ; (ld keeps the flags)
            ret
.put:       push de                         ; HL = the tile in GB byte order: plane 0 rows to
            ld de, VT_BUF                   ;   even bytes, plane 1 ($FF) to odd
            ld b, 8
.p:         ld a, [de]
            inc de
            ld [hl+], a
            ld [hl], $FF
            inc hl
            dec b
            jr nz, .p
            pop de
            ret

; b03:A902 "draw object sprite" (NPCs, every frame on a normal map): 4 OAM entries at
; $0200 + $26 from $40 (x) / $41 (y) and the 8 bytes at ($80) (tile + $82, flags; ROM in bank
; 3 for the NPC graphics table) - one banked copy of the 8 bytes instead of 8 indirect reads
; with two bank switches each. Exit as the NES: $26 += 16, A = $26, X = the old $26, Y = 7,
; N Z C V of the ADC.
hle_objspr_b:
            ld a, [NES_RAM + $81]           ; the 8 bytes -> VT_BUF
            ld h, a
            ld a, [NES_RAM + $80]
            ld l, a
            ld a, h
            cp $20
            jr c, .ram
            cp $60
            jr c, .io
            cp $80
            jr c, .sram
            cp $C0
            jr nc, .fix
            sub $40                         ; $8000-$BFFF: the data image of the NES bank there
            ld h, a
            ldh a, [data_bank8]
            jr .rd
.fix:       sub $80                         ; $C000-$DFFF / $E000-$FFFF
            ld h, a
            cp $60
            ld a, DATA + 31
            jr nc, .rd
            ldh a, [data_bankC]
.rd:        call rd8_bank
            jr .have
.sram:      add a, $40                      ; NES $6000-$7FFF = cart RAM $A000-$BFFF
            ld h, a
            jr .copy
.ram:       and $07
            add a, high(NES_RAM)
            ld h, a
.copy:      ld de, VT_BUF
            ld b, 8
.cl:        ld a, [hl+]
            ld [de], a
            inc e
            dec b
            jr nz, .cl
            jr .have
.io:        ld a, 3
            jp rt_fault
.have:      ld a, [NES_RAM + $26]
            ld [MU_T], a                    ; (the old $26: X at the end)
            ld l, a
            ld h, high(NES_RAM) + 2
            ld a, [NES_RAM + $41]           ; y: entries 0 / 2 (+0, +8), y + 8: 1 / 3 (+4, +12)
            ld [hl], a
            set 3, l
            ld [hl], a
            add a, 8
            res 3, l
            set 2, l
            ld [hl], a
            set 3, l
            ld [hl], a
            ld a, [MU_T]                    ; x: entries 0 / 1 (+3, +7), x + 8: 2 / 3 (+11, +15)
            add a, 3
            ld l, a
            ld a, [NES_RAM + $40]
            ld [hl], a
            set 2, l
            ld [hl], a
            add a, 8
            set 3, l
            ld [hl], a
            res 2, l
            ld [hl], a
            ld a, [NES_RAM + $82]           ; tiles + $82 (+1), flags (+2), entry by entry
            ld b, a
            ld a, [MU_T]
            inc a
            ld l, a
            ld de, VT_BUF
            ld c, 4
.pr:        ld a, [de]
            inc e
            add a, b
            ld [hl+], a
            ld a, [de]
            inc e
            ld [hl], a
            ld a, l
            add a, 3
            ld l, a
            dec c
            jr nz, .pr
            ld a, [MU_T]                    ; $26 += 16 (V: $70-$7F become negative)
            ld e, a                         ; X
            ld c, 0
            cp $70
            jr c, .nv
            cp $80
            jr nc, .nv
            ld c, $40
.nv:        ld a, c
            ldh [vfl], a
            ld bc, 7                        ; Y = 7 (B = 0)
            ld d, b
            ld a, e
            add a, $10                      ; Z, C
            ld [NES_RAM + $26], a
            ldh [nzv], a                    ; N
            ret

; fix:C2F3 world-map water animation (every frame on the world map): $6D += 3 picks a pair
; of pattern addresses from the table at $C34F (one bit-plane row of two tiles); the 16-bit
; row ($80:$81) is read back, rotated a pixel left and written again. The same NES state as
; the routine ($6D, $80, $81, X, A, N Z C V, PPU address / read buffer / latch / vblank flag);
; the two bytes go through chr_w1 (DMG: only the changed tile row re-coded, instead of two
; whole tiles marked for re-coding every frame).
hle_water_b:
            push bc
            ld a, [NES_RAM + $6D]           ; CLC / ADC #3 (V: $7D-$7F become negative)
            ld b, a
            add a, 3
            ld [NES_RAM + $6D], a
            ld c, a
            xor b
            ld d, a
            ld a, c
            xor 3
            and d
            and $80
            rrca
            ldh [vfl], a
            ld a, c
            and $0F
            add a, a
            ld [MU_T], a                    ; X
            add a, $4F                      ; the table pair: GB $434F + X in the fixed bank's
            ld l, a                         ;   data image
            ld h, $43
            ld a, DATA + 31
            call rd8_bank
            xor a                           ; LDA $2002
            ldh [vbl_flag], a
            ldh [ppu_latch], a
            ld a, [VT_BUF]
            call .rd
            ld [NES_RAM + $80], a
            ld a, [VT_BUF + 1]
            call .rd
            ld [NES_RAM + $81], a
            ld hl, NES_RAM + $80            ; ASL A ($80) / ROL $81 / ROL $80
            ld a, [hl]
            add a, a
            inc l
            rl [hl]
            dec l
            rl [hl]
            ld a, [NES_RAM + $80]
            ld d, a
            ld a, [VT_BUF]
            call .wr
            ld a, [NES_RAM + $81]
            ld d, a
            ld a, [VT_BUF + 1]
            call .wr
            ld a, [MU_T]
            ld e, a
            ld d, 0
            pop bc
            ld a, [NES_RAM + $81]           ; A, N, Z = $81 (LDA $81); C = the bit ROL $80
            ldh [nzv], a                    ;   shifted out = bit 0 of $81
            ld h, a
            rrca
            ld a, h
            inc a
            dec a
            ret
.rd:        ldh [ppu_vl], a                 ; A = address low ($03xx): the two LDA $2007
            ld a, $03
            ldh [ppu_vh], a
            call rt_ppu_r7
            call rt_ppu_r7
            ld a, l
            ret
.wr:        ldh [ppu_vl], a
            ld a, $03
            ldh [ppu_vh], a
; D = byte to the NES pattern address ppu_vh / ppu_vl: rt_ppu_w7 with a fast DMG path. A BG
; tile that is coded and not waiting (CODED != $FF, not in DIRTY_BM / DEFER_BM) whose new row
; uses no colour index the tile did not use: the shadow byte and only that row re-coded
; (its two GB bytes through vram_put). Otherwise rt_ppu_w7. Keeps BC, DE.
chr_w1:     push bc
            push de
            ldh a, [is_cgb]
            and a
            jr nz, .gen
            ldh a, [ppu_vh]
            cp $20
            jr nc, .gen
            ld h, a
            and $10
            ld b, a
            ldh a, [ppu_ctrl]
            and $10
            xor b
            jr nz, .gen
            ld a, h
            and $0F
            ld h, a                         ; H = tile high nibble
            swap a
            ld b, a
            ldh a, [ppu_vl]
            ld l, a
            swap a
            and $0F
            or b
            ld e, a                         ; E = tile
            ldh [sh_tile], a
            push hl
            ld c, a
            call bm_addr                    ; waiting for re-coding, parked, or coding unknown:
            ld a, [hl]                      ;   the general path
            and b
            jr nz, .genp
            ld a, l
            add a, low(DEFER_BM) - low(DIRTY_BM)
            ld l, a
            ld a, [hl]
            and b
            jr nz, .genp
            ld l, e
            ld h, high(CODED)
            ld a, [hl]
            inc a
            jr z, .genp
            pop hl
            ld a, l                         ; GB byte offset in the tile (plane 0 rows even,
            and $0F                         ;   plane 1 odd)
            cp 8
            jr c, .p0
            sub 8
            add a, a
            inc a
            jr .pk
.p0:        add a, a
.pk:        ldh [sh_l1], a
            ld b, a
            ld a, l
            and $F0
            or b
            ld l, a
            ld a, h
            add a, high(BG_SHADOW)
            ld h, a
            ld a, 1
            ld [$4000], a
            ld [hl], d
            ld a, l
            xor 1
            ld l, a
            ld c, [hl]                      ; the row's other plane
            xor a
            ld [$4000], a
            bit 0, b
            jr z, .ev
            ld a, c
            ld c, d
            ld d, a
.ev:        ld a, d                         ; D = p0, C = p1
            ldh [sh_p0], a
            ld a, c
            ldh [sh_p1], a
            ld l, 0                         ; L = colour indices the row uses (1-3)
            ld a, c
            cpl
            and d
            jr z, .n1
            set 1, l
.n1:        ld a, d
            cpl
            and c
            jr z, .n2
            set 2, l
.n2:        ld a, d
            and c
            jr z, .n3
            set 3, l
.n3:        ld a, e                         ; an index the tile did not use: its coding key
            srl a                           ;   changes (general path; the shadow byte is
            add a, low(TILE_USE)            ;   simply written again)
            ld c, a
            ld b, high(TILE_USE)
            ld a, [bc]
            bit 0, e
            jr z, .lo
            swap a
.lo:        and $0F
            cpl
            and l
            jr nz, .gen
            ld l, e                         ; masks of the tile's palette (as retile_b)
            ld h, high(TILE_PAL)
            ld a, [hl]
            and 3
            add a, a
            add a, a
            add a, low(PAL_MAP)
            ld l, a
            ld h, high(PAL_MAP)
            ld bc, 0                        ; B = indices whose value has bit 0, C = bit 1
            ld d, 1
.m:         ld a, [hl+]
            rrca
            jr nc, .m0
            ld e, a
            ld a, b
            or d
            ld b, a
            ld a, e
.m0:        rrca
            jr nc, .m1
            ld a, c
            or d
            ld c, a
.m1:        sla d
            bit 4, d
            jr z, .m
            ld hl, RM
            ld a, b
            call rt_anf
            ld a, c
            call rt_anf
            ldh a, [sh_p0]                  ; the row through the masks
            ld b, a
            ldh a, [sh_p1]
            ld c, a
            and b
            ld d, a                         ; p0 & p1
            ld a, [RM + 4]                  ; plane 1
            and b
            ld e, a
            ld a, [RM + 5]
            and c
            xor e
            ld e, a
            ld a, [RM + 6]
            and d
            xor e
            ld e, a
            ld a, [RM + 7]
            xor e
            ldh [sh_m1], a
            ld a, [RM]                      ; plane 0
            and b
            ld e, a
            ld a, [RM + 1]
            and c
            xor e
            ld e, a
            ld a, [RM + 2]
            and d
            xor e
            ld e, a
            ld a, [RM + 3]
            xor e
            ld e, a
            ldh a, [sh_tile]                ; VRAM: tiles 0-127 at $9000, 128-255 at $8800
            swap a
            ld b, a
            and $F0
            ld l, a
            ldh a, [sh_l1]
            and $0E
            or l
            ld l, a
            ld a, b
            and $0F
            cp 8
            jr nc, .hi
            add a, $10
.hi:        add a, $80
            ld h, a
            ld a, e
            call vram_put
            inc l
            ldh a, [sh_m1]
            call vram_put
            call ppu_inc
            pop de
            pop bc
            ret
.genp:      pop hl
.gen:       pop de
            ld a, d
            pop bc
            jp rt_ppu_w7

; LCD going on after drawing with it off (dmg_scan_all, rt/dmg_shade.s): every GB map cell
; (rows 0-29) gives its tile the palette it is drawn with (from the nametable that owns the
; cell; tiles coded for another palette are marked, parked tiles in use marked again) and
; the tile counts as used (REF_BM). The cells in the GB view come last, so that a tile drawn
; there with another palette than off the view is coded for the view, and give PAL_USED (the
; palettes of the view). Each cell once, per row set-up, bit masks from a table.
SC_RB      = $DCD4          ; (MU_ temps of hle_mapupd) row: nametable byte offset low,
SC_RH      = $DCD5          ;   page of nametable 0,
SC_AB      = $DCD6          ;   attribute byte offset low
SC_OW      = $DCD7          ; cells of this row owned by nametable 1 exist (sc_row)
SC_P1      = $DCD8          ; off the view (no PAL_USED), else the view
SC_VR      = $DCD9          ; first view row, first view column
SC_VC      = $DCDA
SC_LT      = $DCDC          ; the last cell's tile and palette ($FF: none): a cell like it
SC_LP      = $DCDD          ;   needs nothing more
dmg_scan_all_b:
            push bc
            push de
            push hl
            ld a, 1
            ldh [sgb_dirty], a
            ldh [sgb_adirty], a
            xor a
            ldh [dmg_scan], a
            ld [PAL_USED], a
            ld hl, REF_BM
            ld b, 32
.z:         ld [hl+], a
            dec b
            jr nz, .z
            ldh a, [own1_lo]
            ld b, a
            ldh a, [own1_hi]
            or b
            ld [SC_OW], a
            ldh a, [cam_y]                  ; the view: map row (scroll_y + cam_y) mod 240 / 8,
            ld b, a                         ;   column (scroll_x + cam_x) / 8
            ldh a, [scroll_y]
            add a, b
            jr c, .w
            cp 240
            jr c, .y
.w:         sub 240
.y:         srl a
            srl a
            srl a
            ld [SC_VR], a
            ldh a, [cam_x]
            ld c, a
            ldh a, [scroll_x]
            add a, c
            srl a
            srl a
            srl a
            ld [SC_VC], a
            ld a, $FF
            ld [SC_LT], a
            ld a, 1                         ; off the view: rows outside it whole, rows in it
            ld [SC_P1], a                   ;   from the column after it, 12 columns
            ld d, 0
.r:         call sc_row
            ld a, [SC_VR]                   ; row in the view: (row - first) mod 30 < 18
            ld b, a
            ld a, d
            sub b
            jr nc, .r1
            add a, 30
.r1:        cp 18
            jr c, .rv
            ld e, 0
            ld b, 32
            jr .c
.rv:        ld a, [SC_VC]
            add a, 20
            and 31
            ld e, a
            ld b, 12
.c:         push bc
            ld b, 0                         ; off the view, a tile the tileset fixed: only its
            ld a, [SC_OW]                   ;   REF_BM bit (the parked check per tile at the
            and a                           ;   end); else sc_cell
            jr z, .o0
            ld a, d
            add a, a
            add a, a
            ld l, a
            ld a, e
            rrca
            rrca
            rrca
            and 3
            or l
            ld l, a
            ld h, high(OWN)
            ld c, [hl]
            ld a, e
            and 7
            ld l, a
            ld h, high(BITS8)
            ld a, [hl]
            and c
            jr z, .o0
            ld b, 4
.o0:        ld a, [SC_RH]
            add a, b
            ld h, a
            ld a, [SC_RB]
            or e
            ld l, a
            ld c, [hl]
            ld l, c
            ld h, high(TILE_PAL)
            bit 7, [hl]
            jr z, .sl
            ld a, c
            and 7
            ld l, a
            ld h, high(BITS8)
            ld b, [hl]
            ld a, c
            rrca
            rrca
            rrca
            and $1F
            or low(REF_BM)
            ld l, a
            ld h, high(REF_BM)
            ld a, [hl]
            or b
            ld [hl], a
            jr .cn
.sl:        call sc_cell
.cn:        pop bc
            ld a, e
            inc a
            and 31
            ld e, a
            dec b
            jr nz, .c
            inc d
            ld a, d
            cp 30
            jr nz, .r
            xor a                           ; the view
            ld [SC_P1], a
            dec a
            ld [SC_LT], a
            ld a, [SC_VR]
            ld d, a
            ld b, 18
.vr:        push bc
            call sc_row
            ld a, [SC_VC]
            ld e, a
            ld b, 20
.vc:        push bc
            call sc_cell
            pop bc
            ld a, e
            inc a
            and 31
            ld e, a
            dec b
            jr nz, .vc
            ld a, d
            inc a
            cp 30
            jr c, .vn
            xor a
.vn:        ld d, a
            pop bc
            dec b
            jr nz, .vr
            ld e, 0                         ; tiles in use and parked: marked again (they are
.pb:        ld a, e                         ;   needed now)
            add a, low(REF_BM)
            ld l, a
            ld h, high(REF_BM)
            ld b, [hl]
            ld a, e
            add a, low(DEFER_BM)
            ld l, a
            ld h, high(DEFER_BM)
            ld a, [hl]
            and b
            jr z, .pn
            ld c, a                         ; C = those bits of byte E
            ld b, 0
.pt:        srl c
            jr nc, .pz
            ld a, e
            add a, a
            add a, a
            add a, a
            or b
            call dmg_mark
.pz:        inc b
            ld a, c
            and a
            jr nz, .pt
.pn:        inc e
            ld a, e
            cp 32
            jr nz, .pb
            pop hl
            pop de
            pop bc
            ret

sc_row:     ld a, d                         ; D = map row -> SC_RB, SC_RH, SC_AB
            and 7
            swap a
            add a, a
            ld [SC_RB], a
            ld a, d
            rrca
            rrca
            rrca
            and $1F
            add a, high(NT_SH)
            ld [SC_RH], a
            ld a, d
            and $1C
            add a, a
            add a, $C0
            ld [SC_AB], a
            push hl                         ; SC_OW = the row's owner bits (0: every cell
            ld a, d                         ;   nametable 0's, no lookups)
            add a, a
            add a, a
            ld l, a
            ld h, high(OWN)
            ld a, [hl+]
            or [hl]
            inc l
            or [hl]
            inc l
            or [hl]
            ld [SC_OW], a
            pop hl
            ret

; D = map row, E = column (sc_row done for D). Keeps D, E.
sc_cell:    ld b, 0                         ; B = 4 for a cell nametable 1 owns
            ld a, [SC_OW]
            and a
            jr z, .o0
            ld a, d                         ; OWN + row * 4 + col / 8, bit col & 7
            add a, a
            add a, a
            ld l, a
            ld a, e
            rrca
            rrca
            rrca
            and 3
            or l
            ld l, a
            ld h, high(OWN)
            ld c, [hl]
            ld a, e
            and 7
            ld l, a
            ld h, high(BITS8)
            ld a, [hl]
            and c
            jr z, .o0
            ld b, 4
.o0:        ld a, [SC_RH]                   ; C = tile
            add a, b
            ld h, a
            ld a, [SC_RB]
            or e
            ld l, a
            ld c, [hl]
            ld a, [SC_P1]                   ; off the view, a palette fixed by the tileset:
            and a                           ;   REF_BM and the parked check (nothing if the
            jr z, .pal                      ;   last cell had this tile too)
            ld l, c
            ld h, high(TILE_PAL)
            bit 7, [hl]
            jr z, .pal
            ld a, [SC_LT]
            cp c
            ret z
            ld a, c
            ld [SC_LT], a
            ld a, $FF
            ld [SC_LP], a
            call .ref
            jr .pk
.pal:       ld a, b                         ; palette: attribute byte, quadrant (row & 2, col & 2)
            add a, high(NT_SH) + 3
            ld h, a
            ld a, e
            rrca
            rrca
            and 7
            ld l, a
            ld a, [SC_AB]
            add a, l
            ld l, a
            ld a, [hl]
            bit 1, d
            jr z, .t
            swap a
.t:         bit 1, e
            jr z, .q
            rrca
            rrca
.q:         and 3
            ld b, a
            ld a, [OVR_ON]                  ; (FF2: GB-only palette override)
            and a
            jr z, .nv
            ld a, b
            call ovr_de
            ld b, a
.nv:        ld a, [SC_LT]                   ; the same tile and palette as the last cell: done
            cp c
            jr nz, .nw
            ld a, [SC_LP]
            cp b
            ret z
.nw:        ld a, c
            ld [SC_LT], a
            ld a, b
            ld [SC_LP], a
            call .ref
            ld a, [SC_P1]
            and a
            jr nz, .tp
            ld l, b                         ; the view: PAL_USED |= bit B
            ld h, high(BITS8)
            ld a, [PAL_USED]
            or [hl]
            ld [PAL_USED], a
.tp:        ld l, c                         ; coded for palette B? (fixed by the tileset: kept)
            ld h, high(TILE_PAL)
            ld a, [hl]
            bit 7, a
            jr nz, .pk
            cp b
            jr z, .pk
            ld [hl], b
            ld a, c
            jp dmg_mark
.pk:        ret                             ; (parked tiles in use: once per tile at the end)
.ref:       ld a, c                         ; REF_BM |= bit C (keeps B, C, D, E)
            and 7
            ld l, a
            ld h, high(BITS8)
            ld h, [hl]
            ld a, c
            rrca
            rrca
            rrca
            and $1F
            add a, low(REF_BM)
            ld l, a
            ld a, h
            ld h, high(REF_BM)
            or [hl]
            ld [hl], a
            ret

; CGB, LCD going on after cells / attributes changed with it off (CGB_SCAN): every GB map
; cell (rows 0-29) gets its palette number in VRAM bank 1 from the nametable that owns it
; (and the GB-only override), once, instead of attr_apply / own_set for each write.
cgb_attr_all_b:
            push bc
            push de
            push hl
            xor a
            ld [CGB_SCAN], a
            inc a
            ldh [$FF4F], a                  ; VRAM bank 1
            ldh a, [own1_lo]
            ld b, a
            ldh a, [own1_hi]
            or b
            ld [SC_OW], a
            ld d, 0
.r:         call sc_row
            ld a, d                         ; HL = $9800 + row * 32
            and 7
            swap a
            add a, a
            ld l, a
            ld a, d
            srl a
            srl a
            srl a
            add a, $98
            ld h, a
            ld a, [SC_OW]                   ; no cell of the row nametable 1's, no override:
            ld b, a                         ;   each attribute byte gives 4 cells at once
            ld a, [OVR_ON]
            or b
            jr nz, .slow
            ld a, [SC_AB]
            ld c, a
            ld b, high(NT_SH) + 3
            ld e, 8
.fa:        ld a, [bc]
            inc c
            bit 1, d
            jr z, .ft
            swap a
.ft:        push af
            and 3
            ld [hl+], a
            ld [hl+], a
            pop af
            rrca
            rrca
            and 3
            ld [hl+], a
            ld [hl+], a
            dec e
            jr nz, .fa
            jr .rn
.slow:      ld e, 0
.c:         push hl
            ld b, 0                         ; B = 4 for a cell nametable 1 owns
            ld a, [SC_OW]
            and a
            jr z, .o0
            ld a, d
            add a, a
            add a, a
            ld l, a
            ld a, e
            rrca
            rrca
            rrca
            and 3
            or l
            ld l, a
            ld h, high(OWN)
            ld c, [hl]
            ld a, e
            and 7
            ld l, a
            ld h, high(BITS8)
            ld a, [hl]
            and c
            jr z, .o0
            ld b, 4
.o0:        ld a, b                         ; attribute byte, quadrant (row & 2, col & 2)
            add a, high(NT_SH) + 3
            ld h, a
            ld a, e
            rrca
            rrca
            and 7
            ld l, a
            ld a, [SC_AB]
            add a, l
            ld l, a
            ld a, [hl]
            bit 1, d
            jr z, .t
            swap a
.t:         bit 1, e
            jr z, .q
            rrca
            rrca
.q:         and 3
            ld b, a
            ld a, [OVR_ON]                  ; (FF2: GB-only palette override)
            and a
            jr z, .nv
            ld a, b
            call ovr_de
            ld b, a
.nv:        pop hl
            ld [hl], b
            inc hl
            inc e
            bit 5, e
            jr z, .c
.rn:        inc d
            ld a, d
            cp 30
            jr nz, .r
            xor a
            ldh [$FF4F], a
            pop hl
            pop de
            pop bc
            ret

; b11:A43A "draw battle character sprite" (every battle frame, per party member X): 6 OAM
; entries (24 bytes at ($2C + 2X)) from the member's pose data at $7900 + 24 * pose (cart
; RAM). FF2's steps ($00-$0F as the NES leaves them; the two multiplies as products, see .e8), the pose bytes and OAM bytes read / written through GB pointers
; (other addresses byte by byte through nes_rd / nes_wr). Exit as the NES: early ($7BA2,X
; bit 7 set) A, N = 1, Z = 0, carry and V kept; else Y = $18, Z = 1, C = 1, N = 0, V = bit 6 of
; $06, fill (no pose) A = $F0, X = $04, else A = the last byte, X = 6.
BS_F       = $DCDB          ; (MU_GL) 1: pointers usable directly (BS_S source, HL OAM)
hle_bspr_b:
            push bc
            ld a, e
            ld [NES_RAM + $04], a           ; STX $04
            ld hl, $BBA2                    ; LDA $7BA2,X / BPL -> RTS
            add a, l
            ld l, a
            jr nc, .h0
            inc h
.h0:        ld a, [hl]
            bit 7, a
            jr z, .go
            pop bc                          ; (bit 7 set: RTS with N = 1)
            ldh [nzv], a
            inc a
            dec a
            ret
.go:        ld [NES_RAM + $05], a
            ld hl, $BBC2                    ; $06 = $7BC2,X, $07 = $06 & $7F
            ld a, e
            add a, l
            ld l, a
            jr nc, .h1
            inc h
.h1:        ld a, [hl]
            ld [NES_RAM + $06], a
            and $7F
            ld [NES_RAM + $07], a
            cp 3                            ; $08 = low($04 * (8 / 6 by CMP #3)): FF2's
            ld a, [NES_RAM + $04]           ;   multiply leaves carry 0 ($02 starts at 0, none
            jr nc, .e6                      ;   of its bits shift out in 8 steps), and $00-$03
            add a, a                        ;   are overwritten below on every path that
            add a, a                        ;   multiplies, so only the products count
            add a, a                        ; ($07 < 3: x 8)
            jr .e8
.e6:        add a, a                        ; (x 6 = x 2 + x 4)
            ld b, a
            add a, a
            add a, b
.e8:        ld [NES_RAM + $08], a
            ld a, [NES_RAM + $07]           ; LDA #0 / LDX $07 / BEQ
            ld b, a
            inc a
            dec a
            ld a, 0
            jr z, .m2
            ld a, b                         ; LDA #6 / CPX #8 / BEQ
            cp 8
            jr nz, .n8
            scf
            ld a, 6
            jr .m2
.n8:        ccf
            push af
            dec b                           ; DEX / LDA $A50B,X (bank 11 data image)
            ld hl, $650B
            ld a, b
            add a, l
            ld l, a
            jr nc, .h2
            inc h
.h2:        ldh a, [data_bank8]
            call rd8_bank
            pop af
            ld a, [VT_BUF]
            ld b, a
            ld a, [NES_RAM + $05]           ; LDX $05 / BEQ / CLC / ADC #3
            inc a
            dec a
            ld a, b
            jr z, .m2
            add a, 3
.m2:        ld l, a                         ; $00 / $01 = $7900 + A * 24 (LDX #$18 / multiply /
            ld h, 0                         ;   ADC with the multiply's carry 0)
            ld d, h
            ld e, l
            add hl, hl
            add hl, de
            add hl, hl
            add hl, hl
            add hl, hl
            ld a, l
            ld [NES_RAM + $00], a
            ld a, h
            add a, $79
            ld [NES_RAM + $01], a
            ld a, [NES_RAM + $04]           ; $02 / $03 = ($2C + 2X)
            add a, a
            add a, $2C
            ld l, a
            ld h, high(NES_RAM)
            ld a, [hl+]
            ld [NES_RAM + $02], a
            ld a, [hl]
            ld [NES_RAM + $03], a
            xor a                           ; direct pointers: source in cart RAM ($60-$7E
            ld [BS_F], a                    ;   page), OAM bytes in RAM below $0700
            ld a, [NES_RAM + $01]
            cp $60
            jr c, .sl
            cp $7F
            jr nc, .sl
            ld a, [NES_RAM + $03]
            cp $07
            jr nc, .sl
            ld a, 1
            ld [BS_F], a
.sl:        ld a, [NES_RAM + $08]           ; $0A + k = pose byte 1 + 4k + $08
            ld b, a
            ld hl, NES_RAM + $0A
            ld a, [BS_F]
            and a
            jr z, .s1
            ld a, [NES_RAM + $00]           ; (direct: DE = source + 1)
            add a, 1
            ld e, a
            ld a, [NES_RAM + $01]
            adc a, $40
            ld d, a
            ld c, 6
.f1:        ld a, [de]
            add a, b
            ld [hl+], a
            ld a, e
            add a, 4
            ld e, a
            jr nc, .f1n
            inc d
.f1n:       dec c
            jr nz, .f1
            jr .ns0
.s1:        ld c, 1
.l1:        ld a, c
            call bs_get
            add a, b
            ld [hl+], a
            ld a, c
            add a, 4
            ld c, a
            cp 25
            jr nz, .l1
.ns0:       ld a, [NES_RAM + $06]           ; BIT $06 / BPL: LDA $05 / BNE: swap the pairs
            bit 7, a
            jr z, .ns
            ld a, [NES_RAM + $05]
            and a
            jr nz, .ns
            ld hl, NES_RAM + $0A
            ld c, 3
.sw:        ld a, [hl+]
            ld b, [hl]
            ld [hl-], a
            ld [hl], b
            inc l
            inc l
            dec c
            jr nz, .sw
.ns:        ld a, [NES_RAM + $04]           ; $08 / $09 = $7BCA,X / $7BCE,X; $05 = $7BB6,X
            ld c, a                         ;   (| $40 when bit 7 of $06)
            ld b, 0
            ld hl, $BBCA
            add hl, bc
            ld a, [hl]
            ld [NES_RAM + $08], a
            ld hl, $BBCE
            add hl, bc
            ld a, [hl]
            ld [NES_RAM + $09], a
            ld hl, $BBB6
            add hl, bc
            ld a, [NES_RAM + $06]
            ld b, a
            ld a, [hl]
            bit 7, b
            jr z, .o4
            or $40
.o4:        ld [NES_RAM + $05], a
            ld a, [BS_F]                    ; direct: DE = source, HL = OAM bytes
            and a
            jr z, .s2
            ld a, [NES_RAM + $00]
            ld e, a
            ld a, [NES_RAM + $01]
            add a, $40
            ld d, a
            ld a, [NES_RAM + $02]
            ld l, a
            ld a, [NES_RAM + $03]
            add a, high(NES_RAM)
            ld h, a
            ld a, [NES_RAM + $07]
            and a
            jr nz, .fm
            ld a, $F0
            ld c, 24
.ff:        ld [hl+], a
            dec c
            jr nz, .ff
            ld a, [NES_RAM + $04]
            ld e, a
            ld h, $F0
            jr .x
.fm:        ld a, [NES_RAM + $09]
            ld b, a
            ld a, [NES_RAM + $08]
            ld c, a
            ld a, [de]
            inc de
            add a, b
            ld [hl+], a
            ld a, [NES_RAM + $0A]
            ld [hl+], a
            inc de
            ld a, [NES_RAM + $05]
            ld [hl+], a
            inc de
            ld a, [de]
            inc de
            add a, c
            ld [hl+], a
            ld a, [de]
            inc de
            add a, b
            ld [hl+], a
            ld a, [NES_RAM + $0B]
            ld [hl+], a
            inc de
            ld a, [NES_RAM + $05]
            ld [hl+], a
            inc de
            ld a, [de]
            inc de
            add a, c
            ld [hl+], a
            ld a, [de]
            inc de
            add a, b
            ld [hl+], a
            ld a, [NES_RAM + $0C]
            ld [hl+], a
            inc de
            ld a, [NES_RAM + $05]
            ld [hl+], a
            inc de
            ld a, [de]
            inc de
            add a, c
            ld [hl+], a
            ld a, [de]
            inc de
            add a, b
            ld [hl+], a
            ld a, [NES_RAM + $0D]
            ld [hl+], a
            inc de
            ld a, [NES_RAM + $05]
            ld [hl+], a
            inc de
            ld a, [de]
            inc de
            add a, c
            ld [hl+], a
            ld a, [de]
            inc de
            add a, b
            ld [hl+], a
            ld a, [NES_RAM + $0E]
            ld [hl+], a
            inc de
            ld a, [NES_RAM + $05]
            ld [hl+], a
            inc de
            ld a, [de]
            inc de
            add a, c
            ld [hl+], a
            ld a, [de]
            inc de
            add a, b
            ld [hl+], a
            ld a, [NES_RAM + $0F]
            ld [hl+], a
            inc de
            ld a, [NES_RAM + $05]
            ld [hl+], a
            inc de
            ld a, [de]
            inc de
            add a, c
            ld [hl+], a
            ld h, a                         ; (the last byte)
            ld e, 6
            jr .x
.s2:        ld a, [NES_RAM + $07]
            and a
            jr nz, .main
            ld c, 0                         ; no pose: 24 x $F0
.fl:        ld a, $F0
            call bs_put
            inc c
            ld a, c
            cp $18
            jr nz, .fl
            ld a, [NES_RAM + $04]
            ld e, a                         ; X = $04
            ld h, $F0
            jr .x
.main:      ld c, 0                         ; per entry: pose + $09, $0A + k, $05, pose + $08
            ld e, 0
.l2:        ld a, c
            call bs_get
            ld b, a
            ld a, [NES_RAM + $09]
            add a, b
            call bs_put
            inc c
            ld a, e
            add a, $0A
            ld l, a
            ld h, high(NES_RAM)
            ld a, [hl]
            inc e
            call bs_put
            inc c
            ld a, [NES_RAM + $05]
            call bs_put
            inc c
            ld a, c
            call bs_get
            ld b, a
            ld a, [NES_RAM + $08]
            add a, b
            call bs_put
            inc c
            ld h, a                         ; (the last byte)
            ld a, c
            cp $18
            jr nz, .l2
.x:         pop bc                          ; Y = $18 (B = 0)
            ld bc, $18
            ld d, b
            ld a, [NES_RAM + $06]
            and $40
            ldh [vfl], a
            xor a
            ldh [nzv], a
            ld a, h
            scf
            ld l, 0
            inc l
            dec l                           ; Z = 1, C = 1
            ret

; A = offset -> A = byte at ($00) + offset (BS_F: GB pointer into cart RAM). Keeps BC, DE, HL.
bs_get:     push hl
            ld l, a
            ld a, [BS_F]
            and a
            jr z, .g
            ld a, [NES_RAM + $00]
            add a, l
            ld l, a
            ld a, [NES_RAM + $01]
            adc a, $40
            ld h, a
            ld a, [hl]
            pop hl
            ret
.g:         push bc
            push de
            ld a, [NES_RAM + $00]
            add a, l
            ld l, a
            ld a, [NES_RAM + $01]
            adc a, 0
            ld h, a
            call nes_rd
            ld a, l
            pop de
            pop bc
            pop hl
            ret

; A = value -> ($02) + C (BS_F: GB pointer into RAM). Keeps A, BC, DE, HL.
bs_put:     push hl
            push af
            ld a, [BS_F]
            and a
            jr z, .g
            ld a, [NES_RAM + $02]
            add a, c
            ld l, a
            ld a, [NES_RAM + $03]
            adc a, high(NES_RAM)
            ld h, a
            pop af
            ld [hl], a
            pop hl
            ret
.g:         pop af
            push af
            push bc
            push de
            ldh [wtmp], a
            ld a, [NES_RAM + $02]
            add a, c
            ld l, a
            ld a, [NES_RAM + $03]
            adc a, 0
            ld h, a
            call nes_wr
            pop de
            pop bc
            pop af
            pop hl
            ret

; b11:9D82-9D8C (battle: the 32 palette bytes from $79A8 every other frame): LDA $79A8,X /
; STA $2007 / INX / CPX #$20 / BNE. An unchanged palette entry only moves the PPU address;
; others (or a non-palette address) through rt_ppu_w7. Exit: A = the last byte, X = $20,
; N = 0, Z = 1, C = 1; Y kept.
hle_palup_b:
            push bc
.lp:        ld hl, $B9A8
            ld a, e
            add a, l
            ld l, a
            jr nc, .h
            inc h
.h:         ld a, [hl]
            ldh [tmp_lo], a
            ld d, a
            ldh a, [ppu_vh]
            cp $3F
            jr nz, .gen
            ldh a, [ppu_vl]                 ; palette index ($10 / $14 / $18 / $1C = $00 / ..)
            and $1F
            ld l, a
            and $13
            cp $10
            ld a, l
            jr nz, .pn
            and $0F
.pn:        ld l, a
            ld h, high(PAL_SH)
            ld a, d
            and $3F
            cp [hl]
            jr nz, .gen
            call ppu_inc
            jr .nx
.gen:       ld a, d
            call rt_ppu_w7
.nx:        inc e
            ld a, e
            cp $20
            jr nz, .lp
            pop bc
            ld d, 0
            xor a
            ldh [nzv], a
            ldh a, [tmp_lo]
            scf
            ld l, 0
            inc l
            dec l                           ; Z = 1, C = 1
            ret

; b11:9D24-9D28 (battle, every frame): STA ($24),Y / DEY / BPL - A to ($24) + Y down to + 0.
; Exit: Y = $FF, N = 1, Z = 0; A, X, carry kept.
hle_bfill_b:
            push af
            ld d, a
            bit 7, c                        ; (Y < $80, RAM below $0700: directly)
            jr nz, .gen
            ld a, [NES_RAM + $25]
            cp $07
            jr nc, .gen
            add a, high(NES_RAM)
            ld h, a
            ld a, [NES_RAM + $24]
            add a, c
            ld l, a
            jr nc, .h
            inc h
.h:         ld a, d
            inc c
.f:         ld [hl-], a
            dec c
            jr nz, .f
            jr .x
.gen:       ld a, d                         ; byte by byte
            ld l, $24
            call rt_izy_wr
            dec c
            bit 7, c
            jr z, .gen
.x:         ld c, $FF
            ld d, 0
            ld a, $80
            ldh [nzv], a
            pop af
            push af
            ld l, 1
            inc l                           ; Z = 0
            pop hl                          ; (A back, Z / carry as set: pop af would undo Z)
            ld a, h
            ret

; b11:9D4A-9D55 (battle, every frame): LDA ($24),Y / STA ($26),Y / STA ($28),Y / STA ($2A),Y /
; INY / CPY #$10 / BNE. Exit: A = the last byte, Y = $10, N = 0, Z = 1, C = 1; X kept.
hle_bcopy_b:
            ld a, [NES_RAM + $25]           ; all four pointers in RAM below $0700: directly
            ld b, a
            ld a, [NES_RAM + $27]
            or b
            ld b, a
            ld a, [NES_RAM + $29]
            or b
            ld b, a
            ld a, [NES_RAM + $2B]
            or b
            cp $07
            jr nc, .gen
.lp:        ld a, [NES_RAM + $24]           ; (each byte: 4 pointers + Y; < 16 bytes, so a
            add a, c                        ;   page crossing is carried into the high byte)
            ld l, a
            ld a, [NES_RAM + $25]
            adc a, high(NES_RAM)
            ld h, a
            ld d, [hl]
            ld a, [NES_RAM + $26]
            add a, c
            ld l, a
            ld a, [NES_RAM + $27]
            adc a, high(NES_RAM)
            ld h, a
            ld [hl], d
            ld a, [NES_RAM + $28]
            add a, c
            ld l, a
            ld a, [NES_RAM + $29]
            adc a, high(NES_RAM)
            ld h, a
            ld [hl], d
            ld a, [NES_RAM + $2A]
            add a, c
            ld l, a
            ld a, [NES_RAM + $2B]
            adc a, high(NES_RAM)
            ld h, a
            ld [hl], d
            inc c
            ld a, c
            cp $10
            jr nz, .lp
            jr .x
.gen:       ld l, $24                       ; byte by byte
            call rt_izy_rd
            ld d, l
            ld a, d
            ld l, $26
            call rt_izy_wr
            ld l, $28
            call rt_izy_wr
            ld l, $2A
            call rt_izy_wr
            inc c
            ld a, c
            cp $10
            jr nz, .gen
.x:         ld b, 0
            xor a
            ldh [nzv], a
            ld a, d
            ld d, b
            scf
            ld l, 0
            inc l
            dec l                           ; Z = 1, C = 1
            ret

; b00:9D97-9DCF (map load): metatiles $7400[$88..255] -> 2 x 2 tiles at ($80) (+0, +1, +$20,
; +$21 from $7800 / $7880 / $7900 / $7980 + X), ($80) += 2, a row's end + $20. Cart RAM
; ($80 page $60-$7B) through GB pointers, else byte by byte. Exit as the NES: $88 = 0, Y = $21,
; X = the last metatile, A and carry from the last pointer step, N = 0, Z = 1.
hle_mexp_b:
            ld a, [NES_RAM + $81]
            cp $60
            jr c, .gen
            cp $7C
            jr nc, .gen
.lp:        ld a, [NES_RAM + $88]           ; X = $7400[$88] (cart RAM $B400)
            ld l, a
            ld h, $B4
            ld e, [hl]
            ld a, [NES_RAM + $80]           ; HL = ($80) in cart RAM
            ld l, a
            ld a, [NES_RAM + $81]
            add a, $40
            ld h, a
            ld d, $B8                       ; $7800 + X -> +0
            ld a, [de]
            ld [hl+], a
            ld d, $B8                       ; ($7880 + X: $B880; X < $80 not assumed)
            ld a, e
            add a, $80
            ld c, a
            ld a, d
            adc a, 0
            ld b, a
            ld a, [bc]
            ld [hl], a
            ld bc, $1F                      ; +$20
            add hl, bc
            ld d, $B9                       ; $7900 + X
            ld a, [de]
            ld [hl+], a
            ld a, e                         ; $7980 + X
            add a, $80
            ld c, a
            ld a, $B9
            adc a, 0
            ld b, a
            ld a, [bc]
            ld [hl], a
            call .step
            ld hl, NES_RAM + $88
            inc [hl]
            jr nz, .lp
            jr .x
.gen:       ld a, [NES_RAM + $88]           ; (as the NES, through nes_rd / nes_wr)
            ld l, a
            ld h, $74
            call nes_rd
            ld e, l
            ld d, $78
            ld c, 0
            call .g1
            ld d, $78
            ld a, e
            add a, $80
            ld e, a                         ; (E = X + $80: X >= $80 reads $7900+; as $7880,X)
            ld a, d
            adc a, 0
            ld d, a
            ld c, 1
            call .g1
            ld a, e
            sub $80
            ld e, a
            ld d, $79
            ld c, $20
            call .g1
            ld a, e
            add a, $80
            ld e, a
            ld a, $79
            adc a, 0
            ld d, a
            ld c, $21
            call .g1
            ld a, e
            sub $80
            ld e, a
            call .step
            ld hl, NES_RAM + $88
            inc [hl]
            jr nz, .gen
.x:         ld a, [MU_T]                    ; (A as left by .step)
            ld b, a
            ld c, $21                       ; Y = $21
            ld d, 0
            xor a
            ldh [nzv], a
            ld a, [MU_N]                    ; carry of the last step
            rrca
            ld a, b
            ld l, 0
            inc l
            dec l                           ; Z = 1, carry kept
            ld b, 0
            ret
.g1:        ld h, d                         ; byte at D:E -> ($80) + C
            ld l, e
            push de
            call nes_rd
            ld a, l
            ldh [wtmp], a
            ld a, [NES_RAM + $80]
            add a, c
            ld l, a
            ld a, [NES_RAM + $81]
            adc a, 0
            ld h, a
            call nes_wr
            pop de
            ret
.step:      ld a, [NES_RAM + $80]           ; $80 += 2; at a row's end + $20 (carry: $81 + 1)
            add a, 2
            ld [NES_RAM + $80], a
            ld b, 0
            jr nc, .s0
            inc b
.s0:        and $1F
            jr nz, .s1
            ld a, [NES_RAM + $80]
            add a, $20
            ld [NES_RAM + $80], a
            ld b, 0
            jr nc, .s1
            inc b
            ld hl, NES_RAM + $81
            inc [hl]
.s1:        ld [MU_T], a                    ; (A, carry for the exit)
            ld a, b
            ld [MU_N], a
            ret

; b00:9DDB-9DDE (map load): LDA ($80),Y / CMP #$39 over $7000-$73FF: the bytes below $39 are
; skipped here (INY, INC $81 at a page end); returns at the next byte >= $39 (carry 1) or at
; the last byte of $73xx (carry 0) with A = the byte and the flags of the CMP; the BCC / JSR /
; INY / loop end that follow run as the NES. ($81 outside $70-$73: one byte, as the NES.)
hle_mscan_b:
            ld a, [NES_RAM + $81]
            cp $70
            jr c, .one
            cp $74
            jr nc, .one
.lp:        ld a, [NES_RAM + $80]           ; HL = ($80) + Y (cart RAM)
            add a, c
            ld l, a
            ld a, [NES_RAM + $81]
            adc a, $40
            ld h, a
            ld a, [hl]
            cp $39
            jr nc, .ret
            ld b, a
            inc c                           ; the last byte ($73FF): return it
            jr nz, .ok
            dec c
            ld a, [NES_RAM + $81]
            cp $73
            ld a, b
            jr z, .ret
            inc c
            ld hl, NES_RAM + $81
            inc [hl]
.ok:        jr .lp
.one:       ld l, $80
            call rt_izy_rd
            ld a, l
.ret:       ld b, 0                         ; flags of CMP #$39
            ld l, a
            sub $39
            ldh [nzv], a
            ld a, l
            cp $39                          ; (Z, carry inverted to the 6502 sense)
            ccf
            ret

section bank HLE_BANK, $7F00
BITS8:      db 1, 2, 4, 8, 16, 32, 64, 128      ; (page start: low byte = bit number)

; fix:F321 "clear nametable 0" (menus, screen changes): $2000-$23BF = 0, $23C0-$23FF = $FF.
; With the LCD off and +1 increment: the shadow tiles, GB map rows 0-29 and the owners at
; once (every cell nametable 0's; DMG: the scan when the LCD goes on; CGB: if nametable 1
; owned cells, the cells' palettes when the LCD goes on); the 64 attribute bytes
; through rt_ppu_w7. Else byte by byte. Exit as the NES: A = $FF, X = Y = 0, N = 0, Z = 1,
; C = 1 (CPY #$C0).
hle_ntclr0_b:
            call rt_ppu_r2                  ; LDA $2002 / $2006 = $20, $00
            ld a, $20
            call rt_ppu_w6
            xor a
            call rt_ppu_w6
            ldh a, [lcd_on]
            and a
            jr nz, .gen
            ldh a, [ppu_ctrl]
            and 4
            jr nz, .gen
            ld hl, NT_SH                    ; shadow tiles
            call .z960
            ld hl, $9800                    ; GB map rows 0-29
            call .z960
            ldh a, [own1_lo]                ; owners: B = nametable 1 owned cells
            ld b, a
            ldh a, [own1_hi]
            or b
            ld b, a
            xor a
            ldh [own1_lo], a
            ldh [own1_hi], a
            ld hl, OWN
            ld c, 120
.ow:        ld [hl+], a
            dec c
            jr nz, .ow
            ldh a, [is_cgb]
            and a
            jr nz, .cgb
            inc a
            ldh [dmg_scan], a
            jr .at
.cgb:       ld a, b                         ; (cells nametable 1 owned: their palettes when
            and a                           ;   the LCD goes on)
            jr z, .at
            ld a, 1
            ld [CGB_SCAN], a
.at:        ld a, $23                       ; the attribute bytes
            ldh [ppu_vh], a
            ld a, $C0
            ldh [ppu_vl], a
            ld b, 64
.al:        ld a, $FF
            call rt_ppu_w7
            dec b
            jr nz, .al
            jr .x
.gen:       ld de, 960
.gl:        xor a
            call rt_ppu_w7
            dec de
            ld a, d
            or e
            jr nz, .gl
            ld b, 64
.gl2:       ld a, $FF
            call rt_ppu_w7
            dec b
            jr nz, .gl2
.x:         ld bc, 0                        ; Y = 0
            ld de, 0                        ; X = 0
            xor a
            ldh [nzv], a
            ld a, $FF
            scf
            ld l, 0
            inc l
            dec l                           ; Z = 1, C = 1
            ret
.z960:      xor a                           ; HL: 960 bytes of 0
            ld c, 240
.zl:        ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            dec c
            jr nz, .zl
            ret
