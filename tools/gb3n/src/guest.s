; FF3's guest (the companion walking behind the party: $600B): its set-up (3B/BA15, 3D/B627),
; its trail of the party's last four steps (3D/B6DA), following with FF3's delays and random
; speed (3D/B716, B78A), its graphics (3B/BAA2: 0E/9800 + id, Guzco from 0D/8000; toad / mini when
; the whole party is) and world-map palette (00/96F8), and drawing (3E/DB58, DBA6). Its tiles are
; OBJ $10-$1F (the people from $20, as FF3).

A_GUPAL    = $4788          ; (B_MAPAUX: 00/96F8)

section bank B_FIELD, $7480
; ---- $EE: the guest A (3B/B6A6)
ev_guest:   ld [SRAM_PAGE + $0B], a
            and a
            ret z
            call gu_init
            jp gu_load
; set up at the party (3B/BA15)
gu_init:    ld a, [pos_x]
            ld [gu_x], a
            ld a, [pos_y]
            ld [gu_y], a
gu_reset:   xor a                           ; (3D/B654)
            ld [gu_sx], a
            ld [gu_sy], a
            ld [gu_spd], a
            ld [gu_wait], a
            ld hl, gu_stack
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl], a
            ld a, DIR_D
            ld [gu_face], a
            call gu_here
            ld [gu_z], a
            ret
; the properties of the party's cell (FF3's $43; 0 on the world map's own)
gu_here:    ld a, [pos_x]
            ld d, a
            ld a, [pos_y]
            ld e, a
            call map_mt
            ld l, a
            ld h, W_PROP1
            ld a, [hl]
            ret
; at a map load (3F/E8C3 -> 3D/B627)
gu_mapin:   ld a, [SRAM_PAGE + $0B]
            and a
            ret z
            call gu_init
            jp gu_load

; its tiles (OBJ $10, VRAM bank 1) and, on the world map, its palette (OBJ palette 2)
gu_load:    ld a, [SRAM_PAGE + $0B]
            and a
            ret z
            cp 4
            jr z, .guz
            ld a, [SRAM_PAGE + $102]        ; (the whole party a toad / mini: so is the guest)
            ld hl, SRAM_PAGE + $142
            and [hl]
            ld hl, SRAM_PAGE + $182
            and [hl]
            ld hl, SRAM_PAGE + $1C2
            and [hl]
            ld b, a
            ld a, $16
            bit 5, b
            jr nz, .g
            ld a, $17
            bit 3, b
            jr nz, .g
            ld a, [SRAM_PAGE + $0B]
            add $18 - 1
.g:         and $3F
            add $40
            ld h, a
            ld l, 0
            ld a, B_CHARS
            jr .cp
.guz:       ld hl, $6040                    ; (B_COMMON: 0D/8000)
            ld a, B_COMMON
.cp:        push af                         ; (LCD off or in a guarded load: straight in; from
            ldh a, [rLCDC]                  ;   an event with the screen on: staged, then a
            cpl                             ;   general DMA in V-Blank)
            and $80
            ld d, a
            ld a, [guard_on]
            or d
            jr z, .dma
            ld a, 1
            ldh [rVBK], a
            pop af
            ld de, $8100
            ld bc, $100
            call far_copy
            xor a
            ldh [rVBK], a
            jr .pal
.dma:       pop af
            ld de, SCRATCH
            ld bc, $100
            call far_copy
            call wait_vbl
            ld a, 1
            ldh [rVBK], a
            ld a, high(SCRATCH)
            ldh [rHDMA1], a
            ld a, low(SCRATCH)
            ldh [rHDMA2], a
            ld a, $81
            ldh [rHDMA3], a
            xor a
            ldh [rHDMA4], a
            ld a, 15
            ldh [rHDMA5], a
            xor a
            ldh [rVBK], a
