; ---- the Magic menu (FF3 3C/9761; owner-approved mock S3): the member's name and Use / Swap /
; Item on top, the spells 3 levels a page ("Lv1  MP 9/9", the level's 3 slots); Use casts the
; field spells (3C/9971: Cure / Cura / Curaga / Curaja, Life / Life2, Heal, Soft, Blindna, Poisona,
; Toad, Mini), Swap trades spell lists with another member (3C/96F5), Item moves a spell to the
; inventory (3C/9897). A member's spells: $6207 + level bit masks, shown as 3 slots per level in
; the order of the spell ids (3D/A2B4) -> SPL (24 bytes).
SPL        = $C680 + $60            ; the slots: level * 3 + n (FF3 $7C00)

magic_menu: ld [m_i], a
            rrca
            rrca
            ld [m_ch], a
            ld [mg_caster], a
            call spl_load
            xor a
            ld [mg_opt], a
            ld [mg_slot], a
.redraw:    call mg_draw
.opt:       ld a, [mg_opt]                  ; the option hand (row 2: cols 1 / 7 / 14)
            ld b, 8
            and a
            jr z, .x
            ld b, 8 + 6 * 8
            dec a
            jr z, .x
            ld b, 8 + 13 * 8
.x:         ld c, 16 + 2 * 8 - 4
            call cursor_at
            call wait_vbl
            call read_pad
            call m_keys
            ld a, [m_new]
            bit 1, a
            jr nz, .out
            bit 0, a
            jr nz, .a
            ld b, a
            ld a, [mg_opt]
            bit 4, b
            jr z, .lf
            inc a
            cp 3
            jr nz, .so
            xor a
            jr .so
.lf:        bit 5, b
            jr z, .opt
            dec a
            cp $FF
            jr nz, .so
            ld a, 2
.so:        ld [mg_opt], a
            jr .opt
.out:       call spl_save
            jp cur_hide
.a:         ld a, [mg_opt]
            cp 1
            jr nz, .slots
            call mg_swap                    ; Swap
            jr .redraw
.slots:     call mg_pick                    ; Use / Item: a slot (carry: B)
            jr c, .redraw
            ld a, [mg_opt]
            and a
            jr z, .use
            call mg_toitem
            jr .redraw
.use:       call mg_use
            jr .redraw

; 3D/A2B4: the bit masks -> 3 slots per level (spells in id order)
spl_load:   ld hl, SPL
            ld b, 24
            xor a
.c:         ld [hl+], a
            dec b
            jr nz, .c
            ld c, 0                         ; spell s = 0..55 (id $C8 + s): level 7 - s / 7
.s:         ld a, c
            call spl_bit                    ; HL = the level byte, B = the bit
            ld a, [hl]
            and b
            jr z, .n
            ld a, c                         ; the level's first free slot
            call spl_lv
            ld b, a
            add a, a
            add a, b                        ; 3 level
            add a, low(SPL)
            ld l, a
            ld h, high(SPL)
            ld a, [hl]
            and a
            jr z, .p
            inc l
            ld a, [hl]
            and a
            jr z, .p
            inc l
.p:         ld a, c
            add a, $C8
            ld [hl], a
.n:         inc c
            ld a, c
            cp 56
            jr nz, .s
            ret
; 3D/A1C9: the slots -> the bit masks
spl_save:   ld a, [mg_caster]
            add a, 7
            ld l, a
            ld h, high(GS + $200)
            ld b, 8
            xor a
.z:         ld [hl+], a
            dec b
            jr nz, .z
            ld de, SPL
            ld c, 24
.l:         ld a, [de]
            inc de
            and a
            jr z, .n
            sub $C8
            push bc
            call spl_bit
            ld a, [hl]
            or b
            ld [hl], a
            pop bc
.n:         dec c
            jr nz, .l
            ret
; A = spell index (0-55) -> A = its level (7 - s / 7)
spl_lv:     ld b, 7
.l:         sub 7
            jr c, .d
            dec b
            jr .l
.d:         ld a, b
            ret
; A = spell index -> HL = the caster's level byte ($6207 + level), B = the spell's bit
spl_bit:    push af
            call spl_lv
            ld b, a
            ld a, [mg_caster]
            add a, 7
            add a, b
            ld l, a
            ld h, high(GS + $200)
            pop af
.m:         cp 7
            jr c, .b
            sub 7
            jr .m
.b:         ld b, a
            ld a, 1
            inc b
.s:         dec b
            jr z, .x
            add a, a
            jr .s
.x:         ld b, a
            ret

; the screen (S3): header, the page of mg_slot (3 levels)
mg_draw:    call m_clear
            ld bc, $0000
            ld de, $1404
            call m_box
            ld a, [mg_caster]
            add a, 6
            ld l, a
            ld h, high(GS + $100)
            ld bc, $0101
            ld e, 6
            call m_codes
            ld hl, s_use
            ld bc, $0202
            call m_str
            ld hl, s_swap
            ld bc, $0802
            call m_str
            ld hl, s_item
            ld bc, $0F02
            call m_str
            ld bc, $0004
            ld de, $140E
            call m_box
            ld a, [mg_slot]                 ; the page: levels 3 p .. 3 p + 2
            call mg_page
            ld [mg_lv], a
            ld [mg_shown], a
            ld c, 5
.lv:        push bc
            ld a, [mg_lv]
            cp 8
            jr nc, .skip
            call mg_level
.skip:      pop bc
            ld a, c
            add a, 4
            ld c, a
            ld hl, mg_lv
            inc [hl]
            cp 17
            jr c, .lv
            ld a, 1
            ld [m_dirty], a
            ret
; A = slot -> A = the first level of its page
mg_page:    ld b, 0
.l:         sub 9
            jr c, .d
            inc b
            jr .l
.d:         ld a, b
            ld c, a
            add a, a
            add a, c
            ret
; level mg_lv at row C: "Lv<n>   MP cur/max", its 3 spells
mg_level:   push bc
            ld b, 1
            ld a, $95
            call m_put
            inc b
            ld a, $B9
            call m_put
            inc b
            ld a, [mg_lv]
            inc a
            add a, $80
            call m_put
            ld b, 10
            ld a, $78
            call m_put
            inc b
            ld a, $79
            call m_put
            ld a, [mg_lv]                   ; $6130 + 2 level (+ caster)
            add a, a
            ld e, a
            ld a, [mg_caster]
            add a, $30
            add a, e
            ld l, a
            ld h, high(GS + $100)
            ld a, [hl+]
            ld b, 14
            add a, $80
            call m_put
            inc b
            ld a, $C7
            call m_put
            inc b
            ld a, [hl]
            add a, $80
            call m_put
            pop bc
            ld a, [mg_lv]                   ; the slots
            ld e, a
            add a, a
            add a, e
            add a, low(SPL)
            ld l, a
            ld h, high(SPL)
            ld e, 3
.s:         inc c
            ld a, [hl+]
            and a
            jr z, .n
            push hl
            push de
            ld b, 2
            call it_name
            pop de
            pop hl
.n:         dec e
            jr nz, .s
            ret

; a slot hand: up / down through the 24 slots (pages turn); A = the slot (carry: B)
mg_pick:    ld a, [mg_slot]
            call mg_page
            ld b, a
            ld a, [mg_shown]
            cp b
            ld a, b
            ld [mg_shown], a
            call nz, mg_draw
            ld a, [mg_slot]                 ; row = 5 + 4 (level - page) + 1 + n
            ld b, 0
.r:         sub 3
            jr c, .rd
            inc b
            jr .r
.rd:        add a, 3
            ld c, a                         ; n
            ld a, [mg_shown]
            ld d, a
            ld a, b
            sub d
            add a, a
            add a, a
            add a, c
            add a, 6
            add a, a
            add a, a
            add a, a
            add a, 16 - 4
            ld c, a
            ld b, 8 + 4
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
            ld a, [mg_slot]
            bit 6, b
            jr z, .d
            and a
            jr z, mg_pick
            dec a
            jr .s
.d:         bit 7, b
            jr z, mg_pick
            cp 23
            jr z, mg_pick
            inc a
.s:         ld [mg_slot], a
            jr mg_pick
.a:         ld a, [mg_slot]
            and a
            ret
.b:         scf
            ret

; Item (3C/9897): the slot's spell to the inventory ("No room to remove" $016B / "Removed" $016E)
mg_toitem:  call mg_spell
            ret z
            ld [ev_par], a
            call ev_find
            ld a, $6B
            jp c, m_msgbox
            ld a, [ev_par]
            ld [hl], a
            ld a, l
            add a, $20
            ld l, a
            inc [hl]
            ld a, [mg_slot]
            add a, low(SPL)
            ld l, a
            ld h, high(SPL)
            ld [hl], 0
            ld a, $6E
            jp m_msgbox
; A = the selected slot's spell (Z if empty)
mg_spell:   ld a, [mg_slot]
            add a, low(SPL)
            ld l, a
            ld h, high(SPL)
            ld a, [hl]
            and a
            ret

; Swap (3C/96F5): another living member's spell lists for the caster's
mg_swap:    call it_party
            call sel_member2
            ret c
            rrca
            rrca
            ld b, a
            ld a, [mg_caster]
            cp b
            ret z
            ld a, b
            add a, 2
            ld l, a
            ld h, high(GS + $100)
            ld a, [hl]
            and $C0
            ret nz
            call spl_save
            ld a, b                         ; $6207-$620E of the two
            add a, 7
            ld e, a
            ld a, [mg_caster]
            add a, 7
            ld l, a
            ld h, high(GS + $200)
            ld d, h
            ld c, 8
.x:         ld a, [de]
            ld b, [hl]
            ld [hl+], a
            ld a, b
            ld [de], a
            inc e
            dec c
            jr nz, .x
            jp spl_load

; Use (3C/9812): a spell the caster's job may cast, MP of its level left, a field spell
mg_use:     call mg_spell
            ret z
            ld [mg_id], a
            call can_equip                  ; (the class: 35/B8FD)
            ret z
            ld a, [mg_id]                   ; MP of the level
            sub $C8
            call spl_lv
            add a, a
            ld e, a
            ld a, [mg_caster]
            add a, $30
            add a, e
            ld [mg_mp], a
            ld l, a
            ld h, high(GS + $100)
            ld a, [hl]
            and a
            ret z
            ld a, [mg_caster]               ; the caster: not dead, stone, toad or silenced
            add a, 2                        ;   (Toad itself: not dead, stone or silenced)
            ld l, a
            ld a, [hl]
            ld b, $F0
            ld a, [mg_id]
            cp $F6
            jr nz, .st
            ld b, $D0
.st:        ld a, [hl]
            and b
            ret nz
            ld hl, mg_tab                   ; the spell's prompt, kind, value
.f:         ld a, [hl+]
            and a
            ret z                           ; (not a field spell)
            ld b, a
            ld a, [mg_id]
            cp b
            jr z, .got
            inc hl
            inc hl
            inc hl
            jr .f
.got:       ld a, [hl+]
            ld [it_prompt], a
            ld a, [hl+]
            ld [mg_kind], a
            ld a, [hl]
            ld [mg_val], a
            call it_party
            call sel_target                 ; (one member, or all: left / right)
            ret c
            ld [mg_tgt], a
            call mg_effect
            ret c
            ld a, [mg_mp]                   ; one MP fewer (3C/9957)
            ld l, a
            ld h, high(GS + $100)
            dec [hl]
            call it_party
            ld b, 30
.w:         call wait_vbl
            dec b
            jr nz, .w
            ret
; spell, prompt (t8200), kind (0 heal: power, 1 remove status: mask, 2 toggle: mask,
; 3 Life2, 4 Curaja), value
mg_tab:     db $FC, $5C, 0, 42              ; Cure
            db $EE, $5C, 0, 125             ; Cura
            db $E0, $5C, 0, 180             ; Curaga
            db $D2, $5C, 4, 220             ; Curaja
            db $E1, $5E, 1, $80             ; Life
            db $CC, $5E, 3, $80             ; Life2
            db $D3, $66, 1, $7F             ; Heal
            db $DA, $5F, 1, $40             ; Soft
            db $F0, $63, 1, $04             ; Blindna (wash)
            db $FD, $64, 1, $02             ; Poisona (pure)
            db $F6, $69, 2, $20             ; Toad
            db $F7, $6A, 2, $08             ; Mini
            db 0

; the target hand: rows 12-15, left / right: all four (FF3 $79F0 >= $10); A = member or 4
sel_target: xor a
.l:         ld [m_sel2], a
            cp 4
            jr z, .all
            add a, 12
            add a, a
            add a, a
            add a, a
            add a, 16 - 4
            ld c, a
            ld b, 8
            call cursor_at
            jr .k
.all:       ld c, 16 + 13 * 8 + 4           ; (the hand at the window's side)
            ld b, 8 + 18 * 8
            call cursor_at
.k:         call wait_vbl
            call read_pad
            call m_keys
            ld a, [m_new]
            bit 1, a
            jr nz, .b
            bit 0, a
            jr nz, .a
            ld b, a
            ld a, [m_sel2]
            bit 4, b
            jr nz, .lr
            bit 5, b
            jr nz, .lr
            cp 4
            jr z, .l
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
.lr:        cp 4
            ld a, 4
            jr nz, .l
            xor a
            jr .l
.a:         ld a, [m_sel2]
            and a
            ret
.b:         scf
            ret

; 3C/99EB: the effect on mg_tgt (4 = all); carry: nothing done
mg_effect:  ld a, [mg_tgt]
            cp 4
            ld a, 1
            jr nz, .n
            ld a, 4
.n:         ld [mg_nt], a
            ld a, [mg_kind]
            and a
            jr z, .heal
            dec a
            jr z, .rem
            dec a
            jr z, .tog
            dec a
            jr z, .life2
            ld a, [mg_nt]                   ; Curaja: one target to max HP, else power 220
            dec a
            jr nz, .heal
            call mg_one
            call mg_alive
            ret c
            jp hp_max
.life2:     ld a, $80                       ; Life2: revive (3D/A3C2), then max HP
            ld [mg_val], a
            call mg_one
            call st_remove
            ret c
            jp hp_max
.rem:       jp st_remove_n                  ; Life / Heal / Soft / Blindna / Poisona
.tog:       ld a, [mg_nt]                   ; Toad / Mini: toggled on each target
            ld b, a
            ld a, [mg_tgt]
            cp 4
            jr nz, .t1
            xor a
.t1:        rrca
            rrca
.tl:        add a, 2
            ld l, a
            ld h, high(GS + $100)
            ld a, [mg_val]
            xor [hl]
            ld [hl], a
            ld a, l
            add a, $40 - 2
            dec b
            jr nz, .tl
            and a
            ret
.heal:      call mg_one                     ; 3C/9B7A: one target must live; all: count the
            ld a, [mg_nt]                   ;   living
            dec a
            jr nz, .multi
            call mg_alive
            ret c
            jr .pow
.multi:     ld b, 0
            xor a
.cnt:       push af
            add a, 2
            ld l, a
            ld h, high(GS + $100)
            ld a, [hl]
            cp $40
            jr nc, .dead
            inc b
.dead:      pop af
            add a, $40
            jr nz, .cnt
            ld a, b
            and a
            scf
            ret z
            ld [mg_nt], a
.pow:       call heal_spell                 ; BC = the amount for each target
            ld a, [mg_tgt]
            cp 4
            jr nz, .one
            xor a
.each:      ld [m_ch], a                    ; (3D/A4A4: all four; the dead / stone not healed)
            push bc
            call mg_alive
            call nc, hp_add
            pop bc
            ld a, [m_ch]
            add a, $40
            jr nz, .each
            and a
            ret
.one:       call hp_add
            and a
            ret
mg_one:     ld a, [mg_tgt]                  ; m_ch = the target (all: member 0)
            cp 4
            jr nz, .s
            xor a
.s:         rrca
            rrca
            ld [m_ch], a
            ret
mg_alive:   ld a, [m_ch]                    ; carry if dead / stone
            add a, 2
            ld l, a
            ld h, high(GS + $100)
            ld a, [hl]
            cp $40
            ccf
            ret

; 3D/A3C2: remove status mg_val (one target m_ch, or all: carry if no one has it); dead removed
; -> HP 1
st_remove_n: ld a, [mg_nt]
            dec a
            jr nz, st_remove.all
            call mg_one
st_remove:  ld a, [m_ch]
            add a, 2
            ld l, a
            ld h, high(GS + $100)
            ld a, [mg_val]
            and [hl]
            scf
            ret z
.do:        bit 7, a
            jr z, .nd
            push hl
            ld a, l
            add a, $0A
            ld l, a
            ld [hl], 1
            pop hl
.nd:        ld a, [mg_val]
            cpl
            and [hl]
            ld [hl], a
            and a
            ret
.all:       ld a, [GS + $102]
            ld b, a
            ld a, [GS + $142]
            or b
            ld b, a
            ld a, [GS + $182]
            or b
            ld b, a
            ld a, [GS + $1C2]
            or b
            ld b, a
            ld a, [mg_val]
            and b
            scf
            ret z
            xor a
.e:         ld [m_ch], a
            add a, 2
            ld l, a
            ld h, high(GS + $100)
            ld a, [mg_val]
            and [hl]
            call nz, st_remove.do
            ld a, [m_ch]
            add a, $40
            jr nz, .e
            and a
            ret

; 3D/A466: multiplier (job level / 32 + level / 16 + spirit / 16 + 1), the power as for items
; (base + base * (random / 2) / 256), x the multiplier, / the targets -> BC
heal_spell: ld a, [mg_caster]
            add a, $10
            ld l, a
            ld h, high(GS + $100)
            ld a, [hl]                      ; job level
            swap a
            rrca
            and $07
            ld b, a
            ld a, l
            sub $0F
            ld l, a
            ld a, [hl]                      ; level ($6101)
            swap a
            and $0F
            add a, b
            ld b, a
            ld a, l
            add a, $1A
            ld l, a
            ld a, [hl]                      ; mod. spirit ($611B)
            swap a
            and $0F
            add a, b
            inc a
            ld [mg_mul], a
            call rnd_get
            srl a
            ld e, a
            ld a, [mg_val]
            ld c, a
            call mul8
            ld a, [mg_val]                  ; power = base + high byte
            add a, h
            ld l, a
            ld a, 0
            adc a, 0
            ld h, a
            ld a, [mg_mul]                  ; x the multiplier (24 bits: the high byte dropped
            ld c, a                         ;   later by the 16-bit HP add as FF3's $81 / $82)
            ld b, h
            ld e, l
            push bc
            call mul8                       ; HL = mult * low
            pop bc
            push hl
            ld e, b
            ld a, [mg_mul]
            ld c, a
            call mul8                       ; HL = mult * high
            ld a, l
            pop hl
            add a, h
            ld h, a
            ld a, [mg_nt]                   ; / the targets (1, 2, 3, 4)
            ld c, a
            call div16_8
            ld b, h
            ld c, l
            ret
; HL / C -> HL
div16_8:    ld a, c
            cp 1
            ret z
            ld b, 16
            xor a
.l:         add hl, hl
            rla
            cp c
            jr c, .n
            sub c
            inc l
.n:         dec b
            jr nz, .l
            ret

; A = item / spell id: NZ if the caster's job may use it (MENU_BANK $6000 masks: build time from 30/9400
; and 00/8900)
can_equip:  ld l, a
            ld h, 0
            ld b, h
            ld c, l
            add hl, hl
            add hl, bc                      ; 3 id
            ld de, MD_MASKS
            add hl, de
            ld a, [mg_caster]
            ld e, a
            ld d, high(GS + $100)
            ld a, [de]                      ; job: bit job of the 24 (byte 2 low)
            ld c, a
            inc hl
            inc hl
            ld a, c
            cp 8
            jr c, .b
            dec hl
            sub 8
            cp 8
            jr c, .b
            dec hl
            sub 8
.b:         ld b, a
            ld a, 1
            inc b
.s:         dec b
            jr z, .x
            add a, a
            jr .s
.x:         and [hl]
            ret

section wram, $C6D0
mg_caster:  ds 1
mg_opt:     ds 1
mg_slot:    ds 1
mg_shown:   ds 1
mg_lv:      ds 1
mg_id:      ds 1
mg_mp:      ds 1
mg_kind:    ds 1
mg_val:     ds 1
mg_tgt:     ds 1
mg_nt:      ds 1
mg_mul:     ds 1
