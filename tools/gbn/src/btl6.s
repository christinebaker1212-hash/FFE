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
            jp cc_fix                       ; (the LCD colour mode: cc.s)
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
.r:         di                              ; (interrupts off for the row: in V-Blank to the end)
            ldh a, [rLY]
            cp 144
            jr c, .w
            cp 152
            jr nc, .w
            ldh a, [is_cgb]                 ; (VBK on the Color only: Lot Check)
            and a
            jr z, .v0
            ld a, [fl_vb]
            ldh [rVBK], a
.v0:        ld a, [fl_e]
            ld b, a
            push de
.c:         ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .c
            ei
            pop de
            ldh a, [is_cgb]
            and a
            jr z, .v1
            xor a
            ldh [rVBK], a
.v1:
            ld a, e
            add a, 32
            ld e, a
            jr nc, .n
            inc d
.n:         dec c
            jr nz, .r
            pop de
            ret
.w:         ei
            ldh a, [is_cgb]                 ; (outside the V-Blank's window: the row byte by
            and a                           ;   byte, so it never waits for ever)
            jr z, .w0
            ld a, [fl_vb]
            ldh [rVBK], a
.w0:        ld a, [fl_e]
            ld b, a
            push de
.wc:        ld a, [hl+]
            call vput
            dec b
            jr nz, .wc
            pop de
            ldh a, [is_cgb]
            and a
            jr z, .v1
            xor a
            ldh [rVBK], a
            jr .v1
