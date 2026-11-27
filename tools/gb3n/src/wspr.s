; FF3's world-map sprites (3E/D85A and its helpers; bank $3C's sprite lists) as native code.
; Positions follow FF3's: an object on a map cell shows at the cell's top + 1 (NES OAM y + 1),
; the party 3 pixels above its cell (3E/D8CA). GB screen = NES screen - (48, 48).
; Bank B_WSPR: $4000 / $4800 / $5000 FF3's OBJ tiles $80-$FF for the floating continent with
; Bahamut, with Hein's castle / the whirlpool, and the other worlds (3D/BDE0); $5800 NES bank $3C
; $8300-$87FF (the sprite lists: an NES address a reads at a - $8300 + $5800); code at $6000.

WS_3C      = $5800 - $8300

section bank B_WSPR, $6000
; ---- the world map's tiles $80-$FF (VRAM bank 1 $8800) for this world (3D/BDE0)
ws_tiles:   ld a, [world]
            srl a
            ld hl, $5000                    ; worlds 2-4
            jr nz, .s
            ld hl, $4000                    ; the floating continent: Bahamut, or Hein's castle
            ld a, [SRAM_PAGE + $20]         ;   and the whirlpool ($6020 & $0C)
            and $0C
            jr z, .s
            ld hl, $4800
.s:         ld de, $8800
            ld bc, $800
            ld a, 1
            ldh [rVBK], a
            ld a, B_WSPR
            call far_copy
            xor a
            ldh [rVBK], a
            ret

; ---- the world map's other sprites into OAM from entry 4 (3E/D85A), the rest hidden
ws_world:   ld a, 16
            ld [ws_n], a
            ld a, [world]
            srl a
            jr z, .fc
            srl a
            jr nz, .x                       ; (underwater: the bubbles, 3A/9442: later)
            ld a, [frame]                   ; flooded / surface world (the order turns every
            rra                             ;   other frame)
            jr c, .s2
            call ws_ship
            call ws_air
            call ws_choc
            call ws_cont
            call ws_inv
            jr .x
.s2:        call ws_inv
            call ws_cont
            call ws_choc
            call ws_ship
            call ws_air
            jr .x
.fc:        ld a, [frame]                   ; the floating continent
            rra
            jr c, .f2
            call ws_naut
            call ws_air
            call ws_ship
            call ws_choc
            call ws_lev
            call ws_misc
            call ws_inv
            jr .x
.f2:        call ws_inv
            call ws_misc
            call ws_lev
            call ws_choc
            call ws_ship
            call ws_air
            call ws_naut
.x:         call ws_chain
                    ld a, [ws_n]                    ; the rest hidden
            ld l, a
            ld h, high(oam_buf)
.h:         ld a, l
            cp 160
            ret nc
            xor a
            ld [hl+], a
            inc l
            inc l
            inc l
            jr .h

