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

STACK_TOP  = $C200          ; GB stack in NES page 1 ($C100-$C1FF; FF3's NMI / IRQ jump stubs
                            ;   at $0100-$0105 stay below the deepest use seen)
NES_RAM    = $C000          ; $0000-$07FF
EX_RAM     = $C800          ; $5C00-$5FFF
OAM_SH     = $CC00          ; GB shadow OAM (160 bytes)
PAL_SH     = $CCA0          ; NES palette RAM (32)
NT_SH      = $D000          ; NES nametables (2 x 1KB after mirroring), WRAM bank 1
DBG        = $D820          ; fault info: code, HL, SP, stack top (16)  (the addresses FF1's
NMI_CNT    = $D830          ; 16-bit count of NES frame waits             test runners read:
VBL_CNT    = $D832          ; 16-bit count of GB frames                   tools/gb/gambatte/
TEST_PAD   = $D83E          ; $A5: test runner input mode (later)         gbrun.c)
DBG_RING   = $DE00          ; debug ring (256 bytes; gbrun GBRUN_DBG dumps it)
DBG_RING_P = $D83F
ATTR_SH    = $DC00          ; GB map attributes (VRAM bank 1 $9800-$9BFF), 1KB, 16-aligned
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
rebank:     ds 1                            ; BG table changed: rewrite the attributes
frame_tick: ds 1
oam_pending: ds 1
pal_dirty:  ds 1
shown:      ds 1                            ; palettes shown: 1 normal, 0 black (rendering off)
joy_shift:  ds 1
joy_state:  ds 1
irq_line:   ds 1                            ; MMC5 $5203 / $5204 (scanline IRQ)
irq_en:     ds 1
async_req:  ds 1                            ; asynchronous NES interrupts due: bit 0 NMI (set by
                                            ;   the vblank while $0100 holds a JMP and NMIs are
                                            ;   on), bit 1 IRQ (armed by the NMI handler); run
                                            ;   at the next safe point (rt_async)
in_async:   ds 1                            ; rt_async is running a handler
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
c_y:        ds 1
c_nt:       ds 1
c_val:      ds 1
c_q:        ds 1
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
            ld hl, $C000                    ; clear WRAM (not the stack page)
            ld bc, $100
            call memclr
            ld hl, $C200
            ld bc, $0E00
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
            ldh a, [rebank]                 ; BG table changed: attributes by DMA
            and a
            jr z, .nrb
            xor a
            ldh [rebank], a
            ld a, 1
            ldh [rVBK], a
            ld a, high(ATTR_SH)
            ldh [rHDMA1], a
            xor a
            ldh [rHDMA2], a
            ld a, $98
            ldh [rHDMA3], a
            xor a
            ldh [rHDMA4], a
            ld a, $3F                       ; 64 blocks of 16 bytes, general purpose
            ldh [rHDMA5], a
            xor a
            ldh [rVBK], a
.nrb:       ldh a, [ppu_ctrl]               ; asynchronous NMI (battle / cutscenes): $0100 = JMP
            bit 7, a                        ;   and NMIs on: run the handler at the next safe
            jr z, .nn                       ;   point
            ld a, [NES_RAM + $100]
            cp $4C
            jr nz, .nn
            ldh a, [async_req]
            or 1
            ldh [async_req], a
.nn:        ld a, 1
            ldh [frame_tick], a
            ld a, $80
            ldh [ppu_stat], a
            ld hl, VBL_CNT
            inc [hl]
            jr nz, .c
            inc hl
            inc [hl]
