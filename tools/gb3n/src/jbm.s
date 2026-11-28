; ---- jbm.s (bank CODE11): the Job screen (FF3 3C/962F, rebuilt for the owner's polish pass,
; 2026-11-28). Header (0,0,20,5): the member's picture in the job under the hand (FF1's job
; picker: the picture changes with the hand), name, Capacity; the job under the hand. The jobs
; (0,5,20,13): "LV" and "Cost" over their columns, then the open jobs ten a row-page (scrolling):
; name (the current one yellow, one costing more than the Capacity grey), its job level, its cost.
; A: FF3's checks and "Change jobs? A..Yes B..No" (3D/AE23; job.s jbx_*), the change, back to the
; main menu. B: back.
JB_ROWS    = 10
JB_P0      = 42                 ; pool: 0-29 the header, 30-37 the job under the hand, 38-41 the
JB_PR      = 11                 ;   labels, 42 + 11 k the list's row k

; A = member (0-3)
jbm_open:   ld [jbm_m], a
            ld [mgm_t], a
            ld a, CODE1
            ld hl, jbx_initt
            call far_call
            call oam_hide
            ld a, [jb_cur]                  ; (the hand on the current job, the list round it)
            ld [jbm_cj], a
            call jbm_topfix
.re:        call jbm_scr
            call u_flush
            call u_fadein
.l:         call jbm_hand
            call wait_vbl
            call u_keys
            ld a, [m_new]
            bit 1, a
            jp nz, .x
            bit 0, a
            jr nz, .a
            ld b, a
            ld a, [jb_cur]
            bit 6, b
            jr z, .d
            and a
            jr z, .l
            dec a
            jr .s
.d:         bit 7, b
            jr z, .l
            inc a
            ld c, a
            ld a, [jb_n]
            cp c
            jr z, .l
            ld a, c
.s:         ld [jb_cur], a
            ld a, $98
            ld [S49], a
            ld a, [jbm_top]
            push af
            call jbm_topfix
            pop af
            ld b, a
            ld a, [jbm_top]
            cp b
            call nz, jbm_rows               ; (scrolled: the rows again)
            call jbm_hov                    ; the header's picture and job
            call u_flush
            jr .l
.a:         ld a, CODE1
            ld hl, jbx_try
            call far_call
            ld a, [u_eres]
            and a
            jr z, .ask
            cp 1
            jr nz, .m
            ld a, $86                       ; (the current job)
            ld [S49], a
            jr .l
.m:         push af
            ld a, $86
            ld [S49], a
            pop af
            call jbm_msg
            jp .l
.ask:       ld a, $85
            ld [S49], a
            ld a, $70                       ; "Change jobs? A..Yes B..No"
            call jbm_show
            call im_wkey
            bit 1, a
            jr nz, .no
            ld a, CODE1
            ld hl, jbx_do
            call far_call
            ld a, [u_eres]
            and a
            jr nz, .full
            ld a, $A3
            ld [S49], a
            call u_fadeout
            call u_hoff
            jp oam_hide
.full:      push af
            ld a, $86
            ld [S49], a
            pop af
            call jbm_show
            call im_wkey
.no:        ld a, $85
            ld [S49], a
            call jbm_hback
            jp .l
.x:         ld a, $85
            ld [S49], a
            ld a, [jbm_cj]                  ; (the picture as it is: the current job)
            ld [jb_cur], a
            call u_fadeout
            call u_hoff
            jp oam_hide

; the list's top: the hand's job in view
jbm_topfix: ld a, [jb_cur]
            ld b, a
            ld a, [jbm_top]
            cp b
            jr c, .lo
            ld a, b
            ld [jbm_top], a
            ret
.lo:        add a, JB_ROWS - 1
            cp b
            ret nc
            ld a, b
            sub JB_ROWS - 1
            ld [jbm_top], a
            ret
; the hand: row 7 + (job - top), text at cell 3
jbm_hand:   ld a, [jbm_top]
            ld b, a
            ld a, [jb_cur]
            sub b
            add a, 7
            ld c, a
            ld b, 3
            jp u_hand

; the screen
jbm_scr:    call oam_hide
            call u_cls
            ld bc, $0000
            ld de, $1405
            call u_box
            ld bc, $0005
            ld de, $140D
            call u_box
            call jbm_head
            ld a, 38                        ; the columns' labels
            ld [u_pool], a
            ld a, UP_LABEL
            ld [u_pal], a
            ld hl, U_LV
            ld bc, $0F06
            call u_textr
            ld hl, U_COST
            ld bc, $1306
            call u_textr
jbm_rows:   xor a
.r:         ld [jbm_k], a
            call jbm_row
            ld a, [jbm_k]
            inc a
            cp JB_ROWS
            jr nz, .r
            ld a, 1
            ld [m_dirty], a
            ret
