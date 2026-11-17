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
            ldh a, [lcd_on]
            and a
            jp nz, .slow
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
            cp $08
            ld d, $90
            jr c, .bg0
            ld d, $80
.bg0:       and $0F
            add a, d
            ld d, a
            jr .copy
.spr:       and $07
            add a, $80
            ld d, a
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
