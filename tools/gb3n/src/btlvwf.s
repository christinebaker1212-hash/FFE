; ---- btlvwf.s (bank CODE3): the battle windows in the menus' small font (owner's polish pass,
; 2026-11-28: one small font everywhere, the battle laid out as the mock-up). The battle code
; draws its windows into the menu canvas (WRAM 2, MC_MAP / MC_ATTR) as before: frames, and text
; as font codes a cell each; strings that need more room than their cells (names, messages) go in
; as retained strings (bv_put: a row, a span of cells, a palette, left / right / centred). Before a
; V-Blank wait finds the canvas changed (wait_vbl -> bv_conv), each changed row is drawn again in
; the small font (ui.py's glyphs, the menus' black shadow down-right): its fields (a cell's text
; up to two blanks) from their first cell (numbers ending at their last), squeezed (letter gaps
; dropped) when they would run into the next field; then the strings. Inked cells take tiles of the
; row's own pool (VRAM bank 1 $70-$EF, 16 a row in the tall window, 32 in the short one), staged in
; WRAM 4 and sent by the V-Blank (menu_vbl -> bv_vbl) before the window's map. Palettes: BG 7 white,
; 4 yellow, 5 the labels' blue-grey, 6 green (healing), all on the window's colour (Config).
BV_STG     = $D000              ; WRAM 4: the staged tiles $70-$EF (8 blocks of 16)
BV_MAP     = $D800              ;   the window's map as shown (10 rows of 32)
BV_ATR     = $D940              ;   its attributes
BV_LB      = $DA80              ;   a row's pixels: 8 bytes a cell, 21 cells
BV_CP      = $DB28              ;   the row's cell attributes (20)
BV_HASH    = $DB40              ;   the rows' hashes (10 x 2)
BV_FRC     = $DB58              ;   rows to draw again (10)
BV_LR      = $DB80              ;   the canvas row: codes (20), attributes at + $20
BV_ITM     = $DC00              ;   the strings: 16 x 40 (row (0: none), from, to, flags, -, -, -,
BV_NI      = 16                 ;     -, the text (32))
BV_TMP     = $DE80              ;   a tile being built (16)
bv_r       = $DE90              ;   (WRAM 4 bytes)
bv_last    = $DE91
bv_mode    = $DE92
bv_s       = $DE93
bv_e       = $DE94
bv_al      = $DE95
bv_w       = $DE96
bv_g       = $DE97
bv_d       = $DE98
bv_pen     = $DE99
bv_nt      = $DE9A
bv_i       = $DE9B
bv_fs      = $DE9C
bv_fe      = $DE9D
bv_gw      = $DE9E
bv_t       = $DE9F
bv_y       = $DEA0
bv_str     = $DEC0              ;   a field's codes (24)
BV_SHN     = $DEE0              ;   tiles on screen (128 bits), in the map being made, in the last
BV_USD     = $DEF0              ;     one made
BV_ULS     = $DE60
BV_CHG     = $DE70              ;   the rows being drawn again (10)

; ---- battle start: the state, the staged tiles (blank, all sent), the palettes
bv_init:    ldh a, [rSVBK]
            push af
            ld a, 4
            ldh [rSVBK], a
            ld hl, BV_STG
            ld de, $800
            call memclr
            ld hl, BV_ITM
            ld de, 40 * BV_NI
            call memclr
            ld hl, BV_ULS
            ld de, 32
            call memclr
            ld hl, BV_SHN
            ld de, 32
            call memclr
            ld hl, BV_HASH
            ld b, 20
            ld a, $5A
.h:         ld [hl+], a
            dec b
            jr nz, .h
            call bv_frc
            ld a, $FF
            ld [bv_mode], a
            ld [bv_dirty], a
            xor a
            ld [bv_map], a
            ld [bv_busy], a
            pop af
            ldh [rSVBK], a
            ld a, 1
            ld [bv_on], a
            ld [m_dirty], a
; the palettes: BG 4-6 = BG 7's frame colours, their inks; the window's colour (Config) in 4-7
bv_pals:    ld hl, pal_sh + 56
            ld de, pal_sh + 32
            ld c, 3
