; ---- NPCs (FF3 3B: object command 7 "load npcs" L3B_B2FA, command 6 "update npcs", random
; movement L3B_AF97, npc passability L3B_B0C5 / B110, drawing L3B_B17C / FDA3A; fix:E3F1 the
; player touching an npc). The object blocks keep FF3's layout: N_OBJ = $7000 (12 x 16 bytes:
; +0 shown (id), +1 movement type, +2/+3 destination x/y, +4/+5 x/y, +6/+7 subtile x/y,
; +8/+9 x/y speed, +A id, +B movement counter, +C moving direction, +D touched, +E animation
; (offset into N_ANIM: right $00, left $10, down $20, up $30)); N_OB2 = $7100 (+0/+1 tile
; properties & $37, +2 animation speed mask, +3 movement counter reset, +5 palette offset,
; +6 z-level).
; (N_OBJ, N_OB2, GS, N_ANIM, N_RNG: main.s)

section bank 0, $2000
; boot: the tables to WRAM, the new-game npc switches (L3A_8E76: 00/B600 -> $6080)
npc_boot:   ld a, NPCT_BANK
            ld [MBC5_BANKL], a
            ld hl, $4400
            ld de, N_ANIM                   ; (the animation frames, then the random numbers)
            ld bc, $100
            call memcpy
            ld de, N_RNG
            ld bc, $100
            call memcpy
            ld a, GAME_BANK                 ; the new-game save block (L3A_8E76, build time)
            ld [MBC5_BANKL], a
            ld hl, $5400
            ld de, GS
            ld bc, $400
            jp memcpy

; object command 7 (normal maps): the map's npc list (map properties byte 4 -> 2C/8000)
load_npcs:  ld hl, N_OBJ
            ld de, $200
            call memclr
            ldh a, [is_world]
            and a
            ret nz
            ld a, [M_ENT + 13]              ; list: NPCL_BANK $4000 + 64 index
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, $4000
            add hl, de
            ld de, N_OBJ
.rec:       ld a, NPCL_BANK
            ld [MBC5_BANKL], a
            ld a, [hl+]
            and a
            ret z
            ld [de], a                      ; (+0 for now)
            ld b, a
            ld a, e
            add a, $0A
            ld e, a
            ld a, b
            ld [de], a                      ; +A id
            ld a, e
            sub $0A
            ld e, a
            ld a, [hl+]                     ; x -> +2, +4
            inc e
            inc e
            ld [de], a
            inc e
            inc e
            ld [de], a
            ld a, [hl+]                     ; y -> +3, +5
            dec e
            ld [de], a
            inc e
            inc e
            ld [de], a
            ld a, e
            sub 5
            ld e, a
            ld a, [hl+]                     ; byte 3: movement type, palette, direction
            push hl
            ld c, a
            and $F0
            inc e
            ld [de], a                      ; +1
            dec e
            ld a, c
            and 3
            ld b, $20                       ; direction 0 down, 1 up, 2 left, 3 right
            jr z, .d
            ld b, $30
            dec a
            jr z, .d
            ld b, $10
            dec a
            jr z, .d
            ld b, $00
.d:         ld a, e
            add a, $0E
            ld e, a
            ld a, b
            ld [de], a                      ; +E
            ld a, e
            sub $0E
            ld e, a
            ld a, c                         ; N_OB2 +5 palette = (byte 3 << 4) & $C0
            swap a
            and $C0
            inc d
            ld b, a
            ld a, e
            add a, 5
            ld e, a
            ld a, b
            ld [de], a
            ld a, e
            sub 5
            ld e, a
            dec d
            push de                         ; tile properties at the npc
            ld a, e
            add a, 2
            ld e, a
            ld a, [de]
            ld b, a
            inc e
            ld a, [de]
            ld d, a
            ld e, b
            call map_at
            ld l, a
            ld h, high(M_P1)
            ld a, [hl]
            pop de
            inc d
            ld b, a
            and $37
            ld [de], a                      ; +0, +1
            inc e
            ld [de], a
            ld a, b
            and 3
            ld b, a
            ld a, e
            add a, 5
            ld e, a
            ld a, b
            ld [de], a                      ; +6 z-level
            ld a, e
            sub 6
            ld e, a
            dec d
            call npc_attrs                  ; switch, speeds, graphics id
            pop hl
            ld a, e
            add a, 16
            ld e, a
            cp $C0
            jp c, .rec
            ret

