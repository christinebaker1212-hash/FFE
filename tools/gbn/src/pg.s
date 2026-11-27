; The post-game: Dawn of Souls' Soul of Chaos dungeons (docs/ff1-postgame-design.md). Our own code.
; The floors are standard maps PGM_MAP0 and up (tools/gbn/postgame.py: map m in ROM bank m + 64,
; $5061 / $5062 the arrival x / y). A run: the entrance floor's stairs start it; each stairs down
; takes the party to the run's next floor (B1-B4 drawn at random from the dungeon's four, then the
; boss floor); the chests of each floor hold that depth's treasure, shuffled per run.
PGM_BANK   = 116
PG_DEPTH   = unsram + $A0   ; the run (kept in the save; FF1 leaves $60A0-$60EF unused, $6040-$609F
PG_ORDER   = unsram + $A1   ;   hold its new game's class stats): the depth (0 the entrance floor), the
PG_CHEST   = unsram + $A5   ;   floors B1-B4 (map ids), this floor's chests opened (bits 0-3), the
PG_FIXED   = unsram + $A6   ;   fixed chests opened (persistent), the bosses beaten (persistent, a bit
PG_BOSS    = unsram + $A7   ;   each), the boss beaten this run, the run's chest shuffle
PG_RUNB    = unsram + $A8
PG_SEED    = unsram + $A9
ST_TILE    = $70            ; (the statue's sprite tiles: postgame.statue)
PG_TC      = 0              ; (FF1's flag of a chest number no map uses: the post-game's chests)
PG_FLOORS  = 4              ; Earthgift: B1-B4 from its four floors (maps PGM_MAP0 + 1-4), B5
PG_BOSSMAP = PGM_MAP0 + 5
PG_ENT     = $1E            ; Earthgift's overworld entrance number (postgame.py: a cave mouth metatile)
PG_OWX     = 132            ; ... at (132, 141): the way back out
PG_OWY     = 141
ORB_EARTH  = ORBS + 3       ; (lit once Lich is beaten: the shrine opens)
PG_OBJ0    = $F0            ; the boss floor's orbs: object ids $F0-$F3 (shown while game flag bit 0)
PG_BFORM0  = 7              ; the bosses' formations in the dungeon's battle set (pgbattle.py)
PGT_BANK   = 125            ; the post-game's text (postgame.py pg_text)

; ---- bank 0: the hooks (load_map's bank, do_tele, open_chest)
section bank 0, $3A68                       ; (free space)                       ; (free space)
; A = map B's ROM bank: FF1's maps from MAP_BANK0, the post-game's at map + 64
pg_mbank:   ld a, b
            cp PGM_MAP0
            jr c, .f
            add a, 64 - MAP_BANK0
.f:         add a, MAP_BANK0
            ret

; do_tele: a post-game floor's stairs go down the run (A = fdepth for FF1's floors)
pg_tchk:    ld a, [cur_map]
            cp PGM_MAP0
            ld a, [fdepth]
            ret c
            pop hl
            ld a, PGM_BANK
            call sbank
            jp pg_down

; open_chest: a post-game chest holds the run's treasure
pg_cchk:    ld [tc_id], a
            ld a, [cur_map]
            cp PGM_MAP0
            ld a, [tc_id]
            ret c
            pop hl
            ld a, PGM_BANK
            call sbank
            jp pg_chest

; back from pg_chest: A = 0 opened already, 1 given (a Dawn of Souls consumable), 2 armour B, else
; FF1's item / weapon / armour code: FF1's chest code gives it
pg_give:    and a
            jr nz, .g
            ld a, DLG_EMPTY
            ret
.g:         push af
            ld a, PG_TC
            ld [tc_id], a
            pop af
            cp 3
            jr nc, .ff
            dec a
            jr nz, .ar
            ld a, 2
            ld [dlgsfx], a
            ld a, DLG_TCGET
            ret
.ar:        ld hl, C_WPNSLOT + 16
            jp tc_give.find
.ff:        push af
            ld a, NAMES
            call sbank
            pop af
            jp tc_give

; load_map (every map): the battle banks of the map's dungeon (pgbattle.py), FF1's elsewhere
pg_lcd:     ld a, $23                       ; (the fiend picture's first cell: FF1's)
            ldh [hbt_fy], a
            ld a, [cur_map]
            cp PGM_MAP0
            jr c, .ff1
            inc a                           ; (MAP_OW: FF1's)
            jr z, .ff1
            ld a, PG_OWX                    ; (the way back out: the shrine's door)
            ld [ow_x], a
            ld a, PG_OWY
            ld [ow_y], a
            ld a, PGB_DATA
            ldh [hbt_db], a
            ldh [hbt_dom], a
            ld a, PGB_CHR
            ldh [hbt_cb], a
            ld a, PGB_SIL
            ldh [hbt_sb], a
            ld a, PGB_SGB
            ldh [hbt_sgb], a
            jp lcd_off
.ff1:       ld a, BTL_DATA
            ldh [hbt_db], a
            ld a, BTL6_BANK
            ldh [hbt_dom], a
            ld a, ENEMY_CHR
            ldh [hbt_cb], a
            ld a, ESIL_BANK
            ldh [hbt_sb], a
            ld a, SGB_BANK
            ldh [hbt_sgb], a
            jp lcd_off

section bank 0, $3B5A                       ; (free space)
; arrived: an overworld entrance (A = [px] back for FF1's entrances): the shrine sealed until
; Lich is beaten (Dawn of Souls' words at its door)
pg_echk:    ld a, e
            and $3F
            cp PG_ENT
            ld a, [px]
            ret nz
            ld a, [ORB_EARTH]
            and a
            ld a, [px]
            ret nz
            pop hl
            ld hl, pg_t_sealed
            call pg_say
            and a
            ret
; a box of the post-game's text (HL in bank PGT_BANK), as dlg_open
pg_say:     ld a, PGT_BANK
            ld [dlg_bank], a
            ld a, l
            ld [dlg_ptr], a
            ld a, h
            ld [dlg_ptr + 1], a
            xor a
            ld [dlgsfx], a
            jp dlg_open2
section bank 0, $1DB4                       ; (free space)
; talk_obj: the boss floor's orbs (ids PG_OBJ0 and up)
pg_tkchk:   ld a, l
            ld [talk_slot], a
            ld a, [hl]
            cp PG_OBJ0
            ret c
            pop de
            pop de                          ; (main's .dlg: the box is opened here)
            ld [talk_id], a
            ld a, PGM_BANK
            call sbank
            jp pg_boss
; talk_after's battle: in the post-game, a boss beaten opens the way out
pg_dobtl:   call do_battle
            push af
            ld a, [cur_map]
            cp PGM_MAP0
            jr c, .x
            inc a                           ; (thrown out to the world map: pg_gover)
            jr z, .x
            pop af
            ld a, PGM_BANK
            call sbank
            jp pg_after
.x:         pop af
            ret
section bank 0, $3F12                       ; (free space)
; game_over: in the post-game, the party is thrown back to the world map instead (Dawn of Souls)
pg_gover:   ldh a, [hbt_db]
            cp BTL_DATA
            jr z, .go
            ld a, PGM_BANK
            call sbank
            call pg_revive                  ; (A = MAP_OW, D, E = the shrine's door)
            call load_map
            scf
            ret
.go:        di
            ld sp, $E000
            jp game_over + 4

section wram, $CC96
pg_rs:      ds 1
pg_bk:      ds 1

section hram, $FFF0
hbt_db:     ds 1                            ; the battle data bank (battle.py's layout)
hbt_cb:     ds 1                            ; the enemy graphics banks (2)
hbt_sb:     ds 1                            ; their silhouettes (2)
hbt_dom:    ds 1                            ; the encounter domains' bank
hbt_sgb:    ds 1                            ; the Super Game Boy's battle colours' bank (sgb.s)
hbt_fy:     ds 1                            ; the fiend picture's first cell (y x: $23, a hanging boss $03)

section bank PGM_BANK, $4000
; ---- the stairs down (E = FF1's teleport number, not used)
pg_down:    ld a, [cur_map]
            cp PGM_MAP0                     ; the entrance floor: a new run
            call z, pg_newrun
            ld hl, PG_DEPTH
            inc [hl]
            xor a
            ld [PG_CHEST], a
            ld a, [hl]
            cp PG_FLOORS + 1
            ld b, PG_BOSSMAP
            jr nc, .go
            ld e, a
            ld d, 0
            ld hl, PG_ORDER - 1
            add hl, de
            ld b, [hl]
.go:        ld a, b
            add a, 64
            ld [fc_bank], a
            ld hl, $5061
            call far_byte
            ld d, a
            inc hl
            call far_byte
            ld e, a
            ld a, b
            jp load_map_w

; a new run: depth 0, the floors in a random order, a new chest shuffle
pg_newrun:  xor a
            ld [PG_DEPTH], a
            ld [PG_RUNB], a
            ld a, [PG_BOSS]                 ; the orbs of the bosses not beaten: shown
            ld c, a
            ld hl, game_flags + PG_OBJ0
            ld b, 4
.o:         res 0, [hl]
            rr c
            jr c, .ob
            set 0, [hl]
.ob:        inc l
            dec b
            jr nz, .o
            call pg_rand
            ld [PG_SEED], a
            ld hl, PG_ORDER                 ; 1, 2, 3, 4, then Fisher-Yates
            ld b, PG_FLOORS
            ld a, PGM_MAP0 + 1
.f:         ld [hl+], a
            inc a
            dec b
            jr nz, .f
            ld c, PG_FLOORS - 1             ; i = 3 .. 1: swap [i] with [rand % (i + 1)]
.s:         call pg_rand
            ld b, c
            inc b
.m:         cp b
            jr c, .md
            sub b
            jr .m
.md:        ld e, a
            ld d, 0
            ld hl, PG_ORDER
            add hl, de
            push hl
            ld e, c
            ld hl, PG_ORDER
            add hl, de
            pop de
            ld a, [de]
            ld b, [hl]
            ld [hl], a
            ld a, b
            ld [de], a
            dec c
            jr nz, .s
            ret

; A = a random byte (the divider and a running state)
pg_rand:    push hl
            ld hl, pg_rs
            ldh a, [$FF04]
            add a, [hl]
            rlca
            xor $5B
            add a, 37
            ld [hl], a
            pop hl
            ret

; ---- a chest (tc_id = its number on the floor: 0-3 the run's, 4-7 the floor's own) -> A = the
; item code and dlg_item (0: opened already), back through pg_give
pg_chest:   ld a, [tc_id]
            cp 4
            jr nc, .fx
            ld b, a
            call pg_bit
            ld c, a
            ld hl, PG_CHEST
            and [hl]
            jr nz, .none
            ld a, [hl]
            or c
            ld [hl], a
            ld a, [PG_DEPTH]                ; the depth's list (B1-B4), slot (k + shuffle) & 3
            dec a
            and 3
            add a, a
            add a, a
            ld c, a
            ld a, [PG_SEED]
            add a, b
            and 3
            add a, c
            ld e, a
            ld d, 0
            ld hl, pg_treas
            add hl, de
            ld a, [hl]
            jr .got
.fx:        sub 4                           ; the floor's own chests: once ever
            ld b, a
            call pg_bit
            ld c, a
            ld hl, PG_FIXED
            and [hl]
            jr nz, .none
            ld a, [hl]
            or c
            ld [hl], a
            ld a, b
            ld e, a
            ld d, 0
            ld hl, pg_fixed
            add hl, de
            ld a, [hl]
.got:       ld [dlg_item], a
            ld b, a                         ; a Dawn of Souls consumable: one more (up to 99)
            ld hl, it_newc
.f:         ld a, [hl+]
            and a
            jr z, .na
            cp b
            jr nz, .f
            ld a, b
            call it_cnt
            ld a, [hl]
            cp 99
            jr nc, .g1
            inc [hl]
.g1:        ld a, 1
            jp pg_give
.na:        ld a, b                         ; Dawn of Souls' armour (name code $43 + id past $6B)
            cp $6C
            jr c, .ff
            cp $43 + N_ARMOUR + 1
            jr nc, .ff
            sub $43
            ld b, a
            ld a, 2
            jp pg_give
.ff:        ld a, b
            jp pg_give
.none:      xor a
            jp pg_give

; A = 1 << B (B kept)
pg_bit:     push bc
            ld a, 1
            inc b
.l:         dec b
            jr z, .x
            add a, a
            jr .l
.x:         pop bc
            ret

; ---- an orb on the boss floor (A = its id): FF1's Talk_fight (the orb gone, the battle when the box
; closes) with the boss's words (Dawn of Souls' lines)
pg_boss:    ld a, [talk_id]
            sub PG_OBJ0
            ld [pg_bk], a
            ld e, a                         ; (its picture's first cell: pg_fy)
            ld d, 0
            ld hl, pg_fy
            add hl, de
            ld a, [hl]
            ldh [hbt_fy], a
            ld a, [talk_id]
            call hide_this
            ld a, [pg_bk]
            add a, PG_BFORM0
            call talk_btl
            ld a, [pg_bk]
            add a, a
            ld e, a
            ld d, 0
            ld hl, pg_t_boss
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            jp pg_say

; ---- after a battle in the post-game (A = do_battle's result): a boss beaten: remembered, the way
; out (Dawn of Souls: one boss a run)
pg_after:   push af
            ld a, [pend_btl]
            sub PG_BFORM0
            jr c, .x
            cp 4
            jr nc, .x
            ld b, a
            call pg_bit
            ld hl, PG_BOSS
            or [hl]
            ld [hl], a
            ld a, 1
            ld [PG_RUNB], a
            pop af
            ld d, PG_OWX
            ld e, PG_OWY
            ld a, MAP_OW
            jp load_map                     ; (no wipe: the battle's own fade has run)
.x:         pop af
            ret

; ---- the party after a lost battle: alive, ailments gone, 1 HP at least
pg_revive:  xor a                           ; (no boss beaten: pg_after)
            ld [pend_btl], a
            ld hl, ch_stats
            ld b, 4
.l:         push hl
            inc l
            ld [hl], 0                      ; (+1: the ailment)
            ld a, l
            add a, CH_HP - CH_AIL
            ld l, a
            ld a, [hl+]
            or [hl]
            jr nz, .n
            dec l
            ld [hl], 1
.n:         pop hl
            ld a, l
            add a, $40
            ld l, a
            dec b
            jr nz, .l
            ld d, PG_OWX
            ld e, PG_OWY
            ld a, MAP_OW
            ret

; ==== Dawn of Souls' items (postgame.py NEW_ITEMS / NEW_ARMOUR): a consumable's id is its name code
; (an FF1 gold amount no chest gives); its count at NEWIT + its place in it_newc (FF1's items: ITEMS + id)
section bank 0, $3FA7                       ; (free space)
; A = an item -> HL = its count (A kept)
it_cnt:     cp $1C
            jr nc, .n
            add a, low(ITEMS)
            ld l, a
            sub low(ITEMS)
            ld h, high(ITEMS)
            ret
.n:         push bc
            ld b, a
            ld hl, it_newc
            ld c, low(NEWIT)
.f:         ld a, [hl+]                     ; (A is always one of them)
            cp b
            jr z, .g
            inc c
            jr .f
.g:         ld l, c
            ld h, high(NEWIT)
            ld a, b
            pop bc
            ret

section bank 0, $2F5E                       ; (free space)
; a bank-6 routine (c6_jp: jp nnnn) from bank 104, with its registers in and out
call6:      push af
            ldh a, [rombank]
            ld [c6_b], a
            ld a, 6
            call sbank
            pop af
            call c6_jp
            push af
            ld a, [c6_b]
            call sbank
            pop af
            ret

section wram, $DD20
c6_jp:      ds 3
c6_b:       ds 1
md_n:       ds 1
md_pg:      ds 1
md_sel:     ds 1
pg_mm:      ds 1
md_list:    ds 16

; ---- the Items screen (bank 2): the new consumables' uses
section bank 2, $7DB0
; it_use: FF1's items by its jump table, the new ones here
it_ux:      cp $1C
            jr nc, .n
            ld hl, it_jt
            ret
.n:         pop hl
            ld hl, it_newc                  ; (their use: it_utab by their place)
            ld e, 0
.f:         cp [hl]
            jr z, .g
            inc hl
            inc e
            jr .f
.g:         ld d, 0
            ld hl, it_utab
            add hl, de
            ld a, [hl]
            add a, a
            ld e, a
            ld hl, .t
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            jp hl
.t:         dw u_none, u_hp, u_rem, u_eth, u_mega, u_apple
u_none:     call sfx_err                    ; (a battle item: not here)
            jp item_menu.l
; Hi-Potion: FF1's Potion, 150 HP
u_hp:       ld a, IT_UseItem_Heal_0
            call tgt_open
            call tgt_pick
            jr .t
.l:         call tgt_pick2
.t:         jp c, item_menu.re
            call ch_rec
            inc hl
            ld a, [hl]
            cp 1
            jr z, .er
            cp 2
            jr z, .er
            dec hl
            call hp_atmax
            jr nz, .ok
            ld a, IT_UseItem_Heal_0
            call no_eff
            jr .l
.ok:        ld a, 150
            call hp_add
            call u_dec
            jr nz, .l
            jp item_menu.re
.er:        call sfx_err
            jr .l
; the item used: one fewer, the target screen again; NZ: some left
u_dec:      ld a, [it_id]
            call it_cnt
            dec [hl]
            ld a, [hl]
            push af
            call tgt_redraw
            pop af
            and a
            ret
; Remedy: outside battle, Poison (as FF1's Antidote)
u_rem:      ld a, [it_id]
            call it_cnt
            ld a, IT_UseItem_Pure_0
            ld b, IT_UseItem_Pure_1
            jp u_cure
; Ether: a member's MP (Classic: one charge of every level)
u_eth:      ld a, IT_UseItem_Heal_0
            call tgt_open
            call tgt_pick
            jr .t
.l:         call tgt_pick2
.t:         jp c, item_menu.re
            ld [pg_mm], a
            call ch_rec
            inc hl
            ld a, [hl]
            cp 1
            jr z, .er
            cp 2
            jr z, .er
            ld a, PGM_BANK
            ld hl, pg_ether
            call bank_call
            ld a, TR_HPUP
            call snd_track
            call u_dec
            jr nz, .l
            jp item_menu.re
.er:        call sfx_err
            jr .l
; Megalixir: everyone standing, all HP and MP
u_mega:     ld a, IT_UseItem_Heal_0
            call tgt_open
.l:         call tg_all
            jp c, item_menu.re
            ld b, 0
.m:         push bc
            ld a, b
            ld [pg_mm], a
            call ch_rec
            inc hl
            ld a, [hl]
            dec hl
            cp 1
            jr z, .n
            cp 2
            jr z, .n
            ld a, l
            add a, CH_HP + 2
            ld l, a
            ld a, [hl+]
            ld e, a
            ld d, [hl]
            dec l
            dec l
            ld [hl], d
            dec l
            ld [hl], e
            ld a, PGM_BANK
            ld hl, pg_mpfull
            call bank_call
.n:         pop bc
            inc b
            ld a, b
            cp 4
            jr c, .m
            ld a, TR_HPUP
            call snd_track
            call u_dec
            jr nz, .l
            jp item_menu.re
; Silver Apple: a member's maximum HP + 5 for good (and the HP)
u_apple:    ld a, IT_UseItem_Heal_0
            call tgt_open
            call tgt_pick
            jr .t
.l:         call tgt_pick2
.t:         jp c, item_menu.re
            call ch_rec
            inc hl
            ld a, [hl]
            dec hl
            cp 1
            jr z, .er
            cp 2
            jr z, .er
            push hl
            ld a, l
            add a, CH_HP + 2
            ld l, a
            ld a, [hl+]
            add a, 5
            ld e, a
            ld a, [hl]
            adc a, 0
            ld d, a
            cp high(999)
            jr c, .s
            jr nz, .cap
            ld a, e
            cp low(999) + 1
            jr c, .s
.cap:       ld de, 999
.s:         ld [hl], d
            dec l
            ld [hl], e
            pop hl
            ld a, 5
            call hp_add
            call u_dec
            jr nz, .l
            jp item_menu.re
.er:        call sfx_err
            jr .l

; ---- the MP (bank PGM_BANK; member [pg_mm]): Ether, a full refill
section bank PGM_BANK, $7000
pg_mrec:    ld a, [pg_mm]
            rrca
            rrca
            ld l, a
            ld h, high(ch_magic)
            ret
pg_ether:   call pg_mrec
            ld a, [opt_mmp]
            and a
            jr nz, .mp
            ld a, l                         ; Classic: each level one charge, up to its maximum
            add a, $20
            ld l, a
            ld b, 8
.c:         ld a, l
            add a, 8
            ld e, a
            ld d, h
            ld a, [de]
            cp [hl]
            jr z, .n
            jr c, .n
            inc [hl]
.n:         inc l
            dec b
            jr nz, .c
            ret
.mp:        ld a, l                         ; Modern MP: 50, up to the maximum
            add a, MM_CUR
            ld l, a
            ld a, [hl+]
            add a, 50
            ld e, a
            ld a, [hl+]
            adc a, 0
            ld d, a
            ld a, [hl+]
            ld c, a
            ld b, [hl]
            ld a, e
            sub c
            ld a, d
            sbc a, b
            jr c, .s
            ld d, b
            ld e, c
.s:         dec l
            dec l
            ld [hl], d
            dec l
            ld [hl], e
            ret
pg_mpfull:  call pg_mrec
            push hl
            ld a, l                         ; the charges (both modes keep them)
            add a, $20
            ld l, a
            ld d, h
            ld b, 8
.c:         ld a, l
            add a, 8
            ld e, a
            ld a, [de]
            ld [hl+], a
            dec b
            jr nz, .c
            pop hl
            ld a, l
            add a, MM_CUR
            ld l, a
            ld d, h
            ld e, l
            inc e
            inc e
            ld a, [de]
            ld [hl+], a
            inc e
            ld a, [de]
            ld [hl], a
            ret

; ---- the battle's Medicine (bank 104): Potion, Antidote, then the new items owned
section bank 104, $7000
; bank-6 routines (call6; the caller's HL on the stack)
c_hand:     push hl
            ld hl, bt_hand
            jr c6s
c_frame:    push hl
            ld hl, bt_frame
            jr c6s
c_msgwin:   push hl
            ld hl, bt_msg_win
            jr c6s
c_vclr:     push hl
            ld hl, vwf_clr
            jr c6s
c_mname:    push hl
            ld hl, bt_mname
            jr c6s
c_vstr:     push hl
            ld hl, vwf_str
            jr c6s
c_mrow:     push hl
            ld hl, bt_mrow
            jr c6s
c_hoff:     push hl
            ld hl, bt_hand_off
            jr c6s
c_mclose:   push hl
            ld hl, bt_msg_close
            jr c6s
c_names:    push hl
            ld hl, bt_names_win
            jr c6s
c_mload:    push hl
            ld hl, bt_mload
            jr c6s
c_tenemy:   push hl
            ld hl, bt_target_enemy
            jr c6s
c_theal:    push hl
            ld hl, bt_target_heal
            jr c6s
c_tmember:  push hl
            ld hl, bt_target_member
            jr c6s
c_slot:     push hl
            ld hl, bt_commands.slot
c6s:        push af
            ld a, $C3
            ld [c6_jp], a
            ld a, l
            ld [c6_jp + 1], a
            ld a, h
            ld [c6_jp + 2], a
            pop af
            pop hl
            jp call6

; B = an entry of md_tab -> A = how many are left to choose (less those chosen by the members
; before this one this round), E = its count's address (page $D0)
md_avail:   ld a, b
            add a, a
            add a, a
            ld e, a
            ld d, 0
            ld hl, md_tab
            add hl, de
            ld e, [hl]
            ld l, e
            ld h, high(unsram)
            ld d, [hl]
            ld a, [bt_cm]
            and a
            jr z, .x
            ld c, a
            ld hl, bt_cmd
.m:         ld a, [hl]
            cp $08
            jr nz, .n
            inc hl
            inc hl
            inc hl
            ld a, [hl-]
            dec hl
            dec hl
            cp e
            jr nz, .n
            dec d
.n:         inc hl
            inc hl
            inc hl
            inc hl
            dec c
            jr nz, .m
.x:         ld a, d
            ret
; HL = md_tab's entry B
md_ent:     ld a, b
            add a, a
            add a, a
            ld e, a
            ld d, 0
            ld hl, md_tab
            add hl, de
            ret

; FF1 BattleSubMenu_Drink with Dawn of Souls' items: 4 rows a page, left / right the pages; C on B
md_menu:    ld hl, md_list
            ld bc, 0
.bl:        ld a, b
            cp MD_N
            jr nc, .bd
            push hl
            push bc
            call md_avail
            pop bc
            pop hl
            and a
            jr nz, .add
            ld a, b
            cp 2                            ; (Potion, Antidote: always shown)
            jr nc, .nx
.add:       ld [hl], b
            inc hl
            inc c
.nx:        inc b
            jr .bl
.bd:        ld a, c
            ld [md_n], a
            xor a
            ld [md_pg], a
            ld [bt_mcur], a
.dr:        call md_draw
.l:         ld a, [bt_mcur]                 ; (the hand 17 px left of the text at x 16)
            add a, 13
            add a, a
            add a, a
            add a, a
            ld c, a
            ld b, 16 - 17
            call c_hand
            call c_frame
            ldh a, [pad_new]
            bit 1, a
            jp nz, .b
            bit 0, a
            jr nz, .a
            bit 4, a
            jr nz, .pg
            bit 5, a
            jr nz, .pg
            and $C0
            jr z, .l
            ld b, a
            call md_rows
            ld c, a
            ld a, [bt_mcur]
            bit 7, b
            jr z, .up
            inc a
            cp c
            jr c, .s
            xor a
            jr .s
.up:        and a
            jr nz, .u1
            ld a, c
.u1:        dec a
.s:         ld [bt_mcur], a
            jr .l
.pg:        ld a, [md_n]                    ; another page (when there are two or more)
            cp 5
            jr c, .l
            ld a, [md_pg]
            xor 1
            ld b, a
            add a, a
            add a, a
            ld c, a
            ld a, [md_n]
            cp c
            jr z, .l
            jr c, .l
            ld a, b
            ld [md_pg], a
            xor a
            ld [bt_mcur], a
            jr .dr
.a:         call md_cur                     ; B = the entry; none left: no
            ld a, b
            ld [md_sel], a
            call md_avail
            and a
            jr z, .l
            call c_hoff
            call c_mclose
            call c_names
            ld a, [md_sel]
            ld b, a
            call md_ent
            inc hl
            inc hl
            ld a, [hl]                      ; its magic -> its target, as the Magic command
            ld [bt_t + 7], a
            call c_mload
            ld a, [mg_d + 3]
            bit 1, a
            jr nz, .en
            bit 4, a
            jr nz, .me
            xor a
            jr .set
.en:        call c_tenemy
            ret c
            jr .set
.me:        ld a, [mg_d + 4]                ; (HP recovery: not on a member at full HP)
            and $FE
            cp 6
            jr nz, .mm
            call c_theal
            ret c
            jr .set
.mm:        call c_tmember
            ret c
.set:       ld b, a
            call c_slot
            ld [hl], $08
            inc hl
            ld a, [bt_t + 7]
            ld [hl+], a
            ld [hl], b
            inc hl
            push hl
            ld a, [md_sel]
            ld b, a
            call md_ent
            ld a, [hl]
            pop hl
            ld [hl], a                      ; (the count's address: bt_pl_drink)
            and a
            ret
.b:         call c_hoff
            call c_mclose
            scf
            ret
; A = the rows on this page
md_rows:    ld a, [md_pg]
            add a, a
            add a, a
            ld c, a
            ld a, [md_n]
            sub c
            cp 4
            ret c
            ld a, 4
            ret
; B = the entry under the hand
md_cur:     ld a, [md_pg]
            add a, a
            add a, a
            ld c, a
            ld a, [bt_mcur]
            add a, c
            ld e, a
            ld d, 0
            ld hl, md_list
            add hl, de
            ld b, [hl]
            ret
; the page: name and count a row
md_draw:    call c_msgwin
            xor a
            ld [bt_rows], a
            ld c, 0
.r:         push bc
            ld b, 18
            call c_vclr
            pop bc
            push bc
            ld a, [md_pg]
            add a, a
            add a, a
            add a, c
            ld c, a
            ld a, [md_n]
            dec a
            cp c
            jr c, .e
            ld e, c
            ld d, 0
            ld hl, md_list
            add hl, de
            ld b, [hl]
            push bc
            call md_ent
            inc hl
            ld a, [hl]
            call c_mname
            ld hl, bt_sbuf
            ld a, 8
            call c_vstr
            pop bc
            call md_avail
            call nf_a
            call num_fmt
            ld hl, nf_dig + 4
            ld de, bt_sbuf
            ld a, [hl+]
            ld [de], a
            inc de
            ld a, [hl]
            ld [de], a
            inc de
            xor a
            ld [de], a
            ld hl, bt_sbuf
            ld a, 80
            call c_vstr
.e:         call c_mrow
            pop bc
            inc c
            ld a, c
            cp 4
            jr c, .r
            ret
; bt_pl_drink (md_use): Ether / Megalixir: the MP of their target / of everyone standing
md_mp:      ld a, [mg_id]
            cp $5E
            jr z, .eth
            cp $5F
            ret nz
            ld b, 0
.m:         push bc
            ld a, b
            ld [pg_mm], a
            call ch_rec
            inc hl
            ld a, [hl]
            cp 1
            jr z, .n
            cp 2
            jr z, .n
            ld a, PGM_BANK
            ld hl, pg_mpfull
            call bank_call
.n:         pop bc
            inc b
            ld a, b
            cp 4
            jr c, .m
            ret
.eth:       ld a, [bt_tgt]
            and 3
            ld [pg_mm], a
            ld a, PGM_BANK
            ld hl, pg_ether
            jp bank_call

section bank 0, $13F5                       ; (free space)
; veh_oam: the bridge and the canal (ow_bc), then the shrine's statue
pg_owst:    call ow_bc
            ld a, PGM_BANK
            ld hl, pg_statue
            jp bank_call

section bank PGM_BANK, $7200
; the statue before Earthgift's sealed door (until Lich is beaten): FF1's Lich in stone, 4 x 4 sprites
; (OAM 24-39, tiles $70-$7F) centred on the door, standing on its tile
pg_statue:  ld a, PG_ON                     ; (built without the Dawn of Souls ROM: no shrine)
            and a
            ret z
            ld hl, oam_buf + 96             ; (hidden first)
            ld b, 16
            xor a
.z:         ld [hl+], a
            inc l
            inc l
            inc l
            dec b
            jr nz, .z
            ld a, [ORB_EARTH]
            and a
            ret nz
            ld a, PG_OWX
            ld hl, px
            call ob_pos
            ret c
            sub 8
            ld b, a
            ld a, PG_OWY
            ld hl, py
            call ob_pos
            ret c
            ld c, a
            call ob_step
            ld a, c
            add a, 3 - 16
            ld c, a
            ld de, oam_buf + 96
            ld h, ST_TILE
            ld l, 4
.r:         push bc
            ld a, b
            ld b, 4
.c:         push af
            ld a, c
            ld [de], a
            inc de
            pop af
            ld [de], a
            inc de
            push af
            ld a, h
            ld [de], a
            inc de
            inc h
            ld a, PG_STPAL
            ld [de], a
            inc de
            pop af
            add a, 8
            dec b
            jr nz, .c
            pop bc
            ld a, c
            add a, 8
            ld c, a
            dec l
            jr nz, .r
            ret

section bank PGM_BANK, $7300
; load_map (the Color, LCD off): the reflection's OBJ palettes 4-7, then on the world map (no
; reflections there) palette 7 the statue's stone: light grey, dark grey, black (NES $10, $00, $0F)
pg_rpal:    ld a, F3_BANK
            ld hl, refl_pal
            call bank_call
            ldh a, [maptype]
            and a
            ret z
            ld a, $80 | $38
            call ocps_w
            ld hl, .g
            ld b, 8
.l:         ld a, [hl+]
            call ocpd_w
            dec b
            jr nz, .l
            ret
.g:         dw $0000, $5294, $2108, $0000
