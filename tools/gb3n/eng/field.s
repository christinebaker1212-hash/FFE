; FF3 native port (docs/ff3-gb-rewrite.md): boot and the field. Built on FF1's native engine
; (tools/gbn/src/main.s: its boot, V-Blank handler, metatile queue, map drawing, scroll and party
; sprite), Color only; FF3's rules written natively from what the everything8215/ff3 listing says
; FF3 does (the routine named beside each piece). Our own code; every game byte comes from the
; user's ROM through the banks tools/gb3n/port.py builds (layout at its top).
;
; RAM (Color only):
;   $C000 oam_buf, $C100-$C8FF qbuf (the metatile queue), $C900- the engine's variables,
;   $C980 TS7B, $CA00 palettes / the map record, $CB00 FF3's zero page (Z), $CC00 / $CD00 FF3's
;   objects (O0 / O1), $CE00 FF3's $0700 (T07), $CF00-$CFFF the stack (SP $D000: never in the
;   switchable bank)
;   WRAM bank 1 $D000-$D3FF: SV, FF3's save page ($6000-$63FF: the listing's addresses map to
;     SV + (address - $6000)), $D400-$D7FF FF3's $7000-$73FF (map objects)
;   WRAM bank 2 (the field's tables, switched in by the field code only; every interrupt
;     handler maps bank 1 and restores the bank):
;     $D000 the tilemap (FF3 $7400, 32 x 32), $D400 tile property byte 1 ($0400), $D500 byte 2
;     ($0500), $D600 palette per metatile ($0600), $D700 / $D800 / $D900 / $DA00 the UL / UR /
;     DL / DR corner tiles ($7C00 / $7D00 / $7E00 / $7200), $DB00 FF3's $0700-$07FF (entrances,
;     treasures, triggers, the map exit, trigger counts)

LCDC_ON    = $83            ; LCD on, BG tiles $8800 mode, BG map $9800, sprites 8x8 on
MBC_BANK   = $2000
MT_DRAWQ   = 20             ; metatiles written per V-Blank at most
rVBK       = $FF4F
rSVBK      = $FF70
rKEY1      = $FF4D
rBCPS      = $FF68
rBCPD      = $FF69
rOCPS      = $FF6A
rOCPD      = $FF6B
SV         = $D000          ; FF3's $6000
OBJ7       = $D400          ; FF3's $7000
W_MAP      = $D000          ; (WRAM bank 2)
W_P1       = $D400
W_P2       = $D500
W_PAL      = $D600
W_UL       = $D700
W_UR       = $D800
W_DL       = $D900
W_DR       = $DA00
W_TB       = T07            ; FF3 $0700 (event.s)
facing     = Z + $33
cur_map    = Z + $48
world      = Z + $78
aa_mode    = Z + $AA
fill_mt    = Z + $4C
t44        = Z + $44
t45        = Z + $45
lay43      = Z + $43
zlev       = Z + $A5
trig       = Z + $AB
frame16    = Z + $F0
C_RGB      = $4000          ; COMMON (port.py)
C_POSE     = $4080
C_POSEOFS  = $40C0
C_TRBASE   = $4100
C_TRTYPE   = $4180
C_TRFIRST  = $41A0
C_BITS     = $41C0
C_NPCSW    = $4200
C_JOBBASE  = $4240
C_INITMP   = $4248
C_INITHP   = $4258
C_INITST   = $4260
C_INITEQ   = $4280
C_SPAL     = $4400
C_MENUT    = $6000
C_FONT     = $6900
C_WINPAL   = $4300
MS_MAX     = 8              ; the map stack's depth (FF3: the 6502 stack, up to $20 bytes free)

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
            ld sp, $D000
            cp $11                          ; A = $11 on a Game Boy Color
            jp nz, not_cgb
            ldh a, [rLCDC]                  ; the LCD goes off only in V-Blank (if on)
            bit 7, a
            jr z, .lo
.vw:        ldh a, [rLY]
            cp 144
            jr c, .vw
            xor a
            ldh [rLCDC], a
.lo:        ld a, 1                         ; work RAM cleared, every bank (Lot Check: no stale
            ldh [rSVBK], a                  ;   memory; the stack is in bank 0, cleared last)
            ld hl, $C000
            ld de, $0E00
            call memclr
            ld b, 7
.wb:        ld a, b
            ldh [rSVBK], a
            ld hl, $D000
            ld de, $1000
            call memclr
            dec b
            jr nz, .wb
            ld a, 1
            ldh [rSVBK], a
            ld hl, $FF80
            ld de, $7F
            call memclr
            ldh a, [rKEY1]                  ; double speed (KEY1 + STOP), FF1's
            bit 7, a
            jr nz, .ds
            xor a
            ldh [rIE], a
            ld a, $30
            ldh [rP1], a
            ld a, 1
            ldh [rKEY1], a
            stop
            nop
.ds:        xor a                           ; VRAM cleared, both banks
            ldh [rVBK], a
            ld hl, $8000
            ld de, $2000
            call memclr
            ld a, 1
            ldh [rVBK], a
            ld hl, $8000
            ld de, $2000
            call memclr
            xor a
            ldh [rVBK], a
            ld hl, dma_rom                  ; OAM DMA routine into HRAM
            ld de, hram_dma
            ld b, dma_end - dma_rom
