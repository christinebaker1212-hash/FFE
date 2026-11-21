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
M_TS       = $5052
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

section bank 0, $0040
            jp vblank
section bank 0, $0048
            reti
section bank 0, $0050
            reti
section bank 0, $0100
            nop
            jp start

section bank 0, $0150
start:      di
            ld sp, $E000
            ld b, a                         ; A = $11 on a Game Boy Color
.vw:        ldh a, [rLY]                    ; the LCD goes off only in V-Blank
            cp 144
            jr c, .vw
            xor a
            ldh [rLCDC], a
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
            ld a, b
            cp $11
            ld a, 0
            jr nz, .dm
            inc a
.dm:        ldh [is_cgb], a
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
.v0:        ld hl, dma_rom                  ; OAM DMA routine into HRAM
            ld de, hram_dma
            ld b, dma_end - dma_rom
.dc:        ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .dc
            ld a, $FF
            ld [mt_force], a
            ld a, COMMON                    ; party sprite tiles at $8000
            ld [MBC_BANK], a
            ld hl, C_SPR
            ld de, $8000
            ld bc, 16 * 16
            call memcpy
            ld a, 3
            ld [facing], a
            ld a, START_MAP                 ; (build.py: the overworld at the new game's position
            cp MAP_OW                       ;   unless --start says otherwise)
            jr nz, .st
            ld a, COMMON
            ld [MBC_BANK], a
            ld a, [C_OWSTART]
            ld d, a
            ld a, [C_OWSTART + 1]
            ld e, a
            ld a, MAP_OW
            jr .ld
.st:        ld d, START_X
            ld e, START_Y
.ld:        call load_map
            xor a
            ldh [rIF], a
            ld a, 1                         ; V-Blank interrupt
            ldh [rIE], a
            ei

; ---- main loop: one engine frame per GB frame
main:       call wait_vbl
            call read_pad
            call move
            call set_scroll
            call make_oam
            jr main

wait_vbl:   xor a
            ldh [vbl_done], a
.w:         halt
            ldh a, [vbl_done]
            and a
            jr z, .w
            ret

; ---- V-Blank: OAM, scroll, palettes, queued metatiles
vblank:     push af
            push bc
            push de
            push hl
            call hram_dma
            ldh a, [scx]
            ldh [rSCX], a
            ldh a, [scy]
            ldh [rSCY], a
            ldh a, [pal_req]
            and a
            call nz, bg_pal
            ldh a, [rLY]                    ; (a late handler: no VRAM writes outside V-Blank)
            cp 144
            jr c, .late
            ld c, MT_DRAWQ
            call q_flush
.late:      ld a, 1
            ldh [vbl_done], a
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
            ldh [pad], a
            ld a, $30
            ldh [rP1], a
            ret

; ---- load standard map A with the party at (D = x, E = y): LCD off in V-Blank, graphics,
; palettes, the map drawn, LCD on
load_map:   ld [cur_map], a
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
            ld [MBC_BANK], a
            ld a, [M_TS]
            add a, TS_BANK0
            ld [ts_bank], a
.lcd:
            ldh a, [rLCDC]                  ; LCD off (in V-Blank)
            bit 7, a
            jr z, .off
.vw:        ldh a, [rLY]
            cp 144
            jr c, .vw
            xor a
            ldh [rLCDC], a
.off:       ldh a, [is_cgb]
            and a
            jr z, .dmg
            ld a, [ts_bank]                 ; CGB: the tileset's tiles -> $9000 (0-127),
            ld [MBC_BANK], a                ;   the overworld's 128-255 -> $8800
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
            ld [MBC_BANK], a
            ld hl, M_BGOUT
            ld a, $80
            call cgb_pal32
            ld a, $80
            ldh [rOCPS], a
            ld hl, M_OBJ
            ld b, 16
.op:        ld a, [hl+]
            ldh [rOCPD], a
            dec b
            jr nz, .op
            jr .drw
