; The battle driver (FF3's main loop 34/8074 order), command input (ours, writing FF3's records
; as 34/986C does) and the presentation of FF3's action scripts (34/8FF7: windows, numerals,
; deaths). Bank B_BSCR with batscr.s.

section bank B_BSCR, $5800
; ---- FF3's battle main
bs_loop:
.turn:      call bs_t81c3                   ; (and the Invincible's cannon's damage)
            ld a, [$D8BA]
            and 1
            jr nz, .nm
            ld hl, fe_A732
            call alg_call
.nm:        call bs_t81a0                   ; (and the cannon's blast: Z when it won)
            jp z, .over
            call bs_input
            xor a
            ld [$DBE1], a
            %FAR B_BAT2, fe_8374
            ld a, [$D8BA]
            bit 7, a
            jr nz, .no
            %FAR B_BAT2, fe_8271
.no:        %FAR B_BAT2, fe_9777
            ld a, $FF
            ld [bs_act], a
            call bs_party
            call bs_hand_off
            %FAR B_BAT2, fe_82CE
            ld a, $FF
            ld hl, $D8CF
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl], a
.act:       %FAR B_BAT2, fe_8213
            call bs_pwin
            %FAR B_BAT2, fe_A458
            ld a, [$D8D3]
            and a
            jr nz, .over
            %FAR B_BAT2, fe_8295
            %FAR B_BAT2, fe_9DE4
            %FAR B_BAT2, fe_A56F
            ld hl, $DED8
            res 5, [hl]
            call bs_script
            ld hl, $DAC2
            inc [hl]
            ld a, [hl]
            cp $0C
            jr z, .end
            ld c, a
            ld hl, $DACB
            call bs_hl_c
            ld a, [hl]
            cp $FF
            jr nz, .act
.end:       ld a, [$D8D3]
            and 2
            jr nz, .ov
            %FAR B_BAT2, fe_BA41
.ov:        %FAR B_BAT2, fe_A458
            ld a, [$D8D3]
            and a
            jr nz, .over
            ld hl, $D8BA
            ld a, [hl]
            and 8
            ld [hl], a
            jp .turn
.over:      call bs_pwin
            ld a, [$D8D3]
            and 2
            jr nz, .esc
            ld a, 2
            ld [$DEC2], a
            ld [$D8D5], a
            ld a, [$D8D3]
            bit 7, a
            ld a, $1C                       ; "Wiped out..."
            jr nz, .m
            ld a, $1D                       ; "The enemies were wiped out!"
.m:         ld [$D8DA], a
            call bs_script
            ld a, [$D8D3]
            bit 7, a
            jp nz, bs_gameover
            %FAR B_BAT2, fe_BB49
.esc:       %FAR B_BAT2, fe_8306
            ld a, [$D8BA]
            and 8
            jr z, .r
            %FAR B_BAT2, fe_88A4
.r:         ld hl, fe_BEBF
            jp alg_call

; defeat: FF3 starts the program again
bs_gameover:
            ld b, 120
.w:         push bc
            call bs_frame
            pop bc
            dec b
            jr nz, .w
            jp soft_reset

bs_hl_c:    ld a, l
            add c
            ld l, a
            ret nc
            inc h
            ret

; ---- command input (34/986C: each character who can act chooses)
bs_input:   xor a
            ld [BZ + $52], a
.next:      ld a, [BZ + $52]
            cp 4
            ret z
            ld b, a
            ld a, [$DBE1]
            call b_clrbit
            ld [$DBE1], a
            call bs_crec                    ; HL = the record
            push hl
            inc hl
            inc hl
            bit 0, [hl]                     ; jumping: keeps its target
            pop hl
            ld a, [BZ + $52]
            ld e, a
            ld d, 0
            jr z, .nj
            push hl
            ld bc, $2F
            add hl, bc
            ld a, [hl]
            ld hl, $DE0F
            add hl, de
            ld [hl], a
            pop hl
            jr .c
.nj:        push hl
            ld hl, $D8CF
            add hl, de
            ld [hl], $FF
            ld hl, $DE0F
            add hl, de
            ld [hl], 0
            pop hl
.c:         call bs_pwin
            call bs_anyone
            ret z
            ld a, [BZ + $52]                ; defence back
            ld e, a
            ld d, 0
            push hl
            ld hl, $DCE4
            add hl, de
            ld a, [hl]
            and a
            jr z, .d
            ld [hl], 0
            pop hl
            push hl
            ld bc, $23
            add hl, bc
            ld [hl], a
.d:         pop hl
            inc hl
            ld a, [hl+]
            and $C0
            jr z, .alive
            ld hl, BZ + $52
            inc [hl]
            ld hl, $DCEB
            inc [hl]
            jr .next
.alive:     ld a, [hl]
            and $E0
            jr z, .act
            bit 5, [hl]                     ; confused: a random fight; asleep / paralysed
            jr z, .slp
            ld hl, fe_BF17
            call alg_call
            jr .inc
.slp:       call bs_crec
            ld bc, $2E
            add hl, bc
            ld [hl], 1
.inc:       ld hl, BZ + $52
            inc [hl]
            jr .next
.act:       bit 0, [hl]
            jr nz, .inc
            call bs_crec                    ; command, targets cleared; an item in use back
            ld bc, $2C
            add hl, bc
            res 3, [hl]
            inc hl
            inc hl
            xor a
            ld [hl+], a
            ld [hl+], a
            ld [hl], a
            call bs_crec
            ld bc, $3F
            add hl, bc
            ld a, [hl]
            and a
            jr z, .ni
            push af
            call b_choff
            pop af
            %FAR B_BAT2, fe_9AE7_a
.ni:        ld a, [$D8BA]                   ; ambushed: nobody chooses
            bit 7, a
            ret nz
            ld a, [BZ + $52]                ; step forward, the command window
            ld [bs_act], a
            call bs_party
            call bs_cmds
            jp .next

; Z set when no character from [$52] on can act (34/A433: status for display $78BB & $F8)
bs_anyone:  ld a, [BZ + $52]
            ld c, a
.c:         ld a, c
            cp 4
            jr z, .none
            add a
            ld hl, $D8BB
            call bs_hl_a
            ld a, [hl]
            and $F8
            jr z, .yes
            inc c
            jr .c
.none:      xor a
            ret
.yes:       or 1
            ret
; HL = character [$52]'s record
bs_crec:    ld a, [BZ + $52]
            jp bs_rec

; ---- the command window: FF3's four commands of the job; left / right twice: row change
bs_cmds:    call b_choff                    ; the job's commands -> bs_cl
            ld c, a
            call p57
            ld a, [hl]
            add a
            add a
            ld hl, job_cmds
            call bs_hl_a
            ld de, bs_cl
            ld b, 4
.cp:        ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .cp
            ld de, $0C0A                    ; window (12, 10) 6 x 10
            ld bc, $060A
            call bs_win
            ld c, 0
.n:         push bc
            ld a, c
            ld hl, bs_cl
            call bs_hl_a
            ld a, [hl]
            cp $FF
            jr z, .sk
            add low($220)                   ; names8800 $220 + command
            ld e, a
            ld a, high($220)
            adc 0
            ld d, a
            call bs_name
            pop bc
            push bc
            ld a, c
            add 13
            ld d, a
            ld e, 12
            ld a, 7
            ld [bs_maxw], a
            call bs_putsn
.sk:        pop bc
            inc c
            ld a, c
            cp 4
            jr nz, .n
            xor a
            ld [bs_cur], a
            ld [bs_lr], a
.loop:      ld a, [bs_cur]                  ; the hand at (13 + cursor, 11)
            add 13
            ld b, a
            ld c, 11
            call bs_hand_cell
            call bs_frame
            ldh a, [pad_new]
            bit 0, a
            jr nz, .ok
            bit 1, a
            jr nz, .back
            bit 6, a
            jr nz, .up
            bit 7, a
            jr nz, .dn
            bit 5, a
            jr nz, .lt
            bit 4, a
            jr nz, .rt
            jr .loop
.up:        ld a, [bs_cur]
            dec a
            and 3
            ld [bs_cur], a
            xor a
            ld [bs_lr], a
            jr .loop
.dn:        ld a, [bs_cur]
            inc a
            and 3
            ld [bs_cur], a
            xor a
            ld [bs_lr], a
            jr .loop
.lt:        ld a, [bs_lr]                   ; twice left: front row (back row in a back attack)
            cp $20
            ld a, $20
            ld [bs_lr], a
            jr nz, .loop
            ld a, [$D8BA]
            and 8
            ld a, 4
            jr z, .row
            inc a
            jr .row
.rt:        ld a, [bs_lr]
            cp $10
            ld a, $10
            ld [bs_lr], a
            jr nz, .loop
            ld a, [$D8BA]
            and 8
            ld a, 5
            jr z, .row
            dec a
.row:       ld [bs_slot], a
            add -2                          ; command 2 / 3: front / back row
            jr .cmd
.back:      call bs_hand_off                ; B: the previous character
            call bs_close_cmd
            ld a, [BZ + $52]
            and a
            ret z
.pv:        ld hl, BZ + $52
            dec [hl]
            call bs_crec
            inc hl
            inc hl
            bit 0, [hl]
            jr nz, .pv2
            ld a, [BZ + $52]
            add a
            ld hl, $D8BB
            call bs_hl_a
            ld a, [hl]
            and $F8
            ret z
.pv2:       ld a, [BZ + $52]
            and a
            jr nz, .pv
            ret
.ok:        ld a, [bs_cur]
            ld [bs_slot], a
            ld hl, bs_cl
            call bs_hl_a
            ld a, [hl]
.cmd:       ld [bs_cmd], a
            call bs_hand_off
            ld a, [BZ + $52]                ; $7AC3 slot, $78CF command
            ld e, a
            ld d, 0
            ld hl, $DAC3
            add hl, de
            ld a, [bs_slot]
            ld [hl], a
            ld hl, $D8CF
            add hl, de
            ld a, [bs_cmd]
            ld [hl], a
            call bs_do
            call bs_close_cmd
            ret
bs_close_cmd:
            ld a, $FF
            ld [bs_act], a
            call bs_party
            jp bs_pwin

; a command: its record (34/9A16); [$52] moves on when it is chosen
bs_do:      ld a, [bs_cmd]
            cp 2
            jr z, .act                      ; rows: the action itself
            cp 3
            jr z, .act
            cp 5
            jr z, .act
            cp 6
            jr z, .act
            cp 7
            jr z, .act
            cp $0F
            jr z, .act
            cp $11
            jr z, .act
            cp $12
            jr z, .act
            cp $14
            jp z, bs_item
            cp $15
            jp z, bs_magic
            cp 4
            jr z, .tg
            cp 8
            jr z, .tgm
            cp $0C
            jr z, .tg
            cp $0D
            jr z, .tg
            cp $0E
            jr z, .tg
            cp $10
            jr z, .tg
            cp $0B
            jr z, .terr
            ret                             ; (none)
.act:       call bs_crec
            ld bc, $2E
            add hl, bc
            ld a, [bs_cmd]
            ld [hl], a
            jr .nx
.tgm:       xor a                           ; jump: a monster only
            ld [BZ + $B3], a
            call bs_target
            ld a, [BZ + $B4]
            and a
            ret z
            ld a, [BZ + $B5]
            bit 7, a
            jr z, .tgm
            jr .set
.tg:        xor a
            ld [BZ + $B3], a
            call bs_target
            ld a, [BZ + $B4]
            and a
            ret z
.set:       call bs_crec
            ld bc, $2E
            add hl, bc
            ld a, [bs_cmd]
            ld [hl+], a
            ld a, [BZ + $B4]
            ld [hl+], a
            ld a, [BZ + $B5]
            ld [hl], a
.nx:        ld hl, BZ + $52
            inc [hl]
            ret
.terr:      call bs_crec                    ; terrain: FF3's random monster or all (35/AA22)
            ld bc, $2E
            add hl, bc
            ld [hl], $0B
            call b_choff
            %FAR B_BAT2, fe_AAC3_t
            ld a, [bs_t]
            ld b, a
            call bs_crec
            ld de, $2F
            add hl, de
            ld a, [bs_n]
            ld [hl+], a
            ld [hl], b
            jr .nx

; ---- choose targets (FF3's battle graphics $10): [$B3] bit 0 all allowed, bit 1 allies first;
; [$B4] = the mask (0: cancelled), [$B5] $80 monsters, + $40 all
bs_target:  ld a, [BZ + $B3]
            and 2
            ld a, 0
            jr nz, .s
            ld a, $80
.s:         ld [bs_side], a
            xor a
            ld [bs_all], a
            ld a, $FF
            ld [bs_sel], a
            call bs_tnext
.loop:      call bs_thand
            call bs_frame
            ldh a, [pad_new]
            bit 0, a
            jr nz, .ok
            bit 1, a
            jr nz, .cancel
            bit 2, a
            jr nz, .all
            bit 6, a
            jr nz, .prev
            bit 7, a
            jr nz, .nx
            and $30
            jr z, .loop
            ld a, [bs_side]                 ; left / right: the other side
            xor $80
            ld [bs_side], a
            xor a
            ld [bs_all], a
            ld a, $FF
            ld [bs_sel], a
            call bs_tnext
            jr .loop
.nx:        call bs_tnext
            jr .loop
.prev:      ld b, 8
.p:         push bc
            call bs_tnext
            pop bc
            dec b
            jr nz, .p
            jr .loop
.all:       ld a, [BZ + $B3]
            and 1
            jr z, .loop
            ld a, [bs_all]
            xor 1
            ld [bs_all], a
            jr .loop
.cancel:    xor a
            ld [BZ + $B4], a
            jp bs_hand_off
.ok:        call bs_hand_off
            ld a, [bs_all]
            and a
            jr nz, .ma
            ld a, [bs_sel]
            ld b, a
            xor a
            call b_setbit
            ld [BZ + $B4], a
            ld a, [bs_side]
            ld [BZ + $B5], a
            ret
.ma:        ld a, [bs_side]                 ; all: the living ones
            or $40
            ld [BZ + $B5], a
            ld c, 0
            ld b, 0
.am:        push bc
            ld a, c
            call bs_tok
            pop bc
            jr z, .an
            push bc
            ld a, b
            ld b, c
            call b_setbit
            pop bc
            ld b, a
.an:        inc c
            ld a, c
            cp 8
            jr nz, .am
            ld a, b
            ld [BZ + $B4], a
            ret
; the next selectable target after bs_sel on bs_side
bs_tnext:   ld b, 9
.l:         ld a, [bs_sel]
            inc a
            and 7
            ld [bs_sel], a
            call bs_tok
            ret nz
            dec b
            jr nz, .l
            ret
; NZ when slot A on bs_side can be chosen
bs_tok:     ld c, a
            ld a, [bs_side]
            and a
            jr z, .ch
            ld a, c
            ld hl, $DDA7
            call bs_hl_a
            ld a, [hl]
            cp $FF
            jr z, .no
            ld a, c
            rrca                            ; (HL = B_MO + 1 + 64 A: the carry kept)
            rrca
            ld l, a
            and $C0
            ld e, a
            ld a, l
            and 3
            ld d, a
            ld hl, B_MO + 1
            add hl, de
            ld a, [hl]
            and $C0
            jr nz, .no
            or 1
            ret
.ch:        ld a, c
            cp 4
            jr nc, .no
            or 1
            ret
.no:        xor a
            ret
; the hand by the target (or at the first, all)
bs_thand:   ld a, [bs_side]
            and a
            ld a, [bs_sel]
            jr z, .ch
            call bs_mpos                    ; monster: its position
            ld a, [bs_y]
            add a
            add a
            add a
            add 16 + 4
            ld b, a
            ld a, [bs_x]
            add a
            add a
            add a
            ld c, a
            jr .s
.ch:        add a
            add a
            add a
            ld b, a
            add a
            add b
            add 16 + 4
            ld b, a
            ld c, 144 + 8 - 18
.s:         ld a, c                         ; (the 16 x 16 hand: its right half where the old
            sub 8                           ;   8 x 8 one was)
            ld c, a
            ld a, b
            sub 4
            ld b, a
            ld hl, oam_buf + 4 * 36
            jp hand16
; bs_x / bs_y (tiles) of monster slot A
bs_mpos:    ld b, a
            add a
            add b
            ld hl, bs_pos
            call bs_hl_a
            ld a, [hl+]
            sub 2
            ld [bs_x], a
            ld a, [hl]
            sub 6
            ld [bs_y], a
            ret
; the hand at BG row B, column C
bs_hand_cell:
            ld a, b
            add a
            add a
            add a
            add 16 - 2
            ld b, a
            ld a, c
            add a
            add a
            add a
            ld c, a
            ld hl, oam_buf + 4 * 36
            jp hand16
bs_hand_off:
            ld hl, oam_buf + 4 * 36
            jp hand16off

; ---- magic (35/B646): levels with mp, three spells each; FF3's job check and targets
bs_magic:   ld a, [$DED8]
            and $40
            ret nz
            call b_choff
            ld c, a
            ld a, [BZ + $5F]                ; the highest level with max mp
            add $3F
            ld c, a
            call p57
            ld b, 7
.h:         ld a, [hl]
            and a
            jr nz, .hf
            dec hl
            dec hl
            dec b
            bit 7, b
            jr z, .h
            ret
.hf:        ld a, b
            ld [bs_lvmax], a
            ld [bs_lv], a
            xor a
            ld [bs_cur], a
.draw:      call bs_mlist
.loop:      ld a, [bs_cur]                  ; hand at row 14, column 1 + 6 x cursor
            ld b, a
            add a
            add b
            add a
            inc a
            ld c, a
            ld b, 14
            call bs_hand_cell
            call bs_frame
            ldh a, [pad_new]
            bit 0, a
            jr nz, .ok
            bit 1, a
            jr nz, .x
            bit 6, a
            jr nz, .up
            bit 7, a
            jr nz, .dn
            bit 5, a
            jr nz, .lt
            bit 4, a
            jr nz, .rt
            jr .loop
.up:        ld a, [bs_lv]
            ld hl, bs_lvmax
            cp [hl]
            jr z, .loop
            inc a
            ld [bs_lv], a
            jr .draw
.dn:        ld a, [bs_lv]
            and a
            jr z, .loop
            dec a
            ld [bs_lv], a
            jr .draw
.lt:        ld a, [bs_cur]
            and a
            jr z, .loop
            dec a
            ld [bs_cur], a
            jr .loop
.rt:        ld a, [bs_cur]
            cp 2
            jr z, .loop
            inc a
            ld [bs_cur], a
            jr .loop
.x:         call bs_hand_off
            ret
.ok:        ld a, [bs_cur]                  ; the spell
            ld hl, bs_sp
            call bs_hl_a
            ld a, [hl]
            cp $FF
            jr z, .loop
            ld [bs_spell], a
            call bs_crec                    ; mp of the level
            ld a, [bs_lv]
            add 7
            call bs_hl_a
            ld a, [hl]
            and a
            jr z, .loop
            ld a, [bs_spell]                ; the job can cast it (35/B8FD)?
            call bs_canuse
            jr z, .loop
            ld a, [bs_ap + 5]               ; targets (35/B953)
            and $18
            jr z, .ok2                      ; (summons: none chosen)
            ld a, [bs_ap + 5]
            and $40
            jr nz, .allm
            ld a, [bs_ap + 5]
            and $20
            ld a, 0
            jr nz, .m1
            inc a
.m1:        ld b, a
            ld a, [bs_ap + 5]
            bit 7, a
            jr z, .m2
            set 1, b
.m2:        ld a, b
            ld [BZ + $B3], a
            call bs_hand_off
            call bs_target
            ld a, [BZ + $B4]
            and a
            jp z, .draw
            call bs_crec
            ld bc, $2F
            add hl, bc
            ld a, [BZ + $B4]
            ld [hl+], a
            ld a, [BZ + $B5]
            ld [hl], a
            jr .ok2
.allm:      ld c, 0                         ; all living monsters, no split
            ld b, 0
.al:        push bc
            ld a, $80
            ld [bs_side], a
            ld a, c
            call bs_tok
            pop bc
            jr z, .an
            push bc
            ld a, b
            ld b, c
            call b_setbit
            pop bc
            ld b, a
.an:        inc c
            ld a, c
            cp 8
            jr nz, .al
            call bs_crec
            ld de, $2F
            add hl, de
            ld [hl], b
            inc hl
            ld [hl], $C0
.ok2:       call bs_hand_off
            ld a, [BZ + $52]
            ld e, a
            ld d, 0
            ld hl, $DAC7
            add hl, de
            ld a, [bs_lv]
            ld [hl], a
            ld a, [bs_spell]
            add $C8
            ld hl, $D8CF
            add hl, de
            ld [hl], a
            push af
            call bs_crec
            ld bc, $2E
            add hl, bc
            pop af
            ld [hl], a
            ld hl, BZ + $52
            inc [hl]
            ret
; the list of level bs_lv: "L8  spell spell spell  mp/max" in the bottom window
bs_mlist:   ld de, $0C00
            ld bc, $0614
            call bs_win
            ld de, $0D01
            ld a, 'L'
            call bs_putc
            inc e
            ld a, [bs_lv]
            add '1'
            call bs_putc
            ld e, 9                         ; mp / max
            call bs_crec
            ld a, [bs_lv]
            add 7
            call bs_hl_a
            ld l, [hl]
            ld h, 0
            push de
            call bs_dec
            pop de
            ld hl, bs_numb + 2
            ld a, [hl+]
            call bs_putc
            inc e
            ld a, [hl]
            call bs_putc
            inc e
            ld a, '/'
            call bs_putc
            inc e
            call b_choff
            ld b, a
            ld a, [bs_lv]
            add a
            add $31
            add b
            ld c, a
            push de
            call p57
            ld l, [hl]
            ld h, 0
            call bs_dec
            pop de
            ld hl, bs_numb + 2
            ld a, [hl+]
            call bs_putc
            inc e
            ld a, [hl]
            call bs_putc
            ld a, $FF                       ; the known spells of the level (save +7 + level)
            ld [bs_sp], a
            ld [bs_sp + 1], a
            ld [bs_sp + 2], a
            call b_choff
            add 7
            ld b, a
            ld a, [bs_lv]
            add b
            ld c, a
            call p59
            ld a, [hl]
            ld [bs_bits], a
            ld a, 7                         ; first id: 7 x (7 - level)
            ld hl, bs_lv
            sub [hl]
            ld b, a
            add a
            add a
            add a
            sub b
            ld c, a
            ld b, 0                         ; slot
            ld e, 7
.s:         ld hl, bs_bits
            srl [hl]
            jr nc, .n
            ld a, b
            cp 3
            jr nc, .n
            push hl
            ld hl, bs_sp
            call bs_hl_a
            ld [hl], c
            pop hl
            inc b
.n:         inc c
            dec e
            jr nz, .s
            ld c, 0
.w:         push bc                         ; names at row 14, columns 2 / 8 / 14
            ld a, c
            ld hl, bs_sp
            call bs_hl_a
            ld a, [hl]
            cp $FF
            jr z, .ws
            add $C8
            ld e, a
            ld d, 0
            call bs_name
            pop bc
            push bc
            ld a, c
            ld b, a
            add a
            add b
            add a
            add 2
            ld e, a
            ld d, 14
            ld a, 5
            ld [bs_maxw], a
            call bs_putsn
.ws:        pop bc
            inc c
            ld a, c
            cp 3
            jr nz, .w
            ret
; NZ when character [$52]'s job can use spell / item A (35/B8FD); its properties -> bs_ap
bs_canuse:  ld l, a                         ; attack properties 30/98C0 + 8 A
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, $98C0 - $4000
            add hl, de
            ld de, bs_ap
            ld bc, 8
            ld a, B_BDAT
            call far_copy
.k:         ld a, [bs_ap + 7]
            and $7F
            ld b, a
            add a
            add b
            ld hl, eq_types
            call bs_hl_a
            ld de, bs_eq
            ld b, 3
.c:         ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .c
            call b_choff                    ; the job's bit (24 bits, job 0 = bit 0 of the last)
            ld c, a
            call p57
            ld a, [hl]
            inc a
            ld b, a
            xor a
            ld [bs_jb], a
            ld [bs_jb + 1], a
            ld [bs_jb + 2], a
            scf
.j:         ld hl, bs_jb + 2
            rl [hl]
            dec l
            rl [hl]
            dec l
            rl [hl]
            and a
            dec b
            jr nz, .j
            ld hl, bs_eq
            ld de, bs_jb
            ld b, 3
.t:         ld a, [de]
            and [hl]
            ret nz
            inc hl
            inc de
            dec b
            jr nz, .t
            ret

; ---- strings: bs_name: names8800 entry DE -> BS_STR (0 end); bs_putsn: BS_STR at (D, E), at
; most [bs_maxw] characters
bs_name:    ld hl, T_NAMES8800
bs_namet:   add hl, de
            add hl, de
            add hl, de
            push hl
            ld de, bs_tmp
            ld bc, 3
            ld a, B_TEXT
            call far_copy
            pop hl
            ld a, [bs_tmp + 1]
            ld l, a
            ld a, [bs_tmp + 2]
            ld h, a
            ld de, BS_STR
            ld bc, 32
            ld a, [bs_tmp]
            call far_copy
bs_term:    ld hl, BS_STR                   ; (end at a 0 or a new line)
            ld b, 31
.e:         ld a, [hl]
            and a
            ret z
            cp $0A
            jr z, .z
            cp $0C
            jr z, .z
            inc hl
            dec b
            jr nz, .e
.z:         ld [hl], 0
            ret
bs_putsn:   ld hl, BS_STR
            ld a, [bs_maxw]
            ld b, a
.c:         ld a, [hl+]
            and a
            ret z
            cp $18                          ; (codes below: none to show; $18 up: icons)
            jr c, .c
            push bc
            push hl
            call bs_putc
            pop hl
            pop bc
            inc e
            dec b
            jr nz, .c
            ret

; ---- FF3's action script (34/8FF7) on our screen
bs_script:  ld a, [$DEC2]
            and a
            ret z
            ld a, [$D8D5]
            cp 6
            ret nc
            add a
            ld hl, bs_scripts
            call bs_hl_a
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld a, l
            ld [bs_scp], a
            ld a, h
            ld [bs_scp + 1], a
            xor a
            ld [BZ + $64], a
            ld [$D8EE], a
            ld [$D8EF], a
.c:         ld a, [bs_scp]
            ld l, a
            ld a, [bs_scp + 1]
            ld h, a
            ld a, [BZ + $64]
            call bs_hl_a
            ld a, [hl]
            cp $FF
            jr z, .end
            add a
            ld hl, bs_scmds
            call bs_hl_a
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            call .go
            ld hl, BZ + $64
            inc [hl]
            jr .c
.end:       xor a
            ld [bs_topon], a
            call bs_topoff
            jp bs_pwin
.go:        jp hl
bs_scripts: dw .s0, .s1, .s2, .s3, .s4, .s5
.s0:        db $05, $07, $0B, $06, $0C, $08, $0D, $09, $0A, $04, $03, $01, $02, $00, $FF
.s1:        db $05, $06, $07, $0B, $0C, $08, $09, $0D, $0A, $04, $03, $02, $01, $00, $FF
.s2:        db $09, $0A, $04, $FF
.s3:        db $09, $0B, $0C, $0E, $0A, $04, $FF
.s4:        db $05, $09, $0A, $04, $00, $FF
.s5:        db $09, $0C, $0A, $04, $FF
bs_scmds:   dw bsc_none, bsc_none, bsc_none, bsc_more, bsc_close, bsc_who, bsc_what, bsc_whom
            dw bsc_stat, bsc_msg, bsc_wait, bsc_anim, bsc_nums, bsc_death, bsc_cdie
bsc_none:   ret

; $03: more messages in the queue: back to the message command
bsc_more:   call msg_at
            ld a, [hl]
            cp $FF
            ret z
            ld a, [$D8D5]
            and a
            ld a, 4
            jr z, .b
            inc a
.b:         ld hl, BZ + $64
            ld b, a
            ld a, [hl]
            sub b
            ld [hl], a
            ret
; $04: the bottom window back to the party
bsc_close:  jp bs_pwin
; the top window, once per script
bs_topwin:  push af
            ld a, [bs_topon]
            and a
            jr nz, .x
            inc a
            ld [bs_topon], a
            call bs_top
.x:         pop af
            ret
; $05 attacker name (top window, line 1)
bsc_who:    call bs_topwin
            ld a, [$D8D6]
            ld de, $0101
            jp bs_actor
; $07 target name (line 2); $88: all
bsc_whom:   call bs_topwin
            ld a, [$D8D8]
            ld de, $0201
            cp $88
            jp nz, bs_actor
            ld de, $0220 + $16
            call bs_name
            ld de, $0201
            ld a, 9
            ld [bs_maxw], a
            jp bs_putsn
; an actor's name A ($FF none, $80 + slot a monster, else a character) at (D, E)
bs_actor:   cp $FF
            ret z
            push de
            bit 7, a
            jr z, .ch
            and 7
            ld hl, $DECD                    ; slot -> type -> monster id -> names $120 + id
            call bs_hl_a
            ld a, [hl]
            ld hl, $DD6B
            call bs_hl_a
            ld a, [hl]
            cp $FF
            jr z, .x
            add low($120)
            ld e, a
            ld a, high($120)
            adc 0
            ld d, a
            call bs_name
            pop de
            ld a, 9
            ld [bs_maxw], a
            jp bs_putsn
.ch:        call bs_choff                   ; a character: 6 letters from the save page +6
            add 6
            ld l, a
            ld h, $D1
            pop de
            ld b, 6
.c:         ld a, [hl+]
            push hl
            push bc
            call bs_ff3char
            call bs_putc
            pop bc
            pop hl
            inc e
            dec b
            jr nz, .c
            ret
.x:         pop de
            ret
; $06 the attack: an item's name, a spell, hits, Miss, a summon, a message (line 1, right)
bsc_what:   call bs_topwin
            ld a, [BZ + $72]
            and a
            jr z, .n
            ld a, [$D8D7]                   ; an item
            ld e, a
            ld d, 0
            jr .nm
.n:         ld a, [$D8D7]
            cp $FF
            ret z
            bit 7, a
            jr nz, .sp
            and a
            jr z, .miss
            cp $21
            jr c, .hits
            cp $39
            jr c, .sum
            cp $52
            jr c, .bm
            sub $46                         ; status messages (t8200)
            ld e, a
            jp bs_t82
.sp:        and $7F                         ; a spell: names $C8 + id
            add $C8
            ld e, a
            ld a, 0
            adc 0
            ld d, a
            jr .nm
.sum:       add $C6                         ; a summon's name: monster names (FF3's id wraps)
            add low($120)
            ld e, a
            ld a, high($120)
            adc 0
            ld d, a
            jr .nm
