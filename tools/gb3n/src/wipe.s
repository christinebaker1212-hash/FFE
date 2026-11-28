; ---- FF3's screen wipes (3E/D066 / D08C normal maps, 3E/CF79 / CF9F world maps) and the
; Color-only message (moved here from bank 0)
;
; Normal maps: black curtains from the top and the bottom close on the middle (wipe out) or
; open from it (wipe in). World maps: the picture splits at the middle and its halves slide
; apart over black (out), or come together (in). FF3 moves the edges 3 lines a frame. On the
; GB the black is the window layer (its map's attributes palette 7, all colours black while it
; covers the picture) switched on / off at the edges by the LY interrupt; the world map's lower
; half by a second SCY. The V-Blank and STAT handlers call wp_vbl9 / wp_stat9 here (bank 0
; trampolines: main.s wp_vbl0, text.s stat_isr).

; the Color-only message (the Game Pak needs a Game Boy Color): the font and the lines from
; MENU_BANK through rd_copy (bank 0), the message centred, then halt (LCD off only in V-Blank)
dmg_msg9:   ldh a, [rLCDC]
            bit 7, a
            jr z, .off
.w:         ldh a, [rLY]
            cp 144
            jr nz, .w
            xor a
            ldh [rLCDC], a
.off:       ld hl, $6400                    ; the font -> $8700 (2304 bytes)
            ld de, $8700
            ld bc, 144 * 16
            ld a, MENU_BANK
            call rd_copy
            ld hl, $9800                    ; the map: blanks
            ld bc, $400
.m:         ld a, $FF
            ld [hl+], a
            dec bc
            ld a, b
            or c
            jr nz, .m
            ld hl, $6D00                    ; the lines (row, column, codes, 0; 0 ends) -> $C000
            ld de, $C000
            ld bc, $100
            ld a, MENU_BANK
            call rd_copy
            ld hl, $C000
.l:         ld a, [hl+]
            and a
            jr z, .on
            ld e, a                         ; DE = $9800 + 32 row + column
            ld d, 0
            sla e
            rl d
            sla e
            rl d
            sla e
            rl d
            sla e
            rl d
            sla e
            rl d
            ld a, [hl+]
            add a, e
            ld e, a
            ld a, d
            add a, $98
            ld d, a
.c:         ld a, [hl+]
            and a
            jr z, .l
            ld [de], a
            inc de
            jr .c
.on:        ld a, $C0                       ; colour 2 white, 3 black
            ldh [$FF47], a                  ; (BGP)
            xor a
            ldh [rSCX], a
            ldh [rSCY], a
            ldh [rIE], a
            ld a, %10010001
            ldh [rLCDC], a
.h:         halt
            jr .h

; ---- the wipes (main thread). A = 1 for the world map's split, 0 for the curtains
; out: the picture closes to black
wipe_out9:  call wp_prep
            xor a
            ld [wp_top], a
            ld a, 144
            ld [wp_bot], a
            ld a, [wp_split]                ; (the split: the gap from the middle)
            and a
            jr z, .go
            ld a, 72
            ld [wp_top], a
            ld [wp_bot], a
.go:        ld a, 1
            ld [wp_on], a
.l:         call wait_vbl
            call wp_step
            jr nz, .l
            call wait_vbl                   ; (the last band shown; then the window over it all,
            xor a                           ;   set here too: it holds through the load even
            ldh [rWY], a                    ;   when a V-Blank comes late)
            ld a, 7
            ldh [rWX], a
            ldh a, [rLCDC]
            set 5, a
            ldh [rLCDC], a
            ld a, 100
            ldh [rLYC], a
            ld hl, pal_sh                   ; (every palette black, uploaded by the next V-Blank
            ld de, 128                      ;   before the load starts: it blackens them anyway)
            call memclr
            ld a, 1                         ; (twice: an upload the edge's sound frame pushed out
            ldh [pal_dirty], a              ;   of the V-Blank is dropped by the hardware)
            call wait_vbl
            ld a, 1
            ldh [pal_dirty], a
            jp wait_vbl
