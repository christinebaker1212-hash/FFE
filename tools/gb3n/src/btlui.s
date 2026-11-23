; ---- battle windows and input on the GB (the approved layout): the menu canvas (WRAM bank 2)
; in the window layer from line 96 (WY 96): canvas rows 0-5 = screen rows 12-17. The party
; window (0, 0, 20, 6): per member name, HP current / maximum (or the chosen command, as FF3's
; English hp window: 34/9BA2); the command window (0, 0, 10, 6) over its left part while a
; member chooses (34/9A69); the font in VRAM bank 1 tiles $70-$FF (text codes = tiles), the
; hand in VRAM bank 1 tiles $60-$63, palettes: the window CGB 7, the hand sprite palette 3.
BD_CMDS    = BD_2F + $240       ; 34/9B21: 4 battle commands a job (build.py)
HAND_T     = $60
NUM_T      = $40                ; numeral sprite tiles in VRAM bank 1 ($40-$49 digits, $4A-$4C Miss)
BTXT_IDX   = $4000              ; BTXT_BANK: 3 bytes a battle string ($0400 + index)
BCV_BUF    = win_buf            ; (bank 0, the field's dialogue box buffer: 4 lines x 20)

ui_init:    ld a, 1                         ; font -> VRAM bank 1 $70-
            call font_ld
            ld a, MENU_BANK                 ; hand -> VRAM bank 1 $60-$63
            ld [vc_src], a
            ld hl, $6E00
            ld de, $8000 + 16 * HAND_T
            ld b, 4
            ld a, 1
            call vcopyx
            call menu_pals
            ld a, BDATA_BANK                ; numeral sprites -> VRAM bank 1 $40-$4C
            ld [vc_src], a
            ld hl, $7000
            ld de, $8000 + 16 * NUM_T
            ld b, 13
            ld a, 1
            call vcopyx
            call msg_reset
            ld a, PAL_TXT | 8
            ld [m_tattr], a
            ld a, 96
            ldh [rWY], a
            ld a, 7
            ldh [rWX], a
            ld a, 1
            ld [menu_on], a
            ret

; the canvas: WRAM bank 2 while drawing, back to FF3's (3) after
cv2:        ld a, 2
            ldh [rSVBK], a
            ret
cv3:        ld a, 3
            ldh [rSVBK], a
            ret

; battle string A + 256 B ($0400 + index) -> btl_str (0-ended, 32 bytes at most)
bstr:       ld l, a
            ld h, b
            ld d, h
            ld e, l
            add hl, hl
            add hl, de
            ld de, BTXT_IDX
            add hl, de
            ld de, btl_str
            ld bc, 3
            ld a, BTXT_BANK
            call rd_copy
            ld a, [btl_str + 1]
            ld l, a
            ld a, [btl_str + 2]
            ld h, a
            ld a, [btl_str]
            ld de, btl_str
            ld bc, 32
            jp rd_copy

; ---- the party window: lines in BCV_BUF (bank 3 values), then the canvas
hp_win:     ld hl, BCV_BUF
            ld de, 80
            ld a, $FF
.cl:        ld [hl+], a
            dec de
            ld b, a
            ld a, d
            or e
            ld a, b
            jr nz, .cl
            xor a
.m:         ld [btl_m], a
            ld l, a                         ; line = BCV_BUF + 20 m
            add a, a
            add a, a
            add a, l
            add a, a
            add a, a
            ld e, a
            ld d, 0
            ld hl, BCV_BUF + 1
            add hl, de
            push hl
            ld a, [btl_m]                   ; name ($6106 + 64 m)
            rrca
            rrca
            add a, 6
            ld e, a
            ld d, 0
            ld hl, GS + $100
            add hl, de
            pop de
            push de
            ld b, 6
.n:         ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .n
            ld a, [btl_m]                   ; hp: $7575 + 64 m + 3
            rrca
            rrca
            add a, 3
            ld e, a
            ld d, 0
            ld hl, W7 + $7575
            add hl, de
            ld a, [hl+]
            ld e, a
            ld a, [hl+]
            ld d, a
            push hl
            pop bc
            pop hl
            push bc
            ld bc, 11                       ; current: columns 9-12 (right-aligned at 12)
            add hl, bc
            call dec4
            ld [hl], $C7                    ; "/"
            inc hl
            push hl
            ld a, [btl_m]                   ; the chosen command, else the maximum
            ld e, a
            ld d, 0
            ld hl, W7 + $78CF
            add hl, de
            ld a, [hl]
            pop hl
            pop bc
            cp $FF
            jr z, .max
            cp $C8
            jr nc, .max                     ; (spells: later)
            push hl
            add a, $20                      ; command names $0620 +
            ld b, 2
            call bstr
            pop de
            ld hl, btl_str
            ld b, 5
.cn:        ld a, [hl+]
            and a
            jr z, .nx
            ld [de], a
            inc de
            dec b
            jr nz, .cn
            jr .nx
.max:       push hl
            ld h, b
            ld l, c
            ld a, [hl+]
            ld e, a
            ld d, [hl]
            pop hl
            inc hl
            inc hl
            inc hl
            call dec4
.nx:        ld a, [btl_m]
            inc a
            cp 4
            jp nz, .m
            call cv2                        ; the canvas: window and lines
            ld bc, $0000
            ld de, $1406
            call b_box
            ld hl, BCV_BUF
            ld c, 1
.r:         ld b, 0
.k:         ld a, [hl+]
            call m_put
            inc b
            ld a, b
            cp 20
            jr nz, .k
            inc c
            ld a, c
            cp 5
            jr nz, .r
            ld bc, $0000                    ; (the frame again: the lines' first / last cells)
            ld de, $1406
            call b_box
            ld a, 1
            ld [m_dirty], a
            jp cv3

; DE in decimal, right-aligned ending at HL (4 cells, blanks before), HL after it
dec4:       push hl
            ld b, 4
.l:         push bc
            push hl
            call b_div10                      ; DE / 10, A = remainder
            pop hl
            pop bc
            add a, $80
            ld [hl-], a
            dec b
            jr z, .x
            ld a, d
            or e
            jr nz, .l
.x:         pop hl
            inc hl
            ret

; ---- the command window (34/9A69): the member's four commands ($7400-$7403; row changes
; $7404 / $7405 = 2 / 3), names $0620 + id
cmd_win:    ld a, 2
            ld [W7 + $7404], a
            inc a
            ld [W7 + $7405], a
            ld a, [BZ + $5F]
            ld c, a
            ld a, $57
            call zpy
            ld a, [hl]                      ; job * 4 -> 34/9B21
            add a, a
            add a, a
            add a, low(BD_CMDS)
            ld l, a
            ld a, high(BD_CMDS)
            adc a, 0
            ld h, a
            ld de, W7 + $7400
            ld bc, 4
            ld a, BDATA_BANK
            call rd_copy
            ld hl, BCV_BUF                  ; names -> 4 lines of 8
            ld de, 32
            ld a, $FF
.cl:        ld [hl+], a
            dec e
            jr nz, .cl
            xor a
.c:         ld [btl_m], a
            ld e, a
            ld d, 0
            ld hl, W7 + $7400
            add hl, de
            ld a, [hl]
            cp $FF
            jr nz, .s
            xor a
.s:         add a, $20
            ld b, 2
            call bstr
            ld a, [btl_m]
            add a, a
            add a, a
            add a, a
            ld e, a
            ld d, 0
            ld hl, BCV_BUF
            add hl, de
            ld d, h
            ld e, l
            ld hl, btl_str
            ld b, 8
.cp:        ld a, [hl+]
            and a
            jr z, .cx
            ld [de], a
            inc de
            dec b
            jr nz, .cp
.cx:        ld a, [btl_m]
            inc a
            cp 4
            jr nz, .c
            call cv2
            ld bc, $0000
            ld de, $0A06
            call b_box
            ld hl, BCV_BUF
            ld c, 1
.r:         ld b, 2
.k:         ld a, [hl+]
            call m_put
            inc b
            ld a, b
            cp 9
            jr nz, .k
            inc hl
            inc c
            ld a, c
            cp 5
            jr nz, .r
            ld a, 1
            ld [m_dirty], a
            jp cv3

; ---- input: new presses with FF3's repeat (as the field menus' m_keys) -> btl_new
b_keys:     call wait_vbl
            call read_pad
            ldh a, [pad]
            ld b, a
            ld a, [btl_old]
            cpl
            and b
            ld c, a
            ld a, b
            ld [btl_old], a
            and $F0
            jr z, .nr
            ld hl, btl_rep
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
            ld [btl_rep], a
