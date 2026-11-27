; FF3's vehicles on the world maps (3E/C4FC movement, 3E/C65D passability, 3E/C2B7 the A button,
; 3E/C7A5 landing, 3E/D8D3 the party's sprite, 3E/DAD4.. the parked vehicle): veh = FF3's $42
; (0 on foot, 1 chocobo, 2 canoe, 3 ship, 4 the Enterprise flying, 5 / 6 airships, 7 the
; Invincible); the parked vehicle at $6001 / $6002 on world $6003 ($6000 shown).
; Tables (B_MAPAUX, from the ROM): $4D40 the vehicles' poses (3E/DCAA), $4D80 passability masks
; (3E/C6CD), $4D88 landing flags (3E/C851), $4D90 sprite rows (3E/D8CA). Graphics (B_VGFX): $4000
; 0B/8800 (96 tiles: canoe, chocobo, ship, Enterprise) at OBJ $20, $4600 0B/8E00 and $4780
; 0B/8F80 (the other airships, 24 tiles at OBJ $68).

A_VPOSE    = $4D40
A_VTAB     = $4D80
VT_MASK    = 0
VT_LAND    = 8
VT_ROW     = 16

section bank B_FIELD, $5000
; ---- the world map's vehicle data (world_enter: VRAM writes allowed)
veh_load:   ld hl, A_VPOSE
            ld de, vposes
            ld bc, 64
            ld a, B_MAPAUX
            call far_copy
            ld hl, A_VTAB
            ld de, vtab
            ld bc, 24
            ld a, B_MAPAUX
            call far_copy
            ld a, 1
            ldh [rVBK], a
            ld hl, $4000                    ; 3D/BDE0: canoe, chocobo, ship, Enterprise
            ld de, $8000 + 16 * $20
            ld bc, $600
            ld a, B_VGFX
            call far_copy
            ld a, [SRAM_PAGE + $20]         ; the other airships over the Enterprise's tiles
            bit 6, a
            jr z, .b0
            ld hl, $4600
            ld de, $8000 + 16 * $68
            ld bc, $180
            ld a, B_VGFX
            call far_copy
.b0:        ld a, [SRAM_PAGE + $20]
            rra
            jr nc, .x
            ld hl, $4780
            ld de, $8000 + 16 * $68
            ld bc, $180
            ld a, B_VGFX
            call far_copy
.x:         xor a
            ldh [rVBK], a
            ret

; ---- the world map's passability for the vehicle (3E/C65D, 3E/C4FC): C = metatile, D / E the
; cell ahead; C set: no step. Boarding / leaving a canoe or ship happens here.
world_pass: ld a, [world]                   ; the boulder (3E/C603: world 0, $6020 bit 0, at
            and a                           ;   (81, 54)) blocks the way
            jr nz, .nb
            ld a, [SRAM_PAGE + $20]
            rra
            jr nc, .nb
            ld a, d
            cp 81
            jr nz, .nb
            ld a, e
            cp 54
            scf
            ret z
.nb:        ld b, W_PROP1
            ld a, [bc]
            ld [w_p1], a
            inc b
            ld a, [bc]
            ld [w_p2], a
            ld a, [veh]                     ; blocked: p1 & mask = mask (3E/C6CD)
            ld hl, vtab + VT_MASK
            call v_hla
            ld b, [hl]
            ld a, [w_p1]
            and b
            cp b
            jp z, v_board
            ld a, [veh]                     ; airships: other worlds (3E/C556)
            cp 4
            jr c, .nf
            call v_edge
            ret c
            ld a, [veh]                     ; airships (not under the sea): no entrances
            cp 4                            ;   (3E/C6C5; events stay)
            jr c, .nf
            ld a, [world]
            cp 4
            jr z, .nf
            ld a, [w_p2]
            bit 7, a
            jr nz, .nf
            ld hl, w_p1
            res 7, [hl]
.nf:        ld a, [w_p1]
            bit 7, a
            jr z, .pl
            ld a, [w_p2]
            bit 7, a
            jr nz, .ev
            ld a, [veh]                     ; an entrance: not in a vehicle (3E/C507)
            and a
            jr nz, .no
            ld a, [w_p2]
            ld [trig_id], a
            ld a, TR_WENT
            ld [trig_next], a
            and a
            ret
.ev:        and $7F
            call trig_script
            and a
            ret
.pl:        bit 6, a                        ; an encounter tile (3E/C6D9)
            call nz, enc_world
            and a
            ret
.no:        scf
            ret

