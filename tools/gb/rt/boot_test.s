; Milestone 1 boot test: header, vectors, LCD init, tile pattern, vblank counter.
section bank 0, $0040
        jp vblank
section bank 0, $0100
        nop
        jp start
section bank 0, $0150
start:  di
        ld sp, $E000
.wait:  ldh a, [rLY]            ; LCD may only be turned off in vblank
        cp 144
        jr c, .wait
        xor a
        ldh [rLCDC], a
        ld hl, $8000            ; clear VRAM
        ld bc, $2000
.clr:   xor a
        ld [hl+], a
        dec bc
        ld a, b
        or c
        jr nz, .clr
        ld hl, $8010            ; tile 1: checkerboard in colours 1/2, tile 2: solid colour 3
        ld de, tiles
        ld b, 32
.cp:    ld a, [de]
        inc de
        ld [hl+], a
        dec b
        jr nz, .cp
        ld hl, $9800            ; BG map: alternate tiles 1/2 with a diagonal stripe
        ld c, 0
.row:   ld b, 32
.col:   ld a, b
        add a, c
        and 1
        inc a
        ld [hl+], a
        dec b
        jr nz, .col
        inc c
        ld a, c
        cp 32
        jr nz, .row
        ld a, $0A               ; enable cart RAM, write a signature
        ld [MBC5_RAMG], a
        xor a
        ld [MBC5_RAMB], a
        ld a, $5A
        ld [$A000], a
        ld a, %11100100
        ldh [rBGP], a
        ld a, %10010001         ; LCD on, BG tiles at $8000, BG on
        ldh [rLCDC], a
        xor a
        ld [frames], a
        ldh [rIF], a
        ld a, 1
        ldh [rIE], a
        ei
.idle:  halt
        jr .idle

vblank: push af
        ld a, [frames]
        inc a
        ld [frames], a
        pop af
        reti

tiles:  db $AA, $55, $55, $AA, $AA, $55, $55, $AA, $AA, $55, $55, $AA, $AA, $55, $55, $AA
        db $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF

section wram, $C000
frames: ds 1
