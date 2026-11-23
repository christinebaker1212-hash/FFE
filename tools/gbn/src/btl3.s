; FF1 native engine: battle part 3 (bank 6): magic. Our own code from FF1's magic routines
; (bank 0C: MenuSelection_Magic, Player_DoMagic, Battle_PrepareMagic, the target routines,
; BtlMag_PerformSpellEffect and the effects, BtlMag_HandleAilmentChanges, Enemy_DoAi).
; Spell data: the ROM's (battle data bank $5900, 8 bytes a spell: hit rate, effectivity,
; element, target, effect, graphic, palette); names: battle data $7400.

B_MAGIC    = $5900
B_MAGMSG   = $5C00
B_AI       = $5600
B_ATKNAME  = $7400
MG_FIRE    = 4              ; (FF1: a confused enemy casts Fire on its own side)

section bank 6, $6000

; ---- the spell list (approved: two levels a page, rows of spells 1 and 2, then spell 3 and
; the level with its MP; hands at x 0 / 80); A = spell id, [bt_mlv] = level; C set on B
bt_mag_menu:
            ld hl, bt_lastm                 ; (the member's last spell slot)
            call bt_memp
            ld a, [hl]
            cp 24
            jr c, .m0
            xor a
.m0:        ld [bt_mcur], a
            ld a, $FF
            ld [bt_mpage], a
.l:         ld a, [bt_mcur]                 ; the page of the cursor's level
            call bt_mslot                   ; B = level, C = slot
            ld a, b
            srl a
            ld hl, bt_mpage
            cp [hl]
            call nz, bt_mag_page
            ld a, [bt_mcur]                 ; the hand: a level a column (text at x 16 / 96,
            call bt_mslot                   ;   the hand 17 px left); row 1 the levels, the
            ld a, c                         ;   spells on rows 2-4 (y = 8 row)
            add a, 14
            add a, a
            add a, a
            add a, a
            ld e, a
            ld a, b
            and 1
            ld b, 16 - 17
            jr z, .x
            ld b, 96 - 17
.x:         ld c, e
            call bt_hand
            call bt_frame
            ldh a, [pad_new]
            bit 1, a
            jp nz, .b
            bit 0, a
            jr nz, .a
            ld e, a
            ld a, [bt_mcur]
            call bt_mslot                   ; B level, C slot
            bit 4, e
            jr nz, .rl
            bit 5, e
            jr nz, .rl
            bit 7, e
            jr nz, .dn
            bit 6, e
            jr z, .l
            ld a, c                         ; up: the slot above; from the top, the last slot
            and a                           ;   of the page above
            jr z, .u1
            dec c
            jr .set2
.u1:        ld c, 2
            ld d, $FE
            jr .pg
.dn:        ld a, c                         ; down: the slot below; from the bottom, the first
            cp 2                            ;   slot of the page below
            jr z, .d1
            inc c
            jr .set2
.d1:        ld c, 0
            ld d, 2
.pg:        ld e, 4                         ; (pages without a spell skipped)
.pn:        ld a, b
            add a, d
            and 7
            ld b, a
            push bc
            push de
            call bt_mpgemp
            pop de
            pop bc
            jr nz, .set2
            dec e
            jr nz, .pn
            jr .set2
.rl:        ld a, b                         ; left / right: the other level of the page
            xor 1
            ld b, a
            jr .set2
.set:       ld c, a
.set2:      ld a, b
            add a, a
            add a, b
            add a, c
            ld [bt_mcur], a
            jp .l
.a:         ld a, [bt_mcur]                 ; the spell there (and MP for its level)
            call bt_mslot
            ld a, b
            ld [bt_mlv], a
            call bt_mdata
            ld a, l
            add a, $20
            add a, b
            ld e, a
            ld d, h
            ld a, [de]
            and a
            jp z, .l
            ld a, b
            add a, a
            add a, a
            add a, c
            add a, l
            ld l, a
            ld a, [hl]
            and a
            jp z, .l
            dec a                           ; spell id = level x 8 + spell - 1
            ld c, a
            ld a, b
            add a, a
            add a, a
            add a, a
            add a, c
            and a
            ret
.b:         scf
            ret
; cursor A (0-23) -> B = level, C = slot
bt_mslot:   ld b, 0
.l:         cp 3
            jr c, .x
            sub 3
            inc b
            jr .l
.x:         ld c, a
            ret
; HL = the commanding member's magic data
bt_mdata:   ld a, [bt_cm]
            rrca
            rrca
            ld l, a
            ld h, high(ch_magic)
            ret
; page A (levels 2A, 2A + 1) into the message window, a level a column (owner, 2026-11-23):
; row 1 "L<n> MP <left>" of both, rows 2-4 their spells
bt_mag_page:
            ld [bt_mpage], a
            ld a, [bt_msgon]
            and a
            call z, bt_msg_win
            xor a
            ld [bt_rows], a
            ld b, 18
            call vwf_clr
            ld a, [bt_mpage]
            add a, a
            ld [bt_t + 6], a                ; level
            ld a, 8
            call bt_mhdr
            ld hl, bt_t + 6
            inc [hl]
            ld a, 88
            call bt_mhdr
            call bt_mrow
            xor a
.sp:        push af                         ; slot
            ld b, 18
            call vwf_clr
            ld a, [bt_mpage]
            add a, a
            ld [bt_t + 6], a
            pop af
            push af
            ld c, a
            ld a, 8
            call bt_mspell
            ld hl, bt_t + 6
            inc [hl]
            pop af
            push af
            ld c, a
            ld a, 88
            call bt_mspell
            call bt_mrow
            pop af
            inc a
            cp 3
            jr c, .sp
            ret
; the spell in slot C of level [bt_t+6] at pixel A (icon + name)
bt_mspell:  ld [vw_x], a
            call bt_mdata
            ld a, [bt_t + 6]
            add a, a
            add a, a
            add a, c
            add a, l
            ld l, a
            ld a, [hl]
            and a
            ret z
            dec a
            ld c, a
            ld a, [bt_t + 6]
            add a, a
            add a, a
            add a, a
            add a, c
            call bt_mname
            ld hl, bt_sbuf
            ld a, [vw_x]
            jp vwf_str
; magic id A -> its name (icon code + letters) in bt_sbuf
bt_mname:   ld l, a
            ld h, 0
            add hl, hl
            ld de, B_ATKNAME
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
; the buffer as message row [bt_rows] (tiles BT_TEXT + 18 row)
bt_mrow:    ld a, [bt_rows]
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

; a member as target: the hand left of its sprite; A = member, C set on B
bt_target_member:
            ld a, $FF
            ld [ban_last], a
            ld a, [bt_cm]
            ld [bt_tcur], a
bt_tm_again:                                ; (the hand where it was)
.l:         call bt_tban_p                  ; (the member's name at the top)
            ld a, [bt_tcur]
            ld c, a
            add a, a
            add a, c
            add a, a
            add a, a
            add a, a                        ; 24 member
            add a, 4
            ld c, a
            ld b, PARTY_X - 18
            call bt_hand
            call bt_frame
            ldh a, [pad_new]
            bit 1, a
            jr nz, .b
            bit 0, a
            jr nz, .a
            bit 2, a
            jr nz, .sel
            ld hl, bt_tcur
            bit 6, a
            jr nz, .up
            bit 7, a
            jr z, .l
            ld a, [hl]
            inc a
            and 3
            ld [hl], a
            jr .l
.up:        ld a, [hl]
            dec a
            and 3
            ld [hl], a
            jr .l
.sel:       call bt_tban_sel
            jr .l
.a:         call bt_hand_off
            call bt_tban_off
            ld a, [bt_tcur]
            and a
            ret
.b:         call bt_hand_off
            call bt_tban_off
            scf
            ret

; the command: Magic chosen (from bt_cmd_one): spell, its target; C set on B
bt_cmd_magic:
            call bt_mag_menu
            push af
            call bt_hand_off
            call bt_msg_close
            pop af
            ret c
            push af
            call bt_names_win               ; (the names while targeting)
            ld hl, bt_lastm                 ; (remembered)
            call bt_memp
            ld a, [bt_mcur]
            ld [hl], a
            pop af
            ld [bt_t + 7], a                ; spell id
            call bt_mload                   ; its data -> mg_d
            ld a, [mg_d + 3]                ; target: one enemy / one member: choose
            bit 1, a
            jr nz, .en
            bit 4, a
            jr nz, .me
            xor a
            jr .set
.en:        call bt_target_enemy
            ret c
            jr .set
.me:        ld a, [mg_d + 4]                ; (HP recovery: not on a member at full HP)
            and $FE
            cp 6
            jr nz, .mm
            call bt_target_heal
            ret c
            jr .set
.mm:        call bt_target_member
            ret c
.set:       ld b, a
            call bt_commands.slot
            ld [hl], $40
            inc hl
            ld a, [bt_t + 7]
            ld [hl+], a
            ld [hl], b
            inc hl
            ld a, [bt_mlv]
            ld [hl], a
            and a
            ret
; the message window closed (the rows below back)
bt_msg_close:
            ld a, [bt_msgon]
            and a
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
            jp bt_upd

; magic id A -> mg_d (8 bytes)
bt_mload:   ld [mg_id], a
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, B_MAGIC
            add hl, de
            ld de, mg_d
            ld bc, 8
            ld a, BTL_DATA
            jp far_copy

; ---- casting: a member's spell (FF1 Player_DoMagic): the command's spell / target / level
bt_pl_magic:
            inc hl
            ld a, [hl+]
            ld [mg_id], a
            ld a, [hl+]
            ld [bt_tgt], a
            ld a, [hl]
            ld [bt_mlv], a
            ld a, [bt_who]                  ; silenced: no
            call ch_rec
            inc hl
            bit 6, [hl]
            jr z, .ok
            ld a, [bt_who]
            call bt_msg_pl
            ld a, $07
            jp bt_msg_end1
.ok:        ld a, [bt_who]                  ; one MP of the level
            rrca
            rrca
            ld l, a
            ld a, [bt_mlv]
            add a, $20
            add a, l
            ld l, a
            ld h, high(ch_magic)
            ld a, [hl]
            and a
            jr z, .nomp
            dec [hl]
.nomp:      ld a, [mg_id]
            call bt_mload
            ld a, SFX_MAGIC                 ; FF1 PreparePlayerMagAttack: the casting sound,
            ld [sfx_req], a                 ;   WalkForwardAndCastMagic (the spell's graphic
            ld a, [mg_d + 5]                ;   and colour)
            ld [bt_ag], a
            ld a, [mg_d + 6]
            ld [bt_ac], a
            ld a, [bt_who]
            call bt_cast_anim
            ld a, [bt_who]
            or $80
            ld [mg_caster], a
            jp bt_cast

; an enemy's spell / special attack A (FF1 Enemy_DoMagicEffect)
bt_en_magic:
            call bt_mload
            call bt_ban_spell               ; (its name at the top: owner, 2026-11-23)
            ld a, [bt_who]
            ld [mg_caster], a
            call bt_erec
            ld de, E_AIL
            add hl, de
            bit 6, [hl]
            jr z, bt_cast
            ld a, [bt_who]
            call bt_msg_en
            ld a, [mg_id]
            call bt_mname
            ld hl, bt_sbuf
            call bt_msg_head
            call bt_msg_row
            ld a, M_NOEFFECT
            jp bt_msg_end1

; cast mg_d by mg_caster ($80 + member / enemy) on its targets (FF1's target bits; for an
; enemy caster the sides swap): 1 all foes, 2 one foe, 4 self, 8 all allies, $10 one ally
bt_cast:    ld a, 1                         ; (messages: only what the numbers cannot say)
            ld [bt_quiet], a
            call bt_cast0
            jp bt_ban_off                   ; (the top window gone with the action)
bt_cast0:   ld a, [mg_d + 4]
            and a
            jr nz, .go
            ld a, [mg_caster]               ; no effect: "ineffective"
            call bt_msg_caster
            ld a, $4A
            jp bt_msg_end1
.go:        ld a, [mg_d + 3]
            ld [mg_tgts], a
            ld a, [mg_caster]
            bit 7, a
            jr z, .enemy
            ld a, [mg_tgts]                 ; a member casting
            bit 0, a
            jr nz, .allen
            bit 1, a
            jr nz, .oneen
            bit 2, a
            jr nz, .self
            bit 3, a
            jr nz, .allpl
            ld a, [bt_tgt]
            jp bt_cast_pl
.self:      ld a, [mg_caster]
            and 3
            jp bt_cast_pl
.oneen:     ld a, [bt_tgt]
            jp bt_cast_en
.allen:     ld c, 0
.ae:        ld a, c
            call bt_ealive
            jr z, .aen
            push bc
            ld a, c
            call bt_cast_en
            pop bc
.aen:       inc c
            ld a, c
            cp 9
            jr c, .ae
            ret
.allpl:     xor a
.ap:        push af
            call bt_cast_pl
            pop af
            inc a
            cp 4
            jr c, .ap
            ret
.enemy:     ld a, [mg_tgts]                 ; an enemy casting
            bit 0, a
            jr nz, .allpl
            bit 1, a
            jr nz, .rndpl
            bit 2, a
            jr nz, .eself
            bit 3, a
            jr nz, .allen
            call bt_rnd_enemy               ; one ally: a random enemy
            jp bt_cast_en
.rndpl:     call bt_rnd_member
            jp bt_cast_pl
.eself:     ld a, [mg_caster]
            jp bt_cast_en
; a random living enemy -> A
bt_rnd_enemy:
            call bt_rng
            and 7
            ld b, a
            call bt_rng
            and 1
            add a, b
            call bt_ealive
            jr z, bt_rnd_enemy
            ret

; the caster's name as row 1 (and its spell's name as a result line later)
bt_msg_caster:
            bit 7, a
            jr z, .e
            and 3
            jp bt_msg_pl
.e:         jp bt_msg_en

; ---- one target: the defender's numbers into dv_*, the effect, back
bt_cast_pl: ld [mg_def], a
            ld a, [mg_caster]
            call bt_msg_caster
            ld a, [mg_def]
            call bt_msg_to_pl
            call bt_msg_spell
            ld a, [mg_def]                  ; dead / stone: ineffective
            call ch_rec
            inc hl
            ld a, [hl]
            and AIL_DEAD | AIL_STONE
            jr z, .ok
            ld a, M_NOEFFECT
            jp bt_msg_end1
.ok:        ld a, [mg_caster]               ; FF1 BtlMag_LoadPlayerDefenderStats: a member's
            rlca                            ;   spell the heal sound, an enemy's the "cha"
            ld a, SFX_MAGIC
            jr c, .sf
            ld a, SFX_HIT
.sf:        ld [sfx_req], a
            ld a, [hl]
            ld [dv_ail], a
            ld a, l
            add a, CH_HP - 1
            ld l, a
            ld a, [hl+]
            ld [dv_hp], a
            ld a, [hl+]
            ld [dv_hp + 1], a
            ld a, [hl+]
            ld [dv_max], a
            ld a, [hl]
            ld [dv_max + 1], a
            ld a, [mg_def]
            call bt_cblk
            ld h, d
            ld l, e
            ld a, [hl+]
            ld [dv_hit], a
            ld a, [hl+]
            ld [dv_magdef], a
            ld a, [hl+]
            ld [dv_evade], a
            ld a, [hl+]
            ld [dv_absorb], a
            ld a, [hl+]
            ld [dv_str], a
            ld a, [hl+]
            ld [dv_resist], a
            ld a, [hl]
            ld [dv_hmult], a
            xor a
            ld [dv_weak], a
            ld [dv_cat], a
            ld [dv_morale], a
            ld a, 1
            ld [dv_player], a
            call bt_effect
            ld a, [mg_def]                  ; back
            call bt_cblk
            ld h, d
            ld l, e
            ld a, [dv_hit]
            ld [hl+], a
            ld a, [dv_magdef]
            ld [hl+], a
            ld a, [dv_evade]
            ld [hl+], a
            ld a, [dv_absorb]
            ld [hl+], a
            ld a, [dv_str]
            ld [hl+], a
            ld a, [dv_resist]
            ld [hl+], a
            ld a, [dv_hmult]
            ld [hl], a
            ld a, [mg_def]
            call ch_rec
            inc hl
            ld a, [dv_ail]
            ld [hl], a
            ld a, l
            add a, CH_HP - 1
            ld l, a
            ld a, [dv_hp]
            ld [hl+], a
            ld a, [dv_hp + 1]
            ld [hl], a
            ld a, [mg_def]
            call bt_pline
            ld a, [dv_ail]                  ; out of action: its command dropped (FF1)
            and AIL_DEAD | AIL_STONE | AIL_STUN | AIL_SLEEP
            jr z, .end
            ld a, [mg_def]
            add a, a
            add a, a
            ld e, a
            ld d, 0
            ld hl, bt_cmd
            add hl, de
            ld [hl], 0
.end:       jp bt_msg_end

bt_cast_en: ld [mg_def], a
            ld a, [mg_caster]
            call bt_msg_caster
            ld a, [mg_def]
            call bt_msg_to_en
            call bt_msg_spell
            ld a, [mg_def]
            call bt_ealive
            jr nz, .ok
            ld a, M_NOEFFECT
            jp bt_msg_end1
.ok:        call bt_flush
            ld a, SFX_HIT                   ; FF1 BtlMag_LoadEnemyDefenderStats: "cha" and
            ld [sfx_req], a                 ;   the explosions
            ld a, [mg_def]
            call bt_explode
            ld a, [mg_def]
            call bt_erec
            push hl
            ld de, E_HPMAX
            add hl, de
            ld a, [hl+]
            ld [dv_max], a
            ld a, [hl+]
            ld [dv_max + 1], a
            ld a, [hl+]
            ld [dv_morale], a
            inc hl
            ld a, [hl+]
            ld [dv_evade], a
            ld a, [hl+]
            ld [dv_absorb], a
            inc hl
            ld a, [hl+]
            ld [dv_hit], a
            ld a, [hl+]
            ld [dv_str], a
            inc hl
            inc hl
            inc hl
            ld a, [hl+]
            ld [dv_cat], a
            ld a, [hl+]
            ld [dv_magdef], a
            ld a, [hl+]
            ld [dv_weak], a
            ld a, [hl+]
            ld [dv_resist], a
            ld a, [hl+]
            ld [dv_hp], a
            ld a, [hl+]
            ld [dv_hp + 1], a
            ld a, [hl+]
            ld [dv_ail], a
            ld a, [hl]
            ld [dv_hmult], a
            xor a
            ld [dv_player], a
            call bt_effect
            pop hl                          ; back
            ld de, E_MORALE
            add hl, de
            ld a, [dv_morale]
            ld [hl+], a
            inc hl
            ld a, [dv_evade]
            ld [hl+], a
            ld a, [dv_absorb]
            ld [hl+], a
            inc hl
            ld a, [dv_hit]
            ld [hl+], a
            ld a, [dv_str]
            ld [hl+], a
            ld de, E_RESIST - E_CRIT
            add hl, de
            ld a, [dv_resist]
            ld [hl+], a
            ld a, [dv_hp]
            ld [hl+], a
            ld a, [dv_hp + 1]
            ld [hl+], a
            ld a, [dv_ail]
            ld [hl+], a
            ld a, [dv_hmult]
            ld [hl], a
            ld a, [dv_ail]
            and AIL_DEAD | AIL_STONE
            jp z, bt_msg_end
            ld a, [mg_def]                  ; defeated: off the screen
            call bt_erase_enemy
            ld a, [mg_def]
            ld e, a
            ld d, 0
            ld hl, bt_eid
            add hl, de
            ld [hl], $FF
            jp bt_msg_end
; the spell's name as the first result line
bt_msg_spell:
            ret                             ; (the top window shows the spell: owner, 2026-11-23)

; FF1 BtlMag_PerformSpellEffect: the effect, its message, HP 0 = dead, ailment messages
bt_effect:  ld a, [dv_ail]
            ld [mg_ail0], a
            xor a
            ld [mg_conn], a
            ld a, [mg_d + 4]
            cp 19
            jr c, .j
            xor a
.j:         add a, a
            ld e, a
            ld d, 0
            ld hl, bt_eff_tbl
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            call .jp
            ld a, [mg_conn]                 ; connected: the spell's message (FF1's table;
            and a                           ;   not when a number shows it: owner, 2026-11-23)
            jr z, .nm
            ld a, [dn_t]
            and a
            jr nz, .nm
            ld a, [mg_id]
            ld l, a
            ld h, 0
            ld de, B_MAGMSG
            add hl, de
            ld a, BTL_DATA
            ld [fc_bank], a
            call far_byte
            and a
            call nz, bt_msg_line
.nm:        ld a, [dv_hp]                   ; HP 0: dead
            ld b, a
            ld a, [dv_hp + 1]
            or b
            jr nz, .al
            ld a, [dv_ail]
            or AIL_DEAD
            ld [dv_ail], a
.al:        ld a, [mg_ail0]                 ; ailment changes (FF1 BtlMag_HandleAilmentChanges)
            ld b, a
            ld a, [dv_ail]
            xor b
            ret z
            ld c, a                         ; changed bits
            ld a, [dv_ail]
            and c
            and AIL_DEAD
            jr z, .ch
            ld a, [dv_player]               ; died: slain / terminated
            and a
            ld a, M_SLAIN
            jr nz, .dm
            ld a, M_TERM
.dm:        jp bq_line
.ch:        ld hl, bt_ailtab                ; per bit (confusion first): added / cured
            ld de, bt_curetab
            ld b, $80
.cl:        ld a, c
            and b
            jr z, .cn
            ld a, [dv_ail]
            and b
            push hl
            push de
            push bc
            ld a, [hl]
            jr nz, .add
            ld a, [de]
.add:       call bt_msg_line
            pop bc
            pop de
            pop hl
.cn:        inc hl
            inc de
            srl b
            jr nz, .cl
            ret
.jp:        jp hl
bt_curetab: db $29, $11, $27, $29, $06, $0E, $4A, $20

