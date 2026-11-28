; ---- eqm.s (bank CODE11): the Equip screen (FF3 3C/9BB5, rebuilt; owner 2026-11-28: the small font,
; only what the job can wear in the lists, Optimize above Remove Equipment). Header (0,0,20,5): the
; picture, name, job; Attack and Defense, with the item under the hand's values beside them (green
; better, red worse). Slots (0,5,20,13): Right Hand .. Arms (label, item), Optimize, Remove
; Equipment. A on a slot: its list (only the items the job can wear; Remove first when it holds
; one); the rules (the other hand's weapon, arrows up to 20) are FF3's (equip.s eqx_*).
EQ_NROW    = 7                  ; 5 slots, Optimize, Remove Equipment
eq_buf     = mn_buf

; A = member (0-3)
eqm_open:   ld [m_i], a
            ld [u_k], a                     ; (u_pic's member)
            call oam_hide                   ; (the main menu's pictures)
            xor a
            ld [eq_row], a
.re:        call eq_vals
            call eq_draw
            call u_flush
            call u_fadein
.l:         call eq_rowhand
            call wait_vbl
            call u_keys
            ld a, [m_new]
            bit 1, a
            jr nz, .x
            bit 0, a
            jr nz, .a
            ld hl, eq_row
            bit 6, a
            jr z, .d
            ld a, [hl]
            dec a
            cp $FF
            jr nz, .s
            ld a, EQ_NROW - 1
            jr .s
.d:         bit 7, a
            jr z, .l
            ld a, [hl]
            inc a
            cp EQ_NROW
            jr c, .s
            xor a
.s:         ld [hl], a
            ld a, $98
            ld [S49], a
            jr .l
.x:         ld a, $85
            ld [S49], a
            call u_fadeout
            jp oam_hide
.a:         ld a, $85
            ld [S49], a
            ld a, [eq_row]
            cp 5
            jr z, .opt
            cp 6
            jr z, .rem
            ld [e_row], a                   ; a slot: its list
            call eq_list
            jr .re1
.opt:       ld a, CODE1
            ld hl, eqx_opt
            call far_call
            jr .re1
.rem:       ld b, 5                         ; every slot to the bag (3C/9DA2)
.rl:        push bc
            ld a, b
            dec a
            ld [e_row], a
            ld a, CODE1
            ld hl, eqx_take
            call far_call
            pop bc
            dec b
            jr nz, .rl
.re1:       call u_fadeout
            jp .re

; the hand at row eq_row (rows 6-10 the slots, 12 Optimize, 13 Remove Equipment)
eq_rowhand: ld a, [eq_row]
            add a, 6
            cp 11
            jr c, .r
            inc a
.r:         ld c, a
            ld b, 3
            jp u_hand

; Attack / Defense now -> u_eatk / u_edef (and the preview the same)
eq_vals:    ld a, CODE1
            ld hl, eqx_vals
            call far_call
            ld hl, u_eatk
            ld de, u_patk
            ld bc, 4
            jp memcpy

eq_draw:    call u_cls
            ld bc, $0000
            ld de, $1405
            call u_box
            ld bc, $0005
            ld de, $140D
            call u_box
            call eq_head
            ld a, UP_LABEL                  ; the slots
            ld [u_pal], a
            xor a
            ld [eq_t], a
.s:         ld a, [eq_t]
            add a, 6
            ld c, a
            ld b, 3
            ld a, [eq_t]
            add a, a
            ld e, a
            ld d, 0
            ld hl, U_SLOTN
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld a, UP_LABEL
            ld [u_pal], a
            call u_text
            ld a, [eq_t]                    ; the item there
            call eq_slotitem
            and a
            jr z, .n
            push hl
            call u_iname
            ld a, UP_WHITE
            ld [u_pal], a
            ld a, [eq_t]
            add a, 6
            ld c, a
            ld b, 9
            call u_text
            pop hl
            ld a, [eq_t]                    ; (the hands: their count, for arrows)
            cp 2
            jr nc, .n
            inc l
            ld a, [hl]
            cp 2
            jr c, .n
            ld e, a
            ld d, 0
            call u_ntoa
            ld a, [eq_t]
            add a, 6
            ld c, a
            ld b, 19
            call u_textr
.n:         ld hl, eq_t
            inc [hl]
            ld a, [hl]
            cp 5
            jr nz, .s
            ld a, UP_WHITE
            ld [u_pal], a
            ld bc, $030C
            ld hl, U_OPT
            call u_text
            ld bc, $030D
            ld hl, U_REM
            call u_text
            jp eq_values

; row A's item -> A (and HL = its slot byte)
eq_slotitem: push bc
            ld c, a
            ld b, 0
            ld hl, EQM_SLOT
            add hl, bc
            ld a, [m_i]
            rrca
            rrca
            add a, [hl]
            ld l, a
            ld h, high(GS + $200)
            ld a, [hl]
            pop bc
            ret
EQM_SLOT:   db 3, 5, 0, 1, 2                ; (rows -> $6200 slots: equip.s EQ_SLOT)

; the header: picture, name, job; the labels (the values last: eq_values)
eq_head:    ld bc, $1008                    ; the picture at (16, 8)
            call u_pic
            ld a, [m_i]
            rrca
            rrca
            add a, 6
            ld l, a
            ld h, high(GS + $100)
            ld de, eq_buf
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
            ld hl, eq_buf
            call u_text
            ld a, [m_i]
            rrca
            rrca
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
            ld bc, $0403                    ; (the job on row 3: clear of the values)
            call u_text
            ld a, UP_LABEL
            ld [u_pal], a
            ld bc, $0A01
            ld hl, U_ATK
            call u_text
            ld bc, $0A02
            ld hl, U_DEF
            jp u_text

; the values (drawn last: a preview draws them again from eq_vp): Attack, Defense now, then the
; preview's when it differs
eq_values:  ld a, [u_pool]
            ld [eq_vp], a
            ld hl, u_eatk
            ld de, u_patk
            ld c, 1
            call .one
            ld hl, u_edef
            ld de, u_pdef
            ld c, 2
.one:       push de
            push bc
            ld a, [hl+]
            ld e, a
            ld d, [hl]
            push de
            call u_ntoa
            ld a, UP_WHITE
            ld [u_pal], a
            pop de
            pop bc
            push bc
            push de
            ld b, 16
            call u_textr
            pop de                          ; DE = now
            pop bc
            pop hl                          ; HL -> the preview
            ld a, [hl+]
            ld h, [hl]
            ld l, a                         ; HL = preview
            ld a, l
            cp e
            jr nz, .df
            ld a, h
            cp d
            jr nz, .df
            ld b, 19                        ; (the same: blank cells, so a change can draw there)
            ld hl, eq_blank
            jp u_textr
.df:        ld a, UP_GREEN
            push hl
            ld a, l                         ; preview < now: red
            sub e
            ld a, h
            sbc d
            ld a, UP_GREEN
            jr nc, .g
            ld a, UP_RED
.g:         ld [u_pal], a
            pop de
            push bc
            call u_ntoa
            ld de, eq_buf                   ; ">" and the number
            ld a, [U_ARROW]
            ld [de], a
            inc de
.cp:        ld a, [hl+]
            ld [de], a
            inc de
            and a
            jr nz, .cp
            pop bc
            ld b, 19
            ld hl, eq_buf
            jp u_textr
eq_blank:   db $FF, $FF, $FF, $FF, $FF, $FF, $FF, 0

; the values again for a preview (the cells kept, their tiles drawn anew)
eq_preview: ld a, [eq_vp]
            ld [u_pool], a
            ld bc, $0E01                    ; (the value cells cleared: columns 14-18, rows 1-2)
.cl:        push bc
            ld a, U_FILL
            call u_cell
            pop bc
            inc b
            ld a, b
            cp 19
            jr nz, .cl
            ld b, 14
            inc c
            ld a, c
            cp 3
            jr nz, .cl
            call eq_values
            jp u_flush

; ---- a slot's list (row e_row): Remove first when it holds an item, then the bag's items the job
; can wear; the header previews the one under the hand
eq_list:    ld a, CODE1
            ld hl, eqx_list
            call far_call
            ld a, [e_row]
            call eq_slotitem
            ld [eq_has], a
            xor a
            ld [eq_sel], a
            ld [eq_top], a
            call u_fadeout
.re:        call eq_ldraw
            call u_flush
            call u_fadein
.l:         ld a, [eq_sel]                  ; the hand (rows 7-16)
            ld b, a
            ld a, [eq_top]
            ld c, a
            ld a, b
            sub c
            add a, 7
            ld c, a
            ld b, 3
            call u_hand
            call eq_prev
            call wait_vbl
            call u_keys
            ld a, [m_new]
            bit 1, a
            jr nz, .b
            bit 0, a
            jr nz, .a
            ld hl, eq_sel
            bit 6, a
            jr z, .d
            ld a, [hl]
            and a
            jr z, .l
            dec [hl]
            ld a, $98
            ld [S49], a
            ld a, [eq_top]
            cp [hl]
            jr c, .l
            jr z, .l
            dec a
            ld [eq_top], a
            jr .sc
.d:         bit 7, a
            jr z, .l
            ld a, [hl]
            inc a
            ld b, a
            call eq_lcount
            cp b
            jr z, .l
            ld [hl], b
            ld a, $98
            ld [S49], a
            ld a, [eq_top]
            add a, 9
            cp b
            jr nc, .l
            ld a, [eq_top]
            inc a
            ld [eq_top], a
.sc:        call eq_lrows                   ; (a scroll: the rows drawn again)
            call u_flush
            jr .l
.b:         ld a, $85
            ld [S49], a
            ret
.a:         call eq_lentry                  ; A = the bag index, $FE Remove, $FF none
            cp $FF
            jr z, .l
            cp $FE
            jr z, .rm
            ld [e_inv], a
            ld a, CODE1
            ld hl, eqx_put
            call far_call
            ld a, [u_eres]
            and a
            jr z, .ok
            ld a, $86                       ; (not with the other hand's weapon / bag full)
            ld [S49], a
            jr .l
.rm:        ld a, CODE1
            ld hl, eqx_take
            call far_call
.ok:        ld a, $85
            ld [S49], a
            ret
; entries: (Remove) + e_cnt
eq_lcount:  ld a, [eq_has]
            and a
            ld a, [e_cnt]
            ret z
            inc a
            ret
; the entry eq_sel -> A = bag index / $FE Remove
eq_lentry:  ld a, [eq_sel]
eq_lent:    ld c, a
            ld a, [eq_has]
            and a
            jr z, .i
            ld a, c
            and a
            ld a, $FE
            ret z
            dec c
.i:         ld a, c
            ld hl, e_cnt
            cp [hl]
            ld a, $FF
            ret nc
            ld b, 0
            ld hl, e_ids
            add hl, bc
            ld a, [hl]
            ret
; the preview of the entry under the hand (Remove: none) when it changed
eq_prev:    call eq_lentry
            cp $FF
            ret z
            cp $FE
            jr z, .z
            add a, low(GS + $C0)
            ld l, a
            ld h, high(GS + $C0)
            ld a, [hl]
            jr .p
.z:         xor a
.p:         ld hl, eq_pid
            cp [hl]
            ret z
            ld [hl], a
            ld [e_item], a
            ld a, CODE1
            ld hl, eqx_prev
            call far_call
            jp eq_preview

eq_ldraw:   call u_cls
            ld bc, $0000
            ld de, $1405
            call u_box
            ld bc, $0005
            ld de, $140D
            call u_box
            call eq_head
            ld a, UP_LABEL                  ; the slot's name
            ld [u_pal], a
            ld a, [e_row]
            add a, a
            ld e, a
            ld d, 0
            ld hl, U_SLOTN
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld bc, $0306
            call u_text
            ld a, [u_pool]
            ld [eq_lp], a
eq_lrows:   ld a, [eq_lp]                   ; (rows drawn again from eq_lp; the values after them
            ld [u_pool], a                  ;   are drawn again by the next preview)
            ld a, $FF
            ld [eq_pid], a
            ld bc, $0107                    ; the rows cleared (fill cells)
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
            xor a
            ld [eq_t], a
.r:         ld a, [eq_top]
            ld b, a
            ld a, [eq_t]
            add a, b
            call eq_lent
            cp $FF
            jr z, .x
            ld b, a
            ld a, [eq_t]
            add a, 7
            ld c, a
            ld a, b
            cp $FE
            jr nz, .it
            ld a, UP_WHITE
            ld [u_pal], a
            ld b, 3
            ld hl, U_REMOVE
            call u_text
            jr .nx
.it:        push bc                         ; an item: name, count
            ld a, b
            add a, low(GS + $C0)
            ld l, a
            ld h, high(GS + $C0)
            ld a, [hl]
            push hl
            call u_iname
            ld a, UP_WHITE
            ld [u_pal], a
            pop de
            pop bc
            push de
            push bc
            ld b, 3
            call u_text
            pop bc
            pop hl
            ld a, l
            add a, $20
            ld l, a
            ld e, [hl]
            ld d, 0
            push bc
            call u_ntoa
            pop bc
            ld b, 19
            call u_textr
.nx:        ld hl, eq_t
            inc [hl]
            ld a, [hl]
            cp 10
            jr nz, .r
.x:         call eq_values                  ; (the values last: the previews draw them again)
            ld a, 1
            ld [m_dirty], a
            ret

section wram, $C6F8                         ; (after selmenu's options)
eq_row:     ds 1
eq_t:       ds 1
eq_vp:      ds 1
eq_lp:      ds 1
eq_has:     ds 1
eq_sel:     ds 1
eq_top:     ds 1
eq_pid:     ds 1
