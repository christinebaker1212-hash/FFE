; FF3 normal maps on the Game Boy Color (first step: one map drawn, no walking yet).
; A map's data bank (made by tools/gb3n/build.py from the user's ROM):
;   $4000 the 256 BG tiles (Game Boy format)       $5000 metatile corner tiles UL, UR, DL, DR
;   $5200 metatile palette (CGB attribute byte)     $5300 the four BG palettes (RGB555)
;   $5400 the 32 x 32 metatile map (decompressed)   $5800 start x, y; $5802 fill metatile

M_TILES    = $4000
M_QUAD     = $5000
M_ATTR     = $5200
M_PALS     = $5300
M_MAP      = $5400
M_START    = $5800
M_FILL     = $5802
VIEW_X     = 4              ; the party's metatile column / row on screen (10 x 9 visible)
VIEW_Y     = 4

section bank 0, $2800

; draw map bank A whole (LCD off): palettes, tiles, the 16 x 16 metatiles of the BG ring
map_show:   ld [MBC5_BANKL], a
            ld a, $80
            ldh [rBCPS], a
            ld hl, M_PALS
            ld b, 32
.pl:        ld a, [hl+]
            ldh [rBCPD], a
            dec b
            jr nz, .pl
            xor a
            ldh [rVBK], a
            ld hl, M_TILES
            ld de, $8000
            ld bc, $1000
            call memcpy
            ld a, [M_START]
            sub VIEW_X
            ld [cam_x], a
            ld a, [M_START + 1]
            sub VIEW_Y
            ld [cam_y], a
            ld c, 0                         ; C = row in the view (0-15)
.row:       ld b, 0                         ; B = column
.col:       push bc
            ld a, [cam_x]
            add b
            ld d, a                         ; D = map x
            ld a, [cam_y]
            add c
            ld e, a                         ; E = map y
            call map_cell
            pop bc
            inc b
            ld a, b
            cp 16
            jr nz, .col
            inc c
            ld a, c
            cp 16
            jr nz, .row
            ld a, [cam_x]                   ; scroll: the ring position of the camera
            and 15
            swap a
            ldh [rSCX], a
            ld a, [cam_y]
            and 15
            swap a
            ldh [rSCY], a
            ret

; the metatile at map (D, E) into its BG ring cell (LCD off or in V-Blank)
map_cell:   ld a, d                         ; outside the 32 x 32 map: the fill metatile
            or e
            and $E0
            ld a, [M_FILL]
            jr nz, .got
            ld a, e                         ; HL = M_MAP + 32 * y + x
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld a, l
            add d
            ld l, a
            ld a, h
            adc high(M_MAP)
            ld h, a
            ld a, [hl]
.got:       and $7F
            ld [mt_cur], a
            ld a, e                         ; VRAM address $9800 + 64 * (y & 15) + 2 * (x & 15)
            and 15
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld a, d
            and 15
            add a
            add l
            ld l, a
            ld a, h
            adc $98
            ld h, a
            ld a, [mt_cur]                  ; the four corner tiles (VRAM bank 0)
            ld c, a
            ld b, high(M_QUAD)
            ld a, [bc]
            ld [hl+], a
            ld a, c
            add $80
            ld c, a
            ld a, [bc]
            ld [hl], a
            ld a, l
            add 31
            ld l, a
            inc b
            ld a, [mt_cur]
            ld c, a
            ld a, [bc]
            ld [hl+], a
            ld a, c
            add $80
            ld c, a
            ld a, [bc]
            ld [hl], a
            ld a, l                         ; the palette for all four (VRAM bank 1)
            sub 33
            ld l, a
            ld a, [mt_cur]
            ld c, a
            ld b, high(M_ATTR)
            ld a, [bc]
            and 3
            ld b, a
            ld a, 1
            ldh [rVBK], a
            ld a, b
            ld [hl+], a
            ld [hl], a
            ld a, l
            add 31
            ld l, a
            ld a, b
            ld [hl+], a
            ld [hl], a
            xor a
            ldh [rVBK], a
            ret

section wram, $C100
cam_x:      ds 1
cam_y:      ds 1
mt_cur:     ds 1
