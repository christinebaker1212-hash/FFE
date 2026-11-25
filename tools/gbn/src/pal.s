; FF1 native engine: the palettes, one logic for every scene (owner, 2026-11-25: one, unified
; palette logic that the game calls for every scene, lightweight, and easy to reference).
;
; The Color's 16 palettes live in shadows in WRAM: sh_pal (BG 0-7, 64 bytes) and pal_ob (OBJ
; 0-7). Every scene and effect writes the shadows, never the hardware:
;   bcps_w / bcpd_w      BG index / colour byte (as BCPS / BCPD; keeps A and the flags)
;   ocps_w / ocpd_w      OBJ index / colour byte (as OCPS / OCPD)
;   bcpd_r / ocpd_r      read a shadow byte (as reading BCPD / OCPD)
;   pal_blk / cgb_pal32  B bytes of BG colours from HL, LCD colour mode applied (cc.s)
;   text_pals            the windows' palette 7 and the outside black 5 (every screen)
; A write marks its half dirty (pal_dirty); the V-Blank handler's first palette work (pal_up,
; right after the map's own) sends the changed halves up, so no colour write can land in
; drawing time and be dropped, or tear. lcd_on sends everything before the screen shows
; (pal_on). Fades and the encounter transition show their scaled copy (fd_tmp, pal_fd 1)
; and never read colours back from the screen: the shadows stay the screen's real colours.
; (Reading the screen back caught the gradient's line colours and half-way fade colours as
; the windows' colours: blown-out borders after shop menus.)
; Line effects stay direct: the gradient (text.s stat_gr / gr_vbl) and the airship's sky
; (air.s ap_p7) change palette 7 by line; their frame starts after pal_up in the V-Blank.
; The plain Game Boy / Super Game Boy: BGP / OBP0 / OBP1 as before (bgp_w, obp0_w).

section bank 99, $75A0
; V-Blank (pal_up): the dirty halves of the shadows, or of the fade's colours, to the Color
pal_put:    ld a, [pal_dirty]
            ld e, a
            xor a
            ld [pal_dirty], a
            ldh a, [is_cgb]
            and a
            ret z
            ld hl, sh_pal
            ld a, [pal_fd]
            and a
            jr z, .s
            ld hl, fd_tmp
.s:         bit 1, e
            jr z, .o
            call .room                      ; (no room left in this V-Blank: the next one)
            jr nc, .d1
            ld a, $80
            ldh [rBCPS], a
            ld c, low(rBCPD)
            call .c64
            jr .o2
.d1:        ld a, 2
            call .keep
.o:         ld bc, 64
            add hl, bc
.o2:        bit 0, e
            ret z
            call .room
            ld a, 1
            jr nc, .keep
            ld a, [pal_fd]
            and a
            jr nz, .f
            ld hl, pal_ob
.f:         ld a, $80
            ldh [rOCPS], a
            ld c, low(rOCPD)
.c64:       ld b, 64
.l:         ld a, [hl+]
            ldh [c], a
            dec b
            jr nz, .l
            ret
; C: a half (64 bytes, ~2.3 lines) still fits this V-Blank (LY 144-149)
.room:      ldh a, [rLCDC]                  ; (the LCD off: always)
            rlca
            ccf
            ret c
            ldh a, [rLY]
            sub 144
            cp 6
            ret
; the half A (2 BG, 1 OBJ) left dirty for the next V-Blank
.keep:      push hl
            ld hl, pal_dirty
            or [hl]
            ld [hl], a
            pop hl
            ret
; lcd_on (pal_on): everything up now; a fade-in to follow starts from black (white after the
; encounter transition)
pal_on9:    ld a, [fd_in]
            and a
            jr z, .s
            call fd_fill
            jr .p
.s:         xor a
            ld [pal_fd], a
.p:         ld a, 3
            ld [pal_dirty], a
            jr pal_put
; fd_tmp all black (white: fd_wh), shown
fd_fill:    ld hl, fd_tmp
            ld b, 64
            ld a, [fd_wh]
            and a
            jr nz, .w
.z:         xor a
            ld [hl+], a
            ld [hl+], a
            dec b
            jr nz, .z
            jr .x
.w:         ld a, $FF
            ld [hl+], a
            ld a, $7F
            ld [hl+], a
            dec b
            jr nz, .w
.x:         ld a, 1
            ld [pal_fd], a
            ret
; a fade's colours: the shadows (BG, then OBJ) -> fd_pal
fd_get:     ld hl, sh_pal
            ld de, fd_pal
            ld bc, 64
            call memcpy
            ld hl, pal_ob
            ld bc, 64
            jp memcpy
; a fade-in done: the shadows shown again
fd_done:    xor a
            ld [pal_fd], a
            ld a, 3
            ld [pal_dirty], a
            ret

; ---- the encounter transition's colours (loc.s bt_trans2: the strips towards white), each
; frame: to the shadows (up in the next V-Blank)
section bank 99, $6198
tr_pals:    ld a, [tr_f]
            and a
            ret z
            ldh a, [is_cgb]
            and a
            jr z, .d
            ld hl, TR_PAL                   ; (shown as a fade's colours: the shadows keep
            ld de, fd_tmp                   ;   the field's own)
            ld bc, 128
            call memcpy
            ld a, 1
            ld [pal_fd], a
            ld a, 3
            ld [pal_dirty], a
            ret
.d:         ld a, [tr_f]                    ; DMG / SGB: the shades a step lighter per 2 levels
            dec a
            srl a
            ld [fd_lv], a
            jp fd_dmgw

; ---- a new game's way into the world (owner, 2026-11-25: from the naming screen to the world
; map it was just a cut). The party screen fades out slowly with the music (the master volume
; down with it), a moment of silence on black (white on the plain Game Boy, its switched-off
; screen), then the world map fades in slowly as the overworld's theme starts.
section bank 99, $7950
ng_out9:    ld a, 4                         ; (each step 6 frames, 8 steps on the Color)
            ld [fd_slow], a
            ld a, [opt_vol]
            ld [fd_vol], a
            ldh a, [is_cgb]
            and a
            jr nz, .c
            ld a, 10                        ; (DMG / SGB: 3 shade steps of 12 frames)
            ld [fd_slow], a
            call fade_out
            jr .k
.c:         call gr_fd                      ; (the Color: 8 levels, from the shadows)
            call fd_get
            ld a, 1
            ld [fd_fine], a
            ld a, 7
.l:         ld [fd_lv], a
            call fd_step
            ld a, [fd_lv]
            dec a
            cp $FF
            jr nz, .l
            xor a
            ld [fd_fine], a
            ld [fd_act], a
            inc a
            ld [fd_saved], a
.k:         ld a, $80                       ; (the music off, the volume back for the world)
            call snd_track
            xor a
            ld [fd_vol], a
            ld [fd_slow], a
            ld b, 40
.h:         push bc
            call wait_vbl
            pop bc
            dec b
            jr nz, .h
            call opt_apply
            ld a, 1                         ; (the world: faded in, ng_in9)
            ld [fd_in], a
            ret
ng_in9:     ld a, F3_BANK                   ; (the party as it stands now: the vehicle is
            ld hl, make_oam                 ;   set after the map's load; make_oam maps the
            call bank_call                  ;   map's bank: called so this one comes back)
            call dma_safe
            ldh a, [is_cgb]
            and a
            jr nz, .c
            ld a, 14                        ; (DMG / SGB: 3 shade steps of 16 frames)
            ld [fd_slow], a
            call fade_in
            jr .x
.c:         xor a
            ld [fd_in], a
            call gr_fd
            call fd_get
            ld a, 5                         ; (8 levels of 7 frames)
            ld [fd_slow], a
            ld a, 1
            ld [fd_fine], a
.l:         ld [fd_lv], a
            call fd_step
            ld a, [fd_lv]
            inc a
            cp 9
            jr c, .l
            call fd_done
            xor a
            ld [fd_fine], a
            ld [fd_wh], a
            ld [fd_act], a
.x:         xor a
            ld [fd_slow], a
            ld [ng_new], a
            ret
; a slow fade's extra frames after a step; the music's master volume a step down every
; fourth frame while fd_vol is counting
fd_xw9:     ld a, [fd_slow]
            ld b, a
.w:         push bc
            call wait_vbl
            pop bc
            ld a, [fd_vol]
            and a
            jr z, .n
            ld a, b
            and 3
            jr nz, .n
            ld hl, fd_vol
            dec [hl]
            ld a, [hl]
            ld c, a
            swap a
            or c
            ldh [$FF24], a
.n:         dec b
            jr nz, .w
            ret

; ---- the letters' shadow (owner, 2026-11-25: a 1 px shadow down and right, not pure black but
; dark enough on light and dark window colours; Color only). The Color font carries it in colour
; 0 (text.font_banks), and the windows' colour 0 is the window colour at a quarter: darker than
; every line of the gradient (the window colour down to a third), whatever colour Config sets.
; The frame's outer edge and the pictures' outlines (colour 0 too) become this near-black.
section bank 99, $7D90
wp_dark:    ld a, [win_r]
            srl a
            srl a
            ld c, a                         ; r / 4
            ld a, [win_g]
            srl a
            srl a
            ld d, a                         ; g / 4
            swap a
            rlca
            and $E0
            or c
            ld [win_pal], a                 ; low: r | g << 5
            ld a, d
            rrca
            rrca
            rrca
            and 3
            ld c, a
            ld a, [win_b]
            srl a
            srl a
            add a, a
            add a, a
            or c
            ld [win_pal + 1], a             ; high: g >> 3 | b << 2
            ret
