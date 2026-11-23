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
gr_reg:     push hl
            ld a, [gr_wn]
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
            ld a, F3_BANK
            ld hl, gr_menu
            call bank_call
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

section bank 99, $4800
; ---- Options (owner, 2026-11-22; WonderSwan Color remake's choices added): Message Speed, Text
; Speed, Volume, B Dash On / Off, Cursor Remember / Reset, and on the Color the windows'
; colour (red, green, blue 0-31, shown at once). Header (0,0,20,3), list (0,3,20,15), one row a
; setting from row 5; up / down pick, left / right change, B back (kept in cart RAM bank 1)
OPT_N_DMG  = 5
OPT_N_CGB  = 9
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
            ld a, [opt_cur]                 ; (a window colour / the gradient: at once)
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
            db "Window Red", 0, "Window Green", 0, "Window Blue", 0, "Gradient", 0
os_var:     dw respond, tw_spd, opt_vol, opt_nodash, opt_curr, win_r, win_g, win_b, opt_nograd
os_max:     db 8, 5, 8, 2, 2, 32, 32, 32, 2
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
            ld bc, $100D                    ; Window Gradient On / Off
            call pen_at
            ld a, [opt_nograd]
            ld l, a
            add a, a
            add a, l
            ld e, a
            ld d, 0
            ld hl, os_dash
            add hl, de
            ld b, 3
            jr .n
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
            call eqm_pal
            ld a, [opt_nograd]              ; (the gradient from the new colour, or off)
            and a
            jp nz, gr_off
            jp gr_menu
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
            ld [opt_nograd], a
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
.q:         push hl                         ; "OQ": the eight, check ("OR": nine)
            ld a, [opt_ver]
            sub $49                         ; (8 / 9)
            ld b, a
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
            ld de, opt_nodash               ; dash, cursor, r, g, b (checked: 0-1, 0-31), gradient
            ld a, [opt_ver]
            sub $4C                         ; (5 / 6)
            ld b, a
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
            ld a, [opt_nograd]
            cp 2
            jr c, .x
            xor a
            ld [opt_nograd], a
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
            ld a, $52
            ld [hl+], a
            ld de, os_var                   ; the nine values, then the check
            ld b, 9
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
            and a
            ret
.empty:     and a
            jr nz, .save
            call sfx_err                    ; (nothing to load there)
            jr .l
.over:      call fp_clr                     ; Save over File k? A / B
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
; row of every tile each (in the order 0 4 2 6 1 5 3 7): the row slides 2 pixels (odd rows
; left, even right), then goes. A fiend's tiles are its own: changed in place, two frames a
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
.st:        ld a, [ed_s]                    ; the row: order[step / 2]
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
            ld a, [bt_type]                 ; a fiend: the screen shakes, the hit sound
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
; effects any Game Boy can show): 26 frames of the map twisting and zooming towards the party,
; 18 of its 8-line strips sliding apart while it fades to white, 6 white; the battle then
; fades in from white. Per line SCX / SCY from battle.py trans_tables (bank TRANS_BANK), written
; by the STAT mode-0 interrupt (stat_rx); FF1's noise as before.
TR_BUF0    = $C200          ; (the field's queue: free now) frame buffers, 144 x (SCX, SCY)
TR_BUF1    = $C320
TR_PAL     = $C440          ; the faded palettes (BG 64, OBJ 64)
TR_WT      = $C500          ; the fade table: 8 levels x 32 (page-aligned)
TR_FR      = 44
TR_TW      = 26
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
            ld hl, $7200
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
            ld a, 1
            ld [rx_on], a
            ld a, $08                       ; (STAT: mode 0 each line, no LYC meanwhile)
            ldh [rSTAT], a
            ldh a, [rIF]
            and $FD
            ldh [rIF], a
            ei
.f:         call tr_buf                     ; line 0's scroll for the V-Blank to write
            ld a, [hl+]
            ldh [scx], a
            ld a, [hl-]
            ldh [scy], a
            push hl
            call tr_noise
            call wait_vbl
            pop hl
            inc hl
            inc hl
            ld a, l
            ld [rx_ptr], a
            ld a, h
            ld [rx_ptr + 1], a
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
            ld a, [tr_k]                    ; (SGB: colour 0 white for the fade, at the strips)
            cp TR_TW - 4
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
            ld [rx_on], a
            ld a, $40
            ldh [rSTAT], a
            ld a, BOX_LINES
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
; HL = frame tr_k's buffer
tr_buf:     ld a, [tr_k]
            rrca
            ld hl, TR_BUF0
            ret nc
            ld hl, TR_BUF1
            ret
; frame tr_k's lines (the table plus the field's scroll) and, in the strips, its colours
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
            ld bc, 288
            ld a, TRANS_BANK
            call far_copy
            pop hl
            ld a, [tr_x0]
            ld d, a
            ld a, [tr_y0]
            ld e, a
            ld b, 144
