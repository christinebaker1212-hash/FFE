; ---- svm.s (bank CODE11): the file screen (FF3's save menu 3D/A897 and load menu 3D/B9F6, rebuilt for
; the owner's polish pass, 2026-11-28). Top (0,0,20,3): Save: "Please choose the file to save to."
; ($014B); Load: New Game and the Battle Speed (left / right). The files (0,5,20,13), 4 rows each: the
; first member's battle picture, its name and LV, the other three names, Gil (an empty file: nothing).
; Save: "This erases old data." Yes / No ($014C), "Saving is complete." ($014D), the GB's power-off
; note; FF3's format and checks (save.s). Lot Check: cart RAM on only around each access (save.s).
SV_P0      = 20                 ; pool: 0-19 the top, 20 + 40 f the file f, 140- the question

; ---- Save (the main menu, on a world map)
svm_save:   xor a
            ld [svm_mode], a
            ld [sv_cur], a
            call svm_scr
            call u_flush
            call u_fadein
.l:         call svm_fhand
            call wait_vbl
            call u_keys
            ld a, [m_new]
            bit 1, a
            jr nz, .x
            bit 0, a
            jr nz, .a
            call svm_ud
            jr .l
.a:         ld a, $85
            ld [S49], a
            ld hl, U_SV1                    ; "This erases old data." Yes / No
            call svm_ask
            jr c, .back
            ld a, CODE1
            ld hl, svx_save
            call far_call
            ld a, $A3
            ld [S49], a
            ld hl, U_SV2                    ; "Saving is complete."
            call svm_note
            ld hl, U_OFF                    ; "You can turn the power off now." (the GB: no RESET)
            call svm_note
.x:         ld a, $85
            ld [S49], a
            call u_fadeout
            call u_hoff
            jp oam_hide
.back:      call svm_redraw
            jr .l

; ---- Load (the title): u_eres = 0 New Game, 1 a file loaded
svm_load:   call u_open
            ld a, 1
            ld [svm_mode], a
            ld a, 3                         ; (New Game first: 3D/BA44)
            ld [sv_cur], a
            call svm_scr
            call u_flush
            call u_fadein
.l:         call svm_fhand
            call wait_vbl
            call u_keys
            ld a, [m_new]
            bit 0, a
            jr nz, .a
            ld b, a
            and $30                         ; left / right: the speed (1-8)
            jr z, .ud
            ld a, [opt_spd]
            bit 4, b
            jr z, .dec
            inc a
            jr .sp
.dec:       dec a
.sp:        and 7
            ld [opt_spd], a
            ld [msg_speed], a
            ld a, $98
            ld [S49], a
            call svm_top
            call u_flush
            jr .l
.ud:        ld a, b
            call svm_ud
            jr .l
.a:         ld a, [sv_cur]
            cp 4
            jr z, .ext
            cp 3
            jr z, .new
            ld [mgm_t], a
            ld a, CODE1
            ld hl, svx_load
            call far_call
            ld a, [u_eres]
            and a
            jr z, .ld
            ld a, $86                       ; (an empty file)
            ld [S49], a
            jr .l
.ld:        ld a, $85
            ld [S49], a
            ld a, [opt_spd]
            ld [GS + $10], a
            call u_fadeout
            call u_hoff
            call oam_hide
            ld a, 1
            ld [u_eres], a
            ret
.ext:       ld a, $85                       ; Extras (FF1's: on the title)
            ld [S49], a
            call u_fadeout
            call xm_run
            ld a, 1
            ld [svm_mode], a
            call svm_scr
            call u_flush
            call u_fadein
            jp .l
.new:       ld a, $85                       ; (3D/BAC6: the speed -> $6010)
            ld [S49], a
            ld a, [opt_spd]
            ld [GS + $10], a
            call u_fadeout
            call u_hoff
            call oam_hide
            xor a
            ld [u_eres], a
            ret

; up / down (A = the new keys): the files (and New Game, 3, above them on the title)
svm_ud:     ld b, a                         ; (title: New Game 3, Extras 4, then the files)
            ld a, [sv_cur]
            bit 6, b
            jr z, .d
            cp 3
            ret z
            cp 4
            jr nz, .u0
            ld a, 3
            jr .s
.u0:        and a
            jr nz, .u
            ld a, [svm_mode]
            and a
            ret z
            ld a, 4
            jr .s
.u:         dec a
            jr .s
.d:         bit 7, b
            ret z
            cp 3
            jr nz, .d4
            ld a, 4
            jr .s
.d4:        cp 4
            jr nz, .dn
            xor a
            jr .s
.dn:        cp 2
            ret z
            inc a
.s:         ld [sv_cur], a
            ld a, $98
            ld [S49], a
            ret
; the hand: at file f's picture (rows 7 + 4 f), or at New Game
svm_fhand:  ld a, [sv_cur]
            cp 3
            jr c, .f
            sub 3                           ; (New Game row 1, Extras row 3)
            add a, a
            inc a
            ld c, a
            ld b, 3
            jp u_hand
.f:         add a, a
            add a, a
            add a, 7
            ld c, a
            ld b, 3
            jp u_hand

; the screen
svm_scr:    call oam_hide
            call u_cls
            ld bc, $0000
            ld de, $1405
            call u_box
            ld bc, $0005                    ; the files: one window, a blank row between
            ld de, $140D
            call u_box
            call svm_top
            xor a
.f:         ld [svm_f], a
            call svm_file
            ld a, [svm_f]
            inc a
            cp 3
            jr nz, .f
            ld a, 1
            ld [m_dirty], a
            ret
svm_redraw: call svm_scr
            jp u_flush
; the top: the save's question, or New Game and the speed (pool 0-19)
svm_top:    ld bc, $0101
.cl:        push bc
            ld a, U_FILL
            call u_cell
            pop bc
            inc b
            ld a, b
            cp 19
            jr nz, .cl
            ld b, 1
            inc c
            ld a, c
            cp 4
            jr nz, .cl
            xor a
            ld [u_pool], a
            ld a, UP_WHITE
            ld [u_pal], a
            ld a, [svm_mode]
            and a
            jr nz, .ld
            ld bc, $0102
            ld hl, U_SV0
            call u_text
            jr .x
.ld:        ld bc, $0301
            ld hl, U_NEWG
            call u_text
            ld bc, $0303
            ld hl, U_EXT
            call u_text
            ld a, UP_LABEL
            ld [u_pal], a
            ld bc, $0B01
            ld hl, U_SPD
            call u_text
            ld a, UP_WHITE
            ld [u_pal], a
            ld a, [opt_spd]
            inc a
            ld e, a
            ld d, 0
            call u_ntoa
            ld bc, $1301
            call u_textr
.x:         ld a, 1
            ld [m_dirty], a
            ret
; file svm_f's window (0, 3 + 5 f, 20, 5): picture, name, LV; the others' names; Gil
svm_file:   ld a, [svm_f]                   ; (its first row: 6 + 4 f)
            add a, a
            add a, a
            add a, 6
            ld [svm_r], a
            ld a, [svm_f]                   ; its tiles
            ld b, a
            add a, a
            add a, a
            add a, b
            add a, a
            add a, a
            add a, a                        ; 40 f
            add a, SV_P0
            ld [u_pool], a
            ld a, [svm_f]
            ld [mgm_t], a
            ld a, CODE1
            ld hl, svx_peek
            call far_call
            ld a, [SVB]
            and a
            ret z
            ld a, [svm_f]                   ; the picture: slot f, the first member's job
            ld [u_k], a
            xor a
            ld [u_pm], a
            ld a, [SVB + 8]
            ld [u_t], a
            call u_mjob
            ld a, [svm_r]
            add a, a
            add a, a
            add a, a
            ld c, a
            ld b, 24
            call u_pic
            ld hl, SVB + 10                 ; the first member's name, LV
            call svm_name
            ld a, [svm_r]
            ld c, a
            ld b, 6
            ld hl, mn_buf
            call u_text
            ld a, UP_LABEL
            ld [u_pal], a
            ld a, [svm_r]
            ld c, a
            ld b, 16
            ld hl, U_LV
            call u_textr
            ld a, UP_WHITE
            ld [u_pal], a
            ld a, [SVB + 9]
            ld e, a
            ld d, 0
            call u_ntoa
            ld a, [svm_r]
            ld c, a
            ld b, 19
            call u_textr
            ld a, 1                         ; the other three names (row 2: cells 6, 12; row 3: 6)
.o:         ld [svm_k], a
            add a, a
            add a, a
            add a, a
            add a, low(SVB + 10)
            ld l, a
            ld h, high(SVB + 10)
            call svm_name
            ld a, [svm_k]
            ld b, 6
            ld c, 1
            cp 2
            jr nz, .o1
            ld b, 12
.o1:        cp 3
            jr nz, .o2
            inc c
.o2:        ld a, [svm_r]
            add a, c
            ld c, a
            ld hl, mn_buf
            call u_text
            ld a, [svm_k]
            inc a
            cp 4
            jr nz, .o
            ld a, UP_LABEL                  ; Gil
            ld [u_pal], a
            ld a, [svm_r]
            add a, 2
            ld c, a
            ld b, 12
            ld hl, U_GIL
            call u_text
            ld a, UP_WHITE
            ld [u_pal], a
            ld a, [SVB + 1]
            ld e, a
            ld a, [SVB + 2]
            ld d, a
            ld a, [SVB + 3]
            ld c, a
            call mn_gil
            ld a, [svm_r]
            add a, 2
            ld c, a
            ld b, 19
            jp u_textr
; the name at HL (6 codes) -> mn_buf (0-terminated)
svm_name:   ld de, mn_buf
            ld b, 6
.n:         ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .n
            xor a
            ld [de], a
            ret

; a question (HL: a line) with Yes / No in a window over the files (No / B: carry)
svm_ask:    push hl
            call svm_ovl
            pop hl
            ld bc, $0408
            call u_text
            ld bc, $060A
            ld hl, U_YES
            call u_text
            ld bc, $0C0A
            ld hl, U_NO
            call u_text
            call u_flush
            xor a
            ld [svm_k], a
.l:         ld a, [svm_k]                   ; the hand: Yes (cell 6) / No (cell 12)
            add a, a
            ld b, a
            add a, a
            add a, b
            add a, 6
            ld b, a
            ld c, $0A
            call u_hand
            call wait_vbl
            call u_keys
            ld a, [m_new]
            bit 1, a
            jr nz, .no
            bit 0, a
            jr nz, .a
            and $30
            jr z, .l
            ld a, [svm_k]
            xor 1
            ld [svm_k], a
            ld a, $98
            ld [S49], a
            jr .l
.a:         ld a, [svm_k]
            and a
            jr nz, .no
            ld a, $85
            ld [S49], a
            and a
            ret
.no:        ld a, $85
            ld [S49], a
            scf
            ret
; a note (HL: lines split by {01}) in the window over the files, until A / B
svm_note:   push hl
            call svm_ovl
            pop hl
            ld bc, $0408
.ln:        push bc
            call u_text
            pop bc
            dec hl
            ld a, [hl+]
            cp 1
            jr nz, .w
            inc c
            jr .ln
.w:         call u_hoff
            call u_flush
            jp im_wkey
; the window over the files (2,6,16,6): the pictures off, its tiles from SV_P0 + 120
svm_ovl:    call oam_hide
            ld bc, $0206
            ld de, $1006
            call u_box
            ld a, SV_P0 + 120
            ld [u_pool], a
            ld a, UP_WHITE
            ld [u_pal], a
            ret

section wram, $DFD8                         ; (WRAM 2: after SVB)
svm_mode:   ds 1
svm_f:      ds 1
svm_r:      ds 1
svm_k:      ds 1
