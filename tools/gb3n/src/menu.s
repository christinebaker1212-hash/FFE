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
M_BLACK    = $01            ; outside the windows: colour 0 (VRAM bank 1 tile 1, cleared at boot)

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
.t:         ld a, M_BLACK
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

; ==== cart RAM (Lot Check: enabled only around each access; every file checked on reading)
; bank 0: $A000 / $A400 / $A800 FF3's three files (its $6400 / $6800 / $6C00 pages), $AC00 + 4 f
; our check (magic 'F', '3', 16-bit sum of the page), $AC10 FF3's save count ($7F38-$7F3A).
SR_ENABLE  = $0000
SR_BANK    = $4000
SR_FILE    = $A000
SR_CHECK   = $AC00
SR_COUNT   = $AC10

sr_on:      ld [SR_BANK], a                 ; A = cart RAM bank
            ld a, $0A
            ld [SR_ENABLE], a
            ret
sr_off:     xor a
            ld [SR_ENABLE], a
            ret
; HL = file A's address in cart RAM
sr_addr:    add a
            add a
            add high(SR_FILE)
            ld h, a
            ld l, 0
            ret
; DE = the 16-bit sum of the 1024 bytes at HL
sr_sum:     ld de, 0
            ld bc, $400
.s:         ld a, [hl+]
            add e
            ld e, a
            jr nc, .n
            inc d
.n:         dec bc
            ld a, b
            or c
            jr nz, .s
            ret
