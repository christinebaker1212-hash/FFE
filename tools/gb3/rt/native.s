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
            ld h, $DD                       ; ($7D93 + X, $7D97 + X: X < 4)
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
            ld de, $D301
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
            ld de, $D300
            ld a, [NES_RAM + $98]           ; back attack gets an h-flip ($90D2: $78C3 = $88)
            and a
            jr z, .pl
            ld a, [$D8C3]
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
            ld hl, $D300
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
            call chr64_src7e
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
            ld h, $D3                       ; flip table $7300 (GB $D300, WRAM bank 1)
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
            ld a, MAP_BANK                  ; (NT_SH: WRAM bank MAP_BANK)
            ldh [rSVBK], a
            ld d, [hl]                      ; D = old
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
            ld a, 1
            ldh [rSVBK], a
            ld a, d
            ldh [c_q], a
            ld a, e
            ld l, c
            call attr_apply                 ; (keeps B, C)
.same:      ld a, 1
            ldh [rSVBK], a
            inc c
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

; chr64_fast parameters from the F98E / F9DA loops: source ($7E), flip table flag $92
chr64_src7e:
            ld a, [NES_RAM + $7E]
            ldh [ch_sl], a
            ld a, [NES_RAM + $7F]
            ldh [ch_sh], a
            ld a, [NES_RAM + $92]
            ldh [ch_fl], a
            ret

; fast path of nat_chr64: PPU address tile-aligned, source ($7E) + 63 in one ROM window.
; 4 tiles: source read in place (one bank switch), flip table applied, written to the staging
; copy in GB row order, each tile marked once. Returns NC when done (Y = $40, nt_a / nt_x
; set, the PPU address advanced), C when it does not apply (nothing changed).
chr64_fast: ldh a, [ppu_vl]
            and $0F
            jr nz, .no
            ldh a, [ch_sl]                  ; source -> GB bank (A) + address (HL)
            ld l, a
            ldh a, [ch_sh]
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
.lowsrc:    cp $60                          ; PRG-RAM (decompressed graphics; contiguous in
            jr c, .ramsrc                   ;   the GB map); RAM $0000-$07FF -> $C000
            ldh a, [ch_n]
            dec a
            add a, l
            ld a, h
            jr nc, .lp1
            call prg_cross
            jr .lp2
.lp1:       call prg_page
.lp2:       jr c, .no
            ld h, a
            ldh a, [code_bank]              ; (no ROM bank needed)
            jr .src
.ramsrc:    cp $08
            jr nc, .no
            add a, high(NES_RAM)
            ld h, a
            ldh a, [code_bank]
.src:       ld [MBC5_BANKL], a
            ld b, 0                         ; (B = 1: bounced through the flip table)
            ldh a, [ch_fl]                  ; flip table ($7300) or a PRG-RAM $7xxx source:
            and a                           ;   both in WRAM bank 1, unseen once the staging
            jr nz, .bnc                     ;   bank is in: the bytes through NC_BUF first
            ld a, h
            and $F0
            cp high(PRG7)
            jr nz, .nob
.bnc:       ldh a, [ch_n]
            ld c, a
            ld de, NC_BUF
            ldh a, [ch_fl]
            and a
            jr nz, .bf
.bc:        ld a, [hl+]
            ld [de], a
            inc e
            dec c
            jr nz, .bc
            jr .bd
