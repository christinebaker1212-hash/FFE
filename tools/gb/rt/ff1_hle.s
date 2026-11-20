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
            ld a, c                         ; a whole BG page (16 tiles from tile 0 of a
            and a                           ;   page), DMG with the LCD off (to the shadow)
            jr nz, .tile                    ;   or CGB with it on (to the tile copy): straight
            ldh a, [ppu_vl]                 ;   copies, the marks for the 16 tiles at once
            and a
            jr nz, .tile
            ldh a, [ppu_vh]
            cp $10
            jr nc, .fs
            ld d, a
            ldh a, [is_cgb]
            and a
            jr z, .fd
            ldh a, [lcd_on]
            and a
            jr z, .tile
            ld a, d
            add a, $D0                      ; CGB: WRAM bank 2, $D000 + tile * 16
            ld d, a
            ld e, 0
            ld a, 2
            ldh [$FF70], a
            jr .ft
.fs:        and $0F                         ; a whole sprite page: left in ROM (bank, address
                                            ;   in LZ_SRC, its tiles marked in LZ_BM: spr_mat
                                            ;   copies a tile to the shadow when a slot load or
                                            ;   a write needs it); its resident slots reloaded
                                            ;   by the next OAM conversion
            ld e, a
            ld a, 3
            ld [$4000], a
            ld a, e
            add a, a
            add a, a
            add a, low(LZ_SRC)
            ld c, a
            ld b, high(LZ_SRC)
            ldh a, [data_bank8]
            ld [bc], a
            inc c
            ld a, l
            ld [bc], a
            inc c
            ld a, h
            ld [bc], a
            ld a, e
            add a, a
            add a, low(LZ_BM)
            ld c, a
            ld a, $FF
            ld [bc], a
            inc c
            ld [bc], a
            xor a
            ld [$4000], a
            ld bc, 255                      ; (A = the page's last byte)
            add hl, bc
            ld a, [hl]
            ld bc, 0                        ; (Y = 0)
            ldh [tmp_lo], a
            ldh a, [ppu_vh]
            jr .fsm
.fd:        ldh a, [lcd_on]
            and a
            jr nz, .tile
            call bgsrc                      ; the same ROM page as last time, the shadow page
            jr z, .fsk                      ;   not written since: it holds these bytes already
            ld a, d
            add a, high(BG_SHADOW)
            ld d, a
            ld e, 0
.fb:        ld a, 1
            ld [$4000], a
.ft:
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, e
            sub 15
            ld e, a
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            dec e
            jr nz, .ft
            ldh [tmp_lo], a                 ; (last byte)
            ldh a, [ppu_vh]
            cp $10
            jr nc, .fsm
            ldh a, [is_cgb]
            and a
            jr z, .fm
            ld a, 1                         ; CGB: WRAM bank 1, the page's 16 tiles marked
            ldh [$FF70], a                  ;   for the vblank DMA
            ldh a, [ppu_vh]
            add a, a
            add a, low(BG_DIRTY)
            ld l, a
            ld h, high(BG_DIRTY)
            ld a, $FF
            ld [hl+], a
            ld [hl], a
            ld a, 1
            ldh [hd_any], a
            jr .fv
.fm:        xor a
            ld [$4000], a
            ldh a, [ppu_vh]                 ; tiles t0 = page * 16 .. + 15: CODED unknown,
            swap a                          ;   marked (DIRTY_BM), not parked (DEFER_BM)
            ld l, a
            ld h, high(CODED)
            ld b, 16
            ld a, $FF
.fc:        ld [hl+], a
            dec b
            jr nz, .fc
            ldh a, [ppu_vh]
            add a, a
            ld l, a
            ld h, high(DIRTY_BM)
            ld a, $FF
            ld [hl+], a
            ld [hl], a
            ld a, l
            add a, low(DEFER_BM) - low(DIRTY_BM)
            ld l, a
            xor a
            ld [hl-], a
            ld [hl], a
            inc a
            ldh [rq_any], a
            jr .fv                          ; (a BG page: no sprite slot to reload; this fell
                                            ;   into .fsm and made sprite tiles 16-31 reload)
.fsm:       and $0F                         ; sprite page: SLOT_KEY of its resident tiles
            swap a                          ;   unknown
            ld l, a
            ld h, high(SPR_SLOT)
            ld b, 16
.fsl:       ld a, [hl+]
            cp $FF
            jr z, .fsn
            push hl
            add a, low(SLOT_KEY)
            ld l, a
            ld h, high(SLOT_KEY)
            ld [hl], $FF
            pop hl
.fsn:       dec b
            jr nz, .fsl
            xor a
            ld [$4000], a
.fsk:       ld bc, 255                      ; (A = the page's last byte; Y = 0)
            add hl, bc
            ld a, [hl]
            ld bc, 0
            ldh [tmp_lo], a
.fv:        ldh a, [ppu_vh]                 ; v += 256
            inc a
            and $3F
            ldh [ppu_vh], a
            pop de
            ldh a, [code_bank]
            ld [$2000], a
            ld hl, NES_RAM + $11            ; INC $11 / DEX (Y stays 0)
            inc [hl]
            dec e
            jp .page
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
            jr .copy                        ; (this jump was missing: the tile went over the
                                            ;   sprite shadow and WRAM bank 2 stayed selected)
.spr:       push af                         ; (a tile still in ROM: to the shadow first)
            and $0F
            swap a
            push bc
            ld b, a
            ld a, e
            swap a
            or b                            ; tile = (vh & $0F) << 4 | vl >> 4
            pop bc
            call spr_mat
            ldh a, [data_bank8]
            ld [$2000], a
            pop af
            and $0F                         ; sprite table -> shadow (RAM bank 1)
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

maprb_tramp:                                ; CGB masked load shown: maprb_b (bank HLE_BANK)
            ld a, HLE_BANK
            ld [$2000], a
            call maprb_b
            ldh a, [code_bank]
            ld [$2000], a
            ret

vshow_tramp:                                ; frame wait, CGB masked load shown: vshow_def
            ld a, PF_BANK                   ;   (bank PF_BANK)
            ld [$2000], a
            call vshow_def
            ldh a, [code_bank]
            ld [$2000], a
            ret

repal_tramp:                                ; LCD on, CGB: repal_b (bank HLE_BANK)
            ld a, HLE_BANK
            ld [$2000], a
            call repal_b
            ldh a, [code_bank]
            ld [$2000], a
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
hle_vstr:                                   ; far vstr (bank HLE_BANK: vstr_b)
            push af
            ld a, HLE_BANK
            ld [$2000], a
            pop af
            call vstr_b
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

hle_palup:                                  ; c62:D865 palette upload (bank HLE_BANK: palup_b)
            push af
            ld a, HLE_BANK
            ld [$2000], a
            pop af
            call palup_b
            jp hle_back

hle_palup2:                                 ; c62:D874 palette upload from X (palup2_b)
            push af
            ld a, HLE_BANK
            ld [$2000], a
            pop af
            call palup2_b
            jp hle_back


hle_pgcopy:                                 ; c62:C324 page copy (pgcopy_b, bank HLE_BANK, run
            ld b, a                         ;   with code_bank = HLE_BANK: its byte path's
            ldh a, [code_bank]              ;   helpers come back to it); flags kept both ways
            push af
            ld a, HLE_BANK
            ldh [code_bank], a
            ld [$2000], a
            ld a, b
            ld b, 0
            call pgcopy_b
            ld b, a
            pop hl
            ld a, h
            ldh [code_bank], a
            ld [$2000], a
            ld a, b
            ld b, 0
            ret

; ---- fix:F618-F624 (battle panel cleared): LDY #0 / LDA #0 / 256 x (STA $691E,Y / STA
; $699E,Y): $691E-$6A9D zeroed. Out: A = Y = 0, X kept; N = 0, Z = 1, C kept.
hle_pclr:   push af
            push hl
            ld hl, $A91E                    ; ($691E, cart RAM bank 0)
            xor a
            ld b, 192                       ; 384 bytes
.l:         ld [hl+], a
            ld [hl+], a
            dec b
            jr nz, .l
            ldh [nzv], a
            pop hl
            pop af
            ld c, 0
            ld a, 1
            dec a                           ; (Z = 1, carry kept)
            ret

; ---- fix:FA5B-FA66: LDY #0 / 64 x (LDA ($90),Y / STA $5F80,Y): 64 bytes to ExRAM $5F80.
; Out: A = the last byte, Y = $40, X kept; N = 0, Z = 1, C = 1.
hle_cp64:   ld a, [NES_RAM + $90]           ; source in one 8 KB area of ROM or save RAM:
            ld l, a                         ;   one bank switch, then a plain copy
            ld a, [NES_RAM + $91]
            ld h, a
            ld a, l
            add a, $3F
            ld a, h
            adc a, 0
            xor h
            and $E0
            jr nz, .slow                    ; (crosses an 8 KB boundary: byte by byte)
            ld a, h
            cp $60
            jr nc, .hi
            cp $5C
            jr c, .slow
            add a, $6C                      ; ExRAM $5C00 -> $C800
            ld h, a
            jr .cp
.hi:
            cp $80
            jr nc, .rom
            add a, $40                      ; save RAM $6000 -> $A000
            ld h, a
            jr .cp
.rom:       cp $C0
            jr nc, .rc
            sub $40                         ; $8000-$BFFF: data_bank8 at $4000
            ld h, a
            ldh a, [data_bank8]
            jr .bk
.rc:        cp $E0
            jr nc, .re
            sub $80                         ; $C000-$DFFF: data_bankC at $4000
            ld h, a
            ldh a, [data_bankC]
            jr .bk
.re:        sub $80                         ; $E000-$FFFF: the fixed bank's data at $6000
            ld h, a
            ld a, DATA + 31
.bk:        ld [$2000], a
.cp:        push de                         ; (E = X: kept)
            ld de, EX_RAM + $380
            ld c, $40
.cl:        ld a, [hl+]
            ld [de], a
            inc e
            dec c
            jr nz, .cl
            pop de
            ld b, a
            ldh a, [code_bank]
            ld [$2000], a
            ld c, $40
            jr .out
.slow:      ld c, 0
.l:         ld a, [NES_RAM + $90]
            ld l, a
            ld a, [NES_RAM + $91]
            ld h, a
            ld b, 0
            add hl, bc
            call nes_rd
            ld a, c
            add a, low(EX_RAM + $380)
            ld h, high(EX_RAM + $380)
            ld b, l
            ld l, a
            ld [hl], b
            inc c
            ld a, c
            cp $40
            jr nz, .l
.out:       xor a
            ldh [nzv], a
            ld a, b                         ; A = the last byte; Z = 1, C = 1 (CPY #$40)
            ld b, 0
            push af
            pop hl
            ld l, $90
            push hl
            pop af
            ret

; ---- fix:FCC7-FCD7: LDX #$0F / 16 x swap $90,X with $6D74,X (through the stack). Out:
; X = $FF, A = the old $90, Y kept; N = 1, Z = 0, C kept.
hle_sw16:   push af
            push bc
            ld hl, NES_RAM + $90
            ld de, $AD74                    ; ($6D74)
            ld b, 16
.l:         ld a, [de]
            ld c, [hl]
            ld [hl+], a
            ld a, c
            ld [de], a
            inc de
            dec b
            jr nz, .l
            ld a, $80
            ldh [nzv], a
            pop bc
            pop af
            ld de, $00FF                    ; X = $FF
            ld a, 2
            dec a                           ; (Z = 0, carry kept)
            ld a, [$AD74]
            ret

hle_vclear:                                 ; far vclear (bank HLE_BANK: vclear_b)
            ld a, HLE_BANK
            ld [$2000], a
            call vclear_b
            jp hle_back
