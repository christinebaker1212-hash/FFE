; FF3 normal maps on the Game Boy Color: a map drawn into the BG ring, the party walking on it.
; Written from FF3's field code as the listing describes it ($3E $CDA3 init player movement,
; $3F $E5EB update player movement, $3E $C65D check destination tile, $3E $D8D3 player sprite).
;
; Data banks (tools/gb3n/build.py, all from the user's ROM):
;   B_MAPINFO $4000 map properties (512 x 16)       $6000 tilesets (7 x 1 KB: UL, UR, DL, DR,
;             palette, property 1, property 2; 128 each)     $7C00 trigger base tiles (128)
;             $7C80 trigger type per tile $60-$7F    $7CA0 first metatile per tile $60-$7F
;             $7CC0 window palette (NES)             $7D00 NES colour -> RGB555 (64 x 2)
;   B_MAPAUX  $4000 general palettes (3 x 256)      $4300 tilemap id per map (512)
;             $4500 graphics subset per map (512)    $4700 map sprite palettes (32)
;             $4720 map character palettes (26 x 4)  $4800 tilemap streams (bank, addr) x 256
;             $4B00 graphics subsets (bank, addr)    $4C00 exit x (64), $4C40 exit y (64)
;             $4D00 the player sprite poses (64)
;   B_EVENTS  NES bank $10 (entrances, treasures, triggers): NES $A000-$BFFF -> $4000-$5FFF
;   B_CHARS   map character graphics, 64 sets of 16 tiles (Game Boy format)
;   B_COMMON  the menu window / text tiles (144, loaded at BG tile $70)
;
; Work RAM: the map ($C400, 32 x 32) and the metatile tables for metatiles 0-255 ($C800 UL,
; $C900 UR, $CA00 DL, $CB00 DR, $CC00 palette, $CD00 property 1, $CE00 property 2): trigger
; tiles get metatiles $80-$FF at load, as FF3 does ($3A $91C8 init trigger).

W_MAP      = $C400
W_UL       = $C8
W_UR       = $C9
W_DL       = $CA
W_DR       = $CB
W_ATTR     = $CC
W_PROP1    = $CD
W_PROP2    = $CE
I_PROPS    = $4000
I_TSETS    = $6000
I_TBASE    = $7C00
I_TTYPE    = $7C80
I_TFIRST   = $7CA0
I_WINPAL   = $7CC0
I_RGB      = $7D00
A_GPAL     = $4000
A_TMID     = $4300
A_GSUB     = $4500
A_SPAL     = $4700
A_CPAL     = $4720
A_TMAPS    = $4800
A_SUBS     = $4B00
A_EXITX    = $4C00
A_EXITY    = $4C40
A_POSE     = $4D00
VIEW_X     = 4              ; the party's metatile column / row on screen (10 x 9 visible)
VIEW_Y     = 4
DIR_R      = 1              ; facing (FF3's ----udlr)
DIR_L      = 2
DIR_D      = 4
DIR_U      = 8
TR_PREV    = $40            ; pending triggers (FF3's $AB)
TR_ENTER   = $80
TR_WORLD   = $C0
TR_WENT    = $A0              ; a world map entrance (after the step)
SCRATCH    = $DA00            ; work RAM bank 1: data staged from ROM banks (768 bytes: the longest
                            ;   tilemap stream is 728); bank 1 map: $D000 save page, $D400 / $D500
                            ;   people, $D600 text, $DA00 scratch, $DD00 music, $DE00 people poses,
                            ;   $DF00 palettes, $DF80 player poses
MAP_DEPTH  = 8              ; entrances within entrances (FF3 recurses on its stack)

section bank B_FIELD, $4000

; ---- load map `map_id` of `world` (LCD off) and show it: FF3's load map ($3F $E7EC: map
; properties, tileset, tilemap, triggers, palettes, graphics); the party at (enter_x, enter_y),
; or at the map's start position when enter_x = $FF
map_enter:  ld a, 63
            ld [cmask], a
            ld a, [wmode]
            and a
            jp nz, world_enter
            ld a, [map_id]                  ; properties: index map + 256 if world != 0
            ld l, a
            ld a, [world]
            and a
            ld h, 0
            jr z, .p0
            inc h
.p0:        add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld a, h
            add high(I_PROPS)
            ld h, a
            ld de, map_props
            ld bc, 16
            ld a, B_MAPINFO
            call far_copy
            ld a, [map_props]               ; tileset (top 3 bits): 7 pages of 128 into the
            swap a                          ;   metatile tables 0-127
            rra
            and 7
            add a
            add a
            add high(I_TSETS)
            ld h, a
            ld l, 0
            ld d, W_UL
            ld c, 7
.ts:        push bc
            ld e, 0
            ld bc, 128
            ld a, B_MAPINFO
            call far_copy
            inc d
            pop bc
            dec c
            jr nz, .ts
            ld hl, I_TBASE                  ; metatiles $80-$FF copy their base tile ($3A $92D9)
            ld de, SCRATCH
            ld bc, 128
            ld a, B_MAPINFO
            call far_copy
            ld c, 0
.tb:        ld h, high(SCRATCH)
            ld a, c
            ld l, a
            ld b, [hl]                      ; B = base tile
            ld d, W_UL
.tp:        ld h, d
            ld l, b
            ld a, [hl]
            ld l, c
            set 7, l
            ld [hl], a
            inc d
            ld a, d
            cp W_PROP2 + 1
            jr nz, .tp
            inc c
            bit 7, c
            jr z, .tb
            ld a, [map_id]                  ; tilemap and graphics subset: index map + 256 if
            ld l, a                         ;   world >= 2
            ld h, 0
            ld a, [world]
            cp 2
            jr c, .t0
            inc h
.t0:        push hl
            ld de, A_TMID
            add hl, de
            ld a, B_MAPAUX
            call far_byte                   ; tilemap id -> (bank, address)
            ld l, a
            ld h, 0
            ld e, l
            ld d, h
            add hl, hl
            add hl, de
            ld de, A_TMAPS
            add hl, de
            ld de, tm_src
            ld bc, 3
            ld a, B_MAPAUX
            call far_copy
            pop hl
            ld de, A_GSUB
            add hl, de
            ld a, B_MAPAUX
            call far_byte                   ; graphics subset -> (bank, address)
            ld l, a
            ld h, 0
            ld e, l
            ld d, h
            add hl, hl
            add hl, de
            ld de, A_SUBS
            add hl, de
            ld de, gs_src
            ld bc, 3
            ld a, B_MAPAUX
            call far_copy
            call pal_gather                 ; NES colours of the 4 BG + 2 sprite palettes
            call map_lists                  ; entrances, treasures, triggers (bank B_EVENTS)
            call map_unpack                 ; the tilemap into W_MAP
            call map_triggers               ; trigger tiles -> metatiles $80-$FF
            call pal_load                   ; Color palettes (LCD off)
            xor a                           ; BG tiles ($8800 mode): the subset at $00 ($9000),
            ldh [rVBK], a                   ;   the menu tiles at $70 ($9700) and $80 ($8800)
            ld a, [gs_src + 1]
            ld l, a
            ld a, [gs_src + 2]
            ld h, a
            ld de, $9000
            ld bc, 112 * 16
            ld a, [gs_src]
            call far_copy
            ld hl, $4000
            ld de, $9700
            ld bc, 16 * 16
            ld a, B_COMMON
            call far_copy
            ld de, $8800
            ld bc, 128 * 16
            ld a, B_COMMON
            call far_copy
            ld a, [char_set]                ; the walking character's tiles: VRAM bank 1 $8000
            and $3F
            add $40
            ld h, a
            ld l, 0
            ld a, 1
            ldh [rVBK], a
            ld de, $8000
            ld bc, $100
            ld a, B_CHARS
            call far_copy
            xor a
            ldh [rVBK], a
            call npc_load                   ; the people (their tiles: VRAM bank 1 from tile 16)
            ld hl, A_POSE                   ; FF3's player poses
            ld de, poses
            ld bc, 64
            ld a, B_MAPAUX
            call far_copy
            ld a, [enter_x]                 ; the position
            cp $FF
            jr nz, .pos
            ld a, [map_props]
            and 31
            ld [pos_x], a
            ld a, [map_props + 1]
            and 31
            ld [pos_y], a
            ld a, DIR_D                     ; (FF3 $3F $E85D: facing down at a map's start)
            ld [facing], a
            jr .pd
.pos:       ld [pos_x], a
            ld a, [enter_y]
            ld [pos_y], a
.pd:        xor a
            ld [step], a
            ld [line_n], a
            ld [z_lev], a
            ld [trig], a
            ld [dlg_on], a                  ; (a running event goes on in the new map, as FF3's)
            ld a, [facing]
            and a
            jr nz, .fc
            ld a, DIR_D
            ld [facing], a
.fc:        call cam_set
            ld c, 0                         ; the 16 rows of the ring, a row at a time
.row:       push bc
            ld a, [cam_y]
            add c
            ld e, a
            ld a, [cam_x]
            ld d, a
            call line_row
            call line_flush
            pop bc
            inc c
            ld a, c
            cp 16
            jr nz, .row
            call scroll_set
            call party_oam
            call npc_oam
            ld a, [pos_x]                   ; the cell under the party ($3F $E87B): its z-level;
            ld d, a                         ;   an event trigger there runs now
            ld a, [pos_y]
            ld e, a
            call map_mt
            ld c, a
            ld b, W_PROP1
            ld a, [bc]
            ld l, a
            and 3
            ld [z_lev], a
            bit 7, l
            ret z
            inc b
            ld a, [bc]
            cp $F0
            ret c
            and 15
            jp trig_event

; entrance / treasure / trigger lists (16 bytes each) from bank B_EVENTS ($3A $9350-$93C0):
; entrances at properties bytes 12-13, treasures and triggers through the pointer tables at
; NES $A000 / $A200 by properties bytes 14 / 15
map_lists:  ld a, [map_props + 12]
            ld l, a
            ld a, [map_props + 13]
            call ev_addr
            ld de, ents
            ld bc, 16
            ld a, B_EVENTS
            call far_copy
            ld a, [map_props + 14]
            ld hl, $4000
            call ev_table
            ld de, treas
            ld bc, 16
            ld a, B_EVENTS
            call far_copy
            ld a, [map_props + 15]
            ld hl, $4200
            call ev_table
            ld de, trigs
            ld bc, 16
            ld a, B_EVENTS
            jp far_copy
ev_table:   ld e, a                         ; HL = table, A = index: HL = its pointer's target
            ld d, 0
            add hl, de
            add hl, de
            ld de, ptr_tmp
            ld bc, 2
            ld a, B_EVENTS
            call far_copy
            ld a, [ptr_tmp]
            ld l, a
            ld a, [ptr_tmp + 1]
ev_addr:    and $1F                         ; NES pointer (L, A) -> $4000 + (ptr & $1FFF)
            add $40
            ld h, a
            ret

; the tilemap's RLE stream into W_MAP ($3E $CBFA: a byte < $80 is a metatile; $80 | v and a
; run length follow, 0 meaning 256)
map_unpack: ld a, [tm_src + 1]               ; (the stream into SCRATCH: up to 1 KB, not past
            ld l, a                         ;   the bank's end)
            ld a, [tm_src + 2]
            ld h, a
            ld a, l
            cpl
            ld c, a
            ld a, h
            cpl
            and $7F
            ld b, a
            inc bc                          ; BC = $8000 - HL
            ld a, b
            cp 3
            jr c, .sz
            ld bc, $300
.sz:        ld de, SCRATCH
            ld a, [tm_src]
            call far_copy
            ld hl, SCRATCH
            ld de, W_MAP
.n:         ld a, d
            cp high(W_MAP) + 4
            ret nc
            ld a, [hl+]
            bit 7, a
            jr nz, .run
            ld [de], a
            inc de
            jr .n
.run:       and $7F
            ld c, a
            ld b, [hl]
            inc hl
.r:         ld a, c
            ld [de], a
            inc de
            ld a, d
            cp high(W_MAP) + 4
            ret nc
            dec b
            jr nz, .r
            jr .n

; trigger tiles ($60-$63, $70-$7C) become metatiles $80-$FF ($3A $91A0 / $91C8): each gets
; first[tile] + its count for that tile; property 2 gets the trigger's number within its type
map_triggers:
            ld hl, trig_cnt
            ld b, 40
            xor a
.cl:        ld [hl+], a
            dec b
            jr nz, .cl
            ld hl, I_TTYPE                  ; type / first metatile tables into SCRATCH
            ld de, SCRATCH
            ld bc, 64
            ld a, B_MAPINFO
            call far_copy
            ld hl, W_MAP
.c:         ld a, [hl]
            sub $60
            jr c, .nx
            cp 4
            jr c, .tr
            cp $10
            jr c, .nx
            cp $1D
            jr nc, .nx
.tr:        push hl
            ld e, a                         ; E = tile - $60
            ld d, 0
            ld hl, trig_cnt
            add hl, de
            ld a, [hl]                      ; this tile's count
            inc [hl]
            ld b, a
            ld hl, SCRATCH
            add hl, de
            ld a, [hl]                      ; type
            ld hl, type_cnt
            add a, l
            ld l, a
            ld a, [hl]                      ; the trigger's number in its type
            inc [hl]
            ld c, a
            ld hl, SCRATCH + 32
            add hl, de
            ld a, [hl]
            add b                           ; the new metatile
            ld b, a
            ld a, e                         ; (treasure chests: opened ones show $7D; the
            cp $1C                          ;   switches come with the game state: later)
            ld a, b
            jr z, .st
            ld h, W_PROP2
            ld l, a
            ld a, [hl]
            or c
            ld [hl], a
            ld a, l
.st:        pop hl
            ld [hl], a
.nx:        inc hl
            ld a, h
            cp high(W_MAP) + 4
            jr nz, .c
            ret

; the NES colours of BG palettes 0-3 and sprite palettes 0-1 into nes_pal ($3A $9091): BG
; 0-2 colours 1-3 from the general palettes by properties bytes 5-7, colour 0 black; BG 3 the
; window; sprites from the map sprite palettes with the walking character's colours 2-3
pal_gather: ld de, nes_pal
            ld hl, map_props + 5
            ld c, 3
.p:         ld a, $0F
            ld [de], a
            inc de
            ld a, [hl+]
            push hl
            push bc
            ld l, a
            ld h, high(A_GPAL)
            ld b, 3
.c3:        ld a, B_MAPAUX
            call far_byte
            ld [de], a
            inc de
            inc h
            dec b
            jr nz, .c3
            pop bc
            pop hl
            dec c
            jr nz, .p
            call pal_spr
            ld hl, I_WINPAL                 ; BG palette 3 on normal maps: the window colours
            ld de, nes_pal + 12
            ld bc, 4
            ld a, B_MAPINFO
            jp far_copy
pal_spr:    ld a, [world]                   ; sprite palettes: 00/9670 + (world & 4) * 4
            and 4
            add a
            add a
            add low(A_SPAL)
            ld l, a
            ld h, high(A_SPAL)
            ld de, nes_pal + 16
            ld bc, 16
            ld a, B_MAPAUX
            call far_copy
            ld a, [char_pal]                ; colours 2-3 of each from the character palette
            add a
            add a
            add low(A_CPAL)
            ld l, a
            ld a, high(A_CPAL)
            adc 0
            ld h, a
            ld de, ptr_tmp
            ld bc, 4
            ld a, B_MAPAUX
            call far_copy
            ld a, [ptr_tmp]
            ld [nes_pal + 18], a
            ld a, [ptr_tmp + 1]
            ld [nes_pal + 19], a
            ld a, [ptr_tmp + 2]
            ld [nes_pal + 22], a
            ld a, [ptr_tmp + 3]
            ld [nes_pal + 23], a
            ret

; nes_pal -> cgb_pal (RGB555: BG palettes 0-3, OBJ palettes 0-3), shown by pal_apply
pal_load:   ld hl, I_RGB                    ; (the NES colour table into SCRATCH)
            ld de, SCRATCH
            ld bc, 128
            ld a, B_MAPINFO
            call far_copy
            ld hl, I_WINPAL                 ; the window's NES colours
            ld de, win_nes
            ld bc, 4
            ld a, B_MAPINFO
            call far_copy
            ld hl, nes_pal
            ld de, cgb_pal
            ld b, 36                        ; (nes_pal and win_nes are adjacent)
.c:         ld a, [hl+]
            and $3F
            add a
            push hl
            ld l, a
            ld h, high(SCRATCH)
            ld a, [hl+]
            ld [de], a
            inc de
            ld a, [hl]
            ld [de], a
            inc de
            pop hl
            dec b
            jr nz, .c
            ret

; ---- one field frame (after the frame wait): V-Blank work, then the walking
field_vbl:  ld a, [frame]
            inc a
            ld [frame], a
            call dlg_vbl
            call dlg_lcdc
            ld a, [line_n]                  ; a pending row / column into the ring
            and a
            call nz, line_flush
            call scroll_set
            jp hram_dma

field_step: call npc_update
            ld a, [step]
            and a
            jr nz, .walk
            ld a, [trig]                    ; a trigger stepped on: act now ($3F $E217)
            and a
            jp nz, trig_run
            ld a, [dlg_on]                  ; the dialogue box: nothing else moves
            and a
            jr z, .nd
            call dlg_step
            jr .done
.nd:        ld a, [ev_on]                   ; an event: its commands (a party step as the pad)
            and a
            jr z, .pl
            xor a
            ld [ev_pad], a
            call ev_step
            ld a, [ev_pad]
            and a
            jr z, .done
            ld b, a
            jr .dir
.pl:        ldh a, [pad_new]                ; A: talk to the person ahead
            and PAD_A
            jr z, .pd
            call talk
            jr .done
.pd:        ldh a, [pad]                    ; a direction held: FF3's order right, left, down, up
            ld b, DIR_R
            bit 4, a
            jr nz, .dir
            ld b, DIR_L
            bit 5, a
            jr nz, .dir
            ld b, DIR_D
            bit 7, a
            jr nz, .dir
            ld b, DIR_U
            bit 6, a
            jr z, .done
.dir:       ld a, b
            ld [facing], a
            call dest_cell                  ; D, E = the metatile ahead
            call npc_at                     ; a person there (FF3 $3F $E399)
            jr c, .done
            call map_mt
            call passable
            jr c, .done
            call edge_line                  ; the row / column coming into view
            ld a, 1
            ld [step], a
            jr .done
.walk:      inc a                           ; a pixel a frame, 16 to a step
            ld [step], a
            cp 17
            jr nz, .done
            xor a
            ld [step], a
            call dest_cell
            ld a, d
            ld [pos_x], a
            ld a, e
            ld [pos_y], a
            call cam_set
            ld a, [trig_next]               ; the step's trigger is due
            ld [trig], a
.done:      call party_oam
            jp npc_oam

; a trigger after the step ($3F $E26A): entrance (to the map in the entrance list), back to the
; previous map, or out to the world map (the world map: later; for now back as from an exit)
trig_run:   ld b, a
            xor a
            ld [trig], a
            ld a, b
            cp TR_BATTLE
            jp z, battle_run
            cp TR_WENT
            jp z, world_in
            cp TR_WORLD
            jp z, world_exit
            cp TR_ENTER
            jr z, .ent
            ld a, [map_sp]                  ; to the previous map; from the first map: the world
            and a                           ;   map where the party stood ($3E $C1DC)
            jp z, world_back
            dec a
            ld [map_sp], a
            ld l, a
            add a
            add l
            add low(map_stack)
            ld l, a
            ld h, high(map_stack)
            ld a, [hl+]
            ld [map_id], a
            ld a, [hl+]
            ld [enter_x], a
            ld a, [hl]
            ld [enter_y], a
            jr .go
.ent:       ld a, [map_sp]                  ; push where we stand, enter the new map
            cp MAP_DEPTH
            ret nc
            ld l, a
            inc a
            ld [map_sp], a
            ld a, l
            add a
            add l
            add low(map_stack)
            ld l, a
            ld h, high(map_stack)
            ld a, [map_id]
            ld [hl+], a
            ld a, [pos_x]
            ld [hl+], a
            ld a, [pos_y]
            ld [hl], a
            ld a, [trig_id]
            and 15
            ld l, a
            ld h, 0
            ld de, ents
            add hl, de
            ld a, [hl]
            ld [map_id], a
            ld a, $FF
            ld [enter_x], a
.go:        jp map_change

; D, E = the cell ahead of the party (coordinates wrap at 64, as FF3's AND $3F)
dest_cell:  ld a, [pos_x]
            ld d, a
            ld a, [pos_y]
            ld e, a
            ld a, [facing]
            rra
            jr c, .r
            rra
            jr c, .l
            rra
            jr c, .d
            dec e
            jr .m
.r:         inc d
            jr .m
.l:         dec d
            jr .m
.d:         inc e
.m:         ld a, [cmask]                   ; (63 on normal maps, 255 on the world map)
            and d
            ld d, a
            ld a, [cmask]
            and e
            ld e, a
            ret

; can the party step onto metatile A? carry set if not ($3F $E396 check tile passability).
; Property 1 bit 7: a trigger, by property 2's high nibble ($3F $E669): 0 previous map,
; 1 world map, 4 entrance, 5 door, 6 locked door (no key: blocked), C-E impassable, F event
; (scripts: later), others as a plain tile. Plain tiles: the low three bits 0 stairs (z
; cleared), 4+ a bridge, 3 impassable, 1 / 2 a level: impassable when it and the current level
; z make 3, else z becomes it.
passable:   ld c, a
            xor a
            ld [trig_next], a
            ld a, [wmode]
            and a
            jp nz, world_pass
            ld b, W_PROP1
            ld a, [bc]
            bit 7, a
            jr z, .plain
            inc b
            ld a, [bc]                      ; property 2: type, id
            ld [trig_id], a
            swap a
            and 15
            jr z, .prev
            dec a
            jr z, .world
            cp 3
            jr z, .ent
            cp 4
            jr z, .ent
            cp 5
            jr z, .no
            cp 14                           ; F: an event trigger, then the tile as plain
            jr z, .evt
            cp 11
            jr nc, .no
            dec b
            ld a, [bc]
            jr .plain
.evt:       push bc
            ld a, [trig_id]
            and 15
            call trig_event
            pop bc
            dec b
            ld a, [bc]
            jr .plain
.prev:      ld a, TR_PREV
            jr .tok
.world:     ld a, TR_WORLD
            jr .tok
.ent:       ld a, TR_ENTER
.tok:       ld [trig_next], a
            and a
            ret
.plain:     bit 6, a                        ; an encounter tile ($3F $E3A5)
            call nz, enc_map
            and 7
            jr z, .st
            cp 4
            jr nc, .ok
            cp 3
            jr z, .no
            ld b, a
            ld a, [z_lev]
            or b
            cp 3
            jr z, .no
            ld [z_lev], a
.ok:        and a
            ret
.st:        xor a
            ld [z_lev], a
            ret
.no:        scf
            ret

cam_set:    ld a, [pos_x]
            sub VIEW_X
            ld [cam_x], a
            ld a, [pos_y]
            sub VIEW_Y
            ld [cam_y], a
            ret

; SCX / SCY: the camera's ring position plus the step's pixels in the facing direction
scroll_set: ld a, [step]
            and a
            jr z, .s0
            dec a
.s0:        ld b, a                         ; B = pixels walked (0-15)
            ld a, [cam_x]
            swap a
            and $F0
            ld c, a
            ld a, [cam_y]
            swap a
            and $F0
            ld d, a
            ld a, [facing]
            rra
            jr c, .r
            rra
            jr c, .l
            rra
            jr c, .d
            ld a, d                         ; up
            sub b
            ld d, a
            jr .w
.r:         ld a, c
            add b
            ld c, a
            jr .w
.l:         ld a, c
            sub b
            ld c, a
            jr .w
.d:         ld a, d
            add b
            ld d, a
.w:         ld a, c
            ldh [rSCX], a
            ld a, d
            ldh [rSCY], a
            ret

; queue the row / column entering the view for the step just started
edge_line:  ld a, [cam_x]
            ld d, a
            ld a, [cam_y]
            ld e, a
            ld a, [facing]
            rra
            jr c, .r
            rra
            jr c, .l
            rra
            jr c, .d
            dec e                           ; up: the row above
            jp line_row
.d:         ld a, e
            add 9
            ld e, a
            jp line_row
.r:         ld a, d
            add 10
            ld d, a
            jp line_col
.l:         dec d
            jp line_col

; build the 16 cells of the row at map y = E from x = D (line_row) or the column at x = D from
; y = E (line_col) into line_buf: per cell its BG map address, 4 tiles and the palette
line_row:   ld a, 1
            jr line_go
line_col:   xor a
line_go:    ld [line_dir], a
            ld hl, line_buf
            ld b, 16
.c:         push bc
            push hl
            call map_mt
            pop hl
            push de
            call cell_buf
            pop de
            ld a, [line_dir]
            and a
            jr z, .y
            inc d
            jr .n
.y:         inc e
.n:         pop bc
            dec b
            jr nz, .c
            ld a, 16
            ld [line_n], a
            ret

; A = the metatile at map (D, E) (0-63; outside the 32 x 32 map: the fill metatile)
map_mt:     ld a, [wmode]
            and a
            jp nz, world_mt
            ld a, d
            or e
            and $20
            jr z, .in
            ld a, [map_props + 3]
            ret
.in:        ld a, e
            and 31
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld a, d
            and 31
            add l
            ld l, a
            ld a, h
            adc high(W_MAP)
            ld h, a
            ld a, [hl]
            ret

; metatile A at map (D, E) -> 7 bytes at HL: BG map address (lo, hi), UL, UR, DL, DR, palette
cell_buf:   ld c, a
            push hl
            ld a, e                         ; $9800 + 64 * (y & 15) + 2 * (x & 15)
            and 15
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld a, d
            and 15
            add a
            add l
            ld e, a
            ld a, h
            adc $98
            ld d, a
            pop hl
            ld a, e
            ld [hl+], a
            ld a, d
            ld [hl+], a
            ld b, W_UL
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
            ld a, [bc]
            ld [hl+], a
            ret

; write line_buf's cells into the BG map (in V-Blank or with the LCD off)
line_flush: ld hl, line_buf
            ld a, [line_n]
            ld b, a
.c:         ld a, [hl+]
            ld e, a
            ld a, [hl+]
            ld d, a
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            ld a, e
            add 31
            ld e, a
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            ld a, [hl+]                     ; the palette, VRAM bank 1
            ld c, a
            ld a, 1
            ldh [rVBK], a
            ld a, c
            ld [de], a
            dec e
            ld [de], a
            ld a, e
            sub 32
            ld e, a
            ld a, c
            ld [de], a
            inc e
            ld [de], a
            xor a
            ldh [rVBK], a
            dec b
            jr nz, .c
            xor a
            ld [line_n], a
            ret

; the walking character into OAM entries 0-3
party_oam:  ld a, [step]                    ; the pose: facing, and the second frame from
            and a                           ;   pixel 8 of a step (FF3: fine scroll & 8)
            jr z, .f0
            dec a
.f0:        and 8
            ld b, a
            ld a, [facing]
            ld c, $00
            rra
            jr c, .p
            ld c, $10
            rra
            jr c, .p
            ld c, $30
            rra
            jr c, .p
            ld c, $20
.p:         ld a, c
            or b
            add low(poses)
            ld l, a
            ld a, high(poses)
            adc 0
            ld h, a
            ld d, VIEW_X * 16 + 8           ; D = x, E = y (OAM: +8 / +16)
            ld e, VIEW_Y * 16 + 16
            ld a, b                         ; FF3: the second frame bobs a pixel (up, or left
            and a                           ;   while walking up / down)
            jr z, .nb
            ld a, [facing]
            and DIR_U | DIR_D
            jr z, .bu
            dec d
            jr .nb
.bu:        dec e
.nb:        ld bc, oam_buf
            call .spr                       ; UL
            ld a, e
            add 8
            ld e, a
            call .spr                       ; DL
            ld a, e
            sub 8
            ld e, a
            ld a, d
            add 8
            ld d, a
            call .spr                       ; UR
            ld a, e
            add 8
            ld e, a
.spr:       ld a, e                         ; one 8 x 8 part: y, x, tile, attributes
            ld [bc], a
            inc c
            ld a, d
            ld [bc], a
            inc c
            ld a, [hl+]
            ld [bc], a
            inc c
            ld a, [hl+]
            call oam_attr
            ld [bc], a
            inc c
            ret

; NES sprite attributes A -> Color: palette (bits 0-1), flip H ($40 -> $20), behind BG
; ($20 -> $80), tiles in VRAM bank 1
oam_attr:   push de
            ld d, a
            and 3
            or $08
            ld e, a
            ld a, d
            and $40
            rra
            or e
            ld e, a
            ld a, d
            and $20
            add a
            add a
            or e
            pop de
            ret

; the LCD off in V-Blank (Lot Check) / back on
lcd_off:    ldh a, [rLCDC]
            bit 7, a
            ret z
.w:         ldh a, [rLY]
            cp 144
            jr c, .w
            xor a
            ldh [rLCDC], a
            ret
lcd_on:     ld a, LCDC_ON
            ldh [rLCDC], a
            ret


section wram, $C000
oam_buf:    ds 160
section wram, $C100
map_id:     ds 1
world:      ds 1
enter_x:    ds 1
enter_y:    ds 1
pos_x:      ds 1
pos_y:      ds 1
cam_x:      ds 1
cam_y:      ds 1
facing:     ds 1
step:       ds 1                            ; 0 standing, 1-16 walking (pixels + 1)
line_n:     ds 1                            ; cells pending in line_buf
line_dir:   ds 1
z_lev:      ds 1                            ; FF3's $A5: the z-level walked on (0 both)
trig:       ds 1                            ; a trigger to act on (FF3's $AB)
trig_next:  ds 1                            ; the trigger of the step under way
trig_id:    ds 1                            ; its property 2
char_set:   ds 1                            ; the walking character's graphics set
char_pal:   ds 1                            ;   and palette
map_sp:     ds 1
tm_src:     ds 3
gs_src:     ds 3
ptr_tmp:    ds 4
map_props:  ds 16
ents:       ds 16
treas:      ds 16
trigs:      ds 16
nes_pal:    ds 32
win_nes:    ds 4
trig_cnt:   ds 32
type_cnt:   ds 8
map_stack:  ds 3 * MAP_DEPTH
section wram, $C300
line_buf:   ds 7 * 16

section wram, $DF80
poses:      ds 64                            ; (work RAM bank 1)
