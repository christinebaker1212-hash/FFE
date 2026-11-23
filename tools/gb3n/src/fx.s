; ---- field effects of the event script (FF3 3B/B555 and fix:D3AF), in the cutscene bank:
; $D0 shake (3B/B938), $D1 / $E2 flash (3B/B913: greyscale every other 2 frames), $D2 / $D3 the
; background colours darkened to blue and back (fix:D3AF), $DA the people's dance (3B/ACB9),
; $E0 / $E1 the map's palettes again (3B/B653, $E1 with the guest's).
FX_SAVE    = $D800              ; (WRAM bank 4) the palettes during a flash
FX3B_DANCE = $7F00              ; CUTD2: 3B/ADB1, AE05, AE59 the dance ($54 each)
FX3B_BANK  = CUTD2

; $D0: 17 frames, the scroll x xor (frame & 2); sound $38
fx_shake:   ld a, $D8
            ld [S49], a
            ldh a, [scx]
            ld [fx_ssx], a
            ld c, 0
.l:         ld a, c
            and 2
            ld b, a
            ld a, [fx_ssx]
            xor b
            ldh [scx], a
            push bc
            call wait_vbl
            pop bc
            inc c
            ld a, c
            cp $11
            jr c, .l
            ld a, [fx_ssx]
            ldh [scx], a
            ret

; $D1: sound $39, then the flash; $E2: the flash (17 frames, greyscale on frames 2-3, 6-7, ...)
fx_flashs:  ld a, $D9
            ld [S49], a
fx_flash:   ld a, 4
            ldh [rSVBK], a
            ld hl, pal_sh
            ld de, FX_SAVE
            ld bc, 128
            call memcpy
            ld c, 0
.l:         push bc
            ld a, c
            and 2
            jr z, .col
            call fx_grey
            jr .w
.col:       ld hl, FX_SAVE
            ld de, pal_sh
            ld bc, 128
            call memcpy
.w:         ld a, 1
            ldh [pal_dirty], a
            call wait_vbl
            pop bc
            inc c
            ld a, c
            cp $11
            jr c, .l
            ld hl, FX_SAVE
            ld de, pal_sh
            ld bc, 128
            call memcpy
            ld a, 1
            ldh [pal_dirty], a
            ldh [rSVBK], a
            jp wait_vbl
