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
            ld a, BN_LINES - 1
            ldh [rLYC], a
            ld a, BN_TIME
            ld [bn_t], a
            ld a, 3                         ; (its gradient)
            ld [gr_cut], a
            jp gr_box
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
eqm_pal:    ld a, F3_BANK                   ; (body: eqm_palf, bank 99)
            ld hl, eqm_palf
            jp bank_call



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

; ---- the Magic screen (owner, 2026-11-22, from the WonderSwan Color remake): SELECT forgets
; the spell under the hand, after a question; the hint in a window below the list
mg_hint:    ld bc, $000F
            ld de, $1403
            call scr_win
            ld bc, $0110
            call pen_at
            ld hl, mf_hint
            jp pen_str
mg_forget:  call mg_lvsl                    ; B = level, A = slot
            ld c, a
            call mg_data                    ; HL = the member's magic data
            ld a, b
            add a, a
            add a, a
            add a, c
            add a, l
            ld l, a
            ld a, [hl]
            and a
            jr nz, .q
            call sfx_err                    ; (an empty slot)
            jp magic_menu.l
.q:         push hl
            ld c, a                         ; the spell's name id: $AF + 8 level + spell
            ld a, b
            add a, a
            add a, a
            add a, a
            add a, c
            add a, $AF
            push af
            ld bc, $0009
            ld de, $1409
            call scr_win
            ld bc, $010A
            call pen_at
            ld hl, mf_q1
            call pen_str
            pop af
            call pen_iname
            ld a, $3F
            call pen_ch
            ld bc, $010C
            call pen_at
            ld hl, mf_q2
            call pen_str
            ld bc, $010D
            call pen_at
            ld hl, mf_q3
            call pen_str
            call scr_upd
            call wait_ab
            pop hl
            jr c, .no
            ld [hl], 0                      ; forgotten
            ld a, SFX_SEL
            ld [sfx_req], a
.no:        call mg_draw
            jp magic_menu.l
mf_hint:    db "SELECT: Forget", 0
mf_q1:      db "Forget ", 0
mf_q2:      db "A Button: Yes", 0
mf_q3:      db "B Button: No", 0

; ---- three save files (owner, 2026-11-22, from the WonderSwan Color remake): file k at cart RAM
; bank 0 $A000 + $410 k ("FF1N", the save page, the sum: file 1 where the single save was)
sv_addr:    ld a, [sv_slot]
            add a, a
            add a, a
            add a, $A0
            ld h, a
            ld a, [sv_slot]
            swap a
            ld l, a
            ret
sv_addr4:   call sv_addr
            ld a, l
            add a, 4
            ld l, a
            ret
; NC if any file holds a good save
sv_any:     xor a
.l:         ld [sv_slot], a
            call save_valid
            ret nc
            ld a, [sv_slot]
            inc a
            cp 3
            jr c, .l
            xor a                           ; (none: file 1 for the hand)
            ld [sv_slot], a
            scf
            ret
; boot (from bank 2): each damaged file, Lot Check's error message, erased after the A Button
sv_boot:    xor a
.l:         ld [sv_slot], a
            call save_state
            cp 2
            jr nz, .n
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
.w:         call scr_frame
            ldh a, [pad_new]
            bit 0, a
            jr z, .w
            call save_erase
.n:         ld a, [sv_slot]
            inc a
            cp 3
            jr c, .l
            xor a
            ld [sv_slot], a
            ret
; the picker in bank 99: C set if cancelled
file_load:  xor a
            jr file_go
file_save:  ld a, 1
file_go:    ld [fp_mode], a
            ld a, F3_BANK
            ld hl, file_pick
            jp bank_call
; the inn (bank 2): the picker, then the shop's screen again
sh_fsave:   call file_save
            call scr_open
            call eqm_pal
            call sh_base
            jp scr_show

; the Options saved (from the title, bank 2)
opt_save0:  ld a, F3_BANK
            ld hl, opt_save
            jp bank_call

; teleport A (0-63 normal, $80 + n entrance; COMMON mapped) lands inside a room behind a
; door (build time: data.room_teles): the room state set for load_map, the door remembered
; (owner, 2026-11-23: the room revealed before the party appears). Keeps C, DE, HL.
room_chk:   push hl
            ld hl, C_ROOMS
            ld b, a
.l:         ld a, [hl+]
            cp $FF
            jr z, .x
            cp b
            jr z, .f
            inc hl
            inc hl
            jr .l
.f:         ld a, [hl+]
            ld [door_x], a
            ld a, [hl]
            ld [door_y], a
            ld a, 1
            ld [ml_room], a
.x:         pop hl
            ret
; wait for A or B (C set on B)
wait_ab:    call oam_clr
.w:         call scr_frame
            ldh a, [pad_new]
            and $03
            jr z, .w
            rrca
            ccf
            ret


