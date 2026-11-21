; FF1 native engine (docs/ff1-native.md): boot, standard maps, walking, doors / rooms,
; teleports. Our own code. Game data is in ROM banks filled at build time (tools/gbn/build.py):
;   bank 1 (COMMON):  $4000 party sprite tiles (16), $4100 FF1's party sprite tables (64),
;                     $4200 normal teleports: x (64), $4240 y (64), $4280 map (64)
;   banks 8-15 (tileset t = TS_BANK0 + t): $4000 tile properties (256), $4100 metatile
;                     corner tiles for CGB (UL, UR / DL, DR pages), $4300 metatile palettes
;                     (128), $4400 the 128 BG tiles (CGB); bank 16 the overworld's (256 tiles)
;   bank 81: the overworld's palettes / DMG tiles as a map bank; banks 84-87 its rows
;   banks 20- (map m = MAP_BANK0 + m): $4000 map (64 x 64), $5000 CGB BG palettes outside
;                     (32), $5020 in a room (32), $5040 CGB OBJ palettes (16), $5050 DMG
;                     OBP0 / OBP1, $5052 tileset, $5100 DMG metatile tiles outside (512),
;                     $5300 in a room (512), $5800 DMG BG tiles (pre-shaded, up to 256)

MT_DRAWQ   = 20             ; metatiles written per V-Blank at most
LCDC_ON    = $83            ; LCD on, BG tiles $8800 mode, BG map $9800, sprites 8x8 on
MBC_BANK   = $2000
COMMON     = 1
TS_BANK0   = 8
MAP_BANK0  = 20
OW_TS      = 16             ; the overworld's tileset bank (as a tileset bank, 256 tiles)
OW_INFO    = 81             ; the overworld's palettes / DMG tiles (as a map bank)
OW_ROWS    = 84             ; banks 84-87: the overworld's 256 rows (64 a bank)
MAP_OW     = $FF            ; load_map: the overworld
C_EXITX    = $42C0          ; exit teleports (standard map -> overworld): x (16), y (16)
C_EXITY    = $42D0
C_ENTRX    = $42E0          ; entrance teleports (overworld -> map): x, y, map (32 each)
C_ENTRY    = $4300
C_ENTRM    = $4320
C_OWSTART  = $43C0          ; the new game's overworld position (x, y)
rVBK       = $FF4F
rBCPS      = $FF68
rBCPD      = $FF69
rOCPS      = $FF6A
rOCPD      = $FF6B
T_PROP     = $4000
T_MTCGB    = $4100
T_MTPAL    = $4300
T_TILES    = $4400
M_MAP      = $4000
M_BGOUT    = $5000
M_BGIN     = $5020
M_OBJ      = $5040
M_OBP      = $5050
M_TS       = $5060
M_PARTYDMG = $7200          ; the party sprite pre-shaded for this map (DMG)
M_OBJBLK   = $7340          ; object graphics blocks: tile bases, count at $7350
M_OBJDMG   = $6800          ; object tiles pre-shaded (DMG), a 256-byte block each
M_OBJCGB   = $7400          ; object tiles as they are (CGB)
M_VEHCGB   = $7400          ; the overworld (bank OW_INFO): vehicle sprites (CGB / DMG ranks),
M_VEHDMG   = $7A00          ;   FF1's vehicle tables: sprite y, facing offsets, 2 x 2 frames
M_VEHY     = $5070
M_VEHFACE  = $5080
M_VEHTBL   = $50A0
V_FOOT     = 1
V_CANOE    = 2
V_SHIP     = 4
V_AIR      = 8
C_OBJTBL   = $4400          ; FF1's object 2 x 2 tables
C_INITPG   = $4500          ; new game: save page 0 and the game flags
C_INITFLG  = $4600
C_TESTPG   = $5E00          ; test builds: the save page to start with ($400)
DMG_OBP    = %11100000      ; sprite tiles hold brightness ranks: 1 white, 2 dark grey, 3 black
M_MTOUT    = $5100
M_MTIN     = $5300
M_TILES    = $5800
C_SPR      = $4000
C_MAPMAN   = $4100
C_TELEX    = $4200
TP_NOMOVE  = $01
MT_CLOSED  = $36            ; FF1's door metatiles (MAPTILE_CLOSEDDOOR / OPENDOOR / LOCKEDDOOR)
MT_OPEN    = $37
MT_LOCKED  = $3B
DLG_BANK   = 90             ; text.s: dialogue table / strings
M_FONT     = $7F00          ; map bank: DMG font code -> tile
C_FONTDMG  = $4800          ; common bank: the font for DMG (pre-shaded) / CGB, by code
C_FONTCGB  = $5000
C_WINPAL   = $4700          ; CGB palette 7: FF1's window colours
C_NESRGB   = $5D40          ; NES colour -> RGB555 (64 x 2)
WIN_ATTR   = $0F            ; CGB window cell: palette 7, VRAM bank 1
LCDC_WIN   = LCDC_ON | $60  ; window on, its map at $9C00
BOX_LINES  = 64

section bank 0, $0040
            jp vblank
section bank 0, $0048
            jp stat_int
section bank 0, $0050
            reti
section bank 0, $0100
            nop
            jp start

section bank 0, $0150
start:      di
            ld sp, $E000
            ld b, a                         ; A = $11 on a Game Boy Color
            ld a, e                         ; (E = $A5: a soft reset / game over -> the title)
            cp $A5
            ld c, 0
            jr nz, .sr
            inc c
.sr:        ldh a, [rLCDC]                  ; the LCD goes off only in V-Blank (if on)
            bit 7, a
            jr z, .lo
.vw:        ldh a, [rLY]
            cp 144
            jr c, .vw
            xor a
            ldh [rLCDC], a
.lo:
            ld hl, $C000                    ; work RAM cleared (Lot Check: no stale memory;
            ld de, $2000                    ;   inline: the stack lives in it)
.wc:        xor a
            ld [hl+], a
            dec de
            ld a, d
            or e
            jr nz, .wc
            ld hl, $FF80
            ld de, $7F
            call memclr
            ld a, c
            ldh [soft_rst], a
            ld a, b
            cp $11
            ld a, 0
            jr nz, .dm
            inc a
.dm:        ldh [is_cgb], a
            and a                           ; a Color: double speed (KEY1 + STOP)
            jr z, .ds
            ldh a, [$FF4D]                  ; (already: a soft reset)
            bit 7, a
            jr nz, .ds
            xor a
            ldh [rIE], a
            ld a, $30
            ldh [rP1], a
            ld a, 1
            ldh [$FF4D], a
            stop
            nop
.ds:
            xor a                           ; VRAM cleared (both banks on a Color)
            ldh [rVBK], a
            ld hl, $8000
            ld de, $2000
            call memclr
            ldh a, [is_cgb]
            and a
            jr z, .v0
            ld a, 1
            ldh [rVBK], a
            ld hl, $8000
            ld de, $2000
            call memclr
            xor a
            ldh [rVBK], a
.v0:        ldh a, [is_cgb]                 ; a Super Game Boy? (palettes, the border)
            and a
            call z, sgb_detect
            ld hl, dma_rom                  ; OAM DMA routine into HRAM
            ld de, hram_dma
            ld b, dma_end - dma_rom
.dc:        ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .dc
            ld a, $FF
            ld [mt_force], a
            call text_init
            ld a, COMMON                    ; new game: save page 0 and the game flags from the ROM
            call sbank
            ld hl, C_INITPG
            ld de, unsram
            ld bc, 256
            call memcpy
            ld hl, C_INITFLG
            ld de, game_flags
            ld bc, 256
            call memcpy
            ld a, TEST_INIT                 ; (test builds: a whole save page, build.py --init)
            and a
            jr z, .nti
            ld hl, C_TESTPG
            ld de, unsram
            ld bc, $400
            call memcpy
.nti:       ld a, 3
            ld [facing], a
            ld a, LCDC_ON                   ; (the STAT handler's LCDC: 8 x 16 sprites in the
            ld [lcdc_on], a                 ;   15-puzzle)
            ld a, SND_BANK                  ; the sound on
            call sbank
            call snd_init_b
            ld a, BOX_LINES                 ; LYC: the dialogue box's bottom (window off)
            ldh [rLYC], a
            ld a, $40
            ldh [rSTAT], a
            xor a
            ldh [rIF], a                    ; (a STAT write on DMG can request one: dropped)
            ld a, 3                         ; V-Blank and STAT interrupts
            ldh [rIE], a
            ei
            ldh a, [soft_rst]               ; (after a soft reset: always the title)
            and a
            ld a, $FE
            jr nz, .ti
            ld a, START_MAP                 ; (build.py: the title and a new game, unless
.ti:        cp $FE                          ;   --start says otherwise)
            jr nz, .nt
            ld a, SCR_BANK
            ld hl, ng_main
            call bank_call
            ld a, [unsram + $10]            ; (new game or continue: the save page's
            add a, 7                        ;   overworld position, + 7)
            ld d, a
            ld a, [unsram + $11]
            add a, 7
            ld e, a
            ld a, MAP_OW
            jr .ld
.nt:        cp MAP_OW
            jr nz, .st
            ld a, START_X                   ; (test builds: --start $FF,X,Y places the party)
            and a
            ld a, MAP_OW
            jr nz, .st
            ld a, COMMON
            call sbank
            ld a, [C_OWSTART]
            ld d, a
            ld a, [C_OWSTART + 1]
            ld e, a
            ld a, MAP_OW
            jr .ld
.st:        ld d, START_X
            ld e, START_Y
.ld:        call load_map
            ld a, [SV_VEH]                  ; the vehicle (save page $14; on foot if 0)
            and a
            jr nz, .vh
            inc a
.vh:        ld [vehicle], a
            call map_music
            ld a, START_ROOM                ; (test builds: start inside a room)
            and a
            jr z, .nr
            ld [inroom], a
            call room_redraw
.nr:
            ld a, START_BATTLE              ; (test builds: a battle first)
            cp $FF
            jr z, .nb
            call do_battle                  ;   (as from the field: lost / the ending too)
.nb:

; ---- main loop: one engine frame per GB frame
main:       call wait_vbl
            call read_pad
            ld a, [box_on]
            and a
            jr z, .fld
            call dlg_frame                  ; a dialogue: everything else waits
            jr .drw
.fld:       call move
            call obj_frame
            ld a, [vehicle]                 ; FF1: the ship's / airship's noise (1 / 2)
            and V_SHIP | V_AIR
            rrca
            rrca
            ld [sfx_nmode], a
.drw:       call set_scroll
            call make_oam
            jr main

wait_vbl:   call sgb_tick                   ; (a Super Game Boy's queued packet: before the
            xor a                           ;   wait, so it never takes V-Blank time)
            ldh [vbl_done], a
.w:         halt
            ldh a, [vbl_done]
            and a
            jr z, .w
            ret

