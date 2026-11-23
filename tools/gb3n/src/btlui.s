; ---- battle windows and input on the GB (the approved layout): the menu canvas (WRAM bank 2)
; in the window layer from line 96 (WY 96): canvas rows 0-5 = screen rows 12-17. The party
; window (0, 0, 20, 6): per member name, HP current / maximum (or the chosen command, as FF3's
; English hp window: 34/9BA2); the command window (0, 0, 10, 6) over its left part while a
; member chooses (34/9A69); the font in VRAM bank 1 tiles $70-$FF (text codes = tiles), the
; hand in VRAM bank 1 tiles $60-$63, palettes: the window CGB 7, the hand sprite palette 3.

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
            cp 8
            jp z, .jump
            cp $0B
            jp z, .terr
            cp $0C
            jr z, .tcmd
            cp $0D
            jr z, .tcmd
            cp $0E
            jr z, .tcmd
            cp $10
            jr z, .tcmd
            cp $0F
            jr z, .act
            cp $11
            jr z, .act
            cp $12
            jr z, .act
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
.tcmd:      ld [BZ + $54], a
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
.jump:      xor a                           ; 35/A9AB: a monster target
            ld [BZ + $B3], a
            call target_sel
            and a
            jp z, .l
            ld a, [BZ + $B5]
            bit 7, a
            jr z, .jump
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
            ld [hl], 8
            ld a, 1
            ret
.terr:      ld a, [BZ + $5F]                ; 35/AA22: the action, the terrain's targets
            add a, $2E
            ld c, a
            ld a, $5B
            call zpy
            ld [hl], $0B
            call terr_atk
            sub $50
            inc a
            ld b, a
            ld hl, BD_TERRT
            push bc
            call bd_rd
            pop bc
.tb:        add a, a
            dec b
            jr nz, .tb
            jr nc, .tall
            ld a, [BZ + $5F]                ; (31/A2E9: a random monster)
            ld c, a
            ld b, 0
            ld hl, W7 + $7575
            add hl, bc
            ld a, $6E
            call zpset
            ld hl, W7 + $7675
            ld a, $22
            call zpset
            ld a, 7
            call rnd_target
            ld a, [W7 + $7E99]
            ld d, $80
            jr .tset
.tall:      ld a, $FF
            ld d, $C0
.tset:      push af
            ld a, [BZ + $5F]
            add a, $2F
            ld c, a
            ld a, $5B
            call zpy
            pop af
            ld [hl+], a
            ld [hl], d
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

; ---- graphics $10 / 32/9A1C choose targets, FF3's cursor: monsters on a 2 x 4 grid by tilemap id
; (32/9EAD: $AF column, $B0 row), $B1 the mode (0 one monster, 1 all, 2 / 3 a monster type,
; 4 one member, 5 all members), $B2 the member; $B3 bit 1: start on the members, bit 0: groups
; allowed (else modes 1, 2, 3, 5 are refused). A -> $B4 = the mask, $B5 = $C0 monsters / $40
; members (bit 6 cleared for a single target), A = 1; B -> $B4 = 0, A = 0
target_sel: xor a
            ld [BZ + $AF], a
            ld [BZ + $B0], a
            ld [BZ + $B2], a
            ld a, [BZ + $B3]
            ld b, a
            and 1
            ld [BZ + $B3], a
            ld a, b
            and 2
            ld a, 4
            jr z, .s
            inc a
.s:         ld [BZ + $B1], a
            call ts_right
.l:         call ts_show
            call b_keys
            call ts_input
            ld a, [BZ + $AD]
            ld b, a
            ld a, [BZ + $AE]
            or b
            jr nz, .l
            ld b, $FF
            call b_hand
            ld a, [BZ + $B4]
            and a
            ret z
            ld a, 1
            ret
target_mon: xor a
            ld [BZ + $B3], a
            jp target_sel

; the hand on the first target ($AD monsters, else $AE members)
ts_show:    ld a, [BZ + $AD]
            and a
            jr z, .c
            ld b, 0
.m:         add a, a
            jr c, .m1
            inc b
            jr .m
.m1:        ld a, b
            ld [btl_tgt], a
            call mon_cursor
            jp b_hand
.c:         ld a, [BZ + $AE]
            ld b, 0
.n:         add a, a
            jr c, .n1
            inc b
            ld c, a
            ld a, b
            cp 4
            ret z
            ld a, c
            jr .n
.n1:        ld a, b                         ; member b: left of its sprite
            add a, a
            add a, b
            add a, a
            add a, a
            add a, a
            add a, low(oam_buf)
            ld l, a
            ld h, high(oam_buf)
            ld a, [hl+]
            sub 16 - 4
            ld c, a
            ld a, [hl]
            sub 8 + 16
            ld b, a
            jp b_hand

