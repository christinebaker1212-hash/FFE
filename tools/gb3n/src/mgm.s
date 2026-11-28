; ---- mgm.s (bank CODE11): the Magic screen (FF3 3C/9761, rebuilt for the owner's polish pass,
; 2026-11-28). Header (0,0,20,5): the member's picture, name, job; FF3's Use / Swap / Item at cell
; 15 (the hand at cells 13-14). Spells (0,5,20,13): three levels a page, a level in 3 rows from rows
; 6 / 10 / 14: "LV1" and MP cur/max at cells 1-4, its 3 slots one a row from cell 7 (the hand at
; cells 5-6); spells that cannot be cast here (not field spells, or not by this job) grey; the
; page at the bottom right. FF3's way: a command first, then a slot (Use, Item) or a member (Swap).
; Use: the target window (as the Item screen's), which stays while MP of the level lasts (FF1).
; The rules are FF3's (magic.s mgx_*); left / right turn the page.
MG_T0      = 40                 ; pool: tiles 0-39 the header, two page buffers of 72 tiles
MG_PT      = 72

; A = member (0-3)
mgm_open:   ld [mgm_m], a
            ld [u_k], a
            xor a
            ld [mgm_quit], a
            ld a, [mgm_m]
            ld [mgm_t], a
            call mgm_load
            call oam_hide
            xor a
            ld [mgm_cmd], a
            ld [mg_slot], a
            ld [mgm_buf], a
.re:        call mgm_scr
            call u_flush
            call u_fadein
.l:         call mgm_chand                  ; the command hand
            call wait_vbl
            call u_keys
            ld a, [m_new]
            bit 1, a
            jr nz, .x
            bit 0, a
            jr nz, .a
            ld hl, mgm_cmd
            bit 6, a
            jr z, .d
            ld a, [hl]
            dec a
            cp $FF
            jr nz, .s
            ld a, 2
            jr .s
.d:         bit 7, a
            jr z, .l
            ld a, [hl]
            inc a
            cp 3
            jr c, .s
            xor a
.s:         ld [hl], a
            ld a, $98
            ld [S49], a
            jr .l
.x:         ld a, $85
            ld [S49], a
            call u_fadeout
            call u_hoff
            jp oam_hide
.a:         ld a, $85
            ld [S49], a
            ld a, [mgm_cmd]
            cp 1
            jr z, .swap
            call mgm_slots                  ; Use / Item: a slot
            ld a, [mgm_quit]                ; (Exit / Warp / Sight: the menu closes)
            and a
            jr z, .l
            call u_fadeout
            call u_hoff
            jp oam_hide
.swap:      call mgm_swap
            jr c, .l
            call u_fadeout
            jr .re

; the spell list's hand: up / down through the 24 slots, left / right a page; A by the command
mgm_slots:
.l:         call mgm_park
            call mgm_shand
            call wait_vbl
            call u_keys
            ld a, [m_new]
            bit 1, a
            jr nz, .b
            bit 0, a
            jr nz, .a
            ld b, a
            ld a, [mg_slot]
            bit 6, b
            jr z, .d
            dec a
            cp $FF
            jr nz, .s
            ld a, 23
            jr .s
.d:         bit 7, b
            jr z, .r
            inc a
            cp 24
            jr c, .s
            xor a
            jr .s
.r:         bit 4, b                        ; right: the next page (the same row of its level)
            jr z, .lf
            add a, 9
            cp 24
            jr c, .s
            sub 27
            jr nc, .s
            add a, 9
            jr .s
.lf:        bit 5, b
            jr z, .l
            sub 9
            jr nc, .s
            add a, 27
            cp 24
            jr c, .s
            sub 9
.s:         ld [mg_slot], a
            ld a, $98
            ld [S49], a
            call mgm_turn                   ; (another page: drawn)
            jr .l
.b:         ld a, $85
            ld [S49], a
            jp mgm_poff
.a:         ld a, [mgm_cmd]
            and a
            jr z, .use
            ld a, CODE1                     ; Item: the spell to the bag
            ld hl, mgx_toitem
            call far_call
            ld a, [u_eres]
            and a
            jr nz, .msg
            ld a, $86
            ld [S49], a
            jr .l
.msg:       push af
            ld a, $85
            ld [S49], a
            pop af
            call mgm_hmsg                   ; (the slot emptied: the page in the other buffer)
            ld a, [mgm_buf]
            xor 1
            ld [mgm_buf], a
            call mgm_draw
            call u_flush
            jr .l
.use:       ld a, CODE1
            ld hl, mgx_check
            call far_call
            ld a, [u_eres]
            and a
            jr z, .cast
            cp 1
            jr z, .err
            call mgm_hmsg                   ; (FF3's message: can't use magic / warp / change size)
            call u_flush
            jp .l
.err:       ld a, $86
            ld [S49], a
            jp .l
.cast:      ld a, $85
            ld [S49], a
            ld a, [mg_kind]
            cp 5
            jp z, mgm_warp
            cp 6
            jp z, mgm_exit
            cp 7
            jp z, mgm_sight
            call mgm_cast
            call u_fadeout
            call mgm_scr
            call u_flush
            call u_fadein
            jr .l

; ---- Exit (3C/98FA): "Warps outside." A: out to the world map (B: the error sound)
mgm_exit:   ld a, [it_prompt]
            call mgm_hshow
            call im_wkey
            bit 1, a
            jr nz, .no
            ld a, $DD                       ; (the warp sound, 3C/958C)
            ld [S49], a
            ld a, CODE1
            ld hl, mgx_mpdec
            call far_call
            ld a, $C1
            ld [mgm_quit], a
            ret
.no:        ld a, $86
            ld [S49], a
            call mgm_hback
            call u_flush
            jp mgm_slots.l
; ---- Warp (3C/9AD0): "Go back how many floors?" 0-45 (up / left one fewer, down / right one more,
; wrapping); A with 1 or more: back that many maps; B: back to the list
mgm_warp:   ld a, [it_prompt]
            call mgm_hshow
            ld a, [u_pool]
            ld [mgm_s], a
            xor a
            ld [mgm_k], a
.d:         call .num
.l:         call wait_vbl
            call u_keys
            ld a, [m_new]
            bit 1, a
            jr nz, .b
            bit 0, a
            jr nz, .a
            ld b, a
            ld a, [mgm_k]
            bit 7, b
            jr nz, .up
            bit 4, b
            jr nz, .up
            bit 6, b
            jr nz, .dn
            bit 5, b
            jr z, .l
.dn:        dec a
            cp $FF
            jr nz, .s
            ld a, 45
            jr .s
.up:        inc a
            cp 46
            jr c, .s
            xor a
.s:         ld [mgm_k], a
            ld a, $98
            ld [S49], a
            jr .d
.a:         ld a, [mgm_k]
            and a
            jr z, .l
            ld [mgm_quit + 1], a
            ld a, $DD
            ld [S49], a
            ld a, CODE1
            ld hl, mgx_mpdec
            call far_call
            ld a, $41
            ld [mgm_quit], a
            ret
.b:         ld a, $85
            ld [S49], a
            call mgm_hback
            call u_flush
            jp mgm_slots.l
.num:       ld a, [mgm_s]                   ; the count at the end of the second line
            ld [u_pool], a
            ld bc, $0F02
.cl:        push bc
            ld a, U_FILL
            call u_cell
            pop bc
            inc b
            ld a, b
            cp 19
            jr nz, .cl
            ld a, [mgm_k]
            ld e, a
            ld d, 0
            call u_ntoa
            ld a, UP_YELLOW
            ld [u_pal], a
            ld bc, $1302
            call u_textr
            ld a, UP_WHITE
            ld [u_pal], a
            ld a, 1
            ld [m_dirty], a
            jp u_flusht
; ---- Sight (3C/9948): on a world map, one MP fewer, the minimap (then the main menu again)
mgm_sight:  ld a, CODE1
            ld hl, mgx_mpdec
            call far_call
            ld a, 2
            ld [mgm_quit], a
            ret

; ---- Use: the target window (the prompt, the party); left / right: all four; the window stays
; while the level's MP lasts
mgm_cast:   call u_fadeout
            call mgm_poff
            call oam_hide
            ld a, [it_prompt]
            call mgm_tscr
            call u_flush
            call u_fadein
            xor a
            ld [mn_mem], a
            ld [mgm_all], a
.l:         call mgm_thand
            call wait_vbl
            call u_keys
            ld a, [m_new]
            bit 1, a
            jr nz, .b
            bit 0, a
            jr nz, .a
            ld b, a
            and $30
            jr z, .ud
            ld a, [mgm_all]                 ; left / right: one / all
            xor 1
            ld [mgm_all], a
            jr .snd
.ud:        ld a, [mgm_all]
            and a
            jr nz, .l
            ld hl, mn_mem
            ld a, [hl]
            bit 6, b
            jr z, .d
            dec a
            and 3
            jr .s
.d:         bit 7, b
            jr z, .l
            inc a
            and 3
.s:         ld [hl], a
.snd:       ld a, $98
            ld [S49], a
            jr .l
.b:         ld a, $85
            ld [S49], a
            jp mgm_hoffs
.a:         ld a, [mn_mem]
            ld b, a
            ld a, [mgm_all]
            and a
            jr z, .one
            ld b, 4
.one:       ld a, b
            ld [mg_tgt], a
            ld a, CODE1
            ld hl, mgx_cast
            call far_call
            ld a, [u_eres]
            and a
            jr z, .done
            ld a, $86                       ; (no effect: FF3 does not cast it)
            ld [S49], a
            jr .l
.done:      ld a, $A3
            ld [S49], a
            xor a                           ; every member's HP again
.hp:        ld [mn_mem + 1], a
            call im_tmem
            ld a, [mn_mem + 1]
            inc a
            cp 4
            jr nz, .hp
            call mgm_tmp                    ; the MP left
            call u_flush
            ld a, CODE1                     ; MP left (and still castable): the window stays
            ld hl, mgx_check
            call far_call
            ld a, [u_eres]
            and a
            jr z, .l
            jp mgm_hoffs

; the target window: the prompt A (two lines), the party (Item screen's rows), the MP left
mgm_tscr:   push af
            call u_cls
            ld bc, $0000
            ld de, $1404
            call u_box
            ld bc, $0004
            ld de, $140E
            call u_box
            pop af
            call im_tprompt
            ld a, 24
            ld [u_pool], a
            xor a
.m:         ld [mn_mem + 1], a
            call im_tmem
            ld a, [mn_mem + 1]
            inc a
            cp 4
            jr nz, .m
            ld a, [mgm_m]                   ; (the caster's picture stays its own)
            ld [u_k], a
mgm_tmp:    ld a, [mg_mp]                   ; "MP n" at the bottom right of the party window
            ld l, a
            ld h, high(GS + $100)
            ld e, [hl]
            ld d, 0
            ld a, 88
            ld [u_pool], a
            ld bc, $0C10
.cl:        push bc
            ld a, U_FILL
            call u_cell
            pop bc
            inc b
            ld a, b
            cp 19
            jr nz, .cl
            call u_ntoa
            ld de, mn_buf
            ld a, $96                       ; "MP " (FF3's letters M, P)
            ld [de], a
            inc de
            ld a, $99
            ld [de], a
            inc de
            ld a, $FF
            ld [de], a
            inc de
.c:         ld a, [hl+]
            ld [de], a
            inc de
            and a
            jr nz, .c
            ld a, UP_LABEL
            ld [u_pal], a
            ld hl, mn_buf
            ld bc, $1310
            call u_textr
            ld a, UP_WHITE
            ld [u_pal], a
            ld a, 1
            ld [m_dirty], a
            ret

; the target hands: the member's, or all four (OAM 36-39, 24-35)
mgm_thand:  ld a, [mgm_all]
            and a
            jr nz, .all
            call mgm_hoffs
            ld a, [mn_mem]
            ld b, a
            add a, a
            add a, b
            add a, 5
            ld c, a
            ld b, 5
            jp u_hand
.all:       ld hl, oam_buf + 4 * 24
            ld a, 1
.h:         push af
            ld b, a
            add a, a
            add a, b
            add a, 5
            add a, a
            add a, a
            add a, a
            ld c, a
            ld b, 5 * 8
            push hl
            call u_handh
            pop hl
            ld de, 16
            add hl, de
            pop af
            inc a
            cp 4
            jr nz, .h
            ld bc, $0505
            jp u_hand
mgm_hoffs:  call u_hoff
mgm_poff:   ld hl, oam_buf + 4 * 24         ; (the parked / extra hands off)
            ld b, 12
            xor a
.o:         ld [hl+], a
            inc hl
            inc hl
            inc hl
            dec b
            jr nz, .o
            ret

; ---- Swap: the party window under "Swap"; A on another living member: their spells traded.
; Carry: nothing done
mgm_swap:   call u_fadeout
            call oam_hide
            ld a, 1
            call mgm_tscr0
            call u_flush
            call u_fadein
            xor a
            ld [mn_mem], a
            ld [mgm_all], a
.l:         call mgm_thand
            call wait_vbl
            call u_keys
            ld a, [m_new]
            bit 1, a
            jr nz, .b
            bit 0, a
            jr nz, .a
            ld b, a
            ld hl, mn_mem
            ld a, [hl]
            bit 6, b
            jr z, .d
            dec a
            and 3
            jr .s
.d:         bit 7, b
            jr z, .l
            inc a
            and 3
.s:         ld [hl], a
            ld a, $98
            ld [S49], a
            jr .l
.b:         ld a, $85
            ld [S49], a
            call u_fadeout
            call u_hoff
            call mgm_scr
            call u_flush
            call u_fadein
            scf
            ret
.a:         ld a, [mn_mem]
            call mgm_swp
            ld a, [u_eres]
            and a
            jr z, .ok
            ld a, $86
            ld [S49], a
            jr .l
.ok:        ld a, $85
            ld [S49], a
            call u_hoff
            and a
            ret
mgm_swp:    ld [mgm_t], a                   ; far_call mgx_swap with A = the member
            ld a, CODE1
            ld hl, mgx_swapt
            jp far_call
; the party window with a title A (1: "Swap") instead of a prompt
mgm_tscr0:  call u_cls
            ld bc, $0000
            ld de, $1404
            call u_box
            ld bc, $0004
            ld de, $140E
            call u_box
            xor a
            ld [u_pool], a
            ld a, UP_WHITE
            ld [u_pal], a
            ld bc, $0101
            ld d, 18
            ld hl, U_SWAP
            call u_textc
            ld a, 24
            ld [u_pool], a
            xor a
.m:         ld [mn_mem + 1], a
            call im_tmem
            ld a, [mn_mem + 1]
            inc a
            cp 4
            jr nz, .m
            ret

; ---- the screen: the header, the page of mg_slot
mgm_scr:    call oam_hide
            call u_cls
            ld bc, $0000
            ld de, $1405
            call u_box
            ld bc, $0005
            ld de, $140D
            call u_box
            call mgm_head
            ld a, $FF
            ld [mgm_pg], a                  ; (the page drawn below)
mgm_turn:   ld a, [mg_slot]                 ; another page than shown: drawn
            call mgm_page
            ld b, a
            ld a, [mgm_pg]
            cp b
            ret z
            ld a, b
            ld [mgm_pg], a
            ld a, [mgm_buf]                 ; (into the other tile buffer)
            xor 1
            ld [mgm_buf], a
            call mgm_draw
            jp u_flush
; A = slot -> A = its page (0-2)
mgm_page:   ld b, 0
.l:         sub 9
            jr c, .d
            inc b
            jr .l
.d:         ld a, b
            ret
mgm_draw:   ld bc, $0106                    ; the list's cells cleared
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
            cp 17
            jr nz, .cl
            ld a, [mgm_buf]                 ; the page's tiles
            and a
            ld a, MG_T0
            jr z, .t
            add a, MG_PT
.t:         ld [u_pool], a
            ld a, [mgm_pg]                  ; levels 3 p .. 3 p + 2
            ld b, a
            add a, a
            add a, b
            ld [mgm_lv], a
            ld a, 6
            ld [mgm_row], a
.lv:        ld a, [mgm_lv]
            cp 8
            jr nc, .pg
            call mgm_level
            ld hl, mgm_lv
            inc [hl]
            ld a, [mgm_row]
            add a, 4
            ld [mgm_row], a
            cp 18
            jr c, .lv
.pg:        ld a, [mgm_pg]                  ; the page: "1/3" at the bottom right
            add a, $81
            ld [mn_buf], a
            ld a, $C7
            ld [mn_buf + 1], a
            ld a, $83
            ld [mn_buf + 2], a
            xor a
            ld [mn_buf + 3], a
            ld a, UP_GREY
            ld [u_pal], a
            ld hl, mn_buf
            ld bc, $1310
            call u_textr
            ld a, 1
            ld [m_dirty], a
            ret
; level mgm_lv at row mgm_row: "LV<n>", MP cur / max below it, the 3 slots
mgm_level:  ld hl, U_LV
            ld de, mn_buf
.c:         ld a, [hl+]
            and a
            jr z, .n
            ld [de], a
            inc de
            jr .c
.n:         ld a, [mgm_lv]
            add a, $81
            ld [de], a
            inc de
            xor a
            ld [de], a
            ld a, UP_LABEL
            ld [u_pal], a
            ld a, [mgm_row]
            ld c, a
            ld b, 1
            ld hl, mn_buf
            call u_text
            ld a, [mgm_lv]                  ; MP: $6130 + 2 level (+ the caster)
            add a, a
            ld e, a
            ld a, [mg_caster]
            add a, $30
            add a, e
            ld l, a
            ld h, high(GS + $100)
            ld a, [hl+]
            ld e, a
            ld a, [hl]
            push af
            ld d, 0
            call u_ntoa
            ld de, mn_buf
.c1:        ld a, [hl+]
            ld [de], a
            inc de
            and a
            jr nz, .c1
            dec de
            ld a, $C7
            ld [de], a
            inc de
            pop af
            push de
            ld e, a
            ld d, 0
            call u_ntoa
            pop de
.c2:        ld a, [hl+]
            ld [de], a
            inc de
            and a
            jr nz, .c2
            ld a, UP_WHITE
            ld [u_pal], a
            ld a, [mgm_row]
            inc a
            ld c, a
            ld b, 1
            ld hl, mn_buf
            call u_text
            xor a                           ; the slots
            ld [mgm_k], a
.s:         ld a, [mgm_lv]
            ld b, a
            add a, a
            add a, b
            ld b, a
            ld a, [mgm_k]
            add a, b
            add a, low(SPL)
            ld l, a
            ld h, high(SPL)
            ld a, [hl]
            and a
            jr z, .ns
            ld [mgm_s], a                   ; (grey: not castable here)
            call mgm_ok
            ld a, [mgm_s]
            call u_iname
            ld a, [u_eres]
            and a
            ld a, UP_WHITE
            jr z, .w
            ld a, UP_GREY
.w:         ld [u_pal], a
            ld a, [mgm_row]
            ld b, a
            ld a, [mgm_k]
            add a, b
            ld c, a
            ld b, 7
            call u_text
.ns:        ld hl, mgm_k
            inc [hl]
            ld a, [hl]
            cp 3
            jr nz, .s
            ret
mgm_ok:     ld [mgm_t], a                   ; far_call mgx_ok, A = the spell
            ld a, CODE1
            ld hl, mgx_okt
            jp far_call
mgm_load:   ld a, CODE1                     ; far_call mgx_load, A = mgm_t
            ld hl, mgx_loadt
            jp far_call

; the header: picture, name, job; Use / Swap / Item (pool tiles 0-39)
mgm_head:   xor a
            ld [u_pool], a
            ld a, [mgm_m]
            ld [u_k], a
            ld bc, $1008
            call u_pic
            ld a, [mgm_m]
            rrca
            rrca
            ld [mn_t], a
            add a, 6
            ld l, a
            ld h, high(GS + $100)
            ld de, mn_buf
            ld b, 6
.n:         ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .n
            xor a
            ld [de], a
            ld a, UP_WHITE
            ld [u_pal], a
            ld bc, $0401
            ld hl, mn_buf
            call u_text
            ld a, [mn_t]
            ld l, a
            ld h, high(GS + $100)
            ld a, [hl]
            and $3F
            add a, a
            ld e, a
            ld d, 0
            ld hl, U_JOBN
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld bc, $0403
            call u_text
            ld bc, $0F01
            ld hl, U_USE
            call u_text
            ld bc, $0F02
            ld hl, U_SWAP
            call u_text
            ld bc, $0F03
            ld hl, U_MITEM
            call u_text
            ld a, MG_T0
            ld [u_pool], a
            ret
; a message A (FF3's t8200) in the header, a key, the header back
mgm_hmsg:   call mgm_hshow
            call im_wkey
            ld a, $85
            ld [S49], a
            jp mgm_hback
; the message A in the header (its tiles in the page buffer not shown), the picture and hands off
mgm_hshow:  push af
            call mgm_poff
            call u_hoff
            ld a, [mgm_m]                   ; (the picture off)
            ld b, a
            add a, a
            add a, b
            add a, a
            add a, a
            add a, a
            ld l, a
            ld h, high(oam_buf)
            ld b, 6
            xor a
.o:         ld [hl+], a
            inc hl
            inc hl
            inc hl
            dec b
            jr nz, .o
            call mgm_hclr
            ld a, [mgm_buf]
            and a
            ld a, MG_T0 + MG_PT
            jr z, .t
            ld a, MG_T0
.t:         ld [u_pool], a
            pop af
            call im_tpromptp
            jp u_flush
; the header's cells cleared (rows 1-3)
mgm_hclr:   ld bc, $0101
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
            cp 4
            jr nz, .cl
            ret
; the header back: blank for a frame (the message's tiles are reused), then drawn (no flush)
mgm_hback:  call mgm_hclr
            ld a, 1
            ld [m_dirty], a
            call wait_vbl
            call wait_vbl
            jp mgm_head

; the command hand (row 1 + command, cell 15)
mgm_chand:  ld a, [mgm_cmd]
            inc a
            ld c, a
            ld b, 15
            jp u_hand
; the parked command hand (OAM 24-27) while a slot is chosen
mgm_park:   ld a, [mgm_cmd]
            inc a
            add a, a
            add a, a
            add a, a
            ld c, a
            ld b, 15 * 8
            ld hl, oam_buf + 4 * 24
            jp u_handh
; the slot hand: row 6 + 4 (level - 3 page) + n, cell 7
mgm_shand:  ld a, [mg_slot]
            ld b, 0
.r:         sub 3
            jr c, .rd
            inc b
            jr .r
.rd:        add a, 3
            ld c, a                         ; n
            ld a, [mgm_pg]
            ld d, a
            add a, a
            add a, d
            ld d, a
            ld a, b
            sub d
            add a, a
            add a, a
            add a, c
            add a, 6
            ld c, a
            ld b, 7
            jp u_hand

section wram, $C69E                         ; (free: after the old menu's)
mgm_quit:   ds 2                            ; 0, or $C1 Exit / $41 Warp (+1: maps back) / 2 Sight
section wram, $C6DC
mgm_m:      ds 1
mgm_cmd:    ds 1
mgm_pg:     ds 1
mgm_buf:    ds 1
section wram, $C6C9                         ; (after item.s's)
mgm_t:      ds 1
mgm_lv:     ds 1
mgm_row:    ds 1
mgm_k:      ds 1
mgm_all:    ds 1
mgm_s:      ds 1
