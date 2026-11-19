; FF1-specific native replacements for hot NES routines (same results, GB speed).

; ---- $E9F6: copy X pages from ($10)+Y to $2007 (CHR upload loop)
;   loop: LDA ($10),Y / STA $2007 / INY / BNE / INC $11 / DEX / BNE ; RTS
;   exit: A = last byte, X = Y = 0, Z = 1, N = 0, carry unchanged.
; Fast path: LCD off, +1 increment, destination in the pattern tables, source in
; $8000-$BFFF, tile-aligned. Anything else runs the generic per-byte path.
hle_chr_pages:
            push af                         ; caller's carry
.page:      ld a, e
            and a
            jp z, .done
            ldh a, [lcd_on]                 ; LCD on: CGB only (BG tiles to the tile copy +
            and a                           ;   DMA marks)
            jr z, .lok
            ldh a, [is_cgb]
            and a
            jp z, .slow
.lok:
            ldh a, [ppu_ctrl]
            and 4
            jp nz, .slow
            ldh a, [ppu_vh]
            cp $20
            jp nc, .slow
            ld a, c                         ; whole tiles only
            and $0F
            jp nz, .slow
            ldh a, [ppu_vl]
            and $0F
            jp nz, .slow
            ld a, [NES_RAM + $11]
            cp $80
            jp c, .slow
            cp $C0
            jp nc, .slow
            ; source HL = GB $4000 + ptr - $8000 + Y in the current $8000 data bank
            sub $40
            ld h, a
            ld a, [NES_RAM + $10]
            add a, c
            ld l, a
            ld a, h
            adc a, 0
            ld h, a
            ldh a, [data_bank8]
            ld [$2000], a
            push de
.tile:      ; destination DE = GB tile address for v (as in rt_ppu_w7)
            ldh a, [ppu_vl]
            and $F0
            ld e, a
            ldh a, [ppu_vh]
            cp $10
            jr nc, .spr
            ld d, a
            ldh a, [is_cgb]
            and a
            ld a, d
            jr nz, .bgv
            and $0F                         ; DMG: BG tiles to the shadow (RAM bank 1), re-coded
            add a, high(BG_SHADOW)          ;   for their palette later
            ld d, a
            ld a, 1
            ld [$4000], a
            jr .copy
.bgv:       ld d, a
            ldh a, [lcd_on]
            and a
            ld a, d
            jr nz, .bgs
            cp $08
            ld d, $90
            jr c, .bg0
            ld d, $80
.bg0:       and $0F
            add a, d
            ld d, a
            jr .copy
.bgs:       and $0F                         ; CGB, LCD on: the tile copy (WRAM bank 2, $D000 +
            add a, $D0                      ;   tile * 16), the tile marked for the vblank DMA
            ld d, a
            ld a, 2
            ldh [$FF70], a
.spr:       and $0F                         ; sprite table -> shadow (RAM bank 1)
            add a, high(SPR_SHADOW)
            ld d, a
            ld a, 1
            ld [$4000], a
.copy:      ld b, 8
.p0:        ld a, [hl+]
            ld [de], a
            inc e
            inc e
            dec b
            jr nz, .p0
            ld a, e
            sub 15
            ld e, a
            ld b, 8
.p1:        ld a, [hl+]
            ld [de], a
            inc e
            inc e
            dec b
            jr nz, .p1
            ldh [tmp_lo], a                 ; last byte
            ld a, d
            cp $D0
            jr c, .nst
            ld a, 1                         ; (tile copy: WRAM bank 1 again, mark the tile)
            ldh [$FF70], a
            push hl
            ld a, e
            sub 17
            swap a
            and $0F
            ld e, a
            ld a, d
            sub $D0
            swap a
            or e
            ld hl, BG_DIRTY
            call hd_mark
            pop hl
            jr .nx
.nst:       ld a, d
            cp high(BG_SHADOW)
            jr c, .nbg
            call hle_bg_tile                ; DMG BG tile in the shadow: queue its re-coding
            jr .nx
