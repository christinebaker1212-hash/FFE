; ---- cfg.s (bank CODE11): Config (FF1's Options, owner 2026-11-28: reference FF1 for the specific
; menus and its implementation of them). Pages as FF1's: Config (Battle Speed, Text Speed, Volume,
; Controls >, Window >, Return to Default), Controls (B Dash, Cursor), Window (Red, Green, Blue,
; Gradient: the windows' colour live, as FF1). Left / right change a value; A or Right opens a
; page; B: back (from Config: saved and closed). Kept in cart RAM bank 0 $AD00 with a check (the
; RAM on only around the copy), loaded at boot (cfg_load; defaults if none or damaged).
CF_AT      = $AD00              ; cart RAM bank 0: $A5, the settings (CF_N), their sum
CF_N       = 8
CF_ROWS    = 6

cfg_open:   xor a
            ld [cf_pg], a
            ld [cf_cur], a
.re:        call cf_scr
            call u_flush
            call u_fadein
.l:         ld a, [cf_cur]                  ; the hand: row 5 + 2 n, cell 3
            add a, a
            add a, 5
            ld c, a
            ld b, 3
            call u_hand
            call wait_vbl
            call u_keys
            ld a, [m_new]
            bit 1, a
            jr nz, .b
            bit 0, a
            jr nz, .a
            ld b, a
            ld a, [cf_cur]
            bit 6, b
            jr z, .d
            and a
            jr z, .l
            dec a
            jr .s
.d:         bit 7, b
            jr z, .lr
            inc a
            ld c, a
            call cf_count
            cp c
            jr z, .l
            ld a, c
.s:         ld [cf_cur], a
            ld a, $98
            ld [S49], a
            jr .l
.lr:        ld a, b
            and $30
            jr z, .l
            call cf_id
            cp 3                            ; (a page: Right opens it)
            jr c, .ch
            cp 6
            jr nc, .ch
            cp 5
            jr z, .l
            bit 4, b
            jr nz, .page
            jr .l
.ch:        call cf_change
            jr .l
.a:         call cf_id
            cp 5
            jr z, .def
            cp 3
            jr c, .l
            cp 5
            jr nc, .l
.page:      sub 2                           ; Controls 1, Window 2
            ld [cf_pg], a
            xor a
            ld [cf_cur], a
            ld a, $85
            ld [S49], a
            call cf_draw
            call u_flush
            jr .l
.def:       ld a, $85                       ; Return to Default
            ld [S49], a
            call cf_defs
            call cf_apply
            call cf_draw
            call u_flush
            jr .l
.b:         ld a, $85
            ld [S49], a
            ld a, [cf_pg]
            and a
            jr z, .x
            add a, 2                        ; (back to Config, the hand on the page's line)
            ld [cf_cur], a
            xor a
            ld [cf_pg], a
            call cf_draw
            call u_flush
            jp .l
.x:         call cfg_save
            call u_fadeout
            jp u_hoff

; the settings on the page: cf_count -> A; cf_id -> A = the setting's id (0 Battle Speed, 1 Text
; Speed, 2 Volume, 3 Controls, 4 Window, 5 Return to Default, 6 B Dash, 7 Cursor, 8 Red, 9 Green,
; 10 Blue, 11 Gradient)
cf_count:   ld a, [cf_pg]
            and a
            ld a, 6
            ret z
            ld a, [cf_pg]
            dec a
            ld a, 2
            ret z
            ld a, 4
            ret
cf_id:      ld a, [cf_cur]
cf_ida:     ld c, a
            ld a, [cf_pg]
            and a
            ld a, c
            ret z
            ld a, [cf_pg]
            dec a
            ld a, c
            jr nz, .w
            add a, 6
            ret
.w:         add a, 8
            ret
; left / right (B = the keys) on setting A
cf_change:  push af
            ld a, $98
            ld [S49], a
            pop af
            ld e, a
            ld d, 0
            ld hl, CF_VAR
            add hl, de
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a                         ; HL = its byte
            push hl
            ld hl, CF_MAX
            add hl, de
            ld c, [hl]                      ; C = its count
            pop hl
            ld a, [hl]
            bit 4, b
            jr z, .dn
            inc a
            cp c
            jr c, .s
            xor a
            jr .s
.dn:        dec a
            cp $FF
            jr nz, .s
            ld a, c
            dec a
.s:         ld [hl], a
            call cf_apply
            ld a, [cf_cur]
            call cf_row
            jp u_flush
CF_VAR:     dw opt_spd, opt_txt, opt_bgm, 0, 0, 0, opt_dash, opt_curm, win_r, win_g, win_b, opt_grad
CF_MAX:     db 8, 5, 8, 1, 1, 1, 2, 2, 32, 32, 32, 2

; the settings take effect: the battle speed into the save block, the volume (NR50), the windows'
; colour and the gradient (shown at once)
cf_apply:   ld a, [opt_spd]
            ld [msg_speed], a
            ld [GS + $10], a
            ld a, [opt_bgm]
            ld b, a
            swap a
            or b
            ldh [rNR50], a
            call u_wcol
            call u_gron
            call u_sv2                      ; (the colours shown now: BG 1-6, the ramp)
            ld hl, u_palt + 8
            ld de, pal_sh + 8
            ld bc, 48
            call memcpy
            ld a, 4
            ld [u_k], a
            call u_grramp
            call u_svr
            ld a, 1
            ldh [pal_dirty], a
            ret
; the defaults (FF1's: Text Speed 3, Volume 7, B Dash on, Cursor Remember, FF3's window colour,
; the gradient on); Battle Speed as it is (FF3 keeps it in the save)
cf_defs:    ld a, 2
            ld [opt_txt], a
            ld a, 7
            ld [opt_bgm], a
            xor a
            ld [opt_dash], a
            ld [opt_curm], a
            ld [opt_grad], a
            ld hl, CF_WIN
            ld a, [hl+]
            ld [win_r], a
            ld a, [hl+]
            ld [win_g], a
            ld a, [hl]
            ld [win_b], a
            ret

; ---- the screen
cf_scr:     call oam_hide
            call u_cls
            ld bc, $0000
            ld de, $1403
            call u_box
            ld bc, $0003
            ld de, $140F
            call u_box
cf_draw:    ld bc, $0101                    ; the title (pool 0-9)
.cl:        push bc
            ld a, U_FILL
            call u_cell
            pop bc
            inc b
            ld a, b
            cp 19
            jr nz, .cl
            xor a
            ld [u_pool], a
            ld a, UP_LABEL
            ld [u_pal], a
            ld a, [cf_pg]
            ld hl, U_CONFIG
            and a
            jr z, .t
            ld hl, U_CTRL
            dec a
            jr z, .t
            ld hl, U_WIN
.t:         ld bc, $0101
            call u_text
            xor a
.r:         push af
            call cf_row
            pop af
            inc a
            cp CF_ROWS
            jr nz, .r
            ld a, 1
            ld [m_dirty], a
            ret
; line A of the page (row 5 + 2 A; pool 10 + 14 A): the setting's name, its value
cf_row:     ld [cf_t], a
            add a, a
            add a, 5
            ld c, a
            ld b, 1
.cl:        push bc
            ld a, U_FILL
            call u_cell
            pop bc
            inc b
            ld a, b
            cp 19
            jr nz, .cl
            ld a, [cf_t]
            ld b, a
            add a, a
            add a, b
            add a, a
            add a, b
            add a, a                        ; 14 A
            add a, 10
            ld [u_pool], a
            call cf_count
            ld b, a
            ld a, [cf_t]
            cp b
            ret nc
            call cf_ida
            ld [cf_i], a
            add a, a
            ld e, a
            ld d, 0
            ld hl, CF_NAME
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld a, UP_WHITE
            ld [u_pal], a
            ld a, [cf_t]
            add a, a
            add a, 5
            ld c, a
            ld b, 3
            call u_text
            ld a, [cf_i]                    ; the value
            cp 3
            jr c, .num
            cp 6
            jr c, .pg
            cp 8
            jr c, .two
            cp 11
            jr c, .num0
            ld hl, U_ON                   ; Gradient: On / Off
            ld a, [opt_grad]
            and a
            jr z, .str
            ld hl, U_OFFW
            jr .str
.two:       cp 6
            ld a, [opt_dash]
            ld hl, U_ON                   ; B Dash: On / Off
            jr z, .oo
            ld a, [opt_curm]                ; Cursor: Remember / Reset
            ld hl, U_REMEM
            and a
            jr z, .str
            ld hl, U_RESET
            jr .str
.oo:        and a
            jr z, .str
            ld hl, U_OFFW
            jr .str
.pg:        cp 5                            ; a page: ">"
            ret z
            ld hl, U_ARROW
            jr .str
.num:       call .var                       ; Battle / Text Speed 1-8, 1-5; Volume 0-7
            ld a, [cf_i]
            cp 2
            ld a, [hl]
            jr z, .n0
            inc a
            jr .n0
.num0:      call .var                       ; Red / Green / Blue 0-31
            ld a, [hl]
.n0:        ld e, a
            ld d, 0
            call u_ntoa
.str:       ld a, [cf_t]
            add a, a
            add a, 5
            ld c, a
            ld b, 19
            ld a, UP_YELLOW
            ld [u_pal], a
            call u_textr
            ld a, UP_WHITE
            ld [u_pal], a
            ld a, 1
            ld [m_dirty], a
            ret
.var:       ld a, [cf_i]
            ld e, a
            ld d, 0
            ld hl, CF_VAR
            add hl, de
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ret
CF_NAME:    dw U_SPD, U_TSPD, U_VOL, U_CTRL, U_WIN, U_DEF0, U_DASH, U_CURS, U_RED, U_GRN, U_BLU, U_GRAD

; ---- cart RAM (bank 0 $AD00): the settings, checked
cfg_save:   call cf_on
            ld hl, CF_AT
            ld a, $A5
            ld [hl+], a
            ld de, CF_SRC
            ld b, CF_N
            ld c, 0
.l:         push hl
            ld a, [de]
            ld l, a
            inc de
            ld a, [de]
            ld h, a
            inc de
            ld a, [hl]
            pop hl
            ld [hl+], a
            add a, c
            ld c, a
            dec b
            jr nz, .l
            ld a, c
            cpl
            ld [hl], a
            jr cf_off
; at boot (main.s): the settings from cart RAM, else the defaults; then in effect (the volume)
cfg_load:   call cf_defs
            ld a, 7
            ld [opt_bgm], a
            call cf_on
            ld hl, CF_AT
            ld a, [hl+]
            cp $A5
            jr nz, .x
            push hl                         ; (the sum + its complement: $FF)
            ld b, CF_N
            ld c, 0
.s:         ld a, [hl+]
            add a, c
            ld c, a
            dec b
            jr nz, .s
            ld a, [hl]
            add a, c
            pop hl
            cp $FF
            jr nz, .x
            ld de, CF_SRC
            ld b, CF_N
.c:         ld a, [hl+]
            ld c, a
            push hl
            ld a, [de]
            ld l, a
            inc de
            ld a, [de]
            ld h, a
            inc de
            ld [hl], c
            pop hl
            dec b
            jr nz, .c
.x:         call cf_off
            ld a, [opt_bgm]
            and 7
            ld [opt_bgm], a
            ld b, a
            swap a
            or b
            ldh [rNR50], a
            ret
cf_on:      xor a
            ld [$4000], a
            ld a, $0A
            ld [$0000], a
            ret
cf_off:     xor a
            ld [$0000], a
            ret
CF_SRC:     dw opt_txt, opt_bgm, opt_dash, opt_curm, win_r, win_g, win_b, opt_grad

section wram, $DFDC                         ; (WRAM 2: after svm.s's)
cf_pg:      ds 1
cf_cur:     ds 1
cf_t:       ds 1
cf_i:       ds 1
