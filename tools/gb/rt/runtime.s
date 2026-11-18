; GB runtime for recompiled NES code (DMG). See docs/gb-port.md §1-2.
; Register contract: A = 6502 A, E = X (D = 0), C = Y (B = 0), HL scratch.
; Helpers preserve A, F, BC, DE unless noted; reads return the byte in L.
; Symbols from build.py: DATA (GB bank of NES bank 0 data), SHADE_TABLE contents.

STACK_TOP  = $E000
NES_RAM    = $C000          ; $0000-$07FF
EX_RAM     = $C800          ; $5C00-$5FFF
OAM_SH     = $CC00          ; GB shadow OAM (160 bytes)
QH         = $CD00          ; VRAM write queue: address high / low / value pages
QL         = $CE00
QV         = $CF00
NT_SH      = $D000          ; NES nametable shadow (2 × 1KB, vertical mirroring)
PAL_SH     = $D800          ; NES palette RAM shadow (32)
DBG        = $D820          ; fault info: code, HL, SP, stack top
SPR_SLOT   = $D900          ; NES sprite tile (0-255) -> GB slot 0-127, $FF = not resident
SLOT_TILE  = $DA00          ; GB slot -> NES sprite tile ($FF = free)
SLOT_STAMP = $DA80          ; GB slot -> frame number of its last use in OAM
SLOT_KEY   = $D880          ; GB slot -> coding of its tile (SPAL_KEY value; $FF = to load)
SGB_CNT    = $DCC4          ; SGB: cells on screen per NES BG palette
SGB_LSX    = $DCC8          ; SGB: last view position (scroll + camera)
SGB_LSY    = $DCC9
SGB_TICK   = $DCCA
SGB_GP     = $DCCB          ; SGB: GRID write pointer (2)
SPAL_KEY   = $DCC0          ; NES sprite palette -> coding: values of indices 1-3 (2 bits each),
                            ;   bit 6 = OBP1 (DMG); $39 = as is (CGB)
SPR_SHADOW = $A000          ; cart RAM bank 1: all 256 NES sprite tiles in GB format (4KB)
NMI_CNT    = $D830          ; 16-bit count of NES frames (rt_wait_nmi calls), for profiling
VBL_CNT    = $D832          ; 16-bit count of GB frames (vblank or timer ticks)
OWN        = $DD00          ; GB map cell -> nametable that drew it (bit set: nametable 1), 128 bytes
BG_SHADOW  = $B000          ; DMG shading (rt/dmg_shade.s): NES BG tiles, cart RAM bank 1
TILE_PAL   = $DB00          ;   palette each BG tile is coded for
DIRTY_BM   = $DC00          ;   tiles queued for re-coding (bitmap)
PAL_MAP    = $DC20          ;   value of each NES colour index, per palette
RT_BUF     = $DC30          ;   one tile being re-coded
DEFER_BM   = $DCA0          ;   marked tiles parked while no cell uses them (bitmap)
REF_BM     = $DC80          ;   tiles the map uses (bitmap, from dmg_scan_all)
REF_LMAX   = $DC40          ;   brightest BG colour level when the maps were last computed
NGRP       = $DC41          ;   number of values (1-3) the brightness levels were grouped into
LVF        = $DC50          ;   levels present (9)
LSL        = $DC60          ;   levels present, ascending (9)
LVMAP      = $DC70          ;   level -> value (9)
TILE_USE   = $DD80          ;   colour indices each BG tile uses (bit i, a nibble per tile), 128 bytes
GLUM       = $DC7C          ;   value (1-3) -> its brightest level ($DC7D-$DC7F)
PAL_STABLE = 8              ;   frames without palette writes before the maps are recomputed
RETILE_PER_FRAME = 3
LCDC_ON    = %11000011      ; LCD on, window map $9C00 (off), BG tiles $8800 (signed), BG map $9800, OBJ on, BG on
CAM_X      = 48
CAM_Y      = 48

section hram, $FF80
hram_dma:   ds 10
sv_a:       ds 1
fc_bank:    ds 1
code_bank:  ds 1
nes_bank8:  ds 1
data_bank8: ds 1
nes_bankC:  ds 1
data_bankC: ds 1
nzv:        ds 1
vfl:        ds 1
wtmp:       ds 1
tmp_lo:     ds 1
ppu_ctrl:   ds 1
ppu_mask:   ds 1
ppu_latch:  ds 1
ppu_vh:     ds 1
ppu_vl:     ds 1
ppu_rbuf:   ds 1
scroll_x:   ds 1
scroll_y:   ds 1
vbl_flag:   ds 1
frame_flag: ds 1
lcd_on:     ds 1
q_head:     ds 1
q_tail:     ds 1
oam_pending: ds 1
pal_dirty:  ds 1
joy_shift:  ds 1
bgp_v:      ds 1
obp0_v:     ds 1
obp1_v:     ds 1
o_y:        ds 1
o_t:        ds 1
o_a:        ds 1
o_cx:       ds 1
o_key:      ds 1                            ; coding wanted for this sprite's tile
sp_s0:      ds 1
sp_s1:      ds 1
is_sgb:     ds 1                            ; Super Game Boy detected
sgb_wait:   ds 1
sgb_pend:   ds 1
sgb_dirty:  ds 1
sgb_force:  ds 1
sgb_glob:   ds 1
sgb_ptr:    ds 1
sgb_acc:    ds 1
sgb_nacc:   ds 1
sgb_c0:     ds 1
sgb_r0:     ds 1
sgb_nattr:  ds 1
sgb_rb:     ds 1
sgb_ns:     ds 1
sgb_rp:     ds 1
sgb_rx1:    ds 1
sgb_ry1:    ds 1
sgb_ty:     ds 1
fade_drop:  ds 1                            ; DMG: shades the palettes are faded by
spr_next:   ds 1
uw_bank:    ds 1
uw_ret:     ds 2
uw_y:       ds 1
uw_f:       ds 1
oam_frame:  ds 1
split_scy:  ds 1
cam_x:      ds 1                            ; GB view origin in the NES picture (pixels),
cam_y:      ds 1                            ; set by NES writes to $5800/$5801 (tiles)
frames:     ds 1
is_cgb:     ds 1                            ; 1 on a Game Boy Color (CGB mode: NES colours)
rq_any:     ds 1                            ; DMG shading (rt/dmg_shade.s): a tile is marked
rq_pos:     ds 1                            ;   scan position in the dirty bitmap
pal_age:    ds 1                            ;   frames since the last palette write
sh_s0:      ds 1
sh_s1:      ds 1
sh_p0:      ds 1
sh_p1:      ds 1
sh_bk:      ds 1
sh_l1:      ds 1
sh_l2:      ds 1
sh_l3:      ds 1
sh_chg:     ds 1
sh_tile:    ds 1
sh_u1:      ds 1
sh_u2:      ds 1
sh_u3:      ds 1
sh_m0:      ds 1
sh_m1:      ds 1
sh_m2:      ds 1
sh_m3:      ds 1
own1_lo:    ds 1                            ; number of GB map cells drawn by nametable 1
own1_hi:    ds 1
maps_due:   ds 1                            ; DMG: palettes changed since the maps were computed
dmg_scan:   ds 1                            ; DMG: map changed while the LCD was off
sh_same:    ds 1                            ; rt_ppu_w7: cell unchanged (tile and owner)
sh_nt:      ds 1                            ;   nametable being shaded: 0 or 4 (high-byte offset)
ap_chg:     ds 1                            ; attribute write: changed quadrants (bit q)
ap_own:     ds 1                            ; attr_apply: owner bits wanted (0 or $FF)
ap_pal:     ds 4                            ; attr_apply: palette of each quadrant
hram_end:   ds 1

