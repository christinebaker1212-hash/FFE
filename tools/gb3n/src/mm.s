; ---- mm.s (bank CODE11): the main menu (FF3 3D/A52F; owner, 2026-11-28: spaced out, one small
; font, every member's picture as FF1's main menu; the cursor reaches every command). Layout:
; party (0,0,12,18): a member every 4 rows from row 1, the battle picture at x 16 (cells 2-3),
; name + LV, job, HP from cell 4; commands (12,0,8,10) from cell 15, the hand at cells 13-14;
; Gil / Capacity (12,10,8,4); the place (12,14,8,4). Commands as FF3's (t8200 $31) and Config;
; Save only on a world map (3D/A59F: greyed elsewhere, the error sound).
MM_N       = 8

mn_open:    ld a, CODE1                     ; (each member's values from the equipment: equip.s)
            ld hl, eq_all
            call far_call
            call u_open
            xor a
            ld [mn_cur], a
.re:        call mn_draw
            call u_flush
            call u_fadein
.l:         ld a, [mn_cur]                  ; the hand at the command
            inc a
            ld c, a
            ld b, 15
            call u_hand
            call wait_vbl
            call u_keys
            ld a, [m_new]
            and $0A                         ; B or START: back to the field
            jp nz, u_close
            ld a, [m_new]
            bit 0, a
            jr nz, .a
            ld hl, mn_cur
            bit 6, a                        ; up / down, wrapping
            jr z, .d
            ld a, [hl]
            dec a
            cp $FF
            jr nz, .s
            ld a, MM_N - 1
            jr .s
.d:         bit 7, a
            jr z, .l
            ld a, [hl]
            inc a
            cp MM_N
            jr c, .s
            xor a
.s:         ld [hl], a
            ld a, $98
            ld [S49], a
            jr .l
.a:         ld a, [mn_cur]
            cp 6                            ; Save: world maps only
            jr nz, .ns
            ldh a, [is_world]
            and a
            jr nz, .ns
            ld a, $86
            ld [S49], a
            jr .l
.ns:        ld a, $85
            ld [S49], a
            ld a, [mn_cur]
            cp 4
            jp z, mn_order
            cp 7
            jr z, .cfg
            and a                           ; Item: rebuilt (itm.s)
            jr nz, .ni
            call u_fadeout
            call itm_open
            jp .re
.ni:
            cp 6
            jr z, .old
            call mn_pick                    ; Magic, Equip, Status, Job: a member first
            jr c, .l
            ld b, a
            ld a, [mn_cur]
            cp 5                            ; Job (3D/A617): a crystal's jobs, not the dead
            jr nz, .old1
            ld a, [GS + $21]
            and $1F
            jr nz, .old1
            ld a, $86
            ld [S49], a
            jr .l
.old:       ld b, 0
.old1:      ld a, [mn_cur]
            cp 2                            ; Equip: rebuilt (eqm.s)
            jr nz, .old2
            push bc
            call u_fadeout
            pop bc
            ld a, b
            call eqm_open
            jp .re
.old2:      call mn_oldsub                  ; the screens not rebuilt yet: the earlier engine's
            jp .re
.cfg:       call u_fadeout
            ld a, CODE1
            ld hl, opt_sub
            call far_call
            call mn_back
            jp .re

; a member chosen on the party window (the hand at the picture) -> A = member, C if cancelled;
; the dead and stone refused for Magic / Job (3D/A5D7)
mn_pick:    ld a, [mn_mem]
            and 3
            ld [mn_mem], a
.l:         ld a, [mn_mem]                  ; the hand: left of the picture (x 0), its finger at
            add a, a                        ;   the picture's middle (top 8 + 32 m + 8)
            add a, a
            add a, a
            add a, a
            add a, a
            add a, 16
            ld c, a
            ld b, 16
            call u_handp
            call wait_vbl
            call u_keys
            ld a, [m_new]
            bit 1, a
            jr nz, .b
            bit 0, a
            jr nz, .a
            ld hl, mn_mem
            bit 6, a
            jr z, .d
            ld a, [hl]
            dec a
            and 3
            jr .s
.d:         bit 7, a
            jr z, .l
            ld a, [hl]
            inc a
            and 3
.s:         ld [hl], a
            ld a, $98
            ld [S49], a
            jr .l
.b:         scf
            ret
.a:         ld a, [mn_cur]                  ; (Magic and Job: not the dead / stone)
            cp 1
            jr z, .ck
            cp 5
            jr nz, .ok
.ck:        ld a, [mn_mem]
            rrca
            rrca
            add a, 2
            ld l, a
            ld h, high(GS + $100)
            ld a, [hl]
            and $C0
            jr z, .ok
            ld a, $86
            ld [S49], a
            jr .l
.ok:        ld a, $85
            ld [S49], a
            ld a, [mn_mem]
            and a
            ret

; Order (3D/A696): a member's battle row toggled ($620F + $40 m bit 0); again until B
mn_order:   call mn_pick
            jp c, mn_open.re
            rrca
            rrca
            add a, $0F
            ld l, a
            ld h, high(GS + $200)
            ld a, [hl]
            xor 1
            ld [hl], a
            call mn_draw
            call u_flush
            jr mn_order

; an earlier screen (A = command, B = member): faded out, run with its own setup (menu.s
; old_sub), then the UI back
mn_oldsub:  push af
            push bc
            call u_fadeout
            call u_hoff
            call oam_hide
            pop bc
            pop af
            ld hl, old_sub
            push af
            ld a, b
            ld [mn_arg], a
            pop af
            ld [mn_cmd], a
            ld a, CODE1
            call far_call
mn_back:    call u_fadeout
            call oam_hide
            ld a, 2
            ldh [rSVBK], a
            call u_tiles
            ld hl, U_PALS
            ld de, u_palt
            ld bc, 128
            call memcpy
            call u_mpal
            ld a, 1
            ld [menu_on], a
            ret

; ---- the screen
mn_draw:    call u_cls
            ld bc, $0000                    ; windows
            ld de, $0C12
            call u_box
            ld bc, $0C00
            ld de, $080A
            call u_box
            ld bc, $0C0A
            ld de, $0804
            call u_box
            ld bc, $0C0E
            ld de, $0804
            call u_box
            xor a
            ld [u_k], a
.m:         call mn_member
            ld hl, u_k
            inc [hl]
            ld a, [hl]
            cp 4
            jr nz, .m
            xor a                           ; the commands
            ld [mn_t], a
.c:         ld a, [mn_t]
            add a, a
            ld e, a
            ld d, 0
            ld hl, U_CMD
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld a, UP_WHITE
            ld [u_pal], a
            ld a, [mn_t]
            cp 6
            jr nz, .cw
            ldh a, [is_world]
            and a
            jr nz, .cw
            ld a, UP_GREY
            ld [u_pal], a
.cw:        ld a, [mn_t]
            inc a
            ld c, a
            ld b, 15
            call u_text
            ld hl, mn_t
            inc [hl]
            ld a, [hl]
            cp MM_N
            jr nz, .c
            ld a, UP_LABEL                  ; Gil, Capacity
            ld [u_pal], a
            ld bc, $0D0B
            ld hl, U_GIL
            call u_text
            ld bc, $0D0C
            ld hl, U_CAP
            call u_text
            ld a, UP_WHITE
            ld [u_pal], a
            ld a, [GS + $1C]                ; (gil: up to 999999; shown as FF3 does, 6 digits)
            ld e, a
            ld a, [GS + $1D]
            ld d, a
            ld a, [GS + $1E]
            ld c, a
            call mn_gil
            ld bc, $130B
            call u_textr
            ld a, [GS + $1B]
            ld e, a
            ld d, 0
            call u_ntoa
            ld bc, $130C
            call u_textr
            ldh a, [is_world]               ; the place
            and a
            ld hl, U_WORLD
            jr nz, .pl
            ld a, [M_ENT + 8]               ; (the map's title id)
            add a, a
            ld e, a
            ld a, 0
            adc a, 0
            ld d, a
            ld hl, U_TITLE
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
.pl:        ld bc, $0D0F
            call u_text
            ld a, [hl]                      ; (a second line after the {01})
            dec hl
            ld a, [hl]
            cp 1
            jr nz, .nl
            inc hl
            ld bc, $0D10
            call u_text
.nl:        ret

; member u_k: the picture, name, LV, job, HP (rows 1 + 4 m ..)
mn_member:  ld a, [u_k]
            add a, a
            add a, a
            inc a
            ld [mn_row], a
            add a, a                        ; the picture: x 16, y 8 row
            add a, a
            add a, a
            ld c, a
            ld b, 16
            call u_pic
            ld a, [u_k]
            rrca
            rrca
            ld [mn_t], a                    ; the record $6100 + $40 m
            add a, 6                        ; the name (6 codes, $FF after)
            ld l, a
            ld h, high(GS + $100)
            ld de, mn_buf
            ld b, 6
.n:         ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .n
            xor a
            ld [de], a
            ld a, UP_WHITE
            ld [u_pal], a
            ld a, [mn_row]
            ld c, a
            ld b, 4
            ld hl, mn_buf
            call u_text
            ld a, UP_LABEL                  ; LV (label ending at cell 9), the level at cell 11
            ld [u_pal], a
            ld a, [mn_row]
            ld c, a
            ld b, 9
            ld hl, U_LV
            call u_textr
            ld a, [mn_t]
            inc a
            ld l, a
            ld h, high(GS + $100)
            ld a, [hl]
            inc a                           ; (FF3 counts from 0)
            ld e, a
            ld d, 0
            call u_ntoa
            ld a, UP_WHITE
            ld [u_pal], a
            ld a, [mn_row]
            ld c, a
            ld b, 11
            call u_textr
            ld a, [mn_t]                    ; the job
            ld l, a
            ld h, high(GS + $100)
            ld a, [hl]
            and $3F
            add a, a
            ld e, a
            ld d, 0
            ld hl, U_JOBN
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld a, [mn_row]
            inc a
            ld c, a
            ld b, 4
            call u_text
            ld a, UP_LABEL                  ; HP
            ld [u_pal], a
            ld a, [mn_row]
            add a, 2
            ld c, a
            ld b, 4
            ld hl, U_HP
            call u_text
            ld a, [mn_t]                    ; cur / max (+$0C / +$0E): yellow at a quarter,
            add a, $0C                      ;   red when 0
            ld l, a
            ld h, high(GS + $100)
            ld a, [hl+]
            ld e, a
            ld a, [hl+]
            ld d, a
            ld a, [hl+]
            ld c, a
            ld a, [hl]
            ld b, a
            ld a, UP_WHITE
            ld [u_pal], a
            ld a, d
            or e
            jr nz, .alive
            ld a, UP_RED
            ld [u_pal], a
            jr .hp
.alive:     push de                         ; 4 cur <= max: yellow
            ld h, d
            ld l, e
            add hl, hl
            add hl, hl
            ld a, l
            sub c
            ld a, h
            sbc b
            pop de
            jr nc, .hp
            ld a, UP_YELLOW
            ld [u_pal], a
.hp:        push bc
            call u_ntoa                     ; "cur/max" in mn_buf
            ld de, mn_buf
.cp1:       ld a, [hl+]
            ld [de], a
            inc de
            and a
            jr nz, .cp1
            dec de
            ld a, $C7                       ; "/"
            ld [de], a
            inc de
            pop bc
            push de
            ld d, b
            ld e, c
            call u_ntoa
            pop de
.cp2:       ld a, [hl+]
            ld [de], a
            inc de
            and a
            jr nz, .cp2
            ld a, [mn_row]
            add a, 2
            ld c, a
            ld b, 11
            ld hl, mn_buf
            jp u_textr

; gil CDE (24 bits) -> HL = its digits (u_num: 7 at most)
mn_gil:     ld hl, mn_buf + 7               ; digits from the right
            ld [hl], 0
.d:         push hl                         ; CDE / 10, remainder in A
            ld b, 24
            xor a
.l:         sla e
            rl d
            rl c
            rla
            cp 10
            jr c, .n
            sub 10
            inc e
.n:         dec b
            jr nz, .l
            pop hl
            dec hl
            add a, $80
            ld [hl], a
            ld a, c
            or d
            or e
            jr nz, .d
            ret

section wram, $CEE8                         ; (after equip.s e_ids)
mn_cur:     ds 1
mn_mem:     ds 1
mn_row:     ds 1
mn_t:       ds 1
mn_cmd:     ds 1
mn_arg:     ds 1
mn_buf:     ds 16
