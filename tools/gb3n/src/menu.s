; ---- field menus (FF3 3D/A52F main menu) on the GB: the window layer over the whole screen (the
; field's BG map, tiles and palettes 0-3 stay as they are: closing shows the field at once, no
; white frame, no palette change); the menu's palettes in CGB palettes 4-7 (fix:E1BC), its own
; tiles in VRAM bank 1 (NPC tiles borrowed while it shows), the canvas built in WRAM bank 2 and
; copied by DMA in one V-Blank. Layout: the owner-approved mock N5B / N6 (tools/gb3n/menu.py).
MC_MAP     = $D000              ; canvas (WRAM bank 2): 32 x 18 tile codes
MC_ATTR    = $D400              ;   and attributes
MP_T       = $70                ; VRAM bank 1 tiles: MP digits "0/".."9/", "0".."9"
JOB_T      = $20                ;   job names, 12 a member
SN_T       = $84                ;   small numbers (gil, capacity): 12
PAL_TXT    = $07                ; attributes: palette 7 (window / white text), bank 0 tiles
PAL_HP     = $04                ;   palette 4 (green HP; 5 orange, 6 pink)

section bank 0, $3800
; Start on the field (fix:E340)
menu_open:  call oam_hide
            ld a, MENU_BANK                 ; palettes: menu BG 0-3 -> CGB 4-7, OBJ likewise
            ld [MBC5_BANKL], a
            ld hl, $5340
            ld de, pal_sh + 32
            ld bc, 32
            call memcpy
            ld hl, $5360
            ld de, pal_sh + 96
            ld bc, 32
            call memcpy
            ld a, 1
            ldh [pal_dirty], a
            ld a, MENU_BANK                 ; tiles: MP digits, cursor
            ld [MBC5_BANKL], a
            ld hl, $5100
            ld de, $8000 + 16 * MP_T
            ld b, 20
            ld a, 1
            call vcopy
            ld a, MENU_BANK
            ld [MBC5_BANKL], a
            ld hl, $5400
            ld de, $8E00
            ld b, 32
            ld a, 1
            call vcopy
            xor a                           ; the members' job names
            ld [m_i], a
.jn:        ld a, [m_i]
            rrca
            rrca
            ld l, a
            ld h, high(GS + $100)
            ld a, [hl]                      ; job
            ld c, a                         ; MENU_BANK $4000 + 192 job
            ld b, 0
            ld h, b
            ld l, c
            add hl, hl
            add hl, bc                      ; 3 job
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl                      ; 192 job
            ld de, $4000
            add hl, de
            ld a, [m_i]                     ; -> tile JOB_T + 12 m
            ld e, a
            add a, a
            add a, e
            add a, a
            add a, a                        ; 12 m
            add a, JOB_T
            swap a
            ld e, a
            and $F0
            ld d, a
            ld a, e
            and $0F
            add a, $80
            ld e, d
            ld d, a
            ld a, MENU_BANK
            ld [MBC5_BANKL], a
            ld b, 12
            ld a, 1
            call vcopy
            ld hl, m_i
            inc [hl]
            ld a, [hl]
            cp 4
            jr nz, .jn
            ld a, 2                         ; the canvas
            ldh [rSVBK], a
            call mm_draw
            ld a, 1
            ld [m_dirty], a
            ld [menu_on], a
            call wait_vbl
            xor a
            ld [m_cur], a
; the main menu loop (3D/A5A9)
mm_loop:    call mm_cursor
            call wait_vbl
            call read_pad
            call m_keys
            ld a, [m_new]
            bit 1, a
            jr nz, menu_close
            bit 6, a                        ; up / down: the command (7, wrapping)
            jr z, .d
            ld a, [m_cur]
            dec a
            cp $FF
            jr nz, .s
            ld a, 6
            jr .s
.d:         bit 7, a
            jr z, mm_loop
            ld a, [m_cur]
            inc a
            cp 7
            jr nz, .s
            xor a
.s:         ld [m_cur], a
            jr mm_loop