.out:       ld a, c
            ld [btl_new], a
            ret

; the hand (OAM sprites 36-39) with its tip at screen B, C (B = x left, C = y top); B = $FF hides
b_hand:     ld hl, oam_buf + 4 * 36
            ld a, b
            cp $FF
            jr nz, .s
            xor a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl], a
            ret
.s:         ld de, hand_spr
            ld a, 4
.l:         push af
            ld a, [de]                      ; dy, dx, tile, attr
            add a, c
            add a, 16
            ld [hl+], a
            inc de
            ld a, [de]
            add a, b
            add a, 8
            ld [hl+], a
            inc de
            ld a, [de]
            ld [hl+], a
            inc de
            ld a, [de]
            ld [hl+], a
            inc de
            pop af
            dec a
            jr nz, .l
            ret
hand_spr:   db 0, 0, HAND_T + 0, 3 | 8
            db 8, 0, HAND_T + 2, 3 | 8
            db 0, 8, HAND_T + 1, 3 | 8
            db 8, 8, HAND_T + 3, 3 | 8

; ---- 34/986C get character actions: each member (dead / stone / jumping skipped; asleep,
; paralysed, confused: their own action, later) chooses a command; B goes back a member
get_actions:
            xor a
            ld [BZ + $52], a
.next:      ld a, [BZ + $52]
            cp 4
            jp z, .done
            ld e, a
            ld d, 0
            ld hl, W7 + $78CF
            add hl, de
            ld [hl], $FF
            ld hl, W7 + $7E0F
            add hl, de
            ld [hl], 0
            call hp_win
            call chr_ofs
            ld a, [BZ + $52]                ; saved defence value back
            ld e, a
            ld d, 0
            ld hl, W7 + $7CE4
            add hl, de
            ld a, [hl]
            and a
            jr z, .d0
            ld [hl], 0
            push af
            ld a, [BZ + $5F]
            add a, $23
            ld c, a
            ld a, $5B
            call zpy
            pop af
            ld [hl], a
