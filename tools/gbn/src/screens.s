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
scr_open:   call fade_out                   ; (the screen before faded out)
            call lcd_off                    ; (LCD off in V-Blank, interrupts off)
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

; the hand (OAM 0-3) hidden; registers but A kept
hand_hide:  xor a
            ld [oam_buf], a
            ld [oam_buf + 4], a
            ld [oam_buf + 8], a
            ld [oam_buf + 12], a
            ret
oam_clr:    ld hl, oam_buf
            ld b, 160
            xor a
.o:         ld [hl+], a
            dec b
            jr nz, .o
            ret

; the map copy cleared (blank, window attributes) with the LCD on
scr_cls:    xor a                           ; (the gradient's windows: drawn again)
            ld [gr_wn], a
            call oam_clr
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
scr_show:   call gr_build                   ; (the windows' gradient: loc.s)
            call lcd_get  
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
            ld a, 1                         ; (faded in)
            ld [fd_in], a
            ld a, LCDC_ON
            call lcd_on
            jp fade_in
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
sf_step:    ld a, [tw_qh]                   ; (a typed letter: its cell first)
            and a
            jr z, .rw
            ldh a, [rLY]
            cp 144
            jr c, .rw
            cp 152
            jr nc, .rw
            ld a, [tw_ql]
            ld l, a
            ld a, [tw_qh]
            ld h, a
            ld a, [tw_qt]
            ld [hl], a
            xor a
            ld [tw_qh], a
.rw:        ld a, [sf_row]
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
scr_win:    call gr_reg                     ; (the gradient's windows: loc.s)
            push de
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
; the hand pointing at text that starts at column B of row C (owner, 2026-11-22: one rule for
; every cursor): the fingertip (the hand's column 15) 2 pixels before the first letter, the
; finger (rows 2-5) level with the letters; cut off at the screen's left edge when it must be
cur_txt:    ld de, oam_buf
cur_tde:    ld a, b                         ; x = 8 B - 17, y = 8 C
            add a, a
            add a, a
            add a, a
            sub 17
            ld b, a
            ld a, c
            add a, a
            add a, a
            add a, a
            ld c, a
            jr scr_cur_de
; the same hand in OAM 4-7 (a second hand: the choice made, while another is picked)
cur_txt2:   ld de, oam_buf + 16
            jr cur_tde
scr_cursor: ld de, oam_buf
scr_cur_de: ld hl, cur_tbl
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
scr_frame:  ld a, [gr_dirty]                ; (a window since the screen showed: the gradient
            and a                           ;   again)
            call nz, gr_build
            ld a, [sf_row]                  ; (owner, 2026-11-22: no hand while a window is
            cp 18                           ;   still going up: it shows once the screen is
            call c, hand_hide               ;   whole, never over the old one)
            call wait_vbl
            call sf_step
            ld a, [scr_mus]                 ; (FF1 MenuFrame / the shops: the music again
            and a                           ;   when a jingle has ended it)
            jr z, .p
            ld b, a
            ld a, [NES_RAM + $4B]
            bit 7, a
            jr z, .p
            ld a, b
            call snd_track
.p:         jp read_pad

section bank 2, $4000

; ---- new game: title menu, party generation
ng_main:    call sv_boot                    ; a damaged file: Lot Check's error message, erased
.sok:       call sus_state                  ; a damaged suspend point: the same
            cp 2
            jr nz, .uok
            call scr_open
            ld bc, $0003
            ld de, $140C
            call scr_win
            ld bc, $0105
            ld hl, str_suserr
            call scr_str
            call scr_show
.ue:        call scr_frame
            ldh a, [pad_new]
            bit 0, a
            jr z, .ue
            call sus_erase
.uok:       xor a
            ld [sus_res], a
            ldh a, [soft_rst]               ; the prologue first (not after a soft reset)
            and a
            jr nz, .np
            call pro_show
.np:        ld a, TR_MINIMAP                ; FF1 IntroTitlePrepare: the crystal theme
            call snd_track
            call scr_open
            ld b, 4                         ; title menu (the GB layout: three boxes, centred:
            ld c, 5                         ;   owner, 2026-11-22)
            ld d, 12
            ld e, 3
            call scr_win
            ld c, 8
            call scr_win
            ld b, 1
            ld c, 11
            ld d, 18
            call scr_win
            ld bc, $0606
            ld hl, str_title0
            call scr_str
            ld bc, $0609
            ld hl, str_title1
            call scr_str
            ld bc, $030C
            ld hl, str_title2
            call scr_str
            call .rate
            call eqm_pal                    ; (Color: the grey of a closed choice)
            call ng_cont                    ; a save or a suspend point: Continue first
            ld a, 0
            jr nc, .sv
            ld hl, smap + $300 + 6 * 32 + 5 ; (nothing to continue: Continue grey, the
            ld b, 10                        ;   hand stays on New Game)
.gy:        ld [hl], $0C
            inc hl
            dec b
            jr nz, .gy
            ld a, 1
.sv:        ld [ng_cur], a
            ld [ng_lock], a
            call scr_show
.t:         ld a, [ng_cur]                  ; the hand at Continue (row 6) / New Game (9),
            ld c, a                         ;   column 8
            add a, a
            add a, c
            add a, 6
            ld c, a
            ld b, 6
            call cur_txt
            call scr_frame
            ldh a, [pad_new]
            ld b, a
            and $C0                         ; up / down: Continue <-> New Game (FF1: the select
            jr z, .lr                       ;   sound)
            ld a, [ng_lock]
            and a
            jr nz, .t
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
            call opt_save0                  ; (the message speed kept, as in Options)
            ld a, [ng_cur]
            and a
            jr nz, .new
            call sus_state                  ; Continue: a suspend point first
            dec a
            jr nz, .cs
            ld hl, str_susc1                ; Continue from Suspend point?
            ld a, 2
            ld d, 0
            call sus_ask
            and a
            jr nz, .cn
            call sus_load                   ; Yes: the point (erased) and the map
            ld a, 1
            ld [sus_res], a
            ret
.cn:        call sv_any                     ; No: with a save, Continue from last save?
            jp c, .np                       ;   The suspend point will be lost!
            ld hl, str_susc2
            ld a, 4
            ld d, 1
            call sus_ask
            and a
            jp nz, .np
            call file_load                  ; (which file: loc.s)
            jp c, .np
            jp sus_erase
.cs:        call sv_any                     ; a saved game: which file (loc.s)
            jp c, .t
            call file_load
            jp c, .np
            ret
.new:       call party_gen
            call ng_stats
            ret
.rate:      ld a, [respond]                 ; the rate's digit after Message Speed
            add a, FONT_D0 + 1
            ld hl, smap + 12 * 32 + 17
            ld [hl], a
            ret

; NC: something to continue (a save, or a good suspend point)
ng_cont:    call sv_any
            ret nc
            call sus_state
            dec a
            ret z
            scf
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
.m:         call pg_box_xy                  ; the hand at the job's picture (box + 4, its
            ld a, b                         ;   middle row + 2)
            add a, 4
            ld b, a
            inc c
            inc c
            jp cur_txt

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

; name entry (owner, 2026-11-22: in windows as the other screens; one case at a time):
; top (0,0,20,5) the job's picture, its name, Select: abc / ABC, the name being written; the
; letters (0,4,20,14): the case's 26 (rows 6, 8, 10) and the digits and signs (rows 12, 14,
; 16), nine a row at columns 2 + 2 x; Select switches capitals / small letters; the cursor
; the hand's finger (8 x 8, it fits the column between two letters). A adds the letter, B
; removes the last (on an empty name: C, back), Start finishes (at least one letter); six
; letters finish too
name_input: call scr_open
            ld bc, $0000
            ld de, $1405
            call scr_win
            ld bc, $0004
            ld de, $140E
            call scr_win
            ld a, [pg_mem]                  ; the job: its picture and name
            ld e, a
            ld d, 0
            ld hl, pg_class
            add hl, de
            ld a, [hl]
            ld [eqm_cls], a
            call scr_classes
            ld a, [eqm_cls]
            ld e, a
            ld d, 0
            ld hl, cls_pal
            add hl, de
            ld a, [hl]
            ld [scr_t0], a
            ld bc, $0808
            ld e, 4
            xor a
            call scr_spr23
            ld bc, $0401
            call pen_at
            ld a, [eqm_cls]
            add a, a
            ld e, a
            ld d, 0
            ld hl, cname_ptrs
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            call pen_str
            xor a
            ld [ni_case], a
            call ni_grid
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
.lp:        call ni_cur
            call scr_frame
            ldh a, [pad_new]
            bit 0, a
            jr nz, .a
            bit 1, a
            jp nz, .b
            bit 3, a
            jp nz, .st
            bit 2, a
            jr z, .ns
            ld a, [ni_case]                 ; Select: the other case
            xor 1
            ld [ni_case], a
            call ni_grid
            call scr_upd
            jr .lp
.ns:        ld hl, ni_x                     ; (6 columns, 10 rows: owner, 2026-11-23, the
            bit 4, a                        ;   whole hand before each letter)
            jr z, .nr
            ld a, [hl]
            inc a
            cp 6
            jr c, .sx
            xor a
.sx:        ld [hl], a
            jr .lp
.nr:        bit 5, a
            jr z, .nl
            ld a, [hl]
            dec a
            cp 6
            jr c, .sx
            ld a, 5
            jr .sx
.nl:        ld hl, ni_y
            bit 6, a
            jr z, .nu
            ld a, [hl]
            dec a
            cp 10
            jr c, .sy
            ld a, 9
.sy:        ld [hl], a
            jr .lp
.nu:        bit 7, a
            jr z, .lp
            ld a, [hl]
            inc a
            cp 10
            jr c, .sy
            xor a
            jr .sy
.a:         ld a, [ni_y]                    ; the letter at (x, y)
            ld b, a
            ld a, [ni_x]
            call ni_char
            ld c, a
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

; A = the symbol at column A (0-5), row B (0-9): rows 0-4 the case's 27 letters, rows 5-9 the
; 27 signs, six a row (blanks: a space); FF1's grid strings hold them nine a row
ni_char:    ld c, a
            ld a, b
            cp 5
            jr c, .l
            sub 5
            ld b, a
            ld e, 6                         ; (signs: grid rows 6-8)
            jr .k
.l:         ld a, [ni_case]                 ; (letters: the case's grid rows)
            ld e, a
            add a, a
            add a, e
            ld e, a
.k:         ld a, b                         ; k = 6 row + column
            add a, a
            add a, b
            add a, a
            add a, c
            cp 27
            ld a, $20
            ret nc
            ld a, b
            add a, a
            add a, b
            add a, a
            add a, c
            ld c, 0                         ; grid row e + k / 9, column k mod 9
.d:         cp 9
            jr c, .m
            sub 9
            inc c
            jr .d
.m:         ld b, a
            ld a, c
            add a, e
            add a, a
            ld l, a
            ld h, 0
            ld de, grid_ptrs
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld a, b
            add a, l
            ld l, a
            ld a, h
            adc a, 0
            ld h, a
            ld a, [hl]
            ret
; the ten rows of symbols (rows 6-15, columns 3, 6, .. 18) and the Select hint
ni_grid:    xor a
.g:         push af
            ld d, a                         ; (D = the row)
            ld hl, pg_row
            xor a
.x:         push af
            push hl
            push de
            ld c, a
            ld b, d
            ld a, c
            call ni_char
            pop de
            pop hl
            ld [hl+], a
            pop af
            inc a
            cp 6
            jr nc, .e
            ld [hl], $20
            inc hl
            ld [hl], $20
            inc hl
            jr .x
.e:         ld [hl], 0
            pop af
            push af
            add a, 6
            ld c, a
            ld b, 3
            ld hl, pg_row
            call scr_str
            pop af
            inc a
            cp 10
            jr c, .g
            ld bc, $0402                    ; Select: the other case
            ld hl, str_nisel
            ld a, [ni_case]
            and a
            jr z, .h
            ld hl, str_nisel2
.h:         jp scr_str

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
            ld bc, $0403
            call lcd_get  
            bit 7, a
            jp z, scr_str
            jp scr_str_on

; the grid's cursor: the whole hand, its fingertip before the letter (cur_txt)
ni_cur:     ld a, [ni_x]
            ld b, a
            add a, a
            add a, b
            add a, 3
            ld b, a
            ld a, [ni_y]
            add a, 6
            ld c, a
            jp cur_txt

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

; ---- Suspend (as the recompiled build): a suspend point in cart RAM bank 1 (FF1S, the
; field's state, a 16-bit sum), kept with the power off, erased when the game is resumed.
; Lot Check: cart RAM enabled only while it is read or written.
SUS_MARK   = $A000
sus_blk:    dw px, o_tb + 1 - px            ; position, map, floors, objects' state
            dw objs, 16 * 15
            dw vehicle, 8
            dw unsram, $400                 ; the save page, the party, flags, magic
            dw bt_rngs, 1
            dw maptype, 1
            dw 0
sus_on:     ld a, $0A
            ld [$0000], a
            ld a, 1
            ld [$4000], a
            ret
sus_off:    push af
            xor a
            ld [$0000], a
            ld [$4000], a
            pop af
            ret
; the blocks <-> cart RAM from sus_cp: A = 0 write, 1 read, 2 only the sum; BC = the sum
sus_copy:   ld [sus_dir], a
            ld bc, 0
            ld hl, sus_blk
.e:         ld a, [hl+]
            ld e, a
            ld a, [hl+]
            ld d, a
            or e
            ret z
            ld a, [hl+]
            ld [sus_n], a
            ld a, [hl+]
            ld [sus_n + 1], a
            push hl
            ld a, [sus_cp]
            ld l, a
            ld a, [sus_cp + 1]
            ld h, a
.c:         ld a, [sus_dir]
            and a
            jr nz, .rd
            ld a, [de]
            ld [hl], a
            jr .s
.rd:        dec a
            ld a, [hl]
            jr nz, .s
            ld [de], a
.s:         inc hl
            inc de
            add a, c
            ld c, a
            ld a, b
            adc a, 0
            ld b, a
            push hl
            ld hl, sus_n
            ld a, [hl]
            sub 1
            ld [hl+], a
            ld a, [hl]
            sbc a, 0
            ld [hl-], a
            or [hl]
            pop hl
            jr nz, .c
            ld a, l
            ld [sus_cp], a
            ld a, h
            ld [sus_cp + 1], a
            pop hl
            jr .e
sus_cp0:    ld a, low(SUS_MARK + 4)
            ld [sus_cp], a
            ld a, high(SUS_MARK + 4)
            ld [sus_cp + 1], a
            ret
sus_end:    ld a, [sus_cp]                  ; HL = the sum's place
            ld l, a
            ld a, [sus_cp + 1]
            ld h, a
            ret
; the suspend point made
sus_write:  call sus_on
            ld hl, SUS_MARK
            ld a, $46
            ld [hl+], a
            ld [hl+], a
            ld a, $31
            ld [hl+], a
            ld a, $53
            ld [hl], a
            call sus_cp0
            xor a
            call sus_copy
            call sus_end
            ld [hl], c
            inc hl
            ld [hl], b
            jp sus_off
; A = 0 none, 1 good, 2 damaged (the mark, a wrong sum)
sus_state:  call sus_on
            ld hl, SUS_MARK
            ld a, [hl+]
            cp $46
            jr nz, .no
            ld a, [hl+]
            cp $46
            jr nz, .no
            ld a, [hl+]
            cp $31
            jr nz, .no
            ld a, [hl]
            cp $53
            jr nz, .no
            call sus_cp0
            ld a, 2
            call sus_copy
            call sus_end
            ld a, [hl+]
            cp c
            jr nz, .bad
            ld a, [hl]
            cp b
            jr nz, .bad
            ld a, 1
            jp sus_off
.bad:       ld a, 2
            jp sus_off
.no:        xor a
            jp sus_off
sus_erase:  call sus_on
            xor a
            ld hl, SUS_MARK
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl], a
            jp sus_off
; the suspend point back into the game (the title's message speed kept), then erased
sus_load:   ld a, [respond]
            push af
            call sus_on
            call sus_cp0
            ld a, 1
            call sus_copy
            call sus_off
            pop af
            ld [respond], a
            xor a                           ; (the frame's passing state cleared)
            ld [wp_req], a
            ld [wp_on], a
            ld [ly_n], a
            ld [pc_hold], a
            ld [shop_pend], a
            ld a, LCDC_ON
            ld [lcdc_on], a
            ld a, $FF
            ld [mt_force], a
            ld a, 1
            ld [pc_req], a
            jr sus_erase
; a question (HL, A lines) with Yes / No below, on its own screen; D = the choice first
; (0 Yes, 1 No) -> A = 0 Yes, 1 No (B: No)
sus_ask:    ld [sus_ln], a
            ld a, d
            ld [sus_k], a
            push hl
            call scr_open
            ld a, [sus_ln]                  ; height = lines + 4, centred
            add a, 4
            ld e, a
            ld a, 18
            sub e
            srl a
            ld [sus_top], a
            ld c, a
            ld b, 0
            ld d, 20
            call scr_win
            pop hl
            ld a, [sus_top]
            inc a
            ld c, a
            ld b, 1
            call scr_str
            ld a, [sus_top]
            ld hl, sus_ln
            add a, [hl]
            add a, 2
            ld [sus_yr], a
            ld c, a
            ld b, 6
            ld hl, str_pgyes
            call scr_str
            ld a, [sus_yr]
            ld c, a
            ld b, 13
            ld hl, str_pgno
            call scr_str
            call scr_show
.l:         ld a, [sus_k]
            and a
            ld b, 6
            jr z, .x
            ld b, 13
.x:         ld a, [sus_yr]
            ld c, a
            call cur_txt
            call scr_frame
            ldh a, [pad_new]
            bit 0, a
            jr nz, .a
            bit 1, a
            jr nz, .b
            and $F0
            jr z, .l
            ld a, [sus_k]
            xor 1
            ld [sus_k], a
            ld a, SFX_SEL
            ld [sfx_req], a
            jr .l
.a:         ld a, [sus_k]
            ret
.b:         ld a, 1
            ret
; the main menu's Suspend: asked (No first); Yes: the point made, the title
sus_menu:   ld hl, str_susq
            ld a, 7
            ld d, 1
            call sus_ask
            and a
            ret nz
            call sus_write
            jp game_over

zz_end_4000:
section bank 2, $5F00                       ; (the prologue's colour fade)
; Colour: palette 4 colour 3 = blue (pr_rgb 0) + (white (pr_rgb 4) - blue) x pr_cnt / 32, per
; channel (the prologue's fading line)
pr_cgbstep: ld hl, pr_rgb
            call pr_split
            ld hl, pr_cc
            ld [hl+], a
            ld a, d
            ld [hl+], a
            ld [hl], e
            ld hl, pr_rgb + 8
            call pr_split                   ; A, D, E = white's R, G, B
            ld hl, pr_cc + 3
            ld [hl+], a
            ld a, d
            ld [hl+], a
            ld [hl], e
            ld c, 0                         ; each channel
.ch:        ld hl, pr_cc
            ld b, 0
            add hl, bc
            ld d, [hl]                      ; D = from
            inc hl
            inc hl
            inc hl
            ld a, [hl]
            sub d                           ; A = to - from (>= 0: blue to white)
            jr nc, .p
            xor a
.p:         ld e, a
            push bc
            ld a, [pr_cnt]
            ld b, a
            ld hl, 0
            ld a, b
            and a
            jr z, .m0
.mu:        ld a, l                         ; HL = delta x cnt
            add a, e
            ld l, a
            jr nc, .mn
            inc h
.mn:        dec b
            jr nz, .mu
.m0:        ld a, l                         ; / 32
            rlca
            rlca
            rlca
            and 7
            ld l, a
            ld a, h
            add a, a
            add a, a
            add a, a
            or l
            add a, d
            pop bc
            ld hl, pr_cc + 6
            ld b, 0
            add hl, bc
            ld [hl], a
            inc c
            ld a, c
            cp 3
            jr c, .ch
            ld a, [pr_cc + 7]               ; RGB555: R | G << 5 | B << 10
            ld b, a
            rrca
            rrca
            rrca
            and $E0
            ld hl, pr_cc + 6
            or [hl]
            ld c, a                         ; low byte
            ld a, b
            srl a
            srl a
            srl a
            ld b, a
            ld a, [pr_cc + 8]
            add a, a
            add a, a
            or b
            ld b, a                         ; high byte
            ld a, $80 | 38
            ldh [rBCPS], a
            ld a, c
            ldh [rBCPD], a
            ld a, b
            ldh [rBCPD], a
            ret
; RGB555 at HL -> A = R, D = G, E = B
pr_split:   ld a, [hl+]
            ld c, a
            ld b, [hl]
            ld a, b
            rrca
            rrca
            and $1F
            ld e, a
            ld a, c
            rlca
            rlca
            rlca
            and 7
            ld d, a
            ld a, b
            and 3
            add a, a
            add a, a
            add a, a
            or d
            ld d, a
            ld a, c
            and $1F
            ret
zz_end_5f00:

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
            call pr_first                   ; (the first page from power-on: white first)
            call scr_show
            call pr_first2
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
.an:        call scr_frame                  ; (owner, 2026-11-22: smoother, and A / B show the
            ldh a, [pad_new]                ;   whole page at once)
            bit 3, a
            jp nz, .quit
            and 3
            jp nz, .all
            ldh a, [is_cgb]
            and a
            jr z, .dm
            call pr_cgbstep                 ; Colour: blue to white in PR_LEN even steps
            jr .ai
.dm:        ld a, [pr_cnt]                  ; DMG: the shade step = cnt / 8, the next one on
            ld b, a                         ;   odd frames of a step's second half
            rrca
            rrca
            rrca
            and 3
            ld c, a
            bit 2, b
            jr z, .ms
            ldh a, [frame]
            and 1
            add a, c
            ld c, a
.ms:        ld a, c
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
            cp PR_LEN
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
            jr .w
.all:       ldh a, [is_cgb]                 ; A / B: this line and every one after it shown
            and a
            jr z, .ad
            call scr_frame
            ld a, $0A
            call pr_rattr
            jr .an1
.ad:        call pr_lyoff
.an1:       ld a, [pr_i]
            inc a
            ld [pr_i], a
            ld hl, pr_nl
            cp [hl]
            jr nc, .w
            call pr_lptr
            jr z, .an1
            ld a, [pr_i]
            ld hl, pr_row0
            add a, [hl]
            ld [pr_row], a
            ldh a, [is_cgb]
            and a
            jr z, .ad2
            call scr_frame                  ; (Colour: drawn already, the shown palette)
            ld a, $0A
            call pr_rattr
            jr .an1
.ad2:       call pr_line                    ; (DMG: drawn now, its row up in V-Blank)
            call scr_frame
            ld a, [pr_row]
            call sf_one
            jr .an1
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

; the first page on the Color fades in from the boot logo's white (bank 104: btl6.s)
pr_first:   ld hl, pr_wwhite
            jr pr_fcall
pr_first2:  ld hl, pr_wfade
pr_fcall:   ld a, [st_pg]
            and a
            ret nz
            ldh a, [is_cgb]
            and a
            ret z
            ld a, BTL6_BANK
            jp bank_call

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
PR_LEN     = 32                         ; frames a line takes to fade in

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
.l:         ld a, [pg_t]                    ; the hand at Yes / No (columns 6 / 13, row 9)
            and a
            ld b, 6
            jr z, .x
            ld b, 13
.x:         ld c, 9
            call cur_txt
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
.l:         ld a, [pg_t]                    ; the hand at the job's name (below its picture)
            call job_xy
            inc c
            inc c
            inc c
            call cur_txt
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



; ---- the equipment screen (owner, 2026-11-22: a modern Final Fantasy style with a Game Boy
; Color feel). Top (0,0,20,5): the member's picture, name, job, level; left / right: the
; next member. Middle (0,5,20,7): the five slots (weapon, body, shield, helmet, gloves: icon
; and name; an empty slot its type's icon and a dash). Bottom (0,12,20,6): Attack, Accuracy,
; Defense, Evasion. A on a slot: the middle window lists Remove (when equipped) and every
; unequipped item in the party's packs that fits the slot and the job; the bottom window shows
; old > new (Colour: green better, red worse); A equips: an item from another member's pack
; goes to this member, the one it replaces back into that pack (FF1's four weapons / four
; armour a member keep). FF1's records and stat rules: stats unadjusted while the screen
; is open (eq_unadj), sorted and readjusted when it closes.
eqm_main:   ld [eqm_m], a
            xor a
            ld [eqm_t], a
            ld [eqm_ot], a
            call eqm_unadj
.scr:       call eqm_draw
.l:         call eqm_ohand                  ; the hand left of the slot / Optimize (loc.s)
            call scr_frame
            ldh a, [pad_new]
            bit 1, a
            jp nz, .exit
            bit 0, a
            jr nz, .a
            ld hl, eqm_t
            bit 6, a
            jr nz, .up
            bit 7, a
            jr nz, .dn
            ld hl, eqm_m
            bit 4, a
            jr nz, .rt
            bit 5, a
            jr z, .l
            ld a, [hl]                      ; left: the member before
            dec a
            and 3
            ld [hl], a
            jr .scr
.rt:        ld a, [hl]
            inc a
            and 3
            ld [hl], a
            jr .scr
.up:        call eqm_oup                    ; (the rows in use and Optimize: loc.s)
            jr .l
.dn:        call eqm_odn
            jr .l
.a:         ld a, [eqm_ot]                  ; Optimize (owner, 2026-11-22)
            and a
            jr z, .list
            call eqm_opt
            jr .l
.list:      call eqm_cands
            ld a, [eqm_n]
            and a
            jr nz, .lo
            call sfx_err                    ; (nothing fits)
            jr .l
.lo:        xor a
            ld [eqm_c], a
            ld [eqm_top], a
.ld:        call eqm_ldraw
.lw:        ld a, [eqm_c]                   ; the hand left of the entry
            ld hl, eqm_top
            sub [hl]
            add a, 6
            call eqm_hand
            call scr_frame
            ldh a, [pad_new]
            bit 1, a
            jr nz, .back
            bit 0, a
            jr nz, .take
            ld hl, eqm_c
            bit 6, a
            jr nz, .lu
            bit 7, a
            jr z, .lw
            ld a, [eqm_n]                   ; down
            ld b, a
            ld a, [hl]
            inc a
            cp b
            jr c, .ls
            xor a
            jr .ls
.lu:        ld a, [hl]
            dec a
            cp $FF
            jr nz, .ls
            ld a, [eqm_n]
            dec a
.ls:        ld [hl], a
            ld hl, eqm_top                  ; (scrolled: five rows show)
            cp [hl]
            jr nc, .l1
            ld [hl], a
            jr .ld
.l1:        sub [hl]
            cp 5
            jr c, .ld
            ld a, [eqm_c]
            sub 4
            ld [hl], a
            jr .ld
.take:      call eqm_entry
            call eqm_apply
.back:      call eqm_sdraw                  ; the slots and the stats again
            call scr_upd
            ld a, [eqm_nr]                  ; (a row gone: the hand on the last)
            ld b, a
            ld a, [eqm_t]
            cp b
            jp c, .l
            ld a, b
            dec a
            ld [eqm_t], a
            jp .l
.exit:      xor a                           ; FF1: sorted, stats readjusted
            ld [eq_kind], a
            ld a, $18
            ld [eq_off], a
            call eq_sort
            call eq_readj
            ld a, 1
            ld [eq_kind], a
            ld a, $1C
            ld [eq_off], a
            call eq_sort
            jp eq_readj

; the hand at text row A (x 0, cut off at the screen's left edge)
eqm_hand:   ld c, a                         ; the hand at the entry (column 2, row A)
            ld b, 2
            jp cur_txt

eqm_unadj:  ld a, 1
            ld [eq_kind], a
            ld a, $1C
            ld [eq_off], a
            call eq_unadj
            xor a
            ld [eq_kind], a
            ld a, $18
            ld [eq_off], a
            jp eq_unadj

; the whole screen (LCD off / masked), shown
eqm_draw:   call scr_open
            call eqm_pal                    ; (masked: into the shadows)
            ld a, [eqm_m]
            call mtop
            ld hl, str_lv                   ; (short: Optimize beside it)
            call pen_str
            ld a, [eqm_m]
            call ch_rec
            ld a, l
            add a, $26
            ld l, a
            ld a, [hl]
            inc a
            call nf_a
            call pen_numl
            ld bc, $0B03                    ; (Optimize, bottom right: owner, 2026-11-22)
            call pen_at
            ld hl, str_eqopt
            call pen_str
            ld bc, $0005
            ld de, $1407
            call scr_win
            ld bc, $000C
            ld de, $1406
            call scr_win
            call eqm_sdraw
            jp scr_show

; the member screens' top window (0,0,20,5): member A's picture (cells 1-2, 1-3), name,
; job; the pen left at (4, 3) for the screen's third line; eqm_cls = the job
mtop:       ld [mt_m], a
            call ch_rec
            ld a, [hl]
            ld [eqm_cls], a
            call scr_classes                ; the member's job: sprite tiles 0-5
            ld bc, $0000
            ld de, $1405
            call scr_win
            ld a, [eqm_cls]
            ld e, a
            ld d, 0
            ld hl, cls_pal
            add hl, de
            ld a, [hl]
            ld [scr_t0], a
            ld bc, $0808
            ld e, 4
            xor a
            call scr_spr23
            ld bc, $0401
            call pen_at
            ld a, [mt_m]
            call pen_name
            ld bc, $0402                    ; (the job's name on one line)
            call pen_at
            ld a, [eqm_cls]
            add a, a
            ld e, a
            ld d, 0
            ld hl, cname_ptrs
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            call pen_str
            ld bc, $0403
            jp pen_at

; the middle window: the weapon, then the armour worn (FF1 has two kinds: weapons and
; armour); the bottom: the stats
eqm_sdraw:  call eqm_mclr
            call eqm_mkrows
            xor a
.t:         ld [eqm_k], a
            ld e, a
            ld d, 0
            ld hl, eqm_rows
            add hl, de
            ld a, [hl]
            cp $FE
            jr z, .n                        ; (no row)
            push af
            ld a, [eqm_k]
            add a, 6
            ld c, a
            ld b, 2
            call pen_at
            ld a, [eqm_k]
            ld [eqm_ft], a                  ; (0: weapons, else armour)
            pop af
            cp $FF
            jr z, .e
            ld [eqm_fj], a
            call eqm_slotj
            ld a, [hl]
            call eqm_name
            jr .n
.e:         ld a, [eqm_k]                   ; empty: a sword or an armour icon, a dash
            and a
            ld a, $19
            jr z, .ic
            ld a, $07
.ic:        call pen_ch
            ld a, '-'
            call pen_ch
.n:         ld a, [eqm_k]
            inc a
            cp 5
            jr c, .t
            ld a, [eqm_m]
            call eqm_calc
            ld hl, eqm_v
            ld de, eqm_w
            ld b, 4
.c:         ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .c
            jp eqm_stats

; the middle window's rows cleared (and their colours)
eqm_mclr:   ld c, 6
.r:         ld b, 1
            call pen_at
            ld b, 18
            call pen_sp
            inc c
            ld a, c
            cp 11
            jr c, .r
            ret

; the item list (eqm_ls from eqm_top) in the middle window, the preview in the bottom one
eqm_ldraw:  call eqm_mclr
            xor a
.r:         ld [eqm_k], a
            ld hl, eqm_top
            add a, [hl]
            ld hl, eqm_n
            cp [hl]
            jr nc, .p
            ld e, a
            ld a, [eqm_k]
            add a, 6
            ld c, a
            ld b, 2
            call pen_at
            ld d, 0
            ld hl, eqm_ls
            add hl, de
            ld a, [hl]
            cp $FF
            jr nz, .it
            ld hl, str_eqrem
            call pen_str
            jr .nx
.it:        call eqm_mslot                  ; HL = member A >> 2's slot A & 3
            ld a, [hl]
            call eqm_name
.nx:        ld a, [eqm_k]
            inc a
            cp 5
            jr c, .r
.p:         call eqm_entry                  ; the preview: the change applied, the stats, undone
            push af
            call eqm_save
            pop af
            call eqm_apply
            ld a, [eqm_m]
            call eqm_calc
            ld hl, eqm_v
            ld de, eqm_w
            ld b, 4
.cw:        ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .cw
            call eqm_rest
            ld a, [eqm_m]
            call eqm_calc
            call eqm_stats
            jp scr_upd

; the bottom window: labels, values; when they differ the new value after '>' (Colour:
; green better, red worse)
eqm_stats:  ld bc, $010D
            call pen_at
            ld hl, str_eqst
            call pen_str
            xor a
.r:         ld [eqm_k], a
            add a, 13
            ld c, a
            ld b, 10
            call pen_at
            ld a, [eqm_k]
            ld e, a
            ld d, 0
            ld hl, eqm_v
            add hl, de
            ld a, [hl]
            call nf_a
            ld b, 3
            call pen_num
            ld b, 13                        ; '>' and the new value, or blank
            ld a, [eqm_k]
            add a, 13
            ld c, a
            call pen_at
            ld a, [eqm_k]
            ld e, a
            ld d, 0
            ld hl, eqm_w
            add hl, de
            ld a, [hl]
            ld hl, eqm_v
            add hl, de
            cp [hl]
            ld b, WIN_ATTR
            jr z, .same
            ld b, $09                       ; (green: palette 1, VRAM bank 1)
            jr nc, .up
            ld b, $0A                       ; (red: palette 2)
.up:        push bc
            push af
            ld a, '>'
            call pen_ch
            ld a, ' '
            call pen_ch
            pop af
            call nf_a
            ld b, 3
            call pen_num
            pop bc
            jr .col
.same:      push bc
            ld b, 5
            call pen_sp
            pop bc
.col:       ld a, [eqm_k]                   ; the colour of cells 13-17 of the row
            add a, 13
            ld c, a
            push bc
            ld b, 13
            call cell_addr
            pop bc
            ld a, h
            add a, 3
            ld h, a
            ld a, b
            ld c, 5
.cl:        ld [hl+], a
            dec c
            jr nz, .cl
            ld a, [eqm_k]
            inc a
            cp 4
            jr c, .r
            ret

; A = slot type (0 weapon, 1 body, 2 shield, 3 helmet, 4 gloves) -> A = the member's slot
; (0-3) holding its equipped item of that type, $FF if none
eqm_find:   ld [eqm_ft], a
            ld c, 0
.l:         ld a, c
            ld [eqm_fj], a
            call eqm_slotj
            ld a, [hl]
            bit 7, a
            jr z, .n
            call eqm_fits
            jr nc, .y
.n:         ld a, [eqm_fj]
            inc a
            ld c, a
            cp 4
            jr c, .l
            ld a, $FF
            ret
.y:         ld a, [eqm_fj]
            ret
; HL = this member's slot eqm_fj of the kind of type eqm_ft
eqm_slotj:  ld a, [eqm_m]
            ld b, a
            ld a, [eqm_fj]
            jr eqm_ms2
; HL = this member's slot of type eqm_k's kind holding its equipped item (eqm_find first)
eqm_slot:   ld [eqm_fj], a
            ld a, [eqm_k]
            ld [eqm_ft], a
            jr eqm_slotj
; A = m * 4 + j -> HL = member m's slot j of the kind of type eqm_ft
eqm_mslot:  ld b, a
            srl b
            srl b
            and 3
            ld c, a
            ld a, c
eqm_ms2:    push af                         ; B = member, A = slot
            ld a, b
            call ch_rec
            ld a, [eqm_ft]
            and a
            ld a, $18
            jr z, .w
            ld a, $1C
.w:         add a, l
            ld l, a
            pop af
            add a, l
            ld l, a
            ret
; A = slot byte: NC if the item is of type eqm_ft (weapons: any; armour: FF1's type)
eqm_fits:   and $7F
            jr nz, .i
            scf                             ; (empty: does not fit)
            ret
.i:
            ld b, a
            ld a, [eqm_ft]
            and a
            ret z                           ; (a weapon: fits)
            push hl
            ld a, b
            dec a
            call eq_atype
            pop hl
            inc a
            ld b, a
            ld a, [eqm_ft]
            cp b
            jr nz, .no
            and a                           ; NC
            ret
.no:        scf
            ret

; the rows: eqm_rows[0] = the member's weapon slot ($FF none); then its armour worn, one
; piece of each type in FF1's order (body, shield, helmet, gloves), then $FF (an empty row
; to put on another piece) while fewer than four are worn; $FE: no row. eqm_nr = rows.
eqm_mkrows: ld hl, eqm_rows
            ld a, $FE
            ld b, 5
.c:         ld [hl+], a
            dec b
            jr nz, .c
            xor a
            call eqm_find
            ld [eqm_rows], a
            ld a, 1
            ld [eqm_nr], a
            ld a, 1                         ; armour types 1-4
.ty:        ld [eqm_k], a
            call eqm_find
            cp $FF
            jr z, .tn
            call .add
.tn:        ld a, [eqm_k]
            inc a
            cp 5
            jr c, .ty
            ld a, [eqm_nr]
            cp 5
            ret nc
            ld a, $FF
.add:       ld b, a
            ld a, [eqm_nr]
            ld e, a
            ld d, 0
            ld hl, eqm_rows
            add hl, de
            ld [hl], b
            inc a
            ld [eqm_nr], a
            ret

; the candidates for row eqm_t: Remove (when the row has an item), then every unequipped
; item of the row's kind (weapons / armour of any type) in the party's packs that the
; member's job may use
eqm_cands:  xor a
            ld [eqm_n], a
            ld a, [eqm_t]
            ld [eqm_ft], a
            ld e, a
            ld d, 0
            ld hl, eqm_rows
            add hl, de
            ld a, [hl]
            cp $FF
            jr z, .m0
            ld a, $FF
            call .add
.m0:        xor a
.l:         ld [eqm_k], a                   ; m * 4 + j
            call eqm_mslot
            ld a, [hl]
            and a
            jr z, .n
            bit 7, a
            jr nz, .n
            call eqm_legal
            jr c, .n
            ld a, [eqm_k]
            call .add
.n:         ld a, [eqm_k]
            inc a
            cp 16
            jr c, .l
            ret
.add:       ld b, a
            ld a, [eqm_n]
            ld e, a
            ld d, 0
            ld hl, eqm_ls
            add hl, de
            ld [hl], b
            inc a
            ld [eqm_n], a
            ret

; A = item (1-based) of the kind of eqm_ft: C if the member's job may not use it (FF1
; IsEquipLegal: the permission word's bit $800 >> class)
eqm_legal:  dec a
            add a, a
            ld e, a
            ld d, 0
            ld a, [eqm_ft]
            and a
            ld hl, N_WPERM
            jr z, .w
            ld hl, N_APERM
.w:         add hl, de
            ld de, eqm_buf
            ld bc, 2
            ld a, NAMES
            call far_copy
            ld a, [eqm_cls]
            ld b, a
            ld hl, $0800
.sh:        ld a, b
            and a
            jr z, .t
            srl h
            rr l
            dec b
            jr .sh
.t:         ld a, [eqm_buf]
            and l
            ld b, a
            ld a, [eqm_buf + 1]
            and h
            or b
            ret z                           ; (Z: allowed, C clear)
            scf
            ret

; A = the list entry under the cursor
eqm_entry:  ld a, [eqm_c]
            ld e, a
            ld d, 0
            ld hl, eqm_ls
            add hl, de
            ld a, [hl]
            ret

; apply entry A to slot type eqm_t: $FF removes the equipped item; m * 4 + j: this member
; equips the item in member m's slot j (FF1's slots; an item from another member's pack
; trades places with the one it replaces, or takes a free slot, or an unequipped one)
eqm_apply:  ld [eqm_e], a
            ld a, [eqm_t]
            ld [eqm_ft], a
            ld e, a
            ld d, 0
            ld hl, eqm_rows
            add hl, de
            ld a, [hl]
            ld [eqm_eq], a                  ; the row's slot ($FF: none)
            ld a, [eqm_e]
            cp $FF
            jr z, .rem
            ld a, [eqm_t]                   ; armour: the piece worn of the new one's type
            and a                           ;   (FF1: one of each) is replaced
            jr z, .take
            ld a, [eqm_e]
            call eqm_mslot
            ld a, [hl]
            and $7F
            dec a
            call eq_atype
            inc a
            call eqm_find                   ; (eqm_ft = its type: still the armour kind)
            cp $FF
            jr z, .take
            ld b, a
            ld a, [eqm_eq]
            cp $FF
            jr nz, .two
            ld a, b                         ; an empty row: that piece is the one replaced
            ld [eqm_eq], a
            jr .take
.two:       cp b
            jr z, .take
            ld a, b                         ; another row's piece of that type: taken off
            ld [eqm_fj], a
            call eqm_slotj
            res 7, [hl]
            jr .take
.rem:       ld a, [eqm_eq]                  ; remove
            cp $FF
            ret z
            ld [eqm_fj], a
            call eqm_slotj
            res 7, [hl]
            ret
.take:      ld a, [eqm_e]
            call eqm_mslot                  ; DE = the item's slot
            ld d, h
            ld e, l
            ld a, [eqm_e]
            srl a
            srl a
            ld b, a
            ld a, [eqm_m]
            cp b
            jr nz, .other
            ld a, [eqm_eq]                  ; this member's own: the old one off, this on
            cp $FF
            jr z, .on
            push de
            ld [eqm_fj], a
            call eqm_slotj
            res 7, [hl]
            pop de
.on:        ld a, [de]
            set 7, a
            ld [de], a
            ret
.other:     ld a, [eqm_eq]                  ; the target slot: the equipped one's, a free
            cp $FF                          ;   one, else the first unequipped one
            jr nz, .tg
            ld c, 0
.fr:        ld a, c
            ld [eqm_fj], a
            push de
            push bc
            call eqm_slotj
            pop bc
            pop de
            ld a, [hl]
            and a
            jr z, .tgh
            inc c
            ld a, c
            cp 4
            jr c, .fr
            ld c, 0
.fu:        ld a, c
            ld [eqm_fj], a
            push de
            push bc
            call eqm_slotj
            pop bc
            pop de
            bit 7, [hl]
            jr z, .tgh
            inc c
            jr .fu
.tg:        ld [eqm_fj], a
            push de
            call eqm_slotj
            pop de
.tgh:       ld a, [hl]                      ; HL = target, DE = the item: swapped, the
            and $7F                         ;   item equipped
            ld b, a
            ld a, [de]
            set 7, a
            ld [hl], a
            ld a, b
            ld [de], a
            ret

; the kind's slots of all four members saved / restored (the preview)
eqm_save:   xor a
            jr eqm_cp
eqm_rest:   ld a, 1
eqm_cp:     ld [eqm_sv], a
            ld a, [eqm_t]
            and a
            ld a, $18
            jr z, .w
            ld a, $1C
.w:         ld l, a
            ld h, high(ch_stats)
            ld de, eqm_bk
            ld c, 4
.m:         push hl
            ld b, 4
.b:         ld a, [eqm_sv]
            and a
            jr nz, .r
            ld a, [hl+]
            ld [de], a
            jr .n
.r:         ld a, [de]
            ld [hl+], a
.n:         inc de
            dec b
            jr nz, .b
            pop hl
            ld a, l
            add a, $40
            ld l, a
            dec c
            jr nz, .m
            ret

; member A's stats with the current equipment -> eqm_v (Attack, Accuracy, Defense, Evasion)
eqm_calc:   ld [eqm_k], a
            ld a, 1
            ld [eq_adj], a
            xor a
            ld [eq_kind], a
            ld a, $18
            ld [eq_off], a
            call eq_readj
            ld a, 1
            ld [eq_kind], a
            ld a, $1C
            ld [eq_off], a
            call eq_readj
            ld a, [eqm_k]
            call ch_rec
            ld a, l
            add a, $20
            ld l, a
            ld a, [hl+]                     ; damage, hit rate, absorb, evasion
            ld [eqm_v], a
            ld a, [hl+]
            ld [eqm_v + 1], a
            ld a, [hl+]
            ld [eqm_v + 2], a
            ld a, [hl]
            ld [eqm_v + 3], a
            jp eqm_unadj

; the name of slot byte A of the kind of type eqm_ft (icon + letters)
eqm_name:   and $7F
            ld b, a
            ld a, [eqm_ft]
            and a
            ld a, 27                        ; weapons: names 28-67, armour 68-107
            jr z, .w
            ld a, 67
.w:         add a, b
            jp pen_iname


zz_end_7500:
section wram, $CD00
scr_t0:     ds 1
scr_t1:     ds 1
ng_cur:     ds 1
pg_mem:     ds 1
pg_t:       ds 1
pg_class:   ds 4
pg_old:     ds 1
scr_mus:    ds 1                            ; the menu's / shop's music, resumed after a jingle
pr_rgb:     ds 10                           ; the prologue's colours (RGB555)
pr_nl:      ds 1
pr_row0:    ds 1
pr_row:     ds 1
pr_i:       ds 1
pr_cnt:     ds 1
pr_cc:      ds 9                            ; (the fade: from R G B, to R G B, now R G B)
eqm_m:      ds 1
eqm_t:      ds 1
eqm_ot:     ds 1
eqm_c:      ds 1
eqm_top:    ds 1
eqm_n:      ds 1
eqm_k:      ds 1
eqm_ft:     ds 1
eqm_fj:     ds 1
eqm_e:      ds 1
eqm_eq:     ds 1
eqm_cls:    ds 1
eqm_sv:     ds 1
eqm_v:      ds 4
eqm_w:      ds 4
eqm_buf:    ds 8
eqm_ls:     ds 17
eqm_bk:     ds 16
eqm_rows:   ds 5
mt_m:       ds 1
eqm_nr:     ds 1
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
sus_dir:    ds 1                            ; (Suspend)
sus_n:      ds 2
sus_cp:     ds 2
sus_ln:     ds 1
sus_k:      ds 1
sus_top:    ds 1
sus_yr:     ds 1
sus_res:    ds 1                            ; the title resumed a suspend point
ng_lock:    ds 1                            ; the title: nothing to continue
ni_case:    ds 1                            ; name entry: 0 capitals, 1 small letters
section wram, $D400
smap:       ds 18 * 32                      ; the screen's map copy (attributes at + $300)
section wram, $D700
sattr:      ds 18 * 32
