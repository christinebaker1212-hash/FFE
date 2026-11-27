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
            ld a, [$D8C3]                   ; (a back attack: everything mirrored)
            cp $88
            ld a, 0
            jr nz, .bk
            inc a
.bk:        ld [bs_bk], a
            xor a
            ldh [snd_isr], a
            ldh [rSTAT], a
            ld [guard_on], a
            xor a                           ; no scroll in a battle
            ldh [rSCX], a
            ldh [rSCY], a
            xor a                           ; (no top window yet, no summon in the BG cells)
            ld [bs_topon], a
            ld [an_sbv], a
            ld [an_sbd], a
            call bs_vall
            call bs_bossin                  ; (a boss: its tiles blank, then its entry: 2F/B486)
            call bs_palette
            call bs_bossin2
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
            call bs_ilv                     ; (3D/BC12: the inventory in id / count pairs)
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
.party:     ld a, 1                         ; the party: OBJ tile 0 blank, the characters'
            ldh [rVBK], a                   ;   tiles loaded by bs_party (bs_cgt)
            ld hl, $8000
            ld b, 16
            xor a
.p0:        ld [hl+], a
            dec b
            jr nz, .p0
            ld [an_pdx], a                  ; (A = 0)
            ld [an_bgm], a
            ld [an_pfl], a
            ld hl, an_pxo                   ; (no member offsets / frames of their own)
            ld b, 8
.po:        ld [hl+], a
            dec b
            jr nz, .po
            ld hl, an_pf
            ld b, 4
            ld a, $FF
.pf:        ld [hl+], a
            dec b
            jr nz, .pf
            ld [an_cf], a
            ld [an_hc], a
            ld hl, bs_gt
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl], a
            ld hl, C_SPRDIG                 ; digits / Miss (our tiles, B_OWN), FF3's hand
            ld de, $8000 + 16 * SPR_DIG
            ld bc, 16 * 16
            ld a, B_OWN
            call far_copy
            call hand_tiles
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
bs_draw:    call bs_attrd
            ld hl, MON_T                    ; blank
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
            xor a                           ; its palettes: 9 x 6 blocks
            ld [bs_t], a
            ld [bs_j], a
            ld a, 18
            ld [bs_w], a
            ld hl, MON_A
.ba:        ld c, 0
.bb:        ld a, c
            call bs_tpal
            ld [hl+], a
            inc c
            ld a, c
            cp 18
            jr nz, .bb
            inc hl
            inc hl
            ld a, [bs_j]
            inc a
            ld [bs_j], a
            cp 12
            jr nz, .ba
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
            ld a, [bs_mi + 3]
            swap a
            and 15
            ld [bs_w], a
            xor a
            ld [bs_j], a
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
            ld a, c
            push hl
            ld hl, bs_x
            sub [hl]
            pop hl
            call bs_tpal
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
            ld a, [bs_j]
            inc a
            ld [bs_j], a
            inc c
            dec b
            jr nz, .r
.x:         ret

; A = the column within the monster -> its palette (0 / 1): FF3's attribute bits ($7D17 + 4 x
; type, a bit per 16 x 16 block, most significant first, row pairs in order; 2F/A6FB); keeps BC
; DE HL
bs_tpal:    push bc
            push de
            push hl
            srl a
            ld e, a                         ; the block column
            ld a, [bs_w]
            srl a
            ld d, a                         ; blocks per row
            ld a, [bs_j]
            srl a
            ld b, a
            ld a, e
            inc b
.k:         dec b
            jr z, .kk
            add d
            jr .k
.kk:        ld c, a                         ; k
            ld a, [bs_t]
            add a
            add a
            ld e, a
            ld a, c
            srl a
            srl a
            srl a
            add e
            ld hl, $DD17
            call bs_hl_a
            ld b, [hl]
            ld a, c
            and 7
            inc a
.b:         rl b
            dec a
            jr nz, .b
            ld a, 0
            rla
            pop hl
            pop de
            pop bc
            ret

