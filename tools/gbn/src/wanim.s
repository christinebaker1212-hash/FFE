; FF1 native engine: the animated sea and rivers (owner's list, 2026-11-24; FF1 has none). The
; build (build.py water_anim) finds the overworld's commonest sea and river metatiles whose tiles
; are only used where the shifted picture stays right, and makes 64 steps of each 16 x 16
; picture: as Final Fantasy Legend III's water (owner, 2026-11-24), made finer (four bands of 4
; lines / columns, each a pixel per 16 frames, in turn 4 frames apart; sea sideways, river
; downwards). Every 4 frames a new step; the tiles that change at it (the build's lists) go to
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
            ld a, [wa_i]                    ; (the last step's tiles not all drawn yet: every
            sub 8                           ;   tile at this one, else only those it changes)
            ld [wa_full], a
            xor a
            ld [wa_i], a
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
            jp wt_cpx

section bank 0, $3BD9
; load_map, once the map's tiles are in VRAM (LCD off or a masked load): the water drawn at
; the step it had reached, so a reload after a menu or a battle shows no first picture
wa_drw:     ld a, F3_BANK
            ld hl, wa_load
            call bank_call
            jp party_spr

section bank 99, $7E00
; (bank F3_BANK) every water tile of the new map at step wa_t / 4: the towns' tile (wt_cp), or
; the overworld's slots (the water bank's header and frames read through far_copy)
wa_load:    xor a                           ; (a map's load: the reflection's tiles made
            ld [rf_pend], a                 ;   again, none taken over: refl.s)
            ld [rf_acls], a
            ld [rf_upi], a
            dec a                           ; (its kept source tiles: none)
            ld [RF_TC], a
            ld [RF_TC + 2], a
            ld [RF_TC + 4], a
            ld [RF_TC + 6], a
            ldh a, [maptype]                ; (the masked tiles' place: build.py RF_TBT)
            and a
            ld a, 8
            jr nz, .tb
            ld a, [cur_map]
            cp 8
            jr c, .tb
            ld a, 9
.tb:        ld e, a
            ld d, 0
            ld hl, RF_TBT
            add hl, de
            ld a, [hl]
            ld [rf_tb], a
            ld a, [wa_t]
            rrca
            rrca
            and 63
            ld [wa_ph], a
            ld a, 1
            ld [wa_ok], a
            ld a, 8                         ; (wa_tick: this step drawn, every tile)
            ld [wa_i], a
            xor a
            ld [wa_full], a
            ld a, [ap_on]
            and a
            ret nz
            ldh a, [maptype]
            and a
            jr nz, .ow
            ld a, [cur_map]                 ; towns (maps 0-7)
            cp 8
            ret nc
            ld hl, wt_cp                    ; (bank 0 code; bank_call maps this bank back)
            jp bank_call
.ow:        ld c, 0                         ; C = slot (entry C / 4, corner C & 3)
.sl:        ld a, c
            srl a
            srl a
            ld b, a                         ; B = entry
            ld hl, $4000                    ; (the entry count)
            call wa_rd
            dec a
            cp b
            ret c
            ld a, b                         ; D = the slot's tile ($4010 + 16 entry + corner)
            swap a
            add a, $10
            ld l, a
            ld a, c
            and 3
            add a, l
            ld l, a
            ld h, $40
            call wa_rd
            ld d, a                         ; DE = its VRAM ($8800 mode)
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
            ld a, [wa_ph]                   ; HL = $4100 + $1000 entry + 64 step + 16 corner
            ld l, a
            srl a
            srl a
            ld h, a
            ld a, b
            swap a
            add a, h
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
            push bc
            call wa_bk
            ld bc, 16
            call far_copy
            pop bc
            inc c
            ld a, c
            cp 8
            jr c, .sl
            ret
; A = the byte at HL in the water bank (keeps BC)
wa_rd:      push bc
            call wa_bk
            ld de, wa_tmp
            ld bc, 1
            call far_copy
            pop bc
            ld a, [wa_tmp]
            ret
wa_bk:      ldh a, [is_cgb]
            and a
            ld a, WANIM_BANK
            ret nz
            ld a, WANIM_DMG
            ret

section bank 0, $2591
; this step's copies while the V-Blank lasts (the water bank mapped; build.py water_anim): the
; list at $6200 + 16 step (the tiles it changes) or, for a redraw (wa_full), $6600 + 32 step
; (every tile); each a count, then (VRAM, frame) address pairs. wa_i = the next copy; a copy
; (~1.3 lines on the plain Game Boy) starts only at LY 144-151, right after the test, so it ends
; by line 153 (the DMG's V-Blank handler leaves the water lines 148-153; the old test, made
; before the slot's mask and addresses, let a copy start at 153 and run into line 0's mode 3)
wa_run:     ld a, [wa_ph]                   ; HL = 16 step
            swap a
            ld l, a
            and $0F
            ld h, a
            ld a, l
            and $F0
            ld l, a
            ld a, [wa_full]
            and a
            jr z, .ch
            add hl, hl                      ; (a redraw: $6600 + 32 step)
            ld a, h
            add a, $66 - $62
            ld h, a
.ch:        ld a, h
            add a, $62
            ld h, a
            ld a, [wa_i]
            cp [hl]
            jr nc, .done
            add a, a                        ; HL = the copy's entry (inside the step's list)
            add a, a
            inc a
            add a, l
            ld l, a
            ldh a, [rLY]
            sub 144
            cp 8
            ret nc
            ld e, [hl]                      ; DE = the tile in VRAM (16-aligned)
            inc l
            ld d, [hl]
            inc l
            ld a, [hl+]                     ; HL = its frame
            ld h, [hl]
            ld l, a
            ld b, 8