; blocked for the vehicle: on foot a canoe on a river (3E/C5DE) or the ship (3E/C61B); in the
; canoe: land (bit 0 clear) or the ship; in the ship: a river (the ship parked) or land
v_board:    ld a, [veh]
            and a
            jr z, .foot
            cp 2
            jr z, .canoe
            cp 3
            jr z, .ship
            scf
            ret
.foot:      call v_canoeok
            jr nc, .to2
            call v_shipok
            ret c
            ld a, 3
            jr v_set
.to2:       ld a, 2
            jr v_set
.canoe:     ld a, [w_p1]
            rra
            jr c, .cs
            xor a                           ; onto land
            jr v_set
.cs:        call v_shipok
            ret c
            ld a, 3
            jr v_set
.ship:      call v_canoeok
            jr c, .sl
            call v_park
            ld a, 2
            jr v_set
.sl:        ld a, [w_p1]                    ; land (3E/C5B5: property 1 bit 0 clear)
            rra
            ret c
            call v_park
            xor a
; the vehicle A from now; the world map's song for it (3E/C93A)
v_set:      ld [veh], a
            call map_song
            and a
            ret
; NC when the cell ahead takes the canoe: canoe obtained ($602E bit 0), a river (property 1 bit 1
; clear)
v_canoeok:  ld a, [SRAM_PAGE + $2E]
            rra
            ccf
            ret c
            ld a, [w_p1]
            bit 1, a
            scf
            ret nz
            and a
            ret
; NC when the ship waits at the cell ahead ($6020 bits 0 / 6 clear, $6000 shown, its world)
v_shipok:   ld a, [SRAM_PAGE + $20]
            and $41
            scf
            ret nz
            ld a, [SRAM_PAGE + $00]
            and a
            scf
            ret z
            ld a, [world]
            ld hl, SRAM_PAGE + $03
            cp [hl]
            scf
            ret nz
            ld a, [SRAM_PAGE + $01]
            cp d
            scf
            ret nz
            ld a, [SRAM_PAGE + $02]
            cp e
            scf
            ret nz
            and a
            ret
; the ship (or a landed airship) parked where the party stands (3E/C59E)
v_park:     ld a, [pos_x]
            ld [SRAM_PAGE + $01], a
            ld a, [pos_y]
            ld [SRAM_PAGE + $02], a
            ld a, [world]
            ld [SRAM_PAGE + $03], a
            ret
v_hla:      add l
            ld l, a
            ret nc
            inc h
            ret

; ---- A on the world map (3E/C2B7): C set when nothing happened
v_abtn:     ld a, [veh]
            and a
            jr z, .foot
            cp 1
            jr z, .off                      ; the chocobo runs off
            cp 3
            jr z, .ship
            cp 7
            jr nc, .no                      ; (the Invincible: later)
            cp 4
            jr nc, v_land
.no:        scf
            ret
.off:       ld a, $80                       ; (3E/C2E7: it runs off from where the party is)
            ld [ws_cb], a
            ld a, $70
            ld [ws_cbx], a
            ld a, $6F
            ld [ws_cby], a
            xor a
            jp v_set
.ship:      ld a, [SRAM_PAGE + $20]         ; the Enterprise takes off ($6020 bit 4, not 5)
            and $30
            cp $10
            jr nz, .no
            ld a, $2A
            call sfx_play
            ld a, 4
            jp v_set
.foot:      ld a, [SRAM_PAGE + $20]         ; an airship under the party (3E/C303)
            rra
            jr nc, .b6
            ld a, [SRAM_PAGE + $00]
            and a
            jr z, .inv
            call v_here
            jr nz, .inv
            ld a, 5
            jr .board
.b6:        ld a, [SRAM_PAGE + $20]
            bit 6, a
            jr z, .inv
            ld a, [world]
            ld hl, SRAM_PAGE + $03
            cp [hl]
            jr nz, .inv
            call v_here
            jr nz, .inv
            ld a, 6
            jr .board
.inv:       jp v_inv
.board:     push af
            ld a, $2D
            call sfx_play
            pop af
            jp v_set
