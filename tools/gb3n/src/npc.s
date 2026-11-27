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
NPC_DRAWN  = 8              ; at most 8 people drawn (40 sprites: the party and the guest take 8)
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
            push de                         ; NPC2 +0 / +1 the cell's properties & $37, +6 its
            ld h, d                         ;   level (3B/B3B0)
            ld l, e
            inc l
            inc l
            ld a, [hl+]
            ld b, a
            ld e, [hl]
            ld d, b
            call map_mt
            ld l, a
            ld h, W_PROP1
            ld a, [hl]
            and $37
            pop de
            ld h, d
            inc h
            ld l, e
            ld [hl+], a
            ld [hl], a
            and 3
            ld c, a
            ld a, l
            add 5
            ld l, a
            ld [hl], c
            push de                         ; +2 animation speed mask, +3 movement counter
            ld hl, 10                       ;   (01/BE00, 01/BF00 off world 0)
            add hl, de
            ld l, [hl]
            ld h, 0
            ld a, [world]
            and a
            jr z, .s0
            inc h
.s0:        ld bc, N_SPEED
            add hl, bc
            ld a, B_NPCS
            call far_byte
            pop de
            ld h, d
            inc h
            ld l, e
            inc l
            inc l
            ld b, a
            and $0F
            ld [hl+], a
            ld a, b
            swap a
            and $0F
            ld [hl], a
npc_gfx:    ld a, [de]                      ; graphics for a shown person (DE = its slot)
            and a
            ret z
            ld a, e                         ; VRAM bank 1 tile 32 + 16 * slot (FF3's $1200 +;
            and $F0                         ;   the guest at 16)
            add $20
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
            push hl                         ; touched by the party (3F/E414): +11 & 3, +13 = 1
            ld a, l
            add 11
            ld l, a
            ld a, [hl]
            and 3
            ld [hl+], a
            inc l
            ld a, [hl]
            and $80
            or 1
            ld [hl], a
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
.w:         ld bc, oam_buf + 32             ; (entries 8-39: the guest has 4-7)
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
            add 14                          ; (FF3: people 2 pixels above their cell)
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
            push bc                         ; (3B/B23E: the frame by movement type)
            call npc_anim
            pop bc
            ld a, [nd_slot]                 ; the pose: palette pair + facing + frame
            ld l, a
            ld h, high(NPC2)
            ld a, l
            add 5
            ld l, a
            ld a, [hl]                      ; NPC2 + 5: palette pair (0, $40, $80, $C0)
            ld e, a
            ld a, [nd_face]                 ; facing offset
            add e
            ld e, a
            ld a, [nd_fr]
            add e
            ld l, a
            ld h, high(npc_poses)
            ld a, [npc_left]
            dec a
            ld [npc_left], a
            ld a, [nd_x]
            ld d, a
            ld a, [nd_y]
            ld e, a
            ld a, [nd_pt]
            ld [nd_pc], a
            call .spr                       ; UL
            ld a, e
            add 8
            ld e, a
            ld a, [nd_pb]
            ld [nd_pc], a
            call .spr                       ; DL
            ld a, e
            sub 8
            ld e, a
            ld a, d
            add 8
            ld d, a
            ld a, [nd_pt]
            ld [nd_pc], a
            call .spr                       ; UR
            ld a, e
            add 8
            ld e, a
            ld a, [nd_pb]
            ld [nd_pc], a
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
            ld a, [nd_pc]                   ; (the priority toggled on bridges: 3B/AEC6)
            xor [hl]
            inc hl
            call oam_attr
            ld [bc], a
            inc c
            ret

; the frame, tiles, facing, bob and priority of the person at nd_slot (3B/B1CD-B2C6)
npc_anim:   ld a, [nd_sx]                   ; halfway across: the cell's priority (3B/B1CD; 0 on
            ld b, a                         ;   a bridge at level 1 / 3)
            ld a, [nd_sy]
            or b
            cp 8
            jr nz, .h
            ld a, [nd_slot]
            ld l, a
            ld h, high(NPC2)
            ld a, [hl]
            bit 2, a
            jr z, .hs
            ld a, l
            add 6
            ld l, a
            bit 0, [hl]
            ld a, l
            sub 6
            ld l, a
            ld a, [hl]
            jr z, .hs
            xor a
.hs:        inc l
            ld [hl], a
.h:         ld a, [nd_slot]
            ld l, a
            ld h, high(NPC1)
            add 32                          ; tiles: 16 per slot from 32
            ld [nd_tb], a
            ld a, l
            add 14
            ld l, a
            ld a, [hl]
            ld [nd_face], a
            ld a, [nd_slot]
            add 13
            ld l, a
            ld a, [hl]                      ; facing the party while spoken to (bit 7, the
            bit 7, a                        ;   direction in bits 4-5)
            jr z, .ty
            and $30
            ld [nd_face], a
            xor a
            ld [nd_fr], a
            jr .pr