.nbg:       cp high(SPR_SHADOW)             ; (BG tiles in VRAM are at $80-$97: not sprites)
            call nc, hle_spr_tile           ; sprite tile: to its slot if resident
.nx:
            ldh a, [ppu_vl]                 ; v += 16
            add a, 16
            ldh [ppu_vl], a
            ldh a, [ppu_vh]
            adc a, 0
            and $3F
            ldh [ppu_vh], a
            ld a, c                         ; Y += 16, page done when it wraps
            add a, 16
            ld c, a
            jr nz, .tile
            pop de
            ldh a, [code_bank]
            ld [$2000], a
            ld hl, NES_RAM + $11            ; INC $11 / DEX
            inc [hl]
            dec e
            jp .page
.slow:      ; generic: one byte (LDA ($10),Y / STA $2007 / INY), then page bookkeeping
            ld l, $10
            call rt_izy_rd
            ld a, l
            ldh [tmp_lo], a
            call rt_ppu_w7
            inc c
            jr nz, .page_cont
            ld hl, NES_RAM + $11
            inc [hl]
            dec e
            jp .page
.page_cont: ld a, e
            and a
            jr nz, .slow
.done:      xor a
            ldh [nzv], a
            pop af                          ; carry back
            ldh a, [tmp_lo]
            ld l, 0
            inc l
            dec l                           ; Z = 1 (DEX reached 0)
            ret

; after a BG tile went to the DMG shadow (DE = shadow tile start + 17, RAM bank 1 on):
; queue the tile for re-coding; RAM bank 0 back. Keeps BC, HL.
hle_bg_tile:
            xor a
            ld [$4000], a
            ld a, e
            sub 17
            swap a
            and $0F
            ld e, a
            ld a, d
            sub high(BG_SHADOW)
            swap a
            or e
            jp dmg_markw

; after a tile went to the sprite shadow (DE = shadow tile start + 17: the odd-byte loop
; ends one past the tile; RAM bank 1 on): copy it to the tile's GB slot if resident;
; RAM bank 0 back. Keeps BC, HL.
hle_spr_tile:
            push bc
            push hl
            ld a, e
            sub 17
            ld e, a                         ; DE = shadow tile start
            ld a, d                         ; tile = ((D - $A0) << 4) | (E >> 4)
            sub high(SPR_SHADOW)
            swap a
            ld b, a
            ld a, e
            swap a
            and $0F
            or b
            ld l, a
            ld h, high(SPR_SLOT)
            ld a, [hl]
            cp $FF
            jr z, .x
            add a, low(SLOT_KEY)            ; resident: loaded again (coded) by the next
            ld l, a                         ;   OAM conversion
            ld h, high(SLOT_KEY)
            ld [hl], $FF
.x:         xor a
            ld [$4000], a
            pop hl
            pop bc
            ret

; ---- $EA7F: one page from ($10)+Y (Y = 0) to $2007 (map CHR loader $EA60; the
;   tile fast path of hle_chr_pages). LDA ($10),Y / STA $2007 / INY / BNE: X and $11 kept,
;   A = last byte, Y = 0, Z = 1, N = 0, carry unchanged.
hle_chr_page1:
            push de                         ; X
            ld e, 1
            call hle_chr_pages              ; (one page; it counts $11 up and X down)
            pop de
            push af
            ld hl, NES_RAM + $11
            dec [hl]
            pop af
            ret

