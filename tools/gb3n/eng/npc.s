; FF3 native port: map objects (people), written from what the everything8215/ff3 listing says FF3
; does (3B/B2FD load npcs, 3B/AEEB update npcs, 3B/B17C npc sprites, 3B/AF97 random movement, 3B/B0C5
; / B110 npc passability, 3B/ACD1 npc event commands, 3F/E3F1 touching, 3F/E494 check npcs). Our own
; code. FF3's object layout kept: 12 objects of 16 bytes in O0 ($7000) and O1 ($7100):
;   O0 +0 shown (npc id or 0), +1 movement type, +2 / +3 destination x / y, +4 / +5 x / y,
;      +6 / +7 subtile x / y, +8 / +9 x / y speed, +A npc id, +B movement counter, +C moving
;      direction, +D touched by the player (bit 7: face the player), +E / +F animation pointer
;   O1 +0 / +1 tile properties (layer), +2 animation speed (frame mask), +3 movement delay,
;      +5 palette combination ($40 each), +6 z-level
; Sprites: the npc in slot i uses sprite tiles $20 + 16 i (VRAM bank 1), as FF3's pattern table.

C_NPCANIM  = $5400          ; COMMON: 3B/B41A npc animation data (256)
C_RND      = $5500          ; 3F/FE00 the random number table (256)
C_FF3ASC   = $5600          ; FF3's letters -> our font
C_NPCGID   = $5700          ; 00/9400 npc id -> graphics id (256), world 2+: 00/9500
C_NPCSPD   = $5900          ; 01/BE00 npc speeds (world 0), 01/BF00 the others
C_NPCPTR   = $5B00          ; 2C/8000 npc list pointers (512, NES addresses)

section bank 0, $1800

; ---- FF3 load npcs (3B/B2FD): the map's npc list (map properties byte 4) into the objects
npc_load:   ld hl, O0                       ; (FF3 clears $7000-$70FF)
            ld de, $100
            call memclr
            ld a, [mrec + 16 + 4]
            ld l, a
            ld h, 0
            add hl, hl
            ld de, C_NPCPTR
            add hl, de
            ld a, COMMON
            call sbank
            ld a, [hl+]
            ld h, [hl]                      ; (NES $8000-$9FFF: bank 2C; | $80 in FF3)
            ld l, a
            set 7, h
            res 6, h                        ; -> GB $4000 + (address & $3FFF) in SCRIPT
            ld a, SCRIPT
            call sbank
            ld bc, O0                       ; BC = the object
.l:         ld a, [hl]
            and a
            ret z
            push hl
            push bc
            call npc_one
            pop bc
            pop hl
            ld de, 4
            add hl, de
            ld a, c
            add a, $10
            ld c, a
            cp $C0
            jr c, .l
            ret

; one npc: HL = its 4 bytes (id, x, y, aaaabbcc), BC = its object (O0 + 16 i)
npc_one:    ld a, [hl+]
            ld [npc_id], a
            ld a, [hl+]
            ld [npc_x], a
            ld a, [hl+]
            ld [npc_y], a
            ld a, [hl]
            ld [npc_b3], a
            ld h, b
            ld l, c
            push hl
            ld de, $0A
            add hl, de
            ld a, [npc_id]
            ld [hl], a                      ; +A id
            pop hl
            ld a, [npc_id]                  ; +0 shown if its npc switch is on (3B/B51A)
            push bc
            call nsw_at
            and [hl]
            pop bc
            ld h, b
            ld l, c
            ld a, 0
            jr z, .h
            ld a, [npc_id]