; is map cell (D, E) on screen? (3E/DBE4) carry set if not; ws_x / ws_y = its top left on the
; GB screen (+1 down as FF3's sprites)
ws_onsc:    ld a, e
            ld hl, pos_y
            sub [hl]
            add 7
            cp 15
            ccf
            ret c
            sub 7
            swap a
            add VIEW_Y * 16 + 1
            ld hl, walk_dy
            sub [hl]
            ld [ws_y], a
            ld a, d
            ld hl, pos_x
            sub [hl]
            add 7
            cp 15
            ccf
            ret c
            sub 7
            swap a
            add VIEW_X * 16
            ld hl, walk_dx
            sub [hl]
            ld [ws_x], a
            and a
            ret

; one sprite: B = GB y, C = GB x, D = tile, E = NES attributes (off screen: none)
ws_spr:     ld a, [ws_n]
            cp 160
            ret nc
            ld a, b
            add 16
            ret z
            cp 160
            ret nc
            ld b, a
            ld a, c
            add 8
            ret z
            cp 168
            ret nc
            ld c, a
            ld a, [ws_n]
            ld l, a
            ld h, high(oam_buf)
            ld a, b
            ld [hl+], a
            ld a, c
            ld [hl+], a
            ld a, d
            ld [hl+], a
            ld a, e                         ; NES attributes -> the Color's (VRAM bank 1)
            and 3
            or 8
            bit 6, e
            jr z, .h
            or $20
.h:         bit 7, e
            jr z, .v
            or $40
.v:         bit 5, e
            jr z, .p
            or $80
.p:         ld [hl+], a
            ld a, l
            ld [ws_n], a
            ret

; a 2 x 2 object at (ws_x, ws_y) (3E/DA3A): HL = 4 x (tile, attributes) UL, DL, UR, DR (in
; WRAM / this bank), [ws_toff] added to the tiles
ws_obj:     ld a, [ws_y]
            ld b, a
            ld a, [ws_x]
            ld c, a
            call .one
            ld a, b
            add 8
            ld b, a
            call .one
            ld a, b
            sub 8
            ld b, a
            ld a, c
            add 8
            ld c, a
            call .one
            ld a, b
            add 8
            ld b, a
.one:       ld a, [ws_toff]
            add [hl]
            inc hl
            ld d, a
            ld a, [hl+]
            ld e, a
            push bc
            push hl
            call ws_spr
            pop hl
            pop bc
            ret
; a vehicle's 2 x 2 (3E/DA07): A = tile offset, [ws_poff] = its pose (3E/DCAA)
ws_veh:     ld [ws_toff], a
            ld a, [ws_poff]
            ld hl, vposes
            add l
            ld l, a
            jr nc, ws_obj
            inc h
            jr ws_obj

; the parked ship (3E/DAD4)
ws_ship:    ld a, [SRAM_PAGE + $20]
            rra
            ret c                           ; (the Nautilus obtained)
            and $10                         ; ($6020 bit 5: chained)
            ret nz
            ld a, [veh]
            cp 3
            ret z
            cp 4
            ret z
            ld a, [SRAM_PAGE + $03]
            ld hl, world
            cp [hl]
            ret nz
            ld a, [SRAM_PAGE + $00]
            and a
            ret z
            ld a, [SRAM_PAGE + $01]
            ld d, a
            ld a, [SRAM_PAGE + $02]
            ld e, a
            call ws_onsc
            ret c
            xor a
            ld [ws_poff], a
            ld a, $50
            jr ws_veh
; the parked Nautilus (3E/DB09)
ws_naut:    ld a, [SRAM_PAGE + $20]
            and 1
            ret z
            ld a, [veh]
            cp 5
            ret z
            ld a, [SRAM_PAGE + $00]
            and a
            ret z
            ld a, [SRAM_PAGE + $01]
            ld d, a
            ld a, [SRAM_PAGE + $02]
            ld e, a
            call ws_onsc
            ret c
            ld a, $10
            ld [ws_poff], a
            ld a, $68
            jr ws_veh
; the parked airship (3E/DB2F)
ws_air:     ld a, [SRAM_PAGE + $20]
            and $40
            ret z
            ld a, [veh]
            cp 6
            ret z
            ld a, [SRAM_PAGE + $03]
            ld hl, world
            cp [hl]
            ret nz
            ld a, [SRAM_PAGE + $01]
            ld d, a
            ld a, [SRAM_PAGE + $02]
            ld e, a
            call ws_onsc
            ret c
            ld a, $10
            ld [ws_poff], a
            ld a, $68
            jr ws_veh

; the parked Invincible (3E/D666): its picture (16-frame animation) and its shadow
ws_inv:     ld a, [veh]
            cp 7
            ret z
            ld a, [SRAM_PAGE + $04]
            and a
            ret z
            ld a, [SRAM_PAGE + $07]
            ld hl, world
            cp [hl]
            ret nz
            ld a, [SRAM_PAGE + $05]
            ld d, a
            ld a, [SRAM_PAGE + $06]
            dec a
            ld e, a
            call ws_onsc
            ret c
            ld a, [frame]
            and $10
            add a
            ; fall through: the Invincible's sprite list X = A (3C/8857)
ws_invx:    ld l, a                         ; (3C/83E0 + X: the list)
            ld h, 0
            ld de, $83E0 + WS_3C
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld de, WS_3C
            add hl, de
            ld a, [ws_x]
            push af
            ld a, [ws_y]
            push af
            call ws_list
            pop af                          ; the shadow 24 lines below, every other frame
            add $18
            ld [ws_y], a
            pop af
            ld [ws_x], a
            ld a, [frame]
            rra
            ret nc
            ld hl, $8608 + WS_3C
            jp ws_list
; a sprite list at HL (3C/87CD: y offset, tile, attributes, x offset; offsets add up; $FF ends;
; a sprite off the 256-wide screen is left out)
ws_list:    ld a, [ws_y]
            ld [ws_ly], a
            ld a, [ws_x]
            ld [ws_lx], a
.l:         ld a, [hl]
            cp $FF
            ret z
            ld b, a                         ; y + offset (signed)
            ld a, [ws_ly]
            add b
            ld [ws_ly], a
            inc hl
            ld d, [hl]
            inc hl
            ld e, [hl]
            inc hl
            ld a, [hl+]
            ld c, a
            ld a, [ws_lx]
            add c
            ld [ws_lx], a
            push hl
            ld a, [ws_ly]
            ld b, a
            ld a, [ws_lx]
            ld c, a
            call ws_spr
            pop hl
            jr .l

; the boulder, the whirlpool, Hein's castle (3E/D537)
ws_misc:    ld a, [SRAM_PAGE + $20]
            and 1
            jr z, .wp
            ld de, $5136                    ; the boulder at (81, 54)
            call ws_onsc
            ret c
            ld a, $90
            jr .pal3
.wp:        ld a, [SRAM_PAGE + $20]
            and 4
            jr z, .h1
            ld de, $4320                    ; the whirlpool at (67, 32)
            call ws_onsc
            ret c
            ld a, [frame]
            srl a
            and $0C
            or $B0
            jr .pal3
.h1:        ld a, [SRAM_PAGE + $20]         ; Hein's castle, circling (object command 0: speed 1,
            and 8                           ;   radius 32; its cell offset kept in $DE / $DF)
            jr z, .h2
            ld b, 1
            ld c, $40
            call ws_hein
            ld a, [ws_hx]
            ld [ws_de], a
            ld a, [ws_hy]
            ld [ws_df], a
            call ws_hon
            ret c
            ld a, [frame]                   ; (3C/88C2: two frames, then the party behind it)
            and 8
            jr z, .h1a
            ld a, $41
