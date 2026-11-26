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
            ld de, RF_OAM                   ;   fixed on the screen, y $50 / $58: foot $60)
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
            ld hl, RF_OAM
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
            ldh a, [maptype]                ; (a town: its water's colour, build.py RF_TWC)
            and a
            jr nz, .sea
            ld a, [RF_TWC]
            ld e, a
            ld a, [RF_TWC + 1]
            ld d, a
            jr .cc
.sea:       ld a, WANIM_BANK                ; the water: DE = its colour, corrected
            ld [fc_bank], a
            ld hl, $4008
            call far_byte
            ld e, a
            ld hl, $4009
            call far_byte
            ld d, a
.cc:        call cc_fix
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
refl_t9:    ldh a, [maptype]                ; (built in RF_OAM, then put in the OAM copy in
            and a                           ;   one go: a V-Blank during the work shows the
            jr nz, .ow                      ;   last frame's, never a half-made one)
            ld a, [cur_map]                 ; (standard maps: the towns, 0-7; owner,
            cp 8                            ;   2026-11-25)
            jr nc, .off
.ow:        ld a, [vehicle]
            cp V_AIR
            jr z, .off
            call refl_mir                   ; the mirrored party, then only its parts over
            ld hl, RF_OAM                   ;   water (C: some part shows); the sprites as
            ld de, RF_RAW                   ;   mirrored kept for rf_up9's OAM patch
            ld b, 16
.raw:       ld a, [hl+]
            ld [de], a
            inc e
            dec b
            jr nz, .raw
            xor a
            ld [rf_hid], a
            call refl_msk
            call c, rf_corner               ; (on a corner tile mostly land: fading out)
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
.k:         and a                           ; (rf_want: a ninth map object yields OAM 36-39
            ld b, 0                         ;   to it from the next frame: obj_draw; owner's
            jr z, .kw                       ;   list, 2026-11-26)
            inc b
.kw:        push af
            ld a, b
            ld [rf_want], a
            pop af
            jr z, .hide
            call refl_fade
            ld a, [refl_k]                  ; the faintest: every other frame (see-through)
            cp 2
            jr nc, .put
            ldh a, [frame]
            rrca
            jr nc, .put
.hide:      ld a, 1                         ; (rf_up9: no patch while hidden)
            ld [rf_hid], a
            xor a
            ld [RF_OAM], a
            ld [RF_OAM + 4], a
            ld [RF_OAM + 8], a
            ld [RF_OAM + 12], a
.put:       ld a, [REFL_OAM]                ; (OAM 36-39 still a ninth object's this frame:
            and a                           ;   left to it, and no patch in the V-Blank)
            jr z, .pt
            ld a, 1
            ld [rf_hid], a
            ret
.pt:        ld hl, RF_OAM
            ld de, REFL_OAM
            ld b, 16
            di
.c:         ld a, [hl+]
            ld [de], a
            inc e
            dec b
            jr nz, .c
            ei
            ret
.off:       xor a                           ; (off: the OAM copy itself; RF_OAM is the
            ld [refl_lv], a                 ;   airship view's table while it shows)
            ld [rf_want], a
            ld [rf_pend], a
            ld [rf_acls], a
            ld [REFL_OAM], a
            ld [REFL_OAM + 4], a
            ld [REFL_OAM + 8], a
            ld [REFL_OAM + 12], a
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
; A = direction (-1 / 0 / 1), B = offset: B + direction x the step's pixels (signed), the
; step one frame on (rf_la: what the screen shows when the tiles made now are up)
refl_st:    ld c, a
            ld a, [moving]
            and a
            ld a, b
            ret z
            ld a, [rf_la]
            ld e, a
            ld a, [mcount]
            add a, e
            bit 7, c
            jr nz, .neg
            dec c
            ld a, b
            ret nz                          ; (direction 0)
            ld a, [mcount]
            add a, e
            add a, b
            ret
.neg:       ld c, a
            ld a, b
            sub c
            ret

; ---- the reflection cut to the water pixel by pixel (owner, 2026-11-25: on the coasts too,
; only over their water). The build's REFL_MASK gives each overworld metatile's water as a bit
; per pixel; each frame the four mirrored sprites get the water under them a frame on (the
; step's next pixel) row by row: all water: the sprite as it is; none: hidden; some: its tile
; masked into a free sprite tile. Those tiles go up in the next V-Blank (rf_up9) into the set
; not shown ($70-$73 / $74-$77), and only once all are up does the set and the sprites' kinds
; change, so a half-written tile never shows (the plain Game Boy may take two V-Blanks).
RF_OAM     = $DC70          ; the four sprites made (copied into REFL_OAM at the end)
RF_SIG     = $DC00          ; what the tiles were made from (23 bytes; the airship view's SCY
                            ;   table, free likewise)
RF_P       = $DC18          ; the four quarters' mask rows (2 x 2 pointers)
RF_QX      = $DC20
RF_QY      = $DC21
RF_UA      = $DC22
RF_UV      = $DC23
RF_TC      = $DCC0          ; the source tiles kept: 4 x (tile, class) keys, then 4 x 16 bytes
RF_TD      = $DD00          ;   (in one page: rf_srcd adds to the low byte; the battle's
                            ;   stage, free on the field)
RF_STG     = $DC80          ; the tiles made (4 x 16; the airship view's sky table, free while
                            ;   the reflection shows: it is off in the air)
RF_ROWS    = $DC40          ; (scratch: the airship view's DMG table, free likewise)
RF_SRC     = $DC48
RF_CK      = $DC58          ; metatile cache: 6 x (key, metatile)
RF_CN      = $DC64
RF_X       = $DC65
RF_Y       = $DC66
RF_I       = $DC67
RF_ANY     = $DC68
RF_SH      = $DC69
RF_T       = $DC6A
RF_YY      = $DC6D
rf_tb      = $CFBC          ; the masked tiles' first sprite tile on this map (0: none)
rf_pend    = $D9FC          ; 1: RF_STG / rf_scls wait for the V-Blank
rf_acls    = $D9FD          ; the kinds shown (2 bits a sprite: 0 hidden, 1 whole, 2 masked)
rf_scls    = $D9FE          ; the kinds made
rf_aset    = $D9FF          ; the tile set shown (0: $70, 1: $74); bit 7: upload going (sprite
                            ;   index in bits 0-2 of rf_upi)
rf_upi     = $DC6B
RF_RAW     = $DC24          ; the four sprites as mirrored, before the kinds (16 bytes)
rf_hid     = $DC34          ; 1: the reflection hidden this frame (its fade)
rf_st      = $DC35          ; 1: the tiles kept are of another pose (refl_msk)
RF_NEXT    = $DCD0          ; the four OAM entries once the tiles made are up (16 bytes)
rf_la      = $DC6C

refl_msk:   xor a
            ld [rf_st], a
            ld a, [rf_pend]                 ; (an upload half done: the tiles made stay)
            and a
            jr z, .mk
            ld a, [rf_upi]
            and a
            jr nz, .stale
.mk:        ldh a, [rLY]                    ; (the frame already late, line 44-143: the tiles
            cp 144                          ;   made stand a frame more, so no frame is lost;
            jr nc, .mk1                     ;   the plain Game Boy needs some 85 lines for
            cp 44                           ;   them, a step's end starts near line 80)
            jr nc, .stale
.mk1:       call rf_sig                     ; (nothing moved: the tiles made stand)
            jr z, .apply
            xor a
            ld [rf_pend], a                 ; (none taken by the V-Blank while being made)
            ld [rf_upi], a
            ld [RF_CN], a
            ld [rf_scls], a
            ld [RF_ANY], a
            xor a                           ; (the tiles show with this frame's sprites:
            ld [rf_la], a                   ;   rf_up9 patches the OAM; owner, 2026-11-26)
            xor a
.e:         ld [RF_I], a
            call rf_one
            ld a, [RF_I]
            inc a
            cp 4
            jr c, .e
            call rf_next
            ld a, 1
            ld [rf_pend], a
            jr .apply
.stale:     call rf_pose                    ; (kept, but the party's pose changed since: its cut
            jr z, .apply                    ;   parts hidden this frame, not shown in the old
            ld a, 1                         ;   pose; Onrac on the plain Game Boy runs late
            ld [rf_st], a                   ;   several frames in a row; owner's list,
            ld [rf_hid], a                  ;   2026-11-26; no patch in the V-Blank either)
.apply:     ld hl, RF_OAM                   ; the kinds shown now
            ld a, [rf_acls]
            ld c, a
            ld b, 0
.ap:        ld a, c
            and 3
            jr nz, .ap1
            ld [hl], a                      ; (hidden)
            jr .apn
.ap1:       cp 2
            jr nz, .apn
            ld a, [rf_st]                   ; (the pose changed since its tiles were cut: hidden)
            and a
            jr nz, .aph
            ld a, [rf_tb]                   ; (no tiles for it on this map: hidden)
            and a
            jr nz, .ap2
.aph:       xor a
            ld [hl], a
            jr .apn
.ap2:       inc l                           ; masked: its tile in the set shown
            inc l
            ld a, [rf_aset]
            and 1
            add a, a
            add a, a
            ld e, a
            ld a, [rf_tb]
            add a, e
            add a, b
            ld [hl-], a
            dec l
.apn:       ld a, l
            add a, 4
            ld l, a
            srl c
            srl c
            inc b
            ld a, b
            cp 4
            jr c, .ap
            ld a, [rf_scls]                 ; C: some part shows (of the ones made)
            and a
            ret z
            scf
            ret

; sprite RF_I: its rows' water, its kind into rf_scls, its masked tile into RF_STG
rf_one:     ld a, [RF_I]
            add a, a
            add a, a
            add a, low(RF_OAM)
            ld l, a
            ld h, high(RF_OAM)
            ld a, [hl+]
            and a
            ret z
            cp 160
            ret nc
            sub 80                          ; Y: its top from the party's tile, the step on
            ld b, a
            push hl
            ld a, [mdy]
            call refl_st
            ld [RF_Y], a
            pop hl
            ld a, [hl+]
            sub 80
            ld b, a
            push hl
            ld a, [mdx]
            call refl_st
            ld [RF_X], a
            pop hl
            ld a, [hl]
            ld [RF_T], a
            ld a, [RF_X]                    ; the 2 x 2 quarters under it: their mask rows
            and 7
            ld [RF_SH], a
            ld a, [RF_X]
            sra a
            sra a
            sra a
            ld [RF_QX], a
            ld a, [RF_Y]
            sra a
            sra a
            sra a
            ld [RF_QY], a
            ld de, RF_P
            ld b, 0
            ld a, $FE                       ; (RF_UA: the quarters' common whole value, or 1)
            ld [RF_UA], a
.p:         push bc
            push de
            ld a, [RF_QX]
            bit 0, b
            jr z, .p1
            inc a
.p1:        ld c, a
            ld a, [RF_QY]
            bit 1, b
            jr z, .p2
            inc a
.p2:        ld b, a
            call rf_qp
            ld b, a                         ; (all four alike and whole, or not)
            ld a, [RF_UA]
            cp $FE
            jr z, .pu
            cp b
            jr z, .pv
            ld b, 1
.pu:        ld a, b
            ld [RF_UA], a
.pv:        pop de
            ld a, l
            ld [de], a
            inc e
            ld a, h
            ld [de], a
            inc e
            pop bc
            inc b
            ld a, b
            cp 4
            jr c, .p
            ld a, [RF_UA]                   ; all four whole quarters alike: no rows to cut
            and a
            ret z                           ; (none water: hidden)
            inc a
            ld c, 1
            jr z, .k                        ; (all water: whole)
            ld a, [RF_Y]                    ; C = row in the quarter pair (0-15)
            and 7
            ld c, a
            ld b, $FF                       ; AND of the rows in B, OR in D, E = RF_ROWS slot
            ld d, 0
            ld e, low(RF_ROWS)
.r:         push bc
            push de
            ld hl, RF_P                     ; the upper or the lower pair
            ld a, c
            cp 8
            jr c, .up
            ld hl, RF_P + 4
            sub 8
.up:        ld e, a                         ; E = row in the quarter
            ld a, [hl+]
            ld c, a
            ld a, [hl+]
            ld b, a
            ld a, c
            add a, e
            ld c, a
            jr nc, .u1
            inc b
.u1:        ld a, [bc]                      ; the left quarter's bits
            ld d, a
            ld a, [RF_SH]
            and a
            jr z, .z
            ld a, [hl+]
            ld c, a
            ld b, [hl]
            ld a, c
            add a, e
            ld c, a
            jr nc, .u2
            inc b
.u2:        ld a, [bc]                      ; the right one's
            ld e, a
            ld a, [RF_SH]
            ld b, a
.s:         sla e                           ; (left, right) << sh: the window in D
            rl d
            dec b
            jr nz, .s
.z:         ld a, d                         ; A = the row's water bits
            pop de
            pop bc
            ld l, e
            ld h, high(RF_ROWS)
            ld [hl], a
            inc e
            ld l, a
            and b
            ld b, a
            ld a, l
            or d
            ld d, a
            inc c
            ld a, e
            cp low(RF_ROWS) + 8
            jr c, .r
            ld a, d
            and a
            ret z                           ; (no water: hidden)
            ld c, 1
            ld a, b
            inc a
            jr z, .k                        ; (all water: whole)
            call rf_half                    ; (less than half over water: hidden; a corner
            ret c                           ;   tile's slivers and tails; owner, 2026-11-26)
            call rf_tile
            ld c, 2
.k:         ld a, [RF_I]                    ; kind C at bits 2 i
            ld b, a
            ld a, c
.ks:        dec b
            bit 7, b
            jr nz, .kd
            add a, a
            add a, a
            jr .ks
.kd:        ld hl, rf_scls
            or [hl]
            ld [hl], a
            ret

; C = quarter column, B = quarter row (from the party's tile, signed): HL = that quarter's 8
; mask rows (the Color's REFL_MASK, the plain Game Boy's at + $1000)
rf_qp:      ld a, b                         ; metatile key: column / 2, row / 2 (signed nibbles)
            sra a
            and $0F
            ld d, a
            ld a, c
            sra a
            and $0F
            swap a
            or d
            ld d, a                         ; D = key
            ld hl, RF_CK                    ; cached?
            ld a, [RF_CN]
            ld e, a
.f:         ld a, e
            and a
            jr z, .miss
            ld a, [hl+]
            cp d
            jr z, .hit
            inc hl
            dec e
            jr .f
.hit:       ld a, [hl]
            jr .got
.miss:      push bc
            push de
            push hl
            ld a, c                         ; E = px + column / 2, D = py + row / 2
            sra a
            ld e, a
            ld a, [px]
            add a, e
            ld e, a
            ld a, b
            sra a
            ld d, a
            ld a, [py]
            add a, d
            ld d, a
            ldh a, [cmask]                  ; (a town: 64 x 64)
            and e
            ld e, a
            ldh a, [cmask]
            and d
            ld d, a
            call rw1
            and $7F
            pop hl
            pop de
            pop bc
            ld e, a
            ld a, [RF_CN]                   ; (cached, 6 at most)
            cp 6
            jr nc, .nc
            inc a
            ld [RF_CN], a
            ld a, d
            ld [hl+], a
            ld [hl], e
.nc:        ld a, e
.got:       ld l, a
            ldh a, [maptype]                ; a town: its quarter flags, whole rows
            and a
            jr nz, .owm
            ld h, 0
            add hl, hl
            add hl, hl
            ld a, b
            and 1
            add a, a
            ld e, a
            ld a, c
            and 1
            or e
            ld e, a
            ld d, 0
            add hl, de
            ld de, RF_TWAT
            add hl, de
            ld a, [hl]
            ld [RF_UV], a
            ld hl, RF_ROWS00
            and a
            ret z
            ld hl, RF_ROWSFF
            ret
.owm:       ld h, 0                         ; HL = 4 mt + quarter (the whole-quarter table's
                                            ;   index), then x 8 + the mask table
            add hl, hl
            add hl, hl
            ld a, b
            and 1
            add a, a
            ld e, a
            ld a, c
            and 1
            or e
            ld e, a
            ld d, 0
            add hl, de
            push hl
            ld de, REFL_UNI
            ldh a, [is_cgb]
            and a
            jr nz, .u
            ld d, high(REFL_UNI) + 2
.u:         add hl, de
            ld a, [hl]
            ld [RF_UV], a
            pop hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, REFL_MASK
            ldh a, [is_cgb]
            and a
            jr nz, .cg
            ld d, high(REFL_MASK) + $10
.cg:        add hl, de
            ld a, [RF_UV]
            ret

; Z if nothing the tiles depend on changed since they were made (the party's place and step,
; the sprites' places and tiles); the new values kept
rf_sig:     ld hl, RF_SIG
            ld c, 0                         ; C: a difference
            ld a, [px]
            call .b
            ld a, [py]
            call .b
            ld a, [mcount]
            call .b
            ld a, [mdx]
            call .b
            ld a, [mdy]
            call .b
            ld a, [moving]
            call .b
            ld a, [dash]
            call .b
            ld de, RF_OAM
            ld b, 16
.o:         ld a, [de]
            inc e
            call .b
            dec b
            jr nz, .o
            ld a, c
            and a
            ret
.b:         cp [hl]
            jr z, .s
            ld c, 1
            ld [hl], a
.s:         inc hl
            ret

; RF_T's tile masked by RF_ROWS (the sprite is drawn upside down: tile row j at screen row 7 - j)
; into RF_STG + 16 RF_I
rf_tile:    ld a, [RF_I]                    ; the source kept for this slot? (same tile, class)
            add a, a
            add a, low(RF_TC)
            ld l, a
            ld h, high(RF_TC)
            ld a, [RF_T]
            cp [hl]
            jr nz, .ld
            inc l
            ld a, [ps_cls]
            cp [hl]
            jr z, .m
            dec l
.ld:        ld a, [RF_T]
            ld [hl+], a
            ld a, [ps_cls]
            ld [hl], a
            ld a, [RF_T]
            cp $10
            jr nc, .veh
            ld a, [RF_T]                    ; the party: the class's tile
            swap a
            ld l, a
            ldh a, [is_cgb]
            and a
            jr z, .pd
            ld a, [ps_cls]                  ; (the Color: MINI_BANK $64 + class, as it is)
            add a, $64
            ld h, a
            call rf_srcd
            ld bc, 16
            ld a, MINI_BANK
            call far_copy
            jr .m
.pd:        ld a, [ps_cls]                  ; (DMG / SGB: the build's pre-shaded overworld
            add a, high(REFL_PDMG)          ;   copy in this bank, REFL_PDMG + 256 class)
            ld h, a
            call rf_srcd
            ld b, 16
.pc:        ld a, [hl+]
            ld [de], a
            inc e
            dec b
            jr nz, .pc
            jr .m
.veh:       sub $10                         ; a vehicle: the overworld's tiles (Color / DMG)
            swap a
            ld l, a
            and $0F
            ld h, a
            ld a, l
            and $F0
            ld l, a
            ld de, M_VEHCGB
            ldh a, [is_cgb]
            and a
            jr nz, .vc
            ld de, M_VEHDMG
.vc:        add hl, de
            call rf_srcd
            ld bc, 16
            ld a, OW_INFO
            call far_copy
.m:         call rf_srcd                    ; HL = the slot's source
            ld h, d
            ld l, e
            ld a, [RF_I]
            swap a
            add a, low(RF_STG)
            ld e, a
            ld d, high(RF_STG)
            ld c, 7                         ; tile row j: screen row 7 - j
.t:         push hl
            ld a, c
            add a, low(RF_ROWS)
            ld l, a
            ld h, high(RF_ROWS)
            ld b, [hl]
            pop hl
            ld a, [hl+]
            and b
            ld [de], a
            inc de
            ld a, [hl+]
            and b
            ld [de], a
            inc de
            dec c
            bit 7, c
            jr z, .t
            ret
; DE = the slot's kept source (RF_TD + 16 RF_I)
rf_srcd:    ld a, [RF_I]
            swap a
            add a, low(RF_TD)
            ld e, a
            ld d, high(RF_TD)
            ret
; V-Blank (after the water): the masked tiles made into the set not shown, 16 bytes while LY
; is 144-152; all up: that set and the kinds made are shown
rf_up9:     ld a, [rf_pend]
            and a
            ret z
.l:         ld a, [rf_upi]
            cp 4
            jr nc, .done
            ld b, a                         ; masked? (kind 2)
            ld a, [rf_scls]
            inc b
.k:         dec b
            jr z, .kk
            srl a
            srl a
            jr .k
.kk:        and 3
            cp 2
            jr nz, .nx
            ld a, [rf_upi]                  ; HL = RF_STG + 16 i, DE = tile ($70 / $74) + i
            swap a
            add a, low(RF_STG)
            ld l, a
            ld h, high(RF_STG)
            ld a, [rf_tb]                   ; (none on this map: nothing to copy)
            and a
            jr z, .nx
            ld e, a
            ld a, [rf_aset]
            and 1
            xor 1
            add a, a
            add a, a
            add a, e
            ld e, a
            ld a, [rf_upi]
            add a, e
            swap a
            ld e, a
            and $0F
            or $80
            ld d, a
            ld a, e
            and $F0
            ld e, a
            ldh a, [rLY]                    ; (in the V-Blank handler: no interrupt comes)
            sub 144
            cp 8
            jr nc, .late
            ld a, [hl+]                     ; (unrolled: 5 cycles a byte)
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
.nx:        ld hl, rf_upi
            inc [hl]
            jr .l
.late:      ret                             ; (the rest in the next V-Blank)
.done:      xor a
            ld [rf_upi], a
            ld [rf_pend], a
            ld a, [rf_aset]
            xor 1
            ld [rf_aset], a
            ld a, [rf_scls]
            ld [rf_acls], a
            jp rf_patch

section bank 0, $2E6D                       ; (free space)
; the V-Blank handler: OAM, then at once the reflection's masked tiles (the plain Game Boy's
; V-Blank has room only this early: the map's rows and the water come after)
rf_dma:     call hram_dma
            jp rf_vbu
section bank 0, $16CB                       ; (free space)
rf_vbu:     ld a, [rf_pend]
            and a
            ret z
            ld a, REFL_BANK
            ld hl, rf_up9
            jp bank_call

section bank 111, $4A10                     ; (free space)
; refl_msk said some part shows (C): on the overworld, C cleared while the tile below the party
; (where the reflection is drawn) is a shore tile at least half land (its water pixels 1-127 of 256): the reflection fades out there
; (owner, 2026-11-26: wedges and tails on such corners). Worked out once per tile (rf_ck*)
rf_corner:  ldh a, [maptype]                ; (towns: maptype 0, whole-tile water)
            and a
            scf
            ret z
            ld a, [px]
            ld e, a
            ld a, [py]                      ; (the tile below the party: where it is drawn)
            inc a
            ld d, a
            ld hl, rf_ckx
            ld a, [hl+]
            cp e
            jr nz, .new
            ld a, [hl+]
            cp d
            jr nz, .new
            ld a, [hl]                      ; (cached: 1 = a mostly-land shore tile)
            jr .res
.new:       ld hl, rf_ckx
            ld [hl], e
            inc hl
            ld [hl], d
            call rw1                        ; A = the party's metatile
            and $7F
            ld l, a                         ; HL = REFL_MASK + 32 mt (the plain Game Boy's + $1000)
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, REFL_MASK
            ldh a, [is_cgb]
            and a
            jr nz, .cg
            ld d, high(REFL_MASK) + $10
.cg:        add hl, de
            ld c, 32
            ld e, 0
            ld d, 0
.b:         ld a, [hl]
            and $0F
            call .n
            ld a, [hl+]
            swap a
            and $0F
            call .n
            dec c
            jr nz, .b
            ld a, d                         ; DE = water pixels (0-256)
            and a
            ld a, 0
            jr nz, .st                      ; (256: all water)
            ld a, e
            and a
            jr z, .st                       ; (no water: nothing shows there anyway)
            cp 128
            ld a, 0
            jr nc, .st
            inc a                           ; 1-127: a shore tile mostly land
.st:        ld [rf_ckr], a
.res:       and a
            scf
            ret z
            xor a                           ; (NC: nothing shows)
            ret
.n:         push hl
            add a, low(rf_nib)
            ld l, a
            ld a, high(rf_nib)
            adc a, 0
            ld h, a
            ld a, [hl]
            pop hl
            add a, e
            ld e, a
            ret nc
            inc d
            ret
; C if fewer than half of the sprite's 64 pixels are over water (RF_ROWS' bits, counted by nibble)
rf_half:    ld hl, RF_ROWS
            ld c, 8
            ld e, 0
.r:         ld a, [hl]
            and $0F
            call .n
            ld a, [hl+]
            swap a
            and $0F
            call .n
            dec c
            jr nz, .r
            ld a, e
            cp 32
            ret
.n:         push hl
            add a, low(rf_nib)
            ld l, a
            ld a, high(rf_nib)
            adc a, 0
            ld h, a
            ld a, [hl]
            add a, e
            ld e, a
            pop hl
            ret
rf_nib:     db 0, 1, 1, 2, 1, 2, 2, 3, 1, 2, 2, 3, 2, 3, 3, 4
; Z if the party's tiles (RF_OAM) are those the kept tiles were cut from (RF_SIG's copy)
rf_pose:    ld hl, RF_OAM + 2
            ld de, RF_SIG + 7 + 2
            ld b, 4
.l:         ld a, [de]
            cp [hl]
            ret nz
            ld a, l
            add a, 4
            ld l, a
            ld a, e
            add a, 4
            ld e, a
            dec b
            jr nz, .l
            ret
; the four OAM entries the tiles made will need (the kinds made, the set not shown now), ready
; for rf_patch's copy
rf_next:    ld a, [rf_scls]
            ld c, a
            ld b, 0
            ld hl, RF_RAW
            ld de, RF_NEXT
.e:         ld a, c
            and 3
            jr z, .hd
            cp 2
            jr z, .m
            ld a, [hl+]                     ; whole: the sprite as mirrored
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
            jr .nx
.m:         ld a, [rf_tb]                   ; masked: its slot in the set not shown now
            and a
            jr z, .hd                       ; (no tiles on this map: hidden)
            push bc
            ld c, a
            ld a, [rf_aset]
            and 1
            xor 1
            add a, a
            add a, a
            add a, c
            add a, b
            ld c, a
            ld a, [hl+]                     ; y, x, the slot, attributes
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            inc l
            ld a, c
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            pop bc
            jr .nx
.hd:        xor a
            ld [de], a
            inc e
            inc e
            inc e
            inc e
            inc l
            inc l
            inc l
            inc l
.nx:        srl c
            srl c
            inc b
            ld a, b
            cp 4
            jr c, .e
            ret
; all the masked tiles up: the reflection's four OAM entries (the hardware's, just loaded by
; the DMA) set to the new kinds at once, so the tiles show with the frame's party
; sprites, not a frame after (owner's list, 2026-11-26: a turn showed the old pose for a frame).
; 16 bytes, unrolled: within a line, so even the plain Game Boy's late uploads (line 152) fit
rf_patch:   ld a, [rf_hid]
            and a
            ret nz
            ldh a, [rLY]                    ; (OAM open: the V-Blank's lines only; line 153
            sub 144                         ;   reads 0 on the plain Game Boy: skipped)
            cp 9
            ret nc
            ld hl, RF_NEXT
            ld de, $FE00 + low(REFL_OAM)
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
            ld a, [hl]
            ld [de], a
            ret                             ; (the copy: the next frame's .apply; a frame
                                            ;   missed shows the last picture again)

section wram, $DA92
rf_want:    ds 1                            ; 1: the reflection shows, OAM 36-39 its own
section wram, $DA96
rf_ckx:     ds 1                            ; rf_corner's last tile (x, y) and its result
rf_cky:     ds 1
rf_ckr:     ds 1
