; FF3's game state and the people on normal maps.
; FF3's save page ($6000-$63FF on the NES) is kept at SRAM_PAGE ($D000, work RAM bank 1) with
; the same layout; init sram ($3A $8E76) is done natively from tables in bank B_NPCS:
;   B_NPCS $4000 NES bank $2C (npc property pointers $8000, npc properties)
;          $6000 graphics id per npc id (512)   $6200 npc speeds (01/BE00, 512)
;          $6400 npc poses (3B/B41A: 4 palette pairs x right, left, down, up x 2 frames x 8)
;          $6500 initial npc switches (64)      $6540 job base stats (8)  $6548 initial MP (8)
;          $6550 initial HP (2)  $6560 initial stats (20)  $6580 initial equipment (16)
;          $6590 the world map start (x, y)     $6700 npc graphics (bank, address) per id
; People ($3B $B2FD load npcs): 12 slots of 16 bytes at NPC1 ($7000 on the NES) and NPC2 ($7100).

SRAM_PAGE  = $D000
SR_NPCSW   = SRAM_PAGE + $80
SR_TREAS   = SRAM_PAGE + $40
NPC1       = $D400
NPC2       = $D500
NPC_SLOTS  = 12
NPC_DRAWN  = 9              ; at most 9 people drawn (40 sprites: the party takes 4)
N_GFXID    = $6000
N_SPEED    = $6200
N_POSE     = $6400
N_INITSW   = $6500
N_GFXTAB   = $6700

section bank B_FIELD, $5800
; ---- new game: the save page as FF3's init sram leaves it
sram_init:  ld hl, SRAM_PAGE
            ld de, $400
            call memclr
            ld hl, SR_TREAS                 ; treasure switches all set ($FF)
            ld b, 64
            ld a, $FF
.t:         ld [hl+], a
            dec b
            jr nz, .t
            ld hl, $6500                    ; the init tables into SCRATCH ($6500-$65FF)
            ld de, SCRATCH
            ld bc, $100
            ld a, B_NPCS
            call far_copy
            ld a, [SCRATCH + $90]           ; the world map start position
            ld [SRAM_PAGE + $09], a
            ld a, [SCRATCH + $91]
            ld [SRAM_PAGE + $0A], a
            ld hl, SCRATCH                  ; npc switches
            ld de, SR_NPCSW
            ld bc, 64
            call memcpy
            ld hl, SCRATCH + $42            ; job base stats bytes 2-6 -> $112 and $117
            ld de, SRAM_PAGE + $112
            ld bc, 5
            call memcpy
            ld hl, SCRATCH + $42
            ld de, SRAM_PAGE + $117
            ld bc, 5
            call memcpy
            ld hl, SCRATCH + $48            ; MP: each value twice ($130, $131 ...)
            ld de, SRAM_PAGE + $130
            ld b, 8
.m:         ld a, [hl+]
            ld [de], a
            inc de
            ld [de], a
            inc de
            dec b
            jr nz, .m
            ld a, [SCRATCH + $50]           ; HP: current and max
            ld [SRAM_PAGE + $10C], a
            ld [SRAM_PAGE + $10E], a
            ld a, [SCRATCH + $51]
            ld [SRAM_PAGE + $10D], a
            ld [SRAM_PAGE + $10F], a
            ld hl, SCRATCH + $60            ; stats ($11C-$12F)
            ld de, SRAM_PAGE + $11C
            ld bc, 20
            call memcpy
            ld hl, SCRATCH + $80            ; equipment ($200)
            ld de, SRAM_PAGE + $200
            ld bc, 16
            call memcpy
            ld hl, SRAM_PAGE + $106         ; names cleared ($FF)
            ld b, 6
            ld a, $FF
.n:         ld [hl+], a
            dec b
            jr nz, .n
            ld hl, SRAM_PAGE + $100         ; the other three members as the first
            ld de, SRAM_PAGE + $140
            ld bc, $40
            call memcpy
            ld hl, SRAM_PAGE + $100
            ld de, SRAM_PAGE + $180
            ld bc, $40
            call memcpy
            ld hl, SRAM_PAGE + $100
            ld de, SRAM_PAGE + $1C0
            ld bc, $40
            call memcpy
            ld hl, SRAM_PAGE + $200
            ld de, SRAM_PAGE + $240
            ld bc, $40
            call memcpy
            ld hl, SRAM_PAGE + $200
            ld de, SRAM_PAGE + $280
            ld bc, $40
            call memcpy
            ld hl, SRAM_PAGE + $200
            ld de, SRAM_PAGE + $2C0
            ld bc, $40
            jp memcpy

; ---- the map's people (LCD off): FF3's load npcs; each visible person's 16 sprite tiles into
; VRAM bank 1 at tile 16 + 16 * slot
npc_load:   ld a, [npc_keep]                ; (back from a menu / battle: the people stay
            and a                           ;   where they were; their graphics again)
            jr nz, .k0
            ld hl, NPC1
            ld de, $200
            call memclr