; the saved palettes in grey (the NES greyscale: each colour's brightness) -> the shadow
fx_grey:    ld hl, FX_SAVE
            ld de, pal_sh
            ld b, 64
.c:         push bc
            ld a, [hl+]                     ; RGB555: r = lo & 31, g = (lo >> 5) | (hi & 3) << 3,
            ld c, a                         ;   b = (hi >> 2) & 31
            ld a, [hl+]
            ld b, a
            ld a, c
            and $1F
            ld [fx_tt], a
            ld a, b
            rrca
            rrca
            and $1F
            ld [fx_tt + 1], a
            ld a, c                         ; g
            swap a
            rrca
            and $07
            ld c, a
            ld a, b
            and 3
            add a, a
            add a, a
            add a, a
            or c                            ; A = g
            push hl
            ld hl, fx_tt
            add a, [hl]
            inc hl
            add a, [hl]                     ; r + g + b (0-93)
            ld l, a                         ; / 3
            ld h, 0
            ld c, 0
.d:         cp 3
            jr c, .d1
            sub 3
            inc c
            jr .d
.d1:        ld a, c                         ; y -> y | y << 5 | y << 10
            ld b, a
            swap a
            rlca                            ; (y << 5) & $E0
            and $E0
            or b
            ld [de], a
            inc de
            ld a, b
            add a, a
            add a, a                        ; (y << 2) | (y >> 3)
            ld c, a
            ld a, b
            rrca
            rrca
            rrca
            and 3
            or c
            and $7F
            ld [de], a
            inc de
            pop hl
            pop bc
            dec b
            jr nz, .c
            ret

; $D2 (fix:D3AF, carry clear): the background colours to brightness 0-1, then their hues a
; step toward 2 (blue) every 4 frames until none moves
fx_dark:    ld hl, M_ENT + 16
            ld de, fx_w
            ld b, 16
.cp:        ld a, [hl+]
            and $1F
            ld [de], a
            inc de
            dec b
            jr nz, .cp
            ld a, 1
            ld [fx_wok], a
            ld c, 1
.l:         ld a, c
            and 3
            jr nz, .w
            call .step
            ld a, b
            and a
            jr z, .end
.w:         push bc
            call fx_wpal
            call wait_vbl
            pop bc
            inc c
            jr .l
.end:       ret
.step:      ld hl, fx_w                     ; B = how many moved
            ld b, 0
            ld c, 16
.s:         ld a, [hl]
            cp $0F
            jr z, .n
            ld e, a
            and $0F
            cp 2
            jr z, .n
            jr c, .up
            dec a
            jr .st
.up:        inc a
.st:        ld d, a
            ld a, e
            and $10
            or d
            ld [hl], a
            inc b
.n:         inc hl
            dec c
            jr nz, .s
            ld c, 4                         ; (the frame count: kept a multiple of 4 + 1)
            ret
; $D3 (carry set): the hues back toward the map's, a step every 4 frames, then its palettes
fx_light:   ld a, [fx_wok]
            and a
            jr nz, .ok
            ld hl, M_ENT + 16
            ld de, fx_w
            ld b, 16
.cp:        ld a, [hl+]
            and $1F
            ld [de], a
            inc de
            dec b
            jr nz, .cp
.ok:        ld c, 1
.l:         ld a, c
            and 3
            jr nz, .w
            push bc
            call .step
            ld a, b
            pop bc
            and a
            jr z, .end
.w:         push bc
            call fx_wpal
            call wait_vbl
            pop bc
            inc c
            jr .l
.end:       xor a
            ld [fx_wok], a
            call map_pals
            call g_pal
            ld a, 1
            ldh [pal_dirty], a
            jp wait_vbl
.step:      ld hl, fx_w
            ld de, M_ENT + 16
            ld b, 0
            ld c, 16
.s:         ld a, [hl]
            cp $0F
            jr z, .n
            push bc
            and $10
            ld [fx_tt], a
            ld a, [de]
            and $0F
            ld b, a                         ; target hue
            ld a, [hl]
            and $0F
            cp b
            jr z, .n0
            jr c, .up
            dec a
            jr .st
.up:        inc a
.st:        ld b, a
            ld a, [fx_tt]
            or b
            ld [hl], a
            pop bc
            inc b
            jr .n
.n0:        pop bc
.n:         inc hl
            inc de
            dec c
            jr nz, .s
            ret
; the working colours (fx_w) -> BG palettes 0-3
fx_wpal:    ld hl, fx_w
            ld bc, pal_sh
.c:         push bc
            call nes_col
            pop bc
            ld [bc], a
            inc bc
            ld a, d
            ld [bc], a
            inc bc
            ld a, c
            cp low(pal_sh + 32)
            jr nz, .c
            ld a, 1
            ldh [pal_dirty], a
            ret

; $E0 / $E1: the map's palettes ($E1 with the guest's)
fx_pal0:    xor a
            jr fx_pal
fx_pal1:    ld a, 1
fx_pal:     push af
            call map_pals
            pop af
            and a
            call nz, g_pal
            ld a, 1
            ldh [pal_dirty], a
            jp wait_vbl

; $DA (3B/ACB9 / AD5D): every person (slots 0-9) steps through FF3's dance (sub-tile x / y and
; facing from 3B/ADB1 / AE05 / AE59, 3 steps every 4 frames), five times; drawn without moving
fx_dance:   xor a
            ld [fx_74], a
            ld [fx_75], a
.f:         ld hl, fcnt
            inc [hl]
            ld a, [hl]
            and 3
            cp 3
            ld a, 0
            ld hl, fx_74
            adc a, [hl]
            ld [hl], a
            cp $54
            jr c, .set
            xor a
            ld [hl], a
            ld hl, fx_75
            inc [hl]
            ld a, [hl]
            cp 5
            ret nc
            xor a
.set:       ld e, a
            ld d, 0
            ld hl, FX3B_DANCE
            add hl, de
            ld a, FX3B_BANK
            call rd_byte
            ld [fx_tt], a
            ld hl, FX3B_DANCE + $54
            add hl, de
            ld a, FX3B_BANK
            call rd_byte
            ld [fx_tt + 1], a
            ld hl, FX3B_DANCE + $A8
            add hl, de
            ld a, FX3B_BANK
            call rd_byte
            swap a
            ld [fx_tt + 2], a
            ld l, 0
            ld h, high(N_OBJ)
.o:         ld a, l
            add a, 6
            ld l, a
            ld a, [fx_tt]
            ld [hl+], a
            ld a, [fx_tt + 1]
            ld [hl], a
            ld a, l
            add a, 7                        ; +E
            ld l, a
            ld a, [fx_tt + 2]
            ld [hl], a
            ld a, l
            add a, 2                        ; next slot
            ld l, a
            cp $A0
            jr c, .o
            call npc_drawall                ; 3B/ABB1
            call wait_vbl
            jr .f

section wram, $CC00
fx_ssx:      ds 1
fx_tt:       ds 3
fx_wok:     ds 1
fx_w:       ds 16
fx_74:      ds 1
fx_75:      ds 1
