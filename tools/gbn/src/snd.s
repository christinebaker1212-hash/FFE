; FF1 native engine: sound (bank SND_BANK). FF1's music engine (sound.py: the native port of
; MusicPlay, its song data from a copy of the user's bank 13) runs once a frame in V-Blank;
; its channel values go straight to the GB sound here: the pulses to CH1 / CH2 (duty, volume,
; frequency from the period table), the triangle to CH3 (a triangle wave). Music RAM: the
; engine's NES-style page at NES_RAM (only the engine uses it).
NES_RAM    = $DE00
SND_BANK   = 7
MUS_DATA   = 95
S_FREQ     = $7000          ; period -> GB frequency (2048 x 2)
S_TSMUS    = $6F00          ; music per tileset (8), per vehicle (9)
S_VEHMUS   = $6F10
TR_BATTLE  = $50            ; FF1's tracks for its events (bank 0B / 0C / 0E code)
TR_FANFARE = $53
TR_GAMEOVER = $52
TR_SHOP    = $4F
TR_MENU    = $51
TR_DLGFAN  = $54
TR_TREAS   = $58
TR_LINEUP  = $55
TR_EPILOGUE = $43
TR_MINIMAP = $41
TR_BRIDGE  = $42
TR_SAVED   = $56
TR_HPUP    = $57

section bank 7, $4000
; boot: sound on, the triangle's wave
snd_init_b: ld a, $80
            ldh [$FF26], a                  ; NR52 on
            ld a, $77
            ldh [$FF24], a                  ; NR50 full
            ld a, SND_MASK                  ; NR51 all channels both sides (test builds:
            ldh [$FF25], a                  ;   env GBN_SND_MASK keeps some only)
            xor a
            ldh [$FF10], a                  ; NR10 no sweep
            ldh [$FF1A], a                  ; NR30 off
            ld hl, snd_wave                 ; wave RAM: a triangle
            ld de, $FF30
            ld b, 16
