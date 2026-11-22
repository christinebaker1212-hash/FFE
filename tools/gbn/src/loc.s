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

section wram, $CDE3
loc_buf:    ds 19
pt_on:      ds 1                            ; (play time counted: set by the field's loop)
op_k:       ds 1                            ; (Optimize)
op_bv:      ds 1
op_be:      ds 1
op_i:       ds 1
op_e:       ds 1
op_n:       ds 1
