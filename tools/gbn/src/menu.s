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
menu_main:  ld a, TR_MENU                   ; (FF1: the menu music)
            call snd_track
            xor a
            ld [mm_cur], a
            ld [menu_act], a
.re:        call mm_draw
.l:         ld a, [mm_cur]                  ; the hand left of the command
            add a, 10
            add a, a
            add a, a
            add a, a
            sub 4
            ld c, a
            ld b, 0
            call scr_cursor
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
            ld a, [hl]                      ; down
            inc a
            cp 5
            jr c, .s
            xor a
.s:         ld [hl], a
            jr .l
.up:        ld a, [hl]
            dec a
            cp 5
            jr c, .s
            ld a, 4
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
            call magic_menu
            ld a, [menu_act]                ; (Warp / Exit: out of the menus)
            and a
            ret nz
            jp .re
.n1:        cp 4
            jr z, .st
            sub 2                           ; weapons (0) / armour (1)
            call equip_menu
            jp .re
.st:
            call pick_char                  ; status: whose
            jr c, .re
            call status_scr
            jr .re

; the main menu drawn (LCD off), shown
mm_draw:    call scr_open
            call orb_gfx
            ld bc, $0000
            ld de, $140A
            call scr_win
            ld bc, $0009
            ld de, $0C09
            call scr_win
            ld bc, $0C0A
            ld de, $0808
            call scr_win
            xor a
.m:         push af
            call mm_member
            pop af
            inc a
            cp 4
            jr c, .m
            ld bc, $020A                    ; commands
            call pen_at
            ld hl, str_mcmd
            call pen_str
            ld bc, $0110                    ; Gil
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
            ldh [rBCPS], a
            ld hl, scr_buf
            ld b, 8
.p:         ld a, [hl+]
            ldh [rBCPD], a
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
orb_pos:    db 14, 12, 16, 12, 14, 14, 16, 14

; ---- choose a member in the party window (hand left of the name): C set on B
pick_char:  xor a
            ld [mm_pc], a
