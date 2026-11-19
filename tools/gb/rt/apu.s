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

; The music driver's writes are not sent at once: each NES frame's register values go into a
; snapshot (APQ_P: $4000-$400F; byte 9 = $4015, byte 13 = notes restarted this frame, bits
; 0-3 per channel, bit 4 = $4015 written). At each frame wait it is queued (2 slots) and at
; most one queued frame is applied per GB frame (vblank): game frames run back to back after
; a slow one (pacing catch-up) no longer rush the music; it plays at a steady 60 Hz, at most
; two frames behind. ($4015 is never read back by the game: reads return 0.)
APQ_P      = $DCD0          ; snapshot being written (16)
APQ_S0     = $DCE0          ; queued frames: 2 slots of 16 ($DCE0, $DCF0)

rt_apu_w:   push af
            push bc
            push hl
            ld b, a                         ; B = value
            ld a, l
            cp $10
            jr nc, .hi
            ld c, a
            add a, low(APQ_P)
            ld l, a
            ld h, high(APQ_P)
            ld [hl], b
            ld a, c                         ; $4003 / $4007 / $400B / $400F: a note restarts
            and 3
            cp 3
            jr nz, .x
            ld a, c
            rrca
            rrca
            and 3
            ld c, a
            ld a, 1
            inc c
.sh:        dec c
            jr z, .st
            add a, a
            jr .sh
.st:        ld hl, APQ_P + 13
            or [hl]
            ld [hl], a
            jr .x
.hi:        cp $15
            jr nz, .x                       ; ($4010-$4013 DMC, $4017: not played)
            ld a, b
            ld [APQ_P + 9], a
            ld hl, APQ_P + 13
            set 4, [hl]
.x:         pop hl
            pop bc
            pop af
            ret

; frame wait: the snapshot queued (the oldest applied first if both slots are full), then
; one queued frame applied if a vblank has passed since the last one
apq_commit: push af
            push bc
            push de
            push hl
            ldh a, [apq_n]
            and 3
            cp 2
            call nc, apq_apply
            ldh a, [apq_n]                  ; tail = (head + count) & 1
            ld b, a
            and 3
            ld c, a
            ld a, b
            rlca
            and 1
            add a, c
            and 1
            swap a
            add a, low(APQ_S0)
            ld e, a
            ld d, high(APQ_S0)
            ld hl, APQ_P
            ld b, 16
.cp:        ld a, [hl+]
            ld [de], a
            inc e
            dec b
            jr nz, .cp
            xor a
            ld [APQ_P + 13], a
            ldh a, [apq_n]
            inc a
            ldh [apq_n], a
            ld a, [VBL_CNT]
            ld b, a
            ldh a, [apq_vbl]
            cp b
            jr z, .x
            ld a, b
            ldh [apq_vbl], a
            call apq_apply
.x:         pop hl
            pop de
            pop bc
            pop af
            ret

apq_apply:  ld a, RT_TABLES
            ld [$2000], a
            call apq_apply_b
            ldh a, [code_bank]
            ld [$2000], a
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
