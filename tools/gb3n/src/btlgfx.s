; ---- battle graphics (FF3 banks $2E / $2F) on the GB: the monsters' graphics, FF3's monster
; tilemap ($7900, 32 x 14 = NES rows 5-18) and attribute table ($7D27), the battle palettes
; ($7CF7), shown on the GB as BG map rows 0-13 (tiles and palettes from VRAM bank 0, the CGB
; attributes from FF3's attribute table), the view from NES (20, 48) (the approved layout: the
; battlefield in the top 96 lines, the windows below). Bosses and back attacks: later.

; 2F/A14A init monster / bg graphics + 2E/9D88 palettes + 2E/9E64 characters
bg_init:    call chr_init
            call pal_init
            call chr_palid
            call chr_gfx
            call chr_pos
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
mon_gfx:    ld hl, W7 + $7300               ; (the monster tiles $70-$FF cleared first: a 4 x 4
            ld de, $100                     ;   monster sits at the bottom of its 4 x 6 slot, as
            call memclr                     ;   FF3's blank pattern table leaves its top rows;
            ld de, $8700                    ;   the field's font was there)
.c:         push de
            ld hl, W7 + $7300
            ld b, 16
            xor a
            call vcopyx
            pop de
            inc d
            ld a, d
            cp $90
            jr nz, .c
            xor a
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
            jr nz, .g
            ld a, [btl_k]                   ; (2F/A3AB: a boss tilemap: slot 0's graphics)
            and a
            call z, boss_gfx
            jr .n
.g:         call mon_gfx1
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

; 2F/A247 update monster positions: each slot's rectangle of tile ids in the tilemap (a boss
; tilemap: 2F/A21E, 12 rows of 18 from 2A/8000 + 216 id at $7922)
mon_pos:    ld a, [W7 + $7D7B]
            cp 9
            jr nz, .np
            ld a, [W7 + $7DA7]
            cp $FF
            ret z
            ld a, [W7 + $7D73]
            and $1F
            ld e, a
            ld d, 216
            call bmul8x                     ; HL = 216 id
            ld de, BD3_BTMAP
            add hl, de
            ld de, W7 + $7922
            ld c, 12
.br:        push bc
            push de
            ld bc, 18
            ld a, BDATA3_BANK
            call rd_copy
            pop de
            ld a, e
            add a, 32
            ld e, a
            jr nc, .bn
            inc d
.bn:        pop bc
            dec c
            jr nz, .br
            jp mon_mirror
.np:        call pos_ptr
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
            jr mon_mirror
.end:       pop hl
            ; (fall through)
; 2F/A29C: a back attack mirrors the tilemap's 14 rows
mon_mirror: call back_atk
            ret nz
            ld hl, W7 + $7900
            ld c, 14
.r:         ld d, h
            ld e, l
            push hl
            ld a, l
            add a, 31
            ld l, a
            ld b, 16
.x:         ld a, [de]
            push af
            ld a, [hl]
            ld [de], a
            pop af
            ld [hl-], a
            inc de
            dec b
            jr nz, .x
            pop hl
            ld a, l
            add a, 32
            ld l, a
            jr nc, .n
            inc h
.n:         dec c
            jr nz, .r
            ret

; Z if a back attack (2F/AF48)
back_atk:   ld a, [W7 + $78C3]
            cp $88
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
mon_attrs:  ld a, [W7 + $7D7B]              ; (2F/A820: a boss: 2E/8FC0 + 7 id, 8 bytes)
            cp 9
            jr nz, .nb
            ld a, [W7 + $7D74]
            and $3F
            ld e, a
            ld d, 7
            call bmul8x
            ld de, $7700                    ; (BDATA: 2E/8FC0)
            add hl, de
            ld de, W7 + $7D17
            ld bc, 8
            ld a, BDATA_BANK
            call rd_copy
            ld a, [W7 + $7D74]
            bit 7, a
            jr z, .ln0
            ld hl, W7 + $7D17
            ld b, 8
.bx:        ld a, [hl]
            cpl
            ld [hl+], a
            dec b
            jr nz, .bx
.ln0:       jp .after
.nb:        xor a
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
            push de
            call bmul8
            pop de
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
.after:     ld hl, W7 + $7D27               ; A697
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
; 2F/A738 the monsters in $7E8F flashed: the normal attributes, then their blocks palette $7E90
mon_flash:  call mon_attrs
            call pos_ptr
            ld a, [W7 + $7E8F]
            ld c, a
            ld b, 8
.m:         sla c
            jr nc, .n
            push bc
            push hl
            call bd_rd
            ld [BZ + $8C], a
            call bd_rd
            ld [BZ + $8E], a
            call bd_rd
            ld [BZ + $90], a
            add a, a
            add a, low(TB_SIZE)
            ld l, a
            ld h, high(TB_SIZE)
            call bd_rd
            ld [BZ + $1E], a
            call bd_rd
            ld [BZ + $1F], a
            ld a, [W7 + $7E90]
            ld [BZ + $82], a
.r:         ld c, 0
.c:         ld a, [BZ + $8C]
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
            pop hl
            pop bc
.n:         inc hl
            inc hl
            inc hl
            dec b
            jr nz, .m
            xor a
            ld [W7 + $7E8E], a
            ret
; 2F/B96F / BABA the monsters drawn again (a split's new one, toad / mini's removed ones): the
; tilemap, the counts, the attributes, to VRAM (FF3 fades a new one in through a second tilemap)
mon_redraw: ld hl, W7 + $7900
            ld de, 32 * BT_ROWS
            call memclr
            call mon_pos
            call mon_count
            call mon_attrs
            call attr_push
            jp map_show
; 2F/AF34 the attribute table to the GB: $7D27 -> the battlefield rows' palettes (VRAM bank 1,
; in a V-Blank: the rows built in W7 + $7300)
attr_push:  ld hl, W7 + $7300
            ld b, 0
