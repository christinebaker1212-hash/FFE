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
scr_open:   call lcd_off                    ; (LCD off in V-Blank, interrupts off)
.off:       xor a
            ld [box_on], a
            ld [sfx_nmode], a               ; (no ship / airship noise; menu sounds on)
            ldh [scx], a
            ldh [scy], a
            ld a, 18
            ld [sf_row], a
            ld [sfx_menu], a
            call sgb_menu
            ld hl, smap                     ; the map copy: blank (code $20), window attributes
            ld b, 18
            ld a, $20
            call fill32
            ld hl, sattr                    ; (outside the windows: black, as FF1's screens)
            ld b, 18
            ld a, BLK_ATTR
            call fill32
            ld hl, $9800                    ; VRAM map: blank
            ld b, 32
            ld a, $20
            call fill32
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
            ld b, 32
            ld a, BLK_ATTR
            call fill32
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
            call bgp_w
            ld a, DMG_OBP_BLK               ; (the screens' black windows: ranks 1-3 white,
            call obp0_w                     ;   light grey, dark grey)
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
            ld b, 18
            ld a, $20
            call fill32
            ld hl, sattr
            ld b, 18
            ld a, BLK_ATTR
            jp fill32
; the whole screen in the window colours (screens without a frame: name entry, prologue)
scr_allwin: ld hl, sattr
            ld b, 18
            ld a, WIN_ATTR
            jp fill32

; the map copy to VRAM: with the LCD off all of it and the LCD on; with the LCD on in the
; next frames' V-Blanks (scr_frame)
scr_show:   call lcd_get  
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
            jp lcd_on
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
            add hl, hl                      ; x 2, then x 256: x 512 (32 tiles of 16 bytes)
            ld a, l
            ld l, 0
            ld h, a
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
            push bc                         ; its cells in the window colours
            push de
            call cell_addr
            ld a, h
            add a, 3                        ; (attributes at + $300)
            ld h, a
.ar:        push hl
            ld b, d
            ld a, WIN_ATTR
.ac:        ld [hl+], a
            dec b
            jr nz, .ac
            pop hl
            ld a, l
            add a, 32
            ld l, a
            jr nc, .an
            inc h
.an:        dec e
            jr nz, .ar
            pop de
            pop bc
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
ng_main:    call save_state                 ; a damaged save: Lot Check's error message, erased
            cp 2                            ;   only after the A Button
            jr nz, .sok
            call scr_open
            xor a
            ld [sfx_menu], a
            ld bc, $0003
            ld de, $140C
            call scr_win
            ld bc, $0105
            ld hl, str_saverr
            call scr_str
            call scr_show
.se:        call scr_frame
            ldh a, [pad_new]
            bit 0, a
            jr z, .se
            call save_erase
.sok:       ldh a, [soft_rst]               ; the prologue first (not after a soft reset)
            and a
            jr nz, .np
            call pro_show
.np:        ld a, TR_MINIMAP                ; FF1 IntroTitlePrepare: the crystal theme
            call snd_track
            call scr_open
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
            call .rate
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
            and $C0                         ; up / down: Continue <-> New Game (FF1: the select
            jr z, .lr                       ;   sound)
            ld a, [ng_cur]
            xor 1
            ld [ng_cur], a
            ld a, SFX_SEL
            ld [sfx_req], a
            jr .t
.lr:        ld a, b                         ; left / right: FF1's respond rate 1-8 (battle
            and $30                         ;   messages' wait)
            jr z, .ab
            ld a, [respond]
            bit 4, b
            jr z, .lf
            inc a
            jr .rs
.lf:        dec a
.rs:        and 7
            ld [respond], a
            call .rate
            call scr_upd
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
.rate:      ld a, [respond]                 ; the rate's digit after "Message Speed"
            add a, FONT_D0 + 1
            ld hl, smap + 12 * 32 + 18
            ld [hl], a
            ret

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
name_buf:   push bc                         ; (keeps BC: the callers' text position)
            ld a, [pg_t]
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
            pop bc
            ret

; name entry (the approved layout: the grid 10 x 9, two columns / rows apart; the name on
; the top row): A adds the letter, B removes the last (on an empty name: C, back), Start
; finishes (at least one letter); six letters finish too
name_input: call scr_open
            call scr_allwin
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
            call lcd_get  
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

section bank 2, $7500                       ; (the prologue, party creation)

; ---- the prologue as FF1's EnterIntroStory: the crystal theme; a blue screen; the lines
; fade in one at a time, each over 64 frames (the colour stepping $00, $10, $20, $30 every 16
; frames, flickering every other frame with the shade below: $01 blue under $00); A / B
; finishes the line at once; when a page is shown, A / B goes on (after the last page: the
; title); Start goes to the title at any time. Two pages (the GB's 18 rows). Colour: per line
; palettes (2 shown, 3 waiting, 4 fading); DMG / SGB: a line is drawn when it starts and its
; scanlines get the fading shade by BGP (the raster list in BGP mode).
pro_show:   ld a, TR_MINIMAP
            call snd_track
            ld hl, pr_nes                   ; the five colours (COMMON's NES table)
            ld de, pr_rgb
.cc:        ld a, [hl+]
            push hl
            push de
            add a, a
            ld l, a
            ld h, 0
            ld bc, C_NESRGB
            add hl, bc
            ld bc, 2
            ld a, COMMON
            call far_copy
            pop de
            inc de
            inc de
            pop hl
            ld a, l
            cp low(pr_nes + 5)
            jr nz, .cc
            xor a
            ld [st_pg], a
.page:      call scr_open
            xor a
            ld [sfx_menu], a
            ld hl, sattr                    ; every cell: the waiting palette
            ld b, 18
            ld a, $0B
            call fill32
            ld a, [st_pg]                   ; the page's text (menu text bank $7000)
            add a, a
            ld l, a
            ld h, $70
            ld de, scr_buf
            ld bc, 2
            ld a, MTEXT
            call far_copy
            ld a, [scr_buf]
            ld l, a
            ld a, [scr_buf + 1]
            ld h, a
            ld de, mtxt
            ld bc, 200
            ld a, MTEXT
            call far_copy
            ld hl, mtxt                     ; lines -> the first row: centred
            ld c, 1
.cn:        ld a, [hl+]
            and a
            jr z, .cd
            cp $0A
            jr nz, .cn
            inc c
            jr .cn
.cd:        ld a, c
            ld [pr_nl], a
            ld a, 18
            sub c
            srl a
            ld [pr_row0], a
            ldh a, [is_cgb]                 ; Colour: every line drawn now (waiting palette)
            and a
            jr z, .np
            xor a
.dl:        ld [pr_i], a
            call pr_line
            ld a, [pr_i]
            inc a
            ld hl, pr_nl
            cp [hl]
            jr c, .dl
.np:        ld a, $80 | 16                  ; Colour palettes 2 (shown), 3 (waiting), 4 (fading)
            call bcps_w
            ld hl, pr_rgb                   ; 2: $01 $01 $01 $30
            call .c3
            ld hl, pr_rgb + 8
            call .c1
            ld b, 4                         ; 3: all $01
.p3:        ld hl, pr_rgb
            call .c1
            dec b
            jr nz, .p3
            ld hl, pr_rgb                   ; 4: $01 $01 $01 $01 (its colour 3 animated)
            call .c3
            ld hl, pr_rgb
            call .c1
            call scr_show
            xor a
            ld [pr_i], a
.ln:        call pr_lptr                    ; (an empty line: nothing to fade)
            jp z, .nx
            ld a, [pr_i]
            ld hl, pr_row0
            add a, [hl]
            ld [pr_row], a
            ldh a, [is_cgb]
            and a
            jr nz, .lc
            call pr_line                    ; DMG: drawn now, its scanlines black (BGP)
            ld a, [pr_row]
            add a, a
            add a, a
            add a, a
            ld hl, ly_tab
            ld [hl+], a
            ld [hl], %11100111
            inc hl
            add a, 8
            ld [hl+], a
            ld [hl], %11100100
            ld a, %11100100
            ld [ly_rst], a
            ld a, LCDC_ON
            ld [ly_base], a
            ld a, 1
            ld [ly_bgp], a
            ld a, 2
            ld [ly_n], a
            call scr_frame
            ld a, [pr_row]
            call sf_one
            jr .an0
.lc:        call scr_frame                  ; Colour: the line to the fading palette
            ld a, $0C
            call pr_rattr
.an0:       xor a
            ld [pr_cnt], a
.an:        call scr_frame
            ldh a, [pad_new]
            bit 3, a
            jp nz, .quit
            and 3
            jr nz, .dn
            ld a, [pr_cnt]                  ; the colour: step = cnt / 16, the shade below on
            ld b, a                         ;   odd frames
            swap a
            and 3
            inc a                           ; (main: index step + 1)
            bit 0, b
            jr z, .mc
            dec a                           ; (sub: the shade below; step 0: $01 blue)
.mc:        ld c, a
            ldh a, [is_cgb]
            and a
            jr z, .dm
            ld a, c                         ; Colour: palette 4 colour 3
            add a, a
            add a, low(pr_rgb)
            ld l, a
            ld h, high(pr_rgb)
            ld a, $80 | 38
            ldh [rBCPS], a
            ld a, [hl+]
            ldh [rBCPD], a
            ld a, [hl]
            ldh [rBCPD], a
            jr .ai
.dm:        ld a, c                         ; DMG: the text shade (colour 0) of the line
            ld hl, pr_shade
            add a, l
            ld l, a
            jr nc, .ds
            inc h
.ds:        ld a, [hl]
            or %11100100 & $FC
            ld [ly_tab + 1], a
.ai:        ld hl, pr_cnt
            inc [hl]
            ld a, [hl]
            cp 64
            jr c, .an
.dn:        ldh a, [is_cgb]                 ; the line shown
            and a
            jr z, .dd
            call scr_frame
            ld a, $0A
            call pr_rattr
            jr .nx
.dd:        call pr_lyoff
.nx:        ld a, [pr_i]
            inc a
            ld [pr_i], a
            ld hl, pr_nl
            cp [hl]
            jp c, .ln
.w:         call scr_frame                  ; the page shown: A / B on, Start: the title
            ldh a, [pad_new]
            bit 3, a
            jr nz, .quit
            and 3
            jr z, .w
            ld hl, st_pg
            inc [hl]
            ld a, [hl]
            cp STORY_FIRST
            jp c, .page
            ret
.quit:      jp pr_lyoff
.c3:        ld b, 3                         ; colour at HL three times, then (.c1) once
.c3l:       call .c1
            dec b
            jr nz, .c3l
            ret
.c1:        push hl
            ld a, [hl+]
            call bcpd_w
            ld a, [hl]
            call bcpd_w
            pop hl
            ret

; DMG: the raster list off, BGP as normal
pr_lyoff:   ldh a, [is_cgb]
            and a
            ret nz
            xor a
            ld [ly_bgp], a
            call ly_off
            ld a, %11100100
            jp bgp_w

; Colour: the attributes of row pr_row (VRAM bank 1, in V-Blank) and its copy = A
pr_rattr:   ld b, a
            ld a, [pr_row]                  ; HL = $9800 + 32 row, DE = sattr + 32 row
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            push hl
            ld de, sattr
            add hl, de
            ld d, h
            ld e, l
            pop hl
            ld a, h
            add a, $98
            ld h, a
            ld a, 1
            ldh [rVBK], a
            ld c, 20
.l:         ld a, b
            ld [hl+], a
            ld [de], a
            inc de
            dec c
            jr nz, .l
            xor a
            ldh [rVBK], a
            ret

; HL = the start of line pr_i of mtxt; Z if the line is empty
pr_lptr:    ld hl, mtxt
            ld a, [pr_i]
            and a
            jr z, .t
            ld b, a
.s:         ld a, [hl+]
            cp $0A
            jr nz, .s
            dec b
            jr nz, .s
.t:         ld a, [hl]
            and a
            ret z
            cp $0A
            ret

; line pr_i into the map copy, centred on row pr_row0 + pr_i
pr_line:    call pr_lptr
            ret z
            ld de, pg_row
            ld b, 0
.c:         ld a, [hl+]
            and a
            jr z, .e
            cp $0A
            jr z, .e
            ld [de], a
            inc de
            inc b
            jr .c
.e:         xor a
            ld [de], a
            ld a, 20
            sub b
            srl a
            ld b, a
            ld a, [pr_i]
            ld hl, pr_row0
            add a, [hl]
            ld c, a
            ld hl, pg_row
            jp scr_str

pr_nes:     db $01, $00, $10, $20, $30      ; FF1's intro colours (index 0 = the blue)
pr_shade:   db 3, 2, 1, 0, 0                ; ... as DMG shades of the text

; party generation (owner's design, 2026-11-21): the four boxes start as FF1's default party
; (Warrior, Thief, Monk, Red Magician), no names; the Control Pad moves between them; A on a
; member opens the job list (every job, its name and picture), then its name entry (B there:
; back to the jobs; B in the jobs: back to the boxes). When all four have names: OK to begin
; with this party? Yes starts the game, No puts everything back to the default, B returns
; to the boxes.
party_gen:
.reset:     ld hl, pg_class
            xor a
.dc:        ld [hl+], a                     ; classes 0, 1, 2, 3
            inc a
            cp 4
            jr c, .dc
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
            ld b, 1
            and $30                         ; left / right: the other column
            jr nz, .mv
            ldh a, [pad_new]
            ld b, 2
            and $C0                         ; up / down: the other row
            jr z, .ml
.mv:        ld a, [pg_mem]
            xor b
            ld [pg_mem], a
            jr .ml
.a:         ld a, [pg_mem]                  ; the member's class kept (a cancel restores it)
            ld l, a
            ld h, 0
            ld de, pg_class
            add hl, de
            ld a, [hl]
            ld [pg_old], a
.job:       call job_select
            jr c, .mem                      ; (B: back to the boxes)
            call name_input
            jr nc, .named
            jr .job                         ; (B on an empty name: back to the jobs)
.named:     call pg_all
            jr nz, .mem
            call pg_screen                  ; all four named: the question
            call pg_ask
            jr c, .mem                      ; (B: back to the boxes)
            and a
            jr nz, .reset                   ; No: everything back to the default
            ret                             ; Yes

; Z if all four members have a name (first letter not blank), NZ if one has none
pg_all:     ld hl, pg_names
            ld b, 4
.l:         ld a, [hl]
            cp $20
            jr z, .no
            ld a, l
            add a, 6
            ld l, a
            jr nc, .c
            inc h
.c:         dec b
            jr nz, .l
            xor a                           ; all named: Z
            ret
.no:        or a                            ; (A = $20: NZ)
            ret

; the question over the boxes: OK to begin with this party? Yes / No; returns A = 0 Yes,
; 1 No (NC), C on B
pg_ask:     ld hl, oam_buf + 16             ; (the class sprites hidden under the window)
            ld b, 24 * 4
            xor a
.h:         ld [hl+], a
            dec b
            jr nz, .h
            ld bc, $0105
            ld de, $1208
            call scr_win
            ld bc, $0306
            ld hl, str_pgok
            call scr_str
            ld bc, $0609
            ld hl, str_pgyes
            call scr_str
            ld bc, $0D09
            ld hl, str_pgno
            call scr_str
            call scr_upd
            xor a
            ld [pg_t], a
.l:         ld a, [pg_t]                    ; the hand left of Yes / No
            and a
            ld b, 4 * 8 - 4
            jr z, .x
            ld b, 11 * 8 - 4
.x:         ld c, 9 * 8 - 4
            call scr_cursor
            call scr_frame
            ldh a, [pad_new]
            bit 0, a
            jr nz, .a
            bit 1, a
            jr nz, .b
            and $30
            jr z, .l
            ld a, [pg_t]
            xor 1
            ld [pg_t], a
            jr .l
.a:         ld a, [pg_t]
            and a                           ; NC
            ret
.b:         scf
            ret

; the job list (every job: its picture and name, two columns of three): the cursor starts on
; the member's job; A picks it (NC, the member's class set), B cancels (C, the class back)
job_select: call scr_open
            xor a
            call scr_classes                ; the six jobs' pictures: sprite tiles 0-35
            ld bc, $0000
            ld de, $1412
            call scr_win
            xor a
.e:         ld [pg_t], a                    ; job j: column j & 1, row j >> 1
            call job_xy                     ; B = the name's column, C = the row of its picture
            push bc
            ld a, c                         ; the name below the picture (one or two lines)
            add a, 3
            ld c, a
            ld a, [pg_t]
            call class_str
            call scr_str
            pop bc
            ld a, [pg_t]                    ; the picture: cells (name + 2 .. + 3, row .. + 2)
            ld e, a
            ld d, 0
            ld hl, cls_pal
            add hl, de
            ld a, [hl]
            ld [scr_t0], a
            ld a, b
            add a, 2
            add a, a
            add a, a
            add a, a
            ld b, a
            ld a, c
            add a, a
            add a, a
            add a, a
            ld c, a
            ld a, [pg_t]                    ; OAM entries 4 + 6 j
            ld e, a
            add a, a
            add a, e
            add a, a
            push af
            add a, 4
            ld e, a
            pop af                          ; tile base 6 j
            call scr_spr23
            ld a, [pg_t]
            inc a
            cp 6
            jr c, .e
            call scr_show
            ld a, [pg_mem]                  ; the cursor on the member's job
            ld l, a
            ld h, 0
            ld de, pg_class
            add hl, de
            ld a, [hl]
            ld [pg_t], a
.l:         ld a, [pg_t]                    ; the hand left of the picture
            call job_xy
            ld a, b
            add a, a
            add a, a
            add a, a
            sub 4
            ld b, a
            ld a, c
            inc a
            add a, a
            add a, a
            add a, a
            ld c, a
            call scr_cursor
            call scr_frame
            ldh a, [pad_new]
            bit 0, a
            jr nz, .a
            bit 1, a
            jr nz, .b
            ld hl, pg_t
            ld b, a
            and $30                         ; left / right: the other column
            jr z, .ud
            ld a, [hl]
            xor 1
            ld [hl], a
            jr .l
.ud:        ld a, b
            bit 6, a                        ; up: the row above (wrapping)
            jr z, .dn
            ld a, [hl]
            sub 2
            jr nc, .s
            add a, 6
            jr .s
.dn:        bit 7, a
            jr z, .l
            ld a, [hl]
            add a, 2
            cp 6
            jr c, .s
            sub 6
.s:         ld [hl], a
            jr .l
.a:         ld a, [pg_mem]
            ld l, a
            ld h, 0
            ld de, pg_class
            add hl, de
            ld a, [pg_t]
            ld [hl], a
            and a                           ; NC
            ret
.b:         ld a, [pg_mem]                  ; (the class as it was)
            ld l, a
            ld h, 0
            ld de, pg_class
            add hl, de
            ld a, [pg_old]
            ld [hl], a
            scf
            ret

; A = job -> B = its name's column (2 / 11), C = its picture's top row (1, 6, 11)
job_xy:     ld b, 2
            bit 0, a
            jr z, .c
            ld b, 11
.c:         srl a
            ld c, a
            add a, a
            add a, a
            add a, c                        ; 5 x row
            inc a
            ld c, a
            ret


section wram, $CD00
scr_t0:     ds 1
scr_t1:     ds 1
ng_cur:     ds 1
pg_mem:     ds 1
pg_t:       ds 1
pg_class:   ds 4
pg_old:     ds 1
pr_rgb:     ds 10                           ; the prologue's colours (RGB555)
pr_nl:      ds 1
pr_row0:    ds 1
pr_row:     ds 1
pr_i:       ds 1
pr_cnt:     ds 1
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
