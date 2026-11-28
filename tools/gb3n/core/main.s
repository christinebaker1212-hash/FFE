; FF3 core rewrite (docs/ff3-gb-rewrite.md): boot, interrupts, the NES-RAM bank and the helpers FF3's
; translated routines share. RAM map: NES $0000-$00FF -> BZ ($C400), $0200-$07FF -> $C600,
; $6000-$63FF -> $D000, $7000-$73FF -> $C000, $7400-$7FFF -> $D400 (work RAM bank 1, always mapped).
; Registers in translations: 6502 A -> A, X -> E, Y -> C, the 6502 carry -> the carry flag.

BZ         = $C400          ; FF3's zero page
NR2        = $C600 - $0200  ; NES $0200-$07FF: NR2 + address
T_MBOX     = $CC00          ; test builds: cmd, A, X, Y, P in, A, X, Y, P out, (2 temp), NES banks $8000 / $A000

section hram, $FF80
rombank:    ds 1                            ; our code bank mapped at $4000
nb8:        ds 1                            ; FF3's NES bank at $8000 / $A000 (its mapper state)
nbA:        ds 1
xa:         ds 1
vbl_done:   ds 1

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

vblank:     push af
            ld a, 1
            ldh [vbl_done], a
            pop af
            reti

; ---- wait for the next V-Blank (the check and the halt with interrupts off: no lost frame)
wait_vbl:   xor a
            ldh [vbl_done], a
.w:         di
            ldh a, [vbl_done]
            and a
            jr nz, .d
            ei
            halt
            jr .w
.d:         ei
            ret

; ---- far call (%X label in the sources): `call xcall` with the target's address and GB bank
; inline after it. A, C, E and the flags go in and come back as the callee leaves them (FF3's
; A / X / Y / P); B, D, H, L are scratch. The caller's code bank is mapped again on return.
xcall:      ldh [xa], a
            pop hl                          ; (no flag changes from here to the call)
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld d, a
            ld a, [hl+]
            push hl                         ; (the return: past the inline bytes)
            ld h, a
            ldh a, [rombank]
            push af
            ld a, h
            ldh [rombank], a
            ld [MBC5_BANKL], a
            ld h, d
            ld l, b
            ldh a, [xa]
            call .go
            ldh [xa], a
            pop hl                          ; (H = the caller's bank; the callee's flags stay)
            ld a, h
            ldh [rombank], a
            ld [MBC5_BANKL], a
            ldh a, [xa]
            ret
.go:        jp hl

; ---- FF3's memory through a NES address. n_rd: A = [NES HL]; n_wr: [NES HL] = A. The carry and
; C / E are kept (n_rd: Z / N not set: translations add `inc a / dec a` where FF3 tests them);
; B, D, H, L scratch. RAM: the map above; ROM: the NES bank FF3 has mapped at that window ($8000:
; nb8, $A000: nbA, $C000 / $E000: the English build's fixed banks 126 / 127), read from GB bank
; NES_BASE + bank / 2.
n_rd:       bit 7, h                        ; (BIT: the carry kept)
            jr nz, .rom
            call n_ram
            ld a, [hl]
            ret
.rom:       push af                         ; (the carry)
            ld a, h
            cp $A0
            ldh a, [nb8]
            jr c, .b
            ld a, h
            cp $C0
            ldh a, [nbA]
            jr c, .b
            ld a, h
            cp $E0
            ld a, 126
            jr c, .b
            ld a, 127
.b:         ld b, a                         ; B = NES bank
            rra                             ; GB bank NES_BASE + bank / 2
            and $7F
            add NES_BASE
            ld d, a
            ld a, h                         ; address $4000 + $2000 (bank & 1) + (a & $1FFF)
            and $1F
            bit 0, b
            jr z, .lo
            or $20
.lo:        or $40
            ld h, a
            ld a, d
            ld [MBC5_BANKL], a
            ld d, [hl]
            ldh a, [rombank]
            ld [MBC5_BANKL], a
            pop af
            ld a, d
            ret
n_wr:       bit 7, h                        ; (writes to $8000+: the mapper's; FF3's code uses
            ret nz                          ;   its bank routines, translated separately)
            call n_ram
            ld [hl], a
            ret
; HL: NES RAM address -> GB address (A and the flags kept)
n_ram:      push af
            ld a, h
            cp $08
            jr nc, .hi
            add $C4                         ; $0000-$07FF: + $C400
            ld h, a
            pop af
            ret
.hi:        cp $70
            jr nc, .s7
            add $70                         ; $6000-$6FFF: + $7000 ($6400-$6FFF: cart RAM,
            ld h, a                         ;   reached through FF3's save routines only)
            pop af
            ret
.s7:        cp $74
            jr nc, .s74
            add $50                         ; $7000-$73FF -> $C000-$C3FF
            ld h, a
            pop af
            ret
.s74:       add $60                         ; $7400-$7FFF -> $D400-$DFFF
            ld h, a
            pop af
            ret

; ---- test builds: tools/gb3n/test/fdiff.py writes NES RAM through the shell, the registers and FF3's
; banks at $8000 / $A000 into T_MBOX, then a routine number; the routine runs in its GB bank, its
; registers come back, the number goes to 0
t_loop:     ld hl, T_MBOX
            ld a, [hl]
            and a
            jr z, t_loop
            dec a                           ; t_table: 3 bytes a routine (address, GB bank)
            ld e, a
            add a
            add e
            ld e, a
            ld d, 0
            ld hl, t_table
            add hl, de
            ld a, [hl+]
            ld [T_MBOX + 9], a
            ld a, [hl+]
            ld [T_MBOX + 10], a
            ld a, [hl]
            ldh [rombank], a
            ld [MBC5_BANKL], a
            ld a, [T_MBOX + 11]
            ldh [nb8], a
            ld a, [T_MBOX + 12]
            ldh [nbA], a
            ld a, [T_MBOX + 3]              ; Y
            ld c, a
            ld a, [T_MBOX + 2]              ; X
            ld e, a
            ld a, [T_MBOX + 9]
            ld l, a
            ld a, [T_MBOX + 10]
            ld h, a
            ld a, [T_MBOX + 4]              ; P: the carry
            rra
            ld a, [T_MBOX + 1]
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

; ---- n_rdx: A = [NES HL + X]; n_rdy: A = [NES HL + Y] (the carry, C and E kept; B, D, H, L scratch)
section bank 0, $0E00
n_rdx:      push af
            ld a, l
            add e
            ld l, a
            jr nc, .n
            inc h
.n:         pop af
            jp n_rd
n_rdy:      push af
            ld a, l
            add c
            ld l, a
            jr nc, .n
            inc h
.n:         pop af
            jp n_rd
