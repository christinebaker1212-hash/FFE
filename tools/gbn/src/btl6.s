; FF1 native engine: battle, part 2 (bank BTL6_BANK = 104): code moved out of the full bank 6.
; Calls into bank 6 go through x_* (bank_call: no arguments in A, BC not returned).

section bank 104, $4400                     ; (battle, part 2: the acting enemy's flash, moved from bank 6)
; bank-6 routines from here
x_flush:    ld a, 6
            ld hl, bt_flush
            jp bank_call
x_frame:    ld a, 6
            ld hl, bt_frame
            jp bank_call
x_nes_rgb:  and $3F                         ; (nes_rgb's copy)
            ld l, a
            ld h, 0
            add hl, hl
            ld de, C_NESRGB
            add hl, de
            ld de, scr_buf + 28
            ld bc, 2
            ld a, COMMON
            call far_copy
            ld a, [scr_buf + 28]
            ld e, a
            ld a, [scr_buf + 29]
            ld d, a
            ret
fl_main:
            ld a, [bt_form]                 ; source: the silhouette page, tile D
            and $0F
            ld b, a
            and 7
            add a, a
            add a, a
            add a, a
            add a, $40
            ld h, a
            ld l, 0
            ld a, d
            swap a
            ld e, a
            and $0F
            ld d, a
            ld a, e
            and $F0
            ld e, a
            add hl, de
            ld a, b
            cp 8
            ld a, ESIL_BANK
            jr c, .bk
            inc a
.bk:        ld [fl_bk], a
            ld de, $8000 + 16 * FL_T0       ; destination
            ld a, [fl_e]                    ; tiles: 16 / 36
            cp 4
            ld a, 16
            jr z, .n
            ld a, 36
.n:         ld [fl_n], a
.bat:       ld a, [fl_n]                    ; batches of up to 18 (bt_stage)
            cp 18
            jr c, .k
            ld a, 18
.k:         ld [fl_k], a
            push de
            push hl
            call fl_bc16
            ld de, bt_stage
            ld a, [fl_bk]
            call far_copy
            ldh a, [is_cgb]
            and a
            jr nz, .st
            ld hl, bt_stage                 ; DMG / SGB: the silhouette white (colour 0) on
            ld a, [fl_k]                    ;   black (3): both planes = not its pixels
            add a, a
            add a, a
            add a, a
            ld b, a
.dm:        inc hl
            ld a, [hl-]
            cpl
            ld [hl+], a
            ld [hl+], a
            dec b
            jr nz, .dm
.st:        pop hl
            pop de
            ld a, low(bt_stage)
            ld [bt_upsrc], a
            ld a, high(bt_stage)
            ld [bt_upsrc + 1], a
            ld a, e
            ld [bt_updst], a
            ld a, d
            ld [bt_updst + 1], a
            ld a, [fl_k]
            ld [bt_upn], a
            push hl
            call x_flush
            pop hl
            call fl_bc16                    ; next batch
            add hl, bc
            ld a, [bt_updst]
            ld e, a
            ld a, [bt_updst + 1]
            ld d, a
            ld a, [fl_k]
            ld b, a
            ld a, [fl_n]
            sub b
            ld [fl_n], a
            jr nz, .bat
            ld a, 1                         ; W, B, W, B (DMG: W, picture, W, picture)
            call fl_phase
            ld a, 2
            call fl_phase
            ld a, 1
            call fl_phase
            ld a, 2
            call fl_phase
            xor a                           ; the picture again
            call fl_fill
            jp fl_put
; BC = 16 fl_k
fl_bc16:    ld a, [fl_k]
            swap a
            ld c, a
            and $0F
            ld b, a
            ld a, c
            and $F0
            ld c, a
            ret
; one phase A (1 W, 2 B), shown 4 frames
fl_phase:   call fl_fill
            call fl_put
            ld b, 3
.w:         push bc
            call x_frame
            pop bc
            dec b
            jr nz, .w
            ret
; the cells' tiles / attributes for phase A (0: the picture, from the map copy) -> fl_tb, fl_ab
fl_fill:    ld [fl_md], a
            ld c, a
            ldh a, [is_cgb]
            and a
            jr nz, .c
            ld a, c                         ; DMG: B = the picture
            cp 2
            jr nz, .c
            xor a
            ld [fl_md], a
.c:         ld a, [fl_b]
            ld b, a
            ld a, [fl_c]
            ld c, a
            call cell_addr
            ld de, fl_tb
            ld a, FL_T0
            ld [fl_t], a
            ld a, [fl_e]
            ld c, a
.r:         push hl
            ld a, [fl_e]
            ld b, a
.x:         ld a, [fl_md]
            and a
            jr z, .p
            ld a, [fl_t]                    ; silhouette tile, palette 5 + phase
            ld [de], a
            inc a
            ld [fl_t], a
            ld a, [fl_md]
            add a, 5
            jr .s
.p:         ld a, [hl]                      ; the picture
            ld [de], a
            push hl
            ld a, h
            add a, 3
            ld h, a
            ld a, [hl]
            pop hl
.s:         push de
            push af
            ld a, e
            add a, 36
            ld e, a
            jr nc, .s1
            inc d
.s1:        pop af
            ld [de], a
            pop de
            inc de
            inc hl
            dec b
            jr nz, .x
            pop hl
            ld a, l
            add a, 32
            ld l, a
            jr nc, .s2
            inc h
.s2:        dec c
            jr nz, .r
            ret
; fl_tb (and on the Color fl_ab) into the screen's cells, a row at a time in V-Blank
fl_put:     call wait_vbl
            ld a, [fl_b]
            ld b, a
            ld a, [fl_c]
            ld c, a
            call cell_addr
            ld de, $9800 - smap
            add hl, de
            ld d, h
            ld e, l
            ld hl, fl_tb
            xor a
            call .pass
            ldh a, [is_cgb]
            and a
            ret z
            ld hl, fl_tb + 36
            ld a, 1
.pass:      push de
            ld [fl_vb], a
            ld a, [fl_e]
            ld c, a
.r:         ldh a, [rLY]
            cp 144
            jr c, .w
            cp 152
            jr nc, .w
            ld a, [fl_vb]
            ldh [rVBK], a
            ld a, [fl_e]
            ld b, a
            push de
.c:         ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .c
            pop de
            xor a
            ldh [rVBK], a
            ld a, e
            add a, 32
            ld e, a
            jr nc, .n
            inc d
.n:         dec c
            jr nz, .r
            pop de
            ret
.w:         push hl
            push de
            push bc
            call wait_vbl
            pop bc
            pop de
            pop hl
            jr .r
; fiends / Chaos (alone on the field): the Color turns BG palettes 1-2 white and back
fl_fiend6:  ldh a, [is_cgb]
            and a
            ret z
            ld hl, fl_tb                    ; (their colours, as bt_pal makes them)
            ld a, [bt_form + 10]
            call .mk
            ld a, [bt_form + 11]
            call .mk
            ld b, 4
.ph:        push bc
            call wait_vbl
            ld a, $88
            ldh [rBCPS], a
            pop bc
            push bc
            bit 0, b
            jr nz, .back
            ld c, 2                         ; white (colour 0 kept black)
.wp:        xor a
            ldh [rBCPD], a
            ldh [rBCPD], a
            ld b, 3
.wc:        ld a, $FF
            ldh [rBCPD], a
            ld a, $7F
            ldh [rBCPD], a
            dec b
            jr nz, .wc
            dec c
            jr nz, .wp
            jr .hold
.back:      ld hl, fl_tb
            ld b, 16
.bc:        ld a, [hl+]
            ldh [rBCPD], a
            dec b
            jr nz, .bc
.hold:      ld b, 3
.h:         push bc
            call x_frame
            pop bc
            dec b
            jr nz, .h
            pop bc
            dec b
            jr nz, .ph
            ret
.mk:        push hl                         ; battle palette A -> 8 bytes at HL
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            ld de, B_PALS
            add hl, de
            ld de, scr_buf
            ld bc, 4
            ld a, BTL_DATA
            call far_copy
            ld a, $0F
            ld [scr_buf], a
            pop hl
            ld c, 0
.k:         push hl
            push bc
            ld b, 0
            ld hl, scr_buf
            add hl, bc
            ld a, [hl]
            call x_nes_rgb
            pop bc
            pop hl
            ld a, e
            ld [hl+], a
            ld a, d
            ld [hl+], a
            inc c
            ld a, c
            cp 4
            jr nz, .k
            ret

; ---- the CGB palettes for the additions (the end of bt_pal; OCPS at OBJ palette 5): OBJ 5 the
; hit label (gold ink, black outline), BG 6 / 7 the flash (white silhouette / black one with a
; white outline)

section bank 104, $4800
; ---- the prologue's first page faded in from white on the Color (owner, 2026-11-23: it showed
; its solid blue at once after the boot logo's white). The Color shows the first screen after
; power-on without the usual fade (fd_on_off), so the prologue fades its own palettes 2-4:
; every colour from white (pr_cnt = 16) to its value (0), one step a frame.
pr_wwhite:  ld a, 16                        ; (LCD off: before scr_show)
            ld [pr_cnt], a
            jr pr_wset
pr_wfade:   ld a, 15
.k:         ld [pr_cnt], a
            call fd_vbl
            call pr_wset
            ld a, [pr_cnt]
            dec a
            cp $FF
            jr nz, .k
            ret
; palettes 2 (blue x 3, white), 3 and 4 (blue x 4), each mixed toward white by pr_cnt / 16
pr_wset:    ld hl, pr_rgb + 8
            call pr_mix
            push bc
            ld hl, pr_rgb
            call pr_mix
            ld a, $80 | 16
            ldh [rBCPS], a
            ld e, 3
            call .wr
            pop hl
            ld a, l
            ldh [rBCPD], a
            ld a, h
            ldh [rBCPD], a
            ld e, 8
.wr:        ld a, c
            ldh [rBCPD], a
            ld a, b
            ldh [rBCPD], a
            dec e
            jr nz, .wr
            ret
; RGB555 at HL mixed toward white by pr_cnt / 16 -> BC
pr_mix:     ld a, [hl+]
            ld c, a
            ld b, [hl]
            ld a, c                         ; R
            and $1F
            call .ch
            ld [pr_cc], a
            ld a, c                         ; G
            rlca
            rlca
            rlca
            and 7
            ld d, a
            ld a, b
            and 3
            add a, a
            add a, a
            add a, a
            or d
            call .ch
            ld [pr_cc + 1], a
            ld a, b                         ; B
            rrca
            rrca
            and $1F
            call .ch
            ld [pr_cc + 2], a
            ld a, [pr_cc + 1]               ; R | G << 5 | B << 10
            ld d, a
            rrca
            rrca
            rrca
            and $E0
            ld e, a
            ld a, [pr_cc]
            or e
            ld c, a
            ld a, d
            srl a
            srl a
            srl a
            ld d, a
            ld a, [pr_cc + 2]
            add a, a
            add a, a
            or d
            ld b, a
            ret
.ch:        push bc                         ; A = t -> t + (31 - t) x pr_cnt / 16
            ld e, a
            ld a, 31
            sub e
            ld d, a
            ld a, [pr_cnt]
            ld b, a
            ld hl, 0
            and a
            jr z, .z
.m:         ld a, l
            add a, d
            ld l, a
            jr nc, .n
            inc h
.n:         dec b
            jr nz, .m
.z:         ld a, l
            swap a
            and $0F
            ld l, a
            ld a, h
            swap a
            and $F0
            or l
            add a, e
            pop bc
            ret