.h1a:       add $5A
            ld l, a
            ld h, 0
            ld de, $8600 + WS_3C
            add hl, de
            call ws_list
            jp ws_behind
.h2:        ld a, [SRAM_PAGE + $2F]         ; ... and rising ($602F bit 1; object command 2: speed
            bit 1, a                        ;   2, radius 24)
            ret z
            ld b, 2
            ld c, $30
            call ws_hein
            call ws_hon
            ret c
            ld a, [ws_x]                    ; ($E6 / $E7: its screen place, for Bahamut)
            add 48
            ld [ws_e6], a
            ld a, [ws_y]
            add 48
            ld [ws_e7], a
            ld a, [frame]                   ; (3C/88DB: two frames, the shadow)
            and $10
            jr z, .h2a
            ld a, $41
.h2a:       add $19
            ld l, a
            ld h, 0
            ld de, $8600 + WS_3C
            add hl, de
            jp ws_withsh
.pal3:      ld [ws_toff], a                 ; (3E/D603: palette 3, 3E/DCF2)
            ld hl, ws_dcf2
            jp ws_obj
ws_dcf2:    db $00, $03, $02, $03, $01, $03, $03, $03

; a list at HL at (ws_x, ws_y), the party behind it, its shadow 24 lines below every other
; frame (3C/8861)
ws_withsh:  ld a, [ws_x]
            push af
            ld a, [ws_y]
            push af
            call ws_list
            call ws_behind
            pop af
            add $18
            ld [ws_y], a
            pop af
            ld [ws_x], a
            ld a, [frame]
            rra
            ret nc
            ld hl, $8608 + WS_3C
            jp ws_list
; the party's sprites behind what was just drawn, unless in an airship (3C/88F1)
ws_behind:  ld a, [veh]
            cp 4
            ret nc
            ld hl, oam_buf
            ld a, [ws_n]
            ld e, a
            ld d, h
            ld b, 16
.mv:        ld a, e
            cp 160
            jr nc, .mz
            ld a, [hl]
            ld [de], a
            inc e
.mz:        xor a
            ld [hl+], a
            dec b
            jr nz, .mv
            ld a, e
            ld [ws_n], a
            ret
