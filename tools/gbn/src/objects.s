; FF1 native engine: map objects (townspeople, guards, ...) on standard maps. Our own code,
; following what FF1's object routines do (disassembly: LoadMapObjects, MapObjectMove,
; CanMapObjMove, AnimateAndDrawMapObject): 15 slots per map, visible while the object's game
; flag has bit 0 set; one object takes a step per frame (after a wait of 0-7 of its turns, in
; a direction from the frame counter and a seed), one pixel every two frames; stationary ones
; walk in place; in a normal room only the room's objects show (and move).
; Map bank: $7300 slots (id, x + flags, y, sprite tile base) x 15.

M_OBJS     = $7300
O_SIZE     = 16
O_ID       = 0
O_FLG      = 1              ; $80 in a room, $40 stationary
O_PX       = 2
O_PY       = 3
O_GX       = 4
O_GY       = 5
O_CX       = 6
O_CY       = 7
O_SX       = 8
O_SY       = 9
O_TILE     = 10
O_WAIT     = 11
O_FACE     = 12             ; 0 right, 1 left, 2 up, 3 down
O_MOVE     = 13             ; nonzero while stepping
O_TALK     = 14             ; nonzero: face the party (talking)
O_RAW      = 15             ; the slot's object id even while hidden (FF1: mapobj_rawid)
MAX_DRAWN  = 9              ; objects drawn (9 x 4 + the party's 4 = 40 sprites)

section bank 0, $1000

; load the map's objects (map bank mapped by the caller's load_map)
obj_load:   ld hl, objs
            ld de, 15 * O_SIZE
            call memclr
            ldh a, [maptype]
            and a
            ret nz                          ; (none on the overworld)
            ld a, [map_bank]
            ld [MBC_BANK], a
            ld hl, M_OBJS
            ld de, objs
            ld b, 15
.l:         push bc
            ld a, [hl+]                     ; id: shown only while its game flag says visible
            ld c, a                         ;   (the slot kept either way, FF1: rawid)
            and a
            jr z, .none
            push hl
            ld l, c
            ld h, high(game_flags)
            ld a, [hl]
            pop hl
            and 1
            ld a, c
            jr nz, .vis
            xor a
.vis:       ld [de], a                      ; +0 id (0: hidden)
            push de
            ld a, e
            add a, O_RAW
            ld e, a
            ld a, c
            ld [de], a                      ; +15 raw id
            pop de
            inc de
            ld a, [hl+]
            ld c, a
            and $C0
            ld [de], a                      ; +1 flags
            inc de
            ld a, c
            and $3F
            ld [de], a                      ; +2 x
            inc de
            ld b, a
            ld a, [hl+]
            and $3F
            ld [de], a                      ; +3 y
            inc de
            ld c, a
            ld a, b
            ld [de], a                      ; +4 graphic x
            inc de
            ld a, c
            ld [de], a                      ; +5 graphic y
            inc de
            inc de                          ; +6..+9 counters / speeds 0
            inc de
            inc de
            inc de
            ld a, [hl+]
            ld [de], a                      ; +10 tile base
            inc de
            inc de                          ; +11 wait 0
            ld a, 3
            ld [de], a                      ; +12 facing down
            inc de
            inc de
            inc de
            inc de                          ; (+13..+15)
            jr .nx
.none:      inc hl                          ; slot empty: skip its other three bytes
            inc hl
            inc hl
            ld a, e
            add a, O_SIZE
            ld e, a
            jr nc, .nx
            inc d
.nx:        pop bc
            dec b
            jr nz, .l
            ret

; C: the object in slot HL is hidden for the room state (normal room: only the room's
; objects; outside: only the others)
obj_hidden: push hl
            inc hl
            ld a, [inroom]
            and a
            ld a, [hl]
            pop hl
            jr z, .out
            bit 7, a
            scf
            ret z
            and a
            ret
.out:       bit 7, a
            scf
            ret nz
            and a
            ret

