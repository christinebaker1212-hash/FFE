; Native layer (docs/ff2-gb-native-layer.md): game routines that did NES hardware work
; through the runtime's register emulation, as GB routines; and the GB-side primitives they
; use (no PPU address latch, no $2007 data port). Code in bank DYN_BANK from $6000 (the
; dynamic-target table uses its start), reached through bank-0 stubs (rt_fcs).

section bank 0, $3FC0
hle_palcp:  call rt_fcs                     ; fix:DC30 copy colour palettes to ppu
            db DYN_BANK
            dw hle_palcp_b
hle_scr4b:  call rt_fcs                     ; fix:FD4B battlefield scroll
            db DYN_BANK
            dw hle_scr4b_b
hle_scr60:  call rt_fcs                     ; fix:FD60-FD6B menu scroll (after the sprite-0 wait)
            db DYN_BANK
            dw hle_scr60_b
hle_cdf5:   call rt_fcs                     ; fix:CDF5 update ppu registers (normal map)
            db DYN_BANK
            dw hle_cdf5_b

section bank DYN_BANK, $6000
; ---- primitive: NES palette entry L (0-31) = colour D. As the NES: $10 / $14 / $18 / $1C
; are $00 / $04 / $08 / $0C. Changed entries: CGB palettes again (that entry; the backdrop:
; all), DMG / SGB maps due. Keeps BC, DE.
gb_pal:     ld a, l
            and $1F
            ld l, a
            and $13
            cp $10
            ld a, l
            jr nz, .pn
            and $0F
.pn:        ld l, a
            ld h, high(PAL_SH)
            ld a, d
            and $3F
            cp [hl]
            ret z                           ; same colour: nothing changes
            ld [hl], a
            push bc
            ld a, l
            and a
            jr nz, .pm
            dec a                           ; the backdrop: every palette's colour 0
            ld hl, PAL_DM
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl], a
            jr .pd
.pm:        ld c, a                         ; the entry's bit in PAL_DM
            and 7
            ld hl, BIT_MASK
            add a, l
            ld l, a
            jr nc, .pc
            inc h
.pc:        ld b, [hl]
            ld a, c
            rrca
            rrca
            rrca
            and 3
            add a, low(PAL_DM)
            ld l, a
            ld h, high(PAL_DM)
            ld a, [hl]
            or b
            ld [hl], a
.pd:        ld a, 1
            ldh [pal_dirty], a
            ldh [maps_due], a
            xor a
            ldh [pal_age], a
            pop bc
            ret

; ---- fix:DC30 copy colour palettes to ppu: the 32 bytes at $03C0 into the palettes, then
; as the NES leaves the PPU: address $0000, latch reset, the vblank flag read (cleared).
; Exit: A = 0, X = $20, Y kept, Z = 1, N = 0, C = 1.
hle_palcp_b:
            push bc
            ld l, 0
.l:         push hl
            ld h, high(NES_RAM + $0300)
            ld a, l
            add a, $C0
            ld l, a
            ld d, [hl]
            pop hl
            push hl
            call gb_pal
            pop hl
            inc l
            ld a, l
            cp $20
            jr nz, .l
            xor a
            ldh [ppu_vh], a
            ldh [ppu_vl], a
            ldh [ppu_latch], a
            ldh [vbl_flag], a
            ldh [nzv], a
            pop bc
            ld e, $20
            ld d, 0
            scf
            ld l, 0
            inc l
            dec l                           ; Z = 1, C = 1, A = 0
            ret

; ---- primitive: a scroll value as the NES's second register takes it (the first of a pair
; is X, the second Y; reading the status register starts a pair again). A kept, flags kept.
gb_scroll:  push af
            ldh a, [ppu_latch]
            xor 1
            ldh [ppu_latch], a
            jr z, .y
            pop af
            ldh [scroll_x], a
            ret
.y:         pop af
            ldh [scroll_y], a
            ret

; A = the NES's A at the end: its N / Z (nzv, Z flag); carry kept
nat_nz:     ldh [nzv], a
            inc a
            dec a
            ret