; Hein's castle (3B/A4C3): B = speed, C = radius: the angle down by the speed, the circle's point
; (3A/9DA4) - $54 as cells (ws_hx, ws_hy) and sub-cells
ws_hein:    ld a, c
            ld [ws_rad], a
            ld a, [ws_bd]
            sub b
            ld [ws_bd], a
            ld [ws_ang], a
            ld a, [ws_bd + 1]
            sbc 0
            ld [ws_bd + 1], a
            ld [ws_ang + 1], a
            call ws_proj
            ld a, [ws_px]
            sub $54
            ld b, a
            and $0F
            ld [ws_hsx], a
            ld a, b
            swap a
            and $0F
            ld [ws_hx], a
            ld a, [ws_py]
            sub $54
            ld b, a
            and $0F
            ld [ws_hsy], a
            ld a, b
            swap a
            and $0F
            ld [ws_hy], a
            ret
; on screen at (45 + hx, 86 + hy) + its sub-cells? carry set if not
ws_hon:     ld a, [ws_hx]
            add $2D
            ld d, a
            ld a, [ws_hy]
            add $56
            ld e, a
            call ws_onsc
            ret c
            ld a, [ws_hsx]
            ld hl, ws_x
            add [hl]
            ld [hl], a
            ld a, [ws_hsy]
            ld hl, ws_y
            add [hl]
            ld [hl], a
            and a
            ret
; the point at angle ws_ang (low byte; quadrant in bits 0-1 of the high), radius ws_rad
; (3A/9DA4): ws_px, ws_py = $74 + r sin, $74 + r cos (FF3's sine table 3A/9E3E)
ws_proj:    ld a, [ws_ang]
            call .m
            ld [ws_p88], a
            ld a, [ws_ang]
            cpl
            call .m
            ld [ws_p89], a
            ld a, [ws_ang + 1]
            and 3
            jr z, .q0
            dec a
            jr nz, .q2
            ld a, [ws_p88]                  ; 1: (cos, -sin)
            cpl
            inc a
            ld b, a
            ld a, [ws_p89]
            ld [ws_p88], a
            ld a, b
            ld [ws_p89], a
            jr .q0
.q2:        dec a
            jr nz, .q3
            ld a, [ws_p88]                  ; 2: (-sin, -cos)
            cpl
            inc a
            ld [ws_p88], a
            ld a, [ws_p89]
            cpl
            inc a
            ld [ws_p89], a
            jr .q0
.q3:        ld a, [ws_p89]                  ; 3: (-cos, sin)
            cpl
            inc a
            ld b, a
            ld a, [ws_p88]
            ld [ws_p89], a
            ld a, b
            ld [ws_p88], a
.q0:        ld a, [ws_p88]
            add $74
            ld [ws_px], a
            ld a, [ws_p89]
            add $74
            ld [ws_py], a
            ret
.m:         ld e, a                         ; sin(A) x radius / 256 (3A/9E1A)
            ld d, 0
            ld hl, ws_sin
            add hl, de
            ld e, [hl]
            ld a, [ws_rad]
            ld hl, 0
            ld b, 8
.ml:        add hl, hl
            rla
            jr nc, .ms
            add hl, de
.ms:        dec b
            jr nz, .ml
            ld a, h
            ret

; the chocobo running off to the right, bobbing (3E/DAA3; started by leaving it: 3E/C2E7)
ws_choc:    ld a, [ws_cb]
            bit 7, a
            ret z
            ld a, [ws_cbx]
            add 2
            ld [ws_cbx], a
            cp $F8
            jr c, .r
            xor a
            ld [ws_cb], a
            ret
.r:         sub 48
            ld [ws_x], a
            ld a, [ws_cbx]
            and 8
            ld [ws_poff], a
            ld a, [frame]
            rla
            ld a, $FF
            jr nc, .u
            ld a, 1
.u:         ld hl, ws_cby
            add [hl]
            ld [hl], a
            sub 47
            ld [ws_y], a
            ld a, $38
            jp ws_veh

; the chain from the chained ship to its anchor at x 162 (3D/BF0A: world 3, $6020 bit 5, in it)
ws_chain:   ld a, [veh]
            cp 3
            ret nz
            ld a, [world]
            cp 3
            ret nz
            ld a, [SRAM_PAGE + $20]
            and $20
            ret z
            ld a, [pos_x]                   ; the anchor's distance in pixels - 8 (NES: (162 -
            ld b, a                         ;   left) x 16 - fine scroll - 8, left = x - 7)
            ld a, $A2 - 7
            sub b
            swap a
            and $F0
            ld hl, walk_dx
            sub [hl]
            sub 8
            ret c
            srl a
            add a
            ld b, a
            add a
            add b                           ; (the table row: 6 bytes per 2 pixels)
            cp 121
            jr c, .t
            ld a, 120
.t:         ld e, a
            ld d, 0
            ld hl, ws_chtab
            add hl, de
            ld a, $80 - 48
            ld [ws_lx], a
            ld a, $75 + 1 - 48
            ld [ws_ly], a
            ld c, 6
.l:         ld a, [hl+]
            push hl
            push bc
            ld b, a
            and $0F
            ld hl, ws_lx
            add [hl]
            ld [hl], a
            ld a, b
            swap a
            and $0F
            cp 8
            jr c, .p
            and 7
            cpl
            inc a
.p:         ld hl, ws_ly
            add [hl]
            ld [hl], a
            ld b, a
            ld a, [ws_lx]
            ld c, a
            ld d, $B6
            ld e, 3
            call ws_spr
            pop bc
            pop hl
            dec c
            jr nz, .l
            ret

; the floating continent seen from below (3C/8887: at (32, 224), not from the Invincible)
ws_cont:    ld de, $20DF
            call ws_onsc
            ret c
            ld a, [veh]
            cp 7
            ret z
            ld hl, $86DC + WS_3C
            ld a, [ws_x]
            push af
            ld a, [ws_y]
            push af
            call ws_list
            pop af
            add $18
            ld [ws_y], a
            pop af
            ld [ws_x], a
            ld a, [frame]
            rra
            ld hl, $8608 + WS_3C
            call c, ws_list
            ld hl, oam_buf                  ; (3C/889A: the party's sprites after it: under the
            ld a, [ws_n]                    ;   continent)
            ld e, a
            ld d, h
            ld b, 16
.mv:        ld a, e
            cp 160
            jr nc, .mz
            ld a, [hl]
            ld [de], a
            inc e
.mz:        xor a
            ld [hl+], a
            dec b
            jr nz, .mv
            ld a, e
            ld [ws_n], a
            ret

; the Leviathan's shadow (3C/8908: $6020 bit 1; drifting along row 53)
ws_lev:     ld a, [SRAM_PAGE + $20]
            and 2
            ret z
            ld a, [frame]
            rra
            ld a, [ws_b3]
            adc 0
            cp $C0
            jr c, .a
            xor a
.a:         ld [ws_b3], a
            cp $60
            jr c, .b
            sub $60
            ld b, a
            ld a, $60
            sub b
.b:         ld [ws_87], a
            swap a
            and $0F
            add $20
            ld d, a
            ld e, $35
            call ws_onsc
            ret c
            ld a, [ws_87]
            and $0F
            ld hl, ws_x
            add [hl]
            ld [hl], a
            ld a, [ws_b3]
            srl a
            srl a
            srl a
            ld a, 0
            jr c, .c
            ld a, $21
.c:         ld b, a
            ld a, [ws_b3]
            cp $60
            ld a, b
            jr c, .d
            add $42
.d:         add $1D
            ld l, a
            ld h, 0
            ld de, $8700 + WS_3C
            add hl, de
            jp ws_list

section bank B_WSPR, $7C00
ws_sin:     ds 256                          ; (3A/9E3E, from the ROM)
ws_chtab:   ds 126                          ; (3D/BF7A: the chain's links by distance)

section wram, $CFC8
ws_n:       ds 1
ws_x:       ds 1
ws_y:       ds 1
ws_lx:      ds 1
ws_ly:      ds 1
ws_toff:    ds 1
ws_poff:    ds 1
ws_b3:      ds 1
ws_87:      ds 1
ws_bd:      ds 2                            ; FF3's $BD / $BE: Hein's castle's angle
ws_de:      ds 1                            ; $DE / $DF: its cell offset
ws_df:      ds 1
ws_e6:      ds 1                            ; $E6 / $E7
ws_e7:      ds 1
ws_ang:     ds 2
ws_rad:     ds 1
ws_px:      ds 1
ws_py:      ds 1
ws_p88:     ds 1
ws_p89:     ds 1
ws_hx:      ds 1
ws_hy:      ds 1
ws_hsx:     ds 1
ws_hsy:     ds 1
ws_cb:      ds 1                            ; $B0-$B2: the chocobo running off
ws_cbx:     ds 1
ws_cby:     ds 1