.p:         push hl
            ld b, 6
.c:         ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .c
            pop hl
            inc de
            inc de
            dec c
            jr nz, .p
            ld hl, BV_INK                   ; colour 3 of BG 4-6
            ld de, pal_sh + 38
            ld c, 3
.i:         ld a, [hl+]
            ld [de], a
            inc de
            ld a, [hl+]
            ld [de], a
            ld a, e
            add a, 7
            ld e, a
            dec c
            jr nz, .i
            ld a, [win_r]                   ; colour 2 of BG 4-7: the window's colour
            ld e, a
            ld a, [win_g]
            ld d, a
            swap a
            add a, a
            and $E0
            or e
            ld e, a
            ld a, d
            srl a
            srl a
            srl a
            ld d, a
            ld a, [win_b]
            add a, a
            add a, a
            or d
            ld d, a
            ld hl, pal_sh + 36
            ld b, 4
.w:         ld [hl], e
            inc hl
            ld [hl], d
            ld a, l
            add a, 7
            ld l, a
            dec b
            jr nz, .w
            ld a, 1
            ldh [pal_dirty], a
            ret
; every row drawn again (WRAM 4 selected)
bv_frc:     ld hl, BV_FRC
            ld b, 10
            ld a, 1
.f:         ld [hl+], a
            dec b
            jr nz, .f
            ret

; ---- the strings. bv_put: B = first cell, C = row, D = the cell after, E = flags (palette, BVF_R /
; BVF_C), HL = the text (0-ended; any bank's RAM, or ROM); the strings it overlaps on that row go.
; bv_clr: B, C, D: those strings gone. bv_clrall: all gone. (Any WRAM bank selected; kept.)
bv_put:     ldh a, [rSVBK]
            ld [bv_svk], a
            push hl
            push de
            ld a, 4
            ldh [rSVBK], a
            call bv_del
            ld hl, BV_ITM                   ; a free one
            ld a, BV_NI
.f:         push af
            ld a, [hl]
            and a
            jr z, .got
            ld a, l
            add a, 40
            ld l, a
            jr nc, .f1
            inc h
.f1:        pop af
            dec a
            jr nz, .f
            pop de
            pop hl
            jr bv_x
.got:       pop af
            pop de
            ld a, c
            ld [hl+], a
            ld a, b
            ld [hl+], a
            ld a, d
            ld [hl+], a
            ld a, e
            ld [hl+], a
            ld de, 4
            add hl, de
            ld d, h
            ld e, l
            pop hl
            ld b, 31
.c:         ld a, [bv_svk]
            ldh [rSVBK], a
            ld a, [hl+]
            ld c, a
            ld a, 4
            ldh [rSVBK], a
            ld a, c
            ld [de], a
            inc de
            and a
            jr z, bv_x
            dec b
            jr nz, .c
            xor a
            ld [de], a
bv_x:       ld a, 1
            ld [m_dirty], a
            ld a, [bv_svk]
            ldh [rSVBK], a
            ret
bv_clr:     ldh a, [rSVBK]
            ld [bv_svk], a
            ld a, 4
            ldh [rSVBK], a
            call bv_del
            jr bv_x
bv_clrall:  ldh a, [rSVBK]
            ld [bv_svk], a
            ld a, 4
            ldh [rSVBK], a
            ld hl, BV_ITM
            ld b, BV_NI
            ld de, 40
.l:         ld a, [hl]
            and a
            jr z, .n
            push hl
            ld [hl], 0
            add a, low(BV_FRC)
            ld l, a
            ld h, high(BV_FRC)
            ld [hl], 1
            pop hl
.n:         add hl, de
            dec b
            jr nz, .l
            jr bv_x
; the strings on row C overlapping cells B to D - 1: gone, the row drawn again (WRAM 4)
bv_del:     push bc
            push de
            ld a, c
            add a, low(BV_FRC)
            ld l, a
            ld h, high(BV_FRC)
            ld [hl], 1
            ld hl, BV_ITM
            ld e, BV_NI
.l:         ld a, [hl]
            cp c
            jr nz, .n
            inc hl
            ld a, [hl+]                     ; from < D and to > B
            cp d
            jr nc, .n2
            ld a, [hl]
            dec hl
            dec hl
            cp b
            jr z, .n
            jr c, .n
            ld [hl], 0
            jr .n
.n2:        dec hl
            dec hl
.n:         ld a, l
            add a, 40
            ld l, a
            jr nc, .n1
            inc h
.n1:        dec e
            jr nz, .l
            pop de
            pop bc
            ret

; the action's line A: its text HL (the caller's bank) kept (BV_NAR + 32 A, WRAM 4)
BV_NAR     = $DF00
bv_nsav:    ld b, a
            ldh a, [rSVBK]
            ld [bv_svk], a
            ld a, b
            swap a
            add a, a
            ld e, a
            ld d, high(BV_NAR)
            ld b, 31