; ------------------------------------------------------------------ vectors
section bank 0, $0000
rt_jp_hl:   jp hl
section bank 0, $0038
            jp rst38_trap                   ; execution ran into $FF bytes: record and stop
section bank 0, $0040
            jp vblank_isr
section bank 0, $0048
            jp stat_isr
section bank 0, $0050
            jp timer_isr
section bank 0, $0100
            nop
            jp boot

; ------------------------------------------------------------------ boot
section bank 0, $0150
boot:       di
            ld sp, STACK_TOP
            push af                         ; A = $11 on a Game Boy Color
.wv:        ldh a, [$FF44]
            cp 144
            jr c, .wv
            xor a
            ldh [$FF40], a                  ; LCD off
            ld hl, $8000                    ; clear VRAM
            ld bc, $2000
            call memclr
            ld hl, $C000                    ; clear WRAM (below the stack)
            ld bc, $1E00
            call memclr
            ld hl, $FE00                    ; clear OAM
            ld bc, $A0
            call memclr
            ld hl, $FF80                    ; clear HRAM
            ld bc, $7F
            call memclr
            pop af
            cp $11
            jr nz, .dmg
            ld a, 1
            ldh [is_cgb], a
            ld a, 1                         ; VRAM bank 1 (attributes) cleared too
            ldh [$FF4F], a
            ld hl, $8000
            ld bc, $2000
            call memclr
            xor a
            ldh [$FF4F], a
            jr .booted
.dmg:       call dmg_init
            call sgb_detect
.booted:
            ld hl, dma_code                 ; OAM DMA routine to HRAM
            ld de, hram_dma
            ld b, 10
.cd:        ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .cd
            ld a, $0A                       ; cart RAM on, RAM bank 0 (NES $6000-$7FFF)
            ld [$0000], a
            xor a
            ld [$4000], a
            ld [$3000], a
            ld hl, SPR_SLOT                 ; sprite tiles 0-127 resident in slots 0-127
            xor a
.sm:        ld [hl+], a
            inc a
            cp 128
            jr nz, .sm
            ld a, $FF
.sm2:       ld [hl+], a
            inc l
            dec l
            jr nz, .sm2
            ld hl, SLOT_KEY                 ; slots: identity coding of the tile loaded
            ld b, 128
            ld a, $39
.sk:        ld [hl+], a
            dec b
            jr nz, .sk
            ld hl, SPAL_KEY
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl], a
            ld hl, SLOT_TILE
            xor a
.st:        ld [hl+], a
            inc a
            cp 128
            jr nz, .st
            ld a, DATA
            ldh [data_bank8], a
            ld a, 62
            ldh [nes_bankC], a
            ld a, DATA + 31
            ldh [data_bankC], a
            ld a, %11100100
            ldh [bgp_v], a
            ldh [$FF47], a
            ldh [obp0_v], a
            ldh [$FF48], a
            ldh [obp1_v], a
            ldh [$FF49], a
            ld a, CAM_X
            ldh [cam_x], a
            ld a, CAM_Y
            ldh [cam_y], a
            call apu_init
            ld a, -68                       ; timer: 4096 Hz / 68 = 60.2 Hz frame tick while the LCD is off
            ldh [$FF06], a
            ldh [$FF05], a
            ld a, %00000100
            ldh [$FF07], a
            ld a, %00000111                 ; IE: vblank + LCD STAT (LYC split) + timer
            ldh [$FFFF], a
            xor a
            ldh [$FF0F], a
            ld de, 0                        ; X = 0 (D = 0), Y = 0 (B = 0)
            ld bc, 0
            ei
            ld a, bank(L_fix_FE2E)
            ldh [code_bank], a
            ld [$2000], a
            xor a
            jp L_fix_FE2E

memclr:     xor a
            ld [hl+], a
            dec bc
            ld a, b
            or c
            jr nz, memclr
            ret

dma_code:   ld a, high(OAM_SH)              ; copied to hram_dma (10 bytes)
            ldh [$FF46], a
            ld a, 40
.w:         dec a
            jr nz, .w
            ret

; ------------------------------------------------------------------ interrupts
vblank_isr: push af                         ; order: OAM, palettes, scroll, then queued VRAM
            push bc                         ;   writes until the last vblank line
            push de
            push hl
            ldh a, [oam_pending]
            and a
            jr z, .no_oam
            xor a
            ldh [oam_pending], a
            call hram_dma
.no_oam:    ldh a, [is_cgb]                 ; CGB palette RAM: only in vblank
            and a
            jr z, .pal_ok
            ldh a, [pal_dirty]
            and a
            call nz, make_palettes
.pal_ok:    ldh a, [bgp_v]
            ldh [$FF47], a
            ldh a, [obp0_v]
            ldh [$FF48], a
            ldh a, [obp1_v]
            ldh [$FF49], a
            ldh a, [cam_x]
            ld b, a
            ldh a, [scroll_x]
            add a, b
            ldh [$FF43], a
            ldh a, [cam_y]                  ; NES rows wrap at 240, the GB map at 256:
            ld b, a
            ldh a, [scroll_y]               ; SCY = (scroll_y + cam_y) mod 240, and an LYC
            add a, b
            jr c, .wr                       ; split where the view reaches NES row 240
            cp 240
            jr c, .sy
.wr:        sub 240
.sy:        ldh [$FF42], a
            ld b, a
            ld a, 240
            sub b
            cp 144
            jr nc, .nosplit
            ldh [$FF45], a
            ld a, b
            add a, 16
            ldh [split_scy], a
            ld a, %01000000
            ldh [$FF41], a
            jr .scy_done
.nosplit:   xor a
            ldh [$FF41], a
.scy_done:  ldh a, [$FF0F]                  ; DMG: the STAT write requested a STAT
            res 1, a                        ;   interrupt; drop it
            ldh [$FF0F], a
            call flush_vbl
            ldh a, [pal_dirty]              ; DMG: the shades for the next frame (the
            and a                           ;   registers are written next vblank)
            call nz, make_palettes
            ld a, 1
            ldh [frame_flag], a
            ld a, $80
            ldh [vbl_flag], a
            ld hl, VBL_CNT
            inc [hl]
            jr nz, .vc
            inc hl
            inc [hl]
.vc:        pop hl
            pop de
            pop bc
            pop af
            reti

stat_isr:   push af                         ; LYC split: skip GB map rows 30-31
            ldh a, [$FF41]                  ; (only on a real LY = LYC match: on the DMG a
            bit 2, a                        ;   STAT write requests a STAT interrupt)
            jr z, .x
            ldh a, [split_scy]
            ldh [$FF42], a
.x:         pop af
            reti

