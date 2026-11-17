; NES APU -> DMG sound. rt_apu_w: L = register ($00-$17 of $40xx), A = value.
; Keeps A, F, BC, DE. Tables in bank RT_TABLES: apu_freq (2048 x 16-bit GB frequency
; for an NES pulse/triangle timer value), apu_noise (16 NR43 values).
; NES pulse 1 -> CH1, pulse 2 -> CH2, triangle -> CH3 (triangle wave), noise -> CH4.

APU_SH     = $D840          ; shadow of $4000-$4017
APU_VOL    = $D858          ; last GB volume byte written per channel (0..3), $FF = unknown

apu_init:   ld a, $80
            ldh [$FF26], a                  ; sound on
            ld a, $77
            ldh [$FF24], a                  ; full master volume
            ld a, $FF
            ldh [$FF25], a                  ; every channel to both outputs
            xor a
            ldh [$FF10], a                  ; CH1: no sweep
            ldh [$FF1A], a                  ; CH3 DAC off while loading wave RAM
            ld hl, tri_wave
            ld c, $30
.w:         ld a, [hl+]
            ldh [c], a
            inc c
            ld a, c
            cp $40
            jr nz, .w
            ld a, $FF
            ld hl, APU_VOL
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl], a
            ret
tri_wave:   db $01, $23, $45, $67, $89, $AB, $CD, $EF, $FE, $DC, $BA, $98, $76, $54, $32, $10

rt_apu_w:   push af
            push bc
            push de
            push hl
            ld e, a                         ; E = value
            ld a, l
            cp $18
            jr nc, .ret
            ld c, a
            ld b, 0
            ld hl, APU_SH
            add hl, bc
            ld [hl], e
            ld a, c
            cp $15
            jr z, .status
            cp $10
            jr nc, .ret                     ; DMC, $4017: ignored
            cp $0C
            jr nc, .noise
            cp $08
            jr nc, .tri
            ; pulse: channel 0/1, register 0-3
            ld a, c
            and 3
            ld d, a
            ld a, c
            srl a
            srl a
            ld b, a                         ; B = pulse channel (0/1)
            ld a, d
            and a
            jr z, .p_ctl
            cp 1
            jr z, .ret                      ; sweep: not reproduced
            cp 2
            jr z, .p_freq_lo
            call pulse_freq                 ; $4003/$4007: pitch + restart
            ld a, 1
            call pulse_trigger
            jr .ret
.p_freq_lo: call pulse_freq                 ; $4002/$4006: pitch only
            xor a
            call pulse_trigger
            jr .ret
.p_ctl:     call pulse_ctl
            jr .ret
.tri:       ld a, c
            cp $08
            jr z, .t_lin
            cp $0A
            jr z, .t_lo
            cp $0B
            jr nz, .ret
            call tri_freq
            ld a, $80
            ldh [$FF1E], a                  ; restart (keeps NR34 frequency high from tri_freq)
            jr .ret
.t_lo:      call tri_freq
            jr .ret
.t_lin:     call tri_level
            jr .ret
.noise:     ld a, c
            cp $0C
            jr z, .n_ctl
            cp $0E
            jr z, .n_per
            cp $0F
            jr nz, .ret
            ld a, $80
            ldh [$FF23], a                  ; restart
            jr .ret
.n_per:     call noise_period
            jr .ret
.n_ctl:     ld a, e
            call vol_byte                   ; A = GB envelope byte for this volume
            ld hl, APU_VOL + 3
            cp [hl]
            jr z, .ret
            ld [hl], a
            ldh [$FF21], a
            ld a, $80
            ldh [$FF23], a
            jr .ret
.status:    ld a, e                         ; $4015: silence disabled channels
            bit 0, a
            call z, mute1
            bit 1, a
            call z, mute2
            bit 2, a
            call z, mute3
            bit 3, a
            call z, mute4
.ret:       pop hl
            pop de
            pop bc
            pop af
            ret

mute1:      push af
            xor a
            ldh [$FF12], a
            ld [APU_VOL], a
            pop af
            ret
mute2:      push af
            xor a
            ldh [$FF17], a
            ld [APU_VOL + 1], a
            pop af
            ret
mute3:      push af
            xor a
            ldh [$FF1A], a
            ld [APU_VOL + 2], a
            pop af
            ret
