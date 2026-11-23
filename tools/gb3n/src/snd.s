; ---- sound: FF3's sound driver (bank $36: 8003 update, 8925 music, 8B9D effects) written for the
; GB, run from the V-Blank interrupt (60 Hz as FF3's frame). Its variables keep FF3's layout
; ($7F40-$7FFF -> $CC40-$CCFF: SV(x) = FF3 address - $B300) and the song data are read from the
; four sound banks (build.py: FF3's bank $36 at $4000 + a song bank at $6000, so a NES address
; $8000-$BFFF is GB $4000-$7FFF). The NES APU writes become GB channel updates (snd_out): pulse 1
; / 2 -> CH1 / CH2, triangle -> CH3 (a triangle wave), noise -> CH4; periods converted by a table
; (SND_TAB), volume changes retrigger the channel.
SD0        = $CC30              ; FF3 $D0 channel, $D1 type, $D2 effect flag, $D3/$D4 pointer,
SD1        = $CC31              ;   $D5 command, $D6-$D9 temporaries
SD2        = $CC32
SD3        = $CC33
SD4        = $CC34
SD5        = $CC35
SD6        = $CC36
SD7        = $CC37
SD8        = $CC38
SD9        = $CC39
S40        = $CC40              ; $7F40 song playing (bit 7: enable roll)
S41        = $CC41              ; $7F41 song to resume
S42        = $CC42              ; $7F42 music flags
S43        = $CC43              ; $7F43 song id
S44        = $CC44              ; $7F44 song volume
S45        = $CC45              ; $7F45 tempo
S46        = $CC46              ; $7F46/47 tempo counter
S48        = $CC48              ; $7F48 fade counter
S49        = $CC49              ; $7F49 sound effect
SFL        = $CC4A              ; $7F4A + x channel flags (0-4 music, 5-6 effects)
SN_SPL        = $CC51              ; $7F51 + x script pointer lo
SPH        = $CC58              ; $7F58 + x script pointer hi
STK        = $CC5F              ; $7F5F + x tick counter
SOC        = $CC66              ; $7F66 octave
SFR        = $CC6D              ; $7F6D frequency lo (noise: period)
SFH        = $CC74              ; $7F74 frequency hi
SVO        = $CC7B              ; $7F7B volume (output)
SSW        = $CC82              ; $7F82 sweep
SDU        = $CC89              ; $7F89 duty
SCV        = $CC90              ; $7F90 channel volume
SDL        = $CC97              ; $7F97 decay counter lo
SDH        = $CC9E              ; $7F9E decay counter hi
SRD        = $CCA5              ; $7FA5 repeat depth
SR0        = $CCAC              ; $7FAC repeat count 0
SR1        = $CCB3              ; $7FB3 repeat count 1
SES        = $CCBA              ; $7FBA envelope state
SVE        = $CCC1              ; $7FC1 volume envelope id
SEO        = $CCC8              ; $7FC8 envelope data offset
SEC        = $CCCF              ; $7FCF envelope step counter
SER        = $CCD6              ; $7FD6 envelope rate
SEA        = $CCDD              ; $7FDD envelope accumulator
SEV        = $CCE4              ; $7FE4 envelope value
SPE        = $CCEB              ; $7FEB pitch envelope id
SPO        = $CCF2              ; $7FF2 pitch envelope offset
SPC        = $CCF9              ; $7FF9 pitch envelope counter

; HL = array A + channel (SD0) (the arrays are in page $CC)
six:        push bc
            ld b, a
            ld a, [SD0]
            add a, b
            ld l, a
            ld h, $CC
            pop bc
            ret

; V-Blank: one frame of FF3's 8003 (the sound bank of the song selected; the bank restored)
snd_frame:  ld a, [snd_on]
            and a
            ret z
            ld a, [snd_bank]
            ld [MBC5_BANKL], a
            ld a, [S43]                     ; (song $37: no effects)
            cp $37
            jr nz, .fx
            xor a
            ld [S49], a
            jr .mu
.fx:        call sfx_update
.mu:        call mus_update
            call snd_out
            ld a, [S42]                     ; bit 7 of $7F42 into bit 7 of $7F40
            and $80
            ld b, a
            ld a, [S40]
            and $7F
            or b
            ld [S40], a
            ld a, [rom_bank]
            ld [MBC5_BANKL], a
            ret

; play song A (FF3: $7F43 = A, $7F42 = 1; the driver takes the song's bank when it starts it)
snd_song:   ld [S43], a
            ld a, 1
            ld [S42], a
            ret

; 3B/B71A event command $F8: A = $00-$7C song, $7D fade out, $7E resume the song before, $7F
; stop, $80-$FF sound effect
snd_f8:     bit 7, a
            jr nz, .fx
            cp $7D
            jr c, snd_song
            jr z, .fade
            cp $7E
            ld a, 2
            jr z, .w
            ld a, 4
.w:         ld [S42], a
            ret
.fade:      ld a, $37
            ld [S43], a
            ld a, $0C
            jr .w
.fx:        ld [S49], a
            ret

; 3B/A006 the world map's song: (world - 1, world 0 as 1) * 8 + vehicle -> song, sound effect
; (3B/A027 / A047, copied to GAME_BANK $7840 / $7880 by build.py)
snd_world:  ld a, [cur_world]
            and a
            jr z, .w
            dec a
.w:         add a, a
            add a, a
            add a, a
            ld l, a
            ld a, [GS + $0F]                ; (FF3's $46 vehicle: on foot until the vehicles are in)
            and 7
            add a, l
            ld l, a
            ld h, $78
            ld a, l
            add a, $40
            ld l, a
            push hl
            ld a, GAME_BANK
            call rd_byte
            call snd_song
            pop hl
            ld a, l
            add a, $40
            ld l, a
            ld a, GAME_BANK
            call rd_byte
            or $80
            ld [S49], a
            ret
; the sound bank of song $7F43 (8999: $00-$18, $19-$2A, $2B-$3A, $3B-)
snd_selbank: ld a, [S43]
            ld b, SND_BANK0
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
            ld [snd_bank], a
            ret

; ---- 8925 update music
mus_update: ld a, [S42]
            ld c, a
            bit 0, a
            jr z, .nn
            ld a, [S40]                     ; a new song
            bit 7, a
            jr z, .start
            and $7F
            ld b, a
            ld a, [S43]
            cp b
            jr z, .same
            cp $37
            jr nz, .start
            ld a, b
            ld [S43], a
            call snd_selbank
            ld a, [snd_bank]
            ld [MBC5_BANKL], a
            jr .same
.start:     ld a, [S40]
            ld [S41], a
            ld a, [S43]
            ld [S40], a
            call snd_selbank
            ld a, [snd_bank]
            ld [MBC5_BANKL], a
            jp song_init
.same:      ld a, $80
            ld [S42], a
            jp mus_chans
.nn:        bit 1, c                        ; resume
            jr z, .ns
            ld a, [S41]
            ld [S40], a
            ld [S43], a
            ld a, 1
            ld [S42], a
            call snd_selbank
            ld a, [snd_bank]
            ld [MBC5_BANKL], a
            jp song_init
.ns:        bit 2, c                        ; stop
            call nz, mus_stopvol
            ld a, [S42]
            bit 5, a
            jr z, .fo
            call fade_in
            jr .ch
.fo:        bit 6, a
            call nz, fade_out
.ch:        ld a, [S42]
            bit 7, a
            ret z
            jp mus_chans

; 89C3 init song
song_init:  call mus_silence
            ld e, 4
.c:         ld d, 0
            ld hl, SFL
            call .z
            ld hl, STK
            call .z
            ld hl, SVO
            call .z
            ld d, 8
            ld hl, SSW
            call .z
            ld d, $30
            ld hl, SDU
            call .z
            ld d, $0F
            ld hl, SCV
            call .z
            ld d, $FF
            ld hl, SVE
            call .z
            ld hl, SPE
            call .z
            ld hl, SRD
            call .z
            ld hl, SES
            call .z
            dec e
            ld a, e
            cp $FF
            jr nz, .c
            ld a, $96
            ld [S45], a
            xor a
            ld [S46], a
            ld [S46 + 1], a
            ld a, [S43]                     ; the song's pointer table (NES addresses)
            cp $19
            jr c, .t0
            cp $2B
            jr nc, .t1
            sub $19
.t0:        add a, a
            ld l, a
            ld h, $60                       ; ($A000 -> GB $6000)
            jr .tp
.t1:        cp $37
            jr nc, .t2
            sub $2B
            add a, a
            add a, low($8C77 - $4000)
            ld l, a
            ld a, high($8C77 - $4000)
            adc a, 0
            ld h, a
            jr .tp
.t2:        cp $3B
            jr nc, .t3
            sub $37
            add a, a
            add a, low($B3AE - $4000)
            ld l, a
            ld a, high($B3AE - $4000)
            adc a, 0
            ld h, a
            jr .tp
.t3:        sub $3B
            add a, a
            add a, low($B400 - $4000)
            ld l, a
            ld a, high($B400 - $4000)
            adc a, 0
            ld h, a
.tp:        ld a, [hl+]                     ; -> the song header (NES address)
            ld h, [hl]
            ld l, a
            call nes2gb
            ld de, SN_SPL                      ; 5 channel pointers
            ld b, 5
.p:         ld a, [hl+]
            ld [de], a
            ld a, e
            add a, 7
            ld e, a
            ld a, [hl+]
            ld [de], a
            ld a, e
            sub 6
            ld e, a
            dec b
            jr nz, .p
            ld e, 4                         ; enabled unless $FFFF
.en:        ld a, e
            add a, low(SN_SPL)
            ld l, a
            ld h, $CC
            ld a, [hl]
            ld b, a
            ld a, l
            add a, 7
            ld l, a
            ld a, [hl]
            and b
            inc a
            jr z, .dis
            ld a, e
            add a, low(SFL)
            ld l, a
            set 7, [hl]
.dis:       dec e
            ld a, e
            cp $FF
            jr nz, .en
            ld a, [S42]                     ; 8A87 start volume (fade in if bit 3)
            bit 3, a
            jr nz, .fin
            ld a, $80
            ld [S42], a
            ld a, $0F
            ld [S44], a
            ret
.fin:       ld a, $A0
            ld [S42], a
            xor a
            ld [S44], a
            ld [S48], a
            ret
.z:         ld a, l
            add a, e
            ld l, a
            ld [hl], d
            ret
; HL: a NES address $8000-$BFFF -> the GB address in the sound bank
nes2gb:     ld a, h
            sub $40
            ld h, a
            ret

; 8AA7 stop
mus_stopvol: ld a, [S42]
            bit 3, a
            jr nz, .f
            ld [S42], a
            jp mus_silence
.f:         ld a, $C0
            ld [S42], a
            xor a
            ld [S48], a
            ret
; 8AC0 silence the music channels (unless an effect holds pulse 2 / noise)
mus_silence: ld a, [SFL]
            bit 7, a
            call nz, .p1
            ld a, [SFL + 1]
            bit 7, a
            jr z, .t
            ld a, [SFL + 5]
            bit 7, a
            call z, .p2
.t:         ld a, [SFL + 2]
            bit 7, a
            call nz, .tr
            ld a, [SFL + 3]
            bit 7, a
            ret z
            ld a, [SFL + 6]
            bit 7, a
            ret nz
            jp apu_noise_off
.p1:        jp apu_p1_off
.p2:        jp apu_p2_off
.tr:        jp apu_tri_off
fade_in:    ld a, [S48]
            and a
            jr nz, .d
            ld hl, S44
            inc [hl]
            ld a, [hl]
            cp $0F
            jr c, .r
            ld a, [S42]
            and $DF
            ld [S42], a
            ret
.r:         ld a, $10
            ld [S48], a
.d:         ld hl, S48
            dec [hl]
            ret
fade_out:   ld a, [S48]
            and a
            jr nz, .d
            ld hl, S44
            dec [hl]
            jr nz, .r
            xor a
            ld [S42], a
            jp mus_silence
.r:         ld a, $10
            ld [S48], a
.d:         ld hl, S48
            dec [hl]
            ret

; 8B2D the music channels: tempo ticks, then the envelopes
mus_chans:  xor a
            ld [SD2], a
            ld a, [S45]
            ld b, a
            ld a, [S46]
            add a, b
            ld [S46], a
            jr nc, .t
            ld hl, S46 + 1
            inc [hl]
.t:         ld a, [S46]                     ; a tick while the counter >= 150
            sub $96
            ld c, a
            ld a, [S46 + 1]
            sbc 0
            jr c, .env
            ld [S46 + 1], a
            ld a, c
            ld [S46], a
            ld a, 4                         ; channel 4 / type 0 (dmc) .. 0 / 4 (pulse 1)
            ld [SD0], a
            xor a
            ld [SD1], a
.ch:        call chan_script
            ld a, [SD0]
            and a
            jr z, .t
            dec a
            ld [SD0], a
            ld a, [SD1]
            inc a
            ld [SD1], a
            jr .ch
.env:       xor a
            ld [SD0], a
.e:         call chan_env
            ld a, [SD0]
            inc a
            ld [SD0], a
            cp 4
            jr nz, .e
            ret

; 81E6 update channel script
chan_script: ld a, low(SFL)
            call six
            bit 7, [hl]
            ret z
            ld a, low(STK)
            call six
            ld a, [hl]
            and a
            call z, snd_cmd
            ld a, low(STK)
            call six
            dec [hl]
            ld a, low(SDL)
            call six
            ld a, [hl]
            and a
            jr nz, .d
            ld a, low(SDH)
            call six
            ld a, [hl]
            and a
            ret z
            dec [hl]
.d:         ld a, low(SDL)
            call six
            dec [hl]
            ret

; 820B execute sound commands until a note
snd_cmd:    ld a, low(SN_SPL)
            call six
            ld a, [hl]
            ld [SD3], a
            ld a, l
            add a, 7
            ld l, a
            ld a, [hl]
            ld [SD4], a
            ld bc, 0                        ; (C = FF3's Y: the offset)
cmd_next:   call cmd_byte
            cp $E0
            jp c, cmd_note
            ld [scmd], a
            sub $E0
            add a, a
            ld l, a
            ld h, 0
            ld de, cmd_tab
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            jp hl
cmd_tab:    dw c_tempo, c_vol, c_vol, c_vol, c_vol, c_vol, c_vol, c_vol    ; E0-E7
            dw c_vol, c_vol, c_vol, c_vol, c_vol, c_vol, c_vol, c_oct      ; E8-EF
            dw c_oct, c_oct, c_oct, c_oct, c_oct, c_env, c_env, c_env      ; F0-F7
            dw c_sweep, c_hihat, c_snare, c_rep, c_rend, c_volta, c_jump, c_end
; the byte at the pointer + C (C + 1)
cmd_byte:   ld a, [SD3]
            ld l, a
            ld a, [SD4]
            ld h, a
            ld b, 0
            add hl, bc
            call nes2gb
            ld a, [hl]
            inc c
            ret

c_tempo:    call cmd_byte                   ; E0
            ld [S45], a
            jr cmd_next
c_vol:      ld a, [scmd]                    ; E1-EE: volume 2-15
            sub $E1 - 2
            push af
            ld a, low(SCV)
            call six
            pop af
            ld [hl], a
            jr cmd_next
c_oct:      ld a, [scmd]                    ; EF-F4: octave 0-5
            sub $EF
            push af
            ld a, low(SOC)
            call six
            pop af
            ld [hl], a
            jr cmd_next
c_env:      ld a, [scmd]                    ; F5 / F6 / F7: duty $30 / $70 / $B0, then the
            sub $F5                         ;   volume and pitch envelope ids
            rrca
            rrca                            ; (0 / $40 / $80)
            or $30
            push af
            ld a, low(SDU)
            call six
            pop af
            ld [hl], a
            call cmd_byte
            push af
            ld a, low(SVE)
            call six
            pop af
            ld [hl], a
            call cmd_byte
            push af
            ld a, low(SPE)
            call six
            pop af
            ld [hl], a
            jp cmd_next
c_sweep:    call cmd_byte                   ; F8
            push af
            ld a, low(SSW)
            call six
            pop af
            ld [hl], a
            jp cmd_next
c_hihat:    ld d, 4                         ; F9: octave 4, envelope 0, volume 8
            ld e, 0
            ld a, 8
            jr c_drum
c_snare:    ld d, 5                         ; FA: octave 5, envelope 1, volume 15
            ld e, 1
            ld a, $0F
c_drum:     push af
            ld a, low(SOC)
            call six
            ld [hl], d
            ld a, low(SVE)
            call six
            ld [hl], e
            ld a, low(SCV)
            call six
            pop af
            ld [hl], a
            jp cmd_next
c_rep:      call cmd_byte                   ; FB n: repeat start
            ld d, a
            ld a, low(SRD)
            call six
            inc [hl]
            ld a, [hl]
            and a
            ld a, low(SR0)
            jr z, .s
            ld a, low(SR1)
.s:         call six
            ld [hl], d
            jp cmd_next
c_rend:     ld a, low(SRD)                  ; FC: repeat end
            call six
            ld a, [hl]
            and a
            ld a, low(SR0)
            jr z, .s
            ld a, low(SR1)
.s:         call six
            dec [hl]
            jr nz, c_jump
            inc c
            inc c
            ld a, low(SRD)
            call six
            dec [hl]
            jp cmd_next
c_volta:    ld a, low(SRD)                  ; FD: volta (odd count: jump)
            call six
            ld a, [hl]
            and a
            ld a, low(SR0)
            jr z, .s
            ld a, low(SR1)
.s:         call six
            bit 0, [hl]
            jr nz, .j
            inc c
            inc c
            jp cmd_next
.j:         ld a, low(SRD)
            call six
            dec [hl]
c_jump:     call cmd_byte                   ; FE: jump
            ld e, a
            call cmd_byte
            ld [SD4], a
            ld a, e
            ld [SD3], a
            ld c, 0
            jp cmd_next
c_end:      ld a, low(SFL)                  ; FF: the channel off
            call six
            res 7, [hl]
            ld a, [SD1]
            and a
            jr z, .cl
            cp 3
            jr z, .p2
            cp 2
            jr z, .tr
            cp 1
            jr z, .no
            call apu_p1_off
            jr .cl
.p2:        ld a, [SD2]
            and a
            jr z, .p2m
            ld hl, SFL + 1
            set 1, [hl]
            jr .p2o
.p2m:       ld a, [SFL + 5]
            bit 7, a
            jr nz, .cl
.p2o:       call apu_p2_off
            jr .cl
.tr:        call apu_tri_off
            jr .cl
.no:        ld a, [SD2]
            and a
            jr z, .nm
            ld hl, SFL + 3
            set 1, [hl]
            jr .noo
.nm:        ld a, [SFL + 6]
            bit 7, a
            jr nz, .cl
.noo:       call apu_noise_off
.cl:        ld a, [SD2]
            and a
            jr nz, .fx
            ld hl, SFL                      ; any music channel left?
            ld b, 5
.m:         bit 7, [hl]
            ret nz
            inc l
            dec b
            jr nz, .m
            xor a
            ld [S42], a
            ret
.fx:        ld a, [SFL + 5]
            bit 7, a
            ret nz
            ld a, [SFL + 6]
            bit 7, a
            ret nz
            xor a
            ld [S49], a
            ret

; 826F a note / rest / tie (A = the byte)
cmd_note:   ld [SD5], a
            ld a, [SD3]                     ; the pointer past it
            add a, c
            ld [SD3], a
            ld e, a
            ld a, [SD4]
            adc a, 0
            ld [SD4], a
            ld d, a
            ld a, low(SN_SPL)
            call six
            ld [hl], e
            ld a, l
            add a, 7
            ld l, a
            ld [hl], d
            ld a, [SD5]                     ; duration (8805 table)
            and $0F
            ld e, a
            ld d, 0
            ld hl, $8805 - $4000
            add hl, de
            ld b, [hl]
            ld a, low(STK)
            call six
            ld [hl], b
            ld a, [SD5]
            cp $D0
            ret nc                          ; (tie)
            cp $C0
            jr nc, .rest
            ld a, low(SFL)                  ; key on
            call six
            ld a, [hl]
            or 1
            and $FD
            ld [hl], a
            xor a
            ld b, a
            ld a, low(SES)
            call six
            ld [hl], b
            ld a, low(SEO)
            call six
            ld [hl], b
            ld a, low(SEA)
            call six
            ld [hl], b
            ld a, low(SPC)
            call six
            ld [hl], b
            ld a, low(SPO)
            call six
            ld [hl], b
            ld a, [SD1]
            and a
            ret z                           ; (dmc: FF3 only pops; nothing here)
            cp 2
            jr z, .pitch
            call decay_init
            ld a, [SD1]
            cp 1
            jr z, .noise
.pitch:     call note_index                 ; frequency table 872D
            add a, a
            ld e, a
            ld d, 0
            ld hl, $872D - $4000
            add hl, de
            ld a, [hl+]
            ld b, [hl]
            push bc
            push af
            ld a, low(SFR)
            call six
            pop af
            ld [hl], a
            ld a, low(SFH)
            call six
            pop bc
            ld [hl], b
            ret
.noise:     call note_index                 ; noise table 87BD
            ld e, a
            ld d, 0
            ld hl, $87BD - $4000
            add hl, de
            ld b, [hl]
            ld a, low(SFR)
            call six
            ld [hl], b
            ret
.rest:      ld a, low(SFL)
            call six
            set 1, [hl]
            ret
; pitch (high nibble) + octave * 12
note_index: ld a, low(SOC)
            call six
            ld a, [hl]
            add a, a
            add a, a
            ld b, a
            add a, a
            add a, b
            ld b, a
            ld a, [SD5]
            swap a
            and $0F
            add a, b
            ret
; 831D decay counter: the note's decay duration + the ties after it
decay_init: ld a, [SD5]
            and $0F
            ld e, a
            ld d, 0
            ld hl, $8815 - $4000
            add hl, de
            ld a, [hl]
            ld [SD8], a
            xor a
            ld [SD9], a
            ld c, 0
.t:         ld a, [SD3]
            ld l, a
            ld a, [SD4]
            ld h, a
            ld b, 0
            add hl, bc
            call nes2gb
            ld a, [hl]
            inc c
            cp $D0
            jr c, .d
            cp $E0
            jr nc, .d
            and $0F
            ld e, a
            ld d, 0
            ld hl, $8815 - $4000
            add hl, de
            ld a, [SD8]
            add a, [hl]
            ld [SD8], a
            jr nc, .t
            ld hl, SD9
            inc [hl]
            jr .t
.d:         ld a, [SD8]
            ld b, a
            ld a, low(SDL)
            call six
            ld [hl], b
            ld a, [SD9]
            ld b, a
            ld a, low(SDH)
            call six
            ld [hl], b
            ret

; 857D channel envelopes
chan_env:   ld a, low(SFL)
            call six
            ld a, [hl]
            bit 7, a
            ret z
            bit 1, a
            jr nz, .off
            call vol_env
            jp pitch_env
.off:       ld a, low(SVO)
            call six
            ld [hl], 0
            ret

; 8595 volume envelope
vol_env:    ld a, low(SES)
            call six
            ld a, [hl]
            cp 3
            jp nc, .zero
            cp 1
            jr nz, .go
            ld a, low(SDL)                  ; decay over: release
            call six
            ld a, [hl]
            and a
            jr nz, .go
            ld a, low(SDH)
            call six
            ld a, [hl]
            and a
            jr nz, .go
            ld a, low(SES)
            call six
            inc [hl]
            ld a, low(SEO)
            call six
            ld [hl], 0
.go:        ld a, low(SVE)
            call six
            ld a, [hl]
            bit 7, a
            jr nz, .none
            add a, a                        ; the envelope's data (9A7C pointers)
            ld e, a
            ld d, 0
            ld hl, $9A7C - $4000
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            call nes2gb
            push hl
            ld a, low(SES)
            call six
            ld a, [hl]
            add a, a
            pop hl
            ld e, a
            ld d, 0
            add hl, de
            ld a, [hl+]
            ld [SD8], a
            ld a, [hl]
            ld [SD9], a
            ld a, low(SES)
            call six
            ld a, [hl]
            and a
            jp z, env_attack
            jp env_decay
.none:      ld a, [S44]                     ; (no envelope: full if the song volume >= 5)
            cp 5
            jr c, .zero
            ld a, low(SVO)
            call six
            ld [hl], $FF
            ret
.zero:      ld a, low(SVO)
            call six
            ld [hl], 0
            ret

; envelope data pointer (SD8 / SD9, NES) + A -> HL (GB)
envp:       ld e, a
            ld d, 0
            ld a, [SD8]
            ld l, a
            ld a, [SD9]
            ld h, a
            add hl, de
            jp nes2gb

; 85FA attack
env_attack: ld a, low(SEO)
            call six
            ld a, [hl]
            push af
            call envp
            ld a, [hl+]
            ld b, a
            ld a, [hl]
            ld c, a                         ; (the next byte)
            push bc
            ld a, low(SEV)
            call six
            pop bc
            ld [hl], b
            push bc
            ld a, low(SEO)
            call six
            inc [hl]
            pop bc
            pop af
            bit 7, c
            jr z, vol_out
            ld a, low(SES)
            call six
            inc [hl]
            ld a, low(SEO)
            call six
            ld [hl], 0
; (8614 / 86B5) the output volume: 8825[channel volume * 16 + envelope value], then (music)
; 8825[song volume * 16 + that]
vol_out:    ld a, low(SEV)
            call six
            ld b, [hl]
vol_outb:   ld a, low(SCV)
            call six
            ld a, [hl]
            swap a
            or b
            ld e, a
            ld d, 0
            ld a, [SD2]
            and a
            jr nz, .t
            ld hl, $8825 - $4000
            add hl, de
            ld a, [S44]
            swap a
            or [hl]
            ld e, a
.t:         ld hl, $8825 - $4000
            add hl, de
            ld b, [hl]
            ld a, low(SVO)
            call six
            ld [hl], b
            ret

; 8635 decay / release
env_decay:  ld a, low(SEV)
            call six
            ld a, [hl]
            and a
            jp z, .kill
            ld a, low(SEO)
            call six
            ld a, [hl]
            and a
            jr nz, .acc
            call envp                       ; the rate (first byte)
            ld b, [hl]
            ld a, low(SER)
            call six
            ld [hl], b
            ld a, low(SEO)
            call six
            inc [hl]
            ld a, low(SEC)
            call six
            ld [hl], 0
.acc:       ld a, low(SER)
            call six
            ld b, [hl]
            ld a, low(SEA)
            call six
            ld a, [hl]
            add a, b
            ld [hl], a
            cp $64
            jr c, .v
            sub $64
            ld [hl], a
            ld a, low(SEV)
            call six
            dec [hl]
            jr z, .kill
.v:         ld a, low(SEV)                  ; 8670: the change in volume
            call six
            ld a, [hl]
            ld [SD5], a
            ld a, low(SEC)
            call six
            ld a, [hl]
            and a
            jr nz, .step
            ld a, low(SEO)
            call six
            ld a, [hl]
            push af
            call envp
            ld a, [hl]
            ld b, a
            pop af
            ld c, a                         ; C = the offset
            ld a, b
            and a
            jr z, .out                      ; (terminated)
            bit 7, a
            jr z, .cnt
            add a, c                        ; (back: "subtract" from the offset)
            ld c, a
            push bc
            call envp
            pop bc
            ld a, [hl]
.cnt:       push bc
            push af
            ld a, low(SEC)
            call six
            pop af
            ld [hl], a
            pop bc
            inc c
            inc c
            push bc
            ld a, low(SEO)
            call six
            pop bc
            ld [hl], c
.step:      ld a, low(SEO)                  ; (8693: data[offset - 1])
            call six
            ld a, [hl]
            dec a
            call envp
            ld a, [hl]
            ld b, a
            ld a, [SD5]
            bit 7, b
            jr nz, .neg
            add a, b
            cp $10
            jr c, .sv
            ld a, $0F
            jr .sv
.neg:       add a, b
            jr c, .sv
            xor a
.sv:        ld [SD5], a
            ld a, low(SEC)
            call six
            dec [hl]
.out:       ld a, [SD5]
            ld b, a
            jp vol_outb
.kill:      ld a, low(SES)                  ; key off
            call six
            ld [hl], 3
            ld a, low(SVO)
            call six
            ld [hl], 0
            ret

; 86D5 pitch envelope (the frequency's low byte, clamped)
pitch_env:  ld a, low(SPE)
            call six
            ld a, [hl]
            bit 7, a
            ret nz
            add a, a
            ld e, a
            ld d, 0
            ld hl, $9EAB - $4000
            add hl, de
            ld a, [hl+]
            ld [SD8], a
            ld a, [hl]
            ld [SD9], a
            ld a, low(SPC)
            call six
            ld a, [hl]
            and a
            jr nz, .dec
            ld a, low(SPO)
            call six
            ld a, [hl]
            ld c, a
            call envp
            ld a, [hl]
            and a
            ret z
            bit 7, a
            jr z, .set
            add a, c
            ld c, a
            push bc
            call envp
            pop bc
            ld a, [hl]
.set:       push bc
            push af
            ld a, low(SPC)
            call six
            pop af
            ld [hl], a
            pop bc
            inc c
            inc c
            push bc
            ld a, low(SPO)
            call six
            pop bc
            ld [hl], c
            ld a, c
            dec a
            call envp
            ld b, [hl]
            ld a, low(SFR)
            call six
            ld a, [hl]
            bit 7, b
            jr nz, .n
            add a, b
            jr nc, .s
            ld a, $FF
            jr .s
.n:         add a, b
            jr c, .s
            xor a
.s:         ld [hl], a
.dec:       ld a, low(SPC)
            call six
            dec [hl]
            ret

; ---- 8B9D sound effects
sfx_update: ld a, [S49]
            and a
            ret z
            cp $FF
            jr z, .mute
            bit 7, a
            jr nz, sfx_init
            ld a, $FF                       ; 8C58: effects 1 (pulse 2) and 2 (noise)
            ld [SD2], a
            ld a, 5
            ld [SD0], a
            ld a, 3
            ld [SD1], a
            call chan_script
            call chan_env
            ld a, 6
            ld [SD0], a
            ld a, 1
            ld [SD1], a
            call chan_script
            jp chan_env
.mute:      ld hl, S49
            inc [hl]
            jp sfx_mute
; 8BB8
sfx_init:   call sfx_mute
            ld e, 1
.c:         ld a, e
            add a, 5
            ld [SD0], a
            ld b, 0
            ld a, low(SFL)
            call six
            ld [hl], b
            ld a, low(STK)
            call six
            ld [hl], b
            ld a, low(SVO)
            call six
            ld [hl], b
            ld b, 8
            ld a, low(SSW)
            call six
            ld [hl], b
            ld b, $30
            ld a, low(SDU)
            call six
            ld [hl], b
            ld b, $0F
            ld a, low(SCV)
            call six
            ld [hl], b
            ld b, $FF
            ld a, low(SVE)
            call six
            ld [hl], b
            ld a, low(SPE)
            call six
            ld [hl], b
            ld a, low(SRD)
            call six
            ld [hl], b
            ld a, low(SES)
            call six
            ld [hl], b
            dec e
            ld a, e
            cp $FF
            jr nz, .c
            ld a, [S49]                     ; the effect's pointers (92C5)
            add a, a
            ld e, a
            ld d, 0
            ld hl, $92C5 - $4000
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            call nes2gb
            ld a, [hl+]
            ld [SN_SPL + 5], a
            ld a, [hl+]
            ld [SPH + 5], a
            ld a, [hl+]
            ld [SN_SPL + 6], a
            ld a, [hl]
            ld [SPH + 6], a
            ld a, [SN_SPL + 5]
            ld b, a
            ld a, [SPH + 5]
            and b
            inc a
            jr z, .d5
            ld hl, SFL + 5
            set 7, [hl]
.d5:        ld a, [SN_SPL + 6]
            ld b, a
            ld a, [SPH + 6]
            and b
            inc a
            jr z, .d6
            ld hl, SFL + 6
            set 7, [hl]
.d6:        ld a, $40
            ld [S49], a
            ret
; 8C29 mute the music's pulse 2 / noise for an effect
sfx_mute:   ld a, [SFL + 5]
            bit 7, a
            jr z, .n
            res 7, a
            ld [SFL + 5], a
            call apu_p2_off
            ld hl, SFL + 1
            set 1, [hl]
.n:         ld a, [SFL + 6]
            bit 7, a
            ret z
            res 7, a
            ld [SFL + 6], a
            call apu_noise_off
            ld hl, SFL + 3
            set 1, [hl]
            ret

; ---- the GB output (FF3 8030 effects / 80AB music: the NES register writes as channel updates)
snd_out:    ld a, GAME_BANK                 ; (the period table SND_TAB at GAME_BANK $6800)
            ld [MBC5_BANKL], a
            ld a, [S49]                     ; effects: pulse 2 (5) -> CH2, noise (6) -> CH4
            and a
            jr z, .mus
            ld a, [SFL + 5]
            bit 7, a
            jr z, .fn
            ld e, 5
            ld d, 1
            call out_pulse
.fn:        ld a, [SFL + 6]
            bit 7, a
            jr z, .mus
            ld e, 6
            call out_noise
.mus:       ld a, [S42]
            bit 7, a
            ret z
            ld a, [SFL]                     ; pulse 1 -> CH1
            bit 7, a
            jr z, .p2
            ld e, 0
            ld d, 0
            call out_pulse
.p2:        ld a, [SFL + 5]                 ; pulse 2 -> CH2 (unless an effect has it)
            bit 7, a
            jr nz, .tr
            ld a, [SFL + 1]
            bit 7, a
            jr z, .tr
            ld e, 1
            ld d, 1
            call out_pulse
.tr:        ld a, [SFL + 2]                 ; triangle -> CH3
            bit 7, a
            call nz, out_tri
            ld a, [SFL + 6]                 ; noise -> CH4 (unless an effect has it)
            bit 7, a
            jr nz, .dmc
            ld a, [SFL + 3]
            bit 7, a
            jr z, .dmc
            ld e, 3
            call out_noise
.dmc:       ld hl, SFL + 4                  ; 81AC dmc: the key-on flag taken (the GB has no
            bit 7, [hl]                     ;   DMC; FF3 only silences it: $4011 = 0)
            ret z
            res 0, [hl]
            ret

; E = channel, D = 0 CH1 / 1 CH2. As FF3's 80B1 / 80F5: key on (flag bit 0): duty, volume,
; sweep, the whole period (and the NES sweep unit restarted); else duty, volume and the period's
; low byte unless the sweep is on. The NES sweep unit runs here (o_sweep: CH2 has none on the GB,
; and CH1's steps differ from the NES's); the GB gets the resulting period each frame, a volume
; change (or the sweep's mute) retriggers.
out_pulse:  ld a, d
            ld [o_ch], a
            ld a, e
            ld [SD0], a
            call o_duty
            ld a, low(SFR)
            call six
            ld c, [hl]                      ; C = period lo
            ld a, low(SFH)
            call six
            ld b, [hl]                      ; B = period hi
            call o_pp                       ; HL = o_per + 2 ch
            ld a, low(SFL)
            push hl
            call six
            bit 0, [hl]
            res 0, [hl]
            pop hl
            jr z, .hold
            ld [hl], c                      ; key on: the period, the divider reloaded
            inc hl
            ld a, b
            and 7
            ld [hl], a
            ld a, 1
            ld [o_trig], a
            call o_swp
            ld a, 1
            ld [hl], a                      ; (o_swr: reload)
            jr .sw
.hold:      xor a
            ld [o_trig], a
            ld a, low(SSW)
            push hl
            call six
            bit 7, [hl]
            pop hl
            jr nz, .sw
            ld [hl], c                      ; (sweep off: the low byte, FF3's $4002 write)
.sw:        call o_sweep                    ; two half-frame clocks a frame
            call o_sweep
            call o_mute                     ; A = 0 if muted
            ld b, a
            ld a, low(SVO)
            call six
            ld a, [hl]
            and $0F
            and b                           ; (muted: volume 0)
            ld b, a
            ld a, [o_ch]
            ld e, a
            ld d, 0
            ld hl, o_lastv
            add hl, de
            ld a, [hl]
            cp b
            jr z, .nv
            ld a, 1
            ld [o_trig], a
.nv:        ld a, [o_trig]
            and a
            jr z, .f
            ld [hl], b                      ; volume (remembered), period, trigger
            ld a, b
            swap a
            ld b, a
            ld a, [o_ch]
            and a
            ld a, b
            jr nz, .v2
            ldh [rNR12], a
            jr .vf
.v2:        ldh [rNR22], a
.vf:        call o_perf
            ld a, $80
            jp o_wr4
.f:         call o_perf
            xor a
            jp o_wr4

; HL = o_per + 2 o_ch
o_pp:       ld a, [o_ch]
            add a, a
            add a, low(o_per)
            ld l, a
            ld h, high(o_per)
            ret
; HL = o_swr + o_ch (and the divider at HL - 2)
o_swp:      ld a, [o_ch]
            add a, low(o_swr)
            ld l, a
            ld h, high(o_swr)
            ret
; o_per -> the GB frequency (SND_TAB) -> NRx3, o_hi
o_perf:     call o_pp
            ld e, [hl]
            inc hl
            ld d, [hl]
            jp o_freq.de

; the sweep's target from o_per and SSW: DE = target, B = SSW, C = 1 if the sweep would mute
; (NES: period < 8, or an upward target above $7FF)
o_target:   ld a, low(SSW)
            call six
            ld b, [hl]
            call o_pp
            ld e, [hl]
            inc hl
            ld d, [hl]
            push de                         ; change = period >> shift
            ld a, b
            and 7
            jr z, .s0
.sh:        srl d
            rr e
            dec a
            jr nz, .sh
.s0:        pop hl                          ; HL = period
            bit 3, b
            jr nz, .neg
            add hl, de                      ; up: period + change
            ld d, h
            ld e, l
            ld a, h
            cp 8
            ld c, 1
            jr nc, .lo
            dec c
            jr .lo
.neg:       ld a, l                         ; down: period - change (pulse 1: - 1 more)
            sub e
            ld e, a
            ld a, h
            sbc d
            ld d, a
            ld a, [o_ch]
            and a
            jr nz, .n2
            dec de
.n2:        ld c, 0
.lo:        call o_pp                       ; period < 8: muted
            ld a, [hl+]
            cp 8
            ld a, [hl]
            sbc 0
            ret nc
            ld c, 1
            ret
; A = 0 if the channel is muted by the sweep unit, else $0F
o_mute:     call o_target
            ld a, c
            and a
            ld a, $0F
            ret z
            xor a
            ret
; one half-frame clock of the NES sweep unit (APU: divider 0, enabled, shift > 0, not muting: the
; period takes the target; then the divider counts down or reloads with P)
o_sweep:    call o_target
            call o_swp
            dec hl
            dec hl                          ; HL = o_swd + ch
            ld a, [hl]
            and a
            jr nz, .cnt
            bit 7, b
            jr z, .rl
            ld a, b
            and 7
            jr z, .rl
            ld a, c
            and a
            jr nz, .rl
            push hl
            call o_pp
            ld [hl], e
            inc hl
            ld [hl], d
            pop hl
.rl:        ld a, b                         ; the divider reloaded with P
            swap a
            and 7
            ld [hl+], a
            inc hl
            ld [hl], 0                      ; (o_swr cleared)
            ret
.cnt:       inc hl
            inc hl
            ld a, [hl]                      ; a reload flag set: reload, else count down
            and a
            dec hl
            dec hl
            jr nz, .rl
            dec [hl]
            ret

; NRx1 duty (FF3 $30 / $70 / $B0 = 1/8, 1/4, 1/2 -> GB 0 / 1 / 2)
o_duty:     ld a, low(SDU)
            call six
            ld a, [hl]
            and $C0
            ld b, a
            ld a, [o_ch]
            and a
            ld a, b
            jr nz, .c2
            ldh [rNR11], a
            ret
.c2:         ldh [rNR21], a
            ret
; NRx2 the volume (no envelope), remembered
o_vol:      ld a, low(SVO)
            call six
            ld a, [hl]
            and $0F
            ld b, a
            ld a, [o_ch]
            ld e, a
            ld d, 0
            ld hl, o_lastv
            add hl, de
            ld [hl], b
            ld a, b
            swap a
            ld b, a
            ld a, [o_ch]
            cp 3
            jr z, .n
            and a
            ld a, b
            jr nz, .c2
            ldh [rNR12], a
            ret
.c2:         ldh [rNR22], a
            ret
.n:         ld a, b
            ldh [rNR42], a
            ret
; the period (hi:lo) -> the GB frequency (SND_TAB) -> NRx3, o_hi
o_freq:     ld a, low(SFH)
            call six
            ld a, [hl]
            and 7
            ld d, a
            ld a, low(SFR)
            call six
            ld e, [hl]
.de:        ld hl, $6800                    ; SND_TAB: 2 bytes a period (.de: DE = the period)
            add hl, de
            add hl, de
            ld a, [hl+]
            ld b, a
            ld a, [hl]
            ld [o_hi], a
            ld a, [o_ch]
            cp 2
            jr z, .c3
            and a
            ld a, b
            jr nz, .c2
            ldh [rNR13], a
            ret
.c2:         ldh [rNR23], a
            ret
.c3:         ld a, b
            ldh [rNR33], a
            ret
; NRx4 = o_hi | A (bit 7: trigger)
o_wr4:      ld b, a
            ld a, [o_hi]
            or b
            ld b, a
            ld a, [o_ch]
            cp 2
            jr z, .c3
            and a
            ld a, b
            jr nz, .c2
            ldh [rNR14], a
            ret
.c2:         ldh [rNR24], a
            ret
.c3:         ld a, b
            ldh [rNR34], a
            ret

; triangle (2) -> CH3: on while its "volume" is not 0 (the linear counter), the period
out_tri:    ld a, 2
            ld [SD0], a
            ld [o_ch], a
            ld a, low(SVO)
            call six
            ld a, [hl]
            and a
            jr z, .off
            ld a, $80
            ldh [rNR30], a
            ld a, $20                       ; (100%)
            ldh [rNR32], a
            ld a, low(SFL)
            call six
            bit 0, [hl]
            jr z, .h
            res 0, [hl]
            call o_freq
            ld a, $80
            jp o_wr4
.h:         call o_freq
            xor a
            jp o_wr4
.off:       xor a
            ldh [rNR32], a
            ret

; noise (E = 3 or 6) -> CH4: volume, the period (SND_NOISE: NES index + mode -> NR43)
out_noise:  ld a, e
            ld [SD0], a
            ld a, 3
            ld [o_ch], a
            ld a, low(SFL)
            call six
            ld a, [hl]
            ld c, a
            res 0, [hl]
            ld a, low(SFR)
            call six
            ld a, [hl]
            ld b, a
            and $0F
            bit 7, b
            jr z, .m
            or $10
.m:         ld e, a
            ld d, 0
            ld hl, $7800                    ; SND_NOISE (GAME_BANK $7800)
            add hl, de
            ld a, [hl]
            ldh [rNR43], a
            ld a, low(SVO)
            call six
            ld a, [hl]
            and $0F
            ld b, a
            ld a, [o_lastv + 3]
            cp b
            jr nz, .t
            bit 0, c
            ret z
.t:         call o_vol
            ld a, $80
            ldh [rNR44], a
            ret

apu_p1_off: xor a
            ldh [rNR12], a
            ld [o_lastv], a
            ret
apu_p2_off: xor a
            ldh [rNR22], a
            ld [o_lastv + 1], a
            ret
apu_tri_off: xor a
            ldh [rNR32], a
            ret
apu_noise_off: xor a
            ldh [rNR42], a
            ld [o_lastv + 3], a
            ret

; boot: the APU on, a triangle wave in CH3, the driver's init (81C3)
snd_init:   ld a, $80
            ldh [rNR52], a
            xor a                           ; (no GB sweep: the NES's runs in o_sweep)
            ldh [rNR10], a
            ld a, $77
            ldh [rNR50], a
            ld a, SND_MASK                  ; ($FF; test builds: one voice, env GB_SND_MASK)
            ldh [rNR51], a
            xor a
            ldh [rNR30], a
            ld hl, $FF30                    ; the triangle: 0..F..0 over 32 samples
            ld de, .wave
            ld b, 16
.w:         ld a, [de]
            inc de
            ld [hl+], a
            dec b
            jr nz, .w
            ld a, $80
            ldh [rNR30], a
            xor a
            ld [S42], a
            ld [S40], a
            ld [S49], a
            ld hl, SFL
            ld b, 7
.c:         ld [hl+], a
            dec b
            jr nz, .c
            ld a, 1
            ld [snd_on], a
            ret

snd_init.wave: db $01, $23, $45, $67, $89, $AB, $CD, $EF, $FE, $DC, $BA, $98, $76, $54, $32, $10

section wram, $CC20
snd_on:     ds 1
snd_bank:   ds 1
scmd:       ds 1
o_ch:       ds 1
o_hi:       ds 1
o_lastv:    ds 4

section wram, $C3A0
o_per:      ds 4                            ; the pulses' NES periods (CH1, CH2)
o_swd:      ds 2                            ; their sweep dividers
o_swr:      ds 2                            ;   and reload flags (o_swd + 2)
o_trig:     ds 1