.ty:        ld a, [nd_slot]
            inc a
            ld l, a
            ld a, [hl]                      ; +1: movement type
            and $F0
            ld c, a
            jr nz, .t1
            ld a, [nd_sx]                   ; 00: walking (the frame halfway across the cell)
            ld b, a
            ld a, [nd_sy]
            or b
            add a
            and 8
            jr .fr
.t1:        ld a, [frame]
            bit 7, c
            jr nz, .t8
            bit 6, c
            jr z, .st
            jr .f8                          ; 40-70: every 8 frames
.t8:        bit 6, c
            jr z, .st                       ; 80-B0: still
            bit 4, c
            jr nz, .t4
            srl a                           ; C0 / E0: every 16
            jr .f8
.t4:        add a                           ; D0 / F0: every 4
.f8:        ld b, a
            and 8
            push af
            bit 6, c                        ; continuous animation with bit 4: the tiles 8 before
            jr z, .nc
            bit 4, c
            jr z, .nc
            bit 4, b
            jr z, .nc
            ld a, [nd_tb]
            sub 8
            ld [nd_tb], a
.nc:        pop af
            jr .fr
.st:        xor a
.fr:        ld [nd_fr], a
            and a                           ; the walkers' bob: up a pixel (or left when moving
            jr z, .pr                       ;   up / down)
            ld a, c
            and a
            jr nz, .pr
            ld a, [nd_sy]
            and a
            jr nz, .bx
            ld hl, nd_y
            dec [hl]
            jr .pr
.bx:        ld hl, nd_x
            dec [hl]
.pr:        ld a, [nd_slot]                 ; priority: NPC2 +1 & $24 the bottom, & $14 the top
            ld l, a
            ld h, high(NPC2)
            inc l
            ld a, [hl]
            ld c, a
            and $24
            jr z, .p1
            ld a, $20
.p1:        ld [nd_pb], a
            ld a, c
            and $14
            jr z, .p2
            ld a, $20
.p2:        ld [nd_pt], a
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
nd_face:    ds 1
nd_fr:      ds 1
nd_pt:      ds 1
nd_pb:      ds 1
nd_pc:      ds 1
npc_r4a:    ds 1                            ; FF3's $4A: the person the wandering looks at next
npc_r4:     ds 1                            ; FF3's $F4: its random number counter
npc_z:      ds 1                            ; FF3's $86
npc_tp:     ds 1
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

; ---- a frame of the people (3B/AEEB): each one's step (3B/B17C), then one may set off
npc_update: ld hl, NPC1
            ld b, NPC_SLOTS
.c:         ld a, [hl]
            and a
            jr z, .n
            push bc
            push hl
            call npc_mv1
            pop hl
            pop bc
.n:         ld a, l
            add 16
            ld l, a
            dec b
            jr nz, .c
            ld a, [ev_on]                   ; (none while an event runs)
            and a
            ret nz
            ld a, [dlg_on]
            and a
            ret nz
            jp npc_rand
; one person's step: a pixel on frames its speed mask allows (always while touched)
npc_mv1:    ld a, l
            add 13
            ld l, a
            ld a, [hl]
            and a
            jr nz, .go
            ld a, l
            sub 11
            ld l, a
            inc h
            ld a, [frame]
            and [hl]
            dec h
            and a                           ; (dec h set the flags)
            ret nz
            ld a, l
            add 11
            ld l, a
.go:        ld a, l                         ; (HL = +13)
            sub 5
            ld l, a
            ld a, [hl]                      ; +8: x speed
            and a
            jr z, .y
            ld c, a
            ld a, l
            sub 2
            ld l, a
            ld a, [hl]
            add c
            and 15
            ld [hl], a
            ret nz
            ld a, l                         ; arrived: speed, direction, touch 0; +4 = +2
            add 2
            ld l, a
            xor a
            ld [hl], a
            ld a, l
            add 4
            ld l, a
            xor a
            ld [hl+], a
            ld a, [hl]
            and $80                         ; (bit 7: facing the party, kept)
            ld [hl], a
            ld a, l
            sub 11
            ld l, a
            ld a, [hl+]
            inc l
            ld [hl], a
            ret