timer_isr:  push af                         ; frame tick while the LCD is off
            ldh a, [lcd_on]
            and a
            jr nz, .x
            ld a, 1
            ldh [frame_flag], a
            ld a, $80
            ldh [vbl_flag], a
            push hl
            ld hl, VBL_CNT
            inc [hl]
            jr nz, .vc
            inc hl
            inc [hl]
.vc:        pop hl
.x:         pop af
            reti

; flush up to B queue entries to VRAM (vblank or LCD off)
flush_q:    ldh a, [q_tail]
            ld d, a
            ldh a, [q_head]
            ld e, a
.lp:        ld a, e
            cp d
            jr z, .done
            ld h, high(QV)
            ld l, e
            ld c, [hl]
            dec h
            ld a, [hl]
            dec h
            ld h, [hl]
            ld l, a
            bit 6, h                        ; $D8-$DB: VRAM bank 1 (CGB attributes)
            jr nz, .b1
            ld [hl], c
.nx:        inc e
            dec b
            jr nz, .lp
.done:      ld a, e
            ldh [q_head], a
            ret
.b1:        res 6, h
            ld a, 1
            ldh [$FF4F], a
            ld [hl], c
            xor a
            ldh [$FF4F], a
            jr .nx

; vblank: queued VRAM writes while the vblank lasts (LY 144-152)
flush_vbl:  ldh a, [q_tail]
            ld d, a
            ldh a, [q_head]
            ld e, a
.lp:        ld a, e
            cp d
            jr z, .done
            ldh a, [$FF44]
            sub 144
            cp 9
            jr nc, .done
            ld h, high(QV)
            ld l, e
            ld c, [hl]
            dec h
            ld a, [hl]
            dec h
            ld h, [hl]
            ld l, a
            bit 6, h
            jr nz, .b1
            ld [hl], c
            inc e
            jr .lp
.b1:        res 6, h
            ld a, 1
            ldh [$FF4F], a
            ld [hl], c
            xor a
            ldh [$FF4F], a
            inc e
            jr .lp
.done:      ld a, e
            ldh [q_head], a
            ret

; NES palette shadow -> DMG palettes (and CGB palette RAM on a Game Boy Color)
make_palettes:
            xor a
            ldh [pal_dirty], a
            ldh a, [is_cgb]
            and a
            call nz, cgb_palettes
            ld hl, PAL_SH
            call pal4
            ld c, a
            ldh a, [is_cgb]
            and a
            ld a, c
            jr nz, .cg
            call dmg_bgp                    ; DMG: shades of the re-coded tile values
            ld c, a
            ldh a, [is_sgb]                 ; SGB: colour numbers
            and a
            ld a, c
            call nz, sgb_bgp
.cg:        ldh [bgp_v], a
            ldh a, [is_cgb]
            and a
            jr z, .dobp
            ld hl, PAL_SH + $10
            call pal4
            ldh [obp0_v], a
            ld hl, PAL_SH + $14
            call pal4
            ldh [obp1_v], a
            ret
.dobp:      ldh a, [is_sgb]
            and a
            jp nz, sgb_obp
            jp dmg_obp
cgb_palettes:                               ; NES palette RAM -> CGB BG / OBJ palettes 0-3
            ld a, $80                       ;   (RGB555 from NES_RGB, $3E00; colour 0 of each
            ldh [$FF68], a                  ;   BG palette is the universal backdrop)
            ld hl, PAL_SH
            ld c, $69
            call .pal16
            ld a, $80
            ldh [$FF6A], a
            ld hl, PAL_SH + $10
            ld c, $6B
.pal16:     ld b, 16
.lp:        ld a, l
            and $03
            ld a, [hl+]
            jr nz, .c
            ld a, [PAL_SH]
.c:         push hl
            and $3F
            add a, a
            ld l, a
            ld h, high(NES_RGB)
            ld a, [hl+]
            ldh [c], a
            ld a, [hl]
            ldh [c], a
            pop hl
            dec b
            jr nz, .lp
            ret

attr_apply:                                 ; A = attribute index i (0-63, + $40: nametable 1):
            push bc                         ;   those of its 4 x 4 cells of the GB map ($9800)
            push de                         ;   that this nametable owns (OWN) get the palette
            push hl                         ;   numbers (VRAM bank 1)
            ld c, a
            and $40
            jr z, .o0
            ld a, $FF
.o0:        ldh [ap_own], a
            ld a, c
            and $40
            rrca
            rrca
            rrca
            rrca
            add a, high(NT_SH) + 3
            ld h, a
            ld a, c
            and $3F
            ld c, a
            add a, $C0
            ld l, a
            ld a, [hl]                      ; the attribute value -> ap_pal[0..3] ($FF: a
            ld hl, ap_pal                   ;   quadrant not in ap_chg, left alone)
            ld b, 4
            ld e, a
            ldh a, [ap_chg]
            ld d, a
.qp:        ld a, e
            and 3
            srl d
            jr c, .qc
            ld a, $FF
.qc:        ld [hl+], a
            ld a, e
            rrca
            rrca
            ld e, a
            dec b
            jr nz, .qp
            ld a, c                         ; DE = OWN byte of (row0, col0): row0 * 4 + col0 / 8
            and $38                         ;   (row0 = (i >> 3) * 4, col0 = (i & 7) * 4)
            rrca
            ld d, a                         ; row0
            add a, a
            add a, a
            ld e, a
            ld a, c
            and 7
            srl a
            or e
            ld e, a
            ld a, c                         ; bit shift of col0 in the byte: 0 or 4
            and 1
            ld a, 0
            jr z, .sb
            ld a, 4
.sb:        ld b, a
            ld a, d                         ; HL = $9800 + row0 * 32 + col0
            and 7
            swap a
            add a, a
            ld l, a
            ld a, d
            srl a
            srl a
            srl a
            add a, $98
            ld h, a
            ld a, c
            and 7
            add a, a
            add a, a
            or l
            ld l, a
            ld d, high(OWN)
            ld c, 0                         ; row in the block (0-3)
.r:         push de
            ld a, [de]                      ; owner bits of the 4 cells -> low nibble
            bit 2, b
            jr z, .sd
            swap a
.sd:        ld e, a
            ldh a, [ap_own]
            xor e
            cpl                             ; bit set: owned by this nametable
            ld e, a
            ld a, c                         ; quadrant row: (row & 2)
            and 2
            push bc
            ld b, a                         ; 0 or 2: index of the left quadrant
            ld c, 4                         ; 4 cells
.c:         push bc
            ld a, c                         ; column in block = 4 - C; right half when C <= 2
            cp 3
            ld a, b
            jr nc, .lft
            inc a
.lft:       push hl
            ld hl, ap_pal
            add a, l
            ld l, a
            ld a, [hl]
            pop hl
            bit 0, e
            jr z, .sk
            cp $FF
            call nz, vram_put1
.sk:        inc hl
            srl e
            pop bc
            dec c
            jr nz, .c
            pop bc
            ld a, l                         ; next row: +32 - 4
            add a, 28
            ld l, a
            jr nc, .nh
            inc h
.nh:        pop de
            ld a, e
            add a, 4
            ld e, a
            inc c
            ld a, c
            cp 4
            jr nz, .r
            pop hl
            pop de
            pop bc
            ret

