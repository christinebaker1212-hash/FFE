; ---- 31/AF77 battle algorithm $00: do magic effect, and the attack effects (31/B15F table
; 31/BA9C), ported from the disassembly. $1A: the spell / attack id; attack properties (30/98C0)
; -> $7400: element, hit %, power, status, effect, admwklll, animation, job mask.

mg_props:   ld a, [BZ + $1A]                ; FFDA6 load array item: 30/98C0 + 8 id -> $7400
            ld [BZ + $18], a
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, BD2_ATK
            add hl, de
            ld de, W7 + $7400
            ld bc, 8
            ld a, BDATA2_BANK
            call rd_copy
            ld a, 8
            ld [BZ + $1A], a
            ld a, $C0
            ld [BZ + $20], a
            ld a, $98
            ld [BZ + $21], a
            ret

magic_eff:  xor a
            ld [BZ + $54], a
            ld hl, W7 + $7EB8
            ld b, 10
.r:         ld [hl+], a
            dec b
            jr nz, .r
            ld a, [BZ + $CC]
            and a
            jr nz, .flg
            call atk_flags
            bit 7, a
            jr nz, .st
            and $10
            jr z, .st
            ld a, [BZ + $1A]
            cp $50
            jr nc, .flg                     ; (a terrain attack)
.st:        ld c, 1
            ld a, $6E
            call zpy
            ld a, [hl]
            and $30
            jr z, .ok
            and $20
            jr z, .sil
            ld a, [BZ + $1A]
            cp $F6                          ; (a toad casts only toad)
            jr z, .ok
            ld a, $53
            jr .cant
.sil:       ld a, $50
.cant:      ld [W7 + $78DA], a
            ld a, $18
            ld [W7 + $7EC2], a
            ret
.ok:        call atk_flags
            and $18
            jr nz, .flg
            ld a, [BZ + $1A]
            sub $C8
            ld [BZ + $1A], a
.flg:       call atk_flags                  ; (Y = $2C as FF3's paths leave it)
            and $E7
            ld [hl], a
            ld a, [BZ + $1A]
            ld [W7 + $7E88], a
            ld b, 0
            cp $5B
            jr c, .sm
            inc b
.sm:        ld a, b
            ld [W7 + $7EC3], a
            call mg_props
            ld a, [W7 + $7406]
            ld [W7 + $7E9D], a
            ld a, [W7 + $7E99]              ; the number of targets (damage split)
            ld b, 0
            ld c, 8
.n:         add a, a
            jr nc, .n1
            inc b
.n1:        dec c
            jr nz, .n
            ld a, b
            ld [BZ + $2A], a
            ld c, $30                       ; the target side's records
            ld a, $6E
            call zpy
            ld a, [hl]
            ld hl, W7 + $7575
            bit 7, a
            jr z, .p1
            ld hl, W7 + $7675
.p1:        ld a, $70
            call zpset
.tgt:       call init_at                    ; each target
            ld a, $FF
            ld [BZ + $78], a
            ld [BZ + $79], a
            ld [BZ + $7A], a
            ld [BZ + $7B], a
            xor a
            ld [W7 + $7574], a
            ld [W7 + $7573], a
            ld a, [W7 + $7E9D]
            cp 6
            jr z, .go                       ; (monster summon / split)
            ld a, [BZ + $62]
            ld e, a
            ld d, 0
            ld hl, BZ + $F0
            add hl, de
            ld a, [hl]
            and $C0
            ret nz                          ; (the attacker dead / stone)
            ld a, [W7 + $7EC1]
            call bitmask
            ld b, a
            ld a, [W7 + $7E99]
            and b
            jp z, .next
.go:        ld a, [BZ + $CC]
            and a
            jp nz, .eff
            ld a, [W7 + $7405]              ; hit %: intellect / spirit / 2 + spell's
            ld c, $10
            and $10
            jr z, .is
            inc c
.is:        ld a, $6E
            call zpy
            ld a, [hl]
            ld [BZ + $18], a
            srl a
            ld b, a
            ld a, [W7 + $7401]
            add a, b
            ld [BZ + $25], a
            ld a, [BZ + $62]
            ld e, a
            ld d, 0
            ld hl, BZ + $F0
            add hl, de
            ld a, [hl]
            and 4
            jr z, .nb
            ld hl, BZ + $25
            srl [hl]
.nb:        ld c, $0F                       ; tries: job level / 32 + level / 16 + stat / 16 + 1
            ld a, $6E
            call zpy
            ld a, [hl]
            swap a
            rrca
            and 7
            ld [BZ + $19], a
            ld c, 0
            ld a, $6E
            call zpy
            ld a, [hl]
            swap a
            and $0F
            ld [BZ + $1A], a
            ld a, [BZ + $18]
            swap a
            and $0F
            scf
            ld hl, BZ + $19
            adc a, [hl]
            ld hl, BZ + $1A
            adc a, [hl]
            ld [BZ + $24], a
            ld [BZ + $38], a
            call hit_count
            ld [BZ + $7C], a
            ld c, $33                       ; an element boost: hits + 1 / 5
            ld a, $6E
            call zpy
            ld a, [hl]
            and $E0
            rrca
            rrca
            rrca
            ld b, a
            ld a, [W7 + $7400]
            and b
            jr z, .eff
            ld a, [BZ + $30]
            ld [BZ + $18], a
            ld a, 5
            ld [BZ + $1A], a
            xor a
            ld [BZ + $19], a
            ld [BZ + $1B], a
            call bdiv16
            ld a, [BZ + $1C]
            ld b, a
            ld a, [BZ + $30]
            add a, b
            ld [BZ + $7C], a
.eff:       call atk_eff
            ld a, [BZ + $79]
            cp $FF
            jr z, .null
            ld a, [BZ + $64]
            ld e, a
            ld d, 0
            ld a, [W7 + $7574]
            and a
            jr nz, .refl
            ld hl, W7 + $7E4F
            add hl, de
            ld a, [BZ + $78]
            ld [hl+], a
            ld a, [BZ + $79]
            ld [hl], a
            jr .null
.refl:      call tgt_flags                  ; reflected: onto the caster's numeral
            and 7
            add a, a
            ld e, a
            ld d, 0
            ld hl, W7 + $7E5F + 1
            add hl, de
            ld a, [hl-]
            cp $FF
            jr z, .r1
            ld a, [BZ + $78]
            add a, [hl]
            ld [hl+], a
            ld a, [BZ + $79]
            adc a, [hl]
            ld [hl], a
            jr .r2
.r1:        ld a, e
            call num_atk
.r2:        ld a, [W7 + $78B5]
            ld [BZ + $70], a
            ld a, [W7 + $78B6]
            ld [BZ + $71], a
            jr .chka
.null:      call tg_ptr
            xor a
            call chk_dead
.chka:      call at_ptr
            ld a, 1
            call chk_dead
.next:      ld hl, W7 + $7EC1
            inc [hl]
            ld a, [hl]
            cp 8
            ret z
            cp 4
            jr nz, .nx
            ld a, [W7 + $7E9A]
            and $40
            ret z
.nx:        ld a, [BZ + $70]
            add a, $40
            ld [BZ + $70], a
            ld a, [BZ + $71]
            adc a, 0
            ld [BZ + $71], a
            jp .tgt

; 31/BB1C set attacker damage numeral buffer (A = its offset: $7E5F + A = $78 / $79)
num_atk:    ld e, a
            ld d, 0
            ld hl, W7 + $7E5F
            add hl, de
            ld a, [BZ + $78]
            ld [hl+], a
            ld a, [BZ + $79]
            ld [hl], a
            ret

; 31/BDC5 check if target (A = 0) / attacker (1) is dead: members by the dead status, monsters
; also stone / toad; zero hp -> dead
chk_dead:   ld [btl_tmp], a
            ld a, $80
            ld [BZ + $18], a
            call atk_or_tgt
            bit 7, a
            jr z, .c
            push af
            ld a, $E0
            ld [BZ + $18], a
            pop af
.c:         and 7
            add a, a
            ld e, a
            ld d, 0
            ld hl, BZ + $E0
            ld a, [btl_tmp]
            and a
            jr z, .t
            ld hl, BZ + $F0
.t:         add hl, de
            push hl
            ld a, [BZ + $18]
            and [hl]
            jr z, .hp
            ld c, 3                         ; dead from status: hp 0
            ld a, $24
            call zpy
            xor a
            ld [hl+], a
            ld [hl], a
            pop hl
            ret
.hp:        ld c, 3
            ld a, $24
            call zpy
            ld a, [hl+]
            or [hl]
            pop hl
            ret nz
            set 7, [hl]
            ret
; 31/A8C8 get flags at [$24] + $2C
atk_or_tgt: ld c, $2C
            ld a, $24
            call zpy
            ld a, [hl]
            ret

; 31/B15F do attack effect ($7404)
atk_eff:    ld a, [W7 + $7404]
            add a, a
            ld e, a
            ld d, 0
            ld hl, eff_tab
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            jp hl

; ---- 31/B17C attack effect $00: normal magic damage
eff_dmg:    ld c, $26
            ld a, $70
            call zpy
            ld a, [hl]
            and a
            call nz, do_reflect
            call elem_mod
            call m_evade
            jr z, .x
            ld a, [W7 + $7403]
            and 1
            jr z, .p
            ld a, [W7 + $7ED8]
            bit 7, a
            jr nz, .inef
.p:         ld a, [W7 + $7403]
            and 2
            jr z, .d
            ld a, [W7 + $7ED8]
            bit 7, a
            jr nz, .inef
            ld c, 1
            ld a, $70
            call zpy
            ld a, [W7 + $7403]
            ld b, a
            ld a, [hl]
            cp b
            jr c, .d
.inef:      call atk_ineff
.x:         jp .refd
.d:         ld c, $15
            ld a, $70
            call zpy
            ld a, [hl]
            ld [BZ + $26], a
            ld c, $10
            ld a, [W7 + $7405]
            and $10
            jr z, .i
            inc c
.i:         ld a, $6E
            call zpy
            ld a, [hl]
            srl a
            ld b, a
            ld a, [W7 + $7402]
            add a, b
            ld [BZ + $25], a
            ld a, 0
            adc a, 0
            ld [BZ + $2B], a
            ld a, [BZ + $64]
            ld e, a
            ld d, 0
            ld hl, BZ + $E0
            add hl, de
            ld a, [hl]
            and $28
            jr nz, .x2
            ld c, $27
            ld a, $70
            call zpy
            ld a, [hl]
            and a
            jr z, .sp
.x2:        ld hl, BZ + $25
            sla [hl]
            ld hl, BZ + $2B
            rl [hl]
            xor a
            ld [BZ + $26], a
.sp:        ld a, [W7 + $7405]
            and $40
            jr z, .cr
            ld a, 1
            ld [BZ + $2A], a
.cr:        xor a
            ld [BZ + $28], a
            ld [BZ + $29], a
            ld a, [BZ + $7C]
            ld [BZ + $24], a
            call calc_dmg
            ld a, [BZ + $1C]
            ld b, a
            ld a, [BZ + $1D]
            or b
            jr nz, .m1
            ld hl, BZ + $1C
            inc [hl]
.m1:        ld a, [BZ + $1C]
            ld [BZ + $78], a
            ld a, [BZ + $1D]
            ld [BZ + $79], a
            call tg_ptr
            call sub_hp
            jr nc, .refd
            call mag_status
.refd:      ld a, [W7 + $7574]
            and a
            ret z
            ld c, 3
            ld a, $70
            call zpy
            ld a, [hl+]
            or [hl]
            ret nz
            ld c, 1
            ld a, $70
            call zpy
            set 7, [hl]
            ret

; 31/B233 attack effect $01 / $18: healing (undead: damage)
eff_heal:   call undead
            jr nc, eff_heal2
            ld a, 1
            ld [BZ + $54], a
            jp eff_dmg
eff_heal2:  call atk_hit
            ret z
            ld a, [W7 + $7405]
            and 7
            cp 6
            jr nz, .r
            ld a, [BZ + $2A]
            cp 1
            jr nz, .r
            ld c, 5                         ; (cure 4 on one: max hp)
            ld a, $70
            call zpy
            ld a, [hl+]
            ld b, [hl]
            dec hl
            dec hl
            dec hl
            ld [hl+], a
            ld [hl], b
            ret
.r:         call restor
            call tg_ptr
            call add_hp
            ld hl, BZ + $79
            set 7, [hl]
            ret

; 31/B276 attack effect $02: tornado (hp to power..2 power)
eff_wind:   call m_evade
            ret z
            call tgt_flags
            bit 7, a
            jr z, .g
            ld a, [W7 + $7ED8]
            bit 7, a
            jp nz, atk_ineff
.g:         ld a, [W7 + $7402]
            call rnd_0a
            ld b, a
            ld a, [W7 + $7402]
            add a, b
            ld [BZ + $18], a
            ld b, a
            ld c, 3
            ld a, $70
            call zpy
            ld a, [hl+]                     ; (FF3's sbc with the add's carry clear: - 1)
            scf
            sbc b
            ld a, [hl]
            sbc 0
            jp c, atk_ineff
            dec hl
            ld a, [BZ + $18]
            ld [hl+], a
            ld [hl], 0
            ret

; 31/B2B5 attack effect $03: drain
eff_drain:  call m_evade
            jp z, atk_ineff
            call tgt_flags
            bit 7, a
            jr z, .g
            ld a, [W7 + $7ED8]
            bit 7, a
            jp nz, atk_ineff
.g:         call atk_flags
            and $87
            ld [BZ + $28], a
            call tgt_flags
            and $87
            ld b, a
            ld a, [BZ + $28]
            cp b
            jp z, atk_ineff
            call restor
            ld a, [BZ + $78]
            push af
            ld a, [BZ + $79]
            push af
            call tg_ptr
            call drain
            pop af
            ld [BZ + $79], a
            pop af
            ld [BZ + $78], a
            ld a, [BZ + $42]
            and a
            jr z, .g2
            ld a, [BZ + $62]
            call num_atk
            ld hl, BZ + $79
            set 7, [hl]
            ret
.g2:        ld a, [BZ + $62]
            ld e, a
            ld d, 0
            ld hl, W7 + $7E5F
            add hl, de
            ld a, [BZ + $78]
            ld [hl+], a
            ld a, [BZ + $79]
            or $80
            ld [hl], a
            ret

; 31/B30C attack effect $04: apply status (undead + death: life)
eff_status: call undead
            jr nc, .a
            ld a, [W7 + $7E88]
            cp 1
            jr nz, .a
            ld a, 5
            ld [BZ + $54], a
            jp eff_heal2
.a:         call m_evade
            ret z
            call tgt_flags
            bit 7, a
            jr z, .b
            ld a, [W7 + $7ED8]
            bit 7, a
            jp nz, atk_ineff
.b:         ld a, [W7 + $7403]
            ld [BZ + $24], a
            and $20
            jr z, .c
            ld a, [BZ + $64]
            ld e, a
            ld d, 0
            ld hl, BZ + $E0
            add hl, de
            ld a, [hl]
            and $40
            jp nz, atk_ineff
.c:         call stat_imm
            jp nc, atk_ineff
            ld a, [W7 + $7E88]
            cp $16
            jr nz, .s
            ld c, 0                         ; kill: the target's level < the caster's x 3/4
            ld a, $6E
            call zpy
            ld a, [hl]
            srl a
            ld [BZ + $18], a
            srl a
            ld b, a
            ld a, [BZ + $18]
            add a, b
            ld [BZ + $18], a
            ld b, a
            ld c, 0
            ld a, $70
            call zpy
            ld a, [hl]
            cp b
            jp nc, atk_ineff
.s:         jp app_status

; 31/B37A attack effect $05: raise / arise (undead, alive: death)
eff_raise:  call undead
            jr nc, .a
            ld a, [BZ + $64]
            ld e, a
            ld d, 0
            ld hl, BZ + $E0
            add hl, de
            ld a, [hl]
            and $80
            jr nz, .a
            ld a, 4
            ld [BZ + $54], a
            jp eff_status
.a:         call atk_hit
            ret z
            ld a, [BZ + $64]
            ld e, a
            ld d, 0
            ld hl, BZ + $E0
            add hl, de
            ld a, [hl]
            and $80
            jr nz, .b
            ld [BZ + $7C], a                ; (not dead: no hits)
            jr .a
.b:         ld a, [W7 + $7403]
            ld [BZ + $24], a
            call rem_status
            call tgt_flags
            bit 7, a
            jr z, .c
            and 7
            ld e, a
            ld d, 0
            ld hl, W7 + $7EC4
            add hl, de
            ld [hl], 0
.c:         xor a
            ld [W7 + $78D9], a
            call life_hp
            call tg_ptr
            call add_hp
            ld hl, BZ + $79
            set 7, [hl]
            ret

; 31/B3CA attack effect $06: remove status
eff_cure:   call atk_hit
            ret z
            ld a, [W7 + $7403]
            ld [BZ + $24], a
            cp $FF
            jr nz, .r
            ld a, [BZ + $64]
            ld e, a
            ld d, 0
            ld hl, BZ + $E0
            add hl, de
            ld a, [hl+]
            and $40
            jr z, .r
            ld a, [hl]
            and $20
            jp nz, atk_ineff
.r:         jp rem_status

; 31/BD03 restore hp (life spells): life 2 ($7402 = $FF) max hp, else 1-9
life_hp:    ld a, [W7 + $7402]
            cp $FF
            jr nz, .r
            ld c, 5
            ld a, $70
            call zpy
            ld a, [hl+]
            ld [BZ + $78], a
            ld a, [hl]
            ld [BZ + $79], a
            ret
.r:         ld a, 9
            call rnd_0a
            and a
            jr z, .r
            ld [BZ + $78], a
            xor a
            ld [BZ + $79], a
            ret

eff_tab:    dw eff_dmg, eff_heal, eff_wind, eff_drain, eff_status, eff_raise, eff_cure, eff_toad
            dw eff_prot, eff_haste, eff_wall, eff_erase, eff_none, eff_libra, eff_div, eff_split
            dw eff_summon, eff_split, eff_explode, eff_bshift, eff_elixir, eff_defense, eff_bite, eff_dmg
            dw eff_heal, eff_dash, eff_none, eff_dmg, eff_status, eff_dmg, eff_dmg, eff_status
            dw eff_dmg, eff_dmg, eff_heal, eff_dmg, eff_dmg, eff_dmg, eff_dmg, eff_dmg
            dw eff_wall, eff_dmg, eff_zan, eff_status, eff_dmg, eff_dmg, eff_haste, eff_rend
            dw eff_dmg, eff_dmg, eff_status, eff_dmg, eff_status, eff_status, eff_dmg, eff_dmg
            dw eff_dmg
eff_none:   ret

; 31/B3F1 attack effect $07: toad / mini (toggled)
eff_toad:   call atk_flags
            bit 7, a
            jr nz, .e
            call tgt_flags
            bit 7, a
            jr z, .t
.e:         call m_evade
            ret z
.t:         call tgt_flags
            bit 7, a
            jr z, .g
            ld a, [W7 + $7ED8]
            bit 7, a
            jp nz, atk_ineff
.g:         ld c, 1
            ld a, $70
            call zpy
            ld a, [hl]
            ld [BZ + $18], a
            ld b, a
            ld a, [W7 + $7403]
            xor b
            ld [hl], a
            ld [BZ + $19], a
            and $28
            jr z, .s
            ld a, [W7 + $7403]
            or [hl]
.s:         push af
            ld a, [BZ + $64]
            ld e, a
            ld d, 0
            ld hl, BZ + $E0
            add hl, de
            pop af
            ld [hl], a
            ld a, [BZ + $19]
            and $20
            jr z, .m
            ld a, [BZ + $18]
            and $20
            ret nz
            ld a, $0F                       ; Frog
            jr .msg
.m:         ld a, [BZ + $19]
            and 8
            jr z, .c
            ld a, [BZ + $18]
            and 8
            ret nz
            ld a, $11                       ; Mini
            jr .msg
.c:         ld a, [BZ + $18]
            and $20
            jr z, .l
            ld a, [BZ + $19]
            and $20
            ret nz
            ld a, 5                         ; Cured
            jr .msg
.l:         ld a, [BZ + $18]
            and 8
            ret z
            ld a, [BZ + $19]
            and 8
            ret nz
            ld a, 7                         ; Enlarged
.msg:       ld [W7 + $78D9], a
            ret

; 31/B474 attack effect $08: protect
eff_prot:   call atk_hit
            ret z
            call restor
            ; (fall through)
; 31/B704 protect effect: defence and m.defence + $78 (FF3 adds the carry into $79)
prot_eff:   ld c, $23
            ld a, $70
            call zpy
            ld a, [hl]
            cp $FF
            jr nz, .a
            ld c, $15
            ld a, $70
            call zpy
            ld a, [hl]
            cp $FF
            jr z, .x
.a:         ld c, $23
            call .add
            ld c, $15
            call .add
            jp dmg_null
.x:         call dmg_null
            jp atk_ineff
.add:       ld a, $70
            call zpy
            ld a, [BZ + $78]
            add a, [hl]
            ld [hl], a
            ld a, [BZ + $79]
            adc a, 0
            ld [BZ + $79], a
            ret z
            ld [hl], $FF
            ret

; 31/B74B set damage to null
dmg_null:   ld a, $FF
            ld [BZ + $79], a
            ld [BZ + $78], a
            ret

; 31/B480 attack effect $09: haste
eff_haste:  call atk_hit
            ret z
            call restor
            ; (fall through)
; 31/B752 haste effect: attack powers + $78, multipliers + $7C (16 at most)
haste_eff:  ld c, $19
            ld a, $70
            call zpy
            ld a, [hl]
            cp $FF
            jr z, .x
            ld c, $1E
            ld a, $70
            call zpy
            ld a, [hl]
            cp $FF
            jr z, .x
            ld c, $17
            ld a, $70
            call zpy
            ld a, [hl]
            cp $10
            jr nc, .x
            ld c, $1C
            ld a, $70
            call zpy
            ld a, [hl]
            cp $10
            jr nc, .x
            ld c, $19
            call prot_eff.add
            ld c, $1E
            call prot_eff.add
            ld c, $17
            call .mul
            ld c, $1C
            call .mul
            jp dmg_null
.x:         call dmg_null
            jp atk_ineff
.mul:       ld a, $70
            call zpy
            ld a, [BZ + $7C]
            add a, [hl]
            cp $10
            jr c, .m
            ld a, $10
.m:         ld [hl], a
            ret

; 31/B48C attack effect $0A: reflect (the counter + 1)
eff_wall:   call atk_hit
            ret z
            ld c, $26
            ld a, $70
            call zpy
            inc [hl]
            ret

; 31/B49B attack effect $0B: erase (FF3 keeps bits 0-1 of +$20)
eff_erase:  call m_evade
            ret z
            call tgt_flags
            bit 7, a
            jr z, .e
            ld a, [W7 + $7ED8]
            bit 7, a
            jp nz, atk_ineff
.e:         ld c, $20
            ld a, $70
            call zpy
            ld a, [hl]
            and 3
            ld [hl], a
            ret

; 31/B4B9 attack effect $0D: libra (current / max hp -> $78E4)
eff_libra:  ld c, 3
            ld a, $70
            call zpy
            ld de, W7 + $78E4
            ld bc, 4
            jp memcpy

; 31/B4C9 attack effect $0E: divide (into a free slot); the magic effect ends
eff_div:    call spl_init
            call spl_copy
eff_end:    pop hl                          ; (31/B4CF: out of the magic effect)
            ret
; 31/B4D4 attack effect $0F / $11: split (only at full hp)
eff_split:  ld c, 3
            ld a, $6E
            call zpy
            ld a, [hl+]
            ld b, a
            ld a, [hl+]
            ld c, a
            ld a, [hl+]
            cp b
            jr nz, .s
            ld a, [hl]
            cp c
            jr nz, .s
            jp spl_none
.s:         call spl_init
            call spl_copy
            jr eff_end
; 31/B4F4 attack effect $10: monster summon
eff_summon: call spl_init
            ld a, [BZ + $1C]
            ld [BZ + $27], a
            call spl_clr
.r:         ld a, 3
            call rnd_0a
            and a
            jr z, .r
            ld e, a
            ld d, 0
            ld [W7 + $7E99], a
            ld hl, W7 + $7D6B
            add hl, de
            ld a, [hl]
            ld [BZ + $26], a
            ld a, 1
            ld [W7 + $7E9B], a
            call load_mon2
            ld c, $2E
            ld a, $5D
            call zpy
            ld [hl], 0
            jr eff_end

; 31/B936: the status buffers from the monsters' (first 4), the first free slot -> $1C (none:
; 31/B98B "Searching", out of the magic effect)
spl_init:   ld hl, W7 + $7675 + 1
            ld a, l
            ld [BZ + $18], a
            ld a, h
            ld [BZ + $19], a
            ld de, BZ + $E0
            ld b, 4
