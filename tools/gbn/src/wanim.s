; FF1 native engine: the animated sea and rivers (owner's list, 2026-11-24; FF1 has none). The
; build (build.py water_anim) finds the overworld's commonest sea and river metatiles whose tiles
; are only used where the shifted picture stays right (the same corner everywhere, or a tile
; whose shifted quarters are equal), and makes 16 phases of each 16 x 16 picture shifted a pixel
; (sea sideways, river downwards). Every 8 frames a new phase; its tiles go to VRAM right after
; the frame wait, while the V-Blank lasts (the rest the next frame).
WANIM_BANK = 106

section bank 0, $3F94
wa_tick:    ldh a, [maptype]
            and a
            ret z
            ld a, [ap_on]                   ; (not under the airship's view)
            and a
            ret nz
            ldh a, [frame]
            and 7
            jr nz, .go
            xor a
            ld [wa_i], a
            ldh a, [frame]
            rrca
            rrca
            rrca
            and 15
            ld [wa_ph], a
.go:        ld a, [wa_i]
            cp 8
            ret nc
            ldh a, [rLCDC]
            bit 7, a
            ret z
            ld a, WANIM_BANK
            call sbank
            jp wa_run

section bank 0, $2591
; the next tiles of this phase while the V-Blank lasts (bank WANIM_BANK mapped): entry e's tile
; for corner q at $4010 + 16 e + q (DMG + 4), its frame at $4100 + $800 e (DMG + $400) +
; 64 phase + 16 q
wa_run:     ldh a, [rLY]
            sub 144
            cp 8
            ret nc
            ld a, [wa_i]
            cp 8
            ret nc
            ld c, a                         ; C = slot (entry C / 4, corner C & 3)
            srl a
            srl a
            ld b, a
            ld a, [$4000]
            dec a
            cp b
            jr c, .done
            ldh a, [is_cgb]
            and a
            ld e, 0
            jr nz, .c
            ld e, 4
.c:         ld a, b                         ; D = the tile
            swap a
            add a, $10
            add a, e
            ld l, a
            ld a, c
            and 3
            add a, l
            ld l, a
            ld h, $40
            ld d, [hl]
            ld a, [wa_ph]                   ; HL = its frame
            ld l, a
            srl a
            srl a
            add a, e
            ld e, a
            ld a, b
            add a, a
            add a, a
            add a, a
            add a, e
            add a, $41
            ld h, a
            ld a, l
            and 3
            rrca
            rrca
            ld l, a
            ld a, c
            and 3
            swap a
            or l
            ld l, a
            ld a, d                         ; DE = the tile's VRAM ($8800 mode)
            swap a
            ld e, a
            and $0F
            bit 7, d
            jr z, .lo
            add a, $80 - $90
.lo:        add a, $90
            ld d, a
            ld a, e
            and $F0
            ld e, a
            jp wa_cp
.done:      ld a, 8
            ld [wa_i], a
            ret

section bank 0, $1798
wa_cp:      ld b, 16                        ; the tile's 16 bytes, then the next slot
.cp:        ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .cp
            ld hl, wa_i
            inc [hl]
            jp wa_run

section wram, $C992                         ; (between the SGB variables and its queue)
wa_i:       ds 1
wa_ph:      ds 1
