; FF1 native engine: full screens (title, new game) in code bank 2. Our own code.
; Screens show the font at tile = code ($10-$7F: DMG BG tiles at $9000 + 16 code, CGB VRAM
; bank 1 with palette 7), windows from FF1's frame tiles, FF1's hand cursor (sprite tiles
; $7C-$7F) and class battle sprites (sprite tiles 0-35: six classes' standing pose).
; UI_GFX bank: see tools/gbn/ui.py. Strings: str_<name> (tools/gbn/ui.py), in this bank.

SCR_BANK   = 2
UI_GFX     = 3
U_SPRDMG   = $4000
U_SPRCGB   = $5800
U_CURDMG   = $7000
U_CURCGB   = $7040
U_CURTBL   = $7080
U_OBJPAL   = $7100
U_CLSPAL   = $7120
U_STATS    = $7140
CUR_TILE   = $7C
CH_NAME2   = $3E            ; the 5th and 6th letters of a name (6-letter names)

section bank 0, $2600                       ; (the framework: bank 0, for every screen)

; ---- the framework
; screen on with the LCD off: map cleared to blank, font, palettes, cursor tiles, no sprites
scr_open:   ldh a, [rLCDC]
            bit 7, a
            jr z, .off
.w:         ldh a, [rLY]
            cp 144
            jr c, .w
            xor a
            ldh [rLCDC], a
.off:       xor a
            ld [box_on], a
            ldh [scx], a
            ldh [scy], a
            ld a, 18
            ld [sf_row], a
            ld hl, smap                     ; the map copy: blank (code $20), window attributes
            ld bc, 18 * 32
.cl:        ld a, $20
            ld [hl+], a
            dec bc
            ld a, b
            or c
            jr nz, .cl
            ld hl, sattr
            ld bc, 18 * 32
.cla:       ld a, WIN_ATTR
            ld [hl+], a
            dec bc
            ld a, b
            or c
            jr nz, .cla
            ld hl, $9800                    ; VRAM map: blank
            ld bc, $0400
.cv:        ld a, $20
            ld [hl+], a
            dec bc
            ld a, b
            or c
            jr nz, .cv
            ld hl, oam_buf                  ; no sprites
            ld b, 160
            xor a
.oc:        ld [hl+], a
            dec b
            jr nz, .oc
            ldh a, [is_cgb]
            and a
            jr z, .dmg
            ld a, 1                         ; CGB: every cell palette 7, VRAM bank 1
            ldh [rVBK], a
            ld hl, $9800
            ld bc, $0400
.ca:        ld a, WIN_ATTR
            ld [hl+], a
            dec bc
            ld a, b
            or c
            jr nz, .ca
            xor a
            ldh [rVBK], a
            ld a, UI_GFX                    ; OBJ palettes 0-3: FF1's battle sprite palettes
            ld hl, U_OBJPAL
            ld de, scr_buf
            ld bc, 32
            call far_copy
            ld a, $80
            ldh [rOCPS], a
            ld hl, scr_buf
            ld b, 32
.op:        ld a, [hl+]
            ldh [rOCPD], a
            dec b
            jr nz, .op
            ld hl, U_CURCGB
            jr .cur
.dmg:       ld a, COMMON                    ; DMG: the font at tile = code
            ld hl, C_FONTDMG + $10          ; (icons $01-$1F, frame, letters)
            ld de, $9010
            ld bc, $07F0
            call far_copy
            ld a, %11100100
            ldh [rBGP], a
            ld a, DMG_OBP
            ldh [rOBP0], a
            ld hl, U_CURDMG
.cur:       ld de, $8000 + 16 * CUR_TILE    ; the hand cursor
            ld bc, 64
            ld a, UI_GFX
            call far_copy
            ld a, UI_GFX                    ; its 2 x 2 table, the class palettes
            ld hl, U_CURTBL
            ld de, cur_tbl
            ld bc, 8
            call far_copy
            ld a, UI_GFX
            ld hl, U_CLSPAL
            ld de, cls_pal
            ld bc, 12
            jp far_copy

oam_clr:    ld hl, oam_buf
            ld b, 160
            xor a
.o:         ld [hl+], a
            dec b
            jr nz, .o
            ret

; the map copy cleared (blank, window attributes) with the LCD on
scr_cls:    call oam_clr
            ld hl, smap
            ld bc, 18 * 32
.c:         ld a, $20
            ld [hl+], a
            dec bc
            ld a, b
            or c
            jr nz, .c
            ld hl, sattr
            ld bc, 18 * 32
.a:         ld a, WIN_ATTR
            ld [hl+], a
            dec bc
            ld a, b
            or c
            jr nz, .a
            ret

; the map copy to VRAM: with the LCD off all of it and the LCD on; with the LCD on in the
; next frames' V-Blanks (scr_frame)
scr_show:   ldh a, [rLCDC]
            bit 7, a
            jr nz, scr_upd
            xor a
.r:         push af
            call sf_one
            pop af
            inc a
            cp 18
            jr c, .r
            ld a, 18
            ld [sf_row], a
            ld a, LCDC_ON
            ldh [rLCDC], a
            ret
scr_upd:    xor a
            ld [sf_row], a
            ret
; row A of the map copy (and its CGB attributes) to VRAM
sf_one:     ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld d, h
            ld e, l
            ld bc, smap
            add hl, bc
            push hl
            ld hl, $9800
            add hl, de
            ld d, h
            ld e, l
            pop hl
            push de
            push hl
            ld b, 20
.c:         ld a, [hl+]
            ld [de], a
            inc e
            dec b
            jr nz, .c
            pop hl
            pop de
            ldh a, [is_cgb]
            and a
            ret z
            ld a, h
            add a, 3                        ; (attributes: + $300)
            ld h, a
            ld a, 1
            ldh [rVBK], a
            ld b, 20
.a:         ld a, [hl+]
            ld [de], a
            inc e
            dec b
            jr nz, .a
            xor a
            ldh [rVBK], a
            ret
; V-Blank (LCD on): rows still to upload, while the V-Blank lasts
sf_step:    ld a, [sf_row]
            cp 18
            ret nc
            ldh a, [rLY]
            cp 144
            ret c
            cp 152
            ret nc
            ld a, [sf_row]
            call sf_one
            ld hl, sf_row
            inc [hl]
            jr sf_step

; the class battle sprites' standing poses (six classes from A) to sprite tiles 0-35
scr_classes:
            ld [scr_t0], a
            ld de, $8000
            ld c, 6
.l:         push bc
            push de
            ld a, [scr_t0]                  ; HL = class block (32 tiles)
            ld l, a
            ld h, 0
            add hl, hl                      ; x 512
            ld a, l
            ld l, 0
            ld h, a
            add hl, hl
            ldh a, [is_cgb]
            and a
            ld bc, U_SPRDMG
            jr z, .d
            ld bc, U_SPRCGB
.d:         add hl, bc
            ld bc, 96
            ld a, UI_GFX
            call far_copy
            ld hl, scr_t0
            inc [hl]
            pop de
            ld hl, 96
            add hl, de
            ld d, h
            ld e, l
            pop bc
            dec c
            jr nz, .l
            ret

; window: B = x, C = y, D = width, E = height (LCD off)
scr_win:    push de
            call .w
            pop de
            ret
.w:         push bc
            call cell_addr                  ; HL = smap + 32 y + x
            ld b, $10
            ld c, $11
            ld a, $12
            call .row
            pop bc
            push bc
            dec e
            dec e
.m:         inc c
            push bc
            push de
            call cell_addr
            ld b, $13
            ld c, $20
            ld a, $14
            call .row
            pop de
            pop bc
            dec e
            jr nz, .m
            inc c
            call cell_addr
            ld b, $15
            ld c, $16
            ld a, $17
            call .row
            pop bc
            ret
.row:       ld [scr_t1], a                  ; B, C x (width - 2), A
            ld a, b
            ld [hl+], a
            ld a, d
            sub 2
            ld b, a
            ld a, c
.r:         ld [hl+], a
            dec b
            jr nz, .r
            ld a, [scr_t1]
            ld [hl], a
            ret

; HL = smap + 32 C + B (the map copy; attributes at + $300)
cell_addr:  push de
            ld l, c
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, smap
            add hl, de
            ld a, l
            add a, b
            ld l, a
            ld a, h
            adc a, 0
            ld h, a
            pop de
            ret

; string HL (this bank or RAM; $0A new line, $00 end) at (B, C); LCD off
scr_str:    push bc
            push hl
            call cell_addr
            ld d, h
            ld e, l
            pop hl
.c:         ld a, [hl+]
            and a
            jr z, .x
            cp $0A
            jr z, .nl
            ld [de], a
            inc de
            jr .c
.nl:        pop bc
            inc c
            push bc
            push hl
            call cell_addr
            ld d, h
            ld e, l
            pop hl
            jr .c
.x:         pop bc
            ret

; the same with the LCD on: into the copy, uploaded in the next V-Blanks
scr_str_on: call scr_str
            jp scr_upd

; the hand cursor at screen pixel (B = x, C = y), OAM entries 0-3
scr_cursor: ld hl, cur_tbl
            ld de, oam_buf
            ld a, c
            add a, 16
            ld c, a
            ld a, b
            add a, 8
            ld b, a
            call .one                       ; UL
            ld a, c
            add a, 8
            ld c, a
            call .one                       ; DL
            ld a, b
            add a, 8
            ld b, a
            ld a, c
            sub 8
            ld c, a
            call .one                       ; UR
            ld a, c
            add a, 8
            ld c, a
            jp .one                         ; DR
.one:       ld a, c
            ld [de], a
            inc de
            ld a, b
            ld [de], a
            inc de
            ld a, [hl+]
            add a, CUR_TILE
            ld [de], a
            inc de
            ld a, [hl+]
            and 3
            ld [de], a
            inc de
            ret

; a class's standing pose (2 x 3 sprites) at (B = x, C = y): tile base A, OAM entry E x 4
scr_spr23:  ld [scr_t1], a
            ld a, e                         ; HL = oam_buf + 4 E
            add a, a
            add a, a
            ld l, a
            ld h, high(oam_buf)
            ld a, [scr_t0]                  ; (palette)
            ld d, a
            ld a, c
            add a, 16
            ld c, a
            ld a, b
            add a, 8
            ld b, a
            ld e, 3
.r:         ld a, c
            ld [hl+], a
            ld a, b
            ld [hl+], a
            ld a, [scr_t1]
            ld [hl+], a
            inc a
            ld [scr_t1], a
            ld a, d
            ld [hl+], a
            ld a, c
            ld [hl+], a
            ld a, b
            add a, 8
            ld [hl+], a
            ld a, [scr_t1]
            ld [hl+], a
            inc a
            ld [scr_t1], a
            ld a, d
            ld [hl+], a
            ld a, c
            add a, 8
            ld c, a
            dec e
            jr nz, .r
            ret

; one frame: wait, pad, OAM
scr_frame:  call wait_vbl
            call sf_step
            jp read_pad

section bank 2, $4000

; ---- new game: title menu, party generation
ng_main:    call scr_open
            ld b, 6                         ; title menu (the GB layout: three boxes)
            ld c, 5
            ld d, 12
            ld e, 3
            call scr_win
            ld c, 8
            call scr_win
            ld b, 2
            ld c, 11
            ld d, 18
            call scr_win
            ld bc, $0806
            ld hl, str_title0
            call scr_str
            ld bc, $0809
            ld hl, str_title1
            call scr_str
            ld bc, $040C
            ld hl, str_title2
            call scr_str
            call save_valid                 ; a save: Continue first, else New Game
            ld a, 0
            jr nc, .sv
            inc a
.sv:        ld [ng_cur], a
            call scr_show
.t:         ld a, [ng_cur]                  ; cursor left of the box
            add a, a
            ld c, a
            add a, a
            add a, c                        ; 6 x
            add a, a
            add a, a                        ; 24 x
            add a, 36
            ld c, a
            ld b, 24
            call scr_cursor
            call scr_frame
            ldh a, [pad_new]
            ld b, a
            and $C0                         ; up / down: Continue <-> New Game
            jr z, .ab
            ld a, [ng_cur]
            xor 1
            ld [ng_cur], a
            jr .t
.ab:        ld a, b
            and $09                         ; A or Start
            jr z, .t
            ld a, [ng_cur]
            and a
            jr nz, .new
            call save_valid                 ; Continue: the saved game
            jr c, .t
            jp load_game
.new:       call party_gen
            call ng_stats
            ret

; party generation (FF1 PtyGen): per member, a direction cycles the class, A names it,
; B goes back a member; after the fourth, A confirms, B returns to the fourth
party_gen:  xor a
            ld hl, pg_class
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl], a
            ld hl, pg_names
            ld b, 24
            ld a, $20
