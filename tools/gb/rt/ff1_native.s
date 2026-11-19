; FF1 routines rewritten natively for speed (same RAM, register and PPU-state results as the
; NES routines; references: Disch's FF1 disassembly, routine names from it). In ROM bank
; HLE_BANK, entered through the bank-0 trampolines below (the recompiler's ext table maps
; the NES routine address to the trampoline, which returns like the NES RTS).


MD_HI      = $CCF0          ; DrawMapRowCol: current PPU address (hi, lo),
MD_LO      = $CCF1
MD_CNT     = $CCF2          ;   down counter to the nametable boundary,
MD_A       = $CCF3          ;   the NES's A at the end (last load),
MD_SRC     = $CCF4          ;   buffer offset of the first / second tile of a pair (2),
MD_IDX     = $CCF6          ;   source index,
MD_ADD     = $CCF7          ;   column: +1 for the right-hand column

section bank HLE_BANK, $4000
NBIT:       db 1, 2, 4, 8, 16, 32, 64, 128   ; (at $4000: low byte = bit number)

; ---- c62:D2EB DrawMapRowCol: the pre-rendered row (2 x 32 tiles) or column (2 x 30) from
; the draw buffers ($0780 UL, $0790 UR, $07A0 DL, $07B0 DR) into the nametables at
; mapdraw_nty ($30) / mapdraw_ntx ($31); mapflags ($2D) bit 1 = column. Each tile goes the
; rt_ppu_w7 way (shadow, owner, DMG shading, GB map) without its per-byte decoding; GB map
; writes go straight to VRAM while still in the vblank with nothing queued.
mapdraw_b:  xor a                           ; (LDA $2002)
            ldh [vbl_flag], a
            ldh [ppu_latch], a
            ld a, [NES_RAM + $30]           ; tmp = $2000 + nty * 64 (+ 2 * col, NT $2400 for
            ld l, a                         ;   col >= 16)
            rrca
            rrca
            and $3F                         ; (nty >> 2 in the low bits)
            and $03
            add a, $20
            ld h, a
            ld a, l
            rrca
            rrca
            and $C0
            ld l, a
            ld a, [NES_RAM + $31]
            cp $10
            jr c, .n0
            and $0F
            ld e, a
            ld a, h
            add a, 4
            ld h, a
            ld a, e
.n0:        ld e, a                         ; E = column in its nametable (X)
            add a, a
            or l
            ld l, a
            ld a, l
            ld [NES_RAM + $10], a
            ld a, h
            ld [NES_RAM + $11], a
            ld a, [NES_RAM + $2D]
            and $02
            jp nz, .col
            ; -- row: two tile rows of 16 pairs, nametable switch after 16 - col pairs
            ld a, e
            xor $0F
            inc a
            ld [NES_RAM + $12], a
            ld a, [NES_RAM + $11]
            ld [MD_HI], a
            ld a, [NES_RAM + $10]
            ld [MD_LO], a
            ld a, $00
            ld b, $10
            call .rowhalf                   ; UL / UR
            ld a, [NES_RAM + $10]           ; next tile row (no carry into the high byte)
            add a, $20
            ld [NES_RAM + $10], a
            ld [MD_LO], a
            ld a, [NES_RAM + $11]
            ld [MD_HI], a
            ld a, $20
            ld b, $30
            call .rowhalf                   ; DL / DR
            ld a, [NES_RAM + $12]           ; X = (16 - col) - 16, Y = 16
            sub 16
            ld e, a
            ld c, $10
            ld a, [MD_A]
            jp .exit
.rowhalf:   ld [MD_SRC], a                  ; A / B = first / second buffer of the pairs
            ld a, b
            ld [MD_SRC + 1], a
            ld a, [NES_RAM + $12]
            ld [MD_CNT], a
            xor a
            ld [MD_IDX], a
.rl:        ld a, [MD_SRC]
            call .tile
            ld a, [MD_SRC + 1]
            call .tile
            ld a, [MD_SRC + 1]              ; A = the second tile (the NES's last load)
            call .src
            ld [MD_A], a                ; (kept for the exit A below)
            ld hl, MD_CNT
            dec [hl]
            jr nz, .rn
            ld a, [NES_RAM + $11]           ; nametable boundary: tmp+1 ^ 4, tmp & $E0
            xor $04
            ld [MD_HI], a
            ld a, [NES_RAM + $10]
            and $E0
            ld [MD_LO], a
            ld [MD_A], a                    ; (A = low byte if this was the last pair)
.rn:        ld hl, MD_IDX
            inc [hl]
            ld a, [hl]
            cp $10
            jr c, .rl
            ret
            ; -- column: two tile columns of 15 pairs (UL/DL, then UR/DR), boundary after
            ;    15 - nty pairs; PPU increment 32 ($2000 = $04)
.col:       ld a, [NES_RAM + $30]
            ld b, a
            ld a, $0F
            sub b
            ld [NES_RAM + $12], a
            ld a, $04
            ldh [ppu_ctrl], a
            ld a, [NES_RAM + $11]
            ld [MD_HI], a
            ld a, [NES_RAM + $10]
            ld [MD_LO], a
            ld a, $00
            ld b, $20
            ld c, 0
            call .colhalf                   ; UL / DL
            ld a, [NES_RAM + $11]
            ld [MD_HI], a
            ld a, [NES_RAM + $10]
            inc a
            ld [MD_LO], a
            ld a, $10
            ld b, $30
            ld c, 1
            call .colhalf                   ; UR / DR
            ld a, [NES_RAM + $12]           ; X = (15 - nty) - 15, Y = 15
            sub 15
            ld e, a
            ld c, $0F
            ld a, [MD_A]
            jp .exit
.colhalf:   ld [MD_SRC], a
            ld a, b
            ld [MD_SRC + 1], a
            ld a, c
            ld [MD_ADD], a                ; (+1 for the right-hand column)
            ld a, [NES_RAM + $12]
            ld [MD_CNT], a
            xor a
            ld [MD_IDX], a
.cl:        ld a, [MD_SRC]
            call .tile
            ld a, [MD_SRC + 1]
            call .tile
            ld a, [MD_SRC + 1]
            call .src
            ld [MD_A], a
            ld hl, MD_CNT
            dec [hl]
            jr nz, .cn
            ld a, [NES_RAM + $11]           ; boundary: tmp+1 & $24, (tmp + 0/1) & $1F
            and $24
            ld [MD_HI], a
            ld a, [NES_RAM + $10]
            ld b, a
            ld a, [MD_ADD]
            add a, b
            and $1F
            ld [MD_LO], a
            ld [MD_A], a
.cn:        ld hl, MD_IDX
            inc [hl]
            ld a, [hl]
            cp $0F
            jr c, .cl
            ret
            ; A = buffer offset: A = draw_buf[offset + index]
.src:       ld hl, MD_IDX
            add a, [hl]
            ld l, a
            ld h, high(NES_RAM + $0780)
            ld a, l
            add a, low(NES_RAM + $0780)
            ld l, a
            ld a, [hl]
            ret
            ; A = buffer offset: draw that tile at the current address, advance it
.tile:      call .src
            ld d, a                         ; D = tile
            ld a, [MD_HI]
            ld h, a
            ld a, [MD_LO]
            ld l, a
            call nt_tile
            ld a, [MD_LO]                   ; address += 1 or 32 ($2000 bit 2)
            ld l, a
            ld a, [MD_HI]
            ld h, a
            ldh a, [ppu_ctrl]
            and 4
            ld a, 1
            jr z, .i1
            ld a, 32
.i1:        add a, l
            ld [MD_LO], a
            ld a, h
            adc a, 0
            and $3F
            ld [MD_HI], a
            ret
.exit:      ld b, a                         ; A, X (E), Y (C); Z = 1, C = 1, N = 0 (CPY)
            ld a, [MD_HI]                   ; PPU address left as the NES leaves it
            ldh [ppu_vh], a
            ld a, [MD_LO]
            ldh [ppu_vl], a
            xor a
            ldh [nzv], a
            ld a, b
            ld b, 0
            ld d, 0
            scf
            push af
            pop hl                          ; (F: Z and C set)
            ld l, $90                       ; (Z, C)
            push hl
            pop af
            ret

; HL = NES nametable address ($2000-$2FFF), D = tile: as rt_ppu_w7's nametable path
nt_tile:    ld a, h
            and $07
            ld b, a                         ; bit 2 = nametable, bits 0-1 = offset high
            and $04
            ld c, a
            ld a, b
            and $03
            ld b, a
            cp $03
            jr nz, .ok
            ld a, l
            cp $C0
            jr c, .ok
            ld a, h                         ; attribute area: the generic path
            ldh [ppu_vh], a
            ld a, l
            ldh [ppu_vl], a
            ld a, d
            jp rt_ppu_w7
.ok:        ld a, b
            or c
            add a, high(NT_SH)
            ld h, a                         ; HL = shadow
            ld a, [hl]
            sub d
            ld a, 0
            jr nz, .df
            inc a
.df:        ldh [sh_same], a
            ld [hl], d
            ldh a, [is_cgb]
            and a
            jr z, .dmg
            call own_set                    ; this nametable owns the GB cell
            jr .map
.dmg:       call own_fast
            ldh a, [sh_same]
            and a
            jr nz, .map
            ldh a, [lcd_on]
            and a
            jr nz, .cell
            inc a
            ldh [dmg_scan], a
            jr .map
.cell:      call fresh_set
.map:       ld a, b                         ; GB map $9800 + offset
            add a, $98
            ld h, a
            ldh a, [lcd_on]
            and a
            jr z, .dir
            ldh a, [q_head]
            ld e, a
            ldh a, [q_tail]
            cp e
            jr nz, .q
            ldh a, [$FF44]
            cp 144
            jr c, .q
            cp 152
            jr nc, .q
.dir:       ld [hl], d
            ret
.q:         ld a, d
            jp vram_put

; DMG own_set: B = offset high (0-3), C = 4 for nametable 1, L = offset low. The GB map
; cell's owner bit (OWN) and the count of cells nametable 1 owns; sh_same = 0 on a change.
; Keeps BC, DE, L.
own_fast:   ld a, c
            and a
            jr nz, .go
            ldh a, [own1_lo]                ; nametable 0, no cell owned by nametable 1
            ld h, a
            ldh a, [own1_hi]
            or h
            ret z
.go:        push de
            ld a, l
            and 7
            add a, low(NBIT)
            ld e, a
            adc a, high(NBIT)
            sub e
            ld d, a
            ld a, [de]
            ld e, a                         ; E = bit
            ld a, l                         ; byte = B * 32 + L / 8
            rrca
            rrca
            rrca
            and $1F
            ld d, a
            ld a, b
            swap a
            add a, a
            or d
            push hl
            ld l, a
            ld h, high(OWN)
            ld a, [hl]
            and e
            ld d, a                         ; old bit
            ld a, c
            and a
            jr z, .z
            ld a, d
            and a
            jr nz, .x                       ; 1 -> 1
            ld a, [hl]
            or e
            ld [hl], a
            ldh a, [own1_lo]
            add a, 1
            ldh [own1_lo], a
            ldh a, [own1_hi]
            adc a, 0
            ldh [own1_hi], a
            jr .chg
.z:         ld a, d
            and a
            jr z, .x                        ; 0 -> 0
            ld a, e
            cpl
            and [hl]
            ld [hl], a
            ldh a, [own1_lo]
            sub 1
            ldh [own1_lo], a
            ldh a, [own1_hi]
            sbc a, 0
            ldh [own1_hi], a
.chg:       xor a
            ldh [sh_same], a
.x:         pop hl
            pop de
            ret

; DMG, LCD on: map cell (B = offset high, L = offset low) drawn by DrawMapRowCol or under
; an attribute quadrant DrawMapAttributes changed. FF1 draws a row / column off the view
; and its attribute bytes the next frame: checking the cell's palette at once would use
; the old attributes and re-code its tile twice. The cell is marked in FRESH (one bit per
; GB map cell) and checked by fresh_scan in the frame waits' spare time. Keeps all but A, F.
fresh_set:  push de
            push hl
            ld a, l
            and 7
            ld e, a
            ld d, high(NBIT)
            ld a, [de]
            ld e, a
            ld a, l
            rrca
            rrca
            rrca
            and $1F
            ld d, a
            ld a, b
            swap a
            add a, a
            or d
            ld l, a
            ld h, high(FRESH)
            ld a, [hl]
            or e
            ld [hl], a
            xor a
            ld [FR_AGE], a
            ld [FR_EMPTY], a
            inc a
            ld [FR_ANY], a
            pop hl
            pop de
            ret

; frame wait (DMG, LCD on, FR_ANY): marked cells get their tiles checked for the palette
; they are drawn with, from 2 waits after the last mark on (the attributes are in by then),
; while the frame has time left (not behind, LY < FR_LY); all of them once cells have
; waited FR_FORCE waits.
fresh_scan: push bc
            push de
            push hl
            ld a, [FR_PEND]
            inc a
            jr z, .p
            ld [FR_PEND], a
.p:         ld a, [FR_AGE]
            inc a
            jr z, .a
            ld [FR_AGE], a
.a:         ld a, [FR_PEND]
            cp FR_FORCE
            ld a, 0
            jr c, .nf
            inc a
.nf:        ld [FR_FRC], a
            and a
            jr nz, .go
            ld a, [FR_AGE]
            cp 2
            jr c, .x
.go:        ld a, [FR_POS]
            ld l, a
            ld h, high(FRESH)
.byte:      ld a, [FR_FRC]                  ; time left?
            and a
            jr nz, .t
            ld a, [VBL_SEEN]
            ld b, a
            ld a, [VBL_CNT]
            cp b
            jr nz, .stop
            ldh a, [$FF44]
            cp FR_LY
            jr nc, .stop
.t:         ld a, [hl]
            and a
            jr nz, .bit
            ld a, [FR_EMPTY]                ; an empty byte
            inc a
            ld [FR_EMPTY], a
            cp 128
            jr z, .done
            ld a, l
            inc a
            and $7F
            ld l, a
            jr .byte
.bit:       ld c, 0                         ; lowest set bit
            ld e, a
.f:         rrca
            jr c, .fd
            inc c
            jr .f
.fd:        ld a, c
            ld d, high(NBIT)
            ld e, a
            ld a, [de]
            cpl
            and [hl]
            ld [hl], a
            xor a
            ld [FR_EMPTY], a
            push hl
            call fresh_cell                 ; byte L, bit C
            pop hl
            jr .byte
.done:      xor a                           ; nothing marked
            ld [FR_ANY], a
            ld [FR_PEND], a
.stop:      ld a, l
            ld [FR_POS], a
.x:         pop hl
            pop de
            pop bc
            ret

; FRESH byte L (row * 4 + col / 8), bit C: the cell's tile (from the nametable that owns the
; cell) checked for the cell's palette
fresh_cell: ld a, l
            rrca
            rrca
            and $3F
            cp 30
            ret nc
            ld b, a                         ; row
            ld a, l
            and 3
            add a, a
            add a, a
            add a, a
            or c
            ld e, a                         ; col
            ld h, high(OWN)
            ld a, c
            push de
            ld e, a
            ld d, high(NBIT)
            ld a, [de]
            pop de
            and [hl]
            ld c, 0
            jr z, .n0
            ld c, 4                         ; C = nametable * 4
.n0:        ld a, b                         ; offset = row * 32 + col
            and 7
            swap a
            add a, a
            or e
            ld l, a
            ld a, b
            srl a
            srl a
            srl a
            ld b, a                         ; offset high
            or c
            add a, high(NT_SH)
            ld h, a
            ld d, [hl]                      ; tile
            jp cell_fast

; DMG dmg_cell, LCD on: B = offset high, C = 4 for nametable 1, L = offset low, D = tile.
; The cell's palette from the attribute shadow; the tile is marked if it is coded for
; another palette (or parked). Keeps BC, DE, HL.
cell_fast:  push bc
            push hl
            ld a, l                         ; row = B * 8 + L / 32
            swap a
            rrca
            and 7
            ld e, a
            ld a, b
            add a, a
            add a, a
            add a, a
            or e
            ld e, a                         ; E = row
            ld a, l
            and 31
            ld b, a                         ; B = col
            srl a
            srl a
            ld l, a
            ld a, e
            and $1C
            add a, a
            add a, l
            add a, $C0
            ld l, a
            ld a, c
            add a, high(NT_SH) + 3
            ld h, a
            ld a, [hl]                      ; attribute byte
            bit 1, e
            jr z, .t
            swap a
.t:         bit 1, b
            jr z, .l
            rrca
            rrca
.l:         and 3
            ld e, a                         ; E = palette
            call pal_used
            ld l, d
            ld h, high(TILE_PAL)
            ld a, [hl]
            cp e
            jr z, .pk
            ld [hl], e
            ld a, d
            call dmg_mark
            jr .x
.pk:        ld a, d                         ; same palette: a parked tile is marked again
            and 7
            add a, low(NBIT)
            ld l, a
            adc a, high(NBIT)
            sub l
            ld h, a
            ld c, [hl]
            ld a, d
            rrca
            rrca
            rrca
            and $1F
            add a, low(DEFER_BM)
            ld l, a
            ld h, high(DEFER_BM)
            ld a, [hl]
            and c
            jr z, .x
            ld a, c
            cpl
            and [hl]
            ld [hl], a
            ld a, d
            call dmg_mark
.x:         pop hl
            pop bc
            ret

; E = palette (0-3): PAL_USED gets it (maps due when it is new). Keeps B, DE.
pal_used:   ld a, e
            add a, low(NBIT)
            ld l, a
            adc a, high(NBIT)
            sub l
            ld h, a
            ld a, [hl]
            ld hl, PAL_USED
            ld c, a
            and [hl]
            ret nz
            ld a, c
            or [hl]
            ld [hl], a
            ld a, 1
            ldh [maps_due], a
            ld a, PAL_STABLE - 1
            ldh [pal_age], a
            ret


; DMG attribute byte write, LCD on (rt_ppu_w7 + dmg_attr): A = new byte, D = old,
; B:C = PPU address ($23C0-$23FF / $27C0-$27FF). The shadow; the cells of the quadrants
; whose palette changed are marked for fresh_scan (rows 0-29). Keeps BC, DE.
attr_fast:  cp d
            ret z
            push bc
            push de
            ld e, a                         ; E = new
            xor d
            call quad_mask
            ld d, a                         ; D = changed quadrants
            ld a, b
            and 4
            add a, high(NT_SH) + 3
            ld h, a
            ld l, c
            ld [hl], e
            ldh a, [sgb_glob]               ; (SGB: the screen's palettes again)
            and a
            jr nz, .ng
            ld a, 1
            ldh [sgb_dirty], a
            ldh [sgb_adirty], a
.ng:        ld a, c                         ; i = C - $C0: FRESH byte of (row0, col0) =
            sub $C0                         ;   (i >> 3) * 16 + (i & 7) / 2, its bits
            ld c, a                         ;   (i & 1) * 4 + 0..3
            and $38
            add a, a
            ld b, a
            ld a, c
            and 7
            srl a
            or b
            ld l, a
            ld h, high(FRESH)
            ld a, c
            and 1
            ld e, $03                       ; E = bits of the left quadrants' two columns
            jr z, .ev
            ld e, $30
.ev:        ld a, d
            and $05                         ; top / bottom left quadrants: E, right: E << 2
            ld a, e
            ld c, 0
            bit 0, d
            jr z, .q1
            or c
            ld c, a
.q1:        bit 1, d
            jr z, .q2
            ld a, e
            add a, a
            add a, a
            or c
            ld c, a
.q2:        ld a, c                         ; C = top rows' bits
            call .two
            ld c, 0                         ; bottom rows (row0 + 2, + 3: 8 bytes on)
            bit 2, d
            jr z, .q3
            ld c, e
.q3:        bit 3, d
            jr z, .q4
            ld a, e
            add a, a
            add a, a
            or c
            ld c, a
.q4:        ld a, l
            add a, 8
            ld l, a
            cp 30 * 4                       ; (rows 30-31: no cells)
            ld a, c
            call c, .two
            xor a
            ld [FR_AGE], a
            ld [FR_EMPTY], a
            inc a
            ld [FR_ANY], a
            pop de
            pop bc
            ret
.two:       and a                           ; A = bits: rows at L and L + 4
            ret z
            ld c, a
            or [hl]
            ld [hl], a
            ld a, l
            add a, 4
            ld l, a
            ld a, c
            or [hl]
            ld [hl], a
            ld a, l
            sub 4
            ld l, a
            ret

; ---- c62:D471 DrawMapAttributes: for each of 16 (row) / 15 (column) entries, the attribute
; byte at draw_buf_at_hi/lo ($07D0 / $07E0) gets the bits of draw_buf_attr ($07C0) under
; draw_buf_at_msk ($07F0): ((old ^ attr) & mask) ^ old, through rt_ppu_w7's attribute path.
; Out: X = count, Y = last at_lo, A = last new byte, $10 = last old byte, $11 = count.
mapattr_b:  xor a
            ldh [vbl_flag], a
            ldh [ppu_latch], a
            ld a, [NES_RAM + $2D]
            and $02
            ld a, $10
            jr z, .n
            dec a
.n:         ld [NES_RAM + $11], a
            ld e, 0
.lp:        ld hl, NES_RAM + $07D0          ; address
            ld a, l
            add a, e
            ld l, a
            ld a, [hl]
            ld b, a                         ; (B: hi)
            ld a, l
            add a, $10
            ld l, a
            ld c, [hl]                      ; (C: lo)
            ld a, b                         ; old byte from the shadow (as the $2007 reads)
            and $07
            ld h, a
            and $04
            ld d, a
            ld a, h
            and $03
            or d
            add a, high(NT_SH)
            ld h, a
            ld l, c
            ld a, [hl]
            ld [NES_RAM + $10], a
            ld d, a
            inc l                           ; read buffer: the byte after (second read)
            ld a, [hl]
            ldh [ppu_rbuf], a
            ld hl, NES_RAM + $07C0
            ld a, l
            add a, e
            ld l, a
            ld a, [hl]
            xor d
            ld l, a
            ld a, e
            add a, low(NES_RAM + $07F0)
            ld h, high(NES_RAM + $07F0)
            push hl
            ld l, a
            ld a, [hl]
            pop hl
            and l
            xor d                           ; new byte
            push af
            ldh a, [is_cgb]                 ; DMG with the LCD on: the fast path
            and a
            jr nz, .gen
            ldh a, [lcd_on]
            and a
            jr z, .gen
            ld a, b
            ldh [ppu_vh], a
            ld a, c
            ldh [ppu_vl], a
            pop af
            push af
            call attr_fast
            call ppu_inc
            pop af
            ld d, a
            jr .nx
.gen:       pop af
            push de
            push af
            ld a, b
            ldh [ppu_vh], a
            ld a, c
            ldh [ppu_vl], a
            pop af
            push af
            push bc
            ld b, 0
            ld c, 0
            ld d, 0
            call rt_ppu_w7
            pop bc
            pop af
            pop de
            ld d, a                         ; (last new byte)
.nx:        inc e
            ld a, [NES_RAM + $11]
            cp e
            jr nz, .lp
            ld b, 0                         ; Y = last at_lo, A = last new byte; Z = 1, C = 1
            ld a, e
            dec a
            add a, low(NES_RAM + $07E0)
            ld l, a
            ld h, high(NES_RAM + $07E0)
            ld c, [hl]
            xor a
            ldh [nzv], a
            ld a, d
            ld d, 0
            push af
            pop hl
            ld l, $90                       ; (Z, C)
            push hl
            pop af
            ret
