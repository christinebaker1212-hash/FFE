; FF1 native engine: the packs screen (owner, 2026-11-26: 'Individual weapon inventories still exist,
; but the player has no way to sort or manage them ... keeping the spirit of the NES version'). FF1's
; Weapon / Armor screens had Equip / Trade / Drop over the four members' four slots each; here, from
; the Equip screen (its Packs entry, or SELECT): one member's four weapons and four armour (worn ones
; marked E), left / right the next member. A on an item not worn: Give it to another member (each
; shown with its free slots of that kind); to a full pack: pick the item it trades places with
; (FF1's Trade). SELECT on an item not worn: Drop it (Yes / No). The packs stay tidy: worn first,
; then by item, empty slots last. Worn items stay put (the Equip screen changes them).
PK_BANK    = 107
pk_m       = eqm_bk                         ; member shown
pk_c       = eqm_bk + 1                     ; hand: 0-3 weapons, 4-7 armour
pk_t       = eqm_bk + 2                     ; target member (Give)
pk_tc      = eqm_bk + 3                     ; hand in the member / trade lists
pk_mem     = eqm_bk + 4                     ; the three other members (3)
pk_k       = eqm_bk + 7                     ; scratch
pk_src     = eqm_bk + 8                     ; (2) the item's slot address
pk_n       = eqm_bk + 10                    ; scratch
pk_row     = eqm_bk + 11                    ; the row pk_item writes on

section bank 107, $4D30
; the screen for member pk_m; back with pk_m the member last shown
pk_main9:   xor a
            ld [pk_c], a
            call pk_tidy
.scr:       call pk_draw
.l:         call pk_hnd
            call scr_frame
            ldh a, [pad_new]
            bit 1, a
            jr nz, .x
            bit 0, a
            jr nz, .give
            bit 2, a
            jr nz, .drop
            ld hl, pk_c
            bit 6, a
            jr nz, .up
            bit 7, a
            jr nz, .dn
            ld hl, pk_m
            bit 4, a
            jr nz, .rt
            bit 5, a
            jr z, .l
            ld a, [hl]
            dec a
            jr .mv
.rt:        ld a, [hl]
            inc a
.mv:        and 3
            ld [hl], a
            jr .scr
.up:        ld a, [hl]
            dec a
            jr .cm
.dn:        ld a, [hl]
            inc a
.cm:        and 7
            ld [hl], a
            jr .l
.x:         ld a, [pk_m]
            ret
.give:      call pk_movable                 ; (an item, not worn)
            jr c, .no
            call pk_give
            call pk_mid                     ; (the packs again, in place)
            jp .l
.drop:      call pk_movable
            jr c, .no
            ld a, 2                         ; Drop it? (bank 2: the question's own screen)
            ld hl, pk_ask
            call bank_call
            and a
            jr nz, .scr
            call pk_srcp
            xor a
            ld [hl], a
            call pk_tidy
            jr .scr
.no:        call sfx_err
            jr .l

; the hand: row 6-9 (weapons) or 11-14 (armour), the item's name at column 2
pk_hnd:     ld a, [pk_c]
            cp 4
            jr c, .w
            inc a
.w:         add a, 6
            ld c, a
            ld b, 2
            jp cur_txt

; HL = the slot under the hand (pk_m, pk_c)
pk_srcp:    ld a, [pk_c]
            ld e, a
            ld a, [pk_m]
; A = member, E = 0-7 -> HL = its slot (weapons $18-$1B, armour $1C-$1F)
pk_slotp:   call ch_rec
            ld a, l
            add a, $18
            add a, e
            ld l, a
            ret
; C if the slot under the hand is empty or worn
pk_movable: call pk_srcp
            ld a, [hl]
            and a
            jr z, .n
            bit 7, a
            jr nz, .n
            and a
            ret
.n:         scf
            ret

; the screen: the member's top window, the packs window
pk_draw:    call scr_open
            ld a, 2
            ld hl, pk_mtop
            call bank_call
            ld hl, str_pk
            call pen_str
            ld bc, $0005
            ld de, $140D
            call scr_win
            call pk_rows
            call pk_hint
            jp scr_show
; the packs window again (after Give: no fade)
pk_mid:     ld bc, $0005
            ld de, $140D
            call scr_win
            call pk_rows
            call pk_hint
            jp scr_upd
pk_hint:    ld bc, $0110
            call pen_at
            ld hl, str_pkh
            jp pen_str
; the eight rows of member pk_m
pk_rows:    xor a
.r:         ld [pk_n], a
            ld e, a
            cp 4
            jr c, .w
            inc a
.w:         add a, 6
            ld c, a
            ld b, 1
            call pen_at
            ld b, 18
            call pen_sp
            ld a, [pk_n]
            ld e, a
            cp 4
            jr c, .w2
            inc a
.w2:        add a, 6
            ld c, a
            ld [pk_row], a
            ld b, 2
            call pen_at
            ld a, [pk_n]
            ld e, a
            ld a, [pk_m]
            call pk_slotp
            ld a, [pk_n]
            call pk_item
            ld a, [pk_n]
            inc a
            cp 8
            jr c, .r
            ret
; [HL] = a slot of kind A >> 2 (0 weapons): its icon and name at the pen, E at column 18 if worn;
; empty: the kind's icon and a dash
pk_item:    and 4
            ld [eqm_ft], a                  ; (eqm_name: 0 weapons, else armour)
            ld a, [hl]
            and a
            jr nz, .i
            ld a, [eqm_ft]
            and a
            ld a, $19
            jr z, .e
            ld a, $07
.e:         call pen_ch
            ld a, '-'
            jp pen_ch
.i:         push af
            and $7F
            ld b, a
            ld a, [eqm_ft]
            and a
            ld a, 27                        ; (weapons: names 28-67, armour 68-107)
            jr z, .nw
            ld a, 67
.nw:        add a, b
            call pen_iname
            pop af
            bit 7, a
            ret z
            ld a, [pk_row]                  ; worn: E at column 18
            ld c, a
            ld b, 18
            call pen_at
            ld a, 'E'
            jp pen_ch

; Give: the three other members (with their free slots of this kind); a full one: trade
pk_give:    ld hl, pk_mem
            ld a, [pk_m]
            ld b, 3
.o:         inc a
            and 3
            ld [hl+], a
            dec b
            jr nz, .o
            xor a
            ld [pk_tc], a
            ld bc, $0805                    ; the window over the packs' right side
            ld de, $0C06
            call scr_win
            ld bc, $0906
            call pen_at
            ld hl, str_pkto
            call pen_str
            xor a
.m:         ld [pk_n], a
            add a, 7
            ld c, a
            ld b, 10
            call pen_at
            ld a, [pk_n]
            ld e, a
            ld d, 0
            ld hl, pk_mem
            add hl, de
            ld a, [hl]
            push af
            call pen_name
            pop af
            call pk_free                    ; its free slots: a digit at column 18
            push af
            ld a, [pk_n]
            add a, 7
            ld c, a
            ld b, 18
            call pen_at
            pop af
            add a, '0'
            call pen_ch
            ld a, [pk_n]
            inc a
            cp 3
            jr c, .m
            call scr_upd
.l:         ld a, [pk_tc]
            add a, 7
            ld c, a
            ld b, 10
            call cur_txt
            call scr_frame
            ldh a, [pad_new]
            bit 1, a
            ret nz
            bit 0, a
            jr nz, .a
            ld hl, pk_tc
            bit 6, a
            jr nz, .u
            bit 7, a
            jr z, .l
            ld a, [hl]
            inc a
            cp 3
            jr c, .s
            xor a
            jr .s
.u:         ld a, [hl]
            dec a
            cp $FF
            jr nz, .s
            ld a, 2
.s:         ld [hl], a
            jr .l
.a:         ld a, [pk_tc]
            ld e, a
            ld d, 0
            ld hl, pk_mem
            add hl, de
            ld a, [hl]
            ld [pk_t], a
            call pk_free
            and a
            jr z, pk_trade
            ld a, [pk_t]                    ; room: into its first empty slot of the kind
            call pk_empty
            push hl
            call pk_srcp
            ld a, [hl]
            ld [hl], 0
            pop hl
            ld [hl], a
            jp pk_tidy
; A = member -> A = its empty slots of the hand's kind
pk_free:    ld [pk_k], a
            ld a, [pk_c]
            and 4
            ld e, a
            ld a, [pk_k]
            call pk_slotp
            ld b, 4
            ld c, 0
.c:         ld a, [hl+]
            and a
            jr nz, .n
            inc c
.n:         dec b
            jr nz, .c
            ld a, c
            ret
; A = member -> HL = its first empty slot of the hand's kind
pk_empty:   ld [pk_k], a
            ld a, [pk_c]
            and 4
            ld e, a
            ld a, [pk_k]
            call pk_slotp
.f:         ld a, [hl]
            and a
            ret z
            inc hl
            jr .f

; the target's pack is full: its four items of the kind, A on one not worn trades places
pk_trade:   ld bc, $0005
            ld de, $140D
            call scr_win
            ld bc, $010C                    ; (Full: name / Trade for which?)
            call pen_at
            ld hl, str_pkfull
            call pen_str
            ld a, [pk_t]
            call pen_name
            ld bc, $010D
            call pen_at
            ld hl, str_pktr
            call pen_str
            ld a, [pk_c]
            and 4
            ld [pk_k], a
            xor a
.r:         ld [pk_n], a
            add a, 6
            ld c, a
            ld [pk_row], a
            ld b, 2
            call pen_at
            ld a, [pk_k]
            ld e, a
            ld a, [pk_n]
            add a, e
            ld e, a
            ld a, [pk_t]
            call pk_slotp
            ld a, [pk_k]
            call pk_item
            ld a, [pk_n]
            inc a
            cp 4
            jr c, .r
            call scr_upd
            xor a
            ld [pk_tc], a
.l:         ld a, [pk_tc]
            add a, 6
            ld c, a
            ld b, 2
            call cur_txt
            call scr_frame
            ldh a, [pad_new]
            bit 1, a
            ret nz
            bit 0, a
            jr nz, .a
            ld hl, pk_tc
            bit 6, a
            jr nz, .u
            bit 7, a
            jr z, .l
            ld a, [hl]
            inc a
            jr .s
.u:         ld a, [hl]
            dec a
.s:         and 3
            ld [hl], a
            jr .l
.a:         ld a, [pk_k]                    ; the target's item: not worn
            ld e, a
            ld a, [pk_tc]
            add a, e
            ld e, a
            ld a, [pk_t]
            call pk_slotp
            ld a, [hl]
            bit 7, a
            jr z, .ok
            call sfx_err
            jr .l
.ok:        push hl
            call pk_srcp
            ld b, [hl]
            pop de
            ld a, [de]
            ld [hl], a                      ; trade places
            ld a, b
            ld [de], a
            jp pk_tidy

; every member's packs tidy: worn first, then by item, empty slots last (FF1's four each)
pk_tidy:    xor a
.m:         ld [pk_n], a
            ld e, 0
            call .one
            ld a, [pk_n]
            ld e, 4
            call .one
            ld a, [pk_n]
            inc a
            cp 4
            jr c, .m
            ret
.one:       call pk_slotp                   ; four bytes at HL: bubble sort, key worn first,
            ld c, 3                         ;   then item, 0 last
.p:         push hl
            ld b, 3
.i:         ld a, [hl+]                     ; D = the first, HL at the second
            ld d, a
            ld a, [hl]
            call .key
            ld e, a
            ld a, d
            call .key
            cp e
            jr c, .k
            jr z, .k
            ld a, [hl]                      ; (out of order: swap)
            dec hl
            ld [hl+], a
            ld [hl], d
.k:         dec b
            jr nz, .i
            pop hl
            dec c
            jr nz, .p
            ret
.key:       and a                           ; A = slot -> its key (worn 0-127, not worn
            jr nz, .k1                      ;   128-255, empty 255)
            dec a
            ret
.k1:        xor $80
            ret

str_pk:     db "Packs", 0
str_pkh:    db "A:Give SELECT:Drop", 0
str_pkto:   db "Give to:", 0
str_pkfull: db "Full: ", 0
str_pktr:   db "Trade for which?", 0

section bank 2, $7345                       ; (free space; the packs screen's calls in bank 2)
pk_mtop:    call eqm_pal                    ; the member's top window (mtop: the pen at (4, 3))
            ld a, [pk_m]
            jp mtop
pk_ask:     ld hl, str_pkdrop
            ld a, 1
            ld d, 1
            jp sus_ask
str_pkdrop: db "Drop this item?", 0

; the Equip screen's Packs (bank 2): the packs screen, then the Equip screen again (its member)
eqm_pk:     ld a, [eqm_m]
            ld [pk_m], a
            ld a, PK_BANK
            ld hl, pk_main9
            call bank_call
            ld a, [pk_m]
            ld [eqm_m], a
            jp eqm_main.scr
section bank 2, $6BB2                       ; (free space)
; the Equip screen's entries: Optimize (owner, 2026-11-22), Packs (top right)
eqm_tops:   ld bc, $0B03
            call pen_at
            ld hl, str_eqopt
            call pen_str
            ld bc, $0D01
            call pen_at
            ld hl, str_pk2
            jp pen_str
str_pk2:    db "Packs", 0

section bank 107, $7000                     ; (free space)
; up / down through Packs, Optimize and the rows in use (eqm_nr)
eqm_oup2:    ld a, [eqm_ot]
            and a
            jr z, .sl
            dec a
            jr nz, .last                    ; (from Packs: the last row)
            ld a, 2                         ; (from Optimize: Packs)
            ld [eqm_ot], a
            ret
.sl:        ld a, [eqm_ot]
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
eqm_odn2:    ld a, [eqm_ot]
            and a
            jr z, .sl
            dec a
            jr z, .first                    ; (from Optimize: the first row)
            ld a, 1                         ; (from Packs: Optimize)
            ld [eqm_ot], a
            ret
.sl:        ld a, [eqm_nr]
            ld b, a
            ld a, [eqm_t]
            inc a
            cp b
            jr c, .nx
            ld a, 2                         ; (past the last row: Packs)
            ld [eqm_ot], a
            ret
.nx:        ld [eqm_t], a
            ret
.first:     xor a
            ld [eqm_ot], a
            ld [eqm_t], a
            ret


section bank 107, $7200                     ; (free space)
; orb tiles to BG $80- (LCD off); CGB: the lit orbs' palette as BG palette 6 (from menu.s)
orb_gfx9:    ldh a, [is_cgb]
            and a
            ld hl, U_ORBDMG
            jr z, .t
            ld hl, U_ORBPAL
            ld de, scr_buf
            ld bc, 8
            ld a, UI_GFX
            call far_copy
            ld a, [win_pal + 4]             ; (the box behind: the window's colour, as the
            ld [scr_buf + 4], a             ;   Config sets it; owner, 2026-11-26)
            ld a, [win_pal + 5]
            ld [scr_buf + 5], a
            ld a, $B0
            call bcps_w
            ld hl, scr_buf
            ld b, 8
.p:         ld a, [hl+]
            call bcpd_w
            dec b
            jr nz, .p
            ld hl, U_ORBCGB
.t:         ld de, $8800
            ld bc, 20 * 16
            ld a, UI_GFX
            jp far_copy

