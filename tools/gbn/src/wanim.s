; FF1 native engine: the animated sea and rivers (owner's list, 2026-11-24; FF1 has none). The
; build (build.py water_anim) finds the overworld's commonest sea and river metatiles whose tiles
; are only used where the shifted picture stays right, and makes 64 steps of each 16 x 16
; picture: as Final Fantasy Legend III's water (owner, 2026-11-24), made finer (four bands of 4
; lines / columns, each a pixel per 16 frames, in turn 4 frames apart; sea sideways, river
; downwards). Every 4 frames a new step; the tiles that change at it (the build's mask) go to
; VRAM right after the frame wait, while the V-Blank lasts (the rest the next frame). The
; Color's frames in WANIM_BANK, the DMG's in WANIM_DMG (the same layout, header copied).
WANIM_BANK = 106
WANIM_DMG  = 108

section bank 0, $3F94
wa_tick:    ldh a, [maptype]
            and a
            ret z
            ld a, [ap_on]                   ; (not under the airship's view)
            and a
            ret nz
            ldh a, [frame]                  ; (a new step whenever frame / 4 changes)
            rrca
            rrca
            and 63
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
            ldh a, [is_cgb]
            and a
            ld a, WANIM_BANK
            jr nz, .b
            ld a, WANIM_DMG
.b:         call sbank
            jp wa_run

section bank 0, $2591
; the next changed tiles of this step while the V-Blank lasts (the bank mapped): entry e's tile
; for corner q at $4010 + 16 e + q, its frame at $4100 + $1000 e + 64 step + 16 q;
; the step's mask at $4080 + step (bit 4 e + q)
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
            call wa_msk                     ; does the slot change at this step?
            jr c, .go
            ld hl, wa_i
            inc [hl]
            jr wa_run
.go:        ld a, b                         ; D = the tile (the bank's own entry)
            swap a
            add a, $10
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
            ld e, a
            ld a, b
            swap a
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

section bank 0, $17E0
; C set if slot C changes at this step (its mask at $4080 + step, bank mapped)
wa_msk:     ld a, [wa_ph]
            add a, $80
            ld l, a
            ld h, $40
            ld e, [hl]
            ld a, c
            inc a
.sh:        rrc e
            dec a
            jr nz, .sh
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