.c:         pop hl
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
            ld hl, DBG_RING_P               ; (debug: LY at each wait entry -> ring $DE00)
            ld a, [hl]
            inc [hl]
            ld l, a
            ld h, high(DBG_RING)
            ldh a, [rLY]
            ld [hl], a
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
.c:         pop af
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
            bit 0, a
            jr z, .irq
            and $FE
            ldh [async_req], a
            ld hl, NMI_CNT                  ; (an NES frame: the test runners' clock)
            inc [hl]
            jr nz, .c
            inc hl
            inc [hl]
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
            call nz, rt_async
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
            call nz, rt_async
            ld a, [NES_RAM + $00]
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

rt_ppu_w7:  push af                         ; $2007 write
            push bc
            push de
            ld c, a
            call ppu_addr_inc               ; HL = NES VRAM address
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
            pop hl
            ld a, h
            cp 3
            jr nz, .cell
            ld a, l
            cp $C0
            jr nc, .attr
.cell:      call cell_map                   ; HL = GB map address of the cell
            ld a, c
            call vput0
            jr .done
.attr:      ld a, l
            sub $C0
            ld l, a
            ld a, c
            call attr_apply                 ; L = attribute index, A = value, B = nametable
            jr .done
.chr:       ld a, h                         ; CHR: tile byte k -> GB row byte
            and $10
            ld b, a                         ; bank (table 1 -> VRAM bank 1)
            ld a, l
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
            and $0F
            or $80
            ld h, a
            ld a, c
            bit 4, b
            jr nz, .b1
            call vput0
            jr .done
.b1:        call vput1
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
; quadrants that changed -> ATTR_SH and VRAM bank 1 (two cells per access window). Keeps B, C.
attr_apply: ldh [c_val], a
            ld d, a
            ldh a, [c_q]
            xor d
            ret z                           ; unchanged
            ld d, a                         ; D = changed bits
            ld a, b
            ldh [c_nt], a
            ld a, l
            and 7
            add a, a
            add a, a
            ldh [c_x], a                    ; first cell column of the block
            ld a, l
            and $38
            rrca
            ldh [c_y], a                    ; first cell row
            ld e, 0                         ; E = quadrant 0-3
.q:         ld a, d
            and 3
            jr z, .nextq
            push de
            ldh a, [c_val]                  ; palette of quadrant E
            ld d, e
.sh:        dec d
            inc d
            jr z, .got
            rrca
            rrca
            dec d
            jr .sh
.got:       and 3
            ld l, a
            ldh a, [bg_bank]
            or l
            ldh [c_q], a                    ; attribute value of the quadrant's cells
            ld a, e                         ; cell row = y + 2 * (q >> 1)
            and 2
            ld l, a
            ldh a, [c_y]
            add a, l
            ld d, a                         ; D = row
            ld a, e                         ; column = x + 2 * (q & 1)
            and 1
            add a, a
            ld l, a
            ldh a, [c_x]
            add a, l
            ld e, a                         ; E = column
            call quad_row
            inc d
            call quad_row
            pop de
.nextq:     srl d
            srl d
            inc e
            ld a, e
            cp 4
            jr c, .q
            ldh a, [c_nt]
            ld b, a
            ret
quad_row:   ld a, d                         ; cells (E, D) and (E + 1, D) of nametable c_nt
            cp 30
            ret nc
            push de
            ld l, d
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld a, e
            add a, l
            ld l, a
            ldh a, [c_nt]
            ld b, a
            call cell_map                   ; -> $98xx
            ld a, h
            sub $98 - high(ATTR_SH)
            ld d, a
            ld e, l
            ldh a, [c_q]
            ld [de], a                      ; shadow (two cells)
            inc e
            ld [de], a
            di
            ld a, 1
            ldh [rVBK], a
.w:         ldh a, [rSTAT]
            and 2
            jr nz, .w
            ldh a, [c_q]
            ld [hl+], a
            ld [hl], a
            ei
            pop de
            ret

; BG pattern table changed: set the bank bit of every attribute in the shadow, then the
; vblank copies them (rebank). A = new bank bit (0 / 8). Keeps all but F.
rebank_attrs:
            push af
            push bc
            push hl
            ld b, a
            ld hl, ATTR_SH
.l:         ld a, [hl]
            and $F7
            or b
            ld [hl+], a
            ld a, h
            cp high(ATTR_SH) + 4
            jr c, .l
            ld a, 1
            ldh [rebank], a
            pop hl
            pop bc
            pop af
            ret

; ------------------------------------------------------------------ OAM, joypad, APU
rt_io_w4014:                                ; OAM DMA from NES page A -> GB shadow OAM
            push af
            push bc
            push de
            ld d, a
            ld e, 0
            ld a, d
            add a, high(NES_RAM)
            ld d, a                         ; DE = NES OAM page (GB address)
            ld hl, OAM_SH
            ld b, 64
            ld c, 40
.lp:        ld a, [de]                      ; NES Y (top - 1)
            inc de
            cp $EF
            jr nc, .skip3
            inc a
            push hl
            ld hl, cam_y
            sub [hl]
            pop hl
            cp 144
            jr c, .yin
            cp 256 - 7
            jr c, .skip3
.yin:       add a, 16
            ldh [o_cx], a                   ; (GB Y)
            ld a, [de]                      ; tile
            inc de
            ldh [o_cnt], a
            ld a, [de]                      ; attributes
            inc de
            ldh [wtmp], a
            ld a, [de]                      ; X
            inc de
            push hl
            ld hl, cam_x
            sub [hl]
            pop hl
            cp 160
            jr c, .xin
            cp 256 - 7
            jr c, .skip0
.xin:       add a, 8
            push af
            ldh a, [o_cx]
            ld [hl+], a                     ; Y
            pop af
            ld [hl+], a                     ; X
            ldh a, [o_cnt]
            ld [hl+], a                     ; tile
            ldh a, [wtmp]                   ; attributes: palette, flips, priority, table
            push bc
            ld b, a
            and 3
            ld c, a
            ld a, b
            and $C0
            rrca
            or c
            ld c, a
            ld a, b
            and $20
            rlca
            rlca
            or c
            ld c, a
            ldh a, [ppu_ctrl]
            and 8                           ; sprite pattern table -> bank bit
            or c
            pop bc
            ld [hl+], a
            dec c
            jr z, .full
            jr .skip0
.skip3:     inc de
            inc de
            inc de
.skip0:     dec b
            jr nz, .lp
.full:      ld a, l                         ; rest off screen
            cp low(OAM_SH) + 160
            jr nc, .end
            xor a
            ld [hl+], a
            jr .full
.end:       ld a, 1
            ldh [oam_pending], a
            pop de
            pop bc
            pop af
            ret

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
rt_rd_8:    push af
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
rt_rd_a:    push af
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
rt_rd_f:    push af                         ; $C000-$FFFF: banks 126 / 127 = GB bank DATA + 63
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
rt_farcall: ; HL = target, fc_bank = its bank; A, F, BC, DE pass both ways
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
; the address's window ($8000: $5114, $A000: $5115), else $FF.
lookup:     push af
            push bc
            push de
            ld d, h
            ld e, l
            ld a, d
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
            ld a, DYN_BANK
            ld [MBC5_BANKL], a
            ld a, e
            add a, d
            add a, c
            ld l, a
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
            ld a, [hl+]
            ldh [fc_bank], a
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ldh a, [code_bank]
            ld [MBC5_BANKL], a
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
.miss:      ldh a, [code_bank]
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

rst38_trap: di                              ; rst $38 (opcode $FF) reached: DBG+8 = SP,
            ld [DBG + 8], sp                ;   DBG+10.. = stack words; then stop
            ld a, $38
            ld [DBG], a
.s:         halt
            jr .s
