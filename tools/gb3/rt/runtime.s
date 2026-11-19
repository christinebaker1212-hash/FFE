; FF3 Game Boy Color runtime for the translated NES code (tools/gb3/translate.py).
; CGB only (header flag $C0): double speed, NES colours, two VRAM banks. See
; docs/ff3-gb-plan.md §2-3. The CPU-side helpers (banking, dispatch, flags, stack tricks)
; are copied from FF2's tools/gb2/rt/runtime.s and adapted; the PPU layer is new.
;
; Register contract: A = 6502 A, E = X (D = 0), C = Y (B = 0), HL scratch.
; Helpers preserve A, F, BC, DE unless noted; reads return the byte in L.
; Symbols from build.py: DATA (GB bank of NES 8KB banks 0/1), RT_TABLES.
;
; Tiles: NES pattern table 0 = VRAM bank 0 $8000-$8FFF, table 1 = VRAM bank 1 $8000-$8FFF
; (unsigned addressing for BG and sprites); each BG map cell / sprite picks the table with
; the CGB bank bit. NES nametables -> GB map $9800 (column x, row y; with horizontal
; mirroring the second nametable continues at row 30, mod 32). NES palette RAM -> CGB
; palettes 0-3 (BG) and 0-3 (OBJ) through NES_RGB.

STACK_TOP  = $D000          ; GB stack $CD00-$CFFF (the NES stack runs on it; FF3 keeps data in
                            ;   page 1 at $0100-$0161, so the stack stays out of NES RAM), outside
                            ;   the switchable WRAM bank $D000-$DFFF
NES_RAM    = $C000          ; $0000-$07FF
EX_RAM     = $C800          ; $5C00-$5FFF
OAM_SH     = $CC00          ; GB shadow OAM (160 bytes)
PAL_SH     = $CCA0          ; NES palette RAM (32)
TILE_DIRTY = $CCC0          ; NES tiles written since their last copy to VRAM (bit per tile, 64;
                            ;   must end at $CCFF: hd_flush stops when L wraps)
STAGE      = $D000          ; NES pattern tables in GB format: table 0 in WRAM bank 2, table 1
                            ;   in bank 3 (copied to VRAM by DMA in the vblank, hd_flush)
