; FF1 native engine: battle (code bank BTL_BANK). Our own code, written from what FF1's battle
; routines do (disassembly banks 0B / 0C: PrepareEnemyFormation, the battle loop, formulas,
; AI, magic, rewards); data from the ROM (tools/gbn/battle.py). Approved Game Boy layout:
; enemies in cols 1-14 rows 0-11 (FF1's enemy box), the party's sprites in their own column
; (x 132, a step forward to 124), at the bottom (rows 12-17) the left window (commands,
; enemy names; 9 wide), the party window (cols 8-19: name, HP current/max in small digits,
; status), a full-width message window over both while a message shows; window text in a
; small proportional font rendered into tiles.
;
; Battle tiles (VRAM bank 0, BG $8800 mode): $00 empty, $12-$7F the enemies, $80-$A7 party
; window lines (4 x 10), $A8-$EF left window / messages (4 x 18), $F0-$F3 the cursor (as
; sprite tiles), $F7-$FF the window frame. Sprite tiles 0-127: the four members' battle
; sprites (32 each). CGB palettes: BG 0 empty, 1 / 2 the enemies, 3 the windows; OBJ 0-3
; FF1's battle sprite palettes.

BTL_BANK   = 6
BTL_DATA   = 92
ENEMY_CHR  = 93
B_FORM     = $4000          ; data bank (battle.py)
B_STATS    = $4C00
B_PALS     = $5C80
B_SHADE    = $5E00
B_NAMES    = $6200
B_MSGS     = $6C00
B_RNG      = $7E00
B_FIEND    = $6A00          ; FF1's fiend TSA (4 x $50: 8 x 8 + 16 attribute bytes), Chaos ($C0)
B_CHAOS    = $6B40
B_RESPOND  = $7FF0          ; FF1 lut_RespondDelay (8)
BT_FRAME   = $F7            ; window frame tiles $F7-$FF (FF1's order, as font codes $10-$18)
BT_PARTY   = $80            ; party window line tiles (10 a member)
BT_TEXT    = $A8            ; left window / message tiles (18 a row)
BT_CUR     = $F0
PARTY_X    = 132

section bank 6, $4000

; ---- entry: formation [btl_fid] (bit 7: the B formation); returns A = 0 won / ran, 1 lost
battle:     xor a                           ; (no menu sounds, no vehicle noise)
            ld [sfx_menu], a
            ld [sfx_nmode], a
            ld a, [btl_fid]
            and $7F
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, B_FORM
            add hl, de
            ld de, bt_form
            ld bc, 16
            ld a, BTL_DATA
            call far_copy
            call bt_prep                    ; enemies generated (FF1 PrepareEnemyFormation)
            ld a, TR_BATTLE                 ; (FF1: the battle music)
            call snd_track
            xor a
            ld [bt_msgon], a
            ld [bt_rmask], a
            dec a                           ; (no target remembered yet)
            ld hl, bt_lastt
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl], a
            call bt_screen
            call bt_draw_party
            call bt_names
            call bt_run                     ; the battle (btl2.s)
            ld a, [bt_result]
            cp 2
            jr z, .lost
            cp 1
            jr nz, .nv
            ld a, TR_FANFARE                ; (FF1: the victory fanfare, the party cheers)
            call snd_track
            call bt_cheer
            ld a, [bt_type]                 ; Chaos defeated (FF1: no reward): his dissolve,
            cp 4                            ;   then the ending (A = 2)
            jr nz, .vic
            call bt_chaos_death
            call bt_ch_exit
            call bt_end_screen
            ld a, 2
            ret
.vic:       call bt_victory
.nv:
            call bt_ch_exit
            call bt_end_screen
            xor a
            ret
.lost:      ld a, TR_GAMEOVER
            call snd_track
            call bt_ch_exit
            call bt_end_screen
            ld a, 1
            ret

; FF1 BattleRNG: the scrambled table, a state byte
bt_rng:     push hl
            push de
            ld a, [bt_rngs]
            inc a
            ld [bt_rngs], a
            dec a
            ld l, a
            ld h, high(B_RNG)
            ld a, BTL_DATA
            ld [fc_bank], a
            call far_byte
            pop de
            pop hl
            ret
; FF1 RandAX: A = lo, X (here B) = hi -> lo + rng * (hi - lo + 1) / 256
bt_randab:  ld c, a
            ld a, b
            inc a
            sub c
            ld b, a                         ; range
            call bt_rng
            ld e, a                         ; rng * range, high byte
            ld d, 0
            ld hl, 0
.m:         srl b
            jr nc, .n
            add hl, de
.n:         sla e
            rl d
            ld a, b
            and a
            jr nz, .m
            ld a, h
            add a, c
            ret

; ---- FF1 PrepareEnemyFormation (types 0 9-small, 1 4-large, 2 mix; 3 / 4 fiend / Chaos)
bt_prep:    ld hl, bt_eid
            ld b, 9
.c:         ld [hl], $FF
            inc hl
            dec b
            jr nz, .c
            xor a
            ld [bt_ecount], a
            ld a, [btl_fid]                 ; the B formation: its quantities, groups 0-1
            bit 7, a
            jr z, .a
            ld a, [bt_form + 14]
            ld [bt_form + 6], a
            ld a, [bt_form + 15]
            ld [bt_form + 7], a
            xor a
            ld [bt_form + 4], a
            ld [bt_form + 5], a
            ld [bt_form + 8], a
            ld [bt_form + 9], a
.a:         ld a, [bt_form]
            swap a
            and $0F
            ld [bt_type], a
            cp 2
            jp z, bt_prep_mix
            jp nc, bt_prep_fiend
            and a                           ; slots: 9 small or 4 large
            ld a, 9
            ld b, 0
            jr z, .s
            xor a
            ld b, 4
.s:         ld [bt_slots], a
            ld a, b
            ld [bt_slots + 1], a
            xor a                           ; groups 0-3
.g:         push af
            call bt_grp_ga                  ; B = graphic ($00/$40/$80/$C0), C = palette bit
            pop af
            push af
            call bt_gen_sl
            pop af
            inc a
            cp 4
            jr c, .g
            ret
; group A: B = its graphic in bits 7-6, C = its palette bit (formation byte 13 bits 7-4)
bt_grp_ga:  ld e, a
            ld a, [bt_form + 1]
            ld b, a
            ld a, e                         ; graphic: bits 2 group .. 2 group + 1
            and a
            jr z, .g0
.gs:        srl b
            srl b
            dec a
            jr nz, .gs
.g0:        ld a, b
            and 3
            rrca
            rrca
            ld b, a
            ld a, [bt_form + 13]            ; palette: bit 7 - group
            ld c, a
            ld a, e
            and a
            jr z, .p0
.ps:        sla c
            dec a
            jr nz, .ps
.p0:        ld a, c
            rlca
            and 1
            ld c, a
            ret
; 9-small / 4-large: generate group A (graphic B, palette C) into the next slots
bt_gen_sl:  ld e, a
            ld d, 0
            ld hl, bt_form + 2
            add hl, de
            ld a, [hl]
            ld [bt_t], a                    ; the enemy id
            ld hl, bt_form + 6
            add hl, de
            ld a, b
            or c
            ld [bt_t + 1], a                ; graphic | palette
            ld a, [hl]                      ; quantity: min (high) .. max (low)
            ld b, a
            swap a
            and $0F
            ld c, a
            ld a, b
            and $0F
            ld b, a
            ld a, c
            call bt_randab
            and a
            ret z
            ld [bt_t + 2], a
.l:         ld a, [bt_t + 1]                ; small / large slot left
            ld e, 0
            bit 6, a
            jr z, .sm
            inc e
.sm:        ld d, 0
            ld hl, bt_slots
            add hl, de
            ld a, [hl]
            and a
            ret z
            dec [hl]
            ld a, [bt_ecount]
            ld e, a
            ld hl, bt_egp
            add hl, de
            ld a, [bt_t + 1]
            ld [hl], a
            ld hl, bt_eid
            add hl, de
            ld a, [bt_t]
            ld [hl], a
            ld hl, bt_ecount
            inc [hl]
            ld hl, bt_t + 2
            dec [hl]
            jr nz, .l
            ret

; mix: 2 large (slots 0, 1) and 6 small (slots 2-7)
bt_prep_mix:
            ld a, 2
            ld [bt_slots + 1], a
            ld a, 6
            ld [bt_slots], a
            ld a, 2
            ld [bt_spos], a
            xor a
.g:         push af
            call bt_grp_ga
            pop af
            push af
            call bt_gen_mx
            pop af
            inc a
            cp 4
            jr c, .g
            ret
bt_gen_mx:  ld e, a
            ld d, 0
            ld hl, bt_form + 2
            add hl, de
            ld a, [hl]
            ld [bt_t], a
            ld a, b
            or c
            ld [bt_t + 1], a
            ld hl, bt_form + 6
            add hl, de
            ld a, [hl]
            ld b, a
            swap a
            and $0F
            ld c, a
            ld a, b
            and $0F
            ld b, a
            ld a, [bt_t + 1]
            bit 6, a
            jr nz, .lg
            ld a, [bt_slots]                ; small: the next small slot
            and a
            ret z
            ld a, c
            call bt_randab
            and a
            ret z
            ld [bt_t + 2], a
.sl:        ld a, [bt_slots]
            and a
            ret z
            dec a
            ld [bt_slots], a
            ld a, [bt_spos]
            ld e, a
            inc a
            ld [bt_spos], a
            jr .put
.lg:        ld a, [bt_slots + 1]            ; large: slot 0, or 1 when one is left
            and a
            ret z
            ld a, c
            call bt_randab
            and a
            ret z
            ld [bt_t + 2], a
.ll:        ld a, [bt_slots + 1]
            and a
            ret z
            ld e, 0
            cp 1
            jr nz, .l0
            inc e
.l0:        dec a
            ld [bt_slots + 1], a
.put:       ld d, 0
            ld hl, bt_eid
            add hl, de
            ld a, [bt_t]
            ld [hl], a
            ld hl, bt_egp
            add hl, de
            ld a, [bt_t + 1]
            ld [hl], a
            ld hl, bt_ecount
            inc [hl]
            ld hl, bt_t + 2
            dec [hl]
            ret z
            ld a, [bt_t + 1]
            bit 6, a
            jr nz, .ll
            jr .sl

; fiend / Chaos: one enemy (graphics later)
bt_prep_fiend:
            ld a, [bt_form + 2]
            ld [bt_eid], a
            xor a
            ld [bt_egp], a
            ld a, 1
            ld [bt_ecount], a
            ret

; ---- the screen
bt_screen:  call lcd_off                    ; (LCD off in V-Blank, interrupts off)
.off:       xor a
            ldh [scx], a
            ldh [scy], a
            ld [box_on], a
            ld hl, $8000                    ; VRAM tiles (bank 0) and map cleared
            ld b, 0                         ; (256 x 32 bytes)
            xor a
            call fill32
            ldh a, [is_cgb]
            and a
            jr z, .nc
            ld a, 1                         ; CGB: bank 1 map attributes 0
            ldh [rVBK], a
            ld hl, $9800
            ld b, 32
            xor a
            call fill32
            xor a
            ldh [rVBK], a
.nc:        ldh a, [is_cgb]                 ; DMG: the empty tiles black (FF1's black battlefield)
            and a
            jr nz, .nd
            ld hl, $9000
            ld b, $12 * 16 / 32
            ld a, $FF
            call fill32
.nd:        call oam_clr
            call bt_frame_gfx
            call bt_enemy_gfx
            call bt_party_gfx
            call bt_pal
            call sgb_battle
            ld hl, smap                     ; the map copy: empty ($00), palette 0
            ld bc, 18 * 32
.sm:        xor a
            ld [hl+], a
            dec bc
            ld a, b
            or c
            jr nz, .sm
            ld hl, sattr
            ld bc, 18 * 32
.sa:        xor a
            ld [hl+], a
            dec bc
            ld a, b
            or c
            jr nz, .sa
            call bt_enemy_map
            call bt_party_win
            call bt_left_win
            ld a, 18
            ld [sf_row], a
            xor a
            ld [bt_upn], a
            call scr_show
            ret

; FF1's window frame tiles (font codes $10-$18) to $F7-$FF
bt_frame_gfx:
            ldh a, [is_cgb]
            and a
            ld hl, C_FONTDMG + $100
            jr z, .d
            ld hl, C_FONTCGB + $100
.d:         ld de, $8F70
            ld bc, 9 * 16
            ld a, COMMON
            jp far_copy

; the enemy graphics page (formation byte 0 low nibble) -> tiles $12-$7F; DMG: shaded by
; the palette of the first enemy using each graphic
bt_enemy_gfx:
            ld a, [bt_form]
            and $0F
            ld b, a
            and 7
            add a, a
            add a, a
            add a, a                        ; $800 page -> high byte 8 page
            add a, $41                      ; + $120 (tile $12)
            ld h, a
            ld l, $20
            ld a, b
            cp 8
            ld a, ENEMY_CHR
            jr c, .b
            inc a
.b:         ld de, $9120
            ld bc, $6E * 16
            call far_copy
            ldh a, [is_cgb]
            and a
            ret nz
            ld a, [btl_fid]                 ; DMG: the formation's shades (palette A, B)
            and $7F
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, B_SHADE
            add hl, de
            ld de, bt_shade
            ld bc, 8
            ld a, BTL_DATA
            call far_copy
            ld a, [bt_type]                 ; (fiend / Chaos: by cell, bt_fiend_map)
            cp 3
            ret nc
            ld c, 0                         ; graphics 0-3: tile ranges
.g:         ld a, c
            call bt_gfx_pal                 ; A = palette of its first user (0 / 1), C kept
            add a, a
            add a, a
            ld e, a
            ld d, 0
            ld hl, bt_shade
            add hl, de
            push bc
            call bt_remap_set
            pop bc
            ld a, c
            ld e, a
            ld d, 0
            ld hl, bt_gtile
            add hl, de
            ld a, [hl]                      ; first tile
            ld hl, bt_gcount
            add hl, de
            ld b, [hl]                      ; tiles
            push bc
            call bt_remap_tiles
            pop bc
            inc c
            ld a, c
            cp 4
            jr c, .g
            ret
bt_gtile:   db $12, $22, $32, $56           ; FF1: small 0 / 1 (4 x 4), large 0 / 1 (6 x 6)
bt_gcount:  db 16, 16, 36, 36
bt_gcode:   db $00, $80, $40, $C0
; graphic C (0-3: small 0, small 1, large 0, large 1) -> A = palette bit of its first user
bt_gfx_pal: ld e, c
            ld d, 0
            ld hl, bt_gcode
            add hl, de
            ld b, [hl]
            ld hl, bt_egp
            ld e, 9
.l:         ld a, [hl+]
            and $C0
            cp b
            jr z, .f
            dec e
            jr nz, .l
            xor a
            ret
.f:         dec hl
            ld a, [hl]
            and 1
            ret
; DMG remap: HL = 4 shades (by colour index) -> bt_rm (lo / hi bit masks per index)
bt_remap_set:
            ld de, bt_rm
            ld b, 4
.l:         ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .l
            ret
; remap B tiles from BG tile A (VRAM $9000 + 16 A, LCD off)
bt_remap_tiles:
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, $9000
            add hl, de
.t:         push bc                         ; B tiles (8 rows each: a row count would pass 255)
            ld b, 8
            call .tile
            pop bc
            dec b
            jr nz, .t
            ret
.tile:
.r:         ld a, [hl+]                     ; lo, hi -> the four colour masks
            ld d, a
            ld e, [hl]
            push hl
            push bc
            ld a, d                         ; m3 = lo & hi, m1 = lo & ~hi, m2 = ~lo & hi
            and e
            ld [bt_m + 3], a
            ld a, e
            cpl
            and d
            ld [bt_m + 1], a
            ld a, d
            cpl
            and e
            ld [bt_m + 2], a
            ld a, d
            or e
            cpl
            ld [bt_m], a
            ld bc, 0                        ; B = new lo, C = new hi
            ld hl, bt_rm
            ld de, bt_m
            ld a, 4
.c:         push af
            ld a, [de]
            inc de
            bit 0, [hl]
            jr z, .n0
            push af
            or b
            ld b, a
            pop af
.n0:        bit 1, [hl]
            jr z, .n1
            or c
            ld c, a
.n1:        inc hl
            pop af
            dec a
            jr nz, .c
            pop de                          ; (D = rows left)
            pop hl
            dec hl
            ld a, b
            ld [hl+], a
            ld a, c
            ld [hl+], a
            ld b, d
            dec b
            jr nz, .r
            ret

; the members' battle sprites (32 tiles each) to sprite tiles 0-127; the cursor to $F0
bt_party_gfx:
            xor a
.m:         push af
            call ch_rec
            ld a, [hl]                      ; class -> its 32 tiles
            ld l, a
            ld h, 0
            add hl, hl                      ; x 2, then x 256: x 512 (32 tiles of 16 bytes)
            ld a, l
            ld l, 0
            ld h, a
            ldh a, [is_cgb]
            and a
            ld de, U_SPRDMG
            jr z, .d
            ld de, U_SPRCGB
.d:         add hl, de
            pop af
            push af
            add a, a                        ; dest $8000 + $200 member
            add a, $80
            ld d, a
            ld e, 0
            ld bc, 512
            ld a, UI_GFX
            call far_copy
            pop af
            inc a
            cp 4
            jr c, .m
            ldh a, [is_cgb]
            and a
            ld hl, U_CURDMG
            jr z, .c
            ld hl, U_CURCGB
.c:         ld de, $8F00
            ld bc, 64
            ld a, UI_GFX
            call far_copy
            ld a, UI_GFX                    ; class palettes (CGB OBJ), cursor table
            ld hl, U_CLSPAL
            ld de, cls_pal
            ld bc, 12
            call far_copy
            ld a, UI_GFX
            ld hl, U_CURTBL
            ld de, cur_tbl
            ld bc, 8
            jp far_copy

; palettes: CGB BG 0 black, 1 / 2 the formation's, 3 the battle window; OBJ the battle
; sprite palettes; DMG: shades in the tiles (BGP straight), OBP0 ranks
bt_pal:     ldh a, [is_cgb]
            and a
            jr nz, .cgb
            ld a, %11100100
            call bgp_w
            ld a, %10010000                 ; ranks 1-3 white / light / dark (on black)
            call obp0_w
            ret
.cgb:       ld a, $80
            call bcps_w
            ld hl, bt_pal0
            call .p4
            ld a, [bt_form + 10]
            call .bp
            ld a, [bt_form + 11]
            call .bp
            ld hl, bt_pal3
            call .p4
            ld a, UI_GFX
            ld hl, U_OBJPAL
            ld de, scr_buf
            ld bc, 32
            call far_copy
            ld a, $80
            ldh [rOCPS], a
            ld hl, scr_buf
            ld b, 32
.o:         ld a, [hl+]
            ldh [rOCPD], a
            dec b
            jr nz, .o
            ret
.bp:        ld l, a                         ; battle palette A (4 NES colours) as RGB555
            ld h, 0
            add hl, hl
            add hl, hl
            ld de, B_PALS
            add hl, de
            ld de, scr_buf
            ld bc, 4
            ld a, BTL_DATA
            call far_copy
            ld a, $0F                       ; (colour 0: the black battlefield)
            ld [scr_buf], a
            ld hl, scr_buf
            ld b, 4
.c:         ld a, [hl+]
            push hl
            push bc
            call nes_rgb
            ld a, e
            call bcpd_w
            ld a, d
            call bcpd_w
            pop bc
            pop hl
            dec b
            jr nz, .c
            ret
.p4:        ld b, 4
.q:         ld a, [hl+]
            push hl
            push bc
            call nes_rgb
            ld a, e
            call bcpd_w
            ld a, d
            call bcpd_w
            pop bc
            pop hl
            dec b
            jr nz, .q
            ret
bt_pal0:    db $0F, $0F, $0F, $0F
bt_pal3:    db $0F, $00, $0F, $30           ; FF1's battle window (black inside)
; NES colour A -> DE = RGB555 (the common bank's table)
nes_rgb:    and $3F
            ld l, a
            ld h, 0
            add hl, hl
            ld de, C_NESRGB
            add hl, de
            ld de, scr_buf + 28
            ld bc, 2
            ld a, COMMON
            call far_copy
            ld a, [scr_buf + 28]
            ld e, a
            ld a, [scr_buf + 29]
            ld d, a
            ret

; the enemies into the map copy (positions: FF1's, minus the camera (1, 6))
bt_enemy_map:
            ld a, [bt_type]
            cp 3
            jp nc, bt_fiend_map
            ld c, 0
.e:         ld a, c
            ld e, a
            ld d, 0
            ld hl, bt_eid
            add hl, de
            ld a, [hl]
            cp $FF
            jr z, .n
            push bc
            ld a, c
            call bt_epos                    ; B, C = cell; E = size (4 / 6), D = first tile
            call bt_eblock
            pop bc
.n:         inc c
            ld a, c
            cp 9
            jr c, .e
            ret
; fiend (8 x 8 at cell (3, 2)) / Chaos (14 x 12 at (1, 0)): FF1's TSA and its attribute
; bytes (4 x 4, each 32 x 32 pixels from NES row 8 / col 0 of the attribute grid row 1)
bt_fiend_map:
            ld a, [bt_type]
            cp 4
            jr z, .ch
            ld a, [bt_form + 1]             ; fiend: TSA $50 x graphic
            ld l, a
            ld h, 0
            ld d, h
            ld e, l
            add hl, hl
            add hl, hl
            add hl, de                      ; x 5
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl                      ; x $50
            ld de, B_FIEND
            add hl, de
            ld bc, $50
            ld a, 8
            ld [bt_t + 4], a                ; width
            ld [bt_t + 5], a                ; rows
            ld a, $23
            ld [bt_t + 6], a                ; (top-left cell: x 3, y 2: low nibble x)
            jr .ld
.ch:        ld hl, B_CHAOS
            ld bc, $C0
            ld a, 14
            ld [bt_t + 4], a
            ld a, 12
            ld [bt_t + 5], a
            ld a, $01                       ; (Chaos: x 1, y 0)
            ld [bt_t + 6], a
.ld:        ld de, bt_stage
            ld a, BTL_DATA
            call far_copy
            ld a, [bt_t + 4]                ; the attribute bytes after the TSA
            ld b, a
            ld a, [bt_t + 5]
            ld c, a
            xor a
.mu:        add a, b
            dec c
            jr nz, .mu
            ld [bt_t + 7], a                ; (TSA bytes)
            ld hl, bt_save                  ; DMG: tiles shaded once (flags)
            ld b, 128
            xor a
.fl:        ld [hl+], a
            dec b
            jr nz, .fl
            ld a, low(bt_stage)
            ld [ft_p], a
            ld a, high(bt_stage)
            ld [ft_p + 1], a
            ld a, [bt_t + 6]
            and $0F
            ld b, a
            ld a, [bt_t + 6]
            swap a
            and $0F
            ld c, a                         ; B, C = the first cell
            ld a, [bt_t + 5]
            ld [bt_t + 8], a
.r:         push bc
            ld a, [bt_t + 4]
            ld [bt_t + 9], a
.c:         ld a, [ft_p]                    ; the tile
            ld l, a
            ld a, [ft_p + 1]
            ld h, a
            ld a, [hl+]
            ld [bt_t + 10], a
            ld a, l
            ld [ft_p], a
            ld a, h
            ld [ft_p + 1], a
            push bc
            call bt_fpal
            ld [bt_t + 11], a
            pop bc
            push bc
            call cell_addr
            ld a, [bt_t + 10]
            ld [hl], a
            inc h
            inc h
            inc h
            ld a, [bt_t + 11]
            ld [hl], a
            call bt_fshade
            pop bc
            inc b
            ld hl, bt_t + 9
            dec [hl]
            jr nz, .c
            pop bc
            inc c
            ld hl, bt_t + 8
            dec [hl]
            jr nz, .r
            ret
; DMG: tile [bt_t+10] shaded by palette [bt_t+11] (2: B, else A), once
bt_fshade:  ldh a, [is_cgb]
            and a
            ret nz
            ld a, [bt_t + 10]
            cp $12                          ; (the empty tiles stay black)
            ret c
            and $7F
            ld l, a
            ld h, high(bt_save)
            ld a, [hl]
            and a
            ret nz
            ld [hl], 1
            ld a, [bt_t + 11]
            cp 2
            ld hl, bt_shade
            jr nz, .a
            ld hl, bt_shade + 4
.a:         call bt_remap_set
            ld a, [bt_t + 10]
            ld b, 1
            jp bt_remap_tiles
; the NES palette of GB cell (B, C) from the fiend / Chaos attribute bytes (after the TSA in
; bt_stage): NES row = C + 6, col = B + 1; attribute row (NES row / 4) - 2, col NES col / 4
bt_fpal:    ld a, c
            add a, 6
            ld d, a                         ; NES row
            ld a, b
            inc a
            ld e, a                         ; NES col
            ld a, d
            srl a
            srl a
            sub 1                           ; attribute row 0-3 (FF1: grid rows 1-4)
            jr c, .z
            cp 4
            jr nc, .z
            add a, a
            add a, a
            ld l, a
            ld a, e
            srl a
            srl a
            cp 4
            jr nc, .z
            add a, l
            ld l, a
            ld a, [bt_t + 7]
            add a, l
            ld l, a
            ld h, 0
            ld a, low(bt_stage)
            add a, l
            ld l, a
            ld a, high(bt_stage)
            adc a, h
            ld h, a
            ld a, [hl]                      ; the byte; quadrant: (row & 2) * 2 + (col & 2)
            ld l, a
            ld a, d
            and 2
            add a, a
            ld h, a
            ld a, e
            and 2
            add a, h                        ; shift 0, 2, 4, 6
            ld h, a
            ld a, l
            inc h
.sh:        dec h
            jr z, .x
            rrca
            jr .sh
.x:         and 3
            ret
.z:         ld a, 1
            ret

; enemy A -> B, C = its top-left cell, E = size, D = first tile (and bt_t = its palette)
bt_epos:    ld e, a
            ld d, 0
            ld hl, bt_egp
            add hl, de
            ld a, [hl]
            ld [bt_t + 3], a
            ld a, [bt_type]
            and a
            ld hl, pos_9s
            jr z, .t
            dec a
            ld hl, pos_4l
            jr z, .t
            ld hl, pos_mx
.t:         add hl, de
            add hl, de
            ld a, [hl+]
            ld b, a
            ld c, [hl]
            ld a, [bt_t + 3]                ; size, first tile
            bit 6, a
            jr nz, .lg
            ld e, 4                         ; small: $12 / $22
            ld d, $12
            bit 7, a
            ret z
            ld d, $22
            ret
.lg:        ld e, 6                         ; large: $32 / $56
            ld d, $32
            bit 7, a
            ret z
            ld d, $56
            ret
pos_9s:     db 1, 4, 1, 0, 1, 8, 5, 4, 5, 0, 5, 8, 9, 4, 9, 0, 9, 8
pos_4l:     db 1, 0, 1, 6, 9, 0, 9, 6
pos_mx:     db 1, 0, 1, 6, 7, 4, 7, 0, 7, 8, 11, 4, 11, 0, 11, 8
; E x E tiles from D at cell (B, C); attributes: palette 1 + the enemy's palette bit
bt_eblock:  ld a, [bt_t + 3]
            and 1
            inc a
            ld [bt_t + 4], a
            ld a, e
            ld [bt_t + 5], a                ; rows
.r:         push bc
            call cell_addr
            push de
.c:         ld a, d
            ld [hl], a
            inc d
            inc h
            inc h
            inc h
            ld a, [bt_t + 4]
            ld [hl], a
            dec h
            dec h
            dec h
            inc hl
            dec e
            jr nz, .c
            pop de
            ld a, d
            add a, e
            ld d, a
            pop bc
            inc c
            ld hl, bt_t + 5
            dec [hl]
            jr nz, .r
            ret

; a window in the battle frame tiles: B, C = x, y; D, E = width, height (map copy, palette 3)
bt_win:     push bc
            push de
            ld a, e
            sub 2
            ld [bt_t + 7], a
            ld hl, bt_wtop
            call .row
.m:         inc c
            ld hl, bt_wmid
            call .row
            ld hl, bt_t + 7
            dec [hl]
            jr nz, .m
            inc c
            ld hl, bt_wbot
            call .row
            pop de
            pop bc
            ret
.row:       push bc                         ; left, middle x (w - 2), right (tiles from HL)
            push de
            ld a, [hl+]
            ld [bt_t + 14], a
            ld a, [hl+]
            ld [bt_t + 15], a
            ld a, [hl]
            ld [bt_t + 6], a
            call cell_addr
            ld a, [bt_t + 14]
            call .cell
            ld a, d
            sub 2
            ld b, a
.mc:        ld a, [bt_t + 15]
            call .cell
            dec b
            jr nz, .mc
            ld a, [bt_t + 6]
            call .cell
            pop de
            pop bc
            ret
.cell:      ld [hl], a
            inc h
            inc h
            inc h
            ld [hl], 3
            dec h
            dec h
            dec h
            inc hl
            ret
bt_wtop:    db $F7, $F8, $F9                ; FF1's frame: corners, sides, the blank inside
bt_wmid:    db $FA, $FF, $FB
bt_wbot:    db $FC, $FD, $FE

; ---- the small font: render a string into the line buffer, upload as tiles
; string HL (RAM / this bank; ASCII, $80-$8A small digits / slash) at pixel A of the buffer
vwf_str:    ld [vw_x], a
.c:         ld a, [hl+]
            and a
            ret z
            push hl
            call vwf_ch
            pop hl
            jr .c
; one glyph A at vw_x, advance
vwf_ch:     cp $20
            jr nz, .g
            ld a, [vw_x]
            add a, 3
            ld [vw_x], a
            ret
.g:         jr nc, .gl
            ld l, a                         ; an icon ($01-$1F): its tile's low plane as ink
            ld h, 0                         ;   (FF3's icons: colours 1 and 3), 8 wide
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, C_FONTCGB
            add hl, de
            ld de, vw_icon + 1
            ld bc, 16
            ld a, COMMON
            call far_copy
            ld hl, vw_icon + 1              ; rows: every other byte -> vw_icon + 1 .. + 8
            ld de, vw_icon + 1
            ld b, 8
.ic:        ld a, [hl+]
            inc hl
            ld [de], a
            inc de
            dec b
            jr nz, .ic
            ld a, 8
            ld [vw_icon], a
            ld hl, vw_icon
            jr .w
.gl:        sub $21                         ; glyph index (from '!')
            ld l, a
            ld h, 0
            ld e, l
            ld d, h
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, de                      ; 9 bytes a glyph: width, 8 rows
            ld de, vwf_glyphs
            add hl, de
.w:         ld a, [hl+]
            and a
            ret z
            ld [vw_w], a
            ld a, [vw_x]                    ; buffer tile, shift
            and 7
            ld [vw_s], a
            ld a, [vw_x]
            and $F8
            ld e, a
            ld d, high(vw_buf)              ; (8 bytes a tile: tile x 8 = x & $F8)
            ld b, 8
.r:         ld a, [hl+]
            push hl
            push bc
            ld c, a                         ; row bits (left-aligned)
            ld a, [vw_s]
            ld b, a
            ld l, c
            ld h, 0
            and a
            jr z, .ns
.sh:        srl l                           ; HL = row >> s : (right part in H shifted in)
            rr h
            dec b
            jr nz, .sh
.ns:        ld a, [de]                      ; this tile
            or l
            ld [de], a
            push de
            ld a, e
            add a, 8
            ld e, a
            ld a, [de]                      ; next tile
            or h
            ld [de], a
            pop de
            inc e
            pop bc
            pop hl
            dec b
            jr nz, .r
            ld a, [vw_w]
            inc a
            ld b, a
            ld a, [vw_x]
            add a, b
            ld [vw_x], a
            ret
; buffer cleared (B tiles)
vwf_clr:    ld hl, vw_buf
            ld a, b
            add a, a
            add a, a
            add a, a
            ld b, a
            xor a
.c:         ld [hl+], a
            dec b
            jr nz, .c
            ret
; B tiles of the buffer -> 2bpp tiles at BG tile A (LCD off: now; on: in the next V-Blanks)
vwf_out:    push af
            push bc
            call bt_flush                   ; (a previous upload first)
            pop bc
            pop af
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, $8000                    ; ($80-$FF: $8800 + 16 (A - $80) = $8000 + 16 A)
            add hl, de
            ld a, l
            ld [bt_updst], a
            ld a, h
            ld [bt_updst + 1], a
            ld a, b
            ld [bt_upn], a
            add a, a
            add a, a
            add a, a
            ld b, a                         ; rows
            ld hl, vw_buf
            ld de, bt_stage
.r:         ld a, [hl+]
            call vwf_row
            ld a, c
            ld [de], a
            inc de
            ld a, [bt_t + 8]
            ld [de], a
            inc de
            dec b
            jr nz, .r
            ld hl, bt_stage
            ld a, l
            ld [bt_upsrc], a
            ld a, h
            ld [bt_upsrc + 1], a
            call lcd_get  
            bit 7, a
            ret nz
            ld a, [bt_updst]                ; LCD off: copied now
            ld e, a
            ld a, [bt_updst + 1]
            ld d, a
            ld a, [bt_upn]
            ld b, a
.c:         ld c, 16
.cc:        ld a, [hl+]
            ld [de], a
            inc de
            dec c
            jr nz, .cc
            dec b
            jr nz, .c
            xor a
            ld [bt_upn], a
            ret
; row bits A -> C = low plane, bt_t+8 = high plane (CGB: ink colour 3 on 2; DMG: 0 on 3)
vwf_row:    ld c, a
            ldh a, [is_cgb]
            and a
            jr z, .d
            ld a, $FF
            ld [bt_t + 8], a
            ret
.d:         ld a, c
            cpl
            ld c, a
            ld [bt_t + 8], a
            ret

; V-Blank: staged tiles to VRAM (a tile at a time while LY < 152)
bt_vbl:     ld a, [bt_upn]
            and a
            ret z
            ld a, [bt_upsrc]
            ld l, a
            ld a, [bt_upsrc + 1]
            ld h, a
            ld a, [bt_updst]
            ld e, a
            ld a, [bt_updst + 1]
            ld d, a
.l:         ldh a, [rLY]                    ; (only in V-Blank: a tile takes under a line,
            sub 144                         ;   so one may start up to line 152)
            cp 9
            jr nc, .x
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc de
            ld a, [bt_upn]
            dec a
            ld [bt_upn], a
            jr nz, .l
.x:         ld a, l
            ld [bt_upsrc], a
            ld a, h
            ld [bt_upsrc + 1], a
            ld a, e
            ld [bt_updst], a
            ld a, d
            ld [bt_updst + 1], a
            ret

; the bottom rows (12-17: the windows) uploaded again in the next V-Blanks (a whole-screen
; upload already under way keeps going: it reaches them too)
bt_upd:     ld a, [sf_row]
            cp 12
            ret c
            ld a, 12
            ld [sf_row], a
            ret

; one battle frame: V-Blank, map rows and staged tiles, the pad
bt_frame:   ld a, [sf_row]                  ; (no hand while the window rows are going up)
            cp 12
            jr c, .h
            ld a, [bt_rmask]
            ld hl, bt_upn
            or [hl]
            jr z, .w
.h:         call hand_hide
.w:         call wait_vbl
            ld a, [bt_upn]                  ; (map rows only once their tiles are up)
            and a
            jr nz, .t
            call sf_step
            call bt_rowsup
.t:         call bt_vbl
            jp read_pad
; one text row's map row (A = 12-17) to upload, alone
bt_upd_row: sub 12
            ld b, a
            inc b
            xor a
            scf
.s:         rla
            dec b
            jr nz, .s
            ld hl, bt_rmask
            or [hl]
            ld [hl], a
            ret
bt_rowsup:  ld a, [bt_rmask]
            and a
            ret z
            ld c, a
            ld b, 12
            ld d, 1
.f:         ld a, c
            and d
            jr nz, .g
            inc b
            sla d
            jr .f
.g:         ldh a, [rLY]
            cp 144
            ret c
            cp 152
            ret nc
            ld a, c
            xor d
            ld [bt_rmask], a
            ld a, b
            call sf_one
            jr bt_rowsup
; wait until every staged upload is done, tiles and map rows (new text never overwrites
; tiles the screen still shows: a window is blanked on screen before its text is staged,
; and its rows go up after all of it)
bt_flush:   call lcd_get  
            bit 7, a
            ret z
            ld a, [bt_upn]
            ld hl, bt_rmask
            or [hl]
            jr nz, .w
            ld a, [sf_row]
            cp 18
            ret nc
.w:         call bt_frame
            jr bt_flush

; ---- the party: sprites in their column, the party window
bt_draw_party:
            ld a, BOBJ_BANK                 ; FF1's pose / swing tables
            ld hl, BO_POSE
            ld de, bt_tsa
            ld bc, 48
            call far_copy
            jp bt_party_upd                 ; (each in its natural pose: btl4.s)
; member A's standing pose at (B, C): OAM 4 + 6 A .. (2 x 3 sprites)
bt_spr:     ld [bt_t + 9], a
            ld e, a                         ; OAM: oam_buf + 16 + 24 A
            add a, a
            add a, e
            add a, a
            add a, a
            add a, a
            add a, 16
            ld l, a
            ld h, high(oam_buf)
            ld a, [bt_t + 9]                ; palette (CGB: the class's), tiles 32 A
            push hl
            call ch_rec
            ld e, [hl]
            ld d, 0
            ld hl, cls_pal
            add hl, de
            ld a, [hl]
            ld [bt_t + 10], a
            pop hl
            ld a, [bt_t + 9]
            swap a
            add a, a                        ; 32 A
            ld e, a
            ld a, c
            add a, 16
            ld c, a
            ld a, b
            add a, 8
            ld b, a
            ld d, 3
.r:         ld a, c
            ld [hl+], a
            ld a, b
            ld [hl+], a
            ld a, e
            ld [hl+], a
            inc e
            ld a, [bt_t + 10]
            ld [hl+], a
            ld a, c
            ld [hl+], a
            ld a, b
            add a, 8
            ld [hl+], a
            ld a, e
            ld [hl+], a
            inc e
            ld a, [bt_t + 10]
            ld [hl+], a
            ld a, c
            add a, 8
            ld c, a
            dec d
            jr nz, .r
            ret

; the party window (8,12,12,6): per member a line of 10 tiles: name, HP cur/max, status
bt_party_win:
            ld bc, $080C
            ld de, $0C06
            call bt_win
            xor a
.m:         push af
            call bt_pline
            pop af
            inc a
            cp 4
            jr c, .m
            ret
; member A's line (tiles BT_PARTY + 10 A at row 13 + A, cols 9-18)
bt_pline:   ld [bt_t + 11], a
            ld b, 10
            call vwf_clr
            ld a, [bt_t + 11]               ; the name (6 letters, trailing blanks)
            call ch_rec
            inc hl
            inc hl
            ld de, bt_sbuf
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
            xor a
            ld [de], a
            ld hl, bt_sbuf
            xor a
            call vwf_str
            ld a, [bt_t + 11]               ; HP current / max in small digits from x 32
            call ch_rec
            ld a, l
            add a, CH_HP
            ld l, a
            push hl
            call nf_w
            call num_fmt
            ld de, bt_sbuf
            call bt_dig3
            ld a, $8A
            ld [de], a
            inc de
            pop hl
            ld a, [bt_t + 11]               ; (a status shows: only the current HP)
            push hl
            call ch_rec
            inc hl
            ld a, [hl]
            pop hl
            and a
            jr z, .mx
            dec de
            jr .hp
.mx:        inc hl
            inc hl
            push de
            call nf_w
            call num_fmt
            pop de
            call bt_dig3
.hp:        xor a
            ld [de], a
            ld hl, bt_sbuf
            ld a, 32
            call vwf_str
            ld a, [bt_t + 11]               ; then the status word (ailment), from x 50
            call ch_rec
            inc hl
            ld a, [hl]
            and a
            jr z, .out
            ld de, str_st_dead
            cp 1
            jr z, .w
            ld de, str_st_stone
            cp 2
            jr z, .w
            ld de, str_st_poison
.w:         ld h, d
            ld l, e
            ld de, bt_sbuf
            ld bc, 16
            ld a, SCR_BANK
            call far_copy
            ld hl, bt_sbuf
            ld a, 50
            call vwf_str
.out:       ld a, [bt_t + 11]               ; tiles and map cells
            ld c, a
            add a, a
            add a, a
            add a, c
            add a, a                        ; 10 A
            add a, BT_PARTY
            push af
            ld b, 10
            call vwf_out
            pop af
            ld e, a
            ld a, [bt_msgon]                ; (under a message: the tiles only)
            and a
            ret nz
            ld a, [bt_t + 11]
            add a, 13
            ld c, a
            ld b, 9
            call cell_addr
            ld b, 10
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
            ret
; nf_dig (6 characters) -> DE: the digits as small-digit codes ($80 + d), no leading blanks
bt_dig3:    ld hl, nf_dig
            ld b, 6
.s:         ld a, [hl]
            cp $20
            jr nz, .c
            inc hl
            dec b
            jr .s
.c:         ld a, [hl+]
            sub $30 - $80
            ld [de], a
            inc de
            dec b
            jr nz, .c
            ret

; the left window (0,12,9,6) with the enemy names (FF1: one line per kind)
bt_left_win:
            ld bc, $000C
            ld de, $0906
            call bt_win
            jp bt_upd
bt_names:   ld b, 28                        ; up to 4 different names, rows 13-16, 7 tiles each
            xor a
            ld [bt_t + 12], a               ; row
            ld c, 0                         ; enemy index
.e:         ld a, c
            ld e, a
            ld d, 0
            ld hl, bt_eid
            add hl, de
            ld a, [hl]
            cp $FF
            jr z, .n
            ld [bt_t + 13], a
            push bc                         ; already listed?
            ld b, c
            ld hl, bt_eid
.k:         ld a, b
            and a
            jr z, .new
            ld a, [hl+]
            ld d, a
            ld a, [bt_t + 13]
            cp d
            jr z, .old
            dec b
            jr .k
.new:       call bt_name_row
.old:       pop bc
.n:         inc c
            ld a, c
            cp 9
            jr c, .e
            ret
; the name of enemy id [bt_t+13] on the next row of the left window
bt_name_row:
            ld a, [bt_t + 12]
            cp 4
            ret nc
            ld b, 7
            call vwf_clr
            ld a, [bt_t + 13]               ; the name (BTL_DATA pointer table)
            ld l, a
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
            call far_copy
            ld hl, bt_sbuf
            xor a
            call vwf_str
            ld a, [bt_t + 12]               ; tiles BT_TEXT + 7 row
            ld c, a
            add a, a
            add a, a
            add a, a
            sub c
            add a, BT_TEXT
            push af
            ld b, 7
            call vwf_out
            call bt_flush
            pop af
            ld e, a
            ld a, [bt_t + 12]
            add a, 13
            ld c, a
            ld b, 1
            call cell_addr
            ld b, 7
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
            call bt_upd
            ld hl, bt_t + 12
            inc [hl]
            ret

; back to the map: palettes / tiles are the map's again (map_reload)
bt_end_screen:
            call oam_clr
            ret

section wram, $DA00
bt_form:    ds 16
bt_type:    ds 1
bt_ecount:  ds 1
bt_eid:     ds 9
bt_egp:     ds 9
bt_slots:   ds 2
bt_spos:    ds 1
bt_t:       ds 16
bt_rngs:    ds 1
bt_shade:   ds 8
bt_rm:      ds 4
bt_m:       ds 4
bt_upn:     ds 1
bt_upsrc:   ds 2
bt_updst:   ds 2
bt_rmask:   ds 1                            ; map rows 12-17 to upload (bits 0-5)
vw_x:       ds 1
vw_w:       ds 1
vw_s:       ds 1
bt_sbuf:    ds 40
vw_icon:    ds 17
ft_p:       ds 2
section wram, $DB00
vw_buf:     ds 160                          ; the small font's line buffer (page-aligned)
section wram, $DC00
bt_stage:   ds 18 * 16                      ; tiles waiting for V-Blank
