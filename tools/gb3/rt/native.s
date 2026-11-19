; FF3 native routines: GB versions of hot NES routines (translate.py FF3.ext), each with the
; same RAM effects, registers and flags at its RTS as the NES routine (checked by RAM
; equivalence, tools/gb3/firstdiff.py). ROM data is read straight from the data bank (one
; bank switch per routine instead of one per byte). Bank 0 (after the runtime).

; ------------------------------------------------------------------ p32:9111
; animation function $00: draw character sprite (battle; for each character every frame).
; In: X (E) = character slot; $90 frame id, $91 flip, $8C / $8E x / y, $98 back attack.
; NES data: bank $32 at $8000 (the code's own bank): $926B / $9280 (frame -> position and
; flip data id), $91CB (pointers to 24-byte position / flip data), $9295 (tile offset per
; character), $972E + 6 * frame (tiles of the 6 sprites). Writes $7300-$7317 (sprite
; buffer), $0200 + $C8.. (24 bytes), $C8, $7E / $7F, $82, $83, and $18-$1B through the
; NES multiply ($F8EA, called translated). Out: A = X = the slot, Y = $18, N / Z of X, C = 1.
NAT_B32    = DATA + $19                     ; GB bank of NES banks $32 / $33
nat_9111:   ld a, e
            ldh [nt_x], a
            ld a, NAT_B32
            ld [MBC5_BANKL], a
            ld a, [NES_RAM + $90]           ; Y = frame id
            ld c, a
            ld a, [NES_RAM + $91]
            and a
            ld hl, $4000 + $926B - $8000
            jr z, .t
            ld hl, $4000 + $9280 - $8000
.t:         add hl, bc
            ld a, [hl]                      ; position and flip data id
            add a, a
            ld c, a
            ld hl, $4000 + $91CB - $8000
            add hl, bc
            ld a, [hl+]                     ; (NES $7E / $7F hold this pointer until the
            ld [NES_RAM + $7E], a           ;   tile pointer replaces it below)
            ld a, [hl]
            ld [NES_RAM + $7F], a
            ldh a, [nt_x]                   ; $82 = tile offset ($9295 + X)
            ld l, a
            ld h, 0
            ld bc, $4000 + $9295 - $8000
            add hl, bc
            ld a, [hl]
            ld [NES_RAM + $82], a
            ldh a, [nt_x]                   ; $83 = palette | palette override
            add a, $93
            ld l, a
            ld h, $BD                       ; ($7D93 + X, $7D97 + X: X < 4)
            ld a, [hl]
            inc l
            inc l
            inc l
            inc l
            or [hl]
            ld [NES_RAM + $83], a
            ldh [n9_at], a
            ld a, [NES_RAM + $8E]
            ldh [n9_y], a
            ld a, [NES_RAM + $8C]
            ldh [n9_x], a
            ld bc, 0
            ld a, [NES_RAM + $90]           ; the NES multiply ($F8EA: JSR $FCD6 with A = frame,
            ld [NES_RAM + $18], a           ;   X = 6, C = 1) leaves $18 = A, $19 = the carry
            ld l, a                         ;   in (1), $1B:$1A = 6 * frame
            ld h, 0
            add hl, hl
            ld d, h
            ld e, l
            add hl, hl
            add hl, de
            ld d, 0
            ld a, 1
            ld [NES_RAM + $19], a
            ld a, h
            ld [NES_RAM + $1B], a
            ld e, a
            ld a, l
            ld [NES_RAM + $1A], a
            add a, $2E                      ; $7E / $7F = $972E + 6 * frame (tiles)
            ld l, a
            ld a, e
            adc a, $97
            sub $40
            ld h, a
            ld a, NAT_B32
            ld [MBC5_BANKL], a
            ld a, [NES_RAM + $82]           ; the 6 tiles -> $7301 + 4i: bit 7 set: the value,
            ld c, a                         ;   else + $82
            ld de, $B301
.tl:        ld a, [hl+]
            bit 7, a
            jr z, .ta
            and $7F
            jr .ts
.ta:        add a, c
.ts:        ld [de], a
            ld a, e
            add a, 4
            ld e, a
            cp 25
            jr nz, .tl
            ld a, l                         ; (NES $7E / $7F: the tile pointer)
            sub 6
            ld [NES_RAM + $7E], a
            ld a, h
            sbc a, 0
            add a, $40
            ld [NES_RAM + $7F], a
            ld a, [NES_RAM + $90]
            ld c, a
            ld b, 0
            ld a, [NES_RAM + $91]
            and a
            ld hl, $4000 + $926B - $8000
            jr z, .t2
            ld hl, $4000 + $9280 - $8000
.t2:        add hl, bc
            ld a, [hl]
            add a, a
            ld c, a
            ld hl, $4000 + $91CB - $8000
            add hl, bc
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld a, h
            sub $40
            ld h, a                         ; HL = position / flip data (GB)
            ld de, $B300
            ld a, [NES_RAM + $98]           ; back attack gets an h-flip ($90D2: $78C3 = $88)
            and a
            jr z, .pl
            ld a, [$B8C3]
            cp $88
            jr z, .pb
.pl:        ldh a, [n9_y]                   ; y += $8E
            add a, [hl]
            inc hl
            ld [de], a
            inc e
            inc hl                          ; (tile: done above)
            inc e
            ldh a, [n9_at]                  ; attributes |= $83
            or [hl]
            inc hl
            ld [de], a
            inc e
            ldh a, [n9_x]                   ; x += $8C
            add a, [hl]
            inc hl
            ld [de], a
            inc e
            ld a, e
            cp 24
            jr nz, .pl
            jr .cp
.pb:        ldh a, [n9_y]                   ; (back attack: x = 248 - (x + $8C), h-flip)
            add a, [hl]
            inc hl
            ld [de], a
            inc e
            inc hl
            inc e
            ldh a, [n9_at]
            or [hl]
            xor $40
            inc hl
            ld [de], a
            inc e
            ldh a, [n9_x]
            add a, [hl]
            inc hl
            cpl
            add a, $F9
            ld [de], a
            inc e
            ld a, e
            cp 24
            jr nz, .pb
.cp:        ldh a, [code_bank]
            ld [MBC5_BANKL], a
            ld a, [NES_RAM + $C8]           ; buffer -> $0200 + $C8 (X wraps in the page)
            ld e, a
            ld d, high(NES_RAM + $200)
            ld hl, $B300
            ld c, 12
.c2:        ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            dec c
            jr nz, .c2
            ld a, e
            ld [NES_RAM + $C8], a
            ld d, 0
            ld c, $18                       ; Y = $18
            ldh a, [nt_x]                   ; A = X = the slot (PLA / TAX): N, Z; C = 1
            ld e, a
            ldh [nzv], a
            scf
            inc a
            dec a
            ret

