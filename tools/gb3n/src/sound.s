; FF3's sound driver as native code (written from the listing's bank $36: $8003 update sound,
; $81E6 / $820B channel scripts, $857D-$872C envelopes, $8925 music, $89C3 init song, $8AF0 /
; $8B11 fades, $8B9D sound effects). Its state keeps FF3's layout: MUS = FF3's $7F40 (the arrays
; for the 7 channels: 0 pulse 1, 1 pulse 2, 2 triangle, 3 noise, 4 dmc, 5 / 6 the sound effect's
; pulse 2 and noise). Song data: GB bank B_SND0 + k holds NES bank $36 at $4000 and the song bank
; k ($37, $38, $39, $09) at $6000, so an NES pointer p reads at p - $4000.
; The output stage (snd_out) gives the channel values to the GB sound: pulses to CH1 / CH2, the
; triangle to CH3 (a triangle wave), noise to CH4. Volume changes inside a note: zombie-mode steps
; (no restart; restarts where an emulator ignores them). The driver runs once a frame, with a second
; tick every ~161 frames: FF3's tempo at the NES's 60.0988 Hz.

MUS        = $DD00          ; FF3's $7F40 page (work RAM bank 1)
M_CUR      = MUS + $00      ; $7F40
M_SAVED    = MUS + $01
M_CTRL     = MUS + $02      ; $7F42: 1 new song, 2 resume, 4 stop, 8 fade, $20 / $40 fading, $80 on
M_SONG     = MUS + $03
M_SVOL     = MUS + $04      ; song volume
M_TEMPO    = MUS + $05
M_TCNT     = MUS + $06      ; (2 bytes)
M_FADE     = MUS + $08
M_SFX      = MUS + $09      ; $7F49
A_FLAGS    = $0A            ; per-channel arrays (offsets from MUS, 7 bytes each)
A_PLO      = $11
A_PHI      = $18
A_TICK     = $1F
A_OCT      = $26
A_FLO      = $2D
A_FHI      = $34
A_VOL      = $3B
A_SWEEP    = $42
A_DUTY     = $49
A_CHVOL    = $50
A_DLO      = $57
A_DHI      = $5E
A_RDEP     = $65
A_RC1      = $6C
A_RC2      = $73
A_EST      = $7A
A_VENV     = $81
A_EOFF     = $88
A_ELOOP    = $8F
A_ERATE    = $96
A_EACC     = $9D
A_EVAL     = $A4
A_PENV     = $AB
A_POFF     = $B2
A_PCNT     = $B9
MZ         = $DDC0          ; the driver's temporaries (FF3's $D0-$D9)
MZ_SLOT    = MZ + 0
MZ_HW      = MZ + 1
MZ_SFX     = MZ + 2
MZ_PTR     = MZ + 3         ; (2)
MZ_NOTE    = MZ + 5
MZ_T6      = MZ + 6
MZ_T8      = MZ + 8         ; (2)
MZ_BANK    = MZ + 10
MZ_SAVE    = MZ + 11
O_CV       = MZ + 12        ; the output stage: GB volume now per GB channel (4)
O_XLO      = MZ + 16        ; GB frequency low per channel (4)
MZ_ACC     = MZ + 20        ; (2) the NES rate: a second tick when it carries
Z_ZMB      = MZ + 22        ; 1: zombie-mode volume steps work here (boot test), 0: restarts
T_DUR      = $8805 - $4000  ; FF3's tables (NES bank $36, read where the bank is mapped)
T_DECAY    = $8815 - $4000
T_VOL      = $8825 - $4000
T_FREQ     = $872D - $4000
T_NOISE    = $87BD - $4000
T_VENV     = $9A7C - $4000
T_PENV     = $9EAB - $4000
T_SFX      = $92C5 - $4000
T_SONG2B   = $8C77 - $4000

section bank 0, $1000
; ---- sound on (boot)
snd_init:   ld a, $80
            ldh [$FF26], a
            ld a, $77
            ldh [$FF24], a
            ld a, $FF
            ldh [$FF25], a
            xor a
            ldh [$FF10], a                  ; (no hardware sweep)
            ldh [$FF1A], a
            ld hl, snd_wave
            ld de, $FF30
            ld b, 16
.w:         ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .w
            ld hl, MUS                      ; FF3's init sound ($81C3)
            ld b, $C0 + 24
            xor a
.c:         ld [hl+], a
            dec b
            jr nz, .c
            ld a, $FF
            ld [O_CV], a
            ld [O_CV + 1], a
            ld [O_CV + 2], a
            ld [O_CV + 3], a