; slot DE: the switch (L3B_B51A: $6080 + id / 8, + $20 off world 0) hides it; speeds 01/BE00
; (world 0) / 01/BF00; graphics id 00/9400 (worlds 0-1) / 00/9500 -> npc_g + slot
npc_attrs:  ld a, e
            add a, $0A
            ld l, a
            ld h, d
            ld a, [hl]                      ; id
            ld c, a
            srl a
            srl a
            srl a
            ld b, a
            ld a, [cur_world]
            and a
            ld a, b
            jr z, .w0
            add a, $20
.w0:        add a, low(GS + $80)
            ld l, a
            ld h, high(GS + $80)
            ld a, c
            and 7
            ld b, a
            ld a, 1
            inc b
.m:         dec b
            jr z, .m1
            add a, a
            jr .m
.m1:        and [hl]
            jr nz, .shown
            xor a
            ld [de], a                      ; +0 = 0: hidden
.shown:     ld a, NPCT_BANK
            ld [MBC5_BANKL], a
            ld b, $42                       ; speeds: $4200 (world 0) / $4300
            ld a, [cur_world]
            and a
            jr z, .s0
            inc b
.s0:        ld h, b
            ld l, c
            ld a, [hl]
            ld b, a
            and $0F
            inc d
            ld l, e
            ld h, d
            inc l
            inc l
            ld [hl+], a                     ; N_OB2 +2 animation speed
            ld a, b
            swap a
            and $0F
            ld [hl], a                      ; +3 movement counter reset
            dec d
            ld b, $40                       ; graphics: $4000 (worlds 0-1) / $4100
            ld a, [cur_world]
            cp 2
            jr c, .g0
            inc b
.g0:        ld h, b
            ld l, c
            ld b, [hl]
            ld a, e                         ; npc_g + slot / 16
            swap a
            add a, low(npc_g)
            ld l, a
            ld a, 0
            adc a, high(npc_g)
            ld h, a
            ld [hl], b
            ret

; the npcs' tiles: graphics g (NPCG_BANK0 + g / 64, $4000 + $100 (g & 63), 16 tiles) -> VRAM
; bank 1 $8200 + $100 slot (as FDF08: PPU $1200 + $100 slot)
npc_gfx:    ld c, 0
.s:         ld a, c
            swap a
            add a, $0A
            ld l, a
            ld h, high(N_OBJ)
            ld a, [hl]
            and a
            jr z, .nx
            ld hl, npc_g
            ld b, 0
            add hl, bc
            ld a, [hl]
            ld b, a
            rlca
            rlca
            and 3
            add a, NPCG_BANK0
            ld [MBC5_BANKL], a
            ld a, b
            and $3F
            add a, $40
            ld h, a
            ld l, 0
            ld a, c
            add a, $82
            ld d, a
            ld e, 0
            push bc
            ld b, 16
            ld a, 1
            call vcopy
            pop bc
.nx:        inc c
            ld a, c
            cp 12
            jr nz, .s
            jp rbank

; ---- each frame (object command 6): movement, sprites (even frames slots 0-11, odd 11-0), then
; one npc's random movement
npc_frame:  ld hl, fcnt
            inc [hl]
            ld a, [npc_oam0]                ; (after the party and the guest)
            and a
            jr nz, .o
            ld a, 16
.o:         ld [oam_p], a
            ld a, [fcnt]
            rrca
            jr c, .odd
            ld l, 0
