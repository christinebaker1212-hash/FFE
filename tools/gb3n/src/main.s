; FF3 native engine for the Game Boy Color (docs/ff3-gb-status.md). Our own code, written from
; what the everything8215/ff3 listing says each routine does; game data is read from the user's
; ROM by tools/gb3n/build.py at build time.
;
; This file: the header vectors, boot (memory cleared, Lot Check), the "Game Boy Color only"
; screen on older systems, double speed, the frame wait, the pad and the soft reset.

LCDC_ON    = $93            ; LCD on, BG tiles at $8000, BG map $9800, BG and sprites on
rKEY1      = $FF4D
rVBK       = $FF4F
rSVBK      = $FF70
rBCPS      = $FF68
rBCPD      = $FF69
rOCPS      = $FF6A
rOCPD      = $FF6B
SOFT_MAGIC = $A5            ; E on entry to `start` from a soft reset
PAD_A      = $01            ; pad bits (read_pad): A B Select Start Right Left Up Down
PAD_B      = $02
PAD_SEL    = $04
PAD_START  = $08
PAD_RESET  = $0F            ; A + B + Select + Start: soft reset (Lot Check)

section bank 0, $0040
            jp vblank
section bank 0, $0048
            reti
section bank 0, $0050
            reti
section bank 0, $0058
            reti
section bank 0, $0060
            reti
section bank 0, $0100
            nop
            jp start

section bank 0, $0150
start:      di
            ld sp, $D000                    ; (the stack: the top of fixed work RAM)
            ld d, a                         ; A = $11 on a Game Boy Color / Advance
            ld a, e                         ; (E = SOFT_MAGIC: a soft reset)
            cp SOFT_MAGIC
            ld c, 0
            jr nz, .sr
            inc c
.sr:        ldh a, [rLCDC]                  ; the LCD goes off only in V-Blank (if on)
            bit 7, a
            jr z, .lo
.vw:        ldh a, [rLY]
            cp 144
            jr c, .vw
            xor a
            ldh [rLCDC], a
.lo:        ld hl, $C000                    ; work RAM bank 0 cleared (inline: the stack is in it;
.wc:        xor a                           ;   D = model, B = Advance bit, C = soft reset kept)
            ld [hl+], a
            ld a, h
            cp $D0
            jr nz, .wc
            ld hl, $FF80                    ; high RAM cleared ($FF80-$FFFE)
.hc:        xor a
            ld [hl+], a
            ld a, l
            cp $FF
            jr nz, .hc
            ld a, c
            ldh [soft_rst], a
            ld a, b                         ; (B bit 0: a Game Boy Advance)
            and 1
            ldh [is_gba], a
            ld a, d
            cp $11
            jp nz, cgb_only                 ; DMG / Pocket / Super Game Boy: the notice
            jp boot_cgb

; ---- older systems: "This Game Pak is designed only for use on the Game Boy Color." Only DMG
; registers here (Lot Check: no Color registers on a DMG / SGB).
cgb_only:   ld hl, $D000                    ; work RAM bank 1 ($D000-$DFFF) cleared
            ld de, $1000
            call memclr
            ld hl, $8000                    ; VRAM cleared
            ld de, $2000
            call memclr
            ld hl, $FE00                    ; OAM cleared (LCD off)
            ld de, $A0
            call memclr
            ld hl, C_TILES                  ; font and frame tiles
            ld de, $8000
            ld bc, $1000
            call memcpy
            ld hl, C_SCR_CGBONLY
            call show_screen
            xor a
            ldh [rNR52], a                  ; sound off
            ld a, %00100111                 ; BGP: 0 black, 1 light grey, 2 dark grey, 3 white
            ldh [rBGP], a
            ld a, LCDC_ON
            ldh [rLCDC], a
            ld a, 1
            ldh [rIE], a
            ei
.idle:      halt
            jr .idle

; ---- the Game Boy Color
boot_cgb:   ldh a, [rKEY1]                  ; double speed (KEY1 + STOP; already on after a
            bit 7, a                        ;   soft reset)
            jr nz, .ds
            xor a
            ldh [rIE], a
            ld a, $30
            ldh [rP1], a
            ld a, 1
            ldh [rKEY1], a
            stop
            nop
.ds:        ld b, 7                         ; work RAM banks 1-7 cleared
.wb:        ld a, b
            ldh [rSVBK], a
            push bc
            ld hl, $D000
            ld de, $1000
            call memclr
            pop bc
            dec b
            jr nz, .wb
            ld a, 1
            ldh [rSVBK], a
            ld a, 1                         ; VRAM banks 1 and 0 cleared
            ldh [rVBK], a
            ld hl, $8000
            ld de, $2000
            call memclr
            xor a
            ldh [rVBK], a
            ld hl, $8000
            ld de, $2000
            call memclr
            ld hl, $FE00
            ld de, $A0
            call memclr
            ld a, $80                       ; BG palettes 0-7 and OBJ palettes 0-7: palette 0
            ldh [rBCPS], a                  ;   black / light / dark / white, the rest black
            ld hl, C_PAL0
            ld b, 8
.p0:        ld a, [hl+]
            ldh [rBCPD], a
            dec b
            jr nz, .p0
            ld b, 56
.p1:        xor a
            ldh [rBCPD], a
            dec b
            jr nz, .p1
            ld a, $80
            ldh [rOCPS], a
            ld b, 64
.p2:        xor a
            ldh [rOCPD], a
            dec b
            jr nz, .p2
            ld hl, C_TILES
            ld de, $8000
            ld bc, $1000
            call memcpy
            ld hl, dma_rom                  ; the OAM DMA routine into high RAM
            ld de, hram_dma
            ld b, dma_end - dma_rom
.dm:        ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .dm
            ld a, START_WORLD               ; (first steps: a test map, walking)
            ld [world], a
            ld a, START_MAP
            ld [map_id], a
            ld a, START_X
            ld [enter_x], a
            ld a, START_Y
            ld [enter_y], a
            call map_enter
            ld a, LCDC_ON
            ldh [rLCDC], a
            ld a, 1
            ldh [rIE], a
            xor a
            ldh [rIF], a
            ei
main_loop:  call wait_vbl
            call field_vbl
            call read_pad
            call field_step
            jr main_loop

; ---- a 20 x 18 screen map (HL) into the BG map at $9800 (LCD off)
show_screen: ld de, $9800
            ld c, 18
.r:         ld b, 20
.c:         ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .c
            ld a, e
            add 12
            ld e, a
            jr nc, .n
            inc d
.n:         dec c
            jr nz, .r
            ret

; ---- V-Blank
vblank:     push af
            ld a, 1
            ldh [vbl_done], a
            pop af
            reti

; wait for the next V-Blank (the check and the halt with interrupts off: no lost frame)
wait_vbl:   xor a
            ldh [vbl_done], a
.w:         di
            ldh a, [vbl_done]
            and a
            jr nz, .d
            ei
            halt
            jr .w
.d:         ei
            ret

; read the pad: pad = buttons held (PAD_*), pad_new = newly pressed; Up + Down or Left + Right
; held together count as neither (as FF1's pad_opp). A + B + Select + Start: soft reset.
read_pad:   ld a, $20
            ldh [rP1], a
            ldh a, [rP1]
            ldh a, [rP1]
            cpl
            and $0F
            swap a
            ld b, a                         ; directions in the high nibble: Down Up Left Right
            ld a, $10
            ldh [rP1], a
            ldh a, [rP1]
            ldh a, [rP1]
            ldh a, [rP1]
            ldh a, [rP1]
            ldh a, [rP1]
            ldh a, [rP1]
            cpl
            and $0F
            or b
            ld b, a
            and $C0                         ; Up + Down
            cp $C0
            jr nz, .ud
            ld a, b
            and $3F
            ld b, a
.ud:        ld a, b
            and $30                         ; Left + Right
            cp $30
            jr nz, .lr
            ld a, b
            and $CF
            ld b, a
.lr:        ld a, $30
            ldh [rP1], a
            ldh a, [pad]
            cpl
            and b
            ldh [pad_new], a
            ld a, b
            ldh [pad], a
            and PAD_RESET
            cp PAD_RESET
            ret nz
soft_reset: di                              ; (A + B + Select + Start)
            ldh a, [is_gba]
            ld b, a
            ld a, $11
            ld e, SOFT_MAGIC
            jp start

memclr:     xor a                           ; HL = start, DE = length
            ld [hl+], a
            dec de
            ld a, d
            or e
            jr nz, memclr
            ret

memcpy:     ld a, [hl+]                     ; HL -> DE, BC bytes
            ld [de], a
            inc de
            dec bc
            ld a, b
            or c
            jr nz, memcpy
            ret

section hram, $FF80
hram_dma:   ds 10
rombank:    ds 1
is_gba:     ds 1
soft_rst:   ds 1
vbl_done:   ds 1
pad:        ds 1
pad_new:    ds 1
