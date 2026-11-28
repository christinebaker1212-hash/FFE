; ---- ui.s (bank CODE11): the menus' UI library (owner, 2026-11-28: one small font in every menu,
; Nintendo-level polish). The window layer covers the screen (menu_on); its canvas is MC_MAP /
; MC_ATTR in WRAM bank 2 (32 x 18), copied by menu_vbl. Text is drawn in FF1's small font
; (ui.py U_GLY: condensed letters, 3-pixel digits) with a black shadow down-right, into a pool of
; VRAM bank 1 tiles rendered in WRAM bank 7 first. FF1's rules: the hand's left = the text - 16,
; its top = the text's top (the finger then lies on the line's middle, the tip just before it);
; fades between screens. VRAM bank 1 while a menu shows: see the constants below.
U_PIC      = $00                ; the members' pictures: 6 tiles each ($00-$17)
U_ICON     = $18                ; FF3's icons ($18-$37)
U_FR       = $38                ; frames: TL T TR L R BL B BR
U_HAND     = $40                ; the hand ($40-$43)
U_FILL     = $44                ; the windows' fill
U_ZERO     = $45                ; black
U_T0       = $48                ; the text pool ($48-$FF)
U_NPOOL    = 184
U_BUF      = $D000              ; WRAM 7: the pool's tiles
GR_WIN     = $D940              ; (WRAM 2: the windows' top row, height; 8 at most)
GR_NW      = $D950
GR_BASE    = $D960              ;   the ramp (16 x RGB555)
GR_TMP     = $DC00              ;   the records being built (then copied under DI)
U_FBUF     = $D9A0              ; (WRAM 2: u_fstr's string, 96 bytes)
U_LINE     = $DE00              ; WRAM 2: a line's 1-bit rows (8 a tile, 20 tiles)
u_palt     = $DF00              ; WRAM 2: the fades' target palettes (BG 0-7, OBJ 0-7)
u_nbuf     = $DF80              ; WRAM 2: an item's name (17)
UP_WHITE   = 1
UP_LABEL   = 2
UP_YELLOW  = 3
UP_GREEN   = 4
UP_GREY    = 5
UP_RED     = 6

; ---- open: the field faded out, the UI's tiles and palettes in, the canvas cleared and shown
u_open:     call u_fadeout
            call oam_hide
            ld a, 1
            ld [menu_on], a
            ld a, 2
            ldh [rSVBK], a
            ld a, 7
            ldh [rWX], a
            xor a
            ldh [rWY], a
            call u_tiles
            call u_cls
            ld hl, U_PALS                   ; the target palettes
            ld de, u_palt
            ld bc, 128
            call memcpy
            call u_wcol                     ; (Config's window colour, the gradient)
            call u_gron
            jp u_mpal

; the field back: faded out, its tiles and palettes restored, faded in (u_closeb: left black, for
; a map change that follows: Exit / Warp)
u_close:    call u_closeb
            call wait_vbl
            call u_fadein0
            ld a, 1
            ldh [rSVBK], a
            ret
u_closeb:   call u_fadeout
            call u_groff
            call oam_hide
            xor a
            ld [menu_on], a
            call wait_vbl
            ld a, 1
            ldh [rSVBK], a
            call font_back
            call npc_gfx
            call char_gfx
            call veh_gfx
            call map_pals                   ; (the field's palettes: the fade's target)
            call menu_pals                  ; (BG / OBJ 4-7: the dialogue window's)
            call u_sv2
            ld hl, pal_sh
            ld de, u_palt
            ld bc, 128
            call memcpy
            call u_svr
            ld hl, pal_sh
            ld de, 128
            call memclr
            ld a, 1
            ldh [pal_dirty], a
            ld a, 1
            ldh [rSVBK], a
            ret

; the UI's tiles -> VRAM bank 1: frames, fill, black, the hand, the icons
u_tiles:    ld a, MENU_BANK
            ld [vc_src], a
            ld hl, $6400 + 16 * ($F7 - $70) ; FF3's frame tiles $F7-$FE
            ld de, $8000 + 16 * U_FR
            ld b, 8
            ld a, 1
            call vcopyx
            ld hl, $6400 + 16 * ($FF - $70) ; its blank (the fill)
            ld de, $8000 + 16 * U_FILL
            ld b, 1
            ld a, 1
            call vcopyx
            ld a, CODE11
            ld [vc_src], a
            ld hl, U_ZTILE
            ld de, $8000 + 16 * U_ZERO
            ld b, 1
            ld a, 1
            call vcopyx
            ld a, MENU_BANK
            ld [vc_src], a
            ld hl, $6E00                    ; the hand
            ld de, $8000 + 16 * U_HAND
            ld b, 4
            ld a, 1
            call vcopyx
            ld hl, $5E00                    ; the icons (0D/B500)
            ld de, $8000 + 16 * U_ICON
            ld b, 32
            ld a, 1
            jp vcopyx

; the members' pictures (FF1's method: each one's battle picture, one palette a member): the
; job's standing pose (CHGFX_BANK $4000 + $2A0 job: its first 6 tiles, 2 x 3) -> VRAM bank 1
; U_PIC + 6 m; its battle palette (job 0: 2E/9E4A by member, else 2E/9E4E by job; colours
; 2E/8C00 + 3 ($FC + id)) -> OBJ palette m colours 1-3
u_mpal:     xor a
            ld [u_k], a
.m:         ld a, [u_k]
            rrca
            rrca
            ld l, a
            ld h, high(GS + $100)
            ld a, [hl]
            and $3F
            ld [u_t], a
            ld a, [u_k]
            ld [u_pm], a
            call u_mjob
            ld hl, u_k
            inc [hl]
            ld a, [hl]
            cp 4
            jr nz, .m
            ret
; member u_k's picture as job u_t: its tiles -> U_PIC + 6 m, its colours -> u_palt OBJ m
u_mjob:     ld a, [u_t]
            ld l, a                         ; the tiles: $4000 + $2A0 job = $20 x 21 x job
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld d, h
            ld e, l
            ld b, 20
.x:         add hl, de
            dec b
            jr nz, .x
            ld de, $4000
            add hl, de
            ld a, [u_k]                     ; -> $8000 + 16 (U_PIC + 6 m)
            ld e, a
            add a, a
            add a, e
            add a, a
            add a, U_PIC
            swap a
            ld e, a
            and $0F
            add a, $80
            ld d, a
            ld a, e
            and $F0
            ld e, a
            ld a, CHGFX_BANK
            ld [vc_src], a
            ld b, 6
            ld a, 1
            call vcopyx
            ld a, [u_t]                     ; the palette id (job 0: by member u_pm)
            and a
            ld hl, U_PFREE
            ld a, [u_pm]
            jr z, .f
            ld hl, U_PJOB
            ld a, [u_t]
.f:         ld e, a
            ld d, 0
            add hl, de
            ld a, [hl]
            add a, $FC                      ; 3 ($FC + id)
            ld l, a
            ld h, 0
            ld d, h
            ld e, l
            add hl, hl
            add hl, de
            ld de, BD_PAL
            add hl, de
            ld de, u_nc + 1
            ld bc, 3
            ld a, BDATA_BANK
            call rd_copy
            ld a, [u_k]                     ; OBJ palette m colours 1-3
            add a, a
            add a, a
            add a, a
            add a, low(u_palt + 64 + 2)
            ld e, a
            ld a, high(u_palt + 64 + 2)
            adc a, 0
            ld d, a
            ld hl, u_nc + 1
            call .one
            call .one
.one:       push de
            call nes_col                    ; ([HL++] -> A, D)
            ld b, d
            pop de
            ld [de], a
            inc de
            ld a, b
            ld [de], a
            inc de
            ret
; member u_k's picture as 6 sprites at pixel (B, C) (OAM entries 6 m ..)
u_pic:      ld a, [u_k]
            ld e, a
            add a, a
            add a, e
            add a, a                        ; 6 m
            ld e, a
            add a, a
            add a, a                        ; 24 m
            ld l, a
            ld h, high(oam_buf)
            ld a, e
            add a, U_PIC
            ld e, a                         ; the tiles
            ld a, [u_k]
            or 8
            ld d, a                         ; palette m, bank 1
            ld a, c
            add a, 16
            ld c, a
            ld a, b
            add a, 8
            ld b, a
            ld a, 3
.r:         push af
            call .s
            ld a, b
            add a, 8
            ld b, a
            call .s
            ld a, b
            sub 8
            ld b, a
            ld a, c
            add a, 8
            ld c, a
            pop af
            dec a
            jr nz, .r
            ret
.s:         ld a, c
            ld [hl+], a
            ld a, b
            ld [hl+], a
            ld a, e
            ld [hl+], a
            inc e
            ld a, d
            ld [hl+], a
            ret

; ---- fades: pal_sh = u_palt x k / 4 (k 4 -> 0 out, 0 -> 4 in), two frames a step
u_fadeout:  call u_sv2
            ld hl, pal_sh                   ; (from what shows now)
            ld de, u_palt
            ld bc, 128
            call memcpy
            call u_svr
            ld a, 3
.o:         push af
            call u_pstep
            pop af
            dec a
            cp $FF
            jr nz, .o
            ret
u_fadein:   ld hl, pal_sh                   ; (from black)
            ld de, 128
            call memclr
u_fadein0:  ld a, 1
.i:         push af
            call u_pstep
            pop af
            inc a
            cp 5
            jr nz, .i
            ret
u_pstep:    ld [u_k], a
            call u_sv2
            ld hl, u_palt
            ld de, pal_sh
            ld b, 64
.c:         push bc
            ld a, [hl+]
            ld c, a
            ld a, [hl+]
            ld b, a                         ; BC = colour
            push hl
            push de
            call u_scale
            pop de
            ld a, l
            ld [de], a
            inc de
            ld a, h
            ld [de], a
            inc de
            pop hl
            pop bc
            dec b
            jr nz, .c
            call u_grramp                   ; (the gradient's colours at this step)
            call u_svr
            ld a, 1
            ldh [pal_dirty], a
            call wait_vbl
            jp wait_vbl
; WRAM bank 2 while the fades' target is read / written (the bank before kept)
u_sv2:      ldh a, [rSVBK]
            ld [u_svb], a
            ld a, 2
            ldh [rSVBK], a
            ret
u_svr:      ld a, [u_svb]
            ldh [rSVBK], a
            ret
; BC = RGB555 -> HL = its channels x u_k / 4
u_scale:    ld a, [u_k]
            cp 4
            jr nz, .s
            ld h, b
            ld l, c
            ret
.s:         ld hl, 0
            ld a, c                         ; red
            and 31
            call .one
            ld l, a
            ld a, c                         ; green: bits 5-9
            srl b
            rr c
            srl b
            rr c
            srl b
            rr c
            srl b
            rr c
            srl b
            rr c
            ld a, c
            and 31
            call .one
            ld e, a                         ; (green: l |= g << 5, h |= g >> 3)
            swap a
            add a, a
            and $E0
            or l
            ld l, a
            ld a, e
            srl a
            srl a
            srl a
            ld h, a
            srl b                           ; blue: bits 10-14
            rr c
            srl b
            rr c
            srl b
            rr c
            srl b
            rr c
            srl b
            rr c
            ld a, c
            and 31
            call .one
            add a, a
            add a, a
            or h
            ld h, a
            ret
.one:       ld d, a                         ; A x k / 4 (k 0-3)
            ld a, [u_k]
            and a
            jr z, .z
            cp 2
            jr z, .h
            jr c, .q
            ld a, d                         ; 3/4
            srl a
            srl a
            ld e, a
            ld a, d
            sub e
            ret
.h:         ld a, d
            srl a
            ret
.q:         ld a, d
            srl a
            srl a
            ret
.z:         xor a
            ret

; ---- the canvas: all black (tile U_ZERO); the text pool emptied; the hand off
u_cls:      ld a, 2
            ldh [rSVBK], a
            ld hl, MC_MAP
            ld de, MC_ATTR
            ld bc, 32 * 18
.l:         ld a, U_ZERO
            ld [hl+], a
            ld a, UP_WHITE | 8
            ld [de], a
            inc de
            dec bc
            ld a, b
            or c
            jr nz, .l
            xor a
            ld [u_pool], a
            ld [u_dlo], a
            ld [u_dhi], a
            ld [GR_NW], a                   ; (the gradient's windows: none yet)
            ret

; a window: B, C = left, top cell; D, E = width, height (its rows kept for the gradient)
u_box:      ld a, [GR_NW]
            cp 8
            jr nc, .ng
            push hl
            add a, a
            add a, low(GR_WIN)
            ld l, a
            ld h, high(GR_WIN)
            ld [hl], c
            inc l
            ld [hl], e
            ld hl, GR_NW
            inc [hl]
            pop hl
.ng:        push bc
            push de
            ld a, U_FR                      ; top row
            call u_cell
            inc b
            ld a, d
            sub 2
            ld l, a
.t:         ld a, U_FR + 1
            call u_cell
            inc b
            dec l
            jr nz, .t
            ld a, U_FR + 2
            call u_cell
            pop de
            pop bc
            push bc
            push de
            dec e
            dec e
.r:         inc c                           ; middle rows
            push bc
            ld a, U_FR + 3
            call u_cell
            inc b
            ld a, d
            sub 2
            ld l, a
.f:         ld a, U_FILL
            call u_cell
            inc b
            dec l
            jr nz, .f
            ld a, U_FR + 4
            call u_cell
            pop bc
            dec e
            jr nz, .r
            inc c                           ; bottom row
            ld a, U_FR + 5
            call u_cell
            inc b
            pop de
            push de
            ld a, d
            sub 2
            ld l, a
.b:         ld a, U_FR + 6
            call u_cell
            inc b
            dec l
            jr nz, .b
            ld a, U_FR + 7
            call u_cell
            pop de
            pop bc
            ret
; tile A at cell (B, C), palette UP_WHITE, bank 1
u_cell:     push af
            ld a, UP_WHITE | 8
u_cella:    ld [u_at], a
            pop af
u_cellt:    push hl                         ; (attribute u_at)
            push af
            ld a, c
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld a, l
            add a, b
            ld l, a
            ld a, h
            add a, high(MC_MAP)
            ld h, a
            pop af
            ld [hl], a
            ld a, h
            add a, high(MC_ATTR - MC_MAP)
            ld h, a
            ld a, [u_at]
            ld [hl], a
            pop hl
            ret

; ---- text: HL = string (FF3 codes, 0 ends; in this bank or WRAM), at cell (B, C), palette u_pal.
; u_text: from the cell's left; u_textr: ending at cell B's right edge (B = the cell after);
; u_textc: centred in D cells from B. Returns B = the cell after the text.
u_textc:    push bc
            push hl
            call u_meas                     ; A = width
            pop hl
            pop bc
            ld e, a
            ld a, d
            add a, a
            add a, a
            add a, a
            sub e                           ; (8 D - w) / 2 pixels in
            jr nc, .p
            xor a
.p:         srl a
            ld e, a                         ; -> cells B + off / 8, pen off & 7
            srl a
            srl a
            srl a
            add a, b
            ld b, a
            ld a, e
            and 7
            jr u_text0
u_textr:    push bc
            push hl
            call u_meas
            pop hl
            pop bc
            ld e, a                         ; start = 8 B - w: cell (8B - w) / 8, pen (8B - w) & 7
            ld a, b
            add a, a
            add a, a
            add a, a
            sub e
            ld e, a
            and 7
            ld d, a
            ld a, e
            srl a
            srl a
            srl a
            ld b, a
            ld a, d
            jr u_text0
u_text:     xor a
u_text0:    ld [u_pen], a                   ; A = the pen's start in the first cell
            ld a, b
            ld [u_bx], a
            ld a, c
            ld [u_by], a
            push hl
            ld hl, U_LINE                   ; the line cleared
            ld b, 160
            xor a
.cl:        ld [hl+], a
            dec b
            jr nz, .cl
            ld [u_nic], a
            pop hl
.ch:        ld a, [hl+]
            and a
            jr z, .out
            cp 1                            ; ({01}: a second line follows: ends this one)
            jr z, .out
            cp $FF
            jr z, .sp
            cp $80
            jr nc, .gl
            cp $50
            jr c, .ch                       ; (control codes: skipped)
            ld e, a                         ; an icon: its own cell
            ld a, [u_pen]
            add a, 7
            and $F8
            ld d, a
            add a, 8
            ld [u_pen], a
            push hl
            ld a, [u_nic]                   ; (its cell and tile kept: drawn at the end)
            cp 4
            jr nc, .icx
            add a, a
            ld l, a
            ld h, high(u_ics)
            ld a, l
            add a, low(u_ics)
            ld l, a
            jr nc, .ic0
            inc h
.ic0:       ld a, d
            srl a
            srl a
            srl a
            ld [hl+], a                     ; the cell (relative)
            ld a, e
            sub $50                         ; (FF3's icons: codes $50-$6F)
            add a, U_ICON
            ld [hl], a
            ld hl, u_nic
            inc [hl]
.icx:       pop hl
            jr .ch
.sp:        ld a, [u_pen]
            add a, 3
            ld [u_pen], a
            jr .ch
.gl:        cp $D0
            jr nc, .ch
            push hl
            call u_glyph
            pop hl
            ld a, [u_pen]
            cp 160 - 8
            jr c, .ch
.out:       ld a, [u_pen]                   ; the cells: (pen - 1 + 7) / 8 (pen - 1: the last
            and a                           ;   glyph's gap dropped)
            jr z, .none
            add a, 6
            srl a
            srl a
            srl a
            ld [u_nc], a
            push hl                         ; (HL: after the line's end, for a second line)
            call u_emit
            pop hl
.none:      ld a, [u_nc]
            ld b, a
            ld a, [u_bx]
            add a, b
            ld b, a
            ld a, [u_by]
            ld c, a
            ret

; the width in pixels of string HL (as u_text draws it) -> A
u_meas:     ld e, 0
.c:         ld a, [hl+]
            and a
            jr z, .x
            cp $FF
            jr z, .sp
            cp $80
            jr nc, .g
            cp $50
            jr c, .c
            ld a, e
            add a, 7
            and $F8
            add a, 8
            ld e, a
            jr .c
.sp:        ld a, e
            add a, 3
            ld e, a
            jr .c
.g:         cp $D0
            jr nc, .c
            push hl
            call u_gptr
            ld a, [hl]
            pop hl
            inc a
            add a, e
            ld e, a
            jr .c
.x:         ld a, e
            and a
            ret z
            dec a                           ; (no gap after the last)
            ret
; HL = the glyph of code A (U_GLY + 9 (A - $80))
u_gptr:     sub $80
            ld l, a
            ld h, 0
            ld b, h
            ld c, l
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, bc
            ld bc, U_GLY
            add hl, bc
            ret
; glyph A at u_pen into U_LINE, the pen on
u_glyph:    call u_gptr
            ld a, [hl+]
            and a
            ret z
            ld [u_w], a
            ld a, [u_pen]
            and 7
            ld [u_s], a
            ld a, [u_pen]
            and $F8
            ld e, a
            ld d, high(U_LINE)
            ld b, 8
.r:         ld a, [hl+]
            push hl
            push bc
            ld c, a
            ld a, [u_s]
            ld b, a
            ld l, c
            ld h, 0
            and a
            jr z, .ns
.sh:        srl l
            rr h
            dec b
            jr nz, .sh
.ns:        ld a, [de]
            or l
            ld [de], a
            ld a, e
            add a, 8
            ld c, a
            ld b, d
            ld a, [bc]
            or h
            ld [bc], a
            inc e
            pop bc
            pop hl
            dec b
            jr nz, .r
            ld a, [u_w]
            inc a
            ld b, a
            ld a, [u_pen]
            add a, b
            ld [u_pen], a
            ret
; the line's u_nc cells -> pool tiles (2 bits: ink 3, shadow down-right 0, else the fill 2) and
; the canvas; icon cells their icon tile
u_emit:     xor a
            ld [u_ce], a                     ; cell
.c:         ld a, [u_ce]                     ; an icon cell?
            ld b, a
            ld a, [u_nic]
            and a
            jr z, .tx
            ld c, a
            ld hl, u_ics
.ic:        ld a, [hl+]
            cp b
            jr z, .icon
            inc hl
            dec c
            jr nz, .ic
.tx:        ld a, [u_pool]                  ; a pool tile
            cp U_NPOOL
            jp nc, .nx
            ld [u_t], a
            inc a
            ld [u_pool], a
            call u_dirty
            ld a, [u_t]                     ; WRAM 7: U_BUF + 16 t
            swap a
            ld e, a
            and $0F
            add a, high(U_BUF)
            ld d, a
            ld a, e
            and $F0
            ld e, a
            push de                         ; (the tile built in u_tb, then to WRAM 7)
            ld a, [u_ce]                     ; the line's tile: U_LINE + 8 k
            add a, a
            add a, a
            add a, a
            ld l, a
            ld h, high(U_LINE)
            ld de, u_tb
            ld b, 8
            ld c, 0                         ; (the row above: none for row 0)
            ld a, $FF
            ld [u_w], a                     ; (row 0: no row above)
.r:         ld a, [hl]                      ; ink
            ld [de], a                      ; plane 0 = ink
            inc de
            push hl
            ld a, [u_w]
            inc a
            jr z, .s0                       ; (row 0)
            dec hl                          ; the row above in this tile
            ld a, [hl]
            srl a
            ld c, a
            ld a, l                         ; the left tile's row above (none for the first cell)
            sub 8
            jr c, .s1
            ld l, a
            ld a, [hl]
            rrca
            and $80
            or c
            ld c, a
            jr .s1
.s0:        ld c, 0
.s1:        pop hl
            ld a, [hl+]                     ; (ink again)
            cpl
            and c                           ; shadow: below-right of ink, where no ink
            cpl
            ld [de], a                      ; plane 1 = not shadow
            inc de
            xor a
            ld [u_w], a
            dec b
            jr nz, .r
            pop de
            ld a, 7
            ldh [rSVBK], a
            ld hl, u_tb
            ld b, 16
.cp:        ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .cp
            ld a, 2
            ldh [rSVBK], a
            ld a, [u_bx]
            ld b, a
            ld a, [u_ce]
            add a, b
            ld b, a
            ld a, [u_by]
            ld c, a
            ld a, [u_pal]
            or 8
            ld [u_at], a
            ld a, [u_t]
            add a, U_T0
            call u_cellt
            jr .nx
.icon:      ld a, [hl]                      ; the icon's tile, palette UP_WHITE (FF3's colours)
            push af
            ld a, [u_bx]
            add a, b
            ld b, a
            ld a, [u_by]
            ld c, a
            ld a, UP_WHITE | 8
            ld [u_at], a
            pop af
            call u_cellt
.nx:        ld hl, u_ce
            inc [hl]
            ld a, [u_nc]
            cp [hl]
            jp nz, .c
            ret
; pool tile u_t into the dirty range
u_dirty:    ld a, [u_dlo]
            ld b, a
            ld a, [u_dhi]
            cp b
            jr nz, .x
            ld a, [u_t]                     ; (empty: starts here)
            ld [u_dlo], a
            inc a
            ld [u_dhi], a
            ret
.x:         ld a, [u_t]
            cp b
            jr nc, .h
            ld [u_dlo], a
.h:         ld a, [u_t]
            inc a
            ld b, a
            ld a, [u_dhi]
            cp b
            ret nc
            ld a, b
            ld [u_dhi], a
            ret

; a number DE (0-65535) as a string in u_num (no leading zeros), HL = u_num
u_ntoa:     ld hl, u_num
            ld bc, 10000
            call .d
            ld bc, 1000
            call .d
            ld bc, 100
            call .d
            ld bc, 10
            call .d
            ld a, e
            add a, $80
            ld [hl+], a
            ld [hl], 0
            ld hl, u_num
.sk:        ld a, [hl]                      ; leading zeros off (not the last digit)
            cp $80
            ret nz
            inc hl
            ld a, [hl]
            and a
            jr nz, .sk
            dec hl
            ret
.d:         ld a, $80
.dl:        push af
            ld a, e
            sub c
            ld e, a
            ld a, d
            sbc b
            ld d, a
            jr c, .dd
            pop af
            inc a
            jr .dl
.dd:        ld a, e
            add a, c
            ld e, a
            ld a, d
            adc a, b
            ld d, a
            pop af
            ld [hl+], a
            ret

; item A's name (GAME_BANK $4400 + 16 id: icon + letters, a leading blank dropped) -> u_nbuf,
; HL = it
u_iname:    ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, $4400
            add hl, de
            ld de, u_nbuf
            ld bc, 16
            ld a, GAME_BANK
            call rd_copy
            xor a
            ld [u_nbuf + 16], a
            ld hl, u_nbuf
.sk:        ld a, [hl]
            cp $FF
            ret nz
            inc hl
            jr .sk

; the pool's dirty tiles only (the canvas as it is: a change inside cells already shown)
u_flusht:   ld a, [u_dlo]
            ld b, a
            ld a, [u_dhi]
            sub b
            ret z
            ld a, 1
            ld [u_tonly], a
            call u_flush
            xor a
            ld [u_tonly], a
            ret

; ---- the canvas and the pool to VRAM: the pool's dirty tiles, 24 a V-Blank (WRAM 7 -> VRAM bank
; 1 by DMA), then the canvas (menu_vbl, m_dirty)
u_flush:    ld a, [u_dlo]
            ld b, a
            ld a, [u_dhi]
            sub b
            jr z, .map
            cp 24
            jr c, .n
            ld a, 24
.n:         ld [u_t], a
.wv:        call wait_vbl                   ; (and the V-Blank's start still: its handler can be
            ldh a, [rLY]                    ;   long, the canvas's copy, the gradient; a copy
            cp 144                          ;   running into the picture loses bytes)
            jr c, .wv
            cp 148
            jr nc, .wv
            ld a, [u_dlo]                   ; source U_BUF + 16 lo, destination $8000 + 16 (U_T0 + lo)
            swap a
            ld l, a
            and $0F
            add a, high(U_BUF)
            ld h, a
            ld a, l
            and $F0
            ld l, a
            ld a, h
            ldh [rHDMA1], a
            ld a, l
            ldh [rHDMA2], a
            ld a, [u_dlo]
            add a, U_T0
            swap a
            ld l, a
            and $0F
            add a, $80
            ldh [rHDMA3], a
            ld a, l
            and $F0
            ldh [rHDMA4], a
            ld a, 7
            ldh [rSVBK], a
            ld a, 1
            ldh [rVBK], a
            ld a, [u_t]
            dec a
            ldh [rHDMA5], a
            xor a
            ldh [rVBK], a
            ld a, 2
            ldh [rSVBK], a
            ld a, [u_t]
            ld b, a
            ld a, [u_dlo]
            add a, b
            ld [u_dlo], a
            jr u_flush
.map:       ld a, [u_tonly]
            and a
            ret nz
            call u_grbuild                  ; (the gradient for these windows)
            ld a, 1
            ld [m_dirty], a
            call wait_vbl
            call wait_vbl
            jp wait_vbl

; ---- the windows' colour and gradient (Config; FF1's): u_palt BG 1-6 colour 2 = the colour,
; colour 0 (the letters' shadow, the frame's outer line) = a quarter of it; the ramp GR_BASE: 16
; levels from the colour down to a third. u_gron: the gradient on (wp_on = 2) if Config has it.
u_wcol:     call u_sv2
            ld a, [win_r]                   ; DE = the colour
            ld e, a
            ld a, [win_g]
            call .g
            ld a, [win_b]
            add a, a
            add a, a
            or d
            ld d, a
            push de
            ld a, [win_r]                   ; BC = a quarter of it
            srl a
            srl a
            ld e, a
            ld a, [win_g]
            srl a
            srl a
            call .g
            ld a, [win_b]
            srl a
            srl a
            add a, a
            add a, a
            or d
            ld b, a
            ld c, e
            pop de
            ld hl, u_palt + 8               ; BG 1-6
            ld a, 6
.p:         push af
            ld [hl], c
            inc hl
            ld [hl], b
            inc hl
            inc hl
            inc hl
            ld [hl], e
            inc hl
            ld [hl], d
            inc hl
            inc hl
            inc hl
            pop af
            dec a
            jr nz, .p
            ld hl, GR_BASE                  ; the ramp: level l = the colour x (45 - 2 l) / 45
            ld c, 0
.r:         push bc
            push hl
            ld a, c
            ld b, a
            ld a, [win_r]
            call .f
            ld e, a
            ld a, [win_g]
            call .f
            call .g
            ld a, [win_b]
            call .f
            add a, a
            add a, a
            or d
            ld d, a
            pop hl
            ld [hl], e
            inc hl
            ld [hl], d
            inc hl
            pop bc
            inc c
            ld a, c
            cp 16
            jr nz, .r
            jp u_svr
.g:         ld d, a                         ; E |= g << 5, D = g >> 3
            swap a
            add a, a
            and $E0
            or e
            ld e, a
            ld a, d
            srl a
            srl a
            srl a
            ld d, a
            ret
.f:         push de                         ; A x (45 - 2 B) / 45 (A 0-31)
            push bc
            push hl
            ld e, a
            ld d, 0
            ld a, b
            add a, a
            cpl
            add a, 46                       ; 45 - 2 l
            ld b, a
            ld hl, 0
.m:         add hl, de
            dec b
            jr nz, .m
            ld e, 0                         ; / 45
.dv:        ld a, l
            sub 45
            ld l, a
            ld a, h
            sbc 0
            ld h, a
            jr c, .dd
            inc e
            jr .dv
.dd:        ld a, e
            pop hl
            pop bc
            pop de
            ret
; the ramp at the fade's step u_k -> GR_RMP (WRAM 2 selected)
u_grramp:   ld hl, GR_BASE
            ld de, GR_RMP
            ld a, 16
.l:         push af
            ld a, [hl+]
            ld c, a
            ld a, [hl+]
            ld b, a
            push hl
            push de
            call u_scale
            pop de
            ld a, l
            ld [de], a
            inc de
            ld a, h
            ld [de], a
            inc de
            pop hl
            pop af
            dec a
            jr nz, .l
            ret
; the gradient on when Config has it (the UI showing), else off
u_gron:     ld a, [opt_grad]
            and a
            jr nz, u_groff
            ld a, 2
            ld [wp_on], a
            ret
u_groff:    ld a, [wp_on]                   ; (off: the frame's sound at its own line again)
            cp 2
            ret nz
            xor a
            ld [wp_on], a
            ld a, WIN_LINE - 1
            ldh [rLYC], a
            ret
; the records for the windows drawn (GR_WIN): each line takes the outermost window over it (the
; smallest top row); its level from 3 lines into that window's top to 3 lines before its bottom
u_grbuild:  call u_sv2
            ld hl, GR_TMP
            xor a
            ld [u_gry], a
            dec a
            ld [u_grp], a                   ; (the level before: none)
.y:         ld a, [u_gry]                   ; (line 48: the frame's sound, mid-screen as
            cp 48                           ;   without the gradient)
            jr nz, .ns
            ld [hl+], a
            ld [hl], $FF
            inc hl
.ns:        push hl
            call .lvl
            pop hl
            ld b, a
            ld a, [u_grp]
            cp b
            jr z, .n
            ld a, b
            ld [u_grp], a
            ld a, [u_gry]
            and a
            jr z, .n                        ; (line 0: the V-Blank's level 0)
            ld [hl+], a
            ld [hl], b
            inc hl
            ld a, l
            cp 250
            jr nc, .e
.n:         ld a, [u_gry]
            inc a
            ld [u_gry], a
            cp 141
            jr nz, .y
.e:         ld a, $FF                       ; (the end)
            ld [hl+], a
            ld [hl], a
            di
            ld hl, GR_TMP
            ld de, GR_REC
            ld bc, 256
            call memcpy
            ei
            jp u_svr
.lvl:       ld a, [u_gry]                   ; A = line y's level
            srl a
            srl a
            srl a
            ld c, a                         ; its row
            ld b, $FF                       ; (the best top)
            ld hl, GR_WIN
            ld a, [GR_NW]
            and a
            ret z
            ld e, a
            ld d, 0                         ; (the best height)
.w:         ld a, [hl+]                     ; top
            push hl
            ld l, [hl]                      ; height
            ld h, a
            ld a, c
            cp h
            jr c, .wn                       ; row < top
            ld a, h
            add a, l
            dec a
            cp c
            jr c, .wn                       ; row > top + h - 1
            ld a, h
            cp b
            jr nc, .wn
            ld b, h
            ld d, l
.wn:        pop hl
            inc hl
            dec e
            jr nz, .w
            ld a, b
            cp $FF
            jr nz, .got
            xor a
            ret
.got:       add a, a                        ; start = 8 top + 3
            add a, a
            add a, a
            add a, 3
            ld c, a
            ld a, [u_gry]
            sub c
            jr nc, .t
            xor a
            ret
.t:         ld l, a                         ; t * 16 / (8 h - 6)
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld a, d
            add a, a
            add a, a
            add a, a
            sub 6
            ld c, a
            ld b, 0
            ld e, 0
.dv:        ld a, l
            sub c
            ld l, a
            ld a, h
            sbc b
            ld h, a
            jr c, .dd
            inc e
            ld a, e
            cp 15
            jr c, .dv
.dd:        ld a, e
            ret

; string A of table HL in bank CODE12 (ui.py: place names, FF3's messages) -> U_FBUF (WRAM 2),
; HL = U_FBUF
u_fstr:     ld e, a
            ld d, 0
            add hl, de
            add hl, de
            ld a, CODE12
            call rd_byte
            push af
            ld a, CODE12
            call rd_byte
            ld h, a
            pop af
            ld l, a
            ld de, U_FBUF
.c:         ld a, CODE12
            call rd_byte
            ld [de], a
            inc de
            and a
            jr nz, .c
            ld hl, U_FBUF
            ret

; ---- the hand (sprite, OBJ palette 7, OAM 36-39): FF1's rule, its left 16 pixels before the
; text at cell B, its top at row C's top (the finger on the line's middle). u_handp: pixel B, C
; (the text's left and top); B = $FF: off
u_hand:     ld a, b
            cp $FF
            jr z, u_hoff
            add a, a
            add a, a
            add a, a
            ld b, a
            ld a, c
            add a, a
            add a, a
            add a, a
            ld c, a
u_handp:    ld hl, oam_buf + 4 * 36
u_handh:    ld a, b                         ; OAM x = text - 16 + 8 (HL: the 4 OAM entries)
            sub 8
            ld b, a
            ld a, c
            add a, 16
            ld c, a
            ld e, U_HAND
            call .s
            ld a, b
            add a, 8
            ld b, a
            call .s
            ld a, b
            sub 8
            ld b, a
            ld a, c
            add a, 8
            ld c, a
            call .s
            ld a, b
            add a, 8
            ld b, a
.s:         ld a, c
            ld [hl+], a
            ld a, b
            ld [hl+], a
            ld a, e
            ld [hl+], a
            inc e
            ld a, 7 | 8
            ld [hl+], a
            ret
u_hoff:     ld hl, oam_buf + 4 * 36
            ld b, 4
            xor a
.o:         ld [hl+], a
            inc hl
            inc hl
            inc hl
            dec b
            jr nz, .o
            ret
; HL = MC_MAP + 32 C + B
u_cadr:     ld a, c
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld a, l
            add a, b
            ld l, a
            ld a, h
            add a, high(MC_MAP)
            ld h, a
            ret

; ---- keys: new presses in m_new with FF3's repeat (3C/9175: after 16 frames, then every 4)
u_keys:     call read_pad
            ldh a, [pad]
            ld b, a
            ld a, [m_old]
            cpl
            and b
            ld c, a
            ld a, b
            ld [m_old], a
            and $F0
            jr z, .nr
            ld hl, m_rep
            inc [hl]
            ld a, [hl]
            cp 16
            jr c, .out
            ld [hl], 12
            ld a, b
            and $F0
            or c
            ld c, a
            jr .out
.nr:        xor a
            ld [m_rep], a
.out:       ld a, c
            ld [m_new], a
            ret

section wram, $C740                         ; (the stack runs from $C800 down: keep below $C780)
u_k:        ds 1
u_t:        ds 1
u_pen:      ds 1
u_bx:       ds 1
u_by:       ds 1
u_w:        ds 1
u_s:        ds 1
u_nc:       ds 4
u_pool:     ds 1
u_dlo:      ds 1
u_dhi:      ds 1
u_pal:      ds 1
u_at:       ds 1
u_tb:       ds 16
u_ce:       ds 1
u_nic:      ds 1
u_ics:      ds 8
u_num:      ds 6
u_svb:      ds 1
u_tonly:    ds 1
u_eatk:     ds 2                            ; (the Equip screen: equip.s eqx_*)
u_edef:     ds 2
u_patk:     ds 2
u_pdef:     ds 2
u_eres:     ds 1
eqx_lo:     ds 1
eqx_hi:     ds 1
u_pm:       ds 1                            ; (u_mjob: the member whose job-0 colours)
u_gry:      ds 1                            ; (u_grbuild: the line, the level before)
u_grp:      ds 1