; A = old XOR new attribute byte -> A = bit q set for each quadrant q that changed
quad_mask:  push bc
            ld c, a
            ld b, 0
            and $03
            jr z, .q1
            set 0, b
.q1:        ld a, c
            and $0C
            jr z, .q2
            set 1, b
.q2:        ld a, c
            and $30
            jr z, .q3
            set 2, b
.q3:        ld a, c
            and $C0
            jr z, .q4
            set 3, b
.q4:        ld a, b
            pop bc
            ret

; HL = GB map address, A = value for VRAM bank 1: written now (LCD off) or queued
; (address high + $40 marks bank 1 for flush_q). Keeps all registers but F.
vram_put1:  push af
            ldh a, [lcd_on]
            and a
            jr nz, .q
            ld a, 1
            ldh [$FF4F], a
            pop af
            ld [hl], a
            push af
            xor a
            ldh [$FF4F], a
            pop af
            ret
.q:         pop af
            push hl
            set 6, h
            call vram_put
            pop hl
            ret

; rt_ppu_w7 nametable cell write: B:L = offset (B 0-3), C = 4 for nametable 1. Marks the
; owner of the GB map cell; on a Game Boy Color a change of owner re-applies the cell's
; attribute byte (of its new nametable). Keeps all registers.
own_set:    push af
            ld a, c                         ; nametable 0 and no cell drawn by nametable 1:
            and a                           ;   nothing to do
            jr nz, .full
            ldh a, [own1_lo]
            and a
            jr nz, .full
            ldh a, [own1_hi]
            and a
            jr nz, .full
            pop af
            ret
.full:      push bc
            push de
            push hl
            push hl                         ; mask of bit (col & 7)
            ld a, l
            and 7
            ld hl, BIT_MASK
            add a, l
            ld l, a
            jr nc, .nc
            inc h
.nc:        ld e, [hl]
            pop hl
            ld a, l                         ; byte = B * 32 + L / 8
            rrca
            rrca
            rrca
            and $1F
            ld d, a
            ld a, b
            swap a
            add a, a
            or d
            push hl
            ld l, a
            ld h, high(OWN)
            ld a, [hl]
            and e
            ld d, a                         ; old bit
            ld a, c
            and a
            jr z, .z
            ld a, [hl]
            or e
            ld [hl], a
            ld a, d
            and a
            pop hl
            jr nz, .x                       ; 1 -> 1
            ldh a, [own1_lo]                ; 0 -> 1
            add a, 1
            ldh [own1_lo], a
            ldh a, [own1_hi]
            adc a, 0
            ldh [own1_hi], a
            jr .chg
.z:         ld a, e
            cpl
            and [hl]
            ld [hl], a
            ld a, d
            and a
            pop hl
            jr z, .x                        ; 0 -> 0
            ldh a, [own1_lo]                ; 1 -> 0
            sub 1
            ldh [own1_lo], a
            ldh a, [own1_hi]
            sbc a, 0
            ldh [own1_hi], a
.chg:       xor a                           ; owner changed: the cell is not unchanged
            ldh [sh_same], a
            ldh a, [is_cgb]
            and a
            jr z, .x
            ld a, c                         ; CGB: this cell's palette from its new nametable
            ldh [sh_nt], a
            ld a, l
            and 31
            ld e, a                         ; col
            ld a, l
            swap a
            rrca
            and 7
            ld d, a
            ld a, b
            add a, a
            add a, a
            add a, a
            or d                            ; row
            call cell_pal
            push hl
            ld e, a
            ld a, b
            add a, $98
            ld h, a                         ; HL = $9800 + offset
            ld a, e
            call vram_put1
            pop hl
.x:         pop hl
            pop de
            pop bc
            pop af
            ret

pal4:       ; HL -> 4 NES colours ($x0 = universal backdrop) -> DMG palette byte
            ld c, 0
            ld b, 4
            ld a, [PAL_SH]                  ; index 0 is always the backdrop
            jr .first
.lp:        ld a, [hl]
.first:     inc hl
            push hl
            and $3F
            ld l, a
            ld h, high(shade_tab)
            ld a, [hl]                      ; shade 0-3
            pop hl
            or c
            rrca
            rrca
            ld c, a
            dec b
            jr nz, .lp
            ld a, c
            ret

; ------------------------------------------------------------------ frame wait (JSR $FE00)
rt_wait_nmi:
            push af
            push hl
            ld hl, NMI_CNT
            inc [hl]
            jr nz, .nc
            inc hl
            inc [hl]
.nc:        pop hl
            ldh a, [is_cgb]
            and a
            call z, dmg_frame
            ldh a, [is_sgb]
            and a
            call nz, sgb_frame
            xor a
            ldh [frame_flag], a
.w:         halt
            ldh a, [frame_flag]
            and a
            jr z, .w
            ld a, [NES_RAM + $FF]           ; NMI handler: LDA $FF / STA $2000 / LDA $2002
            call rt_ppu_w0
            call rt_ppu_r2
            pop af
            ld a, $FE                       ; then PLA x3: A = $FE (N=1, Z=0), carry kept
            ldh [nzv], a
            inc a
            dec a
            ret

dmg_frame:                                  ; DMG shading, once per NES frame with the LCD
            ldh a, [lcd_on]                 ;   on (with it off, all of it when it goes on):
            and a                           ;   palette maps once the palettes have been
            ret z                           ;   stable for PAL_STABLE frames, then re-code a
            push bc                         ;   few marked tiles
            ldh a, [pal_age]
            cp 255
            jr z, .a
            inc a
            ldh [pal_age], a
            cp PAL_STABLE
            jr nz, .a
            ldh a, [maps_due]
            and a
            jr z, .a
            call dmg_maps_now
.a:         ld b, RETILE_PER_FRAME
            call dmg_retile_some
            pop bc
            ret
dmg_maps_now:
            xor a
            ldh [maps_due], a
            ld a, 1
            ldh [sgb_dirty], a
            call dmg_maps
            ld a, 1                         ; BGP again with the new maps
            ldh [pal_dirty], a
            ret

; ------------------------------------------------------------------ PPU registers
rt_ppu_w0:  ldh [ppu_ctrl], a
            ret
rt_ppu_w1:  push af
            push bc
            push de
            push hl
            ldh [ppu_mask], a
            and $18
            jr z, .off
            ldh a, [lcd_on]
            and a
            jr nz, .ret
            ld b, 0                         ; flush everything (LCD still off)
            call flush_q
            ldh a, [is_cgb]
            and a
            jr nz, .lon
            ldh a, [maps_due]               ; DMG: palette maps now if the palettes changed
            and a                           ;   since they were last computed
            call nz, dmg_maps_now
            ldh a, [dmg_scan]               ; DMG: tiles' palettes from the whole map if it
            and a                           ;   was drawn with the LCD off, then re-code the
            jr z, .nsc                      ;   marked tiles it uses (else all marked tiles)
            call dmg_scan_all               ;   while the LCD is still off
            call dmg_retile_ref
            jr .lon
.nsc:       ld b, 0
            call dmg_retile_some
.lon:       ld a, LCDC_ON
            ldh [$FF40], a
            ld a, 1
            ldh [lcd_on], a
            jr .ret
.off:       ldh a, [lcd_on]
            and a
            jr z, .ret
            ldh a, [is_sgb]
            and a
            call nz, sgb_lcd_off
.wv:        ldh a, [$FF44]
            cp 144
            jr c, .wv
            xor a
            ldh [$FF40], a
            ldh [lcd_on], a
            ld b, 0
            call flush_q
.ret:       pop hl
            pop de
            pop bc
            pop af
            ret

rt_ppu_r2:  push af
            ldh a, [vbl_flag]
            ld l, a
            xor a
            ldh [vbl_flag], a
            ldh [ppu_latch], a
            pop af
            ret

rt_ppu_w5:  push af
            ldh a, [ppu_latch]
            xor 1
            ldh [ppu_latch], a
            jr z, .y
            pop af
            ldh [scroll_x], a
            ret
.y:         pop af
            ldh [scroll_y], a
            ret

rt_ppu_w6:  push af
            ldh a, [ppu_latch]
            xor 1
            ldh [ppu_latch], a
            jr z, .lo
            pop af
            push af
            and $3F
            ldh [ppu_vh], a
            pop af
            ret
.lo:        pop af
            ldh [ppu_vl], a
            ret

rt_ppu_w3:
rt_ppu_w4:
rt_ppu_w2:  ret
rt_ppu_r0:
rt_ppu_r1:
rt_ppu_r3:
rt_ppu_r4:
rt_ppu_r5:
rt_ppu_r6:  ld l, 0
            ret

; v += 1 or 32
ppu_inc:    ldh a, [ppu_ctrl]
            and 4
            ld a, 1
            jr z, .one
            ld a, 32
.one:       ld h, a
            ldh a, [ppu_vl]
            add a, h
            ldh [ppu_vl], a
            ldh a, [ppu_vh]
            adc a, 0
            and $3F
            ldh [ppu_vh], a
            ret

rt_ppu_w7:  push af
            push bc
            push de
            push hl
            ld d, a                         ; D = value
            ldh a, [ppu_vh]
            ld h, a
            ldh a, [ppu_vl]
            ld l, a
            ld a, h
            cp $20
            jr nc, .nt
            ; ---- pattern tables: GB byte offset in the tile (plane 0 rows -> even, plane 1 -> odd)
            ld a, l
            and $0F
            cp 8
            jr c, .p0
            sub 8
            add a, a
            inc a
            jr .pk
.p0:        add a, a
.pk:        ld c, a
            ld a, l
            and $F0
            or c
            ld l, a
            ld a, h
            cp $10
            jr nc, .spr
            ldh a, [is_cgb]
            and a
            jr nz, .bgv
            ld a, h                         ; DMG: the BG tile goes to the shadow; the tile is
            add a, high(BG_SHADOW)          ;   re-coded for its palette later
            ld h, a
            ld a, 1
            ld [$4000], a
            ld [hl], d
            xor a
            ld [$4000], a
            ld a, h
            sub high(BG_SHADOW)
            swap a
            ld b, a
            ld a, l
            swap a
            and $0F
            or b
            call dmg_mark
            jp .done
.bgv:       ld a, h
            cp $08                          ; BG tiles 0-127 at $9000, 128-255 at $8800
            ld c, $90
            jr c, .bg0
            ld c, $80
.bg0:       and $0F
            add a, c
            ld h, a
            jr .vram
.spr:       ; sprite table: write the shadow (RAM bank 1); the slot too if the tile is resident
            and $0F
            ld b, a                         ; tile high nibble
            add a, high(SPR_SHADOW)
            ld h, a
            ld a, 1
            ld [$4000], a
            ld [hl], d
            xor a
            ld [$4000], a
            ld a, b                         ; tile = (v >> 4) & $FF
            swap a
            ld b, a
            ld a, l
            swap a
            and $0F
            or b
            ld c, l                         ; keep the byte offset
            ld l, a
            ld h, high(SPR_SLOT)
            ld a, [hl]
            cp $FF
            jr z, .done
            add a, low(SLOT_KEY)            ; resident: loaded again (coded) by the next
            ld l, a                         ;   OAM conversion
            ld h, high(SLOT_KEY)
            ld [hl], $FF
            jr .done
.nt:        cp $3F
            jr z, .pal
            and $07                         ; $2000-$2FFF (+ mirror $3000): vertical mirroring
            ld b, a                         ; b = (v >> 8) & 7: bit 2 = nametable, bits 0-1 = offset high
            and $04
            ld c, a                         ; nametable 1 -> +$400 in the shadow
            ld a, b
            and $03
            ld b, a
            or c
            add a, high(NT_SH)
            ld h, a
            ld a, b
            cp $03
            jr nz, .map0
            ld a, l
            cp $C0
            jr c, .map0
            ld a, [hl]                      ; attribute byte: nothing to do if unchanged;
            xor d                           ;   ap_chg = quadrants whose palette changed
            jr z, .done
            call quad_mask
            ldh [ap_chg], a
            ld [hl], d
            ld a, c                         ; attribute table: shadow; CGB: the 16 cells'
            swap a                          ;   palette numbers in VRAM bank 1; DMG: their
            ld b, a                         ;   tiles' shading. A = index (0-63) + $40 for
            ld a, l                         ;   nametable 1
            sub $C0
            or b
            ld b, a
            ldh a, [is_cgb]
            and a
            ld a, b
            jr z, .dat
            call attr_apply
            jr .done
.dat:       ldh a, [lcd_on]                 ; (LCD off: the scan when it goes on)
            and a
            ld a, b
            jr nz, .dat2
            ld a, 1
            ldh [dmg_scan], a
            jr .done
.dat2:      call dmg_attr
            jr .done
.map0:      ld a, [hl]                      ; shadow copy; sh_same = 1 if the cell had this tile
            sub d
            ld a, 0
            jr nz, .df
            inc a
.df:        ldh [sh_same], a
            ld [hl], d
.map:       call own_set                    ; this nametable now owns the GB map cell
            ldh a, [is_cgb]
            and a
            jr nz, .map2
            ldh a, [sh_same]                ; DMG: the cell's tile shaded for its palette
            and a                           ;   (unless tile and owner are unchanged; with
            jr nz, .map2                    ;   the LCD off, once for the whole map when it
            ldh a, [lcd_on]                 ;   goes on)
            and a
            jr nz, .mcell
            inc a
            ldh [dmg_scan], a
            jr .map2
.mcell:
            push bc                         ;   (B = offset high + 4 for nametable 1)
            ld a, b
            or c
            ld b, a
            ld a, d
            call dmg_cell
            pop bc
.map2:      ld a, b
            add a, $98
            ld h, a
.vram:      ldh a, [lcd_on]
            and a
            jr nz, .queue
            ld [hl], d
            jr .done
.queue:     ldh a, [q_tail]
            ld e, a
            inc a
            ld b, a
.full:      ldh a, [q_head]
            cp b
            jr nz, .room
            halt                            ; queue full: wait for the vblank flush
            jr .full
.room:      ld a, l
            ld c, h
            ld h, high(QH)
            ld l, e
            ld [hl], c
            inc h
            ld [hl], a
            inc h
            ld [hl], d
            ld a, b
            ldh [q_tail], a
            jr .done
