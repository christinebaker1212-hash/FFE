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

; ---- the event's screen effects
; $D0: shake (3B/B58F / B938: sound $38, 17 frames, the scroll's x EOR (frame & 2))
ev_d0:      ld a, $D8
            ld [M_SFX], a
            xor a
.l:         push af
            and 2
            ld [fx_x], a
            call wait_vbl
            call snd_frame
            call set_scroll
            ld a, [fx_x]
            ld b, a
            ldh a, [scx]
            xor b
            ldh [scx], a
            pop af
            inc a
            cp $11
            jr c, .l
            call wait_vbl
            jp set_scroll
; $D1: flash with a sound (3B/B597: $39), $E2: flash (3B/B913): grey every other 2 frames, 17
ev_d1:      ld a, $D9
            ld [M_SFX], a
ev_e2:      ld hl, sh_pal                   ; (the colours kept)
            ld de, fx_keep
            ld bc, 128
            call memcpy
            xor a
.l:         push af
            srl a
            and 1
            call z, fx_norm
            call nz, fx_grey
            call wait_vbl
            call snd_frame
            pop af
            inc a
            cp $11
            jr c, .l
            call fx_norm
            jp wait_vbl
fx_norm:    push af
            ld hl, fx_keep
            ld de, sh_pal
            ld bc, 128
            call memcpy
            ld a, 1
            ld [pal_dirty], a
            pop af
            ret
; the NES's greyscale (colour & $30): each colour to the grey of its brightness
fx_grey:    push af
            ld hl, fx_keep
            ld de, sh_pal
            ld b, 64
.c:         ld a, [hl+]                     ; RGB555: r + g + b
            ld c, a
            ld a, [hl+]
            push hl
            push de
            ld h, a
            ld l, c
            ld a, l                         ; r = l & 31
            and 31
            ld e, a
            ld a, l                         ; g = (h << 3 | l >> 5) & 31
            swap a
            rrca
            and 7
            ld d, a
            ld a, h
            and 3
            add a, a
            add a, a
            add a, a
            or d
            add a, e
            ld e, a
            ld a, h                         ; b = h >> 2
            rrca
            rrca
            and 31
            add a, e                        ; (sum 0-93)
            ld e, a
            ld hl, fx_gtab                  ; the NES grey for that brightness
            cp 12
            jr c, .g
            inc hl
            inc hl
            cp 40
            jr c, .g
            inc hl
            inc hl
            cp 70
            jr c, .g
            inc hl
            inc hl
.g:         ld a, [hl+]
            ld c, a
            ld a, [hl]
            pop de
            ld h, a
            ld a, c
            ld [de], a
            inc de
            ld a, h
            ld [de], a
            inc de
            pop hl
            dec b
            jr nz, .c
            ld a, 1
            ld [pal_dirty], a
            pop af
            ret
fx_gtab:    dw $0000, $3DEF, $5EF7, $7FFF   ; (NES $0F / $00 / $10 / $30 greys)

; $D2 / $D3: the BG colours darkened towards blue / back (3E/D3AF): every 4 frames each colour's hue
; one step towards 2 (blue), its brightness at most 1, black kept; back: one step towards its own,
; then the colours as they were
ev_d2:      ld hl, mrec + 112               ; (FF3's $03C0: the map's NES colours, port.py)
            ld de, fx_nes
            ld b, 16
.c:         ld a, [hl+]
            and $1F
            ld [de], a
            inc de
            dec b
            jr nz, .c
            ld a, 2
            ld [fx_hue], a
            jr fx_steps
ev_d3:      xor a
            ld [fx_hue], a
fx_steps:   ld a, 1
.l:         push af
            and 3
            jr nz, .w
            call fx_step
            ld a, b
            and a
            jr z, .x
.w:         call wait_vbl
            call snd_frame
            pop af
            inc a
            jr .l
.x:         pop af
            ld a, [fx_hue]                  ; (back: the colours as they were)
            and a
            ret nz
            jp load_pal
; one step: B = colours changed
fx_step:    ld b, 0
            ld c, 0
.l:         ld hl, fx_nes
            ld e, c
            ld d, 0
            add hl, de
            ld a, [hl]
            cp $0F
            jr z, .n
            and $10
            ld [fx_br], a
            ld a, [fx_hue]                  ; the hue's goal: blue (2), or the colour's own
            and a
            jr nz, .g
            push hl
            ld hl, mrec + 112
            add hl, de
            ld a, [hl]
            pop hl
            and $0F
.g:         ld e, a
            ld a, [hl]
            and $0F
            cp e
            jr z, .n
            jr c, .up
            dec a
            jr .s
.up:        inc a
.s:         ld e, a
            ld a, [fx_br]
            or e
            ld [hl], a
            inc b
.n:         inc c
            ld a, c
            cp 16
            jr c, .l
            push bc                         ; the 16 colours to the BG shadow (palettes 0-3)
            ld a, COMMON
            call sbank
            ld hl, fx_nes
            ld de, sh_pal
            ld c, 16
.r:         ld a, [hl+]
            push hl
            and $3F
            add a, a
            ld l, a
            ld h, high(C3_RGB)
            ld a, [hl+]
            ld [de], a
            inc de
            ld a, [hl]
            ld [de], a
            inc de
            pop hl
            dec c
            jr nz, .r
            ld a, 1
            ld [pal_dirty], a
            pop bc
            ret

section wram, $D700                         ; (WRAM bank 1)
fx_keep:    ds 128
fx_nes:     ds 16
fx_x:       ds 1
fx_hue:     ds 1
fx_br:      ds 1

