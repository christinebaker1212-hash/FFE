; FF1 native engine: Extras from the title menu (owner's list, 2026-11-24): the sound test (every
; one of FF1's 24 songs, from the user's ROM through our music engine) and the bestiary (the
; monsters met in battle, kept for all save files). Our own code; code bank EXTRA_BANK.
EXTRA_BANK = 107
ST_FIRST   = $41            ; FF1's songs $41-$58
ST_N       = 24

section bank 107, $4000
ex_menu:    xor a
            ld [ex_cur], a
.re:        call scr_open
            ld bc, $0000
            ld de, $1403
            call scr_win
            ld bc, $0101
            ld hl, ex_title
            call pen_at
            call pen_str
            ld bc, $0003
            ld de, $140F
            call scr_win
            ld bc, $0405
            call pen_at
            ld hl, ex_l0
            call pen_str
            ld bc, $0407
            call pen_at
            ld hl, ex_l1
            call pen_str
            call scr_show
.l:         ld a, [ex_cur]                  ; the hand at row 5 + 2 n
            add a, a
            add a, 5
            ld c, a
            ld b, 4
            call cur_txt
            call scr_frame
            ldh a, [pad_new]
            bit 1, a
            ret nz
            bit 0, a
            jr nz, .a
            and $C0
            jr z, .l
            ld a, [ex_cur]
            xor 1
            ld [ex_cur], a
            jr .l
.a:         ld a, [ex_cur]
            and a
            jr nz, .b
            call st_main
            jr .re
.b:         call bs_main
            jr .re
ex_title:   db "Extras", 0
ex_l0:      db "Sound Test", 0
ex_l1:      db "Bestiary", 0

; ---- the sound test: left / right a song, A plays it, B back
st_main:    call scr_open
            ld bc, $0000
            ld de, $1403
            call scr_win
            ld bc, $0101
            call pen_at
            ld hl, st_title
            call pen_str
            ld bc, $0003
            ld de, $140F
            call scr_win
            ld bc, $0205
            call pen_at
            ld hl, st_l0
            call pen_str
            ld bc, $020A
            call pen_at
            ld hl, st_h0
            call pen_str
            ld bc, $020C
            call pen_at
            ld hl, st_h1
            call pen_str
            ld bc, $020E
            call pen_at
            ld hl, st_h2
            call pen_str
            call .num
            call scr_show
.l:         ld bc, $0805                    ; (the hand before the number)
            call cur_txt
            call scr_frame
            ldh a, [pad_new]
            bit 1, a
            jr nz, .x
            bit 0, a
            jr nz, .play
            ld b, 1
            bit 4, a
            jr nz, .ch
            ld b, ST_N - 1
            bit 5, a
            jr z, .l
.ch:        ld a, [st_i]                    ; (wraps)
            add a, b
            cp ST_N
            jr c, .s
            sub ST_N
.s:         ld [st_i], a
            call .num
            call scr_upd
            jr .l
.play:      ld a, [st_i]
            add a, ST_FIRST
            call snd_track
            jr .l
.x:         ret
.num:       ld bc, $0A05                    ; the song's number, 01-24, and its count
            call pen_at
            ld a, [st_i]
            inc a
            call nf_a
            ld b, 2
            call pen_num
            ld hl, st_of
            jp pen_str
st_title:   db "Sound Test", 0
st_l0:      db "Song", 0
st_of:      db " / 24", 0
st_h0:      db "Left/Right: song", 0
st_h1:      db "A Button: play", 0
st_h2:      db "B Button: back", 0

; ---- the bestiary: the 128 monsters in FF1's order, the ones met in battle by name (kept in
; cart RAM bank 1 for every save file; Lot Check: cart RAM on only meanwhile); A on a met one:
; its battle picture (FF1's graphics and colours from the user's ROM, drawn by the battle's
; own loaders) and its stats from the ROM; left / right the next met one, B back
BS_RAM     = $BF80          ; "BE", 16 bytes (a bit per enemy id), a check (xor, $5A)
BS_TAB     = $6800          ; BTL_DATA (battle.py bestiary_tab): formation, egp, type, 0
BS_ROWS    = 13
bs_cur     = bt_sbuf        ; (battle scratch: free outside battle)
bs_top     = bt_sbuf + 1
bs_hold    = bt_sbuf + 2
bs_col     = bt_sbuf + 3
bs_bits    = bt_sbuf + 4    ; 16
bs_bv      = bt_sbuf + 20
bs_maxr    = bt_sbuf + 21
bs_rec     = bt_sbuf + 24   ; 4
bs_x0      = bt_sbuf + 28
bs_y0      = bt_sbuf + 29
bs_x1      = bt_sbuf + 30
bs_y1      = bt_sbuf + 31
bs_ax      = bt_sbuf + 32   ; the picture's area: x, y, width, height
bs_ay      = bt_sbuf + 33
bs_aw      = bt_sbuf + 34
bs_ah      = bt_sbuf + 35
bs_w       = bt_sbuf + 36
bs_h       = bt_sbuf + 37
BS_NM      = bt_stage + 200 ; a name (20)
BS_ST      = bt_stage + 232 ; the stats (20)
BS_ART     = $C500          ; the picture's cells (tile, attribute; GR_A / GR_B: only used
                            ;   from scr_show on)

bs_main:    call bs_load
            xor a
            ld [bs_cur], a
            ld [bs_top], a
.re:        call bs_lscr
.l:         ld a, [bs_cur]                  ; the hand before the name
            ld b, a
            ld a, [bs_top]
            ld c, a
            ld a, b
            sub c
            add a, 4
            ld c, a
            ld b, 3
            call cur_txt
            call scr_frame
            call bs_pad
            bit 1, a
            ret nz
            bit 0, a
            jr nz, .a
            ld b, a
            ld a, [bs_cur]
            bit 7, b
            jr nz, .dn
            bit 6, b
            jr nz, .up
            bit 4, b
            jr nz, .pd
            bit 5, b
            jr z, .l
            sub BS_ROWS
            jr nc, .mv
            xor a
            jr .mv
.pd:        add a, BS_ROWS
            cp 128
            jr c, .mv
            ld a, 127
            jr .mv
.dn:        inc a
            jr .w
.up:        dec a
.w:         and $7F
.mv:        ld [bs_cur], a
            ld a, [bs_top]
            push af
            call bs_fix
            pop bc
            ld a, [bs_top]
            cp b
            jr z, .l
            call bs_names                   ; (scrolled: the names again)
            call scr_upd
            jr .l
.a:         ld a, [bs_cur]
            call bs_seen
            jr z, .l
            call bs_entry
            jr .re

; the directions repeat while held (20 frames, then every 4)
bs_pad:     ldh a, [pad]
            and $F0
            jr z, .z
            ldh a, [pad_new]
            and $F0
            jr nz, .z
            ld hl, bs_hold
            inc [hl]
            ld a, [hl]
            cp 20
            jr c, .n
            ld [hl], 16
            ld a, SFX_MOVE
            ld [sfx_req], a
            ldh a, [pad]
            and $F0
            ld b, a
            ldh a, [pad_new]
            or b
            ret
.z:         xor a
            ld [bs_hold], a
.n:         ldh a, [pad_new]
            ret

; bs_top so that bs_cur is among the 13 rows shown
bs_fix:     ld a, [bs_cur]
            ld b, a
            ld a, [bs_top]
            cp b
            jr z, .x
            jr c, .lo
            ld a, b
            jr .s
.lo:        add a, BS_ROWS - 1
            cp b
            ret nc
            ld a, b
            sub BS_ROWS - 1
.s:         ld [bs_top], a
.x:         ret

; enemy A met? NZ if so
bs_seen:    ld b, a
            and 7
            ld c, a
            ld a, b
            rrca
            rrca
            rrca
            and $0F
            ld e, a
            ld d, 0
            ld hl, bs_bits
            add hl, de
            ld a, [hl]
            inc c
.s:         dec c
            jr z, .t
            rrca
            jr .s
.t:         and 1
            ret

; the list screen
bs_lscr:    call bs_fix
            call scr_open
            ld bc, $0000
            ld de, $1403
            call scr_win
            ld bc, $0101
            call pen_at
            ld hl, bs_title
            call pen_str
            ld bc, $0C01                    ; met / 128
            call pen_at
            ld hl, bs_bits
            ld c, 16
            ld e, 0
