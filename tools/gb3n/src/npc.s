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

section bank 0, $3800
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
            ld a, B_NPCS
            call sbank
            ld hl, $6590                    ; the world map start position
            ld a, [hl+]
            ld [SRAM_PAGE + $09], a
            ld a, [hl]
            ld [SRAM_PAGE + $0A], a
            ld hl, N_INITSW                 ; npc switches
            ld de, SR_NPCSW
            ld bc, 64
            call memcpy
            ld hl, $6542                    ; job base stats bytes 2-6 -> $110 and $115
            ld de, SRAM_PAGE + $112
            ld bc, 5
            call memcpy
            ld hl, $6542
            ld de, SRAM_PAGE + $117
            ld bc, 5
            call memcpy
            ld hl, $6548                    ; MP: each value twice ($130, $131 ...)
            ld de, SRAM_PAGE + $130
            ld b, 8
.m:         ld a, [hl+]
            ld [de], a
            inc de
            ld [de], a
            inc de
            dec b
            jr nz, .m
            ld a, [$6550]                   ; HP: current and max
            ld [SRAM_PAGE + $10C], a
            ld [SRAM_PAGE + $10E], a
            ld a, [$6551]
            ld [SRAM_PAGE + $10D], a
            ld [SRAM_PAGE + $10F], a
            ld hl, $6560                    ; stats ($11C-$12F)
            ld de, SRAM_PAGE + $11C
            ld bc, 20
            call memcpy
            ld hl, $6580                    ; equipment ($200)
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
npc_load:   ld hl, NPC1
            ld de, $200
            call memclr
            ld a, B_SCRIPT                  ; the map's npc list (NES $2C/$2D as one 16 KB bank:
            call sbank                      ;   NES $8000-$BFFF -> $4000-$7FFF), into npc_list
            ld a, [map_props + 4]
            ld l, a
            ld h, 0
            add hl, hl
            ld de, $4000
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld a, h
            and $3F
            or $40
            ld h, a
            ld de, npc_list
            ld b, 4 * NPC_SLOTS
.cp:        ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .cp
            xor a
            ld [de], a                      ; (a terminator after 12)
            ld a, B_NPCS
            call sbank
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
            ld a, [de]                      ; graphics for a shown person
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
            ld a, [hl]                      ; graphics id
            ld l, a
            ld h, 0
            ld c, l
            ld b, h
            add hl, hl
            add hl, bc
            ld bc, N_GFXTAB
            add hl, bc
            ld a, [hl+]
            ld [gfx_src], a
            ld a, [hl+]
            ld [gfx_src + 1], a
            ld a, [hl]
            ld [gfx_src + 2], a
            ld a, [gfx_src]
            call sbank
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
            call memcpy
            xor a
            ldh [rVBK], a
            pop de
            ld a, B_NPCS
            jp sbank

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
.w:         ld a, B_NPCS
            call sbank
            ld bc, oam_buf + 16
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
            inc hl
            inc hl
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
            ld [nd_y], a
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
            ld h, high(N_POSE)
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
frame:      ds 1
npc_list:   ds 4 * NPC_SLOTS + 1