; ------------------------------------------------------------------ fix:F98E idiom
; copy graphics to ppu, inner loop (LDY #0 / LDA ($7E),Y / [$92: TAX / LDA $7300,X] /
; STA $2007 / INY / CPY #$40 / BNE): 64 bytes straight into the CHR staging copy when the PPU
; address is in the pattern tables with increment 1 (else through $2007). Out as the loop:
; Y = $40, A = the last byte written, X = $92 (0) or the last source byte, Z = 1, C = 1, N = 0.
nat_chr64:
            ld a, $40
            ldh [ch_n], a
            xor a
            ldh [wc_n], a                   ; (the PPU address moves: no cached run)
             ld c, 0                         ; Y
            ldh a, [ppu_ctrl]
            and 4
            jr nz, .slow
            ldh a, [ppu_vh]
            cp $20
            jr nc, .slow
            call chr64_fast                 ; (whole tiles from one ROM window: NC)
            jr nc, .end
.lp:        call .byte
            push bc
            ld c, a                         ; chr_put: C = value, HL = NES address
            ldh a, [ppu_vl]
            ld l, a
            ldh a, [ppu_vh]
            ld h, a
            call chr_put
            ldh a, [ppu_vl]
            inc a
            ldh [ppu_vl], a
            jr nz, .ni
            ldh a, [ppu_vh]
            inc a
            ldh [ppu_vh], a
.ni:        pop bc
            inc c
            ld a, c
            cp $40
            jr nz, .lp
.end:       ld d, 0
            ld b, 0
            ldh a, [nt_x]
            ld e, a
            xor a                           ; N = 0, Z = 1, C = 1
            ldh [nzv], a
            scf
            ldh a, [nt_a]
            ret
.slow:      ldh a, [ppu_ctrl]               ; nametables with step 1: gather the 64 bytes,
            and 4                           ;   then rt_ppu_copy's runs (whole map-row pieces)
            jr nz, .slw
            ldh a, [ppu_vh]
            cp $20
            jr c, .slw
            cp $3F
            jr nc, .slw
.gb:        call .byte                      ; (C = Y = 0 .. 63)
            ld hl, NC_BUF
            ld b, 0
            add hl, bc
            ld [hl], a
            inc c
            ld a, c
            cp $40
            jr nz, .gb
            ldh a, [ppu_vl]                 ; a whole attribute table ($23C0 / $27C0 / ..):
            cp $C0                          ;   only the bytes that changed
            jr nz, .ncp
            ldh a, [ppu_vh]
            and 3
            cp 3
            jr nz, .ncp
            call attr_put64
            jr .end
.ncp:       ld a, $40
            ldh [cp_n], a
            ld hl, NC_BUF
            xor a
            call rt_ppu_copy
            jr .end
.slw:       call .byte
            call rt_ppu_w7
            inc c
            ld a, c
            cp $40
            jr nz, .slw
            jr .end
.byte:      ld l, $7E                       ; A = the byte to write; nt_x = X, nt_a = A
            call rt_izy_rd
            ld a, [NES_RAM + $92]
            and a
            ld a, l
            jr z, .nf
            ldh [nt_x], a
            ld l, a
            ld h, $B3                       ; flip table $7300 (GB $B300)
            ld a, [hl]
            ldh [nt_a], a
            ret
.nf:        ldh [nt_a], a
            xor a
            ldh [nt_x], a
            ldh a, [nt_a]
            ret

; NC_BUF (64 bytes) -> the attribute table at the PPU address ($2xC0, increment 1): the
; nametable shadow, and attr_apply for each byte that changed; PPU address + 64. C kept.
attr_put64:
            push bc
            ldh a, [ppu_vh]                 ; B = nametable 0 / 1 after mirroring (as rt_ppu_w7)
            and $0F
            rrca
            rrca
            and 3
            ld b, a
            ldh a, [mirror]
            and a
            ld a, b
            jr z, .vm
            srl a
            jr .nt
.vm:        and 1
.nt:        ld b, a
            ld c, 0                         ; C = index 0-63
.lp:        ld a, b                         ; HL = NT_SH + n * $400 + $3C0 + index
            add a, a
            add a, a
            add a, high(NT_SH) + 3
            ld h, a
            ld a, c
            add a, $C0
            ld l, a
            ld a, [hl]
            ld d, a                         ; D = old
            push hl
            ld hl, NC_BUF
            ld a, l
            add a, c
            ld l, a
            ld a, [hl]                      ; A = new
            pop hl
            cp d
            jr z, .same
            ld [hl], a
            ld e, a
            ld a, d
            ldh [c_q], a
            ld a, e
            ld l, c
            call attr_apply                 ; (keeps B, C)
.same:      inc c
            ld a, c
            cp $40
            jr nz, .lp
            ldh a, [ppu_vh]                 ; PPU address + 64 ($xxC0 -> next page)
            inc a
            and $3F
            ldh [ppu_vh], a
            xor a
            ldh [ppu_vl], a
            pop bc
            ret

; fast path of nat_chr64: PPU address tile-aligned, source ($7E) + 63 in one ROM window.
; 4 tiles: source read in place (one bank switch), flip table applied, written to the staging
; copy in GB row order, each tile marked once. Returns NC when done (Y = $40, nt_a / nt_x
; set, the PPU address advanced), C when it does not apply (nothing changed).
chr64_fast: ldh a, [ppu_vl]
            and $0F
            jr nz, .no
            ld a, [NES_RAM + $7E]           ; source -> GB bank (A) + address (HL)
            ld l, a
            ld a, [NES_RAM + $7F]
            ld h, a
            ldh a, [ch_n]                   ; (no window change within the bytes)
            dec a
            add a, l
            ld a, h
            adc a, 0
            xor h
            and $E0
            jr nz, .no
            ld a, h
            cp $80
            jr c, .lowsrc
            cp $A0
            jr nc, .ha
            and $1F
            or $40
            ld h, a
            ldh a, [odd8]
            or h
            ld h, a
            ldh a, [data_bank8]
            jr .src
.ha:        cp $C0
            jr nc, .hf
            and $1F
            or $40
            ld h, a
            ldh a, [oddA]
            or h
            ld h, a
            ldh a, [data_bankA]
            jr .src
.hf:        sub $80
            ld h, a
            ld a, DATA + 63
            jr .src
.lowsrc:    cp $60                          ; PRG-RAM $6000-$7FFF (decompressed graphics) ->
            jr c, .ramsrc                   ;   GB $A000; RAM $0000-$07FF -> $C000
            add a, $40
            ld h, a
            ldh a, [code_bank]              ; (no ROM bank needed)
            jr .src
.ramsrc:    cp $08
            jr nc, .no
            add a, high(NES_RAM)
            ld h, a
            ldh a, [code_bank]
.src:       ld [MBC5_BANKL], a
            push hl                         ; mark the 4 tiles dirty
            ldh a, [ppu_vl]
            ld l, a
            ldh a, [ppu_vh]
            ld h, a
            ldh a, [ch_n]                   ; (tiles = bytes / 16)
            swap a
            and $0F
            ld c, a
.mk:        push hl
            call tile_mark
            pop hl
            ld a, l
            add a, 16
            ld l, a
            jr nc, .mk2
            inc h
.mk2:       dec c
            jr nz, .mk
            ldh a, [ppu_vh]                 ; staging bank and destination
            ld h, a
            and $10
            swap a
            add a, 2
            ldh [rSVBK], a
            ld a, h
            and $0F
            or high(STAGE)
            ld d, a
            ldh a, [ppu_vl]
            ld e, a
            pop hl
            ld a, [NES_RAM + $92]           ; flip table on: the slow loop
            and a
            jr nz, .flp
            ldh a, [ch_n]                   ; plane 0 -> even, plane 1 -> odd bytes
            ld c, a
.pl:        ld a, [hl+]
            ld [de], a
            inc e
            inc e
            dec c
            ld a, c
            and 7
            jr nz, .pl
            ld a, e                         ; after 8 bytes: plane 1 (-15) or next tile (-1)
            bit 3, c
            jr z, .np
            sub 15
            ld e, a
            jr .pl
.np:        dec a
            ld e, a
            jr nz, .pl2
            inc d
.pl2:       ld a, c
            and a
            jr nz, .pl
            dec hl                          ; A = the last byte (no table: X = $92 = 0)
            ld a, [hl]
            ldh [nt_a], a
            xor a
            ldh [nt_x], a
            jr .done
.flp:       ld b, a
            ldh a, [ch_n]
            swap a
            and $0F
            ld c, a
.tile:      push bc
            ld c, 8                         ; plane 0 -> even bytes
.p0:        ld a, [hl+]
            call .flip
            ld [de], a
            inc e
            inc e
            dec c
            jr nz, .p0
            ld a, e
            sub 15
            ld e, a
            ld c, 8                         ; plane 1 -> odd bytes
.p1:        ld a, [hl+]
            call .flip
            ld [de], a
            inc e
            inc e
            dec c
            jr nz, .p1
            dec e                           ; next tile
            ld a, e
            and a
            jr nz, .t2
            inc d
.t2:        pop bc
            dec c
            jr nz, .tile
.done:
            ld a, 1
            ldh [rSVBK], a
            ldh a, [code_bank]
            ld [MBC5_BANKL], a
            ld a, 1
            ldh [chr_dirty], a
            ldh a, [ch_n]                   ; PPU address + the bytes, Y = the bytes
            ld c, a
            ldh a, [ppu_vl]
            add a, c
            ldh [ppu_vl], a
            jr nc, .v
            ldh a, [ppu_vh]
            inc a
            ldh [ppu_vh], a
.v:
            and a                           ; NC: done
            ret
.no:        scf
            ret
.flip:      ldh [nt_x], a                   ; the source byte: X if the table is on
            inc b
            dec b
            jr z, .nf
            push hl
            ld l, a
            ld h, $B3                       ; flip table $7300 (GB $B300)
            ld a, [hl]
            pop hl
            ldh [nt_a], a
            ret
.nf:        ldh [nt_a], a
            xor a
            ldh [nt_x], a
            ldh a, [nt_a]
            ret

; ------------------------------------------------------------------ fix:F897
; copy color palettes to ppu ($7CF7-$7D16 -> $3F00-$3F1F, every battle frame): straight into
; the palette shadow (writes to $3F10/14/18/1C land on $3F00/04/08/0C, as on the NES), the
; CGB palettes reloaded only if a colour changed. PPU state as after the NES loop: latch
; reset, address $3F20. Out: X = $20, A = the last colour, Z = 1, C = 1, N = 0.
nat_f897:
            push af
            xor a
            ldh [wc_n], a                   ; (the PPU address moves: no cached run)
            pop af
              ld a, c                         ; (Y is kept)
            ldh [nt_x], a
            ld hl, $BCF7                    ; PRG-RAM $7CF7
            ld de, PAL_SH
            ld c, 0                         ; C = palette index 0-31
.lp:        ld a, c
            and $13
            cp $10
            ld a, c
            jr nz, .k
            and $0F
.k:         add a, low(PAL_SH)
            ld e, a
            ld a, [hl+]
            and $3F
            ld b, a
            ld a, [de]
            cp b
            jr z, .same
            ld a, b
            ld [de], a
            ld a, 1
            ldh [pal_dirty], a
.same:      inc c
            ld a, c
            cp $20
            jr nz, .lp
            ldh a, [nt_x]
            ld c, a
            xor a
            ldh [ppu_latch], a
            ldh [ppu_stat], a               ; (BIT $2002 in the set-address routine)
            ldh [nzv], a
            ld a, $3F
            ldh [ppu_vh], a
            ld a, $20
            ldh [ppu_vl], a
            ld e, $20
            ld d, 0
            ld b, 0
            ld a, [$BD16]                   ; A = $7D16 (the last byte)
            scf                             ; C = 1, Z = 1 (CPX #$20)
            ld h, a
            ld a, 0
            inc a
            dec a
            ld a, h
            ret

; ------------------------------------------------------------------ p2e:9F98
; clear vram ($0000-$2FFF through $2007): staging copy and nametable shadow cleared, every
; tile marked, the GB map cleared and the attributes reset (palette 0, the BG table's bank)
; by DMA in the next vblank (map_flush). Out: A = X = Y = 0, Z = 1, N = 0, C kept;
; PPU address $3000, latch reset.
nat_9f98:
            push af
            xor a
            ldh [wc_n], a                   ; (the PPU address moves: no cached run)
            pop af
              push af
            ld a, 2                         ; staging tables (WRAM banks 2, 3)
.sb:        ldh [rSVBK], a
            ld hl, STAGE
            xor a
            ld b, 0                         ; 256 x 16 bytes
.c1:        ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            dec b
            jr nz, .c1
            ldh a, [rSVBK]
            inc a
            cp 4
            jr c, .sb
            ld a, 1
            ldh [rSVBK], a
            ld hl, NT_SH                    ; nametables
.c2:        xor a
            ld [hl+], a
            ld a, h
            cp high(NT_SH) + 8
            jr c, .c2
            ld a, MAP_BANK                  ; GB map: tile 0; attributes: palette 0, the BG
            ldh [rSVBK], a                  ;   table's bank
            ld hl, MAP_SH
.c5:        xor a
            ld [hl+], a
            ld a, h
            cp high(MAP_SH) + 4
            jr c, .c5
            ldh a, [bg_bank]
            ld b, a
.c3:        ld a, b
            ld [hl+], a
            ld a, h
            cp high(ATTR_SH) + 4
            jr c, .c3
            ld a, 1
            ldh [rSVBK], a
            ld a, $FF
            ld hl, map_dirty                ; (map_dirty, attr_dirty: 8 bytes in a row)
            ld b, 8
.c6:        ld [hl+], a
            dec b
            jr nz, .c6
            ld hl, TILE_DIRTY               ; all 512 tiles
            ld a, $FF
.c4:        ld [hl+], a
            inc l
            dec l
            jr nz, .c4
            ld a, 1
            ldh [chr_dirty], a
            ldh [map_any], a
            xor a
            ldh [mr_hi], a
            dec a
            ldh [tm_hi], a
            xor a
            ldh [ppu_latch], a
            ldh [ppu_stat], a
            ldh [ppu_vl], a
            ldh [nzv], a
            ld a, $30
            ldh [ppu_vh], a
            ld bc, 0
            ld de, 0
            pop af                          ; (C kept)
            ld a, 0
            inc a
            dec a                           ; Z = 1
            ret

; ------------------------------------------------------------------ fix:FCF5
; multiply (16-bit): $1C-$1F = $18:$19 * $1A:$1B, the NES loop step for step in registers
; (same final $1A-$1F, A, carry). In: C (6502 carry) as the NES reads it. Out: X = 0, A = the
; last $1F computed (0 if none), Z = 1, N = 0, C from the last ROR; Y kept.
nat_fcf5:   push af                         ; (unrolled: 16 steps)
            ld a, c
            ldh [nt_y], a
            ld a, [NES_RAM + $18]
            ldh [n9_y], a
            ld a, [NES_RAM + $19]
            ldh [n9_x], a
            ld a, [NES_RAM + $1A]
            ld c, a
            ld a, [NES_RAM + $1B]
            ld b, a
            ld de, 0                        ; D = $1F, E = $1E
            ld hl, 0                        ; H = $1D, L = $1C
            pop af                          ; (the incoming carry)
            ld a, 0
            rr b                            ; ROR $1B / ROR $1A
            rr c
            jr nc, .s0
            ldh a, [n9_y]                   ; CLC / ADC: $1E += $18, $1F += $19 + carry
            add a, e
            ld e, a
            ldh a, [n9_x]
            adc a, d
            ld d, a                         ; (A = the last $1F computed)
.s0:        rr d                            ; ROR $1F $1E $1D $1C
            rr e
            rr h
            rr l
            rr b                            ; ROR $1B / ROR $1A
            rr c
            jr nc, .s1
            ldh a, [n9_y]                   ; CLC / ADC: $1E += $18, $1F += $19 + carry
            add a, e
            ld e, a
            ldh a, [n9_x]
            adc a, d
            ld d, a                         ; (A = the last $1F computed)
.s1:        rr d                            ; ROR $1F $1E $1D $1C
            rr e
            rr h
            rr l
            rr b                            ; ROR $1B / ROR $1A
            rr c
            jr nc, .s2
            ldh a, [n9_y]                   ; CLC / ADC: $1E += $18, $1F += $19 + carry
            add a, e
            ld e, a
            ldh a, [n9_x]
            adc a, d
            ld d, a                         ; (A = the last $1F computed)
.s2:        rr d                            ; ROR $1F $1E $1D $1C
            rr e
            rr h
            rr l
            rr b                            ; ROR $1B / ROR $1A
            rr c
            jr nc, .s3
            ldh a, [n9_y]                   ; CLC / ADC: $1E += $18, $1F += $19 + carry
            add a, e
            ld e, a
            ldh a, [n9_x]
            adc a, d
            ld d, a                         ; (A = the last $1F computed)
.s3:        rr d                            ; ROR $1F $1E $1D $1C
            rr e
            rr h
            rr l
            rr b                            ; ROR $1B / ROR $1A
            rr c
            jr nc, .s4
            ldh a, [n9_y]                   ; CLC / ADC: $1E += $18, $1F += $19 + carry
            add a, e
            ld e, a
            ldh a, [n9_x]
            adc a, d
            ld d, a                         ; (A = the last $1F computed)
.s4:        rr d                            ; ROR $1F $1E $1D $1C
            rr e
            rr h
            rr l
            rr b                            ; ROR $1B / ROR $1A
            rr c
            jr nc, .s5
            ldh a, [n9_y]                   ; CLC / ADC: $1E += $18, $1F += $19 + carry
            add a, e
            ld e, a
            ldh a, [n9_x]
            adc a, d
            ld d, a                         ; (A = the last $1F computed)
.s5:        rr d                            ; ROR $1F $1E $1D $1C
            rr e
            rr h
            rr l
            rr b                            ; ROR $1B / ROR $1A
            rr c
            jr nc, .s6
            ldh a, [n9_y]                   ; CLC / ADC: $1E += $18, $1F += $19 + carry
            add a, e
            ld e, a
            ldh a, [n9_x]
            adc a, d
            ld d, a                         ; (A = the last $1F computed)
.s6:        rr d                            ; ROR $1F $1E $1D $1C
            rr e
            rr h
            rr l
            rr b                            ; ROR $1B / ROR $1A
            rr c
            jr nc, .s7
            ldh a, [n9_y]                   ; CLC / ADC: $1E += $18, $1F += $19 + carry
            add a, e
            ld e, a
            ldh a, [n9_x]
            adc a, d
            ld d, a                         ; (A = the last $1F computed)
.s7:        rr d                            ; ROR $1F $1E $1D $1C
            rr e
            rr h
            rr l
            rr b                            ; ROR $1B / ROR $1A
            rr c
            jr nc, .s8
            ldh a, [n9_y]                   ; CLC / ADC: $1E += $18, $1F += $19 + carry
            add a, e
            ld e, a
            ldh a, [n9_x]
            adc a, d
            ld d, a                         ; (A = the last $1F computed)
.s8:        rr d                            ; ROR $1F $1E $1D $1C
            rr e
            rr h
            rr l
            rr b                            ; ROR $1B / ROR $1A
            rr c
            jr nc, .s9
            ldh a, [n9_y]                   ; CLC / ADC: $1E += $18, $1F += $19 + carry
            add a, e
            ld e, a
            ldh a, [n9_x]
            adc a, d
            ld d, a                         ; (A = the last $1F computed)
.s9:        rr d                            ; ROR $1F $1E $1D $1C
            rr e
            rr h
            rr l
            rr b                            ; ROR $1B / ROR $1A
            rr c
            jr nc, .s10
            ldh a, [n9_y]                   ; CLC / ADC: $1E += $18, $1F += $19 + carry
            add a, e
            ld e, a
            ldh a, [n9_x]
            adc a, d
            ld d, a                         ; (A = the last $1F computed)
.s10:        rr d                            ; ROR $1F $1E $1D $1C
            rr e
            rr h
            rr l
            rr b                            ; ROR $1B / ROR $1A
            rr c
            jr nc, .s11
            ldh a, [n9_y]                   ; CLC / ADC: $1E += $18, $1F += $19 + carry
            add a, e
            ld e, a
            ldh a, [n9_x]
            adc a, d
            ld d, a                         ; (A = the last $1F computed)
.s11:        rr d                            ; ROR $1F $1E $1D $1C
            rr e
            rr h
            rr l
            rr b                            ; ROR $1B / ROR $1A
            rr c
            jr nc, .s12
            ldh a, [n9_y]                   ; CLC / ADC: $1E += $18, $1F += $19 + carry
            add a, e
            ld e, a
            ldh a, [n9_x]
            adc a, d
            ld d, a                         ; (A = the last $1F computed)
.s12:        rr d                            ; ROR $1F $1E $1D $1C
            rr e
            rr h
            rr l
            rr b                            ; ROR $1B / ROR $1A
            rr c
            jr nc, .s13
            ldh a, [n9_y]                   ; CLC / ADC: $1E += $18, $1F += $19 + carry
            add a, e
            ld e, a
            ldh a, [n9_x]
            adc a, d
            ld d, a                         ; (A = the last $1F computed)
.s13:        rr d                            ; ROR $1F $1E $1D $1C
            rr e
            rr h
            rr l
            rr b                            ; ROR $1B / ROR $1A
            rr c
            jr nc, .s14
            ldh a, [n9_y]                   ; CLC / ADC: $1E += $18, $1F += $19 + carry
            add a, e
            ld e, a
            ldh a, [n9_x]
            adc a, d
            ld d, a                         ; (A = the last $1F computed)
.s14:        rr d                            ; ROR $1F $1E $1D $1C
            rr e
            rr h
            rr l
            rr b                            ; ROR $1B / ROR $1A
            rr c
            jr nc, .s15
            ldh a, [n9_y]                   ; CLC / ADC: $1E += $18, $1F += $19 + carry
            add a, e
            ld e, a
            ldh a, [n9_x]
            adc a, d
            ld d, a                         ; (A = the last $1F computed)
.s15:        rr d                            ; ROR $1F $1E $1D $1C
            rr e
            rr h
            rr l
            push af
            ld a, c
            ld [NES_RAM + $1A], a
            ld a, b
            ld [NES_RAM + $1B], a
            ld a, l
            ld [NES_RAM + $1C], a
            ld a, h
            ld [NES_RAM + $1D], a
            ld a, e
            ld [NES_RAM + $1E], a
            ld a, d
            ld [NES_RAM + $1F], a
            ld de, 0                        ; X = 0
            ld b, 0
            ldh a, [nt_y]
            ld c, a
            xor a
            ldh [nzv], a
            pop af                          ; A = the last $1F computed, carry of the last ROR
            ld h, 0                         ; Z = 1 (DEX): from a register known to be 0
            inc h
            dec h
            ret

; ------------------------------------------------------------------ fix:FC92
; divide (16-bit): $1C = $18:$19 / $1A:$1B, $1E = remainder, the NES loop step for step (same
; final $18-$1F, A, carry). In: C (6502 carry). Out: as the NES RTS (early exit: A = 0, Z = 1,
; X kept; else X = 0, A = $1F, Z = 1, N = 0, C from the last ROL); Y kept.
nat_fc92:   push af
            xor a
            ld [NES_RAM + $1C], a
            ld [NES_RAM + $1D], a
            ld [NES_RAM + $1E], a
            ld [NES_RAM + $1F], a
            ld a, [NES_RAM + $18]
            ld h, a
            ld a, [NES_RAM + $19]
            or h
            jr z, .zero
            ld a, [NES_RAM + $1A]
            ld h, a
            ld a, [NES_RAM + $1B]
            or h
            jr z, .zero
            ld a, c
            ldh [nt_y], a
            ld a, [NES_RAM + $18]           ; HL = dividend ($19:$18), shifted out as the
            ld l, a                         ;   quotient bits come in: HL = quotient ($1D:$1C)
            ld a, [NES_RAM + $19]
            ld h, a
            ld a, [NES_RAM + $1A]
            ld c, a
            ld a, [NES_RAM + $1B]
            ld b, a                         ; BC = divisor, DE = remainder ($1F:$1E)
            ld de, 0
            pop af                          ; the NES's ROL $18 takes the incoming carry first,
            ld a, 0                         ;   then the zeros ROL $1D shifts out: $18:$19 end
            rra                             ;   as 0 : C << 7; the last ROL leaves C = 0
            ldh [nt_a], a
            ld a, 4
            ldh [nt_x], a
.lp:
            add hl, hl                      ; (dividend out of H, quotient bit into L)
            rl e
            rl d
            ld a, e                         ; SEC / SBC: remainder - divisor
            sub c
            ld e, a
            ld a, d
            sbc a, b
            ld d, a
            jr nc, .q0
            ld a, e                         ; borrow: restore (ADC), quotient bit 0
            add a, c
            ld e, a
            ld a, d
            adc a, b
            ld d, a
            jr .n0
.q0:        inc l                           ; quotient bit 1
.n0:
            add hl, hl                      ; (dividend out of H, quotient bit into L)
            rl e
            rl d
            ld a, e                         ; SEC / SBC: remainder - divisor
            sub c
            ld e, a
            ld a, d
            sbc a, b
            ld d, a
            jr nc, .q1
            ld a, e                         ; borrow: restore (ADC), quotient bit 0
            add a, c
            ld e, a
            ld a, d
            adc a, b
            ld d, a
            jr .n1
.q1:        inc l                           ; quotient bit 1
.n1:
            add hl, hl                      ; (dividend out of H, quotient bit into L)
            rl e
            rl d
            ld a, e                         ; SEC / SBC: remainder - divisor
            sub c
            ld e, a
            ld a, d
            sbc a, b
            ld d, a
            jr nc, .q2
            ld a, e                         ; borrow: restore (ADC), quotient bit 0
            add a, c
            ld e, a
            ld a, d
            adc a, b
            ld d, a
            jr .n2
.q2:        inc l                           ; quotient bit 1
.n2:
            add hl, hl                      ; (dividend out of H, quotient bit into L)
            rl e
            rl d
            ld a, e                         ; SEC / SBC: remainder - divisor
            sub c
            ld e, a
            ld a, d
            sbc a, b
            ld d, a
            jr nc, .q3
            ld a, e                         ; borrow: restore (ADC), quotient bit 0
            add a, c
            ld e, a
            ld a, d
            adc a, b
            ld d, a
            jr .n3
.q3:        inc l                           ; quotient bit 1
.n3:
            ldh a, [nt_x]
            dec a
            ldh [nt_x], a
            jp nz, .lp
            xor a
            ld [NES_RAM + $18], a
            ldh a, [nt_a]
            ld [NES_RAM + $19], a
            ld a, l
            ld [NES_RAM + $1C], a
            ld a, h
            ld [NES_RAM + $1D], a
            ld a, e
            ld [NES_RAM + $1E], a
            ld a, d
            ld [NES_RAM + $1F], a
            ld de, 0
            ld b, 0
            ldh a, [nt_y]
            ld c, a
            xor a                           ; X = 0, A = $1F, Z = 1, N = 0, C = 0
            ldh [nzv], a
            ld a, [NES_RAM + $1F]
            ret
.zero:      xor a                           ; early RTS: A = 0, Z = 1, N = 0, C kept, X kept
            ldh [nzv], a
            pop af
            ld a, 0
            inc a
            dec a
            ret

; ------------------------------------------------------------------ fix:FC27
; init rng (battle / cutscene start: a 256-byte table at $7BE3 from 256 rounds of a 16-bit
; multiply and divide). Closed form for rounds 0-254: v' = r if r <= 512 else 1024 - r, with
; r = (s * v) mod 1024, s = 3 / 5, table = (v' >> 1) & 255; the last round runs the native
; multiply / divide step for step, so $18-$1F, A, X, Y and the flags end as on the NES.
nat_fc27:   ld hl, NES_RAM                  ; seed: A + the zero page with carries (ADC $00,X)
.sum:       adc a, [hl]
            inc l
            jr nz, .sum
            ld [NES_RAM + $15], a
            ld [NES_RAM + $16], a
            ld [NES_RAM + $17], a
            and 2
            add a, 3                        ; (AND / CLC / ADC #3)
            ld [NES_RAM + $22], a
            ld b, a                         ; B = s
            ld de, 1                        ; DE = v
            ld hl, $BBE3                    ; table ($7BE3)
.rnd:       push hl
            ld h, d                         ; HL = v * s (s = 3: v + 2v; 5: v + 4v)
            ld l, e
            add hl, hl
            bit 2, b
            jr z, .s3
            add hl, hl
.s3:        add hl, de
            ld a, h                         ; r = mod 1024
            and 3
            ld h, a
            cp 2                            ; r > 512: 1024 - r
            jr c, .keep
            jr nz, .flip
            ld a, l
            and a
            jr z, .keep
.flip:      xor a
            sub l
            ld l, a
            ld a, 4
            sbc a, h
            ld h, a
.keep:      ld d, h
            ld e, l
            pop hl
            ld a, d                         ; table = (v >> 1) & 255
            rra
            ld a, e
            rra
            ld [hl+], a
            ld a, l
            cp $E2                          ; ($7BE3 + 255 = $7CE2: the last round below)
            jr nz, .rnd
            ld a, e                         ; v -> $20 / $21
            ld [NES_RAM + $20], a
            ld a, d
            ld [NES_RAM + $21], a
            ld a, b                         ; last round exactly: $18 = s, $19 = 0, $1A / $1B = v
            ld [NES_RAM + $18], a
            xor a
            ld [NES_RAM + $19], a
            ld a, e
            ld [NES_RAM + $1A], a
            ld a, d
            ld [NES_RAM + $1B], a
            ld a, e                         ; carry = bit 0 of $20 (the last ROR)
            rra
            ld c, $FF                       ; (Y = 255)
            call nat_fcf5
            ld a, [NES_RAM + $1C]
            ld [NES_RAM + $18], a
            ld a, [NES_RAM + $1D]
            ld [NES_RAM + $19], a
            ld a, 0
            ld [NES_RAM + $1A], a
            ld a, 4
            ld [NES_RAM + $1B], a           ; (loads keep the multiply's carry)
            call nat_fc92
            ld a, [NES_RAM + $1F]           ; SEC / SBC #2 / ORA $1E / BEQ / BCC
            sub 2
            jr c, .nf2                      ; ($1F < 2: keep)
            ld h, a
            ld a, [NES_RAM + $1E]
            or h
            jr z, .nf2
            ld a, [NES_RAM + $1E]           ; $1E = 0 - $1E, $1F = 4 - $1F - borrow
            cpl
            add a, 1
            ld [NES_RAM + $1E], a
            ccf
            ld a, [NES_RAM + $1F]
            ld h, a
            ld a, 4
            sbc a, h
            ld [NES_RAM + $1F], a
.nf2:       ld a, [NES_RAM + $1F]
            ld [NES_RAM + $21], a
            ld h, a
            ld a, [NES_RAM + $1E]
            ld [NES_RAM + $20], a
            srl h                           ; LSR $1F (C = bit 0) / ROR $1E
            rra
            ld [$BCE2], a                   ; table[255]
            push af                         ; (A and the ROR's carry)
            xor a                           ; Y = 0 (INY wrapped): Z = 1, N = 0
            ldh [nzv], a
            ld bc, 0
            ld d, 0
            pop af
            push af
            pop hl
            set 7, l                        ; GB Z flag on, carry kept
            push hl
            pop af
            ret

; ------------------------------------------------------------------ fix:FB87 / FB89
; switch prg bank 0 and 1: A = 16KB unit -> $8000 = 2A, $A000 = 2A + 1 ($5114 / $5115 with
; bit 7), $AB = A (FB87 only); $A9 incremented and decremented around each write (net 0).
; Out: A = ((2A & $7F) + 1) & $7F, C = 0, N / Z from the last DEC $A9 (= $A9); X, Y kept.
nat_fb87:   ld [NES_RAM + $AB], a
nat_fb89:   add a, a                        ; $8000: bank 2A & $7F (even), $A000: the next
            and $7F                         ;   (odd): both in GB bank DATA + (2A & $7F) / 2
            ldh [nes_bank8], a
            inc a
            ldh [nes_bankA], a
            ld l, a                         ; L = A out
            srl a
            add a, DATA
            ldh [data_bank8], a
            ldh [data_bankA], a
            xor a
            ldh [odd8], a
            ld a, $20
            ldh [oddA], a
            ld a, [NES_RAM + $A9]           ; N / Z of $A9 (the last DEC), C = 0
            ldh [nzv], a
            and a
            ld a, l
            ret

; ------------------------------------------------------------------ p34:9754
; init text buffer: $7200-$73FF = $FF, $7AC0 = $4E = $18 = 0, $7AC1 = $4F = $72, $19 = $73.
; Out: A = $FF, Y = 0, Z = 1, N = 0, C kept; X kept.
nat_9754:   push af
            xor a
            ld [$BAC0], a                   ; $7AC0
            ld [NES_RAM + $4E], a
            ld [NES_RAM + $18], a
            ld a, $72
            ld [$BAC1], a                   ; $7AC1
            ld [NES_RAM + $4F], a
            inc a
            ld [NES_RAM + $19], a
            ld hl, $B200                    ; $7200 (PRG-RAM)
            ld a, $FF
            ld b, 64
.f:         ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            dec b
            jr nz, .f
            ld c, 0
            xor a
            ldh [nzv], a
            pop af                          ; (C kept)
            push af
            ld hl, sp + 0
            set 7, [hl]                     ; Z = 1
            pop af
            ld a, $FF
            ret                             ; (B = 0 after the loop)

; ------------------------------------------------------------------ fix:FCD6
; multiply: $1B:$1A = A * X ($18 = A, $19 = X, rotated as the NES loop leaves it), step for
; step in registers. In: A, X, C (6502 carry). Out: X = 0, A = the last ADC result ($1B) or
; 0, Z = 1, N = 0, C from the last ROR $1A; Y kept.
nat_fcd6:   ld [NES_RAM + $18], a
            ld h, a                         ; H = $18
            push af                         ; (incoming carry)
            ld a, e
            ld l, a                         ; L = $19
            ld a, c
            ldh [nt_y], a
            xor a
            ldh [nt_a], a
            ld d, a                         ; D = $1B, E = $1A
            ld e, a
            ld c, 8
            pop af
.lp:        rr l                            ; ROR $19
            jr nc, .ns
            ld a, h                         ; CLC / ADC $1B
            add a, d
            ld d, a
            ldh [nt_a], a
.ns:        rr d                            ; ROR $1B / ROR $1A
            rr e
            dec c
            jr nz, .lp
            push af
            ld a, l
            ld [NES_RAM + $19], a
            ld a, d
            ld [NES_RAM + $1B], a
            ld a, e
            ld [NES_RAM + $1A], a
            ld de, 0
            ld b, 0
            ldh a, [nt_y]
            ld c, a
            xor a
            ldh [nzv], a
            pop af
            ld a, 0
            inc a
            dec a
            ldh a, [nt_a]
            ret

; ------------------------------------------------------------------ p2e:BD2A
; monster death animation step (39 entries a step): sprites $0264-$02FF hidden, then for each
; entry of $7380 (x / y) the cell ($7900 + 32 * y + x) is checked; free cells get a sprite
; (y, tile $86, attributes $43 / $03 by back attack, x) at $0264 + $84. Multiply by 32 in closed
; form except for the last entry, which runs the native multiply so $18-$1B end as on the NES.
; Out: X = $4E, Y as the last entry left it, A as the NES leaves it, Z = 1, C = 1, N = 0.
nat_bd2a:   ld hl, NES_RAM + $264
            ld a, $F0
            ld b, $9C
.f:         ld [hl+], a
            dec b
            jr nz, .f
            xor a
            ld [NES_RAM + $84], a
            ld a, $61
            ld [NES_RAM + $86], a
            ld a, $0D
            ld [NES_RAM + $87], a
            ld e, 0                         ; X
.lp:        ld c, 0                         ; Y (LDY #0)
            ld a, e
            add a, $80
            ld l, a
            ld h, $B3                       ; $7380 + X (PRG-RAM)
            ld a, [hl+]
            ld [NES_RAM + $7E], a
            ld a, [hl]
            ld [NES_RAM + $7F], a
            ld a, e
            cp $4C
            jr z, .exact
            ld a, [NES_RAM + $7F]           ; 32 * y: lo = y << 5, hi = y >> 3
            ld h, a
            swap a
            add a, a
            and $E0
            ld l, a
            ld a, h
            srl a
            srl a
            srl a
            ld h, a
            jr .mul
.exact:     push de                         ; the last entry: the NES multiply ($F8EA) step for
            ld a, [NES_RAM + $7F]           ;   step (C = 0 from the CPX before)
            ld e, $20
            and a
            call nat_fcd6
            ld a, [NES_RAM + $1A]
            ld l, a
            ld a, [NES_RAM + $1B]
            ld h, a
            pop de
            ld c, 0
.mul:       ld a, h                         ; pointer $7900 + 32y + x -> $82 / $83
            add a, $79
            ld h, a
            ld a, [NES_RAM + $7E]
            add a, l
            ld l, a
            ld [NES_RAM + $82], a
            ld a, h
            adc a, 0
            ld [NES_RAM + $83], a
            add a, $40                      ; (PRG-RAM -> GB $A000)
            ld h, a
            ld a, [hl]
            ldh [nt_a], a
            and a
            jr nz, .skip
            ld a, [NES_RAM + $84]           ; a sprite at $0264 + $84
            ld c, a
            ld hl, NES_RAM + $264
            add hl, bc
            ld a, [NES_RAM + $7F]           ; y: ((y + 5) << 3) - 1
            add a, 5
            add a, a
            add a, a
            add a, a
            dec a
            ld [hl+], a
            ld a, [NES_RAM + $86]           ; tile
            ld [hl+], a
            ld a, [$B8C3]                   ; back attack ($78C3 = $88): $43, else $03
            cp $88
            ld a, $43
            jr z, .ba
            ld a, $03
.ba:        ld [hl+], a
            ld a, [NES_RAM + $7E]           ; x << 3
            add a, a
            add a, a
            add a, a
            ld [hl], a
            ld a, [NES_RAM + $84]
            add a, 4
            ld [NES_RAM + $84], a
            ldh [nt_a], a
.skip:      ld hl, NES_RAM + $87            ; DEC $87: at 0, next tile and 13 again
            dec [hl]
            jr nz, .nz
            ld hl, NES_RAM + $86
            inc [hl]
            ld a, $0D
            ld [NES_RAM + $87], a
            ldh [nt_a], a
.nz:        inc e
            inc e
            ld a, e
            cp $4E
            jr nz, .lp
            xor a                           ; X = $4E, Z = 1, C = 1, N = 0
            ldh [nzv], a
            ld b, 0
            ld d, 0
            ldh a, [nt_a]
            scf
            push af
            ld hl, sp + 0
            set 7, [hl]
            pop af
            ret

; ------------------------------------------------------------------ p34:95E1
; convert hex to decimal: $18/$19 -> $1A-$1D (ten-thousands .. tens, + $80; leading zeros $FF)
; and $1E (units + $80), by repeated subtraction as the NES does. Left as the NES leaves it:
; $18 = units, $19 = 0, $1F = $FF, $20 / $21 = 10 / 0, X = 3, Y kept; A and flags from the
; leading-zero scan: the first nonzero digit (Z = 0, N = 0, C = 1) or, all zero, $FF (N = 1,
; Z = 0, C = 1).
nat_95e1:
            ld a, [NES_RAM + $18]
            ld l, a
            ld a, [NES_RAM + $19]
            ld h, a
            ld de, -10000
            call .dg
            ld [NES_RAM + $1A], a
            ld de, -1000
            call .dg
            ld [NES_RAM + $1B], a
            ld de, -100
            call .dg
            ld [NES_RAM + $1C], a
            ld de, -10
            call .dg
            ld [NES_RAM + $1D], a
            ld a, l
            ld [NES_RAM + $18], a
            add a, $80
            ld [NES_RAM + $1E], a
            xor a
            ld [NES_RAM + $19], a
            ld [NES_RAM + $21], a
            ld d, a
            ld b, a
            ld a, $0A
            ld [NES_RAM + $20], a
            ld a, $FF
            ld [NES_RAM + $1F], a
            ld e, 3                         ; X
            ld hl, NES_RAM + $1A
.z:         ld a, [hl]                      ; leading zeros -> $FF
            cp $80
            jr nz, .nz
            ld a, $FF
            ld [hl+], a
            inc b
            bit 2, b
            jr z, .z
            ld b, 0
            ldh [nzv], a                    ; all zero: A = $FF, N = 1, Z = 0, C = 1
            or a
            scf
            ret
.nz:        ld b, 0                         ; A = the digit ($80 + d): Z = 0, N = 0, C = 1
            push af
            xor a
            ldh [nzv], a
            pop af
            scf
            ret
.dg:        ld b, $7F                       ; A = $80 + HL / K, HL = HL mod K (DE = -K)
.dl:        inc b
            add hl, de
            jr c, .dl
            ld a, l                         ; (one subtraction too many: add K back)
            sub e
            ld l, a
            ld a, h
            sbc a, d
            ld h, a
            ld a, b
            ret

; ------------------------------------------------------------------ fix:F8EA, F8E0, F8C5
; multiply wrapper: JSR $FCD6 / LDA $1A / LDX $1B. Out: A = $1A, X = $1B (N, Z of X), C from
; the multiply, Y kept.
nat_f8ea:   call nat_fcd6
            ld a, [NES_RAM + $1B]
            ld e, a
            ldh [nzv], a
            inc e
            dec e
            ld a, [NES_RAM + $1A]
            ret

; set ppu address: BIT $2002 / STA $2006 / STX $2006. Out: N, V, Z of the BIT; A, X, Y, C kept.
nat_f8e0:   push af
            ldh [ppu_th], a
            ld a, e
            ldh [ppu_vl], a
            ldh a, [ppu_th]
            and $3F
            ldh [ppu_vh], a
            xor a
            ldh [wc_n], a                   ; (new address: no cached run)
            ldh [ppu_latch], a              ; (BIT resets it; the two writes leave it reset)
            ldh a, [ppu_stat]
            ld l, a
            xor a
            ldh [ppu_stat], a
            ld a, l
            ldh [nzv], a
            ldh [vfl], a
            pop af
            ld h, a
            push af                         ; Z = (A & $2002) = 0, carry kept
            and l
            ld l, a
            pop af
            ld a, h
            inc l
            dec l
            ret

; wait for vblank (no color update): $FB80 (wait for the NMI handler), $F8AA (OAM DMA from
; page 2), $F8CB (PPU registers from $06 / $09 / $0C / $0D). Out: A = $0D (N, Z), C kept,
; X, Y kept.
nat_f8c5:   call rt_wait_nmi
            ld a, 2
            call rt_io_w4014
nat_f8cb:   ld a, [NES_RAM + $06]           ; update ppu registers ($F8CB)
            call rt_ppu_w0
            ld a, [NES_RAM + $09]
            call rt_ppu_w1
            ld a, [NES_RAM + $0C]
            call rt_ppu_w5
            ld a, [NES_RAM + $0D]
            call rt_ppu_w5
            ldh [nzv], a
            inc a
            dec a
            ret

; ------------------------------------------------------------------ small fixed-bank helpers
; (each called from every code bank: here they cost no bank switch)
; $FD3C-$FD40: ASL A x 6 .. x 2; $FD43-$FD47: LSR A x 6 .. x 2. Out: N, Z, C of the last shift.
nat_fd3c:   add a, a
nat_fd3d:   add a, a
nat_fd3e:   add a, a
nat_fd3f:   add a, a
nat_fd40:   add a, a
            add a, a
            ldh [nzv], a
            ret
nat_fd43:   srl a
nat_fd44:   srl a
nat_fd45:   srl a
nat_fd46:   srl a
nat_fd47:   srl a
            srl a
            ldh [nzv], a
            ret
; $FD20 set bit (ORA $FD24,X), $FD2C clear bit (AND $FD30,X), $FD38 check bit (AND $FD24,X):
; the mask read from the fixed bank as the NES does; N, Z of the result, C kept.
nat_fd20:   push af                         ; (A and the carry)
            ld hl, $4000 + $FD24 - $C000
            add hl, de                      ; + X (D = 0)
            call rt_rd_f                    ; L = mask (A, F kept)
            pop af
            push af
            or l
            jr bit_out
nat_fd2c:   push af
            ld hl, $4000 + $FD30 - $C000
            add hl, de
            call rt_rd_f
            pop af
            push af
            and l
            jr bit_out
nat_fd38:   push af
            ld hl, $4000 + $FD24 - $C000
            add hl, de
            call rt_rd_f
            pop af
            push af
            and l
bit_out:    ld l, a                         ; N, Z of the result, the caller's carry
            ldh [nzv], a
            pop af
            ld a, l
            inc l
            dec l
            ret

; $F8F2 / $F8FE / p34:$A558: CLC / ADC zp / STA zp / LDA zp+1 / ADC #0 / STA zp+1 (16-bit add
; of A to $7E / $80 / $4E). Out: A = the high byte, N, Z, C of its ADC.
nat_f8f2:   ld hl, NES_RAM + $7E
            jr add16
nat_f8fe:   ld hl, NES_RAM + $80
            jr add16
nat_a558:   ld hl, NES_RAM + $4E
add16:      add a, [hl]
            ld [hl+], a
            ld a, [hl]
            adc a, 0
            ld [hl], a
            ldh [nzv], a
            ret

; $F8AA: LDA #2 / STA $4014 (OAM DMA from page 2). Out: A = 2, N = Z = 0, C kept.
nat_f8aa:   ld a, 2
            call rt_io_w4014
            ldh [nzv], a
            inc a
            dec a
            ret

; p34:$A549 write spaces to text buffer: $7AD7 + X = 0, then $FF at X - 1 downwards while X
; stays positive (DEX / BPL). Out: A = $FF, X as the loop leaves it (N = 1), C kept, Y kept.
nat_a549:   ld hl, $BAD7                    ; ($7AD7 in PRG-RAM)
            add hl, de
            ld [hl], 0
            dec e
.lp:        ld hl, $BAD7
            add hl, de
            ld [hl], $FF
            dec e
            bit 7, e
            jr z, .lp
            ld a, e
            ldh [nzv], a
            inc e
            dec e
            ld a, $FF
            ret

; $FBAA update joypad input: $12 = previous buttons, $13 = new (8 reads of $4016, as the NES:
; each read is a safe point), repeat counter $14. Out: X = 0, A / N / Z as the NES path leaves
; them, C from the last ROR $13.
nat_fbaa:   ld a, [NES_RAM + $13]
            ld [NES_RAM + $12], a
            ld a, 1
            call rt_io_w4016
            xor a
            call rt_io_w4016
            ld e, 8
.rd:        call rt_io_r4016                ; L = the button (bit 0)
            ld a, l
            rra
            ld hl, NES_RAM + $13
            rr [hl]
            dec e
            jr nz, .rd
            push af                         ; (the carry of the last ROR)
            ld a, [NES_RAM + $12]
            ld l, a
            ld a, [NES_RAM + $13]
            ld h, a
            or l
            jr nz, .any
            ld [NES_RAM + $12], a           ; nothing pressed: $12 = 0, $14 = 8
            ld a, 8
            ld [NES_RAM + $14], a
            jr .out
.any:       ld a, l
            and h
            jr nz, .held
.new:       ld a, l                         ; newly pressed: $12 = ~old & new
            cpl
            and h
            ld [NES_RAM + $12], a
            jr .out
.held:      ld a, [NES_RAM + $14]           ; held: repeat every 4 frames after 8
            dec a
            ld [NES_RAM + $14], a
            jr nz, .new
            ld a, 4
            ld [NES_RAM + $14], a
            ld a, h
            ld [NES_RAM + $12], a
.out:       ld l, a
            ldh [nzv], a
            pop af
            ld a, l
            inc l
            dec l
            ret

; ------------------------------------------------------------------ p2e:A697 / A78D
; reset attribute tables: $7D27-$7D66 = $FF, $7D27-$7D2E = $AA, $7D2F-$7D36 = $FA.
; Out: X = 0, A = $FA, Z = 1, N = 0, C kept; Y kept.
nat_a697:   ld hl, $BD27                    ; ($7D27 in PRG-RAM)
            ld a, $FF
            ld e, $40
.f:         ld [hl+], a
            dec e
            jr nz, .f
            ld hl, $BD27
            ld a, $AA
            ld e, 8
.a:         ld [hl+], a
            dec e
            jr nz, .a
            ld a, $FA
            ld e, 8
.b:         ld [hl+], a
            dec e
            jr nz, .b
            push af
            xor a
            ldh [nzv], a
            pop af
            ld e, 0
            inc e
            dec e                           ; Z = 1 (DEX), carry kept
            ret

; L = the byte at NES address HL as the current mapping shows it (A, F kept)
rom_rd:     push af
            jp izrd

; set attribute table for monster: ($18) -> x, y, size id ($8C, $8E, $90); for each 2x2 tile
; block of the monster (width / height from $A4CC + 2 * size, the code's own bank): the
; palette from $A6FB (the flash palette $7E90 while $7E8E is set, else the next bits of the
; attribute data $7D17 + $1A at bit $1B) into the attribute table $7D27 ($A7D4). RAM left as
; the NES leaves it ($7E, $7F, $80, $82, $84, $86, $87, $1A, $1B, $1D, $1E, $1F, $8E).
; Out: A = X (N, Z), Y = 2 * size, C = 1.
nat_a78d:   ld a, e
            ldh [nt_x], a
            ld a, [NES_RAM + $18]
            ld l, a
            ld a, [NES_RAM + $19]
            ld h, a
            call rom_rd
            ld a, l
            ld [NES_RAM + $8C], a
            ld a, [NES_RAM + $18]
            ld l, a
            ld a, [NES_RAM + $19]
            ld h, a
            inc hl
            push hl
            call rom_rd
            ld a, l
            ld [NES_RAM + $8E], a
            pop hl
            inc hl
            call rom_rd
            ld a, l
            ld [NES_RAM + $90], a
            add a, a
            ld c, a                         ; Y = 2 * size
            ld l, a
            ld h, 0
            ld de, $A4CC
            add hl, de
            push hl
            call rom_rd
            ld a, l
            ld [NES_RAM + $1E], a           ; width
            pop hl
            inc hl
            call rom_rd
            ld a, l
            ld [NES_RAM + $1F], a           ; height
            ld d, 0
.row:       ld e, 0
.col:       ld a, [$BE8E]                   ; $A6FB: $7E8E set: the flash palette $7E90
            and a
            jr z, .np
            ld a, [$BE90]
            jr .pd
.np:        ld a, [NES_RAM + $1A]           ; A = $7D17 + $1A, shifted left $1B + 1 times
            ld l, a                         ;   into $7E
            ld h, 0
            push de
            ld de, $BD17
            add hl, de
            ld d, [hl]
            ld a, [NES_RAM + $1B]
            inc a
            ld b, a
            ld hl, NES_RAM + $7E
.sh:        sla d
            rl [hl]
            dec b
            jr nz, .sh
            pop de
            ld a, [NES_RAM + $1B]           ; $7F = $1B + 1, $1B = that & 7, $1A += bit 3
            inc a
            ld [NES_RAM + $7F], a
            ld b, a
            and 7
            ld [NES_RAM + $1B], a
            ld a, b
            and 8
            rrca
            rrca
            rrca
            ld hl, NES_RAM + $1A
            add a, [hl]
            ld [hl], a
            ld a, [NES_RAM + $7E]
            and 1
.pd:        ld [NES_RAM + $1D], a
            ld [NES_RAM + $82], a
            ld a, [NES_RAM + $8C]           ; $7E = x + $8C, $80 = $8E
            add a, e
            ld [NES_RAM + $7E], a
            ld a, [NES_RAM + $8E]
            ld [NES_RAM + $80], a
            ld a, [NES_RAM + $7E]           ; $A7D4: $7F = $7E >> 2
            srl a
            srl a
            ld [NES_RAM + $7F], a
            ld l, a
            ld a, [NES_RAM + $80]           ; $84 = ($80 & $FC) * 2 + $7F (attribute byte)
            and $FC
            add a, a
            add a, l
            ld [NES_RAM + $84], a
            ld a, [NES_RAM + $7E]           ; $86 = quadrant ($7E bit 1, $80 bit 1)
            and 2
            ld h, a
            ld a, [NES_RAM + $80]
            and 2
            add a, a
            add a, h
            srl a
            ld [NES_RAM + $86], a
            ld b, a
            ld h, 3                         ; H = 3 << 2q (the quadrant's bits)
            ld a, [NES_RAM + $82]
            and 3
            inc b
.q:         dec b
            jr z, .qd
            add a, a
            add a, a
            sla h
            sla h
            jr .q
.qd:        ld [NES_RAM + $87], a
            ld l, a
            push de
            ld a, [NES_RAM + $84]
            ld e, a
            ld a, h
            cpl
            ld h, a
            ld a, l
            ld l, h                         ; L = mask, A = bits
            push af
            ld d, 0
            ld a, l
            ld hl, $BD27
            add hl, de
            and [hl]
            ld e, a
            pop af
            or e
            ld [hl], a
            pop de
            inc e                           ; next block
            inc e
            ld a, [NES_RAM + $1E]
            cp e
            jp nz, .col
            ld hl, NES_RAM + $8E
            inc [hl]
            inc [hl]
            ld hl, NES_RAM + $1F
            dec [hl]
            dec [hl]
            jp nz, .row
            ld b, 0
            ld d, 0
            ldh a, [nt_x]
            ld e, a
            ldh [nzv], a
            scf
            inc a
            dec a
            ret

; ------------------------------------------------------------------ fix:F9DA idiom
; copy graphics to ppu, the last rows (LDY #0 / LDA ($7E),Y / [$92: TAX / LDA $7300,X] /
; STA $2007 / INY / CPY $82 / BNE): whole tiles into the staging copy as nat_chr64 does, else
; byte by byte through $2007. Out: Y = $82, A = the last byte, X = $92 (0) or the last source
; byte, Z = 1, C = 1, N = 0.
nat_chrn:   xor a
            ldh [wc_n], a
            ld c, 0
            ld a, [NES_RAM + $82]
            and a
            jr z, .slow
            cp $41
            jr nc, .slow
            ld b, a
            and $0F
            jr nz, .slow
            ld a, b
            ldh [ch_n], a
            ldh a, [ppu_ctrl]
            and 4
            jr nz, .slow
            ldh a, [ppu_vh]
            cp $20
            jr nc, .slow
            call chr64_fast                 ; (C = the bytes when done)
            jr nc, .end
.slow:      ld b, 0
.lp:        call nat_chr64.byte
            call rt_ppu_w7
            inc c
            ld a, [NES_RAM + $82]
            cp c
            jr nz, .lp
.end:       ld d, 0
            ld b, 0
            ldh a, [nt_x]
            ld e, a
            xor a                           ; N = 0, Z = 1, C = 1
            ldh [nzv], a
            scf
            ldh a, [nt_a]
            ret
