; ---- battle (FF3 banks $2E-$35), bank CODE2. FF3's battle RAM keeps its layout in Color WRAM
; bank 3 while a battle runs: zero page $00-$FF at BZ ($D000: FF3's field map area, unused in
; battle) and $7200-$7EFF at W7 + address ($D200-$DEFF). The save block ($6000-$63FF) is GS as on
; the field, the sound RAM ($7F40-) the driver's ($CC40). Pointers kept in RAM are GB addresses.
; The battle starts from the field (battle_go, act $20) as FF3's fix:E26A / FFA26: the flash,
; init, the battle main loop, the fade out; then the map is reloaded.
btl_pals   = $DF00              ; (WRAM bank 3, FF3's unused $7F00-: the palettes before the flash)

btl_main:   call btl_flash
            call pal_black                  ; (the LCD stays on behind black: no white screen;
            ld a, 3                         ;   the VRAM copies by DMA)
            ldh [rSVBK], a
            call inv_pair                   ; (3C/BC12: the inventory as pairs)
            ld hl, BZ                       ; FF3's battle RAM cleared (zero page, $7200-$7EFF)
            ld de, $0F00
            call memclr
            ld a, [btl_id]                  ; FFA26: battle index, bg, flags
            ld [W7 + $7CED], a
            call btl_bg                     ; (3A/8533: the map's battle bg and flags)
            ld [W7 + $7CEF], a
            ld a, [cur_world]               ; (FFA26: the flags = field $78, the world)
            ld [W7 + $7ED8], a
            ld a, [cur_map]                 ; (FFB17 pushed the field's zero page: $74C8 = the
            ld [W7 + $74C8], a              ;   map id, $74C6 the vehicle)
            xor a
            ld [W7 + $74C6], a
            call btl_init
            call init_cm                    ; (34/9CE3 init characters / monsters)
; [TEST]
            ld a, [btl_fba]                 ; (test hook: btl_fba = $88 forces a back attack)
            cp $88
            jr nz, .nf
            call row_toggle
            ld a, $88
            ld [W7 + $78C3], a
            ld [W7 + $78BA], a
            xor a
            ld [btl_fba], a
; [/TEST]
.nf:
            call oam_hide                   ; (2E/9F8D clear oam data)
            call bg_init
            call btl_screen
            ld a, 1
            ld [lcd_is], a
            ld a, LCDC_ON
            ldh [rLCDC], a
            call ba_walkin                  ; (2F/B469)
            call ui_init
            call btl_loop
            call btl_end
            ld a, 3
            ldh [rSVBK], a
            call inv_unpair                 ; (3C/BC2D)
            ld a, [W7 + $78D3]              ; (defeated: FF3 starts the program again)
            ld [btl_res], a
            ret

; fix:D34D: the flash (sound $95, 64 frames of the screen's greyscale bit toggling): the BG and
; sprite palettes swapped with grey versions every frame
btl_flash:  ld a, $95
            ld [S49], a
            ld a, 3                         ; (the copy in WRAM bank 3's unused top)
            ldh [rSVBK], a
            ld hl, pal_sh                   ; (the palettes kept)
            ld de, btl_pals
            ld bc, 128
            call memcpy
            xor a
            ld [btl_k], a
.f:         ld a, [btl_k]
            and 1
            jr z, .n
            ld hl, pal_sh                   ; greyscale: each colour's green level in all three
            ld b, 64
.g:         ld a, [hl+]                     ; g = ((hi and 3) << 3) | (lo >> 5)
            ld e, a
            ld a, [hl-]
            and 3
            add a, a
            add a, a
            add a, a
            ld d, a
            ld a, e
            swap a
            rrca
            and 7
            or d
            ld c, a
            add a, a                        ; lo = g | g << 5
            add a, a
            add a, a
            add a, a
            add a, a
            or c
            ld [hl+], a
            ld a, c                         ; hi = g >> 3 | g << 2
            srl a
            srl a
            srl a
            ld d, a
            ld a, c
            add a, a
            add a, a
            or d
            ld [hl+], a
            dec b
            jr nz, .g
            jr .gd
.n:         ld hl, btl_pals
            ld de, pal_sh
            ld bc, 128
            call memcpy
.gd:        ld a, 1
            ldh [pal_dirty], a
            call wait_vbl
            ld hl, btl_k
            inc [hl]
            ld a, [hl]
            cp $41
            jr c, .f
            ld hl, pal_sh                   ; then black
            ld de, 128
            call memclr
            ld a, 1
            ldh [pal_dirty], a
            jp wait_vbl

; 3A/8533: the battle bg and flags of the map (39/BC00 + map; 39/BD00 off world 0)
btl_bg:     ld a, [cur_map]
            ld l, a
            ld h, $5C                       ; (JOB_BANK: FF3 bank $39, NES $A000, at $4000)
            ld a, [cur_grp]
            and a
            jr z, .w
            inc h
.w:         ld a, JOB_BANK
            jp rd_byte

; ---- 2E/9E8E init battle (the parts the native battle needs), FFC27 init rng, 2F/A02A load
; monster set, 2E/9FAA tilemap id, 2F/A31F slots, 2F/B909 monsters remaining
btl_init:   ld a, [W7 + $7ED8]
            and a
            jr z, .nb
            ld a, 1                         ; (a boss battle: msb of the battle id)
.nb:        ld [W7 + $7CEE], a
            ld a, [W7 + $7ED8]
            ld [BZ + $7E], a
            ld a, [W7 + $7CEF]
            push af
            and $1F
            ld [W7 + $7CEF], a
            pop af
            and $E0
            ld [W7 + $7ED8], a
            ld a, [W7 + $74C6]
            cp 4
            jr c, .bg
            ld a, [BZ + $7E]
            cp 4
            jr z, .bg
            ld a, 6
            ld [W7 + $7CEF], a
.bg:        ld a, $88                       ; ($06 / $07 / $08: FF3's ppu control copies)
            ld [BZ + $06], a
            ld [BZ + $07], a
            ld a, $99
            ld [BZ + $08], a
            ld a, $10
            ld [BZ + $04], a
            ld a, $97
            ld [BZ + $03], a
            call rng_init
            call mon_set
            call mon_tmid
            call mon_slots
            call mon_count
            ld hl, W7 + $7DA7               ; $7ECD = monster types
            ld de, W7 + $7ECD
            ld bc, 8
            call memcpy
            ld a, [W7 + $7D68]              ; $7ED8 |= (count id >> 6) and 3
            rlca
            rlca
            and 3
            ld b, a
            ld a, [W7 + $7ED8]
            or b
            ld [W7 + $7ED8], a
            ret

; FFC27: the battle's random table ($7BE3, 256 bytes) from a seed (FF3: the sum of its zero page;
; here the field's random counters and the frame count stand in for it)
rng_init:
; [TEST]
            ld a, [btl_seedf]               ; (test hook: btlcmp.py sets the NES's seed)
            cp $A5
            ld a, [btl_seedv]
            jr z, .sd
; [/TEST]
            ld a, [rnd_f5]
            ld b, a
            ld a, [rnd_f6]
            add a, b
            ld b, a
            ldh a, [rDIV]
            add a, b
.sd:
            ld [BZ + $15], a
            ld [BZ + $16], a
            ld [BZ + $17], a
            and 2
            add a, 3
            ld [BZ + $22], a
            ld a, 1
            ld [BZ + $20], a
            xor a
            ld [BZ + $21], a
            ld [btl_k], a                   ; (Y)
.l:         ld a, [BZ + $22]                ; x = (22 * x) mod 1021-ish: FF3's generator
            ld [BZ + $18], a
            xor a
            ld [BZ + $19], a
            ld a, [BZ + $20]
            ld [BZ + $1A], a
            ld a, [BZ + $21]
            ld [BZ + $1B], a
            call bmul16
            ld a, [BZ + $1C]
            ld [BZ + $18], a
            ld a, [BZ + $1D]
            ld [BZ + $19], a
            xor a
            ld [BZ + $1A], a
            ld a, 4
            ld [BZ + $1B], a
            call bdiv16
            ld a, [BZ + $1F]                ; remainder - 2 (16 bits): > 0 -> $0400 - remainder
            sub 2
            ld b, a
            ld a, [BZ + $1E]
            or b
            jr z, .k
            ld a, [BZ + $1F]
            cp 2
            jr c, .k
            ld a, [BZ + $1E]
            cpl
            add a, 1
            ld [BZ + $1E], a
            ld a, [BZ + $1F]
            cpl
            adc a, 4
            ld [BZ + $1F], a
.k:         ld a, [BZ + $1F]
            ld [BZ + $21], a
            ld b, a
            ld a, [BZ + $1E]
            ld [BZ + $20], a
            srl b                           ; table[y] = (x >> 1) and $FF
            rra
            ld b, a
            ld a, [btl_k]
            ld l, a
            ld h, high(W7 + $7BE3)
            ld a, l
            add a, low(W7 + $7BE3)
            ld l, a
            jr nc, .s
            inc h
.s:         ld [hl], b
            ld hl, btl_k
            inc [hl]
            jr nz, .l
            ret

; 2F/A02A load monster set: 2E/8000 + 2 index -> $7D67 / $7D68; 2E/8400 + 6 set -> $7D69..;
; graphics attribute ids -> $7D73; counts 2E/8A00 + 4 (count id and $3F) randomized
mon_set:    ld a, [W7 + $7CED]
            ld l, a
            ld a, [W7 + $7CEE]
            ld h, a
            add hl, hl
            ld de, BD_BATTLE
            add hl, de
            call bd_rd
            ld [W7 + $7D67], a
            call bd_rd
            ld [W7 + $7D68], a
            ld a, [W7 + $7D67]              ; x 6
            ld l, a
            ld h, 0
            add hl, hl
            ld d, h
            ld e, l
            add hl, hl
            add hl, de
            ld de, BD_SET
            add hl, de
            ld de, W7 + $7D69
            ld bc, 6
            ld a, BDATA_BANK
            call rd_copy
            xor a
.at:        ld [btl_k], a
            add a, low(W7 + $7D6B)
            ld l, a
            ld h, high(W7 + $7D6B)
            ld a, [hl]
            call mon_attr                   ; -> BZ+$7E / $7F
            ld a, [btl_k]
            add a, a
            add a, low(W7 + $7D73)
            ld l, a
            ld h, high(W7 + $7D73)
            ld a, [BZ + $7E]
            ld [hl+], a
            ld a, [BZ + $7F]
            ld [hl], a
            ld a, [btl_k]
            inc a
            cp 4
            jr nz, .at
            ld a, [W7 + $7D68]
            and $3F
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            ld de, BD_COUNT
            add hl, de
            ld de, W7 + $7D6F
            ld bc, 4
            ld a, BDATA_BANK
            call rd_copy
            xor a
.cn:        ld [btl_k], a
            add a, low(W7 + $7D6F)
            ld l, a
            ld h, high(W7 + $7D6F)
            push hl
            ld a, [hl]                      ; random (min..max) with counter 0
            ld c, a
            xor a
            ld [BZ + $21], a
            ld a, c
            swap a
            and $0F
            ld b, a
            ld a, c
            and $0F
            call rnd_xa
            pop hl
            ld [hl], a
            ld a, [btl_k]
            inc a
            cp 4
            jr nz, .cn
            ret

; 2F/A0E7: monster id A -> BZ+$7E = graphics properties (size class, id), BZ+$7F = graphics id
; + the size class's offset, msb from the boss table (2E/8F00 + id >> 3, bit id and 7)
mon_attr:   cp $FF
            jr nz, .m
            ld [BZ + $7E], a
            ld [BZ + $7F], a
            ret
.m:         ld [BZ + $81], a
            ld l, a
            ld h, high(BD_GPROP)
            call bd_rd
            ld [BZ + $7E], a
            and $1F
            ld c, a
            ld a, [BZ + $7E]
            and $E0
            ld b, $10
            cp $20
            jr z, .o
            ld b, $18
            cp $60
            jr z, .o
            ld b, 0
.o:         ld a, b
            add a, c
            ld [BZ + $7F], a
            ld a, [BZ + $81]                ; the boss bit: (2E/8F00 + id / 8) << (id and 7) + 1
            and 7
            inc a
            ld c, a
            ld a, [BZ + $81]
            srl a
            srl a
            srl a
            ld l, a
            ld h, high(BD_8F00)
            call bd_rd
            ld b, 0
.b:         add a, a
            rr b
            dec c
            jr nz, .b
            ld a, [BZ + $7F]                ; (FF3: and $80 / ora: only the graphics id kept)
            ld [BZ + $7F], a
            ret

; 2E/9FAA (+ 2F/A000): the monster tilemap id -> $7D7B
mon_tmid:   ld a, [W7 + $7D73]
            and $E0
            ld [BZ + $7E], a
            and $C0
            ld b, 0
            jr z, .set
            ld a, [BZ + $7E]
            ld b, 7
            cp $A0
            jr z, .set
            and $C0
            ld b, 9
            cp $C0
            jr z, .set
            cp $40
            jr nz, .s0
            ld a, [W7 + $7D77]
            and $C0
            ld b, 3
            jr nz, .set
            ld b, 1
            jr .set
.s0:        ld a, [W7 + $7D6F]              ; (2E/9FE5 -)
            cp 1
            jr nz, .t
            ld a, [W7 + $7D75]
            and $C0
            ld b, 2
            jr z, .set
            cp $40
            jr nz, .t
            ld b, 4
            jr .set
.t:         ld a, [W7 + $7D75]              ; 2F/A001
            and $E0
            ld b, 8
            cp $A0
            jr z, .set
            ld a, [W7 + $7D6F]
            cp 2
            jr nz, .six
            ld a, [W7 + $7D75]
            and $C0
            ld b, 5
            cp $40
            jr z, .set
.six:       ld b, 6
.set:       ld a, b
            ld [W7 + $7D7B], a
            ret

; 2F/A31F init monster slots: $7DA7 / $7DAF = each slot's monster type (from the tilemap's
; first slot per type, 2F/A4DA)
mon_slots:  ld hl, W7 + $7DA7
            ld b, 16
            ld a, $FF
.c:         ld [hl+], a
            dec b
            jr nz, .c
            ld a, [W7 + $7D7B]
            add a, a
            add a, a
            add a, low(TB_TYPES)
            ld l, a
            ld a, high(TB_TYPES)
            adc a, 0
            ld h, a
            ld de, btl_tmp
            ld bc, 4
            ld a, BDATA_BANK
            call rd_copy
            xor a
.t:         ld [btl_k], a                   ; (Y)
            ld e, a
            ld d, 0
            ld hl, btl_tmp
            add hl, de
            ld a, [hl]
            cp $FF
            jr z, .n
            ld [BZ + $8C], a
.n:         ld hl, W7 + $7D6F
            add hl, de
            ld a, [hl]
            and a
            jr z, .nx
            ld c, a
.m:         ld a, [BZ + $8C]
            ld l, a
            ld h, 0
            ld de, W7 + $7DA7
            add hl, de
            ld a, [btl_k]
            ld [hl], a
            ld de, 8
            add hl, de
            ld [hl], a
            ld hl, BZ + $8C
            inc [hl]
            dec c
            jr nz, .m
.nx:        ld a, [btl_k]
            inc a
            cp 4
            jr nz, .t
            ret

; 2F/B909: monsters of each type ($7DCE) and in all ($7DD2)
mon_count:  xor a
            ld [btl_n2], a
            ld c, 0
.t:         ld b, 0
            ld hl, W7 + $7DA7
            ld e, 8
.s:         ld a, [hl+]
            cp c
            jr nz, .n
            inc b
.n:         dec e
            jr nz, .s
            ld a, c
            add a, low(W7 + $7DCE)
            ld l, a
            ld h, high(W7 + $7DCE)
            ld [hl], b
            ld a, [btl_n2]
            add a, b
            ld [btl_n2], a
            inc c
            ld a, c
            cp 4
            jr nz, .t
            ld a, [btl_n2]
            ld [W7 + $7DD2], a
            ret

section wram, $DF80                         ; (WRAM bank 3: FF3 $7F80-, unused in battle)
btl_k:      ds 1
btl_n2:     ds 1
btl_lo:     ds 2
btl_tmp:    ds 4
btl_tmp2:   ds 6
btl_spr:    ds 24
btl_oy:     ds 1
btl_ox:     ds 1
btl_oa:     ds 1
