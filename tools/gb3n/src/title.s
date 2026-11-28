; ---- the boot screens (FF3 fix:C06E program start): a suspend point first (owner: Continue from
; Suspend point?), the prophecy (3A/8726: the narration, here as GB pages faded in and out, any
; button skips), the load menu (3D/B9F6: the three files as on the save screen and New Game, the
; message speed), New Game: FF3's new-game state and the name entry (3D/B895). Returns A: 0 new
; game, 1 a file loaded, 2 the suspend point resumed.

tl_flow:    call menu_pals                  ; (window palette 7, the font in bank 0, the hand)
            xor a
            call font_ld
            call hand_ld
            ld a, PAL_TXT
            ld [m_tattr], a
            ld a, 2
            ldh [rSVBK], a
            ld a, 1
            ld [menu_on], a
            call sus_check                  ; a suspend point?
            jr c, .nosus
            ld hl, s_cs1                    ; Continue from Suspend point?
            call tl_ask
            jr c, .nosus
            call sus_load
            call sus_erase
            ld a, 2
            jr .out
.nosus:     call tl_prophecy
.menu:      ld a, CODE11                    ; the file screen (svm.s)
            ld hl, svm_load
            call far_call
            ld a, [u_eres]
            cp 1
            jr z, .out
            ld a, CODE13                    ; New Game: the name entry (nme.s)
            ld hl, nme_open
            call far_call
            xor a
.out:       ld [tl_res], a
            push af
            call cur_hide
            call wait_vbl
            ld a, 1
            ldh [rSVBK], a
            xor a
            ld [menu_on], a
            call wait_vbl
            pop af
            ret

; ---- the suspend point (cart RAM bank 1: selmenu.s sus_save)
sus_check:  call sus_on                     ; carry if none
            ld a, [$A7FF]
            cp SUS_MAGIC
            call sus_off
            ret z
            scf
            ret
sus_on:     ld a, 1
            ld [$4000], a
            ld a, $0A
            ld [$0000], a
            ret
sus_off:    push af
            xor a
            ld [$0000], a
            ld [$4000], a
            pop af
            ret
sus_erase:  call sus_on
            xor a
            ld [$A7FF], a
            jp sus_off
sus_load:   call sus_on
            ld hl, $A000
            ld de, GS
            ld bc, $400
            call memcpy
            ld hl, $A400
            ld de, sus_vars
            ld bc, sus_end - sus_vars
            call memcpy
            ld de, $A500                    ; the place (the order of sus_pos)
            ld hl, sus_pos
.p:         ld a, [hl+]
            and a
            jr z, .pd
            ld c, a
            ld a, [hl+]
            push hl
            ld h, [hl]
            ld l, a
.pc:        ld a, [de]
            inc de
            ld [hl+], a
            dec c
            jr nz, .pc
            pop hl
            inc hl
            jr .p
.pd:        ld a, [opt_spd]
            ld [msg_speed], a
            jp sus_off

; a question in two GB-word lines (HL, then the string after it) with Yes / No: carry = no
tl_ask:     push hl
            call m_clear
            ld bc, $0003
            ld de, $1407
            call m_box
            pop hl
            ld bc, $0104
            call m_str                      ; (line 1, then the strings that follow it)
            ld bc, $0105
            call m_str
            ld hl, s_yes
            ld bc, $0307
            call m_str
            ld hl, s_no
            ld bc, $0A07
            call m_str
            ld a, 1
            ld [m_dirty], a
            xor a
            ld [sv_yn], a                   ; (Yes first)
.l:         ld a, [sv_yn]
            ld b, 8 + 1 * 8
            and a
            jr z, .x
            ld b, 8 + 8 * 8
.x:         ld c, 16 + 7 * 8 - 4
            call cursor_at
            call wait_vbl
            call read_pad
            call m_keys
            ld a, [m_new]
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
            scf
            ret

