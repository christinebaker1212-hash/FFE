; FF1 native engine: battle additions from the owner's review of the WonderSwan Color remake
; (2026-11-22): an acting enemy flashes, the hit count over the attacker, the enemies' counts in
; the names window, members darting forward to swing / cast. Our own code; the silhouettes and
; the label tiles are made at build time (battle.py sil_banks / hit_tiles).

ESIL_BANK  = 100            ; enemy silhouettes (2 banks, ENEMY_CHR's layout)
HITL_BANK  = 102            ; "n HIT(S)" labels: 3 sprite tiles each, n = 1-39
FL_T0      = $C4            ; free BG tiles while the names window shows (it uses $A8-$C3)
HL_OAM     = oam_buf + 128  ; the label: OAM 32-34 (the damage number: 35-39)
HL_T0      = $F4            ; its tiles ($F4: "MISS!" only, never shown with a label)

section bank 6, $7C00

; ---- an enemy about to act flashes (owner, 2026-11-22, as the WonderSwan Color remake; the
; one blink the owner wants): white silhouette, black one with a white outline, twice, 4 frames
; each (Color: palettes 6 / 7 on silhouette tiles); DMG / SGB: white silhouette and the picture
; in turn. Fiends / Chaos: the Color turns their palettes white in turn (DMG / SGB: none).
bt_eflash:  call bt_flush
            ld a, [bt_type]
            cp 3
            jp nc, fl_fiend
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
            ld a, [bt_form]                 ; source: the silhouette page, tile D
            and $0F
            ld b, a
            and 7
            add a, a
            add a, a
            add a, a
            add a, $40
            ld h, a
            ld l, 0
            ld a, d
            swap a
            ld e, a
            and $0F
            ld d, a
            ld a, e
            and $F0
            ld e, a
            add hl, de
            ld a, b
            cp 8
            ld a, ESIL_BANK
            jr c, .bk
            inc a
.bk:        ld [fl_bk], a
            ld de, $8000 + 16 * FL_T0       ; destination
            ld a, [fl_e]                    ; tiles: 16 / 36
            cp 4
            ld a, 16
            jr z, .n
            ld a, 36
.n:         ld [fl_n], a
.bat:       ld a, [fl_n]                    ; batches of up to 18 (bt_stage)
            cp 18
            jr c, .k
            ld a, 18
.k:         ld [fl_k], a
            push de
            push hl
            call fl_bc16
            ld de, bt_stage
            ld a, [fl_bk]
            call far_copy
            ldh a, [is_cgb]
            and a
            jr nz, .st
            ld hl, bt_stage                 ; DMG / SGB: the silhouette white (colour 0) on
            ld a, [fl_k]                    ;   black (3): both planes = not its pixels
            add a, a
            add a, a
            add a, a
            ld b, a
.dm:        inc hl
            ld a, [hl-]
            cpl
            ld [hl+], a
            ld [hl+], a
            dec b
            jr nz, .dm
.st:        pop hl
            pop de
            ld a, low(bt_stage)
            ld [bt_upsrc], a
            ld a, high(bt_stage)
            ld [bt_upsrc + 1], a
            ld a, e
            ld [bt_updst], a
            ld a, d
            ld [bt_updst + 1], a
            ld a, [fl_k]
            ld [bt_upn], a
            push hl
            call bt_flush
            pop hl
            call fl_bc16                    ; next batch
            add hl, bc
            ld a, [bt_updst]
            ld e, a
            ld a, [bt_updst + 1]
            ld d, a
            ld a, [fl_k]
            ld b, a
            ld a, [fl_n]
            sub b
            ld [fl_n], a
            jr nz, .bat
            ld a, 1                         ; W, B, W, B (DMG: W, picture, W, picture)
            call fl_phase
            ld a, 2
            call fl_phase
            ld a, 1
            call fl_phase
            ld a, 2
            call fl_phase
            xor a                           ; the picture again
            call fl_fill
            jp fl_put
; BC = 16 fl_k
fl_bc16:    ld a, [fl_k]
            swap a
            ld c, a
            and $0F
            ld b, a
            ld a, c
            and $F0
            ld c, a
            ret
; one phase A (1 W, 2 B), shown 4 frames
fl_phase:   call fl_fill
            call fl_put
            ld b, 3
.w:         push bc
            call bt_frame
            pop bc
            dec b
            jr nz, .w
            ret
; the cells' tiles / attributes for phase A (0: the picture, from the map copy) -> fl_tb, fl_ab
fl_fill:    ld [fl_md], a
            ld c, a
            ldh a, [is_cgb]
            and a
            jr nz, .c
            ld a, c                         ; DMG: B = the picture
            cp 2
            jr nz, .c
            xor a
            ld [fl_md], a
.c:         ld a, [fl_b]
            ld b, a
            ld a, [fl_c]
            ld c, a
            call cell_addr
            ld de, fl_tb
            ld a, FL_T0
            ld [fl_t], a
            ld a, [fl_e]
            ld c, a
.r:         push hl
            ld a, [fl_e]
            ld b, a
.x:         ld a, [fl_md]
            and a
            jr z, .p
            ld a, [fl_t]                    ; silhouette tile, palette 5 + phase
            ld [de], a
            inc a
            ld [fl_t], a
            ld a, [fl_md]
            add a, 5
            jr .s
.p:         ld a, [hl]                      ; the picture
            ld [de], a
            push hl
            ld a, h
            add a, 3
            ld h, a
            ld a, [hl]
            pop hl
.s:         push de
            push af
            ld a, e
            add a, 36
            ld e, a
            jr nc, .s1
            inc d
.s1:        pop af
            ld [de], a
            pop de
            inc de
            inc hl
            dec b
            jr nz, .x
            pop hl
            ld a, l
            add a, 32
            ld l, a
            jr nc, .s2
            inc h
.s2:        dec c
            jr nz, .r
            ret
; fl_tb (and on the Color fl_ab) into the screen's cells, a row at a time in V-Blank
fl_put:     call wait_vbl
            ld a, [fl_b]
            ld b, a
            ld a, [fl_c]
            ld c, a
            call cell_addr
            ld de, $9800 - smap
            add hl, de
            ld d, h
            ld e, l
            ld hl, fl_tb
            xor a
            call .pass
            ldh a, [is_cgb]
            and a
            ret z
            ld hl, fl_tb + 36
            ld a, 1
.pass:      push de
            ld [fl_vb], a
            ld a, [fl_e]
            ld c, a
.r:         ldh a, [rLY]
            cp 144
            jr c, .w
            cp 152
            jr nc, .w
            ld a, [fl_vb]
            ldh [rVBK], a
            ld a, [fl_e]
            ld b, a
            push de
.c:         ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .c
            pop de
            xor a
            ldh [rVBK], a
            ld a, e
            add a, 32
            ld e, a
            jr nc, .n
            inc d
.n:         dec c
            jr nz, .r
            pop de
            ret
.w:         push hl
            push de
            push bc
            call wait_vbl
            pop bc
            pop de
            pop hl
            jr .r
; fiends / Chaos (alone on the field): the Color turns BG palettes 1-2 white and back
fl_fiend:   ldh a, [is_cgb]
            and a
            ret z
            ld hl, fl_tb                    ; (their colours, as bt_pal makes them)
            ld a, [bt_form + 10]
            call .mk
            ld a, [bt_form + 11]
            call .mk
            ld b, 4
.ph:        push bc
            call wait_vbl
            ld a, $88
            ldh [rBCPS], a
            pop bc
            push bc
            bit 0, b
            jr nz, .back
            ld c, 2                         ; white (colour 0 kept black)
.wp:        xor a
            ldh [rBCPD], a
            ldh [rBCPD], a
            ld b, 3
.wc:        ld a, $FF
            ldh [rBCPD], a
            ld a, $7F
            ldh [rBCPD], a
            dec b
            jr nz, .wc
            dec c
            jr nz, .wp
            jr .hold
.back:      ld hl, fl_tb
            ld b, 16
.bc:        ld a, [hl+]
            ldh [rBCPD], a
            dec b
            jr nz, .bc
.hold:      ld b, 3
.h:         push bc
            call bt_frame
            pop bc
            dec b
            jr nz, .h
            pop bc
            dec b
            jr nz, .ph
            ret
.mk:        push hl                         ; battle palette A -> 8 bytes at HL
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            ld de, B_PALS
            add hl, de
            ld de, scr_buf
            ld bc, 4
            ld a, BTL_DATA
            call far_copy
            ld a, $0F
            ld [scr_buf], a
            pop hl
            ld c, 0
.k:         push hl
            push bc
            ld b, 0
            ld hl, scr_buf
            add hl, bc
            ld a, [hl]
            call nes_rgb
            pop bc
            pop hl
            ld a, e
            ld [hl+], a
            ld a, d
            ld [hl+], a
            inc c
            ld a, c
            cp 4
            jr nz, .k
            ret

; ---- the CGB palettes for the additions (the end of bt_pal; OCPS at OBJ palette 5): OBJ 5 the
; hit label (gold ink, black outline), BG 6 / 7 the flash (white silhouette / black one with a
; white outline)
bt_pal5:    ld hl, pal5_tab
            ld b, 8
.o:         ld a, [hl+]
            ldh [rOCPD], a
            dec b
            jr nz, .o
            ld a, $80 | (6 * 8)
            call bcps_w
            ld b, 16
.g:         ld a, [hl+]
            call bcpd_w
            dec b
            jr nz, .g
            ret
pal5_tab:   db $00, $00, $DF, $0A, $FF, $7F, $00, $00
            db $00, $00, $00, $00, $FF, $7F, $FF, $7F
            db $00, $00, $FF, $7F, $00, $00, $00, $00

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
            ld a, [hl]
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