.c:         ld a, [hl+]
            ld c, a
            ld a, 4
            ldh [rSVBK], a
            ld a, c
            ld [de], a
            inc de
            ld a, [bv_svk]
            ldh [rSVBK], a
            ld a, c
            and a
            ret z
            dec b
            jr nz, .c
            ld a, 4
            ldh [rSVBK], a
            xor a
            ld [de], a
            ld a, [bv_svk]
            ldh [rSVBK], a
            ret
; the kept line A as a string at B, C, D, E (bv_put)
bv_nput:    swap a
            add a, a
            ld l, a
            ld h, high(BV_NAR)
            ldh a, [rSVBK]
            push af
            ld a, 4
            ldh [rSVBK], a
            call bv_put
            pop af
            ldh [rSVBK], a
            ret
; the width of code A with its gap (0: none) -> A (DE changed)
bv_cw:      push hl
            call bv_gly
            pop hl
            ld a, 0
            ret nc
            ld a, [de]
            and a
            ret z
            inc a
            ret

; ---- the converter (wait_vbl, the canvas changed): changed rows drawn again. Tiles: a cell keeps
; its tile when the new picture is the same; else a tile neither on screen (BV_SHN) nor in the map
; being made (BV_USD), so the screen never shows a tile changing under the old map
bv_conv:    ldh a, [rSVBK]
            push af
            ld a, 1
            ld [bv_busy], a
            xor a
            ld [m_dirty], a
            ld a, 4
            ldh [rSVBK], a
            ld a, [bv_map]                  ; (the last map shown: its tiles are the screen's)
            and a
            jr nz, .s0
            ld hl, BV_ULS
            ld de, BV_SHN
            ld b, 16
.s1:        ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .s1
.s0:        ldh a, [rWY]                    ; the tall window (WY 64): text rows 1-8, else 1-4
            cp 64
            ld a, 9
            jr z, .t
            ld a, 5
.t:         ld [bv_last], a
            ld hl, bv_mode
            cp [hl]
            jr z, .m
            ld [hl], a
            call bv_frc
.m:         xor a                           ; pass 1: which rows change (others as they are)
.r:         ld [bv_r], a
            call bv_lrow                    ; -> DE = the hash
            ld a, [bv_r]
            add a, low(BV_CHG)
            ld c, a
            ld b, high(BV_CHG)
            xor a
            ld [bc], a
            ld a, [bv_r]
            add a, a
            add a, low(BV_HASH)
            ld l, a
            ld h, high(BV_HASH)
            ld a, [hl]
            cp e
            jr nz, .ch
            inc hl
            ld a, [hl-]
            cp d
            jr nz, .ch
            ld a, [bv_r]
            add a, low(BV_FRC)
            ld c, a
            ld b, high(BV_FRC)
            ld a, [bc]
            and a
            jr z, .nx
.ch:        ld [hl], e
            inc hl
            ld [hl], d
            ld a, [bv_r]
            add a, low(BV_FRC)
            ld l, a
            ld h, high(BV_FRC)
            ld [hl], 0
            ld a, [bv_r]                    ; text rows 1 to last - 1: later; else as they are
            and a
            jr z, .dir
            ld hl, bv_last
            cp [hl]
            jr nc, .dir
            add a, low(BV_CHG)
            ld l, a
            ld h, high(BV_CHG)
            ld [hl], 1
            jr .nx
.dir:       call bv_copy
.nx:        ld a, [bv_r]
            inc a
            cp 10
            jr nz, .r
            ld hl, BV_USD                   ; the map's unchanged text rows: their tiles in use
            ld b, 16
            xor a
.u0:        ld [hl+], a
            dec b
            jr nz, .u0
            ld a, 1
.u:         ld [bv_r], a
            add a, low(BV_CHG)
            ld l, a
            ld h, high(BV_CHG)
            ld a, [hl]
            and a
            jr nz, .un
            call bv_madr
            ld b, 20
.uc:        ld a, [hl+]
            call bv_use
            dec b
            jr nz, .uc
.un:        ld a, [bv_r]
            inc a
            ld hl, bv_last
            cp [hl]
            jr c, .u
            ld a, 1                         ; pass 2: the changed text rows
.p:         ld [bv_r], a
            add a, low(BV_CHG)
            ld l, a
            ld h, high(BV_CHG)
            ld a, [hl]
            and a
            jr z, .pn
            call bv_lrow
            call bv_row
.pn:        ld a, [bv_r]
            inc a
            ld hl, bv_last
            cp [hl]
            jr c, .p
            ld hl, BV_USD
            ld de, BV_ULS
            ld b, 16
.l1:        ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .l1
            ld a, 1
            ld [bv_map], a
            xor a
            ld [bv_busy], a
            pop af
            ldh [rSVBK], a
            ret
; tile A ($70-$EF) in use in the map being made (B, HL kept)
bv_use:     sub $70
            ret c
            cp $80
            ret nc
            push hl
            push bc
            call bv_bit
            ld a, [hl]
            or b
            ld [hl], a
            pop bc
            pop hl
            ret
; tile index A (0-127): HL = BV_USD + A / 8, B = its bit
bv_bit:     ld c, a
            and 7
            ld b, $80
            jr z, .b1
.b:         srl b
            dec a
            jr nz, .b
.b1:        ld a, c
            srl a
            srl a
            srl a
            add a, low(BV_USD)
            ld l, a
            ld h, high(BV_USD)
            ret

; canvas row bv_r -> BV_LR (codes, attributes at + $20); DE = its hash (WRAM 4 kept)
bv_lrow:    ld a, [bv_r]
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld a, h
            add a, high(MC_MAP)
            ld h, a
            ld de, BV_LR
            call .c
            ld a, h
            add a, high(MC_ATTR - MC_MAP)
            ld h, a
            ld a, l
            sub 20
            ld l, a
            ld e, low(BV_LR + $20)
            call .c
            ld hl, BV_LR                    ; the hash
            ld de, 0
            ld b, 20
            call .hs
            ld l, low(BV_LR + $20)
            ld b, 20
.hs:        sla e
            rl d
            jr nc, .h1
            inc e
.h1:        ld a, [hl+]
            xor e
            ld e, a
            dec b
            jr nz, .hs
            ret
.c:         ld b, 20
.cl:        ld a, 2
            ldh [rSVBK], a
            ld a, [hl+]
            ld c, a
            ld a, 4
            ldh [rSVBK], a
            ld a, c
            ld [de], a
            inc de
            dec b
            jr nz, .cl
            ret

; HL = BV_MAP + 32 bv_r (DE = BV_ATR + 32 bv_r)
bv_madr:    ld a, [bv_r]
            swap a
            add a, a
            ld l, a
            ld h, high(BV_MAP)
            jr nc, .a
            inc h
.a:         push hl
            ld de, BV_ATR - BV_MAP
            add hl, de
            ld d, h
            ld e, l
            pop hl
            ret
; a frame row (or one not shown): as it is
bv_copy:    call bv_madr
            ld bc, BV_LR
.l:         ld a, [bc]
            ld [hl+], a
            push bc
            ld a, c
            add a, $20
            ld c, a
            ld a, [bc]
            ld [de], a
            inc de
            pop bc
            inc c
            ld a, c
            cp low(BV_LR) + 20
            jr nz, .l
            ret

; ---- a text row: the pixels, then the cells
bv_row:     ld hl, BV_LB
            ld de, 168
            call memclr
            ld hl, BV_LR + $20              ; the cells' attributes as the canvas has them
            ld de, BV_CP
            ld b, 20
.a:         ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .a
            xor a                           ; the fields
.f:         ld [bv_i], a
            cp 20
            jr nc, .items
            ld e, a
            ld d, high(BV_LR)
            ld a, low(BV_LR)
            add a, e
            ld e, a
            ld a, [de]
            call bv_istx
            jr nc, .fn
            call bv_field
            ld a, [bv_fe]
            jr .f
.fn:        ld a, [bv_i]
            inc a
            jr .f
.items:     ld hl, BV_ITM
            ld b, BV_NI
.it:        push bc
            push hl
            ld a, [bv_r]
            cp [hl]
            jr nz, .in
            inc hl
            ld a, [hl+]                     ; from, to (cells), flags
            ld c, a
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            push hl
            ld e, a
            and 7                           ; the span's palette
            or 8
            ld d, a
            ld a, c
            add a, low(BV_CP)
            ld l, a
            ld h, high(BV_CP)
            ld a, b
            sub c
            jr z, .ip
            jr c, .ip
.pc:        ld [hl], d
            inc hl
            dec a
            jr nz, .pc
.ip:        ld a, c
            add a, a
            add a, a
            add a, a
            ld [bv_s], a
            ld a, b
            add a, a
            add a, a
            add a, a
            ld [bv_e], a
            ld a, e
            rrca
            rrca
            rrca
            and 3
            ld [bv_al], a
            pop hl
            inc hl
            inc hl
            inc hl
            inc hl
            call bv_draw
.in:        pop hl
            ld de, 40
            add hl, de
            pop bc
            dec b
            jr nz, .it
            jp bv_emit

; A = a code: carry if text (not a blank, not a frame)
bv_istx:    cp $F0                          ; ($F0-$F6: tiles as they are, the item icons)
            ret
; a field from cell bv_i: its cells, its room, drawn; bv_fe = the cell after it
bv_field:   ld a, [bv_i]
            ld [bv_fs], a
            ld c, a                         ; C = its last cell
.x:         ld a, c
            inc a
            cp 20
            jr nc, .xd
            ld e, a
            call .code
            call bv_istx
            jr c, .x1
            cp $FF                          ; a single blank before more text: a space
            jr nz, .xd
            ld a, c
            add a, 2
            cp 20
            jr nc, .xd
            ld e, a
            call .code
            call bv_istx
            jr nc, .xd
            inc c
.x1:        inc c
            jr .x
.xd:        ld a, c
            inc a
            ld [bv_fe], a
            ld hl, BV_LR                    ; its codes -> bv_str; numbers only (digits, / :
            ld a, [bv_fs]                   ;   blanks): ending at its last cell
            add a, l
            ld l, a
            ld de, bv_str
            ld a, [bv_fe]
            ld b, a
            ld a, [bv_fs]
            ld c, a
            ld a, b
            sub c
            ld b, a
            ld c, 1                         ; (C: numbers only)
.cp:        ld a, [hl+]
            ld [de], a
            inc de
            cp $FF
            jr z, .cn
            cp $C7
            jr z, .cn
            cp $C8
            jr z, .cn
            cp $8A
            jr nc, .cnn
            cp $80
            jr nc, .cn
.cnn:       ld c, 0
.cn:        dec b
            jr nz, .cp
            xor a
            ld [de], a
            ld a, [bv_fs]
            add a, a
            add a, a
            add a, a
            ld [bv_s], a
            ld a, c
            and a
            jr z, .left
            ld a, [bv_fe]                   ; a number: right-aligned in its own cells
            add a, a
            add a, a
            add a, a
            ld [bv_e], a
            ld a, 1
            jr .go
.left:      ld a, [bv_fe]                   ; the room: to the next field (3 pixels before it) or
            ld c, a                         ;   the frame / the row's end
.nf:        ld a, c
            cp 20
            jr nc, .ne
            ld e, a
            call .code
            cp $FF
            jr nz, .nt
            inc c
            jr .nf
.nt:        call bv_istx
            ld a, c
            jr nc, .ne
            add a, a
            add a, a
            add a, a
            sub 3
            jr .ne1
.ne:        ld a, c
            add a, a
            add a, a
            add a, a
.ne1:       ld [bv_e], a
            xor a
.go:        ld [bv_al], a
            ld hl, bv_str
            jp bv_draw
.code:      ld a, low(BV_LR)
            add a, e
            ld l, a
            ld h, high(BV_LR)
            ld a, [hl]
            ret

; ---- a string HL (WRAM 4) in pixels bv_s to bv_e, bv_al (0 left, 1 right, 2 centre) -> BV_LB;
; too wide: letter gaps dropped (the first ones), then cut at bv_e
bv_draw:    push hl
            ld c, 0                         ; C = width, B = glyphs
            ld b, 0
.m:         ld a, [hl+]
            and a
            jr z, .md
            cp $FF
            jr z, .msp
            call bv_gly
            jr nc, .m
            ld a, [de]
            and a
            jr z, .m
            inc a
            add a, c
            ld c, a
            inc b
            jr .m
.msp:       ld a, c
            add a, 3
            ld c, a
            jr .m
.md:        ld a, c
            and a
            jr z, .m0
            dec c
.m0:        ld a, b                         ; gaps = glyphs - 1
            and a
            jr z, .g0
            dec b
.g0:        ld a, [bv_s]                    ; room = e - s; d = min(w - room, gaps)
            ld e, a
            ld a, [bv_e]
            sub e
            ld e, a
            ld a, c
            sub e
            jr nc, .ov
            xor a
.ov:        cp b
            jr c, .d1
            ld a, b
.d1:        ld [bv_d], a
            ld d, a
            ld a, c
            sub d
            ld c, a                         ; C = the width drawn
            ld a, [bv_al]                   ; the pen
            and a
            ld a, [bv_s]
            jr z, .pen
            ld a, e
            sub c
            jr nc, .p1
            xor a
.p1:        ld d, a
            ld a, [bv_al]
            cp 2
            ld a, d
            jr nz, .p2
            srl a
.p2:        ld d, a
            ld a, [bv_s]
            add a, d
.pen:       ld [bv_pen], a
            pop hl
.dl:        ld a, [hl+]
            and a
            ret z
            cp $FF
            jr z, .sp
            push hl
            call bv_gly
            jr nc, .dn
            ld a, [de]
            and a
            jr z, .dn
            ld [bv_gw], a
            ld b, a
            ld a, [bv_pen]
            add a, b
            ld b, a
            ld a, [bv_e]
            cp b
            jr c, .cut
            inc de
            call bv_put1
            ld a, [bv_gw]
            ld b, a
            ld a, [bv_d]
            and a
            jr z, .gap
            dec a
            ld [bv_d], a
            dec b
.gap:       inc b
            ld a, [bv_pen]
            add a, b
            ld [bv_pen], a
.dn:        pop hl
            jr .dl
.cut:       pop hl
            ret
.sp:        ld a, [bv_pen]
            add a, 3
            ld [bv_pen], a
            jr .dl

; DE = the glyph of code A (BV_GLY + 9 (A - $80)); carry if one
bv_gly:     cp $CA                          ; (FF3's battle arrow: ours)
            jr nz, .x
            ld a, $C9
.x:         cp $76                          ; (FF3's "EXP", "HP", "MP" tiles $76-$7A: E H M P X)
            jr c, .g
            cp $7B
            jr nc, .g
            push hl
            sub $76
            add a, low(.t)
            ld l, a
            ld a, high(.t)
            adc a, 0
            ld h, a
            ld a, [hl]
            pop hl
            jr .g
.t:         db $8E, $91, $96, $99, $A1
.g:         cp $80
            ccf
            ret nc
            cp $D0
            ret nc
            push hl
            sub $80
            ld l, a
            ld h, 0
            ld d, h
            ld e, l
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, de
            ld de, BV_GLY
            add hl, de
            ld d, h
            ld e, l
            pop hl
            scf
            ret
; the glyph's 8 rows (DE) at bv_pen -> BV_LB
bv_put1:    ld a, [bv_pen]
            and $F8
            ld l, a
            ld h, high(BV_LB)
            ld a, low(BV_LB)
            add a, l
            ld l, a
            jr nc, .h
            inc h
.h:         ld a, [bv_pen]
            and 7
            ld c, a
            ld b, 8
.r:         ld a, [de]
            inc de
            and a
            jr z, .n
            push bc
            push hl
            ld h, a
            ld l, 0
            ld a, c
            and a
            jr z, .s0
.s:         srl h
            rr l
            dec c
            jr nz, .s
.s0:        ld b, h
            ld c, l
            pop hl
            ld a, [hl]
            or b
            ld [hl], a
            push hl
            ld a, l
            add a, 8
            ld l, a
            jr nc, .s1
            inc h
.s1:        ld a, [hl]
            or c
            ld [hl], a
            pop hl
            pop bc
.n:         inc hl
            dec b
            jr nz, .r
            ret

; ---- the row's cells: inked ones (or under the shadow of the one before) get pool tiles
bv_emit:    call bv_madr
            push de
            push hl
            xor a
            ld [bv_i], a
.c:         pop hl
            pop de
            ld a, [bv_i]
            ld c, a
            ld b, high(BV_LR)
            ld a, low(BV_LR)
            add a, c
            ld c, a
            ld a, [bc]
            cp $F0                          ; a frame (or an icon): as it is
            jr c, .tx
            cp $FF
            jr z, .tx
            ld [hl+], a
            ld a, c
            add a, $20
            ld c, a
            ld a, [bc]
            ld [de], a
            inc de
            jp .nx
.tx:        push de
            push hl
            call bv_lbc                     ; HL = the cell's pixels; any ink, or a shadow
            ld b, 8
            xor a
.k:         or [hl]
            inc hl
            dec b
            jr nz, .k
            ld c, a
            ld a, [bv_i]
            and a
            jr z, .k2
            ld a, l
            sub 16
            ld l, a
            jr nc, .k0
            dec h
.k0:        ld b, 8
.k1:        ld a, [hl+]
            and 1
            or c
            ld c, a
            dec b
            jr nz, .k1
.k2:        ld a, c
            and a
            jr z, .blank
            call bv_tile                    ; -> A = the tile ($FF: none left)
            jr .put
.blank:     ld a, $FF
.put:       pop hl
            pop de
            ld [hl+], a
            ld a, [bv_i]
            add a, low(BV_CP)
            ld c, a
            ld b, high(BV_CP)
            ld a, [bc]
            ld [de], a
            inc de
.nx:        push de
            push hl
            ld a, [bv_i]
            inc a
            ld [bv_i], a
            cp 20
            jp nz, .c
            pop hl
            pop de
            ret
; HL = BV_LB + 8 bv_i
bv_lbc:     ld a, [bv_i]
            add a, a
            add a, a
            add a, a
            add a, low(BV_LB)
            ld l, a
            ld h, high(BV_LB)
            ret nc
            inc h
            ret
; the cell bv_i's tile -> A: its old one if its picture is the same, else a free one ($FF: none)
bv_tile:    call bv_lbc                     ; the picture: plane 0 ink, plane 1 not shadow
            ld de, BV_TMP
            xor a
            ld [bv_y], a
.r:         ld c, 0                         ; C = the shadow: the row above, a pixel right
            ld a, [bv_y]
            and a
            jr z, .s
            dec hl
            ld a, [hl+]
            srl a
            ld c, a
            ld a, [bv_i]
            and a
            jr z, .s
            push hl                         ; (the cell before's row above: its last pixel)
            ld a, l
            sub 9
            ld l, a
            jr nc, .s0
            dec h
.s0:        ld a, [hl]
            rrca
            and $80
            or c
            ld c, a
            pop hl
.s:         ld a, [hl+]
            ld [de], a
            inc de
            ld b, a
            ld a, c
            cpl
            or b
            ld [de], a
            inc de
            ld a, [bv_y]
            inc a
            ld [bv_y], a
            cp 8
            jr nz, .r
            call bv_madr                    ; the old tile (the map not yet written here)
            ld a, [bv_i]
            add a, l
            ld l, a
            ld a, [hl]
            ld [bv_t], a
            sub $70
            jr c, .new
            cp $80
            jr nc, .new
            call bv_stg
            call bv_same
            jr nz, .new
            ld a, [bv_t]
            call bv_use
            ld a, [bv_t]
            ret
.new:       ld hl, BV_SHN                   ; a tile free in both
            ld de, BV_USD
            ld c, 0
.f:         ld a, [de]
            or [hl]
            cp $FF
            jr nz, .fb
            inc hl
            inc de
            ld a, c
            add a, 8
            ld c, a
            cp $80
            jr c, .f
            ld a, $FF
            ret
.fb:        ld b, $80
.fk:        rlca                            ; (the first clear bit, MSB first)
            jr nc, .fk1
            srl b
            inc c
            jr .fk
.fk1:       ld a, [de]
            or b
            ld [de], a
            ld a, c
            add a, $70
            ld [bv_t], a
            sub $70
            call bv_stg                     ; staged, its block to send
            ld de, BV_TMP
            ld b, 16
.w:         ld a, [de]
            ld [hl+], a
            inc de
            dec b
            jr nz, .w
            ld a, [bv_t]
            sub $70
            swap a
            and 7
            ld b, a
            ld a, $80
            inc b
.bt:        rlca
            dec b
            jr nz, .bt
            ld b, a
            ld a, [bv_dirty]
            or b
            ld [bv_dirty], a
            ld a, [bv_t]
            ret
; HL = BV_STG + 16 A (A = tile - $70)
bv_stg:     swap a
            ld l, a
            and $0F
            add a, high(BV_STG)
            ld h, a
            ld a, l
            and $F0
            ld l, a
            ret
; Z if the staged tile HL = BV_TMP
bv_same:    ld de, BV_TMP
            ld b, 16
.c:         ld a, [de]
            cp [hl]
            ret nz
            inc de
            inc hl
            dec b
            jr nz, .c
            ret

; ---- the V-Blank (menucore.s bv_vbl, this bank mapped): the staged tile blocks (WRAM 4 -> VRAM
; bank 1 $8700 + 256 k), then the window's map and attributes once all are sent; each copy only
; while LY 144-150 leaves it time
bv_vbl9:    ld a, [bv_busy]
            and a
            ret nz
            ldh a, [rSVBK]
            push af
            ld a, 4
            ldh [rSVBK], a
.b:         ld a, [bv_dirty]
            and a
            jr z, .m
            ld c, a
            ldh a, [rLY]
            cp 144
            jr c, .x
            cp 151
            jr nc, .x
            ld b, 0                         ; the lowest block k (B), its bit (E) off
            ld e, 1
.k:         ld a, c
            and e
            jr nz, .k1
            inc b
            sla e
            jr .k
.k1:        ld a, e
            cpl
            and c
            ld [bv_dirty], a
            ld a, b
            add a, $D0
            ldh [rHDMA1], a
            xor a
            ldh [rHDMA2], a
            ld a, b
            add a, $87
            ldh [rHDMA3], a
            xor a
            ldh [rHDMA4], a
            ld a, 1
            ldh [rVBK], a
            ld a, 15
            ldh [rHDMA5], a
            xor a
            ldh [rVBK], a
            jr .b
.m:         ld a, [bv_map]
            and a
            jr z, .x
            ldh a, [rLY]
            cp 144
            jr c, .x
            cp 150
            jr nc, .x
            ld a, $D8
            ldh [rHDMA1], a
            xor a
            ldh [rHDMA2], a
            ld a, $9C
            ldh [rHDMA3], a
            xor a
            ldh [rHDMA4], a
            ld a, 20 - 1
            ldh [rHDMA5], a
            ld a, 1
            ldh [rVBK], a
            ld a, $D9
            ldh [rHDMA1], a
            ld a, $40
            ldh [rHDMA2], a
            ld a, $9C
            ldh [rHDMA3], a
            xor a
            ldh [rHDMA4], a
            ld a, 20 - 1
            ldh [rHDMA5], a
            xor a
            ldh [rVBK], a
            ld [bv_map], a
.x:         pop af
            ldh [rSVBK], a
            ret

; ---- the battle's end: the canvas copied as it is again
bv_off:     xor a
            ld [bv_on], a
            ret
