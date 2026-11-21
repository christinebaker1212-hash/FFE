; FF1 native engine: the lineup menu (Select) and the world map (B + Select on the overworld).
; Our own code, written from what FF1's EnterLineupMenu (bank 0E) and EnterMinimap (bank 09)
; do; the world map's picture is made at build time from the user's ROM (minimap.py).

section bank 2, $6100

; ---- FF1 EnterLineupMenu: the four members (battle sprites, names) in a window (3,0,14,18);
; A on one moves it left, A on another swaps them (the leader never dead / stone), B goes back
; or leaves; the records are reordered on leaving (FF1 LineupMenu_Finalize). FF1's positions
; less (56, 40): sprites at x 96, y 16 + 32 n, names at (6, 3 + 4 n), the hand at x 32.
LU_X       = 96
lineup:     call scr_open
            ld a, TR_LINEUP
            call snd_track
            ld bc, $0300
            ld de, $0E12
            call scr_win
            xor a                           ; the slots: dead / stone, member, x, y, x, y to go
.s:         push af
            ld l, a
            add a, a
            add a, a
            add a, a
            add a, low(lu_slot)
            ld e, a
            ld d, high(lu_slot)
            ld a, l
            push de
            call ch_rec
            pop de
            inc hl
            ld a, [hl]                      ; FF1: (ailment + 1) AND 2
            inc a
            and 2
            ld [de], a
            inc de
            pop af
            push af
            ld [de], a                      ; member
            inc de
            ld b, a
            ld a, LU_X
            ld [de], a
            inc de
            ld a, b
            swap a
            add a, a
            add a, 16
            ld c, a
            ld [de], a
            inc de
            ld a, LU_X
            ld [de], a
            inc de
            ld a, c
            ld [de], a
            pop af
            inc a
            cp 4
            jr c, .s
            xor a                           ; each member's class sprite: tiles 6 m
.g:         push af
            call ch_rec
            ld a, [hl]
            ld l, a
            ld h, 0
            add hl, hl
            ld a, l
            ld l, 0
            ld h, a
            add hl, hl                      ; x 512
            ldh a, [is_cgb]
            and a
            ld bc, U_SPRDMG
            jr z, .d
            ld bc, U_SPRCGB
.d:         add hl, bc
            pop af
            push af
            ld e, a                         ; $8000 + 96 m
            add a, a
            add a, e
            swap a
            add a, a
            ld e, a
            ld a, 0
            adc a, $80
            ld d, a
            ld bc, 96
            ld a, UI_GFX
            call far_copy
            pop af
            inc a
            cp 4
            jr c, .g
            call lu_names
            call scr_show
            xor a
            ld [lu_cur], a
            ld [lu_cur2], a
            ld [lu_mode], a
.l:         call lu_sprites
            ld a, [lu_cur]                  ; the hand: x 32, the slot's y + 8
            call lu_slotp
            inc hl
            inc hl
            inc hl
            ld a, [hl]
            add a, 8
            ld c, a
            ld b, 32
            call scr_cursor
            call scr_frame
            call lu_mode_step
            ld a, [lu_mode]                 ; input in modes 0 / 2 only
            and a
            jr z, .in
            cp 2
            jr nz, .l
.in:        ldh a, [pad_new]
            bit 1, a
            jr nz, .b
            bit 0, a
            jr nz, .a
            ld hl, lu_cur
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
.b:         ld a, [lu_mode]
            and a
            jp z, lu_final
            ld a, 4
            ld [lu_mode], a
            ld a, [lu_cur2]
            ld [lu_cur], a
            jr .l
.a:         ld a, [lu_mode]
            and a
            jr nz, .a2
            inc a                           ; first choice: it moves left
            ld [lu_mode], a
            ld a, [lu_cur]
            ld [lu_cur2], a
            jr .l