.pal:
            ld a, [wmode]
            and a
            ret z
            ld a, [SRAM_PAGE + $0B]          ; (00/96F8: two colours by guest; colour 1 black)
            dec a
            and $0F
            add a
            add low(A_GUPAL)
            ld l, a
            ld h, high(A_GUPAL)
            ld a, B_MAPAUX
            call far_byte
            ld [nes_pal + 26], a
            inc hl
            ld a, B_MAPAUX
            call far_byte
            ld [nes_pal + 27], a
            ld a, $0F
            ld [nes_pal + 25], a
            jp pal_load

; ---- the party sets off a step: the trail moves back one (3D/B6DA)
gu_push:    ld hl, gu_stack + 2
            ld a, [hl+]
            ld [hl-], a
            dec hl
            ld a, [hl+]
            ld [hl-], a
            dec hl
            ld a, [hl+]
            ld [hl-], a
            ld a, [facing]
            and $0F
            ld [hl], a
            call dest_cell                  ; (FF3's $44: the cell stepped onto)
            call map_mt
            ld l, a
            ld h, W_PROP1
            ld b, [hl]
            ld a, [wmode]
            and a
            jr z, .m
            ld a, b
            and $30
            jr .or
.m:         bit 2, b                        ; (a bridge at an odd level: as it is)
            jr z, .z
            ld a, [z_lev]
            rra
            ret c
.z:         ld a, b
            and $34
            bit 2, a
            jr z, .or
            ld a, $70
.or:        ld hl, gu_stack
            or [hl]
            ld [hl], a
            ret

; ---- each frame: follow, then move (3D/B78A)
gu_update:  ld a, [SRAM_PAGE + $0B]
            and a
            jp z, gu_reset
            ld a, [gu_wait]
            and a
            jr nz, .f
            ld a, [wmode]
            and a
            jr z, .f
            ld a, [veh]
            and a
            jp nz, gu_reset
.f:         call gu_follow
            ld a, [gu_spd]
            and a
            ret z
            ld a, [gu_face]                 ; (3D/B7A7)
            rra
            jr nc, .l
            ld a, [gu_sx]
            ld hl, gu_spd
            add [hl]
            and $0F
            ld [gu_sx], a
            ret nz
            ld hl, gu_x
            inc [hl]
            jr .stop
.l:         rra
            jr nc, .d
            ld a, [gu_sx]
            ld hl, gu_spd
            sub [hl]
            jr nc, .l1
            ld hl, gu_x
            dec [hl]
.l1:        and $0F
            ld [gu_sx], a
            ret nz
            jr .stop
.d:         rra
            jr nc, .u
            ld a, [gu_sy]
            ld hl, gu_spd
            add [hl]
            and $0F
            ld [gu_sy], a
            ret nz
            ld hl, gu_y
            inc [hl]
            jr .stop
.u:         ld a, [gu_sy]
            ld hl, gu_spd
            sub [hl]
            jr nc, .u1
            ld hl, gu_y
            dec [hl]
.u1:        and $0F
            ld [gu_sy], a
            ret nz
.stop:      xor a
            ld [gu_spd], a
            ret
; which step it takes (3D/B716): four behind at once, three, two (waiting every other 16
; frames), one (the world map only while the party waits for it)
gu_follow:  ld a, [gu_spd]
            and a
            ret nz
            ld hl, gu_stack + 3
            ld a, [hl]
            and a
            jr z, .s3
            ld [hl], 0
.go:        ld b, a                         ; (3D/B723)
            and $0F
            ld [gu_face], a
            ld a, b
            and $70
            ld [gu_z], a
            ld a, [frame]
            ld e, a
            ld d, 0
            ld hl, fld_rng
            add hl, de
            ld a, [hl]
            and 2
            jr nz, .sp
            or 1
.sp:        ld [gu_spd], a
            ret
.s3:        dec hl
            ld a, [hl]
            and a
            jr z, .s2
            ld [hl], 0
            jr .go
.s2:        dec hl
            ld a, [hl]
            and a
            jr z, .s1
            ld a, [gu_wait]
            and a
            jr nz, .s2g
            ld a, [frame]
            and $10
            ret nz
.s2g:       ld a, [hl]
            ld [hl], 0
            call .go
            ld a, 1
            ld [gu_spd], a
            ret
.s1:        dec hl
            ld a, [hl]
            and $0F
            ld [gu_face], a
            ld a, [wmode]
            and a
            jr z, .s1n
            ld a, [gu_wait]
            and a
            ret z
            ld a, [hl]
            and a
            jr z, .s1n
            ld [gu_stack + 1], a
            ld [hl], 0
            ld hl, gu_stack + 1
            jr .s2g
.s1n:       xor a
            ld [gu_wait], a
            ret

; ---- drawn into OAM entries 4-7 (3E/DB58, DBA6)
gu_draw:    ld hl, oam_buf + 16
            ld b, 16
            xor a
.c:         ld [hl+], a
            dec b
            jr nz, .c
            ld a, [ev_hide]
            and $C0
            ret nz
            ld a, [SRAM_PAGE + $0B]
            and a
            ret z
            ld a, [gu_wait]
            and a
            jr nz, .s
            ld a, [wmode]
            and a
            jr z, .s
            ld a, [veh]
            and a
            ret nz
.s:         ld a, [gu_x]                    ; on screen: within 5 cells
            ld hl, pos_x
            sub [hl]
            add 5
            cp 11
            ret nc
            sub 5
            swap a
            and $F0
            add VIEW_X * 16 + 8
            ld hl, walk_dx
            sub [hl]
            ld hl, gu_sx
            add [hl]
            ld d, a
            ld a, [gu_y]
            ld hl, pos_y
            sub [hl]
            add 5
            cp 10
            ret nc
            sub 5
            swap a
            and $F0
            add VIEW_Y * 16 + 16 - 4
            ld hl, walk_dy
            sub [hl]
            ld hl, gu_sy
            add [hl]
            ld e, a
            ld a, [gu_face]                 ; the pose: facing (3E/DC1A), the frame halfway
            ld c, $00
            rra
            jr c, .p
            ld c, $10
            rra
            jr c, .p
            ld c, $30
            rra
            jr c, .p
            ld c, $20
.p:         ld a, [gu_sx]
            ld b, a
            ld a, [gu_sy]
            or b
            and 8
            jr z, .f0
            ld a, [gu_sx]                   ; (the bob: left a pixel moving sideways, else up)
            and a
            jr z, .by
            dec d
            jr .bf
.by:        dec e
.bf:        ld a, 8
.f0:        or c
            ld hl, gu_poses
            add l
            ld l, a
            jr nc, .h
            inc h
.h:         ld a, [gu_z]                    ; priority by the cell (3E/D9A7)
            ld c, a
            and $24
            jr z, .pb
            ld a, $20
.pb:        ld [gu_pb], a
            ld a, c
            and $14
            jr z, .pt
            ld a, $20
.pt:        ld [gu_pt], a
            ld bc, oam_buf + 16
            ld a, [gu_pt]
            call .spr                       ; UL
            ld a, e
            add 8
            ld e, a
            ld a, [gu_pb]
            call .spr                       ; DL
            ld a, e
            sub 8
            ld e, a
            ld a, d
            add 8
            ld d, a
            ld a, [gu_pt]
            call .spr                       ; UR
            ld a, e
            add 8
            ld e, a
            ld a, [gu_pb]
.spr:       ld [gu_pc], a
            ld a, e
            ld [bc], a
            inc c
            ld a, d
            ld [bc], a
            inc c
            ld a, [hl+]
            add $10
            ld [bc], a
            inc c
            ld a, [gu_pc]
            xor [hl]
            inc hl
            call oam_attr
            ld [bc], a
            inc c
            ret

section bank B_FIELD, $6820
gu_poses:   ds 64                           ; (3E/DC6A, from the ROM)

section wram, $C0A0
gu_x:       ds 1                            ; FF3's $AC / $AD
gu_y:       ds 1
gu_sx:      ds 1                            ; $13 / $14
gu_sy:      ds 1
gu_spd:     ds 1                            ; $AE
gu_wait:    ds 1                            ; $A9
gu_face:    ds 1                            ; $A7
gu_z:       ds 1                            ; $A8
gu_pt:      ds 1
gu_pb:      ds 1
gu_pc:      ds 1
