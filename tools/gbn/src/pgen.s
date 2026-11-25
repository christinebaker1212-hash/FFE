; FF1 native engine: party creation, the job picker and name entry (owner, 2026-11-25: proposals
; P-A, K-A and N of docs/ff1-job-screens-proposals.md). Our own code; the jobs' pictures and starting
; stats come from the user's ROM (UI_GFX), the strings and the letter grid from ui.pg_source().
;
; Party (P-A): a 'Light Warriors' header; one window with the four members, each its job's picture,
; the job on one line and the name below ('------' while it has none), the hand at the picture, as on
; the main menu; a hint row. Up / Down choose a member, A: the job picker, then name entry; after a
; name the hand moves to the next member without one; with all four named: 'OK to begin with this
; party?' (START asks it again after a B).
; Job picker (K-A): a 'Choose a Job' header, the six jobs' pictures in two rows of three, the chosen
; one marked by the hand, and below it the job's name, a line about it and its starting
; stats. The Control Pad moves, A takes the job, B goes back.
; Name entry (N): 'Name the' and the job above the name's six places ('Yura--'); the letters in pages
; shown as tabs (ABC abc 123: SELECT turns the page); END below them. A types (the sixth letter moves
; the hand to END) or, on END, finishes; B takes the last letter back (on no name: back to the jobs);
; START types a preset name when there is none, and moves the hand to END.
; Changes while the screen shows are copied to VRAM row by row in V-Blanks (pg_push), so the hand
; never blinks.

PG_BANK    = 110

section wram, $CDF2
jp_k:       ds 1                            ; the job picker's cursor
jp_old:     ds 1
pg_sj:      ds 1                            ; scratch: a job

section bank 110, $4000
; ---- party creation (called from the title's New Game: screens.s)
pg_main:
.reset:     ld hl, pg_class                 ; FF1's default party: Warrior, Thief, Monk, Red
            xor a                           ;   Magician, no names
.dc:        ld [hl+], a
            inc a
            cp 4
            jr c, .dc
            ld hl, pg_names
            ld b, 24
            ld a, $20
.n:         ld [hl+], a
            dec b
            jr nz, .n
            xor a
            ld [pg_mem], a
.mem:       call pa_screen
.ml:        call pa_cur
            call scr_frame
            ldh a, [pad_new]
            bit 0, a
            jr nz, .a
            bit 3, a
            jr nz, .st
            ld hl, pg_mem
            bit 6, a
            jr nz, .up
            bit 7, a
            jr z, .ml
            ld a, [hl]
            inc a
            and 3
            ld [hl], a
            jr .ml
.up:        ld a, [hl]
            dec a
            and 3
            ld [hl], a
            jr .ml
.st:        call pa_all                     ; START: all named, the question again
            jr z, .ask
            call sfx_err
            jr .ml
.a:         call pa_cls                     ; the member's job kept (a B in the picker
            ld a, [hl]                      ;   puts it back)
            ld [pg_old], a
.job:       call jp_main
            jr c, .mem                      ; (B: back to the party)
            call ne_main
            jr c, .job                      ; (B on no name: back to the jobs)
            call pa_all
            jr z, .ask
            call pa_next                    ; the next member without a name
            jr .mem
.ask:       call pa_screen
            call pa_ask
            jr c, .mem                      ; (B: back to the party)
            and a
            jr nz, .reset                   ; No: everything back to the default
            ret                             ; Yes

; HL = pg_class + member pg_mem
pa_cls:     ld a, [pg_mem]
            ld l, a
            ld h, 0
            ld de, pg_class
            add hl, de
            ret
; HL = pg_names + 6 x member A
pa_nmp:     ld l, a
            add a, a
            add a, l
            add a, a
            ld l, a
            ld h, 0
            ld de, pg_names
            add hl, de
            ret
; Z if all four have a name
pa_all:     xor a
.l:         push af
            call pa_nmp
            pop af
            ld e, a
            ld a, [hl]
            cp $20
            jr z, .no
            ld a, e
            inc a
            cp 4
            jr c, .l
            xor a                           ; Z: all named
            ret
.no:        or a                            ; (A = $20) NZ: one has no name
            ret
; pg_mem = the next member (after it, wrapping) with no name
pa_next:    ld a, [pg_mem]
            ld c, 3
.l:         inc a
            and 3
            push af
            call pa_nmp
            pop af
            ld b, a
            ld a, [hl]
            cp $20
            ld a, b
            jr z, .s
            dec c
            jr nz, .l
            ret
.s:         ld [pg_mem], a
            ret