; ---- V-Blank: OAM, scroll, palettes, queued metatiles
vblank:     push af
            ld a, [lmask]                   ; (a masked load: the frame counted, nothing else)
            and a
            jr nz, .mk
            push bc
            push de
            push hl
            ldh a, [rombank]                ; (restored at the end: the handler switches)
            push af
            ld hl, frame
            inc [hl]
            call hram_dma
            ldh a, [scx]
            ldh [rSCX], a
            ldh a, [scy]
            ldh [rSCY], a
            ldh a, [pal_req]
            and a
            call nz, bg_pal
            call box_vbl
            ld a, [wp_on]                   ; (a screen wipe: the window from the top)
            and a
            call nz, wp_vbl
            ld a, [ly_n]                    ; (the LCDC list: from its first line again)
            and a
            call nz, ly_vbl
            ldh a, [rLY]                    ; (a late handler: no VRAM writes outside V-Blank)
            cp 144
            jr c, .late
            ld c, MT_DRAWQ
            call q_flush
.late:      ld a, 1
            ldh [vbl_done], a
            pop af
            call sbank
            pop hl
            pop de
            pop bc
            pop af
            reti
.mk:        push bc                         ; (and the music: the STAT handler only guards)
            push de
            push hl
            ld hl, frame
            inc [hl]
            ld a, 1
            ldh [vbl_done], a
            ldh a, [rombank]
            push af
            ld a, SND_BANK
            ld [MBC_BANK], a
            call snd_frame_b
            pop af
            ld [MBC_BANK], a
            pop hl
            pop de
            pop bc
            pop af
            reti

; ---- joypad: pad = buttons (bit 0 A, 1 B, 2 Select, 3 Start, 4 Right, 5 Left, 6 Up, 7 Down)
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
            ld c, a
            ldh a, [pad]                    ; newly pressed this frame
            cpl
            and c
            ldh [pad_new], a
            ld a, c
            ldh [pad], a
            ld a, $30
            ldh [rP1], a
            ld a, [sfx_menu]                ; menus: FF1's cursor sound on a new direction,
            and a                           ;   its select sound on A / B
            jr z, .ns
            ldh a, [pad_new]
            ld b, SFX_MOVE
            and $F0
            jr nz, .rq
            ldh a, [pad_new]
            and 3
            jr z, .ns
            ld b, SFX_SEL
.rq:        ld a, b
            ld [sfx_req], a
.ns:        ld a, c                         ; A + B + Start + Select: soft reset (Lot Check)
            and $0F
            cp $0F
            ret nz
            xor a
            ld [$0000], a                   ; (cart RAM off)
            jp game_over

; ---- load standard map A with the party at (D = x, E = y): LCD off in V-Blank, graphics,
; palettes, the map drawn, LCD on
; a map transition (FF1: the screen wiped closed, the map loaded, wiped open)
load_map_w: push af
            ld a, 1
            ld [wp_req], a
            pop af
load_map:   push af
            ld a, [wp_req]
            and a
            call nz, wipe_close
            pop af
            ld [cur_map], a
            xor a                           ; (the field: no menu sounds)
            ld [sfx_menu], a
            ld a, [ml_keep]                 ; (a new map, not the reload after a menu: no
            and a                           ;   palette cycle)
            jr nz, .rl
            ld [pc_req], a
.rl:
            ld a, [cur_map]
            ld b, a
            ld a, d
            ld [px], a
            ld a, e
            ld [py], a
            xor a
            ld [inroom], a
            ld [moving], a
            ld [mcount], a
            ld [mdx], a
            ld [mdy], a
            ld [q_n], a
            ld [q_rd], a
            ld a, b
            cp MAP_OW
            jr nz, .sm
            ld a, 1                         ; the overworld: 256 x 256, its own banks
            ldh [maptype], a
            ld a, $FF
            ldh [cmask], a
            ld a, OW_INFO
            ld [map_bank], a
            ld a, OW_TS
            ld [ts_bank], a
            jr .lcd
.sm:        xor a
            ldh [maptype], a
            ld a, 63
            ldh [cmask], a
            ld a, b
            add a, MAP_BANK0
            ld [map_bank], a
            call sbank
            ld a, [M_TS]
            add a, TS_BANK0
            ld [ts_bank], a
.lcd:        call lcd_off                    ; (LCD off in V-Blank, interrupts off)
.off:       ldh a, [is_cgb]
            and a
            jr z, .dmg
            ld a, [ts_bank]                 ; CGB: the tileset's tiles -> $9000 (0-127),
            call sbank                ;   the overworld's 128-255 -> $8800
            ld hl, T_TILES
            ld de, $9000
            ld bc, 128 * 16
            call memcpy
            ldh a, [maptype]
            and a
            jr z, .t1
            ld de, $8800
            ld bc, 128 * 16
            call memcpy
.t1:
            ld a, [map_bank]
            call sbank
            ld hl, M_BGOUT
            ld a, $80
            call cgb_pal32
            ld a, $80                       ; OBJ palettes 0-3 (NES sprite palettes)
            ldh [rOCPS], a
            ld hl, M_OBJ
            ld b, 32
.op:        ld a, [hl+]
            ldh [rOCPD], a
            dec b
            jr nz, .op
            ld a, COMMON                    ; party sprite tiles at $8000 (as they are)
            call sbank
            ld hl, C_SPR
            ld de, $8000
            ld bc, 16 * 16
            call memcpy
            ld hl, M_OBJCGB
            call obj_tiles
            ld hl, M_VEHCGB
            call veh_tiles
            jr .drw
.dmg:       ld a, [map_bank]                ; DMG: pre-shaded variants 0-127 -> $9000,
            call sbank                ;   128-255 -> $8800
            ld hl, M_TILES
            ld de, $9000
            ld bc, 128 * 16
            call memcpy
            ld de, $8800
            ld bc, 128 * 16
            call memcpy
            ld a, %11100100                 ; tile values are shades
            call bgp_w
            ld a, DMG_OBP
            call obp0_w
            ld hl, M_PARTYDMG               ; party sprite pre-shaded for this map
            ld de, $8000
            ld bc, 16 * 16
            call memcpy
            ld hl, M_OBJDMG
            call obj_tiles
            ld hl, M_VEHDMG
            call veh_tiles
.drw:       call party_spr                  ; (the leader's class)
            call sgb_map
            ld a, [ml_keep]                 ; (a reload keeps the objects)
            and a
            call z, obj_load
            xor a
            ld [ml_keep], a
            call font_map
            call draw_all
            call set_scroll
            ldh a, [scx]
            ldh [rSCX], a
            ldh a, [scy]
            ldh [rSCY], a
            call make_oam
            call dma_safe
            call map_music
            ld a, [pc_req]                  ; (a palette cycle in to follow: black first)
            and a
            call nz, pc_black
            ld a, [wp_req]                  ; (a transition: wiped open)
            and a
            jr nz, wipe_open
            ld a, LCDC_ON
            jp lcd_on

; the map drawn again after a full screen (menu): position, room and objects as they were
map_reload: ld a, [inroom]
            push af
            ld a, 1
            ld [ml_keep], a
            ld a, [px]
            ld d, a
            ld a, [py]
            ld e, a
            ld a, [cur_map]
            call load_map
            pop af
            and a
            jr z, .pc
            ld [inroom], a
            call room_redraw
.pc:        ld a, [pc_req]                  ; FF1: the palettes cycle in
            and a
            ret z
            xor a
            ld [pc_req], a
            ld a, SCR_BANK
            ld hl, pc_in
            jp bank_call

; the overworld: the vehicles' sprite tiles (FF1's OW objects) to sprite tiles $10-$6F
veh_tiles:  ldh a, [maptype]
            and a
            ret z
            ld a, [map_bank]
            call sbank
            ld de, $8100
            ld bc, 96 * 16
            jp memcpy

; the map's object graphics blocks (HL = their tiles in the map bank, 256 bytes a block) to
; their tile bases ($8000 + 16 x base; LCD off)
obj_tiles:  ldh a, [maptype]
            and a
            ret nz
            ld a, [map_bank]
            call sbank
            ld a, [M_OBJBLK + 16]
            and a
            ret z
            ld b, a
            ld de, M_OBJBLK
.b:         push bc
            push de
            ld a, [de]                      ; tile base -> VRAM $8000 + 16 base
            swap a
            ld e, a
            and $0F
            add a, $80
            ld d, a
            ld a, e
            and $F0
            ld e, a
            ld bc, 256
            call memcpy
            pop de
            inc de
            pop bc
            dec b
            jr nz, .b
            ret

cgb_pal32:  ld b, 32                        ; HL = 32 bytes of BG palettes 0-3 (A = BCPS)
pal_blk:    push af                         ; B bytes (a masked load: into the shadow)
            ld a, [lmask]
            and a
            jr nz, .m
            pop af
            ldh [rBCPS], a
.p:         ld a, [hl+]
            ldh [rBCPD], a
            dec b
            jr nz, .p
            ret
.m:         pop af
            call bcps_w
.q:         ld a, [hl+]
            call bcpd_w
            dec b
            jr nz, .q
            ret

; V-Blank, CGB: the BG palettes for the room state
bg_pal:     xor a
            ldh [pal_req], a
            ld a, [pc_hold]                 ; (a palette cycle in progress: its own colours)
            and a
            ret nz
            ldh a, [is_cgb]
            and a
            ret z
            ld a, [map_bank]
            call sbank
            ld hl, M_BGOUT
            ld a, [inroom]
            and a
            jr z, .o
            ld hl, M_BGIN
.o:         ld a, $80
            jp cgb_pal32

; ---- movement on a standard map (FF1: one metatile in 16 frames, a pixel a frame)
move:       ld a, [moving]
            and a
            jr z, .idle
            ld a, [mcount]
            inc a
            ld [mcount], a
            cp 16
            ret nz
            ldh a, [cmask]                  ; step done
            ld c, a
            ld a, [mdx]
            ld b, a
            ld a, [px]
            add a, b
            and c
            ld [px], a
            ld a, [mdy]
            ld b, a
            ld a, [py]
            add a, b
            and c
            ld [py], a
            xor a
            ld [moving], a
            ld [mcount], a
            ld [mdx], a
            ld [mdy], a
            call arrived                    ; teleports
            ret c
.idle:      ld a, [q_rd]                    ; (a room redraw still being written: wait)
            ld b, a
            ld a, [q_n]
            sub b
            cp 24
            ret nc
            ldh a, [pad_new]                ; Start: the main menu
            bit 3, a
            jr z, .nm
            ld hl, menu_main                   ; (FF1: the palettes cycle out first)
            call pc_menu
            ld a, [menu_act]                ; Warp / Exit cast in the menu
            and a
            jp z, map_reload
            ldh a, [maptype]
            and a
            jp nz, map_reload               ; (on the overworld: nothing to leave)
            ld a, [menu_act]
            cp 1
            jp z, arrived.warp
            xor a
            ld [fdepth], a
            jp arrived.toow
.nm:        ldh a, [pad_new]                ; Select: FF1's lineup menu; with B held on the
            bit 2, a                        ;   overworld, its world map
            jr z, .na
            ldh a, [maptype]
            and a
            jr z, .lu
            ldh a, [pad]
            bit 1, a
            jr z, .lu
            ld hl, minimap                   ; (FF1: the palettes cycle out first)
            call pc_menu
            jp map_reload
.lu:        ld hl, lineup                   ; (FF1: the palettes cycle out first)
            call pc_menu
            jp map_reload
