; ---- random battles (FF3 3D/BC5B): a step onto a tile whose property 1 has bit 6 set asks the
; random table; a battle starts when the step ends (FF3 $AB = $20: act $20, act_id = battle id).
; Normal maps (3D/BDB9): battle if rnd < the map's rate (39/BE00 + map, 39/BF00 off world 0),
; the group from 2E/92F0 / 93F0 + map. World maps (3D/BC68): the rate and group by world and
; vehicle (2E/9D40-9D4F), world 0 / world 3 by the party's place (2E/9CF0, 2E/9D00). The battle
; from the group's eight (2E/94F0 + 8 group) by the second counter $F7 (3D/BD4D, table 3D/BD78).
; Tables copied at build time into BDATA_BANK (build.py bdata).
ENC_ONE    = $4000              ; 2E/9D40-9D4F
ENC_W0     = $4010              ; 2E/9CF0 (16)
ENC_W3     = $4020              ; 2E/9D00 (64)
ENC_SLOT   = $4060              ; 3D/BD78 (64)
ENC_GRP0   = $4100              ; 2E/92F0 (256)
ENC_RATE0  = $4300              ; 39/BE00 (256), 39/BF00 at $4400
ENC_SETS   = $4800              ; 2E/94F0: 8 battle ids a group

; fix:C711: the random table walked forward or back ($F5 / $F6)
rnd_get:    ld a, [rnd_f6]
            bit 7, a
            jr nz, .dn
            ld a, [rnd_f5]
            inc a
            ld [rnd_f5], a
            jr nz, .get
            jr .flip
.dn:        ld a, [rnd_f5]
            dec a
            ld [rnd_f5], a
            jr nz, .get
.flip:      ld a, [rnd_f6]
            add a, $A0
            ld [rnd_f6], a
.get:       ld a, [rnd_f5]
            ld l, a
            ld h, high(N_RNG)
            ld a, [hl]
            ret

; a byte of BDATA_BANK at HL
enc_rd:     ld a, BDATA_BANK
            jp rd_byte

; normal map (3D/BDB9)
enc_map:    ld a, [ev_on]                   ; (none while an event runs: $6C)
            and a
            ret nz
            call rnd_get
            ld b, a
            ld a, [cur_map]
            ld l, a
            ld h, high(ENC_RATE0)
            ld a, [cur_grp]
            and a
            jr z, .r
            inc h
.r:         push bc
            call enc_rd
            pop bc
            ld c, a
            ld a, b
            cp c
            ret nc                          ; (rnd >= rate)
            ld a, [cur_map]
            ld l, a
            ld h, high(ENC_GRP0)
            ld a, [cur_grp]
            and a
            jr z, .g
            inc h
.g:         call enc_rd
            jp enc_pick

; world map (3D/BC68): rate by world / vehicle (FF3 $78 / $42)
enc_world:  ld a, [ev_on]
            and a
            ret nz
            ld a, [GS + $0F]                ; (the vehicle: on foot until the vehicles are in)
            ld [enc_v], a
            ld a, [cur_world]
            and a
            jr nz, .w2
            ld e, 7                         ; floating continent: on foot $9D47, canoe $9D48,
            ld a, [enc_v]                   ;   ship $9D49, else none
            and a
            jr z, .rate
            inc e
            cp 2
            jr z, .rate
            inc e
            cp 3
            jr z, .rate
            ret
.w2:        cp 2
            jr nz, .w3
            ld e, $0A                       ; flooded world: on foot only
            ld a, [enc_v]
            and a
            ret nz
            jr .rate
.w3:        cp 3
            jr nz, .uw
            ld e, $0B                       ; surface world: on foot, canoe, ship, chocobo
            ld a, [enc_v]
            and a
            jr z, .rate
            inc e
            cp 2
            jr z, .rate
            inc e
            cp 3
            jr z, .rate
            ld b, a
            ld a, [GS + $2F]
            rrca
            ret nc
            ld e, $0E
            ld a, b
            cp 4
            jr nc, .rate
            ret
.uw:        ld e, $0F                       ; underwater
.rate:      ld l, e
            ld h, high(ENC_ONE)
            call enc_rd
            ld [enc_r], a
            call rnd_get
            ld b, a
            ld a, [enc_r]
            ld c, a
            ld a, b
            cp c
            ret nc
            ld a, [cur_world]               ; the group (3D/BCD1)
            and a
            jr nz, .g2
            ld a, [enc_v]
            and a
            jr z, .gp0
            ld l, 0                         ; canoe $9D40, ship $9D41
            cp 2
            jr z, .g1
            inc l
.g1:        ld h, high(ENC_ONE)
            call enc_rd
            jp enc_pick
.gp0:       ld a, [px]                      ; world 0: ((x and $7F) >> 5) | ((y and $60) >> 3)
            and $7F
            swap a
            rrca
            and 3
            ld b, a
            ld a, [py]
            and $60
            rrca
            rrca
            rrca
            or b
            ld l, a
            ld h, high(ENC_W0)
            ld a, l
            add a, low(ENC_W0)
            ld l, a
            call enc_rd
            jp enc_pick
.g2:        cp 2
            jr nz, .g3
            ld l, 2                         ; flooded: $9D42
            jr .g1
.g3:        cp 3
            jr nz, .g4
            ld a, [enc_v]
            ld l, 3                         ; canoe $9D43
            cp 2
            jr z, .g1
            inc l                           ; ship $9D44
            cp 3
            jr z, .g1
            inc l                           ; airship $9D45
            cp 4
            jr nc, .g1
            ld a, [px]                      ; world 3: (x >> 5) | ((y and $E0) >> 2)
            swap a
            rrca
            and 7
            ld b, a
            ld a, [py]
            and $E0
            rrca
            rrca
            or b
            add a, low(ENC_W3)
            ld l, a
            ld h, high(ENC_W3)
            call enc_rd
            jp enc_pick
.g4:        ld l, 6                         ; underwater $9D46
            jr .g1

; A = group: one of its eight battles (3D/BD4D) -> act $20, act_id
enc_pick:   ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, ENC_SETS
            add hl, de
            push hl
            ld hl, rnd_f7                   ; $F7++, the random table at it, 0-63 -> slot
            inc [hl]
            ld l, [hl]
            ld h, high(N_RNG)
            ld a, [hl]
            and $3F
            add a, low(ENC_SLOT)
            ld l, a
            ld h, high(ENC_SLOT)
            call enc_rd
            pop hl
            add a, l
            ld l, a
            jr nc, .n
            inc h
.n:         call enc_rd
            ld [act_id], a
            ld a, $20
            ld [act], a
            ret

; from the field: battle act_id (fix:E26A: the flash, the battle in CODE2, the map reloaded)
battle_go:  ld a, [act_id]
            ld [btl_id], a
            ld a, CODE2
            ld hl, btl_main
            call far_call
            ld a, 1
            ldh [rSVBK], a
            ld a, $FF                       ; (no map title after a battle)
            ld [m_title], a
            ld [m_title2], a
            jp load_map

section wram, $C3E8
btl_id:     ds 1
btl_n:      ds 1
rnd_f7:     ds 1
enc_v:      ds 1
enc_r:      ds 1