; ---- the prophecy as FF3 shows it (3A/8726-3A/8883): the screen NES blue ($02); each page's lines
; 16 pixels apart, each line hidden (ink blue), then faded in (ink $00 -> $10 -> $20 -> $30, a step
; every 16 frames, on odd frames a step lower: FF3's flicker), then shown in light grey ($10) while
; the next one fades in; a page follows the last line at once (FF3 cuts). A, B or START ends the
; prophecy (owner). CGB palettes 4 / 5 / 6 = hidden / fading / shown (menu_pals put back after).
PR_HID     = 4
PR_BUF     = $D800                 ; (WRAM 2: free at the title)
PR_FADE    = 5
PR_DONE    = 6
pr_prev    = xtr_k                      ; (the encounter transition's bytes: free at the title)
pr_f       = xtr_k + 1
pr_v       = xtr_k + 2
pr_n       = xtr_k + 3
pr_r0      = xtr_k + 4
pr_k       = xtr_k + 5
tl_prophecy: ld a, 1                        ; song 1 (3A/8798)
            call snd_song
            ld a, $FF
            ld [pr_prev], a                 ; (a button still held from before: not a press)
            ld b, 12                        ; palettes 4-6: all NES blue; 6's ink light grey
            ld hl, pal_sh + 8 * PR_HID
.pb:        push bc
            push hl
            ld a, $02
            call pr_col
            pop hl
            pop bc
            ld a, e
            ld [hl+], a
            ld a, d
            ld [hl+], a
            dec b
            jr nz, .pb
            ld a, $10
            ld hl, pal_sh + 8 * PR_DONE + 6
            call pr_set
            ld hl, TL_PRO                   ; (the pages: bank CODE10 -> WRAM 2 PR_BUF)
            ld de, PR_BUF
            ld bc, TL_PRO_END - TL_PRO
            ld a, CODE10
            call rd_copy
            ld a, low(PR_BUF)
            ld [tl_ptr], a
            ld a, high(PR_BUF)
            ld [tl_ptr + 1], a
.page:      call m_clear
            ld hl, MC_ATTR                  ; (every cell hidden-blue)
            ld bc, 32 * 18
.at:        ld a, PR_HID
            ld [hl+], a
            dec bc
            ld a, b
            or c
            jr nz, .at
            ld hl, tl_ptr                   ; the page's lines: counted, then drawn 2 rows apart
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld c, 1
.cnt:       ld a, [hl+]
            and a
            jr z, .cn
            cp $0B
            jr z, .cn
            cp $01
            jr nz, .cnt
            inc c
            jr .cnt
.cn:        ld a, c
            ld [pr_n], a
            add a, a                        ; first row (19 - 2 n) / 2
            cpl
            add a, 20
            srl a
            ld [pr_r0], a
            ld a, PR_HID
            ld [m_attr], a
            ld hl, tl_ptr
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld a, [pr_r0]
            ld c, a
            ld b, 1
.ch:        ld a, [hl+]
            and a
            jr z, .drawn
            cp $0B
            jr z, .drawn
            cp $01
            jr nz, .put
            ld b, 1
            inc c
            inc c
            jr .ch
.put:       call m_put2
            inc b
            jr .ch
.drawn:     dec hl                          ; (the end code: $0B next page, 0 the last)
            ld a, [hl+]
            push af
            ld a, l
            ld [tl_ptr], a
            ld a, h
            ld [tl_ptr + 1], a
            ld a, 1
            ld [m_dirty], a
            call cur_hide
            call wait_vbl
            call wait_vbl
            xor a
            ld [pr_k], a
.line:      ld a, PR_FADE                   ; 3A/87E6: this line fades in
            call pr_row
            call pr_fade
            jr c, .skip
            ld a, PR_DONE                   ; then shows in grey
            call pr_row
            ld hl, pr_k
            inc [hl]
            ld a, [pr_n]
            cp [hl]
            jr nz, .line
            call pr_frame                   ; (3A/87FE: one frame's input)
            jr c, .skip
            pop af
            and a
            jp nz, .page
            jr .end
.skip:      pop af
.end:       ld hl, pal_sh + 8 * PR_HID      ; the screen black, the menus' palettes back
            ld b, 24
            xor a
.bk:        ld [hl+], a
            dec b
            jr nz, .bk
            ld a, 1
            ldh [pal_dirty], a
            call wait_vbl
            call wait_vbl
            call m_clear
            ld a, 1
            ld [m_dirty], a
.rel:       call wait_vbl                   ; (the button that ended it let go first: it must
            call read_pad                   ;   not carry into the load menu)
            ldh a, [pad]
            and a
            jr nz, .rel
            call wait_vbl
            jp menu_pals
; line pr_k's row (pr_r0 + 2 k): its 20 cells to palette A, the attributes copied next V-Blank
pr_row:     push af
            ld a, [pr_k]
            add a, a
            ld hl, pr_r0
            add a, [hl]
            ld l, a                         ; MC_ATTR + 32 row
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, MC_ATTR
            add hl, de
            pop af
            ld b, 20
.l:         ld [hl+], a
            dec b
            jr nz, .l
            ld a, 2
            ld [m_dirty], a
            ret
; 3A/8801: the fading line's ink $00 / $10 / $20 / $30, 16 frames each, odd frames a step lower
; ($01 below $00); C set when a button ended the prophecy
pr_fade:    xor a
            ld [pr_v], a
            ld [pr_f], a
.f:         ld a, [pr_f]
            ld b, a
            and $0F
            ld a, [pr_v]
            jr z, .c
            bit 0, b
            jr z, .c
            sub $10
            jr nc, .c
            ld a, $01
.c:         ld hl, pal_sh + 8 * PR_FADE + 6
            call pr_set
            call pr_frame
            ret c
            ld hl, pr_f
            inc [hl]
            ld a, [hl]
            and $0F
            jr nz, .f
            ld a, [pr_v]
            add a, $10
            ld [pr_v], a
            cp $40
            jr c, .f
            and a
            ret
; a frame (3A/884C): the palettes up, the music, the pad; C set on a new A / B / START
pr_frame:   ld a, 1
            ldh [pal_dirty], a
            call wait_vbl
            call read_pad
            ldh a, [pad]
            ld b, a
            ld a, [pr_prev]
            cpl
            and b
            ld c, a
            ld a, b
            ld [pr_prev], a
            ld a, c
            and $0B                         ; (A, B, START)
            ret z
            scf
            ret
; NES colour A -> RGB555 at [HL] (pr_col: -> DE)
pr_set:     push hl
            call pr_col
            pop hl
            ld a, e
            ld [hl+], a
            ld [hl], d
            ret
pr_col:     and $3F                         ; (NES_RGB: 2 bytes a colour)
            add a, a
            ld l, a
            ld h, 0
            ld de, NES_RGB
            add hl, de
            ld e, [hl]
            inc hl
            ld d, [hl]
            ret

; ---- the load menu (3D/B9F6): New Game and the speed on top, the files below; A on a valid file
; loads it (the message speed of its slot), on New Game starts one (FF3's new-game state)
tl_load:    ld a, 1                         ; song 1 (3D/BA4E; still playing after the prophecy)
            call snd_song
            call menu_pals
            ld a, 3
            ld [tl_cur], a                  ; (New Game first: 3D/BA44 cursor $0C)
.draw:      call m_clear
            ld bc, $0000
            ld de, $1404
            call m_box
            ld hl, s_newgame
            ld bc, $0201
            call m_str
            ld hl, s_spd
            ld bc, $0202
            call m_str
            ld a, [opt_spd]
            inc a
            ld bc, $1102
            call m_digit
            ld bc, $0004
            ld de, $1405
            call m_box
            xor a
.f:         ld [sv_tmp], a
            add a, 5
            ld c, a
            ld a, [sv_tmp]
            call sv_line
            ld a, [sv_tmp]
            inc a
            cp 3
            jr nz, .f
            ld a, [tl_cur]                  ; the chosen file's party
            cp 3
            jr z, .np
            ld [sv_cur], a
            call sv_detail
.np:        ld a, 1
            ld [m_dirty], a
.l:         ld a, [tl_cur]
            cp 3
            ld c, 16 + 1 * 8 - 4
            jr z, .cp
            add a, 5
            add a, a
            add a, a
            add a, a
            add a, 16 - 4
            ld c, a
.cp:        ld b, 8
            call cursor_at
            call wait_vbl
            call read_pad
            call m_keys
            ld a, [m_new]
            bit 0, a
            jr nz, .a
            ld b, a
            and $30                         ; left / right: the speed
            jr z, .ud
            ld a, [opt_spd]
            bit 4, b
            jr z, .dec
            inc a
            jr .sp
.dec:       dec a
.sp:        and 7
            ld [opt_spd], a
            ld [msg_speed], a
            jp .draw
.ud:        ld a, [tl_cur]                  ; up / down: New Game, files 1-3
            bit 6, b
            jr z, .dn
            cp 3
            jr z, .l
            and a
            ld a, 3
            jr z, .s
            ld a, [tl_cur]
            dec a
            jr .s
.dn:        bit 7, b
            jr z, .l
            cp 3
            ld a, 0
            jr z, .s
            ld a, [tl_cur]
            cp 2
            jr z, .l
            inc a
.s:         ld [tl_cur], a
            jp .draw
.a:         ld a, [tl_cur]
            cp 3
            jr z, .new
            call sv_valid                   ; (a file that is not valid: nothing)
            jr c, .inv
            ld de, GS                       ; load: the file -> the save block
            ld bc, $400
            call memcpy
            call sram_off
            ld a, [opt_spd]
            ld [GS + $10], a
            ld a, 1
            ret
.inv:       call sram_off
            jp .l
.new:       ld a, [opt_spd]                 ; (3D/BAC6: init, the speed -> $6010)
            ld [GS + $10], a
            xor a
            ret

; ---- the name entry (3D/B895, the layout of the earlier engine the owner preferred): the member at
; the top (its walking picture, the name with a dash at the next letter, the job), the letters
; below: 9 x 5, one case at a time (SELECT switches), A a letter (6 at most), B the last letter off
; (none: back to the member before), START this name (not empty). FF3's rule kept: a name like an
; earlier member's is refused (3D/B981).
tl_names:   xor a
            ld [nm_ch], a
            ld [nm_case], a
.ch:        xor a
            ld [nm_cur], a
            call nm_len                     ; (a name already there: its length)
            ld [nm_pos], a
            call nm_pic
.draw:      call nm_fill
            call m_clear
            ld bc, $0000
            ld de, $1405
            call m_box
            ld a, [nm_ch]                   ; the name so far ($6106 + $40 n)
            rrca
            rrca
            add a, 6
            ld l, a
            ld h, high(GS + $100)
            ld bc, $0501
            ld e, 6
            call m_codes
            ld a, [nm_pos]                  ; the next letter's place: a dash
            cp 6
            jr nc, .nd
            add a, 5
            ld b, a
            ld c, 1
            ld a, $C2                       ; -
            call m_put
.nd:        ld hl, TL_JOB                   ; the job (all Onion Knights at the start)
            ld bc, $0503
            ld e, TL_JOBE - TL_JOB
            call m_codes
            ld bc, $0005
            ld de, $140D
            call m_box
            ld hl, TL_G0
            ld a, [nm_case]
            and a
            jr z, .g
            ld hl, TL_G1
.g:         ld c, 6
.gr:        ld b, 2
            ld e, 9
.gc:        ld a, [hl+]
            call m_put
            inc b
            inc b
            dec e
            jr nz, .gc
            inc c
            inc c
            ld a, c
            cp 16
            jr nz, .gr
            ld hl, TL_H0
            ld a, [nm_case]
            and a
            jr z, .h
            ld hl, TL_H1
.h:         ld bc, $010F
            ld e, 11
            call m_codes
            ld hl, TL_H2
            ld bc, $0110
            ld e, 18
            call m_codes
            ld a, 1
            ld [m_dirty], a
.l:         ld a, [nm_cur]                  ; the hand at letter nm_cur (column 2 + 2x, row 6 + 2y)
            ld b, 0
.dv:        sub 9
            jr c, .dd
            inc b
            jr .dv
.dd:        add a, 9
            add a, a
            add a, 2
            ld d, a
            ld a, b
            add a, a
            add a, 6
            ld c, a
            ld b, d
            call hand_txt
            call wait_vbl
            call read_pad
            call m_keys
            ld a, [m_new]
            bit 0, a
            jp nz, .a
            bit 1, a
            jr nz, .b
            bit 2, a
            jr nz, .case
            bit 3, a
            jr nz, .done
            ld b, a
            ld a, [nm_cur]
            bit 4, b
            jr z, .lf
            inc a
            cp 45
            jr c, .s
            xor a
            jr .s
.lf:        bit 5, b
            jr z, .up
            dec a
            cp $FF
            jr nz, .s
            ld a, 44
            jr .s
.up:        bit 6, b
            jr z, .dn
            sub 9
            jr nc, .s
            add a, 45
            jr .s
.dn:        bit 7, b
            jr z, .l
            add a, 9
            cp 45
            jr c, .s
            sub 45
.s:         ld [nm_cur], a
            jp .l
.case:      ld a, [nm_case]
            xor 1
            ld [nm_case], a
            jp .draw
.b:         ld a, [nm_pos]                  ; B: the last letter off; none: the member before
            and a
            jr z, .bp
            dec a
            ld [nm_pos], a
            jp .draw
.bp:        ld a, [nm_ch]
            and a
            jp z, .l
            dec a
            ld [nm_ch], a
            jp .ch
.done:      ld a, [nm_pos]                  ; START: this name (not empty, not an earlier one's);
            and a                           ;   with none, one of the member's preset names
            jr nz, .dnm
            ld a, CODE10                    ; (extras.s)
            ld hl, nm_preset
            call far_call
            jp .draw
.dnm:
            call nm_dup
            jp c, .draw
            ld a, [nm_ch]
            inc a
            ld [nm_ch], a
            cp 4
            jp nz, .ch
            call cur_hide
            ld hl, oam_buf                  ; (the picture off)
            ld b, 4
            call oam_hide.l0
            ld a, [GS + $0E]
            ret
.a:         ld a, [nm_pos]                  ; A: the letter (6 at most)
            cp 6
            jp nc, .l
            ld a, [nm_cur]
            ld e, a
            ld d, 0
            ld hl, TL_G0
            ld a, [nm_case]
            and a
            jr z, .a1
            ld hl, TL_G1
.a1:        add hl, de
            ld b, [hl]
            ld a, [nm_ch]
            rrca
            rrca
            add a, 6
            ld e, a
            ld a, [nm_pos]
            add a, e
            ld l, a
            ld h, high(GS + $100)
            ld [hl], b
            ld a, [nm_pos]
            inc a
            ld [nm_pos], a
            jp .draw

; the hand with its fingertip just before the text at column B, row C, the finger at the text's
; middle (FF1's rule: the hand's left = text - 16, its top = the text's top)
hand_txt:   ld a, b
            add a, a
            add a, a
            add a, a
            sub 16 - 8
            ld b, a
            ld a, c
            add a, a
            add a, a
            add a, a
            add a, 16
            ld c, a
            jp cursor_at

; the length of member nm_ch's name (up to the first blank) -> A
nm_len:     ld a, [nm_ch]
            rrca
            rrca
            add a, 6
            ld l, a
            ld h, high(GS + $100)
            ld b, 0
.l:         ld a, [hl+]
            cp $FF
            jr z, .x
            and a
            jr z, .x
            inc b
            ld a, b
            cp 6
            jr nz, .l
.x:         ld a, b
            ret
; the name's letters after nm_pos: blanks ($FF)
nm_fill:    ld a, [nm_ch]
            rrca
            rrca
            add a, 6
            ld hl, nm_pos
            add a, [hl]
            ld l, a
            ld h, high(GS + $100)
            ld a, [nm_pos]
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
; member nm_ch's walking picture (facing down) beside the name: its tiles and colours as the
; field's (select.s char_gfx / char_pal), OAM 0-3 at column 1-2, rows 1-2
nm_pic:     ld a, [GS + $0E]
            push af
            ld a, [nm_ch]
            rrca
            rrca
            ld [GS + $0E], a
            call char_gfx
            call char_pal
            pop af
            ld [GS + $0E], a
            ld a, 1
            ldh [pal_dirty], a
            ld hl, $7F00                    ; (SPR_BANK: the field's frames, as load_map: M_FACE /
            ld de, M_FACE                   ;   M_FRAME; frame $30 faces down)
            ld bc, $50
            ld a, SPR_BANK
            call rd_copy
            ld de, M_FRAME + $30
            ld hl, oam_buf
            ld bc, (8 + 12) * 256 + 16 + 8  ; (B = x, C = y in OAM coordinates)
            call .s
            ld a, c
            add a, 8
            ld c, a
            call .s
            ld a, b
            add a, 8
            ld b, a
            ld a, c
            sub 8
            ld c, a
            call .s
            ld a, c
            add a, 8
            ld c, a
.s:         ld a, c
            ld [hl+], a
            ld a, b
            ld [hl+], a
            ld a, [de]
            inc de
            ld [hl+], a
            ld a, [de]
            inc de
            ld [hl+], a
            ret

; 3D/B95D / B981: the name of member nm_ch against the earlier ones
nm_dup:     ld a, [nm_ch]
            and a
            ret z
            ld b, a
            ld c, 0
.m:         push bc
            ld a, c
            rrca
            rrca
            add a, 6
            ld e, a
            ld d, high(GS + $100)
            ld a, b
            rrca
            rrca
            add a, 6
            ld l, a
            ld h, d
            ld b, 6
.c:         ld a, [de]
            cp [hl]
            jr nz, .diff
            inc e
            inc l
            dec b
            jr nz, .c
            pop bc
            scf                             ; (refused: carry)
            ret
.diff:      pop bc
            inc c
            ld a, c
            cp b
            jr nz, .m
            and a
            ret

section wram, $CFF4
tl_cur:     ds 1
tl_res:     ds 1
tl_ptr:     ds 2
nm_ch:      ds 1
nm_pos:     ds 1
nm_cur:     ds 1
nm_case:    ds 1
np_last:    ds 1
