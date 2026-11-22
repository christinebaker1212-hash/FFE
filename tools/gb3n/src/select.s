; ---- the walking character and the Select button (owner, 2026-11-19: Select on the field opens
; OPTIONS / SUSPEND; B + Select changes the walking member, the Famicom's Select: fix:F72C)

; the showing character ($600E: fix:DD2D): graphics job (toad $16, mini $17) -> VRAM bank 1
char_gfx:   ld a, [GS + $0E]
            ld l, a
            ld h, high(GS + $100)
            inc l
            inc l
            ld a, [hl]                      ; status
            dec l
            dec l
            ld b, $16
            bit 5, a
            jr nz, .g
            inc b
            bit 3, a
            jr nz, .g
            ld a, [hl]
            and $3F
            ld b, a
.g:         ld a, b
            add a, $40
            ld h, a
            ld l, 0
            ld a, SPR_BANK
            ld [MBC5_BANKL], a
            ld de, $8000
            ld b, 16
            ld a, 1
            call vcopy
            jp rbank

; its colours (3A/9050: toad $16, an Onion Knight in slot n > 0: $16 + n, else the job; 00/9690
; + 4 i) -> OBJ palettes 0 / 1 colours 2-3 in the shadow (shown with the next upload)
char_pal:   ld a, [GS + $0E]
            ld l, a
            ld h, high(GS + $100)
            inc l
            inc l
            ld a, [hl]
            dec l
            dec l
            ld b, $16
            bit 5, a
            jr nz, .p
            ld a, [hl]
            ld b, a
            and a
            jr nz, .p
            ld a, [GS + $0E]
            rlca
            rlca
            and 3
            ld b, a
            jr z, .p
            add a, $16
            ld b, a
.p:         ld a, b
            and $3F
            add a, a
            add a, a
            ld l, a
            ld h, $58
            ld a, GAME_BANK
            ld [MBC5_BANKL], a
            ld de, pal_sh + 64 + 4
            call .two
            ld de, pal_sh + 64 + 12
            call .two
            jp rbank
.two:       call .one
.one:       push de
            call nes_col                    ; ([HL++] -> A, D)
            ld b, d
            pop de
            ld [de], a
            inc de
            ld a, b
            ld [de], a
            inc de
            ret

; B + Select (fix:F72C): the next member not dead / stone walks
next_char:  ld a, [GS + $0E]
.n:         add a, $40
            ld l, a
            inc l
            inc l
            ld h, high(GS + $100)
            ld b, a
            ld a, [hl]
            and $C0
            ld a, b
            jr nz, .n
            ld [GS + $0E], a
            call char_gfx
            call char_pal
            ld a, 1
            ldh [pal_dirty], a
            ret

