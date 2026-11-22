; ---- dialogue (FF3 fix:EC8B "show dialogue", FEE65 / FEE9A / FEEFA text decoding) on the GB:
; the window layer at the top of the screen (20 x 6 tiles: frame, 4 lines of 18, frame), cut off
; at line 48 by an LYC interrupt; its tiles have BG priority (people never show over the box).
; The text was laid out at build time (tools/gb3n/text.py: pages of 4 lines of 18 broken at
; paragraph / sentence ends); $01 new line, $0B new page, $00 end, FF3's codes for names.
; A page shows at once; any button (after all were released) turns the page, as fix:ECAB.
; (WIN_ROWS, WIN_LINE: main.s)

section bank 0, $2800
; A = table (0 t8000 events, 1 t8200 messages, 2 t8400 / 3 t8600 people), C = id
dlg_show:   ld b, a                         ; index: TXT_BANK $4000 + 3 (256 table + id)
            ld a, TXT_BANK
            ld [MBC5_BANKL], a
            ld h, b
            ld l, c
            ld d, h
            ld e, l
            add hl, hl
            add hl, de                      ; 3 (256 t + id)
            ld a, h
            add a, $40
            ld h, a
            ld a, [hl+]
            ld [t_bank], a
            ld a, [hl+]
            ld [t_ptr], a
            ld a, [hl]
            ld [t_ptr + 1], a
            ld a, [t_bank]                  ; (empty string: nothing shown)
            ld [MBC5_BANKL], a
            ld a, [t_ptr]
            ld l, a
            ld a, [t_ptr + 1]
            ld h, a
            ld a, [hl]
            and a
            ret z
            call win_open
.page:      call win_clear
            call t_page                     ; one page; Z: the end
            push af
            ld a, 1
            ld [win_dirty], a
            call wait_keys
            pop af
            jr nz, .page
            jp win_close

; draw one page into win_buf from t_ptr; NZ if a page follows
t_page:     ld a, 1
            ld [t_col], a
            ld [t_row], a
.ch:        ld a, [t_bank]
            ld [MBC5_BANKL], a
            ld a, [t_ptr]
            ld l, a
            ld a, [t_ptr + 1]
            ld h, a
            ld a, [hl+]
            ld b, a
            ld a, [hl]                      ; (the parameter byte, if any)
            ld c, a
            ld a, l
            ld [t_ptr], a
            ld a, h
            ld [t_ptr + 1], a
            ld a, b
            and a
            ret z                           ; end (Z)
            cp $0B
            jr nz, .nl
            or a                            ; new page (NZ)
            ret
.nl:        cp $01
            jr nz, .code
            ld a, 1
            ld [t_col], a
            ld hl, t_row
            inc [hl]
            jr .ch
.code:      cp $28
            jr nc, .put
            cp $02
            jr nz, .c3
            ld a, [t_item]                  ; $02: the item's name (fix:EF5B)
            jr .name
.c3:        cp $03
            jr nz, .c5
            ld a, [t_item]                  ; $03: its price (treasure gil: fix:EF6A)
            call item_price
            jr .num
.c5:        cp $05
            jr nz, .c10
            ld hl, GS + $1C                 ; $05: the party's gil
            ld a, [hl+]
            ld e, a
            ld a, [hl+]
            ld d, a
            ld a, [hl]
            ld c, a
.num:       call t_num
            jp .ch
.c10:       cp $10
            jp c, .ch                       ; ($04, $06-$0F: later)
            call t_skip1                    ; $10-$27: one parameter byte
            ld a, b
            cp $18
            jr nz, .c14
            ld a, c                         ; $18: an item's name (parameter)
.name:      ld l, a                         ; GAME_BANK $4400 + 16 id
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, $4400
            add hl, de
            ld b, 16
            ld a, 1
            ld [t_lead], a                  ; (leading blanks dropped)
.nc:        ld a, GAME_BANK
            ld [MBC5_BANKL], a
            ld a, [hl+]
            and a
            jp z, .ch
            cp $70                          ; (menu icons not in dialogue: fix:EF0E)
            jr c, .ns
            cp $FF
            jr nz, .nf
            ld a, [t_lead]
            and a
            jr nz, .ns
            ld a, $FF
.nf:        push af
            xor a
            ld [t_lead], a
            pop af
            push hl
            push bc
            call t_putc
            pop bc
            pop hl
.ns:        dec b
            jr nz, .nc
            jp .ch
.c14:       ld a, b
            cp $14
            jr nz, .nm
            ld a, c                         ; $14: column
            inc a
            ld [t_col], a
            jr .ch
.nm:        cp $14
            jr nc, .ch
            and 3                           ; $10-$13: a character's name ($6106 + $40 n)
            rrca
            rrca
            add a, 6
            ld l, a
            ld h, high(GS + $100)
            ld b, 6
.nmc:       ld a, [hl+]
            cp $FF
            jr z, .ch
            push hl
            push bc
            call t_putc
            pop bc
            pop hl
            dec b
            jr nz, .nmc
            jr .ch
.put:       call t_putc
            jr .ch

; CDE = 24-bit number (C high) -> its digits (no leading zeros)
t_num:      ld a, c
            ld [n24 + 2], a
            ld a, d
            ld [n24 + 1], a
            ld a, e
            ld [n24], a
            xor a
            ld [t_lead], a
            ld hl, t_pow
            ld b, 7
.d:         push bc
            ld c, 0                         ; digit = how often the power subtracts
