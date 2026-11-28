; ---- the Item menu (FF3 3C/9EC2 list, 3C/9FA5 swap / use, 3D/A033 use; owner-approved mocks S1 /
; S2): a label window, the inventory one item a row (icon, name, ":", count) scrolling in 13 rows;
; A marks an item, A again on it uses it, on another swaps the two, B unmarks; using one asks for a
; member in a party window under a shortened list (prompts from t8200 $5B-$65, $73-$75).
IT_ROWS    = 13
ICON_T     = $50                ; item icons (0D/B500) in VRAM bank 1 tiles $50-$6F

item_menu:  xor a
            ld [it_cur], a
            ld [it_top], a
            ld a, $FF
            ld [it_mark], a
            ld a, MENU_BANK                 ; the icons
            ld [vc_src], a
            ld hl, $5E00
            ld de, $8000 + 16 * ICON_T
            ld b, 32
            ld a, 1
            call vcopyx
.redraw:    call it_draw
.l:         call it_cursor
            call wait_vbl
            call read_pad
            call m_keys
            ld a, [m_new]
            bit 1, a
            jr z, .nb
            ld a, [it_mark]                 ; B: unmark, else back
            inc a
            jr z, .out
            ld a, $FF
            ld [it_mark], a
            jr .l
.out:       call cur_hide
            ld hl, oam_buf + 4 * 32
            ld b, 4
            call oam_hide.l0
            ret
.nb:        bit 0, a
            jr nz, .a
            bit 6, a
            jr z, .dn
            ld a, [it_cur]
            and a
            jr z, .l
            dec a
            ld [it_cur], a
            ld b, a
            ld a, [it_top]
            cp b
            jr c, .l
            jr z, .l
            ld a, b
            ld [it_top], a
            jr .redraw
.dn:        bit 7, a
            jr z, .l
            ld a, [it_cur]
            cp 31
            jr z, .l
            inc a
            ld [it_cur], a
            ld b, a
            ld a, [it_top]
            add a, IT_ROWS - 1
            cp b
            jr nc, .l
            ld a, b
            sub IT_ROWS - 1
            ld [it_top], a
            jr .redraw
.a:         ld a, [it_mark]                 ; first A: mark
            cp $FF
            jr nz, .second
            ld a, [it_cur]
            ld [it_mark], a
            jr .l
.second:    ld b, a
            ld a, [it_cur]
            cp b
            jr z, .use
            ld e, a                         ; swap slots B and E (ids $60C0, counts $60E0)
            ld d, high(GS + $C0)
            ld a, e
            add a, low(GS + $C0)
            ld e, a
            ld a, b
            add a, low(GS + $C0)
            ld l, a
            ld h, d
            call .xch
            ld a, l
            add a, $20
            ld l, a
            ld a, e
            add a, $20
            ld e, a
            call .xch
            ld a, $FF
            ld [it_mark], a
            jp .redraw
.xch:       ld a, [de]
            ld c, [hl]
            ld [hl], a
            ld a, c
            ld [de], a
            ret
.use:       ld a, $FF
            ld [it_mark], a
            call it_use
            jp .redraw

; the list (S1)
it_draw:    call m_clear
            ld bc, $0000
            ld de, $1403
            call m_box
            ld bc, $0101                    ; "Item" (t8200 $35)
            ld a, $35
            call m_msg1
            ld bc, $0003
            ld de, $140F
            call m_box
            ld a, [it_top]
            ld [m_i], a
            ld c, 4
.r:         push bc
            ld a, [m_i]
            call it_row
            pop bc
            ld hl, m_i
            inc [hl]
            inc c
            ld a, c
            cp 4 + IT_ROWS
            jr nz, .r
            ld a, 1
            ld [m_dirty], a
            ret

; slot A at row C: icon (col 1), name (cols 2-15), ":" (16), count (17-18)
it_row:     cp 32
            ret nc
            ld e, a
            add a, low(GS + $C0)
            ld l, a
            ld h, high(GS + $C0)
            ld a, [hl]
            and a
            ret z
            push hl
            ld b, 1
            call it_name
            pop hl
            ld a, l
            add a, $20
            ld l, a
            ld e, [hl]
            ld d, 0
            ld b, 16
            ld a, $C8                       ; ":"
            call m_put
            ld b, 18
            jp m_dec

; the name of item A from column B, row C (its icon a VRAM bank 1 tile, leading blank dropped)
it_name:    ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, $4400
            add hl, de
            push bc                         ; (the name -> it_nbuf)
            ld de, it_nbuf
            ld bc, 16
            ld a, GAME_BANK
            call rd_copy
            pop bc
            ld hl, it_nbuf
            ld e, 15
