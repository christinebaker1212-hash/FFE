; FF3's event effects (bank $3B): the screen shake ($D0), the flash ($D1 / $E2), the blue
; darkening and its undoing ($D2 / $D3: 3E/D3AF), the map palettes again ($E0 / $E1), and the
; people's jumps, circles, spins and dance (3B/AB71-ADB0) with their tables from the ROM.

section bank B_FIELD, $5D00
; ---- a frame while an effect runs: V-Blank work, sound, the pad
ev_fx_fr:   call wait_vbl
            call ev_pflush
            call field_vbl
            call snd_frame
            jp read_pad
; ... with only the people drawn again (3B/ABB1)
ev_nfr:     call npc_oam
            call wait_vbl
            call hram_dma
            call snd_frame
            jp read_pad

; $D0: the sound and 17 frames of the picture moved 2 pixels every other pair (3B/B938)
ev_shake:   ld a, $58
            call sfx_play
            xor a
.l:         push af
            call wait_vbl
            call field_vbl
            pop af
            push af
            and 2
            ld b, a
            ldh a, [rSCX]
            xor b
            ldh [rSCX], a
            call snd_frame
            call read_pad
            pop af
            inc a
            cp $11
            jr c, .l
            ret
; $D1: the sound and the flash; $E2: the flash (3B/B913: grey every other pair of frames)
ev_flash:   ld a, $59
            call sfx_play
ev_flash2:  xor a
.l:         push af
            srl a
            and 1
            call ev_grey
            call ev_fx_fr
            pop af
            inc a
            cp $11
            jr c, .l
            xor a
            call ev_grey
            jp ev_fx_fr
; the palettes in grey (A = 1) or not, shown in the next V-Blank
ev_grey:    ld [pl_grey], a
            call pal_load
            xor a
            ld [pl_grey], a
            ld a, 1
            ld [ev_pnew], a
            ret
; (the palettes made by ev_grey / ev_wshow go to the Color in V-Blank)
ev_pflush:  ld a, [ev_pnew]
            and a
            ret z
            xor a
            ld [ev_pnew], a
            jp pal_apply

; $D2: the BG colours step to blue, a step every 4 frames (3E/D3B5)
ev_dark:    ld hl, nes_pal
            ld de, ev_w
            ld b, 16
.c:         ld a, [hl+]
            and $1F
            ld [de], a
            inc de
            dec b
            jr nz, .c
            ld a, 1
.l:         push af
            and 3
            jr nz, .f
            call ev_step2
            jr z, .x
.f:         call ev_wshow
            pop af
            inc a
            jr .l
.x:         pop af
            ret
; $D3: back to the map's colours (3E/D3E5), then the map's palette as it is
ev_undark:  ld a, 1
.l:         push af
            and 3
            jr nz, .f
            call ev_stepo
            jr z, .x
.f:         call ev_wshow
            pop af
            inc a
            jr .l
.x:         pop af
            call pal_load
            call wait_vbl
            call pal_apply
            call snd_frame
            jp read_pad
; one step of each working colour's hue toward blue ($02) / the map's own (3E/D440 / D410):
; Z set when none changed
ev_step2:   ld c, 16
            ld hl, ev_w
            ld e, 0
.l:         ld a, [hl]
            cp $0F
            jr z, .n
            ld d, 2
            call ev_hstep
.n:         inc hl
            dec c
            jr nz, .l
            ld a, e
            and a
            ret
ev_stepo:   ld c, 16
            ld hl, ev_w
            ld e, 0
.l:         ld a, [hl]
            cp $0F
            jr z, .n
            push hl
            ld a, l
            sub low(ev_w)
            add low(nes_pal)
            ld l, a
            ld a, high(nes_pal)
            adc 0
            ld h, a
            ld a, [hl]
            and $0F
            ld d, a
            pop hl
            call ev_hstep
.n:         inc hl
            dec c
            jr nz, .l
            ld a, e
            and a
            ret
; [HL]'s hue one toward D (its $10 kept); E + 1 when changed
ev_hstep:   ld a, [hl]
            and $10
            ld b, a
            ld a, [hl]
            and $0F
            cp d
            ret z
            jr c, .up
            dec a
            jr .s
.up:        inc a
.s:         or b
            ld [hl], a
            inc e
            ret