.y:         inc l                           ; +9: y speed
            ld a, [hl]
            and a
            ret z
            ld c, a
            ld a, l
            sub 2
            ld l, a
            ld a, [hl]
            add c
            and 15
            ld [hl], a
            ret nz
            ld a, l
            add 2
            ld l, a
            xor a
            ld [hl], a
            ld a, l
            add 3
            ld l, a
            xor a
            ld [hl+], a
            ld a, [hl]
            and $80
            ld [hl], a
            ld a, l
            sub 10
            ld l, a
            ld a, [hl+]                     ; +5 = +3
            inc l
            ld [hl], a
            ret

; the wandering (3B/AF97): one person every frame looked at in turn; when its counter runs out
; it steps a random way if the cell is free
npc_rand:   ld a, [npc_r4a]
            add 16
            and $F0
            cp $C0
            jr c, .k
            xor a
.k:         ld [npc_r4a], a
            ld l, a
            ld h, high(NPC1)
            ld a, [hl]
            and a
            ret z
            inc l
            ld a, [hl]                      ; +1 bit 7: stays put
            and $80
            ld b, a
            ld a, l
            add 11
            ld l, a
            ld a, [hl]                      ; +12: already moving
            or b
            ret nz
            dec l
            ld a, [hl]                      ; +11: the counter
            and a
            jr z, .go
            dec [hl]
            ret
.go:        ld a, [npc_r4a]
            ld [nd_slot], a
            add 2
            ld l, a
            ld a, [hl+]
            ld d, a
            ld e, [hl]
            inc h
            ld a, [npc_r4a]
            add 6
            ld l, a
            ld a, [hl]
            ld [npc_z], a
            dec h
            ld hl, npc_r4
            inc [hl]
            ld a, [hl]
            ld hl, fld_rng
            add l
            ld l, a
            jr nc, .r
            inc h
.r:         ld a, [hl]
            and 3
            jr z, .rt
            dec a
            jr z, .lt
            dec a
            jr z, .dn
            dec e                           ; up
            ld a, e
            and 63
            ld e, a
            call npc_pass
            ret c
            ld h, high(NPC1)
            ld a, [nd_slot]
            add 3
            ld l, a
            ld [hl], e
            inc l
            inc l
            ld [hl], e
            inc l
            inc l
            ld [hl], 15                     ; +7
            inc l
            inc l
            ld [hl], $FF                    ; +9
            ld c, 4
            ld b, $30
            jr .set
.dn:        inc e
            ld a, e
            and 63
            ld e, a
            call npc_pass
            ret c
            ld h, high(NPC1)
            ld a, [nd_slot]
            add 3
            ld l, a
            ld [hl], e
            ld a, l
            add 6
            ld l, a
            ld [hl], 1                      ; +9
            ld c, 8
            ld b, $20
            jr .set
.lt:        dec d
            ld a, d
            and 63
            ld d, a
            call npc_pass
            ret c
            ld h, high(NPC1)
            ld a, [nd_slot]
            add 2
            ld l, a
            ld [hl], d
            inc l
            inc l
            ld [hl], d
            inc l
            inc l
            ld [hl], 15                     ; +6
            inc l
            inc l
            ld [hl], $FF                    ; +8
            ld c, 2
            ld b, $10
            jr .set
.rt:        inc d
            ld a, d
            and 63
            ld d, a
            call npc_pass
            ret c
            ld h, high(NPC1)
            ld a, [nd_slot]
            add 2
            ld l, a
            ld [hl], d
            ld a, l
            add 6
            ld l, a
            ld [hl], 1                      ; +8
            ld c, 1
            ld b, 0
.set:       ld a, [nd_slot]                 ; +12 direction, the facing unless +1 & $50
            add 12
            ld l, a
            ld [hl], c
            ld a, [nd_slot]
            inc a
            ld l, a
            ld a, [hl]
            and $50
            jr nz, .cnt
            ld a, [nd_slot]
            add 14
            ld l, a
            ld [hl], b
.cnt:       ld a, [nd_slot]                 ; +11 = NPC2 +3
            add 3
            ld l, a
            inc h
            ld a, [hl]
            dec h
            ld b, a
            ld a, [nd_slot]
            add 11
            ld l, a
            ld [hl], b
            ret

; can person nd_slot step to (D, E) at level npc_z? carry set if not (3B/B110)
npc_pass:   ld a, [ev_on]
            and a
            jr nz, .tile
            ld a, [npc_z]                   ; the party's cell (unless on another level)
            and a
            jr z, .pl
            ld a, [z_lev]
            and a
            jr z, .pl
            ld b, a
            ld a, [npc_z]
            cp b
            jr nz, .tl
.pl:        ld a, [pos_x]
            cp d
            jr nz, .pd
            ld a, [pos_y]
            cp e
            jr z, .no