; file A: 0 empty, 1 good, 2 damaged (our check present, the page's sums wrong)
sr_state:   ld [m_sf], a
            xor a
            call sr_on
            ld a, [m_sf]
            add a
            add a
            ld l, a
            ld h, high(SR_CHECK)
            ld a, [hl+]
            cp 'F'
            jr nz, .empty
            ld a, [hl]
            cp '3'
            jr nz, .empty
            ld a, [m_sf]
            call sr_addr
            push hl
            call sr_sum
            pop hl
            ld a, [m_sf]
            add a
            add a
            add 2
            ld c, a
            ld b, high(SR_CHECK)
            ld a, [bc]
            cp e
            jr nz, .bad
            inc c
            ld a, [bc]
            cp d
            jr nz, .bad
            push hl                         ; FF3's own check (3D/AE97): $6019 = $5A, the
            ld de, $19                      ;   8-bit sum of the page $FF
            add hl, de
            ld a, [hl]
            pop hl
            cp $5A
            jr nz, .bad
            ld bc, $400
            ld e, 0
.f:         ld a, [hl+]
            add e
            ld e, a
            dec bc
            ld a, b
            or c
            jr nz, .f
            ld a, e
            inc a
            jr nz, .bad
            call sr_off
            ld a, 1
            ret
.bad:       call sr_off
            ld a, 2
            ret
.empty:     call sr_off
            xor a
            ret
; the page ($D000) into file A (FF3's 3D/A960 after its checksum 3D/AE5C), our check after
sr_write:   ld [m_sf], a
            xor a
            call sr_on
            ld a, [m_sf]
            call sr_addr
            push hl
            ld d, h
            ld e, l
            ld hl, SRAM_PAGE
            ld bc, $400
            call memcpy
            pop hl
            call sr_sum
            ld a, [m_sf]
            add a
            add a
            ld l, a
            ld h, high(SR_CHECK)
            ld [hl], 'F'
            inc l
            ld [hl], '3'
            inc l
            ld [hl], e
            inc l
            ld [hl], d
            jp sr_off
; file A into the page
sr_read:    ld [m_sf], a
            xor a
            call sr_on
            ld a, [m_sf]
            call sr_addr
            ld de, SRAM_PAGE
            ld bc, $400
            call memcpy
            jp sr_off
; FF3's save count (3D/A897: $7F38 = $55, $7F39 = $AA, else count 1) -> A; B = 1: count + 1 stored
sr_count:   xor a
            call sr_on
            ld hl, SR_COUNT
            ld a, [hl+]
            cp $55
            jr nz, .i
            ld a, [hl+]
            cp $AA
            jr z, .v
.i:         ld hl, SR_COUNT
            ld [hl], $55
            inc l
            ld [hl], $AA
            inc l
            ld [hl], 1
.v:         ld hl, SR_COUNT + 2
            ld a, b
            and a
            ld a, [hl]
            jr z, .x
            inc a                           ; (3D/A93D: up to 99, then 1)
            cp 100
            jr c, .s
            ld a, 1
.s:         ld [hl], a
.x:         ld c, a
            call sr_off
            ld a, c
            ret
; FF3's update sram checksum (3D/AE5C): world, vehicle, world position into the page, $601A
sr_ff3sum:  ld a, [world]
            ld [SRAM_PAGE + $08], a
            xor a                           ; (vehicles: on foot for now)
            ld [SRAM_PAGE + $0F], a
            ld a, [pos_x]
            ld [SRAM_PAGE + $09], a
            ld a, [pos_y]
            ld [SRAM_PAGE + $0A], a
            xor a
            ld [SRAM_PAGE + $1A], a
            ld a, $5A
            ld [SRAM_PAGE + $19], a
            ld hl, SRAM_PAGE
            ld bc, $400
            ld e, 0
.s:         ld a, [hl+]
            add e
            ld e, a
            dec bc
            ld a, b
            or c
            jr nz, .s
            ld a, e
            cpl
            ld [SRAM_PAGE + $1A], a
            ret

; ---- 7 Save (FF3's 3D/A897; the world map only, as FF3 offers it)
m_save:     ld a, [wmode]
            and a
            jp z, m_sfx_err
            ld b, 0                         ; the save count into the page, FF3's sum
            call sr_count
            ld [SRAM_PAGE + $14], a
            call sr_ff3sum
            call m_sprclr
            xor a
            ld [m_f], a
.scr:       call m_files                    ; the three files (rows 3-14)
            ld a, $4B                       ; "Please choose the file to save to."
            call m_msg
            call m_show
.lp:        ld a, [m_f]                     ; the hand at file f
            call m_fhand
            call m_frame
            ldh a, [pad_new]
            bit 6, a
            jr nz, .up
            bit 7, a
            jr nz, .dn
            bit 1, a
            jr nz, .x
            and PAD_A
            jr z, .lp
            call m_sfx_ok
            ld hl, m_s_erase                ; "This erases old data." (t8200 $4C) Yes / No
            call m_msghl
            call m_show
            call m_yesno
            jr c, .scr
            ld a, [m_f]
            call sr_write
            ld b, 1                         ; the count up (3D/A93D)
            call sr_count
            ld a, $4D                       ; "Saving is complete."
            call m_msg
            ld a, [m_f]
            call m_files.one
            call m_show
            call m_hand2off
            call m_waitkey
.x:         call m_hand2off
            ret
.up:        ld a, [m_f]
            dec a
            cp $FF
            jr nz, .m
            ld a, 2
            jr .m
.dn:        ld a, [m_f]
            inc a
            cp 3
            jr c, .m
            xor a
.m:         ld [m_f], a
            call m_sfx_move
            jr .lp

; the hand (OAM 39) at file A's window
m_fhand:    add a
            add a
            inc a
            ld b, a
            ld c, 1
            jp m_hand2
; the files: three windows (0, 4 f) 20 x 4: "n Name  Lv xx" / "Job" or empty / damaged
m_files:    call m_clear
            xor a
            call .one
            ld a, 1
            call .one
            ld a, 2
.one:       ld [m_f2], a
            ld b, a
            add a
            add a
            ld d, a                         ; row 4 f
            ld e, 0
            ld bc, $0414
            call m_win
            inc d
            ld e, 2
            ld a, [m_f2]
            add '1'
            call m_putc
            ld e, 4
            push de
            ld a, [m_f2]
            call sr_state
            pop de
            cp 1
            jr z, .good
            and a
            ret z                           ; empty: the number only
            ld hl, m_damaged
            jp m_puts0
.good:      push de                         ; the first member's name, level (cart RAM: on
            xor a                           ;   only to copy them)
            call sr_on
            ld a, [m_f2]
            call sr_addr
            inc h                           ; $6100: level, name
            ld de, m_fbuf
            ld bc, 12
            call memcpy
            call sr_off
            pop de
            ld hl, m_fbuf + 6
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
            ld e, 12
            ld hl, m_lv
            call m_puts0
            ld a, [m_fbuf + 1]
            inc a
            ld l, a
            ld h, 0
            ld e, 15
            ld b, 2
            jp m_num

; t8200 message A in the bottom window (0, 13) 20 x 5 (its lines, wrapped at build time)
m_msg:      push af
            pop af
            call m_t82all
            ld hl, M_STR
; the string HL (lines split by $0A / $0C) in the bottom window
m_msghl:    push hl
            ld de, $0D00
            ld bc, $0514
            call m_win
            pop hl
            ld de, $0E01
.c:         ld a, [hl+]
            and a
            ret z
            cp $0A
            jr z, .nl
            cp $0C
            jr z, .nl
            cp ' '
            jr c, .c
            call m_putc
            inc e
            jr .c
.nl:        inc d
            ld e, 1
            jr .c
; t8200 string A -> M_STR whole (up to 80 bytes, 0 ended)
m_t82all:   ld l, a
            ld h, 0
            ld e, l
            ld d, h
            add hl, hl
            add hl, de
            ld de, T_T8200
            add hl, de
            ld de, m_tmp
            ld bc, 3
            ld a, B_TEXT
            call far_copy
            ld a, [m_tmp + 1]
            ld l, a
            ld a, [m_tmp + 2]
            ld h, a
            ld de, M_STR
            ld bc, 80
            ld a, [m_tmp]
            jp far_copy
; Yes / No in the message window's last line (t8200 $06's words): C = No / B
m_yesno:    xor a
            ld [m_yn], a
            ld hl, m_s_yes
            ld de, $1002
            call m_puts0
            ld hl, m_s_no
            ld e, 8
            call m_puts0
            ld a, 1
            ld [m_dirty], a
.lp:        ld a, [m_yn]
            and a
            ld c, 2
            jr z, .h
            ld c, 8
.h:         ld b, 16
            call m_hand2
            call m_frame
            ldh a, [pad_new]
            and $30
            jr nz, .t
            ldh a, [pad_new]
            bit 1, a
            jr nz, .no
            and PAD_A
            jr z, .lp
            call m_hand2off
            ld a, [m_yn]
            and a
            jr nz, .no2
            call m_sfx_ok
            and a
            ret
.t:         ld a, [m_yn]
            xor 1
            ld [m_yn], a
            call m_sfx_move
            jr .lp
.no:        call m_hand2off
.no2:       call m_sfx_ok
            scf
            ret
; wait for A or B
m_waitkey:  call m_frame
            ldh a, [pad_new]
            and PAD_A | PAD_B
            jr z, m_waitkey
            ret
; FF3's window colours as BG palette 7 (cgb_pal + 64; work RAM bank 1)
m_winpal:   ld hl, I_WINPAL
            ld de, m_tmp
            ld bc, 4
            ld a, B_MAPINFO
            call far_copy
            ld de, cgb_pal + 64
            ld hl, m_tmp
            ld b, 4
.c:         ld a, [hl+]
            push hl
            push bc
            and $3F
            add a
            ld l, a
            ld h, high(I_RGB)
            ld a, low(I_RGB)
            add l
            ld l, a
            jr nc, .s
            inc h
.s:         push hl
            ld a, B_MAPINFO
            call far_byte
            ld [de], a
            inc de
            pop hl
            inc hl
            ld a, B_MAPINFO
            call far_byte
            ld [de], a
            inc de
            pop bc
            pop hl
            dec b
            jr nz, .c
            ret

; ==== the title: FF3's game load menu (3D/B9F6): the files, New Game; ours: Resume (later)
; returns A = 0 new game, 1 a file loaded into the page
t_title:    call m_enter
            call m_winpal
            ld a, $01                       ; FF3's song 1 (3D/BA41)
            call mus_play
            ld a, 3
            ld [m_f], a                     ; (New Game first: FF3's cursor $0C)
.scr:       call m_files
            ld de, $0C00
            ld bc, $0314
            call m_win
            ld a, $22                       ; "New Game"
            call m_t82
            ld de, $0D02
            ld a, 16
            call m_putsn
            call m_show
.lp:        ld a, [m_f]
            cp 3
            jr nz, .f
            ld bc, $0D01
            call m_hand2
            jr .w
.f:         call m_fhand
.w:         call m_frame
            ldh a, [pad_new]
            bit 6, a
            jr nz, .up
            bit 7, a
            jr nz, .dn
            and PAD_A
            jr z, .lp
            ld a, [m_f]
            cp 3
            jr z, .new
            call sr_state
            cp 1
            jr z, .load
            call m_sfx_err                  ; empty or damaged
            jr .lp
.load:      call m_sfx_ok
            ld a, [m_f]
            call sr_read
            call m_leave
            ld a, 1
            ld [m_res], a
            ret
.new:       call m_sfx_ok
            call m_leave
            xor a
            ld [m_res], a
            ret
.up:        ld a, [m_f]
            dec a
            cp $FF
            jr nz, .m
            ld a, 3
            jr .m
.dn:        ld a, [m_f]
            inc a
            cp 4
            jr c, .m
            xor a
.m:         ld [m_f], a
            call m_sfx_move
            jr .lp

; ==== New Game: the four names (FF3's 3D/B895: a name each, B on an empty name back to the one
; before); our grid: 9 x 5 letters, one case at a time (SELECT switches), B deletes, START ends
t_names:    call m_enter
            call m_winpal
            xor a
            ld [n_who], a
            ld [n_case], a
.ch:        xor a
            ld [n_cur], a
            ld a, [n_who]                   ; the name so far: its length
            call m_choff
            add 6
            ld l, a
            ld h, high(SRAM_PAGE + $100)
            ld b, 0
.ln:        ld a, [hl+]
            cp $FF
            jr z, .lx
            and a
            jr z, .lx
            inc b
            ld a, b
            cp 6
            jr nz, .ln
.lx:        ld a, b
            ld [n_len], a
            call n_fill                     ; (the rest padded with $FF)
.scr:       call n_draw
.lp:        ld a, [n_cur]                   ; the hand at letter n_cur
            ld c, 0
.dv:        cp 9
            jr c, .dd
            sub 9
            inc c
            jr .dv
.dd:        add a                           ; column 2 + 2 x, row 6 + 2 y
            add 2
            ld e, a
            ld a, c
            add a
            add 6
            ld b, a
            ld c, e
            call m_hand2
            call m_frame
            ldh a, [pad_new]
            ld b, a
            and $F0
            jp nz, .dir
            bit 2, b
            jr nz, .case
            bit 3, b
            jr nz, .done
            bit 1, b
            jr nz, .del
            bit 0, b
            jr z, .lp
            ld a, [n_len]                   ; A: a letter (6 at most)
            cp 6
            jr nc, .err
            ld a, [n_who]
            call m_choff
            add 6
            ld hl, n_len
            add [hl]
            ld e, a
            inc [hl]
            ld a, [n_case]
            and a
            ld hl, n_grid0
            jr z, .g
            ld hl, n_grid1
.g:         ld a, [n_cur]
            add l
            ld l, a
            jr nc, .g2
            inc h
.g2:        ld a, [hl]
            ld l, e
            ld h, high(SRAM_PAGE + $100)
            ld [hl], a
            call m_sfx_ok
            jp .scr
.err:       call m_sfx_err
            jp .lp
.del:       ld a, [n_len]                   ; B: the last letter off; none: the member before
            and a
            jr z, .back
            dec a
            ld [n_len], a
            call n_fill
            call m_sfx_ok
            jp .scr
.back:      ld a, [n_who]
            and a
            jr z, .err
            dec a
            ld [n_who], a
            call m_sfx_ok
            jp .ch
.case:      ld a, [n_case]
            xor 1
            ld [n_case], a
            call m_sfx_move
            jp .scr
.done:      ld a, [n_len]                   ; START: this name (not empty)
            and a
            jr z, .err
            call m_sfx_ok
            ld a, [n_who]
            inc a
            ld [n_who], a
            cp 4
            jp nz, .ch
            call m_hand2off
            jp m_leave
.dir:       ld a, [n_cur]
            bit 4, b
            jr nz, .r
            bit 5, b
            jr nz, .l
            bit 6, b
            jr nz, .u
            add 9                           ; down
            cp 45
            jr c, .s
            sub 45
            jr .s
.u:         sub 9
            jr nc, .s
            add 45
            jr .s
.r:         inc a
            cp 45
            jr c, .s
            xor a
            jr .s
.l:         dec a
            cp $FF
            jr nz, .s
            ld a, 44
.s:         ld [n_cur], a
            call m_sfx_move
            jp .lp
; the name's letters after n_len: $FF
n_fill:     ld a, [n_who]
            call m_choff
            add 6
            ld hl, n_len
            add [hl]
            ld l, a
            ld h, high(SRAM_PAGE + $100)
            ld a, [n_len]
            ld b, a
            ld a, 6
            sub b
            ret z
            ld b, a
.f:         ld [hl], $FF
            inc l
            dec b
            jr nz, .f
            ret
; the screen: the member (picture, name, job) at the top, the grid below
n_draw:     call m_clear
            ld de, $0000
            ld bc, $0514
            call m_win
            ld a, [n_who]
            ld de, $0105
            call m_name
            ld a, [n_len]                   ; the next letter's place: a dash
            cp 6
            jr nc, .nd
            add 5
            ld e, a
            ld a, '-'
            call m_putc
.nd:        ld a, [n_who]                   ; the job's name (t8200 $E2 + job)
            call m_choff
            call m_sp1
            add $E2
            call m_t82
            ld de, $0305
            ld a, 14
            call m_putsn
            ld de, $0500
            ld bc, $0D14
            call m_win
            ld a, [n_case]
            and a
            ld hl, n_grid0
            jr z, .g
            ld hl, n_grid1
.g:         ld d, 6
.r:         ld e, 2
            ld b, 9
.c:         push bc
            push hl
            ld a, [hl]
            call m_ff3c
            call m_putc
            pop hl
            pop bc
            inc hl
            inc e
            inc e
            dec b
            jr nz, .c
            inc d
            inc d
            ld a, d
            cp 16
            jr nz, .r
            ld de, $0F01
            ld hl, n_help0
            ld a, [n_case]
            and a
            jr z, .h
            ld hl, n_help1
.h:         call m_puts0
            ld de, $1001
            ld hl, n_help2
            call m_puts0
            call m_sprclr
            ld a, [n_who]
            ld c, a
            ld de, $1810
            call m_pictxy
            jp m_show

section wram, $CD80
m_cur:      ds 1
m_who:      ds 1
m_dirty:    ds 1
m_pal:      ds 1
m_jpal:     ds 4
m_digs:     ds 8
m_n24:      ds 3
m_tmp:      ds 3
m_f:        ds 1
m_f2:       ds 1
m_yn:       ds 1
m_fbuf:     ds 12
m_res:      ds 1
m_sf:       ds 1
n_who:      ds 1
n_case:     ds 1
n_cur:      ds 1
n_len:      ds 1
