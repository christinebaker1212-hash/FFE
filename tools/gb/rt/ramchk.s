; ---- boot: cart RAM banking check (bank DYN_BANK, called from boot with the LCD off and
; cart RAM enabled). The game keeps work data in cart RAM banks 0-3 (32 KB, MBC5); a flash
; Game Pak that does not bank its save RAM would mix them up and corrupt the game, so then a
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
            ; ---- the Game Pak's RAM banks are not separate: the message, then stop
            ld hl, ramchk_text
            call msg_show                   ; (lot.s)
.stop:      jr .stop
