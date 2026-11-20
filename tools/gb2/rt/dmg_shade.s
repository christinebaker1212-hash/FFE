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
; (retile_b, bank HLE_BANK). Keeps BC, DE, HL.
retile:     push af
            ld a, HLE_BANK
            ld [$2000], a
            pop af
            call retile_b
            jp hle_back

; B / C = colour indices whose value has bit 0 / bit 1 set (the tile's palette), E = tile ->
; A = its coding key: the values of the indices it uses. Keeps BC, DE, HL.
tkey_bc:    push hl
            ld a, e
            srl a
            add a, low(TILE_USE)
            ld l, a
            ld h, high(TILE_USE)
            ld a, [hl]
            bit 0, e
            jr z, .lo
            swap a
.lo:        and $0F
            or 1
            ld l, a
            and c
            swap a
            ld h, a
            ld a, l
            and b
            or h
            pop hl
            ret

; A = tile whose pixels were written: mark it, its coding unknown. Keeps all registers.
dmg_markw:  push hl
            ld l, a
            ld h, high(CODED)
            ld [hl], $FF
            ld h, high(TILE_PAL)            ; (new pattern: no longer the tileset's)
            res 7, [hl]
            pop hl
            jp dmg_mark
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
            call q_drain1
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
            push hl                         ; palette fixed by the field tileset (tset_fix):
            ld l, a                         ;   no cell lookup, only the parked check
            ld h, high(TILE_PAL)            ;   (L = the cell's offset is needed below)
            bit 7, [hl]
            pop hl
            jr nz, .pk
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
            call pal_mark
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
            call ovr_be                     ; (FF2: GB-only palette override)
            pop hl
            pop bc
            ret

; NES attribute byte A (0-63, + $40 for nametable 1) written: its 16 cells' tiles are checked
dmg_attr:   push bc
            push de
            push hl
            ld c, a
            ldh a, [sgb_glob]               ; (SGB: the screen's palettes again; while it
            and a                           ;   scrolls, on the next 32-frame rebuild)
            jr nz, .ng
            ld a, 1
            ldh [sgb_dirty], a
            ldh [sgb_adirty], a
.ng:        ld a, c
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
            ld a, d                         ; this nametable's tile there has a palette fixed
            srl a                           ;   by the field tileset: nothing to re-shade
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
            ld l, [hl]
            ld h, high(TILE_PAL)
            bit 7, [hl]
            jr nz, .s
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
            call pal_mark                   ; (a palette reached by an attribute change, e.g.
            pop af                          ;   the prologue's fade, counts as used too)
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
dmg_maps:   ld a, HLE_BANK                  ; (the body is dmg_maps_b in bank HLE_BANK,
            ld [$2000], a                   ;   rt/ff2_banked.s: bank 0 is full)
            call dmg_maps_b
            jp hle_back

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
.lum:       ld a, b                         ; (value 1, the darkest: by its darkest level -
            dec a                           ;   FF2's credits draw black with indices 2-3
            jr nz, .lg                      ;   over a blue backdrop, beside a grey)
            ld a, [LSL]
            jp lum_shade
.lg:        ld a, b
            add a, low(GLUM)
            ld l, a
            ld h, high(GLUM)
            ld a, [hl]
            jp lum_shade
.n3:        call .v1blk                     ; value 1 / 2 / 3: dark grey / light grey / white,
            jr z, .n3b                      ;   or black / light grey / white when value 1
            ld a, 3                         ;   holds only the darkest colours ($0x: menu
            sub b                           ;   windows, as the battle's black windows)
            ret
.n3b:       ld a, b
            dec a
            ld a, 3
            ret z
            ld a, b
            sub 2
            xor 1
            ret
.n2:        call .v1blk
            ld a, b
            jr nz, .n2g
            dec a
            ld a, 3
            ret z
            xor a
            ret
.n2g:       dec a
            ld a, 2
            ret z
            xor a
            ret
.v1blk:     ld a, [GLUM + 1]                ; Z: value 1's brightest level is 1 or less
            cp 2
            jr nc, .v1n
            xor a
            ret
.v1n:       or 1
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
dmg_init:   ld hl, CODED                    ; no tile coded yet
            ld a, $FF
.cd:        ld [hl+], a
            inc l
            dec l
            jr nz, .cd
            ld a, 8
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

; LCD going on after drawing with it off: every GB map cell gives its tile the palette it
; is drawn with (dmg_scan_all_b in bank HLE_BANK, rt/ff2_banked.s)
dmg_scan_all:
            ld a, HLE_BANK
            ld [$2000], a
            call dmg_scan_all_b
            jp hle_back
cgb_attr_all:                               ; CGB, LCD going on: every cell's palette
            ld a, HLE_BANK                  ;   (cgb_attr_all_b, rt/ff2_banked.s)
            ld [$2000], a
            call cgb_attr_all_b
            jp hle_back

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

; A = BG palette a cell uses: into PAL_USED; a palette new there makes the maps be
; recomputed (next frame). Keeps BC, DE, HL.
pal_mark:   push hl
            push bc
            ld hl, BIT_MASK
            add a, l
            ld l, a
            jr nc, .nc
            inc h
.nc:        ld b, [hl]
            ld a, [PAL_USED]
            ld c, a
            or b
            cp c
            jr z, .x
            ld [PAL_USED], a
            ld a, 1
            ldh [maps_due], a
            ld a, PAL_STABLE - 1
            ldh [pal_age], a
.x:         pop bc
            pop hl
            ret