.a2:        ld a, [lu_cur]                  ; second: the same one, or the leader dead: no swap
            ld hl, lu_cur2
            cp [hl]
            jr z, .kill
            and a
            jr nz, .c2
            ld a, [lu_cur2]
            call lu_slotp
            ld a, [hl]
            and a
            jr nz, .kill
.c2:        ld a, [lu_cur2]
            and a
            jr nz, .safe
            ld a, [lu_cur]
            call lu_slotp
            ld a, [hl]
            and a
            jr nz, .kill
.safe:      ld a, [lu_cur]                  ; the two slots' y to go swapped
            call lu_slotp
            ld de, 5
            add hl, de
            push hl
            ld a, [lu_cur2]
            call lu_slotp
            ld de, 5
            add hl, de
            pop de
            ld a, [de]
            ld b, [hl]
            ld [hl], a
            ld a, b
            ld [de], a
            ld hl, lu_mode
            inc [hl]
            jp .l
.kill:      ld a, [lu_cur2]
            ld [lu_cur], a
            ld hl, lu_mode
            inc [hl]
            jp .l

; slot A -> HL
lu_slotp:   add a, a
            add a, a
            add a, a
            add a, low(lu_slot)
            ld l, a
            ld h, high(lu_slot)
            ret

; FF1 LineupMenu_ProcessMode: 1 the chosen one moves left (to x < 81), 3 the second right (to
; 112), 4 both move to their places (y first, then x), then the slots swap
lu_mode_step:
            ld a, [lu_mode]
            cp 1
            jr nz, .m3
            ld a, [lu_cur2]
            call lu_slotp
            inc hl
            inc hl
            ld a, [hl]
            cp 81
            jr c, .inc
            dec [hl]
            ret
.m3:        cp 3
            jr nz, .m4
            ld a, [lu_cur]
            call lu_slotp
            inc hl
            inc hl
            ld a, [hl]
            cp 112
            jr nc, .inc
            inc [hl]
            ret
.inc:       ld hl, lu_mode
            inc [hl]
            ret
.m4:        cp 4
            ret nz
            ld a, [lu_cur]
            call lu_step
            jr nc, .f1
            ld a, [lu_cur2]
            jp lu_step
.f1:        ld a, [lu_cur2]
            call lu_step
            ret c
            ld a, [lu_cur]                  ; both there: the slots swapped
            call lu_slotp
            push hl
            ld a, [lu_cur2]
            call lu_slotp
            pop de
            ld b, 8
.sw:        ld a, [de]
            ld c, [hl]
            ld [hl+], a
            ld a, c
            ld [de], a
            inc de
            dec b
            jr nz, .sw
            xor a
            ld [lu_mode], a
            ld a, [lu_cur2]
            ld [lu_cur], a
            call lu_names
            jp scr_upd
; FF1 LineupMenu_AnimStep: slot A one pixel nearer its place; C set while moving
lu_step:    call lu_slotp
            inc hl
            inc hl
            inc hl
            ld a, [hl]                      ; y
            inc hl
            inc hl
            cp [hl]
            dec hl
            dec hl
            jr z, .x
            jr c, .dn
            dec [hl]
            scf
            ret
.dn:        inc [hl]
            scf
            ret
.x:         dec hl                          ; x
            ld a, [hl]
            inc hl
            inc hl
            cp [hl]
            dec hl
            dec hl
            ret z                           ; (C clear)
            jr c, .rt
            dec [hl]
            scf
            ret
.rt:        inc [hl]
            scf
            ret
; the names (6, 3 + 4 n) by slot
lu_names:   xor a
.n:         push af
            ld b, a
            add a, a
            add a, a
            add a, 3
            ld c, a
            push bc
            ld b, 6
            call pen_at
            pop bc
            ld a, b
            call lu_slotp
            inc hl
            ld a, [hl]
            call pen_name
            pop af
            inc a
            cp 4
            jr c, .n
            ret
