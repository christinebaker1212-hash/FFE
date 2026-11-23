; ---- battle graphics (FF3 banks $2E / $2F) on the GB: the monsters' graphics, FF3's monster
; tilemap ($7900, 32 x 14 = NES rows 5-18) and attribute table ($7D27), the battle palettes
; ($7CF7), shown on the GB as BG map rows 0-13 (tiles and palettes from VRAM bank 0, the CGB
; attributes from FF3's attribute table), the view from NES (20, 48) (the approved layout: the
; battlefield in the top 96 lines, the windows below). Bosses and back attacks: later.
TB_A2D0    = BD_2F + $20C       ; 2F/A2D0: first tile of each monster type (build.py)
BT_ROWS    = 14

; 2F/A14A init monster / bg graphics + 2E/9D88 palettes + 2E/9E64 characters
bg_init:    call chr_init
            call pal_init
            call mon_gfx
            ld hl, W7 + $7900               ; 2F/A362 clear the monster tilemap
            ld de, 32 * BT_ROWS
            call memclr
            call mon_pos
            call mon_attrs
            ld a, [W7 + $7D68]              ; 2E/9D5F: the battle song (bit 6: boss)
            bit 6, a
            ld b, $20
            jr z, .s
            ld a, [W7 + $7D73]
            and $1F
            ld b, $28
            cp 8
            jr z, .s
            ld b, $2A
.s:         ld a, b
            jp snd_song

; 2E/9E64: the members' rows ($620F bit 0) and jobs ($6100) -> $7D8F / $7D8B; status buffer
chr_init:   ld hl, GS + $100
            ld de, 0
.m:         ld a, [hl]
            push hl
            ld hl, W7 + $7D8B
            add hl, de
            ld [hl], a
            pop hl
            push hl
            ld a, l
            add a, $0F
            ld l, a
            inc h                           ; ($6100 + $10F = $620F)
            ld a, [hl]
            and 1
            ld hl, W7 + $7D8F
            add hl, de
            ld [hl], a
            pop hl
            ld a, l
            add a, $40
            ld l, a
            inc e
            ld a, e
            cp 4
            jr nz, .m
            ld hl, W7 + $78BB
            ld de, W7 + $7D9B
            ld bc, 8
            jp memcpy

; 2E/9DA2: bg 0 / 1 = the monster palettes, bg 2 = the battle bg's general palette, bg 3 = menu
; window ($FB), sprites 0-2 = characters ($FC-$FE), 3 = cursor ($FF); colour 0 always black
pal_init:   ld a, [W7 + $7D69]
            ld b, $00
            call pal_one
            ld a, [W7 + $7D6A]
            ld b, $04
            call pal_one
            ld a, [W7 + $7CEF]              ; FF877: 00/9100 / 9200 / 9300 + bg
            ld l, a
            ld h, high(BD_GPAL)
            call bd_rd
            ld [W7 + $7CF0], a
            ld a, [W7 + $7CEF]
            ld l, a
            ld h, high(BD_GPAL) + 1
            call bd_rd
            ld [W7 + $7CF1], a
            ld a, [W7 + $7CEF]
            ld l, a
            ld h, high(BD_GPAL) + 2
            call bd_rd
            ld [W7 + $7CF2], a
            ld a, $0F
            ld [W7 + $7CF7 + 8], a
            ld hl, W7 + $7CF0
            ld de, W7 + $7CF7 + 9
            ld bc, 3
            call memcpy
            ld a, $FB
            ld b, $0C
            call pal_one
            ld a, $FC
            ld b, $10
            call pal_one
            ld a, $FD
            ld b, $14
            call pal_one
            ld a, $FE
            ld b, $18
            call pal_one
            ld a, $FF
            ld b, $1C
            ; (fall through)