; FF3's monster attribute data -> $7D17 (2F/A857: per monster id 4 bytes by graphics size from
; 2E/8F20.., a boss's 8 bytes from 2E/8FC0 + 7 x id; inverted when the id's attribute byte has bit 7)
bs_attrd:   ld a, [$DD7B]
            cp 9
            jr nz, .m
            ld a, [$DD74]
            and $3F
            ld l, a
            ld h, 0
            ld d, h
            ld e, l
            add hl, hl
            add hl, hl
            add hl, hl
            ld a, l
            sub e
            ld l, a
            ld a, h
            sbc d
            ld h, a                         ; 7 x id
            ld de, $8FC0 - $4000
            add hl, de
            ld de, $DD17
            ld bc, 8
            ld a, B_BSET
            call far_copy
            ld a, [$DD74]
            ld c, 8
            ld hl, $DD17
            jr .inv
.m:         ld c, 0
.n:         push bc
            ld a, c
            ld hl, $DD6B
            call bs_hl_a
            ld a, [hl]
            cp $FF
            jr z, .nx
            ld a, c
            add a
            ld hl, $DD73
            call bs_hl_a
            ld a, [hl+]
            and $E0
            swap a
            ld [bs_tmp], a                  ; 2 x size class
            ld a, [hl]
            ld [bs_tmp + 1], a              ; the attribute byte
            ld a, [bs_tmp]
            ld hl, $A8D8 - $4000            ; 2F/A8D8: the data's address by size
            call bs_hl_a
            ld de, bs_tmp + 2
            ld bc, 2
            ld a, B_BSET
            call far_copy
            ld a, [bs_tmp]                  ; 2F/A8E4: the length by size
            srl a
            ld hl, $A8E4 - $4000
            call bs_hl_a
            ld a, B_BSET
            call far_byte
            ld b, a
            ld a, [bs_tmp + 1]
            and $3F
            ld c, a
            xor a
.mu:        add c
            dec b
            jr nz, .mu
            ld hl, bs_tmp + 2
            ld e, [hl]
            inc hl
            ld d, [hl]
            ld h, d
            ld l, e
            call bs_hl_a
            ld a, h
            sub $40
            ld h, a
            pop bc
            push bc
            ld a, c
            add a
            add a
            add low($DD17)
            ld e, a
            ld d, high($DD17)
            push de
            ld bc, 4
            ld a, B_BSET
            call far_copy
            pop hl
            ld a, [bs_tmp + 1]
            ld c, 4
            call .inv
.nx:        pop bc
            inc c
            ld a, c
            cp 4
            jr nz, .n
            ret
.inv:       bit 7, a
            ret z
.i:         ld a, [hl]
            cpl
            ld [hl+], a
            dec c
            jr nz, .i
            ret

; ---- the party's sprites (members at x 144, y 24 i; acting: x 136)
bs_party:   ld hl, oam_buf
            ld b, 160
            xor a
.z:         ld [hl+], a
            dec b
            jr nz, .z
            ld c, 0
.m:         push bc
            call bs_cframe                  ; the frame by the status (2F/B607), its tiles
            ld [bs_tmp + 6], a
            pop bc
            ld a, [an_cf]                   ; (the attacker's frame while it swings)
            cp $FF
            jr z, .nf
            ld a, [an_c]
            cp c
            jr nz, .nf
            ld a, [an_cf]
            ld [bs_tmp + 6], a
.nf:        ld a, c                         ; (a member's own frame / offsets in an animation;
            ld hl, an_pf                    ;   $FE: not shown; in the air after Jump)
            call bs_hl_a
            ld a, [hl]
            cp $FF
            jr z, .nf2
            cp $FE
            jp z, .skip
            ld [bs_tmp + 6], a
.nf2:       ld a, c
            ld hl, $DE22
            call bs_hl_a
            ld a, [hl]
            and a
            jp nz, .skip
            push bc
            ld a, c                         ; y = 24 i, x = 144 (136 stepping forward)
            add a
            add a
            add a
            ld b, a
            add a
            add b
            ld e, a
            ld a, [bs_act]
            cp c
            ld d, 144
            jr nz, .x
            ld d, 136
.x:         ld a, [an_hc]                   ; (knocked back by a hit)
            cp c
            jr nz, .x2
            ld a, [an_dx]
            add d
            ld d, a
.x2:        ld a, [an_pdx]                  ; (the party shaken)
            add d
            ld d, a
            ld a, c
            ld hl, an_pxo
            call bs_hl_a
            ld a, [hl]
            add d
            ld d, a
            ld a, c
            ld hl, an_pyo
            call bs_hl_a
            ld a, [hl]
            add e
            ld e, a
            ld a, [bs_tmp + 6]
            call bs_cdraw
            pop bc
.skip:      inc c
            ld a, c
            cp 4
            jr nz, .m
            ret

; character C's frame (FF3's $7D83, 2F/B607) from its status for display ($78BB): dead 9 (toad /
; mini $10), stone 0, paralysed / asleep / confused / any second status 3 (toad / mini $0C),
; else 2 ($0B); its tiles reloaded when its graphics type changes (2F/B651: 0 normal, 1 dead, 2
; toad, 3 mini)
bs_cframe:  ld a, c
            add a
            ld hl, $D8BB
            call bs_hl_a
            ld a, [hl+]
            ld d, a                         ; D = status 1, E = status 2
            ld e, [hl]
            ld b, 0                         ; graphics type
            bit 2, d
            jr z, .nt
            ld b, 2
