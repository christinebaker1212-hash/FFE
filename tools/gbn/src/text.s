; FF1 native engine: text and the dialogue box. Our own code.
; Font: codes $10-$18 window frame (FF1's tiles from the ROM), $20-$7F our Latin font.
;   CGB: VRAM bank 1, tile = code (attribute: palette 7, bank 1), loaded once at boot.
;   DMG: the map's free BG tiles (per-map table, map bank $7F00), loaded with the map.
; Dialogue: table at DLG_BANK $4000 (256 x bank, address), strings: ASCII, $0A next line,
;   $0C next page, $00 end, $02 the item name.
; The box (the approved layout): 20 x 8 cells in the window layer at the top of the screen,
; text 18 columns x 6 lines from (1, 1); the window is cut off at line 64 by the LYC
; interrupt; the objects under the box are hidden while it shows.


section bank 0, $1800

; boot (LCD off): CGB font into VRAM bank 1, palette 7
text_init:  ldh a, [is_cgb]
            and a
            ret z
            ld a, COMMON
            call sbank
            ld a, 1
            ldh [rVBK], a
            ld hl, C_FONTCGB                ; codes 0-127 -> $9000 + 16 code (bank 1)
            ld de, $9000
            ld bc, 2048
            call memcpy
            xor a
            ldh [rVBK], a
            ld a, $B8                       ; BG palette 7
            ldh [rBCPS], a
            ld hl, C_WINPAL
            ld b, 8
.p:         ld a, [hl+]
            ldh [rBCPD], a
            dec b
            jr nz, .p
            ld a, $A8                       ; BG palette 5: all black (outside the windows)
            ldh [rBCPS], a
            ld b, 8
            xor a
.k:         ldh [rBCPD], a
            dec b
            jr nz, .k
            ret

; load_map (LCD off), DMG: the font into the map's free tiles; the table kept in WRAM
font_map:   ld a, [map_bank]
            call sbank
            ld hl, M_FONT
            ld de, font_tbl
            ld bc, 128
            call memcpy
            ldh a, [is_cgb]
            and a
            ret nz
            ldh a, [maptype]
            and a
            ret nz                          ; (the overworld shows no text box)
            ld c, $01                       ; (icons $01-$1F, frame $10-$18, letters)
.l:         ld a, c                         ; tile for code C
            ld l, a
            ld h, high(font_tbl)
            ld a, [hl]
            and a
            jr z, .n
            call tile_addr                  ; DE = VRAM of BG tile A
            ld a, c                         ; HL = C_FONTDMG + 16 code
            swap a
            ld l, a
            and $0F
            add a, high(C_FONTDMG)
            ld h, a
            ld a, l
            and $F0
            ld l, a
            ld a, COMMON
            call sbank
            push bc
            ld bc, 16
            call memcpy
            pop bc
.n:         inc c
            bit 7, c
            jr z, .l
            ret

; A = BG tile number ($8800 addressing) -> DE = its VRAM address
tile_addr:  push hl
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl                      ; 16 n
            bit 7, a
            ld a, h
            jr nz, .hi
            add a, $90                      ; 0-127: $9000 + 16 n
            jr .s
.hi:        add a, $88 - $08                ; 128-255: $8800 + 16 (n - 128)
.s:         ld d, a
            ld e, l
            pop hl
            ret

; ---- the dialogue box
; open dialogue A: first page into the buffer, the box shown once it is written
dlg_open:   ld l, a                         ; table entry: 3 x id
            ld h, 0
            ld e, l
            ld d, h
            add hl, hl
            add hl, de
            ld de, $4000
            add hl, de
            ld a, DLG_BANK
            call sbank
            ld a, [hl+]
            ld [dlg_bank], a
            ld a, [hl+]
            ld [dlg_ptr], a
            ld a, [hl]
            ld [dlg_ptr + 1], a
            call dlg_page
            ld a, 1
            ld [box_on], a
            ld a, [dlgsfx]                  ; a fanfare / the treasure ditty (FF1 dlgsfx)
            and a
            ret z
            cp 1
            ld a, TR_DLGFAN
            jr z, .t
            ld a, TR_TREAS
.t:         call snd_track
            xor a
            ld [dlgsfx], a
            ret

; the next page into the buffer (from dlg_ptr), upload restarted
dlg_page:   ld hl, win_buf                  ; frame and blank inside
            ld bc, $1011                    ; top: UL, top x 18, UR
            ld d, $12
            call .row3
            ld e, 6
.mid:       ld bc, $1318                    ; left, blank x 18, right
            ld d, $14
            call .row3
            dec e
            jr nz, .mid
            ld bc, $1516                    ; bottom: DL, bottom x 18, DR
            ld d, $17
            call .row3
            ld a, [dlg_bank]                ; the text
            call sbank
            ld a, [dlg_ptr]
            ld e, a
            ld a, [dlg_ptr + 1]
            ld d, a
            ld hl, win_buf + 21             ; row 1, column 1
            ld b, l                         ; (B: the line's first cell, low byte)
.ch:        ld a, [de]
            inc de
            and a
            jr z, .end
            cp $0C
            jr z, .pg
            cp $0A
            jr z, .nl
            cp $02
            jr z, .item
            call code_tile
            ld [hl+], a
            jr .ch
.item:      push de                         ; the item name (names bank), then the text again
            ld a, NAMES
            call sbank
            ld a, [dlg_item]
            ld e, a
            ld d, 0
            push hl
            ld hl, $4000
            add hl, de
            add hl, de
            ld a, [hl+]
            ld d, [hl]
            ld e, a
            pop hl
.in:        ld a, [de]
            inc de
            and a
            jr z, .ie
            call code_tile
            ld [hl+], a
            jr .in
.ie:        ld a, [dlg_bank]
            call sbank
            pop de
            jr .ch
.nl:        ld a, b                         ; next line: 20 cells on
            add a, 20
            ld b, a
            ld l, a
            ld a, h
            adc a, 0
            ld h, a
            jr .ch
.pg:        ld a, e                         ; more pages
            ld [dlg_ptr], a
            ld a, d
            ld [dlg_ptr + 1], a
            ld a, 1
            ld [dlg_more], a
            jr .up
.end:       xor a
            ld [dlg_more], a
.up:        xor a
            ld [win_up], a
            ret
.row3:      ld a, b                         ; B, then C x 18, then D
            call code_tile
            ld [hl+], a
            ld a, c
            call code_tile
            push bc
            ld b, 18
.r:         ld [hl+], a
            dec b
            jr nz, .r
            pop bc
            ld a, d
            call code_tile
            ld [hl+], a
            ret

; A = code -> A = tile (CGB: the code itself, in VRAM bank 1; DMG: the map's table)
code_tile:  push hl
            ld l, a
            ldh a, [is_cgb]
            and a
            ld a, l
            jr nz, .c
            ld h, high(font_tbl)
            ld a, [hl]
.c:         pop hl
            ret

; V-Blank: up to 4 box rows to the window map (CGB: and their attributes); then shown
box_vbl:    ld a, [box_on]
            and a
            jr nz, .on
            ldh a, [rLCDC]                  ; closed: window off
            res 5, a
            ldh [rLCDC], a
            ret
.on:        ld a, [win_up]
            cp 8
            jr nc, .show
            ld c, 4
.r:         ldh a, [rLY]                    ; (only while V-Blank lasts: LY 144-150)
            sub 144
            cp 7
            ret nc
            ld a, [win_up]                  ; row: win_buf + 20 row -> $9C00 + 32 row
            ld e, a
            add a, a
            add a, a
            add a, e                        ; 5 row
            add a, a
            add a, a                        ; 20 row
            ld l, a
            ld h, high(win_buf)
            ld a, e
            swap a
            add a, a                        ; 32 row (row < 8)
            ld e, a
            ld d, $9C
            push de
            ld b, 20
.c:         ld a, [hl+]
            ld [de], a
            inc e
            dec b
            jr nz, .c
            pop de
            ldh a, [is_cgb]
            and a
            jr z, .na
            ld a, 1
            ldh [rVBK], a
            ld a, WIN_ATTR
            ld b, 20
.at:        ld [de], a
            inc e
            dec b
            jr nz, .at
            xor a
            ldh [rVBK], a
.na:        ld hl, win_up
            inc [hl]
            ld a, [hl]
            cp 8
            jr nc, .show
            dec c
            jr nz, .r
            ret
.show:      ld a, 7                         ; window at the top, cut at line 64 (STAT)
            ldh [rWX], a
            xor a
            ldh [rWY], a
            call lcd_get                    ; (not while the LCD is off)
            bit 7, a
            ret z
            ld a, LCDC_WIN
            ldh [rLCDC], a
            ret

; STAT (LYC = 64): the window off below the box
stat_int:   push af
            ld a, [lmask]                   ; (a masked load: held through mode 3)
            and a
            jr nz, .gd
            ld a, [ly_n]                    ; (a list of LCDC changes by line: the story's
            and a                           ;   shutters)
            jr nz, .ly
            ld a, [wp_on]                   ; (a screen wipe: the band's edges)
            and a
            jr nz, .wp
            ldh a, [rLCDC]                  ; (a request left pending while the LCD went off:
            bit 7, a                        ;   it stays off)
            jr z, .off
            ld a, [lcdc_on]
            ldh [rLCDC], a
.off:
.mus:       push bc                         ; and the music, once a frame, here (mid-frame:
            push de                         ;   V-Blank stays free for VRAM writes)
            push hl
            ldh a, [rombank]
            push af
            ld a, SND_BANK
            ld [MBC_BANK], a
            call snd_frame_b
            pop af
            ld [MBC_BANK], a
            pop hl
            pop de
            pop bc
            pop af
            reti
.wp:        ld a, [wp_st]                   ; the band's top: the window off (an empty band:
            and a                           ;   it stays on), the bottom next
            jr nz, .wb
            inc a
            ld [wp_st], a
            ld a, [wp_top]
            push bc
            ld b, a
            ld a, [wp_bot]
            cp b
            pop bc
            jr z, .wm
            jr c, .wm
            ld a, 167                       ; (hidden)
            ldh [rWX], a
            ld a, [wp_bot]
            ldh [rLYC], a
            pop af
            reti
.wb:        cp 2                            ; the bottom: the window shown again; the music
            jr nc, .wm2
            ld a, 7
            ldh [rWX], a
.wm:        ld a, 2
            ld [wp_st], a
            jr .mus
.wm2:       pop af
            reti
.ly:        push hl                         ; this entry's WX (the window shown / hidden),
            ld a, [ly_i]                    ;   the next entry's line; after the last: the
            add a, a                        ;   music
            add a, low(ly_tab) + 1
            ld l, a
            ld h, high(ly_tab)
            ld a, [ly_bgp]                  ; (the prologue's fading line: BGP instead)
            and a
            ld a, [hl+]
            jr nz, .lyg
            ldh [rWX], a
            jr .ly0
.lyg:       ldh [rBGP], a
.ly0:       ld a, [ly_i]
            inc a
            ld [ly_i], a
            push bc
            ld b, a
            ld a, [ly_n]
            cp b
            pop bc
            jr z, .lyl
            ld a, [hl]
            ldh [rLYC], a
            pop hl
            pop af
            reti
.lyl:       pop hl
            jp .mus
.gd:        ld a, [gd_off]                  ; (paused: RAM-only work running)
            and a
            jr nz, .gr
.g1:        ldh a, [rSTAT]                  ; modes 2 / 3: wait
            and 2
            jr nz, .g1
.gr:        pop af
            reti

; the dialogue in progress (main loop): A turns the page or closes the box
dlg_frame:  ldh a, [pad_new]
            bit 0, a
            ret z
            ld a, [win_up]                  ; (not before the page is up)
            cp 8
            ret c
            ld a, [dlg_more]
            and a
            jr z, .close
            jp dlg_page
.close:     xor a
            ld [box_on], a
            call map_music                  ; (after a fanfare: the map's music again)
            jp talk_after                   ; (a teleport / battle the talk asked for)

section wram, $CB00
win_buf:    ds 160
section wram, $CC00
font_tbl:   ds 128                          ; code -> tile (page-aligned)
section wram, $CC80
box_on:     ds 1
win_up:     ds 1
dlg_more:   ds 1
dlg_bank:   ds 1
dlg_ptr:    ds 2