; the party screen (LCD off; shown at the end)
pa_screen:  call scr_open
            call eqm_pal                    ; (the header's gold)
            xor a
            call scr_classes                ; the six jobs' standing poses: sprite tiles 0-35
            ld bc, $0000
            ld de, $1403
            call scr_win
            ld bc, $0301
            ld hl, pgs_hdr
            ld e, 14
            call gold_str
            ld bc, $0003                    ; the members (0,3,20,15)
            ld de, $140F
            call scr_win
            xor a
.m:         ld [pg_t], a
            call pa_line
            ld a, [pg_t]
            inc a
            cp 4
            jr c, .m
            ld bc, $0110                    ; the hint row
            ld hl, pgs_hint
            call scr_str
            jp scr_show
; member pg_t: job (row 4 + 3 m), name (row 5 + 3 m) from column 3, the picture at x 7
pa_line:    ld a, [pg_t]
            ld c, a
            add a, a
            add a, c
            add a, 4
            ld c, a
            ld b, 3
            push bc
            ld a, [pg_t]
            ld l, a
            ld h, 0
            ld de, pg_class
            add hl, de
            ld a, [hl]
            ld [pg_sj], a              ; (scratch: the job)
            call pg_jname
            call scr_str
            pop bc
            inc c
            push bc
            ld a, [pg_t]                    ; the name, or '------'
            call pa_nmp
            ld a, [hl]
            cp $20
            jr nz, .nm
            ld hl, pgs_none
            jr .p
.nm:        ld de, pg_nb
            ld b, 6
.c:         ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .c
            xor a
            ld [de], a
            ld hl, pg_nb
.p:         pop bc
            push bc
            call scr_str
            pop bc
            dec c                           ; the picture: x 7, y 8 (row 4 + 3 m)
            ld a, c
            add a, a
            add a, a
            add a, a
            ld c, a
            ld b, 7
            ld a, [pg_sj]
            call pg_pal
            ld a, [pg_sj]              ; tile base 6 x job
            ld e, a
            add a, a
            add a, e
            add a, a
            push af
            ld a, [pg_t]                    ; OAM entries 4 + 6 m
            ld e, a
            add a, a
            add a, e
            add a, a
            add a, 4
            ld e, a
            pop af
            jp scr_spr23
; scr_t0 = job A's sprite palette
pg_pal:     ld e, a
            ld d, 0
            ld hl, cls_pal
            add hl, de
            ld a, [hl]
            ld [scr_t0], a
            ret
; HL = job A's name (one line)
pg_jname:   add a, a
            ld l, a
            ld h, 0
            ld de, pgs_np
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ret
; the hand at member pg_mem's picture (its middle row; cut by the screen's edge, as the main menu)
pa_cur:     ld a, [pg_mem]
            ld c, a
            add a, a
            add a, c
            add a, 5
            add a, a
            add a, a
            add a, a
            ld c, a
            ld b, 7 - 10
            jp scr_cursor

; 'OK to begin with this party?' Yes / No over the list, the whole width (the two pictures under
; it hidden, their outlines covered): A = 0 Yes, 1 No (NC), C on B
pa_ask:     ld hl, oam_buf + 4 * 10         ; (members 1 and 2: OAM 10-21)
            ld b, 12 * 4
            xor a
.h:         ld [hl+], a
            dec b
            jr nz, .h
            ld bc, $0007
            ld de, $1406
            call scr_win
            ld bc, $0408
            ld hl, pgs_ok
            call scr_str
            ld bc, $0209
            ld hl, pgs_ok2
            call scr_str
            ld bc, $060B
            ld hl, pgs_yes
            call scr_str
            ld bc, $0D0B
            ld hl, pgs_no
            call scr_str
            call alt_upd
            ld bc, $070C
            call pg_push
            xor a
            ld [pg_t], a
.l:         ld a, [pg_t]
            and a
            ld b, 6
            jr z, .x
            ld b, 13
.x:         ld c, 11
            call cur_txt
            call scr_frame
            ldh a, [pad_new]
            bit 0, a
            jr nz, .a
            bit 1, a
            jr nz, .b
            and $30
            jr z, .l
            ld a, [pg_t]
            xor 1
            ld [pg_t], a
            jr .l
.a:         ld a, [pg_t]
            and a                           ; NC
            ret
.b:         scf
            ret