.b:         ld a, [hl+]
            ld b, 8
.i:         rrca
            jr nc, .n
            inc e
.n:         dec b
            jr nz, .i
            dec c
            jr nz, .b
            ld a, e
            call nf_a
            ld b, 3
            call pen_num
            ld hl, bs_of
            call pen_str
            ld bc, $0003
            ld de, $140F
            call scr_win
            call bs_names
            jp scr_show
; the 13 rows of names from bs_top
bs_names:   xor a
.r:         push af
            add a, 4
            ld c, a
            ld b, 3
            call pen_at
            pop af
            push af
            ld b, a
            ld a, [bs_top]
            add a, b
            push af
            call bs_seen
            jr z, .u
            pop af
            call bs_name
            ld hl, BS_NM
            jr .w
.u:         pop af
            ld hl, bs_unk
.w:         ld b, 15
.c:         ld a, [hl]
            and a
            jr z, .sp
            inc hl
            call pen_ch
            dec b
            jr nz, .c
            jr .e
.sp:        ld a, $20
            call pen_ch
            dec b
            jr nz, .sp
.e:         pop af
            inc a
            cp BS_ROWS
            jr c, .r
            ret
; enemy A's name -> BS_NM
bs_name:    ld l, a
            ld h, 0
            add hl, hl
            ld de, B_NAMES
            add hl, de
            ld de, BS_NM
            ld bc, 2
            ld a, BTL_DATA
            call far_copy
            ld a, [BS_NM]
            ld l, a
            ld a, [BS_NM + 1]
            ld h, a
            ld de, BS_NM
            ld bc, 20
            ld a, BTL_DATA
            jp far_copy
bs_title:   db "Bestiary", 0
bs_of:      db "/128", 0
bs_unk:     db "- - - - -", 0

; ---- an entry: the picture and the stats (Chaos: the picture over the top 12 rows)
bs_entry:   call scr_open
            ld a, [bs_cur]                  ; the stats
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            ld d, h
            ld e, l
            add hl, hl
            add hl, hl
            add hl, de
            ld de, B_STATS
            add hl, de
            ld de, BS_ST
            ld bc, 20
            ld a, BTL_DATA
            call far_copy
            ld a, [bs_cur]                  ; its record: formation, egp, type
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            ld de, BS_TAB
            add hl, de
            ld de, bs_rec
            ld bc, 4
            ld a, BTL_DATA
            call far_copy
            ld a, [bs_rec + 2]
            cp 4
            jr z, .ch
            ld bc, $0003                    ; others: the picture in cols 0-7, rows 3-10
            ld de, $0808
            call bs_art
            ld bc, $0000
            ld de, $1403
            call scr_win
            ld bc, $0101
            call pen_at
            ld a, [bs_cur]
            call bs_name
            ld hl, BS_NM
            call pen_str
            ld bc, $0803
            ld de, $0C08
            call scr_win
            ld hl, bs_lab                   ; HP, Attack, Defense, Evade, EXP, Gil
            ld bc, $0904
            call pen_at
            call pen_str
            ld bc, $0E04
            ld hl, BS_ST + E_HPMAX
            call bs_n5
            ld bc, $1005
            ld a, [BS_ST + E_DMG]
            call bs_n3
            ld bc, $1006
            ld a, [BS_ST + E_ABSORB]
            call bs_n3
            ld bc, $1007
            ld a, [BS_ST + E_EVADE]
            call bs_n3
            ld bc, $0E08
            ld hl, BS_ST + E_EXP
            call bs_n5
            ld bc, $0E09
            ld hl, BS_ST + E_GP
            call bs_n5
            ld bc, $000B
            ld de, $1407
            call scr_win
            ld a, 16
            ld [bs_maxr], a
            ld c, 12
            ld a, [BS_ST + E_WEAK]
            ld hl, bs_weak
            ld de, bs_elem
            call bs_lst
            ld a, [BS_ST + E_RESIST]
            ld hl, bs_res
            ld de, bs_elem
            call bs_lst
            ld a, [BS_ST + E_CAT]           ; (only the two traits whose meaning is sure:
            and $88                         ;   Undead (Harm / Dia), Regen (HP back each
            ld hl, bs_type                  ;   round); the family bits are left out)
            ld de, bs_cats
            call nz, bs_lst
            jr .sh
.ch:        ld bc, $0000                    ; Chaos: the picture over rows 0-11
            ld de, $140C
            call bs_art
            ld bc, $000C
            ld de, $1406
            call scr_win
            ld bc, $010D
            call pen_at
            ld a, [bs_cur]
            call bs_name
            ld hl, BS_NM
            call pen_str
            ld bc, $010E
            call pen_at
            ld hl, bs_hp
            call pen_str
            ld bc, $030E
            ld hl, BS_ST + E_HPMAX
            call bs_n5
            ld bc, $090E
            call pen_at
            ld hl, bs_atk
            call pen_str
            ld bc, $100E
            ld a, [BS_ST + E_DMG]
            call bs_n3
            ld a, 15
            ld [bs_maxr], a
            ld c, 15
            ld a, [BS_ST + E_WEAK]
            ld hl, bs_weak
            ld de, bs_elem
            call bs_lst
            ld a, 16
            ld [bs_maxr], a
            ld c, a
            ld a, [BS_ST + E_RESIST]
            ld hl, bs_res
            ld de, bs_elem
            call bs_lst
.sh:        call scr_show
.l:         call scr_frame
            ldh a, [pad_new]
            bit 1, a
            ret nz
            ld b, 1
            bit 4, a
            jr nz, .mv
            ld b, $FF
            bit 5, a
            jr z, .l
.mv:        ld a, [bs_cur]                  ; the next met one that way (wraps)
            ld e, a
            ld c, 127
.nx:        add a, b
            and $7F
            push af
            push bc
            push de
            call bs_seen
            pop de
            pop bc
            jr nz, .f
            pop af
            dec c
            jr nz, .nx
            jr .l
.f:         pop af
            ld [bs_cur], a
            jp bs_entry
; the number at [HL] (2 bytes) in 5 digits at cell (B, C); A in 3
bs_n5:      push hl
            call pen_at
            pop hl
            call nf_w
            ld b, 5
            jp pen_num
bs_n3:      push af
            call pen_at
            pop af
            call nf_a
            ld b, 3
            jp pen_num
; a list: label HL at (1, C), the names (table DE) of the bits of A from column 8, wrapped
; (rows up to bs_maxr); "None" / "All"; C -> the next row
bs_lst:     ld [bs_bv], a
            push de
            push bc
            push hl
            ld b, 1
            call pen_at
            pop hl
            call pen_str
            pop bc
            pop de
            ld a, 8
            ld [bs_col], a
            ld a, [bs_bv]
            and a
            ld hl, bs_none
            jr z, .one
            inc a
            ld hl, bs_all
            jr z, .one
            ld b, 8
.k:         ld a, [bs_bv]
            rrca
            ld [bs_bv], a
            jr nc, .nk
            ld a, [de]                      ; the name, its length
            ld l, a
            inc de
            ld a, [de]
            ld h, a
            dec de
            push hl
            push bc
            ld b, 0
.ln:        ld a, [hl+]
            and a
            jr z, .lt
            inc b
            jr .ln
.lt:        ld a, [bs_col]                  ; fits on this row? (up to column 18)
            add a, b
            cp 20
            jr c, .ft
            ld a, [bs_maxr]
            cp c
            jr z, .full
            inc c
            ld a, 8
            ld [bs_col], a
            add a, b