.n:         ld [hl+], a
            dec b
            jr nz, .n
            xor a
            ld [pg_mem], a
.mem:       call pg_screen
.ml:        call pg_draw_cur
            call scr_frame
            ldh a, [pad_new]
            bit 0, a
            jr nz, .a
            bit 1, a
            jr nz, .b
            and $F0
            jr z, .ml
            ld a, [pg_mem]                  ; next class
            ld l, a
            ld h, 0
            ld de, pg_class
            add hl, de
            ld a, [hl]
            inc a
            cp 6
            jr c, .cs
            xor a
.cs:        ld [hl], a
            call pg_screen
            jr .ml
.b:         ld a, [pg_mem]
            and a
            jr z, .ml
            dec a
            ld [pg_mem], a
            jr .mem
.a:         call name_input
            jr c, .mem                      ; (B on an empty name: back to the boxes)
            ld a, [pg_mem]
            inc a
            ld [pg_mem], a
            cp 4
            jr c, .mem
            ld a, 4                         ; all four: confirm
            ld [pg_mem], a
            call pg_screen
.cf:        call scr_frame
            ldh a, [pad_new]
            bit 0, a
            ret nz
            bit 1, a
            jr z, .cf
            ld a, 3
            ld [pg_mem], a
            jr .mem

; the four boxes (approved layout: 10 x 9 at (0,0) (10,0) (0,9) (10,9)): class sprite,
; class name, name
pg_screen:  call scr_open
            xor a
            call scr_classes
            ld a, 0