.d0:        ld a, [BZ + $5F]
            inc a
            ld c, a
            ld a, $5B
            call zpy
            ld a, [hl+]
            and $C0
            jr nz, .skip
            ld a, [hl]
            and 1
            jr nz, .skip                    ; (jumping)
            call cmd_win
            ld a, [BZ + $5F]                ; command, target cleared; item flag off
            add a, $2E
            ld c, a
            ld a, $5B
            call zpy
            xor a
            ld [hl+], a
            ld [hl+], a
            ld [hl], a
            call cmd_input                  ; -> A = 0 back, 1 chosen
            and a
            jr z, .back
.skip:      ld hl, BZ + $52
            inc [hl]
            jr .next
.back:      call b_back
            jr .next
.done:      ld b, $FF
            jp b_hand

; 34/9A42: back to the previous member able to choose (else the same one)
b_back:     ld a, [BZ + $52]
            ld [BZ + $18], a
.p:         ld a, [BZ + $52]
            and a
            jr z, .same
            dec a
            ld [BZ + $52], a
            call chr_ofs
            add a, 2
            ld c, a
            ld a, $5B
            call zpy
            ld a, [hl]
            and 1
            jr nz, .p
            ld a, [BZ + $52]
            add a, a
            ld e, a
            ld d, 0
            ld hl, W7 + $78BB
            add hl, de
            ld a, [hl]
            and $F8
            ret z
            jr .p