.h:         ld [hl+], a                     ; +0
            ld a, [npc_b3]                  ; +1 movement type
            and $F0
            ld [hl+], a
            ld a, [npc_x]
            ld [hl+], a                     ; +2
            ld a, [npc_y]
            ld [hl+], a                     ; +3
            ld a, [npc_x]
            ld [hl+], a                     ; +4
            ld a, [npc_y]
            ld [hl+], a                     ; +5
            xor a
            ld [hl+], a                     ; +6 .. +9
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            inc hl                          ; (+A set)
            ld [hl+], a                     ; +B, +C, +D
            ld [hl+], a
            ld [hl+], a
            ld a, [npc_b3]                  ; +E / +F the animation pointer by direction (3B/B3F8:
            and 3                           ;   0 down, 1 up, 2 left, 3 right)
            ld e, a
            ld d, 0
            push hl
            ld hl, .dir
            add hl, de
            ld a, [hl]
            pop hl
            add a, low(C_NPCANIM)
            ld [hl+], a
            ld a, high(C_NPCANIM)
            ld [hl], a
            ld h, high(O1)                  ; O1 +5 palette: bits 2-3 << 4 & $C0
            ld l, c
            ld a, [npc_b3]
            swap a
            and $C0
            push hl
            ld de, 5
            add hl, de
            ld [hl], a
            pop hl
            ld a, [npc_x]                   ; its tile (3B/B0C5) -> O1 +0 / +1 its layer, +6 z
            ld [z84], a
            ld a, [npc_y]
            ld [z85], a
            xor a
            ld [z86], a
            push hl
            call npc_pass
            ld a, [z67]
            call tile_p1
            and $37
            pop hl
            ld [hl+], a
            ld [hl-], a
            and 3
            push hl
            ld de, 6
            add hl, de
            ld [hl], a
            pop hl
            ld a, COMMON                    ; O1 +2 / +3 the speeds (01/BE00 by id, world 0;
            call sbank                      ;   01/BF00 elsewhere)
            ld a, [npc_id]
            ld e, a
            ld d, 0
            push hl
            ld hl, C_NPCSPD
            ld a, [world]
            and a
            jr z, .w0
            inc h
.w0:        add hl, de
            ld a, [hl]
            pop hl
            inc hl
            inc hl
            ld b, a
            and $0F
            ld [hl+], a                     ; +2 animation speed
            ld a, b
            swap a
            and $0F
            ld [hl], a                      ; +3 movement delay
            ld a, SCRIPT
            jp sbank
.dir:       db $20, $30, $10, $00           ; (down, up, left, right: 3B/B43A / B44A / B42A / B41A)

