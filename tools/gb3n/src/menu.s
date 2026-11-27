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
M_HAND     = $EE            ; the hand (OBJ tile, VRAM bank 1; battle's SPR_HAND)
M_ATTR     = $0F            ; window cells: palette 7, VRAM bank 1
M_BLACK    = $01            ; outside the windows: colour 0 (VRAM bank 1 tile 1, cleared at boot)

section wram, $C800
M_STR:      ds 256                          ; a string (the overlap check guards it)

section bank B_MENU, $4000
; ---- the menu (called from the field; the field reloads its map after)
m_main:     call m_enter
            xor a
            ld [m_cur], a
.top:       call m_mainscr
.lp:        ld a, [m_cur]                   ; the hand at (1 + cursor, 12)
            inc a
            ld b, a
            ld c, 12
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
            ld de, $000B                    ; (owner, 2026-11-27: the party on the left, the
            ld bc, $0B09                    ;   commands and Gil / CP on the right)
            call m_win
            ld hl, m_cmdtxt                 ; the commands (FF3's text $31, ours after)
            ld de, $010C
            ld b, M_NCMD
.c:         push bc
            push de
            call m_puts0
            pop de
            pop bc
            inc d
            dec b
            jr nz, .c
            ld de, $0B0B
            ld bc, $0709
            call m_win
            ld hl, m_gil
            ld de, $0C0C
            call m_puts0
            ld hl, SRAM_PAGE + $1C          ; gil ($601C, 3 bytes)
            ld de, $0D0C
            ld b, 7
            call m_num24
            ld hl, m_cp
            ld de, $0F0C
            call m_puts0
            ld a, [SRAM_PAGE + $1B]         ; cp ($601B)
            ld l, a
            ld h, 0
            ld de, $1010
            ld b, 3
            call m_num
            call m_party
            jp m_show

; the party window (0, 0) 11 x 18: per member 4 rows from 1 + 4 i: name, level, (status), HP
m_party:    ld de, $0000
            ld bc, $120B
            call m_win
            ld c, 0
.m:         push bc
            ld a, c
            add a
            add a
            inc a
            ld d, a                         ; row
            ld e, 4
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
            ld e, 7
            ld b, 2
            call m_num
.s:         inc d
            inc d
            ld e, 1
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
            add 8 + 8
            ld e, a                         ; x
; the picture of member C at (E, D) (OAM entries 1 + 6 C)
m_pictxy:   ld a, c
            add a
            ld b, a
            add a
            add b
            ld b, a                         ; 6 C (OAM entries 4 + 6 C: the hand has 0-3)
            add 4
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
            ld c, 1
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


; ---- FF3's sounds: $85 confirm, $98 move, $86 error (3E/D20D, D213, D529)
m_sfx_ok:   ld a, $05
            jp sfx_play
m_sfx_move: ld a, $18
            jp sfx_play
m_sfx_err:  ld a, $06
            jp sfx_play

; ---- screen: enter (black, OBJ tiles, palettes), frame, leave
m_enter:    xor a
            ld [m_mh], a
            ld [m_pal], a                   ; (these live in the map's tables: stale at first)
            ld [m_dirty], a
            call wait_vbl
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
            call hand_tiles                 ; FF3's 16 x 16 hand
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
; member [m_who]'s picture again (a new job): the tiles behind the line guard, its palette id
m_regfx:    call wait_vbl
            ld a, 1
            ld [guard_on], a
            ld a, $20
            ldh [rSTAT], a
            ld a, 1
            ldh [rVBK], a
            ld a, [m_who]
            ld c, a
            call m_jobgfx
            xor a
            ldh [rVBK], a
            ldh [rSTAT], a
            ld [guard_on], a
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
m_leave:    xor a
            ld [m_mh], a
            call wait_vbl
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
            call m_dec24
            jr m_n24p
; the 24-bit number at HL -> m_digs (7 characters, leading spaces)
m_dec24:    ld a, [hl+]
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
            call m_div10                    ; A = remainder
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
            ret
m_n24p:
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
m_div10:    ld hl, m_n24 + 2                ; m_n24 /= 10, A = remainder
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

; ---- sprites: FF3's 16 x 16 hand (OAM 0-3), a second hand (OAM 36-39), all off; the hand
; ends just left of column C, its finger at row B
m_hand:     ld hl, oam_buf
.s:         ld a, b
            add a
            add a
            add a
            add 16 - 2
            ld b, a
            ld a, c
            add a
            add a
            add a
            sub 8
            ld c, a
            jp hand16
m_hand2:    ld hl, oam_buf + 4 * 36
            jr m_hand.s
m_hand2off: ld hl, oam_buf + 4 * 36
            jp hand16off
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
            ld a, [veh]
            ld [SRAM_PAGE + $0F], a
            ld a, [pos_x]                   ; (FF3's $27 / $28: the party's tile - 7)
            sub 7
            ld [SRAM_PAGE + $09], a
            ld a, [pos_y]
            sub 7
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
m_msg:      call m_t82all
            ld hl, M_STR
; the string HL (lines split by $0A / $0C) in the bottom window
m_msghl:    push hl
            ld a, [m_mh]                    ; (the window: rows m_mrow .. + m_mh; m_mh 0: 13 / 5)
            and a
            jr nz, .w
            ld a, 13
            ld [m_mrow], a
            ld a, 5
            ld [m_mh], a
.w:         ld a, [m_mrow]
            ld d, a
            ld e, 0
            ld a, [m_mh]
            ld b, a
            ld c, 20
            call m_win
            pop hl
            inc d
            ld e, 1
.c:         ld a, [hl+]
            and a
            ret z
            cp $0A
            jr z, .nl
            cp $0C
            jr z, .nl
            cp $04                          ; {04}: the amount in m_val
            jr z, .num
            cp ' '
            jr c, .c
            call m_putc
            inc e
            jr .c
.nl:        inc d
            ld e, 1
            ld a, d                         ; (never past the screen)
            cp 17
            jr c, .c
            ret
.num:       push hl
            push de
            ld hl, m_val
            call m_dec24                    ; (printed without the leading spaces)
            pop de
            ld hl, m_digs
            ld b, 7
.n:         ld a, [hl+]
            cp ' '
            jr z, .n2
            call m_putc
            inc e
.n2:        dec b
            jr nz, .n
            pop hl
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
            ld bc, 255
            ld a, [m_tmp]
            call far_copy
            xor a
            ld [M_STR + 255], a
            ret
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
t_title:    call su_state                   ; a suspend point: Resume first
            ld [m_su], a
            call m_enter
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
            ld a, [m_su]
            and a
            jr z, .ns
            ld de, $0F00
            ld bc, $0314
            call m_win
            ld de, $1002
            ld hl, m_s_resume
            ld a, [m_su]
            cp 1
            jr z, .rs
            ld hl, m_damaged
.rs:        call m_puts0
.ns:        call m_show
.lp:        ld a, [m_f]
            cp 3
            jr nz, .f4
            ld bc, $0D01
            call m_hand2
            jr .w
.f4:        cp 4
            jr nz, .f
            ld bc, $1001
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
            cp 4
            jr z, .resume
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
.resume:    ld a, [m_su]
            cp 1
            jr nz, .rerr
            call m_sfx_ok
            call su_load
            call m_leave
            ld a, 2
            ld [m_res], a
            ret
.rerr:      call m_sfx_err
            jp .lp
.up:        ld a, [m_f]
            dec a
            cp $FF
            jr nz, .m
            call .last
            jr .m
.dn:        call .last
            ld b, a
            ld a, [m_f]
            cp b
            jr z, .z
            inc a
            jr .m
.z:         xor a
.m:         ld [m_f], a
            call m_sfx_move
            jp .lp
.last:      ld a, [m_su]                    ; the last entry: Resume (4) or New Game (3)
            and a
            ld a, 3
            ret z
            inc a
            ret

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

; ==== 0 Item (FF3's 3C/9EC2): the inventory ($60C0 ids, $60E0 counts) and a trash can; an item
; chosen twice is used, another swaps with it, the trash can discards it
I_TRASH    = 32
m_item:     xor a
            ld [m_icur], a
            ld [m_top], a
            ld a, $FF
            ld [m_isel], a
.scr:       call i_draw
.lp:        ld a, [m_icur]                  ; the hand at the cursor's row
            ld hl, m_top
            sub [hl]
            add 4
            ld b, a
            ld c, 1
            call m_hand
            ld a, [m_isel]                  ; the chosen one: the second hand
            cp $FF
            jr z, .ns
            ld hl, m_top
            sub [hl]
            jr c, .nh
            cp 13
            jr nc, .nh
            add 4
            ld b, a
            ld c, 2
            call m_hand2
            jr .ns
.nh:        call m_hand2off
.ns:        call m_frame
            ldh a, [pad_new]
            bit 6, a
            jr nz, .up
            bit 7, a
            jr nz, .dn
            bit 1, a
            jr nz, .b
            and PAD_A
            jr z, .lp
            call m_sfx_ok
            ld a, [m_isel]
            cp $FF
            jr nz, .two
            ld a, [m_icur]                  ; the first choice
            ld [m_isel], a
            jr .lp
.b:         call m_sfx_ok
            ld a, [m_isel]
            cp $FF
            jr z, .x
            ld a, $FF
            ld [m_isel], a
            call m_hand2off
            jr .lp
.x:         call m_hand2off
            ret
.two:       ld a, [m_isel]                  ; the second: trash, swap or use (3C/9FA5)
            ld [m_isel2], a
            ld a, $FF
            ld [m_isel], a
            call m_hand2off
            ld a, [m_icur]
            cp I_TRASH
            jr z, .trash
            ld b, a
            ld a, [m_isel2]
            cp I_TRASH
            jr z, .trash2
            cp b
            jr z, .use
            ld c, a                         ; swap ids and counts
            ld h, high(SRAM_PAGE)
            ld a, $C0
            add b
            ld e, a
            ld a, $C0
            add c
            ld l, a
            ld d, h
            call .xch
            ld a, $E0
            add b
            ld e, a
            ld a, $E0
            add c
            ld l, a
            call .xch
            jp .scr
.xch:       ld a, [de]
            push af
            ld a, [hl]
            ld [de], a
            pop af
            ld [hl], a
            ret
.trash2:    ld a, b                         ; (the trash first: the second item goes)
            ld [m_isel2], a
.trash:     ld a, [m_isel2]                 ; discard the first choice (not key items $9A-$A3,
            cp I_TRASH                      ;   the Toad / Mini spells $F6 / $F7)
            jr z, .err
            ld l, a
            add $C0
            ld l, a
            ld h, high(SRAM_PAGE)
            ld a, [hl]
            cp $F6
            jr z, .err
            cp $F7
            jr z, .err
            cp $9A
            jr c, .del
            cp $A4
            jr c, .err
.del:       xor a
            ld [hl], a
            ld a, l
            add $20
            ld l, a
            xor a
            ld [hl], a
            jp .scr
.err:       call m_sfx_err
            jp .lp
.use:       call i_use
            jp .scr
.up:        ld a, [m_icur]
            and a
            jr z, .lp2
            dec a
            jr .m
.dn:        ld a, [m_icur]
            cp I_TRASH
            jr z, .lp2
            inc a
.m:         ld [m_icur], a
            call m_sfx_move
            ld hl, m_top                    ; keep the cursor in the 13 rows shown
            ld a, [m_icur]
            cp [hl]
            jr nc, .m1
            ld [hl], a
            jp .scr
.m1:        sub [hl]
            cp 13
            jp c, .lp
            ld a, [hl]
            inc a
            ld [hl], a
            jp .scr
.lp2:       jp .lp
; (the first choice is kept apart from m_isel, which the loop clears)
m_isel2 = m_isel + 1

; the item screen: "Item" (0, 0) 20 x 3, the list (0, 3) 20 x 15 (13 rows from m_top)
i_draw:     call m_clear
            call m_sprclr
            ld de, $0000
            ld bc, $0314
            call m_win
            ld a, $35                       ; "Item" (t8200 $35)
            call m_t82
            ld de, $0101
            ld a, 10
            call m_putsn
            ld de, $0300
            ld bc, $0F14
            call m_win
            ld a, [m_top]
            ld [m_row], a
            ld d, 4
.r:         push de
            ld a, [m_row]
            cp I_TRASH
            jr z, .t
            jr nc, .n
            add $C0
            ld l, a
            ld h, high(SRAM_PAGE)
            ld a, [hl]
            and a
            jr z, .n
            ld e, a                         ; its name (names8800 = id)
            ld d, 0
            call m_n88
            pop de
            push de
            ld e, 2
            ld a, 12
            call m_putsn
            pop de
            push de
            ld e, 15
            ld a, ':'
            call m_putc
            inc e
            ld a, [m_row]
            add $E0
            ld l, a
            ld h, high(SRAM_PAGE)
            ld l, [hl]
            ld h, 0
            ld b, 2
            call m_num
            jr .n
.t:         pop de
            push de
            ld e, 2
            ld hl, m_trash
            call m_puts0
.n:         pop de
            ld a, [m_row]
            inc a
            ld [m_row], a
            inc d
            ld a, d
            cp 17
            jr nz, .r
            jp m_show

; names8800 entry DE -> M_STR
m_n88:      ld hl, T_NAMES8800
            add hl, de
            add hl, de
            add hl, de
            ld de, m_tmp
            ld bc, 3
            push hl
            pop hl
            push hl
            ld a, B_TEXT
            call far_copy
            pop hl
            ld a, [m_tmp + 1]
            ld l, a
            ld a, [m_tmp + 2]
            ld h, a
            ld de, M_STR
            ld bc, 24
            ld a, [m_tmp]
            jp far_copy

; ---- use item [m_icur] (3D/A033)
i_use:      ld a, [m_icur]
            ld [m_islot], a
            add $E0
            ld l, a
            ld h, high(SRAM_PAGE)
            ld a, [hl]                      ; none left
            and a
            jp z, m_sfx_err
            ld a, l
            sub $20
            ld l, a
            ld a, [hl]
            ld [m_iid], a
            cp $C8
            jp nc, i_teach                  ; a spell: who will hold it
            cp $A6                          ; Potion .. Antidote ($A6-$B0) are used; the
            jr c, .cant                     ;   Midgard Bread ($A4) and Otter's Head ($B0)
            cp $B0                          ;   (minimap, warp: later)
            jr nc, .cant
            sub $A6                         ; the question (t8200 $5B + n)
            add $5B
.again:     push af
            call m_party2
            pop af
            push af
            call m_msg
            call m_show
            call m_target
            pop bc
            ret c
            push bc
            call i_effect
            pop bc
            jr c, .bad
            ld a, [m_islot]                 ; one used (3D/A33C)
            add $E0
            ld l, a
            ld h, high(SRAM_PAGE)
            dec [hl]
            ret nz
            ld a, l
            sub $20
            ld l, a
            ld [hl], 0
            ret
.bad:       call m_sfx_err
            ld a, b
            jr .again
.cant:      ld a, $5A                       ; "It can't be used."
            call m_msg
            call m_show
            jp m_waitkey

; the effect of item [m_iid] on member [m_who]: C = no effect (3D/A097-A15A)
i_effect:   ld a, [m_who]
            call m_choff
            ld [m_x7f], a
            add 2
            ld l, a
            ld h, high(SRAM_PAGE + $100)    ; HL = status ($6102)
            ld a, [m_iid]
            cp $A6                          ; Potion: power 30
            ld b, 30
            jr z, .heal
            cp $A7                          ; Hi-Potion: 120
            ld b, 120
            jr z, .heal
            cp $A8                          ; Elixir: HP and MP to max
            jr z, .elix
            cp $A9                          ; Phoenix Down: dead -> 1 HP
            jr z, .fenix
            ld c, $40                       ; Soft, Maiden's Kiss, Echo Herbs: a status off
            cp $AA
            jr z, .st
            ld c, $20
            cp $AB
            jr z, .st
            ld c, $10
            cp $AC
            jr z, .st
            cp $AD                          ; Lucky Mallet: mini on / off
            jr nz, .eye
            ld a, [hl]
            xor $08
            ld [hl], a
            and a
            ret
.eye:       ld c, $04                       ; Eye Drops, else Antidote
            cp $AE
            jr z, .st
            ld c, $02
.st:        ld a, [hl]
            and c
            scf
            ret z
            ld a, c
            cpl
            and [hl]
            ld [hl], a
            and a
            ret
.heal:      ld a, [hl]
            cp $40
            ccf
            ret c                           ; dead or stone
            ld a, b
            ld [m_pow], a
            ld a, 1
            ld [m_tgts], a
            ld a, 3
            ld [m_mult], a
            jp m_heal
.elix:      ld a, [hl]
            cp $40
            ccf
            ret c
            call m_hpmax
            jp m_mpmax
.fenix:     bit 7, [hl]
            scf
            ret z
            res 7, [hl]
            ld a, l
            add $0A                         ; HP +1 ($610C)
            ld l, a
            inc [hl]
            ret nz
            inc l
            inc [hl]
            and a
            ret

; ---- FF3's healing (3D/A48A): power P = base + (random / 2 x base) / 256, x multiplier /
; targets, added to HP up to max ([m_tgts] 1: member [m_x7f], else all four)
m_heal:     %FAR B_FIELD, f_rnd_m
            ld a, [m_rnd]
            srl a
            ld l, a
            ld h, 0
            ld a, [m_pow]
            ld e, a
            ld d, 0
            call m_mul16                    ; HL = rnd/2 x base
            ld a, [m_pow]
            add h
            ld l, a
            ld a, 0
            adc 0
            ld h, a                         ; P
            ld a, [m_mult]
            ld e, l
            ld d, h
            ld l, a
            call m_mul16                    ; HL = P x mult (fits 16 bits: P < 512, mult small)
            ld a, [m_tgts]
            ld c, a
            call m_div                      ; HL / C
            ld a, l
            ld [m_amt], a
            ld a, h
            ld [m_amt + 1], a
            ld a, [m_tgts]
            cp 1
            jr z, m_addhp
            xor a
.a:         ld [m_x7f], a
            call m_addhp
            ld a, [m_x7f]
            add $40
            jr nz, .a
            and a
            ret
; FF3's restore hp (3D/A429): [m_amt] to member [m_x7f] (not dead / stone: C), capped at max
m_addhp:    ld a, [m_x7f]
            add 2
            ld l, a
            ld h, high(SRAM_PAGE + $100)
            ld a, [hl]
            cp $40
            ccf
            ret c
            ld a, [m_x7f]
            add $0C
            ld l, a
            ld a, [m_amt]
            add [hl]
            ld [hl+], a
            ld c, a
            ld a, [m_amt + 1]
            adc [hl]
            ld [hl+], a
            ld b, a
            ld a, [hl+]
            ld e, a
            ld d, [hl]                      ; max
            ld a, d
            cp b
            jr c, m_hpmax
            jr nz, .ok
            ld a, e
            cp c
            jr c, m_hpmax
.ok:        and a
            ret
m_hpmax:    ld a, [m_x7f]
            add $0E
            ld l, a
            ld h, high(SRAM_PAGE + $100)
            ld a, [hl+]
            ld b, [hl]
            dec l
            dec l
            ld [hl], b
            dec l
            ld [hl], a
            and a
            ret
; FF3's restore mp to max (3D/A418): each level's current = max
m_mpmax:    ld a, [m_x7f]
            add $30
            ld l, a
            ld h, high(SRAM_PAGE + $100)
            ld b, 8
.m:         inc l
            ld a, [hl-]
            ld [hl+], a
            inc l
            dec b
            jr nz, .m
            and a
            ret
; HL = HL / C (C > 0)
m_div:      ld b, 16
            xor a
.d:         add hl, hl
            rla
            cp c
            jr c, .n
            sub c
            inc l
.n:         dec b
            jr nz, .d
            ret

; ---- a spell item: who will hold it (3D/A15F: the level's three places, none twice)
i_teach:    ld a, $73                       ; "Who will hold this magic?"
.q:         push af
            call m_party2
            pop af
            call m_msg
            call m_show
            call m_target
            ret c
            ld a, [m_who]
            call m_choff
            ld [m_x7f], a
            call sp_buf                     ; the spells known -> m_spl (24)
            ld a, [m_iid]
            sub $C8
            ld c, a
            ld hl, sp_ptr
            call m_hla
            ld e, [hl]                      ; the level's first place
            ld d, 0
            ld hl, m_spl
            add hl, de
            ld a, [m_iid]
            ld b, 3
.h:         cp [hl]
            jr z, .has
            inc hl
            dec b
            jr nz, .h
            dec hl                          ; 3D/A1B6: the first empty of the three, or the
            dec hl                          ;   third
            dec hl
            ld a, [hl]
            and a
            jr z, .put
            inc hl
            ld a, [hl]
            and a
            jr z, .put
            inc hl
            ld a, [hl]
            and a
            jr z, .put
            ld a, $74                       ; "Can't hold any more."
            jr .msg
.has:       ld a, $75                       ; "Already holds this magic."
.msg:       push af
            call m_msg
            call m_show
            call m_waitkey
            pop af
            ld a, $73
            jr .q
.put:       ld a, [m_iid]
            ld [hl], a
            call sp_save
            ld a, [m_islot]                 ; one fewer
            add $E0
            ld l, a
            ld h, high(SRAM_PAGE)
            dec [hl]
            ret nz
            ld a, l
            sub $20
            ld l, a
            ld [hl], 0
            ret
; FF3's init spell list buffer (3D/A2B4): member [m_x7f]'s known spells ($6207-$620E bits) ->
; m_spl (24: three per level, by sp_ptr)
sp_buf:     ld hl, m_spl
            ld b, 24
            xor a
.z:         ld [hl+], a
            dec b
            jr nz, .z
            ld c, 0
.s:         ld hl, sp_lvl
            call m_hla
            ld a, [m_x7f]
            add [hl]
            add 7
            ld l, a
            ld h, high(SRAM_PAGE + $200)
            ld b, [hl]
            ld hl, sp_mask
            call m_hla
            ld a, [hl]
            and b
            jr z, .n
            ld hl, sp_ptr                   ; 3D/A2DF: the first empty of its three places
            call m_hla
            ld e, [hl]
            ld d, 0
            ld hl, m_spl
            add hl, de
            ld a, [hl]
            and a
            jr z, .p
            inc hl
            ld a, [hl]
            and a
            jr z, .p
            inc hl
.p:         ld a, c
            add $C8
            ld [hl], a
.n:         inc c
            ld a, c
            cp 56
            jr nz, .s
            ret
; FF3's update spell list (3D/A1C9): m_spl -> the bits ($6207-$620E of member [m_x7f])
sp_save:    ld a, [m_x7f]
            add 7
            ld l, a
            ld h, high(SRAM_PAGE + $200)
            ld b, 8
            xor a
.z:         ld [hl+], a
            dec b
            jr nz, .z
            ld de, m_spl
            ld b, 24
.s:         ld a, [de]
            inc de
            and a
            jr z, .n
            sub $C8
            ld c, a
            ld hl, sp_lvl
            call m_hla
            ld a, [m_x7f]
            add [hl]
            add 7
            push af
            ld hl, sp_mask
            call m_hla
            ld a, [hl]
            pop hl
            ld l, h
            ld h, high(SRAM_PAGE + $200)
            or [hl]
            ld [hl], a
.n:         dec b
            jr nz, .s
            ret
; HL += C
m_hla:      ld a, l
            add c
            ld l, a
            ret nc
            inc h
            ret

; ---- the party for a target (0, 0) 20 x 13: per member 3 rows: name / Lv (or ailment), HP,
; MP (current, 8 levels)
m_party2:   call m_clear
            call m_sprclr
            ld de, $0000
            ld bc, $0D14
            call m_win
            ld c, 0
.m:         push bc
            ld a, c
            add a
            add c
            inc a
            ld d, a
            ld e, 4
            ld a, c
            call m_name
            ld e, 12
            ld a, c
            call m_stword
            jr nz, .s
            ld hl, m_lv
            call m_puts0
            pop bc
            push bc
            ld a, c
            call m_choff
            inc a
            call m_sp1
            inc a
            ld l, a
            ld h, 0
            ld e, 16
            ld b, 2
            call m_num
.s:         inc d
            ld e, 4
            ld hl, m_hp
            call m_puts0
            inc e
            pop bc
            push bc
            ld a, c
            call m_hpline
            inc d
            ld e, 4
            pop bc
            push bc
            ld a, c
            call m_choff
            add $30
            ld [m_tmpc], a
            ld b, 8
.mp:        push bc
            ld a, [m_tmpc]
            call m_sp1
            ld l, a
            ld h, 0
            ld b, 1
            call m_num
            ld a, [m_tmpc]
            add 2
            ld [m_tmpc], a
            pop bc
            dec b
            jr z, .mx
            ld a, '/'
            call m_putc
            inc e
            jr .mp
.mx:        pop bc
            push bc
            ld a, c
            add a
            add c
            inc a
            add a
            add a
            add a
            add 16
            ld d, a
            ld e, 16
            call m_pictxy
            pop bc
            inc c
            ld a, c
            cp 4
            jp nz, .m
            ret
; choose a member in m_party2 (the hand at row 2 + 3 i): C = cancelled
m_target:   ld a, [m_who]
            and 3
            ld [m_who], a
.lp:        ld a, [m_who]
            ld b, a
            add a
            add b
            add 2
            ld b, a
            ld c, 1
            call m_hand2
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
            call m_hand2off
            and a
            ret
.x:         call m_sfx_ok
            call m_hand2off
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

; ==== 2 Equip (FF3's 3C/9BB5): a slot with something: it comes off (3C/9D9B); an empty slot:
; something from the pack (3C/9C3C); "Remove Equipment": everything off
E_SLOTS:    db 3, 5, 0, 1, 2                ; our rows: right hand, left hand, head, body, arms
E_LABEL:    db $E0, $E1, $DD, $DE, $DF      ; their empty names (t8200)
m_equip:    call m_member
            ret c
            xor a
            ld [m_ecur], a
.scr:       ld a, [m_who]
            ld c, a
            %FAR B_BSCR, bs_fequip          ; (FF3's battle values for Attack / Defense)
            call e_draw
.lp:        ld a, [m_ecur]
            add 4
            ld b, a
            ld c, 1
            call m_hand
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
            ld a, [m_ecur]
            cp 5
            jr z, .all
            call e_slotx                    ; L = the slot's page offset
            ld a, [hl]
            and a
            jr z, .pick
            call e_remove                   ; something there: off
            jr .scr
.pick:      call e_pick
            jr .scr
.all:       call e_all
            jr .scr
.x:         ret
.up:        ld a, [m_ecur]
            dec a
            cp $FF
            jr nz, .m
            ld a, 5
            jr .m
.dn:        ld a, [m_ecur]
            inc a
            cp 6
            jr c, .m
            xor a
.m:         ld [m_ecur], a
            call m_sfx_move
            jr .lp

; HL = $6200 + member + slot of row [m_ecur]; [m_eslot] = the slot
e_slotx:    ld a, [m_ecur]
            ld hl, E_SLOTS
            add l
            ld l, a
            jr nc, .s
            inc h
.s:         ld a, [hl]
            ld [m_eslot], a
            ld b, a
            call m_who_off
            add b
            ld l, a
            ld h, high(SRAM_PAGE + $200)
            ret

; the screen: the member's window (0, 0) 20 x 11: name, Attack / Defense, the five slots, Remove
; Equipment; the pack's fitting items below when choosing
e_draw:     call m_clear
            call m_sprclr
            ld de, $0000
            ld bc, $0B14
            call m_win
            ld a, [m_who]
            ld de, $0101
            call m_name
            call m_who_off
            call m_sp1
            add $E2
            call m_t82
            ld de, $0108
            ld a, 11
            call m_putsn
            ld de, $0201                    ; Attack ($6123 + $6128), Defense ($612D)
            ld a, 5
            call m_label
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
.a1:        ld de, $020D
            ld b, 3
            call m_num
            ld de, $0301
            ld a, 7
            call m_label
            call m_toad
            ld hl, 1
            jr nz, .d1
            call m_who_off
            add $2D
            call m_sp1
            ld l, a
            ld h, 0
.d1:        ld de, $030D
            ld b, 3
            call m_num
            xor a
.s:         ld [m_row], a                   ; the slots (rows 4-8)
            ld b, a
            ld a, [m_ecur]
            push af
            ld a, b
            ld [m_ecur], a
            call e_slotx
            pop af
            ld [m_ecur], a
            ld a, [m_row]
            add 4
            ld d, a
            ld e, 2
            ld a, [hl]
            and a
            jr nz, .it
            push de
            ld a, [m_row]
            ld hl, E_LABEL
            add l
            ld l, a
            jr nc, .l2
            inc h
.l2:        ld a, [hl]
            call m_t82
            pop de
            ld a, 14
            call m_putsn
            jr .nx
.it:        push hl
            push de
            ld e, a
            ld d, 0
            call m_n88
            pop de
            ld a, 13
            call m_putsn
            pop hl
            ld a, [m_eslot]                 ; arrows: their number
            cp 3
            jr c, .nx
            inc l
            ld a, [hl]
            cp 2
            jr c, .nx
            ld l, a
            ld h, 0
            ld e, 15
            ld a, ':'
            call m_putc
            inc e
            ld b, 2
            call m_num
.nx:        ld a, [m_row]
            inc a
            cp 5
            jr nz, .s
            ld de, $0902
            ld hl, m_remove
            call m_puts0
            jp m_show

; ---- off: the slot's item (and its count) into the pack (3C/9D68): C = no room
e_remove:   call e_off
            push af
            ld a, [m_who]
            ld c, a
            %FAR B_BSCR, bs_fequip
            call e_draw
            pop af
            ld a, $6B                       ; "Your inventory is full ..."
            jr c, .m
            ld a, $6E                       ; "Removed the equipment."
.m:         call m_msg
            call m_show
            jp m_waitkey
e_off:      call e_slotx
            ld a, [hl]
            and a
            ret z
            ld [m_iid], a
            ld c, 1
            ld a, [m_eslot]
            cp 3
            jr c, .q
            inc l
            ld c, [hl]
            dec l
.q:         push hl
            ld a, [m_iid]
            ld b, a
            call m_invadd
            pop hl
            ret c
            ld [hl], 0                      ; 3C/9E0F
            ld a, [m_eslot]
            cp 3
            jr c, .u
            inc l
            ld [hl], 0
.u:         and a
            ret
; FF3's add item to inventory (3C/9362): B id, C count: its stack (up to 99) or the first
; empty place; C = full
m_invadd:    ld hl, SRAM_PAGE + $C0
            ld e, 32
.f:         ld a, [hl]
            cp b
            jr z, .put
            inc l
            dec e
            jr nz, .f
            ld hl, SRAM_PAGE + $C0
            ld e, 32
.e:         ld a, [hl]
            and a
            jr z, .put
            inc l
            dec e
            jr nz, .e
            scf
            ret
.put:       ld [hl], b
            ld a, l
            add $20
            ld l, a
            ld a, [hl]
            add c
            cp 99
            jr c, .s
            ld a, 99
.s:         ld [hl], a
            and a
            ret
; FF3's remove item from inventory (3C/90B9): B id, C count
m_invsub:    ld hl, SRAM_PAGE + $C0
            ld e, 32
.f:         ld a, [hl]
            cp b
            jr z, .s
            inc l
            dec e
            jr nz, .f
            ret
.s:         ld a, l
            add $20
            ld l, a
            ld a, [hl]
            sub c
            ld [hl], a
            ret nz
            ld a, l
            sub $20
            ld l, a
            ld [hl], 0
            ret

; ---- Remove Equipment (3C/9DA2): slots 5, 3, 2, 1, 0
e_all:      xor a
            ld [m_eany], a
            ld a, [m_ecur]
            push af
            ld b, 5
.s:         push bc
            ld a, b                         ; slot -> our row
            ld hl, E_SLOTS
            ld c, 0
.f:         cp [hl]
            jr z, .g
            inc hl
            inc c
            jr .f
.g:         ld a, c
            ld [m_ecur], a
            call e_slotx
            ld a, [hl]
            and a
            jr z, .n
            call e_off
            jr c, .full
            ld a, 1
            ld [m_eany], a
.n:         pop bc
            dec b
            ld a, b
            cp 4
            jr nz, .n2
            dec b
.n2:        bit 7, b
            jr z, .s
            pop af
            ld [m_ecur], a
            ld a, [m_eany]
            and a
            ret z
            ld a, $6E
            jr .m
.full:      pop bc
            pop af
            ld [m_ecur], a
            ld a, $6B
.m:         call m_msg
            call m_show
            jp m_waitkey

; ---- choose from the pack for the empty slot (the pack's fitting items, 5 rows below)
e_pick:     call e_list                     ; -> m_elist (inventory places), m_en
            ld a, [m_en]
            and a
            jp z, m_sfx_err
            xor a
            ld [m_icur], a
            ld [m_top], a
.scr:       call e_listdraw
.lp:        ld a, [m_icur]
            ld hl, m_top
            sub [hl]
            add 12
            ld b, a
            ld c, 1
            call m_hand2
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
            call m_hand2off
            ld a, [m_icur]
            ld hl, m_elist
            add l
            ld l, a
            jr nc, .g
            inc h
.g:         ld a, [hl]                      ; the pack's place
            call e_equip
            ret nc
            ld a, $6F                       ; "Can't equip."
            call m_msg
            call m_show
            call m_waitkey
            ret
.x:         call m_hand2off
            ret
.up:        ld a, [m_icur]
            and a
            jr z, .lp
            dec a
            jr .m
.dn:        ld a, [m_icur]
            inc a
            ld hl, m_en
            cp [hl]
            jr nc, .lp
.m:         ld [m_icur], a
            call m_sfx_move
            ld hl, m_top
            ld a, [m_icur]
            cp [hl]
            jr nc, .m1
            ld [hl], a
            jr .scr
.m1:        sub [hl]
            cp 5
            jr c, .lp
            ld a, [hl]
            inc a
            ld [hl], a
            jr .scr
; the pack's places whose items fit slot [m_eslot]: hands $00-$61, head $62-$71, body $72-$8A,
; arms $8B-$97 (3C/9C72)
e_list:     call e_slotx
            ld a, [m_eslot]
            ld bc, $6200                    ; B low, C high (exclusive)
            cp 3
            jr nc, .r
            ld bc, $7262
            and a
            jr z, .r
            ld bc, $8B72
            dec a
            jr z, .r
            ld bc, $988B
.r:         ld a, c
            ld [m_elo], a
            ld a, b
            ld [m_ehi], a
            xor a
            ld [m_en], a
            ld c, 0
.f:         ld a, c
            add $C0
            ld l, a
            ld h, high(SRAM_PAGE)
            ld a, [hl]
            and a
            jr z, .n
            ld hl, m_elo
            cp [hl]
            jr c, .n
            inc hl
            cp [hl]
            jr nc, .n
            ld a, [m_en]
            ld hl, m_elist
            add l
            ld l, a
            jr nc, .p
            inc h
.p:         ld [hl], c
            ld hl, m_en
            inc [hl]
.n:         inc c
            ld a, c
            cp 32
            jr nz, .f
            ret
; the list window (0, 11) 20 x 7: 5 rows from m_top
e_listdraw: ld de, $0B00
            ld bc, $0714
            call m_win
            ld a, [m_top]
            ld [m_row], a
            ld d, 12
.r:         ld a, [m_row]
            ld hl, m_en
            cp [hl]
            jr nc, .x
            push de
            ld hl, m_elist
            add l
            ld l, a
            jr nc, .g
            inc h
.g:         ld a, [hl]
            push af
            add $C0
            ld l, a
            ld h, high(SRAM_PAGE)
            ld e, [hl]
            ld d, 0
            call m_n88
            pop af
            pop de
            push de
            push af
            ld e, 2
            ld a, 12
            call m_putsn
            pop af
            pop de
            push de
            add $E0
            ld l, a
            ld h, high(SRAM_PAGE)
            ld l, [hl]
            ld h, 0
            ld e, 15
            ld a, ':'
            call m_putc
            inc e
            ld b, 2
            call m_num
            pop de
            ld a, [m_row]
            inc a
            ld [m_row], a
            inc d
            ld a, d
            cp 17
            jr nz, .r
.x:         jp m_show
; equip the pack's place A in slot [m_eslot] (3C/9C3C): C = can't
e_equip:    ld [m_islot], a
            add $C0
            ld l, a
            ld h, high(SRAM_PAGE)
            ld a, [hl]
            ld [m_iid], a
            call m_canequip
            scf
            ret z
            ld a, [m_eslot]
            cp 3
            jr c, .arm
            ld a, [m_eslot]                 ; a hand: the other hand's item (slot 3 <-> 5)
            xor 6
            ld b, a
            call m_who_off
            add b
            ld l, a
            ld h, high(SRAM_PAGE + $200)
            ld a, [hl]
            and a
            jr z, .ok                       ; (3C/9CDF: the pair allowed? 3C/9D4B)
            call e_wtype
            ld b, a
            ld a, [m_iid]
            call e_wtype
            add a
            add a
            or b
            ld hl, wp_comb
            add l
            ld l, a
            jr nc, .w2
            inc h
.w2:        ld a, [hl]
            and a
            scf
            ret nz
.ok:        ld a, [m_islot]                 ; arrows: up to 20 of them; else 1
            add $E0
            ld l, a
            ld h, high(SRAM_PAGE)
            ld a, [hl]
            cp 21
            jr c, .q
            ld a, 20
.q:         ld c, a
            ld a, [m_iid]
            cp $4F
            jr c, .one
            cp $57
            jr c, .put
.one:       ld c, 1
            jr .put
.arm:       ld c, 1
.put:       call e_slotx
            ld a, [m_iid]
            ld [hl], a
            ld a, [m_eslot]
            cp 3
            jr c, .r
            inc l
            ld [hl], c
.r:         ld a, [m_iid]
            ld b, a
            call m_invsub
            and a
            ret
; FF3's weapon type (3C/9D2F): 0 other, 1 bow, 2 arrows, 3 harp
e_wtype:    cp $46
            jr c, .o
            cp $4A
            jr c, .h
            cp $4F
            jr c, .b
            cp $57
            jr c, .a
.o:         xor a
            ret
.h:         ld a, 3
            ret
.b:         ld a, 1
            ret
.a:         ld a, 2
            ret
; NZ when member [m_who]'s job may equip item [m_iid] (35/B8FD: 30/9400 + 8 id, byte 7 & $7F
; -> the jobs allowed, 00/8900 + 3 n)
m_canequip: ld a, [m_iid]
            cp $C8                          ; (a spell: 30/9400 + 8 (id - $30), 34/8053)
            jr c, .i
            sub $30
.i:         ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, $9400 + 7 - $4000
            add hl, de
            ld a, B_BDAT
            call far_byte
            and $7F
            ld l, a
            ld h, 0
            ld d, h
            ld e, l
            add hl, hl
            add hl, de
            ld de, eq_types
            add hl, de
            ld de, m_tmp
            ld bc, 3
            ld a, B_BSCR
            call far_copy
            call m_who_off                  ; the job's bit (job 0: bit 0 of the third byte)
            call m_sp1
            ld c, a
            ld hl, m_tmp + 2
            ld a, c
            cp 16
            jr c, .b1
            sub 16
            ld hl, m_tmp
            jr .b
.b1:        cp 8
            jr c, .b
            sub 8
            dec hl
.b:         ld b, a
            ld a, 1
            inc b
.s:         dec b
            jr z, .t
            add a
            jr .s
.t:         and [hl]
            ret

; ==== 1 Magic (FF3's 3C/9761): the member's spells, four levels a page (a level: "Ln MP x/y",
; its three spells); A on a spell: Use / Item (FF3's options; Swap not offered)
m_magic:    call m_member
            ret c
            call m_who_off
            ld [m_x7f], a
            ld [m_caster], a
            add 2
            call m_sp1
            and $C0                         ; dead / stone: no (3D/A5E5)
            jp nz, m_sfx_err
            call sp_buf
            xor a
            ld [m_mcur], a
.scr:       call g_draw
.lp:        ld a, [m_mcur]                  ; the hand: level row + 1 + k
            call g_rowof
            ld b, a
            ld c, 3
            call m_hand
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
            ld a, [m_mcur]
            ld hl, m_spl
            add l
            ld l, a
            jr nc, .g
            inc h
.g:         ld a, [hl]
            and a
            jr z, .err
            ld [m_iid], a
            call m_sfx_ok
            call g_opts                     ; Use / Item: C = cancelled, A = 0 / 1
            jr c, .scr
            and a
            jr nz, .item
            call g_use
            jr .scr
.item:      ld a, [m_iid]                   ; 3C/9897: into the pack
            ld b, a
            ld c, 1
            call m_invadd
            ld a, $6B
            jr c, .msg
            ld a, [m_mcur]
            ld hl, m_spl
            add l
            ld l, a
            jr nc, .i2
            inc h
.i2:        ld [hl], 0
            call sp_save
            ld a, $6E
.msg:       call m_msg
            call m_show
            call m_waitkey
            jr .scr
.err:       call m_sfx_err
            jr .lp
.x:         call m_sfx_ok
            jp sp_save
.up:        ld a, [m_mcur]
            and a
            jr z, .lp
            dec a
            jr .m
.dn:        ld a, [m_mcur]
            cp 23
            jr z, .lp
            inc a
.m:         ld b, a                         ; another page: redraw
            ld a, [m_mcur]
            call g_page
            ld c, a
            ld a, b
            ld [m_mcur], a
            call g_page
            cp c
            push af
            call m_sfx_move
            pop af
            jp nz, .scr
            jp .lp
; A = the page (0 / 1) of slot A; g_rowof: A = the BG row of slot A
g_page:     cp 12
            ld a, 0
            ret c
            inc a
            ret
g_rowof:    cp 12
            jr c, .p
            sub 12
.p:         ld c, 0
.d:         cp 3
            jr c, .r
            sub 3
            inc c
            jr .d
.r:         ld b, a                         ; 1 + 4 level + 1 + k
            ld a, c
            add a
            add a
            add 2
            add b
            ret
; the page of slot [m_mcur]: four levels
g_draw:     call m_clear
            call m_sprclr
            ld de, $0000
            ld bc, $1214
            call m_win
            ld a, [m_mcur]
            call g_page
            add a
            add a
            ld [m_lvl], a                   ; the first level
            ld d, 1
.l:         ld e, 1
            ld a, 'L'
            call m_putc
            inc e
            ld a, [m_lvl]
            add '1'
            call m_putc
            ld e, 5
            ld hl, m_mp
            call m_puts0
            inc e
            ld a, [m_lvl]                   ; MP current / max ($6130 + 2 l)
            add a
            ld b, a
            ld a, [m_x7f]
            add $30
            add b
            push af
            call m_sp1
            ld l, a
            ld h, 0
            ld b, 2
            call m_num
            ld a, '/'
            call m_putc
            inc e
            pop af
            inc a
            call m_sp1
            ld l, a
            ld h, 0
            ld b, 2
            call m_num
            ld c, 0                         ; the three spells
.s:         inc d
            push bc
            push de
            ld a, [m_lvl]
            ld b, a
            add a
            add b
            add c
            ld hl, m_spl
            add l
            ld l, a
            jr nc, .g
            inc h
.g:         ld a, [hl]
            and a
            jr z, .e
            ld e, a
            ld d, 0
            call m_n88
            pop de
            push de
            ld e, 4
            ld a, 14
            call m_putsn
.e:         pop de
            pop bc
            inc c
            ld a, c
            cp 3
            jr nz, .s
            inc d
            ld a, [m_lvl]
            inc a
            ld [m_lvl], a
            and 3
            jr nz, .l
            jp m_show
; Use / Item in a small window (11, 14) 9 x 4 (FF3's text $36's words): A = 0 / 1, C = B
g_opts:     ld de, $0E0B
            ld bc, $0409
            call m_win
            ld hl, m_s_use
            ld de, $0F0D
            call m_puts0
            ld hl, m_s_item
            ld de, $100D
            call m_puts0
            ld a, 1
            ld [m_dirty], a
            xor a
            ld [m_yn], a
.lp:        ld a, [m_yn]
            add 15
            ld b, a
            ld c, 13
            call m_hand2
            call m_frame
            ldh a, [pad_new]
            and $C0
            jr nz, .t
            ldh a, [pad_new]
            bit 1, a
            jr nz, .x
            and PAD_A
            jr z, .lp
            call m_sfx_ok
            call m_hand2off
            ld a, [m_yn]
            and a
            ret
.t:         ld a, [m_yn]
            xor 1
            ld [m_yn], a
            call m_sfx_move
            jr .lp
.x:         call m_sfx_ok
            call m_hand2off
            scf
            ret

; ---- cast spell [m_iid] from slot [m_mcur] (3C/9812-3C/9AD0)
G_SPELLS:   db $CC, $5E, $D2, $5C, $D3, $66, $DA, $5F, $E0, $5C, $E1, $5E, $EE, $5C
            db $F6, $69, $F0, $63, $F7, $6A, $FC, $5C, $FD, $64, 0
g_use:      call m_canequip                 ; the job may cast it ($7200)
            jp z, m_sfx_err
            ld a, [m_iid]                   ; MP of its level
            sub $C8
            ld c, a
            ld hl, sp_lvl
            call m_hla
            ld a, [hl]
            add a
            ld b, a
            ld a, [m_caster]
            add $30
            add b
            ld [m_mpat], a
            call m_sp1
            and a
            jp z, m_sfx_err
            ld a, [m_iid]                   ; a field spell, with its question
            ld hl, G_SPELLS
.f:         ld b, a
            ld a, [hl+]
            and a
            jp z, m_sfx_err                 ; (Exit, Teleport, Sightro: later)
            cp b
            ld a, [hl+]
            jr z, .q
            ld a, b
            jr .f
.q:         ld [m_q], a
            ld a, [m_caster]                ; the caster: not dead, stone, toad or silenced
            add 2                           ;   (Toad: a toad may cast it)
            call m_sp1
            ld c, $F0
            ld b, a
            ld a, [m_iid]
            cp $F6
            jr nz, .c
            ld c, $D0
.c:         ld a, b
            and c
            jp nz, m_sfx_err
.ask:       call m_party2
            ld a, [m_q]
            call m_msg
            call m_show
            ld a, [m_iid]                   ; Arise and Esuna: one member; the rest: one or all
            cp $CC
            jr z, .one
            cp $D3
            jr z, .one
            call m_target_all
            jr .t
.one:       call m_target
            xor a
            ld [m_all], a
.t:         ret c
            ld a, [m_all]
            and a
            ld a, 1
            jr z, .n
            ld a, 4
.n:         ld [m_tgts], a
            ld a, [m_who]
            call m_choff
            ld [m_x7f], a
            ld a, [m_all]
            and a
            jr z, .e
            xor a
            ld [m_x7f], a
.e:         call g_effect
            jr c, .bad
            ld a, [m_mpat]                  ; 3C/9957: MP - 1
            ld l, a
            ld h, high(SRAM_PAGE + $100)
            dec [hl]
            ld a, [m_caster]
            ld [m_x7f], a
            ret
.bad:       call m_sfx_err
            jr .ask
; the effect (3C/99FF): C = nothing to do
g_effect:   ld a, [m_iid]
            cp $CC                          ; Arise: life, HP to max
            jr nz, .a
            ld c, $80
            call g_status
            ret c
            call m_hpmax
            ret
.a:         cp $D2                          ; Curaga: one: HP to max; all: power 220
            jr nz, .b
            call g_valid
            ret c
            ld a, [m_tgts]
            cp 1
            jp z, m_hpmax
            ld a, 220
            jr .heal
.b:         ld c, $7F                       ; Esuna
            cp $D3
            jr z, g_status
            ld c, $40                       ; Stona
            cp $DA
            jr z, g_status
            cp $E0                          ; Curada: 180
            ld b, 180
            jr z, .cure
            ld c, $80                       ; Raise
            cp $E1
            jr z, g_status
            cp $EE                          ; Cura: 125
            ld b, 125
            jr z, .cure
            ld c, $20                       ; Toad (toggle)
            cp $F6
            jr z, .tog
            ld c, $04                       ; Blindna
            cp $F0
            jr z, g_status
            ld c, $08                       ; Minimum (toggle)
            cp $F7
            jr z, .tog
            cp $FC                          ; Cure: 42
            ld b, 42
            jr z, .cure
            ld c, $02                       ; Poisona
            jr g_status
.cure:      push bc
            call g_valid
            pop bc
            ret c
            ld a, b
.heal:      ld [m_pow], a                   ; 3D/A466: x = job level / 32 + level / 16 +
            ld a, [m_caster]                ;   spirit / 16 + 1
            add $10
            call m_sp1
            swap a
            srl a
            and 7
            ld b, a
            ld a, [m_caster]
            inc a
            call m_sp1
            swap a
            and 15
            add b
            ld b, a
            ld a, [m_caster]
            add $1B
            call m_sp1
            swap a
            and 15
            scf
            adc b
            ld [m_mult], a
            jp m_heal
.tog:       ld a, [m_tgts]                  ; 3C/9AA5: toggle on [m_tgts] from [m_x7f]
            ld b, a
            ld a, [m_x7f]
.tl:        push af
            add 2
            ld l, a
            ld h, high(SRAM_PAGE + $100)
            ld a, [hl]
            xor c
            ld [hl], a
            pop af
            add $40
            dec b
            jr nz, .tl
            and a
            ret
; FF3's validate targets for cure spell (3C/9B7A): one: not dead / stone (C); all: count the
; others, [m_x7f] the last one standing
g_valid:    ld a, [m_tgts]
            cp 1
            jr nz, .all
            ld a, [m_x7f]
            add 2
            call m_sp1
            and $C0
            ret z
            scf
            ret
.all:       xor a
.l:         ld b, a
            add 2
            call m_sp1
            cp $40
            jr c, .ok
            ld hl, m_tgts
            dec [hl]
            jr .n
.ok:        ld a, b
            ld [m_x7f], a
.n:         ld a, b
            add $40
            jr nz, .l
            and a
            ret
; FF3's remove status (3D/A3C2): mask C; one: member [m_x7f] must have it; all: anyone
g_status:   ld a, [m_tgts]
            cp 1
            jr nz, .all
            ld a, [m_x7f]
.one:       add 2
            ld l, a
            ld h, high(SRAM_PAGE + $100)
            ld a, [hl]
            and c
            scf
            ret z
.rm:        bit 7, a                        ; (dead: HP 1)
            jr z, .r2
            push hl
            ld a, l
            add $0A
            ld l, a
            ld [hl], 1
            pop hl
.r2:        ld a, c
            cpl
            and [hl]
            ld [hl], a
            and a
            ret
.all:       ld hl, SRAM_PAGE + $102
            ld a, [hl]
            ld l, $42
            or [hl]
            ld l, $82
            or [hl]
            ld l, $C2
            or [hl]
            and c
            scf
            ret z
            xor a
.l:         push af
            add 2
            ld l, a
            ld h, high(SRAM_PAGE + $100)
            ld a, [hl]
            and c
            call nz, .rm
            pop af
            add $40
            jr nz, .l
            and a
            ret
; choose a member or all (the hand past the fourth: all four hands)
m_target_all:
            xor a
            ld [m_all], a
            ld a, [m_who]
            and 3
            ld [m_who], a
.lp:        call .hands
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
            call .off
            and a
            ret
.x:         call m_sfx_ok
            call .off
            scf
            ret
.up:        ld a, [m_all]
            and a
            jr z, .u1
            xor a
            ld [m_all], a
            ld a, 3
            ld [m_who], a
            jr .mv
.u1:        ld a, [m_who]
            and a
            jr nz, .u2
            ld a, 1
            ld [m_all], a
            jr .mv
.u2:        dec a
            ld [m_who], a
            jr .mv
.dn:        ld a, [m_all]
            and a
            jr z, .d1
            xor a
            ld [m_all], a
            ld [m_who], a
            jr .mv
.d1:        ld a, [m_who]
            cp 3
            jr nz, .d2
            ld a, 1
            ld [m_all], a
            jr .mv
.d2:        inc a
            ld [m_who], a
.mv:        call m_sfx_move
            jr .lp
.hands:     call .off
            ld a, [m_all]
            and a
            jr nz, .h4
            ld a, [m_who]
            ld b, a
            add a
            add b
            add 2
            ld b, a
            ld c, 1
            jp m_hand2
.h4:        ld de, .slots                   ; all four (OAM 0, 28, 32, 36)
            ld b, 2
.h:         push bc
            push de
            ld a, [de]
            ld l, a
            ld h, high(oam_buf)
            ld c, 1
            call m_hand.s
            pop de
            inc de
            pop bc
            ld a, b
            add 3
            ld b, a
            cp 14
            jr nz, .h
            ret
.slots:     db 0, 4 * 28, 4 * 32, 4 * 36
.off:       ld hl, oam_buf
            call hand16off
            ld hl, oam_buf + 4 * 28
            call hand16off
            ld hl, oam_buf + 4 * 32
            call hand16off
            ld hl, oam_buf + 4 * 36
            jp hand16off

; ==== 5 Job (FF3's 3C/962F): the jobs the crystals give (3F/F38A), FF3's CP cost (3D/AD85), its
; checks (3D/AE23) and change (3D/AB8F). Job data: 39/A000 (8 a job), level-ups 39/A1D6..,
; first MP 39/BB88 (B_BDAT3 = NES $38 / $39)
m_job:      ld a, [SRAM_PAGE + $21]         ; crystals (3D/A61B: none: no)
            and $1F
            jp z, m_sfx_err
            call m_member
            ret c
            call m_who_off
            ld [m_x7f], a
            add 2
            call m_sp1
            and $C0
            jp nz, m_sfx_err
            ld a, [SRAM_PAGE + $21]         ; the last job (3F/F38A)
            and $1F
            ld b, 0
            srl a
            jr nc, .k
            ld b, 5
            srl a
            jr nc, .k
            ld b, 9
            srl a
            jr nc, .k
            ld b, $10
            srl a
            jr nc, .k
            ld b, $13
            srl a
            jr nc, .k
            ld b, 21
.k:         ld a, b
            inc a
            ld [m_jn], a
            call j_costs
            xor a
            ld [m_icur], a
            ld [m_top], a
.scr:       call j_draw
.lp:        ld a, [m_icur]
            ld hl, m_top
            sub [hl]
            add 5
            ld b, a
            ld c, 1
            call m_hand
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
            ld a, [m_icur]
            ld [m_newj], a
            ld b, a
            ld a, [m_x7f]
            call m_sp1
            cp b
            jr z, .err
            call j_check                    ; A = message when not allowed
            jr nc, .no
            ld hl, m_s_chg                  ; "Change jobs? A..Yes B..No" (t8200 $70)
            call m_msghl
            call m_show
            call m_waitkey
            ldh a, [pad_new]
            and PAD_A
            jr z, .scr
            call j_change
            call m_regfx
.x:         call m_sfx_ok                   ; (3C/961C: the equipment update)
            ld a, [m_who]
            ld c, a
            %FAR B_BSCR, bs_fequip
            ret
.no:        call m_msg
            call m_show
            call m_waitkey
            jr .scr
.err:       call m_sfx_err
            jr .lp
.up:        ld a, [m_icur]
            and a
            jr z, .lp
            dec a
            jr .m
.dn:        ld a, [m_icur]
            inc a
            ld hl, m_jn
            cp [hl]
            jr nc, .lp
.m:         ld [m_icur], a
            call m_sfx_move
            ld hl, m_top
            ld a, [m_icur]
            cp [hl]
            jr nc, .m1
            ld [hl], a
            jp .scr
.m1:        sub [hl]
            cp 12
            jp c, .lp
            ld a, [hl]
            inc a
            ld [hl], a
            jp .scr
; the screen: (0, 0) 20 x 4 name, job, CP; (0, 4) 20 x 14 the jobs (12 rows) and their costs
j_draw:     call m_clear
            call m_sprclr
            ld de, $0000
            ld bc, $0414
            call m_win
            ld a, [m_who]
            ld de, $0101
            call m_name
            ld a, [m_x7f]
            call m_sp1
            add $E2
            call m_t82
            ld de, $0201
            ld a, 13
            call m_putsn
            ld hl, m_cp
            ld de, $010E
            call m_puts0
            ld a, [SRAM_PAGE + $1B]
            ld l, a
            ld h, 0
            ld e, 16
            ld b, 3
            call m_num
            ld de, $0400
            ld bc, $0E14
            call m_win
            ld a, [m_top]
            ld [m_row], a
            ld d, 5
.r:         ld a, [m_row]
            ld hl, m_jn
            cp [hl]
            jr nc, .x
            push de
            add $E2
            call m_t82
            pop de
            push de
            ld e, 2
            ld a, 13
            call m_putsn
            pop de
            push de
            ld a, [m_row]
            ld hl, m_jcost
            add l
            ld l, a
            jr nc, .c
            inc h
.c:         ld l, [hl]
            ld h, 0
            ld e, 16
            ld b, 3
            call m_num
            pop de
            ld a, [m_row]
            inc a
            ld [m_row], a
            inc d
            ld a, d
            cp 17
            jr nz, .r
.x:         jp m_show
; job j's 8 bytes -> HL (B_BDAT3 copy into m_jd + 8 k): j_load A = job, DE = buffer
j_load:     ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            ld bc, $6000
            add hl, bc
            ld bc, 8
            ld a, B_BDAT3
            jp far_copy
; FF3's cp needed for each job (3D/AD85): 4 x (|phys/mag difference| + |law/chaos difference|)
; minus the new job's level, at least 0
j_costs:    ld a, [m_x7f]
            call m_sp1
            ld de, m_jd + 8
            call j_load
            xor a
.j:         ld [m_newj], a
            ld de, m_jd
            call j_load
            ld a, [m_jd]
            swap a
            and 15
            ld b, a
            ld a, [m_jd + 8]
            swap a
            and 15
            sub b
            jr nc, .a1
            cpl
            inc a
.a1:        ld c, a
            ld a, [m_jd]
            and 15
            ld b, a
            ld a, [m_jd + 8]
            and 15
            sub b
            jr nc, .a2
            cpl
            inc a
.a2:        add c
            add a
            add a
            ld b, a
            ld a, [m_newj]                  ; - the job's level ($6210 + 2 j)
            add a
            ld c, a
            ld a, [m_x7f]
            add $10
            add c
            ld l, a
            ld h, high(SRAM_PAGE + $200)
            ld a, b
            sub [hl]
            jr nc, .s
            xor a
.s:         ld b, a
            ld a, [m_newj]
            ld hl, m_jcost
            add l
            ld l, a
            jr nc, .p
            inc h
.p:         ld [hl], b
            ld a, [m_newj]
            inc a
            cp 23
            jr nz, .j
            ret
; FF3's check (3D/AE23): C = allowed, else A = the message
j_check:    ld a, [m_newj]
            ld de, m_jd
            call j_load
            ld a, [m_x7f]                   ; level >= the job's minimum
            inc a
            call m_sp1
            ld hl, m_jd + 1
            cp [hl]
            ld a, $3A
            ccf
            ret nc
            ld a, [m_x7f]                   ; nothing equipped (slots 0-3, 5)
            ld l, a
            ld h, high(SRAM_PAGE + $200)
            ld a, [hl+]
            or [hl]
            inc l
            or [hl]
            inc l
            or [hl]
            inc l
            inc l
            or [hl]
            ld a, $71
            ret nz
            ld a, [m_newj]                  ; enough CP
            ld hl, m_jcost
            add l
            ld l, a
            jr nc, .c
            inc h
.c:         ld a, [SRAM_PAGE + $1B]
            cp [hl]
            ld a, $72
            ccf
            ret
; FF3's change job (3D/AB8F)
j_change:   ld a, [m_newj]
            ld hl, m_jcost
            add l
            ld l, a
            jr nc, .c
            inc h
.c:         ld a, [SRAM_PAGE + $1B]         ; CP - cost
            sub [hl]
            ld [SRAM_PAGE + $1B], a
            ld a, [m_x7f]                   ; the old job's level / exp saved
            ld l, a
            ld h, high(SRAM_PAGE + $100)
            ld a, [hl]
            add a
            ld b, a
            ld a, l
            add $10
            ld l, a
            ld a, [hl+]
            ld c, [hl]
            push af
            ld a, [m_x7f]
            add $10
            add b
            ld l, a
            inc h
            pop af
            ld [hl+], a
            ld [hl], c
            ld a, [m_x7f]                   ; the new job, its level / exp
            ld l, a
            dec h
            ld a, [m_newj]
            ld [hl], a
            add a
            ld b, a
            ld a, l
            add $10
            add b
            ld l, a
            inc h
            ld a, [hl+]
            ld c, [hl]
            dec h
            push af
            ld a, [m_x7f]
            add $10
            ld l, a
            pop af
            ld [hl+], a
            ld [hl], c
            ld a, [m_x7f]                   ; base stats from the job (bytes 2-6)
            add $12
            ld e, a
            ld d, high(SRAM_PAGE + $100)
            ld hl, m_jd + 2
            ld bc, 5
            call memcpy
            ld a, [m_x7f]                   ; status bit 0 (equipment to check)
            add 2
            ld l, a
            ld h, high(SRAM_PAGE + $100)
            set 0, [hl]
            ld a, [m_jd + 7]                ; max MP of each level: 39/BB88 + 8 index
            add a
            add a
            add a
            ld l, a
            ld h, 0
            ld bc, $7B88
            add hl, bc
            ld de, m_tmp8
            ld bc, 8
            ld a, B_BDAT3
            call far_copy
            ld a, [m_x7f]
            add $31
            ld l, a
            ld h, high(SRAM_PAGE + $100)
            ld de, m_tmp8
            ld b, 8
.mp:        ld a, [de]
            inc de
            ld [hl+], a
            inc l
            dec b
            jr nz, .mp
            ld a, [m_x7f]                   ; the level-ups again with the new job's table
            inc a
            call m_sp1
            ld [m_lvl], a
            and a
            jr z, .done
            ld a, [m_newj]                  ; its table (3D/AD59: 39/xxxx -> B_BDAT3 - $2000)
            add a
            ld hl, job_prog
            add l
            ld l, a
            jr nc, .t
            inc h
.t:         ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld bc, -$2000
            add hl, bc
            ld a, l
            ld [m_jp], a
            ld a, h
            ld [m_jp + 1], a
.lv:        ld a, [m_lvl]                   ; (level - 1) x 2
            dec a
            add a
            ld c, a
            ld a, [m_jp]
            ld l, a
            ld a, [m_jp + 1]
            ld h, a
            ld b, 0
            add hl, bc
            ld de, m_tmp8
            ld bc, 2
            ld a, B_BDAT3
            call far_copy
            ld a, [m_tmp8]
            and 7
            ld [m_jadd], a
            ld a, [m_x7f]                   ; stats: bits 7-3 -> $6112-$6116 + n (99 at most)
            add $12
            ld l, a
            ld h, high(SRAM_PAGE + $100)
            ld a, [m_tmp8]
            ld b, 5
.st:        add a
            push af
            jr nc, .sn
            ld a, [m_jadd]
            add [hl]
            cp 99
            jr c, .s1
            ld a, 99
.s1:        ld [hl], a
.sn:        pop af
            inc l
            dec b
            jr nz, .st
            ld a, [m_x7f]                   ; MP: bits 7-0 -> $613F, $613D .. $6131 + 1
            add $3F
            ld l, a
            ld a, [m_tmp8 + 1]
            ld b, 8
.ms:        add a
            push af
            jr nc, .mn
            ld a, [hl]
            inc a
            cp 99
            jr c, .m1
            ld a, 99
.m1:        ld [hl], a
.mn:        pop af
            dec l
            dec l
            dec b
            jr nz, .ms
            ld a, [m_lvl]
            dec a
            ld [m_lvl], a
            jr nz, .lv
.done:      ld a, [m_x7f]                   ; mod. stats = base; current MP <= max
            add $12
            ld l, a
            ld h, high(SRAM_PAGE + $100)
            ld e, l
            ld d, h
            ld a, e
            add 5
            ld e, a
            ld bc, 5
            call memcpy
            ld a, [m_x7f]
            add $30
            ld l, a
            ld b, 8
.cm:        inc l
            ld a, [hl-]
            cp [hl]
            jr nc, .cn
            ld [hl], a
.cn:        inc l
            inc l
            dec b
            jr nz, .cm
            ret

; ==== 6 Config (ours): FF3's message speed ($6010: 0-7, shown 1-8; 3D/BB59 wraps it)
m_config:   call m_clear
            call m_sprclr
            ld de, $0000
            ld bc, $0314
            call m_win
            ld hl, m_s_cfg
            ld de, $0101
            call m_puts0
            ld de, $0300
            ld bc, $0414
            call m_win
            ld hl, m_s_mspd
            ld de, $0402
            call m_puts0
            ld a, [SRAM_PAGE + $10]
            and 7
            inc a
            ld l, a
            ld h, 0
            ld de, $0411
            ld b, 1
            call m_num
            call m_show
            ld bc, $0401
            call m_hand
.lp:        call m_frame
            ldh a, [pad_new]
            ld b, a
            and $30
            jr nz, .ch
            ld a, b
            and PAD_A | PAD_B
            jr z, .lp
            call m_sfx_ok
            ret
.ch:        ld a, [SRAM_PAGE + $10]
            bit 4, b
            jr nz, .r
            dec a
            jr .s
.r:         inc a
.s:         and 7
            ld [SRAM_PAGE + $10], a
            call m_sfx_move
            jr m_config

; ==== 8 Suspend (ours): the page and the field's place in cart RAM bank 1, then the title;
; bank 1: $A000 page, $A400 field ($C100, 192), $A4C0 world / vehicle ($C2C0, 32), $A4F0 'S' '3' + sum
SU_FIELD   = $A400
SU_WORLD   = $A4C0
SU_CHECK   = $A4F0
m_suspend:  ld a, 1
            call sr_on
            ld hl, SRAM_PAGE
            ld de, $A000
            ld bc, $400
            call memcpy
            ld hl, $C100
            ld de, SU_FIELD
            ld bc, 192
            call memcpy
            ld hl, $C2C0
            ld de, SU_WORLD
            ld bc, 32
            call memcpy
            call su_sum
            ld hl, SU_CHECK
            ld [hl], 'S'
            inc l
            ld [hl], '3'
            inc l
            ld [hl], e
            inc l
            ld [hl], d
            call sr_off
            call m_sprclr
            ld hl, m_s_susp
            call m_msghl
            call m_show
            call m_waitkey
            call m_leave
            jp soft_reset
; DE = the sum of $A000-$A4EF (cart RAM on)
su_sum:     ld hl, $A000
            ld bc, $4F0
            ld de, 0
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
; A = 0 none, 1 good, 2 damaged
su_state:   ld a, 1
            call sr_on
            ld hl, SU_CHECK
            ld a, [hl+]
            cp 'S'
            jr nz, .none
            ld a, [hl]
            cp '3'
            jr nz, .none
            call su_sum
            ld hl, SU_CHECK + 2
            ld a, [hl+]
            cp e
            jr nz, .bad
            ld a, [hl]
            cp d
            jr nz, .bad
            call sr_off
            ld a, 1
            ret
.bad:       call sr_off
            ld a, 2
            ret
.none:      call sr_off
            xor a
            ret
; resume: everything back, the point erased (used once)
su_load:    ld a, 1
            call sr_on
            ld hl, $A000
            ld de, SRAM_PAGE
            ld bc, $400
            call memcpy
            ld hl, SU_FIELD
            ld de, $C100
            ld bc, 192
            call memcpy
            ld hl, SU_WORLD
            ld de, $C2C0
            ld bc, 32
            call memcpy
            xor a
            ld [SU_CHECK], a
            jp sr_off

; ==== shops and inns (people $E0-$FF; their script: scr_buf, 3F/E9E8): inns $E0-$E2 (3C/8E8D),
; shops $E3-$FB (3D/AF1F), the Fat Chocobo $FC+ (later). [m_res] = an event to run after (inns)
m_shop:     call m_enter
            call m_winpal
            xor a
            ld [m_res], a
            ld [m_mrow], a
            ld a, [ev_who]
            cp $E3
            jp c, m_inn
            cp $FC
            jp nc, .fat
            ld hl, scr_buf + 1              ; the eight items and their prices (3D/B220)
            ld de, s_items
            ld bc, 8
            call memcpy
            ld a, $26                       ; "Welcome! What is your business?"
            ld [s_mid], a
.top:       xor a
            ld [s_opt], a
            ld [s_qty], a
.tl:        ld a, 3
            ld [s_mode], a                  ; options: Buy Sell Exit
            call s_draw
            call s_opts
            jr c, .x
            ld a, [s_opt]
            cp 2
            jr z, .x
            and a
            jr nz, .sell
            ld a, 4                         ; how many: 1 4 10
            ld [s_mode], a
            ld a, $2D
            ld [s_mid], a
            xor a
            ld [s_opt], a
            call s_draw
            call s_opts
            jr c, .back
            ld a, [s_opt]
            ld [s_qty], a
            ld a, $27                       ; "What shall it be?"
            ld [s_mid], a
            call s_buy
.back:      ld a, $26
            ld [s_mid], a
            jr .tl
.sell:      ld a, 5                         ; how many: 1 All
            ld [s_mode], a
            ld a, $2E
            ld [s_mid], a
            xor a
            ld [s_opt], a
            call s_draw
            call s_opts
            jr c, .back
            ld a, [s_opt]
            ld [s_qty], a
            ld a, $2A                       ; "What will you sell?"
            ld [s_mid], a
            call s_sell
            jr .back
.x:         ld a, $29                       ; "Thank you for your patronage."
            ld [s_mid], a
            xor a
            ld [s_mode], a
            call s_draw
            call m_waitkey
            jp m_leave
.fat:       call m_sfx_err                  ; (the Fat Chocobo: later)
            jp m_leave

; the shop screen: message (0, 0) 20 x 4, options (0, 4) 20 x 3, list (0, 7) 20 x 8, Gil
; (0, 15) 20 x 3; s_mode: 0 none, 3 Buy / Sell / Exit, 4 1 / 4 / 10, 5 1 / All; s_list: 1 buy,
; 2 sell
s_draw:     call m_clear
            call m_sprclr
            xor a
            ld [m_mrow], a                  ; (the message at the top: rows 0-3)
            ld a, 4
            ld [m_mh], a
            call s_msg
            ld de, $0400
            ld bc, $0314
            call m_win
            ld a, [s_mode]
            ld hl, m_s_buy
            cp 3
            jr z, .o3
            ld hl, m_s_q1
            cp 4
            jr z, .o3
            cp 5
            jr nz, .no
            ld de, $0502                    ; 1 / All
            call m_puts0
            ld hl, m_s_qall
            ld e, 8
            call m_puts0
            jr .no
.o3:        ld de, $0502                    ; three words at columns 2, 8, 14
            call m_puts0
            ld e, 8
            call m_puts0
            ld e, 14
            call m_puts0
.no:        ld de, $0700
            ld bc, $0814
            call m_win
            call s_listdraw
            ld de, $0F00                    ; Gil
            ld bc, $0314
            call m_win
            ld hl, m_gil
            ld de, $1001
            call m_puts0
            ld hl, SRAM_PAGE + $1C
            ld de, $100B
            ld b, 7
            call m_num24
            jp m_show
; the message s_msg in rows 0-3 (its {04}: m_val)
s_msg:      ld a, [s_mid]
            call m_t82all
            ld hl, M_STR
            jp m_msghl
; choose one of s_mode's options (s_opt): C = B
s_opts:     ld a, [s_mode]
            ld b, 3
            cp 5
            jr nz, .n
            dec b
.n:         ld a, b
            ld [s_nopt], a
.lp:        ld a, [s_opt]                   ; the hand at column 1 + 6 opt
            ld c, a
            add a
            add c
            add a
            add 2
            ld c, a
            ld b, 5
            call m_hand
            call m_frame
            ldh a, [pad_new]
            bit 4, a
            jr nz, .r
            bit 5, a
            jr nz, .l
            bit 1, a
            jr nz, .x
            and PAD_A
            jr z, .lp
            call m_sfx_ok
            and a
            ret
.x:         call m_sfx_ok
            scf
            ret
.r:         ld a, [s_nopt]
            ld b, a
            ld a, [s_opt]
            inc a
            cp b
            jr c, .s
            xor a
            jr .s
.l:         ld a, [s_opt]
            and a
            jr nz, .l2
            ld a, [s_nopt]
.l2:        dec a
.s:         ld [s_opt], a
            call m_sfx_move
            jr .lp
; the list: buying: the eight items and their prices (for s_qty); selling: the pack (6 rows
; from m_top)
s_listdraw: ld a, [s_list]
            and a
            ret z
            cp 2
            jr z, .sell
            ld a, [m_top]
            ld [m_row], a
            ld d, 8
.b:         ld a, [m_row]
            cp 8
            ret nc
            ld hl, s_items
            add l
            ld l, a
            jr nc, .b1
            inc h
.b1:        ld a, [hl]
            and a
            jr z, .bn
            push de
            ld e, a
            ld d, 0
            call m_n88
            pop de
            push de
            ld e, 2
            ld a, 11
            call m_putsn
            ld a, [m_row]
            call s_price                    ; -> m_val
            pop de
            push de
            ld hl, m_val
            ld e, 12
            ld b, 7
            call m_num24
            pop de
.bn:        ld a, [m_row]
            inc a
            ld [m_row], a
            inc d
            ld a, d
            cp 14
            jr nz, .b
            ret
.sell:      ld a, [m_top]
            ld [m_row], a
            ld d, 8
.s:         ld a, [m_row]
            cp 32
            ret nc
            push de
            add $C0
            ld l, a
            ld h, high(SRAM_PAGE)
            ld a, [hl]
            and a
            jr z, .sn
            ld e, a
            ld d, 0
            call m_n88
            pop de
            push de
            ld e, 2
            ld a, 13
            call m_putsn
            pop de
            push de
            ld a, [m_row]
            add $E0
            ld l, a
            ld h, high(SRAM_PAGE)
            ld l, [hl]
            ld h, 0
            ld e, 16
            ld a, ':'
            call m_putc
            inc e
            ld b, 2
            call m_num
.sn:        pop de
            ld a, [m_row]
            inc a
            ld [m_row], a
            inc d
            ld a, d
            cp 14
            jr nz, .s
            ret
; m_val = item A's price (10/9E00 + 2 id: B_EVENTS $5E00)
s_base:     ld l, a
            ld h, 0
            add hl, hl
            ld bc, $5E00
            add hl, bc
            ld de, m_val
            ld bc, 2
            ld a, B_EVENTS
            call far_copy
            xor a
            ld [m_val + 2], a
            ret
; m_val = the price of shop item A for s_qty (3D/B281: 1: p; 4: 4p - 4p x 26 / 256; 10: 10p -
; 10p x 51 / 256, 24-bit as FF3)
s_price:    ld hl, s_items
            add l
            ld l, a
            jr nc, .g
            inc h
.g:         ld a, [hl]
            call s_base
            ld a, [s_qty]
            and a
            ret z
            cp 1
            ld b, 4
            ld c, 26
            jr z, .d
            ld b, 10
            ld c, 51
.d:         push bc
            ld a, b
            call m_mul24                    ; t = p x n
            ld hl, m_val
            ld de, s_t
            ld bc, 3
            call memcpy
            pop bc
            ld a, c
            call m_mul24                    ; u = t x k
            ld a, [s_t]                     ; t - u / 256
            ld hl, m_val + 1
            sub [hl]
            ld [m_val], a
            ld a, [s_t + 1]
            inc hl
            sbc [hl]
            ld [m_val + 1], a
            ld a, [s_t + 2]
            sbc 0
            ld [m_val + 2], a
            ret
; m_val = m_val x A (24 bits kept: 3C/8E55)
m_mul24:    ld b, a
            ld hl, m_val
            ld a, [hl+]
            ld c, a
            ld a, [hl+]
            ld d, a
            ld e, [hl]                      ; EDC = multiplicand
            xor a
            ld [s_acc], a
            ld [s_acc + 1], a
            ld [s_acc + 2], a
.l:         srl b
            jr nc, .s
            ld hl, s_acc
            ld a, [hl]
            add c
            ld [hl+], a
            ld a, [hl]
            adc d
            ld [hl+], a
            ld a, [hl]
            adc e
            ld [hl], a
.s:         sla c
            rl d
            rl e
            ld a, b
            and a
            jr nz, .l
            ld hl, s_acc
            ld de, m_val
            ld bc, 3
            jp memcpy
; C = gil < m_val (3D/B0CA)
s_short:    ld hl, SRAM_PAGE + $1E
            ld a, [m_val + 2]
            cp [hl]
            jr c, .ok
            jr nz, .no
            dec l
            ld a, [m_val + 1]
            cp [hl]
            jr c, .ok
            jr nz, .no
            dec l
            ld a, [m_val]
            cp [hl]
            jr c, .ok
            jr z, .ok
.no:        scf
            ret
.ok:        and a
            ret
; gil -= m_val; gil += m_val (at most 9999999)
s_pay:      ld hl, SRAM_PAGE + $1C
            ld a, [m_val]
            ld b, a
            ld a, [hl]
            sub b
            ld [hl+], a
            ld a, [m_val + 1]
            ld b, a
            ld a, [hl]
            sbc b
            ld [hl+], a
            ld a, [m_val + 2]
            ld b, a
            ld a, [hl]
            sbc b
            ld [hl], a
            ret
s_earn:     ld hl, SRAM_PAGE + $1C
            ld a, [m_val]
            add [hl]
            ld [hl+], a
            ld a, [m_val + 1]
            adc [hl]
            ld [hl+], a
            ld a, [m_val + 2]
            adc [hl]
            ld [hl], a
            %FAR B_FIELD, gil_cap
            ret

; buying (3D/AFFF): an item of the eight for s_qty x 1 / 4 / 10
s_buy:      ld a, 1
            ld [s_list], a
            xor a
            ld [m_icur], a
            ld [m_top], a
.scr:       call s_draw
.lp:        ld a, [m_icur]
            ld hl, m_top
            sub [hl]
            add 8
            ld b, a
            ld c, 1
            call m_hand
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
            ld a, [m_icur]
            call s_price
            call s_short
            ld a, $6C                       ; "You don't have enough money."
            jr c, .m
            ld a, [m_icur]
            ld hl, s_items
            add l
            ld l, a
            jr nc, .g
            inc h
.g:         ld a, [hl]
            and a
            jr z, .lp
            ld b, a
            ld a, [s_qty]                   ; 1 / 4 / 10 of it
            and a
            ld c, 1
            jr z, .q
            dec a
            ld c, 4
            jr z, .q
            ld c, 10
.q:         call s_carry                    ; C = can't carry
            ld a, $2C
            jr c, .m
            call s_pay
            ld a, $28                       ; "Thank you so much! Anything else?"
.m:         ld [s_mid], a
            jr .scr
.x:         xor a
            ld [s_list], a
            ret
.up:        ld a, [m_icur]
            and a
            jr z, .lp
            dec a
            jr .mv
.dn:        ld a, [m_icur]
            cp 7
            jr z, .lp
            inc a
.mv:        ld [m_icur], a
            call m_sfx_move
            ld hl, m_top
            ld a, [m_icur]
            cp [hl]
            jr nc, .m1
            ld [hl], a
            jr .scr
.m1:        sub [hl]
            cp 6
            jr c, .lp
            ld a, [hl]
            inc a
            ld [hl], a
            jr .scr
; B of item id, C of them into the pack (3D/B078: its stack + C under 100, else the first
; empty place): C = no room
s_carry:    ld hl, SRAM_PAGE + $C0
            ld e, 32
.f:         ld a, [hl]
            cp b
            jr z, .st
            inc l
            dec e
            jr nz, .f
            ld hl, SRAM_PAGE + $C0
            ld e, 32
.e:         ld a, [hl]
            and a
            jr z, .new
            inc l
            dec e
            jr nz, .e
            scf
            ret
.st:        ld a, l
            add $20
            ld l, a
            ld a, [hl]
            add c
            cp 100
            ccf
            ret c
            ld [hl], a
            ret
.new:       ld [hl], b
            ld a, l
            add $20
            ld l, a
            ld [hl], c
            and a
            ret

; selling (3D/B129): one / all of a pack's item for half its price
s_sell:     ld a, 2
            ld [s_list], a
            xor a
            ld [m_icur], a
            ld [m_top], a
.scr:       call s_draw
.lp:        ld a, [m_icur]
            ld hl, m_top
            sub [hl]
            add 8
            ld b, a
            ld c, 1
            call m_hand
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
            ld a, [m_icur]
            add $C0
            ld l, a
            ld h, high(SRAM_PAGE)
            ld a, [hl]
            and a
            jr z, .err
            cp $9A                          ; not key items, not Toad / Minimum
            jr c, .ok
            cp $A4
            jr c, .err
            cp $F6
            jr z, .err
            cp $F7
            jr z, .err
.ok:        call m_sfx_ok
            call s_base                     ; half the price (x count for All: 3D/B248)
            ld a, [s_qty]
            and a
            jr z, .h
            ld a, [m_icur]
            add $E0
            ld l, a
            ld h, high(SRAM_PAGE)
            ld a, [hl]
            call m_mul24
.h:         ld hl, m_val + 2
            srl [hl]
            dec hl
            rr [hl]
            dec hl
            rr [hl]
            ld a, $2B                       ; "That will come to N Gil." (A: yes)
            ld [s_mid], a
            call s_draw
            call m_waitkey
            ldh a, [pad_new]
            and PAD_A
            jr z, .no
            call m_sfx_ok
            ld a, [m_icur]                  ; one / all of them go
            add $E0
            ld l, a
            ld h, high(SRAM_PAGE)
            ld a, [s_qty]
            and a
            jr nz, .all
            dec [hl]
            jr nz, .e
.all:       ld [hl], 0
            ld a, l
            sub $20
            ld l, a
            ld [hl], 0
.e:         call s_earn
.no:        ld a, $2A
            ld [s_mid], a
            jr .scr
.err:       call m_sfx_err
            jp .lp
.x:         xor a
            ld [s_list], a
            ret
.up:        ld a, [m_icur]
            and a
            jp z, .lp
            dec a
            jr .mv
.dn:        ld a, [m_icur]
            cp 31
            jp z, .lp
            inc a
.mv:        ld [m_icur], a
            call m_sfx_move
            ld hl, m_top
            ld a, [m_icur]
            cp [hl]
            jr nc, .m1
            ld [hl], a
            jp .scr
.m1:        sub [hl]
            cp 6
            jp c, .lp
            ld a, [hl]
            inc a
            ld [hl], a
            jp .scr

; ---- an inn (3C/8E8D): 5 x the living x the script's rate; yes: pay, HP to max for the
; living, then the script's event
m_inn:      ld b, 0                         ; the living (not dead / stone)
            ld hl, SRAM_PAGE + $102
.c:         ld a, [hl]
            and $C0
            jr nz, .n
            inc b
.n:         ld a, l
            add $40
            ld l, a
            jr nc, .c
            ld a, b
            add a
            add a
            add b
            push af
            ld a, [scr_buf]
            ld [m_val], a
            xor a
            ld [m_val + 1], a
            ld [m_val + 2], a
            pop af
            call m_mul24
            ld a, 3
            ld [m_mrow], a
            ld a, 9
            ld [m_mh], a
            call m_clear
            call m_sprclr
            ld a, $04                       ; the innkeeper's question (its {04}: the cost)
            call m_msg
            ld de, $0F00
            ld bc, $0314
            call m_win
            ld hl, m_gil
            ld de, $1001
            call m_puts0
            ld hl, SRAM_PAGE + $1C
            ld de, $100B
            ld b, 7
            call m_num24
            call m_show
            call m_yesno2
            jr c, .x
            call s_short
            ld a, $6C                       ; "You don't have enough money."
            jr c, .m
            call s_pay
            ld hl, SRAM_PAGE + $1C          ; (the Gil shown again)
            ld de, $100B
            ld b, 7
            call m_num24
            ld hl, SRAM_PAGE + $10C         ; 3C/8ED8: HP to max for the living
.h:         ld a, l
            sub $0A
            ld e, a
            ld d, h
            ld a, [de]
            and $C0
            jr nz, .hn
            push hl
            inc l
            inc l
            ld a, [hl+]
            ld b, [hl]
            pop hl
            ld [hl+], a
            ld [hl], b
            dec l
.hn:        ld a, l
            add $40
            ld l, a
            jr nc, .h
            ld a, [scr_buf + 1]             ; the event after
            ld [m_res], a
            ld a, $4F                       ; "Thank you very much. Please rest well..."
.m:         call m_msg
            call m_show
            call m_waitkey
.x:         jp m_leave
; Yes / No under the inn's message (rows 13-14: the hand at 13 / 14)
m_yesno2:   ld hl, m_s_yes
            ld de, $0C02
            call m_puts0
            ld hl, m_s_no
            ld de, $0D02
            call m_puts0
            ld a, 1
            ld [m_dirty], a
            xor a
            ld [m_yn], a
.lp:        ld a, [m_yn]
            add 12
            ld b, a
            ld c, 2
            call m_hand2
            call m_frame
            ldh a, [pad_new]
            and $C0
            jr nz, .t
            ldh a, [pad_new]
            bit 1, a
            jr nz, .no
            and PAD_A
            jr z, .lp
            call m_hand2off
            call m_sfx_ok
            ld a, [m_yn]
            and a
            ret z
            scf
            ret
.t:         ld a, [m_yn]
            xor 1
            ld [m_yn], a
            call m_sfx_move
            jr .lp
.no:        call m_hand2off
            call m_sfx_ok
            scf
            ret

section bank B_MENU, $7C00
sp_mask:    ds 56                           ; (3D/A20C, A244, A27C: from the ROM)
sp_lvl:     ds 56
sp_ptr:     ds 56
wp_comb:    ds 16                           ; (3C/9D4B)
job_prog:   ds 44                           ; (3D/AD59)

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
m_icur:     ds 1
m_top:      ds 1
m_isel:     ds 2
m_islot:    ds 1
m_iid:      ds 1
m_x7f:      ds 1
m_pow:      ds 1
m_tgts:     ds 1
m_mult:     ds 1
m_amt:      ds 2
m_rnd:      ds 1
m_tmpc:     ds 1
m_spl:      ds 24
m_row:      ds 1
m_ecur:     ds 1
m_eslot:    ds 1
m_eany:     ds 1
m_elo:      ds 1
m_ehi:      ds 1
m_en:       ds 1
m_elist:    ds 32
m_mcur:     ds 1
m_lvl:      ds 1
m_caster:   ds 1
m_mpat:     ds 1
m_q:        ds 1
m_all:      ds 1
m_jn:       ds 1
m_newj:     ds 1
m_jadd:     ds 1
m_jp:       ds 2
m_jd:       ds 16
m_jcost:    ds 23
m_tmp8:     ds 8

m_su:       ds 1
m_mrow:     ds 1
m_mh:       ds 1
m_val:      ds 3
s_items:    ds 8
s_mid:      ds 1
s_opt:      ds 1
s_nopt:     ds 1
s_qty:      ds 1
s_mode:     ds 1
s_list:     ds 1
s_t:        ds 3
s_acc:      ds 3
