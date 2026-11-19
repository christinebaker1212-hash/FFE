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
MD_FAST    = $CCF8          ;   DMG with the LCD on: the batched writer (mdf_row / mdf_col),
MD_MK      = MD_SRC         ;   (batched) DMG: mark the drawn cells in FRESH,
MD_PB      = $DCE0          ;   CGB: palettes of a GB map row (32)
SP_T       = $DCE0          ; scan_b (DMG): palettes of a map row by pair (32; MD_PB is the CGB's)
SC_VR      = $D837          ;   the view's first map row, first column
SC_VC      = $D838

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
            ld a, MDF_ON                    ; (GB_MDF=0 at build time: per tile, for checks)
            and a
            jr z, .sl
            ldh a, [dlg_on]                 ; no dialogue box: the batched writer (the VRAM
            and a                           ;   queue emptied first, so no queued map cell
            jr nz, .sl                      ;   is written after it)
.dr:        ldh a, [q_head]
            ld b, a
            ldh a, [q_tail]
            cp b
            jr z, .de
            call q_drain1
            jr .dr
.de:        ld a, [VLCD]                    ; CGB masked load (not yet being shown): no VRAM
            cp 1                            ;   writes, the GB map and the cell palettes are
            jr nz, .nv                      ;   rebuilt from the shadows when shown (MD_FAST 2)
            ld a, 1
            ld [MAP_RB], a
            ld [CGB_RP], a
            xor a
            ld [MD_MK], a
            ld a, 2
            jr .sf
.nv:        ldh a, [is_cgb]                 ; (CGB: no shading checks)
            and a
            jr z, .dm
            xor a
            ld [MD_MK], a
            inc a
            jr .sf
.dm:        ldh a, [lcd_on]                 ; DMG: the drawn cells are marked for the palette
            ld [MD_MK], a                   ;   check (FRESH, as nt_tile does); LCD off: the
            and a                           ;   map is scanned when it goes on
            jr nz, .d1
            inc a
            ldh [dmg_scan], a
.d1:        ld a, 1
            jr .sf
.sl:        xor a
.sf:        ld [MD_FAST], a
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
            ld a, [MD_FAST]
            and a
            jp nz, mdf_row
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
            ld a, [MD_FAST]
            and a
            jp nz, mdf_col
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
            ldh a, [dlg_on]                 ; a dialogue box's cell: to the window
            and a
            jr z, .nd
            call dlg_cell
            ret nz
.nd:        ldh a, [sh_same]                ; the same tile again, from the nametable that
            and a                           ;   owns the cell: nothing changes (FF1 rewrites
            jr z, .nd2                      ;   whole panels and rows)
            push de
            push hl
            ld a, l
            and 7
            add a, low(NBIT)
            ld e, a
            ld d, high(NBIT)
            ld a, [de]
            ld e, a                         ; E = the cell's bit
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
            ld h, high(OWN)
            ld a, [hl]
            and e                           ; NZ: nametable 1 owns it
            pop hl
            pop de
            jr z, .o0
            ld a, c
            and a
            ret nz
            jr .nd2
.o0:        ld a, c
            and a
            ret z
.nd2:       ldh a, [is_cgb]
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
.cell:      ld a, [NT_NOW]                  ; (ntrun_b: the palette check at once)
            and a
            jr nz, .now
            call fresh_set
            jr .map
.now:       call cell_fast
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

; ---- DrawMapRowCol batched (DMG, LCD on, no dialogue box, VRAM queue empty): the tiles
; go to the nametable shadow in runs, the GB map row / column is copied from the shadow
; (two cells per moment VRAM is free), the owner bits are set 8 cells at a time, and the
; cells whose tile is marked or parked get their palette checked (as nt_tile). The NES
; state at the end (RAM $10-$12, PPU address, A / X / Y / flags) as the per-tile loop.
mdf_row:    ld a, e                         ; E = pair column in its nametable
            add a, a
            ld [MD_ADD], a                  ; s = first column of nametable A (2 * E)
            ld a, e
            xor $0F
            inc a
            ld [NES_RAM + $12], a           ; pairs before the boundary
            ld a, [NES_RAM + $10]
            ld [MD_LO], a
            xor a
            call mdf_rsh                    ; tile row 2k: UL / UR
            call mdf_rgb
            ld a, [NES_RAM + $10]
            add a, $20
            ld [NES_RAM + $10], a
            ld [MD_LO], a
            ld a, $20
            call mdf_rsh                    ; tile row 2k + 1: DL / DR
            call mdf_rgb
            ld a, [NES_RAM + $11]           ; the address after the last tile (nametable B)
            xor $04
            ld [MD_HI], a
            ld a, [NES_RAM + $12]
            cp 16
            jr nz, .nb
            ld a, [NES_RAM + $10]           ; boundary at the last pair: A = the low byte
            and $E0
            ld [MD_LO], a
            ld [MD_A], a
            jr .ex
.nb:        ld b, a
            ld a, 16
            sub b
            add a, a
            ld b, a
            ld a, [NES_RAM + $10]
            and $E0
            add a, b
            ld [MD_LO], a
            ld a, [NES_RAM + $07BF]         ; A = the last tile (DR, pair 15)
            ld [MD_A], a
.ex:        ld a, [NES_RAM + $12]
            sub 16
            ld e, a
            ld c, $10
            ld a, [MD_A]
            jp mapdraw_b.exit

; A = buffer offset (0 / $20): 16 pairs (A[i], A[i + $10]) into the shadow row at MD_LO
; ($11 = address high), the nametable switch after $12 pairs
mdf_rsh:    add a, low(NES_RAM + $0780)
            ld c, a
            ld b, high(NES_RAM + $0780)
            ld a, [NES_RAM + $11]
            and 7
            add a, high(NT_SH)
            ld h, a
            ld a, [MD_LO]
            ld l, a
            ld a, [NES_RAM + $12]
            ld d, a
            ld e, 16
.p:         ld a, [bc]
            ld [hl+], a
            ld a, c
            add a, $10
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, c
            sub $0F
            ld c, a
            dec e
            ret z
            dec d
            jr nz, .p
            ld a, [NES_RAM + $11]           ; nametable B from column 0
            and 7
            xor 4
            add a, high(NT_SH)
            ld h, a
            ld a, [MD_LO]
            and $E0
            ld l, a
            jr .p

; the shadow row at MD_LO to the GB map (nametable A from column s = MD_ADD, B below s),
; its owner bits, the palette checks
mdf_rgb:    ld a, [NES_RAM + $11]
            and 3
            ld [MD_IDX], a                  ; offset high
            ld a, [NES_RAM + $11]
            and 7
            add a, high(NT_SH)
            ld h, a
            ld a, [MD_LO]
            ld l, a
            ld e, a
            ld a, [MD_IDX]
            add a, $98
            ld d, a
            ld a, [MD_ADD]
            cpl
            add a, 33
            srl a
            ld b, a                         ; (32 - s) / 2 pairs
            call mdf_vrun
            ld a, [NES_RAM + $11]
            and 7
            xor 4
            add a, high(NT_SH)
            ld h, a
            ld a, [MD_LO]
            and $E0
            ld l, a
            ld e, a
            ld a, [MD_IDX]
            add a, $98
            ld d, a
            ld a, [MD_ADD]
            srl a
            ld b, a                         ; s / 2 pairs
            call mdf_vrun
            ld a, [MD_FAST]                 ; CGB (not masked): the row's cell palettes (VRAM
            cp 2                            ;   bank 1)
            jr z, .np
            ldh a, [is_cgb]
            and a
            call nz, mdf_pbrow
.np:
            ld a, [MD_LO]                   ; OWN: offset high * 32 + (row & 7) * 4
            and $E0
            rrca
            rrca
            rrca
            ld l, a
            ld a, [MD_IDX]
            swap a
            add a, a
            or l
            ld l, a
            ld a, [MD_ADD]
            ld d, a
            ld a, [NES_RAM + $11]
            and 4
            jr z, .e0
            ld a, $FF
.e0:        ld e, a
            call mdf_ownrow
            ld a, [MD_MK]                   ; DMG: the row's 32 cells marked in FRESH (byte
            and a                           ;   row * 4 + col / 8), checked in spare time
            ret z
            ld a, [MD_IDX]
            add a, a
            add a, a
            add a, a
            ld b, a
            ld a, [MD_LO]
            swap a
            rrca
            and 7
            or b                            ; row
            add a, a
            add a, a
            ld l, a
            ld h, high(FRESH)
            ld a, $FF
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl], a
            jp mdf_fra

; CGB: the palettes of the GB map row at MD_LO (offset high MD_IDX) from the attribute
; shadow of the nametable that drew each cell (A from column MD_ADD, B below), to VRAM
; bank 1
mdf_pbrow:  ld a, [MD_IDX]
            add a, a
            add a, a
            add a, a
            ld b, a
            ld a, [MD_LO]
            swap a
            rrca
            and 7
            or b
            ld b, a                         ; B = row
            and $1C
            add a, a
            add a, $C0
            ld c, a                         ; C = attribute row ($C0 + (row / 4) * 8)
            ld hl, MD_PB
            ld d, 0                         ; D = pair
.p:         push hl
            ld a, [MD_ADD]
            ld e, a
            ld a, d
            add a, a
            cp e                            ; carry: column below s (nametable B)
            ld a, [NES_RAM + $11]
            jr nc, .na
            xor 4
.na:        and 4
            add a, high(NT_SH) + 3
            ld h, a
            ld a, d
            srl a
            add a, c
            ld l, a
            ld a, [hl]
            bit 1, b
            jr z, .t
            swap a
.t:         bit 0, d
            jr z, .u
            rrca
            rrca
.u:         and 3
            pop hl
            ld [hl+], a
            ld [hl+], a
            inc d
            ld a, d
            cp 16
            jr nz, .p
            ld hl, MD_PB
            ld a, [MD_LO]
            and $E0
            ld e, a
            ld a, [MD_IDX]
            add a, $98
            ld d, a
            ld b, 16
.l:         di                              ; (VRAM bank 1 only with interrupts off: the
            ldh a, [$FF41]                  ;   handlers leave bank 0 selected)
            bit 1, a
            jr z, .w
            ei
            jr .l
.w:         ld a, 1
            ldh [$FF4F], a
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            xor a
            ldh [$FF4F], a
            ei
            dec b
            jr nz, .l
            ret

; HL = source, DE = GB map, B = pairs: two cells per moment VRAM is free (STAT mode 0 / 1,
; mode 2 follows: both writes land within its 20 M-cycles); interrupts between the polls
mdf_vrun:   ld a, [MD_FAST]                 ; (masked load: rebuilt when shown)
            cp 2
            ret z
            ld a, b
            and a
            ret z
.l:         di
            ldh a, [$FF41]
            bit 1, a
            jr z, .w
            ei
            jr .l
.w:         ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            ei
            inc e
            dec b
            jr nz, .l
            ret

; OWN bytes L..L+3 (a GB map row): columns >= D owned by nametable A (E = $FF: nametable
; 1, 0: nametable 0), those below by the other one; own1 kept as the count of set bits
mdf_ownrow: ld h, high(OWN)
            ld b, 0                         ; B = first column of the byte
.j:         ld a, d
            sub b
            jr c, .ff
            jr z, .ff
            cp 8
            jr nc, .zz
            ld c, a
            ld a, $FF
.sh:        add a, a
            dec c
            jr nz, .sh
            jr .m
.ff:        ld a, $FF
            jr .m
.zz:        xor a
.m:         xor e                           ; A = columns >= D -> the new byte
            cpl
            ld c, a
            push hl
            push de
            ld e, [hl]
            ld [hl], c
            ld h, high(POPC)
            ld l, c
            ld a, [hl]
            ld l, e
            sub [hl]                        ; set bits new - old
            ld e, a
            ld d, 0
            jr nc, .p
            dec d
.p:         ldh a, [own1_lo]
            add a, e
            ldh [own1_lo], a
            ldh a, [own1_hi]
            adc a, d
            ldh [own1_hi], a
            pop de
            pop hl
            inc l
            ld a, b
            add a, 8
            ld b, a
            cp 32
            jr nz, .j
            ret

; cells were marked in FRESH: the bookkeeping fresh_set does
mdf_fra:    xor a
            ld [FR_AGE], a
            ld [FR_EMPTY], a
            inc a
            ld [FR_ANY], a
            ret

; column (DrawMapRowCol with $2D bit 1): E = pair column in its nametable, $12 = pairs
; before the wrap to row 0, ppu_ctrl set
mdf_col:    xor a
            call mdf_cone                   ; UL / DL
            ld a, 1
            call mdf_cone                   ; UR / DR
            ld a, [NES_RAM + $11]           ; the address after the last tile: from row 0
            and $24                         ;   of the right-hand column on, 64 per pair
            ld h, a
            ld a, [NES_RAM + $10]
            inc a
            and $1F
            ld l, a
            ld a, [NES_RAM + $12]
            cp 15
            jr nz, .nb
            ld a, l                         ; boundary at the last pair: A = the low byte
            ld [MD_A], a
            jr .ad
.nb:        ld b, a
            ld a, 15
            sub b
            ld b, a
            ld de, 64
.a64:       add hl, de
            dec b
            jr nz, .a64
            ld a, [NES_RAM + $07BE]         ; A = the last tile (DR, pair 14)
            ld [MD_A], a
.ad:        ld a, h
            and $3F
            ld [MD_HI], a
            ld a, l
            ld [MD_LO], a
            ld a, [NES_RAM + $12]
            sub 15
            ld e, a
            ld c, $0F
            ld a, [MD_A]
            jp mapdraw_b.exit

; CGB: palettes of the column (shadow cell of row 0 at the stack top + 2) from its
; nametable's attribute shadow, to VRAM bank 1, two rows (one quadrant row) per write
mdf_pbcol:  ld hl, sp + 2
            ld a, [hl+]
            ld c, a                         ; C = column (shadow low byte, row 0)
            ld a, [hl]
            and 4
            add a, high(NT_SH) + 3
            ld h, a
            ld a, c
            srl a
            srl a
            add a, $C0
            ld l, a                         ; HL = attribute byte of rows 0-3
            ld e, c
            ld d, $98                       ; DE = GB map row 0
            ld b, 0                         ; B = pair (rows 2B, 2B + 1)
.p:         ld a, [hl]
            bit 0, b
            jr z, .t
            swap a
.t:         bit 1, c
            jr z, .u
            rrca
            rrca
.u:         and 3
            push bc
            ld c, a
.l:         di
            ldh a, [$FF41]
            bit 1, a
            jr z, .w
            ei
            jr .l
.w:         ld a, 1
            ldh [$FF4F], a
            ld a, c
            ld [de], a
            set 5, e
            ld [de], a
            xor a
            ldh [$FF4F], a
            ei
            pop bc
            ld a, e
            add a, 32
            ld e, a
            jr nc, .n
            inc d
.n:         bit 0, b
            jr z, .s
            ld a, l
            add a, 8
            ld l, a
.s:         inc b
            ld a, b
            cp 15
            jr nz, .p
            ret

