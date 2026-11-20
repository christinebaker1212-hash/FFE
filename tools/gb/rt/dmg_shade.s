; DMG / SGB shading of BG tiles (not used on a Game Boy Color).
; The DMG has one BG palette for the whole screen, the NES four. Each BG tile is re-coded
; for the NES palette it is drawn with: pixel value 0 = the backdrop (or a colour equal to
; it), 1..3 = the palette's other colours by brightness (darkest 1). One BG palette (BGP)
; then gives each value a shade from the current NES colours, so palette fades darken /
; brighten the picture without re-coding tiles.
;   BG_SHADOW  cart RAM bank 1 $B000: the NES BG tiles as written (GB byte order)
;   TILE_PAL   palette (0-3) each BG tile is coded for (from nametable/attribute writes)
;   PAL_MAP    value of each NES colour index, per palette; recomputed once the palettes
;              have been stable for 8 frames (FF1 fades step every few frames)
;   RQ / DIRTY tiles waiting to be re-coded: all at once while the LCD is off, a few per
;              frame while it is on (through the VRAM queue)

; (constants BG_SHADOW .. RETILE_PER_FRAME: top of runtime.s)

; A = tile: mark it for re-coding. Keeps all registers.
dmg_mark:   push af
            push bc
            push hl
            ld c, a
            call bm_addr
            ld a, [hl]
            or b
            ld [hl], a
            ld a, l                         ; (no longer parked)
            add a, low(DEFER_BM) - low(DIRTY_BM)
            ld l, a
            ld a, b
            cpl
            and [hl]
            ld [hl], a
            ld a, 1
            ldh [rq_any], a
            pop hl
            pop bc
            pop af
            ret

; C = tile -> HL = its DIRTY_BM byte, B = its bit
bm_addr:    ld a, c
            and 7
            ld hl, BIT_MASK
            add a, l
            ld l, a
            jr nc, .nc
            inc h
.nc:        ld b, [hl]
            ld a, c
            srl a
            srl a
            srl a
            ld l, a
            ld h, high(DIRTY_BM)
            ret

; re-code up to B marked tiles (B = 0: all). The dirty bitmap is scanned from rq_pos
; (byte index) on, so every marked tile gets its turn.
dmg_retile_some:
            ldh a, [rq_any]
            and a
            ret z
            push bc
            push de
            push hl
            ld d, 33                        ; bytes left to look at (one more: the start byte again)
.byte:      ldh a, [rq_pos]
            ld l, a
            ld h, high(DIRTY_BM)
            ld a, [hl]
            and a
            jr nz, .bit
            ld a, l
            inc a
            and 31
            ldh [rq_pos], a
            dec d
            jr nz, .byte
            xor a                           ; nothing marked
            ldh [rq_any], a
            jr .x
.bit:       ld c, 0                         ; lowest set bit -> C, mask -> E
            ld e, 1
.f:         rrca
            jr c, .fd
            inc c
            sla e
            jr .f
.fd:        ld a, e
            cpl
            and [hl]
            ld [hl], a
            ld a, l
            add a, a
            add a, a
            add a, a
            or c
            call retile
            ld d, 33
            dec b
            jr nz, .byte
.x:         pop hl
            pop de
            pop bc
            ret

; A = tile: write its VRAM pixels from the shadow through PAL_MAP[TILE_PAL[tile]]
; (retile_b, bank HLE_BANK). Keeps BC, DE, HL.
retile:     push af
            ld a, HLE_BANK
            ld [$2000], a
            pop af
            call retile_b
            jp hle_back

