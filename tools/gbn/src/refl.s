; FF1 native engine: the party's / vehicle's reflection on water (owner's list, 2026-11-24): on
; the overworld, on foot, by ship or canoe, when the tile below the party is sea or river (FF1's
; tile properties: blocked on foot, open to the ship or the canoe; while stepping, below both
; tiles of the step), a mirrored copy of its four sprites sits on that tile, its far row
; wavering a pixel. The Color: darker copies of OBJ palettes 0-3 in 4-7 (made when a map
; loads); DMG / SGB: OBP1, a dimmer mapping. OAM 36-39 (unused on the overworld).
REFL_OAM   = oam_buf + 144

section bank 0, $1698
refl_tick:  xor a                           ; (hidden first)
            ld [REFL_OAM], a
            ld [REFL_OAM + 4], a
            ld [REFL_OAM + 8], a
            ld [REFL_OAM + 12], a
            ldh a, [maptype]
            and a
            ret z
            ld a, [vehicle]
            cp V_AIR
            ret z
            ld a, [px]
            ld e, a
            ld a, [py]
            inc a
            ld d, a
            call refl_wat
            ret nc
            ld a, [moving]
            and a
            jp z, refl_mir
            ld a, [mdx]
            ld b, a
            ld a, [px]
            add a, b
            ld e, a
            ld a, [mdy]
            ld b, a
            ld a, [py]
            add a, b
            inc a
            ld d, a
            call refl_wat
            ret nc
.ok:        jp refl_mir

section bank 0, $3584
refl_mir:   ld hl, oam_buf                  ; B = the lowest row's y
            ld b, 0
            ld c, 4
.m:         ld a, [hl]
            cp b
            jr c, .m1
            ld b, a
.m1:        inc l
            inc l
            inc l
            inc l
            dec c
            jr nz, .m
            ld a, b
            and a
            ret z
            add a, a                        ; C = 2 B + 8 (mirrored about the sprites' foot)
            add a, 8
            ld c, a
            push bc
            ld hl, oam_buf
            ld de, REFL_OAM
            ld b, 4
.e:         ld a, [hl+]                     ; y' = C - y
            cpl
            inc a
            add a, c
            ld [de], a
            inc de
            ld a, [hl+]                     ; x, tile
            ld [de], a
            inc de
            ld a, [hl+]
            ld [de], a
            inc de
            ld a, [hl+]                     ; attributes: flipped, darker
            xor $40
            ld [de], a
            ldh a, [is_cgb]
            and a
            ld a, [de]
            jr z, .dm
            and $FB                         ; (palette 0-3 -> 4-7)
            or 4
            jr .wa
.dm:        or $10                          ; (OBP1)
.wa:        ld [de], a
            inc de
            dec b
            jr nz, .e
            pop bc                          ; the far row (y' = B + 16) wavers
            ld a, b
            add a, 16
            ld c, a
            ldh a, [frame]
            rrca
            rrca
            rrca
            and 7
            add a, low(refl_wv)
            ld l, a
            ld a, high(refl_wv)
            adc a, 0
            ld h, a
            ld b, [hl]
            ld hl, REFL_OAM
            ld e, 4
.w:         ld a, [hl+]
            cp c
            jr nz, .wn
            ld a, [hl]
            add a, b
            ld [hl], a
.wn:        inc l
            inc l
            inc l
            dec e
            jr nz, .w
            ret
refl_wv:    db 0, 1, 1, 1, 0, -1, -1, -1

section bank 0, $3B9C
; D = y, E = x on the overworld: C set if sea or river
refl_wat:   call map_at
            call props
            ld a, d
            and V_FOOT
            ret z
            ld a, d
            and V_SHIP | V_CANOE
            cp V_SHIP | V_CANOE
            ret z
            scf
            ret
; the window layer off now (LCD on) and moved off screen
win_kill:   ldh a, [rLCDC]
            bit 7, a
            ret z
            ld a, [lcdc_on]
            ldh [rLCDC], a
            ld a, 167
            ldh [rWX], a
            ret

section bank 99, $7F00
; the Color: OBJ palettes 4-7 = 0-3 darker and bluer (LCD off or V-Blank: palette RAM read)
refl_pal:   ldh a, [is_cgb]
            and a
            ret z
            ld c, 0                         ; byte index 0, 2, .. 30
.l:         ld a, c
            ldh [rOCPS], a
            ldh a, [rOCPD]
            ld e, a
            ld a, c
            inc a
            ldh [rOCPS], a
            ldh a, [rOCPD]
            ld d, a                         ; DE = colour (b 14-10, g 9-5, r 4-0)
            ld a, e                         ; r
            and 31
            call .dk
            ld [refl_r], a
            ld a, e                         ; g = (DE >> 5) & 31
            and $E0
            ld b, a
            ld a, d
            and 3
            or b
            rlca
            rlca
            rlca
            and 31
            call .dk
            ld [refl_g], a
            ld a, d                         ; b
            rrca
            rrca
            and 31
            call .dk
            add a, 4
            cp 32
            jr c, .b1
            ld a, 31
.b1:        ld [refl_b], a
            ld a, [refl_g]                  ; pack: low = r | g << 5, high = g >> 3 | b << 2
            ld b, a
            rrca
            rrca
            rrca
            and $E0
            ld e, a
            ld a, [refl_r]
            or e
            ld e, a
            ld a, b
            rrca
            rrca
            rrca
            and 3
            ld d, a
            ld a, [refl_b]
            add a, a
            add a, a
            or d
            ld d, a
            ld a, c
            add a, 32
            ldh [rOCPS], a
            ld a, e
            ldh [rOCPD], a
            ld a, c
            add a, 33
            ldh [rOCPS], a
            ld a, d
            ldh [rOCPD], a
            inc c
            inc c
            ld a, c
            cp 32
            jr c, .l
            ret
.dk:        ld b, a                         ; A x 5/8
            srl a
            ld l, a
            ld a, b
            srl a
            srl a
            srl a
            add a, l
            ret

section wram, $C7F8
refl_r:     ds 1
refl_g:     ds 1
refl_b:     ds 1
