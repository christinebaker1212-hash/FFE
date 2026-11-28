; ---- shp.s (bank CODE13, on the UI copy): shops (FF3 3D/AF1F, rebuilt for the owner's polish pass,
; 2026-11-28). Message (0,0,20,4): FF3's words, two lines. The choices (0,4,20,3): Buy / Sell / Exit,
; then How many? 1 / 4 / 10 (buying) or 1 / All (selling), the hand before each; the Gil at the
; right. The goods (0,7,20,11): the shop's name, then its eight goods (icon, name, the price for
; the quantity chosen) or, selling, the bag (8 rows of 32, scrolling; name, count). FF3's rules and
; prices (shop.s shx_*: buy 1 / 4 / 10 at FF3's discounts, sell at half price, the refused items).
SP_ROW     = 9                  ; the list's first row
SP_LP      = 70                 ; pool: 0-39 the message, 40-59 the choices and Gil, 60-69 the name,
SP_LR      = 14                 ;   70 + 14 k the list's row k

shp_open:   call u_open
            ld a, 5
            ld [sp_crow], a
            ld a, 40
            ld [sp_cpool], a
            xor a
            ld [sh_ev], a
            ld [sh_q], a
            ld [sh_lc], a
            ld a, CODE1
            ld hl, shx_prices
            call far_call
            ld a, 0                         ; Welcome! What is your business?
            ld [sp_msg], a
            xor a
            ld [sh_mode], a
            ld [sp_ch], a
            call sp_scr
            call u_flush
            call u_fadein
.main:      xor a                           ; Buy / Sell / Exit
            ld [sp_set], a
            ld [sh_mode], a
            call sp_cdraw
            call sp_list
            call u_flush
            call sp_choose
            jr c, .close
            and a
            jr z, .buy
            dec a
            jr z, .sell
.close:     call u_fadeout
            call u_hoff
            jp u_close
; buy: the quantity (FF3 AFC2), then the goods (B01A)
.buy:       ld a, 1                         ; What shall it be?
            ld [sp_msg], a
            call sp_mdraw
            ld a, 1
            ld [sp_set], a
            ld a, [sh_q]
            ld [sp_ch], a
            call sp_cdraw
            call u_flush
            call sp_choose
            jr c, .back
            ld [sh_q], a
            ld a, CODE1
            ld hl, shx_prices
            call far_call
            call sp_list
            call u_flush
.bl:        call sp_park
            ld a, [sh_lc]
            add a, SP_ROW
            ld c, a
            ld b, 3
            call u_hand
            call wait_vbl
            call u_keys
            ld a, [m_new]
            bit 1, a
            jr nz, .bb
            bit 0, a
            jr nz, .ba
            ld c, $FF                       ; (up: -1, down: +1; empty slots passed over)
            bit 6, a
            jr nz, .bt
            ld c, 1
            bit 7, a
            jr z, .bl
.bt:        ld a, [sh_lc]
.bn:        add a, c
            cp 8
            jr nc, .bl                      ; (past either end: stays)
            ld b, a
            add a, low(EV_TRIG + 1)
            ld l, a
            ld h, high(EV_TRIG + 1)
            ld a, [hl]
            and a
            ld a, b
            jr z, .bn
.bs:        ld [sh_lc], a
            call sp_mv
            jr .bl
.bb:        call sp_ok
            call sp_poff
            jr .buy
.ba:        call sp_ok
            ld a, CODE1
            ld hl, shx_buy
            call far_call
            ld a, [u_eres]                  ; (FF3's outcome: its message)
            call sp_msgid
            call sp_mdraw
            call sp_gil
            call u_flush
            jr .bl
.back:      xor a
            ld [sp_msg], a
            call sp_mdraw
            jp .main
; sell: 1 / all (B0EB), then the bag (B13D)
.sell:      xor a
            ld [sh_cur], a
            ld [sh_top], a
.sq:        ld a, 4                         ; What will you sell?
            ld [sp_msg], a
            call sp_mdraw
            ld a, 2
            ld [sp_set], a
            xor a
            ld [sp_ch], a
            call sp_cdraw
            ld a, 1
            ld [sh_mode], a
            call sp_list
            call u_flush
            call sp_choose
            jr c, .back
            ld [sh_q], a
.sl:        call sp_park
            ld a, [sh_cur]
            ld b, a
            ld a, [sh_top]
            ld c, a
            ld a, b
            sub c
            add a, SP_ROW
            ld c, a
            ld b, 3
            call u_hand
            call wait_vbl
            call u_keys
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
            call sp_mv
            ld b, a
            ld a, [sh_top]
            cp b
            jr c, .sl
            jr z, .sl
            ld a, b
            ld [sh_top], a
            call sp_list
            call u_flush
            jr .sl
.sd:        bit 7, b
            jr z, .sl
            cp 31
            jr z, .sl
            inc a
            ld [sh_cur], a
            call sp_mv
            ld b, a
            ld a, [sh_top]
            add a, 7
            cp b
            jr nc, .sl
            ld a, b
            sub 7
            ld [sh_top], a
            call sp_list
            call u_flush
            jr .sl
.sb:        call sp_ok
            call sp_poff
            jp .sq
.sa:        ld a, CODE1                     ; (refused, empty: the error sound)
            ld hl, shx_sval
            call far_call
            ld a, [u_eres]
            and a
            jr z, .sv
            ld a, $86
            ld [S49], a
            jp .sl
.sv:        call sp_ok
            ld a, 5                         ; That will come to n Gil. (A: sell, B: not)
            ld [sp_msg], a
            call sp_mdraw
            call u_flush
            call u_hoff
.sw:        call wait_vbl
            call u_keys
            ld a, [m_new]
            and 3
            jr z, .sw
            push af
            ld a, 4
            ld [sp_msg], a
            pop af
            bit 0, a
            jr z, .sn
            call sp_ok
            ld a, CODE1
            ld hl, shx_sell
            call far_call
            call sp_gil
            call sp_list
            jr .s2
.sn:        call sp_ok
.s2:        call sp_mdraw
            call u_flush
            jp .sl

; ---- the inn (3C/8E8D, rebuilt): the innkeeper's words with the cost (0,0,20,8), the party's
; pictures and HP (0,8,20,6), Yes / No and the Gil (0,14,20,4); Yes: FF3's stay (shop.s shx_istay:
; the gil, HP to max, its event after), Thank you very much... or You don't have enough money.
inn13:      ld a, CODE1
            ld hl, shx_icost
            call far_call
            call u_open
            ld a, 15
            ld [sp_crow], a
            ld a, 70
            ld [sp_cpool], a
            call oam_hide
            call u_cls
            ld bc, $0000
            ld de, $1408
            call u_box
            ld bc, $0008
            ld de, $1406
            call u_box
            ld bc, $000E
            ld de, $1404
            call u_box
            call in_speech
            call in_party
            ld a, 3
            ld [sp_set], a
            xor a
            ld [sp_ch], a
            call sp_cdraw
            call in_gil
            call u_flush
            call u_fadein
            call sp_choose
            jr c, .x
            and a
            jr nz, .x
            ld a, CODE1
            ld hl, shx_istay
            call far_call
            ld a, [u_eres]
            and a
            ld hl, IN_THX
            jr z, .t
            ld a, 7
            ld hl, SP_MSG
.t:         push af
            call sp_str
            call in_clear
            ld bc, $0102
.ln:        push bc
            call u_text
            pop bc
            dec hl
            ld a, [hl+]
            cp 1
            jr nz, .w
            inc c
            jr .ln
.w:         pop af
            and a
            jr nz, .s
            ld a, $A3                       ; (rested: the HP shown full)
            ld [S49], a
            call in_party
            call in_gil
.s:         call u_flush
            call u_hoff
            call sp_poff
.k:         call wait_vbl
            call u_keys
            ld a, [m_new]
            and 3
            jr z, .k
.x:         ld a, $85
            ld [S49], a
            call u_fadeout
            call u_hoff
            call sp_poff
            jp u_close
in_clear:   ld bc, $0101                    ; (the speech's rows; pool 0)
.cl:        push bc
            ld a, U_FILL
            call u_cell
            pop bc
            inc b
            ld a, b
            cp 19
            jr nz, .cl
            ld b, 1
            inc c
            ld a, c
            cp 7
            jr nz, .cl
            xor a
            ld [u_pool], a
            ld a, UP_WHITE
            ld [u_pal], a
            ld a, 1
            ld [m_dirty], a
            ret
in_speech:  call in_clear
            xor a
.l:         ld [sp_n], a
            ld b, a
            ld a, [IN_NK + 1]
            cp b
            jr z, .num
            ld a, [sp_n]
            ld hl, IN_L
            call sp_str
            ld a, [sp_n]
            inc a
            ld c, a
            ld b, 1
            call u_text
            jr .n
.num:       ld a, [sp_n]                    ; the cost's line: before, the number, after
            inc a
            ld c, a
            ld b, 1
            ld hl, IN_PRE
            call u_text
            push bc
            ld a, [sh_val]
            ld e, a
            ld a, [sh_val + 1]
            ld d, a
            ld a, [sh_val + 2]
            ld c, a
            call sp_n24
            pop bc
            call u_text
            ld hl, IN_SUF
            call u_text
.n:         ld a, [sp_n]
            inc a
            ld b, a
            ld a, [IN_NK]
            cp b
            ld a, b
            jr nz, .l
            ret
; the members: picture (cells 1 + 5 m, rows 9-11), HP below (row 12; pool 100 + 12 m)
in_party:   xor a
.m:         ld [u_k], a
            ld b, a
            add a, a
            add a, a
            add a, b
            inc a
            ld [sp_t], a
            add a, a
            add a, a
            add a, a
            ld b, a
            ld c, 9 * 8
            call u_pic
            ld a, [sp_t]
            ld b, a
            ld c, 12
.cl:        push bc
            ld a, U_FILL
            call u_cell
            pop bc
            inc b
            ld a, [sp_t]
            add a, 5
            cp b
            jr nz, .cl
            ld a, [u_k]
            ld b, a
            add a, a
            add a, b
            add a, a
            add a, a
            add a, 100
            ld [u_pool], a
            ld a, [u_k]
            rrca
            rrca
            add a, $0C
            ld l, a
            ld h, high(GS + $100)
            ld a, [hl+]
            ld e, a
            ld a, [hl+]
            ld d, a
            ld a, [hl+]
            ld c, a
            ld b, [hl]
            push bc
            call u_ntoa
            ld de, sp_nb
.c1:        ld a, [hl+]
            ld [de], a
            inc de
            and a
            jr nz, .c1
            dec de
            ld a, $C7
            ld [de], a
            inc de
            pop bc
            push de
            ld d, b
            ld e, c
            call u_ntoa
            pop de
.c2:        ld a, [hl+]
            ld [de], a
            inc de
            and a
            jr nz, .c2
            ld a, [sp_t]
            ld b, a
            ld c, 12
            ld hl, sp_nb
            call u_text
            ld a, [u_k]
            inc a
            cp 4
            jr nz, .m
            ld a, 1
            ld [m_dirty], a
            ret
in_gil:     ld bc, $0C0F                    ; Gil at the right of the choices' row (pool 52-59)
.cl:        push bc
            ld a, U_FILL
            call u_cell
            pop bc
            inc b
            ld a, b
            cp 19
            jr nz, .cl
            ld a, 80
            ld [u_pool], a
            ld a, [GS + $1C]
            ld e, a
            ld a, [GS + $1D]
            ld d, a
            ld a, [GS + $1E]
            ld c, a
            call sp_n24
            ld a, UP_WHITE
            ld [u_pal], a
            ld bc, $130F
            call u_textr
            ld a, UP_LABEL
            ld [u_pal], a
            ld bc, $0C0F
            ld hl, U_GIL
            call u_text
            ld a, UP_WHITE
            ld [u_pal], a
            ld a, 1
            ld [m_dirty], a
            ret

; FF3's message id A (shop.s's sh_msg) -> sp_msg (SP_MSG's order: $26, $27, $28, $29, $2A, $2B, $2C,
; $6C)
sp_msgid:   ld hl, SP_MIDS
            ld c, 0
.f:         cp [hl]
            jr z, .x
            inc hl
            inc c
            ld a, c
            cp 8
            jr nz, .f
            ld c, 2
.x:         ld a, c
            ld [sp_msg], a
            ret
SP_MIDS:    db $26, $27, $28, $29, $2A, $2B, $2C, $6C

sp_ok:      ld a, $85
            ld [S49], a
            ret
sp_mv:      push af
            ld a, $98
            ld [S49], a
            pop af
            ret

; ---- the screen
sp_scr:     call oam_hide
            call u_cls
            ld bc, $0000
            ld de, $1404
            call u_box
            ld bc, $0004
            ld de, $1403
            call u_box
            ld bc, $0007
            ld de, $140B
            call u_box
            call sp_mdraw
            call sp_gil
            ld a, 60                        ; the shop's name (types 7-10)
            ld [u_pool], a
            ld a, UP_LABEL
            ld [u_pal], a
            ld a, [EV_TRIG]
            sub 7
            and 3
            ld hl, SP_TITLE
            call sp_str
            ld bc, $0108
            call u_text
            ld a, UP_WHITE
            ld [u_pal], a
            ld a, 1
            ld [m_dirty], a
            ret
; HL = string A of the table HL (this bank)
sp_str:     add a, a
            ld e, a
            ld d, 0
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ret
; the message sp_msg (two lines; $2B with the value sh_val between its parts)
sp_mdraw:   ld bc, $0101
.cl:        push bc
            ld a, U_FILL
            call u_cell
            pop bc
            inc b
            ld a, b
            cp 19
            jr nz, .cl
            ld b, 1
            inc c
            ld a, c
            cp 3
            jr nz, .cl
            xor a
            ld [u_pool], a
            ld a, UP_WHITE
            ld [u_pal], a
            ld a, [sp_msg]
            cp 5
            jr z, .val
            ld hl, SP_MSG
            call sp_str
            ld bc, $0101
.ln:        push bc
            call u_text
            pop bc
            dec hl
            ld a, [hl+]
            cp 1
            jr nz, .x
            inc c
            jr .ln
.x:         ld a, 1
            ld [m_dirty], a
            ret
.val:       ld bc, $0101                    ; That will come to / n Gil.
            ld hl, SP_V1
            call u_text
            ld a, [sh_val]
            ld e, a
            ld a, [sh_val + 1]
            ld d, a
            ld a, [sh_val + 2]
            ld c, a
            call sp_n24
            ld bc, $0102
            call u_text
            ld hl, SP_V2
            call u_text
            jr .x
; CDE -> HL = its digits (sp_nb)
sp_n24:     ld hl, sp_nb + 7
            ld [hl], 0
.d:         push hl
            ld b, 24
            xor a
.l:         sla e
            rl d
            rl c
            rla
            cp 10
            jr c, .n
            sub 10
            inc e
.n:         dec b
            jr nz, .l
            pop hl
            dec hl
            add a, $80
            ld [hl], a
            ld a, c
            or d
            or e
            jr nz, .d
            ret
; the Gil (row 5, at the right; pool 52-59)
sp_gil:     ld bc, $0C08
.cl:        push bc
            ld a, U_FILL
            call u_cell
            pop bc
            inc b
            ld a, b
            cp 19
            jr nz, .cl
            ld a, 52
            ld [u_pool], a
            ld a, [GS + $1C]
            ld e, a
            ld a, [GS + $1D]
            ld d, a
            ld a, [GS + $1E]
            ld c, a
            call sp_n24
            ld a, UP_WHITE
            ld [u_pal], a
            ld bc, $1308
            call u_textr
            ld a, UP_LABEL
            ld [u_pal], a
            ld bc, $0C08
            ld hl, U_GIL
            call u_text
            ld a, UP_WHITE
            ld [u_pal], a
            ld a, 1
            ld [m_dirty], a
            ret
; the choices of set sp_set (0 Buy / Sell / Exit, 1 1 / 4 / 10, 2 1 / All) on row 5 at cells 3,
; 8, 13 (pool 40-51)
sp_cdraw:   ld a, [sp_crow]
            ld c, a
            ld b, 1
.cl:        push bc
            ld a, U_FILL
            call u_cell
            pop bc
            inc b
            ld a, b
            cp 19
            jr nz, .cl
            ld a, [sp_cpool]
            ld [u_pool], a
            ld a, UP_WHITE
            ld [u_pal], a
            ld a, [sp_set]
            ld hl, SP_SETS
            call sp_str                     ; (count, then the words)
            ld a, [hl+]
            ld [sp_n], a
            ld a, [sp_crow]
            ld c, a
            ld b, 3
.w:         push bc
            call u_text
            pop bc
            ld a, b
            add a, 5
            ld b, a
            ld a, [sp_n]
            dec a
            ld [sp_n], a
            jr nz, .w
            ld a, 1
            ld [m_dirty], a
            ret
; the hand over the choices (left / right; A: carry clear, A = the choice; B: carry)
sp_choose:  ld a, [sp_set]
            ld hl, SP_SETS
            call sp_str
            ld a, [hl]
            ld [sp_n], a
.l:         ld a, [sp_ch]
            ld b, a
            add a, a
            add a, a
            add a, b
            add a, 3
            ld b, a
            ld a, [sp_crow]
            ld c, a
            call u_hand
            call wait_vbl
            call u_keys
            ld a, [m_new]
            bit 1, a
            jr nz, .b
            bit 0, a
            jr nz, .a
            ld b, a
            ld a, [sp_ch]
            bit 5, b
            jr z, .r
            and a
            jr z, .l
            dec a
            jr .s
.r:         bit 4, b
            jr z, .l
            inc a
            ld c, a
            ld a, [sp_n]
            cp c
            jr z, .l
            ld a, c
.s:         ld [sp_ch], a
            call sp_mv
            jr .l
.b:         call sp_ok
            scf
            ret
.a:         call sp_ok
            ld a, [sp_ch]
            and a
            ret
; the parked hand at the choice (OAM 24-27) while the list is chosen from
sp_park:    ld a, [sp_ch]
            ld b, a
            add a, a
            add a, a
            add a, b
            add a, 3
            add a, a
            add a, a
            add a, a
            ld b, a
            ld a, [sp_crow]
            add a, a
            add a, a
            add a, a
            ld c, a
            ld hl, oam_buf + 4 * 24
            jp u_handh
sp_poff:    ld hl, oam_buf + 4 * 24
            ld b, 4
            xor a
.o:         ld [hl+], a
            inc hl
            inc hl
            inc hl
            dec b
            jr nz, .o
            ret

; the list: the goods (sh_mode 0) or the bag from sh_top (1), rows 9-16
sp_list:    xor a
.r:         ld [sh_k], a
            call sp_row
            ld a, [sh_k]
            inc a
            cp 8
            jr nz, .r
            ld a, 1
            ld [m_dirty], a
            ret
sp_row:     ld a, [sh_k]
            add a, SP_ROW
            ld c, a
            ld b, 1
.cl:        push bc
            ld a, U_FILL
            call u_cell
            pop bc
            inc b
            ld a, b
            cp 19
            jr nz, .cl
            ld a, [sh_k]                    ; its tiles: 70 + 14 k
            ld b, a
            add a, a
            add a, a
            add a, a
            sub b
            add a, a
            add a, SP_LP
            ld [u_pool], a
            ld a, UP_WHITE
            ld [u_pal], a
            ld a, [sh_mode]
            and a
            jr nz, .inv
            ld a, [sh_k]
            add a, low(EV_TRIG + 1)
            ld l, a
            ld h, high(EV_TRIG + 1)
            ld a, [hl]
            and a
            ret z
            call u_iname
            ld a, [sh_k]
            add a, SP_ROW
            ld c, a
            ld b, 3
            call u_text
            ld a, [sh_k]                    ; its price (sh_pr + 3 k)
            ld b, a
            add a, a
            add a, b
            add a, low(sh_pr)
            ld l, a
            ld h, high(sh_pr)
            ld a, [hl+]
            ld e, a
            ld a, [hl+]
            ld d, a
            ld c, [hl]
            call sp_n24
            ld a, [sh_k]
            add a, SP_ROW
            ld c, a
            ld b, 19
            jp u_textr
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
            call u_iname
            ld a, [sh_k]
            add a, SP_ROW
            ld c, a
            ld b, 3
            call u_text
            pop hl
            ld a, l
            add a, $20
            ld l, a
            ld e, [hl]
            ld d, 0
            call u_ntoa
            ld a, [sh_k]
            add a, SP_ROW
            ld c, a
            ld b, 19
            jp u_textr

section wram, $DFB0                         ; (WRAM 2: shared with the file screen's bytes)
sp_msg:     ds 1
sp_set:     ds 1
sp_ch:      ds 1
sp_n:       ds 1
sp_nb:      ds 16
sp_crow:    ds 1
sp_t:       ds 1
sp_cpool:   ds 1
