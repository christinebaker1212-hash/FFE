; Super Game Boy: detection, packets, colour palettes and the screen attribute map.
; Runs in DMG mode on top of the DMG shading (rt/dmg_shade.s): a BG pixel's 2-bit value is
; its brightness group (0 = backdrop, 1-3 darkest .. brightest), and on the SGB the BGP
; passes the value through as the colour number (minus the fade), so SGB palette p colour v
; is the NES colour of BG palette p that has value v. Sprites use the colours of the cell
; they are in (SGB hardware): OBP0 = 0 / 1 / 3, OBP1 = 1 / 2 / 3.
; Static screens: each 8x8 screen cell gets the SGB palette of its NES attribute (ATTR_CHR).
; Screens that scroll (field, towns, dungeons) get one palette for the whole screen
; (ATTR_BLK), its colours taken from the palette most cells on screen use.
; Packets are built in cart RAM bank 2 (NEXT = the state wanted, SENT = what the SGB has)
; and sent one at a time, SGB_GAP frames apart, from the frame wait.
;   packets 0 PAL01, 1 PAL23, 2.. ATTR_BLK (1) or ATTR_CHR (6)

SGB_NEXT   = $A000          ; cart RAM bank 2: 8 packets
SGB_SENT   = $A080          ; cart RAM bank 2: 8 packets as last sent
SGB_GAP    = 4              ; frames between packets

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
            ldh a, [sgb_pend]
            and a
            jr nz, .send
            ldh a, [sgb_dirty]
            and a
            jr z, .x
            call sgb_build
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
            ld a, 2
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
.x:         pop hl
            pop de
            pop bc
            ret

; ---- NEXT from the current palettes and map; sgb_pend = the packets that differ from SENT
sgb_build:  xor a
            ldh [sgb_dirty], a
            ld a, 2
            ld [$4000], a
            ld hl, SGB_NEXT                 ; clear NEXT
            ld b, 128
            xor a
.cl:        ld [hl+], a
            dec b
            jr nz, .cl
            call sgb_counts                 ; cells per palette on screen; per-cell palettes
            ldh a, [sgb_glob]               ;   -> the ATTR packets
            and a
            jr nz, .glob
            ld hl, SGB_NEXT                 ; PAL01, PAL23 from the four NES BG palettes
            ld a, $01
            ld [hl+], a
            call bk_rgb
            ld c, 0
            call pal_rgb
            ld c, 1
            call pal_rgb
            ld hl, SGB_NEXT + 16
            ld a, $09
            ld [hl+], a
            call bk_rgb
            ld c, 2
            call pal_rgb
            ld c, 3
            call pal_rgb
            jr .cmp
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
            ld c, 2                         ; ATTR_CHR: all six if any differs
.d3:        call pk_diff
            jr nz, .chr
            inc c
            ld a, c
            cp 8
            jr nz, .d3
            jr .dn
.chr:       ld a, b
            or $FC
            ld b, a
.dn:        ldh a, [sgb_force]              ; (everything after detection / a mode change;
            ld c, a                         ;   one palette: PAL01 and ATTR_BLK only)
            ldh a, [sgb_glob]
            and a
            ld a, c
            jr z, .fa
            and $03
.fa:        or b
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
            xor a                           ; owner of the cell
            ldh [sh_nt], a
            ldh a, [own1_lo]
            ld b, a
            ldh a, [own1_hi]
            or b
            jr z, .o0
            call own_chk
            and a
            jr z, .o0
            ld a, 4
            ldh [sh_nt], a
.o0:        ld a, d
            call cell_pal
            ld c, a
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
            ld b, 0                         ; OBP0: values 1 / 2 / 3 -> colours 0 / 1 / 3
            ld e, 1
            ld d, 3
            call .mk
            ldh [obp0_v], a
            ld b, 1                         ; OBP1: 1 / 2 / 3
            ld e, 2
            ld d, 3
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
            ld a, 1
            ldh [sgb_dirty], a
.x:         pop bc
            ret

; LCD going off: static screens again (per-cell palettes)
sgb_lcd_off:
            ldh a, [sgb_glob]
            and a
            ret z
            xor a
            ldh [sgb_glob], a
            ld a, $FF
            ldh [sgb_force], a
            ldh [sgb_dirty], a
            ret
