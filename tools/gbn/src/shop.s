; FF1 native engine: shops, inn and clinic (code bank 2). Our own code, written from what FF1's
; shop routines do (disassembly bank 0E: EnterShop and the shop loops). Layout (approved
; SaGa-style shop with the Gil shown): speech (0,0,20,6) up to 4 lines; title (0,6,10,5);
; commands / Yes-No / names (10,6,10,6); the list (0,5,20,12): 5 items x 2 rows (name, the
; price below ending at column 18); Gil (0,15,12,3) over the list's empty corner.
N_STYPE    = $7A00          ; names bank: shop type per shop id, 5 items per shop, magic
N_SITEMS   = $7B00          ;   permissions (8 per class)
N_MPERM    = $7D00
MT_SHOP    = $6000          ; menu text bank: the shop texts
SH_WELCOME = $09
SH_WHAT    = $0D
SH_PRICE   = $0E
SH_NOMONEY = $10
SH_WHO     = $11
SH_THANKS  = $13
SH_SELLWHO = $14
SH_TOOBAD  = $25
SH_FULL    = $0C
SH_NOSELL  = $1E

section bank 2, $5980

; enter shop A (from the map: the door tile's shop number)
shop_main:  ld a, TR_SHOP                   ; (the shop music, again after a jingle: FF1)
            ld [scr_mus], a
            call .in
            xor a
            ld [scr_mus], a
            ret
.in:        ld a, [shop_arg]
            ld [sh_id], a
            ld e, a                         ; type, items (or the inn / clinic price)
            ld d, 0
            ld hl, N_STYPE
            add hl, de
            ld a, NAMES
            ld [fc_bank], a
            call far_byte
            ld [sh_type], a
            ld a, [sh_id]                   ; items: 5 id
            ld l, a
            ld h, 0
            ld d, h
            ld e, l
            add hl, hl
            add hl, hl
            add hl, de
            ld de, N_SITEMS
            add hl, de
            ld de, sh_inv
            ld bc, 5
            ld a, NAMES
            call far_copy
            xor a
            ld [sh_inv + 5], a
            call scr_open
            call eqm_pal                    ; (Color: green / red / gold text, as the menus)
            call sh_base
            call scr_show
            ld a, TR_SHOP                   ; (FF1: the shop music)
            call snd_track
            ld a, [sh_type]
            cp 2
            jp c, sh_equip
            cp 4
            jp c, sh_magic
            jp z, sh_clinic
            cp 5
            jp z, sh_inn
            jp sh_item

; the screen without the list: speech, title, Gil
sh_base:    call scr_cls
            ld bc, $0000
            ld de, $1406
            call scr_win
            ld bc, $0006
            ld de, $0A05
            call scr_win
            ld bc, $0107
            call pen_at
            ld a, [sh_type]                 ; title: the shop's name (shop text = type)
            call sh_text
            ld hl, mtxt
            call pen_str
            jp sh_gold
sh_gold:    ld bc, $000F
            ld de, $0C03
            call scr_win
            ld bc, $0110
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
            ld a, $20
            call pen_ch
            ld hl, str_gil
            jp pen_str

; shop text A -> mtxt
sh_text:    add a, a
            ld l, a
            ld h, high(MT_SHOP)
            ld de, scr_buf
            ld bc, 2
            ld a, MTEXT
            call far_copy
            ld a, [scr_buf]
            ld l, a
            ld a, [scr_buf + 1]
            ld h, a
            ld de, mtxt
            ld bc, 80
            ld a, MTEXT
            jp far_copy

; the shopkeeper says text A
sh_say:     push af
            ld bc, $0000
            ld de, $1406
            call scr_win
            pop af
            call sh_text
            ld bc, $0101
            call pen_at
            call scr_upd
            ld hl, mtxt
            jp pen_type
; the price question: the price (sh_price) and text 14 (its first line empty)
sh_ask:     ld bc, $0000
            ld de, $1406
            call scr_win
            ld a, SH_PRICE
            call sh_text
            ld bc, $0102
            call pen_at
            ld hl, sh_price
            call nf_w
            call pen_numl
            ld a, $20
            call pen_ch
            ld hl, mtxt + 1                 ; (after the empty first line)
            call pen_str
            call scr_upd
            ld hl, str_yesno
            ld b, 2
            call sh_menu
            ret c
            and a
            ret z
            scf
            ret

; commands HL (B lines) in (10,6,10,6): A = the choice, C set on B
sh_menu:    ld a, b
            ld [sh_n], a
            push hl
            ld bc, $0A06
            ld de, $0A06
            call scr_win
            ld bc, $0C07
            call pen_at
            pop hl
            call pen_str
            call scr_upd
            xor a
            ld [sh_cur], a
.l:         ld a, [sh_cur]                  ; the hand at the choice (column 12, row 7 + n)
            add a, 7
            ld c, a
            ld b, 12
            call cur_txt
            call scr_frame
            ldh a, [pad_new]
            bit 1, a
            jr nz, .b
            bit 0, a
            jr nz, .a
            ld hl, sh_cur
            bit 6, a
            jr nz, .up
            bit 7, a
            jr z, .l
            ld a, [sh_n]
            ld b, a
            ld a, [hl]
            inc a
            cp b
            jr c, .s
            xor a
.s:         ld [hl], a
            jr .l
.up:        ld a, [hl]
            dec a
            cp $FF
            jr nz, .s
            ld a, [sh_n]
            dec a
            jr .s
.a:         call .clr
            ld a, [sh_cur]
            and a
            ret
.b:         call .clr
            scf
            ret
.clr:       ld bc, $0A06                    ; the window gone again (blank, black)
            call cell_addr
            ld c, 6
.cr:        push hl
            ld b, 10
.cc:        ld [hl], $20
            ld a, h                         ; (its colour: + $300)
            add a, 3
            ld h, a
            ld [hl], BLK_ATTR
            sub 3
            ld h, a
            inc hl
            dec b
            jr nz, .cc
            pop hl
            ld de, 32
            add hl, de
            dec c
            jr nz, .cr
            jp oam_clr

; price of item A -> sh_price (FF1 LoadPrice)
sh_getprice:
            ld l, a
            ld h, 0
            add hl, hl
            ld de, N_PRICE
            add hl, de
            ld de, sh_price
            ld bc, 2
            ld a, NAMES
            jp far_copy

; Gil >= sh_price (FF1 Shop_CanAfford): C clear if so
sh_afford:  ld a, [GOLD + 2]
            and a
            ret nz
            ld a, [sh_price]
            ld b, a
            ld a, [GOLD]
            sub b
            ld a, [sh_price + 1]
            ld b, a
            ld a, [GOLD + 1]
            sbc a, b
            ret
; Gil -= sh_price (FF1 ShopPayPrice)
sh_pay:     ld hl, GOLD
            ld a, [sh_price]
            ld b, a
            ld a, [hl]
            sub b
            ld [hl+], a
            ld a, [sh_price + 1]
            ld b, a
            ld a, [hl]
            sbc a, b
            ld [hl+], a
            ld a, [hl]
            sbc a, 0
            ld [hl], a
            call sh_gold
            jp scr_upd

; ---- weapon / armour shops (FF1 EnterShop_Equip; owner, 2026-11-22: as the new menus).
; Buy: the list, the price, then the party window with each member's Attack / Defense now and
; with it (Can't use / Full); then Equip it now? Sell: one list of every unequipped item of
; the kind in the party's packs.
sh_equip:   ld a, SH_WELCOME
            call sh_say
.l:         ld hl, str_buysell
            ld b, 3
            call sh_menu
            ret c
            and a
            jr z, .buy
            dec a
            ret nz
            call sh_sellall                 ; sell
            jr nc, .hs
            ld a, SH_NOSELL
            call sh_say
            jr .l
.hs:        ld hl, str_shwhich
            call sh_says
            ld a, 1
            ld [sh_sell], a
            call sh_pick
            push af
            xor a
            ld [sh_sell], a
            pop af
            jr c, .l
            ld e, a
            ld d, 0
            ld hl, sh_ref
            add hl, de
            ld a, [hl]
            ld [sh_slot], a
            call sh_ask
            jr c, .cancel
            ld a, [sh_slot]                 ; (unequipped: no stats change)
            ld b, a
            srl a
            srl a
            push bc
            call sh_slots
            pop bc
            ld a, b
            and 3
            add a, l
            ld l, a
            ld [hl], 0
            ld a, [sh_type]
            call eq_setkind
            call eq_sort
            ld hl, sh_price
            ld a, [hl+]
            ld c, a
            ld b, [hl]
            call add_gold
            call sh_gold
            call scr_upd
            jr .l
.cancel:    ld a, SH_TOOBAD
            call sh_say
            jr .l
.buy:       call sh_invlist
            ld a, SH_WHAT
            call sh_say
            call sh_pick
            jr c, .l
            call sh_ask
            jr c, .cancel
            call sh_afford
            jr nc, .af
            ld a, SH_NOMONEY
            call sh_say
            jr .l
.af:        ld hl, str_shwho
            call sh_says
            call sh_epv
            call sh_wpick
            push af
            call sh_base
            pop af
            jp c, .l
            ld [sh_k], a
            ld e, a
            ld d, 0
            ld hl, sh_pv
            add hl, de
            ld a, [hl]
            cp 2
            jr nz, .ok
            ld a, SH_FULL
            call sh_say
            jp .l
.ok:        push af
            call sh_free                    ; the item into the first empty slot
            ld a, l
            ld [sh_slot], a
            call sh_idx
            ld [hl], a
            call sh_pay
            pop af
            and a
            jr nz, .th                      ; (can't use it: no question)
            ld hl, str_sheq
            call sh_says
            ld hl, str_yesno
            ld b, 2
            call sh_menu
            jr c, .th
            and a
            jr nz, .th
            call eqm_unadj                  ; worn: FF1's stats with it
            ld a, [sh_slot]
            ld l, a
            ld h, high(ch_stats)
            call sh_wear
            call sh_readj
.th:        ld a, SH_THANKS
            call sh_say
            jp .l

; eq_kind / eq_off for shop type A (0 weapons, 1 armour)
eq_setkind: ld [eq_kind], a
            and a
            ld a, $18
            jr z, .s
            ld a, $1C
.s:         ld [eq_off], a
            ret
; the shop's items -> sh_list
sh_invlist: ld hl, sh_inv
            ld de, sh_list
            ld b, 6
.c:         ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .c
            ret

; ---- item shops and the caravan (FF1 EnterShop_Item)
sh_item:    ld a, SH_WELCOME
            call sh_say
.l:         ld hl, str_buyleave
            ld b, 2
            call sh_menu
            ret c
            and a
            ret nz
            call sh_invlist
            ld a, SH_WHAT
            call sh_say
            call sh_pick
            jr c, .l
            call sh_qty                     ; how many (owner, 2026-11-22)
            jr c, .l
            ld a, [sh_it]
            add a, low(ITEMS)
            ld l, a
            ld h, high(ITEMS)
            ld a, [sh_q]
            add a, [hl]
            ld [hl], a
            call sh_pay3
            ld a, SH_THANKS
            call sh_say
            jr .l
.cancel:    ld a, SH_TOOBAD
            call sh_say
            jr .l

; ---- magic shops (FF1 EnterShop_Magic, MagicShop_AssertLearn; owner, 2026-11-22: the
; spell first, then the party window with each member's OK / Known / Can't learn / Full)
sh_magic:   ld a, SH_WELCOME                ; (FF1: Buy / Leave, again after every answer)
            call sh_say
.l:         ld hl, str_buyleave
            ld b, 2
            call sh_menu
            ret c
            and a
            ret nz
.pk:        call sh_invlist
            ld a, $18                       ; which magic
            call sh_say
            call sh_pick
            jr c, .l
            ld a, [sh_it]
            sub $B0
            ld [sh_sp], a
.w:         ld a, $17                       ; who will learn
            call sh_say
            call sh_mpv
            call sh_wpick
            push af
            call sh_base
            pop af
            jr c, .pk
            ld [sh_k], a
            call sh_mstat
            and a
            jr z, .ok
            ld b, $19                       ; can't learn
            dec a
            jr z, .say
            ld b, $1A                       ; already known
            dec a
            jr z, .say
            ld b, $22                       ; the level is full
.say:       ld a, b
            call sh_say
            call wait_ab
            jr .w
.ok:        call sh_ask
            jr c, .cancel
            call sh_afford
            jr nc, .buy
            ld a, SH_NOMONEY
            call sh_say
            call wait_ab
            jr .pk
.buy:       ld a, [sh_k]
            call sh_mstat                   ; (HL = the free slot, C = the spell)
            ld [hl], c
            call sh_pay
            ld a, SH_THANKS                 ; (Anything else I can do for ya?)
            call sh_say
            jr .l
.cancel:    ld a, SH_TOOBAD
            call sh_say
            jr .l

; member sh_k and spell sh_sp: A = 0 may learn (HL = the level's free slot, C = the spell
; in its level, 1-8), 1 the job can't, 2 known, 3 the level full
sh_mstat:   ld a, [sh_k]                    ; the job's permission bit set: no
            call ch_rec
            ld a, [hl]
            add a, a
            add a, a
            add a, a
            ld b, a
            ld a, [sh_sp]
            rrca
            rrca
            rrca
            and 7
            add a, b
            ld l, a
            ld h, 0
            ld de, N_MPERM
            add hl, de
            ld a, NAMES
            ld [fc_bank], a
            call far_byte
            ld c, a
            ld a, [sh_sp]                   ; bit $80 >> (spell & 7)
            and 7
            inc a
            ld b, a
            ld a, $01
.bt:        rrca
            dec b
            jr nz, .bt
            and c
            ld a, 1
            ret nz
            ld a, [sh_k]                    ; the level's three slots: known / free
            rrca
            rrca
            ld b, a
            ld a, [sh_sp]
            rrca
            and $1C
            add a, b
            ld l, a
            ld h, high(ch_magic)
            ld a, [sh_sp]
            and 7
            inc a
            ld c, a
            ld b, 3
            push hl
.kn:        ld a, [hl+]
            cp c
            jr z, .know
            dec b
            jr nz, .kn
            pop hl
            ld b, 3
.fr:        ld a, [hl]
            and a
            ret z                           ; (A = 0)
            inc hl
            dec b
            jr nz, .fr
            ld a, 3
            ret
.know:      pop hl
            ld a, 2
            ret

; ---- inn (FF1 EnterShop_Inn): stay, the price, HP / MP full, saved
sh_inn:     ld a, $1B
            call sh_say
            ld hl, str_yesno
            ld b, 2
            call sh_menu
            jr c, .x
            and a
            jr nz, .x
            call sh_ipr
            call sh_ask
            jr c, .x
            call sh_afford
            jr c, sh_poor
            call sh_pay
            xor a
.hp:        push af                         ; FF1 MenuFillPartyHP: everyone not dead / stone
            call ch_rec
            inc hl
            ld a, [hl-]
            cp 1
            jr z, .nh
            cp 2
            jr z, .nh
            call hp_full
.nh:        pop af
            inc a
            cp 4
            jr c, .hp
            call party_mp
            call sh_fsave                   ; (which file: loc.s)
            ld a, $1C
            call sh_say
            call wait_ab
.x:         ld a, $1D
            call sh_say
            jp wait_ab
sh_poor:    ld a, SH_NOMONEY                ; FF1: can't afford -> out of the shop
            call sh_say
            jp wait_ab
; the inn / clinic price: the shop data's first two bytes
sh_ipr:     ld a, [sh_inv]
            ld [sh_price], a
            ld a, [sh_inv + 1]
            ld [sh_price + 1], a
            ret

; ---- clinic (FF1 EnterShop_Clinic): revive a dead member with 1 HP
sh_clinic:  ld hl, sh_nbuf                  ; the dead, as a list of names
            ld de, sh_dead
            xor a
            ld [sh_n], a
            ld c, 0
.d:         ld a, c
            call ch_rec
            inc hl
            ld a, [hl]
            cp 1
            jr nz, .nd
            ld a, c
            ld [de], a
            inc de
            ld hl, sh_n
            inc [hl]
.nd:        inc c
            ld a, c
            cp 4
            jr c, .d
            ld a, [sh_n]
            and a
            jr nz, .some
            ld a, $23                       ; nobody needs it
            call sh_say
            jp wait_ab
.some:      ld a, $20
            call sh_say
            ld hl, sh_nbuf                  ; names of the dead
            ld de, sh_dead
            ld a, [sh_n]
            ld b, a
.nm:        push bc
            ld a, [de]
            inc de
            push de
            push hl
            call ch_rec
            inc hl
            inc hl
            ld d, h
            ld e, l
            pop hl
            ld b, 4
.c:         ld a, [de]
            inc de
            ld [hl+], a
            dec b
            jr nz, .c
            ld a, e
            add a, CH_NAME2 - 6
            ld e, a
            ld a, [de]
            inc de
            ld [hl+], a
            ld a, [de]
            ld [hl+], a
            ld [hl], $0A
            inc hl
            pop de
            pop bc
            dec b
            jr nz, .nm
            dec hl
            ld [hl], 0
            ld a, [sh_n]
            ld b, a
            ld hl, sh_nbuf
            call sh_menu
            ret c
            ld e, a
            ld d, 0
            ld hl, sh_dead
            add hl, de
            ld a, [hl]
            ld [sh_ch], a
            call sh_ipr
            call sh_ask
            jr c, sh_clinic
            call sh_afford
            jr c, sh_poor
            call sh_pay
            ld a, [sh_ch]
            call ch_rec
            inc hl
            ld [hl], 0
            ld a, l
            add a, CH_HP - 1
            ld l, a
            ld [hl], 1
            ld a, $21
            call sh_say
            call wait_ab
            jp sh_clinic

zz_end_5980:

section bank 2, $66C0                       ; (the shops as the new menus, owner 2026-11-22)

; the shopkeeper says string HL
sh_says:    push hl
            ld bc, $0000
            ld de, $1406
            call scr_win
            ld bc, $0101
            call pen_at
            call scr_upd
            pop hl
            jp pen_type

; the party window over the list (0,5,20,7): a header row (6), the members (7-10), the
; name at column 2; the shop's words at column 8
sh_wwin:    ld bc, $0005
            ld de, $1407
            call scr_win
            xor a
.n:         ld [sh_k], a
            add a, 7
            ld c, a
            ld b, 2
            call pen_at
            ld a, [sh_k]
            call pen_name
            ld a, [sh_k]
            inc a
            cp 4
            jr c, .n
            ret
; the hand on a member there: A = member, C set on B
sh_wpick:   call scr_upd
            xor a
            ld [sh_cur], a
.l:         ld a, [sh_cur]
            add a, 7
            ld c, a
            ld b, 2
            call cur_txt
            call scr_frame
            ldh a, [pad_new]
            bit 1, a
            jr nz, .b
            bit 0, a
            jr nz, .a
            ld hl, sh_cur
            bit 6, a
            jr nz, .up
            bit 7, a
            jr z, .l
            ld a, [hl]
            inc a
            jr .s
.up:        ld a, [hl]
            dec a
.s:         and 3
            ld [hl], a
            jr .l
.a:         call oam_clr
            ld a, [sh_cur]
            and a
            ret
.b:         call oam_clr
            scf
            ret

; sh_it's number in its kind (FF1's slot byte, 1-based)
sh_idx:     ld a, [sh_type]
            and a
            ld a, [sh_it]
            jr nz, .ar
            sub $1B
            ret
.ar:        sub $43
            ret
; member A's four slots of the shop's kind -> HL
sh_slots:   call ch_rec
            ld a, [sh_type]
            and a
            ld a, $18
            jr z, .w
            ld a, $1C
.w:         add a, l
            ld l, a
            ret
; member sh_k's first empty slot of the kind -> HL; C set if none
sh_free:    ld a, [sh_k]
            call sh_slots
            ld b, 4
.l:         ld a, [hl]
            and a
            ret z
            inc hl
            dec b
            jr nz, .l
            scf
            ret
; member sh_k wears slot HL: what it replaces taken off first (FF1: one weapon; one armour
; of each type)
sh_wear:    push hl
            ld a, [hl]
            and $7F
            ld [sh_wi], a
            ld a, [sh_k]
            call sh_slots
            ld b, 4
.u:         bit 7, [hl]
            jr z, .n
            ld a, [sh_type]
            and a
            jr z, .off                      ; (weapons: the one worn)
            push hl
            push bc
            ld a, [hl]
            and $7F
            dec a
            call eq_atype
            push af
            ld a, [sh_wi]
            dec a
            call eq_atype
            pop bc
            cp b
            pop bc
            pop hl
            jr nz, .n
.off:       res 7, [hl]
.n:         inc hl
            dec b
            jr nz, .u
            pop hl
            set 7, [hl]
            ret
; the stats with the equipment again (both kinds)
sh_readj:   xor a
            ld [eq_kind], a
            ld a, $18
            ld [eq_off], a
            call eq_readj
            ld a, 1
            ld [eq_kind], a
            ld a, $1C
            ld [eq_off], a
            jp eq_readj

; the party window for equipment: each member's Attack (weapons) / Defense (armour) now and
; with sh_it worn (Color: green better, red worse), or Can't use / Full; sh_pv[m]: 0 may
; wear it, 1 can't, 2 no empty slot
sh_epv:     call sh_wwin
            ld bc, $0B06                    ; (the heading over the values, columns 10-18)
            ld hl, str_satk
            ld a, [sh_type]
            and a
            jr z, .h
            ld hl, str_sdef
.h:         ld e, 7
            call gold_str
            call eqm_unadj
            xor a
.m:         ld [sh_k], a
            call ch_rec
            ld a, [hl]
            ld [eqm_cls], a
            ld a, [sh_type]
            ld [eqm_ft], a
            ld a, 1
            ld [sh_wi], a
            call sh_idx
            call eqm_legal
            jr c, .wr
            call sh_free
            ld a, 2
            ld [sh_wi], a
            jr c, .wr
            push hl
            ld a, [sh_k]                    ; the slots kept
            call sh_slots
            ld de, eqm_bk
            ld b, 4
.sv:        ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .sv
            ld a, [sh_k]
            call eqm_calc
            call .val
            ld [eqm_w], a
            pop hl
            call sh_idx
            ld [hl], a
            call sh_wear
            ld a, [sh_k]
            call eqm_calc
            call .val
            ld [eqm_w + 1], a
            ld a, [sh_k]                    ; the slots back
            call sh_slots
            ld de, eqm_bk
            ld b, 4
.rs:        ld a, [de]
            ld [hl+], a
            inc de
            dec b
            jr nz, .rs
            ld a, [sh_k]                    ; now > with it (ending at column 18: clear of
            add a, 7                        ;   a six-letter name; owner 2026-11-24 polish)
            ld c, a
            ld b, 10
            call pen_at
            ld a, [eqm_w]
            call nf_a
            ld b, 3
            call pen_num
            ld a, $20
            call pen_ch
            call sh_arrow                   ; ('>', or the arrow up / down)
            ld a, $20
            call pen_ch
            ld a, [eqm_w + 1]
            call nf_a
            ld b, 3
            call pen_num
            ld a, [eqm_w + 1]               ; the colour of the new value (cells 14-16)
            ld hl, eqm_w
            cp [hl]
            ld e, WIN_ATTR
            jr z, .co
            ld e, $09
            jr nc, .co
            ld e, $0A
.co:        ld a, [sh_k]
            add a, 7
            ld c, a
            ld b, 16
            call cell_addr
            ld a, h
            add a, 3
            ld h, a
            ld a, e
            ld [hl+], a
            ld [hl+], a
            ld [hl], a
            xor a
            ld [sh_wi], a
            jr .nx
.wr:        ld a, [sh_k]                    ; Can't use / Full (ending at column 18)
            add a, 7
            ld c, a
            ld a, [sh_wi]
            dec a
            ld b, 10
            ld hl, str_scant
            jr z, .ws
            ld b, 15
            ld hl, str_sfull
.ws:        push hl
            call pen_at
            pop hl
            call pen_str
.nx:        ld a, [sh_k]
            ld e, a
            ld d, 0
            ld hl, sh_pv
            add hl, de
            ld a, [sh_wi]
            ld [hl], a
            ld a, [sh_k]
            inc a
            cp 4
            jp c, .m
            call sh_readj
            ld a, [sh_type]
            jp eq_setkind
.val:       ld a, [sh_type]                 ; Attack (eqm_v + 0) or Defense (+ 2)
            and a
            ld a, [eqm_v]
            ret z
            ld a, [eqm_v + 2]
            ret

; the party window for a spell: each member's OK / Can't learn / Known / Full
sh_mpv:     call sh_wwin
            xor a
.m:         ld [sh_k], a
            call sh_mstat
            push af
            ld a, [sh_k]
            add a, 7
            ld c, a
            ld b, 9                         ; (a space after a six-letter name)
            call pen_at
            pop af
            ld hl, str_sok
            and a
            jr z, .p
            ld hl, str_scant                ; (the equipment shops' wording: the longer
                                            ;   one left no room after a six-letter name)
            dec a
            jr z, .p
            ld hl, str_sknown
            dec a
            jr z, .p
            ld hl, str_sfull
.p:         call sh_pstr                    ; (and the level's slots: loc.s)
            ld a, [sh_k]
            inc a
            cp 4
            jr c, .m
            ret

; every unequipped item of the shop's kind in the party's packs -> sh_list (ids, 0-ended),
; sh_ref (member x 4 + slot); C set if none
sh_sellall: xor a
            ld [sh_n], a
.l:         ld [sh_k], a
            srl a
            srl a
            call sh_slots
            ld a, [sh_k]
            and 3
            add a, l
            ld l, a
            ld a, [hl]
            and a
            jr z, .n
            bit 7, a
            jr nz, .n
            ld b, a
            ld a, [sh_type]
            and a
            ld a, $1B                       ; weapon n -> item $1B + n, armour $43 + n
            jr z, .w
            ld a, $43
.w:         add a, b
            ld b, a
            ld a, [sh_n]
            ld e, a
            ld d, 0
            ld hl, sh_list
            add hl, de
            ld [hl], b
            ld hl, sh_ref
            add hl, de
            ld a, [sh_k]
            ld [hl], a
            ld hl, sh_n
            inc [hl]
.n:         ld a, [sh_k]
            inc a
            cp 16
            jr c, .l
            ld a, [sh_n]
            ld e, a
            ld d, 0
            ld hl, sh_list
            add hl, de
            ld [hl], 0
            cp 1
            ret

; the list sh_list (ids, 0-ended, up to 16; five show, scrolled): A = the index chosen (the
; item in sh_it, its price in sh_price, halved when selling), C set on B
sh_pick:    xor a
            ld [sh_top], a
            ld [sh_cur], a
            dec a                           ; (the owned / worn line: loc.s)
            ld [sh_ocur], a
.rd:        ld bc, $0005                    ; (one line an entry, six shown: owner's audit,
            ld de, $1408                    ;   2026-11-25; the info window below: sh_info)
            call scr_win
            xor a
.it:        ld [sh_k], a
            ld hl, sh_top
            add a, [hl]
            ld e, a
            ld d, 0
            ld hl, sh_list
            add hl, de
            ld a, [hl]
            and a
            jr z, .dn
            ld [sh_it], a
            ld a, [sh_k]                    ; name at row 6 + i, column 1 (17 letters fit)
            add a, 6
            ld c, a
            ld b, 1
            push bc
            call pen_at
            ld a, [sh_it]
            call pen_iname
            pop bc
            ld a, [sh_it]                   ; spells: their level at the right
            cp $B0
            jr c, .np
            cp $F0
            jr nc, .np
            ld b, 17
            push bc
            call pen_at
            ld a, $4C
            call pen_ch
            ld a, [sh_it]
            sub $B0
            rrca
            rrca
            rrca
            and 7
            add a, $31
            call pen_ch
            pop bc
.np:        ld a, [sh_k]
            inc a
            cp 6
            jr c, .it
.dn:        call scr_upd
.l:         call sh_info                    ; (price, owned / worn, Gil)
            ld a, [sh_cur]                  ; the hand at the entry (row 6 + n; over the icon,
            ld hl, sh_top                   ;   as the Equip list)
            sub [hl]
            add a, 6
            ld c, a
            ld b, 2
            call cur_txt
            call scr_frame
            ldh a, [pad_new]
            bit 1, a
            jr nz, .b
            bit 0, a
            jr nz, .a
            ld hl, sh_cur
            bit 6, a
            jr nz, .up
            bit 7, a
            jr z, .l
            ld a, [hl]                      ; down: while there is a next one
            inc a
            ld e, a
            ld d, 0
            push hl
            ld hl, sh_list
            add hl, de
            ld a, [hl]
            pop hl
            and a
            jr z, .l
            ld [hl], e
            ld a, [sh_top]
            add a, 5
            cp e
            jr nc, .l
            ld hl, sh_top
            inc [hl]
            jp .rd
.up:        ld a, [hl]
            and a
            jr z, .l
            dec a
            ld [hl], a
            ld hl, sh_top
            cp [hl]
            jr nc, .l
            ld [hl], a
            jp .rd
.a:         ld a, [sh_cur]                  ; the item and its price
            ld e, a
            ld d, 0
            ld hl, sh_list
            add hl, de
            ld a, [hl]
            ld [sh_it], a
            call .price
            call .gone
            ld a, [sh_cur]
            and a
            ret
.b:         call .gone
            scf
            ret
.gone:      call sh_base                    ; the list gone: the base screen again
            jp oam_clr
.price:     ld a, [sh_it]
            call sh_getprice
            ld a, [sh_sell]
            and a
            ret z
            ld hl, sh_price + 1             ; selling: half (FF1)
            srl [hl]
            dec hl
            rr [hl]
            ret

; how many of sh_it (owner, 2026-11-22): up / down one, right / left ten, at most what the
; Gil buys and 99 in all; the total below; A buys (C clear, sh_q, sh_tot), B cancels
sh_qty:     ld a, [sh_it]
            add a, low(ITEMS)
            ld l, a
            ld h, high(ITEMS)
            ld a, 99
            sub [hl]
            ld b, a                         ; room
            jr nz, .rm
            ld a, SH_FULL
            call sh_say
            scf
            ret
.rm:        xor a                           ; the most the Gil buys
            ld [sh_q], a
            call .t0
.mx:        ld a, [sh_q]
            cp b
            jr z, .mo
            call .add
            ld hl, GOLD + 2                 ; total > Gil: one fewer
            ld a, [sh_tot + 2]
            cp [hl]
            jr c, .fit
            jr nz, .mo
            dec hl
            ld a, [sh_tot + 1]
            cp [hl]
            jr c, .fit
            jr nz, .mo
            dec hl
            ld a, [sh_tot]
            cp [hl]
            jr z, .fit
            jr nc, .mo
.fit:       ld hl, sh_q
            inc [hl]
            jr .mx
.mo:        ld a, [sh_q]
            ld [sh_qmax], a
            and a
            jr nz, .some
            ld a, SH_NOMONEY
            call sh_say
            scf
            ret
.some:      ld hl, str_howmany              ; (the shopkeeper asks)
            call sh_says
            ld a, 1
            ld [sh_q], a
            ld bc, $0005                    ; the window: the item, x count, total Gil
            ld de, $1406
            call scr_win
            ld bc, $0206
            call pen_at
            ld a, [sh_it]
            call pen_iname
.dr:        call .tot
            ld bc, $0208
            call pen_at
            ld a, 'x'
            call pen_ch
            ld a, [sh_q]
            call nf_a
            ld b, 2
            call pen_num
            ld bc, $0808
            call pen_at
            ld hl, sh_tot
            ld a, [hl+]
            ld [nf_val], a
            ld a, [hl+]
            ld [nf_val + 1], a
            ld a, [hl]
            ld [nf_val + 2], a
            ld b, 6
            call pen_num
            ld a, $20
            call pen_ch
            ld hl, str_gil
            call pen_str
            call scr_upd
.l:         ld bc, $0208                    ; (the hand at the count)
            call cur_txt
            call scr_frame
            ldh a, [pad_new]
            bit 1, a
            jr nz, .b
            bit 0, a
            jr nz, .a
            ld b, 1
            bit 6, a
            jr nz, .pl
            bit 4, a
            ld b, 10
            jr nz, .pl
            ld b, 1
            bit 7, a
            jr nz, .mi
            bit 5, a
            jr z, .l
            ld b, 10
.mi:        ld a, [sh_q]
            sub b
            jr z, .m1
            jr nc, .st
.m1:        ld a, 1
            jr .st
.pl:        ld a, [sh_qmax]
            ld c, a
            ld a, [sh_q]
            add a, b
            cp c
            jr c, .st
            ld a, c
.st:        ld [sh_q], a
            jr .dr
.a:         call .tot
            call oam_clr
            call sh_base
            and a
            ret
.b:         call oam_clr
            call sh_base
            scf
            ret
.tot:       call .t0                        ; sh_tot = sh_q x the price
            ld a, [sh_q]
            ld b, a
.tl:        call .add
            dec b
            jr nz, .tl
            ret
.t0:        xor a
            ld [sh_tot], a
            ld [sh_tot + 1], a
            ld [sh_tot + 2], a
            ret
.add:       ld hl, sh_tot
            ld a, [sh_price]
            add a, [hl]
            ld [hl+], a
            ld a, [sh_price + 1]
            adc a, [hl]
            ld [hl+], a
            ld a, 0
            adc a, [hl]
            ld [hl], a
            ret
; Gil -= sh_tot
sh_pay3:    ld hl, GOLD
            ld a, [sh_tot]
            ld b, a
            ld a, [hl]
            sub b
            ld [hl+], a
            ld a, [sh_tot + 1]
            ld b, a
            ld a, [hl]
            sbc a, b
            ld [hl+], a
            ld a, [sh_tot + 2]
            ld b, a
            ld a, [hl]
            sbc a, b
            ld [hl], a
            call sh_gold
            jp scr_upd
zz_end_6690:

section bank 2, $73A1                       ; (free space)
; ---- the list's info window (owner's audit, 2026-11-25; was the speech window's last row, on
; its border): the item under the hand's price, how many the party owns (weapons / armour: and
; wears; WonderSwan Color remake, owner 2026-11-22), the Gil; drawn when the hand moves
sh_info:    ld a, [sh_cur]
            ld hl, sh_ocur
            cp [hl]
            ret z
            ld [hl], a
            ld bc, $000D
            ld de, $1405
            call scr_win
            ld a, [sh_cur]                  ; the price (selling: half)
            ld e, a
            ld d, 0
            ld hl, sh_list
            add hl, de
            ld a, [hl]
            ld [sh_it], a
            call sh_pick.price
            ld bc, $010E
            call pen_at
            ld hl, so_price
            call pen_str
            ld bc, $0D0E
            call pen_at
            ld hl, sh_price
            call nf_w
            ld b, 6
            call pen_num
            ld bc, $0110                    ; the Gil
            call pen_at
            ld hl, so_gil
            call pen_str
            ld bc, $0D10
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
            call scr_upd
            jp sh_own                       ; (owned / worn: buying equipment or items)

section bank 2, $58BB                       ; (free space)
sh_own:     ld a, [sh_sell]
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
            ld bc, $010F
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

section bank 2, $477E                       ; (free space)
so_price:   db "Price", 0
so_gil:     db "Gil", 0
; the target screen again after a use (menu.s)
tgt_redraw: ld c, 1                         ; (the inside only: the frame's bottom row is the
.r:         push bc                         ;   text window's top, which stays: owner's audit,
            ld b, 1                         ;   2026-11-25)
            call cell_addr
            ld a, $20
            ld b, 18
.f:         ld [hl+], a
            dec b
            jr nz, .f
            pop bc
            inc c
            ld a, c
            cp 9
            jr c, .r
            xor a
.m:         push af
            call mm_member
            pop af
            inc a
            cp 4
            jr c, .m
            jp scr_upd


section wram, $CF40
sh_id:      ds 1
sh_type:    ds 1
sh_inv:     ds 6
sh_n:       ds 1
sh_cur:     ds 1
sh_it:      ds 1
sh_ch:      ds 1
sh_slot:    ds 1
sh_sell:    ds 1
sh_sp:      ds 1
sh_price:   ds 2
sh_dead:    ds 4
sh_nbuf:    ds 32
section wram, $C800                         ; (the map's queue: free while a shop shows)
sh_list:    ds 17
sh_ref:     ds 16
sh_pv:      ds 4
sh_k:       ds 1
sh_top:     ds 1
sh_wi:      ds 1
sh_q:       ds 1
sh_qmax:    ds 1
sh_tot:     ds 3
sh_ocur:    ds 1

section bank 2, $7F94                       ; (free space)
; the shops' preview: '>' between the values, the arrow up / down when the new one is better /
; worse (owner's audit, 2026-11-25: every system; the Color also colours the value)
sh_arrow:   ld a, [eqm_w + 1]
            ld hl, eqm_w
            cp [hl]
            ld a, '>'
            jr z, .p
            ld a, $0C
            jr nc, .p
            inc a
.p:         jp pen_ch
; Formation: while the second member is picked, a still hand at the first (OAM 28-31; owner's
; audit, 2026-11-25)
lu_hand2:   ld a, [lu_mode]
            cp 2
            jr nz, .h
            ld a, [lu_cur2]
            call lu_slotp
            inc hl
            inc hl
            inc hl
            ld a, [hl]
            add a, 8
            ld c, a
            ld b, 32
            ld de, oam_buf + 112
            jp scr_cur_de
.h:         xor a
            ld [oam_buf + 112], a
            ld [oam_buf + 116], a
            ld [oam_buf + 120], a
            ld [oam_buf + 124], a
            ret
; the Status screen: a member with no MP at any level gets "-", not sixteen 0/0s (owner's audit,
; 2026-11-25); Z then
st_nomp:    ld a, [mm_t]
            rrca
            rrca
            add a, $28
            ld l, a
            ld h, high(ch_magic)
            ld b, 8
            xor a
.z:         or [hl]
            inc l
            dec b
            jr nz, .z
            and a
            ret nz
            ld a, $2D
            call pen_ch
            xor a
            ret