bt_eff_tbl: dw ef_none, ef_damage, ef_undead, ef_ail, ef_slow, ef_morale, ef_heal, ef_heal
            dw ef_cure, ef_absorb, ef_resist, ef_atk, ef_fast, ef_atk2, ef_evdown, ef_cureall
            dw ef_evup, ef_remres, ef_ail2

ef_none:    ld a, M_NOEFFECT
            jp bt_msg_line
; hit chance: 148, 0 if resisted, +40 if weak (FF1 BtlMag_CalcElemHitChance)
mg_hit_el:  ld a, 148
            ld [mg_hitc], a
            xor a
            ld [mg_hitc + 1], a
            ld a, [mg_d + 2]
            ld b, a
            ld a, [dv_resist]
            and b
            jr z, .w
            xor a
            ld [mg_hitc], a
.w:         ld a, [dv_weak]
            and b
            ret z
            ld a, [mg_hitc]
            add a, 40
            ld [mg_hitc], a
            ld a, [mg_hitc + 1]
            adc a, 0
            ld [mg_hitc + 1], a
            ret
; FF1 BtlMag_PrepHitAndDamage: + hit rate - magic defence (at least 0); damage + random(0..D);
; the random number 0-200
mg_prep:    ld a, [mg_d]
            ld b, a
            ld a, [mg_hitc]
            add a, b
            ld [mg_hitc], a
            ld a, [mg_hitc + 1]
            adc a, 0
            ld [mg_hitc + 1], a
            ld a, [dv_magdef]
            ld b, a
            ld a, [mg_hitc]
            sub b
            ld [mg_hitc], a
            ld a, [mg_hitc + 1]
            sbc a, 0
            ld [mg_hitc + 1], a
            jr nc, .d
            xor a
            ld [mg_hitc], a
            ld [mg_hitc + 1], a
