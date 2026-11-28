; ---- Extras (owner, 2026-11-28: FF1's Sound Test and Bestiary in FF3), code bank CODE10, from the
; Select menu: full-screen windows as the field menus (WRAM bank 2 canvas, menu_on). The Sound
; Test plays every one of FF3's 63 songs through the game's own sound driver; the names are ours,
; by where the game plays each song (soundtest.py, from the user's ROM at build time).

ST_N       = 63                 ; FF3's songs (soundtest.py N_SONGS)

ex_open:    call oam_hide
            call menu_pals
            call hand_ld
            call font_menu
            ld a, 2
            ldh [rSVBK], a
            xor a
            ld [ex_cur], a
.draw:      call ex_clear
            ld bc, $0000
            ld de, $1403
            call ex_box
            ld hl, ex_t_ex
            ld bc, $0101
            call ex_str
            ld bc, $0003
            ld de, $140F
            call ex_box
            ld hl, ex_t_st
            ld bc, $0405
            call ex_str
            call ex_show
.l:         ld a, [ex_cur]                  ; the hand at row 5 + 2 n
            add a, a
            add a, 5
            ld c, a
            ld b, 4
            call ex_hand
            call ex_keys
            bit 1, a
            jr nz, .x
            bit 0, a
            jr z, .l
            call st_main
            jr .draw
.x:         call ex_hoff
            call font_back
            xor a
            ld [menu_on], a
            jp wait_vbl

; ---- the Sound Test (as FF1's): left / right a song, A plays it, B back (the map's song again)
st_main:    call ex_clear
            ld bc, $0000
            ld de, $1403
            call ex_box
            ld hl, ex_t_st
            ld bc, $0101
            call ex_str
            ld bc, $0003
            ld de, $140F
            call ex_box
            ld hl, ex_song
            ld bc, $0405
            call ex_str
            ld hl, ex_h0
            ld bc, $020B
            call ex_str
            ld hl, ex_h1
            ld bc, $020D
            call ex_str
            ld hl, ex_h2
            ld bc, $020F
            call ex_str
            call .num
            call ex_show
.l:         ld bc, $0405
            call ex_hand
            call ex_keys
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
            call ex_show
            jr .l
.play:      ld a, [st_i]
            call snd_song
            ld hl, ex_now                   ; ("Now playing" under its name)
            ld bc, $0408
            call ex_str
            call ex_show
            jr .l
.x:         jp map_song_r                   ; (the map's song again)
.num:       ld a, [st_i]                    ; the song's number, its count, its name
            inc a
            ld b, 0
.t:         sub 10
            jr c, .t1
            inc b
            jr .t
.t1:        add a, 10 + $80
            ld e, a
            ld a, b
            add a, $80
            ld bc, $0A05
            call m_put
            ld a, e
            inc b
            call m_put
            ld hl, ex_of
            ld bc, $0C05
            call ex_str
            ld hl, ex_blank
            ld bc, $0407
            call ex_str
            ld hl, ex_blank
            ld bc, $0408
            call ex_str
            ld a, [st_i]
            add a, a
            ld l, a
            ld h, 0
            ld de, st_names
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld bc, $0407
            jp ex_str

; ---- helpers (the field menus' are in CODE1)
; the canvas blank (the window colour)
ex_clear:   ld hl, MC_MAP
            ld de, MC_ATTR
            ld bc, 32 * 18
.l:         ld a, $FF
            ld [hl+], a
            ld a, PAL_TXT
            ld [de], a
            inc de
            dec bc
            ld a, b
            or c
            jr nz, .l
            ld a, PAL_TXT
            ld [m_tattr], a
            ret
; a window: B, C = left, top; D, E = width, height
ex_box:     push bc
            ld a, $F7
            call m_put
            ld h, d
            dec h
            dec h
.t:         inc b
            ld a, $F8
            call m_put
            dec h
            jr nz, .t
            inc b
            ld a, $F9
            call m_put
            pop bc
            push bc
            ld l, e
            dec l
            dec l
.m:         inc c
            push bc
            ld a, $FA
            call m_put
            ld a, b
            add a, d
            dec a
            ld b, a
            ld a, $FB
            call m_put
            pop bc
            dec l
            jr nz, .m
            inc c
            ld a, $FC
            call m_put
            ld h, d
            dec h
            dec h
.b:         inc b
            ld a, $FD
            call m_put
            dec h
            jr nz, .b
            inc b
            ld a, $FE
            call m_put
            pop bc
            ret
; the string at HL (0-ended) from column B, row C
ex_str:     ld a, [hl+]
            and a
            ret z
            call m_put
            inc b
            jr ex_str
; the canvas to the screen in the next V-Blank, the window over the whole screen
ex_show:    ld a, 1
            ld [m_dirty], a
            ld [menu_on], a
            jp wait_vbl
; the hand with its fingertip before the text at column B, row C (FF1's rule)
ex_hand:    ld a, b
            add a, a
            add a, a
            add a, a
            sub 16 - 8
            ld b, a
            ld a, c
            add a, a
            add a, a
            add a, a
            add a, 16
            ld c, a
            ld hl, oam_buf + 4 * 36
            ld de, EX_HAND
            call .one                       ; TL
            ld a, c
            add a, 8
            ld c, a
            call .one                       ; BL
            ld a, b
            add a, 8
            ld b, a
            ld a, c
            sub 8
            ld c, a
            call .one                       ; TR
            ld a, c
            add a, 8
            ld c, a
.one:       ld a, c
            ld [hl+], a
            ld a, b
            ld [hl+], a
            ld a, [de]
            inc de
            ld [hl+], a
            ld a, [de]
            inc de
            ld [hl+], a
            ret
ex_hoff:    ld hl, oam_buf + 4 * 36
            ld b, 4
            jp oam_hide.l0
; a frame; A = the new presses (the directions again after 16 frames, then every 4)
ex_keys:    call wait_vbl
            call read_pad
            ldh a, [pad]
            ld b, a
            ld a, [ex_old]
            cpl
            and b
            ld c, a
            ld a, b
            ld [ex_old], a
            and $F0
            jr z, .nr
            ld hl, ex_rep
            inc [hl]
            ld a, [hl]
            cp 16
            jr c, .o
            ld [hl], 12
            ld a, b
            and $F0
            or c
            ld c, a
            jr .o
.nr:        xor a
            ld [ex_rep], a
.o:         ld a, c
            ret

section wram, $C377
ex_cur:     ds 1
st_i:       ds 1
ex_old:     ds 1
ex_rep:     ds 1
