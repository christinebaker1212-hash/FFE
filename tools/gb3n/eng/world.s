; FF3 native port: the world map, written from what the everything8215/ff3 listing says FF3 does
; (3E/C0ED world map main, 3E/C859 load world map, 3E/C1E4 check player input / triggers, 3E/C4FC do
; player movement, 3E/C65D check destination tile, 3D/BC68 check random battle, 3E/C1B0 entrance,
; 3F/E2CE exit to the world map). On foot for now; the vehicles join with their events. Our own code.
; Data (port.py): the world maps' rows unpacked in WROWS (4 banks a map, 64 rows each), WTSET (the
; 5 worlds' tilesets as the normal maps' 1 KB blocks, their palettes, the exit / entrance tables,
; the songs, the passability masks, the battle tables), WGFX (256 BG tiles per world pair).

W_PALS     = $5400          ; WTSET: BG palettes per world (5 x 32, RGB555)
W_EXITX    = $5500          ; 00/8880: exits' x (64), 00/88C0: y (64)
W_EXITY    = $5540
W_ENTR     = $5580          ; 00/8800 entrances' maps (world 0, 64), 00/8840 (the others)
W_SONG     = $5600          ; 3B/A027 world map songs by world and vehicle (32), 3B/A047 effects
W_SFX      = $5620
W_PASS     = $5640          ; 3E/C6CD passability masks by vehicle (8)
W_ENC0     = $5700          ; 2E/9CF0 (16), 2E/9D00 (64), 2E/9D40 (16)
W_ENC2     = $5710
W_ENCV     = $5750
z27        = Z + $27        ; FF3: the world position - 7 (we keep px / py: the party's tile)
z42        = Z + $42        ; the vehicle
z46        = Z + $46

section bank 0, $3800

; the world map's index (worlds 0 and 1 share a map: data.WORLD_MAPS)
w_index:    ld a, [world]
            and a
            ret z
            dec a
            ret

; ---- FF3 load world map (3E/C859): its graphics, tileset, palette, song; the party at px / py
world_load: call lcd_off
            ld a, 1
            ldh [maptype], a
            xor a
            ld [moving], a
            ld [mcount], a
            ld [mdx], a
            ld [mdy], a
            ld [q_n], a
            ld [q_rd], a
            ld [de_n], a
            ld [trig], a
            ld [z44], a
            ld [z45], a
            ld [z50], a
            ld [z22], a
            ld [z23], a
            ld [z24], a
            ld [z25], a
            ld [ms_n], a
            ld [box_on], a
            ld hl, O0                       ; (no people on the world map)
            ld de, $100
            call memclr
            ld a, 2                         ; the tileset into WRAM bank 2 (as a normal map's)
            ldh [rSVBK], a
            ld a, WTSET
            call sbank
            ld a, [world]
            add a, a
            add a, a
            add a, $40
            ld h, a
            ld l, 0
            ld de, W_UL
            ld bc, 128
            call memcpy
            ld de, W_UR
            ld bc, 128
            call memcpy
            ld de, W_DL
            ld bc, 128
            call memcpy
            ld de, W_DR
            ld bc, 128
            call memcpy
            ld de, W_PAL
            ld bc, 128
            call memcpy
            ld de, W_P1
            ld bc, 128
            call memcpy
            ld de, W_P2
            ld bc, 128
            call memcpy
            ld a, 1
            ldh [rSVBK], a
            ld a, [world]                   ; BG palettes 0-3
            swap a
            add a, a
            ld l, a
            ld h, high(W_PALS)
            ld de, sh_pal
            ld bc, 32
            call memcpy
            ld a, WGFX                      ; the tiles: world pair (world & 6) / 2
            call sbank
            ld a, [world]
            and 6
            add a, a
            add a, a
            add a, a
            add a, $40
            ld h, a
            ld l, 0
            ld de, $9000
            ld bc, 128 * 16
            call memcpy
            ld de, $8800
            ld bc, 128 * 16
            call memcpy
            call char_id                    ; the walking character, its palettes
            ld [chr_id], a
            ld a, CHARS
            call sbank
            ld a, [chr_id]
            add a, $40
            ld h, a
            ld l, 0
            ld a, 1
            ldh [rVBK], a
            ld de, $8000
            ld bc, 256
            call memcpy
            xor a
            ldh [rVBK], a
            call load_pal.ob
            ld a, 4                         ; facing down (3E/C8DC)
            ld [facing], a
            call w_song
            ld a, [px]                      ; the tile under the party: its layer bit (3E/C10B)
            ld e, a
            ld a, [py]
            ld d, a
            call tile_props
            ld a, [t44]
            and $20
            ld [lay43], a
            xor a
            ld [t44], a
            call draw_all
            call set_scroll
            ldh a, [scx]
            ldh [rSCX], a
            ldh a, [scy]
            ldh [rSCY], a
            call make_oam
            ld a, LCDC_ON
            jp lcd_on

; FF3 play world map song (3E/C93A -> 3B/A006): by world (worlds 1-4: - 1) and vehicle
w_song:     ld a, WTSET
            call sbank
            call w_index
            add a, a
            add a, a
            add a, a
            ld b, a
            ld a, [z46]
            or b
            ld e, a
            ld d, 0
            ld hl, W_SONG
            add hl, de
            ld a, [hl]
            ld [M_SONG], a
            ld a, 1
            ld [M_CTRL], a
            ld hl, W_SFX
            add hl, de
            ld a, [hl]
            or $80
            ld [M_SFX], a
            ret

; ---- one frame of the world map (3E/C112): the step, then (standing) its triggers and the input
w_frame:    call scroll_step
            ld a, [moving]
            and a
            ret nz
            ld a, [z42]                     ; (3E/C14C: the vehicle boarded)
            ld [z46], a
; FF3 check player input / triggers (3E/C1E4)
            ld a, [t44]
            bit 7, a
            jr z, .nt
            bit 6, a
            jr nz, .ex                      ; ($C0: another world: with the vehicles)
            jp w_enter                      ; ($80: an entrance)
.nt:        bit 6, a
            jr z, .in
            jp battle_runw                  ; ($40: a battle, 3E/C19D)
.ex:        xor a
            ld [t44], a
            ret
.in:        ld a, [z6C]
            and a
            jr nz, .ev
            xor a                           ; (Start / Select / A / B: with the menus and vehicles)
            ld [z22], a
            ld [z23], a
            ld [z24], a
            ld [z25], a
.ev:        call ev_step
            ld a, [z20]
            and $0F
            ret z
            ld c, a                         ; facing: right, left, down, up first
            bit 0, c
            ld a, 1
            jr nz, .one
            bit 1, c
            ld a, 2
            jr nz, .one
            bit 2, c
            ld a, 4
            jr nz, .one
            ld a, 8
.one:       ld [facing], a
; FF3 do player movement on foot (3E/C4FC -> C502): the destination's passability
            call w_dest
            ret c
            ld a, [z6C]                     ; (3E/C50F: $E4; the boulder: with its event)
            ld a, 1                         ; FF3 init player movement
            ld [moving], a
            xor a
            ld [mcount], a
            ld a, [facing]
            call dir_dxy
            ld a, b
            ld [mdx], a
            ld a, c
            ld [mdy], a
            jp draw_edge

; FF3 check destination tile (world map, 3E/C65D): C if the vehicle may not go there; a trigger's
; event, a random battle
w_dest:     ld a, [facing]
            call dir_dxy
            ld a, [px]
            add a, b
            ld [tx], a
            ld e, a
            ld a, [py]
            add a, c
            ld [ty], a
            ld d, a
            call tile_props
            ld a, WTSET
            call sbank
            ld a, [z42]
            ld e, a
            ld d, 0
            ld hl, W_PASS
            add hl, de
            ld b, [hl]
            ld a, [t44]
            and b
            cp b
            jr nz, .ok
            scf
            ret
.ok:        ld a, [t44]
            bit 7, a
            jr nz, .trg
            bit 6, a
            jr z, .p
            call enc_world                  ; ($40: a random battle, 3D/BC68)
.p:         and a
            ret
.trg:       ld a, [t45]
            bit 7, a
            jr z, .p                        ; (an entrance: after the step)
            and $7F                         ; (an event trigger, 3E/C911)
            push af
            ld a, [t44]
            and $7F
            ld [t44], a
            pop af
            ld b, a
            ld a, [z6C]
            and a
            jr nz, .p
            ld a, b
            call ev_trig
            and a
            ret

; FF3 check random battle, world map (3D/BC68): the rate by world and vehicle, the group by place
enc_world:  ld a, [z6C]
            and a
            jr nz, .no
            ld a, [z42]                     ; the rate (2E/9D47-9D4F) by world and vehicle
            ld b, a
            ld a, [world]
            and a
            jr nz, .nw0
            ld a, b                         ; floating continent: on foot, canoe, ship
            ld c, 7
            and a
            jr z, .rc
            ld c, 8
            cp 2
            jr z, .rc
            ld c, 9
            cp 3
            jr z, .rc
            jr .no
.nw0:       cp 2
            jr nz, .nw2
            ld a, b                         ; flooded world: on foot
            and a
            jr nz, .no
            ld c, $0A
            jr .rc
.nw2:       cp 3
            jr nz, .uw
            ld a, b                         ; surface world
            ld c, $0B
            and a
            jr z, .rc
            ld c, $0C
            cp 2
            jr z, .rc
            ld c, $0D
            cp 3
            jr z, .rc
            cp 4
            jr c, .no
            ld a, [SV + $2F]
            rrca
            jr nc, .no
            ld c, $0E
            jr .rc
.uw:        ld c, $0F
.rc:        ld a, c
.rate:      ld e, a
            ld d, 0
            ld a, WTSET
            call sbank
            ld hl, W_ENCV
            add hl, de
            ld b, [hl]
            push bc
            call rnd_fld
            pop bc
            cp b
            jr nc, .no
            ld a, WTSET
            call sbank
            ld a, [world]
            and a
            jr nz, .g1
            ld a, [z42]                     ; floating continent
            and a
            jr z, .g0
            cp 2
            ld a, [W_ENCV + 0]
            jr z, .grp
            ld a, [W_ENCV + 1]
            jr .grp
.g0:        ld a, [px]
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
            ld e, a
            ld d, 0
            ld hl, W_ENC0
            add hl, de
            ld a, [hl]
            jr .grp
.g1:        cp 2
            jr nz, .g2
            ld a, [W_ENCV + 2]
            jr .grp
.g2:        cp 3
            jr nz, .g3
            ld a, [z42]
            cp 2
            ld a, [W_ENCV + 3]
            jr z, .grp
            ld a, [z42]
            cp 3
            ld a, [W_ENCV + 4]
            jr z, .grp
            ld a, [px]                      ; surface: x / 32, y / 32 x 8
            swap a
            rrca
            and 7
            ld b, a
            ld a, [py]
            and $E0
            rrca
            rrca
            or b
            ld e, a
            ld d, 0
            ld hl, W_ENC2
            add hl, de
            ld a, [hl]
            jr .grp
.g3:        ld a, [W_ENCV + 6]
.grp:       call enc_grp
            ret                             ; ($44 keeps $40: the battle next frame)
.no:        ld a, [t44]
            and $3F
            ld [t44], a
            ret

; FF3 entrance from the world map (3E/C1B0): the map 00/8800 + trigger id (world 0) / 00/8840
w_enter:    ld a, $93                       ; (sound effect $13)
            ld [M_SFX], a
            ld a, WTSET
            call sbank
            ld a, [t45]
            and $3F
            ld e, a
            ld d, 0
            ld hl, W_ENTR
            ld a, [world]
            and a
            jr z, .w
            ld hl, W_ENTR + $40
.w:         add hl, de
            ld a, [hl]
            ld [cur_map], a
            ld a, [px]                      ; (where to come back: FF3 keeps $27 / $28)
            ld [w_px], a
            ld a, [py]
            ld [w_py], a
            xor a
            ldh [maptype], a
            ld [t44], a
            ld [ms_n], a
            jp load_map                     ; (A = 0: from the world map)

; FF3 exit to the world map (3F/E2CE): the map's exit (T07 $30 & $3F) -> 00/8880 / 88C0
w_exit:     ld a, $94                       ; (sound effect $14)
            ld [M_SFX], a
            ld a, WTSET
            call sbank
            ld a, [T07 + $30]
            and $3F
            ld e, a
            ld d, 0
            ld hl, W_EXITX
            add hl, de
            ld a, [hl]
            ld [px], a
            ld hl, W_EXITY
            add hl, de
            ld a, [hl]
            ld [py], a
            jp world_load

section wram, $C960
w_px:       ds 1
w_py:       ds 1