; B (3D/A646): the window off, the NPC tiles back, the field as it was
menu_close: call oam_hide
            call wait_vbl
            ld a, 1
            ldh [rSVBK], a
            call npc_gfx
            ld a, SPR_BANK                  ; (the party's tiles too)
            ld [MBC5_BANKL], a
            ld hl, $4000
            ld de, $8000
            ld b, 16
            ld a, 1
            call vcopy
            xor a
            ld [menu_on], a
            jp wait_vbl

; new presses with FF3's cursor repeat (3C/9175: the same direction again after 16 frames)
m_keys:     ldh a, [pad]
            ld b, a
            ld a, [m_old]
            cpl
            and b
            ld c, a
            ld a, b
            ld [m_old], a
            and $F0
            jr z, .nr
            ld hl, m_rep
            inc [hl]
            ld a, [hl]
            cp 16
            jr c, .out
            ld [hl], 12                     ; (then every 4 frames)
            ld a, b
            and $F0
            or c
            ld c, a
            jr .out
.nr:        xor a
            ld [m_rep], a
.out:       ld a, c
            ld [m_new], a
            ret

; the hand at the command (FD5EB: tiles $E4 +, frame 3E/DCF2, palette 3 -> OBJ 7)
mm_cursor:  ld a, [m_cur]
            add a, a
            add a, a
            add a, a
            add a, 16 + 8 - 4
            ld c, a                         ; y = row (1 + cur) 8
            ld b, 8 + 12 * 8 + 2            ; x: left of the words (column 12.25)
cursor_at:  ld hl, oam_buf
            ld a, MENU_BANK
            ld [MBC5_BANKL], a
            ld de, $5640
            call .one                       ; TL
            ld a, c
            add a, 8
            ld c, a
            call .one                       ; BL
            ld a, b
            add a, 8
            ld b, a
            ld a, c
            sub 8
            ld c, a
            call .one                       ; TR
            ld a, c
            add a, 8
            ld c, a
.one:       ld a, c
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

oam_hide:   ld hl, oam_buf
            ld b, 40
            xor a
.l:         ld [hl+], a
            inc l
            inc l
            inc l
            dec b
            jr nz, .l
            ret

; ---- the main menu canvas (N5B / N6)
mm_draw:    call m_clear
            ld bc, $0000                    ; party window
            ld de, $0D12
            call m_box
            ld bc, $0D00                    ; commands
            ld de, $0709
            call m_box
            ld bc, $0D09                    ; gil / capacity
            ld de, $0704
            call m_box
            ld bc, $0D0D                    ; guest
            ld de, $0705
            call m_box
            ld a, MENU_BANK                 ; the command words (t8200 $0131)
            ld [MBC5_BANKL], a
            ld hl, $5600
            ld bc, $0E01
.cw:        push bc
            push hl
            ld e, 8
            call m_codes
            pop hl
            pop bc
            ld a, l
            add a, 8
            ld l, a
            inc c
            ld a, c
            cp 8
            jr nz, .cw
            xor a
            ld [m_i], a
.mem:       call mm_member
            ld hl, m_i
            inc [hl]
            ld a, [hl]
            cp 4
            jr nz, .mem
            ld hl, GS + $1C                 ; gil: small digits, "G" ($90: the font's G)
            ld a, [hl+]
            ld e, a
            ld a, [hl+]
            ld d, a
            ld c, [hl]
            ld a, SN_T
            ld [sn_tile], a
            ld bc, $0E0A
            ld a, [GS + $1E]
            ld h, a
            call sn_draw24
            ld bc, $120A
            ld a, $90
            call m_put
            ld a, [GS + $1B]                ; capacity, "C"
            ld e, a
            ld d, 0
            ld h, 0
            ld a, SN_T + 6
            ld [sn_tile], a
            ld bc, $0E0B
            call sn_draw24
            ld bc, $120B
            ld a, $8C
            jp m_put

; member m_i: rows 1 + 4m .. 4 + 4m of the party window
mm_member:  ld a, [m_i]
            add a, a
            add a, a
            inc a
            ld [m_row], a
            ld a, [m_i]
            rrca
            rrca
            ld [m_ch], a                    ; $40 m
            ld l, a                         ; name ($6106, 6 codes)
            ld a, l
            add a, 6
            ld l, a
            ld h, high(GS + $100)
            ld a, [m_row]
            ld c, a
            ld b, 1
            ld e, 6
            call m_codes
            ld a, [m_row]                   ; "Lv" + level ($6101 + 1)
            ld c, a
            ld b, 8
            ld a, $95
            call m_put
            inc b
            ld a, $B9
            call m_put
            ld a, [m_ch]
            ld l, a
            inc l
            ld h, high(GS + $100)
            ld a, [hl]
            inc a
            ld e, a
            ld d, 0
            ld b, 11
            call m_dec                      ; (right-aligned, ending column B)
            ld a, [m_row]                   ; the job's condensed name (VRAM bank 1)
            inc a
            ld c, a
            ld b, 1
            ld a, [m_ch]
            ld l, a
            ld h, high(GS + $100)
            ld a, [hl]
            add a, low($5080)
            ld l, a
            ld a, high($5080)
            adc a, 0
            ld h, a
            ld a, MENU_BANK
            ld [MBC5_BANKL], a
            ld a, [hl]
            ld e, a
            ld a, [m_i]
            ld d, a
            add a, a
            add a, d
            add a, a
            add a, a
            add a, JOB_T
.jt:        push af
            ld d, a
            ld a, PAL_TXT | 8
            ld [m_attr], a
            ld a, d
            call m_put2
            pop af
            inc a
            inc b
            dec e
            jr nz, .jt
            ld a, [m_row]                   ; HP: "HP" [77][79], cur / max, in the status colour
            add a, 2
            ld c, a
            call mm_hpcol
            ld b, 1
            ld a, $77
            call m_put2
            inc b
            ld a, $79
            call m_put2
            ld b, 3                         ; "cur/max" from column 3
            ld a, [m_ch]
            add a, $0C
            call m_dec_l
            ld a, $C7                       ; "/"
            call m_put2
            inc b
            ld a, [m_ch]
            add a, $0E
            call m_dec_l
            ld a, PAL_TXT
            ld [m_attr], a
            ld a, [m_row]                   ; MP: [78][79], the 8 levels' current MP
            add a, 3
            ld c, a
            ld b, 1
            ld a, $78
            call m_put2
            inc b
            ld a, $79
            call m_put2
            ld a, PAL_TXT | 8
            ld [m_attr], a
            ld a, [m_ch]
            add a, $30
            ld l, a
            ld h, high(GS + $100)
            ld b, 3
            ld e, 8
.mp:        ld a, [hl+]
            inc l
            cp 10
            jr c, .m9
            ld a, 9
.m9:        dec e
            jr z, .last
            add a, MP_T                     ; "d/"
            call m_put2
            inc b
            jr .mp
.last:      add a, MP_T + 10                ; "d"
            call m_put2
            ld a, PAL_TXT
            ld [m_attr], a
            ret

; the HP row's palette (3C/95D7): no status green, dead / stone pink, other orange
mm_hpcol:   ld a, [m_ch]
            add a, 2
            ld l, a
            ld h, high(GS + $100)
            ld a, [hl]
            and $FE
            ld b, PAL_HP
            jr z, .s
            and $C0
            ld b, PAL_HP + 2
            jr nz, .s
            ld b, PAL_HP + 1
.s:         ld a, b
            ld [m_attr], a
            ret

; ---- canvas helpers (WRAM bank 2 selected)
m_clear:    ld hl, MC_MAP
            ld de, MC_ATTR
            ld bc, 32 * 18
.l:         ld a, $FF
            ld [hl+], a
            ld a, PAL_TXT
            ld [de], a
            inc de
            dec bc
            ld a, b
            or c
            jr nz, .l
            ld a, PAL_TXT
            ld [m_attr], a
            ret

; A = tile at column B, row C (attribute m_attr)
m_put:      push af
            ld a, PAL_TXT
            ld [m_attr], a
            pop af
m_put2:     push hl
            push af
            ld a, c
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
            add a, high(MC_MAP)
            ld h, a
            pop af
            ld [hl], a
            ld a, h
            add a, high(MC_ATTR - MC_MAP)
            ld h, a
            ld a, [m_attr]
            ld [hl], a
            pop hl
            ret

; E codes from HL ($FF ends early? no: $FF is a blank) at column B, row C
m_codes:    ld a, [hl+]
            call m_put2
            inc b
            dec e
            jr nz, m_codes
            ret

; a window frame: B, C = left, top; D, E = width, height (FEDF6 / FEE1D / FEE3E tiles)
m_box:      push bc
            ld a, $F7
            call m_put2
            ld a, d
            sub 2
            ld h, a
.t:         inc b
            ld a, $F8
            call m_put2
            dec h
            jr nz, .t
            inc b
            ld a, $F9
            call m_put2
            pop bc
            push bc
            ld a, e
            sub 2
            ld l, a
.m:         inc c
            push bc
            ld a, $FA
            call m_put2
            ld a, b
            add a, d
            dec a
            ld b, a
            ld a, $FB
            call m_put2
            pop bc
            dec l
            jr nz, .m
            inc c
            ld a, $FC
            call m_put2
            ld a, d
            sub 2
            ld h, a
.b:         inc b
            ld a, $FD
            call m_put2
            dec h
            jr nz, .b
            inc b
            ld a, $FE
            call m_put2
            pop bc
            ret

; DE (16 bits) in decimal, right-aligned, its last digit at column B, row C (English font digits)
m_dec:      push bc
.l:         push bc
            call div10                      ; DE / 10, A = remainder
            pop bc
            add a, $80
            call m_put2
            dec b
            ld a, d
            or e
            jr nz, .l
            pop bc
            ret
; the 16-bit value at GS + $100 + A, left-aligned from column B (B ends after it)
m_dec_l:    ld l, a
            ld h, high(GS + $100)
            ld a, [hl+]
            ld e, a
            ld d, [hl]
            push bc                         ; digits right to left into m_digs
            ld hl, m_digs
            ld c, 0
.d:         push hl
            push bc
            call div10
            pop bc
            pop hl
            ld [hl+], a
            inc c
            ld a, d
            or e
            jr nz, .d
            ld a, c
            pop bc
            ld e, a
.p:         dec hl
            ld a, [hl]
            add a, $80
            call m_put2
            inc b
            dec e
            jr nz, .p
            ret
div10:      ld hl, 0                        ; DE = DE / 10, A = DE mod 10
            ld b, 16
.l:         sla e
            rl d
            rl l
            rl h
            ld a, l
            sub 10
            ld c, a
            ld a, h
            sbc 0
            jr c, .n
            ld h, a
            ld l, c
            inc e
.n:         dec b
            jr nz, .l
            ld a, l
            ret

; HDE (24 bits: H high) in small digits, right-aligned in 4 tiles from column B, row C, into
; VRAM bank 1 tiles sn_tile.. (two digits a tile, 4 pixels each)
sn_draw24:  push bc
            ld a, h
            ld [n24 + 2], a
            ld a, d
            ld [n24 + 1], a
            ld a, e
            ld [n24], a
            ld hl, sn_dig                   ; 8 digits, most significant first ($FF = blank)
            ld b, 8
.c:         ld [hl], $FF
            inc hl
            dec b
            jr nz, .c
            ld hl, sn_dig + 7
.d:         push hl
            call div24                      ; n24 / 10 -> A = digit
            pop hl
            ld [hl-], a
            ld a, [n24]
            ld b, a
            ld a, [n24 + 1]
            or b
            ld b, a
            ld a, [n24 + 2]
            or b
            jr nz, .d
            ld hl, sn_buf                   ; 4 tiles: pixel rows (GB format, colour 3 on 2)
            ld b, 64
.cl:        ld a, $00
            ld [hl+], a                     ; (low plane 0, high plane 1: colour 2)
            ld a, $FF
            ld [hl+], a
            dec b
            jr nz, .cl
            ld c, 0                         ; digit k: tile k / 2, shift (k & 1) 4
.k:         ld a, c
            ld e, a
            ld d, high(sn_dig)
            ld a, e
            add a, low(sn_dig)
            ld e, a
            ld a, [de]
            cp $FF
            jr z, .nk
            ld b, a                         ; glyph rows: MENU_BANK $5300 + 5 digit
            add a, a
            add a, a
            add a, b
            add a, low($5300)
            ld e, a
            ld d, high($5300)
            ld a, c
            srl a
            swap a                          ; tile * 16
            add a, 2 * 2                    ; (from pixel row 2)
            ld l, a
            ld h, high(sn_buf)
            ld b, 5
.r:         ld a, MENU_BANK
            ld [MBC5_BANKL], a
            ld a, [de]
            inc de
            bit 0, c                        ; (even digits at pixels 1-3, odd at 5-7)
            jr nz, .h
            swap a
.h:         or [hl]                         ; ink: colour 3 = both planes
            ld [hl+], a
            inc hl
            dec b
            jr nz, .r
.nk:        inc c
            ld a, c
            cp 8
            jr nz, .k
            ld a, [sn_tile]                 ; upload (V-Blank DMA), place the 4 tiles
            swap a
            ld e, a
            and $F0
            ld d, a
            ld a, e
            and $0F
            add a, $80
            ld e, d
            ld d, a
            ld hl, sn_buf
            ld b, 4
            ld a, 1
            call vcopy_w
            pop bc
            ld a, PAL_TXT | 8
            ld [m_attr], a
            ld a, [sn_tile]
            ld e, 4
.p:         push af
            call m_put2
            pop af
            inc a
            inc b
            dec e
            jr nz, .p
            ld a, PAL_TXT
            ld [m_attr], a
            ret
div24:      ld hl, n24 + 2                  ; n24 /= 10, A = remainder
            xor a
            ld b, 3
.l:         ld c, [hl]
            push bc
            ld b, 8
.bit:       sla c
            rla
            cp 10
            jr c, .z
            sub 10
            inc c
.z:         dec b
            jr nz, .bit
            ld e, a
            ld a, c
            ld [hl-], a
            ld a, e
            pop bc
            dec b
            jr nz, .l
            ret

; B tiles from WRAM HL -> VRAM DE (bank A), in the next V-Blank (general-purpose DMA)
vcopy_w:    ld [vc_bank], a
            push hl
            push de
            push bc
            call wait_vbl
            pop bc
            pop de
            pop hl
            ld a, h
            ldh [rHDMA1], a
            ld a, l
            ldh [rHDMA2], a
            ld a, d
            ldh [rHDMA3], a
            ld a, e
            ldh [rHDMA4], a
            ld a, [vc_bank]
            ldh [rVBK], a
            ld a, b
            dec a
            ldh [rHDMA5], a
            xor a
            ldh [rVBK], a
            ret

; V-Blank (from the handler): the canvas when changed (map + attributes, 36 blocks each)
menu_vbl:   ld a, [m_dirty]
            and a
            ret z
            ld a, high(MC_MAP)
            ldh [rHDMA1], a
            xor a
            ldh [rHDMA2], a
            ld a, $9C
            ldh [rHDMA3], a
            xor a
            ldh [rHDMA4], a
            ld a, 36 - 1
            ldh [rHDMA5], a
            ld a, 1
            ldh [rVBK], a
            ld a, high(MC_ATTR)
            ldh [rHDMA1], a
            xor a
            ldh [rHDMA2], a
            ld a, $9C
            ldh [rHDMA3], a
            xor a
            ldh [rHDMA4], a
            ld a, 36 - 1
            ldh [rHDMA5], a
            xor a
            ldh [rVBK], a
            ld [m_dirty], a
            ret

section wram, $C680
m_i:        ds 1
m_row:      ds 1
m_ch:       ds 1
m_attr:     ds 1
m_cur:      ds 1
m_old:      ds 1
m_new:      ds 1
m_rep:      ds 1
m_dirty:    ds 1
menu_on:    ds 1
sn_tile:    ds 1
sn_dig:     ds 8
m_digs:     ds 6
section wram, $C700
sn_buf:     ds 64                           ; (page-aligned: DMA source)
