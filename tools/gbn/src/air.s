; FF1 native engine: the airship's view (owner, 2026-11-24: the approved mock-up). While the
; airship flies, the map above the ship's line (screen lines 0-63) is drawn in perspective: each
; line's SCY moves its picture further up the map, more for the lines nearer the top, as a
; ground seen from above leaning away; above the horizon a sky band (the window). Taking off
; and landing blend it in and out with the ship's height (33 levels, build.py ap_source: the
; mock-up's curve). A mode-0 STAT interrupt per line writes the next line's SCY (and the sky's
; colour on the Color, the sky's shade and a haze under the horizon on a plain Game Boy, BGP);
; after line 63 the STAT interrupt is the field's usual one. The map streamer keeps rows py-10 ..
; py+5 while flying (the lines near the horizon show rows up to ten above the party).
AP_YC      = 64             ; the ship's line: the perspective above it
AP_TAB     = $6600          ; (bank F3_BANK) 33 levels x 64 offsets, then 33 horizons, the sky
AP_HZ      = AP_TAB + 33 * 64
AP_SKY     = AP_HZ + 33
AP_FOG     = 8              ; (DMG: the haze's lines under the horizon)

section bank 0, $3E80                       ; (bank 0: the STAT and V-Blank parts, the streamer's)
; draw_edge: the rows of a column entering the view (D = first, B = count)
ap_hrows:   ld a, [vehicle]
            cp V_AIR
            ld a, [py]
            jr z, .a
            sub 6
            ld d, a
            ld b, 13
            ret
.a:         sub 10
            ld d, a
            ld b, 16
            ret
; draw_edge: the row to draw above (B, from py): one beyond the row entering (-6); flying, the
; perspective shows rows py - 10 .. + 5, the whole ring: the entering one (-11)
ap_up:      ld a, [vehicle]
            cp V_AIR
            ld b, $FA
            ret nz
            ld b, $F5
            ret

; the field's frame (main loop, air_frame): the view's level from the airship's height; on / off
ap_tick:    ldh a, [maptype]                ; (the overworld only: maptype 1)
            dec a
            jr nz, .off
            ld a, [vehicle]
            cp V_AIR
            jr nz, .off
            ld a, [air_y]                   ; (taking off / landing: the height; else flying)
            and a
            ld a, 32
            jr z, .k
            ld a, [air_y]
            ld b, a
            ld a, $6F - $1C
            sub b
            jr nc, .k0
            xor a
.k0:        cp 33
            jr c, .k
            ld a, 32
.k:         ld [ap_kn], a
            ld a, F3_BANK
            ld hl, ap_frame
            jp bank_call
.off:       ld a, [ap_on]
            and a
            ret z
            call ap_stop
            ldh a, [maptype]                ; (landed: the row under the view again, py + 5)
            dec a
            ret nz
            jp ap_row5
; off now (a menu opens): V-Blank puts the display back
ap_stop:    push hl                         ; (HL kept: pc_menu's routine. The SGB packet
            call sgb_amb0                   ;   clobbered it, and opening a shop or the menu
            pop hl                          ;   with the ambience on jumped into RAM: crash)
            ld a, [ap_on]
            and a
            ret z
            xor a
            ld [ap_on], a
            inc a
            ld [ap_rest], a
            ret
; (bank 0: q_mt maps the map's bank and leaves it so)
; the row py + 5 queued (landed: the field's view needs it again)
ap_row5:    ld a, [py]
            add a, 5
            ld d, a
            ld b, 1
            jr ap_rows.g
; the rows py - 10 .. py - 6 (13 metatiles each) queued
ap_rows:    ld a, [py]
            sub 10
            ld d, a
            ld b, 5
.g:         ldh a, [rombank]                ; (the bank mapped kept: q_mt maps the map's)
            push af
            call .r0
            pop af
            jp sbank
.r0:
.r:         push bc
            ld a, [px]
            sub 6
            ld e, a
            ld b, 13
.c:         push bc
            push de
            call q_mt
            pop de
            pop bc
            inc e
            dec b
            jr nz, .c
            pop bc
            inc d
            dec b
            jr nz, .r
            ret


section bank 0, $3150                       ; (bank 0 continued)
; V-Blank (after the window's own handling): the frame's first line, the per-line interrupt
ap_vbl:     ld a, [ap_rest]
            and a
            jr nz, .rest
            ld a, [ap_on]
            and a
            ret z
            xor a
            ld [ap_done], a
            ldh a, [scy]
            ld [ap_scy0], a
            ld hl, ap_off
            sub [hl]
            ldh [rSCY], a
            ld a, [ap_scy0]                 ; (line 1's values ready)
            inc l
            sub [hl]
            ld [ap_ns], a
            ld a, [ap_bgpt + 1]
            ld [ap_nb], a
            ld a, [ap_hz]                   ; the sky band: the window from line 0
            and a
            jr z, .nw
            xor a
            ldh [rWY], a
            ld a, 7
            ldh [rWX], a
            ldh a, [rLCDC]
            or $60
            ldh [rLCDC], a
            ldh a, [is_cgb]
            and a
            jr z, .nw
            ld hl, ap_sky
            call ap_p7
            call ap_wattr                   ; (the window's cells: palette 7, a row a frame)
.nw:        ldh a, [is_cgb]
            and a
            jr nz, .s
            ld a, [ap_bgpt]
            ldh [rBGP], a
.s:         ld a, $08                       ; STAT: mode 0 each line
            ldh [rSTAT], a
            ldh a, [rIF]
            and $FD
            ldh [rIF], a
            ei                              ; (the rest of V-Blank's work, the map's queued
            ret                             ;   writes, may run into the first lines: their
                                            ;   interrupts must not wait for it)
.rest:      xor a                           ; off: the field's STAT, the window, the colours
            ld [ap_rest], a
            ld a, $40
            ldh [rSTAT], a
            ld a, BOX_LINES - 1
            ldh [rLYC], a
            ld a, [lcdc_on]
            ldh [rLCDC], a
            ldh a, [is_cgb]
            and a
            jr z, .rd
            jp ap_p7w
.rd:        ld a, [ap_bgp0]
            ldh [rBGP], a
            ret
section bank 0, $3530                       ; (bank 0 continued)
; Color: the window's rows 0-3 in palette 7 (its four colours are the sky's), one per V-Blank
ap_wattr:   ld a, [ap_wrow]
            cp 4
            ret nc
            inc a
            ld [ap_wrow], a
            dec a
            swap a
            add a, a                        ; 32 row
            ld l, a
            ld h, $9C
            ld a, 1
            ldh [rVBK], a
            ld a, WIN_ATTR
            ld b, 20
.c:         ld [hl+], a
            dec b
            jr nz, .c
            xor a
            ldh [rVBK], a
            ret
; CGB palette 7's four colours = the colour at HL (the sky line's)
ap_p7:      ld a, $B8
            ldh [rBCPS], a
            ld a, [hl+]
            ld c, a
            ld b, [hl]
            ld a, c
            ldh [rBCPD], a
            ld a, b
            ldh [rBCPD], a
            ld a, c
            ldh [rBCPD], a
            ld a, b
            ldh [rBCPD], a
            ld a, c
            ldh [rBCPD], a
            ld a, b
            ldh [rBCPD], a
            ld a, c
            ldh [rBCPD], a
            ld a, b
            ldh [rBCPD], a
            ret
; CGB palette 7 back to the windows' colours
ap_p7w:     ld a, $B8
            ldh [rBCPS], a
            ld hl, win_pal
            ld b, 8
.c:         ld a, [hl+]
            ldh [rBCPD], a
            dec b
            jr nz, .c
            ret
section bank 0, $3B10                       ; (bank 0 continued)
; STAT mode 0 at the end of line LY: line LY + 1's SCY (and DMG BGP) first, from values ready
; (written early in the blanking, before the line draws); then its sky / horizon work and the
; values for the line after
stat_ap:    ld a, [ap_ns]
            ldh [rSCY], a
            ldh a, [is_cgb]
            and a
            jr nz, .c0
            ld a, [ap_nb]
            ldh [rBGP], a
.c0:        push hl
            push bc
            ldh a, [rLY]
            inc a
            cp AP_YC
            jr nc, .end
            ld l, a
            ld h, high(ap_off)
            ld a, [ap_hz]
            cp l
            jr z, .hz
            jr c, .nx
            ldh a, [is_cgb]                 ; a sky line (Color): its colour
            and a
            jr z, .nx
            push hl
            ld a, l
            add a, a
            add a, low(ap_sky)
            ld l, a
            call ap_p7
            pop hl
            jr .nx
.hz:        ld a, [lcdc_on]                 ; the horizon: the window off, palette 7 back
            ldh [rLCDC], a
            ldh a, [is_cgb]
            and a
            jr z, .nx
            push hl
            call ap_p7w
            pop hl
.nx:        inc l                           ; the next line's values
            ld a, l
            cp AP_YC
            jr nc, .last
            ld a, [ap_scy0]
            sub [hl]
            ld [ap_ns], a
            set 6, l
            ld a, [hl]
            ld [ap_nb], a
            jr .x
.last:      ld a, [ap_scy0]
            ld [ap_ns], a
            ld a, [ap_bgp0]
            ld [ap_nb], a
.x:         pop bc
            pop hl
            pop af
            reti
.end:       ld a, 1                         ; the field's STAT interrupt from here (the music's
            ld [ap_done], a                 ;   line)
            ld a, $40
            ldh [rSTAT], a
            ld a, 100
            ldh [rLYC], a
            ldh a, [rIF]
            and $FD
            ldh [rIF], a
            pop bc
            pop hl
            ld a, [mus_pend]                ; (a music tick held for this line: text.s)
            and a
            jr z, .mx
            dec a
            ld [mus_pend], a
            call mus_tick
.mx:        pop af
            reti

; ---- (bank F3_BANK) the frame's work: the level's offsets and sky; the rows above the view
section bank 99, $6EC0
ap_frame:   ld a, [ap_on]
            and a
            jr nz, .on
            ld a, 1                         ; switched on: the rows the view now needs (py - 10 ..
            ld [ap_on], a                   ;   py - 6), the sky's colours, the level redone
            ld a, $FF
            ld [ap_k], a
            xor a
            ld [ap_wrow], a
            call ap_rows
            ld hl, AP_SKY
            ld de, ap_sky
            ld bc, 64
            call memcpy
            ld hl, ap_sky                   ; (the LCD colour mode: cc.s)
            ld b, 64
            call cc_inpl
            ld a, %11100100                 ; (DMG: the overworld's BGP: its tiles are shades;
            ld [ap_bgp0], a                 ;   fades stop the view first)
.on:
.c:         ld a, [ap_kn]
            ld hl, ap_k
            cp [hl]
            jr z, .hide
            ld [hl], a
            ld l, a                         ; the level's 64 offsets and its horizon
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, AP_TAB
            add hl, de
            ld de, ap_off
            ld bc, 64
            call memcpy
            ld a, [ap_k]
            ld e, a
            ld d, 0
            ld hl, AP_HZ
            add hl, de
            ld a, [hl]
            ld [ap_hz], a
            ldh a, [is_cgb]
            and a
            call z, ap_bgps
.hide:      ld hl, oam_buf + 16             ; (the other sprites above the ship's line hidden:
            ld b, 36                        ;   the bridge, the canal, the ship)
.o:         ld a, [hl]
            cp AP_YC + 16
            jr nc, .on2
            ld [hl], 0
.on2:       inc l
            inc l
            inc l
            inc l
            dec b
            jr nz, .o
            ret
; DMG: each line's BGP: the sky light grey then white (the window), the haze (a shade lighter)
; under the horizon, the game's own after
ap_bgps:    ld hl, ap_bgpt
            ld a, [ap_bgp0]                 ; the haze: each shade one lighter
            ld c, a
            ld b, 4
            ld e, 0
.h:         ld a, c
            and 3
            jr z, .h0
            dec a
.h0:        rrc e
            rrc e
            or e
            ld e, a
            srl c
            srl c
            dec b
            jr nz, .h
            rrc e
            rrc e
            ld a, [ap_hz]
            ld d, a
            ld c, 0
.l:         ld a, c
            cp d
            jr nc, .g
            cp 14
            ld a, $55
            jr c, .w
            xor a
            jr .w
.g:         sub d
            cp AP_FOG
            ld a, e
            jr c, .w
            ld a, [ap_bgp0]
.w:         ld [hl+], a
            inc c
            ld a, c
            cp 64
            jr c, .l
            ret
section wram, $DC00
ap_off:     ds 64                           ; the level's SCY offsets by line (page-aligned)
ap_bgpt:    ds 64                           ; (DMG) BGP by line
ap_sky:     ds 64                           ; (Color) the sky's colour by line
                                            ; (the tables share the battle's tile stage: they
                                            ;   are made again whenever the view comes on; the
                                            ;   flags below must not: free bytes)
section wram, $DAD6
ap_on:      ds 1
ap_rest:    ds 1
ap_done:    ds 1
ap_k:       ds 1
ap_kn:      ds 1
ap_hz:      ds 1
ap_scy0:    ds 1
ap_bgp0:    ds 1
ap_wrow:    ds 1
ap_ns:      ds 1                            ; the next line's SCY, BGP
section wram, $DAC9
ap_nb:      ds 1