.cp:        ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            dec b
            jr nz, .cp
            ld hl, wa_i
            inc [hl]
            jr wa_run
.done:      ld a, 8
            ld [wa_i], a
            ret

section wram, $C992                         ; (between the SGB variables and its queue)
wa_i:       ds 1
wa_ph:      ds 1

section wram, $CFB8                         ; (after ly_tab; fixed RAM no screen shares: the map's
                                            ;   queue $C100-$C8FF ran over these at $C6E8)
wa_t:       ds 1                            ; the water's own frame count
wa_ok:      ds 1                            ; 0 after a map load: the tiles at their first picture
wa_full:    ds 1                            ; a full redraw at this step
wa_tmp:     ds 1                            ; (wa_load: a byte of the water bank)

section bank 0, $2D24                       ; (free space)
; ---- the world map's waterfall (owner's audit, 2026-11-25, W2): its two tiles a pixel lower each
; water step (8 pictures; build.py town_water, bank WTOWN_BANK $6C00), copied two frames after
; the step changed (the sea's and rivers' copies are done by then), early in the V-Blank
wf_tick:    ldh a, [maptype]
            and a
            ret z
            ld a, [ap_on]
            and a
            ret nz
            ldh a, [rLCDC]
            bit 7, a
            ret z
            ld a, [wa_t]
            and 3
            cp 2
            ret nz
            ldh a, [rLY]                    ; (two tiles, ~2.6 lines on the plain Game Boy: a
            sub 144                         ;   start by line 150 ends by 153)
            cp 7
            ret nc
            ld a, WTOWN_BANK
            call sbank
            ldh a, [is_cgb]
            and a
            ld hl, $6C00
            ld bc, $6C10
            jr nz, .s
            ld hl, $6C04
            ld bc, $6D10
.s:         ld a, [wa_t]                    ; BC += 32 x ((wa_t / 4) & 7)
            rrca
            rrca
            and 7
            swap a
            add a, a
            add a, c
            ld c, a
            ld a, b
            adc a, 0
            ld b, a
            call .t
.t:         ld e, [hl]                      ; a tile: [HL] its VRAM, BC its picture
            inc hl                          ;   (eight bytes a pass, unrolled: both tiles in
            ld d, [hl]                      ;   ~1.6 lines of the plain Game Boy)
            inc hl
            push hl
            ld h, b
            ld l, c
            ld c, 2
.c:
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            dec c
            jr nz, .c
            ld b, h
            ld c, l
            pop hl
            ret

section bank 0, $3E30                       ; (free space)
; wt_cp's end: the water tile, then the canal's shadowed tiles (wt_cp2)
wt_cpx:     call memcpy
            ld a, F3_BANK
            ld hl, wt_cp2
            jp bank_call

section bank 99, $4AD0                      ; (after WT2_HDR)
; the towns' canal in shadow (owner, 2026-11-25): its shadowed water tile and the corner with
; the shadow's edge, at the water's step (build.py town_water2: WT2_HDR, pictures in WT2_BANK);
; with the LCD on only while the V-Blank lasts (a tile left for the next step otherwise)
WT2_BANK   = 112
wt_cp2:     ldh a, [is_cgb]
            and a
            ld a, 8
            jr nz, .t
            ld a, [cur_map]
.t:         add a, a
            add a, a
            add a, a
            ld e, a
            ld d, 0
            ld hl, WT2_HDR
            add hl, de
            call .one
.one:       ld e, [hl]                      ; DE = the tile's VRAM, B = its pictures' high byte
            inc hl
            ld d, [hl]
            inc hl
            ld b, [hl]
            inc hl
            inc hl
            ld a, d
            or e
            ret z
            push hl
            di
            ldh a, [rLCDC]
            bit 7, a
            jr z, .go
            ldh a, [rLY]
            sub 144
            cp 7
            jr nc, .x
.go:        ld a, [wa_ph]                   ; HL = pictures + 16 step
            swap a
            ld l, a
            and $0F
            add a, b
            ld h, a
            ld a, l
            and $F0
            ld l, a
            ld bc, 16
            ld a, WT2_BANK
            call far_copy
.x:         ei
            pop hl
            ret