.same:      ld a, [BZ + $18]
            ld [BZ + $52], a
            ret

; the command list's cursor (slots 0-3; left / right: the row commands, slots 4 / 5); A = 1 when
; a command was taken, 0 = back (B on a later member)
cmd_input:  xor a
            ld [btl_cur], a
.l:         ld a, [btl_cur]                 ; the hand at the command's line (screen rows 13-16)
            add a, a
            add a, a
            add a, a
            add a, 104 - 4
            ld c, a
            ld b, 0
            call b_hand
            call b_keys
            ld a, [btl_new]
            bit 0, a
            jr nz, .a
            bit 1, a
            jr nz, .b
            ld b, a
            ld a, [btl_cur]
            bit 6, b
            jr z, .d
            and a
            jr z, .l
            dec a
            jr .s
.d:         bit 7, b
            jr z, .lr
            cp 3
            jr z, .l
            inc a
.s:         ld [btl_cur], a
            ld a, $98
            ld [S49], a
            jr .l
.lr:        ld a, b                         ; left / right: change row (back attack: swapped)
            and $30
            jr z, .l
            ld c, 4
            bit 5, b
            jr nz, .rw
            inc c
.rw:        ld a, [W7 + $78BA]
            and 8
            jr z, .rw2
            ld a, c
            xor 1
            ld c, a
.rw2:       ld a, c
            ld [btl_cur], a
            jr .a
.b:         ld a, [BZ + $52]
            and a
            jr z, .l
            xor a
            ret
.a:         ld a, $85                       ; 34/99C6
            ld [S49], a
            ld a, [btl_cur]
            ld e, a
            ld d, 0
            ld a, [BZ + $52]
            ld c, a
            ld b, 0
            ld hl, W7 + $7AC3
            add hl, bc
            ld [hl], e
            ld hl, W7 + $7400
            add hl, de
            ld a, [hl]
            ld hl, W7 + $78CF
            add hl, bc
            ld [hl], a
            cp 4
            jr z, .fight
            cp 5
            jr z, .defend
            cp 6
            jr z, .run
            cp 7
            jr z, .escape
            cp 2
            jr z, .row
            cp 3
            jr z, .row
            ld a, $86                       ; (the other commands: not yet)
            ld [S49], a
            ld a, $FF
            ld hl, W7 + $78CF
            add hl, bc
            ld [hl], a
            jp .l
.row:       call b_setcmd                   ; (35/A70x: the row change as its action)
            ld a, 1
            ret
.fight:     ld a, 4                         ; 35/A848 do command: the targets
            ld [BZ + $54], a
            call target_mon
            and a
            jp z, .l
            ld a, [BZ + $5F]
            add a, $2F
            ld c, a
            ld a, $5B
            call zpy
            ld a, [BZ + $B4]
            ld [hl+], a
            ld a, [BZ + $B5]
            ld [hl-], a
            dec hl
            ld a, [BZ + $54]
            ld [hl], a
            ld a, 1
            ret
.defend:    ld a, 5
            jr .act
.run:       ld a, 6
            jr .act
.escape:    ld a, 7
.act:       push af
            ld a, [BZ + $5F]
            add a, $2E
            ld c, a
            ld a, $5B
            call zpy
            pop af
            ld [hl], a
            ld a, 1
            ret
; the row commands store their id as the action
b_setcmd:   ld b, a
            ld a, [BZ + $5F]
            add a, $2E
            ld c, a
            ld a, $5B
            call zpy
            ld [hl], b
            ret

; graphics $10 choose targets (monsters): the hand left of a living monster; up / down / left /
; right to the next one; A -> $B4 = its bit, $B5 = $80, A = 1; B -> A = 0
target_mon: ld a, 0
.f:         ld [btl_tgt], a                 ; the first living slot
            call mon_alive
            jr nz, .l
            ld a, [btl_tgt]
            inc a
            cp 8
            jr nz, .f
            xor a
            ret
.l:         call mon_cursor
            call b_hand
            call b_keys
            ld a, [btl_new]
            bit 0, a
            jr nz, .a
            bit 1, a
            jr nz, .b
            and $F0
            jr z, .l
            ld b, a
