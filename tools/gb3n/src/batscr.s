; The battle on the Game Boy Color screen (our presentation; FF3's rules run in the battle banks).
; Screen: monsters in BG rows 0-11 (columns 0-17: FF3's positions - 2 / - 6), the party's
; battle sprites at x 144 (a member every 24 lines), windows in rows 12-17; a top window
; (rows 0-3) over the monsters for an action's names. All BG writes go to a shadow (tiles and
; attributes) copied to VRAM in V-Blank a few rows a frame.
; Memory during a battle (the field's map tables, rebuilt after): $C800 shadow, $C520 variables.

SH_T       = $C800          ; 20 x 18 tiles
SH_A       = $C968          ; 20 x 18 attributes
SH_D       = $CAD0          ; dirty rows (18)
MON_T      = $CAE8          ; the monster area rows 0-11 (tiles, attributes): the base
MON_A      = $CBD8
BS_STR     = $CCD0          ; a string (40)
BLANK_T    = $FF            ; an empty BG tile (VRAM bank 0)
SPR_DIG    = $E0            ; sprite tiles (VRAM bank 1): digits 0-9 at $E0, "Miss" $EA-$ED, hand $EE
SPR_HAND   = $EE

section bank B_BSCR, $4000
; ---- the battle (far-called from the field with bs_id / bs_bg set; the field reloads its map
; after)
bs_battle:  call wait_vbl
            call pal_black
            ld a, 1
            ld [guard_on], a
            ldh [snd_isr], a
            ld a, $20
            ldh [rSTAT], a
            call bs_setup
            xor a
            ldh [snd_isr], a
            ldh [rSTAT], a
            ld [guard_on], a
            xor a                           ; no scroll in a battle
            ldh [rSCX], a
            ldh [rSCY], a
            call bs_vall
            call bs_palette
            call bs_loop                    ; (FF3's battle main)
            jp bs_leave

; ---- setup: FF3's battle RAM, its init, our screen
bs_setup:   ld hl, BZ                       ; FF3's zero page cleared
            ld b, 0
            xor a
.z:         ld [hl+], a
            dec b
            jr nz, .z
            ld a, 2                         ; work RAM bank 2: the save page copied in, the rest
            ldh [rSVBK], a                  ;   cleared
            ld hl, $D400
            ld bc, $0B00
.zb:        xor a
            ld [hl+], a
            dec bc
            ld a, b
            or c
            jr nz, .zb
            ld c, 1
            call bs_page
            ld a, [bs_id]                   ; (2E/9E8E: id + $100 off world 0; the bg byte:
            ld [$DCED], a                   ;   id in the low 5 bits, flags in the top 3)
            ld a, [world]
            and a
            jr z, .w0
            ld a, 1
.w0:        ld [$DCEE], a
            ld a, [bs_bg]
            and $1F
            ld [$DCEF], a
            ld a, [bs_bg]
            and $E0
            ld [$DED8], a
            xor a
            ld [$D4C6], a                   ; vehicle (on foot)
            ld a, [map_id]
            ld [$D4C8], a
            ld a, [frame]                   ; the random table (FF3 seeds with its zero page)
            ld hl, pos_x
            add [hl]
            inc hl
            add [hl]
            ld hl, wm_x
            add [hl]
            ld [bs_seed], a
            %FAR B_BAT2, fe_setup_all       ; random table, monster set, counts, layout, slots
            ld a, [$DD68]                   ; flags from the count id
            swap a
            srl a
            srl a
            and 3
            ld hl, $DED8
            or [hl]
            ld [hl], a
            ld hl, $DDA7                    ; $7ECD = the slots' types at the start
            ld de, $DECD
            ld b, 8
.ty:        ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .ty
            %FAR B_BAT2, fe_9CE3            ; characters and monsters
            ld a, 1
            ld [bs_live], a
            call bs_gfx
            call bs_draw
            call bs_party
            call bs_pwin
            ld a, [$DD68]                   ; the song: Battle 1, a boss: Battle 2 (Last Battle)
            bit 6, a
            ld a, $20
            jr z, .s
            ld a, [$DD73]
            and $1F
            cp 8
            ld a, $28
            jr z, .s
            ld a, $2A
.s:         jp mus_play

; the save page between work RAM banks: C = 1: bank 1 -> 2, C = 2: bank 2 -> 1 ($D000-$D3FF)
bs_page:    ld d, $D0
.p:         ld a, c
            ldh [rSVBK], a
            ld h, d
            ld l, 0
            ld e, l
            push de
            ld de, BS_PAGE
            ld b, 0
.a:         ld a, [hl+]
            ld [de], a
            inc e
            dec b
            jr nz, .a
            pop de
            ld a, c
            xor 3
            ldh [rSVBK], a
            ld hl, BS_PAGE
            push de
            ld e, 0
.b:         ld a, [hl+]
            ld [de], a
            inc e
            jr nz, .b
            pop de
            inc d
            ld a, d
            cp $D4
            jr nz, .p
            ld a, 2
            ldh [rSVBK], a
            ret
BS_PAGE    = $C600

; ---- graphics: monster types' tiles to VRAM bank 0, the party's to bank 1, sprite digits
bs_gfx:     xor a
            ldh [rVBK], a
            ld hl, $8FF0                    ; the blank tile ($FF)
            ld b, 16
.bl:        ld [hl+], a
            dec b
            jr nz, .bl
            ld [bs_n], a                    ; the next free tile
            ld [bs_t], a                    ; the type
            ld a, [$DD7B]                   ; a boss: its 144 tiles (B_BINFO $4400 + 3 x id)
            cp 9
            jr nz, .t
            call bs_bossid
            ld l, a
            add a
            add l
            ld l, a
            ld h, high($4400)
            ld a, l
            add low($4400)
            ld l, a
            ld de, bs_mi
            ld bc, 3
            ld a, B_BINFO
            call far_copy
            ld a, [bs_mi + 1]
            ld l, a
            ld a, [bs_mi + 2]
            ld h, a
            ld de, $9000
            ld bc, 128 * 16
            ld a, [bs_mi]
            call far_copy
            ld de, $8800
            ld bc, 16 * 16
            ld a, [bs_mi]
            call far_copy
            jp .party
.t:         ld a, [bs_t]
            ld hl, bs_tb
            call bs_hl_a
            ld a, [bs_n]
            ld [hl], a
            ld a, [bs_t]                    ; the type's monster id -> its graphics
            ld hl, $DD6B
            call bs_hl_a
            ld a, [hl]
            cp $FF
            jr z, .nx
            call bs_minfo
            ld a, [bs_mi + 3]
            and a
            jr z, .nx
            ld e, a                         ; tiles = w x h
            swap a
            and 15
            ld d, a
            ld a, e
            and 15
            ld e, a
            xor a
.m:         add e
            dec d
            jr nz, .m
            ld [bs_cnt], a
            ld a, [bs_n]
            call bs_tile_addr
            ld a, [bs_mi + 1]
            ld l, a
            ld a, [bs_mi + 2]
            ld h, a
.cp:        ld bc, 16
            ld a, [bs_mi]
            call far_copy                   ; (HL, DE move on)
            ld a, d                         ; ($97F0 -> $8800: the $8800 mode's tiles 128+)
            cp $98
            jr nz, .w
            ld d, $88
.w:         ld a, [bs_n]
            inc a
            ld [bs_n], a
            ld a, [bs_cnt]
            dec a
            ld [bs_cnt], a
            jr nz, .cp
.nx:        ld a, [bs_t]
            inc a
            ld [bs_t], a
            cp 4
            jr nz, .t
.party:     ld a, 1                         ; the party: standing pose (6 tiles) at OBJ tiles
            ldh [rVBK], a                   ;   6 x member, VRAM bank 1
            ld c, 0
.p:         push bc
            call bs_jobaddr
            pop bc
            push bc
            ld a, c
            add a
            ld b, a
            add a
            add b                           ; 6 x member
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
            ld a, [bs_ja]
            ld l, a
            ld a, [bs_ja + 1]
            ld h, a
            ld bc, 6 * 16
            ld a, B_CGFX
            call far_copy
            pop bc
            inc c
            ld a, c
            cp 4
            jr nz, .p
            ld hl, C_SPRDIG                 ; digits / Miss / hand (our tiles, B_OWN)
            ld de, $8000 + 16 * SPR_DIG
            ld bc, 16 * 16
            ld a, B_OWN
            call far_copy
            xor a
            ldh [rVBK], a
            ret
; [bs_ja] = B_CGFX address of character C's job graphics ($4000 + job x $2A0)
bs_jobaddr: ld a, c
            call bs_choff
            ld l, a
            ld h, $D1
            ld a, [hl]
            cp 22
            jr c, .j
            xor a
.j:         ld e, a
            ld d, 0
            ld hl, $4000
            ld b, a
            and a
            jr z, .s
.a:         ld de, $2A0
            add hl, de
            dec b
            jr nz, .a
.s:         ld a, l
            ld [bs_ja], a
            ld a, h
            ld [bs_ja + 1], a
            ret
; A = character C x $40 (save page offset)
bs_choff:   rrca
            rrca
            and $C0
            ret
; DE = the VRAM address of BG tile A ($8800 mode)
bs_tile_addr:
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            bit 7, a
            ld de, $9000
            jr z, .s
            ld de, $8000
.s:         add hl, de
            ld d, h
            ld e, l
            ret
; HL += A
bs_hl_a:    add l
            ld l, a
            ret nc
            inc h
            ret
; [bs_mi] = monster A's graphics index (B_BINFO: bank, address, w << 4 | h)
bs_minfo:   ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            ld de, $4000
            add hl, de
            ld de, bs_mi
            ld bc, 4
            ld a, B_BINFO
            jp far_copy

; ---- the monster area from the slots: shadow rows 0-11 and its base copy
bs_draw:    ld hl, MON_T                    ; blank
            ld bc, 240
.z:         ld a, BLANK_T
            ld [hl+], a
            dec bc
            ld a, b
            or c
            jr nz, .z
            ld hl, MON_A
            ld bc, 240
.z2:        xor a
            ld [hl+], a
            dec bc
            ld a, b
            or c
            jr nz, .z2
            ld a, [$DD7B]                   ; FF3's positions (2F/A5E6 + 2 x tilemap id)
            cp 9
            jp z, .boss
            add a
            ld l, a
            ld h, high($A5E6 - $4000)
            ld a, l
            add low($A5E6 - $4000)
            ld l, a
            jr nc, .p
            inc h
.p:         ld a, B_BSET
            call far_byte
            ld c, a
            inc hl
            ld a, B_BSET
            call far_byte
            sub $40
            ld h, a
            ld l, c
            ld de, bs_pos                   ; up to 8 x 3 bytes
            ld bc, 24
            ld a, B_BSET
            call far_copy
            ld c, 0                         ; slot
.s:         ld a, c
            ld b, a
            add a
            add b
            ld hl, bs_pos
            call bs_hl_a
            ld a, [hl]
            cp $FF
            jp z, .copy
            ld a, c
            push hl
            ld hl, $DDA7
            call bs_hl_a
            ld a, [hl]
            pop hl
            cp $FF
            jr z, .n
            push bc
            ld [bs_t], a                    ; the slot's type
            ld a, [hl+]
            sub 2
            ld [bs_x], a
            ld a, [hl]
            sub 6
            ld [bs_y], a
            ld a, [bs_t]
            ld hl, $DD6B
            call bs_hl_a
            ld a, [hl]
            call bs_minfo
            ld a, [bs_mi + 3]
            and a
            jr z, .nn
            call bs_block
.nn:        pop bc
.n:         inc c
            ld a, c
            cp 8
            jr nz, .s
            jr .copy
.boss:      ld a, [$DDA7]                   ; a boss: its 18 x 12 tilemap (B_BINFO $4500)
            cp $FF
            jr z, .copy
            call bs_bossid
            ld l, a
            ld h, 0
            ld de, 216
            call bs_mul16hl
            ld de, $4500
            add hl, de
            ld de, MON_T
            ld b, 12
.br:        push bc
            push de
            ld bc, 18
            ld a, B_BINFO
            call far_copy
            pop de
            ld a, e
            add 20
            ld e, a
            jr nc, .bn
            inc d
.bn:        pop bc
            dec b
            jr nz, .br
.copy:      ld hl, MON_T                    ; base -> shadow rows 0-11
            ld de, SH_T
            ld bc, 240
            call memcpy
            ld hl, MON_A
            ld de, SH_A
            ld bc, 240
            call memcpy
            ld hl, SH_D
            ld b, 12
            ld a, 1
.d:         ld [hl+], a
            dec b
            jr nz, .d
            ret
; A = the boss's graphics id ($7D73 & $1F)
bs_bossid:  ld a, [$DD73]
            and $1F
            ret
; HL = L x DE (L small)
bs_mul16hl: ld a, l
            ld hl, 0
            and a
            ret z
.m:         add hl, de
            dec a
            jr nz, .m
            ret
; a type's block (bs_mi: w x h) at (bs_x, bs_y) in MON_T / MON_A
bs_block:   ld a, [bs_t]
            ld hl, bs_tb
            call bs_hl_a
            ld a, [hl]
            ld [bs_n], a                    ; the first tile
            ld a, [bs_t]                    ; palette: types 0 / 2 -> 0, 1 / 3 -> 1
            and 1
            ld [bs_pal], a
            ld a, [bs_mi + 3]
            and 15
            ld b, a                         ; rows
            ld a, [bs_y]
            ld c, a
.r:         ld a, c
            cp 12
            jr nc, .x
            push bc
            ld l, c                         ; HL = MON_T + 20 y + x
            ld h, 0
            add hl, hl
            add hl, hl
            ld d, h
            ld e, l
            add hl, hl
            add hl, hl
            add hl, de
            ld a, [bs_x]
            call bs_hl_a
            push hl
            ld de, MON_T
            add hl, de
            ld d, h
            ld e, l
            pop hl
            ld bc, MON_A
            add hl, bc
            ld a, [bs_mi + 3]
            swap a
            and 15
            ld b, a                         ; columns
            ld a, [bs_x]
            ld c, a
.c:         ld a, c
            cp 18
            jr nc, .cx
            ld a, [bs_n]
            ld [de], a
            ld a, [bs_pal]
            ld [hl], a
.cx:        inc de
            inc hl
            ld a, [bs_n]
            inc a
            ld [bs_n], a
            inc c
            dec b
            jr nz, .c
            pop bc
            inc c
            dec b
            jr nz, .r
.x:         ret

; ---- the party's sprites (members at x 144, y 24 i; acting: x 136)
bs_party:   ld hl, oam_buf
            ld b, 160
            xor a
.z:         ld [hl+], a
            dec b
            jr nz, .z
            ld c, 0
.m:         ld a, c                         ; dead (status 1 bit 7): not shown
            call bs_rec
            inc hl
            bit 7, [hl]
            jr nz, .nx
            ld a, c
            add a
            add a
            add a
            ld b, a
            add a
            add b                           ; 24 i
            add 16
            ld e, a                         ; y
            ld a, [bs_act]
            cp c
            ld d, 144 + 8
            jr nz, .x
            ld d, 136 + 8
.x:         ld a, c                         ; OAM entry 6 i
            add a
            ld b, a
            add a
            add b
            add a
            add a
            ld l, a
            ld h, high(oam_buf)
            ld a, c                         ; tile 6 i
            add a
            ld b, a
            add a
            add b
            ld b, a
            push bc
            ld c, 3
.r:         ld a, e
            ld [hl+], a
            ld a, d
            ld [hl+], a
            ld a, b
            ld [hl+], a
            inc b
            ld a, $08                       ; VRAM bank 1, palette 0
            ld [hl+], a
            ld a, e
            ld [hl+], a
            ld a, d
            add 8
            ld [hl+], a
            ld a, b
            ld [hl+], a
            inc b
            ld a, $08
            ld [hl+], a
            ld a, e
            add 8
            ld e, a
            dec c
            jr nz, .r
            pop bc
.nx:        inc c
            ld a, c
            cp 4
            jr nz, .m
            ret
; HL = the record of character A (B_CH + $40 A)
bs_rec:     rrca
            rrca
            ld l, a
            and $C0
            add low(B_CH)
            ld e, a
            ld a, l
            and 3
            adc high(B_CH)
            ld h, a
            ld l, e
            ret

; ---- the party window (rows 12-17): name, hp / max per member
bs_pwin:    ld de, $0C00                    ; row 12, column 0
            ld bc, $0614                    ; 6 x 20
            call bs_win
            ld c, 0
.m:         push bc
            ld a, c
            add 13
            ld d, a
            ld e, 2
            ld a, c                         ; the name: the save page +6 (6 letters, FF3 codes)
            call bs_choff
            add 6
            ld l, a
            ld h, $D1
            ld b, 6
.n:         ld a, [hl+]
            push hl
            call bs_ff3char
            call bs_putc
            pop hl
            inc e
            dec b
            jr nz, .n
            pop bc
            push bc
            ld a, c
            call bs_rec
            ld a, l
            add 3
            ld l, a
            jr nc, .h
            inc h
.h:         ld a, [hl+]
            ld b, [hl]
            inc hl
            push hl
            ld l, a
            ld h, b
            ld e, 9
            call bs_num4
            ld a, '/'
            call bs_putc
            inc e
            pop hl
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            call bs_num4
            pop bc
            inc c
            ld a, c
            cp 4
            jr nz, .m
            ret
; an FF3 text code -> our font (ASCII) through C_FF3ASC (B_OWN)
bs_ff3char: ld l, a
            ld h, high(C_FF3ASC)
            ld a, l
            add low(C_FF3ASC)
            ld l, a
            jr nc, .s
            inc h
.s:         ld a, B_OWN
            jp far_byte

; ---- shadow writes. bs_putc: A at row D, column E (window cell); bs_num4: HL right-aligned
; in 4 cells from E (E moves on); bs_puts: the string at BS_STR (0 end) from (D, E)
bs_putc:    push hl
            push bc
            push af
            call bs_cell
            pop af
            ld [hl], a
            ld bc, SH_A - SH_T
            add hl, bc
            ld [hl], ATTR_FRAME
            ld a, d
            ld hl, SH_D
            call bs_hl_a
            ld [hl], 1
            pop bc
            pop hl
            ret
bs_cell:    ld l, d                         ; HL = SH_T + 20 D + E
            ld h, 0
            add hl, hl
            add hl, hl
            push de
            ld d, h
            ld e, l
            add hl, hl
            add hl, hl
            add hl, de
            pop de
            ld a, e
            call bs_hl_a
            ld bc, SH_T
            add hl, bc
            ret
bs_num4:    push de
            call bs_dec                     ; -> bs_numb (4 digits, leading spaces)
            pop de
            ld hl, bs_numb
            ld b, 4
.c:         ld a, [hl+]
            push bc
            push hl
            call bs_putc
            pop hl
            pop bc
            inc e
            dec b
            jr nz, .c
            ret
bs_puts:    ld hl, BS_STR
.c:         ld a, [hl+]
            and a
            ret z
            push hl
            call bs_putc
            pop hl
            inc e
            ld a, e
            cp 19
            jr c, .c
            ret
; HL (0-9999) -> bs_numb: 4 characters, leading spaces
bs_dec:     ld de, bs_numb
            ld bc, -1000
            call .d
            ld bc, -100
            call .d
            ld bc, -10
            call .d
            ld a, l
            add '0'
            ld [de], a
            ld hl, bs_numb                  ; leading zeros -> spaces
            ld b, 3
.z:         ld a, [hl]
            cp '0'
            ret nz
            ld [hl], ' '
            inc hl
            dec b
            jr nz, .z
            ret
.d:         ld a, '0' - 1
.l:         inc a
            add hl, bc
            jr c, .l
            push af
            ld a, l                         ; (undo the last)
            sub c
            ld l, a
            ld a, h
            sbc b
            ld h, a
            pop af
            ld [de], a
            inc de
            ret

; a window: (D row, E column), B rows x C columns; frame + spaces
bs_win:     push de
            ld a, FR_TL
            call bs_putc
            inc e
            ld a, c
            sub 2
.t:         push af
            ld a, FR_T
            call bs_putc
            pop af
            inc e
            dec a
            jr nz, .t
            ld a, FR_TR
            call bs_putc
            pop de
            push de
            ld a, b
            sub 2
.m:         push af
            inc d
            push de
            ld a, FR_L
            call bs_putc
            inc e
            ld a, c
            sub 2
.s:         push af
            ld a, ' '
            call bs_putc
            pop af
            inc e
            dec a
            jr nz, .s
            ld a, FR_R
            call bs_putc
            pop de
            pop af
            dec a
            jr nz, .m
            inc d
            ld a, FR_BL
            call bs_putc
            inc e
            ld a, c
            sub 2
.b:         push af
            ld a, FR_B
            call bs_putc
            pop af
            inc e
            dec a
            jr nz, .b
            ld a, FR_BR
            call bs_putc
            pop de
            ret

; the top window (rows 0-3) over the monsters; bs_topoff puts the monsters back
bs_top:     ld de, 0
            ld bc, $0414
            jp bs_win
bs_topoff:  ld hl, MON_T
            ld de, SH_T
            ld bc, 80
            call memcpy
            ld hl, MON_A
            ld de, SH_A
            ld bc, 80
            call memcpy
            ld hl, SH_D
            ld a, 1
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl], a
            ret

; ---- a frame: wait for V-Blank, copy dirty rows (4 at most), sprites, sound, the pad
bs_frame:   call wait_vbl
            call bs_vrows
            call hram_dma
            call snd_frame
            call read_pad
            ret
bs_vrows:   ld c, 0                         ; row
            ld b, 2                         ; rows this frame (V-Blank: two fit)
.r:         ld a, c
            ld hl, SH_D
            call bs_hl_a
            ld a, [hl]
            and a
            jr z, .n
            ld [hl], 0
            push bc
            call bs_vrow
            pop bc
            dec b
            ret z
.n:         inc c
            ld a, c
            cp 18
            jr nz, .r
            ret
bs_vrow:    ld l, c                         ; SH_T + 20 C -> $9800 + 32 C
            ld h, 0
            add hl, hl
            add hl, hl
            ld d, h
            ld e, l
            add hl, hl
            add hl, hl
            add hl, de
            ld de, SH_T
            add hl, de
            push hl
            ld l, c
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, $9800
            add hl, de
            ld d, h
            ld e, l
            pop hl
            xor a
            ldh [rVBK], a
            push de
            push hl
            ld b, 20
.t:         ld a, [hl+]
            ld [de], a
            inc e
            dec b
            jr nz, .t
            pop hl
            pop de
            ld bc, SH_A - SH_T
            add hl, bc
            ld a, 1
            ldh [rVBK], a
            ld b, 20
.a:         ld a, [hl+]
            ld [de], a
            inc e
            dec b
            jr nz, .a
            xor a
            ldh [rVBK], a
            ret
; all rows now (under the load guard: H-Blank / V-Blank only)
bs_vall:    ld hl, SH_D
            ld b, 18
            ld a, 1
.d:         ld [hl+], a
            dec b
            jr nz, .d
            ld c, 0
.r:         push bc
            call wait_vbl
            call bs_vrow
            pop bc
            inc c
            ld a, c
            cp 18
            jr nz, .r
            ld hl, SH_D
            ld b, 18
            xor a
.c:         ld [hl+], a
            dec b
            jr nz, .c
            ret

; ---- palettes: BG 0 / 1 the monster set's two (2E/8C00: 3 colours + black), BG 7 the windows
bs_palette: ld a, [$DD69]                   ; (cgb_pal is in work RAM bank 1)
            ld [bs_tmp], a
            ld a, [$DD6A]
            ld [bs_tmp + 1], a
            ld a, 1
            ldh [rSVBK], a
            ld a, [bs_tmp]
            ld hl, cgb_pal
            call bs_mpal
            ld a, [bs_tmp + 1]
            ld hl, cgb_pal + 8
            call bs_mpal
            call wait_vbl
            call pal_apply
            ld a, 2
            ldh [rSVBK], a
            ret
bs_mpal:    push hl
            ld l, a
            ld h, 0
            ld d, h
            ld e, l
            add hl, hl
            add hl, de
            ld de, $8C00 - $4000
            add hl, de
            ld de, bs_tmp + 4
            ld bc, 3
            ld a, B_BDAT2
            call far_copy
            pop de
            ld a, $0F                       ; black
            call .c
            ld hl, bs_tmp + 4
            ld b, 3
.l:         ld a, [hl+]
            push hl
            push bc
            call .c
            pop bc
            pop hl
            dec b
            jr nz, .l
            ret
.c:         and $3F                         ; NES colour A -> RGB555 at DE
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
            ret

; ---- back to the field (it reloads its map)
bs_leave:   ld c, 2                         ; the save page back to bank 1
            call bs_page
            xor a
            ld [bs_live], a
            ld a, 1
            ldh [rSVBK], a
            ret

section wram, $C520
bs_live:    ds 1
bs_id:      ds 2
bs_bg:      ds 1
bs_tb:      ds 4                            ; first BG tile per monster type
bs_mi:      ds 4
bs_ja:      ds 2
bs_t:       ds 1
bs_x:       ds 1
bs_y:       ds 1
bs_n:       ds 1
bs_pal:     ds 1
bs_act:     ds 1                            ; the member stepping forward ($FF none)
bs_numb:    ds 4
bs_tmp:     ds 8
bs_seed:    ds 1
bs_cnt:     ds 1
bs_pos:     ds 24
