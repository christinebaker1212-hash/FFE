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
wp_vbl9:    ld a, [wp_on]                   ; (2: the menus' window gradient, gr_vbl)
            cp 2
            jp z, gr_vbl
            xor a
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
            ldh a, [scy]                    ; (no gap: the whole picture, unshifted)
            ldh [rSCY], a
            call .woff
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

; ---- FF1's typewriter text for the dialogue box (owner): one page typed a letter at a time,
; about 21 letters a second (90 / 256 a frame, FF1's TW_RATE), twice as fast with A held; then a
; button (fix:ECAB). Each frame the page is drawn again from its start with the letters past
; tw_lim left blank (t_putc); blanks cost no time. tw_more: NZ if another page follows.
TW_RATE    = 90
TW_RT:      db 45, 64, TW_RATE, 140, 0
tw_page9:   ld a, [t_bank]                  ; the page's start
            ld [tw_sb], a
            ld a, [t_ptr]
            ld [tw_sp], a
            ld a, [t_ptr + 1]
            ld [tw_sp + 1], a
            ld a, $FF                       ; (counted: all its letters)
            ld [tw_lim], a
            call .draw
            ld [tw_more], a
            ld a, [tw_cnt]
            ld [tw_tot], a
            xor a
            ld [tw_lim], a
            ld [tw_acc], a
.l:         ld a, [tw_lim]
            ld b, a
            ld a, [tw_tot]
            cp b
            jr c, .done
            jr z, .done
            call .draw
            call wait_vbl
            call read_pad
            ld a, [opt_txt]                 ; (Config's Text Speed: the rate; 5 = a page at once)
            ld e, a
            ld d, 0
            ld hl, TW_RT
            add hl, de
            ld a, [hl]
            and a
            jr z, .done
            ld b, a
            ldh a, [pad]
            bit 0, a                        ; (A held: twice as fast)
            ld a, [tw_acc]
            jr z, .r1
            add a, b
            jr nc, .r1
            ld hl, tw_lim
            inc [hl]
.r1:        add a, b
            ld [tw_acc], a
            jr nc, .l
            ld hl, tw_lim
            inc [hl]
            jr .l
.done:      ld a, $FF
            ld [tw_lim], a
            call .draw
            xor a
            ld [tw_on], a
            jp wait_keys
; the page from its start, letters up to tw_lim; A = NZ if a page follows
.draw:      ld a, [tw_sb]
            ld [t_bank], a
            ld a, [tw_sp]
            ld [t_ptr], a
            ld a, [tw_sp + 1]
            ld [t_ptr + 1], a
            xor a
            ld [tw_cnt], a
            inc a
            ld [tw_on], a
            call win_clear
            call t_page
            ld a, 0
            jr z, .d0
            inc a
.d0:        push af
            ld a, 1
            ld [win_dirty], a
            pop af
            ret

; ---- FF1's encounter transition (owner, 2026-11-28: the fancy battle transition we made for
; FF1; loc.s bt_trans2 there): 8 frames of two white flashes, 24 of the map swirling and drawn in
; towards the party, 16 of its lines parting as the picture folds onto the party's line into
; white; then white while the battle loads. Per-line SCX / SCY from trans.py (TRANS_BANK), written
; in each line's H-Blank by stat_rx (text.s) from page hrx; FF3's encounter sound ($95) as
; btl_flash. The tables in WRAM bank 2 (the menu canvas's bank: free at the battle's start).
TR_P0      = $D8                            ; frame pages: even frames $D8 / $D9, odd $DA / $DB
TR_SAVE    = $DC00                          ; the palettes as they were (128)
TR_WT      = $DD00                          ; the fade to white: 8 levels x 32
TR_FR      = 48
bt_trans9:  ld a, $95                       ; (FF3's encounter sound)
            ld [S49], a
            call ring_fill
            ld a, 2
            ldh [rSVBK], a
            ldh a, [scx]
            ld [xtr_x0], a
            ldh a, [scy]
            ld [xtr_y0], a
            ld hl, pal_sh
            ld de, TR_SAVE
            ld bc, 128
            call memcpy
            ld hl, $7600
            ld de, TR_WT
            ld bc, 256
            ld a, TRANS_BANK
            call rd_copy
            ld hl, oam_buf + 16             ; (the sprites: the party only)
            ld b, 36
            call oam_hide.l0
            xor a
            ld [xtr_k], a
            call xtr_prep                    ; frame 0
            di
            call xtr_page                   ; (the page first: with hrx 0 the handler's other
            ld a, h                         ;   work would run on every line)
            ldh [hrx], a
            ld a, $08                       ; (STAT: mode 0 each line, no LYC meanwhile)
            ldh [rSTAT], a
            ldh a, [rIF]
            and $FD
            ldh [rIF], a
            ei
.f:         call xtr_page                    ; line 0's scroll for the V-Blank to write
            ld l, 0
            ld a, [hl]
            ldh [scx], a
            inc h
            ld a, [hl]
            ldh [scy], a
            call wait_vbl
            call xtr_page                    ; (this frame's lines)
            ld a, h
            ldh [hrx], a
            call snd_frame                  ; (the sound: its LY interrupt is not running)
            ld hl, xtr_k
            inc [hl]
            ld a, [hl]
            cp TR_FR
            jr nc, .end
            call xtr_prep
            jr .f
.end:       ld hl, pal_sh                   ; white
            ld b, 64
.w:         ld a, $FF
            ld [hl+], a
            ld a, $7F
            ld [hl+], a
            dec b
            jr nz, .w
            ld a, 1
            ldh [pal_dirty], a
            call wait_vbl
            di
            xor a
            ldh [hrx], a
            ld a, $40
            ldh [rSTAT], a
            ld a, WIN_LINE - 1
            ldh [rLYC], a
            ldh a, [rIF]
            and $FD
            ldh [rIF], a
            ei
            ld a, [xtr_x0]
            ldh [scx], a
            ld a, [xtr_y0]
            ldh [scy], a
            ld hl, oam_buf
            ld b, 40
            call oam_hide.l0
            ld b, 6
.ww:        push bc
            call wait_vbl
            pop bc
            dec b
            jr nz, .ww
            ret
; H = frame xtr_k's SCX page (L = 0)
xtr_page:    ld a, [xtr_k]
            rrca
            ld hl, TR_P0 << 8
            ret nc
            ld hl, (TR_P0 + 2) << 8
            ret
; frame xtr_k's lines (the tables plus the field's scroll) and its colours
xtr_prep:    ld a, [xtr_k]                    ; HL = $4000 + 288 k
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld a, [xtr_k]
            add a, h
            add a, $40
            ld h, a
            push hl
            call xtr_page
            ld d, h
            ld e, l
            pop hl
            push hl
            push de
            ld bc, 144
            ld a, TRANS_BANK
            call rd_copy
            pop de
            pop hl
            ld bc, 144
            add hl, bc
            inc d
            ld a, TRANS_BANK
            call rd_copy
            call xtr_page
            ld a, [xtr_x0]
            ld d, a
            ld b, 144
.ax:        ld a, [hl]
            add a, d
            ld [hl+], a
            dec b
            jr nz, .ax
            ld l, 0
            inc h
            ld a, [xtr_y0]
            ld d, a
            ld b, 144
.ay:        ld a, [hl]
            add a, d
            ld [hl+], a
            dec b
            jr nz, .ay
            ld a, [xtr_k]                    ; the frame's colour level (0 unchanged, 1 the
            ld l, a                         ;   colours as they were, 2-9 the fade's 1-8)
            ld h, $77
            ld a, TRANS_BANK
            call rd_byte
            and a
            ret z
            dec a
            jr nz, .fd
            ld hl, TR_SAVE
            ld de, pal_sh
            ld bc, 128
            call memcpy
            jr .up
.fd:        dec a                           ; 64 colours through the table (32 (level - 2))
            swap a
            add a, a
            ld [xtr_t], a
            ld hl, TR_SAVE
            ld de, pal_sh
            ld b, 64
.c:         push bc
            ld a, [hl+]
            ld c, a                         ; low: GGGRRRRR
            ld a, [hl+]
            ld b, a                         ; high: 0BBBBBGG
            push hl
            ld a, [xtr_t]
            ld h, high(TR_WT)
            ld l, a
            ld a, c                         ; red
            and 31
            add a, l
            push hl
            ld l, a
            ld a, [hl]
            pop hl
            ld [xtr_r], a
            ld a, b                         ; green
            and 3
            add a, a
            add a, a
            add a, a
            ld [xtr_g], a
            ld a, c
            swap a
            rrca
            and 7
            push hl
            ld hl, xtr_g
            or [hl]
            pop hl
            add a, l
            push hl
            ld l, a
            ld a, [hl]
            pop hl
            ld [xtr_g], a
            ld a, b                         ; blue
            rrca
            rrca
            and 31
            add a, l
            ld l, a
            ld a, [hl]
            add a, a
            add a, a
            ld b, a
            ld a, [xtr_g]
            ld c, a
            swap a
            add a, a
            and $E0
            ld l, a
            ld a, [xtr_r]
            or l
            ld [de], a
            inc de
            ld a, c
            rrca
            rrca
            rrca
            and 3
            or b
            ld [de], a
            inc de
            pop hl
            pop bc
            dec b
            jr nz, .c
.up:        ld a, 1
            ldh [pal_dirty], a
            ret

; the whole 16 x 16 metatile ring around the party (the field draws 12 x 12: the transition's
; twist and zoom show the BG map beyond the view, which held stale cells): two rows a V-Blank
ring_fill:  ld a, [py]
            sub 8
            ld d, a
            ld c, 16
.row:       ld a, [px]
            sub 8
            ld e, a
            ld b, 16
.col:       push bc
            push de
            call q_mt_r
            pop de
            pop bc
            inc e
            dec b
            jr nz, .col
            inc d
            bit 0, c
            jr nz, .nx
            push bc
            push de
            call wait_vbl
            pop de
            pop bc
.nx:        dec c
            jr nz, .row
            ret

; ---- the menus' window gradient (FF1's, owner 2026-11-28; ui.s builds it): wp_on = 2. Records in
; WRAM 2 GR_REC (line, level; a level $FF ends: the frame's sound there), the ramp GR_RMP (16
; colours, the fades applied). Each record: in the H-Blank before its line, colour 2 of BG
; palettes 1-6 (the windows' fill) becomes its level's colour; LYC then the next record's line - 1.
; The V-Blank puts level 0 (the windows' own colour) back and LYC at the first record.
gr_vbl:     ldh a, [rSVBK]
            ld [gr_svb], a
            ld a, 2
            ldh [rSVBK], a
            xor a
            ld [gr_i], a
            ld hl, GR_RMP
            ld a, [hl+]
            ld b, a
            ld d, [hl]
            call gr_put
            ld a, [bv_on]                   ; (a battle: palettes 1-3 are the battlefield's, their
            and a                           ;   colour 2 back from the shadow; the window covers the
            jr z, .nb                       ;   lines where the gradient writes them)
            ld hl, pal_sh + 12
            ld c, low(rBCPS)
            ld a, $8C
.bp:        ld [c], a
            inc c
            ld e, a
            ld a, [hl+]
            ld [c], a
            ld a, [hl+]
            ld [c], a
            dec c
            ld a, l
            add a, 6
            ld l, a
            ld a, e
            add a, 8
            cp $A4
            jr nz, .bp
.nb:        ld a, [GR_REC]                  ; LYC: the first record's line - 1
            dec a
            ldh [rLYC], a
            ld a, 2                         ; (the STAT interrupt: LYC)
            ldh [rIF], a
            xor a
            ldh [rIF], a
            ldh a, [rLCDC]                  ; (the menu: the window on)
            set 5, a
            ldh [rLCDC], a
            ld a, [gr_svb]
            ldh [rSVBK], a
            ret
; colour B (low), D (high) -> colour 2 of BG palettes 1-6
gr_put:     ld c, low(rBCPS)
            ld a, $8C
            call .one
            ld a, $94
            call .one
            ld a, $9C
            call .one
            ld a, $A4
            call .one
            ld a, $AC
            call .one
            ld a, $B4
.one:       ld [c], a
            inc c
            ld a, b
            ld [c], a
            ld a, d
            ld [c], a
            dec c
            ret
section wram, $C6AC                         ; (after Config's settings)
gr_i:       ds 1
gr_svb:     ds 1
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

section wram, $C370                         ; (the encounter transition)
xtr_k:       ds 1
xtr_x0:      ds 1
xtr_y0:      ds 1
xtr_t:       ds 1
xtr_r:       ds 1
xtr_g:       ds 1
tst_btl:    ds 1                            ; (test hook: main.s tst_choc $B0)


