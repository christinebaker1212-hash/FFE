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
M_VEHDMG   = $6A00          ;   FF1's vehicle tables: sprite y, facing offsets, 2 x 2 frames
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
DMG_OBP_BLK = %10010000     ; on black (screens, battle): 1 white, 2 light grey, 3 dark grey
DMG_OBP    = %11100000      ; sprite tiles hold brightness ranks: 1 white, 2 dark grey, 3 black
M_MTOUT    = $5100
M_MTIN     = $5300
M_TILES    = $5800
C_SPR      = $4000
C_MAPMAN   = $4100
C_TELEX    = $4200
C_ROOMS    = $4340          ; teleports into rooms: (teleport, door x, y) .. $FF
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
BLK_ATTR   = $0D            ; CGB cell outside the windows: palette 5 (all black), VRAM bank 1
LCDC_WIN   = LCDC_ON | $60  ; window on, its map at $9C00
BOX_LINES  = 64

section bank 0, $0040
            jp vblank
section bank 0, $0048
            jp stat_int
section bank 0, $0050
            jp timer_int
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
            ldh a, [is_cgb]                 ; VRAM cleared (both banks on a Color; VBK is
            and a                           ;   written on the Color only: Lot Check)
            jr z, .d0
            xor a
            ldh [rVBK], a
.d0:        ld hl, $8000
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
            ld a, F3_BANK                   ; (the Options: from cart RAM, or defaults)
            ld hl, opt_load
            call bank_call
            ld a, BOX_LINES - 1                 ; LYC: the dialogue box's bottom (window off)
            ldh [rLYC], a
            ld a, $40
            ldh [rSTAT], a
            xor a
            ldh [rIF], a                    ; (a STAT write on DMG can request one: dropped)
            ldh a, [is_cgb]                 ; the music's clock: the timer at the NES's frame
            and a                           ;   rate, 60.0988 Hz (owner, 2026-11-24: the music
            jr z, .tk                       ;   as the NES; a frame tick, 59.73 Hz, played every
            ldh a, [$FF4D]                  ;   song 0.6 % slow; KEY1 reads $FF on a plain Game
.tk:        bit 7, a                        ;   Boy: A = 0 there). 4096 Hz: 68.156 counts a tick
            ld a, 188                       ;   (188 or 187 by 40 / 256); double speed (KEY1 bit
            ld b, 40                        ;   7): 8192 Hz, 136.31 (120 or 119 by 79 / 256)
            jr z, .tn
            ld a, 120
            ld b, 79
.tn:        ld [tm_base], a
            ldh [rTMA], a
            ldh [rTIMA], a
            ld a, b
            ld [tm_frac], a
            xor a
            ld [mus_pend], a
            ld [mus_busy], a
            ld a, 4                         ; (timer on: 4096 Hz, 8192 Hz in double speed)
            ldh [rTAC], a
            xor a
            ldh [rIF], a
            ld a, 7                         ; V-Blank, STAT and timer interrupts
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
            ld a, [sus_res]                 ; (a suspend point resumed: the map as after a
            and a                           ;   menu, palettes cycled in)
            jr z, .nsr
            call map_reload
            jp main
.nsr:       call ng_out                     ; (a new game: the party screen fades out with
                                            ;   its music, the world fades in: pal.s)
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
            call ng_in                      ; (a new game: the world fades in, pal.s)
            ld a, START_DLG                 ; (test builds: a dialogue first, build.py --dlg)
            cp $FF
            call nz, dlg_open
            call t_shop                     ; (test builds: a shop first, build.py --shop)
            ld a, START_BATTLE              ; (test builds: a battle first)
            cp $FF
            jr z, .nb
            call do_battle                  ;   (as from the field: lost / the ending too)
.nb:

; ---- main loop: one engine frame per GB frame
main:       call wait_vbl
            call wa_tick                    ; (the sea and rivers move: wanim.s; in V-Blank)
            call wf_tick                    ; (the waterfall: wanim.s)
            call sgb_amb                    ; (SGB: waves / wind by vehicle: sgbx.s)
            call read_pad
            call bn_main                    ; (the place banner, the play time: text.s)
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
.drw:       ld a, F3_BANK                   ; (the line ahead: 3 metatiles a frame)
            ld hl, q_feed
            call bank_call
            call set_scroll
            call make_oam
            call bd_oam                     ; (boarding: the party into the vehicle)
            call refl_tick                  ; (the reflection on water: refl.s)
            jp ap_tl                        ; (the airship's view: air.s; the DMG's water)


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
            ldh a, [is_cgb]                 ; (the Color: the VRAM bank kept for the code it
            and a                           ;   interrupted; box_vbl / q_flush leave it at 0,
            jr z, .v0                       ;   and an attribute row being written went into
            ldh a, [rVBK]                   ;   the tile map: the garbled battles)
.v0:        push af
            ldh a, [is_cgb]                 ; (and bank 0 for its own map writes: with the
            and a                           ;   interrupted code's bank 1 they went into the
            jr z, .v2                       ;   attributes: mirrored letters)
            xor a
            ldh [rVBK], a
