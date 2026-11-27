; FF3's world maps on the Game Boy Color ($3E $C859 load world map, $3A $8F43 init world map,
; $3E $C65D check destination tile, $3E $C1B0 entrances). The 256 x 256 maps are unpacked at
; build time (tools/gb3n/data.py world_rows): world map wi (worlds 0/1, 2, 3, 4) row y in bank
; B_WORLD0 + 4 * wi + y / 64 at $4000 + 256 * (y & 63).
;   B_WINFO $4000 + $400 * world: tileset as the normal maps' (UL, UR, DL, DR, palette, property
;           1, property 2; 128 each)   $5400 + 16 * world: BG palettes (NES)
;           $5500 entrance maps, world 0 (64)   $5540 the other worlds (64)
;   B_WGFX  $4000 + $1000 * (world & 6) / 2: the 256 BG tiles

W_TSET     = $4000
W_PALS     = $5400
W_ENT0     = $5500
W_ENT1     = $5540

section bank B_FIELD, $4800
; ---- the world map (LCD off or behind the guard), the party at (wm_x, wm_y)
world_enter:
            ld a, 255
            ld [cmask], a
            ld a, [world]                   ; tileset: 7 pages of 128
            add a
            add a
            add high(W_TSET)
            ld h, a
            ld l, 0
            ld d, W_UL
            ld c, 7
.ts:        push bc
            ld e, 0
            ld bc, 128
            ld a, B_WINFO
            call far_copy
            inc d
            pop bc
            dec c
            jr nz, .ts
            ld a, [world]                   ; BG palettes: the world's base palette
            swap a
            add low(W_PALS)
            ld l, a
            ld h, high(W_PALS)
            ld de, nes_pal
            ld bc, 16
            ld a, B_WINFO
            call far_copy
            call pal_spr                    ; sprite palettes as on the maps
            call pal_load
            ld a, [world]                   ; BG tiles: 0-127 at $9000, 128-255 at $8800
            and 6
            rra
            swap a
            add high(W_TSET)
            ld h, a
            ld l, 0
            push hl
            xor a
            ldh [rVBK], a
            ld de, $9000
            ld bc, $800
            ld a, B_WGFX
            call far_copy
            pop hl
            ld a, h
            add 8
            ld h, a
            ld de, $8800
            ld bc, $800
            ld a, B_WGFX
            call far_copy
            ld a, [char_set]                ; the walking character's tiles
            and $3F
            add $40
            ld h, a
            ld l, 0
            ld a, 1
            ldh [rVBK], a
            ld de, $8000
            ld bc, $100
            ld a, B_CHARS
            call far_copy
            xor a
            ldh [rVBK], a
            ld hl, NPC1                     ; no people on the world map
            ld de, $200
            call memclr
            ld hl, A_POSE
            ld de, poses
            ld bc, 64
            ld a, B_MAPAUX
            call far_copy
            ld a, [wm_x]
            ld [pos_x], a
            ld a, [wm_y]
            ld [pos_y], a
            xor a
            ld [step], a
            ld [line_n], a
            ld [z_lev], a
            ld [trig], a
            ld [dlg_on], a
            call cam_set
            ld c, 0                         ; the 16 rows of the ring
.row:       push bc
            ld a, [cam_y]
            add c
            ld e, a
            ld a, [cam_x]
            ld d, a
            call line_row
            call line_flush
            pop bc
            inc c
            ld a, c
            cp 16
            jr nz, .row
            call scroll_set
            call party_oam
            jp npc_oam

; A = the world map's metatile at (D, E) (0-255, wrapping)
world_mt:   ld a, [world]                   ; wi: worlds 0 / 1 -> 0, 2 -> 1, 3 -> 2, 4 -> 3
            and a
            jr z, .w
            dec a
.w:         add a
            add a
            ld l, a
            ld a, e
            rlca
            rlca
            and 3
            add l
            add B_WORLD0
            push af
            ld a, e
            and 63
            add $40
            ld h, a
            ld l, d
            pop af
            jp far_byte

; on foot over world metatile C ($3E $C65D: impassable when property 1 bit 0 is set; bit 7 a
; trigger: property 2 bit 7 an event (its script id), else an entrance after the step)
world_pass: ld b, W_PROP1
            ld a, [bc]
            bit 0, a
            jr nz, .no
            bit 7, a
            jr nz, .tr
            bit 6, a                        ; an encounter tile ($3E $C6D9)
            call nz, enc_world
            jr .ok
.tr:
            inc b
            ld a, [bc]
            bit 7, a
            jr nz, .ev
            ld [trig_id], a
            ld a, TR_WENT
            ld [trig_next], a
.ok:        and a
            ret
.ev:        and $7F
            call trig_script
            and a
            ret
.no:        scf
            ret

; ---- a world map entrance: the map from FF3's entrance tables (00/8800 world 0, 00/8840)
world_in:   ld a, [pos_x]
            ld [wm_x], a
            ld a, [pos_y]
            ld [wm_y], a
            ld a, [trig_id]
            and 63
            ld l, a
            ld h, high(W_ENT0)
            add low(W_ENT0)
            ld l, a
            ld a, [world]
            and a
            jr z, .w0
            ld a, l
            add W_ENT1 - W_ENT0
            ld l, a
.w0:        ld a, B_WINFO
            call far_byte
            ld [map_id], a
            xor a
            ld [wmode], a
            ld [map_sp], a
            ld a, $FF
            ld [enter_x], a
            jp map_change

; back to the world map where the party stood
world_back: ld a, 1
            ld [wmode], a
            jp map_change

; out to the world map from a deeper map ($3F $E2CE: the map's exit, properties byte 11, through
; the exit tables 00/8880 x / 00/88C0 y)
world_exit: ld a, [map_props + 11]
            and 63
            ld l, a
            ld h, 0
            push hl
            ld de, A_EXITX
            add hl, de
            ld a, B_MAPAUX
            call far_byte
            ld [wm_x], a
            pop hl
            ld de, A_EXITY
            add hl, de
            ld a, B_MAPAUX
            call far_byte
            ld [wm_y], a
            xor a
            ld [map_sp], a
            jr world_back

section wram, $C2C0
wmode:      ds 1                            ; 1: the world map
wm_x:       ds 1
wm_y:       ds 1
cmask:      ds 1
