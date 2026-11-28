; ---- 35/ADAF battle command $14: item. FF3's grid kept: column 0 the hands (rows 1 / 3; rows 0 /
; 2 their labels), columns 1-8 the inventory, 4 rows each ($7AF5 + 8 x + 2 y: id, count), the
; usability marks ($7B3D + 4 x + y); A picks an item, A again on it uses it (target choice),
; on another place swaps a hand and an inventory item (FF3's two-hand, shield and arrow rules);
; B drops the pick / closes. On the GB (the owner's tall list window): screen rows 8-17, the
; cursor's column in the top four lines and the next column below it.
IT_X       = BZ + $63           ; FF3's cursor x / y, the picked place, the pick flag
IT_Y       = BZ + $62
IT_SX      = BZ + $69
IT_SY      = BZ + $68
IT_SEL     = BZ + $67
IT_BUF     = W7 + $7AF5

bitem_menu:  xor a
            ld [W7 + $7573], a
            ld hl, GS + $C0                 ; the inventory -> $7AFD
            ld de, W7 + $7AFD
            ld bc, $40
            call memcpy
            ld hl, W7 + $7B3D               ; all usable, then the inventory's checked
            ld b, $24
            ld a, 1
.u:         ld [hl+], a
            dec b
            jr nz, .u
            ld a, [BZ + $5F]                ; the hands: rows 0-1 right, 2-3 left
            add a, 3
            ld c, a
            ld a, $59
            call zpy
            ld a, [hl+]
            ld [W7 + $7AF5], a
            ld [W7 + $7AF7], a
            ld a, [hl+]
            ld [W7 + $7AF6], a
            ld [W7 + $7AF8], a
            ld a, [hl+]
            ld [W7 + $7AF9], a
            ld [W7 + $7AFB], a
            ld a, [hl]
            ld [W7 + $7AFA], a
            ld [W7 + $7AFC], a
            xor a
            ld [BZ + $42], a
            ld [BZ + $43], a
.k:         ld a, [BZ + $42]
            ld e, a
            ld d, 0
            ld hl, GS + $C0
            add hl, de
            ld a, [hl]
            cp $62
            jr c, .w
            cp $98
            jr c, .no
            cp $C8
            jr c, .ok
            jr .no
.w:         call b_can
            jr nz, .ok
.no:        ld a, [BZ + $43]
            ld e, a
            ld d, 0
            ld hl, W7 + $7B41
            add hl, de
            dec [hl]
.ok:        ld hl, BZ + $42
            inc [hl]
            inc [hl]
            ld hl, BZ + $43
            inc [hl]
            ld a, [hl]
            cp $20
            jr nz, .k
            xor a
            ld [IT_Y], a
            ld [BZ + $65], a
            ld [IT_SEL], a
            inc a
            ld [BZ + $66], a
            ld [IT_X], a
            call tall_open
.l:         call bit_draw
.in:        call b_keys
            ld a, [btl_new]
            and a
            jr z, .in
            ld b, a
            ld a, $98
            ld [S49], a
            ld a, b
            cp 1
            jp z, it_a
            cp 2
            jp z, it_b
            cp $10
            jr z, .right
            cp $20
            jr z, .left
            cp $80
            jr z, .down
            cp $40
            jr nz, .in
            ld a, [IT_X]                    ; up (column 0: the hand rows 1 / 3)
            and a
            jr nz, .u1
            ld a, [IT_Y]
            cp 1
            jr z, .l
            ld hl, IT_Y
            dec [hl]
.u1:        ld a, [IT_Y]
            and a
            jr z, .l
            ld hl, IT_Y
            dec [hl]
            jr .l
.down:      ld a, [IT_Y]
            cp 3
            jr z, .l
            ld a, [IT_X]
            and a
            jr nz, .d1
            ld hl, IT_Y
            inc [hl]
.d1:        ld hl, IT_Y
            inc [hl]
            jr .l
.left:      ld a, [IT_X]
            and a
            jr z, .l
            dec a
            ld [IT_X], a
            jr nz, .l
            ld a, [IT_Y]                    ; (into column 0: an odd row)
            or 1
            ld [IT_Y], a
            jr .l
.right:     ld a, [IT_X]
            cp 8
            jr z, .l
            inc a
            ld [IT_X], a
            jr .l

; A: pick, use the picked one, or swap
it_a:       ld a, [IT_SEL]
            and a
            jr nz, .two
            inc a
            ld [IT_SEL], a
            ld a, [IT_Y]
            ld [IT_SY], a
            ld a, [IT_X]
            ld [IT_SX], a
            ld a, $85
            ld [S49], a
            jp bitem_menu.l
.two:       ld a, [IT_X]
            ld b, a
            ld a, [IT_SX]
            cp b
            jr nz, it_swap
            ld a, [IT_Y]
            ld b, a
            ld a, [IT_SY]
            cp b
            jp z, bit_use
            ; (fall through)
; 35/AF88 swap a hand and an inventory item
it_swap:    ld a, [IT_X]
            ld b, a
            ld a, [IT_SX]
            or b
            jr z, it_err
            ld a, [IT_X]
            and a
            jr z, it_sw2
            ld a, [IT_SX]
            and a
            jr z, it_sw2
it_err:     ld a, $86
            ld [S49], a
            jp bitem_menu.l
it_sw2:     xor a
            ld [W7 + $7408], a
            inc a
            ld [W7 + $7409], a
            ld a, [IT_SX]                   ; ($63 the hand column, $69 the inventory's)
            ld b, a
            ld a, [IT_X]
            cp b
            jr c, .s1
            call it_xchg
            ld a, 1
            ld [W7 + $7408], a
            xor a
            ld [W7 + $7409], a
.s1:        ld a, [IT_SX]
            add a, a
            add a, a
            add a, a
            ld b, a
            ld a, [IT_SY]
            add a, a
            add a, b
            ld [BZ + $43], a
            ld a, [IT_SX]
            add a, a
            add a, a
            ld b, a
            ld a, [IT_SY]
            add a, b
            ld [BZ + $45], a
            ld e, a
            ld d, 0
            ld hl, W7 + $7B3D
            add hl, de
            ld a, [hl]
            and a
            jr z, .err
            ld a, [BZ + $43]
            ld e, a
            ld d, 0
            ld hl, IT_BUF
            add hl, de
            ld a, [hl+]
            cp $62
            jr nc, .err
            ld [BZ + $40], a
            ld a, [hl]
            ld [BZ + $41], a
            ld a, [IT_X]
            add a, a
            add a, a
            add a, a
            ld b, a
            ld a, [IT_Y]
            add a, a
            add a, b
            ld [BZ + $42], a
            ld e, a
            ld d, 0
            ld hl, IT_BUF
            add hl, de
            ld a, [hl+]
            ld [BZ + $3E], a
            ld a, [hl]
            ld [BZ + $3F], a
            ld a, [IT_X]
            add a, a
            add a, a
            ld b, a
            ld a, [IT_Y]
            add a, b
            ld [BZ + $44], a
            call it_hands
            jr c, .err
            ld a, [BZ + $40]
            ld b, a
            ld a, [BZ + $3E]
            cp b
            jr nz, .diff
            or b
            jr z, .err
            ld a, [BZ + $42]                ; the same item: into the inventory's count
            call it_slot
            xor a
            ld [hl+], a
            ld [hl], a
            ld a, [BZ + $44]
            ld e, a
            ld d, 0
            ld hl, W7 + $7B3D
            add hl, de
            ld [hl], 1
            ld a, [BZ + $43]
            call it_slot
            inc hl
            ld a, [BZ + $41]
            ld b, a
            ld a, [BZ + $3F]
            add a, b
            cp $64
            jr c, .s2
            ld a, $63
.s2:        ld [hl], a
            jp .done
.err:       ld a, [W7 + $7408]              ; 35/AFDF
            and a
            call nz, it_xchg
            jp it_err
.diff:      ld a, [BZ + $41]
            cp 1
            jp z, .plain
            ld a, [BZ + $40]
            and a
            jp z, .plain
            ld hl, W7 + $7AFD               ; the first free pair -> $24 ($25: none)
            ld c, 0
            xor a
            ld [BZ + $25], a
.f:         ld a, [hl+]
            inc hl
            and a
            jr z, .f1
            inc c
            inc c
            ld a, c
            cp $40
            jr nz, .f
            ld a, 1
            ld [BZ + $25], a
.f1:        ld a, c
            ld [BZ + $24], a
            ld a, [BZ + $40]
            cp $4F
            jr c, .one
            cp $57
            jr nc, .one
            ld a, [BZ + $41]                ; arrows: 20 to the hand (21 or more)
            cp $15
            jp c, .plain
            call .free
            jr c, .err
            ld a, $14
            jr .take
.one:       call .free                      ; one to the hand
            jr c, .err
            ld a, 1
.take:      ld [btl_tmp], a
            ld a, [BZ + $42]
            call it_slot
            ld a, [BZ + $40]
            ld [hl+], a
            ld a, [btl_tmp]
            ld [hl], a
            ld a, [BZ + $43]
            call it_slot
            inc hl
            ld a, [btl_tmp]
            ld b, a
            ld a, [hl]
            sub b
            ld [hl], a
            jr .done
.free:      ld a, [BZ + $3E]                ; the hand's item into the free pair (none: carry)
            and a
            ret z
            ld a, [BZ + $25]
            and a
            scf
            ret nz
            ld a, [BZ + $24]
            ld e, a
            ld d, 0
            ld hl, W7 + $7AFD
            add hl, de
            ld a, [BZ + $3E]
            ld [hl+], a
            ld a, [BZ + $3F]
            ld [hl], a
            and a
            ret
.plain:     ld a, [BZ + $43]                ; 35/B101: the two exchanged, their marks too
            call it_slot
            ld a, [BZ + $3E]
            ld [hl+], a
            ld a, [BZ + $3F]
            ld [hl], a
            ld a, [BZ + $42]
            call it_slot
            ld a, [BZ + $40]
            ld [hl+], a
            ld a, [BZ + $41]
            ld [hl], a
            ld a, [BZ + $44]
            ld e, a
            ld d, 0
            ld hl, W7 + $7B3D
            add hl, de
            ld b, [hl]
            push hl
            ld a, [BZ + $45]
            ld e, a
            ld hl, W7 + $7B3D
            add hl, de
            ld a, [hl]
            ld [hl], b
            pop hl
            ld [hl], a
.done:      call it_save                    ; 35/B131
            ld a, $85
            ld [S49], a
            ld a, [W7 + $7408]
            and a
            jr z, .d1
            ld a, [IT_X]
            ld b, a
            ld a, [IT_SX]
            ld [IT_X], a
            ld a, b
            ld [IT_SX], a
.d1:        jp it_close                     ; (the same member again)

; the inventory and the hands back ($60C0, the save block's hands)
it_save:    ld hl, W7 + $7AFD
            ld de, GS + $C0
            ld bc, $40
            call memcpy
            ld a, [BZ + $5F]
            add a, 3
            ld c, a
            ld a, $59
            call zpy
            ld a, [W7 + $7AF7]
            ld [hl+], a
            ld a, [W7 + $7AF8]
            ld [hl+], a
            ld a, [W7 + $7AFB]
            ld [hl+], a
            ld a, [W7 + $7AFC]
            ld [hl], a
            ret

; HL = $7AF5 + A
it_slot:    ld e, a
            ld d, 0
            ld hl, IT_BUF
            add hl, de
            ret

; the cursor and the picked place exchanged
it_xchg:    ld a, [IT_X]
            ld b, a
            ld a, [IT_SX]
            ld [IT_X], a
            ld a, b
            ld [IT_SX], a
            ld a, [IT_Y]
            ld b, a
            ld a, [IT_SY]
            ld [IT_Y], a
            ld a, b
            ld [IT_SY], a
            ret

; 35/B242: carry if the hands can't hold the pair (the other hand's item vs the new one)
it_hands:   ld a, [BZ + $40]
            ld [BZ + $1D], a
            ld a, [BZ + $3E]
            ld b, a
            ld a, [W7 + $7AF5]
            cp b
            jr nz, .o
            ld a, [W7 + $7AF9]
.o:         ld [BZ + $1C], a
            ld b, a
            ld a, [BZ + $1D]
            cp b
            jr c, .s
            ld [BZ + $1C], a                ; ($1C the larger, $1D the smaller)
            ld a, b
            ld [BZ + $1D], a
.s:         ld a, [BZ + $1C]
            and a
            ret z
            cp $62
            ccf
            ret c
            ld c, a
            ld a, [BZ + $1D]
            ld b, a
            ld a, c
            cp $58
            jr c, .w
            ld a, b                         ; a shield: not with a harp / bow / arrows
            and a
            ret z
            cp $58
            jr nc, .okc
            cp $46
            ccf
            ret
.okc:       and a
            ret
.w:         cp $4F
            jr c, .b
            ld a, b                         ; arrows: with a bow
            and a
            ret z
            cp $4F
            ccf
            ret c
            cp $4A
            ccf
            ccf
            ret
.b:         cp $46
            ccf
            ret nc
            ld a, b                         ; a bow / harp: the other hand empty
            and a
            ret z
            scf
            ret

; 35/B198 B: drop the pick, else close
it_b:       ld a, [IT_SEL]
            and a
            jp z, it_close
            xor a
            ld [IT_SEL], a
            jp bitem_menu.l

; 35/B4F7 use the item at the cursor
bit_use:     ld a, [IT_X]
            add a, a
            add a, a
            add a, a
            ld b, a
            ld a, [IT_Y]
            add a, a
            add a, b
            ld [BZ + $26], a
            call it_slot
            ld a, [hl]
            and a
            jr nz, .i
.nil:       ld a, [BZ + $5F]                ; action $00, error
            add a, $2E
            ld c, a
            ld a, $5B
            call zpy
            ld [hl], 0
            jp it_err
.i:         push af
            ld a, $85
            ld [S49], a
            ld a, [BZ + $5F]
            add a, $2E
            ld c, a
            ld a, $5B
            call zpy
            pop af
            ld [hl-], a
            cp $A6
            jr c, .p0
            cp $A9
            jr nc, .p0
            ld b, a
            ld a, $FF
            ld [W7 + $7CE8], a
            ld a, b
.p0:        dec hl
            set 3, [hl]
            ld [BZ + $27], a
            cp $C8
            jr nc, .nil
            cp $98
            jr nc, .it
            cp $57
            jr nc, .nil
            ld l, a                         ; a weapon: its spell (30/9400 + 8 id + 4)
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, BD2_ITEM
            add hl, de
            ld de, W7 + $7478
            ld bc, 8
            ld a, BDATA2_BANK
            call rd_copy
            ld a, [W7 + $747C]
            jr .sp
.it:        sub $98                         ; an item: 2E/91A0
            ld e, a
            ld d, 0
            ld hl, BD_ITSPL
            add hl, de
            call bd_rd
.sp:        ld [btl_tmp], a
            ld a, [IT_X]
            add a, a
            add a, a
            ld b, a
            ld a, [IT_Y]
            add a, b
            ld e, a
            ld d, 0
            ld hl, W7 + $7B3D
            add hl, de
            ld a, [hl]
            and a
            jr z, .nil
            ld a, [btl_tmp]
            cp $7F
            jr nz, .ap
            ld a, 9
            ld [W7 + $747D], a
            jr .tg
.ap:        ld l, a                         ; the spell's attack properties -> $7478
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, BD2_ATK
            add hl, de
            ld de, W7 + $7478
            ld bc, 8
            ld a, BDATA2_BANK
            call rd_copy
.tg:        call tall_close
            call mg_targets
            cp 2
            jr nz, .go
            jp it_close.same
.go:        ld a, [BZ + $5F]
            add a, $3F
            ld c, a
            ld a, $5B
            call zpy
            ld a, [BZ + $27]
            ld [hl-], a
            ld a, [IT_X]
            and a
            jr nz, .q
            ld [hl], 1
.q:         ld a, [BZ + $26]                ; one used up (the buffer), the inventory back
            call it_slot
            inc hl
            dec [hl]
            jr nz, .s
            dec hl
            ld [hl], 0
.s:         ld hl, W7 + $7AFD
            ld de, GS + $C0
            ld bc, $40
            call memcpy
            ld hl, BZ + $52
            inc [hl]
            jr it_close.out

; 35/B1B0 close: the equipment updated, the member (or the next) again
it_close:   call tall_close
.same:      ; (same member)
.out:       call beq_update
            ld a, 2
            ret

; 35/B979 the item / spell's targets ($7478: its attack properties): A = 0 chosen, 2 cancelled
mg_targets: ld a, [W7 + $747D]
            and $18
            jr z, .ok                       ; (summons: none)
            ld a, [W7 + $747D]
            and $40
            jr nz, .all
            ld a, [W7 + $747D]
            and $20
            ld a, 0
            jr nz, .m
            inc a
.m:         ld b, a
            ld a, [W7 + $747D]
            bit 7, a
            ld a, b
            jr z, .m1
            or 2
.m1:        ld [BZ + $B3], a
            xor a
            ld [W7 + $7CE8], a
            call tg_on                      ; (the target's name in the left window)
            call target_sel
            push af
            xor a
            ld [btl_tw], a
            pop af
            and a
            ld a, 2
            ret z
            ld a, [BZ + $5F]
            add a, $2F
            ld c, a
            ld a, $5B
            call zpy
            ld a, [BZ + $B4]
            ld [hl+], a
            ld a, [BZ + $B5]
            ld [hl], a
            jr .ok
.all:       ld hl, W7 + $7675 + 1           ; every monster neither dead nor stone
            ld bc, $0800
.a:         ld a, [hl]
            and $C0
            jr nz, .a1
            ld a, 8
            sub b
            push bc
            push hl
            call bitmask
            pop hl
            pop bc
            or c
            ld c, a
.a1:        push bc
            ld bc, $40
            add hl, bc
            pop bc
            dec b
            jr nz, .a
            push bc
            ld a, [BZ + $5F]
            add a, $2F
            ld c, a
            ld a, $5B
            call zpy
            pop bc
            ld [hl], c
            inc hl
            ld [hl], $C0
.ok:        xor a
            ret

; NZ if the member can equip item A (MENU_BANK $6000: 3 bytes a job mask per item)
b_can:      ld l, a
            ld h, 0
            ld e, l
            ld d, h
            add hl, hl
            add hl, de
            ld de, $6000
            add hl, de
            ld de, btl_tmp
            ld bc, 3
            ld a, MENU_BANK
            call rd_copy
            call chr_ofs                    ; the job: bit j from the low end of byte 2
            ld c, a
            ld a, $57
            call zpy
            ld a, [hl]
            ld hl, btl_tmp + 2
            ld b, a
.j:         ld a, b
            cp 8
            jr c, .b
            sub 8
            ld b, a
            dec hl
            jr .j
.b:         ld a, [hl]
            inc b
.r:         dec b
            jr z, .t
            srl a
            jr .r
.t:         and 1
            ret

; ---- the tall window (screen rows 8-17): the party's sprites hidden while it shows
tall_open:  ld a, 64
            ldh [rWY], a
            ld bc, $0A08                    ; (the gradient over the tall window)
            call bv_grad
            ld hl, oam_buf
            ld b, 24
.h:         ld [hl], 0
            inc hl
            inc hl
            inc hl
            inc hl
            dec b
            jr nz, .h
            ret
tall_close: ld b, $FF
            call b_hand
            ld a, 96
            ldh [rWY], a
            ld bc, $060C
            call bv_grad
            call hp_win                     ; (the windows below again: the list's lines gone)
            jp chr_draw

; the list: the cursor's column (top four lines), the next one below, the hands (two)
bit_draw:    ld hl, ic_map                   ; (the icons' tiles: chosen again)
            ld b, 7
            ld a, $FF
.ic:        ld [hl+], a
            dec b
            jr nz, .ic
            ld bc, $0000
            ld de, $140A
            call w_box
            ld a, [IT_X]
            ld [btl_k], a
            ld c, 1
            call it_col
            ld a, [IT_X]
            cp 8
            jr z, .h
            inc a
            ld [btl_k], a
            ld c, 5
            call it_col
.h:         ld a, [IT_Y]                    ; the hand at the cursor (screen row 9 + line)
            add a, a
            add a, a
            add a, a
            add a, 64 + 8
            ld c, a
            ld b, 0
            call b_hand
            jp wait_vbl

; column btl_k's four rows from canvas row C
it_col:     xor a
.r:         ld [btl_n2], a
            push bc
            ld a, [btl_k]
            and a
            jr nz, .inv
            ld a, [btl_n2]                  ; column 0: labels on rows 0 / 2
            bit 0, a
            jr nz, .inv
            and a
            ld hl, lbl_r
            jr z, .lb
            ld hl, lbl_l
.lb:        push hl
            call .blank
            pop hl
            ld de, win_buf
            ld bc, 6
            call memcpy
            jr .put
.blank:     ld hl, win_buf
            ld b, 18
            ld a, $FF
.bl:        ld [hl+], a
            dec b
            jr nz, .bl
            ld [hl], 0
            ret
.inv:       ld a, [btl_k]
            add a, a
            add a, a
            add a, a
            ld b, a
            ld a, [btl_n2]
            add a, a
            add a, b
            call it_slot
            ld a, [hl+]
            ld [btl_tmp + 2], a
            ld a, [hl]
            ld [btl_tmp + 3], a
            call .blank
            xor a
            ld [it_nm], a
            ld a, [btl_tmp + 2]
            and a
            jr z, .pick
            ld a, 1
            ld [it_nm], a
            ld [it_us], a
            ld a, [btl_k]                   ; the usability mark
            add a, a
            add a, a
            ld b, a
            ld a, [btl_n2]
            add a, b
            ld e, a
            ld d, 0
            ld hl, W7 + $7B3D
            add hl, de
            ld a, [hl]
            ld [it_us], a                   ; (not usable: grey)
.pick:      ld a, [IT_SEL]                  ; the picked place: an arrow before it
            and a
            jr z, .put
            ld a, [IT_SX]
            ld b, a
            ld a, [btl_k]
            cp b
            jr nz, .put
            ld a, [IT_SY]
            ld b, a
            ld a, [btl_n2]
            cp b
            jr nz, .put
            ld a, $CA
            ld [win_buf], a
.put:       pop bc
            push bc
            ld b, 1
            call cv_line
            pop bc
            push bc
            ld a, [it_nm]
            and a
            call nz, it_str
            pop bc
            inc c
            ld a, [btl_n2]
            inc a
            cp 4
            jr nz, .r
            ret
; the item's name (icon dropped) and ":count" on row C (small font strings; grey: not usable)
it_str:     push bc
            ld a, [btl_tmp + 2]
            ld b, 0
            call bstr
            ld a, 2                         ; (the name's column: 2, after an icon 3)
            ld [it_col0], a
            ld a, [btl_str]                 ; FF3's icon ($50-$6F) in its own cell (column 2)
            cp $50
            jr c, .ni
            cp $70
            jr nc, .ni
            ld a, 3
            ld [it_col0], a
            ld a, [btl_str]
            call it_icon
            pop bc
            push bc
            ld b, 2
            call cv2
            call m_put
            call cv3
.ni:        ld hl, btl_str + 1
            ld de, btl_str
            ld bc, 31
            call memcpy
            pop bc
            push bc
            ld a, [it_us]
            and a
            ld e, BVP_W
            jr nz, .w
            ld e, BVP_L
.w:         ld a, e
            ld [it_nm], a
            ld a, [it_col0]
            ld b, a
            ld d, 16
            ld hl, btl_str
            call bv_put
            ld hl, btl_str
            ld [hl], $C8                    ; ":" and the count
            inc hl
            ld a, [btl_tmp + 3]
            ld e, a
            ld d, 0
            call bnum
            ld [hl], 0
            pop bc
            ld a, [it_nm]
            or BVF_R
            ld e, a
            ld b, 16
            ld d, 19
            ld hl, btl_str
            jp bv_put
; icon code A -> its tile ($F0-$F6: loaded once a list, MENU_BANK $5E00; $FF none left)
it_icon:    ld b, a
            ld hl, ic_map
            ld c, 0
.f:         ld a, [hl]
            cp b
            jr z, .got
            cp $FF
            jr z, .new
            inc hl
            inc c
            ld a, c
            cp 7
            jr nz, .f
            ld a, $FF
            ret
.new:       ld [hl], b
            push bc
            ld a, MENU_BANK
            ld [vc_src], a
            ld a, b                         ; ($50-$6F: the item icons at $5E00; $70-$7F: the
            sub $50                         ;   font's, the spells' among them, at $6400)
            cp $20
            ld h, $5E
            jr c, .i0
            sub $20
            ld h, $64
.i0:        swap a
            ld l, a
            and $0F
            add a, h
            ld h, a
            ld a, l
            and $F0
            ld l, a
            ld a, c
            swap a
            ld e, a
            ld d, $8F
            ld b, 1
            ld a, 1
            call vcopyx
            pop bc
.got:       ld a, c
            add a, $F0
            ret
lbl_r:      db $9B, $BE, $91, $A4, $B1, $A7, 0      ; R.Hand
lbl_l:      db $95, $BE, $91, $A4, $B1, $A7, 0      ; L.Hand

; win_buf (0-ended) at column B, row C of the canvas (no wait)
cv_line:    call cv2
            ld hl, win_buf
.l:         ld a, [hl+]
            and a
            jr z, .d
            call m_put
            inc b
            jr .l
.d:         ld a, 1
            ld [m_dirty], a
            jp cv3

section wram, $DF57                         ; (WRAM 3: after btlui.s's)
it_nm:      ds 1                            ; the line is an item (then its palette)
it_us:      ds 1                            ;   usable
ic_map:     ds 7                            ; the icons in tiles $F0-$F6
section wram, $DF50                         ; (WRAM 3: after btlmsg.s's)
it_col0:    ds 1