.dc:        ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .dc
            call sv_init                    ; a new game's save page (FF3 init sram)
            call snd_init                   ; FF3's sound driver (sound.s)
            ld a, COMMON                    ; the window font (VRAM bank 1, tile = code)
            call sbank
            ld a, 1
            ldh [rVBK], a
            ld hl, C_FONT
            ld de, $9000
            ld bc, 128 * 16
            call memcpy
            xor a
            ldh [rVBK], a
            ld hl, C_WINPAL                 ; BG palette 7: FF3's window colours
            ld de, sh_pal + 56
            ld bc, 8
            call memcpy
            ld a, $FF
            ld [z4B], a
            ld a, BOX_LINES - 1             ; LYC: the dialogue box's bottom
            ldh [rLYC], a
            ld a, $40
            ldh [rSTAT], a
            xor a
            ldh [rIF], a
            ld a, 3                         ; V-Blank, STAT
            ldh [rIE], a
            ei
            ld a, START_WORLD
            ld [world], a
            ld a, START_X
            ld [px], a
            ld a, START_Y
            ld [py], a
            ld a, 4                         ; facing down
            ld [facing], a
            ld a, START_MAP
            ld [cur_map], a
            ld a, START_AA                  ; (a new game: map 0 from FF3's program start, 3E/C0E6;
            call load_map                   ;   test builds: the position given, kept)

; ---- main loop: FF3 map main (3F/E1E1), one engine frame per GB frame
main:       call wait_vbl
            call snd_frame
            call read_pad
            ld hl, zF0
            inc [hl]
            call scroll_step                ; (FF3 update scrolling: the step in progress)
            ld a, [moving]
            and a
            jr nz, .spr
            ld a, [z76]                     ; (a dialogue pending)
            and a
            jr nz, .spr
            ld a, [trig]                    ; a trigger stepped on (FF3 $AB)
            and $E0
            jr z, .in
            call do_trigger
            jr main
.in:        call check_input
.spr:       ld a, [z76]                     ; a dialogue (FF3 $76 -> show dialogue)
            and a
            call nz, dlg_show
            call q_feed
            call set_scroll
            call make_oam
            call npc_frame
            jr main


