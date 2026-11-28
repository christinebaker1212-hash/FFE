; ---- bst.s (bank CODE11): Extras (owner, 2026-11-28: FF1's Sound Test and Bestiary in FF3) in the
; menus' UI. Extras: Sound Test, Bestiary. Sound Test: every one of FF3's 63 songs through the game's
; own driver (names: soundtest.py), left / right a song, A plays it, B back (the map's song again).
; Bestiary (FF1's): every monster a battle has shown (bs_mark, from the battle's monster set: cart
; RAM bank 0 $AE00, "BE", 32 bytes of bits, a check; the RAM on only around the copy); the list
; (numbers, the met ones' names), a page per monster: its battle picture as FF3 draws it (tiles,
; its two palettes by 2 x 2 blocks; bosses with their tilemaps: bestiary.py), LV, HP, EXP, Gil.
BS_N       = $E7                ; FF3's monsters $00-$E6 (bestiary.py N)
BS_AT      = $AE00              ; cart RAM bank 0: $42, $45, 32 bytes, their sum's complement
BS_SEEN    = $DFE0              ; WRAM 2: the bits while the Bestiary shows
BS_REC     = $D980              ; WRAM 2: the monster's BS_GFX record (32)
BS_ST      = $D9F0              ; WRAM 2: its BS_STAT record (8)
BS_ROWS    = 13

; ---- the battle (btl.s mon_set): the set's monsters marked as met
bs_mark:    call cf_on
            ld a, [BS_AT]
            cp $42
            jr nz, .new
            ld a, [BS_AT + 1]
            cp $45
            jr z, .ok
.new:       ld hl, BS_AT                    ; (none yet: empty)
            ld a, $42
            ld [hl+], a
            ld a, $45
            ld [hl+], a
            ld b, 33
            xor a
.z:         ld [hl+], a
            dec b
            jr nz, .z
.ok:        ld hl, W7 + $7D6B               ; the set's four monsters ($FF none)
            ld c, 4
.m:         ld a, [hl+]
            cp BS_N
            jr nc, .n
            push hl
            push bc
            call bs_bit
            ld a, [hl]
            or b
            ld [hl], a
            pop bc
            pop hl
.n:         dec c
            jr nz, .m
            ld hl, BS_AT + 2                ; the check
            ld b, 32
            xor a
.s:         add a, [hl]
            inc hl
            dec b
            jr nz, .s
            cpl
            ld [hl], a
            jp cf_off
; A = monster -> HL = its byte (cart RAM), B = its bit
bs_bit:     ld b, a
            srl a
            srl a
            srl a
            add a, low(BS_AT + 2)
            ld l, a
            ld h, high(BS_AT)
            ld a, b
            and 7
            ld b, 1
            jr z, .x
.l:         sla b
            dec a
            jr nz, .l
.x:         ret
; the bits -> BS_SEEN (none or damaged: all clear); bs_cnt = how many
bs_load:    ld hl, BS_SEEN
            ld b, 32
            xor a
.c:         ld [hl+], a
            dec b
            jr nz, .c
            call cf_on
            ld a, [BS_AT]
            cp $42
            jr nz, .x
            ld a, [BS_AT + 1]
            cp $45
            jr nz, .x
            ld hl, BS_AT + 2
            ld b, 32
            xor a
.s:         add a, [hl]
            inc hl
            dec b
            jr nz, .s
            add a, [hl]
            inc a
            jr nz, .x
            ld hl, BS_AT + 2
            ld de, BS_SEEN
            ld bc, 32
            call memcpy
.x:         call cf_off
            xor a
            ld [bs_cnt], a
            ld c, 0
.k:         ld a, c
            call bs_seen
            jr z, .k1
            ld hl, bs_cnt
            inc [hl]
.k1:        inc c
            ld a, c
            cp BS_N
            jr nz, .k
            ret
; A = monster: NZ if met
bs_seen:    push bc
            ld b, a
            srl a
            srl a
            srl a
            add a, low(BS_SEEN)
            ld l, a
            ld h, high(BS_SEEN)
            ld a, b
            and 7
            ld b, [hl]
            inc a
.l:         rr b
            dec a
            jr nz, .l
            sbc a, a
            pop bc
            and a
            ret

; ---- Extras: Sound Test, Bestiary
xm_open:    call u_open                     ; (from the field: opened and closed here)
            call xm_run
            jp u_close
xm_run:     xor a
            ld [xm_cur], a
.re:        call xm_scr
            call u_flush
            call u_fadein
.l:         ld a, [xm_cur]
            add a, a
            add a, 5
            ld c, a
            ld b, 3
            call u_hand
            call wait_vbl
            call u_keys
            ld a, [m_new]
            bit 1, a
            jr nz, .x
            bit 0, a
            jr nz, .a
            and $C0
            jr z, .l
            ld a, [xm_cur]
            xor 1
            ld [xm_cur], a
            ld a, $98
            ld [S49], a
            jr .l
.a:         ld a, $85
            ld [S49], a
            call u_fadeout
            ld a, [xm_cur]
            and a
            jr nz, .bs
            call st_open
            jr .re
.bs:        call bs_open
            jr .re
.x:         ld a, $85
            ld [S49], a
            jp u_fadeout
xm_scr:     call oam_hide
            call u_cls
            ld bc, $0000
            ld de, $1403
            call u_box
            ld bc, $0003
            ld de, $140F
            call u_box
            ld a, UP_LABEL
            ld [u_pal], a
            ld bc, $0101
            ld hl, U_EXT
            call u_text
            ld a, UP_WHITE
            ld [u_pal], a
            ld bc, $0305
            ld hl, U_STT
            call u_text
            ld bc, $0307
            ld hl, U_BST
            call u_text
            ld a, 1
            ld [m_dirty], a
            ret

; ---- the Sound Test: "Song", its number / 63, its name; Now playing after A
st_open:    call oam_hide
            call u_cls
            ld bc, $0000
            ld de, $1403
            call u_box
            ld bc, $0003
            ld de, $140F
            call u_box
            ld a, UP_LABEL
            ld [u_pal], a
            ld bc, $0101
            ld hl, U_STT
            call u_text
            ld bc, $030B                    ; the hints
            ld hl, U_STH0
            call u_text
            ld bc, $030D
            ld hl, U_STH1
            call u_text
            ld bc, $030F
            ld hl, U_STH2
            call u_text
            ld a, UP_WHITE
            ld [u_pal], a
            ld bc, $0305
            ld hl, U_SONG
            call u_text
            call .num
            call u_flush
            call u_fadein
.l:         ld bc, $0305
            call u_hand
            call wait_vbl
            call u_keys
            ld a, [m_new]
            bit 1, a
            jr nz, .x
            bit 0, a
            jr nz, .play
            ld b, 1
            bit 4, a
            jr nz, .ch
            ld b, 62
            bit 5, a
            jr z, .l
.ch:        ld a, [xm_song]                 ; (wraps)
            add a, b
            cp 63
            jr c, .s
            sub 63
.s:         ld [xm_song], a
            ld a, $98
            ld [S49], a
            call .num
            call u_flush
            jr .l
.play:      ld a, [xm_song]
            call snd_song
            ld a, 120                       ; "Now playing"
            ld [u_pool], a
            ld a, UP_YELLOW
            ld [u_pal], a
            ld bc, $0308
            ld hl, U_NOWP
            call u_text
            ld a, UP_WHITE
            ld [u_pal], a
            call u_flush
            jr .l
.x:         ld a, $85
            ld [S49], a
            call u_fadeout
            ld a, 1                         ; (the title's song again: Extras is on the title)
            jp snd_song
.num:       ld bc, $0306                    ; (the song's lines cleared)
.cl:        push bc
            ld a, U_FILL
            call u_cell
            pop bc
            inc b
            ld a, b
            cp 19
            jr nz, .cl
            ld b, 3
            inc c
            ld a, c
            cp 9
            jr nz, .cl
            ld bc, $0805
.c2:        push bc
            ld a, U_FILL
            call u_cell
            pop bc
            inc b
            ld a, b
            cp 19
            jr nz, .c2
            ld a, 80
            ld [u_pool], a
            ld a, [xm_song]                 ; "n / 63"
            inc a
            ld e, a
            ld d, 0
            call u_ntoa
            ld de, mn_buf
            call sts_cp
            ld a, $FF
            ld [de], a
            inc de
            ld a, $C7
            ld [de], a
            inc de
            ld a, $FF
            ld [de], a
            inc de
            ld a, $86
            ld [de], a
            inc de
            ld a, $83
            ld [de], a
            inc de
            xor a
            ld [de], a
            ld bc, $1305
            ld hl, mn_buf
            call u_textr
            ld a, [xm_song]                 ; its name (CODE12)
            ld hl, U_SONGN
            call u_fstr
            ld bc, $0306
            call u_text
            ld a, 1
            ld [m_dirty], a
            ret

; ---- the Bestiary: the list
bs_open:    call bs_load
            xor a
            ld [bs_cur], a
            ld [bs_top], a
.re:        call bs_scr
            call u_flush
            call u_fadein
.l:         ld a, [bs_top]
            ld b, a
            ld a, [bs_cur]
            sub b
            add a, 4
            ld c, a
            ld b, 6
            call u_hand
            call wait_vbl
            call u_keys
            ld a, [m_new]
            bit 1, a
            jr nz, .x
            bit 0, a
            jr nz, .a
            ld b, a
            ld a, [bs_cur]
            bit 6, b
            jr z, .d
            and a
            jr z, .l
            dec a
            jr .s
.d:         bit 7, b
            jr z, .lr
            inc a
            cp BS_N
            jr z, .l
            jr .s
.lr:        bit 4, b                        ; left / right: a page of 13
            jr z, .lf
            add a, BS_ROWS
            cp BS_N
            jr c, .s
            ld a, BS_N - 1
            jr .s
.lf:        bit 5, b
            jr z, .l
            sub BS_ROWS
            jr nc, .s
            xor a
.s:         ld [bs_cur], a
            ld a, $98
            ld [S49], a
            ld a, [bs_top]                  ; (the hand's row in view; scrolled: the rows again)
            ld c, a
            ld a, [bs_cur]
            cp c
            jr nc, .s1
            ld [bs_top], a
            jr .sc
.s1:        sub BS_ROWS - 1
            jr c, .l2
            cp c
            jr c, .l2
            jr z, .l2
            ld [bs_top], a
.sc:        call bs_rows
            call u_flush
.l2:        jp .l
.a:         ld a, [bs_cur]
            call bs_seen
            jr nz, .pg
            ld a, $86
            ld [S49], a
            jp .l
.pg:        ld a, $85
            ld [S49], a
            call u_fadeout
            call bs_page
            jp .re
.x:         ld a, $85
            ld [S49], a
            jp u_fadeout
bs_scr:     call oam_hide
            call u_cls
            ld bc, $0000
            ld de, $1403
            call u_box
            ld bc, $0003
            ld de, $140F
            call u_box
            ld a, UP_LABEL
            ld [u_pal], a
            ld bc, $0101
            ld hl, U_BST
            call u_text
            ld a, UP_WHITE
            ld [u_pal], a
            ld a, [bs_cnt]                  ; met / all
            ld e, a
            ld d, 0
            call u_ntoa
            ld de, mn_buf
            call sts_cp
            ld a, $C7
            ld [de], a
            inc de
            push de
            ld de, BS_N
            call u_ntoa
            pop de
            call sts_cp
            xor a
            ld [de], a
            ld bc, $1301
            ld hl, mn_buf
            call u_textr
bs_rows:    xor a
.r:         ld [bs_k], a
            call bs_row
            ld a, [bs_k]
            inc a
            cp BS_ROWS
            jr nz, .r
            ld a, 1
            ld [m_dirty], a
            ret
; row bs_k: number, name (met) or a dash (pool 12 + 12 k)
bs_row:     ld a, [bs_k]
            add a, 4
            ld c, a
            ld b, 1
.cl:        push bc
            ld a, U_FILL
            call u_cell
            pop bc
            inc b
            ld a, b
            cp 19
            jr nz, .cl
            ld a, [bs_k]
            ld b, a
            add a, a
            add a, b
            add a, a
            add a, a
            add a, 12
            ld [u_pool], a
            ld a, [bs_top]
            ld b, a
            ld a, [bs_k]
            add a, b
            ld [bs_m], a
            cp BS_N
            ret nc
            inc a
            ld e, a
            ld d, 0
            call u_ntoa
            ld a, UP_GREY
            ld [u_pal], a
            ld a, [bs_k]
            add a, 4
            ld c, a
            ld b, 4
            call u_textr
            ld a, [bs_m]
            call bs_seen
            ld hl, U_DASH
            jr z, .t
            ld a, UP_WHITE
            ld [u_pal], a
            ld a, [bs_m]
            ld hl, BS_NAME
            call u_fstr
.t:         ld a, [bs_k]
            add a, 4
            ld c, a
            ld b, 6
            call u_text
            ld a, UP_WHITE
            ld [u_pal], a
            ret

; ---- a monster's page: left / right the next met one, B the list
bs_page:
.re:        call bs_pscr
            call u_flush
            call u_fadein
.l:         call wait_vbl
            call u_keys
            ld a, [m_new]
            and 3
            jr nz, .x
            ld a, [m_new]
            and $30
            jr z, .l
            ld b, 1
            bit 4, a
            jr nz, .n
            ld b, BS_N - 1
.n:         ld a, [bs_cur]                  ; the next met one that way
.f:         add a, b
            cp BS_N
            jr c, .f1
            sub BS_N
.f1:        ld c, a
            push bc
            call bs_seen
            pop bc
            ld a, c
            jr z, .f
            ld [bs_cur], a
            ld a, $98
            ld [S49], a
            call u_fadeout
            jr .re
.x:         ld a, $85
            ld [S49], a
            ld a, [bs_cur]                  ; (the list round it)
            ld [bs_top], a
            cp BS_N - BS_ROWS
            jr c, .t
            ld a, BS_N - BS_ROWS
            ld [bs_top], a
.t:         call u_fadeout
            jp u_mpal                       ; (the pool's tiles and pictures: the UI's again)
; the page: the picture window (0,0,20,14), the values (0,14,20,4)
bs_pscr:    call oam_hide
            call u_cls
            ld bc, $0000
            ld de, $140E
            call u_box
            ld bc, $000E
            ld de, $1404
            call u_box
            ld a, [bs_cur]                  ; its records (CODE12)
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, BS_GFX
            add hl, de
            ld de, BS_REC
            ld bc, 32
            ld a, CODE12
            call rd_copy
            ld a, [bs_cur]
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, BS_STAT
            add hl, de
            ld de, BS_ST
            ld bc, 8
            ld a, CODE12
            call rd_copy
            call bs_pal
            call bs_tiles
            call bs_cells
            xor a                           ; the values (pool 0-39)
            ld [u_pool], a
            ld a, [bs_cur]
            ld hl, BS_NAME
            call u_fstr
            ld bc, $010F
            call u_text
            ld a, UP_LABEL
            ld [u_pal], a
            ld bc, $100F
            ld hl, U_LV
            call u_textr
            ld bc, $0110
            ld hl, U_HP
            call u_text
            ld a, 13
            call .w
            ld bc, $0810
            call u_text
            ld bc, $0E10
            ld hl, U_GIL
            call u_text
            ld a, UP_WHITE
            ld [u_pal], a
            ld a, [BS_ST]
            ld e, a
            ld d, 0
            call u_ntoa
            ld bc, $130F
            call u_textr
            ld hl, BS_ST + 1
            ld bc, $0710
            call .v
            ld hl, BS_ST + 3
            ld bc, $0D10
            call .v
            ld hl, BS_ST + 5
            ld bc, $1310
            call .v
            ld a, 1
            ld [m_dirty], a
            ret
.v:         push bc
            ld a, [hl+]
            ld e, a
            ld d, [hl]
            call u_ntoa
            pop bc
            jp u_textr
.w:         add a, a                        ; HL = U_STW word A
            ld e, a
            ld d, 0
            ld hl, U_STW
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ret
; its palettes: BG 0 = black + palette A, BG 7 = black + palette B
bs_pal:     call u_sv2
            ld hl, u_palt
            call .one
            ld hl, BS_REC + 16
            ld de, u_palt + 2
            ld bc, 6
            call memcpy
            ld hl, u_palt + 7 * 8
            call .one
            ld hl, BS_REC + 22
            ld de, u_palt + 7 * 8 + 2
            ld bc, 6
            call memcpy
            jp u_svr
.one:       xor a
            ld [hl+], a
            ld [hl], a
            ret
; its tiles -> VRAM bank 1 $70.. (bosses: 144; summon graphics flipped through WRAM 2)
bs_tiles:   ld a, [BS_REC + 1]
            add a, MGFX_BANK0
            ld [vc_src], a
            ld a, [BS_REC + 2]              ; HL = $4000 + 16 tile
            ld l, a
            ld a, [BS_REC + 3]
            ld h, a
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, $4000
            add hl, de
            ld a, [BS_REC]
            and a
            ld b, 144
            jr nz, .n
            ld a, [BS_REC + 4]
            ld e, a
            ld a, [BS_REC + 5]
            ld d, a
            xor a
.m:         add a, e
            dec d
            jr nz, .m
            ld b, a
.n:         ld a, [BS_REC + 7]
            and a
            jr nz, .flip
            ld de, $8700
            ld a, 1
            jp vcopyx
.flip:      ld de, $8700                    ; 16 tiles at a time: bits reversed in GR_TMP
.fc:        push bc
            push de
            push hl
            ld de, GR_TMP
            ld bc, 256
            ld a, [vc_src]
            call rd_copy
            ld hl, GR_TMP
            ld c, 0
.fb:        ld a, [hl]
            ld b, 8
.fr:        rra
            rl e
            dec b
            jr nz, .fr
            ld [hl], e
            inc hl
            dec c
            jr nz, .fb
            pop hl
            ld de, 256
            add hl, de
            pop de
            push hl
            push de
            ld hl, GR_TMP
            ld b, 16
            ld a, 1
            call vcopy
            pop de
            ld hl, 256
            add hl, de
            ld d, h
            ld e, l
            pop hl
            pop bc
            ld a, b
            sub 16
            ld b, a
            jr nz, .fc
            ret
; its cells: a monster's w x h tiles centred in the window (1-18, 1-12), a boss's 18 x 12 tilemap
; (BDATA3: 2A/8000 + 216 id; tiles below $70 blank); the palette of each 2 x 2 block by its bit
bs_cells:   ld bc, $0101                    ; (the window black: BG 0 colour 0)
.bk:        push bc
            ld a, 0 | 8
            ld [u_at], a
            ld a, U_ZERO
            call u_cellt
            pop bc
            inc b
            ld a, b
            cp 19
            jr nz, .bk
            ld b, 1
            inc c
            ld a, c
            cp 13
            jr nz, .bk
            ld a, [BS_REC + 4]              ; the corner
            ld b, a
            ld a, 18
            sub b
            srl a
            inc a
            ld [bs_x0], a
            ld a, [BS_REC + 5]
            ld b, a
            ld a, 12
            sub b
            srl a
            inc a
            ld [bs_y0], a
            xor a
            ld [bs_r], a
.r:         xor a
            ld [bs_c], a
.c:         ld a, [bs_r]                    ; the tile: $70 + r w + c, or the boss tilemap's
            ld e, a
            ld a, [BS_REC + 4]
            ld d, a
            call bs_mul
            ld a, [bs_c]
            add a, l
            ld l, a
            jr nc, .c0
            inc h
.c0:        ld a, [BS_REC]
            and a
            jr nz, .boss
            ld a, l
            add a, $70
            jr .t
.boss:      push hl
            ld a, [BS_REC + 6]              ; 216 id
            ld e, a
            ld d, 216
            call bs_mul
            pop de
            add hl, de
            ld de, BD3_BTMAP
            add hl, de
            ld a, BDATA3_BANK
            call rd_byte
            cp $70
            jr nc, .t
            ld a, U_ZERO
.t:         ld [bs_t], a
            ld a, [bs_r]                    ; the block's bit: (r / 2) (w / 2) + c / 2
            srl a
            ld e, a
            ld a, [BS_REC + 4]
            srl a
            ld d, a
            call bs_mul
            ld a, [bs_c]
            srl a
            add a, l
            ld b, a                         ; bit number
            srl a
            srl a
            srl a
            add a, low(BS_REC + 8)
            ld l, a
            ld h, high(BS_REC + 8)
            ld a, b
            and 7
            inc a
            ld c, a
            ld a, [hl]
.sh:        rla
            dec c
            jr nz, .sh
            ld a, 0 | 8                     ; (0: palette A = BG 0; 1: B = BG 7)
            jr nc, .p
            ld a, 7 | 8
.p:         ld [u_at], a
            ld a, [bs_x0]
            ld b, a
            ld a, [bs_c]
            add a, b
            ld b, a
            ld a, [bs_y0]
            ld c, a
            ld a, [bs_r]
            add a, c
            ld c, a
            ld a, [bs_t]
            call u_cellt
            ld hl, bs_c
            inc [hl]
            ld a, [BS_REC + 4]
            cp [hl]
            jp nz, .c
            ld hl, bs_r
            inc [hl]
            ld a, [BS_REC + 5]
            cp [hl]
            jp nz, .r
            ld a, UP_WHITE | 8
            ld [u_at], a
            ret
; E x D -> HL
bs_mul:     ld hl, 0
            ld a, d
            and a
            ret z
            ld d, 0
.l:         add hl, de
            dec a
            jr nz, .l
            ret

section wram, $DFB0                         ; (WRAM 2: SVB's bytes; the file screen not open)
xm_cur:     ds 1
xm_song:    ds 1
bs_cur:     ds 1
bs_top:     ds 1
bs_cnt:     ds 1
bs_k:       ds 1
bs_m:       ds 1
bs_x0:      ds 1
bs_y0:      ds 1
bs_r:       ds 1
bs_c:       ds 1
bs_t:       ds 1