; ---- fix:FD4B (battle, after the battlefield split): control $3B, scroll $39 / $37.
; Exit: A = $37 with its N / Z, carry kept.
hle_scr4b_b:
            ld a, [NES_RAM + $3B]
            ldh [ppu_ctrl], a
            ld a, [NES_RAM + $39]
            call gb_scroll
            ld a, [NES_RAM + $37]
            call gb_scroll
            jp nat_nz

; ---- fix:FD60-FD6B (menus, after the sprite-0 hit): control $3A, one scroll value $38.
; Exit: A = $38 with its N / Z, carry kept.
hle_scr60_b:
            ld a, [NES_RAM + $3A]
            ldh [ppu_ctrl], a
            ld a, [NES_RAM + $38]
            call gb_scroll
            jp nat_nz

; ---- fix:CDF5 update ppu registers (normal map): $FF = control = $FD, scroll X = $29 * 16
; | $35, Y = $2F * 16 | $36. Exit: A = Y with its N / Z, carry = bit 4 of $2F (its ASLs).
hle_cdf5_b:
            ld a, [NES_RAM + $FD]
            ld [NES_RAM + $FF], a
            ldh [ppu_ctrl], a
            ld a, [NES_RAM + $29]
            swap a
            and $F0
            ld l, a
            ld a, [NES_RAM + $35]
            or l
            call gb_scroll
            ld a, [NES_RAM + $2F]
            swap a
            ld l, a
            and $F0
            ld h, a
            ld a, [NES_RAM + $36]
            or h
            ld h, a
            ld a, l
            rra                             ; carry = bit 4 of $2F
            ld a, h
            call gb_scroll
            jp nat_nz

