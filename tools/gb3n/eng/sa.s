; FF3 native port: FF3's special animations (event command $EF, 3B/A4FA), written from what the
; everything8215/ff3 listing says FF3 does. Our own code. NES sprite positions map to the Game Boy's
; OAM as the party's: OAM x = NES x - 32, OAM y = NES y - 28 (the party: NES (112, 108), GB (72, 64)).

C_SIN3     = $5F00          ; COMMON: 3A/9E3E the sine table (256)

section bank 0, $3A00

; $EF nn (3B/B6B4: $BC and the frame counter from 0)
ev_ef:      xor a
            ld [Z + $BC], a
            ld [zF0], a
            ld a, [z71]
            cp $0D
            jr z, sa_d
            cp 5                            ; 5-8: a statue destroyed (3B/A52B: the switch bit;
            ret c                           ;   its animation and tiles with the world map's)
            cp 9
            ret nc
            sub 4                           ; (bits 1-4 of $602E)
            ld b, a
            ld a, 1
.b:         add a, a
            dec b
            jr nz, .b
            ld hl, SV + $2E
            or [hl]
            ld [hl], a
            ret

; ---- D: circling stars (3B/A1F7): object 0's picture, 8 copies on a circle round the party, the
; radius from $EA down by 2 a frame to $0C, the angle up by 4
sa_d:       xor a
            ld [O1 + 1], a                  ; (3B/A1F9: its layer)
            ld [Z + $62], a
            ld [Z + $63], a
            ld a, $EA
            ld [Z + $65], a
            call sa_reset
.f:         call sa_wait
            call sa_reset
            call make_oam                   ; (3E/C01B: the party's sprites)
            ld a, $10
            ld [spr_at], a
            ld a, 8                         ; (3B/A230: eight)
            ld [Z + $8E], a
            ld a, [Z + $62]
            ld [Z + $66], a
            ld a, [Z + $63]
            ld [Z + $67], a
.s:         call sa_pos
            ld a, [Z + $40]                 ; (3B/A23F: - 4, - 4)
            sub 4 + 32
            ld [spr_x], a
            ld a, [Z + $41]
            sub 4 + 28
            ld [spr_y], a
            xor a                           ; (3B/B236: object 0, no movement)
            ld [npc_o], a
            ld l, a
            ld h, high(O0)
            call npc_spr.frame
            ld a, [Z + $66]                 ; (the next: + $80)
            add a, $80
            ld [Z + $66], a
            ld a, [Z + $67]
            adc a, 0
            ld [Z + $67], a
            ld hl, Z + $8E
            dec [hl]
            jr nz, .s
            ld a, [Z + $62]
            add a, 4
            ld [Z + $62], a
            ld a, [Z + $63]
            adc a, 0
            ld [Z + $63], a
            ld a, [Z + $65]
            sub 2
            ld [Z + $65], a
            cp $0C
            jr nc, .f
            ret

; FF3 calculate projectile sprite position (3A/9DA4): radius z65, angle z66 / z67 (down 0, right
; $100, up $200, left $300) -> z40 / z41 (centre $74)
sa_pos:     ld a, COMMON
            call sbank
            ld a, [Z + $66]                 ; sine x radius
            ld l, a
            ld h, high(C_SIN3)
            ld b, [hl]
            call .mul
            ld [Z + $88], a
            ld a, [Z + $66]                 ; cosine: the sine of the angle negated
            cpl
            ld l, a
            ld b, [hl]
            call .mul
            ld [Z + $89], a
            ld a, [Z + $67]
            and 3
            jr z, .p
            cp 1
            jr nz, .q2
            ld a, [Z + $89]                 ; 1: (y, -x)
            ld b, a
            ld a, [Z + $88]
            cpl
            inc a
            ld [Z + $89], a
            ld a, b
            ld [Z + $88], a
            jr .p
.q2:        cp 2
            jr nz, .q3
            ld a, [Z + $88]                 ; 2: (-x, -y)
            cpl
            inc a
            ld [Z + $88], a
            ld a, [Z + $89]
            cpl
            inc a
            ld [Z + $89], a
            jr .p
.q3:        ld a, [Z + $88]                 ; 3: (-y, x)
            ld b, a
            ld a, [Z + $89]
            cpl
            inc a
            ld [Z + $88], a
            ld a, b
            ld [Z + $89], a
.p:         ld a, [Z + $88]
            add a, $74
            ld [Z + $40], a
            ld a, [Z + $89]
            add a, $74
            ld [Z + $41], a
            ret
.mul:       ld a, [Z + $65]                 ; (3A/9E1A: B x radius, the high byte)
            ld c, a
            ld hl, 0
            ld d, 0
            ld e, c
.m:         srl b
            jr nc, .n
            add hl, de
.n:         sla e
            rl d
            ld a, b
            and a
            jr nz, .m
            ld a, h
            ret

; FF3 reset sprite data (3B/A842): every sprite hidden
sa_reset:   ld hl, oam_buf
            ld b, 40
            xor a
.l:         ld [hl+], a
            inc l
            inc l
            inc l
            dec b
            jr nz, .l
            ret
; FF3 wait for end of V-Blank (3B/A85A): a frame, the OAM, the frame counter, the sound
sa_wait:    call wait_vbl
            call snd_frame
            ld hl, zF0
            inc [hl]
            ret
