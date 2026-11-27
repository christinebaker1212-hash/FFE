; FF3's summons in battle (2F/B050, 33/AFB0, 32/8CEF; the attacks of bank $32), our presentation.
; The summon is FF3's sprite grid (up to 8 x 10 tiles, more than the GB's 40 sprites): here it is
; drawn in the window layer (tiles at VRAM bank 1 $8900, BG palettes 2-4 copying FF3's sprite
; palettes 0-2), placed by WX / WY to the pixel; the window is cut at the battlefield's bottom by the
; line interrupt (text.s stat_isr's window cut at line 95). Its place: FF3's x - 64 (kept on the
; screen), rows from FF3's + 2 (kept above the windows). Cells of the window outside the summon's
; shape show the battlefield's cells as they were. The party is hidden (FF3 clears the sprites),
; so the attacks' sprites have all 40 entries.

section bank B_BANIM, $6000
; ---- kind 2: a summon (A from batui: [$7E94] = summon id x 16 + attack)
an_summon:  ld a, [$D8D6]
            ld [an_c], a
            ld a, [$DE94]
            swap a
            and $0F
            ld [an_sid], a
            ld b, a
            add a
            add b
            ld b, a
            ld a, [$DE94]
            and $0F
            ld [an_sat], a
            add b
            ld [an_six], a
            xor a
            ld [an_sfin], a
            ld [an_wy], a
            call an_stepf
            call an_cgfx
            ld a, $1F
            call bs_sfx
            ld a, 4                         ; the pre-animation (33/AFB0): the cast pose and the
            call an_lgfx                    ;   spinning frames 40 frames
            call an_savepal
            ld a, [an_sid]
            ld hl, sm_pal
            call an_hla
            ld a, [hl]
            call an_gpal3
            xor a
            ld [an_f], a
.p:         call an_cast
            ld a, [an_f]
            srl a
            srl a
            ld hl, sm_pre
            call an_hla
            ld a, [hl]
            call an_wspr0
            call an_frame
            ld a, [an_f]
            cp 40
            jr nz, .p
            call an_cast                    ; four sprites flying off 40 frames
            ld a, $5B
            call an_wspr0
            call an_frame
            xor a
            ld [an_f], a
.fl:        call an_sfly
            call an_frame
            ld a, [an_f]
            cp 40
            jr nz, .fl
            call an_pose0
            call an_restpal
            call an_oparty                  ; the party's colours cycling, fading (32/8CBA, 8CA7)
            ld b, 16
.c:         push bc
            call an_ocyc
            call an_oput
            call an_frame
            pop bc
            dec b
            jr nz, .c
            call an_ofade16
            ld hl, an_pf                    ; the party hidden
            ld b, 4
            ld a, $FE
.h:         ld [hl+], a
            dec b
            jr nz, .h
            ld a, $0F
            ld [an_bgm], a
            call xb_party
            call an_frame
            call an_sload                   ; the summon (32/8CEF)
            call an_son
            ld a, 80                        ; coming in from the right 8 a frame (32/8E56)
.e:         push af
            call an_wpos
            call an_frame
            pop af
            sub 8
            jr nc, .e
            ld a, [an_six]                  ; its attack (32/8115)
            add a
            ld hl, .tab
            call an_hla
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            call .go
            call an_ofade16                 ; fading out (32/8E21)
            call an_clr
            call an_soff
            ld a, [an_sfin]                 ; (Chocobo's escape: the party has gone)
            and a
            jr nz, .x
            ld hl, an_pf                    ; the party back, its colours cycling (2F/B0CE)
            ld b, 4
            ld a, $FF
.b:         ld [hl+], a
            dec b
            jr nz, .b
            xor a
            ld [an_bgm], a
            call an_oparty
            call an_oput
            call xb_party
            ld b, 16
.c2:        push bc
            call an_ocyc
            call an_oput
            call an_frame
            pop bc
            dec b
            jr nz, .c2
            call an_stepb
            ld a, [$DE94]                   ; (2F/B158: healing light, barrier, aura: a spell's
            ld c, $34                       ;   hit on the targets after)
            cp $30
            jr z, .sp
            ld c, $0C
            cp $50
            jr z, .sp
            ld c, $13
            cp $70
            ret nz
.sp:        ld a, c
            jp an_sspell
.x:         xor a
            ld [an_bgm], a
            ret
.go:        jp hl
.tab:       dw an_s00, an_s01, an_s02, an_none, an_s04, an_none
            dw an_s06, an_s07, an_s07, an_s09, an_none, an_none
            dw an_none, an_none, an_s14, an_s15, an_s16, an_none
            dw an_s18, an_none, an_none, an_s21, an_none, an_none

; the pre-animation's four sprites (AN_OAM 0-3) flying off diagonally (33/B02A, AFF2): out of the
; battlefield: tile 0; the tile $55.. by the frame / 8 up to $58
an_sfly:    ld hl, sm_fly
            ld b, 8
.m:         ld a, [hl+]                     ; OAM offset, step
            ld e, a
            ld a, [hl+]
            push hl
            ld d, 0
            ld hl, AN_OAM
            add hl, de
            add [hl]
            ld [hl], a
            pop hl
            dec b
            jr nz, .m
            ld hl, AN_OAM
            ld b, 4
.s:         ld a, [hl+]                     ; y within the battlefield, x on the screen
            sub 16
            cp 96
            jr nc, .off
            ld a, [hl]
            sub 8
            cp 160
            jr nc, .off
            inc hl
            ld a, [hl]
            and a
            jr z, .n
            cp $58
            jr z, .n
            ld a, [an_f]
            and $18
            rrca
            rrca
            rrca
            add $55
            ld [hl], a
            jr .n
.off:       inc hl
            ld [hl], 0
.n:         inc hl
            inc hl
            dec b
            jr nz, .s
            ret

; ---- FF3's NES colours for OBJ palettes 0-3 (an_osh), written as RGB in V-Blank (an_oput; BG 2-4
; = OBJ 0-2 while a summon shows)
; the party's: battle palettes $FC-$FF (2E/8C00)
an_oparty:  ld c, 0
.p:         ld a, c
            add $FC
            ld l, a
            ld h, 0
            ld d, h
            ld e, l
            add hl, hl
            add hl, de
            ld de, $8C00 - $4000
            add hl, de
            ld a, c
            add a
            add a
            ld de, an_osh
            add e
            ld e, a
            jr nc, .d
            inc d
.d:         ld a, $0F
            ld [de], a
            inc de
            push bc
            ld bc, 3
            ld a, B_BDAT2
            call far_copy
            pop bc
            inc c
            ld a, c
            cp 4
            jr nz, .p
            ret
; palette C (0-3) from FF3's general palette A (00/9100: three colours)
an_ogen:    ld e, a
            ld d, 0
            ld a, c
            add a
            add a
            ld hl, an_osh
            call an_hla
            ld [hl], $0F
            inc hl
            ld b, 3
            ld a, low(A_GPAL)
            ld [an_gp], a
            ld a, high(A_GPAL)
            ld [an_gp + 1], a
.c:         push hl
            push de
            push bc
            ld a, [an_gp]
            ld l, a
            ld a, [an_gp + 1]
            ld h, a
            add hl, de
            ld a, B_MAPAUX
            call far_byte
            pop bc
            pop de
            pop hl
            ld [hl+], a
            ld a, [an_gp + 1]
            inc a
            ld [an_gp + 1], a
            dec b
            jr nz, .c
            ret
; each colour's hue + 2, brightness + 1 (33/A46A)
an_ocyc:    ld hl, an_osh
            ld b, 16
.c:         ld a, b
            and 3
            jr z, .n                        ; (colour 0 kept)
            ld a, [hl]
            ld c, a
            and $F0
            ld d, a
            ld a, c
            add 2
            and $0F
            or d
            ld c, a
            and $CF
            ld d, a
            ld a, c
            add $10
            and $30
            or d
            ld [hl], a
.n:         inc hl
            dec b
            jr nz, .c
            ret
; one step darker (3F/FA87): black stays, the darkest to black
an_ofade:   ld hl, an_osh
            ld b, 16
.c:         ld a, [hl]
            cp $0F
            jr z, .n
            ld c, a
            and $30
            ld a, $0F
            jr z, .s
            ld a, c
            sub $10
.s:         ld [hl], a
.n:         inc hl
            dec b
            jr nz, .c
            ret
an_ofade16: ld b, 16
.f:         push bc
            call an_ofade
            call an_oput
            call an_frame
            pop bc
            dec b
            jr nz, .f
            ret
; an_osh -> an_orgb (RGB555), written by an_frame in the next V-Blank
an_oput:    ld hl, an_osh
            ld de, an_orgb
            ld b, 16
.c:         push bc
            ld a, [hl+]
            push hl
            and $3F
            add a
            ld l, a
            ld h, high(I_RGB)
            ld a, low(I_RGB)
            add l
            ld l, a
            jr nc, .s
            inc h
.s:         push hl
            ld a, B_MAPINFO
            call far_byte
            ld [de], a
            inc de
            pop hl
            inc hl
            ld a, B_MAPINFO
            call far_byte
            ld [de], a
            inc de
            pop hl
            pop bc
            dec b
            jr nz, .c
            ld a, 1
            ld [an_opf], a
            ret
; (in V-Blank) the palettes
an_oset:    xor a
            ld [an_opf], a
            ld a, $80
            ldh [rOCPS], a
            ld hl, an_orgb
            ld b, 32
.o:         ld a, [hl+]
            ldh [rOCPD], a
            dec b
            jr nz, .o
            ld a, [an_sbg]
            and a
            ret z
            ld a, $80 | 16
            ldh [rBCPS], a
            ld hl, an_orgb
            ld b, 24
.b:         ld a, [hl+]
            ldh [rBCPD], a
            dec b
            jr nz, .b
            ret

; ---- the summon: its properties (2A/9440), palettes, tiles, window map
an_sload:   ld a, [an_sid]
            add a
            add a
            add a
            ld hl, sm_data
            call an_hla
            ld de, an_sprp
            ld bc, 8
            call memcpy
            ld a, [an_sat]                  ; palettes: the attack's three general palettes
            ld hl, an_sprp + 1
            call an_hla
            ld a, [hl]
            ld [an_k4], a
            ld c, 0
.pl:        push bc
            ld a, [an_k4]
            add c
            call an_ogen
            pop bc
            inc c
            ld a, c
            cp 3
            jr nz, .pl
            ld a, 1
            ld [an_sbg], a
            call an_oput
            ld a, [an_sprp]                   ; tiles: 55 from 0D/9800 + 16 x index (BG $90..)
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, $4000
            add hl, de
            ld de, $8900
            ld bc, 55 * 16
            ld a, B_SUMN
            call an_vcopy
            ld a, [an_sprp + 4]               ; size, place
            ld b, a
            swap a
            and $0F
            ld [an_sw], a
            ld a, b
            and $0F
            ld [an_sh], a
            ld a, [an_sprp + 5]               ; x: 112 + 8 hi, at most 160 - 8 w
            swap a
            and $0F
            add 14
            ld b, a
            ld a, [an_sw]
            ld c, a
            ld a, 20
            sub c
            cp b
            jr c, .xc
            ld a, b
.xc:        ld [an_sc0], a
            add a
            add a
            add a
            ld [an_sx], a
            ld a, [an_sprp + 5]               ; row: lo + 2, at most 12 - h
            and $0F
            add 2
            ld b, a
            ld a, [an_sh]
            ld c, a
            ld a, 12
            sub c
            cp b
            jr c, .yc
            ld a, b
.yc:        ld [an_sr0], a
            ld a, [an_sprp + 6]               ; the map in sm_data
            sub low($9440)
            ld l, a
            ld a, [an_sprp + 7]
            sbc high($9440)
            ld h, a
            ld de, sm_data
            add hl, de
            ld a, l
            ld [an_smp], a
            ld a, h
            ld [an_smp + 1], a
; the window map ($9C00), rows 0-17 (12-17 the windows' cells), columns 0 .. 19 - an_sc0
an_smap:    call wait_vbl
            ld a, 1
            ld [guard_on], a
            ld a, $20
            ldh [rSTAT], a
            ld c, 0                         ; C = row
.r:         ld b, 0                         ; B = column in the window
.k:         ld a, [an_sc0]
            add b
            cp 20
            jr nc, .nr
            call an_scell                   ; -> D tile, E attributes
            ld a, c                         ; $9C00 + 32 row + column
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld a, b
            call an_hla
            ld a, h
            add $9C
            ld h, a
            ld a, d
            ld [hl], a
            ld a, 1
            ldh [rVBK], a
            ld [hl], e
            xor a
            ldh [rVBK], a
            inc b
            jr .k
.nr:        inc c
            ld a, c
            cp 18
            jr nz, .r
            xor a
            ldh [rSTAT], a
            ld [guard_on], a
            ret
; the cell at window row C, column B -> D tile, E attributes (keeps BC)
an_scell:   ld a, [an_sr0]
            ld e, a
            ld a, c
            sub e
            jr c, .bf
            ld e, a                         ; row within the summon
            ld a, [an_sh]
            dec a
            cp e
            jr c, .bf
            ld a, [an_sw]
            dec a
            cp b
            jr c, .bf
            ld a, [an_sw]                   ; map[row w + column]
            ld d, a
            xor a
.mu:        dec e
            bit 7, e
            jr nz, .md
            add d
            jr .mu
.md:        add b
            ld e, a
            ld a, [an_smp]
            add e
            ld l, a
            ld a, [an_smp + 1]
            adc 0
            ld h, a
            ld a, [hl]
            cp $FF
            jr z, .bf
            ld e, a
            and $3F
            add $90
            ld d, a
            ld a, e
            rlca
            rlca
            and 3
            add 2
            or $08
            ld e, a
            ret
.bf:        push bc                         ; the battlefield's own cell (SH_T / SH_A)
            ld a, [an_sc0]
            add b
            ld e, a
            ld a, c
            add a
            add a
            ld d, a
            add a
            add a
            add d                           ; 20 row
            add e
            ld l, a
            ld h, 0
            ld de, SH_T
            add hl, de
            ld d, [hl]
            push de
            ld de, SH_A - SH_T
            add hl, de
            pop de
            ld e, [hl]
            pop bc
            ret

; the window on (cut at line 95 by stat_isr), hidden until placed
an_son:     ld a, 167
            ld [an_wxv], a
            xor a
            ld [an_wyv], a
            ld a, 95
            ldh [rLYC], a
            ld a, $40
            ldh [rSTAT], a
            ld a, 1
            ld [an_won], a
            ret
an_soff:    xor a
            ld [an_won], a
            ld [an_sbg], a
            call wait_vbl
            ldh a, [rLCDC]
            and $DF
            ldh [rLCDC], a
            xor a
            ldh [rSTAT], a
            ld a, 167
            ldh [rWX], a
            ret
; the summon at its place + A pixels across (signed), + an_wy down
an_wpos:    ld b, a
            ld a, [an_sx]
            bit 7, b
            jr nz, .m
            add b
            jr c, .hid
            cp 160
            jr nc, .hid
            jr .s
.m:         add b
            jr nc, .z
.s:         add 7
            ld [an_wxv], a
            ld a, [an_wy]
            ld [an_wyv], a
            ret
.z:         xor a
            jr .s
.hid:       ld a, 167
            ld [an_wxv], a
            ret
; (in V-Blank) the window shown, placed
an_wset:    ldh a, [rLCDC]
            or $20
            ldh [rLCDC], a
            ld a, [an_wxv]
            ldh [rWX], a
            ld a, [an_wyv]
            ldh [rWY], a
            ret
; summon cells changed in V-Blank: an_wq (count), then (address lo, hi, tile) x 9 at most
an_wqset:   ld hl, an_wq
            ld a, [hl+]
            and a
            ret z
            ld b, a
.c:         ld a, [hl+]
            ld e, a
            ld a, [hl+]
            ld d, a
            ld a, [hl+]
            ld [de], a
            dec b
            jr nz, .c
            xor a
            ld [an_wq], a
            ret

; ---- 0: Chocobo's escape (32/8AB5): 16 frames, then (when the escape works, $7E93 = 0) its
; sound and the summon going off to the right (32/8E36); the party does not come back
an_s00:     call an_w16
            ld a, [$DE93]
            and a
            ret nz
            call an_ssnd
            ld a, 1
            ld [an_sfin], a
; the summon going off to the right 8 a frame (32/8E36)
an_sexit:   xor a
.e:         push af
            call an_wpos
            call an_frame
            pop af
            add 8
            cp 88
            jr nz, .e
            ret
; ---- 1: stumbling (32/8AC6): 32 frames 0-3 pixels across (FF3's random table by frame)
an_s01:     call an_ssnd
            xor a
            ld [an_k3], a
.f:         ld a, [an_k3]
            ld hl, RNG_TAB
            call an_hla
            ld a, [hl]
            and 3
            call an_wpos
            call an_frame
            ld hl, an_k3
            inc [hl]
            ld a, [hl]
            cp 32
            jr nz, .f
            xor a
            jp an_wpos
; ---- 2: Chocobo Kick (32/8AEB): its tiles by turns every 4 frames (32/8B37), the blunt hits on
; the target 64 frames (graphics set 9, palette $BD; FF3's 16 hits, right hand)
an_s02:     ld a, 9
            call an_lgfx
            ld a, $4D                       ; (set 9 covers the summon's tiles $4D-$59)
            ld b, 13
            call an_sbgcp
            ld a, $BD
            call an_gpal3
            xor a
            ld [an_h], a
            ld a, $10
            ld [BZ + $BB], a
            ld [BZ + $BC], a
            ld a, [$DE99]
            call an_slot
            ld [an_t], a
            call an_ssnd
            xor a
            ld [an_f], a
            ld [an_b9], a
.f:         ld a, [an_f]
            and 3
            jr nz, .h
            ld a, [an_f]                    ; the chocobo's 9 cells
            and 4
            ld hl, ck_t + 9
            jr z, .t
            ld hl, ck_t
.t:         call an_sq9
.h:         call an_clr
            ld a, 1
            call an_hit
            call an_frame
            ld a, [an_f]
            cp $40
            jr nz, .f
            ret
; the summon's cells 0-8 (rows of 3) to the tiles at HL (FF3's numbers) in the next V-Blank
an_sq9:     ld de, an_wq + 1
            ld c, 0
.c:         push hl
            ld a, c                         ; window row = an_sr0 + c / 3, column c mod 3
            ld b, 0
.d3:        cp 3
            jr c, .r
            sub 3
            inc b
            jr .d3
.r:         push af
            ld a, [an_sr0]
            add b
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            pop af
            call an_hla
            ld a, h
            add $9C
            ld h, a
            ld a, l
            ld [de], a
            inc de
            ld a, h
            ld [de], a
            inc de
            pop hl
            ld a, [hl+]
            sub $39 - $90
            ld [de], a
            inc de
            inc c
            ld a, c
            cp 9
            jr nz, .c
            ld a, 9
            ld [an_wq], a
            ret
ck_t:       db $39, $3A, $3B, $3C, $3D, $3E, $3F, $40, $41
            db $51, $52, $53, $54, $55, $56, $57, $58, $59
; OBJ tiles A.. (B of them, VRAM bank 1) into the summon's BG copies ($90 + A - $39)
an_sbgcp:   ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld d, h
            ld e, l
            ld hl, $8000
            add hl, de
            ld a, l
            ld [an_gp], a
            ld a, h
            ld [an_gp + 1], a
            ld hl, $8900 - 16 * $39
            add hl, de
            ld d, h
            ld e, l
            ld a, b
            ld [an_k4], a
            call wait_vbl
            ld a, 1
            ld [guard_on], a
            ld a, $20
            ldh [rSTAT], a
            ld a, 1
            ldh [rVBK], a
            ld a, [an_gp]
            ld l, a
            ld a, [an_gp + 1]
            ld h, a
.t:         ld b, 16
.b:         ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .b
            ld a, [an_k4]
            dec a
            ld [an_k4], a
            jr nz, .t
            xor a
            ldh [rVBK], a
            ld a, [an_won]
            and a
            jr z, .s
            ld a, $40
.s:         ldh [rSTAT], a
            xor a
            ld [guard_on], a
            ret
; the attack's sound (2F/AFC0)
an_ssnd:    ld a, [an_six]
            ld hl, sm_snd
            call an_hla
            ld a, [hl]
            jp bs_sfx
an_w16:     ld b, 16
.w:         push bc
            call an_frame
            pop bc
            dec b
            jr nz, .w
            ret

; ---- the targets' ($7E99) cells in BG palette C ($FF: their own again), straight to VRAM
an_tcells:  ld a, c
            ld [an_tpc], a
            ld a, [$DE99]
            ld [an_tm], a
            call wait_vbl
            ld a, 1
            ld [guard_on], a
            ld a, $20
            ldh [rSTAT], a
            xor a
            ld [an_t], a
.t:         ld a, [an_tm]
            add a
            ld [an_tm], a
            jr nc, .n
            ld a, [an_t]
            ld [fl_s], a
            call xb_srect
            ld a, [an_src]
            and a
            call z, .rect
.n:         ld hl, an_t
            inc [hl]
            ld a, [hl]
            cp 8
            jr nz, .t
            ld a, [an_won]
            and a
            jr z, .s
            ld a, $40
.s:         ldh [rSTAT], a
            xor a
            ld [guard_on], a
            ret
.rect:      ld a, [fl_y]
            ld c, a
            ld a, [fl_h]
            ld b, a
.r:         push bc
            ld l, c                         ; SH_A + 20 y + x, $9800 + 32 y + x
            ld h, 0
            add hl, hl
            add hl, hl
            ld d, h
            ld e, l
            add hl, hl
            add hl, hl
            add hl, de
            ld a, [fl_x]
            call an_hla
            ld de, SH_A
            add hl, de
            push hl
            ld l, c
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld a, [fl_x]
            call an_hla
            ld de, $9800
            add hl, de
            ld d, h
            ld e, l
            pop hl
            ld a, [fl_w]
            ld b, a
            ld a, 1
            ldh [rVBK], a
.c:         ld a, [an_tpc]
            cp $FF
            ld a, [hl+]
            jr z, .s2
            and $F8
            ld c, a
            ld a, [an_tpc]
            or c
.s2:        ld [de], a
            inc de
            dec b
            jr nz, .c
            xor a
            ldh [rVBK], a
            pop bc
            inc c
            dec b
            jr nz, .r
            ret
; BG palette C = FF3's general palette A (black + its 3 colours), written in the next V-Blank
an_bgpal:   push bc
            ld c, 0
            call an_ogen                    ; (into an_osh palette 0, kept aside)
            ld hl, an_osh
            ld de, an_bpq + 1
            ld b, 4
.c:         push bc
            ld a, [hl+]
            push hl
            call an_nrgb
            ld a, c
            ld [de], a
            inc de
            ld a, b
            ld [de], a
            inc de
            pop hl
            pop bc
            dec b
            jr nz, .c
            pop bc
            ld a, c
            add a
            add a
            add a
            or $80
            ld [an_bpq], a
            ld a, 1
            ld [an_bpf], a
            jp an_oparty0
; (in V-Blank) the BG palette waiting
an_bpset:   xor a
            ld [an_bpf], a
            ld a, [an_bpq]
            ldh [rBCPS], a
            ld hl, an_bpq + 1
            ld b, 8
.c:         ld a, [hl+]
            ldh [rBCPD], a
            dec b
            jr nz, .c
            ret
; (an_osh palette 0 back to the party's first)
an_oparty0: push bc
            ld c, 0
            ld a, $FC
            call an_opal1
            pop bc
            ret
; an_osh palette C = battle palette A (2E/8C00)
an_opal1:   ld l, a
            ld h, 0
            ld d, h
            ld e, l
            add hl, hl
            add hl, de
            ld de, $8C00 - $4000
            add hl, de
            ld a, c
            add a
            add a
            ld de, an_osh
            add e
            ld e, a
            jr nc, .d
            inc d
.d:         ld a, $0F
            ld [de], a
            inc de
            ld bc, 3
            ld a, B_BDAT2
            jp far_copy
; NES colour A -> BC (C low byte, B high)
an_nrgb:    and $3F
            add a
            ld l, a
            ld h, high(I_RGB)
            ld a, low(I_RGB)
            add l
            ld l, a
            jr nc, .s
            inc h
.s:         push hl
            ld a, B_MAPINFO
            call far_byte
            ld c, a
            pop hl
            inc hl
            ld a, B_MAPINFO
            call far_byte
            ld b, a
            ret
; the backdrop flashing colour A for B frames (32/8781)
an_flashn:  ld [an_k4], a
            ld a, b
            ld [an_k3], a
            jp an_flash.f

; ---- 4: Icy Stare (32/8A05), 16: Slash (89FE): the targets in a palette of their own, every
; other 4 frames general palette $E8 / $FF (FF3's battle palette 2 by turns), 48 frames
an_s04:     ld a, $E8
            jr an_s16.g
an_s16:     ld a, $FF
.g:         ld c, 6
            call an_bgpal
            call an_ssnd
            xor a
            ld [an_k3], a
.f:         ld a, [an_k3]
            and 3
            jr nz, .w
            ld a, [an_k3]
            and 4
            ld c, 6
            jr z, .p
            ld c, $FF
.p:         call an_tcells
.w:         call an_frame
            ld hl, an_k3
            inc [hl]
            ld a, [hl]
            cp $30
            jr nz, .f
            ld c, $FF
            jp an_tcells
; ---- 6: Mind Blast (32/89D2): the monsters' palettes cycling white 48 frames (32/8B99, 87AD)
an_s06:     call an_ssnd
            ld a, $30
; the monsters' palettes (BG 0 / 1) cycling in hue A: colours 1-3 the hue at brightness f, f + 1,
; f + 2 (mod 4) for 48 frames, then their own again
an_mcyc:    and $0F
            ld [an_k5], a
            call an_bgsave
            xor a
            ld [an_k3], a
.f:         ld a, [an_k3]                   ; brightness steps
            and 3
            swap a
            ld b, a
            ld c, 0                         ; palettes 0 and 1 colours 1-3
            ld hl, an_bpq + 1
            ld a, $0F
            call .one
            ld a, b
            call .one
            ld a, b
            add $10
            call .one
            ld a, b
            add $20
            call .one
            ld a, $80
            ld [an_bpq], a
            ld a, 1
            ld [an_bpf], a
            call an_frame
            ld a, $88                       ; (palette 1 the same: written straight after)
            ldh [rBCPS], a
            ld hl, an_bpq + 1
            ld b, 8
.c1:        ld a, [hl+]
            ldh [rBCPD], a
            dec b
            jr nz, .c1
            ld hl, an_k3
            inc [hl]
            ld a, [hl]
            cp $30
            jr nz, .f
            jp an_bgrest
.one:       push bc
            push hl
            cp $0F
            jr z, .k
            and $30
            ld c, a
            ld a, [an_k5]
            or c
.k:         call an_nrgb
            pop hl
            ld a, c
            ld [hl+], a
            ld a, b
            ld [hl+], a
            pop bc
            ret
; BG palettes 0-1 kept / put back
an_bgsave:  call wait_vbl
            ld hl, an_bgs
            ld c, 0
.l:         ld a, c
            ldh [rBCPS], a
            ldh a, [rBCPD]
            ld [hl+], a
            inc c
            ld a, c
            cp 16
            jr nz, .l
            ret
an_bgrest:  call wait_vbl
            ld a, $80
            ldh [rBCPS], a
            ld hl, an_bgs
            ld b, 16
.l:         ld a, [hl+]
            ldh [rBCPD], a
            dec b
            jr nz, .l
            ret
; ---- 7 / 8: Ramuh (32/8977): the backdrop flashing 16 frames, then (after the summon) spell $2A's
; hit on the targets
an_s07:     call an_ssnd
            ld a, $29
            ld b, 16
            call an_flashn
            ld b, 8                         ; (FF3 cycles its battle background's palette 8 frames)
.w:         push bc
            call an_frame
            pop bc
            dec b
            jr nz, .w
            ld a, $2A
            jr an_sspell
; ---- 9: Ifrit's healing light, 15: Odin's barrier, 21: Bahamut's aura: the backdrop flashing (32/877F)
an_s09:     call an_ssnd
            ld a, $31
            jp an_flash
an_s15:     call an_ssnd
            ld a, $2B
            jp an_flash
an_s21:     call an_ssnd
            ld a, $31
            jp an_flash
; ---- 14: Earthen Fury (32/8C8D): the screen shaking
an_s14:     jp an_shake
; ---- 18: Demon Eye (32/89E8): the targets in the windows' palette, the backdrop flashing, 16 frames
an_s18:     ld a, [$DE9B]
            and a
            ret z
            ld c, 7
            call an_tcells
            call an_ssnd
            ld a, $31
            call an_flash
            call an_w16
            ld c, $FF
            jp an_tcells
; a spell's hit (2F/B158 / 32/89B7: type 7) on the targets: A = spell
an_sspell:  ld [$DE88], a
            ld a, 7
            ld [$DE9D], a
            ld a, [$DE99]
            ld [$DE9B], a
            xor a
            ld [BZ + $CC], a
            call an_mprop
            call an_savepal
            ld a, [an_m2]
            call an_gpal3
            call an_mhit
            jp an_restpal

section wram, $DA00
an_tpc:     ds 1
an_bpf:     ds 1
an_bpq:     ds 9
an_bgs:     ds 16

section bank B_BANIM, $7D00
sm_snd:     ds 24                           ; (2F/AFC0)
sm_pal:     ds 8                            ; (32/8043)
sm_pre:     ds 10                           ; (33/B1EE)
sm_fly:     ds 16                           ; (33/AFF2)

section wram, $D900                         ; (work RAM bank 2: FF3's $7900, its graphics buffer)
an_sid:     ds 1
an_sat:     ds 1
an_six:     ds 1
an_sfin:    ds 1
an_sprp:      ds 8
an_sw:      ds 1
an_sh:      ds 1
an_sc0:     ds 1
an_sx:      ds 1
an_sr0:     ds 1
an_smp:     ds 2
an_wy:      ds 1
an_wxv:     ds 1
an_wyv:     ds 1
an_won:     ds 1
an_sbg:     ds 1
an_opf:     ds 1
an_gp:      ds 2
an_osh:     ds 16
an_orgb:    ds 32
an_wq:      ds 1 + 27

