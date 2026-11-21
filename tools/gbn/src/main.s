; FF1 native engine (docs/ff1-native.md), milestone 1: boot, a standard map, walking.
; Our own code. Game data comes from the ROM banks tools/gbn/build.py fills at build time:
;   DATA_MAP  (bank 1): map (64 x 64), tile properties, metatile tables
;   DATA_GFX  (bank 2): tiles, palettes, the party sprite tables
; Every label of those banks is defined by the generated data source.

MT_DRAWQ   = 16             ; metatiles written per V-Blank at most
LCDC_ON    = $83            ; LCD on, BG tiles $8800 mode, BG map $9800, sprites 8x8 on
MBC_BANK   = $2000
DATA_MAP   = 1
DATA_GFX   = 2
rVBK       = $FF4F
rBCPS      = $FF68
rBCPD      = $FF69
rOCPS      = $FF6A
rOCPD      = $FF6B

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
            call gfx_load
            ld a, 16                        ; party at the town's entrance, facing down
            ld [px], a
            ld a, 23
            ld [py], a
            ld a, 3
            ld [facing], a
            call draw_all
            call set_scroll
            call make_oam
            call hram_dma
            ld a, LCDC_ON
            ldh [rLCDC], a
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

; ---- V-Blank: OAM, scroll, queued metatiles
vblank:     push af
            push bc
            push de
            push hl
            call hram_dma
            ldh a, [scx]
            ldh [rSCX], a
            ldh a, [scy]
            ldh [rSCY], a
            ld c, MT_DRAWQ
            call q_flush
            ld a, 1
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

; ---- movement on a standard map (FF1: one metatile in 16 frames, a pixel a frame)
move:       ld a, [moving]
            and a
            jr z, .idle
            ld a, [mcount]
            inc a
            ld [mcount], a
            cp 16
            ret nz
            ld a, [mdx]                     ; step done
            ld b, a
            ld a, [px]
            add a, b
            and 63
            ld [px], a
            ld a, [mdy]
            ld b, a
            ld a, [py]
            add a, b
            and 63
            ld [py], a
            xor a
            ld [moving], a
            ld [mcount], a
            ld [mdx], a
            ld [mdy], a
.idle:      ldh a, [pad]
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
            ld a, [px]                      ; the target metatile: blocked if its tile
            add a, b                        ;   properties say so (bit 0 of the first byte)
            and 63
            ld e, a
            ld a, [py]
            add a, c
            and 63
            ld d, a
            push bc
            call map_at                     ; A = metatile
            add a, a
            ld l, a
            ld h, 0
            ld de, sm_prop
            add hl, de
            ld a, DATA_MAP
            ld [MBC_BANK], a
            ld a, [hl]
            pop bc
            bit 0, a
            ret nz
            ld a, b
            ld [mdx], a
            ld a, c
            ld [mdy], a
            ld a, 1
            ld [moving], a
            xor a
            ld [mcount], a
            jp draw_edge

; ---- metatile number at (E = x, D = y) of the map
map_at:     ld a, DATA_MAP
            ld [MBC_BANK], a
            ld l, d                         ; HL = sm_map + 64 y + x
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
            adc a, high(sm_map)
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
make_oam:   ld a, DATA_GFX
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
            ld h, 0
            ld de, mapman_tbl
            add hl, de
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
; queue entry: VRAM address (lo, hi), tiles UL UR DL DR, CGB palette
draw_all:   ld a, [py]                      ; the 16 x 16 metatiles around the party, LCD off
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

draw_edge:  di                              ; (no V-Blank flush while entries are added)
            call .q
            ei
            ret
.q:         ld a, [mdx]                     ; the line of metatiles entering the view
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

; queue metatile (E = x, D = y), map coordinates taken mod 64
q_mt:       ld a, e
            and 63
            ld e, a
            ld a, d
            and 63
            ld d, a
            push de
            call map_at                     ; A = metatile (bank DATA_MAP mapped)
            pop de
            ld c, a                         ; C = metatile
            ld a, [q_n]
            ld l, a
            add a, a
            add a, a
            add a, a
            sub l                           ; 7 bytes an entry
            ld l, a
            ld h, high(qbuf)
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
            ld b, high(mt_dmg_ul)           ; the tile tables: DMG pre-shaded or CGB
            ldh a, [is_cgb]
            and a
            jr z, .t
            ld b, high(mt_cgb_ul)
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
            ld e, c                         ; palette
            ld d, high(mt_pal)
            ld a, [de]
            ld [hl], a
            ld hl, q_n
            inc [hl]
            ret

; write up to C queued metatiles to VRAM (V-Blank or LCD off)
q_flush:    ld a, [q_n]
            and a
            ret z
            ld a, [q_rd]
            ld l, a
            add a, a
            add a, a
            add a, a
            sub l
            ld l, a
            ld h, high(qbuf)
.e:         ld a, [hl+]
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
            ld a, [q_n]
            ld b, a
            ld a, [q_rd]
            cp b
            jr z, .done
            dec c
            jr nz, .e
            ret
.done:      xor a
            ld [q_n], a
            ld [q_rd], a
            ret

; ---- graphics and palettes (LCD off)
gfx_load:   ld a, DATA_GFX
            ld [MBC_BANK], a
            ldh a, [is_cgb]
            and a
            jr z, .dmg
            ld hl, cgb_tiles                ; BG: the tileset's 128 tiles -> $9000
            ld de, $9000
            ld bc, 128 * 16
            call memcpy
            ld a, $80                       ; BG palettes 0-3, OBJ palettes 0-1
            ldh [rBCPS], a
            ld hl, cgb_bg
            ld b, 32
.bp:        ld a, [hl+]
            ldh [rBCPD], a
            dec b
            jr nz, .bp
            ld a, $80
            ldh [rOCPS], a
            ld hl, cgb_obj
            ld b, 16
.op:        ld a, [hl+]
            ldh [rOCPD], a
            dec b
            jr nz, .op
            jr .spr
.dmg:       ld hl, dmg_tiles                ; BG: pre-shaded variants 0-127 -> $9000,
            ld de, $9000                    ;   128-255 -> $8800
            ld bc, 128 * 16
            call memcpy
            ld de, $8800
            ld bc, 128 * 16
            call memcpy
            ld a, %11100100                 ; tile values are shades
            ldh [rBGP], a
            ld a, [obp_vals]
            ldh [rOBP0], a
            ld a, [obp_vals + 1]
            ldh [rOBP1], a
.spr:       ld hl, spr_tiles                ; party sprite: 16 tiles at $8000
            ld de, $8000
            ld bc, 16 * 16
            jp memcpy

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
qbuf:       ds 7 * 36                       ; metatile queue (page $C1)
            ds 4
px:         ds 1
py:         ds 1
facing:     ds 1
moving:     ds 1
mcount:     ds 1
mdx:        ds 1
mdy:        ds 1
q_n:        ds 1
q_rd:       ds 1

section hram, $FF80
hram_dma:   ds 10
is_cgb:     ds 1
vbl_done:   ds 1
pad:        ds 1
scx:        ds 1
scy:        ds 1
