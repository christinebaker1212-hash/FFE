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
            jp wa_ow

section bank 0, $13CB
wa_ow:      ld a, [wa_ok]                   ; (after a map's load: wa_load drew the step)
            and a
            ret z
            call wa_step
            ld [WA_SEA + 3], a              ; the targets: the sea's step, the river's two
            add a, 2                        ;   steps on (((s + 2) / 4) & 15: other frames
            rrca                            ;   than the sea's band)
            rrca
            and 15
            ld [WA_RIV + 3], a
            ldh a, [is_cgb]                 ; (the plain Game Boy: its copies in the frame's
            and a                           ;   idle H-Blanks, wa_late; its V-Blank is the
            ret z                           ;   waterfall's and the map's)
            ld a, WANIM_BANK
            call sbank
            jp wa_run
; A = this frame's step (0-63, a new one every 4 frames of shown water)
wa_step:    ld hl, wa_t
            inc [hl]
            ld a, [hl]
            rrca
            rrca
            and 63
            ret

section bank 0, $3A2B                       ; (free space; was $2F52, grown)
; towns (tileset 0: maps 0-7), outside the rooms: their one water tile ($0F) moves as the sea,
; in two bands of 4 lines (build.py town_water); a step's picture goes to VRAM in the V-Blank
wa_town:    ld a, [cur_map]
            cp 8
            jr nc, .no
            ld a, [inroom]
            and a
            jr nz, .no
            ld a, [wt_req]                  ; (one the V-Blank did not take: wanted again,
            and a                           ;   after this field frame)
            jr z, .s
            ld a, 1
            ld [wt_req], a
.s:         call wa_step
            ld b, a
            ld hl, wa_ph
            ld a, [wa_ok]
            and a
            jr z, .new
            ld a, b
            cp [hl]
            ret z
.new:       ld [hl], b                      ; (the copy in the V-Blank after this field frame:
            ld a, 1                         ;   wt_vbl. Here, right after the frame wait, the
            ld [wa_ok], a                   ;   plain Game Boy's walking frames came at line
            ld [wt_req], a                  ;   149-153, too late: the water stood still while
            ret                             ;   the party walked; owner, 2026-11-26)
.no:        xor a
            ld [wt_req], a
            ret

section bank 0, $3195                       ; (free space)
; V-Blank (main.s vblank): the map's first metatiles
qf_wt:      ld c, 3
            jp q_flush
; V-Blank, right after the OAM (rf_dma; the plain Game Boy's reflection tiles and map rows come
; after it, each with its own time check): the town water's step (wa_town) once a field frame
; has ended (wt_end: 1 -> 2; a menu or a load in between keeps it from them)
wt_vbl:     ld a, [wt_req]
            cp 2
            ret nz
            ldh a, [maptype]
            and a
            ret nz
            ldh a, [rLY]                    ; (up to line 149: 16 bytes, some 1.5 lines on the
            sub 144                         ;   plain Game Boy; the canal's tiles check their
            cp 6                            ;   own time)
            ret nc
            xor a
            ld [wt_req], a
            jp wt_cp
; the main loop's end (ap_tl)
wt_end:     ld hl, wt_req
            sla [hl]
            jp main

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
wa_load:    call tl_setf                    ; (tall or not: tall.s)
            ld hl, hw_src                   ; (the water copier's helpers into HRAM)
            ld c, low(HW_TIME)
            ld b, hw_end - hw_src
.hw:        ld a, [hl+]
            ldh [c], a
            inc c
            dec b
            jr nz, .hw
            xor a                           ; (a map's load: the reflection's tiles made
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
            ldh a, [rLCDC]                  ; (the LCD on, a masked load: the V-Blank copies
            bit 7, a                        ;   it, wt_vbl; at once it was written in line
            jr z, .twn                      ;   44's drawing: strict checker, 2026-11-26)
            ld a, 2
            ld [wt_req], a
            ret
.twn:       ld hl, wt_cp                    ; (bank 0 code; bank_call maps this bank back)
            jp bank_call
.ow:        ld hl, $4010                    ; the sea from its whole tiles at step 0 (the
                                            ;   list at $4010), the river idle at 0; then
            call wa_rd                      ;   every step up to now, without the V-Blank's
            ld [WA_SEA], a                  ;   limit (LCD off or a masked load)
            ld hl, $4011
            call wa_rd
            ld [WA_SEA + 1], a
            xor a
            ld [WA_SEA + 2], a
            ld [WA_RIV], a
            ld [WA_RIV + 1], a
            ld [WA_RIV + 2], a
            ld a, 63
            ld [WA_SEA + 4], a
            ld a, $80
            ld [WA_SEA + 5], a
            ld a, 15
            ld [WA_RIV + 4], a
            ld a, $40
            ld [WA_RIV + 5], a
            ld a, [wa_t]
            rrca
            rrca
            and 63
            ld [WA_SEA + 3], a
            add a, 2
            rrca
            rrca
            and 15
            ld [WA_RIV + 3], a
            ld a, 1
            ldh [wa_nl], a
            call wa_bk
            ld hl, wa_run                   ; (bank 0 code, the water bank mapped)
            call bank_call
            xor a
            ldh [wa_nl], a
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
wa_run:     ld hl, WA_SEA
            call wa_an
            ret c
            ld hl, WA_RIV
; HL = an animator (list pointer, step, target, mask, index's low byte): its lists applied in turn
; up to its target, a record at a time while the V-Blank lasts (wa_nl: no limit, a load). C: out
; of time. Records: VRAM address (bit 0: 16 bytes, else 8), the bytes; a zero word ends a list
wa_an:      push hl
.n:         pop hl
            push hl
            ld a, [hl+]
            ld e, a
            ld a, [hl+]
            ld d, a
            or e
            jr nz, .rec
            ld a, [hl+]                     ; (no list running: the next step's, if behind)
            cp [hl]
            jr z, .x
            inc hl
            inc a
            and [hl]
            ld c, a
            inc hl
            add a, a
            add a, [hl]
            ld l, a
            ld h, $40
            ld e, [hl]
            inc hl
            ld d, [hl]
            pop hl
            push hl
            inc hl
            inc hl
            ld [hl], c
.rec:       call HW_TIME                    ; (the time left: HRAM, hw_src)
            jr c, .late
            ld a, [de]
            ld l, a
            inc de
            ld a, [de]
            ld h, a
            inc de
            and a
            jr z, .end
            ld b, 8
            bit 0, l
            jr z, .c
            res 0, l
            ld b, 16
.c:         call HW_CPY                     ; (B bytes DE -> HL: HRAM, hw_src)
            pop hl
            push hl
            ld [hl], e
            inc hl
            ld [hl], d
            jr .n
.end:       pop hl
            push hl
            xor a
            ld [hl+], a
            ld [hl], a
            jr .n
.late:      pop hl
            scf
            ret
.x:         pop hl
            and a
            ret

section wram, $C992                         ; (between the SGB variables and its queue)
wa_i:       ds 1
wa_ph:      ds 1                            ; (the towns' water tile: its step)
section wram, $CCF0
WA_SEA:     ds 6                            ; wa_an's animators: list pointer, step, target,
WA_RIV:     ds 6                            ;   mask, index (low byte; page $40)
section hram, $FF9C
wa_nl:      ds 1                            ; 1: no V-Blank limit (a load)

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
            push hl                         ; (no di / ei: run from the V-Blank handler, wt_vbl,
            ldh a, [rLCDC]                  ;   or a load with the LCD off)
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
.x:         pop hl
            ret

; ---- wa_an's helpers, run from HRAM (copied there by wa_load; position independent: jr only)
HW_TIME    = $FFA0
HW_CPY     = HW_TIME + (hw_cpy - hw_src)
section bank 99, $7A23                      ; (free space)
; C when the time is out: wa_nl 0 the V-Blank (lines 144-151), 1 none (a load), 2 H-Blanks up to
; line 127 (a record's last bytes 8 lines on) (the plain Game Boy's idle lines: wa_late)
hw_src:     ldh a, [wa_nl]
            cp 1
            jr z, .ok
            jr c, .vb
            ldh a, [rLY]
            cp 128
            ccf
            ret
.vb:        ldh a, [rLY]
            sub 144
            cp 8
            ccf
            ret
.ok:        and a
            ret
; B bytes DE -> HL (VRAM); in H-Blanks (wa_nl 2): 2 at each H-Blank's start, interrupts off
hw_cpy:     ldh a, [wa_nl]
            cp 2
            jr z, .hb
.c:         ld a, [de]
            ld [hl+], a
            inc de
            dec b
            jr nz, .c
            ret
.hb:        di
.w3:        ldh a, [rSTAT]
            and 3
            cp 1                            ; (the V-Blank reached: the rest at once)
            jr z, .vb
            cp 3
            jr nz, .w3
.w0:        ldh a, [rSTAT]
            and 3
            jr nz, .w0
            ld a, [de]
            ld [hl+], a
            inc de
            ld a, [de]
            ld [hl+], a
            inc de
            ei
            dec b
            dec b
            jr nz, .hb
            ret
.vb:        ei
            jr .c
hw_end:
