; FF1 native engine: place names (owner, 2026-11-22, from the WonderSwan Color remake): a banner
; with the place's name when the party enters a new place (not the world map), the place on the
; main menu; and the play time. Our own code; the names: ui.py LOC_NAMES (bank 99 $7000).

BN_LINES   = 24             ; the banner: window rows 0-2 (LYC cuts it at line 24)
BN_TIME    = 150            ; shown 2.5 seconds
LOC_WORLD  = 27             ; (loc_tab: "World Map", the main menu only)
PT_SAVE    = unsram + $F0   ; play time in the save page (unused by FF1): frames, seconds,
                            ;   minutes, hours (to 99)

section bank 99, $4700

; ---- a new place entered (load_map, the main loop calls it once the map shows): the banner
bn_prep:    ld a, [cur_map]
            call loc_get
            ld b, a
            inc a                           ; (bn_last: the place + 1, 0 none yet)
            ld c, a
            ld a, [bn_last]
            cp c
            ret z
            ld a, c
            ld [bn_last], a
            ld a, b
            cp LOC_WORLD
            ret z
            push hl
            ld hl, win_buf                  ; the box: 3 rows of 20
            ld bc, $1011
            ld d, $12
            call .row
            ld bc, $1318
            ld d, $14
            call .row
            ld bc, $1516
            ld d, $17
            call .row
            pop de                          ; the name, centred on row 1
            ld h, d
            ld l, e
            ld b, 0
.n:         ld a, [hl+]
            and a
            jr z, .nn
            inc b
            jr .n
.nn:        ld a, 18
            sub b
            srl a
            add a, low(win_buf + 21)
            ld l, a
            ld h, high(win_buf)
.c:         ld a, [de]
            inc de
            and a
            jr z, .go
            call code_tile
            ld [hl+], a
            jr .c
.go:        xor a
            ld [win_up], a
            ld a, BN_LINES
            ldh [rLYC], a
            ld a, BN_TIME
            ld [bn_t], a
            ret
.row:       ld a, b                         ; B, C x 18, D
            call code_tile
            ld [hl+], a
            ld a, c
            call code_tile
            ld e, 18
.r:         ld [hl+], a
            dec e
            jr nz, .r
            ld a, d
            call code_tile
            ld [hl+], a
            ret

; map A -> A = name number, HL = the name
loc_get:    cp 61
            ld b, LOC_WORLD
            jr nc, .w
            ld e, a
            ld d, 0
            ld hl, loc_tab
            add hl, de
            ld b, [hl]
.w:         ld l, b
            ld h, 0
            add hl, hl
            ld de, loc_ptr
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld a, b
            ret

; the current place's name -> loc_buf (for the main menu: bank_call from bank 2)
loc_copy:   ld a, [cur_map]
            call loc_get
            ld de, loc_buf
.c:         ld a, [hl+]
            ld [de], a
            inc de
            and a
            jr nz, .c
            ret

