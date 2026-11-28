; ---- the Magic menu (FF3 3C/9761; owner-approved mock S3): the member's name and Use / Swap /
; Item on top, the spells 3 levels a page ("Lv1  MP 9/9", the level's 3 slots); Use casts the
; field spells (3C/9971: Cure / Cura / Curaga / Curaja, Life / Life2, Heal, Soft, Blindna, Poisona,
; Toad, Mini), Swap trades spell lists with another member (3C/96F5), Item moves a spell to the
; inventory (3C/9897). A member's spells: $6207 + level bit masks, shown as 3 slots per level in
; the order of the spell ids (3D/A2B4) -> SPL (24 bytes).
SPL        = $C680 + $60            ; the slots: level * 3 + n (FF3 $7C00)

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
.go:        push bc                         ; (spl_save uses B)
            call spl_save
            pop bc
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
            db $D8, $67, 5, 0               ; Warp: "Go back how many floors?" (3C/9AD0)
            db $EF, $68, 6, 0               ; Exit: "Warps outside." (3C/98FA)
            db $FE, 0, 7, 0                 ; Sight: the world's minimap (3A/88A3)
            db 0

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

; ---- for the rebuilt Magic screen (mgm.s, CODE11): FF3's rules, no drawing
; A = member: the caster, its slots -> SPL
mgx_load:   ld [m_i], a
            rrca
            rrca
            ld [m_ch], a
            ld [mg_caster], a
            jp spl_load
mgx_save:   jp spl_save
mgx_loadt:  ld a, [mgm_t]
            jp mgx_load
mgx_okt:    ld a, [mgm_t]
            jp mgx_ok
mgx_swapt:  ld a, [mgm_t]
            jp mgx_swap
; A = spell id: u_eres 0 if a field spell the caster's job may cast (else 1)
mgx_ok:     ld [mg_id], a
            ld b, 1
            ld hl, mg_tab
.f:         ld a, [hl+]
            and a
            jr z, .x
            ld c, a
            inc hl
            inc hl
            inc hl
            ld a, [mg_id]
            cp c
            jr nz, .f
            ld a, [mg_id]
            call can_equip
            ld b, 1
            jr z, .x
            dec b
.x:         ld a, b
            ld [u_eres], a
            ret
; slot mg_slot to the bag: u_eres 0 (empty slot), $6B (no room), $6E (removed)
mgx_toitem: xor a
            ld [u_eres], a
            call mg_spell
            ret z
            ld [ev_par], a
            call ev_find
            ld a, $6B
            jr c, .r
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
            call spl_save
            ld a, $6E
.r:         ld [u_eres], a
            ret
; A = another member: the two members' spells traded (3C/96F5); u_eres 1 if refused (the caster
; itself, or dead / stone)
mgx_swap:   ld b, a
            ld a, 1
            ld [u_eres], a
            ld a, b
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
            xor a
            ld [u_eres], a
            jp mg_swap.go
; slot mg_slot: may it be cast now? (3C/9812, 3C/98EC) u_eres 0 (it_prompt, mg_kind, mg_val, mg_mp
; set), 1 (the error sound: empty, not by this job, no MP, not a field spell, the caster dead /
; stone / toad / silenced, Warp on a world map, Sight off one), else FF3's message ($77 can't
; change size, $78 can't warp, $79 can't use magic)
mgx_check:  ld a, 1
            ld [u_eres], a
            call mg_spell
            ret z
            ld [mg_id], a
            call mgx_ok
            ld a, [u_eres]
            and a
            ret nz
            inc a
            ld [u_eres], a
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
            ld a, [mg_caster]
            add a, 2
            ld l, a
            ld b, $F0
            ld a, [mg_id]
            cp $F6
            jr nz, .st
            ld b, $D0
.st:        ld a, [hl]
            and b
            ret nz
            ld hl, mg_tab
.f:         ld a, [hl+]
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
            call mgx_flags                  ; (3C/98EC: the map's flags, 39/BC00)
            ld c, a
            bit 7, c
            ld a, $79                       ; "Magic cannot be used"
            jr nz, .r
            ld a, [mg_kind]
            cp 5
            jr z, .warp
            cp 6
            jr z, .exit
            cp 7
            jr z, .sight
            ld a, [mg_id]                   ; Toad / Mini: not where FF3's bit 5 is set
            cp $F6
            jr z, .sz
            cp $F7
            jr nz, .ok
.sz:        bit 5, c
            ld a, $77
            jr nz, .r
.ok:        xor a
.r:         ld [u_eres], a
            ret
.warp:      ldh a, [is_world]               ; Warp: not on a world map
            and a
            ld a, 1
            jr nz, .r
.exit:      bit 6, c
            ld a, $78
            jr nz, .r
            xor a
            jr .r
.sight:     ldh a, [is_world]               ; Sight: on a world map only
            and a
            ld a, 1
            jr z, .r
            xor a
            jr .r
; the map's flags (FF3 $53: 39/BC00 + map, 39/BD00 off world 0; 0 on a world map)
mgx_flags:  ldh a, [is_world]
            and a
            ld a, 0
            ret nz
            ld a, [cur_map]
            ld l, a
            ld h, $5C                       ; (JOB_BANK: FF3 bank $39 at $4000)
            ld a, [cur_grp]
            and a
            jr z, .w
            inc h
.w:         ld a, JOB_BANK
            jp rd_byte
; Exit / Warp / Sight cast: one MP fewer (3C/9957)
mgx_mpdec:  ld a, [mg_mp]
            ld l, a
            ld h, high(GS + $100)
            dec [hl]
            ret
; cast on mg_tgt (4 = all): u_eres 0 (cast, one MP fewer), 1 (no effect: FF3 does not cast it)
mgx_cast:   call mg_effect
            ld a, 1
            jr c, .r
            ld a, [mg_mp]
            ld l, a
            ld h, high(GS + $100)
            dec [hl]
            xor a
.r:         ld [u_eres], a
            ret

section wram, $C6D0
mg_caster:  ds 1
mg_opt_:    ds 1
mg_slot:    ds 1
mg_shown_:  ds 1
mg_lv:      ds 1
mg_id:      ds 1
mg_mp:      ds 1
mg_kind:    ds 1
mg_val:     ds 1
mg_tgt:     ds 1
mg_nt:      ds 1
mg_mul:     ds 1