.c:         ld a, [hl]
            ld [de], a
            push de
            ld a, e
            add a, $10
            ld e, a
            ld a, [hl]
            ld [de], a
            pop de
            inc de
            inc de
            push bc
            ld bc, $40
            add hl, bc
            pop bc
            dec b
            jr nz, .c
            dec hl
            ld a, l
            ld [BZ + $18], a
            ld a, h
            ld [BZ + $19], a
            ld hl, W7 + $7DA7
            ld c, 0
.f:         ld a, [hl+]
            cp $FF
            jr z, .got
            inc c
            ld a, c
            cp 6
            jr nz, .f
            pop hl                          ; (none free: out of the effect too)
            jp spl_none
.got:       ld a, c
            ld [BZ + $1C], a
            ld e, a
            ld d, 0
            ld hl, W7 + $7EC4
            add hl, de
            ld [hl], 0
            ld a, $FF
            ld [W7 + $78D8], a
            call atk_flags
            and 7
            ld [BZ + $18], a
            ld e, a
            ld d, 0
            ld hl, W7 + $7DA7
            add hl, de
            ld a, [hl]
            ld [W7 + $7E99], a
            ld a, 1
            ld [W7 + $7E9B], a
            ret
; 31/B98B: no room ("Searching..."), out of the magic effect
spl_none:   ld a, $FF
            ld [W7 + $78D7], a
            ld [W7 + $78D8], a
            ld [W7 + $7E99], a
            ld a, $44
            ld [W7 + $78DA], a
            jr eff_end
