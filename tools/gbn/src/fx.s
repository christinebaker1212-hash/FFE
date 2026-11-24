; FF1 native engine: raster spell effects in battle (owner's list, 2026-11-24). While a spell's
; burst plays on an enemy, the enemy area (screen lines 0-95) moves by line, by the spell's
; element (FF1's magic data byte 2): fire a heat ripple, ice a shiver, lightning jagged tears,
; earth a quake, anything else (Nuke, death, status) a slow wave. Only the background moves (the
; bursts are sprites). A mode-0 STAT interrupt per line writes the next line's SCX / SCY from
; tables made each frame in bank BTL6_BANK; from line 96 the battle's own STAT interrupt (the
; music's line). The top name window closes first (it uses the window's line split).
FX_SCX     = $C300          ; per line (96; the field's queue: free in battle)
FX_SCY     = $C360
FX_N       = 96

section bank 0, $293C
; a spell's raster effect on (A = its element bits) / off; each frame its tables
fx_start:   ld [fx_el], a
            xor a
            ld [fx_ph], a
            call bt_ban_off
            ld a, BTL6_BANK
            ld hl, fx_fill
            call bank_call
            ld a, 1
            ld [fx_on], a
            ret
fx_stop:    ld a, [fx_on]
            and a
            ret z
            xor a
            ld [fx_on], a
            inc a
            ld [fx_rest], a
            ret
fx_tick:    ld a, [fx_on]                   ; (from wait_vbl: every register kept)
            and a
            ret z
            push af
            push bc
            push de
            push hl
            ld hl, fx_ph
            inc [hl]
            ld a, BTL6_BANK
            ld hl, fx_fill
            call bank_call
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
