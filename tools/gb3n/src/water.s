; FF3's water animation (3A/858F update, 3D/B7F9 buffers, 3A/866E init, 3A/9319 the map's flags):
; the low plane of tiles $22-$27 (the world map's sea; a map's water when its properties byte 1
; has bit 7 / bit 6) kept as three 16 x 8 strips: $22 / $23 and $24 / $25 turning a pixel right
; every 32 frames, $26 / $27 a line down every 16; two bytes a frame go to VRAM in FF3's order
; (rows by threes / twos), so a strip changes a row at a time. Under the sea (world 4) the high
; plane of tiles $80 / $81 and $90 / $91 sways left and right. FF3 sets the flags only when a map
; loads: the world map keeps the last map's (and the sea stops after a dive), as on the Famicom.

WAT_BUF    = $DCD0          ; FF3's $7F00-$7F2F (work RAM bank 1: the end of SCRATCH, rebuilt at
                            ;   every load after the map's stream)

section bank B_FIELD, $6870
; ---- a map's flags (3A/9319)
wat_map:    ld a, [map_props + 1]
            ld b, a
            and $80
            or $0D
            ld [wat_6d], a
            ld a, b
            and $40
            add a
            or $0E
            ld [wat_6e], a
            ret

; ---- the buffer from the tiles just loaded (3A/866E)
wat_init:   ld a, [wmode]
            and a
            jr z, .map
            ld a, [world]
            cp 4
            jr nc, .uw
            and 6                           ; (the world's tiles: src/world.s)
            rra
            swap a
            add high(W_TSET)
            ld h, a
            ld l, 0
            ld a, B_WGFX
            jr .t
.map:       ld a, [gs_src + 1]
            ld l, a
            ld a, [gs_src + 2]
            ld h, a
            ld a, [gs_src]
.t:         ld [wat_bk], a
            ld de, $220                     ; tiles $22-$27, plane 0
            add hl, de
            ld c, 0
            ld e, low(WAT_BUF)
            call .p
            ld e, low(WAT_BUF) + 16
            call .p
            ld e, low(WAT_BUF) + 32
.p:         push hl
            push de
            push bc
            ld a, [wat_bk]
            ld de, SCRATCH
            ld bc, 32
            call far_copy
            pop bc
            pop de
            call wat_il
            pop hl
            ld a, l
            add 32
            ld l, a
            ret nc
            inc h
            ret
.uw:        ld a, B_WGFX                    ; (3A/86C1: tiles $80 / $81, $90 / $91, plane 1)
            ld [wat_bk], a
            ld hl, W_TSET + $2800
            ld c, 1
            ld e, low(WAT_BUF)
            call .p
            ld hl, W_TSET + $2900
            ld e, low(WAT_BUF) + 16
            jr .p
; two tiles at SCRATCH: plane C's rows, interlaced, to WAT_BUF page + E (16 bytes)
wat_il:     ld hl, SCRATCH
            ld a, c
            or l
            ld l, a
            ld d, high(WAT_BUF)
            ld b, 8
.r:         ld a, [hl]
            ld [de], a
            inc e
            set 4, l
            ld a, [hl]
            ld [de], a
            inc e
            res 4, l
            inc l
            inc l
            dec b
            jr nz, .r
            ret

; ---- each frame in V-Blank (3A/858F), then the buffers (3D/B7F9)
wat_vbl:    ld a, [wmode]
            and a
            jr z, .s
            ld a, [world]
            cp 4
            jr nc, .uw
.s:         ld a, [frame]
            rra
            jr c, .v
            ld a, [wat_6d]                  ; even frames: across (two bytes of 32)
            add a
            jr nc, .buf
            ld a, [wat_6d]
            add 3
            and $8F
            ld b, a
            and $0F
            jr nz, .h
            ld b, $90
.h:         ld a, b
            ld [wat_6d], a
            and $0F                         ; row n: tile $22 + 2 (n / 8), its row n & 7
            ld c, a
            and 8
            add c
            add a
            add $20
            ld l, a
            ld h, $92
            ld a, c
            add a
            add low(WAT_BUF)
            ld e, a
            ld d, high(WAT_BUF)
            jr .w
.v:         ld a, [wat_6e]                  ; odd frames: down (two bytes of 16)
            add a
            jr nc, .buf
            ld a, [wat_6e]
            add 2
            and $8F
            ld b, a
            and $0F
            jr nz, .vh
            ld b, $90
.vh:        ld a, b
            ld [wat_6e], a
            and $0F
            ld c, a
            add $60
            ld l, a
            ld h, $92
            ld a, c
            add low(WAT_BUF) + $20
            ld e, a
            ld d, high(WAT_BUF)
.w:         ld a, [de]
            ld [hl], a
            inc e
            set 4, l
            ld a, [de]
            ld [hl], a
.buf:       ld a, [wat_6e]                  ; (3D/B81A) a full round: the strips move on
            bit 7, a
            jr z, .b2
            bit 4, a
            jr z, .b2
            xor $10
            ld [wat_6e], a
            call wat_down
.b2:        ld a, [wat_6d]
            bit 7, a
            ret z
            bit 4, a
            ret z
            xor $10
            ld [wat_6d], a
            jr wat_right
.uw:        ld a, [frame]                   ; under the sea: every 4 frames (3A/854E)
            and 3
            jr nz, .ub
            ld a, [wat_6d]
            add 3
            and $0F
            jr nz, .u1
            ld a, $10
.u1:        ld [wat_6d], a
            and $0F                         ; row n: tile $80 + 16 (n / 8), plane 1, row n & 7
            ld c, a
            and 7
            add a
            inc a
            ld l, a
            ld a, c
            rra
            rra
            rra
            and 1
            add $88
            ld h, a
            ld a, c
            add a
            add low(WAT_BUF)
            ld e, a
            ld d, high(WAT_BUF)
            ld a, [de]
            ld [hl], a
            inc e
            set 4, l
            ld a, [de]
            ld [hl], a
.ub:        ld a, [wat_6d]                  ; (3D/B804) a round: left 4, right 4 alternately
            and $10
            ret z
            xor a
            ld [wat_6d], a
            ld hl, wat_6e
            inc [hl]
            bit 2, [hl]
            jr z, wat_right
; the two upper strips a pixel left (3D/B875)
wat_left:   ld hl, WAT_BUF
            ld b, 16
.l:         ld a, [hl+]
            rla
            ld a, [hl]
            rla
            ld [hl-], a
            ld a, [hl]
            rla
            ld [hl+], a
            inc l
            dec b
            jr nz, .l
            ret
; a pixel right (3D/B864)
wat_right:  ld hl, WAT_BUF
            ld b, 16
.l:         inc l
            ld a, [hl-]
            rra
            ld a, [hl]
            rra
            ld [hl+], a
            ld a, [hl]
            rra
            ld [hl+], a
            dec b
            jr nz, .l
            ret
; the lower strip a line down (3D/B83F)
wat_down:   ld a, [WAT_BUF + $2E]
            ld b, a
            ld a, [WAT_BUF + $2F]
            ld c, a
            ld hl, WAT_BUF + $2D
            ld de, WAT_BUF + $2F
            ld a, 14
.l:         push af
            ld a, [hl-]
            ld [de], a
            dec e
            pop af
            dec a
            jr nz, .l
            ld a, b
            ld [WAT_BUF + $20], a
            ld a, c
            ld [WAT_BUF + $21], a
            ret

section wram, $C0E6
wat_6d:     ds 1                            ; FF3's $6D: across (bit 7 on, bit 4 a round done)
wat_6e:     ds 1                            ; $6E: down
wat_bk:     ds 1