.pal:       ld a, l
            and $1F
            ld l, a
            and $13
            cp $10
            ld a, l
            jr nz, .pn
            and $0F
.pn:        ld l, a
            ld h, high(PAL_SH)
            ld a, d
            and $3F
            cp [hl]                         ; same colour again: nothing changes
            jr z, .done
            ld [hl], a
            ld a, 1
            ldh [pal_dirty], a
            ldh [maps_due], a
            xor a
            ldh [pal_age], a
.done:      call ppu_inc
            pop hl
            pop de
            pop bc
            pop af
            ret

rt_ppu_r7:  push af                         ; buffered read (nametables from the shadow)
            push bc
            ldh a, [ppu_rbuf]
            ld l, a
            push hl
            ldh a, [ppu_vh]
            cp $20
            jr c, .zero
            cp $3F
            jr z, .zero
            and $07
            ld h, a
            ldh a, [ppu_vl]
            ld l, a
            ld a, h
            and $04
            ld b, a
            ld a, h
            and $03
            or b
            add a, high(NT_SH)
            ld h, a
            ld a, [hl]
            jr .set
.zero:      xor a
.set:       ldh [ppu_rbuf], a
            call ppu_inc
            pop hl
            pop bc
            pop af
            ret

; ------------------------------------------------------------------ OAM DMA ($4014)
rt_io_w4014:
            push af
            push bc
            push de
            push hl
            push af
            ldh a, [oam_frame]
            inc a
            ldh [oam_frame], a
            pop af
            and $07
            add a, high(NES_RAM)
            ld h, a
            ld l, 0
            ld de, OAM_SH
            ld b, 64
            ld c, 40
.lp:        ld a, [hl+]                     ; NES y (top - 1)
            ldh [o_y], a
            ld a, [hl+]
            ldh [o_t], a
            ld a, [hl+]
            ldh [o_a], a
            ldh a, [cam_x]
            sub 8
            ldh [o_cx], a
            ld a, [hl+]                     ; NES x
            push bc
            ld b, a
            ldh a, [o_cx]
            ld c, a
            ld a, b
            sub c
            pop bc
            jr c, .skip
            cp 168
            jr nc, .skip
            push af
            ldh a, [o_y]
            cp $EF
            jr nc, .skip_p
            push bc
            ld b, a
            ldh a, [cam_y]
            sub 17
            ld c, a
            ld a, b
            sub c                           ; GB y = NES y + 1 - cam_y + 16
            pop bc
            jr c, .skip_p
            cp 160
            jr nc, .skip_p
            ld [de], a
            inc e
            pop af
            ld [de], a
            inc e
            push hl
            ldh a, [o_a]                    ; coding of the sprite's palette
            and 3
            add a, low(SPAL_KEY)
            ld l, a
            ld h, high(SPAL_KEY)
            ld a, [hl]
            ldh [o_key], a
            ldh a, [o_t]
            ld l, a
            ld h, high(SPR_SLOT)
            ld a, [hl]
            cp $FF
            call z, spr_alloc
            push af                         ; resident with another coding: load it again
            add a, low(SLOT_KEY)
            ld l, a
            ld h, high(SLOT_KEY)
            ldh a, [o_key]
            cp [hl]
            jr z, .kok
            pop af
            push af
            push bc
            ld c, a
            call spr_load
            pop bc
.kok:       pop af
            ld l, a
            ld h, high(SLOT_STAMP)
            set 7, l
            ldh a, [oam_frame]
            ld [hl], a
            res 7, l
            ld a, l
            pop hl
            ld [de], a
            inc e
            ldh a, [o_a]                    ; NES: v h p - - - pp  -> GB: p v h pal - - - -
            push bc
            ld b, a
            and $C0                         ; v h
            rrca
            ld c, a                         ; -> bits 6,5
            ld a, b
            and $20                         ; priority -> bit 7
            rlca
            rlca
            or c
            ld c, a
            ldh a, [o_key]                  ; DMG: OBP1 if the coding says so
            and $40
            rrca
            rrca
            or c
            ld c, a
            ld a, b
            and $03                         ; CGB: OBJ palette = NES palette (ignored on DMG)
            or c
            pop bc
            ld [de], a
            inc e
            dec c
            jr z, .full
            jr .skip
.skip_p:    pop af
.skip:      dec b
            jr nz, .lp
.full:      ld a, c                         ; hide the unused GB sprites
            and a
            jr z, .end
            xor a
.clr:       ld [de], a
            inc e
            ld [de], a
            inc e
            inc e
            inc e
            dec c
            jr nz, .clr
.end:       ld a, 1
            ldh [oam_pending], a
            pop hl
            pop de
            pop bc
            pop af
            ret

; NES sprite tile o_t is not resident: take the next slot not used by this frame's
; sprites, load the tile from the shadow, return A = slot. Keeps BC, DE, HL.
spr_alloc:  push bc
            push de
            push hl
            ld b, 128
.find:      ldh a, [spr_next]
            inc a
            and $7F
            ldh [spr_next], a
            ld l, a
            ld h, high(SLOT_STAMP)
            set 7, l
            ldh a, [oam_frame]
            cp [hl]
            jr nz, .got
            dec b
            jr nz, .find
            ldh a, [spr_next]               ; all slots busy this frame: reuse anyway
            ld l, a
.got:       res 7, l                        ; L = slot
            ld h, high(SLOT_TILE)
            ld a, [hl]                      ; evict the old tile
            cp $FF
            jr z, .free
            push hl
            ld l, a
            ld h, high(SPR_SLOT)
            ld [hl], $FF
            pop hl
.free:      ldh a, [o_t]
            ld [hl], a                      ; SLOT_TILE[slot] = tile
            ld c, l
            ld l, a
            ld h, high(SPR_SLOT)
            ld [hl], c                      ; SPR_SLOT[tile] = slot
            call spr_load
            ld a, c
            pop hl
            pop de
            pop bc
            ret

; C = slot: load NES sprite tile o_t into it from the shadow, coded with o_key (the value
; of each colour index); SLOT_KEY[slot] = o_key. Keeps all registers.
spr_load:   push af
            push bc
            push de
            push hl
            ld a, c
            add a, low(SLOT_KEY)
            ld l, a
            ld h, high(SLOT_KEY)
            ldh a, [o_key]
            ld [hl], a
            ld b, a                         ; plane sets: sp_s0 = indices whose value has
            ld d, 0                         ;   bit 0, sp_s1 = bit 1 (index 0 -> 0)
            ld e, 0
            bit 0, b
            jr z, .k1
            set 1, d
.k1:        bit 1, b
            jr z, .k2
            set 1, e
.k2:        bit 2, b
            jr z, .k3
            set 2, d
.k3:        bit 3, b
            jr z, .k4
            set 2, e
.k4:        bit 4, b
            jr z, .k5
            set 3, d
.k5:        bit 5, b
            jr z, .k6
            set 3, e
