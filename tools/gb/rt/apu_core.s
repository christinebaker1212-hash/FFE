; NES APU -> DMG sound, the work (in bank RT_TABLES after apu_freq / apu_noise; called from the
; bank-0 entry points in apu.s, which map this bank and restore the code bank).
; Reproduced from the NES: duty, constant volume and volume changes (without restarting
; the note: APU_ZOMBIE), the envelope's decay rate (GB envelope), length counters (half-frame
; clocks: two per NES frame), the pulse sweep (period changes and its mute conditions: period
; < 8, target > $7FF), the triangle's linear counter, noise period / mode, $4015.

apu_init_b: ld a, $80
            ldh [$FF26], a                  ; sound on
            ld a, $77
            ldh [$FF24], a                  ; full master volume
            ld a, $FF
            ldh [$FF25], a                  ; every channel to both outputs
            xor a
            ldh [$FF10], a                  ; CH1: no GB sweep
            ldh [$FF1A], a                  ; CH3 DAC off while loading wave RAM
            ld hl, tri_wave
            ld c, $30
.w:         ld a, [hl+]
            ldh [c], a
            inc c
            ld a, c
            cp $40
            jr nz, .w
            ld hl, APU_LEN
            ld b, APU_TLIN + 1 - APU_LEN
            xor a
.z:         ld [hl+], a
            dec b
            jr nz, .z
            ld a, $FF
            ld hl, APU_CV
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl], a
            ret
tri_wave:   db $01, $23, $45, $67, $89, $AB, $CD, $EF, $FE, $DC, $BA, $98, $76, $54, $32, $10

; NES length counter load values (index = value >> 3 of $4003 / $4007 / $400B / $400F)
len_tab:    db 10, 254, 20, 2, 40, 4, 80, 6, 160, 8, 60, 10, 14, 12, 26, 14
            db 12, 16, 24, 18, 48, 20, 96, 22, 192, 24, 72, 26, 16, 28, 32, 30
; NES envelope period V (steps of (V+1)/240 s) -> GB envelope period (steps of n/64 s)
env_tab:    db 1, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4

; ---- L = register, E = value
apu_write:  ld a, l
            cp $18
            ret nc
            ld c, a
            ld b, 0
            ld hl, APU_SH
            add hl, bc
            ld a, [hl]                      ; the same value again (the music driver rewrites
            cp e                            ;   its registers every frame): nothing to do,
            jr nz, .chg                     ;   unless it restarts a note ($4003 / $4007 /
            ld a, c                         ;   $400B / $400F) or is $4015
            cp $15
            jr z, .chg
            and 3
            cp 3
            ret nz
            ld a, c
            cp $10
            ret nc
.chg:       ld [hl], e
            ld a, c
            cp $15
            jp z, w_status
            cp $10
            ret nc                          ; DMC: not reproduced
            cp $0C
            jp nc, w_noise
            cp $08
            jp nc, w_tri
            ld b, 0                         ; pulse B, register 0-3
            cp 4
            jr c, .p
            inc b
            sub 4
.p:         and a
            jp z, p_ctl
            dec a
            jr z, p_sweep
            dec a
            jp z, p_lo
            jp p_hi

p_sweep:    ld hl, APU_SWR                  ; $4001 / $4005: divider reloaded at its next clock
            call hl_b
            ld [hl], 1
            ret

; HL += B (keeps A, F)
hl_b:       push af
            ld a, l
            add a, b
            ld l, a
            jr nc, .x
            inc h
.x:         pop af
            ret

; B = pulse -> C = its NRx1 port ($11 / $16)
pbase:      ld a, b
            and a
            ld c, $11
            ret z
            ld c, $16
            ret

; B = pulse -> HL = its shadow ($4000 / $4004)
psh:        ld a, b
            add a, a
            add a, a
            ld l, a
            ld h, high(APU_SH)
            ld a, l
            add a, low(APU_SH)
            ld l, a
            ret

; A = NES control byte (duty / halt / constant / volume), HL = the channel's APU_CV entry ->
; A = GB NRx2 byte; APU_CV = the volume (constant) or $FF (envelope)
vol_byte:   bit 4, a
            jr z, .env
            and $0F
            ld [hl], a
            swap a
            or $08                          ; add mode, period 0: no envelope steps; $08 writes
            ret                             ;   while playing raise the volume by one