.bm:        sub $39
            jr .bmn
.miss:      ld a, 9
.bmn:       add low($220)
            ld e, a
            ld a, high($220)
            adc 0
            ld d, a
.nm:        call bs_name
            ld de, $010A
            ld a, 7
            ld [bs_maxw], a
            jp bs_putsn
.hits:      ld l, a                         ; "n hits"
            ld h, 0
            push hl
            ld de, $0220 + $13
            call bs_name
            pop hl
            call bs_dec                     ; two digits at (1, 10), the word at (1, 13)
            ld de, $010A
            ld a, [bs_numb + 2]
            call bs_putc
            inc e
            ld a, [bs_numb + 3]
            call bs_putc
            ld a, 4
            ld [bs_maxw], a
            ld de, $010D
            jp bs_putsn
; $08 the status message (line 2, right): t8200 $0C + n
bsc_stat:   ld a, [$D8D9]
            cp $FF
            ret z
            call bs_topwin
            add $0C
            ld e, a
bs_t82:     ld d, 0                         ; t8200 entry E at (2, 10)
            ld hl, T_T8200
            add hl, de
            add hl, de
            add hl, de
            call bs_tget
            ld de, $020A
            ld a, 7
            ld [bs_maxw], a
            jp bs_putsn
; a text index entry at HL (B_TEXT) -> BS_STR
bs_tget:    push hl
            ld de, bs_tmp
            ld bc, 3
            ld a, B_TEXT
            call far_copy
            pop hl
            ld a, [bs_tmp + 1]
            ld l, a
            ld a, [bs_tmp + 2]
            ld h, a
            ld de, BS_STR
            ld bc, 32
            ld a, [bs_tmp]
            call far_copy
            jp bs_term
; $09 the battle message queue's message (the bottom window)
bsc_msg:    call msg_at
            ld a, [hl]
            cp $FF
            ret z
            ld [bs_msg], a
            ld de, $0C00
            ld bc, $0614
            call bs_win
            ld a, [bs_msg]                  ; its variable type (34/9575)
            srl a
            ld hl, msg_vars
            call bs_hl_a
            ld a, [hl]
            ld b, a
            ld a, [bs_msg]
            and 1
            ld a, b
            jr nz, .lo
            swap a
.lo:        and 15
            ld [bs_var], a
            ld e, 1
            cp 3
            jr nz, .nn
            ld a, [$D8EF]                   ; a number first
            ld hl, $D8E4
            call bs_hl_a
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld d, 14
            call bs_num4
            ld hl, $D8EF
            inc [hl]
            inc [hl]
.nn:        ld a, [bs_var]
            cp 4
            jr nz, .ni
            push de                         ; an item's name first
            ld a, [$D8E4]
            ld e, a
            ld d, 0
            call bs_name
            pop de
            ld d, 14
            ld a, 12
            ld [bs_maxw], a
            call bs_putsn
            inc e
