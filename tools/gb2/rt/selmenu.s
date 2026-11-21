; Select menu (OPTIONS / FORMATION / SUSPEND) and suspend points (owner's brief, FF2 GB).
; GB only: the NES variant's bank-23 routines gsel / gres (tools/gb2/layout.py) are replaced
; by sel_menu_b / sel_resume_b (NATIVE_EXT). The menu is drawn on the window layer with tiles
; in the sprite slots ($8000-$85FF): the BG tiles and map are not touched; on the way out the
; window map is put back and the slot cache emptied (slots load again from the sprite shadow
; on use). The letters and the window frame come from the game's menu font (NES bank 9).
;
; Suspend point: a snapshot of the machine taken when SUSPEND is confirmed (WRAM - on a Game
; Boy Color all eight banks -, HRAM, VRAM - both banks -, the NES work RAM without the save
; slots, the DMG tile shadows, the DMG scan table) in cart RAM banks 4-12, with a header and
; a checksum in bank 3 (SU_HDR). Resuming (the load menu's prompt) restores it and returns
; into the suspended menu, which leaves as after any Select menu: the game reloads the map.
; Resuming erases the suspend point. A snapshot is only resumed on the model it was taken on.
;
; Cart RAM bank 3: $A110 options (SM_OPT), $A120 suspend header (SU_HDR); banks 4-12 data.

SM_OPT     = $A110          ; 'OP', BGM volume, SFX volume, check (xor of the two, $5A)
SU_HDR     = $A120          ; 'SUSP', model, SP (2), checksum (2), check byte
SU_BANK0   = 4              ; first cart RAM bank of the snapshot
SM_BUF     = $A200          ; cart RAM bank 3 scratch: font bytes from the ROM
SM_FONTB   = DATA + 9       ; ROM bank of the menu font (NES bank 9, $8320 + 16 t)
SM_FONTA   = $4320

; HRAM scratch while the menu runs (the boot stack area, unused otherwise)
SM_PREV    = $FFFA          ; buttons last frame
SM_SPL     = $FFFC          ; (resume: saved SP)
SM_SPH     = $FFFD
; fixed WRAM scratch ($CCDE-$CCDF free; stream state in VT_BUF while the menu runs)
SM_CUR     = $CCDE          ; cursor row
SM_TMP     = $CCDF
SU_B       = $CCD0          ; stream: cart RAM bank, pointer (2), checksum (2), mode
SU_P       = $CCD1
SU_S       = $CCD3
SU_M       = $CCD5

; tiles in the slots
T_FRAME    = 80             ; $F7-$FE: top-left, top, top-right, left, right, bottom-left,
T_BLANK    = 88             ;   bottom, bottom-right
T_CUR      = 89

section bank 0, $3F40
hle_select: call rt_fcs                     ; layout gsel (bank 23): the Select menu
            db SGB_BANK
            dw sel_menu_b
hle_resume: call rt_fcs                     ; layout gres (bank 23): the suspend prompt
            db SGB_BANK
            dw sel_resume_b
; A = ROM bank: BC bytes from HL (its $4000-$7FFF window) to DE; then SGB_BANK again
far_copy:   ld [$2000], a
.l:         ld a, [hl+]
            ld [de], a
            inc de
            dec bc
            ld a, b
            or c
            jr nz, .l
            ld a, SGB_BANK
            ld [$2000], a
            ret

section bank SGB_BANK, $6800
; ---- options at boot (save.s boot_more): the stored volumes, else 8 / 8
sm_boot:    ld a, 3
            ld [$4000], a
            ld hl, SM_OPT
            ld a, [hl+]
            cp $4F
            jr nz, .def
            ld a, [hl+]
            cp $50
            jr nz, .def
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld c, a
            xor b
            xor $5A
            cp [hl]
            jr nz, .def
            ld a, b
            cp 9
            jr nc, .def
            ld a, c
            cp 9
            jr nc, .def
            jr .set
.def:       ld bc, $0808
.set:       ld a, b
            ld [VOL_BGM], a
            ld a, c
            ld [VOL_SFX], a
            call sm_optput
            xor a
            ld [$4000], a
            ret

; cart RAM bank 3 mapped: the options block from VOL_BGM / VOL_SFX
sm_optput:  ld hl, SM_OPT
            ld [hl], $4F
            inc hl
            ld [hl], $50
            inc hl
            ld a, [VOL_BGM]
            ld [hl+], a
            ld b, a
            ld a, [VOL_SFX]
            ld [hl+], a
            xor b
            xor $5A
            ld [hl], a
            ret

; ---- the Select menu (field; interrupts on, LCD on). Out: GBARG (NES $7FE9) = 0 the row
; screen (FORMATION), 1 back to the field. Keeps C, E (NES Y, X); B = D = 0.
sel_menu_b: push bc
            push de
            call ui_begin
.top:       call ui_clear
            ld bc, $0000                    ; window (0,0) 12 x 5
            ld de, $0C05
            call ui_box
            ld bc, $0201
            ld hl, SMT_SEL
            call ui_text
            call ui_show
            xor a
            ld [SM_CUR], a
.sl:        ld a, [SM_CUR]
            ld b, 1
            add a, 1
            ld c, a
            ld a, 3
            call ui_curs                    ; cursor at column 1, rows 1-3
            call ui_frame
            bit 1, a                        ; B: back to the field
            jr nz, .back
            bit 0, a
            jr nz, .pick
            ld b, 3
            call ui_updown
            jr .sl
.pick:      ld a, [SM_CUR]
            and a
            jr z, .opts
            dec a
            jr z, .form
            call sm_suspend                 ; (returns here only if not confirmed / resumed)
            jr c, .back                     ; (resumed: back to the field)
            jr .top
.opts:      call sm_options
            jr .top
.form:      xor a
            jr .out
.back:      ld a, 1
.out:       ld [$BFE9], a                   ; GBARG (cart RAM bank 0 = NES $6000-$7FFF)
            call ui_end
            pop de
            pop bc
            ld b, 0
            ld d, 0
            xor a
            ldh [nzv], a
            ret

; ---- OPTIONS: Battle Speed (the game's message speed $601F, 0-7, shown 1-8), BGM / SFX
; volume (0-8). Up / down choose, left / right change, A / B back.
sm_options: call ui_clear
            ld bc, $0000
            ld de, $1405
            call ui_box
            ld bc, $0201
            ld hl, SMT_OPT
            call ui_text
            xor a
            ld [SM_CUR], a
            call .vals
            call ui_show
.lp:        call .vals
            ld a, [SM_CUR]
            inc a
            ld c, a
            ld b, 1
            ld a, 3
            call ui_curs
            call ui_frame
            and $03                         ; A / B: back
            jr nz, .done
            ldh a, [SM_PREV + 1]            ; (this frame's new presses)
            bit 4, a
            jr nz, .right
            bit 5, a
            jr nz, .left
            ld b, 3
            call ui_updown
            jr .lp
.right:     ld e, 1
            jr .chg
.left:      ld e, $FF
.chg:       ld a, [SM_CUR]
            and a
            jr nz, .vol
            ld a, [$A01F]                   ; NES $601F (cart RAM bank 0)
            add a, e
            cp 8
            jr nc, .lp
            ld [$A01F], a
            jr .lp
.vol:       dec a
            ld hl, VOL_BGM
            jr z, .v1
            inc hl
.v1:        ld a, [hl]
            add a, e
            cp 9
            jr nc, .lp
            ld [hl], a
            ld a, 3
            ld [$4000], a
            call sm_optput
            xor a
            ld [$4000], a
            jr .lp
.done:      ret
.vals:      ld a, [$A01F]                   ; the three values at column 17
            and 7
            inc a
            ld bc, $1101
            call ui_digit
            ld a, [VOL_BGM]
            ld bc, $1102
            call ui_digit
            ld a, [VOL_SFX]
            ld bc, $1103
            jp ui_digit

; ---- SUSPEND: the question; Yes: snapshot, then the title (soft reset). Out: carry = the
; game was resumed from this snapshot (back to the field), else back to the menu.
sm_suspend: call ui_clear
            ld bc, $0000
            ld de, $140C                    ; (8 lines of text, Yes / No on row 10)
            call ui_box
            ld bc, $0101
            ld hl, SMT_SUS
            call ui_text
            ld c, 10
            call ui_yesno
            and a
            ret nz                          ; No (carry clear)
            call su_save                    ; A = 0 saved, 1 resumed
            and a
            jr z, .title
            scf
            ret
.title:     jp soft_reset

; ---- the load menu (LCD off): a suspend point of this model -> 'Continue from Suspend
; point?' Yes: resume (no return). No: 'Continue from last save? / Start a New Game? The
; suspend point will be lost!' Yes: erased, the load menu as usual; No: the first question.
sel_resume_b:
            push bc
            push de
            call su_valid
            jr nz, .x                       ; (none)
            call su_sum
            jr z, .ok
            call ui_begin                   ; damaged: the message, erased
            call ui_clear
            ld bc, $0000
            ld de, $140A
            call ui_box
            ld bc, $0101
            ld hl, SMT_BAD
            call ui_text
            call ui_show
.wa:        call ui_frame
            and 1
            jr z, .wa
            call su_erase
            jr .end
.ok:        call ui_begin
.q1:        call ui_clear
            ld bc, $0000
            ld de, $1406
            call ui_box
            ld bc, $0101
            ld hl, SMT_CONT
            call ui_text
            ld c, 4
            call ui_yesno
            and a
            jr nz, .q2
            call su_erase                   ; resuming erases the suspend point
            jp su_load                      ; (no return)
.q2:        call ui_clear
            ld bc, $0000
            ld de, $140A
            call ui_box
            ld hl, SMT_LOST2                ; a save in a slot? (FF2's slot check)
            ld c, 0
.sv:        push hl
            push bc
            call sv_valid
            pop bc
            pop hl
            jr z, .has
            inc c
            ld a, c
            cp 4
            jr nz, .sv
            jr .msg
.has:       ld hl, SMT_LOST1
.msg:       ld bc, $0101
            call ui_text
            ld c, 8
            call ui_yesno
            and a
            jr nz, .q1
            call su_erase
.end:       call ui_end
.x:         pop de
            pop bc
            ld b, 0
            ld d, 0
            xor a
            ldh [nzv], a
            ret

; ================================================================ screen
; set up: interrupts off, LCD off (in the V-Blank), sound muted, tiles into the slots,
; window map blank, palettes, LCD on with the window over the screen
ui_begin:   di
            ldh a, [$FF40]
            bit 7, a
            jr z, .off
.wv:        ldh a, [$FF44]
            cp 144
            jr c, .wv
            cp 152
            jr nc, .wv
            xor a
.lcdoff:    ldh [$FF40], a
.off:       xor a
            ldh [$FF25], a                  ; sound muted (NR51)
            ld b, 0                         ; queued VRAM writes out first (LCD off)
            call flush_q
            ld a, 3                         ; the font (80 letters, 8 frame tiles) -> SM_BUF
            ld [$4000], a
            ld a, SM_FONTB
            ld hl, SM_FONTA + 16 * $80
            ld de, SM_BUF
            ld bc, 80 * 16
            call far_copy
            ld a, SM_FONTB
            ld hl, SM_FONTA + 16 * $F7
            ld de, SM_BUF + 80 * 16
            ld bc, 8 * 16
            call far_copy
            ld hl, SM_BUF                   ; NES planar -> GB rows, slots 0-87
            ld de, $8000
            ld c, 88
.t:         ld b, 8
.r:         ld a, [hl]
            ld [de], a
            inc de
            push hl
            ld a, l
            add a, 8
            ld l, a
            jr nc, .nc
            inc h
.nc:        ld a, [hl]
            pop hl
            ld [de], a
            inc de
            inc hl
            dec b
            jr nz, .r
            ld a, l
            add a, 8
            ld l, a
            jr nc, .nc2
            inc h
.nc2:       dec c
            jr nz, .t
            xor a
            ld [$4000], a
            ld hl, T_BLANK * 16 + $8000     ; blank: colour 2
            ld b, 8
.bl:        xor a
            ld [hl+], a
            dec a
            ld [hl+], a
            dec b
            jr nz, .bl
            ld de, SM_CURG                  ; the cursor
            ld b, 8
.cu:        ld a, [de]
            inc de
            ld [hl+], a
            ld a, $FF
            ld [hl+], a
            dec b
            jr nz, .cu
            ldh a, [is_cgb]
            and a
            jr z, .dmg
            ld a, 1                         ; CGB: window attributes palette 7, bank 0
            ldh [$FF4F], a
            ld hl, $9C00
            ld bc, $400
.at:        ld a, 7
            ld [hl+], a
            dec bc
            ld a, b
            or c
            jr nz, .at
            xor a
            ldh [$FF4F], a
            ld a, $80 | 56                  ; BG palette 7: the NES $0F / $00 / $02 / $30
            ldh [$FF68], a
            ld de, SM_PALC
            ld b, 4
.pc:        ld a, [de]
            inc de
            add a, a
            ld l, a
            ld h, high(NES_RGB)
            ld a, [hl+]
            ldh [$FF69], a
            ld a, [hl]
            ldh [$FF69], a
            dec b
            jr nz, .pc
.dmg:       ld a, %00111011                 ; DMG / SGB: colours 0 / 2 black, 1 dark grey, 3 white
            ldh [$FF47], a
            call ui_clear
            ldh a, [is_sgb]                 ; SGB: one palette (white / greys / black) over
            and a                           ;   the whole screen (the field's packets are
            jr z, .nsgb                     ;   built again on the way out: sgb_force)
            ld hl, SM_SGBPAL
            call sgb_send
            ld b, 4
            call sgb_delay
            ld hl, SM_SGBATT
            call sgb_send
            ld b, 4
            call sgb_delay
.nsgb:      xor a
            ldh [$FF4A], a                  ; window at the top left
            ld a, 7
            ldh [$FF4B], a
            call ui_show
            ld a, $FF
            ldh [SM_PREV], a                ; (buttons held on entry count as held)
            ret

; leave: LCD off (in the V-Blank), window map back (DMG: tile 0; CGB: attributes $08, the
; mask), the slot cache emptied, palettes / OAM / SGB packets again, sound on; the LCD on
; again if the game had it on; interrupts on
ui_end:     ldh a, [$FF40]
            bit 7, a
            jr z, .off
.wv:        ldh a, [$FF44]
            cp 144
            jr c, .wv
            cp 152
            jr nc, .wv
            xor a
.lcdoff:    ldh [$FF40], a
.off:
            ld hl, $9C00
            ld bc, $400
.wm:        xor a
            ld [hl+], a
            dec bc
            ld a, b
            or c
            jr nz, .wm
            ldh a, [is_cgb]
            and a
            jr z, .dmg
            ld a, 1
            ldh [$FF4F], a
            ld hl, $9C00
            ld bc, $400
.wa:        ld a, $08
            ld [hl+], a
            dec bc
            ld a, b
            or c
            jr nz, .wa
            xor a
            ldh [$FF4F], a
.dmg:       ld hl, SPR_SLOT                 ; no sprite tile resident
            ld a, $FF
.s1:        ld [hl+], a
            inc l
            dec l
            jr nz, .s1
            ld hl, SLOT_TILE
            ld b, 128
.s2:        ld [hl+], a
            dec b
            jr nz, .s2
            ld hl, SLOT_KEY
            ld b, 128
.s3:        ld [hl+], a
            dec b
            jr nz, .s3
            xor a
            ldh [spr_next], a
            inc a
            ldh [pal_dirty], a
            ldh [oam_pending], a
            ld a, $FF
            ldh [sgb_dirty], a
            ldh [sgb_force], a
            ldh [$FF25], a                  ; sound on
            ld a, [VBL_CNT]                 ; (no frames to catch up)
            ld [VBL_SEEN], a
            ldh a, [lcd_on]
            and a
            jr z, .x
            ld a, LCDC_ON
            ldh [$FF40], a
.x:         ei
            ret

; window map blank (32 x 18), with the LCD off (in the V-Blank) until ui_show
ui_clear:   ldh a, [$FF40]
            bit 7, a
            jr z, .off
.wv:        ldh a, [$FF44]
            cp 144
            jr c, .wv
            cp 152
            jr nc, .wv
            xor a
.lcdoff:    ldh [$FF40], a
.off:       ld hl, $9C00
            ld bc, 32 * 18
.l:         ld a, T_BLANK
            ld [hl+], a
            dec bc
            ld a, b
            or c
            jr nz, .l
            ret

; the screen built: LCD on, the window over it (tiles $8000, map $9C00), BG under it
ui_show:    ld a, %11110001
            ldh [$FF40], a
            ret

; B, C = column, row -> HL = window map address. Keeps BC, DE.
ui_at:      ld a, c
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld a, l
            add a, b
            ld l, a
            ld a, h
            adc a, $9C
            ld h, a
            ret

; frame at B, C (column, row), D x E (width, height)
ui_box:     push bc
            call ui_at
            ld a, T_FRAME
            call .row
            pop bc
            push bc
            ld a, e
            sub 2
            ld e, a
.mid:       inc c
            push de
            call ui_at
            ld a, T_FRAME + 3
            ld [hl+], a
            ld a, d
            sub 2
            ld d, a
.m:         ld a, T_BLANK
            ld [hl+], a
            dec d
            jr nz, .m
            ld a, T_FRAME + 4
            ld [hl], a
            pop de
            dec e
            jr nz, .mid
            inc c
            call ui_at
            ld a, T_FRAME + 5
            call .row
            pop bc
            ret
.row:       ld [hl+], a                     ; A = left corner; the edge and right corner follow
            inc a
            push de
            ld e, a
            ld a, d
            sub 2
            ld d, a
            ld a, e
.e:         ld [hl+], a
            dec d
            jr nz, .e
            inc a
            ld [hl], a
            pop de
            ret

; text HL (tiles; $FE = next line, $FF = end) at B, C
ui_text:    push bc
.ln:        push hl
            call ui_at
            ld d, h
            ld e, l
            pop hl
.c:         ld a, [hl+]
            cp $FF
            jr z, .x
            cp $FE
            jr z, .nl
            ld [de], a
            inc de
            jr .c
.nl:        inc c
            jr .ln
.x:         pop bc
            ret

; A = 0-9 at B, C
ui_digit:   push af
            call ui_at
            pop af
            add a, SM_DIG0
            ld [hl], a
            ret

; cursor at column B, row C; the other rows of the A rows from row 1 cleared (column B)
ui_curs:    push bc
            ld e, a
            ld c, 1
.l:         call ui_at
            ld [hl], T_BLANK
            inc c
            dec e
            jr nz, .l
            pop bc
            call ui_at
            ld [hl], T_CUR
            ret

; up / down move SM_CUR within 0 .. B-1 (wrapping); A = this frame's presses
ui_updown:  ldh a, [SM_PREV + 1]
            bit 6, a
            jr nz, .up
            bit 7, a
            ret z
            ld a, [SM_CUR]
            inc a
            cp b
            jr c, .s
            xor a
            jr .s
.up:        ld a, [SM_CUR]
            and a
            jr nz, .u1
            ld a, b
.u1:        dec a
.s:         ld [SM_CUR], a
            ret

; 'Yes' / 'No' on row C (columns 3 / 10), cursor before them; A / B -> A = 0 Yes, 1 No
ui_yesno:   ld b, 3
            push bc
            ld hl, SMT_YES
            call ui_text
            pop bc
            push bc
            ld b, 10
            ld hl, SMT_NO
            call ui_text
            pop bc
            call ui_show
            xor a
            ld [SM_CUR], a
.l:         push bc
            ld b, 2                         ; clear both cursor spots, then the cursor
            call ui_at
            ld [hl], T_BLANK
            ld b, 9
            call ui_at
            ld [hl], T_BLANK
            ld a, [SM_CUR]
            and a
            ld b, 2
            jr z, .c
            ld b, 9
.c:         call ui_at
            ld [hl], T_CUR
            call ui_frame
            pop bc
            bit 1, a
            jr nz, .no
            bit 0, a
            jr nz, .pk
            and $30                         ; left / right
            jr z, .l
            ld a, [SM_CUR]
            xor 1
            ld [SM_CUR], a
            jr .l
.pk:        ld a, [SM_CUR]
            ret
.no:        ld a, 1
            ret

; one frame (LY 144 reached), then the buttons: A = new presses (A B Sel St R L U D = bits
; 0-7), also in SM_PREV + 1; SM_PREV = the buttons held
ui_frame:
.a:         ldh a, [$FF44]
            cp 144
            jr z, .a
.b:         ldh a, [$FF44]
            cp 144
            jr nz, .b
            ld a, $20
            ldh [$FF00], a
            ldh a, [$FF00]
            ldh a, [$FF00]
            cpl
            and $0F
            swap a
            ld b, a
            ld a, $10
            ldh [$FF00], a
            ldh a, [$FF00]
            ldh a, [$FF00]
            ldh a, [$FF00]
            cpl
            and $0F
            or b
            ld b, a
            ld a, $30
            ldh [$FF00], a
            ldh a, [SM_PREV]
            cpl
            and b
            ld c, a
            ld a, b
            ldh [SM_PREV], a
            ld a, c
            ldh [SM_PREV + 1], a
            ret

SM_CURG:    db $00, $20, $30, $38, $30, $20, $00, $00   ; the cursor (an arrow, colour 3 on 2)
SM_PALC:    db $0F, $00, $02, $30
SM_SGBPAL:  db $01                          ; PAL01: colour 0 white, palette 0 light grey /
            dw $7FFF, $56B5, $294A, $0000   ;   dark grey / black (BGP values = colours)
            dw $56B5, $294A, $0000
            db 0
SM_SGBATT:  db $21, $01, $07, $00, 0, 0, 19, 17   ; ATTR_BLK: the screen in palette 0
            db 0, 0, 0, 0, 0, 0, 0, 0

; ================================================================ suspend points
; Z = a suspend point of this model in the header
su_valid:   ld a, 3
            ld [$4000], a
            ld hl, SU_HDR
            ld a, [hl+]
            cp $53
            jr nz, .n
            ld a, [hl+]
            cp $55
            jr nz, .n
            ld a, [hl+]
            cp $53
            jr nz, .n
            ld a, [hl+]
            cp $50
            jr nz, .n
            call su_model
            cp [hl]
.n:         push af
            xor a
            ld [$4000], a
            pop af
            ret

su_model:   ldh a, [is_cgb]                 ; A = 1 + CGB * 2 + SGB
            add a, a
            ld b, a
            ldh a, [is_sgb]
            or b
            inc a
            ret

su_erase:   ld a, 3
            ld [$4000], a
            xor a
            ld [SU_HDR], a
            ld [$4000], a
            ret

; the snapshot's blocks, in stream order: kind, address, length, (cart RAM bank)
;   kind 0 memory, 1 VRAM bank 1 (CGB), 2 WRAM bank 2-7 (CGB, $D000), 3 cart RAM (bank)
SU_BLOCKS:  db 0
            dw $C000, $2000                 ; WRAM banks 0 / 1 (restored last)
            db 0
            dw $FF80, $007F                 ; HRAM
            db 0
            dw $8000, $2000                 ; VRAM bank 0
            db 1
            dw $8000, $2000                 ; VRAM bank 1 (CGB)
            db 2
            dw $D000, $6000                 ; WRAM banks 2-7 (CGB)
            db 3
            dw $A000, $0300                 ; NES $6000-$62FF
            db 0
            db 3
            dw $AF00, $1100                 ; NES $6F00-$7FFF
            db 0
            db 3
            dw $A000, $2000                 ; DMG tile shadows
            db 1
            db 3
            dw $B000, $1000                 ; DMG scan table
            db 3
            db $FF

; stream: SU_B = cart RAM bank, SU_P = pointer in $A000-$BFFF, SU_S = 16-bit sum
su_open:    ld a, SU_BANK0
            ld [SU_B], a
            ld hl, $A000
            ld a, l
            ld [SU_P], a
            ld a, h
            ld [SU_P + 1], a
            xor a
            ld [SU_S], a
            ld [SU_S + 1], a
            ret

; the stream's next byte position mapped: HL = pointer (cart RAM bank SU_B selected)
su_map:     ld a, [SU_B]
            ld [$4000], a
            ld a, [SU_P]
            ld l, a
            ld a, [SU_P + 1]
            ld h, a
            ret

; after a byte at HL: the stream pointer advanced (next bank at $C000), sum += A
su_adv:     push af
            ld a, [SU_S]
            ld b, a
            pop af
            push af
            add a, b
            ld [SU_S], a
            jr nc, .nc
            ld a, [SU_S + 1]
            inc a
            ld [SU_S + 1], a
.nc:        pop af
            inc hl
            ld a, h
            cp $C0
            jr nz, .st
            ld a, [SU_B]
            inc a
            ld [SU_B], a
            ld [$4000], a
            ld h, $A0
.st:        ld a, l
            ld [SU_P], a
            ld a, h
            ld [SU_P + 1], a
            ret

; SU_M = 0 save (memory -> stream), 1 load (stream -> memory), 2 sum only. One block: DE =
; address, BC = length, cart RAM bank in SM_TMP ($FF: not cart RAM). In chunks of up to 128
; bytes (not past the stream bank's end) through SU_BUF (the VRAM write queue's page, empty
; while the menu runs; WRAM itself is restored last).
SU_BUF     = $CD00
SU_N       = $CCD6          ; (chunk length)
su_block:   ld a, b
            or c
            ret z
            push bc
            ld a, b                         ; n = min(BC, 128, $C000 - pointer)
            and a
            ld a, 128
            jr nz, .n1
            ld a, c
            cp 128
            jr c, .n1
            ld a, 128
.n1:        ld b, a
            ld a, [SU_P + 1]
            cp $BF
            jr nz, .n2
            ld a, [SU_P]
            cpl
            inc a                           ; bytes left in the bank (1-256; 0 = 256)
            jr z, .n2
            cp b
            jr nc, .n2
            ld b, a
.n2:        ld a, b
            ld [SU_N], a
            ld a, [SU_M]
            and a
            jr z, .save
            dec a
            jr z, .load
            call su_map                     ; sum: the stream bytes
            ld a, [SU_N]
            ld b, a
            call su_addsum
            jr .adv
.save:      ld a, [SM_TMP]                  ; memory -> SU_BUF -> stream
            cp $FF
            jr z, .s1
            ld [$4000], a
.s1:        ld h, d
            ld l, e
            ld a, [SU_N]
            ld b, a
            push de
            ld de, SU_BUF
            call su_cp
            call su_map
            ld d, h
            ld e, l
            ld hl, SU_BUF
            ld a, [SU_N]
            ld b, a
            call su_cp
            pop de
            call su_map
            ld a, [SU_N]
            ld b, a
            call su_addsum
            jr .adv
.load:      call su_map                     ; stream -> SU_BUF -> memory
            ld a, [SU_N]
            ld b, a
            push de
            ld de, SU_BUF
            call su_cp
            ld a, [SM_TMP]
            cp $FF
            jr z, .l1
            ld [$4000], a
.l1:        pop de
            push de
            ld hl, SU_BUF
            ld a, [SU_N]
            ld b, a
            call su_cp
            pop de
.adv:       ld a, [SU_N]                    ; DE += n, stream pointer += n, BC -= n
            ld c, a
            add a, e
            ld e, a
            jr nc, .d1
            inc d
.d1:        ld a, [SU_P]
            add a, c
            ld [SU_P], a
            ld a, [SU_P + 1]
            adc a, 0
            cp $C0
            jr nz, .p1
            ld a, [SU_B]
            inc a
            ld [SU_B], a
            ld a, $A0
.p1:        ld [SU_P + 1], a
            pop hl                          ; (BC on entry)
            ld a, l
            sub c
            ld c, a
            ld a, h
            sbc a, 0
            ld b, a
            jr su_block

; B bytes (0 = 256) from HL to DE. Keeps nothing.
su_cp:      ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, su_cp
            ret

; SU_S += the B bytes at HL (stream bank mapped)
su_addsum:  push de
            ld a, [SU_S]
            ld e, a
            ld a, [SU_S + 1]
            ld d, a
.l:         ld a, [hl+]
            add a, e
            ld e, a
            jr nc, .nc
            inc d
.nc:        dec b
            jr nz, .l
            ld a, e
            ld [SU_S], a
            ld a, d
            ld [SU_S + 1], a
            pop de
            ret

; all blocks in mode SU_M (A = first block to do; WRAM banks 0 / 1 skipped when loading)
su_run:     call su_open
            ld hl, SU_BLOCKS
.b:         ld a, [hl+]
            cp $FF
            ret z
            ld [SU_M + 2], a                ; kind
            ld a, [hl+]
            ld e, a
            ld a, [hl+]
            ld d, a
            ld a, [hl+]
            ld c, a
            ld a, [hl+]
            ld b, a
            ld a, $FF
            ld [SM_TMP], a
            ld a, [SU_M + 2]
            cp 3
            jr nz, .k
            ld a, [hl+]
            ld [SM_TMP], a
.k:         push hl
            ld a, [SU_M + 2]
            and a
            jr nz, .k1
            ld a, d                         ; (loading: WRAM $C000 skipped here, done last)
            cp $C0
            jr nz, .go
            ld a, [SU_M]
            cp 1
            jr nz, .go
            call su_skip
            jr .nx
.k1:        dec a
            jr nz, .k2
            ldh a, [is_cgb]                 ; VRAM bank 1
            and a
            jr z, .nx
            ld a, 1
            ldh [$FF4F], a
            call su_block
            xor a
            ldh [$FF4F], a
            jr .nx
.k2:        dec a
            jr nz, .go
            ldh a, [is_cgb]                 ; WRAM banks 2-7: $1000 each
            and a
            jr z, .nx
            ld a, 2
.wb:        ldh [$FF70], a
            push af
            ld de, $D000
            ld bc, $1000
            call su_block
            pop af
            inc a
            cp 8
            jr nz, .wb
            ld a, 1
            ldh [$FF70], a
            jr .nx
.go:        call su_block
.nx:        pop hl
            jr .b

; skip BC bytes of the stream (sum only if mode 2)
su_skip:    ld a, [SU_M]
            push af
            ld a, 2
            ld [SU_M], a
            ld a, $FF
            ld [SM_TMP], a
            call su_block
            pop af
            ld [SU_M], a
            ret

; take the snapshot (from the menu, LCD on): A = 0 saved; A = 1 when the game is resumed
; from it later (su_load returns here)
su_save:    ld hl, sp + 0
            ld a, l
            ldh [SM_SPL], a
            ld a, h
            ldh [SM_SPH], a
.wv:        ldh a, [$FF44]                  ; LCD off (in the V-Blank)
            cp 144
            jr c, .wv
            cp 152
            jr nc, .wv
            xor a
.lcdoff:    ldh [$FF40], a
            call su_erase
            xor a
            ld [SU_M], a
            call su_run
            ld a, 3                         ; header: 'SUSP', model, SP, sum, check
            ld [$4000], a
            ld hl, SU_HDR + 4
            call su_model
            ld [hl+], a
            ldh a, [SM_SPL]
            ld [hl+], a
            ldh a, [SM_SPH]
            ld [hl+], a
            ld a, [SU_S]
            ld [hl+], a
            ld a, [SU_S + 1]
            ld [hl+], a
            ld hl, SU_HDR
            ld [hl], $53
            inc hl
            ld [hl], $55
            inc hl
            ld [hl], $53
            inc hl
            ld [hl], $50
            xor a
            ld [$4000], a
            ret

; Z = the snapshot's sum matches the header
su_sum:     ld a, 2
            ld [SU_M], a
            call su_open
            ld hl, SU_BLOCKS                ; (mode 2 reads every block, WRAM included)
            call su_run
            ld a, 3
            ld [$4000], a
            ld hl, SU_HDR + 7
            ld a, [SU_S]
            cp [hl]
            jr nz, .x
            inc hl
            ld a, [SU_S + 1]
            cp [hl]
.x:         push af
            xor a
            ld [$4000], a
            pop af
            ret

; restore the snapshot and return into su_save with A = 1 (LCD off, interrupts off)
su_load:    di
            ldh a, [$FF40]                  ; LCD off (in the V-Blank)
            bit 7, a
            jr z, .off
.wv:        ldh a, [$FF44]
            cp 144
            jr c, .wv
            cp 152
            jr nc, .wv
            xor a
.lcdoff:    ldh [$FF40], a
.off:       ld a, 3                         ; SP from the header (into the boot-stack bytes)
            ld [$4000], a
            ld a, [SU_HDR + 5]
            ld e, a
            ld a, [SU_HDR + 6]
            ld d, a
            ld a, 1
            ld [SU_M], a
            push de
            call su_run                     ; every block but WRAM banks 0 / 1
            pop de
            ld a, e                         ; (HRAM was restored: SP into $FFFC / $FFFD)
            ldh [SM_SPL], a
            ld a, d
            ldh [SM_SPH], a
            ld a, 1                         ; WRAM bank 1 for $D000
            ldh [$FF70], a
            ld a, SU_BANK0                  ; WRAM $C000-$DFFF = stream bank 4, no calls
            ld [$4000], a                   ;   (the stack is in it)
            ld hl, $C000
            ld de, $A000
.w:         ld a, [de]
            ld [hl+], a
            inc de
            ld a, h
            cp $E0
            jr nz, .w
            xor a
            ld [$4000], a
            ldh a, [SM_SPL]
            ld l, a
            ldh a, [SM_SPH]
            ld h, a
            ld sp, hl
            ld a, 1
            ret