.na:        ldh a, [maptype]                ; the overworld: B presses counted (FF1 joy_b);
            and a                           ;   the 55th with A + B held on the ship: the
            jr z, .np                       ;   15-puzzle
            ldh a, [pad_new]
            bit 1, a
            jr z, .pc
            ld hl, pz_bcnt
            inc [hl]
.pc:        ld a, [pz_bcnt]
            cp 55
            jr nz, .np
            ld a, [vehicle]
            cp V_SHIP
            jr nz, .np
            ldh a, [pad]
            and 3
            cp 3
            jr nz, .np
            ld hl, pz_bcnt
            inc [hl]
            ld hl, puzzle                   ; (FF1: the palettes cycle out first)
            call pc_menu
            jp map_reload
.np:        ldh a, [pad_new]                ; A on a standard map: talk to what is in front
            bit 0, a
            jr z, .nt
            ldh a, [maptype]
            and a
            jp z, talk
            jp ow_abutton                   ; (the overworld: the airship)
.nt:        ldh a, [pad]
            ld bc, $0100                    ; B = dx, C = dy; facing in D
            ld d, 0
            bit 4, a
            jr nz, .go
            ld bc, $FF00
            ld d, 1
            bit 5, a
            jr nz, .go
            ld bc, $00FF
            ld d, 2
            bit 6, a
            jr nz, .go
            ld bc, $0001
            ld d, 3
            bit 7, a
            ret z
.go:        ld a, d
            ld [facing], a
            ldh a, [cmask]
            ld d, a
            ld a, [px]                      ; the target metatile
            add a, b
            and d
            ld [tx], a
            ld e, a
            ld a, [py]
            add a, c
            and d
            ld [ty], a
            ld d, a
            push bc
            call map_at                     ; A = metatile
            call props                      ; D, E = its two property bytes
            pop bc
            ldh a, [maptype]                ; the overworld: FF1's vehicle rules
            and a
            jr z, .smr
            push bc
            call ow_canmove
            pop bc
            ret c
            jr .ok
.smr:       push de                         ; an object there: blocked
            push bc
            ld a, [tx]
            ld e, a
            ld a, [ty]
            ld d, a
            call obj_at
            pop bc
            pop de
            ret c
            call sm_special                 ; crown / cube / orbs gates, the altars
            ret c
            ld a, d                         ; doors and rooms
            and $1E
            cp $02
            jr z, .door
            cp $04
            jr z, .door
            cp $06
            jr z, .close
            bit 0, d
            ret nz                          ; TP_NOMOVE
.ok:        ld a, b
            ld [mdx], a
            ld a, c
            ld [mdy], a
            ld a, 1
            ld [moving], a
            xor a
            ld [mcount], a
            jp draw_edge
.door:      ld a, d                         ; a locked door: only with the Mystic Key (FF1)
            and $1E
            cp $04
            jr nz, .dr
            ld a, [ITEMS + 5]
            and a
            ret z
.dr:        ld a, [inroom]                  ; into a room: palette, the open door drawn
            and a
            jr nz, .ok
            push bc
            ld a, 1
            ld [inroom], a
            ld a, [tx]
            ld [door_x], a
            ld a, [ty]
            ld [door_y], a
            ld b, MT_OPEN
            call door_draw
            call room_redraw
            pop bc
            jr .ok
.close:     ld a, [inroom]                  ; out of the room: palette, the door closed
            and a
            jr z, .ok
            push bc
            xor a
            ld [inroom], a
            ld b, MT_CLOSED
            call door_draw
            call room_redraw
            pop bc
            jr .ok