.ev:        call npc_one
            ld a, l
            add a, 16
            ld l, a
            cp $C0
            jr nz, .ev
            jr .rest
.odd:       ld l, $B0
.od:        call npc_one
            ld a, l
            sub 16
            ld l, a
            jr nc, .od
.rest:      ld a, [oam_p]                   ; the rest of the sprites hidden
            ld l, a
            ld h, high(oam_buf)
.h:         ld a, l
            cp 160
            jr nc, npc_rand
            ld [hl], 0
            add a, 4
            ld l, a
            jr .h

; 3B/AF7F the people's sprites without movement (event effects)
npc_drawall: ld a, [npc_oam0]
            and a
            jr nz, .o
            ld a, 16
.o:         ld [oam_p], a
            ld l, 0
.s:         ld h, high(N_OBJ)
            ld a, [hl]
            and a
            jr z, .n
            push hl
            call npc_upd.draw
            pop hl
.n:         ld a, l
            add a, 16
            ld l, a
            cp $C0
            jr nz, .s
            ld a, [oam_p]
            ld l, a
            ld h, high(oam_buf)
.h:         ld a, l
            cp 160
            ret nc
            ld [hl], 0
            add a, 4
            ld l, a
            jr .h

npc_one:    ld h, high(N_OBJ)
            ld a, [hl]
            and a
            ret z
            push hl
            call npc_upd
            pop hl
            ret

; L3B_B17C: L = slot offset
npc_upd:    ld a, l
            add a, $0D
            ld e, a
            ld d, h
            ld a, [de]                      ; +D touched: moves every frame
            and a
            jr nz, .mv
            inc d                           ; else only when (frame & speed mask) = 0
            ld a, l
            add a, 2
            ld e, a
            ld a, [fcnt]
            ld b, a
            ld a, [de]
            and b
            jr nz, .draw
.mv:        ld d, h
            ld a, l
            add a, 8
            ld e, a
            ld a, [de]                      ; +8 x speed
            and a
            jr z, .vy
            ld b, a
            ld a, l
            add a, 6
            ld e, a
            ld a, [de]
            add a, b
            and $0F
            ld [de], a
            jr nz, .draw
            ld b, 2                         ; arrived: +4 = +2
            jr .arr
.vy:        inc e
            ld a, [de]                      ; +9 y speed
            and a
            jr z, .draw
            ld b, a
            ld a, l
            add a, 7
            ld e, a
            ld a, [de]
            add a, b
            and $0F
            ld [de], a
            jr nz, .draw
            ld b, 3
.arr:       ld a, l
            add a, 8
            ld e, a
            xor a
            ld [de], a                      ; +8, +9
            inc e
            ld [de], a
            ld a, l
            add a, $0C
            ld e, a
            xor a
            ld [de], a                      ; +C, +D
            inc e
            ld [de], a
            ld a, l
            add a, b
            ld e, a
            ld a, [de]
            inc e
            inc e
            ld [de], a
; L3B_B1CD: halfway across a tile: the priority properties (+1) from the tile's
.draw:      ld d, h
            ld a, l
            add a, 6
            ld e, a
            ld a, [de]
            inc e
            ld b, a
            ld a, [de]
            or b
            cp 8
            jr nz, .pos
            inc d
            ld e, l
            ld a, [de]                      ; N_OB2 +0
            ld b, a
            bit 2, a
            jr z, .p1
            ld a, l
            add a, 6
            ld e, a
            ld a, [de]                      ; (on a bridge tile, z-level 1: none)
            rrca
            jr nc, .p1
            ld b, 0
.p1:        ld a, l
            inc a
            ld e, a
            ld a, b
            ld [de], a
