; FF1 native engine: place names (owner, 2026-11-22, from the WonderSwan Color remake): a banner
; with the place's name when the party enters a new place (not the world map), the place on the
; main menu; and the play time. Our own code; the names: ui.py LOC_NAMES (bank 99 $7000).

BN_LINES   = 24             ; the banner: window rows 0-2 (LYC cuts it at line 24)
BN_TIME    = 150            ; shown 2.5 seconds
LOC_WORLD  = 27             ; (loc_tab: "World Map", the main menu only)
PT_SAVE    = unsram + $F0   ; play time in the save page (unused by FF1): frames, seconds,
                            ;   minutes, hours (to 99)

section bank 99, $4700

; ---- a new place entered (load_map, the main loop calls it once the map shows): the banner
bn_prep:    ld a, [cur_map]
            call loc_get
            ld b, a
            inc a                           ; (bn_last: the place + 1, 0 none yet)
            ld c, a
            ld a, [bn_last]
            cp c
            ret z
            ld a, c
            ld [bn_last], a
            ld a, b
            cp LOC_WORLD
            ret z
            push hl
            ld hl, win_buf                  ; the box: 3 rows of 20
            ld bc, $1011
            ld d, $12
            call .row
            ld bc, $1318
            ld d, $14
            call .row
            ld bc, $1516
            ld d, $17
            call .row
            pop de                          ; the name, centred on row 1
            ld h, d
            ld l, e
            ld b, 0
.n:         ld a, [hl+]
            and a
            jr z, .nn
            inc b
            jr .n
.nn:        ld a, 18
            sub b
            srl a
            add a, low(win_buf + 21)
            ld l, a
            ld h, high(win_buf)
.c:         ld a, [de]
            inc de
            and a
            jr z, .go
            call code_tile
            ld [hl+], a
            jr .c
.go:        xor a
            ld [win_up], a
            ld a, BN_LINES
            ldh [rLYC], a
            ld a, BN_TIME
            ld [bn_t], a
            ret
.row:       ld a, b                         ; B, C x 18, D
            call code_tile
            ld [hl+], a
            ld a, c
            call code_tile
            ld e, 18
.r:         ld [hl+], a
            dec e
            jr nz, .r
            ld a, d
            call code_tile
            ld [hl+], a
            ret

; map A -> A = name number, HL = the name
loc_get:    cp 61
            ld b, LOC_WORLD
            jr nc, .w
            ld e, a
            ld d, 0
            ld hl, loc_tab
            add hl, de
            ld b, [hl]
.w:         ld l, b
            ld h, 0
            add hl, hl
            ld de, loc_ptr
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld a, b
            ret

; the current place's name -> loc_buf (for the main menu: bank_call from bank 2)
loc_copy:   ld a, [cur_map]
            call loc_get
            ld de, loc_buf
.c:         ld a, [hl+]
            ld [de], a
            inc de
            and a
            jr nz, .c
            ret

section bank 2, $4710                       ; (the main menu's place / play time rows)
; the place (row 14) and the play time (row 15, h:mm ending at column 18)
mm_place:   ld a, F3_BANK
            ld hl, loc_copy
            call bank_call
            ld bc, $010E
            call pen_at
            ld hl, loc_buf
            call pen_str
            ld bc, $010F
            call pen_at
            ld hl, str_ptime
            call pen_str
            ld a, [PT_SAVE + 3]             ; hours: tens, ones
            ld c, 0
.h:         cp 10
            jr c, .h1
            sub 10
            inc c
            jr .h
.h1:        ld e, a
            ld a, c
            and a
            ld b, 15                        ; (h:mm from column 15, hh:mm from 14)
            jr z, .p
            dec b
.p:         push bc
            push de
            ld c, $0F
            call pen_at
            pop de
            pop bc
            ld a, c
            and a
            jr z, .o
            add a, $30
            call pen_ch
.o:         ld a, e
            add a, $30
            call pen_ch
            ld a, $3A
            call pen_ch
            ld a, [PT_SAVE + 2]             ; minutes, two digits
            ld c, 0
.m:         cp 10
            jr c, .m1
            sub 10
            inc c
            jr .m
.m1:        ld e, a
            ld a, c
            add a, $30
            call pen_ch
            ld a, e
            add a, $30
            jp pen_ch

section wram, $CDE3
loc_buf:    ds 19
pt_on:      ds 1                            ; (play time counted: set by the field's loop)
