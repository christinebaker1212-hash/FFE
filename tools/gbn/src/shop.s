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
            ld hl, mtxt
            call pen_str
            jp scr_upd
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
.l:         ld a, [sh_cur]
            add a, 7
            add a, a
            add a, a
            add a, a
            sub 4
            ld c, a
            ld b, 80
            call scr_cursor
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
.clr:       ld bc, $0A06                    ; the window gone again (blank)
            call cell_addr
            ld c, 6
.cr:        push hl
            ld b, 10
.cc:        ld [hl], $20
            inc hl
            dec b
            jr nz, .cc
            pop hl
            ld de, 32
            add hl, de
            dec c
            jr nz, .cr
            jp oam_clr

; a member (the names in the command window): A = member, C set on B
sh_names:   ld hl, sh_nbuf
            xor a
.n:         push af
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
            pop af
            inc a
            cp 4
            jr c, .n
            dec hl
            ld [hl], 0
            ld hl, sh_nbuf
            ld b, 4
            jp sh_menu

; the list of sh_list (ids, 0-terminated, up to 5): A = the index chosen, C set on B
sh_pick:    ld bc, $0005
            ld de, $140C
            call scr_win
            xor a
            ld [sh_n], a
.it:        ld a, [sh_n]
            ld e, a
            ld d, 0
            ld hl, sh_list
            add hl, de
            ld a, [hl]
            and a
            jr z, .dn
            ld [sh_it], a
            ld a, [sh_n]                    ; name at row 6 + 2 i, column 2
            add a, a
            add a, 6
            ld c, a
            ld b, 2
            push bc
            call pen_at
            ld a, [sh_it]
            call pen_iname
            pop bc
            inc c
            ld a, [sh_it]                   ; spells: their level first
            cp $B0
            jr c, .np
            cp $F0
            jr nc, .np
            ld b, 3
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
.np:        push bc
            ld a, [sh_it]                   ; the price, ending at column 18
            call sh_getprice
            pop bc
            ld a, [sh_sell]
            and a
            jr z, .full
            ld hl, sh_price + 1             ; selling: half (FF1)
            srl [hl]
            dec hl
            rr [hl]
.full:      ld b, 13
            call pen_at
            ld hl, sh_price
            call nf_w
            ld b, 6
            call pen_num
            ld hl, sh_n
            inc [hl]
            ld a, [hl]
            cp 5
            jr c, .it
.dn:        call sh_gold
            call scr_upd
            xor a
            ld [sh_cur], a
.l:         ld a, [sh_cur]
            add a, a
            add a, 6
            add a, a
            add a, a
            add a, a
            sub 4
            ld c, a
            ld b, 0
            call scr_cursor
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
.a:         ld a, [sh_cur]                  ; the item and its price
            ld e, a
            ld d, 0
            ld hl, sh_list
            add hl, de
            ld a, [hl]
            ld [sh_it], a
            call sh_getprice
            ld a, [sh_sell]
            and a
            jr z, .ap
            ld hl, sh_price + 1
            srl [hl]
            dec hl
            rr [hl]
.ap:        call .gone
            ld a, [sh_cur]
            and a
            ret
.b:         call .gone
            scf
            ret
.gone:      call sh_base                    ; the list gone: the base screen again
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

; ---- weapon / armour shops (FF1 EnterShop_Equip)
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
            ; sell: whose, which
            ld a, SH_SELLWHO
            call sh_say
            call sh_names
            jr c, .l
            ld [sh_ch], a
            call sh_sellbox
            jr nc, .hs
            ld a, SH_NOSELL
            call sh_say
            jr .l
.hs:        ld a, 1
            ld [sh_sell], a
            call sh_pick
            push af
            xor a
            ld [sh_sell], a
            pop af
            jr c, .l
            ld [sh_slot], a
            call sh_ask
            jr c, .cancel
            ld a, [sh_type]                 ; out of the record, stats readjusted (FF1)
            call eq_setkind
            call eq_unadj
            ld a, [sh_ch]
            rrca
            rrca
            ld b, a
            ld a, [eq_off]
            add a, b
            ld b, a
            ld a, [sh_slot]
            add a, b
            ld l, a
            ld h, high(ch_stats)
            ld [hl], 0
            call eq_sort
            call eq_readj
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
.af:        ld a, SH_WHO
            call sh_say
            call sh_names
            jp c, .l
            ld [sh_ch], a
            call sh_give                    ; a free slot (FF1 EquipShop_GiveItemToChar)
            jr nc, .ok
            ld a, SH_FULL
            call sh_say
            jp .l
