; FF1 native engine: the airship's view (owner, 2026-11-24; 2026-11-26: the whole world slanted,
; one even tilt, no horizon). While the airship flies, every screen line's SCY is set so the
; ground is foreshortened by the same ratio on every line, around the ship's line (64, 1:1): the
; lines above show the ground further ahead, the lines below further behind, as a flat world seen
; at a slant. Taking off and landing blend it in and out with the ship's height (33 levels,
; build.py ap_source). The offset changes on only some lines (about 2 in 5): an LY = LYC STAT
; interrupt on the line before each writes the new SCY in its H-Blank (the plain Game Boy's
; time: one interrupt a line took half of every line); after the last the STAT interrupt is
; the field's usual one. The map streamer keeps the rows
; py - 7 .. py + 8 while flying (the whole 16-row ring: the top line shows up to 90 pixels ahead
; of the ship's, the bottom one 112 behind).
AP_YC      = 64             ; the ship's line: 1:1 there
AP_BANK    = 114            ; (build.py ap_source) AP_TAB: 33 levels' lists, 256 bytes apart

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
.a:         sub 7
            ld d, a
            ld b, 16
            ret
; draw_edge: the row to draw above (B, from py before the step): one beyond the row entering
; (-6); flying, the view keeps rows py - 7 .. + 8, the whole ring: the new top one (-8)
ap_up:      ld a, [vehicle]
            cp V_AIR
            ld b, $FA
            ret nz
            ld b, $F8
            ret
; draw_edge: the row to draw below (B, from py before the step): py + 6; flying the ring's new
; bottom one, py + 9
ap_dn:      ld a, [vehicle]
            cp V_AIR
            ld b, 6
            ret nz
            ld b, 9
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
            jp ap_stop                      ; (landed: the field's rows py - 6 .. + 6 are in
                                            ;   the flying ring py - 7 .. + 8 already)
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
; switched on: the rows the flying ring adds to the field's (py - 6 .. + 6, its edges possibly
; a step behind): py - 7, py - 6 and py + 6 .. + 8, queued (13 metatiles each)
ap_rows:    ld a, [py]
            sub 7
            ld d, a
            ld b, 2
            call .g
            ld a, [py]
            add a, 6
            ld d, a
            ld b, 3
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
; V-Blank: the frame's first line, the per-line interrupt
ap_vbl:     ld a, [ap_rest]
            and a
            jr nz, .rest
            ld a, [ap_on]
            and a
            ret z
            ldh a, [scy]
            ld [ap_scy0], a
            ld hl, ap_lst                   ; line 0's offset
            sub [hl]
            ldh [rSCY], a
            inc l
            ld a, [hl+]                     ; the first change's line - 1
            cp $FF
            jr z, .flat
            ldh [rLYC], a
            ld a, l
            ld [ap_ix], a
            xor a
            ld [ap_done], a
            ld a, $40                       ; STAT: LY = LYC
            ldh [rSTAT], a
            ldh a, [rIF]
            and $FD
            ldh [rIF], a
            ei                              ; (the rest of V-Blank's work, the map's queued
            ret                             ;   writes, may run into the first lines: their
                                            ;   interrupts must not wait for it)
.flat:      ld a, 1                         ; (on the ground: no change, the field's STAT)
            ld [ap_done], a
            ret
.rest:      xor a                           ; off: the field's STAT
            ld [ap_rest], a
            ld a, $40
            ldh [rSTAT], a
            ld a, BOX_LINES - 1
            ldh [rLYC], a
            ret
section bank 0, $3B10                       ; (bank 0 continued)
; STAT LY = LYC at the start of the line before a change: the new SCY written in this line's
; H-Blank (waited for: the line drawn first), then LYC at the next change
stat_ap:    push hl
            push bc
            ld a, [ap_ix]                   ; HL = this change's offset
            ld l, a
            ld h, high(ap_lst)
            ld a, [ap_scy0]
            sub [hl]
            ld b, a
            inc l
            ld c, low(rSTAT)
.w:         ldh a, [c]                      ; (this line's H-Blank)
            and 3
            jr nz, .w
            ld a, b
            ldh [rSCY], a
            ld a, [hl+]                     ; the next change's line - 1 ($FF: none)
            ldh [rLYC], a
            inc a
            jr z, .end
            ld a, l
            ld [ap_ix], a
            pop bc
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

; ---- (bank F3_BANK) the frame's work: the level's offsets; the rows the ring adds
section bank 99, $6600                      ; (the view's tables moved to AP_BANK: their room)
ap_frame:   ld a, [ap_on]
            and a
            jr nz, .on
            ld a, 1                         ; switched on: the rows the view now needs, the
            ld [ap_on], a                   ;   level redone
            ld a, $FF
            ld [ap_k], a
            call ap_rows
.on:        ld a, [ap_kn]
            ld hl, ap_k
            cp [hl]
            jr z, .hide
            ld [hl], a
            add a, high(AP_TAB)             ; the level's list (256 bytes apart; up to 128)
            ld h, a
            ld l, 0
            ld de, ap_lst
            ld bc, 128
            ld a, AP_BANK
            call far_copy
.hide:      ld hl, oam_buf + 16             ; (the other sprites, off the ship's lines,
            ld b, 36                        ;   hidden: the bridge, the canal, the parked ship
.o:         ld a, [hl]                      ;   would not follow the slant)
            cp AP_YC + 16
            jr c, .hd
            cp AP_YC + 16 + 24              ; (the ship and its shadow)
            jr c, .on2
.hd:        ld [hl], 0
.on2:       inc l
            inc l
            inc l
            inc l
            dec b
            jr nz, .o
            ret
section wram, $DC00
ap_lst:     ds 128                          ; the level's list: line 0's offset, then (line - 1,
                                            ;   offset) per change, $FF (page-aligned;
                                            ;   the battle's tile stage and the reflection's
                                            ;   work page, neither used in the air: refl.s
                                            ;   starts again after a gap in its frames)
                                            ; (made again whenever the view comes on; the
                                            ;   flags below must not: free bytes)
section wram, $DAD6
ap_on:      ds 1
ap_rest:    ds 1
ap_done:    ds 1
ap_k:       ds 1
ap_kn:      ds 1
ap_scy0:    ds 1
ap_ix:      ds 1                            ; the next change's offset (low byte in ap_lst)