.pd:        ld a, [step]                    ; (and where the party is stepping to)
            and a
            jr z, .tl
            push de
            call dest_cell
            ld a, d
            ld b, e
            pop de
            cp d
            jr nz, .tl
            ld a, b
            cp e
            jr z, .no
.tl:        call npc_tile
            ret c
            ld hl, NPC1                     ; the others' destinations
.o:         ld a, [nd_slot]
            cp l
            jr z, .on
            ld a, [hl]
            and a
            jr z, .on
            inc h
            ld a, l
            add 6
            ld l, a
            ld a, [hl]                      ; their level
            and a
            jr z, .oz
            ld b, a
            ld a, [npc_z]
            and a
            jr z, .oz
            cp b
            jr nz, .ox
.oz:        ld a, l
            sub 6
            ld l, a
            dec h
            inc l
            inc l
            ld a, [hl+]
            cp d
            jr nz, .oy
            ld a, [hl]
            cp e
            jr z, .no
.oy:        ld a, l
            and $F0
            ld l, a
            jr .on
.ox:        ld a, l
            sub 6
            ld l, a
            dec h
.on:        ld a, l
            add 16
            ld l, a
            cp $C0
            jr nz, .o
            jr .set
.tile:      call npc_tile
            ret c
.set:       ld a, [nd_slot]                 ; NPC2 +0 = the cell's properties, +6 the level
            ld l, a
            ld h, high(NPC2)
            ld a, [npc_tp]
            and $37
            ld [hl], a
            ld a, l
            add 6
            ld l, a
            ld a, [npc_z]
            ld [hl], a
            and a
            ret
.no:        scf
            ret
; the cell (D, E) for a person at level npc_z (3B/B0C5): carry set if blocked
npc_tile:   push de
            call map_mt
            pop de
            ld l, a
            ld h, W_PROP1
            ld a, [hl]
            ld [npc_tp], a
            bit 7, a
            jr nz, .no
            and 7
            jr z, .z0
            cp 4
            jr nc, .ok
            cp 3
            jr z, .no
            ld b, a
            ld a, [npc_z]
            or b
            cp 3
            jr z, .no
            ld [npc_z], a
.ok:        and a
            ret
.z0:        ld [npc_z], a
            ret
.no:        scf
            ret

; the person at (D, E) to talk to (3F/E494: a person halfway across a cell counts as in the
; next): HL = their slot, carry set; one who turns faces the party (+13 bit 7, the way in 4-5)
npc_find:   ld hl, NPC1
.c:         inc h
            ld a, l
            add 6
            ld l, a
            ld a, [hl]
            and a
            jr z, .zo
            cp 3
            jr z, .zo
            ld b, a
            ld a, [z_lev]
            and a
            jr z, .zo
            cp b
            jr nz, .nx
.zo:        ld a, l
            and $F0
            ld l, a
            dec h
            ld a, [hl]
            and a
            jr z, .nn
            ld a, l
            add 6
            ld l, a
            ld c, [hl]                      ; x + (sub >= 8)
            ld a, l
            sub 2
            ld l, a
            ld a, c
            cp 8
            ld a, [hl]
            ccf
            adc 0
            and 63
            cp d
            jr nz, .nb
            ld a, l
            add 3
            ld l, a
            ld c, [hl]
            ld a, l
            sub 2
            ld l, a
            ld a, c
            cp 8
            ld a, [hl]
            ccf
            adc 0
            and 63
            cp e
            jr nz, .nb
            ld a, l
            and $F0
            ld l, a
            inc l
            ld a, [hl]
            dec l
            and $30
            jr nz, .f
            push hl                         ; turns to face the party
            ld a, [facing]
            ld b, $20                       ; party up: down
            bit 3, a
            jr nz, .w
            ld b, $30                       ; down: up
            bit 2, a
            jr nz, .w
            ld b, 0                         ; left: right
            bit 1, a
            jr nz, .w
            ld b, $10                       ; right: left
.w:         ld a, l
            add 13
            ld l, a
            ld a, [hl]
            and $0F
            or b
            or $80
            ld [hl], a
            pop hl
.f:         scf
            ret
.nx:        ld a, l
            and $F0
            ld l, a
            dec h
            jr .nn
.nb:        ld a, l
            and $F0
            ld l, a
.nn:        ld a, l
            add 16
            ld l, a
            cp $C0
            jr nz, .c
            and a
            ret
; the people stop facing the party (the talk is over)
npc_unface: ld hl, NPC1 + 13
.c:         res 7, [hl]
            ld a, l
            add 16
            ld l, a
            cp $C0 + 13
            jr nz, .c
            ret

section wram, $DE00
npc_poses:  ds 256                          ; (work RAM bank 1)