; screen position: npc pixel - party pixel (16 bits, map wraps at 1024)
.pos:       ld a, l
            add a, 4
            ld e, a
            ld d, h
            ld a, [de]                      ; x
            add a, a                        ; (6 bits: x 16 < 1024)
            add a, a
            ld c, a
            ld b, 0
            sla c
            rl b
            sla c
            rl b
            ld a, l
            add a, 6
            ld e, a
            ld a, [de]
            or c
            ld c, a                         ; BC = x 16 + sub
            ld a, [ppx_pix]
            ld e, a
            ld a, [ppx_pix + 1]
            ld d, a
            call .rel
            ret c
            add a, PX0 + 8
            ld [spr_x], a
            ld a, l
            add a, 5
            ld e, a
            ld d, h
            ld a, [de]
            add a, a
            add a, a
            ld c, a
            ld b, 0
            sla c
            rl b
            sla c
            rl b
            ld a, l
            add a, 7
            ld e, a
            ld a, [de]
            or c
            ld c, a
            ld a, [ppy_pix]
            ld e, a
            ld a, [ppy_pix + 1]
            ld d, a
            call .rel
            ret c
            add a, PY0 + 16 - 3             ; (FF3 draws objects 3 pixels up: L3B_B1EE, fix:D8CA)
            ld [spr_y], a
            jr .frame
.rel:       ld a, c                         ; A = (BC - DE) mod 1024 as -88..87, C set if out
            sub e
            ld c, a
            ld a, b
            sbc d
            ld b, a
            ld a, c
            add a, 88
            ld c, a
            ld a, b
            adc a, 0
            and 3
            jr nz, .out
            ld a, c
            cp 176
            jr nc, .out
            sub 88
            and a
            ret
.out:       scf
            ret
; frame (L3B_B23E)
.frame:     ld d, h
            ld a, l                         ; touched by the party's A (+D bit 7): this frame
            add a, $0D                      ;   facing the party, frame 0 (L3B_B2C6)
            ld e, a
            ld a, [de]
            bit 7, a
            jr z, .nf
            and $7F
            ld [de], a
            ld a, [facing]
            ld b, $10                       ; party right -> it faces left
            rrca
            jr c, .fp
            ld b, $00
            rrca
            jr c, .fp
            ld b, $30
            rrca
            jr c, .fp
            ld b, $20
.fp:        ld a, l
            add a, $20
            ld [n_tb], a
            ld a, b
            ld [n_face], a
            xor a
            ld [n_fr], a
            jp .an2
.nf:        ld a, l
            inc a
            ld e, a
            ld a, [de]                      ; +1 type
            and $F0
            ld b, a
            ld c, 0                         ; C = tile adjustment
            and a
            jr z, .t0
            bit 7, b
            jr z, .t7
            bit 6, b
            jr z, .st
            bit 4, b
            jr nz, .t4
            ld a, [fcnt]                    ; C0 / E0: every 16 frames
            srl a
            jr .tf
.t4:        ld a, [fcnt]                    ; D0 / F0: every 4 frames
            add a, a
            jr .tf
.t7:        bit 6, b
            jr z, .st
            ld a, [fcnt]                    ; 40-70: every 8 frames
.tf:        ld [n_tmp], a
            and 8
            jr .fr
.st:        xor a                           ; static
            jr .fr
.t0:        ld a, l                         ; 00: walking animation by the subtile position
            add a, 6
            ld e, a
            ld a, [de]
            inc e
            ld c, a
            ld a, [de]
            or c
            add a, a
            and 8
            ld c, 0
.fr:        ld [n_fr], a
            bit 6, b                        ; continuous animation, type & $10, (A & $10):
            jr z, .ad                       ;   the tiles 8 back
            bit 4, b
            jr z, .ad
            ld a, [n_tmp]
            and $10
            jr z, .ad
            ld c, -8
.ad:        ld a, [n_fr]                    ; the one-pixel bob (type 00, frame 1)
            and a
            jr z, .an
            ld a, b
            and a
            jr nz, .an
            ld a, l
            add a, 7
            ld e, a
            ld a, [de]
            and a
            jr z, .bobu
            ld a, [spr_x]
            dec a
            ld [spr_x], a
            jr .an
