; DMG / SGB shading of BG tiles (not used on a Game Boy Color).
; The DMG has one BG palette for the whole screen, the NES four. Each BG tile is re-coded
; for the NES palette it is drawn with: pixel value 0 = the backdrop (or a colour equal to
; it), 1..3 = the palette's other colours by brightness (darkest 1). One BG palette (BGP)
; then gives each value a shade from the current NES colours, so palette fades darken /
; brighten the picture without re-coding tiles.
;   BG_SHADOW  cart RAM bank 1 $B000: the NES BG tiles as written (GB byte order)
;   TILE_PAL   palette (0-3) each BG tile is coded for (from nametable/attribute writes)
;   PAL_MAP    value of each NES colour index, per palette; recomputed once the palettes
;              have been stable for 8 frames (FF1 fades step every few frames)
;   RQ / DIRTY tiles waiting to be re-coded: all at once while the LCD is off, a few per
;              frame while it is on (through the VRAM queue)

; (constants BG_SHADOW .. RETILE_PER_FRAME: top of runtime.s)

; A = tile: mark it for re-coding. Keeps all registers.
dmg_mark:   push af
            push bc
            push hl
            ld c, a
            call bm_addr
            ld a, [hl]
            or b
            ld [hl], a
            ld a, l                         ; (no longer parked)
            add a, low(DEFER_BM) - low(DIRTY_BM)
            ld l, a
            ld a, b
            cpl
            and [hl]
            ld [hl], a
            ld a, 1
            ldh [rq_any], a
            pop hl
            pop bc
            pop af
            ret

; C = tile -> HL = its DIRTY_BM byte, B = its bit
bm_addr:    ld a, c
            and 7
            ld hl, BIT_MASK
            add a, l
            ld l, a
            jr nc, .nc
            inc h
.nc:        ld b, [hl]
            ld a, c
            srl a
            srl a
            srl a
            ld l, a
            ld h, high(DIRTY_BM)
            ret

; re-code up to B marked tiles (B = 0: all). The dirty bitmap is scanned from rq_pos
; (byte index) on, so every marked tile gets its turn.
dmg_retile_some:
            ldh a, [rq_any]
            and a
            ret z
            push bc
            push de
            push hl
            ld d, 33                        ; bytes left to look at (one more: the start byte again)
.byte:      ldh a, [rq_pos]
            ld l, a
            ld h, high(DIRTY_BM)
            ld a, [hl]
            and a
            jr nz, .bit
            ld a, l
            inc a
            and 31
            ldh [rq_pos], a
            dec d
            jr nz, .byte
            xor a                           ; nothing marked
            ldh [rq_any], a
            jr .x
.bit:       ld c, 0                         ; lowest set bit -> C, mask -> E
            ld e, 1
.f:         rrca
            jr c, .fd
            inc c
            sla e
            jr .f
.fd:        ld a, e
            cpl
            and [hl]
            ld [hl], a
            ld a, l
            add a, a
            add a, a
            add a, a
            or c
            call retile
            ld d, 33
            dec b
            jr nz, .byte
.x:         pop hl
            pop de
            pop bc
            ret

; A = tile: write its VRAM pixels from the shadow through PAL_MAP[TILE_PAL[tile]]
retile:     push bc
            push de
            push hl
            ldh [sh_tile], a
            ld e, a
            ld l, a
            ld h, high(TILE_PAL)
            ld a, [hl]
            add a, a
            add a, a
            add a, low(PAL_MAP)
            ld l, a
            ld h, high(PAL_MAP)
            ld bc, 0                        ; B = values with bit 0 set, C = with bit 1
            ld d, 1
.m:         ld a, [hl+]
            bit 0, a
            jr z, .n0
            push af
            ld a, b
            or d
            ld b, a
            pop af
.n0:        bit 1, a
            jr z, .n1
            ld a, c
            or d
            ld c, a
