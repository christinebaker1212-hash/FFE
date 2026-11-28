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
            dw sc_stat, sc_msg, sc_wait, sc_anim, sc_numw, sc_death, sc_none

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
            ld a, [W7 + $78D6]              ; (a member: its name yellow in the party window)
            bit 7, a
            jr nz, .o
            ld [btl_hl], a
            ld [btl_m], a
            ld a, [msg_full]
            and a
            call z, hp_line
            ld a, [W7 + $78D6]
            call name_of
.o:         xor a
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
.hits:      ld [btl_tmp2], a                ; n + $0633 (" hits": "1 Hit", "n Hits", the label colour)
            ld a, BVP_L
            ld [msg_pal], a
            ld a, $33
            ld b, 2
            call bstr
            ld a, [btl_str + 1]             ; (its first letter a capital: h -> H)
            sub $A4 - $8A
            ld [btl_str + 1], a
            ld a, [btl_tmp2]
            dec a
            jr nz, .hs
            ld hl, btl_str                  ; (one: the last letter off)
.he:        ld a, [hl+]
            and a
            jr nz, .he
            dec hl
            dec hl
            ld [hl], 0
.hs:
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
.o:         ld hl, btl_str + 29             ; "> " before it
            ld de, btl_str + 31
            ld b, 30
.mv:        ld a, [hl-]
            ld [de], a
            dec de
            dec b
            jr nz, .mv
            ld a, ARROW
            ld [btl_str], a
            ld a, $FF
            ld [btl_str + 1], a
            ld a, 2
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

; $0C, then the party's lines with the HP as they are now (the window under no message)
sc_numw:    call sc_num
            ld a, [msg_full]
            and a
            ret nz
            xor a