; every frame: animate all (a pixel every second frame), step one, draw
obj_frame:  ldh a, [maptype]
            and a
            ret nz
            ld hl, objs
            ld b, 15
.a:         ld a, [hl]
            and a
            call nz, obj_anim
            ld a, l
            add a, O_SIZE
            ld l, a
            jr nc, .an
            inc h
.an:        dec b
            jr nz, .a
            call obj_step
            ret

; HL = slot: one pixel of its step on even frames
obj_anim:   ldh a, [frame]
            and 1
            ret nz
            push hl
            push bc
            ld bc, O_SX
            add hl, bc                      ; HL = +8 (speed x)
            ld a, [hl+]
            ld c, [hl]                      ; C = speed y
            dec hl
            dec hl
            dec hl                          ; HL = +6 (counter x)
            and a
            jr z, .y
            add a, [hl]
            and 15
            ld [hl], a
            jr nz, .x
            xor a                           ; step done: speed 0, graphic = physical
            inc hl
            inc hl
            ld [hl], a                      ; speed x
            pop bc
            pop hl
            jr .done
.y:         inc hl                          ; +7 counter y
            ld a, c
            and a
            jr z, .x
            add a, [hl]
            and 15
            ld [hl], a
            jr nz, .x
            inc hl
            inc hl
            xor a
            ld [hl], a                      ; speed y
            pop bc
            pop hl
            jr .done
.x:         pop bc
            pop hl
            ret
.done:      push hl
            ld a, l                         ; graphic position = physical, not moving
            add a, O_PX
            ld e, a
            ld d, h
            ld a, [de]
            ld c, a
            inc de
            ld a, [de]
            inc de
            ld b, a
            ld a, c
            ld [de], a
            inc de
            ld a, b
            ld [de], a
            pop hl
            push hl
            ld a, l
            add a, O_MOVE
            ld l, a
            ld [hl], 0
            pop hl
            ret

; one object a frame: wait, then a step in a pseudo-random direction if it is free
obj_step:   ld a, [obj_cur]
            inc a
            cp 15
            jr c, .c
            xor a
.c:         ld [obj_cur], a
            swap a                          ; x 16
            ld l, a
            ld h, high(objs)
            ld a, [hl]
            and a
            ret z
            inc hl
            ld a, [hl]                      ; stationary
            dec hl
            and $40
            ret nz
            ld a, l
            add a, O_MOVE
            ld e, a
            ld d, h
            ld a, [de]
            and a
            ret nz                          ; still stepping
            ld a, [inroom]                  ; in a normal room, objects outside it wait
            and a
            jr z, .w
            inc hl
            ld a, [hl]
            dec hl
            bit 7, a
            ret z
.w:         ld a, l
            add a, O_WAIT
            ld e, a
            ld a, [de]
            and a
            jr z, .go
            dec a
            ld [de], a
            ret
.go:        ldh a, [frame]                  ; direction: frame counter + seed (FF1)
            ld b, a
            ld a, [npc_seed]
            add a, b
            ld [npc_seed], a
            and 3
            ld c, a                         ; C: 0 right, 1 left, 2 up, 3 down
            inc hl
            inc hl
            ld a, [hl+]                     ; physical x, y
            ld e, a
            ld a, [hl]
            ld d, a
            dec hl
            dec hl
            dec hl                          ; HL = slot
            ld a, c
            and a
            jr nz, .n0
            inc e
.n0:        cp 1
            jr nz, .n1
            dec e
.n1:        cp 2
            jr nz, .n2
            dec d
.n2:        cp 3
            jr nz, .n3
            inc d
.n3:        ld a, e
            and 63
            ld e, a
            ld a, d
            and 63
            ld d, a
            push hl
            push bc
            push de
            call obj_canmove
            pop de
            pop bc
            pop hl
            ret c
            push hl                         ; physical = target; speed; left / up: graphic =
            inc hl                          ;   target and the counter from 15 down
            inc hl
            ld [hl], e
            inc hl
            ld [hl], d
            pop hl
            push hl
            ld a, l
            add a, O_FACE
            ld l, a
            ld [hl], c
            inc hl
            ld [hl], 1                      ; moving
            pop hl
            push hl
            ld a, c
            and a                           ; right: speed x +1
            jr nz, .s1
            ld a, l
            add a, O_SX
            ld l, a
            ld [hl], 1
            jr .sw