; A = metatile -> A = its property byte 1 (WRAM bank 2's table)
tile_p1:    ld e, a
            ld d, high(W_P1)
            ld a, 2
            ldh [rSVBK], a
            ld a, [de]
            ld b, a
            ld a, 1
            ldh [rSVBK], a
            ld a, b
            ret

; ---- the npcs' graphics (3E/DF08): each slot's 16 tiles to sprite tiles $20 + 16 i (VRAM bank 1),
; converted at build time per graphics id; LCD off
npc_gfx:    ld c, 0
.l:         ld a, c
            swap a
            ld l, a
            ld h, high(O0)
            ld de, $0A
            add hl, de
            ld a, [hl]
            and a
            jr z, .n
            ld e, a                         ; the graphics id
            ld d, 0
            ld a, COMMON
            call sbank
            ld hl, C_NPCGID
            ld a, [world]
            cp 2
            jr c, .w
            inc h
.w:         add hl, de
            ld a, [hl]                      ; bank NPCGFX + id / 64, $4000 + 256 (id & 63)
            ld b, a
            rlca
            rlca
            and 3
            add a, NPCGFX
            call sbank
            ld a, b
            and $3F
            add a, $40
            ld h, a
            ld l, 0
            ld a, c                         ; -> VRAM bank 1 $8200 + $100 i
            add a, $82
            ld d, a
            ld e, 0
            ld a, 1
            ldh [rVBK], a
            push bc
            ld bc, 256
            call memcpy
            pop bc
            xor a
            ldh [rVBK], a
.n:         inc c
            ld a, c
            cp 12
            jr c, .l
            ret

; ---- FF3 check npc passability (3B/B0C5): z84 / z85 the tile, z86 the z-level -> C impassable,
; z67 the tile
npc_pass:   ld a, [z84]
            ld e, a
            ld a, [z85]
            ld d, a
            call map_at
            ld [z67], a
            call tile_p1
            bit 7, a
            jr nz, .no
            and 7
            jr z, .st
            cp 4
            jr nc, .ok
            cp 3
            jr z, .no
            ld b, a
            ld a, [z86]
            or b
            cp 3
            jr z, .no
            ld [z86], a
.ok:        and a
            ret
.no:        scf
            ret
.st:        xor a
            ld [z86], a
            ret

; FF3 move npc (3B/B110): X (HL = O0 + slot) may move to z84 / z85: not onto the party, another
; npc on its z-level; during an event the tile alone decides. C: no
npc_canmv:  ld a, [z6C]
            and a
            jr z, .free
            push hl
            call npc_pass
            pop hl
            ret c
            jr .set
.free:      ld a, [z86]                     ; (the party, unless on another z-level)
            and a
            jr z, .pp
            ld a, [zA5]
            and a
            jr z, .pp
            ld b, a
            ld a, [z86]
            cp b
            jr nz, .np
.pp:        ld a, [z84]
            ld b, a
            ld a, [px]
            cp b
            jr nz, .np
            ld a, [z85]
            ld b, a
            ld a, [py]
            cp b
            jr nz, .np
            scf
            ret
.np:        push hl
            call npc_pass
            pop hl
            ret c
            ld de, O0                       ; another npc there
.o:         ld a, e
            cp l
            jr z, .on
            ld a, [de]
            and a
            jr z, .on
            push de
            inc d                           ; (O1 +6: its z-level)
            ld a, e
            add a, 6
            ld e, a
            ld a, [de]
            pop de
            and a
            jr z, .zz
            ld b, a
            ld a, [z86]
            and a
            jr z, .zz
            cp b
            jr nz, .on
.zz:        push de
            inc e
            inc e
            ld a, [de]                      ; +2 / +3 its destination
            ld b, a
            inc e
            ld a, [de]
            ld c, a
            pop de
            ld a, [z84]
            cp b
            jr nz, .on
            ld a, [z85]
            cp c
            jr nz, .on
            scf
            ret
.on:        ld a, e
            add a, $10
            ld e, a
            cp $C0
            jr c, .o
.set:       push hl                         ; O1 +0 / +6: its tile's layer and z-level
            ld a, [z67]
            call tile_p1
            and $37
            pop hl
            inc h
            ld [hl], a
            push hl
            ld a, l
            add a, 6
            ld l, a
            ld a, [z86]
            ld [hl], a
            pop hl
            dec h
            and a
            ret

; ---- FF3 npc step (3B/AFDD): HL = O0 + slot, A & 3 = direction (0 right, 1 left, 2 down, 3 up)
npc_step:   and 3
            ld c, a
            push hl                         ; z86 = its z-level (O1 +6)
            inc h
            ld de, 6
            add hl, de
            ld a, [hl]
            ld [z86], a
            pop hl
            push hl
            inc hl                          ; z84 / z85 from +2 / +3 (the destination: here)
            inc hl
            ld a, [hl+]
            ld [z84], a
            ld a, [hl]
            ld [z85], a
            pop hl
            ld a, c
            cp 2
            jr c, .lr
            jr nz, .up
            ld a, [z85]                     ; down
            inc a
            and 63
            ld [z85], a
            call npc_canmv
            ret c
            ld a, [z85]
            ld e, 3
            call .o0
            ld e, 9
            ld a, 1
            call .o0
            ld a, 8
            ld b, $20
            jr .fin
.up:        ld a, [z85]
            dec a
            and 63
            ld [z85], a
            call npc_canmv
            ret c
            ld a, [z85]
            ld e, 3
            call .o0
            ld e, 5
            call .o0
            ld e, 9
            ld a, $FF
            call .o0
            ld e, 7
            ld a, $0F
            call .o0
            ld a, 4
            ld b, $30
            jr .fin
.lr:        and a
            jr z, .rt
            ld a, [z84]                     ; left
            dec a
            and 63
            ld [z84], a
            call npc_canmv
            ret c
            ld a, [z84]
            ld e, 4
            call .o0
            ld e, 2
            call .o0
            ld e, 8
            ld a, $FF
            call .o0
            ld e, 6
            ld a, $0F
            call .o0
            ld a, 2
            ld b, $10
            jr .fin
.rt:        ld a, [z84]
            inc a
            and 63
            ld [z84], a
            call npc_canmv
            ret c
            ld a, [z84]
            ld e, 2
            call .o0
            ld e, 8
            ld a, 1
            call .o0
            ld a, 1
            ld b, $00
.fin:       ld e, $0C                       ; +C the direction; the animation unless it turns
            call .o0                        ;   by itself (+1 & $50)
            push hl
            inc hl
            ld a, [hl]
            pop hl
            and $50
            jr nz, .rs
            ld e, $0E
            ld a, b
            add a, low(C_NPCANIM)
            call .o0
            ld e, $0F
            ld a, high(C_NPCANIM)
            call .o0
.rs:        inc h                           ; +B = O1 +3 (the delay)
            push hl
            inc hl
            inc hl
            inc hl
            ld a, [hl]
            pop hl
            dec h
            ld e, $0B
.o0:        push hl                         ; O0 + slot + E = A
            push af
            ld a, l
            add a, e
            ld l, a
            pop af
            ld [hl], a
            pop hl
            ret

; ---- FF3 event commands $00-$BF (3B/ACD1): object (cmd >> 4), command cmd & 15
npc_cmd:    ld a, [z70]
            and $F0
            ld l, a
            ld h, high(O0)
            push hl
            ld de, $0C
            add hl, de
            ld a, [hl]
            pop hl
            and a
            jr z, .go
            ld hl, z17                      ; still moving: the command again next frame
            inc [hl]
            ret
.go:        ld a, [z70]
            and $0F
            cp 4
            jp c, npc_step                  ; 0-3: a step
            cp 8
            jr nc, .c8
            and 3                           ; 4-7: face (right, left, down, up)
            ld e, a
            ld d, 0
            push hl
            ld hl, npc_dirp
            add hl, de
            ld a, [hl]
            pop hl
            add a, low(C_NPCANIM)
            ld de, $0E
            add hl, de
            ld [hl+], a
            ld [hl], high(C_NPCANIM)
            ret
.c8:        jr nz, .c9
            push hl                         ; 8: shown
            ld de, $0A
            add hl, de
            ld a, [hl]
            pop hl
            ld [hl], a
            ret
.c9:        cp 9
            jr nz, .cc
            ld [hl], 0                      ; 9: hidden
            ret
.cc:        cp $0C                          ; C / D: the walking animation always / not
            jr nz, .cd
            inc hl
            set 6, [hl]
            ret
.cd:        cp $0D
            ret nz                          ; (A / B jumps, E / F circles: with the scenes)
            inc hl
            ld a, [hl]
            and $B0
            ld [hl], a
            ret
npc_dirp:   db $00, $10, $20, $30           ; right, left, down, up

; ---- FF3 update npcs (3B/AEEB) with the sprites (3B/B17C): movement, then their sprites into OAM
; from entry 8; even frames in order, odd frames backwards; then one npc's random movement
npc_frame:  ld a, $20
            ld [spr_at], a
            ld a, [zF0]
            rrca
            jr c, .odd
            ld l, 0
.e:         ld h, high(O0)
            ld a, [hl]
            and a
            call nz, npc_upd
            ld a, l
            add a, $10
            ld l, a
            cp $C0
            jr c, .e
            jr .rnd
.odd:       ld l, $B0
.o:         ld h, high(O0)
            ld a, [hl]
            and a
            call nz, npc_upd
            ld a, l
            sub $10
            ld l, a
            jr nc, .o
.rnd:       ld a, [spr_at]                  ; (the rest hidden)
            ld l, a
            ld h, high(oam_buf)
.hd:        ld a, l
            cp 160
            jr nc, npc_rand
            ld [hl], 0
            ld a, l
            add a, 4
            ld l, a
            jr .hd

; FF3 update random npc movement (3B/AF97): one npc every call
npc_rand:   ld a, [z6C]
            and a
            ret nz
            ld a, [z4A]
            add a, $10
            and $F0
            cp $C0
            jr c, .s
            xor a
.s:         ld [z4A], a
            ld l, a
            ld h, high(O0)
            ld a, [hl]
            and a
            ret z
            push hl
            inc hl
            ld a, [hl]
            and $80
            ld b, a
            ld de, $0B
            add hl, de
            ld a, [hl]                      ; +C
            or b
            pop hl
            ret nz
            push hl
            ld de, $0B
            add hl, de
            ld a, [hl]
            and a
            jr z, .go
            dec [hl]
            pop hl
            ret
.go:        pop hl
            push hl                         ; z86 = its z-level
            inc h
            ld de, 6
            add hl, de
            ld a, [hl]
            ld [z86], a
            pop hl
            ld a, [zF4]
            inc a
            ld [zF4], a
            ld e, a
            ld d, 0
            push hl
            ld a, COMMON
            call sbank
            ld hl, C_RND
            add hl, de
            ld a, [hl]
            pop hl
            jp npc_step

; one npc (HL = O0 + slot): its step this frame (3B/B17C), its sprite
npc_upd:    push hl
            ld de, $0D
            add hl, de
            ld a, [hl]
            pop hl
            and a
            jr nz, .mv                      ; (touched: every frame)
            inc h                           ; frame & O1 +2: moving this frame?
            inc hl
            inc hl
            ld a, [zF0]
            and [hl]
            ld b, a
            dec hl
            dec hl
            dec h
            ld a, b
            and a
            jr nz, npc_spr
.mv:        push hl
            ld de, 8
            add hl, de
            ld a, [hl]                      ; +8 x speed
            and a
            jr z, .vy
            dec hl
            dec hl
            add a, [hl]                     ; +6
            and $0F
            ld [hl], a
            pop hl
            jr nz, npc_spr
            push hl                         ; arrived
            call .stop
            ld de, 2
            add hl, de
            ld a, [hl]
            inc hl
            inc hl
            ld [hl], a                      ; +4 = +2
            pop hl
            jr npc_spr
.vy:        inc hl                          ; +9 y speed
            ld a, [hl]
            and a
            jr z, .no
            dec hl
            dec hl
            add a, [hl]                     ; +7
            and $0F
            ld [hl], a
            pop hl
            jr nz, npc_spr
            push hl
            call .stop
            ld de, 3
            add hl, de
            ld a, [hl]
            inc hl
            inc hl
            ld [hl], a                      ; +5 = +3
            pop hl
            jr npc_spr
.no:        pop hl
            jr npc_spr
.stop:      push hl
            ld de, 8
            add hl, de
            xor a
            ld [hl+], a                     ; +8 / +9 speeds
            ld [hl+], a
            inc hl
            inc hl
            ld [hl+], a                     ; +C, +D
            ld [hl], a
            pop hl
            ret

; FF3 update npc sprites (no movement) (3B/B1CD): its layer at the halfway point, its place on the
; screen (relative to the party: the party at (72, 64)), its frame, 4 sprites
npc_spr:    ld a, l
            ld [npc_o], a
            push hl
            ld de, 6
            add hl, de
            ld a, [hl+]
            or [hl]
            pop hl
            cp 8
            jr nz, .pos
            inc h                           ; halfway: O1 +1 from O1 +0 (0 on a bridge's top)
            ld a, [hl]
            bit 2, a
            jr z, .t
            push hl
            ld de, 6
            add hl, de
            ld a, [hl]
            pop hl
            rrca
            jr nc, .t0
            xor a
            jr .t
.t0:        ld a, [hl]
.t:         inc hl
            ld [hl-], a
            dec h
.pos:       push hl                         ; y: (y - py + 8) & 63 in 3..13
            ld de, 5
            add hl, de
            ld a, [py]
            ld b, a
            ld a, [hl]
            sub b
            add a, 8
            and 63
            cp 3
            jr c, .off
            cp 14
            jr nc, .off
            swap a                          ; d * 16 + subtile y - the party's y offset
            ld b, a
            inc hl
            inc hl
            ld a, [hl]                      ; +7
            add a, b
            ld b, a
            ld a, [mdy]
            ld c, a
            ld a, [mcount]
            call ofs_sub
            sub 48                          ; -> OAM y (64 + 16 - 128 + ...)
            ld [spr_y], a
            pop hl
            push hl
            ld de, 4
            add hl, de
            ld a, [px]
            ld b, a
            ld a, [hl]
            sub b
            add a, 8
            and 63
            cp 2
            jr c, .off
            cp 15
            jr nc, .off
            swap a
            ld b, a
            inc hl
            inc hl
            ld a, [hl]                      ; +6
            add a, b
            ld b, a
            ld a, [mdx]
            ld c, a
            ld a, [mcount]
            call ofs_sub
            sub 48                          ; -> OAM x (72 + 8 - 128 + ...)
            ld [spr_x], a
            pop hl
            jr .frame
.off:       pop hl
            ret
.frame:     ld a, [spr_at]                  ; (no OAM entries left: not drawn)
            cp 160
            ret nc
            push hl
            ld de, $0D
            add hl, de
            ld a, [hl]
            pop hl
            bit 7, a
            jp nz, npc_face                 ; (touched: facing the party)
            push hl
            inc hl
            ld a, [hl]                      ; movement type
            pop hl
            and $F0
            jr z, .walk
            add a, a
            jr nc, .m0
            add a, a                        ; msb set
            jr nc, .stat
            add a, a
            add a, a
            jr nc, .e2
            jr .e4
.m0:        add a, a                        ; msb clear
            jr c, .e8
.stat:      xor a                           ; 80 / 20: still
            ld [npc_t0], a
            jr .fr
.e2:        ld a, [zF0]                     ; C0 / E0: every 2 frames
            srl a
            ld [npc_t0], a
            and 8
            jr .fr
.e8:        ld a, [zF0]                     ; 40: every 8
            ld [npc_t0], a
            and 8
            jr .fr
.e4:        ld a, [zF0]                     ; D0 / F0: every 4
            add a, a
            ld [npc_t0], a
            and 8
            jr .fr
.walk:      push hl                         ; 00: walking, the frame halfway across the tile
            ld de, 6
            add hl, de
            ld a, [hl+]
            or [hl]
            pop hl
            add a, a
            and 8
.fr:        ld [npc_fr], a
            push hl                         ; the animation pointer + frame
            ld de, $0E
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld a, [npc_fr]
            add a, l
            ld [npc_ap], a
            ld a, h
            ld [npc_ap + 1], a
            pop hl
            ld a, l                         ; the tile offset: $20 + 16 slot
            add a, $20
            ld [npc_toff], a
            push hl
            inc hl
            ld a, [hl]
            pop hl
            bit 6, a                        ; (the continuous animation, type bit 4: the frame
            jr z, .nc                       ;   - 8 every other count)
            bit 4, a
            jr z, .nc
            ld a, [npc_t0]
            and $10
            jr z, .nc
            ld a, [npc_toff]
            sub 8
            ld [npc_toff], a
.nc:        ld a, [npc_fr]                  ; (a walking frame: one pixel up / left)
            and a
            jr z, npc_draw
            push hl
            inc hl
            ld a, [hl]
            pop hl
            and $F0
            jr nz, npc_draw
            push hl
            ld de, 7
            add hl, de
            ld a, [hl]
            pop hl
            and a
            ld hl, spr_y
            jr z, .dy
            ld hl, spr_x
.dy:        dec [hl]
            jr npc_draw

; touched: facing the party (3B/B2C6)
npc_face:   push hl
            ld de, $0D
            add hl, de
            res 7, [hl]
            pop hl
            ld a, l
            add a, $20
            ld [npc_toff], a
            ld a, [z33]
            ld b, $20                       ; (the party facing up: the npc down)
            rrca
            jr nc, .l
            ld b, $10                       ; (right: left)
            jr .s
.l:         rrca
            jr nc, .d
            ld b, $00                       ; (left: right)
            jr .s
.d:         rrca
            jr nc, .s
            ld b, $30                       ; (down: up)
.s:         ld a, b
            add a, low(C_NPCANIM)
            ld [npc_ap], a
            ld a, high(C_NPCANIM)
            ld [npc_ap + 1], a
; FF3 draw npc sprite (3B/AEAD): palette combination + animation data, 4 sprites, the layer
npc_draw:   ld a, [npc_o]
            ld l, a
            ld h, high(O1)
            push hl
            ld de, 5
            add hl, de
            ld a, [hl]                      ; O1 +5 the palette combination
            pop hl
            ld b, a
            ld a, [npc_ap]
            add a, b
            ld e, a
            ld a, [npc_ap + 1]
            adc a, 0
            ld d, a
            ld a, COMMON
            call sbank
            ld a, [spr_at]
            ld l, a
            ld h, high(oam_buf)
            ld a, [spr_y]
            ld b, a
            ld a, [spr_x]
            ld c, a
            call obj_put                    ; UL
            ld a, b
            add a, 8
            ld b, a
            call obj_put                    ; DL
            ld a, b
            sub 8
            ld b, a
            ld a, c
            add a, 8
            ld c, a
            call obj_put                    ; UR
            ld a, b
            add a, 8
            ld b, a
            call obj_put                    ; DR
            ld a, l
            ld [spr_at], a
            ld a, [npc_o]                   ; the layer: O1 +1 & $24 the lower two, & $14 the upper
            ld l, a
            ld h, high(O1)
            inc hl
            ld a, [hl]
            ld [npc_ly], a
            ld a, [spr_at]
            sub 16
            ld l, a
            ld h, high(oam_buf)
            ld a, [npc_ly]
            and $24
            jr z, .lo
            push hl
            ld de, 4 + 3
            add hl, de
            ld a, [hl]
            xor $80
            ld [hl], a
            ld de, 8
            add hl, de
            ld a, [hl]
            xor $80
            ld [hl], a
            pop hl
.lo:        ld a, [npc_ly]
            and $14
            jr z, .x
            ld de, 3
            add hl, de
            ld a, [hl]
            xor $80
            ld [hl], a
            ld de, 8
            add hl, de
            ld a, [hl]
            xor $80
            ld [hl], a
.x:         ld a, [npc_o]
            ld l, a
            ld h, high(O0)
            ret

; one sprite: DE = (tile, NES attributes), B = y, C = x, + npc_toff -> OAM at HL
obj_put:    ld a, b
            ld [hl+], a
            ld a, c
            ld [hl+], a
            ld a, [de]
            inc de
            push bc
            ld b, a
            ld a, [npc_toff]
            add a, b
            ld [hl+], a
            ld a, [de]
            inc de
            ld b, a
            and 3
            or $08
            bit 6, b
            jr z, .f
            set 5, a
.f:         bit 5, b
            jr z, .p
            set 7, a
.p:         ld [hl+], a
            pop bc
            ret

; B = 16 d + subtile, C = the party's step direction (-1 / 0 / 1), A = its step count ->
; A = B - C * A
ofs_sub:    ld e, a
            ld a, c
            and a
            ld a, b
            ret z
            bit 7, c
            jr nz, .n
            sub e
            ret
.n:         add a, e
            ret

; ---- FF3 check if player is touching an npc (3F/E3F1): the tile ahead (tx / ty) taken by an npc
; on the party's z-level (or one walking onto it): C, the npc marked touched
npc_touch:  ld l, 0
.l1:        ld h, high(O1)
            push hl
            ld de, 6
            add hl, de
            ld a, [hl]
            pop hl
            dec h
            and a
            jr z, .a
            ld b, a
            ld a, [zA5]
            and a
            jr z, .a
            cp b
            jr nz, .n1
.a:         ld a, [hl]
            and a
            jr z, .n1
            push hl
            inc hl
            inc hl
            ld a, [tx]
            cp [hl]
            jr nz, .p1
            inc hl
            ld a, [ty]
            cp [hl]
            jr nz, .p1
            pop hl
            push hl                         ; +B &= 3, +D = 1
            ld de, $0B
            add hl, de
            ld a, [hl]
            and 3
            ld [hl+], a
            inc hl
            ld [hl], 1
            pop hl
            scf
            ret
.p1:        pop hl
.n1:        ld a, l
            add a, $10
            ld l, a
            cp $C0
            jr c, .l1
            ld l, 0                         ; (second pass: the npc's own tile, ahead by its
.l2:        ld a, [zA5]                     ;   moving direction: marked, still passable)
            and a
            jr z, .b
            ld h, high(O1)
            push hl
            ld de, 6
            add hl, de
            ld a, [hl]
            pop hl
            ld h, high(O0)
            and a
            jr z, .b
            ld b, a
            ld a, [zA5]
            cp b
            jr nz, .n2
.b:         ld h, high(O0)
            ld a, [hl]
            and a
            jr z, .n2
            push hl
            ld de, 4
            add hl, de
            ld a, [hl+]
            ld b, a                         ; B = x, C = y (+4 / +5)
            ld a, [hl]
            ld c, a
            pop hl
            push hl
            ld de, 8
            add hl, de
            ld a, [hl+]
            bit 7, a                        ; x speed < 0: x + 1
            jr z, .xs
            inc b
            jr .tq
.xs:        ld a, [hl]                      ; y speed < 0: y + 1
            bit 7, a
            jr z, .tq
            inc c
.tq:        pop hl
            ld a, b
            and 63
            ld b, a
            ld a, c
            and 63
            ld c, a
            ld a, [tx]
            cp b
            jr nz, .n2
            ld a, [ty]
            cp c
            jr nz, .n2
            push hl
            ld de, $0D
            add hl, de
            ld [hl], 1
            pop hl
            and a
            ret
.n2:        ld a, l
            add a, $10
            ld l, a
            cp $C0
            jr c, .l2
            and a
            ret

; ---- FF3 check npcs (3F/E494): the npc on the tile ahead (tx / ty) -> C, L = its object; it turns
; to the party unless its type says not (+1 & $30)
npc_ahead:  ld l, 0
.l:         ld h, high(O1)
            push hl
            ld de, 6
            add hl, de
            ld a, [hl]
            pop hl
            ld h, high(O0)
            and a
            jr z, .a
            cp 3
            jr z, .a
            ld b, a
            ld a, [zA5]
            and a
            jr z, .a
            cp b
            jr nz, .n
.a:         ld a, [hl]
            and a
            jr z, .n
            push hl
            ld de, 4
            add hl, de
            ld c, [hl]                      ; x + (subtile x >= 8)
            inc hl
            inc hl
            ld a, [hl]
            dec hl
            dec hl
            cp 8
            ccf
            ld a, c
            adc a, 0
            and 63
            ld b, a
            ld a, [tx]
            cp b
            jr nz, .p
            inc hl                          ; y + (subtile y >= 8)
            ld c, [hl]
            inc hl
            inc hl
            ld a, [hl]
            cp 8
            ccf
            ld a, c
            adc a, 0
            and 63
            ld b, a
            ld a, [ty]
            cp b
            jr nz, .p
            pop hl
            push hl
            inc hl
            ld a, [hl]
            pop hl
            and $30
            jr nz, .y
            push hl
            ld de, $0D
            add hl, de
            set 7, [hl]
            pop hl
.y:         scf
            ret
.p:         pop hl
.n:         ld a, l
            add a, $10
            ld l, a
            cp $C0
            jr c, .l
            and a
            ret

section wram, $C940
npc_id:     ds 1
npc_x:      ds 1
npc_y:      ds 1
npc_b3:     ds 1
spr_at:     ds 1
spr_x:      ds 1
spr_y:      ds 1
npc_o:      ds 2
npc_ap:     ds 2
npc_toff:   ds 1
npc_fr:     ds 1
npc_t0:     ds 1
npc_ly:     ds 1
z67:        ds 1
