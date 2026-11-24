; FF1 native engine: the Color's LCD colour correction (owner, 2026-11-24: Options LCD: Default,
; GBC Corrected, GBA Corrected; a Game Boy Color's screen shows the NES colours less vividly).
; Applied where a screen's own colours are written (maps, battles, windows, sprites, the
; gradient's ramp); fades and masked loads work from the palettes read back, already corrected.
; Per colour: each channel through the mode's curve (cc_lut, build.py), then the saturation
; raised (GBC: by half the distance from the grey of the three channels, GBA: by a quarter).
section bank 0, $2E80
; B bytes of colours at HL -> HL = the corrected copy (cc_buf); Default: HL as it was
cc_copy:    ld a, [opt_ccm]
            and a
            ret z
            push bc
            push de
            ld de, cc_buf
            srl b
.c:         push bc
            ld a, [hl+]
            ld c, a
            ld a, [hl+]
            push hl
            push de
            ld d, a
            ld e, c
            call cc_fix
            ld b, d
            ld c, e
            pop de
            ld a, c
            ld [de], a
            inc de
            ld a, b
            ld [de], a
            inc de
            pop hl
            pop bc
            dec b
            jr nz, .c
            ld hl, cc_buf
            pop de
            pop bc
            ret
; B bytes of colours at HL corrected in place
cc_inpl:    ld a, [opt_ccm]
            and a
            ret z
            push hl
            push bc
            call cc_copy
            pop bc
            pop de
            push de
            push bc
.l:         ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .l
            pop bc
            pop hl
            ret
; DE = an RGB555 colour, corrected for the mode (opt_ccm 1 / 2)
cc_fix:     ld a, [opt_ccm]
            and a
            ret z
            push hl
            push bc
            dec a
            swap a
            add a, a                        ; 32 (mode - 1)
            add a, low(cc_lut)
            ld c, a                         ; C = the curve's low byte
            ld a, e                         ; red
            and 31
            call .lut
            ld [cc_rgb], a
            ld a, d                         ; green: E bits 5-7, D bits 0-1
            and 3
            ld b, a
            ld a, e
            swap a
            rrca
            and 7
            ld e, a
            ld a, b
            add a, a
            add a, a
            add a, a
            or e
            call .lut
            ld [cc_rgb + 1], a
            ld a, d                         ; blue
            rrca
            rrca
            and 31
            call .lut
            ld [cc_rgb + 2], a
            ld hl, cc_rgb                   ; the grey: (r + g + b) / 3
            ld a, [hl+]
            add a, [hl]
            inc hl
            add a, [hl]
            ld b, 0
.d3:        sub 3
            jr c, .dx
            inc b
            jr .d3
.dx:        ld hl, cc_rgb                   ; each channel: c + (c - grey) / 2 (GBC) or / 4
            ld e, 3
.s:         ld a, [hl]
            sub b                           ; A = c - grey (signed)
            sra a
            ld d, a
            ld a, c
            cp low(cc_lut) + 32
            ld a, d
            jr c, .k
            sra a
.k:         add a, [hl]
            bit 7, a
            jr z, .p
            xor a
.p:         cp 32
            jr c, .w
            ld a, 31
.w:         ld [hl+], a
            dec e
            jr nz, .s
            ld a, [cc_rgb + 1]              ; packed again
            ld b, a
            swap a
            add a, a
            and $E0
            ld e, a
            ld a, [cc_rgb]
            or e
            ld e, a
            ld a, b
            rrca
            rrca
            rrca
            and 3
            ld d, a
            ld a, [cc_rgb + 2]
            add a, a
            add a, a
            or d
            ld d, a
            pop bc
            pop hl
            ret
.lut:       add a, c                        ; A = cc_lut[mode][A]
            ld l, a
            ld h, high(cc_lut)
            ld a, [hl]
            ret

section wram, $DBBC
cc_rgb:     ds 3
            ds 1
cc_buf:     ds 64                           ; a corrected palette (cc_copy)
