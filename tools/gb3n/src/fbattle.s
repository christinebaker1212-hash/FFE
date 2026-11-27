; Battles from the field: FF3's random encounters (3D/BC5B), its field random numbers (3E/C711,
; the table 3F/FE00), and the battle trigger: the battle, then the map loaded again.
TR_BATTLE  = $20            ; (FF3's $AB = $20)

section bank B_FIELD, $4990
; ---- a normal map's tile with property 1 bit 6 ($3D $BDB9): a battle when (0..255) < the map's
; rate; the battle from the map's group (2E/92F0 world 0, 2E/93F0 others)
enc_map:    push af
            push bc
            ld a, [ev_on]                   ; not during an event
            and a
            jr nz, .x
            call f_rnd
            ld hl, enc_rate
            cp [hl]
            jr nc, .x
            ld a, [map_id]
            ld e, a
            ld d, 0
            ld a, [world]
            and a
            ld hl, $92F0 - $4000
            jr z, .w
            ld hl, $93F0 - $4000
.w:         add hl, de
            ld a, B_BSET
            call far_byte
            call enc_group
.x:         pop bc
            pop af
            ret
; ---- the world map ($3D $BC68): rates by world (on foot), groups by area
enc_world:  push af
            push bc
            ld a, [ev_on]
            and a
            jr nz, .x
            ld a, [veh]                     ; the rate by world and vehicle (3D/BC68)
            ld c, a
            ld a, [world]
            and a
            jr nz, .w1
            ld hl, $9D47 - $4000            ; world 0: on foot, canoe, ship; else none
            ld a, c
            and a
            jr z, .r
            ld hl, $9D48 - $4000
            cp 2
            jr z, .r
            ld hl, $9D49 - $4000
            cp 3
            jr z, .r
            jr .x
.w1:        cp 2
            jr nz, .w3
            ld hl, $9D4A - $4000            ; world 2: on foot only
            ld a, c
            and a
            jr z, .r
            jr .x
.w3:        cp 3
            jr nz, .uw
            ld hl, $9D4B - $4000            ; world 3: on foot, canoe, ship; airships when
            ld a, c                         ;   $602F bit 0
            and a
            jr z, .r
            ld hl, $9D4C - $4000
            cp 2
            jr z, .r
            ld hl, $9D4D - $4000
            cp 3
            jr z, .r
            ld hl, $9D4E - $4000
            cp 4
            jr c, .x
            ld a, [SRAM_PAGE + $2F]
            rra
            jr nc, .x
            jr .r
.uw:        ld hl, $9D4F - $4000            ; underwater
.r:         ld a, B_BSET
            call far_byte
            ld [enc_t], a
            call f_rnd
            ld hl, enc_t
            cp [hl]
            jr nc, .x
            ld a, [veh]                     ; the group (3D/BCD1; pos = FF3's $27 + 7)
            ld c, a
            ld a, [world]
            and a
            jr nz, .w2
            ld hl, $9D40 - $4000            ; world 0: canoe / ship groups
            ld a, c
            and a
            jr z, .a0
            cp 2
            jr z, .g0
            ld hl, $9D41 - $4000
            jr .g0
.a0:        ld a, [pos_x]                   ; world 0: 16 areas (2E/9CF0)
            and $7F
            swap a
            srl a
            and 3
            ld b, a
            ld a, [pos_y]
            and $60
            srl a
            srl a
            srl a
            or b
            ld e, a
            ld d, 0
            ld hl, $9CF0 - $4000
            jr .g
.w2:        cp 3
            jr nz, .w4
            ld hl, $9D43 - $4000            ; the surface world: canoe, ship, airship groups
            ld a, c
            cp 2
            jr z, .g0
            ld hl, $9D44 - $4000
            cp 3
            jr z, .g0
            ld hl, $9D45 - $4000
            cp 4
            jr nc, .g0
            ld a, [pos_x]                   ; 64 areas (2E/9D00)
            swap a
            srl a
            and 7
            ld b, a
            ld a, [pos_y]
            and $E0
            srl a
            srl a
            or b
            ld e, a
            ld d, 0
            ld hl, $9D00 - $4000
            jr .g
.w4:        ld hl, $9D42 - $4000            ; the flooded world / under the sea: one group
            cp 2
            jr z, .g0
            ld hl, $9D46 - $4000
.g0:        ld de, 0
.g:         add hl, de
            ld a, B_BSET
            call far_byte
            call enc_group
.x:         pop bc
            pop af
            ret
; ---- the battle from group A ($3D $BD4D: 2E/94F0 + 8 x group, the slot by FF3's chances)
enc_group:  ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, $94F0 - $4000
            add hl, de
            push hl
            ld hl, f_rng + 2                ; ($F7: its own counter)
            inc [hl]
            ld a, [hl]
            call f_tab
            and $3F
            ld hl, enc_prob
            add l
            ld l, a
            jr nc, .p
            inc h
.p:         ld e, [hl]
            ld d, 0
            pop hl
            add hl, de
            ld a, B_BSET
            call far_byte
            ld [bs_id], a
            xor a
            ld [bs_id + 1], a
            ld a, TR_BATTLE
            ld [trig_next], a
            ret
; ---- FF3's field random number ($3E $C711: a counter up or down through 3F/FE00)
; (for the menu: the number in m_rnd)
f_rnd_m:    call f_rnd
            ld [m_rnd], a
            ret
f_rnd:      ld hl, f_rng + 1
            bit 7, [hl]
            dec hl
            jr nz, .dn
            inc [hl]
            jr nz, .t
            jr .w
.dn:        dec [hl]
            jr nz, .t
.w:         inc hl
            ld a, [hl]
            add $A0
            ld [hl-], a
.t:         ld a, [hl]
f_tab:      ld e, a
            ld d, 0
            ld hl, fld_rng
            add hl, de
            ld a, [hl]
            ret

; ---- a battle (the trigger after the step): the battle, then this map again where the party is
battle_run: ld a, [map_id]                  ; the battle background (39/BC00 world 0, BD00)
            ld e, a
            ld d, 0
            ld a, [world]
            and a
            ld hl, $BC00 - $4000
            jr z, .b
            ld hl, $BD00 - $4000
.b:         add hl, de
            ld a, [wmode]
            and a
            jr z, .bg
            ld hl, $BC00 - $4000            ; (the world map: map 0's)
.bg:        ld a, B_BDAT3
            call far_byte
            ld [bs_bg], a
            ld a, [z_lev]
            push af
            %FAR B_BSCR, bs_battle
            ld a, [pos_x]
            ld [enter_x], a
            ld [wm_x], a
            ld a, [pos_y]
            ld [enter_y], a
            ld [wm_y], a
            call keep_people
            call map_change
            pop af
            ld [z_lev], a
            ret
; ---- (B_FIELD, mapped at boot) the title (FF3's game load menu, B_MENU) with the LCD on, then a new game's map or the
; loaded file's world map
title_boot: ld a, LCDC_ON
            ldh [rLCDC], a
            ld a, 3
            ldh [rIE], a
            xor a
            ldh [rIF], a
            ei
            %FAR B_MENU, t_title
            ld a, [m_res]
            and a
            jr z, .new
            cp 2                            ; resumed: the place as it was
            jr z, .res
            ld a, [SRAM_PAGE + $08]         ; a file: its world map position (3E/C0DE)
            ld [world], a
            ld a, [SRAM_PAGE + $09]         ; (FF3's $27 + 7: the party's tile)
            add 7
            ld [enter_x], a
            ld [wm_x], a
            ld a, [SRAM_PAGE + $0A]
            add 7
            ld [enter_y], a
            ld [wm_y], a
            ld a, [SRAM_PAGE + $0F]         ; the vehicle (3E/C0D7)
            ld [veh], a
            ld a, $FF
            ld [map_id], a
            ld a, 1
            ld [wmode], a
            jr .go
.new:       %FAR B_MENU, t_names            ; the party's names (FF3's 3D/B895)
            ld a, START_MAP                 ; (test builds: map 255 = the world map)
            inc a
            jr nz, .go
            inc a
            ld [wmode], a
.res:       ld a, [pos_x]
            ld [enter_x], a
            ld a, [pos_y]
            ld [enter_y], a
.go:        call map_change
            jp main_loop

; Start on the map: FF3's main menu (its screen in B_MENU), then the map again
menu_open:  ld a, [z_lev]
            push af
            %FAR B_MENU, m_main
            ld a, [m_exit]                  ; Exit / Otter's Head: the world map where the
            and a                           ;   party went in (3C/9918)
            jr z, .st
            pop af
            xor a
            ld [map_sp], a
            ld [z_lev], a
            ld a, [wm_x]
            ld [enter_x], a
            ld a, [wm_y]
            ld [enter_y], a
            jp world_back
.st:        ld a, [pos_x]
            ld [enter_x], a
            ld [wm_x], a
            ld a, [pos_y]
            ld [enter_y], a
            ld [wm_y], a
            call keep_people
            call map_change
            pop af
            ld [z_lev], a
            ret
; a shop / inn (B_MENU's screen), then the map again and the inn's event
shop_talk:  ld a, [z_lev]
            push af
            %FAR B_MENU, m_shop
            ld a, [m_res]                   ; (menu variables live in the map's tables: read
            ld [sh_ev], a                   ;   before the map comes back)
            ld a, [pos_x]
            ld [enter_x], a
            ld a, [pos_y]
            ld [enter_y], a
            call keep_people
            call map_change
            pop af
            ld [z_lev], a
            ld a, [sh_ev]
            jp ev_start
; the next map load keeps the people where they are (a map, not the world map)
keep_people:
            ld a, [wmode]
            and a
            ld a, 1
            jr z, .k
            xor a
.k:         ld [npc_keep], a
            ret
; the map's battle rate at a map's start (FF3's $F8: 39/BE00 world 0, 39/BF00 others)
enc_setrate:
            ld a, [map_id]
            ld e, a
            ld d, 0
            ld a, [world]
            and a
            ld hl, $BE00 - $4000
            jr z, .r
            ld hl, $BF00 - $4000
.r:         add hl, de
            ld a, B_BDAT3
            call far_byte
            ld [enc_rate], a
            ret

fld_rng:    ds 256                          ; (3F/FE00, from the ROM: ROMDATA)
enc_prob:   ds 64                           ; (3D/BD78)

section wram, $C2D0
f_rng:      ds 3                            ; FF3's $F5, $F6, $F7
enc_rate:   ds 1
enc_t:      ds 1
sh_ev:      ds 1
veh:        ds 1                            ; FF3's $42: the vehicle (0 on foot)