.ft:        inc a
            ld [bs_col], a                  ; (the next word's column)
            sub b
            dec a
            ld b, a                         ; B = this word's column, C = the row
            pop af                          ; (A: the bits left; the old row dropped)
            pop hl                          ; the name
            push af
            push bc
            push de
            call pen_at
            call pen_str
            pop de
            pop bc
            pop af
            ld b, a
            jr .nk
.full:      pop bc
            pop hl
            jr .x
.nk:        inc de
            inc de
            dec b
            jr nz, .k
.x:         inc c
            ret
.one:       push bc
            ld b, 8
            call pen_at
            call pen_str
            pop bc
            inc c
            ret
bs_lab:     db "HP", $0A, "Attack", $0A, "Defense", $0A, "Evade", $0A, "EXP", $0A, "Gil", 0
bs_hp:      db "HP", 0
bs_atk:     db "Attack", 0
bs_weak:    db "Weak", 0
bs_res:     db "Resist", 0
bs_type:    db "Trait", 0
bs_none:    db "None", 0
bs_all:     db "All", 0
bs_elem:    dw .e0, .e1, .e2, .e3, .e4, .e5, .e6, .e7     ; FF1's element bits
.e0:        db "Status", 0
.e1:        db "Stone", 0
.e2:        db "Time", 0
.e3:        db "Death", 0
.e4:        db "Fire", 0
.e5:        db "Ice", 0
.e6:        db "Bolt", 0
.e7:        db "Earth", 0
bs_cats:    dw .c0, .c0, .c0, .c3, .c0, .c0, .c0, .c7     ; FF1's enemy categories $08 / $80
.c0:        db 0
.c3:        db "Undead", 0
.c7:        db "Regen", 0

; ---- the picture of enemy [bs_cur] (record bs_rec) centred in the area B, C, D x E (LCD off):
; FF1's formation that shows it through the battle's own loaders (tiles $12-$7F at $9120,
; DMG shading, positions, fiend / Chaos TSA), then the tiles moved to $8920 ($92-$FF: the
; font stays at $9000) and the cells into the area
bs_art:     ld a, b
            ld [bs_ax], a
            ld a, c
            ld [bs_ay], a
            ld a, d
            ld [bs_aw], a
            ld a, e
            ld [bs_ah], a
            ld a, [bs_rec + 2]
            cp $FF
            ret z
            ld a, [bs_rec]                  ; the formation
            ld [btl_fid], a
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, B_FORM
            add hl, de
            ld de, bt_form
            ld bc, 16
            ld a, BTL_DATA
            call far_copy
            ld hl, bt_eid
            ld b, 9
            ld a, $FF
.ce:        ld [hl+], a
            dec b
            jr nz, .ce
            ld a, [bs_cur]
            ld [bt_eid], a
            ld a, [bs_rec + 1]
            ld [bt_egp], a
            ld a, [bs_rec + 2]
            cp 3
            jr nc, .t
            xor a                           ; (alone: slot 0 of a 9-small battle)
.t:         ld [bt_type], a
            ld hl, smap                     ; rows 0-11 empty
            ld b, 12
            xor a
            call fill32
            ld hl, sattr
            ld b, 12
            xor a
            call fill32
            ld a, BTL_BANK
            ld hl, bt_enemy_gfx
            call bank_call
            ld a, BTL_BANK
            ld hl, bt_enemy_map
            call bank_call
            ld hl, $9120                    ; the tiles to $8920
            ld de, $8920
            ld bc, $6E0
            call memcpy
            ldh a, [is_cgb]
            and a
            jr nz, .pal
            ld a, COMMON                    ; DMG: the font back
            ld hl, C_FONTDMG + $120
            ld de, $9120
            ld bc, $6E0
            call far_copy
            jr .box
.pal:       ld a, $80 | 8                   ; CGB: BG palettes 1 / 2 the formation's
            call bcps_w
            ld a, [bt_form + 10]
            call bs_bp
            ld a, [bt_form + 11]
            call bs_bp
.box:       ld a, $FF                       ; the cells used: their box
            ld [bs_x0], a
            ld [bs_y0], a
            xor a
            ld [bs_x1], a
            ld [bs_y1], a
            ld c, 0
.r:         ld b, 0
.c:         call cell_addr
            ld a, [hl]
            and a
            jr z, .n
            ld a, [bs_x0]
            cp b
            jr c, .k1
            ld a, b
            ld [bs_x0], a
.k1:        ld a, [bs_y0]
            cp c
            jr c, .k2
            ld a, c
            ld [bs_y0], a
.k2:        ld a, b
            ld hl, bs_x1
            cp [hl]
            jr c, .k3
            ld [hl], a
.k3:        ld a, c
            ld hl, bs_y1
            cp [hl]
            jr c, .n
            ld [hl], a
.n:         inc b
            ld a, b
            cp 16
            jr c, .c
            inc c
            ld a, c
            cp 12
            jr c, .r
            ld a, [bs_x0]
            cp $FF
            jr z, .clr
            ld b, a
            ld a, [bs_x1]
            sub b
            inc a
            ld [bs_w], a
            ld a, [bs_y0]
            ld c, a
            ld a, [bs_y1]
            sub c
            inc a
            ld [bs_h], a
            ld de, BS_ART                   ; the box -> BS_ART (tile, attribute)
            ld a, [bs_h]
.cr:        push af
            push bc
            ld a, [bs_w]
.cc:        push af
            call cell_addr
            ld a, [hl]
            ld [de], a
            inc de
            inc h
            inc h
            inc h
            ld a, [hl]
            ld [de], a
            inc de
            inc b
            pop af
            dec a
            jr nz, .cc
            pop bc
            inc c
            pop af
            dec a
            jr nz, .cr
            call .clr
            ld a, [bs_aw]                   ; centred in the area
            ld hl, bs_w
            sub [hl]
            srl a
            ld hl, bs_ax
            add a, [hl]
            ld b, a
            ld a, [bs_ah]
            ld hl, bs_h
            sub [hl]
            srl a
            ld hl, bs_ay
            add a, [hl]
            ld c, a
            ld de, BS_ART
            ld a, [bs_h]
.wr:        push af
            push bc
            ld a, [bs_w]
.wc:        push af
            call cell_addr
            ld a, [de]                      ; tile: $12- -> + $80; else the black blank
            inc de
            cp $12
            jr c, .bl
            add a, $80
            ld [hl], a
            inc h
            inc h
            inc h
            ld a, [de]
            inc de
            cp 1
            jr z, .at
            cp 2
            jr z, .at
            ld a, 5                         ; (palette 0 / 3 cells: black)
.at:        ld [hl], a
            jr .wn
.bl:        inc de
            ld [hl], $20
            inc h
            inc h
            inc h
            ld [hl], BLK_ATTR
.wn:        inc b
            pop af
            dec a
            jr nz, .wc
            pop bc
            inc c
            pop af
            dec a
            jr nz, .wr
            ret
.clr:       ld hl, smap                     ; rows 0-11 blank again
            ld b, 12
            ld a, $20
            call fill32
            ld hl, sattr
            ld b, 12
            ld a, BLK_ATTR
            jp fill32
; battle palette A (4 NES colours, colour 0 the black) -> the next CGB BG palette
bs_bp:      ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            ld de, B_PALS
            add hl, de
            ld de, scr_buf
            ld bc, 4
            ld a, BTL_DATA
            call far_copy
            ld a, $0F
            ld [scr_buf], a
            ld hl, scr_buf
            ld b, 4
.c:         ld a, [hl+]
            push hl
            push bc
            and $3F
            ld l, a
            ld h, 0
            add hl, hl
            ld de, C_NESRGB
            add hl, de
            ld de, scr_buf + 28
            ld bc, 2
            ld a, COMMON
            call far_copy
            ld a, [scr_buf + 28]
            ld e, a
            ld a, [scr_buf + 29]
            ld d, a
            call cc_fix
            ld a, e
            call bcpd_w
            ld a, d
            call bcpd_w
            pop bc
            pop hl
            dec b
            jr nz, .c
            ret

; ---- cart RAM: the met enemies (bs_load: into bs_bits; bs_mark: from a battle's bt_eid)
bs_on:      ld a, $0A
            ld [$0000], a
            ld a, 1
            ld [$4000], a
            ret
bs_off:     xor a
            ld [$0000], a
            ld [$4000], a
            ret
; Z if the record is whole (HL -> its check byte, C the sum)
bs_chk:     ld hl, BS_RAM
            ld a, [hl+]
            cp $42
            ret nz
            ld a, [hl+]
            cp $45
            ret nz
            ld b, 16
            ld c, $5A
.c:         ld a, [hl+]
            xor c
            ld c, a
            dec b
            jr nz, .c
            ld a, [hl]
            cp c
            ret
bs_load:    call bs_on
            call bs_chk
            ld hl, BS_RAM + 2
            ld de, bs_bits
            ld b, 16
            jr z, .c
            ld hl, bs_zero
.c:         ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .c
            jp bs_off
bs_zero:    db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
bs_mark:    call bs_on
            call bs_chk
            jr z, .ok
            ld hl, BS_RAM                   ; (none yet, or damaged: a new record)
            ld a, $42
            ld [hl+], a
            ld a, $45
            ld [hl+], a
            ld b, 17
            xor a
.z:         ld [hl+], a
            dec b
            jr nz, .z
.ok:        ld de, bt_eid
            ld c, 9
.e:         ld a, [de]
            inc de
            cp $80
            jr nc, .n
            push bc
            ld b, a
            and 7
            ld c, a
            ld a, b
            rrca
            rrca
            rrca
            and $0F
            add a, low(BS_RAM + 2)
            ld l, a
            ld h, high(BS_RAM)
            ld a, 1
            inc c
.s:         dec c
            jr z, .d
            add a, a
            jr .s
.d:         or [hl]
            ld [hl], a
            pop bc
.n:         dec c
            jr nz, .e
            call bs_chk
            ld [hl], c
            jp bs_off

; ---- a save page from the builds whose sound variables ran into it ($D000-$D004, until
; 2026-11-24): the ship's and the airship's flags not 0 / 1 are mended (the ship: given if the
; pirates were fought, at FF1's starting place; the airship: not found), so an old save plays on
sv_fix:     ld a, [KN_MARK]                 ; (a file without the Konami Code: the LCD
            cp $A5                          ;   colours Default, the option hidden; owner,
            jr z, .k                        ;   2026-11-24)
            xor a
            ld [opt_ccm], a
.k:         ld a, [SV_SHIP]
            cp 2
            jr c, .air
            ld a, [game_flags + 4]          ; (Bikke's event flag: bit 1)
            rrca
            rrca
            and 1
            ld [SV_SHIP], a
            ld a, COMMON                    ; (the ship's place: the ROM's new-game page)
            ld hl, C_INITPG + 1
            ld de, SV_SHIP + 1
            ld bc, 2
            call far_copy
.air:       ld a, [SV_AIR]
            cp 2
            ret c
            xor a
            ld [SV_AIR], a
            ret

; the title menu's up / down: Continue 0, New Game 1, Extras 3 (Continue left out while there is
; nothing to continue)
ng_ud:      ldh a, [pad_new]
            ld b, a
            ld a, [ng_cur]
            bit 6, b
            jr nz, .u
            inc a
            cp 2
            jr nz, .d1
            inc a
.d1:        cp 4
            jr c, .z
            xor a
            jr .z
.u:         dec a
            cp 2
            jr nz, .u1
            dec a
.u1:        cp $FF
            jr nz, .z
            ld a, 3
.z:         and a
            jr nz, .s
            ld a, [ng_lock]
            and a
            ld a, 0
            jr z, .s
            bit 6, b
            ld a, 3
            jr nz, .s
            ld a, 1
.s:         ld [ng_cur], a
            ret

section bank 0, $17B0
; the battle's enemies generated, then the met ones marked (bs_mark)
bs_seen0:   call bt_prep
            ld a, EXTRA_BANK
            ld hl, bs_mark
            jp bank_call

section bank 0, $17C0                       ; (moved from text.s: its section was full)
; the encounter transition (STAT mode 0 each line; A = hrx): the next line's SCX and SCY from
; the frame's tables (page hrx: SCX by line, page hrx + 1: SCY), indexed by the line itself, so
; nothing moves and a frame that takes longer only shows the same table again. Kept short:
; ~47 cycles a line (the plain Game Boy took two frames a step with the pointer version)
stat_rx:    push hl
            ld h, a
            ldh a, [rLY]
            inc a
            ld l, a
            ld a, [hl]
            ldh [rSCX], a
            inc h
            ld a, [hl]
            ldh [rSCY], a
            pop hl
            pop af
            reti

section wram, $C996
ex_cur:     ds 1
st_i:       ds 1