; ---- c62:D1A8: map decompression run (STA ($12),Y / INY / BEQ $D1B8 / DEX / BNE $D1A8).
;   The run is stored here; it returns to $D1AB (the BEQ) either with Y = 0 and Z = 1 (as
;   the NES leaves it when Y wraps: X not counted for that store) or with X = 1 and Z = 0
;   (the NES's last DEX / BNE then ends the run). A kept. Work RAM ($6000-$7FFF) directly,
;   anything else through rt_izy_wr.
hle_rlefill:
            push af
            ld a, [NES_RAM + $13]
            cp $60
            jr c, .slow
            cp $80
            jr nc, .slow
            add a, $40                      ; NES $6000-$7FFF -> cart RAM $A000-$BFFF
            ld h, a
            ld a, [NES_RAM + $12]
            ld l, a
            add hl, bc                      ; + Y (B = 0)
            pop af
.lp:        ld [hl+], a
            inc c
            ret z                           ; Y wrapped (Z = 1)
            dec e
            jr nz, .lp
            inc e                           ; X = 1, Z = 0
            ret
.slow:      pop af
.sl:        push af
            ld l, $12
            call rt_izy_wr
            pop af
            inc c
            ret z
            dec e
            jr nz, .sl
            inc e
            ret

; ---- c62:C43C: clear the NES OAM buffer ($0200-$02FF = $F8), $26 = 0 (FF1's per-frame
;   sprite clear: LDX #$3F / LDA #$F8 / 4 x STA $0200..$02C0,X / DEX / BPL; LDA #0 /
;   STA $26 / RTS). Returns as its RTS: X = $FF, A = 0, Z = 1, N = 0; carry unchanged.
hle_oam_clear:
            push af                         ; (carry)
            ld hl, NES_RAM + $0200
            ld a, $F8
            ld e, 32
.lp:        ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            dec e
            jr nz, .lp
            xor a
            ld [NES_RAM + $26], a
            ldh [nzv], a
            ld e, $FF
            pop af
            ld a, 0
            inc a
            dec a                           ; Z = 1, carry kept
            ret

; ---- trampolines into the native FF1 routines (rt/ff1_native.s, bank HLE_BANK)
hle_mapdraw:
            push af
            ld a, HLE_BANK
            ld [$2000], a
            pop af
            call mapdraw_b
            jr hle_back
hle_mapattr:
            push af
            ld a, HLE_BANK
            ld [$2000], a
            pop af
            call mapattr_b
hle_back:   push af
            ldh a, [code_bank]
            ld [$2000], a
            pop af
            ret

fresh_tramp:                                ; frame wait, DMG: fresh_scan (bank HLE_BANK)
            ld a, HLE_BANK
            ld [$2000], a
            call fresh_scan
            ldh a, [code_bank]
            ld [$2000], a
            ret

hle_vtile:                                  ; far vtile (bank HLE_BANK: vtile_b)
            ld a, HLE_BANK
            ld [$2000], a
            call vtile_b
            jp hle_back

; b12:BF8F (battle, every frame): swap $0090-$009F with $6D97-$6DA6 (LDA/PHA/LDA/STA/PLA/
; STA, X 0-15). Out: X = 16, Y = 0, A = the old $009F; N = 0, Z = 1, C kept.
hle_swap90: push af
            ld hl, NES_RAM + $90
            ld de, $AD97                    ; $6D97 (cart RAM bank 0)
            ld c, 16
.l:         ld a, [de]
            ld b, [hl]
            ld [hl+], a
            ld a, b
            ld [de], a
            inc de
            dec c
            jr nz, .l
            xor a
            ldh [nzv], a
            pop hl                          ; (L = F before: keep its carry)
            ld a, l
            and $10
            or $80
            ld l, a
            ld h, b
            push hl
            pop af
            ld de, 16
            ld bc, 0
            ret

hle_ntclr:                                  ; fix:F2CF nametable clear (bank HLE_BANK: ntclr_b)
            push af
            ld a, HLE_BANK
            ld [$2000], a
            pop af
            call ntclr_b
            jp hle_back

hle_ntrun:                                  ; fix:F4EA panel row copy (bank HLE_BANK: ntrun_b)
            push af
            ld a, HLE_BANK
            ld [$2000], a
            pop af
            call ntrun_b
            jp hle_back

hle_mclr:                                  ; (bank HLE_BANK: mclr_b)
            push af
            ld a, HLE_BANK
            ld [$2000], a
            pop af
            call mclr_b
            jp hle_back

hle_wrow:                                  ; (bank HLE_BANK: wrow_b)
            push af
            ld a, HLE_BANK
            ld [$2000], a
            pop af
            call wrow_b
            jp hle_back