; rows B .. C of the map copy to VRAM now, each in a V-Blank's first lines with interrupts off
; (the screen's own refresh hides the hand while it runs); nothing while the LCD is off
pg_push:    call lcd_get
            bit 7, a
            ret z
.r:         push bc
.w:         ldh a, [rLY]
            cp 144
            jr c, .w
            cp 150
            jr nc, .w
            pop bc
            push bc
            ld a, b
            di
            call sf_one
            ei
            pop bc
            ld a, b
            inc b
            cp c
            jr c, .r
            ret

; ---- the job picker: NC with the member's job set, C on B (the job put back)
jp_main:    call scr_open
            call eqm_pal
            xor a
            call scr_classes                ; standing poses: tiles 0-35
            ld bc, $0000
            ld de, $1403
            call scr_win
            ld bc, $0401
            ld hl, pgs_jhdr
            ld e, 12
            call gold_str
            ld bc, $0003                    ; the pictures (0,3,20,9)
            ld de, $1409
            call scr_win
            call pa_cls                     ; the cursor on the member's job
            ld a, [hl]
            ld [jp_k], a
            xor a
.p:         ld [jp_old], a
            call jp_pic
            ld a, [jp_old]
            inc a
            cp 6
            jr c, .p
            call jp_info
            call scr_show
.l:         ld a, [jp_k]                    ; the hand at the picture's middle row
            call jp_xy
            inc c
            call cur_txt
            call scr_frame
            ldh a, [pad_new]
            bit 0, a
            jr nz, .a
            bit 1, a
            jr nz, .b
            ld b, a
            ld a, [jp_k]
            ld [jp_old], a
            ld c, a
            bit 4, b                        ; right: the next in the row (wrapping)
            jr z, .nr
            ld a, c
            cp 2
            jr z, .r0
            cp 5
            jr z, .r0
            inc a
            jr .mv
.r0:        sub 2
            jr .mv
.nr:        bit 5, b                        ; left
            jr z, .nl
            ld a, c
            and a
            jr z, .l0
            cp 3
            jr z, .l0
            dec a
            jr .mv
.l0:        add a, 2
            jr .mv
.nl:        ld a, b
            and $C0                         ; up / down: the other row
            jr z, .l
            ld a, c
            add a, 3
            cp 6
            jr c, .mv
            sub 6
.mv:        ld [jp_k], a
            call jp_info                    ; (the pictures stay: a pose change rebuilt every
            call alt_upd                    ;   outline cell with the LCD on, ~30 frames; gold
            ld bc, $0B11                    ;   glyphs on DMG / SGB)
            call pg_push
            jr .l
.a:         call pa_cls
            ld a, [jp_k]
            ld [hl], a
            and a                           ; NC
            ret
.b:         call pa_cls
            ld a, [pg_old]
            ld [hl], a
            scf
            ret
; A = job -> B = its picture's column (3, 9, 15), C = its top row (4, 8)
jp_xy:      ld c, 4
            cp 3
            jr c, .r
            sub 3
            ld c, 8
.r:         ld b, a
            add a, a
            add a, b
            add a, a
            add a, 3
            ld b, a
            ret
; job A's picture, OAM entries 4 + 6 A
jp_pic:     ld [pg_sj], a
            call jp_xy
            ld a, b
            add a, a
            add a, a
            add a, a
            ld b, a
            ld a, c
            add a, a
            add a, a
            add a, a
            ld c, a
            ld a, [pg_sj]
            push bc
            call pg_pal
            pop bc
            ld a, [pg_sj]
            ld e, a
            add a, a
            add a, e
            add a, a                        ; 6 A
            ld d, a
            add a, 4
            ld e, a
            ld a, d
            jp scr_spr23
; the job's window (0,11,20,7): name (gold), its line, the starting stats (into the map copy)
jp_info:    ld bc, $000B
            ld de, $1407
            call scr_win
            ld a, [jp_k]
            call pg_jname
            push hl
            ld e, 0                         ; (its length: the gold cells)
.ln:        ld a, [hl+]
            and a
            jr z, .lz
            inc e
            jr .ln
.lz:        pop hl
            ld bc, $010C
            call gold_str
            ld a, [jp_k]
            add a, a
            ld l, a
            ld h, 0
            ld de, pgs_dp
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld bc, $010D
            call scr_str
            ld bc, $010E
            ld hl, pgs_lab1
            call scr_str
            ld bc, $0A0E
            ld hl, pgs_lab2
            call scr_str
            ld a, [jp_k]                    ; the job's starting record (FF1: class, HP, Str,
            swap a                          ;   Agi, Int, Vit, Luck)
            ld l, a
            ld h, 0
            ld de, U_STATS
            add hl, de
            ld de, scr_buf
            ld bc, 16
            ld a, UI_GFX
            call far_copy
            ld hl, jp_num
            ld de, scr_buf + 1
            ld b, 6
