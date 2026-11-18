; NES APU -> DMG sound: bank-0 entry points. The work is done in bank RT_TABLES (apu_core.s,
; next to its tables): rt_apu_w for every write to $4000-$4017 (L = register $00-$17,
; A = value; keeps A, F, BC, DE), apu_tick once per NES frame (length counters, sweep,
; linear counter: the NES frame counter's half-frame clocks), apu_init at boot.
; NES pulse 1 -> CH1, pulse 2 -> CH2, triangle -> CH3 (triangle wave), noise -> CH4.

APU_SH     = $D840          ; shadow of $4000-$4017
APU_FH     = $D858          ; NRx4 frequency high bits of the two pulses (2)
APU_LEN    = $D860          ; NES length counters: pulse 1, pulse 2, triangle, noise
APU_ON     = $D864          ; channel sounding (cleared by the length counter, the sweep's
                            ;   mute conditions, the linear counter, $4015)
APU_CV     = $D868          ; GB volume now set (constant volume), $FF = envelope mode
APU_SWD    = $D86C          ; sweep dividers (2)
APU_SWR    = $D86E          ; sweep reload flags (2)
APU_TLIN   = $D870          ; triangle linear counter (frames left; control flag clear)
APU_SWT    = $D871          ; sweep register being clocked (scratch)
; Volume changes don't restart the note: NRx2 "zombie mode" (each $08 written while the
; channel plays in add mode with envelope period 0 raises its volume by one, mod 16).

apu_init:   ld a, RT_TABLES
            ld [$2000], a
            call apu_init_b
            ldh a, [code_bank]
            ld [$2000], a
            ret

rt_apu_w:   push af
            push bc
            push de
            push hl
            ld e, a
            ld a, RT_TABLES
            ld [$2000], a
            call apu_write
            ldh a, [code_bank]
            ld [$2000], a
            pop hl
            pop de
            pop bc
            pop af
            ret

apu_tick:   push af
            push bc
            push de
            push hl
            ld a, RT_TABLES
            ld [$2000], a
            call apu_frame
            ldh a, [code_bank]
            ld [$2000], a
            pop hl
            pop de
            pop bc
            pop af
            ret
