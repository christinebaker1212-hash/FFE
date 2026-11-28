; ---- sts.s (bank CODE11): the Status screen (FF3 3C/89xx, rebuilt for the owner's polish pass,
; 2026-11-28; FF1's way: left / right the next member). Header (0,0,20,5): picture, name, job; LV
; and Proficiency (the job level) on the right. Values (0,5,20,13): HP; MP of the eight levels (two
; rows); EXP and To next level; then two columns: Strength .. Spirit, and Attack (multiplier x
; power), Hit rate, Defense (multiplier x defense), Evasion rate, Magic defense, Magic evasion. The
; values are FF3's (menu.s stx_vals, st_*). A or B: back.

; A = member (0-3)
sts_open:   ld [sts_m], a
            call oam_hide
.re:        call sts_draw
            call u_flush
            call u_fadein
.l:         call wait_vbl
            call u_keys
            ld a, [m_new]
            and 3
            jr nz, .x
            ld a, [m_new]
            and $30
            jr z, .l
            ld b, 1                         ; right: the next member, left: the one before
            bit 4, a
            jr nz, .n
            ld b, 3
.n:         ld a, [sts_m]
            add a, b
            and 3
            ld [sts_m], a
            ld a, $98
            ld [S49], a
            call u_fadeout
            jr .re
.x:         ld a, $85
            ld [S49], a
            call u_fadeout
            jp oam_hide

; the screen
sts_draw:   call oam_hide
            call u_cls
            ld bc, $0000
            ld de, $1405
            call u_box
            ld bc, $0005
            ld de, $140D
            call u_box
            ld a, [sts_m]                   ; FF3's derived values
            ld [mgm_t], a
            ld a, CODE1
            ld hl, stx_valt
            call far_call
            ld a, [sts_m]
            ld [u_k], a
            rrca
            rrca
            ld [sts_o], a
            ld bc, $1008                    ; the picture, name, job
            call u_pic
            ld a, [sts_o]
            add a, 6
            ld l, a
            ld h, high(GS + $100)
            ld de, mn_buf
            ld b, 6
.nm:        ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .nm
            xor a
            ld [de], a
            ld a, UP_WHITE
            ld [u_pal], a
            ld bc, $0401
            ld hl, mn_buf
            call u_text
            ld a, [sts_o]
            ld l, a
            ld h, high(GS + $100)
            ld a, [hl]
            and $3F
            add a, a
            ld e, a
            ld d, 0
            ld hl, U_JOBN
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld bc, $0403
            call u_text
            ld hl, U_LV                     ; LV, Proficiency (FF3: $6101 + 1, $6110 + 1)
            ld bc, $0B01
            call sts_lab
            ld a, $01
            ld bc, $1301
            call sts_b1
            ld a, 0
            ld bc, $0B02
            call sts_word
            ld a, $10
            ld bc, $1302
            call sts_b1
            ld hl, U_HP                     ; HP cur / max ($610C, $610E)
            ld bc, $0106
            call sts_lab
            ld a, [sts_o]
            add a, $0C
            ld l, a
            ld h, high(GS + $100)
            ld a, [hl+]
            ld e, a
            ld a, [hl+]
            ld d, a
            ld a, [hl+]
            ld c, a
            ld b, [hl]
            call sts_frac
            ld bc, $1306
            call u_textr
            ld a, 14                        ; MP: levels 1-4 on row 7, 5-8 on row 8
            ld bc, $0107
            call sts_word
            xor a
            ld [sts_t], a
.mp:        ld a, [sts_t]
            add a, a
            ld b, a
            ld a, [sts_o]
            add a, $30
            add a, b
            ld l, a
            ld h, high(GS + $100)
            ld e, [hl]
            inc l
            ld c, [hl]
            ld d, 0
            ld b, d
            call sts_frac
            ld a, [sts_t]                   ; ending at cell 7 + 4 (level & 3), row 7 + level / 4
            ld c, a
            and 3
            add a, a
            add a, a
            add a, 7
            ld b, a
            ld a, c
            srl a
            srl a
            add a, 7
            ld c, a
            call u_textr
            ld hl, sts_t
            inc [hl]
            ld a, [hl]
            cp 8
            jr nz, .mp
            ld a, 13                        ; EXP ($6103, 24 bits)
            ld bc, $0109
            call sts_word
            ld a, [sts_o]
            add a, 3
            ld l, a
            ld h, high(GS + $100)
            ld a, [hl+]
            ld e, a
            ld a, [hl+]
            ld d, a
            ld c, [hl]
            call mn_gil
            ld bc, $1309
            call u_textr
            ld a, 6                         ; To next level
            ld bc, $010A
            call sts_word
            ld a, [stx_buf]
            ld e, a
            ld a, [stx_buf + 1]
            ld d, a
            ld a, [stx_buf + 2]
            ld c, a
            call mn_gil
            ld bc, $130A
            call u_textr
            ld a, 1                         ; the five stats ($6117-$611B)
.st:        ld [sts_t], a
            add a, $0A
            ld c, a
            ld b, 1
            ld a, [sts_t]
            call sts_word
            ld a, [sts_t]
            add a, $16
            ld b, a
            ld a, [sts_t]
            add a, $0A
            ld c, a
            ld a, b
            ld b, 9
            call sts_b0
            ld a, [sts_t]
            inc a
            cp 6
            jr c, .st
            ld a, 7                         ; Attack: n x power
            ld bc, $0A0B
            call sts_word
            ld a, [stx_buf + 3]
            ld hl, stx_buf + 4
            ld c, $0B
            call sts_mult
            ld a, 8                         ; Hit rate %
            ld bc, $0A0C
            call sts_word
            ld a, [stx_buf + 6]
            ld c, $0C
            call sts_pct
            ld a, 9                         ; Defense: n x defense
            ld bc, $0A0D
            call sts_word
            ld a, [stx_buf + 7]
            ld hl, stx_buf + 8
            ld c, $0D
            call sts_mult
            ld a, 10                        ; Evasion rate %
            ld bc, $0A0E
            call sts_word
            ld a, [stx_buf + 10]
            ld c, $0E
            call sts_pct
            ld a, 11                        ; Magic defense
            ld bc, $0A0F
            call sts_word
            ld a, [stx_buf + 11]
            ld e, a
            ld d, 0
            call u_ntoa
            ld bc, $130F
            call u_textr
            ld a, 12                        ; Magic evasion %
            ld bc, $0A10
            call sts_word
            ld a, [stx_buf + 12]
            ld c, $10
            call sts_pct
            ld a, 1
            ld [m_dirty], a
            ret

; word A of U_STW at (B, C), label colour; then white for the value
sts_word:   push bc
            add a, a
            ld e, a
            ld d, 0
            ld hl, U_STW
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            pop bc
sts_lab:    ld a, UP_LABEL
            ld [u_pal], a
            call u_text
            ld a, UP_WHITE
            ld [u_pal], a
            ret
; the member's byte $6100 + A (+1: sts_b1), ending at cell B, row C
sts_b1:     push bc
            call sts_byte
            inc e
            jr sts_b0.n
sts_b0:     push bc
            call sts_byte
.n:         ld d, 0
            call u_ntoa
            pop bc
            jp u_textr
sts_byte:   ld b, a
            ld a, [sts_o]
            add a, b
            ld l, a
            ld h, high(GS + $100)
            ld e, [hl]
            ret
; "n x v" (A = n, HL -> v 16 bits) ending at cell 19, row C
sts_mult:   push bc
            push hl
            ld e, a
            ld d, 0
            call u_ntoa
            ld de, mn_buf
            call sts_cp
            ld a, $BB                       ; "x"
            ld [de], a
            inc de
            ld a, $FF
            ld [de], a
            inc de
            pop hl
            push de
            ld a, [hl+]
            ld e, a
            ld d, [hl]
            call u_ntoa
            pop de
            call sts_cp
            xor a
            ld [de], a
            pop bc
            ld b, 19
            ld hl, mn_buf
            jp u_textr
; "v%" (A = v) ending at cell 19, row C
sts_pct:    push bc
            ld e, a
            ld d, 0
            call u_ntoa
            ld de, mn_buf
            call sts_cp
            ld a, $C6
            ld [de], a
            inc de
            xor a
            ld [de], a
            pop bc
            ld b, 19
            ld hl, mn_buf
            jp u_textr
; "cur/max" (DE, BC) -> HL = mn_buf
sts_frac:   push bc
            call u_ntoa
            ld de, mn_buf
            call sts_cp
            ld a, $C7
            ld [de], a
            inc de
            pop bc
            push de
            ld d, b
            ld e, c
            call u_ntoa
            pop de
            call sts_cp
            xor a
            ld [de], a
            ld hl, mn_buf
            ret
; the string at HL (0 ends) -> DE (DE at its end, no terminator)
sts_cp:     ld a, [hl+]
            and a
            ret z
            ld [de], a
            inc de
            jr sts_cp

section wram, $C6B0                         ; (after sight.s's: to $C6BF)
sts_m:      ds 1
sts_o:      ds 1
sts_t:      ds 1
stx_buf:    ds 13