; fiends / Chaos (alone on the field): the Color turns BG palettes 1-2 white and back
fl_fiend6:  ldh a, [is_cgb]
            and a
            ret z
            ld hl, fl_tb                    ; (their colours, as bt_pal makes them)
            ld a, [bt_form + 10]
            call .mk
            ld a, [bt_form + 11]
            call .mk
            ld b, 8                         ; (8 flashes: a boss's end lasts; owner, 2026-11-26)
.ph:        push bc
            call wait_vbl
            ld a, $88
            call bcps_w
            pop bc
            push bc
            bit 0, b
            jr nz, .back
            ld c, 2                         ; white (colour 0 kept black)
.wp:        xor a
            call bcpd_w
            call bcpd_w
            ld b, 3
.wc:        ld a, $FF
            call bcpd_w
            ld a, $7F
            call bcpd_w
            dec b
            jr nz, .wc
            dec c
            jr nz, .wp
            jr .hold
.back:      ld hl, fl_tb
            ld b, 16
.bc:        ld a, [hl+]
            call bcpd_w
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
            call pr_wset                    ; (to the shadows, up in the V-Blank: pal.s)
            call wait_vbl
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
            call bcps_w
            ld e, 3
            call .wr
            pop hl
            ld a, l
            call bcpd_w
            ld a, h
            call bcpd_w
            ld e, 8
.wr:        ld a, c
            call bcpd_w
            ld a, b
            call bcpd_w
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

section bank 104, $5600
; ---- the ailment bubbles (owner, 2026-11-25): each living member with an ailment shows it as a
; round icon in front of its sprite (OAM 28-31; battle.py bubble_tiles after the hit labels),
; several in turn, the worst first (as the party line's word). A member's bubble tile is its
; lying pose's last tile (32 m + 31: only shown while it lies dead, when the bubble is gone and
; the tile is put back). Every frame from bt_frame (bt_fhook); one tile upload a frame.
BUB_SRC    = $4000 + 39 * 48 + 64
bub_tick:   ld a, [crit_on]                 ; ("CRITICAL!" owns OAM 28-31 while the damage
            and a                           ;   number shows; then gone)
            jr z, .nc
            ld a, [dn_t]
            and a
            ret nz
            ld [crit_on], a
            ld hl, oam_buf + 112
            ld b, 4
.cl:        ld [hl+], a
            inc l
            inc l
            inc l
            dec b
            jr nz, .cl
.nc:        ld a, [bt_exn]                  ; (a hit burst owns OAM 28-31)
            and a
            ret nz
            ld hl, bub_t
            inc [hl]
            xor a
            ld [bub_up], a
            ld c, 0
.m:         push bc
            call bub_one
            pop bc
            inc c
            ld a, c
            cp 4
            jr c, .m
            ret
; member C: the bubble it wants (0 none, 1-7 bub_tab), its tile, its sprite
bub_one:    ld a, c
            ld [bub_m], a
            call ch_rec
            inc hl
            ld b, [hl]                      ; (the ailment bits)
            ld e, 0
            bit 0, b                        ; (dead: none)
            jr nz, .want
            ld hl, bub_tab
            ld d, 0
            ld c, 7
.cnt:       ld a, [hl+]
            and b
            jr z, .cn
            inc d
.cn:        dec c
            jr nz, .cnt
            ld a, d
            and a
            jr z, .want
            ld a, [bub_t]                   ; the k-th of them (k: every 64 frames the next)
            rlca
            rlca
            and 3
.md:        cp d
            jr c, .k
            sub d
            jr .md
.k:         ld d, a
            ld hl, bub_tab
.fd:        inc e
            ld a, [hl+]
            and b
            jr z, .fd
            ld a, d
            and a
            jr z, .want
            dec d
            jr .fd
.want:      ld a, [bub_m]
            ld hl, bub_cur
            add a, l
            ld l, a
            jr nc, .w1
            inc h
.w1:        ld a, [hl]
            cp e
            jr z, .oam
            ld a, [bub_up]                  ; (its tile first: one upload a frame)
            ld d, a
            ld a, [bt_upn]
            or d
            jr nz, .hide
            ld [hl], e
            ld a, 1
            ld [bub_up], a
            ld a, e
            and a
            jr z, .orig
            dec a                           ; the bubble's tile
            swap a
            ld l, a
            ld h, 0
            ld bc, BUB_SRC
            add hl, bc
            ld a, HITL_BANK
            jr .cp
.orig:      ld a, [bub_m]                   ; the lying pose's tile back (bt_party_gfx)
            call ch_rec
            ld a, [hl]
            add a, a
            ld h, a
            ld l, $F0
            inc h
            ldh a, [is_cgb]
            and a
            ld bc, U_SPRDMG - $100
            jr z, .o2
            ld bc, U_SPRCGB - $100
.o2:        add hl, bc
            ld a, UI_GFX
.cp:        ld de, bub_buf
            ld bc, 16
            call far_copy
            ld hl, bt_upsrc
            ld a, low(bub_buf)
            ld [hl+], a
            ld [hl], high(bub_buf)
            ld a, [bub_m]                   ; $8000 + $200 m + $1F0
            add a, a
            add a, $81
            ld [bt_updst + 1], a
            ld a, $F0
            ld [bt_updst], a
            ld a, 1
            ld [bt_upn], a
            jr .hide
.oam:       ld a, e
            and a
            jr z, .hide
            ld a, [bub_m]                   ; beside the member's top-left sprite
            ld c, a
            add a, a
            add a, c
            add a, a
            add a, a
            add a, a
            add a, 16
            ld l, a
            ld h, high(oam_buf)
            ld a, [hl+]
            and a
            jr z, .hide
            ld d, a
            ld a, [hl]
            sub 9
            ld b, a
            call bub_slot
            ld a, d
            ld [hl+], a
            ld a, b
            ld [hl+], a
            ld a, [bub_m]                   ; tile 32 m + 31
            swap a
            add a, a
            add a, 31
            ld [hl+], a
            ld a, e                         ; poisoned: green; numb / confused: gold; else white
            cp 7
            ld a, $16
            jr z, .at
            ld a, e
            cp 2
            ld a, $15
            jr z, .at
            ld a, e
            cp 5
            ld a, $15
            jr z, .at
            ld a, $14
.at:        ld [hl], a
            ret
.hide:      call bub_slot
            ld [hl], 0
            ret
bub_slot:   ld a, [bub_m]                   ; HL = OAM 28 + m
            add a, a
            add a, a
            add a, 112
            ld l, a
            ld h, high(oam_buf)
            ret
; the ailments in the bubbles' order (battle.py BUB_ORDER): stone, numb, asleep, mute, confused,
; blind, poisoned
bub_tab:    db $02, $10, $20, $40, $80, $08, $04

section wram, $C6D0
bub_cur:    ds 4                            ; the bubble whose tile each member has (0: its own)
bub_t:      ds 1
bub_up:     ds 1
bub_m:      ds 1
bub_buf:    ds 16

section bank 104, $7E00                     ; (free space)
; ---- level ups after a victory (owner, 2026-11-25: 128X EXP gave one level a battle). lv_all:
; member bt_lvm levelled once already (bt_lvall); on a file with an EXP multiplier (a code and
; not Normal) it goes on while the experience reaches the next level (FF1: one a battle).
lv_all:     ld a, [KN_MARK]
            cp $A5
            ret nz
            ld a, [KN_EXP]
            and a
            ret z
.l:         call .lv
            ld b, a
            push bc
            ld a, 6
            ld hl, bt_lvchk_m
            call bank_call
            pop bc
            call .lv
            cp b
            jr nz, .l
            ret
.lv:        ld a, [bt_lvm]                  ; A = its level (ch_rec's record)
            rrca
            rrca
            add a, CH_LEVEL
            ld l, a
            ld h, high(ch_stats)
            ld a, [hl]
            ret
; the results window's record of member bt_lvm's level up (bt_levelup, after a victory): the
; level, the HP gain (summed over several), the stats raised (all of them)
lv_rec:     call lv_all.lv
            ld b, a
            ld a, [bt_lvm]
            ld e, a
            ld d, 0
            ld hl, res_lv
            add hl, de
            ld [hl], b
            ld c, 0                         ; C = the stats raised (bit 0 strength .. 4 luck)
            ld hl, bt_lvup + 4
            ld b, 5
.m:         ld a, [hl-]
            and a
            jr z, .z
            scf
.z:         rl c
            dec b
            jr nz, .m
            ld hl, res_on
            add hl, de
            ld a, [hl]
            ld [hl], 1
            and a
            jr nz, .acc
            ld hl, res_st
            add hl, de
            ld [hl], c
            ld hl, res_hph
            add hl, de
            ld [hl], 0
            ld hl, res_hp
            add hl, de
            ld a, [bt_t + 1]
            ld [hl], a
            ret
.acc:       ld hl, res_st
            add hl, de
            ld a, [hl]
            or c
            ld [hl], a
            ld hl, res_hp
            add hl, de
            ld a, [bt_t + 1]
            add a, [hl]
            ld [hl], a
            ret nc
            ld hl, res_hph
            add hl, de
            inc [hl]
            ret

section bank 104, $46A0                     ; (free space before the status words at $4700)
; the top window's rows still to go up (win_up .. 7: win_buf -> $9C00 + 32 row), byte by byte
; (vput) from the main code; the V-Blank's box_vbl kept out meanwhile (bn_t 0)
box_safe:   ld a, [bn_t]
            push af
            xor a
            ld [bn_t], a
.r:         ld a, [win_up]
            cp 8
            jr nc, .x
            ld e, a
            add a, a
            add a, a
            add a, e
            add a, a
            add a, a                        ; 20 row
            ld l, a
            ld h, high(win_buf)
            ld a, e
            swap a
            add a, a                        ; 32 row
            ld e, a
            ld d, $9C
            push de
            ld b, 20
.c:         ld a, [hl+]
            call vput
            dec b
            jr nz, .c
            pop de
            ldh a, [is_cgb]
            and a
            jr z, .n
            ld a, 1
            ldh [rVBK], a
            ld a, [ban_attr]
            and a
            jr nz, .w
            ld a, WIN_ATTR
.w:         ld b, 20
.at:        call vput
            dec b
            jr nz, .at
            xor a
            ldh [rVBK], a
.n:         ld hl, win_up
            inc [hl]
            jr .r
.x:         pop af
            ld [bn_t], a
            ret

section bank 104, $4000                     ; (free space)
; an enemy's spell / ability name stays up at least BAN_MIN frames, whatever the battle speed
; (owner, 2026-11-26: it must be readable at speed 8 too)
BAN_MIN    = 60
bt_bmark:   ld a, [frame]
            ld [ban_t0], a
            ld a, 1
            ld [ban_min], a
            ret
bt_bwait:   ld a, [ban_min]
            and a
            jr z, .x
            xor a
            ld [ban_min], a
.w:         ld a, [frame]
            ld hl, ban_t0
            sub [hl]
            cp BAN_MIN
            jr nc, .x
            call x_frame
            jr .w
.x:         ld a, [ban_on]
            ret

section wram, $DBB1
ban_t0:     ds 1
ban_min:    ds 1
