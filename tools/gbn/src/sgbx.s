; FF1 native engine: Super Game Boy extras (owner's list, 2026-11-24): the border's colours by
; region and the SNES's own sound effects. Regions (sgb.py): world, town, castle, cave, sea,
; sky, Chaos, ice, volcano; a map load into another region sends the border's map and palettes
; again (PCT_TRN, the screen frozen; the tiles stay from boot). Sounds: SOUND packets through
; the queue: Lightning / Quake / Fire bursts, waves while sailing, wind while flying.
SG_RPAL    = $5C00          ; SGB bank: 9 x 32 bytes, palette 4 per region
SG_REGT    = $5E00          ; SGB bank: region of each map (61)

section bank 0, $1FA7
; load_map (DMG / SGB, LCD off): the border's region
sgb_region: ld a, [sgb_on]
            and a
            ret z
            ld a, SGB_BANK
            call sbank
            ldh a, [maptype]                ; (the overworld: region 0)
            and a
            ld a, 0
            jr nz, .r
            ld a, [cur_map]
            add a, low(SG_REGT)
            ld l, a
            ld a, high(SG_REGT)
            adc a, 0
            ld h, a
            ld a, [hl]
.r:         ld hl, sgb_reg
            cp [hl]
            ret z
            ld [hl], a
            ldh a, [rIE]                    ; (the timer only meanwhile: the music plays on,
            push af                         ;   no line interrupt touches LCDC)
            ld a, 4
            ldh [rIE], a
            ld hl, SG_FRZ
            call sgb_send
            ld b, 2
            call sgb_delay
            jp sgb_rt2

section bank 0, $29AF
sgb_rt2:    ld hl, SG_PCT                   ; the map (as boot), this region's palette 4,
            ld de, $8000                    ;   palettes 5-7
            ld bc, $0800
            call memcpy
            ld a, [sgb_reg]
            swap a
            add a, a
            ld l, a
            ld a, high(SG_RPAL)
            adc a, 0
            ld h, a
            ld bc, 32
            call memcpy
            ld hl, SG_PCT + $820
            ld bc, $60
            call memcpy
            ld hl, $9800                    ; tiles 0-255 in order, 20 a row
            ld d, 0
            ld b, 13
.r:         ld c, 20
.c:         ld a, d
            ld [hl+], a
            inc d
            dec c
            jr nz, .c
            ld a, l
            add a, 12
            ld l, a
            jr nc, .nh
            inc h
.nh:        dec b
            jr nz, .r
            jp sgb_rt3

section bank 0, $1EBC
sgb_rt3:    xor a                           ; (the picture unscrolled: the SGB reads it as
            ldh [rSCX], a                   ;   shown; the field sets its scroll again)
            ldh [rSCY], a
            ld a, %11100100
            ldh [rBGP], a
            ld a, %10010001                 ; LCD on, BG tiles $8000, map $9800
            ldh [rLCDC], a
            ld b, 2
            call sgb_delay
            ld hl, SG_PCTTRN
            call sgb_send
            ld b, 4
            call sgb_delay
.wv:        ldh a, [rLY]
            cp 144
            jr c, .wv
            xor a
            ldh [rLCDC], a
            ldh a, [rIF]
            and $FC
            ldh [rIF], a
            pop af
            ldh [rIE], a
            ret

section bank 0, $38AA
; a SOUND packet: A = effect A, B = effect B ($80 stops it), C = pitch / volume
sgb_snd:    push af
            ld a, [sgb_on]
            and a
            jr z, .x
            ld a, [sgb_qi]                  ; (the queue idle: from its start)
            ld hl, sgb_qn
            cp [hl]
            jr nz, .q
            xor a
            ld [sgb_qi], a
            ld [hl], a
.q:         ld a, [sgb_qn]
            cp 6
            jr nc, .x
            call sgb_slot
            ld a, $41
            ld [de], a
            inc de
            pop af
            ld [de], a
            inc de
            ld a, b
            ld [de], a
            inc de
            ld a, c
            ld [de], a
            inc de
            xor a
            ld b, 12
.z:         ld [de], a
            inc de
            dec b
            jr nz, .z
            ret
.x:         pop af
            ret

section bank 0, $2FC0
; the main loop: the ambience (waves on the ship, wind in the airship, else none)
sgb_amb:    ld a, [sgb_on]
            and a
            ret z
            ld b, $80
            ldh a, [maptype]
            and a
            jr z, .s
            ld a, [vehicle]
            ld b, $0B                       ; (wave)
            cp V_SHIP
            jr z, .s
            ld b, $04                       ; (wind)
            cp V_AIR
            jr z, .s
            ld b, $80
.s:         ld a, [sgb_ab]
            cp b
            ret z
            ld a, b
            ld [sgb_ab], a
            xor a
            ld c, $40                       ; (B at medium volume)
            jp sgb_snd
; battles / menus: the ambience off (the main loop sends it again after)
sgb_amb0:   ld a, [sgb_on]
            and a
            ret z
            ld b, $80
            jr sgb_amb.s

section bank 0, $3BC0
; a spell's burst (A = its element bits): Lightning, Quake, Fire
sgb_spell:  ld b, $2F                       ; (lightning)
            bit 6, a
            jr nz, .s
            ld b, $30                       ; (earthquake)
            bit 7, a
            jr nz, .s
            ld b, $22                       ; (fire)
            bit 4, a
            ret z
.s:         ld a, b
            ld b, 0
            ld c, $40
            jp sgb_snd

section wram, $C994
sgb_reg:    ds 1                            ; the border's region now
sgb_ab:     ds 1                            ; the ambience (SOUND effect B) now