; the members' sprites at their slots' places (OAM 4 + 6 n)
lu_sprites: xor a
.m:         push af
            call lu_slotp
            inc hl
            ld a, [hl+]                     ; member: tiles 6 m, the class's palette
            ld d, a
            ld a, [hl+]
            ld b, a
            ld c, [hl]
            push bc
            push de
            ld a, d
            call ch_rec
            ld e, [hl]
            ld d, 0
            ld hl, cls_pal
            add hl, de
            ld a, [hl]
            ld [scr_t0], a
            pop de
            pop bc
            ld a, d
            add a, a
            add a, d
            add a, a                        ; 6 m
            ld d, a
            pop af
            push af
            ld e, a                         ; OAM entry 4 + 6 slot
            add a, a
            add a, e
            add a, a
            add a, 4
            ld e, a
            ld a, d
            call scr_spr23
            pop af
            inc a
            cp 4
            jr c, .m
            ret
; FF1 LineupMenu_Finalize: the records (64 bytes) and spell pages (64) in the slots' order
lu_final:   ld hl, ch_stats                 ; (copies in the screen map buffer)
            ld de, smap
            ld bc, 256
            call memcpy
            ld hl, ch_magic
            ld de, smap + 256
            ld bc, 256
            call memcpy
            xor a
.p:         push af
            call lu_slotp
            inc hl
            ld a, [hl]                      ; member in this slot
            rrca
            rrca
            ld l, a                         ; its old record
            pop af
            push af
            rrca
            rrca
            ld e, a                         ; the slot's record
            push hl
            push de
            ld h, high(smap)
            ld a, l
            add a, low(smap)
            ld l, a
            ld a, h
            adc a, 0
            ld h, a
            ld d, high(ch_stats)
            ld bc, 64
            call memcpy
            pop de
            pop hl
            ld bc, smap + 256
            ld a, l
            add a, c
            ld l, a
            ld a, b
            adc a, 0
            ld h, a
            ld d, high(ch_magic)
            ld bc, 64
            call memcpy
            pop af
            inc a
            cp 4
            jr c, .p
            ret

; ---- FF1 EnterMinimap: the world map (128 x 128, at (16, 8)) drawn a pixel row a frame
; with FF1's drawing tone, then the "you are here" mark and the town / dungeon marks, their
; colours cycling (FF1 MinimapFrame); A or B leaves
MN_CGB     = $4000
MN_DMG     = $5000
MN_SPR     = $6000
MN_MARKS   = $6200
MN_PAL     = $6300
MN_ZERO    = $6308
minimap:    call lcd_off                    ; (LCD off in V-Blank, interrupts off)
.off:       xor a
            ld [box_on], a
            ld [sfx_menu], a
            ld [sfx_nmode], a
            ldh [scx], a
            ldh [scy], a
            ld a, $80                       ; (FF1: no music while it draws)
            call snd_track
            call sgb_mini
            ldh a, [is_cgb]                 ; the 256 tiles cleared to the sea's colour (CGB
            and a                           ;   index 0; DMG: its shade, 3)
            ld a, $FF
            jr z, .c0
            xor a
.c0:        ld [mn_t], a
            ld hl, $8800
            ld bc, $1000
.c:         ld a, [mn_t]
            ld [hl+], a
            dec bc
            ld a, b
            or c
            jr nz, .c
            ld a, MINI_BANK
            ld hl, MN_ZERO
            ld [fc_bank], a
            call far_byte
            ld [mn_t], a
            ld hl, $9800                    ; the map: an empty tile, the picture's 16 x 16
            ld b, 18
.r:         ld c, 20
            push hl
.cc:        ld a, [mn_t]
            ld [hl+], a
            dec c
            jr nz, .cc
            pop hl
            ld de, 32
            add hl, de
            dec b
            jr nz, .r
            ld hl, $9800 + 32 + 2
            ld b, $80                       ; tile ids $80, $81 .. $FF, $00 .. $7F