.dmg:       ld a, [map_bank]                ; DMG: pre-shaded variants 0-127 -> $9000,
            ld [MBC_BANK], a                ;   128-255 -> $8800
            ld hl, M_TILES
            ld de, $9000
            ld bc, 128 * 16
            call memcpy
            ld de, $8800
            ld bc, 128 * 16
            call memcpy
            ld a, %11100100                 ; tile values are shades
            ldh [rBGP], a
            ld a, [M_OBP]
            ldh [rOBP0], a
            ld a, [M_OBP + 1]
            ldh [rOBP1], a
.drw:       call draw_all
            call set_scroll
            ldh a, [scx]
            ldh [rSCX], a
            ldh a, [scy]
            ldh [rSCY], a
            call make_oam
            call hram_dma
            ld a, LCDC_ON
            ldh [rLCDC], a
            ret

cgb_pal32:  ldh [rBCPS], a                  ; HL = 32 bytes of BG palettes 0-3
            ld b, 32
.p:         ld a, [hl+]
            ldh [rBCPD], a
            dec b
            jr nz, .p
            ret

; V-Blank, CGB: the BG palettes for the room state
bg_pal:     xor a
            ldh [pal_req], a
            ldh a, [is_cgb]
            and a
            ret z
            ld a, [map_bank]
            ld [MBC_BANK], a
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
            ldh a, [pad]
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
            ldh a, [maptype]                ; the overworld: blocked if the first byte has
            and a                           ;   the vehicle's bit (1: on foot)
            jr z, .smr
            bit 0, d
            ret nz
            jr .ok
.smr:       ld a, d                         ; doors and rooms
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
.door:      ld a, [inroom]                  ; into a room: palette, the open door drawn
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
            ldh a, [maptype]
            and a
            jr nz, .ow
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
            call load_map
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
            call load_map
            scf
            ret
.ow:        bit 7, e                        ; overworld: second byte bit 7 = an entrance,
            ret z                           ;   bits 0-5 its number
            ld a, [px]                      ; (the overworld position kept for the warp out)
            ld [ow_x], a
            ld a, [py]
            ld [ow_y], a
            xor a
            ld [fdepth], a
            ld a, e
            and $3F
            ld l, a
            ld a, COMMON
            ld [MBC_BANK], a
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
            call load_map
            scf
            ret
.exit:      xor a                           ; exit to the overworld at FF1's exit position
            ld [fdepth], a
            ld a, COMMON
            ld [MBC_BANK], a
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
            call load_map
            scf
            ret
.norm:      push de                         ; push this floor (FF1: for a later warp)
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
            ld [MBC_BANK], a
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
            call load_map
            scf
            ret

; A = metatile -> D, E = its property bytes (the tileset bank)
props:      add a, a
            ld l, a
            ld h, high(T_PROP)
            ld a, [ts_bank]
            ld [MBC_BANK], a
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
            ld [MBC_BANK], a
            ld a, d
            and 63
            add a, $40
            ld h, a
            ld l, e
            ld a, [hl]
            ret
.sm:        ld a, [map_bank]
            ld [MBC_BANK], a
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
make_oam:   ld a, COMMON
            ld [MBC_BANK], a
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
            ret
.spr:       ld a, b
            ld [de], a
            inc de
            ld a, c
            ld [de], a
            inc de
            ld a, [hl+]
            ld [de], a
            inc de
            ld a, [hl+]                     ; NES attributes -> GB: flip bit 6 -> 5, palette
            push bc                         ;   0-1 (CGB bits 0-2, DMG bit 4)
            ld b, a
            and $40
            rrca
            ld c, a
            ld a, b
            and 3
            or c
            ld c, a
            ld a, b
            and 1
            swap a
            or c
            pop bc
            ld [de], a
            inc de
            ret

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
            call q_mt
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
            ld [MBC_BANK], a
            ld b, high(T_MTCGB)
            jr .t
.dmg:       ld a, [map_bank]
            ld [MBC_BANK], a
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
            ld [MBC_BANK], a
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

; ---- helpers
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

section hram, $FF80
hram_dma:   ds 10
is_cgb:     ds 1
vbl_done:   ds 1
pad:        ds 1
scx:        ds 1
scy:        ds 1
pal_req:    ds 1
q_nolim:    ds 1
maptype:    ds 1                            ; 0 standard map, 1 overworld
cmask:      ds 1                            ; coordinate mask: 63 / 255