; 2E/9E28 + 9E1A: battle palette A (2E/8C00 + 3 A) -> $7CF7 + B
pal_one:    ld c, a
            push bc
            ld e, b
            ld d, 0
            ld hl, W7 + $7CF7
            add hl, de
            ld d, h
            ld e, l
            ld a, $0F
            ld [de], a
            inc de
            ld l, c                         ; 3 c
            ld h, 0
            ld b, h
            add hl, hl
            add hl, bc
            ld bc, BD_PAL
            add hl, bc
            ld bc, 3
            ld a, BDATA_BANK
            call rd_copy
            pop bc
            ret

; 2F/A37F init monster graphics: each type's tiles to its ppu place (2F/A42E)
mon_gfx:    xor a
            ld [BZ + $86], a
.t:         ld [btl_k], a
            add a, low(W7 + $7D6B)
            ld l, a
            ld h, high(W7 + $7D6B)
            ld a, [hl]
            cp $FF
            jr z, .n
            ld a, [W7 + $7D7B]
            cp 9
            jr z, .n                        ; (bosses: later)
            call mon_gfx1
.n:         ld a, [btl_k]
            inc a
            cp 4
            jr nz, .t
            ret
mon_gfx1:   ld a, [btl_k]                   ; props $7D73 + 2 type
            add a, a
            add a, low(W7 + $7D73)
            ld l, a
            ld h, high(W7 + $7D73)
            ld a, [hl]
            ld [BZ + $88], a
            and $E0                         ; class * 4 -> 2F/A4B4: address, bank, size
            rrca
            rrca
            rrca
            add a, low(TB_GFX)
            ld l, a
            ld h, high(TB_GFX)
            ld de, btl_tmp
            ld bc, 4
            ld a, BDATA_BANK
            call rd_copy
            ld a, [btl_tmp + 3]             ; width x height = tiles
            add a, a
            add a, low(TB_SIZE)
            ld l, a
            ld h, high(TB_SIZE)
            call bd_rd
            ld b, a
            call bd_rd
            call bmul8                       ; A = tiles (<= 216)
            ld [BZ + $82], a
            ld e, a                         ; graphics address + id * tiles * 16
            ld d, 0
            ld a, [BZ + $88]
            and $1F
            ld b, a
            ld hl, 0
            and a
            jr z, .a0
.mu:        add hl, de
            dec b
            jr nz, .mu
.a0:        add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld a, [btl_tmp]
            ld e, a
            ld a, [btl_tmp + 1]
            sub $40                         ; (NES $8000- -> GB $4000-)
            ld d, a
            add hl, de
            push hl
            ld a, [BZ + $86]                ; the ppu place: 2F/A4A4 + 2 n (+ 8 for class 0)
            add a, a
            ld c, a
            ld hl, BZ + $86
            inc [hl]
            ld a, [BZ + $88]
            and $E0
            jr nz, .p
            ld a, c
            add a, 8
            ld c, a
.p:         ld a, c
            add a, low(TB_PPU)
            ld l, a
            ld h, high(TB_PPU)
            call bd_rd
            ld e, a
            call bd_rd
            add a, $80                      ; (VRAM $8000 + ppu)
            ld d, a
            ld a, [btl_tmp + 2]             ; the bank: pairs $10-$13 -> MGFX_BANK0 + 0-3
            sub $10
            jr nc, .b
            ld a, 4                         ; (pair $06: summon graphics)
.b:         add a, MGFX_BANK0
            ld [vc_src], a
            pop hl
            ld a, [BZ + $82]
            ld b, a
            xor a                           ; (VRAM bank 0)
            jp vcopyx

; 2F/A247 update monster positions: each slot's rectangle of tile ids in the tilemap
mon_pos:    call pos_ptr
            ld c, 0                         ; slot
.s:         push hl
            call bd_rd                      ; x
            cp $FF
            jr z, .end
            ld [BZ + $8C], a
            call bd_rd
            ld [BZ + $8E], a
            call bd_rd
            ld [BZ + $90], a
            ld a, c
            add a, low(W7 + $7DA7)
            ld l, a
            ld h, high(W7 + $7DA7)
            ld a, [hl]
            cp $FF
            jr z, .n
            add a, low(TB_A2D0)
            ld l, a
            ld h, high(TB_A2D0)
            push bc
            call bd_rd
            ld [BZ + $91], a
            call mon_rect
            pop bc