.env:       and $0F                         ; decay from 15 at the NES rate (as near as the
            push hl                         ;   GB envelope gets)
            ld hl, env_tab
            add a, l
            ld l, a
            jr nc, .nc
            inc h
.nc:        ld a, [hl]
            pop hl
            ld [hl], $FF
            or $F0
            ret

; B = pulse, E = new $4000 / $4004 value
p_ctl:      call pbase
            ld a, e
            and $C0
            ldh [c], a                      ; duty (no GB length)
            ld hl, APU_ON
            call hl_b
            ld a, [hl]
            and a
            ret z
            ld hl, APU_CV
            call hl_b
            ; C = NRx1, HL = APU_CV entry, E = control: a volume change
vol_change: bit 4, e
            jr z, .env
            ld a, [hl]
            cp $FF
            jr z, .re                       ; was in envelope mode: restart
            ld d, a
            ld a, e
            and $0F
            sub d
            and $0F
            ret z                           ; same volume
            ld d, a
            ld a, e
            and $0F
            ld [hl], a
            inc c                           ; NRx2: $08 x (new - old) mod 16 ("zombie mode")
.zm:        ld a, $08
            ldh [c], a
            dec d
            jr nz, .zm
            ret
.env:       ld a, [hl]                      ; envelope mode: only a change from constant
            cp $FF                          ;   volume restarts the note
            ret z
.re:        ld a, c
            cp $20
            jp z, n_trig
            jp p_trig

; B = pulse: DE = its NES timer (11 bits) from the shadow
p_timer:    call psh
            inc l
            inc l
            ld e, [hl]
            inc l
            ld a, [hl]
            and 7
            ld d, a
            ret

; DE = NES timer -> DE = GB frequency value
nes_freq:   ld hl, apu_freq
            add hl, de
            add hl, de
            ld e, [hl]
            inc hl
            ld d, [hl]
            ret

; B = pulse: frequency to the GB (no restart), or mute when the NES would (period < 8)
p_lo:       ld hl, APU_ON
            call hl_b
            ld a, [hl]
            and a
            ret z
p_freq:     call p_timer
            ld a, d
            and a
            jr nz, .ok
            ld a, e
            cp 8
            jp c, p_mute
.ok:        call nes_freq
            call pbase
            inc c
            inc c                           ; NRx3
            ld a, e
            ldh [c], a
            inc c
            ld a, d
            ldh [c], a                      ; NRx4: high bits, no restart
            ret

; B = pulse: $4003 / $4007 (length load, restart)
p_hi:       ld a, [APU_SH + $15]            ; channel enabled in $4015?
            ld c, a
            ld a, b
            and a
            ld a, c
            jr z, .b0
            rrca
.b0:        rrca
            ret nc
            ld a, e
            rrca
            rrca
            rrca
            and $1F
            ld hl, len_tab
            add a, l
            ld l, a
            jr nc, .nc
            inc h
.nc:        ld d, [hl]
            ld hl, APU_LEN
            call hl_b
            ld [hl], d
p_trig:     ld hl, APU_ON                   ; B = pulse: restart with the shadow's duty,
            call hl_b                       ;   volume, timer
            ld [hl], 1
            call p_timer
            ld a, d
            and a
            jr nz, .ok
            ld a, e
            cp 8
            jp c, p_mute
.ok:        call pbase
            call psh
            ld a, [hl]
            ld e, a
            and $C0
            ldh [c], a                      ; NRx1 duty
            inc c
            ld hl, APU_CV
            call hl_b
            ld a, e
            call vol_byte
            ldh [c], a                      ; NRx2
            push bc
            call p_timer
            call nes_freq
            pop bc
            inc c
            ld a, e
            ldh [c], a                      ; NRx3
            inc c
            ld a, d
            or $80
            ldh [c], a                      ; NRx4: restart
            ret

; B = pulse: silent until the next restart
p_mute:     ld hl, APU_ON
            call hl_b
            ld [hl], 0
            call pbase
            inc c
            xor a
            ldh [c], a                      ; NRx2 = 0: DAC off
            ret