; the Invincible (3E/C942): on foot on it ($6004 shown, world $6007, at $6005 / $6006): inside
; (its entrance 0 of the world, 3E/C292; $602B bit 7 from the tile's property 1 & $81)
v_inv:      ld a, [SRAM_PAGE + $04]
            and a
            jr z, v_no
            ld a, [world]
            ld hl, SRAM_PAGE + $07
            cp [hl]
            jr nz, v_no
            ld a, [pos_x]
            ld hl, SRAM_PAGE + $05
            cp [hl]
            jr nz, v_no
            ld a, [pos_y]
            inc hl
            cp [hl]
            jr nz, v_no
v_inside:   ld a, [pos_x]
            ld d, a
            ld a, [pos_y]
            ld e, a
            call map_mt
            ld l, a
            ld h, W_PROP1
            ld a, [hl]
            and $81
            ld hl, SRAM_PAGE + $2B
            res 7, [hl]
            jr z, .e
            set 7, [hl]
.e:         xor a                           ; FF3's $44 = $80, $45 = 0: entrance 0
            ld [trig_id], a
            ld a, TR_WENT
            ld [trig], a
            and a
            ret
v_no:       scf
            ret
; B on the world map (3E/C282): in the Invincible: inside; on foot: the Invincible's check
v_bbtn:     ld a, [veh]
            and a
            jr z, v_inv
            cp 7
            jr z, v_inside
            scf
            ret
; Z when the party stands on the parked vehicle
v_here:     ld a, [pos_x]
            ld hl, SRAM_PAGE + $01
            cp [hl]
            ret nz
            ld a, [pos_y]
            inc hl
            cp [hl]
            ret
; landing (3E/C7A5): property 1 & the landing flag: not here; else parked here and on foot
; (the Enterprise becomes the ship). Under the sea: surfacing (3E/C786); on the surface world's
; sea (tile $1E) with $6020 bit 7: diving (3E/C7E4)
v_land:     ld a, [pos_x]
            ld d, a
            ld a, [pos_y]
            ld e, a
            call map_mt
            ld c, a
            ld l, a
            ld h, W_PROP1
            ld b, [hl]
            ld a, [world]
            cp 4
            jr nz, .nu
            bit 1, b                        ; surfacing where property 1 bit 1 is clear
            jr nz, .no
            ld a, $2D
            call sfx_play
            ld a, 3
            jp v_goto_here
.nu:        ld a, [veh]
            ld hl, vtab + VT_LAND
            call v_hla
            ld a, [hl]
            and b
            jr z, .ok
            ld a, [world]                   ; not here: diving?
            cp 3
            jr nz, .no
            ld a, c                         ; (FF3: 2 x the tile = $3C)
            cp $1E
            jr nz, .no
            ld a, [SRAM_PAGE + $20]
            bit 7, a
            jr z, .no
            ld a, $29
            call sfx_play
            ld a, 4
            jp v_goto_here
.ok:
            ld a, [pos_x]
            ld [SRAM_PAGE + $01], a
            ld a, [pos_y]
            ld [SRAM_PAGE + $02], a
            ld a, [veh]
            cp 5
            jr z, .nw
            ld a, [world]
            ld [SRAM_PAGE + $03], a
.nw:        ld a, $24
            call sfx_play
            ld a, [veh]
            cp 4
            ld a, 3
            jr z, .s
            xor a
.s:         jp v_set
.no:        call m_sfx_err_f
            scf
            ret
m_sfx_err_f:
            ld a, $06
            jp sfx_play

; airships at a world's edge (3E/C566 / C966): world 0's tile $64 takes them to world 2 (3 once
; $6021 bit 5) at (32, 222), the floating continent's place kept in $600C / $600D (FF3's $27
; format); worlds 2 / 3 at (32, 224) back to it. C set: changed (no step)
v_edge:     ld a, [world]
            and a
            jr nz, .up
            ld a, c                         ; (FF3 compares 2 x the tile: $C8)
            cp $64
            jr nz, .n
            ld a, [pos_x]
            sub 7
            ld [SRAM_PAGE + $0C], a
            ld a, [pos_y]
            sub 7
            ld [SRAM_PAGE + $0D], a
            ld a, [SRAM_PAGE + $21]
            and $20
            cp 1
            ld a, 2
            adc 0
            ld d, 25 + 7
            ld e, 215 + 7
            jr v_goto
.up:        cp 4
            jr z, .n
            ld a, d
            cp 32
            jr nz, .n
            ld a, e
            cp 224
            jr nz, .n
            ld a, [SRAM_PAGE + $0C]
            add 7
            ld d, a
            ld a, [SRAM_PAGE + $0D]
            add 7
            ld e, a
            xor a
            jr v_goto
.n:         and a
            ret
; to world A at the party's place
v_goto_here:
            ld b, a
            ld a, [pos_x]
            ld d, a
            ld a, [pos_y]
            ld e, a
            ld a, b
; to world A at (D, E): the world map loaded there (C set)
v_goto:     ld [world], a
            ld a, d
            ld [wm_x], a
            ld [enter_x], a
            ld a, e
            ld [wm_y], a
            ld [enter_y], a
            call map_change
            scf
            ret

