; The post-game: Dawn of Souls' Soul of Chaos dungeons (docs/ff1-postgame-design.md). Our own code.
; Four shrines (tools/gbn/shrines.py); their floors are standard maps PGM_MAP0 and up (postgame.py: map m in
; ROM bank m + 64, with M_PG* bytes about it). A run: the entrance floor's stairs start it; each stairs
; down takes the party one depth on: a boss depth to its boss floor, any other to the next floor of the
; shrine's pool in this run's order (a shuffle of the pool by the run's seed). A boss floor holds its
; bosses' orbs; its stairs (on and out) open once one of them is beaten this run. The chests of a floor
; hold that depth's treasure, shuffled per run.
PGM_BANK   = 116
PG_DEPTH   = unsram + $A0   ; the run (kept in the save; FF1 leaves $60A0-$60EF unused, $6040-$609F
PG_DUN     = unsram + $A1   ;   hold its new game's class stats): the depth (0 the entrance floor), the
PG_SEED    = unsram + $A2   ;   shrine, the run's seed, this floor's chests opened (16 bits), the boss
PG_CHEST   = unsram + $A3   ;   floors passed this run (a bit each), the bosses beaten (persistent: a
PG_RUNB    = unsram + $A5   ;   byte a shrine, a bit a boss), the fixed chests opened (persistent)
PG_BOSS    = unsram + $A6
PG_FIXED   = unsram + $AA
ST_TILE    = $70            ; (the statue's sprite tiles: postgame.statue)
STATUE_BANK = 127
PG_TC      = 0              ; (FF1's flag of a chest number no map uses: the post-game's chests)
PG_ENT     = $1E            ; the shrines' overworld entrance number (postgame.py: their doors)
PG_OBJ0    = $F0            ; a boss floor's orbs: object ids $F0-$F3 (the shrine's bosses 0-3), and
PG_EXIT    = $F4            ;   the light that takes the party out once one of them is beaten
PGT_BANK   = 125            ; the post-game's text (postgame.py text_source)
PG_NPC0    = $D0            ; a floor's people: object ids $D0 + n (pgevents.py; FF1's ids end at $CF)
PG_PF      = unsram + $AB   ; this floor's flags (16 bits: cleared on arrival; the people's scripts)
M_PGA      = $5063          ; a post-game map's bytes (build.py): its encounter area, shrine, role (0 floor,
M_PGS      = $5064          ;   1 entrance, 2 boss floor), boss floor number, the shrine's door (x, y),
M_PGR      = $5065          ;   the battle banks of its two sets (data, graphics, silhouettes, Super Game
M_PGB      = $5066          ;   Boy), the first band of set 1, the depths a band; its chests: count, then
M_PGD      = $5067          ;   x, y, kind (0 / 1 the depth's lists, 2 + n fixed chest n)
M_PGBK     = $5069
M_PGBS     = $5071
M_PGBL     = $5072
M_PGNC     = $5080

; ---- bank 0: the hooks (load_map's bank, do_tele, open_chest)
section bank 0, $3A68                       ; (free space)
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
.ar:        jp tc_give.find                 ; (B = the id, HL = the slots: pg_gift)
.ff:        push af
            ld a, NAMES
            call sbank
            pop af
            jp tc_give

; load_map (every map; its bank mapped): the battle banks of the map's shrine (pgbattle.py), FF1's elsewhere;
; a post-game floor's facts (pg_shr, pg_role, pg_bfi, the encounter domain pg_dom by its area and depth band)
pg_lcd:     ld a, $23                       ; (the fiend picture's first cell: FF1's)
            ldh [hbt_fy], a
            ld a, [cur_map]
            cp PGM_MAP0
            jr c, .ff1
            inc a                           ; (MAP_OW: FF1's)
            jr z, .ff1
            ld hl, M_PGA                    ; (its bytes, then pg_lcd2 in the post-game's bank)
            ld de, pg_mb
            ld bc, 16
            call memcpy
            ld a, PGM_BANK
            ld hl, pg_lcd2
            call bank_call
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
; arrived: an overworld entrance (A = [px] back for FF1's entrances): a shrine's door (pg_enter)
pg_echk:    ld a, e
            and $3F
            cp PG_ENT
            ld a, [px]
            ret nz
            pop hl
            ld a, PGM_BANK
            ld hl, pg_enter
            jp bank_call
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
section bank 0, $3B80                       ; (free space)
; the encounter domain of the map (FF1's: map + 64; the post-game's: pg_dom)
pg_domi:    ld a, [cur_map]
            cp PGM_MAP0
            jr c, .f
            ld a, [pg_dom]
            ret
.f:         add a, 64
            ret
; load_map_w for the post-game's bank: back here (bank 0), C set
pg_lmw:     call load_map_w
            scf
            ret

section bank 0, $1DB4                       ; (free space)
; talk_obj: the boss floor's orbs (ids PG_OBJ0 and up)
pg_tkchk:   ld a, l
            ld [talk_slot], a
            ld a, [hl]
            cp PG_NPC0
            ret c
            pop de
            pop de                          ; (main's .dlg: the box is opened here)
            ld [talk_id], a
            ld a, PGM_BANK
            call sbank
            jp pg_boss
; talk_after's battle: in the post-game, a boss beaten opens the way on
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
pg_gover:   ld a, [cur_map]                 ; (a post-game floor, FF1's formations too: pg_ffight)
            cp PGM_MAP0
            jr c, .go
            inc a
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

section wram, $DDE6                         ; (free: rammap.py)
pg_mb:      ds 16                           ; (the map's M_PG* bytes, $5063 on)
pg_shr:     ds 1                            ; the floor's shrine, role, boss floor number, encounter domain
pg_role:    ds 1
pg_bfi:     ds 1
pg_dom:     ds 1
pg_t0:      ds 1                            ; (scratch)
pg_t1:      ds 1
dlg_nhi:    ds 1                            ; (the chest message's name index: text.s)
pg_stl:     ds 1                            ; (the statue loaded: its shrine)
pg_ffb:     ds 1                            ; a person's battle with FF1's formation pending (pg_ffight)
pg_sfx:     ds 1                            ; (the next box's fanfare)
pg_sb:      ds 2                            ; (the script running: its start)

section hram, $FFF0
hbt_db:     ds 1                            ; the battle data bank (battle.py's layout)
hbt_cb:     ds 1                            ; the enemy graphics banks (2)
hbt_sb:     ds 1                            ; their silhouettes (2)
hbt_dom:    ds 1                            ; the encounter domains' bank
hbt_sgb:    ds 1                            ; the Super Game Boy's battle colours' bank (sgb.s)
hbt_fy:     ds 1                            ; the fiend picture's first cell (y x: $23, a hanging boss $03)

section bank PGM_BANK, $4000
; load_map of a post-game floor (pg_mb = its M_PG* bytes): pg_shr, pg_role, pg_bfi, the door (the way back
; out), the encounter domain pg_dom (its area and the depth's band), the battle banks of the band's set
PB_A       = pg_mb
PB_S       = pg_mb + 1
PB_D       = pg_mb + 4
PB_BK      = pg_mb + 6
PB_BS      = pg_mb + 14
PB_BL      = pg_mb + 15
pg_lcd2:    ld hl, PB_S
            ld a, [hl+]
            ld [pg_shr], a
            ld a, [hl+]
            ld [pg_role], a
            ld a, [hl+]
            ld [pg_bfi], a
            ld a, [hl+]
            ld [ow_x], a
            ld a, [hl]
            ld [ow_y], a
            ld a, [PG_DEPTH]                ; the band: (depth - 1) / PB_BL, 0-3
            and a
            jr z, .b1
            dec a
            ld b, 0
            ld hl, PB_BL
.bd:        cp [hl]
            jr c, .bx
            sub [hl]
            inc b
            jr .bd
.bx:        ld a, b
            cp 4
            jr c, .b1
            ld a, 3
.b1:        ld c, a
            ld a, [PB_A]                    ; the domain: $80 + 4 area + band
            add a, a
            add a, a
            add a, c
            or $80
            ld [pg_dom], a
            ld a, [PB_BS]                   ; the battle set: 1 from band PB_BS on
            ld b, a
            ld a, c
            cp b
            ld hl, PB_BK
            jr c, .s0
            ld hl, PB_BK + 4
.s0:        ld a, [hl+]
            ldh [hbt_db], a
            ldh [hbt_dom], a
            ld a, [hl+]
            ldh [hbt_cb], a
            ld a, [hl+]
            ldh [hbt_sb], a
            ld a, [hl]
            ldh [hbt_sgb], a
            ret

; HL = table HL + A (A kept in E)
pg_ix:      ld e, a
            ld d, 0
            add hl, de
            ret
; A = [HL + 4 shrine + A]: a shrine's byte of four
pg_s4:      push af
            ld a, [pg_shr]
            add a, a
            add a, a
            ld e, a
            pop af
            add a, e
            jp pg_ixr
; A = [HL + A]
pg_ixr:     ld e, a
            ld d, 0
            add hl, de
            ld a, [hl]
            ret
; HL = the word at [HL + 2 shrine]
pg_sw:      ld a, [pg_shr]
            add a, a
            ld e, a
            ld d, 0
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ret

; ---- a shrine's door (overworld entrance PG_ENT): the shrine at the party's place; sealed until its Fiend
; is beaten (Dawn of Souls' words at its door), else its entrance floor
pg_enter:   ld c, 0
            ld hl, pg_door
.f:         ld a, [px]
            cp [hl]
            inc hl
            jr nz, .n
            ld a, [py]
            cp [hl]
            jr z, .g
.n:         inc hl
            inc c
            ld a, c
            cp 4
            jr c, .f
            and a                           ; (no shrine there: nothing)
            ret
.g:         ld a, c
            ld [pg_shr], a
            ld hl, pg_orb
            call pg_ixr
            ld l, a
            ld h, high(ORBS)
            ld a, [hl]
            and a
            jr nz, .op
            ld hl, pg_t_sealed
            call pg_sw
            jp pg_esay
.op:        ld a, [pg_shr]
            ld hl, pg_ent
            call pg_ixr
            ld b, a
            add a, 64
            ld [fc_bank], a
            ld hl, $5061
            call far_byte
            ld d, a
            inc hl
            call far_byte
            ld e, a
            xor a
            ld [fdepth], a
            ld a, b
            jp pg_lmw

; ---- a boss floor's way on / out before its boss is beaten this run: "held back" (C clear)
pg_held:    call pg_evrec                   ; (a floor of people: its own words)
            jr z, .d
            inc hl
            inc hl
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            or h
            jr nz, .s
.d:         ld hl, pg_t_held
.s:         jp pg_esay
; NZ: this floor's way is open (not a boss floor, or one of its bosses beaten this run; a floor of people:
; its gate's flags all set)
pg_open:    ld a, [pg_role]
            cp 2
            jr nz, .y
.bf:        ld a, [pg_bfi]
            ld b, a
            call pg_bit
            ld hl, PG_RUNB
            and [hl]
            ret
.y:         call pg_evrec
            jr z, .op
            ld a, [hl+]                     ; (the gate)
            ld e, a
            ld d, [hl]
            ld a, [PG_PF]
            and e
            cp e
            jr nz, .cl
            ld a, [PG_PF + 1]
            and d
            cp d
            jr nz, .cl
.op:        or 1
            ret
.cl:        xor a
            ret
; HL = this floor's people record (pgevents.py: gate, held text, count, scripts); Z: none
pg_evrec:   ld a, [cur_map]
            sub PGM_MAP0
            add a, a
            ld hl, pg_evt
            call pg_ix
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            or h
            ret

; ---- the stairs down (E = FF1's teleport number, not used)
pg_down:    ld a, [pg_role]
            cp 1                            ; the entrance floor: a new run
            call z, pg_newrun
            call pg_open
            jr nz, .on
            pop hl                          ; (do_tele's caller: the box)
            jr pg_held
.on:        ld hl, PG_DEPTH
            inc [hl]
            xor a
            ld [PG_CHEST], a
            ld [PG_CHEST + 1], a
            ld [PG_PF], a                   ; (a new floor: its flags clear, its people shown)
            ld [PG_PF + 1], a
            ld hl, game_flags + PG_NPC0
            ld b, 15
.vis:       set 0, [hl]
            inc l
            dec b
            jr nz, .vis
            ld hl, PG_DEPTH
            ld a, [hl]
            ld c, a                         ; C = the depth
            ld b, 0                         ; a boss depth: its floor; B = boss depths passed
            ld hl, pg_bdep
            ld a, [pg_shr]
            add a, a
            add a, a
            ld e, a
            ld d, 0
            add hl, de
            push hl
.bl:        ld a, [hl+]
            and a
            jr z, .nb
            cp c
            jr z, .bm
            jr nc, .nb
            inc b
            ld a, b
            cp 4
            jr c, .bl
            jr .nb
.bm:        pop hl                          ; the boss floor: pg_bdmap at the same place
            ld de, pg_bdmap - pg_bdep
            add hl, de
            ld a, b
            call pg_ixr
            jr .go
.nb:        pop hl
            ld a, c                         ; the k-th pool floor, k = depth - 1 - boss depths passed
            sub b
            dec a
            push af
            call pg_perm
            pop af
            ld hl, bt_sbuf
            call pg_ixr                     ; the pool entry: map, alternatives
            add a, a
            ld c, a
            ld hl, pg_pool
            call pg_sw
            ld b, 0
            add hl, bc
            ld a, [hl+]
            ld b, a                         ; B = its first map, [HL] = how many to choose from
            ld a, [hl]
            cp 2
            jr c, .one
            ld c, a
            ld a, [PG_SEED]                 ; (one of them a run: by the seed)
            rrca
            rrca
            rrca
            call pg_mod
            add a, b
            ld b, a
.one:       ld hl, game_flags + PG_EXIT    ; (no light on a pool floor)
            res 0, [hl]
            ld a, b
            jr .go2
.go:        push af                         ; (a boss floor passed already: its light shown)
            ld a, b
            ld [pg_bfi], a
            call pg_open.bf
            ld hl, game_flags + PG_EXIT
            set 0, [hl]
            jr nz, .gl
            res 0, [hl]
.gl:        pop af
.go2:       ld b, a
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

; A = A mod C (C > 0)
pg_mod:     cp c
            ret c
            sub c
            jr pg_mod

; the run's order of the shrine's pool: bt_sbuf = 0 .. P-1 shuffled (Fisher-Yates, a generator seeded by the run)
pg_perm:    ld a, [pg_shr]
            ld hl, pg_npool
            call pg_ixr
            ld b, a                         ; B = P
            ld hl, bt_sbuf
            xor a
.i:         ld [hl+], a
            inc a
            cp b
            jr c, .i
            ld a, [PG_SEED]
            ld [pg_t0], a
            ld c, b                         ; i = P - 1 .. 1: swap [i], [rand % (i + 1)]
            dec c
            ret z
.s:         ld a, [pg_t0]                   ; (x = 5 x + 41)
            ld e, a
            add a, a
            add a, a
            add a, e
            add a, 41
            ld [pg_t0], a
            swap a
            push bc
            inc c
            call pg_mod
            pop bc
            ld e, a
            ld d, 0
            ld hl, bt_sbuf
            add hl, de
            push hl
            ld e, c
            ld hl, bt_sbuf
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

; a new run of shrine pg_shr: depth 0, a new seed, no boss floor passed; the orbs of the bosses not beaten
; shown; a boss floor whose bosses are all beaten is open already
pg_newrun:  ld a, [pg_shr]
            ld [PG_DUN], a
            xor a
            ld [PG_DEPTH], a
            ld [PG_RUNB], a
            call pg_rand
            ld [PG_SEED], a
            call pg_beat                    ; C = the shrine's beaten bosses
            ld hl, game_flags + PG_OBJ0
            ld b, 4
            ld a, c
.o:         res 0, [hl]
            rrca
            jr c, .ob
            set 0, [hl]
.ob:        inc l
            dec b
            jr nz, .o
            ld b, 0                         ; boss floors 0-3: open if none of theirs is left
.f:         ld c, 0                         ; (C: its bosses not beaten)
            ld e, 0
.k:         push bc
            push de
            ld a, e
            ld hl, pg_bfl
            call pg_s4
            pop de
            pop bc
            cp b
            jr nz, .kn
            push bc
            ld b, e
            call pg_bit
            pop bc
            push bc
            ld b, a
            call pg_beat
            ld a, c
            and b
            pop bc
            jr nz, .kn
            inc c
.kn:        inc e
            ld a, e
            cp 4
            jr c, .k
            ld a, c
            and a
            jr nz, .fn
            call pg_bit
            ld hl, PG_RUNB
            or [hl]
            ld [hl], a
.fn:        inc b
            ld a, b
            cp 4
            jr c, .f
            ret
; C = the bosses of shrine pg_shr beaten (PG_BOSS + shrine), HL there
pg_beat:    push de
            ld a, [pg_shr]
            ld e, a
            ld d, 0
            ld hl, PG_BOSS
            add hl, de
            ld c, [hl]
            pop de
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

; ---- a chest: the one in front of the party in the map's list (x, y, kind) -> its gift (pg_gift),
; back through pg_give (A = 0: opened already)
pg_chest:   ld a, [px]
            ld e, a
            ld a, [py]
            ld d, a
            ld a, [facing]
            and a
            jr nz, .f1
            inc e
.f1:        cp 1
            jr nz, .f2
            dec e
.f2:        cp 2
            jr nz, .f3
            dec d
.f3:        cp 3
            jr nz, .f4
            inc d
.f4:        push de
            ld a, [map_bank]
            ld hl, M_PGNC
            ld de, bt_sbuf
            ld bc, 40
            call far_copy
            pop de
            ld hl, bt_sbuf
            ld a, [hl+]
            ld c, a                         ; C = chests left to look at
            ld b, 0                         ; B = this chest's number
            xor a
            ld [pg_t0], a                   ; (ranks: chests of kind 0 / 1 before it)
            ld [pg_t1], a
.l:         ld a, c
            and a
            jp z, .none
            ld a, [hl+]
            cp e
            jr nz, .nx
            ld a, [hl]
            cp d
            jr z, .got
.nx:        inc hl
            ld a, [hl+]                     ; (its kind: count it)
            cp 2
            jr nc, .nk
            push hl
            ld hl, pg_t0
            and a
            jr z, .k0
            inc hl
.k0:        inc [hl]
            pop hl
.nk:        inc b
            dec c
            jr .l
.got:       inc hl
            ld a, [hl]
            ld [pg_bk], a                   ; (its kind)
            ld hl, PG_CHEST                 ; HL, C = its bit (opened this run?)
            ld a, b
            cp 8
            jr c, .lo
            inc hl
            sub 8
.lo:        ld b, a
            call pg_bit
            ld c, a
            and [hl]
            jp nz, .none
            push hl
            push bc
            ld a, [pg_bk]
            cp 2
            jr nc, .fx
            and a                           ; the depth's list (0 / 1): its rank's item, shuffled
            jr z, .r0
            ld a, [pg_t1]
            ld [pg_t0], a
.r0:        ld hl, pg_tl
            call pg_sw
            ld a, [PG_DEPTH]
            add a, a
            add a, a
            ld e, a
            ld a, [pg_bk]
            add a, a
            add a, e
            call pg_ix
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            or h
            jr z, .nol
            ld a, [hl+]                     ; n, then n gifts
            ld c, a
            ld a, [PG_SEED]
            ld e, a
            ld a, [pg_t0]
            add a, e
            call pg_mod
            add a, a
            call pg_ix
            ld a, [hl+]
            ld e, a
            ld d, [hl]
            jr .mark
.nol:       pop bc
            pop hl
            jr .none
.fx:        sub 2                           ; a fixed chest n: once ever
            ld [pg_bk], a
            ld b, a
            call pg_bit
            ld c, a
            ld hl, PG_FIXED
            and [hl]
            jr z, .fn
            pop bc
            pop hl
            jr .none
.fn:        ld a, [hl]
            or c
            ld [hl], a
            ld a, [pg_bk]
            add a, a
            ld hl, pg_fixed
            call pg_ix
            ld a, [hl+]
            ld e, a
            ld d, [hl]
.mark:      pop bc                          ; (opened this run)
            pop hl
            ld a, [hl]
            or c
            ld [hl], a
            jp pg_gift
.none:      xor a
            jp pg_give

; DE = a gift (D 0: an FF1 code E (items, weapons, armour, gold); 1: Dawn of Souls consumable E; 2 / 3: weapon /
; armour id E) -> given, back through pg_give (the chest's message: dlg_item, dlg_nhi: text.s)
pg_gift:    ld a, d
            and a
            jr nz, .n
            ld a, e
            ld [dlg_item], a
            jp pg_give
.n:         cp 1
            jr nz, .gr
            ld a, e                         ; consumable E: one more (99 at most)
            ld [dlg_item], a
            ld a, 1
            ld [dlg_nhi], a
            ld a, e
            add a, C_CONS
            call it_cnt
            ld a, [hl]
            cp 99
            jr nc, .g1
            inc [hl]
.g1:        ld a, 1
            jp pg_give
.gr:        ld b, e                         ; gear E: a free slot (name code: postgame.weapon_code /
            ld hl, C_WPNSLOT                ;   armour_code)
            cp 2
            ld a, e
            jr nz, .ga
            cp 41
            jr c, .w1
            add a, 40
.w1:        add a, 27
            jr .gc
.ga:        ld hl, C_WPNSLOT + 16
            cp 41
            jr c, .a1
            add a, 24
.a1:        add a, 67
.gc:        ld [dlg_item], a
            ld a, 2
            ld [dlg_nhi], a
            jp pg_give

; ---- an orb on the boss floor (its id PG_OBJ0 + k: the shrine's boss k): FF1's Talk_fight (the orb gone,
; the battle when the box closes) with the boss's words (Dawn of Souls' lines)
pg_boss:    ld a, [talk_id]
            cp PG_EXIT                      ; (the light: out to the world map, at the door)
            jr z, .out
            cp PG_OBJ0                      ; (a floor's people: pg_npc)
            jp c, pg_npc
            sub PG_OBJ0
            ld [pg_bk], a
            ld hl, pg_fy                    ; (its picture's first cell)
            call pg_s4
            ldh [hbt_fy], a
            ld a, [talk_id]
            call hide_this
            ld a, [pg_bk]
            ld hl, pg_bform
            call pg_s4
            call talk_btl
            ld a, [pg_shr]
            add a, a
            add a, a
            ld hl, pg_bk
            add a, [hl]
            add a, a
            ld hl, pg_t_boss
            call pg_ix
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            jp pg_say
.out:       ld a, [ow_x]
            ld d, a
            ld a, [ow_y]
            ld e, a
            xor a
            ld [fdepth], a
            ld a, MAP_OW
            jp pg_lmw

; ---- after a battle in the post-game (A = do_battle's result): a boss beaten: remembered, its floor
; passed this run (its other orbs gone), the party stays; a boss with a second form fights it first
pg_after:   push af
            ld a, [pg_ffb]                  ; (a person's battle: the floor's own battle banks again)
            and a
            jr z, .pg
            xor a
            ld [pg_ffb], a
            call pg_lcd2
            pop af
            ret
.pg:        ld a, [pend_btl]
            ld c, a
            ld e, 0
.f:         push de                         ; which of the shrine's bosses?
            ld a, e
            ld hl, pg_bform
            call pg_s4
            pop de
            cp c
            jr z, .k
            push de
            ld a, e
            ld hl, pg_b2
            call pg_s4
            pop de
            cp c
            jr z, .k2
            inc e
            ld a, e
            cp 4
            jr c, .f
            pop af
            ret
.k:         ld a, e                         ; (boss e: a second form?)
            ld [pg_bk], a
            ld hl, pg_b2
            call pg_s4
            and a
            jr z, .won
            ld b, a
            pop af
            ld a, b
            call talk_btl                   ; (the second form when its box closes)
            ld a, [pg_shr]
            add a, a
            add a, a
            ld hl, pg_bk
            add a, [hl]
            add a, a
            ld hl, pg_t_b2
            call pg_ix
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            jp pg_say
.k2:        ld a, e
            ld [pg_bk], a
.won:       ld a, [pg_bk]                   ; beaten: PG_BOSS + shrine, bit k
            ld b, a
            call pg_bit
            ld b, a
            call pg_beat
            ld a, b
            or c
            ld [hl], a
            ld a, [pg_bfi]                  ; this floor passed this run
            ld b, a
            call pg_bit
            ld hl, PG_RUNB
            or [hl]
            ld [hl], a
            ld a, PG_EXIT                   ; the light out: shown
            call show_obj
            ld e, 0                         ; the floor's other orbs: gone
.o:         push de
            ld a, e
            ld hl, pg_bfl
            call pg_s4
            ld b, a
            ld a, [pg_bfi]
            cp b
            pop de
            jr nz, .on
            ld a, e
            add a, PG_OBJ0
            push de
            call hide_obj
            pop de
.on:        inc e
            ld a, e
            cp 4
            jr c, .o
            pop af
            ret

; ---- the party after a lost battle: alive, ailments gone, 1 HP at least; A = MAP_OW, D, E = the door
pg_revive:  xor a                           ; (no boss beaten: pg_after)
            ld [pend_btl], a
            ld [pg_ffb], a
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
            ld a, [ow_x]
            ld d, a
            ld a, [ow_y]
            ld e, a
            ld a, MAP_OW
            ret

; ---- a floor's people (ids PG_NPC0 + n: pgevents.py): their scripts. Ops: $00 end (no box), $01 say (text in
; PGT_BANK), $02 if flag (f, offset), $03 set flag, $04 fight (FF1's formation), $05 hide (this person), $06 if all
; (mask, offset), $07 if boss beaten (shrine, boss, offset), $08 shop, $09 heal, $0A MP full, $0B HP halved,
; $0D give (kind: 0 FF1 item / 1 new consumable, which), $0F go to (offset), $10 the next box's fanfare
pg_npc:     call pg_evrec
            ret z
            ld a, [talk_id]
            sub PG_NPC0
            add a, a
            add a, 5
            call pg_ix
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld a, l
            ld [pg_sb], a
            ld a, h
            ld [pg_sb + 1], a
.op:        ld a, [hl+]
            and a
            ret z
            dec a
            jr z, .say
            dec a
            jr z, .ifset
            dec a
            jr z, .set
            dec a
            jp z, .fight
            dec a
            jp z, .hide
            dec a
            jp z, .ifall
            dec a
            jp z, .ifboss
            dec a
            jp z, .shop
            dec a
            jp z, .heal
            dec a
            jp z, .mpup
            dec a
            jp z, .drain
            dec a
            dec a
            jp z, .give
            dec a
            dec a
            jp z, .goto
            ld a, 2                         ; (the treasure ditty with the next box)
            ld [pg_sfx], a
            jr .op
.say:       ld a, [hl+]
            ld h, [hl]
            ld l, a
            jp pg_esay
.ifset:     ld a, [hl+]
            ld c, [hl]
            inc hl
            call pg_pfbit
            jr z, .op
.jmp:       ld a, [pg_sb]                   ; (to the script's offset C)
            add a, c
            ld l, a
            ld a, [pg_sb + 1]
            adc a, 0
            ld h, a
            jr .op
.set:       ld a, [hl+]
            call pg_pfbit
            ld a, [de]
            or b
            ld [de], a
            jr .op
.goto:      ld c, [hl]
            inc hl
            jr .jmp
.fight:     ld a, [hl+]                     ; FF1's formation: FF1's battle banks until pg_after
            push hl
            call talk_btl
            ld a, BTL_DATA
            ldh [hbt_db], a
            ld a, BTL6_BANK
            ldh [hbt_dom], a
            ld a, ENEMY_CHR
            ldh [hbt_cb], a
            ld a, ESIL_BANK
            ldh [hbt_sb], a
            ld a, SGB_BANK
            ldh [hbt_sgb], a
            ld a, $23
            ldh [hbt_fy], a
            ld a, 1
            ld [pg_ffb], a
            pop hl
            jp .op
.hide:      push hl
            ld a, [talk_id]
            call hide_this
            pop hl
            jp .op
.ifall:     ld a, [hl+]
            ld e, a
            ld a, [hl+]
            ld d, a
            ld c, [hl]
            inc hl
            ld a, [PG_PF]
            and e
            cp e
            jp nz, .op
            ld a, [PG_PF + 1]
            and d
            cp d
            jp nz, .op
            jr .jmp
.ifboss:    ld a, [hl+]                     ; (PG_BOSS + shrine, the boss's bit)
            ld e, a
            ld a, [hl+]
            ld b, a
            ld c, [hl]
            inc hl
            push hl
            ld d, 0
            ld hl, PG_BOSS
            add hl, de
            call pg_bit
            and [hl]
            pop hl
            jp z, .op
            jr .jmp
.shop:      ld a, [hl]                      ; (as a shop's door: main.s)
            ld [shop_arg], a
            ld hl, shop_main
            call pc_menu
            jp map_reload
.heal:      push hl                         ; everyone not dead / stone: HP full
            ld hl, ch_stats
            ld b, 4
.hl:        push hl
            inc l
            ld a, [hl]
            dec l
            dec a                           ; (1 dead, 2 stone: not healed)
            cp 2
            jr c, .hn
            ld a, l
            add a, CH_MAXHP
            ld l, a
            ld a, [hl+]
            ld c, [hl]
            dec l
            dec l
            ld [hl], c
            dec l
            ld [hl], a
.hn:        pop hl
            ld a, l
            add a, $40
            ld l, a
            dec b
            jr nz, .hl
            pop hl
            jp .op
.mpup:      push hl
            ld a, 2
            ld hl, party_mp
            call bank_call
            pop hl
            jp .op
.drain:     push hl                         ; everyone not dead / stone: HP halved, 1 at least
            ld hl, ch_stats
            ld b, 4
.dl:        push hl
            inc l
            ld a, [hl]
            dec a
            cp 2
            jr c, .dn
            ld a, l
            add a, CH_HP - CH_AIL + 1
            ld l, a
            srl [hl]
            dec l
            rr [hl]
            ld a, [hl+]
            or [hl]
            jr nz, .dn
            dec l
            ld [hl], 1
.dn:        pop hl
            ld a, l
            add a, $40
            ld l, a
            dec b
            jr nz, .dl
            pop hl
            jp .op
.give:      ld a, [hl+]                     ; (kind, which: one more, 99 at most)
            ld d, a
            ld a, [hl+]
            push hl
            ld e, a
            ld a, d
            and a
            ld a, e
            jr z, .gf
            add a, C_CONS
.gf:        call it_cnt
            ld a, [hl]
            cp 99
            jr nc, .gx
            inc [hl]
.gx:        pop hl
            jp .op
; a box of the post-game's text HL (bank PGT_BANK), with pg_sfx's fanfare; C clear. Always the last thing
; done (jp): the text bank is mapped while the box opens, so no code of this bank may run after it
pg_esay:    ld a, PGT_BANK
            ld [dlg_bank], a
            ld a, l
            ld [dlg_ptr], a
            ld a, h
            ld [dlg_ptr + 1], a
            ld a, [pg_sfx]
            ld [dlgsfx], a
            xor a
            ld [pg_sfx], a
            jp dlg_open2
; NZ: floor flag A set (HL kept); DE = its byte, B = its bit
pg_pfbit:   ld de, PG_PF
            cp 8
            jr c, .l
            inc de
            sub 8
.l:         ld b, a
            call pg_bit
            ld b, a
            ld a, [de]
            and b
            ret

; ==== Dawn of Souls' items (postgame.py NEW_CONS, WEAPON_NAMES, ARMOUR_NAMES): consumable k's Items-screen code
; C_CONS + k, its count at NEWIT + k, its name index 256 + k (names.py); FF1's items: ITEMS + code
section bank 0, $3FA7                       ; (free space)
; A = an item -> HL = its count (A kept)
it_cnt:     cp $1C
            jr nc, .n
            add a, low(ITEMS)
            ld l, a
            sub low(ITEMS)
            ld h, high(ITEMS)
            ret
.n:         sub C_CONS - low(NEWIT)         ; (Dawn of Souls' k: code C_CONS + k, NEWIT + k)
            ld l, a
            add a, C_CONS - low(NEWIT)
            ld h, high(NEWIT)
            ret

section bank 0, $3574                       ; (free space)
; the chest message's item: DE = its name index (pg_nidx)
dlg_nidx:   push hl
            ld a, PGM_BANK
            ld hl, pg_nidx
            call bank_call
            pop hl
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

MD_MAX     = 23
section wram, $DD20
c6_jp:      ds 3
c6_b:       ds 1
md_n:       ds 1
md_pg:      ds 1
md_sel:     ds 1
pg_mm:      ds 1
pg_use:     ds 1
md_list:    ds MD_MAX                       ; (the Medicine owned: at most MD_MAX kinds listed)

; ---- the Items screen (bank 2): the new consumables' uses (it_utab: postgame.USES; pg_use1 in the post-game's
; bank does the member's part)
U_CURE     = 2
U_MEGA     = 4
U_EXIT     = 11
section bank 2, $7D7D
; it_use: FF1's items by its jump table, the new ones here
it_ux:      cp $1C
            jr nc, .n
            ld hl, it_jt
            ret
.n:         pop hl
            sub C_CONS
            ld e, a
            ld d, 0
            ld hl, it_utab
            add hl, de
            ld a, [hl]
            ld [pg_use], a
            and a
            jr z, u_none
            cp U_CURE
            jr z, u_rem
            cp U_EXIT
            jr z, u_exit
            cp U_MEGA
            jr z, u_all
            ld a, IT_UseItem_Heal_0         ; one member: the target screen, as FF1's Potion
            call tgt_open
            call tgt_pick
            jr .t
.l:         call tgt_pick2
.t:         jp c, item_menu.re
            ld [pg_mm], a
            ld a, PGM_BANK
            ld hl, pg_use1
            call bank_call
            and a
            jr z, .ok
            dec a
            jr nz, .er
            ld a, IT_UseItem_Heal_0
            call no_eff
            jr .l
.er:        call sfx_err
            jr .l
.ok:        call u_ok
            jr nz, .l
            jp item_menu.re
u_none:     call sfx_err                    ; (a battle item: not here)
            jp item_menu.l
; the item used: its sound, one fewer, the target screen again; NZ: some left
u_ok:       ld a, TR_HPUP
            call snd_track
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
; Megalixir: everyone standing
u_all:      ld a, IT_UseItem_Heal_0
            call tgt_open
.l:         call tg_all
            jp c, item_menu.re
            ld b, 0
.m:         push bc
            ld a, b
            ld [pg_mm], a
            ld a, PGM_BANK
            ld hl, pg_use1
            call bank_call
            pop bc
            inc b
            ld a, b
            cp 4
            jr c, .m
            call u_ok
            jr nz, .l
            jp item_menu.re
; Emergency Exit: out to the world map (as the Exit spell; not on the world map)
u_exit:     ld a, [cur_map]
            inc a
            jr z, u_none
            ld a, [it_id]
            call it_cnt
            dec [hl]
            ld a, 2
            ld [menu_act], a
            ret

section bank 2, $60D8
; the main menu's Items: out of the menus too after an Emergency Exit
item_mx:    call item_menu
            ld a, [menu_act]
            and a
            ret z
            pop hl
            ret
; the name of Items-screen code A at the pen (Dawn of Souls' consumables: name index 256 + k)
it_pen:     cp C_CONS
            jp c, pen_iname
            sub C_CONS
            ld l, a
            ld h, 1
            jp pen_inx

section bank PGM_BANK, $6000
; a new consumable used on member pg_mm (pg_use: postgame.USES) -> A = 0 used, 1 no effect, 2 not on them
pg_use1:    ld a, [pg_mm]
            call ch_rec
            inc hl
            ld a, [hl]                      ; (the ailment: 1 dead, 2 stone)
            dec hl
            ld c, a
            ld a, [pg_use]
            cp 10                           ; Phoenix Down: the dead only, back with 1 HP
            jr nz, .nl
            ld a, c
            cp 1
            ld a, 1
            ret nz
            inc hl
            ld [hl], 0
            ld a, l
            add a, CH_HP - CH_AIL
            ld l, a
            ld [hl], 1
            xor a
            ret
.nl:        ld a, c
            cp 1
            jr z, .x2
            cp 2
            jr z, .x2
            ld a, [pg_use]
            ld b, a
            ld de, .t - 2
            add a, a
            add a, e
            ld e, a
            jr nc, .j
            inc d
.j:         ld a, [de]
            push af
            inc de
            ld a, [de]
            ld d, a
            pop af
            ld e, a
            push de
            ret
.x2:        ld a, 2
            ret
.t:         dw .hp, .cu, .eth, .mega, .ap5, .hpf, .eth2, .ethx, .elx, .x2, .x2, .ap10, .soma, .st0, .st3, .st2
            dw .st1, .st4
.hp:        ld bc, 150                      ; Hi-Potion
            jr .hpa
.hpf:       ld bc, 999                      ; X-Potion
.hpa:       call pg_hpadd
            ret
.cu:        ld a, 1
            ret
.eth:       call pg_mpis                    ; Ether: one charge a level
            ld a, 1
            ret z
            call pg_ether
            xor a
            ret
.eth2:      call pg_mpis                    ; Turbo Ether: two
            ld a, 1
            ret z
            call pg_ether
            call pg_ether
            xor a
            ret
.ethx:      call pg_mpis                    ; Dry Ether: all
            ld a, 1
            ret z
            call pg_mpfull
            xor a
            ret
.mega:      call pg_mpfull                  ; Megalixir (each member): all HP and MP
            ld bc, 999
            call pg_hpadd
            xor a
            ret
.elx:       call pg_mpfull                  ; Elixir: all HP and MP
            ld bc, 999
            call pg_hpadd
            xor a
            ret
.ap5:       ld c, 5                         ; Silver / Golden Apple: the maximum HP for good
            jr .ap
.ap10:      ld c, 10
.ap:        ld a, [pg_mm]
            call ch_rec
            ld a, l
            add a, CH_MAXHP
            ld l, a
            ld a, [hl]
            add a, c
            ld e, a
            inc hl
            ld a, [hl]
            adc a, 0
            ld d, a
            ld a, e                         ; (999 at most)
            sub low(1000)
            ld a, d
            sbc a, high(1000)
            jr c, .apw
            ld de, 999
.apw:       ld [hl], d
            dec hl
            ld [hl], e
            ld b, 0
            call pg_hpadd
            xor a
            ret
.soma:      ld a, [pg_mm]                   ; Soma Drop: one more charge on each level known (9 at
            call pg_mrec                    ;   most); Modern MP: 10 more
            ld a, l
            add a, $28
            ld l, a
            ld b, 8
.so:        ld a, [hl]
            and a
            jr z, .so2
            cp 9
            jr nc, .so2
            inc [hl]
.so2:       inc l
            dec b
            jr nz, .so
            ld a, [pg_mm]
            call pg_mrec
            ld a, l
            add a, MM_CUR + 2
            ld l, a
            ld a, [hl]
            add a, 10
            ld [hl+], a
            ld a, [hl]
            adc a, 0
            ld [hl], a
            xor a
            ret
.st0:       ld e, $10                       ; Power / Speed / Mind / Stamina / Luck Plus: the stat + 1
            jr .st                          ;   for good (99 at most)
.st1:       ld e, $11
            jr .st
.st2:       ld e, $12
            jr .st
.st3:       ld e, $13
            jr .st
.st4:       ld e, $14
.st:        ld a, [pg_mm]
            call ch_rec
            ld a, l
            add a, e
            ld l, a
            ld a, [hl]
            cp 99
            ld a, 1
            ret nc
            inc [hl]
            xor a
            ret
; Z: member pg_mm's MP already full (or none)
pg_mpis:    ld a, [pg_mm]
            call pg_mrec
            ld a, l
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
            ret                             ; (a charge short: NZ)
.n:         inc l
            dec b
            jr nz, .c
            xor a
            ret
; member pg_mm's HP + BC, up to the maximum (B = 0 and C = 0: only to the maximum); A = 0, 1 if it was full
pg_hpadd:   ld a, [pg_mm]
            call ch_rec
            ld a, l
            add a, CH_HP
            ld l, a
            ld a, [hl+]
            ld e, a
            ld a, [hl+]
            ld d, a
            ld a, [hl+]
            cp e
            jr nz, .add
            ld a, [hl]
            cp d
            ld a, 1
            jr nz, .add
            ld a, b
            or c
            ld a, 1
            ret nz
.add:       dec hl
            ld a, e
            add a, c
            ld e, a
            ld a, d
            adc a, b
            ld d, a
            ld a, [hl+]                     ; (max: low, high)
            sub e
            ld a, [hl]
            sbc a, d
            jr nc, .w
            ld a, [hl-]
            ld d, a
            ld e, [hl]
            inc hl
.w:         dec hl
            dec hl
            ld [hl], d
            dec hl
            ld [hl], e
            xor a
            ret

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
.add:       ld a, c
            cp MD_MAX
            jr nc, .bd
            ld [hl], b
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
; bt_pl_drink (md_use): the item's MP effect (md_tab byte 3: 1 a charge a level, 2 two, 3 all, 4 everyone's all,
; 5 all, the HP done by its magic) on its target (bt_tgt) / everyone standing; A = the count's address
md_mp:      ld hl, md_tab + 3
            ld b, MD_N
.f:         dec hl
            dec hl
            dec hl
            cp [hl]
            inc hl
            inc hl
            inc hl
            jr z, .g
            inc hl
            inc hl
            inc hl
            inc hl
            dec b
            jr nz, .f
            ret
.g:         ld a, [hl]
            and a
            ret z
            ld [pg_use], a
            cp 4
            jr z, .all
            ld a, [bt_tgt]
            and 3
            ld [pg_mm], a
.one:       ld a, [pg_use]
            ld hl, pg_ether
            cp 1
            jr z, .c
            cp 2
            jr nz, .full
            ld a, PGM_BANK
            call bank_call
            ld hl, pg_ether
            jr .c
.full:      ld hl, pg_mpfull
.c:         ld a, PGM_BANK
            jp bank_call
.all:       ld b, 0
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

section bank 0, $13F5                       ; (free space)
; veh_oam: the bridge and the canal (ow_bc), then the shrine's statue
pg_owst:    call ow_bc
            ld a, PGM_BANK
            ld hl, pg_statue
            jp bank_call

section bank PGM_BANK, $6380
; dlg_item, dlg_nhi -> DE = the item's name index (names.py): dlg_nhi 1: 256 + dlg_item (Dawn of Souls'
; consumables), 2: dlg_item (the gear); 0: FF1's codes, a gold amount's name at 256 + its code; dlg_nhi cleared
pg_nidx:    ld a, [dlg_item]
            ld e, a
            ld d, 0
            ld a, [dlg_nhi]
            and a
            jr nz, .x
            ld a, e
            cp $6C
            ret c
            cp $B0
            ret nc
            inc d
            ret
.x:         dec a
            jr nz, .y
            inc d
.y:         xor a
            ld [dlg_nhi], a
            ret

section bank PGM_BANK, $6400
; veh_tiles (the world map, LCD off; DE = the vehicles' tiles in the map's bank): them to sprite tiles $10-$6F,
; then the statue of the sealed shrine nearest the party (pg_stl; its tiles after the vehicles', 256 bytes each)
pg_veh:     push de
            ld a, [map_bank]
            ld h, d
            ld l, e
            ld de, $8100
            ld bc, 96 * 16
            call far_copy
            ld c, 0                         ; the nearest sealed shrine (by the larger of |dx|, |dy|)
            ld b, $FF
            ld e, 0
.s:         push bc
            push de
            ld a, e
            ld hl, pg_orb
            call pg_ixr
            ld l, a
            ld h, high(ORBS)
            ld a, [hl]
            pop de
            pop bc
            and a
            jr nz, .n
            push bc
            ld a, e
            add a, a
            ld hl, pg_door
            push de
            call pg_ixr
            pop de
            ld b, a
            ld a, [px]
            sub b
            jr nc, .x
            cpl
            inc a
.x:         ld d, a
            inc hl
            ld a, [py]
            sub [hl]
            jr nc, .y
            cpl
            inc a
.y:         cp d
            jr nc, .m
            ld a, d
.m:         pop bc
            cp b
            jr nc, .n
            ld b, a
            ld c, e
.n:         inc e
            ld a, e
            cp 4
            jr c, .s
            ld a, c
            ld [pg_stl], a
            pop hl                          ; (statue C's tiles: bank STATUE_BANK, $4000 / $4400 + 256 C)
            ld h, $40
            ldh a, [is_cgb]
            and a
            jr nz, .cg
            ld h, $44
.cg:        ld a, c
            add a, h
            ld h, a
            ld l, 0
            ld a, STATUE_BANK
            ld de, $8700
            ld bc, 256
            jp far_copy

section bank PGM_BANK, $7200
; the statue before the nearest sealed shrine's door (pg_stl, until its Fiend is beaten): the Fiend in stone,
; 4 x 4 sprites (OAM 24-39, tiles $70-$7F) centred on the door, standing on its tile
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
            ld a, [pg_stl]                  ; (the shrine whose statue is loaded)
            ld hl, pg_orb
            call pg_ixr
            ld l, a
            ld h, high(ORBS)
            ld a, [hl]
            and a
            ret nz
            ld a, [pg_stl]
            add a, a
            ld hl, pg_door
            call pg_ixr
            push hl
            ld hl, px
            call ob_pos
            pop hl
            ret c
            sub 8
            ld b, a
            inc hl
            ld a, [hl]
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

; ==== the gear's name codes (postgame.weapon_code / armour_code): weapon / armour id A (Z: a weapon) -> its
; name code (FF1's 40 of each: $1B + n / $43 + n; Dawn of Souls': $43 + n / $5B + n), and back (gidz)
section bank 2, $7F11
gcodez:      jr nz, .a
            cp 41
            jr c, .w
            add a, 40
.w:         add a, 27
            ret
.a:         cp 41
            jr c, .b
            add a, 24
.b:         add a, 67
            ret
gidz:       jr nz, .a
            cp $6C
            jr c, .w
            sub 40
.w:         sub $1B
            ret
.a:         cp $84
            jr c, .b
            sub 24
.b:         sub $43
            ret
section bank 6, $6C46
gcodez6:     jr nz, .a
            cp 41
            jr c, .w
            add a, 40
.w:         add a, 27
            ret
.a:         cp 41
            jr c, .b
            add a, 24
.b:         add a, 67
            ret
section bank 107, $7FC0
gcodez7:     jr nz, .a
            cp 41
            jr c, .w
            add a, 40
.w:         add a, 27
            ret
.a:         cp 41
            jr c, .b
            add a, 24
.b:         add a, 67
            ret
section bank 110, $7FC0
gcodez110:   jr nz, .a
            cp 41
            jr c, .w
            add a, 40
.w:         add a, 27
            ret
.a:         cp 41
            jr c, .b
            add a, 24
.b:         add a, 67
            ret