.r:         ld c, 0
.c:         ld a, b
            add a, 5
            ld [BZ + $80], a
            push bc
            push hl
            call back_atk
            jr nz, .na
            ld a, 31
            sub c
            ld c, a
            call attr_get
            or $20
            jr .ha
.na:        call attr_get
.ha:        pop hl
            pop bc
            ld [hl+], a
            inc c
            ld a, c
            cp 32
            jr nz, .c
            inc b
            ld a, b
            cp BT_ROWS
            jr nz, .r
            ld a, CODE3
            ld [vc_src], a
            ld hl, W7 + $7300
            ld de, $9800
            ld b, 2 * BT_ROWS
            ld a, 1
            jp vcopyx
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
btl_screen: ld hl, W7 + $7300                ; (the LCD on, behind black: by DMA) zeros
            ld de, $100
            call memclr
            ld a, CODE3
            ld [vc_src], a
            ld hl, W7 + $7300               ; VRAM bank 0 tile 0 blank
            ld de, $8000
            ld b, 1
            xor a
            call vcopyx
            ld de, $9800                    ; BG map: 32 x 32 tile 0, attributes 0
.z:         push de
            ld hl, W7 + $7300
            ld b, 16
            xor a
            call vcopyx
            pop de
            push de
            ld hl, W7 + $7300
            ld b, 16
            ld a, 1
            call vcopyx
            pop de
            ld hl, $100
            add hl, de
            ld d, h
            ld e, l
            ld a, d
            cp $9C
            jr nz, .z
            call map_show                   ; tiles, palettes
            call attr_push
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
            call chr_draw
            call btl_scx                    ; the view: NES (20, 48) = tilemap row 1 (mirrored: 76)
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
btl_end:    call pal_black                  ; (the LCD stays on: the field loads behind black)
            xor a
            ld [menu_on], a                 ; (the battle's window off, as at boot)
            ldh [rWY], a
            ldh [scx], a
            ldh [scy], a
            ld a, 1
            ldh [rSVBK], a
            ret

; ---- the party (2F/AA00 load character graphics, 2F/B4AC positions, 32/90EA draw): FF3's
; positions ($C0 x, $C4 y) and frames ($7D83) kept; on the GB a member's base is mapped onto
; the approved party column: x = 140 + (NES x - 208) / 2, y = 24 member + (NES y - $2C - 4
; member); the six sprites' offsets as FF3's (32/91CB templates, 32/972E tiles); tiles in VRAM
; bank 1 at FF3's indices (tile 1 + 14 member), palettes as FF3's ($7D93 | $7D97).

chr_gfx:    xor a
.m:         ld [btl_k], a
            ld e, a
            ld d, 0
            ld hl, W7 + $7D8B
            add hl, de
            ld a, [hl]
            cp $FF
            jr z, .n
            ld c, a                         ; job (toad $18 / mini $19 from the status)
            ld hl, W7 + $7D9B
            add hl, de
            add hl, de
            ld a, [hl]
            and 5
            jr z, .j
            ld b, 2
            ld c, $18
            and 4
            jr nz, .t
            ld b, 3
            ld c, $19
.t:         ld hl, W7 + $7DA3
            add hl, de
            ld [hl], b
.j:         ld a, c                         ; 2F/AB3D: job * $2A0, toad / mini $3F80 / $3F00
            ld hl, $7F80
            cp $18
            jr z, .p
            ld hl, $7F00
            cp $19
            jr z, .p
            ld l, a
            ld h, 0
            add hl, hl                      ; x $2A0 = x 32 x 21
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld d, h
            ld e, l
            ld b, 20
.x:         add hl, de
            dec b
            jr nz, .x
            ld de, $4000
            add hl, de
.p:         ld a, [btl_k]                   ; -> VRAM bank 1 tile 1 + 14 member
            ld e, a
            add a, a
            add a, a
            add a, a
            sub e
            add a, a
            inc a
            swap a
            ld e, a
            and $F0
            ld c, a
            ld a, e
            and $0F
            add a, $80
            ld d, a
            ld e, c
            ld a, CHGFX_BANK
            ld [vc_src], a
            ld b, 14
            ld a, 1
            call vcopyx
.n:         ld a, [btl_k]
            inc a
            cp 4
            jr nz, .m
            ret

; 2F/B4AC + B48D: start positions and frames (the walk-in: later; members at their row now)
chr_pos:    ld hl, BD_START                 ; (2F/B51A: x 4, y 4; a back attack's 8 on)
            call back_atk
            jr nz, .s0
            ld hl, BD_START + 8
.s0:        ld de, BZ + $C0
            ld bc, 8
            ld a, BDATA_BANK
            call rd_copy
            ld c, 0
.m:         ld b, 0
            ld hl, W7 + $7D8F
            add hl, bc
            ld a, [hl]
            and 1
            ld e, a
            call back_atk                   ; (2F/B516 + 2 in a back attack)
            ld a, e
            jr nz, .r0
            add a, 2
.r0:        add a, low(BD_ROWX)
            ld l, a
            ld h, high(BD_ROWX)
            push bc
            call bd_rd
            pop bc
            ld hl, W7 + $7D7F
            add hl, bc
            ld [hl], a
            ld hl, BZ + $C0
            add hl, bc
            ld [hl], a                      ; (at the row: B48D after the walk-in)
            ld hl, W7 + $7D9B
            add hl, bc
            add hl, bc
            ld a, [hl]
            ld d, 0
            and $C0
            jr nz, .f
            ld a, [hl]
            ld d, $0B
            and 5
            jr nz, .f
            ld d, 2
.f:         ld hl, W7 + $7D83
            add hl, bc
            ld [hl], d
            inc c
            ld a, c
            cp 4
            jr nz, .m
            ret

; 2E/9E01: palette ids by job (2E/9E4A freelancer by member, 2E/9E4E by job) -> $7D93
chr_palid:  ld c, 0
.m:         ld b, 0
            ld hl, W7 + $7D8B
            add hl, bc
            ld a, [hl]
            and a
            jr nz, .j
            ld a, c
            ld hl, chr_pfree
            jr .r
.j:         ld hl, chr_pjob
.r:         ld e, a
            ld d, 0
            add hl, de
            ld a, [hl]
            ld hl, W7 + $7D93
            add hl, bc
            ld [hl], a
            inc c
            ld a, c
            cp 4
            jr nz, .m
            ret
chr_pfree:  db 0, 1, 2, 0                           ; (2E/9E4A)
chr_pjob:   db 0, 0, 1, 0, 1, 0, 2, 0, 2, 0, 1, 1   ; (2E/9E4E)
            db 1, 1, 1, 2, 2, 1, 0, 2, 0, 0

; 32/90EA for each member -> OAM sprites 6 m .. 6 m + 5
chr_draw:   ld c, 0
.m:         push bc
            call chr_draw1
            pop bc
            inc c
            ld a, c
            cp 4
            jr nz, .m
            ret
chr_draw1:  ld b, 0
            ld hl, W7 + $7D83
            add hl, bc
            ld a, [hl]
            ld d, 0
            bit 7, a                        ; (flipped)
            jr z, .nf
            ld d, $15
.nf:        and $7F
            ld [BZ + $90], a
            ld hl, W7 + $7E22               ; (jumping: frame 0)
            add hl, bc
            ld a, [hl]
            and a
            jr nz, .jp
            ld a, [BZ + $90]                ; (frame 0 otherwise, between the step and the
            and a                           ;   swing: the pose kept, no blink)
            ret z
            jr .fr
.jp:        xor a
            ld [BZ + $90], a
.fr:        ld a, [BZ + $90]                ; template: 32/91CB [ 926B / 9280 frame ]
            add a, d
            add a, low(SP_IDX)
            ld l, a
            ld a, high(SP_IDX)
            adc a, 0
            ld h, a
            push bc
            call bd_rd
            add a, a
            add a, low(SP_TMPL)
            ld l, a
            ld a, high(SP_TMPL)
            adc a, 0
            ld h, a
            call bd_rd
            ld e, a
            call bd_rd
            ld d, a
            ld hl, BD_SPR - $9100
            add hl, de
            ld de, btl_spr
            ld bc, 24
            ld a, BDATA_BANK
            call rd_copy
            pop bc
            ld a, c                         ; tile offset, palette
            add a, low(SP_OFS)
            ld l, a
            ld h, high(SP_OFS)
            push bc
            call bd_rd
            pop bc
            ld [BZ + $82], a
            ld b, 0
            ld hl, W7 + $7D93
            add hl, bc
            ld a, [hl]
            ld hl, W7 + $7D97
            add hl, bc
            or [hl]
            ld [BZ + $83], a
            ld hl, BZ + $C0                 ; GB base: x = 140 + (x - 208) / 2 + 8 (a back attack:
            add hl, bc                      ;   from 240 - x, then mirrored on the GB screen)
            call back_atk
            ld a, [hl]
            jr nz, .bx
            ld a, 240
            sub [hl]
.bx:        sub 208
            sra a
            add a, 140 + 8
            ld [BZ + $8C], a
            ld hl, BZ + $C4                 ; y: (y - $2C - 4 m) (FF3's rows 28 px apart -> 24) + 16 + 1
            add hl, bc
            ld a, c
            add a, a
            add a, a
            ld e, a                         ; 4 m
            ld a, [hl]
            sub e
            sub $2C - 17
            ld [BZ + $8E], a
            ld a, [BZ + $90]                ; frame tiles: 32/972E + 6 frame
            ld e, a
            add a, a
            add a, e
            add a, a
            add a, low(SP_FRAME)
            ld l, a
            ld a, high(SP_FRAME)
            adc a, 0
            ld h, a
            push bc
            ld de, btl_tmp2
            ld bc, 6
            ld a, BDATA_BANK
            call rd_copy
            pop bc
            ld a, c                         ; OAM sprites 6 m ..
            add a, a
            add a, c
            add a, a
            add a, a
            add a, a
            ld e, a
            ld d, 0
            ld hl, PARTY_OAM
            add hl, de
            ld de, btl_spr
            ld b, 0                         ; (sprite index)
.s:         push hl
            ld a, [de]                      ; template: y, (tile), attributes, x
            ld hl, BZ + $8E
            add a, [hl]
            ld [btl_oy], a
            inc de
            inc de
            ld a, [de]                      ; attributes: flip (bit 6), palette, VRAM bank 1
            ld hl, BZ + $83
            or [hl]
            ld c, a
            and $40
            rrca                            ; (the NES h-flip, bit 6 -> the GB's bit 5)
            ld l, a
            ld a, c
            and 3
            or 8
            or l
            ld [btl_oa], a
            inc de
            ld a, [de]
            ld hl, BZ + $8C
            add a, [hl]
            ld [btl_ox], a
            call back_atk
            jr nz, .nb
            ld a, [btl_ox]                  ; (mirrored: x = 168 - x, flipped)
            ld l, a
            ld a, 168
            sub l
            ld [btl_ox], a
            ld a, [btl_oa]
            xor $20
            ld [btl_oa], a
.nb:
            inc de
            ld a, b                         ; tile: bit 7 absolute, else + the member's offset
            add a, low(btl_tmp2)
            ld l, a
            ld a, high(btl_tmp2)
            adc a, 0
            ld h, a
            ld a, [hl]
            bit 7, a
            jr z, .ro
            and $7F
            jr nz, .tl
            pop hl                          ; ($80: the NES's blank tile 0, e.g. frame 0: the
            xor a                           ;   cell hidden; the GB's tile 0 is not blank)
            ld [hl+], a
            inc hl
            inc hl
            inc hl
            jr .nx
.ro:        ld hl, BZ + $82
            add a, [hl]
.tl:        pop hl
            ld c, a
            ld a, [btl_oy]
            ld [hl+], a
            ld a, [btl_ox]
            ld [hl+], a
            ld a, c
            ld [hl+], a
            ld a, [btl_oa]
            ld [hl+], a
.nx:        inc b
            ld a, b
            cp 6
            jr nz, .s
            ret

; HL = E x D
bmul8x:     ld hl, 0
            ld a, d
            ld d, 0
.l:         and a
            ret z
            srl a
            jr nc, .s
            add hl, de
.s:         sla e
            rl d
            jr .l

; 2F/A3B8 + A40B: the boss's 144 tiles (2F/9068: bbs---tt tttttttt; b the bank pair, s the
; summon graphics, flipped to face the members) -> VRAM bank 0 tile $70
boss_gfx:   ld a, [W7 + $7D73]
            and $1F
            add a, a
            ld e, a
            ld d, 0
            ld hl, BD3_BPTR
            add hl, de
            ld a, BDATA3_BANK
            call rd_byte
            ld c, a
            ld a, BDATA3_BANK
            call rd_byte
            ld b, a                         ; BC = the word
            ld a, b
            and 3
            ld h, a
            ld l, c
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, $4000
            add hl, de                      ; (the pair's NES $8000 -> GB $4000)
            ld a, b
            bit 5, a
            jr nz, .s
            rlca
            rlca
            and 3
            add a, MGFX_BANK0
            ld [vc_src], a
            ld de, $8700
            ld b, 144
            xor a
            jp vcopyx
.s:         xor a
            ldh [rVBK], a
            ld [btl_tmp + 1], a
            ld a, MGFX_BANK0 + 4            ; (summon graphics: each tile flipped)
            ld [btl_tmp], a
            ld a, low($8700)
            ld [btl_tmp + 2], a
            ld a, high($8700)
            ld [btl_tmp + 3], a
            ld de, $8700
            ld c, 144
.t:         push bc
            push de
            ld de, btl_spr
            ld bc, 16
            ld a, [btl_tmp]
            call rd_copy
            push hl
            ld hl, btl_spr
            ld c, 16
.f:         ld a, [hl]
            ld b, 8
.r:         rra
            rl e
            dec b
            jr nz, .r
            ld [hl], e
            inc hl
            dec c
            jr nz, .f
            pop hl
            pop de
            push hl
            ld hl, btl_spr                  ; (into a chunk of 16 tiles, sent by DMA)
            ld a, [btl_tmp + 1]
            ld e, a
            ld d, 0
            sla e
            rl d
            sla e
            rl d
            sla e
            rl d
            sla e
            rl d
            push hl
            ld hl, W7 + $7300
            add hl, de
            ld d, h
            ld e, l
            pop hl
            ld bc, 16
            call memcpy
            ld hl, btl_tmp + 1
            inc [hl]
            ld a, [hl]
            cp 16
            call z, .snd
            pop hl
            pop bc
            dec c
            jr nz, .t
            ret
.snd:       ld [hl], 0                      ; 16 tiles -> VRAM at btl_tmp + 2 / + 3
            ld a, CODE3
            ld [vc_src], a
            ld a, [btl_tmp + 2]
            ld e, a
            ld a, [btl_tmp + 3]
            ld d, a
            push de
            ld hl, W7 + $7300
            ld b, 16
            xor a
            call vcopyx
            pop hl
            ld de, $100
            add hl, de
            ld a, l
            ld [btl_tmp + 2], a
            ld a, h
            ld [btl_tmp + 3], a
            ret

; the battlefield's SCX: 20 (NES x 20 at the left edge), a back attack's mirror 76
btl_scx:    call back_atk
            ld a, 20
            ret nz
            ld a, 76
            ret
; A - (SCX - 8) / A - SCX - 16 (carry if below 0)
sub_scx8:   push bc
            ld b, a
            call btl_scx
            sub 8
            ld c, a
            ld a, b
            sub c
            pop bc
            ret
sub_scx16:  push bc
            ld b, a
            call btl_scx
            add a, 16
            ld c, a
            ld a, b
            sub c
            pop bc
            ret
