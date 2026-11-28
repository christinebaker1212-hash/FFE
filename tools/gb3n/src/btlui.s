; ---- battle windows and input on the GB (the approved layout): the menu canvas (WRAM bank 2)
; in the window layer from line 96 (WY 96): canvas rows 0-5 = screen rows 12-17. The party
; window (0, 0, 20, 6): per member name, HP current / maximum (or the chosen command, as FF3's
; English hp window: 34/9BA2); the command window (0, 0, 10, 6) over its left part while a
; member chooses (34/9A69); the font in VRAM bank 1 tiles $70-$FF (text codes = tiles), the
; hand in VRAM bank 1 tiles $60-$63, palettes: the window CGB 7, the hand sprite palette 3.

ui_hand:    ld a, MENU_BANK                 ; hand -> VRAM bank 1 $60-$63
            ld [vc_src], a
            ld hl, $6E00
            ld de, $8000 + 16 * HAND_T
            ld b, 4
            ld a, 1
            jp vcopyx
ui_init:    ld a, 1                         ; font -> VRAM bank 1 $70-
            call font_ld
            call ui_hand
            call menu_pals
            call bv_init                    ; (btlvwf.s: the small font's windows)
            ld a, BDATA_BANK                ; numeral sprites -> VRAM bank 1 $40-$4C
            ld [vc_src], a
            ld hl, $7000
            ld de, $8000 + 16 * NUM_T
            ld b, 13
            ld a, 1
            call vcopyx
            call msg_reset
            xor a
            ld [msg_full], a
            ld [msg_keep], a
            ld a, BVP_W | 8
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

; ---- the windows as the mock-up (owner's polish pass, 2026-11-28; small font: btlvwf.s): the left
; window (0, 0, 10, 6) for the commands, the target's name and the action's lines; the party window
; (10, 0, 10, 6): per member the name (yellow while it chooses or acts) and HP current / maximum
; (yellow below a quarter, grey when fallen). A battle message covers both (btlmsg.s).
hp_win:     call bv_clrall                  ; (both windows drawn again: every string gone first)
            xor a
            ld [msg_full], a
            ld bc, $0000
            ld de, $0A06
            call w_box
            ld bc, $0A00
            ld de, $0A06
            call w_box
            xor a
.m:         ld [btl_m], a
            call hp_line
            ld a, [btl_m]
            inc a
            cp 4
            jr nz, .m
            ret

; member btl_m's line
hp_line:    ld a, [btl_m]                   ; the name (GS + $106 + 64 m), its blanks after off
            rrca
            rrca
            add a, 6
            ld l, a
            ld h, high(GS + $100)
            ld de, btl_str
            call nm6
            ld a, [btl_hl]
            ld b, a
            ld a, [btl_m]
            cp b
            ld e, BVP_W
            jr nz, .w
            ld e, BVP_Y
.w:         inc a
            ld c, a
            ld b, 11
            ld d, 15
            ld hl, btl_str
            call bv_put
            ld a, [btl_m]                   ; HP: $7575 + 64 m + 3 (current, maximum)
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
            ld a, [hl+]
            ld c, a
            ld b, [hl]
            push bc
            push de
            ld hl, btl_str
            call bnum
            ld [hl], $C7                    ; "/"
            inc hl
            pop de
            pop bc
            push de
            push bc
            ld d, b
            ld e, c
            call bnum
            ld [hl], 0
            pop bc                          ; the colour: fallen grey; current x 4 < maximum yellow
            pop de
            ld a, [btl_m]
            rrca
            rrca
            inc a
            push bc
            ld c, a
            ld a, $5B
            call zpy
            pop bc
            ld a, [hl]
            and $C0
            ld a, BVP_L
            jr nz, .p
            sla e
            rl d
            sla e
            rl d
            ld a, e
            sub c
            ld a, d
            sbc b
            ld a, BVP_W
            jr nc, .p
            ld a, BVP_Y
.p:         or BVF_R
            ld e, a
            ld a, [btl_m]
            inc a
            ld c, a
            ld b, 15
            ld d, 19
            ld hl, btl_str
            jp bv_put

; 6 name letters HL -> DE, 0-ended, the blanks after the last letter off
nm6:        ld b, 6
            push de
.c:         ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .c
            xor a
            ld [de], a
            pop hl
            ld b, 6
            ld c, 0                         ; C = the length up to the last letter
.l:         ld a, [hl+]
            cp $FF
            jr z, .n
            ld a, 7
            sub b
            ld c, a
.n:         dec b
            jr nz, .l
            ld a, l
            sub 6
            ld l, a
            ld a, h
            sbc 0
            ld h, a
            ld b, 0
            add hl, bc
            ld [hl], 0
            ret

; DE in decimal at HL (no leading zeros), HL after it
bnum:       xor a
            ld [bn_f], a
            ld bc, 10000
            call .d
            ld bc, 1000
            call .d
            ld bc, 100
            call .d
            ld bc, 10
            call .d
            ld a, e
            add a, $80
            ld [hl+], a
            ret
.d:         ld a, $7F
.l:         inc a
            push af
            ld a, e
            sub c
            ld e, a
            ld a, d
            sbc b
            ld d, a
            jr c, .u
            pop af
            jr .l
.u:         ld a, e
            add a, c
            ld e, a
            ld a, d
            adc a, b
            ld d, a
            pop af
            cp $80
            jr nz, .w
            ld a, [bn_f]
            and a
            ret z
            ld a, $80
.w:         ld [hl+], a
            ld a, 1
            ld [bn_f], a
            ret

; a window at B, C, D x E: frame, inside blank, its strings gone
w_box:      push bc
            push de
            call cv2
            call b_box
            pop de
            pop bc
            push bc
            push de
            dec d
            dec d
            dec e
            dec e
            inc c
.r:         push bc
            push de
            inc b
.k:         ld a, $FF
            call m_put
            inc b
            dec d
            jr nz, .k
            pop de
            pop bc
            inc c
            dec e
            jr nz, .r
            call cv3
            pop de
            pop bc
            ld a, b                         ; the strings on its rows
            add a, d
            ld d, a
            inc c
            dec e
            dec e
.s:         call bv_clr
            inc c
            dec e
            jr nz, .s
            ld a, 1
            ld [m_dirty], a
            ret

; ---- the command window (34/9A69): the member's four commands ($7400-$7403; row changes
; $7404 / $7405 = 2 / 3), names $0620 + id, in the left window from column 2
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
            ld bc, $0000
            ld de, $0A06
            call w_box
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
            inc a
            ld c, a
            ld b, 2
            ld d, 10
            ld e, BVP_W
            ld hl, btl_str
            call bv_put
            ld a, [btl_m]
            inc a
            cp 4
            jr nz, .c
            ret

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
.out:       bit 0, b                        ; (FF1's quick selection: A held repeats, after 18
            jr z, .na                       ;   frames, then every 6)
            ld hl, btl_arep
            inc [hl]
            ld a, [hl]
            cp 18
            jr c, .ao
            ld [hl], 12
            set 0, c
            jr .ao
.na:        xor a
            ld [btl_arep], a
.ao:        ld a, c
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
            ld a, [BZ + $52]                ; (its name yellow while it chooses)
            ld [btl_hl], a
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
            jr z, .alive
            ld hl, W7 + $7CEB               ; (dead / stone)
            inc [hl]
            jr .skip
.alive:     ld a, [hl]                      ; 35/A66C: confused -> 31/BF17, asleep / paralysed -> 1
            and $E0
            jr z, .nc
            and $20
            jr z, .slp
            call conf_atk
            jr .skip
.slp:       ld a, [BZ + $5F]
            add a, $2E
            ld c, a
            ld a, $5B
            call zpy
            ld [hl], 1
            jr .skip
.nc:        ld a, [hl]
            and 1
            jr nz, .skip                    ; (jumping)
            ld a, [BZ + $52]                ; 34/9940: the member steps forward for its command
            ld [BZ + $95], a
            ld [BZ + $53], a
            call ba_stepf
            call cmd_win
            call atk_mem                    ; (34/98EE: the item flag off, a picked item back)
            res 3, [hl]
            call ret_item
            ld a, [BZ + $5F]                ; command, target cleared
            add a, $2E
            ld c, a
            ld a, $5B
            call zpy
            xor a
            ld [hl+], a
            ld [hl+], a
            ld [hl], a
            call cmd_input                  ; -> A = 0 back, 1 chosen, 2 again from $52
            push af                         ; 34/99FD: and back once it is chosen (or cancelled)
            ld a, [BZ + $53]
            ld [BZ + $95], a
            call ba_stepb
            pop af
            and a
            jr z, .back
            cp 2
            jp z, .next
.skip:      ld hl, BZ + $52
            inc [hl]
            jr .next
.back:      call b_back
            jr .next
.done:      ld a, $FF
            ld [btl_hl], a
            ld b, $FF
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
cmd_input:  ld a, [opt_curm]                ; (Config's Cursor: Remember starts on the command the
            and a                           ;   member chose last, $7AC3 + member; Reset on Fight)
            jr nz, .c0
            ld a, [BZ + $52]
            ld e, a
            ld d, 0
            ld hl, W7 + $7AC3
            add hl, de
            ld a, [hl]
            cp 4
            jr c, .c1
.c0:        xor a
.c1:        ld [btl_cur], a
.l:         ld a, [btl_cur]                 ; the hand at the command's line (screen rows 13-16)
            add a, a
            add a, a
            add a, a
            add a, 104
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
            cp $14
            jp z, bitem_menu
            cp $15
            jp z, bmagic_menu
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
            call .tc
            push af
            xor a                           ; (35/A86C: $54 cleared)
            ld [BZ + $54], a
            pop af
            and a
            jp z, .l
            ret
.tc:        call tg_on
            call target_mon
            push af
            call tg_off
            pop af
            and a
            ret z
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
            call tg_on
            call target_sel
            push af
            call tg_off
            pop af
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

; HL = member $52's +$2C
atk_mem:    call chr_ofs
            add a, $2C
            ld c, a
            ld a, $5B
            jp zpy

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
            call tg_show
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
.n1:        push bc                         ; (the member's name in the left window; all: "All")
            ld a, [BZ + $B1]
            cp 5
            ld a, $F0
            jr z, .k
            ld a, b
            or $E0
.k:         call tg_key
            pop bc
            ld a, b                         ; member b: left of its sprite
            add a, a
            add a, b
            add a, a
            add a, a
            add a, a
            add a, low(oam_buf)
            ld l, a
            ld h, high(oam_buf)
            ld a, [hl+]                     ; (the finger at the member's middle: its top + 12)
            sub 16 - 9
            ld c, a
            ld a, [hl]
            sub 8 + 16
            ld b, a
            jp b_hand

; the target's window (the mock-up): while a command's target is chosen, the left window shows the
; monster's name and how many of its kind stand (all: FF3's "All"; a member: empty)
tg_on:      ld a, 1
            ld [btl_tw], a
            ld a, $FF
            ld [btl_tws], a
            ret
tg_off:     xor a
            ld [btl_tw], a
            jp cmd_win
tg_show:    ld a, [BZ + $B1]
            cp 1
            ld a, $F0
            jr z, tg_key
            ld a, [btl_tgt]
tg_key:     ld b, a
            ld a, [btl_tw]
            and a
            ret z
            ld a, [btl_tws]
            cp b
            ret z
            ld a, b
            ld [btl_tws], a
            push bc
            ld bc, $0000
            ld de, $0A06
            call w_box
            pop bc
            ld a, b
            cp $F0
            jr z, .all
            cp $E0
            jr c, .m
            and 3                           ; (a member)
            call name_of
            jr .put
.all:       ld a, b
            cp $F0
            jr nz, .m
            ld a, $36                       ; $0636 All
            ld b, 2
            call bstr
            jr .put
.m:         or $80
            call name_of
            ret nc
.put:       ld bc, $0101
            ld d, 10
            ld e, BVP_W
            ld hl, btl_str
            call bv_put
            ld a, [btl_tws]
            cp $E0
            ret nc
            ld e, a                         ; how many of its kind: $7ECD + slot = the kind,
            ld d, 0                         ;   $7DA7 + slot $FF: gone
            ld hl, W7 + $7ECD
            add hl, de
            ld b, [hl]
            ld c, 0
            ld e, 0
.k:         ld hl, W7 + $7DA7
            add hl, de
            ld a, [hl]
            cp $FF
            jr z, .kn
            ld hl, W7 + $7ECD
            add hl, de
            ld a, [hl]
            cp b
            jr nz, .kn
            inc c
.kn:        inc e
            ld a, e
            cp 8
            jr nz, .k
            ld hl, btl_str
            ld [hl], $BB                    ; "x"
            inc hl
            ld e, c
            ld d, 0
            call bnum
            ld [hl], 0
            ld bc, $0102
            ld d, 9
            ld e, BVP_L | BVF_R
            ld hl, btl_str
            jp bv_put

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
.k:         ld a, [BZ + $B1]                ; (one monster chosen: FF1's free targeting, the
            and a                           ;   nearest living one in the pressed direction)
            jr nz, .k0
            ld a, [BZ + $AD]
            and a
            jr z, .k0
            ld a, b
            and $F0
            jr z, .k0
            push bc
            call ts_free
            pop bc
            ret c
.k0:        ld a, b
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
; FF1's free targeting (owner): from the monster at the grid place ($AF, $B0), the nearest living
; one in direction A (R $10, L $20, U $40, D $80) by their centres on the screen (the distance
; along the direction + twice the distance across); carry and chosen (ts_mon) if there is one,
; else no carry and the place kept (FF3's own move follows: off the right edge, the party)
TF         = btl_spr                        ; (scratch: cx, cy, best place, score lo / hi, the
                                            ;   direction, the place kept, the place tried)
ts_free:    ld [TF + 5], a
            ld a, [BZ + $AF]
            ld b, a
            ld a, [BZ + $B0]
            and 1
            add a, a
            add a, a
            add a, b
            ld [TF + 6], a
            call ts_slot
            ld [btl_k], a
            call num_xy
            ld a, b
            ld [TF + 0], a
            ld a, c
            ld [TF + 1], a
            ld a, $FF
            ld [TF + 2], a
            ld [TF + 3], a
            ld [TF + 4], a
            xor a
.p:         ld [TF + 7], a
            ld b, a
            ld a, [TF + 6]
            cp b
            jr z, .nx
            ld a, b
            and 3
            ld [BZ + $AF], a
            ld a, b
            rrca
            rrca
            and 1
            ld [BZ + $B0], a
            call ts_ok
            jr nc, .nx
            call ts_slot
            ld [btl_k], a
            call num_xy                     ; B = x, C = y
            ld a, [TF + 0]                  ; D = |dx|, E = |dy|; H: bit 0 dx > 0, bit 1 dx < 0,
            ld h, 0                         ;   bit 2 dy > 0, bit 3 dy < 0
            ld l, a
            ld a, b
            sub l
            jr z, .x0
            jr c, .xn
            ld d, a
            set 0, h
            jr .y
.xn:        cpl
            inc a
            ld d, a
            set 1, h
            jr .y
.x0:        ld d, 0
.y:         ld a, [TF + 1]
            ld l, a
            ld a, c
            sub l
            jr z, .y0
            jr c, .yn
            ld e, a
            set 2, h
            jr .dir
.yn:        cpl
            inc a
            ld e, a
            set 3, h
            jr .dir
.y0:        ld e, 0
.dir:       ld a, [TF + 5]                  ; in the direction? the score: along + 2 across
            bit 4, a
            jr z, .d1
            bit 0, h
            jr z, .nx
            jr .sx
.d1:        bit 5, a
            jr z, .d2
            bit 1, h
            jr z, .nx
.sx:        ld l, d                         ; (horizontal: along dx, across dy)
            ld a, e
            jr .sc
.d2:        bit 6, a
            jr z, .d3
            bit 3, h
            jr z, .nx
            jr .sy
.d3:        bit 2, h
            jr z, .nx
.sy:        ld l, e                         ; (vertical: along dy, across dx)
            ld a, d
.sc:        ld h, 0                         ; HL = along + 2 across
            ld b, 0
            ld c, a
            add hl, bc
            add hl, bc
            ld a, [TF + 4]                  ; better than the best?
            cp h
            jr c, .nx
            jr nz, .nb
            ld a, [TF + 3]
            cp l
            jr c, .nx
            jr z, .nx
.nb:        ld a, l
            ld [TF + 3], a
            ld a, h
            ld [TF + 4], a
            ld a, [TF + 7]
            ld [TF + 2], a
.nx:        ld a, [TF + 7]
            inc a
            cp 8
            jr nz, .p
            ld a, [TF + 2]                  ; the best place
            cp $FF
            jr nz, .got
            ld a, [TF + 6]                  ; none that way (FF1): right, the party (FF3's
            call .set                       ;   move); up / down, the next living one in
            ld a, [TF + 5]                  ;   order; left, the place kept
            bit 4, a
            jr z, .nr
            call ts_chr
            scf
            ret
.nr:        and $C0
            jr z, .keep
            ld a, [TF + 6]
            ld [TF + 7], a
            ld b, 7
.cy:        push bc
            ld a, [TF + 5]
            bit 7, a
            ld a, [TF + 7]
            jr z, .cu
            inc a
            jr .cs
.cu:        dec a
.cs:        and 7
            ld [TF + 7], a
            call .set
            call ts_ok
            pop bc
            jr c, .cf
            dec b
            jr nz, .cy
            ld a, [TF + 6]
            call .set
.keep:      scf
            ret
.cf:        call ts_mon
            scf
            ret
.got:       call .set
            call ts_mon
            scf
            ret
.set:       ld b, a
            and 3
            ld [BZ + $AF], a
            ld a, b
            rrca
            rrca
            and 1
            ld [BZ + $B0], a
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
            add a, low(TB_SIZE)
            ld l, a
            ld h, high(TB_SIZE)
            call bd_rd                      ; width
            ld b, a
            call back_atk                   ; (a back attack: the mirrored columns)
            jr nz, .nb
            ld a, [btl_px]
            add a, b
            ld b, a
            ld a, 32
            sub b
            ld [btl_px], a
.nb:        call bd_rd                      ; height
            add a, a
            add a, a
            ld c, a
            ld a, [btl_py]
            sub 6
            add a, a
            add a, a
            add a, a
            add a, c
            sub 3                           ; (the finger, 3 lines into the hand, at the
            ld c, a                         ;   monster's middle: owner)
            ld a, [btl_px]
            add a, a
            add a, a
            add a, a
            call sub_scx16
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
section wram, $DF55                         ; (WRAM 3: after btlmsg.s's)
btl_tw:     ds 1                            ; the target's window on, the target it shows
btl_tws:    ds 1

section wram, $C33A                         ; (bank 0 WRAM: free after the wipe's)
btl_arep:   ds 1
bv_on:      ds 1                            ; (btlvwf.s: the small-font battle windows on,
bv_busy:    ds 1                            ;   being drawn, the staged blocks to send, the map
bv_dirty:   ds 1                            ;   to send, a caller's WRAM bank)
bv_map:     ds 1
bv_svk:     ds 1
