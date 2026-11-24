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

bt_pal5:    ld hl, pal5_tab
            ld b, 16
            call cc_copy                    ; (the LCD colour mode: cc.s)
.o:         ld a, [hl+]
            ldh [rOCPD], a
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
bt_nstr:    xor a
            ld [vw_x], a
.c:         ld a, [hl+]
            and a
            jr z, .cnt
            push hl
            push af
            call bt_gw                      ; its width (with the gap) -> A
            ld b, a
            ld a, [vw_x]
            add a, b
            cp 53                           ; (right edge past 51: stop)
            jr nc, .cut
            pop af
            call vwf_ch
            pop hl
            jr .c
.cut:       pop af
            pop hl
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
