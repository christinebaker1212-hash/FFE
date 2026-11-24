; FF1 native engine: the animated sea and rivers (owner's list, 2026-11-24; FF1 has none). The
; build (build.py water_anim) finds the overworld's commonest sea and river metatiles whose tiles
; are only used where the shifted picture stays right (the same corner everywhere, or a tile
; whose shifted quarters are equal), and makes 32 half steps of each 16 x 16 picture: as Final
; Fantasy Legend III's water (owner, 2026-11-24), a pixel per 16 frames, the picture's two halves
; in turn 8 frames apart (sea sideways, river downwards). Every 8 frames a new half step; its tiles
; go to VRAM right after the frame wait, while the V-Blank lasts (the rest the next frame).
WANIM_BANK = 106

section bank 0, $3F94
wa_tick:    ldh a, [maptype]
            and a
            ret z
            ld a, [ap_on]                   ; (not under the airship's view)
            and a
            ret nz
            ldh a, [frame]                  ; (a new half step whenever frame / 8 changes:
            rrca                            ;   a loop that misses the exact frame still
            rrca                            ;   keeps the pace)
            rrca
            and 31
            ld hl, wa_ph
            cp [hl]
            jr z, .go
            ld [hl], a
            xor a
            ld [wa_i], a
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
; for corner q at $4010 + 16 e + q (DMG + 4), its frame at $4100 + $1000 e (DMG + $800) +
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
            add a, e                        ; (DMG: + 8, E = 4 twice)
            add a, e
            ld e, a
            ld a, b
            swap a                          ; ($10 a entry)
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