.mr:        ld c, 16
            push hl
.mc:        ld a, b
            ld [hl+], a
            inc b
            dec c
            jr nz, .mc
            pop hl
            ld de, 32
            add hl, de
            ld a, b
            cp $80
            jr nz, .mr
            ldh a, [is_cgb]
            and a
            jr z, .dmg
            ld a, 1                         ; CGB: palette 0 everywhere
            ldh [rVBK], a
            ld hl, $9800
            ld bc, $0240
.ca:        xor a
            ld [hl+], a
            dec bc
            ld a, b
            or c
            jr nz, .ca
            ldh [rVBK], a
            ld hl, MN_PAL
            ld de, scr_buf
            ld bc, 8
            ld a, MINI_BANK
            call far_copy
            ld a, $80
            ldh [rBCPS], a
            ld hl, scr_buf
            ld b, 8
.bp:        ld a, [hl+]
            ldh [rBCPD], a
            dec b
            jr nz, .bp
            jr .spr
.dmg:       ld a, %11100100
            ldh [rBGP], a
.spr:       ld hl, MN_SPR                   ; sprite tiles 0-31
            ld de, $8000
            ld bc, $200
            ld a, MINI_BANK
            call far_copy
            ld hl, oam_buf
            ld b, 160
            xor a
.oc:        ld [hl+], a
            dec b
            jr nz, .oc
            ld a, SND_BANK                  ; the drawing tone's frequency (FF1: period $060)
            ld hl, S_FREQ + 2 * $60
            ld de, mn_fq
            ld bc, 2
            call far_copy
            ld a, LCDC_ON
            ldh [rLCDC], a
            xor a                           ; 128 pixel rows, one a frame
            ld [mn_row], a
.dr:        ld a, [mn_row]
            and 7
            jr nz, .nb
            ld a, [mn_row]                  ; a new tile row: its 16 tiles to the buffer
            rrca
            rrca
            rrca
            and $0F
            ld h, a
            ld l, 0
            ldh a, [is_cgb]
            and a
            ld de, MN_CGB
            jr nz, .s1
            ld de, MN_DMG
.s1:        add hl, de
            ld de, smap
            ld bc, 256
            ld a, MINI_BANK
            call far_copy
.nb:        call wait_vbl
            ld a, [mn_row]                  ; row r & 7 of the 16 tiles: $8800 + 256 (r >> 3)
            ld b, a                         ;   + 16 t + 2 (r & 7)
            and 7
            add a, a
            ld c, a
            ld a, b
            rrca
            rrca
            rrca
            and $0F
            add a, $88
            ld d, a
            ld e, c
            ld h, high(smap)
            ld a, low(smap)
            add a, c
            ld l, a
            ld b, 16