mute4:      push af
            xor a
            ldh [$FF21], a
            ld [APU_VOL + 3], a
            pop af
            ret

; NES --LC VVVV -> GB envelope byte VVVV0000 (constant volume; envelope mode uses its
; period as a decreasing GB envelope from 15)
vol_byte:   bit 4, a
            jr z, .env
            and $0F
            swap a
            ret
.env:       and $07
            or $F0                          ; start at 15, decrease
            ret

; B = pulse (0/1). Duty + volume from register 0.
pulse_ctl:  ld a, e
            and $C0
            ld d, a                         ; duty
            ld a, b
            and a
            ld a, d
            jr nz, .c2
            ldh [$FF11], a
            jr .v
.c2:        ldh [$FF16], a
.v:         ld a, e
            call vol_byte
            ld hl, APU_VOL
            ld c, b
            ld b, 0
            add hl, bc
            ld b, c
            cp [hl]
            ret z
            ld [hl], a                      ; volume changed: write NRx2 and restart
            ld d, a
            ld a, b
            and a
            ld a, d
            jr nz, .v2
            ldh [$FF12], a
            jr .t
.v2:        ldh [$FF17], a
.t:         ld a, 1
            jp pulse_trigger

; B = pulse: look up the GB frequency for the shadow timer -> D:E (hi:lo), saved in pf_hi/lo
pulse_freq: ld a, b
            add a, a
            add a, a
            ld c, a
            ld b, 0
            ld hl, APU_SH + 2
            add hl, bc
            ld a, [hl+]                     ; timer low
            ld e, a
            ld a, [hl]
            and 7
            ld d, a                         ; DE = NES timer
            call nes_freq                   ; DE = GB frequency
            ld a, c
            srl a
            srl a
            ld b, a
            ld a, b
            and a
            jr nz, .c2
            ld a, e
            ldh [$FF13], a
            ld a, d
            ld [APU_SH + $18], a            ; pending NR14 high bits
            ret
.c2:        ld a, e
            ldh [$FF18], a
            ld a, d
            ld [APU_SH + $19], a
            ret

; B = pulse, A = 1 to restart: write NRx4 with the frequency high bits
pulse_trigger:
            and a
            jr z, .nt
            ld a, $80
.nt:        ld d, a
            ld a, b
            and a
            jr nz, .c2
            ld a, [APU_SH + $18]
            or d
            ldh [$FF14], a
            ret
.c2:        ld a, [APU_SH + $19]
            or d
            ldh [$FF19], a
            ret

tri_freq:   ld a, [APU_SH + $0A]
            ld e, a
            ld a, [APU_SH + $0B]
            and 7
            ld d, a
            call nes_freq
            ld a, e
            ldh [$FF1D], a
            ld a, d
            ldh [$FF1E], a
            ret

tri_level:  ld a, e                         ; linear counter reload 0 = silent
            and $7F
            jr z, .off
            ld a, [APU_VOL + 2]
            cp $20
            ret z
            ld a, $80
            ldh [$FF1A], a
            ld a, $20
            ldh [$FF1C], a                  ; 100 %
            ld [APU_VOL + 2], a
            ld a, [APU_SH + $0B]
            and 7
            ld a, $80
            ldh [$FF1E], a
            ret
.off:       xor a
            ldh [$FF1C], a
            ld [APU_VOL + 2], a
            ret

noise_period:
            ld a, e
            and $0F
            ld c, a
            ld b, 0
            ld a, RT_TABLES
            ld [$2000], a
            ld hl, apu_noise
            add hl, bc
            ld a, [hl]
            ld d, a
            ldh a, [code_bank]
            ld [$2000], a
            ld a, e
            and $80                         ; short mode -> 7-bit LFSR
            rrca
            rrca
            rrca
            rrca
            or d
            ldh [$FF22], a
            ret

; DE = NES timer (11 bits) -> DE = GB frequency value (11 bits)
nes_freq:   ld a, RT_TABLES
            ld [$2000], a
            ld hl, apu_freq
            add hl, de
            add hl, de
            ld a, [hl+]
            ld e, a
            ld d, [hl]
            ldh a, [code_bank]
            ld [$2000], a
            ret
