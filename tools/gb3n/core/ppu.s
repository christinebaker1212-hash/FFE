; FF3 core rewrite: the GB port of the NES PPU registers FF3's translated routines write
; (docs/ff3-gb-rewrite.md "PPU"). FF3's logic around the PPU stays FF3's; only its STA $2000 / $2001 /
; $2005 / $2006 / $2007 / $4014 become calls here:
;   ppu_2000 (A) control: NMI flag, address step, pattern tables, nametable select
;   ppu_2001 (A) mask: rendering off = the GB screen blanked (black palettes, no sprites; the LCD
;                stays on: Lot Check 2.1) and VRAM writes wait for H-Blank / V-Blank
;   ppu_2002     the address / scroll latch reset (A = $80: FF3 only waits on it in loops we replace)
;   ppu_2005 (A) scroll x then y;  ppu_2006 (A) address high then low;  ppu_2007 (A) a byte at the address
;   ppu_4014     the OAM page $0200 converted to the GB OAM buffer (shown at the next V-Blank)
; Memory: NES pattern table 0 / 1 -> GB VRAM bank 0 / 1 $8000 (tile n at $8000 + 16 n; NES plane
; rows to GB interleaved, byte by byte); nametable cell (row r, column c) of either horizontal
; nametable -> the GB BG map $9800 + 32 r + c, its CGB attribute byte (VRAM bank 1) = the NES palette
; of its attribute quadrant + the BG pattern table's VRAM bank; $3F00-$3F1F -> nes_pal (CGB palettes
; made in V-Blank). The 160 x 144 view: SCX = scroll x + cam_x, SCY = scroll y + cam_y (mod 240, with
; an LYC split where it crosses row 240). All registers kept but A where noted; the carry kept.

section bank 0, $2000
ppu_2000:   ldh [p_ctrl], a
            ret
ppu_2001:   push af
            ldh [p_mask], a
            and $18
            ldh [p_blank], a                ; (0: rendering off)
            pop af
            ret
ppu_2002:   push af
            xor a
            ldh [p_latch], a
            pop af
            ld a, $80
            ret
ppu_2005:   push af
            push hl
            ld hl, p_latch
            ld a, [hl]
            xor 1
            ld [hl], a
            pop hl
            jr z, .y
            pop af
            ldh [p_sx], a
            ret
.y:         pop af
            ldh [p_sy], a
            ret
ppu_2006:   push af
            push hl
            ld hl, p_latch
            ld a, [hl]
            xor 1
            ld [hl], a
            pop hl
            jr z, .lo
            pop af
            and $3F
            ldh [p_ah], a
            ret
.lo:        pop af
            ldh [p_al], a
            ret

; ---- a byte to the PPU address, the address stepped (1, or 32 by $2000 bit 2)
ppu_2007:   push af
            push bc
            push de
            push hl
            ld b, a                         ; B = the byte
            ldh a, [p_ah]
            cp $20
            jr c, .pat
            cp $3F
            jr nc, .pal
            ldh a, [p_al]                   ; nametable: offset $000-$3FF
            ld l, a
            ldh a, [p_ah]
            and 3
            ld h, a
            cp 3
            jr nz, .cell
            ld a, l
            cp $C0
            jr nc, .attr
.cell:      ld a, l                         ; GB map $9800 + offset (row r, column c: 32 r + c)
            ld e, a
            ld a, h
            add high($9800)
            ld d, a
            call v_wait
            ld a, b
            ld [de], a
            ld a, 1                         ; its attribute: the quadrant's palette, the bank
            ldh [rVBK], a
            call t_attr                     ; A = the cell's CGB attribute
            call v_wait
            ld [de], a
            xor a
            ldh [rVBK], a
            jr .step
.attr:      ld a, l                         ; an attribute byte: remembered, its 16 cells redone
            and $3F
            ld e, a
            ld d, high(nes_att)
            ld a, b
            ld [de], a
            call t_quad
            jr .step
