; FF1 native engine: the main menu and its screens (code bank 2). Our own code, written from
; what FF1's menus do (disassembly bank 0E: EnterMainMenu, the item / magic / equip / status
; menus), in the approved Game Boy layouts (docs/gb-handoff.md, main menu).
; Text is drawn with the LCD off through a pen (a VRAM map address); the screen framework
; (scr_open, scr_win, scr_cursor) is in screens.s.

U_ORBDMG   = $7300
U_ORBCGB   = $7480
U_ORBPAL   = $7600
U_EXPTBL   = $7610
ORB_TILE   = $80            ; orb tiles at BG $80- ($8800): 16 lit (4 a orb), 4 unlit
ORB_UNLIT  = $90
CH_CLASS   = $00            ; FF1's character record (save page + $100 + $40 n)
CH_AIL     = $01
CH_NAME    = $02
CH_EXP     = $07
CH_HP      = $0A
CH_MAXHP   = $0C
CH_LEVEL   = $26
ORBS       = $D032          ; FF1 orb_fire .. orb_earth (items + $12)

section bank 0, $3000                       ; (the pen and numbers: bank 0, for every screen)

; ---- the pen
; pen at cell (B, C)
pen_at:     push hl
            call cell_addr
            ld a, l
            ld [pen], a
            ld [pen_l], a
            ld a, h
            ld [pen + 1], a
            ld [pen_l + 1], a
            pop hl
            ret

; A -> [pen++]
pen_ch:     push hl
            ld hl, pen
            push af
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            pop af
            ld [hl+], a
            ld a, l
            ld [pen], a
            ld a, h
            ld [pen + 1], a
            pop hl
            ret

; string HL ($0A: the next line under the first cell, $00 end)
pen_str:    ld a, [hl+]
            and a
            ret z
            cp $0A
            jr z, .nl
            call pen_ch
            jr pen_str
.nl:        push hl
            ld hl, pen_l
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld de, 32
            add hl, de
            ld a, l
            ld [pen_l], a
            ld [pen], a
            ld a, h
            ld [pen_l + 1], a
            ld [pen + 1], a
            pop hl
            jr pen_str

; B spaces
pen_sp:     ld a, $20
            call pen_ch
            dec b
            jr nz, pen_sp
            ret

; nf_val (3 bytes) as B digits, right-aligned with spaces
pen_num:    push bc
            call num_fmt
            pop bc
            ld a, 6
            sub b
            ld e, a
            ld d, 0
            ld hl, nf_dig
            add hl, de
.c:         ld a, [hl+]
            call pen_ch
            dec b
            jr nz, .c
            ret
; the same without the leading spaces
pen_numl:   call num_fmt
            ld hl, nf_dig
            ld b, 6
.s:         ld a, [hl]
            cp $20
            jr nz, .c
            inc hl
            dec b
            jr .s
.c:         ld a, [hl+]
            call pen_ch
            dec b
            jr nz, .c
            ret
; A -> nf_val
nf_a:       ld [nf_val], a
            xor a
            ld [nf_val + 1], a
            ld [nf_val + 2], a
            ret
; [HL] (2 bytes) -> nf_val
nf_w:       ld a, [hl+]
            ld [nf_val], a
            ld a, [hl]
            ld [nf_val + 1], a
            xor a
            ld [nf_val + 2], a
            ret

; nf_val -> nf_dig: 6 characters, leading zeros as spaces
num_fmt:    ld hl, pow10
            ld de, nf_dig
            ld c, 6
.dg:        ld b, 0
.sub:       ld a, [nf_val]
            sub [hl]
            ld [nf_t], a
            inc hl
            ld a, [nf_val + 1]
            sbc a, [hl]
            ld [nf_t + 1], a
            inc hl
            ld a, [nf_val + 2]
            sbc a, [hl]
            dec hl
            dec hl
            jr c, .dn
            ld [nf_val + 2], a
            ld a, [nf_t]
            ld [nf_val], a
            ld a, [nf_t + 1]
            ld [nf_val + 1], a
            inc b
            jr .sub
.dn:        ld a, b
            add a, $30
            ld [de], a
            inc de
            inc hl
            inc hl
            inc hl
            dec c
            jr nz, .dg
            ld hl, nf_dig
            ld b, 5
.lz:        ld a, [hl]
            cp $30
            ret nz
            ld [hl], $20
            inc hl
            dec b
            jr nz, .lz
            ret
pow10:      db $A0, $86, $01, $10, $27, $00, $E8, $03, $00, $64, $00, $00, $0A, $00, $00
            db $01, $00, $00

; HL = character A's record (ch_stats + $40 A)
ch_rec:     rrca
            rrca
            ld l, a
            ld h, high(ch_stats)
            ret

; character A's name (6 letters)
pen_name:   call ch_rec
            push hl
            inc hl
            inc hl
            ld b, 4
.l:         ld a, [hl+]
            call pen_ch
            dec b
            jr nz, .l
            pop hl
            ld a, l
            add a, CH_NAME2
            ld l, a
            ld a, [hl+]
            call pen_ch
            ld a, [hl]
            jp pen_ch

; the name of item / spell / class A (names bank: icon + letters)
pen_iname:  ld l, a
            ld h, 0
            add hl, hl
            ld de, $4000
            add hl, de
            ld de, scr_buf
            ld bc, 2
            ld a, NAMES
            call far_copy
            ld a, [scr_buf]
            ld l, a
            ld a, [scr_buf + 1]
            ld h, a
            ld de, scr_buf
            ld bc, 20
            ld a, NAMES
            call far_copy
            ld hl, scr_buf
            jp pen_str

section bank 2, $4800

; ---- the main menu (approved layout): party (0,0,20,10), commands + Gil (0,9,12,9),
; orbs (12,10,8,8)
menu_main:  ld a, TR_MENU                   ; (FF1: the menu music, again after a jingle)
            ld [scr_mus], a
            call .in
            xor a
            ld [scr_mus], a
            ret
.in:        ld a, TR_MENU
            call snd_track
            xor a
            ld [mm_cur], a
            ld [menu_act], a
.re:        call mm_draw
.l:         ld a, [mm_cur]                  ; the hand left of the command (column 12)
            inc a
            ld c, a
            ld b, 12
            call cur_txt
            call scr_frame
            ldh a, [pad_new]
            bit 1, a
            ret nz                          ; B: back to the map
            bit 0, a
            jr nz, .a
            ld hl, mm_cur
            bit 6, a
            jr nz, .up
            bit 7, a
            jr z, .l
            ld a, [hl]                      ; down (six commands: Items, Magic, Equip,
            inc a                           ;   Status, Options, Suspend)
            cp 6
            jr c, .s
            xor a
.s:         ld [hl], a
            jr .l
.up:        ld a, [hl]
            dec a
            cp 6
            jr c, .s
            ld a, 5
            jr .s
.a:         ld a, [mm_cur]
            and a
            jr nz, .n0
            call item_menu
            jr .re
.n0:        cp 1
            jr nz, .n1
.mp:        call pick_char                  ; magic: whose (not dead / stone: FF1's error
            jr c, .re                       ;   sound)
            push af
            call ch_rec
            inc hl
            ld a, [hl]
            dec a
            cp 2
            jr nc, .mok
            pop af
            call sfx_err
            jr .mp
