; FF1 native engine: battle additions from the owner's review of the WonderSwan Color remake
; (2026-11-22): an acting enemy flashes, the hit count over the attacker, the enemies' counts in
; the names window, members darting forward to swing / cast. Our own code; the silhouettes and
; the label tiles are made at build time (battle.py sil_banks / hit_tiles).

ESIL_BANK  = 100            ; enemy silhouettes (2 banks, ENEMY_CHR's layout)
HITL_BANK  = 102            ; "n HIT(S)" labels: 3 sprite tiles each, n = 1-39
TRANS_BANK = 103            ; the encounter transition's tables (battle.py trans_tables)
FL_T0      = $C4            ; free BG tiles while the names window shows (it uses $A8-$C3)
HL_OAM     = oam_buf + 128  ; the label: OAM 32-34 (the damage number: 35-39)
HL_T0      = $F4            ; its tiles ($F4: "MISS!" only, never shown with a label)
CL_OAM     = oam_buf + 112  ; "CRITICAL!": OAM 28-31 (the bubbles' / bursts'), with the number
CL_T0      = $EC            ;   tiles $EC-$EF (the message window's last cells: not while it shows)

section bank 6, $7D00

; ---- an enemy about to act flashes (owner, 2026-11-22, as the WonderSwan Color remake; the
; one blink the owner wants): white silhouette, black one with a white outline, twice, 4 frames
; each (Color: palettes 6 / 7 on silhouette tiles); DMG / SGB: white silhouette and the picture
; in turn. Fiends / Chaos: the Color turns their palettes white in turn (DMG / SGB: none).
bt_eflash:  call bt_flush                   ; (the flash itself: bank BTL6, btl6 part of btl5)
            ld a, [bt_type]
            cp 3
            jr nc, fl_fiend
            ld a, [bt_who]
            call bt_epos                    ; B, C = cell, E = size, D = first tile
            ld hl, fl_b
            ld a, b
            ld [hl+], a
            ld a, c
            ld [hl+], a
            ld a, e
            ld [hl+], a
            ld a, d
            ld [hl], a
            ld a, BTL6_BANK
            ld hl, fl_main
            jp bank_call
fl_fiend:   ld a, BTL6_BANK
            ld hl, fl_fiend6
            jp bank_call

bt_pal5:    ld hl, pal5_tab                 ; (all 48 bytes corrected at once: HL then walks
            ld b, 48                        ;   the corrected copy through both loops)
            call cc_copy                    ; (the LCD colour mode: cc.s)
            ld b, 16
.o:         ld a, [hl+]
            call ocpd_w
            dec b
            jr nz, .o
            ld a, $80 | (4 * 8)             ; (BG 4 / 5: the party lines' yellow / red)
            call bcps_w
            ld b, 32
.g:         ld a, [hl+]
            call bcpd_w
            dec b
            jr nz, .g
            ret

; ---- the hit count over the attacker (after the damage number): mt_conn hits, "n HIT(S)"
; (owner, 2026-11-22: as the WonderSwan Color remake), gold on the Color, white on DMG / SGB
bt_hitlab:  ld a, [mt_conn]
            and a
            ret z
            cp 40
            jr c, .n
            ld a, 39
.n:         dec a                           ; HL = $4000 + 48 (n - 1)
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld d, h
            ld e, l
            add hl, hl
            add hl, de
            ld de, $4000
            add hl, de
            push hl
            call bt_flush
            pop hl
            ld de, bt_stage
            ld bc, 48
            ld a, HITL_BANK
            call far_copy
            ld a, low(bt_stage)
            ld [bt_upsrc], a
            ld a, high(bt_stage)
            ld [bt_upsrc + 1], a
            ld a, low($8000 + 16 * HL_T0)
            ld [bt_updst], a
            ld a, high($8000 + 16 * HL_T0)
            ld [bt_updst + 1], a
            ld a, 3
            ld [bt_upn], a
            call bt_flush
            ld a, [df_player]
            and a
            jr nz, .en
            ld a, [bt_who]                  ; a member: left of its sprite, at its head
            call bt_mxy
            ld a, b
            sub 25
            ld b, a
            jr .put
.en:        ld a, [bt_who]                  ; an enemy: centred on its top row
            call bt_epos
            ld a, b
            add a, a
            add a, a
            add a, a
            ld b, a
            ld a, e
            add a, a
            add a, a
            add a, b
            sub 4
            ld b, a
            ld a, c
            add a, a
            add a, a
            add a, a
            add a, 16
            ld c, a
.put:       ld hl, HL_OAM
            ld d, HL_T0
            ld e, 3
.o:         ld a, c
            ld [hl+], a
            ld a, b
            ld [hl+], a
            add a, 8
            ld b, a
            ld a, d
            ld [hl+], a
            inc d
            ld a, $15                       ; (CGB OBJ palette 5; DMG / SGB OBP1)
            ld [hl+], a
            dec e
            jr nz, .o
            ret

; ---- the enemy names window: the name (clipped to 51 pixels) and the kind's count in the
; narrow digits at its right end (owner, 2026-11-22: "Goblin 3"); HL = the name -> vw_buf
; (a name too long is cut at 47 pixels and ends in ".", a gap before the count: owner's audit,
; 2026-11-25: "Tyrannosaur1")
bt_nstr:    push hl                         ; (its right limit: bank BTL6 bt_nmeas)
            ld a, BTL6_BANK
            ld hl, bt_nmeas
            call bank_call
            xor a
            ld [vw_x], a
            pop hl
.c:         ld a, [hl+]
            and a
            jr z, .cnt
            push hl
            push af
            call bt_gw                      ; its width (with the gap) -> A
            ld b, a
            ld a, [vw_x]
            add a, b
            ld hl, bt_nlim
            cp [hl]
            jr nc, .cut
            pop af
            call vwf_ch
            pop hl
            jr .c
.cut:       pop af
            pop hl
            ld a, $2E                       ; "."
            call vwf_ch
.cnt:       ld a, [bt_t + 13]
            ld b, a
            ld hl, bt_eid
            ld c, 9
            ld d, $80                       ; (the narrow digits: codes $80-$89)
.l:         ld a, [hl+]
            cp b
            jr nz, .n
            inc d
.n:         dec c
            jr nz, .l
            ld a, 53
            ld [vw_x], a
            ld a, d
            jp vwf_ch
; ---- a member darts forward / back (owner, 2026-11-22: moving forward while swinging or
; casting, not FF1's slow walk): A = member, B = pixels a frame, C = pose; 2 frames
bt_dart:    ld [bt_am], a
            ld a, b
            ld [bt_ad], a
            ld a, c
            ld [dt_pose], a
            ld a, 2
.l:         push af
            ld a, [bt_am]
            ld e, a
            ld d, 0
            ld hl, bt_pose
            add hl, de
            ld a, [dt_pose]
            ld [hl], a
            ld hl, bt_px
            add hl, de
            ld a, [bt_ad]
            add a, [hl]
            ld [hl], a
            ld a, [bt_am]
            call bt_dm
            call bt_frame
            pop af
            dec a
            jr nz, .l
            ret

; ---- the party walks in from the right before the first command (owner, 2026-11-22): each
; living member from past the screen's edge (8 pixels apart), 2 pixels a frame, FF1's walking
; pose every 4 frames; then everyone's natural pose
bt_walkin:  ld b, 0
.i:         ld a, b
            push bc
            call ch_rec
            pop bc
            inc hl
            ld a, [hl]
            and AIL_DEAD | AIL_STONE
            ld e, b
            ld d, 0
            ld hl, bt_px
            add hl, de
            jr nz, .n                       ; (the fallen: in place)
            ld a, b
            add a, a
            add a, a
            add a, a
            add a, 160
            ld [hl], a
.n:         inc b
            ld a, b
            cp 4
            jr c, .i
            xor a
            ld [dt_pose], a                 ; (the frame count)
.f:         ld c, 0                         ; members still walking
            ld b, 0
.m:         ld e, b
            ld d, 0
            ld hl, bt_px
            add hl, de
            ld a, [hl]
            cp PARTY_X + 1
            jr c, .nx
            sub 2
            ld [hl], a
            inc c
            ld hl, bt_pose
            add hl, de
            ld a, [dt_pose]
            and 4                           ; walk / stand every 4 frames
            ld [hl], a
            push bc
            ld a, b
            call bt_dm
            pop bc
.nx:        inc b
            ld a, b
            cp 4
            jr c, .m
            ld a, c
            and a
            jr z, .x
            push bc
            call bt_frame
            pop bc
            ld hl, dt_pose
            inc [hl]
            jr .f
.x:         jp bt_party_upd

section bank 6, $7EEB
; ---- a critical hit (owner, 2026-11-25): "CRITICAL!" (battle.py: after the hit labels) beside
; the member it concerns (the attacker; the member hit when an enemy struck), gold, before the
; hit count and the damage number; tiles $F0-$F3 (the damage number's, not up yet)
bt_critlab: ld a, [mt_crits]
            and a
            ret z
            ld a, [bt_defer]
            and a
            ret nz
            ld a, [bt_msgon]                ; (its tiles are the message window's last four)
            and a
            ret nz
            call bt_flush
            ld hl, $4000 + 39 * 48          ; (staged after the damage number's glyphs)
            ld de, bt_stage + 128
            ld bc, 64
            ld a, HITL_BANK
            call far_copy
            ld hl, bt_upsrc
            ld a, low(bt_stage + 128)
            ld [hl+], a
            ld [hl], high(bt_stage + 128)
            ld hl, bt_updst
            ld a, low($8000 + 16 * CL_T0)
            ld [hl+], a
            ld [hl], high($8000 + 16 * CL_T0)
            ld a, 4
            ld [bt_upn], a
            call bt_flush
            ld a, [df_player]
            and a
            ld a, [bt_who]
            jr z, .m
            ld a, [bt_tgt]
            and 3
.m:         call bt_mxy                     ; left of the sprite, at its head
            ld a, b
            sub 33
            ld b, a
            jp crit_y

section bank 6, $7FE8
; every battle frame: the ailment bubbles (bank 104: btl6.s), then the damage number's bounce
bt_fhook:   push bc
            push de
            push hl
            ld a, BTL6_BANK
            ld hl, bub_tick
            call bank_call
            pop hl
            pop de
            pop bc
            jp bt_danim

section bank 6, $5DBF
crit_put:   ld hl, CL_OAM                   ; (shown with the damage number, OAM 28-31: the
            ld d, CL_T0                     ;   bubbles wait; bub_tick takes it away with the
            ld e, 4                         ;   number)
.o:         ld a, c
            ld [hl+], a
            ld a, b
            ld [hl+], a
            add a, 8
            ld b, a
            ld a, d
            ld [hl+], a
            inc d
            ld a, $15                       ; (CGB OBJ palette 5, gold; DMG / SGB OBP1)
            ld [hl+], a
            dec e
            jr nz, .o
            ld a, 1
            ld [crit_on], a
            ret

section wram, $C760
fl_b:       ds 1                            ; the flashing enemy: cell, size, first tile
fl_c:       ds 1
fl_e:       ds 1
fl_d:       ds 1
fl_bk:      ds 1
fl_n:       ds 1
fl_k:       ds 1
fl_md:      ds 1
fl_t:       ds 1
fl_vb:      ds 1
dt_pose:    ds 1
fl_tb:      ds 72                           ; tiles (36), attributes (36)
bt_defer:   ds 1                            ; bt_phys working out the result only (no text, no numbers)
bt_sv:      ds 4                            ; (the RNG and the defender's HP / ailments meanwhile)
bt_swn:     ds 1                            ; swings left
ex_one:     ds 1                            ; bt_explode: one burst
bt_quiet:   ds 1                            ; messages: only what the numbers cannot say
ban_w:      ds 1
dn_attr:    ds 1                            ; the number's OAM attribute
bt_hp0:     ds 2                            ; HP before a heal
ban_last:   ds 1                            ; the target whose name the top window shows

section bank 6, $733B                       ; (free space after the Konami Code's multipliers)
; glyph A's advance: a space 3, a glyph its width + 1
bt_gw:      cp $20
            jr nz, .g
            ld a, 3
            ret
.g:         sub $21
            ld l, a
            ld h, 0
            ld e, l
            ld d, h
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, de
            ld de, vwf_glyphs
            add hl, de
            ld a, BTL6_BANK
            ld [fc_bank], a
            call far_byte
            inc a
            ret

section bank 104, $7F00
; bt_nstr's limit for the name in bt_sbuf: 53 when it fits (up to 51 pixels), else 47 (cut, ".")
bt_nmeas:   ld hl, bt_sbuf
            ld c, 0
.m:         ld a, [hl+]
            and a
            jr z, .d
            cp $20
            ld b, 3
            jr z, .a
            push hl
            sub $21
            ld l, a
            ld h, 0
            ld e, l
            ld d, h
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, de
            ld de, vwf_glyphs
            add hl, de
            ld b, [hl]
            inc b
            pop hl
.a:         ld a, c
            add a, b
            ld c, a
            jr .m
.d:         ld a, c
            cp 53
            ld a, 53
            jr c, .s
            ld a, 47
.s:         ld [bt_nlim], a
            ret

section wram, $CF75                         ; (free fixed RAM)
bt_nlim:    ds 1                            ; bt_nstr: the name's right limit
crit_on:    ds 1                            ; "CRITICAL!" showing (OAM 28-31)

section bank 6, $7465                       ; (free space)
; battle start: no member's tile holds a bubble yet (bt_ail_in)
bub_init:   xor a
            ld hl, bub_cur
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl], a
            ld [crit_on], a                 ; (no "CRITICAL!" left over)
            ret

section bank 6, $7EB6                       ; (free space)
; "CRITICAL!" a line under what it would cover (owner, 2026-11-25): a member's hit: its hit count
; (at the head); a member hit: the damage number (left of the sprite, bouncing upwards)
crit_y:     ld a, [df_player]
            and a
            ld a, 10
            jr z, .y
            ld a, 18
.y:         add a, c
            ld c, a
            jp crit_put