.pat:       ldh a, [p_al]                   ; pattern: tile = addr >> 4, row = addr & 7, plane = bit 3
            ld l, a
            ldh a, [p_ah]
            ld h, a
            and $10                         ; table 0 / 1 -> VRAM bank 0 / 1
            swap a
            ldh [rVBK], a
            ld a, h
            and $0F
            ld h, a
            ld a, l
            and $F0
            ld e, a                         ; DE = $8000 + (addr & $0FF0)
            ld a, h
            add $80
            ld d, a
            ld a, l
            and 7
            add a
            bit 3, l
            jr z, .p0
            inc a
.p0:        or e
            ld e, a
            call v_wait
            ld a, b
            ld [de], a
            xor a
            ldh [rVBK], a
            jr .step
.pal:       ldh a, [p_al]                   ; ($3F10 / 14 / 18 / 1C are $3F00 / 04 / 08 / 0C)
            and $1F
            ld e, a
            and $13
            cp $10
            jr nz, .pc
            ld a, e
            sub $10
            ld e, a
.pc:        ld d, high(nes_pal)
            ld a, b
            and $3F
            ld [de], a
            ld a, 1
            ldh [pal_dirty], a
.step:      ldh a, [p_ctrl]
            and 4
            ld a, 1
            jr z, .s1
            ld a, 32
.s1:        ld hl, p_al
            add [hl]
            ld [hl+], a
            ld a, [hl]
            adc 0
            and $3F
            ld [hl], a
            pop hl
            pop de
            pop bc
            pop af
            ret

; wait until VRAM can be written (LCD off, or mode 0 / 1); A kept
v_wait:     push af
            ldh a, [rLCDC]
            bit 7, a
            jr z, .x
.w:         ldh a, [rSTAT]
            and 2
            jr nz, .w
.x:         pop af
            ret

; A = the CGB attribute of nametable cell offset L (H = 0-3): its quadrant's palette from nes_att, the
; BG pattern table's VRAM bank (bit 3)
t_attr:     push hl
            push de
            ld a, l                         ; quadrant: attribute byte (row / 4) * 8 + col / 4,
            and $1F                         ;   shift ((row & 2) * 2 + (col & 2))
            ld e, a
            ld a, h
            and 3
            ld d, a
            ld a, l                         ; row = (H * 256 + L) / 32
            srl d
            rra
            srl d
            rra
            srl a
            srl a
            srl a
            ld d, a                         ; D = row, E = column
            and $1C
            add a
            ld l, a
            ld a, e
            srl a
            srl a
            or l
            ld l, a
            ld h, high(nes_att)
            ld a, [hl]
            bit 1, d
            jr z, .h
            swap a
.h:         bit 1, e
            jr z, .v
            rrca
            rrca
.v:         and 3
            ld l, a
            ldh a, [p_ctrl]                 ; BG pattern table: VRAM bank bit 3
            and $10
            rrca
            or l
            pop de
            pop hl
            ret

; the 16 cells of attribute byte E (0-63) get their CGB attributes again
t_quad:     ld a, e
            and 7
            add a
            add a
            ld c, a                         ; C = first column
            ld a, e
            srl a
            srl a
            srl a
            add a
            add a
            ld b, a                         ; B = first row
            ld d, 4
.r:         ld e, 4
.c:         push bc
            push de
            ld a, b                         ; offset 32 row + column
            cp 30
            jr nc, .sk
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld a, l
            or c
            ld l, a
            call t_attr
            ld b, a
            ld de, $9800
            add hl, de
            ld a, 1
            ldh [rVBK], a
            call v_wait
            ld [hl], b
            xor a
            ldh [rVBK], a
.sk:        pop de
            pop bc
            inc c
            dec e
            jr nz, .c
            ld a, c
            sub 4
            ld c, a
            inc b
            dec d
            jr nz, .r
            ret

section hram, $FFA0
p_ctrl:     ds 1
p_mask:     ds 1
p_blank:    ds 1
p_latch:    ds 1
p_sx:       ds 1
p_sy:       ds 1
p_al:       ds 1
p_ah:       ds 1
pal_dirty:  ds 1
cam_x:      ds 1
cam_y:      ds 1

section wram, $CC40
nes_pal:    ds 32                           ; (page-aligned users: nes_pal / nes_att on $CCxx)
section wram, $CD00
nes_att:    ds 64                           ; the attribute table (last written of either nametable)
