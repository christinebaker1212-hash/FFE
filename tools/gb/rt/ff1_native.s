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
SC_TC      = $D827          ;   scn_tab: row / 2 its SP_T is for ($FF: none; fault-dump area DBG + 7)

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
            ldh a, [is_cgb]                 ; DMG with the LCD off: the attribute shadow
            and a                           ;   only, in one loop (the map is scanned when
            jr nz, .lp                      ;   the LCD goes on)
            ldh a, [lcd_on]
            and a
            jr z, .fo
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
            jr z, .off
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
.off:       ld a, b                         ; DMG, LCD off: the attribute shadow (the map
            ldh [ppu_vh], a                 ;   is scanned when the LCD goes on)
            ld a, c
            ldh [ppu_vl], a
            ld a, b
            and $07
            ld h, a
            and $04
            push de
            ld d, a
            ld a, h
            and $03
            or d
            pop de
            add a, high(NT_SH)
            ld h, a
            ld l, c
            pop af
            push af
            cp [hl]
            jr z, .os
            ld [hl], a
            ld a, 1
            ldh [dmg_scan], a
.os:        call ppu_inc
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
.ex:        ld b, 0                         ; Y = last at_lo, A = last new byte; Z = 1, C = 1
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
.fo:        ld a, [NES_RAM + $11]
            ld e, a                         ; E = entries left; L walks the
            ld hl, NES_RAM + $07D0          ;   tables by bits 4-5: $C0 attr, $D0 hi, $E0 lo,
.fl:        ld a, [hl]                      ;   $F0 mask
            and 7
            add a, high(NT_SH)
            ld b, a
            res 4, l
            set 5, l
            ld c, [hl]                      ; BC = the byte in the shadow
            ld a, [bc]
            ld d, a                         ; D = old
            res 5, l
            xor [hl]
            set 4, l
            set 5, l
            and [hl]                        ; (old ^ attr) & mask: the bits that change
            jr z, .fs
            xor d
            ld [bc], a
            ld a, 1
            ldh [dmg_scan], a
.fs:        res 5, l
            inc l
            dec e
            jr nz, .fl
            ld a, d                         ; the last entry: $10 = its old byte, the read
            ld [NES_RAM + $10], a           ;   buffer = the byte after it, v = its address
            inc c                           ;   + 1 or 32
            ld a, [bc]
            dec c
            ldh [ppu_rbuf], a
            ld a, [bc]
            ld d, a                         ; D = its new byte
            ld a, [NES_RAM + $11]
            ld e, a                         ; (X = the count)
            add a, low(NES_RAM + $07CF)
            ld l, a
            ld h, high(NES_RAM + $07CF)
            ld b, [hl]                      ; its address high
            ldh a, [ppu_ctrl]
            and 4
            ld a, 1
            jr z, .fi
            ld a, 32
.fi:        add a, c
            ldh [ppu_vl], a
            ld a, b
            adc a, 0
            and $3F
            ldh [ppu_vh], a
            jr .ex

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
            pop de                          ; the tile not in ROM (BG_LZ) and its shadow
            push de                         ;   holding these rows already: nothing to
            ld a, d                         ;   write, code or queue (the NES writes the
            rrca                            ;   same bytes again when FF1 redraws a box)
            rrca
            rrca
            and $1F
            add a, low(BG_LZ)
            ld l, a
            ld h, high(BG_LZ)
            ld a, d
            and 7
            ld b, 1
            jr z, .zb
.zs:        sla b
            dec a
            jr nz, .zs
.zb:        ld a, 3
            ld [$4000], a
            ld a, [hl]
            and b
            ld c, a
            xor a
            ld [$4000], a
            or c
            jr nz, .wr
            ld a, d
            swap a
            ld l, a
            and $F0
            ld c, a
            ld a, l
            and $0F
            add a, high(BG_SHADOW)
            ld h, a
            ld l, c
            ld de, RT_BUF
            ld a, 1
            ld [$4000], a
            ld c, 8
.cm:        ld a, [de]
            cp [hl]
            jr nz, .ne
            inc hl
            cp [hl]
            jr nz, .ne
            inc hl
            inc e
            dec c
            jr nz, .cm
            xor a
            ld [$4000], a
            jr .out
.ne:        xor a
            ld [$4000], a
.wr:        pop de
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
            call bgsrc_inv                  ; (the page no longer as copied from ROM)
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
            push bc                         ; (still in ROM: into the shadow first)
            ld c, HLE_BANK
            ldh a, [sh_tile]
            call bg_mat
            pop bc
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
            ldh a, [sh_tile]                ; both planes (pf2_b: plane 0 the function whose
            ld c, a                         ;   bit i is bit 0 of index i's value, plane 1
            ld b, high(CODED)               ;   bit 1); pixels written since its last
            ld a, [bc]                      ;   coding (CODED $FF, A = 0): also the colour
            inc a                           ;   indices it uses (TILE_USE)
            call pf2_call
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
            jr nz, .wb
            ld a, [LON_ST]                  ; (LCD off: TBLK is SC_NP's second half: a
            cp 2                            ;   deferred scan in progress starts again)
            jr nz, .bk
            ld a, 1
            ld [LON_DIRTY], a
            jr .bk
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
            ld a, d                         ; attribute bytes: the shadows; the cells'
            ld hl, NT_SH + $3C0             ;   palettes from them when the screen shows
            ld c, 64                        ;   (DMG: the LCD-on scan; CGB: repal_b)
.c1:        ld [hl+], a
            dec c
            jr nz, .c1
            ld hl, NT_SH + $7C0
            ld c, 64
.c2:        ld [hl+], a
            dec c
            jr nz, .c2
            ld a, 1
            ld [CGB_RP], a
            ldh [dmg_scan], a
            ld a, $28                       ; v = $2800 (after 8 x 256 writes)
            ldh [ppu_vh], a
            xor a
            ldh [ppu_vl], a
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
.fill:      ld c, $3C                       ; HL: $3C0 bytes of D (16 per pass)
            ld a, d
.f1:        ld [hl+], a
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
            dec c
            jr nz, .f1
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
; in place (sprload_b; eight rows unrolled). Keeps nothing.
anf_rows:
            ld b, [hl]                      ; p0
            inc l
            ld c, [hl]                      ; p1
            ld a, b
            and c
            ld d, a                         ; p0 & p1
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
            ld b, [hl]                      ; p0
            inc l
            ld c, [hl]                      ; p1
            ld a, b
            and c
            ld d, a                         ; p0 & p1
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
            ld b, [hl]                      ; p0
            inc l
            ld c, [hl]                      ; p1
            ld a, b
            and c
            ld d, a                         ; p0 & p1
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
            ld b, [hl]                      ; p0
            inc l
            ld c, [hl]                      ; p1
            ld a, b
            and c
            ld d, a                         ; p0 & p1
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
            ld b, [hl]                      ; p0
            inc l
            ld c, [hl]                      ; p1
            ld a, b
            and c
            ld d, a                         ; p0 & p1
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
            ld b, [hl]                      ; p0
            inc l
            ld c, [hl]                      ; p1
            ld a, b
            and c
            ld d, a                         ; p0 & p1
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
            ld b, [hl]                      ; p0
            inc l
            ld c, [hl]                      ; p1
            ld a, b
            and c
            ld d, a                         ; p0 & p1
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
            ld b, [hl]                      ; p0
            inc l
            ld c, [hl]                      ; p1
            ld a, b
            and c
            ld d, a                         ; p0 & p1
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
            ret

; NES sprite tile o_t is not resident: take the next slot not used by this frame's
; sprites, load the tile from the shadow, return A = slot. Keeps BC, DE, HL.
spr_alloc:  push bc
            push de
            push hl
            ld b, 128
.find:      ldh a, [spr_next]
            inc a
            and $7F
            ldh [spr_next], a
            ld l, a
            ld h, high(SLOT_STAMP)
            set 7, l
            ldh a, [oam_frame]
            cp [hl]
            jr nz, .got
            dec b
            jr nz, .find
            ldh a, [spr_next]               ; all slots busy this frame: reuse anyway
            ld l, a
.got:       res 7, l                        ; L = slot
            ld h, high(SLOT_TILE)
            ld a, [hl]                      ; evict the old tile
            cp $FF
            jr z, .free
            push hl
            ld l, a
            ld h, high(SPR_SLOT)
            ld [hl], $FF
            pop hl