.mv:        ld a, [btl_tgt]                 ; down / right: next, up / left: previous
            bit 6, b
            jr nz, .pv
            bit 5, b
            jr nz, .pv
            inc a
            jr .w
.pv:        dec a
.w:         and 7
            ld [btl_tgt], a
            call mon_alive
            jr z, .mv
            ld a, $98
            ld [S49], a
            jr .l
.a:         ld a, $85
            ld [S49], a
            ld a, [btl_tgt]
            call bitmask
            ld [BZ + $B4], a
            ld a, $80
            ld [BZ + $B5], a
            ld b, $FF
            call b_hand
            ld a, 1
            ret
.b:         ld a, $85
            ld [S49], a
            xor a
            ret
; NZ if monster slot btl_tgt is there and alive
mon_alive:  ld a, [btl_tgt]
            ld e, a
            ld d, 0
            ld hl, W7 + $7DA7
            add hl, de
            ld a, [hl]
            cp $FF
            jr z, .no
            ld a, [btl_tgt]                 ; status: $7675 + 64 n + 1
            rrca
            rrca
            ld l, a
            and $C0
            inc a
            ld e, a
            ld a, l
            and 3
            ld d, a
            ld hl, W7 + $7675
            add hl, de
            ld a, [hl]
            and $C0
            jr nz, .no
            or 1
            ret
.no:        xor a
            ret
; B, C = the hand's screen place for monster btl_tgt: its position entry (x, y, size): left
; of it, mid-height (NES cells -> the view: x * 8 - 20 - 16, (y - 6) * 8 + height * 4 - 8)
mon_cursor: call pos_ptr
            ld a, [btl_tgt]
            ld e, a
            add a, a
            add a, e
            ld e, a
            ld d, 0
            add hl, de
            call bd_rd
            ld [btl_px], a
            call bd_rd
            ld [btl_py], a
            call bd_rd
            add a, a
            add a, low(TB_SIZE) + 1
            ld l, a
            ld h, high(TB_SIZE)
            call bd_rd                      ; height
            add a, a
            add a, a
            ld c, a
            ld a, [btl_py]
            sub 6
            add a, a
            add a, a
            add a, a
            add a, c
            sub 8
            ld c, a
            ld a, [btl_px]
            add a, a
            add a, a
            add a, a
            sub 20 + 16
            jr nc, .x
            xor a
.x:         ld b, a
            ret

; a window frame (as the menus' m_box, in this bank): B, C = left, top; D, E = width, height
b_box:      push bc
            ld a, [m_tattr]
            ld [m_attr], a
            ld a, $F7
            call m_put2
            ld a, d
            sub 2
            ld h, a
.t:         inc b
            ld a, $F8
            call m_put2
            dec h
            jr nz, .t
            inc b
            ld a, $F9
            call m_put2
            pop bc
            push bc
            ld a, e
            sub 2
            ld l, a
.m:         inc c
            push bc
            ld a, $FA
            call m_put2
            ld a, b
            add a, d
            dec a
            ld b, a
            ld a, $FB
            call m_put2
            pop bc
            dec l
            jr nz, .m
            inc c
            ld a, $FC
            call m_put2
            ld a, d
            sub 2
            ld h, a
.b:         inc b
            ld a, $FD
            call m_put2
            dec h
            jr nz, .b
            inc b
            ld a, $FE
            call m_put2
            pop bc
            ret
; DE = DE / 10, A = DE mod 10
b_div10:    ld hl, 0
            ld b, 16
.l:         sla e
            rl d
            rl l
            ld a, l
            sub 10
            jr c, .n
            ld l, a
            inc e
.n:         dec b
            jr nz, .l
            ld a, l
            ret

section wram, $DFD8
btl_m:      ds 1
btl_cur:    ds 1
btl_old:    ds 1
btl_rep:    ds 1
btl_new:    ds 1
btl_tgt:    ds 1
btl_px:     ds 1
btl_py:     ds 1
btl_str:    ds 32