.d:         ld a, [mg_dmg]
            ld b, a
            xor a
            call bt_randab
            ld b, a
            ld a, [mg_dmg]
            add a, b
            ld [mg_dmg], a
            ld a, [mg_dmg + 1]
            adc a, 0
            ld [mg_dmg + 1], a
            xor a
            ld b, 200
            call bt_randab
            ld [mg_rand], a
            ret
; connected: rand != 200 and hit chance >= rand (NC if not)
mg_conn_t:  ld a, [mg_rand]
            cp 200
            jr z, .no
            ld b, a
            ld a, [mg_hitc + 1]
            and a
            jr nz, .yes
            ld a, [mg_hitc]
            cp b
            ret                             ; (C clear: hit chance >= rand)
.yes:       and a
            ret
.no:        scf
            ret
mg_mark:    ld a, 1
            ld [mg_conn], a
            ret
ef_damage:  call mg_mark                    ; FF1 BtlMag_Effect_Damage
            ld a, 148
            ld [mg_hitc], a
            xor a
            ld [mg_hitc + 1], a
            ld [mg_dmg + 1], a
            ld a, [mg_d + 1]
            ld [mg_dmg], a
            ld a, [mg_d + 2]
            ld b, a
            ld a, [dv_resist]
            and b
            jr z, .w
            xor a                           ; resisted: no hit chance, damage halved
            ld [mg_hitc], a
            ld a, [mg_dmg]
            srl a
            ld [mg_dmg], a
.w:         ld a, [dv_weak]
            and b
            jr z, .p
            ld a, [mg_hitc]                 ; weak: +40, damage x 1.5
            add a, 40
            ld [mg_hitc], a
            ld a, [mg_dmg]
            ld c, a
            srl a
            add a, c
            ld [mg_dmg], a
            ld a, [mg_dmg + 1]
            adc a, 0
            ld [mg_dmg + 1], a
.p:         call mg_prep
mg_apply:   call mg_conn_t                  ; connected: damage doubled
            jr c, .s
            ld hl, mg_dmg
            sla [hl]
            inc hl
            rl [hl]
.s:         ld a, [mg_dmg]                  ; HP - damage (at least 0)
            ld b, a
            ld a, [dv_hp]
            sub b
            ld [dv_hp], a
            ld a, [mg_dmg + 1]
            ld b, a
            ld a, [dv_hp + 1]
            sbc a, b
            ld [dv_hp + 1], a
            jr nc, .m
            xor a
            ld [dv_hp], a
            ld [dv_hp + 1], a
.m:         ld a, [mg_dmg]
            ld [nf_val], a
            ld a, [mg_dmg + 1]
            ld [nf_val + 1], a
            xor a
            ld [nf_val + 2], a
            ld a, M_DMG
            call bq_num
            ld hl, mg_dmg                   ; (the number over the target)
            jp bt_dnum_w
ef_undead:  ld a, 148                       ; only undead (category bit 3)
            ld [mg_hitc], a
            xor a
            ld [mg_hitc + 1], a
            ld [mg_dmg + 1], a
            ld a, [mg_d + 1]
            ld [mg_dmg], a
            call mg_prep
            ld a, [dv_cat]
            and $08
            jr nz, .u
            xor a
            ld [mg_conn], a
            ld a, M_NOEFFECT
            jp bt_msg_line
.u:         call mg_mark
            jr mg_apply
mg_statprep:
            call mg_hit_el
            xor a
            ld [mg_dmg], a
            ld [mg_dmg + 1], a
            jp mg_prep
ef_ail:     call mg_statprep                ; ailment if connected
            call mg_conn_t
            ret c
mg_ail_add: ld a, [mg_d + 1]
            ld b, a
            ld a, [dv_ail]
            and b
            jr z, .n
            push bc
            ld a, M_NOEFFECT
            call bt_msg_line
            pop bc
.n:         ld a, [dv_ail]
            or b
            ld [dv_ail], a
            jp mg_mark
ef_slow:    call mg_statprep                ; hits multiplier - 1 (at least 0)
            call mg_conn_t
            ret c
            call mg_mark
            ld a, [dv_hmult]
            and a
            ret z
            dec a
            ld [dv_hmult], a
            ret
ef_morale:  call mg_statprep                ; morale - effectivity (FF1: always applied)
            ld a, [mg_rand]
            cp 200
            ret z
            ld a, [mg_d + 1]
            ld b, a
            ld a, [dv_morale]
            sub b
            jr nc, .s
            xor a
.s:         ld [dv_morale], a
            jp mg_mark
ef_heal:    call mg_mark                    ; HP + random(E .. 2E) (at most 255), at most max
            ld a, [dv_hp]                   ; (before: the green number's base)
            ld [bt_hp0], a
            ld a, [dv_hp + 1]
            ld [bt_hp0 + 1], a
            ld a, [mg_d + 1]
            ld b, a
            xor a
            call bt_randab
            ld b, a
            ld a, [mg_d + 1]
            add a, b
            jr nc, .c
            ld a, $FF
.c:         ld b, a
            ld a, [dv_hp]
            add a, b
            ld [dv_hp], a
            ld a, [dv_hp + 1]
            adc a, 0
            ld [dv_hp + 1], a
            call mg_capmax
            jp bt_healnum
mg_capmax:  ld a, [dv_max]                  ; HP > max: max
            ld b, a
            ld a, [dv_hp]
            sub b
            ld a, [dv_max + 1]
            ld b, a
            ld a, [dv_hp + 1]
            sbc a, b
            ret c
mg_setmax:  ld a, [dv_max]
            ld [dv_hp], a
            ld a, [dv_max + 1]
            ld [dv_hp + 1], a
            ret
ef_cure:    ld a, [mg_d + 1]                ; the effectivity's ailments cured
            cpl
            ld b, a
            ld a, [dv_ail]
            and b
            ld [dv_ail], a
            jp mg_mark
ef_absorb:  ld a, [mg_d + 1]
            ld b, a
            ld a, [dv_absorb]
            add a, b
            jr nc, .s
            ld a, $FF
.s:         ld [dv_absorb], a
            jp mg_mark
ef_resist:  ld a, [mg_d + 1]
            ld b, a
            ld a, [dv_resist]
            or b
            ld [dv_resist], a
            jp mg_mark
ef_atk:     ld a, [mg_d + 1]
            ld b, a
            ld a, [dv_str]
            add a, b
            jr nc, .s
            ld a, $FF
.s:         ld [dv_str], a
            jp mg_mark
ef_fast:    call mg_mark                    ; hits multiplier + 1 (2 at most)
            ld a, [dv_hmult]
            inc a
            cp 3
            jr c, .s
            xor a
            ld [mg_conn], a
            ld a, 2
.s:         ld [dv_hmult], a
            ret
ef_atk2:    ld a, [mg_d]                    ; hit rate + the spell's hit rate, damage + effectivity
            ld b, a
            ld a, [dv_hit]
            add a, b
            jr nc, .h
            ld a, $FF
.h:         ld [dv_hit], a
            jr ef_atk
ef_evdown:  call mg_statprep                ; evasion - effectivity if connected (FF1's bug
            call mg_conn_t                  ;   fixed: it never applied)
            ret c
            ld a, [mg_d + 1]
            ld b, a
            ld a, [dv_evade]
            sub b
            jr nc, .s
            xor a
.s:         ld [dv_evade], a
            jp mg_mark
ef_cureall: call mg_setmax
            xor a
            ld [dv_ail], a
            jp mg_mark
ef_evup:    ld a, [mg_d + 1]
            ld b, a
            ld a, [dv_evade]
            add a, b
            jr nc, .s
            ld a, $FF
.s:         ld [dv_evade], a
            jp mg_mark
ef_remres:  ld a, 148                       ; resistances removed if connected
            ld [mg_hitc], a
            xor a
            ld [mg_hitc + 1], a
            ld a, [mg_d + 2]
            ld b, a
            ld a, [dv_resist]
            and b
            jr z, .w
            xor a
            ld [mg_hitc], a
.w:         ld a, [dv_weak]
            and b
            jr z, .p
            ld a, 188
            ld [mg_hitc], a
.p:         xor a
            ld [mg_dmg], a
            ld [mg_dmg + 1], a
            call mg_prep
            ld a, [mg_rand]
            cp 200
            ret z
            call mg_conn_t
            ret c
            xor a
            ld [dv_resist], a
            jp mg_mark
ef_ail2:    ld a, [mg_d + 2]                ; HP < 300 (and not resisted): the ailment
            ld b, a
            ld a, [dv_resist]
            and b
            ret nz
            ld a, [dv_hp + 1]
            cp 1
            jr c, .y
            jr nz, .no
            ld a, [dv_hp]
            cp $2C
            jr nc, .no
.y:         jp mg_ail_add
.no:        ret

; ---- the AI (FF1 Enemy_DoAi): magic chance, special attack chance, else a physical attack
bt_en_ai:   ld a, [bt_who]
            call bt_erec
            ld de, E_AI
            add hl, de
            ld a, [hl]
            cp $FF
            jr z, .phys
            ld l, a                         ; the AI's 16 bytes
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, B_AI
            add hl, de
            ld de, mg_ai
            ld bc, 16
            ld a, BTL_DATA
            call far_copy
            xor a                           ; random(0..128) < chance: a spell
            ld b, $80
            call bt_randab
            ld b, a
            ld a, [mg_ai]
            cp b
            jr z, .sp
            jr nc, .mag
.sp:        xor a                           ; else < the special chance: a special attack
            ld b, $80
            call bt_randab
            ld b, a
            ld a, [mg_ai + 1]
            cp b
            jr z, .phys
            jr c, .phys
            ld a, [bt_who]                  ; a special attack: the list in turn (4)
            call bt_erec
            ld de, E_AIATK
            add hl, de
.sl:        ld a, [hl]
            and 3
            ld c, a
            inc a
            ld [hl], a
            ld a, c
            add a, 11
            ld e, a
            ld d, 0
            push hl
            ld hl, mg_ai
            add hl, de
            ld a, [hl]
            pop hl
            cp $FF
            jr nz, .sx
            ld [hl], 0
            jr .sl
.sx:        add a, $42
            jp bt_en_magic
.mag:       ld a, [bt_who]                  ; a spell: the list in turn (8)
            call bt_erec
            ld de, E_AIMAG
            add hl, de
.ml:        ld a, [hl]
            and 7
            ld c, a
            inc a
            ld [hl], a
            ld a, c
            add a, 2
            ld e, a
            ld d, 0
            push hl
            ld hl, mg_ai
            add hl, de
            ld a, [hl]
            pop hl
            cp $FF
            jr nz, bt_en_magic
            ld [hl], 0
            jr .ml
.phys:      call bt_rnd_member
            jp bt_en_attack

; ---- Medicine (FF1 BattleSubMenu_Drink): Potion / Antidote with their counts this battle
bt_cmd_drink:
            call bt_msg_win
            xor a
            ld [bt_rows], a
            ld c, 0
.r:         push bc
            ld b, 18
            call vwf_clr
            pop bc
            push bc
            ld a, c
            add a, $40
            call bt_mname
            ld hl, bt_sbuf
            ld a, 8
            call vwf_str
            pop bc
            push bc
            ld e, c
            ld d, 0
            ld hl, bt_pots
            add hl, de
            ld a, [hl]
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
            call vwf_str
            call bt_mrow
            pop bc
            inc c
            ld a, c
            cp 2
            jr c, .r
            xor a
            ld [bt_mcur], a
.l:         ld a, [bt_mcur]                 ; (the text at x 16: the hand 17 px left)
            add a, 13
            add a, a
            add a, a
            add a, a
            ld c, a
            ld b, 16 - 17
            call bt_hand
            call bt_frame
            ldh a, [pad_new]
            bit 1, a
            jr nz, .b
            bit 0, a
            jr nz, .a
            and $C0
            jr z, .l
            ld a, [bt_mcur]
            xor 1
            ld [bt_mcur], a
            jr .l
.a:         ld a, [bt_mcur]                 ; none left: no
            ld e, a
            ld d, 0
            ld hl, bt_pots
            add hl, de
            ld a, [hl]
            and a
            jr z, .l
            push hl
            call bt_hand_off
            call bt_msg_close
            call bt_names_win
            ld a, [bt_mcur]                 ; (the Potion: not on a member at full HP)
            and a
            jr nz, .an
            call bt_target_heal
            jr .at
.an:        call bt_target_member
.at:        pop hl
            ret c
            dec [hl]                        ; (one fewer to choose this round)
            ld b, a
            call bt_commands.slot
            ld [hl], $08
            inc hl
            ld a, [bt_mcur]
            add a, $40
            ld [hl+], a
            ld [hl], b
            inc hl
            ld a, [bt_mcur]
            ld [hl], a
            and a
            ret
.b:         call bt_hand_off
            call bt_msg_close
            scf
            ret
; a member drinks (FF1 Player_DoDrink): the item used, the potion's magic
bt_pl_drink:
            inc hl
            ld a, [hl+]
            ld [mg_id], a
            ld a, [hl+]
            ld [bt_tgt], a
            ld a, [hl]                      ; 0 Potion, 1 Antidote: one fewer
            add a, low(ITEMS + $19)
            ld l, a
            ld h, high(ITEMS)
            ld a, [hl]
            and a
            jr z, .z
            dec [hl]
.z:         ld a, [mg_id]
            call bt_mload
            xor a                           ; FF1: an item's spell: the walk and the cheer,
            ld [bt_ag], a                   ;   nothing drawn
            ld a, [bt_who]
            call bt_cast_anim
            ld a, [bt_who]
            or $80
            ld [mg_caster], a
            jp bt_cast

; ---- Items (FF1 BattleSubMenu_Item): the member's weapons, then armour (a page each, left /
; right turns); one with a spell casts it
bt_cmd_item:
            xor a
            ld [bt_mpage], a
.pg:        call bt_msg_win
            xor a
            ld [bt_rows], a
            ld c, 0
.r:         push bc
            ld b, 18
            call vwf_clr
            pop bc
            push bc
            call bt_islot                   ; A = the item's name id (0: empty)
            and a
            jr z, .e
            call bt_mname_item
            ld hl, bt_sbuf
            ld a, 8
            call vwf_str
.e:         call bt_mrow
            pop bc
            inc c
            ld a, c
            cp 4
            jr c, .r
            xor a
            ld [bt_mcur], a
.l:         ld a, [bt_mcur]                 ; (the text at x 16: the hand 17 px left)
            add a, 13
            add a, a
            add a, a
            add a, a
            ld c, a
            ld b, 16 - 17
            call bt_hand
            call bt_frame
            ldh a, [pad_new]
            bit 1, a
            jr nz, .b
            bit 0, a
            jr nz, .a
            bit 4, a
            jr nz, .flip
            bit 5, a
            jr nz, .flip
            ld hl, bt_mcur
            bit 6, a
            jr nz, .up
            bit 7, a
            jr z, .l
            ld a, [hl]
            inc a
            and 3
            ld [hl], a
            jr .l
.up:        ld a, [hl]
            dec a
            and 3
            ld [hl], a
            jr .l
.flip:      ld a, [bt_mpage]
            xor 1
            ld [bt_mpage], a
            jp .pg
.a:         ld a, [bt_mcur]                 ; its spell (data byte 3; 0: none)
            ld c, a
            call bt_islot
            and a
            jr z, .l
            call bt_ispell
            and a
            jr z, .l
            dec a
            ld [bt_t + 7], a
            call bt_hand_off
            call bt_msg_close
            call bt_names_win
            ld a, [bt_t + 7]
            call bt_mload
            ld a, [mg_d + 3]
            bit 1, a
            jr nz, .en
            bit 4, a
            jr nz, .me
            xor a
            jr .set
.en:        call bt_target_enemy
            ret c
            jr .set
.me:        call bt_target_member
            ret c