.a:         ld a, [hl]
            add a, d
            ld [hl+], a
            ld a, [hl]
            add a, e
            ld [hl+], a
            dec b
            jr nz, .a
            xor a                           ; the fade level: (strip frame + 1) / 2, to 8
            ld [tr_f], a
            ld a, [tr_k]
            sub TR_TW
            ret c
            inc a
            srl a
            cp 9
            jr c, .lv
            ld a, 8
.lv:        ld [tr_f], a
            and a
            ret z
            ldh a, [is_cgb]
            and a
            ret z
            ld a, [tr_f]                    ; Color: 64 colours through the table
            dec a
            swap a
            add a, a                        ; 32 (level - 1)
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
            ld de, 72 * 2
            add hl, de
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

section wram, $C4C0
tr_k:       ds 1
tr_x0:      ds 1
tr_y0:      ds 1
tr_px:      ds 1
tr_f:       ds 1
tr_t:       ds 1
tr_r:       ds 1
tr_g:       ds 1
tr_sgp:     ds 14

section bank 99, $5C00
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
            ld a, [gr_cut]
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
            ret
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
gr_pals:    xor a
            ld [gr_pm], a
            ld [gr_pa], a
            ld [gr_i], a
.w:         ld a, [gr_i]
            call gr_wp
            ld a, [hl+]
            ld b, a                         ; x
            ld a, [hl+]
            ld c, a                         ; y
            ld a, [hl+]
            ld d, a                         ; w
            ld e, [hl]                      ; h
            ld a, [gr_i]
            push de
            ld e, a
            ld d, 0
            ld hl, gr_grp
            add hl, de
            ld a, [hl]
            pop de
            ld [gr_g], a
.r:         push bc
            push de
            call cell_addr
            ld a, h
            add a, 3
            ld h, a