.nt:        bit 0, d
            jr z, .nm
            ld b, 3
.nm:        bit 7, d
            jr z, .alive
            ld a, b
            and a
            jr nz, .td
            ld b, 1
.td:        call bs_cgt
            ld a, d
            and 5
            ld a, $10
            ret nz
            ld a, 9
            ret
.alive:     call bs_cgt
            bit 6, d                        ; stone: kneeling (FF3 draws it in the BG from the
            jr nz, .kn                      ;   kneeling tiles 28/8080, BG palette 3: here OBJ 5)
            ld a, d
            and $32
            or e
            jr z, .st
.kn:        ld a, d
            and 5
            ld a, $0C
            ret nz
            ld a, 3
            ret
.st:        ld a, d
            and 5
            ld a, $0B
            ret nz
            ld a, 2
            ret
; character C's graphics as type B (OBJ tiles 1 + 14 C, VRAM bank 1; keeps BCDE)
bs_cgt:     ld a, c
            ld hl, bs_gt
            call bs_hl_a
            ld a, [hl]
            cp b
            ret z
            ld [hl], b
            push bc
            push de
            call bs_jobaddr
            pop de
            pop bc
            push bc
            push de
            ld a, c                         ; DE = $8000 + 16 (1 + 14 C)
            add a
            ld e, a
            add a
            add a
            add a
            sub e
            inc a
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
            ld a, b
            ld bc, 14 * 16
            and a
            jr z, .go
            ld bc, 6 * 16                   ; dead: 6 tiles from the job's $240
            push de
            ld de, $240
            add hl, de
            pop de
            dec a
            jr z, .go
            ld hl, $7F80                    ; toad (29/BF80) / mini (29/BF00): 8 tiles
            ld bc, 8 * 16
            dec a
            jr z, .go
            ld hl, $7F00
.go:        ld a, [guard_on]                ; (inside a guarded load: as it is)
            and a
            jr nz, .in
            push hl
            push bc
            push de
            ldh a, [rLCDC]
            bit 7, a
            call nz, wait_vbl
            ld a, 1
            ld [guard_on], a
            ld a, $20
            ldh [rSTAT], a
            pop de
            pop bc
            pop hl
            call .cp
            xor a
            ldh [rSTAT], a
            ld [guard_on], a
            pop de
            pop bc
            ret
.in:        call .cp
            pop de
            pop bc
            ret
.cp:        ld a, 1
            ldh [rVBK], a
            ld a, B_CGFX
            call far_copy
            xor a
            ldh [rVBK], a
            ret
