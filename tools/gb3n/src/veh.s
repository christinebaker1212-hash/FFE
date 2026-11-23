; ---- vehicles on the world maps (FF3 bank 3E): the vehicle in GS + $0F (FF3's $46, saved at
; $600F): 0 on foot, 1 chocobo, 2 canoe, 3 ship, 4-6 airships, 7 the Invincible. Passability
; by vehicle (3E/C6CD), boarding / leaving (3E/C4FC: canoe on rivers, the ship from its place,
; dismounting onto walkable land; 3E/C2B7 A: airships, the ship taking off, landing by 3E/C851),
; speeds (3E/CD76), the vehicle's sprite (3E/D8D3) and the parked ones (3E/DAD4, DB09, DB2F).
; The parked vehicle: $6000 shown, $6001 / $6002 its tile, $6003 its world; flags $6020.
VEH_TILES  = $6000              ; SPR_BANK: 0B/8800 (96 tiles: sprite tiles $20-$7F)
VEH_FR     = $7F50              ;   3E/DCAA vehicle frames (GB attributes)
VEH_Y      = $7FA0              ;   3E/D8CA the sprite's y by vehicle
VEH_MASK   = $7FA8              ;   3E/C6CD impassable when (property 1 & mask) = mask
VEH_LAND   = $7FB0              ;   3E/C851 no landing where (property 1 & it)
VEH_SPD    = $7FB8              ;   3E/CD76 pixels a frame
VEH        = GS + $0F

; the vehicles' tiles -> VRAM bank 1 tiles $20-$7F (world maps)
veh_gfx:    ldh a, [is_world]
            and a
            ret z
            ld a, SPR_BANK
            ld [vc_src], a
            ld hl, VEH_TILES
            ld de, $8200
            ld b, 96
            ld a, 1
            jp vcopyx

; a byte of SPR_BANK at VEH_* + vehicle
veh_tab:    ld e, a
            ld a, [VEH]
            add a, e
            ld l, a
            ld h, high(VEH_MASK)
            ld a, SPR_BANK
            jp rd_byte