.k0:
            ld hl, N_POSE                   ; the people's poses (3B/B41A) into npc_poses
            ld de, npc_poses
            ld bc, 256
            ld a, B_NPCS
            call far_copy
            ld a, [map_props + 4]           ; the map's npc list (NES $2C/$2D as one 16 KB bank:
            ld l, a                         ;   NES $8000-$BFFF -> $4000-$7FFF), into npc_list
            ld h, 0
            add hl, hl
            ld de, $4000
            add hl, de
            ld de, nd_ptr
            ld bc, 2
            ld a, B_SCRIPT
            call far_copy
            ld a, [nd_ptr]
            ld l, a
            ld a, [nd_ptr + 1]
            and $3F
            or $40
            ld h, a
            ld de, npc_list
            ld bc, 4 * NPC_SLOTS
            ld a, B_SCRIPT
            call far_copy
            xor a
            ld [npc_list + 4 * NPC_SLOTS], a ; (a terminator after 12)
            ld a, [npc_keep]
            and a
            jr z, .k1
            xor a
            ld [npc_keep], a
            ld de, NPC1
            ld b, NPC_SLOTS
.kg:        push bc
            push de
            call npc_gfx
            pop de
            pop bc
            ld a, e
            add 16
            ld e, a
            jr nc, .kn
            inc d
.kn:        dec b
            jr nz, .kg
            ret
.k1:
            ld hl, npc_list
            ld de, NPC1
            xor a
            ld [npc_n], a
.n:         ld a, [hl]
            and a
            ret z
            ld a, [npc_n]
            cp NPC_SLOTS
            ret nc
            push hl
            push de
            call npc_one
            pop de
            pop hl
            ld bc, 4
            add hl, bc
            ld a, e
            add 16
            ld e, a
            ld a, [npc_n]
            inc a
            ld [npc_n], a
            jr .n

; one person: HL = its 4 property bytes, DE = its NPC1 slot ($3B $B34E load npc)
npc_one:    ld a, [hl+]                     ; id
            ld c, a
            push hl
            ld hl, 10                       ; +10: id
            add hl, de
            ld [hl], c
            ld a, c                         ; shown when its npc switch is set
            call npc_switch
            pop hl
            jr z, .hid
            ld a, c
            ld [de], a                      ; +0: id when shown, 0 hidden
.hid:       ld a, [hl+]                     ; x -> +2, +4
            push hl
            ld hl, 2
            add hl, de
            ld [hl], a
            inc hl
            inc hl
            ld [hl], a
            pop hl
            ld a, [hl+]                     ; y -> +3, +5
            push hl
            ld hl, 3
            add hl, de
            ld [hl], a
            inc hl
            inc hl
            ld [hl], a
            pop hl
            ld a, [hl]                      ; aaaabbcc: movement +1, palette pair NPC2+5,
            ld b, a                         ;   facing +14 (pose offset: right 0, left $10,
            and $F0                         ;   down $20, up $30)
            push hl
            ld hl, 1
            add hl, de
            ld [hl], a
            ld a, b
            and 3
            ld c, $20                       ; 0 down
            jr z, .f
            ld c, $30                       ; 1 up
            dec a
            jr z, .f
            ld c, $10                       ; 2 left
            dec a
            jr z, .f
            ld c, 0                         ; 3 right
.f:         ld hl, 14
            add hl, de
            ld [hl], c
            ld a, b
            add a
            add a
            add a
            add a
            and $C0
            ld hl, NPC2 - NPC1 + 5
            add hl, de
            ld [hl], a
            pop hl
npc_gfx:    ld a, [de]                      ; graphics for a shown person (DE = its slot)
            and a
            ret z
            ld a, e                         ; VRAM bank 1 tile 16 + 16 * slot
            and $F0
            add $10
            ld [npc_vram], a
            ld hl, 10
            add hl, de
            ld l, [hl]
            ld h, 0
            ld a, [world]
            cp 2
            jr c, .w
            inc h
.w:         ld bc, N_GFXID
            add hl, bc
            ld a, B_NPCS
            call far_byte                   ; graphics id
            ld l, a
            ld h, 0
            ld c, l
            ld b, h
            add hl, hl
            add hl, bc
            ld bc, N_GFXTAB
            add hl, bc
            push de
            ld de, gfx_src
            ld bc, 3
            ld a, B_NPCS
            call far_copy
            pop de
            ld a, [gfx_src + 1]
            ld l, a
            ld a, [gfx_src + 2]
            ld h, a
            push de
            ld a, [npc_vram]
            swap a
            ld e, a
            and $0F
            add $80
            ld d, a
            ld a, e
            and $F0
            ld e, a
            ld a, 1
            ldh [rVBK], a
            ld bc, $100
            ld a, [gfx_src]
            call far_copy
            xor a
            ldh [rVBK], a
            pop de
            ret

; Z clear when npc switch A is set ($3B $B51A: byte id / 8 (+ 32 off world 0), bit id & 7)
npc_switch: push bc
            push hl
            ld c, a
            and 7
            ld b, a
            ld a, 1
            inc b
.b:         dec b
            jr z, .g
            add a
            jr .b
.g:         ld b, a
            ld a, c
            srl a
            srl a
            srl a
            ld c, a
            ld a, [world]
            and a
            ld a, c
            jr z, .w0
            add 32
.w0:        ld l, a
            ld h, high(SR_NPCSW)
            ld a, l
            add low(SR_NPCSW)
            ld l, a
            ld a, [hl]
            and b
            pop hl
            pop bc
            ret

; is a shown person at map (D, E)? carry set if so ($3F $E3F1, the standing cell)
npc_at:     ld hl, NPC1
            ld b, NPC_SLOTS
.c:         ld a, [hl]
            and a
            jr z, .n
            push hl
            inc hl
            inc hl
            ld a, [hl+]
            cp d
            jr nz, .x
            ld a, [hl]
            cp e
            jr nz, .x
            pop hl
            scf
            ret
.x:         pop hl
.n:         ld a, l
            add 16
            ld l, a
            dec b
            jr nz, .c
            and a
            ret

; draw the people in view into OAM entries 4-39 (at most NPC_DRAWN; the rest of OAM hidden)
npc_oam:    ld a, [step]                    ; the walk's pixel offset (signed): walk_dx / dy
            and a
            jr z, .s0
            dec a
.s0:        ld b, a
            xor a
            ld [walk_dx], a
            ld [walk_dy], a
            ld a, [facing]
            rra
            jr c, .r
            rra
            jr c, .l
            rra
            jr c, .d
            xor a
            sub b
            ld [walk_dy], a
            jr .w
.r:         ld a, b
            ld [walk_dx], a
            jr .w
.l:         xor a
            sub b
            ld [walk_dx], a
            jr .w
.d:         ld a, b
            ld [walk_dy], a
.w:         ld bc, oam_buf + 16
            ld hl, NPC1
            ld a, NPC_SLOTS
            ld [npc_n], a
            ld a, NPC_DRAWN
            ld [npc_left], a
.c:         ld a, [hl]
            and a
            jr z, .n
            ld a, [npc_left]
            and a
            jr z, .end
            push hl
            call npc_draw
            pop hl
.n:         ld a, l
            add 16
            ld l, a
            ld a, [npc_n]
            dec a
            ld [npc_n], a
            jr nz, .c
.end:       ld a, c                         ; hide the rest
            cp 160
            ret nc
            xor a
            ld [bc], a
            inc c
            inc c
            inc c
            inc c
            jr .end

