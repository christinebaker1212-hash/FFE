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

; $EF special animations (3B/A4FA): the game-state effects (vehicles, $602E statue / gate flags
; with their metatile copies, $602F bit 6 the spinning walker) after each animation
fx_special: ld a, [ev_par]
            and $0F
            add a, a
            ld l, a
            ld h, 0
            ld de, .t
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            jp hl
.t:         dw sp_0, sp_1, sp_2, sp_3, sp_4, sp_5, sp_6, sp_7
            dw sp_8, sp_9, sp_a, sp_b, sp_c, sp_d, sp_e, sp_f
; 0 (3B/A8A9): the Enterprise lands: on it, facing left, the ship on world 0
sp_0:       call spa_0
            ld a, 2
            ld [facing], a
            ld a, 5
            ld [GS + $0F], a
            ld a, 1
            ld [GS + $00], a
            xor a
            ld [GS + $03], a
            ret
; 1 (3A/9AB8): the airship / boulder explodes: off it, its flag cleared, the walker spins, the
; vehicle at (80, 80) shown
sp_1:       call g_init
            call spa_1
            xor a
            ld [GS + $0F], a
            ld hl, GS + $20
            res 0, [hl]
            call sp_spin
            ld a, $50
            ld [GS + $01], a
            ld [GS + $02], a
            ld a, 1
            ld [GS + $00], a
            ret
; 2 / 3 (3B/A609, A631), then 3B/A5BE (128 frames, the walker spinning)
sp_2:       jp spa_2                        ; (each ends with 3B/A5BE: the walker spins)
sp_3:       jp spa_3
; 4 (3B/A3EA, 3A/9A7B): Saronia's cannon balls, the airship shot down: off it, hidden, at (83, 71)
; on world 3
sp_4:       call spa_4
            xor a
            ld [GS + $0F], a
            ld [GS + $00], a
            ld a, $53
            ld [GS + $01], a
            ld a, $47
            ld [GS + $02], a
            ld a, 3
            ld [GS + $03], a
            ret
; 5-8 (3B/A806): a statue destroyed: $602E bit 1-4, metatile $40-$43 <- 0 (3B/A9BA)
sp_5:       ld b, 0
            jr sp_st
sp_6:       ld b, 1
            jr sp_st
sp_7:       ld b, 2
            jr sp_st
sp_8:       ld b, 3
sp_st:      push bc
            call spa_st
            pop bc
            ld a, b
            add a, $40
            ld c, a
            ld a, 2
.sh:        dec b
            bit 7, b
            jr nz, .s1
            add a, a
            jr .sh
.s1:        ld hl, GS + $2E
            or [hl]
            ld [hl], a
            ld b, 0
            jr sp_mt
; E: the Saronia gate opened: $602E bit 5, metatile $4A <- 3
sp_e:       ld hl, GS + $2E
            set 5, [hl]
            ld bc, $034A
sp_mt:      call mt_copy
            jp draw_view
; 9 (3B/A66A): the Invincible rises from the sea: aboard, facing left, it shown
sp_9:       call spa_9
            ld a, 2
            ld [facing], a
            ld a, 7
            ld [GS + $0F], a
            ld a, 1
            ld [GS + $04], a
            ret
sp_a:       jp spa_a
sp_b:       jp spa_b
; C (3B/A264): Bahamut attacks, the walker spins
sp_c:       call spa_c
            jp sp_spin
sp_d:       jp spa_d
sp_f:       ret
; $602F bit 6: the walker spins (3E/D8F7, cleared by itself 64 frames later)
sp_spin:    ld hl, GS + $2F
            set 6, [hl]
            xor a
            ld [spin_c], a
            ret

; the animations (anim.s, bank CODE6)
spa_0:      ld hl, an_enter
            jr spa
spa_1:      ld hl, an_burst
            jr spa
spa_2:      ld hl, an_six
            jr spa
spa_3:      ld hl, an_sixteen
            jr spa
spa_4:      ld hl, an_saronia
            jr spa
spa_st:     ld hl, an_statue
            jr spa
spa_9:      ld hl, an_rise
            jr spa
spa_a:      ld hl, an_circa
            jr spa
spa_b:      ld hl, an_circb
            jr spa
spa_c:      ld hl, an_bahamut
            jr spa
spa_d:      ld hl, an_stars
spa:        ld a, CODE6
            jp far_call
