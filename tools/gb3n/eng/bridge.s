; FF3 native port: the kept parts (FF3's battle rules and screen, tools/gb3n/src/bat*.s / banim.s /
; bsumn.s; FF3's sound driver, sound.s: written natively from the listing and checked against FF3
; earlier) joined to the engine. Our own code: the routines and RAM those modules use, the battle's
; interrupt mode, entering a battle from the field and coming back.
;
; A battle runs in its own mode (bmode = 1): the V-Blank handler only counts the frame (and runs the
; sound during the battle's loads), the STAT handler holds a guarded load to H-Blank or runs the
; battle's raster effects; the battle draws, uploads and plays its sound itself. The field's state
; in $C900-$CDFF is kept in WRAM bank 3 while the battle uses that RAM, and the map is loaded again
; after it (FF3 3F/E274: reload map).

I_RGB      = $7D00          ; (B_MAPINFO: NES colour -> RGB555, old build's field_banks)
A_GPAL     = $4000          ; (B_MAPAUX: FF3's general palettes)
FR_TL      = $10            ; the window frame codes (as dlg.s: FF3's $F7-$FE)
FR_T       = $11
FR_TR      = $12
FR_L       = $13
FR_R       = $14
FR_BL      = $15
FR_B       = $16
FR_BR      = $17
ATTR_FRAME = $0F            ; palette 7, VRAM bank 1
map_id     = Z + $48
pos_x      = px
wm_x       = Z + $27
PAD_A      = $01            ; the pad bits (read_pad): A B Select Start Right Left Up Down
PAD_B      = $02
PAD_SEL    = $04
PAD_START  = $08
PAD_RESET  = $0F
SRAM_PAGE  = SV             ; FF3's save page ($6000)
SR_GIL     = SV + $1C
I_WINPAL   = $7CC0          ; (B_MAPINFO: the window's NES colours)
veh        = Z + $42        ; FF3's vehicle
pos_y      = py
wmode      = maptype        ; 1: the world map
ev_who     = Z + $A0        ; the person talked to (FF3 $A0)
scr_buf    = TS7B           ; FF3's $7B00 (a shop's items)
SCRATCH    = $DA00          ; (WRAM bank 1: data staged from ROM banks, 768 bytes)
SV_KEEP    = $D000          ; (WRAM bank 3: the field's RAM while a battle runs)

section bank 0, $2A00

; ---- the battle mode's interrupts
vbl_b:      ld a, 1                         ; (from vblank, AF pushed)
            ldh [vbl_done], a
            ldh a, [snd_isr]                ; (during loads the sound runs here)
            and a
            jr nz, .snd
            pop af
            reti
.snd:       xor a
            ldh [snd_isr], a
            push bc
            push de
            push hl
            ei
            call snd_frame
            di
            ldh a, [guard_on]               ; (a guarded load goes on in H-Blank / V-Blank only)
            and a
            jr z, .r
.g:         ldh a, [rSTAT]
            and 3
            cp 2
            jr nc, .g
.r:         ld a, 1
            ldh [snd_isr], a
            pop hl
            pop de
            pop bc
            pop af
            reti

stat_b:     ldh a, [c_split]                ; (from stat_int, AF pushed)
            and a
            jr nz, .cs
.w:         ldh a, [rSTAT]                  ; a guarded load: held until H-Blank
            and 3
            jr nz, .w
            ldh a, [guard_on]
            and a
            jr nz, .x
            ldh a, [rLCDC]
            and $DF
            ldh [rLCDC], a
.x:         pop af
            reti
.cs:        cp 3                            ; (3: a battle's wave, a line's SCX from wv_tab;
            jr z, .wv                       ;   4: its bands, SCX negated every 24 lines)
            cp 4
            jr z, .zb
            ldh a, [rLCDC]
            xor $08
            ldh [rLCDC], a
            ldh a, [c_lyb]
            ldh [rLYC], a
            ld a, $FF
            ldh [c_lyb], a
            pop af
            reti
.wv:        ldh a, [rLY]
            cp 95
            jr nc, .we
            inc a
            push hl
            ld hl, wv_ph
            add a, [hl]
            and 15
            add a, low(wv_tab)
            ld l, a
            ld h, high(wv_tab)
            ld a, [hl]
            ldh [rSCX], a
            pop hl
            pop af
            reti
.we:        xor a
            ldh [rSCX], a
            ldh a, [rLCDC]
            and $DF
            ldh [rLCDC], a
            pop af
            reti
.zb:        ldh a, [rLYC]
            cp 95
            jr nc, .ze
            add a, 24
            ldh [rLYC], a
            ldh a, [rSCX]
            cpl
            inc a
            ldh [rSCX], a
            pop af
            reti
.ze:        xor a
            ldh [rSCX], a
            pop af
            reti

; ---- the routines the kept modules use
far_copy:   push af                         ; A = bank: BC bytes HL -> DE
            ldh a, [rombank]
            ldh [fc_save], a
            pop af
            ldh [mapbank], a                ; (mapbank first: an interrupt maps it again)
            ld [MBC5_BANKL], a
            call memcpy
            ldh a, [fc_save]
            ldh [mapbank], a
            ld [MBC5_BANKL], a
            ret
far_byte:   push bc                         ; A = bank: A = [HL]
            ld b, a
            ldh a, [rombank]
            ld c, a
            ld a, b
            ldh [mapbank], a
            ld [MBC5_BANKL], a
            ld b, [hl]
            ld a, c
            ldh [mapbank], a
            ld [MBC5_BANKL], a
            ld a, b
            pop bc
            ret
pal_apply:  ld hl, cgb_pal                  ; (V-Blank / LCD off) BG 0-3, OBJ 0-3, BG 7
            ld a, $80
            ldh [rBCPS], a
            ld b, 32
.b:         ld a, [hl+]
            ldh [rBCPD], a
            dec b
            jr nz, .b
            ld a, $80
            ldh [rOCPS], a
            ld b, 32
.o:         ld a, [hl+]
            ldh [rOCPD], a
            dec b
            jr nz, .o
            ld a, $80 | 7 * 8
            ldh [rBCPS], a
            ld b, 8
.w:         ld a, [hl+]
            ldh [rBCPD], a
            dec b
            jr nz, .w
            ret
pal_black:  ld a, $80                       ; all palettes black (V-Blank)
            ldh [rBCPS], a
            ld b, 64
            xor a
.b:         ldh [rBCPD], a
            dec b
            jr nz, .b
            ld a, $80
            ldh [rOCPS], a
            ld b, 64
            xor a
.o:         ldh [rOCPD], a
            dec b
            jr nz, .o
            ret
soft_reset: jp sreset

; the field's random number for the menu (m_rnd), FF3's (3E/C711)
f_rnd_m:    call rnd_fld
            ld [m_rnd], a
            ret
; FF3's gil at most 9,999,999 ($98967F)
gil_cap:    ld hl, SR_GIL + 2
            ld a, [hl]
            cp $98
            ret c
            jr nz, .cap
            dec hl
            ld a, [hl]
            cp $96
            ret c
            jr nz, .cap
            dec hl
            ld a, [hl]
            cp $80
            ret c
.cap:       ld hl, SR_GIL
            ld a, $7F
            ld [hl+], a
            ld a, $96
            ld [hl+], a
            ld a, $98
            ld [hl], a
            ret

; ---- a full screen of the kept modules (the main menu): the field's RAM kept, their interrupt
; mode, then the map again (FF3 3F/E356 reload map, 3E/C27C reload world map)
menu_run:   xor a
            ld [z23], a
            ld [z22], a
            ld [z24], a
            ld [z25], a
            ld hl, m_main
            ld b, B_MENU
full_run:   push hl
            push bc
            call lcd_off
            call fr_enter
            pop bc
            pop hl
            ld a, b
            call far_call
            call lcd_off
            call fr_leave
            jp fr_reload
; the field's RAM into WRAM bank 3, the kept modules' interrupt mode
fr_enter:   xor a
            ld [box_on], a
            ldh a, [rLCDC]
            res 5, a
            ldh [rLCDC], a
            ld a, 3
            ldh [rSVBK], a
            ld hl, $C900
            ld de, SV_KEEP
            ld bc, $0600
            call memcpy
            ld a, 1
            ldh [rSVBK], a
            ld hl, C_WINPAL                 ; (BG palette 7 for their windows)
            ld de, cgb_pal + 64
            ld bc, 8
            ld a, COMMON
            call far_copy
            ld a, 1
            ldh [bmode], a
            xor a
            ldh [c_split], a
            ldh [guard_on], a
            ld a, LCDC_ON | $40
            ldh [rLCDC], a
            ret
; the field's mode and RAM back
fr_leave:   di
            xor a
            ldh [bmode], a
            ldh [c_split], a
            ldh [guard_on], a
            ldh [snd_isr], a
            ld a, BOX_LINES - 1
            ldh [rLYC], a
            ld a, $40
            ldh [rSTAT], a
            xor a
            ldh [rSCX], a
            ldh [rSCY], a
            ld a, 3
            ldh [rIE], a
            ei
            ld a, 3
            ldh [rSVBK], a
            ld hl, SV_KEEP
            ld de, $C900
            ld bc, $0600
            call memcpy
            ld a, 1
            ldh [rSVBK], a
            ld hl, C_WINPAL
            ld a, COMMON
            ld de, sh_pal + 56
            ld bc, 8
            jp far_copy
; the map again: the world map, or FF3 reload map (A = 1: the npcs kept)
fr_reload:  xor a
            ld [t44], a
            ldh a, [maptype]
            and a
            jp nz, world_load
            ld a, 1
            jp load_map

; ---- FF3 battle from the field (3F/E26E: flash, the default battle background, the battle, the
; map reloaded): A = the battle id (z6A); the background from 39/BC00 (world 0) / BD00 by map
battle_runw:                                ; (the world map: the background from the tile
            ld a, [px]                      ;   underfoot's second property byte, 3E/C1A0)
            ld e, a
            ld a, [py]
            ld d, a
            call tile_props
            ld a, [t45]
            ld [bs_bg], a
            ld a, [z6A]
            ld [bs_id], a
            jr battle_go
battle_run: ld [bs_id], a
            ld a, [cur_map]
            ld e, a
            ld d, 0
            ld hl, $BC00 - $4000
            ld a, [world]
            and a
            jr z, .b
            ld hl, $BD00 - $4000
.b:         add hl, de
            ld a, B_BDAT3
            call far_byte
            ld [bs_bg], a
battle_go:  ld a, [world]                   ; (+ $100 off world 0: batscr's bs_setup)
            and a
            ld a, 0
            jr z, .w
            inc a
.w:         ld [bs_id + 1], a
            call lcd_off
            call fr_enter
            ld hl, bs_battle
            ld a, B_BSCR
            call far_call
            call lcd_off
            call fr_leave
            jp fr_reload

section wram, $DF00                         ; (WRAM bank 1)
cgb_pal:    ds 72                           ; the battle's palettes (BG 0-3, OBJ 0-3, BG 7)
section wram, $C5C0                         ; (battle only; the STAT interrupt reads them)
wv_tab:     ds 16
wv_ph:      ds 1

section hram, $FFE0
mapbank:    ds 1                            ; the bank mapped now (the sound maps it back)
snd_isr:    ds 1                            ; the sound in the V-Blank handler (a battle's loads)
is_gba:     ds 1
bmode:      ds 1                            ; 1: a battle's interrupt mode
guard_on:   ds 1
fc_save:    ds 1
c_split:    ds 1
c_lyb:      ds 1
soft_rst:   ds 1