.bx:        ld [pg_t], a
            call pg_box_xy                  ; B, C = the box's corner
            ld d, 10
            ld e, 9
            call scr_win
            push bc                         ; class name (two rows) at (+1, +5)
            inc b
            ld a, c
            add a, 5
            ld c, a
            ld a, [pg_t]
            ld l, a
            ld h, 0
            ld de, pg_class
            add hl, de
            ld a, [hl]
            call class_str                  ; HL = its name
            call scr_str
            pop bc
            push bc                         ; name at (+1, +7)
            inc b
            ld a, c
            add a, 7
            ld c, a
            call name_buf                   ; HL = the member's 6 letters, 0-ended copy
            call scr_str
            pop bc
            ld a, [pg_t]                    ; sprite: cells (+4..5, +1..3)
            ld l, a
            ld h, 0
            ld de, pg_class
            add hl, de
            ld a, [hl]
            push af
            ld e, a                         ; palette from the class
            ld hl, cls_pal
            ld d, 0
            add hl, de
            ld a, [hl]
            ld [scr_t0], a
            pop af
            ld e, a                         ; tile base 6 x class
            add a, a
            add a, e
            add a, a
            push af
            ld a, b
            add a, 4
            add a, a
            add a, a
            add a, a
            ld b, a
            ld a, c
            inc a
            add a, a
            add a, a
            add a, a
            ld c, a
            ld a, [pg_t]                    ; OAM entries 4 + 6 box
            ld e, a
            add a, a
            add a, e
            add a, a
            add a, 4
            ld e, a
            pop af
            call scr_spr23
            ld a, [pg_t]
            inc a
            cp 4
            jr c, .bx
            call scr_show
            ret