spa_5be:    ld hl, an_5be
            jr spa

; ---- people's moves (3B/AB71, AC25, AC68): object fx_slot; drawn without moving, a frame each
; $xA / $xB a jump left / right over one tile (48 frames, heights 3B/AC0C)
fx_jumpl:   ld a, 1
            jr fx_jump
fx_jumpr:   xor a
fx_jump:    ld [fx_75], a
            xor a
            ld [fx_74], a
            ld a, [fx_slot]
            ld l, a
            ld h, high(N_OBJ)
            ld a, l
            add a, 5
            ld l, a
            dec [hl]                        ; y - 1, y sub-tile $0F
            inc l
            inc l
            ld [hl], $0F
.f:         ld a, [fx_slot]
            ld l, a
            ld h, high(N_OBJ)
            ld a, [fx_75]
            and a
            ld a, l
            add a, 6
            ld l, a
            ld a, [hl]
            jr nz, .left
            inc a                           ; right
            and $0F
            ld [hl], a
            jr nz, .y
            dec l
            dec l
            inc [hl]
            inc l
            inc l
            jr .y
.left:      sub 1
            push af
            and $0F
            ld [hl], a
            pop af
            jr nc, .y
            dec l
            dec l
            dec [hl]
            inc l
            inc l
.y:         inc l                           ; +7: 3B/AC0C (mirrored after the middle) xor $0F
            push hl
            ld a, [fx_74]
            cp $18
            jr c, .y1
            ld b, a
            ld a, $2F
            sub b
.y1:        ld e, a
            ld d, 0
            ld hl, FX3B_DANCE - $100
            add hl, de
            ld a, CUTD2
            call rd_byte
            xor $0F
            pop hl
            ld [hl], a
            ld hl, fx_74
            inc [hl]
            call npc_drawall                ; 3B/ABB1
            call wait_vbl
            ld a, [fx_74]
            cp $30
            jr c, .f
            ld a, [fx_slot]                 ; sub-tiles 0, y + 1, destination x = x
            ld l, a
            ld h, high(N_OBJ)
            ld a, l
            add a, 6
            ld l, a
            xor a
            ld [hl+], a
            ld [hl], a
            ld a, l
            sub 2
            ld l, a
            inc [hl]
            dec l
            ld a, [hl]
            dec l
            dec l
            ld [hl], a
            ret
; $xF a spin: a quarter turn every 8 frames, twice round (3B/AC64)
fx_spin:    xor a
            ld [fx_74], a
.f:         ld hl, fcnt
            inc [hl]
            ld a, [hl]
            and 7
            cp 7
            ld a, 0
            ld hl, fx_74
            adc a, [hl]
            ld [hl], a
            cp 8
            ret nc
            and 3
            add a, low(FX3B_DANCE - $E8)
            ld l, a
            ld h, high(FX3B_DANCE - $E8)
            ld a, CUTD2
            call rd_byte
            add a, a
            add a, a
            add a, a
            ld b, a
            ld a, [fx_slot]
            add a, $0E
            ld l, a
            ld h, high(N_OBJ)
            ld [hl], b
            call npc_drawall
            call wait_vbl
            jr .f
; $xE a circle (the dance's first $32 steps, a step every other frame)
fx_circle:  xor a
            ld [fx_74], a
.f:         ld hl, fcnt
            inc [hl]
            ld a, [hl]
            rrca
            ld a, 0
            ld hl, fx_74
            adc a, [hl]
            ld [hl], a
            cp $32
            jr nc, .end
            ld e, a
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
            ld b, a
            ld a, [fx_slot]
            add a, 6
            ld l, a
            ld h, high(N_OBJ)
            ld a, [fx_tt]
            ld [hl+], a
            ld a, [fx_tt + 1]
            ld [hl], a
            ld a, l
            add a, 7
            ld l, a
            ld [hl], b
            call npc_drawall
            call wait_vbl
            jr .f
.end:       ld a, [fx_slot]
            add a, 6
            ld l, a
            ld h, high(N_OBJ)
            xor a
            ld [hl+], a
            ld [hl], a
            ret

section wram, $CC00
fx_slot:    ds 1
fx_ssx:      ds 1
fx_tt:       ds 3
fx_wok:     ds 1
fx_w:       ds 16
fx_74:      ds 1
fx_75:      ds 1