.bobu:      ld a, [spr_y]
            dec a
            ld [spr_y], a
.an:        ld a, l                         ; tile base = $20 + 16 slot (+ C)
            add a, $20
            add a, c
            ld [n_tb], a
            ld d, h                         ; frame data: N_ANIM + palette + animation + frame
            ld a, l
            add a, $0E
            ld e, a
            ld a, [de]
            ld [n_face], a
.an2:       ld d, h
            ld a, [n_face]
            ld b, a
            ld a, [n_fr]
            add a, b
            ld b, a
            inc d
            ld a, l
            add a, 5
            ld e, a
            ld a, [de]
            add a, b
            ld [n_off], a
            ld a, l
            inc a
            ld e, a
            ld a, [de]                      ; N_OB2 +1: priority flags
            ld [n_pri], a
            ld a, [n_off]
            ld e, a
            ld d, high(N_ANIM)
            ld a, [oam_p]
            ld l, a
            ld h, high(oam_buf)
            ld a, [spr_y]
            ld c, a
            ld a, [spr_x]
            ld b, a
            ld a, [n_pri]                   ; top / bottom halves behind the BG
            and $14
            ld [n_tpri], a
            ld a, [n_pri]
            and $24
            ld [n_bpri], a
            ld a, [n_tpri]
            call .spr                       ; TL
            ld a, c
            add a, 8
            ld c, a
            ld a, [n_bpri]
            call .spr                       ; BL
            ld a, b
            add a, 8
            ld b, a
            ld a, c
            sub 8
            ld c, a
            ld a, [n_tpri]
            call .spr                       ; TR
            ld a, c
            add a, 8
            ld c, a
            ld a, [n_bpri]
            call .spr                       ; BR
            ld a, l
            ld [oam_p], a
            ret
.spr:       push af
            ld a, l
            cp 160
            jr nc, .full
            ld a, c
            ld [hl+], a
            ld a, b
            ld [hl+], a
            ld a, [de]
            inc e
            push hl
            ld hl, n_tb
            add a, [hl]
            pop hl
            ld [hl+], a
            pop af
            and a
            ld a, [de]
            jr z, .np
            xor $80                         ; (behind the BG: CGB OAM bit 7)
.np:        inc e
            ld [hl+], a
            ret
.full:      pop af
            inc e
            inc e
            ret

; L3B_AF97: one npc a frame (n_cur cycles 0-11): stationary types ($80) never move; a counter
; between moves; then a random direction (fix:FE00 table, index n_rnd) if L3B_B110 allows it
npc_rand:   ld a, [ev_on]                   ; (not while an event runs)
            and a
            ret nz
            ld a, [n_cur]
            add a, 16
            and $F0
            cp $C0
            jr c, .c
            xor a
.c:         ld [n_cur], a
            ld l, a
            ld h, high(N_OBJ)
            ld a, [hl]
            and a
            ret z
            inc l
            ld a, [hl]                      ; +1 & $80 | +C
            dec l
            and $80
            ld b, a
            ld a, l
            add a, $0C
            ld e, a
            ld d, h
            ld a, [de]
            or b
            ret nz
            dec e                           ; +B counter
            ld a, [de]
            and a
            jr z, .go
            dec a
            ld [de], a
            ret
.go:        ld a, [n_rnd]
            inc a
            ld [n_rnd], a
            ld e, a
            ld d, high(N_RNG)
            ld a, [de]