; A = box -> B, C = its corner
pg_box_xy:  ld bc, 0
            bit 0, a
            jr z, .x
            ld b, 10
.x:         bit 1, a
            ret z
            ld c, 9
            ret

pg_draw_cur:
            ld a, [pg_mem]                  ; the hand left of the class name
            cp 4
            jr c, .m
            ld bc, $0000                    ; (confirm: no cursor)
            ld hl, oam_buf
            ld [hl], 0
            inc hl
            inc hl
            inc hl
            inc hl
            ld [hl], 0
            ret
.m:         call pg_box_xy
            ld a, b
            add a, a
            add a, a
            add a, a
            ld b, a
            ld a, c
            add a, 5
            add a, a
            add a, a
            add a, a
            sub 4
            ld c, a
            jp scr_cursor

; A = class -> HL = its name string
class_str:  add a, a
            ld l, a
            ld h, 0
            ld de, class_ptrs
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ret
class_ptrs: dw str_class0, str_class1, str_class2, str_class3, str_class4, str_class5
            dw str_class6, str_class7, str_class8, str_class9, str_class10, str_class11

; HL = a 0-ended copy of member pg_t's name (6 letters)
name_buf:   ld a, [pg_t]
            ld l, a
            add a, a
            add a, l
            add a, a                        ; 6 x
            ld l, a
            ld h, 0
            ld de, pg_names
            add hl, de
            ld de, pg_nb
            ld b, 6
