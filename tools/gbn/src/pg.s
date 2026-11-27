; The post-game: Dawn of Souls' Soul of Chaos dungeons (docs/ff1-postgame-design.md). Our own code.
; The floors are standard maps PGM_MAP0 and up (tools/gbn/postgame.py: map m in ROM bank m + 64,
; $5061 / $5062 the arrival x / y). A run: the entrance floor's stairs start it; each stairs down
; takes the party to the run's next floor (B1-B4 drawn at random from the dungeon's four, then the
; boss floor); the chests of each floor hold that depth's treasure, shuffled per run.
PGM_BANK   = 116
PG_DEPTH   = unsram + $40   ; the run (kept in the save; FF1 leaves $6040-$60EF unused): the depth
PG_ORDER   = unsram + $41   ;   (0 the entrance floor), the floors B1-B4 (map ids), this floor's
PG_CHEST   = unsram + $45   ;   chests opened (bits 0-3), the fixed chests opened (persistent),
PG_FIXED   = unsram + $46   ;   the bosses beaten (persistent, a bit each), the boss beaten this
PG_BOSS    = unsram + $47   ;   run, the run's chest shuffle
PG_RUNB    = unsram + $48
PG_SEED    = unsram + $49
PG_TC      = 0              ; (FF1's flag of a chest number no map uses: the post-game's chests)
PG_FLOORS  = 4              ; Earthgift: B1-B4 from its four floors (maps PGM_MAP0 + 1-4), B5
PG_BOSSMAP = PGM_MAP0 + 5

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

; back from pg_chest: A = the item (0: the chest was opened) -> FF1's chest code gives it
pg_give:    and a
            ld a, DLG_EMPTY
            ret z
            ld a, NAMES
            call sbank
            ld a, PG_TC
            ld [tc_id], a
            ld a, [dlg_item]
            jp tc_give

; load_map (every map): the battle banks of the map's dungeon (pgbattle.py), FF1's elsewhere
pg_lcd:     ld a, [cur_map]
            cp PGM_MAP0
            jr c, .ff1
            inc a                           ; (MAP_OW: FF1's)
            jr z, .ff1
            ld a, PGB_DATA
            ldh [hbt_db], a
            ldh [hbt_dom], a
            ld a, PGB_CHR
            ldh [hbt_cb], a
            ld a, PGB_SIL
            ldh [hbt_sb], a
            jp lcd_off
.ff1:       ld a, BTL_DATA
            ldh [hbt_db], a
            ld a, BTL6_BANK
            ldh [hbt_dom], a
            ld a, ENEMY_CHR
            ldh [hbt_cb], a
            ld a, ESIL_BANK
            ldh [hbt_sb], a
            jp lcd_off

section wram, $CC96
pg_rs:      ds 1

section hram, $FFF0
hbt_db:     ds 1                            ; the battle data bank (battle.py's layout)
hbt_cb:     ds 1                            ; the enemy graphics banks (2)
hbt_sb:     ds 1                            ; their silhouettes (2)
hbt_dom:    ds 1                            ; the encounter domains' bank

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
            jp pg_give
.none:      xor a
            jp pg_give

; A = 1 << B
pg_bit:     ld a, 1
            inc b
.l:         dec b
            ret z
            add a, a
            jr .l