.ok:        call sh_pay
            ld a, SH_THANKS
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
; the member's equipment as item ids -> sh_list (FF1 EquipMenu_BuildSellBox); C set if none
sh_sellbox: ld a, [sh_type]
            call eq_setkind
            ld a, [sh_ch]
            rrca
            rrca
            ld b, a
            ld a, [eq_off]
            add a, b
            ld l, a
            ld h, high(ch_stats)
            ld de, sh_list
            ld b, 0
.l:         ld a, [hl+]
            and a
            jr z, .x
            and $7F
            ld c, a
            ld a, [eq_kind]
            and a
            ld a, $1B                       ; weapon n -> item $1B + n, armour $43 + n
            jr z, .w
            ld a, $43
.w:         add a, c
            ld [de], a
            inc de
            inc b
            ld a, b
            cp 4
            jr c, .l
.x:         xor a
            ld [de], a
            ld a, b
            cp 1
            ret
; give sh_it to sh_ch: the first empty slot; C set if none
sh_give:    ld a, [sh_type]
            call eq_setkind
            ld a, [sh_ch]
            rrca
            rrca
            ld b, a
            ld a, [eq_off]
            add a, b
            ld l, a
            ld h, high(ch_stats)
            ld b, 4
.l:         ld a, [hl]
            and a
            jr z, .f
            inc hl
            dec b
            jr nz, .l
            scf
            ret
.f:         ld a, [eq_kind]
            and a
            ld a, [sh_it]
            jr nz, .ar
            sub $1B
            jr .st
.ar:        sub $43
.st:        ld [hl], a
            and a
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
            call sh_ask
            jr c, .cancel
            call sh_afford
            jr nc, .af
            ld a, SH_NOMONEY
            call sh_say
            jr .l
.af:        ld a, [sh_it]                   ; 99 at most
            add a, low(ITEMS)
            ld l, a
            ld h, high(ITEMS)
            ld a, [hl]
            cp 99
            jr c, .ok
            ld a, SH_FULL
            call sh_say
            jr .l
.ok:        inc [hl]
            call sh_pay
            ld a, SH_THANKS
            call sh_say
            jr .l
.cancel:    ld a, SH_TOOBAD
            call sh_say
            jr .l

; ---- magic shops (FF1 EnterShop_Magic, MagicShop_AssertLearn)
sh_magic:   ld a, $17                       ; who will learn
            call sh_say
.l:         call sh_names
            ret c
            ld [sh_ch], a
            call sh_invlist
            ld a, $18
            call sh_say
            call sh_pick
            jr c, sh_magic
            ld a, [sh_ch]                   ; may the class learn it (permission bit set: no)
            call ch_rec
            ld a, [hl]
            add a, a
            add a, a
            add a, a
            ld b, a
            ld a, [sh_it]
            sub $B0
            ld [sh_sp], a
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
            jr z, .may
            ld a, $19                       ; can't learn
            call sh_say
            jr .l
.may:       ld a, [sh_ch]                   ; the level's three slots: known / free
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
            jr z, .free
            inc hl
            dec b
            jr nz, .fr
            ld a, $22                       ; the level is full
            call sh_say
            jp .l
.know:      pop hl
            ld a, $1A                       ; already known
            call sh_say
            jp .l
.free:      push hl
            push bc
            call sh_ask
            pop bc
            pop hl
            jr c, .cancel
            push hl
            push bc
            call sh_afford
            pop bc
            pop hl
            jr nc, .buy
            ld a, SH_NOMONEY
            call sh_say
            jp .l
.buy:       ld [hl], c
            call sh_pay
            jp sh_magic
.cancel:    ld a, SH_TOOBAD
            call sh_say
            jp .l

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
            call save_game
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
section wram, $CF40
sh_id:      ds 1
sh_type:    ds 1
sh_inv:     ds 6
sh_list:    ds 6
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