.t:         ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl-]
            ld [de], a
            ld a, l
            add a, 16
            ld l, a
            ld a, e
            add a, 15
            ld e, a
            dec b
            jr nz, .t
            xor a                           ; FF1 Minimap_DrawSFX: 12.5 % duty, volume 6,
            ldh [$FF16], a                  ;   restarted every frame
            ld a, $60
            ldh [$FF17], a
            ld a, [mn_fq]
            ldh [$FF18], a
            ld a, [mn_fq + 1]
            or $80
            ldh [$FF19], a
            ld hl, mn_row
            inc [hl]
            bit 7, [hl]
            jr z, .dr
            xor a                           ; drawn: the tone off, the music (FF1 $41)
            ldh [$FF17], a
            ld a, TR_MINIMAP
            call snd_track
            ld a, [px]                      ; "you are here" at (px / 2, py / 2) of the picture
            srl a                           ;   (FF1's mark centred on it: - 3)
            add a, 16 - 3 + 8
            ld [oam_buf + 1], a
            ld a, [py]
            srl a
            add a, 8 - 3 + 16
            ld [oam_buf], a
            xor a
            ld [oam_buf + 2], a
            ld [oam_buf + 3], a
            ld hl, MN_MARKS                 ; the marks (y, x, tile; palette 0)
            ld de, win_buf
            ld bc, 3 * 39 + 1
            ld a, MINI_BANK
            push de
            call far_copy
            pop hl
            ld a, [hl+]
            ld b, a
            ld de, oam_buf + 4
.mk:        ld a, [hl+]
            ld [de], a
            inc de
            ld a, [hl+]
            ld [de], a
            inc de
            ld a, [hl+]
            ld [de], a
            inc de
            xor a
            ld [de], a
            inc de
            dec b
            jr nz, .mk
            xor a
            ld [mn_fc], a
.fr:        call mn_colours                 ; FF1 MinimapFrame
            call wait_vbl
            call mn_pal
            call read_pad
            ldh a, [pad_new]
            and 3
            jr z, .fr
            ret
; FF1: the mark's colour 1 tan / black every 8 frames, the marks' colour 2 $00 / $10 / $20 /
; $0F every 16
mn_colours: ld hl, mn_fc
            inc [hl]
            ld a, [hl]
            and 8
            ld a, $37
            jr z, .a
            ld a, $0F
.a:         ld [mn_c1], a
            ld a, [hl]
            and $30
            cp $30
            jr nz, .b
            ld a, $0F
.b:         ld [mn_c2], a
            ret
mn_pal:     ldh a, [is_cgb]
            and a
            jr z, .dmg
            ld a, [mn_c1]
            call mn_rgb
            ld a, $82
            ldh [rOCPS], a
            ld a, e
            ldh [rOCPD], a
            ld a, d
            ldh [rOCPD], a
            ld a, [mn_c2]
            call mn_rgb
            ld a, e
            ldh [rOCPD], a
            ld a, d
            ldh [rOCPD], a
            ret
.dmg:       ld a, [mn_c1]                   ; OBP0: colours 1 / 2 as shades
            call mn_shade
            add a, a
            add a, a
            ld b, a
            ld a, [mn_c2]
            call mn_shade
            swap a
            or b
            ldh [rOBP0], a
            ret
; NES colour A -> DMG shade ($0F black, by the brightness row otherwise)
mn_shade:   cp $0F
            ld b, 3
            jr z, .x
            swap a
            and 3
            ld b, 2                         ; (row 0 dark grey, 1 light grey, 2 / 3 white)
            jr z, .x
            dec a
            ld b, 1
            jr z, .x
            ld b, 0
.x:         ld a, b
            ret
; NES colour A -> DE = RGB555 (the common bank's table)
mn_rgb:     and $3F
            add a, a
            ld l, a
            ld h, 0
            ld de, C_NESRGB
            add hl, de
            ld de, mn_tmp
            ld bc, 2
            ld a, COMMON
            call far_copy
            ld a, [mn_tmp]
            ld e, a
            ld a, [mn_tmp + 1]
            ld d, a
            ret

; ---- FF1 EnterMiniGame: the 15-puzzle in a window (5,4,10,10): the pieces as 8 x 16 sprite
; pairs (FF1's 16 x 16 pieces; 30 sprites), shuffled with 127 random moves (FF1's lut_RNG by
; the frame counter), the cursor's piece blinking (FF1); A slides the pieces between it and the
; gap (an error sound otherwise), sliding a pixel a frame; solved: the fanfare, the backs'
; colour cycling until A / B, the reward (FF1: 100 Gil); B leaves
PZ_TILES   = $7400
PZ_START   = $7800
PZ_X       = 48 + 8         ; the first piece (OAM coordinates)
PZ_Y       = 40 + 16
TR_PUZZLE  = $42
B_LUTRNG   = $7D00          ; (battle data bank: FF1's lut_RNG)
puzzle:     call scr_open
            xor a
            ld [sfx_menu], a                ; (FF1: no menu sounds here)
            ld a, TR_PUZZLE
            call snd_track
            ld bc, $0504
            ld de, $0A0A
            call scr_win
            ld hl, PZ_TILES                 ; the pieces: sprite tiles 0-63
            ld de, $8000
            ld bc, $400
            ld a, MINI_BANK
            call far_copy
            ld hl, PZ_START
            ld de, pz_tab
            ld bc, 18
            ld a, MINI_BANK
            call far_copy
            call pz_shuffle
            ld a, $30                       ; colours: 1 black, 2 FF1's red, 3 white
            ld [pz_c3], a
            call pz_pal
            call pz_pal_set
            call scr_show
            ld a, LCDC_ON | 4               ; 8 x 16 sprites
            ld [lcdc_on], a
            ldh [rLCDC], a
            xor a
            ld [pz_cur], a
            ld [pz_anim], a
            ld a, [pz_tab]
            and a
            jr nz, .l
            ld a, 1
            ld [pz_cur], a
.l:         ld hl, pz_fc
            inc [hl]
            call pz_draw
            call scr_frame
            ld a, [pz_anim]                 ; (sliding: no input)
            and a
            jr nz, .l
            ldh a, [pad_new]
            bit 1, a
            jr nz, .x
            bit 0, a
            jr nz, .a
            and $F0
            jr z, .chk
            ld b, 1                         ; FF1: right +1, left -1, down +4, up -4, past gaps
            bit 4, a
            jr nz, .mv
            ld b, $FF
            bit 5, a
            jr nz, .mv
            ld b, 4
            bit 7, a
            jr nz, .mv
            ld b, $FC
.mv:        ld a, [pz_cur]
            add a, b
            and 15
            ld [pz_cur], a
            ld e, a
            ld d, 0
            ld hl, pz_tab
            add hl, de
            ld a, [hl]
            and a
            jr z, .mv
            jr .chk
.a:         xor a                           ; (the cursor's piece shown at once)
            ld [pz_fc], a
            call pz_slide
.chk:       call pz_won
            jr nc, .l
            ld a, TR_DLGFAN                 ; solved: FF1's fanfare, the backs cycling
            call snd_track
            ld a, $12                       ; (cursor off the puzzle)
            ld [pz_cur], a
            call pz_draw
.v:         ld hl, pz_fc
            inc [hl]
            ld a, [hl]                      ; FF1: (frame x 2) AND $30
            add a, a
            and $30
            ld [pz_c3], a
            call pz_pal
            call scr_frame
            call pz_pal_set
            ldh a, [pad_new]
            and 3
            jr z, .v
            ld a, [pz_tab + 16]             ; the reward (FF1's 100)
            ld c, a
            ld a, [pz_tab + 17]
            ld b, a
            call add_gold
.x:         ld a, LCDC_ON
            ld [lcdc_on], a
            ret
; the pieces' colours: CGB OBJ palette 0 = black, red, [pz_c3]; DMG OBP0 by shades
; (pz_pal: worked out; pz_pal_set: written, in V-Blank or with the LCD off)
pz_pal:     ld a, [pz_c3]
            call mn_shade
            rrca
            rrca
            or %00101100                    ; (1 black, 2 dark grey)
            ld [pz_obp], a
            ldh a, [is_cgb]
            and a
            ret z
            ld hl, pz_rgb
            ld a, $0F
            call .c
            ld a, $15
            call .c
            ld a, [pz_c3]
.c:         push hl
            call mn_rgb
            pop hl
            ld a, e
            ld [hl+], a
            ld a, d
            ld [hl+], a
            ret
pz_pal_set: ldh a, [is_cgb]
            and a
            jr z, .dmg
            ld a, $82
            ldh [rOCPS], a
            ld hl, pz_rgb
            ld b, 6
.w:         ld a, [hl+]
            ldh [rOCPD], a
            dec b
            jr nz, .w
            ret
.dmg:       ld a, [pz_obp]
            ldh [rOBP0], a
            ret
; FF1 MiniGame_ShufflePuzzle: 127 tries, each a random direction (lut_RNG by the frame
; counter) moving a piece into the gap when it can
pz_shuffle: ld a, [frame]
            ld [pz_fc], a
            ld a, 127
.l:         push af
            ld hl, pz_fc
            inc [hl]
            ld l, [hl]
            ld h, high(B_LUTRNG)
            ld a, BTL_DATA
            ld [fc_bank], a
            call far_byte
            and 3
            ld e, a
            ld d, 0
            ld hl, .dir
            add hl, de
            ld b, [hl]                      ; B = offset
            call pz_gap                     ; E = the gap
            ld a, e
            add a, b                        ; the piece to move in
            cp 16
            jr nc, .n                       ; (outside: also < 0)
            ld c, a
            ld a, b
            cp 1
            jr nz, .r
            ld a, c                         ; from the right: not from column 0
            and 3
            jr z, .n
            jr .ok
.r:         cp $FF
            jr nz, .ok
            ld a, c                         ; from the left: not from column 3
            and 3
            cp 3
            jr z, .n
.ok:        ld b, 0
            ld hl, pz_tab
            add hl, bc
            ld a, [hl]
            ld [hl], 0
            ld d, 0
            ld hl, pz_tab
            add hl, de
            ld [hl], a
.n:         pop af
            dec a
            jr nz, .l
            ret
.dir:       db 1, $FF, 4, $FC
; E = the gap's slot
pz_gap:     ld hl, pz_tab
            ld e, 0
.f:         ld a, [hl+]
            and a
            ret z
            inc e
            jr .f
; FF1 MiniGame_CheckVictory: each piece one more than the one before (slots 1-14)
pz_won:     ld hl, pz_tab
            ld a, [hl+]
            ld b, 14
.l:         inc a
            cp [hl]
            jr nz, .no
            inc hl
            dec b
            jr nz, .l
            scf
            ret
.no:        and a
            ret
; A on the cursor's piece: the gap in its column (vertical) or row (horizontal): the pieces
; between slide; else FF1's error sound
pz_slide:   call pz_gap
            ld a, e
            ld [pz_old], a                  ; (the gap: the cursor goes there)
            ld a, [pz_cur]
            ld c, a
            xor e
            and 3
            ld b, 4                         ; same column: step 4
            jr z, .go
            ld a, c
            xor e
            and $0C
            ld b, 1                         ; same row: step 1
            jr z, .go
            ld a, SFX_PUZERR
            ld [sfx_req], a
            ret
.go:        ld a, b
            ld [pz_step], a
            ld a, c                         ; cursor < gap: the pieces move + (toward the gap)
            cp e
            jr nc, .neg
            ld a, b
            ld [pz_dir], a
            ld a, c                         ; moved: cursor + step .. gap
            add a, b
            ld [pz_lo], a
            ld a, e
            ld [pz_hi], a
.m1:        ld a, e                         ; shift: slot e <- slot e - step, down to cursor
            sub b
            ld d, a
            call .mv
            ld a, d
            ld e, a
            cp c
            jr nz, .m1
            jr .done
.neg:       ld a, b
            cpl
            inc a
            ld [pz_dir], a
            ld a, e
            ld [pz_lo], a
            ld a, c
            sub b
            ld [pz_hi], a
.m2:        ld a, e                         ; slot e <- slot e + step, up to cursor
            add a, b
            ld d, a
            call .mv
            ld a, d
            ld e, a
            cp c
            jr nz, .m2
.done:      ld a, c                         ; the cursor's slot is the gap now
            ld e, a
            ld d, 0
            ld hl, pz_tab
            add hl, de
            ld [hl], 0
            ld a, [pz_old]
            ld [pz_cur], a
            ld a, 16
            ld [pz_anim], a
            ret
.mv:        push de                         ; pz_tab[e] = pz_tab[d]
            ld hl, pz_tab
            ld a, l
            add a, d
            ld l, a
            ld a, [hl]
            ld hl, pz_tab
            push af
            ld a, l
            add a, e
            ld l, a
            pop af
            ld [hl], a
            pop de
            ret
; the pieces to OAM (8 x 16 pairs, entries 2 s, 2 s + 1); the cursor's piece hidden two
; frames in four (FF1); pieces sliding drawn (16 - k) pixels back
pz_draw:    ld a, [pz_anim]
            and a
            jr z, .na
            dec a
            ld [pz_anim], a
.na:        ld hl, oam_buf
            ld c, 0
.s:         ld e, c
            ld d, 0
            push hl
            ld hl, pz_tab
            add hl, de
            ld a, [hl]
            pop hl
            and a
            jr z, .hide
            ld b, a                         ; piece: tiles 4 p, 4 p + 2
            ld a, [pz_cur]
            cp c
            jr nz, .vis
            ld a, [pz_anim]                 ; (no blinking while pieces slide)
            and a
            jr nz, .vis
            ld a, [pz_fc]
            and 2
            jr nz, .hide
.vis:       push bc
            ld a, b
            add a, a
            add a, a
            ld [pz_pt], a
            ld a, c                         ; x, y
            and 3
            swap a
            add a, PZ_X
            ld d, a
            ld a, c
            and $0C
            add a, a
            add a, a
            add a, PZ_Y
            ld e, a
            call .off                       ; sliding: back by pz_anim x direction
            ld a, e
            ld [hl+], a
            ld a, d
            ld [hl+], a
            ld a, [pz_pt]
            ld [hl+], a
            xor a
            ld [hl+], a
            ld a, e
            ld [hl+], a
            ld a, d
            add a, 8
            ld [hl+], a
            ld a, [pz_pt]
            add a, 2
            ld [hl+], a
            xor a
            ld [hl+], a
            pop bc
            jr .nx
.hide:      xor a
            ld [hl+], a
            inc hl
            inc hl
            inc hl
            ld [hl+], a
            inc hl
            inc hl
            inc hl
.nx:        inc c
            ld a, c
            cp 16
            jr c, .s
            ret
.off:       ld a, [pz_anim]
            and a
            ret z
            ld a, [pz_lo]                   ; slot C among the moved ones?
            ld b, a
            ld a, c
            sub b
            ret c
            ld b, a
            ld a, [pz_hi]
            cp c
            ret c
            ld a, [pz_step]
            cp 4
            jr nz, .in
            ld a, b
            and 3
            ret nz
.in:        ld a, [pz_anim]                 ; pixels back
            ld b, a
            ld a, [pz_dir]
            cp 1
            jr z, .xm
            cp $FF
            jr z, .xp
            cp 4
            jr z, .ym
            ld a, e                         ; moving up: drawn lower
            add a, b
            ld e, a
            ret
.ym:        ld a, e
            sub b
            ld e, a
            ret
.xm:        ld a, d
            sub b
            ld d, a
            ret
.xp:        ld a, d
            add a, b
            ld d, a
            ret

section wram, $C100                         ; (the map queue: free on these screens)
lu_slot:    ds 32
lu_cur:     ds 1
lu_cur2:    ds 1
lu_mode:    ds 1
mn_t:       ds 1
mn_row:     ds 1
mn_fq:      ds 2
mn_fc:      ds 1
mn_c1:      ds 1
mn_c2:      ds 1
mn_tmp:     ds 2
pz_tab:     ds 18                           ; the puzzle (16 slots), the reward
pz_cur:     ds 1
pz_fc:      ds 1
pz_c3:      ds 1
pz_anim:    ds 1
pz_old:     ds 1
pz_step:    ds 1
pz_dir:     ds 1
pz_lo:      ds 1
pz_hi:      ds 1
pz_pt:      ds 1
pz_obp:     ds 1
pz_rgb:     ds 6