.n:         pop hl
            inc hl
            inc hl
            inc hl
            inc c
            ld a, c
            cp 8
            jr nz, .s
            ret
.end:       pop hl
            ret
; HL = the tilemap id's position data (2F/A5E6 pointer -> BDATA)
pos_ptr:    ld a, [W7 + $7D7B]
            add a, a
            add a, low(TB_POS)
            ld l, a
            ld h, high(TB_POS)
            call bd_rd
            ld e, a
            call bd_rd
            ld d, a
            ld hl, BD_2F - $A4A4
            add hl, de
            ret
; 2F/A2D4: tiles $91.. in a width x height rectangle at $7900 + (y - 5) * 32 + x
mon_rect:   ld a, [BZ + $8E]
            sub 5
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld a, [BZ + $8C]
            ld e, a
            ld d, 0
            add hl, de
            ld de, W7 + $7900
            add hl, de
            push hl
            ld a, [BZ + $90]
            add a, a
            add a, low(TB_SIZE)
            ld l, a
            ld h, high(TB_SIZE)
            call bd_rd
            ld b, a                         ; width
            call bd_rd
            ld c, a                         ; height
            pop hl
            ld a, [BZ + $91]
            ld d, a
.r:         push hl
            ld e, b
.c:         ld [hl], d
            inc hl
            inc d
            dec e
            jr nz, .c
            pop hl
            ld a, l
            add a, 32
            ld l, a
            jr nc, .k
            inc h
.k:         dec c
            jr nz, .r
            ld a, d
            ld [BZ + $91], a
            ret

; 2F/A6B1 update monster attribute table: A857 (attribute data, 4 bytes a type -> $7D17), A697
; (all palette 3, the bg rows palette 2), then each monster's 2 x 2 blocks from its bits
mon_attrs:  xor a
.l:         ld [btl_k], a                   ; 2F/A86C
            add a, low(W7 + $7D6B)
            ld l, a
            ld h, high(W7 + $7D6B)
            ld a, [hl]
            cp $FF
            jr z, .ln
            ld a, [btl_k]
            add a, a
            add a, low(W7 + $7D73)
            ld l, a
            ld h, high(W7 + $7D73)
            ld a, [hl+]
            ld [BZ + $8C], a
            ld a, [hl]
            ld [BZ + $8D], a
            ld a, [BZ + $8C]                ; base 2F/A8D8 + class (words), x 2F/A8E4 + class
            and $E0
            swap a
            ld c, a                         ; (class * 2)
            ld b, 0
            ld hl, mattr_base
            add hl, bc
            ld a, [hl+]
            ld e, a
            ld d, [hl]
            srl c
            ld hl, mattr_mul
            add hl, bc
            ld b, [hl]
            ld a, [BZ + $8D]
            and $3F
            call bmul8
            ld l, a
            ld h, b
            add hl, de                      ; (2E/8Fxx -> BD_8F00 + xx)
            ld de, BD_8F00 - $8F00
            add hl, de
            ld a, [btl_k]
            add a, a
            add a, a
            add a, low(W7 + $7D17)
            ld e, a
            ld d, high(W7 + $7D17)
            ld bc, 4
            ld a, BDATA_BANK
            call rd_copy
            ld a, [BZ + $8D]
            bit 7, a
            jr z, .ln
            ld a, [btl_k]
            add a, a
            add a, a
            add a, low(W7 + $7D17)
            ld l, a
            ld h, high(W7 + $7D17)
            ld b, 4
.x:         ld a, [hl]
            cpl
            ld [hl+], a
            dec b
            jr nz, .x
.ln:        ld a, [btl_k]
            inc a
            cp 4
            jr nz, .l
            ld hl, W7 + $7D27               ; A697
            ld b, $40
            ld a, $FF
