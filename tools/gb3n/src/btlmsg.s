; ---- 34/8FF7 execute action script: FF3's script commands (34/9519 by $78D5) run as FF3 does
; (the text buffer fills, the window / queue indexes, the status merges of the death command,
; the near fatal and status updates, the monster deaths' experience and slots); shown on the GB
; as the approved layout: the five NES message windows in one full-width window over the party
; window (lines of 18; the target after the attacker behind an arrow when it fits; a window
; that finds no free line covers the last one; closing blanks its cells, the last one closed
; brings the party window back), damage numerals as sprites over the targets.


act_script: ld a, [W7 + $7EC2]
            and a
            jp z, .end
            ld a, [W7 + $78D5]              ; $62 = the script (FF3's address kept)
            add a, a
            ld e, a
            ld d, 0
            ld hl, SCRIPTS
            add hl, de
            call bd_rd
            ld [BZ + $62], a
            call bd_rd
            ld [BZ + $63], a
            xor a
            ld [BZ + $64], a
            ld [W7 + $78EE], a
            ld [W7 + $78EF], a
.cmd:       call txt_init                   ; 34/9754
            xor a
            ld hl, W7 + $7AD7
            ld b, $14
.cl:        ld [hl+], a
            dec b
            jr nz, .cl
            ld a, [BZ + $62]                ; the command: FF3's address - $950D + SCRIPTS
            ld l, a
            ld a, [BZ + $63]
            ld h, a
            ld de, SCRIPTS - $950D
            add hl, de
            ld a, [BZ + $64]
            ld e, a
            ld d, 0
            add hl, de
            call bd_rd
            ld [BZ + $4B], a
            cp $FF
            jr z, .end
            add a, a
            ld e, a
            ld d, 0
            ld hl, sc_tab
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            call .jp
            ld hl, BZ + $64
            inc [hl]
            jr .cmd
.jp:        jp hl
.end:       jp msg_done                     ; (battle graphics $25)

sc_tab:     dw sc_close, sc_close, sc_close, sc_close3, sc_close, sc_atk, sc_act, sc_tgt
            dw sc_stat, sc_msg, sc_wait, sc_anim, sc_num, sc_death, sc_none

sc_none:    ret

; 34/9754 init text buffer: $7200-$73FF = $FF
txt_init:   xor a
            ld [W7 + $7AC0], a
            ld [BZ + $4E], a
            ld [BZ + $18], a
            ld a, $72
            ld [W7 + $7AC1], a
            ld [BZ + $4F], a
            ld a, $74
            ld [BZ + $19], a
            ld hl, W7 + $7200
            ld bc, $0200
.f:         ld a, $FF
            ld [hl+], a
            dec bc
            ld a, b
            or c
            jr nz, .f
            ret

; $00 / $01 / $02 / $04: close window $4B if its value ($78D6 + id) is set
sc_close:   ld a, [BZ + $4B]
.c:         ld e, a
            ld d, 0
            ld hl, W7 + $78D6
            add hl, de
            ld a, [hl]
            cp $FF
            ret z
            ld a, e
            jp msg_close
; $03: close the status window, or another message: back to $09
sc_close3:  ld a, [W7 + $78EE]
            ld e, a
            ld d, 0
            ld hl, W7 + $78DA
            add hl, de
            ld a, [hl]
            cp $FF
            ld a, 3
            jr z, sc_close.c
            ld a, [W7 + $78D5]
            and a
            ld b, 4
            jr z, .b
            inc b
.b:         ld a, [BZ + $64]
            sub b
            ld [BZ + $64], a
            ret

; $05: the attacker's name (top left)
sc_atk:     ld a, [W7 + $78D6]
            call name_of
            ret nc
            xor a
            jp msg_open

; the name of id A (a member, monster $80 + slot) -> btl_str; carry clear: none
name_of:    bit 7, a
            jr nz, .m
            rrca                            ; member: ($57) + 64 id + 6, 6 letters
            rrca
            add a, 6
            ld c, a
            ld a, $57
            call zpy
            ld de, btl_str
            ld b, 6
.n:         ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .n
            xor a
            ld [de], a
            scf
            ret
.m:         cp $FF
            jr z, .no
            and $7F
            ld e, a
            ld d, 0
            ld hl, W7 + $7ECD
            add hl, de
            ld e, [hl]
            ld hl, W7 + $7D6B
            add hl, de
            ld a, [hl]
            cp $FF
            jr z, .no
            ld b, 1                         ; monster names $0520 +
            add a, $20
            jr nc, .s
            inc b
.s:         call bstr
            scf
            ret
.no:        and a
            ret

; $06: the action (top right): item / spell name, hits, miss, summon, battle or status message
sc_act:     ld a, [BZ + $72]
            and a
            jr z, .a
            ld a, [W7 + $78D7]              ; item names $0400 + (the icon dropped)
            ld b, 0
            call bstr
            ld hl, btl_str + 1
            ld de, btl_str
            ld bc, 31
            call memcpy
            jr .open
.a:         ld a, [W7 + $78D7]
            bit 7, a
            jr nz, .spell
            and a
            jr z, .miss
            cp $21
            jr c, .hits
            cp $39
            jr c, .summon
            cp $52
            jr c, .bmsg
            sub $46                         ; status messages: t8200 $010C + (A - $46)
            add a, $0C
            ld b, 4
            call bstr
            jr .open
.bmsg:      sub $39                         ; battle messages $0620 +
            add a, $20
            ld b, 2
            call bstr
            jr .open
.summon:    add a, $C6 + $20                ; summon names $0520 + $C6 +
            ld b, 1
            jr nc, .su
            inc b
.su:        call bstr
            jr .open
.miss:      ld a, $29                       ; $0629 Miss!
            ld b, 2
            call bstr
            jr .open
.hits:      ld [btl_tmp2], a                ; n + $0633 ("hits")
            ld a, $33
            ld b, 2
            call bstr
            ld hl, btl_str + 29             ; the string moved right by 2
            ld de, btl_str + 31
            ld b, 30
.mv:        ld a, [hl-]
            ld [de], a
            dec de
            dec b
            jr nz, .mv
            ld a, [btl_tmp2]
            ld b, $80
.d:         cp 10
            jr c, .d1
            sub 10
            inc b
            jr .d
.d1:        add a, $80
            ld [btl_str + 1], a
            ld a, b
            ld [btl_str], a
            cp $80
            jr nz, .open
            ld hl, btl_str + 1              ; (one digit)
            ld de, btl_str
            ld bc, 31
            call memcpy
            jr .open
.spell:     cp $FF
            ret z
            sub $80                         ; spell names $04C8 +
            add a, $C8
            ld b, 0
            jr nc, .sp
            inc b
.sp:        call bstr
.open:      ld a, 1
            jp msg_open

; $07: the target's name (middle left)
sc_tgt:     ld a, [W7 + $78D8]
            cp $88
            jr nz, .n
            ld a, $36                       ; $0636 (all)
            ld b, 2
            call bstr
            jr .o
.n:         call name_of
            ret nc
.o:         ld a, 2
            jp msg_open

; $08: the status message (middle right): t8200 $010C + $0C + id
sc_stat:    ld a, [W7 + $78D9]
            cp $FF
            ret z
            add a, $18
            ld b, 4
            call bstr
            ld a, 3
            jp msg_open

; $09: the next battle message of the queue, by its variable type
sc_msg:     ld a, [W7 + $78EE]
            ld e, a
            ld d, 0
            ld hl, W7 + $78DA
            add hl, de
            ld a, [hl]
            cp $FF
            ret z
            ld [btl_tmp2], a
            srl a                           ; the type: 34/9575 + id / 2, high nibble if even
            ld e, a
            ld hl, SCR_TYPES
            add hl, de
            call bd_rd
            ld b, a
            ld a, [btl_tmp2]
            and 1
            ld a, b
            jr nz, .lo
            swap a
.lo:        and $0F
            ld [btl_tmp2 + 1], a
            ld a, [btl_tmp2]                ; battle messages $0620 +
            add a, $20
            ld b, 2
            jr nc, .s
            inc b
.s:         call bstr
            ld a, [btl_tmp2 + 1]
            cp 3
            jr z, .num
            cp 4
            jr z, .item
            cp 2
            jr nz, .show
            ld hl, W7 + $78EF               ; (peep: the two hp values used up; shown later)
            inc [hl]
            inc [hl]
            inc [hl]
            inc [hl]
            jr .show
.item:      call .save
            ld a, [W7 + $78E4]              ; the item's name ($78E4) in front
            ld b, 0
            call bstr
            ld hl, btl_str + 1
            ld de, btl_str
            ld bc, 31
            call memcpy
            ld a, $FF
            ld [btl_str + 15], a
            xor a
            ld [btl_str + 16], a
            jr .cat
.num:       call .save                      ; the number ($78E4 + $78EF) in front
            ld a, [W7 + $78EF]
            ld e, a
            ld d, 0
            ld hl, W7 + $78E4
            add hl, de
            ld a, [hl+]
            ld e, a
            ld d, [hl]
            ld hl, W7 + $78EF
            inc [hl]
            inc [hl]
            call dec5
.cat:       call .end0                      ; the message appended
            ld hl, win_buf + 40
.c:         ld a, [hl+]
            ld [de], a
            inc de
            and a
            jr nz, .c
.show:      ld a, 4
            call msg_open
            ld a, [btl_tmp2 + 1]
            and a
            call nz, b_waitA
            ld hl, W7 + $78EE
            inc [hl]
            ret
; DE = the end (0) of btl_str
.end0:      ld de, btl_str
.e:         ld a, [de]
            and a
            ret z
            inc de
            jr .e
; btl_str -> win_buf + 40
.save:      ld hl, btl_str
            ld de, win_buf + 40
            ld bc, 32
            jp memcpy

; DE in decimal at btl_str (no leading zeros; 5 cells at most), 0-ended
dec5:       ld hl, btl_str + 5
            ld [hl], 0
            ld b, 5
.l:         push bc
            push hl
            call b_div10
            pop hl
            pop bc
            add a, $80
            dec hl
            ld [hl], a
            dec b
            ld a, d
            or e
            jr nz, .l
            ld de, btl_str                  ; (moved to the start)
.m:         ld a, [hl+]
            ld [de], a
            inc de
            and a
            jr nz, .m
            ret

; A or the message time: (8 - speed) x 8 frames
sc_wait:    ld a, [GS + $10]
            ld b, a
            ld a, 8
            sub b
            add a, a
            add a, a
            add a, a
            ld [BZ + $24], a
            and a
            ret z
.w:         call b_keys
            ld a, [btl_new]
            bit 0, a
            ret nz
            ld hl, BZ + $24
            dec [hl]
            jr nz, .w
            ret
b_waitA:    call b_keys
            ld a, [btl_new]
            bit 0, a
            jr z, b_waitA
            ret

; $0B: the attack animation (34/8411: btlanim.s)
sc_anim:    jp ba_show

; $0C: the damage numerals ($7E4F: monsters 2 x slot, members $7E5F + 2 x id; $FFFF none,
; hi bit 6 miss, bit 7 restored): up to 4 targets at a time, 40 frames each
sc_num:     ld a, [ba_dirty]                ; (an animation used their tiles: loaded again)
            and a
            jr z, .t0
            xor a
            ld [ba_dirty], a
            ld a, BDATA_BANK
            ld [vc_src], a
            ld hl, $7000
            ld de, $8000 + 16 * NUM_T
            ld b, 13
            ld a, 1
            call vcopyx
.t0:        ld a, $17
            ld [W7 + $7EC2], a
            xor a
            ld [btl_k], a                   ; target 0-11
.batch:     call num_clear
            xor a
            ld [btl_n2], a                  ; sprites used / 4
.t:         ld a, [btl_k]
            cp 12
            jr z, .show
            add a, a
            ld e, a
            ld d, 0
            ld hl, W7 + $7E4F
            add hl, de
            ld a, [hl+]
            ld e, a
            ld a, [hl]
            ld d, a
            and e
            inc a
            jr z, .nx                       ; ($FFFF: none)
            call num_one
            ld hl, btl_k
            inc [hl]
            ld a, [btl_n2]
            cp 4
            jr nz, .t
            jr .show
.nx:        ld hl, btl_k
            inc [hl]
            jr .t
.show:      ld a, [btl_n2]
            and a
            jr z, .done
            ld b, 40
.w:         call wait_vbl
            dec b
            jr nz, .w
            ld a, [btl_k]
            cp 12
            jr nz, .batch
.done:      call num_clear
            ld a, [W7 + $7EE1]              ; (the split animation: later)
            ret

num_clear:  ld hl, NUM_OAM
            ld b, 16
.c:         xor a
            ld [hl+], a
            inc hl
            inc hl
            inc hl
            dec b
            jr nz, .c
            ret

; one numeral: DE (hi bits 6 / 7: miss / restored) for target btl_k, sprites btl_n2 x 4
num_one:    push de
            call num_xy                     ; B = x, C = y (the numeral's centre)
            pop de
            ld a, d
            bit 6, a
            jr z, .v
            ld hl, btl_str                  ; Miss
            ld a, NUM_T + 10
            ld [hl+], a
            inc a
            ld [hl+], a
            inc a
            ld [hl+], a
            ld [hl+], a
            ld a, 4
            jr .put
.v:         and $3F
            ld d, a
            push bc
            call dec5
            pop bc
            ld hl, btl_str
            ld e, 0
.cv:        ld a, [hl]
            and a
            jr z, .cn
            sub $80 - NUM_T
            ld [hl+], a
            inc e
            jr .cv
.cn:        ld a, e
.put:       ld e, a                         ; E = length: x from centre - 4 length
            add a, a
            add a, a
            ld d, a
            ld a, b
            sub d
            ld b, a
            ld a, [btl_n2]                  ; OAM 24 + 4 n
            add a, a
            add a, a
            add a, a
            add a, a
            add a, low(NUM_OAM)
            ld l, a
            ld h, high(NUM_OAM)
            push hl
            push de
.s:         ld a, c
            ld [hl+], a
            ld a, b
            ld [hl+], a
            add a, 8
            ld b, a
            inc hl
            ld a, 3 | 8
            ld [hl+], a
            dec e
            jr nz, .s
            pop de
            pop hl
            inc hl
            inc hl
            ld bc, btl_str
.t:         ld a, [bc]
            inc bc
            ld [hl+], a
            inc hl
            inc hl
            inc hl
            dec e
            jr nz, .t
            ld hl, btl_n2
            inc [hl]
            ret

; the numeral's centre (OAM coordinates) for target btl_k: B = x, C = y
num_xy:     ld a, [btl_k]
            cp 8
            jr nc, .m
            ld c, a                         ; monster slot: its tilemap rectangle
            call pos_ptr
            ld a, c
            add a, a
            add a, c
            ld e, a
            ld d, 0
            add hl, de
            call bd_rd
            ld [btl_tmp], a                 ; col
            call bd_rd
            ld [btl_tmp + 1], a             ; row
            call bd_rd
            add a, a
            add a, low(TB_SIZE)
            ld l, a
            ld h, high(TB_SIZE)
            call bd_rd
            ld b, a                         ; w
            call bd_rd                      ; h
            ld c, a
            call back_atk                   ; (a back attack: the mirrored columns)
            jr nz, .nb
            ld a, [btl_tmp]
            add a, b
            ld d, a
            ld a, 32
            sub d
            ld [btl_tmp], a
.nb:
            ld a, [btl_tmp]                 ; x = (col + w / 2) x 8 - 20 + 8
            add a, a
            add a, a
            add a, a
            ld d, a
            ld a, b
            add a, a
            add a, a
            add a, d
            call sub_scx8
            ld b, a
            ld a, [btl_tmp + 1]             ; y = (row + h / 2) x 8 - 48 + 16
            add a, a
            add a, a
            add a, a
            ld d, a
            ld a, c
            add a, a
            add a, a
            add a, d
            sub 32
            ld c, a
            ret
.m:         sub 8                           ; member: left of its sprite
            ld b, a
            add a, a
            add a, b
            add a, a
            add a, a
            add a, a                        ; 24 member -> its first sprite
            ld l, a
            ld h, high(oam_buf)
            ld a, l
            add a, low(oam_buf)
            ld l, a
            ld a, [hl+]
            add a, 8
            ld c, a
            ld a, [hl]
            sub 12
            ld b, a
            ret

; $0D: the death command: status buffers merged into the records, near fatal, display status,
; then the deaths (34/8411 animation $0E)
sc_death:   ld a, [W7 + $78D3]
            and 2
            ret nz
            call atk_flags
            bit 7, a
            jr nz, .ma
            ld c, $30
            ld a, $6E
            call zpy
            bit 7, [hl]
            jr nz, .cm
            ld a, $E0                       ; member -> member
            call st_chr
            ld a, $F0
            call st_chr
            jr .u
.cm:        ld a, $F0                       ; member -> monster
            call st_chr
            ld a, $E0
            call st_mon
            jr .u
.ma:        ld c, $30
            ld a, $6E
            call zpy
            bit 7, [hl]
            jr nz, .mm
            ld a, $E0                       ; monster -> member
            call st_chr
            ld a, $F0
            call st_mon
            jr .u
.mm:        ld a, $F0                       ; monster -> monster
            call st_mon
            ld a, $E0
            call st_mon
.u:         call near_fatal
            call stat_disp_all
            ; (fall through)
; 34/8411 animation $0E (the death animations) and 2F/BB0A: the deaths' experience, slots
mon_deaths: ld a, $16
            ld [W7 + $7EC2], a
            ld hl, W7 + $7EC4
            ld de, W7 + $7DA7
            ld b, 8
.f:         ld a, [hl+]
            bit 7, a
            jr z, .n
            ld a, [de]
            cp $FF
            jr nz, .die
.n:         inc de
            dec b
            jr nz, .f
            ret
.die:       ld hl, W7 + $7EC4               ; 34/84C7: $7E = the dead ones (slot 0 the msb)
            ld b, 8
            xor a
.g:         ld c, a
            ld a, [hl+]
            rla
            ld a, c
            rla
            dec b
            jr nz, .g
            ld [BZ + $7E], a
            ld [W7 + $7DCA], a              ; 2F/BAEE: the experience counts
            ld c, a
            ld b, 0
.x:         sla c
            jr nc, .x1
            push bc
            ld hl, W7 + $7DA7
            ld e, b
            ld d, 0
            add hl, de
            ld a, [hl]
            cp $FF
            jr z, .x0
            ld e, a
            ld hl, W7 + $7DD3
            add hl, de
            inc [hl]
.x0:        pop bc
.x1:        inc b
            ld a, b
            cp 8
            jr nz, .x
mon_gone:   ld a, $0F                       ; 2F/BB5E: the animation palette black,
            ld hl, W7 + $7D13
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl], a
            ld a, [W7 + $7DCA]              ;   the slots cleared, the tilemap rebuilt
            ld [BZ + $7E], a
            ld c, a
            ld hl, W7 + $7DA7
            ld b, 8
.c:         sla c
            jr nc, .c1
            ld [hl], $FF
.c1:        inc hl
            dec b
            jr nz, .c
            ld hl, W7 + $7900               ; 2F/A362
            ld de, 32 * 14
            call memclr
            ld hl, W7 + $7916               ; 2F/BB13
            ld c, 14
.r:         ld b, 10
            push hl
.r1:        ld [hl], 1
            inc hl
            dec b
            jr nz, .r1
            pop hl
            ld de, 32
            add hl, de
            dec c
            jr nz, .r
            call mon_pos
            call mon_count
            call mon_wipe
            jp map_show

; 2F/BB94 the wipe: the new tilemap over the old one, row k's column c at step c + k (25 columns
; from the left, from the right in a back attack; 2 frames a step; sound $31)
mon_wipe:   ld a, $B1
            ld [S49], a
            ld c, 0
.s:         call wait_vbl
            ld b, 0
.r:         ld a, c
            sub b
            jr c, .n
            cp 25
            jr nc, .n
            ld e, a
            ld a, [W7 + $78C3]
            cp $88
            jr nz, .f
            ld a, 31
            sub e
            ld e, a
.f:         push bc
            ld l, b                         ; offset 32 row + column
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld d, 0
            add hl, de
            push hl
            ld de, W7 + $7900
            add hl, de
            ld a, [hl]
            pop hl
            ld de, $9800
            add hl, de
            ld b, a
.w:         ldh a, [rSTAT]                  ; (VRAM: not while drawing)
            and 2
            jr nz, .w
            ld [hl], b
            pop bc
.n:         inc b
            ld a, b
            cp BT_ROWS
            jr nz, .r
            call wait_vbl
            inc c
            ld a, c
            cp 25 + BT_ROWS
            jr nz, .s
            ret

; 2F/B34D monsters run away (mask A): as their deaths, without experience
mon_run:    ld [W7 + $7DCA], a
            jr mon_gone
; the dying monsters (mask A, slot 0 the msb) fade: their palettes stepped to black (4 x 4
; frames; FF3 dissolves them), A kept
mon_vanish: push af
            ld b, 16
.w:         call wait_vbl
            dec b
            jr nz, .w
            pop af
            ret

; the tilemap $7900 -> the BG map (rows 0-13; 28 x 16 bytes in the vblanks)
map_show:   ld a, CODE2
            ld [vc_src], a
            ld hl, W7 + $7900
            ld de, $9800
            ld b, 28
            xor a
            jp vcopyx

; 34/93CD: the members' status from the buffer at zero page A ($E0 / $F0)
st_chr:     ld [BZ + $18], a
            xor a
            ld [BZ + $19], a
            ld [BZ + $52], a
.m:         call chr_ofs
            inc a
            ld [BZ + $1A], a
            ld a, [BZ + $52]
            add a, a
            ld e, a
            ld a, [BZ + $18]
            add a, e
            ld e, a
            ld d, high(BZ)
            ld a, [BZ + $1A]
            ld c, a
            push de
            ld a, $5B
            call zpy
            pop de
            ld a, [de]
            or [hl]
            ld [hl], a
            bit 7, a
            jr z, .s2
            res 0, [hl]
            jr .n
.s2:        inc de
            inc hl
            ld a, [de]
            or [hl]
            ld [hl], a
.n:         ld a, [BZ + $52]
            inc a
            ld [BZ + $52], a
            cp 4
            jr nz, .m
            ret

; 34/9408: the monsters' status from the buffer at zero page A
st_mon:     ld [BZ + $18], a
            xor a
            ld [BZ + $19], a
            ld [BZ + $1C], a
            ld hl, W7 + $7675
.m:         push hl
            ld a, [BZ + $1C]
            add a, a
            ld [BZ + $1A], a
            ld e, a
            ld a, [BZ + $18]
            add a, e
            ld e, a
            ld d, high(BZ)
            inc hl
            ld a, [de]
            or [hl]
            ld [hl], a
            and $E8                         ; (FF3 keeps only these bits then)
            jr z, .s2
            or $80
            ld [hl], a
            push hl
            push af
            ld a, [BZ + $1C]
            ld c, a
            ld b, 0
            ld hl, W7 + $7EC4
            add hl, bc
            pop af
            ld [hl], a
            pop hl
.s2:        inc de
            inc hl
            ld a, [de]
            or [hl]
            ld [hl], a
            pop hl
            ld de, $40
            add hl, de
            ld a, [BZ + $1C]
            inc a
            ld [BZ + $1C], a
            cp 8
            jr nz, .m
            ld a, l                         ; ($1E / $1F as FF3 leaves them)
            ld [BZ + $1E], a
            ld a, h
            ld [BZ + $1F], a
            ret

; ---- the message window
msg_reset:  xor a
            ld [msg_n], a
            ld [msg_lines], a
            ld [msg_rest], a
            ld a, $FF
            ld hl, msg_wl2
            ld b, 5
.c2:        ld [hl+], a
            dec b
            jr nz, .c2
            ld hl, msg_wl
            ld b, 5
.c:         ld [hl+], a
            dec b
            jr nz, .c
            ret

; open window A (0-4) with btl_str
msg_open:   ld [msg_w], a
            ld a, [msg_n]
            and a
            call z, msg_frame
            ld a, [msg_w]                   ; (opened again: the old cells first)
            call msg_close
            call msg_wrap
            ld hl, btl_str                  ; the length (18 at most)
            ld b, 0
.l:         ld a, [hl+]
            and a
            jr z, .l1
            inc b
            ld a, b
            cp 18
            jr nz, .l
.l1:        ld a, b
            ld [msg_len], a
            ld a, [msg_w]                   ; the target behind the attacker's name
            cp 2
            jr nz, .free
            ld a, [msg_wl]
            cp $FF
            jr z, .free
            ld [msg_tmp], a                 ; (its line)
            ld a, [msg_alen]
            ld c, a
            ld a, [msg_len]
            add a, c
            inc a
            cp 19
            jr nc, .free
            ld a, [msg_tmp]
            ld [msg_wl + 2], a
            ld a, c
            ld [msg_wc + 2], a              ; (from the arrow's column)
            ld b, c
            jr .put
.free:      ld a, [msg_lines]               ; the first free line, else the last
            ld e, a
            ld c, 0
            ld b, 1
.f:         ld a, e
            and b
            jr z, .got
            sla b
            inc c
            ld a, c
            cp 4
            jr nz, .f
            ld c, 3
            ld b, 8
            ld a, 3                         ; (covered: whoever had it loses it)
            call msg_owner
.got:       ld a, [msg_lines]
            or b
            ld [msg_lines], a
            ld a, c
            ld [msg_tmp], a
            ld a, [msg_w]
            ld e, a
            ld d, 0
            ld hl, msg_wl
            add hl, de
            ld [hl], c
            ld hl, msg_wc
            add hl, de
            ld [hl], 0
            and a
            jr nz, .nb
            ld a, [msg_len]                 ; (the attacker: its length kept)
            ld [msg_alen], a
.nb:        ld b, 0
.put:       ld de, win_buf                  ; B = column: the arrow first (if not 0)
            ld a, b
            and a
            jr z, .cp
            ld a, ARROW
            ld [de], a
            inc de
.cp:        ld hl, btl_str
            ld a, [msg_len]
            ld c, a
            and a
            jr z, .z
.c:         ld a, [hl+]
            ld [de], a
            inc de
            dec c
            jr nz, .c
.z:         xor a
            ld [de], a
            ld hl, msg_n
            inc [hl]
            ld a, [msg_tmp]                 ; row 1 + line, column 1 + B
            inc a
            ld c, a
            inc b
            call msg_text
            ld a, [msg_rest]                ; the rest of a wrapped text: a line of its own
            and a
            ret z
            ld hl, msg_rest
            ld de, btl_str
            ld bc, 20
            call memcpy
            xor a
            ld [msg_rest], a
            call msg_free
            ld a, [msg_w]
            ld e, a
            ld d, 0
            ld hl, msg_wl2
            add hl, de
            ld [hl], c
            push bc
            ld hl, btl_str
            ld de, win_buf
            ld b, 18
.r:         ld a, [hl+]
            ld [de], a
            inc de
            and a
            jr z, .r1
            dec b
            jr nz, .r
            xor a
            ld [de], a
.r1:        pop bc
            inc c
            ld b, 1
            jp msg_text

; a text longer than 18: cut at its last space within 19 cells, the rest -> msg_rest
msg_wrap:   xor a
            ld [msg_rest], a
            ld hl, btl_str
            ld b, 0
.l:         ld a, [hl+]
            and a
            ret z
            inc b
            ld a, b
            cp 19
            jr c, .l
            ld hl, btl_str + 18             ; the last space at or before cell 18
            ld b, 18
.s:         ld a, [hl]
            cp $FF
            jr z, .cut
            dec hl
            dec b
            jr nz, .s
            ld hl, btl_str + 18             ; (none: cut at 18)
            ld a, [hl]
            push hl
            ld de, msg_rest
            jr .cp
.cut:       push hl
            inc hl
            ld de, msg_rest
.cp:        ld c, 19
.c:         ld a, [hl+]
            ld [de], a
            inc de
            and a
            jr z, .e
            dec c
            jr nz, .c
            xor a
            ld [de], a
.e:         pop hl
            ld [hl], 0
            ret

; the first free line -> C (its bit set), else the last (its owners lose it)
msg_free:   ld a, [msg_lines]
            ld e, a
            ld c, 0
            ld b, 1
.f:         ld a, e
            and b
            jr z, .got
            sla b
            inc c
            ld a, c
            cp 4
            jr nz, .f
            ld c, 3
            ld b, 8
            ld a, 3
            push bc
            call msg_owner
            pop bc
.got:       ld a, [msg_lines]
            or b
            ld [msg_lines], a
            ret

; whoever owns line A (whole line) loses it
msg_owner:  ld hl, msg_wl
            ld e, 5
.l:         cp [hl]
            jr nz, .n
            ld [hl], $FF
.n:         inc hl
            dec e
            jr nz, .l
            ret

; close window A: its cells blanked; the last one: the party window back
msg_close:  push af
            call msg_blank
            pop af
            ld e, a
            ld d, 0
            ld hl, msg_wl
            add hl, de
            ld a, [hl]
            cp $FF
            ret z
            ld [hl], $FF
            ld hl, msg_n
            dec [hl]
            ret

; the cells of window A blanked (its line freed if it starts the line; its second line too)
msg_blank:  push af
            ld e, a
            ld d, 0
            ld hl, msg_wl2
            add hl, de
            ld a, [hl]
            cp $FF
            jr z, .one
            ld [hl], $FF
            ld c, a
            call msg_unline
            ld b, 0
            call msg_clr
.one:       pop af
            ld e, a
            ld d, 0
            ld hl, msg_wl
            add hl, de
            ld a, [hl]
            cp $FF
            ret z
            ld c, a
            ld hl, msg_wl + 5
            add hl, de
            ld b, [hl]
            ld a, b
            and a
            jr nz, .k
            call msg_unline                 ; (the whole line: freed)
.k:         ; (fall through)
; line C blanked from column B
msg_clr:    ld hl, win_buf                  ; blanks from column B to 17
            ld a, 18
            sub b
            ld d, a
.b:         ld [hl], $FF
            inc hl
            dec d
            jr nz, .b
            ld [hl], 0
            inc c
            inc b
            jp msg_text

; line C's bit freed
msg_unline: push bc
            ld a, c
            inc a
            ld d, a
            ld a, $80
.s:         rlca
            dec d
            jr nz, .s
            cpl
            ld d, a
            ld a, [msg_lines]
            and d
            ld [msg_lines], a
            pop bc
            ret

; the window's frame and empty lines
msg_frame:  call cv2
            ld bc, $0000
            ld de, $1406
            call b_box
            ld c, 1
.r:         ld b, 1
.k:         ld a, $FF
            call m_put
            inc b
            ld a, b
            cp 19
            jr nz, .k
            inc c
            ld a, c
            cp 5
            jr nz, .r
            xor a
            ld [msg_lines], a
            jr msg_text.dirty

; win_buf (0-ended) at column B, row C of the canvas
msg_text:   call cv2
            ld hl, win_buf
.l:         ld a, [hl+]
            and a
            jr z, .dirty
            call m_put
            inc b
            jr .l
.dirty:     ld a, 1
            ld [m_dirty], a
            call cv3
            jp wait_vbl

; the end of the script: the windows gone, the party window back
msg_done:   call msg_reset
            jp hp_win

section wram, $DF40
msg_wl:     ds 5                ; per window: line (FF: closed)
msg_wc:     ds 5                ; and first column (0: the whole line)
msg_n:      ds 1                ; windows open
msg_lines:  ds 1                ; lines in use (bits 0-3)
msg_w:      ds 1
msg_len:    ds 1
msg_tmp:    ds 1
msg_alen:   ds 1
msg_wl2:    ds 5                ; per window: a wrapped text's second line (FF: none)

section wram, $DF00
msg_rest:   ds 20               ; (WRAM bank 3, FF3's unused $7F00-: the flash's copy is gone)