; ---- triangle ($4008 linear counter / control, $400A / $400B timer, length)
w_tri:      ld a, c
            cp $08
            jr z, .lin
            cp $0A
            jr z, .lo
            cp $0B
            ret nz
            ld a, [APU_SH + $15]
            bit 2, a
            ret z
            ld a, e
            rrca
            rrca
            rrca
            and $1F
            ld hl, len_tab
            add a, l
            ld l, a
            jr nc, .nc
            inc h
.nc:        ld a, [hl]
            ld [APU_LEN + 2], a
            ld a, [APU_SH + $08]            ; linear counter reload
            and $7F
            jr z, t_mute
            srl a                           ; (240 Hz -> frames: / 4)
            srl a
            inc a
            ld [APU_TLIN], a
            ld a, 1
            ld [APU_ON + 2], a
            ld a, $80
            ldh [$FF1A], a                  ; DAC on
            ld a, $20
            ldh [$FF1C], a                  ; 100 %
            call t_freq
            or $80
            ldh [$FF1E], a                  ; restart
            ret
.lo:        ld a, [APU_ON + 2]
            and a
            ret z
            call t_freq
            ldh [$FF1E], a
            ret
.lin:       ld a, [APU_ON + 2]              ; reload 0 silences it (FF1's note-off)
            and a
            ret z
            ld a, e
            and $7F
            jr z, t_mute
            ret

; triangle frequency: NR33 written, A = NR34 high bits
t_freq:     ld a, [APU_SH + $0A]
            ld e, a
            ld a, [APU_SH + $0B]
            and 7
            ld d, a
            call nes_freq
            ld a, e
            ldh [$FF1D], a
            ld a, d
            ret

t_mute:     xor a
            ld [APU_ON + 2], a
            ldh [$FF1C], a                  ; level 0
            ret

; ---- noise ($400C control, $400E period / mode, $400F length + restart)
w_noise:    ld a, c
            cp $0C
            jr z, .ctl
            cp $0E
            jr z, .per
            cp $0F
            ret nz
            ld a, [APU_SH + $15]
            bit 3, a
            ret z
            ld a, e
            rrca
            rrca
            rrca
            and $1F
            ld hl, len_tab
            add a, l
            ld l, a
            jr nc, .nc
            inc h
.nc:        ld a, [hl]
            ld [APU_LEN + 3], a
            jp n_trig
.per:       ld a, e
            and $0F
            ld hl, apu_noise
            add a, l
            ld l, a
            jr nc, .nc2
            inc h
.nc2:       ld d, [hl]
            ld a, e
            and $80                         ; short mode -> 7-bit LFSR
            rrca
            rrca
            rrca
            rrca
            or d
            ldh [$FF22], a
            ret
.ctl:       ld a, [APU_ON + 3]
            and a
            ret z
            ld c, $20                       ; (NR41: vol_change uses C + 1 = NR42)
            ld hl, APU_CV + 3
            jp vol_change

n_trig:     ld a, 1
            ld [APU_ON + 3], a
            ld hl, APU_CV + 3
            ld a, [APU_SH + $0C]
            call vol_byte
            ldh [$FF21], a
            ld a, $80
            ldh [$FF23], a                  ; restart
            ret

n_mute:     xor a
            ld [APU_ON + 3], a
            ldh [$FF21], a
            ret

; ---- $4015: disabled channels stop and their length counters clear
w_status:   ld a, e
            bit 0, a
            jr nz, .s1
            xor a
            ld [APU_LEN], a
            ld b, 0
            call p_mute
.s1:        ld a, e
            bit 1, a
            jr nz, .s2
            xor a
            ld [APU_LEN + 1], a
            ld b, 1
            call p_mute
.s2:        ld a, e
            bit 2, a
            jr nz, .s3
            xor a
            ld [APU_LEN + 2], a
            call t_mute
.s3:        ld a, e
            bit 3, a
            ret nz
            xor a
            ld [APU_LEN + 3], a
            jp n_mute

; ---- once per NES frame: two half-frame clocks (length counters, sweep), four quarter-
; frame clocks (the triangle's linear counter, counted here in frames)
apu_frame:  ld b, 0
            call len_p
            ld b, 1
            call len_p
            ld a, [APU_ON + 2]              ; triangle: length (halt = control flag) and
            and a                           ;   linear counter
            jr z, .t
            ld a, [APU_SH + $08]
            bit 7, a
            jr nz, .t
            ld hl, APU_LEN + 2
            call len_dec
            jr nz, .tl
            call t_mute
            jr .t
.tl:        ld hl, APU_TLIN
            ld a, [hl]
            and a
            jr z, .t
            dec [hl]
            call z, t_mute
.t:         ld a, [APU_ON + 3]              ; noise: length (halt = bit 5)
            and a
            jr z, .s
            ld a, [APU_SH + $0C]
            bit 5, a
            jr nz, .s
            ld hl, APU_LEN + 3
            call len_dec
            call z, n_mute
.s:         ld b, 0                         ; sweeps: two clocks each
            call sw_clk
            ld b, 0
            call sw_clk
            ld b, 1
            call sw_clk
            ld b, 1
            jp sw_clk

; HL = a length counter: two half-frame clocks; Z when it reached 0
len_dec:    ld a, [hl]
            sub 2
            jr nc, .s
            xor a
.s:         ld [hl], a
            and a
            ret

; B = pulse: its length counter unless halted (bit 5 of $4000 / $4004)
len_p:      ld hl, APU_ON
            call hl_b
            ld a, [hl]
            and a
            ret z
            call psh
            bit 5, [hl]
            ret nz
            ld hl, APU_LEN
            call hl_b
            call len_dec
            ret nz
            jp p_mute

; B = pulse: one sweep clock. Divider 0 and enabled with a shift: period += / -= period >>
; shift (pulse 1 negates as one's complement: one more); target > $7FF (adding) or a period
; < 8 mutes. The divider reloads with P (bits 4-6) at 0 or after a $4001 write.
sw_clk:     ld a, b                         ; sweep off (bit 7 of $4001 / $4005): nothing
            and a                           ;   (the divider only matters while it runs)
            ld a, [APU_SH + 1]
            jr z, .s0
            ld a, [APU_SH + 5]
.s0:        bit 7, a
            ret z
            ld hl, APU_ON
            call hl_b
            ld a, [hl]
            and a
            ret z
            call psh
            inc l
            ld a, [hl]                      ; sweep register
            ld [APU_SWT], a
            ld hl, APU_SWD
            call hl_b
            ld a, [hl]
            and a
            jr nz, .dec
            ld a, [APU_SWT]
            bit 7, a
            jr z, .rl
            and 7
            jr z, .rl
            call sw_adj
.rl:        ld a, [APU_SWT]
            swap a
            and 7
            ld hl, APU_SWD
            call hl_b
            ld [hl], a
            ld hl, APU_SWR
            call hl_b
            ld [hl], 0
            ret
.dec:       ld hl, APU_SWR                  ; (reload flag of this pulse)
            call hl_b
            ld a, [hl]
            and a
            jr nz, .rl
            ld hl, APU_SWD
            call hl_b
            dec [hl]
            ret

; B = pulse, sweep enabled with a shift: adjust the period (shadow + GB frequency) or mute
sw_adj:     call p_timer                    ; DE = period
            ld a, [APU_SWT]
            and 7
            ld c, a                         ; C = shift
            push de
.sh:        srl d
            rr e
            dec c
            jr nz, .sh
            ld h, d
            ld l, e                         ; HL = change
            pop de
            ld a, [APU_SWT]
            bit 3, a
            jr nz, .neg
            add hl, de                      ; target = period + change
            ld a, h
            cp 8
            jp nc, p_mute                   ; > $7FF
            jr .set
.neg:       ld a, e                         ; target = period - change (- 1 on pulse 1)
            sub l
            ld l, a
            ld a, d
            sbc a, h
            ld h, a
            ld a, b
            and a
            jr nz, .n2
            dec hl
.n2:        bit 7, h
            jp nz, p_mute
.set:       push hl
            call psh
            inc l
            inc l
            pop de
            ld [hl], e                      ; shadow period low
            inc l
            ld a, [hl]
            and $F8
            or d
            ld [hl], a                      ; high bits
            jp p_freq                       ; GB frequency (mutes a period < 8)
