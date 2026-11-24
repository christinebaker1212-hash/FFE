; FF1 native engine: Extras from the title menu (owner's list, 2026-11-24): the sound test (every
; one of FF1's 24 songs, from the user's ROM through our music engine) and the bestiary (the
; monsters met in battle, kept for all save files). Our own code; code bank EXTRA_BANK.
EXTRA_BANK = 107
ST_FIRST   = $41            ; FF1's songs $41-$58
ST_N       = 24

section bank 107, $4000
ex_menu:    xor a
            ld [ex_cur], a
.re:        call scr_open
            ld bc, $0000
            ld de, $1403
            call scr_win
            ld bc, $0101
            ld hl, ex_title
            call pen_at
            call pen_str
            ld bc, $0003
            ld de, $140F
            call scr_win
            ld bc, $0405
            call pen_at
            ld hl, ex_l0
            call pen_str
            ld bc, $0407
            call pen_at
            ld hl, ex_l1
            call pen_str
            call scr_show
.l:         ld a, [ex_cur]                  ; the hand at row 5 + 2 n
            add a, a
            add a, 5
            ld c, a
            ld b, 4
            call cur_txt
            call scr_frame
            ldh a, [pad_new]
            bit 1, a
            ret nz
            bit 0, a
            jr nz, .a
            and $C0
            jr z, .l
            ld a, [ex_cur]
            xor 1
            ld [ex_cur], a
            jr .l
.a:         ld a, [ex_cur]
            and a
            jr nz, .b
            call st_main
            jr .re
.b:         call bs_main
            jr .re
ex_title:   db "Extras", 0
ex_l0:      db "Sound Test", 0
ex_l1:      db "Bestiary", 0

; ---- the sound test: left / right a song, A plays it, B back
st_main:    call scr_open
            ld bc, $0000
            ld de, $1403
            call scr_win
            ld bc, $0101
            call pen_at
            ld hl, st_title
            call pen_str
            ld bc, $0003
            ld de, $140F
            call scr_win
            ld bc, $0205
            call pen_at
            ld hl, st_l0
            call pen_str
            ld bc, $020A
            call pen_at
            ld hl, st_h0
            call pen_str
            ld bc, $020C
            call pen_at
            ld hl, st_h1
            call pen_str
            ld bc, $020E
            call pen_at
            ld hl, st_h2
            call pen_str
            call .num
            call scr_show
.l:         ld bc, $0805                    ; (the hand before the number)
            call cur_txt
            call scr_frame
            ldh a, [pad_new]
            bit 1, a
            jr nz, .x
            bit 0, a
            jr nz, .play
            ld b, 1
            bit 4, a
            jr nz, .ch
            ld b, ST_N - 1
            bit 5, a
            jr z, .l
.ch:        ld a, [st_i]                    ; (wraps)
            add a, b
            cp ST_N
            jr c, .s
            sub ST_N
.s:         ld [st_i], a
            call .num
            call scr_upd
            jr .l
.play:      ld a, [st_i]
            add a, ST_FIRST
            call snd_track
            jr .l
.x:         ret
.num:       ld bc, $0A05                    ; the song's number, 01-24, and its count
            call pen_at
            ld a, [st_i]
            inc a
            call nf_a
            ld b, 2
            call pen_num
            ld hl, st_of
            jp pen_str
st_title:   db "Sound Test", 0
st_l0:      db "Song", 0
st_of:      db " / 24", 0
st_h0:      db "Left/Right: song", 0
st_h1:      db "A Button: play", 0
st_h2:      db "B Button: back", 0

bs_main:    ret                             ; (the bestiary: next)

; the title menu's up / down: Continue 0, New Game 1, Extras 3 (Continue left out while there is
; nothing to continue)
ng_ud:      ldh a, [pad_new]
            ld b, a
            ld a, [ng_cur]
            bit 6, b
            jr nz, .u
            inc a
            cp 2
            jr nz, .d1
            inc a
.d1:        cp 4
            jr c, .z
            xor a
            jr .z
.u:         dec a
            cp 2
            jr nz, .u1
            dec a
.u1:        cp $FF
            jr nz, .z
            ld a, 3
.z:         and a
            jr nz, .s
            ld a, [ng_lock]
            and a
            ld a, 0
            jr z, .s
            bit 6, b
            ld a, 3
            jr nz, .s
            ld a, 1
.s:         ld [ng_cur], a
            ret

section wram, $C996
ex_cur:     ds 1
st_i:       ds 1
