; FF3's main menu (Start on the map) on the Game Boy Color screen: FF3's commands (Item, Magic,
; Equip, Status, Order, Job, Save) plus Config and Suspend (owner's decision). FF3's rules come
; from its menu code (3C/3D); the screens are ours (full-screen windows of 20 x 18 tiles).
; Memory while the menu shows (the field's map tables, rebuilt when it closes): $C900 tile shadow
; (32 x 18), $CB40 attribute shadow, $CD80 variables. $C400-$C7FF stay free for FF3's battle
; zero page / variables (the equipment update runs FF3's battle algorithm $05).

rHDMA1     = $FF51
rHDMA2     = $FF52
rHDMA3     = $FF53
rHDMA4     = $FF54
rHDMA5     = $FF55
M_T        = $C900          ; 32 x 18 tiles (copied whole by general DMA in V-Blank)
M_A        = $CB40          ; 32 x 18 attributes
M_STR      = $CE00          ; a string (40)
M_HAND     = $EE            ; the hand (OBJ tile, VRAM bank 1; battle's SPR_HAND)
M_ATTR     = $0F            ; window cells: palette 7, VRAM bank 1

section bank B_MENU, $4000
; ---- the menu (called from the field; the field reloads its map after)
m_main:     call m_enter
            xor a
            ld [m_cur], a
.top:       call m_mainscr
.lp:        ld a, [m_cur]                   ; the hand at (1 + cursor, 1)
            inc a
            ld b, a
            ld c, 1
            call m_hand
            call m_frame
            ldh a, [pad_new]
            bit 6, a
            jr nz, .up
            bit 7, a
            jr nz, .dn
            and PAD_B | PAD_START
            jp nz, m_leave
            ldh a, [pad_new]
            and PAD_A
            jr z, .lp
            call m_sfx_ok
            ld a, [m_cur]
            add a
            ld hl, .cmds
            add l
            ld l, a
            jr nc, .j
            inc h
.j:         ld a, [hl+]
            ld h, [hl]
            ld l, a
            call .go
            jr .top
.go:        jp hl
.up:        ld a, [m_cur]
            dec a
            cp $FF
            jr nz, .m
            ld a, M_NCMD - 1
            jr .m
.dn:        ld a, [m_cur]
            inc a
            cp M_NCMD
            jr c, .m
            xor a
.m:         ld [m_cur], a
            call m_sfx_move
            jr .lp
.cmds:      dw m_item, m_magic, m_equip, m_status, m_order, m_job, m_config, m_save, m_suspend
M_NCMD     = 9

; ---- the main screen: commands (0, 0) 9 x 11, Gil / CP (0, 11) 9 x 7, the party (9, 0) 11 x 18
m_mainscr:  call m_clear
            ld de, $0000
            ld bc, $0B09
            call m_win
            ld hl, m_cmdtxt                 ; the commands (FF3's text $31, ours after)
            ld de, $0101
            ld b, M_NCMD
.c:         push bc
            push de
            call m_puts0
            pop de
            pop bc
            inc d
            dec b
            jr nz, .c
            ld de, $0B00
            ld bc, $0709
            call m_win
            ld hl, m_gil
            ld de, $0C01
            call m_puts0
            ld hl, SRAM_PAGE + $1C          ; gil ($601C, 3 bytes)
            ld de, $0D01
            ld b, 7
            call m_num24
            ld hl, m_cp
            ld de, $0F01
            call m_puts0
            ld a, [SRAM_PAGE + $1B]         ; cp ($601B)
            ld l, a
            ld h, 0
            ld de, $1005
            ld b, 3
            call m_num
            call m_party
            jp m_show

; the party window (9, 0) 11 x 18: per member 4 rows from 1 + 4 i: name, level, (status), HP
m_party:    ld de, $0009
            ld bc, $120B
            call m_win
            ld c, 0
.m:         push bc
            ld a, c
            add a
            add a
            inc a
            ld d, a                         ; row
            ld e, 13
            ld a, c
            call m_name
            inc d
            ld a, c
            call m_stword                   ; FF3's 3F/F299: the level, or an ailment's word
            jr nz, .s
            ld hl, m_lv
            call m_puts0
            pop bc
            push bc
            ld a, c
            call m_choff
            inc a                           ; level + 1 ($6101)
            ld l, a
            ld h, high(SRAM_PAGE + $100)
            ld a, [hl]
            inc a
            ld l, a
            ld h, 0
            ld e, 16
            ld b, 2
            call m_num
.s:         inc d
            ld e, 13
            inc d
            ld e, 10
            pop bc
            push bc
            ld a, c
            call m_hpline
            pop bc
            push bc
            call m_pict
            pop bc
            inc c
            ld a, c
            cp 4
            jr nz, .m
            ret

; member A's HP "cur/max" at (D, E) (9 cells)
m_hpline:   push de
            call m_choff
            add $0C
            ld l, a
            ld h, high(SRAM_PAGE + $100)
            ld a, [hl+]
            ld c, a
            ld a, [hl+]
            ld b, a
            push hl
            ld h, b
            ld l, c
            ld b, 4
            call m_num
            ld a, '/'
            call m_putc
            inc e
            pop hl
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld b, 4
            call m_num
            pop de
            ret

; member A's name (FF3 codes, 6) at (D, E)
m_name:     push de
            call m_choff
            add 6
            ld l, a
            ld h, high(SRAM_PAGE + $100)
            ld b, 6
.n:         ld a, [hl+]
            push hl
            push bc
            call m_ff3c
            call m_putc
            pop bc
            pop hl
            inc e
            dec b
            jr nz, .n
            pop de
            ret
; FF3 text code A -> our font (C_FF3ASC, B_OWN)
m_ff3c:     ld l, a
            ld h, 0
            ld bc, C_FF3ASC
            add hl, bc
            ld a, B_OWN
            jp far_byte

; member A's ailment word at (D, E) (3F/F2BB: death, stone, toad, silence, mini, blind, poison:
; t8200 $16, $17, $1B-$1F); Z set when well
m_stword:   call m_choff
            add 2
            ld l, a
            ld h, high(SRAM_PAGE + $100)
            ld a, [hl]                      ; status ($6102)
            and $FE
            ret z
            ld b, $16
            add a
            jr c, .w
            inc b
            add a
            jr c, .w
            ld b, $1B
.f:         add a
            jr c, .w
            inc b
            jr .f
.w:         ld a, b
            push de
            call m_t82
            pop de
            ld a, 6
            call m_putsn
            or 1
            ret

; member C's picture (job graphics, 6 OBJ tiles at 6 C) at the left of its block in the party
; window: x 88 (+ 4 in the back row), y 1 + 4 C rows
m_pict:     ld a, c
            add a
            add a
            inc a
            add a
            add a
            add a
            add 16
            ld d, a                         ; y
            ld a, c
            call m_choff
            add $0F
            ld l, a
            ld h, high(SRAM_PAGE + $200)
            ld a, [hl]                      ; row ($620F bit 0)
            and 1
            add a
            add a
            add 80 + 8
            ld e, a                         ; x
; the picture of member C at (E, D) (OAM entries 1 + 6 C)
m_pictxy:   ld a, c
            add a
            ld b, a
            add a
            add b
            ld b, a                         ; 6 C
            inc a
            add a
            add a
            ld l, a
            ld h, high(oam_buf)
            ld a, c
            push hl
            ld hl, m_jpal
            add l
            ld l, a
            jr nc, .p
            inc h
.p:         ld a, [hl]
            and 3
            or $08
            ld c, a
            pop hl
            push de
            ld a, 3
.r:         push af
            ld a, d
            ld [hl+], a
            ld a, e
            ld [hl+], a
            ld a, b
            ld [hl+], a
            inc b
            ld a, c
            ld [hl+], a
            ld a, d
            ld [hl+], a
            ld a, e
            add 8
            ld [hl+], a
            ld a, b
            ld [hl+], a
            inc b
            ld a, c
            ld [hl+], a
            ld a, d
            add 8
            ld d, a
            pop af
            dec a
            jr nz, .r
            pop de
            ret

; ---- choose a member: C = cancelled; [m_who] = member (FF3's 3D/A6B4: the hand at the party)
m_member:   ld a, [m_who]
            and 3
            ld [m_who], a
.lp:        ld a, [m_who]
            add a
            add a
            inc a
            ld b, a
            ld c, 10
            call m_hand2
            call m_frame
            ldh a, [pad_new]
            bit 6, a
            jr nz, .up
            bit 7, a
            jr nz, .dn
            bit 1, a                        ; B: cancelled
            jr nz, .x
            and PAD_A
            jr z, .lp
            call m_sfx_ok
            call m_hand2off
            and a
            ret
.x:         call m_hand2off
            scf
            ret
.up:        ld a, [m_who]
            dec a
            jr .m
.dn:        ld a, [m_who]
            inc a
.m:         and 3
            ld [m_who], a
            call m_sfx_move
            jr .lp

; ---- 4 Order: FF3's row select (3D/A696): the chosen member's row toggles, again until B
m_order:    call m_member
            ret c
.t:         ld a, [m_who]
            call m_choff
            add 2
            ld l, a
            ld h, high(SRAM_PAGE + $100)
            ld a, [hl]
            and $C0
            jr nz, .n                       ; dead or stone: no change
            ld a, l
            add $0D                         ; $620F
            ld l, a
            inc h
            ld a, [hl]
            xor 1
            ld [hl], a
.n:         ld a, [m_who]
            ld c, a
            call m_pict
            call m_member
            jr nc, .t
            ret

; ---- 3 Status (FF3's 3D/A83B, text $47 laid out for our screen)
m_status:   call m_member
            ret c
.again:     ld a, [m_who]
            ld c, a
            %FAR B_BSCR, bs_fequip          ; FF3's equipment update (its battle values)
            call m_clear
            ld de, $0000
            ld bc, $1214
            call m_win
            ld a, [m_who]
            ld c, a
            ld de, $0104
            ld a, c
            call m_name
            ld hl, m_lv
            ld e, 13
            call m_puts0
            call m_who_off
            inc a
            call m_sp1
            inc a
            ld l, a
            ld h, 0
            ld e, 16
            ld b, 2
            call m_num
            ld de, $0204                    ; the job's name (t8200 $E2 + job)
            call m_who_off
            call m_sp1
            add $E2
            push de
            call m_t82
            pop de
            ld a, 14
            call m_putsn
            ld de, $0304
            ld hl, m_hp
            call m_puts0
            ld e, 7
            ld a, [m_who]
            call m_hpline
            ld de, $0501                    ; MP: 8 levels (current)
            ld hl, m_mp
            call m_puts0
            ld e, 4
            ld c, 0
.mp:        push bc
            call m_who_off
            add $30
            add c
            add c
            call m_sp1
            ld l, a
            ld h, 0
            ld b, 1
            call m_num
            pop bc
            inc c
            ld a, c
            cp 8
            jr z, .mpx
            ld a, '/'
            call m_putc
            inc e
            jr .mp
.mpx:       ld de, $0701                    ; experience ($6103, 3 bytes)
            ld hl, m_exp
            call m_puts0
            call m_who_off
            add 3
            ld l, a
            ld h, high(SRAM_PAGE + $100)
            ld de, $070B
            ld b, 7
            call m_num24
            ld de, $0801                    ; proficiency ($6110 + 1)
            ld hl, m_prof
            call m_puts0
            call m_who_off
            add $10
            call m_sp1
            inc a
            ld l, a
            ld h, 0
            ld de, $0810
            ld b, 2
            call m_num
            ld de, $0A01                    ; the five stats ($6117-$611B)
            ld c, 0
.st:        push bc
            push de
            ld a, c
            call m_label
            pop de
            push de
            ld e, 16
            call m_who_off
            add $17
            add c
            call m_sp1
            ld l, a
            ld h, 0
            ld b, 2
            call m_num
            pop de
            inc d
            pop bc
            inc c
            ld a, c
            cp 5
            jr nz, .st
            ld de, $1001                    ; attack: multiplier ($6121 + $6126) x power
            ld a, 5                         ;   ($6123 + $6128; 1 for a toad / mini)
            call m_label
            call m_who_off
            add $21
            call m_sp1
            ld b, a
            call m_who_off
            add $26
            call m_sp1
            add b
            ld l, a
            ld h, 0
            ld de, $100A
            ld b, 2
            call m_num
            ld a, 'x'
            call m_putc
            call m_toad
            ld hl, 1
            jr nz, .a1
            call m_who_off
            add $23
            call m_sp1
            ld b, a
            call m_who_off
            add $28
            call m_sp1
            add b
            ld l, a
            ld a, 0
            adc 0
            ld h, a
.a1:        ld de, $100F
            ld b, 3
            call m_num
            ld de, $1101                    ; defense: multiplier ($612B) x $612D
            ld a, 7
            call m_label
            call m_who_off
            add $2B
            call m_sp1
            ld l, a
            ld h, 0
            ld de, $110A
            ld b, 2
            call m_num
            ld a, 'x'
            call m_putc
            call m_toad
            ld hl, 1
            jr nz, .d1
            call m_who_off
            add $2D
            call m_sp1
            ld l, a
            ld h, 0
.d1:        ld de, $110F
            ld b, 3
            call m_num
            ld a, [m_who]
            ld c, a
            ld de, $1810                    ; (y 24, x 16: rows 1-3, columns 1-2)
            call m_onepict
            call m_show
.w:         call m_frame                    ; left / right: the next member; A / B: back
            ldh a, [pad_new]
            bit 4, a
            jr nz, .nx
            bit 5, a
            jr nz, .pv
            and PAD_A | PAD_B
            jr z, .w
            ret
.nx:        ld a, [m_who]
            inc a
            jr .ch
.pv:        ld a, [m_who]
            dec a
.ch:        and 3
            ld [m_who], a
            call m_sfx_move
            jp .again
; Z clear for a toad / mini ($6102 & $28)
m_toad:     call m_who_off
            add 2
            call m_sp1
            and $28
            ret
; A = [m_who] x $40
m_who_off:  ld a, [m_who]
m_choff:    rrca
            rrca
            and $C0
            ret
; A = [SRAM_PAGE + $100 + A] (character page 1)
m_sp1:      push hl
            ld l, a
            ld h, high(SRAM_PAGE + $100)
            ld a, [hl]
            pop hl
            ret
; only member C's picture (others hidden) at (E, D)
m_onepict:  push bc
            push de
            call m_sprclr
            pop de
            pop bc
            jp m_pictxy

; status label A (m_labels: 0-4 the stats, 5 attack, 6 hit rate, 7 defense) at (D, E)
m_label:    ld hl, m_labels
            ld b, a
            inc b
.f:         dec b
            jp z, m_puts0
.s:         ld a, [hl+]
            and a
            jr nz, .s
            jr .f

; ---- not yet: an error sound (first pass)
m_item:
m_magic:
m_equip:
m_job:
m_config:
m_save:
m_suspend:  jp m_sfx_err

; ---- FF3's sounds: $85 confirm, $98 move, $86 error (3E/D20D, D213, D529)
m_sfx_ok:   ld a, $05
            jp sfx_play
m_sfx_move: ld a, $18
            jp sfx_play
m_sfx_err:  ld a, $06
            jp sfx_play

; ---- screen: enter (black, OBJ tiles, palettes), frame, leave
m_enter:    call wait_vbl
            call pal_black
            ld a, 1
            ld [guard_on], a
            ldh [snd_isr], a
            ld a, $20
            ldh [rSTAT], a
            xor a
            ldh [rSCX], a
            ldh [rSCY], a
            ld a, LCDC_ON
            ldh [rLCDC], a
            call m_sprclr
            call hram_dma
            ld a, 1                         ; OBJ tiles (VRAM bank 1): the party's pictures,
            ldh [rVBK], a                   ;   the hand
            ld c, 0
.p:         push bc
            ld a, c
            call m_choff
            pop bc
            push bc
            call m_jobgfx
            pop bc
            inc c
            ld a, c
            cp 4
            jr nz, .p
            ld hl, C_SPRDIG
            ld de, $8000 + 16 * $E0
            ld bc, 16 * 16
            ld a, B_OWN
            call far_copy
            xor a
            ldh [rVBK], a
            xor a
            ldh [snd_isr], a
            ldh [rSTAT], a
            ld [guard_on], a
            %FAR B_BSCR, bs_objpal          ; OBJ palettes: FF3's battle character palettes
            ld de, m_jpal
            %FAR B_BSCR, bs_jpals
            ret
; member C's standing pose (6 tiles) from B_CGFX ($4000 + job x $2A0) to OBJ tiles 6 C
m_jobgfx:   ld a, c
            call m_choff
            ld l, a
            ld h, high(SRAM_PAGE + $100)
            ld a, [hl]
            ld l, a
            ld h, 0
            ld de, $2A0
            call m_mul16                    ; HL = job x $2A0
            ld de, $4000
            add hl, de
            push hl
            ld a, c
            add a
            ld b, a
            add a
            add b
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, $8000
            add hl, de
            ld d, h
            ld e, l
            pop hl
            ld bc, 6 * 16
            ld a, B_CGFX
            jp far_copy
; HL = L x DE (L < 256)
m_mul16:    ld a, l
            ld hl, 0
.l:         and a
            ret z
            srl a
            jr nc, .s
            add hl, de
.s:         sla e
            rl d
            jr .l

; the shadow shown: copied in the next V-Blank, palettes there too
m_show:     ld a, 1
            ld [m_dirty], a
            call m_frame
            ld a, [m_pal]
            and a
            ret nz
            inc a
            ld [m_pal], a
            call wait_vbl
            jp pal_apply
; a frame: V-Blank, the shadow by general DMA when changed (36 + 36 blocks: within V-Blank), OAM,
; sound, the pad
m_frame:    call wait_vbl
            ld a, [m_dirty]
            and a
            jr z, .n
            xor a
            ld [m_dirty], a
            ldh [rVBK], a
            ld a, high(M_T)
            ldh [rHDMA1], a
            ld a, low(M_T)
            ldh [rHDMA2], a
            ld a, $98
            ldh [rHDMA3], a
            xor a
            ldh [rHDMA4], a
            ld a, 35
            ldh [rHDMA5], a
            ld a, 1
            ldh [rVBK], a
            ld a, high(M_A)
            ldh [rHDMA1], a
            ld a, low(M_A)
            ldh [rHDMA2], a
            ld a, $98
            ldh [rHDMA3], a
            xor a
            ldh [rHDMA4], a
            ld a, 35
            ldh [rHDMA5], a
            xor a
            ldh [rVBK], a
.n:         call hram_dma
            call snd_frame
            jp read_pad
; leave: black; the field reloads its map
m_leave:    call wait_vbl
            call pal_black
            call m_sprclr
            xor a
            ld [m_pal], a
            jp hram_dma

; ---- the shadow: clear (blank cells), windows, letters, numbers
m_clear:    ld hl, M_T
            ld bc, 32 * 18
.t:         ld a, ' '
            ld [hl+], a
            dec bc
            ld a, b
            or c
            jr nz, .t
            ld hl, M_A
            ld bc, 32 * 18
.a:         ld a, M_ATTR
            ld [hl+], a
            dec bc
            ld a, b
            or c
            jr nz, .a
            ret
; HL = M_T + 32 D + E
m_cell:     ld l, d
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld a, e
            add l
            ld l, a
            ld a, h
            adc high(M_T)
            ld h, a
            ret
; letter A at (D, E); keeps BC DE HL
m_putc:     push hl
            push af
            call m_cell
            pop af
            ld [hl], a
            pop hl
            ret
; a 0-terminated string HL at (D, E); HL after the 0; E after the text
m_puts0:    ld a, [hl+]
            and a
            ret z
            call m_putc
            inc e
            jr m_puts0
; M_STR at (D, E), at most A letters (codes < $20 skipped)
m_putsn:    ld b, a
            ld hl, M_STR
.c:         ld a, [hl+]
            and a
            ret z
            cp ' '
            jr c, .c
            call m_putc
            inc e
            dec b
            jr nz, .c
            ret
; a window (D row, E column), B rows x C columns: FF3's frame, spaces inside
m_win:      push de
            push bc
            ld a, FR_TL
            ld h, FR_T
            ld l, FR_TR
            call .row
            pop bc
            push bc
            ld a, b
            sub 2
.m:         push af
            inc d
            ld a, FR_L
            ld h, ' '
            ld l, FR_R
            call .row
            pop af
            dec a
            jr nz, .m
            inc d
            ld a, FR_BL
            ld h, FR_B
            ld l, FR_BR
            call .row
            pop bc
            pop de
            ret
.row:       push de                         ; A first, H middle (C - 2), L last
            call m_putc
            inc e
            ld b, c
            dec b
            dec b
.r:         ld a, h
            call m_putc
            inc e
            dec b
            jr nz, .r
            ld a, l
            call m_putc
            pop de
            ret
; HL (0-65535) as B digits (leading spaces) at (D, E); E after
m_num:      push bc
            push de
            ld de, m_digs
            ld bc, -10000
            call .d
            ld bc, -1000
            call .d
            ld bc, -100
            call .d
            ld bc, -10
            call .d
            ld a, l
            add '0'
            ld [de], a
            ld hl, m_digs                   ; leading zeros -> spaces
            ld b, 4
.z:         ld a, [hl]
            cp '0'
            jr nz, .o
            ld [hl], ' '
            inc hl
            dec b
            jr nz, .z
.o:         pop de
            pop bc
            ld a, 5
            sub b
            ld hl, m_digs
            add l
            ld l, a
            jr nc, .p
            inc h
.p:         ld a, [hl+]
            call m_putc
            inc e
            dec b
            jr nz, .p
            ret
.d:         ld a, '0' - 1
.dl:        inc a
            add hl, bc
            jr c, .dl
            push af
            ld a, l
            sub c
            ld l, a
            ld a, h
            sbc b
            ld h, a
            pop af
            ld [de], a
            inc de
            ret
; the 24-bit number at HL (little end first) as B digits (<= 7) at (D, E)
m_num24:    push de
            push bc
            ld a, [hl+]
            ld [m_n24], a
            ld a, [hl+]
            ld [m_n24 + 1], a
            ld a, [hl]
            ld [m_n24 + 2], a
            ld hl, m_digs
            ld c, 7
.cl:        ld [hl], ' '
            inc hl
            dec c
            jr nz, .cl
            ld hl, m_digs + 6               ; digits from the right: divide by 10
.dv:        push hl
            call .div10                     ; A = remainder
            pop hl
            add '0'
            ld [hl-], a
            ld a, [m_n24]
            ld b, a
            ld a, [m_n24 + 1]
            or b
            ld b, a
            ld a, [m_n24 + 2]
            or b
            jr nz, .dv
            pop bc
            pop de
            ld a, 7
            sub b
            ld hl, m_digs
            add l
            ld l, a
            jr nc, .p
            inc h
.p:         ld a, [hl+]
            call m_putc
            inc e
            dec b
            jr nz, .p
            ret
.div10:     ld hl, m_n24 + 2                ; m_n24 /= 10, A = remainder
            ld c, 3
            xor a
.b:         ld b, 8
            ld e, [hl]
.bit:       sla e
            rla
            cp 10
            jr c, .s
            sub 10
            inc e
.s:         dec b
            jr nz, .bit
            ld [hl], e
            dec hl
            dec c
            jr nz, .b
            ret

; t8200 string A -> M_STR (B_TEXT index T_T8200)
m_t82:      ld l, a
            ld h, 0
            ld e, l
            ld d, h
            add hl, hl
            add hl, de
            ld de, T_T8200
            add hl, de
            push hl
            ld de, m_tmp
            ld bc, 3
            ld a, B_TEXT
            call far_copy
            pop hl
            ld a, [m_tmp + 1]
            ld l, a
            ld a, [m_tmp + 2]
            ld h, a
            ld de, M_STR
            ld bc, 32
            ld a, [m_tmp]
            call far_copy
            ld hl, M_STR                    ; (end at a 0 or a new line)
            ld b, 31
.e:         ld a, [hl]
            and a
            ret z
            cp $0A
            jr z, .z
            inc hl
            dec b
            jr nz, .e
.z:         ld [hl], 0
            ret

; ---- sprites: the hand (OAM 0), a second hand (OAM 39), all off
m_hand:     ld hl, oam_buf
.s:         ld a, b                         ; at BG row B, column C (left of the text)
            add a
            add a
            add a
            add 16
            ld [hl+], a
            ld a, c
            add a
            add a
            add a
            ld [hl+], a
            ld a, M_HAND
            ld [hl+], a
            ld [hl], $0B
            ret
m_hand2:    ld hl, oam_buf + 4 * 39
            jr m_hand.s
m_hand2off: xor a
            ld [oam_buf + 4 * 39], a
            ret
m_sprclr:   ld hl, oam_buf
            ld b, 160
            xor a
.z:         ld [hl+], a
            dec b
            jr nz, .z
            ret

section wram, $CD80
m_cur:      ds 1
m_who:      ds 1
m_dirty:    ds 1
m_pal:      ds 1
m_jpal:     ds 4
m_digs:     ds 8
m_n24:      ds 3
m_tmp:      ds 3