; frame A (bit 7: flipped) of character C at screen (D, E) into OAM entries 6 C (32/9111: the
; frame's six tiles, absolute from bit 7, else from the character's first tile 1 + 14 C; the
; sprites' offsets and flips by the frame's set)
bs_cdraw:   ld b, a
            and $7F
            ld [cf_f], a
            ld a, d
            ld [cf_x], a
            ld a, e
            ld [cf_y], a
            ld a, c                         ; the tile base and attributes
            add a
            ld e, a
            add a
            add a
            add a
            sub e
            inc a
            ld [cf_b], a
            push bc
            ld a, c
            ld hl, $DD93
            call bs_hl_a
            ld a, [hl]
            and 3
            or $08
            ld [cf_a], a
            ld a, c                         ; (stone: OBJ palette 5, FF3's BG palette 3)
            add a
            ld hl, $D8BB
            call bs_hl_a
            ld a, [hl]
            and $C0
            cp $40
            jr nz, .ns
            ld a, $0D
            ld [cf_a], a
.ns:        pop bc
            ld a, [cf_f]
            ld hl, cf_set
            bit 7, b
            jr z, .s
            ld hl, cf_setf
.s:         call bs_hl_a
            ld a, [hl]
            add a                           ; x 24
            add a
            add a
            ld e, a
            add a
            add e
            ld hl, cf_pos
            call bs_hl_a
            ld d, h                         ; DE = the set's 6 x (y, -, attributes, x)
            ld e, l
            ld a, [cf_f]                    ; HL = the frame's 6 tiles
            ld b, a
            add a
            add b
            add a
            ld hl, cf_tiles
            call bs_hl_a
            ld a, c                         ; BC = OAM entry 6 C
            add a
            ld b, a
            add a
            add b
            add a
            add a
            ld c, a
            ld b, high(oam_buf)
            ld a, 6
            ld [cf_n], a
.k:         ld a, [de]                      ; y: the screen's + offset + 1 (NES OAM y) + 16
            inc de
            push hl
            ld hl, cf_y
            add [hl]
            add 17
            ld [bc], a
            inc c
            inc de
            ld a, [de]                      ; x after: attributes ($40 h-flip)
            inc de
            ld [cf_t], a
            ld a, [de]
            inc de
            ld hl, cf_x
            add [hl]
            add 8
            ld [bc], a
            inc c
            pop hl
            ld a, [hl+]                     ; the tile
            bit 7, a
            jr z, .r
            and $7F
            jr .t
.r:         push hl
            ld hl, cf_b
            add [hl]
            pop hl
.t:         ld [bc], a
            inc c
            ld a, [cf_t]
            and $40
            rra
            push hl
            ld hl, cf_a
            or [hl]
            pop hl
            ld [bc], a
            inc c
            ld a, [cf_n]
            dec a
            ld [cf_n], a
            jr nz, .k
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
bs_top:     ld de, 0                        ; (18 wide: the party's column stays clear)
            ld bc, $0412
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
bs_frame:   call bs_opre                    ; (a back attack: the sprites mirrored)
            call wait_vbl
            call bs_vrows
            call hram_dma
            call bs_opre
            call snd_frame
            call read_pad
            ret
bs_vrows:   ld c, 0                         ; row
            ld b, 2                         ; rows this frame (V-Blank: two fit; none
.r:         ldh a, [rLY]                    ;   from line 150, so a row ends inside it)
            cp 150
            ret nc
            cp 144
            ret c
            ld a, c
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
bs_vrow:    ld a, [bs_bk]                   ; (a back attack: the battlefield's rows mirrored)
            and a
            jr z, .nm
            ld a, c
            cp 12
            jp c, bs_vrowm
.nm:        ld l, c                         ; SH_T + 20 C -> $9800 + 32 C
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
bs_palette: ld c, 0                         ; 2E/9E64: rows and jobs, the status buffer
.cj:        ld a, c
            call bs_choff
            add $0F
            ld l, a
            ld h, $D2
            ld a, [hl]
            and 1
            ld b, a
            ld a, c
            ld hl, $DD8F
            call bs_hl_a
            ld [hl], b
            ld a, c
            call bs_choff
            ld l, a
            ld h, $D1
            ld b, [hl]
            ld a, c
            ld hl, $DD8B
            call bs_hl_a
            ld [hl], b
            inc c
            ld a, c
            cp 4
            jr nz, .cj
            ld hl, $D8BB
            ld de, $DD9B
            ld bc, 8
            call memcpy
            ld a, [$DD69]                   ; (cgb_pal is in work RAM bank 1)
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
            call bs_objpal
            call wait_vbl
            call pal_apply
            ld a, $80 | 4 * 8               ; OBJ 4 (ours): green numbers
            ldh [rOCPS], a
            ld hl, bs_green
            ld b, 8
.g:         ld a, [hl+]
            ldh [rOCPD], a
            dec b
            jr nz, .g
            ld a, $80 | 5 * 8               ; OBJ 5: the windows' palette (stone characters, as
            ldh [rOCPS], a                  ;   FF3 draws them with BG palette 3)
            ld hl, cgb_pal + 64
            ld b, 8
.sp:        ld a, [hl+]
            ldh [rOCPD], a
            dec b
            jr nz, .sp
            ld a, 2
            ldh [rSVBK], a
            ld de, $DD93
            jp bs_jpals
; OBJ palettes 0-2: the characters' battle palettes ($FC-$FE), 3: the cursor's ($FF), into
; cgb_pal (work RAM bank 1 mapped)
bs_objpal:  ld a, $FC
.o:         push af
            sub $FC
            add a
            add a
            add a
            add low(cgb_pal + 32)
            ld l, a
            ld h, high(cgb_pal + 32)
            jr nc, .o2
            inc h
.o2:        pop af
            push af
            call bs_mpal
            pop af
            inc a
            jr nz, .o
            ret
; the characters' palette ids -> DE (4 bytes; 2E/9E01: 2E/9E4E + job, 2E/9E4A + member for the
; Onion Kid); the save page at $D100 (either work RAM bank)
bs_jpals:   ld c, 0
.j:         push de
            ld a, c
            call bs_choff
            ld l, a
            ld h, $D1
            ld a, [hl]
            and a
            ld hl, $9E4E - $4000
            jr nz, .j1
            ld hl, $9E4A - $4000
            ld a, c
.j1:        call bs_hl_a
            push bc
            ld a, B_BSET
            call far_byte
            pop bc
            pop de
            ld [de], a
            inc de
            inc c
            ld a, c
            cp 4
            jr nz, .j
            ret
bs_green:   dw $0000, $0000, $0140, $03E8
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

; ---- FF3's update character equipment (3E/D10B -> 34/803D: battle algorithm $05) from the field
; menu: C = member; the save page goes to work RAM bank 2 for it and comes back (FF3's zero page
; and battle variables at $C400-$C7FF meanwhile)
bs_fequip:  push bc
            ld c, 1
            call bs_page
            ld a, 2
            ldh [rSVBK], a
            ld hl, fe_88E1
            ld a, B_BAT2
            call far_call
            pop bc
            ld a, c
            ld [BZ + $52], a
            ld hl, fe_AA16
            ld a, B_BAT
            call far_call
            ld c, 2
            call bs_page
            ld a, 1
            ldh [rSVBK], a
            ret

; ---- back to the field (it reloads its map)
bs_leave:   call bs_dlv                     ; (3D/BC2D: the inventory as the field keeps it)
            ld c, 2                         ; the save page back to bank 1
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
bs_act:     ds 1                            ; the member stepping forward ($FF none)
bs_numb:    ds 4
bs_tmp:     ds 8
bs_seed:    ds 1
bs_cnt:     ds 1
bs_pos:     ds 24
bs_j:       ds 1                            ; the row within a monster (its palette bits)
bs_w:       ds 1                            ; the monster's width in tiles

section bank B_BSCR, $5000
; ---- FF3's pre-attack flash (2F/B024, 34/8545): the attacking monster (slot A) in the windows'
; palette every other frame, 8 frames (not for Flare Wave: $7E9D = 9); the attributes go
; straight to VRAM behind the line guard (the shadow keeps the monster's own)
bs_flash:   ld [fl_s], a
            ld a, [$DE9D]
            cp 9
            ret z
            call bs_srect
            ret c
.st:        ld hl, SH_D                     ; (the windows up first)
            ld b, 18
            xor a
.sd:        or [hl]
            inc hl
            dec b
            jr nz, .sd
            and a
            jr z, .go
            call bs_frame
            jr .st
.go:        xor a
            ld [fl_f], a
.l:         call bs_opre
            call wait_vbl
            call hram_dma
            call bs_opre
            ld a, 1
            ld [guard_on], a
            ld a, $20
            ldh [rSTAT], a
            call .rect
            xor a
            ldh [rSTAT], a
            ld [guard_on], a
            call snd_frame
            call read_pad
            ld hl, fl_f
            inc [hl]
            ld a, [hl]
            cp 8
            jr nz, .l
            call wait_vbl                   ; (its own colours again)
            ld a, 1
            ld [guard_on], a
            ld a, $20
            ldh [rSTAT], a
            call .rect
            xor a
            ldh [rSTAT], a
            ld [guard_on], a
            ret
.rect:      ld a, [fl_y]                    ; (cells through bs_mcell: a back attack mirrored)
            ld [bs_rr], a
            ld a, [fl_h]
            ld [bs_rh], a
.r:         ld a, [fl_x]
            ld [bs_rc], a
            ld a, [fl_w]
            ld [bs_rw], a
.c:         ld a, [bs_rr]                   ; SH_A + 20 y + x
            ld l, a
            add a
            add a
            ld e, a
            add a
            add a
            add e
            ld e, a
            ld a, [bs_rc]
            add e
            ld e, a
            ld d, 0
            ld hl, SH_A
            add hl, de
            ld c, [hl]
            ld a, [fl_f]                    ; odd frames: palette 7, else the monster's
            and 1
            jr z, .p
            ld a, c
            and $F8
            or 7
            ld c, a
.p:         ld a, [bs_rr]
            ld d, a
            ld a, [bs_rc]
            ld e, a
            push bc
            call bs_mcell
            ld a, b
            pop bc
            jr z, .s
            xor c
            ld c, a
            ld a, 1
            ldh [rVBK], a
            ld [hl], c
            xor a
            ldh [rVBK], a
.s:         ld hl, bs_rc
            inc [hl]
            ld hl, bs_rw
            dec [hl]
            jr nz, .c
            ld hl, bs_rr
            inc [hl]
            ld hl, bs_rh
            dec [hl]
            jr nz, .r
            ret
; the slot fl_s's cells in the monster area (fl_x, fl_y, fl_w, fl_h; the top window's rows 0-3
; left out while it shows); C: none
bs_srect:   ld a, [$DD7B]
            cp 9
            jr nz, .m
            xor a                           ; a boss: the whole area
            ld [fl_x], a
            ld [fl_y], a
            ld a, 18
            ld [fl_w], a
            ld a, 12
            ld [fl_h], a
            jr .clip
.m:         ld a, [fl_s]
            ld hl, $DDA7
            call bs_hl_a
            ld a, [hl]
            cp $FF
            scf
            ret z
            ld hl, $DD6B
            call bs_hl_a
            ld a, [hl]
            call bs_minfo
            ld a, [fl_s]
            ld b, a
            add a
            add b
            ld hl, bs_pos
            call bs_hl_a
            ld a, [hl+]
            sub 2
            ld [fl_x], a
            ld a, [hl]
            sub 6
            ld [fl_y], a
            ld a, [bs_mi + 3]
            ld b, a
            and 15
            ld [fl_h], a
            ld a, b
            swap a
            and 15
            ld b, a
            ld a, [fl_x]                    ; (18 columns at most)
            add b
            cp 19
            jr c, .w
            ld a, 18
.w:         ld hl, fl_x
            sub [hl]
            ld [fl_w], a
.clip:      ld a, [fl_y]                    ; rows to 11, from 4 under the top window
            ld hl, fl_h
            add [hl]
            cp 13
            jr c, .b
            ld a, 12
.b:         ld b, a                         ; B = the end row
            ld a, [bs_topon]
            and a
            ld a, [fl_y]
            jr z, .t
            cp 4
            jr nc, .t
            ld a, 4
.t:         ld [fl_y], a
            ld c, a
            ld a, b
            sub c
            jr z, .no
            jr c, .no
            ld [fl_h], a
            ld a, [fl_w]
            and a
            jr z, .no
            and a
            ret
.no:        scf
            ret

section wram, $C590
fl_s:       ds 1
fl_f:       ds 1
fl_x:       ds 1
fl_y:       ds 1
fl_w:       ds 1
fl_h:       ds 1

section bank B_BSCR, $5600
cf_tiles:   ds 126                          ; (32/972E: 21 frames x 6 tiles)
cf_pos:     ds 144                          ; (32/91D7: 6 sets x 6 x (y, tile, attributes, x))
cf_set:     ds 21                           ; (32/926B: the frame's set; 9280 flipped)
cf_setf:    ds 21

section wram, $C58B
bs_gt:      ds 4                            ; FF3's $7DA3: the graphics type loaded

section wram, $C596
cf_f:       ds 1
cf_x:       ds 1
cf_y:       ds 1
cf_b:       ds 1
cf_a:       ds 1
cf_t:       ds 1
cf_n:       ds 1