NT_SH      = $D000          ; NES nametables (2 x 1KB after mirroring), WRAM bank 1
DBG        = $D820          ; fault info: code, HL, SP, stack top (16)  (the addresses FF1's
NMI_CNT    = $D830          ; 16-bit count of NES frame waits             test runners read:
VBL_CNT    = $D832          ; 16-bit count of GB frames                   tools/gb/gambatte/
WAIT_CNT   = $D834          ; 16-bit count of NES frames the main thread waited for (tools/gb3/firstdiff.py)
TEST_PAD   = $D83E          ; $A5: test runner input mode (later)         gbrun.c)
LK_TAB     = $DA00          ; dynamic-target lookup cache (512 bytes, WRAM bank 1; lookup)
PC_BUF     = $CD00          ; rt_ppu_copy: one piece (<= 32 bytes; the stack's far end, never reached)
NC_BUF     = $CD40          ; nat_chr64: 64 bytes for a nametable destination
MAP_SH     = $D000          ; GB map (VRAM bank 0 $9800-$9BFF) and its attributes (VRAM bank 1),
ATTR_SH    = $D400          ;   1KB each, in WRAM bank MAP_BANK; dirty rows copied by DMA in the
MAP_BANK   = 5              ;   vblank (map_flush)
DYN_BANK   = 127            ; ROM bank of the dynamic-target table (translate.py)
LCDC_ON    = %10010011      ; LCD on, window map $9800 (off), BG/window tiles $8000 (unsigned),
                            ;   BG map $9800, 8x8 OBJ on, BG priority on
CAM_X      = 48             ; default camera (pixels): the centre of the NES picture
CAM_Y      = 48

section hram, $FF80
hram_dma:   ds 10
sv_a:       ds 1
fc_bank:    ds 1
code_bank:  ds 1
nes_bank8:  ds 1                            ; NES 8KB bank at $8000 ($5114) / $A000 ($5115)
nes_bankA:  ds 1
data_bank8: ds 1                            ; GB bank holding it, and $20 if it is odd
data_bankA: ds 1                            ;   (the upper half of the GB bank)
odd8:       ds 1
oddA:       ds 1
nzv:        ds 1
vfl:        ds 1
wtmp:       ds 1
tmp_lo:     ds 1
ppu_ctrl:   ds 1
ppu_mask:   ds 1
ppu_latch:  ds 1
ppu_vh:     ds 1
ppu_vl:     ds 1
ppu_th:     ds 1                            ; $2006 first write
ppu_rbuf:   ds 1
ppu_stat:   ds 1                            ; $2002 bit 7 (set at vblank, cleared by a read)
scroll_x:   ds 1
scroll_y:   ds 1
mirror:     ds 1                            ; 0 vertical ($5105 = $44), 1 horizontal ($50)
bg_bank:    ds 1                            ; BG pattern table the attributes carry (0 / 8)
map_dirty:  ds 4                            ; GB map rows written (bit per row) /
attr_dirty: ds 4                            ;   attribute rows written
map_any:    ds 1                            ; a bit is set in map_dirty / attr_dirty
wc_n:       ds 1                            ; $2007 write cache: cells left in the current map row
wc_nl:      ds 1                            ;   (increment 1), the next cell's NT_SH and MAP_SH
wc_nh:      ds 1                            ;   addresses (0 = slow path)
wc_ml:      ds 1
wc_mh:      ds 1
wv:         ds 1
wc_inc:     ds 1                            ; the cached run's step: 1 or 32
tm_lo:      ds 1                            ; CHR tile marked last (L & $F0, H; H = $FF: none)
tm_hi:      ds 1
mr_lo:      ds 1                            ; GB map row marked last ($2007 writes: L & $E0, H)
mr_hi:      ds 1
frame_tick: ds 1
oam_pending: ds 1
oam_end:    ds 1                            ; OAM_SH slots in use after the last conversion (low byte)
pal_dirty:  ds 1
shown:      ds 1                            ; palettes shown: 1 normal, 0 black (rendering off)
chr_dirty:  ds 1                            ; a bit is set in TILE_DIRTY
joy_shift:  ds 1
joy_state:  ds 1
irq_line:   ds 1                            ; MMC5 $5203 / $5204 (scanline IRQ)
irq_en:     ds 1
async_req:  ds 1                            ; asynchronous NES interrupts due: bit 0 NMI (set by
                                            ;   the vblank while $0100 holds a JMP and NMIs are
                                            ;   on), bit 1 IRQ (armed by the NMI handler); run
                                            ;   at the next safe point (rt_async)
nmi_pend:   ds 1                            ; NMIs due (vblanks since the handler last ran; the
                                            ;   handler runs once for each: none is dropped)
in_async:   ds 1                            ; rt_async is running a handler
in_wait:    ds 1                            ; rt_wait_nmi is waiting (its NMI counts a frame)
in_irq:     ds 1                            ; running the NES IRQ handler: $2000 / $2005 are
spl_ctrl:   ds 1                            ;   the split's values (below irq_line)
spl_x:      ds 1
spl_y:      ds 1
spl_latch:  ds 1
cam_x:      ds 1
cam_y:      ds 1
uw_bank:    ds 1
uw_ret:     ds 2
uw_y:       ds 1
uw_f:       ds 1
o_cnt:      ds 1
o_cx:       ds 1
c_x:        ds 1                            ; attribute writes: cell / quadrant work
c_val:      ds 1
c_q:        ds 1
nt_x:       ds 1                            ; native routines (rt/native.s): saved X, A
nt_a:       ds 1
nt_y:       ds 1
cp_dl:      ds 1                            ; rt_copy_n: destination (GB), count
cp_dh:      ds 1
cp_n:       ds 1
n9_y:       ds 1                            ; nat_9111: y offset, attributes, x offset
n9_at:      ds 1
n9_x:       ds 1
ch_n:       ds 1                            ; chr64_fast: bytes (16 / 32 / 48 / 64)
hram_end:   ds 1

; ------------------------------------------------------------------ vectors
section bank 0, $0000
rt_jp_hl:   jp hl
section bank 0, $0038
            jp rst38_trap                   ; execution ran into $FF bytes: record and stop
section bank 0, $0040
            jp vblank_isr
section bank 0, $0048
            reti
section bank 0, $0100
            nop
            jp boot

; ------------------------------------------------------------------ boot
section bank 0, $0150
boot:       di
            ld sp, STACK_TOP
            cp $11                          ; A = $11 on a Game Boy Color
            jr z, .cgb
.dmg:       halt                            ; (Color-only cartridge: stop on other models)
            jr .dmg
.cgb:       ld a, 1                         ; double speed (KEY1 + STOP, interrupts off)
            ldh [rKEY1], a
            xor a
            ldh [rIE], a
            ld a, $30
            ldh [rP1], a
            stop
.wv:        ldh a, [rLY]
            cp 144
            jr c, .wv
            xor a
            ldh [rLCDC], a                  ; LCD off (only here, at power-on)
            ld a, 1
            ldh [rVBK], a
            ld hl, $8000                    ; clear both VRAM banks
            ld bc, $2000
            call memclr
            xor a
            ldh [rVBK], a
            ld hl, $8000
            ld bc, $2000
            call memclr
            ld hl, $C000                    ; clear WRAM (not the stack $CF00-$CFFF in use)
            ld bc, $0F00
            call memclr
            ld a, 4                         ; WRAM bank 4: zeros (DMA source, map clears)
            ldh [rSVBK], a
            ld hl, $D000
            ld bc, $1000
            call memclr
            ld a, MAP_BANK                  ; GB map / attribute shadows
            ldh [rSVBK], a
            ld hl, $D000
            ld bc, $1000
            call memclr
            ld a, 1
            ldh [rSVBK], a
            ld hl, $D000
            ld bc, $1000
            call memclr
            ld hl, $FE00                    ; clear OAM
            ld bc, $A0
            call memclr
            ld hl, $FF80                    ; clear HRAM
            ld bc, $7F
            call memclr
            ld a, $FF                       ; (no CHR tile marked yet)
            ldh [tm_hi], a
            ld hl, dma_code                 ; OAM DMA routine to HRAM
            ld de, hram_dma
            ld b, 10
.cd:        ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .cd
            ld a, $0A                       ; cart RAM on, RAM bank 0 (NES $6000-$7FFF)
            ld [MBC5_RAMG], a
            xor a
            ld [MBC5_RAMB], a
            ld [MBC5_BANKH], a
            ld a, CAM_X
            ldh [cam_x], a
            ld a, CAM_Y
            ldh [cam_y], a
            ld a, $7F                       ; MMC5 power-on: last bank everywhere
            call rt_mmc_w5114
            call rt_mmc_w5115
            call black_palettes
            xor a
            ldh [rSCX], a
            ldh [rSCY], a
            ldh [rIF], a
            ld a, LCDC_ON
            ldh [rLCDC], a
            ld a, 1                         ; vblank interrupt only
            ldh [rIE], a
            ld de, 0
            ld bc, 0
            ld a, CODE_BANK0
            ldh [code_bank], a
            ld [MBC5_BANKL], a
            ei
            ld hl, RESET_NES                ; the NES reset vector (translated)
            call rt_dyn_call
.stop:      halt
            jr .stop

memclr:     xor a                           ; HL = start, BC = count
            ld [hl+], a
            dec bc
            ld a, b
            or c
            jr nz, memclr
            ret

dma_code:   ld a, high(OAM_SH)              ; copied to HRAM: OAM DMA
            ldh [rDMA], a
            ld a, 40
.w:         dec a
            jr nz, .w
            ret

; ------------------------------------------------------------------ vblank
vblank_isr: push af
            push hl
            ldh a, [oam_pending]
            and a
            jr z, .no_oam
            xor a
            ldh [oam_pending], a
            call hram_dma
.no_oam:    ldh a, [ppu_mask]               ; NES rendering off: black palettes, no sprites
            and $18
            jr nz, .on
            ldh a, [shown]
            and a
            jr z, .pal_done
            xor a
            ldh [shown], a
            push bc
            call black_palettes
            pop bc
            jr .pal_done
.on:        ldh a, [shown]
            and a
            jr z, .pal
            ldh a, [pal_dirty]
            and a
            jr z, .pal_done
.pal:       ld a, 1
            ldh [shown], a
            xor a
            ldh [pal_dirty], a
            push bc
            push de
            call load_palettes
            pop de
            pop bc
.pal_done:  ldh a, [ppu_mask]               ; sprites shown (NES mask bit 4)
            and $10
            ld a, LCDC_ON
            jr nz, .obj
            and $FD
.obj:       ldh [rLCDC], a
            ldh a, [ppu_ctrl]               ; scroll: NES scroll + camera
            ld h, a
            ldh a, [scroll_x]
            ld l, a
            ldh a, [cam_x]
            add a, l
            ldh [rSCX], a
            ldh a, [mirror]                 ; vertical mirroring: rows 0-29 of the map;
            and a                           ; horizontal: nametable 2/3 from row 30 (mod 32)
            ld a, 0
            jr z, .v
            bit 1, h
            jr z, .v
            ld a, 240
.v:         ld l, a
            ldh a, [scroll_y]
            add a, l
            ld l, a
            ldh a, [cam_y]
            add a, l
            ldh [rSCY], a
            ldh a, [map_any]                ; staged map / attribute rows -> VRAM
            and a
            jr z, .nmc
            push bc
            push de
            ldh a, [rSVBK]
            push af
            ld a, MAP_BANK
            ldh [rSVBK], a
            xor a
            ldh [map_any], a
            ldh [mr_hi], a                  ; (row marks gone: forget the last marked row and
            ldh [wc_n], a                   ;   the cached run)
            ld hl, map_dirty
            ld d, high(MAP_SH)
            ld e, 0
            call map_flush
            ld hl, attr_dirty
            ld d, high(ATTR_SH)
            ld e, 1
            call map_flush
            xor a
            ldh [rVBK], a
            pop af
            ldh [rSVBK], a
            pop de
            pop bc
.nmc:       ldh a, [chr_dirty]              ; staged tiles -> VRAM
            and a
            jr z, .nchr
            push bc
            push de
            ldh a, [rSVBK]
            push af
            call hd_flush
            pop af
            ldh [rSVBK], a
            pop de
            pop bc
.nchr:      ldh a, [ppu_ctrl]               ; asynchronous NMI (battle / cutscenes): $0100 = JMP
            bit 7, a                        ;   and NMIs on: run the handler at the next safe
            jr z, .nn                       ;   point
            ld a, [NES_RAM + $100]
            cp $4C
            jr nz, .nn
            ldh a, [nmi_pend]
            cp 8
            jr nc, .nn
            inc a
            ldh [nmi_pend], a
            ldh a, [async_req]
            or 1
            ldh [async_req], a
.nn:        ld a, 1
            ldh [frame_tick], a
            ld a, $80
            ldh [ppu_stat], a
            ldh a, [rSVBK]                  ; (VBL_CNT is in WRAM bank 1: the main thread may
            push af                         ;   have a staging bank selected)
            ld a, 1
            ldh [rSVBK], a
            ld hl, VBL_CNT
            inc [hl]
            jr nz, .c
            inc hl
            inc [hl]
.c:         pop af
            ldh [rSVBK], a
            pop hl
            pop af
            reti

; CGB palettes from the NES palette RAM (BG 0-3: universal colour + 3; OBJ 0-3)
load_palettes:
            ld a, $80
            ldh [rBCPS], a
            ld de, PAL_SH
            ld c, 4
.bg:        ld a, [PAL_SH]
            call put_col_bg
            inc de
            ld b, 3
.bgc:       ld a, [de]
            call put_col_bg
            inc de
            dec b
            jr nz, .bgc
            dec c
            jr nz, .bg
            ld a, $80
            ldh [rOCPS], a
            ld c, 4
.ob:        ld a, [PAL_SH]
            call put_col_ob
            inc de
            ld b, 3
.obc:       ld a, [de]
            call put_col_ob
            inc de
            dec b
            jr nz, .obc
            dec c
            jr nz, .ob
            ret
put_col_bg: and $3F                         ; A = NES colour -> BCPD (2 bytes)
            add a, a
            ld l, a
            ld h, high(NES_RGB)
            ld a, [hl+]
            ldh [rBCPD], a
            ld a, [hl]
            ldh [rBCPD], a
            ret
put_col_ob: and $3F
            add a, a
            ld l, a
            ld h, high(NES_RGB)
            ld a, [hl+]
            ldh [rOCPD], a
            ld a, [hl]
            ldh [rOCPD], a
            ret
black_palettes:                             ; all CGB palettes black
            ld a, $80
            ldh [rBCPS], a
            ldh [rOCPS], a
            xor a
            ld b, 64
.l:         ldh [rBCPD], a
            ldh [rOCPD], a
            dec b
            jr nz, .l
            ret

; ------------------------------------------------------------------ frame waits
; wait for the next vblank (the NES NMI); A, F, BC, DE kept
wait_vbl:   push af
            xor a
            ldh [frame_tick], a
.w:         halt
            ldh a, [frame_tick]
            and a
            jr z, .w
            ld hl, NMI_CNT
            inc [hl]
            jr nz, .c
            inc hl
            inc [hl]
.c:         ld hl, WAIT_CNT
            inc [hl]
            jr nz, .c2
            inc hl
            inc [hl]
.c2:        pop af
            ret

; run the NES IRQ handler if the scanline IRQ is armed (it would have fired in the frame
; that just ran): through the RAM vector $0103 (JMP). A, F, BC, DE kept.
run_irq:    ldh a, [irq_en]
            and a
            ret z
            ld a, [NES_RAM + $103]
            cp $4C
            ret nz
            push af
            push bc
            push de
            ld a, 1
            ldh [in_irq], a
            ld a, [NES_RAM + $104]
            ld l, a
            ld a, [NES_RAM + $105]
            ld h, a
            call rt_dyn_call                ; (its RTI = ret)
            xor a
            ldh [in_irq], a
            pop de
            pop bc
            pop af
            ret

; Asynchronous NES interrupts at a safe point of the translated code (ROM data reads,
; joypad reads, cross-bank returns, the wait idioms): the NMI handler through $0100, then
; on a later call the IRQ it armed (through $0103). Everything is preserved (registers,
; the 6502 flag bytes and the helpers' scratch bytes in HRAM).
rt_async:   push af
            ldh a, [in_async]
            and a
            jr nz, .busy
            push bc
            push de
            push hl
            ldh a, [nzv]
            push af
            ldh a, [vfl]
            push af
            ldh a, [sv_a]
            push af
            ldh a, [wtmp]
            push af
            ldh a, [tmp_lo]
            push af
            ld a, 1
            ldh [in_async], a
            ld de, 0
            ld bc, 0
            ldh a, [async_req]
            bit 1, a                        ; (an IRQ still due from the last frame first)
            jr nz, .irq
            ldh a, [nmi_pend]
            dec a
            ldh [nmi_pend], a
            jr nz, .more
            ldh a, [async_req]
            and $FE
            ldh [async_req], a
.more:
            ld hl, NMI_CNT                  ; an NES frame (the input clock of the test runners)
            inc [hl]
            jr nz, .c0
            inc hl
            inc [hl]
.c0:        ldh a, [in_wait]                ; a frame the main thread waited for ($FB80): an
            and a                           ;   equivalence point
            jr z, .c
            ld hl, WAIT_CNT
            inc [hl]
            jr nz, .cnt
            inc hl
            inc [hl]
.cnt:       xor a
            ldh [in_wait], a
.c:         ld a, [NES_RAM + $101]
            ld l, a
            ld a, [NES_RAM + $102]
            ld h, a
            call rt_dyn_call                ; (RTI = ret)
            ldh a, [irq_en]                 ; the IRQ it armed: at the next safe point
            and a
            jr z, .done
            ldh a, [async_req]
            or 2
            ldh [async_req], a
            jr .done
.irq:       and $FD
            ldh [async_req], a
            call run_irq
.done:      xor a
            ldh [in_async], a
            pop af
            ldh [tmp_lo], a
            pop af
            ldh [wtmp], a
            pop af
            ldh [sv_a], a
            pop af
            ldh [vfl], a
            pop af
            ldh [nzv], a
            pop hl
            pop de
            pop bc
.busy:      pop af
            ret

; $FF36 (wait for vblank): returns like the NES stub $FF2A (RTI back in $0100, $2002 read,
; A = $FF from the dropped interrupt frame; N and Z from it, C kept)
rt_wait_ff36:
            call run_irq
            call wait_vbl
            ld a, $40
            ld [NES_RAM + $100], a
            xor a
            ldh [ppu_latch], a
            ldh [ppu_stat], a
            ld a, $FF
            ldh [nzv], a
            inc a
            dec a
            ret

; $FB80 idiom (INC $05 / wait until the NMI handler clears it): the handler runs from the
; vblank's request; then LDA $05 (N, Z). C kept.
rt_wait_nmi:
            push af
            ld hl, NES_RAM + $05
            inc [hl]
.lp:        ldh a, [async_req]
            and a
            jr z, .chk
            ld a, 1
            ldh [in_wait], a
            call rt_async
            xor a
            ldh [in_wait], a
            ld a, [NES_RAM + $05]           ; (cleared: done; else run what is still due
            and a                           ;   before halting: an IRQ ran first, the NMI
            jr nz, .lp                      ;   is due too)
.chk:
            ld a, [NES_RAM + $05]
            and a
            jr z, .done
            halt
            jr .lp
.done:      pop af
            ld a, [NES_RAM + $05]
            ldh [nzv], a
            inc a
            dec a
            ret

; $FB79 idiom (INC $00 / wait until the IRQ handler clears it). C kept.
rt_wait_irq:
            push af
            ld hl, NES_RAM + $00
            inc [hl]
.lp:        ldh a, [async_req]
            and a
            jr z, .chk
            call rt_async
            ld a, [NES_RAM + $00]
            and a
            jr nz, .lp
.chk:       ld a, [NES_RAM + $00]
            and a
            jr z, .done
            halt
            jr .lp
.done:      pop af
            ld a, [NES_RAM + $00]
            ldh [nzv], a
            inc a
            dec a
            ret

; $F809 idiom (NOP / DEY delay until the battle bg is drawn): no wait; Y = 0, Z = 1
rt_bgwait:  ld c, 0
            push af
            xor a
            ldh [nzv], a
            pop af
            inc c
            dec c
            ret

; ------------------------------------------------------------------ PPU registers
rt_ppu_w0:  push af                         ; $2000
            ldh a, [in_irq]
            and a
            jr nz, .split
            xor a
            ldh [wc_n], a                   ; (increment may change: no cached run)
            pop af
            ldh [ppu_ctrl], a
            push af
            and $10                         ; BG pattern table -> attribute bank bit
            rrca
            push hl
            ld hl, bg_bank
            cp [hl]
            jr z, .same
            ld [hl], a
            call rebank_attrs
.same:      pop hl
            pop af
            ret
.split:     pop af
            ldh [spl_ctrl], a
            ret
rt_ppu_w1:  ldh [ppu_mask], a               ; $2001
            ret
rt_ppu_r2:  push af                         ; $2002: vblank flag (cleared), latch reset
            ldh a, [ppu_stat]
            ld l, a
            xor a
            ldh [ppu_stat], a
            ldh [ppu_latch], a
            pop af
            ret
rt_ppu_w5:  push af                         ; $2005
            ldh a, [in_irq]
            and a
            jr nz, .split
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
.split:     ldh a, [spl_latch]
            xor 1
            ldh [spl_latch], a
            jr z, .sy
            pop af
            ldh [spl_x], a
            ret
.sy:        pop af
            ldh [spl_y], a
            ret
rt_ppu_w6:  push af                         ; $2006
            ldh a, [ppu_latch]
            xor 1
            ldh [ppu_latch], a
            jr z, .lo
            pop af
            ldh [ppu_th], a
            ret
.lo:        pop af
            ldh [ppu_vl], a
            push af
            xor a
            ldh [wc_n], a                   ; (new address: no cached run)
            ldh a, [ppu_th]
            and $3F
            ldh [ppu_vh], a
            pop af
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

; VRAM address in HL (ppu_vh / vl), then advance it by 1 or 32 ($2000 bit 2)
ppu_addr_inc:
            ldh a, [ppu_vl]
            ld l, a
            ldh a, [ppu_vh]
            ld h, a
            push hl
            ldh a, [ppu_ctrl]
            and 4
            ld a, 1
            jr z, .one
            ld a, 32
.one:       add a, l
            ldh [ppu_vl], a
            ld a, h
            adc a, 0
            and $3F
            ldh [ppu_vh], a
            pop hl
            ret

; VRAM writes with the LCD on: wait until the PPU is out of mode 3 (modes 0 / 1 / 2 follow
; for at least 80 dots), interrupts off around it. vput0 / vput1: A -> [HL] in VRAM bank 0 / 1.
vput0:      push af
            di
            xor a
            ldh [rVBK], a
            jr vput_go
vput1:      push af
            di
            ld a, 1
            ldh [rVBK], a
vput_go:
.w:         ldh a, [rSTAT]
            and 2
            jr nz, .w
            pop af
            ld [hl], a
            ei
            ret

rt_ppu_w7:
            ldh [wv], a                     ; $2007 write
            push af
            di                              ; (fast path: a run of cells in one map row, after
            ldh a, [wc_n]                   ;   a slow write set it up; the vblank flush
            and a                           ;   clears it)
            jr z, .slow0
            dec a
            ldh [wc_n], a
            push hl
            push de
            ldh a, [wc_inc]
            ld e, a
            cp 2
            jr z, .fchr
            ldh a, [wc_nl]                  ; nametable shadow (WRAM bank 1)
            ld l, a
            add a, e
            ldh [wc_nl], a
            ldh a, [wc_nh]
            ld h, a
            adc a, 0
            ldh [wc_nh], a
            ldh a, [wv]
            ld [hl], a
            ldh a, [wc_ml]                  ; map shadow (WRAM bank MAP_BANK; wraps in 1KB)
            ld l, a
            add a, e
            ldh [wc_ml], a
            ldh a, [wc_mh]
            ld h, a
            adc a, 0
            res 2, a
            ldh [wc_mh], a
            ld a, MAP_BANK
            ldh [rSVBK], a
            ldh a, [wv]
            ld [hl], a
            ld a, 1
            ldh [rSVBK], a
            ei
.adv:       ldh a, [ppu_vl]                 ; PPU address + the step
            add a, e
            ldh [ppu_vl], a
            jr nc, .fv
            ldh a, [ppu_vh]
            inc a
            and $3F
            ldh [ppu_vh], a
.fv:        pop de
            pop hl
            pop af
            ret
.fchr:      ldh a, [wc_ml]                  ; CHR run (step 2 marks it): the next byte of the
            ld l, a                         ;   tile straight into the staging copy (tile
            ldh a, [wc_mh]                  ;   marked when the run was set up; the vblank's
            ld h, a                         ;   hd_flush ends the run)
            ldh a, [wc_nl]                  ; (WRAM bank 2 / 3)
            ldh [rSVBK], a
            ldh a, [wv]
            ld [hl], a
            ld a, 1
            ldh [rSVBK], a
            ld a, l                         ; staging offset: plane 0 bytes 0, 2 .. 14, then
            and $0F                         ;   plane 1 bytes 1, 3 .. 15
            cp 14
            ld a, l
            jr z, .fp1
            add a, 2
            jr .fst
.fp1:       sub 13
.fst:       ldh [wc_ml], a
            ei
            ld e, 1
            jr .adv
.slow0:     ei
            push bc
            push de
            ldh a, [wv]
            ld c, a
            ldh a, [ppu_vl]                 ; HL = NES VRAM address, then advance it (1 / 32)
            ld l, a
            ld e, a
            ldh a, [ppu_vh]
            ld h, a
            ld d, a
            ldh a, [ppu_ctrl]
            bit 2, a
            jr nz, .i32
            inc de
            jr .ist
.i32:       ld a, e
            add a, 32
            ld e, a
            jr nc, .ist
            inc d
.ist:       ld a, e
            ldh [ppu_vl], a
            ld a, d
            and $3F
            ldh [ppu_vh], a
            ld a, h
            cp $20
            jr c, .chr
            cp $3F
            jr z, .pal
            and $0F                         ; nametable: n = (H >> 2) & 3
            rrca
            rrca
            and 3
            ld b, a
            ldh a, [mirror]
            and a
            ld a, b
            jr z, .vm
            srl a                           ; horizontal: 2/3 -> nametable 1
            jr .nt
.vm:        and 1                           ; vertical: 1/3 -> nametable 1
.nt:        ld b, a                         ; B = nametable 0 / 1
            ld a, h
            and 3
            ld h, a                         ; HL = offset in the nametable (0-$3FF)
            push hl
            ld a, b
            add a, a
            add a, a
            add a, h
            add a, high(NT_SH)
            ld h, a
            ld a, [hl]                      ; (old value: attribute writes compare)
            ldh [c_q], a
            ld [hl], c                      ; shadow
            inc hl                          ; (next cell's shadow address, for the cache)
            ld a, l
            ldh [wc_nl], a
            ld a, h
            ldh [wc_nh], a
            pop hl
            ld a, h
            cp 3
            jr nz, .cell
            ld a, l
            cp $C0
            jr nc, .attr
.cell:      call cell_map                   ; HL = GB map address of the cell
            ld a, h                         ; -> MAP_SH (WRAM bank MAP_BANK) first, then the row
            sub $98 - high(MAP_SH)          ;   mark (a vblank flush in between then copies the
            ld d, a                         ;   value or forgets the mark: never a lost write)
            ld e, l
            ld a, MAP_BANK
            ldh [rSVBK], a
            ld a, c
            ld [de], a
            ld a, 1
            ldh [rSVBK], a
            ld a, l                         ; row already marked last time: skip
            and $E0
            ld e, a
            ldh a, [mr_lo]
            cp e
            jr nz, .mk
            ldh a, [mr_hi]
            cp h
            jr z, .cache
.mk:        ld a, e
            ldh [mr_lo], a
            ld a, h
            ldh [mr_hi], a
            call map_mark
.cache:     ldh a, [ppu_ctrl]               ; increment 1: the rest of this map row goes the
            and 4                           ;   fast way; increment 32: the rest of the column
            jr nz, .c32                     ;   down to NES row 29 (its rows marked now)
            ld a, 1
            ldh [wc_inc], a
            ld a, l
            and 31
            xor 31
            jr z, .done
            ldh [wc_n], a
            ld a, l
            inc a
            ldh [wc_ml], a
            ld a, h
            sub $98 - high(MAP_SH)
            ldh [wc_mh], a
            jr .done
.c32:       ldh a, [wc_nl]                  ; NES row of this cell = (shadow offset >> 5) & 31
            sub 1                           ;   (wc_nl / wc_nh hold this cell's + 1)
            ld e, a
            ldh a, [wc_nh]
            sbc a, 0
            and 3
            ld d, a
            ld a, e
            and $E0
            or d
            swap a
            rrca                            ; A = row (bits: D[1:0] E[7:5])
            and 31
            cp 29
            jr nc, .done
            ld d, a
            ld a, 29
            sub d
            ldh [wc_n], a                   ; cells left below in this nametable's cell area
            ld b, a
            ldh a, [wc_nl]                  ; next NES cell = this + 32
            add a, 31
            ldh [wc_nl], a
            ldh a, [wc_nh]
            adc a, 0
            ldh [wc_nh], a
            ld a, 32
            ldh [wc_inc], a
            ld a, l                         ; next map cell = this + 32 (wrapping in the map)
            add a, 32
            ld l, a
            ld a, h
            adc a, 0
            and $9B
            ld h, a
            ld a, l
            ldh [wc_ml], a
            ld a, h
            sub $98 - high(MAP_SH)
            ldh [wc_mh], a
.pm:        push bc                         ; mark the rows of the run
            push hl
            call map_mark
            pop hl
            pop bc
            ld a, l
            add a, 32
            ld l, a
            ld a, h
            adc a, 0
            and $9B
            ld h, a
            dec b
            jr nz, .pm
            xor a                           ; (row cache: unknown now)
            ldh [mr_hi], a
            jr .done
.attr:      ld a, l
            sub $C0
            ld l, a
            ld a, c
            call attr_apply                 ; L = attribute index, A = value, B = nametable
            jr .done
.chr:       di                              ; CHR: into the staging copy; with step 1 the
            call chr_put                    ;   rest of the tile goes the fast way (set up
            ldh a, [ppu_ctrl]               ;   with interrupts off: a vblank flush between
            and 4                           ;   the mark and the run would lose the run's
            jr nz, .chx                     ;   writes)
            ld a, l
            and $0F
            cp 15
            jr z, .chx
            ld d, a                         ; D = byte k of the tile
            ld a, 15
            sub d
            ld b, a                         ; B = bytes left in the tile
            ld a, d
            inc a                           ; staging offset of byte k + 1
            cp 8
            jr c, .c0
            sub 8
            add a, a
            inc a
            jr .c1
.c0:        add a, a
.c1:        ld d, a
            ld a, l
            and $F0
            or d
            ldh [wc_ml], a
            ld a, h
            and $10
            swap a
            add a, 2
            ldh [wc_nl], a
            ld a, h
            and $0F
            or high(STAGE)
            ldh [wc_mh], a
            ld a, 2
            ldh [wc_inc], a
            ld a, b
            ldh [wc_n], a
.chx:       ei
            jr .done
.pal:       ld a, l                         ; palette RAM ($3F10/14/18/1C = $3F00/04/08/0C)
            and $1F
            ld l, a
            and $13
            cp $10
            jr nz, .pk
            ld a, l
            and $0F
            ld l, a
.pk:        ld h, high(PAL_SH)
            ld a, l
            add a, low(PAL_SH)
            ld l, a
            ld a, c
            and $3F
            ld [hl], a
            ld a, 1
            ldh [pal_dirty], a
.done:      pop de
            pop bc
            pop af
            ret

; NES CHR byte C at NES address HL ($0000-$1FFF) -> staging copy (WRAM bank 2 / 3, GB
; row order: byte k of a tile -> 2k, k - 8 -> 2(k - 8) + 1), tile marked for the vblank's
; DMA. A, F, B, D, E, HL clobbered (rt_ppu_w7 keeps them); C kept.
chr_put:    push hl                         ; store first, then mark (a vblank flush in
            call chr_store                  ;   between copies the byte or forgets the mark)
            pop hl
            ld a, l                         ; same tile as the last mark: done
            and $F0
            ld b, a
            ldh a, [tm_lo]
            cp b
            jr nz, .mk
            ldh a, [tm_hi]
            cp h
            ret z
.mk:        ld a, b
            ldh [tm_lo], a
            ld a, h
            ldh [tm_hi], a
            jp tile_mark
; mark the tile of NES CHR address HL dirty (A, F, B, D, E clobbered; HL, C kept)
tile_mark:  ld a, h                         ; dirty byte = tile >> 3 = H * 2 + (L >> 7)
            and $1F
            add a, a
            bit 7, l
            jr z, .i
            inc a
.i:         add a, low(TILE_DIRTY)
            ld e, a
            ld d, high(TILE_DIRTY)
            ld a, l                         ; bit = (L >> 4) & 7
            swap a
            and 7
            ld b, a
            ld a, 1
            inc b
.sh:        dec b
            jr z, .m
            add a, a
            jr .sh
.m:         push hl
            ld h, d
            ld l, e
            or [hl]
            ld [hl], a
            pop hl
            ld a, 1
            ldh [chr_dirty], a
            ret
chr_store:  ld a, l                         ; byte k -> GB offset
            and $0F
            cp 8
            jr c, .lo8
            sub 8
            add a, a
            inc a
            jr .k
.lo8:       add a, a
.k:         ld d, a
            ld a, l
            and $F0
            or d
            ld l, a
            ld a, h
            and $10                         ; table -> WRAM bank 2 / 3
            swap a
            add a, 2
            ld b, a
            ld a, h
            and $0F
            or high(STAGE)
            ld h, a
            ld a, b
            ldh [rSVBK], a
            ld [hl], c
            ld a, 1
            ldh [rSVBK], a
            ret

; vblank: dirty tiles -> VRAM by general-purpose DMA (runs of set bits within a byte = up to
; 8 tiles per DMA), only while LY is still 144-151 (a DMA in drawing time loses its writes);
; the rest waits for the next vblank. A, F, BC, DE, HL clobbered.
hd_flush:   xor a
            ldh [chr_dirty], a
            ldh [wc_n], a                   ; (a CHR run relies on its tile's mark)
            ld a, $FF                       ; (marks cleared: forget the last marked tile)
            ldh [tm_hi], a
            ld hl, TILE_DIRTY
.byte:      ld a, [hl]
            and a
            jr z, .next
            ldh a, [rLY]
            cp 144
            jr c, .late
            cp 151
            jr nc, .late
            ld d, [hl]                      ; D = the byte's bits
            ld [hl], 0
            push hl
            ld a, l                         ; tile = (L - low(TILE_DIRTY)) * 8 + bit
            sub low(TILE_DIRTY)
            ld e, a                         ; E = byte index 0-63 (bit 5: table 1)
            ld b, 0                         ; B = bit
.bit:       bit 0, d
            jr z, .nb
            ld c, 0                         ; run length
.run:       inc c
            srl d
            inc b
            bit 0, d
            jr z, .go
            ld a, b
            cp 8
            jr c, .run
.go:        push de
            push bc
            ld a, b                         ; first tile of the run: E * 8 + B - C
            sub c
            ld b, a
            ld a, e
            and $1F
            ld d, a                         ; tile & 255 = (E & 31) * 8 + first bit
            add a, a
            add a, a
            add a, a
            add a, b
            ld l, a                         ; L = tile (0-255)
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl                      ; HL = tile * 16
            ld a, e                         ; table: WRAM bank 2 / 3, VRAM bank 0 / 1
            and $20
            swap a
            rrca
            ldh [rVBK], a
            add a, 2
            ldh [rSVBK], a
            ld a, h
            add a, high(STAGE)
            ldh [rHDMA1], a
            ld a, l
            ldh [rHDMA2], a
            ld a, h
            add a, $80 - $00
            ldh [rHDMA3], a                 ; (VRAM $8000 + tile * 16)
            ld a, l
            ldh [rHDMA4], a
            ld a, c
            dec a
            ldh [rHDMA5], a                 ; C blocks, general purpose
            ld a, 1
            ldh [rSVBK], a
            xor a
            ldh [rVBK], a
            pop bc
            pop de
            jr .bit2
.nb:        srl d
            inc b
.bit2:      ld a, b
            cp 8
            jr c, .bit
            pop hl
.next:      inc l                           ; (TILE_DIRTY ends at $CCFF: L wraps to 0)
            jr nz, .byte
            ret
.late:      ld a, 1                         ; out of vblank time: the rest next frame
            ldh [chr_dirty], a
            ret

; HL = offset in nametable B (cell < $3C0) -> HL = GB map address. Keeps B, C.
cell_map:   ldh a, [mirror]
            and a
            jr z, .v
            ld a, b                         ; horizontal: row + 30 for nametable 1, mod 32
            and a
            jr z, .v
            ld a, l                         ; offset + 30 * 32 = + $3C0, mod $400
            add a, $C0
            ld l, a
            ld a, h
            adc a, 3
            and 3
            ld h, a
.v:         ld a, h
            add a, $98
            ld h, a
            ret

rt_ppu_r7:  push af                         ; $2007 read (buffered; nametables from the shadow)
            xor a
            ldh [wc_n], a
            push bc
            push de
            call ppu_addr_inc
            ldh a, [ppu_rbuf]
            ld e, a
            ld a, h
            cp $20
            jr c, .zero
            cp $3F
            jr z, .pal
            and $0F
            rrca
            rrca
            and 3
            ld b, a
            ldh a, [mirror]
            and a
            ld a, b
            jr z, .vm
            srl a
            jr .nt
.vm:        and 1
.nt:        add a, a
            add a, a
            ld b, a
            ld a, h
            and 3
            add a, b
            add a, high(NT_SH)
            ld h, a
            ld a, [hl]
            jr .buf
.pal:       ld a, l
            and $1F
            add a, low(PAL_SH)
            ld l, a
            ld h, high(PAL_SH)
            ld e, [hl]                      ; (palette reads are not buffered)
            ld a, e
            jr .buf
.zero:      xor a                           ; (CHR reads: not kept)
.buf:       ldh [ppu_rbuf], a
            ld l, e
            pop de
            pop bc
            pop af
            ret

; attribute byte A at index L (0-63) of nametable B, old value in c_q: palettes of the
; quadrants that changed -> ATTR_SH (WRAM bank MAP_BANK), their rows marked in attr_dirty
; after the writes (a vblank flush in between copies the values or keeps the mark).
; A block covers cell rows r..r + 3 (r = 4 * block row); in the map a pair of rows (r, r + 1)
; never straddles the 32-row wrap (r and the horizontal-mirroring offset 30 are even), so
; each pair is one address computation. Keeps B, C.
attr_apply: ldh [c_val], a
            ld d, a
            ldh a, [c_q]
            xor d
            ret z                           ; unchanged
            push bc
            ld d, a                         ; D = changed bits
            ld a, l
            and $38
            cp $38
            jr nz, .rows
            ld a, d                         ; block row 7: its lower quadrants would be NES
            and $0F                         ;   rows 30-31 (none)
            jr z, .ret
            ld d, a
            ld a, $38
.rows:      rrca                            ; A = first cell row r (0, 4, .. 28)
            ld e, a
            ldh a, [mirror]
            and a
            jr z, .v
            ld a, b
            and a
            jr z, .v
            ld a, e                         ; horizontal, nametable 1: rows + 30, mod 32
            add a, 30
            and 31
            ld e, a
.v:         ld a, l
            and 7
            add a, a
            add a, a
            ld c, a                         ; C = first cell column
            ldh a, [bg_bank]
            ld b, a                         ; B = the cells' VRAM bank bit
            ld a, MAP_BANK
            ldh [rSVBK], a
            ldh a, [c_val]
            call .pair                      ; quadrants 0, 1: rows E, E + 1
            swap d
            ld a, e
            add a, 2
            and 31
            ld e, a
            ldh a, [c_val]
            swap a
            call .pair                      ; quadrants 2, 3
            ld a, 1
            ldh [rSVBK], a
.ret:       pop bc
            ret
; A = palettes (bits 0-1 left quadrant, 2-3 right), D low nibble = their changed bits,
; E = map row (even), C = column, B = bank bit
.pair:      ldh [c_x], a
            ld a, d
            and $0F
            ret z
            ld a, e                         ; HL = ATTR_SH + E * 32 + C (bit 5 of L clear:
            rrca                            ;   E is even)
            rrca
            rrca
            ld h, a
            and $E0
            or c
            ld l, a
            ld a, h
            and 3
            add a, high(ATTR_SH)
            ld h, a
            ld a, d
            and 3
            jr z, .p1
            ldh a, [c_x]
            and 3
            or b
            ld [hl+], a                     ; two cells in each of the two rows
            ld [hl-], a
            set 5, l
            ld [hl+], a
            ld [hl-], a
            res 5, l
.p1:        ld a, d
            and $0C
            jr z, .pm
            inc l
            inc l
            ldh a, [c_x]
            rrca
            rrca
            and 3
            or b
            ld [hl+], a
            ld [hl-], a
            set 5, l
            ld [hl+], a
            ld [hl], a
.pm:        ld a, e                         ; rows E, E + 1: bits E & 7, + 1 of byte E >> 3
            and 6
            rrca
            ld hl, PAIR_MASK
            add a, l
            ld l, a
            jr nc, .pn
            inc h
.pn:        ld h, [hl]
            ld a, e
            rrca
            rrca
            rrca
            and 3
            add a, low(attr_dirty)
            ld l, a
            ld a, h
            ld h, $FF
            or [hl]
            ld [hl], a
            ld a, 1
            ldh [map_any], a
            ret

; HL = GB map address ($9800-$9BFF): mark its row in map_dirty (map_mark) or in the bitmap at
; DE (row_mark). A, F, D, E clobbered; HL, B, C kept.
map_mark:   ld de, map_dirty
row_mark:   ld a, h                         ; row = (H & 3) << 3 | L >> 5: byte H & 3, bit L >> 5
            and 3
            add a, e
            ld e, a
            ld a, l
            swap a
            rrca
            and 7
            push hl
            ld hl, BIT_MASK
            add a, l
            ld l, a
            jr nc, .nc
            inc h
.nc:        ld a, [hl]
            ld h, d
            ld l, e
            or [hl]
            ld [hl], a
            pop hl
            ld a, 1
            ldh [map_any], a
            ret

; vblank: dirty rows of one shadow -> VRAM by general-purpose DMA (runs within a bitmap byte,
; 2 blocks per row), while LY is 144-150; the rest stays marked for the next vblank.
; HL = bitmap (4 bytes, HRAM), D = high(shadow), E = VRAM bank. SVBK = MAP_BANK.
map_flush:  ld a, e
            ldh [rVBK], a
            ld b, 0                         ; B = bitmap byte 0-3
.byte:      ld a, [hl]
            and a
            jr z, .next
            ldh a, [rLY]
            cp 151
            jr nc, .late
            ld c, [hl]                      ; C = bits; row = B * 8 + bit
            ld [hl], 0
            push hl
            ld e, 0                         ; E = bit
.bit:       bit 0, c
            jr z, .nb
            ld l, 0                         ; L = run length
.run:       inc l
            srl c
            inc e
            bit 0, c
            jr z, .go
            ld a, e
            cp 8
            jr c, .run
.go:        push de
            push bc
            ld a, e                         ; first row = B * 8 + E - L
            sub l
            ld e, a
            ld a, b
            add a, a
            add a, a
            add a, a
            add a, e                        ; A = row (0-31)
            ld h, 0                         ; offset = row * 32
            push hl
            ld l, a
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld a, h
            add a, d
            ldh [rHDMA1], a
            ld a, l
            ldh [rHDMA2], a
            ld a, h
            add a, $98
            ldh [rHDMA3], a
            ld a, l
            ldh [rHDMA4], a
            pop hl
            ld a, l                         ; 2 blocks per row
            add a, a
            dec a
            ldh [rHDMA5], a
            pop bc
            pop de
            jr .b2
.nb:        srl c
            inc e
.b2:        ld a, e
            cp 8
            jr c, .bit
            pop hl
.next:      inc hl
            inc b
            ld a, b
            cp 4
            jr c, .byte
            ret
.late:      ld a, 1
            ldh [map_any], a
            ret

; BG pattern table changed: set the bank bit of every attribute in the shadow, then the
; vblank copies them (rebank). A = new bank bit (0 / 8). Keeps all but F.
rebank_attrs:
            push af
            push bc
            push hl
            ld b, a
            ld a, MAP_BANK
            ldh [rSVBK], a
            ld hl, ATTR_SH
.l:         ld a, [hl]
            and $F7
            or b
            ld [hl+], a
            ld a, h
            cp high(ATTR_SH) + 4
            jr c, .l
            ld a, 1
            ldh [rSVBK], a
            ld a, $FF
            ld hl, attr_dirty
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl], a
            ld a, 1
            ldh [map_any], a
            pop hl
            pop bc
            pop af
            ret

; ------------------------------------------------------------------ OAM, joypad, APU
rt_io_w4014:                                ; OAM DMA from NES page A -> GB shadow OAM
            push af                         ;   (64 NES sprites -> up to 40 GB sprites in view)
            push bc
            push de
            add a, high(NES_RAM)
            ld h, a
            ld l, 0                         ; HL = NES OAM page (GB address)
            ldh a, [cam_y]                  ; C = 17 - cam_y: GB Y = NES Y + C (visible 9..159)
            cpl
            add a, 18
            ld c, a
            ldh a, [cam_x]                  ; B = 8 - cam_x: GB X = NES X + B (visible 1..167)
            cpl
            add a, 9
            ld b, a
            ldh a, [ppu_ctrl]               ; attribute table for the sprite pattern table
            and 8
            rrca
            rrca
            rrca
            add a, high(OAM_ATTR)
            ldh [wtmp], a
            ld de, OAM_SH
.lp:        ld a, [hl+]                     ; NES Y (HL -> tile)
            cp $EF
            jr nc, .s3
            add a, c
            cp 160
            jr nc, .s3
            cp 9
            jr c, .s3
            ld [de], a                      ; (GB Y, kept if X is in view too)
            inc l
            inc l
            ld a, [hl-]                     ; NES X (HL -> attributes)
            add a, b
            jr z, .sx
            cp 168
            jr nc, .sx
            inc e
            ld [de], a                      ; X
            dec l
            ld a, [hl+]                     ; tile (HL -> attributes)
            inc e
            ld [de], a
            ld a, [hl+]                     ; attributes (HL -> X)
            push hl
            ld l, a
            ldh a, [wtmp]
            ld h, a
            ld a, [hl]
            pop hl
            inc e
            ld [de], a
            inc e
            inc l                           ; next sprite
            ld a, e
            cp low(OAM_SH) + 160
            jr z, .full2
            ld a, l
            and a
            jr nz, .lp
            jr .fill
.s3:        inc l                           ; (HL at the tile: + 3)
            inc l
            inc l
            jr nz, .lp
            jr .fill
.sx:        inc l                           ; (HL at the attributes: + 2)
            inc l
            jr nz, .lp
.fill:      ldh a, [oam_end]                ; rest off screen (Y = 0 hides a GB sprite): only
            ld b, a                         ;   the slots used by the last conversion
            ld a, e
            ldh [oam_end], a
            ld h, d
            ld l, e
            ld de, 4
.fl:        ld a, l
            cp b
            jr nc, .end
            ld [hl], 0
            add hl, de
            jr .fl
.end:       ld a, 1
            ldh [oam_pending], a
            pop de
            pop bc
            pop af
            ret
.full2:     ld a, e                         ; (40 sprites: all slots in use)
            ldh [oam_end], a
            jr .end

rt_io_w4016:                                ; strobe: latch the buttons
            push af
            and 1
            jr z, .x
            call read_buttons
            ldh [joy_shift], a
.x:         pop af
            ret
rt_io_r4016:                                ; next button in NES order (A B Sel Start U D L R)
            push af
            ldh a, [async_req]              ; (safe point: battle input loops poll here)
            and a
            call nz, rt_async
            ldh a, [joy_shift]
            ld l, a
            scf
            rra
            ldh [joy_shift], a
            ld a, l
            and 1
            ld l, a
            pop af
            ret
read_buttons:                               ; -> A: bit 0 A, 1 B, 2 Select, 3 Start, 4 Up,
            push bc                         ;   5 Down, 6 Left, 7 Right (1 = pressed)
            ld a, [TEST_PAD]                ; test runner mode (gbrun / sgbrun): the pad of
            cp $A5                          ;   NES frame wait k from cart RAM bank 3
            jr nz, .real                    ;   $A000 + (k & $FF), in this bit order
            push hl
            ld a, 3
            ld [MBC5_RAMB], a
            ld a, [NMI_CNT]
            ld l, a
            ld h, $A0
            ld b, [hl]
            xor a
            ld [MBC5_RAMB], a
            ld a, b
            pop hl
            pop bc
            ret
.real:      ld a, $20
            ldh [rP1], a
            ldh a, [rP1]
            ldh a, [rP1]
            cpl
            and $0F                         ; GB: R L U D in bits 0-3
            ld b, a
            ld a, $10
            ldh [rP1], a
            ldh a, [rP1]
            ldh a, [rP1]
            ldh a, [rP1]
            ldh a, [rP1]
            cpl
            and $0F                         ; A B Select Start
            ld c, a
            xor a
            bit 0, b
            jr z, .r
            set 7, a
.r:         bit 1, b
            jr z, .l
            set 6, a
.l:         bit 2, b
            jr z, .u
            set 4, a
.u:         bit 3, b
            jr z, .d
            set 5, a
.d:         or c
            ld b, a
            ld a, $30
            ldh [rP1], a
            ld a, b
            pop bc
            ret
rt_io_r4015:
rt_io_r4017:
rt_io_rnone:
            ld l, 0
            ret
rt_apu_w:   ret                             ; (sound: later)

; ------------------------------------------------------------------ MMC5 registers
rt_mmc_w5114:                               ; 8KB bank at $8000
            push af
            and $7F
            ldh [nes_bank8], a
            push af
            and 1
            jr z, .e
            ld a, $20
.e:         ldh [odd8], a
            pop af
            srl a
            add a, DATA
            ldh [data_bank8], a
            pop af
            ret
rt_mmc_w5115:                               ; 8KB bank at $A000
            push af
            and $7F
            ldh [nes_bankA], a
            push af
            and 1
            jr z, .e
            ld a, $20
.e:         ldh [oddA], a
            pop af
            srl a
            add a, DATA
            ldh [data_bankA], a
            pop af
            ret
rt_mmc_w5116:
            ret                             ; ($C000 stays bank 126)
rt_mmc_w5105:                               ; mirroring: $44 vertical, $50 horizontal
            push af
            cp $50
            ld a, 0
            jr nz, .v
            inc a
.v:         ldh [mirror], a
            pop af
            ret
rt_mmc_w5203:
            ldh [irq_line], a
            ret
rt_mmc_w5204:
            push af
            and $80
            ldh [irq_en], a
            pop af
            ret
rt_mmc_r5204:                               ; IRQ pending + in frame (the helpers' polls pass)
            ld l, $C0
            ret
rt_mmc_w5800:                               ; GB layout: camera X / Y in tiles (later)
            push af
            add a, a
            add a, a
            add a, a
            ldh [cam_x], a
            pop af
            ret
rt_mmc_w5801:
            push af
            add a, a
            add a, a
            add a, a
            ldh [cam_y], a
            pop af
            ret
rt_mmc_w5802:
rt_mmc_w5803:
rt_mmc_w5804:
rt_mmc_w5805:
rt_mmc_w5806:
rt_mmc_w5807:
rt_mmc_w5808:
rt_mmc_w5809:
rt_mmc_w580A:
rt_mmc_w580B:
rt_mmc_w580C:
rt_mmc_w580D:
rt_mmc_w580E:
rt_mmc_w580F:
            ret

; ------------------------------------------------------------------ ROM data reads
; HL = $4000 + offset in the window's 8KB bank; returns L. The GB bank holds NES banks 2k
; (at $4000) and 2k + 1 (at $6000).
rt_rd_8:
           push af
            ldh a, [data_bank8]
            ld [MBC5_BANKL], a
            ldh a, [odd8]
            or h
            ld h, a
            ld l, [hl]
            ldh a, [code_bank]
            ld [MBC5_BANKL], a
            ldh a, [async_req]              ; (safe point)
            and a
            call nz, rt_async
            pop af
            ret
rt_rd_a:
           push af
            ldh a, [data_bankA]
            ld [MBC5_BANKL], a
            ldh a, [oddA]
            or h
            ld h, a
            ld l, [hl]
            ldh a, [code_bank]
            ld [MBC5_BANKL], a
            ldh a, [async_req]              ; (safe point)
            and a
            call nz, rt_async
            pop af
            ret
rt_rd_f:
           push af                         ; $C000-$FFFF: banks 126 / 127 = GB bank DATA + 63
            ld a, DATA + 63
            ld [MBC5_BANKL], a
            ld l, [hl]
            ldh a, [code_bank]
            ld [MBC5_BANKL], a
            ldh a, [async_req]              ; (safe point)
            and a
            call nz, rt_async
            pop af
            ret

; ------------------------------------------------------------------ indirect access
rt_izy_rd:
           push af                         ; L = zp pointer; byte at ptr+Y -> L
            ld h, high(NES_RAM)
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            add hl, bc
izrd:       ld a, h                         ; HL = NES address (AF pushed by the caller)
            add a, a                        ; (H's top bits shifted out: no compares)
            jr nc, .low
            add a, a
            jr c, .f
            add a, a
            jr c, .hi
            ld a, h                         ; $8000-$9FFF: the $5114 bank
            and $1F
            or $40
            ld h, a
            ldh a, [odd8]
            or h
            ld h, a
            ldh a, [data_bank8]
.rd:        ld [MBC5_BANKL], a
            ld l, [hl]
            ldh a, [code_bank]
            ld [MBC5_BANKL], a
            pop af
            ret
.hi:        ld a, h                         ; $A000-$BFFF: the $5115 bank
            and $1F
            or $40
            ld h, a
            ldh a, [oddA]
            or h
            ld h, a
            ldh a, [data_bankA]
            jr .rd
.f:         ld a, h                         ; $C000-$FFFF: banks 126 / 127
            sub $80
            ld h, a
            ld a, DATA + 63
            jr .rd
.low:       ld a, h
            cp $20
            jr nc, .prg
            and $07                         ; RAM
            or high(NES_RAM)
            ld h, a
            ld l, [hl]
            pop af
            ret
.prg:       cp $60
            jr c, .other
            add a, $40                      ; PRG-RAM $6000-$7FFF -> $A000
            ld h, a
            ld l, [hl]
            pop af
            ret
.other:     call nes_rd                     ; ExRAM, I/O
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
            jr izrd
; STA (zp),Y / INY / BNE (translate.py idiom): A -> ptr + Y .. ptr + 255; then Y = 0, Z = 1,
; N = 0, A and C kept. L = zp.
rt_izy_fill:
            push af
            ldh [wtmp], a
            ld h, high(NES_RAM)
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            add hl, bc                      ; HL = first address (NES)
            ld a, h
            cp $20
            jr c, .ram
            cp $60
            jr c, .slow
            cp $80
            jr nc, .slow
            add a, $40                      ; PRG-RAM -> $A000
            ld h, a
            jr .fill
.ram:       and $07
            or high(NES_RAM)
            ld h, a
.fill:      ldh a, [wtmp]                   ; (256 - Y bytes from ptr + Y, as on the NES)
.fl:        ld [hl+], a
            inc c
            jr nz, .fl
            jr .end
.slow:      push hl                         ; I/O or ROM: one byte at a time
            call nes_wr
            pop hl
            inc hl
            inc c
            jr nz, .slow
.end:       xor a
            ldh [nzv], a
            pop af                          ; Z = 1, A and C kept
            push af
            push hl
            ld hl, sp + 2
            set 7, [hl]
            pop hl
            pop af
            ret

; copy loop idiom (translate.py copy_idiom): cp_n bytes (0 = 256) from GB address HL (ROM
; bank A, 0 = RAM) to cp_dh:cp_dl. Returns A = the last byte, Z = 1, C = 1 (CPX / CPY equal),
; nzv = 0. B, C, D, E kept.
rt_copy_n:  push bc
            push de
            and a
            jr z, .ram
            ld [MBC5_BANKL], a
.ram:       ldh a, [cp_dl]
            ld e, a
            ldh a, [cp_dh]
            ld d, a
            ldh a, [cp_n]
            ld b, a
.lp:        ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .lp
            ld b, a
            ldh a, [code_bank]
            ld [MBC5_BANKL], a
            xor a
            ldh [nzv], a
            ld a, b
            pop de
            pop bc
            scf
            push af
            push hl
            ld hl, sp + 2
            set 7, [hl]                     ; Z = 1
            pop hl
            pop af
            ret

; PPU upload loop idiom (translate.py ppu_idiom): LDA src,X|Y / STA $2007 / INX|INY /
; CPX|CPY #n / BNE: cp_n bytes (0 = 256) from GB address HL (ROM bank A, 0 = RAM) through
; $2007. Returns A = the last byte, Z = 1, C = 1, nzv = 0. B, C, D, E kept.
rt_ppu_copy:
            push bc
            push de
            ld d, a                         ; D = data bank (0: RAM)
            ldh a, [cp_n]
            ld b, a                         ; B = bytes left (0 = 256: one byte first)
.lp:        ld a, b
            and a
            jr z, .one
            ldh a, [wc_n]                   ; a cached run with step 1: whole pieces of it
            and a
            jr z, .one
            ldh a, [wc_inc]
            dec a
            jr nz, .one
            ldh a, [wc_n]                   ; K = min(run, left)
            cp b
            jr c, .k
            ld a, b
.k:         ld e, a                         ; E = K
            push bc
            push de
            ld bc, PC_BUF                   ; source -> buffer
            ld a, d
            and a
            jr z, .s1
            ld [MBC5_BANKL], a
.s1:        ld a, [hl+]
            ld [bc], a
            inc c
            dec e
            jr nz, .s1
            ldh [nt_a], a                   ; (the last byte: A at the end)
            ldh a, [code_bank]
            ld [MBC5_BANKL], a
            pop de
            push hl
            ldh a, [wc_nl]                  ; buffer -> nametable shadow (bank 1)
            ld l, a
            ldh a, [wc_nh]
            ld h, a
            ld bc, PC_BUF
            push de
.s2:        ld a, [bc]
            ld [hl+], a
            inc c
            dec e
            jr nz, .s2
            pop de
            ld a, l
            ldh [wc_nl], a
            ld a, h
            ldh [wc_nh], a
            di                              ; buffer -> map shadow (bank MAP_BANK), unless a
            ldh a, [wc_n]                   ;   vblank flush dropped the run meanwhile (then
            and a                           ;   the rest goes one byte at a time)
            jr z, .lost
            ldh a, [wc_ml]
            ld l, a
            ldh a, [wc_mh]
            ld h, a
            ld a, MAP_BANK
            ldh [rSVBK], a
            ld bc, PC_BUF
            push de
.s3:        ld a, [bc]
            ld [hl+], a
            inc c
            dec e
            jr nz, .s3
            pop de
            ld a, 1
            ldh [rSVBK], a
            ld a, l
            ldh [wc_ml], a
            ld a, h
            ldh [wc_mh], a
            ldh a, [wc_n]                   ; run -= K, PPU address += K
            sub e
            ldh [wc_n], a
            ei
            ldh a, [ppu_vl]
            add a, e
            ldh [ppu_vl], a
            jr nc, .v
            ldh a, [ppu_vh]
            inc a
            and $3F
            ldh [ppu_vh], a
.v:         pop hl
            pop bc
            ld a, b                         ; left -= K
            sub e
            ld b, a
            jr nz, .lp
            jr .end
.lost:      ei                              ; (nametable shadow already written: redo the
            pop hl                          ;   piece through $2007 from the source)
            pop bc
            ld a, l
            sub e
            ld l, a
            jr nc, .one
            dec h
.one:       ld a, d                         ; one byte through $2007
            and a
            jr z, .r
            ld [MBC5_BANKL], a
            ld a, [hl+]
            ld e, a
            ldh a, [code_bank]
            ld [MBC5_BANKL], a
            ld a, e
            jr .w
.r:         ld a, [hl+]
.w:         ldh [nt_a], a
            push hl
            call rt_ppu_w7
            pop hl
            dec b
            jr nz, .lp
.end:       xor a
            ldh [nzv], a
            ldh a, [nt_a]
            pop de
            pop bc
            scf
            push af
            push hl
            ld hl, sp + 2
            set 7, [hl]
            pop hl
            pop af
            ret

; LDA (zp),Y / STA $2007 / INY / DEX / BNE (translate.py ppu_izy_idiom): L = zp, C = Y,
; E = X (0 = 256). The bytes ptr + Y .. go through rt_ppu_copy when they lie in one memory
; window (RAM, PRG-RAM, a ROM window) and Y does not wrap; else one at a time. Returns
; A = the last byte, X = 0, Y + count, Z = 1, N = 0 (nzv), C kept. D = 0, B = 0.
rt_ppu_izy: push af                         ; (C: kept)
            ld a, e
            and a
            jr z, .slow
            add a, c                        ; Y + X <= 256
            jr nc, .ok
            jr nz, .slow
.ok:        ld d, l                         ; D = zp (for the slow path)
            ld h, high(NES_RAM)
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            add hl, bc                      ; HL = first NES address
            ld a, e                         ; (L + X - 1: the carry into H for the end check)
            dec a
            add a, l
            ld a, h
            jr c, .cy
            cp $20
            jr c, .ram
            cp $60
            jr c, .slow1
            cp $80
            jr c, .prg
            cp $A0
            jr c, .w8
            cp $C0
            jr c, .wa
            jr .rf
.cy:        cp $20                          ; (end in the next page: same windows, end checked)
            jr c, .ramc
            cp $60
            jr c, .slow1
            cp $80
            jr c, .prgc
            cp $A0
            jr c, .w8c
            cp $C0
            jr c, .wac
            cp $FF
            jr z, .slow1
            jr .rf
.ramc:      and 7
            cp 7
            jr z, .slow1                    ; (would run past $07FF)
            ld a, h
.ram:       and 7
            or high(NES_RAM)
            ld h, a
            xor a
            jr .go
.prgc:      and $1F
            cp $1F
            jr z, .slow1
            ld a, h
.prg:       add a, $40                      ; PRG-RAM $6000 -> $A000
            ld h, a
            xor a
            jr .go
.w8c:       and $1F
            cp $1F
            jr z, .slow1
            ld a, h
.w8:        and $1F
            or $40
            ld h, a
            ldh a, [odd8]
            or h
            ld h, a
            ldh a, [data_bank8]
            jr .go
.wac:       and $1F
            cp $1F
            jr z, .slow1
            ld a, h
.wa:        and $1F
            or $40
            ld h, a
            ldh a, [oddA]
            or h
            ld h, a
            ldh a, [data_bankA]
            jr .go
.rf:        sub $80                         ; $C000-$FFFF: banks 126 / 127 at $4000
            ld h, a
            ld a, DATA + 63
.go:        ld d, a
            ld a, e
            ldh [cp_n], a
            ld a, d
            ld d, 0
            call rt_ppu_copy
            jr .end
.slow1:     ld l, d
.slow:      ld d, l                         ; one byte at a time (256 when X = 0)
.sl:        ld l, d
            call rt_izy_rd
            ld a, l
            ldh [nt_a], a
            call rt_ppu_w7
            inc c
            dec e
            jr nz, .sl
            ld d, 0
            ld e, c                         ; (Y: the count added below)
            ld c, 0
.end:       ld a, c                         ; Y += X, X = 0
            add a, e
            ld c, a
            ld e, 0
            xor a
            ldh [nzv], a
            pop af                          ; F: C as on entry, Z = 1; A = the last byte
            ldh a, [nt_a]
            push af
            ld hl, sp + 0
            ld a, [hl]
            and $10
            or $80
            ld [hl], a
            pop af
            ret

; LDA (zp),Y with the carry dead (translate.py): L = zp -> A = the byte at ptr + Y; F
; clobbered (the caller sets N / Z); BC, DE kept. RAM and PRG-RAM inline, else izrd.
rt_izy_lda: ld h, high(NES_RAM)
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            add hl, bc
            ld a, h
            add a, a
            jr c, .rom
            ld a, h
            and $E0
            jr z, .ram
            cp $60
            jr nz, .oth
            ld a, h                         ; PRG-RAM $6000 -> $A000
            add a, $40
            ld h, a
            ld a, [hl]
            ret
.ram:       ld a, h
            and 7
            or high(NES_RAM)
            ld h, a
            ld a, [hl]
            ret
.rom:       add a, a
            jr c, .f
            add a, a
            jr c, .hi
            ld a, h                         ; $8000-$9FFF
            and $1F
            or $40
            ld h, a
            ldh a, [odd8]
            or h
            ld h, a
            ldh a, [data_bank8]
.rd:        ld [MBC5_BANKL], a
            ld a, [hl]
            ld h, a
            ldh a, [code_bank]
            ld [MBC5_BANKL], a
            ld a, h
            ret
.hi:        ld a, h                         ; $A000-$BFFF
            and $1F
            or $40
            ld h, a
            ldh a, [oddA]
            or h
            ld h, a
            ldh a, [data_bankA]
            jr .rd
.f:         ld a, h                         ; $C000-$FFFF
            sub $80
            ld h, a
            ld a, DATA + 63
            jr .rd
.oth:       call izrd_c                     ; (ExRAM, I/O)
            ld a, l
            ret
izrd_c:     push af
            jp izrd
; STA (zp),Y with no flag live after it (translate.py): L = zp, A -> ptr + Y; A, BC, E kept,
; D used (0 again), F clobbered.
rt_izy_sta: ld d, a
            ld h, high(NES_RAM)
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            add hl, bc
            ld a, h
            and $E0
            jr z, .ram
            cp $60
            jr nz, .oth
            ld a, h
            add a, $40
            ld h, a
            ld a, d
            ld [hl], a
            ld d, 0
            ret
.ram:       ld a, h
            and 7
            or high(NES_RAM)
            ld h, a
            ld a, d
            ld [hl], a
            ld d, 0
            ret
.oth:       ld a, d
            ld d, 0
            ldh [wtmp], a
            push af
            call nes_wr
            pop af
            ret

rt_izy_wr:
           push af                         ; L = zp pointer; A -> ptr+Y
            ldh [wtmp], a
            ld h, high(NES_RAM)
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            add hl, bc
            ld a, h                         ; (RAM and PRG-RAM first)
            cp $20
            jr nc, .n1
            and $07
            or high(NES_RAM)
            ld h, a
            pop af
            ld [hl], a
            ret
.n1:        cp $60
            jr c, .other
            cp $80
            jr nc, .other
            add a, $40                      ; PRG-RAM $6000 -> $A000
            ld h, a
            pop af
            ld [hl], a
            ret
.other:     call nes_wr
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
            add a, $40                      ; PRG-RAM $6000 -> $A000
            ld h, a
            ld l, [hl]
            ret
.rom:       cp $A0
            jr nc, .roma
            and $1F
            or $40
            ld h, a
            jp rt_rd_8
.roma:      cp $C0
            jr nc, .romf
            and $1F
            or $40
            ld h, a
            jp rt_rd_a
.romf:      sub $80
            ld h, a
            jp rt_rd_f
.low:       cp $5C
            jr c, .io
            add a, $6C                      ; ExRAM $5C00 -> $C800
            ld h, a
            ld l, [hl]
            ret
.io:        cp $20
            jr c, .bad
            cp $40
            jr nc, .bad
            ld a, l                         ; PPU registers through a pointer
            and 7
            cp 2
            jp z, rt_ppu_r2
            cp 7
            jp z, rt_ppu_r7
.bad:       ld a, 3
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
.io:        cp $20
            jr c, .bad
            cp $40
            jr nc, .bad
            ld a, l                         ; PPU registers through a pointer
            and 7
            cp 7
            ldh a, [wtmp]
            jp z, rt_ppu_w7
            ld a, l
            and 7
            cp 6
            ldh a, [wtmp]
            jp z, rt_ppu_w6
            ret
.bad:       ld a, 4
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
; M-cycles at normal speed; the loop below runs twice for double speed. Register left
; at 0 with Z = 1, carry kept.
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
            jr .go
.n:         ld l, a
            srl l
            srl l
            sub l
            ret z
.go:        ld l, a
.lp:        dec a
            jr nz, .lp
            ld a, l
.lp2:       dec a
            jr nz, .lp2
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

; ------------------------------------------------------------------ TSX / TXS
; X = $FF - (GB stack depth) / 2 (every GB stack entry is 2 bytes); rt_txs maps it back.
; (FF2's helpers; FF3: stack check fix:E299, Warp p3c:9B5F, inn p3c:9039.)
rt_tsx:     push af
            ld hl, sp + 4                   ; the caller's SP
            ld a, low(STACK_TOP)
            sub l
            ld l, a
            ld a, high(STACK_TOP)
            sbc h
            srl a
            rr l
            ld a, $FF
            sub l
            ld e, a
            pop af
            ret
rt_txs:     push af                         ; SP = STACK_TOP - 2 * ($FF - X); A, F, BC, DE kept
            pop hl
            ld a, h
            ldh [sv_a], a
            ld a, l
            ldh [uw_f], a
            pop hl                          ; return address
            ld a, l
            ldh [uw_ret], a
            ld a, h
            ldh [uw_ret + 1], a
            ld a, $FF
            sub e
            ld l, a
            ld h, 0
            add hl, hl
            ld a, low(STACK_TOP)
            sub l
            ld l, a
            ld a, high(STACK_TOP)
            sbc h
            ld h, a
            ld sp, hl
            ldh a, [uw_ret + 1]
            ld h, a
            ldh a, [uw_ret]
            ld l, a
            push hl
            ldh a, [sv_a]
            ld h, a
            ldh a, [uw_f]
            ld l, a
            push hl
            pop af
            ret

; ------------------------------------------------------------------ banking / dispatch
rt_farcall:
           ; HL = target, fc_bank = its bank; A, F, BC, DE pass both ways
            ldh [sv_a], a
            ldh a, [code_bank]
            push af
            ldh a, [fc_bank]
            ldh [code_bank], a
            ld [MBC5_BANKL], a
            ldh a, [sv_a]
            call rt_jp_hl
rt_farcall_ret:
            ldh [sv_a], a
            pop hl
            ld a, h
            ldh [code_bank], a
            ld [MBC5_BANKL], a
            ldh a, [sv_a]
            push af                         ; (the callee's A and flags pass back)
            ldh a, [async_req]              ; (safe point)
            and a
            jr nz, .async
            pop af
            ret
.async:     pop af
            jp rt_async

; HL = NES address -> HL = GB address, fc_bank = GB bank (A, F, BC, DE kept). Hashed table
; in bank DYN_BANK (translate.py): bucket (lo + hi + key) & $FF, key = the NES 8KB bank of
; the address's window ($8000: $5114, $A000: $5115), else $FF. In front of it a direct-mapped
; cache LK_TAB (WRAM bank 1, 64 entries of 8 bytes: lo, hi, key, GB bank, GB address), index
; (lo + hi + key) & 63. (An empty entry, all 0, never matches: key 0 only goes with $8000-$BFFF.)
lookup:
           push af
            push bc
            push de
            ld d, h
            ld e, l
            ld a, d                         ; C = key
            cp $80
            jr c, .any
            cp $A0
            jr c, .w8
            cp $C0
            jr nc, .any
            ldh a, [nes_bankA]
            jr .key
.w8:        ldh a, [nes_bank8]
            jr .key
.any:       ld a, $FF
.key:       ld c, a
            ld a, e
            add a, d
            add a, c
            ld b, a                         ; B = hash
            and 63
            add a, a
            add a, a
            ld l, a
            ld h, high(LK_TAB) / 2          ; (LK_TAB 512-aligned)
            add hl, hl                      ; HL = LK_TAB + 8 * index
            ld a, [hl+]
            cp e
            jr nz, .full
            ld a, [hl+]
            cp d
            jr nz, .full
            ld a, [hl+]
            cp c
            jr nz, .full
            ld a, [hl+]
            ldh [fc_bank], a
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            pop de
            pop bc
            pop af
            ret
.full:      ld a, l                         ; (entry start: L & $F8)
            and $F8
            ld l, a
            push hl
            ld a, DYN_BANK
            ld [MBC5_BANKL], a
            ld l, b
            ld h, high(dyn_index) / 2
            add hl, hl                      ; dyn_index + 2 * bucket ($4000-$41FF)
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld b, [hl]                      ; entries in the bucket
            inc hl
            inc b
.lp:        dec b
            jr z, .miss
            ld a, [hl+]
            cp e
            jr nz, .n1
            ld a, [hl+]
            cp d
            jr nz, .n2
            ld a, [hl+]
            cp c
            jr nz, .n3
            ld a, [hl+]                     ; found: bank, address -> the cache entry
            ldh [fc_bank], a
            ld b, a
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ldh a, [code_bank]
            ld [MBC5_BANKL], a
            ld a, l
            ldh [tmp_lo], a
            ld a, h
            pop hl                          ; HL = entry
            ld [hl], e
            inc l
            ld [hl], d
            inc l
            ld [hl], c
            inc l
            ld [hl], b
            inc l
            ld d, a
            ldh a, [tmp_lo]
            ld [hl+], a
            ld [hl], d
            ld h, d
            ld l, a
            pop de
            pop bc
            pop af
            ret
.n1:        inc hl
.n2:        inc hl
.n3:        inc hl
            inc hl
            inc hl
            jr .lp
.miss:      pop hl
            ldh a, [code_bank]
            ld [MBC5_BANKL], a
            ld h, d
            ld l, e
            ld a, 1
            jp rt_fault

; compact cross-bank stub: call rt_fcs / db bank / dw target (translate.py). A, F, BC, DE pass.
rt_fcs:     ldh [sv_a], a
            pop hl
            ld a, [hl+]
            ldh [fc_bank], a
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ldh a, [sv_a]
            jp rt_farcall

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
rt_unwind3: ldh [sv_a], a                   ; 3 frames, then CLC
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

BIT_MASK:   db 1, 2, 4, 8, 16, 32, 64, 128
PAIR_MASK:  db 3, 12, 48, 192

rst38_trap: di                              ; rst $38 (opcode $FF) reached: DBG+8 = SP,
            ld [DBG + 8], sp                ;   DBG+10.. = stack words; then stop
            ld a, $38
            ld [DBG], a
.s:         halt
            jr .s