; in: the new picture (drawn behind black) opens from the middle
wipe_in9:   call wp_hide
            ld hl, pal_sh + 56              ; (BG palette 7 black while it covers: the world
            ld de, wp_psav                  ;   map's colours kept, put back after)
            ld bc, 8
            call memcpy
            call wp_p7
            ld a, 72
            ld [wp_top], a
            ld [wp_bot], a
            ld a, [wp_split]
            and a
            jr z, .go
            xor a
            ld [wp_top], a
            ld a, 144
            ld [wp_bot], a
.go:        ld a, 1
            ld [wp_on], a
.l:         call wait_vbl
            call wp_istep
            jr nz, .l
            call wait_vbl
            xor a
            ld [wp_on], a
            ld hl, wp_psav
            ld de, pal_sh + 56
            ld bc, 8
            call memcpy
            ld a, 1
            ldh [pal_dirty], a
            ldh a, [scy]                    ; (the scroll and the dialogue's LY line back)
            ldh [rSCY], a
            ld a, WIN_LINE - 1
            ldh [rLYC], a
            ret

; the sprites hidden, the window's map attributes palette 7 (black: palette 7 all colours 0)
wp_prep:    call wp_hide
            call wp_p7
            ld a, CODE6                     ; (the window's attributes: rows 0-17, by DMA)
            ld [vc_src], a
            ld hl, wp_attr
            ld de, $9C00
            ld b, 36
            ld a, 1
            jp vcopyx
wp_p7:      ld hl, pal_sh + 56              ; BG palette 7 black
            ld b, 8
            xor a
.p:         ld [hl+], a
            dec b
            jr nz, .p
            ld a, 1
            ldh [pal_dirty], a
            ret
wp_hide:    ld hl, oam_buf
            ld b, 40
            jp oam_hide.l0

; one frame of the wipe out: the edges 3 lines further (NZ while not done)
wp_step:    ld a, [wp_split]
            and a
            jr nz, .s
            ld a, [wp_top]                  ; curtains: top + 3, bottom - 3 until they meet
            add a, 3
            ld [wp_top], a
            ld b, a
            ld a, [wp_bot]
            sub 3
            ld [wp_bot], a
            cp b
            jr z, .end
            jr c, .end
            or 1
            ret
.end:       ld a, 72
            ld [wp_top], a
            ld [wp_bot], a
            xor a
            ret
.s:         ld a, [wp_top]                  ; split: top - 3, bottom + 3 until off the screen
            sub 3
            jr nc, .s1
            xor a
.s1:        ld [wp_top], a
            ld a, [wp_bot]
            add a, 3
            cp 144
            jr c, .s2
            ld a, 144
.s2:        ld [wp_bot], a
            ld a, [wp_top]
            and a
            ret nz
            ld a, [wp_bot]
            cp 144
            ret
; one frame of the wipe in (the reverse; NZ while not done)
wp_istep:   ld a, [wp_split]
            and a
            jr nz, .s
            ld a, [wp_top]
            sub 3
            jr nc, .c1
            xor a
.c1:        ld [wp_top], a
            ld a, [wp_bot]
            add a, 3
            cp 144
            jr c, .c2
            ld a, 144
.c2:        ld [wp_bot], a
            ld a, [wp_top]
            and a
            ret nz
            ld a, [wp_bot]
            cp 144
            ret
.s:         ld a, [wp_top]
            add a, 3
            cp 72
            jr c, .s1
            ld a, 72
.s1:        ld [wp_top], a
            ld a, [wp_bot]
            sub 3
            cp 72
            jr nc, .s2
            ld a, 72
.s2:        ld [wp_bot], a
            ld a, [wp_top]
            cp 72
            ret

; ---- V-Blank (first thing in the handler): the window, and the frame's list of LY interrupts:
; the edges and the sound's frame (once a frame, early: run at an edge low on the screen, it
; held the V-Blank interrupt past the V-Blank and the frame showed without the wipe)
WA_SND      = 0                             ; actions: the sound only
WA_TOP      = 1                             ;   curtains' top: the window off
WA_BOT      = 2                             ;   curtains' bottom: the window on
WA_SPL      = 3                             ;   split, the gap's bottom: the window off, SCY
WA_S        = $80                           ;   (+ the sound after it)
wp_vbl9:    xor a
            ld [wp_i], a
            ld [wp_n], a
            ldh [rWY], a
            ld a, 7
            ldh [rWX], a
            ld a, [wp_top]
            ld b, a
            ld a, [wp_bot]
            ld c, a
            ld a, [wp_split]
            and a
            jr nz, .split
            ld a, c                         ; curtains: black above the top, below the bottom
            cp b
            jr z, .all
            jr c, .all
            ld a, b
            and a
            jr z, .notop
            call .won
            ld a, b
            dec a
            ld d, a
            ld e, WA_TOP | WA_S
            call .add
            ld a, c
            cp 144
            jr nc, .go
            dec a
            ld d, a
            ld e, WA_BOT
            call .add
            jr .go
.notop:     call .woff
            ld a, c
            cp 144
            jr nc, .snd
            call .s19
            ld a, c
            dec a
            ld d, a
            ld e, WA_BOT
            call .add
            jr .go
.all:       call .won
.snd:       ld d, 100                       ; (no edge: the sound's line only)
            ld e, WA_SND | WA_S
            call .add
            jr .go
.split:     ld a, c                         ; split: the gap [top, bottom) black (the window
            cp b                            ;   from WY = top), the upper half shifted up
            jr nz, .gap
            call .woff                      ; (no gap: the whole picture)
            jr .snd
.gap:       ld a, 72
            sub b
            ld d, a
            ldh a, [scy]
            add a, d
            ldh [rSCY], a
            ld a, b
            ldh [rWY], a
            call .won
            ld a, c
            cp 144
            jr nc, .snd
            call .s19
            ld a, c
            dec a
            ld d, a
            ld e, WA_SPL
            call .add
.go:        ld a, [wp_l]                    ; the first interrupt's line
            ldh [rLYC], a
            ret
.s19:       ld d, 19
            ld e, WA_SND | WA_S
.add:       ld a, [wp_n]                    ; D = line, E = action
            ld l, a
            inc a
            ld [wp_n], a
            ld h, 0
            push de
            ld de, wp_l
            add hl, de
            pop de
            ld [hl], d
            ld a, l
            add a, 3
            ld l, a
            jr nc, .ad1
            inc h
.ad1:       ld [hl], e
            ret
.won:       ldh a, [rLCDC]
            set 5, a
            ldh [rLCDC], a
            ret
.woff:      ldh a, [rLCDC]
            res 5, a
            ldh [rLCDC], a
            ret

; ---- STAT: this entry's action in its line's H-Blank, the next entry's line. A = 1: the
; sound's frame after it
wp_stat9:   ld a, [wp_i]
            ld b, a
            ld a, [wp_n]
            cp b
            jr z, .none                     ; (past the list: nothing)
            ld a, b
            add a, low(wp_a)
            ld l, a
            ld a, high(wp_a)
            adc a, 0
            ld h, a
            ld c, [hl]                      ; C = action
            inc b
            ld a, b
            ld [wp_i], a
            ld a, [wp_n]
            cp b
            jr z, .nl
            ld a, b
            add a, low(wp_l)
            ld l, a
            ld a, high(wp_l)
            adc a, 0
            ld h, a
            ld a, [hl]
            ldh [rLYC], a                   ; (the next one: later in this frame)
.nl:        ld a, c
            and $7F
            jr z, .ret                      ; (the sound only)
.w:         ldh a, [rSTAT]
            and 3
            jr nz, .w
            ld a, c
            and $7F
            cp WA_TOP
            jr z, .off
            cp WA_BOT
            jr z, .on
            ldh a, [rLCDC]                  ; WA_SPL: the window off, the lower half's scroll
            res 5, a                        ;   SCY + 72 - bottom
            ldh [rLCDC], a
            ld a, [wp_bot]
            ld b, a
            ld a, 72
            sub b
            ld b, a
            ldh a, [scy]
            add a, b
            ldh [rSCY], a
            jr .ret
.off:       ldh a, [rLCDC]
            res 5, a
            ldh [rLCDC], a
            jr .ret
.on:        ldh a, [rLCDC]
            set 5, a
            ldh [rLCDC], a
.ret:       ld a, c
            rlca
            and 1
            ret
.none:      xor a
            ret

section wram, $C321
wp_on:      ds 1
wp_top:     ds 1
wp_bot:     ds 1
wp_st:      ds 1
wp_split:   ds 1
wp_psav:    ds 8
wp_i:       ds 1
wp_n:       ds 1
wp_l:       ds 3
wp_a:       ds 3