.free:      ldh a, [o_t]
            ld [hl], a                      ; SLOT_TILE[slot] = tile
            ld c, l
            ld l, a
            ld h, high(SPR_SLOT)
            ld [hl], c                      ; SPR_SLOT[tile] = slot
            call spr_load
            ld a, c
            pop hl
            pop de
            pop bc
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
.k6:        push bc                         ; (C = slot)
            push de                         ; (D / E: the planes' boolean functions)
            call blk_alloc                  ; DE = block
            ldh a, [o_t]                    ; (still in ROM: to the shadow first)
            call spr_mat
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
            pop bc                          ; B = plane 0's function, C = plane 1's: each
            push bc                         ;   plane coded from the shadow into the block by
            push hl                         ;   its own routine (pf_call: pf_0-pf_15)
            push de
            ld a, b
            call pf_call
            pop de
            pop hl
            pop bc
            inc e
            ld a, c
            call pf_call
            xor a
            ld [$4000], a
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

ntfill:     ld a, b
            or c
            ret z
            ldh a, [lcd_on]                 ; (LCD off, or a CGB masked load)
            and a
            jr z, .bk
            ld a, [VLCD]
            and a
            jr z, .lon
.bk:        ldh a, [ppu_ctrl]
            and 4
            jp nz, .col
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
.attr:      pop de                          ; attribute bytes: the shadow; the cells'
            ld a, h                         ;   palettes from it when the screen shows
            add a, high(NT_SH)              ;   (DMG: the LCD-on scan; CGB: repal_b)
            ld h, a
            ld e, 0                         ; (E: the bytes' differences, OR-ed)
            ld a, l                         ; n = min(count, 256 - L): up to L wrapping
            cpl
            inc a                           ; (256 - L; 0: 256)
            push bc
            inc b
            dec b
            jr nz, .an                      ; (count >= 256)
            and a
            jr z, .ac                       ; (256 - L = 256 > count)
            cp c
            jr c, .an
.ac:        ld a, c
.an:        ld b, a                         ; B = n (0: 256)
            ld c, a
.al:        ld a, [hl]
            xor d
            or e
            ld e, a
            ld [hl], d
            inc l
            dec b
            jr nz, .al
            ld a, c                         ; count -= n
            pop bc
            and a
            jr z, .a256
            ld h, a
            ld a, c
            sub h
            ld c, a
            jr nc, .ae
            dec b
            jr .ae
.a256:      dec b
.ae:        ld a, l                         ; v: offset L, or the next nametable at 0
            ldh [ppu_vl], a
            and a
            jr nz, .av
            ldh a, [ppu_vh]
            inc a
            and $3F
            ldh [ppu_vh], a
.av:        ld a, e
            and a
            jp z, ntfill
            ld a, 1
            ld [CGB_RP], a                  ; (CGB; on a DMG unused)
            ldh a, [is_cgb]
            and a
            jp nz, ntfill
            ld a, 1
            ldh [dmg_scan], a
            jp ntfill
.col:       ldh a, [own1_lo]                ; increment 32 (a column) in nametable 0, no
            ld h, a                         ;   cell owned by nametable 1: shadow and GB map
            ldh a, [own1_hi]                ;   cell by cell, up to the attributes
            or h
            jr nz, .one
            ldh a, [ppu_vh]
            cp $20
            jr c, .one
            cp $3F
            jr z, .one
            and 7
            cp 4
            jr nc, .one
            ld h, a
            ldh a, [ppu_vl]
            ld l, a
            push de
            ld e, 0                         ; (E: cells written)
.cl:        ld a, h
            cp 3
            jr c, .c1
            ld a, l
            cp $C0
            jr nc, .ce
.c1:        ld a, h
            add a, high(NT_SH)
            ld h, a
            ld [hl], d
            ld a, [VLCD]
            and a
            jr nz, .cv
            ld a, h
            sub high(NT_SH) - $98
            ld h, a
            ld [hl], d
            ld a, h
            sub $98
            jr .cn
.cv:        ld a, 1
            ld [MAP_RB], a
            ld a, h
            sub high(NT_SH)
.cn:        ld h, a
            inc e
            ld a, l
            add a, 32
            ld l, a
            jr nc, .cc
            inc h
.cc:        dec bc
            ld a, b
            or c
            jr nz, .cl
.ce:        ld a, l
            ldh [ppu_vl], a
            ldh a, [ppu_vh]
            and $FC
            or h
            ldh [ppu_vh], a
            ld a, e
            pop de
            and a
            jp z, .one
            ldh a, [is_cgb]
            and a
            jp nz, ntfill
            ld a, 1
            ldh [dmg_scan], a
            jp ntfill
.one:       ld a, d
            call rt_ppu_w7
            dec bc
            jr ntfill
.lon:       ld a, d                         ; LCD on, not masked: every byte through
            call rt_ppu_w7                  ;   rt_ppu_w7 (the state cannot become a bulk
            dec bc                          ;   case during these writes)
            ld a, b
            or c
            jr nz, .lon
            ret
.setm:      ld a, [VLCD]
            and a
            jr z, .set
            ld a, 1
            ld [MAP_RB], a
            ret
.set:       ld a, [NF_N]                    ; HL: NF_N bytes of D (8 at a time, then the
            ld c, a                         ;   rest)
            ld a, [NF_N + 1]
            ld b, a
            srl b
            rr c
            srl b
            rr c
            srl b
            rr c
            inc b
            ld a, c
            and a
            jr nz, .s8
            dec b
            jr z, .r
.s8:        ld a, d
.sl:        ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            dec c
            jr nz, .sl
            dec b
            jr nz, .sl
.r:         ld a, [NF_N]
            and 7
            ret z
            ld c, a
            ld a, d
.sr:        ld [hl+], a
            dec c
            jr nz, .sr
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
.fill:      ld a, d                         ; HL: 960 bytes of D (HL ends at +$3C0)
            ld c, 120
.f:         ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            dec c
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

; fix:E14D / E17F / E1A4 (window rows): X times STA $2007 of A. Out: X = 0; N = 0, Z = 1, carry,
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

; fix window rows (build.py: every LDA #L / STA $2007 / LDA #M / STA $2007 / DEX / BNE /
; LDA #R / STA $2007, entered at the first STA with A = L): L, X times M (X = 0: 256), R.
; LCD off (or a CGB masked load), increment 1, nametable 0, no cell drawn by nametable 1, all
; map cells: shadow and GB map at once; otherwise rt_ppu_w7 / ntfill. M and R from WROW3.
; Out: A = R, X = 0; N, Z from R; carry kept.
wrow3_b:    push af                         ; (carry)
            ldh [sh_l1], a                  ; L
            ld hl, WROW3
.f:         ld a, [hl+]
            cp $00
            jr z, .nf
            ld b, a
            ldh a, [sh_l1]
            cp b
            jr z, .fd
            inc hl
            inc hl
            jr .f
.nf:        ld b, 0                         ; (not in the table: cannot happen; plain STA)
            pop af
            ldh a, [sh_l1]
            jp rt_ppu_w7
.fd:        ld a, [hl+]
            ldh [sh_u2], a                  ; M
            ld a, [hl]
            ldh [sh_u3], a                  ; R
            ld b, 0
            ldh a, [lcd_on]                 ; (LCD off, or a CGB masked load)
            and a
            jr z, .lk
            ld a, [VLCD]
            cp 1
            jr nz, .gen
            ldh a, [dlg_on]
            and a
            jr nz, .gen
.lk:        ldh a, [ppu_ctrl]
            and 4
            jr nz, .gen
            ldh a, [own1_lo]
            ld h, a
            ldh a, [own1_hi]
            or h
            jr nz, .gen
            ldh a, [ppu_vh]
            cp $20
            jr c, .gen
            cp $3F
            jr z, .gen
            bit 2, a
            jr nz, .gen
            and 3
            ld h, a
            ldh a, [ppu_vl]
            ld l, a                         ; HL = the first cell's offset
            push hl
            ld a, e                         ; n = X + 2 (X = 0: 258)
            add a, 2
            ld c, a
            ld a, 0
            adc a, b
            ld b, a
            ld a, e
            and a
            jr nz, .n1
            inc b
.n1:        add hl, bc                      ; the end: within the map cells ($3C0)
            ld a, h
            cp 3
            jr c, .ok
            jr nz, .g1
            ld a, l
            cp $C1
            jr nc, .g1
.ok:        ld bc, 0
            pop hl
            push hl
            push de
            ld a, h
            add a, high(NT_SH)
            ld h, a
            call .row                       ; shadow
            pop de
            push de
            ld a, [VLCD]
            cp 1
            jr nz, .mp
            ld [MAP_RB], a                  ; (masked: the GB map rebuilt when shown)
            jr .md
.mp:        pop de
            pop hl
            push hl
            push de
            ld a, h
            add a, $98
            ld h, a
            call .row                       ; GB map
.md:        ld a, 1                         ; DMG: the map is scanned when the LCD goes on
            ldh [dmg_scan], a
            pop de                          ; (E = X)
            pop hl                          ; v = the end
            ld a, e
            add a, 2
            ld c, a
            ld a, 0
            adc a, 0
            ld b, a
            ld a, e
            and a
            jr nz, .n2
            inc b
.n2:        add hl, bc
            ld a, l
            ldh [ppu_vl], a
            ldh a, [ppu_vh]
            and $FC
            or h
            ldh [ppu_vh], a
            ld bc, 0
            jr .out
.g1:        pop hl
.gen:       ldh a, [code_bank]              ; (the PPU routines come back to code_bank)
            push af
            ld a, HLE_BANK
            ldh [code_bank], a
            ldh a, [sh_l1]
            call rt_ppu_w7
            ldh a, [sh_u2]
            ld d, a
            ld b, 0
            ld c, e
            ld a, c
            and a
            jr nz, .g2
            inc b
.g2:        push de
            call ntfill
            pop de
            ld d, 0
            ld bc, 0
            ldh a, [sh_u3]
            call rt_ppu_w7
            pop af
            ldh [code_bank], a
.out:       ld e, 0                         ; X = 0
            pop hl                          ; (L = the flags on entry: carry kept)
            ld a, l
            and $10
            ld l, a
            ldh a, [sh_u3]                  ; A = R; N, Z from it
            ldh [nzv], a
            and a
            jr nz, .nz
            set 7, l
.nz:        ld h, a
            push hl
            pop af
            ret
.row:       ldh a, [sh_l1]                  ; HL: L, E x M, R
            ld [hl+], a
            ldh a, [sh_u2]
.rm:        ld [hl+], a
            dec e
            jr nz, .rm
            ldh a, [sh_u3]
            ld [hl], a
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
.lp:        ldh a, [ppu_vh]                 ; v = $3F00 + index, increment 1 (as the game
            cp $3F                          ;   sets it): unchanged colours only counted, v
            jr nz, .sl                      ;   set before a changed one and at the end
            ldh a, [ppu_ctrl]
            and 4
            jr nz, .sl
            ldh a, [ppu_vl]
            cp c
            jr nz, .sl
.fl:        jp pu_fast                      ; (unrolled, pu_fast)
.fl0:       ld a, c
            cp 16
            jr nz, .fn
            ld hl, NES_RAM + $03D0
.fn:        ld a, [hl+]
            ld b, a                         ; B = the colour
            ld a, c                         ; PAL_SH index: $10/$14/$18/$1C -> $00/$04/...
            ld e, a
            and $13
            cp $10
            jr nz, .fm
            res 4, e
.fm:        ld d, high(PAL_SH)
            ld a, [de]
            xor b
            and $3F
            jr z, .fs
            ld a, b                         ; a changed colour: the shadow and its flags (as
            and $3F                         ;   rt_ppu_w7g's palette write; v set at the end)
            ld [de], a
            ld a, 1
            ldh [pal_dirty], a
            ldh [maps_due], a
            xor a
            ldh [pal_age], a
.fs:        inc c
            ld a, c
            cp 32
            jr c, .fl
            ldh [ppu_vl], a                 ; v = $3F20
            jr .x
.sl:        ld a, c
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
            jr c, .sl
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
; ---- far vclear (gb_layout.py VWF_SRC): VN * 8 bytes of VBUF cleared (256 when that is 0),
; VX = 0. Out: A = X = 0, Y kept; N = 0, Z = 1, C = 1.
vclear_b:   xor a
            ld [VW_VX], a
            ldh [nzv], a
            ld a, [VW_VN]                   ; (VN tiles of 8 rows: 8 bytes a pass; the NES
            and $1F                         ;   loop clears VN * 8 mod 256 bytes, 256 for 0:
            jr nz, .n0                      ;   32 passes)
            ld a, 32
.n0:        ld e, a
            ld hl, VW_BUF
            xor a
.l:
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            dec e
            jr nz, .l
            ld de, 0
            push af
            pop hl
            ld l, $90                       ; (Z, C)
            push hl
            pop af
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


; oamconv_b: NES sprite attribute (v h p - - - p p) -> GB OAM attribute (p v h - - p p p:
; priority, flips, CGB palette); OBP1 (DMG) added from the coding
section bank HLE_BANK, $7900
OATTR:
            db $00, $01, $02, $03, $00, $01, $02, $03, $00, $01, $02, $03, $00, $01, $02, $03
            db $00, $01, $02, $03, $00, $01, $02, $03, $00, $01, $02, $03, $00, $01, $02, $03
            db $80, $81, $82, $83, $80, $81, $82, $83, $80, $81, $82, $83, $80, $81, $82, $83
            db $80, $81, $82, $83, $80, $81, $82, $83, $80, $81, $82, $83, $80, $81, $82, $83
            db $20, $21, $22, $23, $20, $21, $22, $23, $20, $21, $22, $23, $20, $21, $22, $23
            db $20, $21, $22, $23, $20, $21, $22, $23, $20, $21, $22, $23, $20, $21, $22, $23
            db $A0, $A1, $A2, $A3, $A0, $A1, $A2, $A3, $A0, $A1, $A2, $A3, $A0, $A1, $A2, $A3
            db $A0, $A1, $A2, $A3, $A0, $A1, $A2, $A3, $A0, $A1, $A2, $A3, $A0, $A1, $A2, $A3
            db $40, $41, $42, $43, $40, $41, $42, $43, $40, $41, $42, $43, $40, $41, $42, $43
            db $40, $41, $42, $43, $40, $41, $42, $43, $40, $41, $42, $43, $40, $41, $42, $43
            db $C0, $C1, $C2, $C3, $C0, $C1, $C2, $C3, $C0, $C1, $C2, $C3, $C0, $C1, $C2, $C3
            db $C0, $C1, $C2, $C3, $C0, $C1, $C2, $C3, $C0, $C1, $C2, $C3, $C0, $C1, $C2, $C3
            db $60, $61, $62, $63, $60, $61, $62, $63, $60, $61, $62, $63, $60, $61, $62, $63
            db $60, $61, $62, $63, $60, $61, $62, $63, $60, $61, $62, $63, $60, $61, $62, $63
            db $E0, $E1, $E2, $E3, $E0, $E1, $E2, $E3, $E0, $E1, $E2, $E3, $E0, $E1, $E2, $E3
            db $E0, $E1, $E2, $E3, $E0, $E1, $E2, $E3, $E0, $E1, $E2, $E3, $E0, $E1, $E2, $E3

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
; DMG whole BG page copies (hle_chr_pages): BG_SRC[page] = the ROM bank and address it was
; last copied from; any other write to the page's shadow (dmg_markw, vtile_b) clears it.
; bgsrc: D = page, HL = the source (data_bank8 mapped) -> Z: the same as last time (the shadow
; holds these bytes; nothing to do), NZ: recorded now (copy it). Keeps BC, DE, HL.
section bank 0, $3FD0
bgsrc:      push bc
            push de
            ld a, 3
            ld [$4000], a
            ld a, d
            add a, a
            add a, a
            add a, low(BG_SRC)
            ld c, a
            ld b, high(BG_SRC)
            ldh a, [data_bank8]
            ld d, a
            ld a, [bc]
            xor d
            ld e, a
            ld a, d
            ld [bc], a
            inc c
            ld a, [bc]
            xor l
            or e
            ld e, a
            ld a, l
            ld [bc], a
            inc c
            ld a, [bc]
            xor h
            or e
            ld e, a
            ld a, h
            ld [bc], a
            xor a
            ld [$4000], a
            or e
            pop de
            pop bc
            ret

; bank PF_BANK routines through HL (hle_pfj)
section bank 0, $3EE3
hle_pfj:    push af                         ; HL = a routine in bank PF_BANK (stubs
            ld a, PF_BANK                   ;   the recompiler's pf: idioms: HL is
            ld [$2000], a                   ;   free at the recompiled code's calls)
            pop af
            call rt_jp_hl
            jp hle_back
hle_wrow3:  push af                         ; fix window rows: wrow3_b (bank HLE_BANK)
            ld a, HLE_BANK
            ld [$2000], a
            pop af
            call wrow3_b
            jp hle_back

; A = BG tile whose shadow bytes were written: its page's BG_SRC cleared. Keeps all registers.
section bank 0, $3DD8
bgsrc_inv:  call bg_lzclr                   ; (a whole tile written: no longer in ROM)
            push af
            push hl
            and $F0
            rrca
            rrca
            add a, low(BG_SRC)
            ld l, a
            ld h, high(BG_SRC)
            ld a, 3
            ld [$4000], a
            ld [hl], $FF
            xor a
            ld [$4000], a
            pop hl
            pop af
            ret
bgsrc_init: ld hl, BG_SRC                   ; (cart RAM bank 3 on) every page unknown
            ld a, $FF
            ld b, 64
.l:         ld [hl+], a
            dec b
            jr nz, .l
            ret

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
; ---- the DMG LCD-on map scan (dmg_scan_all), in PF_BANK
section bank PF_BANK, $4800
SC_NP      = $DE00          ; scan_b: palette each tile is drawn with ($FF: not used; the FRESH /
                            ;   TBLK area, free here: queue flushed, FRESH superseded)
scan_b:     push bc
            push de
            push hl
            call scb_init
            jr c, .done
            ld d, 0
.rw:        call scb_row
            inc d
            ld a, d
            cp 30
            jr nz, .rw
            call scb_fin
.done:      pop hl
            pop de
            pop bc
            ret
; scan_b in pieces (also run in the frame waits' spare time by lon_b): scb_init (carry: a
; one-palette screen, done), scb_row for rows D = 0-29, scb_fin
scb_init:   ld a, $FF
            ld [SC_TC], a
            ld a, 1
            ldh [sgb_dirty], a
            ldh [sgb_adirty], a
            xor a
            ldh [dmg_scan], a
            ld hl, REF_BM
            ld b, 4
.z:
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            dec b
            jr nz, .z
            ld hl, SC_NP                    ; (SC_NP: the palettes each tile is drawn with,
            ld b, 32                        ;   bit p; bit 7: the view's palette)
.f:
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
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
            ld b, a                         ; (as a palette bit)
            ld hl, NT_SH
            ld d, high(SC_NP)
            ld c, 60                        ; 960 cells, 16 per pass (a page in 16 passes;
.uc:                                        ;   A = the palette bit)
            ld e, [hl]
            ld [de], a
            inc l
            ld e, [hl]
            ld [de], a
            inc l
            ld e, [hl]
            ld [de], a
            inc l
            ld e, [hl]
            ld [de], a
            inc l
            ld e, [hl]
            ld [de], a
            inc l
            ld e, [hl]
            ld [de], a
            inc l
            ld e, [hl]
            ld [de], a
            inc l
            ld e, [hl]
            ld [de], a
            inc l
            ld e, [hl]
            ld [de], a
            inc l
            ld e, [hl]
            ld [de], a
            inc l
            ld e, [hl]
            ld [de], a
            inc l
            ld e, [hl]
            ld [de], a
            inc l
            ld e, [hl]
            ld [de], a
            inc l
            ld e, [hl]
            ld [de], a
            inc l
            ld e, [hl]
            ld [de], a
            inc l
            ld e, [hl]
            ld [de], a
            inc l
            jr nz, .uh
            inc h
.uh:        dec c
            jr nz, .uc
            ld a, [LON_ST]                  ; (lon_b: scb_settle as a step of its own)
            and a
            call z, scb_settle
            scf
            ret
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
            xor a
            ld [PAL_USED], a
            and a                           ; (carry clear: rows to scan)
            ret
scb_row:                                    ; row D: SC_NP |= its cells' palettes; the
.r:         ld a, [SC_VR]                   ;   view's rows: PAL_USED (view row: (D - VR)
            ld b, a                         ;   mod 30 < 18). In battle only the view's rows:
            ld a, d                         ;   a fixed camera and no scrolling, so the other
            sub b                           ;   rows never show (their tiles keep codings
            jr nc, .vd                      ;   nobody sees)
            add a, 30
.vd:        cp 18
            jr c, .vr
            ldh a, [in_battle]
            bit 7, a
            jr nz, .rn
            ld a, [LON_ST]                  ; (the deferred switch-on: the view's rows only;
            and a                           ;   the others go to FRESH afterwards: lon_frm)
            jr nz, .rn
            call scn_tab
            call scn_rowf
            jr .rn
.vr:        call scn_tab
            call scn_rowf
            call scn_pu
.rn:        ret
scb_fin:    ld hl, SC_NP                    ; a tile drawn with two palettes: bit 7, and the
            ld c, 0                         ;   view's cells decide (the last one; out of the
.cf:        ld a, [hl]                      ;   view: the lowest); C = how many
            ld b, a
            dec a
            and b
            jr z, .cn
            set 7, [hl]
            inc c
.cn:        inc l
            jr nz, .cf
            ld a, c
            and a
            call nz, scn_view
scb_settle: ld e, 0                         ; each tile used: REF_BM; drawn with another palette
.t:         ld l, e                         ;   than it is coded for: TILE_PAL, marked; the
            ld h, high(SC_NP)               ;   same palette but parked: marked again
            ld a, [hl]
            and $0F                         ; (palette bits -> palette: the view's, else
            jr z, .tn                       ;   the lowest)
            add a, low(SC_LOG)
            ld l, a
            ld h, high(SC_LOG)
            ld b, [hl]
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
            ld b, 32
.c:
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            dec b
            jr nz, .c
            ld [FR_ANY], a
            ld [FR_PEND], a
            ld [FR_AGE], a
            ld [FR_EMPTY], a
            ld [FR_POS], a
            ret

; scan_b, map row D: SC_TL / SC_TH (tile row offset, page of nametable 0) and SP_T[nt * 16
; + pair] = the palette of columns 2 * pair, + 1 in nametable nt. Keeps DE.
scn_tab:    push de                         ; SP_T entries as palette bits (SC_TBL: nibble ->
            ld a, d                         ;   bit of its low / high 2-bit field)
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
            ld a, d                         ; (rows 2k and 2k + 1 share their attribute
            srl a                           ;   quadrants: SP_T as for the row before;
            ld hl, SC_TC                    ;   SC_TC $FF from scb_init)
            cp [hl]
            jr nz, .new
            pop de
            ret
.new:       ld [hl], a
            ld a, d
            and $1C
            add a, a
            add a, $C0
            ld l, a
            ld bc, SP_T
            bit 1, d
            ld d, high(SC_TBL)
            jr nz, .s
            ld h, high(NT_SH) + 3
            push hl
            ld a, [hl+]
            and $0F
            ld e, a
            ld a, [de]
            ld [bc], a
            inc c
            inc d
            ld a, [de]
            ld [bc], a
            inc c
            dec d
            ld a, [hl+]
            and $0F
            ld e, a
            ld a, [de]
            ld [bc], a
            inc c
            inc d
            ld a, [de]
            ld [bc], a
            inc c
            dec d
            ld a, [hl+]
            and $0F
            ld e, a
            ld a, [de]
            ld [bc], a
            inc c
            inc d
            ld a, [de]
            ld [bc], a
            inc c
            dec d
            ld a, [hl+]
            and $0F
            ld e, a
            ld a, [de]
            ld [bc], a
            inc c
            inc d
            ld a, [de]
            ld [bc], a
            inc c
            dec d
            ld a, [hl+]
            and $0F
            ld e, a
            ld a, [de]
            ld [bc], a
            inc c
            inc d
            ld a, [de]
            ld [bc], a
            inc c
            dec d
            ld a, [hl+]
            and $0F
            ld e, a
            ld a, [de]
            ld [bc], a
            inc c
            inc d
            ld a, [de]
            ld [bc], a
            inc c
            dec d
            ld a, [hl+]
            and $0F
            ld e, a
            ld a, [de]
            ld [bc], a
            inc c
            inc d
            ld a, [de]
            ld [bc], a
            inc c
            dec d
            ld a, [hl+]
            and $0F
            ld e, a
            ld a, [de]
            ld [bc], a
            inc c
            inc d
            ld a, [de]
            ld [bc], a
            inc c
            dec d
            pop hl
            ld h, high(NT_SH) + 7
            ld a, [hl+]
            and $0F
            ld e, a
            ld a, [de]
            ld [bc], a
            inc c
            inc d
            ld a, [de]
            ld [bc], a
            inc c
            dec d
            ld a, [hl+]
            and $0F
            ld e, a
            ld a, [de]
            ld [bc], a
            inc c
            inc d
            ld a, [de]
            ld [bc], a
            inc c
            dec d
            ld a, [hl+]
            and $0F
            ld e, a
            ld a, [de]
            ld [bc], a
            inc c
            inc d
            ld a, [de]
            ld [bc], a
            inc c
            dec d
            ld a, [hl+]
            and $0F
            ld e, a
            ld a, [de]
            ld [bc], a
            inc c
            inc d
            ld a, [de]
            ld [bc], a
            inc c
            dec d
            ld a, [hl+]
            and $0F
            ld e, a
            ld a, [de]
            ld [bc], a
            inc c
            inc d
            ld a, [de]
            ld [bc], a
            inc c
            dec d
            ld a, [hl+]
            and $0F
            ld e, a
            ld a, [de]
            ld [bc], a
            inc c
            inc d
            ld a, [de]
            ld [bc], a
            inc c
            dec d
            ld a, [hl+]
            and $0F
            ld e, a
            ld a, [de]
            ld [bc], a
            inc c
            inc d
            ld a, [de]
            ld [bc], a
            inc c
            dec d
            ld a, [hl+]
            and $0F
            ld e, a
            ld a, [de]
            ld [bc], a
            inc c
            inc d
            ld a, [de]
            ld [bc], a
            inc c
            dec d
            pop de
            ret
.s:
            ld h, high(NT_SH) + 3
            push hl
            ld a, [hl+]
            swap a
            and $0F
            ld e, a
            ld a, [de]
            ld [bc], a
            inc c
            inc d
            ld a, [de]
            ld [bc], a
            inc c
            dec d
            ld a, [hl+]
            swap a
            and $0F
            ld e, a
            ld a, [de]
            ld [bc], a
            inc c
            inc d
            ld a, [de]
            ld [bc], a
            inc c
            dec d
            ld a, [hl+]
            swap a
            and $0F
            ld e, a
            ld a, [de]
            ld [bc], a
            inc c
            inc d
            ld a, [de]
            ld [bc], a
            inc c
            dec d
            ld a, [hl+]
            swap a
            and $0F
            ld e, a
            ld a, [de]
            ld [bc], a
            inc c
            inc d
            ld a, [de]
            ld [bc], a
            inc c
            dec d
            ld a, [hl+]
            swap a
            and $0F
            ld e, a
            ld a, [de]
            ld [bc], a
            inc c
            inc d
            ld a, [de]
            ld [bc], a
            inc c
            dec d
            ld a, [hl+]
            swap a
            and $0F
            ld e, a
            ld a, [de]
            ld [bc], a
            inc c
            inc d
            ld a, [de]
            ld [bc], a
            inc c
            dec d
            ld a, [hl+]
            swap a
            and $0F
            ld e, a
            ld a, [de]
            ld [bc], a
            inc c
            inc d
            ld a, [de]
            ld [bc], a
            inc c
            dec d
            ld a, [hl+]
            swap a
            and $0F
            ld e, a
            ld a, [de]
            ld [bc], a
            inc c
            inc d
            ld a, [de]
            ld [bc], a
            inc c
            dec d
            pop hl
            ld h, high(NT_SH) + 7
            ld a, [hl+]
            swap a
            and $0F
            ld e, a
            ld a, [de]
            ld [bc], a
            inc c
            inc d
            ld a, [de]
            ld [bc], a
            inc c
            dec d
            ld a, [hl+]
            swap a
            and $0F
            ld e, a
            ld a, [de]
            ld [bc], a
            inc c
            inc d
            ld a, [de]
            ld [bc], a
            inc c
            dec d
            ld a, [hl+]
            swap a
            and $0F
            ld e, a
            ld a, [de]
            ld [bc], a
            inc c
            inc d
            ld a, [de]
            ld [bc], a
            inc c
            dec d
            ld a, [hl+]
            swap a
            and $0F
            ld e, a
            ld a, [de]
            ld [bc], a
            inc c
            inc d
            ld a, [de]
            ld [bc], a
            inc c
            dec d
            ld a, [hl+]
            swap a
            and $0F
            ld e, a
            ld a, [de]
            ld [bc], a
            inc c
            inc d
            ld a, [de]
            ld [bc], a
            inc c
            dec d
            ld a, [hl+]
            swap a
            and $0F
            ld e, a
            ld a, [de]
            ld [bc], a
            inc c
            inc d
            ld a, [de]
            ld [bc], a
            inc c
            dec d
            ld a, [hl+]
            swap a
            and $0F
            ld e, a
            ld a, [de]
            ld [bc], a
            inc c
            inc d
            ld a, [de]
            ld [bc], a
            inc c
            dec d
            ld a, [hl+]
            swap a
            and $0F
            ld e, a
            ld a, [de]
            ld [bc], a
            inc c
            inc d
            ld a, [de]
            ld [bc], a
            inc c
            dec d
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
            dec a                           ; both nametables: cell by cell (C = owner bits;
            ld c, a                         ;   each pair's two palette bits fetched once)
            push de
            ld a, e
            srl a
            add a, low(SP_T)
            ldh [sh_l1], a                  ; (SP_T index of the group's first pair)
            ld a, [SC_TL]
            or e
            ld e, a                         ; E = the tiles' offset
            ld a, [SC_TH]
            ld d, a                         ; D = nametable 0's page (+ 4: nametable 1)
            ld b, 4
.mp:        ldh a, [sh_l1]
            ld l, a
            inc a
            ldh [sh_l1], a
            ld h, high(SP_T)
            ld a, [hl]
            ldh [sh_u2], a
            set 4, l
            ld a, [hl]
            ldh [sh_u3], a
            call .mc
            call .mc
            dec b
            jr nz, .mp
            pop de
            ld a, e
            add a, 8
            ld e, a
            jr .ng
.u0:        ld c, 0
            jr .uf
.u1:        ld c, 16
.uf:        push de
            ld a, e
            srl a
            add a, c
            add a, low(SP_T)
            ld b, a                         ; B = SP_T low
            ld a, [SC_TH]
            bit 4, c
            jr z, .p0
            add a, 4
.p0:        ld d, a
            ld a, [SC_TL]
            or e
            ld e, a                         ; DE = the tiles
            ld l, b
            ld h, high(SP_T)
            ld c, [hl]
            inc b
            ld h, high(SC_NP)
            ld a, [de]
            inc e
            ld l, a
            ld a, [hl]
            or c
            ld [hl], a
            ld a, [de]
            inc e
            ld l, a
            ld a, [hl]
            or c
            ld [hl], a
            ld l, b
            ld h, high(SP_T)
            ld c, [hl]
            inc b
            ld h, high(SC_NP)
            ld a, [de]
            inc e
            ld l, a
            ld a, [hl]
            or c
            ld [hl], a
            ld a, [de]
            inc e
            ld l, a
            ld a, [hl]
            or c
            ld [hl], a
            ld l, b
            ld h, high(SP_T)
            ld c, [hl]
            inc b
            ld h, high(SC_NP)
            ld a, [de]
            inc e
            ld l, a
            ld a, [hl]
            or c
            ld [hl], a
            ld a, [de]
            inc e
            ld l, a
            ld a, [hl]
            or c
            ld [hl], a
            ld l, b
            ld h, high(SP_T)
            ld c, [hl]
            inc b
            ld h, high(SC_NP)
            ld a, [de]
            inc e
            ld l, a
            ld a, [hl]
            or c
            ld [hl], a
            ld a, [de]
            inc e
            ld l, a
            ld a, [hl]
            or c
            ld [hl], a
            pop de
            ld a, e
            add a, 8
            ld e, a
.ng:        ld a, e
            cp 32
            jr nz, .g
            ret
.mc:        srl c                           ; one cell: SC_NP[tile] |= its palette bit
            ld a, d
            jr c, .m1
            ld h, a
            ld l, e
            ld l, [hl]
            ld h, high(SC_NP)
            ldh a, [sh_u2]
            or [hl]
            ld [hl], a
            inc e
            ret
.m1:        add a, 4
            ld h, a
            ld l, e
            ld l, [hl]
            ld h, high(SC_NP)
            ldh a, [sh_u3]
            or [hl]
            ld [hl], a
            inc e
            ret

; scan_b: the view's cells (18 rows from SC_VR, 20 columns from SC_VC): a tile marked with
; bit 7 (drawn with two palettes) gets $C0 | the palette bit of its last view cell (as
; scn_rowv did, where the last view cell won). Walked backwards: the first cell found decides
; (bit 6), and the walk ends once all C marked tiles are decided.
scn_view:   ld a, c
            ldh [sh_u2], a                  ; (tiles left to decide)
            ld a, [SC_VR]                   ; D = the view's last row, (VR + 17) mod 30
            add a, 17
            cp 30
            jr c, .r0
            sub 30
.r0:        ld d, a
            ld b, 18
.vr:        push bc
            ld a, d                         ; the row's tiles: offset (row & 7) * 32, page
            and 7
            swap a
            add a, a
            ldh [sh_l1], a
            ld a, d
            srl a
            srl a
            srl a
            add a, high(NT_SH)
            ldh [sh_l2], a
            ld a, [SC_VC]                   ; E = the view's last column, (VC + 19) mod 32
            add a, 19
            and 31
            ld e, a
            call .ob                        ; C: bit 7 = column E's owner
            ld b, 20
.vc:        sla c
            ldh a, [sh_l2]
            jr nc, .o0
            add a, 4
.o0:        ld h, a
            ldh a, [sh_l1]
            or e
            ld l, a
            ld l, [hl]                      ; the tile
            ld h, high(SC_NP)
            ld a, [hl]
            and $C0
            cp $80                          ; marked, not decided yet
            jr nz, .nd
            call .set
            ldh a, [sh_u2]
            dec a
            ldh [sh_u2], a
            jr z, .dn
.nd:        ld a, e
            dec a
            and 31
            ld e, a
            and 7
            cp 7
            call z, .ob
            dec b
            jr nz, .vc
            ld a, d
            sub 1
            jr nc, .vn
            ld a, 29
.vn:        ld d, a
            pop bc
            dec b
            jr nz, .vr
            ret
.dn:        pop bc
            ret
.ob:        ld a, d                         ; C = OWN[D * 4 + E / 8] << (7 - E & 7): bit 7 =
            add a, a                        ;   column E
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
            xor 7
            ret z
.sh:        sla c
            dec a
            jr nz, .sh
            ret
.set:       push hl                         ; HL = the tile's SC_NP: $C0 | the palette bit of
            push bc                         ;   cell (D, E) in the nametable that drew it
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
            and b                           ; NZ: nametable 1
            ld a, high(NT_SH) + 3
            jr z, .s0
            add a, 4
.s0:        ld h, a
            ld a, d                         ; attribute byte $3C0 + (D / 4) * 8 + E / 4
            and $1C
            add a, a
            add a, $C0
            ld l, a
            ld a, e
            srl a
            srl a
            add a, l
            ld l, a
            ld a, [hl]
            bit 1, d                        ; quadrant: bit 1 of D -> 4 bits, of E -> 2
            jr z, .s1
            swap a
.s1:        bit 1, e
            jr z, .s2
            rrca
            rrca
.s2:        and 3
            ld l, a
            ld h, high(NBIT60)
            ld a, [hl]
            or $C0
            pop bc
            pop hl
            ld [hl], a
            ret

; scan_b: view row D (scn_tab done), only when a tile is drawn with two palettes: its 20
; columns from SC_VC; a tile drawn with two palettes gets the view cell's ($80 | bit; the
; last view cell wins). Keeps D.
scn_rowv:   ld a, [SC_VC]
            ld e, a
            call scn_ob
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
            ld b, [hl]                      ; palette bit
            pop af
            ld l, a
            ld h, high(SC_NP)
            ld a, [hl]
            bit 7, a
            jr nz, .w
            and $0F
            push bc
            ld b, a
            dec a
            and b
            pop bc
            jr z, .nw
.w:         ld a, b
            or $80
            ld [hl], a
.nw:        ld a, c
            pop bc
            ld c, a
            ld a, e
            inc a
            and 31
            ld e, a
            and 7
            call z, scn_ob
            dec b
            jr nz, .c
            ret

; scan_b: view row D (scn_tab done): PAL_USED gets the palette of each of its 20 view
; cells (by owner). Keeps D.
scn_pu:     ld hl, SP_T                     ; (nothing new possible: all 32 pairs' palettes
            xor a                           ;   already in PAL_USED)
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
            inc l
            or [hl]
            inc l
            or [hl]
            inc l
            or [hl]
            inc l
            ld b, a
            ld a, [PAL_USED]
            cpl
            and b
            ret z
            ld a, [SC_VC]
            ld e, a
            call scn_ob
            xor a
            ldh [sh_u1], a
            ld b, 20
.c:         ld a, e
            srl a
            add a, low(SP_T)
            srl c
            jr nc, .o
            add a, 16
.o:         ld l, a
            ld h, high(SP_T)
            ldh a, [sh_u1]
            or [hl]
            ldh [sh_u1], a
            ld a, e
            inc a
            and 31
            ld e, a
            and 7
            call z, scn_ob
            dec b
            jr nz, .c
            ld hl, PAL_USED
            ldh a, [sh_u1]
            or [hl]
            ld [hl], a
            ret

; C = owner bits of map row D from column E on (bit 0: column E)
scn_ob:     ld a, d
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
            or [hl]
            ld [hl], a
            pop de
            ret

; recompute PAL_MAP from the NES BG palettes. A colour's value depends only on its
; brightness level, the same in every palette (a tile drawn with several palettes, such
; as the font, is then coded alike): 0 = the backdrop's level; the other levels present
; in the four BG palettes, darkest first, get 1 / 2 / 3, more than three levels being
; split into three groups at the two largest gaps between them. Tiles of palettes whose
; map changed are queued for re-coding. All colours black (faded out): nothing changes.
dmg_maps_b: push bc
            push de
            push hl
            ld hl, MPB                      ; (the palette to shade by: dmg_target)
            call bg_lmax_hl
            and a
            jp z, .x
            ld [REF_LMAX], a                ; brightness the BGP fade level is measured from
            ld a, [MPB]
            call lum
            ldh [sh_bk], a                  ; backdrop brightness
            ld hl, LVF                      ; levels present (other than the backdrop's)
            ld b, 9
            xor a
.cl:        ld [hl+], a
            dec b
            jr nz, .cl
            ld c, 0
.lv:        ld a, c
            and 3
            jr z, .mn
            ld a, [PAL_USED]                ; palettes no cell uses: their colours left out
            and a
            jr z, .lu
            ld b, a
            ld a, c
            srl a
            srl a
            inc a
.lb:        rr b
            dec a
            jr nz, .lb
            jr nc, .mn
.lu:
            ld a, c
            add a, low(MPB)
            ld l, a
            ld h, high(MPB)
            ld a, [hl]
            call lum
            ld b, a
            ldh a, [sh_bk]
            cp b
            jr z, .mn
            ld a, b
            add a, low(LVF)
            ld l, a
            ld h, high(LVF)
            ld [hl], 1
.mn:        inc c
            ld a, c
            cp 16
            jr nz, .lv
            ld e, 0                         ; LSL = the levels present, ascending; E = count
            ld c, 0
.ls:        ld a, c
            add a, low(LVF)
            ld l, a
            ld h, high(LVF)
            ld a, [hl]
            and a
            jr z, .ln
            ld a, e
            add a, low(LSL)
            ld l, a
            ld h, high(LSL)
            ld [hl], c
            inc e
.ln:        inc c
            ld a, c
            cp 9
            jr nz, .ls
            xor a                           ; cuts (group ends): sh_s0 < sh_s1
            ldh [sh_s0], a
            inc a
            ldh [sh_s1], a
            ld a, e
            cp 4
            jr c, .asg
            ld a, $FF
            call .maxgap
            ld d, a
            call .maxgap
            cp d
            jr nc, .ord
            ld b, a
            ld a, d
            ld d, b
.ord:       ldh [sh_s1], a
            ld a, d
            ldh [sh_s0], a
.asg:       ld a, e                         ; number of values in use
            cp 4
            jr c, .ng
            ld a, 3
.ng:        ld [NGRP], a
            ld c, 0
.as:        ld a, c
            cp e
            jr z, .pm
            ld b, 1                         ; value = 1 + (i > cut 0) + (i > cut 1)
            ldh a, [sh_s0]
            cp c
            jr nc, .a1
            inc b
.a1:        ldh a, [sh_s1]
            cp c
            jr nc, .a2
            inc b
.a2:        ld a, c
            add a, low(LSL)
            ld l, a
            ld h, high(LSL)
            ld a, [hl]                      ; level
            ld d, a
            add a, low(LVMAP)
            ld l, a
            ld h, high(LVMAP)
            ld [hl], b
            ld a, b                         ; GLUM[value] = its brightest level
            add a, low(GLUM)
            ld l, a
            ld [hl], d
            inc c
            jr .as
.pm:        xor a                           ; (sh_m0..3: indices changed per palette)
            ldh [sh_m0], a
            ldh [sh_m1], a
            ldh [sh_m2], a
            ldh [sh_m3], a
            ld c, 0                         ; palette
.p:         ld a, c
            add a, a
            add a, a
            add a, low(MPB)
            ld l, a
            ld h, high(MPB)
            ld de, RT_BUF
            xor a
            ld [de], a                      ; colour 0 -> 0
            inc de
            ld b, 3
            ldh [sh_chg], a                 ; (0: all three like the backdrop so far)
.pc:        inc l
            ld a, [hl]
            push hl
            call lum
            ld h, a
            ldh a, [sh_bk]
            cp h
            ld a, 0
            jr z, .pz
            ld a, h
            add a, low(LVMAP)
            ld l, a
            ld h, high(LVMAP)
            ld a, [hl]
            ld h, a
            ld a, 1
            ldh [sh_chg], a
            ld a, h
.pz:        pop hl
            ld [de], a
            inc de
            dec b
            jr nz, .pc
            ldh a, [sh_chg]                 ; a palette that is all backdrop keeps its map
            and a
            jr z, .nx
            ld a, c                         ; compare with PAL_MAP[c]; copy; mark if changed
            add a, a
            add a, a
            add a, low(PAL_MAP)
            ld l, a
            ld h, high(PAL_MAP)
            ld de, RT_BUF
            ld b, 4
            xor a
            ldh [sh_chg], a                 ; sh_chg: indices whose value changed (bit i)
            inc a
            ldh [sh_l1], a                  ; (bit of the index being compared)
.cmp:       ld a, [de]
            cp [hl]
            jr z, .same
            ld [hl], a
            push bc
            ldh a, [sh_l1]
            ld b, a
            ldh a, [sh_chg]
            or b
            ldh [sh_chg], a
            pop bc
.same:      ldh a, [sh_l1]
            add a, a
            ldh [sh_l1], a
            inc de
            inc hl
            dec b
            jr nz, .cmp
            ldh a, [sh_chg]
            and a
            jr z, .nx
            push bc
            ld b, a
            ld a, c
            add a, low(sh_m0)
            ld c, a
            ld a, b
            ldh [c], a
            pop bc
.nx:        inc c
            ld a, c
            cp 4
            jp nz, .p
            ldh a, [sh_m0]
            ld b, a
            ldh a, [sh_m1]
            or b
            ld b, a
            ldh a, [sh_m2]
            or b
            ld b, a
            ldh a, [sh_m3]
            or b
            call nz, .markp
            call spr_maps
.x:         pop hl
            pop de
            pop bc
            ret
.maxgap:    ; A = gap index to skip -> A = index i of the largest LSL[i+1] - LSL[i]
            ldh [sh_l1], a                  ;   (the first one of equal gaps); keeps D, E
            xor a
            ldh [sh_l2], a
            ldh [sh_l3], a
            ld c, 0
.mg:        ld a, c
            inc a
            cp e
            jr nc, .mgx
            ldh a, [sh_l1]
            cp c
            jr z, .mgn
            ld a, c
            add a, low(LSL)
            ld l, a
            ld h, high(LSL)
            ld a, [hl+]
            ld b, a
            ld a, [hl]
            sub b
            ld b, a
            ldh a, [sh_l2]
            cp b
            jr nc, .mgn
            ld a, b
            ldh [sh_l2], a
            ld a, c
            ldh [sh_l3], a
.mgn:       inc c
            jr .mg
.mgx:       ldh a, [sh_l3]
            ret
.markp:     ; one pass: queue every tile whose palette's changed indices (sh_m0..3) meet
            ld hl, TILE_PAL                 ;   the indices it uses (TILE_USE); eight tiles'
            ld de, TILE_USE                 ;   bits gathered in B, then marked at once (as
.mb:                                        ;   dmg_mark: DIRTY_BM set, DEFER_BM cleared)
            ld a, [hl]                      ; even tile: low nibble
            cp 4
            jr nc, .r00                   ;   (no palette: carry clear)
            add a, low(sh_m0)
            ld c, a
            ldh a, [c]
            ld c, a
            ld a, [de]
            and c
            and $0F
            add a, $FF                      ; carry: a changed index it uses
.r00:     rr b
            inc l
            ld a, [hl]                      ; odd tile: high nibble
            cp 4
            jr nc, .r10
            add a, low(sh_m0)
            ld c, a
            ldh a, [c]
            swap a
            ld c, a
            ld a, [de]
            and c
            and $F0
            add a, $FF
.r10:     rr b
            inc l
            inc e
            ld a, [hl]                      ; even tile: low nibble
            cp 4
            jr nc, .r01                   ;   (no palette: carry clear)
            add a, low(sh_m0)
            ld c, a
            ldh a, [c]
            ld c, a
            ld a, [de]
            and c
            and $0F
            add a, $FF                      ; carry: a changed index it uses
.r01:     rr b
            inc l
            ld a, [hl]                      ; odd tile: high nibble
            cp 4
            jr nc, .r11
            add a, low(sh_m0)
            ld c, a
            ldh a, [c]
            swap a
            ld c, a
            ld a, [de]
            and c
            and $F0
            add a, $FF
.r11:     rr b
            inc l
            inc e
            ld a, [hl]                      ; even tile: low nibble
            cp 4
            jr nc, .r02                   ;   (no palette: carry clear)
            add a, low(sh_m0)
            ld c, a
            ldh a, [c]
            ld c, a
            ld a, [de]
            and c
            and $0F
            add a, $FF                      ; carry: a changed index it uses
.r02:     rr b
            inc l
            ld a, [hl]                      ; odd tile: high nibble
            cp 4
            jr nc, .r12
            add a, low(sh_m0)
            ld c, a
            ldh a, [c]
            swap a
            ld c, a
            ld a, [de]
            and c
            and $F0
            add a, $FF
.r12:     rr b
            inc l
            inc e
            ld a, [hl]                      ; even tile: low nibble
            cp 4
            jr nc, .r03                   ;   (no palette: carry clear)
            add a, low(sh_m0)
            ld c, a
            ldh a, [c]
            ld c, a
            ld a, [de]
            and c
            and $0F
            add a, $FF                      ; carry: a changed index it uses
.r03:     rr b
            inc l
            ld a, [hl]                      ; odd tile: high nibble
            cp 4
            jr nc, .r13
            add a, low(sh_m0)
            ld c, a
            ldh a, [c]
            swap a
            ld c, a
            ld a, [de]
            and c
            and $F0
            add a, $FF
.r13:     rr b
            inc l
            inc e
            ld a, b
            and a
            jr z, .mq
            push hl
            dec l                           ; HL = the DIRTY_BM byte of these eight
            ld a, l
            rrca
            rrca
            rrca
            and $1F
            ld l, a
            ld h, high(DIRTY_BM)
            ld a, [hl]
            or b
            ld [hl], a
            ld a, l
            add a, low(DEFER_BM) - low(DIRTY_BM)
            ld l, a
            ld a, b
            cpl
            and [hl]
            ld [hl], a
            ld a, 1
            ldh [rq_any], a
            pop hl
.mq:        ld a, l
            and a
            jp nz, .mb
            ret

; BGP: value 0 = the backdrop's shade. Over a black backdrop, values 1-3 get dark grey /
; light grey / white (two values: dark grey / white); otherwise each value the shade of its
; brightest level. Darkened while the palettes are faded: one shade per two brightness
; levels the brightest BG colour is below REF_LMAX (its level when the maps were last
; computed). Returns A = BGP.

; ---- retile_b: tile HL (shadow, RAM bank 1 on) coded into DE (plane 0 by sh_s0, plane 1 by
; sh_s1); A = 0: its TILE_USE nibble too (colour indices 1-3 used). Keeps nothing.
TU_SP      = $DCDA          ; (2) pf2_b: SP saved while the tile is read with POP
pf2_b:      push af
            push hl
            push de
            ldh a, [sh_s0]
            call .pf
            pop de
            pop hl
            push hl
            inc e
            ldh a, [sh_s1]
            call .pf
            pop hl
            pop af
            and a
            ret nz
.use:       ld [TU_SP], sp                  ; rows by POP (p0 in E, p1 in D), interrupts off:
            di                              ;   B |= p0 & ~p1, C |= p1 & ~p0, H |= p0 & p1
            ld sp, hl
            ld bc, 0
            ld h, b
            pop de
            ld a, e
            and d
            ld l, a
            or h
            ld h, a
            ld a, l
            xor e
            or b
            ld b, a
            ld a, l
            xor d
            or c
            ld c, a
            pop de
            ld a, e
            and d
            ld l, a
            or h
            ld h, a
            ld a, l
            xor e
            or b
            ld b, a
            ld a, l
            xor d
            or c
            ld c, a
            pop de
            ld a, e
            and d
            ld l, a
            or h
            ld h, a
            ld a, l
            xor e
            or b
            ld b, a
            ld a, l
            xor d
            or c
            ld c, a
            pop de
            ld a, e
            and d
            ld l, a
            or h
            ld h, a
            ld a, l
            xor e
            or b
            ld b, a
            ld a, l
            xor d
            or c
            ld c, a
            pop de
            ld a, e
            and d
            ld l, a
            or h
            ld h, a
            ld a, l
            xor e
            or b
            ld b, a
            ld a, l
            xor d
            or c
            ld c, a
            pop de
            ld a, e
            and d
            ld l, a
            or h
            ld h, a
            ld a, l
            xor e
            or b
            ld b, a
            ld a, l
            xor d
            or c
            ld c, a
            pop de
            ld a, e
            and d
            ld l, a
            or h
            ld h, a
            ld a, l
            xor e
            or b
            ld b, a
            ld a, l
            xor d
            or c
            ld c, a
            pop de
            ld a, e
            and d
            ld l, a
            or h
            ld h, a
            ld a, l
            xor e
            or b
            ld b, a
            ld a, l
            xor d
            or c
            ld c, a
            ld a, [TU_SP]
            ld l, a
            ld a, [TU_SP + 1]
            ld d, h
            ld h, a
            ld sp, hl
            ei
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
.pf:        push hl                         ; plane function A (pf_tab), HL / DE kept for it
            add a, a
            ld l, a
            ld h, high(pf_tab)
            ld a, [hl+]
            ld b, [hl]
            ld c, a
            pop hl
            push bc
            ret

dmg_target_b: push de
            push hl
            ldh a, [pro_mode]               ; the prologue: palettes 1-3 as palette 3 (its
            and a                           ;   shown lines: the text white on black; lines
            jr z, .np                       ;   appear as drawn, the page fades by the BGP)
            ld hl, PAL_SH
            ld de, MPB
            ld b, 0
            ld c, 0
.pp:        ld a, c
            cp 4
            ld a, c
            jr c, .p0
            and 3
            add a, 12
.p0:        add a, low(PAL_SH)
            ld l, a
            ld a, [de]
            cp [hl]
            jr z, .ps
            ld b, 1
            ld a, [hl]
            ld [de], a
.ps:        inc e
            inc c
            ld a, c
            cp 16
            jr nz, .pp
            pop hl
            pop de
            scf
            ret
.np:        ldh a, [in_battle]
            and a
            ld hl, NES_RAM + $3C0
            jr z, .t
            ld hl, $AD34                    ; ($6D34, cart RAM bank 0)
.t:         push hl
            ld de, PAL_SH
            ld b, 16
            ld c, 0                         ; C = target colours that are not black
.ck:        ld a, e
            and 3
            jr nz, .c1
            ld a, e
            and a
            jr nz, .nx                      ; (colour 0 of palettes 1-3: the backdrop)
.c1:        ld a, [hl]
            and $3F
            call .blk
            jr z, .tb
            inc c
.tb:        push bc
            ld a, [hl]
            and $3F
            ld c, a                         ; C = target colour
            ld a, [de]
            and $3F
            ld b, a                         ; B = live colour
            cp c
            jr z, .ok
            call .blk
            jr z, .ok                       ; (black)
            xor c
            and $0F
            jr nz, .bad                     ; another hue
            ld a, b
            cp c
            jr nc, .bad                     ; brighter
.ok:        pop bc
.nx:        inc hl
            inc e
            dec b
            jr nz, .ck
            pop hl                          ; a fade of the target (if it is not all black)
            ld a, c
            and a
            jr z, .live
            scf
            jr .cp
.bad:       pop bc
            pop hl
.live:      ld hl, PAL_SH
            and a                           ; (carry clear)
.cp:        push af
            ld de, MPB
            ld c, 16
            ld b, 0
.cl:        ld a, [de]
            cp [hl]
            jr z, .cs
            ld b, 1
            ld a, [hl]
            ld [de], a
.cs:        inc hl
            inc e
            dec c
            jr nz, .cl
            pop af
            pop hl
            pop de
            ret
.blk:       cp $0F                          ; Z: an NES black (x0F, or xD-xF)
            ret z
            push af
            and $0F
            cp $0D
            jr c, .nb
            pop af
            cp a
            ret
.nb:        pop af
            or 1                            ; (NZ)
            ret

; DMG sprites: two fixed OBJ palettes, OBP0 = black / dark grey / white and OBP1 = dark
; grey / light grey / white (values 1 / 2 / 3). Each NES sprite palette takes OBP0 if one
; of its colours is black, else OBP1, and codes its indices by their shades (SPAL_KEY);
; the sprite slots are loaded again with that coding when the OAM is converted.
spr_maps:   push bc
            push de
            push hl
            ld c, 0
.p:         ld a, c
            add a, a
            add a, a
            add a, low(PAL_SH) + $11
            ld l, a
            ld h, high(PAL_SH)
            ld de, RT_BUF + 8               ; shades of indices 1-3; D... flags black
            ld b, 3
.i:         ld a, [hl+]
            call lum
            call lum_shade
            ld [de], a
            inc de
            dec b
            jr nz, .i
            ld hl, RT_BUF + 8               ; any black (3)? -> OBP0 table, else OBP1
            ld de, SPR_VAL_B
            ld b, 3
.bk:        ld a, [hl+]
            cp 3
            jr nz, .bn
            ld de, SPR_VAL_A
.bn:        dec b
            jr nz, .bk
            ld hl, RT_BUF + 10              ; key = v1 | v2 << 2 | v3 << 4 (+ $40: OBP1)
            ld b, 0
            ld a, 3
.kv:        push af
            ld a, [hl-]
            push de
            add a, e
            ld e, a
            jr nc, .kc
            inc d
.kc:        ld a, [de]
            pop de
            sla b
            sla b
            or b
            ld b, a
            pop af
            dec a
            jr nz, .kv
            ld a, e                         ; OBP1 table: bit 6
            cp low(SPR_VAL_B)
            jr nz, .ka
            ld a, d
            cp high(SPR_VAL_B)
            jr nz, .ka
            set 6, b
.ka:        ld a, c
            add a, low(SPAL_KEY)
            ld l, a
            ld h, high(SPAL_KEY)
            ld [hl], b
            inc c
            ld a, c
            cp 4
            jr nz, .p
            pop hl
            pop de
            pop bc
            ret
SPR_VAL_A:  db 3, 2, 2, 1                   ; shade (white .. black) -> value, OBP0
SPR_VAL_B:  db 3, 2, 1, 1                   ;   OBP1


; ---- DMG, LCD off (rt_ppu_w1 turning it on): the marked tiles re-coded straight into VRAM
; in one pass. A = 0: every marked tile (dmg_retile_some 0); A = 1: those the map uses
; (REF_BM), the others parked in DEFER_BM (dmg_retile_ref); A = 2: those the map uses, the
; others left marked (re-coded in the frame waits' spare time: the prologue). The same codings, keys
; (CODED) and TILE_USE as retile_b.
RB_S       = $DC30          ; (RT_BUF) per palette: S0 = indices whose value has bit 0 (4), S1 (4)
rtb_b:      ldh [sh_u3], a
            ld hl, PAL_MAP                  ; S0 / S1 of the four palettes
            ld c, 0
.pp:        ld de, $0001                    ; D = S0, E = bit
            ld b, 0                         ; B = S1
.pi:        ld a, [hl+]
            rrca
            jr nc, .p0
            push af
            ld a, d
            or e
            ld d, a
            pop af
.p0:        rrca
            jr nc, .p1
            ld a, b
            or e
            ld b, a
.p1:        sla e
            bit 4, e
            jr z, .pi
            push hl
            ld a, c
            add a, low(RB_S)
            ld l, a
            ld h, high(RB_S)
            ld [hl], d
            ld a, l
            add a, 4
            ld l, a
            ld [hl], b
            pop hl
            inc c
            ld a, c
            cp 4
            jr nz, .pp
            ld e, 0                         ; bitmap byte
.byte:      ld l, e
            ld h, high(DIRTY_BM)
            ld a, [hl]
            and a
            jr z, .nb
            ld [hl], 0
            ld d, a
            ldh a, [sh_u3]
            and a
            jr z, .all
            ld a, e                         ; (the map's tiles; the others parked, or with
            add a, low(REF_BM)              ;   A = 2 left marked for the frame waits' spare
            ld l, a                         ;   time)
            ld h, high(REF_BM)
            ld b, [hl]
            ld a, b
            cpl
            and d
            jr z, .np
            ld c, a
            ldh a, [sh_u3]
            cp 2
            jr z, .kp
            ld a, e
            add a, low(DEFER_BM)
            ld l, a
            ld h, high(DEFER_BM)
            ld a, c
            or [hl]
            ld [hl], a
            jr .np
.kp:        ld l, e
            ld h, high(DIRTY_BM)
            ld [hl], c
.np:        ld a, d
            and b
            ld d, a
.all:       ld a, e
            add a, a
            add a, a
            add a, a
            ld c, a                         ; C = tile of bit 0
.bit:       srl d
            jr nc, .bn
            push bc
            push de
            ld a, c
            call .one
            pop de
            pop bc
.bn:        inc c
            ld a, d
            and a
            jr nz, .bit
.nb:        ld a, [LON_LIM]                 ; (lon_b: stop when the frame's time is up;
            and a                           ;   the bytes done are clear)
            jr z, .nl
            call lon_time
            jr c, .early
.nl:        inc e
            ld a, e
            cp 32
            jr nz, .byte
            ldh a, [sh_u3]                  ; (A = 2: tiles may be left marked)
            cp 2
            ld a, 1
            jr z, .rq
            xor a
.rq:        ldh [rq_any], a
            ret
.early:     ld a, 1
            ldh [rq_any], a
            ret
.one:       ldh [sh_tile], a                ; tile A
            push bc                         ; (still in ROM: into the shadow first)
            ld c, PF_BANK
            call bg_mat
            pop bc
            swap a                          ; HL = shadow tile (RAM bank 1)
            ld l, a
            and $0F
            add a, high(BG_SHADOW)
            ld h, a
            ld a, l
            and $F0
            ld l, a
            ld a, 1
            ld [$4000], a
            ldh a, [sh_tile]
            ld e, a
            ld d, high(CODED)
            ld a, [de]
            inc a
            jr nz, .k
            push hl                         ; written since its last coding: TILE_USE first
            xor a
            call pf2_b.use
            pop hl
.k:         ldh a, [sh_tile]                ; key = (u & S1) << 4 | (u & S0), u = TILE_USE | 1
            ld e, a
            ld d, high(TILE_PAL)
            ld a, [de]
            add a, low(RB_S)
            ld c, a
            ld b, high(RB_S)
            ld a, [bc]
            ldh [sh_s0], a
            ld a, c
            add a, 4
            ld c, a
            ld a, [bc]
            ldh [sh_s1], a
            ld a, e
            srl a
            add a, low(TILE_USE)
            ld c, a
            ld b, high(TILE_USE)
            ld a, [bc]
            bit 0, e
            jr z, .lo
            swap a
.lo:        and $0F
            or 1
            ld b, a
            ldh a, [sh_s1]
            and b
            swap a
            ld c, a
            ldh a, [sh_s0]
            and b
            or c
            ld d, high(CODED)
            ld b, a                         ; B = key
            ld a, [de]
            cp b
            jr z, .done
            ld a, b
            ld [de], a
            ld a, e                         ; DE = VRAM tile ($9000 + t * 16 for 0-127,
            swap a                          ;   $8000 + t * 16 above)
            ld c, a
            and $0F
            bit 7, e
            jr nz, .hi
            add a, $90
            jr .dd
.hi:        add a, $80
.dd:        ld d, a
            ld a, c
            and $F0
            ld e, a
            push hl
            push de
            ldh a, [sh_s0]
            call pf2_b.pf
            pop de
            pop hl
            inc e
            ldh a, [sh_s1]
            call pf2_b.pf
.done:      xor a
            ld [$4000], a
            ret

; CGB masked load shown (rt_ppu_w1): the GB map and the cell palettes deferred while masked.
; With every cell drawn by nametable 0 (own1 = 0): the map is its shadow (NT_SH, WRAM bank 1)
; and the palettes are expanded from its attribute bytes into WRAM bank 4 $D000; both go to
; VRAM by general-purpose DMA in a vblank (interrupts off; a second vblank if the first has
; no room left). Cells of both nametables: vshow_own.
; end of a CGB masked load's show (interrupts off, in the vblank, after the DMA): VLCD 2.
; This vblank's handler runs late (after the DMA), so when it would unmask (no queued write,
; no tile copy pending, no dialogue window) the window mask is lifted here for the top lines
; of the next frame, LCDC as vbl_regs sets it.
vshow_unm:  ld a, 2
            ld [VLCD], a
            ldh a, [hd_any]
            and a
            ret nz
            ldh a, [q_head]
            ld b, a
            ldh a, [q_tail]
            cp b
            ret nz
            ldh a, [dlg_l]
            and a
            ret nz
            ld a, [BAND_LIFE]               ; (a band reveal: its raster events from vbl_regs,
            and a                           ;   the window mask kept meanwhile)
            ret nz
            xor a                           ; (shown now: VLCD 0, so writes made before the
            ld [VLCD], a                    ;   next vblank do not mask it again)
            ld b, LCDC_ON & %11111101
            ldh a, [ppu_mask]
            bit 4, a
            jr z, .ns
            set 1, b
.ns:        ld a, b
            ldh [$FF40], a
            ret
vshow_def:  ld a, [VSHOW_P]                 ; (every CGB frame wait) a show pending: below;
            and a                           ;   else, masked: vshow_own's buffer built ahead
            jr nz, .sh0
            ld a, [VLCD]
            cp 1
            ret nz
            jp vpre
.sh0:       xor a                           ; VSHOW_P: rendering still on: shown,
            ld [VSHOW_P], a                 ;   unmasked in the vblank (VLCD 2); else masked.
            ldh a, [ppu_mask]               ;   Keeps BC, DE, HL (the NES's X / Y)
            and $18
            ret z
            ld a, [MAP_RB]                  ; nothing to rebuild: unmasked by vbl_regs (VLCD 2)
            and a
            jr nz, .sh
            ld a, [CGB_RP]
            and a
            jr nz, .sh
            ld a, 2
            ld [VLCD], a
            ret
.sh:        push bc                         ; else VLCD set at the end of the DMA (vshow_unm:
            push de                         ;   not before it, so no vblank handler unmasks
            push hl                         ;   the old map)
            call vshow_b
            pop hl
            pop de
            pop bc
            ret
vshow_b:    ld a, [MAP_RB]
            ld b, a
            ld a, [CGB_RP]
            or b
            ret z
            ldh a, [own1_lo]
            ld b, a
            ldh a, [own1_hi]
            or b
            jp nz, vshow_own                ; (cells of both nametables: by owner)
.g:         ldh a, [q_head]                 ; queued writes first (no queued cell after these)
            ld b, a
            ldh a, [q_tail]
            cp b
            jr z, .qe
            call q_drain1
            jr .g
.qe:        ld a, [CGB_RP]
            and a
            call nz, .pal
            di
            ld a, [MAP_RB]
            and a
            jr z, .np
            call .vb                        ; map: NT_SH $D000 (bank 1) -> $9800, 60 x 16
            ld a, $D0
            ldh [$FF51], a
            xor a
            ldh [$FF52], a
            ld a, $18
            ldh [$FF53], a
            xor a
            ldh [$FF54], a
            ld a, 59
            ldh [$FF55], a
            xor a
            ld [MAP_RB], a
.np:        ld a, [CGB_RP]
            and a
            jr z, .x
            ldh a, [$FF44]                  ; (in a vblank with room left, else the next)
            cp 144
            jr c, .wt
            cp 149
            jr c, .go
.wt:        call .vb
.go:        ld a, 4                         ; palettes: bank 4 $D000 -> VRAM bank 1 $9800
            ldh [$FF70], a
            ld a, 1
            ldh [$FF4F], a
            ld a, $D0
            ldh [$FF51], a
            xor a
            ldh [$FF52], a
            ld a, $18
            ldh [$FF53], a
            xor a
            ldh [$FF54], a
            ld a, 59
            ldh [$FF55], a
            xor a
            ldh [$FF4F], a
            ld [CGB_RP], a
            inc a
            ldh [$FF70], a
.x:         call vshow_unm
            ei
            ret
.vb:        ldh a, [$FF44]                  ; in a vblank with room (LY 144-146): now;
            cp 144                          ;   else wait for the next one
            jr c, .v1
            cp 147
            ret c
.v0:        ldh a, [$FF44]
            cp 144
            jr nc, .v0
.v1:        ldh a, [$FF44]
            cp 144
            jr nz, .v1
            ret
.pal:       ld de, 0                        ; D = attribute index (0-63), E = (scratch)
.pa:        ld a, d                         ; value (NT_SH $3C0 + i, bank 1)
            add a, $C0
            ld l, a
            ld h, high(NT_SH) + 3
            ld c, [hl]
            ld a, d                         ; HL = $D000 + row0 * 32 + col0 (bank 4)
            and $38                         ;   row0 = (i >> 3) * 4, col0 = (i & 7) * 4
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl                      ; (i & $38) * 16 = row0 * 32
            ld a, d
            and 7
            add a, a
            add a, a
            add a, l
            ld l, a
            ld a, h
            add a, $D0
            ld h, a
            ld a, 4
            ldh [$FF70], a
            ld b, 2                         ; top half (quadrants 0 / 1), then bottom (2 / 3)
.hf:        ld a, c
            and 3
            ld e, a                         ; left
            ld a, c
            rrca
            rrca
            and 3                           ; right
            push bc
            ld b, a
            ld c, 2                         ; two rows
.rw:        ld a, h                         ; (rows 30-31: none)
            cp $D3
            jr nz, .w
            ld a, l
            cp $C0
            jr nc, .sk
.w:         ld a, e
            ld [hl+], a
            ld [hl+], a
            ld a, b
            ld [hl+], a
            ld [hl+], a
            ld a, l
            add a, 28
            ld l, a
            jr nc, .nc
            inc h
.nc:        dec c
            jr nz, .rw
.sk:        pop bc
            ld a, c
            swap a
            ld c, a
            dec b
            jr nz, .hf
            ld a, 1
            ldh [$FF70], a
            inc d
            ld a, d
            cp 64
            jr nz, .pa
            ret

; vshow_b with cells of both nametables: GB map (by owner) to WRAM bank 4 $D000, cell
; palettes to $D400, eight cells at a time (read in bank 1, kept on the stack, written in
; bank 4); then both by general-purpose DMA in a vblank
vshow_own:  ldh a, [q_head]                 ; queued writes first
            ld b, a
            ldh a, [q_tail]
            cp b
            jr z, .qe
            call q_drain1
            jr vshow_own
.qe:        call vo_first                   ; B = the first row still to build (a build
            xor a                           ;   ahead in the masked frame waits: vpre)
            ldh [sh_l2], a                  ; (no time limit)
            call vo_rows
            xor a
            ld [MAP_RB], a
            ld [CGB_RP], a
            di
            call vshow_b.vb
            ld a, 4
            ldh [$FF70], a
            ld a, $D0                       ; map: bank 4 $D000 -> $9800
            ldh [$FF51], a
            xor a
            ldh [$FF52], a
            ld a, $18
            ldh [$FF53], a
            xor a
            ldh [$FF54], a
            ld a, 59
            ldh [$FF55], a
            ldh a, [$FF44]                  ; (in a vblank with room left, else the next)
            cp 144
            jr c, .wt
            cp 149
            jr c, .go
.wt:        call vshow_b.vb
.go:        ld a, 1                         ; palettes: bank 4 $D400 -> VRAM bank 1 $9800
            ldh [$FF4F], a
            ld a, $D4
            ldh [$FF51], a
            xor a
            ldh [$FF52], a
            ld a, $18
            ldh [$FF53], a
            xor a
            ldh [$FF54], a
            ld a, 59
            ldh [$FF55], a
            xor a
            ldh [$FF4F], a
            inc a
            ldh [$FF70], a
            call vshow_unm
            ei
            ret

; vshow_own's rows B..29 (map by owner -> WRAM bank 4 $D000, cell palettes -> $D400). sh_l2
; non-zero: stop before the vblank (a vblank since the frame wait began, or LY 136-143).
; Out: B = the next row.
vo_rows:
.row:       ld a, b
            cp 30
            ret z
            ldh a, [sh_l2]
            and a
            jr z, .go
            ld a, [VBL_CNT]
            ld c, a
            ld a, [VBL_ENT]
            cp c
            ret nz
            ldh a, [$FF44]
            cp 136
            jr c, .go
            cp 144
            ret c
.go:        ld c, 0                         ; group (0-3)
.grp:       push bc
            ld a, b                         ; palettes of the group's four pairs, both
            and $1C                         ;   nametables: attribute bytes $3C0 + (row / 4)
            add a, a                        ;   * 8 + group * 2, + 1
            add a, $C0
            ld l, a
            ld a, c
            add a, a
            add a, l
            ld l, a
            ld h, high(NT_SH) + 3
            ld e, b                         ; (E: row)
            ld a, [hl+]                     ; NT0, columns 0-3
            bit 1, e
            jr z, .a0
            swap a
.a0:        ld d, a
            and 3
            ldh [sh_m0], a
            ld a, d
            rrca
            rrca
            and 3
            ldh [sh_m1], a
            ld a, [hl]                      ; NT0, columns 4-7
            bit 1, e
            jr z, .a1
            swap a
.a1:        ld d, a
            and 3
            ldh [sh_m2], a
            ld a, d
            rrca
            rrca
            and 3
            ldh [sh_m3], a
            set 2, h                        ; NT1
            ld a, [hl-]
            bit 1, e
            jr z, .a2
            swap a
.a2:        ld d, a
            and 3
            ldh [sh_u1], a
            ld a, d
            rrca
            rrca
            and 3
            ldh [sh_u2], a
            ld a, [hl]
            bit 1, e
            jr z, .a3
            swap a
.a3:        ld d, a
            and 3
            ldh [sh_p0], a
            ld a, d
            rrca
            rrca
            and 3
            ldh [sh_p1], a
            ld a, b                         ; owner bits: OWN[row * 4 + group]
            add a, a
            add a, a
            add a, c
            ld l, a
            ld h, high(OWN)
            ld a, [hl]
            ld d, a
            ld a, b                         ; HL = NT_SH + row * 32 + group * 8
            and 7                           ; (rows 16-29: swap would carry row bit 4 into
            swap a                          ;   the low byte)
            add a, a
            ld l, a                         ; (row & 7) * 32 in the low byte
            ld a, b
            srl a
            srl a
            srl a
            add a, high(NT_SH)
            ld h, a
            ld a, c
            add a, a
            add a, a
            add a, a
            add a, l
            ld l, a
            ld c, d                         ; C = owner bits
            srl c
            jr c, .n0
            ld d, [hl]
            ldh a, [sh_m0]
            jr .w0
.n0:      set 2, h
            ld d, [hl]
            res 2, h
            ldh a, [sh_p0]
.w0:      ld e, a
            push de
            inc l
            srl c
            jr c, .n1
            ld d, [hl]
            ldh a, [sh_m0]
            jr .w1
.n1:      set 2, h
            ld d, [hl]
            res 2, h
            ldh a, [sh_p0]
.w1:      ld e, a
            push de
            inc l
            srl c
            jr c, .n2
            ld d, [hl]
            ldh a, [sh_m1]
            jr .w2
.n2:      set 2, h
            ld d, [hl]
            res 2, h
            ldh a, [sh_p1]
.w2:      ld e, a
            push de
            inc l
            srl c
            jr c, .n3
            ld d, [hl]
            ldh a, [sh_m1]
            jr .w3
.n3:      set 2, h
            ld d, [hl]
            res 2, h
            ldh a, [sh_p1]
.w3:      ld e, a
            push de
            inc l
            srl c
            jr c, .n4
            ld d, [hl]
            ldh a, [sh_m2]
            jr .w4
.n4:      set 2, h
            ld d, [hl]
            res 2, h
            ldh a, [sh_u1]
.w4:      ld e, a
            push de
            inc l
            srl c
            jr c, .n5
            ld d, [hl]
            ldh a, [sh_m2]
            jr .w5
.n5:      set 2, h
            ld d, [hl]
            res 2, h
            ldh a, [sh_u1]
.w5:      ld e, a
            push de
            inc l
            srl c
            jr c, .n6
            ld d, [hl]
            ldh a, [sh_m3]
            jr .w6
.n6:      set 2, h
            ld d, [hl]
            res 2, h
            ldh a, [sh_u2]
.w6:      ld e, a
            push de
            inc l
            srl c
            jr c, .n7
            ld d, [hl]
            ldh a, [sh_m3]
            jr .w7
.n7:      set 2, h
            ld d, [hl]
            res 2, h
            ldh a, [sh_u2]
.w7:      ld e, a
            push de
            inc l
            dec l                           ; HL = the group's last cell, bank 4
            ld a, 4
            ldh [$FF70], a
            pop de
            ld [hl], d
            set 2, h
            ld [hl], e
            res 2, h
            dec l
            pop de
            ld [hl], d
            set 2, h
            ld [hl], e
            res 2, h
            dec l
            pop de
            ld [hl], d
            set 2, h
            ld [hl], e
            res 2, h
            dec l
            pop de
            ld [hl], d
            set 2, h
            ld [hl], e
            res 2, h
            dec l
            pop de
            ld [hl], d
            set 2, h
            ld [hl], e
            res 2, h
            dec l
            pop de
            ld [hl], d
            set 2, h
            ld [hl], e
            res 2, h
            dec l
            pop de
            ld [hl], d
            set 2, h
            ld [hl], e
            res 2, h
            dec l
            pop de
            ld [hl], d
            set 2, h
            ld [hl], e
            res 2, h
            dec l
            ld a, 1
            ldh [$FF70], a
            pop bc
            inc c
            ld a, c
            cp 4
            jp nz, .grp
            inc b
            jp .row

; B = the first row vshow_own must build: MAP_RB = CGB_RP = 2 (built ahead): 30; both 3 (being
; built, nothing written since): PB_ROW; else 0
vo_first:   ld a, [CGB_RP]
            ld b, a
            ld a, [MAP_RB]
            cp b
            jr nz, .z
            cp 2
            jr z, .all
            cp 3
            jr nz, .z
            ld a, [PB_ROW]
            ld b, a
            ret
.all:       ld b, 30
            ret
.z:         ld b, 0
            ret

; frame wait, CGB masked load not yet shown, cells of both nametables: vshow_own's buffer
; built ahead, a few rows per wait in its spare time (MAP_RB = CGB_RP = 3 while building, 2
; when done; any write sets them back to 1 and the build starts over). Keeps BC, DE, HL.
vpre:       push bc
            push de
            push hl
            ldh a, [own1_lo]
            ld b, a
            ldh a, [own1_hi]
            or b
            jr z, .x
            ld a, [MAP_RB]
            ld b, a
            ld a, [CGB_RP]
            ld c, a
            or b
            jr z, .x                        ; (nothing to build)
            ld a, b
            cp 1
            jr z, .st
            ld a, c
            cp 1
            jr z, .st
            ld a, b
            cp c
            jr nz, .st
            cp 2
            jr z, .x                        ; (built)
            cp 3
            jr nz, .st
            ld a, [PB_ROW]
            ld b, a
            jr .bd
.st:        ld b, 0
            ld a, 3
            ld [MAP_RB], a
            ld [CGB_RP], a
.bd:        ld a, 1
            ldh [sh_l2], a
            call vo_rows
            ld a, b
            ld [PB_ROW], a
            cp 30
            jr nz, .x
            ld a, 2
            ld [MAP_RB], a
            ld [CGB_RP], a
.x:         pop hl
            pop de
            pop bc
            ret

; ---- c62:DEF1-DF03 (menu text printer, one letter): LDX $2002 / LDX $55 / STX $2006 / LDX $54 /
; STX $2006 / STY $2007 / STA $2007: the dakuten byte Y and the letter A at $55:$54 and the
; next cell (+1 or +32). LCD off, no cell drawn by nametable 1, both cells map cells of
; nametable 0: straight to the shadow and the GB map (as rt_ppu_w7's short path); anything
; else through the PPU routines. Out: X = $54; N, Z from it; A, Y and carry kept.
tpair_b:    push af                         ; (the letter, carry)
            ld a, c
            ldh [w7v], a                    ; (Y)
            ldh a, [lcd_on]                 ; LCD off, or a CGB masked load (map rebuilt
            and a                           ;   from the shadow when shown)
            jr z, .lof
            ld a, [VLCD]
            cp 1
            jr nz, .slow
            ldh a, [dlg_on]
            and a
            jr nz, .slow
.lof:       ldh a, [own1_lo]
            ld h, a
            ldh a, [own1_hi]
            or h
            jr nz, .slow
            ld a, [NES_RAM + $55]
            and $3F
            cp $20
            jr c, .slow
            cp $3F
            jr z, .slow
            bit 2, a
            jr nz, .slow                    ; (nametable 1)
            and 3
            ld h, a
            ld a, [NES_RAM + $54]
            ld l, a                         ; HL = the first cell's offset
            ldh a, [ppu_ctrl]
            and 4
            ld a, 1
            jr z, .i1
            ld a, 32
.i1:        ld e, a                         ; DE = the increment
            push hl
            add hl, de                      ; HL = the second cell's offset: below $3C0
            ld a, h
            cp 3
            jr c, .ok
            jr nz, .sl1
            ld a, l
            cp $C0
            jr nc, .sl1
.ok:        pop de                          ; DE = the first cell's offset
            ld a, h
            add a, high(NT_SH)
            ld h, a
            pop af
            push af
            ld [hl], a                      ; the letter: shadow
            ld a, d
            add a, high(NT_SH)
            ld b, h
            ld h, a
            ld c, l
            ld l, e
            ldh a, [w7v]
            ld [hl], a                      ; Y: shadow
            ld a, [VLCD]
            cp 1
            jr nz, .map
            ld [MAP_RB], a                  ; (masked: the GB map rebuilt when shown)
            jr .mx
.map:       ld a, h                         ; GB map: Y, then the letter
            add a, $98 - high(NT_SH)
            ld h, a
            ldh a, [w7v]
            ld [hl], a
            ld a, b
            add a, $98 - high(NT_SH)
            ld h, a
            ld l, c
            pop af
            push af
            ld [hl], a
.mx:        ldh a, [w7v]                    ; (C = Y again, B = 0)
            ld c, a
            ld b, 0
            ld a, 1                         ; DMG: the map is scanned when the LCD goes on
            ldh [dmg_scan], a
            ldh a, [ppu_ctrl]               ; v = $55:$54 + 2 increments
            and 4
            ld a, 2
            jr z, .i2
            ld a, 64
.i2:        ld e, a
            ld a, [NES_RAM + $54]
            add a, e
            ldh [ppu_vl], a
            ld a, [NES_RAM + $55]
            adc a, 0
            and $3F
            ldh [ppu_vh], a
            xor a                           ; ($2002 read: vblank flag and latch cleared;
            ldh [vbl_flag], a               ;   the two $2006 writes leave the latch at 0)
            ldh [ppu_latch], a
            jr .out
.sl1:       pop hl
.slow:      ldh a, [code_bank]              ; (the PPU routines come back to code_bank)
            ld b, a
            ld a, PF_BANK
            ldh [code_bank], a
            call rt_ppu_r2
            ld a, [NES_RAM + $55]
            call rt_ppu_w6
            ld a, [NES_RAM + $54]
            call rt_ppu_w6
            ld a, c
            call rt_ppu_w7
            pop af
            push af
            call rt_ppu_w7
            ld a, b
            ldh [code_bank], a
            ld b, 0
.out:       ld a, [NES_RAM + $54]           ; X = $54, N and Z from it
            ld e, a
            ld d, 0
            ldh [nzv], a
            pop hl                          ; H = the letter, L = its flags: carry kept
            ld a, l
            and $10
            ld l, a
            ld a, e
            and a
            jr nz, .nz
            set 7, l
.nz:        push hl
            pop af
            ret

; ---- c62:DECE-DED1 (menu text printer loop head: LDY #0 / LDA ($3E),Y) and every letter
; (>= $48) after it, natively: INC $3E/$3F, the English mode dispatch ex:5CA4 by the mode at
; $5C00 (0: dakuten byte $FF and the letter, tpair_b as c62:DEF1; 1: the letter at $55:$54, the
; upper row; else: at $55:$54 + $20, the lower row), then c62:DF04 INC $54 (build.py checks
; the NES bytes). Returns at the first byte < $48: A = it, Y = 0; N, Z from A; C and V as the
; last letter left them (entry values if none); X = the last letter's cell address low byte
; ($54 before its INC, or $54 + $20), kept if none. Each cell straight to the shadow and the GB
; map when the LCD is off (or a CGB masked load), the cell is nametable 0's and no cell is
; nametable 1's; otherwise through the PPU routines.
txrun_b:    push af                         ; [SP + 2]: the flags out (C)
            ldh a, [code_bank]
            push af
            ld a, PF_BANK                   ; (the helpers come back to code_bank)
            ldh [code_bank], a
.rs:        call .st                        ; C = the increment, D = the fast-write state
            bit 7, d                        ; fast: a loop per row mode (the mode changes
            jr nz, .lp                      ;   only by control codes, which end the run)
            ld a, [EX_RAM]
            and a
            jp z, .q0
            dec a
            jp z, .q1
            jp .q2
.lp:        ld hl, NES_RAM + $3E            ; (in the loop: B temporary, C = increment,
            ld a, [hl+]                     ;   D = state, E = X)
            ld h, [hl]
            ld l, a
            ld a, h
            cp $20
            jr c, .ram
            cp $60
            jr c, .gr
            cp $80
            jr nc, .gr
            add a, $40                      ; save RAM $6000 -> $A000
            ld h, a
            ld a, [hl]
            jr .rd
.ram:       and $07
            or high(NES_RAM)
            ld h, a
            ld a, [hl]
            jr .rd
.gr:        call nes_rd
            ld a, l
.rd:        cp $48
            jp c, .chk
            ld hl, NES_RAM + $3E            ; INC $3E / $3F
            inc [hl]
            jr nz, .i3
            inc l
            inc [hl]
.i3:        ld b, a                         ; (B = the letter)
            ld a, [EX_RAM]                  ; the mode
            and a
            jr nz, .m12
            push bc                         ; 0: Y = $FF at $55:$54, the letter one increment on
            ld b, $FF
            ld a, [NES_RAM + $54]
            ld l, a
            ld a, [NES_RAM + $55]
            call .fp
            pop bc
            jr c, .s0
            ld a, [NES_RAM + $54]
            add a, c
            ld l, a
            ld a, [NES_RAM + $55]
            adc a, 0
            call .fp
            jr c, .s0
            ld a, [NES_RAM + $54]           ; X = $54, v = $55:$54 + 2 increments
            ld e, a
            ld a, c
            add a, a
            add a, e
            ldh [ppu_vl], a
            ld a, [NES_RAM + $55]
            adc a, 0
            and $3F
            ldh [ppu_vh], a
            jr .fd
.s0:        ld a, b                         ; (anything else: tpair_b)
            ld c, $FF
            call tpair_b
            call .st
            jr .sd
.m12:       dec a
            jr nz, .m2
            ld a, [NES_RAM + $54]           ; 1: the letter at $55:$54
            ld l, a
            ld a, [NES_RAM + $55]
            call .fp
            jr c, .s1
            ld a, [NES_RAM + $54]           ; X = $54, v = $55:$54 + the increment
            ld e, a
            add a, c
            ldh [ppu_vl], a
            ld a, [NES_RAM + $55]
            adc a, 0
            and $3F
            ldh [ppu_vh], a
            jr .fd
.s1:        ld a, [NES_RAM + $54]
            ld l, a
            ld a, [NES_RAM + $55]
            ld h, b
            call .put1
            call .st
            jr .sd
.m2:        ld a, [NES_RAM + $55]           ; else: at ($55:$54) + $20 (CLC / ADC #$20 /
            ld h, a                         ;   ADC #$00: C and V from the high byte)
            ld a, [NES_RAM + $54]
            add a, $20
            ld l, a
            ld a, h
            adc a, 0
            ld e, a                         ; (E = the high byte)
            sbc a, a
            and $10
            push hl
            ld hl, sp + 4                   ; (the flags out: under HL and the code bank)
            res 4, [hl]
            or [hl]
            ld [hl], a                      ; C
            pop hl
            ld a, e
            xor h
            and e
            and $80
            rrca
            ldh [vfl], a                    ; V
            ld a, e
            call .fp                        ; (keeps E and L)
            jr c, .s2
            ld a, l                         ; v = the cell + the increment, X = its low byte
            add a, c
            ldh [ppu_vl], a
            ld a, e
            adc a, 0
            and $3F
            ldh [ppu_vh], a
            ld e, l
            jr .f2
.s2:        ld a, e
            ld h, b
            call .put1
            call .st
            jr .nx
.fd:        ld hl, sp + 2
            set 4, [hl]                     ; C = 1 (CMP #$48; nothing after changes it)
.f2:        xor a                           ; ($2002 read: vblank flag and latch cleared;
            ldh [vbl_flag], a               ;   the two $2006 writes leave the latch at 0)
            ldh [ppu_latch], a
            inc a                           ; DMG: the map is scanned when the LCD goes on
            ldh [dmg_scan], a
            jr .nx
.sd:        ld hl, sp + 2
            set 4, [hl]                     ; C = 1
.nx:        ld hl, NES_RAM + $54            ; INC $54
            inc [hl]
            jp .lp
; a byte < $48 (A): 0 ends; with $37 = 0, code 1 (next line), 5-15 (the English patch's
; ExRAM handlers through the table at ex:5CEA) and $14-$47 (ignored) are handled here as FF1
; does (DED4 INC $3E, the compare chain from DF09, the handler, JMP DEC7 / DECE): RAM, X, C
; and V as it leaves them; then the loop goes on (.rs). Anything else ends the run.
.chk:       jp txc_chk                      ; (txc_chk: bank PF_BANK below)
.end:       ld d, a                         ; (the byte)
            pop af
            ldh [code_bank], a
            pop hl                          ; L = the flags out
            ld a, l
            and $10
            ld l, a
            ld a, d
            ldh [nzv], a
            and a
            jr nz, .e1
            set 7, l
.e1:        ld h, d
            ld bc, 0                        ; Y = 0
            ld d, b
            push hl
            pop af
            ret
.st:        ldh a, [ppu_ctrl]               ; C = 1 or 32; D = $80: cells through the PPU
            and 4                           ;   routines, 0: LCD off, 1: CGB masked load
            ld c, 1                         ;   (straight to the shadow and the GB map;
            jr z, .s3                       ;   masked: the shadow, the map rebuilt when shown)
            ld c, 32
.s3:        ld d, $80
            ldh a, [own1_lo]
            ld b, a
            ldh a, [own1_hi]
            or b
            ret nz
            ldh a, [lcd_on]
            and a
            jr z, .s4
            ld a, [VLCD]
            cp 1
            ret nz
            ldh a, [dlg_on]
            and a
            ret nz
            ld d, 1
            jr .s5
.s4:        ld d, 0
.s5:        ld a, [NES_RAM + $55]           ; ($55 stays the same through the run: INC $54
            and $3F                         ;   does not carry into it)
            cp $20
            jr c, .s6
            bit 2, a
            ret z
.s6:        ld d, $80                       ; (not nametable 0's cells)
            ret
.fp:        bit 7, d                        ; tile B at A:L (PPU address, high byte A) when it is
            jr nz, .fn                      ;   a map cell of nametable 0 and D allows: NC;
            and $3F                         ;   else C (nothing written). Keeps B-E, L.
            cp $20
            ret c
            bit 2, a
            jr nz, .fn                      ; (nametable 1, palettes)
            and 3
            ld h, a
            cp 3
            jr c, .fy
            ld a, l
            cp $C0
            jr nc, .fn                      ; (attributes)
            ld a, h
.fy:        add a, high(NT_SH)
            ld h, a
            ld [hl], b                      ; shadow
            bit 0, d
            jr nz, .fm
            add a, $98 - high(NT_SH)
            ld h, a
            ld [hl], b                      ; GB map
            and a
            ret
.fm:        ld a, 1
            ld [MAP_RB], a                  ; (masked: the GB map rebuilt when shown)
            and a
            ret
.fn:        scf
            ret
.get:       ld hl, NES_RAM + $3E            ; A = the byte at ($3E)
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld a, h
            cp $20
            jr c, .gram
            cp $60
            jr c, .grom
            cp $80
            jr nc, .grom
            add a, $40                      ; save RAM $6000 -> $A000
            ld h, a
            ld a, [hl]
            ret
.gram:      and $07
            or high(NES_RAM)
            ld h, a
            ld a, [hl]
            ret
.grom:      jp rc_get                       ; ROM: through the read-ahead (rc_get)
.adv:       ld hl, NES_RAM + $3E            ; INC $3E / $3F, INC $54; a letter written (D bit 6)
            inc [hl]
            jr nz, .av
            inc l
            inc [hl]
.av:        ld hl, NES_RAM + $54
            inc [hl]
            set 6, d
            ret
.q0:        call txr_rn0                    ; (a run of letters at once, when it can)
            jp c, .q0x                      ; (C: the run reached the end, A = that byte)
            call .get                       ; mode 0 (D < $80): Y = $FF at $55:$54 and the
            cp $48                          ;   letter one increment on, both map cells of
            jr c, .q0x                      ;   nametable 0 ($55 checked by .st)
            ld b, a
            ld a, [NES_RAM + $54]
            ld l, a
            add a, c
            jr c, .fs                       ; (the second cell past this 256: general path)
            ld e, a                         ; (E = its low byte)
            ld a, [NES_RAM + $55]
            and 3
            cp 3
            jr nz, .q0k
            ld a, e
            cp $C0
            jr nc, .fs                      ; (attributes)
            ld a, 3
.q0k:       add a, high(NT_SH)
            ld h, a
            ld [hl], $FF                    ; shadow: Y, the letter
            ld l, e
            ld [hl], b
            bit 0, d
            jr nz, .q0m
            add a, $98 - high(NT_SH)        ; GB map: the letter, Y
            ld h, a
            ld [hl], b
            ld a, [NES_RAM + $54]
            ld l, a
            ld [hl], $FF
            jr .q0n
.q0m:       ld a, 1
            ld [MAP_RB], a                  ; (masked: the GB map rebuilt when shown)
.q0n:       call .adv
            jr .q0
.fs:        ld a, b                         ; (a letter for the general path)
            jp .rd
.q0x:       bit 6, d                        ; the last letter's state: X = its $54, v = that
            jp z, .chk                      ;   + 2 increments, C = 1
            push af
            ld a, [NES_RAM + $54]
            dec a
            ld e, a
            ld l, a
            ld a, c
            add a, a
            add a, l
.fv:        ldh [ppu_vl], a
            ld a, [NES_RAM + $55]
            adc a, 0
            and $3F
            ldh [ppu_vh], a
            ld hl, sp + 4                   ; (the flags out: under AF and the code bank)
            set 4, [hl]
.fz:        xor a                           ; ($2002 read: vblank flag and latch cleared)
            ldh [vbl_flag], a
            ldh [ppu_latch], a
            inc a                           ; DMG: the map is scanned when the LCD goes on
            ldh [dmg_scan], a
            pop af
            jp .chk
.q1:        xor a
            call txr_rn1
            jp c, .q1x
            call .get                       ; mode 1: the letter at $55:$54
            cp $48
            jr c, .q1x
            ld b, a
            ld a, [NES_RAM + $54]
            ld l, a
.fw:        ld a, [NES_RAM + $55]           ; (letter B at cell low L, $55's 256)
            and 3
            cp 3
            jr nz, .q1k
            ld a, l
            cp $C0
            jr nc, .fs
            ld a, 3
.q1k:       add a, high(NT_SH)
            ld h, a
            ld [hl], b
            bit 0, d
            jr nz, .q1m
            add a, $98 - high(NT_SH)
            ld h, a
            ld [hl], b
            jr .q1n
.q1m:       ld a, 1
            ld [MAP_RB], a
.q1n:       call .adv
            ld a, [EX_RAM]                  ; (back to this mode's loop)
            dec a
            jr z, .q1
            jr .q2
.q1x:       bit 6, d                        ; X = the last letter's $54, v = that + the
            jp z, .chk                      ;   increment, C = 1
            push af
            ld a, [NES_RAM + $54]
            dec a
            ld e, a
            add a, c
            jr .fv
.q2:        ld a, $20
            call txr_rn1
            jp c, .q2x
            call .get                       ; else: the letter at $55:$54 + $20 (the ADC
            cp $48                          ;   with no carry: C = 0, V = 0)
            jr c, .q2x
            ld b, a
            ld a, [NES_RAM + $54]
            add a, $20
            jr c, .fs                       ; (the carry: general path)
            ld l, a
            jr .fw
.q2x:       bit 6, d                        ; X = the last letter's $54 + $20, v = that +
            jp z, .chk                      ;   the increment; C = 0, V = 0
            push af
            xor a
            ldh [vfl], a
            ld hl, sp + 4
            res 4, [hl]
            ld a, [NES_RAM + $54]
            add a, $1F
            ld e, a
            ld l, a
            ld a, c
            add a, l
            ldh [ppu_vl], a
            ld a, [NES_RAM + $55]
            adc a, 0
            and $3F
            ldh [ppu_vh], a
            jr .fz
.put1:      ld b, h                         ; LDX $2002 / $2006 = A / $2006 = L / $2007 = H.
            and $3F                         ;   Out: E = L (X), BC = 0, D = 0
            ld d, a                         ; (D = the high byte, 6 bits)
            ldh a, [lcd_on]
            and a
            jr z, .pf
            ld a, [VLCD]
            cp 1
            jr nz, .ps
            ldh a, [dlg_on]
            and a
            jr nz, .ps
.pf:        ldh a, [own1_lo]
            ld h, a
            ldh a, [own1_hi]
            or h
            jr nz, .ps
            ld a, d
            cp $20
            jr c, .ps
            bit 2, a
            jr nz, .ps                      ; (nametable 1, palettes)
            and 3
            ld e, a
            cp 3
            jr c, .pk
            ld a, l
            cp $C0
            jr nc, .ps                      ; (attributes)
.pk:        ld a, e
            add a, high(NT_SH)
            ld h, a
            ld [hl], b                      ; shadow
            ld a, [VLCD]
            cp 1
            jr nz, .pm
            ld [MAP_RB], a                  ; (masked: the GB map rebuilt when shown)
            jr .px
.pm:        ld a, e
            add a, $98
            ld h, a
            ld [hl], b                      ; GB map
.px:        ld a, 1                         ; DMG: the map is scanned when the LCD goes on
            ldh [dmg_scan], a
            ldh a, [ppu_ctrl]               ; v = the cell + the increment
            and 4
            ld a, 1
            jr z, .pi
            ld a, 32
.pi:        add a, l
            ldh [ppu_vl], a
            ld a, d
            adc a, 0
            and $3F
            ldh [ppu_vh], a
            xor a                           ; ($2002 read: vblank flag and latch cleared;
            ldh [vbl_flag], a               ;   the two $2006 writes leave the latch at 0)
            ldh [ppu_latch], a
            ld e, l
            ld bc, 0
            ld d, b
            ret
.ps:        ld e, l                         ; (the PPU routines keep BC and DE)
            push hl
            call rt_ppu_r2
            pop hl
            push hl
            ld a, d
            call rt_ppu_w6
            pop hl
            ld a, l
            call rt_ppu_w6
            ld a, b
            call rt_ppu_w7
            ld bc, 0
            ld d, b
            ret

; ---- far pr1 (gb_layout prow, the prologue's row writer): LDA ($10),Y / CMP #$10 / BCC pr3 /
; EOR POFF / STA $2007 / INY / BNE pr1. Each letter as rt_ppu_w7 would write it, without its
; generic path: DMG, LCD on, increment 1, nametable 0, no cell drawn by nametable 1, no
; dialogue: the shadow, the tile's palette check (dmg_cell) and the GB map (vram_put);
; otherwise rt_ppu_w7. Runs with code_bank = PF_BANK (the helpers come back to it).
; Out (at pr3): a code < $10: A = it, N = 1, Z = 0, C = 0; Y wrapped: A = the last letter,
; N = 0, Z = 1, C = 1. Y as the loop leaves it, X kept.
prow_b:     ldh a, [code_bank]
            push af
            ld a, PF_BANK
            ldh [code_bank], a
            ld b, 0                         ; (B: $80 | the palette of the letter before, in
            xor a                           ;   the same attribute quadrant)
            ldh [sh_nt], a
            ldh a, [is_cgb]                 ; o_cx = 1: the fast case (DMG, LCD on, no
            and a                           ;   dialogue, increment 1, no cell drawn by
            jr nz, .nf                      ;   nametable 1), decided once for the row
            ldh a, [lcd_on]
            and a
            jr z, .nf
            ldh a, [dlg_on]
            and a
            jr nz, .nf
            ldh a, [ppu_ctrl]
            and 4
            jr nz, .nf
            ldh a, [own1_lo]
            ld h, a
            ldh a, [own1_hi]
            or h
            jr nz, .nf
            ld a, 1
            jr .fs
.nf:        xor a
.fs:        ldh [o_cx], a
            ldh a, [is_sgb]                 ; sh_u1 = $80 on a plain Game Boy in the
            and a                           ;   prologue: every palette shades alike there,
            ld a, 0                         ;   so a fading row's copied letters ($00-$7F)
            jr nz, .so                      ;   are shown as the font itself ($80-$FF): the
            ldh a, [pro_mode]               ;   copies are never coded (the NES shadow
            and a                           ;   keeps them)
            jr z, .so
            ld a, $80
.so:        ldh [sh_u1], a
.lp:        push bc                         ; (B = 0 for the read: Y = C)
            ld b, 0
            ld l, $10
            call rt_izy_rd
            pop bc
            ld a, l
            cp $10
            jr c, .code
            ld hl, PROW_OFF
            xor [hl]
            ldh [w7v], a
            call .put
            inc c
            jr nz, .lp
            pop af                          ; (Y wrapped)
            ldh [code_bank], a
            ld b, 0
            xor a
            ldh [nzv], a
            ldh a, [w7v]
            ld h, a
            ld l, $90                       ; Z, C
            push hl
            pop af
            ret
.code:      ld h, a
            pop af
            ldh [code_bank], a
            ld b, 0
            ld a, $80
            ldh [nzv], a
            ld l, 0
            push hl
            pop af
            ret
.put:       ldh a, [o_cx]                   ; the letter (w7v) to the PPU
            and a
            jr z, .gen
            ldh a, [ppu_vh]
            cp $20
            jr c, .gen
            cp $3F
            jr z, .gen
            bit 2, a
            jr nz, .gen
            and 3
            ld h, a
            ldh a, [ppu_vl]
            ld l, a                         ; HL = the cell's offset
            ld a, h
            cp 3
            jr nz, .ok
            ld a, l
            cp $C0
            jr nc, .gen
.ok:        push de
            ld d, h
            ld e, l
            ld a, h
            add a, high(NT_SH)
            ld h, a
            ldh a, [w7v]
            cp [hl]
            jr z, .inc                      ; the same tile, same owner: nothing changes
            ld [hl], a                      ; shadow
            ldh a, [sh_u1]                  ; (plain Game Boy, prologue: every palette
            and a                           ;   shades alike: palette 3 for all)
            jr z, .pc
            ld b, $83
            jr .pk
.pc:        bit 0, e                        ; the cell's palette: an odd column right after
            jr z, .pe                       ;   the letter before shares its quadrant
            bit 7, b
            jr nz, .pk
.pe:        push de
            ld a, e
            and 31
            ld l, a                         ; col
            ld a, e
            swap a
            rrca
            and $07
            ld h, a
            ld a, d
            add a, a
            add a, a
            add a, a
            or h                            ; row
            ld e, l
            call cell_pal                   ; (sh_nt = 0)
            pop de
            or $80
            ld b, a
.pk:        ldh a, [sh_u1]
            ld h, a
            ldh a, [w7v]
            or h
            ldh [sh_u2], a                  ; (the tile shown)
            ld h, a
            ld a, b
            and 3
            call dmg_tile_p                 ; the tile checked for that palette
            ld a, d                         ; GB map
            add a, $98
            ld h, a
            ld l, e
            ldh a, [sh_u1]                  ; (prologue, plain Game Boy: queued only, the
            and a                           ;   row is written in the vblank)
            ldh a, [sh_u2]
            jr nz, .qp
            call vram_put
            jr .inc
.qp:        call q_put
.inc:       pop de
            ldh a, [ppu_vl]                 ; v += 1
            add a, 1
            ldh [ppu_vl], a
            ret nc
            ldh a, [ppu_vh]
            inc a
            and $3F
            ldh [ppu_vh], a
            ret
.gen:       xor a                           ; (anything else: the cache dropped, and the
            ld b, a                         ;   fast case for the rest of the row)
            ldh [o_cx], a
            ldh a, [w7v]
            jp rt_ppu_w7

; ---- fix window-row routines, from the LDA $2002 after their JSR $E1BD to their RTS (build.py:
; WRF = L, M, R, add per variant; A = variant): $2002, $2006 x 2 with $55 / $54, X = $1A, STA
; $2007 of L, X x M (X = 0: 256), R; the add variants then $54 += $20 with the carry into $55.
; LCD off or a CGB masked load, increment 1, nametable 0, no cell drawn by nametable 1, map
; cells: shadow and map at once (as wrow3_b); else rt_ppu_w7 / hle_wrow. Out: X = 0; with the
; add A = $55 and N, Z, C, V as its ADC #$00; else A = R, N and Z from it, C and V kept.
wrf_b:      push af                         ; (entry flags)
            push bc                         ; (Y)
            add a, a
            add a, a
            add a, low(WRF)
            ld l, a
            ld h, high(WRF)
            ld a, [hl+]
            ldh [sh_l1], a                  ; L
            ld a, [hl+]
            ldh [sh_u2], a                  ; M
            ld a, [hl+]
            ldh [sh_u3], a                  ; R
            ld a, [hl]
            ldh [sh_l2], a                  ; add
            ld a, [NES_RAM + $1A]
            ld e, a                         ; X
            call wrow_do
            jp wrf_fin

; one window row (wrf_b, dbox_b): $2002 read, v = $55:$54, sh_l1 (L), E x sh_u2 (M), sh_u3 (R)
; as STA $2007 writes. Out: D = 0; BC, E, HL clobbered.
wrow_do:    xor a
            ldh [vbl_flag], a
            ldh [ppu_latch], a
            ld a, [NES_RAM + $55]
            and $3F
            ldh [ppu_vh], a
            ld a, [NES_RAM + $54]
            ldh [ppu_vl], a
            ldh a, [lcd_on]
            and a
            jr z, .lk
            ld a, [VLCD]
            cp 1
            jp nz, .gen
            ldh a, [dlg_on]
            and a
            jp nz, .gen
.lk:        ldh a, [ppu_ctrl]
            and 4
            jp nz, .gen
            ldh a, [own1_lo]
            ld h, a
            ldh a, [own1_hi]
            or h
            jp nz, .gen
            ldh a, [ppu_vh]
            cp $20
            jp c, .gen
            cp $3F
            jp z, .gen
            bit 2, a
            jp nz, .gen
            and 3
            ld h, a
            ldh a, [ppu_vl]
            ld l, a                         ; HL = the first cell's offset
            push hl
            ld b, 0
            ld a, e                         ; n = X + 2 (X = 0: 258)
            add a, 2
            ld c, a
            ld a, 0
            adc a, b
            ld b, a
            ld a, e
            and a
            jr nz, .n1
            inc b
.n1:        add hl, bc                      ; (BC = n)
            ld a, h
            cp 3
            jr c, .ok
            jr nz, .g1
            ld a, l
            cp $C1
            jr nc, .g1
.ok:        ld a, l                         ; v = the end
            ldh [ppu_vl], a
            ldh a, [ppu_vh]
            and $FC
            or h
            ldh [ppu_vh], a
            pop hl
            push de
            push hl
            ld a, h
            add a, high(NT_SH)
            ld h, a
            call .row                       ; shadow
            pop hl
            pop de
            ld a, [VLCD]
            cp 1
            jr nz, .mp
            ld [MAP_RB], a                  ; (masked: the GB map rebuilt when shown)
            jr .md
.mp:        ld a, h
            add a, $98
            ld h, a
            call .row                       ; GB map
.md:        ld a, 1
            ldh [dmg_scan], a
            ld d, 0
            ret
.g1:        pop hl
.gen:       push bc
            ldh a, [code_bank]              ; (the PPU routines come back to code_bank)
            push af
            ld a, PF_BANK
            ldh [code_bank], a
            ld b, 0
            ld d, 0
            ldh a, [sh_l1]
            call rt_ppu_w7
            ldh a, [sh_u2]
            push de
            call hle_wrow                   ; X x M (keeps the registers but X)
            pop de
            ldh a, [sh_u3]
            call rt_ppu_w7
            pop af
            ldh [code_bank], a
            pop bc
            ld d, 0
            ret
.row:       ldh a, [sh_l1]                  ; HL: L, E x M, R (E = X, 0: 256; four at a
            ld [hl+], a                     ;   time; D, E clobbered)
            ld a, e
            dec a
            srl a
            srl a
            inc a
            ld d, a                         ; D = passes of 4 (the first one partial)
            ld a, e
            dec a
            and 3                           ; (count - 1) & 3: 3 = a whole first pass
            ld e, a
            ldh a, [sh_u2]
            bit 1, e
            jr z, .r01
            bit 0, e
            jr nz, .rm
            jr .r3
.r01:       bit 0, e
            jr nz, .r2
            jr .r1
.rm:        ld [hl+], a
.r3:        ld [hl+], a
.r2:        ld [hl+], a
.r1:        ld [hl+], a
            dec d
            jr nz, .rm
            ldh a, [sh_u3]
            ld [hl], a
            ret
wrf_fin:    pop bc                          ; (Y)
            ld e, 0                         ; X = 0
            ld d, 0
            ldh a, [sh_l2]
            and a
            jr nz, .add
            pop hl                          ; A = R; N, Z from it; C kept
            ld a, l
            and $10
            ld l, a
            ldh a, [sh_u3]
            ldh [nzv], a
            and a
            jr nz, .nz
            set 7, l
.nz:        ld h, a
            push hl
            pop af
            ret
.add:       pop hl                          ; (entry flags dropped)
            ld hl, NES_RAM + $54            ; $54 += $20, $55 += carry (ADC #$00)
            ld a, [hl]
            add a, $20
            ld [hl+], a
            ld a, [hl]
            ld d, a                         ; (D = the old $55)
            adc a, 0
            ld [hl], a
            ld e, a                         ; (E = the new $55)
            ld l, 0                         ; flags: C, Z
            jr nc, .a1
            ld l, $10
.a1:        and a
            jr nz, .a2
            set 7, l
.a2:        ld a, e
            ldh [nzv], a                    ; N
            ld a, d                         ; V: (old ^ new) & new & $80
            xor e
            and e
            and $80
            rrca
            ldh [vfl], a
            ld h, e
            ld de, 0
            push hl
            pop af
            ret

; ---- fix:E0FD-E117 (DrawBox's rows when $37 = 0, no frame per row): $1A = $3C - 2, $1B =
; $3D - 2; the top row (F7, F8 x $1A, F9), $1B middle rows (FA, FF.., FB), the bottom row (FC,
; FD.., FE), each as wrf_b; $54/$55 one row down (ADC) after the top and each middle row.
; A conditional idiom (build.py checks the NES bytes): $37 != 0 or $3D < 3 declines (returns
; past the caller's JP, every register and flag kept). Out: A = $FE, X = 0, $1B = 0, Y kept;
; N = 1, Z = 0; C and V from the last middle row's ADC #$00.
dbox_b:     push af
            ld a, [NES_RAM + $37]
            and a
            jr nz, .dcl
            ld a, [NES_RAM + $3D]
            cp 3
            jr c, .dcl
            pop af
            push bc                         ; (Y)
            ldh a, [code_bank]
            push af
            ld a, PF_BANK
            ldh [code_bank], a
            ld a, [NES_RAM + $3C]
            sub 2
            ld [NES_RAM + $1A], a
            ld a, [NES_RAM + $3D]
            sub 2
            ld [NES_RAM + $1B], a
            call dbx_fast                   ; (the whole box at once when it can: C)
            jr c, .fin
            ld a, $F7
            ld bc, $F8F9
            call .row
.mid:       ld a, $FA
            ld bc, $FFFB
            call .row
            ld hl, NES_RAM + $1B
            dec [hl]
            jr nz, .mid
            ld a, $FC                       ; the bottom row: no ADC
            ld bc, $FDFE
            ldh [sh_l1], a
            ld a, b
            ldh [sh_u2], a
            ld a, c
            ldh [sh_u3], a
            ld a, [NES_RAM + $1A]
            ld e, a
            call wrow_do
.fin:       pop af
            ldh [code_bank], a
            pop bc
            ld de, 0                        ; X = 0
            ld a, $FE
            ldh [nzv], a                    ; N
            ldh a, [sh_l2]                  ; C (Z = 0)
            ld l, a
            ld h, $FE
            push hl
            pop af
            ret
.row:       ldh [sh_l1], a                  ; a row (L = A, M = B, R = C), then the ADC
            ld a, b
            ldh [sh_u2], a
            ld a, c
            ldh [sh_u3], a
            ld a, [NES_RAM + $1A]
            ld e, a
            call wrow_do
            ld hl, NES_RAM + $54            ; $54 += $20, $55 += carry (ADC #$00)
            ld a, [hl]
            add a, $20
            ld [hl+], a
            ld a, [hl]
            ld d, a                         ; (D = the old $55)
            adc a, 0
            ld [hl], a
            ld e, a
            sbc a, a
            and $10
            ldh [sh_l2], a                  ; C
            ld a, d                         ; V: (old ^ new) & new & $80
            xor e
            and e
            and $80
            rrca
            ldh [vfl], a
            ld d, 0
            ret
.dcl:       push hl                         ; decline: past the caller's JP (3 bytes)
            ld hl, sp + 6                   ;   (HL, AF, hle_pfj's return, the caller's)
            ld a, [hl]
            add a, 3
            ld [hl+], a
            jr nc, .d1
            inc [hl]
.d1:        pop hl
            pop af
            ret

; ---- b21:80AE-80DA (a list of PPU records: address high, low, count (0: 256), the bytes;
; a 0 ends it): each record's $2002 read and $2006 writes, its bytes by izyrun0 (bank 0).
; Out (at the RTS, b21:80DB): A = 0, Y = 0; N = 0, Z = 1; C, V from the last record's TYA /
; CLC / ADC $10 (kept if none); X = 0 (kept if no record); $10/$11 at the 0.
rlist_b:    push af                         ; [SP + 2]: the flags out (C)
            ldh a, [code_bank]
            push af
            ld a, PF_BANK
            ldh [code_bank], a
.lp:        call rl_fast                    ; (records from ROM straight to the shadow)
            xor a                           ; LDA $2002: vblank flag and latch cleared
            ldh [vbl_flag], a
            ldh [ppu_latch], a
            ld hl, NES_RAM + $10
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            push hl
            call nes_rd
            ld a, l
            pop hl
            and a
            jr z, .end
            and $3F                         ; $2006 (high), then low (latch back at 0)
            ldh [ppu_vh], a
            inc hl
            push hl
            call nes_rd
            ld a, l
            ldh [ppu_vl], a
            pop hl
            inc hl
            call nes_rd
            ld e, l                         ; X = the count
            ld bc, 3                        ; Y = 3
            ld a, $10
            call izyrun0                    ; X bytes ($10),Y -> $2007 (Y += n, X = 0)
            ld hl, NES_RAM + $10            ; TYA / CLC / ADC $10 / STA $10 (BCC / INC $11)
            ld a, [hl]
            ld d, a
            add a, c
            ld [hl+], a
            ld b, a                         ; (B = the sum)
            jr nc, .nc
            inc [hl]
.nc:        sbc a, a                        ; (A: $FF with the carry)
            and $10
            ld hl, sp + 2
            res 4, [hl]
            or [hl]
            ld [hl], a                      ; C
            ld a, c                         ; V: (Y ^ sum) & (M ^ sum) & $80
            xor b
            ld h, a
            ld a, d
            xor b
            and h
            and $80
            rrca
            ldh [vfl], a
            ld bc, 0
            ld d, b
            jr .lp
.end:       pop af
            ldh [code_bank], a
            pop hl                          ; (L = the flags out: C)
            ld a, l
            and $10
            or $80                          ; Z
            ld l, a
            xor a
            ldh [nzv], a
            ld h, a
            ld bc, 0                        ; Y = 0
            push hl
            pop af
            ret

; DMG, LCD off: the GB map rows 0-29 from NT_SH (+ $400 for cells of nametable 1, OWN);
; MAP_RB = 0. Eight cells per OWN byte (bit 0 first).
dmg_maprb_b: push bc
            push de
            xor a
            ld [MAP_RB], a
            ld de, $9800
            ldh a, [own1_lo]                ; no cell of nametable 1: nametable 0's shadow as
            ld b, a                         ;   it is (960 bytes, 16 a pass)
            ldh a, [own1_hi]
            or b
            jr nz, .ow
            ld hl, NT_SH
            ld c, 60
.st:        ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc de
            dec c
            jr nz, .st
            pop de
            pop bc
            ret
.ow:        ld hl, OWN
.by:        ld a, [hl+]
            push hl
            ld c, a
            ld a, d                         ; HL = shadow of these 8 cells
            add a, high(NT_SH) - $98
            ld h, a
            ld l, e
            ld a, c
            and a
            jr z, .z
            inc a
            jr z, .f
            ld b, 8                         ; mixed: cell by cell
.c:         push hl
            srl c
            jr nc, .c0
            ld a, h
            add a, 4
            ld h, a
.c0:        ld a, [hl]
            ld [de], a
            inc e
            pop hl
            inc l
            dec b
            jr nz, .c
            jr .nx
.f:         ld a, h                         ; all of nametable 1
            add a, 4
            ld h, a
.z:         ld a, [hl+]                     ; (8 cells)
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
.nx:        pop hl
            ld a, e
            and a
            jr nz, .n1
            inc d
.n1:        ld a, d
            cp $9B
            jr nz, .by
            ld a, e
            cp $C0
            jr nz, .by
            pop de
            pop bc
            ret

; ---- fix:FA77-FA7A (battle text: LDX #0 / LDA ($90,X)) and each letter after it (>= $48:
; FA87 JSR FA9C / JSR FCA7 / JMP FA77), natively: $9E = the letter, the pair (dakuten byte
; $FF / $C0 / $C1, the tile) at ($92) and $92 += 2, $90 += 1; FF1's conversion ($48-$79:
; ranges + $47 / $4C / $73 / $78, $C1 + $33 / $6E). Stops at a byte < $48 (or 0): A = it,
; X = 0; N, Z from A; Y = 0, C (letter >= $7A), V (set below $7A) as the last letter left
; them, or as on entry. Pointers into RAM, ExRAM or save RAM (else the idiom is not used:
; build.py checks the bytes; anything else falls back to nes_rd / nes_wr).
btx_b:      push af                         ; [SP + 2]: the flags out (C)
            ldh a, [code_bank]              ; (nes_rd / nes_wr come back to code_bank)
            push af
            ld a, PF_BANK
            ldh [code_bank], a
            jp btx_f
.lp:        ld hl, NES_RAM + $90
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            call .rd                        ; A = the byte
            and a
            jr z, .end
            cp $48
            jr c, .end
            ld [NES_RAM + $9E], a
            ld d, $FF                       ; D = dakuten byte, A = tile
            cp $7A
            jr nc, .k                       ; (C = 1; V kept)
            ld d, $C0
            ld b, $47
            cp $57
            jr c, .ad
            ld b, $4C
            cp $5C
            jr c, .ad
            ld b, $73
            cp $6B
            jr c, .ad
            ld b, $78
            cp $70
            jr c, .ad
            ld d, $C1
            ld b, $33
            cp $75
            jr c, .ad
            ld b, $6E
.ad:        add a, b                        ; (C = 0, V = 1: two positives giving a negative)
            ld b, a
            ld a, $40
            ldh [vfl], a
            ld a, b
            ld hl, sp + 2
            res 4, [hl]
            jr .wr
.k:         ld hl, sp + 2
            set 4, [hl]
.wr:        ld e, a                         ; ($92) + 1 = tile, ($92) = dakuten byte
            ld hl, NES_RAM + $92
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld a, d
            call .wb
            inc hl
            ld a, e
            call .wb
            ld hl, NES_RAM + $92            ; $92 += 2, $90 += 1
            ld a, [hl]
            add a, 2
            ld [hl+], a
            jr nc, .n2
            inc [hl]
.n2:        ld hl, NES_RAM + $90
            inc [hl]
            jr nz, .n1
            inc l
            inc [hl]
.n1:        ld c, 0                         ; Y = 0
            jr .lp
.end:       ld b, a
            ldh [nzv], a
            pop af
            ldh [code_bank], a
            pop hl                          ; (L = flags: C)
            ld a, l
            and $10
            ld l, a
            ld a, b
            and a
            jr nz, .nz
            set 7, l
.nz:        ld h, b
            ld b, 0
            ld de, 0                        ; X = 0
            push hl
            pop af
            ret
.rd:        ld a, h                         ; HL = NES address -> A (keeps BC, DE)
            cp $08
            jr c, .rr
            cp $5C
            jr c, .ro
            cp $60
            jr c, .re
            cp $80
            jr nc, .ro
            add a, $40                      ; save RAM
            ld h, a
            ld a, [hl]
            ret
.rr:        or high(NES_RAM)
            ld h, a
            ld a, [hl]
            ret
.re:        add a, $6C                      ; ExRAM $5C00 -> $C800
            ld h, a
            ld a, [hl]
            ret
.ro:        push de
            call nes_rd
            pop de
            ld a, l
            ret
.wb:        push hl                         ; A -> NES address HL (keeps BC, DE, HL)
            push af
            ld a, h
            cp $08
            jr c, .wr0
            cp $5C
            jr c, .wo
            cp $60
            jr c, .we
            cp $80
            jr nc, .wo
            add a, $40
            ld h, a
            pop af
            ld [hl], a
            pop hl
            ret
.wr0:       or high(NES_RAM)
            ld h, a
            pop af
            ld [hl], a
            pop hl
            ret
.we:        add a, $6C
            ld h, a
            pop af
            ld [hl], a
            pop hl
            ret
.wo:        pop af
            push de
            ldh [wtmp], a
            call nes_wr
            pop de
            pop hl
            ret

section bank PF_BANK, $7F00
NBIT60:     db 1, 2, 4, 8, 16, 32, 64, 128

; scan_b tables: SC_TBL[n] = bit of n's low field, SC_TBL + $100: of its high field;
; SC_LOG[bits] = the palette (the lowest bit)
section bank PF_BANK, $7D00
SC_TBL:     db 1, 2, 4, 8, 1, 2, 4, 8, 1, 2, 4, 8, 1, 2, 4, 8
section bank PF_BANK, $7E00
            db 1, 1, 1, 1, 2, 2, 2, 2, 4, 4, 4, 4, 8, 8, 8, 8
section bank PF_BANK, $7E40
SC_LOG:     db 0, 0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0

; ---- gb_layout's own far routines, native (build.py FAR_PF: used when their bytes hash as
; expected). NES $6000-$7FFF = cart RAM bank 0 at $A000.
section bank PF_BANK, $7000
VSV_GB     = $A000 + $0EAC  ; vsave / vrest: the caller's $88-$8B
; vsave: $88-$8B -> VSV; vrest: back. Out as the 6502 loop (X 3..0): A = the byte at index
; 0, X = $FF, N = 1, Z = 0; C, V kept.
vsave_b:    ld hl, NES_RAM + $88
            ld a, [hl+]
            ld [VSV_GB], a
            ld a, [hl+]
            ld [VSV_GB + 1], a
            ld a, [hl+]
            ld [VSV_GB + 2], a
            ld a, [hl]
            ld [VSV_GB + 3], a
vs_out:     ld a, $FE
            inc a                           ; (Z = 0, C kept)
            ldh [nzv], a
            ld e, a
            ld a, [VSV_GB]
            ret
vrest_b:    ld hl, VSV_GB
            ld a, [hl+]
            ld [NES_RAM + $88], a
            ld a, [hl+]
            ld [NES_RAM + $89], a
            ld a, [hl+]
            ld [NES_RAM + $8A], a
            ld a, [hl]
            ld [NES_RAM + $8B], a
            jr vs_out
; party_stamp (battle panel cleared): the party window into the panel image ($691E, 32 a
; row): top / bottom frame rows at column 9 of rows 0 / 5, rows 1-4 left frame, ten tiles
; $80 + 10m.., right frame; VLINE = 0. Out: A = $A8, X = $8A, Y = 4, Z = 1, C = 1, N = 0,
; V = 0 (the last ADC).
PS_PAN     = $A000 + $091E
pstamp_b:   xor a
            ld [$A000 + $0EA0], a           ; (VLINE)
            ld hl, PS_PAN + 9
            ld [hl], $F7
            inc l
            ld a, $F8
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
            ld [hl], $F9
            ld hl, PS_PAN + 5 * 32 + 9
            ld [hl], $FC
            inc hl
            ld a, $FD
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
            ld [hl], $FE
            ld hl, PS_PAN + 32 + 9
            ld a, $80
            ld c, 4
.r:         ld [hl], $FA
            inc hl
            ld [hl+], a
            inc a
            ld [hl+], a
            inc a
            ld [hl+], a
            inc a
            ld [hl+], a
            inc a
            ld [hl+], a
            inc a
            ld [hl+], a
            inc a
            ld [hl+], a
            inc a
            ld [hl+], a
            inc a
            ld [hl+], a
            inc a
            ld [hl+], a
            inc a
            ld [hl], $FB
            ld de, 32 - 11
            add hl, de
            dec c
            jr nz, .r
            ld e, $8A                       ; (D = 0 from the add)
            ld c, 4
            xor a
            ldh [nzv], a
            ldh [vfl], a
            scf
            ld a, $A8
            ret

; ---- b12:BF13-BF25 (battle sprite step, every frame: swap $90-$9F with $6D97, LDA $94 / BEQ,
; the step, swap back): when the swapped-in $94 ($6D9B) is 0 the two swaps cancel, so only the
; registers as FF1 leaves them: A = $6DA6, X = 16, Y = 0; N = 0, Z = 1; C kept. A conditional
; idiom (build.py checks the bytes): $6D9B != 0 declines (past the caller's JP, all kept).
bfsw_b:     push af
            ld a, [$A000 + $0D9B]
            and a
            jr nz, .dcl
            xor a
            ldh [nzv], a
            ld bc, 0
            ld de, 16
            pop hl
            ld a, l
            and $10
            or $80
            ld l, a
            push hl
            pop af
            ld a, [$A000 + $0DA6]
            ret
.dcl:       push hl                         ; decline: past the caller's JP (3 bytes)
            ld hl, sp + 6                   ;   (HL, AF, hle_pfj's return, the caller's)
            ld a, [hl]
            add a, 3
            ld [hl+], a
            jr nc, .d1
            inc [hl]
.d1:        pop hl
            pop af
            ret

; ---- fix:FC89-FC98 (battle text: a name of at most $9F letters from ($94), each through
; FA9C): each letter's pair at ($92) (dakuten byte, tile, as btx_b), $92 += 2, $9E = it;
; stops at a 0 or after $9F letters. Out (at FC99): Y = the letters done, X kept; A = 0 (the
; 0) or the last letter; N = 0, Z = 1; C from the last CPY (1 after $9F letters; kept if the
; first byte is 0); V as the last letter's conversion left it (kept if none).
bnm_b:      push af                         ; [SP + 4]: the flags out (C)
            ldh a, [code_bank]              ; (nes_rd / nes_wr come back to code_bank)
            push af
            ld a, PF_BANK
            ldh [code_bank], a
            push de                         ; (X)
            ld c, 0
            ld a, [NES_RAM + $9F]           ; fast path: source in the $8000 ROM bank, the
            and a                           ;   pairs in save RAM, $9F letters within both
            jr z, .lp
            ld hl, NES_RAM + $92
            ld e, [hl]
            inc l
            ld d, [hl]                      ; DE = destination
            ld l, a
            ld h, 0
            add hl, hl
            add hl, de                      ; HL = its end
            ld a, d
            sub $60
            cp $20
            jr nc, .lp
            ld a, h
            sub $60
            cp $20
            jr nc, .lp
            ld a, d
            add a, $40
            ld d, a                         ; (GB address)
            ld hl, NES_RAM + $94
            ld a, [hl+]
            ld h, [hl]
            ld l, a                         ; HL = source
            ld a, h
            sub $80
            cp $40
            jr nc, .lp
            ld a, [NES_RAM + $9F]
            add a, l
            ld a, h
            adc a, 0
            sub $80
            cp $40
            jr nc, .lp
            ld a, h
            sub $40
            ld h, a                         ; (rt_rd_8's window)
.fl:        push hl
            call rt_rd_8
            ld a, l
            pop hl
            and a
            jr z, .fz
            inc hl
            ld b, a
            cp $7A
            jr c, .fc
            ld a, $FF
            ld [de], a
            inc de
            ld a, b
.fw:        ld [de], a
            inc de
            inc c
            ld a, [NES_RAM + $9F]
            cp c
            jr nz, .fl
            call .fe                        ; $9F letters: C = 1
            jr .eq
.fz:        call .fe                        ; a 0: C = 0 after a letter (else kept)
            ld b, 0
            ld a, c
            and a
            jr z, .out
            ld hl, sp + 4
            res 4, [hl]
            jr .out
.fe:        ld a, e                         ; $92 = the end, $9E = the last letter
            ld [NES_RAM + $92], a
            ld a, d
            sub $40
            ld [NES_RAM + $93], a
            ld a, c
            and a
            ret z
            ld a, b
            ld [NES_RAM + $9E], a
            ret
.fc:        cp $70                          ; dakuten byte, then the tile
            ld a, $C0
            jr c, .f0
            inc a
.f0:        ld [de], a
            inc de
            ld a, $40
            ldh [vfl], a
            ld a, b
            cp $57
            jr nc, .f1
            add a, $47
            jr .fw
.f1:        cp $5C
            jr nc, .f2
            add a, $4C
            jr .fw
.f2:        cp $6B
            jr nc, .f3
            add a, $73
            jr .fw
.f3:        cp $70
            jr nc, .f4
            add a, $78
            jr .fw
.f4:        cp $75
            jr nc, .f5
            add a, $33
            jr .fw
.f5:        add a, $6E
            jr .fw
.lp:        ld hl, NES_RAM + $94
            ld a, [hl+]
            ld h, [hl]
            add a, c
            ld l, a
            jr nc, .r1
            inc h
.r1:        call btx_b.rd
            and a
            jr z, .z
            ld [NES_RAM + $9E], a
            ld b, a
            ld d, $FF                       ; D = dakuten byte, E = tile
            cp $7A
            jr nc, .k
            ld d, $C0
            ld e, $47
            cp $57
            jr c, .ad
            ld e, $4C
            cp $5C
            jr c, .ad
            ld e, $73
            cp $6B
            jr c, .ad
            ld e, $78
            cp $70
            jr c, .ad
            ld d, $C1
            ld e, $33
            cp $75
            jr c, .ad
            ld e, $6E
.ad:        add a, e                        ; (C = 0, V = 1)
            ld e, a
            ld a, $40
            ldh [vfl], a
            ld hl, sp + 4
            res 4, [hl]
            jr .wr
.k:         ld e, a                         ; (C = 1, V kept)
            ld hl, sp + 4
            set 4, [hl]
.wr:        ld hl, NES_RAM + $92
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld a, d
            call btx_b.wb
            inc hl
            ld a, e
            call btx_b.wb
            ld hl, NES_RAM + $92            ; $92 += 2
            ld a, [hl]
            add a, 2
            ld [hl+], a
            jr nc, .n2
            inc [hl]
.n2:        inc c                           ; INY / CPY $9F
            ld hl, NES_RAM + $9F
            ld a, c
            cp [hl]
            jr z, .eq
            ld hl, sp + 4
            jr c, .lt
            set 4, [hl]
            jr .lp
.lt:        res 4, [hl]
            jr .lp
.z:         ld b, 0
            jr .out
.eq:        ld hl, sp + 4
            set 4, [hl]
.out:       xor a
            ldh [nzv], a
            pop de
            ld d, 0
            pop af
            ldh [code_bank], a
            pop hl                          ; (L = flags: C)
            ld a, l
            and $10
            or $80
            ld l, a
            ld h, b
            ld b, 0
            push hl
            pop af
            ret

; ---- fix:F5F3-F5FE (battle box list: a 5-byte record from ($8C) to $6A9E-$6AA2). Out (at the
; RTS): A = the fifth byte, Y = 5, X kept; N = 0, Z = 1, C = 1; V kept.
rec5_b:     push de                         ; (X)
            ld hl, NES_RAM + $8C
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld a, h
            sub $60
            cp $1B                          ; (save RAM, the five bytes below $7C00)
            jr nc, .gen
            add a, $A0
            ld h, a
            ld de, $A000 + $0A9E
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl]
            ld [de], a
.out:       pop de
            ld d, 0
            ld b, a
            xor a
            ldh [nzv], a
            ld c, 5
            scf                             ; (Z = 1 from the XOR, C = 1)
            ld a, b
            ld b, 0
            ret
.gen:       ldh a, [code_bank]              ; (anything else: byte by byte, through nes_rd,
            push af                         ;   which comes back to code_bank)
            ld a, PF_BANK
            ldh [code_bank], a
            ld de, $A000 + $0A9E
            ld b, 5
.g:         push hl
            call btx_b.rd
            pop hl
            ld [de], a
            inc e
            inc hl
            dec b
            jr nz, .g
            ld b, a
            pop af
            ldh [code_bank], a
            ld a, b
            jr .out


section bank HLE_BANK, $6E00
; ---- NES OAM page A -> GB OAM shadow (rt_io_w4014 runs it with code_bank = HLE_BANK).
; GB y = NES y + 17 - cam_y * 8 (shown from -16), x = NES x + 8 - cam_x * 8 (from -8), the
; tile in a GB sprite slot (loaded on first use, coded for its palette), the attributes.
; The GB table is filled from its end, the NES entries taken last first: the NES order is
; kept, and sprites appearing or going at the start of the page (FF1's cursor, entries 0-3)
; leave the slots of the others where they were. So a page like the last one is converted
; incrementally (.inc): entries equal to the last page's copy keep their GB entries; only
; changed ones are converted, and the ones below a change in the number of GB entries. A
; tile not resident with its coding, a new camera / page / coding or a slot changed since
; (oam_clean = 0) convert the whole page (.sv, a new frame number for the slot stamps); more
; than 40 in view: the forward conversion (.fwd), which drops the last ones as before.
OC_HDR     = $A6C0          ; (cart RAM bank 3) oamconv_b's last input: page, cam_x, cam_y,
OC_COPY    = $A700          ;   SPAL_KEY 0-3; the NES OAM page (256)
OC_POS     = $A800          ;   GB slot of each NES entry with a GB entry (index = entry offset)
OC_LIST    = $A6C8          ;   changed entries (occmp, up to 16)
OC_DF      = $A6D8          ;   a slot load deferred in this conversion (whole conversions)
OC_ST      = $A6D9          ;   the slots in use stamped in this incremental conversion
OC_TOP     = $A6DA          ;   the layout of the last whole conversion (kept by incremental
OC_BOT     = $A6DB          ;   ones): highest / lowest GB slot in use (OAM_SH offsets), and
OC_MAXI    = $A6DC          ;   the highest / lowest NES entry with a GB entry ($FF: none);
OC_MINI    = $A6DD          ;   free slots above OC_TOP / below OC_BOT take entries coming into
                            ;   view above / below them (NES order kept)
OC_EPO     = $A6DE          ;   whole conversions so far (mod 256): OC_POS + entry + 1 = the one
                            ;   that gave the entry its slot (a hole it left is its own)
oamconv_b:  and $07
            add a, high(NES_RAM)
            ld h, a
            ld a, [OAM_USED]                ; (few sprites last time: converting costs less
            cp 6                            ;   than comparing; the copy is left invalid)
            jr c, .pl
            ld a, 3
            ld [$4000], a
            ld de, OC_HDR
            ld a, [OAM_CLEAN]
            and a
            jr z, .sv
            ld a, [de]
            cp h
            jr nz, .sv
            inc e
            ldh a, [cam_x]
            ld b, a
            ld a, [de]
            cp b
            jr nz, .sv
            inc e
            ldh a, [cam_y]
            ld b, a
            ld a, [de]
            cp b
            jr nz, .sv
            inc e
            ld bc, SPAL_KEY
            ld a, [bc]
            ld l, a
            ld a, [de]
            cp l
            jr nz, .sv
            inc e
            inc c
            ld a, [bc]
            ld l, a
            ld a, [de]
            cp l
            jr nz, .sv
            inc e
            inc c
            ld a, [bc]
            ld l, a
            ld a, [de]
            cp l
            jr nz, .sv
            inc e
            inc c
            ld a, [bc]
            ld l, a
            ld a, [de]
            cp l
            jr nz, .sv
            jp .inc
.sv:        ld de, OC_HDR                   ; keep this input
            ld a, h
            ld [de], a
            inc e
            ldh a, [cam_x]
            ld [de], a
            inc e
            ldh a, [cam_y]
            ld [de], a
            inc e
            ld bc, SPAL_KEY
            ld a, [bc]
            ld [de], a
            inc e
            inc c
            ld a, [bc]
            ld [de], a
            inc e
            inc c
            ld a, [bc]
            ld [de], a
            inc e
            inc c
            ld a, [bc]
            ld [de], a
            ld de, OC_COPY                  ; (y of every entry; the other three bytes only of
            ld l, e                         ;   the visible ones: occmp compares y alone where
            push hl                         ;   both are hidden)
.cp:        ld a, [hl+]
            ld [de], a
            inc e
            cp $EF
            jr nc, .ch
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            jr nz, .cp
            jr .cd
.ch:        inc l
            inc l
            inc l
            inc e
            inc e
            inc e
            jr nz, .cp
.cd:        pop hl
            ld a, 1
            jr .pk
.pl:        xor a
.pk:        ld [OAM_CLEAN], a
            ld a, 3                         ; (cart RAM bank 3 on: each entry's GB slot to
            ld [$4000], a                   ;   OC_POS)
            xor a                           ; (OC_DF: a slot load deferred in this conversion)
            ld [OC_DF], a
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
            call oc_resv                    ; (DE = the first slot; top slots left free)
            ld l, $FC
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $F8
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $F4
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $F0
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $EC
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $E8
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $E4
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $E0
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $DC
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $D8
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $D4
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $D0
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $CC
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $C8
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $C4
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $C0
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $BC
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $B8
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $B4
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $B0
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $AC
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $A8
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $A4
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $A0
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $9C
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $98
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $94
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $90
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $8C
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $88
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $84
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $80
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $7C
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $78
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $74
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $70
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $6C
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $68
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $64
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $60
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $5C
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $58
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $54
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $50
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $4C
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $48
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $44
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $40
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $3C
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $38
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $34
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $30
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $2C
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $28
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $24
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $20
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $1C
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $18
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $14
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $10
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $0C
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $08
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $04
            ld a, [hl]
            cp $EF
            call c, .vis
            ld l, $00
            ld a, [hl]
            cp $EF
            call c, .vis
            ld a, e
            add a, 4
            jp .endr
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
            or $80                          ; (SLOT_KEY and SLOT_STAMP: $80 | slot in their
            ld l, a                         ;   pages)
            ld h, high(SLOT_KEY)            ; resident with another coding: load it again
            ld a, b
            cp [hl]
            jr nz, .load
.ok2:       ld h, high(SLOT_STAMP)          ; stamp (in use this frame)
            ldh a, [oam_frame]
            ld [hl], a
            ld a, c
            ld [de], a                      ; tile = slot
            inc e
            ldh a, [o_a]                    ; NES v h p - - - pp -> GB p v h obp1 - pal(3)
            ld l, a                         ;   (OATTR), OBP1 below
            ld h, high(OATTR)
            ld a, [hl]
            bit 6, b                        ; (DMG: OBP1 if the coding says so)
            jr z, .o0
            or $10
.o0:        ld [de], a
            pop bc
            pop hl
            push hl                         ; OC_POS[entry] = its slot
            ld a, l
            and $FC
            ld l, a
            ld h, high(OC_POS)
            ld a, e
            sub 3
            ld [hl], a
            inc l
            ld a, [OC_EPO]
            ld [hl], a
            pop hl
            ld a, e                         ; the slot below (filled from the end)
            sub 7
            ld e, a
            ret nc
            pop af                          ; slot 0 filled: more than 40 in view; the
            jp oc_fwd                       ;   forward conversion (drops the last ones)
.xr:        xor a                           ; out of view sideways: this entry's y hidden
            ld [de], a                      ;   again (else last frame's x and tile showed)
            ret
.alloc:     call sl_chk
            jr c, .dfr
            ld a, b
            ldh [o_key], a
            call spr_alloc
            ld c, a
            jr .ok
.load:      ld a, [hl]                      ; stale with this coding (a page upload since):
            xor b                           ;   its bytes the same? (spr_mat brings it into
            cp $80                          ;   the shadow now, wtmp = 1 if unchanged)
            jr nz, .ld2
            call sl_chk                     ; (the copy from ROM counts as a load: at most
            jr c, .dfr                      ;   SL_MAX a frame, a battle start's party spread)
            ldh a, [o_t]
            call spr_mat
            ld a, 3
            ld [$4000], a
            ldh a, [wtmp]
            and a
            jr z, .ld2
            ld [hl], b
            jr .ok2
.ld2:       call sl_chk
            jr c, .dfr
            ld a, b
            ldh [o_key], a
            call spr_load
            jr .ok
.dfr:       xor a                           ; (this frame's slot loads used up: no sprite
            ld [OAM_CLEAN], a               ;   shows this frame (OC_DF) and no other load
            inc a                           ;   can happen: the rest of the page is not
            ld [OC_DF], a                   ;   converted; the next conversion a whole one)
            pop bc
            pop hl
            pop hl                          ; (the return into the entry list)
            jp .endr
.ok:        ld a, 3                         ; (the load left cart RAM bank 0 on)
            ld [$4000], a
            ld a, c
            or $80
            ld l, a
            jr .ok2

; the incremental conversion (cart RAM bank 3 on; H = the page): occmp (bank OC_BANK) lists
; the entries that differ from the copy; each one keeps its GB slot (OC_POS) or leaves a
; hidden hole there; one that comes into view (no slot) or a tile not resident: the whole page
.inc:       push hl
            ld a, OC_BANK
            ldh [fc_bank], a
            ld a, h
            ld hl, occmp
            call rt_farcall
            pop hl
            jr c, .ab                       ; (more than 16 changed)
            ld a, c
            sub low(OC_LIST)
            jr z, .same
            ldh [o_cx], a                   ; entries left
            call oc_rev                     ; (entries above every GB one: ascending)
            xor a
            ld [OC_ST], a
            ld a, low(OC_LIST)
            ldh [o_y], a                    ; next one in the list
            ldh a, [cam_y]
            cpl
            add a, 18
            ld b, a
            ldh a, [cam_x]
            cpl
            add a, 9
            ld c, a
.il:        ldh a, [o_y]
            ld e, a
            inc a
            ldh [o_y], a
            ld d, high(OC_LIST)
            ld a, [de]
            ld l, a
            ld e, a
            ld d, high(OC_COPY)
            ld a, [de]                      ; a GB entry last time? (the copy, same camera)
            cp $EF
            jr nc, .o0n
            add a, b
            cp 160
            jr nc, .o0n
            inc e
            inc e
            inc e
            ld a, [de]
            ld e, l
            add a, c
            cp 168
            jr nc, .o0n
            ld a, 1
            jr .o1n
.o0n:       xor a
.o1n:       ld [OC_MISS], a
            ld a, [hl]                      ; one now?
            cp $EF
            jr nc, .nn
            add a, b
            cp 160
            jr nc, .nn
            inc l
            inc l
            inc l
            ld a, [hl]
            dec l
            dec l
            dec l
            add a, c
            cp 168
            jr nc, .nn
            ld a, [OC_MISS]
            and a
            jr z, .nw                       ; (comes into view: a free slot above / below?)
            inc d                           ; in its slot
            ld a, [de]
            dec d
.vp:        call .vput
            jr .cu
.nw:        call oc_new                     ; (a free slot above / below: A, OC_POS set)
            jp c, .ab
            jr .vp
.nn:        ld a, [OC_MISS]                 ; none now: its slot hidden
            and a
            jr z, .cu
            inc d
            ld a, [de]
            dec d
            push de
            ld e, a
            ld d, high(OAM_SH)
            xor a
            ld [de], a
            pop de
.cu:        ld a, [hl+]                     ; the copy updated
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl]
            ld [de], a
            ldh a, [o_cx]
            dec a
            ldh [o_cx], a
            jr nz, .il
            xor a
            ld [$4000], a
            ld a, 1
            ldh [oam_pending], a
            ret
.same:      xor a
            ld [$4000], a
            ret
.ab:        ld a, l                         ; (the whole page again: H = the page)
            jp .sv

; A = GB slot, HL -> entry (y), B / C = camera: the entry written there; its tile must be
; resident with its coding (else the whole page again)
.vput:      push de
            push hl
            ld e, a
            ld d, high(OAM_SH)
            ld a, [hl+]
            add a, b
            ld [de], a
            inc e
            ld a, [hl+]
            ldh [o_t], a
            ld a, [hl+]
            ldh [o_a], a
            ld a, [hl]
            add a, c
            ld [de], a
            inc e
            push bc
            ldh a, [o_a]
            and 3
            add a, low(SPAL_KEY)
            ld l, a
            ld h, high(SPAL_KEY)
            ld b, [hl]
            ldh a, [o_t]
            ld l, a
            ld h, high(SPR_SLOT)
            ld a, [hl]
            cp $FF
            jr z, .val                      ; (not resident: a slot now, within the cap)
            ld c, a
            or $80
            ld l, a
            ld h, high(SLOT_KEY)
            ld a, b
            cp [hl]
            jr nz, .vld                     ; (another coding: loaded again, or a stale key)
.vst:       ld h, high(SLOT_STAMP)
            ldh a, [oam_frame]
            ld [hl], a
            ld a, c
            ld [de], a
            inc e
            ldh a, [o_a]
            ld l, a
            ld h, high(OATTR)
            ld a, [hl]
            bit 6, b
            jr z, .v0
            or $10
.v0:        ld [de], a
            pop bc
            pop hl
            pop de
            ret
.val:       call sl_chk
            jr c, .vab
            call .stmp                      ; (first time in this conversion: the slots in use
            ld a, b                         ;   stamped, so the new slot is none of them)
            ldh [o_key], a
            call spr_alloc
            ld c, a
            jr .vre
.vld:       ld a, [hl]                      ; stale with this coding: the same bytes?
            xor b
            cp $80
            jr nz, .vl2
            call sl_chk
            jr c, .vab
            ldh a, [o_t]
            call spr_mat
            ld a, 3
            ld [$4000], a
            ldh a, [wtmp]
            and a
            jr z, .vl2
            ld [hl], b
            jr .vst
.vl2:       call sl_chk
            jr c, .vab
            ld a, b
            ldh [o_key], a
            call spr_load
.vre:       ld a, 3                         ; (the load left cart RAM bank 0 on)
            ld [$4000], a
            ld a, c
            or $80
            ld l, a
            jr .vst
.vab:       pop bc
            pop hl
            pop de
            pop af                          ; (the return address)
            jr .ab
; the GB table's slots stamped with a new frame number (once per conversion: OC_ST). Keeps
; all but A, F.
.stmp:      ld a, [OC_ST]
            and a
            ret nz
            inc a
            ld [OC_ST], a
            push bc
            push de
            push hl
            ldh a, [oam_frame]
            inc a
            ldh [oam_frame], a
            ld d, a
            ld hl, OAM_SH
            ld e, 40
.sp:        ld a, [hl+]
            and a
            jr z, .sn
            inc l
            ld a, [hl]
            push hl
            or $80
            ld l, a
            ld h, high(SLOT_STAMP)
            ld [hl], d
            pop hl
            inc l
            inc l
            jr .sc
.sn:        inc l
            inc l
            inc l
.sc:        dec e
            jr nz, .sp
            pop hl
            pop de
            pop bc
            ret

; A = p (the lowest GB slot in use; 160: none): the slots below that the last conversion
; used are hidden; OAM_USED = the count
.endr:      ld e, a
            ld [OC_BOT], a
            ld a, [OC_DF]                   ; a load deferred: no sprites this frame (they
            and a                           ;   appear together once their tiles are in,
            jr z, .nd                       ;   not part of a figure)
            ld hl, OAM_SH
            ld b, 40
            xor a
.hd:        ld [hl+], a
            inc l
            inc l
            inc l
            dec b
            jr nz, .hd
            ld [OAM_USED], a
            jr .rx
.nd:
            ld a, [OC_TOP]                  ; every slot below p hidden (a layout with free
            add a, 4                        ;   slots at both ends: whatever an earlier one
            sub e                           ;   left there); OAM_USED = the slots in use
            rrca
            rrca
            ld [OAM_USED], a
            ld d, high(OAM_SH)
            xor a
.rc:        inc e
            dec e
            jr z, .rx
            dec e
            dec e
            dec e
            dec e
            ld [de], a
            jr .rc
.rx:        xor a
            ld [$4000], a
            inc a
            ldh [oam_pending], a
            ret


; the forward conversion (more than 40 in view): slots 0-39, the last entries dropped
oc_fwd:     xor a
            ld [OAM_CLEAN], a
            ld [OC_BOT], a                  ; (a full layout: the next whole conversion leaves
            ld a, 156                       ;   no slots free at the top, no overflow again)
            ld [OC_TOP], a
            xor a
            ld [$4000], a
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
            call c, .visF
            ld l, $04
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $08
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $0C
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $10
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $14
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $18
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $1C
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $20
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $24
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $28
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $2C
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $30
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $34
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $38
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $3C
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $40
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $44
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $48
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $4C
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $50
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $54
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $58
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $5C
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $60
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $64
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $68
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $6C
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $70
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $74
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $78
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $7C
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $80
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $84
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $88
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $8C
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $90
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $94
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $98
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $9C
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $A0
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $A4
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $A8
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $AC
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $B0
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $B4
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $B8
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $BC
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $C0
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $C4
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $C8
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $CC
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $D0
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $D4
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $D8
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $DC
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $E0
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $E4
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $E8
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $EC
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $F0
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $F4
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $F8
            ld a, [hl]
            cp $EF
            call c, .visF
            ld l, $FC
            ld a, [hl]
            cp $EF
            call c, .visF
            jp .fullF
.visF:       add a, b                        ; HL -> entry, A = NES y
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
            jr nc, .xrF
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
            jr z, .allocF
            ld c, a
            or $80                          ; (SLOT_KEY and SLOT_STAMP: $80 | slot in their
            ld l, a                         ;   pages)
            ld h, high(SLOT_KEY)            ; resident with another coding: load it again
            ld a, b
            cp [hl]
            jr nz, .loadF
.ok2F:       ld h, high(SLOT_STAMP)          ; stamp (in use this frame)
            ldh a, [oam_frame]
            ld [hl], a
            ld a, c
            ld [de], a                      ; tile = slot
            inc e
            ldh a, [o_a]                    ; NES v h p - - - pp -> GB p v h obp1 - pal(3)
            ld l, a                         ;   (OATTR), OBP1 below
            ld h, high(OATTR)
            ld a, [hl]
            bit 6, b                        ; (DMG: OBP1 if the coding says so)
            jr z, .o0F
            or $10
.o0F:        ld [de], a
            inc e
            pop bc
            pop hl
            ld a, e
            cp 160
            ret nz
            pop af                          ; GB table full: the scan ends
            jr .fullF
.xrF:        xor a                           ; out of view sideways: this entry's y hidden
            ld [de], a                      ;   again (else last frame's x and tile showed)
            ret
.allocF:     call sl_chk
            jr c, .dfrF
            ld a, b
            ldh [o_key], a
            call spr_alloc
            ld c, a
            jr .okF
.loadF:      ld a, [hl]
            xor b
            cp $80
            jr nz, .ld2F
            call sl_chk
            jr c, .dfrF
            ldh a, [o_t]
            call spr_mat
            ldh a, [wtmp]
            and a
            jr z, .ld2F
            ld [hl], b
            jr .ok2F
.ld2F:       call sl_chk
            jr c, .dfrF
            ld a, b
            ldh [o_key], a
            call spr_load
            jr .okF
.dfrF:       dec e
            dec e
            xor a
            ld [de], a
            pop bc
            pop hl
            ret
.okF:        ld a, c
            or $80
            ld l, a
            jr .ok2F
.fullF:      ld a, e                         ; hide the GB sprites used last frame only
            rrca
            rrca
            ld c, a
            ld a, [OAM_USED]
            ld b, a
            ld a, c
            ld [OAM_USED], a
            ld a, b
            sub c
            jr c, .endF
            jr z, .endF
            ld b, a
            xor a
.clrF:       ld [de], a
            inc e
            inc e
            inc e
            inc e
            dec b
            jr nz, .clrF
.endF:       ld a, 1
            ldh [oam_pending], a
            ret


; ---- oamconv_b's compare (ROM bank OC_BANK, through rt_farcall; cart RAM bank 3 on): NES OAM
; page A against the copy, entries 63..0 unrolled (hidden in both: y only); the offsets of
; the entries that differ to OC_LIST. Out: C = low(OC_LIST) + their count; carry: more
; than 15 (the list is full).
section bank OC_BANK, $4000
occmp:      ld h, a
            ld bc, OC_LIST
            ld d, high(OC_COPY)
            ld l, $FC
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c63
            cp $EF
            jr nc, .n63
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c63
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c63
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n63
.c63:        ld a, $FC
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n63:
            ld l, $F8
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c62
            cp $EF
            jr nc, .n62
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c62
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c62
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n62
.c62:        ld a, $F8
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n62:
            ld l, $F4
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c61
            cp $EF
            jr nc, .n61
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c61
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c61
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n61
.c61:        ld a, $F4
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n61:
            ld l, $F0
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c60
            cp $EF
            jr nc, .n60
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c60
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c60
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n60
.c60:        ld a, $F0
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n60:
            ld l, $EC
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c59
            cp $EF
            jr nc, .n59
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c59
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c59
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n59
.c59:        ld a, $EC
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n59:
            ld l, $E8
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c58
            cp $EF
            jr nc, .n58
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c58
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c58
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n58
.c58:        ld a, $E8
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n58:
            ld l, $E4
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c57
            cp $EF
            jr nc, .n57
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c57
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c57
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n57
.c57:        ld a, $E4
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n57:
            ld l, $E0
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c56
            cp $EF
            jr nc, .n56
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c56
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c56
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n56
.c56:        ld a, $E0
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n56:
            ld l, $DC
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c55
            cp $EF
            jr nc, .n55
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c55
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c55
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n55
.c55:        ld a, $DC
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n55:
            ld l, $D8
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c54
            cp $EF
            jr nc, .n54
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c54
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c54
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n54
.c54:        ld a, $D8
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n54:
            ld l, $D4
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c53
            cp $EF
            jr nc, .n53
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c53
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c53
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n53
.c53:        ld a, $D4
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n53:
            ld l, $D0
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c52
            cp $EF
            jr nc, .n52
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c52
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c52
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n52
.c52:        ld a, $D0
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n52:
            ld l, $CC
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c51
            cp $EF
            jr nc, .n51
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c51
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c51
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n51
.c51:        ld a, $CC
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n51:
            ld l, $C8
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c50
            cp $EF
            jr nc, .n50
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c50
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c50
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n50
.c50:        ld a, $C8
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n50:
            ld l, $C4
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c49
            cp $EF
            jr nc, .n49
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c49
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c49
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n49
.c49:        ld a, $C4
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n49:
            ld l, $C0
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c48
            cp $EF
            jr nc, .n48
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c48
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c48
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n48
.c48:        ld a, $C0
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n48:
            ld l, $BC
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c47
            cp $EF
            jr nc, .n47
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c47
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c47
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n47
.c47:        ld a, $BC
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n47:
            ld l, $B8
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c46
            cp $EF
            jr nc, .n46
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c46
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c46
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n46
.c46:        ld a, $B8
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n46:
            ld l, $B4
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c45
            cp $EF
            jr nc, .n45
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c45
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c45
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n45
.c45:        ld a, $B4
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n45:
            ld l, $B0
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c44
            cp $EF
            jr nc, .n44
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c44
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c44
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n44
.c44:        ld a, $B0
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n44:
            ld l, $AC
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c43
            cp $EF
            jr nc, .n43
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c43
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c43
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n43
.c43:        ld a, $AC
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n43:
            ld l, $A8
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c42
            cp $EF
            jr nc, .n42
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c42
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c42
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n42
.c42:        ld a, $A8
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n42:
            ld l, $A4
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c41
            cp $EF
            jr nc, .n41
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c41
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c41
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n41
.c41:        ld a, $A4
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n41:
            ld l, $A0
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c40
            cp $EF
            jr nc, .n40
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c40
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c40
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n40
.c40:        ld a, $A0
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n40:
            ld l, $9C
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c39
            cp $EF
            jr nc, .n39
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c39
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c39
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n39
.c39:        ld a, $9C
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n39:
            ld l, $98
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c38
            cp $EF
            jr nc, .n38
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c38
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c38
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n38
.c38:        ld a, $98
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n38:
            ld l, $94
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c37
            cp $EF
            jr nc, .n37
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c37
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c37
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n37
.c37:        ld a, $94
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n37:
            ld l, $90
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c36
            cp $EF
            jr nc, .n36
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c36
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c36
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n36
.c36:        ld a, $90
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n36:
            ld l, $8C
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c35
            cp $EF
            jr nc, .n35
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c35
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c35
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n35
.c35:        ld a, $8C
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n35:
            ld l, $88
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c34
            cp $EF
            jr nc, .n34
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c34
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c34
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n34
.c34:        ld a, $88
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n34:
            ld l, $84
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c33
            cp $EF
            jr nc, .n33
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c33
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c33
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n33
.c33:        ld a, $84
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n33:
            ld l, $80
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c32
            cp $EF
            jr nc, .n32
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c32
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c32
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n32
.c32:        ld a, $80
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n32:
            ld l, $7C
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c31
            cp $EF
            jr nc, .n31
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c31
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c31
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n31
.c31:        ld a, $7C
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n31:
            ld l, $78
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c30
            cp $EF
            jr nc, .n30
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c30
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c30
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n30
.c30:        ld a, $78
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n30:
            ld l, $74
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c29
            cp $EF
            jr nc, .n29
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c29
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c29
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n29
.c29:        ld a, $74
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n29:
            ld l, $70
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c28
            cp $EF
            jr nc, .n28
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c28
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c28
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n28
.c28:        ld a, $70
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n28:
            ld l, $6C
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c27
            cp $EF
            jr nc, .n27
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c27
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c27
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n27
.c27:        ld a, $6C
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n27:
            ld l, $68
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c26
            cp $EF
            jr nc, .n26
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c26
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c26
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n26
.c26:        ld a, $68
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n26:
            ld l, $64
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c25
            cp $EF
            jr nc, .n25
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c25
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c25
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n25
.c25:        ld a, $64
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n25:
            ld l, $60
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c24
            cp $EF
            jr nc, .n24
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c24
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c24
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n24
.c24:        ld a, $60
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n24:
            ld l, $5C
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c23
            cp $EF
            jr nc, .n23
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c23
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c23
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n23
.c23:        ld a, $5C
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n23:
            ld l, $58
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c22
            cp $EF
            jr nc, .n22
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c22
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c22
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n22
.c22:        ld a, $58
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n22:
            ld l, $54
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c21
            cp $EF
            jr nc, .n21
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c21
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c21
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n21
.c21:        ld a, $54
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n21:
            ld l, $50
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c20
            cp $EF
            jr nc, .n20
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c20
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c20
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n20
.c20:        ld a, $50
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n20:
            ld l, $4C
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c19
            cp $EF
            jr nc, .n19
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c19
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c19
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n19
.c19:        ld a, $4C
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n19:
            ld l, $48
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c18
            cp $EF
            jr nc, .n18
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c18
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c18
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n18
.c18:        ld a, $48
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n18:
            ld l, $44
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c17
            cp $EF
            jr nc, .n17
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c17
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c17
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n17
.c17:        ld a, $44
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n17:
            ld l, $40
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c16
            cp $EF
            jr nc, .n16
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c16
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c16
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n16
.c16:        ld a, $40
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n16:
            ld l, $3C
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c15
            cp $EF
            jr nc, .n15
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c15
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c15
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n15
.c15:        ld a, $3C
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n15:
            ld l, $38
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c14
            cp $EF
            jr nc, .n14
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c14
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c14
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n14
.c14:        ld a, $38
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n14:
            ld l, $34
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c13
            cp $EF
            jr nc, .n13
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c13
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c13
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n13
.c13:        ld a, $34
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n13:
            ld l, $30
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c12
            cp $EF
            jr nc, .n12
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c12
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c12
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n12
.c12:        ld a, $30
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n12:
            ld l, $2C
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c11
            cp $EF
            jr nc, .n11
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c11
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c11
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n11
.c11:        ld a, $2C
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n11:
            ld l, $28
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c10
            cp $EF
            jr nc, .n10
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c10
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c10
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n10
.c10:        ld a, $28
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n10:
            ld l, $24
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c9
            cp $EF
            jr nc, .n9
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c9
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c9
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n9
.c9:        ld a, $24
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n9:
            ld l, $20
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c8
            cp $EF
            jr nc, .n8
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c8
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c8
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n8
.c8:        ld a, $20
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n8:
            ld l, $1C
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c7
            cp $EF
            jr nc, .n7
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c7
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c7
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n7
.c7:        ld a, $1C
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n7:
            ld l, $18
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c6
            cp $EF
            jr nc, .n6
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c6
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c6
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n6
.c6:        ld a, $18
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n6:
            ld l, $14
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c5
            cp $EF
            jr nc, .n5
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c5
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c5
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n5
.c5:        ld a, $14
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n5:
            ld l, $10
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c4
            cp $EF
            jr nc, .n4
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c4
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c4
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n4
.c4:        ld a, $10
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n4:
            ld l, $0C
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c3
            cp $EF
            jr nc, .n3
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c3
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c3
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n3
.c3:        ld a, $0C
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n3:
            ld l, $08
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c2
            cp $EF
            jr nc, .n2
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c2
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c2
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n2
.c2:        ld a, $08
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n2:
            ld l, $04
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c1
            cp $EF
            jr nc, .n1
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c1
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c1
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n1
.c1:        ld a, $04
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n1:
            ld l, $00
            ld e, l
            ld a, [de]
            cp [hl]
            jr nz, .c0
            cp $EF
            jr nc, .n0
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c0
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr nz, .c0
            inc l
            inc e
            ld a, [de]
            cp [hl]
            jr z, .n0
.c0:        ld a, $00
            ld [bc], a
            inc c
            ld a, c
            cp low(OC_LIST) + 16
            jp z, .over
.n0:
            and a
            ret
.over:      scf
            ret

; ---- b12:9ADA-9AFB (battle, every frame of a choice): $6AEF + x = (the byte at $6BB7 + T1[x] =
; $FF) ? $FF : T1[x] for x 0-8; $6AAC-$6ABD = T2. T1 / T2 = the ROM's tables at b12:9FF7 / 9F95,
; copied by build.py (B9AD_T). Out (at 9AFC): A = T2's last byte, X = 9, Y = $12; N = 0,
; Z = 1, C = 1; V kept.
section bank PF_BANK, $7300
b9ad_b:     ld hl, B9AD_T
            ld de, $A000 + $0AEF
            ld c, 9
.l1:        ld a, [hl+]
            push hl
            ld b, a
            add a, low($A000 + $0BB7)
            ld l, a
            ld a, high($A000 + $0BB7)
            adc a, 0
            ld h, a
            ld a, [hl]
            cp $FF
            jr z, .s
            ld a, b
.s:         ld [de], a
            inc de
            pop hl
            dec c
            jr nz, .l1
            ld de, $A000 + $0AAC            ; ($6AAC-$6ABD: one page)
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld b, a
            xor a
            ldh [nzv], a
            ld de, 9
            ld c, $12
            scf
            ld a, b
            ld b, 0
            ret

; (in bank 0's free space after sgb.s)
section bank 0, $2800
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
            jp z, .x
.n:         ld a, [NMI_CNT]
            ld [BLK_F], a
            ld a, [NMI_CNT + 1]
            ld [BLK_F + 1], a
            ld hl, NT_SH + 19 * 32 + 2      ; the shadow now; the GB map in the next vblank
                                            ;   (blk_cp: the four rows from the shadow,
                                            ;   before the queued writes) or at once with
                                            ;   the LCD off. Only the message window's own
                                            ;   small-font tiles, $A8-$EF: the party and
                                            ;   command windows keep theirs (rows 19-22,
                                            ;   columns 2-19: one page)
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k0
            ld [hl], 0
.k0:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k1
            ld [hl], 0
.k1:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k2
            ld [hl], 0
.k2:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k3
            ld [hl], 0
.k3:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k4
            ld [hl], 0
.k4:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k5
            ld [hl], 0
.k5:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k6
            ld [hl], 0
.k6:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k7
            ld [hl], 0
.k7:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k8
            ld [hl], 0
.k8:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k9
            ld [hl], 0
.k9:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k10
            ld [hl], 0
.k10:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k11
            ld [hl], 0
.k11:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k12
            ld [hl], 0
.k12:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k13
            ld [hl], 0
.k13:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k14
            ld [hl], 0
.k14:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k15
            ld [hl], 0
.k15:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k16
            ld [hl], 0
.k16:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k17
            ld [hl], 0
.k17:        inc l
            ld a, 14
            add a, l
            ld l, a
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k18
            ld [hl], 0
.k18:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k19
            ld [hl], 0
.k19:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k20
            ld [hl], 0
.k20:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k21
            ld [hl], 0
.k21:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k22
            ld [hl], 0
.k22:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k23
            ld [hl], 0
.k23:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k24
            ld [hl], 0
.k24:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k25
            ld [hl], 0
.k25:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k26
            ld [hl], 0
.k26:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k27
            ld [hl], 0
.k27:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k28
            ld [hl], 0
.k28:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k29
            ld [hl], 0
.k29:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k30
            ld [hl], 0
.k30:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k31
            ld [hl], 0
.k31:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k32
            ld [hl], 0
.k32:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k33
            ld [hl], 0
.k33:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k34
            ld [hl], 0
.k34:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k35
            ld [hl], 0
.k35:        inc l
            ld a, 14
            add a, l
            ld l, a
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k36
            ld [hl], 0
.k36:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k37
            ld [hl], 0
.k37:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k38
            ld [hl], 0
.k38:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k39
            ld [hl], 0
.k39:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k40
            ld [hl], 0
.k40:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k41
            ld [hl], 0
.k41:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k42
            ld [hl], 0
.k42:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k43
            ld [hl], 0
.k43:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k44
            ld [hl], 0
.k44:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k45
            ld [hl], 0
.k45:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k46
            ld [hl], 0
.k46:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k47
            ld [hl], 0
.k47:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k48
            ld [hl], 0
.k48:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k49
            ld [hl], 0
.k49:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k50
            ld [hl], 0
.k50:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k51
            ld [hl], 0
.k51:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k52
            ld [hl], 0
.k52:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k53
            ld [hl], 0
.k53:        inc l
            ld a, 14
            add a, l
            ld l, a
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k54
            ld [hl], 0
.k54:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k55
            ld [hl], 0
.k55:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k56
            ld [hl], 0
.k56:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k57
            ld [hl], 0
.k57:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k58
            ld [hl], 0
.k58:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k59
            ld [hl], 0
.k59:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k60
            ld [hl], 0
.k60:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k61
            ld [hl], 0
.k61:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k62
            ld [hl], 0
.k62:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k63
            ld [hl], 0
.k63:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k64
            ld [hl], 0
.k64:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k65
            ld [hl], 0
.k65:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k66
            ld [hl], 0
.k66:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k67
            ld [hl], 0
.k67:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k68
            ld [hl], 0
.k68:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k69
            ld [hl], 0
.k69:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k70
            ld [hl], 0
.k70:        inc l
            ld a, [hl]
            sub $A8
            cp $48
            jr nc, .k71
            ld [hl], 0
.k71:        inc l
            ldh a, [$FF40]
            bit 7, a
            jr z, .off
            ld a, 1
            ld [BLK_REQ], a
.x:         pop hl
            pop de
            pop bc
            pop af
            ret
.off:       call blk_cp
            jr .x


; ---- JMP (P) of a pointer just loaded from a jump table with Y (recomp.py table_jump): HL ->
; P, N, then per entry the NES address and its GB bank / address. The pointer is checked
; against Y's entry; anything else goes through the dynamic jump. A, F kept.
rt_tjump:   push af
            push de
            ld a, [hl+]
            ld e, a
            ld d, high(NES_RAM)             ; DE = the pointer
            ld a, c
            rrca
            jr c, .dyn                      ; (Y odd)
            cp [hl]
            jr nc, .dyn                     ; (past the table)
            inc hl
            push bc
            ld c, a
            add a, a
            add a, a
            add a, c
            ld c, a
            ld b, 0
            add hl, bc
            pop bc
            ld a, [de]
            cp [hl]
            jr nz, .dyn
            inc e
            inc hl
            ld a, [de]
            cp [hl]
            jr nz, .dyn1
            inc hl
            ld a, [hl+]
            ldh [fc_bank], a
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            pop de
            pop af
            jp rt_dyn_go
.dyn1:      dec e
.dyn:       ld h, d
            ld l, e
            pop de
            pop af
            jp rt_jmp_ind

; ---- farjsr's .go (ExRAM: LDA FARHI,X / PHA / LDA FARLO,X / PHA / RTS, an idiom): far routine
; X directly (FARX, build.py: count, then per routine its FARLO byte and GB bank / address).
; A = the FARLO byte, N / Z from it; C, V kept.
rt_farx:    pop hl                          ; (the idiom's return: this is a jump)
            push af
            ld hl, FARX
            ld a, e
            cp [hl]
            jp nc, rt_fatal
            inc hl
            add a, a
            add a, a
            add a, l
            ld l, a
            jr nc, .h
            inc h
.h:         ld a, [hl+]
            ldh [nzv], a
            ldh [sv_a], a
            ld a, [hl+]
            ldh [fc_bank], a
            inc a                           ; ($FF: a far routine run natively, its bank-0
            jr z, .nat                      ;   trampoline: a jump; it returns as the RTS)
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            pop af
            ldh a, [sv_a]
            inc a
            dec a
            jp rt_dyn_go
.nat:       ld a, [hl+]
            ld h, [hl]
            ld l, a
            pop af
            ldh a, [sv_a]
            inc a
            dec a
            jp hl

; ---- b12:BF8F: swap $90-$9F with $6D97-$6DA6 (cart RAM bank 0; one page). Out: A = the old
; $9F, X = 16, Y = 0; N = 0, Z = 1; C kept.
hle_swap90: push af
            ld hl, NES_RAM + $90
            ld de, $AD97
            ld a, [de]
            ld b, [hl]
            ld [hl+], a
            ld a, b
            ld [de], a
            inc e
            ld a, [de]
            ld b, [hl]
            ld [hl+], a
            ld a, b
            ld [de], a
            inc e
            ld a, [de]
            ld b, [hl]
            ld [hl+], a
            ld a, b
            ld [de], a
            inc e
            ld a, [de]
            ld b, [hl]
            ld [hl+], a
            ld a, b
            ld [de], a
            inc e
            ld a, [de]
            ld b, [hl]
            ld [hl+], a
            ld a, b
            ld [de], a
            inc e
            ld a, [de]
            ld b, [hl]
            ld [hl+], a
            ld a, b
            ld [de], a
            inc e
            ld a, [de]
            ld b, [hl]
            ld [hl+], a
            ld a, b
            ld [de], a
            inc e
            ld a, [de]
            ld b, [hl]
            ld [hl+], a
            ld a, b
            ld [de], a
            inc e
            ld a, [de]
            ld b, [hl]
            ld [hl+], a
            ld a, b
            ld [de], a
            inc e
            ld a, [de]
            ld b, [hl]
            ld [hl+], a
            ld a, b
            ld [de], a
            inc e
            ld a, [de]
            ld b, [hl]
            ld [hl+], a
            ld a, b
            ld [de], a
            inc e
            ld a, [de]
            ld b, [hl]
            ld [hl+], a
            ld a, b
            ld [de], a
            inc e
            ld a, [de]
            ld b, [hl]
            ld [hl+], a
            ld a, b
            ld [de], a
            inc e
            ld a, [de]
            ld b, [hl]
            ld [hl+], a
            ld a, b
            ld [de], a
            inc e
            ld a, [de]
            ld b, [hl]
            ld [hl+], a
            ld a, b
            ld [de], a
            inc e
            ld a, [de]
            ld b, [hl]
            ld [hl+], a
            ld a, b
            ld [de], a
            inc e
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

; (moved to bank 0's free space)
hle_mapdec: ld a, e
            ld [MDC_X], a
            ld a, [NES_RAM + $12]           ; a standard map's whole decompression ($7000):
            and a                           ;   decompressed at build time (MAPS_BANK0's
            jr nz, .dec                     ;   table: NES bank, source; build.py), copied
            ld a, [NES_RAM + $13]
            and $F0
            cp $70
            jr nz, .dec
            call mpre
            ret c
.dec:       ldh a, [data_bank8]
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
            inc l
            jr nz, .lp
            call .ih
            jr .lp
.run:       cp $FF
            jp z, mdc_end
            and $7F
            ld [NES_RAM + $14], a
            ld b, a
            call .inc
            ld c, [hl]                      ; count (0: 256)
            ld a, c
            dec a
            cp 8                            ; (1-8: here; else fillde)
            ld a, b
            jr nc, .fl
.sr:        ld [de], a
            inc de
            dec c
            jr nz, .sr
            jr .fd
.fl:        call fillde
.fd:
            xor a
            ld [MDC_X], a
            inc l
            jr nz, .lp
            call .ih
            jr .lp
.inc:       inc l
            ret nz
.ih:        inc h
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


; the table: 10 bytes an entry (NES bank, source low / high, GB bank, page, the source's end
; low / high, flags (bit 0: a run: X and $14 below), X, $14), $FF at the end. Carry: done, RAM
; and registers as mdc_end leaves them.
mpre:       ld a, MAPS_BANK0
            ld [$2000], a
            ldh a, [nes_bank8]              ; the overworld's rows (bank 1, row $2C, 256
            cp 1                            ;   bytes to $7000 + (row & 15) * 256): table at
            jr z, .ow                       ;   $5000, 16 bytes a row
            ld a, [NES_RAM + $13]
            cp $70
            jr nz, .nf
            ld hl, $4000
.f:         ld a, [hl]
            cp $FF
            jr z, .nf
            ld b, a
            ldh a, [nes_bank8]
            cp b
            jr nz, .n0
            inc hl
            ld a, [NES_RAM + $10]
            cp [hl]
            jr nz, .n1
            inc hl
            ld a, [NES_RAM + $11]
            cp [hl]
            jr nz, .n2
            inc hl
            ld a, [hl+]
            ld b, a                         ; B = GB bank
            ld a, [hl+]
            ld c, a                         ; C = page
            ld a, [hl+]
            ld [NES_RAM + $10], a
            ld a, [hl+]
            ld [NES_RAM + $11], a
            ld a, [hl+]
            rrca
            jr nc, .nr
            ld a, [hl+]
            ld [MDC_X], a
            ld a, [hl]
            ld [NES_RAM + $14], a
.nr:        ld a, b
            ld [$2000], a
            ld h, c
            ld l, 0
            ld de, $B000
.cp:
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            jr nz, .cp
            inc d
            ld a, d
            cp $C0
            jr nz, .cp
            xor a
            ld [NES_RAM + $12], a
            ld a, $80
            ld [NES_RAM + $13], a
.end:       ldh a, [code_bank]
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
.n0:        inc hl
.n1:        inc hl
.n2:        ld de, 8
            add hl, de
            jr .f
.nf:        and a                           ; (not found: carry clear)
            ret
.ow:        ld a, [NES_RAM + $2C]
            ld b, a
            swap a
            and $F0
            ld l, a
            ld a, b
            swap a
            and $0F
            add a, $50
            ld h, a
            ld a, [hl+]
            cp $FF
            jr z, .nf                       ; (no entry)
            ld b, a
            ld a, [NES_RAM + $10]
            cp b
            jr nz, .nf
            ld a, [NES_RAM + $11]
            cp [hl]
            jr nz, .nf
            inc hl
            ld a, [hl+]
            ld b, a                         ; B = GB bank
            ld a, [hl+]
            ld c, a                         ; C = page
            ld a, [hl+]
            ld [NES_RAM + $10], a
            ld a, [hl+]
            ld [NES_RAM + $11], a
            ld a, [hl+]
            rrca
            jr nc, .or
            ld a, [hl+]
            ld [MDC_X], a
            ld a, [hl]
            ld [NES_RAM + $14], a
.or:        ld a, b
            ld [$2000], a
            ld h, c
            ld l, 0
            ld a, [NES_RAM + $13]
            ld b, a
            add a, $40
            ld d, a
            ld e, 0
.oc:
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            jr nz, .oc
            ld a, b
            inc a
            ld [NES_RAM + $13], a
            jr .end


; ---- palup2_b's fast path (v = $3F00 + C, increment 1): C = the first index, HL -> its colour
; ($03D0 from index 16 on). Each colour compared with the shadow at its constant index; a
; changed one to the shadow and its flags (pu_chg, as rt_ppu_w7g's palette write).
section bank HLE_BANK, $6000
pu_fast:    ld a, c
            cp 32
            jr nc, .end
            push hl
            ld l, c
            ld h, 0
            ld d, h
            ld e, l
            add hl, hl
            add hl, de
            add hl, hl
            add hl, hl
            add hl, de                      ; C * 13 (one entry)
            cp 16
            jr c, .lo
            inc hl                          ; (past the source reload after entry 15)
            inc hl
            inc hl
.lo:        ld de, .e0
            add hl, de
            ld d, h
            ld e, l
            pop hl
            push de
            ret
.e0:        ld a, [hl+]
            ld b, a
            ld e, $00
            ld a, [PAL_SH + $00]
            xor b
            and $3F
            call nz, pu_chg
.e1:        ld a, [hl+]
            ld b, a
            ld e, $01
            ld a, [PAL_SH + $01]
            xor b
            and $3F
            call nz, pu_chg
.e2:        ld a, [hl+]
            ld b, a
            ld e, $02
            ld a, [PAL_SH + $02]
            xor b
            and $3F
            call nz, pu_chg
.e3:        ld a, [hl+]
            ld b, a
            ld e, $03
            ld a, [PAL_SH + $03]
            xor b
            and $3F
            call nz, pu_chg
.e4:        ld a, [hl+]
            ld b, a
            ld e, $04
            ld a, [PAL_SH + $04]
            xor b
            and $3F
            call nz, pu_chg
.e5:        ld a, [hl+]
            ld b, a
            ld e, $05
            ld a, [PAL_SH + $05]
            xor b
            and $3F
            call nz, pu_chg
.e6:        ld a, [hl+]
            ld b, a
            ld e, $06
            ld a, [PAL_SH + $06]
            xor b
            and $3F
            call nz, pu_chg
.e7:        ld a, [hl+]
            ld b, a
            ld e, $07
            ld a, [PAL_SH + $07]
            xor b
            and $3F
            call nz, pu_chg
.e8:        ld a, [hl+]
            ld b, a
            ld e, $08
            ld a, [PAL_SH + $08]
            xor b
            and $3F
            call nz, pu_chg
.e9:        ld a, [hl+]
            ld b, a
            ld e, $09
            ld a, [PAL_SH + $09]
            xor b
            and $3F
            call nz, pu_chg
.e10:        ld a, [hl+]
            ld b, a
            ld e, $0A
            ld a, [PAL_SH + $0A]
            xor b
            and $3F
            call nz, pu_chg
.e11:        ld a, [hl+]
            ld b, a
            ld e, $0B
            ld a, [PAL_SH + $0B]
            xor b
            and $3F
            call nz, pu_chg
.e12:        ld a, [hl+]
            ld b, a
            ld e, $0C
            ld a, [PAL_SH + $0C]
            xor b
            and $3F
            call nz, pu_chg
.e13:        ld a, [hl+]
            ld b, a
            ld e, $0D
            ld a, [PAL_SH + $0D]
            xor b
            and $3F
            call nz, pu_chg
.e14:        ld a, [hl+]
            ld b, a
            ld e, $0E
            ld a, [PAL_SH + $0E]
            xor b
            and $3F
            call nz, pu_chg
.e15:        ld a, [hl+]
            ld b, a
            ld e, $0F
            ld a, [PAL_SH + $0F]
            xor b
            and $3F
            call nz, pu_chg
            ld hl, NES_RAM + $03D0
.e16:        ld a, [hl+]
            ld b, a
            ld e, $00
            ld a, [PAL_SH + $00]
            xor b
            and $3F
            call nz, pu_chg
.e17:        ld a, [hl+]
            ld b, a
            ld e, $11
            ld a, [PAL_SH + $11]
            xor b
            and $3F
            call nz, pu_chg
.e18:        ld a, [hl+]
            ld b, a
            ld e, $12
            ld a, [PAL_SH + $12]
            xor b
            and $3F
            call nz, pu_chg
.e19:        ld a, [hl+]
            ld b, a
            ld e, $13
            ld a, [PAL_SH + $13]
            xor b
            and $3F
            call nz, pu_chg
.e20:        ld a, [hl+]
            ld b, a
            ld e, $04
            ld a, [PAL_SH + $04]
            xor b
            and $3F
            call nz, pu_chg
.e21:        ld a, [hl+]
            ld b, a
            ld e, $15
            ld a, [PAL_SH + $15]
            xor b
            and $3F
            call nz, pu_chg
.e22:        ld a, [hl+]
            ld b, a
            ld e, $16
            ld a, [PAL_SH + $16]
            xor b
            and $3F
            call nz, pu_chg
.e23:        ld a, [hl+]
            ld b, a
            ld e, $17
            ld a, [PAL_SH + $17]
            xor b
            and $3F
            call nz, pu_chg
.e24:        ld a, [hl+]
            ld b, a
            ld e, $08
            ld a, [PAL_SH + $08]
            xor b
            and $3F
            call nz, pu_chg
.e25:        ld a, [hl+]
            ld b, a
            ld e, $19
            ld a, [PAL_SH + $19]
            xor b
            and $3F
            call nz, pu_chg
.e26:        ld a, [hl+]
            ld b, a
            ld e, $1A
            ld a, [PAL_SH + $1A]
            xor b
            and $3F
            call nz, pu_chg
.e27:        ld a, [hl+]
            ld b, a
            ld e, $1B
            ld a, [PAL_SH + $1B]
            xor b
            and $3F
            call nz, pu_chg
.e28:        ld a, [hl+]
            ld b, a
            ld e, $0C
            ld a, [PAL_SH + $0C]
            xor b
            and $3F
            call nz, pu_chg
.e29:        ld a, [hl+]
            ld b, a
            ld e, $1D
            ld a, [PAL_SH + $1D]
            xor b
            and $3F
            call nz, pu_chg
.e30:        ld a, [hl+]
            ld b, a
            ld e, $1E
            ld a, [PAL_SH + $1E]
            xor b
            and $3F
            call nz, pu_chg
.e31:        ld a, [hl+]
            ld b, a
            ld e, $1F
            ld a, [PAL_SH + $1F]
            xor b
            and $3F
            call nz, pu_chg
.end:       ld a, 32
            ldh [ppu_vl], a                 ; v = $3F20
            ld c, a
            jp palup2_b.x
pu_chg:     ld a, b
            and $3F
            ld d, high(PAL_SH)
            ld [de], a
            ld a, 1
            ldh [pal_dirty], a
            ldh [maps_due], a
            xor a
            ldh [pal_age], a
            ret

section bank 0, $3000
; ---- DMG deferred switch-on (bank 0 helpers). lon_start (rt_ppu_w1, the LCD off and the NES
; switching on): NZ = deferred to lon_b (not on the SGB or in the prologue, which keep the
; old path); lon_on: the LCD on, from the frame wait right after its tick
lon_start:  ldh a, [is_sgb]
            and a
            jr nz, .now
            ldh a, [pro_mode]
            and a
            jr nz, .now
            ld a, [LON_ST]
            and a
            ret nz                          ; (already pending)
            xor a
            ld [LON_SCN], a
            ld [LON_RDY], a
            ld [LON_LIM], a
            ld [LON_CNT], a
            inc a
            ld [LON_ST], a                  ; (NZ)
            ret
.now:       xor a                           ; (Z)
            ret
lon_on:     xor a
            ld [LON_RDY], a
            ld [LON_ST], a
            ld a, LCDC_ON
            ldh [$FF40], a
            ld a, 1
            ldh [lcd_on], a
            ret
lon_tramp:  ldh a, [lcd_on]
            and a
            ret nz
            push bc
            push de
            push hl
            ld hl, lon_b
            call hle_pfj
            pop hl
            pop de
            pop bc
            ret
; carry: not enough of the frame left for an atomic step (forced: never)
lon_half:   ld a, [LON_CNT]
            cp LON_MAXF
            ccf
            ccf
            ret nc
            ldh a, [$FF05]
            cp LON_HALF
            ccf
            ret
; carry: not enough of the frame left for a big atomic step (about half a frame)
lon_big:    ld a, [LON_CNT]
            cp LON_MAXF
            ccf
            ccf
            ret nc
            ldh a, [$FF05]
            cp LON_BIG
            ccf
            ret
; carry: the frame's time is up (a tick since the wait's entry, or TIMA at LON_END)
lon_time:   ld a, [LON_CNT]                 ; (pending LON_MAXF frames: no limit)
            cp LON_MAXF
            ccf
            ccf
            ret nc
            push hl
            ld hl, VBL_ENT
            ld a, [VBL_CNT]
            cp [hl]
            pop hl
            scf
            ret nz
            ldh a, [$FF05]
            cp LON_END
            ccf
            ret

; ---- lon_b (PF_BANK, from the frame wait while the LCD is off): the switch-on's map scan
; (scb_init / scb_row / scb_fin), palette maps and re-coding (rtb_b) in the frame's spare
; time; an atomic step only with LON_HALF left; a scan disturbed by writes (dmg_scan) or a
; sprite slot load (LON_DIRTY) starts again; done: LON_RDY (lon_on at the next frame start).
; Steps (LON_ST): 1 scan begin, 2 rows, 3 maps, 4 re-coding, 5 check, 6 waiting, 7 the
; one-palette scan's scb_settle.
section bank PF_BANK, $7400
lon_b:      ldh a, [code_bank]              ; (the bank-0 helpers come back to code_bank)
            push af
            ld a, PF_BANK
            ldh [code_bank], a
            ld a, [LON_CNT]                 ; (one more frame pending)
            cp 255
            jr z, .lp
            inc a
            ld [LON_CNT], a
.lp:        call lon_time
            jr c, .x
            ld a, [LON_ST]
            cp 1
            jr z, .s1
            cp 2
            jr z, .s2
            cp 3
            jr z, .s3
            cp 4
            jr z, .s4
            cp 5
            jr z, .s5
            cp 7
            jr z, .s7
.x:         pop af
            ldh [code_bank], a
            ret
.s1:        ldh a, [dmg_scan]
            and a
            jr z, .to3
            call lon_big                    ; (up to ~0.4 frames)
            jr c, .x
            xor a
            ld [LON_DIRTY], a
            ld [LON_ROW], a
            inc a
            ld [LON_SCN], a
            call scb_init                   ; (clears dmg_scan)
            jr c, .s1o                      ; (one palette: done)
            ld a, 2
            ld [LON_ST], a
            jr .lp
.s1o:       ld a, 7                         ; (one palette: scb_settle next)
            ld [LON_ST], a
            jr .lp
.s7:        call lon_big
            jr c, .x
            call scb_settle
            ld a, 1
            ldh [maps_due], a
.to3:       ld a, 3
            ld [LON_ST], a
            jr .lp
.s2:        ld a, [LON_DIRTY]
            ld b, a
            ldh a, [dmg_scan]
            or b
            jr nz, .rst
            ld a, [LON_ROW]
            cp 30
            jr z, .fin
            ld d, a
            call scb_row
            ld a, [LON_ROW]
            inc a
            ld [LON_ROW], a
            jr .lp
.fin:       call lon_half
            jr c, .x
            call scb_fin
            call lon_frm
            ld a, 1
            ldh [maps_due], a
            jr .to3
.rst:       ld a, 1                         ; (disturbed: the scan again)
            ld [LON_ST], a
            ldh [dmg_scan], a
            jr .lp
.s3:        ldh a, [maps_due]               ; palette maps (as dmg_frame: from the target
            and a                           ;   if the live palette is a fade of it, else once
            jr z, .to4                      ;   the palettes have been stable PAL_STABLE
            call lon_half                   ;   frames: a flash at a battle start does not
            jr c, .x                        ;   make the maps; forced: at once)
            ldh a, [in_battle]              ; a battle start: from the battle palette it fades
            bit 7, a                        ;   in to ($6D34), not its flashes
            jr nz, .mb
            call dmg_target
            jr c, .mn
            ldh a, [pal_age]
            cp 255
            jr z, .ma
            inc a
            ldh [pal_age], a
.ma:        cp PAL_STABLE
            jr nc, .mn
            ld a, [LON_CNT]
            cp LON_MAXF
            jr c, .x
.mn:        call dmg_maps_now
            jr .to4
.mb:        ld hl, $A000 + $0D34            ; (cart RAM bank 0)
            ld de, MPB
            ld b, 16
.mc:        ld a, [hl+]
            ld [de], a
            inc e
            dec b
            jr nz, .mc
            xor a
            ldh [maps_due], a
            ldh [maps_wait], a
            inc a
            ldh [sgb_dirty], a
            call dmg_maps
            ld a, 1
            ldh [pal_dirty], a
.to4:       ld a, 4
            ld [LON_ST], a
            jr .lp
.s4:        ld a, 1
            ld [LON_LIM], a
            ld a, [LON_SCN]
            call rtb_b
            xor a
            ld [LON_LIM], a
            call .dirty
            jr nz, .lp
            ld a, 5
            ld [LON_ST], a
            jr .lp
.s5:        ldh a, [dmg_scan]               ; anything since? that step again (palette
            and a                           ;   changes: dmg_frame once the LCD is on, as
            jr nz, .rst                     ;   after the old switch-on)
            call .dirty
            ld a, 4
            jr nz, .st
            ld a, 1
            ld [LON_RDY], a
            ld a, 6
.st:        ld [LON_ST], a
            jp .lp
.dirty:     ld hl, DIRTY_BM                 ; NZ: tiles still marked
            ld b, 32
            xor a
.d:         or [hl]
            inc l
            dec b
            jr nz, .d
            and a
            ret

; lon_b after its scan (the view's rows only; not in battle, where the camera stays): the
; other rows' cells marked in FRESH, checked in the frame waits once the LCD is on
lon_frm:    ldh a, [in_battle]
            bit 7, a
            ret nz
            ld a, [SC_VR]                   ; rows (VR + 18 .. VR + 29) mod 30
            add a, 18
            ld b, 12
.r:         cp 30
            jr c, .r0
            sub 30
.r0:        ld c, a
            add a, a
            add a, a
            ld l, a
            ld h, high(FRESH)
            ld a, $FF
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl], a
            ld a, c
            inc a
            dec b
            jr nz, .r
            xor a
            ld [FR_AGE], a
            ld [FR_EMPTY], a
            ld [FR_PEND], a
            ld [FR_POS], a
            inc a
            ld [FR_ANY], a
            ret

; ---- b12:9910-99D2 (battle, every frame: character A's six sprites) with the routines it runs
; (998D, 99B4, 99D3, 97E9), natively; RAM as FF1 leaves it: $68B3 = $6BA8 + A (palette), $68AF
; / $68B0 = x, $68B1 / $68B2 = y ($6AD3 / $6AD4 + 4A), $68B6 = 1 << A; down ($6AD1 bit A): tile
; $1A + $6AD5,Y, x = $84, y + 8, two rows of three; else (with $6AD2 bit A: palette 3, pose $18
; to $6AD6,Y, x = $8C) pose X = $6AD6,Y: three rows of two, tile $6AD5,Y + BDC_T[X] (the ROM's
; table at b12:A00C, copied by build.py); each sprite at OAM entry $68B5 (y, tile, palette, x)
; and $68B5 / $68B4 + 1; y + 8 after each row. Out (at the RTS): A = $68B1, N, Z, C, V of its
; last ADC #8; X = pose + 3 (down: 0), Y = 4A.
section bank PF_BANK, $7700
bdc_b:      ld c, a
            ld e, a
            add a, low($ABA8)
            ld l, a
            ld h, high($ABA8)
            ld a, [hl]
            ld [$A8B3], a
            ld a, c
            add a, a
            add a, a
            ld c, a                         ; C = Y = 4A
            add a, low($AAD3)
            ld l, a
            ld h, high($AAD3)
            ld a, [hl+]
            ld [$A8AF], a
            ld [$A8B0], a
            ld a, [hl]
            ld [$A8B1], a
            ld [$A8B2], a
            ld a, 1                         ; $68B6 = 1 << A
            ld b, e
            inc b
.sh:        dec b
            jr z, .sd
            add a, a
            jr .sh
.sd:        ld [$A8B6], a
            ld b, a
            ld e, 0                         ; (X = 0 after FF1's DEX loop)
            ld a, [$AAD1]
            and $0F
            and b
            jr nz, .dn
            ld a, [$AAD2]
            and $0F
            and b
            jr z, .np
            ld a, 3
            ld [$A8B3], a
            ld a, c
            add a, low($AAD6)
            ld l, a
            ld h, high($AAD6)
            ld [hl], $18
            ld a, $8C
            ld [$A8AF], a
            ld [$A8B0], a
.np:        ld a, c
            add a, low($AAD6)
            ld l, a
            ld h, high($AAD6)
            ld e, [hl]                      ; X = pose
            ld b, 3
.row:       ld a, c                         ; $68B4 = $6AD5,Y + BDC_T[X]; X + 1
            add a, low($AAD5)
            ld l, a
            ld h, high($AAD5)
            ld a, [hl]
            ld l, e
            ld h, high(BDC_T)
            add a, [hl]
            ld [$A8B4], a
            inc e
            ld a, [$A8B0]
            ld [$A8AF], a
            call .spr
            call .nx
            ld hl, $A8B5
            inc [hl]
            dec l
            inc [hl]
            call .yd
            dec b
            jr nz, .row
            jr .out
.dn:        ld a, c
            add a, low($AAD5)
            ld l, a
            ld h, high($AAD5)
            ld a, [hl]
            add a, $1A
            ld [$A8B4], a
            ld a, $84
            ld [$A8AF], a
            ld [$A8B0], a
            call .yd
            ld b, 2
.r3:        ld a, [$A8B0]
            ld [$A8AF], a
            call .spr
            call .nx
            call .nx
            ld hl, $A8B5
            inc [hl]
            dec l
            inc [hl]
            call .yd
            dec b
            jr nz, .r3
.out:       ld a, [$A8B1]                   ; flags of the last y + 8
            ld h, a
            sub 8
            cpl
            and h
            and $80
            rrca
            ldh [vfl], a                    ; V: before positive, after negative
            ld a, h
            ldh [nzv], a
            ld b, 0
            ld d, 0
            ld l, 0
            cp 8
            jr nc, .c0
            ld l, $10                       ; C: it wrapped
.c0:        and a
            jr nz, .z0
            set 7, l
.z0:        push hl
            pop af
            ret
.spr:       ld a, [$A8B5]                   ; 97E9: the sprite at entry $68B5
            add a, a
            add a, a
            ld l, a
            ld h, high(NES_RAM + $0200)
            ld a, [$A8B1]
            ld [hl+], a
            ld a, [$A8B4]
            ld [hl+], a
            ld a, [$A8B3]
            ld [hl+], a
            ld a, [$A8AF]
            ld [hl], a
            ret
.nx:        ld hl, $A8B5                    ; 99D3: entry + 1, tile + 1, x + 8, the sprite
            inc [hl]
            dec l
            inc [hl]
            ld hl, $A8AF
            ld a, [hl]
            add a, 8
            ld [hl], a
            jr .spr
.yd:        ld hl, $A8B1
            ld a, [hl]
            add a, 8
            ld [hl], a
            ret

; ---- c62:D25A PrepRowCol natively (FF1 turns 16 map tiles of a row / column into the five
; draw buffers: $0780 / $0790 / $07A0 / $07B0 / $07C0 + X = $0500 / $0580 / $0600 / $0680 /
; $0700 + tile). $2D bit 0: a 64x64 map at $7000 (ptr $10 / $11 from $2B / $2C, $12 = row
; bits; a row wraps within its 64 tiles, a column adds $40 with the page kept in $70-$7F);
; else the overworld's 16-row ring of 256 tiles ($10 = $2B, $11 = $70 | $2C & 15; a row: INC
; $10, a column: $11 + 1 in the ring). $2D bit 1: a column. RAM as FF1 leaves it ($10-$12);
; out (at the RTS): X = 16, Y = the last tile, A = the last value FF1 had (a row of the
; overworld: the last $0700 byte; a 64x64 row: $10; a column: $11), Z and C set (CPX #$10).
section bank PF_BANK, $6100
; the 16 tiles are gathered into $07C0-$07CF first (D = cart RAM page, B = low byte of the
; pointer, steps by mode), sh_u2 = OR of all tiles (bit 7: the slow per-tile path)
prc_b:      xor a
            ldh [sh_u2], a
            ld hl, NES_RAM + $07C0
            ld a, [NES_RAM + $2D]
            rrca
            jr nc, .ow
            ld a, [NES_RAM + $2C]           ; 64x64 map
            ld b, a
            rrca
            rrca
            and $C0
            ld c, a                         ; C = $12
            ld [NES_RAM + $12], a
            ld a, b
            srl a
            srl a
            or $70
            ld [NES_RAM + $11], a
            add a, $40                      ; ($7000 -> cart RAM $B000)
            ld d, a
            ld a, [NES_RAM + $2B]
            or c
            ld e, a                         ; E = $10
            ld a, [NES_RAM + $2D]
            and 2
            jr nz, .sc
.sr:        ld a, [de]                      ; a row: $10 = ($10 + 1) & $3F | $12
            ld [hl+], a
            ld b, a
            ldh a, [sh_u2]
            or b
            ldh [sh_u2], a
            ld a, e
            inc a
            and $3F
            or c
            ld e, a
            ld a, l
            cp low(NES_RAM + $07D0)
            jr nz, .sr
            ld a, e
            ld [NES_RAM + $10], a
            ldh [sh_u3], a                  ; (A out)
            jr .p2
.sc:        ld a, [de]                      ; a column: $10 + $40, carry into $11 (page
            ld [hl+], a                     ;   in $70-$7F)
            ld b, a
            ldh a, [sh_u2]
            or b
            ldh [sh_u2], a
            ld a, e
            add a, $40
            ld e, a
            ld a, d
            adc a, 0
            sub $40
            and $0F
            or $70
            ld c, a                         ; (C = $11)
            add a, $40
            ld d, a
            ld a, l
            cp low(NES_RAM + $07D0)
            jr nz, .sc
            ld a, e
            ld [NES_RAM + $10], a
            ld a, c
            ld [NES_RAM + $11], a
            ldh [sh_u3], a
            jr .p2
.ow:        ld a, [NES_RAM + $2C]           ; overworld
            and $0F
            or $70
            ld c, a                         ; C = $11
            ld [NES_RAM + $11], a
            add a, $40
            ld d, a
            ld a, [NES_RAM + $2B]
            ld e, a                         ; E = $10
            ld a, [NES_RAM + $2D]
            and 2
            jr nz, .oc
.or:        ld a, [de]                      ; a row: INC $10
            ld [hl+], a
            ld b, a
            ldh a, [sh_u2]
            or b
            ldh [sh_u2], a
            inc e
            ld a, l
            cp low(NES_RAM + $07D0)
            jr nz, .or
            ld a, e
            ld [NES_RAM + $10], a
            ld a, $FF                       ; (A out: the last $0700 byte)
            ldh [sh_u3], a
            jr .p2
.oc:        ld a, [de]                      ; a column: $11 = ($11 + 1) & 15 | $70
            ld [hl+], a
            ld b, a
            ldh a, [sh_u2]
            or b
            ldh [sh_u2], a
            ld a, c
            inc a
            and $0F
            or $70
            ld c, a
            add a, $40
            ld d, a
            ld a, l
            cp low(NES_RAM + $07D0)
            jr nz, .oc
            ld a, e
            ld [NES_RAM + $10], a
            ld a, c
            ld [NES_RAM + $11], a
            ldh [sh_u3], a
.p2:        ld a, [NES_RAM + $07CF]
            ldh [tmp_lo], a                 ; (Y out: the last tile)
            ldh a, [sh_u2]
            rla
            jr c, .slow
            ld hl, NES_RAM + $0780          ; all tiles below $80: five passes, each over
            ld de, NES_RAM + $07C0          ;   the 16 tiles (in $07C0-$07CF until the
            ld b, high(NES_RAM) + 5         ;   last pass replaces them in place)
            ld a, [de]
            inc e
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld e, low(NES_RAM + $07C0)
            ld a, [de]
            inc e
            or $80
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            or $80
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            or $80
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            or $80
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            or $80
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            or $80
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            or $80
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            or $80
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            or $80
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            or $80
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            or $80
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            or $80
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            or $80
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            or $80
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            or $80
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            or $80
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld e, low(NES_RAM + $07C0)
            inc b
            ld a, [de]
            inc e
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld e, low(NES_RAM + $07C0)
            ld a, [de]
            inc e
            or $80
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            or $80
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            or $80
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            or $80
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            or $80
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            or $80
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            or $80
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            or $80
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            or $80
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            or $80
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            or $80
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            or $80
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            or $80
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            or $80
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            or $80
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, [de]
            inc e
            or $80
            ld c, a
            ld a, [bc]
            ld [hl+], a
            inc b
            ld c, [hl]
            ld a, [bc]
            ld [hl+], a
            ld c, [hl]
            ld a, [bc]
            ld [hl+], a
            ld c, [hl]
            ld a, [bc]
            ld [hl+], a
            ld c, [hl]
            ld a, [bc]
            ld [hl+], a
            ld c, [hl]
            ld a, [bc]
            ld [hl+], a
            ld c, [hl]
            ld a, [bc]
            ld [hl+], a
            ld c, [hl]
            ld a, [bc]
            ld [hl+], a
            ld c, [hl]
            ld a, [bc]
            ld [hl+], a
            ld c, [hl]
            ld a, [bc]
            ld [hl+], a
            ld c, [hl]
            ld a, [bc]
            ld [hl+], a
            ld c, [hl]
            ld a, [bc]
            ld [hl+], a
            ld c, [hl]
            ld a, [bc]
            ld [hl+], a
            ld c, [hl]
            ld a, [bc]
            ld [hl+], a
            ld c, [hl]
            ld a, [bc]
            ld [hl+], a
            ld c, [hl]
            ld a, [bc]
            ld [hl+], a
            ld c, [hl]
            ld a, [bc]
            ld [hl+], a
.out:       ld a, [NES_RAM + $07CF]
            ld b, a                         ; (the last $0700 byte)
            ld a, [NES_RAM + $2D]           ; A out: an overworld row: that byte; else as
            and 3                           ;   saved in sh_u3
            jr z, .o2
            ldh a, [sh_u3]
            ld b, a
.o2:        ldh a, [tmp_lo]
            ld c, a                         ; Y = the last tile
            ld e, 16
            ld d, 0
            xor a
            ldh [nzv], a                    ; (Z = 1, N = 0)
            scf
            ld a, b
            ld b, 0
            ret
.slow:      ld e, 0                         ; (a tile $80 or above: tile by tile)
.sl:        ld a, e
            or $C0
            ld l, a
            ld h, high(NES_RAM) + 7
            ld a, [hl]
            call .put
            inc e
            ld a, e
            cp 16
            jr c, .sl
            jr .out
; one tile A at X = E: the five buffer bytes; A out = the $0700 byte. Keeps BCDE.
.put:       push bc
            ld c, a                         ; C = tile
            ld h, high(NES_RAM) + 7
            ld a, e
            or $80
            ld l, a                         ; HL = $0780 + X
            ld b, high(NES_RAM) + 5
            ld a, [bc]
            ld [hl], a
            set 4, l                        ; $0790 + X
            ld a, c
            rlca                            ; (carry: tile + $80 crosses a page)
            ld a, b
            adc a, 0
            ld b, a
            ld a, c
            xor $80
            ld c, a
            ld a, [bc]
            ld [hl], a
            ld a, l
            add a, $10
            ld l, a                         ; $07A0 + X
            ld a, c
            xor $80
            ld c, a
            ld b, high(NES_RAM) + 6
            ld a, [bc]
            ld [hl], a
            set 4, l                        ; $07B0 + X
            ld a, c
            rlca
            ld a, b
            adc a, 0
            ld b, a
            ld a, c
            xor $80
            ld c, a
            ld a, [bc]
            ld [hl], a
            ld a, l
            add a, $10
            ld l, a                         ; $07C0 + X
            ld a, c
            xor $80
            ld c, a
            ld b, high(NES_RAM) + 7
            ld a, [bc]
            ld [hl], a
            pop bc
            ret

; ---- gb_layout vtext's scan (far): Y = the first of the 20 cells at ($8A) that is a frame tile
; ($F7-$FE), else 20. Out: Y (C), B = 0; A and flags as left (dead there).
vscan_b:    ld hl, NES_RAM + $8A
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld a, h
            and $E0
            cp $60
            jr nz, .gen                     ; (not save RAM: through the PPU-free reads)
            ld a, h
            add a, $40
            ld h, a
            ld c, 0
.w:         ld a, [hl+]
            cp $F7
            jr c, .n
            cp $FF
            jr c, .x
.n:         inc c
            ld a, c
            cp 20
            jr nz, .w
.x:         ld b, 0
            ret
.gen:       ldh a, [code_bank]              ; (the helpers come back to code_bank)
            push af
            ld a, PF_BANK
            ldh [code_bank], a
            ld bc, 0
.g:         push bc
            ld l, $8A
            call rt_izy_rd
            ld a, l
            pop bc
            cp $F7
            jr c, .gn
            cp $FF
            jr c, .gx
.gn:        inc c
            ld a, c
            cp 20
            jr nz, .g
.gx:        pop af
            ldh [code_bank], a
            jr .x

; ---- b12:97A7 (battle: LDX #0 / LDA #$F0 / STA $0200,X / INX / BNE): the OAM page all $F0.
; Out: A = $F0, X = 0, Z = 1, N = 0, carry kept.
oclr_b:     push af
            ld hl, NES_RAM + $0200
            ld a, $F0
            ld e, 32
.l:
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            dec e
            jr nz, .l
            xor a
            ldh [nzv], a
            pop af
            ld a, 0
            inc a
            dec a
            ld a, $F0
            ret

; ---- c62:D403 natively (FF1: 16 attribute positions of a row / column of the map: $07D0 +
; Y = $23 / $27, $07E0 + Y = $C0 | ($30 >> 1) << 3 | ($31 & 15) >> 1, $07F0 + Y = the
; quadrant mask $0F / $F0 & $33 / $CC), $31 + 1 (mod 32) per entry in a row (16), $30 + 1
; (mod 15) in a column (15). RAM as FF1 leaves it ($10-$12, $30 / $31); out: Y = 16 / 15,
; X = the last $33 / $CC, A = the last $31 / $30, Z and C set.
pap_b:      ld a, [NES_RAM + $2D]           ; (state in registers / HRAM, RAM at the end:
            and 2                           ;   C = Y, H = page 7, L = $07D0 + Y)
            jr nz, .col
            ld a, [NES_RAM + $30]           ; a row: $30 fixed, $31 + 1 mod 32 per entry
            ld d, $0F
            srl a
            jr nc, .x0
            ld d, $F0
.x0:        add a, a
            add a, a
            add a, a
            ld b, a                         ; B = ($30 >> 1) << 3, D = $0F / $F0
            ld a, [NES_RAM + $31]
            ldh [sh_u2], a
            ld c, 0
            ld h, high(NES_RAM) + 7
.r:         ld a, c
            or $D0
            ld l, a
            ldh a, [sh_u2]
            cp $10
            ld [hl], $23
            jr c, .r1
            ld [hl], $27
            and $0F
.r1:        ld e, $33
            srl a
            jr nc, .r2
            ld e, $CC
.r2:        or b
            ldh [sh_u3], a                  ; ($10)
            or $C0
            set 5, l
            res 4, l
            ld [hl], a                      ; $07E0 + Y
            set 4, l
            ld a, e
            and d
            ld [hl], a                      ; $07F0 + Y
            ldh a, [sh_u2]
            inc a
            and $1F
            ldh [sh_u2], a
            inc c
            ld a, c
            cp 16
            jr c, .r
            ldh a, [sh_u2]
            ld [NES_RAM + $31], a
            jr .out
.col:       ld a, [NES_RAM + $31]           ; a column: $31 fixed, $30 + 1 mod 15 per entry
            ld h, $23
            cp $10
            jr c, .n0
            and $0F
            ld h, $27
.n0:        ld e, $33
            srl a
            jr nc, .m0
            ld e, $CC
.m0:        ld b, a                         ; B = ($31 & 15) >> 1, E = $33 / $CC
            ld a, h
            ldh [wtmp], a                   ; (the page byte)
            ld a, [NES_RAM + $30]
            ldh [sh_u2], a
            ld c, 0
            ld h, high(NES_RAM) + 7
.c:         ld a, c
            or $D0
            ld l, a
            ldh a, [wtmp]
            ld [hl], a                      ; $07D0 + Y
            ldh a, [sh_u2]
            ld d, $0F
            srl a
            jr nc, .c1
            ld d, $F0
.c1:        add a, a
            add a, a
            add a, a
            or b
            ldh [sh_u3], a                  ; ($10)
            or $C0
            set 5, l
            res 4, l
            ld [hl], a
            set 4, l
            ld a, e
            and d
            ld [hl], a
            ldh a, [sh_u2]
            inc a
            cp 15
            jr c, .c2
            sub 15
.c2:        ldh [sh_u2], a
            inc c
            ld a, c
            cp 15
            jr c, .c
            ldh a, [sh_u2]
            ld [NES_RAM + $30], a
.out:       ld b, a                         ; (A out: the last $31 / $30)
            ldh a, [sh_u3]
            ld [NES_RAM + $10], a
            ld a, l
            and $0F                         ; (the last entry's mask and page byte)
            or $F0
            ld l, a
            ld a, [hl]
            ld [NES_RAM + $11], a
            res 5, l
            ld a, [hl]
            ld [NES_RAM + $12], a
            ld d, 0
            xor a
            ldh [nzv], a
            scf
            ld a, b
            ld b, 0
            ret

section bank 0, $3100
; carry: no more sprite slot loads this GB frame (DMG: SL_MAX a frame; a sprite whose tile
; is not loaded yet stays hidden until a later frame's conversion loads it). Keeps BC, DE.
SL_V       = $D828          ; (fault-dump area) VBL_CNT of the loads counted in SL_N
SL_N       = $D82F
SL_MAX     = 8
sl_chk:     ldh a, [is_cgb]
            and a
            ret nz
            push hl
            ld hl, SL_V
            ld a, [VBL_CNT]
            cp [hl]
            jr z, .s
            ld [hl], a
            xor a
            ld [SL_N], a
.s:         ld a, [SL_N]
            cp SL_MAX
            ccf
            jr c, .x
            inc a
            ld [SL_N], a
            and a
.x:         pop hl
            ret



section bank 0, $3140
; A = value, HL = VRAM address: one entry at the end of the VRAM queue (LCD on), nothing
; written now (prow_b in the prologue). Keeps BC, DE, HL.
q_put:      push bc
            push de
            ld d, a
            ldh a, [q_tail]
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
            pop de
            pop bc
            ret

section bank 0, $3170
; ---- DMG BG pages left in ROM (hle_chr_pages, a whole page with the LCD off): BG_LZ (cart RAM
; bank 3) marks the tiles not yet in the shadow, BG_LZS the ROM bank and address of each page.
; D = page, HL = its source (bank data_bank8): recorded, its 16 tiles marked. Keeps BC, DE, HL.
bg_lazy:    push hl
            push bc
            ld a, 3
            ld [$4000], a
            ld b, h
            ld c, l
            ld a, d
            add a, a
            add a, a
            add a, low(BG_LZS)
            ld l, a
            ld h, high(BG_LZS)
            ldh a, [data_bank8]
            ld [hl+], a
            ld a, c
            ld [hl+], a
            ld [hl], b
            ld a, d
            add a, a
            add a, low(BG_LZ)
            ld l, a
            ld a, $FF
            ld [hl+], a
            ld [hl], a
            xor a
            ld [$4000], a
            pop bc
            pop hl
            ret
; boot (cart RAM bank 3 on): no BG tile left in ROM
bg_lzinit:  ld hl, BG_LZ
            xor a
            ld b, 32
.l:         ld [hl+], a
            dec b
            jr nz, .l
            ret
; A = tile: its BG_LZ mark cleared (a whole tile written into the shadow). Keeps all registers.
bg_lzclr:   push af
            push bc
            push hl
            ld c, a
            rrca
            rrca
            rrca
            and $1F
            add a, low(BG_LZ)
            ld l, a
            ld h, high(BG_LZ)
            ld a, c
            and 7
            ld b, $FE
            jr z, .bt
.sh:        rlc b
            dec a
            jr nz, .sh
.bt:        ld a, 3
            ld [$4000], a
            ld a, [hl]
            and b
            ld [hl], a
            xor a
            ld [$4000], a
            pop hl
            pop bc
            pop af
            ret
; A = tile, C = the ROM bank to come back to: still in ROM (BG_LZ) -> copied into the shadow
; now (GB byte order), mark cleared. Cart RAM bank 0 after. Keeps all registers.
bg_mat:     push af                         ; (C: the bank mapped now if its ID is at $7FFE,
            ld a, [$7FFE]                   ;   a code or runtime bank: natives call PPU
            cp $A5                          ;   writes with code_bank still the recompiled
            jr nz, .ci                      ;   caller's; callers keep their BC)
            ld a, [$7FFF]
            ld c, a
.ci:        pop af
            push af
            push bc
            push de
            push hl
            ld e, a
            ld a, 3                         ; (not in ROM: nothing, no bank touched)
            ld [$4000], a
            ld a, e
            rrca
            rrca
            rrca
            and $1F
            add a, low(BG_LZ)
            ld l, a
            ld h, high(BG_LZ)
            ld a, e
            and 7
            ld b, 1
            jr z, .b0
.s0:        sla b
            dec a
            jr nz, .s0
.b0:        ld a, [hl]
            and b
            jr nz, .lz
            xor a
            ld [$4000], a
            pop hl
            pop de
            pop bc
            pop af
            ret
.lz:
            ld a, 3
            ld [$4000], a
            ld a, e
            rrca
            rrca
            rrca
            and $1F
            add a, low(BG_LZ)
            ld l, a
            ld h, high(BG_LZ)
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
            ld a, e
            swap a
            and $0F
            add a, a
            add a, a
            add a, low(BG_LZS)
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
.nc:        ld a, e                         ; HL = shadow + tile * 16
            swap a
            ld l, a
            and $0F
            add a, high(BG_SHADOW)
            ld h, a
            ld a, l
            and $F0
            ld l, a
            ld a, 1
            ld [$4000], a
            ld a, d
            ld [$2000], a
            ld e, 8
.p0:        ld a, [bc]
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
            inc bc
            ld [hl+], a
            inc l
            dec e
            jr nz, .p1
.n:         xor a
            ld [$4000], a
            pop hl
            pop de
            pop bc
            ld a, c
            ld [$2000], a
            pop af
            ret

section bank 0, $2DC0
; frame wait entry: A = the VBL_CNT to wait past: the current one, or the one before when the
; LCD is on, LY is in the vblank (144-153) and no frame wait has ended in this vblank yet (the
; NES: FF1 enabling NMI with the vblank flag set gets its NMI at once). Keeps the rest.
vbl_late:   ldh a, [lcd_on]
            and a
            jr z, .n
            ldh a, [$FF44]
            cp 144
            jr c, .n
            push hl
            ld hl, VBL_SEEN
            ld a, [VBL_CNT]
            cp [hl]
            pop hl
            jr z, .n
            dec a
            ret
.n:         ld a, [VBL_CNT]
            ret

section bank 0, $2F40
; HL = NES address -> A (bank RT_TABLES mapped again); keeps BC, DE, HL
mrd:        push hl
            ld a, l                         ; (the engine's tables, copied into this bank by
            sub low(MT_LO)                  ;   build.py at MTAB: read here, no bank switch)
            ld l, a
            ld a, h
            sbc a, high(MT_LO)
            jr c, .nt
            ld h, a
            cp high(MT_LEN)
            jr c, .in
            jr nz, .nt
            ld a, l
            cp low(MT_LEN)
            jr nc, .nt
            ld a, h
.in:        add a, high(MTAB)
            ld h, a
            ld a, [hl]
            pop hl
            ret
.nt:        pop hl
            push hl
            ld a, h
            sub $80
            cp $40
            jr nc, .o
            add a, $40
            ld h, a
            ldh a, [data_bank8]
            ld [$2000], a
            ld h, [hl]
            ld a, RT_TABLES
            ld [$2000], a
            ld a, h
            pop hl
            ret
.o:         push de
            call nes_rd
            pop de
            ld a, RT_TABLES
            ld [$2000], a
            ld a, l
            pop hl
            ret

; ---- gb_layout vbreak (and vcw), natively: the row from VC0 in VW tiles less VIND: VEND = its
; end, VNEXT = the next row's start; VLIM, VLO, VSQ, VBRK, VCNT and Y (the last glyph's index)
; as the NES routine leaves them. Its callers (vtext: JSR vclear, vrows: LDX VNEXT) use no
; flag and no register after it; A / X / Y are set as on the NES all the same. Glyph widths
; vw_gw60: a copy of the far bank's GW (build.py).
VW_VW      = $AE9E
VW_VIND    = $AE9F
VW_VNEXT   = $AEA7
VW_VC0     = $AEA8
VW_VLIM    = $AEA9
VW_VBRK    = $AEAA
section bank PF_BANK, $6800
vbrk_b:     ld a, [VW_VW]
            add a, a
            add a, a
            add a, a
            ld hl, VW_VIND
            sub [hl]
            ld [VW_VLIM], a
            ld b, a                         ; B = VLIM
            ld a, [VW_VC0]
            ld e, a                         ; E = X
            xor a
            ld d, a                         ; D = VLO
            ld [VW_VSQ], a
            dec a
            ld [VW_VBRK], a
            call .rd                        ; HL = VSTR + X (walked along with X)
.l:         ld a, [hl]
            and a
            jr z, .all
            cp $FE
            jr z, .fe
            cp $FD
            jr z, .fd
            cp $FF
            jr z, .sp
            sub VW_FIRST                    ; vcw: width + 1 (0 for none), Y = glyph
            jr c, .z0
            ld c, a
            push hl
            ld h, high(vw_gw60)
            ld l, a
            ld a, [hl]
            pop hl
            and a
            jr z, .ad
            inc a
.ad:        add a, d
            ld d, a
            jr z, .ok
            dec a
            cp b
            jr z, .ok
            jr nc, .over
.ok:        inc hl
            inc e
            jr nz, .l
            jr .all
.z0:        xor a
            jr .ad
.sp:        ld a, e
            ld [VW_VBRK], a
            ld a, 3
            jr .ad
.fd:        inc hl                          ; $FD $80+n: VLO = 8n
            inc e
            ld a, [hl]
            sub $80
            add a, a
            add a, a
            add a, a
            ld d, a
            jr .ok
.all:       ld a, e
            ld [VW_VEND], a
            ld [VW_VNEXT], a
            xor a
.x:         ld h, a
            ld a, d
            ld [VW_VLO], a
            ld a, h
            ld b, 0
            ld d, b
            and a
            ldh [nzv], a
            ret
.fe:        ld a, e
            ld [VW_VEND], a
            inc e
            ld a, e
            ld [VW_VNEXT], a
            ld a, $FE
            jr .x
.over:      ld a, [VW_VBRK]
            cp $FF
            jr z, .cut
            ld [VW_VEND], a
            ld e, a
            inc e
            ld h, a
            ld a, e
            ld [VW_VNEXT], a
            ld a, h
            jr .x
.cut:       ld a, e                         ; one word wider than the row: squeeze or cut
            ld [VW_VSQ], a
            ld a, [VW_VC0]
            ld e, a
            ld d, 0
            xor a
            ld [VW_VCNT], a
.sw:        call .rd
            and a
            jr z, .swe
            cp $FF
            jr z, .swe
            cp $FE
            jr z, .swe
            call .cw
            add a, d
            ld d, a
            ld hl, VW_VCNT
            inc [hl]
            inc e
            jr nz, .sw
.swe:       ld a, d                         ; overflow = width - 1 - limit
            dec a
            sub b
            jr c, .fit                      ; (fits after all: VLO = 0)
            ld d, a
            ld a, [VW_VCNT]
            dec a
            cp d
            jr c, .nosq
            jr .sq
.fit:       ld d, 0
.sq:        ld a, e                         ; the whole word on this row, VLO gaps dropped
            ld [VW_VEND], a
            call .rd
            and a
            jr z, .sq3
            inc e
.sq3:       ld a, e
            ld [VW_VNEXT], a
            ld a, d
            ld [VW_VSQ], a
            jr .x
.nosq:      ld a, [VW_VSQ]                  ; cut at the overflowing letter
            ld e, a
            xor a
            ld [VW_VSQ], a
            ld a, [VW_VC0]
            cp e
            jr nz, .c2
            inc e
.c2:        ld a, e
            ld [VW_VEND], a
            ld [VW_VNEXT], a
            xor a
            jr .x
.rd:        ld a, e                         ; A = VSTR[X]
            add a, low(VW_VSTR)
            ld l, a
            ld a, high(VW_VSTR)
            adc 0
            ld h, a
            ld a, [hl]
            ret
.cw:        sub VW_FIRST                    ; vcw (not a space): A = width + 1, Y = glyph
            jr c, .cz
            ld c, a
            add a, low(vw_gw60)
            ld l, a
            ld a, high(vw_gw60)
            adc 0
            ld h, a
            ld a, [hl]
            and a
            ret z
            inc a
            ret
.cz:        xor a
            ret

; ---- gb_layout vtids, natively: VTID[k] for the VN cells from (VROW, VCOL) (the 9-column left
; window's LPOOL tiles, else $A8 + 18(row-1) + col-2). Out as the NES routine: Y = VN, A / X
; as its path leaves them, Z = C = 1 (CPY), N = 0; VLO. vw_lpool (page-aligned): the far
; bank's 256 bytes from LPOOL (build.py), all an X can index.
VW_VROW    = $AE9C
VW_VCOL    = $AE9D
VW_VTID    = NES_RAM + $0350
section bank PF_BANK, $6C00
vtids_b:    ld a, [$A927]                   ; (NES $6927: panel row 0, column 9)
            cp $F9
            jr nz, .full
            ld a, [VW_VCOL]
            cp 9
            jr nc, .full
            ld a, [VW_VROW]
            dec a
            ld [VW_VLO], a
            ld h, a
            add a, a
            add a, a
            add a, a
            sub h
            ld h, a
            ld a, [VW_VCOL]
            add a, h
            sub 2
            ld e, a                         ; X
            ld a, [VW_VN]
            ld b, a                         ; (0: 256 cells, as Y wraps)
            ld c, a
            ld hl, VW_VTID
.l:         push hl
            ld h, high(vw_lpool)
            ld l, e
            ld a, [hl]
            pop hl
            ld [hl+], a
            inc e
            dec b
            jr nz, .l
            jr .x
.full:      ld a, [VW_VROW]
            dec a
            add a, a
            ld [VW_VLO], a
            ld h, a
            add a, a
            add a, a
            add a, a
            add a, h
            ld hl, VW_VCOL
            adc [hl]
            adc $A6
            ld d, a
            ld a, [VW_VN]
            ld b, a
            ld c, a
            ld hl, VW_VTID
.f:         ld a, d
            ld [hl+], a
            inc d
            dec b
            jr nz, .f
            ld a, d
            ld d, b
.x:         ld h, a
            xor a
            ldh [nzv], a
            scf
            ld a, h
            ret

; ---- gb_layout vtext's `.c` loop (LDY #0 / LDA VTID,Y / STA ($8A),Y / INY / CPY VN / BNE): the
; row's cells show its tiles. Out: Y = VN, A = the last tile, Z = C = 1, N = 0; X kept.
vtc_b:      ld hl, NES_RAM + $8A
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld a, h
            sub $60
            cp $1F
            jr nc, .gen                     ; (save RAM below $7F00 only)
            ld a, h
            add a, $40
            ld h, a
            push de
            ld a, [VW_VN]
            ld b, a
            ld c, a
            ld de, VW_VTID
.l:         ld a, [de]
            ld [hl+], a
            inc de
            dec b
            jr nz, .l
            pop de
.x:         ld h, a
            xor a
            ldh [nzv], a
            scf
            ld a, h
            ret
.gen:       ldh a, [code_bank]
            push af
            ld a, PF_BANK
            ldh [code_bank], a
            ld bc, 0
.g:         ld hl, VW_VTID
            add hl, bc
            ld a, [hl]
            ld l, $8A
            call rt_izy_wr
            inc c
            ld a, [VW_VN]
            cp c
            jr nz, .g
            pop af
            ldh [code_bank], a
            ld hl, VW_VTID - 1
            add hl, bc
            ld a, [hl]
            jr .x

; ---- RTS after LDA T+1,X / PHA / LDA T,X / PHA, T a constant table (recomp rts_table): HL = the
; site's table (count, then per entry its target lo, hi, GB bank, GB address); X even, within
; it and the pushed address + 1 the entry's target: jump there (rt_dyn_go), the pushes dropped;
; else rt_rts_dispatch. Keeps A, F, BC, DE.
section bank 0, $30B0
rt_rtstab:  ldh [sv_a], a
            push af
            push de
            push bc                         ; [SP+2] = X, [SP+7] = lo, [SP+9] = hi
            ld b, h
            ld c, l
            ld hl, sp + 7
            ld e, [hl]
            inc hl
            inc hl
            ld d, [hl]
            inc de                          ; DE = the target
            ld hl, sp + 2
            ld a, [hl]
            ld h, b
            ld l, c
            rrca
            jr c, .dyn
            cp [hl]
            jr nc, .dyn
            inc hl
            ld c, a
            add a, a
            add a, a
            add a, c
            ld c, a
            ld b, 0
            add hl, bc
            ld a, [hl+]
            cp e
            jr nz, .dyn
            ld a, [hl+]
            cp d
            jr nz, .dyn
            ld a, [hl+]
            ldh [fc_bank], a
            ld a, [hl+]
            ldh [tmp_lo], a
            ld a, [hl]
            ldh [wtmp], a
            pop bc
            pop de
            pop af
            pop hl
            pop hl
            ldh a, [wtmp]
            ld h, a
            ldh a, [tmp_lo]
            ld l, a
            ldh a, [sv_a]
            jp rt_dyn_go
.dyn:       pop bc
            pop de
            pop af
            ldh a, [sv_a]
            jp rt_rts_dispatch

; HL = NES ROM address ($8000-$FFFF), DE = destination in cart RAM bank 3, B = bytes (1-64,
; within one ROM region): copied up to and with the first byte < $48 (data_bank8 / data_bankC /
; the fixed bank's data), C = the bytes before it, B = 0 if none came; code_bank mapped after,
; cart RAM bank 3 left mapped.
section bank 0, $3288
rd_blk:     ld a, 3
            ld [$4000], a
            ld a, h
            cp $C0
            jr nc, .c
            sub $40
            ld h, a
            ldh a, [data_bank8]
            jr .go
.c:         cp $E0
            jr nc, .e
            sub $80
            ld h, a
            ldh a, [data_bankC]
            jr .go
.e:         sub $80
            ld h, a
            ld a, DATA + 31
.go:        ld [$2000], a
            ld c, 0
.l:         ld a, [hl+]
            ld [de], a                      ; (the end byte too: B != 0 then)
            cp $48
            jr c, .x
            inc de
            inc c
            dec b
            jr nz, .l
.x:         ldh a, [code_bank]
            ld [$2000], a
            ret

; A run of letters at once (fast modes; C = increment, D = state, both kept; E, B, HL
; clobbered): the string bytes at ($3E) up to the first < $48 (within its 256-byte page, up to
; 64; from ROM copied to TX_BUF first), as far as every cell stays a map cell of nametable 0
; and below 256; mode 0 only with increment 32 (the Y row and the letter row apart). The cells
; as the letter loop writes them (shadow, then the GB map or MAP_RB when masked); then $3E/$3F
; and $54 + n, D bit 6 if n > 0. C (carry) when the run ends at the string's end: A = that
; byte (< $48; the letter loop's .qNx goes on with it); else NC and the letter loop goes on
; with the byte after (or the letter the run could not take).
section bank PF_BANK, $6D00
txr_rn0:    ld a, c
            cp 32
            jr nz, txr_no
            push bc
            push de
            call txr_src                    ; DE = the bytes, C = letters, B: end follows
            jr z, txr_rx
            push bc
            push de
            ld a, [NES_RAM + $55]
            and 3
            ld h, a
            ld a, [NES_RAM + $54]
            ld l, a
            ld a, h                         ; n <= $E0 - L ($A0 - L in the last 256: attributes)
            cp 3
            ld a, $E0
            jr nz, txr_r1
            ld a, $A0
txr_r1:     sub l
            jr c, txr_rx2
            jr z, txr_rx2
            cp c
            jr nc, txr_r2
            ld c, a
txr_r2:     ld a, h
            add a, high(NT_SH)
            ld h, a
            call txr_r0w                    ; shadow
            ld hl, sp + 5
            bit 0, [hl]
            jr nz, txr_rm
            ld a, [NES_RAM + $55]
            and 3
            add a, $98
            ld h, a
            ld a, [NES_RAM + $54]
            ld l, a
            call txr_r0w                    ; GB map
            jr txr_rup
txr_rm:     ld a, 1
            ld [MAP_RB], a
            jr txr_rup
txr_r0w:    push hl                         ; Y row: $FF x C; letter row (+32): the bytes
            push de
            ld b, c
            ld a, $FF
txr_ra:     ld [hl+], a
            dec b
            jr nz, txr_ra
            pop de
            pop hl
            push de
            ld a, l
            add a, 32
            ld l, a
            ld b, c
txr_rb:     ld a, [de]
            inc de
            ld [hl+], a
            dec b
            jr nz, txr_rb
            pop de
            ret
txr_rup:    ld hl, NES_RAM + $3E            ; $3E/$3F += n, $54 += n, D bit 6
            ld a, [hl]
            add a, c
            ld [hl+], a
            jr nc, txr_ru1
            inc [hl]
txr_ru1:    ld hl, NES_RAM + $54
            ld a, [hl]
            add a, c
            ld [hl], a
            ld hl, sp + 5
            set 6, [hl]
            ld a, c                         ; all the letters taken and the end after them:
            pop hl                          ;   A = that byte, C
            pop de                          ; (D: end follows, E: letters counted)
            cp e
            jr nz, txr_rx
            inc d
            dec d
            jr z, txr_rx
            ld e, c
            ld d, 0
            add hl, de
            ld b, [hl]                      ; (TX_BUF: cart RAM bank 3 still on)
            xor a
            ld [$4000], a
            ld a, b
            pop de
            pop bc
            scf
            ret
txr_rx2:    pop hl
            pop hl
txr_rx:     xor a                           ; (cart RAM bank 0 again; NC)
            ld [$4000], a
            pop de
            pop bc
            ret
txr_no:     and a
            ret
txr_rn1:    push bc                         ; modes 1 / 2: A = the row offset (0 / $20)
            push de
            ld b, a
            ld a, [NES_RAM + $54]
            add a, b
            jr c, txr_rx
            ld l, a                         ; L = the first cell
            push hl
            call txr_src
            pop hl
            jr z, txr_rx
            push bc
            push de
            ld a, [NES_RAM + $55]
            and 3
            ld h, a
            cp 3                            ; n <= 256 - L ($C0 - L in the last 256)
            jr nz, txr_r3
            ld a, l
            cp $C0
            jr nc, txr_rx2
            ld a, $C0
            sub l
            jr txr_r5
txr_r3:     ld a, l
            cpl
            inc a
            jr z, txr_r4                    ; (256: any n)
txr_r5:     cp c
            jr nc, txr_r4
            ld c, a
txr_r4:     ld a, h
            add a, high(NT_SH)
            ld h, a
            push hl
            call txr_r1w                    ; shadow
            pop hl
            ld a, l
            ld hl, sp + 5
            bit 0, [hl]
            jr nz, txr_rm
            ld l, a
            ld a, [NES_RAM + $55]
            and 3
            add a, $98
            ld h, a
            call txr_r1w                    ; GB map
            jr txr_rup
txr_r1w:    push de
            ld b, c
txr_rc:     ld a, [de]
            inc de
            ld [hl+], a
            dec b
            jr nz, txr_rc
            pop de
            ret
txr_src:    ld hl, NES_RAM + $3E            ; DE = the bytes at ($3E), C = letters before the
            ld a, [hl+]                     ;   first byte < $48 (within the page, up to 64),
            ld h, [hl]                      ;   B != 0 when that byte follows them (at DE + C);
            ld l, a                         ;   Z when no letter
            cpl
            inc a                           ; B = 256 - L, at most 64
            jr z, txr_s64
            cp 64
            jr c, txr_sb
txr_s64:    ld a, 64
txr_sb:     ld b, a
            ld a, h
            cp $20
            jr c, txr_sr
            cp $5C
            jr c, txr_sno
            cp $60
            jr c, txr_se
            cp $80
            jr c, txr_ss
            ld de, TX_BUF                   ; ROM: the letters (and the end) to TX_BUF
            call rd_blk
            ld de, TX_BUF
            ld a, c
            and a
            ret
txr_sr:     and 7                           ; RAM
            or high(NES_RAM)
            jr txr_sd
txr_se:     add a, $6C                      ; ExRAM
            jr txr_sd
txr_ss:     add a, $40                      ; save RAM
txr_sd:     ld d, a
            ld e, l
            push de
            ld c, 0
txr_cl:     ld a, [de]
            cp $48
            jr c, txr_cd
            inc de
            inc c
            dec b
            jr nz, txr_cl
txr_cd:     pop de
            ld a, c
            and a
            ret
txr_sno:    xor a
            ret

; NZ when sprites show: the LCD on and not a DMG load blanked (VLCD 1 with the LCD on: BGP 0,
; sprites off until the switch-off). Keeps BC, DE, HL.
section bank 0, $32D0
oam_hid:    ldh a, [lcd_on]
            and a
            ret z
            ldh a, [is_cgb]
            and a
            ret nz
            ld a, [VLCD]
            dec a
            ret

; ---- b12:AE09 (A x X by shift and add: STA $68B3 / STX $68B4 / 8 x (LSR $68B3, ADC $68B4, ROR A,
; ROR $68B5)), natively: $68B3 = 0, $68B4 = X, $68B5 = the low byte; A = the low byte, X = the
; high byte; N, Z from the low byte, C = 0 (the bits shifted out of $68B5 are its initial
; zeros); Y kept. (V: the routine's last ADC; its callers do not test it.)
section bank PF_BANK, $6D00 + $200
mul8_b:     push bc                         ; (quarter squares: SQ_LO / SQ_HI, build.py)
            ld b, a
            ld a, e
            ld [$A8B4], a
            add a, b                        ; s = A + X (9 bits): sq(s)
            ld l, a
            ld a, high(SQ_LO)
            adc 0
            ld h, a
            ld c, [hl]
            ld a, h
            add a, high(SQ_HI) - high(SQ_LO)
            ld h, a
            ld d, [hl]
            ld a, b                         ; |A - X|: sq of it
            sub e
            jr nc, .p
            cpl
            inc a
.p:         ld l, a
            ld h, high(SQ_LO)
            ld a, c
            sub [hl]
            ld c, a                         ; C = the low byte
            ld h, high(SQ_HI)
            ld a, d
            sbc a, [hl]
            ld e, a                         ; X = the high byte
            xor a
            ld [$A8B3], a
            ld d, a
            ld a, c
            ld [$A8B5], a
            pop bc
            ldh [nzv], a
            and a                           ; (Z from A, C = 0)
            ret

; ---- dbox_b's rows at once ($1A / $1B set): when the LCD is off (or a load masked, no dialogue
; box), the increment is 1, no cell is nametable 1's, $55 is in nametable 0's map and the box
; ($3D rows of $3C cells from $55:$54, 32 apart) ends by the attributes. The shadow (and the
; GB map, else MAP_RB when masked); as the row-by-row path leaves them: $1B = 0, $55:$54 + 32
; x ($3D - 1), the PPU address after the bottom row, latch / vblank flag 0, dmg_scan, sh_l1 /
; sh_u2 / sh_u3 = the bottom row's tiles, sh_l2 / vfl = C / V of the last ADC. C = 1 when
; done (else nothing changed, C = 0). Keeps BC.
section bank PF_BANK, $4410
dbx_fast:   ldh a, [lcd_on]
            and a
            jr z, .k1
            ld a, [VLCD]
            cp 1
            jr nz, .no
            ldh a, [dlg_on]
            and a
            jr nz, .no
.k1:        ldh a, [ppu_ctrl]
            and 4
            jr nz, .no
            ldh a, [own1_lo]
            ld e, a
            ldh a, [own1_hi]
            or e
            jr nz, .no
            ld a, [NES_RAM + $55]
            and $3F
            cp $20
            jr c, .no
            cp $3F
            jr z, .no
            bit 2, a
            jr nz, .no
            ld a, [NES_RAM + $3C]
            cp 3                            ; (2: X = 0, 256 cells: the row path)
            jr c, .no
            push bc
            ld a, [NES_RAM + $3D]           ; DE = 32 x (rows - 1)
            dec a
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld d, h
            ld e, l
            ld a, [NES_RAM + $55]
            and 3
            ld h, a
            ld a, [NES_RAM + $54]
            ld l, a                         ; HL = the first row's offset
            push hl
            add hl, de                      ; the bottom row's offset
            ld a, [NES_RAM + $3C]
            add a, l
            ld c, a
            ld a, 0
            adc a, h
            ld b, a                         ; BC = its end
            pop hl
            ld a, b                         ; end <= $3C0
            cp 3
            jr c, .ok
            jr nz, .no2
            ld a, c
            cp $C1
            jr nc, .no2
.ok:        push bc                         ; (the end)
            push de
            push hl
            ld a, h
            add a, high(NT_SH)
            ld h, a
            call .box                       ; shadow
            pop hl
            ld a, [VLCD]
            cp 1
            jr nz, .mp
            ld [MAP_RB], a
            jr .md
.mp:        push hl
            ld a, h
            add a, $98
            ld h, a
            call .box                       ; GB map
            pop hl
.md:        pop de
            pop bc
            ld a, 1
            ldh [dmg_scan], a
            xor a
            ldh [vbl_flag], a
            ldh [ppu_latch], a
            ld [NES_RAM + $1B], a
            ld a, $FC
            ldh [sh_l1], a
            ld a, $FD
            ldh [sh_u2], a
            ld a, $FE
            ldh [sh_u3], a
            ld a, [NES_RAM + $3D]           ; the last ADC: $54 before it = ($54 + 32 x
            sub 2                           ;   (rows - 2)) & $FF; $55 before it likewise
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld a, [NES_RAM + $54]
            add a, l
            ld l, a
            ld a, [NES_RAM + $55]
            adc a, h
            ld h, a                         ; HL = $55:$54 before the last ADC
            ld a, l
            add a, $20
            ld [NES_RAM + $54], a
            ld a, h
            adc a, 0
            ld [NES_RAM + $55], a
            ld e, a                         ; (E = the new $55, H = the old)
            sbc a, a
            and $10
            ldh [sh_l2], a                  ; C
            ld a, h
            xor e
            and e
            and $80
            rrca
            ldh [vfl], a                    ; V
            ld a, c                         ; the PPU address after the bottom row
            ldh [ppu_vl], a
            ld a, e
            and $3C
            or b
            ldh [ppu_vh], a
            pop bc
            scf
            ret
.no2:       pop bc
.no:        and a
            ret
.box:       ld a, $F7                       ; HL = the top row; DE = 32 x (rows - 1)
            ld b, $F8
            ld c, $F9
            call .r
            ld a, [NES_RAM + $3D]
            sub 2
            ld d, a
.bm:        ld a, $FA
            ld b, $FF
            ld c, $FB
            call .r
            dec d
            jr nz, .bm
            ld a, $FC
            ld b, $FD
            ld c, $FE
.r:         push hl                         ; one row: A, B x ($3C - 2), C; HL += 32
            ld [hl+], a
            ld a, [NES_RAM + $3C]
            sub 2                           ; (>= 1)
            ld e, a
            and 3                           ; the rest one by one, then fours
.rr:        jr z, .r4
            ld [hl], b
            inc hl
            dec a
            jr .rr
.r4:        srl e
            srl e
            jr z, .re
            ld a, b
.rl:        ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            dec e
            jr nz, .rl
.re:        ld [hl], c
            pop hl
            ld a, l
            add a, 32
            ld l, a
            ret nc
            inc h
            ret

section bank PF_BANK, $6920
txc_chk:       and a
            jp z, txrun_b.end
            ld b, a
            ld a, [NES_RAM + $37]
            and a
            jr nz, txc_cx                      ; (DEC7: JSR E1BD when $37 != 0)
            ld a, b
            cp 1
            jr z, txc_c1
            cp $14
            jr nc, txc_cig
            cp 5
            jr c, txc_cx
            cp $10
            jr nc, txc_cx
            call txc_cinc
            ld a, b                         ; 5-15: X = (code - 5) * 2 (TAX), V = 0 (SBC #5),
            sub 5                           ;   C = 0 (ASL)
            add a, a
            ld e, a
            xor a
            ldh [vfl], a
            ld hl, sp + 2
            res 4, [hl]
            ld a, e
            add a, low(txc_jt)
            ld l, a
            ld a, high(txc_jt)
            adc 0
            ld h, a
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            jp hl
txc_cx:        ld a, b
            jp txrun_b.end
txc_cig:       call txc_cinc                      ; $14-$47: nothing (CMP #$14: C = 1)
            ld hl, sp + 2
            set 4, [hl]
            jp txrun_b.rs
txc_c1:        call txc_cinc                      ; 1: $54 = ($54 & $E0 | $3A) + $40, $55 + carry
            ld hl, NES_RAM + $3A            ;   (ADC #$00: C, V)
            ld a, [NES_RAM + $54]
            and $E0
            or [hl]
            add a, $40
            ld [NES_RAM + $54], a
            ld hl, NES_RAM + $55
            ld a, [hl]
            ld d, a
            adc a, 0
            ld [hl], a
            ld c, a                         ; (C: free until .st; X = E kept)
            sbc a, a
            and $10
            ld hl, sp + 2
            res 4, [hl]
            or [hl]
            ld [hl], a
            ld a, d                         ; V: (old ^ new) & new & $80
            xor c
            and c
            and $80
            rrca
            ldh [vfl], a
            jp txrun_b.rs
txc_cinc:      ld hl, NES_RAM + $3E            ; INC $3E / $3F
            inc [hl]
            ret nz
            inc l
            inc [hl]
            ret
txc_jt:        dw txc_h5, txc_h6, txc_h7, txc_h8, txc_h9, txc_h10, txc_h11, txc_h12, txc_h13, txc_h14, txc_h15
txc_h5:        ld a, [EX_RAM]                  ; 5D4C
            ld [EX_RAM + 1], a
            ld a, [NES_RAM + $54]
            ld [EX_RAM + 2], a
            ld a, 1
            ld [EX_RAM], a
            jp txrun_b.rs
txc_h6:        ld a, [EX_RAM + 2]              ; 5D5B
            ld [NES_RAM + $54], a
            ld a, 2
            ld [EX_RAM], a
            jp txrun_b.rs
txc_h7:        ld a, [EX_RAM + 1]              ; 5D64
            ld [EX_RAM], a
            jp txrun_b.rs
txc_h9:        ld a, 2                         ; 5D6A
            ld [EX_RAM], a
            jp txrun_b.rs
txc_h11:       xor a                           ; 5D6E
            ld [EX_RAM + 3], a
            ld [EX_RAM], a
            jp txrun_b.rs
txc_h12:       ld hl, NES_RAM + $54            ; 5D47
            inc [hl]
            jp txrun_b.rs
txc_h10:       call txrun_b.get                       ; 5D8B
            push af
            call txc_cinc
            pop af
            ld [EX_RAM + 3], a
            jp txrun_b.rs
txc_h13:       call txrun_b.get                       ; 5D30
            push af
            call txc_cinc
            pop af
            ld [EX_RAM + 4], a
            ld b, a
            ld a, [NES_RAM + $54]
            and $E0
            or b
            ld [NES_RAM + $54], a
            jp txrun_b.rs
txc_h8:        ld hl, NES_RAM + $3A            ; 5D79: $54 = ($54 & $E0 | $3A) + $20
            ld a, [NES_RAM + $54]
            and $E0
            or [hl]
            ld b, $20
            jr txc_hadd
txc_h14:       ld a, [NES_RAM + $54]           ; 5D00
            ld [EX_RAM + 5], a
            ld a, [NES_RAM + $55]
            ld [EX_RAM + 6], a
            ld a, 1
            ld [EX_RAM], a
            ld a, [EX_RAM + 2]
            ld b, $40
txc_hadd:      ld d, a                         ; $54 = A + B (CLC / ADC: C, V), $55 + carry
            add a, b                        ;   (C, D: free until .st; X = E kept)
            ld [NES_RAM + $54], a
            ld c, a
            jr nc, txc_ha1
            ld hl, NES_RAM + $55
            inc [hl]
txc_ha1:       sbc a, a                        ; (C from the ADD still: SBC A gives 0 / $FF)
            and $10
            ld hl, sp + 2
            res 4, [hl]
            or [hl]
            ld [hl], a
            ld a, d                         ; V: (A ^ res) & (B ^ res) & $80
            xor c
            ld d, a
            ld a, b
            xor c
            and d
            and $80
            rrca
            ldh [vfl], a
            jp txrun_b.rs
txc_h15:       ld a, [EX_RAM + 5]              ; 5D1E
            ld [NES_RAM + $54], a
            ld a, [EX_RAM + 6]
            ld [NES_RAM + $55], a
            ld a, 2
            ld [EX_RAM], a
            jp txrun_b.rs

; ---- rlist_b's records in bulk (bank 0: the list read from its ROM bank directly): while the
; LCD is off (or a load masked, no dialogue box), the increment is 1, no cell is nametable 1's,
; the list ($10) is in ROM and the record's cells are nametable 0's (offset + count <= $3C0,
; the record within one 256-byte page... of its ROM region): its bytes to the shadow and the
; GB map (MAP_RB when masked), dmg_scan, the PPU address after it, latch / vblank flag 0;
; $10/$11 += (count + 3) & $FF with C (the flags-out slot of rlist_b) and V as its TYA /
; CLC / ADC $10; X = 0 after a record (as izyrun0 leaves it). Returns at the 0 or at a record
; it does not take (rlist_b's loop does that one). Keeps E if no record, D.
section bank 0, $2DDC
rl_fast:    ldh a, [lcd_on]
            and a
            jr z, .k1
            ld a, [VLCD]
            cp 1
            ret nz
            ldh a, [dlg_on]
            and a
            ret nz
.k1:        ldh a, [ppu_ctrl]
            and 4
            ret nz
            ldh a, [own1_lo]
            ld b, a
            ldh a, [own1_hi]
            or b
            ret nz
            push de                         ; (X: 0 after a record, else kept)
.rec:       ld hl, NES_RAM + $10
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld a, h                         ; ROM region: bank, GB address
            cp $80
            jr c, .x
            cp $C0
            jr nc, .c
            sub $40
            ld h, a
            ldh a, [data_bank8]
            jr .b
.c:         cp $E0
            jr nc, .e
            sub $80
            ld h, a
            ldh a, [data_bankC]
            jr .b
.e:         sub $80
            ld h, a
            ld a, DATA + 31
.b:         ld [$2000], a
            ld a, h                         ; (the last page of an 8 KB area: the loop)
            and $1F
            cp $1F
            jr z, .x
            ld a, [hl+]                     ; address high (0: the end)
            and a
            jr z, .x
            and $3F
            cp $20
            jr c, .x
            cp $3F
            jr z, .x
            ld b, a                         ; B = $2006 high (6 bits)
            and 7
            cp 4
            jr nc, .x
            ld d, a                         ; D:E = the offset
            ld a, [hl+]
            ld e, a
            ld a, [hl+]
            ld c, a                         ; C = count (0: 256)
            ld a, l                         ; the count's bytes within this 256 of the ROM
            add a, c                        ;   address (a page crossing: rlist_b's loop)
            jr c, .x
            ld a, c
            and a
            jr z, .x
            dec a                           ; offset + count <= $3C0
            add a, e
            ld a, d
            adc a, 0
            cp 3
            jr c, .ok
            jr nz, .x
            ld a, c
            dec a
            add a, e
            cp $C0
            jr nc, .x
.ok:        push bc
            push de
            push hl
            ld a, d                         ; shadow
            add a, high(NT_SH)
            ld d, a
            call rl_cpy
            pop hl
            pop de
            pop bc
            ld a, [VLCD]
            cp 1
            jr nz, .mp
            ld [MAP_RB], a
            jr .md
.mp:        push de
            push bc
            ld a, d
            add a, $98
            ld d, a
            call rl_cpy
            pop bc
            pop de
.md:        ldh a, [is_cgb]
            and a
            jr nz, .mc
            inc a
            ldh [dmg_scan], a
.mc:        xor a
            ldh [vbl_flag], a
            ldh [ppu_latch], a
            ld a, c                         ; v = offset + count (6-bit high, mirror bits kept)
            add a, e
            ldh [ppu_vl], a
            ld a, d
            adc a, 0
            ld d, a
            ld a, b
            and $FC
            or d
            ldh [ppu_vh], a
            ld a, c                         ; $10 += (count + 3) & $FF (C, V)
            add a, 3
            ld b, a                         ; B = Y
            ld hl, NES_RAM + $10
            ld a, [hl]
            ld d, a
            add a, b
            ld [hl+], a
            ld e, a
            jr nc, .n1
            inc [hl]
.n1:        sbc a, a
            and $10
            ld hl, sp + 6
            res 4, [hl]
            or [hl]
            ld [hl], a
            ld hl, sp + 0
            xor a
            ld [hl+], a                     ; (X = 0)
            ld [hl], a
            ld a, b                         ; V: (Y ^ sum) & (M ^ sum) & $80
            xor e
            ld c, a
            ld a, d
            xor e
            and c
            and $80
            rrca
            ldh [vfl], a
            ldh a, [code_bank]
            ld [$2000], a
            jp .rec
.x:         ldh a, [code_bank]
            ld [$2000], a
            pop de
            ret
; C bytes (1-255) from HL to DE, four at a time (the rest first). HL, DE advanced, C = 0.
rl_cpy:     ld a, c
            and 3
            jr z, .q
            ld b, a
.r:         ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .r
.q:         srl c
            srl c
            ret z
.l:         ld a, [hl+]
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
            dec c
            jr nz, .l
            ret

; ---- b12:AF9D-AFAC (12 bytes from ($9C) to ($9A), each pair of offsets from the table at
; b12:AFCB: JSR AFAF while $6C8E < $18; then JMP AFE3), natively: the bytes by the runtime's
; (zp),Y read / write; $6C8E = $18; A = $18, X = $17, Y = the last offset; N = 0, Z = C = 1
; (CMP #$18); V kept. ecopy_t: the table, copied by build.py.
section bank PF_BANK, $7B40
ecopy_b:    ldh a, [code_bank]              ; (the helpers come back to code_bank)
            push af
            ld a, PF_BANK
            ldh [code_bank], a
            ld hl, ecopy_t
            ld d, 12
.l:         ld c, [hl]
            inc hl
            ld b, 0
            push hl
            ld l, $9C
            call rt_izy_rd
            ld a, l
            pop hl
            ld c, [hl]
            inc hl
            push hl
            ld l, $9A
            call rt_izy_wr
            pop hl
            dec d
            jr nz, .l
            ld a, $18
            ld [$A000 + $0C8E], a
            pop af
            ldh [code_bank], a
            xor a
            ldh [nzv], a
            ld e, $17                       ; X
            ld d, a
            ld b, a
            ld hl, $1890                    ; A = $18; Z, C
            push hl
            pop af
            ret

; oamconv_b's whole conversion, before its entries (H = the NES page, cart RAM bank 3 on):
; R = the free GB slots (40 less the entries of the last layout) less 4 kept below, at most
; 12, left free (hidden) at the top for entries coming into view above the others later;
; DE = the first slot to fill; OC_TOP, OC_MAXI / OC_MINI ($FF) set; OC_EPO + 1. Keeps BC, H.
section bank HLE_BANK, $5D48
oc_resv:    push bc
            ld a, [OC_EPO]
            inc a
            ld [OC_EPO], a
            ld a, [OC_BOT]                  ; the entries of the last layout (OC_TOP + 4 -
            ld b, a                         ;   OC_BOT) / 4 for the count (a jump in the
            ld a, [OC_TOP]                  ;   count: more than 40 - R in view goes to the
            add a, 4                        ;   forward conversion, as with more than 40)
            sub b
            jr nc, .c1
            xor a
.c1:        rrca
            rrca
            and $3F
            ld b, a
            ld a, 36
            sub b
            jr nc, .rg
            xor a
.rg:        cp 12
            jr c, .rr
            ld a, 12
.rr:        ld b, a
            ld de, OAM_SH + 156
            and a
            jr z, .rd
            xor a
.rh:        ld [de], a
            ld a, e
            sub 4
            ld e, a
            xor a
            dec b
            jr nz, .rh
.rd:        ld a, e
            ld [OC_TOP], a
            ld a, $FE                       ; (OC_MAXI / OC_MINI found when first needed)
            ld [OC_MAXI], a
            pop bc
            ret

; oamconv_b's incremental conversion: NES entry L (HL -> it, DE -> its copy) comes into view
; with no GB entry: a free slot above OC_TOP if it is above every entry with a GB entry, below
; OC_BOT if below every one (NES order kept); A = the slot, OC_POS set, NC. Else C.
oc_new:     push hl                         ; its own slot from this layout (a hole it left)?
            ld h, d
            ld l, e
            inc h                           ; (OC_POS + entry + 1: the layout that gave it)
            inc l
            ld a, [OC_EPO]
            cp [hl]
            jr nz, .f0
            dec l
            ld a, [hl]
            pop hl
            and a
            ret
.f0:        pop hl
.fr:        ld a, [OC_MAXI]                 ; above the highest: the slot above OC_TOP
            cp $FE
            jr nz, .k
            ld a, [OC_BOT]                  ; (an empty layout: the whole page at once)
            sub 4
            push hl
            ld hl, OC_TOP
            cp [hl]
            pop hl
            jr z, .ab
            call oc_mm
.k:         cp $FF
            jr z, .ab
            cp l
            jr nc, .nb
            ld a, [OC_TOP]
            cp 156
            jr nc, .ab
            add a, 4
            ld [OC_TOP], a
            push af
            ld a, l
            ld [OC_MAXI], a
            jr .np
.nb:        ld a, [OC_MINI]                 ; below the lowest: the slot below OC_BOT
            cp l
            jr c, .ab
            jr z, .ab
            ld a, [OC_BOT]
            sub 4
            jr c, .ab
            ld [OC_BOT], a
            push af
            ld a, l
            ld [OC_MINI], a
            ld a, [OAM_USED]                ; (one more in use from the bottom: hidden again
            inc a                           ;   by the next whole conversion's .endr)
            ld [OAM_USED], a
.np:        pop af
            inc d                           ; OC_POS[entry] = the slot, from this layout
            ld [de], a
            push af
            inc e
            ld a, [OC_EPO]
            ld [de], a
            dec e
            pop af
            dec d
            and a                           ; (NC: placed)
            ret
.ab:        scf
            ret

; oamconv_b's incremental conversion: the leading run of OC_LIST (occmp lists the entries
; descending) whose entries are above OC_MAXI reversed, so that entries coming into view
; above the others take the free slots above OC_TOP in ascending order (those coming into
; view below keep the descending order the slots below OC_BOT need). Keeps H.
oc_rev:     push hl
            ld a, [OC_MAXI]
            cp $FF
            jr z, .x
            ld b, a
            ld hl, OC_LIST
            ldh a, [o_cx]
            ld c, a
            ld e, 0
.r1:        ld a, [hl+]
            cp b
            jr c, .r2
            jr z, .r2
            inc e
            dec c
            jr nz, .r1
.r2:        ld a, e
            cp 2
            jr c, .x
            ld hl, OC_LIST
            add a, low(OC_LIST) - 1
            ld c, a
            ld b, high(OC_LIST)
.r3:        ld a, l
            cp c
            jr nc, .x
            ld d, [hl]
            ld a, [bc]
            ld [hl], a
            ld a, d
            ld [bc], a
            inc l
            dec c
            jr .r3
.x:         pop hl
            ret

; OC_MAXI / OC_MINI: the highest / lowest NES entry with a slot from this layout (OC_POS +
; entry + 1 = OC_EPO; holes count, they stay their entries'), $FF if none. A = OC_MAXI.
; Keeps BC, DE, HL.
oc_mm:      push hl
            push bc
            ld a, [OC_EPO]
            ld b, a
            ld c, $FF                       ; (C: the lowest so far)
            ld hl, OC_POS + $FD             ; (entries 63..0: the epoch byte)
            ld a, $FF
            ld [OC_MAXI], a
.l:         ld a, [hl]
            cp b
            jr nz, .n
            ld a, l
            dec a
            ld c, a
            ld a, [OC_MAXI]
            inc a
            jr nz, .n
            ld a, c
            ld [OC_MAXI], a
.n:         ld a, l
            sub 4
            ld l, a
            jr nc, .l
            ld a, c
            ld [OC_MINI], a
            ld a, [OC_MAXI]
            pop bc
            pop hl
            ret

; (moved out of dmg_shade.s's bank-0 section)
section bank 0, $3D40
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

; ---- DMG sprite pages left in ROM: LZ_SRC + 4 * page + 3 = 1 once a byte write changed the
; page's shadow (lz_dirty: B = page; cart RAM bank 0 after; keeps all but A, F). lz_same (E =
; page, HL = the source in the ROM window): a whole-page copy from the same ROM page as last
; time onto a page no byte write changed since: nothing to do, to hle_chr_pages.fsk (the page
; done; cart RAM bank 0); else the mark cleared, cart RAM bank 3 on, back. Keeps BC, DE, HL.
section bank 0, $3E80
lz_dirty:   push hl
            ld a, 3
            ld [$4000], a
            ld a, b
            add a, a
            add a, a
            add a, low(LZ_SRC) + 3
            ld l, a
            ld h, high(LZ_SRC)
            ld [hl], 1
            xor a
            ld [$4000], a
            pop hl
            ret
lz_dirty1:  push bc                         ; (D = SPR_SHADOW page: cart RAM bank 1 after)
            ld a, d
            sub high(SPR_SHADOW)
            ld b, a
            call lz_dirty
            pop bc
            ld a, 1
            ld [$4000], a
            ret
lz_same:    push hl
            push bc
            push de
            ld a, 3
            ld [$4000], a
            ld a, e
            add a, a
            add a, a
            add a, low(LZ_SRC)
            ld c, a
            ld b, high(LZ_SRC)
            ldh a, [data_bank8]
            ld e, a
            ld a, [bc]
            cp e
            jr nz, .no
            inc c
            ld a, [bc]
            cp l
            jr nz, .no
            inc c
            ld a, [bc]
            cp h
            jr nz, .no
            inc c
            ld a, [bc]
            and a
            jr nz, .no
            pop de
            pop bc
            pop hl
            add sp, 2                       ; (not back: the page is done)
            xor a
            ld [$4000], a
            jp hle_chr_pages.fsk
.no:        ld a, c
            or 3
            ld c, a
            xor a
            ld [bc], a
            pop de
            pop bc
            pop hl
            ret

; ---- b12:A169-A1A3 (battle round start: $6848-$6854 = the 13 bytes at b12:A15C (SHUF_I, copied
; from the ROM by build.py), $6AF8 = $6B86 = 0, then the turn order $6849-$6855 shuffled by 17
; swaps of two entries picked by AE5D(0, 12), i.e. (RNG byte x 13) >> 8, the RNG byte
; T[$688A++] from the table at fix:FCE6 (SHUF_H = its bytes x 13 >> 8, build.py). RAM as
; FF1 leaves it: $688E = 0, $68AF = 0, $68B0 = $68B6 = $68B4 = 13, $68B3 = 0, $68B5 = the last
; product's low byte. Out: A = the value stored last (at the first pick), X = the first pick,
; Y = the second; N = 0, Z = 1, C = 0, V = 0.
section bank PF_BANK, $6545
shuf_b:     ld hl, SHUF_I
            ld de, $A848
            ld c, 13
.i:         ld a, [hl+]
            ld [de], a
            inc e
            dec c
            jr nz, .i
            xor a
            ld [$AAF8], a
            ld [$AB86], a
            ld a, $11
            ld [$A88E], a
            ld a, [$A88A]
            ld b, a                         ; B = RNG index
.p:         ld h, high(SHUF_H)
            ld l, b
            inc b
            ld d, [hl]                      ; D = first pick
            ld l, b
            inc b
            ld a, [hl]
            ld c, a                         ; C = second pick
            ld h, $A8
            add a, $48
            ld l, a                         ; HL = $6848 + second
            ld a, d
            add a, $48
            ld e, a
            ld a, [hl]                      ; A = its value
            ld l, e
            ld e, [hl]                      ; E = the first's
            ld [hl], a
            ld a, c
            add a, $48
            ld l, a
            ld [hl], e
            ld hl, $A88E
            dec [hl]
            jr nz, .p
            ld a, b
            ld [$A88A], a
            dec a
            add a, $E6                      ; the last RNG byte (fix:FCE6 + index, through
            ld l, a                         ;   rt_rd_e) x 13, low byte
            ld a, $7C
            adc a, 0
            ld h, a
            ldh a, [code_bank]
            push af
            ld a, PF_BANK
            ldh [code_bank], a
            call rt_rd_e
            pop af
            ldh [code_bank], a
            ld a, l
            add a, a
            add a, l
            add a, a
            add a, a
            add a, l
            ld [$A8B5], a
            xor a
            ld [$A8AF], a
            ld [$A8B3], a
            ldh [nzv], a
            ldh [vfl], a
            ld a, 13
            ld [$A8B0], a
            ld [$A8B6], a
            ld [$A8B4], a
            ld e, d
            ld b, 0
            ld d, 0
            ld h, $A8
            ld a, e
            add a, $48
            ld l, a
            xor a                           ; (Z = 1, C = 0)
            ld a, [hl]
            ret

; ---- btx_b's fast path (the text in ExRAM $5F00-$5FFF, the pairs in save RAM below $7E00)
section bank PF_BANK, $7830
btx_f:
            ld hl, NES_RAM + $92            ; fast path: the text in ExRAM $5F00-$5FFF, the
            ld a, [hl+]                     ;   pairs in save RAM below $7E00
            ld e, a
            ld a, [hl]
            sub $60
            cp $1E
            jp nc, btx_b.lp
            add a, $A0
            ld d, a                         ; DE = destination (GB)
            ld hl, NES_RAM + $90
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld a, h
            cp $5F
            jp nz, btx_b.lp
            ld h, high(EX_RAM) + 3          ; HL = source (GB)
            ld b, 0                         ; B: the last letter (0: none yet)
.fl:        ld a, [hl]
            cp $48
            jr c, .fe                       ; (0 too)
            ld b, a
            cp $7A
            jr c, .fc
            ld a, $FF
            ld [de], a
            inc de
            ld a, b
.fw:        ld [de], a
            inc de
            inc l
            jr nz, .fl
            push af                         ; past $5FFF: the general loop goes on
            call .fs
            pop af
            jp btx_b.lp
.fe:        push af
            call .fs
            pop af
            jp btx_b.end
.fs:        ld a, l                         ; $90 / $92 / $9E, C as the last letter left it
            ld [NES_RAM + $90], a
            ld a, h
            sub high(EX_RAM) - $5C
            ld [NES_RAM + $91], a
            ld a, e
            ld [NES_RAM + $92], a
            ld a, d
            sub $40
            ld [NES_RAM + $93], a
            ld a, b
            and a
            ret z
            ld [NES_RAM + $9E], a
            ld hl, sp + 6
            res 4, [hl]
            cp $7A
            jr c, .fs1
            set 4, [hl]
.fs1:       ld c, 0                         ; (Y = 0 after a letter: FCA7)
            ret
.fc:        cp $70                          ; dakuten byte, then the tile
            ld a, $C0
            jr c, .f0
            inc a
.f0:        ld [de], a
            inc de
            ld a, $40
            ldh [vfl], a
            ld a, b
            cp $57
            jr nc, .f1
            add a, $47
            jr .fw
.f1:        cp $5C
            jr nc, .f2
            add a, $4C
            jr .fw
.f2:        cp $6B
            jr nc, .f3
            add a, $73
            jr .fw
.f3:        cp $70
            jr nc, .f4
            add a, $78
            jr .fw
.f4:        cp $75
            jr nc, .f5
            add a, $33
            jr .fw
.f5:        add a, $6E
            jr .fw


; ---- far vstr / vchar in ROM bank VWF_BANK (hle_vstr), with the glyphs pre-shifted at build
; time (build.py vwf_shift_tables): VWS_LO / VWS_HI = glyph -> its block of 8 x 16 bytes
; (shift s: 8 rows for the glyph's tile, then the 8 rows spilling into the next tile); glyphs
; without ink share a block of zeros. Same RAM as before (VC, VX, VSQ, VCNT, VSH, VT2, VOFF,
; $88/$89, VBUF).
section bank VWF_BANK, $7400
; vstr is lazy (deferred drawing): it computes everything the NES routine leaves in RAM
; (VC, VX, VSQ, VCNT, VSH, VT2, VOFF, $88/$89) without drawing, and records a job in cart
; RAM bank 3 (VX, VSQ and VN at the call, then the bytes of VSTR it went over). vclear is
; lazy too (VX = 0; the clear pending, the jobs before it dropped). The jobs are drawn into
; VBUF by vjob_run, which hle_vtile calls before the first tile upload after them (gb_layout's
; vupload waits for a frame before it): the drawing lands in that light frame, not in the
; frame that laid the text out. Only vchar and vtile use VBUF.
VJ_CLR     = $AB00          ; (cart RAM bank 3) passes of 8 bytes to clear first, 0: none
VJ_N       = $AB01          ; jobs recorded
VJ_JOBS    = $AB10          ; jobs of 64 bytes: VX, VSQ, VN, length, bytes (up to VJ_MAX)
VJ_MAX     = 60
VJ_CAP     = 3
vstr_b:     ld [VW_VC], a
            ld c, a                         ; C = start
            ld a, [VW_VX]                   ; the state at the call (for the job / a fallback)
            ldh [wtmp], a
            ld a, [VW_VSQ]
            ld b, a
            push bc
            call vstr_dry
            pop bc                          ; C = start, B = VSQ at the call
            ld a, [VW_VC]
            sub c                           ; A = bytes gone over
            cp VJ_MAX + 1
            jr nc, .now
            ld e, a                         ; E = length
            ld a, 3
            ld [$4000], a
            ld a, [VJ_N]
            cp VJ_CAP
            jr nc, .now0
            ld d, a                         ; job slot: HL = VJ_JOBS + 64 * D
            inc a
            ld [VJ_N], a
            ld a, d
            rrca
            rrca
            and $C0
            add a, low(VJ_JOBS)
            ld l, a
            ld a, high(VJ_JOBS)
            adc a, 0
            ld h, a
            ldh a, [wtmp]
            ld [hl+], a                     ; VX
            ld [hl], b                      ; VSQ
            inc hl
            xor a
            ld [$4000], a
            ld a, [VW_VN]
            ld d, a
            ld a, 3
            ld [$4000], a
            ld [hl], d                      ; VN
            inc hl
            ld [hl], e                      ; length
            inc hl
            ld a, e
            and a
            jr z, .done
            ld a, c                         ; the bytes, from VSTR + start
            add a, low(VW_VSTR)
            ld c, a
            ld b, high(VW_VSTR)
.cp:        xor a
            ld [$4000], a
            ld a, [bc]
            inc bc
            ld d, a
            ld a, 3
            ld [$4000], a
            ld [hl], d
            inc hl
            dec e
            jr nz, .cp
.done:      xor a
            ld [$4000], a
            ld a, 1
            ldh [apq_n], a                  ; (a job pending: hle_vtile)
            ld b, 0
            ld d, 0
            ret
.now0:      xor a                           ; no room for a job: the pending ones drawn, then
            ld [$4000], a                   ;   this one at once (as before)
.now:       push bc
            call vjob_run
            pop bc
            ldh a, [wtmp]
            ld [VW_VX], a
            ld a, b
            ld [VW_VSQ], a
            ld a, c
            call vstr_n
            ld b, 0
            ld d, 0
            ret

; vstr without drawing: the same walk and the same RAM results (vchar_dry per letter)
vstr_dry:
.l:         ld a, [VW_VEND]
            ld c, a
            ld a, [VW_VC]
            cp c
            ret nc
            add a, low(VW_VSTR)
            ld l, a
            ld h, high(VW_VSTR)
            ld a, [hl]
            and a
            ret z
            cp $FD
            jr nz, .c
            inc l
            ld a, [hl]
            sub $80
            add a, a
            add a, a
            add a, a
            ld [VW_VX], a
            ld hl, VW_VC
            inc [hl]
            jr .n
.c:         call vchar_dry
.n:         ld hl, VW_VC
            inc [hl]
            jr nz, .l
            ret
vchar_dry:  cp $FD
            ret z
            cp $FF
            jr nz, .g
            ld a, [VW_VX]
            add a, 3
            ld [VW_VX], a
            ret
.g:         sub VW_FIRST
            ret c
            ld e, a
            ld hl, vw_gw58
            add a, l
            ld l, a
            jr nc, .w
            inc h
.w:         ld a, [hl]
            and a
            ret z
            ld [VW_VCNT], a
            ld l, e
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            ld bc, VW_GR_NES
            add hl, bc
            ld a, l
            ld [NES_RAM + $88], a
            ld a, h
            ld [NES_RAM + $89], a
            ld a, [VW_VX]
            and 7
            ld [VW_VSH], a
            ld a, [VW_VX]
            srl a
            srl a
            srl a
            ld c, a
            ld a, [VW_VN]
            ld d, a
            ld a, c
            cp d
            jp nc, vchar_n.adv
            ld [VW_VT2], a
            add a, a
            add a, a
            add a, a
            ld [VW_VOFF], a
            jp vchar_n.adv

; vclear, lazy: VX = 0, the clear (VN * 8 bytes, 256 for VN 0 mod 32) left pending, the
; jobs before it dropped. Out as the NES routine: A = X = 0, Y kept; N = 0, Z = 1, C = 1.
vclear_l:   xor a
            ld [VW_VX], a
            ldh [nzv], a
            ld a, [VW_VN]
            and $1F
            jr nz, .n0
            ld a, 32
.n0:        ld e, a
            ld a, 3
            ld [$4000], a
            ld a, e
            ld [VJ_CLR], a
            xor a
            ld [VJ_N], a
            ld [$4000], a
            inc a
            ldh [apq_n], a
            xor a
            ld de, 0
            push af
            pop hl
            ld l, $90                       ; (Z, C)
            push hl
            pop af
            ret

; the pending clear and jobs into VBUF (the real VX, VN, VSQ, VCNT, VSH, VT2, VOFF, VC,
; $88/$89 kept). Keeps all registers.
vjob_run:   push af
            push bc
            push de
            push hl
            xor a
            ldh [apq_n], a
            ld hl, VW_VX                    ; save: VX VN, VCNT VSH VOFF, VT2, VC
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld c, a
            push bc
            inc l
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld c, a
            ld a, [hl+]
            ld d, a                         ; (VOFF; VLO at $AE96 not touched)
            inc l
            ld a, [hl]
            ld e, a                         ; (VT2)
            push bc
            push de
            ld a, [VW_VC]
            ld b, a
            ld a, [VW_VSQ]
            ld c, a
            push bc
            ld a, [NES_RAM + $88]
            ld b, a
            ld a, [NES_RAM + $89]
            ld c, a
            push bc
            ld a, 3
            ld [$4000], a
            ld a, [VJ_CLR]
            ld e, a
            xor a
            ld [VJ_CLR], a
            ld [$4000], a
            ld a, e
            and a
            jr z, .jobs
            ld hl, VW_BUF
            xor a
.cl:        ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            dec e
            jr nz, .cl
.jobs:      ld a, 3
            ld [$4000], a
            ld a, [VJ_N]
            ld b, a
            xor a
            ld [VJ_N], a
            ld [$4000], a
            ld a, b
            and a
            jr z, .end
            ld hl, VJ_JOBS
.job:       push bc
            push hl
            ld a, 3
            ld [$4000], a
            ld a, [hl+]
            ld b, a                         ; VX
            ld a, [hl+]
            ld c, a                         ; VSQ
            ld a, [hl+]
            ld d, a                         ; VN
            ld a, [hl+]
            ld e, a                         ; length
            xor a
            ld [$4000], a
            ld a, b
            ld [VW_VX], a
            ld a, c
            ld [VW_VSQ], a
            ld a, d
            ld [VW_VN], a
            ld a, e
            and a
            jr z, .jn
.ch:        ld a, 3
            ld [$4000], a
            ld a, [hl+]
            ld b, a
            ld c, [hl]                      ; (the byte after: a pen code's operand)
            xor a
            ld [$4000], a
            ld a, b
            cp $FD
            jr nz, .gl
            inc hl                          ; $FD $80+n: pen to tile n
            dec e
            ld a, c
            sub $80
            add a, a
            add a, a
            add a, a
            ld [VW_VX], a
            jr .nx
.gl:        push de
            push hl
            call vchar_n
            pop hl
            pop de
.nx:        dec e
            jr nz, .ch
.jn:        pop hl
            ld de, 64
            add hl, de
            pop bc
            dec b
            jr nz, .job
.end:       pop bc                          ; restore
            ld a, b
            ld [NES_RAM + $88], a
            ld a, c
            ld [NES_RAM + $89], a
            pop bc
            ld a, b
            ld [VW_VC], a
            ld a, c
            ld [VW_VSQ], a
            pop de
            pop bc
            ld hl, VW_VCNT
            ld a, b
            ld [hl+], a
            ld a, c
            ld [hl+], a
            ld a, d
            ld [hl+], a
            inc l
            ld [hl], e
            pop bc
            ld hl, VW_VX
            ld a, b
            ld [hl+], a
            ld [hl], c
            pop hl
            pop de
            pop bc
            pop af
            ret

vstr_r:     call vstr_n                     ; (the old entry: draws at once)
            ld b, 0
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
            ld hl, vw_gw58
            add a, l
            ld l, a
            jr nc, .w
            inc h
.w:         ld a, [hl]
            and a
            ret z
            ld [VW_VCNT], a
            ld l, e                         ; $88/$89 = GR + glyph * 8 (NES address)
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            ld bc, VW_GR_NES
            add hl, bc
            ld a, l
            ld [NES_RAM + $88], a
            ld a, h
            ld [NES_RAM + $89], a
            ld a, [VW_VX]
            and 7
            ld [VW_VSH], a
            ld b, a                         ; B = shift
            ld a, [VW_VX]
            srl a
            srl a
            srl a                           ; A = tile
            ld c, a
            ld a, [VW_VN]
            ld d, a                         ; D = tiles in the line
            ld a, c
            cp d
            jr nc, .adv
            ld [VW_VT2], a
            add a, a
            add a, a
            add a, a
            ld [VW_VOFF], a
            push de
            ld d, high(VWS_LO)              ; HL = the glyph's block + 16 * shift
            ld a, [de]
            ld l, a
            inc d
            ld a, [de]
            ld h, a
            ld a, b
            swap a
            add a, l
            ld l, a
            pop de
            ld a, [VW_VOFF]
            ld e, a                         ; E = VBUF offset of the tile, D = VN
            ld a, c
            inc a
            cp d                            ; NC: tile + 1 >= VN, the line's last tile
            ld d, high(VW_BUF)
            ld a, b
            jr nc, .one
            and a
            jr z, .one                      ; (shift 0: nothing spills)
            ld c, 16
            jr .rows
.one:       ld c, 8
.rows:      ld a, [de]
            or [hl]
            ld [de], a
            inc l
            inc e
            dec c
            jr nz, .rows
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

; ---- b21:8861-887A (name entry, every frame): LDA $2002, PPU $1D00, then the 16 bytes at
; b21:887C (CT16_T, copied by build.py) to $2007: sprite tile $D0. Unchanged bytes are left
; alone by the generic path anyway, so when all 16 equal the sprite shadow (the tile brought
; into the shadow first if still in ROM), only the PPU address moves on ($1D10); else the
; generic writes. Out: A = the last byte, X = $10, Y kept; N = 0, Z = 1, C = 1 (CPX #$10).
section bank PF_BANK, $6F40
ct16_b:     ldh a, [code_bank]
            push af
            ld a, PF_BANK
            ldh [code_bank], a
            push bc
            call rt_ppu_r2
            ld a, $1D
            call rt_ppu_w6
            xor a
            call rt_ppu_w6
            ld a, $D0
            call spr_mat
            ld a, 1
            ld [$4000], a
            ld hl, CT16_T
            ld de, SPR_SHADOW + $D0 * 16
            ld c, 8
.p0:        ld a, [de]                      ; plane 0 -> even bytes
            cp [hl]
            jr nz, .gen
            inc hl
            inc e
            inc e
            dec c
            jr nz, .p0
            ld de, SPR_SHADOW + $D0 * 16 + 1
            ld c, 8
.p1:        ld a, [de]                      ; plane 1 -> odd bytes
            cp [hl]
            jr nz, .gen
            inc hl
            inc e
            inc e
            dec c
            jr nz, .p1
            xor a
            ld [$4000], a
            ld a, $1D                       ; all the same: $1D10 (two $2006 writes leave the
            call rt_ppu_w6                  ;   latch as the 16 data writes do)
            ld a, $10
            call rt_ppu_w6
            jr .out
.gen:       xor a
            ld [$4000], a
            ld a, $1D
            call rt_ppu_w6
            xor a
            call rt_ppu_w6
            ld hl, CT16_T
            ld c, 16
.w:         ld a, [hl+]
            push hl
            push bc
            call rt_ppu_w7g
            pop bc
            pop hl
            dec c
            jr nz, .w
.out:       pop bc
            pop af
            ldh [code_bank], a
            xor a
            ldh [nzv], a
            ld de, $0010                    ; X = $10
            ld a, [CT16_T + 15]
            scf
            ld h, a
            ld l, $D0                       ; flags: Z = 1, C = 1 (bits 7, 4), N via nzv
            push hl
            pop af
            ret

; ---- txrun_b's ROM read-ahead (Lot Check-safe scratch: NES page 1 above FF1's $0100 /
; $0110-$0112 and below the deepest stack seen, not part of the RAM checks; cleared at boot)

section bank 0, $2F84
; HL = NES ROM address ($8000-$FFFF), 32-aligned; DE = destination: 32 bytes copied (ROM
; through its data bank, then code_bank mapped again). Keeps nothing.
rd32:       ld a, h
            cp $C0
            jr nc, .c
            sub $40
            ld h, a
            ldh a, [data_bank8]
            jr .go
.c:         cp $E0
            jr nc, .e
            sub $80
            ld h, a
            ldh a, [data_bankC]
            jr .go
.e:         sub $80
            ld h, a
            ld a, DATA + 31
.go:        ld [$2000], a
            ld b, 32
.l:         ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .l
            ldh a, [code_bank]
            ld [$2000], a
            ret

; ---- txrun_b .get from ROM: a 32-byte read-ahead copy (RC_BUF; tag = the block's NES address
; and its data bank). HL = NES address -> A. Keeps BC, DE.
section bank PF_BANK, $7366
rc_get:     push de                         ; ROM: through a 32-byte read-ahead copy (RC_BUF;
            ld a, l                         ;   tag = the block's NES address and bank)
            and $E0
            ld e, a
            ld a, [RC_HI]
            cp h
            jr nz, .rf
            ld a, [RC_LO]
            cp e
            jr nz, .rf
            call .rcb
            ld d, a
            ld a, [RC_B]
            cp d
            jr nz, .rf
.rh:        ld a, l
            and $1F
            add a, low(RC_BUF)
            ld e, a
            ld d, high(RC_BUF)
            ld a, [de]
            pop de
            ret
.rf:        push bc
            push hl
            ld a, h
            ld [RC_HI], a
            ld a, e
            ld [RC_LO], a
            ld l, e
            call .rcb
            ld [RC_B], a
            ld de, RC_BUF
            call rd32
            pop hl
            pop bc
            jr .rh
.rcb:       ld a, h                         ; A = the data bank of address H
            cp $C0
            jr nc, .rc1
            ldh a, [data_bank8]
            ret
.rc1:       cp $E0
            jr nc, .rc2
            ldh a, [data_bankC]
            ret
.rc2:       ld a, DATA + 31
            ret