; ---- the windows' gradient's bank-0 side: windows recorded, builds through bank 99
gr_fd:      ld a, 1                         ; a fade: the gradient fades with the screen
            ld [fd_act], a                  ;   (owner, 2026-11-23: the gradient is the
            ret                             ;   windows' colour, not a layer shown after)
; a fade step (CGB, fd_lv 0-4): the ramp from the window colour at fd_lv / 4
gr_fdramp:  ld a, [gr_on]
            and a
            ret z
            ld a, [fd_wh]                   ; (no gradient in the white fades: battle)
            and a
            ret nz
            ld hl, win_r
            ld b, 3
.p:         ld a, [hl]
            push af
            call fd_mul
            ld [hl+], a
            dec b
            jr nz, .p
            ld a, F3_BANK
            ld hl, gr_ramp_mk
            call bank_call
            ld hl, win_b
            ld b, 3
.r:         pop af
            ld [hl-], a
            dec b
            jr nz, .r
            ret
gr_build:   push bc
            push de
            push hl
            xor a
            ld [gr_dirty], a
            ld a, [lmask]                   ; (a masked load: the guard paused, RAM only;
            ld [gd_off], a                  ;   held through modes 2 / 3 it halved the
            ld a, F3_BANK                   ;   build's time)
            ld hl, gr_menu
            call bank_call
            call gd_resume
            pop hl
            pop de
            pop bc
            ret
gr_box0:    ld [gr_cut], a
            push bc
            push de
            push hl
            ld a, F3_BANK
            ld hl, gr_box
            call bank_call
            pop hl
            pop de
            pop bc
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
; (moved from screens.s / main.s: their bank-0 sections were full)
; Super Game Boy: the party's pictures in their job colours on the menu screens (bank 99)
sgb_pic0:   push hl                         ; (scr_spr23: B, C = the picture's x, y; the
                                            ;   outline's record, then the SGB's: ul.s pic_rec)
            push de
            push bc
            ld a, b
            ld [sgb_px], a
            ld a, c
            ld [sgb_py], a
            ld a, e
            ld [sgb_pk], a
            ld a, F3_BANK
            ld hl, pic_rec
            call bank_call
            pop bc
            pop de
            pop hl
            ret
sgb_pics0:  push hl                         ; (scr_show: the pictures' outlines; DMG / SGB: other
            push de                         ;   inks, then the SGB's pictures and gold labels)
            push bc
            ld a, F3_BANK
            ld hl, pic_show
            call bank_call
            pop bc
            pop de
            pop hl
            ret
; the hand (OAM 0-3) hidden; registers but A kept
hand_hide:  xor a
            ld [oam_buf], a
            ld [oam_buf + 4], a
            ld [oam_buf + 8], a
            ld [oam_buf + 12], a
            ret
; A = the byte at bank A' (fc_bank), HL; the caller's bank mapped again
far_byte:   ldh a, [rombank]
            ld [fc_save], a
            ld a, [fc_bank]
            call sbank
            ld a, [hl]
            push af
            ld a, [fc_save]
            call sbank
            pop af
            ret

section bank 99, $4800
; ---- Options (owner, 2026-11-22; WonderSwan Color remake's choices added): Message Speed, Text
; Speed, Volume, B Dash On / Off, Cursor Remember / Reset, and on the Color the windows'
; colour (red, green, blue 0-31, shown at once). Header (0,0,20,3), list (0,3,20,15), one row a
; setting from row 5; up / down pick, left / right change, B back (kept in cart RAM bank 1)
KN_MARK    = unsram + $F8   ; $A5: the Konami Code entered on this file's Formation menu (kept
KN_EXP     = unsram + $F9   ;   in the save); the experience and Gil multipliers (0 Normal, 1 2X,
KN_GOLD    = unsram + $FA   ;   2 4X, 3 8X, 4 12X; owner, 2026-11-24)
SC_MARK    = unsram + $FB   ; $5A: the Sound Test code (1 9 9 2 1 1 2 4, then a save loaded; owner,
SC_NOENC   = unsram + $FC   ;   2026-11-25): multipliers to 128X, No Encounters, the main menu's Save
OPT_ROWS   = 12             ; settings shown at once (rows 5-16); more scroll
opt_menu:   xor a
            ld [opt_cur], a
            ld [opt_top], a
opt_redraw: call opt_mklist
            call scr_open
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
            call opt_rows
            call scr_show
.l:         ld a, [opt_top]                 ; the hand at the setting (row 5 + n - top)
            ld b, a
            ld a, [opt_cur]
            sub b
            add a, 5
            ld c, a
            ld b, 2
            call cur_txt
            call scr_frame
            ldh a, [pad_new]
            bit 1, a
            jp nz, opt_save
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
.ch:        call opt_id                     ; B = +1 / -1, clamped; E = the setting's id
            ld e, a
            ld d, 0
            ld hl, os_max
            add hl, de
            call opt_mx
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
            ld b, a
            ld a, e
            cp 6
            jr z, .mm
            ld [hl], b
            push de
            call opt_apply
            pop de
            ld a, e                         ; (a window colour / the gradient / LCD: at once)
            cp 14
            jr nz, .w7
            call scr_dmgpal
            jr .nw
.w7:        cp 7
            jr c, .nw
            cp 12
            jr nc, .nw
            ldh a, [is_cgb]
            and a
            jr z, .sw
            call opt_wnow
            jr .nw
.sw:        call sgb_wlive
.nw:        call opt_rows
            call scr_upd
            jr .l
.mm:        call mmp_ok                     ; Modern MP (src/mmp.s): only with the wiki's data;
            and a                           ;   the owner's warning first (Yes: the party's MP
            jr z, .l                        ;   converted), the screen again either way
            push hl
            push bc
            ld a, SCR_BANK
            ld hl, mmp_ask
            call bank_call
            pop bc
            pop hl
            and a
            jp nz, opt_redraw
            ld [hl], b
            call mmp_sync
            jp opt_redraw
.up:        ld hl, opt_cur
            ld a, [hl]
            and a
            jr nz, .u1
            ld a, [opt_cnt]                 ; (from the first: the last)
.u1:        dec a
            ld [hl], a
            jr .sc
.dn:        ld hl, opt_cur
            ld a, [opt_cnt]
            ld b, a
            ld a, [hl]
            inc a
            cp b
            jr c, .d1
            xor a
.d1:        ld [hl], a
.sc:        call opt_scroll
            jp .l
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
            ld hl, win_pal                  ; (the LCD colour mode: cc.s)
            ld b, 8
            jp cc_inpl
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
section bank 99, $5000
; ---- the file screen: three windows (0,6k,20,6), each "File k", the play time, the four names,
; the leader's level and the Gil (or No data); the hand on a file; A loads (a good file) /
; saves (a file with a save: Save over it? first); B: C set
file_pick:  ld a, [sv_slot]                 ; (the hand on the file used last)
            cp 3
            jr c, .c
            xor a
.c:         ld [fp_cur], a
            call fp_draw
.l:         ld a, [fp_cur]
            ld c, a
            add a, a
            add a, c
            add a, a
            inc a
            ld c, a
            ld b, 2
            call cur_txt
            call scr_frame
            ldh a, [pad_new]
            bit 1, a
            jr nz, .b
            bit 0, a
            jr nz, .a
            and $C0
            jr z, .l
            ld b, a
            ld a, [fp_cur]
            bit 7, b
            jr z, .u
            inc a
            cp 3
            jr c, .s
            xor a
            jr .s
.u:         dec a
            cp $FF
            jr nz, .s
            ld a, 2
.s:         ld [fp_cur], a
            ld a, SFX_MOVE
            ld [sfx_req], a
            jr .l
.b:         call oam_clr
            scf
            ret
.a:         ld a, [fp_cur]
            ld [sv_slot], a
            call save_valid
            ld a, [fp_mode]
            jr c, .empty
            and a
            jr nz, .over
            call oam_clr                    ; load
            call load_game
            call sva_ld                     ; (its place, if saved with the Sound Test code's
            and a                           ;   Save; sv_fix: old saves mended, the code applied)
            ret
.empty:     and a
            jr nz, .save
            call sfx_err                    ; (nothing to load there)
            jr .l
.over:      ld a, [fp_cur]                  ; Save over File k? A / B (that file's rows
            call fp_clr                     ;   cleared: A held fp_mode, so File 2's were)
            ld a, [fp_cur]
            call fp_row
            push bc
            call pen_at
            ld hl, fp_s_over
            call pen_str
            ld a, [fp_cur]
            add a, $31
            call pen_ch
            ld a, $3F
            call pen_ch
            pop bc
            inc c
            inc c
            push bc
            call pen_at
            ld hl, mf_q2
            call pen_str
            pop bc
            inc c
            call pen_at
            ld hl, mf_q3
            call pen_str
            call scr_upd
            call oam_clr
            call wait_ab
            jr nc, .save
            ld a, [fp_cur]
            call fp_clr
            ld a, [fp_cur]
            call fp_one
            call scr_upd
            jp .l
.save:      call oam_clr
            call save_game
            call sva_after                  ; (the place with the main menu's Save; else none)
            ld a, [fp_cur]                  ; the file's new contents, a moment
            call fp_clr
            ld a, [fp_cur]
            call fp_one
            call scr_upd
            ld b, 60
.w:         push bc
            call scr_frame
            pop bc
            dec b
            jr nz, .w
            and a
            ret
fp_s_over:  db "Save over File ", 0
fp_s_file:  db "File ", 0
fp_s_none:  db "No data", 0
fp_s_lv:    db "Lv ", 0
fp_s_gil:   db " Gil", 0
; the screen
fp_draw:    call scr_open
            call eqm_pal
            ld a, [sv_slot]                 ; (fp_one reads each file through sv_slot: the
            push af                         ;   file in use kept)
            xor a
.k:         push af
            ld c, a
            add a, a
            add a, c
            add a, a
            ld c, a
            ld b, 0
            ld de, $1406
            call scr_win
            pop af
            push af
            call fp_one
            pop af
            inc a
            cp 3
            jr c, .k
            pop af
            ld [sv_slot], a
            jp scr_show
; A = file -> B = 2, C = its first text row
fp_row:     ld c, a
            add a, a
            add a, c
            add a, a
            inc a
            ld c, a
            ld b, 2
            ret
; file A's text rows cleared
fp_clr:     call fp_row
            ld e, 4
.r:         push bc
            push de
            ld b, 1
            call pen_at
            ld b, 18
            call pen_sp
            pop de
            pop bc
            inc c
            dec e
            jr nz, .r
            ret
; file A's contents
fp_one:     ld [fp_k], a
            ld [sv_slot], a
            call fp_row                     ; "File k" in gold
            push bc
            call pen_at
            ld hl, fp_s_file
            call pen_str
            ld a, [fp_k]
            add a, $31
            call pen_ch
            pop bc
            push bc
            call cell_addr
            ld a, h
            add a, 3
            ld h, a
            ld a, $0B
            ld b, 6
.g:         ld [hl+], a
            dec b
            jr nz, .g
            pop bc
            push bc
            call save_valid
            pop bc
            jr nc, .ok
            inc c
            call pen_at
            ld hl, fp_s_none
            jp pen_str
.ok:        push bc
            call fp_read
            pop bc
            push bc                         ; the time, h:mm ending at column 18
            ld b, 14
            ld a, [fp_buf + 29]
            cp 10
            jr c, .t1
            dec b
.t1:        call pen_at
            ld a, [fp_buf + 29]
            call fp_dec
            ld a, $3A
            call pen_ch
            ld a, [fp_buf + 28]
            call fp_two
            pop bc
            inc c                           ; the names: two a row (columns 2, 11)
            ld hl, fp_buf
            ld e, 0
.nm:        push bc
            push de
            push hl
            ld a, e
            and 1
            ld b, 2
            jr z, .nx
            ld b, 11
.nx:        ld a, e
            srl a
            add a, c
            ld c, a
            call pen_at
            pop hl
            ld d, 6
.ch:        ld a, [hl+]
            and a
            jr nz, .cp
            ld a, $20                       ; (an unused letter: blank)
.cp:        call pen_ch
            dec d
            jr nz, .ch
            pop de
            pop bc
            inc e
            ld a, e
            cp 4
            jr c, .nm
            inc c                           ; the leader's level, the Gil
            inc c
            push bc
            call pen_at
            ld hl, fp_s_lv
            call pen_str
            ld a, [fp_buf + 24]
            inc a
            call fp_dec
            pop bc
            ld b, 9
            call pen_at
            ld hl, fp_buf + 25
            ld a, [hl+]
            ld [nf_val], a
            ld a, [hl+]
            ld [nf_val + 1], a
            ld a, [hl]
            ld [nf_val + 2], a
            ld b, 6
            call pen_num
            ld hl, fp_s_gil
            jp pen_str
; the file's page (sv_slot): names (4 x 6), the leader's level (+24), the Gil (+25, 3),
; minutes (+28), hours (+29) -> fp_buf (cart RAM on only meanwhile)
fp_read:    ld a, $0A
            ld [$0000], a
            xor a
            ld [$4000], a
            call sv_addr4                   ; HL = the page
            push hl
            ld de, fp_buf
            ld c, 0
.m:         push hl
            ld a, h                         ; member c: + $100 + $40 c
            inc a
            ld h, a
            ld a, c
            rrca
            rrca
            add a, l
            ld l, a
            push hl
            inc hl
            inc hl
            ld b, 4
.n4:        ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .n4
            pop hl
            ld a, l
            add a, $3E
            ld l, a
            jr nc, .n5
            inc h
.n5:        ld a, [hl+]
            ld [de], a
            inc de
            ld a, [hl]
            ld [de], a
            inc de
            pop hl
            inc c
            ld a, c
            cp 4
            jr c, .m
            pop hl
            push hl
            inc h                           ; the leader's level (+ $126)
            ld a, l
            add a, $26
            ld l, a
            ld a, [hl]
            ld [fp_buf + 24], a
            pop hl
            push hl
            ld a, l                         ; play time (+ $F2, $F3)
            add a, $F2
            ld l, a
            jr nc, .pt
            inc h
.pt:        ld a, [hl+]
            ld [fp_buf + 28], a
            ld a, [hl]
            ld [fp_buf + 29], a
            pop hl
            ld a, l                         ; Gil (+ $1C)
            add a, $1C
            ld l, a
            ld de, fp_buf + 25
            ld b, 3
.gd:        ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .gd
            xor a
            ld [$0000], a
            ret
; A in decimal without leading zeros (0-99) / with two digits
fp_dec:     cp 10
            jr c, fp_two.o
fp_two:     ld c, 0
.t:         cp 10
            jr c, .d
            sub 10
            inc c
            jr .t
.d:         push af
            ld a, c
            add a, $30
            call pen_ch
            pop af
.o:         add a, $30
            jp pen_ch

section wram, $C95C
sv_slot:    ds 1                            ; the save file in use (0-2)
fp_mode:    ds 1                            ; the file screen: 0 load, 1 save
fp_cur:     ds 1
fp_k:       ds 1
fp_buf:     ds 30
ml_room:    ds 1                            ; load_map: arrive inside a room (main.s room_chk)
section bank 99, $4BC0                      ; (an enemy dies: bt_erase_enemy)

; ---- an enemy dies (owner, 2026-11-23, as the WonderSwan Color remake: it breaks up in
; horizontal strips). fl_b / fl_c = its cell, fl_e = its size (bank 6 bt_erase_enemy). Its
; tiles are shared with others of its kind, so they are copied to the tiles free while the
; names window shows (FL_T0) and its cells switched to the copies; then 16 steps, one pixel
; row of every tile going every second step (in the order 0 4 2 6 1 5 3 7), in place (owner,
; 2026-11-24: no sliding; the slide code below is no longer reached). A fiend's tiles are its own: changed in place, two frames a
; step, the screen shaking and the hit sound every fourth step. VRAM only outside mode 3.
ED_T0      = $C4
ed_dissolve:
            xor a
            ldh [rVBK], a
            ld a, [fl_e]                    ; cells (E x E)
            ld b, a
            ld c, a
            xor a
.sq:        add a, b
            dec c
            jr nz, .sq
            ld [ed_n], a
            ld de, fl_tb                    ; the tiles' list
            ld a, ED_T0
            ld [ed_t], a
            xor a
            ld [ed_r], a
.r:         ld a, [fl_b]                    ; row ed_r: HL = its first cell in smap
            ld b, a
            ld a, [fl_c]
            ld c, a
            ld a, [ed_r]
            add a, c
            ld c, a
            push de
            call cell_addr
            pop de
            ld a, [fl_e]
            ld b, a
.c:         ld a, [bt_type]
            cp 3
            ld a, [hl]
            jr nc, .own                     ; (a fiend: its own tile)
            push bc
            push de
            push hl
            call ed_tadr                    ; the tile copied to ed_t
            push hl
            ld a, [ed_t]
            call ed_tadr
            ld d, h
            ld e, l
            pop hl
            ld b, 8
.cp:        di
            call ed_vw
            ld a, [hl+]
            ld [de], a
            inc de
            ld a, [hl+]
            ld [de], a
            inc de
            ei
            dec b
            jr nz, .cp
            pop hl
            ld a, [ed_t]                    ; the cell to the copy (smap and the screen)
            ld [hl], a
            push hl
            ld de, $9800 - smap
            add hl, de
            ld e, a
            di
            call ed_vw
            ld [hl], e
            ei
            pop hl
            pop de
            pop bc
            ld a, [ed_t]
            inc a
            ld [ed_t], a
            dec a
.own:       ld [de], a
            inc de
            inc hl
            dec b
            jr nz, .c
            ld hl, ed_r
            inc [hl]
            ld a, [fl_e]
            cp [hl]
            jr nz, .r
.steps:     di                              ; the blank: tile 0's first row (the Color: colour
            call ed_vw                      ;   0; DMG / SGB: the battle's black is colour 3)
            ld a, [$9000]
            ld [ed_bk], a
            ei
            xor a
            ld [ed_s], a
.st:        ld a, [ed_s]                    ; (owner, 2026-11-24: no sliding: on the even
            bit 0, a                        ;   steps the rows stay in place)
            jp z, .nx
            ld a, [ed_s]                    ; the row: order[step / 2]
            srl a
            ld e, a
            ld d, 0
            ld hl, ed_ord
            add hl, de
            ld a, [hl]
            add a, a
            ld [ed_row], a                  ; (its byte offset)
            ld de, fl_tb
            ld a, [ed_n]
            ld b, a
.t:         push bc
            push de
            ld a, [de]
            call ed_tadr
            ld a, [ed_row]
            add a, l
            ld l, a
            di
            call ed_vw
            ld a, [hl+]
            ld b, a
            ld a, [hl-]
            ld c, a
            ei
            ld a, [ed_s]
            bit 0, a
            jr nz, .clr
            ld a, [ed_bk]                   ; (the bits shifted in: the blank's)
            ld e, a
            ld a, [ed_row]                  ; slide: odd rows left, even rows right
            bit 1, a
            jr z, .rt
            sla b
            sla b
            sla c
            sla c
            ld a, e
            and $03
            ld d, a
            or b
            ld b, a
            ld a, d
            or c
            ld c, a
            jr .wr
.rt:        srl b
            srl b
            srl c
            srl c
            ld a, e
            and $C0
            ld d, a
            or b
            ld b, a
            ld a, d
            or c
            ld c, a
            jr .wr
.clr:       ld a, [ed_bk]
            ld b, a
            ld c, a
.wr:        di
            call ed_vw
            ld [hl], b
            inc hl
            ld [hl], c
            ei
            pop de
            inc de
            pop bc
            dec b
            jr nz, .t
.nx:        ld a, [bt_type]                 ; a fiend: the screen shakes, the hit sound
            cp 3
            jr c, .w1
            ld a, [ed_s]
            and 1
            ld a, 2
            jr z, .sx
            ld a, -2
.sx:        ldh [scx], a
            ld a, [ed_s]
            and 3
            jr nz, .w2
            ld a, SFX_HIT
            ld [sfx_req], a
.w2:        call wait_vbl
.w1:        call wait_vbl
            ld hl, ed_s
            inc [hl]
            ld a, [hl]
            cp 16
            jr c, .st
            xor a
            ldh [scx], a
            jp wait_vbl
ed_ord:     db 0, 4, 2, 6, 1, 5, 3, 7
; HL = VRAM of BG tile A ($8800 mode: $80-$FF at $8800, $00-$7F at $9000)
ed_tadr:    ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            bit 7, a
            jr nz, .hi
            ld a, h
            add a, $90
            ld h, a
            ret
.hi:        ld a, h
            add a, $80
            ld h, a
            ret
; until VRAM is free (modes 0 / 1; mode 2 follows, VRAM still open): ~20 cycles of access
ed_vw:      ldh a, [rSTAT]
            and 2
            jr nz, ed_vw
            ret

section bank 99, $5600
; ---- the encounter transition (owner, 2026-11-22: from the WonderSwan Color remake, as raster
; effects any Game Boy can show; made lovelier 2026-11-24): 8 frames of two white flashes, 24 of
; the map swirling (a rolling ripple) and drawn in towards the party, 16 of its lines parting
; (every other one left / right) as the picture folds onto the party's line and fades to white,
; 6 white; the battle then fades in from white. Each frame's colour level from a table. Per line SCX / SCY from battle.py trans_tables (bank TRANS_BANK), written
; by the STAT mode-0 interrupt (stat_rx); FF1's noise as before.
TR_BUF0    = $C2            ; (the field's queue: free now; battle temporaries, set when it starts)
TR_BUF1    = $C6            ;   frame tables: page n SCX by line, n + 1 SCY (bytes $00-$8F)
TR_PAL     = $C440          ; the faded palettes (BG 64, OBJ 64)
TR_WT      = $C500          ; the fade table: 8 levels x 32 (page-aligned)
TR_FR      = 48
TR_TW      = 32          ; (the fade's first frame)
bt_trans2:  ld a, [q_n]                     ; (the field's queue dropped)
            ld [q_rd], a
            ld a, $80
            call snd_track
            xor a
            ld [bx_n], a
            ld [tr_k], a
            ld [tr_px], a
            ldh a, [scx]
            ld [tr_x0], a
            ldh a, [scy]
            ld [tr_y0], a
            ldh a, [is_cgb]
            and a
            jr z, .dmg
            call fd_vbl                     ; the colours now (read in a V-Blank)
            ld hl, fd_pal
            ld c, 0
.rb:        ld a, c
            ldh [rBCPS], a
            ldh a, [rBCPD]
            ld [hl+], a
            inc c
            bit 6, c
            jr z, .rb
            ld c, 0
.ro:        ld a, c
            ldh [$FF6A], a
            ldh a, [$FF6B]
            ld [hl+], a
            inc c
            bit 6, c
            jr z, .ro
            ld hl, $7600
            ld de, TR_WT
            ld bc, 256
            ld a, TRANS_BANK
            call far_copy
            jr .sp
.dmg:       ldh a, [rBGP]
            ld [fd_b], a
            ldh a, [rOBP0]
            ld [fd_o0], a
            ldh a, [rOBP1]
            ld [fd_o1], a
.sp:        ld hl, oam_buf                  ; sprites: the party only (at the screen's middle)
            ld b, 40
.o:         ld a, [hl]
            sub 16 + 64
            cp 16
            jr nc, .hd
            inc hl
            ld a, [hl-]
            sub 8 + 72
            cp 16
            jr c, .kp
.hd:        ld [hl], 0
.kp:        ld a, l
            add a, 4
            ld l, a
            dec b
            jr nz, .o
            call tr_prep                    ; frame 0
            di
            call tr_buf                     ; (its tables from the start)
            ld a, h
            ldh [hrx], a
            ld a, $08                       ; (STAT: mode 0 each line, no LYC meanwhile)
            ldh [rSTAT], a
            ldh a, [rIF]
            and $FD
            ldh [rIF], a
            ei
.f:         call tr_buf                     ; line 0's scroll for the V-Blank to write; the
            ld l, 0                         ;   page shown after it
            ld a, [hl]
            ldh [scx], a
            inc h
            ld a, [hl]
            ldh [scy], a
            dec h
            ld a, h
            ld [tr_nx], a
            call tr_noise
            call wait_vbl
            ld a, [tr_nx]                   ; (in this V-Blank: line 0's interrupt reads it)
            ldh [hrx], a
            call tr_pals                    ; (in this V-Blank)
            ld a, $F0                       ; the noise
            ldh [$FF21], a
            ld a, [bx_nz]
            ldh [$FF22], a
            ld a, $80
            ldh [$FF23], a
            ld hl, bx_n
            inc [hl]
            call tr_party
            ld a, [tr_k]                    ; (SGB: colour 0 white for the fade, before it)
            cp TR_TW - 2
            call z, tr_sgbw
            ld hl, tr_k
            inc [hl]
            ld a, [hl]
            cp TR_FR
            jr nc, .end
            call tr_prep
            jr .f
.end:       call wait_vbl                   ; white
            di
            xor a
            ldh [hrx], a
            ld a, $40
            ldh [rSTAT], a
            ld a, BOX_LINES - 1
            ldh [rLYC], a
            ldh a, [rIF]
            and $FD
            ldh [rIF], a
            ei
            ld a, [tr_x0]
            ldh [scx], a
            ldh [rSCX], a
            ld a, [tr_y0]
            ldh [scy], a
            ldh [rSCY], a
            ldh a, [is_cgb]
            and a
            jr z, .dw
            ld a, $80
            ldh [rBCPS], a
            ldh [$FF6A], a
            ld b, 32
.wc:        ld a, $FF
            ldh [rBCPD], a
            ldh [$FF6B], a
            ld a, $7F
            ldh [rBCPD], a
            ldh [$FF6B], a
            dec b
            jr nz, .wc
            ld a, 1                         ; (the battle's load and fade-in: white)
            ld [fd_wh], a
            jr .wt
.dw:        xor a
            ldh [rBGP], a
            ldh [rOBP0], a
            ldh [rOBP1], a
.wt:        call oam_clr
            ld b, 5
.ww:        push bc
            call wait_vbl
            pop bc
            dec b
            jr nz, .ww
            xor a                           ; (the noise off)
            ldh [$FF21], a
            ret
; Super Game Boy: the map's palette with colour 0 white (all shades 0 at the fade's end)
tr_sgbw:    ld a, [sgb_on]
            and a
            ret z
            ld hl, M_SGB
            ld de, tr_sgp
            ld bc, 14
            ld a, [map_bank]
            call far_copy
            ld a, $FF
            ld [tr_sgp], a
            ld a, $7F
            ld [tr_sgp + 1], a
            ld a, [sgb_qi]                  ; (the queue idle: from its start)
            ld hl, sgb_qn
            cp [hl]
            jr nz, .q
            xor a
            ld [sgb_qi], a
            ld [hl], a
.q:         ld a, [sgb_qn]
            cp 6
            ret nc
            ld hl, tr_sgp
            ld c, 0
            ld a, $01
            jp sgb_pal
; H = frame tr_k's SCX page (L = 0)
tr_buf:     ld a, [tr_k]
            rrca
            ld hl, TR_BUF0 << 8
            ret nc
            ld hl, TR_BUF1 << 8
            ret
; frame tr_k's lines (the tables plus the field's scroll) and its colours
tr_prep:    ld a, [tr_k]                    ; HL = $4000 + 288 k
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld a, [tr_k]
            add a, h
            add a, $40
            ld h, a
            push hl
            call tr_buf
            ld d, h
            ld e, l
            pop hl
            push de
            ld bc, 144
            ld a, TRANS_BANK
            call far_copy                   ; (HL, DE: past the SCX run)
            pop de
            push de
            inc d
            ld bc, 144
            ld a, TRANS_BANK
            call far_copy
            pop hl
            ld a, [tr_x0]
            ld d, a
            ld b, 144
.ax:        ld a, [hl]
            add a, d
            ld [hl+], a
            dec b
            jr nz, .ax
            ld l, 0
            inc h
            ld a, [tr_y0]
            ld d, a
            ld b, 144
.ay:        ld a, [hl]
            add a, d
            ld [hl+], a
            dec b
            jr nz, .ay
            ld a, TRANS_BANK                ; the frame's colour level (0 unchanged, 1 the
            ld [fc_bank], a                 ;   map's own, 2-9 the fade's 1-8)
            ld a, [tr_k]
            ld l, a
            ld h, $77
            call far_byte
            ld [tr_f], a
            and a
            ret z
            ldh a, [is_cgb]
            and a
            ret z
            ld a, [tr_f]
            dec a
            jr nz, .fd
            ld hl, fd_pal                   ; Color, level 1: the colours as they were
            ld de, TR_PAL
            ld bc, 128
            jp memcpy
.fd:        dec a                           ; Color: 64 colours through the table
            swap a
            add a, a                        ; 32 (level - 2)
            ld [tr_t], a
            ld hl, fd_pal
            ld de, TR_PAL
            ld b, 64
.c:         push bc
            ld a, [hl+]
            ld c, a                         ; low: GGGRRRRR
            ld a, [hl+]
            ld b, a                         ; high: 0BBBBBGG
            push hl
            ld a, [tr_t]
            ld h, high(TR_WT)
            ld l, a
            ld a, c                         ; red
            and 31
            add a, l
            push hl
            ld l, a
            ld a, [hl]
            pop hl
            ld [tr_r], a
            ld a, b                         ; green
            and 3
            add a, a
            add a, a
            add a, a
            ld [tr_g], a
            ld a, c
            swap a
            rrca
            and 7
            push hl
            ld hl, tr_g
            or [hl]
            pop hl
            add a, l
            push hl
            ld l, a
            ld a, [hl]
            pop hl
            ld [tr_g], a
            ld a, b                         ; blue
            rrca
            rrca
            and 31
            add a, l
            ld l, a
            ld a, [hl]
            add a, a
            add a, a
            ld b, a                         ; (blue << 2)
            ld a, [tr_g]
            ld c, a
            swap a
            add a, a
            and $E0
            ld l, a
            ld a, [tr_r]
            or l
            ld [de], a
            inc de
            ld a, c
            rrca
            rrca
            rrca
            and 3
            or b
            ld [de], a
            inc de
            pop hl
            pop bc
            dec b
            jr nz, .c
            ret
; the frame's colours in the V-Blank (the strips: towards white)
tr_pals:    ld a, [tr_f]
            and a
            ret z
            ldh a, [is_cgb]
            and a
            jr z, .d
            ld a, $80
            ldh [rBCPS], a
            ldh [$FF6A], a
            ld hl, TR_PAL
            ld b, 64
.b:         ld a, [hl+]
            ldh [rBCPD], a
            dec b
            jr nz, .b
            ld b, 64
.ob:        ld a, [hl+]
            ldh [$FF6B], a
            dec b
            jr nz, .ob
            ret
.d:         ld a, [tr_f]                    ; DMG / SGB: the shades a step lighter per 2 levels
            dec a
            srl a
            ld [fd_lv], a
            jp fd_dmgw
; the noise's next period (FF1: from bx_n)
tr_noise:   ld a, SND_BANK
            ld [fc_bank], a
            ld a, [bx_n]
            srl a
            or 3
            and 15
            add a, low(SFX_NZ)
            ld l, a
            ld h, high(SFX_NZ)
            call far_byte
            ld [bx_nz], a
            ret
; the party's sprites follow the twist at its line (72)
tr_party:   call tr_buf
            ld l, 72
            ld a, [tr_x0]
            ld b, a
            ld a, [hl]
            sub b                           ; this frame's offset there
            ld b, a
            ld a, [tr_px]
            ld c, a
            ld a, b
            ld [tr_px], a
            sub c                           ; the change
            ld c, a
            ld hl, oam_buf + 1
            ld b, 40
.s:         dec hl
            ld a, [hl+]
            and a
            jr z, .n
            ld a, [hl]
            sub c
            ld [hl], a
.n:         ld a, l
            add a, 4
            ld l, a
            dec b
            jr nz, .s
            ret

section wram, $C4E0
opt_top:    ds 1                            ; Options: the first setting shown
opt_cnt:    ds 1                            ;   the settings listed
opt_list:   ds 16                           ;   their ids (15 at most: the codes)
kn_st:      ds 1                            ; the Konami Code's watch: keys matched so far

section wram, $C4C0
tr_k:       ds 1
tr_x0:      ds 1
tr_y0:      ds 1
tr_px:      ds 1
tr_f:       ds 1
tr_t:       ds 1
tr_nx:      ds 1
tr_r:       ds 1
tr_g:       ds 1
tr_sgp:     ds 14

section bank 99, $5C00
gr_btab:    db 1, 2, 4, 8, 16, 32, 64, 128   ; (palette -> its bit: kept at $5C00, one page)
; ---- the windows' gradient (the Color, Options: Window Gradient; owner, 2026-11-22): each
; window's inside colour from the chosen window colour at its top to a third of it at its
; bottom (one step per change of the 5-bit colour), written per line (text.s stat_gr).
; Windows side by side with other tops (the main menu's right column) take palette 0, a copy
; of the window palette, and the orbs' palette 6 goes with them.
GR_A       = $C500          ; menus' event lists (the field's queue: free on menu screens)
GR_B       = $C600
GR_FA      = $CBA0          ; the field box's / banner's (12 records each)
GR_FB      = $CBD0
GR_MAXW    = 16
; the menus' windows (scr_win) -> the list for the next V-Blank
gr_menu:    ld a, [gr_wn]
            and a
            jp z, gr_off
            call gr_ok
            jp z, gr_off
            call gr_ramp_mk
            call gr_groups
            call gr_pals
            ld a, [gr_wn]
            ld [gr_n], a
            xor a
            ld [gr_cut], a
            ld hl, GR_A
            ld de, GR_B
            ld a, 60
            jp gr_make
; the field's box / banner: A = rows of the window layer from the top (cut below it)
gr_box:     call gr_ok
            jp z, gr_off
            xor a                           ; (no palette-0 copy: that is the menus' alt
            ld [gr_p0], a                   ;   windows'; left on, it painted the map's
            ld a, [gr_cut]                  ;   palette 0 in the window colours)
            ld b, a
            xor a
            ld hl, gr_win
            ld [hl+], a                     ; x 0, y 0, w 20, h rows
            ld [hl+], a
            ld a, 20
            ld [hl+], a
            ld a, b
            ld [hl], a
            ld a, 1
            ld [gr_n], a
            xor a
            ld [gr_grp], a
            call gr_ramp_mk
            ld a, $80 | (7 * 8 + 4)         ; (the field: palette 7 only)
            ld [gr_nlm], a
            ld a, $FF
            ld [gr_nlm + 1], a
            ld [gr_nla], a
            ld hl, GR_FA
            ld de, GR_FB
            ld a, 10
            jp gr_make
; Z: no gradient (not a Color, or switched off)
gr_ok:      ldh a, [is_cgb]
            and a
            ret z
            ld a, [opt_nograd]
            xor 1
            ret
; the ramp: 32 colours from (r, g, b) to (r, g, b) / 3
gr_ramp_mk: ld hl, win_r                     ; per channel: value v, step 2 v, a remainder
            ld de, gr_vr                    ;   (v - floor(2 v c / 93): to v / 3 at c = 31)
            ld b, 3
.i:         ld a, [hl+]
            ld [de], a                      ; value
            inc de
            add a, a
            ld [de], a                      ; step
            inc de
            xor a
            ld [de], a                      ; remainder
            inc de
            dec b
            jr nz, .i
            ld hl, gr_ramp
            ld c, 32
.c:         ld a, [gr_vg]                   ; RGB555: r | g << 5 | b << 10
            ld d, a
            swap a
            rlca
            and $E0
            ld e, a
            ld a, [gr_vr]
            or e
            ld [hl+], a
            ld a, d
            rrca
            rrca
            rrca
            and 3
            ld e, a
            ld a, [gr_vb]
            add a, a
            add a, a
            or e
            ld [hl+], a
            push hl
            ld hl, gr_vr
            ld b, 3
.s:         ld d, [hl]                      ; the next colour: remainder + step, each 93 one
            inc hl                          ;   step down
            ld a, [hl+]
            add a, [hl]
.d:         cp 93
            jr c, .k
            sub 93
            dec d
            jr .d
.k:         ld [hl-], a
            dec hl
            ld [hl], d
            inc hl
            inc hl
            inc hl
            dec b
            jr nz, .s
            pop hl
            dec c
            jr nz, .c
            ld hl, gr_ramp                  ; (the LCD colour mode: cc.s)
            ld b, 64
            jp cc_inpl
; groups: window i goes to the alt group when an earlier main window j has rows overlapping
; it, columns apart (a shared border allowed) and another top or height
gr_groups:  xor a
            ld [gr_i], a
.w:         xor a                           ; (main until shown otherwise)
            ld [gr_g], a
            ld [gr_j], a
.j:         ld a, [gr_j]
            ld hl, gr_i
            cp [hl]
            jr nc, .s
            ld e, a
            ld d, 0
            ld hl, gr_grp
            add hl, de
            ld a, [hl]
            and a
            jr nz, .nj
            call gr_beside                  ; windows gr_i, gr_j: C set when beside
            jr nc, .nj
            ld a, 1
            ld [gr_g], a
            jr .s
.nj:        ld hl, gr_j
            inc [hl]
            jr .j
.s:         ld a, [gr_i]
            ld e, a
            ld d, 0
            ld hl, gr_grp
            add hl, de
            ld a, [gr_g]
            ld [hl], a
            ld hl, gr_i
            inc [hl]
            ld a, [gr_wn]
            cp [hl]
            jr nz, .w
            ret
; A = window -> HL = its (x, y, w, h)
gr_wp:      add a, a
            add a, a
            add a, low(gr_win)
            ld l, a
            ld a, high(gr_win)
            adc a, 0
            ld h, a
            ret
; C set: windows gr_i (I) and gr_j (J) side by side with another top or height
gr_beside:  ld a, [gr_j]
            call gr_wp
            ld d, h
            ld e, l                         ; DE = J
            ld a, [gr_i]
            call gr_wp                      ; HL = I
            inc hl                          ; rows overlap: yI < yJ + hJ and yJ < yI + hI
            inc de
            ld a, [de]
            ld b, a                         ; yJ
            inc de
            inc de
            ld a, [de]
            add a, b
            ld c, a                         ; yJ + hJ
            dec de
            dec de
            dec de                          ; (DE = J)
            ld a, [hl]                      ; yI
            cp c
            ret nc                          ; (NC: not beside)
            inc hl
            inc hl
            add a, [hl]                     ; yI + hI
            dec hl
            dec hl
            cp b
            jr z, .nb
            jr c, .nb
            dec hl                          ; HL = I
            ; columns apart (one shared allowed): xI >= xJ + wJ - 1 or xJ >= xI + wI - 1
            ld a, [de]
            ld b, a                         ; xJ
            inc de
            inc de
            ld a, [de]
            add a, b
            dec a
            ld c, a                         ; xJ + wJ - 1
            dec de
            dec de
            ld a, [hl]
            cp c
            jr nc, .apart
            inc hl
            inc hl
            add a, [hl]
            dec a                           ; xI + wI - 1
            dec hl
            dec hl
            ld c, a
            ld a, b
            cp c
            jr c, .nb
.apart:     inc hl                          ; another top or height
            inc de
            ld a, [de]
            cp [hl]
            jr nz, .yes
            inc hl
            inc hl
            inc de
            inc de
            ld a, [de]
            cp [hl]
            jr nz, .yes
.nb:        and a
            ret
.yes:       scf
            ret
; the palettes each group's windows use (colour 2 written per line): from the map copy's
; attributes; the alt windows' palette-7 cells to palette 0 (a copy of palette 7)
gr_pals:    xor a                           ; (owner, 2026-11-23: the cell checks took ~6
            ld [gr_pm], a                   ;   frames of a menu's load; now three tight
            ld [gr_pa], a                   ;   passes)
            ld [gr_i], a                    ; 1: the main windows' palettes (before any alt
.m:         call gr_pw                      ;   window turns its palette-7 cells to 0)
            jr nz, .mn
.mr:        push bc
            push de
            call gr_pcell
            ld a, [gr_pm]
            ld e, a
.mc:        ld a, [hl+]
            and 7
            cp 5                            ; (palette 5: the black outside)
            jr z, .ms
            add a, low(gr_btab)
            ld c, a
            ld b, high(gr_btab)
            ld a, [bc]
            or e
            ld e, a
.ms:        dec d
            jr nz, .mc
            ld a, e
            ld [gr_pm], a
            pop de
            pop bc
            inc c
            dec e
            jr nz, .mr
.mn:        ld hl, gr_i
            inc [hl]
            ld a, [gr_wn]
            cp [hl]
            jr nz, .m
.r:         ld hl, gr_i                     ; 2: last window first: a main window marks its
            ld a, [hl]                      ;   cells (attribute bit 4, unused by the
            and a                           ;   hardware); an alt window's unmarked cells
            jr z, .c0                       ;   (no later main window over them) count, and
            dec [hl]                        ;   palette 7 there becomes 0
            call gr_pw
            jr nz, .al
.rm:        push bc
            push de
            call gr_pcell
.rmc:       set 4, [hl]
            inc hl
            dec d
            jr nz, .rmc
            pop de
            pop bc
            inc c
            dec e
            jr nz, .rm
            jr .r
.al:        push bc
            push de
            call gr_pcell
            ld a, [gr_pa]
            ld e, a
.ac:        ld a, [hl]
            bit 4, a
            jr nz, .as
            and 7
            cp 5
            jr z, .as
            cp 7
            jr nz, .ab
            ld a, [hl]
            and $F8
            ld [hl], a
            xor a
.ab:        add a, low(gr_btab)
            ld c, a
            ld b, high(gr_btab)
            ld a, [bc]
            or e
            ld e, a
.as:        inc hl
            dec d
            jr nz, .ac
            ld a, e
            ld [gr_pa], a
            pop de
            pop bc
            inc c
            dec e
            jr nz, .al
            jr .r
.c0:        xor a                           ; 3: the marks off again
            ld [gr_i], a
.c:         call gr_pw
            jr nz, .cn
.cr:        push bc
            push de
            call gr_pcell
.cc:        res 4, [hl]
            inc hl
            dec d
            jr nz, .cc
            pop de
            pop bc
            inc c
            dec e
            jr nz, .cr
.cn:        ld hl, gr_i
            inc [hl]
            ld a, [gr_wn]
            cp [hl]
            jr nz, .c
            ld a, [gr_pa]                   ; (orbs in an alt window: palette 6 alt only)
            bit 6, a
            jr z, .l
            ld a, [gr_pm]
            res 6, a
            ld [gr_pm], a
.l:         ld a, [gr_pa]                   ; palette 0 used: a copy of palette 7 (into a
            and 1                           ;   masked load's shadows now, and with the list
            ld [gr_p0], a                   ;   in its V-Blank)
            jr z, .ls
            ld a, $80
            call bcps_w
            ld hl, win_pal
            ld b, 8
.p0:        ld a, [hl+]
            call bcpd_w
            dec b
            jr nz, .p0
.ls:        ld a, [gr_pm]                   ; the BCPS lists
            ld hl, gr_nlm
            call .lst
            ld a, [gr_pa]
            ld hl, gr_nla
.lst:       ld c, 0
.lb:        rrca
            jr nc, .ln
            push af
            ld a, c
            add a, a
            add a, a
            add a, a
            add a, $84                      ; (colour 2, auto-increment)
            ld [hl+], a
            pop af
.ln:        inc c
            bit 3, c
            jr z, .lb
            ld [hl], $FF
            ret
; window gr_i -> B, C, D, E = x, y, w, h; gr_g its group, NZ when alt
gr_pw:      ld a, [gr_i]
            ld e, a
            ld d, 0
            ld hl, gr_grp
            add hl, de
            ld a, [hl]
            ld [gr_g], a
            ld a, [gr_i]
            call gr_wp
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld c, a
            ld a, [hl+]
            ld d, a
            ld e, [hl]
            ld a, [gr_g]
            and a
            ret
; HL = the map copy's attribute of cell (B, C)
gr_pcell:   call cell_addr
            ld a, h
            add a, 3
            ld h, a
            ret
; the event list (HL / DE: its two buffers, A: records at most): per line each group's
; owner (the last window drawn there) and its colour; a record where a colour changes; the
; music in the longest gap; the box's cut
gr_make:    ld [gr_lim], a
            push hl
            push de
            xor a                           ; (line 0: the windows looked at)
            ld [gr_nev], a
            ld a, $FF                       ; (no owners yet)
            ld hl, gr_so
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl], a
            ld a, [gr_n]                    ; each window's top and end line
            and a
            jr z, .p9
            ld b, a
            ld hl, gr_win + 1
            ld de, gr_wt
.p:         ld a, [hl+]                     ; y
            inc hl
            ld c, a
            add a, a
            add a, a
            add a, a
            ld [de], a                      ; top line
            ld a, [hl+]                     ; h
            add a, c
            add a, a
            add a, a
            add a, a
            push de
            push af
            ld a, e
            add a, GR_MAXW
            ld e, a
            ld a, d
            adc a, 0
            ld d, a
            pop af
            ld [de], a                      ; end line (gr_wb)
            pop de
            inc de
            inc hl                          ; (the next window's y)
            dec b
            jr nz, .p
.p9:        pop de
            pop hl
            ld a, [gr_base]                 ; (the buffer not in use)
            cp l
            jr nz, .b
            ld a, [gr_base + 1]
            cp h
            jr nz, .b
            ld h, d
            ld l, e
.b:         ld a, l
            ld [gr_nb], a
            ld a, h
            ld [gr_nb + 1], a
            ld a, low(gr_ramp)              ; (both groups start at the top colour)
            ld [gr_cm], a
            ld [gr_ca], a
            xor a
            ld [gr_ln], a
            ld [gr_rc], a
.ln:        call gr_col                     ; E = main, C = alt (ramp low bytes; $FF none)
            ld a, [gr_ln]
            and a
            jr z, .z
            ld a, [gr_cut]
            and a
            jr z, .nc
            add a, a
            add a, a
            add a, a
            ld l, a
            ld a, [gr_ln]
            cp l
            jp nc, .end                     ; (the box's cut)
.nc:        xor a
            ld [gr_mk], a
            ld a, e
            cp $FF
            jr z, .na
            ld a, [gr_cm]
            call gr_same                    ; Z: the same colour as low byte E
            jr z, .na
            ld a, e
            ld [gr_cm], a
            ld a, 1
            ld [gr_mk], a
.na:        ld a, c
            cp $FF
            jr z, .nb
            ld e, c
            ld a, [gr_ca]
            call gr_same
            jr z, .nb
            ld a, c
            ld [gr_ca], a
            ld a, [gr_mk]
            or 2
            ld [gr_mk], a
.nb:        ld a, [gr_mk]
            and a
            jr z, .next
            jr .rec
.z:         ld a, e                         ; line 0: its colours (or the top colour)
            cp $FF
            jr z, .z1
            ld [gr_cm], a
.z1:        ld a, c
            cp $FF
            jr z, .z2
            ld [gr_ca], a
.z2:        ld a, 3
            ld [gr_mk], a
.rec:       ld a, [gr_lim]                  ; (room)
            ld b, a
            ld a, [gr_rc]
            cp b
            jr nc, .next
            call gr_recp                    ; HL = record gr_rc
            ld a, [gr_ln]
            ld [hl+], a
            ld a, [gr_mk]
            ld [hl+], a
            ld a, [gr_cm]
            ld [hl+], a
            ld a, [gr_ca]
            ld [hl], a
            ld hl, gr_rc
            inc [hl]
.next:      ld hl, gr_ln
            inc [hl]
            ld a, [hl]
            cp 144
            jp c, .ln
.end:       ld a, [gr_cut]                  ; the cut (+ music) / the music in the longest gap
            and a
            jr z, .gap
            add a, a
            add a, a
            add a, a
            ld b, a
            ld c, $C0
            jr .add
.gap:       ld a, [gr_nb]                   ; the music: from the first record at or after the
            ld l, a                         ;   line it has without the gradient, after its
            ld a, [gr_nb + 1]               ;   colours (colour records interrupt it; in the
            ld h, a                         ;   longest gap it could run into V-Blank, a fade
            ld a, [gr_rc]                   ;   step a frame late; a record of its own on the
            ld c, a                         ;   line before a colour record made that one a line
.gm:        ld a, c                         ;   late; owner, 2026-11-23)
            and a
            jr z, .gn
            ld a, [hl+]
            cp BOX_LINES
            jr nc, .gs
            inc hl
            inc hl
            inc hl
            dec c
            jr .gm
.gs:        set 6, [hl]
            jr .fin
.gn:        ld b, BOX_LINES                 ; (none after it: a record of its own)
            ld c, $40
.add:       call gr_ins
.fin:       ld a, [gr_rc]                   ; the end
            call gr_recp.a
            ld a, $FF
            ld [hl+], a
            xor a
            ld [hl], a
            ld a, 1                         ; for the next V-Blank
            ld [gr_new], a
            ld [gr_on], a
            ret
; HL = record gr_rc (A = record n: .a)
gr_recp:    ld a, [gr_rc]
.a:         add a, a
            add a, a
            ld l, a
            ld a, [gr_nb]
            add a, l
            ld l, a
            ld a, [gr_nb + 1]
            adc a, 0
            ld h, a
            ret
; Z: ramp entries at low bytes A and E hold the same colour
gr_same:    ld l, a
            ld h, high(gr_ramp)
            ld a, [hl+]
            ld b, [hl]
            ld l, e
            cp [hl]
            ret nz
            inc l
            ld a, b
            cp [hl]
            ret
; line gr_ln: E = the main owner's colour, C = the alt owner's (ramp low bytes; $FF none);
; the last window drawn over the line owns it. Colour 31 d / (lines - 1) at its line d.
; (Owner, 2026-11-23: a division per window and line took ~9 frames of a menu's load.) The
; owners change only on the windows' top and end lines (gr_nev: the next one): the windows
; are looked at there, a division made for a new owner; on the other lines each owner's
; colour steps on
gr_col:     ld a, [gr_ln]
            ld d, a
            ld hl, gr_nev
            cp [hl]
            jr nc, .full
            ld e, 1                         ; (owners as on the line before)
            call gr_gcs
            ld c, a
            push bc
            ld e, 0
            call gr_gcs
            pop bc
            ld e, a
            ret
.full:      ld a, 144                       ; the next top or end line after this one
            ld [hl], a
            ld a, [gr_n]
            and a
            jr z, .f9
            ld c, a
            ld hl, gr_wt
.f:         ld a, [hl]
            call .ev
            push hl
            ld a, l
            add a, GR_MAXW
            ld l, a
            ld a, h
            adc a, 0
            ld h, a
            ld a, [hl]                      ; (gr_wb)
            call .ev
            pop hl
            inc hl
            dec c
            jr nz, .f
.f9:        ld a, $FF
            ld [gr_tm], a
            ld [gr_ta], a
            ld a, [gr_n]
            ld c, a
            ld b, 0
.w:         ld a, c
            and a
            jr z, .x
            dec c
            ld hl, gr_wt
            add hl, bc
            ld a, d
            cp [hl]                         ; (above its top)
            jr c, .w
            ld hl, gr_wb
            add hl, bc
            cp [hl]                         ; (below its bottom)
            jr nc, .w
            ld hl, gr_grp
            add hl, bc
            ld a, [hl]
            ld hl, gr_tm
            and a
            jr z, .g
            inc hl                          ; (gr_ta)
.g:         ld a, [hl]
            inc a
            jr nz, .w                       ; (that group owned already)
            ld [hl], c
            ld a, [gr_tm]
            ld e, a
            ld a, [gr_ta]
            or e
            inc a
            jr z, .w                        ; (one still free)
.x:         ld a, [gr_ta]
            ld e, 1
            call gr_gc
            ld c, a
            push bc
            ld a, [gr_tm]
            ld e, 0
            call gr_gc
            pop bc
            ld e, a
            ret
.ev:        cp d                            ; A after line D and before gr_nev: gr_nev
            ret z
            ret c
            push hl
            ld hl, gr_nev
            cp [hl]
            jr nc, .e9
            ld [hl], a
.e9:        pop hl
            ret
; HL = group E's state (gr_so: owner, colour, remainder, lines - 1)
gr_sp:      ld a, e
            add a, a
            add a, a
            add a, low(gr_so)
            ld l, a
            ld a, high(gr_so)
            adc a, 0
            ld h, a
            ret
; group E, the same owner as on the line before -> A = its colour one line on ($FF none)
gr_gcs:     call gr_sp
            ld a, [hl+]
            cp $FF
            ret z
.st:        inc hl                          ; (HL = the remainder)
            ld a, [hl+]
            ld b, [hl]                      ; lines - 1
            dec hl
            add a, 31                       ; remainder + 31
            dec hl
.s:         cp b
            jr c, .k
            sub b
            inc [hl]                        ; colour + 1
            jr .s
.k:         inc hl
            ld [hl-], a
.out:       ld a, [hl]
            add a, a
            add a, low(gr_ramp)
            ret
; A = the owner of group E on line D ($FF none) -> A = its colour (ramp low byte; $FF)
gr_gc:      ld c, a
            call gr_sp
            ld a, c
            cp $FF
            jr nz, .o
            ld [hl], a                      ; (no owner)
            ret
.o:         cp [hl]
            jr nz, .new
            inc hl
            jr gr_gcs.st                    ; (the same: one step)
.new:       ld [hl], c                      ; a new owner: 31 d / (lines - 1)
            inc hl
            push hl
            ld b, 0
            ld hl, gr_wt
            add hl, bc
            ld a, [hl]
            ld [gr_t], a                    ; top line
            ld hl, gr_wb
            add hl, bc
            ld a, [hl]
            ld hl, gr_t
            sub [hl]
            dec a
            ld b, a                         ; B = lines - 1
            ld a, d
            sub [hl]                        ; d
            ld l, a
            ld h, 0
            ld e, l
            ld d, h
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld a, l
            sub e
            ld l, a
            ld a, h
            sbc a, d
            ld h, a                         ; 31 d
            ld a, b
            cpl
            ld e, a
            ld d, $FF
            inc de                          ; -(lines - 1)
            ld c, $FF
.d:         inc c
            add hl, de
            jr c, .d
            ld a, l                         ; remainder: HL + (lines - 1)
            add a, b
            ld e, a
            pop hl
            ld a, c
            cp 32
            jr c, .q
            ld a, 31
.q:         ld [hl+], a                     ; colour
            ld a, e
            ld [hl+], a                     ; remainder
            ld [hl], b                      ; lines - 1
            dec hl
            dec hl
            ld a, [gr_ln]
            ld d, a
            jr gr_gcs.out
; insert record (line B, mask C, the colours as they stand) before the first record with a
; later line; the same line: its mask ORed in
gr_ins:     ld a, b
            ld [gr_t], a
            ld a, c
            ld [gr_mk], a
            ld a, [gr_nb]
            ld l, a
            ld a, [gr_nb + 1]
            ld h, a
            ld a, [gr_rc]
            ld e, a                         ; records left
.f:         ld a, e
            and a
            jr z, .at
            ld a, [gr_t]
            cp [hl]
            jr z, .or
            jr c, .at
            inc hl
            inc hl
            inc hl
            inc hl
            dec e
            jr .f
.or:        inc hl
            ld a, [gr_mk]
            or [hl]
            ld [hl], a
            ret
.at:        push hl                         ; the E records from HL up by one record
            ld a, e
            add a, a
            add a, a
            ld c, a                         ; bytes
            ld b, 0
            add hl, bc
            dec hl
            ld d, h
            ld e, l
            inc hl
            inc hl
            inc hl
            inc hl                          ; HL = DE + 4
            ld a, c
            and a
            jr z, .wr
.mv:        ld a, [de]
            ld [hl-], a
            dec de
            dec c
            jr nz, .mv
.wr:        pop hl
            ld a, [gr_t]
            ld [hl+], a
            ld a, [gr_mk]
            ld [hl+], a
            ld a, [gr_cm]                   ; (colours: unused by a special record)
            ld [hl+], a
            ld a, [gr_ca]
            ld [hl], a
            ld hl, gr_rc
            inc [hl]
            ret

section wram, $D640
gr_ramp:    ds 64                           ; 32 colours
gr_win:     ds GR_MAXW * 4                  ; the menus' windows (scr_win): x, y, w, h
gr_grp:     ds GR_MAXW                      ; 0 main, 1 alt
gr_wn:      ds 1
gr_n:       ds 1
gr_on:      ds 1
gr_new:     ds 1
gr_rst:     ds 1
gr_dirty:   ds 1
gr_p0:      ds 1
fd_act:     ds 1
gr_p:       ds 2
gr_base:    ds 2
gr_nb:      ds 2
gr_lm:      ds 8                            ; BCPS lists in use: main, alt ($FF ends)
gr_la:      ds 8
gr_nlm:     ds 8                            ; the next list's
gr_nla:     ds 8
section wram, $DAA0
gr_wt:      ds GR_MAXW                      ; (gr_make: each window's top line,
gr_wb:      ds GR_MAXW                      ;   end line)
gr_so:      ds 8                            ; per group: owner, colour, remainder, lines - 1
gr_nev:     ds 1                            ; (the next line where the owners can change)
section wram, $D9CF
gr_i:       ds 1
gr_j:       ds 1
gr_g:       ds 1
gr_t:       ds 1
gr_pm:      ds 1
gr_pa:      ds 1
gr_cm:      ds 1
gr_ca:      ds 1
gr_lim:     ds 1
gr_ln:      ds 1
gr_rc:      ds 1
gr_mk:      ds 1
gr_cut:     ds 1
gr_tm:      ds 1
gr_ta:      ds 1
gr_cx:      ds 1
gr_cy:      ds 1
gr_vr:      ds 3                            ; (gr_ramp_mk: value, step, remainder per channel)
gr_vg:      ds 3
gr_vb:      ds 3
ed_n:       ds 1                            ; (ed_dissolve: cells, tile, rows left, step, row)
ed_t:       ds 1
ed_r:       ds 1
ed_s:       ds 1
ed_row:     ds 1
ed_bk:      ds 1

section wram, $CCC0                         ; (moved 2026-11-25: it overlapped the Suspend's and
                                            ;   name entry's variables at $CDE4)
loc_buf:    ds 19
pt_on:      ds 1                            ; (play time counted: set by the field's loop)
op_k:       ds 1                            ; (Optimize)
op_bv:      ds 1
op_be:      ds 1
op_i:       ds 1
op_e:       ds 1
op_n:       ds 1

section bank 99, $7200
; a colour changed: the palettes now (in V-Blank: palette 7 and the menus' 1-4)
opt_wnow:   call opt_wpal
            call opt_objp                   ; (the hand's colours: an LCD mode change)
            call eqm_pal                    ; (its colours made, then V-Blank: the writes)
            call pal_win                    ; (the rest in a V-Blank too: Lot Check checker)
            call opt_p0
            call text_pals
            call opt_objw
            ld a, [opt_nograd]              ; (the gradient from the new colour, or off)
            and a
            jp nz, gr_off
            ld a, [opt_cur]                 ; (switched on, or not on yet: built whole; a
            cp 10                            ;   colour change: the ramp only, the windows
            jp z, gr_menu                   ;   are the same; the whole build took frames,
            ld a, [gr_on]                   ;   and quick presses were lost with their
            and a                           ;   sounds)
            jp z, gr_menu
            jp gr_ramp_mk
; Options: palette 0 again when it is the menus' alt windows' copy of palette 7 (a colour change)
opt_p0:     ld a, [gr_p0]
            and a
            ret z
            ld a, $80
            call bcps_w
            ld hl, win_pal
            ld b, 8
.l:         ld a, [hl+]
            call bcpd_w
            dec b
            jr nz, .l
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
            ld [opt_nograd], a
            ld [opt_retgt], a               ; (Off by default: owner)
            ld [opt_mmp], a
            ld [opt_ccm], a
            ld [opt_dmgw], a
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
            ld [opt_ver], a
            cp $55                          ; ("OU": thirteen, the DMG's window shade)
            jr z, .q
            cp $54
            jr z, .q
            cp $53
            jr z, .q
            cp $52
            jr z, .q
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
.q:         push hl                         ; "OQ": the eight, check ("OR": nine, "OS": eleven)
            ld a, [opt_ver]
            sub $49                         ; (8 / 9 / 10: 11 for "OS", 12 for "OT")
            cp 10
            jr c, .qn
            inc a
.qn:        ld b, a
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
            ld de, opt_nodash               ; dash, cursor, r, g, b (checked: 0-1, 0-31), gradient,
            ld a, [opt_ver]                 ;   then retarget, Modern MP ("OS")
            sub $4C                         ; (5 / 6 / 8 / 9 with the LCD mode)
            cp 7
            jr c, .qm
            inc a
.qm:        ld b, a
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
.qc:        ld a, [opt_dmgw]                ; (0 / 1)
            cp 2
            jr c, .qd
            xor a
            ld [opt_dmgw], a
.qd:        ld a, [win_r]
            ld b, a
            ld a, [win_g]
            or b
            ld b, a
            ld a, [win_b]
            or b
            cp 32
            call nc, opt_wdef
            ld a, [opt_nograd]
            cp 2
            jr c, .qg
            xor a
            ld [opt_nograd], a
.qg:        ld a, [opt_ccm]                 ; (0-2)
            cp 3
            jr c, .qq
            xor a
            ld [opt_ccm], a
.qq:        ld a, [opt_retgt]               ; (0 / 1 each)
            ld b, a
            ld a, [opt_mmp]
            or b
            cp 2
            jr c, .x
            xor a
            ld [opt_retgt], a
            ld [opt_mmp], a
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
            ld a, $55
            ld [hl+], a
            ld de, os_sv                    ; the thirteen values, then the check ("OU")
            ld b, 13
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

; ---- new game: CLASSIC or MODERN (owner, 2026-11-24). A choice, its description, Ok to start on
; ...? Yes / No; the settings set (all can be changed in Options): Classic: the cursor reset, no B
; dash, no gradient, charges (Modern MP off), no Auto Retarget; Modern: the cursor remembered, B
; dash, the gradient, Modern MP, Auto Retarget. A = 0 chosen, 1 back (B on the choice)
section bank 99, $6200
ng_mode:    xor a
            ld [ngm_cur], a
.re:        call scr_open
            call eqm_pal
            ld b, 4
            ld c, 6
            ld d, 12
            ld e, 6
            call scr_win
            ld bc, $0707
            ld hl, ngm_s0
            call scr_str
            ld bc, $0709
            ld hl, ngm_s1
            call scr_str
            call scr_show
.l:         ld a, [ngm_cur]                 ; the hand at row 7 / 9, column 7
            add a, a
            add a, 7
            ld c, a
            ld b, 7
            call cur_txt
            call scr_frame
            ldh a, [pad_new]
            bit 1, a
            jr nz, .b
            bit 0, a
            jr nz, .a
            and $C0
            jr z, .l
            ld a, [ngm_cur]
            xor 1
            ld [ngm_cur], a
            ld a, SFX_SEL
            ld [sfx_req], a
            jr .l
.b:         ld a, 1
            ret
.a:         call scr_open                   ; the description (16 rows)
            call eqm_pal
            ld bc, $0000
            ld de, $1412
            call scr_win
            ld a, [ngm_cur]
            and a
            ld hl, ngm_dc
            jr z, .d
            ld hl, ngm_dm
.d:         ld bc, $0101
            call scr_str
            call scr_show
.w:         call scr_frame                  ; A: the question; B: the choice again
            ldh a, [pad_new]
            bit 1, a
            jr nz, .re
            and $09
            jr z, .w
            call scr_open                   ; Ok to start on ...? Yes / No (Yes first)
            call eqm_pal
            ld b, 0
            ld c, 5
            ld d, 20
            ld e, 7
            call scr_win
            ld a, [ngm_cur]
            and a
            ld hl, ngm_qc
            jr z, .q
            ld hl, ngm_qm
.q:         ld bc, $0106
            call scr_str
            ld bc, $0609
            ld hl, ngm_yes
            call scr_str
            ld bc, $0D09
            ld hl, ngm_no
            call scr_str
            call scr_show
            xor a
            ld [ngm_yn], a
.y:         ld a, [ngm_yn]
            and a
            ld b, 6
            jr z, .yx
            ld b, 13
.yx:        ld c, 9
            call cur_txt
            call scr_frame
            ldh a, [pad_new]
            bit 1, a
            jp nz, .re
            bit 0, a
            jr nz, .ya
            and $30
            jr z, .y
            ld a, [ngm_yn]
            xor 1
            ld [ngm_yn], a
            ld a, SFX_SEL
            ld [sfx_req], a
            jr .y
.ya:        ld a, [ngm_yn]
            and a
            jp nz, .re
            ld a, [ngm_cur]                 ; the settings
            and a
            ld a, 1
            jr z, .cl
            xor a
.cl:        ld [opt_nodash], a              ; Classic 1 (off) / Modern 0 (on)
            ld [opt_curr], a                ;   1 reset / 0 remembered
            ld [opt_nograd], a              ;   1 off / 0 on
            xor 1
            ld [opt_mmp], a                 ;   Modern MP: Classic 0 / Modern 1
            ld [opt_retgt], a
            xor a                           ; (a new file has no Konami Code: LCD Default,
            ld [opt_ccm], a                 ;   the window colours made again for it)
            call opt_wpal
            call opt_save0
            xor a
            ret
ngm_s0:     db "CLASSIC", 0
ngm_s1:     db "MODERN", 0
ngm_yes:    db "Yes", 0
ngm_no:     db "No", 0
ngm_qc:     db "OK to start on", $0A, "CLASSIC?", 0
ngm_qm:     db "OK to start on", $0A, "MODERN?", 0
ngm_dc:     db "Classic offers", $0A, "gameplay true to", $0A, "the original.", $0A
            db "Manage spell", $0A, "charges with Inns", $0A, "or Cottages, and", $0A
            db "plan your battles", $0A, "carefully - the", $0A, "party will not", $0A
            db "change their", $0A, "target after", $0A, "selection.", $0A, $0A
            db "These settings can", $0A, "be changed at any", $0A, "time in Config.", 0
ngm_dm:     db "Modern offers", $0A, "gameplay similar", $0A, "to more modern", $0A
            db "Final Fantasy", $0A, "games. Hold the", $0A, "B Button to dash.", $0A
            db "MP is shared by", $0A, "all spells, and", $0A, "the party will", $0A
            db "change targets if", $0A, "the enemy is", $0A, "slain.", $0A, $0A
            db "These settings can", $0A, "be changed at any", $0A, "time in Config.", 0

section wram, $DAFC
ngm_cur:    ds 1
ngm_yn:     ds 1

section bank 99, $52C0                      ; (Options: the list's helpers and tables)
; the list scrolled so the chosen setting shows (the rows drawn again when it moves)
opt_scroll: ld a, [opt_top]
            ld b, a
            ld a, [opt_cur]
            cp b
            jr c, .s
            sub b
            cp OPT_ROWS
            ret c
            ld a, [opt_cur]
            sub OPT_ROWS - 1
.s:         ld [opt_top], a
            call opt_rows
            jp scr_upd
; the chosen setting's id
opt_id:     ld a, [opt_cur]
opt_idx:    ld e, a                         ; list position A -> its id
            ld d, 0
            ld hl, opt_list
            add hl, de
            ld a, [hl]
            ret
; the settings shown: 0-6 always, 7-10 (window colours, gradient) on the Color, after the Konami
; Code on this file 11 (LCD, Color) and 12-13 (EXP, Gold)
opt_mklist: ld hl, opt_list
            xor a
.b:         ld [hl+], a
            inc a
            cp 7
            jr c, .b
            ld c, 7
            ldh a, [is_cgb]
            and a
            jr nz, .cg
            ld a, [sgb_on]                  ; (owner's audit, 2026-11-25: the SGB's windows
            and a                           ;   take the same three colours; the DMG a shade)
            jr nz, .sg
            ld a, 14
            ld [hl+], a
            inc c
            jr .k
.sg:        jr .k                           ; (SGB: windows black, no colour settings)
.cg:        ld a, 7
.c:         ld [hl+], a
            inc a
            cp 11
            jr c, .c
            ld c, 11
            call kn_on
            jr nz, .k
            ld a, 11
            ld [hl+], a
            inc c
.k:         call kn_on
            jr nz, .x
            ld a, 12
            ld [hl+], a
            inc a
            ld [hl+], a
            inc c
            inc c
            call sc_lst
.x:         ld a, c
            ld [opt_cnt], a
            ld a, [opt_cur]                 ; (kept in range)
            cp c
            ret c
            xor a
            ld [opt_cur], a
            ld [opt_top], a
            ret
; Z if the Konami Code was entered on this file
kn_on:      ld a, [KN_MARK]
            cp $A5
            ret
; every row of the list (12)
opt_rows:   ld c, 0
.r:         ld a, [opt_top]
            add a, c
            ld b, a
            ld a, [opt_cnt]
            cp b
            jr z, .e
            jr c, .e
            push bc
            ld a, b
            call opt_idx
            pop bc
            push bc
            call opt_row
            pop bc
            jr .n
.e:         push bc                         ; (past the list: blank)
            ld a, c
            add a, 5
            ld c, a
            call opt_clr
            pop bc
.n:         inc c
            ld a, c
            cp OPT_ROWS
            jr c, .r
            ret
; row C (screen row) blank, columns 1-18
opt_clr:    ld b, 1
            call pen_at
            ld b, 18
            jp pen_sp
; setting A on list row C: its name at column 2, its value ending at column 18
opt_row:    push af
            ld a, c
            add a, 5
            ld c, a
            push bc
            call opt_clr
            pop bc
            pop af
            push af
            push bc
            ld hl, os_labels                ; (the id-th name)
            ld e, a
.f:         ld a, e
            and a
            jr z, .lb
.z:         ld a, [hl+]
            and a
            jr nz, .z
            dec e
            jr .f
.lb:        pop bc
            push bc
            push hl
            ld b, 2
            call pen_at
            pop hl
            call pen_str
            pop bc
            pop af                          ; A = the id, C = the row
            ld e, a
            ld d, 0
            ld hl, os_fmt                   ; its value's column and format
            add hl, de
            add hl, de
            ld a, [hl+]
            ld b, a
            ld a, [hl]
            push af
            push de
            call pen_at
            pop de
            ld hl, os_var
            add hl, de
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld c, [hl]                      ; C = the value
            pop af
            and a
            jr z, .d1
            dec a
            jr z, .spd
            dec a
            jr z, .d0
            dec a
            jr z, .dsh
            dec a
            jr z, .cur
            dec a
            jr z, .oo
            dec a
            jr z, .n2
            dec a
            jr z, .lcd
            dec a
            jr nz, .wnd
            ld hl, os_mul                   ; EXP / Gold: Normal, 2X .. 12X
            ld b, 6
            jr opt_ostr
.d1:        ld a, c                         ; Message Speed: 1-8
            inc a
.d0:        add a, $30
            jp pen_ch
.spd:       ld hl, os_spn
            ld b, 7
            jr opt_ostr
.dsh:       ld hl, os_dash
            ld b, 3
            jr opt_ostr
.cur:       ld hl, os_cur
            ld b, 8
            jr opt_ostr
.oo:        ld hl, os_onoff
            ld b, 3
            jr opt_ostr
.n2:        ld a, c
            call nf_a
            ld b, 2
            jp pen_num
.wnd:       ld hl, os_wnd                   ; (the DMG's window shade)
            ld b, 5
            jr opt_ostr
.lcd:       ld hl, os_lcd
            ld b, 13
; the C-th name of B letters in table HL
opt_ostr:   ld a, c
            and a
            jr z, .p
            ld e, b
            ld d, 0
.m:         add hl, de
            dec c
            jr nz, .m
.p:         ld a, [hl+]
            call pen_ch
            dec b
            jr nz, .p
            ret
os_title:   db "Config", 0                  ; (the main menu's label, MM-A)
os_labels:  db "Battle Speed", 0, "Text Speed", 0, "Volume", 0, "B Dash", 0, "Cursor", 0
            db "Auto Retarget", 0, "Modern MP", 0
            db "Window Red", 0, "Window Green", 0, "Window Blue", 0, "Gradient", 0, "LCD", 0
            db "EXP", 0, "Gold", 0, "Window", 0, "No Encounters", 0
os_var:     dw respond, tw_spd, opt_vol, opt_nodash, opt_curr, opt_retgt, opt_mmp, win_r, win_g, win_b, opt_nograd, opt_ccm
            dw KN_EXP, KN_GOLD, opt_dmgw, SC_NOENC
os_max:     db 8, 5, 8, 2, 2, 2, 2, 32, 32, 32, 2, 3, 5, 5, 2, 2
os_fmt:     db 18, 0, 12, 1, 18, 2, 16, 3, 11, 4, 16, 5, 16, 5, 17, 6, 17, 6, 17, 6, 16, 3, 6, 7
            db 13, 8, 13, 8, 14, 9, 16, 5   ; (the value's column, its format)
os_sv:      dw respond, tw_spd, opt_vol, opt_nodash, opt_curr, win_r, win_g, win_b, opt_nograd, opt_retgt, opt_mmp, opt_ccm
            dw opt_dmgw
                                            ; (the saved order: the older records' first nine)
os_onoff:   db "Off", " On"
os_lcd:     db "      Default", "GBC Corrected", "GBA Corrected"
os_spn:     db "   Slow", " Normal", "   Fast", " Faster", "Instant"
os_dash:    db " On", "Off"
os_cur:     db "Remember", "   Reset"
os_wnd:     db "Black", "White"

; ---- the Konami Code on the Formation menu (owner, 2026-11-24): Up Up Down Down Left Right Left
; Right B A shows Options' LCD (Color) and EXP / Gold multipliers for this file (KN_MARK in the
; save page). A = the keys the menu acts on: the B after the eight directions is held back (else
; it would leave), the A that ends the code is used up
kn_seq:     db $40, $40, $80, $80, $20, $10, $20, $10, $02, $01
kn_feed:    ldh a, [pad_new]
            and a
            ret z
            ld b, a
            ld a, [kn_st]
            ld e, a
            ld d, 0
            ld hl, kn_seq
            add hl, de
            ld a, b
            cp [hl]
            jr nz, .miss
            inc e
            ld a, e
            ld [kn_st], a
            cp 9
            jr z, .hold
            cp 10
            jr z, .ok
            ld a, b
            ret
.hold:      xor a
            ret
.ok:        xor a
            ld [kn_st], a
            ld a, $A5
            ld [KN_MARK], a
            ld a, SFX_MAGIC
            ld [sfx_req], a
            xor a
            ret
.miss:      ld a, b                         ; (a key off the code: from the start; an Up
            cp $40                          ;   begins it again)
            ld a, 0
            jr nz, .z
            inc a
.z:         ld [kn_st], a
            ld a, b
            ret

section bank 99, $7700                      ; (the body of eqm_pal)
eqm_palf:   ldh a, [is_cgb]                 ; (a plain Game Boy: no colours)
            and a
            ret z
            ld de, eqm_c3                   ; colour 3 of palettes 1-4: NES green, red, yellow (the
            ld a, $2A                       ;   labels' gold), grey (a choice not open now), corrected
            call .nes                       ;   for the LCD mode (cc.s) before any palette write, so
            ld a, $26                       ;   the writes stay in V-Blank when the LCD is on
            call .nes
            ld a, $28
            call .nes
            xor a
            call .nes
            ld hl, eqm_c3
            ld b, 8
            call cc_inpl
            ld hl, win_pal                  ; colours 0-2: the window's (the Options' choice,
            ld de, eqm_buf                  ;   already corrected)
            ld bc, 8
            call memcpy
            ld a, [lmask]                   ; (the LCD on, not a masked load: the writes in
            and a                           ;   V-Blank)
            jr nz, .w
            ldh a, [rLCDC]
            add a, a
            call c, wait_vbl
.w:         ld de, eqm_c3
            ld a, $80 | 8
            call .put
            ld a, $80 | 16
            call .put
            ld a, $80 | 24
            call .put
            ld a, $80 | 32
.put:       call bcps_w
            ld a, [de]
            inc de
            ld [eqm_buf + 6], a
            ld a, [de]
            inc de
            ld [eqm_buf + 7], a
            ld hl, eqm_buf
            ld b, 8
.p:         ld a, [hl+]
            call bcpd_w
            dec b
            jr nz, .p
            ret
.nes:       push de
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
            ret
; Options: the hand's colours (OBJ palettes 0-3) for a new LCD mode (cc.s): made ready, written
opt_objp:   ld a, UI_GFX
            ld hl, U_OBJPAL
            ld de, scr_buf
            ld bc, 32
            call far_copy
            ld hl, scr_buf
            ld b, 32
            jp cc_inpl
opt_objw:   ld a, $80
            ldh [rOCPS], a
            ld hl, scr_buf
            ld b, 32
.o:         ld a, [hl+]
            ldh [rOCPD], a
            dec b
            jr nz, .o
            ret

section bank 99, $7800
; ---- Super Game Boy, menu screens (polish, 2026-11-24): a sprite takes the colours of the cell
; under it, so the party's pictures showed in the windows' white / grey. Each picture placed by
; scr_spr23 (up to four on a screen) gets the battle's palette for its job's FF1 sprite palette
; (SGB palette 2 / 3, their darkest colour the windows' blue: the cells' background); sent when
; the screen is shown, again when a picture changes on a shown screen
sgb_pic:    ld a, [sgb_py]                  ; (the cells are worked out when sent)
            ld c, a
            ld a, [scr_t0]                  ; FF1's sprite palette 1 jobs: SGB 2, else 3
            and a
            ld a, $0A
            jr nz, .p
            ld a, $0F
.p:         ld e, a
            ld hl, sgb_pl                   ; its sprite slot already listed: moved / changed?
            ld a, [sgb_pn]
            ld d, a
.f:         ld a, d
            and a
            jr z, .new
            ld a, [sgb_pk]
            cp [hl]
            jr z, .old
            inc hl
            inc hl
            inc hl
            inc hl
            dec d
            jr .f
.old:       inc hl                          ; (moved within the same cells and the same
            ld a, [sgb_px]                  ;   palette: nothing to send)
            add a, 3
            call sgb_c8
            ld b, a
            ld a, [hl]
            add a, 3
            call sgb_c8
            cp b
            jr nz, .ch
            inc hl
            ld a, c
            add a, 3
            call sgb_c8
            ld b, a
            ld a, [hl-]
            add a, 3
            call sgb_c8
            cp b
            jr nz, .ch
            inc hl
            inc hl
            ld a, [hl-]
            dec hl
            cp e
            jr nz, .ch
            ld a, [sgb_px]                  ; (the place kept exact)
            ld [hl+], a
            ld [hl], c
            ret
.ch:        ld a, [sgb_px]
            ld [hl+], a
            ld a, c
            ld [hl+], a
            ld [hl], e
            jr sgb_live
.new:       ld a, [sgb_pn]
            cp 4
            ret nc                          ; (more than four: none coloured, all alike)
            ld a, [sgb_pk]
            ld [hl+], a
            ld a, [sgb_px]
            ld [hl+], a
            ld a, c
            ld [hl+], a
            ld [hl], e
            ld hl, sgb_pn
            inc [hl]
; on a shown screen: the attribute block again (the palettes are in)
sgb_live:   ldh a, [rLCDC]
            bit 7, a
            ret z
            ld a, [sgb_qi]
            ld hl, sgb_qn
            cp [hl]
            jr c, .q
            xor a
            ld [sgb_qi], a
            ld [hl], a
.q:         ld a, [hl]
            cp 5
            ret nc
            jr sgb_attr
sgb_c8:     srl a
            srl a
            srl a
            ret
; scr_show: the screen's packets made again with the pictures' palettes and blocks
sgb_pics:   ld a, [sgb_pn]
            and a
            ret z
            cp 5
            ret nc
            call sgb_new
            call alt_pal01                  ; PAL01: the windows (their colour), the gold labels
            call sgb_p23
            call sgb_attr
            jp sgb_end
sgb_p23:    ld hl, SG_FIXED + 16            ; PAL23: the party's two, darkest = the windows' blue
            ld de, sgb_tmp
            ld bc, 8
            ld a, SGB_BANK
            call far_copy
            ld hl, SG_FIXED + 34
            ld de, sgb_tmp + 8
            ld bc, 6
            ld a, SGB_BANK
            call far_copy
            ld de, sgb_tmp + 6              ; (darkest: the windows' inside)
            call sgb_wc
            ld de, sgb_tmp + 12
            call sgb_wc
            ld a, $09
            ld hl, sgb_tmp
            ld c, 0
            jp sgb_pal
; ATTR_BLK (two packets): the screen palette 0, then each picture's cells
sgb_attr:   call sgb_slot
            push de
            call sgb_slot
            pop de
            push de
            ld b, 32
            xor a
.z:         ld [de], a
            inc de
            dec b
            jr nz, .z
            pop de
            ld a, $22
            ld [de], a
            inc de
            call sgb_nblk                   ; (the screen, the gold labels, the pictures)
            ld [de], a
            inc de
            ld a, $07                       ; the whole screen: palette 0 (3: black outside)
            ld [de], a
            inc de
            call sgb_scrb
            ld a, 19
            ld [de], a
            inc de
            ld a, 17
            ld [de], a
            inc de
            call sgb_gblk
            ld hl, sgb_pl + 1               ; (x, y, palette of each)
            ld a, [sgb_pn]
            and a                           ; (none: gold labels only)
            ret z
            ld c, a
.e:         ld a, $03                       ; inside + border
            ld [de], a
            inc de
            inc hl
            inc hl
            ld a, [hl-]                     ; the palette
            ld [de], a
            inc de
            dec hl
            ld a, [hl+]                     ; x1 = (x + 3) / 8, y1 = (y + 3) / 8,
            ld b, a                         ; x2 = (x + 12) / 8, y2 = (y + 20) / 8
            add a, 3
            call sgb_c8
            ld [de], a
            inc de
            ld a, [hl]
            add a, 3
            call sgb_c8
            ld [de], a
            inc de
            ld a, b
            add a, 12
            call sgb_c8
            ld [de], a
            inc de
            ld a, [hl+]
            add a, 20
            call sgb_c8
            ld [de], a
            inc de
            inc hl                          ; (the next entry's x)
            inc hl
            dec c
            jr nz, .e
            ret

section bank 0, $16F0                       ; (after refl_tick: the menu pictures' resets)
sgb_menu0:  jp alt_new                       ; (scr_open: no pictures yet; a new screen)
sgb_btl0:   xor a                           ; (a battle: its own palettes; no gold-label pass:
            ld [sgb_pn], a                  ;   it sent the menus' palettes over the battle's
            ld [alt_ok], a                  ;   on the SGB and its glyphs would take battle
            ld [alt_g], a                   ;   (alt_g: the last screen's gold, alt_show's test)
            jp sgb_battle                   ;   tiles $C0-$FF; since 3b67bca)

section bank 0, $2CCE                       ; (free space)
; ---- plain Game Boy / Super Game Boy: the Color's gold labels and grey choices (attributes $0B /
; $0C) in other inks (owner's audit, 2026-11-25; body in bank 99: alt_pass)
alt_upd:    push hl                         ; (and the pictures' outlines when one changed: ul.s)
            push de
            push bc
            ld a, F3_BANK
            ld hl, pic_upd
            call bank_call
            pop bc
            pop de
            pop hl
            ret
alt_new:    ld a, 1                         ; (scr_open: a new screen; its glyphs made again)
            ld [alt_ok], a
            xor a
            ld [alt_n], a
            ld [alt_g], a
            ld [sgb_pn], a
            ld a, F3_BANK
            ld hl, sgb_menu9
            jp bank_call
; the screens' DMG shades: black windows (FF1's blue as black) or, Options' Window White, the
; same inverted: dark text on white windows (owner's audit, 2026-11-25; not on the SGB)
scr_dmgpal: ld a, [sgb_on]
            and a
            jr nz, .b
            ld a, [opt_dmgw]
            and a
            jr z, .b
            ld a, %00011011
            call bgp_w
            ld a, DMG_OBP_BLK               ; (sprites as on black: the pictures' black outline,
            jp obp0_w                       ;   ul.s, sets them apart; owner, 2026-11-25)
.b:         ld a, %11100100
            call bgp_w
            ld a, DMG_OBP_BLK
            jp obp0_w

section bank 99, $7B60
; ---- plain Game Boy / Super Game Boy: the Color shows labels in gold (attribute palette 3) and
; closed choices in grey (palette 4) with the same font; here those cells get a copy of their glyph
; in another ink, made in tiles $C0-$FF (free on the menu screens): gold = shade 1 (the DMG's light
; grey; the SGB's palette 1, gold), grey = shade 2 (dark grey). On the SGB the gold cells' area takes
; palette 1 (its other colours the windows' own). Off on screens that use $C0-$FF or these palettes
; otherwise (the prologue's fades, the Bestiary's entries: alt_ok 0)
ALT_TBL    = $C500          ; key (code | $80 grey) -> tile (GR_A: the Color's gradient only)
ALT_KEY    = $C600          ; tile - $C0 -> its key (GR_B)
ALT_T0     = $C0
ALT_MAX    = 32             ; ($C0-$DF: the pictures' outlines take $E0-$FF on DMG: ul.s)
alt_show:   call alt_pass
            ld a, [sgb_on]
            and a
            ret z
            ld a, [sgb_pn]                  ; (no pictures: the gold labels' palette, if any)
            and a
            jr nz, .pc
            ld a, [alt_g]
            and a
            ret z
            jr alt_bshow
.pc:        ld a, [alt_g]
            and a
            jp z, sgb_pics
            ld a, [sgb_pn]                  ; (with four pictures no block is left: labels in
            cp 4                            ;   the DMG's light grey)
            jr c, .g
            xor a
            ld [alt_g], a
            jp sgb_pics
.g:         call sgb_new
            call alt_pal01
            call sgb_p23
            call sgb_attr
            jp sgb_end
alt_bshow:  call sgb_new
            call alt_pal01
            call sgb_attr
            jp sgb_end
alt_pal01:  ld hl, SG_FIXED                 ; PAL01: the windows, the gold labels
            ld de, sgb_tmp
            ld bc, 8
            ld a, SGB_BANK
            call far_copy
            ld hl, SG_FIXED + 42
            ld de, sgb_tmp + 8
            ld bc, 6
            ld a, SGB_BANK
            call far_copy
            ld de, sgb_tmp + 6              ; (the windows' inside: Options' colour)
            call sgb_wc
            ld de, sgb_tmp + 12
            call sgb_wc
            ld a, $01
            ld hl, sgb_tmp
            ld c, 0
            jp sgb_pal
; [DE] = the windows' inside colour on the SGB: black (owner, 2026-11-25: the SGB's blue window
; black too; the Options' window colour no longer applies there)
sgb_wc:     xor a
            ld [de], a
            inc de
            ld [de], a
            ret
sgb_wc_rgb: ld a, [win_g]                   ; (the Options' colour, as before: unused)
            swap a
            rlca
            and $E0
            ld b, a
            ld a, [win_r]
            or b
            ld [de], a
            inc de
            ld a, [win_g]
            rrca
            rrca
            rrca
            and 3
            ld b, a
            ld a, [win_b]
            add a, a
            add a, a
            or b
            ld [de], a
            ret
; the menus' packets (scr_open): PAL01 with the windows' colour, the screen palette 0
sgb_menu9:  call ul_new                     ; (no pictures' outlines yet: ul.s)
            ld a, [sgb_on]
            and a
            ret z
            call sgb_new
            call alt_pal01
            ld hl, SG_ALL0
            call sgb_put
            jp sgb_end
; Options on the SGB: a window colour changed: PAL01 again (no mask)
sgb_wlive:  ld a, [sgb_on]
            and a
            ret z
            ld a, [sgb_qi]
            ld hl, sgb_qn
            cp [hl]
            jr c, .q
            xor a
            ld [sgb_qi], a
            ld [hl], a
.q:         ld a, [hl]
            cp 5
            ret nc
            jp alt_pal01
; the screen's cells: gold / grey cells' glyphs to their ink copies; the gold area (alt_x0 ..)
alt_pass:   ld a, [alt_ok]
            and a
            ret z
            xor a
            ld [alt_g], a
            ld [alt_x1], a
            ld [alt_y1], a
            dec a
            ld [alt_x0], a
            ld [alt_y0], a
            ld hl, sattr
            ld c, 0
.r:         ld b, 0
.c:         ld a, [hl]
            and 7
            cp 3
            jr z, .g
            cp 4
            jr nz, .n
            ld d, $80
            jr .t
.g:         ld a, 1
            ld [alt_g], a
            ld a, [alt_x0]
            cp b
            jr c, .g1
            ld a, b
            ld [alt_x0], a
.g1:        ld a, [alt_x1]
            cp b
            jr nc, .g2
            ld a, b
            ld [alt_x1], a
.g2:        ld a, [alt_y0]
            cp c
            jr c, .g3
            ld a, c
            ld [alt_y0], a
.g3:        ld a, [alt_y1]
            cp c
            jr nc, .g4
            ld a, c
            ld [alt_y1], a
.g4:        ld d, 0
.t:         push hl
            ld a, h                         ; (the map copy's cell: sattr - $300)
            sub 3
            ld h, a
            ld a, [hl]
            cp $21                          ; (blanks, the frame, icons: as they are)
            jr c, .s
            cp $80
            jr nc, .s
            or d
            push bc
            call alt_get
            pop bc
            and a
            jr z, .s
            ld [hl], a
.s:         pop hl
.n:         inc hl
            inc b
            ld a, b
            cp 20
            jr c, .c
            ld de, 12
            add hl, de
            inc c
            ld a, c
            cp 18
            jr c, .r
            ret
; A = key -> A = its tile (made if new), 0 if the 64 are taken; keeps HL
alt_get:    push hl
            ld e, a
            ld l, a
            ld h, high(ALT_TBL)
            ld a, [hl]
            sub ALT_T0
            jr c, .new
            ld c, a
            ld a, [alt_n]
            cp c
            jr z, .new
            jr c, .new
            push hl
            ld h, high(ALT_KEY)
            ld l, c
            ld a, [hl]
            pop hl
            cp e
            jr nz, .new
            ld a, c
            add a, ALT_T0
            jr .x
.new:       ld a, [alt_n]
            cp ALT_MAX
            jr nc, .full
            ld c, a
            inc a
            ld [alt_n], a
            ld a, c
            add a, ALT_T0
            ld [hl], a
            push af
            ld h, high(ALT_KEY)
            ld l, c
            ld [hl], e
            call alt_mk
            pop af
            jr .x
.full:      xor a
.x:         pop hl
            ret
; tile C ($C0 + C) from key E: the DMG font's glyph (text shade 0) in shade 1 or (key bit 7) 2
alt_mk:     ld a, e
            ld [alt_k], a
            ld a, c
            ld [alt_t], a
            ld a, e
            and $7F
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, C_FONTDMG
            add hl, de
            ld de, alt_buf
            ld bc, 16
            ld a, COMMON
            call far_copy
            ld hl, alt_buf
            ld b, 8
.r:         ld a, [hl+]
            ld d, a                         ; D = low plane, E = high plane
            ld a, [hl-]
            ld e, a
            or d
            cpl
            ld c, a                         ; C = the text's pixels
            ld a, [alt_k]
            bit 7, a
            jr nz, .i2
            ld a, d
            or c
            ld [hl+], a
            inc hl
            jr .nx
.i2:        inc hl
            ld a, e
            or c
            ld [hl+], a
.nx:        dec b
            jr nz, .r
            ld a, [alt_t]                   ; DE = $8C00 + 16 t
            swap a
            ld e, a
            and $0F
            add a, $8C
            ld d, a
            ld a, e
            and $F0
            ld e, a
            ld hl, alt_buf
            ld b, 16
.w:         di                              ; (no interrupt between the check and the
            ldh a, [rLCDC]                  ;   write: a music tick put it in mode 3 on the
            bit 7, a                        ;   SGB; Lot Check checker)
            jr z, .wr
.ws:        ldh a, [rSTAT]                  ; (LCD on: each byte in mode 0 / 1)
            and 2
            jr nz, .ws
.wr:        ld a, [hl+]
            ld [de], a
            ei
            inc de
            dec b
            jr nz, .w
            ret
; the SGB's ATTR_BLK: the number of blocks; the gold labels' block (palette 1)
sgb_nblk:
.p:         ld a, [sgb_pn]
            inc a
            ld hl, alt_g
            add a, [hl]
            ret
sgb_scrb:   xor a                           ; the screen block's palette 0, x1, y1 (SGB note:
            ld [de], a                      ;   the windows' outside stays blue: a frame cell
            inc de                          ;   holds outside and inside pixels and takes one
            ld [de], a                      ;   palette; owner's audit 2026-11-25)
            inc de
            ld [de], a
            inc de
            ret
sgb_gblk:
.g:         ld a, [alt_g]
            and a
            ret z
            ld a, $03
            ld [de], a
            inc de
            ld a, $05                       ; (inside and border palette 1)
            ld [de], a
            inc de
            ld a, [alt_x0]
            ld [de], a
            inc de
            ld a, [alt_y0]
            ld [de], a
            inc de
            ld a, [alt_x1]
            ld [de], a
            inc de
            ld a, [alt_y1]
            ld [de], a
            inc de
            ret

section wram, $C640                         ; (GR_B's rest: the Color's gradient only)
alt_n:      ds 1
alt_ok:     ds 1
alt_g:      ds 1
alt_x0:     ds 1
alt_y0:     ds 1
alt_x1:     ds 1
alt_y1:     ds 1
alt_k:      ds 1
alt_t:      ds 1
alt_buf:    ds 16

section bank 0, $3802                       ; (gr_reg: moved, it grew)
gr_reg:     push hl
            ld a, [gr_wn]                   ; (a window drawn again: listed once; owner's
            and a                           ;   audit, 2026-11-25: the shops' speech window
            jr z, .nw                       ;   was listed at every line said)
            ld hl, gr_win
.d:         push af
            ld a, [hl+]
            cp b
            jr nz, .n3
            ld a, [hl+]
            cp c
            jr nz, .n2
            ld a, [hl+]
            cp d
            jr nz, .n1
            ld a, [hl+]
            cp e
            jr nz, .n0
            pop af
            pop hl
            ret
.n3:        inc hl
.n2:        inc hl
.n1:        inc hl
.n0:        pop af
            dec a
            jr nz, .d
.nw:        ld a, [gr_wn]
            cp GR_MAXW
            jr nc, .x
            inc a
            ld [gr_wn], a
            dec a
            add a, a
            add a, a
            add a, low(gr_win)
            ld l, a
            ld a, high(gr_win)
            adc a, 0
            ld h, a
            ld a, b
            ld [hl+], a
            ld a, c
            ld [hl+], a
            ld a, d
            ld [hl+], a
            ld [hl], e
            ld a, 1
            ld [gr_dirty], a
.x:         pop hl
            ret

section bank 99, $7400                      ; (free space)
; ---- the Sound Test code (owner, 2026-11-25: tracks 1 9 9 2 1 1 2 4, then a save loaded): EXP /
; Gold multipliers up to 128X, No Encounters in Options, and the main menu's Suspend becomes Save:
; the file (as an inn's save) plus the exact place (the suspend point's blocks) in cart RAM bank 2,
; $A000 + $600 x file, loaded with that file. An inn's save over the file drops the place.
os_mul:     db "Normal", "    2X", "    4X", "    8X", "   12X", "   24X", "   48X", "   64X", "  128X"
; Z if this file has the code
sc_on:      ld a, [SC_MARK]
            cp $5A
            ret
; Options: the list (HL, C counted) gets No Encounters
sc_lst:     call sc_on
            ret nz
            ld a, 15
            ld [hl+], a
            inc c
            ret
; Options: C = setting E's count (HL at os_max's entry): EXP / Gold 9 with the code
opt_mx:     ld c, [hl]
            ld a, e
            cp 12
            ret c
            cp 14
            ret nc
            call sc_on
            ret nz
            ld c, 9
            ret
; the suspend routines (screens.s) pointed at file sv_slot's place, and back
sva_set:    ld a, 1
            ld [sus_bk], a
            ld a, [sv_slot]
            ld b, a
            add a, a
            add a, b
            add a, a
            ld [sus_bo], a
            ret
sva_clr:    xor a
            ld [sus_bk], a
            ld [sus_bo], a
            ret
; HL in bank SCR_BANK with the file's place
sva_run:    push hl
            call sva_set
            pop hl
            ld a, SCR_BANK
            call bank_call
            push af
            call sva_clr
            pop af
            ret
; after a save to file sv_slot: its place written (the main menu's Save) or dropped (an inn)
sva_after:  ld a, [sva_req]
            and a
            ld hl, sus_write
            jr nz, sva_run
            ld hl, sus_erase
            jr sva_run
; after file sv_slot was loaded: its place, if any (resumed as a suspend point), else the map
; from the save page; sv_fix either way (sus_load calls it)
sva_ld:     ld hl, sus_state
            call sva_run
            dec a
            jr nz, .no
            ld hl, sus_load
            call sva_run
            ld a, 1
            ld [sus_res], a
            ret
.no:        ld a, EXTRA_BANK
            ld hl, sv_fix
            jp bank_call
; the main menu's Save (in Suspend's place): the file picker in save mode, the place with it
sva_menu:   ld a, 1
            ld [sva_req], a
            call file_save
            xor a
            ld [sva_req], a
            ret

; ---- the main menu, MM-A (owner, 2026-11-25): the windows, and the members' lines in colour
section bank 99, $4E40                      ; (free space)
; the windows: party (0,0,11,14), the commands (10,0,10,9) over its right edge (the whole hand
; inside: labels from column 13), the orbs (10,8,10,6), the place / time / Gil (0,13,20,5);
; the command cursor kept from the last opening (in range)
mm_wins:    ld a, [mm_cur]
            cp 7
            jr c, .k
            xor a
            ld [mm_cur], a
.k:         call eqm_pal                    ; (palettes 2 / 3 / 4: red, gold, grey for mm_hpc)
            ld bc, $0000
            ld de, $0B0E
            call scr_win
            ld bc, $0A00
            ld de, $0A09
            call scr_win
            ld bc, $0A08
            ld de, $0A06
            call scr_win
            ld bc, $000D
            ld de, $1405
            jp scr_win
; member mm_t's lines as the battle's party lines: HP under a quarter: the HP line gold (palette
; 3); dead / stone: the ailment and HP lines red on the Color (palette 2), grey on the plain Game
; Boy / Super Game Boy (palette 4: their grey ink, alt_pass)
mm_hpc:     ld a, [mm_t]
            call ch_rec
            inc hl
            ld a, [hl-]                     ; (outside battle: 1 dead, 2 stone, 3 poison)
            dec a
            cp 2
            jr nc, .hp
            ld e, 2
            ldh a, [is_cgb]
            and a
            ld d, $0A
            jr nz, .set
            ld d, $0C
            jr .set
.hp:        ld a, l
            add a, CH_HP
            ld l, a
            ld a, [hl+]                     ; HP x 4 < max?
            ld e, a
            ld a, [hl+]
            ld d, a
            sla e
            rl d
            sla e
            rl d
            ld a, [hl+]
            ld c, a
            ld b, [hl]
            ld a, e
            sub c
            ld a, d
            sbc a, b
            ret nc
            ld d, $0B
            ld e, 1
.set:       ld a, [mm_t]                    ; the last E of its rows 1 + 3 m .. 3 + 3 m
            ld c, a
            add a, a
            add a, c
            add a, 4
            sub e
            ld c, a
            ld b, 3
.r:         push bc
            call cell_addr
            ld a, h
            add a, 3
            ld h, a
            ld b, 7
.c:         ld [hl], d
            inc hl
            dec b
            jr nz, .c
            pop bc
            inc c
            dec e
            jr nz, .r
            ret
