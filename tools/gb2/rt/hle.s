; Trampolines into the native routines in bank HLE_BANK (rt/native.s). The FF1-specific
; native replacements of the FF1 copy are not used by FF2; FF2's own go in rt/ff2.s.
hle_back:   push af
            ldh a, [code_bank]
            ld [$2000], a
            pop af
            ret

fresh_tramp:                                ; frame wait, DMG: fresh_scan (bank HLE_BANK)
            ld a, HLE_BANK
            ld [$2000], a
            call fresh_scan
            ldh a, [code_bank]
            ld [$2000], a
            ret