; the step ended on (px, py): normal teleports (FF1: first property byte bits 7-6 = 10,
; second byte = teleport number). C: the map changed.
arrived:    ld a, [px]
            ld e, a
            ld a, [py]
            ld d, a
            call map_at
            call props
            ld a, d                         ; (FF1 tileprop_now: the item menu's checks)
            ld [tprop_now], a
            ldh a, [maptype]
            and a
            jr nz, .ow
            ld a, d                         ; a door with a shop number: the shop
            and $1E
            cp $02
            jr nz, .nsh
            ld a, e
            and a
            jr z, .nsh
            ld [shop_arg], a
            ld hl, shop_main                ; (FF1: the palettes cycle out first)
            call pc_menu
            xor a                           ; (out of the room, as FF1)
            ld [inroom], a
            call map_reload
            scf
            ret
.nsh:       push de                         ; poison (FF1 MapPoisonDamage); damage tiles:
            call ow_poison                  ;   everyone - 1 HP, not below 1
            pop de
            ld a, d
            and $1E
            cp $0C
            jr nz, .ndm
            push de
            xor a
.dm:        push af
            call ch_rec
            ld a, l
            add a, CH_HP
            ld l, a
            ld a, [hl+]
            ld c, a
            ld a, [hl-]
            and a
            jr nz, .dd
            ld a, c
            cp 2
            jr c, .dn
.dd:        ld a, [hl]
            sub 1
            ld [hl+], a
            ld a, [hl]
            sbc a, 0
            ld [hl], a
.dn:        pop af
            inc a
            cp 4
            jr c, .dm
            pop de
.ndm:       ld a, d                         ; a battle tile (FF1 SMMove_Battle)
            and $1E
            cp $0A
            jr nz, .nbt
            bit 7, e
            jr z, .spk
            call enc_step                   ; random: the map's rate
            ld b, a
            ld a, [cur_map]
            inc a
            ld l, a
            ld h, high(B_RATES)
            ld a, BTL_DATA
            ld [fc_bank], a
            call far_byte
            ld c, a
            ld a, b
            cp c
            jr nc, .nbt
            ld a, [cur_map]
            add a, 64
            call enc_form
            jp do_battle
.spk:       ld a, e                         ; spiked: the second byte is the formation
            jp do_battle
.nbt:
            ld a, d
            and $C0
            cp $80
            jr z, .norm
            cp $C0
            jr z, .exit
            cp $40
            jr z, .warp
            and a
            ret
.warp:      ld a, [fdepth]                  ; warp: the previous floor, or the overworld where
            and a                           ;   the party entered from
            jr z, .toow
            dec a
            ld [fdepth], a
            add a, a
            add a, a
            ld l, a
            ld h, 0
            ld bc, fstack
            add hl, bc
            ld d, [hl]                      ; x, y, room state, map
            inc hl
            ld e, [hl]
            inc hl
            ld a, [hl+]
            ld [warp_room], a
            ld a, [hl]
            call load_map_w
            ld a, [warp_room]               ; (FF1 restores the room state too)
            and a
            jr z, .wr
            ld [inroom], a
            call room_redraw
.wr:        scf
            ret
.toow:      ld a, [ow_x]
            ld d, a
            ld a, [ow_y]
            ld e, a
            ld a, MAP_OW
            call load_map_w
            scf
            ret
.ow:        ld a, [unsram + $16]            ; the bridge crossed: the story (FF1 bridgescene)
            cp 1
            jr nz, .nbr
            ld a, $80
            ld [unsram + $16], a
            push de
            ld a, SCR_BANK                  ; (FF1: the palettes cycle out first)
            ld hl, pc_out
            call bank_call
            ld a, STORY_FIRST
            ld b, 4 + STORY_CRED
            ld hl, story_show
            ld a, SCR_BANK
            call bank_call_ab
            pop de
            call map_reload
            scf
            ret
.nbr:       ld a, [vehicle]                 ; on foot: poison
            cp V_FOOT
            push de
            call z, ow_poison
            pop de
            ld a, [shop_pend]               ; the caravan
            and a
            jr z, .nc
            ld [shop_arg], a
            xor a
            ld [shop_pend], a
            ld hl, shop_main                ; (FF1: the palettes cycle out first)
            call pc_menu
            call map_reload
            scf
            ret
.nc:        ld a, [no_enc]                  ; (boarding / landing steps: none)
            and a
            jr nz, .owe
            ld a, [vehicle]
            cp V_AIR
            jr z, .owe
            bit 6, e                        ; overworld: random encounters (FF1 OWCanMove)
            jr z, .owe
            ld a, [vehicle]                 ; (the ship: 3 in 256)
            cp V_SHIP
            ld c, ENC_OW
            jr nz, .rt
            ld c, 3
.rt:        push de
            push bc
            call enc_step
            pop bc
            pop de
            cp c                            ; (FF1: 10 in 256 a step)
            jr nc, .owe
            ld a, e                         ; the domain: land (8 x 8 grid), sea, river
            and 3
            jr z, .land
            cp 2
            ld a, $42
            jr z, .dom
            ld a, [py]
            rlca
            and 1
            or $40
            jr .dom
.land:      ld a, [px]
            rlca
            rlca
            rlca
            and 7
            ld b, a
            ld a, [py]
            srl a
            srl a
            and $38
            or b
.dom:       call enc_form
            jp do_battle
.owe:       ld a, [vehicle]                 ; (flying: no entrances)
            cp V_AIR
            jr z, .ncy
            bit 7, e                        ; second byte bit 7 = an entrance,
            jr z, .ncy                      ;   bits 0-5 its number
            jr .ent
.ncy:       and a                           ; (nothing: C clear, the next step at once)
            ret
.ent:       ld a, [px]                      ; (the overworld position kept for the warp out)
            ld [ow_x], a
            ld a, [py]
            ld [ow_y], a
            xor a
            ld [fdepth], a
            ld a, e
            and $3F
            ld l, a
            ld a, COMMON
            call sbank
            ld h, high(C_ENTRX)
            ld a, l
            add a, low(C_ENTRX)
            ld l, a
            ld a, h
            adc a, 0
            ld h, a
            ld d, [hl]                      ; x (C_ENTRX + n)
            ld bc, C_ENTRY - C_ENTRX
            add hl, bc
            ld e, [hl]                      ; y
            ld bc, C_ENTRM - C_ENTRY
            add hl, bc
            ld a, [hl]                      ; map
            call load_map_w
            scf
            ret
.exit:      xor a                           ; exit to the overworld at FF1's exit position
            ld [fdepth], a
            ld a, COMMON
            call sbank
            ld a, e
            and 15
            ld l, a
            ld h, high(C_EXITX)
            ld a, l
            add a, low(C_EXITX)
            ld l, a
            ld d, [hl]
            ld a, l
            add a, 16
            ld l, a
            ld e, [hl]
            ld a, MAP_OW
            call load_map_w
            scf
            ret
.norm:      call do_tele
            scf
            ret

; a normal teleport (E = its number): this floor pushed (FF1: for a later warp), the new map
do_tele:    push de                         ; push this floor

            ld a, [fdepth]
            cp 8
            jr nc, .nf
            ld b, a
            inc a
            ld [fdepth], a
            ld a, b
            add a, a
            add a, a
            ld l, a
            ld h, 0
            ld bc, fstack
            add hl, bc
            ld a, [px]
            ld [hl+], a
            ld a, [py]
            ld [hl+], a
            ld a, [inroom]
            ld [hl+], a
            ld a, [cur_map]
            ld [hl], a
.nf:        pop de
            ld a, COMMON
            call sbank
            ld l, e
            ld h, high(C_TELEX)
            ld a, [hl]                      ; x
            ld b, a
            ld a, l
            add a, $40
            ld l, a
            ld a, [hl]                      ; y
            ld c, a
            ld a, l
            add a, $40
            ld l, a
            ld a, [hl]                      ; map
            ld d, b
            ld e, c
            call load_map_w
            scf
            ret

; talk to the object in front of the party (FF1: its talk routine picks the dialogue), or
; "There's nothing there."
talk:       ld a, [px]
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
.f4:        ld a, e
            and 63
            ld e, a
            ld a, d
            and 63
            ld d, a
            call obj_at                     ; C: HL inside the object's slot
            jr nc, .tile
            ld a, l
            and $F0
            ld l, a
            push hl
            ld bc, O_TALK
            add hl, bc
            ld [hl], 1                      ; it turns to the party
            pop hl
            call talk_obj                   ; A = dialogue
.dlg:       jp dlg_open
.tile:      call map_at                     ; no object: the tile (FF1 TalkToSMTile)
            call props
            ld a, d
            and $1E
            cp $08                          ; a treasure chest
            jr z, .tc
            ld a, d
            and $C2                         ; (teleports / doors: "nothing there")
            ld a, 0
            jr nz, .dlg
            ld a, e                         ; the tile's own dialogue
            jr .dlg
.tc:        ld a, e
            call open_chest
            jr .dlg

; A = metatile -> D, E = its property bytes (the tileset bank)
props:      add a, a
            ld l, a
            ld h, high(T_PROP)
            ld a, [ts_bank]
            call sbank
            ld a, [hl+]
            ld d, a
            ld e, [hl]
            ret

; the door metatile B at (door_x, door_y), queued
door_draw:  ld a, [door_x]
            ld e, a
            ld a, [door_y]
            ld d, a
            ld a, b
            ld [mt_force], a
            call q_mt
            ld a, $FF
            ld [mt_force], a
            call text_init
            ret

; room state changed: CGB palettes in the next V-Blank; DMG: the visible metatiles again with
; the other pre-shaded tiles (the lines entering later are drawn with the new state anyway)
room_redraw:
            ld a, 1
            ldh [pal_req], a
            ldh a, [is_cgb]
            and a
            ret nz
            ld a, [py]
            sub 5
            ld d, a
            ld b, 11
.r:         ld a, [px]                      ; (11 x 11: the view and the line the step
            sub 5                           ;   brings in)
            ld e, a
            ld c, 11
.c:         push bc
            push de
            call q_mt
            pop de
            pop bc
            inc e
            dec c
            jr nz, .c
            inc d
            dec b
            jr nz, .r
            ret

; ---- metatile number at (E = x, D = y) of the map (the map bank left mapped)
map_at:     ldh a, [maptype]
            and a
            jr z, .sm
            ld a, d                         ; overworld: bank OW_ROWS + y / 64, row (y & 63)
            rlca                            ;   x 256 + x
            rlca
            and 3
            add a, OW_ROWS
            call sbank
            ld a, d
            and 63
            add a, $40
            ld h, a
            ld l, e
            ld a, [hl]
            ret
.sm:        ld a, [map_bank]
            call sbank
            ld l, d                         ; HL = M_MAP + 64 y + x
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld a, e
            add a, l
            ld l, a
            ld a, h
            adc a, high(M_MAP)
            ld h, a
            ld a, [hl]
            ret

; ---- scroll: the party's metatile at screen (72, 64)
set_scroll: ld a, [mcount]                  ; offset in the step
            ld c, a
            ld a, [mdx]
            call mulsign
            ld b, a
            ld a, [px]
            swap a
            and $F0
            add a, b
            sub 72
            ldh [scx], a
            ld a, [mdy]
            call mulsign
            ld b, a
            ld a, [py]
            swap a
            and $F0
            add a, b
            sub 64
            ldh [scy], a
            ret
mulsign:    and a                           ; A = sign (-1 / 0 / 1) -> A = sign * C
            ret z
            bit 7, a
            ld a, c
            ret z
            cpl
            inc a
            ret

; ---- party sprite (FF1's 2x2 tables: tile, attributes for UL, DL, UR, DR)
make_oam:   ldh a, [maptype]                ; the overworld: vehicles
            and a
            jp nz, veh_oam
make_oam_f: ld a, COMMON
            call sbank
            ld a, [facing]
            add a, a
            ld b, a
            ld a, [mcount]                  ; walking frame: second half of a step
            and 8
            jr z, .f0
            inc b
.f0:        ld a, b
            add a, a
            add a, a
            add a, a
            ld l, a
            ld h, high(C_MAPMAN)
            ld de, oam_buf
            ld bc, $5050                    ; B = y + 16, C = x + 8 (screen 64 / 72)
            call .spr
            ld b, $58
            call .spr
            ld bc, $5058
            call .spr
            ld b, $58
            call .spr
            jp obj_draw
.spr:       ld a, b
            ld [de], a
            inc de
            ld a, c
            ld [de], a
            inc de
            ld a, [hl+]
            ld [de], a
            inc de
            ld a, [hl+]                     ; NES attributes -> GB: flip bit 6 -> 5, CGB
            push bc                         ;   palette 0-3 (DMG: one palette)
            ld b, a
            and $40
            rrca
            ld c, a
            ld a, b
            and 3
            or c
            pop bc
            ld [de], a
            inc de
            ret

; the overworld's sprites (FF1 DrawOWSprites): the party or its vehicle at the screen's
; centre (FF1's vehicle frames, y by vehicle), the ship / airship where they stand
veh_oam:    ld a, [vehicle]
            cp V_FOOT
            jr nz, .veh
            call make_oam_f
            jr .objs
.veh:       ld hl, oam_buf                  ; (all hidden first)
            ld b, 40
            xor a
.c:         ld [hl+], a
            inc hl
            inc hl
            inc hl
            dec b
            jr nz, .c
            ld a, [vehicle]
            ld e, a
            ld d, 0
            ld a, [map_bank]
            call sbank
            ld hl, M_VEHY
            add hl, de
            ld a, [hl]
            sub $6C - $50                   ; (FF1 y $6C on foot = our $50)
            ld [vh_y], a
            ld a, [air_y]                   ; (the airship taking off / landing: its y)
            and a
            jr z, .ny
            ld [vh_y], a
.ny:
            ld a, [facing]                  ; facing 0-3 (R L U D) -> FF1 bits 1, 2, 8, 4
            ld e, a
            ld hl, .fbit
            add hl, de
            ld e, [hl]
            ld a, [map_bank]
            call sbank
            ld hl, M_VEHFACE
            add hl, de
            ld a, [hl]
            ld b, a
            ld a, [vehicle]
            cp V_AIR
            ldh a, [frame]
            jr z, .fa
            ld a, [mcount]
.fa:        and 8
            or b
            ld e, a
            ld hl, M_VEHTBL
            add hl, de
            ld a, [vehicle]                 ; tile base: ship $20, canoe $50, airship $38
            ld c, $20
            cp V_SHIP
            jr z, .tb
            ld c, $50
            cp V_CANOE
            jr z, .tb
            ld c, $38
.tb:        ld de, oam_buf
            ld a, [vh_y]
            ld b, a
            call .two
            ld a, [vh_y]
            add a, 8
            ld b, a
            call .two
.objs:      ld a, [vehicle]                 ; the ship / airship standing on the map
            cp V_SHIP
            jr z, .na
            ld hl, SV_SHIP
            ld c, $20
            ld de, oam_buf + 16
            call .obj
.na:        ld a, [vehicle]
            cp V_AIR
            jr z, .shd
            ld hl, SV_AIR
            ld c, $38
            ld de, oam_buf + 32
            jr .obj
.shd:       ldh a, [frame]                  ; flying: FF1 DrawAirshipShadow, on the ground
            rrca                            ;   every other frame (FF1's flicker)
            ret nc
            ld a, $48
            ld [vh_x], a
            ld a, $6F - $1C
            ld [vh_y], a
            ld c, $10                       ; (OW object tiles $10: the shadow; FF1
            ld de, oam_buf + 32             ;   lut_OWObjectSprTbl's entry in our order)
            ld hl, .shtbl
            jr .od
.shtbl:     db 0, 3, 1, 3, 2, 3, 3, 3
.fbit:      db 1, 2, 8, 4
.two:       ld a, $50                       ; a row: x 72, 80
            call .spr
            ld a, $58
.spr:       push af
            ld a, b
            ld [de], a
            inc de
            pop af
            ld [de], a
            inc de
            ld a, [hl+]
            add a, c
            ld [de], a
            inc de
            ld a, [hl+]
            push bc
            ld b, a
            and $40
            rrca
            ld c, a
            ld a, b
            and 3
            or c
            pop bc
            ld [de], a
            inc de
            ret
.obj:       ld a, [hl+]                     ; visible and near: its 2 x 2 (the first frame)
            and a
            ret z
            ld a, [hl+]                     ; screen x = 72 + 16 (x - px)
            push hl
            ld hl, px
            sub [hl]
            pop hl
            add a, 4
            cp 9
            ret nc
            sub 4
            swap a
            add a, $48
            ld [vh_x], a
            ld a, [hl]
            push hl
            ld hl, py
            sub [hl]
            pop hl
            add a, 4
            cp 9
            ret nc
            sub 4
            swap a
            add a, $50
            ld [vh_y], a
            push de
            ld a, [map_bank]
            call sbank
            ld hl, M_VEHTBL
            pop de
.od:        ld a, [vh_y]
            ld b, a
            call .ot
            ld a, [vh_y]
            add a, 8
            ld b, a
.ot:        ld a, [vh_x]
            add a, 8
            call .spr
            ld a, [vh_x]
            add a, 16
            jr .spr

; ---- drawing metatiles into the 32 x 32 BG ring (queued; written in V-Blank)
; queue entry (8 bytes): VRAM address (lo, hi), tiles UL UR DL DR, CGB palette
draw_all:   ld a, 1                         ; (LCD off: the flush without the LY limit)
            ldh [q_nolim], a
            call .all
            xor a
            ldh [q_nolim], a
            ret
.all:       ld a, [py]                      ; the 16 x 16 metatiles around the party, LCD off
            sub 7
            ld d, a
            ld b, 16
.r:         ld a, [px]
            sub 7
            ld e, a
            ld c, 16
.c:         push bc
            push de
            ld a, [lmask]                   ; (a masked load: the guard paused while the
            ld [gd_off], a                  ;   metatile is looked up, RAM only)
            call q_mt
            call gd_resume
            ld c, 255
            call q_flush
            pop de
            pop bc
            inc e
            dec c
            jr nz, .c
            inc d
            dec b
            jr nz, .r
            ret

draw_edge:  ld a, [mdx]                     ; the line of metatiles entering the view
            and a
            jr z, .vert
            ld b, 6                         ; right: column x + 6, left: x - 6
            bit 7, a
            jr z, .h1
            ld b, $FA
.h1:        ld a, [px]
            add a, b
            ld e, a
            ld a, [py]
            sub 5
            ld d, a
            ld b, 11
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
            ld b, 5
            bit 7, a
            jr z, .v1
            ld b, $FB
.v1:        ld a, [py]
            add a, b
            ld d, a
            ld a, [px]
            sub 6
            ld e, a
            ld b, 13
.vl:        push bc
            push de
            call q_mt
            pop de
            pop bc
            inc e
            dec b
            jr nz, .vl
            ret

; queue metatile (E = x, D = y), map coordinates taken mod 64; mt_force != $FF draws that
; metatile instead of the map's (the doors)
q_mt:       ldh a, [cmask]
            ld b, a
            ld a, e
            and b
            ld e, a
            ld a, d
            and b
            ld d, a
            ld a, [q_rd]                    ; full (255 queued): dropped (never seen)
            ld b, a
            ld a, [q_n]
            inc a
            cp b
            ret z
            push de
            call map_at                     ; A = metatile
            pop de
            ld c, a
            ld a, [mt_force]
            cp $FF
            jr z, .m
            ld c, a
.m:         ld a, [q_n]                     ; HL = qbuf + 8 n (a ring of 256 entries: q_n
            ld l, a                         ;   written here only, q_rd by the flush only)
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            ld a, h
            add a, high(qbuf)
            ld h, a
            ld a, d                         ; address $9800 + 32 (2y & 31) + (2x & 31)
            add a, a
            and 31
            ld b, a                         ; B = row
            ld a, e
            add a, a
            and 31
            push hl
            ld l, b
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add a, l
            ld e, a
            ld a, h
            adc a, $98
            ld d, a
            pop hl
            ld [hl], e
            inc l
            ld [hl], d
            inc l
            ldh a, [is_cgb]                 ; the tile tables: CGB (tileset bank) or DMG
            and a                           ;   pre-shaded for the room state (map bank)
            jr z, .dmg
            ld a, [ts_bank]
            call sbank
            ld b, high(T_MTCGB)
            jr .t
.dmg:       ld a, [map_bank]
            call sbank
            ld b, high(M_MTOUT)
            ld a, [inroom]
            and a
            jr z, .t
            ld b, high(M_MTIN)
.t:         ld e, c                         ; four tables of 128, one per corner (256-aligned)
            ld d, b
            ld a, [de]
            ld [hl+], a
            ld a, e
            add a, 128
            ld e, a
            ld a, [de]
            ld [hl+], a
            inc d
            ld e, c
            ld a, [de]
            ld [hl+], a
            ld a, e
            add a, 128
            ld e, a
            ld a, [de]
            ld [hl+], a
            ld a, [ts_bank]                 ; palette
            call sbank
            ld e, c
            ld d, high(T_MTPAL)
            ld a, [de]
            ld [hl], a
            ld hl, q_n                      ; (one INC: the entry is complete before it)
            inc [hl]
            ret

; write up to C queued metatiles to VRAM (V-Blank or LCD off)
q_flush:    ld a, [q_n]
            ld b, a
            ld a, [q_rd]
            cp b
            ret z
            ld l, a                         ; HL = qbuf + 8 rd
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            ld a, h
            add a, high(qbuf)
            ld h, a
.e:         ldh a, [q_nolim]                ; (LCD off: no limit) in V-Blank: only while
            and a                           ;   LY is 144-151, so no write lands in drawing
            jr nz, .go
            ldh a, [rLY]
            sub 144
            cp 8
            ret nc
.go:        ld a, [hl+]
            ld e, a
            ld a, [hl+]
            ld d, a                         ; DE = the UL cell
            push de
            ld a, [hl+]
            ld [de], a                      ; UL
            inc e
            ld a, [hl+]
            ld [de], a                      ; UR
            ld a, e
            add a, 31
            ld e, a
            jr nc, .c1
            inc d
.c1:        ld a, [hl+]
            ld [de], a                      ; DL
            inc e
            ld a, [hl+]
            ld [de], a                      ; DR
            ld b, [hl]                      ; CGB: the palette into VRAM bank 1
            inc hl
            inc hl
            pop de
            ldh a, [is_cgb]
            and a
            jr z, .n
            ld a, 1
            ldh [rVBK], a
            ld a, b
            ld [de], a
            inc e
            ld [de], a
            ld a, e
            add a, 31
            ld e, a
            jr nc, .c2
            inc d
.c2:        ld a, b
            ld [de], a
            inc e
            ld [de], a
            xor a
            ldh [rVBK], a
.n:         ld a, [q_rd]
            inc a
            ld [q_rd], a
            jr nz, .w
            ld hl, qbuf                     ; (the ring wraps)
.w:         ld b, a
            ld a, [q_n]
            cp b
            ret z
            dec c
            jr nz, .e
            ret

; ---- banks: every switch through sbank, so the V-Blank handler can restore the bank the
; interrupted code runs in (banked modules call bank-0 code freely)
sbank:      ldh [rombank], a
            ld [MBC_BANK], a
            ret
; run routine HL in code bank A, then back to the caller's bank
bank_call:  push af
            ldh a, [rombank]
            ld b, a
            pop af
            push bc
            call sbank
            call .jp
            pop bc
            push af
            ld a, b
            call sbank
            pop af
            ret
.jp:        jp hl
; bank_call with arguments: story_show (A = first page, B = pages) in bank SCR_BANK
bank_call_ab:
            ld a, 1                         ; (the bridge: FF1's page timing)
            ld [st_mode], a
            ld a, STORY_FIRST
            ld [st_pg], a
            ldh a, [rombank]
            push af
            ld a, SCR_BANK
            call sbank
            ld a, TR_BRIDGE                 ; FF1's bridge music
            call snd_track
            ld a, STORY_FIRST
            ld b, 4 + STORY_CRED                ; (the bridge: its story, FF1's credits)
            call story_show
            ld b, $20                       ; FF1: $20 frames of stall before the exit
.st:        push bc
            call scr_frame
            pop bc
            dec b
            jr nz, .st
            pop af
            jp sbank
; copy BC bytes from bank A, HL to DE (RAM / VRAM); the caller's bank mapped again
far_copy:   push af
            ldh a, [rombank]
            ld [fc_save], a
            pop af
            call sbank
            call memcpy
            ld a, [fc_save]
            jp sbank
; A = the byte at bank A' (fc_bank), HL; the caller's bank mapped again
far_byte:   ldh a, [rombank]
            ld [fc_save], a
            ld a, [fc_bank]
            call sbank
            ld a, [hl]
            push af
            ld a, [fc_save]
            call sbank
            pop af
            ret

; ---- helpers
memclr:     xor a                           ; HL = start, DE = length
            ld [hl+], a
            dec de
            ld a, d
            or e
            jr nz, memclr
            ret
dma_rom:    ld a, high(oam_buf)
            ldh [rDMA], a
            ld a, 40
.w:         dec a
            jr nz, .w
            ret
dma_end:

; standard map special tiles (FF1 SMMove_Crown / Cube / 4Orbs / xOrb): D = the target's first
; property byte; C set if blocked (keeps BC, DE)
sm_special: ld a, d
            and $1E
            ld hl, ITEMS + $02              ; crown
            cp $0E
            jr z, .item
            ld hl, ITEMS + $0E              ; cube
            cp $10
            jr z, .item
            cp $12
            jr z, .orbs
            ld hl, ITEMS + $15              ; altars: earth $18, fire $1A, water $1C, air $1E
            cp $18
            jr z, .alt
            ld hl, ITEMS + $12
            cp $1A
            jr z, .alt
            inc hl
            cp $1C
            jr z, .alt
            inc hl
            cp $1E
            jr z, .alt
            and a
            ret
.item:      ld a, [hl]
            and a
            jr z, .no
.fan:       ld a, TR_DLGFAN                 ; (FF1: the fanfare)
            call snd_track
            and a
            ret
.orbs:      ld a, [ITEMS + $12]
            ld hl, ITEMS + $13
            and [hl]
            inc hl
            and [hl]
            inc hl
            and [hl]
            jr nz, .fan
.no:        scf
            ret
.alt:       ld a, [hl]                      ; an altar: its orb lit (FF1 altar effect)
            and a
            ret nz
            ld [hl], 1
            and a
            ret

; ---- vehicles (FF1 ProcessOWInput @Movement, OWCanMove, Board / Unboard / DockShip): D, E =
; the target's property bytes, tx / ty the target; C set if the move is blocked
SV_SHIP    = $D000          ; save page: ship (visible, x, y), airship, bridge, canal, canoe
SV_AIR     = $D004
SV_BRIDGE  = $D008
SV_CANAL   = $D00C
SV_CANOE   = $D012
SV_VEH     = $D014
ow_canmove: xor a
            ld [no_enc], a
            ld a, [vehicle]
            cp V_AIR
            jr z, .go                       ; the airship: anywhere
            cp V_SHIP
            jr z, .ship
            cp V_CANOE
            jr z, .canoe
            ld a, d                         ; on foot
            and V_FOOT
            jr nz, .fb
            ld a, d                         ; special tiles: the chime, the caravan
            and $C0
            jr z, .go
            cp $40
            jr nz, .car
            ld a, [ITEMS + $0C]
            and a
            jr z, .no
            jr .go
.car:       cp $80
            jr nz, .go
            ld a, [game_flags + $13]        ; (FF1: shop 70 unless the fairy is out)
            and 1
            jr nz, .go
            ld a, 70
            ld [shop_pend], a
            jr .go
.fb:        ld a, 1                         ; blocked on foot: the bridge, a canoe, the ship
            ld [no_enc], a
            ld hl, SV_BRIDGE
            call .at
            jr nc, .brg
            call .tcanoe
            jr nc, .go
            call .tship
            jr nc, .go
.no:        scf
            ret
.brg:       ld a, [unsram + $16]            ; (FF1 bridgescene: the bridge story once)
            and a
            jr nz, .go
            inc a
            ld [unsram + $16], a
.go:        and a
            ret
.ship:      ld a, d
            and V_SHIP
            jr nz, .sb
            ld hl, SV_CANAL                 ; water: not through the canal object
            call .at
            jr nc, .no
            jr .go
.sb:        call .tcanoe                    ; land: a canoe, else dock where allowed
            jr nc, .go
            ld a, d
            and $21
            cp $20
            jr nz, .no
            call .dock
            ld a, V_FOOT
            ld [vehicle], a
            jr .go
.canoe:     ld a, d
            and V_CANOE
            jr z, .go
            bit 0, d                        ; onto land (walkable): on foot
            jr nz, .cs
            ld a, V_FOOT
            ld [vehicle], a
            ld a, 1
            ld [no_enc], a
            jr .go
.cs:        call .tship
            jr nc, .go
            jr .no
.tcanoe:    bit 1, d                        ; FF1 BoardCanoe
            jr nz, .f
            ld a, [SV_CANOE]
            and a
            jr z, .f
            ld a, [vehicle]
            cp V_SHIP
            call z, .dock
            ld a, V_CANOE
            ld [vehicle], a
            ld a, 1
            ld [no_enc], a
            and a
            ret
.tship:     ld hl, SV_SHIP                  ; FF1 BoardShip: the ship at the target
            call .at
            ret c
            ld a, V_SHIP
            ld [vehicle], a
            ld a, 1
            ld [no_enc], a
            and a
            ret
.dock:      ld a, [px]                      ; FF1 DockShip: the ship stays here
            ld [SV_SHIP + 1], a
            ld a, [py]
            ld [SV_SHIP + 2], a
            ret
.at:        ld a, [hl+]                     ; object (visible, x, y) at the target: C clear
            and a
            jr z, .f
            ld a, [tx]
            cp [hl]
            jr nz, .f
            inc hl
            ld a, [ty]
            cp [hl]
            jr nz, .f
            and a
            ret
.f:         scf
            ret

; A on the overworld (FF1): the airship lands (not on tiles with byte 0 bit 3), or the party
; boards it on its tile
ow_abutton: ld a, [vehicle]
            cp V_AIR
            jr z, .land
            cp V_FOOT
            ret nz
            ld a, [SV_AIR]
            and a
            ret z
            ld a, [px]
            ld hl, SV_AIR + 1
            cp [hl]
            ret nz
            ld a, [py]
            inc hl
            cp [hl]
            ret nz
            ld a, V_AIR                     ; FF1 FlyAirship: the airship's music, the takeoff
            ld [vehicle], a
            call map_music
            jp air_up
.land:      call air_down                   ; FF1 LandAirship: down first, then the tile: not
            ld a, [px]                      ;   allowed (tile byte 0 bit 3): up again
            ld e, a
            ld a, [py]
            ld d, a
            call map_at
            call props
            bit 3, d
            jp nz, air_up
            ld a, [px]
            ld [SV_AIR + 1], a
            ld a, [py]
            ld [SV_AIR + 2], a
            ld a, V_FOOT
            ld [vehicle], a
            jp map_music

; FF1 AnimateAirshipTakeoff / AnimateAirshipLanding: the airship rises from y $6F to $4F
; (lands: back), a pixel every second frame, its shadow, the noise (FF1: volume 8, the
; frame counter as its period); then facing right
air_up:     ld a, $6F - $1C
            ld [air_y], a
.l:         call air_frame
            ldh a, [frame]
            rrca
            jr c, .l
            ld hl, air_y
            dec [hl]
            ld a, [hl]
            cp $4F - $1C
            jr nc, .l
            jr air_done
air_down:   ld a, $4F - $1C
            ld [air_y], a
.l:         call air_frame
            ldh a, [frame]
            rrca
            jr c, .l
            ld hl, air_y
            inc [hl]
            ld a, [hl]
            cp $70 - $1C
            jr c, .l
air_done:   xor a
            ld [air_y], a
            ld [facing], a
            ld [sfx_nmode], a
            ret
air_frame:  ld a, 3
            ld [sfx_nmode], a
            call veh_oam
            jp wait_vbl

; FF1 MapPoisonDamage: on foot, each poisoned member loses 1 HP a step (not below 1)
section bank 0, $3200                       ; (main.s continued)
MINI_BANK  = 97             ; (also: the 12 classes' map sprites at $6400, colours at $7000)
M_PERM     = $7380          ; map bank: DMG rank permutations per class and sprite palette

; the party's map sprite: the leader's class (FF1 LoadPlayerMapmanCHR, MAPMAN_PAL); LCD off.
; CGB: the raw tiles, the class's colours as colour 2 of OBJ palettes 0 / 1; DMG: the tiles
; ranked by brightness for this map (the build's permutations)
party_spr:  ld a, [ch_stats]
            ld [ps_cls], a
            ldh a, [is_cgb]
            and a
            jr z, .dmg
            ld a, [ps_cls]
            add a, $64
            ld h, a
            ld l, 0
            ld de, $8000
            ld bc, 256
            ld a, MINI_BANK
            call far_copy
            ld a, [ps_cls]
            add a, a
            add a, a
            ld l, a
            ld h, $70
            ld de, scr_buf
            ld bc, 4
            ld a, MINI_BANK
            call far_copy
            ld a, $84
            ldh [rOCPS], a
            ld a, [scr_buf]
            ldh [rOCPD], a
            ld a, [scr_buf + 1]
            ldh [rOCPD], a
            ld a, $8C
            ldh [rOCPS], a
            ld a, [scr_buf + 2]
            ldh [rOCPD], a
            ld a, [scr_buf + 3]
            ldh [rOCPD], a
            ret
.dmg:       ld a, [ps_cls]
            add a, a
            add a, low(M_PERM)
            ld l, a
            ld h, high(M_PERM)
            ld de, ps_perm
            ld bc, 2
            ld a, [map_bank]
            call far_copy
            xor a
.t:         ld [ps_t], a
            ld a, [ps_cls]                  ; the tile's raw data
            add a, $64
            ld h, a
            ld a, [ps_t]
            swap a
            ld l, a
            ld de, scr_buf
            ld bc, 16
            ld a, MINI_BANK
            call far_copy
            ld a, [ps_t]                    ; palette 0 / 1 by the tile (bit 1)
            rrca
            and 1
            ld e, a
            ld d, 0
            ld hl, ps_perm
            add hl, de
            ld a, [hl]
            ld [ps_p], a
            ld a, [ps_t]                    ; -> $8000 + 16 t
            swap a
            ld e, a
            ld d, $80
            ld hl, scr_buf
            ld b, 8
.r:         push bc
            ld a, [hl+]
            ld b, a                         ; B = lo, C = hi
            ld a, [hl+]
            ld c, a
            push hl
            push de
            ld a, c                         ; masks of values 1, 2, 3
            cpl
            and b
            ld d, a
            ld a, b
            cpl
            and c
            ld e, a
            ld a, b
            and c
            ld h, a
            ld a, [ps_p]
            ld l, a
            xor a                           ; new lo
            bit 0, l
            jr z, .a1
            or d
.a1:        bit 2, l
            jr z, .a2
            or e
.a2:        bit 4, l
            jr z, .a3
            or h
.a3:        ld b, a
            xor a                           ; new hi
            bit 1, l
            jr z, .b1
            or d
.b1:        bit 3, l
            jr z, .b2
            or e
.b2:        bit 5, l
            jr z, .b3
            or h
.b3:        ld c, a
            pop de
            ld a, b
            ld [de], a
            inc de
            ld a, c
            ld [de], a
            inc de
            pop hl
            pop bc
            dec b
            jr nz, .r
            ld a, [ps_t]
            inc a
            cp 16
            jr c, .t
            ret

; the LCD off (Lot Check: only in V-Blank; interrupts off meanwhile, so no handler can run the
; write past the V-Blank); nothing if it is off already
; FF1 sound: the error buzz (menus: not allowed)
sfx_err:    ld a, SFX_ERROR
            ld [sfx_req], a
            ret

ow_poison:  xor a
.m:         push af
            call ch_rec
            inc hl
            ld a, [hl]
            cp 3
            jr nz, .n
            ld a, l
            add a, CH_HP - 1
            ld l, a
            ld a, [hl+]
            ld c, a
            ld a, [hl-]
            and a
            jr nz, .d
            ld a, c
            cp 2
            jr c, .n
.d:         ld a, [hl]
            sub 1
            ld [hl+], a
            ld a, [hl]
            sbc a, 0
            ld [hl], a
.n:         pop af
            inc a
            cp 4
            jr c, .m
            ret

; ---- sound: the music engine's song data reader (bank 0: maps the data bank, then back to
; the sound bank; safe in the V-Blank handler: no shared variables)
mrd:        push hl
            ld a, h
            sub $40
            ld h, a
            ld a, MUS_DATA
            ld [MBC_BANK], a
            ld a, [hl]
            push af
            ld a, SND_BANK
            ld [MBC_BANK], a
            pop af
            pop hl
            ret
; A = a music track (FF1's numbers)
snd_track:  ld [NES_RAM + $4B], a
            ret
; the map's music: the overworld by vehicle, a standard map by its tileset (FF1)
map_music:  ldh a, [maptype]
            and a
            jr z, .sm
            ld a, [vehicle]
            ld l, a
            ld h, high(S_VEHMUS)
            ld a, l
            add a, low(S_VEHMUS)
            ld l, a
            jr .rd
.sm:        ld a, [ts_bank]
            sub TS_BANK0
            add a, low(S_TSMUS)
            ld l, a
            ld h, high(S_TSMUS)
.rd:        ld a, SND_BANK
            ld [fc_bank], a
            call far_byte
            ld b, a
            ld a, [NES_RAM + $4B]           ; (already playing it: kept)
            cp b
            ret z
            ld a, b
            jr snd_track

; ---- encounters and battles
B_RATES    = $4A00          ; battle data bank: encounter rate per map (+1), domains, lut_RNG,
B_DOMAINS  = $4800          ;   the formation weights
B_FRNG     = $7D00
B_WEIGHT   = $7F00
; FF1 BattleStepRNG -> A
enc_step:   ld a, [bsign]
            bit 7, a
            ld hl, bstep
            jr nz, .neg
            inc [hl]
            jr nz, .d
            jr .exp
.neg:       dec [hl]
            jr nz, .d
.exp:       ld a, [bsign]
            add a, $A0
            ld [bsign], a
.d:         ld a, [bstep]
            ld l, a
            ld h, high(B_FRNG)
            ld a, BTL_DATA
            ld [fc_bank], a
            jp far_byte
; FF1 GetBattleFormation: domain A -> A = a formation (weighted)
enc_form:   ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, B_DOMAINS
            add hl, de
            push hl
            ld hl, bcount
            inc [hl]
            ld l, [hl]
            ld h, high(B_FRNG)
            ld a, BTL_DATA
            ld [fc_bank], a
            call far_byte
            and $3F
            ld l, a
            ld h, high(B_WEIGHT)
            call far_byte
            pop hl
            add a, l
            ld l, a
            ld a, h
            adc a, 0
            ld h, a
            jp far_byte
; a battle with formation A, then the map again (C set: the step handled); lost: game over
do_battle:  ld [btl_fid], a
            ld a, SCR_BANK                  ; FF1 BattleTransition (the field's flashing, noise)
            ld hl, bt_trans
            call bank_call
            ld a, BTL_BANK
            ld hl, battle
            call bank_call
            and a
            jr z, .ok
            cp 2
            jr nz, game_over
            ld a, SCR_BANK                  ; the ending (FF1 EnterEndingScene): the epilogue
            call sbank                      ;   music, the story's last pages (input ignored),
            ld a, TR_EPILOGUE               ;   then "The End" drawn; it stays (soft reset)
            call snd_track
            ld a, 2
            ld [st_mode], a
            ld a, STORY_FIRST + 4 + STORY_CRED
            ld b, STORY_END - STORY_FIRST - 4 - STORY_CRED
            call story_show
            jp the_end
.ok:        ld a, 1                         ; (FF1: back on the map, the palettes cycle in)
            ld [pc_req], a
            call map_reload
            scf
            ret
; the save in cart RAM valid (its mark and sum)? C clear if so; load_game copies it in
; the save's state (Lot Check): A = 0 none (no mark), 1 good, 2 damaged (mark, wrong sum)
save_state: call save_valid
            ld a, 1
            ret nc
            ld a, $0A
            ld [$0000], a
            xor a
            ld [$4000], a
            ld hl, SAVE_MARK
            ld a, [hl+]
            cp $46
            jr nz, .none
            ld a, [hl+]
            cp $46
            jr nz, .none
            ld a, [hl+]
            cp $31
            jr nz, .none
            ld a, [hl]
            cp $4E
            jr nz, .none
            xor a
            ld [$0000], a
            ld a, 2
            ret
.none:      xor a
            ld [$0000], a
            ret
; the damaged save erased (its mark cleared), after the player's A Button
save_erase: ld a, $0A
            ld [$0000], a
            xor a
            ld [$4000], a
            ld hl, SAVE_MARK
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl], a
            ld [$0000], a
            ret
save_valid: ld a, $0A
            ld [$0000], a
            xor a
            ld [$4000], a
            ld hl, SAVE_MARK
            ld a, [hl+]
            cp $46
            jr nz, .no
            ld a, [hl+]
            cp $46
            jr nz, .no
            ld a, [hl+]
            cp $31
            jr nz, .no
            ld a, [hl+]
            cp $4E
            jr nz, .no
            ld bc, 0
            ld de, $400
.s:         ld a, [hl+]
            add a, c
            ld c, a
            ld a, b
            adc a, 0
            ld b, a
            dec de
            ld a, d
            or e
            jr nz, .s
            ld a, [hl+]
            cp c
            jr nz, .no
            ld a, [hl]
            cp b
            jr nz, .no
            xor a
            ld [$0000], a
            ret
.no:        xor a
            ld [$0000], a
            scf
            ret
load_game:  ld a, $0A
            ld [$0000], a
            xor a
            ld [$4000], a
            ld hl, SAVE_MARK + 4
            ld de, unsram
            ld bc, $400
            call memcpy
            xor a
            ld [$0000], a
            ret

; FF1 GameOver: back to the title
game_over:  di
            ld sp, $E000
            ld e, $A5
            ldh a, [is_cgb]                 ; (start reads the console from A)
            and a
            ld a, 0
            jp z, start
            ld a, $11
            jp start

; ---- the save (Lot Check: a sum and a mark; cart RAM enabled only while it is written)
SAVE_MARK  = $A000          ; "FF1N", then the save page ($400), then the sum (2)
save_game:  ldh a, [maptype]                ; the overworld position (FF1: its scroll, - 7)
            and a
            ld a, [px]
            ld b, a
            ld a, [py]
            ld c, a
            jr nz, .ow
            ld a, [ow_x]
            ld b, a
            ld a, [ow_y]
            ld c, a
.ow:        ld a, [vehicle]
            ld [SV_VEH], a
            ld a, b
            sub 7
            ld [unsram + $10], a
            ld a, c
            sub 7
            ld [unsram + $11], a
            ld a, $0A
            ld [$0000], a
            xor a
            ld [$4000], a                   ; cart RAM bank 0
            ld hl, SAVE_MARK
            ld a, $46
            ld [hl+], a
            ld a, $46
            ld [hl+], a
            ld a, $31
            ld [hl+], a
            ld a, $4E
            ld [hl+], a
            ld de, unsram
            ld bc, 0                        ; the sum
.c:         ld a, [de]
            inc de
            ld [hl+], a
            add a, c
            ld c, a
            ld a, b
            adc a, 0
            ld b, a
            ld a, d
            cp high(unsram) + 4
            jr c, .c
            ld a, c
            ld [hl+], a
            ld [hl], b
            xor a
            ld [$0000], a
            ret

section wram, $C000
oam_buf:    ds 160
            ds 96
qbuf:       ds 8 * 256                      ; metatile queue, a ring ($C100-$C8FF)
px:         ds 1
py:         ds 1
tx:         ds 1
ty:         ds 1
facing:     ds 1
moving:     ds 1
mcount:     ds 1
mdx:        ds 1
mdy:        ds 1
q_n:        ds 1
q_rd:       ds 1
cur_map:    ds 1
map_bank:   ds 1
ps_cls:     ds 1                            ; (party_spr)
ps_t:       ds 1
ps_p:       ds 1
ps_perm:    ds 2
lcdc_on:    ds 1
air_y:      ds 1                            ; the airship's y while taking off / landing
respond:    ds 1                            ; FF1 respondrate (0-7)
pc_req:     ds 1                            ; a palette cycle in when the map is back
wp_req:     ds 1                            ; (the screen wipe: requested, on, band, state)
wp_on:      ds 1
wp_top:     ds 1
wp_bot:     ds 1
wp_st:      ds 1
wp_t:       ds 1
ly_n:       ds 1                            ; (the LCDC list: entries, the next, its base)
ly_i:       ds 1
ly_base:    ds 1
pc_hold:    ds 1                            ; (the cycle's colours: no map palette writes)
pz_bcnt:    ds 1                            ; B presses on the overworld (FF1 joy_b: the puzzle)
ts_bank:    ds 1
inroom:     ds 1
door_x:     ds 1
door_y:     ds 1
mt_force:   ds 1
ow_x:       ds 1                            ; the overworld position while on a standard map
ow_y:       ds 1
fdepth:     ds 1                            ; floors pushed by normal teleports
fstack:     ds 4 * 8                        ; x, y, room state, map
warp_room:  ds 1
fc_save:    ds 1
fc_bank:    ds 1
obj_cur:    ds 1
npc_seed:   ds 1
o_tx:       ds 1
o_ty:       ds 1
o_sx:       ds 1
o_sy:       ds 1
o_tb:       ds 1

section wram, $CF90
vehicle:    ds 1
no_enc:     ds 1
shop_pend:  ds 1
vh_y:       ds 1
vh_x:       ds 1
bstep:      ds 1
bsign:      ds 1
bcount:     ds 1

section wram, $CA00
objs:       ds 16 * 15                      ; map objects (objects.s)

section wram, $D000
unsram:     ds 256                          ; FF1's save page ($6000-$63FF): page 0
ch_stats:   ds 256
game_flags: ds 256
ch_magic:   ds 256

section hram, $FF80
hram_dma:   ds 10
is_cgb:     ds 1
vbl_done:   ds 1
pad:        ds 1
pad_new:    ds 1
scx:        ds 1
scy:        ds 1
pal_req:    ds 1
q_nolim:    ds 1
rombank:    ds 1                            ; the ROM bank mapped at $4000 (sbank)
maptype:    ds 1                            ; 0 standard map, 1 overworld
frame:      ds 1                            ; frame counter
cmask:      ds 1                            ; coordinate mask: 63 / 255
soft_rst:   ds 1
nzv:        ds 1                            ; (the music engine's flag bytes)
vfl:        ds 1

section bank 0, $3900                       ; (the screen wipe, the palette cycle's helpers)
; ---- FF1 ScreenWipe_Close / _Open: the window layer (a black map) covers the screen above
; and below a band that closes on the middle (2 lines a frame each side) or opens from it;
; the STAT handler switches the window off at the band's top and on at its bottom. Sprites
; hidden, the music stopped; FF1's sound on square 1 (12.5 %, volume 8, sweeping down, its
; pitch from the visible lines every fourth frame).
wipe_close: push de
            ld a, $80
            call snd_track
            call oam_clr
            call wp_map                     ; (the window map black, LCD on: in V-Blanks)
            xor a
            ld [wp_top], a
            ld a, 144
            ld [wp_bot], a
            ld a, 1
            ld [wp_on], a
.l:         call wait_vbl
            call wp_snd
            ld hl, wp_top
            ld a, [hl]
            add a, 2
            ld [hl], a
            ld b, a
            ld hl, wp_bot
            ld a, [hl]
            sub 2
            ld [hl], a
            cp b
            jr z, .x
            jr nc, .l
.x:         call wait_vbl
            pop de
            ret
wipe_open:  xor a
            ld [wp_req], a
            call oam_clr                    ; (FF1: no sprites while it opens)
            call dma_safe
            call wp_map
            ld a, 72
            ld [wp_top], a
            ld [wp_bot], a
            ld a, 1
            ld [wp_on], a
            ld a, 7
            ldh [rWX], a
            xor a
            ldh [rWY], a
            ld a, LCDC_WIN                  ; (the first frame covered)
            call lcd_on
.l:         call wait_vbl
            call wp_snd
            ld hl, wp_top
            ld a, [hl]
            sub 2
            jr nc, .t
            xor a
.t:         ld [hl], a
            ld hl, wp_bot
            ld a, [hl]
            add a, 2
            cp 145
            jr c, .b
            ld a, 144
.b:         ld [hl], a
            cp 144
            jr c, .l
            ld a, [wp_top]
            and a
            jr nz, .l
            call wait_vbl
            xor a
            ld [wp_on], a
            ldh [$FF12], a                  ; (square 1 silent; the music goes on)
            ld a, BOX_LINES
            ldh [rLYC], a
            ld a, [lcdc_on]
            ldh [rLCDC], a
            ld a, 7
            ldh [rWX], a
            ret
; the window map black: the font's blank (DMG: its tile for this map, shade 3; CGB: in VRAM
; bank 1, palette 6 all black); with the LCD on, three rows a V-Blank
wp_map:     ld a, $20
            call code_tile
            ld [wp_t], a
            call lcd_get  
            bit 7, a
            jr z, .off
            ld c, 0
.r:         call wait_vbl
            call .rows
            ld a, c
            cp 18
            jr c, .r
            jr .pal
.off:       ld c, 0
.o:         call .rows
            ld a, c
            cp 18
            jr c, .o
.pal:       ldh a, [is_cgb]
            and a
            ret z
            call lcd_get                    ; (palette 6 black: in V-Blank or LCD off)
            bit 7, a
            call nz, wait_vbl
            ld a, $80 | 48
            call bcps_w
            ld b, 8
            xor a
.p:         call bcpd_w
            dec b
            jr nz, .p
            ret
.rows:      ld b, 3                         ; rows C .. C + 2 of $9C00
.rw:        push bc
            ld l, c
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, $9C00
            add hl, de
            ld b, 20
            ld a, [wp_t]
.c:         ld [hl+], a
            dec b
            jr nz, .c
            ldh a, [is_cgb]
            and a
            jr z, .na
            ld a, l
            sub 20
            ld l, a
            ld a, h
            sbc a, 0
            ld h, a
            ld a, 1
            ldh [rVBK], a
            ld b, 20
            ld a, $0E                       ; (palette 6, VRAM bank 1)
.a:         ld [hl+], a
            dec b
            jr nz, .a
            xor a
            ldh [rVBK], a
.na:        pop bc
            inc c
            dec b
            jr nz, .rw
            ret
; FF1's wipe sound, every fourth frame: period (255 - 3 / 2 visible lines) x 8
wp_snd:     ldh a, [frame]
            and 3
            ret nz
            ld a, [wp_top]
            ld b, a
            ld a, [wp_bot]
            sub b
            jr nc, .v
            xor a
.v:         ld b, a                         ; visible lines (GB) x 3 / 2: FF1's 224-line scale
            srl a
            add a, b
            jr nc, .s
            ld a, 255
.s:         cpl                             ; 255 - that
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl                      ; x 8: the NES period
            add hl, hl                      ; (x 2: the table's entries)
            ld de, S_FREQ
            add hl, de
            ld a, SND_BANK
            ld [fc_bank], a
            call far_byte
            ld e, a
            inc hl
            call far_byte
            ld d, a
            ld a, %00011010                 ; sweep: time 1, down in pitch, shift 2
            ldh [$FF10], a
            xor a                           ; 12.5 %
            ldh [$FF11], a
            ld a, $80                       ; volume 8
            ldh [$FF12], a
            ld a, e
            ldh [$FF13], a
            ld a, d
            or $80
            ldh [$FF14], a
            ret
; HL = a screen of SCR_BANK: FF1's palette cycle out, then the screen
pc_menu:    push hl
            ld a, SCR_BANK
            ld hl, pc_out
            call bank_call
            pop hl
            ld a, SCR_BANK
            jp bank_call
; V-Blank during a wipe: the window on from line 0 (unless the band starts there), the STAT
; interrupt at the band's top
wp_vbl:     xor a                           ; (the window enabled all frame, shown or hidden
            ldh [rWY], a                    ;   by WX: 7 / 167)
            call lcd_get  
            bit 7, a
            ret z
            ld a, LCDC_WIN
            ldh [rLCDC], a
            ld a, [wp_top]
            and a
            jr z, .z
            dec a
            ldh [rLYC], a
            xor a
            ld [wp_st], a
            ld a, 7
            ldh [rWX], a
            ret
.z:         ld a, 1
            ld [wp_st], a
            ld a, [wp_bot]
            ldh [rLYC], a
            ld a, 167
            ldh [rWX], a
            ret
; the screen black before FF1's palette cycle in (LCD off)
pc_black:   ld a, 1
            ld [pc_hold], a
            call oam_clr
            ld a, $FF
            call bgp_w
            ldh a, [is_cgb]
            and a
            ret z
            ld a, $80
            call bcps_w
            ld b, 32
            xor a
.c:         call bcpd_w
            dec b
            jr nz, .c
            ret

; V-Blank with a WX list: the window enabled but out of sight (WX 167: its line counter
; waits), the first entry's line
ly_vbl:     xor a
            ld [ly_i], a
            ldh [rWY], a
            ld a, 167
            ldh [rWX], a
            call lcd_get  
            bit 7, a
            ret z
            ld a, [ly_base]
            ldh [rLCDC], a
            ld a, [ly_tab]
            ldh [rLYC], a
            ret
; the list off: the dialogue's line again
ly_off:     xor a
            ld [ly_n], a
            ld a, BOX_LINES
            ldh [rLYC], a
            ld a, [lcdc_on]
            ldh [rLCDC], a
            ld a, 7
            ldh [rWX], a
            ret

section wram, $CF98
ly_tab:     ds 32                           ; (line, LCDC) x 16 (in one page)


section bank 0, $3C00                       ; (masked loads)

; ---- masked loads (Color). FF1 blanks the screen (black) while it draws a new one; a Game Boy
; Color whose LCD is off shows white, so a load keeps the LCD on behind black palettes, sprites off: the
; palettes are read into shadows and set black in a V-Blank, palette writes during the load go
; to the shadows, and a mode-2 STAT interrupt holds the CPU through each line's mode 3, so the
; load writes VRAM directly as with the LCD off. lcd_on shows the screen: shadows back in a
; V-Blank, the STAT interrupt as before.
lcd_off:    ld a, [q_n]                     ; (the field's metatile queue dropped: a new
            ld [q_rd], a                    ;   screen; the field redraws all of its map)
            ld a, [lmask]
            and a
            ret nz
            ldh a, [rLCDC]
            bit 7, a
            ret z
            ldh a, [is_cgb]                 ; (a DMG / SGB: the LCD off, as before; the
            and a                           ;   white of a switched-off LCD is the Color's
            jr nz, .cgb                     ;   problem: docs/gb-lessons.md)
            di
.wd:        ldh a, [rLY]
            cp 144
            jr c, .wd
            cp 153
            jr nc, .wd
            xor a
            ldh [rLCDC], a
            reti
.cgb:       push bc
            push hl
            di
.w0:        ldh a, [rLY]                    ; (a V-Blank with time left: LY 144-147; the
            cp 144                          ;   palette work takes ~5 lines at double speed,
            jr c, .w0                       ;   and palette RAM ignores writes in mode 3)
            cp 148
            jr nc, .w0
.go:        ldh a, [rBGP]
            ld [sh_bgp], a
            ldh a, [rOBP0]
            ld [sh_obp0], a
            ld a, $FF
            ldh [rBGP], a
            ldh [rOBP0], a
            ldh a, [is_cgb]
            and a
            jr z, .nc
            ld hl, sh_pal                   ; CGB: the BG palettes read back, then black
            ld c, 0
.rd:
            ld a, c
            ldh [rBCPS], a
            ldh a, [rBCPD]
            ld [hl+], a
            inc c
            ld a, c
            ldh [rBCPS], a
            ldh a, [rBCPD]
            ld [hl+], a
            inc c
            ld a, c
            ldh [rBCPS], a
            ldh a, [rBCPD]
            ld [hl+], a
            inc c
            ld a, c
            ldh [rBCPS], a
            ldh a, [rBCPD]
            ld [hl+], a
            inc c
            ld a, c
            ldh [rBCPS], a
            ldh a, [rBCPD]
            ld [hl+], a
            inc c
            ld a, c
            ldh [rBCPS], a
            ldh a, [rBCPD]
            ld [hl+], a
            inc c
            ld a, c
            ldh [rBCPS], a
            ldh a, [rBCPD]
            ld [hl+], a
            inc c
            ld a, c
            ldh [rBCPS], a
            ldh a, [rBCPD]
            ld [hl+], a
            inc c
            bit 6, c
            jr z, .rd
            ld a, $80
            ldh [rBCPS], a
            ld b, 8
            xor a
.bk:
            ldh [rBCPD], a
            ldh [rBCPD], a
            ldh [rBCPD], a
            ldh [rBCPD], a
            ldh [rBCPD], a
            ldh [rBCPD], a
            ldh [rBCPD], a
            ldh [rBCPD], a
            dec b
            jr nz, .bk
.nc:        ldh a, [rSTAT]
            and $78
            ld [sh_stat], a
            ld a, $20                       ; the mode-2 interrupt only
            ldh [rSTAT], a
            ldh a, [rLCDC]
            res 1, a
            ldh [rLCDC], a
            ld a, 1
            ld [lmask], a
            ldh a, [rIF]                    ; (a DMG's STAT write requests an interrupt)
            and $FD
            ldh [rIF], a
            pop hl
            pop bc
            reti

; the screen on (A = LCDC): after a masked load in the next V-Blank, the shadows back
lcd_on:     push af
            ld a, [lmask]
            and a
            jr nz, .m
            pop af
            ldh [rLCDC], a
            ret
.m:         push bc
            push de
            push hl
            di
.w:         ldh a, [rLY]                    ; (the start of a V-Blank: the 64 palette bytes
            cp 144                          ;   take ~3 lines)
            jr c, .w
            cp 147
            jr nc, .w
            ldh a, [is_cgb]
            and a
            jr z, .d
            ld a, $80
            ldh [rBCPS], a
            ld hl, sh_pal
            ld b, 64
.p:         ld a, [hl+]
            ldh [rBCPD], a
            dec b
            jr nz, .p
.d:         ldh a, [scx]                    ; (the new screen's scroll, from its first frame)
            ldh [rSCX], a
            ldh a, [scy]
            ldh [rSCY], a
            ld a, [sh_bgp]
            ldh [rBGP], a
            ld a, [sh_obp0]
            ldh [rOBP0], a
            ld a, [sh_stat]
            ldh [rSTAT], a
            xor a
            ld [lmask], a
            ldh a, [rIF]
            and $FD
            ldh [rIF], a
            pop hl
            pop de
            pop bc
            pop af
            ldh [rLCDC], a
            reti

; the guard resumed after RAM-only work: out of modes 2 / 3 first (the line's interrupt came
; and went while paused)
gd_resume:  ld a, [gd_off]
            and a
            ret z
            xor a
            ld [gd_off], a
.w:         ldh a, [rSTAT]
            and 2
            jr nz, .w
            ret

; OAM DMA from the main code (interrupts off: none may run while the DMA holds the bus)
dma_safe:   di
            call hram_dma
            reti

; A = LCDC, bit 7 clear during a masked load (callers: "the LCD off" = write VRAM directly)
lcd_get:    ld a, [lmask]
            and a
            ldh a, [rLCDC]
            ret z
            res 7, a
            ret

; palette writes: during a masked load into the shadows (A and the flags kept)
bgp_w:      push af
            ld a, [lmask]
            and a
            jr nz, .m
            pop af
            ldh [rBGP], a
            ret
.m:         pop af
            ld [sh_bgp], a
            ret
obp0_w:     push af
            ld a, [lmask]
            and a
            jr nz, .m
            pop af
            ldh [rOBP0], a
            ret
.m:         pop af
            ld [sh_obp0], a
            ret
bcps_w:     push af
            ld a, [lmask]
            and a
            jr nz, .m
            pop af
            ldh [rBCPS], a
            ret
.m:         pop af
            ld [sh_ps], a
            ret
bcpd_w:     push af                         ; (masked: the flags not kept)
            ld a, [lmask]
            and a
            jr nz, .m
            pop af
            ldh [rBCPD], a
            ret
.m:         pop af
            push hl
            push bc
            ld c, a
            ld a, [sh_ps]
            ld b, a
            and $3F
            add a, low(sh_pal)
            ld l, a
            ld h, high(sh_pal)
            ld [hl], c
            bit 7, b
            jr z, .s
            inc b
            res 6, b
            ld a, b
            ld [sh_ps], a
.s:         ld a, c
            pop bc
            pop hl
            ret

memcpy:     srl b                           ; HL -> DE, BC bytes (BC = 0 after; unrolled:
            rr c                            ;   1, 2, 4, then 8 at a time)
            jr nc, .n1
            ld a, [hl+]
            ld [de], a
            inc de
.n1:        srl b
            rr c
            jr nc, .n2
            ld a, [hl+]
            ld [de], a
            inc de
            ld a, [hl+]
            ld [de], a
            inc de
.n2:        srl b
            rr c
            jr nc, .n4
            ld a, [hl+]
            ld [de], a
            inc de
            ld a, [hl+]
            ld [de], a
            inc de
            ld a, [hl+]
            ld [de], a
            inc de
            ld a, [hl+]
            ld [de], a
            inc de
.n4:        ld a, b
            or c
            ret z
.l8:
            ld a, [hl+]
            ld [de], a
            inc de
            ld a, [hl+]
            ld [de], a
            inc de
            ld a, [hl+]
            ld [de], a
            inc de
            ld a, [hl+]
            ld [de], a
            inc de
            ld a, [hl+]
            ld [de], a
            inc de
            ld a, [hl+]
            ld [de], a
            inc de
            ld a, [hl+]
            ld [de], a
            inc de
            ld a, [hl+]
            ld [de], a
            inc de
            dec bc
            ld a, b
            or c
            jr nz, .l8
            ret

; fill: A to HL, B x 32 bytes (unrolled)
fill32:     ld c, 4
.l:         ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            dec c
            jr nz, .l
            dec b
            jr nz, fill32
            ret

section wram, $D980
sh_pal:     ds 64                           ; masked loads: the CGB BG palettes
lmask:      ds 1
sh_bgp:     ds 1
sh_obp0:    ds 1
sh_ps:      ds 1
sh_stat:    ds 1
gd_off:     ds 1                            ; the guard paused (RAM-only work)