.v2:
            ld hl, frame
            inc [hl]
            call rf_dma                     ; (OAM; then the reflection's masked tiles: refl.s)
            ldh a, [scx]
            ldh [rSCX], a
            ldh a, [scy]
            ldh [rSCY], a
            call qf_wt                      ; (the map's rows first, 3 metatiles: a running
                                            ;   step queues 15 per 8 frames; behind the rest
                                            ;   of the handler the plain Game Boy managed 1 a
                                            ;   frame and new rows showed undrawn; owner,
                                            ;   2026-11-26)
            ldh a, [pal_req]
            and a
            call nz, bg_pal
            call pal_up                     ; (the palette shadows, when changed: pal.s)
            call box_vbl
            call pt_tick
            call gr_vbl                     ; (the windows' gradient: text.s)
            call ap_vbl                     ; (the airship's view: air.s)
            call fx_vbl                     ; (a spell's raster effect: fx.s)
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
            ld b, a
            ldh a, [is_cgb]
            and a
            jr z, .v1
            ld a, b
            ldh [rVBK], a
.v1:        pop af
            call sbank
            pop hl
            pop de
            pop bc
            pop af
            reti
.mk:        push hl                         ; (the music: the timer's)
            ld hl, frame
            inc [hl]
            ld a, 1
            ldh [vbl_done], a
            pop hl
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
            call pad_opp                    ; (opposite directions together: neither)
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
            jp sreset

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
            ld a, [ml_room]                 ; (a teleport into a room: shown from the start)
            ld [inroom], a
            xor a
            ld [ml_room], a
            ld [moving], a
            ld [mcount], a
            ld [mdx], a
            ld [mdy], a
            ld [q_n], a
            ld [q_rd], a
            ld [wa_ok], a                   ; (the water's tiles back at their first picture)
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
            call pg_mbank                   ; (the post-game's maps: pg.s)
            ld [map_bank], a
            call sbank
            ld a, [M_TS]
            add a, TS_BANK0
            ld [ts_bank], a
.lcd:        call pg_lcd                     ; (LCD off in V-Blank, interrupts off; the battle banks)
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
            call room_bgp                   ; (inside a room after a teleport: its colours)
            ld a, $80
            call cgb_pal32
            call text_pals                  ; (the boxes' palette 7: win_pal as it is now)
            ld a, $80                       ; OBJ palettes 0-3 (NES sprite palettes)
            call ocps_w
            ld hl, M_OBJ
            ld b, 32
            call cc_copy                    ; (the LCD colour mode: cc.s)
.op:        ld a, [hl+]
            call ocpd_w
            dec b
            jr nz, .op
            ld a, F3_BANK                   ; (OBJ 4-7: their darker copies, the reflection's)
            ld hl, refl_pal
            call bank_call
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
.dmg:       call sgb_region                 ; (SGB: the border's colours by region: sgbx.s)
            ld a, [map_bank]                ; DMG: pre-shaded variants 0-127 -> $9000,
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
            ld a, %10010100                 ; (OBP1: the reflection, faded: 1 / 2 light grey,
            ldh [rOBP1], a                  ;   3 dark grey: a soft figure in the water)
            ld hl, M_PARTYDMG               ; party sprite pre-shaded for this map
            ld de, $8000
            ld bc, 16 * 16
            call memcpy
            ld hl, M_OBJDMG
            call obj_tiles
            ld hl, M_VEHDMG
            call veh_tiles
.drw:       call wa_drw                     ; (the water at its step: wanim.s; the leader's class)
            call sgb_map
            ld a, [ml_keep]                 ; (a reload keeps the objects)
            and a
            call z, obj_load
            call bn_ml                      ; (a new map, not a reload: its banner; text.s)
            call font_map
            call draw_all
            call set_scroll
            ldh a, [scx]
            ldh [rSCX], a
            ldh a, [scy]
            ldh [rSCY], a
            call make_oam
            call dma_safe
            ld a, [wp_req]                  ; (a wipe: the map's song once it has opened;
            and a                           ;   during it the wipe sound has square 1, and
            call z, map_music               ;   the song's first notes were spoiled)
            ld a, [pc_req]                  ; (a palette cycle in to follow: black first)
            and a
            call nz, pc_black
            ld a, [wp_req]                  ; (a transition: wiped open)
            and a
            jr nz, wipe_open
            ld a, LCDC_ON
            jp lcd_on

; the map drawn again after a full screen (menu): position, room and objects as they were
map_reload: call fade_out
            ld a, [inroom]
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
            call ot_bc                      ; (256 bytes a block; a tall map's 384)
            call memcpy
            pop de
            inc de
            pop bc
            dec b
            jr nz, .b
            ret



; ---- movement on a standard map (FF1: one metatile in 16 frames, a pixel a frame)
move:       ld a, [moving]
            and a
            jr z, .idle
            ld a, [mcount]                  ; (a dash: two pixels a frame; the step still
            inc a                           ;   ends at 16 and checks for an encounter, so
            ld hl, dash                     ;   none is skipped: they come twice as fast)
            add a, [hl]
            ld [mcount], a
            cp 16
            ret c
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
            call veh_arr                    ; (a vehicle boarded on foot: now, its song)
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
            ld hl, menu_main                ; (the screen's own fade, as every other screen:
            call pc_fade                    ;   owner, 2026-11-25; no colour cycle)
            ld a, [menu_act]                ; Warp / Exit cast in the menu
            and a
            jp z, mr_menu
            ldh a, [maptype]
            and a
            jp nz, mr_menu                  ; (on the overworld: nothing to leave)
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
            jr nz, .mm
            ld b, 8                         ; (Select a moment before B: up to 8 frames for B)
.wb:        push bc
            call wait_vbl
            call read_pad
            pop bc
            ldh a, [pad]
            bit 1, a
            jr nz, .mm
            bit 2, a                        ; (Select let go without B: the lineup)
            jr z, .lu
            dec b
            jr nz, .wb
            jr .lu
.mm:        ld hl, minimap                   ; (FF1: the palettes cycle out first)
            call pc_menu3
            jp map_reload
.lu:        ld a, PG_BANK                   ; (Order is in the main menu now: Select shows the
            ld hl, ps_next                  ;   next member on the map, the leader unchanged;
            jp bank_call                    ;   owner, 2026-11-25)
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
            call pc_menu3
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
            call ow_cmm
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
            ld [dash], a                    ; B held, on foot: this step at double speed
            call dash_b                     ;   (owner, 2026-11-22; Options: Dash On / Off)
            jr z, .nd
            ld a, [vehicle]
            cp V_FOOT
            jr nz, .nd
            ld a, 1
            ld [dash], a
.nd:        jp draw_edge
.door:      ld a, d                         ; a locked door: only with the Mystic Key (FF1)
            and $1E
            cp $04
            jr nz, .dr
            ld a, [ITEMS + 5]
            and a
            ret z
.dr:        ld a, [tx]                      ; (every door stepped on is the one to close
            ld [door_x], a                  ;   later: a room left the way it was entered or
            ld a, [ty]                      ;   another, after stairs or a teleport; owner,
            ld [door_y], a                  ;   2026-11-25: a stale door drawn after stairs up)
            ld a, [inroom]                  ; into a room: palette, the open door drawn
            and a
            jr nz, .ok
            push bc
            ld a, 1
            ld [inroom], a
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
            ld a, l
            or $80
            call room_chk
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
do_tele:    call pg_tchk                    ; (A = fdepth; the post-game's stairs: pg.s)
            push de                         ; push this floor

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
            ld a, e
            call room_chk
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
            ld bc, O_FACE - O_TALK          ; (and stays turned: its facing, as FF1; owner:
            add hl, bc                      ;   not back to its old direction mid-talk)
            ld a, [facing]
            xor 1                           ; (right <-> left, up <-> down)
            ld [hl], a
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
            ret                             ; (its palettes: bg_pal, in V-Blank)

; room state changed: CGB palettes in the next V-Blank; DMG: the visible metatiles again with
; the other pre-shaded tiles (the lines entering later are drawn with the new state anyway)
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

mulsign:    and a                           ; A = sign (-1 / 0 / 1) -> A = sign * C
            ret z
            bit 7, a
            ld a, c
            ret z
            cpl
            inc a
            ret

; pen_iname's end: a name in scr_buf (icon + letters) longer than a list row's 17 cells gets its
; final "ts" in one cell ('~', text.py KERN_TS; FF1's longer names all end in "Gauntlets"; owner,
; 2026-11-26: Mythril Gauntlets ran onto the Equip window's border), then it is printed
kern_ts:    ld hl, scr_buf + 17
            ld a, [hl+]
            and a
            jr z, .p
            ld a, [hl]
            and a
            jr nz, .p
            dec hl
            ld a, [hl]
            cp $73                          ; (s)
            jr nz, .p
            dec hl
            ld [hl], $7E                    ; (~: "ts")
            inc hl
            ld [hl], 0
.p:         ld hl, scr_buf
            jp pen_str

; ---- party sprite (FF1's 2x2 tables: tile, attributes for UL, DL, UR, DR)
make_oam:   ldh a, [tl_mt]                  ; the overworld: vehicles; a tall map: tall.s
            and a
            jp nz, mo_hook
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
.objs:      call ow_bc                      ; the bridge and the canal (FF1
            ld a, [vehicle]                 ;   DrawOWObj_BridgeCanal); the ship / airship
            cp V_SHIP                       ;   standing on the map
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
            ld a, [hl+]                     ; screen x = 72 + 16 (x - px), less the scroll
            push hl                         ;   within a step (anchored to the map)
            ld hl, px
            call ob_pos
            pop hl
            ret c
            sub 8
            ld b, a
            ld a, [hl]
            push hl
            ld hl, py
            call ob_pos
            pop hl
            ret c
            push bc                         ; (C: the tile base, kept; it was taken as the y,
            ld c, a                         ;   so the parked ship / airship drew other tiles
            call ob_step                    ;   at every step: owner, 2026-11-25)
            ld a, b
            ld [vh_x], a
            ld a, c                         ; (FF1 Draw2x2Vehicle: on its tile, 3 lines below
            add a, 3                        ;   the party on foot, as the ship sailing; owner,
            ld [vh_y], a                    ;   2026-11-25: it jumped down when boarded)
            pop bc
            push de
            ld a, [map_bank]
            call sbank
            ld hl, M_VEHTBL
            pop de
.od:        ld a, [vh_y]
            ld b, a
            call .ot
            ld a, b                         ; (.ot keeps B)
            add a, 8
            ld b, a
.ot:        ld a, [vh_x]
            add a, 8
            call .spr
            ld a, [vh_x]
            add a, 16
            jr .spr

; boarding on foot (veh_pend: owner, 2026-11-26, the party walks into the ship / canoe instead
; of turning into it): the canoe drawn on its tile, then bd_oam9 puts the vehicle over the party
bd_oam:     ld a, [veh_pend]
            and a
            ret z
            ld a, PG_BANK
            ld hl, bd_oam9
            jp bank_call

; ---- drawing metatiles into the 32 x 32 BG ring (queued; written in V-Blank)
; queue entry (8 bytes): VRAM address (lo, hi), tiles UL UR DL DR, CGB palette
draw_all:   xor a                           ; (a line pending: superseded)
            ld [de_n], a
            inc a                           ; (LCD off: the flush without the LY limit)
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

draw_edge:  ld a, F3_BANK                   ; (bank 99: de_line, q_feed)
            ld hl, de_line
            jp bank_call

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
            call door_st                    ; (inside a room every door shows open)
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
            ldh a, [is_cgb]                 ; palette: the Color only (its tiles came from the
            and a                           ;   tileset bank, mapped still; the plain Game Boy's
            jr z, .np                       ;   shades are in its tiles)
            ld e, c
            ld d, high(T_MTPAL)
            ld a, [de]
            ld [hl], a
.np:        ld hl, q_n                      ; (one INC: the entry is complete before it)
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
            call ow_brc                     ; (the bridge, or the canal before it is blasted)
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
            call veh_set
            ld a, 1
            ld [no_enc], a
            and a
            ret
.tship:     ld hl, SV_SHIP                  ; FF1 BoardShip: the ship at the target
            call .at
            ret c
            ld a, V_SHIP
            call veh_set
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
            ld a, PG_BANK                   ; (the party into the airship first: bd_air9)
            ld hl, bd_air9
            call bank_call
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

section bank 0, $2540                       ; (main.s continued: room redraw, room palettes)
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
            call room_bgp
            ld a, $80
            call cgb_pal32
            jp text_pals                    ; (the windows' palette 7 and black 5 again)
; HL = the map's CGB BG palettes for the room state (map bank mapped)
room_bgp:   ld hl, M_BGOUT
            ld a, [inroom]
            and a
            ret z
            ld hl, M_BGIN
            ret
room_redraw:
            ld a, 1
            ldh [pal_req], a
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
            call rr_cell                    ; (the Color: door cells only)
            pop de
            pop bc
            inc e
            dec c
            jr nz, .c
            inc d
            dec b
            jr nz, .r
            ret

section bank 0, $1480                       ; (the screen fades)
; ---- the screen fades (owner, 2026-11-22: consistent, stylish transitions): every menu,
; shop and sub-screen change fades out and in, four steps of two frames. The Color: the
; palettes scaled to black (the masked load's colour); DMG / SGB: the shades to white (the
; switched-off screen's colour). fade_out before a load (scr_open, map_reload), fade_in after
; scr_show switches the new screen on; FF1's palette cycle before a menu stands for its
; fade-out (fd_skip).
fade_out:   call lcd_get
            bit 7, a
            ret z
            call gr_fd                      ; (the gradient paused: loc.s)
            ld a, [fd_skip]
            and a
            jr z, .go
            xor a
            ld [fd_skip], a
            ld [fd_saved], a                ; (no colours kept: the load reads them back)
            ret
.go:        ldh a, [is_cgb]
            and a
            jr z, .dmg
            ld a, F3_BANK                   ; the colours from the shadows (never read
            ld hl, fd_get                   ;   back: the gradient's line colours were)
            call bank_call
            ld a, 3
.l:         ld [fd_lv], a
            call fd_step
            ld a, [fd_lv]
            dec a
            cp $FF
            jr nz, .l
            jr .sv
.dmg:       ldh a, [rBGP]
            ld [fd_b], a
            ldh a, [rOBP0]
            ld [fd_o0], a
            ldh a, [rOBP1]
            ld [fd_o1], a
            ld a, 1
.dl:        ld [fd_lv], a
            call fd_dmgw
            call wait_vbl
            call wait_vbl
            call fd_xw                      ; (a slow fade: its extra frames, pal.s)
            ld a, [fd_lv]
            inc a
            cp 4
            jr c, .dl
.sv:        ld a, 1
            ld [fd_saved], a
            xor a
            ld [fd_act], a
            ret
fade_in:    ld a, [fd_in]
            and a
            ret z
            xor a
            ld [fd_in], a
            call gr_fd                      ; (the gradient paused meanwhile)
            ldh a, [is_cgb]
            and a
            jr z, .dmg
            ld a, F3_BANK                   ; (the new screen's colours: the shadows)
            ld hl, fd_get
            call bank_call
            ld a, 1
.l:         ld [fd_lv], a
            call fd_step
            ld a, [fd_lv]
            inc a
            cp 5
            jr c, .l
            ld a, F3_BANK                   ; (the shadows themselves again)
            ld hl, fd_done
            call bank_call
            xor a                           ; (a white fade-in once only)
            ld [fd_wh], a
            ld [fd_act], a
            ret
.dmg:       ld a, 2
.dl:        ld [fd_lv], a
            call fd_dmgw
            call wait_vbl
            call wait_vbl
            call fd_xw                      ; (a slow fade: its extra frames, pal.s)
            ld a, [fd_lv]
            dec a
            cp $FF
            jr nz, .dl
            xor a
            ld [fd_act], a
            ret
; CGB: fd_pal at fd_lv / 4 to the palettes (two frames)
fd_step:    call fd_scale                   ; (fd_tmp, shown by the V-Blank: pal.s)
            call gr_fdramp                  ; (the windows' gradient too: loc.s)
            ld a, 1
            ld [pal_fd], a
            ld a, 3
            ld [pal_dirty], a
            call wait_vbl
            call wait_vbl
            jp fd_xw                        ; (a slow fade: its extra frames, pal.s)
; a V-Blank with room for the palette work (LY 144-147)
fd_vbl:     jp fd_vb2                       ; (screens.s: a late handler never stops it)
            ds 11
; fd_pal (64 colours) x fd_lv / 4 -> fd_tmp
fd_scale:   ld hl, fd_pal
            ld de, fd_tmp
            ld b, 64
.c:         push bc
            ld a, [hl+]
            ld c, a
            ld a, [hl+]
            ld b, a
            push hl
            ld a, c                         ; red
            and 31
            call fd_mul
            ld l, a
            ld a, b                         ; green
            and 3
            add a, a
            add a, a
            add a, a
            ld h, a
            ld a, c
            swap a
            rrca
            and 7
            or h
            call fd_mul
            ld h, a
            ld a, b                         ; blue
            rrca
            rrca
            and 31
            call fd_mul
            ld c, a
            ld a, h
            swap a
            add a, a
            and $E0
            or l
            ld [de], a
            inc de
            ld a, h
            rrca
            rrca
            rrca
            and 3
            ld b, a
            ld a, c
            add a, a
            add a, a
            or b
            ld [de], a
            inc de
            pop hl
            pop bc
            dec b
            jr nz, .c
            ret
fd_mul:     push bc
            ld c, a
            ld a, [fd_wh]                   ; (from white: c + (31 - c) (4 - lv) / 4)
            and a
            jr nz, fd_mulw
            ld a, [fd_lv]
            ld b, a
            xor a
            inc b
.m:         dec b
            jr z, .x
            add a, c
            jr .m
.x:         srl a
            srl a
            call fd_fin                     ; (a fine fade: 8 levels, pal.s)
            pop bc
            ret
; DMG / SGB: the shades lightened by fd_lv
fd_dmgw:    ld a, [fd_b]
            call fd_light
            ldh [rBGP], a
            ld a, [fd_o0]
            call fd_light
            ldh [rOBP0], a
            ld a, [fd_o1]
            call fd_light
            ldh [rOBP1], a
            ret
fd_mulw:    push de
            ld a, 31
            sub c
            ld d, a
            ld a, [fd_lv]
            ld b, a
            call fd_4                       ; (4 levels; a fine fade 8)
            sub b
            ld b, a
            xor a
            inc b
.m:         dec b
            jr z, .x
            add a, d
            jr .m
.x:         srl a
            srl a
            call fd_fin
            add a, c
            pop de
            pop bc
            ret
fd_light:   ld c, a
            ld e, 0
            ld b, 4
.f:         rlc c
            rlc c
            ld a, [fd_lv]
            ld h, a
            ld a, c
            and 3
            sub h
            jr nc, .ok
            xor a
.ok:        sla e
            sla e
            or e
            ld e, a
            dec b
            jr nz, .f
            ld a, e
            ret
; lcd_on with a fade to come (fd_in): the new screen's colours kept, black / white first
fd_on_cgb:  ld de, fd_pal + 64              ; (from the start of a V-Blank: OBJ read, all black;
.obj:       ld c, 0                         ;   then BG from the shadows: RAM only. Lot Check
                                            ;   checker: the old order ran into line 0)
.ro:        ld a, c
            ldh [$FF6A], a
            ldh a, [$FF6B]
            ld [de], a
            inc de
            inc c
            bit 6, c
            jr z, .ro
            ld a, $80
            ldh [rBCPS], a
            ldh [$FF6A], a
            ld a, [fd_wh]                   ; (after the encounter transition: from white)
            and a
            jr nz, .zw
            xor a
            ld b, 64
.z:         ldh [rBCPD], a
            ldh [$FF6B], a
            dec b
            jr nz, .z
            jr .cp
.zw:        ld b, 32
.zwl:       ld a, $FF
            ldh [rBCPD], a
            ldh [$FF6B], a
            ld a, $7F
            ldh [rBCPD], a
            ldh [$FF6B], a
            dec b
            jr nz, .zwl
.cp:        ld hl, sh_pal
            ld de, fd_pal
            ld b, 64
.c:         ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .c
            ret
fd_on_off:  ldh a, [is_cgb]                 ; (the LCD off: only the first screen after
            and a                           ;   power-on or a soft reset; the Color shows
            jr z, fd_on_dmg                 ;   it at once: palette RAM read back is not
            xor a                           ;   dependable there)
            ld [fd_in], a
            ret
fd_on_dmg:  ldh a, [rBGP]
            ld [fd_b], a
            ldh a, [rOBP0]
            ld [fd_o0], a
            ldh a, [rOBP1]
            ld [fd_o1], a
            xor a
            ldh [rBGP], a
            ldh [rOBP0], a
            ldh [rOBP1], a
            ret

section bank 0, $1400                       ; (main.s continued: the airship)
; pc_menu for the screens in F3_BANK (the world map, the 15-puzzle)
pc_menu3:   call ap_stop
            push hl
            ld a, SCR_BANK
            ld hl, pc_out
            call bank_call
            pop hl
            ld a, F3_BANK
            jp bank_call

; FF1 AnimateAirshipTakeoff / AnimateAirshipLanding: the airship rises from y $6F to $4F
; (lands: back), a pixel every second frame, its shadow, the noise (FF1: volume 8, the
; frame counter as its period); then facing right
air_up:     ld a, TALL_BANK                 ; (air_up9 / air_down9: tall.s, for bank 0's room)
            ld hl, air_up9
            jp bank_call
air_down:   ld a, TALL_BANK
            ld hl, air_down9
            jp bank_call
; the main loop's end: the airship's view, then on the plain Game Boy the water's copies in the
; frame's idle H-Blanks (wa_late)
ap_tl:      call ap_tick
            call wa_late
            jp wt_end                       ; (the town water's copy now due: wanim.s)
wa_late:    ldh a, [is_cgb]                 ; (the plain Game Boy / SGB, the overworld, not under
            and a                           ;   the box, the banner or the airship's view: their
            ret nz                          ;   lines' handlers)
            ldh a, [maptype]
            and a
            ret z
            ld a, [wa_ok]
            and a
            ret z
            ld a, [bn_t]
            ld b, a
            ld a, [box_on]
            or b
            ld b, a
            ld a, [ap_on]
            or b
            ret nz
            ld a, WANIM_DMG
            call sbank
            ld a, 2
            ldh [wa_nl], a
            call wa_run
            xor a
            ldh [wa_nl], a
            ret

; FF1 MapPoisonDamage: on foot, each poisoned member loses 1 HP a step (not below 1)
section wram, $CCAB                         ; (free)
wt_req:     ds 1                            ; the town water's step: 1 asked (wa_town), 2 the
                                            ;   field frame ended (wt_end): copied in V-Blank

section bank 0, $3200                       ; (main.s continued)
MINI_BANK  = 97             ; (also: the 12 classes' map sprites at $6400, colours at $7000)
M_PERM     = $7380          ; map bank: DMG rank permutations per class and sprite palette

; the party's map sprite: the leader's class (FF1 LoadPlayerMapmanCHR, MAPMAN_PAL); LCD off.
; CGB: the raw tiles, the class's colours as colour 2 of OBJ palettes 0 / 1; DMG: the tiles
; ranked by brightness for this map (the build's permutations)
party_spr:  call ps_wcls                    ; (the member shown: Select on the map)
            ld [ps_cls], a
            ldh a, [is_cgb]
            and a
            jr z, .dmg
            ld a, [ps_cls]
            add a, $64
            ld h, a
            ld l, 0
            call ps_dst                     ; (DE = $8000, or the RAM copy)
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
            ld hl, scr_buf                  ; (the LCD colour mode: cc.s)
            ld b, 4
            call cc_inpl
            ld a, $84
            call ocps_w
            ld a, [scr_buf]
            call ocpd_w
            ld a, [scr_buf + 1]
            call ocpd_w
            ld a, $8C
            call ocps_w
            ld a, [scr_buf + 2]
            call ocpd_w
            ld a, [scr_buf + 3]
            call ocpd_w
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
            call ps_dde                     ; (E = A; D = $80, or the RAM copy)
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
; A = a music track (FF1's numbers)
snd_track:  ld [NES_RAM + $4B], a
            ld [mus_cur], a                 ; (the song asked for last: FF1 sets $4B to 0 once
            ret                             ;   a song plays, so it cannot tell what plays)
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
            ld a, [mus_cur]                 ; (already playing it: kept; owner, 2026-11-22:
            cp b                            ;   it restarted after every dialogue and menu,
            ret z                           ;   comparing with $4B, which reads 0 while a song
                                            ;   plays)
            ld a, b
            jr snd_track

; ---- encounters and battles
B_RATES    = $4A00          ; battle data bank: encounter rate per map (+1), domains, lut_RNG,
                            ;   the formation weights (B_DOMAINS: bank BTL6, build.py)
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
.exp:       add a, $A0                      ; (A = bsign still)
            ld [bsign], a
.d:         ld l, [hl]                      ; (HL = bstep)
            ld h, high(B_FRNG)
            ld a, BTL_DATA
            ld [fc_bank], a
            call far_byte
            ld l, a                         ; (No Encounters: the Sound Test code's Options;
            ld a, [SC_NOENC]                ;   the step counted as before, no battle)
            and a
            ld a, l
            ret z
            ld a, $FF
            ret
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
            push af
            ldh a, [hbt_dom]                ; (the domain byte: bank BTL6; the post-game's: pg.s)
            ld [fc_bank], a
            pop af
            add a, l
            ld l, a
            ld a, h
            adc a, 0
            ld h, a
            jp far_byte
; a battle with formation A, then the map again (C set: the step handled); lost: game over
do_battle:  ld [btl_fid], a
            call sgb_amb0                   ; (SGB: the ambience off: sgbx.s)
            ld a, F3_BANK                   ; the encounter transition (owner, 2026-11-22; loc.s)
            ld hl, bt_trans2
            call bank_call
            call mmp_sync                   ; (Modern MP: the party's MP in the mode in use)
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
            ld a, F3_BANK
            call sbank
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
            call sv_addr
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
            call sv_addr                    ; (the file: loc.s)
            xor a
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
            call sv_addr
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
            call sv_addr4
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
            call sv_addr
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
            ld a, TR_SAVED                  ; FF1 SaveGame: the "you saved your game" jingle
            jp snd_track

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
dash:       ds 1                            ; this step at double speed (B held, on foot)
bt_lastc:   ds 4                            ; battle: each member's last command, magic slot
bt_lastm:   ds 4                            ;   (owner, 2026-11-22: the cursor remembered)

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
hrx:        ds 1                            ; the encounter transition: its tables' page (0 off)

section bank 0, $3900                       ; (the screen wipe, the palette cycle's helpers)
; ---- the screen wipe (bank TALL_BANK: tall.s wipe_close9 / wipe_open9, for bank 0's room)
wipe_close: ld a, TALL_BANK
            ld hl, wipe_close9
            jp bank_call
wipe_open:  ld a, TALL_BANK
            ld hl, wipe_open9
            jp bank_call
; lcd_off: the windows' gradient off; the file screen gone: its per-file gradient lists (palettes 4-6, the ramps' page)
; off, before gr_off writes the flat colour through the lists
fcw_goff:   ld a, [fcw_on]
            and a
            jp z, gr_off
            xor a
            ld [fcw_on], a
            ld [gr_rpx], a
            dec a
            ld [gr_lm], a
            ld [gr_la], a
            ld [gr_nlm], a
            ld [gr_nla], a
            jp gr_off
; STAT during a wipe (from text.s stat_int): the band's top, the window off (an empty band:
; it stays on), the bottom next
stat_wp:    ld a, [wp_st]                   ; the band's top: the window off (an empty band:
            and a                           ;   it stays on), the bottom next
            jr nz, .wb
            inc a
            ld [wp_st], a
            ld a, [wp_top]
            push bc
            ld b, a
            ld a, [wp_bot]
            cp b
            pop bc
            jr z, .wm
            jr c, .wm
            ld a, 167                       ; (hidden)
            ldh [rWX], a
            ld a, [wp_wh]                   ; (the plain Game Boy's white curtains: the
            and a                           ;   band in the scene's shades)
            jr z, .wt
            ld a, [wp_bgp]
            ldh [rBGP], a
.wt:        ld a, [wp_bot]
            ldh [rLYC], a
            pop af
            reti
.wb:        cp 2                            ; the bottom: the window shown again; the music
            jr nc, .wm2
            ld a, [wp_bot]                  ; (at the screen's bottom: nothing below it to
            cp 144                          ;   cover; shown there, a late V-Blank left it
            jr nc, .wm                      ;   over the whole next frame)
            ld a, 7
            ldh [rWX], a
            ld a, LCDC_WIN
            ldh [rLCDC], a
            ld a, [wp_wh]                   ; (white below the band)
            and a
            jr z, .wm
            xor a
            ldh [rBGP], a
.wm:        ld a, 2
            ld [wp_st], a
            jp stat_int.mus
.wm2:       pop af
            reti
; HL = a screen of SCR_BANK: FF1's palette cycle out, then the screen
pc_menu:    call ap_stop                    ; (the airship's view off: air.s)
            push hl
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
            ld a, [wp_wh]                   ; (the plain Game Boy: the curtains white, BGP 0
            and a                           ;   on their lines; the band the scene's shades)
            jr z, .nw
            ld a, [wp_top]
            and a
            ld a, [wp_bgp]
            jr z, .nw0                      ; (no curtain at the top: the scene's)
            xor a
.nw0:       ldh [rBGP], a
.nw:        ld a, [wp_top]
            and a
            jr z, .z
            ld a, LCDC_WIN
            ldh [rLCDC], a
            ld a, [wp_top]
            dec a
            ldh [rLYC], a
            xor a
            ld [wp_st], a
            ld a, 7
            ldh [rWX], a
            ret
.z:         ld a, LCDC_ON | $40             ; (no band at the top: the window off until the
            ldh [rLCDC], a                  ;   bottom edge; parked at WX 167 instead, it
            ld a, 1                         ;   covered the whole frame on hardware)
            ld [wp_st], a
            ld a, [wp_bot]
            ldh [rLYC], a
            ld a, 167
            ldh [rWX], a
            ret
; the screen black before FF1's palette cycle in (LCD off)
pc_black:   ld a, TALL_BANK                 ; (tall.s pc_black9)
            ld hl, pc_black9
            jp bank_call
; make_oam on the overworld (its vehicles) or a tall map (tall.s: 8 x 16 people)
mo_hook:    ldh a, [maptype]
            and a
            jp nz, veh_oam
            ld a, TALL_BANK
            ld hl, tall_oam
            jp bank_call

; V-Blank with a WX list: the window enabled but out of sight (WX 167: its line counter
; waits), the first entry's line
ly_vbl:     xor a
            ld [ly_i], a
            ldh [rWY], a
            ld a, [ly_bgp]                  ; (a BGP list: the frame starts with its value)
            and a
            jr z, .wx
            ld a, [ly_rst]
            ldh [rBGP], a
            jr .lc
.wx:        ld a, 167
            ldh [rWX], a
.lc:
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
            ld a, BOX_LINES - 1
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
lcd_off:    call fcw_goff                   ; (the windows' gradient off, its windows gone; the
                                            ;   file screen's colours: loc.s)
            xor a
            ld [gr_wn], a
            ld [tl_lc], a                   ; (a tall map's 8 x 16 frames end: tall.s)
            ld a, [bn_t]                    ; (the place-name banner: gone)
            and a
            jr z, .nb
            xor a
            ld [bn_t], a
            ld a, BOX_LINES - 1
            ldh [rLYC], a
.nb:        xor a                           ; (any load: a skipped fade-out is spent)
            ld [fd_skip], a
            ld a, [q_n]                     ; (the field's metatile queue dropped: a new
            ld [q_rd], a                    ;   screen; the field redraws all of its map)
            ld a, [lmask]
            and a
            ret nz
            ldh a, [rLCDC]
            bit 7, a
            ret z
            ldh a, [is_cgb]                 ; (a DMG / SGB: the LCD off, as before; a masked
            and a                           ;   load there runs at a third of the speed (the
            jr nz, .cgb                     ;   line guard): 71 frames for a town, 2026-11-24)
            di
.wd:        ldh a, [rLY]
            cp 144
            jr c, .wd
            cp 153
            jr nc, .wd
            xor a
            ldh [rLCDC], a
            ld a, [fd_saved]                ; (after a fade: the shades back, the screen off)
            and a
            jr z, .dx
            xor a
            ld [fd_saved], a
            ld a, [fd_b]
            ldh [rBGP], a
            ld a, [fd_o0]
            ldh [rOBP0], a
            ld a, [fd_o1]
            ldh [rOBP1], a
.dx:        reti
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
            xor a                           ; (the shadows are the screen's colours:
            ld [fd_saved], a                ;   nothing read back from the screen; black,
            ld a, $80                       ;   white after the encounter transition)
            ldh [rBCPS], a
            ld a, [fd_wh]
            and a
            jr nz, .bw
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
            jr .nc
.bw:        ld b, 32
.bwl:       ld a, $FF
            ldh [rBCPD], a
            ld a, $7F
            ldh [rBCPD], a
            dec b
            jr nz, .bwl
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
            ld a, [fd_in]                   ; (a fade-in to come: white / black first)
            and a
            call nz, fd_on_off
            ldh a, [is_cgb]                 ; (the LCD off: the shadows up before it goes on)
            and a
            call nz, pal_on
            pop af
            ldh [rLCDC], a
            ret
.m:         push bc
            push de
            push hl
            di
.w:         ldh a, [rLY]                    ; (the start of a V-Blank: a fade's palette work
            cp 144                          ;   takes ~8 lines)
            jr nz, .w
            ldh a, [is_cgb]
            and a
            jr z, .d
            call pal_on                     ; (the shadows; black / white for a fade-in)
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
; the palette shadows (pal.s in F3_BANK has the rest): A = the index as BCPS / OCPS
; (bit 7: auto-increment); writes keep A and the flags, as the ldh they replace
bcps_w:     ld [sh_ps], a
            ret
ocps_w:     ld [sh_po], a
            ret
ocpd_w:     push hl
            push bc
            ld hl, sh_po
            ld c, low(pal_ob)
            jr pd_w
bcpd_w:     push hl
            push bc
            ld hl, sh_ps
            ld c, low(sh_pal)
pd_w:       push af
            ld b, a
            ld a, [hl]
            push af
            bit 7, a
            jr z, .n
            inc a
            and $BF
            ld [hl], a
.n:         pop af
            and $3F
            add a, c
            ld l, a
            ld h, high(sh_pal)
            ld [hl], b
            ld a, c                         ; dirty: BG ($80) bit 1, OBJ ($40) bit 0
            rlca
            rlca
            ld hl, pal_dirty
            or [hl]
            ld [hl], a
            pop af
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

section wram, $C880                         ; (the map's queue: free while a menu fades)
fd_tmp:     ds 128
section wram, $D980
sh_pal:     ds 64                           ; masked loads: the CGB BG palettes
lmask:      ds 1
sh_bgp:     ds 1
sh_obp0:    ds 1
sh_ps:      ds 1
sh_stat:    ds 1
gd_off:     ds 1                            ; the guard paused (RAM-only work)
ly_bgp:     ds 1                            ; the raster list writes BGP (not WX)
ly_rst:     ds 1                            ; ... and the frame starts with this BGP
fd_skip:    ds 1                            ; (the fades: skip the next fade-out, palettes
fd_saved:   ds 1                            ;   kept for the load, a fade-in to come, the
fd_in:      ds 1                            ;   step, the DMG shades)
fd_lv:      ds 1
fd_b:       ds 1
fd_o0:      ds 1
fd_o1:      ds 1

section bank 0, $1E00                       ; (main.s continued: the overworld's bridge / canal)
; FF1 DrawOWObj_BridgeCanal: the bridge (OAM 12-15) and the canal (16-19) where they stand, FF1
; lut_OWObjectSprTbl's 2 x 2 (UL UR DL DR here), OW object tiles + $10, palette 3
ow_bc:      ld a, [vehicle]                 ; on foot in a forest (FF1 inforest, tile
            cp V_FOOT                       ;   property bit 4): the party's lower half
            jr nz, .nf                      ;   hidden, the trees over it
            ld a, [tprop_now]
            and $10
            jr z, .nf
            xor a
            ld [oam_buf + 4], a
            ld [oam_buf + 12], a
.nf:        ld hl, SV_BRIDGE
            ld de, oam_buf + 48
            ld bc, .brtbl
            call .obj
            ld hl, SV_CANAL
            ld de, oam_buf + 64
            ld bc, .cntbl
.obj:       ld a, c
            ld [vh_t], a
            ld a, b
            ld [vh_t + 1], a
            ld a, [hl+]                     ; visible and near (OAM x = 80 + 16 (x - px), less
            and a                           ;   the scroll within a step: anchored to the map;
            ret z                           ;   owner, 2026-11-24: it slid with the camera)
            ld a, [hl+]
            push hl
            ld hl, px
            call ob_pos
            pop hl
            ret c
            ld b, a                         ; B = x of the left column
            ld a, [hl]
            ld hl, py
            call ob_pos
            ret c
            ld c, a                         ; C = y of the top row
            call ob_step
            ld a, [vh_t]
            ld l, a
            ld a, [vh_t + 1]
            ld h, a
            call .row
            ld a, c
            add a, 8
            ld c, a
.row:       call .spr
            ld a, b
            add a, 8
            ld b, a
            call .spr
            ld a, b
            sub 8
            ld b, a
            ret
.spr:       ld a, c
            ld [de], a
            inc de
            ld a, b
            ld [de], a
            inc de
            ld a, [hl+]
            add a, $10
            ld [de], a
            inc de
            ld a, [hl+]                     ; (attribute: the palette, no flips here)
            and 3
            ld [de], a
            inc de
            ret
.brtbl:     db 4, 3, 5, 3, 6, 3, 7, 3
.cntbl:     db 8, 3, 9, 3, 10, 3, 11, 3
; A = an object's coordinate, HL = px / py -> A = 16 (A - [HL] + 5) (-5 .. 5 tiles away;
; C set: farther)
ob_pos:     sub [hl]
            add a, 5
            cp 11
            ccf
            ret c
            swap a
            and a
            ret
; B, C less the scroll within the step (mcount x mdx / mdy, as set_scroll)
ob_step:    push hl
            ld a, [mcount]
            ld l, a
            ld a, [mdx]
            call .m
            ld a, b
            sub h
            ld b, a
            ld a, [mdy]
            call .m
            ld a, c
            sub h
            ld c, a
            pop hl
            ret
.m:         ld h, 0                         ; H = sign (A) x L
            and a
            ret z
            ld h, l
            bit 7, a
            ret z
            ld a, h
            cpl
            inc a
            ld h, a
            ret

section bank 0, $1F00
; square 1 after a wipe sound: the music engine's shadow / volume / frequency marked unknown, so
; its next note writes every register (it skipped "unchanged" ones the wipe had changed)
snd_sq1rst: ld a, $FF
            ld [snd_sh], a
            ld [snd_sh + 1], a
            ld [snd_sh + 2], a
            ld [snd_sh + 3], a
            ld [snd_cv], a
            ld [snd_fh], a
            ret

section bank 0, $1F40                       ; (the music timer)
; the music and the sound effects, at the NES's frame rate (the timer: 60.0988 Hz). A tick near
; or in V-Blank (LY 124-153, the LCD on) waits for the next line-64 STAT event (text.s
; stat_int.mus): the main code's V-Blank uploads must not be held up (the music takes lines;
; on a plain Game Boy, tiles written late were garbage)
timer_int:  push af
            push hl
            ld a, [tm_acc]                  ; the next period: 68 / 136 counts, 69 / 137 at
            ld hl, tm_frac                  ;   the fraction
            add a, [hl]
            ld [tm_acc], a
            ld a, [tm_base]
            jr nc, .p
            dec a
.p:         ldh [rTMA], a
            pop hl
            ldh a, [rLCDC]
            bit 7, a
            jr z, .go
            ld a, [lmask]                   ; (a masked load: nothing shows; at once, else
            and a                           ;   held to its end, an effect's note with it)
            jr nz, .go
            call tm_late                    ; (from line 124 to line 1: held)
            jr c, .go
            ld a, [mus_pend]                ; (later: counted; run at line 64, after the
            inc a                           ;   frame's V-Blank work: a tick run in V-Blank
            ld [mus_pend], a                ;   took the plain Game Boy's window-row time,
            pop af                          ;   2026-11-24)
            reti
.go:        call mus_tick
            pop af
            reti
; the music once: the sound bank in rombank meanwhile (V-Blank and the line events may interrupt
; it; their handlers restore rombank); busy already (a nested call): counted for later
mus_tick:   ld a, [mus_busy]
            and a
            jr nz, .def
            inc a
            ld [mus_busy], a
            push bc
            push de
            push hl
            ldh a, [rombank]
            push af
            ld a, SND_BANK
            ldh [rombank], a
            ld [MBC_BANK], a
            ei
            call snd_frame_b
            di
            pop af
            ldh [rombank], a
            ld [MBC_BANK], a
            pop hl
            pop de
            pop bc
            xor a
            ld [mus_busy], a
            ret
.def:       ld a, [mus_pend]
            inc a
            ld [mus_pend], a
            ret

section bank 0, $3BE8
; C set if a music tick may run now: LY 2-123. From line 124 on it is held to line 64 (V-Blank
; uploads); also at LY 0-1: a tick that arrived in line 153 reads LY 0 here, and run then it held a
; V-Blank tile copy (bt_vbl's) into line 9's mode 3 on the plain Game Boy
tm_late:    ldh a, [rLY]
            sub 2
            cp 124 - 2
            ret

section wram, $DAD0
tm_acc:     ds 1                            ; (the music timer: the fraction's sum,
tm_frac:    ds 1                            ;   its step,
tm_base:    ds 1                            ;   the reload)
mus_pend:   ds 1                            ; music ticks waiting for a safe moment
mus_busy:   ds 1                            ; the music running (no second one nested)

section wram, $CF78
sgb_pn:     ds 1                            ; Super Game Boy menu pictures (loc.s sgb_pic)
sgb_px:     ds 1
sgb_py:     ds 1
sgb_pk:     ds 1
sgb_pl:     ds 4 * 4                        ; sprite slot, x, y, ATTR palette byte

section bank 0, $3FC8                       ; (doors: every door open while inside a room)
; A = the metatile to draw for map metatile A: a closed / locked door shows open inside a room
; (owner, 2026-11-25: also after a warp or teleport inside); keeps BC, DE, HL
door_st:    cp MT_CLOSED
            jr z, .d
            cp MT_LOCKED
            ret nz
.d:         push af
            ld a, [inroom]
            and a
            jr z, .n
            pop af
            ld a, MT_OPEN
            ret
.n:         pop af
            ret
; room_redraw's cell (E, D): the Color only needs the doors again (its room state is in the
; palettes); a plain Game Boy all of them (tiles shaded for the state)
rr_cell:    ldh a, [is_cgb]
            and a
            jp z, q_mt
            push de
            call map_at
            pop de
            cp MT_CLOSED
            jp z, q_mt
            cp MT_LOCKED
            jp z, q_mt
            cp MT_OPEN
            ret nz
            jp q_mt

section bank 0, $3878                       ; (free space after gr_reg)
; the battle's results: the left window's cells (0-7, rows 12-17) empty, not an empty window
; (owner's audit, 2026-11-25); the party window drawn next keeps its border
bt_res_clr: ld c, 12
.r:         push bc
            ld b, 0
            call cell_addr
            ld b, 8
            xor a
.f:         ld [hl+], a
            dec b
            jr nz, .f
            ld de, $0300 - 8
            add hl, de
            ld b, 8
.a:         ld [hl+], a
            dec b
            jr nz, .a
            pop bc
            inc c
            ld a, c
            cp 18
            jr c, .r
            ret

section bank 0, $17D0                       ; (free space)
; the LCD on (not a masked load): wait for the first lines of a V-Blank (LY 144-150), so
; palette writes made now are not dropped in mode 3 (Lot Check checker, 2026-11-25)
pal_win:    ld a, [lmask]
            and a
            ret nz
            ldh a, [rLCDC]
            add a, a
            ret nc
.v:         ldh a, [rLY]
            cp 144
            jr c, .v
            cp 151
            jr nc, .v
            ret

section bank 0, $1459                       ; (free space)
; A = the keys read: Up + Down or Left + Right held together count as neither (Lot Check: a
; worn Control Pad or a test rig pressing both must not move the hand / the party both ways)
pad_opp:    ld c, a
            and $C0
            cp $C0
            jr nz, .ud
            ld a, c
            and $3F
            ld c, a
.ud:        ld a, c
            and $30
            cp $30
            ld a, c
            ret nz
            and $CF
            ret

section bank 0, $00C1                       ; (free space before the header)
cgb_pal32:  ld b, 32                        ; HL = 32 bytes of BG palettes 0-3 (A = BCPS)
pal_blk:    push af                         ; B bytes from HL to the BG shadow (A = BCPS)
            call cc_copy                    ; (the LCD colour mode: cc.s)
            pop af
            call bcps_w
.p:         ld a, [hl+]
            call bcpd_w
            dec b
            jr nz, .p
            ret

section bank 0, $1F15                       ; (free space)
wait_vbl:   call rst_chk                    ; (A + B + START + SELECT: a soft reset from any
            ldh a, [rLCDC]                  ;   loop, fades and loads too: Lot Check)
            bit 7, a                        ; (the LCD off: no V-Blank comes; at once, never a
            ret z                           ;   hang)
            call fx_tick
            call sgb_tick                   ; (a Super Game Boy's queued packet: before the
            xor a                           ;   wait, so it never takes V-Blank time)
            ldh [vbl_done], a
.w:         halt
            ldh a, [vbl_done]
            and a
            jr z, .w
            ret
rst_chk:    call btn_rd
            ret nz
; the soft reset (Lot Check: A + B + START + SELECT): cart RAM off, the four buttons let go
; first (held, the game would start again and again), then the title
sreset:     xor a
            ld [$0000], a
.w:         call btn_rd
            jr z, .w
            jp game_over

section bank 0, $1DEB                       ; (free space)
; A = the buttons' four bits (0: pressed), Z: all four held; P1 left as read_pad leaves it
btn_rd:     ld a, $10
            ldh [rP1], a
            ldh a, [rP1]
            ldh a, [rP1]
            ldh a, [rP1]
            ldh a, [rP1]
            push af
            ld a, $30
            ldh [rP1], a
            pop af
            and $0F
            ret

section bank 0, $384B                       ; (free space: moved for the V-Blank handler's VBK)
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

section bank 0, $1FDF                       ; (free space)
; A to VRAM at DE (DE + 1) in a mode where VRAM can be written (0 / 1), whatever the time: the
; fallback of the V-Blank uploads when they miss their window, so they never wait for ever
; (owner, 2026-11-25: a battle's results never came on a plain Game Boy)
vput:       push af
.w:         di
            ldh a, [rSTAT]
            and 2
            jr z, .ok
            ei
            jr .w
.ok:        pop af
            ld [de], a
            ei
            inc de
            ret

section bank 0, $0FC8                       ; (free space)
; map row A of the copy (and its Color attributes) to VRAM byte by byte (vput): sf_one's
; fallback at any time of the frame
row_safe:   ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld d, h
            ld e, l
            ld bc, smap
            add hl, bc
            ld a, [sf_mx]
            add a, $98
            add a, d
            ld d, a
            push hl
            push de
            call .cp
            pop de
            pop hl
            ldh a, [is_cgb]
            and a
            ret z
            ldh [rVBK], a                   ; (is_cgb = 1: VRAM bank 1)
            ld a, h
            add a, 3
            ld h, a
            call .cp
            xor a
            ldh [rVBK], a
            ret
.cp:        ld b, 20
.c:         ld a, [hl+]
            call vput
            dec b
            jr nz, .c
            ret

section bank 0, $2E61                       ; (free space)
; wait for the V-Blank (LY 144+) when the LCD is on; at once when it is off (LY stays 0 then:
; a plain loop on LY would never end)
vb_wait:    ldh a, [rLCDC]
            bit 7, a
            ret z
.v:         ldh a, [rLY]
            cp 144
            jr c, .v
            ret

section bank 0, $25F8                       ; (free space)
box_fb:     ld a, BTL6_BANK                 ; (box_fb9: moved out of bank 0; flags kept)
            ld hl, box_fb9
            jp bank_call
section bank 104, $48C0                     ; (free space)
; the battle's top window going up (box_vbl in the V-Blank): C while its rows are not all up;
; after 6 frames without them, the rest written from here (box_safe), so it never hangs
box_fb9:    ld a, [win_up]
            cp 8
            jr nc, .d
            ld hl, box_fc
            inc [hl]
            ld a, [hl]
            cp 6
            jr c, .c
            ld [hl], 0
            call box_safe
.c:         scf
            ret
.d:         xor a                           ; (NC)
            ld [box_fc], a
            ret

section wram, $CDF5
box_fc:     ds 1

section bank 0, $38E1                       ; (free space)
; map row A to VRAM now: in a V-Blank's first lines whole (interrupts off), else byte by byte
row_put:    ld b, a
            di                              ; (off before the test: an interrupt between
            ldh a, [rLY]                    ;   them pushed a row into line 0; checker)
            cp 144
            jr c, .s
            cp 150
            jr nc, .s
            ld a, b
            call sf_one
            ei
            ret
.s:         ei
            ld a, b
            jp row_safe

section bank 0, $3E65                       ; (free space)
; test builds (build.py --shop N): shop N first (after a second on the map), then the map again
t_shop:     ld a, START_SHOP
            cp $FF
            ret z
            ld a, F3_BANK
            ld hl, t_shop2
            jp bank_call

section bank 99, $4F00                      ; (free space)
t_shop2:    ld b, 60
.w:         push bc
            call wait_vbl
            pop bc
            dec b
            jr nz, .w
            ld a, START_SHOP
            ld [shop_arg], a
            ld hl, shop_main
            call pc_menu
            jp map_reload

section wram, $D940
pal_ob:     ds 64                           ; the Color's OBJ palettes (BG: sh_pal)
section wram, $D9EF
pal_dirty:  ds 1                            ; bit 1 BG, bit 0 OBJ changed: up in the V-Blank
pal_fd:     ds 1                            ; a fade / transition shows fd_tmp
sh_po:      ds 1                            ; the OBJ shadow's index (as OCPS)
ng_new:     ds 1                            ; a new game: its fade into the world (pal.s)
fd_slow:    ds 1                            ; a slow fade: extra frames a step
fd_vol:     ds 1                            ; ... the music's master volume going down with it
fd_fine:    ds 1                            ; a fine fade: 8 levels (fd_lv 0-8) instead of 4

section bank 0, $0000                       ; (the RST vectors' room: no RST is used)
; V-Blank: the changed palettes up (pal.s), not during a masked load (lcd_on shows them)
pal_up:     ld a, [pal_dirty]
            and a
            ret z
            ld a, [lmask]
            and a
            ret nz
            ld a, F3_BANK
            ld hl, pal_put
            jp bank_call
; LCD on: every palette up now (black / white when a fade-in follows)
pal_on:     ld a, F3_BANK
            ld hl, pal_on9
            jp bank_call
; a slow fade's extra frames (fd_slow) after each step
fd_xw:      ld a, [fd_slow]
            and a
            ret z
            ld a, F3_BANK
            ld hl, fd_xw9
            jp bank_call
; every hand (tiles $7C-$7F) off, other sprites kept: a message waiting for A / B over a screen
; with pictures keeps them (owner, 2026-11-26: the Magic screen lost its picture, not its outline)
hands_off:  ld hl, oam_buf + 2
.l:         ld a, [hl]
            and $FC
            cp CUR_TILE
            jr nz, .n
            dec l
            dec l
            ld [hl], 0
            inc l
            inc l
.n:         ld a, l
            add a, 4
            ld l, a
            cp 162
            jr c, .l
            ret

section bank 0, $00E6                       ; (free space)
; A = the shadow's colour byte at the index (as reading BCPD / OCPD)
ocpd_r:     push hl
            ld a, [sh_po]
            ld l, low(pal_ob)
            jr pd_r
bcpd_r:     push hl
            ld a, [sh_ps]
            ld l, low(sh_pal)
pd_r:       and $3F
            add a, l
            ld l, a
            ld h, high(sh_pal)
            ld a, [hl]
            pop hl
            ret

section bank 0, $17E4                       ; (free space)
; a new game (ng_new): the party screen out, the world in, slowly (pal.s)
ng_out:     ld a, [ng_new]
            and a
            ret z
            ld a, F3_BANK
            ld hl, ng_out9
            jp bank_call
ng_in:      ld a, [ng_new]
            and a
            ret z
            ld a, F3_BANK
            ld hl, ng_in9
            jp bank_call

section bank 0, $1798                       ; (free space)
; a fine fade (fd_fine): the level product / 8 instead of / 4 (A = it / 4 already)
fd_fin:     push af
            ld a, [fd_fine]
            and a
            jr z, .n
            pop af
            srl a
            ret
.n:         pop af
            ret
fd_4:       ld a, [fd_fine]
            and a
            ld a, 4
            ret z
            ld a, 8
            ret

section bank 0, $3DF0                       ; (free space)
; the music's NES address HL (FF1 bank 13 at $8000-$BFFF) -> A, the song bank mapped meanwhile.
; NES $C000+ is no song data: $FF, as the open bus (a stray score pointer read disabled cart
; RAM there: Lot Check checker)
mrd:        ld a, h
            cp $C0
            ld a, $FF
            ret nc
            push hl
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

section bank 0, $1EEC                       ; (free space)
; the second hand (OAM 4-7) put away (pick_char's B: the menu goes on without a redraw)
hand2_off:  xor a
            ld [oam_buf + 16], a
            ld [oam_buf + 20], a
            ld [oam_buf + 24], a
            ld [oam_buf + 28], a
            ret

section bank 0, $1FEF                       ; (free space)
; a screen about to fade in (scr_show): the windows' gradient at level 0 too, so its first frame
; is dark (it showed its full colour for a frame under the black palettes: owner, 2026-11-25)
gr_dark:    ldh a, [is_cgb]
            and a
            ret z
            xor a
            ld [fd_lv], a
            jp gr_fdramp

section bank 0, $252A                       ; (free space)
; a screen from the map with its own fade (the main menu): no colour cycle first
pc_fade:    call ap_stop
            ld a, SCR_BANK
            jp bank_call
; back from the main menu: the map faded in (no colour cycle: the menu had its own fade)
mr_menu:    ld a, 1
            ld [fd_in], a
            call map_reload
            jp fade_in

section bank 0, $3E10                       ; (free space)
; ow_canmove, then the vehicle's song when it changed (FF1: boarding / leaving the ship or the
; canoe changes the music; owner, 2026-11-25: the overworld's never came back after the ship)
ow_cmm:     ld a, [vehicle]
            push af
            call ow_canmove
            pop hl                          ; (H = the vehicle before)
            ret c
            ld a, [vehicle]
            cp h
            ret z
            call map_music
            and a
            ret
; on foot: the bridge or the canal at the target, C clear (FF1 IsOnBridge falls through to
; IsOnCanal: the canal's land walks as a bridge until the canal is blasted; owner, 2026-11-25)
ow_brc:     ld hl, SV_BRIDGE
            call ow_canmove.at
            ret nc
            ld hl, SV_CANAL
            jp ow_canmove.at

section bank 0, $351A                       ; (free space)
; party_spr's destination: VRAM, or the RAM copy Select's change draws first (ps_dh)
ps_dst:     ld a, [ps_dh]
            xor $80
            ld d, a
            ld e, 0
            ret
ps_dde:     ld e, a
            ld a, [ps_dh]
            xor $80
            ld d, a
            ret
section bank 0, $3E40                       ; (free space)
; A = the class of the member shown on the map (SHOW_WHO; not Dead / Stone: the next one;
; all down: the leader)
ps_wcls:    push hl
            push bc
            ld a, [SHOW_WHO]
            ld c, a
            ld b, 4
.l:         ld a, c
            and 3
            ld c, a
            rrca
            rrca
            ld l, a
            ld h, high(ch_stats)
            inc l
            ld a, [hl]
            and AIL_DEAD | AIL_STONE
            jr z, .ok
            inc c
            dec b
            jr nz, .l
            ld l, 1
.ok:        dec l
            ld a, [hl]
            pop bc
            pop hl
            ret

section wram, $CFBD
ps_dh:      ds 1                            ; party_spr: 0 VRAM, $41 the RAM copy at $C100

section bank 110, $7000                     ; (free space)
SHOW_WHO   = unsram + $FD   ; the member shown on the map (kept in the save; owner, 2026-11-25)
; Select on the map: the next member who is not Dead / Stone shown; drawn into a RAM copy, then
; into VRAM in V-Blanks with the party's sprites hidden meanwhile
ps_next:    ld a, [SHOW_WHO]
            ld c, a
            ld b, 3
.f:         inc c                           ; the next one up
            ld a, c
            and 3
            ld c, a
            rrca
            rrca
            ld l, a
            ld h, high(ch_stats)
            inc l
            ld a, [hl]
            and AIL_DEAD | AIL_STONE
            jr z, .got
            dec b
            jr nz, .f
            jp sfx_err                      ; (no one else: the error sound)
.got:       ld a, c
            ld [SHOW_WHO], a
            ld a, SFX_MOVE
            ld [sfx_req], a
.q:         ld a, [q_rd]                    ; (the map queue empty: its ring holds the copy)
            ld b, a
            ld a, [q_n]
            cp b
            jr z, .qe
            call wait_vbl
            jr .q
.qe:        ld a, 1                         ; (tall.s: V-Blank's palette work held, its time
            ld [tl_hold], a                 ;   for the copy)
            ld hl, pal_ob + 4               ; (the Color: the colours shown now kept: the new
            ld de, $C3C0                    ;   ones go up with the last tiles; the queue's ring,
            ld a, [hl+]                     ;   empty, holds the copies)
            ld [de], a
            inc e
            ld a, [hl]
            ld [de], a
            inc e
            ld hl, pal_ob + 12
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl]
            ld [de], a
            ld a, $41                       ; the new picture into the RAM copy ($C100)
            ld [ps_dh], a
            call party_spr
            xor a
            ld [ps_dh], a
            ld hl, pal_ob + 4               ; (its colours aside, the shown ones back)
            ld de, $C3C0
            call .sw
            ld hl, pal_ob + 12
            call .sw
            ld a, [tl_map]                  ; (a tall map: its pairs too, made from the copy
            and a                           ;   into $C200-$C37F; tall.s)
            jr z, .np
            ld a, $C1
            ld [tl_sh], a
            ld de, $C200
            ld a, TALL_BANK
            ld hl, tl_pgen
            call bank_call
.np:        ld de, $C380                    ; the copy order at $C380: the tiles not on screen,
            ld c, 0                         ;   then the four on screen (OAM entries 0-3; a tall
.t:         call .vis                       ;   map's 8 x 16 frame: the two pairs)
            jr nz, .tn
            ld a, c
            ld [de], a
            inc e
.tn:        call .nxt
            jr c, .t
            ld c, 0
.t2:        call .vis
            jr z, .tm
            ld a, c
            ld [de], a
            inc e
.tm:        call .nxt
            jr c, .t2
            ld a, $FF
            ld [de], a
            ld bc, $C380                    ; four tiles a V-Blank: the picture on screen changes
.fw:        call wait_vbl                   ;   at once in the last one (the plain Game Boy's
            di                              ;   V-Blank work ends by line 148: about 400 cycles
            ldh a, [rLY]                    ;   of copying left to fit)
            sub 144
            cp 5
            jr c, .fc
            ei
            jr .fw
.fc:        ld a, [bc]                      ; tile T: $C100 + 16 T -> $8000 + 16 T
            push bc
            swap a
            ld l, a
            and $0F
            ld h, a
            ld a, l
            and $F0
            ld l, a
            ld e, a
            ld a, h
            add a, $80
            ld d, a
            ld a, h
            add a, $C1
            ld h, a
            call ps_cp16
            pop bc
            inc c
            ld a, [bc]
            cp $FF
            jr z, .fd
            ld a, c
            and 3
            jr nz, .fc
            ei
            jr .fw
.fd:
            ldh a, [is_cgb]
            and a
            jr z, .fx
            ld hl, $C3C0                    ; the new colours: hardware and shadow
            ld de, pal_ob + 4
            ld a, $84
            call .pc
            ld de, pal_ob + 12
            ld a, $8C
            call .pc
.fx:        xor a                           ; (tall.s: V-Blank's palette work again)
            ld [tl_hold], a
            ei
            ret
; NZ if tile C is one of the party's four on screen (OAM entries 0-3; 8 x 16: tiles T, T + 1)
.vis:       ld hl, oam_buf + 2
            ld b, 4
.vl:        ld a, [hl]
            cp c
            jr z, .vy
            ld a, [tl_lc]
            and a
            jr z, .vn
            ld a, [hl]
            or 1
            cp c
            jr z, .vy
.vn:        inc l
            inc l
            inc l
            inc l
            dec b
            jr nz, .vl
            xor a
            ret
.vy:        or 1
            ret
; the next tile: C set while below 16 (40 on a tall map)
.nxt:       inc c
            ld a, [tl_map]
            and a
            ld a, c
            jr nz, .n4
            cp 16
            ret
.n4:        cp 40
            ret
; swap 2 bytes at HL (pal_ob) and DE (the copy)
.sw:        ld b, 2
.s1:        ld a, [de]
            ld c, [hl]
            ld [hl+], a
            ld a, c
            ld [de], a
            inc e
            dec b
            jr nz, .s1
            ret
; 2 colour bytes HL -> OCPS A, OCPD, and the shadow at DE
.pc:        ldh [rOCPS], a
            ld a, [hl+]
            ldh [rOCPD], a
            ld [de], a
            inc de
            ld a, [hl+]
            ldh [rOCPD], a
            ld [de], a
            ret

section bank 110, $7200                     ; (free space)
; 16 bytes HL -> DE (a tile; DE tile-aligned), unrolled: 5 cycles a byte
ps_cp16:
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
            inc e
            ret

section bank 0, $3E72                       ; (free space; moved: draw_edge's section full)
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

section bank 0, $2D92                       ; (free space)
; q_mt from banked code: the caller's bank back after it (q_mt switches to the map's banks)
q_mtb:      ldh a, [rombank]
            push af
            call q_mt
            pop af
            jp sbank

section bank 99, $4F18                      ; (free space: ps_next moved to bank 110)
de_line:    call q_fall                     ; (a line still pending: queued now)
            ld a, [mdx]                     ; the line of metatiles one beyond the one entering
            and a                           ;   the view (drawn a whole step before it shows:
            jr z, .vert                     ;   owner, 2026-11-26, the top / bottom rows showed
            ld b, 7                         ;   stale tiles while running); right: column x + 7,
            bit 7, a                        ;   left: x - 7
            jr z, .h1
            ld b, $F9
.h1:        ld a, [px]
            add a, b
            ld e, a
            call ap_hrows                   ; (D, B: rows py - 6 .. + 6; flying py - 7 .. + 8)
            ld a, 1                         ; (down the column)
            jr .st
.vert:      ld a, [mdy]                     ; (B: py + 6 / py - 6; flying py + 9 / py - 8:
            bit 7, a                        ;   the ring py - 7 .. + 8, the whole of it)
            jr nz, .up
            call ap_dn
            jr .v1
.up:        call ap_up
.v1:        ld a, [py]
            add a, b
            ld d, a
            ld a, [px]
            sub 7
            ld e, a
            ld b, 15
            xor a                           ; (along the row)
.st:        ld [de_dir], a                  ; the line, queued 3 metatiles a frame (q_feed:
            ld a, e                         ;   the step's first frame was too heavy for the
            ld [de_x], a                    ;   plain Game Boy)
            ld a, d
            ld [de_y], a
            ld a, b
            ld [de_n], a
            ld a, [vehicle]                 ; (flying, a row enters at once: no line ahead)
            cp V_AIR
            ret nz
            jp q_fall

; the pending line (draw_edge): up to 3 metatiles a frame into the queue; q_fall: all of it
q_fall:     ld c, 0
            jr q_fc
q_feed:     ld a, [dash]                    ; (1 a frame walking, 2 dashing: a step's 16 / 8
            inc a                           ;   frames cover the line's 15; more than that
            ld c, a                         ;   overran the plain Game Boy's frames)
q_fc:       ld a, [de_n]
            and a
            ret z
            dec a
            ld [de_n], a
            push bc
            ld a, [de_x]
            ld e, a
            ld a, [de_y]
            ld d, a
            call q_mtb
            ld hl, de_x                     ; (along the row: x + 1; down the column: y + 1)
            ld a, [de_dir]
            add a, l
            ld l, a
            inc [hl]
            pop bc
            dec c
            jr nz, q_fc
            ret

section wram, $DA99
de_x:       ds 1                            ; draw_edge's pending line: start x, y (de_y right
de_y:       ds 1                            ;   after de_x), metatiles left, 1 down the column
de_n:       ds 1
de_dir:     ds 1

section bank 0, $3BEF                       ; (free space)
; ow_canmove's boarding: on foot the vehicle is pending until the step ends (veh_arr)
veh_set:    ld b, a
            ld a, [vehicle]
            cp V_FOOT
            ld a, b
            jr nz, .n
            ld [veh_pend], a
            ret
.n:         ld [vehicle], a
            ret

section bank 0, $292A                       ; (free space)
veh_arr:    ld a, [veh_pend]
            and a
            ret z
            ld [vehicle], a
            xor a
            ld [veh_pend], a
            jp map_music

section bank 0, $29F2                       ; (free space)
; make_oam from banked code, the caller's bank back after it
mo_b:       ldh a, [rombank]
            push af
            call make_oam
            pop af
            jp sbank

section bank 110, $6000                     ; (free space)
; boarding (veh_pend): the vehicle in front of the party in OAM 0-3 (the ship: its parked sprites,
; OAM 4-7; the canoe: drawn as the game draws it, moved onto the target tile), the party after it;
; from half way the party's leading half hidden (it has gone in)
bd_oam9:    ld a, [veh_pend]
            cp V_CANOE
            jr z, .cn
            ld de, oam_buf + 16
            call bd_swap                    ; (DE: the party's entries now)
            jr .hd
.cn:        ld hl, oam_buf                  ; the party aside
            ld de, bd_tmp
            ld b, 16
.c1:        ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .c1
            ld a, V_CANOE                   ; the canoe as the vehicle (OAM 0-3)
            ld [vehicle], a
            call vo_b
            ld a, V_FOOT
            ld [vehicle], a
            ld a, [mcount]                  ; onto the target: + direction x (16 - mcount)
            cpl
            add a, 17
            ld c, a
            ld a, [mdx]
            call mulsign
            ld d, a
            ld a, [mdy]
            call mulsign
            ld e, a
            ld hl, oam_buf
            ld b, 4
.mv:        ld a, [hl]
            add a, e
            ld [hl+], a
            ld a, [hl]
            add a, d
            ld [hl+], a
            inc hl
            inc hl
            dec b
            jr nz, .mv
            ld hl, bd_tmp                   ; the party after it (OAM 20-23)
            ld de, oam_buf + 80
            ld b, 16
.c2:        ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .c2
            ld de, oam_buf + 80
.hd:        ld a, [mcount]
            cp 8
            ret c
            ld a, [mdx]                     ; leading half: right UR DR, left UL DL, down DL DR,
            ld b, %1100                     ;   up UL UR (entries UL, DL, UR, DR)
            and a
            jr z, .v
            bit 7, a
            jr z, .h
            ld b, %0011
            jr .h
.v:         ld a, [mdy]
            ld b, %1010
            bit 7, a
            jr z, .h
            ld b, %0101
.h:         jr bd_hide
; swap 16 bytes oam_buf / DE; DE back at its start
bd_swap:    ld hl, oam_buf
            ld b, 16
.l:         ld a, [de]
            ld c, [hl]
            ld [hl+], a
            ld a, c
            ld [de], a
            inc e
            dec b
            jr nz, .l
            ld a, e
            sub 16
            ld e, a
            ret
; hide the party's entries at DE whose bit is set in B (bit 0 the first)
bd_hide:    ld c, 4
.l:         srl b
            jr nc, .n
            xor a
            ld [de], a
.n:         inc e
            inc e
            inc e
            inc e
            dec c
            jr nz, .l
            ret
; A on the airship: the party sinks into it (its lower half, then all of it, 8 frames each)
bd_air9:    ld c, 16
.f:         push bc
            call mo_b
            ld de, oam_buf + 32             ; (the parked airship: OAM 8-11)
            call bd_swap
            pop bc
            push bc
            ld b, %1010                     ; (DL, DR)
            ld a, c
            cp 9
            jr nc, .h
            ld b, %1111
.h:         call bd_hide
            call wait_vbl
            pop bc
            dec c
            jr nz, .f
            ret

section wram, $DBA0
veh_pend:   ds 1                            ; a vehicle boarded on foot, until the step ends
bd_tmp:     ds 16                           ; the party's sprites while the canoe is drawn

section bank 0, $16D8                       ; (free space)
; veh_oam from banked code, the caller's bank back after it
vo_b:       ldh a, [rombank]
            push af
            call veh_oam
            pop af
            jp sbank
