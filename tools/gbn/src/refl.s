; FF1 native engine: the party's / vehicle's reflection on water (owner's list, 2026-11-24): on
; the overworld, on foot, by ship or canoe, when the tile below the party is sea or river (FF1's
; tile properties: blocked on foot, open to the ship or the canoe; while stepping, below both
; tiles of the step), a mirrored copy of its four sprites sits on that tile, its far row
; wavering a pixel. The Color: darker copies of OBJ palettes 0-3 in 4-7 (made when a map
; loads); DMG / SGB: OBP1, a dimmer mapping. OAM 36-39 (unused on the overworld).
REFL_OAM   = oam_buf + 144

section bank 0, $16A0
refl_tick:  ld a, REFL_BANK                 ; (the reflection's frame: refl_t9)
            ld hl, refl_t9
            jp bank_call
; refl_wat from another bank: the caller's bank back after map_at (C kept: sbank keeps flags)
rw0:        ldh a, [rombank]
            ld [rw_bk], a
            call refl_wat
            ld a, [rw_bk]
            jp sbank
; map_at from another bank: A = the metatile at (E, D), the caller's bank back
rw1:        ldh a, [rombank]
            ld [rw_bk], a
            call map_at
            ld [rw_mt], a
            ld a, [rw_bk]
            call sbank
            ld a, [rw_mt]
            ret

section bank 0, $3584
refl_mir:   ld hl, oam_buf                  ; mirrored about the party's foot (its rows are
            ld de, REFL_OAM                 ;   fixed on the screen, y $50 / $58: foot $60)
            ld b, 4
.e:         ld a, [hl+]
            and a
            jr nz, .y
            ld a, $58                       ; (a row hidden in a forest: the legs are there)
.y:         cpl
            inc a
            add a, $B8
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
            ld c, a
            ldh a, [is_cgb]
            and a
            ld a, c
            jr z, .dm
            and $FB                         ; (palette 0-3 -> 4-7)
            or 4
            jr .wa
.dm:        or $10                          ; (OBP1)
.wa:        ld [de], a
            inc de
            dec b
            jr nz, .e
            ldh a, [frame]                  ; the far row (y $68) wavers
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
            cp $68
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
; the Color: OBJ palettes 4-7 = 0-3 faded into the sea (owner, 2026-11-24: more like a game
; reflection, more faded): each channel 3/8 the sprite's, 5/8 the sea's main colour (the build's,
; WANIM_BANK $4008, through the LCD colour mode); LCD off or V-Blank: palette RAM read
refl_pal:   ldh a, [is_cgb]
            and a
            ret z
            ld a, WANIM_BANK                ; the water: DE = its colour, corrected
            ld [fc_bank], a
            ld hl, $4008
            call far_byte
            ld e, a
            ld hl, $4009
            call far_byte
            ld d, a
            call cc_fix
            ld a, e
            and 31
            ld [refl_w], a
            call .g
            ld [refl_w + 1], a
            ld a, d
            rrca
            rrca
            and 31
            ld [refl_w + 2], a
            ld c, 0                         ; byte index 0, 2, .. 30
.l:         ld a, c
            call ocps_w
            call ocpd_r
            ld e, a
            ld a, c
            inc a
            call ocps_w
            call ocpd_r
            ld d, a                         ; DE = colour (b 14-10, g 9-5, r 4-0)
            ld a, e                         ; r
            and 31
            ld hl, refl_w
            call .bl
            ld [refl_r], a
            call .g                         ; g
            ld hl, refl_w + 1
            call .bl
            ld [refl_g], a
            ld a, d                         ; b
            rrca
            rrca
            and 31
            ld hl, refl_w + 2
            call .bl
            ld [refl_b], a
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
            call ocps_w
            ld a, e
            call ocpd_w
            ld a, c
            add a, 33
            call ocps_w
            ld a, d
            call ocpd_w
            inc c
            inc c
            ld a, c
            cp 32
            jr c, .l
            ret
.g:         ld a, e                         ; A = green of DE
            and $E0
            ld b, a
            ld a, d
            and 3
            or b
            rlca
            rlca
            rlca
            and 31
            ret
.bl:        push de                         ; A = (k A + (8 - k) [HL]) / 8, k = refl_k (the
            ld e, a                         ;   fade: 3 full, 1 nearly the sea; 0 counts as 3)
            call .kk
            ld d, a
            xor a
.m1:        add a, e
            dec d
            jr nz, .m1
            ld b, a
            call .kk
            ld d, a
            ld a, 8
            sub d
            ld d, a
            ld a, b
.m2:        add a, [hl]
            dec d
            jr nz, .m2
            srl a
            srl a
            srl a
            pop de
            ret
.kk:        ld a, [refl_k]
            and a
            ret nz
            ld a, 3
            ret

section wram, $C7F8
refl_r:     ds 1
refl_g:     ds 1
refl_b:     ds 1
refl_w:     ds 3

section wram, $D9F6
refl_lv:    ds 1                            ; the reflection's fade, 0 (none) .. 12 (full)
refl_k:     ds 1                            ; the strength its colours were made for (1-3)
rw_bk:      ds 1
rw_n:       ds 1
rw_mt:      ds 1

REFL_BANK  = 111
section bank 111, $4000
; ---- the reflection's frame (owner, 2026-11-25: fading in and out, and care at the sides
; where one tile has water and the other not). It fades in as the party steps onto water and
; out as it steps off (the tile below where the step ends decides; 12 frames, three
; strengths: the Color blends its colours into the sea's, the plain Game Boy / SGB lighten
; OBP1), and on a sideways step each half of it is shown only over water: it slips into the
; shore column by column while it fades.
refl_t9:    xor a                           ; (hidden first)
            ld [REFL_OAM], a
            ld [REFL_OAM + 4], a
            ld [REFL_OAM + 8], a
            ld [REFL_OAM + 12], a
            ldh a, [maptype]
            and a
            jr z, .off
            ld a, [vehicle]
            cp V_AIR
            jr z, .off
            call refl_mir                   ; the mirrored party, then only its parts over
            call refl_clip                  ;   water (C: some part shows)
            ld hl, refl_lv                  ; the strength rises while some of it shows, and
            ld a, [hl]                      ;   falls when none does
            jr nc, .dn
            cp 12
            jr nc, .k
            inc a
            jr .s
