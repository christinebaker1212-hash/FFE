; ---- the Select menu: OPTIONS (battle message speed, music and sound volume) / SUSPEND
sel_open:   call menu_pals
            call hand_ld
            call font_box
            ld a, 2
            ldh [rSVBK], a
            xor a
            ld [m_cur], a
.top:       call m_clear_t
            ld bc, $0000
            ld de, $1405
            call m_box
            ld hl, s_opt
            ld bc, $0201
            call m_str
            ld hl, s_ext
            ld bc, $0202
            call m_str
            ld hl, s_sus
            ld bc, $0203
            call m_str
            ld a, 5 * 8                     ; (the window cut under the box)
            call win_cut
.l:         ld a, [m_cur]                   ; the hand at the entry
            add a, a
            add a, a
            add a, a
            add a, 16 + 8 - 4
            ld c, a
            ld b, 8
            call cursor_at
            call wait_vbl
            call read_pad
            call m_keys
            ld a, [m_new]
            bit 1, a
            jp nz, sel_close
            bit 0, a
            jr nz, .a
            ld b, a
            and $C0
            jr z, .l
            ld a, [m_cur]                   ; up / down: Options, Extras, Suspend (wrapping)
            bit 6, b
            jr z, .dn
            dec a
            cp $FF
            jr nz, .us
            ld a, 2
            jr .us
.dn:        inc a
            cp 3
            jr c, .us
            xor a
.us:        ld [m_cur], a
            jr .l
.a:         ld a, [m_cur]
            and a
            jr nz, .ex
            call options
            xor a
            ld [m_cur], a
            jr .top
.ex:        dec a
            jr nz, .sus
            ld a, CODE10                    ; (extras.s: the Sound Test, the Bestiary)
            ld hl, ex_open
            call far_call
            ld a, 1
            ld [m_cur], a
            jr .top
.sus:       call suspend
            ld a, 2
            ld [m_cur], a
            jr .top

sel_close:  call cur_hide
            call wait_vbl
            ld a, 1
            ldh [rSVBK], a
            xor a
            ld [win_on], a
            call wait_vbl
            ld a, WIN_LINE - 1
            ldh [rLYC], a
            ret

; A = lines: the canvas shown at the top of the screen down to that line (LYC cut)
win_cut:    push af
            ld b, a                         ; (sprites under the box: hidden; the field's below
            add a, 16                       ;   stay)
            ld c, a
            ld hl, oam_buf
            ld e, 36
.o:         ld a, [hl]
            cp c
            jr nc, .k
            ld [hl], 0
.k:         inc l
            inc l
            inc l
            inc l
            dec e
            jr nz, .o
            pop af
            dec a
            ldh [rLYC], a
            ld a, 1
            ld [m_dirty], a
            ld [win_on], a
            jp wait_vbl

; OPTIONS: up / down choose, left / right change (speed 1-8: FF3's message speed $08 0-7;
; volumes 0-7)
options:    xor a
            ld [o_cur], a
.draw:      call m_clear_t
            ld bc, $0000
            ld de, $1407
            call m_box
            ld hl, s_spd
            ld bc, $0201
            call m_str
            ld hl, s_bgm
            ld bc, $0203
            call m_str
            ld hl, s_sfx
            ld bc, $0205
            call m_str
            ld a, [opt_spd]
            inc a
            ld bc, $1101
            call m_digit
            ld a, [opt_bgm]
            ld bc, $1103
            call m_digit
            ld a, [opt_sfx]
            ld bc, $1105
            call m_digit
            ld a, 7 * 8
            call win_cut
.l:         ld a, [o_cur]
            add a, a
            add a, a
            add a, a
            add a, a
            add a, 16 + 8 - 4
            ld c, a
            ld b, 8
            call cursor_at
            call wait_vbl
            call read_pad
            call m_keys
            ld a, [m_new]
            and $03
            ret nz                          ; A / B: back
            ld a, [m_new]
            bit 6, a
            jr z, .dn
            ld a, [o_cur]
            and a
            jr z, .l
            dec a
            ld [o_cur], a
            jr .l
.dn:        bit 7, a
            jr z, .lr
            ld a, [o_cur]
            cp 2
            jr z, .l
            inc a
            ld [o_cur], a
            jr .l