; L3B_AFDD: npc L takes a step: A & 3 = 0 right, 1 left, 2 down, 3 up (from its destination)
npc_dir:    ld d, high(N_OBJ)
            push af
            ld a, l
            add a, 2
            ld e, a
            ld a, [de]
            ld b, a                         ; B, C = destination x, y
            inc e
            ld a, [de]
            ld c, a
            pop af
            and 3
            jr z, .right
            dec a
            jr z, .left
            dec a
            jr z, .down
            dec c                           ; up
            ld a, c
            and $3F
            ld c, a
            call npc_try
            ret c
            ld a, l                         ; +3 = +5 = y, +7 = $F, +9 = -1, +C = 4
            add a, 3
            ld e, a
            ld d, h
            ld a, c
            ld [de], a
            inc e
            inc e
            ld [de], a
            inc e
            inc e
            ld a, $0F
            ld [de], a
            inc e
            inc e
            ld a, $FF
            ld [de], a
            ld b, 4
            ld c, $30
            jr .set
.down:      inc c
            ld a, c
            and $3F
            ld c, a
            call npc_try
            ret c
            ld a, l
            add a, 3
            ld e, a
            ld d, h
            ld a, c
            ld [de], a
            ld a, l
            add a, 9
            ld e, a
            ld a, 1
            ld [de], a
            ld b, 8
            ld c, $20
            jr .set
.left:      dec b
            ld a, b
            and $3F
            ld b, a
            call npc_try
            ret c
            ld a, l
            add a, 2
            ld e, a
            ld d, h
            ld a, b
            ld [de], a
            inc e
            inc e
            ld [de], a
            inc e
            inc e
            ld a, $0F
            ld [de], a
            inc e
            inc e
            ld a, $FF
            ld [de], a
            ld b, 2
            ld c, $10
            jr .set
.right:     inc b
            ld a, b
            and $3F
            ld b, a
            call npc_try
            ret c
            ld a, l
            add a, 2
            ld e, a
            ld d, h
            ld a, b
            ld [de], a
            ld a, l
            add a, 8
            ld e, a
            ld a, 1
            ld [de], a
            ld b, 1
            ld c, $00
.set:       ld d, h                         ; +C direction, +E animation (unless type & $50),
            ld a, l                         ;   +B = the counter reset
            add a, $0C
            ld e, a
            ld a, b
            ld [de], a
            ld a, l
            inc a
            ld e, a
            ld a, [de]
            and $50
            jr nz, .cnt
            ld a, l
            add a, $0E
            ld e, a
            ld a, c
            ld [de], a
.cnt:       inc d
            ld a, l
            add a, 3
            ld e, a
            ld a, [de]
            dec d
            ld b, a
            ld a, l
            add a, $0B
            ld e, a
            ld a, b
            ld [de], a
            ret

; L3B_B110: may npc L move to (B, C)? (not onto the party's destination unless on another
; z-level, not onto an impassable / trigger tile or another level, not onto another npc's
; destination); carry set if not; else its tile properties and z-level updated
npc_try:    push bc
            ld a, [n_ev]                    ; (for an event: the tile's properties taken, the
            and a                           ;   step always allowed: L3B_B110)
            jr z, .norm
            inc h
            ld a, l
            add a, 6
            ld e, a
            ld d, h
            dec h
            ld a, [de]
            ld [n_z], a
            jp .tile
.norm:      inc h
            ld a, l
            add a, 6
            ld e, a
            ld d, h
            dec h
            ld a, [de]                      ; z
            ld [n_z], a
            and a
            jr z, .pl
            ld a, [zlev]
            and a
            jr z, .pl
            ld e, a
            ld a, [n_z]
            cp e
            jr nz, .tile
.pl:        ld a, [ppx]
            cp b
            jr nz, .tile
            ld a, [ppy]
            cp c
            jr z, .no
.tile:      push hl
            ld e, b
            ld d, c
            call map_at
            ld l, a
            ld h, high(M_P1)
            ld a, [hl]
            pop hl
            ld [n_p], a
            ld e, a
            ld a, [n_ev]
            and a
            ld a, e
            jr z, .t1
            and 7                           ; (event: the z-level as the rule would leave it)
            jr z, .ez0
            cp 4
            jr nc, .store
            cp 3
            jr z, .store
            ld e, a
            ld a, [n_z]
            or e
            cp 3
            jr z, .store
            ld [n_z], a
            jr .store