; a frame with the working colours as the BG palettes (3E/D381)
ev_wshow:   ld hl, nes_pal
            ld de, ev_sv
            ld bc, 16
            call memcpy
            ld hl, ev_w
            ld de, nes_pal
            ld bc, 16
            call memcpy
            call pal_load
            ld hl, ev_sv
            ld de, nes_pal
            ld bc, 16
            call memcpy
            call wait_vbl
            call pal_apply
            call snd_frame
            jp read_pad

; $E0 / $E1: the map's palettes again (3A/8509)
ev_repal:   ld a, [wmode]
            and a
            jr z, .m
            ld a, [world]
            swap a
            add low(W_PALS)
            ld l, a
            ld h, high(W_PALS)
            ld de, nes_pal
            ld bc, 16
            ld a, B_WINFO
            call far_copy
            call pal_spr
            jr .l
.m:         call pal_gather
.l:         call pal_load
            call wait_vbl
            call pal_apply
            call snd_frame
            jp read_pad

; ---- people (L = the slot): jumps ($0A left, $0B right), the walking frames on / off ($0C /
; $0D), a circle ($0E), a spin ($0F) (3B/AD1F-AD52)
ev_npcx:    cp $0C
            jr nz, .d
            ld a, l
            inc a
            ld l, a
            set 6, [hl]
            ret
.d:         cp $0D
            jr nz, .e
            ld a, l
            inc a
            ld l, a
            ld a, [hl]
            and $B0
            ld [hl], a
            ret
.e:         ld b, a
            ld a, l
            ld [ev_ns], a
            xor a
            ld [ev_74], a
            ld a, b
            cp $0E
            jp z, ev_circ
            cp $0F
            jp z, ev_spin
            cp $0A                          ; a jump (3B/AB71): 48 frames over a cell
            ld a, 0
            jr nz, .r
            inc a
.r:         ld [ev_75], a
            ld a, l
            add 5
            ld l, a
            dec [hl]                        ; y - 1, sub-y 15
            inc l
            inc l
            ld [hl], 15
.j:         call ev_jstep
            call ev_nfr
            ld a, [ev_74]
            cp $30
            jr c, .j
            ld a, [ev_ns]
            ld l, a
            ld h, high(NPC1)
            add 6
            ld l, a
            xor a
            ld [hl+], a
            ld [hl], a
            ld a, l
            sub 2
            ld l, a
            inc [hl]                        ; y + 1
            dec l
            ld a, [hl]
            dec l
            dec l
            ld [hl], a                      ; +2 = +4
            ret
ev_jstep:   ld a, [ev_ns]                   ; (3B/ABBF)
            add 6
            ld l, a
            ld h, high(NPC1)
            ld a, [ev_75]
            and a
            jr nz, .lt
            ld a, [hl]
            inc a
            and 15
            ld [hl], a
            jr nz, .h
            dec l
            dec l
            inc [hl]
            jr .h
.lt:        ld a, [hl]
            sub 1
            push af
            and 15
            ld [hl], a
            pop af
            jr nc, .h
            dec l
            dec l
            dec [hl]
.h:         ld a, [ev_74]
            cp $18
            jr c, .y
            ld b, a
            ld a, $2F
            sub b
.y:         ld e, a
            ld d, 0
            ld hl, nj_h
            add hl, de
            ld a, [hl]
            xor $0F
            ld b, a
            ld a, [ev_ns]
            add 7
            ld l, a
            ld h, high(NPC1)
            ld [hl], b
            ld hl, ev_74
            inc [hl]
            ret
; a circle (3B/AC68): the dance's first 50 steps, a step every other frame
ev_circ:    ld hl, frame
            inc [hl]
            ld a, [hl]
            rra
            ld a, [ev_74]
            adc 0
            ld [ev_74], a
            cp $32
            jr nc, .x
            ld a, [ev_ns]
            ld l, a
            ld a, [ev_74]
            call ev_dpose
            call ev_nfr
            jr ev_circ
.x:         ld a, [ev_ns]
            add 6
            ld l, a
            ld h, high(NPC1)
            xor a
            ld [hl+], a
            ld [hl], a
            ret
; a spin (3B/AC25): the four ways, a turn every 8 frames, twice round
ev_spin:    ld hl, frame
            inc [hl]
            ld a, [hl]
            and 7
            cp 7
            ccf
            ld a, [ev_74]
            adc 0
            ld [ev_74], a
            cp 8
            ret nc
            and 3
            ld e, a
            ld d, 0
            ld hl, ns_tab
            add hl, de
            ld a, [hl]
            add a
            add a
            add a
            ld b, a
            ld a, [ev_ns]
            add 14
            ld l, a
            ld h, high(NPC1)
            ld [hl], b
            call ev_nfr
            jr ev_spin