.l:         ld a, [mm_pc]                   ; y = 8 (2 + 2 m) - 2: beside line 2
            add a, a
            add a, 2
            add a, a
            add a, a
            add a, a
            sub 2
            ld c, a
            ld b, 0
            call scr_cursor
            ld a, [mm_cur]                  ; (the command's hand stays: second cursor)
            add a, 10
            add a, a
            add a, a
            add a, a
            sub 4
            add a, 16
            ld [oam_buf + 16], a
            ld [oam_buf + 24], a
            add a, 8
            ld [oam_buf + 20], a
            ld [oam_buf + 28], a
            ld a, 8
            ld [oam_buf + 17], a
            ld [oam_buf + 21], a
            add a, 8
            ld [oam_buf + 25], a
            ld [oam_buf + 29], a
            ld hl, oam_buf + 2
            ld de, oam_buf + 18
            ld b, 2
            ld a, [hl]
            ld [de], a
            ld a, [oam_buf + 6]
            ld [oam_buf + 22], a
            ld a, [oam_buf + 10]
            ld [oam_buf + 26], a
            ld a, [oam_buf + 14]
            ld [oam_buf + 30], a
            ld a, [oam_buf + 3]
            ld [oam_buf + 19], a
            ld [oam_buf + 23], a
            ld [oam_buf + 27], a
            ld [oam_buf + 31], a
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
status_scr: ld [mm_t], a
            call scr_open
            ld bc, $0000
            ld de, $1408
            call scr_win
            ld bc, $0007
            ld de, $140B
            call scr_win
            ld bc, $0101
            call pen_at
            ld a, [mm_t]
            call pen_name
            ld bc, $0A01
            call pen_at
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
            ld bc, $0102                    ; class
            call pen_at
            ld a, [mm_t]
            call ch_rec
            ld a, [hl]
            add a, a
            ld e, a
            ld d, 0
            ld hl, cname_ptrs
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            call pen_str
            ld bc, $0103                    ; experience
            call pen_at
            ld hl, str_exp
            call pen_str
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
            ld bc, $0D04
            call pen_at
            ld b, 6
            call pen_num
            ld bc, $0105                    ; until the next level
            call pen_at
            ld hl, str_next
            call pen_str
            call exp_next
            ld bc, $0D06
            call pen_at
            ld b, 6
            call pen_num
            ld a, [mm_t]                    ; stats: rows 8-12, values at columns 13-18
            call ch_rec
            ld a, l
            add a, $10
            ld l, a
            ld de, str_stats
            ld c, 8
            call st_rows
            ld a, [mm_t]                    ; damage, hit rate, absorb, evasion: rows 13-16
            call ch_rec
            ld a, l
            add a, $20
            ld l, a
            ld de, str_bstats
            ld c, 13
            call st_rows4
            call st_sprite
            call scr_show
.w:         call scr_frame
            ldh a, [pad_new]
            and $03
            jr z, .w
            ret

; rows of label (DE, lines) + value byte at HL+i, from row C, values right-aligned at 16-18
st_rows:    ld b, 5
            jr st_r
st_rows4:   ld b, 4
st_r:       push bc
            push hl
            ld b, 1
            call pen_at
            ld h, d
            ld l, e
.t:         ld a, [hl+]                     ; the label up to $0A / $00
            and a
            jr z, .e
            cp $0A
            jr z, .e
            call pen_ch
            jr .t
.e:         ld d, h
            ld e, l
            pop hl
            pop bc
            push bc
            push de
            push hl
            ld a, [hl]
            call nf_a
            ld b, 16
            call pen_at
            ld b, 3
            call pen_num
            pop hl
            inc hl
            pop de
            pop bc
            inc c
            dec b
            jr nz, st_r
            ret

; the class's standing pose right of rows 1-3 (sprite tiles 0-5, palette from the class)
st_sprite:  ld a, [mm_t]
            call ch_rec
            ld a, [hl]
            call scr_classes                ; classes A.. -> tiles 0-35 (the first is A)
            ld a, [mm_t]
            call ch_rec
            ld a, [hl]
            ld e, a
            ld d, 0
            ld hl, cls_pal
            add hl, de
            ld a, [hl]
            ld [scr_t0], a
            xor a
            ld e, 0
            ld b, 136
            ld c, 8
            jp scr_spr23

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
.re:        call it_list                    ; FF1 DrawItemBox: the items held, orbs skipped
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
.l:         ld a, [it_cur]                  ; the hand: row 4 + (cur mod 13)
            call it_row
            add a, 4
            add a, a
            add a, a
            add a, a
            sub 4
            ld c, a
            ld b, 0
            call scr_cursor
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
            ld bc, $0000
            ld de, $0803
            call scr_win
            ld bc, $0003
            ld de, $140F
            call scr_win
            ld bc, $0101
            call pen_at
            ld hl, str_items
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
            ld hl, mtxt
            call pen_str
            ld a, 1
            ld [it_desc], a
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
u_heal:     ld a, IT_UseItem_Heal_0
            call tgt_open
.l:         call tgt_pick
            jp c, item_menu.re
            call ch_rec
            inc hl
            ld a, [hl]                      ; dead or stone: no (FF1's error sound)
            cp 1
            jr z, .er
            cp 2
            jr z, .er
            dec hl
            ld a, IT_UseItem_Heal_5
            call hp_add
            ld hl, IT_UseItem_Heal_6
            dec [hl]
            call tgt_redraw
            call wait_ab
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
.l:         push bc
            call tgt_pick
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
            call tgt_redraw
            call wait_ab
            jp item_menu.re
.x:         pop hl
            jp item_menu.re
.er:        call sfx_err
            jr .l

; ---- the target screen: the main menu's party window, the text below
tgt_open:   push af
            call scr_cls
            call tgt_draw
            pop af
            call desc_box
            jp scr_upd
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
.l:         ld a, [mm_pc]
            add a, a
            add a, 2
            add a, a
            add a, a
            add a, a
            sub 2
            ld c, a
            ld b, 0
            call scr_cursor
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
            ret
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

; ---- the magic menu (approved layout): title (0,0,8,3), list (0,3,20,15): three levels a
; page, each a line "L1  MP 9/9" and its three spells below from column 3; up / down step
; through the slots, another level's page turns by itself
magic_menu: ld [mg_ch], a
            xor a
            ld [mg_cur], a
.re:        call mg_draw
            call scr_show
.l:         ld a, [mg_cur]                  ; hand: row of the slot
            call mg_row
            add a, a
            add a, a
            add a, a
            sub 4
            ld c, a
            ld b, 0
            call scr_cursor
            call scr_frame
            ldh a, [pad_new]
            bit 1, a
            ret nz
            bit 0, a
            jp nz, mg_use
            and $C0
            jr z, .l
            ld b, a
            ld a, [mg_cur]                  ; slots 0-23 (level * 3 + slot)
            ld c, a
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
            ld a, [it_desc]
            and a
            jr nz, .rd
            ld a, c
            call mg_page
            ld b, a
            ld a, [mg_cur]
            call mg_page
            cp b
            jr z, .l
.rd:        call mg_draw
            call scr_upd
            jr .l

; slot A -> page (9 slots a page) / screen row (5 + 4 (level in page) + slot)
mg_page:    ld b, 0
.p:         cp 9
            jr c, .x
            sub 9
            inc b
            jr .p
.x:         ld a, b
            ret
mg_row:     cp 9
            jr c, .r
            sub 9
            jr mg_row
.r:         ld b, 0                         ; level in page, slot
.l:         cp 3
            jr c, .s
            sub 3
            inc b
            jr .l
.s:         ld c, a
            ld a, b
            add a, a
            add a, a
            add a, c
            add a, 5
            ret

; HL = the member's magic data (ch_magic + $40 member)
mg_data:    ld a, [mg_ch]
            rrca
            rrca
            ld l, a
            ld h, high(ch_magic)
            ret

mg_draw:    call scr_cls
            xor a
            ld [it_desc], a
            ld bc, $0000
            ld de, $0803
            call scr_win
            ld bc, $0003
            ld de, $140F
            call scr_win
            ld bc, $0101
            call pen_at
            ld hl, str_magic
            call pen_str
            ld bc, $0901                    ; (the member's name beside the title)
            call pen_at
            ld a, [mg_ch]
            call pen_name
            ld a, [mg_cur]
            call mg_page
            ld b, a                         ; first level = 3 page
            add a, a
            add a, b
            ld [mg_lv], a
            ld c, 4
.lv:        ld a, [mg_lv]
            cp 8
            ret nc
            ld b, 1
            push bc
            call pen_at
            ld a, $4C                       ; L1  MP 9/9
            call pen_ch
            ld a, [mg_lv]
            add a, $31
            call pen_ch
            ld hl, str_mp
            call pen_str
            call mg_data
            ld a, [mg_lv]
            add a, $20
            add a, l
            ld l, a
            push hl
            ld a, [hl]
            call nf_a
            call pen_numl
            ld a, $2F
            call pen_ch
            pop hl
            ld a, l
            add a, 8
            ld l, a
            ld a, [hl]
            call nf_a
            call pen_numl
            pop bc
            ld a, 3                         ; the three spells
.sp:        push af
            inc c
            ld b, 2
            push bc
            call pen_at
            call mg_data
            ld a, [mg_lv]
            add a, a
            add a, a
            add a, l
            ld l, a
            pop bc
            pop af
            push af
            push bc
            ld b, a                         ; slot = 3 - A
            ld a, 3
            sub b
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
            call pen_iname
.em:        pop bc
            pop af
            dec a
            jr nz, .sp
            inc c
            ld hl, mg_lv
            inc [hl]
            ld a, c
            cp 16
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
            jp magic_menu.l
mg_spend:   ld a, [mg_mp]                   ; one MP of the level
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
.l:         call tgt_pick
            jr c, mg_back
            call ch_rec
            inc hl
            ld a, [hl-]
            cp 1
            jr z, .er
            cp 2
            jr z, .er
            ld a, [mg_hp]
            call hp_add
            call mg_spend
            jr m_done
.er:        call sfx_err
            jr .l
; Curaja: HP to the maximum (FF1 does not check ailments)
m_cur4:     ld a, MG_CUR4_0
            call tgt_open
            call tgt_pick
            jr c, mg_back
            call ch_rec
            call hp_full
            call mg_spend
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
            ld a, MG_HEL3_2
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
.l:         push bc
            call tgt_pick
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
            jp m_done
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
equip_menu: ld [eq_kind], a
            and a
            ld a, $18                       ; FF1 equipoffset: ch_weapons / ch_armor
            jr z, .k
            ld a, $1C
.k:         ld [eq_off], a
            call eq_sort                    ; FF1 SortEquipmentList, the item box, stats unadjusted
            call eq_tobox
            call eq_unadj
            call inv_gfx
            xor a
            ld [eq_cur], a
            ld [eq_mode], a
            call eq_draw
            call scr_show
.mode:      ld a, [eq_mode]                 ; the mode cursor: x 0 / 56 / 104, row 2
            ld b, 0
            and a
            jr z, .m1
            ld b, 56
            dec a
            jr z, .m1
            ld b, 104
.m1:        ld c, 12
            call scr_cursor
            call scr_frame
            ldh a, [pad_new]
            bit 1, a
            jr nz, .exit
            bit 0, a
            jr nz, .sub
            ld hl, eq_mode
            bit 4, a
            jr nz, .rt
            bit 5, a
            jr z, .mode
            ld a, [hl]                      ; left
            dec a
            cp 3
            jr c, .ms
            ld a, 2
            jr .ms
.rt:        ld a, [hl]
            inc a
            cp 3
            jr c, .ms
            xor a
.ms:        ld [hl], a
            jr .mode
.exit:      call eq_frombox                 ; back into the records, sorted, stats readjusted
            call eq_sort
            jp eq_readj
.sub:       ld a, [eq_mode]
            and a
            jr z, .equip
            dec a
            jr z, .swap
            ; drop: A twice on an item
.drop:      call eq_pick
            jr c, .mode
            call eq_item
            and a
            jr z, .dre                      ; (an empty slot: FF1's error sound)
            ld b, 1                         ; confirm: the hand twice (FF1 flickers it)
            call eq_pick2
            jr c, .drop
            call eq_item
            ld [hl], 0
            call eq_redraw
            jr .drop
.equip:     call eq_pick
            jp c, .mode
            call eq_item
            and a
            jr z, .equip
            bit 7, a
            jr nz, .tog                     ; equipped: always off
            call eq_legal
            jr c, .eqe
            call eq_item
.tog:       xor $80
            ld [hl], a
            call eq_redraw
            jr .equip
.eqe:       call sfx_err                    ; (not for this class)
            jr .equip
.dre:       call sfx_err
            jr .drop
.swap:      call eq_pick
            jp c, .mode
            ld b, 0
            call eq_pick2                   ; the second slot (both hands shown)
            jr c, .swap
            ld a, [eq_cur]                  ; swapped, both unequipped
            ld e, a
            ld d, 0
            ld hl, eq_box
            add hl, de
            ld a, [eq_cur2]
            ld e, a
            push hl
            ld hl, eq_box
            add hl, de
            pop de
            ld a, [de]
            and $7F
            ld b, a
            ld a, [hl]
            and $7F
            ld [de], a
            ld [hl], b
            call eq_redraw
            jr .swap

; the slot cursor: C set on B; the hand at the slot (eq_cur), page by member
eq_pick:    ld a, [eq_cur]
            call eq_hand
            call scr_frame
            ldh a, [pad_new]
            bit 1, a
            jr nz, .b
            bit 0, a
            ret nz                          ; (C clear)
            and $C0
            jr z, eq_pick
            ld b, a
            ld a, [eq_cur]
            ld c, a
            bit 7, b
            jr z, .up
            inc a
            and 15
            jr .mv
.up:        dec a
            and 15
.mv:        ld [eq_cur], a
            xor c                           ; another page (member pair): redraw
            and 8
            jr z, eq_pick
            call eq_redraw
            jr eq_pick
.b:         scf
            ret
; the second hand (eq_cur kept, a second cursor eq_cur2 moved); B = 1: on the same slot only
eq_pick2:   ld a, [eq_cur]
            ld [eq_cur2], a
.l:         ld a, [eq_cur2]
            push bc
            call eq_hand
            ld hl, oam_buf                  ; the first hand into OAM 4-7 (same page only)
            ld de, oam_buf + 16
            ld c, 16
.c:         ld a, [hl+]
            ld [de], a
            inc de
            dec c
            jr nz, .c
            ld a, [eq_cur]
            ld hl, eq_cur2
            xor [hl]
            and 8
            jr z, .sp
            xor a
            ld [oam_buf + 16], a
            ld [oam_buf + 20], a
            ld [oam_buf + 24], a
            ld [oam_buf + 28], a
.sp:        ld a, [eq_cur]                  ; first hand at eq_cur in 0-3
            call eq_hand
            ld hl, oam_buf
            ld de, oam_buf + 16
            ld c, 16
.sw:        ld a, [de]                      ; swap: 0-3 = second, 4-7 = first
            ld b, [hl]
            ld [hl+], a
            ld a, b
            ld [de], a
            inc de
            dec c
            jr nz, .sw
            call scr_frame                  ; (read_pad clobbers BC)
            pop bc
            ldh a, [pad_new]
            bit 1, a
            jr nz, .b
            bit 0, a
            jr nz, .a
            ld c, a
            ld a, b
            and a
            jr nz, .l                       ; (confirm: no moving)
            ld a, c
            and $C0
            jr z, .l
            ld a, [eq_cur2]
            ld d, a
            bit 7, c
            jr z, .up
            inc a
            and 15
            jr .mv
.up:        dec a
            and 15
.mv:        ld [eq_cur2], a
            xor d
            and 8
            jr z, .l
            push bc
            ld a, [eq_cur]
            push af
            ld a, [eq_cur2]
            ld [eq_cur], a
            call eq_redraw
            pop af
            ld [eq_cur], a
            pop bc
            jr .l
.a:         and a
            ret
.b:         scf
            ret
; the hand at slot A: x -8 (cut off), y of the slot's row
eq_hand:    ld b, a
            and 3
            ld c, a
            ld a, b
            and 4                           ; member in the pair
            ld a, 6
            jr z, .t
            ld a, 13
.t:         add a, c
            add a, a
            add a, a
            add a, a
            sub 4
            ld c, a
            ld b, $F8
            jp scr_cursor

; HL = the slot eq_cur in the box, A = its item
eq_item:    ld a, [eq_cur]
            ld e, a
            ld d, 0
            ld hl, eq_box
            add hl, de
            ld a, [hl]
            ret

; the records' slots <-> the box; FF1 SortEquipmentList (gaps removed)
eq_tobox:   ld de, eq_box
            ld c, 0
.m:         ld a, [eq_off]
            add a, c
            ld l, a
            ld h, high(ch_stats)
            ld b, 4
.s:         ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .s
            ld a, c
            add a, $40
            ld c, a
            jr nz, .m
            ret
eq_frombox: ld de, eq_box
            ld c, 0
.m:         ld a, [eq_off]
            add a, c
            ld l, a
            ld h, high(ch_stats)
            ld b, 4
.s:         ld a, [de]
            inc de
            ld [hl+], a
            dec b
            jr nz, .s
            ld a, c
            add a, $40
            ld c, a
            jr nz, .m
            ret
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

; the class may use the item (FF1 IsEquipLegal: permission words, $800 >> class); C set if
; not; equipping it unequips the member's other weapons / armour of the same type
eq_legal:   and $7F
            dec a
            ld [eq_t], a
            add a, a
            ld e, a
            ld d, 0
            ld a, [eq_kind]
            and a
            ld hl, N_WPERM
            jr z, .w
            ld hl, N_APERM
.w:         add hl, de
            ld de, scr_buf
            ld bc, 2
            ld a, NAMES
            call far_copy
            ld a, [eq_cur]                  ; the class bit
            rlca
            rlca
            rlca
            rlca
            and $C0
            ld l, a
            ld h, high(ch_stats)
            ld a, [hl]
            ld [eq_cls], a
            ld b, a
            ld hl, $0800
.sh:        ld a, b
            and a
            jr z, .bit
            srl h
            rr l
            dec b
            jr .sh
.bit:       ld a, [scr_buf]
            and l
            ld b, a
            ld a, [scr_buf + 1]
            and h
            or b
            jr z, .ok
            scf
            ret
.ok:        ld a, [eq_cur]                  ; the member's four slots
            and $0C
            ld e, a
            ld d, 0
            ld hl, eq_box
            add hl, de
            ld a, [eq_kind]
            and a
            jr nz, .arm
            ld b, 4                         ; a weapon: every weapon off
.wo:        res 7, [hl]
            inc hl
            dec b
            jr nz, .wo
            and a
            ret
.arm:       push hl                         ; armour: the same type off
            ld a, [eq_t]
            call eq_atype
            ld [eq_t], a
            pop hl
            ld b, 4
.ao:        bit 7, [hl]
            jr z, .an
            ld a, [hl]
            and $7F
            dec a
            push hl
            push bc
            call eq_atype
            pop bc
            pop hl
            ld c, a
            ld a, [eq_t]
            cp c
            jr nz, .an
            res 7, [hl]
.an:        inc hl
            dec b
            jr nz, .ao
            and a
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

; inverted icons to BG $A0 + code (LCD off)
inv_gfx:    call lcd_off                    ; (LCD off in V-Blank, interrupts off)
.off:       ldh a, [is_cgb]
            and a
            ld hl, N_INVDMG
            jr z, .d
            ld hl, N_INVCGB
.d:         ld de, $8A00
            ld bc, 512
            ld a, NAMES
            jp far_copy

eq_redraw:  call eq_draw
            jp scr_upd
eq_draw:    call scr_cls
            ld bc, $0000
            ld de, $1404
            call scr_win
            ld bc, $0004
            ld de, $1407
            call scr_win
            ld bc, $000B
            ld de, $1407
            call scr_win
            ld bc, $0101
            call pen_at
            ld a, [eq_kind]
            and a
            ld hl, str_weapons
            jr z, .t
            ld hl, str_armor
.t:         call pen_str
            ld bc, $0202
            call pen_at
            ld hl, str_eqcmd
            call pen_str
            ld a, [eq_cur]                  ; the pair: members 2 page, 2 page + 1
            and 8
            rrca
            rrca
            ld [eq_ch], a                   ; (0 / 2)
            ld c, 5
            call .mem
            ld a, [eq_ch]
            inc a
            ld [eq_ch], a
            ld c, 12
.mem:       push bc                         ; name row C, slots below
            ld b, 1
            call pen_at
            ld a, [eq_ch]
            call pen_name
            pop bc
            ld a, [eq_ch]
            add a, a
            add a, a
            ld [eq_t], a                    ; box index
            ld b, 4
.sl:        inc c
            push bc
            ld a, [eq_t]
            ld e, a
            ld d, 0
            ld hl, eq_box
            add hl, de
            ld a, [hl]
            and a
            jr z, .em
            ld [eq_it], a
            ld b, 1
            call pen_at
            ld a, [eq_it]                   ; the name (icon + letters) into scr_buf
            and $7F
            ld b, 27                        ; weapons: name 27 + n, armour 67 + n
            ld c, a
            ld a, [eq_kind]
            and a
            jr z, .wn
            ld b, 67
.wn:        ld a, b
            add a, c
            call pen_iname
            ld a, [eq_it]                   ; equipped: the icon inverted
            bit 7, a
            jr z, .em
            pop bc
            push bc
            ld b, 1
            call cell_addr
            ld a, [hl]
            add a, INV_TILE
            ld [hl], a
            inc h
            inc h
            inc h
            ld [hl], WIN_ATTR & 7           ; (CGB: VRAM bank 0)
.em:        ld hl, eq_t
            inc [hl]
            pop bc
            dec b
            jr nz, .sl
            ret

; ---- story pages (the prologue, the bridge, the ending): A = first page, B = pages; each a
; window (0,2,20,14) with up to 12 centred lines; A turns the page, Start skips the rest
story_show: ld [st_pg], a
            ld a, b
            ld [st_n], a
.p:         call scr_open
            xor a                           ; (no menu sounds on the story pages)
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
            call scr_show
.w:         call scr_frame
            ldh a, [pad_new]
            bit 3, a
            ret nz                          ; Start: the rest skipped
            and $01
            jr z, .w
            ld hl, st_pg
            inc [hl]
            ld hl, st_n
            dec [hl]
            jr nz, .p
            ret

section wram, $CE00
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
mtxt:       ds 160