; 31/B9A0: the monster in slot $18 copied to slot $1C (31/B9AB), its status buffers cleared
spl_copy:   ld a, $FF
            ld [W7 + $78D8], a
            ld a, [BZ + $18]
            call rec_ptr
            ld de, $0100
            add hl, de
            push hl
            ld a, l
            ld [BZ + $1E], a
            ld a, h
            ld [BZ + $1F], a
            ld a, [BZ + $1C]
            call rec_ptr
            ld de, $0100
            add hl, de
            ld a, l                         ; ($20 / $21 as FF3's: $21 is also the rng index)
            ld [BZ + $20], a
            ld a, h
            sub high(W7)
            ld [BZ + $21], a
            ld d, h
            ld e, l
            pop hl
            ld bc, $40
            call memcpy
            ld a, [BZ + $1C]
            or $80
            and $E7
            ld c, $2C
            push af
            ld a, $20
            call zpy
            pop af
            ld [hl+], a
            inc hl
            ld [hl], 0
            ; (fall through)
; 31/B9ED clear target status ($1C)
spl_clr:    ld a, [BZ + $1C]
            add a, a
            ld e, a
            ld d, 0
            ld hl, BZ + $E0
            add hl, de
            xor a
            ld [hl], a
            ld hl, BZ + $F0
            add hl, de
            ld [hl], a
            ret

; 31/B51F attack effect $12: self-destruct (damage = current hp x 4; at full hp nothing)
eff_explode: ld c, 3
            ld a, $6E
            call zpy
            ld a, [hl+]
            ld [BZ + $18], a
            ld b, a
            ld a, [hl+]
            ld [BZ + $19], a
            ld c, a
            ld a, b                         ; current - max: FF3 tests the high byte's result
            sub [hl]
            inc hl
            ld a, c
            sbc [hl]
            jr z, .full
            ld a, [BZ + $18]
            ld e, a
            ld a, [BZ + $19]
            ld d, a
            sla e
            rl d
            sla e
            rl d
            ld a, e
            ld [BZ + $78], a
            ld a, d
            ld [BZ + $79], a
            call tg_ptr
            call sub_hp
            ld c, 3
            ld a, $6E
            call zpy
            xor a
            ld [hl+], a
            ld [hl], a
            ld c, 1
            ld a, $6E
            call zpy
            ld [hl], $80
            ret
.full:      ld a, $FF
            ld [W7 + $78D7], a
            ld [W7 + $78D8], a
            xor a
            ld [W7 + $7E99], a
            ld a, $44
            ld [W7 + $78DA], a
            ret

; 31/B56C attack effect $13: barrier shift
eff_bshift: call bshift
            ld a, $FF
            ld [W7 + $7BE2], a
            ld [W7 + $78D8], a
            jp eff_end
; 31/B57A: a random weakness (3-5) and the absorbed / strong elements all but it
bshift:     ld a, 1
            ld [BZ + $21], a
            ld b, 3
            ld a, 5
            call rnd_xa
            ld [BZ + $24], a
.r:         ld a, 1
            ld [BZ + $21], a
            ld b, 3
            ld a, 5
            call rnd_xa
            ld b, a
            ld a, [BZ + $24]
            cp b
            jr z, .r
            ld a, b
            call bitmask
            push af
            ld c, $12
            ld a, $6E
            call zpy
            pop af
            ld [hl], a
            cpl
            push af
            ld c, $20
            ld a, $6E
            call zpy
            pop af
            ld [hl], a
            ret

; 31/B5AA attack effect $14: elixir (hp and mp to max)
eff_elixir: ld c, 5
            ld a, $70
            call zpy
            ld a, [hl+]
            ld b, [hl]
            dec hl
            dec hl
            dec hl
            ld [hl+], a
            ld [hl], b
            call tgt_flags
            and 7
            ld [BZ + $52], a
            call chr_ofs
            add a, $31
            ld [BZ + $18], a
            ld a, [BZ + $5F]
            add a, 7
            ld [BZ + $19], a
            ld b, 8
.m:         push bc
            ld a, [BZ + $18]
            ld c, a
            ld a, $57
            call zpy
            ld a, [hl]
            push af
            ld a, [BZ + $19]
            ld c, a
            ld a, $5B
            call zpy
            pop af
            ld [hl], a
            ld hl, BZ + $18
            inc [hl]
            inc [hl]
            ld hl, BZ + $19
            inc [hl]
            pop bc
            dec b
            jr nz, .m
            xor a
            ld [BZ + $52], a
            ret

; 31/B5E7 attack effect $15: defense (the stats saved, raised to the top)
eff_defense: ld a, [W7 + $78C9]
            and a
            jr nz, .x
            ld c, $13
            ld a, $6E
            call zpy
            ld de, W7 + $78C9
            ld bc, 3
            call memcpy
            ld c, $21
            ld a, $6E
            call zpy
            ld de, W7 + $78CC
            ld bc, 3
            call memcpy
            ld c, $13
            ld a, $6E
            call zpy
            ld [hl], $10
            inc hl
            ld [hl], $63
            inc hl
            ld [hl], $FF
            ld c, $21
            ld a, $6E
            call zpy
            ld [hl], $10
            inc hl
            ld [hl], $63
            inc hl
            ld [hl], $FF
.x:         ld a, $FF
            ld [W7 + $78D8], a
            ret

; 31/B62C attack effect $16: bite (the stats back, then normal damage)
eff_bite:   ld c, $13
            ld a, $6E
            call zpy
            ld d, h
            ld e, l
            ld hl, W7 + $78C9
            ld bc, 3
            call memcpy
            ld c, $21
            ld a, $6E
            call zpy
            ld d, h
            ld e, l
            ld hl, W7 + $78CC
            ld bc, 3
            call memcpy
            ld hl, W7 + $78C9
            ld de, 6
            call memclr
            jp eff_dmg

; 31/B658 attack effect $19: chocobo dash (80% run, not from bosses)
eff_dash:   ld a, [W7 + $7ED8]
            bit 7, a
            jr nz, eff_inef
            ld a, 99
            call rnd_0a
            cp $50
            jr nc, eff_inef
            ld a, 2
            ld [W7 + $78D3], a
            jp eff_end
eff_inef:   ld hl, W7 + $7E93
            inc [hl]
            ld a, $3B
            ld [W7 + $78DA], a
            jp eff_end

; 31/B688 attack effect $2A: zantetsuken (60%: all monsters dead; not bosses)
eff_zan:    ld a, [W7 + $7ED8]
            bit 7, a
            jr nz, eff_inef
            ld a, 99
            call rnd_0a
            cp $3C
            jr nc, eff_inef
            ld hl, BZ + $E0
            ld b, 8
.d:         set 7, [hl]
            inc hl
            inc hl
            dec b
            jr nz, .d
            jp eff_end

; 31/B6B0 attack effect $2F: rend (60%: the target dead; not bosses)
eff_rend:   ld a, [W7 + $7ED8]
            bit 7, a
            jr nz, eff_inef
            ld a, 99
            call rnd_0a
            cp $3C
            jr nc, eff_inef
            ld c, 3
            ld a, $70
            call zpy
            xor a
            ld [hl+], a
            ld [hl], a
            ld a, [BZ + $64]
            ld e, a
            ld d, 0
            ld hl, BZ + $E0
            add hl, de
            set 7, [hl]
            jp eff_end

; 31/B6DD calculate restorative damage: power vs m.defence, multiplier 2 -> $78
restor:     xor a
            ld [BZ + $28], a
            ld [BZ + $29], a
            ld [BZ + $2B], a
            ld a, 2
            ld [BZ + $27], a
            ld a, [BZ + $7C]
            ld [BZ + $24], a
            ld a, [W7 + $7402]
            ld [BZ + $25], a
            ld c, $15
            ld a, $70
            call zpy
            ld a, [hl]
            ld [BZ + $26], a
            call calc_dmg
            ld a, [BZ + $1C]
            ld [BZ + $78], a
            ld a, [BZ + $1D]
            ld [BZ + $79], a
            ret

; 31/B7F1 remove status $24 (bit 0: status 2)
rem_status: ld a, [BZ + $24]
            and 1
            jr nz, .s2
            ld c, 1
            ld a, $70
            call zpy
            ld a, [BZ + $24]
            and [hl]
            jp z, atk_ineff
            ld a, [BZ + $24]
            cpl
            and [hl]
            ld [hl], a
            push af
            ld a, [BZ + $64]
            ld e, a
            ld d, 0
            ld hl, BZ + $E0
            add hl, de
            pop af
            ld [hl], a
            call .self
            ld a, [BZ + $24]
            ld c, 0
.f:         add a, a
            jr c, .f1
            inc c
            jr .f
.f1:        ld a, c
            cp 2
            jr c, .f2
            add a, 3
.f2:        ld [W7 + $78D9], a
            ret
.s2:        ld c, 1
            ld a, $70
            call zpy
            ld a, [hl+]
            or [hl]
            jp z, atk_ineff
            dec hl
            ld a, [BZ + $24]
            cp $FF
            ld a, $80
            jr z, .a
            ld a, $BF
.a:         and [hl]
            ld [hl+], a
            ld a, [BZ + $24]
            cp $FF
            ld a, 0
            jr z, .b
            ld a, [hl]
            and $F9
.b:         ld [hl], a
            ld a, [BZ + $64]
            ld e, a
            ld d, 0
            ld hl, BZ + $E0
            add hl, de
            xor a
            ld [hl+], a
            ld [hl], a
            call .self                      ; (HL: E0 + x + 1)
            ret nz
            dec hl
            ld de, $10
            add hl, de
            ld [hl], a                      ; (FF3: $F0 + x = A, the self status)
            ret
; 31/B865: a self target: the attacker's buffer = the target's ([HL] = $E0 + x); NZ if not self
.self:      push hl
            call tgt_flags
            ld [BZ + $18], a
            call atk_flags
            ld b, a
            ld a, [BZ + $18]
            cp b
            pop hl
            ret nz
            ld a, [hl]
            push hl
            ld de, $10
            add hl, de
            ld [hl], a
            pop hl
            xor a
            ret

; 31/B875: carry set if the target isn't immune to status $24 (after the hit check)
stat_imm:   call atk_hit
            ld c, $24
            ld a, $70
            call zpy
            ld a, [BZ + $24]
            and [hl]
            scf
            ret z
            and a
            ret

; 31/B88F apply elemental modifiers -> $27 (absorbed: healing instead, out of the damage effect)
elem_mod:   xor a
            ld [BZ + $27], a
            ld c, $24
            ld a, $70
            call zpy
            ld a, [hl]
            and 1
            jr z, .w
            ld c, $20
            ld a, $70
            call zpy
            ld a, [W7 + $7400]
            and [hl]
            jr z, .w
            ld a, 4
            ld [BZ + $27], a
            pop hl
            ld a, 2
            ld [BZ + $54], a
            jp eff_heal2
.w:         ld c, $12
            ld a, $70
            call zpy
            ld a, [W7 + $7400]
            and [hl]
            jr nz, .x4
            ld c, $33                       ; (FF3's boost test shifts the wrong way: never)
            ld a, $6E
            call zpy
            ld a, [hl]
            and $E0
            add a, a
            add a, a
            add a, a
            ld b, a
            ld a, [W7 + $7400]
            and b
            jr z, .s
.x4:        ld a, 4
            ld [BZ + $27], a
            ret
.s:         ld c, $20
            ld a, $70
            call zpy
            ld a, [W7 + $7400]
            and [hl]
            jr nz, .x1
            ld a, [hl]
            cp 2
            jr z, .x1
            ld a, 2
            jr .x
.x1:        ld a, 1
.x:         ld [BZ + $27], a
            ret

; 31/B8E7 apply m.evade (members on members with hits: none), then 31/B921 check if the attack
; was effective: Z (and the target out of the mask) if no hits
m_evade:    call atk_flags
            bit 7, a
            jr nz, .e
            call tgt_flags
            bit 7, a
            jr nz, .e
            ld a, [BZ + $7C]
            and a
            jr nz, .s
.e:         ld c, $13
            ld a, $70
            call zpy
            ld a, [hl+]
            ld [BZ + $24], a
            ld a, [hl]
            ld [BZ + $25], a
            ld c, 1
            ld a, $70
            call zpy
            ld a, [hl]
            and 4
            jr z, .b
            ld a, [BZ + $25]
            srl a
            ld [BZ + $25], a
.b:         ld a, [hl]
            and $28
            jr z, .h
            xor a
            ld [BZ + $24], a
.h:         call hit_count
            ld b, a
            ld a, [BZ + $7C]
            sub b
            jr nc, .s
            xor a
.s:         ld [BZ + $7C], a
            ; (fall through)
atk_hit:    ld a, [BZ + $7C]
            and a
            ret nz
            jp atk_ineff

; 31/BE43 apply magic status: hit % = hits x 100 / tries
mag_status: ld a, [BZ + $7C]
            and a
            ret z
            ld a, [W7 + $7403]
            and a
            ret z
            ld b, a
            ld c, $24
            ld a, $70
            call zpy
            ld a, [hl]
            and b
            ret nz
            ld a, [BZ + $7C]
            ld [BZ + $18], a
            ld a, 100
            ld [BZ + $1A], a
            xor a
            ld [BZ + $19], a
            ld [BZ + $1B], a
            call bmul16
            ld a, [BZ + $38]
            ld [BZ + $1A], a
            ld a, [BZ + $1C]
            ld [BZ + $18], a
            ld a, [BZ + $1D]
            ld [BZ + $19], a
            xor a
            ld [BZ + $1B], a
            call bdiv16
            ld a, [BZ + $1C]
            ld [BZ + $25], a
            ld a, [BZ + $7C]
            ld [BZ + $24], a
            call hit_count
            and a
            ret z
            ld a, [W7 + $7403]
            ld [BZ + $24], a
            jp app_status

; 31/B9FA do reflect effect (monsters <-> members only; the spell reflectable, 31/BB0E): a random
; living target on the caster's side
do_reflect: call atk_flags
            bit 7, a
            jr nz, .m
            call tgt_flags
            bit 7, a
            ret z
            jr .r
.m:         call tgt_flags
            bit 7, a
            ret nz
.r:         ld a, [W7 + $7E88]
            ld [BZ + $18], a
            srl a
            srl a
            srl a
            ld e, a
            ld d, 0
            ld hl, REFL_T
            add hl, de
            call bd_rd
            ld b, a
            ld a, [BZ + $18]
            and 7
            inc a
            ld c, a
            ld a, b
.s:         add a, a
            dec c
            jr nz, .s
            ret nc
            ld a, [BZ + $70]
            ld [W7 + $78B5], a
            ld a, [BZ + $71]
            ld [W7 + $78B6], a
            call tgt_flags
            push af
            and 7
            call bitmask
            ld b, a
            ld a, [W7 + $7EB8]
            or b
            ld [W7 + $7EB8], a
            ld c, $26
            ld a, $70
            call zpy
            ld [hl], 0
            xor a
            ld [BZ + $24], a
            ld [BZ + $27], a
            ld a, 3
            ld [BZ + $25], a
            pop af
            bit 7, a
            jr nz, .t
            ld a, 4
            ld [BZ + $24], a
            ld a, $0B
            ld [BZ + $25], a
            ld a, $FC
            ld [BZ + $27], a
.t:         ld a, 1
            ld [BZ + $21], a
            ld a, [BZ + $24]
            ld b, a
            ld a, [BZ + $25]
            call rnd_xa
            push af
            ld b, a
            ld a, [BZ + $27]
            add a, b
            ld [BZ + $26], a
            pop af
            call rec_ptr
            ld a, $70
            call zpset
            ld c, 1
            ld a, $70
            call zpy
            ld a, [hl+]
            and $C0
            jr nz, .t
            ld a, [hl]
            and 1
            jr nz, .t
            ld a, [BZ + $26]
            call bitmask
            push af
            ld a, [W7 + $7EC1]
            inc a
            ld e, a
            ld d, 0
            ld hl, W7 + $7EB8
            add hl, de
            pop af
            ld [hl], a
            ld hl, W7 + $7574
            inc [hl]
            ret

; ---- 35/A367 action $14: magic ($1A: the spell / attack id)
act_magic:  ld a, [BZ + $1A]
            push af
            push af
            call atk_flags
            and $10
            jr z, .m
            ld a, [BZ + $1A]                ; (a monster's attack: its id)
            or $80
            ld [W7 + $78D7], a
            pop af
            jr .v
.m:         pop af                          ; (a member's spell: id - $C8)
            ld a, [BZ + $1A]
            sub $C8
            push af
            or $80
            ld [W7 + $78D7], a
            pop af
.v:         cp 4                            ; (cure-type spells keep dead targets)
            jr z, .go
            cp $19
            jr z, .go
            cp $12
            jr z, .t
            cp $0B
            jr nz, .val
.t:         ld c, 1
            ld a, $70
            call zpy
            bit 7, [hl]
            jr z, .go
.val:       call val_tgts
.go:        pop af
            ld [BZ + $1A], a
            ld a, 1
            ld [W7 + $78D5], a
            ld a, [W7 + $78D9]              ; (a summon's name)
            cp $FF
            jr z, .e
            ld [W7 + $78D7], a
            ld a, $FF
            ld [W7 + $78D9], a
.e:         jp magic_eff

; 35/A3D7 validate targets: dead / stone / jumping ones out of $7E99 (-> $7E9B)
val_tgts:   xor a
            ld [BZ + $24], a
.l:         ld a, [W7 + $7E9A]
            and $40
            ld a, [BZ + $24]
            jr z, .c
            add a, 4
.c:         call rec_ptr
            ld a, l
            ld [BZ + $1A], a
            ld a, h
            ld [BZ + $1B], a
            push hl
            ld a, [BZ + $24]
            call bitmask
            ld b, a
            ld a, [W7 + $7E99]
            and b
            pop hl
            jr z, .n
            inc hl
            ld a, [hl+]
            and $C0
            jr nz, .x
            ld a, [hl]
            and 1
            jr z, .n
.x:         ld a, b
            cpl
            ld b, a
            ld a, [W7 + $7E99]
            and b
            ld [W7 + $7E99], a
.n:         ld a, [BZ + $24]
            inc a
            ld [BZ + $24], a
            cp 8
            jr nz, .l
            ld a, [W7 + $7E99]
            ld [W7 + $7E9B], a
            ret

; 35/A56F show magic message (the spell's own message, ineffective, absorbed / undead /
; backfired by $54)
mag_msg:    ld a, [W7 + $7E88]
            ld [BZ + $24], a
            cp $5B
            jr nc, .k                       ; (none, or not a spell)
            ld a, [W7 + $78DA]
            cp $44
            ret z                           ; ("Searching...": nothing more)
            ld a, [W7 + $7E9B]
            and a
            jr nz, .h
            ld a, [BZ + $54]
            cp 3
            jr z, .k
            ld a, $3B                       ; Ineffective
            call .q
.h:         ld a, [BZ + $54]                ; (life on undead: the death spell's message; death
            cp 5                            ;   on undead: life's)
            ld b, $34
            jr z, .h1
            cp 4
            jr nz, .h2
            ld b, 1
.h1:        ld a, b
            ld [BZ + $24], a
            xor a
            ld [BZ + $54], a
.h2:        call .qa
            ld a, [hl]
            and a
            jr nz, .s
            ld [hl], $FF
            jr .h
.s:         ld a, [BZ + $24]                ; the spell's bit in 35/A5FD: its message $0640 +
            srl a
            srl a
            srl a
            ld e, a
            ld d, 0
            ld hl, MAGMSG_T
            add hl, de
            call bd_rd
            ld b, a
            ld a, [BZ + $24]
            and 7
            inc a
            ld c, a
            ld a, b
.b:         add a, a
            dec c
            jr nz, .b
            jr nc, .k
            ld a, [BZ + $24]
            add a, $20
            call .q
.k:         ld a, [BZ + $54]
            and a
            jr z, .z
            cp 2
            ld b, 1
            jr z, .w
            cp 1
            ld b, $45
            jr z, .w
            ld b, $4F
.w:         ld a, b
            call .q
.z:         xor a
            ld [BZ + $54], a
            ret
.qa:        ld a, [W7 + $78EE]
            ld e, a
            ld d, 0
            ld hl, W7 + $78DA
            add hl, de
            ret
.q:         push af
            call .qa
            pop af
            ld [hl], a
            ret