section bank 2, $4710                       ; (the main menu's place / play time rows)
; the place (row 14) and the play time (row 15, h:mm ending at column 18)
mm_place:   ld a, F3_BANK
            ld hl, loc_copy
            call bank_call
            ld bc, $010E
            call pen_at
            ld hl, loc_buf
            call pen_str
            ld bc, $010F
            call pen_at
            ld hl, str_ptime
            call pen_str
            ld a, [PT_SAVE + 3]             ; hours: tens, ones
            ld c, 0
.h:         cp 10
            jr c, .h1
            sub 10
            inc c
            jr .h
.h1:        ld e, a
            ld a, c
            and a
            ld b, 15                        ; (h:mm from column 15, hh:mm from 14)
            jr z, .p
            dec b
.p:         push bc
            push de
            ld c, $0F
            call pen_at
            pop de
            pop bc
            ld a, c
            and a
            jr z, .o
            add a, $30
            call pen_ch
.o:         ld a, e
            add a, $30
            call pen_ch
            ld a, $3A
            call pen_ch
            ld a, [PT_SAVE + 2]             ; minutes, two digits
            ld c, 0
.m:         cp 10
            jr c, .m1
            sub 10
            inc c
            jr .m
.m1:        ld e, a
            ld a, c
            add a, $30
            call pen_ch
            ld a, e
            add a, $30
            jp pen_ch

section bank 2, $5FB0                       ; (the Items screen's list and drawing)
; A = list index -> A = its page / its row in the page
it_page:    ld b, 0
.p:         cp IT_PAGE
            jr c, .x
            sub IT_PAGE
            inc b
            jr .p
.x:         ld a, b
            ret
it_row:     cp IT_PAGE
            ret c
            sub IT_PAGE
            jr it_row

; the page's items -> it_box, it_n: the consumables (FF1's order, or healing first after Sort),
; or the key items $01-$11 (orbs never listed)
it_list:    ld de, it_box
            ld c, 0
            ld a, [it_mode]
            and a
            jr nz, .key
            ld hl, it_ord0
            ld a, [IT_SORT]
            and a
            jr z, .o
            ld hl, it_ord1
.o:         ld b, 6
.ol:        ld a, [hl+]
            push hl
            ld l, a
            add a, low(ITEMS)
            ld h, a
            ld a, l
            ld l, h
            ld h, high(ITEMS)
            push af
            ld a, [hl]
            and a
            jr z, .on
            pop af
            ld [de], a
            inc de
            inc c
            jr .oc
.on:        pop af
.oc:        pop hl
            dec b
            jr nz, .ol
            jr .x
.key:       ld hl, ITEMS + 1
            ld b, 1
.k:         ld a, [hl+]
            and a
            jr z, .kn
            ld a, b
            ld [de], a
            inc de
            inc c
.kn:        inc b
            ld a, b
            cp $12
            jr c, .k
.x:         ld a, c
            ld [it_n], a
            ret
it_ord0:    db $16, $17, $18, $19, $1A, $1B
it_ord1:    db $19, $1A, $1B, $16, $17, $18

; the item screen (the page of it_cur) into the map copy
it_draw:    call scr_cls
            xor a
            ld [it_desc], a
            ld bc, $0000                    ; commands
            ld de, $0C05
            call scr_win
            ld bc, $0B00                    ; title, Gil
            ld de, $0905
            call scr_win
            ld bc, $0004                    ; the list
            ld de, $140E
            call scr_win
            ld bc, $0201
            call pen_at
            ld hl, str_ituse
            call pen_str
            ld bc, $0202
            call pen_at
            ld hl, str_itsort
            call pen_str
            ld bc, $0203
            call pen_at
            ld hl, str_itkey
            call pen_str
            ld bc, $0C01
            ld hl, str_items
            ld e, 5
            call gold_str
            ld bc, $0C02
            call pen_at
            ld hl, str_gil
            call pen_str
            ld bc, $0D03
            call pen_at
            ld hl, GOLD
            ld a, [hl+]
            ld [nf_val], a
            ld a, [hl+]
            ld [nf_val + 1], a
            ld a, [hl]
            ld [nf_val + 2], a
            ld b, 6
            call pen_num
            ld a, [it_cur]
            call it_page
            ld b, a                         ; first = 12 page
            add a, a
            add a, b
            add a, a
            add a, a
            ld [it_t], a
            ld c, 5
.r:         ld a, [it_t]
            ld hl, it_n
            cp [hl]
            ret nc
            ld e, a
            ld d, 0
            ld hl, it_box
            add hl, de
            ld a, [hl]
            ld [it_id], a
            ld b, 2
            push bc
            call pen_at
            ld a, [it_id]
            call pen_iname
            ld a, [it_id]                   ; consumables: the count
            cp $16
            jr c, .nc
            add a, low(ITEMS)
            ld l, a
            ld h, high(ITEMS)
            ld a, [hl]
            call nf_a
            pop bc
            push bc
            ld b, 17
            call pen_at
            ld b, 2
            call pen_num
.nc:        pop bc
            inc c
            ld hl, it_t
            inc [hl]
            ld a, c
            cp 5 + IT_PAGE
            jr c, .r
            ret

section bank 2, $7180                       ; (the equipment screen's Optimize)
; the hand: Optimize (top right) or the slot row
eqm_ohand:  ld a, [eqm_ot]
            and a
            jr z, .s
            ld bc, $0B03
            jp cur_txt
.s:         ld a, [eqm_t]
            add a, 6
            jp eqm_hand
; up / down through Optimize and the rows in use (eqm_nr)
eqm_oup:    ld a, [eqm_ot]
            and a
            jr nz, .last
            ld a, [eqm_t]
            and a
            jr z, .opt
            dec a
            ld [eqm_t], a
            ret
.last:      xor a
            ld [eqm_ot], a
            ld a, [eqm_nr]
            dec a
            ld [eqm_t], a
            ret
.opt:       ld a, 1
            ld [eqm_ot], a
            ret
eqm_odn:    ld a, [eqm_ot]
            and a
            jr nz, .first
            ld a, [eqm_nr]
            ld b, a
            ld a, [eqm_t]
            inc a
            cp b
            jr nc, eqm_oup.opt
            ld [eqm_t], a
            ret
.first:     xor a
            ld [eqm_ot], a
            ld [eqm_t], a
            ret

; ---- Optimize (owner, 2026-11-22, from the WonderSwan Color remake): the member takes the
; weapon with the best Attack and, one piece at a time, the armour that raises Defense most,
; from its own and the party's packs (the screen's candidates and its preview: applied,
; measured, undone)
eqm_opt:    xor a                           ; the weapon
            ld [eqm_t], a
            call eqm_mkrows
            call eqm_cands
            xor a
            call op_best
            cp $FE
            jr z, .arm
            call eqm_apply
.arm:       ld a, 8                         ; armour: up to 8 improvements
            ld [op_n], a
.al:        ld a, 1
            ld [eqm_t], a
            call eqm_mkrows
            call eqm_cands
            ld a, 2
            call op_best
            cp $FE
            jr z, .done
            ld [op_e], a
            call op_row
            ld a, [op_e]
            call eqm_apply
            ld hl, op_n
            dec [hl]
            jr nz, .al
.done:      xor a
            ld [eqm_t], a
            ld a, SFX_SEL                   ; (the choice sound)
            ld [sfx_req], a
            call eqm_sdraw
            jp scr_upd
section bank 2, $7430                       ; (Optimize: the candidates measured)
; the candidate (eqm_ls) that raises stat A (0 Attack, 2 Defense) most -> A, $FE: none
op_best:    ld [op_k], a
            ld a, [eqm_m]
            call eqm_calc
            call op_v
            ld [op_bv], a
            ld a, $FE
            ld [op_be], a
            xor a
            ld [op_i], a
.l:         ld a, [op_i]
            ld hl, eqm_n
            cp [hl]
            jr nc, .x
            ld e, a
            ld d, 0
            ld hl, eqm_ls
            add hl, de
            ld a, [hl]
            cp $FF
            jr z, .n
            ld [op_e], a
            call eqm_save
            ld a, [op_k]
            and a
            jr z, .w
            ld a, [eqm_t]                   ; armour: in the row of the piece it replaces
            push af
            call op_row
            ld a, [op_e]
            call eqm_apply
            pop af
            ld [eqm_t], a
            jr .c
.w:         ld a, [op_e]
            call eqm_apply
.c:         ld a, [eqm_m]
            call eqm_calc
            call op_v
            ld b, a
            ld a, [op_bv]
            cp b
            jr nc, .r
            ld a, b
            ld [op_bv], a
            ld a, [op_e]
            ld [op_be], a
.r:         call eqm_rest
.n:         ld hl, op_i
            inc [hl]
            jr .l
.x:         ld a, [op_be]
            ret
op_v:       ld a, [op_k]
            ld e, a
            ld d, 0
            ld hl, eqm_v
            add hl, de
            ld a, [hl]
            ret
; armour entry op_e: eqm_t = the row of the worn piece of its type (else the empty row)
op_row:     ld a, 1
            ld [eqm_ft], a
            ld a, [op_e]
            call eqm_mslot
            ld a, [hl]
            and $7F
            dec a
            call eq_atype
            inc a
            call eqm_find
            ld b, a
            ld hl, eqm_rows + 1
            ld c, 1
.s:         ld a, [hl+]
            cp b
            jr z, .f
            inc c
            ld a, c
            cp 5
            jr c, .s
            ld c, 1
.f:         ld a, c
            ld [eqm_t], a
            ret


section bank 0, $2A00                       ; (helpers for every bank: the menus' gold labels
                                            ;   and window palettes, the Options' dash)
gold_str:   push de
            push bc
            push hl
            call pen_at
            call pen_str
            pop hl
            ld d, 1                         ; (its lines)
.n:         ld a, [hl+]
            and a
            jr z, .g
            cp $0A
            jr nz, .n
            inc d
            jr .n
.g:         pop bc
            pop hl
            ld e, l
.r:         push bc
            push de
            call cell_addr
            ld a, h
            add a, 3
            ld h, a
            ld a, $0B
.c:         ld [hl+], a
            dec e
            jr nz, .c
            pop de
            pop bc
            inc c
            dec d
            jr nz, .r
            ret

; Colour: palettes 1 / 2 the window's with green / red text (the preview's better / worse)
eqm_pal:    ld hl, win_pal                  ; (the window colours: the Options' choice)
            ld de, eqm_buf
            ld bc, 8
            call memcpy
            ld a, $2A                       ; NES green
            ld de, eqm_buf + 6
            call .nes
            ld a, $80 | 8
            call .put
            ld a, $26                       ; NES red
            ld de, eqm_buf + 6
            call .nes
            ld a, $80 | 16
            call .put
            ld a, $28                       ; NES yellow: the labels' gold (palette 3)
            ld de, eqm_buf + 6
            call .nes
            ld a, $80 | 24
            call .put
            ld a, $00                       ; NES grey: a choice not open now (palette 4)
            ld de, eqm_buf + 6
            call .nes
            ld a, $80 | 32
.put:       call bcps_w
            ld hl, eqm_buf
            ld b, 8
.p:         ld a, [hl+]
            call bcpd_w
            dec b
            jr nz, .p
            ret
.nes:       add a, a
            ld l, a
            ld h, 0
            ld bc, C_NESRGB
            add hl, bc
            ld bc, 2
            ld a, COMMON
            jp far_copy


; ---- shops (owner, 2026-11-22, from the WonderSwan Color remake): the item under the hand,
; how many the party owns (weapons / armour: and wears) on the speech window's last row
sh_own:     ld a, [sh_cur]
            ld hl, sh_ocur
            cp [hl]
            ret z
            ld [hl], a
            ld a, [sh_sell]
            and a
            ret nz
            ld a, [sh_type]
            cp 2
            jr c, .eq
            cp 6
            ret c                           ; (magic, clinic, inn: none)
            call .it                        ; items: the count held
            ld a, [hl]
            ld b, a
            ld c, $FF
            jr .draw
.eq:        call .it
            and a                           ; A = the shop's kind: weapons 0, armour 1
            ld a, [hl]                      ; (L = id)
            ld e, $1B
            jr z, .w
            ld e, $43
.w:         sub e                           ; FF1's slot number (1-based)
            ld e, a
            ld bc, 0                        ; B owned, C worn
            ld hl, ch_stats + $18
            ld a, [sh_type]
            and a
            jr z, .m0
            ld l, $1C
.m0:        ld d, 4
.m:         push hl
            push de
            ld d, 4
.s:         ld a, [hl+]
            push af
            and $7F
            cp e
            jr nz, .ns
            inc b
            pop af
            push af
            bit 7, a
            jr z, .ns
            inc c
.ns:        pop af
            dec d
            jr nz, .s
            pop de
            pop hl
            ld a, l
            add a, $40
            ld l, a
            dec d
            jr nz, .m
.draw:      push bc
            ld bc, $0104
            call pen_at
            pop bc
            push bc
            ld hl, so_own
            call pen_str
            pop bc
            push bc
            ld a, b
            call nf_a
            ld b, 2
            call pen_num
            pop bc
            ld a, c
            cp $FF
            jr z, .end
            push bc
            ld hl, so_worn
            call pen_str
            pop bc
            ld a, c
            call nf_a
            ld b, 2
            call pen_num
.end:       jp scr_upd
.it:        ld a, [sh_cur]                  ; HL = the item id's cell in sh_list (A = id),
            ld e, a                         ;   then the item's count in the packs; A = kind
            ld d, 0
            ld hl, sh_list
            add hl, de
            ld a, [hl]
            ld e, a
            add a, low(ITEMS)
            ld l, a
            ld h, high(ITEMS)
            ld a, [sh_type]
            cp 2
            ret nc
            ld hl, sh_list                  ; (equipment: HL = the id's cell again)
            ld a, [sh_cur]
            add a, l
            ld l, a
            ld a, h
            adc a, 0
            ld h, a
            ld a, [sh_type]
            ret
so_own:     db "Own ", 0
so_worn:    db "   Worn ", 0

; magic shops: after a member's word, the level's three slots as pips (filled: a spell
; learnt), unless the job can't learn it
sh_pstr:    call pen_str
            ld a, [sh_k]
            call sh_mstat
            cp 1
            ret z
            ld a, [sh_k]
            add a, 7
            ld c, a
            ld b, 16
            call pen_at
            ld a, [sh_k]
            rrca
            rrca
            ld b, a
            ld a, [sh_sp]
            rrca
            and $1C
            add a, b
            ld l, a
            ld h, high(ch_magic)
            ld b, 3
.p:         ld a, [hl+]
            and a
            ld a, $0A
            jr nz, .f
            inc a
.f:         call pen_ch
            dec b
            jr nz, .p
            ret

; the field's dash: Z if B is not held or the Options turned the dash off
dash_b:     ld a, [opt_nodash]
            and a
            jr nz, .no
            ldh a, [pad]
            bit 1, a
            ret
.no:        xor a
            ret

section bank 99, $4800
; ---- Options (owner, 2026-11-22; WonderSwan Color remake's choices added): Message Speed, Text
; Speed, Volume, B Dash On / Off, Cursor Remember / Reset, and on the Color the windows'
; colour (red, green, blue 0-31, shown at once). Header (0,0,20,3), list (0,3,20,15), one row a
; setting from row 5; up / down pick, left / right change, B back (kept in cart RAM bank 1)
OPT_N_DMG  = 5
OPT_N_CGB  = 8
opt_menu:   call scr_open
            call eqm_pal
            ld bc, $0000
            ld de, $1403
            call scr_win
            ld bc, $0101
            ld hl, os_title
            ld e, 7
            call gold_str
            ld bc, $0003
            ld de, $140F
            call scr_win
            call opt_n
            ld b, a
            ld c, 5
            ld hl, os_labels
.lb:        push bc
            push hl
            ld b, 2
            call pen_at
            pop hl
            call pen_str                    ; (HL past the string)
            pop bc
            inc c
            dec b
            jr nz, .lb
            call opt_vals
            call scr_show
            xor a
            ld [opt_cur], a
.l:         ld a, [opt_cur]                 ; the hand at the setting (row 5 + n)
            add a, 5
            ld c, a
            ld b, 2
            call cur_txt
            call scr_frame
            ldh a, [pad_new]
            bit 1, a
            jp nz, opt_save
            ld hl, opt_cur
            bit 6, a
            jr nz, .up
            bit 7, a
            jr nz, .dn
            ld b, 1
            bit 4, a
            jr nz, .ch
            ld b, $FF
            bit 5, a
            jr z, .l
.ch:        ld a, [opt_cur]                 ; B = +1 / -1, clamped
            ld e, a
            ld d, 0
            ld hl, os_max
            add hl, de
            ld c, [hl]
            ld hl, os_var
            add hl, de
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld a, [hl]
            add a, b
            cp c
            jr nc, .l                       ; (past either end: no change)
            ld [hl], a
            call opt_apply
            ld a, [opt_cur]                 ; (a window colour: the palettes at once)
            cp 5
            call nc, opt_wnow
            call opt_vals
            call scr_upd
            jr .l
.up:        call opt_n
            ld b, a
            ld a, [hl]
            dec a
            cp b
            jr c, .s
            ld a, b
            dec a
            jr .s
.dn:        call opt_n
            ld b, a
            ld a, [hl]
            inc a
            cp b
            jr c, .s
            xor a
.s:         ld [hl], a
            jr .l
; settings shown: A = 5 (DMG / SGB) or 8 (Color)
opt_n:      ldh a, [is_cgb]
            and a
            ld a, OPT_N_DMG
            ret z
            ld a, OPT_N_CGB
            ret
os_title:   db "Options", 0
os_labels:  db "Message Speed", 0, "Text Speed", 0, "Volume", 0, "B Dash", 0, "Cursor", 0
            db "Window Red", 0, "Window Green", 0, "Window Blue", 0
os_var:     dw respond, tw_spd, opt_vol, opt_nodash, opt_curr, win_r, win_g, win_b
os_max:     db 8, 5, 8, 2, 2, 32, 32, 32
os_spn:     db "   Slow", " Normal", "   Fast", " Faster", "Instant"
os_dash:    db " On", "Off"
os_cur:     db "Remember", "   Reset"
; the values, ending at column 18
opt_vals:   ld bc, $1205
            call pen_at
            ld a, [respond]
            add a, $31
            call pen_ch
            ld bc, $0C06
            call pen_at
            ld a, [tw_spd]
            ld l, a
            add a, a
            add a, a
            add a, a
            sub l                           ; 7 a name
            ld e, a
            ld d, 0
            ld hl, os_spn
            add hl, de
            ld b, 7
            call .n
            ld bc, $1207
            call pen_at
            ld a, [opt_vol]
            add a, $30
            call pen_ch
            ld bc, $1008
            call pen_at
            ld a, [opt_nodash]
            ld l, a
            add a, a
            add a, l
            ld e, a
            ld d, 0
            ld hl, os_dash
            add hl, de
            ld b, 3
            call .n
            ld bc, $0B09
            call pen_at
            ld a, [opt_curr]
            add a, a
            add a, a
            add a, a
            ld e, a
            ld d, 0
            ld hl, os_cur
            add hl, de
            ld b, 8
            call .n
            ldh a, [is_cgb]
            and a
            ret z
            ld hl, win_r
            ld c, 10
.w:         push hl
            push bc
            ld b, 17
            call pen_at
            pop bc
            pop hl
            ld a, [hl+]
            push hl
            push bc
            call nf_a
            ld b, 2
            call pen_num
            pop bc
            pop hl
            inc c
            ld a, c
            cp 13
            jr c, .w
            ret
.n:         ld a, [hl+]
            call pen_ch
            dec b
            jr nz, .n
            ret
; the volume to the master volume (NR50)
opt_apply:  ld a, [opt_vol]
            ld b, a
            swap a
            or b
            ldh [$FF24], a
            ret
; the windows' palette from win_r / g / b (colour 2 of FF1's window palette)
opt_wpal:   ld a, COMMON
            ld hl, C_WINPAL
            ld de, win_pal
            ld bc, 8
            call far_copy
            ld a, [win_g]                   ; RGB555: r | g << 5 | b << 10
            swap a
            rlca
            and $E0
            ld b, a
            ld a, [win_r]
            or b
            ld [win_pal + 4], a
            ld a, [win_b]
            add a, a
            add a, a
            ld b, a
            ld a, [win_g]
            rrca
            rrca
            rrca
            and 3
            or b
            ld [win_pal + 5], a
            ret
; a colour changed: the palettes now (in V-Blank: palette 7 and the menus' 1-4)
opt_wnow:   call opt_wpal
            call wait_vbl
            call text_pals
            jp eqm_pal
; FF1's window colour -> win_r / g / b (the defaults)
opt_wdef:   ld a, COMMON
            ld hl, C_WINPAL + 4
            ld de, win_r
            ld bc, 2
            call far_copy
            ld a, [win_r]                   ; (low byte, high byte for now)
            ld c, a
            ld a, [win_g]
            ld b, a
            ld a, c
            and $1F
            ld [win_r], a
            ld a, b                         ; g = (high & 3) << 3 | low >> 5
            and 3
            add a, a
            add a, a
            add a, a
            ld d, a
            ld a, c
            swap a
            rrca
            and 7
            or d
            ld [win_g], a
            ld a, b
            rrca
            rrca
            and $1F
            ld [win_b], a
            ret
; the options from cart RAM bank 1 $BF00: "OQ", the eight, a check ("OP": the first three of
; an older save); defaults when not valid (Lot Check: cart RAM on only meanwhile)
OPT_RAM    = $BF00
opt_load:   ld a, 1
            ld [tw_spd], a
            ld a, 7
            ld [opt_vol], a
            xor a
            ld [opt_nodash], a
            ld [opt_curr], a
            call opt_wdef
            ld a, $0A
            ld [$0000], a
            ld a, 1
            ld [$4000], a
            ld hl, OPT_RAM
            ld a, [hl+]
            cp $4F
            jr nz, .x
            ld a, [hl+]
            cp $51
            jr z, .q
            cp $50
            jr nz, .x
            ld a, [hl+]                     ; "OP": respond, text speed, volume, check
            ld b, a
            ld a, [hl+]
            ld c, a
            ld a, [hl+]
            ld d, a
            ld a, b
            xor c
            xor d
            xor $5A
            cp [hl]
            jr nz, .x
            call .set3
            jr .x
.q:         push hl                         ; "OQ": the eight, check
            ld b, 8
            ld c, $5A
.qs:        ld a, [hl+]
            xor c
            ld c, a
            dec b
            jr nz, .qs
            ld a, c
            cp [hl]
            pop hl
            jr nz, .x
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld c, a
            ld a, [hl+]
            ld d, a
            push hl
            call .set3
            pop hl
            jr c, .x
            ld de, opt_nodash               ; dash, cursor, r, g, b (checked: 0-1, 0-31)
            ld b, 5
.q5:        ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .q5
            ld a, [opt_nodash]
            ld b, a
            ld a, [opt_curr]
            or b
            cp 2
            jr c, .qc
            xor a
            ld [opt_nodash], a
            ld [opt_curr], a
.qc:        ld a, [win_r]
            ld b, a
            ld a, [win_g]
            or b
            ld b, a
            ld a, [win_b]
            or b
            cp 32
            call nc, opt_wdef
.x:         xor a
            ld [$0000], a
            ld [$4000], a
            call opt_wpal
            ldh a, [is_cgb]                 ; (the window palette now: boot, LCD off)
            and a
            call nz, text_pals
            jp opt_apply
.set3:      ld a, b                         ; B, C, D in range: respond, speed, volume (C set:
            cp 8                            ;   not)
            jr nc, .bad
            ld a, c
            cp 5
            jr nc, .bad
            ld a, d
            cp 8
            jr nc, .bad
            ld a, b
            ld [respond], a
            ld a, c
            ld [tw_spd], a
            ld a, d
            ld [opt_vol], a
            and a
            ret
.bad:       scf
            ret
opt_save:   ld a, $0A
            ld [$0000], a
            ld a, 1
            ld [$4000], a
            ld hl, OPT_RAM
            ld a, $4F
            ld [hl+], a
            ld a, $51
            ld [hl+], a
            ld de, os_var                   ; the eight values, then the check
            ld b, 8
            ld c, $5A
.s:         push bc
            ld a, [de]
            inc de
            ld c, a
            ld a, [de]
            inc de
            ld b, a
            ld a, [bc]
            pop bc
            ld [hl+], a
            xor c
            ld c, a
            dec b
            jr nz, .s
            ld a, c
            ld [hl], a
            xor a
            ld [$0000], a
            ld [$4000], a
            ret

section wram, $CDE3
loc_buf:    ds 19
pt_on:      ds 1                            ; (play time counted: set by the field's loop)
op_k:       ds 1                            ; (Optimize)
op_bv:      ds 1
op_be:      ds 1
op_i:       ds 1
op_e:       ds 1
op_n:       ds 1
