; FF1 native engine: tall maps (owner, 2026-11-26: "all Twelve Sages at once"; owner chose taller
; sprites). A map with more than 9 people in one view (data.tall_maps: Crescent Lake, map 4) keeps
; its people as top / bottom tile pairs (data.tall_pairs: 12 pairs, 24 tiles a picture; the party's
; made here from its 16 tiles, after them at tiles 16-39) and, in a frame with more people in view
; than the 8 x 8 budget, draws them as 8 x 16 sprites: 2 OAM entries a person. Other frames stay
; 8 x 8 (the same pairs; the party from its own 16 tiles), so the reflection on water works as
; everywhere; a frame drawn 8 x 16 has no reflection. FF1 colours a person's top with one sprite
; palette and its bottom with another; an 8 x 16 sprite has one, so on the Color the 8 x 16 frames
; use palettes 4 (party) and 6 (people), copies of 0 / 2 made in V-Blank, and a line handler writes
; colour 2 at each band edge: people stand on the 16-pixel grid, so their tops and bottoms fall in
; 8-line bands; the party's at line 72. The plain Game Boy / SGB: one shade set, nothing to change.
TALL_BANK  = 113
TL_OBJ     = $DE80          ; tall_oam: the people in view (OAM y, x, frame x 8, tile base) x 15
                            ;   (the shop's buffer: free on the field)
section wram, $CCDA
tl_map:     ds 1                            ; 1: this map is tall
tl_lc:      ds 1                            ; 4: this frame's OAM is 8 x 16 (V-Blank: LCDC bit 2)
tl_no:      ds 1                            ; the line handler: the next band edge (LYC), the
tl_os:      ds 1                            ;   colour it writes (0 top, 1 bottom), the party's
tl_pd:      ds 1                            ;   bottom written
tl_pb:      ds 2                            ; colours 2: the party's bottom, people's top / bottom
tl_ot:      ds 2
tl_ob:      ds 2
tl_n:       ds 1                            ; people in view
tl_f8:      ds 1                            ; 1: 8 x 8 this frame (a load)
tl_sh:      ds 1                            ; tl_pgen: the source tiles' page
tl_cut:     ds 1
tl_md:      ds 1                            ; tall_oam: this frame's mode (0 / 4)
tl_hold:    ds 1                            ; 1: Select's copy (ps_next): V-Blank's palette work held

section hram, $FF9A
tl_mt:      ds 1                            ; make_oam: 0 standard map, 1 overworld, 2 tall map
tl_ras:     ds 1                            ; 1: the line handler's band edges this frame

section bank 113, $4000
; ---- a map's load (wa_load): tall or not, from the map bank's flag (M_OBJBLK + 17)
tl_set:     ldh a, [tl_ras]                 ; (the line handler off, the cut's line back)
            and a
            jr z, .r
            ld a, BOX_LINES - 1
            ldh [rLYC], a
.r:         xor a
            ld [tl_lc], a
            ldh [tl_ras], a
            ld a, [lcdc_on]                 ; (8 x 8 again)
            and $FB
            ld [lcdc_on], a
            ldh a, [maptype]
            and a
            ld a, 1
            jr nz, .s
            ld a, [map_bank]
            ld [fc_bank], a
            ld hl, M_OBJBLK + 17
            call far_byte
            and a
            jr z, .s
            ld a, 2
.s:         ldh [tl_mt], a
            cp 2
            ld a, 0
            jr nz, .m
            inc a
.m:         ld [tl_map], a
            ret

; ---- make_oam on a tall map (mo_hook): the party and its people, 8 x 8 or 8 x 16
tall_oam:   call lcd_get                    ; (a load: the party's pairs made from its tiles,
            bit 7, a                        ;   and 8 x 8: the LCD comes on with LCDC_ON)
            ld a, 0
            jr nz, .on
            call tl_pair
            ld a, 1
.on:        ld [tl_f8], a
            call tl_scan
            ld a, [box_on]                  ; (the box / banner: their cut and handlers; 8 x 8)
            ld b, a
            ld a, [bn_t]
            or b
            ld b, a
            ld a, [wp_on]
            or b
            ld b, a
            ld a, [tl_f8]
            or b
            ld b, a
            ld a, [refl_lv]                 ; (the reflection showing: 8 x 8)
            or b
            jr nz, .s8
            ld a, [rf_want]                 ; more than the 8 x 8 budget in view: 8 x 16
            xor MAX_DRAWN
            ld b, a
            ld a, [tl_n]
            cp b
            jr z, .s8
            jr c, .s8
            ld a, 4
            jr .sm
.s8:        xor a
.sm:        ld [tl_md], a
            call lcd_get                    ; (a late frame, LCD on: the last OAM stands)
            bit 7, a
            jr z, .go
            ldh a, [rLY]
            cp 120
            jr c, .go
            cp 144
            ret c
.go:        ld de, oam_buf
            ld a, [facing]                  ; the party: its frame
            add a, a
            ld b, a
            ld a, [mcount]
            and 8
            jr z, .f0
            inc b
.f0:        ld a, [tl_md]
            and a
            jr nz, .p16
            ld a, b                         ; 8 x 8: FF1's table, tiles 0-15, palettes 0 / 1
            add a, a
            add a, a
            add a, a
            ld l, a
            ld h, high(TL_PT8)
            ld bc, $5050
            call tl_one8
            ld b, $58
            call tl_one8
            ld bc, $5058
            call tl_one8
            ld b, $58
            call tl_one8
            jr .ob
.p16:       ld a, b                         ; 8 x 16: the pairs, palette 4
            add a, a
            add a, a
            ld l, a
            ld h, high(TL_PT16)
            ld bc, $5050
            ld a, 4
            ld [tl_cut], a
            call tl_one16
            ld c, $58
            call tl_one16
.ob:        ld a, [tl_n]                    ; the people
            and a
            jr z, .rest
            ld b, a
            ld a, [tl_md]
            and a
            jr nz, .o16
            ld a, [rf_want]                 ; (8 x 8: at most the budget)
            xor MAX_DRAWN
            cp b
            jr nc, .o8
            ld b, a
.o8:        ld hl, TL_OBJ
.o8l:       push bc
            ld a, [hl+]                     ; y, x, frame x 8, base
            ld b, a
            ld a, [hl+]
            ld c, a
            ld a, [hl+]
            ld [tl_f8], a
            ld a, [hl+]
            ld [tl_cut], a
            push hl
            ld a, [tl_f8]
            ld l, a
            ld h, high(TL_OT8)
            call tl_ob8
            pop hl
            pop bc
            dec b
            jr nz, .o8l
            jr .rest
.o16:       ld hl, TL_OBJ
.o6l:       push bc
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld c, a
            ld a, [hl+]
            srl a                           ; (frame x 4)
            ld [tl_f8], a
            ld a, [hl+]
            ld [tl_cut], a
            push hl
            ld a, [tl_f8]
            ld l, a
            ld h, high(TL_OT16)
            call tl_ob16
            pop hl
            pop bc
            dec b
            jr nz, .o6l
.rest:      ld a, e                         ; the rest hidden
            cp 160
            jr nc, .x
            xor a
            ld [de], a
            inc de
            inc de
            inc de
            inc de
            jr .rest
.x:         ld a, [tl_md]
            ld [tl_lc], a
            ret

; HL = table entry (tile, NES attribute), B = OAM y, C = x, DE = OAM: one 8 x 8 entry, its
; palette 0-3 (HL + 2 after)
tl_one8:    ld a, b
            ld [de], a
            inc de
            ld a, c
            ld [de], a
            inc de
            ld a, [hl+]
            ld [de], a
            inc de
            ld a, [hl+]
            call tl_attr
            ld [de], a
            inc de
            ret
; NES attribute A -> GB: flip bit 6 -> 5, the palette (bits 0-1)
tl_attr:    push bc
            ld b, a
            and $40
            rrca
            ld c, a
            ld a, b
            and 3
            or c
            pop bc
            ret
; HL = 8 x 16 table entry (2 pair, NES attribute), B = y, C = x, tl_cut = the palette (4 / 6),
; DE = OAM (HL + 2 after); A on entry for tl_ob16's base
tl_one16:   ld a, b
            ld [de], a
            inc de
            ld a, c
            ld [de], a
            inc de
            ld a, [hl+]
            ld [de], a
            inc de
tl_a16:     ld a, [hl+]
            and $40
            rrca
            push bc
            ld b, a
            ld a, [tl_cut]
            or b
            pop bc
            ld [de], a
            inc de
            ret
; a person 8 x 8: HL = its frame in TL_OT8, B = y, C = x, tl_cut = its tile base: UL, DL, UR, DR
tl_ob8:     call .e
            ld a, b
            add a, 8
            ld b, a
            call .e
            ld a, b
            sub 8
            ld b, a
            ld a, c
            add a, 8
            ld c, a
            call .e
            ld a, b
            add a, 8
            ld b, a
.e:         ld a, b
            ld [de], a
            inc de
            ld a, c
            ld [de], a
            inc de
            ld a, [tl_cut]
            add a, [hl]
            inc hl
            ld [de], a
            inc de
            ld a, [hl+]
            call tl_attr
            ld [de], a
            inc de
            ret
; a person 8 x 16: HL = its frame in TL_OT16, B = y, C = x, tl_cut = its base: two columns, palette 6
tl_ob16:    call .e
            ld a, c
            add a, 8
            ld c, a
.e:         ld a, b
            ld [de], a
            inc de
            ld a, c
            ld [de], a
            inc de
            ld a, [tl_cut]
            add a, [hl]
            inc hl
            ld [de], a
            inc de
            ld a, [hl+]
            and $40
            rrca
            or 6
            ld [de], a
            inc de
            ret

; the people in view (as obj_spr places them; not in another room, not under the box / banner):
; TL_OBJ, tl_n
tl_scan:    xor a
            ld [tl_n], a
            ld de, TL_OBJ
            ld hl, objs
            ld b, 15
.l:         ld a, [hl]
            and a
            jr z, .n
            push bc
            push hl
            call obj_hidden
            jr c, .sk
            pop hl
            push hl
            call tl_pos
            jr c, .sk
            ld a, [tl_n]
            inc a
            ld [tl_n], a
.sk:        pop hl
            pop bc
.n:         ld a, l
            add a, O_SIZE
            ld l, a
            jr nc, .n2
            inc h
.n2:        dec b
            jr nz, .l
            ret
; HL = slot, DE = TL_OBJ entry: its y, x, frame x 8, base (DE + 4) and NC, or C (not drawn)
tl_pos:     push hl
            ld a, l                         ; x = 72 + 8 + 16 (gx - px) + counter x - the step
            add a, O_GX
            ld l, a
            ld a, [px]
            ld b, a
            ld a, [hl]
            sub b
            add a, 32
            and 63
            sub 32
            cp $F9
            jr nc, .xin
            cp 7
            jr c, .xin
            pop hl
            scf
            ret
.xin:       swap a
            and $F0
            add a, 72 + 8
            ld b, a
            inc hl
            inc hl
            ld a, [hl]
            add a, b
            ld b, a
            push bc
            ld a, [mcount]
            ld c, a
            ld a, [mdx]
            call mulsign
            pop bc
            cpl
            inc a
            add a, b
            ld [tl_cut], a                  ; (x)
            dec hl
            ld a, [py]
            ld b, a
            ld a, [hl]
            sub b
            add a, 32
            and 63
            sub 32
            cp $FA
            jr nc, .yin
            cp 6
            jr c, .yin
            pop hl
            scf
            ret
.yin:       swap a
            and $F0
            add a, 64 + 16
            ld b, a
            inc hl
            inc hl
            ld a, [hl]
            add a, b
            ld b, a
            push bc
            ld a, [mcount]
            ld c, a
            ld a, [mdy]
            call mulsign
            pop bc
            cpl
            inc a
            add a, b
            ld b, a                         ; B = y
            ld a, [box_on]                  ; (under the box / the banner: hidden)
            and a
            ld a, BOX_LINES + 16
            jr nz, .cut
            ld a, [bn_t]
            and a
            jr z, .vis
            ld a, BN_LINES + 16
.cut:       cp b
            jr c, .vis
            jr z, .vis
            pop hl
            scf
            ret
.vis:       ld a, b
            ld [de], a
            inc de
            ld a, [tl_cut]
            ld [de], a
            inc de
            pop hl                          ; the frame (obj_spr's rules)
            push hl
            ld a, l
            add a, O_TALK
            ld c, a
            ld b, h
            ld a, [bc]
            and a
            jr z, .nt
            xor a                           ; (talking: face the party, standing)
            ld [bc], a
            ld a, [facing]
            xor 1
            add a, a
            jr .tb
.nt:        ld a, l
            add a, O_FACE
            ld c, a
            ld b, h
            ld a, [bc]
            add a, a
            push af
            inc hl
            ld a, [hl]
            dec hl
            and $40
            jr z, .wk
            ldh a, [frame]
            rrca
            jr .fr
.wk:        ld a, l
            add a, O_CX
            ld c, a
            ld b, h
            ld a, [bc]
            inc bc
            ld l, a
            ld a, [bc]
            or l
            rlca
.fr:        and 8
            jr z, .f0
            pop af
            inc a
            jr .tb
.f0:        pop af
.tb:        add a, a
            add a, a
            add a, a
            ld [de], a
            inc de
            pop hl
            push hl
            ld a, l
            add a, O_TILE
            ld l, a
            ld a, [hl]
            ld [de], a
            inc de
            pop hl
            and a
            ret

; ---- the party's pairs (tiles 16-39) from its 16 tiles (VRAM; LCD off or a masked load)
tl_pair:    ld a, $80
            ld [tl_sh], a
            ld de, $8100
; DE = the 24 tiles' destination, tl_sh = the 16 tiles' page: TL_PAIRS' top / bottom (mirrored)
tl_pgen:    ld hl, TL_PAIRS
            ld c, 12
.p:         push bc
            ld a, [hl+]                     ; top
            push hl
            call .ad
            xor a
            call tl_cp16
            pop hl
            ld a, [hl+]                     ; bottom, mirrored or not
            ld b, [hl]
            inc hl
            push hl
            push bc
            call .ad
            pop bc
            ld a, b
            call tl_cp16
            pop hl
            pop bc
            dec c
            jr nz, .p
            ret
.ad:        swap a
            ld l, a
            ld a, [tl_sh]
            ld h, a
            ret
; 16 bytes HL -> DE, mirrored when A is nonzero
tl_cp16:    ld b, 16
            and a
            jr nz, .f
.c:         ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .c
            ret
.f:         ld a, [hl+]
            push hl
            ld l, a
            ld h, high(TL_REV)
            ld a, [hl]
            pop hl
            ld [de], a
            inc de
            dec b
            jr nz, .f
            ret

; ---- V-Blank (rf_vb9, after the OAM): LCDC's sprite size from tl_lc; on the Color in an 8 x 16
; frame palettes 4 / 6 = 0 / 2 as shown (faded, colour-corrected), the bottoms' colours read, the
; line handler's first band edge (none while the box, banner, gradient, a wipe or a load has the
; lines: those frames keep the tops' colours)
tl_vb9:     ld a, [tl_map]
            and a
            jr z, .off
            ldh a, [rLCDC]
            bit 7, a
            jr z, .off
            and $FB
            ld b, a
            ld a, [tl_lc]
            or b
            ldh [rLCDC], a
            ld a, [lcdc_on]
            and $FB
            ld b, a
            ld a, [tl_lc]
            or b
            ld [lcdc_on], a
            ldh a, [is_cgb]
            and a
            jr z, .off
            ld a, [tl_lc]
            and a
            jr z, .off
            ld a, [tl_hold]                 ; (Select's copy: its V-Blank time)
            and a
            jr nz, .gate
            ld bc, $0020                    ; palette 0 -> 4, 2 -> 6
            call .cp
            ld bc, $1030
            call .cp
            ld c, 12                        ; colours 2 of palettes 1, 3, 2
            ld hl, tl_pb
            call .rd
            ld c, 28
            ld hl, tl_ob
            call .rd
            ld c, 20
            ld hl, tl_ot
            call .rd
.gate:      ld a, [box_on]
            ld b, a
            ld a, [bn_t]
            or b
            ld b, a
            ld a, [gr_on]
            or b
            ld b, a
            ld a, [wp_on]
            or b
            ld b, a
            ld a, [lmask]
            or b
            ld b, a
            ld a, [ly_n]
            or b
            ld b, a
            ldh a, [hrx]
            or b
            jr nz, .off
            ld a, [mcount]                  ; Y0: the first line of a top band (mod 16)
            ld c, a
            ld a, [mdy]
            call mulsign
            cpl
            inc a
            and 15
            ld e, a
            cpl                             ; line 0's band: top when (0 - Y0) & 15 < 8
            inc a
            and 15
            cp 8
            ld a, 1                         ; (top: the next edge writes the bottom)
            jr c, .t0
            ld a, $B4                       ; (bottom: its colour now)
            ldh [rOCPS], a
            ld a, [tl_ob]
            ldh [rOCPD], a
            ld a, [tl_ob + 1]
            ldh [rOCPD], a
            xor a
.t0:        ld [tl_os], a
            ld a, e                         ; the first edge: l = ((Y0 - 1) & 7) + 1, LYC l - 1
            dec a
            and 7
            ld [tl_no], a
            xor a
            ld [tl_pd], a
            ld a, [tl_no]
            ldh [rLYC], a
            ld a, 1
            ldh [tl_ras], a
            ret
.off:       ldh a, [tl_ras]
            and a
            ret z
            xor a
            ldh [tl_ras], a
            ld a, [bn_t]                    ; (the cut's line back)
            and a
            ld a, BOX_LINES - 1
            jr z, .ly
            ld a, BN_LINES - 1
.ly:        ldh [rLYC], a
            ret
; B = source index, C = destination index: 8 bytes (a palette)
.cp:        ld e, 8
.c1:        ld a, b
            ldh [rOCPS], a
            ldh a, [rOCPD]
            ld d, a
            ld a, c
            ldh [rOCPS], a
            ld a, d
            ldh [rOCPD], a
            inc b
            inc c
            dec e
            jr nz, .c1
            ret
; C = index: 2 bytes into HL
.rd:        ld a, c
            ldh [rOCPS], a
            ldh a, [rOCPD]
            ld [hl+], a
            inc c
            ld a, c
            ldh [rOCPS], a
            ldh a, [rOCPD]
            ld [hl], a
            ret

; ---- the line handler (stat_t2; STAT LYC, the Color, an 8 x 16 frame): in this line's H-Blank
; the people's colour 2 (palette 6) for the band from the next line, the party's bottom at line 72
stat_tl9:   push de
.w:         ldh a, [rSTAT]
            and 3
            jr nz, .w
            ldh a, [rLYC]
            ld d, a
            ld a, [tl_no]
            cp d
            jr nz, .np
            ld a, [tl_os]
            and a
            ld hl, tl_ot
            jr z, .o1
            ld hl, tl_ob
.o1:        ld a, $B4
            ldh [rOCPS], a
            ld a, [hl+]
            ldh [rOCPD], a
            ld a, [hl]
            ldh [rOCPD], a
            ld a, [tl_os]
            xor 1
            ld [tl_os], a
            ld a, [tl_no]
            add a, 8
            ld [tl_no], a
.np:        ld a, d
            cp 71
            jr nz, .nq
            ld a, [tl_pd]
            and a
            jr nz, .nq
            inc a
            ld [tl_pd], a
            ld a, $A4
            ldh [rOCPS], a
            ld a, [tl_pb]
            ldh [rOCPD], a
            ld a, [tl_pb + 1]
            ldh [rOCPD], a
.nq:        ld a, [tl_no]                   ; the next: the next edge, or the party's first
            ld d, a
            ld a, [tl_pd]
            and a
            jr nz, .nl
            ld a, d
            cp 71
            jr c, .nl
            ld d, 71
.nl:        ld a, d
            cp 143
            jr c, .s
            ld a, $FF                       ; (none left this frame)
.s:         ldh [rLYC], a
            pop de
            ret

; FF1's screen black before its palette cycle in (main.s pc_black; moved here for bank 0's room)
pc_black9:  ld a, 1
            ld [pc_hold], a
            call oam_clr
            ld a, $FF
            call bgp_w
            ldh a, [is_cgb]
            and a
            ret z
            ld a, $80
            call bcps_w
            ld b, 32
            xor a
.c:         call bcpd_w
            dec b
            jr nz, .c
            ret

; ---- bank 0's hooks
section bank 0, $0053                       ; (free space after the vectors)
; stat_int after its other users: the gradient, or a tall map's band edges (stat_tl9)
stat_grt:   ld a, [gr_on]
            and a
            jp nz, stat_gr
            ldh a, [tl_ras]
            and a
            jp z, stat_int.lc
            jp stat_t2
section bank 0, $00D3                       ; (free space)
stat_t2:    push bc
            push hl
            ld a, TALL_BANK
            ld hl, stat_tl9
            call bank_call
            pop hl
            pop bc
            jp stat_int.off
section bank 0, $0FBD                       ; (free space)
; obj_tiles' block size from the map bank (M_OBJBLK + 17: a tall map's 24 tiles)
ot_bc:      ld bc, 256
            ld a, [M_OBJBLK + 17]
            and a
            ret z
            ld c, $80
            ret
section bank 99, $6F7E                      ; (free space)
tl_setf:    ld a, TALL_BANK
            ld hl, tl_set
            jp bank_call

; FF1 AnimateAirshipTakeoff / AnimateAirshipLanding (moved from bank 0): the airship rises from y
; $6F to $4F (lands: back), a pixel every second frame, its shadow, the noise (FF1: volume 8, the
; frame counter as its period); then facing right
section bank 113, $4F00
air_up9:    ld a, $6F - $1C
            ld [air_y], a
.l:         call air_fr9
            ldh a, [frame]
            rrca
            jr c, .l
            ld hl, air_y
            dec [hl]
            ld a, [hl]
            cp $4F - $1C
            jr nc, .l
            jr air_dn9
air_down9:  ld a, $4F - $1C
            ld [air_y], a
.l:         call air_fr9
            ldh a, [frame]
            rrca
            jr c, .l
            ld hl, air_y
            inc [hl]
            ld a, [hl]
            cp $70 - $1C
            jr c, .l
air_dn9:    xor a
            ld [air_y], a
            ld [facing], a
            ld [sfx_nmode], a
            ret
air_fr9:    ld a, 3
            ld [sfx_nmode], a
            call vo_b
            call ap_tick
            jp wait_vbl