.ni:        ld a, [bs_var]
            cp 2
            jr z, .hp
            push de
            ld a, [bs_msg]
            add low($220)
            ld e, a
            ld a, high($220)
            adc 0
            ld d, a
            call bs_name
            pop de
            ld d, 14
            ld a, 19
            sub e
            ld [bs_maxw], a
            call bs_putsw                   ; (wrapped: the English is longer than FF3's)
            jr .w
.hp:        ld de, $0E01                    ; peep: "HP cur/max"
            ld a, 'H'
            call bs_putc
            inc e
            ld a, 'P'
            call bs_putc
            ld e, 4
            ld hl, $D8E4
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            call bs_num4
            ld a, '/'
            call bs_putc
            inc e
            ld hl, $D8E6
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            call bs_num4
.w:         ld a, [bs_var]
            and a
            jr z, .x
            call bsc_wait                   ; (types 1-4 wait for A themselves)
.x:         ld hl, $D8EE
            inc [hl]
            ret
; $0A wait: 40 frames or A
bsc_wait:   ld a, [$D010]                   ; FF3's 34/9450: (8 - message speed) x 8 frames
            ld b, a
            ld a, 8
            sub b
            add a
            add a
            add a
            ld b, a
            and a
            ret z
.w:         push bc
            call bs_frame
            pop bc
            ldh a, [pad_new]
            and 1
            ret nz
            dec b
            jr nz, .w
            ret
; $0B the action: the acting member steps forward
bsc_anim:   call ui_kind                    ; (the Invincible's cannon: 34/84F6, 32/84C9)
            cp $0C
            jr nz, .nc
            ld hl, an_cannon
            jp xa_go
.nc:        ld a, [$D8D6]
            cp 4
            jr c, .ch
            and 7                           ; a monster: FF3's pre-attack flash (34/8545)
            call bs_flash
            call ui_kind                    ; its fight on a member: the member hit (34/8637);
            cp $0D                          ;   its magic: the spell's hit (2F/B15E); running
            jr z, .run                      ;   away: those that got away wiped (34/84E6, 2F/BB5E)
            cp 1
            jr nz, .mf
            call xa_mmon
            jr .m
.mf:        and a
            jr nz, .m
            ld a, [$DE9A]
            bit 6, a
            jr nz, .m
            call xa_chit
            jr .m
.ch:        call ui_kind                    ; a character's fight on a monster: its swings
            cp 1                            ;   (34/8613, battle graphics $12); magic: its
            jp z, xa_magic                  ;   casting (34/8577, $1D); the others (34/843E)
            cp 2                            ; (a summon)
            jr z, .kg
            cp 6
            jr c, .k0
            cp $11
            jr nc, .k0
            cp $0C                          ; (cannon: bsc_anim's own; $0E / $0F: the
            jr z, .st                       ;   deaths' and numbers' own commands)
            cp $0E
            jr nc, .k1
.kg:        ld [an_kk], a
            ld hl, an_kinds
            jp xa_go
.k1:        cp $10
            jr z, .kg
            jr .st
.k0:        and a
            jr nz, .st
            ld a, [$DE9A]
            bit 6, a
            jp nz, xa_fight
.st:        ld a, [$D8D6]
            ld [bs_act], a
            call bs_party
.m:         ld b, 12
.w:         push bc
            call bs_frame
            pop bc
            dec b
            jr nz, .w
            ld a, $FF
            ld [bs_act], a
            jp bs_party
; (monsters getting away: wiped, their slots cleared: 2F/BAA2)
.run:       ld a, [$D8D4]
            and a
            jp z, .m
            call bs_mwipe
            ld a, [$D8D4]
            ld b, 0
.rc:        add a
            push af
            jr nc, .rn
            ld a, b
            ld hl, $DDA7
            call bs_hl_a
            ld [hl], $FF
.rn:        pop af
            inc b
            ld c, a
            ld a, b
            cp 8
            ld a, c
            jr nz, .rc
            %FAR B_BAT2, fe_B909
            call bs_draw
            jp .m
; the animation bank's routines (B_BANIM)
xa_mmon:    ld hl, an_mmon
xa_go:      ld a, B_BANIM
            jp far_call
xa_chit:    ld hl, an_chit
            jr xa_go
xa_magic:   ld hl, an_magic
            jr xa_go
xa_fight:   ld hl, an_fight
            jr xa_go
; the action's animation kind (34/83F8)
ui_kind:    call an_kind
            ret
an_kind:    ld a, [$DEC2]
            ld hl, an_ids
            call bs_hl_a
            ld a, B_BANIM
            jp far_byte
; bs_srect for the animation bank: its carry in an_src
bs_srectx:  call bs_srect
            sbc a
            ld [an_src], a
            ret
; $0C damage numerals: targets ($7E4F) and attackers ($7E5F), three at a time, 32 frames
bsc_nums:   xor a
            ld [bs_nn], a
            ld c, 0                         ; 16 entries: targets 0-7, attackers 8-15
.e:         push bc
            ld a, c
            add a
            ld hl, $DE4F
            call bs_hl_a
            ld a, [hl+]
            ld e, a
            ld d, [hl]
            ld a, e
            and d
            inc a
            jr z, .nx                       ; $FFFF: none
            ld a, c                         ; side: targets by $7E9A bit 6, attackers bit 7
            cp 8
            ld a, [$DE9A]
            jr nc, .at
            add a
.at:        and $80
            ld b, a
            ld a, c
            and 7
            or b
            call bs_numspr
            ld hl, bs_nn
            inc [hl]
            ld a, [hl]
            cp 3
            jr c, .nx
            call bs_numshow
.nx:        pop bc
            inc c
            ld a, c
            cp 16
            jr nz, .e
            ld a, [bs_nn]
            and a
            ret z
; show the numbers placed (32 frames), then clear them
bs_numshow: ld b, 32
.w:         push bc
            call bs_frame
            pop bc
            dec b
            jr nz, .w
            ld hl, oam_buf + 4 * 24         ; entries 24-38
            ld b, 15 * 4
            xor a
.z:         ld [hl+], a
            dec b
            jr nz, .z
            ld [bs_nn], a
            ret
; a number DE (bit 15 green, $40 high: Miss) at slot A (bit 7 a monster) into OAM 24 + 5 n
bs_numspr:  push de
            ld c, a
            bit 7, a
            jr z, .ch
            and 7
            call bs_mpos
            ld a, [bs_y]
            add a
            add a
            add a
            add 16 + 8
            ld [bs_ny], a
            ld a, [bs_x]
            add a
            add a
            add a
            add 8 + 4
            ld [bs_nx], a
            jr .p
.ch:        ld a, c
            add a
            add a
            add a
            ld b, a
            add a
            add b
            add 16 + 8
            ld [bs_ny], a
            ld a, 112 + 8
            ld [bs_nx], a
.p:         ld a, [bs_topon]                ; below the top window while it shows
            and a
            jr z, .p2
            ld a, [bs_ny]
            cp 16 + 32
            jr nc, .p2
            ld a, 16 + 32
            ld [bs_ny], a
.p2:        pop de
            ld a, [bs_nn]                   ; OAM 24 + 5 n
            ld b, a
            add a
            add a
            add b
            add 24
            add a
            add a
            ld l, a
            ld h, high(oam_buf)
            ld a, d
            and $40
            jr nz, .miss
            ld a, d
            and $80
            ld [bs_ngr], a                  ; (green: palette 1)
            ld a, d
            and $3F
            ld d, a
            push hl
            ld h, d
            ld l, e
            call bs_dec
            pop hl
            ld de, bs_numb
            ld b, 4
.d:         ld a, [de]
            inc de
            cp ' '
            jr z, .sp
            sub '0'
            add SPR_DIG
            ld c, a
            ld a, [bs_ny]
            ld [hl+], a
            ld a, [bs_nx]
            ld [hl+], a
            ld a, c
            ld [hl+], a
            ld a, [bs_ngr]
            and a
            ld a, $0C
            jr nz, .g
            ld a, $0B
.g:         ld [hl+], a
.sp:        ld a, [bs_nx]
            add 8
            ld [bs_nx], a
            dec b
            jr nz, .d
            ret
.miss:      ld b, 4                         ; "Miss"
            ld c, SPR_DIG + 10
.m:         ld a, [bs_ny]
            ld [hl+], a
            ld a, [bs_nx]
            ld [hl+], a
            add 8
            ld [bs_nx], a
            ld a, c
            ld [hl+], a
            inc c
            ld a, $0B
            ld [hl+], a
            dec b
            jr nz, .m
            ret
; $0D deaths (34/8496 with FF3's state changes in its animations), then the screen
bsc_death:
bs_deaths:  ld c, 0
.s:         ld a, c
            ld hl, $DEC4
            call bs_hl_a
            ld a, [hl]
            bit 7, a
            jr nz, .dead
            ld a, c                         ; alive, but its slot empty: brought back
            ld hl, $DDA7
            call bs_hl_a
            ld a, [hl]
            cp $FF
            jr z, .summ
            jr .nx
.dead:      ld a, c
            ld hl, $DDA7
            call bs_hl_a
            ld a, [hl]
            cp $FF
            jr nz, .die
.nx:        inc c
            ld a, c
            cp 8
            jr nz, .s
            jp bs_party
.die:       call bs_deadmask                ; 2F/BB0A: experience credit, slots cleared, count
            push af                         ; (their death: a boss's 2F/BEA4, else the wipe)
            call bs_isboss
            jr nz, .wp
            pop af
            push af
            call bs_bossdie
            jr .wd
.wp:        pop af
            push af
            call bs_mwipe
.wd:        pop af
            ld [bs_t], a
            ld b, 0                         ; (slot)
.e:         ld a, [bs_t]
            add a
            ld [bs_t], a
            jr nc, .en
            ld a, b
            ld hl, $DDA7
            call bs_hl_a
            ld a, [hl]
            cp $FF
            jr z, .en
            ld [hl], $FF
            ld hl, $DDD3                    ; (2F/BAEE: counted by the monster's type)
            call bs_hl_a
            inc [hl]
.en:        inc b
            ld a, b
            cp 8
            jr nz, .e
            jr .redraw
.summ:      call bs_deadmask                ; 2F/B959: the living slots' types back
            cpl
            ld b, 0
.u:         add a
            push af
            jr nc, .un
            ld a, b
            ld hl, $DDAF
            call bs_hl_a
            ld e, [hl]
            ld a, b
            ld hl, $DDA7
            call bs_hl_a
            ld [hl], e
.un:        pop af
            inc b
            ld c, a
            ld a, b
            cp 8
            ld a, c
            jr nz, .u
.redraw:    %FAR B_BAT2, fe_B909
            call bs_draw
            jp bs_party
; A = the dead slots (34/84C7: $7EC4 bit 7, slot 0 the top bit)
bs_deadmask:
            ld hl, $DEC4
            ld b, 8
            xor a
.l:         rl [hl]
            rr [hl]                         ; (keep the byte; carry = its bit 7)
            bit 7, [hl]
            scf
            jr nz, .s
            ccf
.s:         rla
            inc hl
            dec b
            jr nz, .l
            ret

; (FF3's tables from the ROM: ROMDATA in build.py)
job_cmds:   ds 88                           ; 34/9B21 the jobs' commands
msg_vars:   ds 72                           ; 34/9575 the battle messages' variables
eq_types:   ds 384                          ; 00/8900 the jobs allowed by type

section wram, $C560
bs_scp:     ds 2
bs_cl:      ds 4
bs_cur:     ds 1
bs_lr:      ds 1
bs_slot:    ds 1
bs_cmd:     ds 1
bs_maxw:    ds 1
bs_side:    ds 1
bs_all:     ds 1
bs_sel:     ds 1
bs_lvmax:   ds 1
bs_lv:      ds 1
bs_spell:   ds 1
bs_bits:    ds 1
bs_ipg:     ds 1
bs_topon:   ds 1
bs_msg:     ds 1
bs_var:     ds 1
bs_nn:      ds 1
bs_nx:      ds 1
bs_ny:      ds 1
bs_ngr:     ds 1
bs_sp:      ds 3
bs_ap:      ds 8
bs_eq:      ds 3
bs_jb:      ds 3
BS_IL      = $C780          ; the item list (ids, then counts: 32 each)

section bank B_BSCR, $7000
; ---- the battle main's steps with the Invincible's cannon: its damage (34/807E), its blast
; before the commands (34/992D; Z: the monsters all gone)
bs_t81c3:   %FAR B_BAT2, fe_81C3
            ld a, [$DED8]
            and $20
            ret z
            %FAR B_BAT2, fe_A487
            ret
bs_t81a0:   %FAR B_BAT2, fe_81A0
            ld a, [$DED8]
            and $20
            jr z, .n
            call bs_cannon
            ld a, [$D8D3]
            cp $40
            ret
.n:         or 1
            ret
; ---- the Invincible's cannon blast (35/A50B): its message, action script 3, the battle's end
bs_cannon:  ld a, $15                       ; (its animation: 34/83F8's $15, as 35/A487 set)
            ld [$DEC2], a
            ld a, $3D                       ; "Cannon blast!"
            ld [$D8DA], a
            ld hl, $DED8
            res 5, [hl]
            ld a, 3
            ld [$D8D5], a
            call bs_script
            %FAR B_BAT2, fe_A458
            ret
; $0E (34/93C4): the cannon's statuses ($E0) into the monsters' (34/9408: dead ones flagged for
; the display, $7EC4), then their deaths
bsc_cdie:   ld c, 0
            ld de, BZ + $E0
            ld hl, B_MO + 1
.m:         ld a, [de]                      ; status 1 |= $E0 + 2 c
            or [hl]
            ld [hl], a
            and $E8
            jr z, .n
            or $80                          ; (as FF3: the bits of $E8 and dead)
            ld [hl], a
            push hl
            ld b, a
            ld hl, $DEC4
            ld a, l
            add c
            ld l, a
            ld [hl], b
            pop hl
.n:         inc hl                          ; status 2 |= $E0 + 2 c + 1
            inc de
            ld a, [de]
            or [hl]
            ld [hl], a
            inc de
            ld a, l                         ; (the next record: + $40)
            add $3F
            ld l, a
            jr nc, .h
            inc h
.h:         inc c
            ld a, c
            cp 8
            jr nz, .m
            jp bs_deaths

; BS_STR at row D, column E, wrapped at spaces: the first line bs_maxw wide, then from column 1 18
; wide, rows 14-16
bs_putsw:   ld hl, BS_STR
.ln:        ld a, [bs_maxw]
            ld c, a
            push hl
            ld [bs_wbr], a                  ; (no space: broken at the width)
            ld b, 0
.sc:        ld a, [hl+]
            and a
            jr z, .end
            cp ' '
            jr nz, .ns
            ld a, b
            ld [bs_wbr], a
.ns:        inc b
            ld a, b
            cp c
            jr c, .sc
            ld a, [hl]                      ; (exactly the width: fits if a space or the end next)
            and a
            jr z, .end
            cp ' '
            jr nz, .brk
            ld a, b
            ld [bs_wbr], a
.brk:       pop hl
            ld a, [bs_wbr]
            ld b, a
            call .pr
            ld a, [hl]
            cp ' '
            jr nz, .nl
            inc hl
.nl:        ld a, d
            cp 16
            ret nc
            inc d
            ld e, 1
            ld a, 18
            ld [bs_maxw], a
            jr .ln
.end:       pop hl
            ld b, 255
.pr:        ld a, b
            and a
            ret z
.p:         ld a, [hl]
            and a
            ret z
            inc hl
            cp $18
            jr c, .p
            push bc
            push hl
            call bs_putc
            pop hl
            pop bc
            inc e
            dec b
            jr nz, .p
            ret

; ---- items (35/ADAF): FF3's grid shown a column at a time: column 0 the hands (rows 1 / 3, under
; t8200's " Right Hand" / " Left Hand"), columns 1-8 the pack's 32 slots, 4 to a column (FF3 scrolls
; two columns across); "X" before what this member cannot use or equip. A marks an entry (a second
; hand), A on it again uses it (35/B4F7: an item $98-$C7 or a weapon's spell), A on another swaps
; it with a hand (35/AF79: one of the two in column 0; 35/B242's checks, stacks, 20 arrows); B drops
; the mark or leaves. A swap or a cancel goes back to the commands; a use ends the member's turn.
; FF3's own variables: BZ + $62 / $63 the cursor's row / column, $67 marked, $68 / $69 its row /
; column; $7AF5 the grid's ids and counts, $7B3D its usable flags.
IT_B       = $DAF5
IT_P       = $DAFD
IT_U       = $DB3D

section bank B_BSCR, $7700
bs_item:    ld hl, $D0C0                    ; the pack, the hands (rows 0 / 1 right, 2 / 3 left)
            ld de, IT_P
            ld bc, $40
            call memcpy
            call it_hands
            ld de, IT_B
            ld a, [hl+]
            ld [de], a
            inc e
            ld b, [hl]
            inc hl
            ld a, b
            ld [de], a
            inc e
            ld a, [IT_B]
            ld [de], a
            inc e
            ld a, b
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld b, [hl]
            ld a, b
            ld [de], a
            inc e
            ld a, [IT_B + 4]
            ld [de], a
            inc e
            ld a, b
            ld [de], a
            ld hl, IT_U                     ; usable: items $98-$C7, what the job can equip
            ld b, 36
            ld a, 1
.u:         ld [hl+], a
            dec b
            jr nz, .u
            ld c, 0
.uc:        ld a, c
            add a
            ld hl, IT_P
            call bs_hl_a
            ld a, [hl]
            cp $62
            jr c, .uw
            cp $98
            jr c, .un
            cp $C8
            jr c, .unx
            jr .un
.uw:        push bc
            call bs_caneq
            pop bc
            jr nz, .unx
.un:        ld a, c
            add 4
            ld hl, IT_U
            call bs_hl_a
            ld [hl], 0
.unx:       inc c
            ld a, c
            cp 32
            jr nz, .uc
            xor a
            ld [BZ + $62], a
            ld [BZ + $67], a
            inc a
            ld [BZ + $63], a
.redraw:    call it_draw
.loop:      ld a, [BZ + $62]
            add 13
            ld b, a
            ld c, 0
            call bs_hand_cell
            call bs_frame
            ldh a, [pad_new]
            bit 0, a
            jp nz, .a
            bit 1, a
            jp nz, .b
            bit 6, a
            jr nz, .up
            bit 7, a
            jr nz, .dn
            bit 5, a
            jr nz, .lf
            bit 4, a
            jr nz, .rt
            jr .loop
.up:        ld a, [BZ + $63]                ; (35/AEE0: column 0 rows 1 / 3 only)
            and a
            ld a, [BZ + $62]
            jr nz, .u2
            cp 1
            jr z, .loop
            dec a
.u2:        and a
            jr z, .loop
            dec a
            ld [BZ + $62], a
            jr .loop
.dn:        ld a, [BZ + $62]
            cp 3
            jr z, .loop
            ld b, a
            ld a, [BZ + $63]
            and a
            ld a, b
            jr nz, .d2
            inc a
.d2:        inc a
            ld [BZ + $62], a
            jr .loop
.lf:        ld a, [BZ + $63]
            and a
            jr z, .loop
            dec a
            ld [BZ + $63], a
            jr nz, .redraw
            ld a, [BZ + $62]
            or 1
            ld [BZ + $62], a
            jr .redraw
.rt:        ld a, [BZ + $63]
            cp 8
            jr z, .loop
            inc a
            ld [BZ + $63], a
            jr .redraw
.b:         ld a, [BZ + $67]
            and a
            jr z, .x
            xor a
            ld [BZ + $67], a
            call it_mark
            jr .loop
.x:         call bs_hand_off                ; (back to the commands)
            jp it_close
.a:         ld a, [BZ + $67]
            and a
            jr nz, .a2
            inc a                           ; marked
            ld [BZ + $67], a
            ld a, [BZ + $62]
            ld [BZ + $68], a
            ld a, [BZ + $63]
            ld [BZ + $69], a
            call it_mark
            ld a, $05
            call bs_sfxu
            ld b, 16
.aw:        push bc
            call bs_frame
            pop bc
            dec b
            jr nz, .aw
            jp .loop
.a2:        ld a, [BZ + $63]                ; the same entry: used
            ld hl, BZ + $69
            cp [hl]
            jr nz, .sw
            ld a, [BZ + $62]
            ld hl, BZ + $68
            cp [hl]
            jp z, it_use
.sw:        call it_swap                    ; (NZ: refused)
            jp nz, .loop
            call bs_hand_off
            jp it_close

; the error sound
it_err:     ld a, $06
            jp bs_sfxu
; HL = the member's hands ($6203 + 64 c: right id, count, left id, count)
it_hands:   ld a, [BZ + $52]
            rrca
            rrca
            and $C0
            add 3
            ld l, a
            ld h, $D2
            ret
; the column [BZ + $63] in the bottom window
it_draw:    ld de, $0C00
            ld bc, $0614
            call bs_win
            ld c, 0
.r:         push bc
            ld a, [BZ + $63]
            and a
            jr nz, .e
            bit 0, c
            jr nz, .e
            ld a, c                         ; (column 0, rows 0 / 2: the hands' names)
            srl a
            add $E0
            ld e, a
            ld d, 0
            ld hl, T_T8200
            call bs_namet
            pop bc
            push bc
            ld a, c
            add 13
            ld d, a
            ld e, 1
            ld a, 17
            ld [bs_maxw], a
            call bs_putsn
            jr .n
.e:         ld a, [BZ + $63]                ; entry k = 4 column + row
            add a
            add a
            add c
            ld [bs_t], a
            add a
            ld hl, IT_B
            call bs_hl_a
            ld a, [hl+]
            and a
            jr z, .n
            ld b, [hl]
            push bc
            ld e, a
            ld d, 0
            call bs_name
            pop bc
            ld a, b
            ld [bs_tq], a
            pop bc
            push bc
            ld a, c
            add 13
            ld d, a
            ld a, [bs_t]                    ; "X": not usable
            ld hl, IT_U
            call bs_hl_a
            ld a, [hl]
            and a
            jr nz, .ok
            ld e, 1
            ld a, 'X'
            call bs_putc
.ok:        ld e, 2
            ld a, 12
            ld [bs_maxw], a
            call bs_putsn
            ld e, 14
            ld a, ':'
            call bs_putc
            ld a, [bs_tq]
            ld l, a
            ld h, 0
            push de
            call bs_dec
            pop de
            ld e, 15
            ld a, [bs_numb + 2]
            call bs_putc
            inc e
            ld a, [bs_numb + 3]
            call bs_putc
.n:         pop bc
            inc c
            ld a, c
            cp 4
            jp nz, .r
; the mark (OAM 32-35, 4 pixels right of the cursor), when its column shows
it_mark:    ld hl, oam_buf + 4 * 32
            ld a, [BZ + $67]
            and a
            jp z, hand16off
            ld a, [BZ + $69]
            ld b, a
            ld a, [BZ + $63]
            cp b
            jp nz, hand16off
            ld a, [BZ + $68]
            add 13
            add a
            add a
            add a
            add 16 - 2
            ld b, a
            ld c, 4
            jp hand16
; leaving: the marks off, FF3's equipment update (34/8026: 31/AA16), the party redrawn
it_close:   ld hl, oam_buf + 4 * 32
            call hand16off
            ld hl, fe_AA16
            ld a, B_BAT
            call far_call
            call bs_party
            jp bs_pwin

; ---- A on the marked entry (35/B4F7): an item's spell (2E/91A0) or a weapon's (30/9400 byte 4)
it_use:     ld a, [BZ + $63]
            add a
            add a
            ld hl, BZ + $62
            add [hl]
            ld [bs_t], a                    ; (k)
            add a
            ld hl, IT_B
            call bs_hl_a
            ld a, [hl]
            and a
            jr z, .no
            cp $C8
            jr nc, .no
            ld [bs_spell], a
            cp $98
            jr nc, .item
            cp $57
            jr nc, .no
            ld l, a                         ; a weapon: its spell
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, $9400 + 4 - $4000
            add hl, de
            ld a, B_BDAT
            call far_byte
            cp $7F
            jr nz, .sp
            ld a, 9                         ; (none: FF3's $747D = 9)
            ld [bs_ap + 5], a
            jr .chk
.no:        call it_err
            jp bs_item.loop
.item:      cp $A6                          ; (potion, hi-potion, elixir: $7CE8)
            jr c, .i2
            cp $A9
            jr nc, .i2
            ld a, $FF
            ld [$DCE8], a
.i2:        ld a, [bs_spell]
            sub $98
            ld l, a
            ld h, 0
            ld de, $91A0 - $4000
            add hl, de
            ld a, B_BDAT2
            call far_byte
            cp $7F
            jr nz, .sp
            ld a, [bs_t]                    ; (no spell: one target)
            ld hl, IT_U
            call bs_hl_a
            ld a, [hl]
            and a
            jr z, .no
            ld a, 2
            jr .t
.sp:        call bs_canuse                  ; (its properties -> bs_ap)
.chk:       ld a, [bs_t]
            ld hl, IT_U
            call bs_hl_a
            ld a, [hl]
            and a
            jr z, .no
            ld a, $05
            call bs_sfxu
            ld a, [bs_ap + 5]
            and $20
            ld a, 0
            jr nz, .m1
            inc a
.m1:        ld b, a
            ld a, [bs_ap + 5]
            bit 7, a
            jr z, .m2
            set 1, b
.m2:        ld a, b
.t:         ld [BZ + $B3], a
            call bs_hand_off
            ld hl, oam_buf + 4 * 32
            call hand16off
            call bs_target
            ld a, [BZ + $B4]
            and a
            jp z, it_close                  ; (cancelled: back to the commands, 35/B5C1)
            call bs_crec                    ; the record: item flag, the item, targets
            ld bc, $2C
            add hl, bc
            set 3, [hl]
            inc hl
            inc hl
            ld a, [bs_spell]
            ld [hl+], a
            ld a, [BZ + $B4]
            ld [hl+], a
            ld a, [BZ + $B5]
            ld [hl], a
            ld de, $3E - $30
            add hl, de
            ld a, [BZ + $63]                ; (from a hand: $3E = 1)
            and a
            jr nz, .h
            ld [hl], 1
.h:         inc hl
            ld a, [bs_spell]
            ld [hl], a
            ld a, [bs_t]                    ; one fewer (FF3 at once: 35/B5D8)
            add a
            inc a
            ld hl, IT_B
            call bs_hl_a
            dec [hl]
            jr nz, .k
            dec hl
            ld [hl], 0
.k:         ld hl, IT_P
            ld de, $D0C0
            ld bc, $40
            call memcpy
            ld hl, BZ + $52
            inc [hl]
            jp it_close

; ---- A on another entry (35/AF79): a hand swapped with a pack slot; NZ refused
it_swap:    ld a, [BZ + $63]                ; one of the two in column 0
            ld b, a
            ld a, [BZ + $69]
            ld c, a
            or b
            jr z, .err
            ld a, b
            and a
            jr z, .h0
            ld a, c
            and a
            jr nz, .err
            ld a, [BZ + $62]                ; (the cursor on the pack: the hand is the mark)
            ld [BZ + $43], a                ; (pack row)
            ld a, b
            ld [BZ + $45], a                ; (pack column)
            ld a, [BZ + $68]
            ld [BZ + $44], a                ; (hand row)
            jr .go
.h0:        ld a, [BZ + $68]
            ld [BZ + $43], a
            ld a, c
            ld [BZ + $45], a
            ld a, [BZ + $62]
            ld [BZ + $44], a
.go:        ld a, [BZ + $45]                ; pack k = 4 column + row; its usable flag
            add a
            add a
            ld hl, BZ + $43
            add [hl]
            ld [BZ + $45], a
            ld hl, IT_U
            call bs_hl_a
            ld a, [hl]
            and a
            jr z, .err
            ld a, [BZ + $45]                ; $40 / $41 the pack's id / count
            add a
            ld [BZ + $43], a
            ld hl, IT_B
            call bs_hl_a
            ld a, [hl+]
            cp $62
            jr nc, .err
            ld [BZ + $40], a
            ld a, [hl]
            ld [BZ + $41], a
            ld a, [BZ + $44]                ; $3E / $3F the hand's (offset $42)
            add a
            ld [BZ + $42], a
            ld hl, IT_B
            call bs_hl_a
            ld a, [hl+]
            ld [BZ + $3E], a
            ld a, [hl]
            ld [BZ + $3F], a
            call it_hcheck
            jr c, .err
            ld a, [BZ + $3E]                ; the same item: the hand's onto the pack's
            ld hl, BZ + $40
            cp [hl]
            jr nz, .df
            or [hl]
            jr z, .err
            ld a, [BZ + $42]
            ld hl, IT_B
            call bs_hl_a
            xor a
            ld [hl+], a
            ld [hl], a
            ld a, [BZ + $44]
            ld hl, IT_U
            call bs_hl_a
            ld [hl], 1
            ld a, [BZ + $41]
            ld hl, BZ + $3F
            add [hl]
            cp 100
            jr c, .s9
            ld a, 99
.s9:        ld b, a
            ld a, [BZ + $43]
            inc a
            ld hl, IT_B
            call bs_hl_a
            ld [hl], b
            jp .done
.err:       call it_err
            or 1
            ret
.df:        ld a, [BZ + $41]                ; one of a kind, or an empty slot: a plain swap
            cp 1
            jp z, .plain
            ld a, [BZ + $40]
            and a
            jp z, .plain
            ld hl, IT_P                     ; a stack: an empty pack slot ($24, $25 = 1: none)
            ld c, 0
            xor a
            ld [BZ + $25], a
.e:         ld a, [hl]
            and a
            jr z, .ef
            inc hl
            inc hl
            inc c
            inc c
            ld a, c
            cp $40
            jr nz, .e
            ld a, 1
            ld [BZ + $25], a
.ef:        ld a, c
            ld [BZ + $24], a
            ld a, [BZ + $40]                ; arrows ($4F-$56): 20 into the hand
            cp $4F
            jr c, .one
            cp $57
            jr nc, .one
            ld a, [BZ + $41]
            cp $15
            jr c, .plain
            ld b, $14
            jr .take
.one:       ld b, 1                         ; else one into the hand
.take:      ld a, [BZ + $3E]
            and a
            jr z, .t2
            ld a, [BZ + $25]                ; the hand's old item into the empty slot
            and a
            jr nz, .err
            ld a, [BZ + $24]
            ld hl, IT_P
            call bs_hl_a
            ld a, [BZ + $3E]
            ld [hl+], a
            ld a, [BZ + $3F]
            ld [hl], a
.t2:        ld a, [BZ + $42]
            ld hl, IT_B
            call bs_hl_a
            ld a, [BZ + $40]
            ld [hl+], a
            ld [hl], b
            ld a, [BZ + $43]
            inc a
            ld hl, IT_B
            call bs_hl_a
            ld a, [hl]
            sub b
            ld [hl], a
            jr .done
.plain:     ld a, [BZ + $43]                ; (35/B101)
            ld hl, IT_B
            call bs_hl_a
            ld a, [BZ + $3E]
            ld [hl+], a
            ld a, [BZ + $3F]
            ld [hl], a
            ld a, [BZ + $42]
            ld hl, IT_B
            call bs_hl_a
            ld a, [BZ + $40]
            ld [hl+], a
            ld a, [BZ + $41]
            ld [hl], a
            ld a, [BZ + $44]
            ld hl, IT_U
            call bs_hl_a
            ld b, [hl]
            ld a, [BZ + $45]
            ld de, IT_U
            add e
            ld e, a
            ld a, [de]
            ld [hl], a
            ld a, b
            ld [de], a
.done:      ld hl, IT_P                     ; (35/B131) the pack and the hands back
            ld de, $D0C0
            ld bc, $40
            call memcpy
            call it_hands
            ld a, [IT_B + 2]
            ld [hl+], a
            ld a, [IT_B + 3]
            ld [hl+], a
            ld a, [IT_B + 6]
            ld [hl+], a
            ld a, [IT_B + 7]
            ld [hl], a
            ld a, $05
            call bs_sfxu
            xor a
            ret

; 35/B242: C when the new item ($40) cannot go with the other hand's (two-handed weapons, bows and
; arrows, shields)
it_hcheck:  ld a, [BZ + $40]
            ld e, a                         ; E = $1D
            ld a, [IT_B]
            ld hl, BZ + $3E
            cp [hl]
            jr nz, .o
            ld a, [IT_B + 4]
.o:         ld d, a                         ; D = $1C
            ld a, e
            cp d
            jr c, .s
            ld e, d
            ld d, a
.s:         ld a, d                         ; D the larger, E the smaller
            and a
            jr z, .ok
            cp $62
            jr nc, .no
            cp $58
            jr c, .w
            ld a, e                         ; a shield
            and a
            jr z, .ok
            cp $58
            jr nc, .ok
            cp $46
            jr nc, .no
            jr .ok
.w:         cp $4F
            jr c, .w2
            ld a, e                         ; arrows: with a bow or nothing
            and a
            jr z, .ok
            cp $4F
            jr nc, .no
            cp $4A
            jr nc, .ok
            jr .no
.w2:        cp $4A
            jr c, .w3
            ld a, e                         ; a bow: alone (arrows sort above it)
            and a
            jr z, .ok
            jr .no
.w3:        cp $46
            jr c, .ok
            ld a, e                         ; two-handed: alone
            and a
            jr z, .ok
.no:        scf
            ret
.ok:        and a
            ret

; NZ when the member can equip weapon / shield A (35/B8FD with 30/9400)
bs_caneq:   ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, $9400 - $4000
            add hl, de
            ld de, bs_ap
            ld bc, 8
            ld a, B_BDAT
            call far_copy
            jp bs_canuse.k

section wram, $C5E7
bs_tq:      ds 1

; FF3's inventory for a battle (3D/BC12): the field's 32 ids ($60C0) and 32 counts ($60E0) as 32
; id / count pairs; and back after it (3D/BC2D); work RAM bank 2's copy of the save page
section bank B_BSCR, $7680
bs_ilv:     call .cp
            ld hl, BS_PAGE
            ld de, $D0C0
            ld b, 32
.i:         ld a, [hl]
            ld [de], a
            inc e
            push hl
            ld a, l
            add 32
            ld l, a
            ld a, [hl]
            ld [de], a
            inc e
            pop hl
            inc l
            dec b
            jr nz, .i
            ret
.cp:        ld hl, $D0C0
            ld de, BS_PAGE
            ld bc, 64
            jp memcpy
bs_dlv:     call bs_ilv.cp
            ld hl, BS_PAGE
            ld de, $D0C0
            ld b, 32
.d:         ld a, [hl+]
            ld [de], a
            push de
            ld a, e
            add 32
            ld e, a
            ld a, [hl+]
            ld [de], a
            pop de
            inc e
            dec b
            jr nz, .d
            ret