.s1:        cp 1                            ; left: graphic x = target, counter 15, speed -1
            jr nz, .s2
            ld a, l
            add a, O_GX
            ld l, a
            ld [hl], e
            inc hl
            inc hl
            ld [hl], 15
            inc hl
            inc hl
            ld [hl], $FF
            jr .sw
.s2:        cp 2                            ; up: graphic y = target, counter 15, speed -1
            jr nz, .s3
            ld a, l
            add a, O_GY
            ld l, a
            ld [hl], d
            inc hl
            inc hl
            ld [hl], 15
            inc hl
            inc hl
            ld [hl], $FF
            jr .sw
.s3:        ld a, l                         ; down: speed y +1
            add a, O_SY
            ld l, a
            ld [hl], 1
.sw:        pop hl
            ld a, l                         ; the next wait: frame counter & 7 (FF1)
            add a, O_WAIT
            ld l, a
            ldh a, [frame]
            and 7
            ld [hl], a
            ret

; C: (E = x, D = y) is not free for an object: a teleport or blocked tile, the party, or
; another object
obj_canmove:
            ld a, e
            ld [o_tx], a
            ld a, d
            ld [o_ty], a
            call map_at
            call props                      ; D, E = property bytes
            ld a, d
            and $C1                         ; teleport bits or blocked
            scf
            ret nz
            ld a, [px]                      ; the party (where it stands, or is stepping to)
            ld e, a
            ld a, [py]
            ld d, a
            ld a, [moving]
            and a
            jr z, .p
            ld a, [tx]
            ld e, a
            ld a, [ty]
            ld d, a
.p:         ld a, [o_tx]
            cp e
            jr nz, .o
            ld a, [o_ty]
            cp d
            scf
            ret z
.o:         ld a, [o_tx]
            ld e, a
            ld a, [o_ty]
            ld d, a
            ; (falls into obj_at)

; C: an object stands on (E = x, D = y) (its physical position)
obj_at:     ld hl, objs + O_PX
            ld b, 15
.l:         push hl
            ld a, l
            sub O_PX
            ld l, a
            ld a, [hl]                      ; id
            pop hl
            and a
            jr z, .n
            ld a, [hl+]
            cp e
            jr nz, .n1
            ld a, [hl]
            cp d
            jr nz, .n1
            scf
            ret
.n1:        dec hl
.n:         ld a, l
            add a, O_SIZE
            ld l, a
            jr nc, .n2
            inc h
.n2:        dec b
            jr nz, .l
            and a
            ret

; the visible objects into OAM after the party (DE = the next OAM entry); the rest hidden
obj_draw:   ld c, MAX_DRAWN
            ldh a, [maptype]
            and a
            jr nz, .rest
            ld hl, objs
            ld b, 15
.l:         ld a, [hl]
            and a
            jr z, .n
            push bc
            push hl
            call obj_hidden
            jr c, .sk
            call obj_spr                    ; NC: drawn (4 OAM entries)
            pop hl
            pop bc
            jr c, .n
            dec c
            jr z, .rest
            jr .n
.sk:        pop hl
            pop bc
.n:         ld a, l
            add a, O_SIZE
            ld l, a
            jr nc, .n2
            inc h
.n2:        dec b
            jr nz, .l
.rest:      ld a, e                         ; hide what is left
            cp 160
            ret nc
            xor a
            ld [de], a
            inc de
            inc de
            inc de
            inc de
            jr .rest

; HL = slot, DE = OAM: the object's 2 x 2 sprite if it is on screen (NC), else C
obj_spr:    push de
            push hl
            ld a, l                         ; screen x = 72 + 16 (gx - px) + counter x - the
            add a, O_GX                     ;   party's own offset in its step
            ld l, a
            ld a, [px]
            ld b, a
            ld a, [hl]                      ; gx
            sub b
            add a, 32                       ; (wrap to -32..31)
            and 63
            sub 32
            cp $F9                          ; -7 .. 6 metatiles only
            jr nc, .xin
            cp 7
            jr c, .xin
            pop hl
            pop de
            scf
            ret
.xin:       swap a                          ; x 16 (A = signed, the result low byte)
            and $F0
            add a, 72 + 8
            ld b, a
            inc hl
            inc hl                          ; +6 counter x
            ld a, [hl]
            add a, b
            ld b, a
            ld a, [mcount]                  ; minus the party's step offset
            ld c, a
            ld a, [mdx]
            call mulsign
            cpl
            inc a
            add a, b
            ld [o_sx], a
            dec hl                          ; +5 gy
            ld a, [py]
            ld b, a
            ld a, [hl]
            sub b
            add a, 32
            and 63
            sub 32
            cp $FA                          ; -6 .. 5
            jr nc, .yin
            cp 6
            jr c, .yin
            pop hl
            pop de
            scf
            ret
.yin:       swap a
            and $F0
            add a, 64 + 16
            ld b, a
            inc hl
            inc hl                          ; +7 counter y
            ld a, [hl]
            add a, b
            ld b, a
            ld a, [mcount]
            ld c, a
            ld a, [mdy]
            call mulsign
            cpl
            inc a
            add a, b
            ld [o_sy], a
            ld b, a                         ; (under the dialogue box: hidden)
            ld a, [box_on]
            and a
            jr z, .vis
            ld a, b
            cp BOX_LINES + 16
            jr nc, .vis
            pop hl
            pop de
            scf
            ret
.vis:       pop hl                          ; slot
            push hl
            ld a, l                         ; the 2 x 2 table: facing x 16 + frame x 8
            add a, O_TALK
            ld e, a
            ld d, h
            ld a, [de]
            and a
            jr z, .nt
            xor a                           ; (talking: face the party, standing)
            ld [de], a
            ld a, [facing]                  ; party right -> object left, left -> right,
            xor 1                           ;   up -> down, down -> up
            bit 1, a
            jr z, .ft
            ld a, [facing]
            xor 1
.ft:        add a, a
            jr .tb
.nt:        ld a, l
            add a, O_FACE
            ld e, a
            ld a, [de]
            add a, a                        ; facing x 2 (x 8 below = 16 bytes a direction)
            ld b, a
            push hl
            inc hl                          ; flags: stationary walk in place
            ld a, [hl]
            pop hl
            and $40
            jr z, .wk
            ldh a, [frame]
            rrca
            jr .fr
.wk:        ld a, l
            add a, O_CX
            ld e, a
            ld a, [de]
            inc de
            ld c, a
            ld a, [de]
            or c
            rlca
.fr:        and 8
            jr z, .f0
            inc b
.f0:        ld a, b
.tb:        add a, a                        ; x 8
            add a, a
            add a, a
            ld c, a
            ld a, l
            add a, O_TILE
            ld e, a
            ld d, h
            ld a, [de]
            ld [o_tb], a
            ld a, COMMON
            ld [MBC_BANK], a
            ld l, c
            ld h, high(C_OBJTBL)
            pop de                          ; (slot, unused now)
            pop de                          ; OAM
            ld a, [o_sy]
            ld b, a
            ld a, [o_sx]
            ld c, a
            call .two
            ld a, c
            add a, 8
            ld c, a
            ld a, [o_sy]
            ld b, a
            call .two
            and a
            ret
.two:       call .one                       ; UL / UR, then DL / DR below
            ld a, b
            add a, 8
            ld b, a
.one:       ld a, b
            ld [de], a
            inc de
            ld a, c
            ld [de], a
            inc de
            ld a, [o_tb]
            add a, [hl]
            inc hl
            ld [de], a
            inc de
            ld a, [hl+]                     ; NES attributes -> GB: flip, CGB palette
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

; HL = slot -> A = dialogue (talk routines: talk.s)