.w:         ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .w
            ld a, $20
            ldh [$FF1C], a                  ; NR32 100 %
            ld hl, snd_sh
            ld b, 64                        ; (and the sound effects' state)
            xor a
.c:         ld [hl+], a
            dec b
            jr nz, .c
            ld a, $FF
            ld [snd_cv], a
            ld [snd_cv + 1], a
            ld a, $80                       ; (no track yet: silent)
            ld [NES_RAM + $4B], a
; volume changes inside a note use "zombie mode" (NRx2 = $08 adds 1 to the playing volume: no
; restart, so no click and no lost phase). The Game Boy, the Game Boy Color and accurate
; emulators do it; some emulators do not on the Color (mGBA 0.10: the write is ignored, the
; music's envelopes are lost). On a Color: a test note at volume 1 (nothing to the speakers),
; its output level read back from PCM12 ($FF76), one $08 write, read again: 1 then 2 = zombie
; mode works; 1 then 1 = it does not (volume changes then restart the note); anything else
; (PCM12 not readable, as some Color revisions in double speed): as the hardware, zombie mode
            ld a, 1
            ld [snd_zmb], a
            ld a, VOL_FORCE                 ; (test builds: GBN_VOLMODE 1 zombie, 2 restarts,
            and a                           ;   3 note starts only; 0 = the test below)
            jr z, .auto
            dec a
            ld [snd_zmb], a
            ret
.auto:      ldh a, [is_cgb]
            and a
            ret z
            xor a
            ldh [$FF25], a                  ; (nothing to the speakers)
            ldh [$FF10], a
            ld a, $80
            ldh [$FF11], a                  ; 50 % duty
            ld a, $18
            ldh [$FF12], a                  ; volume 1, up, no envelope steps
            ld a, $C0
            ldh [$FF13], a
            ld a, $87
            ldh [$FF14], a                  ; frequency $7C0, restart
            call .zwait                     ; (the hardware ignores a write until the envelope
            call .zmax                      ;   clock's first tick, 1/64 s)
            ld d, b                         ; D = the level before
            ld a, $08
            ldh [$FF12], a                  ; zombie: + 1
            call .zmax                      ; B = after
            xor a
            ldh [$FF12], a                  ; (channel 1 off again)
            ld a, SND_MASK
            ldh [$FF25], a
            ld a, d
            cp 1
            ret nz
            ld a, b
            cp 1
            ret nz
            xor a
            ld [snd_zmb], a
            ret
.zwait:     ld de, $4000                    ; (~55 ms)
.zw:        dec de
            ld a, d
            or e
            jr nz, .zw
            ret
.zmax:      ld bc, 0                        ; B = the highest level of 256 reads
.zr:        ldh a, [$FF76]
            and $0F
            cp b
            jr c, .zn
            ld b, a
.zn:        dec c
            jr nz, .zr
            ret
tri_lens:   db 10, 254, 20, 2, 40, 4, 80, 6, 160, 8, 60, 10, 14, 12, 26, 14     ; the NES length table
            db 12, 16, 24, 18, 48, 20, 96, 22, 192, 24, 72, 26, 16, 28, 32, 30
snd_wave:   db $01, $23, $45, $67, $89, $AB, $CD, $EF, $FE, $DC, $BA, $98, $76, $54, $32, $10

; L = NES-style register of the engine ($00-$15), A = value, only if changed
awf:        push hl
            ld h, high(snd_sh)
            push af
            ld a, l
            add a, low(snd_sh)
            ld l, a
            pop af
            cp [hl]
            pop hl
            ret z
; the value to the GB channel (keeps A, BC, DE, HL)
aw:         push af
            push bc
            push de
            push hl
            ld e, a
            ld a, l
            add a, low(snd_sh)
            ld c, a
            ld b, high(snd_sh)
            ld a, e
            ld [bc], a
            ld a, l
            cp $00
            jr z, .vol1
            cp $04
            jr z, .vol2
            cp $02
            jr z, .f1l
            cp $03
            jr z, .f1h
            cp $06
            jr z, .f2l
            cp $07
            jr z, .f2h
            cp $08
            jr z, .tlin
            cp $0A
            jr z, .ftl
            cp $0B
            jr z, .fth
            cp $15
            jp z, .en
.x:         pop hl
            pop de
            pop bc
            pop af
            ret
.vol1:      ld hl, $FF11                    ; CH1: duty, volume; restarted when it changed
            ld c, 0
            jr .vol
.vol2:      ld hl, $FF16
            ld c, 1
.vol:       ld a, e                         ; (no restart for a volume change: FF1 changes the
            and $C0                         ;   volume nearly every frame, and a restart resets
            ld [hl+], a                     ;   the wave: a 60 Hz buzz and flat notes on the
            ld a, e                         ;   GB. Steps of $08 to NRx2 ("zombie mode") move
            and $0F                         ;   the playing volume, as the recompiled build)
            call p58
            ld b, a                         ; B = the new GB volume
            ld a, c
            add a, low(snd_cv)
            ld e, a
            ld d, high(snd_cv)
            ld a, [de]
            cp $FF
            jr z, .vr                       ; (unknown: set and restart)
            ld a, [snd_zmb]                 ; (zombie mode does not work here: every change
            cp 2                            ;   by a restart with the new volume; 2, a test
            jr z, .vs                       ;   build: the volume only at a note's start)
            and a
            jr nz, .zm
            ld a, [de]
            cp b
            jp z, .x
            jr .vr
.vs:        ld a, b
            ld [de], a
            jp .x
.zm:        push hl
            ld h, d
            ld l, e
            ld a, b
            sub [hl]
            and $0F
            ld [hl], b
            pop hl                          ; HL = NRx2
            jr z, .vx
            ld d, a
            ld a, $08
.vz:        ld [hl], a
            dec d
            jr nz, .vz
.vx:        jp .x
.vr:        ld a, b
            ld [de], a
            swap a
            or $08                          ; (DAC on, constant volume)
            ld [hl+], a                     ; NRx2
            inc hl                          ; NRx4: restart with the frequency
            ld a, c
            add a, low(snd_fh)
            ld e, a
            ld d, high(snd_fh)
            ld a, [de]
            or $80
            ld [hl], a
            jr .x
.f1l:       ld hl, snd_sh + 2
            ld c, 0
            jr .fl
.f1h:       ld hl, snd_sh + 2
            ld c, 0
            jr .fh
.f2l:       ld hl, snd_sh + 6
            ld c, 1
            jr .fl
.f2h:       ld hl, snd_sh + 6
            ld c, 1
            jr .fh
.ftl:       ld hl, snd_sh + $0A
            ld c, 2
            jr .fl
.fth:       ld a, e                         ; (a new note: the length counter loaded, the
            rrca                            ;   linear counter reloaded)
            rrca
            rrca
            and $1F
            add a, low(tri_lens)
            ld l, a
            ld h, high(tri_lens)
            jr nc, .fl2
            inc h
.fl2:       ld a, [hl]
            ld [tri_len], a
            ld a, [snd_sh + 8]
            bit 7, a
            jr nz, .ft1
            ld e, a
            call .tlc
.ft1:       ld hl, snd_sh + $0A
            ld c, 2
            jr .fh
.fl:        call .freq                      ; the period's low byte: NRx3, NRx4 (no restart)
            ld [hl+], a
            ld [hl], d
            ld a, d
            ld [bc], a
            jr .x
.fh:        call .freq                      ; the high byte: restart (the pulses with their
            push af                         ;   current volume in NRx2 first)
            ld a, c
            sub low(snd_fh)
            cp 2
            jr nc, .ft
            and a                           ; (square 1: no hardware sweep; FF1's music
            jr nz, .fs                      ;   never sweeps, and an effect's sweep left
            ldh [$FF10], a                  ;   on bent every later note: owner, 2026-11-23)
            xor a
.fs:        push de
            add a, low(snd_cv)
            ld e, a
            ld d, high(snd_cv)
            ld a, [de]
            cp $FF
            jr nz, .fk
            xor a
            ld [de], a
.fk:        swap a
            or $08
            dec hl
            ld [hl+], a
            pop de
.ft:        pop af                          ; the triangle: a new note
            ld [hl+], a
            ld a, d
            ld [bc], a
            ld e, a
            ldh a, [is_cgb]                 ; (a Color: restarted every note, as before; its
            and a                           ;   wave RAM does not suffer, and the ModRetro
            jr nz, .ftc                     ;   Chromatic, an FPGA Color, wants the restart)
            ld a, [tri_on]
            and a
            jr z, .ftg
            ld [hl], e                      ; sounding: the new pitch only, no restart (as the
            jp .x                           ;   NES triangle, which keeps its phase; and a
.ftg:       xor a                           ;   restart while the wave plays corrupts the
            ldh [$FF1A], a                  ;   wave RAM on a plain Game Boy). Stopped: the
            push hl                         ;   wave RAM written again (safe with the DAC off)
            ld hl, snd_wave                 ;   and the note started
            ld c, $30
            ld b, 16
.fw:        ld a, [hl+]
            ldh [c], a
            inc c
            dec b
            jr nz, .fw
            pop hl
            ld a, [tri_dac]
            ldh [$FF1A], a
            and a
            jp z, .x                        ; (DAC off: no note, as before)
            ld [tri_on], a
            ld a, e
            or $80
            ld [hl], a
            jp .x
.ftc:       ld a, e
            or $80
            ld [hl], a
            ld a, [tri_dac]
            ld [tri_on], a
            jp .x
; HL = the period's bytes, C = channel -> A = GB frequency low, D = high; HL = NRx3; BC =
; its high-bits shadow
.freq:      ld a, [hl+]
            ld e, a
            ld a, [hl]
            and 7
            ld d, a
            sla e
            rl d                            ; x 2
            ld hl, S_FREQ
            add hl, de
            ld a, [hl+]
            ld d, [hl]
            push af
            ld a, c
            add a, low(snd_fh)
            ld e, a
            ld b, high(snd_fh)
            ld a, c
            ld hl, snd_nrx3
            add a, l
            ld l, a
            ld a, [hl]
            ld l, a
            ld h, $FF
            ld c, e
            pop af
            ret
.tlin:      xor a                           ; the triangle: control bit set: on while its
            ld [tri_lc], a                  ;   linear counter value is set; clear: it runs
            bit 7, e                        ;   out after value / 4 frames (FF1 ends a song
            jr nz, .tl1                     ;   with $70: ~0.47 s)
            call .tlc
            jp .x
.tl1:       ld a, e
            and $7F
            ld a, 0
            jr z, .toff
            ld a, $80
.toff:      call nr30_w
            jp .x
.tlc:       ld a, e                         ; (the countdown: the linear counter's (v + 3) / 4
            and $7F                         ;   frames or the length counter's len / 2,
            jr z, .tl0                      ;   whichever runs out first: both count while
            add a, 3                        ;   the control bit is clear)
            srl a
            srl a
            ld e, a
            ld a, [tri_len]
            inc a
            srl a
            jr z, .tl0
            cp e
            jr c, .tls
            ld a, e
.tls:       ld [tri_lc], a
            ld a, $80
            jp nr30_w
.tl0:       jp nr30_w
.en:        bit 0, e                        ; $15: channels off
            jr nz, .e1
            xor a
            ldh [$FF12], a
.e1:        bit 1, e
            jr nz, .e2
            xor a
            ldh [$FF17], a
.e2:        bit 2, e
            jp nz, .x
            xor a
            call nr30_w
            jp .x
snd_nrx3:   db $13, $18, $1D
; NR30 = A (the wave channel's DAC): remembered; off also stops the channel (tri_on 0)
nr30_w:     ldh [$FF1A], a
            ld [tri_dac], a
            and a
            ret nz
            ld [tri_on], a
            ret

section wram, $CFC0
snd_sh:     ds 32                           ; the engine's register values (shadow)
snd_fh:     ds 4                            ; GB frequency high bits per channel
sfx_req:    ds 1                            ; an effect to start (SFX_*; the game sets it)
sfx_menu:   ds 1                            ; menus: cursor / button sounds (read_pad)
sfx_nmode:  ds 1                            ; noise: 0 off, 1 the ship, 2 the airship
sfx_nlast:  ds 1
sfx_nvol:   ds 1
sfx_fc:     ds 1                            ; (its frame counter)
sfx_tot:    ds 1                            ; the effect: frames left
sq_n:       ds 1                            ; square blocks left, frames of this one, next
sq_c:       ds 1
sq_p:       ds 2
nz_n:       ds 1                            ; noise blocks
nz_c:       ds 1
nz_p:       ds 2
sw_r:       ds 1                            ; the NES sweep ($4005), its divider, the period
sw_d:       ds 1
sw_per:     ds 2
sw_mute:    ds 1
tri_lc:     ds 1                            ; the triangle's linear counter run out in N frames
tri_len:    ds 1                            ; its length counter (half frames, last $400B)
snd_cv:     ds 2                            ; the pulses' GB volume now ($FF: unknown)
snd_zmb:    ds 1                            ; 1: zombie mode works (volume steps), 0: restarts
mus_cur:    ds 1                            ; the music track asked for last (main.s snd_track)
tri_on:     ds 1                            ; the wave channel started and not stopped since
tri_dac:    ds 1                            ; the last NR30 value

; ---- sound effects (FF1's, data from the ROM: sound.sfx_data). The square part plays on CH2
; while the music engine leaves its square 2 alone (sq2_sfx = NES_RAM + $7E, FF1's own
; mechanism); the NES sweep runs here, two half-frame clocks a frame; the noise on CH4.
SFX_TBL    = $6D00
SFX_NZ     = $6E40          ; NES noise period -> NR43
section bank 7, $4900
; once a frame (the STAT interrupt): a requested effect starts, the music, the effect's step
snd_frame_b:
            ld a, [tri_lc]                  ; the triangle's linear counter
            and a
            jr z, .nt
            dec a
            ld [tri_lc], a
            jr nz, .nt
            call nr30_w
.nt:        ld a, [sfx_req]
            and a
            call nz, sfx_start
            call mus_play_b
            jp sfx_step

sfx_start:  dec a
            add a, a
            ld l, a
            ld h, high(SFX_TBL)
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            xor a
            ld [sfx_req], a
            ld [snd_sh + 4], a              ; (the music sets its square 2 volume again after)
            ld a, [hl+]                     ; header: frames, square blocks, noise blocks
            ld [sfx_tot], a
            ld [NES_RAM + $7E], a           ; FF1 sq2_sfx: the music leaves square 2 alone
            ld a, [hl+]
            ld [sq_n], a
            ld a, [hl+]
            ld [nz_n], a
            inc hl
            ld a, l
            ld [sq_p], a
            ld a, h
            ld [sq_p + 1], a
            ld de, 5
            add hl, de
            ld a, l
            ld [nz_p], a
            ld a, h
            ld [nz_p + 1], a
            ld a, 1
            ld [sq_c], a
            ld [nz_c], a
            xor a
            ld [sw_r], a
            ret

sfx_step:   ld a, [sfx_tot]
            and a
            jp z, sfx_noise                 ; (none: the ship's / airship's noise)
            dec a
            ld [sfx_tot], a
            jr nz, .on
            ld a, $FF                       ; (square 2's volume unknown to the music again)
            ld [snd_cv + 1], a
            ld a, [NES_RAM + $4B]           ; over: square 2 back to the music; silent if no
            and a                           ;   song plays
            jr z, .m
            xor a
            ldh [$FF17], a
.m:         xor a
            ldh [$FF21], a
            dec a
            ld [sfx_nlast], a
            ret
.on:        call sq_step
            jp nz_step

; FF1 UpdateBattleSFX_Square: the next block when this one's frames are over, then the sweep
sq_step:    ld a, [sq_n]
            and a
            jr z, .sw
            ld hl, sq_c
            dec [hl]
            jr nz, .sw
            dec a
            ld [sq_n], a
            call blk_next
            ld a, [hl+]                     ; $4004: duty, volume
            ld b, a
            and $C0
            ldh [$FF16], a                  ; NR21
            ld a, b
            call nes_vol_p
            ldh [$FF17], a                  ; NR22
            ld a, [hl+]                     ; $4005: the sweep
            ld [sw_r], a
            swap a
            and 7
            inc a
            ld [sw_d], a
            ld a, [hl+]                     ; $4006 / $4007: the period; restarted
            ld [sw_per], a
            ld a, [hl+]
            and 7
            ld [sw_per + 1], a
            ld a, [hl]
            ld [sq_c], a
            xor a
            ld [sw_mute], a
            ld a, [sw_per + 1]              ; (NES: a period < 8 is silent; FF1's hit sounds
            and a                           ;   have only noise)
            jr nz, .pl
            ld a, [sw_per]
            cp 8
            jr nc, .pl
            ld a, 1
            ld [sw_mute], a
            xor a
            ldh [$FF17], a
            ret
.pl:        call sq_freq
            or $80
            ldh [$FF19], a
            ret
.sw:        ld a, [sw_r]                    ; the NES sweep: enabled, shift > 0, not muted
            bit 7, a
            ret z
            and 7
            ret z
            ld a, [sw_mute]
            and a
            ret nz
            call .clk
.clk:       ld hl, sw_d                     ; one half-frame clock: the divider
            dec [hl]
            ret nz
            ld a, [sw_r]
            ld b, a
            swap a
            and 7
            inc a
            ld [hl], a
            ld a, [sw_per]
            ld e, a
            ld a, [sw_per + 1]
            ld d, a
            ld a, b
            and 7
            ld c, a
            ld h, d
            ld l, e
.sh:        srl h
            rr l
            dec c
            jr nz, .sh
            bit 3, b
            jr z, .add
            ld a, e                         ; negate (pitch up; square 2: P - (P >> s))
            sub l
            ld e, a
            ld a, d
            sbc a, h
            ld d, a
            jr .chk
.add:       add hl, de
            ld d, h
            ld e, l
            ld a, d
            cp 8
            jr nc, .mute                    ; (target > $7FF)
.chk:       ld a, d
            and a
            jr nz, .ok
            ld a, e
            cp 8
            jr c, .mute                     ; (period < 8)
.ok:        ld a, e
            ld [sw_per], a
            ld a, d
            ld [sw_per + 1], a
            call sq_freq
            ldh [$FF19], a                  ; (no restart)
            ret
.mute:      ld a, 1
            ld [sw_mute], a
            xor a
            ldh [$FF17], a
            ret
; the period -> NR23; A = the frequency's high bits
sq_freq:    ld a, [sw_per]
            ld l, a
            ld a, [sw_per + 1]
            ld h, a
            add hl, hl
            ld de, S_FREQ
            add hl, de
            ld a, [hl+]
            ldh [$FF18], a
            ld a, [hl]
            ret
; HL = the next block of square (sq_p) / noise (nz_p, DE = nz_p) data; the pointer + 8
blk_next:   ld de, sq_p
blk_de:     ld a, [de]
            ld l, a
            inc de
            ld a, [de]
            ld h, a
            push hl
            ld bc, 8
            add hl, bc
            ld a, h
            ld [de], a
            dec de
            ld a, l
            ld [de], a
            pop hl
            ret
; the pulses at 7/8 of FF1's volume: the voices' balance measured against FF1's NSF (libgme,
; the owner's soundtrack): triangle / pulse 1 = 0.87 on the NES; the GB wave channel at full
; level against pulses at 7/8 gives 0.86. A = 0-15 -> (7 A + 4) >> 3
p58:        push bc
            ld b, a
            add a, a
            add a, a
            add a, a
            sub b
            add a, 4
            srl a
            srl a
            srl a
            pop bc
            ret
; nes_vol for a pulse: the level at 7/8; a decay from 13 instead of 15 (its steps as nes_vol:
; about the same length)
nes_vol_p:  bit 4, a
            jr z, .d
            and $0F
            call p58
            swap a
            ret
.d:         and $0F
            add a, 4
            srl a
            srl a                           ; n = 1-4 (as nes_vol)
            or $D0                          ; (from 13, down)
            ret
; A = NES volume byte (bit 4 constant volume, else decay at speed v) -> GB NRx2
nes_vol:    bit 4, a
            jr z, .d
            and $0F
            swap a
            ret
.d:         and $0F                         ; a step every (v + 1) / 240 s ~ n / 64 s
            add a, 4
            srl a
            srl a
            or $F0                          ; (from 15, down)
            ret

; FF1 UpdateBattleSFX_Noise
nz_step:    ld a, [nz_n]
            and a
            ret z
            ld hl, nz_c
            dec [hl]
            ret nz
            dec a
            ld [nz_n], a
            ld de, nz_p
            call blk_de
            ld a, [hl+]                     ; $400C
            ld b, a
            ld a, [hl+]                     ; $400E
            ld e, a
            ld a, [hl]
            ld [nz_c], a
            ld a, b
            call nes_vol
; A = NR42, E = NES $400E: the noise, restarted (off at volume 0)
nz_set:     ldh [$FF21], a
            and $F0
            ret z
            call nz_poly
            ld a, $80
            ldh [$FF23], a
            ret
nz_poly:    ld a, e
            and $0F
            add a, low(SFX_NZ)
            ld l, a
            ld h, high(SFX_NZ)
            ld a, [hl]
            bit 7, e
            jr z, .w
            or $08                          ; (short mode)
.w:         ldh [$FF22], a
            ret

; FF1's overworld loop: the ship (noise $0A, the volume rising and falling with the frame
; counter, 0-7) and the airship (volume 8, the noise period from twice the frame counter)
sfx_noise:  ld hl, sfx_fc
            inc [hl]
            ld a, [sfx_nmode]
            and a
            jr nz, .on
            ld hl, sfx_nlast
            cp [hl]
            ret z
            ld [hl], a
            ldh [$FF21], a
            ret
.on:        ld b, a
            ld a, [sfx_fc]
            dec b
            jr nz, .air
            bit 7, a
            jr z, .p
            cpl
.p:         and $70
            ld c, a
            ld e, $0A
            jr .set
.air:       dec b                           ; (2: twice the frame counter; 3: the airship's
            jr nz, .tr                      ;   takeoff / landing, the frame counter itself)
            add a, a
.tr:        ld e, a
            ld c, $80
.set:       ld a, [sfx_nmode]
            ld hl, sfx_nlast
            cp [hl]
            ld [hl], a
            jr nz, .rs                      ; another mode or volume: restarted
            ld a, [sfx_nvol]
            cp c
            jp z, nz_poly
.rs:        ld a, c
            ld [sfx_nvol], a
            jr nz_set
