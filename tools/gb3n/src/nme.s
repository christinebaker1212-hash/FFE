; ---- nme.s (bank CODE13, on the UI copy): the name entry (FF3 3D/B895, rebuilt for the owner's
; polish pass, 2026-11-28; FF1's grid: the whole hand before each letter). Header (0,0,20,5): the
; member's Onion Knight picture, the name so far (a dash at the next letter), the job, the member's
; number. Letters (0,5,20,13): 45 letters 6 a row from cell 3, three cells apart (rows 6-13); the
; hints below. A a letter (6 at most); B the last letter off (none: the member before); SELECT the
; other case; START this name (not empty; FF3: not like an earlier member's, 3D/B981) or, with
; none, one of the member's preset names (extras.s nm_preset). Returns A: [GS + $0E] as before.
NE_COLS    = 6

nme_open:   call u_open
            xor a
            ld [nm_ch], a
            ld [nm_case], a
.ch:        xor a
            ld [nm_cur], a
            call ne_len
            ld [nm_pos], a
            call ne_scr
            call u_flush
            call u_fadein
.l:         ld a, [nm_cur]                  ; the hand: column 3 + 3 x, row 6 + y
            ld b, 0
.dv:        sub NE_COLS
            jr c, .dd
            inc b
            jr .dv
.dd:        add a, NE_COLS
            ld c, a
            add a, a
            add a, c
            add a, 3
            ld d, a
            ld a, b
            add a, 6
            ld c, a
            ld b, d
            call u_hand
            call wait_vbl
            call u_keys
            ld a, [m_new]
            bit 0, a
            jp nz, .a
            bit 1, a
            jr nz, .b
            bit 2, a
            jr nz, .case
            bit 3, a
            jr nz, .done
            ld b, a
            ld a, [nm_cur]
            bit 4, b
            jr z, .lf
            inc a
            cp 45
            jr c, .s
            xor a
            jr .s
.lf:        bit 5, b
            jr z, .up
            dec a
            cp $FF
            jr nz, .s
            ld a, 44
            jr .s
.up:        bit 6, b
            jr z, .dn
            sub NE_COLS
            jr nc, .s
            add a, 48
            cp 45
            jr c, .s
            sub NE_COLS
            jr .s
.dn:        bit 7, b
            jr z, .l
            add a, NE_COLS
            cp 45
            jr c, .s
            sub 48
            jr nc, .s
            add a, NE_COLS
.s:         ld [nm_cur], a
            ld a, $98
            ld [S49], a
            jp .l
.case:      ld a, [nm_case]
            xor 1
            ld [nm_case], a
            ld a, $98
            ld [S49], a
            call ne_grid
            call u_flush
            jp .l
.b:         ld a, $85
            ld [S49], a
            ld a, [nm_pos]                  ; B: the last letter off; none: the member before
            and a
            jr z, .bp
            dec a
            ld [nm_pos], a
            call ne_name
            call u_flush
            jp .l
.bp:        ld a, [nm_ch]
            and a
            jp z, .l
            dec a
            ld [nm_ch], a
            call u_fadeout
            jp .ch
.done:      ld a, [nm_pos]                  ; START: this name; with none, a preset one
            and a
            jr nz, .dnm
            ld a, $98
            ld [S49], a
            ld a, CODE10
            ld hl, nm_preset
            call far_call
            call ne_name
            call u_flush
            jp .l
.dnm:       call ne_dup
            jr nc, .ok
            ld a, $86
            ld [S49], a
            jp .l
.ok:        ld a, $85
            ld [S49], a
            call ne_fill
            ld a, [nm_ch]
            inc a
            ld [nm_ch], a
            cp 4
            jr z, .x
            call u_fadeout
            jp .ch
.x:         call u_fadeout
            call u_hoff
            call oam_hide
            xor a
            ld [menu_on], a
            ld a, [GS + $0E]
            ret
.a:         ld a, [nm_pos]                  ; A: the letter (6 at most)
            cp 6
            jr c, .a0
            ld a, $86
            ld [S49], a
            jp .l
.a0:        ld a, $85
            ld [S49], a
            ld a, [nm_cur]
            ld e, a
            ld d, 0
            ld hl, TL_G0N
            ld a, [nm_case]
            and a
            jr z, .a1
            ld hl, TL_G1N
.a1:        add hl, de
            ld b, [hl]
            ld a, [nm_ch]
            rrca
            rrca
            add a, 6
            ld e, a
            ld a, [nm_pos]
            add a, e
            ld l, a
            ld h, high(GS + $100)
            ld [hl], b
            ld a, [nm_pos]
            inc a
            ld [nm_pos], a
            call ne_name
            call u_flush
            jp .l

; the screen
ne_scr:     call oam_hide
            call u_cls
            ld bc, $0000
            ld de, $1405
            call u_box
            ld bc, $0005
            ld de, $140D
            call u_box
            ld a, [nm_ch]                   ; the picture: the member's Onion Knight colours
            ld [u_k], a
            ld [u_pm], a
            xor a
            ld [u_t], a
            call u_mjob
            ld bc, $1008
            call u_pic
            ld a, 30                        ; the job, the member's number (pool 30-39)
            ld [u_pool], a
            ld a, UP_WHITE
            ld [u_pal], a
            ld hl, U_JOBN
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld bc, $0403
            call u_text
            ld a, [nm_ch]
            add a, $81
            ld [ne_buf], a
            ld a, $C7
            ld [ne_buf + 1], a
            ld a, $84
            ld [ne_buf + 2], a
            xor a
            ld [ne_buf + 3], a
            ld a, UP_GREY
            ld [u_pal], a
            ld hl, ne_buf
            ld bc, $1301
            call u_textr
            ld a, UP_LABEL                  ; the hints (pool 40-69)
            ld [u_pal], a
            ld a, 40
            ld [u_pool], a
            ld bc, $0210
            ld hl, TL_H2N
            call u_text
            ld a, UP_WHITE
            ld [u_pal], a
            call ne_name
            jp ne_grid
; the name so far, a dash at the next letter (pool 0-9)
ne_name:    ld bc, $0401
.cl:        push bc
            ld a, U_FILL
            call u_cell
            pop bc
            inc b
            ld a, b
            cp 14
            jr nz, .cl
            xor a
            ld [u_pool], a
            ld a, [nm_ch]
            rrca
            rrca
            add a, 6
            ld l, a
            ld h, high(GS + $100)
            ld de, ne_buf
            ld a, [nm_pos]
            and a
            jr z, .d
            ld b, a
.c:         ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .c
.d:         ld a, [nm_pos]
            cp 6
            jr nc, .z
            ld a, $C2                       ; (the next letter's place)
            ld [de], a
            inc de
.z:         xor a
            ld [de], a
            ld a, UP_WHITE
            ld [u_pal], a
            ld hl, ne_buf
            ld bc, $0401
            call u_text
            ld a, 1
            ld [m_dirty], a
            ret
; the letters (pool 70-), and the case's hint
ne_grid:    ld a, 70
            ld [u_pool], a
            ld hl, TL_G0N
            ld a, [nm_case]
            and a
            jr z, .g
            ld hl, TL_G1N
.g:         xor a
.r:         ld [ne_k], a
            push hl
            ld b, 0                         ; cell 3 + 3 (k mod 6), row 6 + k / 6
            ld a, [ne_k]
.dv:        sub NE_COLS
            jr c, .dd
            inc b
            jr .dv
.dd:        add a, NE_COLS
            ld c, a
            add a, a
            add a, c
            add a, 3
            ld c, b
            ld b, a
            ld a, c
            add a, 6
            ld c, a
            push bc
            ld a, U_FILL
            call u_cell
            pop bc
            pop hl
            ld a, [hl+]
            push hl
            ld [ne_buf], a
            xor a
            ld [ne_buf + 1], a
            ld hl, ne_buf
            call u_text
            pop hl
            ld a, [ne_k]
            inc a
            cp 45
            jr nz, .r
            ld bc, $020F                    ; SELECT: abc / ABC
.cl:        push bc
            ld a, U_FILL
            call u_cell
            pop bc
            inc b
            ld a, b
            cp 19
            jr nz, .cl
            ld a, UP_LABEL
            ld [u_pal], a
            ld hl, TL_H0N
            ld a, [nm_case]
            and a
            jr z, .h
            ld hl, TL_H1N
.h:         ld bc, $020F
            call u_text
            ld a, UP_WHITE
            ld [u_pal], a
            ld a, 1
            ld [m_dirty], a
            ret
; the length of member nm_ch's name (up to the first blank) -> A
ne_len:     ld a, [nm_ch]
            rrca
            rrca
            add a, 6
            ld l, a
            ld h, high(GS + $100)
            ld b, 0
.l:         ld a, [hl+]
            cp $FF
            jr z, .x
            and a
            jr z, .x
            inc b
            ld a, b
            cp 6
            jr nz, .l
.x:         ld a, b
            ret
; the name's letters after nm_pos: blanks ($FF)
ne_fill:    ld a, [nm_ch]
            rrca
            rrca
            add a, 6
            ld hl, nm_pos
            add a, [hl]
            ld l, a
            ld h, high(GS + $100)
            ld a, [nm_pos]
            ld b, a
            ld a, 6
            sub b
            ret z
            ld b, a
.f:         ld [hl], $FF
            inc l
            dec b
            jr nz, .f
            ret
; 3D/B95D / B981: member nm_ch's name (blanks after nm_pos) against the earlier ones: carry if alike
ne_dup:     call ne_fill
            ld a, [nm_ch]
            and a
            ret z
            ld b, a
            ld c, 0
.m:         push bc
            ld a, c
            rrca
            rrca
            add a, 6
            ld e, a
            ld d, high(GS + $100)
            ld a, b
            rrca
            rrca
            add a, 6
            ld l, a
            ld h, d
            ld b, 6
.c:         ld a, [de]
            cp [hl]
            jr nz, .diff
            inc e
            inc l
            dec b
            jr nz, .c
            pop bc
            scf
            ret
.diff:      pop bc
            inc c
            ld a, c
            cp b
            jr nz, .m
            and a
            ret

section wram, $DFB0                         ; (WRAM 2: the file screen's bytes, not open now)
ne_k:       ds 1
ne_buf:     ds 8