.c:         ld a, [hl+]
            and a
            ret z
            cp $70
            jr nc, .ch
            push af                         ; an icon
            ld a, PAL_TXT | 8
            ld [m_attr], a
            pop af
            call m_put2
            jr .n
.ch:        call m_put
.n:         inc b
            dec e
            jr nz, .c
            ret

; the hands: the cursor (and the marked item's, sprites 32-35)
it_cursor:  ld a, [it_cur]
            ld b, a
            ld a, [it_top]
            ld c, a
            ld a, b
            sub c
            add a, 4
            add a, a
            add a, a
            add a, a
            add a, 16 - 4
            ld c, a
            ld b, 8
            call cursor_at
            ld hl, oam_buf + 4 * 32         ; the mark (if in view)
            ld b, 4
            call oam_hide.l0
            ld a, [it_mark]
            cp $FF
            ret z
            ld b, a
            ld a, [it_top]
            ld c, a
            ld a, b
            sub c
            ret c
            cp IT_ROWS
            ret nc
            add a, 4
            add a, a
            add a, a
            add a, a
            add a, 16 - 4
            ld c, a
            ld b, 8 + 4
            ld hl, oam_buf + 4 * 32
            jp cursor_at.hl

; ---- 3D/A033: use the item in slot it_cur
it_use:     ld a, [it_cur]
            add a, low(GS + $C0)
            ld l, a
            ld h, high(GS + $C0)
            ld a, [hl]
            ld [it_id], a
            ld a, l
            add a, $20
            ld l, a
            ld a, [hl]
            and a
            ret z                           ; (count 0)
            ld a, [it_id]
            cp $C8                          ; a spell (3D/A15F): given to a member to learn
            jp nc, it_spell
            cp $A6
            jr c, .cant                     ; (before the potion: not usable; Midgard Bread later)
            cp $B1
            jr c, .ok                       ; $A6-$B0 (spells $C8+: later)
.cant:      ld a, $5A                       ; "It can't be used."
            jp m_msgbox
.ok:        cp $B0
            jr z, .cant                     ; (the Otter's Head warp: later)
            sub $A6                         ; the prompt: $5B + (id - $A6)
            add a, $5B
            ld [it_prompt], a
.again:     call it_party
            call sel_member2
            jr c, .back
            ld [m_i], a
            rrca
            rrca
            ld [m_ch], a
            call it_effect
            jr c, .again                    ; (not used: try another)
            ld a, [it_cur]                  ; one fewer (3D/A33C)
            add a, low(GS + $E0)
            ld l, a
            ld h, high(GS + $E0)
            dec [hl]
            jr nz, .redraw
            ld a, l
            sub $20
            ld l, a
            ld [hl], 0
.redraw:    call it_party                   ; (the new HP shown)
            ld b, 30
.w:         call wait_vbl
            dec b
            jr nz, .w
.back:      ret

; 3D/A15F: a spell from the bag: "Give to whom?"; the member learns it unless they have it
; ("Already has that!") or its level holds three ("Can't carry anymore."); FF3 asks no job
; (the job decides casting, the Magic menu)
it_spell:   ld a, $73
            ld [it_prompt], a
.again:     call it_party
            call sel_member2
            ret c
            rrca
            rrca
            ld [mg_caster], a
            ld a, [it_id]
            sub $C8
            call spl_bit                    ; HL = the level byte, B = the bit
            ld a, [hl]
            and b
            ld a, $75                       ; "Already has that!"
            jr nz, .no
            ld a, [hl]                      ; three already at this level?
            ld c, 0
            ld d, 8
.cnt:       rrca
            jr nc, .z
            inc c
.z:         dec d
            jr nz, .cnt
            ld a, c
            cp 3
            ld a, $74                       ; "Can't carry anymore."
            jr nc, .no
            ld a, [hl]
            or b
            ld [hl], a
            ld a, $A3                       ; (the learn sound: FF3's confirm)
            ld [S49], a
            ld a, [it_cur]                  ; one fewer (3D/A33C)
            add a, low(GS + $E0)
            ld l, a
            ld h, high(GS + $E0)
            dec [hl]
            jr nz, .ok
            ld a, l
            sub $20
            ld l, a
            ld [hl], 0
.ok:        call it_party
            ld b, 30
.w:         call wait_vbl
            dec b
            jr nz, .w
            ret
.no:        call m_msgbox
            jr .again

; ---- for the rebuilt Item screen (itm.s, bank CODE11): it_cur = the bag slot, m_i = the member.
; itx_use: FF3's effect (it_effect); used: one fewer, u_eres 0; else u_eres 1
itx_use:    ld a, [it_cur]
            add a, low(GS + $C0)
            ld l, a
            ld h, high(GS + $C0)
            ld a, [hl]
            ld [it_id], a
            ld a, [m_i]
            rrca
            rrca
            ld [m_ch], a
            call it_effect
            ld a, 1
            jr c, .r
            ld a, [it_cur]
            call itx_dec
            xor a
.r:         ld [u_eres], a
            ret
itx_dec:    add a, low(GS + $E0)            ; (bag slot A: one fewer, emptied at 0)
            ld l, a
            ld h, high(GS + $E0)
            dec [hl]
            ret nz
            ld a, l
            sub $20
            ld l, a
            ld [hl], 0
            ret
; itx_teach: the spell it_id learned by m_i (3D/A15F): u_eres 0, or the message $75 (has it) /
; $74 (three at its level)
itx_teach:  ld a, [m_i]
            rrca
            rrca
            ld [mg_caster], a
            ld a, [it_id]
            sub $C8
            call spl_bit
            ld a, [hl]
            and b
            ld a, $75
            jr nz, .r
            ld a, [hl]
            ld c, 0
            ld d, 8
.cnt:       rrca
            jr nc, .z
            inc c
.z:         dec d
            jr nz, .cnt
            ld a, c
            cp 3
            ld a, $74
            jr nc, .r
            ld a, [hl]
            or b
            ld [hl], a
            ld a, [it_cur]
            call itx_dec
            xor a
.r:         ld [u_eres], a
            ret

; the target screen (S2): prompt (rows 0-3), the list around the item, the party (rows 11-17)
it_party:   call m_clear
            ld bc, $0000
            ld de, $1404
            call m_box
            ld bc, $0101
            ld a, [it_prompt]
            call m_msg1
            ld bc, $0004
            ld de, $1407
            call m_box
            ld a, [it_cur]
            ld c, 5
            push bc
            call it_row
            pop bc
            ld bc, $000B
            ld de, $1407
            call m_box
            xor a
            ld [m_sel2], a
.m:         ld a, [m_sel2]
            rrca
            rrca
            ld [m_ch], a
            add a, 6
            ld l, a
            ld h, high(GS + $100)
            ld a, [m_sel2]
            add a, 12
            ld c, a
            ld b, 2
            ld e, 6
            call m_codes
            call mm_hpcol
            ld b, 9
            ld a, $77
            call m_put2
            inc b
            ld a, $79
            call m_put2
            ld b, 11
            ld a, [m_ch]
            add a, $0C
            call m_dec_l
            ld a, $C7
            call m_put2
            inc b
            ld a, [m_ch]
            add a, $0E
            call m_dec_l
            ld hl, m_sel2
            inc [hl]
            ld a, [hl]
            cp 4
            jr nz, .m
            ld a, 1
            ld [m_dirty], a
            ret

; the member hand in the party window (rows 12-15): A = member, carry: B
sel_member2: xor a
.l:         ld [m_sel2], a
            add a, 12
            add a, a
            add a, a
            add a, a
            add a, 16 - 4
            ld c, a
            ld b, 8
            call cursor_at
            call wait_vbl
            call read_pad
            call m_keys
            ld a, [m_new]
            bit 1, a
            jr nz, .b
            bit 0, a
            jr nz, .a
            ld b, a
            ld a, [m_sel2]
            bit 6, b
            jr z, .d
            dec a
            and 3
            jr .l
.d:         bit 7, b
            jr z, .l
            inc a
            and 3
            jr .l
.a:         ld a, [m_sel2]
            and a
            ret
.b:         scf
            ret

; 3D/A093-A15C: the effect of it_id on member m_ch; carry if it did nothing
it_effect:  ld a, [m_ch]
            add a, 2
            ld l, a
            ld h, high(GS + $100)           ; HL = status ($6102)
            ld a, [it_id]
            cp $A6
            jr nz, .hi
            ld a, 30                        ; Potion: power 30
.heal:      ld b, a
            ld a, [hl]
            cp $40
            ccf
            ret c                           ; (dead / stone: not used)
            ld a, b
            jp heal_item
.hi:        cp $A7
            jr nz, .el
            ld a, 120                       ; Hi-Potion: 120
            jr .heal
.el:        cp $A8
            jr nz, .fd
            ld a, [hl]                      ; Elixir: HP and MP to max
            cp $40
            ccf
            ret c
            call hp_max
            jp mp_max
.fd:        cp $A9
            jr nz, .st
            bit 7, [hl]                     ; Phoenix Down: the dead to 1 HP added
            scf
            ret z
            res 7, [hl]
            ld bc, 1
            jp hp_add
.st:        cp $AD
            jr nz, .cure
            ld a, [hl]                      ; Luck Mallet: mini toggled
            xor $08
            ld [hl], a
            and a
            ret
.cure:      sub $AA                         ; Soft $40, Maiden's Kiss $20, Echo Herb $10,
            ld c, a                         ;   (Mallet), Eye Drops $04, Antidote $02
            ld b, 0
            push hl
            ld hl, .bits
            add hl, bc
            ld a, [hl]
            pop hl
            ld b, a
            and [hl]
            scf
            ret z                           ; (no such status: not used)
            ld a, b
            cpl
            and [hl]
            ld [hl], a
            and a
            ret
.bits:      db $40, $20, $10, $08, $04, $02

; 3D/A48A with one target, 3 x the power (3D/A4B5: base + base * (random / 2) / 256) -> HP
heal_item:  ld [it_pow], a
            call rnd_get                    ; (fix:C711)
            srl a
            ld e, a                         ; base * r
            ld a, [it_pow]
            ld c, a
            call mul8                       ; HL = C * E
            ld a, h                         ; (the high byte) + base
            ld l, a
            ld h, 0
            ld a, [it_pow]
            add a, l
            ld l, a
            ld a, h
            adc a, 0
            ld h, a
            ld b, h                         ; x 3
            ld c, l
            add hl, hl
            add hl, bc
            ld b, h
            ld c, l
            jp hp_add

; HP + BC, at most the max (3D/A438)
hp_add:     ld a, [m_ch]
            add a, $0C
            ld l, a
            ld h, high(GS + $100)
            ld a, [hl]
            add a, c
            ld [hl+], a
            ld a, [hl]
            adc a, b
            ld [hl+], a                     ; (HL = max)
            ld b, a
            ld a, [hl+]
            ld c, a
            ld a, [hl]                      ; max high
            cp b
            jr c, hp_max
            jr nz, .ok
            dec l
            dec l
            dec l
            ld a, [hl]                      ; current low
            cp c
            jr z, .ok
            jr nc, hp_max
.ok:        and a
            ret
hp_max:     ld a, [m_ch]
            add a, $0E
            ld l, a
            ld h, high(GS + $100)
            ld a, [hl+]
            ld b, [hl]
            dec l
            dec l
            ld [hl], b
            dec l
            ld [hl], a
            and a
            ret
mp_max:     ld a, [m_ch]                    ; (3D/A418) the 8 levels' MP to their max
            add a, $30
            ld l, a
            ld h, high(GS + $100)
            ld b, 8
.l:         inc l
            ld a, [hl-]
            ld [hl+], a
            inc l
            dec b
            jr nz, .l
            and a
            ret

; C x E -> HL
mul8:       ld hl, 0
            ld d, 0
            ld b, 8
.l:         srl c
            jr nc, .n
            add hl, de
.n:         sla e
            rl d
            dec b
            jr nz, .l
            ret

; (rnd_get, fix:C711: enc.s, bank 0)

; a t8200 message's first page into the canvas at column B, row C (2 lines, 18 columns)
m_msg1:     ld e, a
            ld a, 3                         ; (2 lines)
            ld [t_maxr], a
m_msg1n:    ld a, b
            ld [t_bx], a
            ld a, c
            ld [t_by], a
            ld a, 1
            ld [t_dest], a
            ld a, 1
            ld c, e
            call t_open
            call t_page
            xor a
            ld [t_dest], a
            ret
; a message alone (the prompt box) until a button
m_msgbox:   push af
            call m_clear
            ld bc, $0000
            ld de, $1406
            call m_box
            pop af
            ld e, a
            ld a, 5                         ; (4 lines)
            ld [t_maxr], a
            ld bc, $0101
            call m_msg1n
            ld a, 1
            ld [m_dirty], a
            call cur_hide
            jp wait_keys

section wram, $C6C0
it_cur:     ds 1
it_top:     ds 1
it_mark:    ds 1
it_id:      ds 1
it_prompt:  ds 1
it_pow:     ds 1
m_sel2:     ds 1
rnd_f5:     ds 1
rnd_f6:     ds 1
section wram, $CFE4
it_nbuf:    ds 16
