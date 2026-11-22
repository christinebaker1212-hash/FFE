; FF3 for the Game Boy Color: the native engine (owner, 2026-11-22: 100% native code, no NES
; layer). Written from what FF3's routines do (everything8215/ff3 disassembly); every game byte
; comes from the user's ROM at build time (tools/gb3n/data.py, build.py).
;
; Milestone 1: boot on a Color, a normal map from the ROM's data (layout, tileset metatiles,
; palettes, graphics), the party walking on it with FF3's passability rule.
;
; Memory: bank 0 code; map data bank MAPB (build.py): $4000 layout (32 x 32 metatiles), $4400
; metatile tables TL / TR / BL / BR / ATTR / P1 / P2 (256 each), $4B00 CGB palettes (BG 64, OBJ
; 64 bytes), $4C00 BG tiles (256, GB format), $5C00 the walking character (16 tiles).
; VRAM: BG tiles bank 0 $8000 (NES tile n = GB tile n), sprite tiles bank 1 $8000; BG map
; $9800 = a 16 x 16 metatile ring (map metatile (x, y) at cells (2x & 31, 2y & 31)).

; Map arrays in WRAM bank 1 (loaded per map from the packed banks, build.py pack): FF3 rewrites
; trigger tiles and their property bytes at run time, as on the NES ($7400, $0400-$06FF).
M_LAY      = $D000              ; 32 x 32 metatiles
M_TL       = $D400              ; metatile tables: TL / TR / BL / BR tile ids, palette, props 1 / 2
M_TR       = $D500
M_BL       = $D600
M_BR       = $D700
M_ATTR     = $D800
M_P1       = $D900
M_P2       = $DA00
M_FACE     = $DB00              ; facing (NES order: R 1, L 2, D 4, U 8) -> frame offset
M_FRAME    = $DB10              ; frames: TL, BL, TR, BR tile / CGB attribute pairs
M_ENT      = $DB80              ; the map's entry (64 bytes, build.py pack)
M_TT       = $DC00              ; the map's treasures (16) and triggers (16): 3A/9341
W_ENT      = $DBC0              ; world map: the entrance tiles' destination maps (64)
N_OBJ      = $C400
N_OB2      = $C500
GS         = $C800              ; FF3's save block $6000-$63FF (npc switches at +$80)
N_ANIM     = $CC00              ; 3B/B41A animation frames (CGB attributes), 256 bytes
N_RNG      = $CD00              ; fix:FE00 random number table
EV_DLG     = $C600              ; FF3 $0740: the person's dialogue ids (32)
EV_TRIG    = $C640              ; FF3 $7B00: the loaded trigger script (64)
MC_MAP     = $D000              ; canvas (WRAM bank 2): 32 x 18 tile codes
MC_ATTR    = $D400              ;   and attributes
MP_T       = $70                ; VRAM bank 1 tiles: MP digits 0/-9/, 0-9
JOB_T      = $20                ;   job names, 12 a member
SN_T       = $84                ;   small numbers (gil, capacity): 12
PAL_TXT    = $07                ; attributes: palette 7 (window / white text), bank 0 tiles
PAL_HP     = $04                ;   palette 4 (green HP; 5 orange, 6 pink)
STEP       = 16                 ; frames per metatile (a pixel a frame)
PX0        = 72                 ; the party's 16 x 16 sprite at screen (72, 64)
PY0        = 64
LCDC_ON    = %11010011          ; LCD on, BG $9800, tiles $8000, sprites on (8 x 8), window map
                                ;   $9C00 (the window itself on while a box shows: bit 5)
WIN_ROWS   = 6                  ; the dialogue box: 6 rows of the window layer (text.s)
WIN_LINE   = 48                 ;   the first screen line under it
QMAX       = 32                 ; queued metatiles (a column / row of the view: 12)

section bank 0, $0040
            jp vblank
section bank 0, $0048
            jp stat_isr
section bank 0, $0100
            nop
            jp start

section bank 0, $0150
start:      di
            ld sp, $C800                    ; (WRAM 0: the menus switch WRAM banks)
            cp $11                          ; (Color only: other models stop here; the
            jr z, .cgb                      ;   message screen comes with the title milestone)
.dmg:       halt
            jr .dmg
.cgb:       xor a
            ldh [rIE], a
            ldh [rNR52], a
            ldh a, [rKEY1]                  ; double speed
            bit 7, a
            jr nz, .fast
            ld a, 1
            ldh [rKEY1], a
            ld a, $30
            ldh [rP1], a
            stop
.fast:      call lcd_off
            ld hl, $C000                    ; memory cleared (Lot Check: nothing assumed; inline:
            ld bc, $2000                    ;   the stack is in it)
.clr:       xor a
            ld [hl+], a
            dec bc
            ld a, b
            or c
            jr nz, .clr
            ld hl, $FF80
            ld de, $7F
            call memclr
            ld a, 1
            ldh [rVBK], a
            ld hl, $8000
            ld de, $2000
            call memclr
            xor a
            ldh [rVBK], a
            ld hl, $8000
            ld de, $2000
            call memclr
            ld hl, dma_rom                  ; OAM DMA routine to HRAM
            ld de, hram_dma
            ld b, dma_end - dma_rom