; one person (HL = its NPC1 slot) if on screen: 4 sprites at BC (advanced)
npc_draw:   ld a, l
            ld [nd_slot], a
            add 6
            ld l, a
            ld a, [hl+]                     ; sub-tile offsets (+6, +7)
            ld [nd_sx], a
            ld a, [hl]
            ld [nd_sy], a
            ld a, [nd_slot]
            add 4
            ld l, a
            ld a, [cam_x]                   ; metatiles from the camera (0-63): on screen
            ld d, a                         ;   when 0-10 or 63 (a step's partial column)
            ld a, [hl+]
            sub d
            and 63
            cp 11
            jr c, .xo
            cp 63
            ret nz
.xo:        swap a                          ; x = d * 16 - walk_dx + 8 (OAM)
            and $F0
            ld d, a
            ld a, [walk_dx]
            cpl
            inc a
            add d
            add 8
            ld d, a
            ld a, [nd_sx]
            add d
            ld [nd_x], a
            ld a, [cam_y]
            ld e, a
            ld a, [hl]
            sub e
            and 63
            cp 10
            jr c, .yo
            cp 63
            ret nz
.yo:        swap a
            and $F0
            ld e, a
            ld a, [walk_dy]
            cpl
            inc a
            add e
            add 16
            ld e, a
            ld a, [nd_sy]
            add e
            ld [nd_y], a
            ld a, [dlg_on]                  ; (under the dialogue box: not drawn)
            and a
            jr z, .vis
            ld a, [nd_y]
            cp 16 + DLG_ROWS * 8
            ret c
.vis:
            ld a, [nd_slot]                 ; the pose: palette pair + facing + frame
            ld l, a
            ld h, high(NPC2)
            ld a, l
            add 5
            ld l, a
            ld a, [hl]                      ; NPC2 + 5: palette pair (0, $40, $80, $C0)
            ld e, a
            ld h, high(NPC1)
            ld a, [nd_slot]
            add 14
            ld l, a
            ld a, [hl]                      ; NPC1 + 14: facing offset
            add e
            ld e, a
            ld a, [frame]                   ; walking in place: a frame every 16
            and $10
            rra
            add e
            ld l, a
            ld h, high(npc_poses)
            ld a, [nd_slot]
            and $F0
            add 16
            ld [nd_tb], a
            ld a, [npc_left]
            dec a
            ld [npc_left], a
            ld a, [nd_x]
            ld d, a
            ld a, [nd_y]
            ld e, a
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
.spr:       ld a, e
            ld [bc], a
            inc c
            ld a, d
            ld [bc], a
            inc c
            ld a, [nd_tb]
            add [hl]
            inc hl
            ld [bc], a
            inc c
            ld a, [hl+]
            call oam_attr
            ld [bc], a
            inc c
            ret

section wram, $C380
npc_n:      ds 1
npc_left:   ds 1
npc_vram:   ds 1
gfx_src:    ds 3
walk_dx:    ds 1
walk_dy:    ds 1
nd_slot:    ds 1
nd_x:       ds 1
nd_y:       ds 1
nd_tb:      ds 1
nd_sx:      ds 1
nd_sy:      ds 1
frame:      ds 1
npc_list:   ds 4 * NPC_SLOTS + 1
nd_ptr:     ds 2
npc_keep:   ds 1                            ; 1: the next map load keeps the people

section bank B_FIELD, $7A00
; ---- person at slot L (NPC1 page) starts a step in direction A (0 right, 1 left, 2 down, 3 up)
; ($3B $AFDD: the destination is claimed at once; right / down count the sub-tile 0 -> 15 from
; the old cell, left / up 15 -> 0 from the new one)
npc_move:   ld h, high(NPC1)
            ld c, a
            ld a, l
            ld [nd_slot], a
            add 14                          ; facing: right 0, left $10, down $20, up $30
            ld l, a
            ld a, c
            swap a
            ld [hl], a
            ld a, [nd_slot]
            add 12
            ld l, a
            ld [hl], 1                      ; +12 moving
            ld a, [nd_slot]
            ld l, a
            ld a, c
            cp 2
            jr nc, .v
            inc l                           ; x: +2 dest, +4 current, +6 sub, +8 speed
            inc l
            ld a, c
            and a
            ld a, [hl]
            jr nz, .lt
            inc a
            and 63
            ld [hl+], a
            inc l
            ld [hl], 0
            inc l
            inc l
            ld [hl], 1
            ret
.lt:        dec a
            and 63
            ld [hl+], a
            inc l
            ld [hl], a
            inc l
            inc l
            ld [hl], 15
            inc l
            inc l
            ld [hl], $FF
            ret
.v:         inc l                           ; y: +3 dest, +5 current, +7 sub, +9 speed
            inc l
            inc l
            ld a, c
            cp 3
            ld a, [hl]
            jr z, .up
            inc a
            and 63
            ld [hl+], a
            inc l
            ld [hl], 0
            inc l
            inc l
            ld [hl], 1
            ret
.up:        dec a
            and 63
            ld [hl+], a
            inc l
            ld [hl], a
            inc l
            inc l
            ld [hl], 15
            inc l
            inc l
            ld [hl], $FF
            ret

; ---- a frame of the people's steps: a pixel a frame; at the end the current cell = destination
npc_update: ld hl, NPC1
            ld b, NPC_SLOTS
.c:         push hl
            ld a, l
            add 12
            ld l, a
            ld a, [hl]
            and a
            jr z, .n
            ld a, l                         ; x speed (+8)
            sub 4
            ld l, a
            ld a, [hl+]
            ld c, a
            ld a, [hl]                      ; y speed (+9)
            ld d, a
            ld a, l
            sub 3
            ld l, a                         ; +6
            ld a, [hl]
            add c
            and 15
            ld [hl+], a
            ld e, a
            ld a, [hl]                      ; +7
            add d
            and 15
            ld [hl], a
            or e
            jr nz, .n
            ld a, l                         ; done: current = destination, speeds and flag 0
            sub 7
            ld l, a
            inc l
            inc l
            ld a, [hl+]
            ld c, a
            ld a, [hl+]
            ld [hl-], a                     ; (+5 = +3)
            dec l
            ld a, c
            inc l
            inc l
            ld [hl], a                      ; +4 = +2
            ld a, l
            add 4
            ld l, a
            xor a
            ld [hl+], a                     ; +8, +9
            ld [hl+], a
            inc l
            inc l
            ld [hl], a                      ; +12
.n:         pop hl
            ld a, l
            add 16
            ld l, a
            dec b
            jr nz, .c
            ret

section wram, $DE00
npc_poses:  ds 256                          ; (work RAM bank 1)