.c:         ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .c
            xor a
            ld [de], a
            ld hl, pg_nb
            ret

; name entry (the approved layout: the grid 10 x 9, two columns / rows apart; the name on
; the top row): A adds the letter, B removes the last (on an empty name: C, back), Start
; finishes (at least one letter); six letters finish too
name_input: call scr_open
            ld c, 1                         ; the grid rows
            ld hl, grid_ptrs
            ld e, 9
.g:         push de
            push hl
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld de, pg_row                   ; letters two cells apart
            ld b, 10
.gl:        ld a, [hl+]
            ld [de], a
            inc de
            ld a, $20
            ld [de], a
            inc de
            dec b
            jr nz, .gl
            xor a
            ld [de], a
            ld b, 1
            ld hl, pg_row
            call scr_str
            inc c
            inc c
            pop hl
            inc hl
            inc hl
            pop de
            dec e
            jr nz, .g
            ld a, [pg_mem]                  ; the name so far (cleared)
            ld [pg_t], a
            call name_ptr
            ld b, 6
            ld a, $20
.cl:        ld [hl+], a
            dec b
            jr nz, .cl
            xor a
            ld [ni_len], a
            ld [ni_x], a
            ld [ni_y], a
            call ni_name
            call scr_show
.lp:        ld a, [ni_x]                    ; the hand left of the letter
            add a, a
            add a, a
            add a, a
            add a, a
            sub 8
            ld b, a
            ld a, [ni_y]
            add a, a
            add a, a
            add a, a
            add a, a
            add a, 4
            ld c, a
            call scr_cursor
            call scr_frame
            ldh a, [pad_new]
            bit 0, a
            jr nz, .a
            bit 1, a
            jr nz, .b
            bit 3, a
            jr nz, .st
            ld hl, ni_x
            bit 4, a
            jr z, .nr
            ld a, [hl]
            inc a
            cp 10
            jr c, .sx
            xor a
.sx:        ld [hl], a
            jr .lp
.nr:        bit 5, a
            jr z, .nl
            ld a, [hl]
            dec a
            cp 10
            jr c, .sx
            ld a, 9
            jr .sx
.nl:        ld hl, ni_y
            bit 6, a
            jr z, .nu
            ld a, [hl]
            dec a
            cp 9
            jr c, .sy
            ld a, 8
.sy:        ld [hl], a
            jr .lp
.nu:        bit 7, a
            jr z, .lp
            ld a, [hl]
            inc a
            cp 9
            jr c, .sy
            xor a
            jr .sy
.a:         ld a, [ni_y]                    ; the letter: grid row y, column x
            add a, a
            ld l, a
            ld h, 0
            ld de, grid_ptrs
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld a, [ni_x]
            add a, l
            ld l, a
            ld a, h
            adc a, 0
            ld h, a
            ld c, [hl]
            call name_ptr
            ld a, [ni_len]
            add a, l
            ld l, a
            ld a, h
            adc a, 0
            ld h, a
            ld [hl], c
            ld a, [ni_len]
            inc a
            ld [ni_len], a
            call ni_name
            ld a, [ni_len]
            cp 6
            jp c, .lp
            and a                           ; six letters: done
            ret
.b:         ld a, [ni_len]
            and a
            jr z, .back
            dec a
            ld [ni_len], a
            call name_ptr
            ld a, [ni_len]
            add a, l
            ld l, a
            ld a, h
            adc a, 0
            ld h, a
            ld [hl], $20
            call ni_name
            jp .lp
.back:      scf
            ret
.st:        ld a, [ni_len]
            and a
            jp z, .lp
            and a                           ; NC: done
            ret

; HL = member pg_mem's name (6 bytes)
name_ptr:   ld a, [pg_mem]
            ld l, a
            add a, a
            add a, l
            add a, a
            ld l, a
            ld h, 0
            ld de, pg_names
            add hl, de
            ret