.f:         ld [hl+], a
            dec b
            jr nz, .f
            ld hl, W7 + $7D27
            ld b, 8
.g:         ld [hl], $AA
            ld a, l
            add a, 8
            ld l, a
            ld [hl], $FA
            ld a, l
            sub 7
            ld l, a
            dec b
            jr nz, .g
            call pos_ptr
            ld c, 0
.s:         push hl
            call bd_rd
            cp $FF
            jr z, .end
            ld [BZ + $8C], a
            call bd_rd
            ld [BZ + $8E], a
            call bd_rd
            ld [BZ + $90], a
            ld a, c
            add a, low(W7 + $7DA7)
            ld l, a
            ld h, high(W7 + $7DA7)
            ld a, [hl]
            cp $FF
            jr z, .n
            add a, a                        ; A6F0: $1A = type * 4, $1B = $1D = 0
            add a, a
            ld [BZ + $1A], a
            xor a
            ld [BZ + $1B], a
            ld [BZ + $1D], a
            push bc
            call mon_attr1
            pop bc
.n:         pop hl
            inc hl
            inc hl
            inc hl
            inc c
            ld a, c
            cp 8
            jr nz, .s
            ret
.end:       pop hl
            ret
mattr_base: dw $8F20, $8F20, $8F48, $8F48, $8FA8, $8FB4   ; (2F/A8D8)
mattr_mul:  db 1, 1, 2, 2, 3, 3                           ; (2F/A8E4)
; 2F/A78D: the monster's 2 x 2 blocks, each its next attribute bit (A6FB) -> palette 0 / 1
mon_attr1:  ld a, [BZ + $90]
            add a, a
            add a, low(TB_SIZE)
            ld l, a
            ld h, high(TB_SIZE)
            call bd_rd
            ld [BZ + $1E], a
            call bd_rd
            ld [BZ + $1F], a
.r:         ld c, 0                         ; (X: column 0, 2, ..)
.c:         call mon_bit                    ; -> A palette
            ld [BZ + $82], a
            ld a, [BZ + $8C]
            add a, c
            ld [BZ + $7E], a
            ld a, [BZ + $8E]
            ld [BZ + $80], a
            push bc
            call attr_set
            pop bc
            inc c
            inc c
            ld a, [BZ + $1E]
            cp c
            jr nz, .c
            ld hl, BZ + $8E
            inc [hl]
            inc [hl]
            ld hl, BZ + $1F
            dec [hl]
            dec [hl]
            jr nz, .r
            ret
; 2F/A6FB: the next bit of the type's attribute data ($7D17 + $1A, bit position $1B)
mon_bit:    ld a, [BZ + $1A]
            add a, low(W7 + $7D17)
            ld l, a
            ld h, high(W7 + $7D17)
            ld a, [hl]
            ld b, a
            ld a, [BZ + $1B]
            inc a
            ld e, a
            ld a, [BZ + $7E]
            ld d, a
.sh:        sla b
            rl d
            dec e
            jr nz, .sh
            ld a, d
            ld [BZ + $7E], a
            ld a, [BZ + $1B]
            inc a
            ld [BZ + $7F], a
            and 7
            ld [BZ + $1B], a
            ld a, [BZ + $7F]
            and 8
            rrca
            rrca
            rrca
            ld b, a
            ld a, [BZ + $1A]
            add a, b
            ld [BZ + $1A], a
            ld a, d
            and 1
            ld [BZ + $1D], a
            ret
; 2F/A7D4: palette $82 for the 2 x 2 block at column $7E, row $80 in $7D27
attr_set:   ld a, [BZ + $7E]
            srl a
            srl a
            ld b, a
            ld a, [BZ + $80]
            and $FC
            add a, a
            add a, b
            ld [BZ + $84], a
            ld a, [BZ + $7E]
            and 2
            ld b, a
            ld a, [BZ + $80]
            and 2
            add a, a
            add a, b
            srl a
            ld [BZ + $86], a                ; quadrant 0-3
            ld c, a
            ld a, [BZ + $82]
            and 3
            ld b, a
            ld a, c
            and a
            jr z, .s0