; volume changes inside a note use "zombie mode" (NRx2 = $08 adds 1 to the playing volume): the
; Game Boy Color and accurate emulators do it, some emulators ignore it (mGBA 0.10 in Color mode:
; the envelopes would be lost). A silent test note at volume 1, its level read back from PCM12
; ($FF76) before and after one $08 write: 1 then 1 = ignored (volume changes restart the note);
; anything else (2, or PCM12 not readable): zombie mode, as the hardware (FF1's test)
            ld a, 1
            ld [Z_ZMB], a
            xor a
            ldh [$FF25], a                  ; (nothing to the speakers)
            ld a, $80
            ldh [$FF11], a
            ld a, $18                       ; volume 1, up, no envelope steps
            ldh [$FF12], a
            ld a, $C0
            ldh [$FF13], a
            ld a, $87
            ldh [$FF14], a
            ld de, $4000                    ; (a write is ignored until the envelope clock's
.zw:        dec de                          ;   first tick: 1/64 s)
            ld a, d
            or e
            jr nz, .zw
            call .zmax
            ld d, b
            ld a, $08
            ldh [$FF12], a
            call .zmax
            xor a
            ldh [$FF12], a                  ; (channel 1 off again)
            ld a, $FF
            ldh [$FF25], a
            ld a, d
            cp 1
            ret nz
            ld a, b
            cp 1
            ret nz
            xor a
            ld [Z_ZMB], a
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
snd_wave:   db $01, $23, $45, $67, $89, $AB, $CD, $EF, $FE, $DC, $BA, $98, $76, $54, $32, $10

; ---- the game asks: play song A / stop / a sound effect A
mus_play:   ld [M_SONG], a
            ld a, 1
            ld [M_CTRL], a
            ret
sfx_play:   or $80
            ld [M_SFX], a
            ret

; ---- once a frame (V-Blank interrupt): FF3's update sound, then the GB output
snd_frame:  ldh a, [rSVBK]                   ; (work RAM bank 1: a battle maps bank 2)
            push af
            ld a, 1
            ldh [rSVBK], a
            ldh a, [mapbank]                ; (the bank mapped now: back at the end)
            ld [MZ_SAVE], a
            call snd_bank
            ld a, [M_SONG]                  ; ($8003: song $37 silences the sound effects)
            cp $37
            jr nz, .sx
            xor a
            ld [M_SFX], a
            jr .mu
.sx:        call sfx_update
.mu:        call mus_update
            ld hl, MZ_ACC                   ; (FF3's 60.0988 Hz on the GB's 59.7275: a second
            ld a, [hl]                      ;   tick every ~161 frames, 65536 x 0.006216)
            add low(407)
            ld [hl+], a
            ld a, [hl]
            adc high(407)
            ld [hl], a
            jr nc, .o
            ld a, [M_SONG]
            cp $37
            call nz, sfx_update
            call mus_update
.o:         call snd_out
            ld a, [M_CTRL]                  ; $7F40 bit 7 = playing
            and $80
            ld b, a
            ld a, [M_CUR]
            and $7F
            or b
            ld [M_CUR], a
            ld a, [MZ_SAVE]
            ld [MBC5_BANKL], a
            pop af
            ldh [rSVBK], a
            ret

; the song bank for the song asked for ($899F: $00-$18 bank $37, $19-$2A $38, $37-$3A $39,
; $3B-$40 $09; $2B-$36 are in bank $36, in every GB sound bank)
snd_bank:   ld a, [M_CTRL]                  ; (the bank of the song playing, unless a new one
            rra                             ;   starts: this runs from V-Blank during loads, so a
            ld a, [M_SONG]                  ;   new id can arrive before its "play" bit; FF3's
            jr c, .n                        ;   36/899F reads $7F43 from its main loop)
            ld a, [M_CUR]
            and $7F
.n:         ld b, 0
            cp $19
            jr c, .s
            inc b
            cp $2B
            jr c, .s
            inc b
            cp $3B
            jr c, .s
            inc b
.s:         ld a, b
            add B_SND0
            ld [MZ_BANK], a
            ld [MBC5_BANKL], a
            ret

; HL = MUS + array A + the channel (MZ_SLOT)
ch_addr:    ld l, a
            ld a, [MZ_SLOT]
            add l
            ld l, a
            ld h, high(MUS)
            ret

; ---- music ($8925)
mus_update: ld a, [M_CTRL]
            ld c, a
            and 1
            jr z, .nn
            ld a, [M_CUR]                   ; a new song (the same one playing: on)
            bit 7, a
            jr z, .ini
            and $7F
            ld b, a
            ld a, [M_SONG]
            cp b
            jr z, .on
.ini:       ld a, [M_CUR]
            ld [M_SAVED], a
            ld a, [M_SONG]
            ld [M_CUR], a
            call snd_bank
            jp song_init
.on:        ld a, $80
            ld [M_CTRL], a
            jr .ch
.nn:        ld a, c
            and 2
            jr z, .ns
            ld a, [M_SAVED]                 ; resume the song before
            ld [M_CUR], a
            ld [M_SONG], a
            ld a, 1
            ld [M_CTRL], a
            call snd_bank
            jp song_init
.ns:        ld a, c
            and 4
            call nz, mus_stop
            ld a, [M_CTRL]
            bit 5, a
            jr z, .fo
            call fade_in
            jr .ch
.fo:        bit 6, a
            call nz, fade_out
.ch:        ld a, [M_CTRL]
            bit 7, a
            ret z
            jp mus_channels

; ($89C3) init song
song_init:  call mus_silence
            ld c, 0
.ch:        ld a, c
            ld [MZ_SLOT], a
            ld a, A_FLAGS
            call ch_addr
            xor a
            ld [hl], a
            ld a, A_TICK
            call ch_addr
            ld [hl], 0
            ld a, A_VOL
            call ch_addr
            ld [hl], 0
            ld a, A_SWEEP
            call ch_addr
            ld [hl], 8
            ld a, A_DUTY
            call ch_addr
            ld [hl], $30
            ld a, A_CHVOL
            call ch_addr
            ld [hl], $0F
            ld a, A_VENV
            call ch_addr
            ld [hl], $FF
            ld a, A_PENV
            call ch_addr
            ld [hl], $FF
            ld a, A_RDEP
            call ch_addr
            ld [hl], $FF
            ld a, A_EST
            call ch_addr
            ld [hl], $FF
            inc c
            ld a, c
            cp 5
            jr nz, .ch
            ld a, 150
            ld [M_TEMPO], a
            xor a
            ld [M_TCNT], a
            ld [M_TCNT + 1], a
            ld a, [M_SONG]                  ; the song's pointer: 5 channel pointers
            cp $19
            jr c, .a
            cp $2B
            jr nc, .b
            sub $19
.a:         add a
            ld l, a
            ld h, $60                       ; ($A000 of its bank)
            jr .p
.b:         cp $37
            jr nc, .c3
            sub $2B
            add a
            add low(T_SONG2B)
            ld l, a
            ld a, high(T_SONG2B)
            adc 0
            ld h, a
            jr .p
.c3:        cp $3B
            jr nc, .d
            sub $37
            add a
            add low($B3AE - $4000)
            ld l, a
            ld a, high($B3AE - $4000)
            adc 0
            ld h, a
            jr .p
.d:         sub $3B
            add a
            ld l, a
            ld h, high($B400 - $4000)
.p:         ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld bc, -$4000
            add hl, bc                      ; HL = the song header (5 pointers)
            ld c, 0
.cp:        ld a, c
            ld [MZ_SLOT], a
            ld a, [hl+]
            ld e, a
            ld a, [hl+]
            ld d, a
            push hl
            ld a, A_PLO
            call ch_addr
            ld [hl], e
            ld a, A_PHI
            call ch_addr
            ld [hl], d
            ld a, e                         ; enabled unless the pointer is $FFFF
            and d
            inc a
            jr z, .dis
            ld a, A_FLAGS
            call ch_addr
            set 7, [hl]
.dis:       pop hl
            inc c
            ld a, c
            cp 5
            jr nz, .cp
            ld a, [M_CTRL]                  ; ($8A87) start: faded in or at full volume
            and 8
            jr nz, .fi
            ld a, $80
            ld [M_CTRL], a
            ld a, $0F
            ld [M_SVOL], a
            ret
.fi:        ld a, $A0
            ld [M_CTRL], a
            xor a
            ld [M_SVOL], a
            ld [M_FADE], a
            ret

mus_stop:   ld a, [M_CTRL]                  ; ($8AA7)
            and 8
            jr nz, .f
            ld [M_CTRL], a
            jp mus_silence
.f:         ld a, $C0
            ld [M_CTRL], a
            xor a
            ld [M_FADE], a
            ret
mus_silence:
            ld c, 0                         ; ($8AC0: the music's volumes to 0)
.s:         ld a, c
            ld [MZ_SLOT], a
            ld a, A_VOL
            call ch_addr
            ld [hl], 0
            inc c
            ld a, c
            cp 4
            jr nz, .s
            ret
fade_in:    ld a, [M_FADE]                  ; ($8AF0)
            and a
            jr nz, .d
            ld hl, M_SVOL
            inc [hl]
            ld a, [hl]
            cp $0F
            jr c, .r
            ld hl, M_CTRL
            res 5, [hl]
            ret
.r:         ld a, $10
            ld [M_FADE], a
.d:         ld hl, M_FADE
            dec [hl]
            ret
fade_out:   ld a, [M_FADE]                  ; ($8B11)
            and a
            jr nz, .d
            ld hl, M_SVOL
            dec [hl]
            jr nz, .r
            xor a
            ld [M_CTRL], a
            jp mus_silence
.r:         ld a, $10
            ld [M_FADE], a
.d:         ld hl, M_FADE
            dec [hl]
            ret

; ($8B2D) the tempo: a tick each time the counter passes 150; then the envelopes
mus_channels:
            xor a
            ld [MZ_SFX], a
            ld hl, M_TCNT
            ld a, [M_TEMPO]
            add [hl]
            ld [hl+], a
            jr nc, .t
            inc [hl]
.t:         ld hl, M_TCNT                   ; counter - 150 >= 0: a tick
            ld a, [hl+]
            sub 150
            ld e, a
            ld a, [hl]
            sbc 0
            jr c, .env
            ld [hl-], a
            ld [hl], e
            ld b, 4                         ; channels 4 (dmc) .. 0 with their hardware types
.c:         ld a, b
            ld [MZ_SLOT], a
            ld a, 4
            sub b
            ld [MZ_HW], a
            push bc
            call ch_script
            pop bc
            dec b
            bit 7, b
            jr z, .c
            jr .t
.env:       ld b, 0
.e:         ld a, b
            ld [MZ_SLOT], a
            push bc
            call ch_env
            pop bc
            inc b
            ld a, b
            cp 4
            jr nz, .e
            ret

; ($81E6) one channel's script for a tick
ch_script:  ld a, A_FLAGS
            call ch_addr
            bit 7, [hl]
            ret z
            ld a, A_TICK
            call ch_addr
            ld a, [hl]
            and a
            call z, ch_cmd
            ld a, A_TICK
            call ch_addr
            dec [hl]
            ld a, A_DLO                     ; the decay counter (16 bits)
            call ch_addr
            ld a, [hl]
            and a
            jr nz, .d
            ld a, A_DHI
            call ch_addr
            ld a, [hl]
            and a
            ret z
            dec [hl]
            ld a, A_DLO
            call ch_addr
.d:         dec [hl]
            ret

; ($820B) the channel's commands up to its next note
ch_cmd:     ld a, A_PLO
            call ch_addr
            ld a, [hl]
            ld [MZ_PTR], a
            ld a, A_PHI
            call ch_addr
            ld a, [hl]
            sub $40                         ; (NES pointer -> GB)
            ld [MZ_PTR + 1], a
            ld de, 0                        ; DE = Y
cmd_next:   call cmd_byte
            cp $E0
            jp c, cmd_note
            sub $E0
            add a
            ld l, a
            ld h, 0
            push de
            ld de, cmd_table
            add hl, de
            pop de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            jp hl
; A = the script's byte at Y (DE), Y + 1
cmd_byte:   ld a, [MZ_PTR]
            add e
            ld l, a
            ld a, [MZ_PTR + 1]
            adc d
            ld h, a
            inc de
            ld a, [hl]
            ret
cmd_table:  dw c_tempo, c_vol, c_vol, c_vol, c_vol, c_vol, c_vol, c_vol
            dw c_vol, c_vol, c_vol, c_vol, c_vol, c_vol, c_vol, c_oct
            dw c_oct, c_oct, c_oct, c_oct, c_oct, c_env, c_env, c_env
            dw c_sweep, c_hihat, c_snare, c_rpt, c_rend, c_volta, c_jump, c_end

c_tempo:    call cmd_byte
            ld [M_TEMPO], a
            jp cmd_next
c_vol:      call cmd_last                   ; $E1-$EE: the channel volume 2-15
            sub $DF
            ld b, a
            ld a, A_CHVOL
            call ch_addr
            ld [hl], b
            jp cmd_next
c_oct:      call cmd_last
            sub $EF
            ld b, a
            ld a, A_OCT
            call ch_addr
            ld [hl], b
            jp cmd_next
c_env:      call cmd_last                   ; $F5 / $F6 / $F7: duty $30 / $70 / $B0, then the
            sub $F5                         ;   volume and pitch envelopes
            swap a
            add a
            add a
            add $30
            ld b, a
            ld a, A_DUTY
            call ch_addr
            ld [hl], b
            call cmd_byte
            ld b, a
            ld a, A_VENV
            call ch_addr
            ld [hl], b
            call cmd_byte
            ld b, a
            ld a, A_PENV
            call ch_addr
            ld [hl], b
            jp cmd_next
c_sweep:    call cmd_byte
            ld b, a
            ld a, A_SWEEP
            call ch_addr
            ld [hl], b
            jp cmd_next
c_hihat:    ld b, 4                         ; octave 4, envelope 0, volume 8
            ld c, 0
            ld a, 8
            jr c_drum
c_snare:    ld b, 5                         ; octave 5, envelope 1, volume 15
            ld c, 1
            ld a, 15
c_drum:     push af
            ld a, A_OCT
            call ch_addr
            ld [hl], b
            ld a, A_VENV
            call ch_addr
            ld [hl], c
            pop bc
            ld a, A_CHVOL
            call ch_addr
            ld [hl], b
            jp cmd_next
c_rpt:      call cmd_byte                   ; ($8499) repeat start: count in rc1 / rc2 by depth
            ld b, a
            ld a, A_RDEP
            call ch_addr
            inc [hl]
            ld a, A_RC1
            jr z, .s
            ld a, A_RC2
.s:         call ch_addr
            ld [hl], b
            jp cmd_next
c_rend:     ld a, A_RDEP                    ; ($84AF) repeat end: loop while the count lasts
            call ch_addr
            ld a, [hl]
            and a
            ld a, A_RC1
            jr z, .s
            ld a, A_RC2
.s:         call ch_addr
            dec [hl]
            jr nz, c_jump
            inc de
            inc de
            ld a, A_RDEP
            call ch_addr
            dec [hl]
            jp cmd_next
c_volta:    ld a, A_RDEP                    ; ($84D0) volta: jump on an odd count
            call ch_addr
            ld a, [hl]
            and a
            ld a, A_RC1
            jr z, .s
            ld a, A_RC2
.s:         call ch_addr
            bit 0, [hl]
            jr nz, .j
            inc de
            inc de
            jp cmd_next
.j:         ld a, A_RDEP
            call ch_addr
            dec [hl]
c_jump:     call cmd_byte                   ; ($84F0) jump
            ld c, a
            call cmd_byte
            sub $40
            ld [MZ_PTR + 1], a
            ld a, c
            ld [MZ_PTR], a
            ld de, 0
            jp cmd_next
c_end:      ld a, A_FLAGS                   ; ($84FF) the channel off (its volume kept; the
            call ch_addr                    ;   output stage silences it)
            res 7, [hl]
            ld a, [MZ_SFX]
            and a
            jr nz, .sx
            ld hl, MUS + A_FLAGS            ; all music channels off: the music off
            ld b, 5
.m:         bit 7, [hl]
            ret nz
            inc l
            dec b
            jr nz, .m
            xor a
            ld [M_CTRL], a
            ret
.sx:        ld a, [MZ_HW]                   ; a sound effect's channel: the music's channel
            ld hl, MUS + A_FLAGS + 1        ;   under it keyed off until its next note
            cp 3
            jr z, .ko
            ld hl, MUS + A_FLAGS + 3
            cp 1
            jr nz, .se
.ko:        set 1, [hl]
.se:        ld a, [MUS + A_FLAGS + 5]
            ld b, a
            ld a, [MUS + A_FLAGS + 6]
            or b
            bit 7, a
            ret nz
            xor a
            ld [M_SFX], a
            ret
; A = the command byte just read (at Y - 1)
cmd_last:   dec de
            call cmd_byte
            ret

; ($826F) a note / rest / tie: the pointer moves past it, its duration
cmd_note:   ld [MZ_NOTE], a
            ld a, A_PLO                     ; the pointer += Y
            call ch_addr
            ld a, [MZ_PTR]
            add e
            ld [MZ_PTR], a
            ld [hl], a
            ld a, [MZ_PTR + 1]
            adc d
            ld [MZ_PTR + 1], a
            add $40
            ld b, a
            ld a, A_PHI
            call ch_addr
            ld [hl], b
            ld a, [MZ_NOTE]                 ; duration
            and $0F
            ld l, a
            ld h, 0
            ld bc, T_DUR
            add hl, bc
            ld b, [hl]
            ld a, A_TICK
            call ch_addr
            ld [hl], b
            ld a, [MZ_NOTE]
            cp $D0
            ret nc                          ; a tie
            cp $C0
            jr c, .key
            ld a, A_FLAGS                   ; a rest: key off
            call ch_addr
            set 1, [hl]
            ret
.key:       ld a, A_FLAGS                   ; key on
            call ch_addr
            set 0, [hl]
            res 1, [hl]
            xor a
            ld b, a
            ld a, A_EST
            call ch_addr
            ld [hl], b
            ld a, A_EOFF
            call ch_addr
            ld [hl], b
            ld a, A_EACC
            call ch_addr
            ld [hl], b
            ld a, A_PCNT
            call ch_addr
            ld [hl], b
            ld a, A_POFF
            call ch_addr
            ld [hl], b
            ld a, [MZ_HW]
            and a
            ret z                           ; (dmc)
            cp 2
            jr z, .pitch                    ; (the triangle has no decay)
            call decay_init
            ld a, [MZ_HW]
            cp 1
            jr z, .noise
.pitch:     ld a, A_OCT                     ; period from the table: pitch + 12 * octave
            call ch_addr
            ld a, [hl]
            ld b, a
            add a
            add b
            add a
            add a                           ; 12 * octave
            ld b, a
            ld a, [MZ_NOTE]
            swap a
            and 15
            add b
            add a
            ld l, a
            ld h, 0
            ld bc, T_FREQ
            add hl, bc
            ld a, [hl+]
            ld c, [hl]
            ld b, a
            ld a, A_FLO
            call ch_addr
            ld [hl], b
            ld a, A_FHI
            call ch_addr
            ld [hl], c
            ret
.noise:     ld a, A_OCT
            call ch_addr
            ld a, [hl]
            ld b, a
            add a
            add b
            add a
            add a
            ld b, a
            ld a, [MZ_NOTE]
            swap a
            and 15
            add b
            ld l, a
            ld h, 0
            ld bc, T_NOISE
            add hl, bc
            ld b, [hl]
            ld a, A_FLO
            call ch_addr
            ld [hl], b
            ret

; ($831D) the decay counter: this note's and the following ties' decay durations
decay_init: ld a, [MZ_NOTE]
            and 15
            ld l, a
            ld h, 0
            ld bc, T_DECAY
            add hl, bc
            ld a, [hl]
            ld [MZ_T8], a
            xor a
            ld [MZ_T8 + 1], a
            ld de, 0
.t:         call cmd_byte                   ; (Y from the note's end: MZ_PTR was moved)
            cp $D0
            jr c, .d
            cp $E0
            jr nc, .d
            and 15
            ld l, a
            ld h, 0
            ld bc, T_DECAY
            add hl, bc
            ld a, [MZ_T8]
            add [hl]
            ld [MZ_T8], a
            jr nc, .t
            ld hl, MZ_T8 + 1
            inc [hl]
            jr .t
.d:         ld a, [MZ_T8]
            ld b, a
            ld a, A_DLO
            call ch_addr
            ld [hl], b
            ld a, [MZ_T8 + 1]
            ld b, a
            ld a, A_DHI
            call ch_addr
            ld [hl], b
            ret

; ($857D) the channel's envelopes for this frame
ch_env:     ld a, A_FLAGS
            call ch_addr
            bit 7, [hl]
            ret z
            bit 1, [hl]
            jr nz, .off
            call venv
            jp penv
.off:       ld a, A_VOL
            call ch_addr
            ld [hl], 0
            ret

; ($8595) the volume envelope: attack, decay, release
venv:       ld a, A_EST
            call ch_addr
            ld a, [hl]
            cp 3
            jr nc, .zero
            cp 1
            jr nz, .st
            ld a, A_DLO                     ; decay done: release
            call ch_addr
            ld a, [hl]
            and a
            jr nz, .st
            ld a, A_DHI
            call ch_addr
            ld a, [hl]
            and a
            jr nz, .st
            ld a, A_EST
            call ch_addr
            inc [hl]
            ld a, A_EOFF
            call ch_addr
            ld [hl], 0
.st:        ld a, A_VENV
            call ch_addr
            ld a, [hl]
            bit 7, a
            jr nz, .none
            add a
            ld l, a
            ld h, 0
            ld bc, T_VENV
            add hl, bc
            ld a, [hl+]
            ld h, [hl]
            ld l, a                         ; HL = this envelope's state pointers (NES)
            ld a, A_EST
            push hl
            call ch_addr
            ld a, [hl]
            pop hl
            add a
            add l
            ld l, a
            jr nc, .n
            inc h
.n:         ld a, h
            sub $40
            ld h, a
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld a, h
            sub $40
            ld h, a
            ld a, l
            ld [MZ_T8], a
            ld a, h
            ld [MZ_T8 + 1], a               ; MZ_T8 = this state's data
            ld a, A_EST
            call ch_addr
            ld a, [hl]
            and a
            jp z, env_attack
            jp env_decay
.none:      xor a                           ; (no envelope: $FF, or 0 on quiet songs)
            ld b, a
            ld a, [M_SVOL]
            cp 5
            jr c, .z
            ld b, $FF
.z:         ld a, A_VOL
            call ch_addr
            ld [hl], b
            ret
.zero:      ld a, A_VOL
            call ch_addr
            ld [hl], 0
            ret

; envelope data byte A (Y) of MZ_T8
env_byte:   ld l, a
            ld a, [MZ_T8]
            add l
            ld l, a
            ld a, [MZ_T8 + 1]
            adc 0
            ld h, a
            ld a, [hl]
            ret

env_attack: ld a, A_EOFF                    ; ($85FA)
            call ch_addr
            ld a, [hl]
            push af
            call env_byte
            ld b, a
            ld a, A_EVAL
            call ch_addr
            ld [hl], b
            ld a, A_EOFF
            call ch_addr
            inc [hl]
            pop af
            inc a
            call env_byte
            bit 7, a
            jr z, .v
            ld a, A_EST
            call ch_addr
            inc [hl]
            ld a, A_EOFF
            call ch_addr
            ld [hl], 0
.v:         ld a, A_EVAL
            call ch_addr
            ld a, [hl]
            jp env_out

env_decay:  ld a, A_EVAL                    ; ($8635)
            call ch_addr
            ld a, [hl]
            and a
            jr z, .koff
            ld a, A_EOFF
            call ch_addr
            ld a, [hl]
            and a
            jr nz, .rate
            xor a
            call env_byte                   ; the rate, then the first value
            ld b, a
            ld a, A_ERATE
            call ch_addr
            ld [hl], b
            ld a, A_EOFF
            call ch_addr
            inc [hl]
            ld a, A_ELOOP
            call ch_addr
            ld [hl], 0
.rate:      ld a, A_ERATE
            call ch_addr
            ld b, [hl]
            ld a, A_EACC
            call ch_addr
            ld a, [hl]
            add b
            ld [hl], a
            cp 100
            jr c, .val
            sub 100
            ld [hl], a
            ld a, A_EVAL
            call ch_addr
            dec [hl]
            jr nz, .val
.koff:      ld a, A_EST
            call ch_addr
            ld [hl], 3
            ld a, A_VOL
            call ch_addr
            ld [hl], 0
            ret
.val:       ld a, A_EVAL
            call ch_addr
            ld a, [hl]
            ld [MZ_NOTE], a                 ; (the value, changed by the steps)
            ld a, A_ELOOP
            call ch_addr
            ld a, [hl]
            and a
            jr nz, .step
            ld a, A_EOFF
            call ch_addr
            ld a, [hl]
            push af
            call env_byte
            pop bc
            and a
            jr z, .out                      ; terminated
            bit 7, a
            jr z, .cnt
            add b                           ; a negative byte: back in the data
            ld b, a
            call env_byte
.cnt:       ld c, a
            ld a, A_ELOOP
            call ch_addr
            ld [hl], c
            inc b
            inc b
            ld a, A_EOFF
            call ch_addr
            ld [hl], b
.step:      ld a, A_EOFF
            call ch_addr
            ld a, [hl]
            dec a
            call env_byte                   ; the change in volume
            ld b, a
            ld a, [MZ_NOTE]
            bit 7, b
            jr nz, .neg
            add b
            cp $10
            jr c, .sv
            ld a, $0F
            jr .sv
.neg:       add b
            jr c, .sv
            xor a
.sv:        ld [MZ_NOTE], a
            ld a, A_ELOOP
            call ch_addr
            dec [hl]
.out:       ld a, [MZ_NOTE]
            ; fall into env_out

; volume = table[channel volume, value] (times the song volume for music) ($8614 / $86B5)
env_out:    ld c, a
            ld a, A_CHVOL
            call ch_addr
            ld a, [hl]
            swap a
            or c
            ld l, a
            ld h, 0
            ld bc, T_VOL
            add hl, bc
            ld a, [MZ_SFX]
            and a
            jr nz, .v
            ld a, [M_SVOL]
            swap a
            or [hl]
            ld l, a
            ld h, 0
            ld bc, T_VOL
            add hl, bc
.v:         ld b, [hl]
            ld a, A_VOL
            call ch_addr
            ld [hl], b
            ret

; ($86D5) the pitch envelope: steps added to the period's low byte
penv:       ld a, A_PENV
            call ch_addr
            ld a, [hl]
            bit 7, a
            ret nz
            add a
            ld l, a
            ld h, 0
            ld bc, T_PENV
            add hl, bc
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld a, h
            sub $40
            ld h, a
            ld a, l
            ld [MZ_T8], a
            ld a, h
            ld [MZ_T8 + 1], a
            ld a, A_PCNT
            call ch_addr
            ld a, [hl]
            and a
            jr nz, .dec
            ld a, A_POFF
            call ch_addr
            ld a, [hl]
            push af
            call env_byte
            pop bc
            and a
            ret z
            bit 7, a
            jr z, .c
            add b
            ld b, a
            call env_byte
.c:         ld c, a
            ld a, A_PCNT
            call ch_addr
            ld [hl], c
            inc b
            inc b
            ld a, A_POFF
            call ch_addr
            ld [hl], b
            dec b
            ld a, b
            call env_byte                   ; the period change
            ld b, a
            ld a, A_FLO
            call ch_addr
            ld a, [hl]
            bit 7, b
            jr nz, .neg
            add b
            jr nc, .s
            ld a, $FF
            jr .s
.neg:       add b
            jr c, .s
            xor a
.s:         ld [hl], a
.dec:       ld a, A_PCNT
            call ch_addr
            dec [hl]
            ret

; ---- sound effects ($8B9D)
sfx_update: ld a, [M_SFX]
            and a
            ret z
            cp $FF
            jr z, .mute
            bit 7, a
            jr nz, sfx_init
            ld a, $FF                       ; ($8C58) its two channels: pulse 2, noise
            ld [MZ_SFX], a
            ld a, 5
            ld [MZ_SLOT], a
            ld a, 3
            ld [MZ_HW], a
            call ch_script
            call ch_env
            ld a, 6
            ld [MZ_SLOT], a
            ld a, 1
            ld [MZ_HW], a
            call ch_script
            jp ch_env
.mute:      ld hl, M_SFX
            inc [hl]
            jr sfx_mute
sfx_init:   call sfx_mute                   ; ($8BB8)
            ld b, 5
.c:         ld a, b
            ld [MZ_SLOT], a
            ld a, A_FLAGS
            call ch_addr
            ld [hl], 0
            ld a, A_TICK
            call ch_addr
            ld [hl], 0
            ld a, A_VOL
            call ch_addr
            ld [hl], 0
            ld a, A_SWEEP
            call ch_addr
            ld [hl], 8
            ld a, A_DUTY
            call ch_addr
            ld [hl], $30
            ld a, A_CHVOL
            call ch_addr
            ld [hl], $0F
            ld a, A_VENV
            call ch_addr
            ld [hl], $FF
            ld a, A_PENV
            call ch_addr
            ld [hl], $FF
            ld a, A_RDEP
            call ch_addr
            ld [hl], $FF
            ld a, A_EST
            call ch_addr
            ld [hl], $FF
            inc b
            ld a, b
            cp 7
            jr nz, .c
            ld a, [M_SFX]                   ; its two script pointers
            add a
            ld l, a
            ld h, 0
            ld bc, T_SFX
            add hl, bc
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld bc, -$4000
            add hl, bc
            ld b, 5
.p:         ld a, b
            ld [MZ_SLOT], a
            ld a, [hl+]
            ld e, a
            ld a, [hl+]
            ld d, a
            push hl
            ld a, A_PLO
            call ch_addr
            ld [hl], e
            ld a, A_PHI
            call ch_addr
            ld [hl], d
            ld a, e
            and d
            inc a
            jr z, .d
            ld a, A_FLAGS
            call ch_addr
            set 7, [hl]
.d:         pop hl
            inc b
            ld a, b
            cp 7
            jr nz, .p
            ld a, $40
            ld [M_SFX], a
            ret

; ($8C29) the sound effect's channels off, the music's under them keyed off
sfx_mute:   ld hl, MUS + A_FLAGS + 5
            bit 7, [hl]
            jr z, .n
            res 7, [hl]
            ld hl, MUS + A_FLAGS + 1
            set 1, [hl]
.n:         ld hl, MUS + A_FLAGS + 6
            bit 7, [hl]
            ret z
            res 7, [hl]
            ld hl, MUS + A_FLAGS + 3
            set 1, [hl]
            ret

; ---- the GB output: each channel's values as FF3's APU writes would make them
snd_out:    ld a, 0                         ; pulse 1: CH1
            ld c, $10
            call out_pulse
            ld a, [MUS + A_FLAGS + 5]       ; pulse 2: the sound effect's while it plays
            bit 7, a
            ld a, 5
            jr nz, .p2
            ld a, 1
.p2:        ld c, $15
            call out_pulse
            call out_tri
            ld a, [MUS + A_FLAGS + 6]       ; noise: the sound effect's while it plays
            bit 7, a
            ld a, 6
            jr nz, .nz
            ld a, 3
.nz:        jp out_noise

; slot A to the GB pulse channel at C ($10 CH1 / $15 CH2)
out_pulse:  ld [MZ_SLOT], a
            ld a, c
            ld [MZ_T6], a
            ld a, A_FLAGS
            call ch_addr
            bit 7, [hl]
            jr nz, .on
            xor a                           ; off: silent
            jr .vol0
.on:        bit 0, [hl]
            res 0, [hl]
            ld a, A_VOL
            push af
            call ch_addr
            ld a, [hl]
            and 15
            ld [MZ_NOTE], a
            pop af
            jr nz, .key
            call o_cv                       ; same note: a volume change by "zombie mode" steps
            ld a, [hl]                      ;   (NRx2 = $08 adds 1 to the playing volume, mod
            ld b, a                         ;   16: no restart, no click; the Game Boy's and
            ld a, [MZ_NOTE]                 ;   the Color's own behaviour, as FF1's driver)
            cp b
            jr z, .fr
            and a                           ; (to 0, or not known: a restart)
            jr z, .key
            ld a, b
            cp $FF
            jr z, .key
            ld a, [Z_ZMB]                   ; (no zombie mode here: a restart)
            and a
            jr z, .key
            ld a, [MZ_NOTE]
            ld [hl], a
            sub b
            and 15
            ld b, a
            ld a, [MZ_T6]
            add 2
            ld c, a
            ld a, $08
.z:         ldh [c], a
            dec b
            jr nz, .z
.fr:        call o_freq                     ; the period (pitch envelope): frequency only
            ld a, [MZ_T6]
            add 3
            ld c, a
            ld a, e
            ldh [c], a
            inc c
            ld a, d
            ldh [c], a
            ret
.key:       call o_cv
            ld a, [MZ_NOTE]
            ld [hl], a
            ld a, A_DUTY                    ; NRx1: duty
            call ch_addr
            ld a, [hl]
            and $C0
            ld b, a
            ld a, [MZ_T6]
            inc a
            ld c, a
            ld a, b
            ldh [c], a
            inc c                           ; NRx2: the volume (0: the DAC on, silent)
            ld a, [MZ_NOTE]
            swap a
            or $08
            ldh [c], a
            call o_freq
            ld a, [MZ_T6]
            add 3
            ld c, a
            ld a, e
            ldh [c], a
            inc c
            ld a, d
            or $80
            ldh [c], a
            ret
.vol0:      ld a, [MZ_T6]
            add 2
            ld c, a
            xor a
            ldh [c], a
            call o_cv
            ld [hl], $FF
            ret
; HL = O_CV for the channel at MZ_T6
o_cv:       ld a, [MZ_T6]
            sub $10
            jr z, .c
            ld a, 1
.c:         add low(O_CV)
            ld l, a
            ld h, high(O_CV)
            ret
; DE = the GB frequency (E low, D high) for the slot's NES period (table in bank 0)
o_freq:     ld a, A_FLO
            call ch_addr
            ld e, [hl]
            ld a, A_FHI
            call ch_addr
            ld a, [hl]
            and 7
            ld d, a
            ld h, d
            ld l, e
            add hl, hl
            ld de, snd_ftab
            add hl, de
            ld e, [hl]
            inc hl
            ld d, [hl]
            ret

; the triangle (slot 2) to CH3: on while its volume is not 0
out_tri:    ld a, 2
            ld [MZ_SLOT], a
            ld a, A_FLAGS
            call ch_addr
            ld b, [hl]
            res 0, [hl]
            ld a, A_VOL
            call ch_addr
            ld a, [hl]
            and a
            jr z, .off
            bit 7, b
            jr z, .off
            ld a, $20
            ldh [$FF1C], a
            call o_freq
            ld a, e
            ldh [$FF1D], a
            ld a, [O_CV + 2]
            and a
            jr z, .start
            bit 0, b
            jr nz, .start
            ld a, d
            ldh [$FF1E], a
            ret
.start:     ld a, $80                       ; (the Color: a restart does not corrupt wave RAM)
            ldh [$FF1A], a
            ld a, d
            or $80
            ldh [$FF1E], a
            ld a, 1
            ld [O_CV + 2], a
            ret
.off:       xor a
            ldh [$FF1C], a
            ld [O_CV + 2], a
            ret

; noise slot A to CH4
out_noise:  ld [MZ_SLOT], a
            ld a, A_FLAGS
            call ch_addr
            bit 7, [hl]
            jr z, .off
            ld b, [hl]
            res 0, [hl]
            ld a, A_VOL
            call ch_addr
            ld a, [hl]
            and 15
            ld c, a
            ld a, A_FLO
            call ch_addr
            ld a, [hl]
            and $8F
            ld e, a                         ; FF3's noise byte: period index, mode bit 7
            and 15
            bit 7, e
            jr z, .m
            add 16
.m:         ld l, a
            ld h, 0
            push bc
            ld bc, snd_ntab
            add hl, bc
            pop bc
            ld a, [hl]
            ldh [$FF22], a
            bit 0, b                        ; (a new note: started)
            jr nz, .key
            ld a, [O_CV + 3]
            cp c
            ret z
            ld b, a                         ; a volume change: zombie steps (to 0 / unknown:
            ld a, c                         ;   a restart)
            and a
            jr z, .key
            ld a, b
            cp $FF
            jr z, .key
            ld a, [Z_ZMB]
            and a
            jr z, .key
            ld a, c
            ld [O_CV + 3], a
            sub b
            and 15
            ld b, a
            ld a, $08
.z:         ldh [$FF21], a
            dec b
            jr nz, .z
            ret
.key:       ld a, c
            ld [O_CV + 3], a
            swap a
            or $08
            ldh [$FF21], a
            ld a, $80
            ldh [$FF23], a
            ret
.off:       xor a
            ldh [$FF21], a
            dec a
            ld [O_CV + 3], a
            ret