; A = 0 / 1: the left / right column of the pairs (buffers $00 / $20 or $10 / $30)
mdf_cone:   ld [MD_ADD], a
            swap a
            add a, low(NES_RAM + $0780)
            ld c, a
            ld b, high(NES_RAM + $0780)
            ld a, [NES_RAM + $11]
            and 7
            add a, high(NT_SH)
            ld h, a
            ld a, [MD_ADD]
            ld d, a
            ld a, [NES_RAM + $10]
            add a, d
            ld l, a                         ; HL = shadow of row 2 * nty
            ld a, [NES_RAM + $12]
            ld d, a
            ld e, 15
.p:         ld a, [bc]
            ld [hl], a
            ld a, l
            add a, 32
            ld l, a
            ld a, c
            add a, $20
            ld c, a
            ld a, [bc]
            ld [hl], a
            ld a, c
            sub $1F
            ld c, a
            ld a, l
            add a, 32
            ld l, a
            jr nc, .nc
            inc h
.nc:        dec e
            jr z, .dn
            dec d
            jr nz, .p
            ld a, l                         ; wrap to row 0
            and $1F
            ld l, a
            ld a, h
            and $FC
            ld h, a
            jr .p
.dn:        ld a, [NES_RAM + $11]           ; HL = the column's row 0 in the shadow
            and 4
            add a, high(NT_SH)
            ld h, a
            ld a, [NES_RAM + $10]
            and $1F
            ld b, a
            ld a, [MD_ADD]
            add a, b
            ld l, a
            push hl
            ld e, a
            ld a, [MD_FAST]                 ; (masked load: map and palettes rebuilt when
            cp 2                            ;   shown)
            jr z, .vx
            ld d, $98                       ; GB map column, 15 pairs of rows
            ld b, 15
.v:         ld c, [hl]
            set 5, l
.w:         di
            ldh a, [$FF41]
            bit 1, a
            jr z, .go
            ei
            jr .w
.go:        ld a, c
            ld [de], a
            ld a, [hl]
            set 5, e
            ld [de], a
            ei
            ld a, l
            add a, 32
            ld l, a
            jr nc, .n1
            inc h
.n1:        ld a, e
            add a, 32
            ld e, a
            jr nc, .n2
            inc d
.n2:        dec b
            jr nz, .v
            ldh a, [is_cgb]                 ; CGB: the column's cell palettes
            and a
            call nz, mdf_pbcol
.vx:
            pop hl                          ; owner bits of the column's 30 cells
            push hl
            ld a, l
            and 7
            ld e, a
            ld d, high(NBIT)
            ld a, [de]
            ld c, a                         ; C = the bit
            ld a, h
            and 4
            ld e, a                         ; E = 4 for nametable 1
            ld a, l
            rrca
            rrca
            rrca
            and 3
            ld l, a
            ld h, high(OWN)
            ld b, 30
            ld d, 0                         ; D = change of the count
.o:         ld a, [hl]
            and c
            jr z, .oz
            ld a, e
            and a
            jr nz, .on
            ld a, c
            cpl
            and [hl]
            ld [hl], a
            dec d
            jr .on
.oz:        ld a, e
            and a
            jr z, .on
            ld a, [hl]
            or c
            ld [hl], a
            inc d
.on:        ld a, l
            add a, 4
            ld l, a
            dec b
            jr nz, .o
            ld e, d
            ld d, 0
            bit 7, e
            jr z, .ps
            dec d
.ps:        ldh a, [own1_lo]
            add a, e
            ldh [own1_lo], a
            ldh a, [own1_hi]
            adc a, d
            ldh [own1_hi], a
            pop hl
            ld a, [MD_MK]                   ; DMG: the column's 30 cells marked in FRESH
            and a
            ret z
            ld a, l
            and 31
            ld b, a
            and 7
            ld e, a
            ld d, high(NBIT)
            ld a, [de]
            ld c, a                         ; C = the column's bit
            ld a, b
            rrca
            rrca
            rrca
            and 3
            ld l, a
            ld h, high(FRESH)
            ld b, 30
.fr:        ld a, [hl]
            or c
            ld [hl], a
            ld a, l
            add a, 4
            ld l, a
            dec b
            jr nz, .fr
            jp mdf_fra

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

; ---- far vtile (tools/ff1/gb_layout.py vupload): tile VUP of the small-font line buffer
; VBUF (8 rows, 1 bit per pixel) -> BG tile VTID[VUP] by 16 $2007 writes (plane 1 = plane
; 0). Native: the tile's bytes straight into the DMG shadow (re-coded once) or the CGB tile
; copy / VRAM. Out as the NES: A = the last byte, X = VUP * 8 + 8, Y = 0, VLO = tile,
; VHI = tile >> 4, PPU address = tile * 16 + 16, latch and vblank flag clear; N = 0, Z = 1,
; C = 1.
VT_BUF     = $AE00          ; VBUF $6E00 (cart RAM bank 0)
VT_VLO     = $AE96
VT_VUP     = $AE98
VT_VHI     = $AEA1
VT_TID     = $C350          ; VTID $0350
vtile_b:    xor a
            ldh [vbl_flag], a
            ldh [ppu_latch], a
            ld a, [VT_VUP]
            ld e, a
            add a, low(VT_TID)
            ld l, a
            ld h, high(VT_TID)
            ld a, [hl]
            ld d, a                         ; D = tile
            ld [VT_VLO], a
            swap a
            and $0F
            ld [VT_VHI], a
            ld a, e                         ; HL = VBUF + VUP * 8
            add a, a
            add a, a
            add a, a
            ld l, a
            add a, 8
            ld e, a                         ; (X out)
            ld h, high(VT_BUF)
            push de
            ldh a, [is_cgb]
            and a
            jr nz, .cgb
            ld de, RT_BUF                   ; DMG: rows to WRAM, then the shadow (RAM bank 1)
            ld c, 8
.cp:        ld a, [hl+]
            ld [de], a
            inc e
            dec c
            jr nz, .cp
            pop de
            push de
            ld a, d
            swap a
            ld l, a
            and $F0
            ld c, a                         ; (low byte of tile * 16)
            ld a, l
            and $0F
            add a, high(BG_SHADOW)
            ld h, a
            ld l, c
            ld de, RT_BUF
            ld a, 1
            ld [$4000], a
            ld c, 8
.sh:        ld a, [de]
            inc e
            ld [hl+], a
            ld [hl+], a
            dec c
            jr nz, .sh
            xor a
            ld [$4000], a
            pop de
            push de
            ld a, d
            call vt_code
            jr .out
.cgb:       pop de                          ; CGB: D = tile
            push de
            ld a, d
            swap a
            ld b, a
            and $F0
            ld c, a
            ld a, b
            and $0F
            ld b, a                         ; BC = tile * 16
            ldh a, [lcd_on]
            and a
            jr z, .vr
            ld a, b                         ; LCD on: the tile copy (WRAM bank 2 $D000 +),
            add a, $D0                      ;   sent by HDMA in the vblank
            ld d, a
            ld e, c
            ld a, 2
            ldh [$FF70], a
            ld c, 8
.cg:        ld a, [hl+]
            ld [de], a
            inc e
            ld [de], a
            inc e
            dec c
            jr nz, .cg
            ld a, 1
            ldh [$FF70], a
            pop de
            push de
            ld a, d
            push hl
            ld hl, BG_DIRTY
            call hd_mark
            pop hl
            jr .out
.vr:        ld a, d                         ; LCD off: VRAM (tiles 0-127 at $9000, 128-255 at $8800)
            cp $80
            ld a, b
            jr nc, .hi
            add a, $90
            jr .va
.hi:        add a, $80
.va:        ld d, a
            ld e, c
            ld c, 8
.vv:        ld a, [hl+]
            ld [de], a
            inc e
            ld [de], a
            inc de
            dec c
            jr nz, .vv
.out:       pop de                          ; D = tile, E = X
            ld a, d                         ; PPU address = tile * 16 + 16
            swap a
            and $0F
            ld b, a
            ld a, d
            swap a
            and $F0
            add a, 16
            ldh [ppu_vl], a
            ld a, b
            adc a, 0
            ldh [ppu_vh], a
            ld b, 0
            ld c, 0                         ; Y = 0
            ld a, [VT_VUP]                  ; A = VBUF[VUP * 8 + 7]
            add a, a
            add a, a
            add a, a
            add a, 7
            ld l, a
            ld h, high(VT_BUF)
            ld d, 0
            xor a
            ldh [nzv], a
            ld a, [hl]
            push af
            pop hl
            ld l, $90                       ; (Z, C)
            push hl
            pop af
            ret