; ---- V-Blank: OAM, scroll, palettes, queued metatiles (FF1's handler, Color only)
vblank:     push af
            ldh a, [bmode]                  ; (a battle: its own V-Blank work: bridge.s)
            and a
            jp nz, vbl_b
            push bc
            push de
            push hl
            ldh a, [mapbank]
            push af
            ldh a, [rSVBK]                  ; (the field's bank 2 may be mapped: bank 1 here)
            push af
            ld a, 1
            ldh [rSVBK], a
            ldh a, [rVBK]
            push af
            xor a
            ldh [rVBK], a
            ld hl, frame
            inc [hl]
            ldh a, [oam_ok]
            and a
            call nz, hram_dma
            ldh a, [scx]
            ldh [rSCX], a
            ldh a, [scy]
            ldh [rSCY], a
            call pal_put
            ldh a, [rLY]                    ; (a late handler: no VRAM writes outside V-Blank)
            cp 144
            jr c, .late
            ld c, MT_DRAWQ
            call q_flush
            call box_vbl
.late:      ld a, 1
            ldh [vbl_done], a
            pop af
            ldh [rVBK], a
            pop af
            ldh [rSVBK], a
            pop af
            ldh [mapbank], a
            ld [MBC_BANK], a
            pop hl
            pop de
            pop bc
            pop af
            reti

; the Color's palette shadows up when changed (FF1 pal.s pal_put: only while V-Blank has room)
pal_put:    ld a, [pal_dirty]
            and a
            ret z
            ldh a, [rLY]
            sub 144
            cp 6
            ret nc
            xor a
            ld [pal_dirty], a
            ld a, $80
            ldh [rBCPS], a
            ld hl, sh_pal
            ld c, low(rBCPD)
            call .c64
            ld a, $80
            ldh [rOCPS], a
            ld c, low(rOCPD)
.c64:       ld b, 64
.l:         ld a, [hl+]
            ldh [c], a
            dec b
            jr nz, .l
            ret

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
            and $30                         ; (opposite directions together: neither; Lot
            cp $30                          ;   Check)
            jr nz, .h
            ld a, c
            and $CF
            ld c, a
.h:         ld a, c
            and $C0
            cp $C0
            jr nz, .v
            ld a, c
            and $3F
            ld c, a
.v:         ldh a, [pad]                    ; newly pressed this frame
            cpl
            and c
            ldh [pad_new], a
            ld a, c
            ldh [pad], a
            ld a, $30
            ldh [rP1], a
            ld a, c                         ; A + B + Start + Select: soft reset (Lot Check)
            and $0F
            cp $0F
            ret nz
            jp sreset

; the soft reset: the four buttons let go first, then the boot again (the title, once there is one)
sreset:     xor a
            ld [$0000], a
.w:         call read_btn
            cp $0F
            jr z, .w
            di
            ld a, $11
            jp start
read_btn:   ld a, $10
            ldh [rP1], a
            ldh a, [rP1]
            ldh a, [rP1]
            ldh a, [rP1]
            ldh a, [rP1]
            cpl
            and $0F
            push af
            ld a, $30
            ldh [rP1], a
            pop af
            ret

wait_vbl:   ldh a, [rLCDC]                  ; (the check and the halt with interrupts off: a
            bit 7, a                        ;   V-Blank between them never costs a frame)
            ret z
            xor a
            ldh [vbl_done], a
.w:         di
            ldh a, [vbl_done]
            and a
            jr nz, .d
            ei
            halt
            jr .w
.d:         ei
            ret

; ---- FF3 init sram (3A/8E76): a new game's save page from the ROM's tables
sv_init:    ld a, COMMON
            call sbank
            ld hl, SV                       ; cleared
            ld de, $400
            call memclr
            ld a, $29                       ; the world map position (41, 47)
            ld [SV + $09], a
            ld a, $2F
            ld [SV + $0A], a
            ld hl, SV + $40                 ; treasure switches: all closed
            ld b, $40
            ld a, $FF
.ts:        ld [hl+], a
            dec b
            jr nz, .ts
            ld hl, C_NPCSW                  ; npc switches
            ld de, SV + $80
            ld bc, 64
            call memcpy
            ld b, 5                         ; job base stats 2-6: base and modified
            ld hl, C_JOBBASE + 2
            ld de, SV + $112
.bs:        ld a, [hl]
            ld [de], a
            push de
            ld a, e
            add a, 5
            ld e, a
            ld a, [hl+]
            ld [de], a
            pop de
            inc de
            dec b
            jr nz, .bs
            ld hl, C_INITMP                 ; MP (job 0: the table's first 8), current and max
            ld de, SV + $130
            ld b, 8
.mp:        ld a, [hl+]
            ld [de], a
            inc de
            ld [de], a
            inc de
            dec b
            jr nz, .mp
            ld a, [C_INITHP]                ; HP, current and max
            ld [SV + $10C], a
            ld [SV + $10E], a
            ld a, [C_INITHP + 1]
            ld [SV + $10D], a
            ld [SV + $10F], a
            ld hl, C_INITST
            ld de, SV + $11C
            ld bc, 20
            call memcpy
            ld hl, C_INITEQ
            ld de, SV + $200
            ld bc, 16
            call memcpy
            ld hl, SV + $106                ; no names yet
            ld b, 6
            ld a, $FF
.nm:        ld [hl+], a
            dec b
            jr nz, .nm
            ld hl, SV + $100                ; the other three characters as the first
            ld de, SV + $140
            ld bc, $C0
            call .cp
            ld hl, SV + $200
            ld de, SV + $240
            ld bc, $C0
.cp:        push hl                         ; (three copies of $40 bytes)
            push de
            ld bc, $40
            call memcpy
            pop de
            pop hl
            push hl
            ld a, e
            add a, $40
            ld e, a
            push de
            ld bc, $40
            call memcpy
            pop de
            pop hl
            push hl
            ld a, e
            add a, $40
            ld e, a
            ld bc, $40
            call memcpy
            pop hl
            ret

; ---- load a normal map (FF3 3F/E7EC load map -> 3E/CBA4, 3A/915E init map, 3E/DD0F graphics,
; 3A/8509 palette, 3F/E81B init map): cur_map, world; A = FF3's $AA (0: from the world map, the
; position from the map's properties; bit 7 a submap / bit 0 a reload: px / py kept)
load_map:   ld [aa_mode], a
            call lcd_off
            xor a
            ld [moving], a
            ld [mcount], a
            ld [mdx], a
            ld [mdy], a
            ld [trig], a
            ld [q_n], a
            ld [q_rd], a
            ld [de_n], a
            ld a, [world]                   ; the record: world 0 / 1 / 2-4
            and a
            jr z, .c
            ld a, 1
            ld b, a
            ld a, [world]
            cp 2
            ld a, b
            jr c, .c
            inc a
.c:         ld b, a                         ; HL = 128 * (256 c + map) in bank MAPREC0 + i / 128
            ld a, [cur_map]
            ld c, a                         ; BC = record index
            ld a, c
            rlca
            and 1
            ld d, a
            ld a, b
            add a, a
            add a, d
            add a, MAPREC0
            call sbank
            ld a, c
            and $7F
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, $4000
            add hl, de
            ld de, mrec
            ld bc, 128
            call memcpy
            ld a, 2                         ; the field's tables in WRAM bank 2
            ldh [rSVBK], a
            ld a, [mrec + 0]                ; the tilemap (unpacked at build time)
            call sbank
            ld hl, mrec + 1
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld de, W_MAP
            ld bc, $400
            call memcpy
            ld a, TSETS                     ; the tileset (3A/9267 load map properties):
            call sbank                      ;   corner tiles, palettes, property bytes
            ld a, [mrec + 5]
            add a, a
            add a, a
            add a, $40
            ld h, a
            ld l, 0
            ld de, W_UL
            ld bc, 128
            call memcpy
            ld de, W_UR
            ld bc, 128
            call memcpy
            ld de, W_DL
            ld bc, 128
            call memcpy
            ld de, W_DR
            ld bc, 128
            call memcpy
            ld de, W_PAL
            ld bc, 128
            call memcpy
            ld de, W_P1
            ld bc, 128
            call memcpy
            ld de, W_P2
            ld bc, 128
            call memcpy
            ld a, COMMON                    ; trigger tiles $80-$FF: copies of their base tiles
            call sbank                      ;   (3A/92D9)
            ld hl, C_TRBASE
            ld c, $80
.tb:        ld a, [hl+]
            push hl
            ld e, a
            ld d, high(W_P1)
            ld l, c
            ld h, d
            ld a, [de]
            ld [hl], a
            inc d
            inc h
            ld a, [de]
            ld [hl], a
            inc d
            inc h
            ld a, [de]
            ld [hl], a
            inc d
            inc h
            ld a, [de]
            ld [hl], a
            inc d
            inc h
            ld a, [de]
            ld [hl], a
            inc d
            inc h
            ld a, [de]
            ld [hl], a
            inc d
            inc h
            ld a, [de]
            ld [hl], a
            pop hl
            inc c
            jr nz, .tb
            ld hl, mrec + 64                ; entrances, treasures, triggers (3A/93AC)
            ld de, W_TB
            ld bc, 48
            call memcpy
            ld a, [mrec + 16 + 11]          ; the map exit (property byte 11)
            ld [W_TB + $30], a
            ld hl, W_TB + $40               ; trigger counts cleared (3A/918D)
            ld b, $40
            xor a
.cc:        ld [hl+], a
            dec b
            jr nz, .cc
            call init_trig                  ; (3A/9197: trigger tiles numbered)
            ld a, 1
            ldh [rSVBK], a
            ld a, [aa_mode]                 ; (a reload keeps the npcs: 3F/E7F8)
            and a
            jr z, .npc
            bit 7, a
            jr z, .nl
.npc:       call npc_load
.nl:
            ld a, COMMON                    ; this map's encounter rate (3F/E8A5: 39/BE00, off
            call sbank                      ;   world 0 39/BF00)
            ld a, [cur_map]
            ld l, a
            ld h, high(C_ENCRATE)
            ld a, [world]
            and a
            jr z, .er
            inc h
.er:        ld a, [hl]
            ld [zF8], a
            ld a, [mrec + 16 + 1]           ; (3A/930B: chests 16-31 hold gil)
            and $20
            ld [z49], a
            ld a, [mrec + 16 + 3]           ; the fill tile outside the 32 x 32 (byte 3)
            ld [fill_mt], a
            ld a, [aa_mode]                 ; from the world map: the map's own entry point
            and a                           ;   (bytes 0 / 1; FF3 puts its scroll at - 7)
            jr nz, .pos
            ld a, [mrec + 16 + 0]
            and $1F
            ld [px], a
            ld a, [mrec + 16 + 1]
            and $1F
            ld [py], a
            ld a, 4                         ; facing down (3F/E861)
            ld [facing], a
.pos:       call load_gfx                   ; (3E/DD0F)
            ld a, COMMON                    ; (the window font again: a battle uses VRAM bank 1)
            call sbank
            ld a, 1
            ldh [rVBK], a
            ld hl, C_FONT
            ld de, $9000
            ld bc, 128 * 16
            call memcpy
            xor a
            ldh [rVBK], a
            call npc_gfx
            call load_pal                   ; (3A/8509)
            ld a, [px]                      ; the tile under the party: its z-level and layer
            ld e, a                         ;   (3F/E87B)
            ld a, [py]
            ld d, a
            call tile_props
            ld a, [aa_mode]
            bit 7, a
            jr nz, .z
            and a
            jr nz, .nz
.z:         ld a, [t44]
            and $34
            ld [lay43], a
            ld a, [t44]
            and $03
            ld [zlev], a
            ld a, [t44]                     ; (3F/E890: standing on an event trigger: it runs)
            bit 7, a
            jr z, .nz
            ld a, [t45]
            cp $F0
            call nc, ev_trigF
.nz:        ld a, [lay43]                   ; (3F/E89D: $44 = $43, no trigger)
            ld [t44], a
            xor a
            ld [t45], a
            call draw_all
            call set_scroll
            ldh a, [scx]
            ldh [rSCX], a
            ldh a, [scy]
            ldh [rSCY], a
            call make_oam
            ld a, [mrec + 16 + 10]          ; the map's song (3F/E8CE: property byte 10)
            bit 7, a
            jr nz, .ns                      ; (a conditional song: with its script)
            ld [M_SONG], a
            ld a, 1
            ld [M_CTRL], a
.ns:        ld a, LCDC_ON
            jp lcd_on

; FF3 init trigger (3A/9197 / 91C8): every tile $60-$63 / $70-$7C in the map becomes its numbered
; trigger tile ($80-$FF), its trigger id in property byte 2; an opened chest becomes $7D
; (WRAM bank 2 mapped; COMMON for the tables)
init_trig:  ld hl, W_MAP
.l:         ld a, [hl]
            cp $60
            jr c, .n
            cp $64
            jr c, .t
            cp $70
            jr c, .n
            cp $7D
            jr nc, .n
.t:         push hl
            call .one
            pop hl
            ld [hl], a
.n:         inc hl
            ld a, h
            cp high(W_MAP) + 4
            jr nz, .l
            ret
.one:       sub $60                         ; X = tile - $60
            ld c, a
            ld b, 0
            ld hl, W_TB + $40               ; $88 = this tile's count, then + 1
            add hl, bc
            ld a, [hl]
            ld [tr88], a
            inc [hl]
            ld hl, C_TRTYPE                 ; the type -> its count = the trigger id ($89)
            add hl, bc
            ld a, [hl]
            ld e, a
            ld d, 0
            ld hl, W_TB + $60
            add hl, de
            ld a, [hl]
            ld [tr89], a
            inc [hl]
            ld hl, C_TRFIRST                ; the new tile = the tile's first + its count
            add hl, bc
            ld a, [tr88]
            add a, [hl]
            ld e, a                         ; E = the new tile id
            ld a, c
            cp $1C
            jr z, .chest
.trg:       ld l, e                         ; property byte 2 |= the trigger id
            ld h, high(W_P2)
            ld a, [tr89]
            or [hl]
            ld [hl], a
            ld a, e
            ret
.chest:     ld a, [tr89]                    ; a chest: its treasure id (3A/91F7)
            ld c, a
            ld b, 0
            ld hl, W_TB + $10
            add hl, bc
            ld a, [hl]
            push af
            and 7
            ld c, a                         ; the bit
            pop af
            rrca
            rrca
            rrca
            and $1F
            ld b, a                         ; the switch byte (+ 32 off the floating continent)
            ld a, [world]
            and a
            ld a, b
            jr z, .w0
            add a, $20
.w0:        ld b, a
            push de
            ld a, 1                         ; (the save page: WRAM bank 1)
            ldh [rSVBK], a
            ld e, b
            ld d, 0
            ld hl, SV + $40
            add hl, de
            ld d, [hl]
            ld a, 2
            ldh [rSVBK], a
            ld b, 0
            ld hl, C_BITS
            add hl, bc
            ld a, [hl]
            and d
            pop de
            jr nz, .trg                     ; (closed: a chest trigger)
            ld a, $7D                       ; opened
            ret

; FF3 get tile properties (3F/E51C): E = x, D = y (0-63) -> t44 / t45 (bytes 1 / 2); the fill
; tile outside the 32 x 32
tile_props: call map_at
            ld e, a
            ld a, 2
            ldh [rSVBK], a
            ld d, high(W_P1)
            ld a, [de]
            ld [t44], a
            inc d
            ld a, [de]
            ld [t45], a
            ld a, 1
            ldh [rSVBK], a
            ret

; E = x, D = y (0-63) -> A = metatile (WRAM bank 1 mapped after)
map_at:     ld a, e
            or d
            and $20
            jr z, .in
            ld a, [fill_mt]
            ret
.in:        ld a, d                         ; HL = W_MAP + 32 y + x
            rrca
            rrca
            rrca
            ld b, a
            and $E0
            or e
            ld l, a
            ld a, b
            and 3
            add a, high(W_MAP)
            ld h, a
            ld a, 2
            ldh [rSVBK], a
            ld b, [hl]
            ld a, 1
            ldh [rSVBK], a
            ld a, b
            ret

; ---- the map's graphics (FF3 3E/DD0F): the BG tiles of the map's graphics subset (0-111) and
; the menu window / text tiles (112-255), the showing character's walking tiles (3E/DD2D) into
; VRAM bank 1 (sprite tiles 0-15); LCD off
load_gfx:   ld a, [mrec + 3]
            call sbank
            ld a, [mrec + 4]
            ld h, a
            ld l, 0
            ld de, $9000
            ld bc, 112 * 16
            call memcpy
            ld a, COMMON
            call sbank
            ld hl, C_MENUT
            ld de, $9700
            ld bc, 16 * 16
            call memcpy
            ld de, $8800
            ld bc, 128 * 16
            call memcpy
            call char_id
            ld [chr_id], a
            ld a, CHARS
            call sbank
            ld a, [chr_id]
            add a, $40
            ld h, a
            ld l, 0
            ld a, 1
            ldh [rVBK], a
            ld de, $8000
            ld bc, 256
            call memcpy
            xor a
            ldh [rVBK], a
            ret

; the showing character's map graphics set (3E/DD2D): the first not dead / stone from SV $0E;
; toad $16, mini $17, else the job
char_id:    ld a, [SV + $0E]
            ld c, a
.l:         ld b, 0
            ld hl, SV + $102
            add hl, bc
            ld a, [hl]
            and $C0
            jr z, .ok
            ld a, c
            add a, $40
            ld c, a
            ld a, [SV + $0E]
            cp c
            jr nz, .l
.ok:        ld a, c
            ld [SV + $0E], a
            ld a, [hl]
            bit 5, a
            ld a, $16
            jr nz, .x
            ld a, [hl]
            bit 3, a
            ld a, $17
            jr nz, .x
            dec hl
            dec hl
            ld a, [hl]
.x:         and $3F
            ret

; the map's palettes (3A/8509 / 9091): BG 0-3 from the record, OBJ 0-3 the character's
load_pal:   ld hl, mrec + 32
            ld de, sh_pal
            ld bc, 32
            call memcpy
            ld a, COMMON
            call sbank
            ld a, [world]                   ; (the second half of the sprite palettes on world 4+)
            and 4
            rrca
            rrca
            add a, a
            add a, a
            add a, a
            ld b, a                         ; + $800 for the second half
            ld a, [chr_id]
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld a, h
            add a, b
            add a, high(C_SPAL)
            ld h, a
            ld de, pal_ob
            ld bc, 32
            call memcpy
            ld a, 1
            ld [pal_dirty], a
            ret

; ---- FF3 check player input (3F/E2F8): an event's command, else A (talk / look), then a direction
; (from the pad, or set by the event) -> facing, passability, the step
check_input:
            ld a, [z6C]
            and a
            jr nz, .ev
            ld a, [z24]                     ; A: npcs and treasures (3F/EA26)
            and a
            jp nz, a_button
            xor a                           ; (B / Start / Select: with the menus)
            ld [z25], a
            ld [z23], a
            ld [z22], a
.ev:        ld a, [z4B]                     ; (a map title showing: nothing)
            cp $FF
            ret nz
            call ev_step                    ; an event's command, or the joypad (3E/D219)
            ld a, [z6C]                     ; (an event started by it: the next frame)
            ld a, [z20]
            and $0F
            ret z
            ld c, a                         ; FF3: right, left, down, up first (3F/E4E9)
            bit 0, c
            ld a, 1
            jr nz, .one
            bit 1, c
            ld a, 2
            jr nz, .one
            bit 2, c
            ld a, 4
            jr nz, .one
            ld a, 8
.one:       ld [facing], a
            call passable
            ret c
            ld a, 1                         ; FF3 init player movement (3F/CA67)
            ld [moving], a
            xor a
            ld [mcount], a
            ld a, [facing]
            call dir_dxy
            ld a, b
            ld [mdx], a
            ld a, c
            ld [mdy], a
            jp draw_edge

; FF3 check npcs and treasures (3F/EA26): the npc ahead -> its event; else a chest / a locked door
a_button:   xor a
            ld [z24], a
            ld a, [facing]
            call dir_dxy
            ld a, [px]
            add a, b
            and 63
            ld [tx], a
            ld a, [py]
            add a, c
            and 63
            ld [ty], a
            call npc_ahead
            jp c, npc_event
            call chk_tres                   ; (3F/E917: a treasure / a locked door)
            push af
            ld a, [lay43]
            ld [t44], a
            pop af
            ret nc
            ld [z76], a                     ; (its dialogue: table $82)
            ld a, $82
            ld [z95], a
            xor a
            ld [z94], a
            ret

; FF3 execute npc event (3F/E9BB): the npc's trigger script (2C/8200, 2C/8400 off world 0); below
; $E0 its dialogue list and the conditional events; then the event
npc_event:  ld a, [lay43]
            ld [t44], a
            ld a, [hl]
            ld [Z + $A0], a
            ld de, $8200
            ld a, [world]
            and a
            jr z, .w
            ld de, $8400
.w:         ld a, [Z + $A0]
            call ts_load
            ld a, [Z + $A0]
            cp $E0
            ret nc                          ; (inns, shops, the Fat Chocobo: with the menus)
            call ts_npc
            ld a, [z6C]
            and a
            ret z
            jp ev_start

; A = facing bits -> B = dx, C = dy
dir_dxy:    ld bc, $0100
            rrca
            ret c
            ld b, $FF
            rrca
            ret c
            ld b, 0
            ld c, 1
            rrca
            ret c
            ld c, $FF
            ret

; FF3 check tile passability (3F/E396): carry clear if the party may step to the tile in front;
; sets FF3's $AB (trig) for exits / entrances / doors
passable:   ld a, [facing]                  ; the tile in facing direction (3F/E4E9)
            call dir_dxy
            ld a, [px]
            add a, b
            and 63
            ld [tx], a
            ld e, a
            ld a, [py]
            add a, c
            and 63
            ld [ty], a
            call npc_touch                  ; (an npc there: impassable; 3F/E3F1)
            jp c, .no
            ld a, [tx]
            ld e, a
            ld a, [ty]
            ld d, a
            call tile_props
            ld a, [t44]
            bit 7, a
            jr nz, .trig
.nt:        ld a, [t44]                     ; (3F/E3A5: an encounter tile: a random battle)
            bit 6, a
            call nz, enc_map
            ld a, [t44]                     ; (3F/E3B4)
            and 7
            jr z, .stairs
            cp 4
            jr nc, .ok                      ; (a bridge)
            cp 3
            jr z, .no
            ld b, a
            ld a, [zlev]
            or b
            cp 3
            jr z, .no                       ; (not the current z-level)
            ld [zlev], a
.ok:        and a
            ret
.stairs:    xor a
            ld [zlev], a
            ret
.no:        xor a                           ; impassable, no trigger
            ld [t45], a
            ld [trig], a
            ld a, [lay43]
            ld [t44], a
            scf
            ret
.trig:      ld a, [t45]                     ; the trigger type (3F/E3D0, table 3F/E669)
            swap a
            and $0F
            jr z, .exit_p
            dec a
            jr z, .exit_w
            sub 3
            jr z, .entr
            dec a
            jr z, .door
            dec a
            jr z, .locked
            cp $0C - 6
            jr c, .nt                       ; (2, 3, 7-B: no trigger)
            cp $0F - 6
            jr c, .blk                      ; (C-E: impassable)
            call ev_trigF                   ; (F: an event trigger, then the tile as any other)
            jp .nt
.exit_p:    ld a, $40
            jr .st
.exit_w:    ld a, $C0
            jr .st
.entr:      ld a, $80
.st:        ld [trig], a
            and a
            ret
.door:      call open_door                  ; (5: the door opens, then the entrance)
            jr .entr
.locked:    ld a, [SV + $21]                ; (6: only once unlocked)
            and $40
            jr z, .blk
            jr .door
.blk:       ld a, [lay43]
            ld [t44], a
            scf
            ret

; FF3 open door (3F/E6F2): the tile in front becomes the open door ($7E), drawn
open_door:  ld a, [tx]
            ld e, a
            ld a, [ty]
            ld d, a
            ld a, $7E
            call map_set
            ld a, [tx]
            ld e, a
            ld a, [ty]
            ld d, a
            jp q_mt

; A to the map at (E, D) (inside the 32 x 32)
map_set:    ld c, a
            ld a, e
            or d
            and $20
            ret nz
            ld a, d
            rrca
            rrca
            rrca
            ld b, a
            and $E0
            or e
            ld l, a
            ld a, b
            and 3
            add a, high(W_MAP)
            ld h, a
            ld a, 2
            ldh [rSVBK], a
            ld [hl], c
            ld a, 1
            ldh [rSVBK], a
            ret

; the step in progress (FF3 3F/E5EB): 16 frames a metatile, then the new position; the layer
; priority at the halfway point (3F/E900)
scroll_step:
            ld a, [moving]
            and a
            ret z
            ld a, [mcount]
            inc a
            ld [mcount], a
            cp 8
            call z, layer_pri
            ld a, [mcount]
            cp 16
            ret c
            ld a, [mdx]
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
            ret

; FF3 update sprite layer priority (3F/E900)
layer_pri:  ld a, [t44]
            bit 2, a
            jr z, .t
            ld a, [zlev]
            rrca
            jr nc, .t
            xor a
            ld [lay43], a
            ret
.t:         ld a, [t44]
            and $34
            ld [lay43], a
            ret

; FF3 execute trigger event (3F/E26A): exits / entrances (the map stack: FF3 keeps the map it came
; from and the position on the 6502 stack, 3F/E299)
do_trigger: ld a, [trig]
            ld b, a
            xor a
            ld [trig], a
            ld a, b
            cp $80
            jr z, .entr
            cp $40
            jr z, .back
            cp $20
            jr z, .bat
            ret                             ; ($C0: the world map: with it)
.bat:       ld a, [z6A]                     ; a battle (3F/E26E)
            call battle_run
            ld a, $FF
            ld [z4B], a
            ret
.entr:      ld a, [ms_n]
            cp MS_MAX
            ret nc
            ld l, a                         ; push x, y, map, world
            ld h, 0
            add hl, hl
            add hl, hl
            ld de, ms_buf
            add hl, de
            ld a, [px]
            ld [hl+], a
            ld a, [py]
            ld [hl+], a
            ld a, [cur_map]
            ld [hl+], a
            ld a, [facing]
            ld [hl], a
            ld hl, ms_n
            inc [hl]
            ld a, [t45]                     ; the destination: entrance id (3F/E2AF)
            and $0F
            ld e, a
            ld d, 0
            ld hl, W_TB
            add hl, de
            ld a, [hl]
            ld [cur_map], a
            xor a                           ; (from the "world map": the map's own entry point)
            jp load_map
.back:      ld a, [ms_n]                    ; exit to the previous map (3F/E2BC)
            and a
            ret z
            dec a
            ld [ms_n], a
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            ld de, ms_buf
            add hl, de
            ld a, [hl+]
            ld [px], a
            ld a, [hl+]
            ld [py], a
            ld a, [hl+]
            ld [cur_map], a
            ld a, [hl]
            ld [facing], a
            xor a
            ld [zlev], a
            ld a, $81
            jp load_map

; ---- the party sprite (FF3 3E/D8D3 / DA2B: the pose table, UL DL UR DR; the walking frame's
; one-pixel lift; the layer priority 3E/D9A7), at screen (72, 64)
make_oam:   ld a, 1
            ldh [oam_ok], a
            ld a, [z7E]                     ; (the player hidden by an event)
            bit 7, a
            jr z, .sh
            xor a
            ld [oam_buf], a
            ld [oam_buf + 4], a
            ld [oam_buf + 8], a
            ld [oam_buf + 12], a
            ret
.sh:
            ld a, COMMON
            call sbank
            ld a, [facing]                  ; pose offset by facing (3E/DC1A)
            ld e, a
            ld d, 0
            ld hl, C_POSEOFS
            add hl, de
            ld b, [hl]
            ld a, [mcount]                  ; the walking frame: subtile & 8
            and 8
            or b
            ld [pose], a
            ld e, a
            ld hl, C_POSE
            add hl, de
            ld bc, $5050                    ; B = y + 16, C = x + 8
            ld a, [pose]
            and 8
            jr z, .nb
            ld a, [mdy]                     ; (moving vertically: one pixel left; else up)
            and a
            jr z, .up
            dec c
            jr .nb
.up:        dec b
.nb:        ld de, oam_buf
            call .spr                       ; UL
            ld a, b
            add a, 8
            ld b, a
            call .spr                       ; DL
            ld a, b
            sub 8
            ld b, a
            ld a, c
            add a, 8
            ld c, a
            call .spr                       ; UR
            ld a, b
            add a, 8
            ld b, a
            call .spr                       ; DR
            ld a, [lay43]                   ; FF3 set sprite layer priority (3E/D9A7)
            and $24
            jr z, .lo
            ld hl, oam_buf + 4 + 3          ; (lower sprites: DL, DR)
            call .pri
            ld hl, oam_buf + 12 + 3
            call .pri
.lo:        ld a, [lay43]
            and $14
            ret z
            ld hl, oam_buf + 0 + 3          ; (upper: UL, UR)
            call .pri
            ld hl, oam_buf + 8 + 3
.pri:       ld a, [hl]
            xor $80
            ld [hl], a
            ret
.spr:       ld a, b
            ld [de], a
            inc de
            ld a, c
            ld [de], a
            inc de
            ld a, [hl+]                     ; the tile (VRAM bank 1: the map's sprite tiles)
            ld [de], a
            inc de
            ld a, [hl+]                     ; NES attributes -> GB: palette 0-3, bank 1, flip
            push bc                         ;   bit 6 -> 5, behind the BG bit 5 -> 7
            ld b, a
            and 3
            or $08
            ld c, a
            bit 6, b
            jr z, .f
            set 5, c
.f:         bit 5, b
            jr z, .p
            set 7, c
.p:         ld a, c
            pop bc
            ld [de], a
            inc de
            ret

; ---- scroll: the party's metatile at screen (72, 64) (FF1's)
set_scroll: ld a, [mcount]
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
            sub 67                          ; (the party's tile at line 67: FF3 draws people 3
            ldh [scy], a                    ;   pixels above their tile, the sprite at line 64)
            ret
mulsign:    and a                           ; A = sign (-1 / 0 / 1) -> A = sign * C
            ret z
            bit 7, a
            ld a, c
            ret z
            cpl
            inc a
            ret

; ---- drawing metatiles into the 32 x 32 BG ring (queued; written in V-Blank: FF1's)
draw_all:   xor a
            ld [de_n], a
            inc a
            ldh [q_nolim], a
            ld a, [py]
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
            xor a
            ldh [q_nolim], a
            ret

; the line of metatiles one beyond the one entering the view (FF1 de_line: drawn a whole step
; before it shows), queued over the step's frames by q_feed
draw_edge:  ld a, [mdx]
            and a
            jr z, .vert
            ld b, 7
            bit 7, a
            jr z, .h1
            ld b, $F9
.h1:        ld a, [px]
            add a, b
            ld e, a
            ld a, [py]
            sub 6
            ld d, a
            ld b, 13
            ld a, 1
            jr .st
.vert:      ld b, 6
            ld a, [mdy]
            bit 7, a
            jr z, .v1
            ld b, $FA
.v1:        ld a, [py]
            add a, b
            ld d, a
            ld a, [px]
            sub 7
            ld e, a
            ld b, 15
            xor a
.st:        ld [de_dir], a
            ld a, e
            ld [de_x], a
            ld a, d
            ld [de_y], a
            ld a, b
            ld [de_n], a
            ret

q_feed:     ld c, 1
.l:         ld a, [de_n]
            and a
            ret z
            dec a
            ld [de_n], a
            push bc
            ld a, [de_x]
            ld e, a
            ld a, [de_y]
            ld d, a
            call q_mt
            ld hl, de_x
            ld a, [de_dir]
            add a, l
            ld l, a
            inc [hl]
            pop bc
            dec c
            jr nz, .l
            ret

; queue metatile (E = x, D = y), coordinates mod 64; entry: VRAM address, UL UR DL DR, palette
q_mt:       ld a, e
            and 63
            ld e, a
            ld a, d
            and 63
            ld d, a
            ld a, [q_rd]                    ; full: dropped
            ld b, a
            ld a, [q_n]
            inc a
            cp b
            ret z
            push de
            call map_at
            pop de
            ld c, a
            ld a, [q_n]                     ; HL = qbuf + 8 n
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            ld a, h
            add a, high(qbuf)
            ld h, a
            ld a, d                         ; $9800 + 32 (2y & 31) + (2x & 31)
            add a, a
            and 31
            ld b, a
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
            ld a, 2                         ; the corner tiles and palette (WRAM bank 2)
            ldh [rSVBK], a
            ld e, c
            ld d, high(W_UL)
            ld a, [de]
            ld [hl+], a
            inc d
            ld a, [de]
            ld [hl+], a
            inc d
            ld a, [de]
            ld [hl+], a
            inc d
            ld a, [de]
            ld [hl+], a
            ld d, high(W_PAL)
            ld a, [de]
            and 3
            ld [hl], a
            ld a, 1
            ldh [rSVBK], a
            ld hl, q_n
            inc [hl]
            ret

; write up to C queued metatiles to VRAM (V-Blank, LY 144-151; or the LCD off)
q_flush:    ld a, [q_n]
            ld b, a
            ld a, [q_rd]
            cp b
            ret z
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            ld a, h
            add a, high(qbuf)
            ld h, a
.e:         ldh a, [q_nolim]
            and a
            jr nz, .go
            ldh a, [rLY]
            sub 144
            cp 8
            ret nc
.go:        ld a, [hl+]
            ld e, a
            ld a, [hl+]
            ld d, a
            push de
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            ld a, e
            add a, 31
            ld e, a
            jr nc, .c1
            inc d
.c1:        ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            ld b, [hl]
            inc hl
            inc hl
            pop de
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
            ld a, [q_rd]
            inc a
            ld [q_rd], a
            jr nz, .w
            ld hl, qbuf
.w:         ld b, a
            ld a, [q_n]
            cp b
            ret z
            dec c
            jr nz, .e
            ret

; ---- the LCD: off only in V-Blank; on after a load (the palettes up first)
lcd_off:    ldh a, [rLCDC]
            bit 7, a
            ret z
            xor a
            ldh [oam_ok], a
.w:         ldh a, [rLY]
            cp 145
            jr c, .w
            cp 153
            jr nc, .w
            xor a
            ldh [rLCDC], a
            ret
lcd_on:     push af
            ld a, 1                         ; (the palettes: from the shadows, LCD off)
            ld [pal_dirty], a
            di
            ld a, $80
            ldh [rBCPS], a
            ld hl, sh_pal
            ld c, low(rBCPD)
            ld b, 64
.b:         ld a, [hl+]
            ldh [c], a
            dec b
            jr nz, .b
            ld a, $80
            ldh [rOCPS], a
            ld c, low(rOCPD)
            ld b, 64
.o:         ld a, [hl+]
            ldh [c], a
            dec b
            jr nz, .o
            xor a
            ld [pal_dirty], a
            call hram_dma
            ei
            pop af
            ldh [rLCDC], a
            ret

; ---- banks
sbank:      ldh [rombank], a
            ldh [mapbank], a
            ld [MBC_BANK], a
            ret
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

; ---- helpers (FF1's)
memclr:     xor a
            ld [hl+], a
            dec de
            ld a, d
            or e
            jr nz, memclr
            ret
memcpy:     ld a, b
            or c
            ret z
.l:         ld a, [hl+]
            ld [de], a
            inc de
            dec bc
            ld a, b
            or c
            jr nz, .l
            ret
dma_rom:    ld a, high(oam_buf)
            ldh [rDMA], a
            ld a, 40
.w:         dec a
            jr nz, .w
            ret
dma_end:

; ---- not a Game Boy Color: FF3 is a Color-only Game Pak (Lot Check: a message on older systems)
not_cgb:    ldh a, [rLCDC]
            bit 7, a
            jr z, .h
.w:         ldh a, [rLY]
            cp 144
            jr c, .w
            xor a
            ldh [rLCDC], a
.h:         halt
            jr .h

section wram, $C000
oam_buf:    ds 256
qbuf:       ds 2048
section wram, $C900
px:         ds 1
py:         ds 1
tx:         ds 1
ty:         ds 1
moving:     ds 1
mcount:     ds 1
mdx:        ds 1
mdy:        ds 1
q_n:        ds 1
q_rd:       ds 1
de_x:       ds 1
de_y:       ds 1
de_n:       ds 1
de_dir:     ds 1
tr88:       ds 1
tr89:       ds 1
chr_id:     ds 1
pose:       ds 1
pal_dirty:  ds 1
ms_n:       ds 1
ms_buf:     ds 4 * MS_MAX
section wram, $CA00                         ; (TS7B at $C980: event.s)
sh_pal:     ds 64                           ; the Color's BG palettes (shadow)
pal_ob:     ds 64                           ; OBJ
mrec:       ds 128                          ; the map's record (port.py)

section hram, $FF80
hram_dma:   ds 10
vbl_done:   ds 1
pad:        ds 1
pad_new:    ds 1
scx:        ds 1
scy:        ds 1
rombank:    ds 1
frame:      ds 1
q_nolim:    ds 1
oam_ok:     ds 1