; the name on the top row (LCD on), with a mark at the next letter
ni_name:    ld a, [pg_mem]
            ld [pg_t], a
            call name_buf
            ld a, [ni_len]                  ; '-' marks the next letter
            cp 6
            jr nc, .n
            ld e, a
            ld d, 0
            ld hl, pg_nb
            add hl, de
            ld [hl], '-'
.n:         ld hl, pg_nb
            ld bc, $0700
            ldh a, [rLCDC]
            bit 7, a
            jp z, scr_str
            jp scr_str_on

grid_ptrs:  dw str_grid0, str_grid1, str_grid2, str_grid3, str_grid4, str_grid5, str_grid6
            dw str_grid7, str_grid8

; the party into the save page: classes, names, starting stats (FF1
; NewGame_LoadStartingStats; Red / White / Black Magicians start with 2 level-1 MP)
ng_stats:   ld c, 0
.m:         ld a, c                         ; HL = ch_stats + 64 c
            rrca
            rrca
            ld l, a
            ld h, high(ch_stats)
            push hl
            ld e, c
            ld d, 0
            ld hl, pg_class
            add hl, de
            ld a, [hl]
            pop hl
            ld [hl], a                      ; class
            push af
            push hl
            inc hl
            inc hl                          ; +2 name (4) and +$3E (2)
            push hl
            ld a, c
            add a, a
            add a, c
            add a, a
            ld e, a
            ld hl, pg_names
            add hl, de
            ld d, h
            ld e, l
            pop hl
            ld b, 4
.nm:        ld a, [de]
            inc de
            ld [hl+], a
            dec b
            jr nz, .nm
            ld a, l
            add a, CH_NAME2 - 6
            ld l, a
            ld a, [de]
            inc de
            ld [hl+], a
            ld a, [de]
            ld [hl], a
            pop hl
            pop af                          ; stats from the class's starting record
            push bc
            push hl
            swap a                          ; x 16: the record into scr_buf
            ld e, a
            ld d, 0
            ld hl, U_STATS
            add hl, de
            ld de, scr_buf
            ld bc, 16
            ld a, UI_GFX
            call far_copy
            ld de, scr_buf
            pop hl
            push hl
            inc de
            ld a, [de]                      ; HP
            inc de
            ld bc, $0A
            add hl, bc
            ld [hl+], a                     ; current
            ld [hl], 0
            inc hl
            ld [hl+], a                     ; max
            ld [hl], 0
            pop hl
            push hl
            ld bc, $10                      ; strength .. luck
            add hl, bc
            ld b, 5
.st:        ld a, [de]
            inc de
            ld [hl+], a
            dec b
            jr nz, .st
            pop hl
            push hl
            ld bc, $20                      ; damage, hit rate, (absorb), evade, magic defence
            add hl, bc
            ld a, [de]
            inc de
            ld [hl+], a
            ld a, [de]
            inc de
            ld [hl+], a
            inc hl
            ld a, [de]
            inc de
            ld [hl+], a
            ld a, [de]
            inc hl
            ld [hl], a
            pop hl
            ld a, [hl]                      ; magicians: MP
            pop bc
            cp 3
            jr c, .nmp
            cp 6
            jr nc, .nmp
            ld a, c
            rrca
            rrca
            add a, $20
            ld l, a
            ld h, high(ch_magic)
            ld [hl], 2                      ; current level-1 MP
            ld a, l
            add a, 8
            ld l, a
            ld [hl], 2                      ; max
.nmp:       inc c
            ld a, c
            cp 4
            jp c, .m
            ret

section wram, $CD00
scr_t0:     ds 1
scr_t1:     ds 1
ng_cur:     ds 1
pg_mem:     ds 1
pg_t:       ds 1
pg_class:   ds 4
pg_names:   ds 24
pg_nb:      ds 8
pg_row:     ds 24
ni_len:     ds 1
ni_x:       ds 1
ni_y:       ds 1
scr_buf:    ds 32
cur_tbl:    ds 8
cls_pal:    ds 12
sf_row:     ds 1
section wram, $D400
smap:       ds 18 * 32                      ; the screen's map copy (attributes at + $300)
section wram, $D700
sattr:      ds 18 * 32
