; FF1 native engine: black outlines around the party's pictures on the menu screens (owner,
; 2026-11-25: the black removed from the sprites, a 1 px black outline around them with the
; edges rounded off, never stacked; applied to the party in menus). Our own code.
;
; A picture is a 2 x 3 sprite block (scr_spr23); its sprites keep FF1's three colours and see-through
; parts. The outline is drawn in the background under it: every window-inside pixel that touches a
; sprite pixel above, below, left or right (not on a diagonal: rounded corners) turns black, and so
; does every see-through pixel inside the figure (sprite on all four sides: ul_fill). The
; cells under the pictures get tiles of their own (copies of what was there, outline added):
; Color: VRAM bank 1 tiles $80-$FF, black = palette colour 0 (the window palette's outside black);
; plain Game Boy with White windows: tiles $94-$BF and $E0-$FF (the gold labels keep $C0-$DF),
; black = index 0 (the pre-shaded font's ink). With Black
; windows (plain Game Boy, Super Game Boy) the see-through parts already show black: nothing to do.
; The outline is worked out from the sprite tiles in VRAM, so any pose and screen works. Rebuilt at
; scr_show (LCD off) and at scr_upd when a picture moved or changed (LCD on: each VRAM access in
; mode 0 / 1). RAM: the field's metatile queue (screens drop it: main.s), $C220-$C2B4 and the cells
; at $C300-$C47F (the battle's raster tables and text line: unused on these screens).

UL_MAXP    = 6              ; pictures on one screen

section wram, $C220                         ; (inside qbuf: the field's queue, dropped by screens)
ul_s:       ds 48                           ; a picture's rows: the sprite pixels (left, right byte)
ul_pk:      ds UL_MAXP * 4                  ; pictures: OAM entry, x, y, first tile
ul_np:      ds 1
ul_nc:      ds 1
ul_dirty:   ds 1
ul_ink:     ds 1                            ; 1 Color, 2 plain Game Boy (White windows)
ul_x:       ds 1
ul_y:       ds 1
ul_t:       ds 1
ul_r:       ds 1
ul_k:       ds 1
ul_m:       ds 4                            ; an outline row aligned to cells
ul_tmp:     ds 16
ul_f:       ds 48                           ; the filled shape (same page as ul_s: ul_x24)
section wram, $C300                         ; (the battle's raster tables / text line: free here)
ul_cell:    ds 128 * 3                      ; cells: map offset (2), the tile that was there

section bank 99, $4D40                      ; (free space)
; scr_open (sgb_menu9): a new screen, no pictures, no cells
ul_new:     xor a
            ld [ul_np], a
            ld [ul_nc], a                   ; (Lot Check checker, 2026-11-25: the count lives in the
                                            ;   field's queue too; a stale one restored stray cells)
            ld [ul_nc], a
            ld [ul_dirty], a
            ret
; scr_spr23 (sgb_pic0): picture sgb_pk at (sgb_px, sgb_py), its tiles from scr_t1; then the SGB's
pic_rec:    ld hl, ul_pk
            ld a, [ul_np]
            ld b, a
.f:         ld a, b
            and a
            jr z, .new
            ld a, [sgb_pk]
            cp [hl]
            jr z, .old
            inc hl
            inc hl
            inc hl
            inc hl
            dec b
            jr .f
.new:       ld a, [ul_np]
            cp UL_MAXP
            jr nc, .sg
            inc a
            ld [ul_np], a
            ld a, [sgb_pk]
            ld [hl+], a
            jr .set
.old:       inc hl                          ; (the same place and tiles: nothing to redo)
            ld a, [sgb_px]
            cp [hl]
            jr nz, .set
            inc hl
            ld a, [sgb_py]
            cp [hl]
            jr nz, .s1
            inc hl
            ld a, [scr_t1]
            cp [hl]
            jr nz, .s2
            jr .sg
.set:       ld a, [sgb_px]
            ld [hl+], a
.s1:        ld a, [sgb_py]
            ld [hl+], a
.s2:        ld a, [scr_t1]
            ld [hl], a
            ld a, 1
            ld [ul_dirty], a
.sg:        ld a, [sgb_on]
            and a
            ret z
            jp sgb_pic
; scr_show (sgb_pics0): the outlines, then the DMG / SGB inks and pictures (alt_show)
pic_show:   call ul_build
            ldh a, [is_cgb]
            and a
            ret nz
            jp alt_show
; scr_upd (alt_upd): the outlines again if a picture changed, then the DMG / SGB inks
pic_upd:    ld a, [ul_dirty]
            and a
            call nz, ul_build
            ldh a, [is_cgb]
            and a
            ret nz
            jp alt_pass

; every picture's outline made again (the cells put back first)
ul_build:   xor a
            ld [ul_dirty], a
            ld a, [ul_nc]                   ; the cells put back (ul_ink still the last build's)
            and a
            jr z, .m
            ld b, a
            ld hl, ul_cell
.r:         ld e, [hl]                      ; (only a cell still showing its outline tile: a cell
            inc hl                          ;   the screen drew again meanwhile keeps the new)
            ld d, [hl]
            inc hl
            ld a, [hl+]
            push hl
            push bc
            ld c, a
            ld a, d                         ; (an offset past the map: none of ours, skipped)
            cp high(18 * 32)
            jr c, .in
            jr nz, .kp
            ld a, e
            cp low(18 * 32)
            jr nc, .kp
.in:
            ld hl, smap
            add hl, de
            ld a, [ul_nc]                   ; (this cell's tile: ul_code of its index)
            sub b
            call ul_code
            cp [hl]
            jr nz, .kp
            ld [hl], c
.kp:        pop bc
            pop hl
            dec b
            jr nz, .r
            xor a
            ld [ul_nc], a
.m:         ldh a, [is_cgb]                 ; which black: the Color's colour 0, the plain
            and a                           ;   Game Boy's colour 3 (White windows only)
            ld a, 1
            jr nz, .k
            ld a, [sgb_on]
            and a
            ret nz
            ld a, [opt_dmgw]
            and a
            ret z
            ld a, 2
.k:         ld [ul_ink], a
            ld a, [ul_np]
            and a
            ret z
            ld b, a
            ld hl, ul_pk
.p:         push bc
            push hl
            inc hl
            ld a, [hl+]
            ld [ul_x], a
            ld a, [hl+]
            ld [ul_y], a
            ld a, [hl]
            ld [ul_t], a
            call ul_pic
            pop hl
            ld de, 4
            add hl, de
            pop bc
            dec b
            jr nz, .p
            ldh a, [is_cgb]                 ; (VBK on the Color only)
            and a
            ret z
            xor a
            ldh [rVBK], a
            ret

section bank 99, $58E0                      ; (free space)
; A = [HL] of VRAM (LCD on: in mode 0 / 1)
ul_rd:      ldh a, [rLCDC]
            bit 7, a
            jr z, .r
.w:         di                              ; (no interrupt between the mode test and the access)
            ldh a, [rSTAT]
            and 2
            jr z, .ok
            ei
            jr .w
.ok:        ld a, [hl]
            ei
            ret
.r:         ld a, [hl]
            ret
; [HL] = A in VRAM (LCD on: in mode 0 / 1); keeps A
ul_wr:      push bc
            ld b, a
            ldh a, [rLCDC]
            bit 7, a
            jr z, .r
.w:         di
            ldh a, [rSTAT]
            and 2
            jr z, .ok
            ei
            jr .w
.ok:        ld [hl], b
            ei
            ld a, b
            pop bc
            ret
.r:         ld [hl], b
            ld a, b
            pop bc
            ret

; one picture (ul_x, ul_y, ul_t): its sprite pixels read, its outline added to the cells
ul_pic:     ldh a, [is_cgb]                 ; (sprite tiles: VRAM bank 0; VBK on the Color only)
            and a
            jr z, .v0
            xor a
            ldh [rVBK], a
.v0:
            ld a, [ul_t]
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, $8000
            add hl, de
            ld de, ul_s
            ld c, 3
.tr:        ld b, 8
.ro:        call ul_rd                      ; the left tile's row: lo | hi
            ld [ul_k], a
            inc hl
            call ul_rd
            ld [ul_r], a
            dec hl
            ld a, [ul_k]
            push hl
            ld hl, ul_r
            or [hl]
            pop hl
            ld [de], a
            inc de
            push hl                         ; the right tile's (16 on)
            ld a, l
            add a, 16
            ld l, a
            ld a, h
            adc a, 0
            ld h, a
            call ul_rd
            ld [ul_k], a
            inc hl
            call ul_rd
            ld [ul_r], a
            ld a, [ul_k]
            ld hl, ul_r
            or [hl]
            pop hl
            ld [de], a
            inc de
            inc hl
            inc hl
            dec b
            jr nz, .ro
            ld a, l                         ; (past the right tile: the next pair)
            add a, 16
            ld l, a
            ld a, h
            adc a, 0
            ld h, a
            dec c
            jr nz, .tr
            call ul_fill
            xor a                           ; box rows 0-25 (y - 1 .. y + 24)
            ld [ul_r], a
.row:       call ul_orow                    ; ul_m = the row's outline, aligned to cells
            ld a, [ul_y]                    ; the pixel row y - 1 + r
            dec a
            ld hl, ul_r
            add a, [hl]
            cp 144
            jr nc, .nx
            ld c, a
            xor a
            ld [ul_k], a
.col:       ld a, [ul_k]
            ld e, a
            ld d, 0
            ld hl, ul_m
            add hl, de
            ld a, [hl]
            and a
            jr z, .cn
            ld b, a                         ; B = the mask, C = the pixel row
            ld a, [ul_x]                    ; the cell column (x - 1) / 8 + k
            dec a
            srl a
            srl a
            srl a
            add a, e
            cp 20
            jr nc, .cn
            push bc
            call ul_cell1
            pop bc
.cn:        ld a, [ul_k]
            inc a
            ld [ul_k], a
            cp 4
            jr c, .col
.nx:        ld a, [ul_r]
            inc a
            ld [ul_r], a
            cp 26
            jr c, .row
            ret

; the 24-bit sprite row of box row A (A - 1 a sprite row 0-23, else none) -> C, D, E:
; bits 23-0 = x - 1 .. x + 22 (the sprite at bits 22-7)
ul_f24:     ld b, low(ul_f)                 ; (the filled shape)
            jr ul_x24
ul_s24:     ld b, low(ul_s)
ul_x24:     dec a
            cp 24
            jr nc, .z
            add a, a
            add a, b
            ld l, a
            ld h, high(ul_s)
            ld a, [hl+]                     ; M = left : right (bit 15 = x)
            ld d, a
            ld e, [hl]
            ld a, d                         ; C = M >> 9, D = (M >> 1) & $FF, E = M << 7
            srl a
            ld c, a
            ld a, d
            rrca
            and $80
            ld b, a
            ld a, e
            srl a
            or b
            ld b, a                         ; (B = the middle byte)
            ld a, e
            rrca
            and $80
            ld e, a
            ld d, b
            ret
.z:         ld c, 0
            ld d, c
            ld e, c
            ret
; ul_m = the black of box row ul_r: (F | F << 1 | F >> 1 | F above | F below) and not S, with F the
; filled shape (ul_fill), shifted right by (x - 1) & 7 so ul_m + 0 is the cell of pixel x - 1
ul_orow:    ld a, [ul_r]                    ; above (box row r - 1)
            dec a
            call ul_f24
            ld a, c
            ld [ul_m], a
            ld a, d
            ld [ul_m + 1], a
            ld a, e
            ld [ul_m + 2], a
            ld a, [ul_r]                    ; below (box row r + 1)
            inc a
            call ul_f24
            ld hl, ul_m
            ld a, c
            or [hl]
            ld [hl+], a
            ld a, d
            or [hl]
            ld [hl+], a
            ld a, e
            or [hl]
            ld [hl], a
            ld a, [ul_r]                    ; this row's F itself
            call ul_f24
            ld hl, ul_m
            ld a, c
            or [hl]
            ld [hl+], a
            ld a, d
            or [hl]
            ld [hl+], a
            ld a, e
            or [hl]
            ld [hl], a
            ld a, [ul_r]                    ; this row: F << 1 and F >> 1 added, S taken out
            call ul_f24
            push bc                         ; (C kept: S's first byte)
            push de
            ld a, e                         ; S << 1
            add a, a
            ld e, a
            ld a, d
            rla
            ld d, a
            ld a, c
            rla
            ld hl, ul_m
            or [hl]
            ld [hl+], a
            ld a, d
            or [hl]
            ld [hl+], a
            ld a, e
            or [hl]
            ld [hl], a
            pop de
            pop bc
            push bc
            push de
            ld a, c                         ; S >> 1
            srl a
            ld c, a
            ld a, d
            rra
            ld d, a
            ld a, e
            rra
            ld e, a
            ld hl, ul_m
            ld a, c
            or [hl]
            ld [hl+], a
            ld a, d
            or [hl]
            ld [hl+], a
            ld a, e
            or [hl]
            ld [hl], a
            pop de
            pop bc
            ld a, [ul_r]
            call ul_s24
            ld hl, ul_m                     ; and not S
            ld a, c
            cpl
            and [hl]
            ld [hl+], a
            ld a, d
            cpl
            and [hl]
            ld [hl+], a
            ld a, e
            cpl
            and [hl]
            ld [hl+], a
            xor a
            ld [hl], a                      ; (ul_m + 3)
            ld a, [ul_x]                    ; shifted right by (x - 1) & 7
            dec a
            and 7
            ret z
            ld b, a
.sh:        ld hl, ul_m
            srl [hl]
            inc hl
            rr [hl]
            inc hl
            rr [hl]
            inc hl
            rr [hl]
            dec b
            jr nz, .sh
            ret

; mask B on pixel row C of cell column A: the cell's own tile (made once a screen, only when the
; mask turns a window-inside pixel black), its window-inside pixels under the mask black
ul_cell1:   ld e, a                         ; DE = smap offset: (C >> 3) x 32 + A
            ld a, c
            and 7
            push af
            ld a, c
            and $F8
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl                      ; x 4: (row / 8) x 32
            ld d, 0
            add hl, de
            ld d, h
            ld e, l
            pop af
            ld c, a                         ; C = the row in the cell
            push bc
            call ul_find
            jr z, .have
            ld hl, smap                     ; not yet: what is shown there, its row C
            add hl, de
            ld a, [hl]
            call ul_vsrc
            pop bc
            push bc
            ld a, c
            add a, a
            add a, l
            ld l, a
            ld a, h
            adc a, 0
            ld h, a
            call ul_rd
            ld c, a
            inc hl
            call ul_rd
            call ul_inside                  ; A = the inside pixels of lo C, hi A
            and b
            jr z, .no
            call ul_alloc
            jr c, .no
.have:      call ul_vaddr                   ; HL = the cell's tile (bank set)
            pop bc
            ld a, c
            add a, a
            add a, l
            ld l, a
            ld a, h
            adc a, 0
            ld h, a
            call ul_rd                      ; lo
            ld e, a
            inc hl
            call ul_rd                      ; hi
            ld d, a
            ld c, e
            call ul_inside
            and b
            ret z
            ld b, a
            ld a, [ul_ink]
            cp 1
            jr nz, .dmg
            ld a, d                         ; Color: colour 0 (hi cleared)
            xor b
            jp ul_wr
.dmg:       ld a, d                         ; DMG: index 0 (lo and hi cleared)
            xor b
            call ul_wr
            dec hl
            ld a, e
            xor b
            jp ul_wr
.no:        pop bc
            ret
; A = the window-inside pixels of a tile row (lo C, hi A): Color colour 2 (lo 0, hi 1), DMG's
; pre-shaded font index 3 (lo 1, hi 1)
ul_inside:  push bc
            ld b, a
            ld a, [ul_ink]
            cp 1
            ld a, c
            jr nz, .d
            cpl
.d:         and b
            pop bc
            ret
; Z and A = the cell's index if smap offset DE has a tile of its own
ul_find:    ld hl, ul_cell
            ld a, [ul_nc]
            ld b, a
            ld c, 0
.f:         ld a, b
            and a
            jr z, .no
            ld a, [hl+]
            cp e
            jr nz, .n1
            ld a, [hl]
            cp d
            jr nz, .n1
            ld a, c
            cp a
            ret
.n1:        inc hl
            inc hl
            inc c
            dec b
            jr .f
.no:        or 1
            ret
; a tile of its own for the cell at smap offset DE (a copy of what is there): A = its index, C set
; if none is left (Color 128, plain Game Boy 76)
ul_alloc:   ld a, [ul_ink]
            cp 1
            ld b, 128
            jr z, .m
            ld b, 76
.m:         ld a, [ul_nc]
            cp b
            ccf
            ret c
            ld c, a
            inc a
            ld [ul_nc], a
            ld a, c                         ; the entry: offset, the tile there
            add a, a
            add a, c
            ld l, a
            ld h, 0
            push bc
            ld bc, ul_cell
            add hl, bc
            pop bc
            ld a, e
            ld [hl+], a
            ld a, d
            ld [hl+], a
            push hl
            ld hl, smap
            add hl, de
            ld a, [hl]
            pop hl
            ld [hl], a
            push bc
            push de
            call ul_vsrc                    ; its 16 bytes to ul_tmp
            ld de, ul_tmp
            ld b, 16
.c:         call ul_rd
            ld [de], a
            inc hl
            inc de
            dec b
            jr nz, .c
            pop de
            pop bc
            ld a, c                         ; the cell shows its own tile
            call ul_code
            ld hl, smap
            add hl, de
            ld [hl], a
            ld a, c
            call ul_vaddr
            ld de, ul_tmp
            ld b, 16
.w:         ld a, [de]
            call ul_wr
            inc de
            inc hl
            dec b
            jr nz, .w
            ld a, c
            and a
            ret
; A = the tile code of cell index A (Color $80 + A; DMG $94 + A, from 44 on $E0 + A - 44)
ul_code:    push bc
            ld b, a
            ld a, [ul_ink]
            cp 1
            ld a, b
            jr nz, .d
            add a, $80
            pop bc
            ret
.d:         cp 44
            jr nc, .e
            add a, $94
            pop bc
            ret
.e:         add a, $E0 - 44
            pop bc
            ret
; HL = VRAM of cell index A's tile ($8800 + 16 (code - $80); Color: bank 1 selected)
ul_vaddr:   call ul_code
            sub $80
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            push bc
            ld bc, $8800
            add hl, bc
            pop bc
            ld a, [ul_ink]
            cp 1
            ret nz
            ld a, 1
            ldh [rVBK], a
            ret
; HL = VRAM of BG tile A ($8800 mode), the bank of its cell (Color: the attribute's bit 3; DE =
; the smap offset)
ul_vsrc:    push af
            ldh a, [is_cgb]
            and a
            jr z, .b
            push hl
            ld hl, sattr
            add hl, de
            ld a, [hl]
            pop hl
            and 8
            rrca
            rrca
            rrca
            ldh [rVBK], a
.b:         pop af
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            bit 7, a
            jr nz, .hi
            ld bc, $9000
            add hl, bc
            ret
.hi:        ld bc, $8800 - $800
            add hl, bc
            ret

section bank 99, $4A00                      ; (free space)
; ul_f = the picture's filled shape (owner, 2026-11-25: the Black Magician's eyes surrounded by
; black): every pixel with sprite pixels left and right of it in its row and above and below it in
; its column, the sprite's own pixels included. See-through parts inside the figure (the face under
; the Black Magician's hat, gaps in robes) turn black, as on the NES's black background.
ul_fill:    ld hl, ul_s                     ; columns: sprite above (running OR from the top)
            ld de, ul_f
            ld bc, 0
.t:         ld a, [hl+]
            or b
            ld b, a
            ld [de], a
            inc de
            ld a, [hl+]
            or c
            ld c, a
            ld [de], a
            inc de
            ld a, l
            cp low(ul_s + 48)
            jr nz, .t
            ld hl, ul_s + 47                ; and sprite below (running OR from the bottom)
            ld de, ul_f + 47
            ld bc, 0
.b:         ld a, [hl-]
            or c
            ld c, a
            ld a, [de]
            and c
            ld [de], a
            dec de
            ld a, [hl-]
            or b
            ld b, a
            ld a, [de]
            and b
            ld [de], a
            dec de
            ld a, l
            cp low(ul_s - 1)
            jr nz, .b
            ld hl, ul_s                     ; rows: between the leftmost and rightmost pixel
.h:         ld a, [hl+]                     ; DE = the row (bit 15 = the left edge)
            ld d, a
            ld a, [hl+]
            ld e, a
            cpl                             ; BC = x | -x: the rightmost pixel and left of it
            add a, 1
            ld c, a
            ld a, d
            cpl
            adc a, 0
            or d
            ld b, a
            ld a, c
            or e
            ld c, a
            ld a, d                         ; and the leftmost pixel and right of it
            and a
            jr z, .lo
            call .sm
            and b
            ld b, a
            jr .st
.lo:        ld b, a                         ; (A = 0)
            ld a, e
            call .sm
            and c
            ld c, a
.st:        push hl
            ld de, ul_f - ul_s - 2
            add hl, de
            ld a, [hl]
            and b
            ld [hl+], a
            ld a, [hl]
            and c
            ld [hl], a
            pop hl
            ld a, l
            cp low(ul_s + 48)
            jr nz, .h
            ret
.sm:        ld d, a                         ; A = A smeared right (A | A >> 1 | .. | A >> 7)
            srl a
            or d
            ld d, a
            srl a
            srl a
            or d
            ld d, a
            swap a
            and $0F
            or d
            ret