.sh:        sla b
            sla b
            dec c
            jr nz, .sh
.s0:        ld a, [BZ + $86]
            ld e, a
            ld d, 0
            ld hl, attr_mask
            add hl, de
            ld c, [hl]
            ld a, [BZ + $84]
            add a, low(W7 + $7D27)
            ld l, a
            ld h, high(W7 + $7D27)
            ld a, [hl]
            and c
            or b
            ld [hl], a
            ret
attr_mask:  db $FC, $F3, $CF, $3F

; ---- the GB screen: VRAM tiles cleared (tile 0 = blank), BG map rows 0-13 from $7900 with the
; CGB palettes from $7D27, BG palettes 0-3 / OBJ 0-3 from $7CF7, the view from NES (20, 48)
btl_screen: xor a                           ; (LCD off) VRAM bank 0 tile 0 blank
            ldh [rVBK], a
            ld hl, $8000
            ld de, 16
            call memclr
            ld hl, $9800                    ; BG map: 32 x 32 tile 0, attributes 0
            ld de, $400
            call memclr
            ld a, 1
            ldh [rVBK], a
            ld hl, $9800
            ld de, $400
            call memclr
            xor a
            ldh [rVBK], a
            ld hl, W7 + $7900               ; tiles
            ld de, $9800
            ld bc, 32 * BT_ROWS
            call memcpy
            ld a, 1                         ; palettes: $7D27 quadrant of NES row r + 5, col c
            ldh [rVBK], a
            ld de, $9800
            ld b, 0                         ; row
.r:         ld c, 0
.c:         ld a, b
            add a, 5
            ld [BZ + $80], a
            push bc
            push de
            call attr_get
            pop de
            pop bc
            ld [de], a
            inc de
            inc c
            ld a, c
            cp 32
            jr nz, .c
            inc b
            ld a, b
            cp BT_ROWS
            jr nz, .r
            xor a
            ldh [rVBK], a
            ld hl, W7 + $7CF7               ; palettes
            ld de, pal_sh
            call pal8
            ld hl, W7 + $7CF7 + 16
            ld de, pal_sh + 64
            call pal8
            ld a, 1
            ldh [pal_dirty], a
            ld a, 20                        ; the view: NES (20, 48) = tilemap row 1
            ldh [scx], a
            ldh [rSCX], a
            ld a, 8
            ldh [scy], a
            ldh [rSCY], a
            ret
; the palette (0-3) of NES row BZ+$80, column C in $7D27
attr_get:   ld a, c
            srl a
            srl a
            ld b, a
            ld a, [BZ + $80]
            and $FC
            add a, a
            add a, b
            add a, low(W7 + $7D27)
            ld l, a
            ld h, high(W7 + $7D27)
            ld a, [hl]
            ld b, a
            ld a, [BZ + $80]
            and 2
            add a, a
            ld e, a
            ld a, c
            and 2
            or e                            ; shift 0 / 2 / 4 / 6
            jr z, .s
.sh:        srl b
            dec a
            jr nz, .sh
.s:         ld a, b
            and 3
            ret
; 16 NES colours at HL -> 4 CGB palettes at DE
pal8:       ld b, 16
.l:         push bc
            push de
            call nes_col
            ld c, a
            ld a, d
            pop de
            push af
            ld a, c
            ld [de], a
            inc de
            pop af
            ld [de], a
            inc de
            pop bc
            dec b
            jr nz, .l
            ret

; FFA26's end: the fade (for now the screen off) and the field's WRAM bank
btl_end:    call wait_vbl
            call lcd_off
            xor a
            ld [lcd_is], a
            ldh [scx], a
            ldh [scy], a
            ld a, 1
            ldh [rSVBK], a
            ret
