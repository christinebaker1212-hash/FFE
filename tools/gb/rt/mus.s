; ---- FF1's music engine (b13:B000 MusicPlay), native: the same RAM results as the 6502 code
; (music_track $4B, primer $4C, mu_chan $4D, sq2_sfx $7E, tmp $10/$11/$1E/$1F, mu_scoreptr
; $18/$19, the channel records at $B0/$C0/$D0), its APU writes straight to apu_write (the GB
; sound as before, without the bank-0 write path). The song data and tables are read from the
; NES bank mapped at $8000 (bank 13) through mrd. build.py turns this on only when the engine's
; bytes in the ROM match (hash) and passes the table addresses it reads from the ROM's own
; operands (MUS_* equates). In bank RT_TABLES, next to apu_write (build.py appends it to
; apu_core.s); mus_play and mrd are in bank 0 (end of apu.s).
; In: A, X (E), Y (C), flags as at JSR $B000; out: as its RTS (A, X, Y; N, Z, C; V where it
; sets it). B = D = 0 on return.

mus_play_b: ld a, [NES_RAM + $4B]
            bit 7, a
            jr z, .play
            cp $80
            jr nz, .x80                     ; (song over, channels silenced already)
            ld a, $70
            ld l, $00
            call awf
            ld l, $04
            call awf
            ld l, $08
            call awf
            ld hl, NES_RAM + $4B
            inc [hl]
            ld a, [hl]
            ldh [nzv], a
            ld hl, $7010                    ; A = $70; Z = 0, C = 1 (CMP #$80)
            push hl
            pop af
            ret
.x80:       ld h, a
            sub $80
            ldh [nzv], a                    ; (N from A - $80)
            ld l, $10                       ; A = the track; Z = 0, C = 1
            push hl
            pop af
            ret
.play:      and a
            jp nz, mus_new
            ld a, [NES_RAM + $BF]           ; square 1: volume (duty 25%), no sweep; the
            bit 7, a                        ;   frequency when it changed
            jr nz, .s1n
            ld a, [NES_RAM + $BC]
            or $70
            ld l, $00
            call awf
            ld a, $7F
            ld l, $01
            call awf
            ld a, [NES_RAM + $BE]
            ld l, $02
            call awf
            ld a, [NES_RAM + $BF]
            ld l, $03
            call aw
            ld a, $80
            ld [NES_RAM + $BF], a
            jr .s1d
.s1n:       ld a, [NES_RAM + $BC]
            or $70
            ld l, $00
            call awf
            ld a, $7F
            ld l, $01
            call awf
.s1d:       ld a, [NES_RAM + $7E]           ; square 2, unless a sound effect plays on it
            and a
            jr z, .s2u
            ld hl, NES_RAM + $7E
            dec [hl]
            jr nz, .s2d
            jr .s2f
.s2u:       ld a, [NES_RAM + $CF]
            bit 7, a
            jr nz, .s2n
.s2f:       ld a, [NES_RAM + $CC]
            or $30
            ld l, $04
            call awf
            ld a, $7F
            ld l, $05
            call awf
            ld a, [NES_RAM + $CE]
            ld l, $06
            call awf
            ld a, [NES_RAM + $CF]
            and $0F
            ld l, $07
            call aw
            or $80
            ld [NES_RAM + $CF], a
            jr .s2d
.s2n:       ld a, [NES_RAM + $CC]
            or $30
            ld l, $04
            call awf
            ld a, $7F
            ld l, $05
            call awf
.s2d:       ld a, [NES_RAM + $DF]           ; triangle
            bit 7, a
            jr nz, .th
            ld a, $8F
            ld l, $08
            call awf
            ld a, [NES_RAM + $DE]
            ld l, $0A
            call awf
            ld a, [NES_RAM + $DF]
            ld l, $0B
            call aw
            ld a, $80
            ld [NES_RAM + $DF], a
            jr .td
.th:        cp $FF
            jr nz, .td
            ld a, $80
            ld l, $08
            call awf
.td:        ld a, $B0                       ; each channel: the note length, the score when
            ld [NES_RAM + $4D], a           ;   it ran out, the envelope
.ul:        ld a, [NES_RAM + $4D]
            ld e, a                         ; X = mu_chan
            add a, $05
            ld l, a
            ld h, high(NES_RAM)
            dec [hl]                        ; ch_lenctr
            jr nz, .es
            call mus_chs
            ld a, e
            add a, $04
            ld l, a
            ld h, high(NES_RAM)
            ld a, [hl]                      ; ch_envpos
            jr .uv
.es:        ld a, e
            add a, $0A
            ld l, a
            ld h, high(NES_RAM)
            ld a, [hl+]                     ; ch_envrate + ch_envrem
            add a, [hl]
            ld [hl], a
            cp 8
            jr c, .un
            ld [NES_RAM + $10], a           ; tmp
            and 7
            ld [hl], a
            ld a, [NES_RAM + $10]
            srl a
            srl a
            srl a
            ld b, a
            ld a, l
            sub $07                         ; (ch_envpos)
            ld l, a
            ld a, b
            add a, [hl]
.uv:        cp $20
            jr c, .u1
            ld a, $1F
.u1:        ld b, a
            ld a, e
            add a, $04
            ld l, a
            ld h, high(NES_RAM)
            ld [hl], b                      ; ch_envpos
            ld c, b                         ; Y
            dec l
            dec l
            ld a, [hl+]                     ; tmp = ch_envptr
            ld [NES_RAM + $10], a
            ld a, [hl]
            ld [NES_RAM + $11], a
            ld l, $10
            call mus_rd                     ; (tmp),Y
            ld b, a
            ld a, e
            add a, $0C
            ld l, a
            ld h, high(NES_RAM)
            ld [hl], b                      ; ch_vol
.un:        ld a, [NES_RAM + $4D]
            add a, $10
            ld [NES_RAM + $4D], a
            cp $E0
            jr c, .ul
            xor a                           ; out: A = $E0, X = $D0; N = 0, Z = 1, C = 1,
            ldh [nzv], a                    ;   V = 0 (CMP #$E0 after ADC #$10)
            ldh [vfl], a
            ld b, a
            ld d, a
            ld hl, $E090
            push hl
            pop af
            ret

; b13:B003 Music_NewSong (A = the track, its bit 6 on the first call)
mus_new:    cp $40
            jr c, .pr
            and $3F
            ld [NES_RAM + $4B], a
            xor a
            ld [NES_RAM + $4C], a
            ld [NES_RAM + $7E], a
            ld l, $02
            call awf
            ld l, $03
            call aw
            ld l, $06
            call awf
            ld l, $07
            call aw
            ld l, $0A
            call awf
            ld l, $0B
            call aw
            ld l, $0E
            call awf
            ld a, $30
            ld l, $00
            call awf
            ld l, $04
            call awf
            ld l, $08
            call awf
            ld l, $0C
            call awf
.pr:        ld a, [NES_RAM + $4B]           ; tmp = the track's pointer table + the primer
            dec a
            add a, a
            add a, a
            add a, a
            ld hl, NES_RAM + $4C
            or [hl]
            ld [NES_RAM + $10], a
            ld a, MUS_SCORE_HI
            ld [NES_RAM + $11], a
            ld a, [hl]                      ; X = primer: its channel (ROM table)
            ld e, a
            add a, low(MUS_P2C)
            ld l, a
            ld a, high(MUS_P2C)
            adc a, 0
            ld h, a
            call mrd
            ld [NES_RAM + $4D], a
            ld e, a                         ; X = the channel
            ld c, 0
            ld l, $10
            call mus_rd                     ; ch_scoreptr = (tmp)
            ld b, a
            ld l, e
            ld h, high(NES_RAM)
            ld [hl], b
            inc c
            ld l, $10
            call mus_rd
            ld b, a
            ld a, e
            inc a
            ld l, a
            ld h, high(NES_RAM)
            ld [hl], b
            call mus_chs
            ld a, [NES_RAM + $4C]
            add a, 2
            ld [NES_RAM + $4C], a
            cp 6
            jr c, .ex                       ; (not all three primed yet)
            xor a
            ld [NES_RAM + $4B], a
            ld [NES_RAM + $BD], a
            ld [NES_RAM + $CD], a
            ld [NES_RAM + $DD], a
            ld [NES_RAM + $ED], a
            ld a, $0F
            ld l, $15
            call aw
            xor a
            ld [NES_RAM + $7E], a
            ld l, $02
            call awf
            ld l, $03
            call aw
            ld l, $06
            call awf
            ld l, $07
            call aw
            ld l, $0A
            call awf
            ld l, $0B
            call aw
            ldh [nzv], a                    ; out: A = 0; N = 0, Z = 1, C = 1 (CMP #6), V = 0
            ldh [vfl], a
            ld b, a
            ld d, a
            ld hl, $0090
            push hl
            pop af
            ret
.ex:        ld h, a                         ; out: A = primer (2 or 4); N = 1, Z = 0, C = 0
            ld a, $80
            ldh [nzv], a
            xor a
            ldh [vfl], a
            ld b, a
            ld d, a
            ld l, a
            push hl
            pop af
            ret

; A = byte at (zp L) + Y (C) in the song bank; keeps BC, DE
mus_rd:     ld h, high(NES_RAM)
            ld a, [hl+]
            ld h, [hl]
            add a, c
            ld l, a
            jr nc, .n
            inc h
.n:         jp mrd

; L = APU register (not a restart, not $4015), A = value: nothing when the register holds it
; already (apu_write would do nothing either), else aw. Keeps A, BC, DE, HL.
awf:        push hl
            set 6, l                        ; (APU_SH = $D840)
            ld h, high(APU_SH)
            cp [hl]
            pop hl
            ret z
; L = APU register, A = value: apu_write (keeps A, BC, DE)
aw:         push af
            push bc
            push de
            ld e, a
            call apu_write
            pop de
            pop bc
            pop af
            ret

; b13:B189 Music_ChannelScore (X = E): mu_scoreptr = ch_scoreptr, then the score
mus_chs:    ld l, e
            ld h, high(NES_RAM)
            ld a, [hl+]
            ld [NES_RAM + $18], a
            ld a, [hl]
            ld [NES_RAM + $19], a
mus_ds:     ld c, 0                         ; b13:B1A3 Music_DoScore
            ld l, $18
            call mus_rd
            cp $C0
            jr nc, .c0
            call mus_note
.done:      ld l, e                         ; ch_scoreptr + 1
            ld h, high(NES_RAM)
            inc [hl]
            ret nz
            inc l
            inc [hl]
            ret
.c0:        cp $D0
            jr nc, .d0
            call mus_rest
            jr .done
.d0:        cp $D8
            jr nc, .d8
            call mus_loop
            jr mus_ds
.d8:        cp $E0
            jr nc, .e0
            call mus_oct
            ld a, 1
            jr mus_inc
.e0:        cp $F0
            jr nc, .f0
            call mus_env
            ld a, 1
            jr mus_inc
.f0:        cp $FF
            jr nz, .fe
            ld a, $80                       ; end of the song
            ld [NES_RAM + $4B], a
            ret
.fe:        cp $F8
            jr nz, .fx
            ld c, 1                         ; envelope speed (ROM table)
            ld l, $18
            call mus_rd
            and $0F
            ld c, a
            add a, low(MUS_ENVSPD)
            ld l, a
            ld a, high(MUS_ENVSPD)
            adc a, 0
            ld h, a
            call mrd
            ld b, a
            ld a, e
            add a, $0A
            ld l, a
            ld h, high(NES_RAM)
            ld [hl], b                      ; ch_envrate
            ld a, 2
            jr mus_inc
.fx:        cp $F9
            jr c, .f7
            call mus_tempo
.f7:        ld a, 1
mus_inc:    ld b, a                         ; b13:B194: ch_scoreptr += A, mu_scoreptr = it
            ld l, e
            ld h, high(NES_RAM)
            ld a, [hl]
            add a, b
            ld [hl+], a
            ld [NES_RAM + $18], a
            ld a, [hl]
            adc a, 0
            ld [hl], a
            ld [NES_RAM + $19], a
            jr mus_ds

; b13:B217 Music_LoopCode (A = the code)
mus_loop:   and $0F
            ld [NES_RAM + $10], a           ; tmp
            ld a, e
            add a, $0D
            ld l, a
            ld h, high(NES_RAM)
            ld a, [hl]                      ; ch_loopctr
            and a
            jr z, .st
            dec [hl]
            jr nz, .rs
            ld l, e                         ; loop over: past its 3 bytes
            ld a, [hl]
            add a, 3
            ld [hl+], a
            ld [NES_RAM + $18], a
            ld a, [hl]
            adc a, 0
            ld [hl], a
            ld [NES_RAM + $19], a
            ret
.st:        ld a, [NES_RAM + $10]
            ld [hl], a
.rs:        ld c, 1                         ; back to the loop's address
            ld l, $18
            call mus_rd
            ld b, a
            ld l, e
            ld h, high(NES_RAM)
            ld [hl], b
            ld a, b
            ld [NES_RAM + $10], a
            inc c
            ld l, $18
            call mus_rd
            ld b, a
            ld a, e
            inc a
            ld l, a
            ld h, high(NES_RAM)
            ld [hl], b
            ld a, b
            ld [NES_RAM + $19], a
            ld a, [NES_RAM + $10]
            ld [NES_RAM + $18], a
            ret

; b13:B250 Music_Note
mus_note:   ld [NES_RAM + $1E], a           ; tmp+14
            call mus_tone
            ld a, [NES_RAM + $1E]
            jr mus_len

; b13:B25A Music_Rest
mus_rest:   call mus_lenr
            ld a, [NES_RAM + $4D]
            cp $D0
            ret nz
            ld a, $FF
            ld [NES_RAM + $DF], a
            ret

; b13:B268 Music_ApplyTone
mus_tone:   ld b, a
            ld a, e
            cp $E0
            ld a, b
            jr nz, .nn
            swap a
            and $0F
            add a, 4
            ld b, a
            ld a, e
            add a, $0E
            ld l, a
            ld h, high(NES_RAM)
            ld [hl], b
            inc l
            ld [hl], 0
            ret
.nn:        srl a
            srl a
            srl a
            and $1E
            ld c, a                         ; Y
            ld a, e
            add a, $06
            call mus_tp                     ; tmp = ch_frqtblptr
            ld l, $10
            call mus_rd
            ld b, a
            ld a, e
            add a, $0E
            ld l, a
            ld h, high(NES_RAM)
            ld [hl], b                      ; ch_freq
            inc c
            ld l, $10
            call mus_rd
            ld b, a
            ld a, e
            add a, $0F
            ld l, a
            ld h, high(NES_RAM)
            ld [hl], b
            ret

; A = a channel field offset (X + field): tmp = that pointer
mus_tp:     ld l, a
            ld h, high(NES_RAM)
            ld a, [hl+]
            ld [NES_RAM + $10], a
            ld a, [hl]
            ld [NES_RAM + $11], a
            ret

; b13:B292 Music_ApplyLength (note): length, envelope back to its start
mus_len:    call mus_lenr
            ld h, high(NES_RAM)             ; ch_envpos, ch_envrem = 0
            ld a, e
            add a, $04
            ld l, a
            xor a
            ld [hl], a
            ld a, e
            add a, $0B
            ld l, a
            xor a
            ld [hl], a
            ret

; b13:B2A8 Music_ApplyLength_Rest: ch_lenctr = (ch_lentblptr),Y (Y = A & 15)
mus_lenr:   and $0F
            ld c, a
            ld a, e
            add a, $08
            call mus_tp
            ld l, $10
            call mus_rd
            ld b, a
            ld a, e
            add a, $05
            ld l, a
            ld h, high(NES_RAM)
            ld [hl], b
            ret

; b13:B2B8 Music_SetTempo
mus_tempo:  sub 9
            and $0F
            swap a
            add a, low(MUS_LENS)
            ld b, a
            ld a, high(MUS_LENS)
            adc a, 0
            ld h, a
            ld a, e
            add a, $08
            ld l, a
            ld a, h
            ld h, high(NES_RAM)
            ld [hl], b
            inc l
            ld [hl], a
            ret

; b13:B2CD Music_SetOctave
mus_oct:    and 7
            ld c, a                         ; Y
            add a, low(MUS_OCT)
            ld l, a
            ld a, high(MUS_OCT)
            adc a, 0
            ld h, a
            call mrd
            add a, low(MUS_FREQS)
            ld b, a
            ld a, high(MUS_FREQS)
            adc a, 0
            ld h, a
            ld a, e
            add a, $06
            ld l, a
            ld a, h
            ld h, high(NES_RAM)
            ld [hl], b
            inc l
            ld [hl], a
            ret

; b13:B2DF Music_SetEnvPattern: ch_envptr = patterns + A * 32 (tmp+15 = Y, then the carry)
mus_env:    ld b, a
            ld a, c
            ld [NES_RAM + $1F], a
            ld a, b
            add a, a
            add a, a
            add a, a
            add a, a
            add a, a
            ld hl, NES_RAM + $1F
            rl [hl]
            adc a, low(MUS_ENVPAT)
            ld b, a
            ld a, [hl]
            ld d, a
            ld a, high(MUS_ENVPAT)
            adc a, d
            ld d, 0
            ld h, a
            ld a, e
            add a, $02
            ld l, a
            ld a, h
            ld h, high(NES_RAM)
            ld [hl], b
            inc l
            ld [hl], a
            ret