.lr:        ld a, [m_new]
            and $30
            jr z, .l
            ld b, 1
            bit 5, a
            jr z, .ch
            ld b, -1
.ch:        ld a, [o_cur]
            add a, low(opt_spd)
            ld l, a
            ld h, high(opt_spd)
            ld a, [hl]
            add a, b
            and 7
            ld [hl], a
            ld a, [opt_spd]
            ld [msg_speed], a
            jr .draw

; SUSPEND: "Create a Suspend Point and return to the Title? ..." Yes / No
suspend:    call m_clear_t
            ld bc, $0000
            ld de, $1408
            call m_box
            ld hl, s_sq1
            ld bc, $0101
            call m_str
            ld hl, s_sq2
            ld bc, $0102
            call m_str
            ld hl, s_sq3
            ld bc, $0103
            call m_str
            ld hl, s_sq4
            ld bc, $0104
            call m_str
            ld hl, s_yes
            ld bc, $0306
            call m_str
            ld hl, s_no
            ld bc, $0A06
            call m_str
            ld a, 8 * 8
            call win_cut
            ld a, 1
            ld [o_cur], a                   ; (No first)
.l:         ld a, [o_cur]
            ld b, 8 + 1 * 8
            and a
            jr z, .x
            ld b, 8 + 8 * 8
.x:         ld c, 16 + 6 * 8 - 4
            call cursor_at
            call wait_vbl
            call read_pad
            call m_keys
            ld a, [m_new]
            bit 1, a
            ret nz
            bit 0, a
            jr nz, .a
            and $30
            jr z, .l
            ld a, [o_cur]
            xor 1
            ld [o_cur], a
            jr .l
.a:         ld a, [o_cur]
            and a
            ret nz
            call sus_save                   ; the point, then to the title (a soft restart)
            call oam_hide
            call wait_vbl
            jp start

; the suspend point -> cart RAM bank 1: the save block, the position, the map stack, options
; (Lot Check: the RAM enabled only around the access)
SUS_MAGIC  = $A5
sus_save:   ld a, $0A
            ld [$0000], a
            ld a, 1
            ld [$4000], a
            ld hl, GS
            ld de, $A000
            ld bc, $400
            call memcpy
            ld hl, sus_vars
            ld de, $A400
            ld bc, sus_end - sus_vars
            call memcpy
            ld hl, sus_pos                  ; the place: group, map, x, y, facing, world, the
            ld de, $A500                    ;   map stack
.p:         ld a, [hl+]
            and a
            jr z, .pd
            ld c, a
            ld a, [hl+]
            push hl
            ld h, [hl]
            ld l, a
.pc:        ld a, [hl+]
            ld [de], a
            inc de
            dec c
            jr nz, .pc
            pop hl
            inc hl
            jr .p
.pd:
            ld a, SUS_MAGIC
            ld [$A7FF], a
            xor a
            ld [$4000], a
            ld [$0000], a
            ret

sus_pos:    db 1
            dw cur_grp
            db 1
            dw cur_map
            db 1
            dw px
            db 1
            dw py
            db 1
            dw facing
            db 1
            dw cur_world
            db 1
            dw stk_n
            db 64
            dw stack
            db 0

; ---- canvas helpers for these boxes
m_clear_t:  ld hl, MC_MAP                   ; the canvas: blank, menu palette (the window layer
            ld de, MC_ATTR                  ;   covers the screen: the box over a blank screen)
            ld bc, 32 * 18
.l:         ld a, $FF
            ld [hl+], a
            ld a, [m_tattr]
            ld [de], a
            inc de
            dec bc
            ld a, b
            or c
            jr nz, .l
            ret
; a 0-terminated string of font codes (MENU_BANK: GB_TEXT, build.py) at column B, row C
m_str:      ld a, [hl+]
            and a
            ret z
            call m_put
            inc b
            jr m_str
m_digit:    add a, $80
            jp m_put



section wram, $C6A0
o_cur:      ds 1
sus_vars:                                       ; (saved with a suspend point)
opt_spd:    ds 1
opt_bgm:    ds 1
opt_sfx:    ds 1
msg_speed:  ds 1
sus_end:
