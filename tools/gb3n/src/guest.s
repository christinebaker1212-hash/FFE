; ---- the guest NPC (FF3 $600B: the companion walking behind the party; 3D/B627 init, 3D/B6DA
; its movement queue, 3D/B716 / B78A following, 3E/DB58 its sprite, 3B/BA5D its graphics, fix:EA56
; talking to it with B). Position g_x / g_y (tiles, FF3 $AC / $AD) + g_sx / g_sy (pixels, $13 /
; $14), speed g_spd ($AE, 1-2 pixels a frame), facing g_dir ($A7: R 1, L 2, D 4, U 8), the
; queue of the party's last steps g_q ($E1-$E4), g_wait ($A9: the party waits for it on a world
; map). pl_hide ($7E): bit 7 the party hidden, bit 6 the guest hidden (event commands C8 / C9 /
; CC / CD). Sprite tiles $10-$1F of VRAM bank 1, palette 2 (its own colours on world maps).
GUEST      = GS + $0B
G_PAL      = $6B00              ; SPR_BANK: 00/96F8 the guests' colours (2 each)
G_GUZCO    = $6A00              ;   0D/8000 the Guzco / Shadow graphics (16 tiles)

; 3D/B627 at the party's tile; the rest cleared (3D/B654)
g_init:     ld a, [px]
            ld [g_x], a
            ld a, [py]
            ld [g_y], a
g_reset:    xor a
            ld [g_sx], a
            ld [g_sy], a
            ld [g_spd], a
            ld [g_q], a
            ld [g_q + 1], a
            ld [g_q + 2], a
            ld [g_q + 3], a
            ld [g_wait], a
            ld a, 4
            ld [g_dir], a
            ret

; 3D/B6DA a step of the party (facing): pushed onto the queue
g_push:     ld a, [g_q + 2]
            ld [g_q + 3], a
            ld a, [g_q + 1]
            ld [g_q + 2], a
            ld a, [g_q]
            ld [g_q + 1], a
            ld a, [facing]
            and $0F
            ld [g_q], a
            ret

; 3D/B78A each frame: follow, then a step's pixels
g_frame:    ld a, [GUEST]
            and a
            jr z, g_reset
            ld a, [g_wait]
            and a
            jr nz, .f
            ldh a, [is_world]
            and a
            jr z, .f
            ld a, [GS + $0F]                ; (in a vehicle: reset)
            and a
            jr nz, g_reset
.f:         call g_follow
            ld a, [g_spd]
            and a
            ret z
            ld b, a
            ld a, [g_dir]
            rrca
            jr nc, .l
            ld a, [g_sx]                    ; right
            add a, b
            and $0F
            ld [g_sx], a
            ret nz
            ld hl, g_x
            inc [hl]
            jr .end
.l:         rrca
            jr nc, .d
            ld a, [g_sx]                    ; left
            sub b
            jr nc, .l1
            ld hl, g_x
            dec [hl]
.l1:        and $0F
            ld [g_sx], a
            ret nz
            jr .end
.d:         rrca
            jr nc, .u
            ld a, [g_sy]                    ; down
            add a, b
            and $0F
            ld [g_sy], a
            ret nz
            ld hl, g_y
            inc [hl]
            jr .end
.u:         ld a, [g_sy]                    ; up
            sub b
            jr nc, .u1
            ld hl, g_y
            dec [hl]
.u1:        and $0F
            ld [g_sy], a
            ret nz
.end:       ldh a, [cmask]                  ; (the map's wrap)
            ld b, a
            ld a, [g_x]
            and b
            ld [g_x], a
            ld a, [g_y]
            and b
            ld [g_y], a
            xor a
            ld [g_spd], a
            ret

; 3D/B716 the next step from the queue: 4 behind (speed 1-2 by the random table), 3 behind,
; 2 behind (every other 16 frames unless waited for: speed 1), 1 behind: facing only
g_follow:   ld a, [g_spd]
            and a
            ret nz
            ld a, [g_q + 3]
            and a
            jr z, .q3
            ld b, a
            xor a
            ld [g_q + 3], a
            ld a, b
.go:        and $0F
            ld [g_dir], a
            ld a, [fcnt]
            ld l, a
            ld h, high(N_RNG)
            ld a, [hl]
            and 2
            jr nz, .s
            or 1
.s:         ld [g_spd], a
            ret
.q3:        ld a, [g_q + 2]
            and a
            jr z, .q2
            ld b, a
            xor a
            ld [g_q + 2], a
            ld a, b
            jr .go
.q2:        ld a, [g_q + 1]
            and a
            jr z, .q1
            ld a, [g_wait]
            and a
            jr nz, .q2a
            ld a, [fcnt]
            and $10
            ret nz
.q2a:       ld a, [g_q + 1]
            ld b, a
            xor a
            ld [g_q + 1], a
            ld a, b
            call .go
            ld a, 1
            ld [g_spd], a
            ret
.q1:        ld a, [g_q]
            and $0F
            ld [g_dir], a
            ldh a, [is_world]
            and a
            jr z, .w0
            ld a, [g_wait]
            and a
            ret z
            ld a, [g_q]
            and a
            jr z, .w0
            ld [g_q + 1], a
            xor a
            ld [g_q], a
            jr .q2a
.w0:        xor a
            ld [g_wait], a
            ret

; fix:C379 (world maps) the party standing with steps queued: it waits for the guest. NZ = wait
g_waits:    ldh a, [is_world]
            and a
            ret z
            ld a, [g_wait]
            and a
            ret nz
            ld a, [GUEST]
            and a
            ret z
            ld a, [g_q]
            and a
            ret z
            ld a, 1
            ld [g_wait], a
            and a
            ret

; 3E/DB58 the guest's sprite (OAM 4-7) relative to the party's; npc_oam0: where the people start
g_draw:     ld a, 16
            ld [npc_oam0], a
            ld a, [pl_hide]
            and $C0
            ret nz
            ld a, [GUEST]
            and a
            ret z
            ld a, [g_wait]
            and a
            jr nz, .s
            ldh a, [is_world]
            and a
            jr z, .s
            ld a, [GS + $0F]
            and a
            ret nz
.s:         ld a, 32
            ld [npc_oam0], a
            ld a, [g_x]                     ; dx = 16 (g_x - px) + g_sx - mdx mcount
            ld hl, px
            sub [hl]
            ld e, a                         ; (signed tiles)
            ld a, [g_sx]
            ld b, a
            ld a, [mdx]
            ld c, a
            call .pix
            add a, PX0 + 8
            ld [g_t], a                     ; OAM x
            ld a, [g_y]
            ld hl, py
            sub [hl]
            ld e, a
            ld a, [g_sy]
            ld b, a
            ld a, [mdy]
            ld c, a
            call .pix
            add a, PY0 + 16 - 4 - 1 + 3 - 3 ; (as the party's y: 3E/DBBA - 4, - 1)
            ld [g_t + 1], a
            ld a, [GUEST]                   ; frame: Guzco $30, else walking by g_sx | g_sy
            cp 4
            ld a, $30
            jr z, .fr
            ld a, [g_sx]
            ld b, a
            ld a, [g_sy]
            or b
            and 8
            ld b, a
            ld a, [g_dir]
            ld l, a
            ld h, high(M_FACE)
            ld a, [hl]
            or b
            bit 3, a
            jr z, .fr
            push af
            ld a, [g_sx]                    ; (the walking frame one pixel up or left)
            and a
            ld hl, g_t + 1
            jr nz, .b
            ld hl, g_t
.b:         dec [hl]
            pop af
.fr:        add a, low(M_FRAME)
            ld e, a
            ld d, high(M_FRAME)
            ld hl, oam_buf + 16
            ld a, [g_t]
            ld b, a
            ld a, [g_t + 1]
            ld c, a
            call .spr                       ; TL
            ld a, c
            add a, 8
            ld c, a
            call .spr                       ; BL
            ld a, b
            add a, 8
            ld b, a
            ld a, c
            sub 8
            ld c, a
            call .spr                       ; TR
            ld a, c
            add a, 8
            ld c, a
.spr:       ld a, c
            ld [hl+], a
            ld a, b
            ld [hl+], a
            ld a, [de]                      ; tile + $10
            inc de
            add a, $10
            ld [hl+], a
            ld a, [de]                      ; palette 2
            inc de
            and $F8
            or 2
            ld [hl+], a
            ret
; E tiles (signed) x 16 + B - C x mcount -> A (screen offset, mod 256)
.pix:       ld a, e
            swap a
            and $F0
            add a, b
            ld b, a
            ld a, [mcount]
            bit 7, c
            jr nz, .m
            dec c
            jr nz, .z
            cpl                             ; (moving +1: - mcount)
            inc a
            add a, b
            ret
.m:         add a, b                        ; (moving -1: + mcount)
            ret
.z:         ld a, b
            ret

; 3B/BA5D the guest's graphics (16 tiles -> VRAM bank 1 $8100) and, on world maps, its colours
; (00/96F8 + 2 (guest - 1) -> OBJ palette 2 colours 2-3, colour 1 black)
g_gfx:      ld a, [GUEST]
            and a
            ret z
            ld b, a
            ld hl, GS + $102                ; (all toad / all mini: those graphics)
            ld a, [hl]
            ld l, $42
            and [hl]
            ld l, $82
            and [hl]
            ld l, $C2
            and [hl]
            ld c, $16
            bit 5, a
            jr nz, .g
            inc c
            bit 3, a
            jr nz, .g
            ld a, b
            cp 4
            jr z, .gz
            dec a                           ; (guest - 1 < 3: $18 + it; 3-4 Guzco; else $17 + it)
            cp 3
            jr c, .n
            dec a
            cp 3
            jr c, .gz
.n:         add a, $18
            ld c, a
.g:         ld a, c
            add a, $40
            ld h, a
            ld l, 0
            jr .cp
.gz:        ld hl, G_GUZCO
.cp:        ld a, SPR_BANK
            ld [vc_src], a
            ld de, $8100
            ld b, 16
            ld a, 1
            call vcopyx
            ldh a, [is_world]
            and a
            ret z
            ld a, [GUEST]
            dec a
            and $0F
            add a, a
            add a, low(G_PAL)
            ld l, a
            ld h, high(G_PAL)
            ld a, SPR_BANK
            call rd_byte
            ld [g_t], a
            ld a, SPR_BANK
            call rd_byte
            ld [g_t + 1], a
            ld a, $0F
            ld [g_c1], a
            ld hl, g_c1
            ld bc, pal_sh + 64 + 16 + 2     ; OBJ palette 2, colours 1-3
.pc:        push bc
            call nes_col
            pop bc
            ld [bc], a
            inc bc
            ld a, d
            ld [bc], a
            inc bc
            ld a, c
            cp low(pal_sh + 64 + 16 + 8)
            jr nz, .pc
            ld a, 1
            ldh [pal_dirty], a
            ret

; fix:EA9C B on a normal map with nobody in front: the guest's script (2C/8860 + 2 (guest - 1)),
; the party turned toward it (fix:EA8C by the last step)
g_talk:     ld a, [pl_hide]
            bit 6, a
            ret nz
            ld a, [GUEST]
            and a
            ret z
            ld a, 1
            ld [g_wait], a
            ld a, [GUEST]
            dec a
            add a, a
            add a, $60
            ld l, a
            ld h, $48
            ld a, EVT_BANK
            call rd_byte
            ld c, a
            ld a, EVT_BANK
            call rd_byte
            ld h, a
            ld l, c
            call ev_trig
            call rbank
            call ev_check
            push af
            ld a, [g_q]
            and $0F
            ld e, a
            ld d, 0
            ld hl, .face
            add hl, de
            ld a, [hl]
            ld [facing], a
            pop af
            jp ev_start
.face:      db $08, $02, $01, $00, $08, $02, $01, $00, $04, $02, $01, $00, $00, $00, $00, $00

section wram, $C3F2
g_x:        ds 1
g_y:        ds 1
g_sx:       ds 1
g_sy:       ds 1
g_spd:      ds 1
g_dir:      ds 1
g_wait:     ds 1
pl_hide:    ds 1
npc_oam0:   ds 1
tk_b:       ds 1
section wram, $C394
g_q:        ds 4
g_c1:       ds 1                ; (colour 1)
g_t:        ds 2