; ---- DMG re-coding of BG tile A (dmg_shade.s retile): its shadow pixels through the
; values of TILE_PAL[tile]'s colour indices. Each output plane is a function of the two
; NES planes p0, p1 per pixel, written as W ^ (p0 & X) ^ (p1 & Y) ^ (p0 & p1 & Z) with
; masks X, Y, Z, W of $00 / $FF (from the plane's truth table over indices 0-3). Done in
; a TBLK block, then sent as one queue entry (LCD on) or copied (LCD off). TILE_USE and
; CODED as before; nothing is done if the tile already has that coding. Keeps BC, DE, HL.
RM         = $D874          ; masks X0 Y0 Z0 W0 X1 Y1 Z1 W1, row counter (not RT_BUF: the
                            ;   vblank handler's dmg_obp uses RT_BUF + 8)
retile_b:   push bc
            push de
            push hl
            ldh [sh_tile], a
            ld e, a
            ld l, a
            ld h, high(TILE_PAL)
            ld a, [hl]
            add a, a
            add a, a
            add a, low(PAL_MAP)
            ld l, a
            ld h, high(PAL_MAP)
            ld bc, 0                        ; B = indices whose value has bit 0, C = bit 1
            ld d, 1
.m:         ld a, [hl+]
            rrca
            jr nc, .n0
            push af
            ld a, b
            or d
            ld b, a
            pop af
.n0:        rrca
            jr nc, .n1
            ld a, c
            or d
            ld c, a
.n1:        sla d
            ld a, d
            cp 16
            jr nz, .m
            ld a, b
            ldh [sh_s0], a
            ld a, c
            ldh [sh_s1], a
            call tkey_bc                    ; already coded like that: nothing to do
            ld l, e
            ld h, high(CODED)
            cp [hl]
            jr nz, .go
            pop hl
            pop de
            pop bc
            ret
.go:        ldh a, [lcd_on]                 ; LCD off: coded straight into its VRAM tile ($9000
            and a                           ;   + tile * 16 for 0-127, $8000 + tile * 16
            jr nz, .bk                      ;   above); on: into a block for the queue
            ldh a, [sh_tile]
            ld c, a
            swap a
            ld b, a
            and $F0
            ld e, a
            ld a, b
            and $0F
            bit 7, c
            jr nz, .hi
            add a, $90
            jr .dd
.hi:        add a, $80
.dd:        ld d, a
            jr .cd
.bk:        call blk_alloc                  ; DE = a free block
.cd:        push de
            ldh a, [sh_tile]                ; HL = the shadow tile (RAM bank 1)
            swap a
            ld l, a
            and $F0
            ld c, a
            ld a, l
            and $0F
            add a, high(BG_SHADOW)
            ld h, a
            ld l, c
            ld a, 1
            ld [$4000], a
            push hl
            ldh a, [sh_s0]                  ; plane 0: the function whose bit i is bit 0 of
            call pf_call                    ;   index i's value; plane 1: bit 1
            pop hl
            pop de
            push de
            inc e
            push hl
            ldh a, [sh_s1]
            call pf_call
            pop hl
            ldh a, [sh_tile]                ; pixels written since its last coding (CODED
            ld e, a                         ;   $FF): the colour indices it uses (TILE_USE)
            ld d, high(CODED)
            ld a, [de]
            inc a
            call z, tile_use
            xor a
            ld [$4000], a
            ldh a, [sh_s0]                  ; the coding it has now
            ld b, a
            ldh a, [sh_s1]
            ld c, a
            ldh a, [sh_tile]
            ld e, a
            call tkey_bc
            ld l, e
            ld h, high(CODED)
            ld [hl], a
            pop de
            ldh a, [lcd_on]
            and a
            jr z, .x
            ldh a, [sh_tile]
            ld e, a
            call blk_send
.x:         pop hl
            pop de
            pop bc
            ret

; HL = a BG tile in the shadow (RAM bank 1 on), sh_tile its number: its TILE_USE nibble
; (bit i: a pixel of colour index i = 1-3)
tile_use:   ld bc, 0
            ld d, 0
            ld e, 8
.r:         ld a, [hl+]
            ldh [tmp_lo], a                 ; p0
            ld a, [hl+]
            push hl
            ld h, a                         ; H = p1, L = p0
            ldh a, [tmp_lo]
            ld l, a
            and h
            or d
            ld d, a                         ; index 3
            ld a, h
            cpl
            and l
            or b
            ld b, a                         ; index 1
            ld a, l
            cpl
            and h
            or c
            ld c, a                         ; index 2
            pop hl
            dec e
            jr nz, .r
            xor a
            inc b
            dec b
            jr z, .u2
            set 1, a
.u2:        inc c
            dec c
            jr z, .u3
            set 2, a
.u3:        inc d
            dec d
            jr z, .u4
            set 3, a
.u4:        ld c, a
            ldh a, [sh_tile]
            ld b, a
            srl a
            add a, low(TILE_USE)
            ld l, a
            ld h, high(TILE_USE)
            bit 0, b
            jr z, .lo
            ld a, c
            swap a
            ld c, a
            ld a, [hl]
            and $0F
            jr .st
.lo:        ld a, [hl]
            and $F0
.st:        or c
            ld [hl], a
            ret

; DE = the next TBLK block (with the LCD on, waits while all 8 are queued). Keeps BC, HL.
blk_alloc:  ldh a, [lcd_on]
            and a
            jr z, .bk
.wb:        ld a, [TB_H]
            ld d, a
            ld a, [TB_T]
            sub d
            cp 8
            jr c, .bk
            call q_drain1                   ; all 8 queued: write the oldest entries now
            jr .wb
.bk:        ld a, [TB_T]
            and 7
            swap a
            add a, low(TBLK)
            ld e, a
            ld d, high(TBLK)
            ret

; E = BG tile: block TB_T (from blk_alloc, filled) to its VRAM tile: one queue entry (LCD
; on: address high 0, low = address low | block, value = address high), or copied now.
blk_send:   ld a, e                         ; VRAM address: tiles 0-127 at $9000, 128-255 at $8800
            swap a
            ld c, a
            and $0F
            bit 7, e
            jr nz, .hi
            add a, $90
            jr .va
.hi:        add a, $80
.va:        ld b, a                         ; B = address high, C = tile low nibble << 4
            ld a, c
            and $F0
            ld c, a
blk_send_bc:                                ; (BC = VRAM address)
            ld a, [TB_T]
            and 7
            ld d, a                         ; D = block
            ldh a, [lcd_on]
            and a
            jr z, .dir
            ldh a, [q_tail]
            ld e, a
            inc a
            ld l, a
.f:         ldh a, [q_head]
            cp l
            jr nz, .r
            call q_drain1
            jr .f
.r:         ld h, high(QH)
            ld a, l
            ld l, e
            ld e, a
            ld [hl], 0
            inc h
            ld a, c
            or d
            ld [hl], a
            inc h
            ld [hl], b
            ld a, e
            ldh [q_tail], a
            ld hl, TB_T
            inc [hl]
            ret
.dir:       ld a, d                         ; LCD off: copy now
            swap a
            add a, low(TBLK)
            ld l, a
            ld h, high(TBLK)
            ld d, b
            ld e, c
            ld c, 16
.dc:        ld a, [hl+]
            ld [de], a
            inc e
            dec c
            jr nz, .dc
            ret

; A = set S of colour indices (bit i) whose value has the plane's bit -> masks X Y Z W at
; [HL+]: X = t0 ^ t1, Y = t0 ^ t2, Z = t0 ^ t1 ^ t2 ^ t3, W = t0 (t_i = bit i of S), as
; $00 / $FF. Keeps BC, DE.
rt_anf:     push de
            ld d, a
            srl a
            xor d
            ld e, a                         ; bit 0: t0 ^ t1, bit 2: t2 ^ t3
            and 1
            cpl
            inc a
            ld [hl+], a                     ; X
            ld a, d
            srl a
            srl a
            xor d
            and 1
            cpl
            inc a
            ld [hl+], a                     ; Y
            ld a, e
            srl a
            srl a
            xor e
            and 1
            cpl
            inc a
            ld [hl+], a                     ; Z
            ld a, d
            and 1
            cpl
            inc a
            ld [hl+], a                     ; W
            pop de
            ret

; ---- fix:F2CF (battle setup, gb_layout): LDY #8 / LDX #0 / STA $2007 / DEX / BNE / DEY /
; BNE: A to 2048 PPU bytes (both nametables from $2000). With the LCD off, from $2000
; with increment 1: the nametables' tiles, the GB map rows 0-29 and their owner (nametable
; 1 drew every cell last) at once, the 128 attribute bytes through rt_ppu_w7; otherwise
; 2048 rt_ppu_w7 calls. Out: X = Y = 0, A kept; N = 0, Z = 1, carry kept.
ntclr_b:    push af
            ld d, a
            ldh a, [lcd_on]                 ; (LCD off, or a CGB masked load)
            and a
            jr z, .bk
            ld a, [VLCD]
            and a
            jr z, .gen
.bk:        ldh a, [ppu_ctrl]
            and 4
            jr nz, .gen
            ldh a, [ppu_vh]
            cp $20
            jr nz, .gen
            ldh a, [ppu_vl]
            and a
            jr nz, .gen
            ld hl, NT_SH                    ; nametable 0 tiles
            call .fill
            ld hl, NT_SH + $400             ; nametable 1 tiles
            call .fill
            ld a, [VLCD]                    ; (masked: the GB map rebuilt when shown)
            and a
            jr z, .gm
            ld a, 1
            ld [MAP_RB], a
            jr .gd
.gm:        ld hl, $9800                    ; GB map rows 0-29
            call .fill
.gd:        ld hl, OWN                      ; every cell drawn by nametable 1 last
            ld a, $FF
            ld c, 120
.ow:        ld [hl+], a
            dec c
            jr nz, .ow
            ld a, low(960)
            ldh [own1_lo], a
            ld a, high(960)
            ldh [own1_hi], a
            ldh a, [is_cgb]
            and a
            jr nz, .cg
            ld a, 1
            ldh [dmg_scan], a
            jr .at
.cg:        ld a, d                         ; CGB: attribute shadows unlike D, so the attribute
            cpl                             ;   bytes below colour every cell again
            ld hl, NT_SH + $3C0
            ld c, 64
.c1:        ld [hl+], a
            dec c
            jr nz, .c1
            ld hl, NT_SH + $7C0
            ld c, 64
.c2:        ld [hl+], a
            dec c
            jr nz, .c2
.at:        ld a, $23                       ; attribute bytes
            call .attr
            ld a, $27
            call .attr
            jr .out
.gen:       ld e, 0                         ; 8 x 256 writes
            ld c, 8
.g:         ld a, d
            call rt_ppu_w7
            dec e
            jr nz, .g
            dec c
            jr nz, .g
.out:       xor a
            ldh [nzv], a
            pop hl                          ; A kept, Z set, carry kept
            ld a, l
            and $10
            or $80
            ld l, a
            push hl
            pop af
            ld bc, 0
            ld de, 0
            ret
.fill:      ld c, $3C                       ; HL: $3C0 bytes of D
.f:         ld a, d
            ld b, 16
.f1:        ld [hl+], a
            dec b
            jr nz, .f1
            dec c
            jr nz, .f
            ret
.attr:      ldh [ppu_vh], a                 ; A = $23 / $27: its 64 attribute bytes
            ld a, $C0
            ldh [ppu_vl], a
            ld c, 64
.a:         ld a, d
            call rt_ppu_w7
            dec c
            jr nz, .a
            ret

; ---- fix:F4EA (battle panel row): LDY #0 / LDA ($88),Y / STA $2007 / INY / CPY #$19 /
; BNE: 25 bytes from ($88) to the PPU. Nametable cells through nt_tile (palette checked at
; once, as rt_ppu_w7 does), anything else through rt_ppu_w7. Out: Y = $19, A = the last
; byte, X kept; N = 0, Z = 1, C = 1.
NR_SRC     = $D87E          ; ntrun_b: source address (lo, hi)
NR_END     = $DCCF          ;   fast path: source low byte after the last cell
ntrun_b:    push de
            call nrf_ok                     ; nametable 0, none of its cells owned by
            jp z, nrf                       ;   nametable 1, LCD on: the run path
            ld a, 1
            ld [NT_NOW], a
            ld a, [NES_RAM + $88]
            ld [NR_SRC], a
            ld a, [NES_RAM + $89]
            ld [NR_SRC + 1], a
            ld c, $19
.lp:        push bc
            ld a, [NR_SRC]                  ; D = next byte (NES $6000-$7FFF: cart RAM
            ld l, a                         ;   directly)
            ld a, [NR_SRC + 1]
            ld h, a
            sub $60
            cp $20
            jr nc, .rd
            add a, $A0
            ld h, a
            ld d, [hl]
            ld a, h
            sub $40
            ld h, a
            jr .rdd
.rd:        push hl
            call nes_rd
            ld d, l
            pop hl
.rdd:       inc hl
            ld a, l
            ld [NR_SRC], a
            ld a, h
            ld [NR_SRC + 1], a
            ldh a, [ppu_vh]                 ; nametable ($2000-$3EFF): native cell write
            cp $20
            jr c, .gen
            cp $3F
            jr z, .gen
            ld h, a
            ldh a, [ppu_vl]
            ld l, a
            ld a, h                         ; (attribute bytes: rt_ppu_w7)
            and 3
            cp 3
            jr nz, .same
            ld a, l
            cp $C0
            jr nc, .gen
.same:      ldh a, [dlg_on]                 ; unchanged cell (shadow has the tile, the
            and a                           ;   writing nametable owns it): only the
            jr nz, .cell                    ;   address moves (FF1 rewrites whole panels)
            ldh a, [ppu_ctrl]
            and 4
            jr nz, .cell
            ld a, h
            and 7
            add a, high(NT_SH)
            push hl
            ld h, a
            ld a, [hl]
            pop hl
            cp d
            jr nz, .cell
            ld a, h                         ; owner bit: OWN[(vh & 3) * 32 + vl / 8], bit vl & 7
            and 3
            swap a
            add a, a
            ld b, a
            ld a, l
            rrca
            rrca
            rrca
            and $1F
            or b
            ld c, a
            ld b, high(OWN)
            ld a, [bc]
            ld b, a                         ; B = the OWN byte
            push hl
            ld a, l
            and 7
            add a, low(NBIT)
            ld l, a
            ld h, high(NBIT)
            ld a, [hl]
            pop hl
            and b                           ; NZ: nametable 1 owns it
            jr z, .o0
            ld a, h
            and 4
            jr nz, .skip
            jr .cell
.o0:        ld a, h
            and 4
            jr nz, .cell
.skip:      ld a, l                         ; PPU address + 1
            add a, 1
            ldh [ppu_vl], a
            ld a, h
            adc a, 0
            and $3F
            ldh [ppu_vh], a
            jr .nx
.cell:      push de
            call nt_tile
            pop de
            call ppu_inc
            jr .nx
.gen:       ld a, d
            call rt_ppu_w7
.nx:        pop bc
            dec c
            jr nz, .lp
            xor a
            ld [NT_NOW], a
            ldh [nzv], a
            ld a, d
            pop de
            ld bc, $19
            push af
            pop hl
            ld l, $90                       ; (Z, C)
            push hl
            pop af
            ret

; Z: the panel row can take the fast path: LCD on (CGB: not masked), no dialogue box, PPU
; +1, none of its 25 GB map cells owned by nametable 1, PPU address in nametable 0's cells with the 25
; cells before the attributes, the source in NES $6000-$7FFF. Then BC = source (cart RAM),
; HL = shadow, DE = GB map, NR_END set.
NR_O1      = $DCD8          ; nrf_ok -> nrf: cells of the run owned by nametable 1 (DMG)
nrf_ok:     xor a
            ld [NR_O1], a
            ld a, MDF_ON
            and a
            jr z, .no
            ldh a, [lcd_on]
            and a
            jr z, .no
            ldh a, [dlg_on]
            ld b, a
            ld a, [VLCD]
            or b
            jr nz, .no
            ldh a, [ppu_ctrl]
            and 4
            jr nz, .no
            ldh a, [ppu_vh]
            cp $20
            jr c, .no
            cp $3F
            jr nc, .no
            and 7
            cp 3
            jr z, .a3
            jr nc, .no                      ; (nametable 1)
            jr .ok
.a3:        ldh a, [ppu_vl]                 ; row 24-29 area: the run ends before $3C0
            cp $C0 - $19 + 1
            jr nc, .no
.ok:        ldh a, [ppu_vh]                 ; none of the run's cells owned by nametable 1:
            and 3                           ;   its 25 OWN bits (from bit k = vl & 7 of byte
            swap a                          ;   vl / 8: bits k-7, two bytes, bits 0-k) are 0
            add a, a
            ld b, a
            ldh a, [ppu_vl]
            rrca
            rrca
            rrca
            and $1F
            or b
            ld l, a
            ld h, high(OWN)
            ldh a, [ppu_vl]
            and 7
            inc a
            ld c, a
            ld a, $FF
            jr .s1
.s0:        add a, a
.s1:        dec c
            jr nz, .s0
            ld b, a                         ; B = $FF << k
            and [hl]
            ld e, a
            inc l
            ld a, [hl+]
            or e
            or [hl]
            inc l
            ld e, a
            ld a, b
            add a, a
            cpl                             ; bits 0-k
            and [hl]
            or e
            jr z, .src
            ldh a, [is_cgb]                 ; (DMG: those cells change owner in nrf)
            and a
            jr nz, .no
            inc a
            ld [NR_O1], a
.src:       ld a, [NES_RAM + $89]
            sub $60
            cp $1F
            jr nc, .no                      ; ($6000-$7EFF: no carry past $7FFF)
            add a, $A0
            ld b, a
            ld a, [NES_RAM + $88]
            ld c, a
            add a, $19
            ld [NR_END], a
            ldh a, [ppu_vh]
            and 3
            ld d, a
            add a, high(NT_SH)
            ld h, a
            ld a, d
            add a, $98
            ld d, a
            ldh a, [ppu_vl]
            ld l, a
            ld e, a
            xor a                           ; (Z)
            ret
.no:        or 1
            ret

; the fast panel row: the VRAM queue emptied first (no queued cell written after these);
; unchanged cells (shadow has the tile; nametable 0 owns the run's cells) only move on; a
; changed cell: shadow, DMG palette check at once (cell_fast), GB map at the next free
; VRAM moment
nrf:        push bc
            push de
.dr:        ldh a, [q_head]
            ld b, a
            ldh a, [q_tail]
            cp b
            jr z, .de
            call q_drain1
            jr .dr
.de:        pop de
            pop bc
            ld a, [NR_O1]                   ; cells owned by nametable 1: owner bit
            and a                           ;   cleared, the shadow byte made to differ
            jr z, .f                        ;   from the new tile (so the loop below
            push bc                         ;   writes and checks the cell)
            push de
            push hl
            ld e, 25
.pp:        push bc
            push hl
            ld a, h
            sub high(NT_SH)
            swap a
            add a, a
            ld d, a
            ld a, l
            rrca
            rrca
            rrca
            and $1F
            or d
            ld c, a                         ; C = OWN byte
            ld a, l
            and 7
            ld l, a
            ld h, high(NBIT)
            ld d, [hl]                      ; D = bit
            ld h, high(OWN)
            ld l, c
            ld a, [hl]
            and d
            jr z, .pn
            ld a, d
            cpl
            and [hl]
            ld [hl], a
            ldh a, [own1_lo]
            sub 1
            ldh [own1_lo], a
            ldh a, [own1_hi]
            sbc a, 0
            ldh [own1_hi], a
            pop hl
            pop bc
            ld a, [bc]
            cpl
            ld [hl], a
            jr .pc
.pn:        pop hl
            pop bc
.pc:        inc hl
            inc bc
            dec e
            jr nz, .pp
            pop hl
            pop de
            pop bc
.f:         ld a, [bc]
            inc bc
            cp [hl]
            jr nz, .c
.n:         inc hl
            inc de
            ld a, [NR_END]
            cp c
            jr nz, .f
            dec bc                          ; out: PPU address + $19, A = the last byte,
            ld a, [bc]                      ;   Y = $19, X kept; N = 0, Z = 1, C = 1
            ld d, a
            ldh a, [ppu_vl]
            add a, $19
            ldh [ppu_vl], a
            ldh a, [ppu_vh]
            adc a, 0
            and $3F
            ldh [ppu_vh], a
            xor a
            ldh [nzv], a
            ld a, d
            pop de
            ld bc, $19
            push af
            pop hl
            ld l, $90
            push hl
            pop af
            ret
.c:         ld [hl], a                      ; changed cell
            push bc
            push de
            ld d, a
            ldh a, [is_cgb]
            and a
            jr nz, .cg
            ld a, h
            sub high(NT_SH)
            ld b, a                         ; B = offset high, C = nametable 0, L = low
            ld c, 0
            call cell_fast
.cg:        ld a, d
            pop de
            ld c, a                         ; (C = the tile: the poll uses A)
.w:         di
            ldh a, [$FF41]
            bit 1, a
            jr z, .wr
            ei
            jr .w
.wr:        ld a, c
            ld [de], a
            ei
            pop bc
            jr .n

; DMG, vtile_b: tile A was written with plane 1 = plane 0 (rows in RT_BUF): only colour
; indices 0 and 3. Coded at once for its palette (value of index 3 where a pixel is set,
; of index 0 elsewhere) into a block for VRAM; TILE_USE, CODED as retile_b leaves them.
vt_code:    push bc
            push de
            push hl
            ldh [sh_tile], a
            ld e, a
            ld l, a                         ; PAL_MAP row of its palette: v0, v3
            ld h, high(TILE_PAL)
            ld a, [hl]
            add a, a
            add a, a
            add a, low(PAL_MAP)
            ld l, a
            ld h, high(PAL_MAP)
            ld a, [hl+]
            ld b, a                         ; B = v0
            inc l
            inc l
            ld c, [hl]                      ; C = v3
            ld a, b                         ; plane p = (pixels & K) ^ Y: Y = v0 bit p
            and 1                           ;   spread, K = Y ^ (v3 bit p spread)
            jr z, .y0
            ld a, $FF
.y0:        ld [RM + 1], a                  ; Y0
            ld d, a
            ld a, c
            and 1
            jr z, .x0
            ld a, $FF
.x0:        xor d
            ld [RM], a                      ; K0
            ld a, b
            and 2
            jr z, .y1
            ld a, $FF
.y1:        ld [RM + 3], a                  ; Y1
            ld d, a
            ld a, c
            and 2
            jr z, .x1
            ld a, $FF
.x1:        xor d
            ld [RM + 2], a                  ; K1
            push de
            call blk_alloc                  ; DE = block
            ld hl, RT_BUF
            ld a, [RM]
            ld b, a
            ld a, [RM + 1]
            ld c, a
            push de
            ld a, [hl+]
            and b
            xor c
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            and b
            xor c
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            and b
            xor c
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            and b
            xor c
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            and b
            xor c
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            and b
            xor c
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            and b
            xor c
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            and b
            xor c
            ld [de], a
            inc e
            inc e
            pop de
            inc e
            ld l, low(RT_BUF)
            ld a, [RM + 2]
            ld b, a
            ld a, [RM + 3]
            ld c, a
            ld a, [hl+]
            and b
            xor c
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            and b
            xor c
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            and b
            xor c
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            and b
            xor c
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            and b
            xor c
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            and b
            xor c
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            and b
            xor c
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            and b
            xor c
            ld [de], a
            inc e
            inc e
            ld l, low(RT_BUF)               ; (any pixel set)
            xor a
            or [hl]
            inc l
            or [hl]
            inc l
            or [hl]
            inc l
            or [hl]
            inc l
            or [hl]
            inc l
            or [hl]
            inc l
            or [hl]
            inc l
            or [hl]
            ld [RM], a
            dec e                           ; (DE: block, as before for the code below)
            ld a, e
            and $F0
            ld e, a
            ld h, d
            ld l, e
            pop de                          ; E = tile
            ld a, e                         ; TILE_USE nibble: index 3 if a pixel is set
            srl a
            add a, low(TILE_USE)
            ld l, a
            ld h, high(TILE_USE)
            ld a, [RM]
            and a
            ld a, 0
            jr z, .nu
            ld a, 8
.nu:        bit 0, e
            jr z, .ulo
            swap a
            ld d, a
            ld a, [hl]
            and $0F
            jr .ust
.ulo:       ld d, a
            ld a, [hl]
            and $F0
.ust:       or d
            ld [hl], a
            ld a, e                         ; CODED: its key for this palette
            push de
            ld l, a
            ld h, high(TILE_PAL)
            ld a, [hl]
            add a, a
            add a, a
            add a, low(PAL_MAP)
            ld l, a
            ld h, high(PAL_MAP)
            ld bc, 0
            ld d, 1
.m:         ld a, [hl+]
            rrca
            jr nc, .n0
            push af
            ld a, b
            or d
            ld b, a
            pop af
.n0:        rrca
            jr nc, .n1
            ld a, c
            or d
            ld c, a
.n1:        sla d
            ld a, d
            cp 16
            jr nz, .m
            pop de
            call tkey_bc
            ld l, e
            ld h, high(CODED)
            ld [hl], a
            call blk_send
            pop hl
            pop de
            pop bc
            ret

; HL = a TBLK block with a tile in GB byte order: each row through the masks at RM (rt_anf)
; in place; sh_u1..3 = pixels of colour index 1..3 (any row). Keeps nothing.
anf_rows:   ld a, 8
            ld [RM + 8], a
            xor a
            ldh [sh_u1], a
            ldh [sh_u2], a
            ldh [sh_u3], a
.row:       ld b, [hl]                      ; p0
            inc l
            ld c, [hl]                      ; p1
            ld a, b
            and c
            ld d, a                         ; p0 & p1 (index 3)
            xor b                           ; index 1
            ld e, a
            ldh a, [sh_u1]
            or e
            ldh [sh_u1], a
            ld a, d                         ; index 2
            xor c
            ld e, a
            ldh a, [sh_u2]
            or e
            ldh [sh_u2], a
            ldh a, [sh_u3]
            or d
            ldh [sh_u3], a
            ld a, [RM + 4]                  ; plane 1
            and b
            ld e, a
            ld a, [RM + 5]
            and c
            xor e
            ld e, a
            ld a, [RM + 6]
            and d
            xor e
            ld e, a
            ld a, [RM + 7]
            xor e
            ld [hl-], a
            ld a, [RM]                      ; plane 0
            and b
            ld e, a
            ld a, [RM + 1]
            and c
            xor e
            ld e, a
            ld a, [RM + 2]
            and d
            xor e
            ld e, a
            ld a, [RM + 3]
            xor e
            ld [hl+], a
            inc l
            ld a, [RM + 8]
            dec a
            ld [RM + 8], a
            jr nz, .row
            ret

; DMG spr_load: C = GB sprite slot: NES sprite tile o_t from the shadow, coded with o_key
; (values of colour indices 1-3, 2 bits each; index 0 stays 0), as one block to VRAM
; $8000 + slot * 16; SLOT_KEY[slot] = o_key. Keeps all registers.
sprload_b:  push af
            push bc
            push de
            push hl
            ld a, c
            add a, low(SLOT_KEY)
            ld l, a
            ld h, high(SLOT_KEY)
            ldh a, [o_key]
            ld [hl], a
            ld b, a                         ; D = indices whose value has bit 0, E = bit 1
            ld de, 0
            bit 0, b
            jr z, .k1
            set 1, d
.k1:        bit 1, b
            jr z, .k2
            set 1, e
.k2:        bit 2, b
            jr z, .k3
            set 2, d
.k3:        bit 3, b
            jr z, .k4
            set 2, e
.k4:        bit 4, b
            jr z, .k5
            set 3, d
.k5:        bit 5, b
            jr z, .k6
            set 3, e
.k6:        ld hl, RM
            ld a, d
            call rt_anf
            ld a, e
            call rt_anf
            push bc
            call blk_alloc                  ; DE = block
            ldh a, [o_t]                    ; HL = shadow $A000 + tile * 16 (RAM bank 1)
            swap a
            ld b, a
            and $F0
            ld l, a
            ld a, b
            and $0F
            add a, high(SPR_SHADOW)
            ld h, a
            ld a, 1
            ld [$4000], a
            ld c, 16
.cp:        ld a, [hl+]
            ld [de], a
            inc e
            dec c
            jr nz, .cp
            xor a
            ld [$4000], a
            ld a, e
            sub 16
            ld l, a
            ld h, d
            call anf_rows
            pop bc
            ld a, c                         ; BC = $8000 + slot * 16
            swap a
            ld b, a
            and $F0
            ld c, a
            ld a, b
            and $0F
            add a, $80
            ld b, a
            call blk_send_bc
            pop hl
            pop de
            pop bc
            pop af
            ret

; ---- DMG: LCD going on after drawing with it off (dmg_scan_all): every GB map cell (rows
; 0-29) gives its tile the palette it is drawn with (from the nametable that owns the
; cell; marked for re-coding if that changed, a parked tile marked again), REF_BM = tiles
; the map uses; then the cells in the GB view again (they win for a tile drawn with two
; palettes) and PAL_USED = the palettes of the view. Row constants once per row; a cell
; with the tile and palette of the cell before it is skipped.
SC_TH      = $D835          ; scan_run: tile row: page (row / 8), offset ((row & 7) * 32),
SC_TL      = $D836
SC_AL      = $D837          ;   attribute row offset ($C0 + (row / 4) * 8), row & 2,
SC_RF      = $D838
SC_OL      = $D839          ;   OWN row offset (row * 4), nametable 1 owns cells,
SC_O1      = $D83A
SC_PU      = $D83B          ;   PAL_USED wanted, cells left, tile / palette of the cell before
SC_N       = $D83C
SC_LT      = $D83D
SC_LP      = $D82E          ;   (in the fault-dump area DBG + 14: written only on a fault)

; ---- D = value, BC = count: count $2007 writes of D (rt_ppu_w7 semantics). In bulk while
; the LCD is off, the increment is 1 and the address is in nametable 0's cells with no cell
; owned by nametable 1: shadow and GB map filled at once (DMG: the map is scanned when the
; LCD goes on). Anything else byte by byte through rt_ppu_w7. Keeps D.
NF_N       = $D82C          ; ntfill: bytes of this run (2; fault-dump area, DBG + 12)
ntfill:     ld a, b
            or c
            ret z
            ldh a, [lcd_on]                 ; (LCD off, or a CGB masked load)
            and a
            jr z, .bk
            ld a, [VLCD]
            and a
            jr z, .one
.bk:        ldh a, [ppu_ctrl]
            and 4
            jr nz, .one
            ld a, b                         ; a whole nametable from offset 0: in bulk
            cp 4
            jr c, .nw
            ldh a, [ppu_vl]
            and a
            jr nz, .nw
            ldh a, [ppu_vh]
            and $F3
            cp $20
            jr nz, .nw
            call nf_whole
            jr ntfill
.nw:        ldh a, [own1_lo]                ; (cells owned by nametable 1: on a CGB their
            ld h, a                         ;   attributes would change too: byte by byte)
            ldh a, [own1_hi]
            or h
            jr z, .o0
            ldh a, [is_cgb]
            and a
            jr nz, .one
.o0:        ldh a, [ppu_vh]
            cp $20
            jr c, .one
            cp $3F
            jr z, .one
            and 7
            cp 4
            jr nc, .one                     ; (nametable 1)
            ld h, a
            ldh a, [ppu_vl]
            ld l, a                         ; HL = offset 0-$3FF
            push de
            ld a, $C0                       ; DE = room = $3C0 - offset
            sub l
            ld e, a
            ld a, 3
            sbc a, h
            ld d, a
            jr c, .attr                     ; (offset >= $3C0: attributes)
            or e
            jr z, .attr
            ld a, b                         ; n = min(count, room)
            cp d
            jr c, .cnt
            jr nz, .rm
            ld a, c
            cp e
            jr c, .cnt
.rm:        jr .n
.cnt:       ld d, b
            ld e, c
.n:         ld a, e
            ld [NF_N], a
            ld a, d
            ld [NF_N + 1], a
            ld a, c                         ; count -= n
            sub e
            ld c, a
            ld a, b
            sbc a, d
            ld b, a
            pop de                          ; D = value
            push bc
            push hl
            ld a, h
            add a, high(NT_SH)
            ld h, a
            call .set                       ; shadow
            pop hl
            push hl
            ld a, h
            add a, $98
            ld h, a
            call .setm                      ; GB map (LCD off; masked: rebuilt when shown)
            pop hl
            ldh a, [own1_lo]                ; nametable 0 owns these cells now
            ld b, a
            ldh a, [own1_hi]
            or b
            call nz, nf_own
            ld a, [NF_N]                    ; v += n
            add a, l
            ldh [ppu_vl], a
            ld a, [NF_N + 1]
            adc a, h
            ld h, a
            ldh a, [ppu_vh]                 ; (mirror bits kept)
            and $F8
            or h
            ldh [ppu_vh], a
            ldh a, [is_cgb]
            and a
            jr nz, .cg
            ld a, 1
            ldh [dmg_scan], a
.cg:        pop bc
            jr ntfill
.attr:      pop de
.one:       ld a, d
            call rt_ppu_w7
            dec bc
            jr ntfill
.setm:      ld a, [VLCD]
            and a
            jr z, .set
            ld a, 1
            ld [MAP_RB], a
            ret
.set:       ld a, [NF_N]                    ; HL: NF_N bytes of D
            ld c, a
            ld a, [NF_N + 1]
            ld b, a
            inc b
            ld a, c
            and a
            jr nz, .s
            dec b
            jr z, .x
.s:         ld a, d
.sl:        ld [hl+], a
            dec c
            jr nz, .sl
            dec b
            jr nz, .sl
.x:         ret

; ntfill with the LCD off, increment 1, at offset 0 of a nametable and >= $400 bytes: its
; 960 cells in bulk (shadow, GB map, every GB map cell now owned by this nametable: the last
; writer, as byte by byte); its attribute shadow is invalidated so the 64 attribute bytes
; that follow in the same fill colour every cell again (CGB palettes; DMG: the map is
; scanned when the LCD goes on). D = value; BC -= $3C0; the address moves to the attributes.
nf_whole:   ld a, c
            sub $C0
            ld c, a
            ld a, b
            sbc a, 3
            ld b, a
            push bc
            ldh a, [ppu_vh]
            and 4
            ld e, a                         ; E = 4: nametable 1
            add a, high(NT_SH)
            ld h, a
            ld l, 0
            call .fill                      ; shadow
            ld a, d                         ; (attribute shadow: every byte differs from D)
            cpl
            ld b, 64
.at:        ld [hl+], a
            dec b
            jr nz, .at
            ld a, [VLCD]                    ; GB map (LCD off; masked: rebuilt when shown)
            and a
            jr z, .gm
            ld a, 1
            ld [MAP_RB], a
            jr .gd
.gm:        ld hl, $9800
            call .fill
.gd:        ld a, e                         ; owners: all nametable 0 / all nametable 1
            and a
            jr z, .o
            ld a, $FF
.o:         ld hl, OWN
            ld b, 120
.ol:        ld [hl+], a
            dec b
            jr nz, .ol
            ld a, e
            and a
            jr z, .c0
            ld a, $C0
            ldh [own1_lo], a
            ld a, 3
            ldh [own1_hi], a
            jr .c1
.c0:        xor a
            ldh [own1_lo], a
            ldh [own1_hi], a
.c1:        ld a, $C0                       ; v = attributes of this nametable
            ldh [ppu_vl], a
            ldh a, [ppu_vh]
            or 3
            ldh [ppu_vh], a
            ldh a, [is_cgb]
            and a
            jr nz, .x
            ld a, 1
            ldh [dmg_scan], a
.x:         pop bc
            ret
.fill:      ld bc, $04C0                    ; HL: 960 bytes of D (HL ends at +$3C0)
.f:         ld a, d
            ld [hl+], a
            dec c
            jr nz, .f
            dec b
            jr nz, .f
            ret

; CGB masked load shown: the GB map (rows 0-29) from the nametable shadows by owner (OWN),
; four cells per moment VRAM is free (mr_flush4). After bulk fills that skipped the map.
MR_OUT     = $DCD0          ; maprb_b / repal_b: four values for VRAM (4), owner bits
MR_BITS    = $DCD4
maprb_b:    ldh a, [q_head]                 ; queued writes first (a queued map cell must
            ld b, a                         ;   not land after the rebuild)
            ldh a, [q_tail]
            cp b
            jr z, .qe
            call q_drain1
            jr maprb_b
.qe:        xor a
            ld [MAP_RB], a
            ld hl, $9800
            ld de, OWN
.byte:      ld a, [de]
            inc de
            push de
            ld c, a                         ; C = owner bits (bit 0 first)
            call .four
            call .four
            pop de
            ld a, l
            cp $C0
            jr nz, .byte
            ld a, h
            cp $9B
            jr nz, .byte
            ret
.four:      push hl
            ld a, h                         ; shadow = NT_SH (+ $400: nametable 1) + offset
            add a, high(NT_SH) - $98
            ld h, a
            ld de, MR_OUT
            ld b, 4
.f:         srl c
            ld a, h
            jr nc, .f0
            add a, 4
.f0:        push hl
            ld h, a
            ld a, [hl]
            ld [de], a
            inc de
            pop hl
            inc l
            dec b
            jr nz, .f
            pop hl
            push bc
            ld c, 0
            call mr_flush4
            pop bc
            ret

; CGB: MR_OUT[0..3] to VRAM bank C at HL (HL += 4) at the next moment VRAM is free (STAT
; mode 0 / 1; double speed: mode 2 after it leaves 40 M-cycles); the bank chosen with
; interrupts off (the handlers leave bank 0 selected)
mr_flush4:
.w:         di
            ldh a, [$FF41]
            bit 1, a
            jr z, .go
            ei
            jr .w
.go:        ld a, c
            ldh [$FF4F], a
            ld a, [MR_OUT]
            ld [hl+], a
            ld a, [MR_OUT + 1]
            ld [hl+], a
            ld a, [MR_OUT + 2]
            ld [hl+], a
            ld a, [MR_OUT + 3]
            ld [hl+], a
            xor a
            ldh [$FF4F], a
            ei
            ret

; CGB: every GB map cell's palette (VRAM bank 1, rows 0-29) from the attribute shadow of the
; nametable that drew it (OWN), four cells (one attribute byte) per write. Run when the
; LCD goes on after owners changed with it off (own_set leaves those cells to this).
repal_b:    xor a
            ld [CGB_RP], a
            ld hl, $9800
            ld b, 0                         ; B = row
.row:       ld c, 0                         ; C = column
.grp:       push hl
            ld a, b                         ; owner bits of columns C..C+3
            add a, a
            add a, a
            ld l, a
            ld a, c
            rrca
            rrca
            rrca
            and 3
            or l
            ld l, a
            ld h, high(OWN)
            ld a, [hl]
            bit 2, c
            jr z, .lo
            swap a
.lo:        ld [MR_BITS], a
            ld a, b                         ; attribute byte $C0 + (row / 4) * 8 + col / 4
            and $1C                         ;   of both nametables, this row's half
            add a, a
            add a, $C0
            ld l, a
            ld a, c
            srl a
            srl a
            add a, l
            ld l, a
            ld h, high(NT_SH) + 3
            ld a, [hl]
            bit 1, b
            jr z, .a0
            swap a
.a0:        ld d, a
            ld h, high(NT_SH) + 7
            ld a, [hl]
            bit 1, b
            jr z, .a1
            swap a
.a1:        ld e, a
            ld hl, MR_OUT
            push bc
            ld a, [MR_BITS]
            ld c, a
            srl c                           ; columns 0-1: the left quadrant, 2-3: the right
            ld a, d
            jr nc, .c0
            ld a, e
.c0:        and 3
            ld [hl+], a
            srl c
            ld a, d
            jr nc, .c1
            ld a, e
.c1:        and 3
            ld [hl+], a
            srl c
            ld a, d
            jr nc, .c2
            ld a, e
.c2:        rrca
            rrca
            and 3
            ld [hl+], a
            srl c
            ld a, d
            jr nc, .c3
            ld a, e
.c3:        rrca
            rrca
            and 3
            ld [hl], a
            pop bc
            pop hl
            push bc
            ld c, 1
            call mr_flush4
            pop bc
            ld a, c
            add a, 4
            ld c, a
            cp 32
            jr nz, .grp
            inc b
            ld a, b
            cp 30
            jr nz, .row
            ret

; ntfill, DMG: HL = first cell offset, NF_N cells: their OWN bits cleared (own1 counts
; down). Keeps HL, D.
nf_own:     push hl
            push de
            ld a, [NF_N]
            ld c, a
            ld a, [NF_N + 1]
            ld b, a
            ld a, l
            and 7
            ld e, a
            push hl
            ld h, high(NBIT)
            ld l, e
            ld e, [hl]                      ; E = bit of the first cell
            pop hl
            ld a, l                         ; HL = OWN + offset / 8
            srl h
            rra
            srl h
            rra
            srl h
            rra
            ld l, a
            ld h, high(OWN)
.lp:        ld a, e                         ; a whole empty byte: 8 cells at once
            cp 1
            jr nz, .bit
            ld a, [hl]
            and a
            jr nz, .bit
            ld a, b
            and a
            jr nz, .skip
            ld a, c
            cp 8
            jr c, .bit
.skip:      inc l
            ld a, c
            sub 8
            ld c, a
            jr nc, .nx
            dec b
            jr .nx
.bit:       ld a, [hl]
            and e
            jr z, .nb
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
.nb:        rlc e
            jr nc, .sm
            inc l
.sm:        dec bc
.nx:        ld a, b
            or c
            jr nz, .lp
            pop de
            pop hl
            ret

; b14:9C0F (menu screen clear): 960 zeros and 64 $FF from the current PPU address.
; Out: X = 0, Y = 0, A = $FF; N = 0, Z = 1, C = 1.
mclr_b:     ld d, 0
            ld bc, 960
            call ntfill
            ld d, $FF
            ld bc, 64
            call ntfill
            xor a
            ldh [nzv], a
            ld a, $FF
            ld bc, 0
            ld de, 0
            scf                             ; (Z from the xor)
            ret

; fix:E14D / E17F (window rows): X times STA $2007 of A. Out: X = 0; N = 0, Z = 1, carry,
; A and Y kept.
wrow_b:     push bc
            push af
            ld d, a
            ld b, 0
            ld c, e
            ld a, c
            and a
            jr nz, .n
            inc b                           ; (X = 0: 256)
.n:         call ntfill
            xor a
            ldh [nzv], a
            pop hl
            ld a, l
            and $10
            or $80
            ld l, a
            push hl
            pop af
            ld de, 0
            pop bc                          ; (Y kept)
            ret

; scan_b's full pass: row D, columns 0-31 (as scan_run, but the palette fetched once per
; column pair or owner change, the owner bit from a rotating byte). Keeps D.
SC_OB      = $D82A          ; owner bits of the next 8 cells, this cell's owner, the owner
SC_CO      = $D82B          ;   the palette was fetched for (fault-dump area DBG + 8..11:
SC_LO      = $D829          ;   written only on a fault)

; ---- c62:D865 (every frame: the 32 palette bytes to $3F00): LDA $0D / BEQ / 16 x $03E0,X /
; then $03C0,X up to X = $20. A colour equal to the shadow's changes nothing: only changed
; ones go through rt_ppu_w7. Out: X = $20, A = the last byte; N = 0, Z = 1, C = 1.
palup_b:    ld a, [NES_RAM + $0D]
            and a
            ld hl, NES_RAM + $03C0
            jr z, .s
            ld hl, NES_RAM + $03E0
.s:         ld c, 0                         ; C = index 0-31
            jp palup2_b.lp
palup2_b:   ld c, e                         ; c62:D874: from X on, $03C0 + X
            ld a, e
            add a, low(NES_RAM + $03C0)
            ld l, a
            ld h, high(NES_RAM + $03C0)
            ld a, c
            cp 32
            jr nc, .x
.lp:        ld a, c
            cp 16
            jr nz, .n
            ld hl, NES_RAM + $03D0
.n:         ld a, [hl+]
            ld d, a
            push hl
            ldh a, [ppu_vh]                 ; (the game set $3F00; follow the PPU address)
            cp $3F
            jr nz, .w
            ldh a, [ppu_vl]                 ; PAL_SH index: $10/$14/$18/$1C -> $00/$04/...
            and $1F
            ld l, a
            and $13
            cp $10
            ld a, l
            jr nz, .m
            and $0F
.m:         ld l, a
            ld h, high(PAL_SH)
            ld a, d
            and $3F
            cp [hl]
            jr nz, .w
            call ppu_inc                    ; unchanged: only the address moves
            jr .nx
.w:         ld a, d
            call rt_ppu_w7
.nx:        pop hl
            inc c
            ld a, c
            cp 32
            jr c, .lp
.x:         xor a
            ldh [nzv], a
            ld e, c
            ld d, 0
            ld b, 0
            ld a, [NES_RAM + $03DF]
            push af
            pop hl
            ld l, $90
            push hl
            pop af
            ret

; ---- suspend points ($5802, rt_mmc_r5802 / rt_mmc_w5802 in runtime.s)
susp_r:
            push af
            ld a, 3
            ld [$4000], a
            ld hl, SUSP_MAGIC
            ld a, [hl+]
            cp 'S'
            jr nz, .no
            ld a, [hl+]
            cp 'U'
            jr nz, .no
            ld a, [hl+]
            cp 'S'
            jr nz, .no
            ld a, [hl]
            cp 'P'
            jr nz, .no
            ld l, 1
            jr .x
.no:        ld l, 0
.x:         xor a
            ld [$4000], a
            pop af
            ret
susp_w:
            push af
            push bc
            push de
            push hl
            cp $A5
            jr z, .save
            cp $5A
            jr z, .load
            cp $E0
            jr z, .erase
            jr .x
.save:      ld a, 3                         ; NES RAM and ExRAM -> bank 3 SUSP_RAM
            ld [$4000], a
            ld hl, NES_RAM
            ld de, SUSP_RAM
            ld bc, $0C00
            call .cp
            ld a, 2                         ; save RAM (bank 0) -> bank 2 through QV (the
            ld b, 32                        ;   VRAM queue is empty while the LCD is off)
            ld hl, $A000
.sv:        push bc
            xor a
            ld [$4000], a
            push hl
            ld de, QV
            ld bc, 256
            call .cp
            pop hl
            ld a, 2
            ld [$4000], a
            ld d, h
            ld e, l
            ld hl, QV
            ld bc, 256
            call .cp
            ld h, d
            ld l, e
            pop bc
            dec b
            jr nz, .sv
            ld a, 3
            ld [$4000], a
            ld hl, SUSP_MAGIC
            ld a, 'S'
            ld [hl+], a
            ld a, 'U'
            ld [hl+], a
            ld a, 'S'
            ld [hl+], a
            ld [hl], 'P'
            jr .x
.load:      ld a, 3                         ; bank 3 -> NES RAM (not page 1: the GB stack)
            ld [$4000], a
            ld hl, SUSP_RAM
            ld de, NES_RAM
            ld bc, $0100
            call .cp
            ld hl, SUSP_RAM + $0200
            ld de, NES_RAM + $0200
            ld bc, $0A00
            call .cp
            ld b, 32                        ; bank 2 -> save RAM
            ld hl, $A000
.ld:        push bc
            ld a, 2
            ld [$4000], a
            push hl
            ld de, QV
            ld bc, 256
            call .cp
            pop hl
            xor a
            ld [$4000], a
            ld d, h
            ld e, l
            ld hl, QV
            ld bc, 256
            call .cp
            ld h, d
            ld l, e
            pop bc
            dec b
            jr nz, .ld
.erase:     ld a, 3
            ld [$4000], a
            xor a
            ld [SUSP_MAGIC], a
.x:         xor a
            ld [$4000], a
            pop hl
            pop de
            pop bc
            pop af
            ret
.cp:        ld a, [hl+]                     ; HL -> DE, BC bytes
            ld [de], a
            inc de
            dec bc
            ld a, b
            or c
            jr nz, .cp
            ret

; ---- $5805 write (GB layout code, rt_mmc_w5805): A = 1 when FF1 starts building a field
; dialogue box ($D4B3), 0 when the box has closed ($D604 returned). FF1 builds the box in
; the other nametable at the view's position and shows it with a raster split growing to
; scanline $1B; the GB keeps one map for both nametables, so the box's cells go to the
; window map instead (dlg_cell) and the window shows its first dlg_l lines (rt_dlgdelay).
; The rectangle: NES column = view column (scroll + camera) + 32, the view's top tile row.
dlg_w:      push af
            push bc
            push hl
            and a
            jr z, .off
            ldh a, [dlg_on]
            and a
            jr nz, .x
            ldh a, [cam_x]                  ; column = ((scroll_x + cam_x) >> 3, with the carry
            ld b, a                         ;   as +32) + 32 * nametable + 32, mod 64
            ldh a, [scroll_x]
            add a, b
            rra
            srl a
            srl a
            ld b, a
            ldh a, [ppu_ctrl]
            and 1
            swap a
            add a, a
            add a, b
            add a, 32
            and 63
            ldh [dlg_c0], a
            ldh a, [cam_y]                  ; row = ((scroll_y + cam_y) mod 240) >> 3
            ld b, a
            ldh a, [scroll_y]
            add a, b
            jr c, .w
            cp 240
            jr c, .s
.w:         sub 240
.s:         srl a
            srl a
            srl a
            ldh [dlg_r0], a
            xor a
            ldh [dlg_l], a
            ldh [dlg_st], a
            inc a
            ldh [dlg_on], a
            jr .x
.off:       ldh a, [dlg_on]
            and a
            jr z, .x
            xor a
            ldh [dlg_on], a
            ldh [dlg_l], a
            ldh a, [is_cgb]                 ; CGB: the window rows back to the mask's
            and a                           ;   attributes (palette 7, black)
            jr z, .x
            ldh a, [lcd_on]
            and a
            jr nz, .on
            ld a, 1                         ; (LCD off: straight into VRAM bank 1)
            ldh [$FF4F], a
            ld hl, $9C00
.d:         ld a, $0F
            ld [hl+], a
            ld a, l
            and a
            jr nz, .d
            xor a
            ldh [$FF4F], a
            jr .x
.on:        ld hl, $DC00
.r:         ld a, $0F
            call vram_put
            inc l
            ld a, l
            and 31
            cp 20
            jr c, .r
            ld a, l
            add a, 12
            ld l, a
            jr nz, .r
.x:         pop hl
            pop bc
            pop af
            ret

; ---- far vstr / vchar (tools/ff1/gb_layout.py VWF_SRC), natively: A = index into VSTR; draws
; VSTR from there up to index VEND or a 0 into the line buffer VBUF (1 bit per pixel, 8 rows
; per tile, tile-major), $FD $80+n moving the pen to tile n. RAM as the NES routines leave it
; (VC, VX, VSQ, VCNT, VSH, VT2, VOFF, VLO, $88/$89 = the last glyph's rows, VBUF); the
; callers use no register after it. Glyph tables vw_gw / vw_gr: copies of the far bank's GW /
; GR made by build.py (codes $7A-$FF).
VW_BUF     = $AE00          ; (cart RAM bank 0 = NES $6000-$7FFF)
VW_VX      = $AE90
VW_VN      = $AE91
VW_VCNT    = $AE93
VW_VSH     = $AE94
VW_VOFF    = $AE95
VW_VLO     = $AE96
VW_VT2     = $AE97
VW_VC      = $AE99
VW_VEND    = $AEA6
VW_VSTR    = $AEB0
VW_VSQ     = $C346          ; (NES $0346)
VW_FIRST   = $7A
vstr_b:     call vstr_n                     ; (out: B = D = 0, as the recompiled code keeps
            ld b, 0                         ;   them: BC = Y, DE = X)
            ld d, 0
            ret
vstr_n:     ld [VW_VC], a
.l:         ld a, [VW_VEND]
            ld c, a
            ld a, [VW_VC]
            cp c
            ret nc                          ; index >= VEND
            add a, low(VW_VSTR)
            ld l, a
            ld h, high(VW_VSTR)
            ld a, [hl]
            and a
            ret z
            cp $FD
            jr nz, .c
            inc l                           ; $FD $80+n: pen to tile n
            ld a, [hl]
            sub $80
            add a, a
            add a, a
            add a, a
            ld [VW_VX], a
            ld hl, VW_VC
            inc [hl]
            jr .n
.c:         call vchar_n
.n:         ld hl, VW_VC
            inc [hl]
            jr nz, .l
            ret

vchar_n:    cp $FD
            ret z
            cp $FF
            jr nz, .g
            ld a, [VW_VX]                   ; space: 3 pixels
            add a, 3
            ld [VW_VX], a
            ret
.g:         sub VW_FIRST
            ret c
            ld e, a                         ; E = glyph
            ld hl, vw_gw
            add a, l
            ld l, a
            jr nc, .w
            inc h
.w:         ld a, [hl]
            and a
            ret z
            ld [VW_VCNT], a
            ld l, e                         ; HL = glyph * 8
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            push hl
            ld bc, VW_GR_NES                ; $88/$89 = GR + glyph * 8 (NES address)
            add hl, bc
            ld a, l
            ld [NES_RAM + $88], a
            ld a, h
            ld [NES_RAM + $89], a
            pop hl
            ld bc, vw_gr
            add hl, bc
            ld b, h
            ld c, l                         ; BC = the glyph's rows
            ld a, [VW_VX]
            and 7
            ld [VW_VSH], a
            ld h, a                         ; H = shift
            ld a, [VW_VX]
            srl a
            srl a
            srl a
            ld l, a                         ; L = tile
            ld a, [VW_VN]
            ld d, a                         ; D = tiles in the line
            ld a, l
            cp d
            jp nc, .adv
            ld [VW_VT2], a
            add a, a
            add a, a
            add a, a
            ld [VW_VOFF], a
            ld e, a                         ; DE = the tile's first row in VW_BUF
            ld a, h                         ; rows OR-ed in, unrolled: shift 0; shifted (the
            and a                           ;   table page of row >> shift: VW_SHR + 2 *
            jr z, .va                       ;   shift - 2, the next page: what spills into
            add a, a                        ;   the next tile) within the line's last tile;
            add a, high(VW_SHR) - 2         ;   shifted into the next tile too
            ld h, a
            inc l
            ld a, l
            cp d                            ; (carry: the next tile is in the line)
            ld d, high(VW_BUF)
            jr nc, .vb
            ld a, [bc]
            inc bc
            and a
            jr z, .z0
            ld l, a
            ld a, [de]
            or [hl]
            ld [de], a
            ld a, e
            add a, 8
            ld e, a
            inc h
            ld a, [de]
            or [hl]
            ld [de], a
            dec h
            ld a, e
            sub 8
            ld e, a
.z0:        inc e
            ld a, [bc]
            inc bc
            and a
            jr z, .z1
            ld l, a
            ld a, [de]
            or [hl]
            ld [de], a
            ld a, e
            add a, 8
            ld e, a
            inc h
            ld a, [de]
            or [hl]
            ld [de], a
            dec h
            ld a, e
            sub 8
            ld e, a
.z1:        inc e
            ld a, [bc]
            inc bc
            and a
            jr z, .z2
            ld l, a
            ld a, [de]
            or [hl]
            ld [de], a
            ld a, e
            add a, 8
            ld e, a
            inc h
            ld a, [de]
            or [hl]
            ld [de], a
            dec h
            ld a, e
            sub 8
            ld e, a
.z2:        inc e
            ld a, [bc]
            inc bc
            and a
            jr z, .z3
            ld l, a
            ld a, [de]
            or [hl]
            ld [de], a
            ld a, e
            add a, 8
            ld e, a
            inc h
            ld a, [de]
            or [hl]
            ld [de], a
            dec h
            ld a, e
            sub 8
            ld e, a
.z3:        inc e
            ld a, [bc]
            inc bc
            and a
            jr z, .z4
            ld l, a
            ld a, [de]
            or [hl]
            ld [de], a
            ld a, e
            add a, 8
            ld e, a
            inc h
            ld a, [de]
            or [hl]
            ld [de], a
            dec h
            ld a, e
            sub 8
            ld e, a
.z4:        inc e
            ld a, [bc]
            inc bc
            and a
            jr z, .z5
            ld l, a
            ld a, [de]
            or [hl]
            ld [de], a
            ld a, e
            add a, 8
            ld e, a
            inc h
            ld a, [de]
            or [hl]
            ld [de], a
            dec h
            ld a, e
            sub 8
            ld e, a
.z5:        inc e
            ld a, [bc]
            inc bc
            and a
            jr z, .z6
            ld l, a
            ld a, [de]
            or [hl]
            ld [de], a
            ld a, e
            add a, 8
            ld e, a
            inc h
            ld a, [de]
            or [hl]
            ld [de], a
            dec h
            ld a, e
            sub 8
            ld e, a
.z6:        inc e
            ld a, [bc]
            inc bc
            and a
            jr z, .z7
            ld l, a
            ld a, [de]
            or [hl]
            ld [de], a
            ld a, e
            add a, 8
            ld e, a
            inc h
            ld a, [de]
            or [hl]
            ld [de], a
            dec h
            ld a, e
            sub 8
            ld e, a
.z7:        inc e
            jp .adv
.va:        ld d, high(VW_BUF)
            ld a, [bc]
            inc bc
            ld l, a
            ld a, [de]
            or l
            ld [de], a
            inc e
            ld a, [bc]
            inc bc
            ld l, a
            ld a, [de]
            or l
            ld [de], a
            inc e
            ld a, [bc]
            inc bc
            ld l, a
            ld a, [de]
            or l
            ld [de], a
            inc e
            ld a, [bc]
            inc bc
            ld l, a
            ld a, [de]
            or l
            ld [de], a
            inc e
            ld a, [bc]
            inc bc
            ld l, a
            ld a, [de]
            or l
            ld [de], a
            inc e
            ld a, [bc]
            inc bc
            ld l, a
            ld a, [de]
            or l
            ld [de], a
            inc e
            ld a, [bc]
            inc bc
            ld l, a
            ld a, [de]
            or l
            ld [de], a
            inc e
            ld a, [bc]
            inc bc
            ld l, a
            ld a, [de]
            or l
            ld [de], a
            inc e
            jp .adv
.vb:
            ld a, [bc]
            inc bc
            ld l, a
            ld a, [de]
            or [hl]
            ld [de], a
            inc e
            ld a, [bc]
            inc bc
            ld l, a
            ld a, [de]
            or [hl]
            ld [de], a
            inc e
            ld a, [bc]
            inc bc
            ld l, a
            ld a, [de]
            or [hl]
            ld [de], a
            inc e
            ld a, [bc]
            inc bc
            ld l, a
            ld a, [de]
            or [hl]
            ld [de], a
            inc e
            ld a, [bc]
            inc bc
            ld l, a
            ld a, [de]
            or [hl]
            ld [de], a
            inc e
            ld a, [bc]
            inc bc
            ld l, a
            ld a, [de]
            or [hl]
            ld [de], a
            inc e
            ld a, [bc]
            inc bc
            ld l, a
            ld a, [de]
            or [hl]
            ld [de], a
            inc e
            ld a, [bc]
            inc bc
            ld l, a
            ld a, [de]
            or [hl]
            ld [de], a
            inc e
.adv:       ld hl, VW_VSQ                   ; a squeezed word: no gap after the letter
            ld a, [hl]
            and a
            jr z, .gap
            dec [hl]
            ld a, [VW_VCNT]
            ld b, a
            ld a, [VW_VX]
            add a, b
            ld [VW_VX], a
            ret
.gap:       ld a, [VW_VCNT]
            ld b, a
            ld a, [VW_VX]
            scf
            adc a, b
            ld [VW_VX], a
            ret

; ---- far vclear (gb_layout.py VWF_SRC): VN * 8 bytes of VBUF cleared (256 when that is 0),
; VX = 0. Out: A = X = 0, Y kept; N = 0, Z = 1, C = 1.
vclear_b:   xor a
            ld [VW_VX], a
            ldh [nzv], a
            ld a, [VW_VN]
            add a, a
            add a, a
            add a, a
            ld e, a
            ld hl, VW_BUF
            xor a
.l:         ld [hl+], a
            dec e
            jr nz, .l
            ld de, 0
            push af
            pop hl
            ld l, $90                       ; (Z, C)
            push hl
            pop af
            ret

; ---- NES OAM page A -> GB OAM shadow (rt_io_w4014 runs it with code_bank = HLE_BANK).
; The 64 entries are tested unrolled (most are hidden: y >= $EF): .vis converts one in
; view: GB y = NES y + 17 - cam_y * 8 (shown from -16), x = NES x + 8 - cam_x * 8 (from
; -8), its tile in a GB sprite slot (loaded on first use, coded for its palette), the
; attributes; a full GB table (40) ends the scan.
oamconv_b:  and $07
            add a, high(NES_RAM)
            ld h, a
            ldh a, [oam_frame]
            inc a
            ldh [oam_frame], a
            ldh a, [cam_y]
            cpl
            add a, 18
            ld b, a
            ldh a, [cam_x]
            cpl
            add a, 9
            ld c, a
            ld de, OAM_SH
            ld l, $00
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $04
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $08
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $0C
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $10
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $14
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $18
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $1C
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $20
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $24
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $28
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $2C
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $30
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $34
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $38
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $3C
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $40
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $44
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $48
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $4C
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $50
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $54
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $58
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $5C
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $60
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $64
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $68
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $6C
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $70
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $74
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $78
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $7C
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $80
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $84
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $88
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $8C
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $90
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $94
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $98
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $9C
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $A0
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $A4
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $A8
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $AC
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $B0
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $B4
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $B8
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $BC
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $C0
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $C4
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $C8
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $CC
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $D0
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $D4
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $D8
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $DC
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $E0
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $E4
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $E8
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $EC
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $F0
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $F4
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $F8
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $FC
            ld a, [hl]
            cp $EF
            call c, .vis
            jp .full
.vis:       add a, b                        ; HL -> entry, A = NES y
            cp 160
            ret nc
            ld [de], a                      ; (GB y; kept only if x is in view too)
            inc l
            ld a, [hl+]
            ldh [o_t], a
            ld a, [hl+]
            ldh [o_a], a
            ld a, [hl]
            add a, c
            cp 168
            jr nc, .xr
            inc e
            ld [de], a                      ; GB x
            inc e
            push hl
            push bc
            ldh a, [o_a]                    ; B = coding of the sprite's palette
            and 3
            add a, low(SPAL_KEY)
            ld l, a
            ld h, high(SPAL_KEY)
            ld b, [hl]
            ldh a, [o_t]                    ; C = its GB slot (loaded on first use)
            ld l, a
            ld h, high(SPR_SLOT)
            ld a, [hl]
            cp $FF
            jr z, .alloc
            ld c, a
            add a, low(SLOT_KEY)            ; resident with another coding: load it again
            ld l, a
            ld h, high(SLOT_KEY)
            ld a, b
            cp [hl]
            jr nz, .load
.ok:        ld a, c                         ; stamp (in use this frame)
            or $80
            ld l, a
            ld h, high(SLOT_STAMP)
            ldh a, [oam_frame]
            ld [hl], a
            ld a, c
            ld [de], a                      ; tile = slot
            inc e
            ldh a, [o_a]                    ; NES v h p - - - pp -> GB p v h obp1 - pal(3)
            ld l, a
            and $C0
            rrca
            bit 5, l
            jr z, .np
            or $80
.np:        ld h, a
            ld a, l
            and 3
            or h
            bit 6, b                        ; (DMG: OBP1 if the coding says so)
            jr z, .o0
            or $10
.o0:        ld [de], a
            inc e
            pop bc
            pop hl
            ld a, e
            cp 160
            ret nz
            pop af                          ; GB table full: the scan ends
            jr .full
.xr:        xor a                           ; out of view sideways: this entry's y hidden
            ld [de], a                      ;   again (else last frame's x and tile showed)
            ret
.alloc:     ld a, b
            ldh [o_key], a
            call spr_alloc
            ld c, a
            jr .ok
.load:      ld a, b
            ldh [o_key], a
            call spr_load
            jr .ok
.full:      ld a, e                         ; hide the GB sprites used last frame only
            rrca
            rrca
            ld c, a
            ld a, [OAM_USED]
            ld b, a
            ld a, c
            ld [OAM_USED], a
            ld a, b
            sub c
            jr c, .end
            jr z, .end
            ld b, a
            xor a
.clr:       ld [de], a
            inc e
            inc e
            inc e
            inc e
            dec b
            jr nz, .clr
.end:       ld a, 1
            ldh [oam_pending], a
            ret

; ---- c62:C324-C333 (copy X pages): LDY #0 / (LDA ($10),Y / STA ($12),Y / INY / BNE) / INC $11 /
; INC $13 / DEX / BNE. Page-aligned pointers: one GB page per NES page (ROM through its
; data bank); anything else byte by byte. Out: A = the last byte, X = Y = 0, $11 / $13 + X;
; N = 0, Z = 1, carry kept.
pgcopy_b:   push af                         ; (carry)
            ld c, 0
.pg:        ld a, [NES_RAM + $10]
            ld b, a
            ld a, [NES_RAM + $12]
            or b
            jr nz, .slow
            ld a, [NES_RAM + $13]           ; destination: RAM, ExRAM, save RAM
            cp $20
            jr nc, .d1
            and 7
            add a, high(NES_RAM)
            jr .dk
.d1:        cp $5C
            jr c, .slow
            cp $60
            jr nc, .d2
            add a, $6C
            jr .dk
.d2:        cp $80
            jr nc, .slow
            add a, $40
.dk:        ld d, a
            ld a, [NES_RAM + $11]           ; source: as the destination, or ROM
            cp $20
            jr nc, .s1
            and 7
            add a, high(NES_RAM)
            jr .sn
.s1:        cp $5C
            jr c, .slow
            cp $60
            jr nc, .s2
            add a, $6C
            jr .sn
.s2:        cp $80
            jr nc, .s3
            add a, $40
.sn:        ld h, a
            xor a                           ; (no bank switch)
            jr .cp
.s3:        cp $C0
            jr nc, .s4
            sub $40
            ld h, a
            ldh a, [data_bank8]
            jr .cp
.s4:        sub $80
            ld h, a
            cp $60
            ld a, DATA + 31
            jr nc, .cp
            ldh a, [data_bankC]
.cp:        ld l, 0
            ld b, e                         ; (X)
            ld e, 0
            call pg_copy0                   ; (bank 0: the source bank may replace this one)
            ld e, b
            ldh [tmp_lo], a
            ld hl, NES_RAM + $11
            inc [hl]
            ld hl, NES_RAM + $13
            inc [hl]
            dec e
            jr nz, .pg
            jr .done
.slow:      ld b, 0                         ; byte by byte (C = Y)
.sb:        ld l, $10
            call rt_izy_rd
            ld a, l
            ldh [tmp_lo], a
            ld l, $12
            call rt_izy_wr
            inc c
            jr nz, .sb
            ld hl, NES_RAM + $11
            inc [hl]
            ld hl, NES_RAM + $13
            inc [hl]
            dec e
            jr nz, .slow
.done:      ld bc, 0
            ld d, 0
            ld e, 0
            xor a
            ldh [nzv], a
            pop af
            ldh a, [tmp_lo]
            ld l, 0
            inc l
            dec l                           ; Z = 1, carry kept
            ret


; set bits of each byte (mdf_ownrow)
section bank HLE_BANK, $5F00
POPC:
            db 0, 1, 1, 2, 1, 2, 2, 3, 1, 2, 2, 3, 2, 3, 3, 4
            db 1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5
            db 1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5
            db 2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6
            db 1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5
            db 2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6
            db 2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6
            db 3, 4, 4, 5, 4, 5, 5, 6, 4, 5, 5, 6, 5, 6, 6, 7
            db 1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5
            db 2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6
            db 2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6
            db 3, 4, 4, 5, 4, 5, 5, 6, 4, 5, 5, 6, 5, 6, 6, 7
            db 2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6
            db 3, 4, 4, 5, 4, 5, 5, 6, 4, 5, 5, 6, 5, 6, 6, 7
            db 3, 4, 4, 5, 4, 5, 5, 6, 4, 5, 5, 6, 5, 6, 6, 7
            db 4, 5, 5, 6, 5, 6, 6, 7, 5, 6, 6, 7, 6, 7, 7, 8

; ---- bank 0: one page HL -> DE (E = 0), with ROM bank A at $4000 for it (0: none); bank
; HLE_BANK again after. Out: A = the last byte. (For pgcopy_b, which runs in HLE_BANK.)
section bank 0, $3DA0
pg_copy0:   and a
            jr z, .c
            ld [$2000], a
.c:         ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            jr nz, .c
            push af
            ld a, HLE_BANK
            ld [$2000], a
            pop af
            ret

; (moved here from runtime.s: bank 0 space)
; A = old XOR new attribute byte -> A = bit q set for each quadrant q that changed
quad_mask:  push bc
            ld c, a
            ld b, 0
            and $03
            jr z, .q1
            set 0, b
.q1:        ld a, c
            and $0C
            jr z, .q2
            set 1, b
.q2:        ld a, c
            and $30
            jr z, .q3
            set 2, b
.q3:        ld a, c
            and $C0
            jr z, .q4
            set 3, b
.q4:        ld a, b
            pop bc
            ret

; (bank 0 space after the colour tables)
section bank 0, $3F40
; ---- fix:F56A-F591 (battle box row): LDY #0 / LDA $68B3 / STA ($88),Y / LDX $6AA1 / DEX /
; DEX / INY / LDA $68B4 / (STA ($88),Y / INY / DEX / BNE) / LDA $68B5 / STA ($88),Y /
; $88-$89 += $20 (CLC / ADC). Out: X = 0, Y = width - 1, A = $89; N, Z, C of the last ADC.
hle_boxrow: ld a, [$AAA1]                   ; ($6AA1: the box width)
            sub 2
            ld e, a                         ; E = middle cells (0: 256, as DEX / BNE)
            ld a, [NES_RAM + $89]
            sub $60
            cp $1F
            jr nc, .slow                    ; (not in save RAM $6000-$7EFF)
            add a, $A0
            ld h, a
            ld a, [NES_RAM + $88]
            ld l, a
            ld a, [$A8B3]
            ld [hl+], a
            ld a, [$A8B4]
            ld b, e
.m:         ld [hl+], a
            dec b
            jr nz, .m
            ld a, [$A8B5]
            ld [hl], a
            jr .done
.slow:      ld bc, 0
            ld a, [$A8B3]
            ld l, $88
            call rt_izy_wr
            inc c
.sm:        ld a, [$A8B4]
            ld l, $88
            call rt_izy_wr
            inc c
            dec e
            jr nz, .sm
            ld a, [$A8B5]
            ld l, $88
            call rt_izy_wr
.done:      ld a, [$AAA1]
            dec a
            ld c, a                         ; Y
            ld b, 0
            ld d, 0
            ld e, 0                         ; X
            ld a, [NES_RAM + $88]
            add a, $20
            ld [NES_RAM + $88], a
            ld a, [NES_RAM + $89]
            adc a, 0
            ld [NES_RAM + $89], a
            ldh [nzv], a
            ret

; ---- c62:D188 .. the $FF that ends it (map decompression into save RAM): bytes < $80 are
; tiles, $80 + t then n (0: 256) a run of t, $FF the end; the source crossing into $C000
; goes on at $8000 of the next bank (c62:D1D9: $15 + 1 through $FE03: $5115). In bank 0
; (the source is read through the data bank). Out as at c62:D158: A = $FF, Y = 0, X as the
; NES leaves it (0 after a run); $10-$14 as on the NES; Z = 1, C = 1, N = 0.
MDC_X      = $DCD5
section bank 0, $3E80
hle_mapdec: ld a, e
            ld [MDC_X], a
            ldh a, [data_bank8]
            ld [$2000], a
            ld a, [NES_RAM + $10]
            ld l, a
            ld a, [NES_RAM + $11]
            sub $40
            ld h, a                         ; HL = source ($8000 -> $4000)
            ld a, [NES_RAM + $12]
            ld e, a
            ld a, [NES_RAM + $13]
            add a, $40
            ld d, a                         ; DE = destination ($7000 -> $B000)
.lp:        ld a, [hl]
            bit 7, a
            jr nz, .run
            ld [de], a
            inc de
            call .inc
            jr .lp
.run:       cp $FF
            jp z, mdc_end
            and $7F
            ld [NES_RAM + $14], a
            ld b, a
            call .inc
            ld c, [hl]                      ; count (0: 256)
            ld a, b
.f:         ld [de], a
            inc de
            dec c
            jr nz, .f
            xor a
            ld [MDC_X], a
            call .inc
            jr .lp
.inc:       inc l
            ret nz
            inc h
            bit 7, h                        ; (NES $C000: the next bank at $8000)
            ret z
            ld h, $40
            ld a, [NES_RAM + $15]
            inc a
            add a, a
            or $80
            call rt_mmc_w5115
            ldh a, [data_bank8]
            ld [$2000], a
            ret

; (hle_mapdec's end, in the bank-0 space after hle_boxrow)
section bank 0, $3FA6
mdc_end:       ld a, l
            ld [NES_RAM + $10], a
            ld a, h
            add a, $40
            ld [NES_RAM + $11], a
            ld a, e
            ld [NES_RAM + $12], a
            ld a, d
            sub $40
            ld [NES_RAM + $13], a
            ldh a, [code_bank]
            ld [$2000], a
            xor a
            ldh [nzv], a
            ld bc, 0
            ld d, 0
            ld a, [MDC_X]
            ld e, a
            ld a, $FF
            cp a
            scf
            ret

; ---- DMG tile coding, one output plane per call: plane = f(NES plane 0, plane 1), f one of the
; 16 boolean functions (bit i of T: the value for colour index i = p0 + 2 * p1). HL = the tile
; in the shadow (interleaved rows), DE = the plane's first byte (+2 a row). Clobbers A, BC.
; (PF_BANK = 60: runtime.s)
section bank PF_BANK, $4000
pf_tab:
            dw pf_0, pf_1, pf_2, pf_3, pf_4, pf_5, pf_6, pf_7, pf_8, pf_9, pf_10, pf_11, pf_12, pf_13, pf_14, pf_15
pf_0:
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            xor a
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            xor a
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            xor a
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            xor a
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            xor a
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            xor a
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            xor a
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            xor a
            ld [de], a
            inc e
            inc e
            ret
pf_1:
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            or b
            cpl
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            or b
            cpl
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            or b
            cpl
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            or b
            cpl
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            or b
            cpl
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            or b
            cpl
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            or b
            cpl
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            or b
            cpl
            ld [de], a
            inc e
            inc e
            ret
pf_2:
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            cpl
            and b
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            cpl
            and b
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            cpl
            and b
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            cpl
            and b
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            cpl
            and b
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            cpl
            and b
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            cpl
            and b
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            cpl
            and b
            ld [de], a
            inc e
            inc e
            ret
pf_3:
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            cpl
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            cpl
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            cpl
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            cpl
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            cpl
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            cpl
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            cpl
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            cpl
            ld [de], a
            inc e
            inc e
            ret
pf_4:
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld c, a
            ld a, b
            cpl
            and c
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld c, a
            ld a, b
            cpl
            and c
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld c, a
            ld a, b
            cpl
            and c
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld c, a
            ld a, b
            cpl
            and c
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld c, a
            ld a, b
            cpl
            and c
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld c, a
            ld a, b
            cpl
            and c
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld c, a
            ld a, b
            cpl
            and c
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld c, a
            ld a, b
            cpl
            and c
            ld [de], a
            inc e
            inc e
            ret
pf_5:
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld a, b
            cpl
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld a, b
            cpl
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld a, b
            cpl
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld a, b
            cpl
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld a, b
            cpl
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld a, b
            cpl
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld a, b
            cpl
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld a, b
            cpl
            ld [de], a
            inc e
            inc e
            ret
pf_6:
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            xor b
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            xor b
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            xor b
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            xor b
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            xor b
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            xor b
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            xor b
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            xor b
            ld [de], a
            inc e
            inc e
            ret
pf_7:
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            and b
            cpl
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            and b
            cpl
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            and b
            cpl
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            and b
            cpl
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            and b
            cpl
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            and b
            cpl
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            and b
            cpl
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            and b
            cpl
            ld [de], a
            inc e
            inc e
            ret
pf_8:
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            and b
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            and b
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            and b
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            and b
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            and b
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            and b
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            and b
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            and b
            ld [de], a
            inc e
            inc e
            ret
pf_9:
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            xor b
            cpl
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            xor b
            cpl
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            xor b
            cpl
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            xor b
            cpl
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            xor b
            cpl
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            xor b
            cpl
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            xor b
            cpl
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            xor b
            cpl
            ld [de], a
            inc e
            inc e
            ret
pf_10:
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld a, b
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld a, b
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld a, b
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld a, b
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld a, b
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld a, b
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld a, b
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld a, b
            ld [de], a
            inc e
            inc e
            ret
pf_11:
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            cpl
            or b
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            cpl
            or b
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            cpl
            or b
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            cpl
            or b
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            cpl
            or b
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            cpl
            or b
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            cpl
            or b
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            cpl
            or b
            ld [de], a
            inc e
            inc e
            ret
pf_12:
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ret
pf_13:
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld c, a
            ld a, b
            cpl
            or c
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld c, a
            ld a, b
            cpl
            or c
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld c, a
            ld a, b
            cpl
            or c
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld c, a
            ld a, b
            cpl
            or c
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld c, a
            ld a, b
            cpl
            or c
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld c, a
            ld a, b
            cpl
            or c
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld c, a
            ld a, b
            cpl
            or c
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld c, a
            ld a, b
            cpl
            or c
            ld [de], a
            inc e
            inc e
            ret
pf_14:
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            or b
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            or b
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            or b
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            or b
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            or b
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            or b
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            or b
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            or b
            ld [de], a
            inc e
            inc e
            ret
pf_15:
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld a, $FF
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld a, $FF
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld a, $FF
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld a, $FF
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld a, $FF
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld a, $FF
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld a, $FF
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld a, $FF
            ld [de], a
            inc e
            inc e
            ret

; bank 0: A = function T, HL = shadow tile, DE = output plane: pf_T in PF_BANK, then
; HLE_BANK again (for retile_b). Clobbers A, BC.
section bank 0, $3D20
pf_call:    push hl
            add a, a
            ld l, a
            ld h, high(pf_tab)
            ld a, PF_BANK
            ld [$2000], a
            ld a, [hl+]
            ld b, [hl]
            ld c, a
            pop hl
            call .go
            ld a, HLE_BANK
            ld [$2000], a
            ret
.go:        push bc
            ret

; $5808 (GB layout, battle message teardown): the message window's text cells (NES rows
; 19-22, columns 2-19) blank at once, in the shadow and the GB map (once per frame), so
; the whole message goes together; FF1's row-by-row panel copy that follows then finds
; them blank already (and draws back whatever stays)
BLK_F      = $DCD6
rt_mmc_w5808:
            push af
            push bc
            push de
            push hl
            ld hl, BLK_F                    ; (16-bit frame count of the last blank)
            ld a, [NMI_CNT]
            cp [hl]
            jr nz, .n
            inc l
            ld a, [NMI_CNT + 1]
            cp [hl]
            jr z, .x
.n:         ld a, [NMI_CNT]
            ld [BLK_F], a
            ld a, [NMI_CNT + 1]
            ld [BLK_F + 1], a
            ld hl, NT_SH + 19 * 32 + 2
            ld de, $9800 + 19 * 32 + 2
            ld c, 4
.r:         ld b, 18
.c:         ld a, [hl]                      ; (only the message window's own small-font tiles,
            sub $A8                         ;   $A8-$EF: the party and command windows keep
            cp $48                          ;   theirs)
            jr c, .bl
            inc hl
            jr .nx
.bl:        xor a
            ld [hl+], a
.w:         di
            ldh a, [$FF41]
            bit 1, a
            jr z, .g
            ei
            jr .w
.g:         xor a
            ld [de], a
            ei
.nx:        inc de
            dec b
            jr nz, .c
            ld a, 14
            add a, l
            ld l, a
            ld a, 14
            add a, e
            ld e, a
            dec c
            jr nz, .r
.x:         pop hl
            pop de
            pop bc
            pop af
            ret

; ---- the DMG LCD-on map scan (dmg_scan_all), in PF_BANK
section bank PF_BANK, $4800
SC_NP      = $DE00          ; scan_b: palette each tile is drawn with ($FF: not used; the FRESH /
                            ;   TBLK area, free here: queue flushed, FRESH superseded)
scan_b:     push bc
            push de
            push hl
            ld a, 1
            ldh [sgb_dirty], a
            ldh [sgb_adirty], a
            xor a
            ldh [dmg_scan], a
            ld hl, REF_BM
            ld b, 32
.z:         ld [hl+], a
            dec b
            jr nz, .z
            ld hl, SC_NP
            ld a, $FF
.f:         ld [hl+], a
            dec b
            jr nz, .f
            ldh a, [own1_lo]                ; one palette for the whole screen (no cell drawn
            ld b, a                         ;   by nametable 1, nametable 0's 64 attribute
            ldh a, [own1_hi]                ;   bytes all one value with four equal
            or b                            ;   quadrants: menus, new-game screens): every
            jr nz, .full                    ;   tile of the map gets that palette
            ld hl, NT_SH + $3C0
            ld a, [hl+]
            ld c, a
            ld b, 63
.ua:        ld a, [hl+]
            cp c
            jr nz, .full
            dec b
            jr nz, .ua
            ld a, c
            rrca
            rrca
            xor c
            and $3F
            jr nz, .full                    ; (quadrants differ)
            ld a, c
            and 3
            ld b, a                         ; B = the palette
            ld l, b
            ld h, high(NBIT60)
            ld a, [hl]
            ld [PAL_USED], a
            ld hl, NT_SH
            ld d, high(SC_NP)
            ld c, 240                       ; 960 cells, 4 per pass
.uc:        ld a, [hl+]
            ld e, a
            ld a, b
            ld [de], a
            ld a, [hl+]
            ld e, a
            ld a, b
            ld [de], a
            ld a, [hl+]
            ld e, a
            ld a, b
            ld [de], a
            ld a, [hl+]
            ld e, a
            ld a, b
            ld [de], a
            dec c
            jr nz, .uc
            jp .settle
.full:      ldh a, [cam_y]                  ; the view: map row (scroll_y + cam_y) mod 240 / 8,
            ld b, a                         ;   column (scroll_x + cam_x) / 8
            ldh a, [scroll_y]
            add a, b
            jr c, .w
            cp 240
            jr c, .y
.w:         sub 240
.y:         srl a
            srl a
            srl a
            ld [SC_VR], a
            ldh a, [cam_x]
            ld b, a
            ldh a, [scroll_x]
            add a, b
            srl a
            srl a
            srl a
            ld [SC_VC], a
            ld d, 0                         ; every cell, rows 0-29
.r:         call scn_tab                    ;   (then the view's cells again: they win for a
            call scn_rowf                   ;   tile drawn with two palettes)
            inc d
            ld a, d
            cp 30
            jr nz, .r
            xor a
            ld [PAL_USED], a
            ld a, [SC_VR]
            ld d, a
            ld b, 18
.vr:        push bc
            call scn_tab
            call scn_rowv
            ld a, d
            inc a
            cp 30
            jr c, .vn
            xor a
.vn:        ld d, a
            pop bc
            dec b
            jr nz, .vr
.settle:    ld e, 0                         ; each tile used: REF_BM; drawn with another palette
.t:         ld l, e                         ;   than it is coded for: TILE_PAL, marked; the
            ld h, high(SC_NP)               ;   same palette but parked: marked again
            ld a, [hl]
            cp $FF
            jr z, .tn
            ld b, a
            ld a, e
            and 7
            ld l, a
            ld h, high(NBIT60)
            ld c, [hl]                      ; C = the tile's bit
            ld a, e
            rrca
            rrca
            rrca
            and $1F
            ld d, a                         ; D = its byte
            add a, low(REF_BM)
            ld l, a
            ld h, high(REF_BM)
            ld a, [hl]
            or c
            ld [hl], a
            ld l, e
            ld h, high(TILE_PAL)
            ld a, [hl]
            cp b
            jr z, .sm
            ld [hl], b
            jr .mk
.sm:        ld a, d
            add a, low(DEFER_BM)
            ld l, a
            ld h, high(DEFER_BM)
            ld a, [hl]
            and c
            jr z, .tn
.mk:        ld a, d                         ; marked (DIRTY_BM), no longer parked (as dmg_mark)
            ld l, a
            ld h, high(DIRTY_BM)
            ld a, [hl]
            or c
            ld [hl], a
            ld a, l
            add a, low(DEFER_BM)
            ld l, a
            ld a, c
            cpl
            and [hl]
            ld [hl], a
            ld a, 1
            ldh [rq_any], a
.tn:        inc e
            jr nz, .t
            ld hl, SC_NP                    ; FRESH (and TBLK) cleared, nothing pending
            xor a
            ld b, a
.c:         ld [hl+], a
            dec b
            jr nz, .c
            ld [FR_ANY], a
            ld [FR_PEND], a
            ld [FR_AGE], a
            ld [FR_EMPTY], a
            ld [FR_POS], a
            pop hl
            pop de
            pop bc
            ret

; scan_b, map row D: SC_TL / SC_TH (tile row offset, page of nametable 0) and SP_T[nt * 16
; + pair] = the palette of columns 2 * pair, + 1 in nametable nt. Keeps DE.
scn_tab:    push de
            ld a, d
            and 7
            swap a
            add a, a
            ld [SC_TL], a
            ld a, d
            srl a
            srl a
            srl a
            add a, high(NT_SH)
            ld [SC_TH], a
            ld a, d
            and $1C
            add a, a
            add a, $C0
            ld l, a
            ld bc, SP_T
            bit 1, d
            jr nz, .s
            ld h, high(NT_SH) + 3
            push hl
            ld a, [hl+]
            ld e, a
            and 3
            ld [bc], a
            inc c
            ld a, e
            rrca
            rrca
            and 3
            ld [bc], a
            inc c
            ld a, [hl+]
            ld e, a
            and 3
            ld [bc], a
            inc c
            ld a, e
            rrca
            rrca
            and 3
            ld [bc], a
            inc c
            ld a, [hl+]
            ld e, a
            and 3
            ld [bc], a
            inc c
            ld a, e
            rrca
            rrca
            and 3
            ld [bc], a
            inc c
            ld a, [hl+]
            ld e, a
            and 3
            ld [bc], a
            inc c
            ld a, e
            rrca
            rrca
            and 3
            ld [bc], a
            inc c
            ld a, [hl+]
            ld e, a
            and 3
            ld [bc], a
            inc c
            ld a, e
            rrca
            rrca
            and 3
            ld [bc], a
            inc c
            ld a, [hl+]
            ld e, a
            and 3
            ld [bc], a
            inc c
            ld a, e
            rrca
            rrca
            and 3
            ld [bc], a
            inc c
            ld a, [hl+]
            ld e, a
            and 3
            ld [bc], a
            inc c
            ld a, e
            rrca
            rrca
            and 3
            ld [bc], a
            inc c
            ld a, [hl+]
            ld e, a
            and 3
            ld [bc], a
            inc c
            ld a, e
            rrca
            rrca
            and 3
            ld [bc], a
            inc c
            pop hl
            ld h, high(NT_SH) + 7
            ld a, [hl+]
            ld e, a
            and 3
            ld [bc], a
            inc c
            ld a, e
            rrca
            rrca
            and 3
            ld [bc], a
            inc c
            ld a, [hl+]
            ld e, a
            and 3
            ld [bc], a
            inc c
            ld a, e
            rrca
            rrca
            and 3
            ld [bc], a
            inc c
            ld a, [hl+]
            ld e, a
            and 3
            ld [bc], a
            inc c
            ld a, e
            rrca
            rrca
            and 3
            ld [bc], a
            inc c
            ld a, [hl+]
            ld e, a
            and 3
            ld [bc], a
            inc c
            ld a, e
            rrca
            rrca
            and 3
            ld [bc], a
            inc c
            ld a, [hl+]
            ld e, a
            and 3
            ld [bc], a
            inc c
            ld a, e
            rrca
            rrca
            and 3
            ld [bc], a
            inc c
            ld a, [hl+]
            ld e, a
            and 3
            ld [bc], a
            inc c
            ld a, e
            rrca
            rrca
            and 3
            ld [bc], a
            inc c
            ld a, [hl+]
            ld e, a
            and 3
            ld [bc], a
            inc c
            ld a, e
            rrca
            rrca
            and 3
            ld [bc], a
            inc c
            ld a, [hl+]
            ld e, a
            and 3
            ld [bc], a
            inc c
            ld a, e
            rrca
            rrca
            and 3
            ld [bc], a
            inc c
            pop de
            ret
.s:         ld h, high(NT_SH) + 3           ; (bottom half of the attribute bytes)
            push hl
            ld a, [hl+]
            swap a
            ld e, a
            and 3
            ld [bc], a
            inc c
            ld a, e
            rrca
            rrca
            and 3
            ld [bc], a
            inc c
            ld a, [hl+]
            swap a
            ld e, a
            and 3
            ld [bc], a
            inc c
            ld a, e
            rrca
            rrca
            and 3
            ld [bc], a
            inc c
            ld a, [hl+]
            swap a
            ld e, a
            and 3
            ld [bc], a
            inc c
            ld a, e
            rrca
            rrca
            and 3
            ld [bc], a
            inc c
            ld a, [hl+]
            swap a
            ld e, a
            and 3
            ld [bc], a
            inc c
            ld a, e
            rrca
            rrca
            and 3
            ld [bc], a
            inc c
            ld a, [hl+]
            swap a
            ld e, a
            and 3
            ld [bc], a
            inc c
            ld a, e
            rrca
            rrca
            and 3
            ld [bc], a
            inc c
            ld a, [hl+]
            swap a
            ld e, a
            and 3
            ld [bc], a
            inc c
            ld a, e
            rrca
            rrca
            and 3
            ld [bc], a
            inc c
            ld a, [hl+]
            swap a
            ld e, a
            and 3
            ld [bc], a
            inc c
            ld a, e
            rrca
            rrca
            and 3
            ld [bc], a
            inc c
            ld a, [hl+]
            swap a
            ld e, a
            and 3
            ld [bc], a
            inc c
            ld a, e
            rrca
            rrca
            and 3
            ld [bc], a
            inc c
            pop hl
            ld h, high(NT_SH) + 7
            ld a, [hl+]
            swap a
            ld e, a
            and 3
            ld [bc], a
            inc c
            ld a, e
            rrca
            rrca
            and 3
            ld [bc], a
            inc c
            ld a, [hl+]
            swap a
            ld e, a
            and 3
            ld [bc], a
            inc c
            ld a, e
            rrca
            rrca
            and 3
            ld [bc], a
            inc c
            ld a, [hl+]
            swap a
            ld e, a
            and 3
            ld [bc], a
            inc c
            ld a, e
            rrca
            rrca
            and 3
            ld [bc], a
            inc c
            ld a, [hl+]
            swap a
            ld e, a
            and 3
            ld [bc], a
            inc c
            ld a, e
            rrca
            rrca
            and 3
            ld [bc], a
            inc c
            ld a, [hl+]
            swap a
            ld e, a
            and 3
            ld [bc], a
            inc c
            ld a, e
            rrca
            rrca
            and 3
            ld [bc], a
            inc c
            ld a, [hl+]
            swap a
            ld e, a
            and 3
            ld [bc], a
            inc c
            ld a, e
            rrca
            rrca
            and 3
            ld [bc], a
            inc c
            ld a, [hl+]
            swap a
            ld e, a
            and 3
            ld [bc], a
            inc c
            ld a, e
            rrca
            rrca
            and 3
            ld [bc], a
            inc c
            ld a, [hl+]
            swap a
            ld e, a
            and 3
            ld [bc], a
            inc c
            ld a, e
            rrca
            rrca
            and 3
            ld [bc], a
            inc c
            pop de
            ret

; scan_b: row D (scn_tab done), every column: SC_NP[tile] = palette; an 8-column group drawn
; by one nametable two cells per palette fetch
scn_rowf:   ld e, 0
.g:         ld a, d                         ; OWN byte of columns E..E+7
            add a, a
            add a, a
            ld l, a
            ld a, e
            rrca
            rrca
            rrca
            and 3
            or l
            ld l, a
            ld h, high(OWN)
            ld a, [hl]
            and a
            jr z, .u0
            inc a
            jr z, .u1
            ld b, 8                         ; both nametables: cell by cell
.m:         push bc
            call scn_c
            inc e
            pop bc
            dec b
            jr nz, .m
            jr .ng
.u0:        ld c, 0
            jr .uf
.u1:        ld c, 16
.uf:        push de
            ld a, [SC_TH]
            bit 4, c
            jr z, .p0
            add a, 4
.p0:        ld h, a
            ld a, [SC_TL]
            or e
            ld l, a
            ld a, e
            srl a
            add a, c
            add a, low(SP_T)
            ld c, a
            ld b, high(SP_T)
            ld d, high(SC_NP)
            ld a, [bc]
            inc c
            ld e, [hl]
            inc l
            ld [de], a
            ld e, [hl]
            inc l
            ld [de], a
            ld a, [bc]
            inc c
            ld e, [hl]
            inc l
            ld [de], a
            ld e, [hl]
            inc l
            ld [de], a
            ld a, [bc]
            inc c
            ld e, [hl]
            inc l
            ld [de], a
            ld e, [hl]
            inc l
            ld [de], a
            ld a, [bc]
            inc c
            ld e, [hl]
            inc l
            ld [de], a
            ld e, [hl]
            inc l
            ld [de], a
            pop de
            ld a, e
            add a, 8
            ld e, a
.ng:        ld a, e
            cp 32
            jr nz, .g
            ret

; scan_b: view row D (scn_tab done), its 20 columns from SC_VC: SC_NP[tile] = palette,
; PAL_USED gets each palette; owner bits fetched again at each 8-column boundary
scn_rowv:   ld a, [SC_VC]
            ld e, a
            call .ob
            ld b, 20
.c:         push bc
            srl c                           ; owner: carry
            ld a, [SC_TH]
            ld b, 0
            jr nc, .o0
            add a, 4
            ld b, 16
.o0:        ld h, a
            ld a, [SC_TL]
            or e
            ld l, a
            ld a, [hl]                      ; tile
            push af
            ld a, e
            srl a
            add a, b
            add a, low(SP_T)
            ld l, a
            ld h, high(SP_T)
            ld b, [hl]                      ; palette
            pop af
            ld l, a
            ld h, high(SC_NP)
            ld [hl], b
            ld l, b
            ld h, high(NBIT60)
            ld a, [hl]
            ld hl, PAL_USED
            or [hl]
            ld [hl], a
            ld a, c
            pop bc
            ld c, a
            ld a, e
            inc a
            and 31
            ld e, a
            and 7
            call z, .ob
            dec b
            jr nz, .c
            ret
.ob:        ld a, d                         ; C = owner bits from column E on
            add a, a
            add a, a
            ld l, a
            ld a, e
            rrca
            rrca
            rrca
            and 3
            or l
            ld l, a
            ld h, high(OWN)
            ld c, [hl]
            ld a, e
            and 7
            ret z
.sh:        srl c
            dec a
            jr nz, .sh
            ret

; scan_b: map row D (scn_tab done), column E: SC_NP[tile] = A = its palette (the cell's
; nametable from OWN). Keeps DE.
scn_c:      push de
            ld a, d
            add a, a
            add a, a
            ld l, a
            ld a, e
            rrca
            rrca
            rrca
            and 3
            or l
            ld l, a
            ld h, high(OWN)
            ld b, [hl]
            ld a, e
            and 7
            ld l, a
            ld h, high(NBIT60)
            ld a, [hl]
            and b
            ld c, 0
            ld a, [SC_TH]
            jr z, .o
            ld c, 16
            add a, 4
.o:         ld h, a
            ld a, [SC_TL]
            or e
            ld l, a
            ld b, [hl]                      ; B = tile
            ld a, e
            srl a
            add a, c
            add a, low(SP_T)
            ld l, a
            ld h, high(SP_T)
            ld a, [hl]
            ld l, b
            ld h, high(SC_NP)
            ld [hl], a
            pop de
            ret

section bank PF_BANK, $7F00
NBIT60:     db 1, 2, 4, 8, 16, 32, 64, 128
