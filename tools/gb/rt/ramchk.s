; ---- boot: cart RAM banking check (bank DYN_BANK, called from boot with the LCD off and
; cart RAM enabled). The game keeps work data in cart RAM banks 0-3 (32 KB, MBC5); a flash
; cart that does not bank its save RAM would mix them up and corrupt the game, so then a
; message is shown instead of running. Each bank's byte at $BFF0 is saved, a marker
; written to every bank, read back, and the bytes restored. Uses WRAM $C010-$C013.
section bank DYN_BANK, $7000
ramchk:     ld hl, $C010
            ld c, 0
.sv:        ld a, c
            ld [$4000], a
            ld a, [$BFF0]
            ld [hl+], a
            inc c
            ld a, c
            cp 4
            jr nz, .sv
            ld c, 0
.wr:        ld a, c
            ld [$4000], a
            add a, $A5
            ld [$BFF0], a
            inc c
            ld a, c
            cp 4
            jr nz, .wr
            ld c, 0
            ld d, 0
.vf:        ld a, c
            ld [$4000], a
            add a, $A5
            ld e, a
            ld a, [$BFF0]
            cp e
            jr z, .ok
            inc d
.ok:        inc c
            ld a, c
            cp 4
            jr nz, .vf
            ld hl, $C010
            ld c, 0
.rs:        ld a, c
            ld [$4000], a
            ld a, [hl+]
            ld [$BFF0], a
            inc c
            ld a, c
            cp 4
            jr nz, .rs
            xor a
            ld [$4000], a
            ld a, d
            and a
            ret z
            ; ---- the cart's RAM banks are not separate: the message, then stop
            ld hl, ramchk_font              ; font tiles from tile 0 ($8000)
            ld de, $8000
            ld bc, ramchk_font_end - ramchk_font
.ft:        ld a, [hl+]
            ld [de], a
            inc de
            dec bc
            ld a, b
            or c
            jr nz, .ft
            ld hl, ramchk_text              ; rows: (map offset lo, hi, length, codes)
.ln:        ld a, [hl+]
            ld e, a
            ld a, [hl+]
            ld d, a
            or e
            jr z, .shown
            ld a, [hl+]
            ld b, a
.ch:        ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .ch
            jr .ln
.shown:     ldh a, [is_cgb]
            and a
            jr z, .dmg
            ld a, $80                       ; CGB BG palette 0: black, -, -, white
            ldh [$FF68], a
            ld hl, .pal
            ld b, 8
.pl:        ld a, [hl+]
            ldh [$FF69], a
            dec b
            jr nz, .pl
            jr .on
.dmg:       ld a, $03                       ; colour 0 black, colour 3 white
            ldh [$FF47], a
.on:        xor a
            ldh [$FF42], a
            ldh [$FF43], a
            ld a, %10010001                 ; LCD on, BG tiles $8000, map $9800
            ldh [$FF40], a
.stop:      jr .stop
.pal:       db $00, $00, $00, $00, $00, $00, $FF, $7F