.n1:        sla d
            ld a, d
            cp 16
            jr nz, .m
            ld a, b
            ldh [sh_s0], a
            ld a, c
            ldh [sh_s1], a
            ld a, e                         ; shadow -> RT_BUF (RAM bank 1)
            swap a
            ld d, a
            and $F0
            ld l, a
            ld a, d
            and $0F
            add a, high(BG_SHADOW)
            ld h, a
            ld a, 1
            ld [$4000], a
            ld de, RT_BUF
            ld b, 16
.cp:        ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .cp
            xor a
            ld [$4000], a
            ld a, l                         ; VRAM address: tiles 0-127 at $9000, 128-255 at $8800
            sub 16
            ld l, a
            ld a, h
            sbc a, 0
            sub high(BG_SHADOW)             ; = tile >> 4
            cp 8
            jr nc, .hi
            add a, $90
            jr .va
.hi:        add a, $80
.va:        ld h, a
            ld de, RT_BUF
            ld b, 8
.row:       ld a, [de]                      ; p0, p1 -> masks of the pixels of index 0-3
            inc de
            ldh [sh_p0], a
            ld a, [de]
            inc de
            ldh [sh_p1], a
            call row_masks
            push bc                         ; indices used -> sh_u1..3
            ldh a, [sh_m1]
            ld c, a
            ldh a, [sh_u1]
            or c
            ldh [sh_u1], a
            ldh a, [sh_m2]
            ld c, a
            ldh a, [sh_u2]
            or c
            ldh [sh_u2], a
            ldh a, [sh_m3]
            ld c, a
            ldh a, [sh_u3]
            or c
            ldh [sh_u3], a
            pop bc
            ldh a, [sh_s0]
            call mask_comb
            call vram_put
            inc hl
            ldh a, [sh_s1]
            call mask_comb
            call vram_put
            inc hl
            dec b
            jr nz, .row
            ld c, 0                         ; colour indices the tile uses -> TILE_USE nibble
            ldh a, [sh_u1]
            and a
            jr z, .u2
            set 1, c
.u2:        ldh a, [sh_u2]
            and a
            jr z, .u3
            set 2, c
.u3:        ldh a, [sh_u3]
            and a
            jr z, .u4
            set 3, c
.u4:        xor a
            ldh [sh_u1], a
            ldh [sh_u2], a
            ldh [sh_u3], a
            ldh a, [sh_tile]
            ld b, a
            srl a
            add a, low(TILE_USE)
            ld l, a
            ld h, high(TILE_USE)
            bit 0, b
            jr z, .ulo
            ld a, c
            swap a
            ld c, a
            ld a, [hl]
            and $0F
            jr .ust
.ulo:       ld a, [hl]
            and $F0
.ust:       or c
            ld [hl], a
            pop hl
            pop de
            pop bc
            ret
