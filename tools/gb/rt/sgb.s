; Super Game Boy: detection, packets, colour palettes and the screen attribute map.
; Runs in DMG mode on top of the DMG shading (rt/dmg_shade.s): a BG pixel's 2-bit value is
; its brightness group (0 = backdrop, 1-3 darkest .. brightest), and on the SGB the BGP
; passes the value through as the colour number (minus the fade), so SGB palette p colour v
; is the NES colour of BG palette p that has value v. Sprites use the colours of the cell
; they are in (SGB hardware); outside battle both OBPs give colours 0 / 2 / 3 (see sgb_obp).
; Static screens: each 8x8 screen cell gets the SGB palette of its NES attribute (ATTR_CHR).
; Screens that scroll (field, towns, dungeons) get one palette for the whole screen
; (ATTR_BLK), its colours taken from the palette most cells on screen use.
; Packets are built in cart RAM bank 2 (NEXT = the state wanted, SENT = what the SGB has)
; and sent one at a time, SGB_GAP frames apart, from the frame wait.
;   packets 0 PAL01, 1 PAL23, 2.. ATTR_BLK (1) or ATTR_CHR (6)

SGB_NEXT   = $A100          ; cart RAM bank 3: 8 packets
SGB_SENT   = $A180          ; cart RAM bank 3: 8 packets as last sent
SGB_GAP    = 4              ; frames between packets
SGB_GRID   = $A200          ; cart RAM bank 3: palette of each screen cell (20 x 18)
SGB_COVER  = $A400          ;   cells covered by the rectangles so far (GRID + $200)
SGB_SETS   = $A380          ;   ATTR_BLK data sets (6 bytes, at most 15)

; ---- boot (DMG, LCD off, interrupts off): is_sgb = 1 on a Super Game Boy
sgb_detect: ld b, 6
            call sgb_delay
            ld hl, MLT_REQ2
            call sgb_send
            ld b, 4
            call sgb_delay
            ld c, 4                         ; two-player mode: the joypad ID changes
.try:       ld a, $20                       ;   when P15 is pulsed
            ldh [$FF00], a
            ld a, $30
            ldh [$FF00], a
            ld a, $10
            ldh [$FF00], a
            ld a, $30
            ldh [$FF00], a
            ldh a, [$FF00]
            ldh a, [$FF00]
            and $03
            cp $03
            jr nz, .sgb
            dec c
            jr nz, .try
            ret
.sgb:       ld a, 1
            ldh [is_sgb], a
            ld hl, MLT_REQ1
            call sgb_send
            ld b, 4
            call sgb_delay
            call sgb_border
            ld a, $FF                       ; everything to send
            ldh [sgb_dirty], a
            ldh [sgb_force], a
            ret

MLT_REQ2:   db $89, $01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
MLT_REQ1:   db $89, $00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
MASK_FRZ:   db $B9, $01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
MASK_OFF:   db $B9, $00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
MASK_BLK:   db $B9, $03, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
CHR_TRN0:   db $99, $00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
PCT_TRN:    db $A1, $00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

; the border (boot, LCD off): screen frozen; the tiles, then the map and its palettes, each
; shown as BG tiles 0-255 for the SGB to read (VRAM transfer); VRAM cleared again
sgb_border: ld hl, MASK_FRZ
            call sgb_send
            ld b, 2
            call sgb_delay
            ld a, RT_TABLES
            ld [$2000], a
            ld hl, sgb_bdr_chr
            ld bc, sgb_bdr_chr_end - sgb_bdr_chr
            ld de, CHR_TRN0
            call .trn
            ld hl, sgb_bdr_pct
            ld bc, $880
            ld de, PCT_TRN
            call .trn
            ld a, 1
            ld [$2000], a
            ld hl, MASK_OFF
            jp sgb_send
.trn:       push de                         ; HL = data, BC = length -> $8000; packet DE
            push hl
            push bc
            ld hl, $8000
            ld bc, $1800
            call memclr
            pop bc
            pop hl
            ld de, $8000
.cp:        ld a, [hl+]
            ld [de], a
            inc de
            dec bc
            ld a, b
            or c
            jr nz, .cp
            ld hl, $9800                    ; map: tiles 0-255 in order, 20 per row
            ld de, 0                        ; (D = tile, E = column)
            ld b, 13
.r:         ld c, 20
.c:         ld a, d
            ld [hl+], a
            inc d
            dec c
            jr nz, .c
            ld a, l
            add a, 12
            ld l, a
            jr nc, .nh
            inc h
.nh:        dec b
            jr nz, .r
            ld a, %11100100
            ldh [$FF47], a
            ld a, %10010001                 ; LCD on, BG tiles $8000, map $9800
            ldh [$FF40], a
            ld b, 2
            call sgb_delay
            pop hl
            call sgb_send
            ld b, 4
            call sgb_delay
.wv:        ldh a, [$FF44]                  ; LCD off (in vblank)
            cp 144
            jr c, .wv
            xor a
            ldh [$FF40], a
            ld hl, $8000
            ld bc, $2000
            jp memclr

