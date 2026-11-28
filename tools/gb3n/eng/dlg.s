; FF3 native port: FF3's dialogue (3F/EC8B show dialogue, 3F/EE65 multi-page text, 3F/ECAB wait for
; keypress) in FF1's dialogue box (tools/gbn/src/text.s, the owner's approved layout): 20 x 8 cells
; in the window layer at the top of the screen, text 18 columns x 6 lines, typed at reading speed
; (A held: twice as fast), the window cut at line 64 in H-Blank by hiding it (WX), the objects under
; the box hidden while it shows. Our own code.
; Font (VRAM bank 1, tile = code, port.py): our Latin font at ASCII, FF3's window frame at $10-$18,
; FF3's icons at text.ICON_CODES; the blank is the space. Text (tools/gb3n/text.py, the project's translation): $00 end,
; $0A new line, $0C new page, $10-$13 a member's name, $14-$17 a member's job, $02 / $03 / $04 an
; item / an amount (z80 / z81: the event's).

BOX_LINES  = 64
WIN_ATTR   = $0F            ; window cell: palette 7, VRAM bank 1
TW_RATE    = 90             ; letters a frame x 256 (FF1's reading speed)
F_UL       = $10
F_T        = $11
F_UR       = $12
F_L        = $13
F_R        = $14
F_DL       = $15
F_B        = $16
F_DR       = $17
F_SP       = $20            ; (the blank: our font's space, the window colour)

section bank 0, $1A00

; the map's title (3F/E24C: FF3's window type 4, a line; any key closes it): t8200 + z4B
dlg_title:  ld [z76], a
            ld a, $FF
            ld [z4B], a
            ld a, $82
            ld [z95], a
            ld a, 1
            ld [dlg_one], a
            call dlg_show
            xor a
            ld [dlg_one], a
            ret

; FF3 show dialogue: z76 = id in table z95 ($80 / $82 / $84 / $86); z7D: the last page waits for A
dlg_show:   ld a, [dlg_one]                 ; (the box's height: 3 rows for a title, else 8)
            and a
            ld a, BOX_LINES - 1
            jr z, .h
            ld a, 23
.h:         ldh [rLYC], a
            ld a, [z95]                     ; the table's index (port.py: TXT_IDX + 3 x id)
            sub $80
            srl a                           ; 0-3
            ld e, a
            ld d, 0
            ld hl, txt_tab
            add hl, de
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld a, [z76]
            ld e, a
            add hl, de
            add hl, de
            add hl, de
            ld a, TXT_IDX
            call sbank
            ld a, [hl+]
            ld [dlg_bank], a
            ld a, [hl+]
            ld [dlg_ptr], a
            ld a, [hl]
            ld [dlg_ptr + 1], a
            xor a
            ld [z76], a
.pg:        call dlg_page
            ld a, 1
            ld [box_on], a
.ty:        call dlg_frame                  ; typed
            ld a, [tw_i]
            cp 160
            jr c, .ty
            call dlg_key                    ; FF3: a key per page
            ld a, [dlg_more]
            and a
            jr nz, .pg
            ld a, [z7D]                     ; (an event's dialogue: the A Button to close)
            and a
            jr z, .cl
.wa:        call dlg_frame
            ldh a, [pad_new]
            bit 0, a
            jr z, .wa
            xor a
            ld [z7D], a
.cl:        xor a
            ld [box_on], a
            call wait_vbl
            ld a, BOX_LINES - 1
            ldh [rLYC], a
            jp joy_clear

; nm_v (24 bits) / 10 -> nm_v, A = the remainder
nm_div10:   ld hl, nm_v + 2
            ld c, 3
            xor a
.l:         ld b, 8                         ; (remainder:byte / 10, a byte at a time, bit by bit)
            ld e, [hl]
.b:         sla e
            rla
            cp 10
            jr c, .s
            sub 10
            inc e
.s:         dec b
            jr nz, .b
            ld [hl], e
            dec hl
            dec c
            jr nz, .l
            ret

; the buttons let go, then any pressed (FF3 3F/ECAB)
dlg_key:    call dlg_frame
            ldh a, [pad]
            and a
            jr nz, dlg_key
.w:         call dlg_frame
            ldh a, [pad_new]
            and a
            jr z, .w
            ret
; FF3's latched buttons cleared after a dialogue (no press carried into the field)
joy_clear:  xor a
            ld [z22], a
            ld [z23], a
            ld [z24], a
            ld [z25], a
            ret

; a frame with the box: the typing, the objects under it hidden, the pad
dlg_frame:  call wait_vbl
            call snd_frame
            call read_pad
            call tw_step
            ld hl, oam_buf + 16             ; (the npcs: hidden while over the box)
.h:         ld a, [hl]
            cp BOX_LINES + 16 + 1
            jr nc, .n
            ld [hl], 0
.n:         ld a, l
            add a, 4
            ld l, a
            cp 160
            jr c, .h
            ret

; the next page into win_buf (from dlg_ptr), the text cells kept in win_tx for the typing
dlg_page:   ld hl, win_buf
            ld bc, (F_UL << 8) | F_T
            ld d, F_UR
            call .row3
            ld e, 6
            ld a, [dlg_one]                 ; (a title: one line, the frame under it)
            and a
            jr z, .mid
            ld bc, (F_L << 8) | F_SP
            ld d, F_R
            call .row3
            ld bc, (F_DL << 8) | F_B
            ld d, F_DR
            call .row3
            ld e, 5
.blk:       ld bc, (F_SP << 8) | F_SP
            ld d, F_SP
            call .row3
            dec e
            jr nz, .blk
            jr .txt
.mid:       ld bc, (F_L << 8) | F_SP
            ld d, F_R
            call .row3
            dec e
            jr nz, .mid
            ld bc, (F_DL << 8) | F_B
            ld d, F_DR
            call .row3
.txt:       ld a, [dlg_bank]
            call sbank
            ld a, [dlg_ptr]
            ld e, a
            ld a, [dlg_ptr + 1]
            ld d, a
            ld hl, win_buf + 21
            ld b, l
.ch:        ld a, [de]
            inc de
            and a
            jr z, .end
            cp $0C
            jr z, .pg
            cp $0A
            jr z, .nl
            cp $02
            jp z, .item
            cp $05
            jp c, .num
            cp $10
            jr c, .ch
            cp $14
            jr c, .name
            cp $18
            jr c, .ch                       ; ($14-$17: jobs, with the menus)
            ld [hl+], a
            jr .ch
.name:      push de                         ; a member's name (SV $106 + $40 n, FF3's letters)
            sub $10
            swap a
            add a, a
            add a, a
            ld e, a
            ld d, 0
            push hl
            ld hl, SV + $106
            add hl, de
            ld d, h
            ld e, l
            pop hl
            ld c, 6
.nm:        ld a, [de]
            inc de
            cp $FF
            jr z, .ne
            push hl
            ld l, a
            ld h, high(C_ASC)
            ld a, COMMON
            call sbank
            ld a, [hl]
            pop hl
            ld [hl+], a
            dec c
            jr nz, .nm
.ne:        ld a, [dlg_bank]
            call sbank
            pop de
            jr .ch
.item:      push de                         ; the item found (z BB): its name (names table)
            push bc
            ld a, [zBB]
            ld e, a
            ld d, 0
            push hl
            ld hl, txt_tab + 8
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            add hl, de
            add hl, de
            add hl, de
            ld a, TXT_IDX
            call sbank
            ld a, [hl+]
            ld c, a
            ld a, [hl+]
            ld e, a
            ld d, [hl]
            pop hl
            ld a, c
            call sbank
.il:        ld a, [de]
            inc de
            and a
            jr z, .ie
            cp $20                          ; (an icon or a letter; the line's codes dropped)
            jr c, .il
            ld [hl+], a
            jr .il
.ie:        pop bc
            ld a, [dlg_bank]
            call sbank
            pop de
            jp .ch
.num:       push de                         ; an amount (z80-z82, 24 bits) in decimal
            push bc
            ld a, [z80]
            ld [nm_v], a
            ld a, [z81]
            ld [nm_v + 1], a
            ld a, [z82]
            ld [nm_v + 2], a
            ld de, nm_buf + 8
            xor a
            ld [de], a
.dv:        push hl                         ; (digits backwards)
            push de
            call nm_div10
            pop de
            pop hl
            add a, '0'
            dec de
            ld [de], a
            ld a, [nm_v]
            ld c, a
            ld a, [nm_v + 1]
            or c
            ld c, a
            ld a, [nm_v + 2]
            or c
            jr nz, .dv
.nc:        ld a, [de]
            inc de
            and a
            jr z, .ne2
            ld [hl+], a
            jr .nc
.ne2:       pop bc
            pop de
            jp .ch
.nl:        ld a, b
            add a, 20
            ld b, a
            ld l, a
            ld a, h
            adc a, 0
            ld h, a
            jr .ch
.pg:        ld a, e
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
            ld hl, win_buf                  ; (the typing: the page kept, its text cells blank)
            ld de, win_tx
            ld bc, 160
            call memcpy
            ld hl, win_buf + 21
            ld d, 6
.r:         ld b, 18
.b:         ld [hl], F_SP
            inc hl
            dec b
            jr nz, .b
            inc hl
            inc hl
            dec d
            jr nz, .r
            ld a, 21
            ld [tw_i], a
            ld a, 256 - TW_RATE
            ld [tw_acc], a
            xor a
            ld [tw_qh], a
            ret
.row3:      ld a, b
            ld [hl+], a
            ld a, c
            push bc
            ld b, 18
.r3:        ld [hl+], a
            dec b
            jr nz, .r3
            pop bc
            ld a, d
            ld [hl+], a
            ret

; the typing: this frame's letters from win_tx into the box (A held: twice as fast; FF1's)
tw_step:    ld a, [tw_i]
            cp 160
            ret nc
            ld a, [win_up]                  ; (the box up first)
            cp 8
            ret c
            ld b, TW_RATE
            ldh a, [pad]
            bit 0, a
            jr z, .r
            ld b, 2 * TW_RATE
.r:         ld a, [tw_acc]
            add a, b
            ld [tw_acc], a
            ret nc
.n:         ld a, [tw_i]                    ; the next text cell (a blank one: skipped)
            cp 160
            ret nc
            ld e, a
            inc a
            ld [tw_i], a
            ld d, high(win_tx)
            ld a, [de]
            cp F_SP
            jr z, .sk
            cp F_R
            jr z, .n
            cp F_L
            jr z, .n
            ld hl, win_buf - win_tx         ; (into win_buf, queued for V-Blank)
            add hl, de
            ld [hl], a
            ld [tw_qt], a
            ld a, e                         ; VRAM $9C00 + 32 row + col (row = e / 20)
            ld c, 0
.dv:        sub 20
            jr c, .dd
            inc c
            jr .dv
.dd:        add a, 20
            ld b, a
            ld a, c
            swap a
            add a, a
            add a, b
            ld [tw_ql], a
            ld a, $9C
            ld [tw_qh], a
            ret
.sk:        ld hl, win_buf - win_tx         ; (a space: no time)
            add hl, de
            ld [hl], a
            jr .n

; ---- V-Blank: the box's rows into the window map (4 a V-Blank, with their attributes), then
; shown at the top, cut at line 64
box_vbl:    ld a, [box_on]
            and a
            jr nz, .on
            ldh a, [rLCDC]                  ; closed: the window off
            res 5, a
            ldh [rLCDC], a
            xor a
            ld [win_up], a
            ret
.on:        ld a, [win_up]
            cp 8
            jr nc, .show
            ld c, 4
.r:         ldh a, [rLY]
            sub 144
            cp 7
            ret nc
            ld a, [win_up]
            ld e, a
            add a, a
            add a, a
            add a, e
            add a, a
            add a, a                        ; 20 row
            ld l, a
            ld h, high(win_buf)
            ld a, e
            swap a
            add a, a                        ; 32 row
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
            ld hl, win_up
            inc [hl]
            ld a, [hl]
            cp 8
            jr nc, .show
            dec c
            jr nz, .r
            ret
.show:      ld a, [tw_qh]                   ; (a typed letter's cell)
            and a
            jr z, .sh
            ldh a, [rLY]
            sub 144
            cp 8
            jr nc, .sh
            ld a, [tw_ql]
            ld l, a
            ld a, [tw_qh]
            ld h, a
            ld a, [tw_qt]
            ld [hl], a
            xor a
            ld [tw_qh], a
.sh:        ld a, 7
            ldh [rWX], a
            xor a
            ldh [rWY], a
            ldh a, [rLCDC]
            set 5, a
            set 6, a
            ldh [rLCDC], a
            ret

; STAT (LYC = 63): the window hidden from line 64, in H-Blank (FF1's: WX, not LCDC)
stat_int:   push af
            ldh a, [bmode]                  ; (a battle: its own STAT work: bridge.s)
            and a
            jp nz, stat_b
.hb:        ldh a, [rSTAT]
            and 3
            jr nz, .hb
            ld a, 167
            ldh [rWX], a
            pop af
            reti

section wram, $D400                         ; (WRAM bank 1)
win_buf:    ds 256                          ; the box: 20 x 8 cells
win_tx:     ds 256                          ; the page as it will be, for the typing
box_on:     ds 1
win_up:     ds 1                            ; rows up in the window map (8: shown)
dlg_bank:   ds 1
dlg_ptr:    ds 2
dlg_more:   ds 1
tw_i:       ds 1
tw_acc:     ds 1
tw_qh:      ds 1
tw_ql:      ds 1
tw_qt:      ds 1
dlg_one:    ds 1                            ; 1: a one-line box (a map's title)
nm_v:       ds 3
nm_buf:     ds 9