.k6:        ld a, d
            ldh [sp_s0], a
            ld a, e
            ldh [sp_s1], a
            ldh a, [o_t]                    ; DE = shadow $A000 + tile * 16 (RAM bank 1)
            swap a
            ld b, a
            and $F0
            ld e, a
            ld a, b
            and $0F
            add a, high(SPR_SHADOW)
            ld d, a
            ld a, c                         ; HL = VRAM $8000 + slot * 16
            swap a
            ld b, a
            and $F0
            ld l, a
            ld a, b
            and $0F
            add a, $80
            ld h, a
            ld b, 8
.row:       ld a, 1
            ld [$4000], a
            ld a, [de]
            inc de
            ldh [sh_p0], a
            ld a, [de]
            inc de
            ldh [sh_p1], a
            xor a
            ld [$4000], a
            call row_masks
            ldh a, [sp_s0]
            call mask_comb
            call vram_put
            inc hl
            ldh a, [sp_s1]
            call mask_comb
            call vram_put
            inc hl
            dec b
            jr nz, .row
            pop hl
            pop de
            pop bc
            pop af
            ret

; ------------------------------------------------------------------ joypad / APU / MMC5
rt_io_w4016:
            push af
            push hl
            call read_buttons
            ldh [joy_shift], a
            pop hl
            pop af
            ret
rt_io_r4016:
            push af
            ldh a, [joy_shift]
            ld l, a
            scf
            rra
            ldh [joy_shift], a
            ld a, l
            and 1
            or $40
            ld l, a
            pop af
            ret
read_buttons:                               ; A = A B Sel St U D L R (bit 0..7), 1 = pressed
            ld a, $20
            ldh [$FF00], a
            ldh a, [$FF00]
            ldh a, [$FF00]
            cpl
            and $0F
            ld h, a                         ; R L U D
            ld a, $10
            ldh [$FF00], a
            ldh a, [$FF00]
            ldh a, [$FF00]
            ldh a, [$FF00]
            ldh a, [$FF00]
            cpl
            and $0F
            ld l, a                         ; A B Sel St
            ld a, $30
            ldh [$FF00], a
            ld a, l
            bit 2, h
            jr z, .u
            or $10
.u:         bit 3, h
            jr z, .d
            or $20
.d:         bit 1, h
            jr z, .l
            or $40
.l:         bit 0, h
            ret z
            or $80
            ret
rt_io_r4015:
rt_io_r4017:
rt_io_rnone:
            ld l, 0
            ret

rt_mmc_w5115:
            push af
            and $7F
            srl a
            ldh [nes_bank8], a
            add a, DATA
            ldh [data_bank8], a
            pop af
            ret
rt_mmc_w5800:                               ; camera X in tiles (GB layout code; bit 7 is
            push af                         ;   no longer used)
            and $1F
            add a, a
            add a, a
            add a, a
            ldh [cam_x], a
            pop af
            ret
rt_mmc_w5801:                               ; camera Y in tiles
            push af
            add a, a
            add a, a
            add a, a
            ldh [cam_y], a
            pop af
            ret
rt_mmc_w5116:
            push af
            and $7F
            ldh [nes_bankC], a
            srl a
            add a, DATA
            ldh [data_bankC], a
            pop af
            ret

; ------------------------------------------------------------------ ROM data reads
; HL = GB address of the byte in the NES bank's data image; returns L.
rt_rd_8:    push af
            ldh a, [data_bank8]
            ld [$2000], a
            ld l, [hl]
            ldh a, [code_bank]
            ld [$2000], a
            pop af
            ret
rt_rd_c:    push af
            ldh a, [data_bankC]
            ld [$2000], a
            ld l, [hl]
            ldh a, [code_bank]
            ld [$2000], a
            pop af
            ret
rt_rd_e:    push af
            ld a, DATA + 31
            ld [$2000], a
            ld l, [hl]
            ldh a, [code_bank]
            ld [$2000], a
            pop af
            ret

; ------------------------------------------------------------------ indirect access
rt_izy_rd:  push af                         ; L = zp pointer; byte at ptr+Y -> L
            ld h, high(NES_RAM)
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            add hl, bc
            call nes_rd
            pop af
            ret
rt_izx_rd:  push af                         ; L = zp; pointer at (zp + X)
            ld a, l
            add a, e
            ld l, a
            ld h, high(NES_RAM)
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            call nes_rd
            pop af
            ret
rt_izy_wr:  push af                         ; L = zp pointer; A -> ptr+Y
            ldh [wtmp], a
            ld h, high(NES_RAM)
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            add hl, bc
            call nes_wr
            pop af
            ret
rt_izx_wr:  push af
            ldh [wtmp], a
            ld a, l
            add a, e
            ld l, a
            ld h, high(NES_RAM)
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            call nes_wr
            pop af
            ret

nes_rd:     ld a, h                         ; HL = NES address -> L (A, F clobbered)
            cp $20
            jr nc, .n1
            and $07
            or high(NES_RAM)
            ld h, a
            ld l, [hl]
            ret
.n1:        cp $60
            jr c, .low
            cp $80
            jr nc, .rom
            add a, $40                      ; save RAM $6000 -> $A000
            ld h, a
            ld l, [hl]
            ret
.rom:       cp $C0
            jr nc, .romc
            sub $40
            ld h, a
            jp rt_rd_8
.romc:      cp $E0
            jr nc, .rome
            sub $80
            ld h, a
            jp rt_rd_c
.rome:      sub $80
            ld h, a
            jp rt_rd_e
.low:       cp $5C
            jr c, .io
            add a, $6C                      ; ExRAM $5C00 -> $C800
            ld h, a
            ld l, [hl]
            ret
.io:        ld a, 3
            jp rt_fault

nes_wr:     ld a, h                         ; HL = NES address, value in wtmp (A, F clobbered)
            cp $20
            jr nc, .n1
            and $07
            or high(NES_RAM)
            ld h, a
            ldh a, [wtmp]
            ld [hl], a
            ret
.n1:        cp $60
            jr c, .low
            cp $80
            ret nc
            add a, $40
            ld h, a
            ldh a, [wtmp]
            ld [hl], a
            ret
.low:       cp $5C
            jr c, .io
            add a, $6C
            ld h, a
            ldh a, [wtmp]
            ld [hl], a
            ret
.io:        ld a, 4
            jp rt_fault

; ------------------------------------------------------------------ arithmetic with V
rt_adc_v:   ld h, a                         ; A + L + C -> A, Z/C; vfl bit 6 = overflow
            adc a, l
            push af
            xor h
            ld h, a                         ; res ^ A
            pop af
            push af
            xor l                           ; res ^ M
            and h
            rra
            ldh [vfl], a
            pop af
            ret
rt_sbc_v:   ld h, a                         ; 6502 SBC = A + ~M + C (carry in 6502 polarity)
            ld a, l
            cpl
            ld l, a
            ld a, h
            jr rt_adc_v

; ------------------------------------------------------------------ timing loops
; DEY / BNE (or DEX / BNE) to itself: n iterations take 5n NES cycles = 2.93n GB
; M-cycles; this waits about that long (loop of 4 M-cycles, 0.75n times) and leaves
; the register at 0 with Z = 1, carry kept.
rt_delay_c: push af
            ld a, c
            call delay_n
            pop af
            ld c, 0
            inc c
            dec c
            ret
