; ---- the Save menu (FF3 3D/A897; owner's choice V1; only on a world map, as FF3): Please choose
; the file to save to. ($014B), the three files one line each (lead member, Lv, save count), the
; chosen file's party below (name, Lv, HP); This erases old data. Yes / No ($014C), the copy,
; Saving is complete. ($014D), You can turn the power off now. (the GB has no RESET: the
; release checklist). Files: cart RAM bank 0, $A000 + $400 (file - 1), FF3's format and checks
; (3D/AE5C: $6019 = $5A, $601A = the complement of the byte sum; 3D/AE97: the sum + 1 = 0); the
; save count as FF3's $7F38-$7F3A at $AC00. Lot Check: the RAM enabled only around each access.
SV_CNT     = $AC00

save_menu:  ld a, [GS + $0E]
            xor a
            ld [sv_cur], a
            call sv_count                   ; (3D/A897: the save count validated, -> $6014)
.draw:      call sv_draw
.l:         ld a, [sv_cur]                  ; the hand at the file's line (rows 6-8)
            add a, 6
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
            jp nz, cur_hide
            bit 0, a
            jr nz, .a
            ld b, a
            ld a, [sv_cur]
            bit 6, b
            jr z, .d
            and a
            jr z, .l
            dec a
            jr .s
.d:         bit 7, b
            jr z, .l
            cp 2
            jr z, .l
            inc a
.s:         ld [sv_cur], a
            call sv_detail
            ld a, 1
            ld [m_dirty], a
            jr .l
.a:         ld a, $4C                       ; "This erases old data." Yes / No (B: no)
            call sv_yesno
            jr c, .draw
            call sv_write
            ld a, $4D                       ; "Saving is complete."
            call m_msgbox
            ld hl, s_off                    ; "You can turn the power off now."
            call sv_note
            jp cur_hide

; 3D/A897: $7F38 / $7F39 = $55 / $AA else the count starts at 1; -> $6014
sv_count:   call sram_on
            ld a, [SV_CNT]
            cp $55
            jr nz, .new
            ld a, [SV_CNT + 1]
            cp $AA
            jr z, .ok
.new:       ld a, $55
            ld [SV_CNT], a
            ld a, $AA
            ld [SV_CNT + 1], a
            ld a, 1
            ld [SV_CNT + 2], a
.ok:        ld a, [SV_CNT + 2]
            ld [GS + $14], a
            jp sram_off

; the save: 3D/AE5C (position, checksum), the count + 1 (99 -> 1), the block to file sv_cur
sv_write:   ld a, [cur_world]
            ld [GS + $08], a
            xor a
            ld [GS + $0F], a                ; (vehicle: none yet)
            ld a, [px]                      ; (FF3's $27 / $28: the view's corner = party - 7)
            sub 7
            ld [GS + $09], a
            ld a, [py]
            sub 7
            ld [GS + $0A], a
            xor a
            ld [GS + $1A], a
            ld a, $5A
            ld [GS + $19], a
            ld hl, GS
            ld bc, $400
            ld e, 0
.sum:       ld a, [hl+]
            add a, e
            ld e, a
            dec bc
            ld a, b
            or c
            jr nz, .sum
            ld a, e
            cpl
            ld [GS + $1A], a
            call sram_on
            ld a, [SV_CNT + 2]              ; (3D/A938)
            inc a
            cp 100
            jr c, .c
            ld a, 1
.c:         ld [SV_CNT + 2], a
            ld a, [sv_cur]
            add a, a
            add a, a
            add a, $A0
            ld d, a
            ld e, 0
            ld hl, GS
            ld bc, $400
            call memcpy
            jp sram_off

; A = file 0-2: carry if not valid (3D/AE97); HL = its address (RAM left enabled: sram_off after)
sv_valid:   add a, a
            add a, a
            add a, $A0
            ld h, a
            ld l, 0
            push hl
            call sram_on
            pop hl
            push hl
            ld a, l
            add a, $19
            ld l, a
            ld a, [hl]
            pop hl
            cp $5A
            scf
            ret nz
            push hl
            ld bc, $400
            ld e, 0
.s:         ld a, [hl+]
            add a, e
            ld e, a
            dec bc
            ld a, b
            or c
            jr nz, .s
            pop hl
            ld a, e
            inc a
            ret z                           ; (carry clear)
            scf
            ret

sram_on:    ld a, 0
            ld [$4000], a
            ld a, $0A
            ld [$0000], a
            ret
sram_off:   xor a
            ld [$0000], a
            ret

; the screen (V1)
sv_draw:    call m_clear
            ld bc, $0000
            ld de, $1405
            call m_box
            ld bc, $0101
            ld a, $4B                       ; "Please choose the file to save to."
            call m_msg1
            ld bc, $0005
            ld de, $1405
            call m_box
            xor a
.f:         ld [sv_tmp], a
            add a, 6
            ld c, a
            ld a, [sv_tmp]
            call sv_line
            ld a, [sv_tmp]
            inc a
            cp 3
            jr nz, .f
            call sv_detail
            ld a, 1
            ld [m_dirty], a
            ret
; file A's line at row C: "n", lead member's name, Lv, save count
sv_line:    push af
            ld b, 1
            add a, $81                      ; "1".."3"
            call m_put
            pop af
            push bc
            call sv_valid
            pop bc
            jp c, sram_off
            push hl                         ; (the lead member: $6100 block)
            ld de, $106
            add hl, de
            ld b, 3
            ld e, 6
            call m_codes
            pop hl
            push hl
            ld de, $101                     ; Lv
            add hl, de
            ld a, [hl]
            inc a
            ld e, a
            ld d, 0
            ld b, 10
            ld a, $95
            call m_put
            ld b, 13
            call m_dec
            pop hl
            ld de, $14                      ; the save count ($6014)
            add hl, de
            ld e, [hl]
            ld d, 0
            ld b, 18
            call m_dec
            jp sram_off
; the chosen file's party (rows 10-17): name, Lv, HP cur/max
sv_detail:  ld bc, $0009
            ld de, $1409
            call m_box
            ld c, 10                        ; (clear)
.cl:        ld b, 1
            ld e, 18
            ld a, $FF
.cc:        call m_put
            inc b
            dec e
            jr nz, .cc
            inc c
            ld a, c
            cp 17
            jr nz, .cl
            ld a, [sv_cur]
            call sv_valid
            jp c, sram_off
            ld a, h
            ld [sv_hi], a
            xor a
.m:         ld [sv_tmp], a
            add a, a
            add a, 10
            ld c, a
            ld a, [sv_tmp]
            rrca
            rrca
            ld l, a
            ld a, [sv_hi]
            inc a
            ld h, a                         ; (file + $100: the $6100 block)
            push hl
            ld a, l
            add a, 6
            ld l, a
            ld b, 2
            ld e, 6
            call m_codes
            pop hl
            push hl
            inc l
            ld a, [hl]
            inc a
            ld e, a
            ld d, 0
            ld b, 10
            ld a, $95
            call m_put
            ld b, 13
            call m_dec
            pop hl
            inc c                           ; HP on the next row
            ld a, l
            add a, $0C
            ld l, a
            ld b, 3
            ld a, $77
            call m_put
            inc b
            ld a, $79
            call m_put
            ld a, [hl+]
            ld e, a
            ld a, [hl+]
            ld d, a
            push hl
            ld b, 10
            call m_dec
            ld b, 11
            ld a, $C7
            call m_put
            pop hl
            ld a, [hl+]
            ld e, a
            ld d, [hl]
            ld b, 15
            call m_dec
            ld a, [sv_tmp]
            inc a
            cp 4
            jr nz, .m
            jp sram_off

; a t8200 question with Yes / No (No first; B = No): carry if no
sv_yesno:   push af
            call m_clear
            ld bc, $0000
            ld de, $1406
            call m_box
            pop af
            ld bc, $0101
            call m_msg1
            ld hl, s_yes
            ld bc, $0304
            call m_str
            ld hl, s_no
            ld bc, $0A04
            call m_str
            ld a, 1
            ld [m_dirty], a
            ld a, 1
            ld [sv_yn], a
.l:         ld a, [sv_yn]
            ld b, 8 + 1 * 8
            and a
            jr z, .x
            ld b, 8 + 8 * 8
.x:         ld c, 16 + 4 * 8 - 4
            call cursor_at
            call wait_vbl
            call read_pad
            call m_keys
            ld a, [m_new]
            bit 1, a
            jr nz, .no
            bit 0, a
            jr nz, .a
            and $30
            jr z, .l
            ld a, [sv_yn]
            xor 1
            ld [sv_yn], a
            jr .l
.a:         ld a, [sv_yn]
            and a
            ret z
.no:        scf
            ret

; a GB-only note (MENU_BANK string HL) in a box until a button
sv_note:    push hl
            call m_clear
            ld bc, $0000
            ld de, $1404
            call m_box
            pop hl
            ld bc, $0101
            call m_str
            ld hl, s_off2
            ld bc, $0102
            call m_str
            ld a, 1
            ld [m_dirty], a
            call cur_hide
            jp wait_keys

section wram, $C0F4
sv_cur:     ds 1
sv_tmp:     ds 1
sv_hi:      ds 1
sv_yn:      ds 1