; 32/9B8C: the input; groups refused unless $B3
ts_input:   ld a, [BZ + $AD]
            ld [btl_tmp], a
            ld a, [BZ + $AE]
            ld [btl_tmp + 1], a
            ld a, [BZ + $AF]
            ld [btl_tmp + 2], a
            ld a, [BZ + $B0]
            ld [btl_tmp + 3], a
            ld a, [BZ + $B1]
            ld [btl_tmp2], a
            call ts_key
            ld a, [BZ + $B3]
            and a
            ret nz
            ld a, [BZ + $B1]
            cp 4
            ret z
            and a
            ret z
            ld a, [btl_tmp2]
            ld [BZ + $B1], a
            ld a, [btl_tmp + 3]
            ld [BZ + $B0], a
            ld a, [btl_tmp + 2]
            ld [BZ + $AF], a
            ld a, [btl_tmp + 1]
            ld [BZ + $AE], a
            ld a, [btl_tmp]
            ld [BZ + $AD], a
            ret

; 32/9BCD (one button alone)
ts_key:     ld a, [btl_new]
            and a
            ret z
            ld b, a
            and $F0
            jr z, .k
            ld a, $98
            ld [S49], a
.k:         ld a, b
            cp $10
            jr z, .right
            cp $20
            jr z, .left
            cp $80
            jp z, ts_down
            cp $40
            jp z, ts_up
            cp 1
            jr z, .a
            cp 2
            ret nz
            xor a                           ; B
            ld [BZ + $AD], a
            ld [BZ + $AE], a
            ld [BZ + $B4], a
            ld [BZ + $B5], a
            ld [btl_n2], a
            ret
.a:         ld a, $85
            ld [S49], a
            ld a, [BZ + $AD]
            and a
            jr z, .ac
            ld [BZ + $B4], a
            ld a, $C0
            jr .a1
.ac:        ld a, [BZ + $AE]
            and $F0
            ld [BZ + $B4], a
            ld a, $40
.a1:        ld [BZ + $B5], a
            ld a, [BZ + $B4]                ; 32/9C50: a single target
            ld b, 8
            ld c, $80
.sg:        cp c
            jr z, .sg1
            srl c
            dec b
            jr nz, .sg
            jr .a2
.sg1:       ld a, [BZ + $B5]
            and $BF
            ld [BZ + $B5], a
.a2:        xor a
            ld [BZ + $AD], a
            ld [BZ + $AE], a
            ret
.right:     ld a, [W7 + $78C3]              ; (a back attack: the other way)
            cp $88
            jr nz, ts_right
            jr ts_left
.left:      ld a, [W7 + $78C3]
            cp $88
            jr nz, ts_left
            ; (fall through)
; 32/9C80
ts_right:   ld a, [BZ + $B1]
            cp 5
            jp z, ts_chr
            cp 4
            jr z, .one
            cp 1
            ret z
            cp 6
            ret nc
            ld a, [BZ + $AF]                ; 0 / 2 / 3: 9CAE
            and a
            jr z, .all
            dec a
            ld [BZ + $AF], a
            call ts_ok
            jp c, ts_mon
            ld a, 1
            ld [BZ + $B0], a
.r:         call ts_ok
            jp c, ts_mon
            call ts_back
            ld a, [BZ + $AF]
            cp $FF
            jr nz, .r
.all:       xor a
            ld [BZ + $B0], a
            ld [BZ + $AF], a
            jp ts_allm
.one:       ld a, 3
            ld [BZ + $AF], a
            ld a, 1
            ld [BZ + $B0], a
.o:         call ts_ok
            jp c, ts_mon
            call ts_back
            jr .o
; 32/9CDC
ts_left:    ld a, [BZ + $B1]
            cp 1
            jr z, .allm
            cp 4
            jp z, ts_allc
            cp 5
            ret z
            cp 6
            ret nc
            ld a, [BZ + $AF]                ; 0 / 2 / 3: 9D08
            cp 3
            jp z, ts_chr
            inc a
            ld [BZ + $AF], a
            call ts_ok
            jp c, ts_mon
            xor a
            ld [BZ + $B0], a
.l:         call ts_ok
            jp c, ts_mon
            call ts_fwd
            ld a, [BZ + $AF]
            cp 4
            jr nz, .l
            jp ts_chr
.allm:      xor a
            ld [BZ + $AF], a
            ld [BZ + $B0], a
.m:         call ts_ok
            jp c, ts_mon
            call ts_fwd
            jr .m
; 32/9D4F
ts_up:      ld a, [BZ + $B1]
            and a
            jr z, .m
            cp 3
            jp z, ts_mon
            cp 4
            ret nz
.c:         ld a, [BZ + $B2]
            dec a
            and 3
            ld [BZ + $B2], a
            call ts_cok
            jr nz, .c
            jp ts_chr
.m:         ld a, [BZ + $B0]
            and a
            jp z, ts_row2
            dec a
            ld [BZ + $B0], a
            call ts_ok
            jp c, ts_mon
            ld hl, BZ + $B0
            inc [hl]
            jp ts_row2