.n:         push bc
            ld a, [hl+]                     ; column, row
            ld b, a
            ld a, [hl+]
            ld c, a
            ld a, [de]
            inc de
            push hl
            push de
            call pg_num2
            pop de
            pop hl
            pop bc
            dec b
            jr nz, .n
            ret
jp_num:     db 5, 14, 14, 14, 5, 15, 14, 15, 5, 16, 14, 16   ; HP, Str, Agi, Int, Vit, Luck
; A (0-99) as two digits (a blank tens) at column B, row C
pg_num2:    push bc
            ld c, 0
.t:         cp 10
            jr c, .o
            sub 10
            inc c
            jr .t
.o:         add a, FONT_D0
            ld [pg_nb + 1], a
            ld a, c
            and a
            ld a, $20
            jr z, .b
            ld a, c
            add a, FONT_D0
.b:         ld [pg_nb], a
            xor a
            ld [pg_nb + 2], a
            pop bc
            ld hl, pg_nb
            jp scr_str

; ---- name entry for member pg_mem (job from pg_class): NC named, C on B with no name
ne_main:    call scr_open
            call eqm_pal
            ld bc, $0000
            ld de, $1405
            call scr_win
            ld bc, $0004
            ld de, $140E
            call scr_win
            call pa_cls                     ; the job: its picture, 'Name the', its name
            ld a, [hl]
            ld [eqm_cls], a
            call scr_classes                ; (its standing pose: tiles 0-5)
            ld a, [eqm_cls]
            call pg_pal
            ld bc, $0808
            ld e, 4
            xor a
            call scr_spr23
            ld bc, $0401
            ld hl, pgs_nm
            call scr_str
            ld a, [eqm_cls]
            call pg_jname
            ld bc, $0402
            call scr_str
            ld a, [pg_mem]                  ; the name cleared
            call pa_nmp
            ld b, 6
            ld a, $20
.cl:        ld [hl+], a
            dec b
            jr nz, .cl
            xor a
            ld [ni_len], a
            ld [ni_x], a
            ld [ni_y], a
            ld [ni_pre], a
            ld [ni_case], a
            call ne_grid
            ld bc, $0F10                    ; END
            ld hl, pgs_end
            call scr_str
            call ne_name
            call scr_show
.lp:        call ne_cur
            call scr_frame
            ldh a, [pad_new]
            bit 0, a
            jr nz, .a
            bit 1, a
            jp nz, .b
            bit 3, a
            jp nz, .st
            bit 2, a
            jr z, .ns
            ld a, [ni_case]                 ; SELECT: the next page
            inc a
            cp 3
            jr c, .sc
            xor a
.sc:        ld [ni_case], a
            call ne_grid
            call alt_upd
            ld bc, $050F
            call pg_push
            jr .lp
.ns:        ld hl, ni_x
            ld b, a
            ld a, [ni_y]
            cp 5
            ld a, b
            jr z, .ud                       ; (on END: up / down only)
            bit 4, a                        ; right / left: the next letter (wrapping)
            jr z, .nr
            ld a, [hl]
            inc a
            cp 6
            jr c, .sx
            xor a
.sx:        ld [hl], a
            jr .lp
.nr:        bit 5, a
            jr z, .ud
            ld a, [hl]
            dec a
            cp 6
            jr c, .sx
            ld a, 5
            jr .sx
.ud:        ld hl, ni_y                     ; up / down: five rows and END
            bit 6, a
            jr z, .nu
            ld a, [hl]
            dec a
            cp 6
            jr c, .sy
            ld a, 5
.sy:        ld [hl], a
            jr .lp
.nu:        bit 7, a
            jr z, .lp
            ld a, [hl]
            inc a
            cp 6
            jr c, .sy
            xor a
            jr .sy
.a:         ld a, [ni_y]                    ; A on END: done (a name of one letter or more)
            cp 5
            jr nz, .al
            ld a, [ni_len]
            and a
            jr z, .er
            xor a
            ld [ni_pre], a
            and a                           ; NC
            ret
.er:        call sfx_err
            jp .lp
.al:        ld a, [ni_len]                  ; a letter (six at most)
            cp 6
            jr nc, .er
            ld a, [ni_y]
            ld b, a
            ld a, [ni_x]
            call ne_char
            cp $20
            jr z, .er
            ld c, a
            xor a                           ; (typed: not a preset name any more)
            ld [ni_pre], a
            ld a, [pg_mem]
            call pa_nmp
            ld a, [ni_len]
            add a, l
            ld l, a
            ld a, h
            adc a, 0
            ld h, a
            ld [hl], c
            ld a, [ni_len]
            inc a
            ld [ni_len], a
            cp 6                            ; (the sixth: the hand to END)
            jr c, .an
            ld a, 5
            ld [ni_y], a
