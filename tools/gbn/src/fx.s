; FF1 native engine: raster spell effects in battle (owner's list, 2026-11-24). While a spell's
; burst plays on an enemy, the enemy area (screen lines 0-95) moves by line, by the spell's
; element (FF1's magic data byte 2): fire a heat ripple, ice a shiver, lightning jagged tears,
; earth a quake, anything else (Nuke, death, status) a slow wave. Only the background moves (the
; bursts are sprites). A mode-0 STAT interrupt per line writes the next line's SCX / SCY from
; tables made each frame in bank BTL6_BANK; from line 96 the battle's own STAT interrupt (the
; music's line). The top name window closes first (it uses the window's line split).
; That moves whole lines: used only for a fiend / Chaos (alone on the field). Any other target
; (owner, 2026-11-24: a spell's effect on its target only) gets its own ripple: its cells are
; switched to copies of its tiles (FXT_* below) and each pass shifts the copies' pixel rows
; by the element's offsets, the source rows kept in RAM (DMG: the unused attribute copy; the
; Color: WRAM bank 2); the V-Blank uploads up to 10 tiles a frame; the cells back at the end.
FX_SCX     = $C300          ; per line (96; the field's queue: free in battle)
FX_SCY     = $C360
FX_N       = 96

section bank 0, $293C
; a spell's raster effect on (A = its element bits) / off; each frame its tables
fx_start:   ld [fx_el], a
            xor a
            ld [fx_ph], a
            call bt_ban_off
            ld a, [bt_type]                 ; (a fiend / Chaos: the lines; else its tiles)
            cp 3
            jr c, .t
            ld a, BTL6_BANK
            ld hl, fx_fill
            call bank_call
            ld a, 1
            ld [fx_on], a
            ret
.t:         ld a, BTL6_BANK                 ; (fl_b / fl_c / fl_e: the target's cell, size)
            ld hl, fxt_init
            call bank_call
            ld a, 2
            ld [fx_on], a
            ret
fx_stop:    ld a, [fx_on]
            and a
            ret z
            cp 2
            jr z, .t
            xor a
            ld [fx_on], a
            inc a
            ld [fx_rest], a
            ret
.t:         xor a                           ; (the uploads stop first: the V-Blank reads fx_on)
            ld [fx_on], a
            ld a, BTL6_BANK
            ld hl, fxt_rest
            jp bank_call
fx_tick:    ld a, [fx_on]                   ; (from wait_vbl: every register kept)
            and a
            ret z
            push af
            push bc
            push de
            push hl
            cp 2
            jr z, .t
            ld hl, fx_ph
            inc [hl]
            ld a, BTL6_BANK
            ld hl, fx_fill
            call bank_call
            jr .x
.t:         ld a, BTL6_BANK
            ld hl, fxt_step
            call bank_call
.x:
            pop hl
            pop de
            pop bc
            pop af
            ret
section bank 0, $1380                       ; (bank 0 continued)
; V-Blank: line 0, the per-line interrupt (or the battle's STAT back)
fx_vbl:     ld a, [fx_rest]
            and a
            jr nz, .rest
            ld a, [fx_on]
            and a
            ret z
            cp 2
            jp z, fxt_vbl
            xor a
            ld [fx_done], a
            ld a, [FX_SCX]
            ldh [rSCX], a
            ld a, [FX_SCY]
            ldh [rSCY], a
            ld a, [FX_SCX + 1]
            ld [fx_nx], a
            ld a, [FX_SCY + 1]
            ld [fx_ny], a
            ld a, $08
            ldh [rSTAT], a
            ldh a, [rIF]
            and $FD
            ldh [rIF], a
            ei
            ret
.rest:      xor a
            ld [fx_rest], a
            ld a, $40
            ldh [rSTAT], a
            ld a, BOX_LINES - 1
            ldh [rLYC], a
            ldh a, [scx]
            ldh [rSCX], a
            ldh a, [scy]
            ldh [rSCY], a
            ret
section bank 0, $0068                       ; (bank 0 continued)
; STAT mode 0 at the end of line LY: line LY + 1's scroll (ready), then the next line's
stat_fx:    ld a, [fx_nx]
            ldh [rSCX], a
            ld a, [fx_ny]
            ldh [rSCY], a
            push hl
            ldh a, [rLY]
            add a, 2
            cp FX_N + 1
            jr nc, .end
            cp FX_N
            jr nc, .last
            ld l, a
            ld h, high(FX_SCX)
            ld a, [hl]
            ld [fx_nx], a
            ld a, l
            add a, FX_N
            ld l, a
            ld a, [hl]
            ld [fx_ny], a
            pop hl
            pop af
            reti
.last:      ldh a, [scx]                    ; (line 96 on: the battle's own scroll)
            ld [fx_nx], a
            ldh a, [scy]
            ld [fx_ny], a
            pop hl
            pop af
            reti
.end:       ld a, 1
            ld [fx_done], a
            ld a, $40
            ldh [rSTAT], a
            ld a, 100
            ldh [rLYC], a
            ldh a, [rIF]
            and $FD
            ldh [rIF], a
            pop hl
            ld a, [mus_pend]                ; (a music tick held for this line)
            and a
            jr z, .mx
            dec a
            ld [mus_pend], a
            call mus_tick
.mx:        pop af
            reti

section bank 104, $5000
; this frame's tables by the element: offsets added to the battle's scroll (scx / scy)
fx_fill:    ld hl, FX_SCX
            ld c, 0                         ; line
.l:         push hl
            call fx_line                    ; D = x offset, E = y offset for line C
            pop hl
            ldh a, [scx]
            add a, d
            ld [hl], a
            push hl
            ld a, l
            add a, FX_N
            ld l, a
            ldh a, [scy]
            add a, e
            ld [hl], a
            pop hl
            inc l
            inc c
            ld a, c
            cp FX_N
            jr c, .l
            ret
; C = line -> D, E (signed offsets)
fx_line:    ld e, 0
            ld a, [fx_el]
            bit 7, a
            jr nz, .earth
            bit 6, a
            jr nz, .bolt
            bit 4, a
            jr nz, .fire
            bit 5, a
            jr nz, .ice
            ld a, [fx_ph]                   ; a slow wave, wide
            add a, a
            add a, a
            add a, c
            ld b, 3
            jr .sin
.fire:      ld a, [fx_ph]                   ; heat: fast ripples
            ld b, a
            add a, a
            add a, b
            ld b, a
            ld a, c
            add a, a
            add a, b
            ld b, 2
            jr .sin
.ice:       ld a, [fx_ph]                   ; shiver: lines one pixel apart, flipping
            add a, c
            and 1
            ld d, 1
            ret z
            ld d, -1
            ret
.bolt:      ld a, c                         ; tears: 4-line bands jumping each frame
            and $FC
            ld b, a
            ld a, [fx_ph]
            swap a
            xor b
            ld l, a
            ld h, high(fx_rnd)
            ld a, [hl]
            ld d, a
            ret
.earth:     ld d, 0                         ; quake: the whole area up and down
            ld a, [fx_ph]
            and 2
            ld e, 2
            ret z
            ld e, -2
            ret
.sin:       and 31                          ; D = sin(A / 32 turn) x B (B = 2 or 3)
            ld l, a
            ld h, high(fx_sin)
            ld a, [hl]
            ld d, a
            ld a, b
            cp 3
            ret nz
            ld a, d                         ; (x 1.5)
            sra a
            add a, d
            ld d, a
            ret

section bank 104, $5100
fx_sin:     db 0, 0, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 1, 1, 1, 0
            db 0, 0, -1, -1, -1, -2, -2, -2, -2, -2, -2, -2, -1, -1, -1, 0
section bank 104, $5200
fx_rnd:     db 2, -3, 1, 3, -2, 0, -1, 2, 3, -3, -1, 1, 0, -2, 2, -1
            db -3, 1, 3, -1, 0, 2, -2, 3, 1, -3, -2, 0, 2, -1, 3, -2
            db 1, 0, -3, 2, -1, 3, 0, -2, 2, 1, -3, -1, 3, 0, -2, 1
            db -2, 3, 0, -1, 2, -3, 1, 2, -1, 0, 3, -2, 1, -3, 2, 0
            db 3, -1, -2, 1, 0, 2, -3, -1, 2, 3, 0, -2, 1, -1, 3, -3
            db 0, 2, -1, -3, 1, 3, -2, 0, -1, 2, 1, -3, 3, -2, 0, 1
            db -1, -2, 3, 0, 2, -1, 1, -3, 0, 3, -2, 2, -1, 1, -3, 2
            db 2, 1, -2, 3, -3, 0, -1, 1, 3, -2, 2, 0, -3, 1, -1, 3
            db 1, -3, 2, -2, 0, 3, -1, 2, -3, 1, 0, -1, 2, 3, -2, 0
            db -3, 0, 1, 2, -1, -2, 3, 1, 0, -3, 2, -1, 1, 3, -2, 2
            db 0, 3, -2, -1, 2, 1, -3, 0, 3, -1, -2, 2, 0, 1, -3, -1
            db 2, -1, 0, 3, -3, 2, 1, -2, -1, 3, 0, -3, 2, 1, -2, 0
            db -2, 1, 3, -3, 0, -1, 2, 3, -2, 1, -1, 0, 3, -3, 1, 2
            db 3, 0, -1, 2, -2, 1, -3, 0, 1, -2, 3, 2, -1, 0, -3, 1
            db -1, 2, 0, -3, 3, 1, -2, -1, 0, 2, -3, 3, 1, -1, 2, -2
            db 1, -2, 2, 0, -1, -3, 3, 1, -2, 0, 2, -1, -3, 3, 0, 2

section wram, $DACA                         ; (the flags in RAM no screen reuses: the tables'
fx_on:      ds 1                            ;   is the field's queue, free only in battle)
fx_rest:    ds 1
fx_done:    ds 1
fx_el:      ds 1
fx_ph:      ds 1
fx_nx:      ds 1
section wram, $DAFE
fx_ny:      ds 1
section wram, $C7F0
fx_w:       ds 8                            ; one line of the row, one plane (E bytes)

; ---- the target's own ripple (fx_on 2)
FXT_STG    = bt_stage       ; staged tiles (10 x 16), then one tile row of the source (6 x 16)
FXT_TMP    = FX_SCX         ; (fixed RAM: the Color maps WRAM bank 2 at $D000 while copying)
FXT_MAX    = 10             ; tiles a pass step / a V-Blank
section wram, $C3C0                         ; (after the line tables: free in battle)
fxt_sh:     ds 48                           ; this pass's shift per pixel row (signed)
fxt_e:      ds 1                            ; cells a side (4 / 6)
fxt_ty:     ds 1                            ; next tile row to make
fxt_up:     ds 1                            ; staged tiles waiting for V-Blank
fxt_ui:     ds 1                            ; ... the next one
fxt_i:      ds 1
fxt_k:      ds 1
fxt_s:      ds 1
section wram, $C7C0
fxt_orig:   ds 36                           ; the cells' own tiles
fxt_dst:    ds FXT_MAX                      ; staged tiles' copy numbers

section bank 0, $3F30
; V-Blank (fx_on 2): staged tiles to their copies while the V-Blank lasts
fxt_vbl:    ld a, [fxt_up]
            and a
            ret z
            ld a, [bt_upn]                  ; (the battle's own tiles first: its uploads wait
            and a                           ;   for V-Blank time, and the burst for them)
            ret nz
            push bc
            push de
            push hl
.l:         ldh a, [rLY]
            cp 144
            jr c, .x
            cp 150
            jr nc, .x
            ld a, [fxt_ui]
            ld c, a
            add a, low(fxt_dst)
            ld l, a
            ld h, high(fxt_dst)
            ld a, [hl]                      ; DE = the copy's address ($8800 mode)
            ld e, a
            swap a
            and $0F
            ld d, a
            ld a, e
            swap a
            and $F0
            ld e, a
            ld a, [hl]
            bit 7, a
            ld a, $90
            jr z, .lo
            ld a, $80
.lo:        add a, d
            ld d, a
            ld a, c                         ; HL = staged tile c
            swap a
            ld l, a
            and $0F
            add a, high(FXT_STG)
            ld h, a
            ld a, l
            and $F0
            add a, low(FXT_STG)
            ld l, a
            jr nc, .nc
            inc h
.nc:        ld b, 16
.c:         ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .c
            ld hl, fxt_ui
            inc [hl]
            ld a, [fxt_up]
            cp [hl]
            jr nz, .l
            xor a
            ld [fxt_up], a
.x:         pop hl
            pop de
            pop bc
            ret

section bank 104, $5300
; copy number of tile i (A) -> A: $C4-$D7, then $01-$11
fxt_cp:     cp 20
            jr nc, .lo
            add a, $C4
            ret
.lo:        sub 19
            ret
; HL = the source rows of tile A (the Color: $D000 + 16 A in WRAM bank 2; DMG: tiles 0-23 in the
; attribute copy's rows 0-11 (unused without a Color, never written in a burst), 24-35 in the
; gradient's RAM ($D640-$D6FF: the Color's only))
fxt_src:    ld h, a
            ldh a, [is_cgb]
            and a
            ld a, h
            jr nz, .c
            cp 24
            jr c, .s
            sub 24
            call .x16
            ld a, h
            add a, high(gr_ramp)
            ld h, a
            ld a, l
            add a, low(gr_ramp)
            ld l, a
            ret nc
            inc h
            ret
.s:         call .x16
            ld a, h
            add a, high(sattr)
            ld h, a
            ret
.c:         call .x16
            ld a, h
            add a, $D0
            ld h, a
            ret
.x16:       swap a                          ; HL = 16 A
            ld l, a
            and $0F
            ld h, a
            ld a, l
            and $F0
            ld l, a
            ret
; tile A -> HL = its address ($8800 mode, as ed_tadr in bank 99)
fxt_tadr:   ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            bit 7, a
            jr nz, .hi
            ld a, h
            add a, $90
            ld h, a
            ret
.hi:        ld a, h
            add a, $80
            ld h, a
            ret
; until VRAM is open (modes 0 / 1)
fxt_vw:     ldh a, [rSTAT]
            and 2
            jr nz, fxt_vw
            ret
; the target (fl_b, fl_c, fl_e): its tiles to RAM and to the copies, its cells to the copies
fxt_init:   xor a
            ld [fxt_ty], a
            ld [fxt_up], a
            ld [fxt_ui], a
            ld [fxt_i], a
            ld a, [fl_e]
            ld [fxt_e], a
            ld a, [fl_c]
            ld c, a
.r:         ld a, [fl_b]
            ld b, a
            push bc
            call cell_addr                  ; HL = the row's first cell (smap)
            pop bc
            ld a, [fxt_e]
            ld b, a
.c:         push bc
            push hl
            ld a, [hl]                      ; its tile
            push af
            ld a, [fxt_i]
            add a, low(fxt_orig)
            ld e, a
            ld d, high(fxt_orig)
            pop af
            ld [de], a
            call fxt_tadr                    ; HL = the tile's 16 bytes -> FXT_TMP
            ld de, FXT_TMP
            ld b, 8
.rd:        di
            call fxt_vw
            ld a, [hl+]
            ld [de], a
            inc de
            ld a, [hl+]
            ld [de], a
            inc de
            ei
            dec b
            jr nz, .rd
            ld a, [fxt_i]                   ; -> the source store
            call fxt_src
            ld d, h
            ld e, l
            ld hl, FXT_TMP
            ld b, 16
            di
            ldh a, [is_cgb]
            and a
            jr z, .s
            ld a, 2
            ldh [$FF70], a
.s:         ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .s
            ldh a, [is_cgb]
            and a
            jr z, .s1
            ld a, 1
            ldh [$FF70], a
.s1:        ei
            ld a, [fxt_i]                   ; -> its copy
            call fxt_cp
            call fxt_tadr
            ld d, h
            ld e, l
            ld hl, FXT_TMP
            ld b, 8
.wr:        di
            call fxt_vw
            ld a, [hl+]
            ld [de], a
            inc de
            ld a, [hl+]
            ld [de], a
            inc de
            ei
            dec b
            jr nz, .wr
            pop hl                          ; the cell to the copy (smap and the screen)
            push hl
            ld a, [fxt_i]
            call fxt_cp
            ld [hl], a
            ld de, $9800 - smap
            add hl, de
            ld e, a
            di
            call fxt_vw
            ld [hl], e
            ei
            ld hl, fxt_i
            inc [hl]
            pop hl
            inc hl
            pop bc
            dec b
            jr nz, .c
            inc c
            ld a, [fl_c]
            ld b, a
            ld a, [fxt_e]
            add a, b
            cp c
            jr nz, .r
            ret
; the cells back to their own tiles
fxt_rest:   xor a
            ld [fxt_up], a
            ld [fxt_i], a
            ld a, [fl_c]
            ld c, a
.r:         ld a, [fl_b]
            ld b, a
            push bc
            call cell_addr
            pop bc
            ld a, [fxt_e]
            ld b, a
.c:         push hl
            ld a, [fxt_i]
            add a, low(fxt_orig)
            ld e, a
            ld d, high(fxt_orig)
            ld a, [de]
            ld [hl], a
            ld de, $9800 - smap
            add hl, de
            ld e, a
            di
            call fxt_vw
            ld [hl], e
            ei
            ld hl, fxt_i
            inc [hl]
            pop hl
            inc hl
            dec b
            jr nz, .c
            inc c
            ld a, [fl_c]
            ld b, a
            ld a, [fxt_e]
            add a, b
            cp c
            jr nz, .r
            ret
; a step (each frame): once the last tiles are up, the next tile rows staged (a new pass: the
; phase on, the shifts made)
fxt_step:   ld a, [fxt_up]
            ld hl, bt_upn                   ; (the stage is the battle's too: not while its
            or [hl]                         ;   own tiles wait there)
            ret nz
            ld a, [fxt_ty]
            and a
            jr nz, .rows
            ld hl, fx_ph
            inc [hl]
            ld a, [fxt_e]                   ; rows: 8 E
            add a, a
            add a, a
            add a, a
            ld b, a
            ld c, 0
            ld hl, fxt_sh
.sh:        push hl
            push bc
            call fx_line                    ; D = this row's shift (line C)
            pop bc
            pop hl
            ld a, d
            cp 4                            ; (at most 3 either way)
            jr c, .s1
            cp 256 - 3
            jr nc, .s1
            bit 7, a
            ld a, 3
            jr z, .s1
            ld a, 256 - 3
.s1:        ld [hl+], a
            inc c
            dec b
            jr nz, .sh
.rows:      xor a
            ld [fxt_k], a                   ; slots staged
.nr:        ld a, [fxt_e]
            ld b, a
            ld a, [fxt_k]
            add a, b
            cp FXT_MAX + 1
            jr nc, .go
            call fxt_row
            ld a, [fxt_e]
            ld b, a
            ld a, [fxt_k]
            add a, b
            ld [fxt_k], a
            ld a, [fxt_ty]
            inc a
            cp b
            jr c, .n1
            xor a
.n1:        ld [fxt_ty], a
            and a
            jr nz, .nr
.go:        xor a
            ld [fxt_ui], a
            ld a, [fxt_k]
            ld [fxt_up], a                  ; (last: the V-Blank may take them now)
            ret
; tile row fxt_ty -> staged slots fxt_k.. (and their copy numbers)
fxt_row:    ld a, [fxt_e]                   ; first tile: ty x E
            ld b, a
            ld a, [fxt_ty]
            ld c, a
            xor a
.m:         add a, c
            dec b
            jr nz, .m
            ld [fxt_i], a
            call fxt_src                    ; its E tiles' source -> FXT_TMP
            ld a, [fxt_e]
            swap a
            ld b, a                         ; 16 E bytes
            ld de, FXT_TMP
            di
            ldh a, [is_cgb]
            and a
            jr z, .cp
            ld a, 2
            ldh [$FF70], a
.cp:        ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .cp
            ldh a, [is_cgb]
            and a
            jr z, .c1
            ld a, 1
            ldh [$FF70], a
.c1:        ei
            ld a, [fxt_e]                   ; the copy numbers
            ld b, a
            ld a, [fxt_k]
            add a, low(fxt_dst)
            ld l, a
            ld h, high(fxt_dst)
            ld a, [fxt_i]
            ld c, a
.dn:        ld a, c
            call fxt_cp
            ld [hl+], a
            inc c
            dec b
            jr nz, .dn
            ld c, 0                         ; C = byte 0-15 within the tile (line x 2 + plane)
.ln:        ld a, [fxt_ty]                  ; the shift: row 8 ty + line
            add a, a
            add a, a
            add a, a
            ld b, a
            ld a, c
            srl a
            add a, b
            add a, low(fxt_sh)
            ld l, a
            ld h, high(fxt_sh)
            ld a, [hl]
            ld [fxt_s], a
            ld hl, FXT_TMP                  ; the E bytes of this line / plane -> fx_w
            ld a, l
            add a, c
            ld l, a
            ld de, fx_w
            ld a, [fxt_e]
            ld b, a
.g:         ld a, [hl]
            ld [de], a
            inc de
            ld a, l
            add a, 16
            ld l, a
            jr nc, .g1
            inc h
.g1:        dec b
            jr nz, .g
            ld a, [fxt_s]
            and a
            jr z, .put
            bit 7, a
            jr nz, .left
.right:     push af                         ; right: each pass, bit 0 into the next byte's bit 7,
            ld hl, fx_w                     ;   the left edge's pixel kept
            ld a, [hl]
            rlca                            ; (C = the leftmost pixel)
            ld a, [fxt_e]
            ld b, a
.rr:        rr [hl]
            inc hl
            dec b
            jr nz, .rr
            pop af
            dec a
            jr nz, .right
            jr .put
.left:      push af                         ; left: the right edge's pixel kept
            ld a, [fxt_e]
            dec a
            add a, low(fx_w)
            ld l, a
            ld h, high(fx_w)
            ld a, [hl]
            rrca                            ; (C = the rightmost pixel)
            ld a, [fxt_e]
            ld b, a
.rl:        rl [hl]
            dec hl
            dec b
            jr nz, .rl
            pop af
            inc a
            jr nz, .left
.put:       ld a, [fxt_k]                   ; fx_w -> staged slots k.., byte C
            swap a
            add a, c
            ld e, a
            ld d, 0
            ld hl, FXT_STG
            add hl, de
            ld de, fx_w
            ld a, [fxt_e]
            ld b, a
.p:         ld a, [de]
            inc de
            ld [hl], a
            ld a, l
            add a, 16
            ld l, a
            jr nc, .p1
            inc h
.p1:        dec b
            jr nz, .p
            inc c
            ld a, c
            cp 16
            jp c, .ln
            ret
