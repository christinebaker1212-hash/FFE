; FF3's summons in battle (2F/B050, 33/AFB0, 32/8CEF; the attacks of bank $32), our presentation.
; The summon is FF3's sprite grid (up to 8 x 10 tiles, more than the GB's 40 sprites): here it is
; drawn in the window layer (tiles at VRAM bank 1 $8900, BG palettes 2-4 copying FF3's sprite
; palettes 0-2), placed by WX / WY to the pixel; the window is cut at the battlefield's bottom by the
; line interrupt (text.s stat_isr's window cut at line 95). Its place: FF3's x - 64 (kept on the
; screen), rows from FF3's + 2 (kept above the windows). Cells of the window outside the summon's
; shape show the battlefield's cells as they were. The party is hidden (FF3 clears the sprites),
; so the attacks' sprites have all 40 entries.

section bank B_BANIM, $5B00
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
            ld hl, bs_gt                    ; (the party's tiles reloaded: set 17 may have
            ld b, 4                         ;   covered them)
            ld a, $FF
.gt:        ld [hl+], a
            dec b
            jr nz, .gt
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
.tab:       dw an_s00, an_s01, an_s02, an_s03, an_s04, an_s05
            dw an_s06, an_s07, an_s07, an_s09, an_s10, an_s11
            dw an_s12, an_s13, an_s14, an_s15, an_s16, an_s17
            dw an_s18, an_s19, an_s20, an_s21, an_s22, an_s23

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
            ld a, B_SUMN
            call far_copy
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
            xor a                           ; Ifrit, Titan: in sprites
            ld [an_smode], a
            ld [an_sbase], a
            ld [an_sbv], a
            ld [an_sbd], a
            ld a, [an_sid]
            cp 3
            jr z, .sp
            cp 4
            jr z, .sp
            ld b, a                         ; (a back attack: the window cannot be mirrored;
            ld a, [bs_bk]                   ;   Chocobo, Shiva, Ramuh in sprites, Odin,
            and a                           ;   Leviathan, Bahamut in the BG cells)
            jr z, an_smap
            ld a, b
            cp 5
            jr c, .sp
            ld a, 2
            ld [an_smode], a
            ret
.sp:        ld a, 1
            ld [an_smode], a
            ld a, [an_sw]                   ; entries: its cells that are not empty
            ld e, a
            ld a, [an_sh]
            call mul8
            ld b, l
            ld a, [an_smp]
            ld l, a
            ld a, [an_smp + 1]
            ld h, a
            ld c, 0
.cn:        call an_sb
            inc hl
            cp $FF
            jr z, .cz
            inc c
.cz:        dec b
            jr nz, .cn
            ld a, c
            add a
            add a
            ld [an_sbase], a
            jp an_sotiles
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
            call an_sb
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
an_son:     ld a, [an_smode]                ; (sprites: no window)
            and a
            ret nz
            ld a, 167
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
an_soff:    ld a, [an_smode]                ; (sprites: their entries off)
            and a
            call nz, an_sgone
            xor a
            ld [an_smode], a
            ld [an_sbase], a
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
            ld a, [an_smode]
            and a
            ld a, b
            jr z, .win
            ld a, [an_smode]
            cp 2
            ld a, b
            jp nz, an_ssdraw
            sra a                           ; (BG cells: drawn by an_frame, columns - A / 8)
            sra a
            sra a
            cpl
            inc a
            ld [an_sbn], a
            ld a, 1
            ld [an_sbd], a
            ret
.win:
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
an_sq9:     ld a, [an_smode]                ; (sprites: their tiles, entries 0-8)
            and a
            jr z, .w
            ld de, oam_buf + 2
            ld b, 9
.s:         ld a, [hl+]
            ld [de], a
            ld a, e
            add 4
            ld e, a
            dec b
            jr nz, .s
            ret
.w:         ld de, an_wq + 1
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
.rect:      ld a, [fl_y]                    ; (cells through an_mcell)
            ld d, a
            ld a, [fl_h]
            ld [an_rh], a
.r:         ld a, [fl_x]
            ld e, a
            ld a, [fl_w]
            ld [an_rw], a
.c:         push de
            ld a, d                         ; SH_A + 20 y + x
            add a
            add a
            ld l, a
            add a
            add a
            add l
            add e
            ld l, a
            ld h, 0
            ld bc, SH_A
            add hl, bc
            ld c, [hl]
            ld a, [an_tpc]
            cp $FF
            jr z, .o
            ld a, c
            and $F8
            ld c, a
            ld a, [an_tpc]
            or c
            ld c, a
.o:         push bc
            call an_mcell
            ld a, b
            pop bc
            jr z, .sk
            xor c
            ld c, a
            ld a, 1
            ldh [rVBK], a
            ld [hl], c
            xor a
            ldh [rVBK], a
.sk:        pop de
            inc e
            ld hl, an_rw
            dec [hl]
            jr nz, .c
            inc d
            ld hl, an_rh
            dec [hl]
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
            ld a, [an_bp2]                  ; (and palette 1 the same)
            and a
            ret z
            xor a
            ld [an_bp2], a
            ld a, $88
            ldh [rBCPS], a
            ld hl, an_bpq + 1
            ld b, 8
.d:         ld a, [hl+]
            ldh [rBCPD], a
            dec b
            jr nz, .d
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




; ---- a summon drawn in sprites (Ifrit, Titan: they move about; 30 tiles at most): entries 0..n-1
; from its map at (an_sx + A, 8 an_sr0 + an_wy), off the screen hidden (FF3 wraps them)
an_ssdraw:  ld [an_sox], a
            ld hl, oam_buf
            ld a, [an_sr0]
            add a
            add a
            add a
            ld c, a
            ld a, [an_wy]
            add c
            add 16
            ld [an_soy], a                  ; OAM y of the top row (signed beyond)
            ld a, [an_smp]
            ld e, a
            ld a, [an_smp + 1]
            ld d, a
            ld c, 0                         ; C = row
.r:         ld b, 0                         ; B = column
.k:         push hl
            ld h, d
            ld l, e
            call an_sb
            pop hl
            inc de
            cp $FF
            jr z, .n
            push af
            ld a, b                         ; x: an_sx + ox + 8 col (signed ox)
            add a
            add a
            add a
            push hl
            ld hl, an_sx
            add [hl]
            ld l, a
            ld h, 0
            jr nc, .x1
            inc h
.x1:        ld a, [an_sox]
            bit 7, a
            jr z, .x2
            dec h
.x2:        add l
            ld l, a
            ld a, h
            adc 0
            ld h, a
            and a                           ; 0-159 shown
            jr nz, .hx
            ld a, l
            cp 160
            jr nc, .hx
            add 8
            ld [an_k2], a
            pop hl
            ld a, c                         ; y
            add a
            add a
            add a
            push hl
            ld hl, an_soy
            add [hl]
            pop hl
            cp 16 + 96 + 8
            jr nc, .hy
            ld [hl+], a
            ld a, [an_k2]
            ld [hl+], a
            pop af
            push af
            and $3F
            add $39
            ld [hl+], a
            pop af
            rlca
            rlca
            and 3
            or $08
            ld [hl+], a
            jr .n
.hx:        pop hl
.hy:        pop af
            xor a
            ld [hl+], a
            inc hl
            inc hl
            inc hl
.n:         inc b
            ld a, [an_sw]
            cp b
            jr nz, .k
            inc c
            ld a, [an_sh]
            cp c
            jr nz, .r
            ret
; the summon's tiles to OBJ $39.. too (sprite mode)
an_sotiles: ld a, [an_sprp]
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, $4000
            add hl, de
            ld de, $8000 + 16 * $39
            ld bc, 55 * 16
            ld a, B_SUMN
            jp an_vcopy
; the summon gone (sprite mode: its entries off)
an_sgone:   ld a, [an_smode]
            and a
            jr z, .w
            cp 2
            jr z, an_sbgoff
            ld hl, oam_buf
            ld a, [an_sbase]
            ld b, a
            xor a
.c:         ld [hl+], a
            dec b
            jr nz, .c
            ret
.w:         ld a, 167
            ld [an_wxv], a
            ret
; set $11 (33/BF18: 22 tiles from NES bank $15 at the address DE to OBJ $01-$16; the party's tiles,
; reloaded after the summon)
an_l11:     ld hl, $4000 - $8000
            add hl, de
            ld de, $8000 + 16
            ld bc, 22 * 16
            ld a, B_MAGIC
            jp an_vcopy
; a sprite list of 32/8F8B.. (HL = its NES address): y, tile, flags, x until $FF, at (D, E) with
; tiles + C; NES palette bits kept
an_slist:   push de
            ld de, sm_lst - $8F8B
            add hl, de
            pop de
.l:         call an_sb
            cp $FF
            ret z
            push hl
            push de
            push bc
            call an_shl
            add e
            cp 96 + 8
            jr c, .y
            cp $F8
            jr c, .s
.y:         add 17
            ld [an_sl1], a
            call an_shl
            add c
            ld [an_sl2], a
            call an_shl
            ld [an_sl3], a
            call an_sb
            add d
            cp 160
            jr nc, .s
            add 8
            ld [an_sl4], a
            call an_slot_oam
            jr c, .s
            ld a, [an_sl1]
            ld [hl+], a
            ld a, [an_sl4]
            ld [hl+], a
            ld a, [an_sl2]
            ld [hl+], a
            ld a, [an_sl3]
            ld b, a
            and $C0
            rra
            ld c, a
            ld a, b
            and 3
            or c
            or $08
            ld [hl], a
.s:         pop bc
            pop de
            pop hl
            inc hl
            inc hl
            inc hl
            inc hl
            jr .l
; the list whose pointer is at NES address HL (32/8F8B..)
an_slistp:  push de
            ld de, sm_lst - $8F8B
            add hl, de
            pop de
            call an_shl
            push af
            call an_sb
            ld h, a
            pop af
            ld l, a
            jr an_slist
; A = byte HL of the summons' data (bank B_SUMN); an_shl: and HL + 1 (keep BC, DE)
an_sb:      ld a, B_SUMN
            jp far_byte
an_shl:     call an_sb
            inc hl
            ret
; NES coordinate A scaled 5 / 8 (FF3's 256-pixel field on ours)
an_s58:     push hl
            push de
            ld e, a
            ld a, 5
            call mul8
            srl h
            rr l
            srl h
            rr l
            srl h
            rr l
            ld a, l
            pop de
            pop hl
            ret
; FF3's random (X..A): B = X
an_rnd:     push hl
            ld c, a
            xor a
            ld [BZ + $21], a
            ld a, c
            call b_rndx
            pop hl
            ret

; ---- 3: Mesmerize (32/8061): the battlefield's lines waving (SCX by line from a 16-entry table:
; growing 0..15 over 16 frames, still, then back to 0), 128 frames
an_s03:     ld hl, wv_tab
            ld b, 16
            xor a
.z:         ld [hl+], a
            dec b
            jr nz, .z
            call an_ssnd
            ld a, 3
            ld [c_split], a
            ld a, $08
            ldh [rSTAT], a
            xor a
            ld [an_k3], a
.f:         ld a, [an_k3]
            ld [wv_ph], a
            call an_frame
            ld a, [an_k3]                   ; (32/8A44)
            cp 16
            jr c, .g
            cp $70
            jr c, .n
            ld hl, wv_tab
            ld b, 16
.d:         ld a, [hl]
            and a
            jr z, .d2
            dec [hl]
.d2:        inc hl
            dec b
            jr nz, .d
            jr .n
.g:         ld hl, wv_tab + 1
            ld de, wv_tab
            ld b, 15
.s:         ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .s
            ld a, [an_k3]
            ld [de], a
.n:         ld hl, an_k3
            inc [hl]
            ld a, [hl]
            cp $80
            jr nz, .f
            call wait_vbl
            xor a
            ld [c_split], a
            ldh [rSCX], a
            ld a, $40
            ldh [rSTAT], a
            ret

; ---- 5: Diamond Dust (32/813B): 40 snowflakes falling across (FF3's x - 4, y + 4 a frame, a sine
; sway), 128 frames; FF3's coordinates scaled 5 / 8 (set 14, palette $FF)
an_s05:     ld a, 14
            call an_lgfx
            ld a, $FF
            call an_gpal3
            ld a, $20                       ; the sway: $20 sin(4 count)
            ld [an_k], a
            ld hl, dd_cnt                   ; counters from the random table, all hidden
            ld de, RNG_TAB
            ld b, 40
.i:         ld a, [de]
            inc de
            ld [hl], a                      ; (dd_cnt)
            push hl
            push de
            ld de, 40
            add hl, de
            and $1F
            inc a
            ld [hl], a                      ; (dd_dly)
            add hl, de
            ld [hl], 0                      ; (dd_on)
            pop de
            pop hl
            inc hl
            dec b
            jr nz, .i
            call an_ssnd
            ld a, $80
            ld [an_k3], a
.f:         call an_frame
            call an_clr
            xor a
            ld [an_t], a
.k:         ld a, [an_t]
            ld c, a
            ld b, 0
            ld hl, dd_cnt
            add hl, bc
            inc [hl]
            ld hl, dd_dly
            add hl, bc
            dec [hl]
            jr nz, .sh
            ld [hl], $26
            ld hl, dd_on
            add hl, bc
            ld [hl], 1
            ld hl, dd_y
            add hl, bc
            ld [hl], 0
            ld hl, an_ri
            inc [hl]
            ld a, [hl]
            ld hl, RNG_TAB
            call an_hla
            ld a, [hl]
            and $F8
            ld hl, dd_x
            add hl, bc
            ld [hl], a
.sh:        ld hl, dd_on
            add hl, bc
            ld a, [hl]
            and a
            jr z, .nx
            ld hl, dd_x
            add hl, bc
            ld a, [hl]
            ld d, a
            sub 4
            ld [hl], a
            ld hl, dd_cnt
            add hl, bc
            ld a, [hl]
            and $3F
            add a
            add a
            push bc
            push de
            call an_smul
            pop de
            pop bc
            add d
            call an_s58
            add 8
            ld [an_kxi], a
            ld hl, dd_y
            add hl, bc
            ld a, [hl]
            ld d, a
            add 4
            ld [hl], a
            cp $98
            jr c, .y
            ld hl, dd_on
            add hl, bc
            ld [hl], 0
.y:         ld a, d
            call an_s58
            add 16
            ld [an_k2], a
            call an_slot_oam
            jr c, .nx
            ld a, [an_k2]
            ld [hl+], a
            ld a, [an_kxi]
            ld [hl+], a
            ld a, [an_t]
            and 1
            add $4B
            ld [hl+], a
            ld [hl], $0B
.nx:        ld hl, an_t
            inc [hl]
            ld a, [hl]
            cp 40
            jp nz, .k
            ld hl, an_k3
            dec [hl]
            jp nz, .f
            call an_clr
            jp an_frame

; ---- 10: Hellfire (32/88B7): Ifrit rising up and away (x - 1, y - 8, 15 frames), 16 frames; flames
; coming down onto the target (32/8F97) from above, then burning on it (32/8F8B: two frames by
; turns) 32 frames (set 17 from 2B/B040, palette $BD)
an_s10:     ld de, $B040
            call an_l11
            ld b, 15
.u:         push bc
            ld a, [an_wy]
            sub 8
            ld [an_wy], a
            ld a, [an_sox]
            dec a
            call an_wpos
            call an_frame
            pop bc
            dec b
            jr nz, .u
            call an_w16
            ld a, $BD
            call an_gpal3
            call an_sgone
            ld a, [$DE99]
            call an_slot
            ld [an_t], a
            call an_tcen
            ld a, e
            ld [an_ky], a
            srl a
            srl a
            add d
            ld [an_kxi], a                   ; ($80)
            xor a
            ld [an_k3], a                   ; ($81)
.d:         call an_frame
            call an_clr
            ld a, [an_kxi]
            ld d, a
            ld a, [an_k3]
            ld e, a
            ld c, 0
            ld hl, $8F97
            call an_slist
            ld hl, an_kxi
            dec [hl]
            dec [hl]
            ld a, [an_k3]
            add 8
            ld [an_k3], a
            ld b, a
            ld a, [an_ky]
            cp b
            jr nc, .d
            call an_ssnd
            ld b, 32
.b:         push bc
            call an_frame
            call an_clr
            call an_burn
            pop bc
            dec b
            jr nz, .b
            call an_clr
            jp an_frame
; flames burning on monster an_t (32/8949): (centre x - 16, bottom - 39), 32/8F8B's lists by f
an_burn:    call an_tcen
            ld a, [fl_h]
            add a
            add a
            add e
            sub 39
            ld e, a
            ld a, d
            sub 16
            ld d, a
            ld a, [an_f]
            and 2
            ld l, a
            ld h, 0
            push de
            ld de, $8F8B
            add hl, de
            pop de
            ld c, 0
            jp an_slistp

; ---- 11: Inferno (32/87EC): 16 frames; Ifrit moving right 1 a frame 24 frames (its palettes
; cycling, 32/87AD with 87E9's hues), then left 8 a frame 26 frames with the backdrop flashing red;
; then flames on the monsters row by row (back first) 64 frames
an_s11:     call an_w16
            ld de, $B040
            call an_l11
            xor a
            ld [an_k4], a
.r:         ld a, [an_k4]
            inc a
            ld [an_k4], a
            call an_wpos
            ld a, [an_k4]                   ; the hue
            rrca
            rrca
            rrca
            and 3
            ld hl, if_hue
            call an_hla
            ld a, [hl]
            ld [an_k5], a
            ld c, 0
.p:         push bc
            call an_pcyc
            pop bc
            inc c
            ld a, c
            cp 3
            jr nz, .p
            call an_oput
            call an_frame
            ld a, [an_k4]
            cp 24
            jr nz, .r
            ld a, 26
            ld [an_k3], a
.l:         ld a, [an_k4]
            sub 8
            ld [an_k4], a
            call an_wpos
            ld a, [an_k3]
            and 3
            ld a, $16
            jr z, .c
            ld a, $0F
.c:         call an_backc
            call an_frame
            ld hl, an_k3
            dec [hl]
            jr nz, .l
            ld a, $0F
            call an_backc
            call an_sgone
            ld a, $BD
            call an_gpal3
            xor a
            ld [an_f], a
.m:         call an_frame
            call an_clr
            ld a, [an_f]                    ; the row: 3 - f / 16
            swap a
            cpl
            and 3
            ld [an_k5], a
            ld a, [an_f]
            and $0F
            call z, an_ssnd
            ld c, 0
.s:         push bc
            ld a, c
            call an_mrow
            ld hl, an_k5
            cp [hl]
            jr nz, .ns
            ld a, c
            ld [an_t], a
            call an_burn
.ns:        pop bc
            inc c
            ld a, c
            cp 8
            jr nz, .s
            ld a, [an_f]
            cp $40
            jr nz, .m
            call an_clr
            jp an_frame
; osh palette C cycling: hue an_k5, brightness by the frame (32/87AD)
an_pcyc:    ld a, c
            add a
            add a
            inc a
            ld hl, an_osh
            call an_hla
            ld a, [an_k5]
            and $0F
            ld e, a
            ld a, [an_f]
            and 3
            swap a
            ld d, a
            or e
            ld [hl+], a
            ld a, d
            add $10
            and $30
            or e
            ld [hl+], a
            ld a, d
            add $20
            and $30
            or e
            ld [hl], a
            ret
; monster slot A's row (34/8705: 34/8739 by the monster set's layout), $FF for none
an_mrow:    ld c, a
            ld hl, $DDA7
            call an_hla
            ld a, [hl]
            cp $FF
            ret z
            ld a, [$DD7B]
            add a
            ld hl, mn_rows
            call an_hla
            ld a, [hl+]
            ld d, a
            ld e, [hl]
            ld a, c
            inc a
            ld b, a
.s:         sla e
            rl d
            rla
            sla e
            rl d
            rla
            dec b
            jr nz, .s
            and 3
            ret

; ---- 12 / 13: Clobber / Stomp (32/82FE / 82F2): Titan's fists (32/90AD) on the target, placed
; again every 4 frames 0-24 pixels from its centre - 24, 64 frames (set 17 from 2B/B300 / B390,
; palette $EC)
an_s12:     ld de, $B300
            jr an_s13.g
an_s13:     ld de, $B390
.g:         push de
            ld a, $EC
            call an_gpal3
            pop de
            call an_l11
            ld a, [$DE99]
            call an_slot
            ld [an_t], a
            call an_tcen
            ld a, d
            sub 24
            ld [an_kxi], a
            ld a, e
            sub 24
            ld [an_ky], a
            call an_ssnd
            xor a
            ld [an_f], a
.f:         call an_frame
            call an_clr
            ld a, [an_f]
            and 3
            jr nz, .d
            ld b, 0
            ld a, $18
            call an_rnd
            ld [an_k4], a
            ld b, 0
            ld a, $18
            call an_rnd
            ld [an_k5], a
.d:         ld a, [an_kxi]
            ld hl, an_k4
            add [hl]
            ld d, a
            ld a, [an_ky]
            ld hl, an_k5
            add [hl]
            ld e, a
            ld c, 0
            ld hl, $90AD
            call an_slist
            ld a, [an_f]
            cp $40
            jr nz, .f
            call an_clr
            jp an_frame

; ---- 22: Rend (32/8376): the backdrop flashing red, then a line of sprites down the target (6, 12
; for a tall one) 64 frames (set 17 from 2B/B1A0, palette $7A)
an_s22:     ld a, $16
            call an_flash
            ld de, $B1A0
            call an_l11
            ld a, $7A
            call an_gpal3
            ld a, [$DE99]
            call an_slot
            ld [an_t], a
            call an_tcen
            ld a, d
            sub 4
            add 8
            ld [an_kxi], a
            ld a, [fl_y]
            add a
            add a
            add a
            add 7 + 17
            ld [an_ky], a
            ld a, [fl_h]
            cp 7
            ld a, 6
            jr c, .n
            ld a, 12
.n:         ld [an_k4], a
            call an_ssnd
            xor a
            ld [an_f], a
.f:         call an_frame
            call an_clr
            ld a, [an_f]
            srl a
            ld [an_k5], a
            ld a, [an_ky]
            ld e, a
            ld a, [an_k4]
            ld b, a
.s:         push bc
            push de
            call an_slot_oam
            pop de
            jr c, .x
            ld a, e
            ld [hl+], a
            ld a, [an_kxi]
            ld [hl+], a
            ld a, [an_k5]
            and 1
            inc a
            ld [hl+], a
            ld [hl], $0B
            ld hl, an_k5
            inc [hl]
.x:         ld a, e
            add 8
            ld e, a
            pop bc
            dec b
            jr nz, .s
            ld a, [an_f]
            cp $40
            jr nz, .f
            call an_clr
            jp an_frame

; ---- 23: Megaflare (32/841A): 60 frames; the backdrop white 16 frames (FF3 also cycles the colour
; emphasis); then two explosions (32/8F8F's frames) at random places by turns, the monsters'
; palettes cycling red, 64 frames (set 17 from 2B/B1C0, palette $BD)
an_s23:     xor a
            ld [an_xto], a
            ld b, 60
.w:         push bc
            call an_frame
            pop bc
            dec b
            jr nz, .w
            call an_ssnd
            ld a, $30
            ld b, 16
            ld [an_k4], a
            ld a, b
            ld [an_k3], a
.wf:        ld a, $30
            call an_backc
            call an_frame
            ld hl, an_k3
            dec [hl]
            jr nz, .wf
            ld a, $0F
            call an_backc
            call an_frame                   ; (the black written before the palettes are saved)
            ld de, $B1C0
            call an_l11
            ld a, $BD
            call an_gpal3
            call an_bgsave
            call an_xpos1
            call an_xpos2
            ld a, 2
            ld [an_xa], a
            xor a
            ld [an_xb], a
            ld [an_f], a
.f:         ld a, [an_f]                    ; (32/854D: every other frame the next frames)
            and 1
            jr nz, .dr
            ld hl, an_xa
            inc [hl]
            ld a, [hl]
            and 3
            ld [hl], a
            call z, an_xpos1
            ld hl, an_xb
            inc [hl]
            ld a, [hl]
            and 3
            ld [hl], a
            call z, an_xpos2
.dr:        ld a, $16                       ; the monsters' palettes in red
            call an_mcyc1
            call an_frame
            call an_clr
            ld a, [an_xa]
            ld hl, an_xp
            call an_xpl
            ld a, [an_xb]
            ld hl, an_xp + 2
            call an_xpl
            ld a, [an_f]
            cp $40
            jr nz, .f
            call an_clr
            call an_frame
            jp an_bgrest
; explosion frame A at (HL), (HL + 1)
an_xpl:     ld d, [hl]
            inc hl
            ld e, [hl]
            add a
            ld l, a
            ld h, 0
            push de
            ld de, $8F8F
            add hl, de
            pop de
            ld a, [an_xto]                  ; (the tiles' offset: Megaflare 0, the cannon $38)
            ld c, a
            jp an_slistp
; new places (32/85F8: x 16-128, y 47-111 on FF3's field, scaled)
an_xpos1:   ld hl, an_xp
            jr an_xpos
an_xpos2:   ld hl, an_xp + 2
an_xpos:    push hl
            ld b, $10
            ld a, $80
            call an_rnd
            call an_s58
            pop hl
            ld [hl+], a
            push hl
            ld b, $2F
            ld a, $6F
            call an_rnd
            sub $2F
            call an_s58
            pop hl
            ld [hl], a
            ret
; the monsters' palettes (BG 0 / 1) in hue A at the brightness of the frame (one step of an_mcyc)
an_mcyc1:   and $0F
            ld [an_k5], a
            ld a, [an_f]
            and 3
            swap a
            ld b, a
            ld hl, an_bpq + 1
            ld a, $0F
            call an_mcyc.one
            ld a, b
            call an_mcyc.one
            ld a, b
            add $10
            call an_mcyc.one
            ld a, b
            add $20
            call an_mcyc.one
            ld a, $80
            ld [an_bpq], a
            ld a, 1
            ld [an_bpf], a
            ld a, 1
            ld [an_bp2], a
            ret

; ---- 17: Zantetsuken (32/874C): (only when it works, $7E93 = 0) 16 frames; Odin riding off to the
; left 8 a frame (drawn in the BG cells, 23 frames); then the battlefield cut in bands of 24 lines
; sliding apart (SCX + / - up to 24 by FF3's sine), the monsters' palettes darkening every 8 frames
; in the last 32 frames, 96 frames; then FF3's state: each target's type counted as beaten
; ($7DD3), all monster types cleared
an_s17:     ld a, [$DE93]
            and a
            ret nz
            call an_w16
            call an_ssnd
            xor a                           ; (a back attack: Odin's own drawing from here)
            ld [an_sbv], a
            ld [an_sbd], a
            ld a, 167                       ; (the window off: Odin in the BG cells)
            ld [an_wxv], a
            call an_frame
            xor a
            ld [an_k4], a
.r:         call an_sbgdraw
            ld a, [an_k4]
            inc a
            ld [an_k4], a
            cp 24
            jr nz, .r
            call an_blankr                  ; (the BG map's columns 20-31 blank for the bands)
            call an_mpal0
            ld a, 23
            ldh [rLYC], a
            ld a, 4
            ld [c_split], a
            ld a, $40
            ldh [rSTAT], a
            xor a
            ld [an_f], a
.f:         ld a, [an_f]                    ; s = 24 x 2 sin(min(f, 64)) / 256
            cp $40
            jr c, .s
            ld a, $40
.s:         ld hl, an_sin
            call an_hla
            ld a, [hl]
            add a
            ld e, 24
            call mul8
            ld a, h
            ld [an_k4], a
            call an_frame
            ld a, [an_k4]                   ; (V-Blank: the first band's scroll, the first split)
            ldh [rSCX], a
            ld a, 23
            ldh [rLYC], a
            ld a, [an_f]
            and $C0
            jr z, .n
            ld a, [an_f]
            and 7
            call z, an_mfade
.n:         ld a, [an_f]
            cp $60
            jr nz, .f
            call wait_vbl
            xor a
            ld [c_split], a
            ldh [rSCX], a
            ld a, $40
            ldh [rSTAT], a
            ld a, 95
            ldh [rLYC], a
            ld a, [$DE99]                   ; FF3's state (32/8757)
            ld [an_tm], a
            ld c, 0
.t:         ld a, [an_tm]
            add a
            ld [an_tm], a
            jr nc, .tn
            ld a, c
            ld hl, $DDA7
            call an_hla
            ld a, [hl]
            cp $FF
            jr z, .tn
            ld hl, $DDD3
            call an_hla
            inc [hl]
.tn:        inc c
            ld a, c
            cp 8
            jr nz, .t
            ld hl, $DDA7
            ld b, 8
            ld a, $FF
.cl:        ld [hl+], a
            dec b
            jr nz, .cl
            ret
; Odin in the BG cells, an_k4 columns to the left (the cells of the last frame back first)
an_sbgdraw: call wait_vbl
            ld a, 1
            ld [guard_on], a
            ld a, $20
            ldh [rSTAT], a
            ld a, [an_k4]                   ; the new place first, then the previous
            ld [an_k5], a                   ;   place's cells it does not cover back to
            xor a                           ;   the battlefield (no flicker)
            ld [an_k2], a
            call .cells
            ld a, [an_k4]
            and a
            jr z, .d
            ld [an_kc], a
            dec a
            ld [an_k5], a
            ld a, 1
            ld [an_k2], a
            call .cells
.d:         ld a, [an_won]
            and a
            jr z, .s
            ld a, $40
.s:         ldh [rSTAT], a
            xor a
            ld [guard_on], a
            ret
.cells:     ld c, 0                         ; C = row in the summon
.r:         ld b, 0
.k:         ld a, [an_sc0]                  ; screen column = an_sc0 + B - an_k5 (signed)
            add b
            ld hl, an_k5
            sub [hl]
            bit 7, a
            jr nz, .n
            cp 20
            jr nc, .n
            ld e, a
            ld a, [an_sr0]
            add c
            cp 12
            jr nc, .n
            ld d, a
            push bc
            push de
            ld a, [an_sw]                   ; the map byte
            ld e, a
            ld a, c
            call mul8                       ; (clobbers B, D)
            pop de
            pop bc
            push bc
            push de
            ld a, l
            add b
            ld e, a
            ld a, [an_smp]
            add e
            ld l, a
            ld a, [an_smp + 1]
            adc 0
            ld h, a
            call an_sb
            pop de
            cp $FF
            jr z, .p
            ld b, a
            ld a, [an_k2]
            and a
            jr nz, .o
            ld a, b
            and $3F
            add $90
            ld [an_bgi], a
            ld a, b
            rlca
            rlca
            and 3
            add 2
            or $08
            ld [an_bga], a
            jr .w
.o:         ld a, [an_kc]                   ; (covered by the new place: left)
            cp $80
            jr z, .o2
            push de
            ld a, [an_sc0]
            ld b, a
            ld a, e
            sub b
            ld hl, an_kc
            add [hl]
            bit 7, a
            jr nz, .o1
            ld hl, an_sw
            cp [hl]
            jr nc, .o1
            ld [an_kxi], a
            pop de
            pop bc
            push bc
            push de
            ld a, [an_sw]
            ld e, a
            ld a, c
            call mul8
            ld a, [an_kxi]
            add l
            ld e, a
            ld a, [an_smp]
            add e
            ld l, a
            ld a, [an_smp + 1]
            adc 0
            ld h, a
            call an_sb
            pop de
            cp $FF
            jr nz, .p
            jr .o2
.o1:        pop de
.o2:        call an_shp                     ; the battlefield's own cell
            ld a, [hl]
            ld [an_bgi], a
            ld bc, SH_A - SH_T
            add hl, bc
            ld a, [hl]
            ld [an_bga], a
.w:         push de
            call an_mcell                   ; (mirrored in a back attack)
            pop de
            jr z, .p
            ld a, [an_bgi]
            ld [hl], a
            ld a, 1
            ldh [rVBK], a
            ld a, [an_bga]
            xor b
            ld [hl], a
            xor a
            ldh [rVBK], a
.p:         pop bc
.n:         inc b
            ld a, [an_sw]
            cp b
            jr nz, .k
            inc c
            ld a, [an_sh]
            cp c
            jr nz, .r
            ret
; HL = SH_T + 20 D + E (keeps DE)
an_shp:     ld a, d
            add a
            add a
            ld l, a
            add a
            add a
            add l
            add e
            ld l, a
            ld h, 0
            push de
            ld de, SH_T
            add hl, de
            pop de
            ret
; the BG map's columns 20-31, rows 0-11 blank (palette 0)
an_blankr:  call wait_vbl
            ld a, 1
            ld [guard_on], a
            ld a, $20
            ldh [rSTAT], a
            ld hl, $9800 + 20
            ld c, 12
.r:         push hl
            ld b, 12
.c:         ld [hl], BLANK_T
            ld a, 1
            ldh [rVBK], a
            ld [hl], 0
            xor a
            ldh [rVBK], a
            inc hl
            dec b
            jr nz, .c
            pop hl
            ld de, 32
            add hl, de
            dec c
            jr nz, .r
            xor a
            ldh [rSTAT], a
            ld [guard_on], a
            ret
; the monsters' NES colours (battle palettes $7D69 / $7D6A) into an_mpn, then each fade step
an_mpal0:   ld a, [$DD69]
            ld c, 0
            call .p
            ld a, [$DD6A]
            ld c, 4
.p:         ld l, a
            ld h, 0
            ld d, h
            ld e, l
            add hl, hl
            add hl, de
            ld de, $8C00 - $4000
            add hl, de
            ld a, c
            ld de, an_mpn
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
an_mfade:   ld hl, an_mpn                   ; (32/8C70)
            ld b, 8
.c:         ld a, [hl]
            and $F0
            jr z, .k
            ld a, [hl]
            sub $10
            jr .s
.k:         ld a, $0F
.s:         ld [hl+], a
            dec b
            jr nz, .c
            ld hl, an_mpn
            ld de, an_bpq + 1
            ld b, 4
.r:         push bc
            ld a, [hl+]
            push hl
            push de
            call an_nrgb
            pop de
            ld a, c
            ld [de], a
            inc de
            ld a, b
            ld [de], a
            inc de
            pop hl
            pop bc
            dec b
            jr nz, .r
            ld a, $80
            ld [an_bpq], a
            ld a, 1
            ld [an_bpf], a
            call an_frame                   ; (palette 1 the next frame)
            ld hl, an_mpn + 4
            ld de, an_bpq + 1
            ld b, 4
.r2:        push bc
            ld a, [hl+]
            push hl
            push de
            call an_nrgb
            pop de
            ld a, c
            ld [de], a
            inc de
            ld a, b
            ld [de], a
            inc de
            pop hl
            pop bc
            dec b
            jr nz, .r2
            ld a, $88
            ld [an_bpq], a
            ld a, 1
            ld [an_bpf], a
            ret

; ---- 19: Cyclone (32/8272): 60 frames; Leviathan going off; 16 frames; a tornado of 64 sprites
; (here 40 of them) moving left across the screen 4 a frame, each swaying (set 14, palette $FF)
an_s19:     ld b, 60
.w:         push bc
            call an_frame
            pop bc
            dec b
            jr nz, .w
            call an_sexit
            call an_w16
            ld a, $FF
            call an_gpal3
            ld a, 14
            call an_lgfx
            ld a, $10                       ; (32/8228: x of each from a sine at $A0 + 4 i, sway
            ld [an_k], a                    ;   angles random, amplitudes 50 down / 2)
            ld hl, cy_x
            ld a, $A0
            ld b, 64
.i:         push af
            push bc
            push hl
            call an_smul
            pop hl
            ld [hl+], a
            pop bc
            pop af
            add 4
            dec b
            jr nz, .i
            ld hl, cy_ang
            ld de, RNG_TAB
            ld b, 64
.i2:        ld a, [de]
            inc de
            ld [hl+], a
            dec b
            jr nz, .i2
            ld a, $FC
            ld [an_k3], a
            xor a
            ld [an_k4], a                   ; ($88)
            call an_ssnd
.f:         call an_frame
            call an_clr
            ld a, [an_k4]
            ld [an_k5], a                   ; ($91)
            xor a
            ld [an_t], a
.s:         ld a, [an_t]                    ; (40 of FF3's 64: i = 8 t / 5)
            ld b, a
            add a
            add a
            add a
            ld e, a
            ld d, 0
            push bc
            ld bc, 0
.dv:        ld a, e
            sub 5
            ld e, a
            ld a, d
            sbc 0
            ld d, a
            jr c, .dd
            inc c
            jr .dv
.dd:        ld a, c
            pop bc
            ld [an_k2], a                   ; i
            cp 48                           ; amplitude: 50 - i, the last 16: 2
            ld a, 2
            jr nc, .am
            ld a, [an_k2]
            cpl
            add 51
.am:        ld [an_k], a
            ld a, [an_k5]
            ld hl, an_k2
            add [hl]
            and $3F
            push af
            ld hl, cy_ang
            call an_hla
            ld a, [hl]
            ld c, a
            add $10
            ld [hl], a
            ld a, c
            call an_smul
            ld c, a
            pop af
            ld hl, cy_x
            call an_hla
            ld a, [hl]
            add c
            ld c, a                         ; x offset (signed)
            ld a, [an_k3]
            call an_s58
            ld b, a
            ld a, c
            sra a
            sra a                           ; (offsets scaled roughly)
            add b
            cp 160
            jr nc, .nx
            add 8
            ld [an_kxi], a
            ld a, [an_k2]                   ; y: $20 + 2 i, scaled
            add a
            add $20
            call an_s58
            add 16 - 8
            ld [an_ky], a
            call an_slot_oam
            jr c, .nx
            ld a, [an_ky]
            ld [hl+], a
            ld a, [an_kxi]
            ld [hl+], a
            ld a, $49
            ld [hl+], a
            ld [hl], $0B
.nx:        ld hl, an_t
            inc [hl]
            ld a, [hl]
            cp 40
            jp nz, .s
            ld hl, an_k4
            inc [hl]
            ld a, [an_k3]
            sub 4
            ld [an_k3], a
            jp nz, .f
            call an_clr
            jp an_frame

; ---- 20: Tidal Wave (32/8635): 60 frames; Leviathan going off; 16 frames; 21 waves (3 sprites
; each) rolling left over the battlefield with the screen shaking, 63 frames (set 17 from 2B/B160,
; palette $BC); FF3's places scaled 5 / 8
an_s20:     ld de, $B160
            call an_l11
            ld b, 60
.w:         push bc
            call an_frame
            pop bc
            dec b
            jr nz, .w
            call an_sexit
            call an_w16
            ld a, $BC
            call an_gpal3
            ld hl, tw_x                     ; (32/866A: x random - 12 / - 24, y in steps)
            ld de, RNG_TAB
            ld c, $34
            ld b, 7
.a:         ld a, [de]
            inc de
            and $0F
            sub $0C + 1
            ld [hl+], a
            ld a, c
            ld [hl+], a
            add $0C
            ld c, a
            dec b
            jr nz, .a
            ld c, $28
            ld b, 14
.b:         ld a, [de]
            inc de
            and $0F
            sub $18 + 1
            ld [hl+], a
            ld a, c
            ld [hl+], a
            add 8
            ld c, a
            dec b
            jr nz, .b
            ld hl, tw_cnt
            ld de, RNG_TAB
            ld b, 21
.c:         ld a, [de]
            inc de
            ld [hl], a
            push hl
            push de
            ld de, 21
            add hl, de
            ld [hl], 0                      ; (tw_on)
            pop de
            pop hl
            inc hl
            dec b
            jr nz, .c
            call an_ssnd
            ld a, $FC
            ld [an_k3], a
.f:         call an_frame                   ; (the shake: the battlefield 0-3 pixels across)
            ld b, 0
            ld a, $FF
            call an_rnd
            and 3
            ldh [rSCX], a
.ly:        ldh a, [rLY]
            cp 95
            jr nz, .ly
.hb:        ldh a, [rSTAT]
            and 3
            jr nz, .hb
            xor a
            ldh [rSCX], a
            call an_clr
            xor a
            ld [an_t], a
.k:         ld a, [an_t]                    ; (32/8701)
            ld c, a
            ld b, 0
            ld hl, tw_cnt
            add hl, bc
            dec [hl]
            ld a, [hl]
            and 7
            ld hl, tw_x
            add hl, bc
            add hl, bc
            jr nz, .m
            ld a, [hl]
            sub 8
            ld [hl], a
.m:         ld a, [hl]
            sub 4
            ld [hl+], a
            ld d, a
            cp $80
            jr c, .v
            cp $E8
            jr nc, .v
            push hl
            ld hl, tw_on
            add hl, bc
            ld [hl], 1
            pop hl
.v:         ld a, [hl]
            ld e, a                         ; y
            ld hl, tw_on
            add hl, bc
            ld a, [hl]
            and a
            call nz, an_twave
            ld hl, an_t
            inc [hl]
            ld a, [hl]
            cp 21
            jr nz, .k
            ld a, [an_k3]
            sub 4
            ld [an_k3], a
            jr nz, .f
            call an_clr
            jp an_frame
; a wave at FF3's (D, E): tiles 1-3 across, the part left of the screen's edge (an_k3) shown
an_twave:   ld b, 3
            ld c, 1
.s:         push bc
            push de
            ld a, d
            sub 8
            ld hl, an_k3
            cp [hl]
            jr nc, .n                       ; (32/86E1: hidden right of the edge)
            ld a, d
            call an_s58
            cp 160
            jr nc, .n
            add 8
            ld [an_kxi], a
            ld a, e
            call an_s58
            add 16 - 8
            ld [an_ky], a
            call an_slot_oam
            jr c, .n
            ld a, [an_ky]
            ld [hl+], a
            ld a, [an_kxi]
            ld [hl+], a
            ld a, c
            ld [hl+], a
            ld [hl], $0B
.n:         pop de
            pop bc
            ld a, d
            add 8
            ld d, a
            inc c
            dec b
            jr nz, .s
            ret

section bank B_BANIM, $7D00
sm_snd:     ds 24                           ; (2F/AFC0)
sm_pal:     ds 8                            ; (32/8043)
sm_pre:     ds 10                           ; (33/B1EE)
sm_fly:     ds 16                           ; (33/AFF2)
if_hue:     ds 3                            ; (32/87E9)
mn_rows:    ds 20                           ; (34/8739: the monsters' rows by layout)

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
an_tpc:     ds 1
an_bpf:     ds 1
an_bpq:     ds 9
an_bgs:     ds 16
an_bp2:     ds 1
an_rh:      ds 1
an_rw:      ds 1
an_pfr:     ds 1
an_pspin:   ds 1
an_px0:     ds 1
an_py0:     ds 1
an_pdxx:    ds 1
an_pdy:     ds 1
an_pn2:     ds 1
an_pk:      ds 1
an_sl1:     ds 1
an_sl2:     ds 1
an_sl3:     ds 1
an_sl4:     ds 1
an_sbase:   ds 1
an_smode:   ds 1                            ; (0 the window, 1 sprites, 2 BG cells)
an_sox:     ds 1
an_soy:     ds 1
an_xa:      ds 1
an_xb:      ds 1
an_xp:      ds 4
an_mpn:     ds 8

section wram, $D9C0                         ; (one animation's tables at a time)
dd_cnt:     ds 40
dd_dly:     ds 40
dd_on:      ds 40
dd_y:       ds 40
dd_x:       ds 40
CY_BASE    = $D9C0                          ; (Cyclone's, Tidal Wave's tables in the same place)
cy_x       = CY_BASE
cy_ang     = CY_BASE + 64
tw_x       = CY_BASE
tw_cnt     = CY_BASE + 42
tw_on      = CY_BASE + 63


section bank B_SUMN, $6800                  ; (after the 640 tiles)
sm_lst:     ds $24C                         ; (32/8F8B-91D6: the attacks' sprite lists)
sm_data:    ds $1C0                         ; (2A/9440: the summons' properties, maps)
em_data:    ds 5 * $60                      ; (06/8E20: the monsters' Flame / Blizzard / Thunder)

; ---- a summon in the BG cells (a back attack, 2): moved by an_frame after the rows (under the guard)
section bank B_BANIM, $7B00
an_sbgmv:   ld a, [c_split]                 ; (not while a raster effect runs)
            and a
            ret nz
            xor a
            ld [an_sbd], a
            ld a, 1
            ld [guard_on], a
            ld a, $20
            ldh [rSTAT], a
            ld a, [an_sbn]                  ; the new place
            ld [an_k5], a
            xor a
            ld [an_k2], a
            call an_sbgdraw.cells
            ld a, [an_sbv]                  ; (the old place's cells it does not cover back)
            and a
            jr z, .d
            ld a, [an_sbn]
            ld [an_kc], a
            ld a, [an_sbo]
            ld hl, an_sbn
            cp [hl]
            jr z, .d
            ld [an_k5], a
            ld a, 1
            ld [an_k2], a
            call an_sbgdraw.cells
.d:         ld a, [an_sbn]
            ld [an_sbo], a
            ld a, 1
            ld [an_sbv], a
            jr an_sbgx
an_sbgoff:  ld a, [an_sbv]                  ; its cells back to the battlefield's
            and a
            ret z
            xor a
            ld [an_sbv], a
            ld [an_sbd], a
            call wait_vbl
            ld a, 1
            ld [guard_on], a
            ld a, $20
            ldh [rSTAT], a
            ld a, $80
            ld [an_kc], a
            ld a, [an_sbo]
            ld [an_k5], a
            ld a, 1
            ld [an_k2], a
            call an_sbgdraw.cells
an_sbgx:    xor a
            ldh [rSTAT], a
            ld [guard_on], a
            ret
; (an_frame, before the rows) a row under the summon about to be drawn again: the summon after it
an_sbgrw:   ld a, [an_sbv]
            and a
            ret z
            ld a, [an_sr0]
            ld hl, SH_D
            call an_hla
            ld a, [an_sh]
            ld b, a
.r:         ld a, [hl+]
            and a
            jr nz, .y
            dec b
            jr nz, .r
            ret
.y:         ld a, [an_sbo]
            ld [an_sbn], a
            ld a, 1
            ld [an_sbd], a
            ret

section wram, $C5DA
an_sbv:     ds 1                            ; (a summon in the BG cells: drawn; the offset drawn,
an_sbo:     ds 1                            ;   the next; to draw)
an_sbn:     ds 1
an_sbd:     ds 1
an_kc:      ds 1                            ; (a restore: the covering place, $80 none)
an_kxi:     ds 1
an_xto:     ds 1                            ; (the explosion frames' tile offset)
an_ckx:     ds 1                            ; (the cannonball's place)
an_cky:     ds 1
bs_wbr:     ds 1                            ; (bs_putsw: the line's break)

; ---- the Invincible's cannon blast (32/84C9): a ball (tiles $4D-$50, palette $D9, set $0F) falling
; from the upper right on an arc (the vector's y: length $60, angle $C0 down 2 a frame; x 3 to the
; left a frame) 32 frames; then an explosion (32/8F8F's frames, tiles + $38, palette $BD) at a
; random place (32/85F8), the next frame every other frame and a new place every 8, the monsters'
; palettes cycling red, 64 frames; the palettes back
section bank B_BANIM, $7D60
an_cannon:  call an_savepal
            call an_bgsave
            ld a, $D9
            call an_gpal3
            ld a, $0F
            call an_lgfx
            xor a
            ld [an_f], a
            ld [an_k3], a
            ld a, $C0
            ld [an_k4], a
.p:         call an_clr
            ld hl, an_k3                    ; x = $B0 + $8C ($8C down 3)
            ld a, [hl]
            sub 3
            ld [hl], a
            add $B0
            call an_s58
            ld [an_ckx], a
            ld a, $60                       ; y = $60 + $60 sin(angle)
            ld [an_k], a
            ld a, [an_k4]
            call an_smul
            add $60
            call an_s58
            ld [an_cky], a
            ld hl, an_k4
            dec [hl]
            dec [hl]
            ld a, [an_cky]
            dec a
            ld e, a
            ld a, [an_ckx]
            ld d, a
            ld b, $4D
            call .spr
            ld a, d
            add 8
            ld d, a
            inc b
            call .spr
            ld a, e
            add 8
            ld e, a
            ld a, [an_ckx]
            ld d, a
            inc b
            call .spr
            ld a, d
            add 8
            ld d, a
            inc b
            call .spr
            call an_frame
            ld a, [an_f]
            cp $20
            jr nz, .p
            call an_clr
            ld a, $BD
            call an_gpal3
            ld a, $38
            ld [an_xto], a
            call an_xpos1
            ld a, 2
            ld [an_xa], a
.e:         ld a, [an_f]
            and 1
            jr nz, .d
            ld hl, an_xa
            inc [hl]
            ld a, [hl]
            and 3
            ld [hl], a
            call z, an_xpos1
.d:         ld a, $16                       ; (32/87AD: the monsters' palettes in red)
            call an_mcyc1
            call an_frame
            call an_clr
            ld a, [an_xa]
            ld hl, an_xp
            call an_xpl
            ld a, [an_f]
            cp $60
            jr nz, .e
            call an_clr
            call an_frame
            xor a
            ld [an_xto], a
            call an_bgrest
            jp an_restpal
; a ball sprite: tile B at (D, E) (palette 3); none off the battlefield
.spr:       ld a, e
            cp 96
            ret nc
            ld a, d
            cp 160
            ret nc
            push bc
            push de
            call an_slot_oam
            pop de
            pop bc
            ret c
            ld a, e
            add 17
            ld [hl+], a
            ld a, d
            add 8
            ld [hl+], a
            ld a, b
            ld [hl+], a
            ld [hl], $0B
            ret
