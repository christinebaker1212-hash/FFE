; FF3 native port: Game Boy picture helpers for the routines that draw (docs/ff3-gb-rewrite.md
; "Picture (native)"). FF3's nametable cell (row r 0-29, column c 0-63 of its two side-by-side
; nametables) is GB BG map cell (r, c mod 32); its CGB attribute byte (VRAM bank 1) = the palette FF3
; keeps for it in its attribute shadow $0300-$037F (64 bytes a nametable) + the VRAM bank of the BG
; tiles (bg_bank). VRAM is written in modes 0 / 1 (or with the LCD off).

section bank 0, $2000
; wait until VRAM can be written (LCD off, or mode 0 / 1); A and the flags kept
v_wait:     push af
            ldh a, [rLCDC]
            bit 7, a
            jr z, .x
.w:         ldh a, [rSTAT]
            and 2
            jr nz, .w
.x:         pop af
            ret

; tile A to FF3 cell (row D, column E): the GB map byte and its CGB attribute. BC, DE kept; HL scratch
gbv_cell:   push af
            call gbv_addr                   ; HL = $9800 + 32 row + (column & 31)
            pop af
            call v_wait
            ld [hl], a
            ; (fall into the attribute)
; the CGB attribute of FF3 cell (row D, column E) from the $0300 shadow; HL = its GB map address
gbv_attr:   push bc
            call gbv_pal                    ; A = palette 0-3
            ld b, a
            ldh a, [bg_bank]
            or b
            ld b, a
            call gbv_addr
            ld a, 1
            ldh [rVBK], a
            ld a, b
            call v_wait
            ld [hl], a
            xor a
            ldh [rVBK], a
            pop bc
            ret
; HL = $9800 + 32 D + (E & 31)
gbv_addr:   ld a, d
            and 7
            swap a
            add a
            ld l, a                         ; (32 row: low byte)
            ld a, d
            srl a
            srl a
            srl a
            add high($9800)
            ld h, a
            ld a, e
            and 31
            or l
            ld l, a
            ret
; A = FF3's palette for cell (row D, column E): shadow byte $0300 + 64 (E >> 5) + 8 (D >> 2) + (E & 31) >> 2,
; quadrant bits by (D & 2, E & 2)
gbv_pal:    push hl
            ld a, d
            and $1C
            add a
            ld l, a
            ld a, e
            and 31
            srl a
            srl a
            or l
            bit 5, e
            jr z, .n
            or $40
.n:         ld l, a
            ld h, high(NR2 + $0300)
            ld a, [hl]
            bit 1, d
            jr z, .h
            swap a
.h:         bit 1, e
            jr z, .v
            rrca
            rrca
.v:         and 3
            pop hl
            ret

section hram, $FFA0
bg_bank:    ds 1                            ; VRAM bank of the BG tiles (CGB attribute bit 3: 0 / 8)
