; FF3's monsters coming and going: a boss's entry and death (2F/BE97, BEA4: its graphics in 4-tile
; blocks, each written 8 times with its rows pushed apart, even rows right and odd rows left, by 7
; down to 0 coming in, 1 up to 8 going), the final boss's death (2F/BF93), and the ordinary
; monsters' death wipe (2F/BB94: FF3 sweeps a gradient diagonally across the dead ones; here a
; diagonal edge sweeps their cells, the cells on the edge masked pixel by pixel).

section bank B_BSCR, $6A00
BFX_BUF    = $D9C0                          ; (work RAM bank 2: FF3's graphics buffer)

; Z when the battle is a boss's (FF3: monster set 9 with $7D68 bit 6)
bs_isboss:  ld a, [$DD7B]
            cp 9
            ret nz
            ld a, [$DD68]
            cpl
            and $40
            ret
; ---- the boss coming in (2F/BE97): its tiles blank first (before the palettes), then block by block
bs_bossin:  call bs_isboss
            ret nz
            call bs_bsrc
            ld a, [bs_bbn]                  ; all blocks empty (shift 8) at once
            ld [bs_bbk], a
            xor a
            ld [bs_bblk], a
.e:         ld a, 8
            call bs_bpass0
            ld hl, bs_bblk
            inc [hl]
            ld a, [hl]
            ld hl, bs_bbk
            cp [hl]
            jr nz, .e
            ret
bs_bossin2: call bs_isboss
            ret nz
            ld a, 7
            ld b, $FF
            ld c, 0
            jr bs_bshift
; ---- the boss beaten (2F/BEA4); the final one (2F/BF93: the music fading out, the screen grey three
; times, then as the others; FF3 sets the message speed to 8 after it)
bs_bossdie: ld a, [$DCEE]
            and a
            jr z, .n
            ld a, [$DCED]
            cp $78
            jr nz, .n
            ld a, 1                         ; the music fading
            ldh [rSVBK], a
            ld a, $0C
            ld [M_CTRL], a
            ld a, 2
            ldh [rSVBK], a
.mf:        call bs_frame
            ld a, 1
            ldh [rSVBK], a
            ld a, [M_CTRL]
            ld b, a
            ld a, 2
            ldh [rSVBK], a
            ld a, b
            and $0C
            jr nz, .mf
            ld b, 60
            call bs_greyf
            ld b, 10
            call bs_greyf
            ld b, 120
            call bs_greyf
            ld a, $0E
            call bs_sfxu
            call bs_fdis                    ; (10/8A9D: the dissolve; 2F/BFB8: the fade)
            ld a, 8                         ; ($6010: the message speed)
            ld [$D010], a
            ret
.n:         ld a, 1
            ld b, 1
            ld c, 1
; the blocks from shift A by B a pass (C: with the sound every 4 blocks)
bs_bshift:  ld [bs_bs0], a
            ld a, b
            ld [bs_bst], a
            ld a, c
            ld [bs_bsnd], a
            call bs_bsrc
            xor a
            ld [bs_bblk], a
.b:         ld a, [bs_bsnd]
            and a
            jr z, .p
            ld a, [bs_bblk]
            and 3
            jr nz, .p
            ld a, $3C
            call bs_sfxu
.p:         ld a, [bs_bs0]
            ld [bs_bss], a
            ld a, 8
            ld [bs_bpc], a
.q:         ld a, [bs_bss]
            call bs_bpass
            ld a, [bs_bss]
            ld hl, bs_bst
            add [hl]
            ld [bs_bss], a
            ld hl, bs_bpc
            dec [hl]
            jr nz, .q
            ld hl, bs_bblk
            inc [hl]
            ld a, [hl]
            ld hl, bs_bbn
            cp [hl]
            jr nz, .b
            ret
; the boss's graphics: bank, address (B_BINFO $4400 + 3 id), blocks (2F/BE7F)
bs_bsrc:    call bs_bossid
            push af
            ld l, a
            add a
            add l
            ld l, a
            ld h, high($4400)
            ld a, l
            add low($4400)
            ld l, a
            ld de, bs_bsb
            ld bc, 3
            ld a, B_BINFO
            call far_copy
            pop af
            ld hl, bs_bblks
            call bs_hl_a
            ld a, [hl]
            ld [bs_bbn], a
            ret
; one pass of block bs_bblk at shift A: a frame, then its 4 tiles to VRAM (bank 0)
bs_bpass:   push af
            call bs_bprep
            call bs_frame
            pop af
            jr bs_bput
bs_bpass0:  push af                         ; (no frame: the screen is black)
            call bs_bprep
            pop af
            jr bs_bput
bs_bprep:   ld a, [bs_bblk]                 ; the block's 64 bytes from the ROM
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld a, [bs_bsb + 1]
            add l
            ld l, a
            ld a, [bs_bsb + 2]
            adc h
            ld h, a
            ld de, BFX_BUF
            ld bc, 64
            ld a, [bs_bsb]
            jp far_copy
bs_bput:    ld [bs_bss2], a                 ; shift the rows (row r: bytes 2r, 2r + 1)
            ld hl, BFX_BUF
            ld c, 32
.r:         ld a, c
            and 1                           ; (even rows of each tile right: C counts down from 32)
            ld b, a
            call .one
            call .one
            dec c
            jr nz, .r
            ld a, [bs_bblk]                 ; tile 4 blk: $9000 + 16 t ($8800 + 16 (t - 128) past 127)
            add a
            add a
            ld e, a
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld a, e
            cp 128
            ld de, $9000
            jr c, .t
            ld de, $8800 - $800
.t:         add hl, de
            ld d, h
            ld e, l
            call wait_vbl
            ld a, 1
            ld [guard_on], a
            ld a, $20
            ldh [rSTAT], a
            xor a
            ldh [rVBK], a
            ld hl, BFX_BUF
            ld b, 64
.c:         ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .c
            xor a
            ldh [rSTAT], a
            ld [guard_on], a
            ret
.one:       ld a, [bs_bss2]
            ld e, a
            ld a, [hl]
            bit 3, e                        ; (8 or more: nothing left)
            jr nz, .z
            inc e
            dec e
            jr z, .s
            bit 0, b
            jr nz, .lf
.rt:        srl a
            dec e
            jr nz, .rt
            jr .s
.lf:        add a
            dec e
            jr nz, .lf
            jr .s
.z:         xor a
.s:         ld [hl+], a
            ret
; FF3's sound A (work RAM bank 2 mapped)
bs_sfxu:    push af
            ld a, 1
            ldh [rSVBK], a
            pop af
            call sfx_play
            ld a, 2
            ldh [rSVBK], a
            ret
; the screen grey by turns 16 frames (10/8A6C), then B frames
bs_greyf:   push bc
            call wait_vbl                   ; (the palettes kept: BG 0-7, OBJ 0-7)
            ld hl, BFX_BUF
            ld c, 0
.k:         ld a, c
            ldh [rBCPS], a
            ldh a, [rBCPD]
            ld [hl+], a
            inc c
            ld a, c
            cp 64
            jr nz, .k
            ld c, 0
.k2:        ld a, c
            ldh [rOCPS], a
            ldh a, [rOCPD]
            ld [hl+], a
            inc c
            ld a, c
            cp 64
            jr nz, .k2
            ld hl, BFX_BUF                  ; grey copies (the colour's green as its level)
            ld de, BFX_BUF + 128
            ld b, 64
.g:         ld a, [hl+]
            ld c, a
            ld a, [hl+]
            push hl
            ld h, a
            ld l, c
            add hl, hl
            add hl, hl
            add hl, hl
            ld a, h
            and $1F                         ; (G: bits 5-9)
            ld c, a
            ld l, a                         ; RGB555 grey: c | c << 5 | c << 10
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld a, l
            or c
            ld [de], a
            inc de
            ld a, c
            add a
            add a
            or h
            ld [de], a
            inc de
            pop hl
            dec b
            jr nz, .g
            ld a, $43                       ; (FF3's sound $C3)
            call bs_sfxu
            ld b, 16
.f:         push bc                         ; (the palettes first in V-Blank: they cannot be
            call wait_vbl                   ;   written while a line is drawn)
            pop bc
            ld a, b
            and 1
            ld hl, BFX_BUF + 128
            jr z, .w
            ld hl, BFX_BUF
.w:         push bc
            call bs_pals
            call snd_frame
            pop bc
            dec b
            jr nz, .f
            call wait_vbl
            ld hl, BFX_BUF
            call bs_pals
            pop bc
.x:         push bc
            call bs_frame
            pop bc
            dec b
            jr nz, .x
            ret
; all palettes from HL (64 BG bytes, 64 OBJ) - in V-Blank
bs_pals:    ld a, $80
            ldh [rBCPS], a
            ld c, 64
.b:         ld a, [hl+]
            ldh [rBCPD], a
            dec c
            jr nz, .b
            ld a, $80
            ldh [rOCPS], a
            ld c, 64
.o:         ld a, [hl+]
            ldh [rOCPD], a
            dec c
            jr nz, .o
            ret

; ---- the dead monsters' wipe (2F/BB94): mask A (slot 0 the top bit), 37 frames, sound $31; a
; diagonal edge from the top left of each one's cells; cells behind it blank, cells on it
; masked copies of their tile (VRAM bank 1 BG tiles $A8-$BF and $C0-$D7 by turns, 24 a frame:
; a slot is never rewritten while a cell still shows it)
bs_mwipe:   ld [bs_wm], a
            and a
            ret z
            ld a, $31
            call bs_sfxu
            xor a
            ld [bs_wf], a
.f:         call bs_frame
            xor a
            ld [bs_wk], a                   ; (slots used this frame)
            ld a, 1
            ld [guard_on], a
            ld a, $20
            ldh [rSTAT], a
            ld a, [bs_wm]
            ld [bs_wt], a
            xor a
            ld [bs_ws], a
.s:         ld a, [bs_wt]
            add a
            ld [bs_wt], a
            jr nc, .ns
            ld a, [bs_ws]
            ld [fl_s], a
            call bs_srect
            call nc, bs_wrect
.ns:        ld hl, bs_ws
            inc [hl]
            ld a, [hl]
            cp 8
            jr nz, .s
            xor a
            ldh [rSTAT], a
            ld [guard_on], a
            ld hl, bs_wf
            inc [hl]
            ld a, [hl]
            cp 38
            jr nz, .f
            ret
; the rect (fl_x, fl_y, fl_w, fl_h) at frame bs_wf: edge p = f (8 (w + h) + 16) / 37
bs_wrect:   ld a, [fl_w]
            ld hl, fl_h
            add [hl]
            add 2
            ld e, a
            ld a, [bs_wf]
            call mul8                       ; HL = f (w + h + 2)
            add hl, hl
            add hl, hl
            add hl, hl                      ; x 8
            ld c, 37
            ld b, 16
            xor a
.d:         add hl, hl
            rla
            cp c
            jr c, .dn
            sub c
            inc l
.dn:        dec b
            jr nz, .d
            ld a, h                         ; (p up to 255)
            and a
            ld a, l
            jr z, .p
            ld a, $FF
.p:         ld [bs_wp], a
            xor a
            ld [bs_wr], a
.r:         xor a
            ld [bs_wc], a
.c:         ld a, [bs_wr]                   ; g0 = 8 (r + c)
            ld hl, bs_wc
            add [hl]
            add a
            add a
            add a
            ld d, a
            ld a, [bs_wp]
            sub d
            jr c, .nx                       ; (the edge has not come)
            cp 15
            jr nc, .blank
            ld [bs_wd], a                   ; on the edge: d = p - g0 (0-14)
            call bs_wedge
            jr .nx
.blank:     call bs_wcell
            jr z, .nx
            ld a, BLANK_T
            ld [hl], a
            ld a, 1
            ldh [rVBK], a
            ld [hl], b
            xor a
            ldh [rVBK], a
.nx:        ld hl, bs_wc
            inc [hl]
            ld a, [fl_w]
            cp [hl]
            jr nz, .c
            ld hl, bs_wr
            inc [hl]
            ld a, [fl_h]
            cp [hl]
            jr nz, .r
            ret
; HL = the cell's VRAM map address ($9800 + 32 (fl_y + r) + fl_x + c)
bs_wcell:   ld a, [fl_y]                    ; (Z: not shown; B: the x-flip toggle)
            ld hl, bs_wr
            add [hl]
            ld d, a
            ld a, [fl_x]
            ld hl, bs_wc
            add [hl]
            ld e, a
            jp bs_mcell
; the edge cell: its tile from the monster area (MON_T / MON_A), masked rows (row y: d - y pixels
; from the left wiped), into a slot of VRAM bank 1, the cell pointed at it
bs_wedge:   ld a, [bs_wk]
            cp 24
            ret nc
            ld a, [fl_y]                    ; MON_T + 20 row + column
            ld hl, bs_wr
            add [hl]
            ld e, a
            add a
            add a
            ld d, a
            add a
            add a
            add d                           ; 20 row
            ld d, a
            ld a, [fl_x]
            ld hl, bs_wc
            add [hl]
            add d
            ld l, a
            ld h, 0
            ld de, MON_T
            add hl, de
            ld a, [hl]
            ld [bs_wtl], a
            ld de, MON_A - MON_T
            add hl, de
            ld a, [hl]
            ld [bs_wat], a
            ld a, [bs_wtl]                  ; the tile's data address ($8800 mode)
            call bs_tile_addr
            ld a, [bs_wat]                  ; (its bank)
            rrca
            rrca
            rrca
            and 1
            ld c, a
            ld hl, BFX_BUF
            ld b, 16
.cp:        di                              ; (each read out of mode 3, its VRAM bank set
            ld a, c                         ;   each time: other interrupts may change both)
            ldh [rVBK], a
.md:        ldh a, [rSTAT]
            and 3
            cp 3
            jr z, .md
            ld a, [de]
            ei
            ld [hl+], a
            inc de
            dec b
            jr nz, .cp
            xor a
            ldh [rVBK], a
            ld hl, BFX_BUF                  ; rows masked
            ld c, 0
.m:         ld a, [bs_wd]
            sub c
            jr c, .keep
            cp 8
            jr c, .sh
            xor a
            ld [hl+], a
            ld [hl+], a
            jr .mn
.sh:        ld b, a
            ld a, $FF
            inc b
            dec b
            jr z, .mm
.s1:        srl a
            dec b
            jr nz, .s1
.mm:        ld b, a
            ld a, [hl]
            and b
            ld [hl+], a
            ld a, [hl]
            and b
            ld [hl+], a
            jr .mn
.keep:      inc hl
            inc hl
.mn:        inc c
            ld a, c
            cp 8
            jr nz, .m
            ld a, [bs_wf]                   ; slot $A8 / $C0 + k (VRAM bank 1 $8800 + 16 slot)
            and 1
            ld a, $A8
            jr z, .sl
            ld a, $C0
.sl:        ld hl, bs_wk
            add [hl]
            ld [bs_wsl], a
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
            ld a, 1
            ldh [rVBK], a
            ld hl, BFX_BUF
            ld b, 16
.w:         ld a, [hl+]
            ld c, a
            di
            ld a, 1
            ldh [rVBK], a
.wm:        ldh a, [rSTAT]
            and 3
            cp 3
            jr z, .wm
            ld a, c
            ld [de], a
            ei
            inc de
            dec b
            jr nz, .w
            xor a
            ldh [rVBK], a
            call bs_wcell
            jr z, .hid
            ld a, [bs_wsl]
            ld [hl], a
            ld a, 1
            ldh [rVBK], a
            ld a, [bs_wat]
            or $08
            xor b
            ld [hl], a
            xor a
            ldh [rVBK], a
            ld hl, bs_wk
            inc [hl]
.hid:       xor a
            ldh [rVBK], a
            ret

section wram, $D9A8
bs_bsb:     ds 3
bs_bbn:     ds 1
bs_bbk:     ds 1
bs_bblk:    ds 1
bs_bs0:     ds 1
bs_bst:     ds 1
bs_bsnd:    ds 1
bs_bss:     ds 1
bs_bss2:    ds 1
bs_bpc:     ds 1
bs_wm:      ds 1
bs_wf:      ds 1
bs_wk:      ds 1
bs_wt:      ds 1
bs_ws:      ds 1
bs_wp:      ds 1
bs_wr:      ds 1
bs_wc:      ds 1
bs_wd:      ds 1
bs_wtl:     ds 1
bs_wat:     ds 1
bs_wsl:     ds 1

section bank B_BSCR, $7F00
bs_bblks:   ds 24                           ; (2F/BE7F: each boss's 4-tile blocks)

; ---- the final boss's death (10/8A9D): 16 columns, one per byte of a tile (FF3's planes: bytes
; 0-7 plane 0, 8-15 plane 1), each clearing its byte in the boss's tiles from $FF down to $70, one
; tile back when its accumulator (+ 10/8A4C's speed a frame) carries, 143 tiles; meanwhile the
; screen scrolled up a line every 16 frames (FF3's split: the battlefield's top cut, the windows
; rising) and shaken across (10/8A5C: 1-3 pixels); then 2F/BFB8: all palettes darker every 8
; frames, 80 frames
FD_N       = BFX_BUF                        ; (each column's tile, accumulator, count)
FD_A       = BFX_BUF + 16
FD_C       = BFX_BUF + 32
section bank B_BSCR, $7400
bs_fdis:    call wait_vbl                   ; (the rows below the windows and right of the
            ld a, 1                         ;   battlefield blank: they scroll in)
            ld [guard_on], a
            ld a, $20
            ldh [rSTAT], a
            ld hl, $9800 + 32 * 18
            ld b, 7 * 32 / 4
.bk:        ld a, BLANK_T
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            dec b
            jr nz, .bk
            ld a, 1
            ldh [rVBK], a
            ld hl, $9800 + 32 * 18
            ld b, 7 * 32
            xor a
.ba:        ld [hl+], a
            dec b
            jr nz, .ba
            xor a
            ldh [rVBK], a
            ld hl, $9800 + 20
            ld c, 18
.br:        ld b, 12
            push hl
.bc:        ld [hl], BLANK_T
            inc hl
            dec b
            jr nz, .bc
            pop hl
            ld a, 1
            ldh [rVBK], a
            push hl
            ld b, 12
            xor a
.bd:        ld [hl+], a
            dec b
            jr nz, .bd
            pop hl
            xor a
            ldh [rVBK], a
            ld de, 32
            add hl, de
            dec c
            jr nz, .br
            xor a
            ldh [rSTAT], a
            ld [guard_on], a
            ld hl, FD_N
            ld b, 16
.i:         ld [hl], $FF
            push hl
            ld de, 16
            add hl, de
            ld [hl], 0
            add hl, de
            ld [hl], $8F
            pop hl
            inc hl
            dec b
            jr nz, .i
            xor a
            ld [bs_fdy], a
            ld [bs_fdy + 1], a
            ld [bs_fdf], a
.f:         call wait_vbl
            ld c, 0                         ; the 16 bytes cleared (V-Blank)
.w:         ld hl, FD_N
            ld a, c
            call bs_hl_a
            ld a, [hl]
            sub $70                         ; (our tile = FF3's - $70)
            call bs_tile_addr               ; DE
            ld a, c                         ; FF3's byte -> ours: plane 0 row r: 2 r, plane 1: 2 r + 1
            cp 8
            jr c, .p0
            sub 8
            add a
            inc a
            jr .pa
.p0:        add a
.pa:        add e
            ld e, a
            xor a
            ld [de], a
            inc c
            ld a, c
            cp 16
            jr nz, .w
            ld a, [bs_fdy + 1]              ; the scroll: up a line every 16 frames (scaled 5 / 8:
            ld b, a                         ;   n - n / 4 - n / 8, no overflow)
            srl a
            srl a
            ld c, a
            srl a
            add c
            ld c, a
            ld a, b
            sub c
            ldh [rSCY], a
            ld a, [bs_fdf]                  ; the shake
            and 7
            ld hl, fd_shk
            call bs_hl_a
            ld a, [hl]
            ldh [rSCX], a
            call snd_frame
            ld hl, bs_fdf
            inc [hl]
            ld hl, bs_fdy
            ld a, [hl]
            add $10
            ld [hl+], a
            jr nc, .y
            inc [hl]
.y:         ld c, 0                         ; the columns moved on
            ld e, 0                         ; (E: still going)
.u:         ld hl, FD_C
            ld a, c
            call bs_hl_a
            ld a, [hl]
            and a
            jr z, .un
            inc e
            ld hl, fd_spd
            ld a, c
            call bs_hl_a
            ld b, [hl]
            ld hl, FD_A
            ld a, c
            call bs_hl_a
            ld a, [hl]
            add b
            ld [hl], a
            jr nc, .un
            ld hl, FD_C
            ld a, c
            call bs_hl_a
            dec [hl]
            ld hl, FD_N
            ld a, c
            call bs_hl_a
            dec [hl]
.un:        inc c
            ld a, c
            cp 16
            jr nz, .u
            ld a, e
            and a
            jp nz, .f
            ld b, 10                        ; 2F/BFB8: the palettes a step darker every 8 frames
.d:         push bc
            call bs_dark
            ld b, 8
.dw:        push bc
            call wait_vbl
            call snd_frame
            pop bc
            dec b
            jr nz, .dw
            pop bc
            dec b
            jr nz, .d
            call wait_vbl
            xor a
            ldh [rSCX], a
            ldh [rSCY], a
            ret
; all palettes (BG, OBJ) a step darker (FF3's colour - $10: here each channel halved)
bs_dark:    call wait_vbl
            ld hl, BFX_BUF + 64
            ld c, 0
.r:         ld a, c
            ldh [rBCPS], a
            ldh a, [rBCPD]
            ld [hl+], a
            inc c
            ld a, c
            cp 64
            jr nz, .r
            ld c, 0
.r2:        ld a, c
            ldh [rOCPS], a
            ldh a, [rOCPD]
            ld [hl+], a
            inc c
            ld a, c
            cp 64
            jr nz, .r2
            ld hl, BFX_BUF + 64
            ld b, 64
.h:         ld e, [hl]
            inc hl
            ld d, [hl]
            srl d
            rr e
            ld a, e
            and $EF
            ld e, a
            ld a, d
            and $3D
            ld [hl-], a
            ld [hl], e
            inc hl
            inc hl
            dec b
            jr nz, .h
            call wait_vbl
            ld a, $80
            ldh [rBCPS], a
            ld hl, BFX_BUF + 64
            ld b, 64
.w:         ld a, [hl+]
            ldh [rBCPD], a
            dec b
            jr nz, .w
            ld a, $80
            ldh [rOCPS], a
            ld b, 64
.w2:        ld a, [hl+]
            ldh [rOCPD], a
            dec b
            jr nz, .w2
            ret
fd_spd:     ds 16                           ; (10/8A4C)
fd_shk:     ds 8                            ; (10/8A5C)

section wram, $C5E4
bs_fdy:     ds 2
bs_fdf:     ds 1