; ---- b13:9C1F update apu registers: the music engine's channel shadow ($6F19 + 4 x + k,
; work RAM) to the GB channels (sound core, rt_apu_w), channels enabled; per channel x
; (square 1, square 2, triangle) unless its bit in $E6 is set, square 2 not while a sound
; effect plays ($E5): register k when the update flag ($C0 + x, LSR) says so. Same RAM
; effects as the NES ($E7, $C0-$C2). Exit: A = the last value loaded, X = 3, Y = 12, Z =
; 1, C = 1, N = 0.
hle_apuout_b:
            ld a, $0F                       ; $4015 = status | $0F: all four enabled
            ld l, $15
            call rt_apu_w
            ld a, [NES_RAM + $E6]
            ld [NES_RAM + $E7], a
            ldh [tmp_lo], a                 ; (the NES's A so far)
            ld bc, 0                        ; B = channel, C = 4 x channel
.ch:        ld hl, NES_RAM + $E7
            srl [hl]
            jr c, .nx
            ld a, b
            cp 1
            jr nz, .go
            ld a, [NES_RAM + $E5]
            ldh [tmp_lo], a
            and a
            jr nz, .nx
.go:        ld e, 0                         ; E = register k
.k:         ld a, b
            add a, $C0
            ld l, a
            ld h, high(NES_RAM)
            srl [hl]
            jr nc, .nk
            ld a, c
            add a, e
            ld d, a                         ; D = 4 x + k (the APU register)
            add a, $19
            ld l, a
            ld h, $AF                       ; $6F19 + 4 x + k (cart RAM bank 0)
            ld a, [hl]
            ldh [tmp_lo], a
            ld l, d
            call rt_apu_w
.nk:        inc e
            ld a, e
            cp 4
            jr nz, .k
.nx:        ld a, c
            add a, 4
            ld c, a
            inc b
            ld a, b
            cp 3
            jr c, .ch
            ld b, 0
            ld d, 0
            ld e, 3
            xor a
            ldh [nzv], a
            ldh a, [tmp_lo]
            scf
            ld l, 0
            inc l
            dec l                           ; Z = 1, C = 1
            ret

; ---- fix:F069 copy text to ppu (with the GB layout's one-row mode, h_flush / onerow):
; the text buffer rows $0780 (upper) and $07A0 (lower) at column $38, tile row $3B: the
; first $91 bytes at ($3A, $3B), the rest ($91 to $3C) from column 0 of the other
; nametable. Two rows (upper, then lower at $3B + 1), or only the lower row while ExRAM
; $5C01 >= 1. Then $90 = 0, $3B = ($3B + 1) mod 30. NES address of row y: rows 30 / 31 =
; 0 / 1 (the game's row table). Exit as the NES: A = $3B, X = the last index, Y = the row
; of the last run, flags of the final compare / subtract.
TX_BUF     = $CCF3          ; hle_txrow: buffer low byte ($80 / $A0) (MD_A)
TX_X       = $CCF6          ;   X at the end (MD_IDX)
TX_Y       = $CCF7          ;   Y at the end (MD_ADD)
TX_HI      = $CCF0          ; nt_copy arguments (native.s MD_HI, MD_LO, MD_SRC)
TX_LO      = $CCF1
TX_SRC     = $CCF4
hle_txrow_b:
            ld a, [NES_RAM + $38]
            ld [NES_RAM + $3A], a
            ld a, [EX_RAM + 1]
            cp 1
            jr nc, .one
            ld a, $80
            call .row
            ld a, [NES_RAM + $38]
            ld [NES_RAM + $3A], a
            ld hl, NES_RAM + $3B
            inc [hl]
.one:       ld a, $A0
            call .row
            xor a
            ld [NES_RAM + $90], a
            ld a, [NES_RAM + $3B]
            inc a
            ld h, $80                       ; (N = 1, Z = 0, C = 0: CMP below $1E)
            cp $1E
            jr c, .st
            sub $1E
            ld h, 0
            ld l, $10                       ; (C = 1, Z if zero)
            jr nz, .st2
            ld l, $90
            jr .st2
.st:        ld l, 0
.st2:       ld [NES_RAM + $3B], a
            ld d, a
            ld a, h
            ldh [nzv], a
            ld h, d
            push hl
            pop af                          ; A = $3B, F = Z / C
            ld b, 0
            ld d, 0
            push af
            ld a, [TX_X]
            ld e, a
            ld a, [TX_Y]
            ld c, a
            pop af
            ret
            ; one buffer row (A = $80 / $A0) at ($3A, $3B)
.row:       ld [TX_BUF], a
            call .addr
            ld a, [NES_RAM + $91]           ; first run: indices 0 .. $91 - 1 (at least 1)
            and a
            jr nz, .n1
            inc a
.n1:        ld [TX_X], a
            ld b, a
            xor a
            call .run
            ld a, [NES_RAM + $3C]
            ld b, a
            ld a, [TX_X]
            cp b
            ret nc                          ; all written
            ld a, [NES_RAM + $3A]           ; the other nametable, column 0
            and $20
            xor $20
            ld [NES_RAM + $3A], a
            call .addr
            ld a, [NES_RAM + $91]           ; second run: indices $91 .. $3C - 1 (at least 1)
            ld c, a
            ld a, [NES_RAM + $3C]
            sub c
            jr z, .n2
            jr nc, .n2b
.n2:        ld a, 1
.n2b:       ld b, a
            add a, c
            ld [TX_X], a
            ld a, c
            ; A = first index, B = count
.run:       ld c, a
            ld a, [TX_BUF]
            add a, c
            ld [TX_SRC], a
            ld a, high(NES_RAM + $0700)
            ld [TX_SRC + 1], a
            ld a, b
            call rt_fcs                     ; (returns to .run's caller)
            db HLE_BANK
            dw nt_copy
            ; LDA $2002 (latch, vblank flag), then the PPU address of ($3A, $3B)
.addr:      xor a
            ldh [ppu_latch], a
            ldh [vbl_flag], a
            ld a, [NES_RAM + $3B]
            ld [TX_Y], a
            cp 30
            jr c, .r
            sub 30
.r:         ld c, a                         ; row r: $2000 + 32 r
            rrca
            rrca
            rrca
            and 3
            or $20
            ld b, a
            ld a, c
            and 7
            swap a
            add a, a
            ld c, a                         ; (r & 7) << 5
            ld a, [NES_RAM + $3A]
            cp $20
            jr c, .l
            and $1F
            set 2, b
.l:         or c
            ld [TX_LO], a
            ld a, b
            ld [TX_HI], a
            ret

; ---- layout ntrow (tools/gb2/layout.py): window row VLINE of the window at VROW / VCOL,
; VW x VH: top frame (FTILE 0-2), bottom frame (5-7), or left side, VW - 2 text tiles from
; (VP) (VP advanced; Y = 0) or the blank tile (VFILL), right side (3, 4). Same RAM effects
; (VSH, VT, VP); exit A = the last tile, X = 0, N / Z of it, C as the NES leaves it (top 0,
; bottom 1, other rows VLINE + 1 >= VH).
NR_VT      = $BFE4          ; layout RAM (NES $7FE4 ...: cart RAM bank 0)
NR_VSH     = $BFE6
NR_VROW    = $BFF0
NR_VCOL    = $BFF1
NR_VW      = $BFF2
NR_VH      = $BFF3
NR_VLINE   = $BFF4
NR_VFILL   = $BFFD
NR_BLANKT  = $B888
NR_FTILE   = $B889
NR_FILL    = $DCF9          ; (native.s NC_FILL)
NR_CNT     = $DCFA          ; text tiles per row
NR_C       = $DCFB          ; exit carry ($10 / 0)
hle_ntrow_b:
            push bc
            ld a, [NR_VROW]                 ; r = VROW + VLINE: VSH = r << 5, VT = r >> 3
            ld hl, NR_VLINE
            add a, [hl]
            ld c, a
            and 7
            swap a
            add a, a
            ld [NR_VSH], a
            ld hl, NR_VCOL
            or [hl]
            ld [TX_LO], a
            ld a, c
            rrca
            rrca
            rrca
            and $1F
            ld [NR_VT], a
            or $20
            and $3F
            ld [TX_HI], a
            ld a, [NR_VW]
            sub 2
            ld [NR_CNT], a
            xor a                           ; NR_C = exit carry
            ld [NR_C], a
            ld a, [NR_VLINE]
            and a
            jr z, .top
            inc a
            ld hl, NR_VH
            cp [hl]
            jr z, .bot
            jr c, .mc                       ; (6502 C: VLINE + 1 >= VH)
            ld a, $10
            ld [NR_C], a
.mc:        ld hl, NR_FTILE + 3             ; left side
            call .one
            ld a, [NR_VFILL]
            and a
            jr z, .txt
            ld a, 1
            ld [NR_FILL], a
            ld hl, NR_BLANKT
            ld a, [NR_CNT]
            call .seg
            jr .rt
.txt:       pop hl                          ; text tiles from (VP): Y = 0 (the saved C)
            ld l, 0
            push hl
            ld a, [NES_RAM + $D2]
            ld l, a
            ld a, [NES_RAM + $D3]
            ld h, a
            ld a, [NR_CNT]                  ; VP += VW - 2
            add a, l
            ld [NES_RAM + $D2], a
            ld a, h
            adc a, 0
            ld [NES_RAM + $D3], a
            ld a, h                         ; NES address -> GB (cart RAM / work RAM)
            cp $60
            jr c, .wr
            add a, $40
            jr .gh
.wr:        add a, high(NES_RAM)
.gh:        ld h, a
            ld a, [NR_CNT]
            call .seg
.rt:        ld hl, NR_FTILE + 4             ; right side
            jr .last
.top:       ld hl, NR_FTILE + 0
            call .one
            ld a, 1
            ld [NR_FILL], a
            ld hl, NR_FTILE + 1
            ld a, [NR_CNT]
            call .seg
            ld hl, NR_FTILE + 2
            jr .last
.bot:       ld a, $10
            ld [NR_C], a
            ld hl, NR_FTILE + 5
            call .one
            ld a, 1
            ld [NR_FILL], a
            ld hl, NR_FTILE + 6
            ld a, [NR_CNT]
            call .seg
            ld hl, NR_FTILE + 7
.last:      push hl
            call .one
            pop hl
            ld a, [hl]                      ; exit: A = the last tile, N / Z of it, C
            ld d, a
            and $80
            ldh [nzv], a
            ld a, [NR_C]
            ld e, a
            ld a, d
            and a
            jr nz, .nz
            set 7, e                        ; (Z)
.nz:        pop bc
            ld b, 0
            ld h, d
            ld l, e
            push hl
            pop af
            ld de, 0
            ret
            ; HL = source, A = count: through nt_copy (rt_fcs returns to .seg's caller)
.one:       ld a, 1
.seg:       ld c, a
            ld a, l
            ld [TX_SRC], a
            ld a, h
            ld [TX_SRC + 1], a
            ld a, c
            call rt_fcs
            db HLE_BANK
            dw nt_copy

; ---- layout pdraw (prophecy / prologue frame, tools/gb2/layout.py): the attribute row PAR
; (>= 0: 8 bytes PATT at $23C0 + 8 PAR), then the line: PRLEN bytes at PRA from (PRP) (PRM
; 0: font codes $80-$CF - $7F; 2: blank tiles $FF), PRLEN = 0. Exit as the NES.
PD_PAR     = $B608          ; (cart RAM: NES $7608 ...)
PD_PATT    = $B609
PD_PRM     = $B60A
PD_PRLEN   = $B60B
PD_PRA     = $B60C
PD_B       = $DCFC          ; the byte being written
PD_C       = $DCFD          ; exit carry ($10 / 0)
PD_X       = $DCFE          ; exit X
hle_pdraw_b:
            ld a, e
            ld [PD_X], a
            ld a, 0
            jr nc, .c0
            ld a, $10
.c0:        ld [PD_C], a
            push bc
            ld a, [PD_PAR]
            bit 7, a
            jr nz, .nl
            add a, a                        ; C = bit 5 (ASL x 3)
            add a, a
            add a, a
            ld b, a
            ld a, 0
            jr nc, .c1
            ld a, $10
.c1:        ld [PD_C], a
            ld a, b
            or $C0
            ld [TX_LO], a
            ld a, $23
            ld [TX_HI], a
            xor a
            ld [PD_X], a                    ; (X = 0 after the loop)
            ld a, 1
            ld [NR_FILL], a
            ld hl, PD_PATT
            ld a, 8
            call .seg
.nl:        ld a, [PD_PRLEN]
            and a
            jr z, .x0
            ld a, [PD_PRA + 1]
            and $3F
            ld [TX_HI], a
            ld a, [PD_PRA]
            ld [TX_LO], a
            pop bc
            ld c, 0                         ; Y
            push bc
.ch:        ld a, [PD_PRM]
            cp 2
            ld a, $FF
            jr z, .w
            ld a, [PD_PRM]
            ld [PD_X], a
            ld a, [NES_RAM + $D4]           ; (PRP), Y
            add a, c
            ld l, a
            ld a, [NES_RAM + $D5]
            adc a, 0
            ld h, a
            push bc
            call nes_rd
            pop bc
            ld a, [PD_PRM]
            and a
            ld a, l
            jr nz, .w
            cp $80
            jr c, .w
            cp $D0
            jr nc, .w
            sub $7F
.w:         ld [PD_B], a
            push bc
            ld hl, PD_B
            call .one
            pop bc
            inc c
            ld a, [PD_PRLEN]
            cp c
            jr nz, .ch
            xor a
            ld [PD_PRLEN], a
            ld a, $10                       ; (CPY: C = 1)
            ld [PD_C], a
            pop hl                          ; (Y = PRLEN)
            ld b, 0
            jr .x
.x0:        pop bc                          ; A = 0, Z = 1, N = 0
.x:         ld a, [PD_X]
            ld e, a
            ld d, 0
            xor a
            ldh [nzv], a
            ld a, [PD_C]
            or $80
            ld h, 0
            ld l, a
            push hl
            pop af
            ret
            ; HL = source, A = count: through nt_copy (rt_fcs returns to .seg's caller)
.one:       ld a, 1
.seg:       ld b, a
            ld a, l
            ld [TX_SRC], a
            ld a, h
            ld [TX_SRC + 1], a
            ld a, b
            call rt_fcs
            db HLE_BANK
            dw nt_copy

; ---- fix:DCB5 copy color palettes to ppu (the 16 BG entries from $03F0), then the PPU
; address $3F00 and $0000 written (v = 0). Exit: A = 0, X = $10, N = 0, Z = 1, C = 1.
hle_palbg_b:
            push bc
            ld l, 0
.l:         push hl
            ld h, high(NES_RAM + $0300)
            ld a, l
            add a, $F0
            ld l, a
            ld d, [hl]
            pop hl
            push hl
            call gb_pal
            pop hl
            inc l
            ld a, l
            cp $10
            jr nz, .l
            xor a
            ldh [ppu_vh], a
            ldh [ppu_vl], a
            ldh [ppu_latch], a
            ldh [vbl_flag], a
            ldh [nzv], a
            pop bc
            ld e, $10
            ld d, 0
            scf
            ld l, 0
            inc l
            dec l                           ; Z = 1, C = 1, A = 0
            ret

; ---- fix:D2FE update dialog window attributes: entries X = 15 (moving vertically) or 14
; down to 0: the byte $07F0 + X at the PPU address ($07D0 + X, $07E0 + X). Exit: A = the
; byte of entry 0, X = $FF, N = 1, Z = 0, C kept.
DA_X       = $DCFE          ; entry
hle_dlgatt8_b:                              ; fix:D308 (entries X down to 0)
            push af
            push bc
            ld a, e
            jr hle_dlgatt_b.v
hle_dlgatt_b:
            push af
            push bc
            ld a, [NES_RAM + $2D]
            and 2
            ld a, $0F
            jr z, .v
            dec a
.v:         ld [DA_X], a
            xor a
            ldh [vbl_flag], a
            ldh [ppu_latch], a
.lp:        ld a, [DA_X]
            ld l, a
            ld h, high(NES_RAM + $0700)
            ld a, l
            add a, $D0
            ld l, a
            ld a, [hl]
            and $3F
            ld [TX_HI], a
            ld a, l
            add a, $10
            ld l, a
            ld a, [hl]
            ld [TX_LO], a
            ld a, l
            add a, $10
            ld [TX_SRC], a
            ld a, h
            ld [TX_SRC + 1], a
            call .one
            ld hl, DA_X
            dec [hl]
            bit 7, [hl]
            jr z, .lp
            pop bc
            pop af                          ; (carry)
            ld a, $80
            ldh [nzv], a
            ld a, [NES_RAM + $07F0]
            ld e, $FF
            ld d, 0
            push af
            pop hl
            res 7, l                        ; Z = 0
            push hl
            pop af
            ret
.one:       ld a, 1
            call rt_fcs                     ; (returns to .one's caller)
            db HLE_BANK
            dw nt_copy

; ---- layout scrw (tools/gb2/layout.py scroll without the music): field menu (MSCR, NES
; $7FEA): control = $FF, scroll 0 / 0; else control = $3B, scroll $39 / $37. Exit: A = the
; last value with its N / Z, carry kept.
hle_scrw_b:
            ld a, [$BFEA]
            inc a                           ; (carry kept)
            dec a
            jr z, .b
            ld a, [NES_RAM + $FF]
            ldh [ppu_ctrl], a
            ld a, 0                         ; (carry kept)
            call gb_scroll
            call gb_scroll
            jp nat_nz
.b:         ld a, [NES_RAM + $3B]
            ldh [ppu_ctrl], a
            ld a, [NES_RAM + $39]
            call gb_scroll
            ld a, [NES_RAM + $37]
            call gb_scroll
            jp nat_nz

; ---- fix:E9DC clear ppu scrolling registers: scroll 0 / 0. Exit: A = 0, Z = 1, N = 0,
; carry kept.
hle_scr00_b:
            ld a, 0                         ; (carry kept)
            call gb_scroll
            call gb_scroll
            jp nat_nz

; ---- layout gmattr (main menu): the 64 attribute bytes $77A0.. to $23C0. Exit: A = the
; last byte, X = 64, N = 0, Z = 1, C = 1 (CPX #64).
hle_gmattr_b:
            ld a, $23
            ld [TX_HI], a
            ld a, $C0
            ld [TX_LO], a
            ld a, low($B7A0)
            ld [TX_SRC], a
            ld a, high($B7A0)
            ld [TX_SRC + 1], a
            xor a
            ldh [ppu_latch], a
            ldh [nzv], a
            push bc
            ld a, 64
            call .run
            pop bc
            ld e, 64
            ld d, 0
            ld a, [$B7DF]
            ld h, a
            ld l, $90                       ; (Z, C)
            push hl
            pop af
            ret
.run:       call rt_fcs                     ; (returns to .run's caller)
            db HLE_BANK
            dw nt_copy

; ---- layout lnrow (battle message line VLN): NES row 19 + VLN, columns 1-18: 17 tiles
; from (VP), then the blank tile. VSH / VT as the NES leaves them. Exit: A = the blank
; tile with its N / Z, X = 0, Y = 17, C = 1 (CPY #17).
hle_lnrow_b:
            ld a, [$BFFE]                   ; r = VLN + 19
            add a, 19
            ld c, a
            and 7
            swap a
            add a, a
            ld [NR_VSH], a
            or 1
            ld [TX_LO], a
            ld a, c
            rrca
            rrca
            rrca
            and $1F
            ld [NR_VT], a
            or $20
            and $3F
            ld [TX_HI], a
            xor a
            ldh [ppu_latch], a
            ld a, [NES_RAM + $D2]           ; (VP): NES -> GB address
            ld [TX_SRC], a
            ld a, [NES_RAM + $D3]
            cp $60
            jr c, .wr
            add a, $40
            jr .gh
.wr:        add a, high(NES_RAM)
.gh:        ld [TX_SRC + 1], a
            ld a, 17
            call .run
            ld a, low(NR_BLANKT)
            ld [TX_SRC], a
            ld a, high(NR_BLANKT)
            ld [TX_SRC + 1], a
            ld a, 1
            call .run
            ld a, [NR_BLANKT]
            ld d, a
            and $80
            ldh [nzv], a
            ld e, $10                       ; (C)
            ld a, d
            and a
            jr nz, .nz
            set 7, e
.nz:        ld h, d
            ld l, e
            push hl
            pop af
            ld bc, 17
            ld de, 0
            ret
.run:       call rt_fcs                     ; (returns to .run's caller)
            db HLE_BANK
            dw nt_copy

; ---- b11:9D7C copy color palettes to ppu (battle: the 32 entries from $79A8), then the PPU
; address $3F00 and $0000. Exit: A = $3F, X = 0, N = 0, Z = 1, C = 1.
hle_palbtl_b:
            push bc
            ld l, 0
.l:         push hl
            ld a, l
            add a, low($B9A8)
            ld l, a
            ld a, high($B9A8)
            adc a, 0
            ld h, a
            ld d, [hl]
            pop hl
            push hl
            call gb_pal
            pop hl
            inc l
            ld a, l
            cp $20
            jr nz, .l
            xor a
            ldh [ppu_vh], a
            ldh [ppu_vl], a
            ldh [ppu_latch], a
            ldh [vbl_flag], a
            ldh [nzv], a
            pop bc
            ld de, 0
            ld a, $3F
            ld h, a
            ld l, $90                       ; (Z, C)
            push hl
            pop af
            ret

; ---- boot splash (fix:F476..), the PPU parts of the glyph routine (idioms):
; fix:F565-F57F: from ($62, $61) to the row's end the tile 0 ($80 = $61 advanced to the
; next row). Exit: A = 0, X = 0, N = 0, Z = 1, carry kept.
hle_splrow0_b:
            push af
            ld a, [NES_RAM + $61]
            ld [NES_RAM + $80], a
            ld a, 0
            jr spl_row
; fix:F5D4-F5ED: the same from $80 with the tile $80 (LDA $2002 first). Exit: A = 0,
; X = $80, N = V = 0, Z = 1, carry kept.
hle_splrow8_b:
            push af
            ld a, $80
spl_row:    ld [PD_B], a
            ld e, a                         ; (X at the end)
            xor a
            ldh [ppu_latch], a
            ldh [vbl_flag], a
            ldh [nzv], a
            ld a, [NES_RAM + $62]
            and $3F
            ld [TX_HI], a
            ld a, [NES_RAM + $61]
            ld [TX_LO], a
            ld a, low(PD_B)
            ld [TX_SRC], a
            ld a, high(PD_B)
            ld [TX_SRC + 1], a
            ld a, 1
            ld [NR_FILL], a
            ld a, [NES_RAM + $80]           ; count = 32 - ($80 & 31); $80 -> next row
            ld l, a
            and $E0
            add a, $20
            ld [NES_RAM + $80], a
            ld a, l
            and $1F
            cpl
            add a, 33
            push de
            push bc
            call .run
            pop bc
            pop de
            pop af                          ; (carry)
            ld a, 0
            ld l, 0
            inc l
            dec l                           ; Z = 1, carry kept
            ret
.run:       call rt_fcs                     ; (returns to .run's caller)
            db HLE_BANK
            dw nt_copy
; fix:F632-F648: the glyph buffer $0350 (16 bytes) to the pattern table at $0800. Exit:
; A = the last byte, X = $10, N = 0, Z = 1, C = 1.
hle_splchr8_b:
            ld a, $08
            ld l, $00
            call spl_chr
            ld a, [NES_RAM + $035F]
            jr spl_x
; fix:F653-F680: the glyph buffer to tile $64 of the pattern table, then tile $64 at
; ($62, $61). Exit: A = $64 with its N / Z, X = $10, C = 1.
hle_splchr64_b:
            ld a, [NES_RAM + $64]
            swap a
            ld l, a
            and $0F
            ld h, a
            ld a, l
            and $F0
            ld l, a
            ld a, h
            call spl_chr
            ld a, [NES_RAM + $62]
            and $3F
            ld [TX_HI], a
            ld a, [NES_RAM + $61]
            ld [TX_LO], a
            ld a, low(NES_RAM + $64)
            ld [TX_SRC], a
            ld a, high(NES_RAM + $64)
            ld [TX_SRC + 1], a
            push bc
            ld a, 1
            call spl_row.run
            pop bc
            ld a, [NES_RAM + $64]
spl_x:      ld d, a
            and $80
            ldh [nzv], a
            ld a, d
            and a
            ld l, $10                       ; (C)
            jr nz, .nz
            ld l, $90                       ; (Z, C)
.nz:        ld h, d
            push hl
            pop af
            ld de, $0010
            ret
            ; A:L = pattern address: the 16 bytes from $0350 (copy_core; C kept)
spl_chr:    and $3F
            ldh [ppu_vh], a
            ld a, l
            ldh [ppu_vl], a
            xor a
            ldh [ppu_latch], a
            push bc
            ld hl, $0350
            ld e, 16
            call copy_core
            pop bc
            ret

; ---- layout pfscr (prologue frame): control = $FF, scroll 0 / 0. Exit: A = 0, Z = 1,
; N = 0, carry kept.
hle_pfscr_b:
            ld a, [NES_RAM + $FF]
            ldh [ppu_ctrl], a
            jp hle_scr00_b

; ---- home code (translate.py HOME_*: routines placed in bank 0 that run with their data
; bank mapped at $4000): (zp),Y reads straight from the mapped bank when the pointer is in
; its window, else as rt_izy_rd. L = zp pointer, C = Y (B = 0) -> L = the byte; A, F, BC,
; DE kept.
section bank 0, $25C0
rt_izy_rd8m:                                ; data bank = the NES bank at $8000-$BFFF
            push af
            ld h, high(NES_RAM)
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            add hl, bc
            ld a, h
            sub $80
            cp $40
            jr nc, izy_m_other
            add a, $40                      ; $8000-$BFFF -> $4000-$7FFF
            ld h, a
            ld l, [hl]
            pop af
            ret
rt_izy_rdem:                                ; data bank = the fixed bank ($E000-$FFFF)
            push af
            ld h, high(NES_RAM)
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            add hl, bc
            ld a, h
            cp $E0
            jr c, izy_m_other
            sub $80                         ; $E000-$FFFF -> $6000-$7FFF
            ld h, a
            ld l, [hl]
            pop af
            ret
izy_m_other:
            call nes_rd
            pop af
            ret
