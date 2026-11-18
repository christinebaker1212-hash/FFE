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
            ld a, 1
            ldh [rq_any], a
            pop hl
            pop bc
            pop af
            ret

; C = tile -> HL = its DIRTY_BM byte, B = its bit
bm_addr:    ld a, c
            srl a
            srl a
            srl a
            ld l, a
            ld h, high(DIRTY_BM)
            ld a, c
            and 7
            ld b, a
            ld a, 1
            inc b
.sh:        dec b
            jr z, .got
            add a, a
            jr .sh
.got:       ld b, a
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
.row:       ld a, [de]                      ; p0
            inc de
            ldh [sh_p0], a
            ld a, [de]                      ; p1
            inc de
            ldh [sh_p1], a
            ldh a, [sh_s0]
            call .plane
            call vram_put
            inc hl
            ldh a, [sh_s1]
            call .plane
            call vram_put
            inc hl
            dec b
            jr nz, .row
            pop hl
            pop de
            pop bc
            ret
.plane:     ; A = set of values (bit v) -> A = OR of the pixel masks of those values
            push bc
            push de
            ld c, a
            ld b, 0
            ldh a, [sh_p0]
            ld d, a
            ldh a, [sh_p1]
            ld e, a
            bit 0, c                        ; value 0: ~p0 & ~p1
            jr z, .v1
            ld a, d
            or e
            cpl
            or b
            ld b, a
.v1:        bit 1, c                        ; value 1: p0 & ~p1
            jr z, .v2
            ld a, e
            cpl
            and d
            or b
            ld b, a
.v2:        bit 2, c                        ; value 2: ~p0 & p1
            jr z, .v3
            ld a, d
            cpl
            and e
            or b
            ld b, a
.v3:        bit 3, c                        ; value 3: p0 & p1
            jr z, .vd
            ld a, d
            and e
            or b
            ld b, a
.vd:        ld a, b
            pop de
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
            jr z, .x
            ld [hl], e
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
            ld c, [hl]                      ; attribute byte
            ld a, b                         ; shift = (row & 2) * 2 + (col & 2)
            and 2
            add a, a
            ld b, a
            ld a, e
            and 2
            add a, b
            inc a
            ld b, a
            ld a, c
.s:         dec b
            jr z, .d
            rrca
            jr .s
.d:         and 3
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

; brightness of NES colour A: 0 black .. 8 white (the 2C02 rows, grey column a bit brighter)
lum:        push bc
            ld b, a
            and $0F
            cp $0D
            jr nc, .blk
            ld c, a
            ld a, b
            and $30
            swap a
            add a, a
            inc a
            ld b, a
            ld a, c
            and a
            ld a, b
            jr nz, .x
            inc a
            jr .x
.blk:       xor a
.x:         pop bc
            ret

; recompute PAL_MAP from the NES BG palettes; tiles of palettes whose map changed are
; queued for re-coding
dmg_maps:   push bc
            push de
            push hl
            call bg_lmax                    ; all BG colours black (faded out): keep the maps
            and a
            jp z, .x
            ld [REF_LMAX], a                ; brightness the BGP fade level is measured from
            ld a, [PAL_SH]
            call lum
            ldh [sh_bk], a                  ; backdrop brightness
            ld c, 0                         ; palette
.p:         ld a, c
            add a, a
            add a, a
            ld l, a
            ld h, high(PAL_SH)
            inc l
            ld a, [hl+]                     ; brightness of colours 1-3 -> sh_l1..3 (0 = like the backdrop)
            call .one
            ldh [sh_l1], a
            ld a, [hl+]
            call .one
            ldh [sh_l2], a
            ld a, [hl]
            call .one
            ldh [sh_l3], a
            ld b, a                         ; a palette that is all backdrop keeps its map
            ldh a, [sh_l1]
            or b
            ld b, a
            ldh a, [sh_l2]
            or b
            jr z, .nx
            ; value of each colour = 1 + number of distinct brighter-or-equal levels below it
            ld hl, sh_l1
            ld b, 3
            ld de, RT_BUF + 1
            xor a
            ld [RT_BUF], a                  ; colour 0 -> 0