.an:        call ne_name
            jp .lp
.b:         ld a, [ni_pre]                  ; B: a preset name goes whole, else the last letter;
            and a                           ;   no name: back to the jobs
            jr nz, .bp
            ld a, [ni_len]
            and a
            jr z, .back
            dec a
            ld [ni_len], a
            ld b, a
            ld a, [pg_mem]
            call pa_nmp
            ld a, b
            add a, l
            ld l, a
            ld a, h
            adc a, 0
            ld h, a
            ld [hl], $20
            call ne_name
            jp .lp
.back:      scf
            ret
.bp:        xor a
            ld [ni_pre], a
            ld [ni_len], a
            ld a, [pg_mem]
            call pa_nmp
            ld b, 6
            ld a, $20
.bc:        ld [hl+], a
            dec b
            jr nz, .bc
            call ne_name
            jp .lp
.st:        ld a, [ni_len]                  ; START: a preset name when there is none (owner,
            and a                           ;   2026-11-25: extras.s), then the hand to END
            jr nz, .se
            ld a, EXTRA_BANK
            ld hl, ni_preset
            call bank_call
            call ne_name
.se:        ld a, 5
            ld [ni_y], a
            jp .lp

; A = column (0-5), B = row (0-4) of the page ni_case -> A = its letter
ne_char:    ld c, a
            ld a, [ni_case]                 ; 30 x page + 6 x row + column
            ld e, a
            add a, a
            add a, a
            add a, a
            add a, a                        ; 16
            sub e
            sub e                           ; 14
            add a, a                        ; 28
            add a, e
            add a, e                        ; 30
            ld e, a
            ld a, b
            add a, a
            add a, b
            add a, a
            add a, c
            add a, e
            ld e, a
            ld d, 0
            ld hl, pgs_grid
            add hl, de
            ld a, [hl]
            ret
; the tabs (row 5: the page's in gold) and the page's five rows (rows 6, 8 .. 14, columns 3, 6
; .. 18), into the map copy
ne_grid:    ld bc, $0305                    ; tabs at columns 3, 9, 15
            ld hl, pgs_tab0
            call scr_str
            ld bc, $0905
            ld hl, pgs_tab1
            call scr_str
            ld bc, $0F05
            ld hl, pgs_tab2
            call scr_str
            ld hl, sattr + 5 * 32 + 3       ; their colours: the page's gold, the others plain
            ld c, 0
.tb:        ld a, [ni_case]
            cp c
            ld a, WIN_ATTR
            jr nz, .tw
            ld a, $0B
.tw:        ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld de, 3
            add hl, de
            inc c
            ld a, c
            cp 3
            jr c, .tb
            xor a
.g:         push af
            ld d, a                         ; (D = the row)
            ld hl, pg_row
            xor a
.x:         push af
            push hl
            push de
            ld b, d
            call ne_char
            pop de
            pop hl
            ld [hl+], a
            pop af
            inc a
            cp 6
            jr nc, .e
            ld [hl], $20
            inc hl
            ld [hl], $20
            inc hl
            jr .x
.e:         ld [hl], 0
            pop af
            push af
            add a, a
            add a, 6
            ld c, a
            ld b, 3
            ld hl, pg_row
            call scr_str
            pop af
            inc a
            cp 5
            jr c, .g
            ret
; the name's six places on row 3 ('Yura--'), to VRAM when the screen shows
ne_name:    ld a, [pg_mem]
            call pa_nmp
            ld de, pg_nb
            ld b, 6
            ld a, [ni_len]
            ld c, a
.c:         ld a, c
            and a
            ld a, [hl+]
            jr nz, .k
            ld a, '-'
.k:         ld [de], a
            inc de
            ld a, c
            and a
            jr z, .z
            dec c
.z:         dec b
            jr nz, .c
            xor a
            ld [de], a
            ld hl, pg_nb
            ld bc, $0403
            call scr_str
            ld bc, $0303
            jp pg_push
; the hand: before the letter at (column 3 + 3 x, row 6 + 2 y), or before END (column 15, row 16)
ne_cur:     ld a, [ni_y]
            cp 5
            jr nz, .g
            ld bc, $0F10
            jp cur_txt
.g:         add a, a
            add a, 6
            ld c, a
            ld a, [ni_x]
            ld b, a
            add a, a
            add a, b
            add a, 3
            ld b, a
            jp cur_txt