; sh_p0 / sh_p1 (a tile row's planes) -> sh_m0..3 = masks of the pixels of index 0..3
row_masks:  push bc
            ldh a, [sh_p0]
            ld b, a
            ldh a, [sh_p1]
            ld c, a
            and b
            ldh [sh_m3], a
            ld a, c
            cpl
            and b
            ldh [sh_m1], a
            ld a, b
            cpl
            and c
            ldh [sh_m2], a
            ld a, b
            or c
            cpl
            ldh [sh_m0], a
            pop bc
            ret

; A = set of indices (bit i) -> A = OR of the pixel masks sh_m<i>
mask_comb:
            push bc
            ld b, a
            ld c, 0
            bit 0, b
            jr z, .c1
            ldh a, [sh_m0]
            ld c, a
.c1:        bit 1, b
            jr z, .c2
            ldh a, [sh_m1]
            or c
            ld c, a
.c2:        bit 2, b
            jr z, .c3
            ldh a, [sh_m2]
            or c
            ld c, a
.c3:        bit 3, b
            jr z, .c4
            ldh a, [sh_m3]
            or c
            ld c, a
.c4:        ld a, c
            pop bc
            ret

; HL = VRAM address, A = value: written now (LCD off) or through the VRAM queue
vram_put:   push bc
            push de
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
            halt
            jr .f
.r:         push hl
            ld a, l
            ld c, h
            ld h, high(QH)
            ld l, e
            ld [hl], c
            inc h
            ld [hl], a
            inc h
            ld [hl], d
            pop hl
            ld a, b
            ldh [q_tail], a
.x:         pop de
            pop bc
            ret

; NES nametable cell written: B:L = offset (0-$3BF; B + 4 for nametable 1), A = tile.
; Its palette from the attribute shadow; a tile coded for another palette is re-coded.
dmg_cell:   push bc
            push de
            push hl
            ld d, a                         ; tile
            ld a, b
            and 4
            ldh [sh_nt], a
            ld a, b
            and 3
            ld b, a
            ld a, l                         ; row = offset >> 5, col = offset & 31
            and 31
            ld e, a                         ; col
            ld a, l
            swap a
            rrca
            and $07
            ld c, a
            ld a, b
            add a, a
            add a, a
            add a, a
            or c                            ; row
            call cell_pal                   ; A = palette of (row A, col E)
            ld e, a
            ld l, d
            ld h, high(TILE_PAL)
            ld a, [hl]
            cp e
            jr z, .pk
            ld [hl], e
            ld a, d
            call dmg_mark
            jr .x
.pk:        ld c, d                         ; same palette: parked tile? mark it
            call bm_addr
            ld a, l
            add a, low(DEFER_BM) - low(DIRTY_BM)
            ld l, a
            ld a, [hl]
            and b
            jr z, .x
            ld a, b
            cpl
            and [hl]
            ld [hl], a
            ld a, d
            call dmg_mark
.x:         pop hl
            pop de
            pop bc
            ret

; A = row, E = col -> A = palette (0-3) from the attribute shadow of nametable sh_nt
cell_pal:   push bc
            push hl
            ld b, a
            and $1C                         ; (row >> 2) * 8
            add a, a
            ld c, a
            ld a, e
            srl a
            srl a
            add a, c
            add a, $C0
            ld l, a
            ldh a, [sh_nt]
            add a, high(NT_SH) + 3
            ld h, a
            ld a, [hl]                      ; attribute byte: bottom half (row & 2) >> 4,
            bit 1, b                        ;   right half (col & 2) >> 2
            jr z, .t
            swap a
.t:         bit 1, e
            jr z, .l
            rrca
            rrca
.l:         and 3
            pop hl
            pop bc
            ret

; NES attribute byte A (0-63, + $40 for nametable 1) written: its 16 cells' tiles are checked
dmg_attr:   push bc
            push de
            push hl
            ld c, a
            and $40
            rrca
            rrca
            rrca
            rrca
            ldh [sh_nt], a
            ld a, c
            and $3F
            ld c, a
            and $38                         ; row0 = (i >> 3) * 4, col0 = (i & 7) * 4
            rrca
            ld d, a                         ; row0
            ld a, c
            and 7
            add a, a
            add a, a
            ld e, a                         ; col0
            ld c, 4
.r:         push bc
            ld b, 4
            push de
.c:         push bc
            ld a, d                         ; rows 30-31: attribute bytes, not cells
            cp 30
            jr nc, .s
            call quad_chk                   ; quadrant whose palette did not change: skip
            jr z, .s
            call own_chk                    ; a cell another nametable drew: not this byte's
            and a
            jr nz, .s
            ld a, d
            srl a                           ; tile at (row D, col E): NT_SH + row*32 + col
            srl a
            srl a
            add a, high(NT_SH)
            ld h, a
            ldh a, [sh_nt]
            add a, h
            ld h, a
            ld a, d
            and 7
            swap a
            add a, a
            or e
            ld l, a
            ld a, [hl]                      ; tile
            push af
            ld a, d
            call cell_pal
            ld b, a
            pop af
            ld l, a
            ld h, high(TILE_PAL)
            ld c, a
            ld a, [hl]
            cp b
            jr z, .s
            ld [hl], b
            ld a, c
            call dmg_mark
.s:         inc e
            pop bc
            dec b
            jr nz, .c
            pop de
            inc d
            pop bc
            dec c
            jr nz, .r
            pop hl
            pop de
            pop bc
            ret

; brightness of NES colour A (0-63): 0 black .. 8 white (the 2C02 rows, the grey column
; a bit brighter). Keeps all registers but A.
lum:        push hl
            and $3F
            ld hl, LUM_TAB
            add a, l
            ld l, a
            jr nc, .nc
            inc h
.nc:        ld a, [hl]
            pop hl
            ret
LUM_TAB:
            db 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0
            db 4, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 0, 0, 0
            db 6, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 0, 0, 0
            db 8, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 0, 0, 0

; recompute PAL_MAP from the NES BG palettes. A colour's value depends only on its
; brightness level, the same in every palette (a tile drawn with several palettes, such
; as the font, is then coded alike): 0 = the backdrop's level; the other levels present
; in the four BG palettes, darkest first, get 1 / 2 / 3, more than three levels being
; split into three groups at the two largest gaps between them. Tiles of palettes whose
; map changed are queued for re-coding. All colours black (faded out): nothing changes.
dmg_maps:   push bc
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
dmg_bgp:    push bc
            push de
            push hl
            call bg_lmax
            ld b, a
            ld a, [REF_LMAX]
            sub b
            jr nc, .dp
            xor a
.dp:        srl a
            ld c, a                         ; fade drop (shades)
            ldh [fade_drop], a
            ld a, [PAL_SH]
            call lum
            call lum_shade
            ld d, a                         ; value 0
            ld e, a                         ; (backdrop shade)
            ld b, 1                         ; value being placed
.v:         call .base
            add a, c
            cp 4
            jr c, .ok
            ld a, 3
.ok:        push bc
.sh:        add a, a
            add a, a
            dec b
            jr nz, .sh
            pop bc
            or d
            ld d, a
            inc b
            ld a, b
            cp 4
            jr nz, .v
            ld a, d
            pop hl
            pop de
            pop bc
            ret
.base:      ld a, e                         ; B = value -> A = its shade before the fade
            cp 3
            jr nz, .lum
            ld a, [NGRP]
            cp 3
            jr z, .n3
            cp 2
            jr z, .n2
.lum:       ld a, b
            add a, low(GLUM)
            ld l, a
            ld h, high(GLUM)
            ld a, [hl]
            jp lum_shade
.n3:        ld a, 3
            sub b
            ret
.n2:        ld a, b
            dec a
            ld a, 2
            ret z
            xor a
            ret

; brightness A (0-8) -> DMG shade (0 white .. 3 black)
lum_shade:  and a
            jr z, .bk
            cp 4
            jr c, .dk
            cp 7
            jr c, .lt
            xor a
            ret
.lt:        ld a, 1
            ret
.dk:        ld a, 2
            ret
.bk:        ld a, 3
            ret

; A = brightest colour 1-3 of the four NES BG palettes (0-8)
bg_lmax:    push bc
            push hl
            ld hl, PAL_SH
            ld b, 0
.i:         ld a, l
            and 3
            jr z, .n
            ld a, [hl]
            call lum
            cp b
            jr c, .n
            ld b, a
.n:         inc l
            ld a, l
            cp 16
            jr nz, .i
            ld a, b
            pop hl
            pop bc
            ret

; boot (DMG): PAL_MAP identity, full brightness reference
dmg_init:   ld a, 8
            ld [REF_LMAX], a
            ld a, 3
            ld [NGRP], a
            ld hl, PAL_MAP
            ld b, 4
.p:         xor a
.i:         ld [hl+], a
            inc a
            cp 4
            jr nz, .i
            dec b
            jr nz, .p
            ret

; D = row, E = col of the GB map: A = 0 if nametable sh_nt drew that cell (OWN)
own_chk:    push bc
            push hl
            ld a, d
            add a, a
            add a, a
            ld b, a
            ld a, e
            rrca
            rrca
            rrca
            and 3
            or b
            ld l, a
            ld h, high(OWN)
            ld a, e
            and 7
            ld b, a
            ld a, [hl]
            inc b
.s:         dec b
            jr z, .d
            rrca
            jr .s
.d:         and 1
            ld b, a
            ldh a, [sh_nt]
            and a
            jr z, .n0
            ld a, 1
.n0:        xor b
            pop hl
            pop bc
            ret

; D = row, E = col: NZ if the cell's attribute quadrant is in ap_chg
quad_chk:   push bc
            ld a, d
            and 2                           ; q = (row & 2) + (col & 2) / 2
            ld b, a
            ld a, e
            and 2
            rrca
            or b
            ld b, a
            ldh a, [ap_chg]
            inc b
.s:         dec b
            jr z, .d
            rrca
            jr .s
.d:         and 1
            pop bc
            ret

; LCD going on after drawing with it off: every GB map cell (rows 0-29) gives its tile
; the palette it is drawn with (from the nametable that owns the cell); tiles coded for
; another palette are marked
dmg_scan_all:
            push bc
            push de
            push hl
            xor a
            ldh [dmg_scan], a
            ld hl, REF_BM                   ; REF_BM: tiles the map uses
            ld b, 32
.z:         ld [hl+], a
            dec b
            jr nz, .z
            ld d, 0                         ; row
.r:         ld e, 0                         ; col
.c:         xor a                           ; owner nametable -> B (0 / 4)
            ldh [sh_nt], a
            ldh a, [own1_lo]
            ld b, a
            ldh a, [own1_hi]
            or b
            jr z, .n0
            call own_chk                    ;   (compares with sh_nt = 0: A = 1 for nametable 1)
            and a
            jr z, .n0
            ld a, 4
.n0:        ld b, a
            ld a, d                         ; tile C: NT_SH + owner * $400 + row * 32 + col
            srl a
            srl a
            srl a
            add a, high(NT_SH)
            add a, b
            ld h, a
            ld a, d
            and 7
            swap a
            add a, a
            or e
            ld l, a
            ld c, [hl]
            ld a, d                         ; palette -> B: attribute byte $3C0 + (row / 4) * 8
            and $1C                         ;   + col / 4 of that nametable, quadrant (row & 2,
            add a, a                        ;   col & 2)
            ld l, a
            ld a, e
            srl a
            srl a
            add a, l
            add a, $C0
            ld l, a
            ld a, b
            add a, high(NT_SH) + 3
            ld h, a
            ld a, [hl]
            bit 1, d
            jr z, .t
            swap a
.t:         bit 1, e
            jr z, .l
            rrca
            rrca
.l:         and 3
            ld b, a
            push bc                         ; tile C referenced
            call bm_addr
            ld a, l
            add a, low(REF_BM) - low(DIRTY_BM)
            ld l, a
            ld a, [hl]
            or b
            ld [hl], a
            pop bc
            ld l, c                         ; coded for palette B?
            ld h, high(TILE_PAL)
            ld a, [hl]
            cp b
            jr z, .s
            ld [hl], b
            ld a, c
            call dmg_mark
.s:         inc e
            ld a, e
            cp 32
            jr nz, .c
            inc d
            ld a, d
            cp 30
            jr nz, .r
            pop hl
            pop de
            pop bc
            ret

; LCD going on after a scan: re-code the marked tiles the map uses; the others are
; parked in DEFER_BM (dmg_cell marks them again when a cell uses them)
dmg_retile_ref:
            push bc
            push de
            push hl
            ld e, 0                         ; bitmap byte
.b:         ld l, e
            ld h, high(DIRTY_BM)
            ld a, e
            add a, low(REF_BM)
            ld c, a
            ld b, high(REF_BM)
            ld a, [bc]                      ; marked tiles the map does not use: parked
            cpl                             ;   (DEFER_BM) until a cell uses them
            and [hl]
            push hl
            push af
            ld a, e
            add a, low(DEFER_BM)
            ld l, a
            ld h, high(DEFER_BM)
            pop af
            or [hl]
            ld [hl], a
            pop hl
            ld a, [bc]
            and [hl]
            ld [hl], 0                      ; no longer marked
            jr z, .n
            ld d, a                         ; bits to do
            ld c, 0
.k:         srl d
            jr nc, .kn
            push de
            ld a, e
            add a, a
            add a, a
            add a, a
            or c
            call retile
            pop de
.kn:        inc c
            ld a, d
            and a
            jr nz, .k
.n:         inc e
            ld a, e
            cp 32
            jr nz, .b
            pop hl
            pop de
            pop bc
            ret

; DMG sprites: two fixed OBJ palettes, OBP0 = black / dark grey / white and OBP1 = dark
; grey / light grey / white (values 1 / 2 / 3). Each NES sprite palette takes OBP0 if one
; of its colours is black, else OBP1, and codes its indices by their shades (SPAL_KEY);
; the sprite slots are loaded again with that coding when the OAM is converted.
spr_maps:   push bc
            push de
            push hl
            ld c, 0
.p:         ld a, c
            add a, a
            add a, a
            add a, low(PAL_SH) + $11
            ld l, a
            ld h, high(PAL_SH)
            ld de, RT_BUF + 8               ; shades of indices 1-3; D... flags black
            ld b, 3
.i:         ld a, [hl+]
            call lum
            call lum_shade
            ld [de], a
            inc de
            dec b
            jr nz, .i
            ld hl, RT_BUF + 8               ; any black (3)? -> OBP0 table, else OBP1
            ld de, SPR_VAL_B
            ld b, 3
.bk:        ld a, [hl+]
            cp 3
            jr nz, .bn
            ld de, SPR_VAL_A
.bn:        dec b
            jr nz, .bk
            ld hl, RT_BUF + 10              ; key = v1 | v2 << 2 | v3 << 4 (+ $40: OBP1)
            ld b, 0
            ld a, 3
.kv:        push af
            ld a, [hl-]
            push de
            add a, e
            ld e, a
            jr nc, .kc
            inc d
.kc:        ld a, [de]
            pop de
            sla b
            sla b
            or b
            ld b, a
            pop af
            dec a
            jr nz, .kv
            ld a, e                         ; OBP1 table: bit 6
            cp low(SPR_VAL_B)
            jr nz, .ka
            ld a, d
            cp high(SPR_VAL_B)
            jr nz, .ka
            set 6, b
.ka:        ld a, c
            add a, low(SPAL_KEY)
            ld l, a
            ld h, high(SPAL_KEY)
            ld [hl], b
            inc c
            ld a, c
            cp 4
            jr nz, .p
            pop hl
            pop de
            pop bc
            ret
SPR_VAL_A:  db 3, 2, 2, 1                   ; shade (white .. black) -> value, OBP0
SPR_VAL_B:  db 3, 2, 1, 1                   ;   OBP1

; obp0_v / obp1_v from the fixed shades, darkened by fade_drop
dmg_obp:    push bc
            ldh a, [fade_drop]
            ld c, a
            ld a, 3                         ; OBP0: values 1-3 = black, dark grey, white
            add a, c
            call .cl
            add a, a
            add a, a
            ld d, a                         ; value 1 << 2
            ld a, 2
            add a, c
            call .cl
            swap a
            or d
            ld d, a
            ld a, c
            call .cl
            rrca
            rrca
            or d
            ldh [obp0_v], a
            ld a, 2                         ; OBP1: dark grey, light grey, white
            add a, c
            call .cl
            add a, a
            add a, a
            ld d, a
            ld a, 1
            add a, c
            call .cl
            swap a
            or d
            ld d, a
            ld a, c
            call .cl
            rrca
            rrca
            or d
            ldh [obp1_v], a
            pop bc
            ret
.cl:        cp 4
            ret c
            ld a, 3
            ret
