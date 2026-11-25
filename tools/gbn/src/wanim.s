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
WTOWN_BANK = 109           ; the towns' water tile (build.py town_water)

section bank 0, $3F94
; every field frame. The water keeps its own step count (wa_t: only while it shows), so a menu,
; a battle or a load holds it where it was; after a map load (wa_ok 0: its tiles back at their
; first picture) every tile is drawn at the current step at once (wa_full)
wa_tick:    ld a, [ap_on]                   ; (not under the airship's view)
            and a
            ret nz
            ldh a, [rLCDC]
            bit 7, a
            ret z
            ldh a, [maptype]
            and a
            jp z, wa_town                   ; (towns: their water tile)
            call wa_step
            ld hl, wa_ph
            cp [hl]
            jr z, .same
            ld [hl], a
            xor a
            ld [wa_i], a
            ld [wa_full], a
.same:      jp wa_ow

section bank 0, $13CB
wa_ow:      ld a, [wa_ok]
            and a
            jr nz, .go
            inc a
            ld [wa_ok], a
            ld [wa_full], a
            xor a
            ld [wa_i], a
.go:        ld a, [wa_i]
            cp 8
            ret nc
            ldh a, [is_cgb]
            and a
            ld a, WANIM_BANK
            jr nz, .b
            ld a, WANIM_DMG
.b:         call sbank
            jp wa_run
; A = this frame's step (0-63, a new one every 4 frames of shown water)
wa_step:    ld hl, wa_t
            inc [hl]
            ld a, [hl]
            rrca
            rrca
            and 63
            ret

section bank 0, $2F52
; towns (tileset 0: maps 0-7), outside the rooms: their one water tile ($0F) moves as the sea,
; in two bands of 4 lines (build.py town_water); a step's picture goes to VRAM in the V-Blank
wa_town:    ld a, [cur_map]
            cp 8
            ret nc
            ld a, [inroom]
            and a
            ret nz
            call wa_step
            ld b, a
            ld hl, wa_ph
            ld a, [wa_ok]
            and a
            jr z, .new
            ld a, b
            cp [hl]
            ret z
.new:       ldh a, [rLY]
            sub 144
            cp 8
            ret nc
            ld [hl], b
            ld a, 1
            ld [wa_ok], a
            jp wt_cp

section bank 0, $31CE
; the town water tile's picture for step wa_ph (entry: the town, or 8 on the Color): its VRAM
; address at $4400 + 2 entry, the pictures at $4800 + $400 entry + 16 step
wt_cp:      ld a, WTOWN_BANK
            call sbank
            ldh a, [is_cgb]
            and a
            ld a, 8
            jr nz, .t
            ld a, [cur_map]
.t:         ld c, a
            add a, a
            ld l, a
            ld h, $44
            ld e, [hl]
            inc l
            ld d, [hl]
            ld a, c
            add a, a
            add a, a
            add a, $48
            ld h, a
            ld a, [wa_ph]
            swap a
            ld l, a
            and $0F
            add a, h
            ld h, a
            ld a, l
            and $F0
            ld l, a
            ld bc, 16
            jp memcpy

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

section bank 0, $1459
; C set if slot C changes at this step (its mask at $4080 + step, bank mapped)
wa_msk:     ld a, [wa_full]                 ; (after a load: every slot)
            and a
            scf
            ret nz
            ld a, [wa_ph]
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

section wram, $C6E8                         ; (after the battle's ailment bubbles)
wa_t:       ds 1                            ; the water's own frame count
wa_ok:      ds 1                            ; 0 after a map load: the tiles at their first picture
wa_full:    ds 1                            ; a full redraw at this step
