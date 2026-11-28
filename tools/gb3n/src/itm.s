; ---- itm.s (bank CODE11): the Item screen (FF3 3C/9EC2 list, 3C/9FA5 swap, 3D/A033 use; rebuilt
; for the owner's polish pass, 2026-11-28). The title (0,0,20,4): "Item", or the prompt / message
; (two lines). The bag (0,4,20,14): 12 rows (icon, name, count), the hand at cells 1-2. FF3's way:
; A marks an item (yellow), A again on it uses it, A on another swaps the two; B unmarks, else
; back. Using: the party (4 rows: picture, name, HP) under the prompt; the target window stays
; while the item lasts (FF1). Spells: taught (FF3: "Who will hold this magic?").
IM_ROWS    = 12
IM_RT      = 12                 ; pool tiles a row
IM_T0      = 24                 ; (pool tiles 0-23: the title / a message, two lines)

itm_open:   call oam_hide
            xor a
            ld [it_cur], a
            ld [it_top], a
            ld a, $FF
            ld [it_mark], a
.re:        call im_scr
            call u_flush
            call u_fadein
.l:         ld a, [it_cur]                  ; the hand (rows 5..)
            ld b, a
            ld a, [it_top]
            ld c, a
            ld a, b
            sub c
            add a, 5
            ld c, a
            ld b, 3
            call u_hand
            call wait_vbl
            call u_keys
            ld a, [m_new]
            bit 1, a
            jr nz, .b
            bit 0, a
            jr nz, .a
            ld hl, it_cur
            bit 6, a
            jr z, .d
            ld a, [hl]
            and a
            jr z, .l
            dec [hl]
            ld a, $98
            ld [S49], a
            ld a, [it_top]
            cp [hl]
            jr c, .l
            jr z, .l
            dec a
            ld [it_top], a
            jr .scr
.d:         bit 7, a
            jr z, .l
            ld a, [hl]
            cp 31
            jr z, .l
            inc [hl]
            ld a, $98
            ld [S49], a
            ld a, [it_top]
            add a, IM_ROWS - 1
            cp [hl]
            jr nc, .l
            ld a, [it_top]
            inc a
            ld [it_top], a
.scr:       call im_rows
            call u_flush
            jr .l
.b:         ld a, [it_mark]                 ; B: unmark, else back
            cp $FF
            jr z, .x
            ld a, $FF
            ld [it_mark], a
            ld a, $85
            ld [S49], a
            call im_rows
            call u_flush
            jr .l
.x:         ld a, $85
            ld [S49], a
            jp u_fadeout
.a:         ld a, $85
            ld [S49], a
            ld a, [it_mark]
            cp $FF
            jr nz, .two
            ld a, [it_cur]                  ; first A: mark
            ld [it_mark], a
            call im_rows
            call u_flush
            jp .l
.two:       ld b, a                         ; A again: on the marked one: use; else swap
            ld a, [it_cur]
            cp b
            jr z, .use
            ld e, a                         ; swap slots B and E (ids $60C0, counts $60E0)
            ld c, b
            ld b, 0
            ld d, 0
            ld hl, GS + $C0
            add hl, bc
            push hl
            ld hl, GS + $C0
            add hl, de
            pop de                          ; DE -> B's id, HL -> E's id
            call .sw
            ld a, e
            add a, $20
            ld e, a
            ld a, l
            add a, $20
            ld l, a
            call .sw
            ld a, $FF
            ld [it_mark], a
            call im_rows
            call u_flush
            jp .l
.sw:        ld a, [de]
            ld b, [hl]
            ld [hl], a
            ld a, b
            ld [de], a
            ret
.use:       ld a, $FF
            ld [it_mark], a
            call im_tuse
            call u_fadeout
            jp .re

; the screen: the title, the bag's rows
im_scr:     call oam_hide
            call u_cls
            ld bc, $0000
            ld de, $1404
            call u_box
            ld bc, $0004
            ld de, $140E
            call u_box
            call im_title
im_rows:    xor a
.r:         ld [im_k], a
            call im_row
            ld a, [im_k]
            inc a
            cp IM_ROWS
            jr nz, .r
            ld a, 1
            ld [m_dirty], a
            ret
; the title: "Item" centred (pool tiles 0-3)
im_title:   xor a
            ld [u_pool], a
            ld a, UP_WHITE
            ld [u_pal], a
            ld bc, $0101
            ld d, 18
            ld hl, U_ITEMW
            call u_textc
            ld a, IM_T0
            ld [u_pool], a
            ret
; row im_k (bag slot it_top + im_k): its cells cleared, then icon + name, the count (pool tiles
; IM_T0 + 12 k ..)
im_row:     ld a, [im_k]
            add a, 5
            ld c, a
            ld b, 3
.cl:        push bc
            ld a, U_FILL
            call u_cell
            pop bc
            inc b
            ld a, b
            cp 19
            jr nz, .cl
            ld a, [im_k]                    ; the row's tiles
            ld b, a
            add a, a
            add a, b
            add a, a
            add a, a                        ; 12 k
            add a, IM_T0
            ld [u_pool], a
            ld a, [it_top]
            ld b, a
            ld a, [im_k]
            add a, b
            ld [im_s], a
            add a, low(GS + $C0)
            ld l, a
            ld h, high(GS + $C0)
            ld a, [hl]
            and a
            ret z
            push hl
            call u_iname
            ld a, UP_WHITE                  ; (the marked one yellow)
            ld [u_pal], a
            ld a, [it_mark]
            ld b, a
            ld a, [im_s]
            cp b
            jr nz, .c
            ld a, UP_YELLOW
            ld [u_pal], a
.c:         ld a, [im_k]
            add a, 5
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
            ld a, [im_k]
            add a, 5
            ld c, a
            ld b, 19
            jp u_textr

; ---- using item it_cur: the target window (the party), FF3's effect each A while it lasts
im_tuse:    ld a, [it_cur]
            add a, low(GS + $C0)
            ld l, a
            ld h, high(GS + $C0)
            ld a, [hl]
            and a
            ret z
            ld [it_id], a
            cp $C8                          ; a spell: taught
            jr nc, .ok
            cp $A6                          ; (FF3 3D/A04B: $A6-$AF usable; Midgard Bread and
            jr c, .no                       ;   the Otter's Head later)
            cp $B0
            jr c, .ok
.no:        ld a, $86
            ld [S49], a
            ld a, $5A                       ; "It can't be used."
            jp im_msg
.ok:        call u_fadeout
            call im_tscr
            call u_flush
            call u_fadein
            xor a
            ld [mn_mem], a
.l:         ld a, [mn_mem]                  ; the hand at the member's name (rows 5 + 3 m)
            ld b, a
            add a, a
            add a, b
            add a, 5
            ld c, a
            ld b, 5
            call u_hand
            call wait_vbl
            call u_keys
            ld a, [m_new]
            bit 1, a
            jr nz, .b
            bit 0, a
            jr nz, .a
            ld hl, mn_mem
            bit 6, a
            jr z, .d
            ld a, [hl]
            dec a
            and 3
            jr .s
.d:         bit 7, a
            jr z, .l
            ld a, [hl]
            inc a
            and 3
.s:         ld [hl], a
            ld a, $98
            ld [S49], a
            jr .l
.b:         ld a, $85
            ld [S49], a
            ret
.a:         ld a, [mn_mem]
            ld [m_i], a
            ld a, [it_id]
            cp $C8
            jr nc, .sp
            ld a, CODE1
            ld hl, itx_use
            call far_call
            ld a, [u_eres]
            and a
            jr z, .used
            ld a, $86                       ; (no effect: FF3 does not use it)
            ld [S49], a
            jr .l
.used:      ld a, $A3
            ld [S49], a
            ld a, [mn_mem]
            ld [mn_mem + 1], a
            call im_tmem                    ; the member's HP again
            call u_flush
            ld a, [it_cur]                  ; more left: the window stays
            add a, low(GS + $E0)
            ld l, a
            ld h, high(GS + $E0)
            ld a, [hl]
            and a
            jr nz, .l
            ret
.sp:        ld a, CODE1                     ; a spell: learned (or why not)
            ld hl, itx_teach
            call far_call
            ld a, [u_eres]
            and a
            jr z, .lrn
            push af
            ld a, $86
            ld [S49], a
            pop af
            call im_tmsg
            jr .l
.lrn:       ld a, $A3
            ld [S49], a
            ret
; the target window: the prompt (FF3's $5B + id - $A6; spells $73), the party
im_tscr:    call u_cls
            ld bc, $0000
            ld de, $1404
            call u_box
            ld bc, $0004
            ld de, $140E
            call u_box
            ld a, [it_id]
            cp $C8
            ld a, $73
            jr nc, .p
            ld a, [it_id]
            sub $A6
            add a, $5B
.p:         call im_tprompt
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
; the prompt / a message A ($5A-$75) in the title window, two lines (pool tiles 0-7)
im_tprompt: push af
            ld bc, $0101                    ; (the rows cleared)
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
            pop af
im_tpromptp: push af                        ; (the pool as it is)
            ld a, UP_WHITE
            ld [u_pal], a
            pop af
            sub $5A
            ld hl, U_MSG
            call u_fstr
im_tstr:    ld bc, $0101                    ; (HL = a string: lines split by {01}, from row 1)
.l:         push bc
            call u_text
            pop bc
            dec hl
            ld a, [hl+]
            cp 1
            ret nz
            inc c
            jr .l
; a message on the target screen, then the prompt back
im_tmsg:    call im_tprompt
            ld a, 1
            ld [m_dirty], a
            call u_flusht
            call im_wkey
            ld a, [it_id]
            cp $C8
            ld a, $73
            jr nc, .p
            ld a, [it_id]
            sub $A6
            add a, $5B
.p:         call im_tprompt
            ld a, 1
            ld [m_dirty], a
            jp u_flusht
; a message on the list's title, a key, the title back
im_msg:     call im_tprompt
            ld a, 1
            ld [m_dirty], a
            call u_flusht
            call im_wkey
            ld bc, $0101
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
            ld a, [u_pool]
            push af
            call im_title
            pop af
            ld [u_pool], a
            ld a, 1
            ld [m_dirty], a
            jp u_flusht
im_wkey:    call wait_vbl
            call u_keys
            ld a, [m_new]
            and 3
            jr z, im_wkey
            ret
; member mn_mem + 1's row on the target window (rows 5 + 3 m): picture, name, HP cur / max (pool
; tiles 8 + 16 m ..)
im_tmem:    ld a, [mn_mem + 1]
            ld [u_k], a
            ld b, a
            add a, a
            add a, b
            add a, 5
            ld [im_k], a
            add a, a
            add a, a
            add a, a
            ld c, a
            ld b, 8
            call u_pic
            ld a, [u_k]                     ; its tiles: 24 + 16 m
            swap a
            add a, 24
            ld [u_pool], a
            ld a, [im_k]                    ; (its cells cleared)
            ld c, a
            ld b, 5
.cl:        push bc
            ld a, U_FILL
            call u_cell
            pop bc
            inc b
            ld a, b
            cp 19
            jr nz, .cl
            ld a, [u_k]
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
            ld a, [im_k]
            ld c, a
            ld b, 5
            ld hl, mn_buf
            call u_text
            ld a, [mn_t]                    ; HP cur / max
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
            ld a, [im_k]
            ld c, a
            ld b, 19
            ld hl, mn_buf
            call u_textr
            ld a, 1
            ld [m_dirty], a
            ret

section wram, $CEFE                         ; (after mm.s's)
im_k:       ds 1
im_s:       ds 1