.m:         ld [btl_m], a
            call hp_line
            ld a, [btl_m]
            inc a
            cp 4
            jr nz, .m
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
.t0:        ld hl, W7 + $7CF7 + $1D         ; (sprite palette 3 for the numerals: black ring,
            ld a, $0F                       ;   white ink; the hits' animations left their colours)
            ld [hl+], a
            ld a, $10
            ld [hl+], a
            ld a, $30
            ld [hl], a
            call ba_vblc
            ld a, $17
            ld [W7 + $7EC2], a
            xor a
            ld [btl_k], a                   ; target 0-11
.batch:     call num_clear
            xor a
            ld [btl_n2], a                  ; sprites used / 4
.t:         ld a, [btl_k]
            cp 12
            jr z, .show
            call num_ent
            ld a, d
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
            call num_hop
            ld a, [btl_k]
            cp 12
            jr nz, .batch
.done:      call num_clear
            ld a, [W7 + $7EE1]              ; (the split animation: later)
            ret

; DE = the numeral of place btl_k (0-7 monster slots, 8-11 members): FF3's buffers are by side,
; $7E4F the target's ($7E6F: a monster), $7E5F the attacker's ($7E9A bit 7: a monster); the
; target's first, else the attacker's when it is on this side; $FFFF none
num_ent:    ld a, [btl_k]
            ld c, 0                         ; C = 1 for a monster place
            cp 8
            jr nc, .m
            inc c
            jr .i
.m:         sub 8
.i:         add a, a
            ld e, a
            ld d, 0
            ld a, [W7 + $7E6F]
            and a
            jr z, .t0
            ld a, 1
.t0:        cp c
            jr nz, .at
            ld hl, W7 + $7E4F
            add hl, de
            ld a, [hl+]
            ld b, a
            ld a, [hl]
            and b
            inc a
            jr nz, .rd
.at:        ld a, [W7 + $7E9A]
            rlca
            and 1
            cp c
            jr nz, .no
            ld hl, W7 + $7E5F
            add hl, de
            ld a, [hl+]
            ld b, a
            ld a, [hl]
            and b
            inc a
            jr z, .no
.rd:        dec hl
            ld a, [hl+]
            ld e, a
            ld d, [hl]
            ret
.no:        ld de, $FFFF
            ret

; 33/AD5C: the numerals hop: 32 frames, the phase 8 a frame, the height sin(phase & $7F) x the
; amplitude / 256 (10/9A80), the amplitude $40 for 16 frames, then $10 (two hops)
num_hop:    ld hl, NUM_OAM                  ; (the resting lines: btl_spr)
            ld de, btl_spr
            ld b, 16
.cy:        ld a, [hl+]
            ld [de], a
            inc de
            inc hl
            inc hl
            inc hl
            dec b
            jr nz, .cy
            xor a
            ld [btl_tmp + 2], a             ; (the phase)
            ld c, 0                         ; C = the frame
.f:         ld a, [btl_tmp + 2]
            add a, 8
            ld [btl_tmp + 2], a
            and $7F
            ld l, a
            ld h, 0
            push bc
            ld bc, CUT_SINE
            add hl, bc
            ld a, CUTD
            call rd_byte
            pop bc
            ld e, a                         ; E = sin (0-127)
            ld a, c
            cp 16
            ld d, $40
            jr c, .am
            ld d, $10
.am:        ld b, 8                         ; H = E x D >> 8
            xor a
            ld h, a
            ld l, a
.ml:        add hl, hl
            sla d
            jr nc, .mn
            push de
            ld d, 0
            add hl, de
            pop de
.mn:        dec b
            jr nz, .ml
            ld b, h                         ; B = the height
            ld hl, NUM_OAM
            ld de, btl_spr
            push bc
            ld c, 16
.sp:        ld a, [de]
            inc de
            and a
            jr z, .sn                       ; (unused)
            sub b
            jr c, .tp
            cp 16 + 1
            jr nc, .sn
.tp:        ld a, 16 + 1                    ; (not over the screen's top)
.sn:        ld [hl+], a
            inc hl
            inc hl
            inc hl
            dec c
            jr nz, .sp
            pop bc
            call wait_vbl
            inc c
            ld a, c
            cp 32
            jr nz, .f
            ld b, 8                         ; (a pause at rest)
.w:         call wait_vbl
            dec b
            jr nz, .w
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

mp_blank:   ld a, [W7 + $78C3]              ; (outside the monsters' columns: blank. FF3's effects
            cp $88                          ;   use parts of $7900 as scratch, harmless on the NES,
            ld c, 0                         ;   which never sends the buffer again; here the copy
            jr z, .bk                       ;   showed them: the blue strip by the party. A back
            ld c, 20                        ;   attack mirrors: its monsters are at the right)
.bk:        ld hl, W7 + $7900
            ld b, BT_ROWS
.br:        push hl
            ld a, l
            add a, c
            ld l, a
            ld e, 12
            xor a
.bc:        ld [hl+], a
            dec e
            jr nz, .bc
            pop hl
            ld de, 32
            add hl, de
            dec b
            jr nz, .br
            ret

; 2F/BB94 the wipe: the new tilemap over the old one, row k's column c at step c + k (25 columns
; from the left, from the right in a back attack; 2 frames a step; sound $31)
mon_wipe:   call mp_blank
            ld a, $B1
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
map_show:   call mp_blank
            ld a, CODE2
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
            ld hl, msg_op
            ld b, 5
.c:         ld [hl+], a
            dec b
            jr nz, .c
            ld a, $FF
            ld [btl_hl], a
            ld a, BVP_W
            ld [msg_pal], a
            ret

; window A (0-4) shows btl_str: 0-3 the action's lines in the left window (0 the actor, yellow;
; 1 the action; 2 "> target"; 3 the status), kept in WRAM 4 (btlvwf.s BV_NAR) so they come back
; after a message; 4 a battle message over both windows, wrapped by its width
msg_open:   ld [msg_w], a
            cp 4
            jp z, msg_full_on
            ld e, a
            ld d, 0
            ld hl, msg_op
            add hl, de
            ld [hl], 1
            ld hl, msg_pl                   ; the palette: 0 yellow, 1 msg_pal, else white
            add hl, de
            ld a, [msg_w]
            and a
            ld a, BVP_Y
            jr z, .p
            ld a, [msg_w]
            dec a
            ld a, BVP_W
            jr nz, .p
            ld a, [msg_pal]
.p:         ld [hl], a
            ld a, BVP_W
            ld [msg_pal], a
            ld a, [msg_w]
            ld hl, btl_str
            call bv_nsav
            ld a, [msg_full]
            and a
            ret nz
            ld a, [msg_w]
; window A's line from its copy
msg_line:   ld [msg_w], a
            ld e, a
            ld d, 0
            ld hl, msg_pl
            add hl, de
            ld a, [hl]
            ld e, a
            ld a, [msg_w]
            inc a
            ld c, a
            ld b, 1
            ld d, 10
            ld a, [msg_w]
            jp bv_nput

; the message window over both (once), its lines
msg_full_on: ld a, [msg_full]
            and a
            jr nz, .f
            ld a, 1
            ld [msg_full], a
.f:         ld bc, $0000
            ld de, $1406
            call w_box
; btl_str in lines of 144 pixels at rows 1-4 (at spaces; a word longer than a line cut)
msg_wput:   ld a, 1
            ld [msg_row], a
            ld hl, btl_str
.line:      ld a, [hl]                      ; (blanks at a line's start skipped)
            cp $FF
            jr nz, .l0
            inc hl
            jr .line
.l0:        and a
            ret z
            push hl                         ; (the line's start)
            ld c, 0
            ld de, 0                        ; (the last space: none)
.ch:        ld a, [hl]
            and a
            jr z, .last
            cp $FF
            jr nz, .g
            ld d, h
            ld e, l
            ld a, c
            add a, 3
            ld c, a
            inc hl
            jr .ch
.g:         push de
            call bv_cw
            pop de
            add a, c
            jr c, .brk
            cp 145 + 1
            jr nc, .brk
            ld c, a
            inc hl
            jr .ch
.brk:       ld a, d                         ; at the last space, else here
            or e
            jr z, .cut
            ld h, d
            ld l, e
.cut:       pop bc
            call msg_lput
            ld a, [msg_row]
            inc a
            ld [msg_row], a
            cp 5
            ret z
            jr .line
.last:      pop bc
            ; (fall through)
; the text from BC up to HL -> row msg_row (HL kept)
msg_lput:   push hl
            ld de, win_buf + 80
.c:         ld a, b
            cp h
            jr nz, .cp
            ld a, c
            cp l
            jr z, .e
.cp:        ld a, [bc]
            ld [de], a
            inc bc
            inc de
            ld a, e
            cp low(win_buf + 80 + 31)
            jr nz, .c
.e:         xor a
            ld [de], a
            ld a, [msg_row]
            ld c, a
            ld b, 1
            ld d, 19
            ld e, BVP_W
            ld hl, win_buf + 80
            call bv_put
            pop hl
            ret

; close window A: its line gone; the message: the windows below back (not while kept)
msg_close:  cp 4
            jr z, .m
            ld e, a
            ld d, 0
            ld hl, msg_op
            add hl, de
            ld [hl], 0
            ld a, [msg_full]
            and a
            ret nz
            ld a, e
            inc a
            ld c, a
            ld b, 0
            ld d, 10
            jp bv_clr
.m:         ld a, [msg_full]
            and a
            ret z
            ld a, [msg_keep]
            and a
            ret nz
; the windows back after a message: the party's, the action's open lines
msg_back:   call hp_win
            xor a
.l:         ld [msg_w], a
            ld e, a
            ld d, 0
            ld hl, msg_op
            add hl, de
            ld a, [hl]
            and a
            call nz, .one
            ld a, [msg_w]
            inc a
            cp 4
            jr nz, .l
            ret
.one:       ld a, [msg_w]
            push af
            call msg_line
            pop af
            ld [msg_w], a
            ret

; the end of the script: the lines gone, the windows back (a kept message stays)
msg_done:   call msg_reset
            ld a, [msg_keep]
            and a
            ret nz
            jp hp_win

section wram, $DF40
msg_op:     ds 5                ; per window 0-3: open
msg_pl:     ds 4                ;   its palette
msg_full:   ds 1                ; the message window over both
msg_keep:   ds 1                ; (the battle's end: messages replace each other, no windows between)
msg_w:      ds 1
msg_pal:    ds 1                ; the next action line's palette (the hits: the label colour)
msg_row:    ds 1
btl_hl:     ds 1                ; the member shown yellow in the party window ($FF none)
bn_f:       ds 1                ; (btlui.s bnum)
