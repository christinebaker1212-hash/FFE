; FF2 runtime, bank 0 at $39E0 (after the stubs; EMPH_RGB + 0 * $80 is unused): CGB palettes
section bank 0, $39E0
cgb_palettes:                               ; NES palette RAM -> CGB BG / OBJ palettes 0-3
            push de                         ;   (RGB555 from NES_RGB, $3E00, or EMPH_RGB with
            ldh a, [ppu_mask]               ;   the NES emphasis bits; colour 0 of each palette
            and $E0                         ;   is the universal backdrop). Only the entries
            or 1                            ;   rt_ppu_w7 marked in PAL_DM are written (new
            ld hl, PAL_LEM                  ;   emphasis bits: all): FF2's world-map overview
            cp [hl]                         ;   changes one colour a frame, and writing all 32
            jr z, .same                     ;   took most of the vblank, so the tile copies by
            ld [hl], a                      ;   HDMA never got their turn
            ld a, $FF
            ld hl, PAL_DM
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl], a
.same:      ld a, [PAL_LEM]
            and $E0
            jr nz, .em
            ld de, NES_RGB
            jr .go
.em:        ld e, a                         ; DE = EMPH_RGB + (A >> 5) * $80
            rlca
            rlca
            and 3
            add a, high(EMPH_RGB)
            ld d, a
            ld a, e
            add a, a
            add a, a
            ld e, a
.go:        ld b, 0                         ; B = entry
.lg:        ld a, b                         ; C = this group's 8 marks (cleared)
            rrca
            rrca
            rrca
            and 3
            add a, low(PAL_DM)
            ld l, a
            ld h, high(PAL_DM)
            ld c, [hl]
            ld [hl], 0
            ld a, c
            and a
            jr nz, .le
            ld a, b
            add a, 8
            ld b, a
            cp 32
            jr nz, .lg
            jr .end
.le:        srl c
            jr nc, .ln
            ld h, high(PAL_SH)
            ld l, b
            ld a, b
            and 3
            ld a, [hl]
            jr nz, .c
            ld a, [PAL_SH]
.c:         and $3F
            add a, a
            add a, e
            ld l, a
            ld h, d                         ; HL = its RGB555
            push bc
            ld c, $68                       ; BG: $FF68 / $FF69, OBJ: $FF6A / $FF6B
            ld a, b
            cp 16
            jr c, .bg
            sub 16
            ld c, $6A
.bg:        add a, a
            or $80                          ; (index, auto-increment)
            ldh [c], a
            inc c
            ld a, [hl+]
            ldh [c], a
            ld a, [hl]
            ldh [c], a
            pop bc
.ln:        inc b
            ld a, b
            and 7
            jr nz, .le
            ld a, b
            cp 32
            jr nz, .lg
.end:       pop de
            ret

; fix:C46E "clear OAM data" (every frame; ~7% of the DMG field time translated): $0200-$02FF
; = $F0, $26 = 0. Exit as the NES: A = 0, X = $FF, N = 0, Z = 1, carry kept.
hle_oamclr: ld hl, NES_RAM + $200
            ld a, $F0
.l:         ld [hl], a
            inc l
            jr nz, .l                       ; (leaves Z = 1, carry untouched)
            ld a, l
            ld [NES_RAM + $26], a
            ldh [nzv], a
            ld e, $FF
            ret