.ez0:       ld [n_z], a
            jr .store
.t1:        bit 7, a
            jr nz, .no
            and 7
            jr z, .z0
            cp 4
            jr nc, .oth
            cp 3
            jr z, .no
            ld e, a
            ld a, [n_z]
            or e
            cp 3
            jr z, .no
            ld [n_z], a
            jr .oth
.z0:        ld [n_z], a
.oth:       ld e, 0                         ; other npcs' destinations
.o:         ld a, e
            cp l
            jr z, .on
            ld d, high(N_OBJ)
            ld a, [de]
            and a
            jr z, .on
            ld a, e
            add a, 6
            ld e, a
            inc d
            ld a, [de]                      ; its z-level
            dec d
            ld [n_oz], a
            ld a, e
            sub 6
            ld e, a
            ld a, [n_oz]
            and a
            jr z, .op
            ld a, [n_z]
            and a
            jr z, .op
            ld d, a
            ld a, [n_oz]
            cp d
            ld d, high(N_OBJ)
            jr nz, .on
.op:        ld a, e
            add a, 2
            ld e, a
            ld a, [de]
            cp b
            jr nz, .on0
            inc e
            ld a, [de]
            dec e
            cp c
            jr z, .no
.on0:       ld a, e
            sub 2
            ld e, a
.on:        ld a, e
            add a, 16
            ld e, a
            cp $C0
            jr c, .o
.store:     inc h                           ; N_OB2 +0 = properties & $37, +6 = z
            ld a, [n_p]
            and $37
            ld e, l
            ld d, h
            ld [de], a
            ld a, l
            add a, 6
            ld e, a
            ld a, [n_z]
            ld [de], a
            dec h
            pop bc
            and a
            ret
.no:        pop bc
            scf
            ret

; fix:E3F1: the party's step onto (E, D) is blocked by an npc standing / heading there (it is
; marked touched and its counter shortened); carry set if so
npc_block:  push hl
            ld l, 0
            ld h, high(N_OBJ)
.l:         ld a, [hl]
            and a
            jr z, .n
            inc h
            push hl
            ld a, l
            add a, 6
            ld l, a
            ld a, [hl]
            pop hl
            dec h
            and a
            jr z, .z
            ld b, a
            ld a, [zlev]
            and a
            jr z, .z
            cp b
            jr nz, .n
.z:         inc l
            inc l
            ld a, [hl+]
            cp e
            jr nz, .n3
            ld a, [hl]
            cp d
            jr nz, .n3
            ld a, l                         ; +B &= 3, +D = 1
            add a, 8
            ld l, a
            ld a, [hl]
            and 3
            ld [hl+], a
            inc l
            ld [hl], 1
            pop hl
            scf
            ret
.n3:        ld a, l
            and $F0
            ld l, a
.n:         ld a, l
            add a, 16
            ld l, a
            cp $C0
            jr c, .l
            pop hl
            and a
            ret

section wram, $C340
npc_g:      ds 12
fcnt:       ds 1
oam_p:      ds 1
spr_x:      ds 1
spr_y:      ds 1
n_tmp:      ds 1
n_fr:       ds 1
n_tb:       ds 1
n_off:      ds 1
n_pri:      ds 1
n_tpri:     ds 1
n_bpri:     ds 1
n_cur:      ds 1
n_rnd:      ds 1
n_z:        ds 1
n_oz:       ds 1
n_p:        ds 1
n_face:     ds 1
ppx:        ds 1                            ; the party's destination tile (FF3 $68 / $69)
ppy:        ds 1
ppx_pix:    ds 2                            ; the party's map pixel (x 16 + step), 16 bits
ppy_pix:    ds 2
cur_world:  ds 1
