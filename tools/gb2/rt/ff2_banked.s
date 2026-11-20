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

; tile A to NES address (D, E) with palette MU_P (DMG / SGB fast; CGB through rt_ppu_w7).
; Keeps B, C, D, E.
mu_write:   push bc
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
.dmg:       ld a, d                         ; B = offset high (0-3), C = 4 for nametable 1,
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
            call own_set
            pop af
            jr z, .vram
            ldh a, [lcd_on]                 ; (LCD off: the scan when it goes on)
            and a
            jr nz, .sh
            inc a
            ldh [dmg_scan], a
            jr .vram
.sh:        ld l, d                         ; shading: fixed by the tileset - nothing; another
            ld h, high(TILE_PAL)            ;   palette - re-coded for this one; the same -
            ld a, [hl]                      ;   a parked tile is marked again
            bit 7, a
            jr nz, .vram
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