; 3E/C65D + C4FC: the world map step onto property 1 = A (HL its M_P1 cell): carry = stop;
; else Z = an ordinary step (the caller's trigger / battle checks), NZ = a vehicle step (none)
veh_step:   ld [veh_p1], a
            ld a, low(VEH_MASK)
            call veh_tab
            ld b, a
            ld a, [veh_p1]
            and b
            cp b
            jr z, veh_block
            ld a, [VEH]
            and a
            ret z                           ; (on foot: the usual checks)
            cp 4
            jr nc, .air
            cp 1
            jr nz, .vs
            ld a, [veh_p1]                  ; (the chocobo: no entrances, no battles)
            bit 7, a
            scf
            ret nz
.vs:        or 1                            ; (canoe / ship / chocobo: a plain step)
            ret
.air:       or 1                            ; (airships: no triggers, no battles)
            ret

; the vehicle can't go there (3E/C51B, C52B, C541): board the canoe or the ship, or get off
veh_block:  ld a, [VEH]
            and a
            jr z, .foot
            cp 2
            jr z, veh_off
            cp 3
            jr z, .ship
            scf
            ret
.foot:      call veh_canoe
            ret nc
            jp veh_ship
.ship:      call veh_canoe
            ret nc
            ; (fall through)
; 3E/C5B5: get off onto walkable land (the ship left where it was)
veh_off:    ld a, [veh_p1]
            rra
            ret c
            ld a, [VEH]
            ld b, a
            xor a
            ld [VEH], a
            ld a, b
            cp 3
            call z, veh_park
            call snd_world
            or 1
            ret
; 3E/C59E: the ship parked at the party's tile
veh_park:   ld a, [px]
            ld [GS + $01], a
            ld a, [py]
            ld [GS + $02], a
            ld a, [cur_world]
            ld [GS + $03], a
            ret
; 3E/C5DE: board the canoe on a river (property 1 bit 1 clear), the canoe obtained ($602E bit 0)
veh_canoe:  ld a, [GS + $2E]
            rra
            ccf
            ret c
            ld a, [veh_p1]
            bit 1, a
            scf
            ret nz
            ld a, [VEH]
            cp 3
            call z, veh_park
            ld a, 2
            ld [VEH], a
            call snd_world
            or 1
            ret
; 3E/C61B: board the ship at the destination tile
veh_ship:   ld a, [GS + $20]
            rra
            ccf
            ret nc
            ccf
            and $10                         ; ($6020 bit 5)
            scf
            ret nz
            ld a, [GS + $00]
            and a
            scf
            ret z
            ld a, [GS + $03]
            ld b, a
            ld a, [cur_world]
            cp b
            scf
            ret nz
            ld a, [GS + $01]
            ld b, a
            ld a, [ppx]
            cp b
            scf
            ret nz
            ld a, [GS + $02]
            ld b, a
            ld a, [ppy]
            cp b
            scf
            ret nz
            ld a, 3
            ld [VEH], a
            call snd_world
            or 1
            ret

; 3E/C2B7: A on the world map, standing
veh_a:      ld a, [VEH]
            and a
            jr z, .foot
            cp 1
            jr z, .choco
            cp 3
            jr z, .ship
            cp 4
            ret c
            cp 7
            ret z                           ; (the Invincible's jump: later)
            jp veh_land
.choco:     xor a                           ; (the chocobo runs off)
            ld [VEH], a
            jp snd_world
.ship:      ld a, [GS + $20]                ; (the ship takes off as the Enterprise)
            and $30
            cp $10
            ret nz
            ld a, 4
            jr veh_board
.foot:      ld a, [GS + $20]
            and 1
            jr z, .f2
            ld a, [GS + $00]
            and a
            ret z
            call .here
            ret nz
            ld a, 5
            jr veh_board
.f2:        ld a, [GS + $20]
            bit 6, a
            jr z, .inv
            ld a, [GS + $03]
            ld b, a
            ld a, [cur_world]
            cp b
            ret nz
            call .here
            jr nz, .inv
            ld a, 6
            jr veh_board
.inv:       ld a, [GS + $04]                ; 3E/C942: the Invincible here: its inside
            and a
            ret z
            ld a, [GS + $07]
            ld b, a
            ld a, [cur_world]
            cp b
            ret nz
            ld a, [GS + $05]
            ld b, a
            ld a, [px]
            cp b
            ret nz
            ld a, [GS + $06]
            ld b, a
            ld a, [py]
            cp b
            ret nz
            jr veh_inv
.here:      ld a, [GS + $01]                ; Z if the parked vehicle is at the party's tile
            ld b, a
            ld a, [px]
            cp b
            ret nz
            ld a, [GS + $02]
            ld b, a
            ld a, [py]
            cp b
            ret
; 3E/C35C: board vehicle A
veh_board:  ld [VEH], a
            ld b, $AD
            cp 4
            jr nz, .s
            ld b, $AA
.s:         ld a, b
            ld [S49], a
            jp snd_world
; 3E/C7A5: land the airship where property 1 allows (the Enterprise lands as the ship)
veh_land:   ld a, [px]
            ld e, a
            ld a, [py]
            ld d, a
            call map_at
            ld h, high(M_P1)
            ld a, [hl]
            ld [veh_p1], a
            ld a, [cur_world]
            cp 4
            ret nc                          ; (underwater: the Nautilus surfacing, later)
            ld a, low(VEH_LAND)
            call veh_tab
            ld b, a
            ld a, [veh_p1]
            and b
            ret nz                          ; (no landing here; the Nautilus diving: later)
            ld a, [px]
            ld [GS + $01], a
            ld a, [py]
            ld [GS + $02], a
            ld a, [VEH]
            cp 5
            jr z, .c
            ld a, [cur_world]
            ld [GS + $03], a
.c:         ld a, [VEH]
            cp 4
            ld b, 3
            ld c, $D3
            jr z, .n
            ld b, 0
            ld c, $A4
.n:         ld a, c
            ld [S49], a
            ld a, b
            ld [VEH], a
            jp snd_world

; 3E/CD7E the step speed (pixels a frame): underwater 1; speed 8 starts a step at 4
veh_speed:  ldh a, [is_world]
            and a
            ld a, 1
            ret z
            ld a, [cur_world]
            cp 4
            ld a, 1
            ret nc
            ld a, low(VEH_SPD)
            call veh_tab
            ret

; ---- sprites: the party's vehicle (instead of the walking sprite) and the parked ones
; (OAM 36-39). B, C = OAM x, y; A = tile offset; E = frame offset (DCAA); HL = OAM
veh_spr:    ld [veh_off8], a
            push hl
            ld a, e
            add a, low(VEH_FR)
            ld l, a
            ld h, high(VEH_FR)
            ld de, veh_buf
            push bc
            ld bc, 8
            ld a, SPR_BANK
            call rd_copy
            pop bc
            pop hl
            ld de, veh_buf
            call .s                         ; TL
            ld a, c
            add a, 8
            ld c, a
            call .s                         ; BL
            ld a, b
            add a, 8
            ld b, a
            ld a, c
            sub 8
            ld c, a
            call .s                         ; TR
            ld a, c
            add a, 8
            ld c, a
.s:         ld a, c
            ld [hl+], a
            ld a, b
            ld [hl+], a
            ld a, [de]
            inc de
            push hl
            ld hl, veh_off8
            add a, [hl]
            pop hl
            ld [hl+], a
            ld a, [de]
            inc de
            ld [hl+], a
            ret

; the party's sprite on a vehicle (make_oam's): Z if on foot (the caller draws the walker)
veh_oam:    ldh a, [is_world]
            and a
            ret z
            ld a, [VEH]
            and a
            ret z
            ld a, low(VEH_Y)                ; y = PY0 + 16 + (3E/D8CA - $6F)
            call veh_tab
            add a, PY0 + 16 - $6F
            ld c, a
            ld b, PX0 + 8
            ld a, [VEH]                     ; animation: the step (airships: the frame count)
            cp 4
            ld a, [mcount]
            jr c, .a
            ld a, [fcnt]
            add a, a
.a:         and 8
            ld d, a
            ld a, [facing]
            ld l, a
            ld h, high(M_FACE)
            ld a, [hl]
            or d
            ld e, a
            ld a, [VEH]
            ld hl, veh_offs
            add a, l
            ld l, a
            jr nc, .o
            inc h
.o:         ld a, [hl]
            ld hl, oam_buf
            call veh_spr
            or 1
            ret
veh_offs:   db 0, $38, $20, $50, $68, $68, $68, $68

; the parked vehicle (3E/DAD4 ship, DB09, DB2F airships) -> OAM 36-39
veh_parked: ld hl, oam_buf + 4 * 36
            ld a, $F0
            ld [hl], a
            ld [oam_buf + 4 * 37], a
            ld [oam_buf + 4 * 38], a
            ld [oam_buf + 4 * 39], a
            ldh a, [is_world]
            and a
            ret z
            ld a, [GS + $20]
            ld c, a
            and 1
            jr nz, .nau
            ld a, c
            and $20
            jr nz, .air
            ld a, [VEH]                     ; the ship (not while on it or the Enterprise)
            cp 3
            ret z
            cp 4
            ret z
            call .world
            ret nz
            ld a, [GS + $00]
            and a
            ret z
            ld e, 0
            ld a, $50
            jr .draw
.nau:       ld a, [VEH]                     ; (3E/DB09)
            cp 5
            ret z
            ld a, [GS + $00]
            and a
            ret z
            jr .ap
.air:       ld a, c                         ; (3E/DB2F)
            and $40
            ret z
            ld a, [VEH]
            cp 6
            ret z
            call .world
            ret nz
.ap:        ld e, $10
            ld a, $68
.draw:      ld [veh_off8], a
            push de
            ld a, [GS + $01]                ; on screen: (tile x 16 - SCX), (tile y 16 - SCY)
            swap a
            and $F0
            ld b, a
            ldh a, [scx]
            ld c, a
            ld a, b
            sub c
            cp 160 + 8
            jr nc, .off
            add a, 8
            ld b, a
            ld a, [GS + $02]
            swap a
            and $F0
            ld d, a
            ldh a, [scy]
            ld c, a
            ld a, d
            sub c
            cp 144 + 8
            jr nc, .off
            add a, 16 - 3
            ld c, a
            pop de
            ld a, [veh_off8]
            ld hl, oam_buf + 4 * 36
            jp veh_spr
.off:       pop de
            ret
.world:     ld a, [GS + $03]
            ld b, a
            ld a, [cur_world]
            cp b
            ret

; 3E/C282 B on the world map: aboard the Invincible, its inside (3E/C292)
veh_b:      ld a, [VEH]
            cp 7
            ret nz
veh_inv:    xor a                           ; (the world map's entrance 0)
            ld [act_id], a
            ld a, $90
            ld [act], a
            ret

section wram, $C3F2
veh_p1:     ds 1
veh_off8:   ds 1
veh_buf:    ds 8
