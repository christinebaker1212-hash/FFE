; ---- menu primitives that bank-0 code uses (the text decoder's canvas target, the V-Blank copy)
m_put:      push af
            ld a, [m_tattr]
            ld [m_attr], a
            pop af

m_put2:     push hl
            push af
            ld a, c
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld a, l
            add a, b
            ld l, a
            ld a, h
            add a, high(MC_MAP)
            ld h, a
            pop af
            ld [hl], a
            push af                         ; (A kept)
            ld a, h
            add a, high(MC_ATTR - MC_MAP)
            ld h, a
            ld a, [m_attr]
            ld [hl], a
            pop af
            pop hl
            ret

; E codes from HL ($FF ends early? no: $FF is a blank) at column B, row C

menu_vbl:   ld a, [m_dirty]
            and a
            ret z
            ld a, high(MC_MAP)
            ldh [rHDMA1], a
            xor a
            ldh [rHDMA2], a
            ld a, $9C
            ldh [rHDMA3], a
            xor a
            ldh [rHDMA4], a
            ld a, 36 - 1
            ldh [rHDMA5], a
            ld a, 1
            ldh [rVBK], a
            ld a, high(MC_ATTR)
            ldh [rHDMA1], a
            xor a
            ldh [rHDMA2], a
            ld a, $9C
            ldh [rHDMA3], a
            xor a
            ldh [rHDMA4], a
            ld a, 36 - 1
            ldh [rHDMA5], a
            xor a
            ldh [rVBK], a
            ld [m_dirty], a
            ret


cur_hide:   ld hl, oam_buf + 4 * 36
            ld b, 4
            jr oam_hide.l0

oam_hide:   ld hl, oam_buf
            ld b, 40
.l0:        xor a
.l:         ld [hl+], a
            inc l
            inc l
            inc l
            dec b
            jr nz, .l
            ret

; ---- the main menu canvas (N5B / N6)


; the field font for windows over the field (world maps: their tiles $70-$FF are map tiles):
; normal maps: bank 0 (the map's set has it), m_tattr = PAL_TXT; world maps: a copy in VRAM bank 1
; $70-$FF (no npcs there), m_tattr = PAL_TXT | 8
font_box:   ld a, PAL_TXT
            ld [m_tattr], a
            ldh a, [is_world]
            and a
            ret z
            ld a, PAL_TXT | 8
            ld [m_tattr], a
            ld a, 1
            jr font_ld
; full-screen menus: the font into bank 0 $70-$FF while they cover the screen (world maps)
font_menu:  ld a, PAL_TXT
            ld [m_tattr], a
            ldh a, [is_world]
            and a
            ret z
            xor a
font_ld:    ld [fnt_vb], a
            ld a, MENU_BANK
            ld [vc_src], a
            ld hl, $6400
            ld de, $8700
            ld b, 72
            ld a, [fnt_vb]
            call vcopyx
            ld hl, $6400 + 72 * 16
            ld de, $8700 + 72 * 16
            ld b, 72
            ld a, [fnt_vb]
            jp vcopyx
; and the world map's tiles back after a full-screen menu
font_back:  ldh a, [is_world]
            and a
            ret z
            ld a, [M_ENT + 2]
            ld [vc_src], a
            ld a, [M_ENT + 3]
            add a, 7
            ld h, a
            ld l, 0
            ld de, $8700
            ld b, 72
            xor a
            call vcopyx
            ld a, [M_ENT + 3]
            add a, 7
            ld h, a
            ld l, 72 * 16 % 256
            ld a, h
            add a, 72 * 16 / 256
            ld h, a
            ld de, $8700 + 72 * 16
            ld b, 72
            xor a
            jp vcopyx
; the hand's tiles -> VRAM bank 1 $8100 (tiles $10-$13)
hand_ld:    ld a, MENU_BANK
            ld [vc_src], a
            ld hl, $6E00
            ld de, $8100
            ld b, 4
            ld a, 1
            jp vcopyx

; the menu palettes (fix:E1BC, CODE1 MD_PALS) -> CGB palettes 4-7 (BG and OBJ)
menu_pals:  ld hl, MD_PALS
            ld de, pal_sh + 32
            ld bc, 32
            ld a, CODE1
            call rd_copy
            ld hl, MD_PALS + 32
            ld de, pal_sh + 96
            ld bc, 32
            ld a, CODE1
            call rd_copy
            ld a, 1
            ldh [pal_dirty], a
            ret