; B / C = colour indices whose value has bit 0 / bit 1 set (the tile's palette), E = tile ->
; A = its coding key: the values of the indices it uses. Keeps BC, DE, HL.
tkey_bc:    push hl
            ld a, e
            srl a
            add a, low(TILE_USE)
            ld l, a
            ld h, high(TILE_USE)
            ld a, [hl]
            bit 0, e
            jr z, .lo
            swap a
.lo:        and $0F
            or 1
            ld l, a
            and c
            swap a
            ld h, a
            ld a, l
            and b
            or h
            pop hl
            ret

; A = tile whose pixels were written: mark it, its coding unknown. Keeps all registers.
dmg_markw:  call bgsrc_inv                  ; (its page no longer as copied from ROM)
            push hl
            ld l, a
            ld h, high(CODED)
            ld [hl], $FF
            pop hl
            jp dmg_mark
; sh_p0 / sh_p1 (a tile row's planes) -> sh_m0..3 = masks of the pixels of index 0..3
row_masks:  push bc
            ldh a, [sh_p0]
            ld b, a
            ldh a, [sh_p1]
            ld c, a
            and b
            ldh [sh_m3], a
            ld a, c
            cpl
            and b
            ldh [sh_m1], a
            ld a, b
            cpl
            and c
            ldh [sh_m2], a
            ld a, b
            or c
            cpl
            ldh [sh_m0], a
            pop bc
            ret

; A = set of indices (bit i) -> A = OR of the pixel masks sh_m<i>
mask_comb:
            push bc
            ld b, a
            ld c, 0
            bit 0, b
            jr z, .c1
            ldh a, [sh_m0]
            ld c, a
.c1:        bit 1, b
            jr z, .c2
            ldh a, [sh_m1]
            or c
            ld c, a
.c2:        bit 2, b
            jr z, .c3
            ldh a, [sh_m2]
            or c
            ld c, a
.c3:        bit 3, b
            jr z, .c4
            ldh a, [sh_m3]
            or c
            ld c, a
.c4:        ld a, c
            pop bc
            ret

; HL = VRAM address, A = value: written now (LCD off) or through the VRAM queue
vram_put:   push bc
            push de
            ld d, a
            ldh a, [lcd_on]
            and a
            jr nz, .q
            ld [hl], d
            jr .x
.q:         ldh a, [q_head]                 ; (entries waiting: as many written as VRAM
            ld b, a                         ;   allows right now)
            ldh a, [q_tail]
            cp b
            call nz, q_try
            ldh a, [q_head]                 ; queue empty: written now if VRAM is free (STAT
            ld b, a                         ;   mode 0 / 1; mode 2 follows, so VRAM stays free
            ldh a, [q_tail]                 ;   long enough), interrupts off for it; a CGB
            cp b                            ;   masked load waits for that moment, otherwise
            jr nz, .qq                      ;   the queue
            ld a, [VLCD]
            ld e, a
            bit 6, h                        ; (address high + $40: VRAM bank 1)
            jr z, .m0
            res 6, h
            di
            ld a, 1
            ldh [$FF4F], a
.w1:        ldh a, [$FF41]
            bit 1, a
            jr z, .d1
            ld a, e
            and a
            jr nz, .w1
            xor a                           ; (not free and no masked load: queued)
            ldh [$FF4F], a
            ei
            set 6, h
            jr .qq
.d1:        ld [hl], d
            xor a
            ldh [$FF4F], a
            ei
            set 6, h
            jr .x
.m0:        di
.w0:        ldh a, [$FF41]
            bit 1, a
            jr z, .d0
            ld a, e
            and a
            jr nz, .w0
            ei
            jr .qq
.d0:        ld [hl], d
            ei
            jr .x
.qq:        ldh a, [q_tail]
            ld e, a
            inc a
            ld b, a
.f:         ldh a, [q_head]
            cp b
            jr nz, .r
            call q_drain1
            jr .f
.r:         push hl
            ld a, l
            ld c, h
            ld h, high(QH)
            ld l, e
            ld [hl], c
            inc h
            ld [hl], a
            inc h
            ld [hl], d
            pop hl
            ld a, b
            ldh [q_tail], a
.x:         pop de
            pop bc
            ret

; NES nametable cell written: B:L = offset (0-$3BF; B + 4 for nametable 1), A = tile.
; Its palette from the attribute shadow; a tile coded for another palette is re-coded.
dmg_cell:   push bc
            push de
            push hl
            ld d, a                         ; tile
            ld a, b
            and 4
            ldh [sh_nt], a
            ld a, b
            and 3
            ld b, a
            ld a, l                         ; row = offset >> 5, col = offset & 31
            and 31
            ld e, a                         ; col
            ld a, l
            swap a
            rrca
            and $07
            ld c, a
            ld a, b
            add a, a
            add a, a
            add a, a
            or c                            ; row
            call cell_pal                   ; A = palette of (row A, col E)
dmg_cell_e: ld e, a
            call pal_mark
            ld l, d
            ld h, high(TILE_PAL)
            ld a, [hl]
            cp e
            jr z, .pk
            ld [hl], e
            ld a, d
            call dmg_mark
            jr .x
.pk:        ld c, d                         ; same palette: parked tile? mark it
            call bm_addr
            ld a, l
            add a, low(DEFER_BM) - low(DIRTY_BM)
            ld l, a
            ld a, [hl]
            and b
            jr z, .x
            ld a, b
            cpl
            and [hl]
            ld [hl], a
            ld a, d
            call dmg_mark
.x:         pop hl
            pop de
            pop bc
            ret

; ---- DMG / SGB: the palette the maps are made from (MPB). FF1 fades and cycles its colours
; on the PPU while the palette they lead to stays in RAM ($6D34 in battle, $03C0 elsewhere).
; When every live BG colour is that target's colour, black, or the same hue darker (a fade),
; the maps come from the target (carry set): fades then only darken the BGP, and a battle
; fading in from black is shaded right from its first frame. Otherwise (colour cycles,
; screens that do not use those buffers) MPB = the live palette (carry clear).
; Out: B = 1 if MPB changed. Keeps DE, HL.
MPB        = SPR_DIRTY      ; (16; the CGB uses it for the sprite DMA marks only)
dmg_target: push af                         ; (native in bank PF_BANK: dmg_target_b)
            ld a, PF_BANK
            ld [$2000], a
            pop af
            call dmg_target_b
            jp hle_back

; A = palette, H = tile: as dmg_cell for a cell whose palette is known (prow_b)
dmg_tile_p: push bc
            push de
            push hl
            ld d, h
            jr dmg_cell_e

; A = tile drawn with NES palette 3 (a dialogue box cell in the window): coded for it
dmg_tile3:  push bc
            push de
            push hl
            ld d, a
            ld a, 3
            jr dmg_cell_e

; A = row, E = col -> A = palette (0-3) from the attribute shadow of nametable sh_nt
cell_pal:   push bc
            push hl
            ld b, a
            and $1C                         ; (row >> 2) * 8
            add a, a
            ld c, a
            ld a, e
            srl a
            srl a
            add a, c
            add a, $C0
            ld l, a
            ldh a, [sh_nt]
            add a, high(NT_SH) + 3
            ld h, a
            ld a, [hl]                      ; attribute byte: bottom half (row & 2) >> 4,
            bit 1, b                        ;   right half (col & 2) >> 2
            jr z, .t
            swap a
.t:         bit 1, e
            jr z, .l
            rrca
            rrca
.l:         and 3
            pop hl
            pop bc
            ret

; NES attribute byte A (0-63, + $40 for nametable 1) written: its 16 cells' tiles are checked
dmg_attr:   push bc
            push de
            push hl
            ld c, a
            ldh a, [sgb_glob]               ; (SGB: the screen's palettes again; while it
            and a                           ;   scrolls, on the next 32-frame rebuild)
            jr nz, .ng
            ld a, 1
            ldh [sgb_dirty], a
            ldh [sgb_adirty], a
.ng:        ld a, c
            and $40
            rrca
            rrca
            rrca
            rrca
            ldh [sh_nt], a
            ld a, c
            and $3F
            ld c, a
            and $38                         ; row0 = (i >> 3) * 4, col0 = (i & 7) * 4
            rrca
            ld d, a                         ; row0
            ld a, c
            and 7
            add a, a
            add a, a
            ld e, a                         ; col0
            ld c, 4
.r:         push bc
            ld b, 4
            push de
.c:         push bc
            ld a, d                         ; rows 30-31: attribute bytes, not cells
            cp 30
            jr nc, .s
            call quad_chk                   ; quadrant whose palette did not change: skip
            jr z, .s
            call own_chk                    ; a cell another nametable drew: not this byte's
            and a
            jr nz, .s
            ld a, d
            srl a                           ; tile at (row D, col E): NT_SH + row*32 + col
            srl a
            srl a
            add a, high(NT_SH)
            ld h, a
            ldh a, [sh_nt]
            add a, h
            ld h, a
            ld a, d
            and 7
            swap a
            add a, a
            or e
            ld l, a
            ld a, [hl]                      ; tile
            push af
            ld a, d
            call cell_pal
            ld b, a
            call pal_mark                   ; (a palette reached by an attribute change, e.g.
            pop af                          ;   the prologue's fade, counts as used too)
            ld l, a
            ld h, high(TILE_PAL)
            ld c, a
            ld a, [hl]
            cp b
            jr z, .s
            ld [hl], b
            ld a, c
            call dmg_mark
.s:         inc e
            pop bc
            dec b
            jr nz, .c
            pop de
            inc d
            pop bc
            dec c
            jr nz, .r
            pop hl
            pop de
            pop bc
            ret

; brightness of NES colour A (0-63): 0 black .. 8 white (the 2C02 rows, the grey column
; a bit brighter). Keeps all registers but A.
lum:        push hl
            and $3F
            ld hl, LUM_TAB
            add a, l
            ld l, a
            jr nc, .nc
            inc h
.nc:        ld a, [hl]
            pop hl
            ret
LUM_TAB:
            db 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0
            db 4, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 0, 0, 0
            db 6, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 0, 0, 0
            db 8, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 0, 0, 0

; retile_b (bank HLE_BANK): both planes of a tile (and TILE_USE) by pf2_b in bank PF_BANK
pf2_call:   push af
            ld a, PF_BANK
            ld [$2000], a
            pop af
            call pf2_b
            ld a, HLE_BANK
            ld [$2000], a
            ret

; ---- LDA (zp),Y / STA $2007 / INY / DEX / BNE (b21:80C5, fix:F24D): X bytes (0: 256) to
; the PPU. In bulk while the LCD is off (or a CGB masked load), the increment is 1, the run
; stays in nametable 0's cells and its source in one 8 KB area: shadow and GB map copied
; (owners as ntfill); anything else byte by byte. Out: A = the last byte, X = 0, Y += n,
; N = 0, Z = 1, carry kept.
NF_N       = $D82C          ; ntfill / izyrun0: bytes of this run (2; fault-dump area, DBG + 12)
IZ_OFF     = $DCDC          ; izyrun0: nametable offset (2), last byte
IZ_LAST    = $DCDE
hle_izr10:  ld a, $10
            jr izyrun0
hle_izr94:  ld a, $94
izyrun0:    ldh [tmp_lo], a                 ; (zp)
            push af                         ; (carry)
            ldh a, [lcd_on]
            and a
            jr z, .bk
            ld a, [VLCD]
            and a
            jp z, .slow
.bk:        ldh a, [ppu_ctrl]
            and 4
            jp nz, .slow
            ldh a, [ppu_vh]
            cp $20
            jp c, .slow
            cp $3F
            jp z, .slow
            and 7
            cp 4
            jp nc, .slow                    ; (nametable 1)
            ld h, a
            ldh a, [own1_lo]                ; (cells of nametable 1 on a CGB: byte by byte)
            ld l, a
            ldh a, [own1_hi]
            or l
            jr z, .o0
            ldh a, [is_cgb]
            and a
            jp nz, .slow
.o0:        ldh a, [ppu_vl]                 ; offset + n <= $3C0
            ld l, a                         ; (HL = offset)
            ld a, e
            dec a                           ; n - 1 (0-255)
            add a, l
            ld a, h
            adc a, 0
            cp 3
            jr c, .ok
            jp nz, .slow
            ld a, e
            dec a
            add a, l
            cp $C0
            jp nc, .slow
.ok:        ld a, l                         ; offset and n kept
            ld [IZ_OFF], a
            ld a, h
            ld [IZ_OFF + 1], a
            ld a, e
            ld [NF_N], a
            and a
            ld a, 0
            jr nz, .n1
            inc a
.n1:        ld [NF_N + 1], a
            ldh a, [tmp_lo]                 ; source: NES (zp) + Y
            ld l, a
            ld h, high(NES_RAM)
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            add hl, bc
            ld a, e                         ; last byte in the same 8 KB area
            dec a
            add a, l
            ld a, h
            adc a, 0
            xor h
            and $E0
            jp nz, .slow
            ld a, h
            cp $20
            jr c, .ram
            cp $60
            jp c, .slow
            cp $80
            jr nc, .rom
            add a, $40                      ; save RAM
            ld h, a
            jr .src
.ram:       ld a, e                         ; (within the 2 KB: no mirror crossing)
            dec a
            add a, l
            ld a, h
            adc a, 0
            xor h
            and $F8
            jp nz, .slow
            ld a, h
            and 7
            or high(NES_RAM)
            ld h, a
            jr .src
.rom:       cp $C0
            jr nc, .rc
            sub $40
            ld h, a
            ldh a, [data_bank8]
            jr .bnk
.rc:        cp $E0
            jr nc, .re
            sub $80
            ld h, a
            ldh a, [data_bankC]
            jr .bnk
.re:        sub $80
            ld h, a
            ld a, DATA + 31
.bnk:       ld [$2000], a
.src:       ld a, [IZ_OFF + 1]              ; shadow
            add a, high(NT_SH)
            ld d, a
            ld a, [IZ_OFF]
            ld e, a
            push hl
            ld b, c                         ; (Y)
            ld a, [NF_N]
            ld c, a
.cs:        ld a, [hl+]
            ld [de], a
            inc de
            dec c
            jr nz, .cs
            ld [IZ_LAST], a
            pop hl
            ld a, [VLCD]                    ; GB map (LCD off; masked: rebuilt when shown)
            and a
            jr z, .mp
            ld a, 1
            ld [MAP_RB], a
            jr .md
.mp:        ld a, [IZ_OFF + 1]
            add a, $98
            ld d, a
            ld a, [IZ_OFF]
            ld e, a
            ld a, [NF_N]
            ld c, a
.m0:        ld a, [hl+]
            ld [de], a
            inc de
            dec c
            jr nz, .m0
.md:        ld c, b                         ; C = Y
            ld b, 0
            ldh a, [code_bank]
            ld [$2000], a
            ld a, [IZ_OFF]
            ld l, a
            ld a, [IZ_OFF + 1]
            ld h, a
            ldh a, [own1_lo]                ; nametable 0 owns these cells now
            ld d, a
            ldh a, [own1_hi]
            or d
            jr z, .nown
            push bc
            push hl
            ld a, HLE_BANK
            ld [$2000], a
            call nf_own
            ldh a, [code_bank]
            ld [$2000], a
            pop hl
            pop bc
.nown:      ldh a, [is_cgb]
            and a
            jr nz, .cg
            ld a, 1
            ldh [dmg_scan], a
.cg:        ld a, [NF_N]                    ; v += n (within nametable 0), Y += n
            ld d, a
            add a, l
            ldh [ppu_vl], a
            ld a, [NF_N + 1]
            adc a, h
            ld h, a
            ldh a, [ppu_vh]
            and $FC
            or h
            ldh [ppu_vh], a
            ld a, c
            add a, d
            ld c, a
            ld a, [IZ_LAST]
            ldh [tmp_lo], a
            jr .out
.slow:      ldh a, [tmp_lo]                 ; byte by byte
            ld d, a
.sl:        ld l, d
            push de
            call rt_izy_rd
            ld a, l
            ldh [tmp_lo], a
            call rt_ppu_w7
            pop de
            inc c
            dec e
            jr nz, .sl
.out:       ld b, 0
            ld d, b
            ld e, b
            xor a
            ldh [nzv], a
            pop af                          ; carry back
            ldh a, [tmp_lo]
            ld l, 0
            inc l
            dec l                           ; Z = 1
            ret

; ---- DMG sprite pages left in ROM by hle_chr_pages (whole pages): LZ_BM (cart RAM bank 3)
; marks the tiles not yet in the shadow, LZ_SRC the ROM bank and address of each page.
; A = sprite tile: copied into the shadow now if marked (the ROM bank: code_bank after).
; Keeps all registers.
spr_mat:    push af
            push bc
            push de
            push hl
            ld e, a
            xor a                           ; (wtmp = 1: copied now, and its bytes were
            ldh [wtmp], a                   ;   the shadow's already)
            ld a, 3
            ld [$4000], a
            ld a, e
            rrca
            rrca
            rrca
            and $1F
            add a, low(LZ_BM)
            ld l, a
            ld h, high(LZ_BM)
            ld a, e
            and 7
            ld b, 1
            jr z, .bt
.sh:        sla b
            dec a
            jr nz, .sh
.bt:        ld a, [hl]
            and b
            jr z, .n
            ld a, b
            cpl
            and [hl]
            ld [hl], a
            ld a, e                         ; source: the page's + (tile & 15) * 16
            swap a
            and $0F
            add a, a
            add a, a
            add a, low(LZ_SRC)
            ld l, a
            ld a, [hl+]
            ld d, a                         ; D = ROM bank
            ld a, [hl+]
            ld c, a
            ld b, [hl]
            ld a, e
            and $0F
            swap a
            add a, c
            ld c, a
            jr nc, .nc
            inc b
.nc:        ld a, e                         ; HL = shadow $A000 + tile * 16
            swap a
            ld l, a
            and $0F
            add a, high(SPR_SHADOW)
            ld h, a
            ld a, l
            and $F0
            ld l, a
            ld a, 1
            ld [$4000], a
            ld a, d
            ld [$2000], a
            ld d, 0                         ; (D = OR of the differences)
            ld e, 8                         ; plane 0 -> even bytes, plane 1 -> odd
.p0:        ld a, [bc]
            xor [hl]
            or d
            ld d, a
            ld a, [bc]
            inc bc
            ld [hl+], a
            inc l
            dec e
            jr nz, .p0
            ld a, l
            sub 15
            ld l, a
            ld e, 8
.p1:        ld a, [bc]
            xor [hl]
            or d
            ld d, a
            ld a, [bc]
            inc bc
            ld [hl+], a
            inc l
            dec e
            jr nz, .p1
            ld a, d
            and a
            jr nz, .df
            inc a
            ldh [wtmp], a
.df:        ldh a, [code_bank]
            ld [$2000], a
.n:         xor a
            ld [$4000], a
.x:         pop hl
            pop de
            pop bc
            pop af
            ret

; A = value, DE = destination, C = count (0: 256): filled 8 bytes at a time; DE += count.
; Keeps HL, C.
fillde:     push hl
            ld h, d
            ld l, e
            ld e, a
            ld a, c
            and 7
            jr z, .g
            ld d, a
            ld a, e
.r:         ld [hl+], a
            dec d
            jr nz, .r
.g:         ld a, c
            srl a
            srl a
            srl a
            jr nz, .gn
            ld a, c
            and a
            jr nz, .x
            ld a, 32
.gn:        ld d, a
            ld a, e
.gl:        ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            dec d
            jr nz, .gl
.x:         ld d, h
            ld e, l
            pop hl
            ret

; dmg_maps: native in bank PF_BANK (dmg_maps_b)
dmg_maps:   push af
            ld a, PF_BANK
            ld [$2000], a
            pop af
            call dmg_maps_b
            jp hle_back

dmg_bgp:    push bc
            push de
            push hl
            call bg_lmax
            ld b, a
            ld a, [REF_LMAX]
            sub b
            jr nc, .dp
            xor a
.dp:        srl a
            ld c, a                         ; fade drop (shades)
            ldh [fade_drop], a
            ld a, [PAL_SH]
            call lum
            call lum_shade
            ld e, a                         ; (backdrop shade)
            call .fd                        ; value 0
            ld d, a
            ld b, 1                         ; value being placed
.v:         call .base
            call .fd
.ok:        push bc
.sh:        add a, a
            add a, a
            dec b
            jr nz, .sh
            pop bc
            or d
            ld d, a
            inc b
            ld a, b
            cp 4
            jr nz, .v
            ld a, d
            pop hl
            pop de
            pop bc
            ret
.fd:        push af                         ; A = shade, C = fade drop -> faded shade: on a
            ldh a, [is_sgb]                 ;   plain Game Boy toward white (owner: simple
            and a                           ;   fades; the LCD off between screens is white
            jr nz, .fdk                     ;   there), on the SGB toward black
            pop af
            sub c
            ret nc
            xor a
            ret
.fdk:       pop af
            add a, c
            cp 4
            ret c
            ld a, 3
            ret
.base:      ld a, e                         ; B = value -> A = its shade before the fade
            cp 3
            jr nz, .lum
            ld a, [NGRP]
            cp 3
            jr z, .n3
            cp 2
            jr z, .n2
.lum:       ld a, b
            add a, low(GLUM)
            ld l, a
            ld h, high(GLUM)
            ld a, [hl]
            jp lum_shade
.n3:        call .v1blk                     ; value 1 / 2 / 3: dark grey / light grey / white,
            jr z, .n3b                      ;   or black / light grey / white when value 1
            ld a, 3                         ;   holds only the darkest colours ($0x: menu
            sub b                           ;   windows, as the battle's black windows)
            ret
.n3b:       ld a, b
            dec a
            ld a, 3
            ret z
            ld a, b
            sub 2
            xor 1
            ret
.n2:        call .v1blk
            ld a, b
            jr nz, .n2g
            dec a
            ld a, 3
            ret z
            xor a
            ret
.n2g:       dec a
            ld a, 2
            ret z
            xor a
            ret
.v1blk:     ld a, [GLUM + 1]                ; Z: value 1's brightest level is 1 or less
            cp 2
            jr nc, .v1n
            xor a
            ret
.v1n:       or 1
            ret

; brightness A (0-8) -> DMG shade (0 white .. 3 black)
lum_shade:  and a
            jr z, .bk
            cp 4
            jr c, .dk
            cp 7
            jr c, .lt
            xor a
            ret
.lt:        ld a, 1
            ret
.dk:        ld a, 2
            ret
.bk:        ld a, 3
            ret

; A = brightest colour 1-3 of the four NES BG palettes (0-8)
bg_lmax:    push hl
            ld hl, PAL_SH
            call bg_lmax_hl
            pop hl
            ret
bg_lmax_hl: push bc                         ; HL = 16 BG colours (page offset a multiple of 16)
            push hl
            ld b, 0
            ld c, 16
.i:         ld a, l
            and 3
            jr z, .n
            ld a, [hl]
            call lum
            cp b
            jr c, .n
            ld b, a
.n:         inc l
            dec c
            jr nz, .i
            ld a, b
            pop hl
            pop bc
            ret

; boot (DMG): PAL_MAP identity, full brightness reference
lz_init:    ld a, 3                         ; boot: no sprite page left in ROM (LZ_BM), no
            ld [$4000], a                   ;   BG page known as copied from ROM (BG_SRC)
            ld hl, LZ_BM
            xor a
            ld b, 32
.lz:        ld [hl+], a
            dec b
            jr nz, .lz
            call bgsrc_init
            xor a
            ld [$4000], a
            ret
dmg_init:   ld hl, CODED                    ; no tile coded yet
            ld a, $FF
.cd:        ld [hl+], a
            inc l
            dec l
            jr nz, .cd
            ld a, 8
            ld [REF_LMAX], a
            ld a, 3
            ld [NGRP], a
            ld hl, PAL_MAP
            ld b, 4
.p:         xor a
.i:         ld [hl+], a
            inc a
            cp 4
            jr nz, .i
            dec b
            jr nz, .p
            ret

; D = row, E = col of the GB map: A = 0 if nametable sh_nt drew that cell (OWN)
own_chk:    push bc
            push hl
            ld a, d
            add a, a
            add a, a
            ld b, a
            ld a, e
            rrca
            rrca
            rrca
            and 3
            or b
            ld l, a
            ld h, high(OWN)
            ld a, e
            and 7
            ld b, a
            ld a, [hl]
            inc b
.s:         dec b
            jr z, .d
            rrca
            jr .s
.d:         and 1
            ld b, a
            ldh a, [sh_nt]
            and a
            jr z, .n0
            ld a, 1
.n0:        xor b
            pop hl
            pop bc
            ret

; D = row, E = col: NZ if the cell's attribute quadrant is in ap_chg
quad_chk:   push bc
            ld a, d
            and 2                           ; q = (row & 2) + (col & 2) / 2
            ld b, a
            ld a, e
            and 2
            rrca
            or b
            ld b, a
            ldh a, [ap_chg]
            inc b
.s:         dec b
            jr z, .d
            rrca
            jr .s
.d:         and 1
            pop bc
            ret

; LCD going on after drawing with it off: every GB map cell (rows 0-29) gives its tile
; the palette it is drawn with (from the nametable that owns the cell); tiles coded for
; another palette are marked
dmg_scan_all:                               ; (native: scan_b, bank PF_BANK)
            push af
            ld a, PF_BANK
            ld [$2000], a
            pop af
            call scan_b
            jp hle_back

; LCD off, going on: re-code marked tiles in one pass (rtb_b, bank PF_BANK): A = 0 all,
; A = 1 those the map uses (the others parked)
dmg_retile_lcd:
            push bc
            push de
            push hl
            push af
            ld a, PF_BANK
            ld [$2000], a
            pop af
            call rtb_b
            pop hl
            pop de
            pop bc
            jp hle_back

; obp0_v / obp1_v from the fixed shades, darkened by fade_drop
dmg_obp:    push bc
            ldh a, [fade_drop]
            ld c, a
            ld a, 3                         ; OBP0: values 1-3 = black, dark grey, white
            add a, c
            call .cl
            add a, a
            add a, a
            ld d, a                         ; value 1 << 2
            ld a, 2
            add a, c
            call .cl
            swap a
            or d
            ld d, a
            ld a, c
            call .cl
            rrca
            rrca
            or d
            ldh [obp0_v], a
            ld a, 2                         ; OBP1: dark grey, light grey, white
            add a, c
            call .cl
            add a, a
            add a, a
            ld d, a
            ld a, 1
            add a, c
            call .cl
            swap a
            or d
            ld d, a
            ld a, c
            call .cl
            rrca
            rrca
            or d
            ldh [obp1_v], a
            pop bc
            ret
.cl:        cp 4
            ret c
            ld a, 3
            ret

; A = BG palette a cell uses: into PAL_USED; a palette new there makes the maps be
; recomputed (next frame). Keeps BC, DE, HL.
pal_mark:   push hl
            push bc
            ld hl, BIT_MASK
            add a, l
            ld l, a
            jr nc, .nc
            inc h
.nc:        ld b, [hl]
            ld a, [PAL_USED]
            ld c, a
            or b
            cp c
            jr z, .x
            ld [PAL_USED], a
            ld a, 1
            ldh [maps_due], a
            ld a, PAL_STABLE - 1
            ldh [pal_age], a
.x:         pop bc
            pop hl
            ret
