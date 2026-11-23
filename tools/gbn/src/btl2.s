; FF1 native engine: battle part 2 (bank 6): stats, commands, the round, physical attacks,
; running, messages, the end of the battle. Our own code from FF1's battle routines
; (bank 0C: Battle_AfterFadeIn, BattleLogicLoop, DoBattleRound, Battle_DoPlayerTurn,
; DoPhysicalAttack, Battle_DoEnemyTurn, Enemy_DoAi, Battle_PlayerTryRun, ...). FF1's known
; bugs in these routines are fixed as in the recompiled Game Boy build (weapon critical rate /
; element / category used; the run chance reads the level).

AIL_DEAD   = $01            ; FF1's in-battle ailment bits
AIL_STONE  = $02
AIL_POISON = $04
AIL_DARK   = $08
AIL_STUN   = $10
AIL_SLEEP  = $20
AIL_MUTE   = $40
AIL_CONF   = $80
E_EXP      = 0              ; enemy record: the ROM's 20 bytes, then the battle's own
E_GP       = 2
E_HPMAX    = 4
E_MORALE   = 6
E_AI       = 7
E_EVADE    = 8
E_ABSORB   = 9
E_NUMHITS  = 10
E_HITRATE  = 11
E_DMG      = 12
E_CRIT     = 13
E_ATKAIL   = 15
E_CAT      = 16
E_MAGDEF   = 17
E_WEAK     = 18
E_RESIST   = 19
E_HP       = 20
E_AIL      = 22
E_HMULT    = 23
E_AIMAG    = 24
E_AIATK    = 25
E_ID       = 26
C_HITRATE  = 0              ; member battle block (FF1 btlch_*)
C_MAGDEF   = 1
C_EVADE    = 2
C_ABSORB   = 3
C_DMG      = 4
C_RESIST   = 5
C_HMULT    = 6
C_NUMHITS  = 7
C_CAT      = 8
C_ELEM     = 9
C_CRIT     = 10
C_WGFX     = 11
C_WPLT     = 12
M_HITS     = $2B            ; FF1 battle message numbers (text: entry n - 1)
M_CRIT     = $2C
M_DMG      = $2E
M_SLAIN    = $20
M_TERM     = $3F
M_MISS     = $40
M_NOEFFECT = $21
M_FIRST    = $22
M_SURPRISE = $23
M_CANTRUN  = $24
M_RANAWAY  = $25
M_CLOSE    = $26
M_WOKE     = $27
M_ASLEEP   = $28
M_CURED    = $29
M_PARA     = $2A
B_LVUP     = $7A00          ; battle data: level-up bytes (6 classes x 49 levels x 2)
B_HITBON   = $7C80          ;   hit rate / magic defence bonuses (12 + 12)

section bank 6, $4C00

