; The field's dialogue box: FF3's window 0 (the top window) as the GB's window layer, rows 0-7
; (frame, 6 lines of 18 letters, frame), cut at line 64 by a line interrupt; text typed a
; letter at a time (FF1's typewriter text, A speeds it up), pages turned with A. Text tables:
; tools/gb3n/text.py (index in B_TEXT: bank, address per string).

TXT_BUF    = $D600          ; the string being shown (work RAM bank 1)
WIN_MAP    = $9C00
DLG_ROWS   = 8
DLG_CUT    = DLG_ROWS * 8 - 1
TYPE_RATE  = 3              ; frames per letter (A held: every frame)
TB_STORY   = 0              ; text tables (text.py TABLES)
TB_SYSTEM  = 1
TB_DLG1    = 2
TB_DLG2    = 3
TB_NAMES   = 4
FR_TL      = $F7            ; FF3's window frame tiles ($3F $EDF6)
FR_T       = $F8
FR_TR      = $F9
FR_L       = $FA
FR_R       = $FB
FR_BL      = $FC
FR_B       = $FD
FR_BR      = $FE
ATTR_FRAME = $03            ; palette 3 (FF3's window colours), VRAM bank 0
ATTR_TEXT  = $0B            ; palette 3, VRAM bank 1 (our font)

section bank B_FIELD, $6400
; ---- the window map's dialogue box (LCD off, once): frame and blank text cells
win_init:   xor a
            ldh [rVBK], a
            ld hl, WIN_MAP
            ld a, FR_TL
            ld [hl+], a
            ld b, 18
            ld a, FR_T
.t:         ld [hl+], a
            dec b
            jr nz, .t
            ld a, FR_TR
            ld [hl+], a
            ld l, $20
            ld c, 6
.r:         ld a, FR_L
            ld [hl+], a
            ld b, 18
            ld a, $20
.s:         ld [hl+], a
            dec b
            jr nz, .s
            ld a, FR_R
            ld [hl+], a
            ld a, l
            add 12
            ld l, a
            jr nc, .rn
            inc h
.rn:        dec c
            jr nz, .r
            ld a, FR_BL
            ld [hl+], a
            ld b, 18
            ld a, FR_B
.b:         ld [hl+], a
            dec b
            jr nz, .b
            ld a, FR_BR
            ld [hl], a
            ld a, 1                         ; attributes: frame in bank 0, text cells in bank 1
            ldh [rVBK], a
            ld hl, WIN_MAP
            ld c, DLG_ROWS
.ar:        ld b, 20
.ac:        ld a, l
            and 31
            jr z, .fr
            cp 19
            jr z, .fr
            ld a, c
            cp DLG_ROWS
            jr z, .fr
            cp 1
            jr z, .fr
            ld a, ATTR_TEXT
            jr .aw
.fr:        ld a, ATTR_FRAME
.aw:        ld [hl+], a
            dec b
            jr nz, .ac
            ld a, l
            add 12
            ld l, a
            jr nc, .an
            inc h
.an:        dec c
            jr nz, .ar
            xor a
            ldh [rVBK], a
            ld a, 7                         ; window at the top left
            ldh [rWX], a
            xor a
            ldh [rWY], a
            ret

; ---- open the dialogue box with string C of table B
dlg_open:   ld a, b
            ld hl, txt_tables
            add a
            add l
            ld l, a
            jr nc, .t
            inc h
.t:         ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld b, 0                         ; HL = index + 3 * C
            add hl, bc
            add hl, bc
            add hl, bc
            ld de, dlg_src
            ld bc, 3
            ld a, B_TEXT
            call far_copy
            ld a, [dlg_src + 1]             ; the string into TXT_BUF (1.5 KB, not past the bank)
            ld l, a
            ld a, [dlg_src + 2]
            ld h, a
            ld a, l
            cpl
            ld c, a
            ld a, h
            cpl
            and $7F
            ld b, a
            inc bc
            ld a, b
            cp 6
            jr c, .sz
            ld bc, $600
.sz:        ld de, TXT_BUF
            ld a, [dlg_src]
            call far_copy
            xor a
            ld [TXT_BUF + $5FF], a
.cd:        ld a, [TXT_BUF]                 ; an empty string shows nothing
            and a
            ret z
            ld hl, TXT_BUF
            ld a, l
            ld [dlg_ptr], a
            ld a, h
            ld [dlg_ptr + 1], a
            xor a
            ld [dlg_col], a
            ld [dlg_row], a
            ld [dlg_ins], a
            ld [dlg_timer], a
            ld a, 1
            ld [dlg_clear], a               ; clear the text cells (V-Blank), then type
            ld [dlg_on], a
            ld a, DLG_TYPE
            ld [dlg_state], a
            ret
txt_tables: dw T_T8000, T_T8200, T_T8400, T_T8600, T_NAMES8800

DLG_TYPE   = 1
DLG_PAGE   = 2
DLG_END    = 3

; ---- one frame of the dialogue (main loop, while dlg_on)
dlg_step:   ld a, [dlg_clear]
            and a
            ret nz                          ; (the clear first)
            ld a, [dlg_state]
            cp DLG_TYPE
            jr z, .type
            ldh a, [pad_new]                ; page / end: wait for A
            and PAD_A
            ret z
            ld a, [dlg_state]
            cp DLG_END
            jr z, .close
            xor a
            ld [dlg_col], a
            ld [dlg_row], a
            inc a
            ld [dlg_clear], a
            ld a, DLG_TYPE
            ld [dlg_state], a
            ret
.close:     xor a
            ld [dlg_on], a
            ld [dlg_state], a
            ret
.type:      ldh a, [pad]                    ; the pace: a letter every TYPE_RATE frames, every
            and PAD_A                       ;   frame while A is held
            jr nz, .now
            ld a, [dlg_timer]
            inc a
            ld [dlg_timer], a
            cp TYPE_RATE
            ret c
.now:       xor a
            ld [dlg_timer], a
.next:      ld a, [dlg_ins]                 ; inside an inserted name: its next letter
            and a
            jr z, .str
            ld hl, dlg_insbuf
            ld a, [dlg_insi]
            add l
            ld l, a
            ld a, [hl]
            ld hl, dlg_insi
            inc [hl]
            ld hl, dlg_ins
            dec [hl]
            jr .put
.str:       ld a, [dlg_ptr]
            ld l, a
            ld a, [dlg_ptr + 1]
            ld h, a
            ld a, [hl+]
            ld b, a
            ld a, l
            ld [dlg_ptr], a
            ld a, h
            ld [dlg_ptr + 1], a
            ld a, b
            and a
            jr z, .end
            cp $0A
            jr z, .nl
            cp $0C
            jr z, .pg
            cp $02
            jr c, .next
            cp $05
            jr nc, .cd
            call dlg_value                  ; an item's name / an amount
            jr .next
.cd:        cp $10
            jr c, .next                     ; (other codes: none in the field's text)
            cp $18
            jr nc, .put
            call dlg_insert                 ; a member's name / job
            jr .next
.put:       ld b, a                         ; a letter at (col + 1, row + 1)
            ld a, [dlg_col]
            cp 18
            ret nc
            inc a
            ld c, a
            ld [dlg_col], a
            ld a, [dlg_row]
            inc a
            swap a
            add a
            add c
            ld l, a
            ld h, high(WIN_MAP)
            jr nc, .pa
            inc h
.pa:        ld a, l
            ld [dlg_cell], a
            ld a, h
            ld [dlg_cell + 1], a
            ld a, b
            ld [dlg_cell + 2], a
            ret
.nl:        xor a
            ld [dlg_col], a
            ld hl, dlg_row
            inc [hl]
            ret
.pg:        ld a, DLG_PAGE
            ld [dlg_state], a
            ret
.end:       ld a, DLG_END
            ld [dlg_state], a
            ret

; a code $10-$13 (member's name) or $14-$17 (job: shown as the name for now) -> dlg_insbuf
dlg_insert: and 3
            swap a
            add a
            add a
            add low(SRAM_PAGE + $106)
            ld l, a
            ld h, high(SRAM_PAGE + $106)
            ld de, dlg_insbuf
            ld c, 0
            ld b, 6
.c:         ld a, [hl+]
            cp $FF
            jr z, .d
            push hl
            ld l, a
            ld h, 0
            push de
            ld de, C_FF3ASC
            add hl, de
            pop de
            ld a, B_OWN
            call far_byte
            pop hl
            ld [de], a
            inc de
            inc c
            dec b
            jr nz, .c
.d:         ld a, c
            ld [dlg_ins], a
            xor a
            ld [dlg_insi], a
            ret

; code $02: the name of item dlg_item; $03 / $04: the amount dlg_num (24 bits) -> dlg_insbuf
dlg_value:  cp $02
            jr nz, .num
            ld a, [dlg_item]                ; the name table's entry (B_TEXT index 4)
            ld c, a
            ld b, 0
            ld hl, T_NAMES8800
            add hl, bc
            add hl, bc
            add hl, bc
            ld de, dlg_src
            ld bc, 3
            ld a, B_TEXT
            call far_copy
            ld a, [dlg_src + 1]
            ld l, a
            ld a, [dlg_src + 2]
            ld h, a
            ld de, dlg_insbuf
            ld bc, 24
            ld a, [dlg_src]
            call far_copy
            ld hl, dlg_insbuf
            ld c, 0
.n:         ld a, [hl+]
            and a
            jr z, .nd
            inc c
            ld a, c
            cp 23
            jr c, .n
.nd:        ld a, c
            ld [dlg_ins], a
            xor a
            ld [dlg_insi], a
            ret
.num:       ld hl, dlg_num                  ; decimal digits of the 24-bit amount (C:D:E)
            ld a, [hl+]
            ld e, a
            ld a, [hl+]
            ld d, a
            ld c, [hl]
            xor a
            ld [dlg_ins], a
            ld hl, dlg_insbuf + 23
.dv:        xor a                           ; C:D:E / 10, the remainder in A
            ld b, 24
.db:        sla e
            rl d
            rl c
            rla
            cp 10
            jr c, .dk
            sub 10
            inc e
.dk:        dec b
            jr nz, .db
            add $30
            dec hl
            ld [hl], a
            ld a, [dlg_ins]
            inc a
            ld [dlg_ins], a
            ld a, c
            or d
            or e
            jr nz, .dv
            ld a, [dlg_ins]                 ; the digits down to dlg_insbuf
            ld b, a
            ld de, dlg_insbuf
.mv:        ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .mv
            xor a
            ld [dlg_insi], a
            ret

; ---- V-Blank: the dialogue's VRAM writes (a letter, or clearing the text cells)
dlg_vbl:    ld a, [dlg_clear]
            and a
            jr z, .cell
            xor a                           ; the 6 x 18 text cells blank
            ldh [rVBK], a
            ld [dlg_clear], a
            ld hl, WIN_MAP + $21
            ld c, 6
.r:         ld b, 18
            ld a, $20
.s:         ld [hl+], a
            dec b
            jr nz, .s
            ld a, l
            add 14
            ld l, a
            jr nc, .n
            inc h
.n:         dec c
            jr nz, .r
            ret
.cell:      ld a, [dlg_cell + 1]
            and a
            ret z
            ld h, a
            ld a, [dlg_cell]
            ld l, a
            ld a, [dlg_cell + 2]
            ld [hl], a
            xor a
            ld [dlg_cell + 1], a
            ret

; the window shown from the top to line DLG_CUT while the dialogue is open (V-Blank)
dlg_lcdc:   ld a, [dlg_on]
            and a
            jr nz, .on
            ldh [rSTAT], a
            ld a, LCDC_ON
            jr .w
.on:
            ld a, DLG_CUT
            ldh [rLYC], a
            ld a, $40                       ; LYC interrupt
            ldh [rSTAT], a
            ld a, LCDC_WIN
.w:         ldh [rLCDC], a
            ret

section wram, $C220
dlg_on:     ds 1
dlg_state:  ds 1
dlg_ptr:    ds 2
dlg_col:    ds 1
dlg_row:    ds 1
dlg_timer:  ds 1
dlg_clear:  ds 1
dlg_cell:   ds 3
dlg_ins:    ds 1
dlg_insi:   ds 1
dlg_insbuf: ds 24
dlg_item:   ds 1
dlg_num:    ds 3
dlg_src:    ds 3

section bank 0, $0E00
; line DLG_CUT: the window off from the next line (written in this line's H-Blank)
stat_isr:   push af
            ld a, [guard_on]                ; a guarded load: hold until H-Blank
            and a
            jr nz, .w
.w:         ldh a, [rSTAT]
            and 3
            jr nz, .w
            ld a, [guard_on]
            and a
            jr nz, .x
            ldh a, [rLCDC]
            and $DF
            ldh [rLCDC], a
.x:         pop af
            reti

