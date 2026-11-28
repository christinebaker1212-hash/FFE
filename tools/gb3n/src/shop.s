; ---- shops (FF3 3D/AF1F) and inns (3C/8E8D), from talking to a person whose id is $E3-$FB (shop)
; or $E0-$E2 (inn); EV_TRIG holds its script (FF3 $7B00: the shop type 7-10 and eight items; the
; inn's price per member and its event). FF3's rules: buy 1 / 4 (4p - 104p / 256) / 10 (10p -
; 510p / 256), not enough gil, 99 at most a slot, a free slot; sell 1 / all at half price, key
; items ($9A-$A3) and the toad / mini magic ($F6 / $F7) refused; gil capped as FF3 (gil_add).
; GB layout (20 x 18, the full-screen menu window; windows sharing borders as FF1's GB shop):
; message (0, 0, 20, 5): 3 lines; band (0, 4, 20, 4): the choices on row 5, the shop's name (or
; How many?) and the gil on row 6; list (0, 7, 20, 11): the goods one a row (rows 8-15: icon,
; name, price at the right; names longer than ten letters in condensed letters, shop.py) or, to
; sell, the inventory (8 rows of the 32 slots, scrolling; name, : count).
SH_T       = $90                ; VRAM bank 1 tiles: the list rows' condensed names (10 a row)
SH_ROW     = 8                  ; the list's first row
SFX_OK     = $85                ; FF3's sounds: confirm (fix:D20D), move (D213), error (D529)
SFX_MOVE   = $98
SFX_ERR    = $86

shop_open:  xor a
            ld [sh_ev], a
            ld [sh_q], a
            ld [sh_lc], a
            call oam_hide
            call menu_pals
            call hand_ld
            call font_menu
            ld a, MENU_BANK                 ; item icons -> VRAM bank 1 $50-$6F
            ld [vc_src], a
            ld hl, $5E00
            ld de, $8000 + 16 * ICON_T
            ld b, 32
            ld a, 1
            call vcopyx
            ld a, 2
            ldh [rSVBK], a
            ld a, 1
            ld [menu_on], a
            call sh_prices
.top:       ld a, $26                       ; Welcome! What is your business?
            ld [sh_msg], a
.main:      xor a
            ld [sh_mode], a
            ld [sh_band], a
            ld [sh_ccur], a
            call sh_draw
            ld hl, sh_main
            call sh_choose
            jr c, .close
            and a
            jr z, .buy
            dec a
            jp z, .sell
.close:     call cur_hide
            jp menu_close
; buy: the quantity (FF3 AFC2), then the goods (B01A)
.buy:       ld a, $27                       ; What shall it be?
            ld [sh_msg], a
.bq:        ld a, 1
            ld [sh_band], a
            ld a, [sh_q]
            ld [sh_ccur], a
            call sh_draw
            ld hl, sh_qbuy
            call sh_choose
            jr c, .top
            ld [sh_q], a
            call sh_prices
            call sh_draw
.bl:        ld a, [sh_lc]                   ; the hand at the goods' row
            add a, SH_ROW
            call sh_hand_row
            call sh_frame
            ld a, [m_new]
            bit 1, a
            jr nz, .bb
            bit 0, a
            jr nz, .ba
            ld b, a
            ld a, [sh_lc]
            bit 6, b
            jr z, .bd
            and a
            jr z, .bl
            dec a
            jr .bs
.bd:        bit 7, b
            jr z, .bl
            cp 7
            jr z, .bl
            inc a
.bs:        ld [sh_lc], a
            call sh_move
            jr .bl
.bb:        call sh_ok
            jr .buy
.ba:        call sh_ok
            call sh_buy1
            call sh_draw
            jr .bl
; sell: 1 / all (B0EB), then the inventory (B13D)
.sell:      xor a
            ld [sh_cur], a
            ld [sh_top], a
.sq:        ld a, $2A                       ; What will you sell?
            ld [sh_msg], a
            ld a, 2
            ld [sh_band], a
            ld a, 1
            ld [sh_mode], a
            xor a
            ld [sh_ccur], a
            call sh_draw
            ld hl, sh_qsell
            call sh_choose
            jp c, .top
            ld [sh_q], a
.sl:        ld a, [sh_cur]
            ld b, a
            ld a, [sh_top]
            ld c, a
            ld a, b
            sub c
            add a, SH_ROW
            call sh_hand_row
            call sh_frame
            ld a, [m_new]
            bit 1, a
            jr nz, .sb
            bit 0, a
            jr nz, .sa
            ld b, a
            ld a, [sh_cur]
            bit 6, b
            jr z, .sd
            and a
            jr z, .sl
            dec a
            ld [sh_cur], a
            call sh_move
            ld b, a
            ld a, [sh_top]
            cp b
            jr c, .sl
            jr z, .sl
            ld a, b
            ld [sh_top], a
            call sh_draw
            jr .sl
.sd:        bit 7, b
            jr z, .sl
            cp 31
            jr z, .sl
            inc a
            ld [sh_cur], a
            call sh_move
            ld b, a
            ld a, [sh_top]
            add a, 7
            cp b
            jr nc, .sl
            ld a, b
            sub 7
            ld [sh_top], a
            call sh_draw
            jr .sl
.sb:        call sh_ok
            jp .sq
.sa:        call sh_sell1
            call sh_draw
            jr .sl

; one frame of input: the canvas, the pad (m_new)
sh_frame:   call wait_vbl
            call read_pad
            jp m_keys
sh_ok:      ld a, SFX_OK
            ld [S49], a
            ret
sh_move:    push af
            ld a, SFX_MOVE
            ld [S49], a
            pop af
            ret
; the hand at row A, columns 0-1
sh_hand_row: add a, a
            add a, a
            add a, a
            add a, 16 - 4
            ld c, a
            ld b, 8
            jp cursor_at

; ---- buying goods row sh_lc (FF3 B04D): the price against the gil first, then the item
sh_buy1:    ld a, [sh_lc]
            call sh_prp                     ; HL = its price
            ld a, [hl+]
            ld [sh_val], a
            ld a, [hl+]
            ld [sh_val + 1], a
            ld a, [hl]
            ld [sh_val + 2], a
            call sh_gilok
            jr nc, .ok
            ld a, SFX_ERR
            ld [S49], a
            ld a, $6C                       ; You don't have enough money.
            ld [sh_msg], a
            ret
.ok:        ld a, [sh_lc]
            add a, low(EV_TRIG + 1)
            ld l, a
            ld h, high(EV_TRIG + 1)
            ld a, [hl]
            and a
            ret z
            ld [sh_id], a
            ld a, [sh_q]                    ; 1 / 4 / 10
            ld c, 1
            and a
            jr z, .q
            ld c, 4
            dec a
            jr z, .q
            ld c, 10
.q:         ld a, c
            ld [sh_n], a
            ld a, [sh_id]                   ; 3C/937E: its slot, else a free one
            call sh_find
            jr c, .full
            ld a, l
            add a, $20
            ld e, a
            ld d, h                         ; DE = the count
            ld a, [hl]
            and a
            jr z, .new
            ld a, [de]
            ld b, a
            ld a, [sh_n]
            add a, b
            cp 100
            jr nc, .full
            jr .set
.new:       ld a, [sh_id]
            ld [hl], a
            ld a, [sh_n]
.set:       ld [de], a
            ld hl, GS + $1C                 ; the gil - the price
            ld a, [sh_val]
            ld b, a
            ld a, [hl]
            sub b
            ld [hl+], a
            ld a, [sh_val + 1]
            ld b, a
            ld a, [hl]
            sbc b
            ld [hl+], a
            ld a, [sh_val + 2]
            ld b, a
            ld a, [hl]
            sbc b
            ld [hl], a
            ld a, $28                       ; Thank you so much! Anything else?
            ld [sh_msg], a
            ret
.full:      ld a, $2C                       ; You're carrying too much to buy more.
            ld [sh_msg], a
            ret

; A = item: HL = its inventory slot ($60C0 + n), else the first free one; carry: none
sh_find:    ld b, a
            ld hl, GS + $C0
.f:         ld a, [hl]
            cp b
            ret z                           ; (carry clear)
            inc l
            ld a, l
            cp low(GS + $E0)
            jr nz, .f
            ld hl, GS + $C0
.e:         ld a, [hl]
            and a
            ret z
            inc l
            ld a, l
            cp low(GS + $E0)
            jr nz, .e
            scf
            ret

; carry if the gil < sh_val (B0CA)
sh_gilok:   ld hl, GS + $1E
            ld a, [sh_val + 2]
            ld b, a
            ld a, [hl-]
            cp b
            ret nz                          ; (carry: less)
            ld a, [sh_val + 1]
            ld b, a
            ld a, [hl-]
            cp b
            ret nz
            ld a, [sh_val]
            ld b, a
            ld a, [hl]
            cp b
            ret

; ---- selling slot sh_cur (B14F): refused items, the price (1, or all: x the count) / 2, A to
; sell (That will come to n Gil.), B not
sh_sell1:   ld a, [sh_cur]
            add a, low(GS + $C0)
            ld l, a
            ld h, high(GS + $C0)
            ld a, [hl]
            and a
            jr z, .err
            cp $9A
            jr c, .ok
            cp $A4
            jr c, .err
            cp $F6
            jr z, .err
            cp $F7
            jr nz, .ok
.err:       ld a, SFX_ERR
            ld [S49], a
            ret
.ok:        ld [sh_id], a
            call sh_ok
            call shx_sval0
            ld a, $2B                       ; That will come to {04} Gil.
            jp sh_sell2
; ---- for the rebuilt shop (shp.s, CODE13): sh_cur / sh_q set; u_eres 1 if refused, else 0 and
; the value in sh_val / t_gil
shx_sval:   ld a, 1
            ld [u_eres], a
            ld a, [sh_cur]
            add a, low(GS + $C0)
            ld l, a
            ld h, high(GS + $C0)
            ld a, [hl]
            and a
            ret z
            cp $9A
            jr c, .ok
            cp $A4
            ret c
            cp $F6
            ret z
            cp $F7
            ret z
.ok:        ld [sh_id], a
            xor a
            ld [u_eres], a
shx_sval0:  ld a, [sh_id]
            call sh_price                   ; CDE
            ld a, [sh_q]
            and a
            jr z, .one
            ld a, [sh_cur]
            add a, low(GS + $E0)
            ld l, a
            ld h, high(GS + $E0)
            ld a, [hl]
            call sh_mul
.one:       srl c                           ; / 2
            rr d
            rr e
            ld a, e
            ld [sh_val], a
            ld [t_gil], a
            ld a, d
            ld [sh_val + 1], a
            ld [t_gil + 1], a
            ld a, c
            ld [sh_val + 2], a
            ld [t_gil + 2], a
            ret
sh_sell2:   ld [sh_msg], a
            call sh_draw
            call cur_hide
.w:         call sh_frame                   ; A: sell, B: not
            ld a, [m_new]
            and 3
            jr z, .w
            push af
            ld a, $2A
            ld [sh_msg], a
            pop af
            bit 0, a
            ret z
            call sh_ok
shx_sell:   ld a, [sh_cur]                  ; (the sale itself; shp.s too)
            add a, low(GS + $C0)
            ld l, a
            ld h, high(GS + $C0)
            ld a, [sh_q]
            and a
            jr nz, .all
            ld a, l
            add a, $20
            ld e, a
            ld d, h
            ld a, [de]
            dec a
            ld [de], a
            jr nz, .gil
.all:       xor a
            ld [hl], a
            ld a, l
            add a, $20
            ld l, a
            ld [hl], 0
.gil:       ld a, [sh_val]
            ld e, a
            ld a, [sh_val + 1]
            ld d, a
            ld a, [sh_val + 2]
            ld c, a
            jp gil_add

shx_prices: jp sh_prices
shx_buy:    call sh_buy1                    ; (sh_lc, sh_q: sh_msg the outcome)
            ld a, [sh_msg]
            ld [u_eres], a
            ret

; ---- prices: A = item -> CDE (10/9E00 + 2 id)
sh_price:   ld l, a
            ld h, 0
            add hl, hl
            ld de, $4200
            add hl, de
            ld a, GAME_BANK
            call rd_byte
            ld e, a
            ld a, GAME_BANK
            call rd_byte
            ld d, a
            ld c, 0
            ret
; CDE * A -> CDE (24 bits kept, as FF3's 3C/8E55)
sh_mul:     push hl
            ld b, a
            ld hl, 0
            xor a
            ld [sh_hi], a
.l:         srl b
            jr nc, .s
            ld a, l                         ; (sh_hi:HL) += CDE
            add a, e
            ld l, a
            ld a, h
            adc a, d
            ld h, a
            ld a, [sh_hi]
            adc a, c
            ld [sh_hi], a
.s:         sla e
            rl d
            rl c
            ld a, b
            and a
            jr nz, .l
            ld e, l
            ld d, h
            ld a, [sh_hi]
            ld c, a
            pop hl
            ret
; HL = sh_pr + 3 A
sh_prp:     ld b, a
            add a, a
            add a, b
            add a, low(sh_pr)
            ld l, a
            ld h, high(sh_pr)
            ret
; the eight goods' prices for quantity sh_q (FF3 B220 / B281)
sh_prices:  xor a
.i:         ld [sh_k], a
            add a, low(EV_TRIG + 1)
            ld l, a
            ld h, high(EV_TRIG + 1)
            ld a, [hl]
            call sh_price
            ld a, [sh_q]
            and a
            jr z, .st
            ld b, 4                         ; 4p - 104p / 256
            ld a, 26
            dec a
            jr z, .x
            ld a, [sh_q]
            cp 1
            ld b, 4
            ld a, 26
            jr z, .x
            ld b, 10                        ; 10p - 510p / 256
            ld a, 51
.x:         ld [sh_f], a
            ld a, b
            call sh_mul                     ; X
            ld a, e
            ld [sh_x], a
            ld a, d
            ld [sh_x + 1], a
            ld a, c
            ld [sh_x + 2], a
            ld a, [sh_f]
            call sh_mul                     ; Y = X * f
            ld a, [sh_x]                    ; X - (Y >> 8)
            sub d
            ld e, a
            ld a, [sh_x + 1]
            sbc c
            ld d, a
            ld a, [sh_x + 2]
            sbc 0
            ld c, a
.st:        ld a, [sh_k]
            call sh_prp
            ld [hl], e
            inc hl
            ld [hl], d
            inc hl
            ld [hl], c
            ld a, [sh_k]
            inc a
            cp 8
            jr nz, .i
            ret

; ---- choices (data: n, then n x (column, string, 0)) on row 5: A = the one taken (carry: B);
; left / right move (sh_ccur)
sh_choose:  ld a, l
            ld [sh_cp], a
            ld a, h
            ld [sh_cp + 1], a
.l:         ld a, [sh_ccur]
            call sh_ccol
            sub 2
            add a, a
            add a, a
            add a, a
            add a, 8
            ld b, a
            ld c, 5 * 8 + 16 - 4
            call cursor_at
            call sh_frame
            ld a, [m_new]
            bit 1, a
            jr nz, .b
            bit 0, a
            jr nz, .a
            ld b, a
            ld a, [sh_cp]
            ld l, a
            ld a, [sh_cp + 1]
            ld h, a
            ld c, [hl]                      ; (n)
            ld a, [sh_ccur]
            bit 5, b
            jr z, .r
            and a
            jr z, .l
            dec a
            jr .s
.r:         bit 4, b
            jr z, .l
            inc a
            cp c
            jr z, .l
.s:         ld [sh_ccur], a
            call sh_move
            jr .l
.b:         call sh_ok
            scf
            ret
.a:         call sh_ok
            ld a, [sh_ccur]
            and a
            ret
; A = choice -> A = its column; HL past the count
sh_ccol:    ld b, a
            ld a, [sh_cp]
            ld l, a
            ld a, [sh_cp + 1]
            ld h, a
            inc hl
.n:         ld a, b
            and a
            jr z, .c
.z:         inc hl                          ; (past the column and the string)
            ld a, [hl]
            and a
            jr nz, .z
            inc hl
            dec b
            jr .n
.c:         ld a, [hl]
            ret
; the choices' words
sh_cdraw:   ld a, [hl+]
            ld e, a
.w:         ld a, [hl+]
            ld b, a
            ld c, 5
            push de
            call m_str
            pop de
            dec e
            jr nz, .w
            ret

; ---- the screen
sh_draw:    call m_clear
            ld bc, $0000
            ld de, $1405
            call m_box
            ld bc, $0004
            ld de, $1404
            call m_box
            ld bc, $0007
            ld de, $140B
            call m_box
            ld a, 4                         ; the message: 3 lines
            ld [t_maxr], a
            ld a, [sh_msg]
            ld e, a
            ld bc, $0101
            call m_msg1n
            ld a, [sh_band]                 ; the band: choices, name / How many?, gil
            cp 3
            jr z, .g                        ; (the fat chocobo: the gil only)
            ld hl, sh_main
            and a
            jr z, .c
            ld hl, sh_qbuy
            dec a
            jr z, .c
            ld hl, sh_qsell
.c:         call sh_cdraw
            ld a, [sh_band]
            and a
            ld hl, sh_how
            jr nz, .t
            ld a, [EV_TRIG]                 ; (type 7-10)
            sub 7
            and 3
            add a, a
            ld e, a
            ld d, 0
            ld hl, sh_titles
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
.t:         ld bc, $0306
            call m_str
.g:         ld hl, GS + $1C                 ; the gil: small digits and G (as the main menu)
            ld a, [hl+]
            ld e, a
            ld a, [hl+]
            ld d, a
            ld a, [hl]
            ld h, a
            ld a, SN_T
            ld [sn_tile], a
            ld bc, $0E06
            call sn_draw24
            ld bc, $1206
            ld a, $90
            call m_put
            xor a                           ; the list
.r:         ld [sh_k], a
            call sh_lrow
            ld a, [sh_k]
            inc a
            cp 8
            jr nz, .r
            ld a, 1
            ld [m_dirty], a
            ret
sh_titles:  dw sh_title0, sh_title1, sh_title2, sh_title3

; list row sh_k: the goods (sh_mode 0: name, price) or inventory slot sh_top + k (name, count)
sh_lrow:    ld a, [sh_mode]
            cp 2
            jp z, ch_orow
            cp 3
            jp z, ch_srow
            and a
            jr nz, .inv
            ld a, [sh_k]
            add a, low(EV_TRIG + 1)
            ld l, a
            ld h, high(EV_TRIG + 1)
            ld a, [hl]
            and a
            ret z
            call sh_name
            ld a, [sh_k]
            call sh_prp
            ld a, [hl+]
            ld [n24], a
            ld a, [hl+]
            ld [n24 + 1], a
            ld a, [hl]
            ld [n24 + 2], a
            ld a, [sh_k]
            add a, SH_ROW
            ld c, a
            ld b, 18
            jp m_dec24
.inv:       ld a, [sh_top]
            ld b, a
            ld a, [sh_k]
            add a, b
            add a, low(GS + $C0)
            ld l, a
            ld h, high(GS + $C0)
            ld a, [hl]
            and a
            ret z
            push hl
            call sh_name
            pop hl
            ld a, l
            add a, $20
            ld l, a
            ld e, [hl]
            ld d, 0
            ld a, [sh_k]
            add a, SH_ROW
            ld c, a
            ld b, 16
            ld a, $C8                       ; :
            call m_put
            ld b, 18
            jp m_dec
; item A on list row sh_k: its icon (column 2), its name from column 3 (ten cells: the font, or
; the condensed tiles SH_T + 10 k)
sh_name:    ld [sh_id], a
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, $4400
            add hl, de
            ld de, it_nbuf
            ld bc, 16
            ld a, GAME_BANK
            call rd_copy
            ld a, [sh_k]
            add a, SH_ROW
            ld c, a
            ld b, 2
            ld hl, it_nbuf
            ld a, [hl]
            cp $70
            jr nc, .ni
            inc hl                          ; an icon (VRAM bank 1)
            push af
            ld a, PAL_TXT | 8
            ld [m_attr], a
            pop af
            call m_put2
            jr .nm
.ni:        cp $FF
            jr nz, .nm
            inc hl                          ; (a leading blank)
.nm:        ld b, 3
            push hl
            ld a, [sh_id]                   ; condensed? (GAME_BANK $7900 + id)
            ld l, a
            ld h, $79
            ld a, GAME_BANK
            call rd_byte
            pop hl
            and a
            jr nz, .cond
            ld e, 10
.ch:        ld a, [hl+]
            and a
            ret z
            call m_put
            inc b
            dec e
            jr nz, .ch
            ret
.cond:      ld a, [sh_id]                   ; bank ITEMN_BANK0 + id / 102, $4000 + 160 (id mod 102)
            ld e, 0
.dv:        cp 102
            jr c, .dd
            sub 102
            inc e
            jr .dv
.dd:        ld l, a
            ld h, 0
            add hl, hl                      ; x 160 = x 32 x 5
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld d, h
            push bc
            ld b, l
            add hl, hl
            add hl, hl
            ld a, l
            add a, b
            ld l, a
            ld a, h
            adc a, d
            add a, $40
            ld h, a
            ld a, e
            add a, ITEMN_BANK0
            ld [vc_src], a
            ld a, [sh_k]                    ; -> VRAM bank 1 SH_T + 10 k
            ld b, a
            add a, a
            add a, a
            add a, b
            add a, a
            add a, SH_T
            ld [sh_t0], a
            swap a
            ld e, a
            and $F0
            ld d, a
            ld a, e
            and $0F
            add a, $80
            ld e, d
            ld d, a
            ld b, 10
            ld a, 1
            call vcopyx
            pop bc
            ld a, PAL_TXT | 8
            ld [m_attr], a
            ld a, [sh_t0]
            ld e, 10
.ct:        call m_put2
            inc a
            inc b
            dec e
            jr nz, .ct
            ld a, [m_tattr]                 ; (the font's attribute again)
            ld [m_attr], a
            ret

; ---- the inn (3C/8E8D), a box over the field: the cost (members not dead / stone x 5 x the
; script's price), Innkeeper: Welcome! ... {04} Gil. Will you stay the night? ($0104, its
; pages), Yes / No and the gil; Yes: the gil taken (not enough: $016C), Thank you very much.
; Please rest well... ($014F), HP restored, the script's event after (FF3 $7B01 -> $6C)
inn_open:   xor a
            ld [sh_ev], a
            ld [sh_val], a                  ; the cost
            ld [sh_val + 1], a
            ld [sh_val + 2], a
            ld b, 0
            ld hl, GS + $102
.m:         ld a, [hl]
            and $C0
            jr nz, .d
            inc b
.d:         ld a, l
            add a, $40
            ld l, a
            cp 2
            jr nz, .m
            ld a, b                         ; x 5
            add a, a
            add a, a
            add a, b
            ld b, a
            ld a, [EV_TRIG]
            ld e, a
            ld d, 0
            ld c, 0
            ld a, b
            call sh_mul
            ld a, e
            ld [sh_val], a
            ld [t_gil], a
            ld a, d
            ld [sh_val + 1], a
            ld [t_gil + 1], a
            ld a, c
            ld [sh_val + 2], a
            ld [t_gil + 2], a
            call menu_pals
            call hand_ld
            call font_box
            ld a, 2
            ldh [rSVBK], a
            ld a, 4
            ld e, a
            call inn_text                   ; the question's pages
            ld a, 1
            ld [sh_ccur], a                 ; (FF3's cursor starts on No? 3C/8F04: Yes)
            xor a
            ld [sh_ccur], a
.yn:        ld a, [sh_ccur]                 ; the hand at Yes / No
            add a, a
            add a, a
            add a, a
            add a, 7 * 8 + 16 - 4
            ld c, a
            ld b, 8
            call cursor_at
            call sh_frame
            ld a, [m_new]
            bit 1, a
            jr nz, .no
            bit 0, a
            jr nz, .a
            and $C0
            jr z, .yn
            ld a, [sh_ccur]
            xor 1
            ld [sh_ccur], a
            call sh_move
            jr .yn
.a:         call sh_ok
            ld a, [sh_ccur]
            and a
            jr nz, .out
            call sh_gilok
            jr nc, .pay
            ld a, $6C                       ; You don't have enough money.
            jr .last
.pay:       ld hl, GS + $1C
            ld a, [sh_val]
            ld b, a
            ld a, [hl]
            sub b
            ld [hl+], a
            ld a, [sh_val + 1]
            ld b, a
            ld a, [hl]
            sbc b
            ld [hl+], a
            ld a, [sh_val + 2]
            ld b, a
            ld a, [hl]
            sbc b
            ld [hl], a
            ld hl, GS + $102                ; HP to max (living members)
.h:         ld a, [hl]
            and $C0
            jr nz, .hn
            push hl
            ld a, l                         ; (HL = +$02: max +$0E / $0F -> HP +$0C / $0D)
            add a, $0C
            ld l, a
            ld a, [hl+]
            ld b, [hl]
            dec hl
            dec hl
            dec hl
            ld [hl+], a
            ld [hl], b
            pop hl
.hn:        ld a, l
            add a, $40
            ld l, a
            cp 2
            jr nz, .h
            ld a, [EV_TRIG + 1]
            ld [sh_ev], a
            ld a, $4F                       ; Thank you very much. Please rest well...
.last:      ld e, a
            call inn_text
            call cur_hide
            call wait_keys
            ldh a, [pad]
            ld [m_old], a
            jr .out
.no:        call sh_ok
.out:       call cur_hide
            jp sel_close

; ---- for the rebuilt inn (shp.s inn13): the cost (members not dead / stone x 5 x the price) ->
; sh_val / t_gil; the stay: the gil (u_eres $6C if short), HP to max, the script's event after
shx_icost:  xor a
            ld [sh_ev], a
            ld [sh_val], a
            ld [sh_val + 1], a
            ld [sh_val + 2], a
            ld b, 0
            ld hl, GS + $102
.m:         ld a, [hl]
            and $C0
            jr nz, .d
            inc b
.d:         ld a, l
            add a, $40
            ld l, a
            cp 2
            jr nz, .m
            ld a, b
            add a, a
            add a, a
            add a, b
            ld b, a
            ld a, [EV_TRIG]
            ld e, a
            ld d, 0
            ld c, 0
            ld a, b
            call sh_mul
            ld a, e
            ld [sh_val], a
            ld [t_gil], a
            ld a, d
            ld [sh_val + 1], a
            ld [t_gil + 1], a
            ld a, c
            ld [sh_val + 2], a
            ld [t_gil + 2], a
            ret
shx_istay:  call sh_gilok
            ld a, $6C
            jr c, .r
            ld hl, GS + $1C
            ld a, [sh_val]
            ld b, a
            ld a, [hl]
            sub b
            ld [hl+], a
            ld a, [sh_val + 1]
            ld b, a
            ld a, [hl]
            sbc b
            ld [hl+], a
            ld a, [sh_val + 2]
            ld b, a
            ld a, [hl]
            sbc b
            ld [hl], a
            ld hl, GS + $102
.h:         ld a, [hl]
            and $C0
            jr nz, .hn
            push hl
            ld a, l
            add a, $0C
            ld l, a
            ld a, [hl+]
            ld b, [hl]
            dec hl
            dec hl
            dec hl
            ld [hl+], a
            ld [hl], b
            pop hl
.hn:        ld a, l
            add a, $40
            ld l, a
            cp 2
            jr nz, .h
            ld a, [EV_TRIG + 1]
            ld [sh_ev], a
            xor a
.r:         ld [u_eres], a
            ret

; t8200 string E in the inn box (rows 0-5: 4 lines), its pages one by one (A between them); with
; the question ($0104) its last page shows Yes / No (rows 6-9) and the gil beside it; Z at the end
inn_text:   ld a, e
            ld [sh_msg], a
            ld a, 1
            ld c, e
            call t_open
.pg:        call m_clear_t
            ld bc, $0000
            ld de, $1406
            call m_box
            ld a, 5                         ; (4 lines)
            ld [t_maxr], a
            ld a, 1
            ld [t_bx], a
            ld [t_by], a
            ld [t_dest], a
            call t_page
            push af
            xor a
            ld [t_dest], a
            ld a, 6 * 8
            ld [sh_k], a                    ; (the window cut: under the message)
            pop af
            push af
            jr nz, .show
            ld a, [sh_msg]
            cp $04
            jr nz, .show
            ld bc, $0006                    ; the question's last page: Yes / No, the gil
            ld de, $0704
            call m_box
            ld hl, sh_yes
            ld bc, $0207
            call m_str
            ld hl, sh_no
            ld bc, $0208
            call m_str
            ld bc, $0706
            ld de, $0D04
            call m_box
            ld hl, GS + $1C
            ld a, [hl+]
            ld [n24], a
            ld a, [hl+]
            ld [n24 + 1], a
            ld a, [hl]
            ld [n24 + 2], a
            ld bc, $0F07
            call m_dec24
            ld hl, sh_gil
            ld bc, $1007
            call m_str
            ld a, 10 * 8
            ld [sh_k], a
.show:      ld a, 1
            ld [m_dirty], a
            ld a, [sh_k]
            call win_cut
            pop af
            ret z                           ; (the last page)
            call cur_hide
            call wait_keys
            ldh a, [pad]                    ; (that press is not a new one for the next loop)
            ld [m_old], a
            jr .pg

ch_list    = $DA00              ; (WRAM bank 2: the menus run with it)
ch_n       = $DB00
; ---- the fat chocobo (3D/B383): Yooo, need somethiiing? ($0151); Deposit / Withdraw / Exit ($0124,
; a row each in the list); Deposit: the inventory, A puts a slot's items in his storage ($6300 +
; item, 99 at most; key items $9A-$A3 refused; I can't eat no more of the same stuff! at 99);
; Withdraw: the stored items, A takes one back (into its slot or a free one; a slot of 153 or more
; keeps it there: FF3's compare; more than 99: the rest stays stored)
choc_open:  xor a
            ld [sh_ev], a
            ld [sh_lc], a
            call oam_hide
            call menu_pals
            call hand_ld
            call font_menu
            ld a, MENU_BANK
            ld [vc_src], a
            ld hl, $5E00
            ld de, $8000 + 16 * ICON_T
            ld b, 32
            ld a, 1
            call vcopyx
            ld a, 2
            ldh [rSVBK], a
            ld a, 1
            ld [menu_on], a
            ld a, 3
            ld [sh_band], a
            ld a, $51
            ld [sh_msg], a
.top:       ld a, 2
            ld [sh_mode], a
            call sh_draw
.o:         ld a, [sh_lc]
            add a, SH_ROW
            call sh_hand_row
            call sh_frame
            ld a, [m_new]
            bit 1, a
            jr nz, .close
            bit 0, a
            jr nz, .oa
            ld b, a
            ld a, [sh_lc]
            bit 6, b
            jr z, .od
            and a
            jr z, .o
            dec a
            jr .os
.od:        bit 7, b
            jr z, .o
            cp 2
            jr z, .o
            inc a
.os:        ld [sh_lc], a
            call sh_move
            jr .o
.oa:        call sh_ok
            ld a, [sh_lc]
            and a
            jr z, .give
            dec a
            jr z, .take
.close:     call cur_hide
            jp menu_close
.give:      ld a, $52                       ; Whatcha gonna give meee?
            ld [sh_msg], a
            ld a, 1
            jr .list
.take:      ld a, $53                       ; Whaddaya want, ya saaay?
            ld [sh_msg], a
            call ch_build
            ld a, 3
.list:      ld [sh_mode], a
            xor a
            ld [sh_cur], a
            ld [sh_top], a
            call sh_draw
.l:         ld a, [sh_cur]
            ld b, a
            ld a, [sh_top]
            ld c, a
            ld a, b
            sub c
            add a, SH_ROW
            call sh_hand_row
            call sh_frame
            ld a, [m_new]
            bit 1, a
            jr nz, .lb
            bit 0, a
            jr nz, .la
            ld b, a
            ld a, [sh_cur]
            bit 6, b
            jr z, .ld
            and a
            jr z, .l
            dec a
            ld [sh_cur], a
            call sh_move
            ld b, a
            ld a, [sh_top]
            cp b
            jr c, .l
            jr z, .l
            ld a, b
            ld [sh_top], a
            call sh_draw
            jr .l
.ld:        bit 7, b
            jr z, .l
            ld c, a
            call ch_last
            ld a, c
            cp b
            jr nc, .l
            inc a
            ld [sh_cur], a
            call sh_move
            ld b, a
            ld a, [sh_top]
            add a, 7
            cp b
            jr nc, .l
            ld a, b
            sub 7
            ld [sh_top], a
            call sh_draw
            jr .l
.lb:        call sh_ok
            ld a, $51
            ld [sh_msg], a
            jp .top
.la:        ld a, [sh_mode]
            cp 1
            call z, ch_give
            ld a, [sh_mode]
            cp 3
            call z, ch_take
            call sh_draw
            jr .l

; B = the list's last index (the inventory 31, the storage its count - 1)
ch_last:    ld a, [sh_mode]
            cp 3
            ld b, 31
            ret nz
            ld a, [ch_n]
            and a
            jr z, .z
            dec a
.z:         ld b, a
            ret

; the stored items (3D/B570): ids with a count, from 1 up -> ch_list, ch_n
ch_build:   ld hl, ch_list
            ld de, $0100
            call memclr
            ld hl, GS + $301
            ld de, ch_list
            ld c, 1
            xor a
            ld [ch_n], a
.s:         ld a, [hl+]
            and a
            jr z, .n
            ld a, c
            ld [de], a
            inc de
            ld a, [ch_n]
            inc a
            ld [ch_n], a
.n:         inc c
            jr nz, .s
            ret

; 3D/B4AE deposit inventory slot sh_cur
ch_give:    ld a, [sh_cur]
            add a, low(GS + $C0)
            ld l, a
            ld h, high(GS + $C0)
            ld a, [hl]
            and a
            jr z, .err
            cp $9A
            jr c, .ok
            cp $A4
            jr c, .err
.ok:        ld e, a
            ld d, high(GS + $300)
            ld a, [de]
            cp $63
            jr c, .eat
            ld a, $55                       ; I can't eat no more of the same stuff!
            ld [sh_msg], a
            jp sh_ok
.eat:       ld b, a
            push hl
            ld a, l
            add a, $20
            ld l, a
            ld a, [hl]
            add a, b
            ld c, 0
            cp $64
            jr c, .st
            sub $63
            ld c, a
            ld a, $63
.st:        ld [de], a
            ld [hl], c
            pop hl
            ld a, c
            and a
            jr nz, .m
            ld [hl], a
.m:         ld a, $54                       ; Time to diiig in. Munch munch...
            ld [sh_msg], a
            jp sh_ok
.err:       ld a, $86
            ld [S49], a
            ret

; 3D/B504 withdraw list entry sh_cur
ch_take:    ld a, [sh_cur]
            ld e, a
            ld d, high(ch_list)
            ld a, e
            add a, low(ch_list)
            ld e, a
            jr nc, .p
            inc d
.p:         ld a, [de]
            and a
            jr z, ch_give.err
            ld [sh_id], a
            push de
            call sh_find                    ; (3D/937E)
            pop de
            jr nc, .f
            ld a, $56                       ; Your stuff's full, so I can't give it back
            ld [sh_msg], a
            jp sh_ok
.f:         ld a, [sh_id]
            ld c, a
            ld b, high(GS + $300)
            ld a, [hl]
            and a
            jr nz, .add
            ld [hl], c                      ; (a free slot: all of it)
            ld a, l
            add a, $20
            ld l, a
            ld a, [bc]
            ld [hl], a
            xor a
            ld [de], a
            ld [bc], a
            jr .done
.add:       ld a, l
            add a, $20
            ld l, a
            ld a, [hl]
            cp $99
            jr c, .a1
            ld a, $57                       ; I'll hang on to what I can't give back
            ld [sh_msg], a
            jp sh_ok
.a1:        push hl
            ld h, b
            ld l, c
            add a, [hl]
            pop hl
            cp $64
            jr nc, .a2
            ld [hl], a
            xor a
            ld [de], a
            ld [bc], a
            jr .done
.a2:        sub $63
            ld [bc], a
            ld [hl], $63
.done:      ld a, $58                       ; Hang on a sec, I'm gettin' it out...
            ld [sh_msg], a
            jp sh_ok

; list row sh_k: the options (mode 2) / a stored item and its count (mode 3)
ch_orow:    ld a, [sh_k]
            cp 3
            ret nc
            add a, a
            ld e, a
            ld d, 0
            ld hl, ch_words
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld a, [sh_k]
            add a, SH_ROW
            ld c, a
            ld b, 2
            jp m_str
ch_words:   dw ch_w0, ch_w1, ch_w2
ch_srow:    ld a, [sh_top]
            ld b, a
            ld a, [sh_k]
            add a, b
            add a, low(ch_list)
            ld l, a
            ld a, high(ch_list)
            adc a, 0
            ld h, a
            ld a, [hl]
            and a
            ret z
            push af
            call sh_name
            pop af
            ld e, a
            ld d, high(GS + $300)
            ld a, [de]
            ld e, a
            ld d, 0
            ld a, [sh_k]
            add a, SH_ROW
            ld c, a
            ld b, 16
            ld a, $C8                       ; :
            call m_put
            ld b, 18
            jp m_dec


section wram, $C3B0
sh_ev:      ds 1
sh_q:       ds 1
sh_lc:      ds 1
sh_cur:     ds 1
sh_top:     ds 1
sh_msg:     ds 1
sh_mode:    ds 1
sh_band:    ds 1
sh_ccur:    ds 1
sh_cp:      ds 2
sh_k:       ds 1
sh_id:      ds 1
sh_n:       ds 1
sh_f:       ds 1
sh_hi:      ds 1
sh_t0:      ds 1
sh_val:     ds 3
sh_x:       ds 3
sh_pr:      ds 24
t_gil:      ds 3