.v:         ld a, [hl]
            and a
            jr z, .v0
            push bc
            push de
            push hl
            call .rank
            pop hl
            pop de
            pop bc
.v0:        ld [de], a
            inc de
            inc l
            dec b
            jr nz, .v
            ld a, c                         ; compare with PAL_MAP[c]; copy; mark if changed
            add a, a
            add a, a
            add a, low(PAL_MAP)
            ld l, a
            ld h, high(PAL_MAP)
            ld de, RT_BUF
            ld b, 4
            ld a, 0
            ldh [sh_chg], a
.cmp:       ld a, [de]
            cp [hl]
            jr z, .same
            ld [hl], a
            ld a, 1
            ldh [sh_chg], a
.same:      inc de
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
.x:         pop hl
            pop de
            pop bc
            ret
.one:       ; A = colour -> brightness, 0 if it equals the backdrop's
            call lum
            ld b, a
            ldh a, [sh_bk]
            cp b
            ld a, b
            ret nz
            xor a
            ret
.rank:      ; A = brightness L (non-zero) -> value 1-3 among sh_l1..3 (0s ignored):
            ld b, a                         ;   1 + count of distinct non-zero levels < L,
            ld c, 0                         ;   spread: 2 levels -> 1 / 3, 1 level -> 3
            ldh a, [sh_l1]
            call .lt
            ldh a, [sh_l2]
            ld e, a
            ldh a, [sh_l1]
            cp e
            ld a, e
            call nz, .lt
            ldh a, [sh_l3]
            ld e, a
            ldh a, [sh_l1]
            cp e
            jr z, .dup
            ldh a, [sh_l2]
            cp e
            jr z, .dup
            ld a, e
            call .lt
.dup:       ; C = levels below; count distinct non-zero levels -> D
            call .ndist
            ld a, d
            cp 3
            jr z, .r3
            cp 2
            jr z, .r2
            ld a, 3
            ret
.r2:        ld a, c
            and a
            ld a, 1
            ret z
            ld a, 3
            ret
.r3:        ld a, c
            inc a
            ret
.lt:        and a                           ; level A non-zero and < B: C += 1
            ret z
            cp b
            ret nc
            inc c
            ret
.ndist:     ld d, 0
            ldh a, [sh_l1]
            and a
            jr z, .d2
            inc d
.d2:        ldh a, [sh_l2]
            and a
            jr z, .d3
            ld e, a
            ldh a, [sh_l1]
            cp e
            jr z, .d3
            inc d
.d3:        ldh a, [sh_l3]
            and a
            ret z
            ld e, a
            ldh a, [sh_l1]
            cp e
            ret z
            ldh a, [sh_l2]
            cp e
            ret z
            inc d
            ret
.markp:     ; queue every tile coded for palette C
            push bc
            ld hl, TILE_PAL
.mk:        ld a, [hl]
            cp c
            jr nz, .mn
            ld a, l
            call dmg_mark
.mn:        inc l
            jr nz, .mk
            pop bc
            ret

; BGP: value 0 = the backdrop's shade; values 1 / 2 / 3 (darkest .. brightest colour of a
; tile's palette) = dark grey / light grey / white, darkened while the palettes are faded:
; one shade per two brightness levels the brightest BG colour is below REF_LMAX (its level
; when the maps were last computed). Returns A = BGP.
dmg_bgp:    push bc
            push de
            call bg_lmax
            ld b, a
            ld a, [REF_LMAX]
            sub b
            jr nc, .dp
            xor a
.dp:        srl a
            ld c, a                         ; fade drop (shades)
            ld a, [PAL_SH]
            call lum
            call lum_shade
            ld d, a                         ; value 0
            ld e, 2                         ; value 1 base shade (dark grey)
            ld b, 1                         ; value being placed
.v:         ld a, e
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
            dec e
            inc b
            ld a, b
            cp 4
            jr nz, .v
            ld a, d
            pop de
            pop bc
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