.set:       ld b, a
            call bt_commands.slot
            ld [hl], $10
            inc hl
            ld a, [bt_t + 7]
            ld [hl+], a
            ld [hl], b
            and a
            ret
.b:         call bt_hand_off
            call bt_msg_close
            scf
            ret
; slot C of the page (weapons / armour) -> A = the name id (0: empty), bt_t+8 = the index
bt_islot:   ld a, [bt_cm]
            rrca
            rrca
            ld b, a
            ld a, [bt_mpage]
            and a
            ld a, $18
            jr z, .w
            ld a, $1C
.w:         add a, b
            add a, c
            ld l, a
            ld h, high(ch_stats)
            ld a, [hl]
            and $7F
            ld [bt_t + 8], a
            ret z
            ld b, a
            ld a, [bt_mpage]
            and a
            ld a, 27                        ; weapons: name 27 + n, armour 67 + n
            jr z, .n
            ld a, 67
.n:         add a, b
            ret
; the name of item id A (the names bank) -> bt_sbuf
bt_mname_item:
            ld l, a
            ld h, 0
            add hl, hl
            ld de, $4000
            add hl, de
            ld de, bt_sbuf
            ld bc, 2
            ld a, NAMES
            call far_copy
            ld a, [bt_sbuf]
            ld l, a
            ld a, [bt_sbuf + 1]
            ld h, a
            ld de, bt_sbuf
            ld bc, 20
            ld a, NAMES
            jp far_copy
; the spell of item bt_t+8 (weapon / armour data byte 3) -> A
bt_ispell:  ld a, [bt_t + 8]
            dec a
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            ld a, [bt_mpage]
            and a
            jr nz, .ar
            add hl, hl
            ld de, N_WSTAT + 3
            jr .g
.ar:        ld de, N_ASTAT + 3
.g:         add hl, de
            ld a, NAMES
            ld [fc_bank], a
            jp far_byte
; a member uses an item (FF1 Player_DoItem): its spell
bt_pl_item: inc hl
            ld a, [hl+]
            ld [mg_id], a
            ld a, [hl]
            ld [bt_tgt], a
            ld a, [mg_id]
            call bt_mload
            xor a                           ; FF1: an item's spell: the walk and the cheer,
            ld [bt_ag], a                   ;   nothing drawn
            ld a, [bt_who]
            call bt_cast_anim
            ld a, [bt_who]
            or $80
            ld [mg_caster], a
            jp bt_cast

; a member for an HP-recovering spell / the Potion: one at full HP refused with the message
; bt_s_noeff (owner, 2026-11-22), the hand back where it was; A = member, C set on B
bt_target_heal:
            call bt_target_member
.c:         ret c
            push af
            call ch_rec
            inc hl                          ; (dead / stone: as FF1, allowed)
            ld a, [hl-]
            cp 1
            jr z, .ok
            cp 2
            jr z, .ok
            ld a, l
            add a, CH_HP
            ld l, a
            ld a, [hl+]
            ld e, a
            ld a, [hl+]
            ld d, a
            ld a, [hl+]
            cp e
            jr nz, .ok
            ld a, [hl]
            cp d
            jr nz, .ok
            pop af
            call sfx_err
            call bt_msg_new
            ld hl, bt_s_noeff
            call bt_msg_row
            call bt_msg_end
            call bt_names_win
            call bt_tm_again
            jr .c
.ok:        pop af
            and a
            ret
bt_s_noeff: db "It wouldn't have any effect.", 0

section wram, $C680
mg_d:       ds 8
mg_id:      ds 1
mg_caster:  ds 1
mg_def:     ds 1
mg_tgts:    ds 1
mg_conn:    ds 1
mg_ail0:    ds 1
mg_hitc:    ds 2
mg_dmg:     ds 2
mg_rand:    ds 1
mg_ai:      ds 16
bt_mcur:    ds 1
bt_mpage:   ds 1
bt_mlv:     ds 1
dv_hp:      ds 2
dv_max:     ds 2
dv_ail:     ds 1
dv_magdef:  ds 1
dv_resist:  ds 1
dv_weak:    ds 1
dv_cat:     ds 1
dv_absorb:  ds 1
dv_str:     ds 1
dv_evade:   ds 1
dv_hmult:   ds 1
dv_morale:  ds 1
dv_hit:     ds 1
dv_player:  ds 1
bt_pots:    ds 2

section bank 6, $7F40                       ; (the spell list's helpers: bank 6 was full)
; "L<n> MP <left>" of level [bt_t+6] at pixel A
bt_mhdr:    push af
            ld hl, bt_sbuf
            ld a, $4C
            ld [hl+], a
            ld a, [bt_t + 6]
            add a, $31
            ld [hl+], a
            ld a, $20
            ld [hl+], a
            ld a, $4D
            ld [hl+], a
            ld a, $50
            ld [hl+], a
            ld a, $20
            ld [hl+], a
            push hl
            call bt_mdata
            ld a, [bt_t + 6]
            add a, $20
            add a, l
            ld l, a
            ld a, [hl]
            call nf_a
            call num_fmt
            pop de
            ld hl, nf_dig + 5
            ld a, [nf_dig + 4]
            cp $20
            jr z, .one
            dec hl
.one:       ld a, [hl+]
            ld [de], a
            inc de
            ld a, l
            cp low(nf_dig + 6)
            jr nz, .one
            xor a
            ld [de], a
            ld hl, bt_sbuf
            pop af
            jp vwf_str
; Z: no spell on page B / 2 (levels B & 6, B & 6 + 1)
bt_mpgemp:  call bt_mdata
            ld a, b
            and 6
            add a, a
            add a, a
            add a, l
            ld l, a
            ld a, [hl+]
            or [hl]
            inc hl
            or [hl]
            inc hl
            inc hl
            or [hl]
            inc hl
            or [hl]
            inc hl
            or [hl]
            ret