; B frames of busy waiting (LCD off, before interrupts)
sgb_delay:  push bc
.f:         ld de, 2508
.l:         dec de
            ld a, d
            or e
            jr nz, .l
            dec b
            jr nz, .f
            pop bc
            ret

; HL = 16-byte packet: sent bit by bit through P1 (interrupts off meanwhile). Keeps BC, DE.
sgb_send:   push bc
            push de
            xor a                           ; reset pulse
            ldh [$FF00], a
            ld a, $30
            ldh [$FF00], a
            ld b, 16
.byte:      ld e, [hl]
            inc hl
            ld c, 8
.bit:       ld a, $10                       ; 1: P15 low
            rr e
            jr c, .one
            ld a, $20                       ; 0: P14 low
.one:       ldh [$FF00], a
            ld a, $30
            ldh [$FF00], a
            dec c
            jr nz, .bit
            dec b
            jr nz, .byte
            ld a, $20                       ; stop bit
            ldh [$FF00], a
            ld a, $30
            ldh [$FF00], a
            pop de
            pop bc
            ret

; sgb_build in its bank (SGB_BANK at $4000), then the code bank again
sgb_build_far:
            ld a, SGB_BANK
            ld [$2000], a
            call sgb_build
            ldh a, [code_bank]
            ld [$2000], a
            ret

; ---- once per NES frame (rt_wait_nmi): build the state when wanted, send one packet
sgb_frame:  call sgb_scroll
            ldh a, [sgb_wait]
            and a
            jr z, .go
            dec a
            ldh [sgb_wait], a
            ret