.mok:       pop af
            push af                         ; (no magic at all: FF1's error sound too)
            call mg_any
            jr nz, .mk2
            pop af
            call sfx_err
            jr .mp
.mk2:       pop af
            call magic_menu
            ld a, [menu_act]                ; (Warp / Exit: out of the menus)
            and a
            ret nz
            jp .re
.n1:        cp 5
            jr nz, .n5
            call sus_menu                   ; Suspend (No: the menu again)
            jp .re
.n5:        cp 4
            jr nz, .n4
            call opt_menu                   ; Options
            jp .re
.n4:        cp 3
            jr z, .st
            call pick_char                  ; Equip: whose (the equipment screen)
            jr c, .re
            call eqm_main
            jp .re
.st:
            call pick_char                  ; status: whose
            jr c, .re
            call status_scr
            jr .re

; the main menu (owner, 2026-11-22: the party's pictures back): party (0,0,12,15), each
; member's battle picture (cells 2-3, three rows) with name, level (or Dead / Stone /
; Poison) and HP / max beside it; commands (11,0,9,7); orbs (11,6,9,9); Gil (0,15,20,3)
mm_draw:    call scr_open
            call orb_gfx
            ld bc, $0000
            ld de, $0C0F
            call scr_win
            ld bc, $0B00                    ; (six commands)
            ld de, $0908
            call scr_win
            ld bc, $0B07
            ld de, $0908
            call scr_win
            ld bc, $000F
            ld de, $1403
            call scr_win
            xor a
.m:         push af
            call mm_mem3
            pop af
            inc a
            cp 4
            jr c, .m
            ld bc, $0C01                    ; commands
            call pen_at
            ld hl, str_mcmd4
            call pen_str
            ld bc, $0910                    ; Gil, ending at column 18
            call pen_at
            ld hl, GOLD
            ld a, [hl+]
            ld [nf_val], a
            ld a, [hl+]
            ld [nf_val + 1], a
            ld a, [hl]
            ld [nf_val + 2], a
            ld b, 6
            call pen_num
            ld a, $20
            call pen_ch
            ld hl, str_gil
            call pen_str
            call orb_draw
            jp scr_show

; member A in the main menu: the picture at x 14 (its job's battle pose: tiles 6 A, OAM 8 + 6 A),
; name, level or ailment, HP / max from column 4, rows 1 + 3 A ..
mm_mem3:    ld [mm_t], a
            call ch_rec
            ld a, [hl]
            ld [scr_t1], a                  ; (the job)
            ld l, a                         ; its pose: 6 tiles of the job's block
            ld h, 0
            add hl, hl
            ld a, l
            ld l, 0
            ld h, a
            ldh a, [is_cgb]
            and a
            ld bc, U_SPRDMG
            jr z, .d
            ld bc, U_SPRCGB
.d:         add hl, bc
            ld a, [mm_t]                    ; -> $8000 + 96 A
            ld e, a
            add a, a
            add a, e
            add a, a                        ; 6 A
            swap a
            ld e, a
            and $0F
            add a, $80
            ld d, a
            ld a, e
            and $F0
            ld e, a
            ld bc, 96
            ld a, UI_GFX
            call far_copy
            ld a, [scr_t1]                  ; its palette
            ld e, a
            ld d, 0
            ld hl, cls_pal
            add hl, de
            ld a, [hl]
            ld [scr_t0], a
            ld a, [mm_t]                    ; at (16, 8 + 24 A)
            ld c, a
            add a, a
            add a, c
            add a, a
            add a, a
            add a, a
            add a, 8
            ld c, a
            ld b, 14                        ; (2 pixels clear of the text)
            ld a, [mm_t]
            ld e, a
            add a, a
            add a, e
            add a, a
            push af
            add a, 8
            ld e, a
            pop af
            call scr_spr23
            ld a, [mm_t]                    ; the name
            ld c, a
            add a, a
            add a, c
            inc a
            ld c, a
            ld b, 4
            push bc
            call pen_at
            ld a, [mm_t]
            call pen_name
            pop bc
            inc c
            push bc
            call pen_at
            ld a, [mm_t]                    ; level, or the ailment (FF1 outside battle:
            call ch_rec                     ;   1 dead, 2 stone, 3 poison)
            inc hl
            ld a, [hl-]
            ld de, str_st_dead
            cp 1
            jr z, .w
            ld de, str_st_stone
            cp 2
            jr z, .w
            ld de, str_st_poison
            cp 3
            jr z, .w
            ld a, l
            add a, CH_LEVEL
            ld l, a
            ld a, $4C
            call pen_ch
            ld a, [hl]
            inc a
            call nf_a
            call pen_numl
            jr .hp
.w:         ld h, d
            ld l, e
            call pen_str
.hp:        pop bc
            inc c
            call pen_at
            ld a, [mm_t]
            call ch_rec
            ld a, l
            add a, CH_HP
            ld l, a
            push hl
            call nf_w
            ld b, 3
            call pen_num
            ld a, $2F
            call pen_ch
            pop hl
            inc hl
            inc hl
            call nf_w
            ld b, 3
            jp pen_num

; member A's two lines: name, L level, HP / max; class or ailment
mm_member:  ld [mm_t], a
            add a, a
            inc a
            ld c, a
            ld b, 1
            call pen_at
            ld a, [mm_t]
            call pen_name
            ld a, $20
            call pen_ch
            ld a, $4C
            call pen_ch
            ld a, [mm_t]
            call ch_rec
            ld a, l
            add a, CH_LEVEL
            ld l, a
            ld a, [hl]
            inc a
            call nf_a
            ld b, 2
            call pen_num
            ld a, $20
            call pen_ch
            ld a, [mm_t]
            call ch_rec
            ld a, l
            add a, CH_HP
            ld l, a
            push hl
            call nf_w
            ld b, 3
            call pen_num
            ld a, $2F
            call pen_ch
            pop hl
            inc hl
            inc hl
            call nf_w
            ld b, 3
            call pen_num
            ld a, [mm_t]                    ; line 2
            add a, a
            add a, 2
            ld c, a
            ld b, 2
            call pen_at
            ld a, [mm_t]
            call ch_rec
            inc hl
            ld a, [hl-]                     ; ailments: dead, stone, poison
            ld de, str_st_dead              ; (FF1 outside battle: 1 dead, 2 stone,
            cp 1                            ;  3 poison)
            jr z, .w
            ld de, str_st_stone
            cp 2
            jr z, .w
            ld de, str_st_poison
            cp 3
            jr z, .w
            ld a, [hl]                      ; else the class
            add a, a
            ld e, a
            ld d, 0
            ld hl, cname_ptrs
            add hl, de
            ld a, [hl+]
            ld d, [hl]
            ld e, a
.w:         ld h, d
            ld l, e
            jp pen_str
cname_ptrs: dw str_cname0, str_cname1, str_cname2, str_cname3, str_cname4, str_cname5
            dw str_cname6, str_cname7, str_cname8, str_cname9, str_cname10, str_cname11

; orb tiles to BG $80- (LCD off); CGB: the lit orbs' palette as BG palette 6
orb_gfx:    ldh a, [is_cgb]
            and a
            ld hl, U_ORBDMG
            jr z, .t
            ld hl, U_ORBPAL
            ld de, scr_buf
            ld bc, 8
            ld a, UI_GFX
            call far_copy
            ld a, $B0
            call bcps_w
            ld hl, scr_buf
            ld b, 8
.p:         ld a, [hl+]
            call bcpd_w
            dec b
            jr nz, .p
            ld hl, U_ORBCGB
.t:         ld de, $8800
            ld bc, 20 * 16
            ld a, UI_GFX
            jp far_copy

; the four orbs (FF1 DrawOrbBox: fire, water / air, earth), lit or not
orb_draw:   ld hl, orb_pos
            ld de, ORBS
            ld a, ORB_TILE
.o:         ld [mm_t], a
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld c, a
            ld a, [de]
            inc de
            push hl
            push de
            and a
            ld a, [mm_t]                    ; lit: its own four tiles, palette 6
            ld e, a
            ld d, 6
            jr nz, .lit
            ld e, ORB_UNLIT
            ld d, 7
.lit:       call cell_addr
            call .two
            ld a, l
            add a, 30
            ld l, a
            ld a, h
            adc a, 0
            ld h, a
            call .two
            pop de
            pop hl
            ld a, [mm_t]
            add a, 4
            cp ORB_TILE + 16
            jr c, .o
            ret
.two:       call .one                       ; two cells: tiles E, E + 1, attributes D
.one:       ld a, e
            ld [hl], a
            inc e
            inc h
            inc h
            inc h
            ld [hl], d
            dec h
            dec h
            dec h
            inc hl
            ret
orb_pos:    db 13, 9, 15, 9, 13, 11, 15, 11

; ---- choose a member in the party window (hand left of the name): C set on B
pick_char:  xor a
            ld [mm_pc], a
.l:         ld a, [mm_pc]                   ; the hand at the member's picture (cells 2-3,
            ld c, a                         ;   its middle row 2 + 3 m)
            add a, a
            add a, c
            add a, 2
            add a, a                        ; (pixels: the fingertip 2 before the picture
            add a, a                        ;   at x 14)
            add a, a
            ld c, a
            ld b, 14 - 17
            call scr_cursor
            ld a, [mm_cur]                  ; (the command's hand stays: second cursor)
            inc a
            ld c, a
            ld b, 12
            call cur_txt2
            call scr_frame
            ldh a, [pad_new]
            bit 1, a
            jr nz, .b
            bit 0, a
            jr nz, .a
            ld hl, mm_pc
            bit 6, a
            jr nz, .up
            bit 7, a
            jr z, .l
            ld a, [hl]
            inc a
            and 3
            ld [hl], a
            jr .l
.up:        ld a, [hl]
            dec a
            and 3
            ld [hl], a
            jr .l
.a:         ld a, [mm_pc]
            and a
            ret
.b:         scf
            ret

; ---- the status screen (approved layout): window (0,0,20,8): name + level, class,
; experience, until next level, the class sprite right of rows 1-3; window (0,7,20,11):
; strength .. luck, then damage, hit rate, absorb, evasion
; ---- the status screen (owner, 2026-11-22: as the equipment screen): top (0,0,20,5)
; picture, name, job, level; (0,5,20,7) HP, MP per level (levels 1-4, 5-8), experience and
; what the next level needs; (0,11,20,7) the five stats and the four battle values; gold
; labels on the Color; left / right: the next member; A / B: back
status_scr: ld [mm_t], a
.re:        call scr_open
            call eqm_pal
            ld a, [mm_t]
            call mtop
            ld hl, str_level
            call pen_str
            ld a, [mm_t]
            call ch_rec
            ld a, l
            add a, CH_LEVEL
            ld l, a
            ld a, [hl]
            inc a
            call nf_a
            call pen_numl
            ld bc, $0005
            ld de, $1407
            call scr_win
            ld bc, $000B
            ld de, $1407
            call scr_win
            ld bc, $0106                    ; gold labels: HP, MP, Exp, Next
            ld hl, str_stlab
            ld e, 2
            call gold_str
            ld bc, $0109
            ld hl, str_stlab2
            ld e, 4
            call gold_str
            ld bc, $010C                    ; Str .. Lck
            ld hl, str_stl
            ld e, 3
            call gold_str
            ld bc, $080C                    ; Attack .. Evasion
            ld hl, str_eqst
            ld e, 8
            call gold_str
            ld bc, $0C06                    ; HP current / maximum, ending at column 18
            call pen_at
            ld a, [mm_t]
            call ch_rec
            ld a, l
            add a, CH_HP
            ld l, a
            push hl
            call nf_w
            ld b, 3
            call pen_num
            ld a, $2F
            call pen_ch
            pop hl
            inc hl
            inc hl
            call nf_w
            ld b, 3
            call pen_num
            ld bc, $0407                    ; MP: current / maximum of each level
            call pen_at
            xor a
.mp:        ld [mm_pc], a
            cp 4
            jr nz, .m1
            ld bc, $0408
            call pen_at
.m1:        ld a, [mm_t]
            rrca
            rrca
            ld l, a
            ld h, high(ch_magic)
            ld a, [mm_pc]
            add a, $20
            add a, l
            ld l, a
            ld a, [hl]
            add a, $30
            call pen_ch
            ld a, $2F
            call pen_ch
            ld a, l
            add a, 8
            ld l, a
            ld a, [hl]
            add a, $30
            call pen_ch
            ld a, [mm_pc]                   ; (a space between, none at the border)
            and 3
            cp 3
            jr z, .m2
            ld a, $20
            call pen_ch
.m2:        ld a, [mm_pc]
            inc a
            cp 8
            jr c, .mp
            ld bc, $0D09                    ; experience
            call pen_at
            ld a, [mm_t]
            call ch_rec
            ld a, l
            add a, CH_EXP
            ld l, a
            ld a, [hl+]
            ld [nf_val], a
            ld a, [hl+]
            ld [nf_val + 1], a
            ld a, [hl]
            ld [nf_val + 2], a
            ld b, 6
            call pen_num
            ld bc, $0D0A                    ; to the next level
            call pen_at
            call exp_next
            ld b, 6
            call pen_num
            ld a, [mm_t]                    ; Str .. Lck at columns 5-6
            call ch_rec
            ld a, l
            add a, $10
            ld l, a
            ld bc, $050C
            ld e, 5
            ld d, 2
            call st_vals
            ld a, [mm_t]                    ; Attack .. Evasion at columns 16-18
            call ch_rec
            ld a, l
            add a, $20
            ld l, a
            ld bc, $100C
            ld e, 4
            ld d, 3
            call st_vals
            call scr_show
.w:         call scr_frame
            ldh a, [pad_new]
            ld b, a
            and $03
            ret nz
            ld hl, mm_t
            bit 4, b
            jr nz, .rt
            bit 5, b
            jr z, .w
            ld a, [hl]
            dec a
            jr .mv
.rt:        ld a, [hl]
            inc a
.mv:        and 3
            ld [hl], a
            jp .re

; E values (bytes at HL..) as D digits at column B, rows C..
st_vals:    push bc
            push de
            push hl
            call pen_at
            pop hl
            ld a, [hl+]
            push hl
            call nf_a
            pop hl
            pop de
            push de
            push hl
            ld b, d
            call pen_num
            pop hl
            pop de
            pop bc
            inc c
            dec e
            jr nz, st_vals
            ret

; the string HL (lines) from (B, C), each line's first E cells gold (Color: palette 3)
gold_str:   push de
            push bc
            push hl
            call pen_at
            call pen_str
            pop hl
            ld d, 1                         ; (its lines)
.n:         ld a, [hl+]
            and a
            jr z, .g
            cp $0A
            jr nz, .n
            inc d
            jr .n
.g:         pop bc
            pop hl
            ld e, l
.r:         push bc
            push de
            call cell_addr
            ld a, h
            add a, 3
            ld h, a
            ld a, $0B
.c:         ld [hl+], a
            dec e
            jr nz, .c
            pop de
            pop bc
            inc c
            dec d
            jr nz, .r
            ret

; nf_val = experience to the next level (FF1: the level-up table minus the experience)
exp_next:   ld a, [mm_t]
            call ch_rec
            ld a, l
            add a, CH_LEVEL
            ld l, a
            ld a, [hl]
            cp 49
            jr c, .t
            xor a                           ; (level 50: nothing more)
            jp nf_a
.t:         ld e, a                         ; table entry: 3 bytes a level
            ld d, 0
            ld h, d
            ld l, e
            add hl, hl
            add hl, de
            ld de, U_EXPTBL
            add hl, de
            ld de, scr_buf
            ld bc, 3
            ld a, UI_GFX
            call far_copy
            ld a, [mm_t]
            call ch_rec
            ld a, l
            add a, CH_EXP
            ld l, a
            ld a, [scr_buf]
            sub [hl]
            ld [nf_val], a
            inc hl
            ld a, [scr_buf + 1]
            sbc a, [hl]
            ld [nf_val + 1], a
            inc hl
            ld a, [scr_buf + 2]
            sbc a, [hl]
            ld [nf_val + 2], a
            ret nc
            xor a
            jp nf_a

; ---- the item menu (approved layout): title (0,0,8,3), list (0,3,20,15) with 13 items a
; page (hand at the screen edge, icon at column 2, the count at 17-18); descriptions in
; (0,9,20,9) over the list, 7 lines of 18
MTEXT      = 5
IT_SAVETXT = IT_UseItem_House_5
IT_PAGE    = 13
item_menu:  xor a
            ld [it_cur], a
.re:        call scr_open                   ; (a screen of its own: faded)
            call eqm_pal                    ; (the gold title)
            call it_list                    ; FF1 DrawItemBox: the items held, orbs skipped
            ld a, [it_n]
            and a
            jr nz, .has
            call it_draw
            ld a, 4                         ; "You have nothing."
            call desc_box
            call scr_show
            jp wait_ab
.has:       ld a, [it_cur]
            ld hl, it_n
            cp [hl]
            jr c, .c
            xor a
            ld [it_cur], a
.c:         call it_draw
            call scr_show
.l:         ld a, [it_cur]                  ; the hand: row 4 + (cur mod 13), column 2
            call it_row
            add a, 4
            ld c, a
            ld b, 2
            call cur_txt
            call scr_frame
            ldh a, [pad_new]
            bit 1, a
            ret nz
            bit 0, a
            jp nz, it_use
            and $C0
            jr z, .l
            ld b, a
            ld a, [it_cur]                  ; up / down through the list
            ld c, a
            bit 7, b
            jr z, .up
            inc a
            ld hl, it_n
            cp [hl]
            jr c, .mv
            xor a
            jr .mv
.up:        dec a
            cp $FF
            jr nz, .mv
            ld a, [it_n]
            dec a
.mv:        ld [it_cur], a
            ld a, [it_desc]                 ; a description shown, or another page: redraw
            and a
            jr nz, .rd
            ld a, c
            call it_page
            ld b, a
            ld a, [it_cur]
            call it_page
            cp b
            jr z, .l
.rd:        call it_draw
            call scr_upd
            jr .l

; A = list index -> A = its page / its row in the page
it_page:    ld b, 0
.p:         cp IT_PAGE
            jr c, .x
            sub IT_PAGE
            inc b
            jr .p
.x:         ld a, b
            ret
it_row:     cp IT_PAGE
            ret c
            sub IT_PAGE
            jr it_row

; the items held -> it_box, it_n
it_list:    ld hl, ITEMS + 1
            ld de, it_box
            ld bc, $0100                    ; B = item id, C = count
.i:         ld a, b
            cp $12                          ; (orbs $12-$15 skipped)
            jr c, .t
            cp $16
            jr c, .n
            cp $1C
            jr nc, .x
.t:         ld a, [hl]
            and a
            jr z, .n
            ld a, b
            ld [de], a
            inc de
            inc c
.n:         inc hl
            inc b
            jr .i
.x:         ld a, c
            ld [it_n], a
            ret

; the item screen (the page of it_cur) into the map copy
it_draw:    call scr_cls
            xor a
            ld [it_desc], a
            ld bc, $0000                    ; (the header as the other screens': the
            ld de, $1403                    ;   title in gold, the Gil on the right)
            call scr_win
            ld bc, $0003
            ld de, $140F
            call scr_win
            ld bc, $0101
            ld hl, str_items
            ld e, 5
            call gold_str
            ld bc, $0901
            call pen_at
            ld hl, GOLD
            ld a, [hl+]
            ld [nf_val], a
            ld a, [hl+]
            ld [nf_val + 1], a
            ld a, [hl]
            ld [nf_val + 2], a
            ld b, 6
            call pen_num
            ld a, $20
            call pen_ch
            ld hl, str_gil
            call pen_str
            ld a, [it_cur]
            call it_page
            ld b, a                         ; first = 13 page
            add a, a
            add a, b
            add a, a
            add a, a
            add a, b
            ld [it_t], a
            ld c, 4
.r:         ld a, [it_t]
            ld hl, it_n
            cp [hl]
            ret nc
            ld e, a
            ld d, 0
            ld hl, it_box
            add hl, de
            ld a, [hl]
            ld [it_id], a
            ld b, 2
            push bc
            call pen_at
            ld a, [it_id]
            call pen_iname
            ld a, [it_id]                   ; consumables: the count
            cp $16
            jr c, .nc
            add a, low(ITEMS)
            ld l, a
            ld h, high(ITEMS)
            ld a, [hl]
            call nf_a
            pop bc
            push bc
            ld b, 17
            call pen_at
            ld b, 2
            call pen_num
.nc:        pop bc
            inc c
            ld hl, it_t
            inc [hl]
            ld a, c
            cp 4 + IT_PAGE
            jr c, .r
            ret

; FF1 menu text A (descriptions, prompts) in the window (0,9,20,9)
desc_box:   push af
            ld bc, $0009
            ld de, $1409
            call scr_win
            pop af
            call mt_get
            ld bc, $010A
            call pen_at
            ld a, 1
            ld [it_desc], a
            call scr_upd
            ld hl, mtxt
            jp pen_type

; string HL typed at the pen (owner, 2026-11-22): a letter at a time at an adult's reading
; speed, twice as fast with A held, a soft click; $0A: the next line. (The screen not shown:
; at once.)
pen_type:   call hand_hide                  ; (no hand while the text types)
            ld a, [tw_spd]                  ; (Instant: at once)
            cp 4
            jp z, pen_str
            call lcd_get
            bit 7, a
            jp z, pen_str
            ld a, [sfx_menu]                ; (no menu sounds from A meanwhile)
            push af
            xor a
            ld [sfx_menu], a
            ld a, 256 - TW_RATE
            ld [tw_acc], a
.l:         ld a, [hl+]
            and a
            jr z, .x
            cp $0A
            jr z, .nl
            cp $20
            jr z, .sp
            push hl
            ld [tw_qt], a
            ld hl, pen                      ; its cell: smap -> VRAM $9800 + the same offset
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld a, l
            ld [tw_ql], a
            ld a, h
            sub high(smap) - $98
            ld [tw_qh], a
            ld a, [tw_qt]
            call pen_ch
            call tw_click
.w:         call scr_frame
            call tw_rate
            jr nc, .w
            pop hl
            jr .l
.sp:        call pen_ch
            jr .l
.nl:        push hl
            ld hl, pen_l
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld de, 32
            add hl, de
            ld a, l
            ld [pen_l], a
            ld [pen], a
            ld a, h
            ld [pen_l + 1], a
            ld [pen + 1], a
            pop hl
            jr .l
.x:         pop af
            ld [sfx_menu], a
            ret
; menu text A -> mtxt
mt_get:     add a, a
            ld l, a
            ld h, $40
            ld de, scr_buf
            ld bc, 2
            ld a, MTEXT
            call far_copy
            ld a, [scr_buf]
            ld l, a
            ld a, [scr_buf + 1]
            ld h, a
            ld de, mtxt
            ld bc, 160
            ld a, MTEXT
            jp far_copy

; a description over the list, shown in the next V-Blanks
desc_show:  call desc_box
            jp scr_upd

; wait for A or B (C set on B)
wait_ab:    call oam_clr
.w:         call scr_frame
            ldh a, [pad_new]
            and $03
            jr z, .w
            rrca
            ccf
            ret

; ---- using an item (FF1 ItemJumpTable / UseItem_x)
it_use:     ld a, [it_cur]
            ld e, a
            ld d, 0
            ld hl, it_box
            add hl, de
            ld a, [hl]
            ld [it_id], a
            ld e, a
            ld hl, it_jt
            add hl, de
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            jp hl
it_jt:      dw item_menu.l, u_lute, u_desc, u_desc, u_desc, u_desc, u_desc, u_desc, u_desc
            dw u_desc, u_rod, u_floater, u_desc, u_desc, u_desc, u_bottle, u_desc, u_desc
            dw item_menu.l, item_menu.l, item_menu.l, item_menu.l, u_tent, u_cabin, u_house
            dw u_heal, u_pure, u_soft
; simple descriptions: the text number of each (the ROM's operands)
u_desc:     ld a, [it_id]
            ld e, a
            ld d, 0
            ld hl, it_dsc
            add hl, de
            ld a, [hl]
u_show:     call desc_show
            jp item_menu.l
it_dsc:     db 0, 0, IT_UseItem_Crown_0, IT_UseItem_Crystal_0, IT_UseItem_Herb_0, IT_UseItem_Key_0
            db IT_UseItem_TNT_0, IT_UseItem_Adamant_0, IT_UseItem_Slab_0, IT_UseItem_Ruby_0, 0, 0
            db IT_UseItem_Chime_0, IT_UseItem_Tail_0, IT_UseItem_Cube_0, 0, IT_UseItem_Oxyale_0
            db IT_UseItem_Canoe_0

u_bottle:   ld a, [IT_UseItem_Bottle_0]     ; the fairy's object flag: already out
            rrca
            ld a, IT_UseItem_Bottle_1
            jr c, u_show
            xor a
            ld [IT_UseItem_Bottle_3], a     ; the bottle is gone
            ld a, IT_UseItem_Bottle_4
            call show_obj
            call fanfare
            ld a, IT_UseItem_Bottle_5
            call desc_box
            call it_list
            ld a, 1
            ld [it_desc], a
            call scr_upd
            jp item_menu.l

; Rod / Lute: on a standard map, on the tile marked for it, while its plate is there
u_rod:      ld a, IT_UseItem_Rod_1
            ld b, IT_UseItem_Rod_2
            ld c, IT_UseItem_Rod_4
            ld d, IT_UseItem_Rod_5
            jr u_plate
u_lute:     ld a, IT_UseItem_Lute_1
            ld b, IT_UseItem_Lute_2
            ld c, IT_UseItem_Lute_4
            ld d, IT_UseItem_Lute_5
u_plate:    ld e, a
            ldh a, [maptype]
            and a
            jr nz, .no
            ld a, [tprop_now]
            and IT_UseItem_Rod_0
            cp e
            jr nz, .no
            ld l, b                         ; the plate object still shown
            ld h, high(game_flags)
            bit 0, [hl]
            jr z, .no
            ld a, b
            push bc
            call hide_obj
            call fanfare
            pop bc
            ld a, c
            jr u_show
.no:        ld a, d
            jr u_show

; Floating Stone: on the overworld, on a floater tile, the airship not yet up
u_floater:  ldh a, [maptype]
            and a
            jr z, .no
            ld a, [tprop_now]
            and IT_UseItem_Floater_0
            cp IT_UseItem_Floater_1
            jr nz, .no
            ld a, [IT_UseItem_Floater_2]
            and a
            jr nz, .no
            ld hl, IT_UseItem_Floater_3
            inc [hl]
            call fanfare
            ld a, IT_UseItem_Floater_4
            jr u_show
.no:        ld a, IT_UseItem_Floater_5
            jr u_show

; Sleeping Bag / Tent / Cottage: on the overworld; HP to everyone, then the save question
u_tent:     ld hl, IT_UseItem_Tent_0
            ld b, IT_UseItem_Tent_1
            ld c, IT_UseItem_Tent_2
            ld d, IT_UseItem_Tent_3
            xor a
            jr u_camp
u_cabin:    ld hl, IT_UseItem_Cabin_0
            ld b, IT_UseItem_Cabin_1
            ld c, IT_UseItem_Cabin_2
            ld d, IT_UseItem_Cabin_3
            xor a
            jr u_camp
u_house:    ld hl, IT_UseItem_House_0
            ld b, IT_UseItem_House_1
            ld c, IT_UseItem_House_2
            ld d, IT_UseItem_House_3
            ld a, 1
u_camp:     ld [it_t], a
            ldh a, [maptype]
            and a
            jr nz, .ok
            ld a, d
            jp u_show
.ok:        dec [hl]
            ld a, b
            push bc
            call party_hp
            call tgt_draw
            pop bc
            ld a, c
            call save_ask
            jr nc, .x
            ld a, [it_t]                    ; the cottage: MP too, after the save (as FF1)
            and a
            call nz, party_mp
.x:         jp item_menu.re

; Potion / Antidote / Golden Needle: on a member
u_heal:     ld a, IT_UseItem_Heal_0         ; (owner, 2026-11-22: used again and again, the
            call tgt_open                   ;   window open, until none are left or B)
            call tgt_pick
            jr .t
.l:         call tgt_pick2
.t:         jp c, item_menu.re
            call ch_rec
            inc hl
            ld a, [hl]                      ; dead or stone: no (FF1's error sound)
            cp 1
            jr z, .er
            cp 2
            jr z, .er
            dec hl
            call hp_atmax                   ; (full: no effect, the hand back)
            jr nz, .ok
            ld a, IT_UseItem_Heal_0
            call no_eff
            jr .l
.ok:        ld a, IT_UseItem_Heal_5
            call hp_add
            ld hl, IT_UseItem_Heal_6
            dec [hl]
            ld a, [hl]
            push af
            call tgt_redraw
            pop af
            and a
            jr nz, .l                       ; (more left: the same member, again)
            jp item_menu.re
.er:        call sfx_err
            jr .l
u_pure:     ld a, IT_UseItem_Pure_0
            ld b, IT_UseItem_Pure_1
            ld hl, IT_UseItem_Pure_2
            jr u_cure
u_soft:     ld a, IT_UseItem_Soft_0
            ld b, IT_UseItem_Soft_1
            ld hl, IT_UseItem_Soft_2
u_cure:     push hl
            push bc
            call tgt_open
            pop bc
            xor a
            ld [mm_pc], a
.l:         push bc
            call tgt_pick2
            pop bc
            jr c, .x
            call ch_rec                     ; FF1 CureOBAilment: only that ailment
            inc hl
            ld a, [hl]
            cp b
            jr nz, .er
            ld [hl], 0
            pop hl
            dec [hl]
            ld a, [hl]
            push hl
            push af
            push bc
            call tgt_redraw
            pop bc
            pop af
            and a
            jr nz, .l                       ; (more left: again)
            pop hl
            jp item_menu.re
.x:         pop hl
            jp item_menu.re
.er:        call sfx_err
            jr .l

; ---- the target screen: the main menu's party window, the text below
tgt_open:   push af
            call scr_open                   ; (a screen of its own: faded)
            call tgt_draw
            pop af
            call desc_box
            jp scr_show
tgt_draw:   ld bc, $0000
            ld de, $140A
            call scr_win
            xor a
.m:         push af
            call mm_member
            pop af
            inc a
            cp 4
            jr c, .m
            ret
tgt_redraw: call tgt_draw
            jp scr_upd
; the hand beside a member: A = member, C set on B
tgt_pick:   xor a
            ld [mm_pc], a
tgt_pick2:                                  ; (the hand where it was)
.l:         ld a, [mm_pc]                   ; (at the member's second line)
            add a, a
            add a, 2
            ld c, a
            ld b, 2
            call cur_txt
            call scr_frame
            ldh a, [pad_new]
            bit 1, a
            jr nz, .b
            bit 0, a
            jr nz, .a
            ld hl, mm_pc
            bit 6, a
            jr nz, .up
            bit 7, a
            jr z, .l
            ld a, [hl]
            inc a
            and 3
            ld [hl], a
            jr .l
.up:        ld a, [hl]
            dec a
            and 3
            ld [hl], a
            jr .l
.a:         ld a, [mm_pc]
            and a
            ret
.b:         scf
            ret

; HP += A for the member at HL (record), at most the maximum (FF1 MenuRecoverHP_Abs)
hp_add:     push hl
            ld b, a
            ld a, l
            add a, CH_HP
            ld l, a
            ld a, [hl]
            add a, b
            ld [hl+], a
            ld a, [hl]
            adc a, 0
            ld [hl-], a
            ld d, a                         ; DE = HP, compared with the maximum
            ld e, [hl]
            inc hl
            inc hl
            ld a, [hl+]
            ld c, a
            ld b, [hl]                      ; BC = max
            ld a, e
            sub c
            ld a, d
            sbc a, b
            jr c, .ok
            dec hl                          ; over: HP = max
            dec hl
            ld a, b
            ld [hl-], a
            ld [hl], c
.ok:        pop hl
            ld a, TR_HPUP                   ; FF1 MenuRecoverHP: the little gain-HP jingle
            jp snd_track
; everyone not dead / stone: HP += A (FF1 MenuRecoverPartyHP)
party_hp:   ld [it_t + 1], a
            xor a
.m:         push af
            call ch_rec
            inc hl
            ld a, [hl-]
            cp 1
            jr z, .n
            cp 2
            jr z, .n
            ld a, [it_t + 1]
            call hp_add
.n:         pop af
            inc a
            cp 4
            jr c, .m
            ret
; everyone not dead / stone: MP to the maximum (FF1 MenuRecoverPartyMP)
party_mp:   xor a
.m:         push af
            call ch_rec
            inc hl
            ld a, [hl]
            cp 1
            jr z, .n
            cp 2
            jr z, .n
            pop af
            push af
            rrca
            rrca
            add a, $20
            ld l, a
            ld h, high(ch_magic)
            ld b, 8
.c:         push hl
            ld a, l
            add a, 8
            ld l, a
            ld a, [hl]
            pop hl
            ld [hl+], a
            dec b
            jr nz, .c
.n:         pop af
            inc a
            cp 4
            jr c, .m
            ret

; the save question (text A): A saves (FF1 MenuSaveConfirm); C set if saved
save_ask:   call desc_show
            call wait_ab
            ccf
            ret nc
            ld a, IT_SAVETXT
            call desc_show
            call save_game
            call wait_ab
            scf
            ret

; ---- the magic screen (owner, 2026-11-22: as the equipment screen): top (0,0,20,5)
; picture, name, job, HP; list (0,5,20,13): the eight levels, each a gold L1 with its MP and
; the member's three spells below it (icon and name), scrolled with the hand; left / right:
; the next member; A casts FF1's out-of-battle spells (again and again while MP lasts)
magic_menu: ld [mg_ch], a
            xor a
            ld [mg_cur], a
            ld [mg_top], a
.re:        call mg_draw
.l:         call mg_row                     ; the hand at the spell
            ld c, a
            ld b, 2
            call cur_txt
            call scr_frame
            ldh a, [pad_new]
            bit 1, a
            ret nz
            bit 0, a
            jp nz, mg_use
            ld hl, mg_ch
            bit 4, a
            jr nz, .rt
            bit 5, a
            jr nz, .lf
            and $C0
            jr z, .l
            ld b, a
            ld a, [mg_cur]                  ; slots 0-23 (level x 3 + slot)
            bit 7, b
            jr z, .up
            inc a
            cp 24
            jr c, .mv
            xor a
            jr .mv
.up:        dec a
            cp $FF
            jr nz, .mv
            ld a, 23
.mv:        ld [mg_cur], a
            call mg_scroll                  ; (NZ: the list moved)
            jr z, .l
            call mg_list
            call scr_upd
            jr .l
.rt:        ld b, 1                         ; (the next member with magic)
            jr .ch
.lf:        ld b, $FF
.ch:        ld c, 4
.cn:        ld a, [hl]
            add a, b
            and 3
            ld [hl], a
            push bc
            push hl
            call mg_any
            pop hl
            pop bc
            jr nz, .re
            dec c
            jr nz, .cn
            jr .re
; member A has magic (any level's MP maximum): NZ
mg_any:     rrca
            rrca
            add a, $28
            ld l, a
            ld h, high(ch_magic)
            ld b, 8
            xor a
.l:         or [hl]
            inc hl
            dec b
            jr nz, .l
            and a
            ret

; B = level, C = slot of mg_cur
mg_lvsl:    ld a, [mg_cur]
            ld b, 0
.l:         cp 3
            ret c
            sub 3
            ld c, a
            inc b
            ld a, c
            jr .l
; mg_top so that the hand's row shows (rows 6-16: a level takes four); NZ when it moved
mg_scroll:  call mg_lvsl
            ld c, a
            ld hl, mg_top
            ld a, b
            cp [hl]
            jr nc, .dn
            ld [hl], a                      ; above: that level first
            or 1
            ret
.dn:        ld d, 0
.l:         ld a, b                         ; 4 (level - top) + 1 + slot <= 10
            sub [hl]
            add a, a
            add a, a
            inc a
            add a, c
            cp 11
            jr c, .x
            inc [hl]
            inc d
            jr .l
.x:         ld a, d
            and a
            ret
; A = the hand's row
mg_row:     call mg_lvsl
            ld c, a
            ld a, [mg_top]
            ld d, a
            ld a, b
            sub d
            add a, a
            add a, a
            add a, c
            add a, 7
            ret

; HL = the member's magic data (ch_magic + $40 member)
mg_data:    ld a, [mg_ch]
            rrca
            rrca
            ld l, a
            ld h, high(ch_magic)
            ret

mg_draw:    call scr_open
            call eqm_pal
            ld a, [mg_ch]
            call mtop
            ld a, $48                       ; HP current / maximum
            call pen_ch
            ld a, $50
            call pen_ch
            ld a, $20
            call pen_ch
            ld a, [mg_ch]
            call ch_rec
            ld a, l
            add a, CH_HP
            ld l, a
            push hl
            call nf_w
            call pen_numl
            ld a, $2F
            call pen_ch
            pop hl
            inc hl
            inc hl
            call nf_w
            call pen_numl
            ld bc, $0005
            ld de, $140D
            call scr_win
            call mg_list
            jp scr_show

; the list rows 6-16 from level mg_top
mg_list:    ld c, 6                         ; (cleared, colours back)
.cl:        ld b, 1
            call pen_at
            ld b, 18
            call pen_sp
            ld b, 1
            call cell_addr
            ld a, h
            add a, 3
            ld h, a
            ld a, WIN_ATTR
            ld b, 18
.ca:        ld [hl+], a
            dec b
            jr nz, .ca
            inc c
            ld a, c
            cp 17
            jr c, .cl
            ld a, [mg_top]
            ld [mg_lv], a
            ld c, 6
.lv:        ld a, [mg_lv]
            cp 8
            ret nc
            push bc                         ; the level: gold L1, MP 9/9 at columns 13-18
            ld b, 1
            call pen_at
            ld a, $4C
            call pen_ch
            ld a, [mg_lv]
            add a, $31
            call pen_ch
            ld b, 1
            call cell_addr
            ld a, h
            add a, 3
            ld h, a
            ld a, $0B
            ld [hl+], a
            ld [hl], a
            pop bc
            push bc
            ld b, 11
            call pen_at
            ld hl, str_mp
            call pen_str
            call mg_data
            ld a, [mg_lv]
            add a, $20
            add a, l
            ld l, a
            ld a, [hl]
            add a, $30
            call pen_ch
            ld a, $2F
            call pen_ch
            ld a, l
            add a, 8
            ld l, a
            ld a, [hl]
            add a, $30
            call pen_ch
            pop bc
            xor a                           ; the three spells
.sp:        ld [mg_hp], a
            inc c
            ld a, c
            cp 17
            ret nc
            ld b, 2
            call pen_at
            call mg_data
            ld a, [mg_lv]
            add a, a
            add a, a
            ld b, a
            ld a, [mg_hp]
            add a, b
            add a, l
            ld l, a
            ld a, [hl]
            and a
            jr z, .em
            ld b, a
            ld a, [mg_lv]
            add a, a
            add a, a
            add a, a
            add a, b
            add a, $AF                      ; FF1: spell id = level x 8 + spell - 1 + MG_START
            push bc
            call pen_iname
            pop bc
.em:        ld a, [mg_hp]
            inc a
            cp 3
            jr c, .sp
            inc c
            ld hl, mg_lv
            inc [hl]
            ld a, c
            cp 17
            jr c, .lv
            ret

; ---- casting (FF1 MagicMenu_Loop @A_Pressed and the UseMagic routines)
mg_use:     ld a, [mg_cur]                  ; level, slot
            ld b, 0
.l:         cp 3
            jr c, .s
            sub 3
            inc b
            jr .l
.s:         ld c, a
            ld a, b
            ld [mg_lv], a
            call mg_data                    ; MP of the level (FF1 UseMagic_GetRequiredMP)
            ld a, l
            add a, $20
            add a, b
            ld [mg_mp], a
            ld e, a
            ld d, h
            ld a, [de]
            and a
            ld a, MG_NOMP
            jp z, mg_show
            ld a, b                         ; the spell id
            add a, a
            add a, a
            add a, c
            add a, l
            ld l, a
            ld a, [hl]
            ld c, a
            and a
            ld a, MG_CANT
            jp z, mg_show
            ld a, b
            add a, a
            add a, a
            add a, a
            add a, c
            add a, $AF
            ld hl, mg_tbl                   ; the out-of-battle spells
.f:         ld c, a
            ld a, [hl+]
            and a
            jr z, .no
            cp c
            jr z, .go
            inc hl
            inc hl
            ld a, c
            jr .f
.go:        ld a, [hl+]
            ld h, [hl]
            ld l, a
            jp hl
.no:        ld a, MG_CANT
            jp mg_show
mg_tbl:     db MG_CURE_ID
            dw m_cure
            db MG_CUR2_ID
            dw m_cur2
            db MG_CUR3_ID
            dw m_cur3
            db MG_CUR4_ID
            dw m_cur4
            db MG_HEAL_ID
            dw m_heal
            db MG_HEL2_ID
            dw m_hel2
            db MG_HEL3_ID
            dw m_hel3
            db MG_PURE_ID
            dw m_pure
            db MG_LIFE_ID
            dw m_life
            db MG_LIF2_ID
            dw m_lif2
            db MG_WARP_ID
            dw m_warp
            db MG_SOFT_ID
            dw m_soft
            db MG_EXIT_ID
            dw m_exit
            db 0
mg_show:    call desc_show
            call wait_ab
            jp magic_menu.re
mg_spend:   ld a, [mg_mp]                   ; one MP of the level; Z: none left
            ld l, a
            ld h, high(ch_magic)
            dec [hl]
            ret
mg_back:    jp magic_menu.re

; Cure / Cura / Curaga: (frame AND m) OR b HP on a member not dead / stone
m_cure:     ld b, MG_CURE_0
            ld c, MG_CURE_1
            jr m_curef
m_cur2:     ld b, MG_CUR2_0
            ld c, MG_CUR2_1
            jr m_curef
m_cur3:     ld b, MG_CUR3_0
            ld c, MG_CUR3_1
m_curef:    ldh a, [frame]
            and b
            or c
            ld [mg_hp], a
            ld a, MG_CUR3_2
            call tgt_open
            call tgt_pick
            jr .t
.l:         call tgt_pick2                  ; (owner, 2026-11-22: cast again and again,
.t:         jr c, mg_back                   ;   the window open, while MP lasts)
            call ch_rec
            inc hl
            ld a, [hl-]
            cp 1
            jr z, .er
            cp 2
            jr z, .er
            call hp_atmax                   ; (full: no effect, the hand back)
            jr nz, .ok
            ld a, MG_CUR3_2
            call no_eff
            jr .l
.ok:        ld a, [mg_hp]
            call hp_add
            call mg_spend
            jr z, m_done
            call tgt_redraw
            jr .l
.er:        call sfx_err
            jr .l
; Curaja: HP to the maximum (FF1 does not check ailments)
m_cur4:     ld a, MG_CUR4_0
            call tgt_open
            call tgt_pick
            jr .t
.l:         call tgt_pick2
.t:         jr c, mg_back
            call ch_rec
            call hp_atmax                   ; (full: no effect, the hand back)
            jr nz, .ok
            ld a, MG_CUR4_0
            call no_eff
            jr .l
.ok:        call hp_full
            call mg_spend
            jr z, m_done
            call tgt_redraw
            jr .l
m_done:     call tgt_redraw
            call wait_ab
            jr mg_back
hp_full:    ld a, l
            add a, CH_MAXHP
            ld l, a
            ld a, [hl+]
            ld b, [hl]
            dec hl
            dec hl
            ld [hl], b
            dec hl
            ld [hl], a
            ret
; Z: the member at HL (record) has HP at its maximum (HL kept)
hp_atmax:   push hl
            ld a, l
            add a, CH_HP
            ld l, a
            ld a, [hl+]
            ld e, a
            ld a, [hl+]
            ld d, a
            ld a, [hl+]
            cp e
            jr nz, .x
            ld a, [hl]
            cp d
.x:         pop hl
            ret
; Z: every member standing (not dead / stone) has HP at its maximum
party_atmax:
            xor a
.m:         push af
            call ch_rec
            inc hl
            ld a, [hl-]
            cp 1
            jr z, .n
            cp 2
            jr z, .n
            call hp_atmax
            jr nz, .no
.n:         pop af
            inc a
            cp 4
            jr c, .m
            xor a                           ; (Z)
            ret
.no:        pop af
            or 1                            ; (NZ)
            ret
; "It wouldn't have any effect." in the description window (owner, 2026-11-22), the error
; sound; a button, then the prompt A again (at once)
no_eff:     push af
            call sfx_err
            call hand_hide
            ld bc, $0009
            ld de, $1409
            call scr_win
            ld bc, $010A
            call pen_at
            call scr_upd
            ld hl, str_noeff
            call pen_type
            call wait_ab
            ld a, [tw_spd]                  ; (the prompt back at once)
            push af
            ld a, 4
            ld [tw_spd], a
            pop bc
            pop af
            push bc
            call desc_box
            pop af
            ld [tw_spd], a
            ret
; Heal family: (frame AND m) + b HP to everyone, after A
m_heal:     ld b, MG_HEAL_0
            ld c, MG_HEAL_1
            jr m_healf
m_hel2:     ld b, MG_HEL2_0
            ld c, MG_HEL2_1
            jr m_healf
m_hel3:     ld b, MG_HEL3_0
            ld c, MG_HEL3_1
m_healf:    ldh a, [frame]
            and b
            add a, c
            ld [mg_hp], a
            call party_atmax                ; (everyone standing full: no effect, the
            jr nz, .go                      ;   spell list again)
            call scr_open
            call tgt_draw
            ld a, MG_HEL3_2
            call desc_box
            call scr_show
            ld a, MG_HEL3_2
            call no_eff
            jp mg_back
.go:        ld a, MG_HEL3_2
            call desc_show
            call wait_ab
            jr c, mg_back
            call scr_cls
            ld a, [mg_hp]
            call party_hp
            call mg_spend
            jr m_done
; Life / Full-Life / Pure / Soft: cure the ailment on a member
m_life:     ld a, MG_LIFE_0
            ld b, 1
            ld c, 1
            jr m_curea
m_lif2:     ld a, MG_LIF2_0
            ld b, 1
            ld c, 2
            jr m_curea
m_pure:     ld a, MG_PURE_0
            ld b, 3
            ld c, 0
            jr m_curea
m_soft:     ld a, MG_SOFT_0
            ld b, 2
            ld c, 0
m_curea:    push bc
            call tgt_open
            pop bc
            xor a
            ld [mm_pc], a
.l:         push bc
            call tgt_pick2
            pop bc
            jp c, mg_back
            push bc
            call ch_rec
            pop bc
            inc hl
            ld a, [hl]
            cp b
            jr nz, .er
            ld [hl], 0
            dec hl
            ld a, c
            and a
            jr z, .sp
            dec a
            jr nz, .full
            ld a, l                         ; Life: 1 HP
            add a, CH_HP
            ld l, a
            ld [hl], 1
            jr .sp
.full:      call hp_full
.sp:        call mg_spend
            jp z, m_done
            push bc
            call tgt_redraw
            pop bc
            jr .l
.er:        call sfx_err
            jr .l
; Warp / Exit: out of the menus, back a floor / to the overworld
m_warp:     ld a, MG_WARP_0
            ld b, 1
            jr m_out
m_exit:     ld a, MG_EXIT_0
            ld b, 2
m_out:      push bc
            call desc_show
            call mg_spend
            call wait_ab
            pop bc
            ld a, b
            ld [menu_act], a
            ret

; ---- the weapon / armour menus (FF1 EnterEquipMenu): top (0,0,20,4) title and the Equip /
; Swap / Drop commands; two members a page in (0,4,20,7) / (0,11,20,7): name, then the four slots (icon
; at column 1, inverted when equipped; the name from column 2; the hand cut off at the
; screen's left edge)
N_WSTAT    = $7300          ; names bank: weapon stats (8 bytes), armour (4), permissions
N_ASTAT    = $7440
N_WPERM    = $7500
N_APERM    = $7550
N_ATYPE    = $75A0
N_INVDMG   = $7600
N_INVCGB   = $7800
INV_TILE   = $A0            ; inverted icons at BG $A0 + icon code
CLS_BB     = 2              ; Black Belt / Master: no weapon / armour bonuses (FF1)
CLS_MA     = 8
eq_sort:    ld c, 0
.m:         ld a, [eq_off]
            add a, c
            ld l, a
            ld h, high(ch_stats)
            push hl
            ld de, scr_buf                  ; the four, then back without the empty ones
            ld b, 4
.cp:        ld a, [hl]
            ld [de], a
            ld [hl+], a
            inc de
            dec b
            jr nz, .cp
            pop hl
            push hl
            xor a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl], a
            pop hl
            ld de, scr_buf
            ld b, 4
.pt:        ld a, [de]
            inc de
            and a
            jr z, .n
            ld [hl+], a
.n:         dec b
            jr nz, .pt
            ld a, c
            add a, $40
            ld c, a
            jr nz, .m
            ret

; A = armour index (0-based) -> A = its type
eq_atype:   ld l, a
            ld h, 0
            ld de, N_ATYPE
            add hl, de
            ld a, NAMES
            ld [fc_bank], a
            jp far_byte

; the stats with / without the equipment (FF1 UnadjustEquipStats / ReadjustEquipStats and
; the Black Belt / Master rules)
eq_unadj:   xor a
            ld [eq_adj], a
            jr eq_adjall
eq_readj:   ld a, 1
            ld [eq_adj], a
eq_adjall:  ld c, 0
.m:         push bc
            ld a, c
            ld [eq_ch], a
            ld a, [eq_off]
            add a, c
            ld l, a
            ld h, high(ch_stats)
            ld b, 4
.s:         ld a, [hl+]
            bit 7, a
            jr z, .n
            push hl
            push bc
            call eq_one
            pop bc
            pop hl
.n:         dec b
            jr nz, .s
            call eq_bb
            pop bc
            ld a, c
            add a, $40
            ld c, a
            jr nz, .m
            ret
; one equipped item A: weapon hit / damage, armour evasion / absorb / resistance
eq_one:     and $7F
            dec a
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            ld a, [eq_kind]
            and a
            jr nz, .a
            add hl, hl
            ld de, N_WSTAT
            add hl, de
            ld de, scr_buf
            ld bc, 2
            ld a, NAMES
            call far_copy
            ld a, [eq_ch]
            add a, $21                      ; hit rate, damage
            ld l, a
            ld h, high(ch_stats)
            ld a, [scr_buf]
            ld b, a
            ld a, [scr_buf + 1]
            ld c, a
            ld a, [eq_adj]
            and a
            jr z, .wsub
            ld a, [hl]
            add a, b
            ld [hl-], a
            ld a, [hl]
            add a, c
            ld [hl], a
            ret
.wsub:      ld a, [hl]
            sub b
            ld [hl-], a
            ld a, [hl]
            sub c
            ld [hl], a
            ret
.a:         ld de, N_ASTAT
            add hl, de
            ld de, scr_buf
            ld bc, 3
            ld a, NAMES
            call far_copy
            ld a, [eq_ch]
            add a, $23                      ; evasion
            ld l, a
            ld h, high(ch_stats)
            ld a, [scr_buf]
            ld b, a
            ld a, [eq_adj]
            and a
            jr z, .asub
            ld a, [hl]                      ; on: evasion - penalty, absorb +, resistance |=
            sub b
            ld [hl], a
            ld a, l
            sub 1
            ld l, a
            ld a, [scr_buf + 1]
            add a, [hl]
            ld [hl], a
            ld a, l
            add a, 2
            ld l, a
            ld a, [scr_buf + 2]
            or [hl]
            ld [hl], a
            ret
.asub:      ld a, [hl]                      ; off: only the evasion back (FF1)
            add a, b
            ld [hl], a
            ret
; Black Belt / Master (FF1 Unadjust / ReadjustBBEquipStats)
eq_bb:      ld a, [eq_ch]
            ld l, a
            ld h, high(ch_stats)
            ld a, [eq_kind]
            and a
            jr nz, .arm
            ld a, [eq_adj]
            and a
            jr nz, .wre
            ld a, [hl]                      ; weapons off: BB damage 0
            cp CLS_BB
            jr z, .z
            cp CLS_MA
            ret nz
.z:         ld a, l
            add a, $20
            ld l, a
            ld [hl], 0
            ret
.wre:       ld a, [hl]
            cp CLS_BB
            jr z, .bw
            cp CLS_MA
            ret nz
.bw:        ld a, l
            add a, $20
            ld l, a
            ld a, [hl]                      ; damage 0: no weapon: 2 (level + 1)
            and a
            jr z, .nw
            ld a, l                         ; with one: + strength / 2
            sub $10
            ld l, a
            ld a, [hl]
            srl a
            ld b, a
            ld a, l
            add a, $10
            ld l, a
            ld a, [hl]
            add a, b
            ld [hl], a
            ret
.nw:        ld a, l
            add a, $06                      ; level ($26)
            ld l, a
            ld a, [hl]
            inc a
            add a, a
            ld b, a
            ld a, l
            sub $06
            ld l, a
            ld [hl], b
            ret
.arm:       ld a, [eq_adj]
            and a
            jr nz, .are
            ld a, l                         ; armour off: absorb and resistance 0
            add a, $22
            ld l, a
            xor a
            ld [hl+], a
            inc hl
            ld [hl], a
            ret
.are:       ld a, [hl]
            cp CLS_BB
            jr z, .ba
            cp CLS_MA
            ret nz
.ba:        ld a, l
            add a, $22
            ld l, a
            ld a, [hl]
            and a
            ret nz
            ld a, l
            add a, $04                      ; level ($26)
            ld l, a
            ld a, [hl]
            inc a
            ld b, a
            ld a, l
            sub $04
            ld l, a
            ld [hl], b
            ret

; ---- story pages (the prologue, the bridge, the ending): A = first page, B = pages; each a
; window (0,2,20,14) with up to 12 centred lines; A turns the page, Start skips the rest
story_show: ld [st_pg], a
            ld a, b
            ld [st_n], a
            xor a
            ld [st_cont], a
.p:         ld a, [st_cont]                 ; (the next page behind closed shutters: the
            and a                           ;   LCD stays on, FF1 shows the blue shutters)
            jr z, .new
            call scr_cls
            jr .drw
.new:       call scr_open
.drw:       xor a                           ; (no menu sounds on the story pages)
            ld [sfx_menu], a
            ld bc, $0002
            ld de, $140E
            call scr_win
            ld a, [st_pg]                   ; the page's text (menu text bank $7000)
            add a, a
            ld l, a
            ld h, $70
            ld de, scr_buf
            ld bc, 2
            ld a, MTEXT
            call far_copy
            ld a, [scr_buf]
            ld l, a
            ld a, [scr_buf + 1]
            ld h, a
            ld de, mtxt
            ld bc, 200
            ld a, MTEXT
            call far_copy
            ld hl, mtxt
            ld c, 3
.ln:        push hl                         ; a line: its length -> centred
            ld b, 0
.len:       ld a, [hl+]
            and a
            jr z, .le
            cp $0A
            jr z, .le
            inc b
            jr .len
.le:        pop hl
            ld a, 18
            sub b
            srl a
            inc a
            ld b, a
            push bc
            call pen_at
.ch:        ld a, [hl+]
            and a
            jr z, .done
            cp $0A
            jr z, .nl
            call pen_ch
            jr .ch
.nl:        pop bc
            inc c
            jr .ln
.done:      pop bc
            ld a, [st_mode]                 ; (the prologue: no shutters)
            and a
            jr nz, .sh
            call scr_show
            jr .so
.sh:        ld a, [st_cont]
            and a
            jr nz, .sc
            call st_wmap                    ; FF1's shutters: closed (the window), then open
            xor a
            call st_shut
            call scr_show
            ld a, 167                       ; (from the first frame: the window's list)
            ldh [rWX], a
            ld a, LCDC_WIN
            ldh [rLCDC], a
            jr .o1
.sc:        call scr_show                   ; (still closed: the rows go up in V-Blanks)
.su:        call scr_frame
            ld a, [sf_row]
            cp 18
            jr c, .su
.o1:        ld a, 1
.op:        push af
            call st_shut
            call scr_frame
            call scr_frame
            pop af
            inc a
            cp 17
            jr c, .op
.so:        xor a                           ; FF1 Story_Wait: 512 frames at most
            ld [st_t], a
            ld a, 2
            ld [st_t + 1], a
.w:         call scr_frame
            ld a, [st_mode]
            and a
            jr nz, .tm
            ldh a, [pad_new]                ; the prologue: A the next page, Start skips
            bit 3, a
            ret nz
            and $01
            jr z, .w
            jr .nx
.tm:        cp 2                            ; the ending: input ignored (FF1)
            jr z, .ct
            ldh a, [pad_new]                ; the bridge: A / B, or the time
            and 3
            jr nz, .nx
.ct:        ld hl, st_t
            dec [hl]
            jr nz, .w
            inc hl
            dec [hl]
            jr nz, .w
.nx:        ld a, [st_mode]
            and a
            jr z, .nc
            ld a, 16                        ; the shutters close (FF1 Story_CloseShutters)
.cs:        push af
            call st_shut
            call scr_frame
            call scr_frame
            pop af
            dec a
            cp $FF
            jr nz, .cs
            ld a, [st_n]                    ; (more pages: kept closed)
            dec a
            ld [st_cont], a
            call z, ly_off
.nc:        ld hl, st_pg
            inc [hl]
            ld hl, st_n
            dec [hl]
            jr nz, .p
            ret

zz_end_4800:
section wram, $CE00
st_k:       ds 1
st_mode:    ds 1                            ; story pages: 0 prologue, 1 bridge, 2 ending
st_cont:    ds 1                            ; story: the next page behind closed shutters
st_t:       ds 2
pen:        ds 2
pen_l:      ds 2
nf_val:     ds 3
nf_t:       ds 2
nf_dig:     ds 6
mm_cur:     ds 1
mm_t:       ds 1
mm_pc:      ds 1
st_pg:      ds 1
st_n:       ds 1
it_cur:     ds 1
it_n:       ds 1
it_t:       ds 2
it_id:      ds 1
it_desc:    ds 1
it_box:     ds 28
menu_act:   ds 1
mg_ch:      ds 1
mg_cur:     ds 1
mg_lv:      ds 1
mg_mp:      ds 1
mg_hp:      ds 1
mg_top:     ds 1
opt_cur:    ds 1
opt_vol:    ds 1                            ; the master volume (0-7)
tw_spd:     ds 1                            ; the typed text's speed (0-4: Slow .. Instant)
eq_kind:    ds 1
eq_off:     ds 1
eq_cur:     ds 1
eq_cur2:    ds 1
eq_mode:    ds 1
eq_t:       ds 1
eq_it:      ds 1
eq_cls:     ds 1
eq_ch:      ds 1
eq_adj:     ds 1
eq_box:     ds 16
mtxt:       ds 200                          ; (story_show copies 200)

section bank 2, $7280                       ; (the Options screen)
; ---- Options (owner, 2026-11-22): Message Speed (FF1's battle message speed, as on the
; title), Text Speed (the typed text: Slow, Normal = reading speed, Fast, Faster, Instant),
; Volume (0-7, the master volume, at once). Header (0,0,20,3), list (0,3,20,15); up / down
; pick, left / right change, B back (kept in cart RAM bank 1: opt_save)
opt_menu:   call scr_open
            call eqm_pal
            ld bc, $0000
            ld de, $1403
            call scr_win
            ld bc, $0101
            ld hl, str_options
            ld e, 7
            call gold_str
            ld bc, $0003
            ld de, $140F
            call scr_win
            ld bc, $0205
            call pen_at
            ld hl, str_opt1
            call pen_str
            ld bc, $0207
            call pen_at
            ld hl, str_opt2
            call pen_str
            ld bc, $0209
            call pen_at
            ld hl, str_opt3
            call pen_str
            call opt_vals
            call scr_show
            xor a
            ld [opt_cur], a
.l:         ld a, [opt_cur]                 ; the hand at the setting (rows 5, 7, 9)
            add a, a
            add a, 5
            ld c, a
            ld b, 2
            call cur_txt
            call scr_frame
            ldh a, [pad_new]
            bit 1, a
            jp nz, opt_save
            ld hl, opt_cur
            bit 6, a
            jr nz, .up
            bit 7, a
            jr nz, .dn
            ld b, 1
            bit 4, a
            jr nz, .ch
            ld b, $FF
            bit 5, a
            jr z, .l
.ch:        ld a, [opt_cur]                 ; B = +1 / -1, clamped
            and a
            ld hl, respond
            ld c, 8
            jr z, .v
            dec a
            ld hl, tw_spd
            ld c, 5
            jr z, .v
            ld hl, opt_vol
            ld c, 8
.v:         ld a, [hl]
            add a, b
            cp c
            jr nc, .l                       ; (past either end: no change)
            ld [hl], a
            call opt_apply
            call opt_vals
            call scr_upd
            jr .l
.up:        ld a, [hl]
            dec a
            cp 3
            jr c, .s
            ld a, 2
            jr .s
.dn:        ld a, [hl]
            inc a
            cp 3
            jr c, .s
            xor a
.s:         ld [hl], a
            jr .l
; the three values, ending at column 18
opt_vals:   ld bc, $1205
            call pen_at
            ld a, [respond]
            add a, $31
            call pen_ch
            ld bc, $0C07
            call pen_at
            ld a, [tw_spd]
            ld l, a
            add a, a
            add a, a
            add a, a
            sub l                           ; 7 a name
            ld e, a
            ld d, 0
            ld hl, opt_spn
            add hl, de
            ld b, 7
.n:         ld a, [hl+]
            call pen_ch
            dec b
            jr nz, .n
            ld bc, $1209
            call pen_at
            ld a, [opt_vol]
            add a, $30
            jp pen_ch
opt_spn:    db "   Slow", " Normal", "   Fast", " Faster", "Instant"
; the volume to the master volume (NR50)
opt_apply:  ld a, [opt_vol]
            ld b, a
            swap a
            or b
            ldh [$FF24], a
            ret
; the options from cart RAM bank 1 $BF00 ("OP", the three, a check); defaults when not
; valid (Lot Check: cart RAM on only meanwhile)
OPT_RAM    = $BF00
opt_load:   ld a, 1
            ld [tw_spd], a
            ld a, 7
            ld [opt_vol], a
            ld a, $0A
            ld [$0000], a
            ld a, 1
            ld [$4000], a
            ld hl, OPT_RAM
            ld a, [hl+]
            cp $4F
            jr nz, .x
            ld a, [hl+]
            cp $50
            jr nz, .x
            ld a, [hl+]                     ; respond, text speed, volume, check
            ld b, a
            ld a, [hl+]
            ld c, a
            ld a, [hl+]
            ld d, a
            ld a, b
            xor c
            xor d
            xor $5A
            cp [hl]
            jr nz, .x
            ld a, b
            cp 8
            jr nc, .x
            ld a, c
            cp 5
            jr nc, .x
            ld a, d
            cp 8
            jr nc, .x
            ld a, b
            ld [respond], a
            ld a, c
            ld [tw_spd], a
            ld a, d
            ld [opt_vol], a
.x:         xor a
            ld [$0000], a
            ld [$4000], a
            jp opt_apply
opt_save:   ld a, $0A
            ld [$0000], a
            ld a, 1
            ld [$4000], a
            ld hl, OPT_RAM
            ld a, $4F
            ld [hl+], a
            ld a, $50
            ld [hl+], a
            ld a, [respond]
            ld b, a
            ld [hl+], a
            ld a, [tw_spd]
            ld c, a
            ld [hl+], a
            ld a, [opt_vol]
            ld d, a
            ld [hl+], a
            ld a, b
            xor c
            xor d
            xor $5A
            ld [hl], a
            xor a
            ld [$0000], a
            ld [$4000], a
            ret
zz_end_7280:
