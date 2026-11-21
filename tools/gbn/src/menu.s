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

section bank 2, $4800

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

; ---- the main menu (approved layout): party (0,0,20,10), commands + Gil (0,9,12,9),
; orbs (12,10,8,8)
menu_main:  xor a
            ld [mm_cur], a
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
.n0:        cp 4
            jr nz, .l                       ; (magic, equipment: next)
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
wait_ab:    call scr_frame
            ldh a, [pad_new]
            and $03
            jr z, wait_ab
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
            ld a, [hl]                      ; dead or stone: no
            cp 1
            jr z, .l
            cp 2
            jr z, .l
            dec hl
            ld a, IT_UseItem_Heal_5
            call hp_add
            ld hl, IT_UseItem_Heal_6
            dec [hl]
            call tgt_redraw
            call wait_ab
            jp item_menu.re
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
            jr nz, .l
            ld [hl], 0
            pop hl
            dec [hl]
            call tgt_redraw
            call wait_ab
            jp item_menu.re
.x:         pop hl
            jp item_menu.re

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

section wram, $CE00
pen:        ds 2
pen_l:      ds 2
nf_val:     ds 3
nf_t:       ds 2
nf_dig:     ds 6
mm_cur:     ds 1
mm_t:       ds 1
mm_pc:      ds 1
it_cur:     ds 1
it_n:       ds 1
it_t:       ds 2
it_id:      ds 1
it_desc:    ds 1
it_box:     ds 28
mtxt:       ds 160