.s:         ld a, [n24]
            sub [hl]
            ld e, a
            inc hl
            ld a, [n24 + 1]
            sbc [hl]
            ld d, a
            inc hl
            ld a, [n24 + 2]
            sbc [hl]
            dec hl
            dec hl
            jr c, .done
            ld [n24 + 2], a
            ld a, d
            ld [n24 + 1], a
            ld a, e
            ld [n24], a
            inc c
            jr .s
.done:      inc hl
            inc hl
            inc hl
            pop bc
            ld a, c
            and a
            jr nz, .pr
            ld a, [t_lead]
            and a
            jr nz, .pr
            ld a, b
            dec a
            jr nz, .nx                      ; (the last digit always)
.pr:        ld a, 1
            ld [t_lead], a
            ld a, c
            add a, $80
            push hl
            push bc
            call t_putc
            pop bc
            pop hl
.nx:        dec b
            jr nz, .d
            ret
t_pow:      db $40, $42, $0F, $A0, $86, $01, $10, $27, $00, $E8, $03, $00
            db $64, $00, $00, $0A, $00, $00, $01, $00, $00

; A = item -> CDE = its price (10/9E00 + 2 id)
item_price: ld l, a
            ld h, 0
            add hl, hl
            ld de, $4200
            add hl, de
            ld a, GAME_BANK
            ld [MBC5_BANKL], a
            ld a, [hl+]
            ld e, a
            ld d, [hl]
            ld c, 0
            ret

t_skip1:    ld hl, t_ptr
            inc [hl]
            ret nz
            inc hl
            inc [hl]
            ret

; A = tile -> win_buf (row t_row, column t_col); the column advances
t_putc:     ld b, a
            ld a, [t_row]
            cp WIN_ROWS - 1
            ret nc
            swap a                          ; row * 32
            add a, a
            ld l, a
            ld a, [t_col]
            cp 19
            ret nc
            add a, l
            ld l, a
            ld h, high(win_buf)
            ld [hl], b
            ld hl, t_col
            inc [hl]
            ret

; the frame (FEDF6 / FEE1D / FEE3E: $F7 $F8 $F9 / $FA $FB / $FC $FD $FE) and the attributes
; (BG palette 3, priority over sprites); the window shown
win_open:   ld hl, win_buf
            ld a, $F7
            ld [hl+], a
            ld b, 18
            ld a, $F8
.t:         ld [hl+], a
            dec b
            jr nz, .t
            ld a, $F9
            ld [hl], a
            ld hl, win_buf + 32 * (WIN_ROWS - 1)
            ld a, $FC
            ld [hl+], a
            ld b, 18
            ld a, $FD
.b:         ld [hl+], a
            dec b
            jr nz, .b
            ld a, $FE
            ld [hl], a
            ld hl, win_buf + 32
            ld c, WIN_ROWS - 2
.m:         ld a, $FA
            ld [hl], a
            ld a, l
            add a, 19
            ld l, a
            ld a, $FB
            ld [hl], a
            ld a, l
            add a, 13
            ld l, a
            dec c
            jr nz, .m
            call win_clear
            ld a, 3                         ; attributes: once, by DMA in the next V-Blank
            ld [win_dirty], a
            call wait_vbl
            ld a, 1
            ld [win_on], a
            ret

win_clear:  ld hl, win_buf + 32 + 1
            ld c, WIN_ROWS - 2
.r:         ld b, 18
            ld a, $FF
.c:         ld [hl+], a
            dec b
            jr nz, .c
            ld a, l
            add a, 14
            ld l, a
            dec c
            jr nz, .r
            ret

win_close:  xor a
            ld [win_on], a
            jp wait_vbl

; any button after all were released (fix:ECAB)
wait_keys:  call wait_vbl
            call read_pad
            ldh a, [pad]
            and a
            jr nz, wait_keys
.w:         call wait_vbl
            call read_pad
            ldh a, [pad]
            and a
            jr z, .w
            ret

; V-Blank part (from the handler): the box's rows by general-purpose DMA when changed
win_vbl:    ld a, [win_dirty]
            and a
            ret z
            bit 1, a
            jr z, .map
            ld a, 1                         ; attributes: palette 3 + priority, from win_attr
            ldh [rVBK], a
            ld a, high(win_attr)
            ldh [rHDMA1], a
            xor a
            ldh [rHDMA2], a
            ld a, $9C
            ldh [rHDMA3], a
            xor a
            ldh [rHDMA4], a
            ld a, WIN_ROWS * 2 - 1
            ldh [rHDMA5], a
            xor a
            ldh [rVBK], a
.map:       ld a, high(win_buf)
            ldh [rHDMA1], a
            xor a
            ldh [rHDMA2], a
            ld a, $9C
            ldh [rHDMA3], a
            xor a
            ldh [rHDMA4], a
            ld a, WIN_ROWS * 2 - 1
            ldh [rHDMA5], a
            xor a
            ld [win_dirty], a
            ret

; LCD status interrupt (LYC = WIN_LINE - 1): the window off from the next line on
stat_isr:   push af
            ld a, [menu_on]                 ; (a menu: the whole screen)
            and a
            jr nz, .x
.w:         ldh a, [rSTAT]
            and 3
            jr nz, .w
            ldh a, [rLCDC]
            res 5, a
            ldh [rLCDC], a
.x:         pop af
            reti

section wram, $CE00
win_buf:    ds 32 * WIN_ROWS                ; (page-aligned: DMA source)
section wram, $CF00
win_attr:   ds 32 * WIN_ROWS
t_bank:     ds 1
t_ptr:      ds 2
t_col:      ds 1
t_row:      ds 1
win_dirty:  ds 1
win_on:     ds 1
t_item:     ds 1                            ; FF3 $BB: the item of {02} / {03}
t_lead:     ds 1
n24:        ds 3
