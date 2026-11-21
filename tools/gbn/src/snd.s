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

section bank 7, $4000
; boot: sound on, the triangle's wave
snd_init_b: ld a, $80
            ldh [$FF26], a                  ; NR52 on
            ld a, $77
            ldh [$FF24], a                  ; NR50 full
            ld a, $FF
            ldh [$FF25], a                  ; NR51 all channels both sides
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
            ld b, 32
            xor a
.c:         ld [hl+], a
            dec b
            jr nz, .c
            ld a, $80                       ; (no track yet: silent)
            ld [NES_RAM + $4B], a
            ret
snd_wave:   db $01, $23, $45, $67, $89, $AB, $CD, $EF, $FE, $DC, $BA, $98, $76, $54, $32, $10
; once a frame (V-Blank)
snd_frame_b:
            jp mus_play_b

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
.vol:       ld a, e
            and $C0
            ld [hl+], a                     ; NRx1 duty
            ld a, e
            and $0F
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
.fth:       ld hl, snd_sh + $0A
            ld c, 2
            jr .fh
.fl:        call .freq                      ; the period's low byte: NRx3, NRx4 (no restart)
            ld [hl+], a
            ld [hl], d
            ld a, d
            ld [bc], a
            jr .x
.fh:        call .freq                      ; the high byte: restart
            ld [hl+], a
            ld a, d
            ld [bc], a
            or $80
            ld [hl], a
            jr .x
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
.tlin:      ld a, e                         ; the triangle: on while its linear counter is set
            and $7F
            ld a, 0
            jr z, .toff
            ld a, $80
.toff:      ldh [$FF1A], a
            jp .x
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
            ldh [$FF1A], a
            jp .x
snd_nrx3:   db $13, $18, $1D

section wram, $CFC0
snd_sh:     ds 32                           ; the engine's register values (shadow)
snd_fh:     ds 4                            ; GB frequency high bits per channel
