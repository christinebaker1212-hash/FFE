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
            ld c, $30
            ld a, $6E
            call zpy
            ld hl, W7 + $7575
            bit 7, [hl]
            jr z, .p
            ld hl, W7 + $7675
.p:         push hl
            ld c, $30
            ld a, $6E
            call zpy
            ld a, [hl]
            pop hl
            bit 7, a
            jr nz, .p1
            ld hl, W7 + $7575
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
            ld [hl-], a
            ld [hl], b                      ; (+4 = max hi? no: see below)
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
            ld a, [hl+]                     ; (FF3's sbc with the carry of the add: clear)
            scf
            ccf
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