; ---- the battle (replaces the placeholder loop): set up, rounds until it ends
bt_run:     call bt_ch_init
            call bt_en_init
            xor a
            ld [bt_msgon], a
            ld [bt_first], a
            ld [bt_result], a
            ld [bt_defer], a
            ld hl, bt_cmd                   ; (no commands yet: a surprise round skips the
            ld b, 16                        ;   party's choices, its members then do nothing)
.cc:        ld [hl+], a
            dec b
            jr nz, .cc
            ld a, [bt_form + 13]            ; no-run formations: no surprise / first strike
            and 1
            jr nz, .loop
            call bt_surprise
            jr c, .comb                     ; surprised: the party's first commands skipped
.loop:      call bt_commands
.comb:      call bt_round
            ld a, [bt_result]
            and a
            jr z, .loop
            ret

; FF1: S = (leader agility + luck) / 8; V = random(S + S .. S + 100) - surprise rate;
; V < 11 surprised (C set), V >= 90 the party strikes first
bt_surprise:
            ld a, [ch_stats + $11]
            ld b, a
            ld a, [ch_stats + $14]
            add a, b
            srl a
            srl a
            srl a
            ld [bt_t], a
            ld b, 100
            call bt_randab                  ; S .. 100
            ld b, a
            ld a, [bt_t]
            ld l, a
            ld h, 0
            ld c, b
            ld b, 0
            add hl, bc
            ld a, [bt_form + 12]
            ld c, a
            ld b, 0
            ld a, l
            sub c
            ld l, a
            ld a, h
            sbc a, b
            ld h, a
            jr nc, .p
            ld hl, 0
.p:         ld a, h                         ; (the low byte decides, as FF1)
            ld a, l
            cp 11
            jr c, .sur
            cp 90
            ccf
            ret nc
            ld a, 1
            ld [bt_first], a
            ld a, M_FIRST
            call bt_say
            and a
            ret
.sur:       ld a, M_SURPRISE
            call bt_say
            scf
            ret

; ---- members' battle stats (FF1 LoadOneCharacterIBStats); ailments to battle bits
bt_ch_init: xor a
.m:         push af
            call ch_rec
            inc hl
            ld a, [hl]                      ; outside ailment 1 dead, 2 stone, 3 poison
            ld b, 0
            cp 1
            jr nz, .a1
            ld b, AIL_DEAD
.a1:        cp 2
            jr nz, .a2
            ld b, AIL_STONE
.a2:        cp 3
            jr nz, .a3
            ld b, AIL_POISON
.a3:        ld [hl], b
            dec hl
            pop af
            push af
            call bt_cblk                    ; DE = the block
            push hl
            ld a, l
            add a, $21
            ld l, a
            ld a, [hl]                      ; hit rate
            ld [de], a
            inc de
            ld b, a
            ld a, l
            add a, 4
            ld l, a
            ld a, [hl]                      ; magic defence ($25)
            ld [de], a
            inc de
            dec l
            dec l
            ld a, [hl]                      ; evade ($23)
            ld [de], a
            inc de
            dec l
            ld a, [hl]                      ; absorb ($22)
            ld [de], a
            inc de
            dec l
            dec l
            ld a, [hl]                      ; damage ($20)
            ld [de], a
            inc de
            ld a, l
            add a, 4
            ld l, a
            ld a, [hl]                      ; resistance ($24)
            ld [de], a
            inc de
            ld a, 1                         ; hits multiplier
            ld [de], a
            inc de
            ld a, b                         ; hits: hit rate / 32 + 1
            swap a
            rrca
            and 7
            inc a
            ld [de], a
            inc de
            pop hl
            push hl
            push de
            ld a, l                         ; the equipped weapon (bit 7 of a weapon slot)
            add a, $18
            ld l, a
            ld b, 4
            xor a
            ld [bt_t + 1], a
.w:         ld a, [hl+]
            bit 7, a
            jr nz, .we
            dec b
            jr nz, .w
            jr .nw
.we:        and $7F
            dec a                           ; its data: crit (2), element (4), category (5), gfx (6)
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, N_WSTAT
            add hl, de
            ld de, scr_buf
            ld bc, 8
            ld a, NAMES
            call far_copy
            ld a, 1
            ld [bt_t + 1], a
.nw:        pop de
            ld a, [bt_t + 1]
            and a
            jr z, .z
            ld a, [scr_buf + 5]             ; category, element, critical rate, graphic
            ld [de], a
            inc de
            ld a, [scr_buf + 4]
            ld [de], a
            inc de
            ld a, [scr_buf + 2]
            ld [de], a
            inc de
            ld a, [scr_buf + 6]
            ld [de], a
            inc de                          ; (and its palette colour)
            ld a, [scr_buf + 7]
            ld [de], a
            dec de
            jr .bb
.z:         xor a
            ld [de], a
            inc de
            ld [de], a
            inc de
            ld [de], a
            inc de
            ld [de], a
            inc de
            ld [de], a
            dec de
.bb:        pop hl                          ; Black Belt / Master unarmed: critical 2 level,
            ld a, [hl]                      ;   hits x 2
            cp CLS_BB
            jr z, .b1
            cp CLS_MA
            jr nz, .nx
.b1:        ld a, [bt_t + 1]
            and a
            jr nz, .nx
            ld a, l
            add a, CH_LEVEL
            ld l, a
            ld a, [hl]
            add a, a
            ld [de], a                      ; (DE: the graphic byte; critical is one before)
            dec de
            ld [de], a
            inc de
            xor a
            ld [de], a
            ld a, e
            sub C_WGFX - C_NUMHITS
            ld e, a
            ld a, [de]
            add a, a
            ld [de], a
.nx:        pop af
            inc a
            cp 4
            jp c, .m
            ret
; member A -> DE = its battle block (16 bytes)
bt_cblk:    swap a
            add a, low(bt_ch)
            ld e, a
            ld a, high(bt_ch)
            adc a, 0
            ld d, a
            ret

; enemies' records from the ROM's stats (FF1 LoadEnemyStats)
bt_en_init: ld c, 0
.e:         ld a, c
            call bt_erec                    ; HL = record
            ld e, c
            ld d, 0
            push hl
            ld hl, bt_eid
            add hl, de
            ld a, [hl]
            pop hl
            cp $FF
            jr z, .n
            push bc
            push hl
            ld [bt_t], a
            ld l, a                         ; 20 x id
            ld h, 0
            add hl, hl
            add hl, hl
            ld d, h
            ld e, l
            add hl, hl
            add hl, hl
            add hl, de
            ld de, B_STATS
            add hl, de
            pop de
            push de
            ld bc, 20
            ld a, BTL_DATA
            call far_copy
            pop hl
            ld a, [hl+]                     ; (HL: +1; the HP from the maximum)
            ld bc, E_HPMAX - 1
            add hl, bc
            ld a, [hl+]
            ld b, a
            ld a, [hl]
            ld c, a
            ld de, E_HP - E_HPMAX - 1
            add hl, de
            ld a, b
            ld [hl+], a
            ld a, c
            ld [hl+], a
            xor a
            ld [hl+], a                     ; ailments
            ld a, 1
            ld [hl+], a                     ; hits multiplier
            xor a
            ld [hl+], a
            ld [hl+], a                     ; AI positions
            ld a, [bt_t]
            ld [hl], a
            pop bc
.n:         inc c
            ld a, c
            cp 9
            jr c, .e
            ret
; enemy A -> HL = its record (32 bytes)
bt_erec:    ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, bt_en
            add hl, de
            ret

; ---- commands (FF1 GetCharacterBattleCommand): B goes back a member
bt_commands:
            call bt_curr                    ; (Options: Cursor Reset)
            ld a, [ITEMS + $19]             ; potions this round (FF1 btl_potion_heal / pure)
            ld [bt_pots], a
            ld a, [ITEMS + $1A]
            ld [bt_pots + 1], a
            ld hl, bt_cmd
            ld b, 16
            xor a
.c:         ld [hl+], a
            dec b
            jr nz, .c
            xor a
            ld [bt_cm], a
.m:         ld a, [bt_cm]
            call ch_rec
            inc hl
            ld a, [hl]
            and AIL_DEAD | AIL_STONE | AIL_STUN | AIL_SLEEP
            jr z, .in
            and AIL_DEAD | AIL_STONE        ; (can't act: no command)
            ld b, a
            call .slot
            ld [hl], b
            jr .nx
.in:        call bt_cmd_one
            jr nc, .nx
            ld a, [bt_cm]                   ; B: the previous member (that can act)
.bk:        and a
            jr z, .m
            dec a
            ld [bt_cm], a
            call ch_rec
            inc hl
            ld a, [hl]
            and AIL_DEAD | AIL_STONE | AIL_STUN | AIL_SLEEP
            jr z, .m
            ld a, [bt_cm]
            jr .bk
.nx:        ld hl, bt_cm
            inc [hl]
            ld a, [hl]
            cp 4
            jr c, .m
            jp bt_names_win                 ; (all chosen: the names again)
.slot:      ld a, [bt_cm]
            add a, a
            add a, a
            ld e, a
            ld d, 0
            ld hl, bt_cmd
            add hl, de
            ret

; one member: step forward, the command window; C set on B (back a member)
bt_cmd_one: ld a, [bt_cm]
            call bt_step_fwd
            call bt_cmd_win
            ld hl, bt_lastc                 ; (the member's last command: the hand there)
            call bt_memp
            ld a, [hl]
            cp 4
            jr c, .c0
            xor a
.c0:        ld [bt_ccur], a
.l:         call bt_cmd_hand
            call bt_frame
            ldh a, [pad_new]
            bit 1, a
            jr nz, .b
            bit 0, a
            jr nz, .a
            ld hl, bt_ccur
            bit 6, a
            jr nz, .up
            bit 7, a
            jr nz, .dn
            and $30
            jr z, .l
            ld a, [hl]                      ; left / right: Fight <-> Run
            cp 4
            ld a, 4
            jr nz, .s
            xor a
            jr .s
.up:        ld a, [hl]
            cp 4
            jr nc, .l
            dec a
            and 3
            jr .s
.dn:        ld a, [hl]
            cp 4
            jr nc, .l
            inc a
            and 3
.s:         ld [hl], a
            jr .l
.b:         ld a, [bt_cm]
            call bt_step_back
            scf
            ret
.a:         ld a, [bt_ccur]
            cp 4
            jr z, .run                      ; (Run is not remembered)
            ld hl, bt_lastc
            call bt_memp
            ld [hl], a
            and a
            jr z, .fight
            cp 1
            jr nz, .md
            call bt_cmd_magic
            jr c, .back
            jr .done
.md:        cp 2
            jr nz, .it
            call bt_cmd_drink
            jr c, .back
            jr .done
.it:        call bt_cmd_item
            jr c, .back
            jr .done
.fight:     call bt_names_win
            call bt_target_enemy
            jr c, .back
            ld b, a
            call bt_commands.slot
            ld [hl], $04
            inc hl
            inc hl
            ld [hl], b
            jr .done
.back:      call bt_cmd_win
            jr .l
.run:       call bt_commands.slot
            ld [hl], $20
.done:      ld a, [bt_cm]
            call bt_step_back
            and a
            ret
; the command hand: rows 13-16 at x 0, Run beside Fight at x 35
bt_cmd_hand:                                ; (the hand's fingertip 1 px before the text,
            ld a, [bt_ccur]                 ;   its finger at the text row's middle: x = text
            cp 4                            ;   - 17, y = 8 row; cut off at the left edge)
            ld b, 12 - 17
            ld c, 13 * 8
            jr z, .r
            add a, 13
            add a, a
            add a, a
            add a, a
            ld c, a
            jr bt_hand
.r:         ld b, 50 - 17
            jr bt_hand
; FF1's hand cursor (sprite tiles $F0-$F3) at (B, C): OAM 0-3
bt_hand:    ld hl, cur_tbl
            ld de, oam_buf
            ld a, c
            add a, 16
            ld c, a
            ld a, b
            add a, 8
            ld b, a
            call .one
            ld a, c
            add a, 8
            ld c, a
            call .one
            ld a, b
            add a, 8
            ld b, a
            ld a, c
            sub 8
            ld c, a
            call .one
            ld a, c
            add a, 8
            ld c, a
.one:       ld a, c
            ld [de], a
            inc de
            ld a, b
            ld [de], a
            inc de
            ld a, [hl+]
            add a, BT_CUR
            ld [de], a
            inc de
            ld a, [hl+]
            and 3
            ld [de], a
            inc de
            ret
bt_hand_off:
            xor a
            ld hl, oam_buf
            ld b, 16
.c:         ld [hl+], a
            dec b
            jr nz, .c
            ret

; the command window: Fight / Magic / Medicine / Items, Run beside Fight
bt_cmd_win: ld a, 0
            ld hl, bt_s_cmd
            jp bt_left_text
; the enemy names again in the left window
bt_names_win:
            call bt_hand_off
            ld a, 0
            ld [bt_t + 12], a
            call bt_left_clear
            jp bt_names
; the left window cleared (frame, empty inside)
bt_left_clear:
            ld bc, $000C
            ld de, $0906
            call bt_win
            jp bt_upd
; the left window's text: HL = lines ($0A between; a $09 before Run moves it to x 50)
bt_left_text:
            push hl
            call bt_left_clear
            pop hl
            xor a
            ld [bt_t + 12], a
.row:       push hl
            ld b, 7
            call vwf_clr
            pop hl
            ld a, 4                         ; (4 px in: room for the hand)
            ld [vw_x], a
.c:         ld a, [hl+]
            and a
            jr z, .end
            cp $0A
            jr z, .nl
            cp $09
            jr nz, .g
            ld a, 42
            ld [vw_x], a
            jr .c
.g:         push hl
            call vwf_ch
            pop hl
            jr .c
.nl:        push hl
            call .put
            pop hl
            jr .row
.end:       call .put
            jp bt_upd
.put:       ld a, [bt_t + 12]
            cp 4
            ret nc
            ld c, a
            add a, a
            add a, a
            add a, a
            sub c
            add a, BT_TEXT
            push af
            ld b, 7
            call vwf_out
            pop af
            ld e, a
            ld a, [bt_t + 12]
            add a, 13
            ld c, a
            ld b, 1
            call cell_addr
            ld b, 7
.cc:        ld a, e
            ld [hl], a
            inc e
            inc h
            inc h
            inc h
            ld [hl], 3
            dec h
            dec h
            dec h
            inc hl
            dec b
            jr nz, .cc
            ld hl, bt_t + 12
            inc [hl]
            ret
bt_s_cmd:   db "Fight", $09, "Run", $0A, "Magic", $0A, "Medicine", $0A, "Items", 0

; ---- an enemy target, chosen freely: the hand starts on the first living enemy; a direction
; moves it to the nearest living enemy that way (distance that way + twice the distance
; across, from the enemies' middles), wrapping round to the far side when none is that way.
; A = slot, C set on B
bt_target_enemy:
            ld hl, bt_lastt                 ; (the member's last target, while it lives)
            call bt_memp
            ld a, [hl]
            cp 9
            jr nc, .ff
            call bt_ealive
            jr z, .ff
            ld [bt_tcur], a
            jr .l
.ff:        ld a, $FF
            ld [bt_tcur], a
            ld b, 10
.f:         inc a                           ; the first living enemy
            cp 9
            jr nc, .l
            call bt_ealive
            jr z, .f
            ld [bt_tcur], a
.l:         ld a, [bt_tcur]                 ; the hand left of the enemy, at its middle row
            call bt_epos
            ld a, b
            add a, a
            add a, a
            add a, a
            sub 17
            ld b, a
            ld a, e
            add a, a
            add a, a                        ; (size / 2 rows down)
            ld d, a
            ld a, c
            add a, a
            add a, a
            add a, a
            add a, d
            sub 4
            ld c, a
            call bt_hand
            call bt_frame
            ldh a, [pad_new]
            bit 1, a
            jr nz, .b
            bit 0, a
            jr nz, .a
            and $F0
            jr z, .l
            call bt_tdir
            jr .l
.a:         call bt_hand_off
            ld hl, bt_lastt
            call bt_memp
            ld a, [bt_tcur]
            ld [hl], a
            and a
            ret
.b:         call bt_hand_off
            scf
            ret
; HL += the member choosing (bt_cm)
bt_memp:    push af                         ; (A and the flags kept)
            ld a, [bt_cm]
            add a, l
            ld l, a
            ld a, h
            adc a, 0
            ld h, a
            pop af
            ret
; enemy A's middle (in half cells): D = x, E = y
bt_ectr:    call bt_epos
            ld a, b
            add a, a
            add a, e
            ld d, a
            ld a, c
            add a, a
            add a, e
            ld e, a
            ret
; the hand moved in direction A (pad bits: right $10, left $20, up $40, down $80)
bt_tdir:    ld [bt_td], a
            ld a, [bt_tcur]
            call bt_ectr
            ld a, d
            ld [bt_tcx], a
            ld a, e
            ld [bt_tcy], a
            xor a
            ld [bt_tps], a
.pass:      ld a, $FF
            ld [bt_tbs], a                  ; the best score, its enemy
            ld [bt_tbj], a
            xor a
.j:         ld [bt_tj], a
            ld hl, bt_tcur
            cp [hl]
            jr z, .nx
            call bt_ealive
            jr z, .nx
            call bt_ectr
            ld a, d                         ; D = dx, E = dy (signed)
            ld hl, bt_tcx
            sub [hl]
            ld d, a
            ld a, e
            ld hl, bt_tcy
            sub [hl]
            ld e, a
            ld a, [bt_td]                   ; B = the distance that way, C = across
            ld b, d
            ld c, e
            bit 4, a
            jr nz, .w
            ld a, d
            cpl
            inc a
            ld b, a
            ld a, [bt_td]
            bit 5, a
            jr nz, .w
            ld b, e
            ld c, d
            bit 7, a
            jr nz, .w
            ld a, e
            cpl
            inc a
            ld b, a
.w:         ld a, [bt_tps]                  ; (wrapping round: every enemy counts, the
            and a                           ;   farthest the other way first)
            jr z, .p0
            ld a, b
            add a, 64
            ld b, a
            jr .ok
.p0:        ld a, b                         ; (that way only)
            dec a
            bit 7, a
            jr nz, .nx
.ok:        ld a, c
            bit 7, a
            jr z, .ps
            cpl
            inc a
.ps:        add a, a
            add a, b
            ld hl, bt_tbs
            cp [hl]
            jr nc, .nx
            ld [hl], a
            ld a, [bt_tj]
            ld [bt_tbj], a
.nx:        ld a, [bt_tj]
            inc a
            cp 9
            jr c, .j
            ld a, [bt_tbj]
            cp $FF
            jr nz, .fd
            ld a, [bt_tps]
            and a
            ret nz                          ; (no other enemy)
            inc a
            ld [bt_tps], a
            jr .pass
.fd:        ld [bt_tcur], a
            ret
; enemy A present and alive: NZ (A kept)
bt_ealive:  push hl
            push de
            push af
            ld e, a
            ld d, 0
            ld hl, bt_eid
            add hl, de
            ld a, [hl]
            cp $FF
            jr z, .no
            pop af
            push af
            call bt_erec
            ld de, E_AIL
            add hl, de
            ld a, [hl]
            and AIL_DEAD | AIL_STONE
            jr nz, .no
            pop af
            pop de
            pop hl
            push bc
            ld b, a
            or 1
            ld a, b
            pop bc
            ret
.no:        pop af
            pop de
            pop hl
            cp a
            ret

; ---- a round (FF1 DoBattleRound): the turn order shuffled, every entity's turn
bt_round:   ld hl, bt_order                 ; 0-8 enemies, $80-$83 the members
            xor a
.i:         ld [hl+], a
            inc a
            cp 9
            jr c, .i
            ld a, $80
.j:         ld [hl+], a
            inc a
            cp $84
            jr c, .j
            ld a, 16                        ; 16 random swaps (FF1)
            ld [bt_t + 2], a
.sw:        xor a
            ld b, 12
            call bt_randab
            push af
            xor a
            ld b, 12
            call bt_randab
            ld e, a
            ld d, 0
            ld hl, bt_order
            add hl, de
            pop af
            ld e, a
            push hl
            ld hl, bt_order
            add hl, de
            pop de
            ld a, [de]
            ld b, [hl]
            ld [hl], a
            ld a, b
            ld [de], a
            ld hl, bt_t + 2
            dec [hl]
            jr nz, .sw
            xor a
            ld [bt_turn], a
.t:         ld a, [bt_turn]
            ld e, a
            ld d, 0
            ld hl, bt_order
            add hl, de
            ld a, [hl]
            bit 7, a
            jr nz, .pl
            ld b, a                         ; an enemy: present, the party not striking first
            call bt_ealive
            jr z, .nx
            ld a, [bt_first]
            and a
            jr nz, .nx
            ld a, b
            call bt_enemy_turn
            jr .chk
.pl:        and 3
            call bt_player_turn
.chk:       call bt_party_upd               ; (FF1: the members' natural poses again)
            call bt_check_end
            ld a, [bt_result]
            and a
            ret nz
.nx:        ld hl, bt_turn
            inc [hl]
            ld a, [hl]
            cp 13
            jr c, .t
            xor a
            ld [bt_first], a
            call bt_round_end               ; poison etc. (FF1 ApplyEndOfRoundEffects)
            call bt_party_upd
            jp bt_check_end

; the battle over? all enemies gone: 1 won; the party all dead / stone: 2 lost
bt_check_end:
            ld a, [bt_result]
            and a
            ret nz
            ld c, 0
.e:         ld a, c
            call bt_ealive
            jr nz, .party
            inc c
            ld a, c
            cp 9
            jr c, .e
            ld a, 1
            ld [bt_result], a
            ret
.party:     xor a
.p:         push af
            call ch_rec
            inc hl
            ld a, [hl]
            and AIL_DEAD | AIL_STONE
            jr z, .alive
            pop af
            inc a
            cp 4
            jr c, .p
            ld a, 2
            ld [bt_result], a
            ret
.alive:     pop af
            ret

; end of the round: poison takes 2 HP, at 0 the member dies (FF1 ApplyPoisonToPlayer)
bt_round_end:
            xor a
.m:         push af
            call ch_rec
            inc hl
            ld a, [hl]
            and AIL_DEAD | AIL_STONE
            jr nz, .n
            ld a, [hl]
            and AIL_POISON
            jr z, .n
            ld a, l
            add a, CH_HP - 1
            ld l, a
            ld a, [hl]
            sub 2
            ld [hl+], a
            ld a, [hl]
            sbc a, 0
            ld [hl-], a
            jr c, .dead
            or [hl]
            jr nz, .ok
.dead:      xor a
            ld [hl+], a
            ld [hl], a
            ld a, l
            sub CH_HP
            ld l, a
            ld [hl], AIL_DEAD
.ok:        pop af
            push af
            call bt_pline
.n:         pop af
            inc a
            cp 4
            jr c, .m
            ret

; ---- a member's turn (FF1 Battle_DoPlayerTurn)
bt_player_turn:
            ld [bt_who], a
            add a, a
            add a, a
            ld e, a
            ld d, 0
            ld hl, bt_cmd
            add hl, de
            ld a, [hl]
            bit 2, a
            jr nz, .fight
            bit 5, a
            jp nz, bt_try_run
            bit 6, a
            jp nz, bt_pl_magic
            bit 3, a
            jp nz, bt_pl_drink
            bit 4, a
            jp nz, bt_pl_item
            ld a, [bt_who]                  ; no command: asleep / paralysed?
            call ch_rec
            inc hl
            ld a, [hl]
            bit 5, a
            jp nz, bt_try_wake
            bit 4, a
            jp nz, bt_try_unstun
            ret
.fight:     inc hl
            inc hl
            ld a, [hl]
            jp bt_pl_attack

bt_pl_attack:
            ld [bt_tgt], a
            ld a, [bt_who]                  ; attacker: the member's block and record
            call bt_cblk
            ld h, d
            ld l, e
            ld a, [hl+]
            ld [ak_hit], a                  ; hit rate
            inc hl
            inc hl
            inc hl
            ld a, [hl+]
            ld [ak_str], a                  ; damage
            inc hl
            ld a, [hl+]
            ld [ak_mult], a
            ld a, [hl+]
            ld [ak_hits], a
            ld a, [hl+]
            ld [ak_cat], a
            ld a, [hl+]
            ld [ak_elem], a
            ld a, [hl+]
            ld [ak_crit], a
            xor a
            ld [ak_ail], a
            ld a, [bt_who]
            call ch_rec
            inc hl
            ld a, [hl]
            ld [ak_ails], a
            ld a, [bt_tgt]                  ; defender: the enemy's record
            call bt_erec
            push hl
            ld de, E_CAT
            add hl, de
            ld a, [hl]
            ld [df_cat], a
            pop hl
            push hl
            ld de, E_WEAK
            add hl, de
            ld a, [hl]
            ld [df_weak], a
            pop hl
            push hl
            ld de, E_EVADE
            add hl, de
            ld a, [hl+]
            ld [df_evade], a
            ld a, [hl]
            ld [df_absorb], a
            pop hl
            push hl
            ld de, E_MAGDEF
            add hl, de
            ld a, [hl]
            ld [df_magdef], a
            pop hl
            push hl
            ld de, E_RESIST
            add hl, de
            ld a, [hl+]
            ld [df_resist], a
            ld a, [hl+]
            ld [df_hp], a
            ld a, [hl+]
            ld [df_hp + 1], a
            ld a, [hl]
            ld [df_ails], a
            xor a
            ld [df_player], a
            ld a, [bt_rngs]                 ; the result worked out first (owner, 2026-11-23:
            ld [bt_sv], a                   ;   the remake's timing: the hit count shows as
            ld a, [df_hp]                   ;   the member darts forward, the number and the
            ld [bt_sv + 1], a               ;   text together after the swing); then the same
            ld a, [df_hp + 1]               ;   again for real
            ld [bt_sv + 2], a
            ld a, [df_ails]
            ld [bt_sv + 3], a
            xor a
            ld [mt_conn], a                 ; (a fallen target: no hits counted)
            inc a
            ld [bt_defer], a
            call bt_phys
            xor a
            ld [bt_defer], a
            ld a, [bt_sv]
            ld [bt_rngs], a
            ld a, [bt_sv + 1]
            ld [df_hp], a
            ld a, [bt_sv + 2]
            ld [df_hp + 1], a
            ld a, [bt_sv + 3]
            ld [df_ails], a
            ld a, [bt_who]                  ; FF1 WalkForwardAndStrike with the weapon's
            call bt_cblk                    ;   graphic and palette (none: not drawn)
            ld hl, C_WGFX
            add hl, de
            ld a, [hl+]
            ld [bt_ag], a
            ld a, [hl]
            ld [bt_ac], a
            ld a, [bt_who]
            call bt_strike
            ld a, [df_ails]                 ; FF1 DoExplosionEffect: the "cha" sound and the
            and AIL_DEAD | AIL_STONE        ;   explosions (not on an enemy already down)
            jr nz, .ns
            ld a, SFX_HIT
            ld [sfx_req], a
            ld a, [bt_tgt]
            call bt_explode
.ns:        ld a, [bt_who]                  ; message: member -> enemy, then the result
            call bt_msg_pl
            ld a, [bt_tgt]
            call bt_msg_to_en
            call bt_phys
            pop hl                          ; back into the enemy's record
            ld de, E_HP
            add hl, de
            ld a, [df_hp]
            ld [hl+], a
            ld a, [df_hp + 1]
            ld [hl+], a
            ld a, [df_ails]
            ld [hl], a
            and AIL_DEAD | AIL_STONE
            jr z, .alive
            ld a, [bt_sv + 3]               ; defeated now (not down already): off the screen
            and AIL_DEAD | AIL_STONE
            ld a, [bt_tgt]
            call z, bt_erase_enemy
.alive:
            ld a, [bt_who]                  ; then the member back in line
            jp bt_sback

bt_en_attack:                               ; enemy [bt_who] -> member A
            ld [bt_tgt], a
            ld a, [bt_who]
            call bt_erec
            push hl
            ld de, E_NUMHITS
            add hl, de
            ld a, [hl+]
            ld [ak_hits], a
            ld a, [hl+]
            ld [ak_hit], a
            ld a, [hl+]
            ld [ak_str], a
            ld a, [hl+]
            ld [ak_crit], a
            inc hl
            ld a, [hl+]
            ld [ak_ail], a
            ld a, [hl+]
            ld [ak_cat], a
            inc hl
            ld a, [hl+]
            ld [ak_elem], a                 ; (FF1: the enemy's element is its weakness byte)
            inc hl
            inc hl
            inc hl
            ld a, [hl+]
            ld [ak_ails], a
            ld a, [hl]
            ld [ak_mult], a
            ld a, [bt_tgt]                  ; defender: the member
            call bt_cblk
            ld h, d
            ld l, e
            inc hl
            ld a, [hl+]
            ld [df_magdef], a
            ld a, [hl+]
            ld [df_evade], a
            ld a, [hl+]
            ld [df_absorb], a
            inc hl
            ld a, [hl]
            ld [df_resist], a
            xor a
            ld [df_cat], a
            ld [df_weak], a
            ld a, [bt_tgt]
            call ch_rec
            inc hl
            ld a, [hl]
            ld [df_ails], a
            ld a, l
            add a, CH_HP - 1
            ld l, a
            ld a, [hl+]
            ld [df_hp], a
            ld a, [hl]
            ld [df_hp + 1], a
            ld a, 1
            ld [df_player], a
            ld a, [bt_who]
            call bt_msg_en
            ld a, [bt_tgt]
            call bt_msg_to_pl
            call bt_msg_head
            call bt_flush
            ld a, SFX_ENEMYHIT              ; FF1: the "boom bash" sound, the screen shakes
            ld [sfx_req], a
            call bt_shake
            call bt_phys
            pop hl
            ld de, E_AIL
            add hl, de
            ld a, [ak_ails]
            ld [hl], a
            ld a, [bt_tgt]                  ; the member's HP / ailments
            call ch_rec
            inc hl
            ld a, [df_ails]
            ld [hl], a
            ld a, l
            add a, CH_HP - 1
            ld l, a
            ld a, [df_hp]
            ld [hl+], a
            ld a, [df_hp + 1]
            ld [hl], a
            ld a, [bt_tgt]
            jp bt_pline

; FF1 DoPhysicalAttack: hit chance 168 (+/- 40 for darkness), category / element bonus
; (+40, damage +4), a helpless defender (damage + 1/4) or hit rate - evade; per hit: random
; 0-200 (200 always misses), damage random(D .. 2 D), - absorb (at least 1) on a hit,
; critical: + D more; ailments from enemy attacks on members
bt_phys:    ld a, 168
            ld [mt_hitc], a
            xor a
            ld [mt_hitc + 1], a
            ld a, [ak_str]
            ld [mt_base], a
            ld a, [ak_ails]
            and AIL_DARK
            jr z, .d1
            ld a, [mt_hitc]
            sub 40
            ld [mt_hitc], a
.d1:        ld a, [df_ails]
            and AIL_DARK
            jr z, .d2
            ld a, [mt_hitc]
            add a, 40
            ld [mt_hitc], a
.d2:        ld a, [ak_cat]
            ld b, a
            ld a, [df_cat]
            and b
            ld c, a
            ld a, [ak_elem]
            ld b, a
            ld a, [df_weak]
            and b
            or c
            jr z, .nb
            ld hl, mt_hitc
            ld a, [hl]
            add a, 40
            jr nc, .c1
            ld a, $FF
.c1:        ld [hl], a
            ld a, [mt_base]
            add a, 4
            jr nc, .c2
            ld a, $FF
.c2:        ld [mt_base], a
.nb:        ld a, [df_ails]
            and AIL_STUN | AIL_SLEEP
            jr z, .mob
            ld a, [mt_base]                 ; helpless: damage + damage / 4
            ld b, a
            srl a
            srl a
            add a, b
            jr nc, .c3
            ld a, $FF
.c3:        ld [mt_base], a
            jr .hc
.mob:       ld a, [ak_hit]                  ; + hit rate (at most 255), - evade (at least 0)
            ld b, a
            ld a, [mt_hitc]
            add a, b
            jr nc, .c4
            ld a, $FF
.c4:        ld b, a
            ld a, [df_evade]
            ld c, a
            ld a, b
            sub c
            jr nc, .c5
            xor a
.c5:        ld [mt_hitc], a
.hc:        ld a, [mt_hitc]                 ; at least 1; critical at most the hit chance
            and a
            jr nz, .h1
            inc a
            ld [mt_hitc], a
.h1:        ld b, a
            ld a, [ak_crit]
            cp b
            jr c, .h2
            ld a, b
.h2:        ld [mt_crit], a
            ld a, [ak_hits]                 ; hits = hits x multiplier (at least 1)
            ld b, a
            ld a, [ak_mult]
            ld c, a
            xor a
            inc c
.mu:        dec c
            jr z, .mx
            add a, b
            jr .mu
.mx:        and a
            jr nz, .h3
            inc a
.h3:        ld [mt_hits], a
            ld a, [df_ails]                 ; a dead / stone defender: no effect
            and AIL_DEAD | AIL_STONE
            jr z, .go
            ld a, M_NOEFFECT
            jp bt_msg_end1
.go:        xor a
            ld [mt_conn], a
            ld [mt_crits], a
            ld [mt_total], a
            ld [mt_total + 1], a
            ld a, [mt_base]
            ld [mt_d], a
.hit:       xor a                           ; one hit
            ld [mt_dmg], a
            ld [mt_dmg + 1], a
            xor a
            ld b, 200
            call bt_randab
            ld [mt_rand], a
            cp 200
            jp z, .next
            ld a, [mt_d]                    ; damage random(D .. 2D)
            ld b, a
            xor a
            call bt_randab
            ld b, a
            ld a, [mt_d]
            add a, b
            jr nc, .c6
            ld a, $FF
.c6:        ld [mt_base], a
            ld a, [mt_rand]
            ld b, a
            ld a, [mt_hitc]
            cp b
            jr c, .miss
            ld a, [df_absorb]               ; a hit: - absorb, at least 1
            ld b, a
            ld a, [mt_base]
            sub b
            jr z, .z1
            jr nc, .z2
.z1:        ld a, 1
.z2:        ld [mt_dmg], a
            ld hl, mt_conn
            inc [hl]
.miss:      ld a, [mt_rand]                 ; critical
            ld b, a
            ld a, [mt_crit]
            cp b
            jr c, .nc
            ld a, [mt_base]
            ld b, a
            ld a, [mt_dmg]
            add a, b
            ld [mt_dmg], a
            ld a, [mt_dmg + 1]
            adc a, 0
            ld [mt_dmg + 1], a
            ld hl, mt_crits
            inc [hl]
.nc:        ld a, [mt_dmg]                  ; total += this hit
            ld b, a
            ld a, [mt_total]
            add a, b
            ld [mt_total], a
            ld a, [mt_dmg + 1]
            ld b, a
            ld a, [mt_total + 1]
            adc a, b
            ld [mt_total + 1], a
            ld a, [df_player]               ; ailments: only on members (FF1)
            and a
            jr z, .next
            ld a, [ak_ail]
            and a
            jr z, .next
            ld a, [mt_conn]
            and a
            jr z, .next
            ld a, [df_resist]               ; chance 100 (0 if resisted) - magic defence
            ld b, a
            ld a, [ak_elem]
            and b
            ld a, 100
            jr z, .r1
            xor a
.r1:        ld b, a
            ld a, [df_magdef]
            ld c, a
            ld a, b
            sub c
            jr z, .r2
            jr nc, .r3
.r2:        ld a, 1
.r3:        ld [mt_ailc], a
            xor a
            ld b, 200
            call bt_randab
            cp 200
            jr z, .next
            ld b, a
            ld a, [mt_ailc]
            cp b
            jr c, .next
            ld a, [df_ails]                 ; newly inflicted: the message
            cpl
            ld b, a
            ld a, [ak_ail]
            and b
            call bt_ail_msgs
            ld a, [ak_ail]
            ld b, a
            ld a, [df_ails]
            or b
            ld [df_ails], a
.next:      ld hl, mt_hits
            dec [hl]
            jp nz, .hit
            ld a, [mt_conn]                 ; messages: hits (2+), critical, damage / miss
            cp 2
            jr c, .m1
            call nf_a
            ld a, M_HITS
            call bt_msg_num
.m1:        ld a, [mt_crits]
            and a
            jr z, .m2
            ld a, M_CRIT
            call bt_msg_line
.m2:        ld a, [mt_total]
            ld b, a
            ld a, [mt_total + 1]
            or b
            jr nz, .dm
            call bt_dmiss                   ; ("MISS!" over the target)
            ld a, M_MISS
            call bt_msg_line
            jp bt_msg_end
.dm:        ld a, [mt_total]
            ld [nf_val], a
            ld a, [mt_total + 1]
            ld [nf_val + 1], a
            xor a
            ld [nf_val + 2], a
            ld a, M_DMG
            call bt_msg_num
            ld hl, mt_total                 ; (the number over the target)
            call bt_dnum_w
            call bt_hitlab                  ; (the hit count over the attacker: btl5.s)
            ld a, [mt_total]                ; HP - total (at least 0)
            ld b, a
            ld a, [df_hp]
            sub b
            ld [df_hp], a
            ld a, [mt_total + 1]
            ld b, a
            ld a, [df_hp + 1]
            sbc a, b
            ld [df_hp + 1], a
            jr nc, .h0
            xor a
            ld [df_hp], a
            ld [df_hp + 1], a
.h0:        ld a, [df_hp]
            ld b, a
            ld a, [df_hp + 1]
            or b
            jp nz, bt_msg_end
            ld a, AIL_DEAD                  ; slain / terminated
            ld [df_ails], a
            ld a, [df_player]
            and a
            ld a, M_SLAIN
            jr nz, .ds
            ld a, M_TERM
.ds:        call bt_msg_line
            jp bt_msg_end

; new ailments A (FF1 PrintPlayerAilmentMessageFromAttack): a line per ailment
bt_ail_msgs:
            ld hl, bt_ailtab
            ld b, 8
.l:         rlca
            jr nc, .n
            push af
            push bc
            push hl
            ld a, [hl]
            call bt_msg_line
            pop hl
            pop bc
            pop af
.n:         inc hl
            dec b
            jr nz, .l
            ret
bt_ailtab:  db $13, $07, $04, $17, $09, $14, $1A, $20   ; confused, silenced, asleep, paralysed,
                                                        ; dark, poisoned, stone, slain

; ---- an enemy's turn (FF1 Battle_DoEnemyTurn, Enemy_DoAi; spells: later)
bt_enemy_turn:
            ld [bt_who], a
            call bt_erec
            ld de, E_AIL
            add hl, de
            ld a, [hl]
            and AIL_SLEEP | AIL_STUN
            jr z, .act
            push hl
            ld a, [bt_who]
            call bt_msg_en
            pop hl
            ld a, [hl]
            and AIL_SLEEP
            jr nz, .sl
            call bt_rng                     ; paralysed: 25 in 256 recover
            cp 25
            jr nc, .pa
            res 4, [hl]
            ld a, M_CURED
            jp bt_msg_end1
.pa:        ld a, M_PARA
            jp bt_msg_end1
.sl:        push hl                         ; asleep: random(0 .. 80) < max HP (low) wakes
            xor a
            ld b, $50
            call bt_randab
            ld c, a
            pop hl
            push hl
            ld de, E_HPMAX - E_AIL
            add hl, de
            ld a, [hl+]
            sub c
            ld a, [hl]
            sbc a, 0
            pop hl
            jr c, .zz
            res 5, [hl]
            ld a, M_WOKE
            jp bt_msg_end1
.zz:        ld a, M_ASLEEP
            jp bt_msg_end1
.act:       bit 7, [hl]                     ; confused: 1 in 4 recover, else it acts on its own
            jr z, .mor
            call bt_rng
            cp $40
            jr nc, .cf
            res 7, [hl]
            ld a, [bt_who]
            call bt_msg_en
            ld a, M_CURED
            jp bt_msg_end1
.cf:        call bt_eflash                  ; (it flashes: btl5.s)
            ld a, MG_FIRE                   ; confused: Fire on a random enemy (FF1)
            call bt_mload
            ld a, [bt_who]
            ld [mg_caster], a
            call bt_rnd_enemy
            jp bt_cast_en
.mor:       ld a, [bt_who]                  ; morale: morale - 2 x leader level + random(0..50)
            call bt_erec                    ;   < 80: runs away
            ld de, E_MORALE
            add hl, de
            ld a, [ch_stats + CH_LEVEL]
            add a, a
            ld b, a
            ld a, [hl]
            sub b
            jr c, .run
            ld [bt_t], a
            xor a
            ld b, 50
            call bt_randab
            ld b, a
            ld a, [bt_t]
            add a, b
            jr c, .ai
            cp 80
            jr nc, .ai
.run:       ld a, [bt_who]
            call bt_msg_en
            ld a, M_RANAWAY
            call bt_msg_end1
            ld a, [bt_who]                  ; gone (no experience / gold for it)
            call bt_erec
            xor a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl], a
            ld de, E_AIL - 3
            add hl, de
            ld [hl], AIL_DEAD
            ld a, [bt_who]
            call bt_erase_enemy
            ld a, [bt_who]
            ld e, a
            ld d, 0
            ld hl, bt_eid
            add hl, de
            ld [hl], $FF
            ret
.ai:        call bt_eflash                  ; (it flashes: btl5.s)
            jp bt_en_ai

; FF1 GetRandomPlayerTarget: slot 0 1/2, 1 1/4, 2 / 3 1/8; again if dead / stone
bt_rnd_member:
            call bt_rng
            ld b, 0
            cp $80
            jr nc, .s
            inc b
            cp $40
            jr nc, .s
            inc b
            cp $20
            jr nc, .s
            inc b
.s:         ld a, b
            push af
            call ch_rec
            inc hl
            ld a, [hl]
            and AIL_DEAD | AIL_STONE
            jr nz, .again
            pop af
            ret
.again:     pop af
            jr bt_rnd_member

; an enemy off the screen (its cells empty)
bt_erase_enemy:
            push af                         ; (owner, 2026-11-23: a proper death; bosses a
            ld b, a                         ;   special one: loc.s ed_dissolve)
            ld a, [bt_type]
            cp 4
            jr nc, .x                       ; (Chaos: its own ending)
            cp 3
            jr c, .n
            call fl_fiend                   ; a fiend: its flash first
            ld bc, $0302
            ld e, 8
            jr .go
.n:         ld a, b
            call bt_epos
.go:        ld hl, fl_b
            ld a, b
            ld [hl+], a
            ld a, c
            ld [hl+], a
            ld [hl], e
            ld a, F3_BANK
            ld hl, ed_dissolve
            call bank_call
.x:         pop af
            jp bt_erase_rows                ; (what is left cleared row by row: btl4.s)
            ld [bt_t + 4], a
            call bt_epos
            ld a, e
            ld [bt_t + 5], a
.r:         push bc
            call cell_addr
            ld d, e
.c:         ld [hl], 0
            inc h
            inc h
            inc h
            ld [hl], 0
            dec h
            dec h
            dec h
            inc hl
            dec d
            jr nz, .c
            pop bc
            inc c
            ld hl, bt_t + 5
            dec [hl]
            jr nz, .r
            jp scr_upd

; ---- messages (approved style A): row 1 attacker -> target, rows 2-4 the result lines;
; the full-width window (0,12,20,6) over the left and party windows while it shows
bt_msg_pl:  push af                         ; row 1 begins with member A's name
            call bt_msg_new
            pop af
            call ch_rec
            inc hl
            inc hl
            ld de, bt_line
            ld b, 4
.n:         ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .n
            ld a, l
            add a, CH_NAME2 - 6
            ld l, a
            ld a, [hl+]
            ld [de], a
            inc de
            ld a, [hl]
            ld [de], a
            inc de
            ld a, e
            ld [bt_lp], a
            ret
bt_msg_en:  push af                         ; row 1 begins with enemy A's name
            call bt_msg_new
            pop af
            call bt_ename
            ld hl, bt_sbuf
            ld de, bt_line
.c:         ld a, [hl+]
            and a
            jr z, .e
            ld [de], a
            inc de
            jr .c
.e:         ld a, e
            ld [bt_lp], a
            ret
bt_msg_to_pl:                               ; " -> member A"
            push af
            call bt_arrow
            pop af
            call ch_rec
            inc hl
            inc hl
            ld a, [bt_lp]
            ld e, a
            ld d, high(bt_line)
            ld b, 4
.n:         ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .n
            ld a, l
            add a, CH_NAME2 - 6
            ld l, a
            ld a, [hl+]
            ld [de], a
            inc de
            ld a, [hl]
            ld [de], a
            inc de
            ld a, e
            ld [bt_lp], a
            ret
bt_msg_to_en:                               ; " -> enemy A"
            push af
            call bt_arrow
            pop af
            call bt_ename
            ld a, [bt_lp]
            ld e, a
            ld d, high(bt_line)
            ld hl, bt_sbuf
.c:         ld a, [hl+]
            and a
            jr z, .e
            ld [de], a
            inc de
            jr .c
.e:         ld a, e
            ld [bt_lp], a
            ret
bt_arrow:   ld a, [bt_lp]
            ld l, a
            ld h, high(bt_line)
            ld [hl], $20
            inc hl
            ld [hl], $8B
            inc hl
            ld [hl], $20
            inc hl
            ld a, l
            ld [bt_lp], a
            ret
; enemy (slot) A's name -> bt_sbuf
bt_ename:   ld e, a
            ld d, 0
            ld hl, bt_eid
            add hl, de
            ld a, [hl]
            cp $FF
            jr nz, .ok
            push de                         ; (gone: the record's id)
            ld a, e
            call bt_erec
            ld de, E_ID
            add hl, de
            ld a, [hl]
            pop de
.ok:        ld l, a
            ld h, 0
            add hl, hl
            ld de, B_NAMES
            add hl, de
            ld de, bt_sbuf
            ld bc, 2
            ld a, BTL_DATA
            call far_copy
            ld a, [bt_sbuf]
            ld l, a
            ld a, [bt_sbuf + 1]
            ld h, a
            ld de, bt_sbuf
            ld bc, 20
            ld a, BTL_DATA
            jp far_copy
; a new message: the line buffer and rows cleared
bt_msg_new: xor a
            ld [bt_rows], a
            ld hl, bt_line
            ld b, 0
.c:         ld [hl+], a
            dec b
            jr nz, .c
            ld a, low(bt_line)
            ld [bt_lp], a
            ret
; row 1 done (the attacker / target line) -> the message window shown
bt_msg_head:
            ld a, [bt_rows]
            and a
            ret nz
            ld a, [bt_lp]
            ld l, a
            ld h, high(bt_line)
            ld [hl], 0
            ld hl, bt_line
            call bt_msg_row
            ret
; result line: FF1 message A (text entry A - 1), indented
bt_msg_line:
            push af
            call bt_msg_head
            pop af
            call bt_mtext
            ld hl, bt_sbuf
            jp bt_msg_row
; "N text" (nf_val, then FF1 message A)
bt_msg_num: push af
            call bt_msg_head
            call num_fmt
            ld hl, nf_dig
            ld de, bt_line
.s:         ld a, [hl]
            cp $20
            jr nz, .c
            inc hl
            jr .s
.c:         ld a, [hl+]
            ld [de], a
            inc de
            ld a, l
            cp low(nf_dig + 6)
            jr nz, .c
            pop af
            push de
            call bt_mtext
            pop de
            ld hl, bt_sbuf
.t:         ld a, [hl+]
            ld [de], a
            inc de
            and a
            jr nz, .t
            ld hl, bt_line
            jp bt_msg_row
; FF1 battle message A -> bt_sbuf
bt_mtext:   dec a
            ld l, a
            ld h, 0
            add hl, hl
            ld de, B_MSGS
            add hl, de
            ld de, bt_sbuf
            ld bc, 2
            ld a, BTL_DATA
            call far_copy
            ld a, [bt_sbuf]
            ld l, a
            ld a, [bt_sbuf + 1]
            ld h, a
            ld de, bt_sbuf
            ld bc, 39
            ld a, BTL_DATA
            call far_copy
            xor a
            ld [bt_sbuf + 39], a
            ret
; a row of the message window: string HL (row 1 at x 0, later rows indented by 8)
bt_msg_row: ld a, [bt_defer]                  ; (the result worked out first: nothing shown)
            and a
            ret nz
            ld a, [bt_rows]
            cp 4
            ret nc
            push hl
            and a
            call z, bt_msg_win
            ld b, 18
            call vwf_clr
            pop hl
            ld a, [bt_rows]
            and a
            ld a, 0
            jr z, .x
            ld a, 8
.x:         call vwf_str
            ld a, [bt_rows]                 ; tiles BT_TEXT + 18 row
            ld c, a
            add a, a
            add a, a
            add a, a
            add a, c
            add a, a
            add a, BT_TEXT
            push af
            ld b, 18
            call vwf_out
            pop af
            ld e, a
            ld a, [bt_rows]
            add a, 13
            ld c, a
            ld b, 1
            call cell_addr
            ld b, 18
.c:         ld a, e
            ld [hl], a
            inc e
            inc h
            inc h
            inc h
            ld [hl], 3
            dec h
            dec h
            dec h
            inc hl
            dec b
            jr nz, .c
            ld a, [bt_rows]
            add a, 13
            call bt_upd_row
            ld hl, bt_rows
            inc [hl]
            ret
bt_msg_win: ld a, [bt_msgon]                 ; (the rows below saved first)
            and a
            jr nz, .w
            ld a, 1
            ld [bt_msgon], a
            ld hl, smap + 12 * 32
            ld de, bt_save
            ld bc, 6 * 32
            call memcpy
            ld hl, sattr + 12 * 32
            ld de, bt_save + 6 * 32
            ld bc, 6 * 32
            call memcpy
.w:         ld bc, $000C
            ld de, $1406
            call bt_win
            jp bt_upd                       ; (blank on screen before any text is staged)
; a one-line result and the end
bt_msg_end1:
            call bt_msg_line
; the message shown for a while (A skips), then the windows below again
bt_msg_end: ld a, [bt_defer]
            and a
            ret nz
            call bt_msg_head
            call bt_flush
            ld a, [respond]                 ; FF1 RespondDelay: the title's message speed
            add a, low(B_RESPOND)
            ld l, a
            ld h, high(B_RESPOND)
            ld a, BTL_DATA
            ld [fc_bank], a
            call far_byte
            ld b, a
.w:         push bc
            call bt_frame
            pop bc
            ldh a, [pad_new]
            and 1
            jr nz, .x
            dec b
            jr nz, .w
.x:         call bt_dnum_off
            ld a, [bt_msgon]                ; the rows below back (the party window's tiles
            and a                           ;   are current), the names drawn again
            ret z
            xor a
            ld [bt_msgon], a
            ld hl, bt_save
            ld de, smap + 12 * 32
            ld bc, 6 * 32
            call memcpy
            ld hl, bt_save + 6 * 32
            ld de, sattr + 12 * 32
            ld bc, 6 * 32
            call memcpy
            call bt_upd
            jp bt_names_win
; a message alone (A = FF1 message), no attacker line
bt_say:     push af
            call bt_msg_new
            pop af
            call bt_mtext
            ld hl, bt_sbuf
            call bt_msg_row
            jp bt_msg_end

; ---- the end
; ailments back to the outside values (dead 1 > stone 2 > poison 3; FF1 ConvertIBAilmentToOB)
bt_ch_exit: xor a
.m:         push af
            call ch_rec
            inc hl
            ld a, [hl]
            ld b, 1
            bit 0, a
            jr nz, .s
            inc b
            bit 1, a
            jr nz, .s
            inc b
            bit 2, a
            jr nz, .s
            ld b, 0
.s:         ld [hl], b
            pop af
            inc a
            cp 4
            jr c, .m
            ret

; victory (FF1 EndOfBattleWrapUp): the monsters were wiped out; the experience of the defeated
; divided by the members standing (at least 1), the gold to the party
bt_victory: call bt_msg_new
            ld a, 61                        ; "The monsters " + "were wiped out"
            call bt_mtext
            ld hl, bt_sbuf
            ld de, bt_line
.c1:        ld a, [hl+]
            and a
            jr z, .c2
            ld [de], a
            inc de
            jr .c1
.c2:        push de
            ld a, 60
            call bt_mtext
            pop de
            ld hl, bt_sbuf
.c3:        ld a, [hl+]
            ld [de], a
            inc de
            and a
            jr nz, .c3
            ld hl, bt_line
            call bt_msg_row
            call bt_msg_end
            ld hl, 0                        ; sums: experience, gold (enemies defeated)
            ld de, 0
            ld c, 0
.e:         push hl
            push de
            push bc
            ld a, c
            call bt_erec
            push hl
            ld de, E_AIL
            add hl, de
            ld a, [hl]
            pop hl
            and AIL_DEAD | AIL_STONE
            jr z, .skip
            ld a, [hl+]
            ld c, a
            ld a, [hl+]
            ld b, a                         ; BC = experience
            ld a, [hl+]
            ld e, a
            ld d, [hl]                      ; DE = gold
            pop af                          ; (the loop counter)
            pop hl                          ; (gold sum)
            add hl, de
            ld d, h
            ld e, l
            pop hl                          ; (experience sum)
            add hl, bc
            ld b, a
            ld c, a
            jr .ne
.skip:      pop bc
            pop de
            pop hl
.ne:        inc c
            ld a, c
            cp 9
            jr c, .e
            push de                         ; experience / survivors
            ld b, 0
            xor a
.sv:        push af
            push hl
            call ch_rec
            inc hl
            ld a, [hl]
            pop hl
            and AIL_DEAD | AIL_STONE
            jr nz, .sd
            inc b
.sd:        pop af
            inc a
            cp 4
            jr c, .sv
            ld a, b
            and a
            jr z, .d1
            ld c, b                         ; HL / C
            ld de, 0
.dv:        ld a, l
            sub c
            ld l, a
            ld a, h
            sbc a, 0
            ld h, a
            jr c, .dd
            inc de
            jr .dv
.dd:        ld h, d
            ld l, e
.d1:        ld a, h
            or l
            jr nz, .d2
            inc l                           ; (at least 1)
.d2:        ld a, l
            ld [bt_rexp], a
            ld a, h
            ld [bt_rexp + 1], a
            pop de                          ; gold (shown in the results window)
            ld a, e
            ld [bt_rgold], a
            ld a, d
            ld [bt_rgold + 1], a
            ld b, d
            ld c, e
            call add_gold
            ld a, 1                         ; (level ups recorded for the results window)
            ld [bt_res], a
            xor a
            ld hl, res_on
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl], a
            xor a                           ; experience to everyone standing (levels: next)
.ax:        push af
            call ch_rec
            inc hl
            ld a, [hl]
            and AIL_DEAD | AIL_STONE
            jr nz, .an
            dec hl
            ld a, l
            add a, CH_EXP
            ld l, a
            ld a, [bt_rexp]
            add a, [hl]
            ld [hl+], a
            ld a, [bt_rexp + 1]
            adc a, [hl]
            ld [hl+], a
            ld a, 0
            adc a, [hl]
            ld [hl], a
            pop af
            push af
            call bt_lvchk                   ; enough for the next level: up (once, as FF1)
.an:        pop af
            inc a
            cp 4
            jr c, .ax
            jp bt_results

; member A: experience >= the table's amount for its level -> a level up
bt_lvchk:   ld [bt_lvm], a
            call ch_rec
            ld a, l
            add a, CH_LEVEL
            ld l, a
            ld a, [hl]
            cp 49
            ret nc
            ld e, a                         ; the table entry (3 bytes)
            ld d, 0
            ld h, d
            ld l, e
            add hl, hl
            add hl, de
            ld de, U_EXPTBL
            add hl, de
            ld de, bt_sbuf
            ld bc, 3
            ld a, UI_GFX
            call far_copy
            ld a, [bt_lvm]
            call ch_rec
            ld a, l
            add a, CH_EXP
            ld l, a
            ld a, [hl+]                     ; experience - needed: no borrow -> level up
            ld b, a
            ld a, [bt_sbuf]
            ld c, a
            ld a, b
            sub c
            ld a, [hl+]
            ld b, a
            ld a, [bt_sbuf + 1]
            ld c, a
            ld a, b
            sbc a, c
            ld a, [hl]
            ld b, a
            ld a, [bt_sbuf + 2]
            ld c, a
            ld a, b
            sbc a, c
            ret c
; FF1 LvlUp_LevelUp
bt_levelup: ld a, [bt_lvm]
            call ch_rec
            ld a, l
            ld [bt_lvr], a
            ld a, CH_LEVEL
            call bt_rf                      ; HL = record + A
            ld a, [hl]
            ld [bt_t], a                    ; old level (0-based)
            inc [hl]
            ld a, [bt_lvr]                  ; class
            ld l, a
            ld a, [hl]
            ld [bt_lvc], a
            ld e, a                         ; hit rate + bonus, magic defence + bonus (at most 200)
            ld d, 0
            ld hl, B_HITBON
            add hl, de
            ld a, BTL_DATA
            ld [fc_bank], a
            call far_byte
            ld b, a
            ld a, $21
            call bt_rf
            ld a, [hl]
            add a, b
            call bt_cap200
            ld [hl], a
            ld a, [bt_lvc]
            add a, 12
            ld e, a
            ld hl, B_HITBON
            add hl, de
            call far_byte
            ld b, a
            ld a, $25
            call bt_rf
            ld a, [hl]
            add a, b
            call bt_cap200
            ld [hl], a
            ld a, [bt_lvc]                  ; the level's two bytes (class mod 6, level)
            cp 6
            jr c, .c6
            sub 6
.c6:        ld l, a                         ; 98 class + 2 level
            ld h, 0
            ld d, h
            ld e, l
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl                      ; 32
            push hl
            add hl, hl                      ; 64
            pop de
            add hl, de                      ; 96
            ld d, 0
            ld a, [bt_lvc]
            cp 6
            jr c, .c7
            sub 6
.c7:        add a, a
            ld e, a
            add hl, de                      ; 98
            ld a, [bt_t]
            add a, a
            ld e, a
            add hl, de
            ld de, B_LVUP
            add hl, de
            ld de, bt_lvd
            ld bc, 2
            ld a, BTL_DATA
            call far_copy
            ld a, [bt_lvc]                  ; MP charges (not Fighter / Thief and their upgrades?
            and a                           ;   FF1: class 0 and 1 only)
            jr z, .nmp
            cp 1
            jr z, .nmp
            ld a, [bt_lvm]
            rrca
            rrca
            add a, $28
            ld l, a
            ld h, high(ch_magic)
            ld a, [bt_lvd + 1]
            ld b, 8
.mp:        rrca
            jr nc, .mn
            inc [hl]
.mn:        inc l
            dec b
            jr nz, .mp
            ld a, [bt_lvc]                  ; caps: Knight / Ninja 4, the others 9
            ld c, 10
            cp 6
            jr z, .k
            cp 7
            jr nz, .cp
.k:         ld c, 5
.cp:        ld a, l
            sub 8
            ld l, a
            ld b, 8
.cl:        ld a, [hl]
            cp c
            jr nz, .cn
            dec [hl]
.cn:        inc l
            dec b
            jr nz, .cl
.nmp:       ld a, $13                       ; HP: vitality / 4 + 1 (+ random 20-25 if bit 5)
            call bt_rf
            ld a, [hl]
            srl a
            srl a
            inc a
            ld [bt_t + 1], a
            ld a, [bt_lvd]
            and $20
            jr z, .nb
            ld a, 20
            ld b, 25
            call bt_randab
            ld b, a
            ld a, [bt_t + 1]
            add a, b
            ld [bt_t + 1], a
.nb:        ld a, CH_MAXHP                  ; max HP + bonus (at most 999)
            call bt_rf
            ld a, [bt_t + 1]
            add a, [hl]
            ld [hl+], a
            ld a, [hl]
            adc a, 0
            ld [hl-], a
            ld d, a
            ld e, [hl]
            ld a, e
            sub $E8                         ; >= 1000?
            ld a, d
            sbc a, 3
            jr c, .hp
            ld [hl], $E7
            inc hl
            ld [hl], 3
.hp:        ld a, [bt_lvd]                  ; stats: bits 4-0 = strength .. luck, sure; else 1 in 4
            add a, a
            add a, a
            add a, a
            ld [bt_t + 2], a
            xor a
            ld [bt_t + 3], a                ; stat index
            ld hl, bt_lvup
.st:        push hl
            ld a, [bt_t + 2]
            add a, a
            ld [bt_t + 2], a
            ld a, 1
            jr c, .inc
            call bt_rng
            and 3
            ld a, 1
            jr z, .inc
            xor a
.inc:       pop hl
            ld [hl+], a
            and a
            jr z, .sn
            push hl
            ld a, [bt_t + 3]
            add a, $10
            call bt_rf
            ld a, [hl]
            inc a
            cp 100
            jr z, .s1
            ld [hl], a
.s1:        pop hl
.sn:        ld a, [bt_t + 3]
            inc a
            ld [bt_t + 3], a
            cp 5
            jr c, .st
            ld a, [bt_lvup]                 ; strength up to an even value: damage + 1
            and a
            jr z, .e1
            ld a, $10
            call bt_rf
            bit 0, [hl]
            jr nz, .e1
            ld a, $20
            call bt_rf
            ld a, [hl]
            inc a
            cp 201
            jr z, .e1
            ld [hl], a
.e1:        ld a, [bt_lvup + 1]             ; agility up: evade + 1
            and a
            jr z, .e2
            ld a, $23
            call bt_rf
            ld a, [hl]
            inc a
            cp 201
            jr z, .e2
            ld [hl], a
.e2:        ld a, [bt_lvc]                  ; Black Belt / Master without a weapon (FF1
            cp CLS_BB                       ;   LvlUp_AdjustBBSubStats)
            jr z, .bb
            cp CLS_MA
            jr nz, .msg
.bb:        ld a, $18
            call bt_rf
            ld b, 4
.bw:        bit 7, [hl]
            jr nz, .msg
            inc hl
            dec b
            jr nz, .bw
            ld a, CH_LEVEL
            call bt_rf
            ld a, [hl]
            inc a
            ld b, a
            ld a, $22
            call bt_rf
            ld [hl], b
            sla b
            ld a, $20
            call bt_rf
            ld [hl], b
.msg:       ld a, [bt_res]                  ; (after a victory: kept for the results window)
            and a
            jp nz, bt_lvrec
            ld a, [bt_lvm]                  ; messages: name, Level up!, Max HP N points, stats
            call bt_msg_pl
            ld a, 48
            call bt_msg_line
            ld a, [bt_t + 1]
            call nf_a
            ld hl, bt_sbuf + 16
            push hl
            ld a, 49
            call bt_mtext                   ; "Max HP" + " " + N + " points"
            ld hl, bt_sbuf
            ld de, bt_line
.m1:        ld a, [hl+]
            and a
            jr z, .m2
            ld [de], a
            inc de
            jr .m1
.m2:        ld a, $20
            ld [de], a
            inc de
            push de
            call num_fmt
            pop de
            ld hl, nf_dig
.m3:        ld a, [hl+]
            cp $20
            jr z, .m4
            ld [de], a
            inc de
.m4:        ld a, l
            cp low(nf_dig + 6)
            jr nz, .m3
            push de
            ld a, 50
            call bt_mtext
            pop de
            ld hl, bt_sbuf
.m5:        ld a, [hl+]
            ld [de], a
            inc de
            and a
            jr nz, .m5
            pop hl
            ld hl, bt_line
            call bt_msg_row
            call bt_msg_end
            xor a                           ; each stat up: "Strength went up" ...
            ld [bt_t + 3], a
.sm:        ld a, [bt_t + 3]
            ld e, a
            ld d, 0
            ld hl, bt_lvup
            add hl, de
            ld a, [hl]
            and a
            jr z, .smn
            ld a, [bt_lvm]
            call bt_msg_pl
            call bt_msg_head
            ld a, [bt_t + 3]
            add a, 51
            call bt_mtext
            ld hl, bt_sbuf
            ld de, bt_line
.sc:        ld a, [hl+]
            and a
            jr z, .sd
            ld [de], a
            inc de
            jr .sc
.sd:        push de
            ld a, 56
            call bt_mtext
            pop de
            ld hl, bt_sbuf
.se:        ld a, [hl+]
            ld [de], a
            inc de
            and a
            jr nz, .se
            call bt_msg_head
            ld hl, bt_line
            call bt_msg_row
            call bt_msg_end
.smn:       ld a, [bt_t + 3]
            inc a
            ld [bt_t + 3], a
            cp 5
            jr c, .sm
            ret
; HL = the levelling member's record + A
bt_rf:      ld l, a
            ld a, [bt_lvr]
            add a, l
            ld l, a
            ld h, high(ch_stats)
            ret
bt_cap200:  cp 201
            ret c
            ld a, 200
            ret
; a row "N" + string HL
bt_numline: push hl
            call num_fmt
            ld hl, nf_dig
            ld de, bt_line
.s:         ld a, [hl]
            cp $20
            jr nz, .c
            inc hl
            jr .s
.c:         ld a, [hl+]
            ld [de], a
            inc de
            ld a, l
            cp low(nf_dig + 6)
            jr nz, .c
            pop hl
.t:         ld a, [hl+]
            ld [de], a
            inc de
            and a
            jr nz, .t
            ld hl, bt_line
            jp bt_msg_row
bt_s_pts:   db "P", 0
bt_s_gil:   db " Gil", 0


; ---- the damage as a number over its target while the message shows, popping up and
; dropping back with a little bounce, as in FF3 (owner, 2026-11-22); "MISS!" the same. Bold
; outlined glyphs (battle.py dn_tiles, BTL_DATA $4B00), one sprite each (tiles $F0-$F4: the
; hand's, not shown meanwhile; put back afterwards), OAM 35-39, white (CGB OBJ palette 4)
B_DNGLY    = $4B00
DN_OAM     = oam_buf + 140
DN_T0      = $F0
bt_dnum_w:  ld a, [bt_defer]
            and a
            ret nz
            ld a, [hl+]                     ; (from the 16-bit damage at HL)
            ld [nf_val], a
            ld a, [hl]
            ld [nf_val + 1], a
            xor a
            ld [nf_val + 2], a
            call num_fmt
            ld hl, nf_dig
            ld de, bt_dstr
            ld b, 0
.s:         ld a, [hl+]                     ; (the digits, no leading spaces)
            sub $30
            jr c, .n
            ld [de], a
            inc de
            inc b
.n:         ld a, l
            cp low(nf_dig + 6)
            jr nz, .s
            call bt_dpop
            ld a, [df_player]               ; (a member hit: it flinches)
            and a
            ret z
            jp rc_start
bt_dmiss:   ld a, [bt_defer]
            and a
            ret nz
            ld hl, dn_miss
            ld de, bt_dstr
            ld bc, 5
            call memcpy
            ld b, 5
; B glyphs from bt_dstr over the target (bt_tgt; df_player: a member)
bt_dpop:    ld a, b
            and a
            ret z
            cp 6                            ; (at most 5 glyphs: OAM 35-39)
            jr c, .nn
            ld a, 5
.nn:        ld [dn_n], a
            call bt_flush                   ; (a previous upload first)
            ld de, bt_stage
            ld hl, bt_dstr
            ld a, [dn_n]
            ld b, a
.g:         push bc
            push hl
            ld a, [hl]
            swap a
            ld l, a
            ld h, high(B_DNGLY)
            ld bc, 16
            ld a, BTL_DATA
            call far_copy                   ; (DE advances)
            pop hl
            inc hl
            pop bc
            dec b
            jr nz, .g
            ld hl, bt_stage
            ld a, l
            ld [bt_upsrc], a
            ld a, h
            ld [bt_upsrc + 1], a
            xor a
            ld [bt_updst], a
            ld a, $8F
            ld [bt_updst + 1], a
            ld a, [dn_n]
            ld [bt_upn], a
            ld b, a                         ; width = 7 n + 1
            add a, a
            add a, a
            add a, a
            sub b
            inc a
            ld [bt_dw], a
            ld a, [df_player]
            and a
            jr nz, .pl
            ld a, [bt_tgt]                  ; an enemy: centred on it, at its middle
            call bt_epos
            ld a, b
            add a, a
            add a, e
            add a, a
            add a, a
            ld d, a
            ld a, [bt_dw]
            srl a
            ld l, a
            ld a, d
            sub l
            ld d, a
            ld a, c
            add a, a
            add a, e
            add a, a
            add a, a
            sub 4
            ld e, a
            jr .put
.pl:        ld a, [bt_tgt]                  ; a member: left of the sprite
            and 3
            ld c, a
            add a, a
            add a, c
            add a, a
            add a, a
            add a, a
            add a, 8
            ld e, a
            ld a, [bt_dw]
            ld l, a
            ld a, PARTY_X - 4
            sub l
            ld d, a
.put:       ld a, d
            ld [dn_x], a
            ld a, e
            ld [dn_y], a
            ld a, 1
            ld [dn_t], a
            ret
; each frame (bt_frame): the glyphs at their place in the bounce, once their tiles are up
bt_danim:   ld a, [dn_t]
            and a
            ret z
            ld a, [bt_upn]
            and a
            ret nz
            push bc                         ; (bt_frame's callers keep registers in it)
            push de
            push hl
            call .go
            pop hl
            pop de
            pop bc
            ret
.go:        ld a, [dn_t]
            cp DN_LEN
            jr nc, .h
            inc a
            ld [dn_t], a
.h:         ld e, a
            ld d, 0
            ld hl, dn_off - 2
            add hl, de
            ld a, [dn_y]
            add a, [hl]
            add a, 16
            ld c, a                         ; OAM y
            ld a, [dn_x]
            add a, 8
            ld b, a                         ; OAM x
            ld hl, DN_OAM
            ld a, [dn_n]
            ld e, a
            ld d, DN_T0
.o:         ld a, c
            ld [hl+], a
            ld a, b
            ld [hl+], a
            add a, 7
            ld b, a
            ld a, d
            ld [hl+], a
            inc d
            ld a, $14                       ; (CGB OBJ palette 4; DMG / SGB OBP1)
            ld [hl+], a
            dec e
            jr nz, .o
            jp rc_anim
; the number gone, the hand's tiles back
bt_dnum_off:
            call rc_end
            ld a, [dn_t]
            and a
            ret z
            xor a
            ld [dn_t], a
            ld hl, HL_OAM                   ; (the hit label too: OAM 32-34)
            ld b, 8
.c:         ld [hl+], a
            inc l
            inc l
            inc l
            dec b
            jr nz, .c
            call bt_flush
            ldh a, [is_cgb]
            and a
            ld hl, U_CURDMG
            jr z, .d
            ld hl, U_CURCGB
.d:         ld de, bt_stage
            ld bc, 64
            ld a, UI_GFX
            call far_copy
            ld hl, bt_stage
            ld a, l
            ld [bt_upsrc], a
            ld a, h
            ld [bt_upsrc + 1], a
            xor a
            ld [bt_updst], a
            ld a, $8F
            ld [bt_updst + 1], a
            ld a, 4
            ld [bt_upn], a
            ret
dn_miss:    db 10, 11, 12, 12, 13           ; M I S S !
; the bounce: y offsets by frame (up, back down, a smaller hop, at rest)
dn_off:     db 0, 254, 252, 250, 249, 248, 248, 249, 250, 252, 254, 0, 254, 253, 253, 254, 0
DN_LEN     = 17

section bank 6, $7360                       ; (a member's flinch: after btl4)
; ---- a member hit (owner, 2026-11-22: feedback for the party being attacked; no blinking):
; its six sprites knocked a few pixels back (right, away from the enemies) and sliding back,
; while the damage number pops
rc_start:   ld a, [bt_tgt]
            and 3
            ld c, a                         ; OAM 4 + 6 m: oam_buf + 16 + 24 m (x at + 1)
            add a, a
            add a, c
            add a, a
            add a, a
            add a, a
            add a, low(oam_buf) + 17
            ld l, a
            ld a, high(oam_buf)
            adc a, 0
            ld h, a
            ld a, l
            ld [rc_p], a
            ld a, h
            ld [rc_p + 1], a
            ld de, rc_bx
            ld b, 6
.c:         ld a, [hl+]
            ld [de], a
            inc de
            inc hl
            inc hl
            inc hl
            dec b
            jr nz, .c
            ld a, 1
            ld [rc_t], a
            ret
; each frame with the number (bt_danim): the offset of this frame
rc_anim:    ld a, [rc_t]
            and a
            ret z
            cp RC_LEN
            jr nc, rc_end
            inc a
            ld [rc_t], a
            ld e, a
            ld d, 0
            ld hl, rc_off - 2
            add hl, de
            ld c, [hl]
            jr rc_put
; back in place
rc_end:     ld a, [rc_t]
            and a
            ret z
            xor a
            ld [rc_t], a
            ld c, a
rc_put:     ld a, [rc_p]
            ld l, a
            ld a, [rc_p + 1]
            ld h, a
            ld de, rc_bx
            ld b, 6
.p:         ld a, [de]                      ; (hidden sprites stay hidden)
            and a
            jr z, .n
            add a, c
.n:         ld [hl+], a
            inc de
            inc hl
            inc hl
            inc hl
            dec b
            jr nz, .p
            ret
rc_off:     db 4, 7, 8, 8, 7, 6, 5, 3, 2, 1, 0
RC_LEN     = 11
; Options: Cursor Reset: each member's command, spell and target not remembered
bt_curr:    ld a, [opt_curr]
            and a
            ret z
            ld hl, bt_lastc
            xor a
            ld b, 8                         ; (bt_lastc, bt_lastm)
.c:         ld [hl+], a
            dec b
            jr nz, .c
            dec a
            ld hl, bt_lastt
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl], a
            ret
zz_end_b6_7360:

section bank 6, $76D0                       ; (running away: after the results window)
; FF1 Battle_PlayerTryRun (the level from the member's record: FF1's bug fixed)
bt_try_run: ld a, [bt_who]
            call bt_msg_pl
            ld a, [bt_first]
            and a
            jr nz, .ok
            ld a, [bt_form + 13]
            and 1
            jr nz, .no
            ld a, [bt_who]
            call ch_rec
            ld a, l
            add a, CH_LEVEL
            ld l, a
            ld a, [hl]
            add a, 15
            ld b, a
            xor a
            call bt_randab                  ; random(0 .. level + 15) - luck > 0: away
            ld b, a
            ld a, [bt_who]
            call ch_rec
            ld a, l
            add a, $14
            ld l, a
            ld a, [hl]
            ld c, a
            ld a, c
            sub b                           ; luck - r > 0: away
            jr z, .no
            jr nc, .ok
.no:        ld a, M_CANTRUN
            jp bt_msg_end1
.ok:        ld a, M_CLOSE
            call bt_msg_end1
            call bt_runoff                  ; (owner, 2026-11-23: the party turns and runs off)
            ld a, 3
            ld [bt_result], a
            ret

; the party runs away: the members that can move turn round (sprites mirrored), a moment,
; then run off to the right, 3 pixels a frame, FF1's walking pose every 4 frames
bt_runoff:  ld a, SFX_MOVE                  ; (a little step sound as they turn)
            ld [sfx_req], a
            ld b, 0
.t:         call .can
            jr nz, .tn
            push bc
            ld a, b
            call bt_dm
            pop bc
            push bc
            ld a, b
            call bt_flipm
            pop bc
.tn:        inc b
            ld a, b
            cp 4
            jr c, .t
            ld b, 10
.w:         push bc
            call bt_frame
            pop bc
            dec b
            jr nz, .w
            xor a
            ld [dt_pose], a
.f:         ld c, 0                         ; members still on the screen
            ld b, 0
.m:         call .can
            jr nz, .nx
            ld e, b
            ld d, 0
            ld hl, bt_px
            add hl, de
            ld a, [hl]
            cp 168
            jr nc, .nx
            add a, 3
            ld [hl], a
            inc c
            ld hl, bt_pose
            add hl, de
            ld a, [dt_pose]
            and 4
            ld [hl], a
            push bc
            ld a, b
            call bt_dm
            pop bc
            push bc
            ld a, b
            call bt_flipm
            pop bc
.nx:        inc b
            ld a, b
            cp 4
            jr c, .m
            ld a, c
            and a
            ret z
            call bt_frame
            ld hl, dt_pose
            inc [hl]
            jr .f
.can:       push bc                         ; NZ: member B cannot move (fallen, asleep, numb)
            ld a, b
            call ch_rec
            inc hl
            ld a, [hl]
            pop bc
            and AIL_DEAD | AIL_STONE | AIL_SLEEP | AIL_STUN
            ret
; member A's six sprites mirrored (each row's two tiles swapped, X flip)
bt_flipm:   ld e, a
            add a, a
            add a, e
            add a, a
            add a, a
            add a, a
            add a, 16 + 2
            ld l, a
            ld h, high(oam_buf)
            ld b, 3
.r:         ld c, [hl]
            ld a, l
            add a, 4
            ld l, a
            ld a, [hl]
            ld [hl], c
            ld c, a
            ld a, l
            sub 4
            ld l, a
            ld [hl], c
            inc l
            set 5, [hl]
            ld a, l
            add a, 4
            ld l, a
            set 5, [hl]
            inc l
            inc l
            inc l
            dec b
            jr nz, .r
            ret

section bank 6, $73F0                       ; (waking / paralysis: after the flinch)
; FF1 Battle_PlayerTryWakeup: random(0 .. 80) < max HP wakes
bt_try_wake:
            ld a, [bt_who]
            call bt_msg_pl
            xor a
            ld b, $50
            call bt_randab
            ld c, a
            ld a, [bt_who]                  ; max HP > r: woke
            call ch_rec
            ld a, l
            add a, CH_MAXHP
            ld l, a
            ld a, [hl+]
            ld d, a
            ld a, [hl]
            and a
            jr nz, .wk
            ld a, d
            cp c
            jr z, .sl
            jr c, .sl
.wk:        ld a, [bt_who]
            call ch_rec
            inc hl
            res 5, [hl]
            ld a, M_WOKE
            jp bt_msg_end1
.sl:        ld a, M_ASLEEP
            jp bt_msg_end1
; FF1 Battle_PlayerTryUnstun: 1 in 4
bt_try_unstun:
            ld a, [bt_who]
            call bt_msg_pl
            call bt_rng
            and 3
            jr z, .ok
            ld a, M_PARA
            jp bt_msg_end1
.ok:        ld a, [bt_who]
            call ch_rec
            inc hl
            res 4, [hl]
            ld a, M_CURED
            jp bt_msg_end1

; ---- physical attacks (FF1 PlayerAttackEnemy_Physical / EnemyAttackPlayer_Physical /
; DoPhysicalAttack): the attacker's and defender's numbers into ak_* / df_*

section bank 6, $7480                       ; (the results window: after btl4)
; a level up kept for the results window: the new level, the HP gain, the stats raised
bt_lvrec:   ld a, CH_LEVEL
            call bt_rf
            ld b, [hl]
            ld a, [bt_lvm]
            ld e, a
            ld d, 0
            ld hl, res_lv
            add hl, de
            ld [hl], b
            ld hl, res_hp
            add hl, de
            ld a, [bt_t + 1]
            ld [hl], a
            ld c, 0
            ld hl, bt_lvup + 4
            ld b, 5
.m:         ld a, [hl-]
            and a
            jr z, .z
            scf
.z:         rl c
            dec b
            jr nz, .m
            ld hl, res_st
            add hl, de
            ld [hl], c
            ld hl, res_on
            add hl, de
            ld [hl], 1
            ret

; ---- the results window (owner, 2026-11-22): over the cleared enemy area (0,0,16,12),
; Experience and Gil, then each member who went up a level (name, Level up!, the level; HP +
; and the stats raised), two members a page; A / B turns the page / closes it
bt_results: call bt_left_clear              ; (the names window empty: no one is left)
            call bt_party_win               ; (the new maximum HP)
            call bt_upd
            xor a
            ld [bt_res], a
            ld [res_m], a                   ; the next member to show
            ld a, 1
            ld [res_pg], a                  ; (page 1: the experience and Gil first)
.pg:        ld bc, $0000
            ld de, $100C
            call bt_win
            xor a
            ld [res_ln], a
            ld a, [res_pg]
            and a
            jr z, .mem
            ld de, bt_line                  ; Experience up N P
            ld a, 73
            call res_txt
            ld a, $20
            ld [de], a
            inc de
            ld hl, bt_rexp
            call res_num
            ld hl, bt_s_pts
            call res_str
            call res_put
            ld de, bt_line                  ; N Gil
            ld hl, bt_rgold
            call res_num
            ld hl, bt_s_gil
            call res_str
            call res_put
            ld hl, res_ln                   ; (a blank row)
            inc [hl]
.mem:       ld a, [res_m]
            cp 4
            jr nc, .sh
            ld e, a
            ld d, 0
            ld hl, res_on
            add hl, de
            ld a, [hl]
            and a
            jr z, .mn
            ld a, [res_ln]                  ; two rows left?
            cp 6
            jr nc, .sh
            ld de, bt_line                  ; name Level up! L n
            ld a, [res_m]
            call ch_rec
            inc hl
            inc hl
            ld b, 4
.nm:        ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .nm
            ld a, l
            add a, CH_NAME2 - 6
            ld l, a
            ld a, [hl+]
            ld [de], a
            inc de
            ld a, [hl]
            ld [de], a
            inc de
.tr:        dec de                          ; (the name's trailing blanks dropped)
            ld a, [de]
            cp $20
            jr z, .tr
            inc de
            ld a, $20
            ld [de], a
            inc de
            ld a, 48
            call res_txt
            ld hl, res_s_l
            call res_str
            ld a, [res_m]
            ld l, a
            ld h, 0
            push de
            ld de, res_lv
            add hl, de
            pop de
            ld a, [hl]
            inc a
            ld [bt_t + 13], a
            xor a
            ld [bt_t + 14], a
            ld hl, bt_t + 13
            call res_num
            call res_put
            ld de, bt_line                  ; HP + n, the stats raised
            ld hl, res_s_hp
            call res_str
            ld a, [res_m]
            ld l, a
            ld h, 0
            push de
            ld de, res_hp
            add hl, de
            pop de
            ld a, [hl]
            ld [bt_t + 13], a
            xor a
            ld [bt_t + 14], a
            ld hl, bt_t + 13
            call res_num
            ld a, [res_m]
            ld l, a
            ld h, 0
            push de
            ld de, res_st
            add hl, de
            pop de
            ld a, [hl]
            ld [bt_t + 15], a
            ld hl, res_s_st
.st:        ld a, [bt_t + 15]
            srl a
            ld [bt_t + 15], a
            jr nc, .sn
            push hl
            call res_str
            pop hl
.sn:        inc hl                          ; (the next name: 5 bytes each)
            inc hl
            inc hl
            inc hl
            inc hl
            ld a, l
            cp low(res_s_st + 25)
            jr nz, .st
            call res_put
.mn:        ld hl, res_m
            inc [hl]
            jp .mem
.sh:        ld a, 12                        ; shown; A / B
            ld [sf_row], a
            xor a
            ld [sf_row], a
.w:         call bt_frame
            ldh a, [pad_new]
            and 3
            jr z, .w
            xor a
            ld [res_pg], a
            ld a, [res_m]                   ; more members left: another page
            cp 4
            jr nc, .cl
            ld e, a
            ld d, 0
            ld hl, res_on
            add hl, de
.ml:        ld a, [hl+]
            and a
            jp nz, .pg
            inc e
            ld a, e
            cp 4
            jr c, .ml
.cl:        ld hl, smap                     ; the window gone: the empty battlefield
            ld c, 12
.cr:        push hl
            ld b, 16
.cc:        ld [hl], 0
            inc h
            inc h
            inc h
            ld [hl], 0
            dec h
            dec h
            dec h
            inc hl
            dec b
            jr nz, .cc
            pop hl
            ld de, 32
            add hl, de
            dec c
            jr nz, .cr
            xor a
            ld [sf_row], a
            ld b, 8
.cw:        push bc
            call bt_frame
            pop bc
            dec b
            jr nz, .cw
            ret
; FF1 message A's text appended at DE
res_txt:    push de
            call bt_mtext
            pop de
            ld hl, bt_sbuf
; string HL appended at DE (0-ended, DE left on the 0)
res_str:    ld a, [hl+]
            ld [de], a
            and a
            ret z
            inc de
            jr res_str
; the 16-bit number at HL appended at DE
res_num:    ld a, [hl+]
            ld [nf_val], a
            ld a, [hl]
            ld [nf_val + 1], a
            xor a
            ld [nf_val + 2], a
            push de
            call num_fmt
            pop de
            ld hl, nf_dig
.s:         ld a, [hl]
            cp $20
            jr nz, .c
            inc hl
            jr .s
.c:         ld a, [hl+]
            ld [de], a
            inc de
            ld a, l
            cp low(nf_dig + 6)
            jr nz, .c
            xor a
            ld [de], a
            ret
; bt_line as the window's next text row (tiles $12 + 14 row, cells (1, 2 + row))
res_put:    ld a, [res_ln]
            cp 7
            ret nc
            ld b, 14
            call vwf_clr
            ld hl, bt_line
            xor a
            call vwf_str
            ld a, [res_ln]
            ld c, a
            add a, a                        ; 14 row
            ld b, a
            add a, a
            add a, a
            add a, a
            sub b
            add a, $12
            push af
            ld b, 14
            call vwf_out
            pop af
            ld e, a
            ld a, [res_ln]
            add a, 2
            ld c, a
            ld b, 1
            call cell_addr
            ld b, 14
.c:         ld [hl], e
            inc e
            inc h
            inc h
            inc h
            ld [hl], 3
            dec h
            dec h
            dec h
            inc hl
            dec b
            jr nz, .c
            ld hl, res_ln
            inc [hl]
            ret
res_s_l:    db " L", 0
res_s_hp:   db "  HP +", 0
res_s_st:   db " Str", 0, " Agi", 0, " Int", 0, " Vit", 0, " Lck", 0
zz_end_b6_7480:

section wram, $C100                         ; (the map's queue is free during a battle)
bt_en:      ds 9 * 32
bt_ch:      ds 4 * 16
bt_cmd:     ds 16
bt_order:   ds 13
bt_turn:    ds 1
bt_first:   ds 1
bt_result:  ds 1
bt_cm:      ds 1
bt_ccur:    ds 1
bt_tcur:    ds 1
bt_who:     ds 1
bt_tgt:     ds 1
bt_rows:    ds 1
bt_lp:      ds 1
ak_hit:     ds 1
ak_str:     ds 1
ak_mult:    ds 1
ak_hits:    ds 1
ak_cat:     ds 1
ak_elem:    ds 1
ak_crit:    ds 1
ak_ail:     ds 1
ak_ails:    ds 1
df_cat:     ds 1
df_weak:    ds 1
df_evade:   ds 1
df_absorb:  ds 1
df_magdef:  ds 1
df_resist:  ds 1
df_hp:      ds 2
df_ails:    ds 1
df_player:  ds 1
mt_hitc:    ds 2
mt_base:    ds 1
mt_crit:    ds 1
mt_hits:    ds 1
mt_conn:    ds 1
mt_crits:   ds 1
mt_total:   ds 2
mt_d:       ds 1
mt_dmg:     ds 2
mt_rand:    ds 1
mt_ailc:    ds 1
bt_rexp:    ds 2
bt_msgon:   ds 1
bt_lvm:     ds 1
bt_lvr:     ds 1
bt_lvc:     ds 1
bt_lvd:     ds 2
bt_lvup:    ds 5
bt_td:      ds 1                            ; (free targeting: direction, the hand's middle,
bt_tcx:     ds 1                            ;   pass, candidate, best score and enemy)
bt_tcy:     ds 1
bt_tps:     ds 1
bt_tj:      ds 1
bt_tbs:     ds 1
bt_tbj:     ds 1
bt_lastt:   ds 4
dn_t:       ds 1                            ; the damage number: frame of its bounce (0: none)
dn_n:       ds 1                            ;   glyphs, place
dn_x:       ds 1
dn_y:       ds 1
bt_dstr:    ds 6
rc_t:       ds 1                            ; a member's flinch: frame (0: none), OAM x pointer,
rc_p:       ds 2                            ;   its sprites' own x
rc_bx:      ds 6                            ; each member's last enemy target (this battle)
bt_res:     ds 1                            ; (the results window: level ups recorded,
bt_rgold:   ds 2                            ;   the gold, each member's new level, HP gain,
res_on:     ds 4                            ;   stats raised, the page, row, next member)
res_lv:     ds 4
res_hp:     ds 4
res_st:     ds 4
res_pg:     ds 1
res_ln:     ds 1
res_m:      ds 1
section wram, $C500
bt_save:    ds 12 * 32                      ; the rows under the message window
section wram, $C400
bt_line:    ds 256                          ; a message line being built (page-aligned)