.bf:        inc b
.bf1:       ld a, [hl+]
            ldh [nt_x], a                   ; (X = the source byte, A = the table's)
            push hl
            ld l, a
            ld h, high(PRG7) + 3
            ld a, [hl]
            pop hl
            ld [de], a
            ldh [nt_a], a
            inc e
            dec c
            jr nz, .bf1
.bd:        ld hl, NC_BUF
.nob:       push hl                         ; mark the 4 tiles dirty
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
            ld a, b                         ; (flip: nt_a / nt_x set by the bounce)
            and a
            jr nz, .done
            dec hl                          ; A = the last byte (no table: X = $92 = 0)
            ld a, [hl]
            ldh [nt_a], a
            xor a
            ldh [nt_x], a
            jr .done
.done:
            ld a, 1
            ldh [rSVBK], a
            ldh a, [code_bank]
            ld [MBC5_BANKL], a
            ld a, 1
            ldh [chr_dirty], a
            ld [FRZW], a
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
            ld hl, $DCF7                    ; PRG-RAM $7CF7
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
            ld a, [$DD16]                   ; A = $7D16 (the last byte)
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
nat_9f98:                                   ; (body in the runtime tables bank: far_9f98)
            push af
            ld a, RT_TABLES
            ld [MBC5_BANKL], a
            pop af
            call far_9f98
            push af
            ldh a, [code_bank]
            ld [MBC5_BANKL], a
            pop af
            ret

; ------------------------------------------------------------------ fix:FCF5
; (body in the runtime tables bank: far_fcf5)
nat_fcf5:
            push af
            ld a, RT_TABLES
            ld [MBC5_BANKL], a
            pop af
            call far_fcf5
            push af
            ldh a, [code_bank]
            ld [MBC5_BANKL], a
            pop af
            ret

; ------------------------------------------------------------------ fix:FC92
; (body in the runtime tables bank: far_fc92)
nat_fc92:
            push af
            ld a, RT_TABLES
            ld [MBC5_BANKL], a
            pop af
            call far_fc92
            push af
            ldh a, [code_bank]
            ld [MBC5_BANKL], a
            pop af
            ret

; ------------------------------------------------------------------ fix:FC27
; init rng (battle / cutscene start: a 256-byte table at $7BE3 from 256 rounds of a 16-bit
; multiply and divide). Closed form for rounds 0-254: v' = r if r <= 512 else 1024 - r, with
; r = (s * v) mod 1024, s = 3 / 5, table = (v' >> 1) & 255; the last round runs the native
; multiply / divide step for step, so $18-$1F, A, X, Y and the flags end as on the NES.
nat_fc27:                                   ; (body in the runtime tables bank: far_fc27)
            push af
            ld a, RT_TABLES
            ld [MBC5_BANKL], a
            pop af
            call far_fc27
            push af
            ldh a, [code_bank]
            ld [MBC5_BANKL], a
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
; ------------------------------------------------------------------ ex: h_flush (one-row line)
; The English one-row line flush (tools/ff3/insert.py h_flush, from its .one label; build.py
; finds it in the ExRAM image): line $07A0, cells 0 .. $91 - 1 from column $38 of row $3B, the
; rest up to $3C from column 0 of the other screen, written straight into the nametable shadow
; and the GB map (native: no $2006 / $2007). RAM as the NES leaves it: $3A, the $2002 read's
; effects (vblank flag, latch); X = the last cell + 1, Y = $3B; then the NES tail at $F715.
nat_h1:     ldh a, [cv_n]                   ; names in this line: condensed tiles (far_cvr)
            and a
            jr z, .nc
            push hl
            ld hl, far_cvr
            call far_call
            pop hl
.nc:        xor a
            ldh [wc_n], a                   ; (no cached $2007 run; row mark forgotten)
            ldh [mr_hi], a
            ldh [ppu_stat], a
            ldh [ppu_latch], a
            ld a, [NES_RAM + $38]
            ld [NES_RAM + $3A], a
            ld e, 0
            ld a, [NES_RAM + $91]
            call h1_run
            ld a, [NES_RAM + $3C]
            ld b, a
            ld a, e
            cp b
            jr nc, .d
            ld a, [NES_RAM + $3A]
            and $20
            xor $20
            ld [NES_RAM + $3A], a
            ld a, [NES_RAM + $91]
            ld e, a
            ld a, b
            call h1_run
.d:         xor a
            ldh [cv_n], a
            ldh [cv_open], a
            ld b, 0
            ld d, 0
            ld a, [NES_RAM + $3B]
            ld c, a
            jp L_fix_F715
h1_run:     ldh [h1_lim], a                 ; cells E .. (do-while) < A from ($3A, $3B)
            ld a, [NES_RAM + $3B]           ; HL = $2000 + row * 32 + column (+ $400: the
            ld l, a                         ;   2nd screen)
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld a, [NES_RAM + $3A]
            ld b, a
            and $1F
            or l
            ld l, a
            ld a, b
            and $20
            rrca
            rrca
            rrca
            or $20
            or h
            ld h, a
.c:         push hl
            push de
            xor a
            ldh [cv_bk], a
            ldh a, [cv_n]                   ; (condensed: CV_SUB 1 = blank, >= 2 = the tile
            and a                           ;   in VRAM bank 1)
            jr z, .t
            ld h, high(CV_SUB)
            ld a, e
            add a, low(CV_SUB)
            ld l, a
            ld a, [hl]
            and a
            jr z, .t
            ld c, $FF
            dec a
            jr z, .w
            inc a
            ld c, a
            ld a, 8
            ldh [cv_bk], a
            jr .w
.t:         ld a, e
            add a, low(NES_RAM + $7A0)
            ld e, a
            ld a, high(NES_RAM + $7A0)
            adc a, 0
            ld d, a
            ld a, [de]
            ld c, a
.w:         pop de
            pop hl
            push hl
            push de
            call nt_put
            pop de
            pop hl
            inc hl
            inc e
            ldh a, [h1_lim]
            ld b, a
            ld a, e
            cp b
            jr c, .c
            ret
; tile C at NES nametable address HL ($2000-$2FFF) -> nametable shadow and GB map (row marked),
; as rt_ppu_w7 does for a cell (attribute bytes: the shadow only). A, BC, DE, HL clobbered.
nt_put:     ld a, h
            and $0F
            rrca
            rrca
            and 3
            ld b, a
            ldh a, [mirror]
            and a
            ld a, b
            jr z, .v
            srl a
            jr .n
.v:         and 1
.n:         ld b, a                         ; B = nametable after mirroring
            ld a, h
            and 3
            ld h, a                         ; HL = offset in it
            push hl
            ld a, b
            add a, a
            add a, a
            add a, h
            add a, high(NT_SH)
            ld h, a
            ld a, MAP_BANK                  ; (NT_SH, MAP_SH: WRAM bank MAP_BANK)
            ldh [rSVBK], a
            ld [hl], c
            pop hl
            ld a, h
            cp 3
            jr nz, .cell
            ld a, l
            cp $C0
            jr nc, .x
.cell:      call cell_map                   ; HL = GB map address
            ld a, h
            sub $98 - high(MAP_SH)
            ld d, a
            ld e, l
            ld a, c
            ld [de], a
            ldh a, [cv_live]                ; condensed names on screen: the cell's VRAM bank
            and a                           ;   bit (ATTR_SH = MAP_SH + $400) as cv_bk says
            jr z, .nb
            ld a, d
            add a, 4
            ld d, a
            ld a, [de]
            and $F7
            ld b, a
            ldh a, [cv_bk]
            or b
            ld b, a
            ld a, [de]
            cp b
            jr z, .nb
            ld a, b
            ld [de], a
            ld a, 1
            ldh [rSVBK], a
            push hl
            ld de, attr_dirty
            call row_mark
            pop hl
            jp map_mark
.nb:        ld a, 1
            ldh [rSVBK], a
            jp map_mark
.x:         ld a, 1
            ldh [rSVBK], a
            ret

; pre-hooks (translate.py FF3.pre, GB only): fix:F3E4 push text pointer / fix:F3ED pop text
; pointer bracket each nested string; in the menus ($37 <> 0, no battle) a nested string read from
; ROM ($3F >= $80 at its end: item, spell, job names; not a character's name in RAM) between the
; columns $90 at the two calls is a span to condense (far_cvr). All registers and flags kept.
cv_beg:     push af
            ldh a, [bcam]
            and a
            jr nz, .x
            ld a, [NES_RAM + $37]
            and a
            jr z, .x
            ld a, [NES_RAM + $90]
            or $80
            ldh [cv_open], a
.x:         pop af
            ret
cv_end:     push af
            ldh a, [cv_open]
            and a
            jr z, .x
            push bc
            push hl
            ld l, a
            xor a
            ldh [cv_open], a
            ld a, [NES_RAM + $3F]
            cp $80
            jr c, .y
            ldh a, [cv_n]
            cp 4
            jr nc, .y
            ld h, a
            ld a, l
            and $7F
            ld l, a                         ; L = start
            ld a, [NES_RAM + $90]
            cp l
            jr z, .y
            jr c, .y
            ld b, a                         ; B = end
            ld a, h
            add a, low(cv_s)
            ld c, a
            ld a, l
            ldh [c], a
            ld a, c
            add a, 4
            ld c, a
            ld a, b
            ldh [c], a
            ld a, h
            inc a
            ldh [cv_n], a
            push de                         ; the name's cells as they are now (16) -> CV_SNAP
            ld a, h                         ;   + 16 n (WRAM bank 7): the line may write over
            swap a                          ;   them later (a price after a tab)
            add a, low(CV_SNAP)
            ld e, a
            ld d, high(CV_SNAP)
            ld a, l
            add a, low(NES_RAM + $7A0)
            ld l, a
            ld h, high(NES_RAM + $7A0)
            ld a, 7
            ldh [rSVBK], a
            ld b, 16
.sn:        ld a, [hl+]
            ld [de], a
            inc e
            dec b
            jr nz, .sn
            ld a, 1
            ldh [rSVBK], a
            pop de
.y:         pop hl
            pop bc
.x:         pop af
            ret
nat_858f:   ld hl, far_858f                 ; field: update water animation (far_858f)
            jp far_call
nat_866e:   ld hl, far_866e                 ; field: init water animation graphics buffer
            jp far_call
; far call: HL = routine in the runtime tables bank (A, F, BC, DE pass; HL clobbered)
far_call:   push af
            ld a, RT_TABLES
            ld [MBC5_BANKL], a
            pop af
            call rt_jp_hl
            push af
            ldh a, [code_bank]
            ld [MBC5_BANKL], a
            pop af
            ret


; sound output: bodies in the runtime tables bank (far_snd_*)
snd_mus:    push hl
            ld hl, far_snd_mus
            jr snd_far
snd_sfx:    push hl
            ld hl, far_snd_sfx
            jr snd_far
snd_init:   push hl
            ld hl, far_snd_init
snd_far:    call far_call
            pop hl
            ret
; NES noise period byte -> NR43 (A clobbered only)
snd_nr43:   push hl
            push af
            and $0F
            ld hl, NOI_TAB
            add a, l
            ld l, a
            jr nc, .a
            inc h
.a:         pop af
            and $80                         ; short mode -> 7-bit LFSR
            rrca
            rrca
            rrca
            rrca
            or [hl]
            pop hl
            ret
NOI_TAB:    db $00, $01, $02, $05, $15, $17, $25, $26, $27, $35, $37, $45, $47, $55, $65, $75


; ------------------------------------------------------------------ fix:C486
; clear oam data (every frame): $0200-$02FF = $F0, $26 = 0. Out as the NES: X = $FF, A = 0,
; N = 0, Z = 1, C kept (no flag-changing instruction but dec b; B = 0 after).
nat_c486:   ld hl, NES_RAM + $200
            ld a, $F0
            ld b, 32
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
            ld e, $FF
            ld a, 0
            ld [NES_RAM + $26], a
            ldh [nzv], a
            ret

nat_9754:   push af
            xor a
            ld [$DAC0], a                   ; $7AC0
            ld [NES_RAM + $4E], a
            ld [NES_RAM + $18], a
            ld a, $72
            ld [$DAC1], a                   ; $7AC1
            ld [NES_RAM + $4F], a
            inc a
            ld [NES_RAM + $19], a
            ld hl, $D200                    ; $7200 (PRG-RAM)
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
nat_bd2a:   ld hl, far_bd2a                 ; (body in the runtime tables bank)
            jp far_call
nat_95e1:
            push af
            ld a, RT_TABLES
            ld [MBC5_BANKL], a
            pop af
            call far_95e1
            push af
            ldh a, [code_bank]
            ld [MBC5_BANKL], a
            pop af
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
nat_a549:   ld hl, $DAD7                    ; ($7AD7 in PRG-RAM)
            add hl, de
            ld [hl], 0
            dec e
.lp:        ld hl, $DAD7
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
nat_a697:   ld hl, $DD27                    ; ($7D27 in PRG-RAM)
            ld a, $FF
            ld e, $40
.f:         ld [hl+], a
            dec e
            jr nz, .f
            ld hl, $DD27
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
.col:       ld a, [$DE8E]                   ; $A6FB: $7E8E set: the flash palette $7E90
            and a
            jr z, .np
            ld a, [$DE90]
            jr .pd
.np:        ld a, [NES_RAM + $1A]           ; A = $7D17 + $1A, shifted left $1B + 1 times
            ld l, a                         ;   into $7E
            ld h, 0
            push de
            ld de, $DD17
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
            ld hl, $DD27
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
            call chr64_src7e
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

; ------------------------------------------------------------------ b40:9F00
; reload the English text engine into ExRAM: $8000-$83FF (the $8000 window: bank $40, the
; code's own) -> $5C00-$5FFF (the image the build translated). Out: X = 0, A = the byte at
; $83FF, Z = 1, N = 0, C kept; Y kept.
nat_9f00:   push af
            ldh a, [data_bank8]
            ld [MBC5_BANKL], a
            ldh a, [odd8]
            or $40
            ld h, a
            ld l, 0
            ld de, EX_RAM
            ld a, RT_WBANK                  ; (ExRAM: WRAM bank RT_WBANK)
            ldh [rSVBK], a
            ld b, 0
.cp:        ld a, [hl+]
            ld [de], a
            inc de
            ld a, [hl+]
            ld [de], a
            inc de
            ld a, [hl+]
            ld [de], a
            inc de
            ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .cp
            ld l, a                         ; (the last byte copied: $83FF)
            ld a, 1
            ldh [rSVBK], a
            ldh a, [code_bank]
            ld [MBC5_BANKL], a
            xor a
            ldh [nzv], a
            ld de, 0
            pop af
            ld a, 0
            inc a
            dec a                           ; Z = 1 (INX to 0), carry kept
            ld a, l
            ret

; ------------------------------------------------------------------ p32:9FE4
; update status animation sprites (every battle frame, per character): 2 sprites from the
; data at ($A1) (y, attributes, x; tile = $9F or 0) into $0200 + $A0.., with the status
; palette / y offset ($A051 / $A049 + $7DB7[$A3]) when the character has a status. Data read
; in place when the p32 pair is mapped as usual (one bank switch), else byte by byte.
; Out: Y = 8, X = $A0 + 8, A = the last x written, Z = 1, C = 1, N = 0.
nat_9fe4:   ldh a, [data_bank8]
            ld b, a
            ldh a, [data_bankA]
            cp b
            jr nz, .slw
            ldh a, [odd8]
            and a
            jr nz, .slw
            ldh a, [oddA]
            cp $20
            jr nz, .slw
            ld a, [NES_RAM + $A2]           ; (data in the $8000-$BFFF windows)
            sub $80
            cp $40 - 1
            jr nc, .slw
            ld a, b
            ld [MBC5_BANKL], a
            jp .fast
.slw:       xor a
.fs:        ldh [n9_at], a                  ; (1: the pair is at $4000-$7FFF of one GB bank)
            ld a, [NES_RAM + $A0]
            ld e, a
            ld c, 0
            ld d, 0
.lp:        call .src                       ; y = data + $9E
            ld hl, NES_RAM + $9E
            add a, [hl]
            ld l, e
            ld h, high(NES_RAM) + 2
            ld [hl], a
            inc c
            inc l                           ; tile: $9F (then + 1), or 0 if $9F = $FF
            ld a, [NES_RAM + $9F]
            cp $FF
            jr nz, .st
            xor a
            ld [hl], a
            jr .at
.st:        ld [hl], a
            ld hl, NES_RAM + $9F
            inc [hl]
.at:        inc c                           ; attributes -> $A7
            call .src
            ld [NES_RAM + $A7], a
            ld b, a
            ld a, [NES_RAM + $A3]
            add a, $B7
            ld l, a
            ld h, $DD                       ; ($7DB7 + $A3)
            ld a, [hl]
            cp $FF
            jr z, .ns
            ld d, a                         ; status: palette and y offset
            ld hl, $A051
            ld a, l
            add a, d
            ld l, a
            call .rdn
            ld l, a
            ld a, b
            and $FC
            or l
            ld b, a
            ld [NES_RAM + $A7], a
            ld hl, $A049
            ld a, l
            add a, d
            ld l, a
            call .rdn
            ld [NES_RAM + $A8], a
            ld l, e
            ld h, high(NES_RAM) + 2
            add a, [hl]
            ld [hl], a
            ld d, 0
.ns:        ld l, e
            ld h, high(NES_RAM) + 2
            inc l
            inc l
            ld [hl], b                      ; $0202 + X = $A7
            inc c
            call .src                       ; x = data + $9D
            ld hl, NES_RAM + $9D
            add a, [hl]
            ld l, e
            ld h, high(NES_RAM) + 2
            inc l
            inc l
            inc l
            ld [hl], a
            ldh [n9_x], a
            inc c
            ld a, e
            add a, 4
            ld e, a
            ld a, c
            cp 8
            jr nz, .lp
            ldh a, [code_bank]
            ld [MBC5_BANKL], a
            ld b, 0
            xor a                           ; Z = 1, C = 1, N = 0 (CPY #8)
            ldh [nzv], a
            scf
            ldh a, [n9_x]
            ret
.fast:      ld a, [NES_RAM + $A3]           ; status of the character ($7DB7 + $A3):
            add a, $B7                      ;   palette / y offset from $A051 / $A049 once
            ld l, a
            ld h, $DD
            ld a, [hl]
            ldh [c_q], a
            cp $FF
            jr z, .f0
            ld e, a
            ld d, 0
            ld hl, $6051                    ; ($A051 in the pair's GB bank)
            add hl, de
            ld a, [hl]
            ldh [c_x], a
            ld hl, $6049
            add hl, de
            ld a, [hl]
            ldh [c_val], a
.f0:        ld a, [NES_RAM + $A1]           ; DE = the data (GB), B = X
            ld e, a
            ld a, [NES_RAM + $A2]
            sub $40
            ld d, a
            ld a, [NES_RAM + $A0]
            ld b, a
            ld c, 2
.fl:        ld a, [de]                      ; y = data + $9E (data: y, -, attributes, x)
            inc de
            inc de
            ld hl, NES_RAM + $9E
            add a, [hl]
            ld l, b
            ld h, high(NES_RAM) + 2
            ld [hl+], a
            ld a, [NES_RAM + $9F]           ; tile: $9F (then + 1), or 0 if $9F = $FF
            cp $FF
            jr nz, .ft
            xor a
            ld [hl+], a
            jr .fa
.ft:        ld [hl+], a
            inc a
            ld [NES_RAM + $9F], a
.fa:        ld a, [de]                      ; attributes
            inc de
            ld [NES_RAM + $A7], a
            ld l, a
            ldh a, [c_q]
            cp $FF
            ld a, l
            jr z, .fn
            and $FC                         ; status: palette, y += offset
            ld l, a
            ldh a, [c_x]
            or l
            ld [NES_RAM + $A7], a
            ld l, a
            ldh a, [c_val]
            ld [NES_RAM + $A8], a
            push hl
            ld l, b
            ld h, high(NES_RAM) + 2
            add a, [hl]
            ld [hl], a
            pop hl
            ld a, l
.fn:        ld l, b
            ld h, high(NES_RAM) + 2
            inc l
            inc l
            ld [hl+], a                     ; $0202 + X
            ld a, [de]                      ; x = data + $9D
            inc de
            push hl
            ld hl, NES_RAM + $9D
            add a, [hl]
            pop hl
            ld [hl], a
            ldh [n9_x], a
            ld a, b
            add a, 4
            ld b, a
            dec c
            jr nz, .fl
            ld e, b                         ; X, Y = 8
            ld c, 8
            ld d, 0
            ldh a, [code_bank]
            ld [MBC5_BANKL], a
            ld b, 0
            xor a                           ; Z = 1, C = 1, N = 0 (CPY #8)
            ldh [nzv], a
            scf
            ldh a, [n9_x]
            ret
.src:       ld a, [NES_RAM + $A1]           ; A = the byte at ($A1) + Y
            add a, c
            ld l, a
            ld a, [NES_RAM + $A2]
            adc a, 0
            ld h, a
.rdn:       ldh a, [n9_at]                  ; A = the byte at NES address HL
            and a
            jr z, .rs
            bit 7, h
            jr z, .rs
            bit 6, h
            jr nz, .rs
            ld a, h
            sub $40
            ld h, a
            ld a, [hl]
            ret
.rs:        call izrd_c
            ld a, l
            ret

; ------------------------------------------------------------------ p34:966A (bconv)
; English text: copy the line at $7AD7 + X into the text buffer at ($4E) + Y after adding $18
; to $4E ($A558); code $01: $4E += 2 * $18, Y = 0 (next line); code $02 n: Y += n; $00 ends.
; Out as the NES: A = 0, Z = 1, N = 0 (or, if Y wraps, the last character with Z = 1), C from
; the last carry-producing step; X, Y as the loop leaves them.
nat_966a:   ld hl, far_966a                 ; (body in the runtime tables bank)
            jp far_call
nat_fbef:   ld h, a
            ld a, e
            ld [NES_RAM + $20], a
            cp $FF
            jr nz, .n1
            ld a, $FF                       ; (TXA: N = 1, Z = 0; C = 1 from CPX)
            ldh [nzv], a
            ld a, 1
            and a
            scf
            ld a, $FF
            ret
.n1:        ld a, h
            and a
            jr z, .eq
            cp e
            jr z, .eq
            sub e                           ; d
            ld [NES_RAM + $18], a
            ld b, a
            xor a
            ld [NES_RAM + $19], a
            ld [NES_RAM + $1B], a
            ld [NES_RAM + $1F], a
            inc a
            ld [NES_RAM + $1A], a
            ld a, b                         ; $1C = (d & 1) << 7
            rrca
            and $80
            ld [NES_RAM + $1C], a
            ld a, [NES_RAM + $21]           ; t = $7BE3 + ($15 + $21), that counter + 1
            add a, $15
            ld l, a
            ld h, high(NES_RAM)
            ld a, [hl]
            inc [hl]
            ld l, a
            ld h, 0
            ld de, $DBE3                    ; ($7BE3 in PRG-RAM)
            add hl, de
            ld a, [hl]
            ld e, a                         ; HL = d * t
            ld d, 0
            ld hl, 0
            push bc
.ml:        srl b
            jr nc, .ms
            add hl, de
.ms:        sla e
            rl d
            ld a, b
            and a
            jr nz, .ml
            pop bc
            ld a, b                         ; + d / 2
            srl a
            add a, l
            ld l, a
            jr nc, .mc
            inc h
.mc:        ld a, l
            ld [NES_RAM + $1D], a
            ld a, h
            ld [NES_RAM + $1E], a
            bit 7, l                        ; X = $1E (+ 1 if $1D bit 7)
            jr z, .x
            inc a
.x:         ld e, a
            ld d, 0
            ld b, 0
            ld hl, NES_RAM + $20            ; A = X + $20
            add a, [hl]
            ldh [nzv], a
            ret
.eq:        ld l, a                         ; A unchanged, Z = 1, C = 1, N = 0
            xor a
            ldh [nzv], a
            scf
            ld a, l
            ret

; ------------------------------------------------------------------ p34:8F57
; sort attack order list (recursive): keys at ($1C) + 1.., indices at ($1E) + 1.. (PRG-RAM or
; RAM; set to 0.. first), step for step as the NES code (same final $18-$22, arrays, A, X, Y,
; flags); pushes / pops through HL (flags kept). X = E, Y = C.
nat_8f57:                                   ; (body in the runtime tables bank: far_8f57)
            push af
            ld a, RT_TABLES
            ld [MBC5_BANKL], a
            pop af
            call far_8f57
            push af
            ldh a, [code_bank]
            ld [MBC5_BANKL], a
            pop af
            ret

; ------------------------------------------------------------------ fix:DEEA
; copy tiles to vram: X tiles (0 = 256) of 16 bytes from ($80) + Y through $2007 (the source
; runs on linearly: Y wraps into $81). CHR destinations (step 1, tile-aligned) four tiles at a
; time into the staging copy (chr64_fast), else byte by byte. Out: X = 0, $82 = 0, Y and $81
; advanced, A = the last byte, Z = 1, N = 0, C kept.
nat_deea:   push af                         ; (C kept)
            xor a
            ldh [wc_n], a
            ld [NES_RAM + $82], a
            ldh [ch_fl], a
.tl:        ld a, e                         ; tiles in this piece: min(4, left) (0 = 256)
            dec a
            cp 3
            jr c, .n
            ld a, 3
.n:         inc a
            ld b, a                         ; B = tiles
            ldh a, [ppu_ctrl]               ; CHR, step 1, tile-aligned: the fast way
            and 4
            jr nz, .slow
            ldh a, [ppu_vh]
            cp $20
            jr nc, .slow
            ldh a, [ppu_vl]
            and $0F
            jr nz, .slow
            ld a, [NES_RAM + $80]           ; source = ($80) + Y
            add a, c
            ldh [ch_sl], a
            ld a, [NES_RAM + $81]
            adc a, 0
            ldh [ch_sh], a
            ld a, b
            swap a
            ldh [ch_n], a
            push bc
            push de
            call chr64_fast
            pop de
            pop bc
            jr c, .slow
            ld a, b                         ; Y += 16 * tiles (into $81)
            swap a
            add a, c
            ld c, a
            jr nc, .nc
            ld hl, NES_RAM + $81
            inc [hl]
.nc:        ld a, e
            sub b
            ld e, a
            jr nz, .tl
            jr .end
.slow:      ld a, b                         ; this piece byte by byte
            swap a
            ld b, a
.sb:        ld l, $80
            call rt_izy_rd
            ld a, l
            ldh [nt_a], a
            call rt_ppu_w7
            inc c
            jr nz, .sn
            ld hl, NES_RAM + $81
            inc [hl]
.sn:        dec b
            ld a, b
            and $0F
            jr nz, .s2
            dec e                           ; (a tile done)
.s2:        ld a, b
            and a
            jr nz, .sb
            ld a, e
            and a
            jr nz, .tl
            jr .end
.end:       ld e, 0
            ld b, 0
            ld d, 0
            xor a
            ldh [nzv], a
            pop af
            ld a, 0
            inc a
            dec a                           ; Z = 1 (DEX), carry kept
            ldh a, [nt_a]
            ret

; ------------------------------------------------------------------ far natives
; Cold natives, in the runtime tables bank (RT_TABLES, mapped by their bank-0 stubs; they
; call only bank-0 code and make no ROM data reads, so no NES interrupt runs inside them).
nat_end0:
section bank RT_TABLES, $4000
far_9f98:
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
            and 7                           ; (SVBK reads with bits 3-7 set)
            inc a
            cp 4
            jr c, .sb
            ld a, MAP_BANK                  ; nametables (WRAM bank MAP_BANK)
            ldh [rSVBK], a
            ld hl, NT_SH
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
            ldh a, [bcam]                   ; (battle cameras: the window rows' bank)
            and a
            ldh a, [spl_bank]
            call nz, rebank_spl
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
            ld [FRZW], a
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


far_fc27:   ld hl, NES_RAM                  ; seed: A + the zero page with carries (ADC $00,X)
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
            ld hl, $DBE3                    ; table ($7BE3)
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
            call far_fcf5
            ld a, [NES_RAM + $1C]
            ld [NES_RAM + $18], a
            ld a, [NES_RAM + $1D]
            ld [NES_RAM + $19], a
            ld a, 0
            ld [NES_RAM + $1A], a
            ld a, 4
            ld [NES_RAM + $1B], a           ; (loads keep the multiply's carry)
            call far_fc92
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
            ld [$DCE2], a                   ; table[255]
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


far_8f57:   ld a, [NES_RAM + $1D]           ; GB bases of the two tables
            ld h, a
            ld a, [NES_RAM + $1C]
            ld l, a
            call .map
            ld a, l
            ldh [n9_y], a
            ld a, h
            ldh [n9_at], a
            ld a, [NES_RAM + $1F]
            ld h, a
            ld a, [NES_RAM + $1E]
            ld l, a
            call .map
            ld a, l
            ldh [c_x], a
            ld a, h
            ldh [c_val], a
            ld a, [NES_RAM + $22]           ; LDA $22 / PHA / SEC / SBC $1A / TAX / INX / STX $18
            ld l, a
            push hl
            ld hl, NES_RAM + $1A
            sub [hl]
            inc a
            ld [NES_RAM + $18], a
            ld c, 1                         ; indices: ($1E) + 1.. = 0..
            ld e, 0
.ini:       call .iadr
            ld [hl], e
            inc c
            inc e
            ld a, [NES_RAM + $18]
            cp e
            jr nz, .ini
            pop hl                          ; PLA
            ld a, l
            call .p6f
            ret
.p6f:       ld [NES_RAM + $1B], a
            ld a, [NES_RAM + $18]
            ld l, a
            push hl
            ld a, [NES_RAM + $19]
            ld l, a
            push hl
            ld l, e
            push hl
            ld a, [NES_RAM + $1A]
            ld e, a                         ; X = $1A
            ld [NES_RAM + $18], a
            ld a, [NES_RAM + $1B]
            ld [NES_RAM + $19], a
            ld a, [NES_RAM + $1A]
            ld c, a
            call .kadr
            ld a, [hl]
            ld [NES_RAM + $20], a
.l87:       ld a, [NES_RAM + $1B]           ; Y = $1B; Y < $1A: done
            ld c, a
            ld hl, NES_RAM + $1A
            cp [hl]
            jr c, .d3
.l8d:       call .kadr                      ; down while key[Y] < pivot
            ld a, [hl]
            ld hl, NES_RAM + $20
            cp [hl]
            jr nc, .l96
            dec c
            jr .l8d
.l96:       ld a, c
            ld [NES_RAM + $1B], a
            ld a, [NES_RAM + $1A]
            ld c, a
.l9a:       call .kadr                      ; up while key[Y] > pivot
            ld a, [hl]
            ld hl, NES_RAM + $20
            cp [hl]
            jr z, .a5
            jr c, .a5
            inc c
            jr .l9a
.a5:        ld a, c
            ld [NES_RAM + $1A], a
            ld a, [NES_RAM + $1B]
            ld c, a
            ld hl, NES_RAM + $1A
            cp [hl]
            jr c, .d3
            call .kadr                      ; swap entries $1B and $1A
            ld e, [hl]                      ; X = key[$1B]
            call .iadr
            ld a, [hl]
            ld [NES_RAM + $21], a
            ld a, [NES_RAM + $1A]
            ld c, a
            call .kadr
            ld b, [hl]
            ld a, [NES_RAM + $1B]
            ld c, a
            call .kadr
            ld [hl], b
            ld a, [NES_RAM + $1A]
            ld c, a
            call .iadr
            ld b, [hl]
            ld a, [NES_RAM + $1B]
            ld c, a
            call .iadr
            ld [hl], b
            ld a, [NES_RAM + $1A]
            ld c, a
            call .iadr
            ld a, [NES_RAM + $21]
            ld [hl], a
            call .kadr
            ld [hl], e
            ld b, 0
            ld hl, NES_RAM + $1B
            dec [hl]
            ld hl, NES_RAM + $1A
            inc [hl]
            jr .l87                         ; (BCS: C = 1 from the CPY above)
.d3:        ld a, [NES_RAM + $1A]           ; X = $1A
            ld e, a
            ld a, [NES_RAM + $18]           ; Y > $18: the left part
            cp c
            jr nc, .e3
            ld [NES_RAM + $1A], a
            ld a, c
            call .p6f
.e3:        ld a, [NES_RAM + $19]           ; X < $19: the right part
            ld l, a
            ld a, e
            cp l
            ccf                             ; (6502 carry: X >= $19)
            jr c, .ee
            ld [NES_RAM + $1A], a
            ld a, [NES_RAM + $19]
            call .p6f
.ee:        pop hl                          ; PLA / TAX / PLA / STA $19 / PLA / STA $18
            ld e, l
            pop hl
            ld a, l
            ld [NES_RAM + $19], a
            pop hl
            ld a, l
            ld [NES_RAM + $18], a
            ldh [nzv], a
            ld b, 0
            ld d, 0
            inc a
            dec a
            ret
.kadr:      ldh a, [n9_y]                   ; HL = key table + Y
            add a, c
            ld l, a
            ldh a, [n9_at]
            adc a, 0
            ld h, a
            ret
.iadr:      ldh a, [c_x]                    ; HL = index table + Y
            add a, c
            ld l, a
            ldh a, [c_val]
            adc a, 0
            ld h, a
            ret
.map:       ld a, h                         ; NES RAM / PRG-RAM address -> GB
            cp $20
            jr nc, .mp
            and 7
            or high(NES_RAM)
            ld h, a
            ret
.mp:        call prg_page
            ld h, a
            ret


; ------------------------------------------------------------------ main menu ($5808 / $5809)
; GB layout (tools/gb3/layout.py main_menu): A <> 0: menu mode on (camera MCAM_X / 0, the right
; windows on the window layer, the SCY steps of MNU_EV from the LYC interrupt); A = 0: off
; (field camera, the HP rows' palettes from the NES attributes again).
far_5808:   and a
            jr z, .off
            ldh a, [mnu]
            and a
            ret nz
            ld a, $FF                       ; (no step this frame: the vblank starts them)
            ldh [rLYC], a
            xor a
            ldh [mnu_i], a
            ldh [ovr_st], a
            ldh [cam_y], a
            ldh [rWY], a
            ld a, MCAM_X
            ldh [cam_x], a
            ld a, MNU_WX
            ldh [rWX], a
            ld a, $40                       ; STAT interrupt on LY = LYC
            ldh [rSTAT], a
            ldh a, [rIF]
            and $FD
            ldh [rIF], a
            ldh a, [rIE]
            or 2
            ldh [rIE], a
            ld a, 1
            ldh [mnu], a
            ld a, $FF                       ; every map row again (the window map's copy)
            ld hl, map_dirty
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl], a
            ld hl, attr_dirty
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl], a
            ld a, 1
            ldh [map_any], a
            ret
.off:       ldh a, [mnu]
            and a
            jr z, .rest
            ld a, RT_WBANK                  ; (ATTR_STALE: WRAM bank RT_WBANK)
            ldh [rSVBK], a
            ld hl, ATTR_STALE               ; (menu closed: every attribute byte stale: the
            ld a, 1                         ;   map shares its cells between the nametables,
.st:        ld [hl+], a                     ;   and the menu left its palettes on cells the
            bit 7, l                        ;   next screen draws from the other one, whose
            jr z, .st                       ;   attribute values need not change)
            ldh [rSVBK], a
            ldh [attr_st], a
            xor a
            ldh [mnu], a
            ld a, [FRZ]                     ; (a held menu screen keeps its raster: the vblank
            and a                           ;   drops it when the next picture is shown)
            jr nz, .keep
            xor a
            ldh [rSTAT], a
            ldh a, [rIE]
            and $FD
            ldh [rIE], a
.keep:      ld a, CAM_X
            ldh [cam_x], a
            ld a, CAM_Y
            ldh [cam_y], a
.rest:      push bc                         ; rows with set palettes: from the NES attributes
            push de                         ;   again (all 32 cells)
            ld d, 0
.rr:        ld a, d
            and 7
            ld hl, BIT_MASK
            add a, l
            ld l, a
            jr nc, .rn
            inc h
.rn:        ld c, [hl]
            ld a, d
            rrca
            rrca
            rrca
            and 3
            add a, low(OVR_ROWS)
            ld l, a
            ld h, high(OVR_ROWS)
            ld a, [hl]
            and c
            jr z, .nx
            ld a, [hl]
            xor c
            ld [hl], a
            ld a, d                         ; (only the cells set: first column, count)
            add a, low(OVR_NC)
            ld l, a
            ld h, high(OVR_NC)
            ld a, [hl]
            ld b, a
            ld a, d
            add a, low(OVR_FC)
            ld l, a
            ld a, [hl]
            ld e, a
            add a, b
            ldh [c_x], a                    ; (end column)
.c:         ld a, d                         ; attribute byte NT_SH + $3C0 + (row >> 2) * 8
            and $1C                         ;   + (col >> 2)
            add a, a
            ld l, a
            ld a, e
            rrca
            rrca
            and 7
            add a, l
            add a, $C0
            ld l, a
            ld h, high(NT_SH) + 3
            ld a, MAP_BANK                  ; (NT_SH: WRAM bank MAP_BANK)
            ldh [rSVBK], a
            ld a, [hl]
            bit 1, d                        ; quadrant: row bit 1 -> high nibble, col bit 1
            jr z, .t                        ;   -> bits 2-3
            swap a
.t:         bit 1, e
            jr z, .u
            rrca
            rrca
.u:         and 3
            ld b, a
            ldh a, [bg_bank]
            or b
            ld b, a
            call mnu_cell
            ld a, MAP_BANK
            ldh [rSVBK], a
            ld [hl], b
            inc e
            ldh a, [c_x]
            cp e
            jr nz, .c
            ld a, 1
            ldh [rSVBK], a
            ld a, d
            call mnu_mark
.nx:        inc d
            ld a, d
            cp 30
            jr c, .rr
            pop de
            pop bc
            ret

far_580C:   push bc                         ; A = count * 4 + palette: row OVR_R from column
            push de                         ;   OVR_C
            ld b, a
            and 3
            ld c, a
            ldh a, [bg_bank]
            or c
            ld c, a
            ld a, b
            rrca
            rrca
            and $3F
            ld b, a
            ld a, [OVR_R]
            ld d, a
            ld a, [OVR_C]
            ld e, a
            jr mnu_set

far_5809:   push bc                         ; A = member * 4 + palette: the member's HP row
            push de                         ;   (NES row 3 + 5 * member, cols 4-14)
            ld b, a
            and 3
            ld c, a
            ldh a, [bg_bank]
            or c
            ld c, a                         ; C = attribute (palette, BG table bank)
            ld a, b
            rrca
            rrca
            and 3
            ld b, a
            add a, a
            add a, a
            add a, b
            add a, 3
            ld d, a
            ld e, 4
            ld b, 11
mnu_set:    ld a, d                         ; B cells from row D column E: attribute C
            add a, low(OVR_FC)              ;   (recorded for the restore)
            ld l, a
            ld h, high(OVR_FC)
            ld [hl], e
            ld a, d
            add a, low(OVR_NC)
            ld l, a
            ld [hl], b
            call mnu_cell
            ld a, MAP_BANK
            ldh [rSVBK], a
.w:         ld a, c
            ld [hl+], a
            dec b
            jr nz, .w
            ld a, 1
            ldh [rSVBK], a
            ld a, d                         ; (the row recorded for the restore)
            and 7
            ld hl, BIT_MASK
            add a, l
            ld l, a
            jr nc, .n
            inc h
.n:         ld c, [hl]
            ld a, d
            rrca
            rrca
            rrca
            and 3
            add a, low(OVR_ROWS)
            ld l, a
            ld h, high(OVR_ROWS)
            ld a, [hl]
            or c
            ld [hl], a
            ld a, d
            call mnu_mark
            pop de
            pop bc
            ret

mnu_cell:   ld a, d                         ; HL = ATTR_SH + D * 32 + E
            rrca
            rrca
            rrca
            ld h, a
            and $E0
            or e
            ld l, a
            ld a, h
            and 3
            add a, high(ATTR_SH)
            ld h, a
            ret

mnu_mark:   ld b, a                         ; attribute row A marked for the vblank copy
            and 7
            ld hl, BIT_MASK
            add a, l
            ld l, a
            jr nc, .n
            inc h
.n:         ld c, [hl]
            ld a, b
            rrca
            rrca
            rrca
            and 3
            add a, low(attr_dirty)
            ld l, a
            ld h, $FF
            ld a, c
            or [hl]
            ld [hl], a
            ld a, 1
            ldh [map_any], a
            ret

; ------------------------------------------------------------------ fix:FCF5
; multiply (16-bit): $1C-$1F = $18:$19 * $1A:$1B, the NES loop step for step in registers
; (same final $1A-$1F, A, carry). In: C (6502 carry) as the NES reads it. Out: X = 0, A = the
; last $1F computed (0 if none), Z = 1, N = 0, C from the last ROR; Y kept.
far_fcf5:   push af                         ; (unrolled: 16 steps)
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
far_fc92:   push af
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

; ------------------------------------------------------------------ p34:95E1
; convert hex to decimal: $18/$19 -> $1A-$1D (ten-thousands .. tens, + $80; leading zeros $FF)
; and $1E (units + $80), by repeated subtraction as the NES does. Left as the NES leaves it:
; $18 = units, $19 = 0, $1F = $FF, $20 / $21 = 10 / 0, X = 3, Y kept; A and flags from the
; leading-zero scan: the first nonzero digit (Z = 0, N = 0, C = 1) or, all zero, $FF (N = 1,
; Z = 0, C = 1).
far_95e1:
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


; ------------------------------------------------------------------ condensed names (far)
; far_cvr (nat_h1, spans in cv_s / cv_e): for each span of the line $07A0: leading cells whose
; code has no condensed glyph (item icons) kept, the run of glyph codes after them (trailing
; blanks dropped) packed in the condensed letters (CV_W / CV_G: tools/latin_font.py COND, built
; by build.py; 1-px gaps) into as many tiles as the pixels need, written to the sprite table's
; staging copy (WRAM bank 3, tiles CV_LO-CV_HI, their old contents saved once in bank 7) and
; marked for the vblank DMA; CV_SUB says per cell: tile (bank 1), blank, or keep.
CV_T0 = $CD96               ; scratch (fixed WRAM): span start, run end, cells, tiles
CV_T1 = $CD97
CV_T2 = $CD98
CV_T3 = $CD99
CV_T4 = $CD9C
CV_T5 = $CD9D               ;   the span's start, its snapshot (low byte)
CV_T6 = $CD9F
far_cvr:    push bc
            push de
            ld hl, CV_SUB
            xor a
            ld b, 64
.z:         ld [hl+], a
            dec b
            jr nz, .z
            ld e, 0                         ; E = span index
.sp:        ldh a, [cv_n]
            cp e
            jr z, .end
            jr c, .end
            push de
            call cvr_span
            pop de
            inc e
            jr .sp
.end:       ld a, 1
            ldh [rSVBK], a
            pop de
            pop bc
            ret
; span E
cvr_span:   ld a, e
            swap a
            add a, low(CV_SNAP)
            ld [CV_T6], a
            ld a, e
            add a, low(cv_e)
            ld c, a
            ldh a, [c]
            cp 64
            jr c, .e1
            ld a, 64
.e1:        ld d, a                         ; D = end
            ld a, e
            add a, low(cv_s)
            ld c, a
            ldh a, [c]
            ld e, a                         ; E = start
            ld [CV_T5], a
.lead:      ld a, e                         ; skip blanks and cells without a glyph (icons)
            cp d
            ret nc
            call cv_code
            cp $FF
            jr z, .skip
            call cv_w
            and a
            jr nz, .run
.skip:      inc e
            jr .lead
.run:       ld a, e
            ld [CV_T0], a                   ; run start
.r1:        ld a, e
            cp d
            jr nc, .r2
            call cv_code
            cp $FF
            jr z, .r3
            call cv_w
            and a
            jr z, .r2
.r3:        inc e
            jr .r1
.r2:        ld a, e
            ld [CV_T1], a                   ; run end (cells kept after it)
.tr:        ld a, [CV_T0]                   ; trailing blanks off
            cp e
            jr nc, .t2
            dec e
            call cv_code
            cp $FF
            jr z, .tr
            inc e
.t2:        ld a, [CV_T0]
            ld b, a
            ld a, e
            sub b
            cp 2
            ret c                           ; (one letter: nothing to gain)
            ld [CV_T2], a                   ; letters
            ld hl, PC_BUF                   ; strip clear
            xor a
            ld c, 64
.sc:        ld [hl+], a
            dec c
            jr nz, .sc
            ld c, 0                         ; C = pixel column
            ld a, [CV_T0]
            ld e, a
.gl:        ld a, [CV_T0]
            cp e
            jr z, .g0
            inc c                           ; (gap)
.g0:        call cv_code
            call cv_glyph                   ; draws at C, C += width; NC = fits
            ret c
            inc e
            ld a, [CV_T2]
            ld b, a
            ld a, [CV_T0]
            add a, b
            cp e
            jr nz, .gl
            ld a, c                         ; tiles = (pixels + 7) / 8 <= cells of the run
            add a, 7
            rrca
            rrca
            rrca
            and $1F
            ld [CV_T3], a
            ld b, a
            ld a, [CV_T0]
            ld c, a
            ld a, [CV_T1]
            sub c
            cp b
            ret c
            ld a, [CV_T0]                   ; tiles: allocated, drawn, CV_SUB
            ld e, a
            ld c, 0                         ; C = strip tile
.tl:        call cv_same                    ; (a cell written over since, not by a blank:
            jr z, .tl1                      ;   the name stays as it is)
            call cv_buf
            cp $FF
            jr nz, .fail
.tl1:       call cv_alloc                   ; -> A = tile, C (carry) = none left
            jr c, .fail
            ld b, a
            ld h, high(CV_SUB)
            ld a, e
            add a, low(CV_SUB)
            ld l, a
            ld [hl], b
            call cv_put                     ; tile B <- strip tile C
            inc e
            inc c
            ld a, [CV_T3]
            cp c
            jr nz, .tl
            ld a, [CV_T1]                   ; the rest of the run: blank
            ld d, a
.bl:        ld a, e
            cp d
            jr nc, .ok
            call cv_same                    ; (cells written over since: kept)
            jr nz, .bl2
            ld h, high(CV_SUB)
            ld a, e
            add a, low(CV_SUB)
            ld l, a
            ld [hl], 1
.bl2:       inc e
            jr .bl
.ok:        ld a, 1
            ldh [cv_live], a
            ret
.fail:      ld a, [CV_T0]                   ; (no tiles left: the name stays as it is)
            ld c, a
.f1:        ld a, c
            cp e
            ret nc
            ld h, high(CV_SUB)
            add a, low(CV_SUB)
            ld l, a
            ld [hl], 0
            inc c
            jr .f1
cv_code:    push hl                         ; A = the name's code in cell E (its snapshot)
            ld a, [CV_T5]
            ld l, a
            ld a, e
            sub l
            cp 16
            jr nc, .bl
            ld l, a
            ld a, [CV_T6]
            add a, l
            ld l, a
            ld h, high(CV_SNAP)
            ld a, 7
            ldh [rSVBK], a
            ld l, [hl]
            ld a, 1
            ldh [rSVBK], a
            ld a, l
            pop hl
            ret
.bl:        ld a, $FF
            pop hl
            ret
cv_buf:     push hl                         ; A = the line's code in cell E now
            ld a, e
            add a, low(NES_RAM + $7A0)
            ld l, a
            ld h, high(NES_RAM + $7A0)
            ld a, [hl]
            pop hl
            ret
cv_same:    call cv_buf                     ; Z: cell E still holds the name's code
            push bc
            ld b, a
            call cv_code
            cp b
            pop bc
            ret
cv_w:       push hl                         ; A = glyph width of code A (0: none)
            ld h, high(CV_W)
            ld l, a
            ld a, [hl]
            pop hl
            ret
; glyph of code A at pixel C of the strip (8 tiles x 8 rows, plane 0); C += width. C: past 64
cv_glyph:   push de
            ld l, a
            ld h, high(CV_W)
            ld a, [hl]                      ; width
            ld d, a
            add a, c
            cp 65
            jr nc, .no
            push af
            ld a, l                         ; HL = CV_G + 8 * code
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            ld a, h
            add a, high(CV_G)
            ld h, a
            ld a, c                         ; DE = strip + 8 * (C >> 3); B = C & 7
            and 7
            ld b, a
            ld a, c
            and $38
            ld e, a
            ld d, high(PC_BUF)
            ld a, e
            add a, low(PC_BUF)
            ld e, a
            ld c, 8
.row:       push bc
            ld a, [hl+]
            ld c, 0                         ; A:C = the row >> B
            inc b
            jr .s1
.s0:        srl a
            rr c
.s1:        dec b
            jr nz, .s0
            ld b, a
            ld a, [de]
            or b
            ld [de], a
            ld a, e
            add a, 8
            ld e, a
            ld a, [de]
            or c
            ld [de], a
            ld a, e
            sub 7
            ld e, a
            pop bc
            dec c
            jr nz, .row
            pop af
            ld c, a
            pop de
            and a
            ret
.no:        pop de
            scf
            ret
; A = a free tile of CV_LO-CV_HI (marked used); carry: none (after one scan of the map)
cv_alloc:   push bc
            push de
            push hl
            ld a, 7
            ldh [rSVBK], a
            ld c, 0                         ; C = tiles tried, E = map scanned
            ld e, 0
.n:         ld a, [CV_NEXT]
            inc a
            cp CV_HI + 1
            jr nc, .w
            cp CV_LO
            jr nc, .n2
.w:         ld a, CV_LO
.n2:        ld [CV_NEXT], a
            ld d, a
            call cv_bit                     ; HL = CV_USED byte, B = mask
            ld a, [hl]
            and b
            jr z, .got
            inc c
            ld a, c
            cp CV_HI - CV_LO + 1
            jr c, .n
            ld a, e
            and a
            jr nz, .none
            inc e
            call cv_rescan
            ld c, 0
            jr .n
.got:       ld a, [hl]
            or b
            ld [hl], a
            ld a, d
            and a
            jr .x
.none:      scf
.x:         push af
            ld a, 1
            ldh [rSVBK], a
            pop af
            pop hl
            pop de
            pop bc
            ret
cv_bit:     ld a, d                         ; D = tile -> HL = CV_USED + D >> 3, B = 1 << (D & 7)
            ld h, high(CV_USED)
            push af
            rrca
            rrca
            rrca
            and $1F
            add a, low(CV_USED)
cv_bit2:    ld l, a
            pop af
            and 7
            ld b, 1
            inc a
.b:         dec a
            ret z
            sla b
            jr .b
cv_sbit:    ld a, d                         ; the same in CV_SAVED
            ld h, high(CV_SAVED)
            push af
            rrca
            rrca
            rrca
            and $1F
            add a, low(CV_SAVED)
            jr cv_bit2
; tiles in use again from the map: cells with the bank-1 bit, plus this line's (bank 7 selected)
cv_rescan:  ld hl, CV_USED
            xor a
            ld c, 32
.c:         ld [hl+], a
            dec c
            jr nz, .c
            ld de, ATTR_SH
.s:         ld a, MAP_BANK
            ldh [rSVBK], a
            ld a, [de]
            bit 3, a
            jr z, .s2
            ld a, d
            sub 4
            ld h, a
            ld l, e
            ld a, [hl]                      ; the tile
            push de
            ld d, a
            ld a, 7
            ldh [rSVBK], a
            call cv_bit
            ld a, [hl]
            or b
            ld [hl], a
            pop de
.s2:        inc de
            ld a, d
            cp high(ATTR_SH) + 4
            jr nz, .s
            ld a, 7
            ldh [rSVBK], a
            ld hl, CV_SUB
            ld c, 64
.l:         ld a, [hl+]
            cp 2
            jr c, .l2
            push hl
            ld d, a
            call cv_bit
            ld a, [hl]
            or b
            ld [hl], a
            pop hl
.l2:        dec c
            jr nz, .l
            ret
; tile B (sprite table) <- strip tile C: its old contents saved once (bank 7), the 16 bytes
; written to the staging copy (bank 3, plane 1 = $FF: ink colour 3 on colour 2), marked.
; All registers kept.
cv_put:     push bc
            push de
            push hl
            ld d, b                         ; D = tile
            push bc
            ld a, 7
            ldh [rSVBK], a
            call cv_sbit
            ld a, [hl]
            and b
            jr nz, .sv
            ld a, [hl]
            or b
            ld [hl], a
            call cv_toff                    ; HL = 16 * tile
            ld c, 16
.cp:        ld a, 3                         ; staging tile (bank 3) -> CV_BAK (bank 7; same
            ldh [rSVBK], a                  ;   addresses: STAGE = CV_BAK = $D000)
            ld a, h
            add a, high(STAGE)
            ld h, a
            ld b, [hl]
            ld a, 7
            ldh [rSVBK], a
            ld [hl], b
            ld a, h
            sub high(STAGE)
            ld h, a
            inc hl
            dec c
            jr nz, .cp
.sv:        pop bc                          ; C = strip tile
            ld a, 3
            ldh [rSVBK], a
            call cv_toff
            ld a, h
            add a, high(STAGE)
            ld h, a
            ld a, c
            add a, a
            add a, a
            add a, a
            add a, low(PC_BUF)
            ld e, a
            ld a, d                         ; (D: the tile, for the mark)
            ld [CV_T4], a
            ld d, high(PC_BUF)
            ld b, 8
.w:         ld a, [de]
            ld [hl+], a
            ld a, $FF
            ld [hl+], a
            inc de
            dec b
            jr nz, .w
            ld a, 1
            ldh [rSVBK], a
            ld a, [CV_T4]                   ; mark PPU $1000 + 16 * tile
            ld d, a
            call cv_toff
            ld a, h
            or $10
            ld h, a
            call tile_mark
            ld a, 1
            ldh [chr_dirty], a
            ld [FRZW], a
            pop hl
            pop de
            pop bc
            ret
cv_toff:    ld l, d                         ; HL = 16 * D
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ret

; ------------------------------------------------------------------ p3a:858F / p3a:866E
; Field water animation, native (the NES layer's $2006 / $2007 gone; the CHR read-back that left
; the water tiles blank on the GB now reads the GB tile store). Tables: WATER_T = NES 3A:$861E-
; $866D (build.py water_src, from the user's ROM): +$00 the surface's PPU low bytes, +$20 the
; second surface set, +$30 the underwater set. Buffers: NES $7380 (CHR copy, $D380), $7F00
; (interlaced frames, $DF00).
; far_858f (3A:858F): every 2nd frame one surface set or every 4th frame (underwater) one frame
; step: two CHR bytes written. RAM: $6D / $6E as the NES. Out: as each NES path's RTS (A, X, Y,
; N / Z, C); the PPU address / latch as the NES leaves them.
far_858f:   ld a, c
            ldh [nt_y], a
            ld a, [NES_RAM + $2D]
            srl a
            jr c, .wm                       ; (not a world map)
            ld a, [NES_RAM + $78]
            cp 4
            jr nc, .uw                      ; (underwater: C = 1)
.wm:        ld a, [NES_RAM + $F0]
            srl a
            jr c, .s2
            ld a, [NES_RAM + $6D]
            bit 7, a
            jr z, .s2
            add a, 3
            and $8F
            ld [NES_RAM + $6D], a
            and $0F
            jr nz, .s1
            ld a, $90
            ld [NES_RAM + $6D], a
.s1:        ld a, [NES_RAM + $6D]           ; X = 2 * step: PPU $02 / WATER_T + X, data $7F00 + X
            and $0F
            add a, a
            ld e, a
            ld d, $02
            ld b, low(WATER_T)
            xor a
            call .pair
            jr .c0
.s2:        ld a, [NES_RAM + $6E]           ; (3A:85DF)
            bit 7, a
            jr nz, .s2w
            ldh [nzv], a                    ; (BPL taken: A = $6E, N = 0, Z of A, C = bit 0
            ld b, a                         ;   of $F0 from the LSR before)
            ld a, [NES_RAM + $F0]
            rra
            ld a, b
            ld b, 0
            ld d, b
            inc a
            dec a
            ret
.s2w:       add a, 2
            and $8F
            ld [NES_RAM + $6E], a
            and $0F
            jr nz, .s2a
            ld a, $90
            ld [NES_RAM + $6E], a
.s2a:       ld a, [NES_RAM + $6E]           ; X = step: WATER_T + $20 + X, data $7F20 + X
            and $0F
            ld e, a
            ld d, $02
            ld b, low(WATER_T) + $20
            ld a, $20
            call .pair
.c0:        ld b, a                         ; Y back; A = the last byte: N / Z of it, C = 0
            ldh a, [nt_y]
            ld c, a
            ld a, b
            ld b, 0
            ld d, b
            ldh [nzv], a
            and a
            ret
.uw:        ld a, [NES_RAM + $F0]           ; (3A:854E, C = 1)
            and 3
            jr z, .uw1
            ldh [nzv], a
            scf                             ; (A = $F0 & 3, Z = 0, N = 0, C = 1)
            ret
.uw1:       ld a, [NES_RAM + $6D]
            add a, 3
            and $0F
            jr nz, .uw2
            ld a, $10
.uw2:       ld [NES_RAM + $6D], a
            and $0F
            add a, a
            ld e, a                         ; X = 2 * step; Y = 8, 9 from step 8 (CMP #$10)
            ld d, 8
            cp $10
            jr c, .uw3
            inc d
.uw3:       ld a, d
            ldh [nt_y], a
            ld b, low(WATER_T) + $30
            xor a
            call .pair
            ldh [nzv], a
            ld b, a
            ldh a, [nt_y]
            ld c, a
            ld a, e                         ; C = (2 * step >= $10), X = 2 * step + 1
            cp $11
            ccf
            ld a, b
            ld b, 0
            ld d, b
            inc a                           ; (Z of A, C kept)
            dec a
            ret
; two CHR bytes: PPU high D, low bytes [WATER_T page: B + X], [.. + 1], data [$DF00 + A + X],
; [.. + 1]; X (E) ends one higher. Out: A = the second data byte. B, D kept; C clobbered.
.pair:      ldh [nt_a], a
            call .one
            inc e
.one:       ld a, e                         ; HL = NES CHR address, C = data
            add a, b
            ld l, a
            ld h, high(WATER_T)
            ld a, [hl]
            ldh [ppu_vl], a
            ldh a, [nt_a]
            add a, e
            ld l, a
            ld h, $DF
            ld c, [hl]
            ldh a, [ppu_vl]
            ld l, a
            ld h, d
            push de
            push bc
            call chr_put
            pop bc
            pop de
            ld a, d                         ; (the PPU address after the $2007 write, latch reset)
            ldh [ppu_vh], a
            ldh a, [ppu_vl]
            inc a
            ldh [ppu_vl], a
            xor a
            ldh [ppu_latch], a
            ld a, c
            ret

; far_866e (3A:866E): the water buffers from the CHR (C = 1, or not underwater: 8 surface tiles
; NES $0220-$029F; underwater: $0800-$081F and $0900-$091F) -> $7380, interlaced into $7F00.
; Out: X = 8, Y = 16, A = the last byte copied, Z = 1, C = 1, N = 0.
far_866e:   jr c, .surf
            ld a, [NES_RAM + $78]
            cp 4
            jr nc, .under
.surf:      ld hl, $0220
            ld de, $D380
            ld b, $80
            call .copy
            ld b, $80
            jr .lace
.under:     ld hl, $0800
            ld de, $D380
            ld b, $20
            call .copy
            ld hl, $0900
            ld b, $20
            call .copy
            ld b, $88
.lace:      ld c, 0                         ; i = 0..7: $7F00 / 01 / 10 / 11 / 20 / 21 + 2 i <-
.l:         ld a, c                         ;   base + i + $00 / $10 / .. / $50 (base = $7380 + B)
            add a, a
            ld e, a
            ld d, $DF
            ld a, b
            add a, c
            ld l, a
            ld h, $D3
            call .two
            ld a, e
            add a, $0F
            ld e, a
            call .two
            ld a, e
            add a, $0F
            ld e, a
            call .two
            ldh [nt_a], a
            inc c
            ld a, c
            cp 8
            jr nz, .l
            ld e, 8
            ld c, 16
            ld b, 0
            ld d, b
            xor a
            ldh [nzv], a
            ldh a, [nt_a]
            cp a                            ; (Z = 1, C = 1: the CPX #8 that ends the loop)
            scf
            ret
.two:       ld a, [hl]                      ; [DE] <- [HL], [DE + 1] <- [HL + $10]; HL += $20
            ld [de], a
            inc e
            ld a, l
            add a, $10
            ld l, a
            ld a, [hl]
            ld [de], a
            ld a, l
            add a, $10
            ld l, a
            ret
.copy:      push bc                         ; B bytes NES CHR HL.. -> DE..
            call chr_get
            pop bc
            ld [de], a
            inc de
            inc hl
            dec b
            jr nz, .copy
            ret
; NES CHR byte at HL ($0000-$1FFF) from the GB tile store (WRAM bank 2 / 3, chr_store's order)
; -> A. HL kept; B clobbered.
chr_get:    push hl
            ld a, l
            and $0F
            cp 8
            jr c, .lo
            sub 8
            add a, a
            inc a
            jr .k
.lo:        add a, a
.k:         ld b, a
            ld a, l
            and $F0
            or b
            ld l, a
            ld a, h
            and $10
            swap a
            add a, 2
            ldh [rSVBK], a
            ld a, h
            and $0F
            or high(STAGE)
            ld h, a
            ld b, [hl]
            ld a, 1
            ldh [rSVBK], a
            ld a, b
            pop hl
            ret

; far_ntlock ($580D): A = 1 + NES nametable 0-3 -> the GB map locked to it (after mirroring):
; its tiles and attributes copied in from the shadow (all rows marked); while locked, writes to
; the other nametable stay in its shadow (rt_ppu_w7, wc_setup). A = 0: off. (The ending's
; credits show nametable 1 while the map still holds nametable 0's last scene.)
far_ntlock: and a
            jr nz, .on
            ld [NT_LOCK], a
            ret
.on:        push bc
            push de
            dec a
            ld b, a
            ldh a, [mirror]                 ; vertical: n & 1; horizontal: n >> 1
            and a
            ld a, b
            jr z, .vm
            srl a
            jr .nt
.vm:        and 1
.nt:        ld b, a
            inc a
            ld [NT_LOCK], a
            ld a, MAP_BANK
            ldh [rSVBK], a
            ld hl, 0
.c:         push hl                         ; cells 0-$3BF: NT_SH + B * $400 -> MAP_SH
            ld a, b
            add a, a
            add a, a
            add a, h
            add a, high(NT_SH)
            ld d, a
            ld e, l
            ld a, [de]
            ld c, a
            call cell_map
            ld a, h
            sub $98 - high(MAP_SH)
            ld h, a
            ld [hl], c
            pop hl
            inc hl
            ld a, h
            cp 3
            jr nz, .c
            ld a, l
            cp $C0
            jr nz, .c
            ld a, 1
            ldh [rSVBK], a
            ld l, 0
.a:         push hl                         ; attribute bytes 0-63: all quadrants applied
            ld a, b
            add a, a
            add a, a
            add a, high(NT_SH) + 3
            ld h, a
            ld a, l
            add a, $C0
            ld l, a
            ld a, MAP_BANK
            ldh [rSVBK], a
            ld e, [hl]
            ld a, 1
            ldh [rSVBK], a
            pop hl
            push hl
            ld a, e
            cpl
            ldh [c_q], a
            ld a, e
            call attr_apply                 ; (keeps B, C)
            pop hl
            inc l
            ld a, l
            cp 64
            jr nz, .a
            ld a, $FF
            ld hl, map_dirty
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl], a
            ld a, 1
            ldh [map_any], a
            pop de
            pop bc
            ret

; far_cvoff ($580F, menus closed): the saved sprite tiles back into the staging copy (marked),
; every bank-1 bit in the map's attributes cleared (rows marked), nothing in use
far_cvoff:  push bc
            push de
            ldh a, [cv_live]
            and a
            jr z, .x
            xor a
            ldh [cv_live], a
            ldh [cv_n], a
            ldh [cv_open], a
            ld d, CV_LO
.t:         ld a, 7
            ldh [rSVBK], a
            ld a, d
            rrca
            rrca
            rrca
            and $1F
            add a, low(CV_SAVED)
            ld l, a
            ld h, high(CV_SAVED)
            ld a, d
            and 7
            ld b, 1
            inc a
.m:         dec a
            jr z, .m2
            sla b
            jr .m
.m2:        ld a, [hl]
            and b
            jr z, .nx
            ld a, b
            cpl
            and [hl]
            ld [hl], a
            ld l, d
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld c, 16
.cp:        ld a, 7
            ldh [rSVBK], a
            ld a, h
            add a, high(CV_BAK)
            ld h, a
            ld b, [hl]
            sub high(CV_BAK) - high(STAGE)
            ld h, a
            ld a, 3
            ldh [rSVBK], a
            ld [hl], b
            ld a, h
            sub high(STAGE)
            ld h, a
            inc hl
            dec c
            jr nz, .cp
            ld l, d
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld a, h
            or $10
            ld h, a
            push de
            call tile_mark
            pop de
            ld a, 1
            ldh [chr_dirty], a
            ld [FRZW], a
.nx:        inc d
            ld a, d
            cp CV_HI + 1
            jr nz, .t
            ld a, 7                         ; nothing in use
            ldh [rSVBK], a
            ld hl, CV_USED
            xor a
            ld c, 32
.u:         ld [hl+], a
            dec c
            jr nz, .u
            ld a, MAP_BANK                  ; bank-1 bits off
            ldh [rSVBK], a
            ld hl, ATTR_SH
.a:         res 3, [hl]
            inc hl
            ld a, h
            cp high(ATTR_SH) + 4
            jr nz, .a
            ld a, $FF
            ld hl, attr_dirty
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl], a
            ld a, 1
            ldh [map_any], a
.x:         ld a, 1
            ldh [rSVBK], a
            pop de
            pop bc
            ret

; ------------------------------------------------------------------ sound output (native)
; FF3's sound engine (bank $36, recompiled) computes each channel's register values into
; $7F6D-$7F8E (frequency lo / hi, volume, sweep, duty: index 0 pulse 1, 1 pulse 2, 2 triangle,
; 3 noise, 5 pulse 2 sound effect, 6 noise sound effect) with a key-on bit (bit 0) in the
; channel flags $7F4A-$7F50 (bit 7: active). Its two output routines (b36:80AB music, 8030
; sound effects) are replaced by these: the values go to the GB channels (pulses -> CH1 / CH2,
; triangle -> CH3 with a triangle wave, noise -> CH4); the key-on bits are cleared as the NES
; routines do. A channel is restarted (trigger) on key-on and when its volume changes (the GB
; takes a new volume only so); the frequency is written every frame.
SND_RAM = $DF00             ; NES $7F00 (work area, WRAM bank 1)
SND_V   = $CDE4             ; last GB volume written: CH1, CH2, CH3 (0 / 1), CH4 (fixed WRAM)
far_snd_mus:    ld a, [SND_RAM + $42]           ; music enabled?
            bit 7, a
            ret z
            push bc
            push de
            push hl
            ld hl, SND_RAM + $4A            ; pulse 1
            ld e, 0
            ld b, 0
            call snd_pch
            ld a, [SND_RAM + $4F]           ; pulse 2 (unless its sound effect plays)
            bit 7, a
            jr nz, .p2
            ld hl, SND_RAM + $4B
            ld e, 1
            ld b, 1
            call snd_pch
.p2:        call snd_tri
            ld a, [SND_RAM + $50]           ; noise (unless its sound effect plays)
            bit 7, a
            jr nz, .n
            ld hl, SND_RAM + $4D
            ld e, 3
            call snd_noi
.n:         ld hl, SND_RAM + $4E            ; dmc: its key-on bit off (the NES disables it)
            bit 7, [hl]
            jr z, .d
            res 0, [hl]
.d:         pop hl
            pop de
            pop bc
            ret
far_snd_sfx:    ld a, [SND_RAM + $49]
            and a
            ret z
            push bc
            push de
            push hl
            ld hl, SND_RAM + $4F            ; pulse 2 sound effect
            ld e, 5
            ld b, 1
            call snd_pch
            ld hl, SND_RAM + $50            ; noise sound effect
            ld e, 6
            call snd_noi
            pop hl
            pop de
            pop bc
            ret
; init sound (b36:81C3): RAM as the NES leaves it ($7F42, $7F40, $7F49, $7F4A-$7F50 = 0; A = 0,
; X = $FF, N = 1, C kept), the GB
; sound on (all channels silent, both sides, master volume full), the triangle wave loaded
far_snd_init:   push af                     ; (carry kept, as the NES routine)
            push bc
            push hl
            xor a
            ld [SND_RAM + $42], a
            ld [SND_RAM + $40], a
            ld [SND_RAM + $49], a
            ld hl, SND_RAM + $4A
            ld b, 7
.c:         ld [hl+], a
            dec b
            jr nz, .c
            ldh [rNR52], a                  ; (off: registers cleared)
            ld a, $80
            ldh [rNR52], a
            ld a, $77
            ldh [rNR50], a
            ld a, $FF
            ldh [rNR51], a
            ld hl, WAVE_RAM                 ; triangle: 0 .. 15, 15 .. 0
            xor a
.w1:        ld b, a
            swap a
            or b
            inc a                           ; (pairs: 01, 23, .. ef)
            ld [hl+], a
            ld a, b
            add a, 2
            cp 16
            jr c, .w1
            ld a, $FE
.w2:        ld b, a
            swap a
            dec b
            or b
            ld [hl+], a
            ld a, b
            dec a
            bit 7, a
            jr z, .w2
            ld a, $08                       ; DACs on, silent
            ldh [rNR12], a
            ldh [rNR22], a
            ldh [rNR42], a
            xor a
            ldh [rNR32], a
            ld [SND_V], a
            ld [SND_V + 1], a
            ld [SND_V + 2], a
            ld [SND_V + 3], a
            ld a, $80
            ldh [rNR30], a
            pop hl
            pop bc
            pop af
            ld a, 0                         ; out as the NES: A = 0, X = $FF (N = 1, Z = 0)
            ld e, $FF
            push af
            ld a, $FF
            ldh [nzv], a
            pop af
            ret
; pulse channel: HL = flags byte, E = RAM index, B = GB channel (0: CH1, 1: CH2)
snd_pch:    bit 7, [hl]
            ret z
            ld d, 0
            bit 0, [hl]
            jr z, .k
            res 0, [hl]
            inc d                           ; D = 1: key on
.k:         ld h, high(SND_RAM)
            ld a, e
            add a, $89
            ld l, a
            ld c, [hl]                      ; duty | volume (NES register 0)
            ld a, e
            add a, $7B
            ld l, a
            ld a, [hl]
            or c
            ld c, a
            ld a, b                         ; GB register base: $FF11 / $FF16
            add a, a
            add a, a
            add a, b
            add a, low(rNR11)
            push bc
            ld b, a                         ; B = NRx1
            ld a, c
            and $C0                         ; duty (the same codes)
            ld c, b
            ldh [c], a
            pop bc
            ld a, c
            and $0F
            push hl
            ld hl, VOL58                    ; pulses at 5/8 (triangle balance)
            add a, l
            ld l, a
            jr nc, .v0
            inc h
.v0:        ld a, [hl]
            pop hl
            push af                         ; GB volume
            ld a, b                         ; changed: restart
            add a, low(SND_V)
            ld l, a
            ld h, high(SND_V)
            pop af
            cp [hl]
            jr z, .vs
            ld [hl], a
            ld d, 1
.vs:        swap a
            jr nz, .v1
            ld a, $08
.v1:        push af
            ld a, b                         ; NRx2
            add a, a
            add a, a
            add a, b
            add a, low(rNR12)
            ld c, a
            pop af
            ld h, a                         ; (written only with a restart)
            ld a, d
            and a
            jr z, .nv
            ld a, h
            ldh [c], a
.nv:        ld a, b                         ; sweep: CH1 only
            and a
            jr nz, .fq
            ld h, high(SND_RAM)
            ld a, e
            add a, $82
            ld l, a
            ld a, [hl]
            call snd_swp
            ldh [rNR10], a
.fq:        ld h, high(SND_RAM)             ; frequency
            ld a, e
            add a, $74
            ld l, a
            ld a, [hl]
            and 7
            ld c, a
            ld a, e
            add a, $6D
            ld l, a
            ld l, [hl]
            ld h, c
            call snd_fq                     ; HL = GB frequency
            ld a, b
            add a, a
            add a, a
            add a, b
            add a, low(rNR13)
            ld c, a
            ld a, l
            ldh [c], a
            inc c
            ld a, d
            rrca                            ; (key on / restart: bit 7)
            and $80
            or h
            ldh [c], a
            ret
; NES sweep byte (EPPP NSSS) -> NR10 (period in GB steps, negate, shift); off: 0
snd_swp:    bit 7, a
            jr z, .off
            ld c, a
            and $07
            ld h, a                         ; shift
            ld a, c
            and $08                         ; negate
            or h
            ld h, a
            ld a, c
            swap a
            and 7
            inc a
            cp 8
            jr c, .p
            ld a, 7
.p:         swap a
            or h
            ret
.off:       xor a
            ret
; HL = NES timer (11 bits) -> HL = GB frequency for a pulse: 2048 - 131072 * 16 (t + 1) /
; 1789773 = 2048 - u - (11 u >> 6), u = t + 1 (0 below the GB's range). B, C, D, E kept.
snd_fq:     push bc
            push de
            inc hl
            ld d, h
            ld e, l                         ; DE = u
            add hl, hl
            ld b, h
            ld c, l
            add hl, hl
            add hl, hl
            add hl, bc
            add hl, de                      ; 11 u
            ld a, l
            and $C0
            rlca
            rlca
            ld b, a
            ld l, h
            ld h, 0
            add hl, hl
            add hl, hl
            ld a, l
            add a, b
            ld l, a
            jr nc, .a
            inc h
.a:         add hl, de                      ; u + (11 u >> 6)
            ld a, l
            cpl
            ld l, a
            ld a, h
            cpl
            ld h, a
            inc hl                          ; -total
            ld a, h
            add a, 8                        ; 2048 - total
            ld h, a
            bit 7, a
            jr z, .ok
            ld hl, 0
.ok:        pop de
            pop bc
            ret
; triangle (index 2): on while its linear counter value ($7F7D & $7F) is not 0
snd_tri:    ld hl, SND_RAM + $4C
            bit 7, [hl]
            ret z
            ld d, 0
            bit 0, [hl]
            jr z, .k
            res 0, [hl]
            inc d
.k:         ld a, [SND_RAM + $7D]
            and $7F
            jr z, .off
            ld a, $20
.off:       ldh [rNR32], a
            ld hl, SND_V + 2
            cp [hl]
            jr z, .s
            ld [hl], a
            ld d, 1
.s:         ld a, [SND_RAM + $76]
            and 7
            ld h, a
            ld a, [SND_RAM + $6F]
            ld l, a                         ; (the GB wave channel runs 32 steps a period
            call snd_fq                     ;   too: the pulse formula gives the octave below)
            ld a, d
            and a
            jr z, .f
            ld a, $80
            ldh [rNR30], a
.f:         ld a, l
            ldh [rNR33], a
            ld a, d
            rrca
            and $80
            or h
            ldh [rNR34], a
            ret
; noise: HL = flags byte, E = RAM index (3 music, 6 sound effect): volume $7F7B + E, period
; $7F6D + E (bits 0-3, bit 7 short mode)
snd_noi:    bit 7, [hl]
            ret z
            ld d, 0
            bit 0, [hl]
            jr z, .k
            res 0, [hl]
            inc d
.k:         ld h, high(SND_RAM)
            ld a, e
            add a, $6D
            ld l, a
            ld a, [hl]
            call snd_nr43
            ldh [rNR43], a
            ld a, e
            add a, $7B
            ld l, a
            ld a, [hl]
            and $0F
            ld hl, SND_V + 3
            cp [hl]
            jr z, .s
            ld [hl], a
            ld d, 1
.s:         ld a, d
            and a
            ret z
            ld a, [hl]
            swap a
            jr nz, .v
            ld a, $08
.v:         ldh [rNR42], a
            ld a, $80
            ldh [rNR44], a
            ret
VOL58:      db 0, 1, 1, 2, 2, 3, 4, 4, 5, 6, 6, 7, 7, 8, 9, 9


; ------------------------------------------------------------------ boot set-up (runtime tables bank)
far_boot:   xor a
            ldh [rIE], a
            ldh [rNR52], a                  ; sound off (all sound registers cleared)
            ld [MBC5_RAMG], a               ; cart RAM off (on only around each save access)
            ldh a, [rKEY1]                  ; double speed (KEY1 + STOP, interrupts off), unless
            bit 7, a                        ;   already on (soft reset)
            jr nz, .fast
            ld a, 1
            ldh [rKEY1], a
            ld a, $30
            ldh [rP1], a
            stop
.fast:      ldh a, [rLCDC]
            bit 7, a
            jr z, .off
.wv:        ldh a, [rLY]                    ; LCD off only in the vblank (release checklist)
            cp 144
            jr c, .wv
            xor a
            ldh [rLCDC], a                  ; LCD off (only here: power-on / soft reset)
.off:
            ld a, 1
            ldh [rVBK], a
            ld hl, $8000                    ; clear both VRAM banks
            ld bc, $2000
            call memclr
            xor a
            ldh [rVBK], a
            ld hl, $8000
            ld bc, $2000
            call memclr
            ld hl, $C000                    ; clear WRAM (not the stack $CF00-$CFFF in use)
            ld bc, $0F00
            call memclr
            ld a, 7                         ; every switchable WRAM bank (7 .. 1: bank 4 =
.wb:        ldh [rSVBK], a                  ;   zeros for DMA, MAP_BANK, RT_WBANK, PRG7 = bank 1)
            push af
            ld hl, $D000
            ld bc, $1000
            call memclr
            pop af
            dec a
            jr nz, .wb
            inc a
            ldh [rSVBK], a
            ld hl, $FE00                    ; clear OAM
            ld bc, $A0
            call memclr
            ld hl, $FF80                    ; clear HRAM
            ld bc, $7F
            call memclr
            ld a, $FF                       ; (no CHR tile marked yet)
            ldh [tm_hi], a
            ld hl, dma_code                 ; OAM DMA routine to HRAM
            ld de, hram_dma
            ld b, 10
.cd:        ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .cd
            xor a                           ; cart RAM bank 0 (the save slots), RAM left off
            ld [MBC5_RAMB], a
            ld [MBC5_BANKH], a
            ldh [rSCX], a
            ldh [rSCY], a
            ldh [rWY], a
            ldh [rWX], a
            ldh [rSTAT], a
            ldh [rLYC], a
            ldh [rVBK], a
            call save_check                 ; save data check (build.py save_check_src): damaged
                                            ;   save files are reported on screen, then erased
            jp boot_tail

; ------------------------------------------------------------------ moved from bank 0 (no ROM reads)
far_966a:   ld a, BCONV_GB                  ; (GB layout, tools/gb3/layout.py: lines start in
            and a                           ;   the first buffer row and a newline is one row)
            ld a, 0
            jr nz, .g0
            ld a, [NES_RAM + $18]
.g0:        call nat_a558
            call .cy
            ld hl, $DAD7                    ; HL = $7AD7 + X (X = 0)
            ld c, 0                         ; Y
.line:      ld a, [NES_RAM + $4E]           ; DE = ($4E) + Y (NES)
            add a, c
            ld e, a
            ld a, [NES_RAM + $4F]
            adc a, 0
            ld d, a                         ; in PRG-RAM up to + 255 (contiguous in the GB
            sub $70                         ;   map: $6000-$62FF, $7000-$7EFF): in place
            cp $0F
            jr c, .p7
            add a, $10
            cp 3
            jr nc, .sch
            add a, high(PRG6)
            jr .pd
.p7:        add a, high(PRG7)
.pd:        ld d, a
.ch:        ld a, [hl+]
            and a
            jr z, .end
            cp 3
            jr c, .spec
            ld [de], a
            inc de
            inc c
            jr nz, .ch
            jr .wrap
.sch:       ld a, [hl+]                     ; (elsewhere: through nes_wr)
            and a
            jr z, .end
            cp 3
            jr c, .spec
            ldh [wtmp], a
            push hl
            ld h, d
            ld l, e
            call nes_wr
            pop hl
            inc de
            inc c
            jr nz, .sch
.wrap:      ld b, a                         ; (Y wrapped: RTS with A = the character, Z = 1)
            ld a, l
            sub $D7
            ld e, a
            ld d, 0
            xor a
            ldh [nzv], a
            ldh a, [n9_y]
            rra
            ld a, b
            ld b, 0
            push af
            ld hl, sp + 0
            set 7, [hl]
            pop af
            ret
.spec:      cp 1
            jr nz, .c2
            push hl                         ; next line: $4E += 2 * $18 (ASL: carry in;
            ld a, [NES_RAM + $18]           ;   GB layout: $18)
            ld l, a
            ld a, BCONV_GB
            and a
            ld a, l
            jr nz, .g1
            add a, a
.g1:        call nat_a558
            call .cy
            pop hl
            ld c, 0
            jr .line
.c2:        ld a, [hl+]                     ; Y += the next byte
            add a, c
            ld c, a
            call .cy
            ld a, l                         ; (X wrapped to 0: BNE falls through to the store
            sub $D7                         ;   of A = Y)
            jr nz, .line
            ld a, c
            dec hl
            jr .one
.one:       ld b, a                         ; (store A at ($4E) + Y, then on as the loop)
            ldh [wtmp], a
            push hl
            ld a, [NES_RAM + $4E]
            add a, c
            ld l, a
            ld a, [NES_RAM + $4F]
            adc a, 0
            ld h, a
            call nes_wr
            pop hl
            inc hl
            inc c
            jr nz, .line
            ld a, b
            jr .wrap
.end:       ld a, l                         ; X = the end code's index
            sub $D8
            ld e, a
            ld d, 0
            ld b, 0
            xor a
            ldh [nzv], a
            ldh a, [n9_y]
            rra                             ; C back, A = 0
            inc a
            dec a                           ; Z = 1
            ret
.cy:        ld a, 0                         ; n9_y = the carry
            rla
            ldh [n9_y], a
            ret

; ------------------------------------------------------------------ fix:FBEF
; random (X..A): $20 = X; X = $FF -> A = $FF; A = 0 or A = X -> A; else d = A - X ($18, $19 = 0),
; t = $7BE3[$15 + $21] (that counter + 1) and the 16-bit multiply of d by t * 256 + $80
; ($FCF5 with C = 1), in closed form: $1A = 1, $1B = 0, $1C = (d & 1) << 7,
; $1E:$1D = d * t + d / 2, $1F = 0; X = $1E (+ 1 if $1D bit 7), A = X + $20 (N, Z, C of it).
far_bd2a:   ld hl, NES_RAM + $264
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
            ld h, $D3                       ; $7380 + X (PRG-RAM)
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
            add a, high(PRG7) - $70          ; (PRG-RAM $79xx -> GB)
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
            ld a, [$D8C3]                   ; back attack ($78C3 = $88): $43, else $03
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
; (body in the runtime tables bank: far_95e1)

section bank 0, nat_end0