.dn:        and a
            jr z, .k
            dec a
.s:         ld [hl], a
.k:         and a
            jr z, .hide
            call refl_fade
            ld a, [refl_k]                  ; the faintest: every other frame (see-through)
            cp 2
            ret nc
            ldh a, [frame]
            rrca
            ret nc
.hide:      xor a
            ld [REFL_OAM], a
            ld [REFL_OAM + 4], a
            ld [REFL_OAM + 8], a
            ld [REFL_OAM + 12], a
            ret
.off:       xor a
            ld [refl_lv], a
            ret
; the strength for the fade level (1-4 -> 1, 5-8 -> 2, 9-12 -> 3), its colours when it changed
refl_fade:  ld a, [refl_lv]
            add a, 3
            srl a
            srl a
            ld hl, refl_k
            cp [hl]
            ret z
            ld [hl], a
            ldh a, [is_cgb]
            and a
            jr z, .dm
            ld a, F3_BANK                   ; (the Color: its colours blended again)
            ld hl, refl_pal
            jp bank_call
.dm:        ld a, [refl_k]                  ; DMG / SGB: OBP1 lighter (colour 0 unused)
            ld hl, .ob - 1
            add a, l
            ld l, a
            ld a, h
            adc a, 0
            ld h, a
            ld a, [hl]
            ldh [rOBP1], a
            ret
.ob:        db %01000000, %01010100, %10010100
; each sprite only where the 8 x 8 quarter under its middle is drawn with open water (the
; build's REFL_WTAB, from the map's own tiles): standing or stepping in any direction it slips
; into the shore exactly where the water ends; C: some part shows
refl_clip:  xor a
            ld [rw_n], a                    ; (parts shown)
            ld hl, REFL_OAM
            ld b, 4
.e:         push bc
            push hl
            ld a, [hl+]                     ; y: the middle from the party's top (OAM y - 16
            and a                           ;   - 64 + 4), the step's pixels added
            jr z, .nx
            cp 160                          ; (off the screen: none)
            jr nc, .land
            sub 76
            ld b, a
            ld a, [mdy]
            call .st
            ld d, a                         ; D = pixels down from the party's tile
            ld a, [hl]                      ; x: the same from its left (OAM x - 8 - 72 + 4)
            sub 76
            ld b, a
            ld a, [mdx]
            call .st
            ld e, a                         ; E = pixels across
            ld c, 1                         ; C = the quarter's bit (UL 1, UR 2, DL 4, DR 8)
            bit 3, e
            jr z, .q1
            sla c
.q1:        bit 3, d
            jr z, .q2
            sla c
            sla c
.q2:        ld a, e                         ; the metatile: the party's + pixels / 16
            sra a
            sra a
            sra a
            sra a
            ld b, a
            ld a, [px]
            add a, b
            ld e, a
            ld a, d
            sra a
            sra a
            sra a
            sra a
            ld b, a
            ld a, [py]
            add a, b
            ld d, a
            push bc
            call rw1
            pop bc
            and $7F
            add a, low(REFL_WTAB)
            ld l, a
            ld a, high(REFL_WTAB)
            adc a, 0
            ld h, a
            ld a, [hl]
            and c
            jr nz, .nx
.land:      pop hl
            push hl
            xor a
            ld [hl], a                      ; (over land: hidden)
.nx:        pop hl
            ld a, [hl]
            and a
            jr z, .n2
            ld a, 1
            ld [rw_n], a
.n2:        ld de, 4
            add hl, de
            pop bc
            dec b
            jr nz, .e
            ld a, [rw_n]                    ; C: some part shows
            rrca
            ret
; A = direction (-1 / 0 / 1), B = offset: B + direction x the step's pixels (signed)
.st:        ld c, a
            ld a, [moving]
            and a
            ld a, b
            ret z
            ld a, [mcount]
            bit 7, c
            jr nz, .neg
            dec c
            ld a, b
            ret nz                          ; (direction 0)
            ld a, [mcount]
            add a, b
            ret
.neg:       ld c, a
            ld a, b
            sub c
            ret