; ---- the party in its vehicle (3E/D8D3): OAM 0-3 from the vehicles' poses + the vehicle's
; tiles; a ground vehicle's frame from the step, an airship's from the frame counter
V_TILES:    db 0, $38, $20, $50, $68, $68, $68, $68
v_oam:      ld a, [veh]
            cp 4
            jr nc, .air
            ld a, [step]
            and a
            jr z, .f0
            dec a
.f0:        and 8
            jr .fb
.air:       ld a, [frame]
            add a
            and 8
.fb:        ld b, a
            ld a, [facing]                  ; right $00, left $10, down $30, up $20
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
            ld hl, vposes
            call v_hla
            ld a, [veh]                     ; the row: 3E/D8CA relative to on foot ($6C)
            push hl
            ld hl, vtab + VT_ROW
            call v_hla
            ld a, [hl]
            sub $6C - (VIEW_Y * 16 + 13)    ; (3 pixels above the cell as FF3)
            ld e, a
            ld a, [veh]
            ld hl, V_TILES
            call v_hla
            ld a, [hl]
            ld [v_toff], a
            pop hl
            ld d, VIEW_X * 16 + 8
            ld bc, oam_buf
; four sprites at D, E from the poses at HL with tile offset v_toff (UL, DL, UR, DR)
v_quad:     call .spr
            ld a, e
            add 8
            ld e, a
            call .spr
            ld a, e
            sub 8
            ld e, a
            ld a, d
            add 8
            ld d, a
            call .spr
            ld a, e
            add 8
            ld e, a
.spr:       ld a, e
            ld [bc], a
            inc c
            ld a, d
            ld [bc], a
            inc c
            ld a, [v_toff]
            add [hl]
            inc hl
            ld [bc], a
            inc c
            ld a, [hl+]
            call oam_attr
            ld [bc], a
            inc c
            ret

; ---- the parked vehicle (3E/DAD4 ship, DB09 / DB2F airships) at OAM 36-39, after the people
v_parked:   ld a, [wmode]                   ; FF3's world-map sprites (src/wspr.s)
            and a
            ret z
            %FAR B_WSPR, ws_world
            ret
; ---- the walking member ($600E): graphics set (3F/F77B: toad $16, mini $17, else the job) and
; palette (3A/9050: toad $16, a job's own, the Onion Kids by member: 0, $17-$19)
char_update:
            ld a, [SRAM_PAGE + $0E]
            ld l, a
            ld h, high(SRAM_PAGE + $100)
            inc l
            inc l
            ld b, [hl]                      ; status
            dec l
            dec l
            ld c, [hl]                      ; job
            ld a, $16
            bit 5, b
            jr nz, .s
            ld a, $17
            bit 3, b
            jr nz, .s
            ld a, c
.s:         and $3F
            ld [char_set], a
            ld a, $16
            bit 5, b
            jr nz, .p
            ld a, c
            and a
            jr nz, .p
            ld a, l                         ; an Onion Kid: by member
            rlca
            rlca
            and 3
            jr z, .p
            add $16
.p:         and $3F
            ld [char_pal], a
            ret

; Select on the map (3E/C258, on foot): the next member not dead or stone shows (3F/F72C);
; its tiles by general DMA and the palettes in the next V-Blank
v_select:   ld a, [veh]
            and a
            ret nz
            ld a, $17
            call sfx_play
            ld b, 4
.n:         ld a, [SRAM_PAGE + $0E]
            add $40
            ld [SRAM_PAGE + $0E], a
            ld l, a
            ld h, high(SRAM_PAGE + $100)
            inc l
            inc l
            ld a, [hl]
            and $C0
            jr z, .ok
            dec b
            jr nz, .n
.ok:        call char_update
            call pal_spr
            call pal_load
            ld a, [char_set]                ; (staged in work RAM for the DMA)
            add $40
            ld h, a
            ld l, 0
            ld de, SCRATCH
            ld bc, $100
            ld a, B_CHARS
            call far_copy
            call wait_vbl
            ld a, 1
            ldh [rVBK], a
            ld a, high(SCRATCH)
            ldh [rHDMA1], a
            ld a, low(SCRATCH)
            ldh [rHDMA2], a
            ld a, $80
            ldh [rHDMA3], a
            xor a
            ldh [rHDMA4], a
            ld a, 15
            ldh [rHDMA5], a
            xor a
            ldh [rVBK], a
            jp pal_apply

section wram, $DFC0
vposes:     ds 64                           ; (work RAM bank 1)

section wram, $C2E0
vtab:       ds 24
w_p1:       ds 1
w_p2:       ds 1
v_toff:     ds 1