rt_delay_e: push af
            ld a, e
            call delay_n
            pop af
            ld e, 0
            inc e
            dec e
            ret
delay_n:    and a
            jr nz, .n
            ld a, 192
            jr .lp
.n:         ld l, a
            srl l
            srl l
            sub l
            ret z
.lp:        dec a
            jr nz, .lp
            ret

; ------------------------------------------------------------------ 6502 status byte
rt_get_p:   ; A = P (N from nzv, V from vfl, Z/C from F, bits 4-5 set). F kept, HL used.
            push af
            ld h, $30
            jr nc, .c0
            set 0, h
.c0:        jr nz, .z0
            set 1, h
.z0:        ldh a, [nzv]
            and $80
            or h
            ld h, a
            ldh a, [vfl]
            and $40
            or h
            ld h, a
            pop af
            ld a, h
            ret
rt_set_p:   ; flags from P in A (A kept): nzv, vfl, GB Z and C
            ldh [nzv], a
            ldh [vfl], a
            ld h, a
            ld l, 0
            bit 1, h
            jr z, .z
            set 7, l
.z:         bit 0, h
            jr z, .c
            set 4, l
.c:         push hl
            pop af
            ret

; ------------------------------------------------------------------ banking / dispatch
rt_farcall: ; HL = target, fc_bank = its bank; A, F, BC, DE pass both ways
            ldh [sv_a], a
            ldh a, [code_bank]
            push af
            ldh a, [fc_bank]
            ldh [code_bank], a
            ld [$2000], a
            ldh a, [sv_a]
            call rt_jp_hl
rt_farcall_ret:
            ldh [sv_a], a
            pop hl
            ld a, h
            ldh [code_bank], a
            ld [$2000], a
            ldh a, [sv_a]
            ret

; HL = NES address -> HL = GB address, fc_bank = GB bank (A, F, BC, DE kept)
lookup:     push af
            push bc
            push de
            ld d, h
            ld e, l
            ld a, d
            cp $80
            jr c, .any
            cp $C0
            jr nc, .ck
            ldh a, [nes_bank8]
            jr .key
.ck:        cp $E0
            jr nc, .any
            ldh a, [nes_bankC]
            jr .key
.any:       ld a, $FF
.key:       ld c, a
            ld hl, dyn_table
.lp:        ld a, [hl+]
            cp e
            jr nz, .n1
            ld a, [hl+]
            cp d
            jr nz, .n2
            ld a, [hl+]
            cp c
            jr nz, .n3
            ld a, [hl+]
            ldh [fc_bank], a
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            pop de
            pop bc
            pop af
            ret
.n1:        cp $FF                          ; end marker ($FF $FF)
            jr nz, .s1
            ld a, [hl]
            cp $FF
            jr z, .miss
.s1:        inc hl
.n2:        inc hl
.n3:        inc hl
            inc hl
            inc hl
            jr .lp
.miss:      ld h, d
            ld l, e
            ld a, 1
            jp rt_fault

rt_dyn_call:
            call lookup
            jp rt_farcall
rt_dyn_jump:                                ; HL = NES address
            call lookup
            push af
            push bc
            ldh a, [fc_bank]
            ld b, a
            ldh a, [code_bank]
            cp b
            pop bc
            jr nz, .far
            pop af
            jp hl
.far:       pop af                          ; another bank: call it, so that its RTS
            call rt_farcall                 ; comes back here and the bank is restored
            ret

rt_jmp_ind:                                 ; JMP (ind): HL = GB address of the pointer
            push af
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            pop af
            jp rt_dyn_jump

rt_jmp_ind_nes:                             ; JMP (ind) with the pointer at NES address HL
            push af
            push hl
            call nes_rd
            ld a, l
            ldh [tmp_lo], a
            pop hl
            inc hl
            call nes_rd
            ld h, l
            ldh a, [tmp_lo]
            ld l, a
            pop af
            jp rt_dyn_jump

rt_rts_dispatch:                            ; PHA hi / PHA lo / RTS -> jump to (hi:lo) + 1
            ldh [sv_a], a
            pop hl
            ld a, h
            ldh [tmp_lo], a
            pop hl
            ldh a, [tmp_lo]
            ld l, a
            inc hl
            ldh a, [sv_a]
            jp rt_dyn_jump

; Drop N NES return frames from the GB stack, then return to the caller. Farcall frames
; (rt_farcall_ret + saved bank) and bank-0 stub frames are not NES frames; if a farcall
; frame is dropped, a synthetic one is pushed back so that the next RTS still restores
; the bank the remaining frames run in.
rt_unwind1: ldh [sv_a], a                   ; PLA PLA dropping one return address: A, F kept
            push af
            pop hl
            ld a, l
            ldh [uw_f], a
            ld a, 1
            jr rt_unwind_a
rt_unwind3: ldh [sv_a], a                   ; TSX ... TXS idiom: 3 frames, then CLC
            xor a
            ldh [uw_f], a
            ld a, 3
rt_unwind_a:
            ld b, a
            ld a, c
            ldh [uw_y], a
            pop hl
            ld a, l
            ldh [uw_ret], a
            ld a, h
            ldh [uw_ret + 1], a
            xor a
            ldh [uw_bank], a
.lp:        pop hl
            ld a, h
            cp high(rt_farcall_ret)
            jr nz, .nfc
            ld a, l
            cp low(rt_farcall_ret)
            jr nz, .nfc
            pop hl                          ; saved bank (H)
            ld a, h
            ldh [uw_bank], a
            jr .lp
.nfc:       ld a, h
            cp $40
            jr c, .lp                       ; bank-0 stub return: not an NES frame
            dec b
            jr nz, .lp
            ldh a, [uw_bank]
            and a
            jr z, .res
            ld h, a
            ld l, 0
            push hl
            ld hl, rt_farcall_ret
            push hl
.res:       ldh a, [uw_y]
            ld c, a
            ld b, 0
            ldh a, [uw_ret]
            ld l, a
            ldh a, [uw_ret + 1]
            ld h, a
            push hl                         ; resume address for the final ret
            ldh a, [uw_f]
            ld l, a
            ldh a, [sv_a]
            ld h, a
            push hl
            pop af
            ret

; ------------------------------------------------------------------ faults
; code 1 = no dynamic target (HL = NES address), 2 = uncompiled code reached
; (caller on the stack), 3/4 = indirect read/write of I/O (HL = NES address)
rt_fatal:   ld a, 2
rt_fault:   di
            ld [DBG], a
            ld a, l
            ld [DBG + 1], a
            ld a, h
            ld [DBG + 2], a
            ld [DBG + 3], sp
            pop hl
            ld a, l
            ld [DBG + 5], a
            ld a, h
            ld [DBG + 6], a
            ldh a, [code_bank]
            ld [DBG + 7], a
rt_halted:  jr rt_halted

; rst $38 (opcode $FF) reached: DBG+8 = SP, DBG+10.. = 8 stack words; then stop
BIT_MASK:   db 1, 2, 4, 8, 16, 32, 64, 128

rst38_trap: di
            ld [DBG + 8], sp
            ld hl, sp + 0
            ld de, DBG + 10
            ld b, 16
.c:         ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .c
            ld a, $38
            ld [DBG], a
.s:         halt
            jr .s
