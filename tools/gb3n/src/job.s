; ---- the Job menu (FF3 3C/962F; owner's choice J1): name + job, Capacity on top; the open jobs one
; a row (condensed name, job level, CP cost: 3D/AD85), 12 a page (left / right); A on another job:
; the checks of 3D/AE23 (level, no equipment, capacity: $013A / $0171 / $0172), "Change jobs?"
; ($0170: A yes), then the change (3D/AB8F: CP paid, the job levels swapped, the new job's base
; stats and MP growth replayed level by level from 39/8000 and the level tables of 3D/AD59)
JB_T       = $90                ; VRAM bank 1: the page's condensed job names ($90-$DF)

job_menu:   ld [m_i], a
            rrca
            rrca
            ld [m_ch], a
            ld [mg_caster], a
            call jb_savexp                  ; (3C/96BA)
            call jb_costs
            call jb_count
            ld a, [m_ch]                    ; (the cursor on the current job)
            ld l, a
            ld h, high(GS + $100)
            ld a, [hl]
            ld [jb_cur], a
.draw:      call jb_draw
.l:         ld a, [jb_cur]                  ; the hand: row 5 + (job mod 12)
            ld b, a
            cp 12
            jr c, .r
            sub 12
.r:         add a, 5
            add a, a
            add a, a
            add a, a
            add a, 16 - 4
            ld c, a
            ld b, 8
            call cursor_at
            call wait_vbl
            call read_pad
            call m_keys
            ld a, [m_new]
            bit 1, a
            jr nz, .out
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
            jr z, .lr
            ld c, a
            ld a, [jb_n]
            dec a
            cp c
            jr z, .l
            ld a, c
            inc a
            jr .s
.lr:        ld c, a                         ; left / right: the other page
            ld a, b
            and $30
            jr z, .l
            ld a, c
            cp 12
            jr nc, .p1
            add a, 12
            ld c, a
            ld a, [jb_n]
            dec a
            cp c
            jr c, .l
            ld a, c
            jr .s
.p1:        sub 12
.s:         ld b, a                         ; (a page change redraws)
            ld a, [jb_cur]
            cp 12
            ld a, 0
            rla
            ld c, a
            ld a, b
            ld [jb_cur], a
            cp 12
            ld a, 0
            rla
            cp c
            jr z, .l
            jr .draw
.out:       ld a, [m_i]                     ; (3C/961C: the values again)
            call eq_calc
            jp cur_hide
.a:         ld a, [jb_cur]
            ld b, a
            ld a, [m_ch]
            ld l, a
            ld h, high(GS + $100)
            ld a, [hl]
            cp b
            jr z, .l                        ; (the current job)
            ld a, b
            call jb_load                    ; 3D/AE23
            ld a, [m_ch]
            ld l, a
            ld h, high(GS + $100)
            inc l
            ld a, [hl]
            ld b, a
            ld a, [jb_new + 1]
            ld c, a
            ld a, b
            cp c
            ld a, $3A
            jr c, .msg
            ld a, [jb_cur]                  ; (owner: equipment no longer refuses the change
                                            ;   (FF3's $71): it is taken off with it, below)
            ld e, a
            ld d, 0
            ld hl, jb_cost                  ; (16-bit: the table may cross a page)
            add hl, de
            ld b, [hl]
            ld a, [GS + $1B]
            cp b
            ld a, $72
            jr c, .msg
            ld a, $70                       ; "Change jobs?" A: yes
            call m_msgbox
            ldh a, [pad]
            bit 0, a
            jp z, .draw
            call jb_unequip                 ; (all the equipment to the bag first; a full bag:
            ld a, $71                       ;   FF3's message, no change)
            jr c, .msg
            call jb_change
            ld a, [m_ch]                    ; (the member's values without it)
            rlca
            rlca
            and 3
            call eq_calc
            jr .out
.msg:       call m_msgbox
            jp .draw

; ---- for the rebuilt Job screen (jbm.s, CODE11): FF3's rules, no drawing
; A = member: costs, the open jobs (jb_n), jb_cur = the current job
jbx_initt:  ld a, [mgm_t]
jbx_init:   ld [m_i], a
            rrca
            rrca
            ld [m_ch], a
            ld [mg_caster], a
            call jb_savexp                  ; (3C/96BA)
            call jb_costs
            call jb_count
            ld a, [m_ch]
            ld l, a
            ld h, high(GS + $100)
            ld a, [hl]
            ld [jb_cur], a
            ret
; job jb_cur: may the member change to it? (3D/AE23) u_eres 0 (ask), 1 (the current job), $3A (the
; level: not enough experience), $72 (not enough Capacity)
jbx_try:    ld a, 1
            ld [u_eres], a
            ld a, [jb_cur]
            ld b, a
            ld a, [m_ch]
            ld l, a
            ld h, high(GS + $100)
            ld a, [hl]
            cp b
            ret z
            ld a, b
            call jb_load
            ld a, [m_ch]
            ld l, a
            ld h, high(GS + $100)
            inc l
            ld a, [hl]
            ld b, a
            ld a, [jb_new + 1]
            ld c, a
            ld a, b
            cp c
            ld a, $3A
            jr c, .r
            ld a, [jb_cur]
            ld e, a
            ld d, 0
            ld hl, jb_cost
            add hl, de
            ld b, [hl]
            ld a, [GS + $1B]
            cp b
            ld a, $72
            jr c, .r
            xor a
.r:         ld [u_eres], a
            ret
; the change (jbx_try passed): the equipment off (u_eres $71 if the bag is full), the job (3D/AB8F),
; the member's values again
jbx_do:     call jb_unequip
            ld a, $71
            jr c, .r
            call jb_change
            ld a, [m_ch]
            rlca
            rlca
            and 3
            call eq_calc
            xor a
.r:         ld [u_eres], a
            ret
; job A's cost (jb_cost) and level (+1) for the member -> B, C
jbx_rowt:   ld a, [mgm_t]
jbx_row:    ld e, a
            ld d, 0
            ld hl, jb_cost
            add hl, de
            ld b, [hl]
            add a, a
            ld e, a
            ld a, [m_ch]
            add a, $10
            add a, e
            ld l, a
            ld h, high(GS + $200)
            ld c, [hl]
            inc c
            ret

; owner (2026-11-28): a job change takes off all the member's equipment (the five slots into the
; bag, as the Equip screen's Remove); carry if the bag is full (what fitted stays off)
jb_unequip: xor a
.r:         push af
            call e_take
            pop bc
            ret c
            ld a, b
            inc a
            cp 5
            jr nz, .r
            and a
            ret

; 3C/96BA: the current job's level / EXP into its slot ($6210 + 2 job)
jb_savexp:  ld a, [m_ch]
            ld l, a
            ld h, high(GS + $100)
            ld a, [hl]
            add a, a
            add a, l
            ld e, a
            ld d, high(GS + $200)
            ld a, e
            add a, $10
            ld e, a
            ld a, l
            add a, $10
            ld l, a
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl]
            ld [de], a
            ret

; fix:F38A: the open jobs (the crystals in $6021) -> jb_n (count)
jb_count:   ld a, [GS + $21]
            and $1F
            ld b, 0
            srl a
            jr nc, .x
            ld b, 5
            srl a
            jr nc, .x
            ld b, 9
            srl a
            jr nc, .x
            ld b, $10
            srl a
            jr nc, .x
            ld b, $13
            srl a
            jr nc, .x
            ld b, 21                        ; (FF3: $30; the list ends at the last job)
.x:         ld a, b
            inc a
            ld [jb_n], a
            ret

; A = job -> jb_new (8 bytes: 39/8000 + 8 job)
jb_load:    ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, $4000
            add hl, de
            ld de, jb_new
            ld bc, 8
            ld a, JOB_BANK
            jp rd_copy

; 3D/AD85: each job's cost = |physical diff| + |lawful diff| of the nibbles, x 4, - its job level
jb_costs:   ld a, [m_ch]
            ld l, a
            ld h, high(GS + $100)
            ld a, [hl]
            call jb_load
            ld a, [jb_new]
            ld [jb_oldf], a
            xor a
.j:         ld [jb_j], a
            call jb_load
            ld a, [jb_new]                  ; physical nibble difference
            swap a
            and $0F
            ld b, a
            ld a, [jb_oldf]
            swap a
            and $0F
            sub b
            jr nc, .p
            cpl
            inc a
.p:         ld c, a
            ld a, [jb_new]                  ; lawful nibble difference
            and $0F
            ld b, a
            ld a, [jb_oldf]
            and $0F
            sub b
            jr nc, .q
            cpl
            inc a
.q:         add a, c
            add a, a
            add a, a
            ld c, a
            ld a, [jb_j]                    ; - the job level ($6210 + 2 job)
            add a, a
            ld b, a
            ld a, [m_ch]
            add a, $10
            add a, b
            ld l, a
            ld h, high(GS + $200)
            ld b, [hl]
            ld a, c
            sub b
            jr nc, .c
            xor a
.c:         ld c, a
            ld a, [jb_j]
            add a, low(jb_cost)
            ld l, a
            ld h, high(jb_cost)
            ld [hl], c
            ld a, [jb_j]
            inc a
            cp 23
            jr nz, .j
            ret

; the screen (J1)
jb_draw:    call m_clear
            ld bc, $0000
            ld de, $1404
            call m_box
            ld a, [m_ch]
            add a, 6
            ld l, a
            ld h, high(GS + $100)
            ld bc, $0101
            ld e, 6
            call m_codes
            ld bc, $0801                    ; (the job name tiles: JOB_T + 12 m, from menu_open)
            call st_job
            ld hl, s_cap
            ld bc, $0102
            call m_str
            ld a, [GS + $1B]
            ld e, a
            ld d, 0
            ld bc, $1102
            call m_dec
            ld bc, $1202
            ld a, $8C                       ; "C"
            call m_put
            ld bc, $0004
            ld de, $140E
            call m_box
            ld a, [jb_cur]                  ; the page
            cp 12
            ld a, 0
            jr c, .p0
            ld a, 12
.p0:        ld [jb_j], a
            ld a, JB_T
            ld [jb_t], a
            ld c, 5
.row:       ld a, [jb_n]
            ld b, a
            ld a, [jb_j]
            cp b
            jr nc, .done
            push bc
            call jb_row
            pop bc
            inc c
            ld hl, jb_j
            inc [hl]
            ld a, c
            cp 17
            jr nz, .row
.done:      ld a, 1
            ld [m_dirty], a
            ret
; job jb_j at row C: name tiles (from MENU_BANK $4000 + 192 job), level, cost
jb_row:     ld a, c
            ld [jb_rc], a
            ld a, [jb_j]                    ; tiles -> VRAM bank 1 jb_t..
            ld l, a
            ld h, 0
            ld b, h
            ld c, l
            add hl, hl
            add hl, bc
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, $4000
            add hl, de
            ld a, [jb_t]
            swap a
            ld e, a
            and $F0
            ld d, a
            ld a, e
            and $0F
            add a, $80
            ld e, d
            ld d, a
            push bc
            ld a, [jb_j]
            add a, low(MD_COUNTS)
            ld c, a
            ld a, high(MD_COUNTS)
            adc a, 0
            ld b, a
            ld a, [bc]
            ld [jb_nt], a
            ld b, a
            ld a, MENU_BANK
            ld [vc_src], a
            ld a, 1
            call vcopyx
            pop bc
            ld a, [jb_rc]
            ld c, a
            ld a, PAL_TXT | 8
            ld [m_attr], a
            ld b, 2
            ld a, [jb_nt]
            ld e, a
            ld a, [jb_t]
.t:         call m_put2
            inc a
            inc b
            dec e
            jr nz, .t
            ld [jb_t], a
            ld a, PAL_TXT
            ld [m_attr], a
            ld a, [jb_j]                    ; job level ($6210 + 2 job) + 1
            add a, a
            ld b, a
            ld a, [m_ch]
            add a, $10
            add a, b
            ld l, a
            ld h, high(GS + $200)
            ld e, [hl]
            inc e
            ld d, 0
            ld b, 12
            call m_dec
            ld b, 14
            ld a, $C8                       ; ":"
            call m_put
            ld a, [jb_j]
            add a, low(jb_cost)
            ld l, a
            ld h, high(jb_cost)
            ld e, [hl]
            ld d, 0
            ld b, 17
            jp m_dec

; 3D/AB8F: the change to job jb_cur (jb_new loaded)
jb_change:  ld a, [jb_cur]
            call jb_load
            ld a, [jb_cur]                  ; CP - cost
            add a, low(jb_cost)
            ld l, a
            ld h, high(jb_cost)
            ld b, [hl]
            ld a, [GS + $1B]
            sub b
            ld [GS + $1B], a
            call jb_savexp                  ; the old job's level / EXP saved
            ld a, [m_ch]                    ; the new job
            ld l, a
            ld h, high(GS + $100)
            ld a, [jb_cur]
            ld [hl], a
            add a, a                        ; its level / EXP
            add a, l
            add a, $10
            ld e, a
            ld d, high(GS + $200)
            ld a, l
            add a, $10
            ld l, a
            ld a, [de]
            ld [hl+], a
            inc e
            ld a, [de]
            ld [hl+], a
            ld de, jb_new + 2               ; base stats $6112-$6116
            ld b, 5
.bs:        ld a, [de]
            inc de
            ld [hl+], a
            dec b
            jr nz, .bs
            ld a, [m_ch]                    ; status bit 0 (3D/AC06)
            add a, 2
            ld l, a
            ld h, high(GS + $100)
            set 0, [hl]
            ld a, [jb_new + 7]              ; MP growth: 39/9B88 + 8 index -> the max MP
            add a, a
            add a, a
            add a, a
            ld l, a
            ld h, 0
            ld de, $5B88
            add hl, de
            ld de, jb_tmp8
            ld bc, 8
            ld a, JOB_BANK
            call rd_copy
            ld hl, jb_tmp8
            ld a, [m_ch]
            add a, $31
            ld e, a
            ld d, high(GS + $100)
            ld b, 8
.mp:        ld a, [hl+]
            ld [de], a
            inc e
            inc e
            dec b
            jr nz, .mp
            ld a, [m_ch]                    ; replay the levels: level - 1 .. 1
            inc a
            ld l, a
            ld h, high(GS + $100)
            ld a, [hl]
            ld [jb_lv], a
            and a
            jr z, .end
.lvl:       call jb_level
            ld hl, jb_lv
            dec [hl]
            jr nz, .lvl
.end:       ld a, [m_ch]                    ; base -> mod. stats; current MP at most max
            add a, $12
            ld l, a
            ld h, high(GS + $100)
            ld b, 5
.cp:        ld a, [hl]
            push hl
            ld de, 5
            add hl, de
            ld [hl], a
            pop hl
            inc l
            dec b
            jr nz, .cp
            ld a, [m_ch]
            add a, $30
            ld l, a
            ld b, 8
.cm:        ld a, [hl+]                     ; current
            ld c, a
            ld a, [hl-]                     ; max
            cp c
            jr nc, .ok
            ld [hl], a
.ok:        inc l
            inc l
            dec b
            jr nz, .cm
            ret
; 3D/AC31: level jb_lv's growth (the job's table, entry jb_lv - 1: stat bits + amount, MP bits)
jb_level:   ld a, [m_ch]
            ld l, a
            ld h, high(GS + $100)
            ld a, [hl]                      ; job -> its table (JOB_BANK $4800 + 2 job: pointer)
            add a, a
            ld l, a
            ld h, $60                       ; (JOB_BANK $6000: the pointers, GB addresses)
            ld de, jb_tmp8
            ld bc, 2
            ld a, JOB_BANK
            call rd_copy
            ld a, [jb_tmp8]
            ld l, a
            ld a, [jb_tmp8 + 1]
            ld h, a
            ld a, [jb_lv]
            dec a
            add a, a
            ld e, a
            ld d, 0
            add hl, de
            ld de, jb_tmp8
            ld bc, 2
            ld a, JOB_BANK
            call rd_copy
            ld a, [jb_tmp8]
            ld [jb_b82], a
            and 7
            ld [jb_b84], a
            ld a, [jb_tmp8 + 1]
            ld [jb_b83], a
            ld a, [m_ch]                    ; stats: bits 7-3 of $82 -> $6112-$6116 + amount
            add a, $12
            ld l, a
            ld h, high(GS + $100)
            ld a, [jb_b82]
            ld c, a
            ld b, 5
.st:        sla c
            jr nc, .sn
            ld a, [jb_b84]
            add a, [hl]
            cp 99
            jr c, .s9
            ld a, 99
.s9:        ld [hl], a
.sn:        inc l
            dec b
            jr nz, .st
            ld a, [m_ch]                    ; MP: bit 7 -> level 8 max ($613F) .. bit 0 -> level 1
            add a, $3F
            ld l, a
            ld a, [jb_b83]
            ld c, a
            ld b, 8
.m:         sla c
            jr nc, .mn
            ld a, [hl]
            inc a
            cp 99
            jr c, .m9
            ld a, 99
.m9:        ld [hl], a
.mn:        dec l
            dec l
            dec b
            jr nz, .m
            ret

section wram, $CF00 + 192 + 16
jb_cur:     ds 1
jb_n:       ds 1
jb_j:       ds 1
jb_t:       ds 1
jb_nt:      ds 1
jb_oldf:    ds 1
jb_lv:      ds 1
jb_b82:     ds 1
jb_b83:     ds 1
jb_b84:     ds 1
jb_new:     ds 8
jb_rc:      ds 1
section wram, $C0F8
jb_tmp8:    ds 8
section wram, $C0DD
jb_cost:    ds 23