; row jbm_k: job top + k (cells cleared; its tiles JB_P0 + 11 k)
jbm_row:    ld a, [jbm_k]
            add a, 7
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
            ld a, [jbm_k]
            ld b, a
            add a, a
            add a, a
            add a, b
            add a, a
            add a, b                        ; 11 k
            add a, JB_P0
            ld [u_pool], a
            ld a, [jbm_top]
            ld b, a
            ld a, [jbm_k]
            add a, b
            ld [jbm_j], a
            ld b, a
            ld a, [jb_n]
            cp b
            ret z
            ret c
            ld a, [jbm_j]                   ; its cost and level
            ld [mgm_t], a
            ld a, CODE1
            ld hl, jbx_rowt
            call far_call
            ld a, b
            ld [jbm_cost], a
            ld a, c
            ld [jbm_lv], a
            ld a, UP_WHITE                  ; (the current job yellow, too dear grey)
            ld [u_pal], a
            ld a, [jbm_cj]
            ld b, a
            ld a, [jbm_j]
            cp b
            jr nz, .nc
            ld a, UP_YELLOW
            ld [u_pal], a
            jr .nm
.nc:        ld a, [jbm_cost]
            ld b, a
            ld a, [GS + $1B]
            cp b
            jr nc, .nm
            ld a, UP_GREY
            ld [u_pal], a
.nm:        ld a, [jbm_j]
            call jbm_jname
            ld a, [jbm_k]
            add a, 7
            ld c, a
            ld b, 3
            call u_text
            ld a, [jbm_lv]
            ld e, a
            ld d, 0
            call u_ntoa
            ld a, [jbm_k]
            add a, 7
            ld c, a
            ld b, 15
            call u_textr
            ld a, [jbm_cost]
            ld e, a
            ld d, 0
            call u_ntoa
            ld a, [jbm_k]
            add a, 7
            ld c, a
            ld b, 19
            call u_textr
            ld a, UP_WHITE
            ld [u_pal], a
            ret
; A = job -> HL = its name
jbm_jname:  add a, a
            ld e, a
            ld d, 0
            ld hl, U_JOBN
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ret

; the header: name, Capacity, the job under the hand and the picture in it (pool 0-37)
jbm_head:   xor a
            ld [u_pool], a
            ld a, [jbm_m]
            rrca
            rrca
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
            ld a, UP_LABEL
            ld [u_pal], a
            ld hl, U_CAP
            ld bc, $0B01
            call u_text
            ld a, UP_WHITE
            ld [u_pal], a
            ld a, [GS + $1B]
            ld e, a
            ld d, 0
            call u_ntoa
            ld bc, $1301
            call u_textr
; the job under the hand: its name (pool 30-37) and the picture in it
jbm_hov:    ld bc, $0403
.cl:        push bc
            ld a, U_FILL
            call u_cell
            pop bc
            inc b
            ld a, b
            cp 19
            jr nz, .cl
            ld a, 30
            ld [u_pool], a
            ld a, [jb_cur]
            call jbm_jname
            ld bc, $0403
            call u_text
            ld a, 1
            ld [m_dirty], a
            ld a, [jbm_m]
            ld [u_k], a
            ld [u_pm], a
            ld a, [jb_cur]
            ld [u_t], a
            call u_mjob
            ld a, 2                         ; (its colours shown at once: u_palt -> pal_sh)
            ldh [rSVBK], a
            ld a, [jbm_m]
            add a, a
            add a, a
            add a, a
            add a, low(u_palt + 64)
            ld l, a
            ld h, high(u_palt + 64)
            ld de, mn_buf
            ld bc, 8
            call memcpy
            ld a, [jbm_m]
            add a, a
            add a, a
            add a, a
            add a, low(pal_sh + 64)
            ld e, a
            ld a, high(pal_sh + 64)
            adc a, 0
            ld d, a
            ld hl, mn_buf
            ld bc, 8
            call memcpy
            ld a, 1
            ldh [pal_dirty], a
            ld a, [jbm_m]
            ld [u_k], a
            ld bc, $1008
            jp u_pic

; a message A (3 lines at most) in the header, a key, the header back
jbm_msg:    call jbm_show
            call im_wkey
            ld a, $85
            ld [S49], a
            jp jbm_hback
; the header blanked (a frame), then the message A ($3A: U_MJOB, else FF3's $5A-$79)
jbm_show:   push af
            call u_hoff
            ld a, [jbm_m]                   ; (the picture off)
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
            call jbm_hclr
            xor a
            ld [u_pool], a
            pop af
            cp $3A
            jr nz, .f
            ld a, UP_WHITE
            ld [u_pal], a
            xor a
            ld hl, U_MJOB
            call u_fstr
            call im_tstr
            jp u_flush
.f:         call im_tpromptp
            jp u_flush
jbm_hclr:   ld bc, $0101
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
            ld a, 1
            ld [m_dirty], a
            call wait_vbl
            call wait_vbl
            jp wait_vbl
jbm_hback:  call jbm_hclr
            call jbm_head
            jp u_flush

section wram, $DFA0                         ; (WRAM 2, the menus' bank: free after u_nbuf)
jbm_m:      ds 1
jbm_cj:     ds 1
jbm_top:    ds 1
jbm_k:      ds 1
jbm_j:      ds 1
jbm_cost:   ds 1
jbm_lv:     ds 1