.cd:        ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .cd
            call npc_boot
            ld hl, win_attr                 ; dialogue box attributes: BG palette 3, priority
            ld b, 32 * WIN_ROWS
            ld a, $83
.wa:        ld [hl+], a
            dec b
            jr nz, .wa
            ld a, START_GRP                 ; the test start (build.py --map / --group)
            ld [cur_grp], a
            cp 3                            ; (the world: group 0 / 1 = world 0 / 1, 2 = world 2,
            jr c, .wd                       ;   3 + w = world map w)
            sub 3
.wd:        ld [cur_world], a
            ld a, START_MAP
            ld [cur_map], a
            ld a, 4                         ; (facing down)
            ld [facing], a
            ld a, START_X                   ; ($FF: the map's own start position)
            ld [px], a
            ld a, START_Y
            ld [py], a
            call load_map
            ld a, LCDC_ON
            ldh [rLCDC], a
            ld a, 1
            ld [lcd_is], a
            ld a, 7                         ; the window: top left, cut by LYC
            ldh [rWX], a
            xor a
            ldh [rWY], a
            ld a, WIN_LINE - 1
            ldh [rLYC], a
            ld a, $40
            ldh [rSTAT], a
            xor a
            ldh [rIF], a
            ld a, 3
            ldh [rIE], a
            ei

; ---- main loop: one engine frame per GB frame
main:       call wait_vbl
            call read_pad
            ldh a, [pad]                    ; newly pressed buttons
            ld b, a
            ld a, [pad_old]
            cpl
            and b
            ld [pad_new], a
            ld a, b
            ld [pad_old], a
            ld [mpad], a
            ld a, [moving]                  ; the party standing (fix:E20F):
            and a
            jr nz, .mv
            ld a, [act]                     ;   a pending trigger (from an event)
            and a
            jr z, .na
            call do_act
            jr main
            ld a, [m_title]                 ;   the map's title (fix:E24D)
            cp $FF
            jr z, .na
            ld c, a
            ld a, $FF
            ld [m_title], a
            ld a, 1
            call dlg_show
            jr main
.na:        ld a, [ev_on]                   ;   an event: one command, its party moves only
            and a
            jr z, .inp
            call ev_step
            ld a, [ev_pad]
            ld [mpad], a
            xor a
            ld [ev_pad], a
            jr .mv
.inp:       ld a, [pad_new]                 ;   A: talk (fix:EA26)
            bit 0, a
            call nz, talk
            ld a, [pad_new]                 ;   Start: the menu (fix:E340)
            bit 3, a
            jr z, .sl
            ld a, CODE1
            ld hl, menu_open
            call far_call
            jr main
.sl:        bit 2, a                        ;   Select: the Select menu; B + Select: the next
            jr z, .mv                       ;     member walks (fix:F72C)
            ldh a, [pad]
            bit 1, a
            jr z, .sm
            call next_char
            jr main
.sm:        ld a, CODE1
            ld hl, sel_open
            call far_call
            jr main
.mv:        call move
            call calc_pp
            call make_oam
            call npc_frame
            ld a, DLG_TEST                  ; (test builds: A shows dialogue DLG_TEST of the
            and a                           ;   people's table)
            jr z, main
            ldh a, [pad]
            bit 0, a
            jr z, main
            ld a, DLG_TEST_T
            ld c, DLG_TEST
            call dlg_show
            jr main

wait_vbl:   xor a
            ldh [vbl_flag], a
.w:         halt
            ldh a, [vbl_flag]
            and a
            jr z, .w
            ret

; ---- V-Blank: OAM, scroll, queued metatiles
vblank:     push af
            push bc
            push de
            push hl
            call hram_dma
            ldh a, [pal_dirty]
            and a
            call nz, pal_up
            ldh a, [scx]
            ldh [rSCX], a
            ldh a, [scy]
            ldh [rSCY], a
            call q_flush
            call win_vbl
            call menu_vbl
            ldh a, [rLCDC]                  ; the dialogue window (cut at line WIN_LINE) or a
            res 5, a                        ;   menu (the whole screen)
            ld b, a
            ld a, [win_on]
            ld c, a
            ld a, [menu_on]
            or c
            jr z, .w
            set 5, b
.w:         ld a, b
            ldh [rLCDC], a
            ld a, 1
            ldh [vbl_flag], a
            pop hl
            pop de
            pop bc
            pop af
            reti

; ---- joypad: pad = held (bit 0 A, 1 B, 2 Select, 3 Start, 4 Right, 5 Left, 6 Up, 7 Down)
read_pad:   ld a, $20
            ldh [rP1], a
            ldh a, [rP1]
            ldh a, [rP1]
            cpl
            and $0F
            swap a
            ld b, a
            ld a, $10
            ldh [rP1], a
            ldh a, [rP1]
            ldh a, [rP1]
            ldh a, [rP1]
            ldh a, [rP1]
            cpl
            and $0F
            or b
            ldh [pad], a
            ld a, $30
            ldh [rP1], a
            ret

; ---- load map cur_map of group cur_grp: LCD off (V-Blank), the entry, layout, tileset tables,
; tiles, character, palettes; the start position when px = $FF
load_map:   ld a, [lcd_is]
            and a
            call z, lcd_off
            ld a, [cur_grp]
            cp 3
            jp nc, .world
            xor a
            ldh [is_world], a
            ld a, $3F
            ldh [cmask], a
            ld a, [cur_grp]                 ; the entry: bank MT_BANK + group, $4000 + 64 id
            add a, MT_BANK
            ld [MBC5_BANKL], a
            ld a, [cur_map]
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld a, h
            add a, $40
            ld h, a
            ld de, M_ENT
            ld bc, 64
            call memcpy
            ld a, [M_ENT + 7]
            ld [fill_mt], a
            ld a, [px]
            inc a
            jr nz, .pos
            ld a, [M_ENT + 5]
            ld [px], a
            ld a, [M_ENT + 6]
            ld [py], a
.pos:       ld a, [M_ENT + 0]               ; layout -> M_LAY
            ld [MBC5_BANKL], a
            ld a, [M_ENT + 1]
            ld h, a
            ld l, 0
            ld de, M_LAY
            ld bc, $400
            call memcpy
            call .tset
            ld a, [cur_grp]                 ; treasures / triggers: TT_BANK + group, 32 id
            add a, TT_BANK
            ld [MBC5_BANKL], a
            ld a, [cur_map]
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld a, h
            add a, $40
            ld h, a
            ld de, M_TT
            ld bc, 32
            call memcpy
            ld a, [M_ENT + 8]               ; the map title (shown once the map is up, when
            ld [m_title2], a                ;   arriving from a world map: fix:E8C6)
            call init_trig
            call load_npcs
            jp .gfx
.world:     sub 3                           ; world map w: its entry and entrance table (bank
            ld [cur_world], a               ;   WLD_BANK $7000 / $7400 + 64 w)
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld a, h
            add a, $70
            ld h, a
            ld a, WLD_BANK
            ld [MBC5_BANKL], a
            push hl
            ld de, M_ENT
            ld bc, 64
            call memcpy
            pop hl
            ld a, h
            add a, 4
            ld h, a
            ld de, W_ENT
            ld bc, 64
            call memcpy
            ld a, 1
            ldh [is_world], a
            ld a, $FF
            ldh [cmask], a
            ld a, [px]                      ; (no position: FF3's new-game one, 41 + 7, 47 + 7)
            inc a
            jr nz, .wp
            ld a, 48
            ld [px], a
            ld a, 54
            ld [py], a
.wp:        call .tset
            call load_npcs
            jp .gfx
.tset:      ld a, [M_ENT + 12]              ; tileset tables -> M_TL..M_P2 (bank e[12])
            ld [MBC5_BANKL], a
            ld a, [M_ENT + 4]
            ld l, 0
            ld h, a                         ; $4000 + $700 ts
            add a, a
            add a, a
            add a, a
            sub h                           ; 7 ts
            add a, $40
            ld h, a
            ld de, M_TL
            ld bc, $700
            jp memcpy
.gfx:       ld a, [lcd_is]                  ; a load during play: the picture behind black
            and a
            jr z, .vram
            call pal_black
.vram:      ld a, [M_ENT + 2]               ; BG tiles -> VRAM bank 0 $8000
            ld [MBC5_BANKL], a
            ld a, [M_ENT + 3]
            ld h, a
            ld l, 0
            ld de, $8000
            ld b, 0                         ; (256 blocks)
            xor a
            call vcopy
            call char_gfx                   ; the walking character -> VRAM bank 1 $8000
            ld a, SPR_BANK                  ;   its frames -> M_FACE / M_FRAME
            ld [MBC5_BANKL], a
            ld hl, $7F00
            ld de, M_FACE
            ld bc, $50
            call memcpy
            call npc_gfx
            ld a, [px]                      ; the party's destination tile
            ld [ppx], a
            ld a, [py]
            ld [ppy], a
            ld hl, pal_sh                   ; palettes: the 32 NES colours through NES_RGB ->
            ld de, 128                      ;   the shadow (BG 0-31, OBJ 64-95; uploaded in
            call memclr                     ;   V-Blank, or now)
            ld hl, M_ENT + 16
            ld bc, pal_sh
.pc:        push bc
            call nes_col
            pop bc
            ld [bc], a
            inc bc
            ld a, d
            ld [bc], a
            inc bc
            ld a, c
            cp low(pal_sh + 32)
            jr nz, .p1
            ld bc, pal_sh + 64
.p1:        cp low(pal_sh + 96)
            jr nz, .pc
            call char_pal
            xor a
            ld [mcount], a
            ld [moving], a
            call set_scroll
            ld a, [lcd_is]
            and a
            jr nz, .masked
            ld a, 1                         ; boot (LCD off): the whole view written at once
            ld [q_direct], a
            call draw_view
            xor a
            ld [q_direct], a
            call pal_up
            jp map_enter

.masked:    call draw_view                  ; (two rows a frame through the queue)
            call wait_vbl
            ld a, 1
            ldh [pal_dirty], a
            call wait_vbl
            jp map_enter

; fix:E865 / E884: the start tile gives the z-level; a type-F trigger there runs its event
map_enter:  ldh a, [is_world]
            and a
            ret nz
            ld a, [px]
            ld e, a
            ld a, [py]
            ld d, a
            call map_at
            ld l, a
            ld h, high(M_P1)
            ld a, [hl]
            ld b, a
            and 3
            ld [zlev], a
            bit 7, b
            ret z
            inc h
            ld a, [hl]
            cp $F0
            ret c
            and $0F
            jp trig_ev

; the whole view: rows py - 5 .. py + 6, columns px - 5 .. px + 6
draw_view:  ld a, [py]
            sub 5
            ld d, a
            ld c, 12
.row:       ld a, [px]
            sub 5
            ld e, a
            ld b, 12
.col:       push bc
            push de
            call q_mt
            pop de
            pop bc
            inc e
            dec b
            jr nz, .col
            inc d
            ld a, [q_direct]                ; (masked: a V-Blank after every two rows)
            and a
            jr nz, .nx
            bit 0, c
            jr nz, .nx
            push bc
            push de
            call wait_vbl
            pop de
            pop bc
.nx:        dec c
            jr nz, .row
            ret

; palettes: the shadow -> CGB palette RAM (V-Blank or LCD off)
pal_up:     ld a, $80
            ldh [rBCPS], a
            ldh [rOCPS], a
            ld hl, pal_sh
            ld b, 64
.b:         ld a, [hl+]
            ldh [rBCPD], a
            dec b
            jr nz, .b
            ld b, 64
.o:         ld a, [hl+]
            ldh [rOCPD], a
            dec b
            jr nz, .o
            xor a
            ldh [pal_dirty], a
            ret
pal_black:  ld hl, pal_sh                   ; all black, shown at the next V-Blank
            ld de, 128
            call memclr
            ld a, 1
            ldh [pal_dirty], a
            jp wait_vbl

; B blocks of 16 bytes HL (ROM) -> DE (VRAM bank A): directly with the LCD off, else by
; general-purpose DMA, 64 blocks a V-Blank (B = 0: 256 blocks)
vcopy:      ld [vc_bank], a
            ldh [rVBK], a
            ld a, [lcd_is]
            and a
            jr nz, .dma
            ld c, b                         ; memcpy B * 16 bytes
            ld a, b
            and a
            jr nz, .m
            ld c, 0
.m:         push bc
            ld b, 16
.m1:        ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .m1
            pop bc
            dec c
            jr nz, .m
            xor a
            ldh [rVBK], a
            ret
.dma:       ld a, b
            ld [vc_left], a
.d1:        push hl
            push de
            call wait_vbl
            pop de
            pop hl
            ld a, h
            ldh [rHDMA1], a
            ld a, l
            ldh [rHDMA2], a
            ld a, d
            ldh [rHDMA3], a
            ld a, e
            ldh [rHDMA4], a
            ld a, [vc_left]
            ld c, 64
            and a
            jr z, .d2                       ; (0 = 256 left)
            cp 64
            jr nc, .d2
            ld c, a
.d2:        ld a, [vc_bank]
            ldh [rVBK], a
            ld a, c
            dec a
            ldh [rHDMA5], a                 ; (general purpose: the CPU waits)
            xor a
            ldh [rVBK], a
            ld a, c                         ; HL, DE += 16 C
            swap a
            ld b, a
            and $F0
            add a, l
            ld l, a
            ld a, b
            and $0F
            adc a, h
            ld h, a
            ld a, c
            swap a
            ld b, a
            and $F0
            add a, e
            ld e, a
            ld a, b
            and $0F
            adc a, d
            ld d, a
            ld a, [vc_left]
            sub c
            ld [vc_left], a
            jr nz, .d1
            ret

; ---- triggers (3A L3A_91C8): trigger tiles $60-$63 / $70-$7C get, in layout order, the next id
; of their type, ORed into the property byte 2 of their metatile copy ($80-$FF: TRIG_O + count)
init_trig:  ld hl, tr_cnt                   ; 32 tile counts + 16 type counts
            ld de, 48
            call memclr
            ld hl, M_LAY
.lp:        ld a, [hl]
            cp $60
            jr c, .nx
            cp $64
            jr c, .tr
            cp $70
            jr c, .nx
            cp $7D
            jr nc, .nx
.tr:        push hl
            sub $60
            ld c, a                         ; C = tile - $60
            ld b, 0
            ld hl, tr_cnt
            add hl, bc
            ld a, [hl]                      ; this tile's count
            inc [hl]
            ld [tr_n], a
            ld hl, TRIG_T
            add hl, bc
            ld e, [hl]                      ; E = type
            ld d, 0
            ld hl, tr_cnt + 32
            add hl, de
            ld a, [hl]                      ; the type's next id
            inc [hl]
            ld [tr_id], a
            ld hl, TRIG_O
            add hl, bc
            ld a, [tr_n]
            add a, [hl]                     ; the metatile copy
            ld e, a
            ld a, c
            cp $1C                          ; treasure chest: opened ones -> $7D (3A/91F7)
            jr nz, .trg
            ld a, [tr_id]
            call tr_open
            jr z, .trg
            pop hl
            ld [hl], $7D
            jr .nx
.trg:       ld d, high(M_P2)
            ld a, [de]
            ld hl, tr_id
            or [hl]
            ld [de], a
            pop hl
            ld [hl], e                      ; the layout points at the copy
.nx:        inc hl
            ld a, h
            cp high(M_LAY) + 4
            jr nz, .lp
            ret

; A = the map's treasure n -> Z if its treasure switch is on (unopened: $6040 + id / 8, + 32
; off world 0; HL = the switch byte, B = its bit)
tr_open:    add a, low(M_TT)
            ld l, a
            ld h, high(M_TT)
            ld a, [hl]
tr_sw:      push af                         ; (A = treasure id)
            and 7
            ld b, a
            ld a, 1
            inc b
.m:         dec b
            jr z, .m1
            add a, a
            jr .m
.m1:        ld b, a
            pop af
            srl a
            srl a
            srl a
            ld c, a
            ld a, [cur_world]
            and a
            ld a, c
            jr z, .w
            add a, $20
.w:         add a, low(GS + $40)
            ld l, a
            ld h, high(GS + $40)
            ld a, [hl]
            and b
            cp b                            ; Z: set
            ret

; ---- movement: a step is one metatile in STEP frames
move:       ld a, [moving]
            and a
            jr nz, .step
            ld a, [mpad]
            ld b, a
            ld de, $0001                    ; D = dy, E = dx (two's complement)
            bit 4, b
            jr nz, .go
            ld e, $FF
            bit 5, b
            jr nz, .go
            ld de, $FF00
            bit 6, b
            jr nz, .go
            ld d, 1
            bit 7, b
            ret z
.go:        ld a, e
            ld [mdx], a
            ld a, d
            ld [mdy], a
            ld c, 1                         ; facing in FF3's order (R 1, L 2, D 4, U 8)
            bit 4, b
            jr nz, .f
            inc c
            bit 5, b
            jr nz, .f
            ld c, 8
            bit 6, b
            jr nz, .f
            ld c, 4
.f:         ld a, c
            ld [facing], a
            ld a, [px]                      ; target metatile
            add a, e
            ld c, a
            ldh a, [cmask]                  ; ($3F on a map, $FF on a world map)
            and c
            ld e, a
            ld a, [py]
            add a, d
            ld c, a
            ldh a, [cmask]                  ; ($3F on a map, $FF on a world map)
            and c
            ld d, a
            push de
            call npc_block
            pop de
            ret c
            ld a, e                         ; (the party's destination tile: FF3 $68 / $69)
            ld [ppx], a
            ld a, d
            ld [ppy], a
            call map_at
            ld l, a
            ldh a, [is_world]
            and a
            jr nz, .wpass
            ld a, l                         ; a trigger tile (property 1 bit 7): fix:E669
            ld h, high(M_P1)
            bit 7, [hl]
            jr z, .plain
            inc h
            ld a, [hl]                      ; property 2: type (high nibble), id
            ld [act_id], a
            swap a
            and $0F
            jr z, .t0                       ; 0 exit to the previous map
            dec a
            jr z, .t1                       ; 1 exit to the world map
            sub 3
            jr z, .t4                       ; 4 entrance
            dec a
            jr z, .t5                       ; 5 door
            dec a
            ret z                           ; 6 locked door (the unlock flag: later)
            cp $0C - 6
            jr c, .def                      ; 2, 3, 7-B: no trigger
            cp $0F - 6
            ret c                           ; C, D, E impassable
            push de                         ; F: its event, then the tile's own passability
            push hl
            ld a, [act_id]
            and $0F
            call trig_ev
            pop hl
            pop de
            jr .def
.def:       ld a, l
.plain:     call passable
            ret c
            jr .go2
; world map (fix:C65D): impassable on foot when property 1 bit 0 is set; bit 7 with property 2
; bit 7 clear: an entrance (fix:C1C4: destination 00/8800 / 00/8840 + id); bit 7 with bit 7:
; an event (later); bit 6 random battles (later)
.wpass:     ld h, high(M_P1)
            ld a, [hl]
            bit 0, a
            ret nz
            bit 7, a
            jr z, .go2
            inc h
            ld a, [hl]
            bit 7, a
            jr nz, .go2
            ld [act_id], a
            ld a, $90
            jr .ta
.t0:        ld a, $40
            jr .ta
.t1:        ld a, $C0
            jr .ta
.t5:        push de                         ; the door shown open (metatile $7E)
            call map_at
            pop de
            ld [hl], $7E
            call q_mt
.t4:        ld a, $80
.ta:        ld [act], a
.go2:       ld a, 1
            ld [moving], a
            xor a
            ld [mcount], a
            call draw_edge                  ; the line of metatiles entering the view
            ret
.step:      ld a, [mcount]
            inc a
            ld [mcount], a
            cp STEP
            jr nz, .sc
            ld a, [px]                      ; arrived
            ld hl, mdx
            add a, [hl]
            ld c, a
            ldh a, [cmask]                  ; ($3F on a map, $FF on a world map)
            and c
            ld [px], a
            ld a, [py]
            inc hl
            add a, [hl]
            ld c, a
            ldh a, [cmask]                  ; ($3F on a map, $FF on a world map)
            and c
            ld [py], a
            xor a
            ld [moving], a
            ld [mcount], a
            ld a, [act]
            and a
            jr nz, do_act
.sc:        jp set_scroll

; ---- the trigger of the tile just reached (FF3 fix:E26A): $80 entrance: the map, group and
; position pushed, the destination map (entrance id -> M_ENT + 48) at its start; $40 exit:
; back to the pushed map and position; $C0 exit to the world map (the bottom of the stack
; until the world maps are in)
do_act:     ld b, a
            xor a
            ld [act], a
            ld [zlev], a
            ld a, b
            cp $90
            jr z, .went
            cp $80
            jr nz, .exit
            call .push
            ret c
            jr .ent
.push:      ld a, [stk_n]
            cp 16
            ccf
            ret c
            inc a
            ld [stk_n], a
            dec a
            add a, a
            add a, a
            ld l, a
            ld h, 0
            ld de, stack
            add hl, de
            ld a, [cur_grp]
            ld [hl+], a
            ld a, [cur_map]
            ld [hl+], a
            ld a, [px]
            ld [hl+], a
            ld a, [py]
            ld [hl], a
            and a
            ret
.ent:       ld a, [act_id]
            and $0F
            add a, low(M_ENT + 48)
            ld l, a
            ld h, high(M_ENT + 48)
.dest:      ld a, [hl]
            ld [cur_map], a
            ld a, $FF
            ld [px], a
            jp load_map
.went:      call .push
            call .went2
            ld a, [m_title2]
            ld [m_title], a
            ret
.went2:                      ; from a world map: the map set of world w
            ld a, [cur_grp]                 ;   (0, 1, then 2) and W_ENT + id
            sub 3
            cp 2
            jr c, .wg
            ld a, 2
.wg:        ld [cur_grp], a
            ld a, [act_id]
            and $3F
            add a, low(W_ENT)
            ld l, a
            ld h, high(W_ENT)
            jr .dest
.exit:      ld a, [stk_n]
            and a
            ret z
            ld a, b
            cp $C0
            ld a, 1
            jr z, .pop
            ld a, [stk_n]
.pop:       dec a
            ld [stk_n], a
            add a, a
            add a, a
            ld l, a
            ld h, 0
            ld de, stack
            add hl, de
            ld a, [hl+]
            ld [cur_grp], a
            ld a, [hl+]
            ld [cur_map], a
            ld a, [hl+]
            ld [px], a
            ld a, [hl]
            ld [py], a
            jp load_map

nes_col:    ld a, [hl+]                     ; [HL++] NES colour -> A = low, D = high (RGB555)
            push hl
            and $3F
            add a, a
            ld l, a
            ld h, 0
            ld de, NES_RGB
            add hl, de
            ld a, [hl+]
            ld d, [hl]
            pop hl
            ret

; FF3's rule (fix:E396 / E51C): property byte 1 of the metatile: bits 0-2 = 3 impassable;
; 1 / 2 a floor level (passable only from the same level or stairs: $A5); 0 stairs (level
; reset); 4-7 bridges. (Triggers, bit 7: passable for now; milestone 2 runs them.)
; A = metatile -> C set if impassable.
passable:   ld l, a
            ld h, high(M_P1)
            ld a, [hl]
            and 7
            jr z, .stairs
            cp 4
            jr nc, .ok
            cp 3
            jr z, .no
            ld b, a
            ld a, [zlev]
            or b
            cp 3
            jr z, .no
            ld [zlev], a
.ok:        and a
            ret
.stairs:    xor a
            ld [zlev], a
            ret
.no:        scf
            ret

; metatile at map (E = x, D = y), 0-63: inside 0-31 from the layout, else the fill metatile
map_at:     ldh a, [is_world]
            and a
            jr nz, .world
            ld a, e
            or d
            and $20
            jr nz, .fill
            ld a, d                         ; HL = M_LAY + y * 32 + x
            and $1F
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld a, l
            or e
            ld l, a
            ld a, h
            add a, high(M_LAY)
            ld h, a
            ld a, [hl]
            ret
.fill:      ld a, [fill_mt]
            ret
.world:     ld a, d                         ; world map (256 x 256 in ROM): bank + y / 64,
            rlca                            ;   $4000 + (y & 63) * 256 + x
            rlca
            and 3
            ld hl, M_ENT
            add a, [hl]
            ld [MBC5_BANKL], a
            ld a, d
            and $3F
            add a, $40
            ld h, a
            ld l, e
            ld a, [hl]
            ret

; the party's map pixel (x 16 + step offset), for the npc sprites
calc_pp:    ld a, [mcount]
            ld c, a
            ld a, [mdx]
            call mulsign
            ld e, a
            ld a, [px]
            ld hl, ppx_pix
            call .one
            ld a, [mdy]
            call mulsign
            ld e, a
            ld a, [py]
.one:       push hl                         ; [HL] = A 16 + E (E signed)
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld d, 0
            bit 7, e
            jr z, .p
            dec d
.p:         add hl, de
            ld d, h
            ld e, l
            pop hl
            ld a, e
            ld [hl+], a
            ld a, d
            ld [hl+], a
            ret

; ---- scroll: the camera (map pixels) = party * 16 + step offset - (PX0, PY0)
set_scroll: ld a, [mcount]
            ld c, a
            ld a, [mdx]
            call mulsign
            ld b, a
            ld a, [px]
            swap a                          ; px * 16 (mod 256: the BG ring)
            and $F0
            add a, b
            sub PX0
            ldh [scx], a
            ld a, [mdy]
            call mulsign
            ld b, a
            ld a, [py]
            swap a
            and $F0
            add a, b
            sub PY0
            ldh [scy], a
            ret
mulsign:    and a                           ; A = -1 / 0 / 1 -> A = sign * C
            ret z
            bit 7, a
            ld a, c
            ret z
            cpl
            inc a
            ret

; ---- the party sprite (fix:D8D3 / DA2B): frame = facing's offset | (step pixel & 8); on the
; second frame the sprite moves a pixel (left while walking up / down, up otherwise)
make_oam:   ld a, [facing]
            ld l, a
            ld h, high(M_FACE)
            ld a, [hl]                      ; (M_FACE: $5D00 + facing)
            ld b, a
            ld a, [mcount]
            and 8
            or b
            add a, low(M_FRAME)
            ld e, a
            ld d, high(M_FRAME)
            ld b, PX0 + 8                   ; B = x, C = y (OAM coordinates)
            ld c, PY0 + 16 - 3              ; (3 pixels up as FF3: fix:D8CA)
            ld a, [mcount]
            and 8
            jr z, .pos
            ld a, [mdy]
            and a
            jr z, .up1
            dec b
            jr .pos
.up1:       dec c
.pos:       ld hl, oam_buf
            call .spr                       ; TL
            ld a, c
            add a, 8
            ld c, a
            call .spr                       ; BL
            ld a, b
            add a, 8
            ld b, a
            ld a, c
            sub 8
            ld c, a
            call .spr                       ; TR
            ld a, c
            add a, 8
            ld c, a
.spr:       ld a, c                         ; BR (falls through)
            ld [hl+], a
            ld a, b
            ld [hl+], a
            ld a, [de]
            inc de
            ld [hl+], a
            ld a, [de]
            inc de
            ld [hl+], a
            ret

; ---- metatiles into the BG ring: queued, written in V-Blank (directly while the LCD is off)
; line entering the view at the start of a step (12 metatiles: a margin either side)
draw_edge:  ld a, [mdx]
            and a
            jr z, .vert
            ld b, 6                         ; column px + 6 (right) or px - 6 (left)
            bit 7, a
            jr z, .h1
            ld b, -6
.h1:        ld a, [px]
            add a, b
            ld e, a
            ld a, [py]
            sub 5
            ld d, a
            ld b, 12
.hl:        push bc
            push de
            call q_mt
            pop de
            pop bc
            inc d
            dec b
            jr nz, .hl
            ret
.vert:      ld a, [mdy]
            ld b, 5                         ; row py + 5 (down) or py - 5 (up): the view shows
            bit 7, a                        ;   rows py - 4 .. py + 4
            jr z, .v1
            ld b, -5
.v1:        ld a, [py]
            add a, b
            ld d, a
            ld a, [px]
            sub 5
            ld e, a
            ld b, 12
.vl:        push bc
            push de
            call q_mt
            pop de
            pop bc
            inc e
            dec b
            jr nz, .vl
            ret

; queue metatile (E = x, D = y) (wrapped to 0-63): its ring cell, 4 tiles and palette
q_mt:       ld a, e
            ld c, a
            ldh a, [cmask]                  ; ($3F on a map, $FF on a world map)
            and c
            ld e, a
            ld a, d
            ld c, a
            ldh a, [cmask]                  ; ($3F on a map, $FF on a world map)
            and c
            ld d, a
            push de
            call map_at
            pop de
            ld c, a                         ; C = metatile
            ld a, [q_n]
            cp QMAX
            ret nc                          ; (full: dropped; the queue holds a line)
            ld l, a
            inc a
            ld [q_n], a
            ld a, l                         ; entry = qbuf + 8 n
            add a, a
            add a, a
            add a, a
            ld l, a
            ld h, high(qbuf)
            ld a, e                         ; BG address = $9800 + (y & 15) * 64 + (x & 15) * 2
            and $0F
            add a, a
            ld b, a
            ld a, d
            and 3
            rrca
            rrca
            or b
            ld [hl+], a                     ; low
            ld a, d
            and $0C
            rrca
            rrca
            add a, $98
            ld [hl+], a                     ; high
            ld b, high(M_TL)                ; the four tiles and the palette
            ld a, [bc]
            ld [hl+], a
            inc b
            ld a, [bc]
            ld [hl+], a
            inc b
            ld a, [bc]
            ld [hl+], a
            inc b
            ld a, [bc]
            ld [hl+], a
            inc b
            ld a, [bc]                      ; (ATTR: the NES attribute = CGB palette 0-3)
            and 3
            ld [hl+], a
            ld a, [q_direct]
            and a
            ret z
            jp q_flush                      ; (LCD off: at once)

; written in V-Blank (or with the LCD off): each entry 4 tiles + 4 attribute cells
q_flush:    ld a, [q_n]
            and a
            ret z
            ld c, a
            ld hl, qbuf
.e:         ld a, [hl+]
            ld e, a
            ld a, [hl+]
            ld d, a
            ld a, [hl+]                     ; TL
            ld [de], a
            inc e
            ld a, [hl+]                     ; TR
            ld [de], a
            ld a, e
            add a, 31
            ld e, a
            jr nc, .n1
            inc d
.n1:        ld a, [hl+]                     ; BL
            ld [de], a
            inc e
            ld a, [hl+]                     ; BR
            ld [de], a
            ld b, [hl]                      ; palette
            inc hl
            ld a, 1
            ldh [rVBK], a
            ld a, b
            ld [de], a
            dec e
            ld [de], a
            ld a, e
            sub 32
            ld e, a
            jr nc, .n2
            dec d
.n2:        ld a, b
            ld [de], a
            inc e
            ld [de], a
            xor a
            ldh [rVBK], a
            inc hl                          ; (entries are 8 bytes)
            dec c
            jr nz, .e
            xor a
            ld [q_n], a
            ret

; ---- banked code (the menus run in CODE1): bank-0 helpers that read another ROM bank restore
; the caller's (code_bank) before returning
; A = bank, HL = routine: call it with that bank in the window
far_call:   ld [fc_bank], a
            ld a, [code_bank]
            push af
            ld a, [fc_bank]
            ld [code_bank], a
            ld [MBC5_BANKL], a
            call .jp
            pop af
            ld [code_bank], a
            ld [MBC5_BANKL], a
            ret
.jp:        jp hl
rbank:      push af                         ; the caller's bank back (flags kept)
            ld a, [code_bank]
            ld [MBC5_BANKL], a
            pop af
            ret
; A = bank, HL = address -> A = the byte, HL + 1
rd_byte:    ld [MBC5_BANKL], a
            ld a, [hl+]
            jr rbank
; A = bank, HL -> DE, BC bytes
rd_copy:    ld [MBC5_BANKL], a
            call memcpy
            jr rbank
; vcopy from bank vc_src
vcopyx:     push af
            ld a, [vc_src]
            ld [MBC5_BANKL], a
            pop af
            call vcopy
            jr rbank

; ---- helpers
lcd_off:    ldh a, [rLCDC]                  ; (Lot Check: only in V-Blank)
            bit 7, a
            ret z
.w:         ldh a, [rLY]
            cp 144
            jr c, .w
            xor a
            ldh [rLCDC], a
            ret
memclr:     xor a                           ; HL = start, DE = length
            ld [hl+], a
            dec de
            ld a, d
            or e
            jr nz, memclr
            ret
memcpy:     ld a, [hl+]                     ; HL -> DE, BC bytes
            ld [de], a
            inc de
            dec bc
            ld a, b
            or c
            jr nz, memcpy
            ret
dma_rom:    ld a, high(oam_buf)
            ldh [rDMA], a
            ld a, 40
.w:         dec a
            jr nz, .w
            ret
dma_end:


section wram, $C000
oam_buf:    ds 160
            ds 96
qbuf:       ds 8 * QMAX                     ; ($C100: page-aligned)
px:         ds 1
py:         ds 1
mdx:        ds 1
mdy:        ds 1
mcount:     ds 1
moving:     ds 1
facing:     ds 1
zlev:       ds 1
q_n:        ds 1
q_direct:   ds 1
pad_old:    ds 1
code_bank:  ds 1
fc_bank:    ds 1
vc_src:     ds 1
m_title:    ds 1
m_title2:   ds 1
pad_new:    ds 1
mpad:       ds 1                            ; the pad as the movement sees it (events: theirs)
lcd_is:     ds 1                            ; 1 once the LCD is on (loads masked)
vc_left:    ds 1
vc_bank:    ds 1
tr_cnt:     ds 48
tr_n:       ds 1
tr_id:      ds 1
act:        ds 1                            ; trigger at the step's end: 0 none, $80 entrance
act_id:     ds 1                            ;   (id), $40 previous map, $C0 world map
stk_n:      ds 1                            ; map stack: entries of group, map, x, y
stack:      ds 4 * 16
pal_sh:     ds 128
cur_map:    ds 1
cur_grp:    ds 1
fill_mt:    ds 1

section hram, $FF80
hram_dma:   ds 10
vbl_flag:   ds 1
pal_dirty:  ds 1
cmask:      ds 1
is_world:   ds 1
pad:        ds 1
scx:        ds 1
scy:        ds 1