.go:        push bc
            push de
            push hl
            ldh a, [sgb_mask]               ; screen going off: blank the SGB screen (black)
            cp 1                            ;   until the new screen's palettes and
            jr nz, .nm                      ;   attributes are out (no frames in the old
            inc a                           ;   screen's colours)
            ldh [sgb_mask], a
            ld hl, MASK_BLK
            jr .one
.nm:        ldh a, [sgb_mask]
            cp 2
            jr c, .nrm
            jr nz, .m3
            ldh a, [lcd_on]                 ; blanked: nothing while the LCD is off (the
            and a                           ;   screen is being drawn); once it is on, one
            jr z, .x                        ;   fresh build (it replaces anything pending)
            ld a, 3
            ldh [sgb_mask], a
            call sgb_build_far
.m3:        ldh a, [sgb_pend]               ; its packets out: show the screen (the game's
            and a                           ;   fade-in, if any, follows unblanked)
            jr nz, .send
            jr .um
.nrm:       ldh a, [sgb_pend]
            and a
            jr nz, .send
            ldh a, [sgb_dirty]
            and a
            jr z, .x
            ld a, [SGB_BGAP]                ; at most one build per SGB_MIN frames (the band
            and a                           ;   fade changes attributes every frame; the
            jr z, .bd                       ;   packets go out one per 4 frames anyway)
            dec a
            ld [SGB_BGAP], a
            jr .x
.bd:        ld a, SGB_MIN - 1
            ld [SGB_BGAP], a
            call sgb_build_far
            ldh a, [sgb_pend]
            and a
            jr z, .x
.send:      ld c, 0                         ; lowest pending packet
            ld b, a
.f:         srl b
            jr c, .k
            inc c
            jr .f
.k:         ld a, c                         ; clear its bit
            ld b, 1
            and a
            jr z, .m0
.m:         sla b
            dec a
            jr nz, .m
.m0:        ld a, b
            cpl
            ld b, a
            ldh a, [sgb_pend]
            and b
            ldh [sgb_pend], a
            ld a, c                         ; HL = NEXT + 16c (RAM bank 2)
            swap a
            ld l, a
            ld h, high(SGB_NEXT)
            ld a, 3
            ld [$4000], a
            di
            call sgb_send
            ei
            ld de, -16                      ; SENT = NEXT
            add hl, de
            ld d, h
            ld e, l
            ld a, l
            add a, $80
            ld l, a
            ld b, 16
.cp:        ld a, [de]
            inc de
            ld [hl+], a
            dec b
            jr nz, .cp
            xor a
            ld [$4000], a
            ld a, SGB_GAP
            ldh [sgb_wait], a
            jr .x
.um:        xor a
            ldh [sgb_mask], a
            ld hl, MASK_OFF
.one:       di
            call sgb_send
            ei
            ld a, SGB_GAP
            ldh [sgb_wait], a
.x:         pop hl
            pop de
            pop bc
            ret

; BGP / OBP on the SGB: colour number = value, darkened by fade_drop (to the backdrop)
sgb_bgp:    push bc
            push de
            ldh a, [fade_drop]
            ld c, a
            ld b, 3                         ; value 3 .. 1
            ld a, 0
.v:         push af
            ld a, b
            sub c
            jr nc, .ok
            xor a
.ok:        ld e, a
            pop af
            or e
            rlca
            rlca
            dec b
            jr nz, .v
            pop de                          ; (value 0 -> 0 in bits 0-1)
            pop bc
            ret

sgb_obp:    push bc
            push de
            ldh a, [fade_drop]
            ld c, a
            ldh a, [in_battle]              ; battle (the party over the black backdrop, where
            and a                           ;   a black outline would vanish): OBP0 0 / 1 / 3,
            jr z, .menu                     ;   OBP1 1 / 2 / 3; with a party slot both 1 / 2 / 3
            ldh a, [sgb_pslot]              ;   (value v = the party palette's colour v)
            and a
            jr z, .old
            ld b, 1
            ld e, 2
            ld d, 3
            call .mk
            ldh [obp0_v], a
            ld b, 1
            ld e, 2
            ld d, 3
            jr .o1
.old:
            ld b, 0
            ld e, 1
            ld d, 3
            call .mk
            ldh [obp0_v], a
            ld b, 1
            ld e, 2
            ld d, 3
            jr .o1
.menu:      ld b, 0                         ; OBP0 and OBP1: values 1 / 2 / 3 -> colours 0 /
            ld e, 2                         ;   2 / 3: never colour 1, the darkest colour of the
            ld d, 3                         ;   cell's palette, which is the window blue / the
            call .mk                        ;   field's dark ground (sprites blended in); the
            ldh [obp0_v], a                 ;   backdrop black outlines them instead
            ld b, 0
            ld e, 2
            ld d, 3
.o1:
            call .mk
            ldh [obp1_v], a
            pop de
            pop bc
            ret
.mk:        ld a, d                         ; (B, E, D = colours of values 1, 2, 3)
            call .sub
            ld d, a
            ld a, e
            call .sub
            ld e, a
            ld a, b
            call .sub
            add a, a
            add a, a                        ; value 1 -> bits 2-3
            ld b, a
            ld a, e
            swap a                          ; value 2 -> bits 4-5
            or b
            ld b, a
            ld a, d
            rrca
            rrca                            ; value 3 -> bits 6-7
            or b
            ret
.sub:       sub c
            ret nc
            xor a
            ret

; scrolling seen with the LCD on: one palette for the screen until the LCD goes off; in
; that mode the state is rebuilt every 32 frames (the cells on screen change)
sgb_scroll: push bc
            ldh a, [scroll_x]
            ld b, a
            ldh a, [cam_x]
            add a, b
            ld b, a
            ldh a, [scroll_y]
            ld c, a
            ldh a, [cam_y]
            add a, c
            ld c, a
            ldh a, [lcd_on]
            and a
            jr z, .save
            ld a, [SGB_LSX]
            cp b
            jr nz, .mv
            ld a, [SGB_LSY]
            cp c
            jr z, .save
.mv:        ldh a, [sgb_glob]
            and a
            jr nz, .save
            ld a, 1
            ldh [sgb_glob], a
            ld a, $FF
            ldh [sgb_force], a
            ldh [sgb_dirty], a
.save:      ld a, b
            ld [SGB_LSX], a
            ld a, c
            ld [SGB_LSY], a
            ldh a, [sgb_glob]
            and a
            jr z, .x
            ld a, [SGB_TICK]
            inc a
            ld [SGB_TICK], a
            and 31
            jr nz, .x
            ld a, [SGB_TX]                  ; (only if the view moved since the last one)
            cp b
            jr nz, .tk
            ld a, [SGB_TY]
            cp c
            jr z, .x
.tk:        ld a, b
            ld [SGB_TX], a
            ld a, c
            ld [SGB_TY], a
            ld a, 1
            ldh [sgb_dirty], a
.x:         pop bc
            ret

; LCD going off: static screens again (per-cell palettes)
sgb_lcd_off:
            ldh a, [sgb_mask]               ; blank (1), or wait for a new build (3 -> 2)
            and a
            jr z, .m1
            cp 3
            jr nz, .k
            dec a
            dec a
.m1:        inc a
            ldh [sgb_mask], a
.k:         ldh a, [sgb_glob]
            and a
            ret z
            xor a
            ldh [sgb_glob], a
            ld a, $FF
            ldh [sgb_force], a
            ldh [sgb_dirty], a
            ret


; ---- the SGB packet builder and its helpers (called only from sgb_frame through
; sgb_build_far): in a bank of their own, the runtime bank 0 being full
section bank SGB_BANK, $4000
; ---- NEXT from the current palettes and map; sgb_pend = the packets that differ from SENT
sgb_build:  xor a
            ldh [sgb_dirty], a
            ld a, 3
            ld [$4000], a
            ldh a, [sgb_glob]               ; static screen, only the palettes changed: the
            ld b, a                         ;   cells, the party slot and the ATTR packets
            ldh a, [sgb_force]              ;   stay (the cell count is the costly part)
            or b
            ld b, a
            ldh a, [sgb_adirty]
            or b
            jr nz, .full
            ld hl, SGB_NEXT
            ld b, 32
.cp:        ld [hl+], a
            dec b
            jr nz, .cp
            ldh a, [sgb_pslot]
            push af
            jr .np
.full:      xor a
            ldh [sgb_adirty], a
            ld hl, SGB_NEXT                 ; clear NEXT
            ld b, 128
            xor a
.cl:        ld [hl+], a
            dec b
            jr nz, .cl
            ldh a, [sgb_pslot]              ; (the party slot is chosen again)
            push af
            ldh a, [sgb_glob]               ; battle: the last party slot if it is still free
            and a                           ;   (only the party column's 48 cells use it):
            jr nz, .z0                      ;   one cell count instead of two
            ldh a, [in_battle]
            and a
            jr z, .z0
            ldh a, [sgb_pslot]
            and a
            jr z, .z0
            call sgb_counts
            ldh a, [sgb_pslot]
            dec a
            add a, low(SGB_CNT)
            ld l, a
            ld h, high(SGB_CNT)
            ld a, [hl]
            cp 48
            jr z, .np
.z0:        xor a
            ldh [sgb_pslot], a
            call sgb_counts                 ; cells per palette on screen; per-cell palettes
            ldh a, [sgb_glob]               ;   -> the ATTR packets
            and a
            jr nz, .glob0
            ldh a, [in_battle]              ; battle: a slot no BG cell uses -> the party
            and a                           ;   column's cells (backdrop only) with the party
            jr z, .np                       ;   sprites' colours
            ld c, 3
.fs:        ld a, c
            add a, low(SGB_CNT)
            ld l, a
            ld h, high(SGB_CNT)
            ld a, [hl]
            and a
            jr z, .got
            dec c
            bit 7, c
            jr z, .fs
            ld c, 0                         ; none free: slot 0 (NES palette 0 is the battle
.got:       ld a, c                         ;   scenery strip, above the GB view; in view only
                                            ;   empty backdrop cells use it)
            inc a
            ldh [sgb_pslot], a
            call sgb_counts
.np:        pop af                          ; slot changed: the OBPs again
            ld c, a
            ldh a, [sgb_pslot]
            cp c
            jr z, .st
            ld a, 1
            ldh [pal_dirty], a
.st:        ld hl, SGB_NEXT                 ; PAL01, PAL23 from the four NES BG palettes
            ld a, $01                       ;   (or the party's colours in its slot)
            ld [hl+], a
            call bk_rgb
            ld c, 0
            call pal_or_spr
            ld c, 1
            call pal_or_spr
            ld hl, SGB_NEXT + 16
            ld a, $09
            ld [hl+], a
            call bk_rgb
            ld c, 2
            call pal_or_spr
            ld c, 3
            call pal_or_spr
            ld a, 6                         ; the cells as rectangles (ATTR_BLK) if they
            ldh [sgb_nattr], a              ;   take at most 15, else ATTR_CHR (6 packets)
            call sgb_rects
            jr .cmp
.glob0:     pop af
            ld c, a                         ; (scrolling: no party slot)
            and a
            jr z, .glob
            ld a, 1
            ldh [pal_dirty], a
.glob:      ld hl, SGB_NEXT                 ; one palette (SGB 0) for the screen: each value
            ld a, $01                       ;   from the palette with most cells that has it
            ld [hl+], a
            call bk_rgb
            call glob_rgb
            ld hl, SGB_NEXT + 16            ; ATTR_BLK: whole screen palette 0
            ld a, $21
            ld [hl+], a
            ld a, 1
            ld [hl+], a
            ld a, 7
            ld [hl+], a
            xor a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld a, 19
            ld [hl+], a
            ld a, 17
            ld [hl], a
            ld hl, SGB_NEXT + 32            ; (packets 2..7 unused)
.cmp:       ld b, 0                         ; pending = groups that differ: PAL01 (bit 0),
            ld c, 0                         ;   PAL23 / ATTR_BLK (bit 1), ATTR_CHR (bits 2-7)
            call pk_diff
            jr z, .d1
            set 0, b
.d1:        ld c, 1
            call pk_diff
            jr z, .d2
            set 1, b
.d2:        ldh a, [sgb_glob]
            and a
            jr nz, .dn
            ld c, 2                         ; ATTR packets (sgb_nattr): all if any differs
            ldh a, [sgb_nattr]
            add a, 2
            ld e, a
.d3:        call pk_diff
            jr nz, .chr
            inc c
            ld a, c
            cp e
            jr nz, .d3
            jr .dn
.chr:       call attr_mask
            or b
            ld b, a
.dn:        ldh a, [sgb_force]              ; (everything after detection / a mode change;
            ld c, a                         ;   one palette: PAL01 and ATTR_BLK only)
            ldh a, [sgb_glob]
            and a
            ld a, c
            jr z, .fa
            and $03
            jr .fb
.fa:        push af
            call attr_mask
            or 3
            ld c, a
            pop af
            and c
.fb:        or b
            ldh [sgb_pend], a
            xor a
            ldh [sgb_force], a
            ld [$4000], a
            ret

; C = packet: NZ if NEXT and SENT differ (RAM bank 2 on)
pk_diff:    push bc
            push hl
            ld a, c
            swap a
            ld l, a
            ld h, high(SGB_NEXT)
            ld b, 16
.l:         ld a, l
            add a, $80
            ld e, a
            ld d, h
            ld a, [de]
            cp [hl]
            jr nz, .x
            inc l
            dec b
            jr nz, .l
.x:         pop hl
            pop bc
            ret

; HL -> the backdrop's RGB555 (2 bytes)
bk_rgb:     ld a, [PAL_SH]
            jp rgb_put

; A = NES colour -> 2 bytes at HL
rgb_put:    push de
            and $3F
            add a, a
            ld e, a
            ld d, high(NES_RGB)
            ld a, [de]
            ld [hl+], a
            inc e
            ld a, [de]
            ld [hl+], a
            pop de
            ret

; C = NES BG palette: colours of values 1-3 (6 bytes at HL). The colour of value v is the
; index with that value that has the best col_score (a hue before a grey, then brighter); a value the palette lacks gets the next lower one's
; (the backdrop for none).
pal_rgb:    ld b, 1
.v:         call val_col
            call rgb_put
            inc b
            ld a, b
            cp 4
            jr nz, .v
            ret

; C = slot: the party's colours in the battle party slot, else NES BG palette C's
pal_or_spr: ldh a, [sgb_pslot]
            dec a
            cp c
            jp nz, pal_rgb
            ld b, 1                         ; values 1-3 from the party's sprite palettes
.v:         call spr_col
            call rgb_put
            inc b
            ld a, b
            cp 4
            jr nz, .v
            ret

; B = value -> A = NES colour: among NES sprite palettes 0-1 (the party), the index with
; that value (SPAL_KEY) that has the best col_score; none: the next lower value
spr_col:    push bc
            push de
            push hl
.again:     ld a, b
            and a
            jr z, .bk
            ld d, $FF
            ld e, 0
            ld c, 0
.p:         ld a, c
            add a, low(SPAL_KEY)
            ld l, a
            ld h, high(SPAL_KEY)
            ld a, [hl]                      ; key: v1 | v2 << 2 | v3 << 4
            and $3F
            ld h, a
            ld l, 1
.i:         ld a, h
            and 3
            cp b
            jr nz, .n
            push hl
            ld a, c
            add a, a
            add a, a
            add a, l
            add a, low(PAL_SH) + $10
            ld l, a
            ld h, high(PAL_SH)
            ld a, [hl]
            pop hl
            push af
            call col_score
            cp e
            jr c, .lo
            ld e, a
            pop af
            ld d, a
            jr .n
.lo:        pop af
.n:         srl h
            srl h
            inc l
            ld a, l
            cp 4
            jr nz, .i
            inc c
            ld a, c
            cp 2
            jr nz, .p
            ld a, d
            cp $FF
            jr nz, .x
            dec b
            jr .again
.bk:        ld a, [PAL_SH]
.x:         pop hl
            pop de
            pop bc
            ret

; A = NES colour -> its score for being the SGB colour of its value: a hue (columns 1-12)
; before a grey, then the brighter
col_score:  push bc
            ld b, a
            call lum
            inc a
            ld c, a
            ld a, b
            and $0F
            jr z, .g
            cp $0D
            jr nc, .g
            ld a, c
            add a, 16
            pop bc
            ret
.g:         ld a, c
            pop bc
            ret

; B = value, C = palette -> A = NES colour (see pal_rgb)
val_col:    push bc
            push de
            push hl
.again:     ld a, b
            and a
            jr z, .bk
            ld d, $FF                       ; best colour
            ld e, 0                         ; its brightness + 1
            ld a, c
            add a, a
            add a, a
            ld l, a
            inc l                           ; index 1
.i:         ld a, l
            and 3
            jr z, .done
            ld h, high(PAL_MAP)
            ld a, l
            add a, low(PAL_MAP)
            push hl
            ld l, a
            ld a, [hl]
            pop hl
            cp b
            jr nz, .n
            ld h, high(PAL_SH)
            ld a, [hl]
            push af
            call col_score
            cp e
            jr c, .lo
            ld e, a
            pop af
            ld d, a
            jr .n
.lo:        pop af
.n:         inc l
            jr .i
.done:      ld a, d
            cp $FF
            jr nz, .x
            dec b                           ; none: the next lower value
            jr .again
.bk:        ld a, [PAL_SH]
.x:         pop hl
            pop de
            pop bc
            ret

; one palette for a scrolling screen: value v from the palette with most cells on screen
; among those that have v (6 bytes at HL)
glob_rgb:   ld b, 1
.v:         push hl
            ld c, $FF                       ; chosen palette
            ld d, 0                         ; its count
            ld e, 0                         ; palette
.p:         ld a, e                         ; palette E has value B?
            add a, a
            add a, a
            add a, low(PAL_MAP) + 1
            ld l, a
            ld h, high(PAL_MAP)
            ld a, [hl+]
            cp b
            jr z, .has
            ld a, [hl+]
            cp b
            jr z, .has
            ld a, [hl]
            cp b
            jr nz, .np
.has:       ld a, e
            add a, low(SGB_CNT)
            ld l, a
            ld h, high(SGB_CNT)
            ld a, [hl]
            cp d
            jr c, .np
            jr z, .np0
            ld d, a
            ld c, e
            jr .np
.np0:       ld a, c                         ; equal counts: keep the first
            cp $FF
            jr nz, .np
            ld c, e
.np:        inc e
            ld a, e
            cp 4
            jr nz, .p
            pop hl
            ld a, c
            cp $FF
            jr nz, .got
            xor a                           ; nobody has it: palette 0 (val_col falls back)
.got:       ld c, a
            call val_col
            call rgb_put
            inc b
            ld a, b
            cp 4
            jr nz, .v
            ret

; cells on screen per NES BG palette -> SGB_CNT[0..3] (saturating at 255); the per-cell
; palettes go into ATTR_CHR packets 2-7 of NEXT (RAM bank 2 on)
sgb_counts: ld hl, SGB_CNT
            xor a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl], a
            ldh a, [sgb_glob]               ; scrolling screen: only the counts are used
            and a
            jp nz, sgb_counts_g
            ld hl, SGB_NEXT + 32            ; ATTR_CHR header: x 0, y 0, 360 cells, by rows
            ld a, $3E
            ld [hl+], a
            xor a
            ld [hl+], a
            ld [hl+], a
            ld a, $68
            ld [hl+], a
            ld a, $01
            ld [hl+], a
            xor a
            ld [hl+], a
            ld a, l
            ldh [sgb_ptr], a                ; next data byte
            ld a, low(SGB_GRID)
            ld [SGB_GP], a
            ld a, high(SGB_GRID)
            ld [SGB_GP + 1], a
            xor a
            ldh [sgb_acc], a
            ld a, 4
            ldh [sgb_nacc], a
            ldh a, [cam_x]                  ; first map column / row on screen
            ld b, a
            ldh a, [scroll_x]
            add a, b
            add a, 4                        ; (nearest cell)
            srl a
            srl a
            srl a
            ldh [sgb_c0], a
            ldh a, [cam_y]
            ld b, a
            ldh a, [scroll_y]
            add a, b
            jr c, .wr
            cp 240
            jr c, .sy
.wr:        sub 240
.sy:        add a, 4
            srl a
            srl a
            srl a
            cp 30
            jr c, .r0
            sub 30
.r0:        ldh [sgb_r0], a
            ld d, a                         ; D = map row, E = map column
            ld b, 18
.r:         push bc
            ldh a, [sgb_c0]
            ld e, a
            ld b, 20
.c:         push bc
            push de
            ld a, d                         ; the cell's palette (inline cell_pal / own_chk):
            and $1C                         ;   attribute byte NT_SH + $3C0 + (row >> 2) * 8
            add a, a                        ;   + (col >> 2) of the nametable that drew it
            ld c, a
            ld a, e
            rrca
            rrca
            and 7
            add a, c
            add a, $C0
            ld l, a
            ld h, high(NT_SH) + 3
            ldh a, [own1_lo]
            ld b, a
            ldh a, [own1_hi]
            or b
            jr z, .o0
            push hl
            ld a, d                         ; OWN + row * 4 + (col >> 3), bit col & 7
            add a, a
            add a, a
            ld l, a
            ld a, e
            rrca
            rrca
            rrca
            and 3
            or l
            ld l, a
            ld h, high(OWN)
            ld b, [hl]
            ld a, e
            and 7
            jr z, .ob
.os:        rrc b
            dec a
            jr nz, .os
.ob:        pop hl
            bit 0, b
            jr z, .o0
            ld a, h
            add a, 4
            ld h, a
.o0:        ld a, [hl]                      ; bottom half (row & 2): high nibble, right half
            bit 1, d                        ;   (col & 2): next two bits
            jr z, .t
            swap a
.t:         bit 1, e
            jr z, .l
            rrca
            rrca
.l:         and 3
            ld c, a
            ldh a, [sgb_pslot]              ; battle party column (GB cols 15-18, rows 0-11):
            and a                           ;   the party slot
            jr z, .po
            ldh a, [sgb_c0]
            ld l, a
            ld a, e
            sub l
            and 31
            sub 15
            cp 4
            jr nc, .po
            ldh a, [sgb_r0]
            ld l, a
            ld a, d
            sub l
            jr nc, .pr
            add a, 30
.pr:        cp 12
            jr nc, .po
            ldh a, [sgb_pslot]
            dec a
            ld c, a
.po:        ld a, [SGB_GP]                  ; GRID
            ld l, a
            ld a, [SGB_GP + 1]
            ld h, a
            ld [hl], c
            inc hl
            ld a, l
            ld [SGB_GP], a
            ld a, h
            ld [SGB_GP + 1], a
            ld a, c
            add a, low(SGB_CNT)             ; count
            ld l, a
            ld h, high(SGB_CNT)
            inc [hl]
            jr nz, .ns
            dec [hl]
.ns:        ldh a, [sgb_acc]                ; 2 bits per cell, first cell in bits 7-6
            add a, a
            add a, a
            or c
            ldh [sgb_acc], a
            ldh a, [sgb_nacc]
            dec a
            ldh [sgb_nacc], a
            jr nz, .nb
            ld a, 4
            ldh [sgb_nacc], a
            ldh a, [sgb_ptr]
            ld l, a
            ld h, high(SGB_NEXT)
            ldh a, [sgb_acc]
            ld [hl], a
            inc l
            ld a, l
            ldh [sgb_ptr], a
.nb:        pop de
            ld a, e
            inc a
            and 31
            ld e, a
            pop bc
            dec b
            jr nz, .c
            ld a, d
            inc a
            cp 30
            jr c, .rn
            xor a
.rn:        ld d, a
            pop bc
            dec b
            jr nz, .r
            ret

; scrolling screen: SGB_CNT from one cell per attribute quadrant on screen (even map row
; and column; the four cells of a quadrant share its palette unless two nametables drew
; them), 4 per quadrant (saturating at 255)
sgb_counts_g:
            ldh a, [cam_x]                  ; first map column / row on screen (as above)
            ld b, a
            ldh a, [scroll_x]
            add a, b
            add a, 4
            srl a
            srl a
            srl a
            ldh [sgb_c0], a
            ldh a, [cam_y]
            ld b, a
            ldh a, [scroll_y]
            add a, b
            jr c, .wr
            cp 240
            jr c, .sy
.wr:        sub 240
.sy:        add a, 4
            srl a
            srl a
            srl a
            cp 30
            jr c, .r0
            sub 30
.r0:        ld d, a                         ; D = map row, E = map column
            ld b, 18
.r:         bit 0, d
            jr nz, .rn
            push bc
            ldh a, [sgb_c0]
            ld e, a
            ld b, 20
.c:         bit 0, e
            jr nz, .cn
            push bc
            ld a, d                         ; attribute byte of the nametable that drew it
            and $1C
            add a, a
            ld c, a
            ld a, e
            rrca
            rrca
            and 7
            add a, c
            add a, $C0
            ld l, a
            ld h, high(NT_SH) + 3
            ldh a, [own1_lo]
            ld b, a
            ldh a, [own1_hi]
            or b
            jr z, .o0
            push hl
            ld a, d
            add a, a
            add a, a
            ld l, a
            ld a, e
            rrca
            rrca
            rrca
            and 3
            or l
            ld l, a
            ld h, high(OWN)
            ld b, [hl]
            ld a, e
            and 7
            jr z, .ob
.os:        rrc b
            dec a
            jr nz, .os
.ob:        pop hl
            bit 0, b
            jr z, .o0
            ld a, h
            add a, 4
            ld h, a
.o0:        ld a, [hl]
            bit 1, d
            jr z, .t
            swap a
.t:         bit 1, e
            jr z, .l
            rrca
            rrca
.l:         and 3
            add a, low(SGB_CNT)
            ld l, a
            ld h, high(SGB_CNT)
            ld a, [hl]
            add a, 4
            jr nc, .ns
            ld a, 255
.ns:        ld [hl], a
            pop bc
.cn:        ld a, e
            inc a
            and 31
            ld e, a
            dec b
            jr nz, .c
            pop bc
.rn:        ld a, d
            inc a
            cp 30
            jr c, .rw
            xor a
.rw:        ld d, a
            dec b
            jr nz, .r
            ret

; A = the pending bits of the ATTR packets (2 .. 1 + sgb_nattr)
attr_mask:  push bc
            ldh a, [sgb_nattr]
            ld b, a
            xor a
.l:         scf
            rla
            dec b
            jr nz, .l
            add a, a
            add a, a
            pop bc
            ret

; per-cell palettes (GRID) -> ATTR_BLK packets 2.. of NEXT: the whole screen in the most
; common palette, then rectangles of equal palette, greedy (rows first). Carry: more
; than 15 rectangles (ATTR_CHR stays). RAM bank 2 on.
sgb_rects:  push bc
            push de
            push hl
            ld hl, SGB_CNT                  ; most common palette -> sgb_rb
            ld bc, 0
            ld e, 0
.bm:        ld a, [hl+]
            cp b
            jr c, .bn
            jr z, .bn
            ld b, a
            ld c, e
.bn:        inc e
            ld a, e
            cp 4
            jr nz, .bm
            ld a, c
            ldh [sgb_rb], a
            ld hl, SGB_GRID                 ; COVER = cells of that palette
            ld bc, 360
.cv:        ldh a, [sgb_rb]
            ld e, a
            ld a, [hl]
            cp e
            ld a, 0
            jr nz, .c0
            inc a
.c0:        inc h
            inc h
            ld [hl], a
            dec h
            dec h
            inc hl
            dec bc
            ld a, b
            or c
            jr nz, .cv
            ld hl, SGB_SETS                 ; set 0: everything in that palette
            ld a, 7
            ld [hl+], a
            ldh a, [sgb_rb]
            ld b, a
            add a, a
            add a, a
            or b
            add a, a
            add a, a
            or b
            ld [hl+], a
            xor a
            ld [hl+], a
            ld [hl+], a
            ld a, 19
            ld [hl+], a
            ld a, 17
            ld [hl], a
            ld a, 1
            ldh [sgb_ns], a
            ld d, 0                         ; scan for cells not covered
.y:         ld e, 0
.x:         call .addr
            inc h
            inc h
            ld a, [hl]
            and a
            jr nz, .nx
            call .rect
            jr c, .x9
.nx:        inc e
            ld a, e
            cp 20
            jr nz, .x
            inc d
            ld a, d
            cp 18
            jr nz, .y
            ld hl, SGB_NEXT + 32            ; the packets: clear, header, sets
            ld b, 96
            xor a
.cl:        ld [hl+], a
            dec b
            jr nz, .cl
            ldh a, [sgb_ns]
            ld c, a
            add a, a
            add a, c
            add a, a                        ; 6n
            ld b, a
            add a, 2 + 15
            swap a
            and $0F                         ; packets
            ldh [sgb_nattr], a
            ld hl, SGB_NEXT + 32
            or $20
            ld [hl+], a
            ld a, c
            ld [hl+], a
            ld de, SGB_SETS
.cp:        ld a, [de]
            inc de
            ld [hl+], a
            dec b
            jr nz, .cp
            and a
.x9:        pop hl
            pop de
            pop bc
            ret
.addr:      push bc                         ; D = row, E = column -> HL = GRID cell
            ld h, 0
            ld l, d
            add hl, hl
            add hl, hl
            ld b, h
            ld c, l
            add hl, hl
            add hl, hl
            add hl, bc
            ld b, 0
            ld c, e
            add hl, bc
            ld bc, SGB_GRID
            add hl, bc
            pop bc
            ret
.same:      ld a, [hl]                      ; Z: cell HL has palette sgb_rp, not covered
            push bc
            ld b, a
            ldh a, [sgb_rp]
            cp b
            pop bc
            ret nz
            inc h
            inc h
            ld a, [hl]
            dec h
            dec h
            and a
            ret
.rect:      push de                         ; rectangle from row D, column E -> set
            call .addr
            ld a, [hl]
            ldh [sgb_rp], a
            ld b, e                         ; right
.ex:        ld a, b
            cp 19
            jr z, .exd
            inc hl
            call .same
            jr nz, .exd
            inc b
            jr .ex
.exd:       ld a, b
            ldh [sgb_rx1], a
            ld c, d                         ; down
.ey:        ld a, c
            cp 17
            jr z, .eyd
            push de
            ld d, c
            inc d
            call .addr
            pop de
            ld a, b
            sub e
            inc a
            push bc
            ld b, a
.er:        call .same
            jr nz, .erf
            inc hl
            dec b
            jr nz, .er
            pop bc
            inc c
            jr .ey
.erf:       pop bc
.eyd:       ld a, c
            ldh [sgb_ry1], a
            ld a, d                         ; cover it
            ldh [sgb_ty], a
.mk:        push de
            ldh a, [sgb_ty]
            ld d, a
            call .addr
            pop de
            ldh a, [sgb_rx1]
            sub e
            inc a
            ld b, a
.mc:        inc h
            inc h
            ld [hl], 1
            dec h
            dec h
            inc hl
            dec b
            jr nz, .mc
            ldh a, [sgb_ty]
            ld c, a
            ldh a, [sgb_ry1]
            cp c
            jr z, .mkd
            ld a, c
            inc a
            ldh [sgb_ty], a
            jr .mk
.mkd:       ldh a, [sgb_ns]                 ; the data set
            cp 15
            jr z, .ovf
            ld c, a
            inc a
            ldh [sgb_ns], a
            ld a, c
            add a, a
            add a, c
            add a, a
            add a, low(SGB_SETS)
            ld l, a
            ld h, high(SGB_SETS)
            ld a, 3                         ; inside + border
            ld [hl+], a
            ldh a, [sgb_rp]
            ld b, a
            add a, a
            add a, a
            or b
            ld [hl+], a
            ld a, e
            ld [hl+], a
            ld a, d
            ld [hl+], a
            ldh a, [sgb_rx1]
            ld [hl+], a
            ldh a, [sgb_ry1]
            ld [hl], a
            pop de
            and a
            ret
.ovf:       pop de
            scf
            ret