.c:         ld a, [gr_g]                    ; (an alt window's cell under a later main window:
            and a                           ;   that window's)
            jr z, .cv
            push hl
            push bc
            push de
            ld a, b
            ld [gr_cx], a
            ld a, c
            ld [gr_cy], a
            call gr_cov
            pop de
            pop bc
            pop hl
            jr c, .nx
.cv:        ld a, [hl]
            and 7
            cp 5                            ; (palette 5: the black outside)
            jr z, .nx
            push bc
            ld b, a
            ld a, [gr_g]
            and a
            jr z, .mn
            ld a, b                         ; alt: palette 7 -> 0
            cp 7
            jr nz, .ak
            ld a, [hl]
            and $F8
            ld [hl], a
            ld b, 0
.ak:        ld a, b
            call gr_bit
            ld b, a
            ld a, [gr_pa]
            or b
            ld [gr_pa], a
            jr .pp
.mn:        ld a, b
            call gr_bit
            ld b, a
            ld a, [gr_pm]
            or b
            ld [gr_pm], a
.pp:        pop bc
.nx:        inc hl
            inc b
            dec d
            jr nz, .c
            pop de
            pop bc
            inc c
            dec e
            jr nz, .r
            ld hl, gr_i
            inc [hl]
            ld a, [gr_wn]
            cp [hl]
            jp nz, .w
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
; C set: cell (gr_cx, gr_cy) inside a main window drawn after window gr_i
gr_cov:     ld a, [gr_i]
.w:         inc a
            ld hl, gr_wn
            cp [hl]
            ret nc                          ; (NC: none)
            ld [gr_t], a
            ld e, a
            ld d, 0
            ld hl, gr_grp
            add hl, de
            ld a, [hl]
            and a
            ld a, [gr_t]
            jr nz, .w
            call gr_wp
            ld a, [gr_cx]                   ; x <= cx < x + w
            sub [hl]
            jr c, .n
            inc hl
            inc hl
            cp [hl]
            jr nc, .n
            dec hl
            ld a, [gr_cy]
            sub [hl]
            jr c, .n
            inc hl
            inc hl
            cp [hl]
            jr nc, .n
            scf
            ret
.n:         ld a, [gr_t]
            jr .w
; A = palette -> A = its bit
gr_bit:     ld b, a
            ld a, 1
            inc b
.s:         dec b
            ret z
            add a, a
            jr .s
; the event list (HL / DE: its two buffers, A: records at most): per line each group's
; owner (the last window drawn there) and its colour; a record where a colour changes; the
; music in the longest gap; the box's cut
gr_make:    ld [gr_lim], a
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
.gap:       call gr_gap                     ; B = the music's line
            ld c, $40
.add:       call gr_ins
            ld a, [gr_rc]                   ; the end
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
; the last window drawn over the line owns it
gr_col:     ld a, $FF
            ld [gr_tm], a
            ld [gr_ta], a
            ld a, [gr_n]
            ld [gr_t], a
.w:         ld a, [gr_t]
            and a
            jr z, .x
            dec a
            ld [gr_t], a
            ld e, a
            ld d, 0
            ld hl, gr_grp
            add hl, de
            ld a, [hl]
            ld [gr_g], a
            and a                           ; (that group already owned: the next)
            ld a, [gr_tm]
            jr z, .g
            ld a, [gr_ta]
.g:         cp $FF
            jr nz, .w
            ld a, [gr_t]
            call gr_wp
            inc hl
            ld a, [hl+]
            add a, a
            add a, a
            add a, a
            ld b, a                         ; top line
            inc hl
            ld a, [hl]
            add a, a
            add a, a
            add a, a
            ld c, a                         ; lines
            ld a, [gr_ln]
            sub b
            jr c, .w
            cp c
            jr nc, .w
            ld d, a
            dec c
            call gr_idx                     ; A = 31 d / (lines - 1)
            add a, a
            add a, low(gr_ramp)
            ld e, a
            ld a, [gr_g]
            and a
            ld a, e
            jr nz, .al
            ld [gr_tm], a
            jr .w
.al:        ld [gr_ta], a
            jr .w
.x:         ld a, [gr_tm]
            ld e, a
            ld a, [gr_ta]
            ld c, a
            ret
; A = 31 D / C (C > 0)
gr_idx:     push bc
            push de
            ld a, d
            ld l, a
            ld h, 0
            ld e, l
            ld d, h
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl                      ; 32 d
            ld a, l
            sub e
            ld l, a
            ld a, h
            sbc a, d
            ld h, a                         ; 31 d
            ld a, c
            cpl
            ld e, a
            ld d, $FF
            inc de                          ; -c
            ld b, $FF
.d:         inc b
            add hl, de
            jr c, .d
            ld a, b
            cp 32
            jr c, .x
            ld a, 31
.x:         pop de
            pop bc
            ret
; B = the first line of the longest gap between records (to 143)
gr_gap:     ld a, [gr_nb]
            ld l, a
            ld a, [gr_nb + 1]
            ld h, a
            ld a, [gr_rc]
            ld c, a
            ld d, 0                         ; best length
            ld b, 1
.l:         ld e, [hl]                      ; this record's line
            inc hl
            inc hl
            inc hl
            inc hl
            dec c
            ld a, 144
            jr z, .t
            ld a, [hl]
.t:         sub e                           ; the gap after it
            cp d
            jr c, .n
            ld d, a
            ld a, e
            inc a
            ld b, a
.n:         ld a, c
            and a
            jr nz, .l
            ld a, b
            cp 144
            ret c
            ld b, 143
            ret
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

section wram, $CDE4
loc_buf:    ds 19
pt_on:      ds 1                            ; (play time counted: set by the field's loop)
op_k:       ds 1                            ; (Optimize)
op_bv:      ds 1
op_be:      ds 1
op_i:       ds 1
op_e:       ds 1
op_n:       ds 1