; 32/9D8E
ts_down:    ld a, [BZ + $B1]
            and a
            jr z, .m
            cp 2
            jp z, ts_mon
            cp 4
            ret nz
.c:         ld a, [BZ + $B2]
            inc a
            and 3
            ld [BZ + $B2], a
            call ts_cok
            jr nz, .c
            jp ts_chr
.m:         ld a, [BZ + $B0]
            and a
            jp nz, ts_row3
            inc a
            ld [BZ + $B0], a
            call ts_ok
            jp c, ts_mon
            ld hl, BZ + $B0
            dec [hl]
            jp ts_row3
; 32/9C66 / 9C73 the grid walked forward / back
ts_fwd:     ld a, [BZ + $B0]
            inc a
            and 1
            ld [BZ + $B0], a
            ret nz
            ld hl, BZ + $AF
            inc [hl]
            ret
ts_back:    ld a, [BZ + $B0]
            dec a
            and 1
            ld [BZ + $B0], a
            ret z
            ld hl, BZ + $AF
            dec [hl]
            ret
; the grid's slot at ($B0 & 1) x 4 + $AF -> A (HL = the entry)
ts_slot:    ld a, [W7 + $7D7B]
            add a, a
            add a, a
            add a, a
            ld e, a
            ld a, [BZ + $B0]
            and 1
            add a, a
            add a, a
            ld hl, BZ + $AF
            add a, [hl]
            add a, e
            ld e, a
            ld d, 0
            ld hl, TS_GRID
            add hl, de
            jp bd_rd
; 32/9D33: carry set if the grid place has a monster
ts_ok:      call ts_slot
            cp $FF
            jr z, .n
            ld e, a
            ld d, 0
            ld hl, W7 + $7DA7
            add hl, de
            ld a, [hl]
            cp $FF
            jr z, .n
            scf
            ret
.n:         and a
            ret
; Z if member $B2 can be chosen (a job, not jumping)
ts_cok:     ld a, [BZ + $B2]
ts_cok0:    ld e, a
            ld d, 0
            ld hl, W7 + $7D8B
            add hl, de
            ld a, [hl]
            cp $FF
            jr z, .n
            ld hl, W7 + $7E22
            add hl, de
            ld a, [hl]
            and a
            ret
.n:         or 1
            ret
; 32/9DD0: one member (from $B2 on)
ts_chr:     ld a, [BZ + $B2]
            and 3
            ld [BZ + $B2], a
            call ts_cok
            jr z, .ok
            ld hl, BZ + $B2
            inc [hl]
            jr ts_chr
.ok:        ld a, 3
            ld [BZ + $AF], a
            ld a, 1
            ld [BZ + $B0], a
            ld a, [BZ + $B2]
            ld b, a
            ld a, $88
            inc b
.k:         dec b
            jr z, .k1
            srl a
            jr .k
.k1:        ld [BZ + $AE], a
            xor a
            ld [BZ + $AD], a
            ld a, 4
            ld [BZ + $B1], a
            ret
; 32/9E03: one monster (the grid place)
ts_mon:     call ts_slot
            call bitmask
            ld [BZ + $AD], a
            xor a
            ld [BZ + $AE], a
            ld [BZ + $B1], a
            ret
; 32/9E1A: all members
ts_allc:    xor a
            ld [BZ + $AD], a
            ld a, 5
            ld [BZ + $B1], a
            ld b, 0
            ld c, 0
.c:         ld a, c
            push bc
            call ts_cok0
            pop bc
            scf
            jr z, .c1
            and a
.c1:        rl b
            inc c
            ld a, c
            cp 4
            jr nz, .c
            ld a, b
            swap a
            ld [BZ + $AE], a
            ret
; 32/9E49: all monsters
ts_allm:    xor a
            ld [BZ + $AD], a
            ld [BZ + $AE], a
            ld [BZ + $AF], a
            ld [BZ + $B0], a
            ld [BZ + $B2], a
            inc a
            ld [BZ + $B1], a
            ld hl, W7 + $7DA7
            ld b, 8
            ld c, 0
.m:         ld a, [hl+]
            cp $FF
            rl c
            dec b
            jr nz, .m
            ld a, c
            ld [BZ + $AD], a
            ret
; 32/9E71 / 9E78: the monsters of the grid place's type
ts_row2:    ld a, 2
            jr ts_row
ts_row3:    ld a, 3
ts_row:     ld [BZ + $B1], a
            xor a
            ld [BZ + $AD], a
            ld [BZ + $AE], a
            call ts_slot
            ld e, a
            ld d, 0
            ld hl, W7 + $7DA7
            add hl, de
            ld a, [hl]
            ld [BZ + $7E], a
            ld b, a
            ld hl, W7 + $7DA7
            ld c, 0
            ld e, 8
.m:         ld a, [hl+]
            cp b
            scf
            jr z, .m1
            and a
.m1:        rl c
            dec e
            jr nz, .m
            ld a, c
            ld [BZ + $AD], a
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
