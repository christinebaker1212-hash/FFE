; FF3 core rewrite (docs/ff3-gb-rewrite.md): boot, interrupts, the NES-RAM bank and the helpers FF3's
; translated routines share. RAM map: NES $0000-$00FF -> BZ ($C400), $0200-$07FF -> $C600,
; $6000-$63FF -> $D000, $7000-$73FF -> $C000, $7400-$7FFF -> $D400 (work RAM bank 1, always mapped).
; Registers in translations: 6502 A -> A, X -> E, Y -> C, the 6502 carry -> the carry flag.

BZ         = $C400          ; FF3's zero page
NR2        = $C600 - $0200  ; NES $0200-$07FF: NR2 + address
T_MBOX     = $CC00          ; test builds: cmd, A, X, Y, P in, A, X, Y, P out

section bank 0, $0000
            ret
section bank 0, $0040
            jp vblank
section bank 0, $0048
            reti
section bank 0, $0100
            nop
            jp boot

section bank 0, $0150
boot:       di
            ld sp, $D000
            ld a, 1                         ; work RAM bank 1: NES $6000-$63FF / $7400-$7FFF
            ldh [rSVBK], a
            ld hl, $C000                    ; work RAM cleared (bank 0 and bank 1)
.c0:        xor a
            ld [hl+], a
            ld a, h
            cp $E0
            jr nz, .c0
            ld a, 1
            ldh [rIE], a
            xor a
            ldh [rIF], a
            ld a, CORE_TEST
            and a
            jp nz, t_loop
.idle:      halt
            jr .idle

vblank:     reti

; ---- test builds: tools/gb3n/test/fdiff.py writes NES RAM through the shell, a routine number in
; T_MBOX and the registers; the routine runs, its registers come back, the number goes to 0
t_loop:     ld hl, T_MBOX
            ld a, [hl]
            and a
            jr z, t_loop
            dec a
            add a
            ld e, a
            ld d, 0
            ld hl, t_table
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            push hl
            ld a, [T_MBOX + 3]              ; Y
            ld c, a
            ld a, [T_MBOX + 2]              ; X
            ld e, a
            ld a, [T_MBOX + 4]              ; P: the carry
            rra
            ld a, [T_MBOX + 1]
            pop hl
            call .go
            push af
            ld [T_MBOX + 5], a
            ld a, e
            ld [T_MBOX + 6], a
            ld a, c
            ld [T_MBOX + 7], a
            pop af
            ld a, 0
            rla
            ld [T_MBOX + 8], a
            xor a
            ld [T_MBOX], a
            jr t_loop
.go:        jp hl