ns_tab:     db $02, $06, $00, $04            ; (3B/AC64: word offsets of the facings)
; person L at dance step A: sub-x, sub-y, facing (3B/ADB1, AE05, AE59)
ev_dpose:   ld e, a
            ld d, 0
            ld h, high(NPC1)
            push hl
            ld hl, dn_x
            add hl, de
            ld b, [hl]
            ld hl, dn_y
            add hl, de
            ld c, [hl]
            ld hl, dn_f
            add hl, de
            ld a, [hl]
            swap a
            pop hl
            push af
            ld a, l
            add 6
            ld l, a
            ld [hl], b
            inc l
            ld [hl], c
            ld a, l
            add 7
            ld l, a
            pop af
            ld [hl], a
            ret
; $DA: everyone dances, five times (3B/ACB9, AD5D)
ev_dance:   xor a
            ld [ev_74], a
            ld [ev_75], a
.l:         ld hl, frame
            inc [hl]
            ld a, [hl]
            and 3
            cp 3
            ccf
            ld a, [ev_74]
            adc 0
            ld [ev_74], a
            cp $54
            jr c, .p
            xor a
            ld [ev_74], a
            ld hl, ev_75
            inc [hl]
            ld a, [hl]
            cp 5
            ret nc
            xor a
.p:         ld [ev_t], a
            ld c, 0
.s:         ld l, c
            ld a, [ev_t]
            push bc
            call ev_dpose
            pop bc
            ld a, c
            add 16
            ld c, a
            cp $A0
            jr c, .s
            call ev_nfr
            jr .l

; ---- the damage floor and poison (3F/E54C-E56D, 3B/A09B-A12A)
; the cell ahead: a damage floor (property 1 bit 3, property 2 0; normal maps)
fx_flset:   xor a
            ld [fl_dmg], a
            ld a, [wmode]
            and a
            ret nz
            call dest_cell
            call map_mt
            ld l, a
            ld h, W_PROP1
            bit 3, [hl]
            ret z
            inc h
            ld a, [hl]
            and a
            ret nz
            inc a
            ld [fl_dmg], a
            ret
; each frame of a step on it: grey every other frame
fx_walkf:   ld a, [fl_dmg]
            and a
            ret z
            ld a, [frame]
            and 1
            jp ev_grey
; the step's end: poisoned members lose 1 HP (sound $16), on a damage floor everyone (sound
; $40); never below 1
fx_stepend: ld hl, SRAM_PAGE + $102
            ld c, 0
.p:         ld a, [hl]
            cp $40
            jr nc, .pn
            and 2
            jr z, .pn
            inc c
.pn:        ld a, l
            add $40
            ld l, a
            jr nc, .p
            ld a, c
            and a
            jr z, .fl
            ld a, $16
            call sfx_play
            ld hl, SRAM_PAGE + $102
.pd:        ld a, [hl]
            cp $40
            jr nc, .pe
            and 2
            call nz, fx_hp1
.pe:        ld a, l
            add $40
            ld l, a
            jr nc, .pd
.fl:        ld a, [fl_dmg]
            and a
            ret z
            xor a
            ld [fl_dmg], a
            call ev_grey
            ld a, $40
            call sfx_play
            ld hl, SRAM_PAGE + $102
.fd:        call fx_hp1
            ld a, l
            add $40
            ld l, a
            jr nc, .fd
            ret
; member at HL ($x02): HP - 1, not below 1
fx_hp1:     push hl
            ld a, l
            add $0A
            ld l, a
            ld a, [hl+]
            ld b, [hl]
            dec hl
            ld c, a
            ld a, b
            and a
            jr nz, .d
            ld a, c
            cp 2
            jr c, .x
.d:         dec bc
            ld [hl], c
            inc hl
            ld [hl], b
.x:         pop hl
            ret

section bank B_FIELD, $6700
nj_h:       ds 25                           ; (3B/AC0C: the jump's height)
dn_x:       ds 84                           ; (3B/ADB1, AE05, AE59: the dance)
dn_y:       ds 84
dn_f:       ds 84

section wram, $CFA0
pl_grey:    ds 1
ev_pnew:    ds 1
ev_w:       ds 16
ev_sv:      ds 16
ev_ns:      ds 1
ev_74:      ds 1
ev_75:      ds 1
ev_t:       ds 1
fl_dmg:     ds 1
