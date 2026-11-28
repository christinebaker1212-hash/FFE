; ---- battle helpers used by both battle code banks (bank 0): FF3 zero page pointers, random
; numbers, multiply / divide, the battle data reads. Constants of the battle modules first.
BZ         = $D000              ; FF3 zero page in battle
W7         = $6000              ; FF3 $7200-$7EFF + W7
BD_BATTLE  = $5000              ; BDATA_BANK: 2E/8000 battles (monster set, count id)
BD_SET     = $5400              ;   2E/8400 monster sets (palettes 2, monster ids 4)
BD_COUNT   = $5A00              ;   2E/8A00 counts (min / max nibbles, 4 types)
BD_GPROP   = $5B00              ;   2E/8B00 monster graphics properties
BD_PAL     = $5C00              ;   2E/8C00 battle palettes (3 colours)
BD3_BTMAP  = $4000              ; BDATA3_BANK: 2A/8000 boss tilemaps (216 bytes)
BD3_BPTR   = $6000              ;   2E/9068 boss graphics pointers
BD_8F00    = $5F00              ;   2E/8F00-8FFF boss flags, attribute data
BD_2F      = $6000              ;   2F/A4A4.. (placement tables)
BD_GPAL    = $6400              ;   00/9100, 9200, 9300 general use palettes
TB_PPU     = BD_2F + $00        ;   2F/A4A4 monster graphics ppu addresses
TB_GFX     = BD_2F + $10        ;   2F/A4B4 graphics address / bank / size by size class
TB_SIZE    = BD_2F + $28        ;   2F/A4CC width, height by size id
TB_TYPES   = BD_2F + $36        ;   2F/A4DA monster types in each tilemap
TB_POS     = BD_2F + $142       ;   2F/A5E6 position data pointers (NES addresses)
BD2_MON    = $4000              ; BDATA2_BANK: FF3 bank $30 at $4000: 30/8000 monster properties
BD2_STAT   = $5000              ;   30/9000 stat sets (3 bytes)
BD2_SPEC   = $5200              ;   30/9200 special attack scripts (8 bytes)
JB_MODS    = $5B1A              ; JOB_BANK (FF3 bank $39, NES $A000, at $4000): 39/BB1A job modifiers
BD2_ATK    = $58C0              ; BDATA2: 30/98C0 attack properties (8 bytes)
BD2_ITEM   = $5400              ; BDATA2: 30/9400 weapon / armour properties (8 bytes)
EQ_P       = W7 + $7400         ; the five items' properties (helmet .. left hand)
BD_TERR    = $7500              ; BDATA: 01/A24E terrain attacks by map (two nibbles)
BD_TERRT   = $7600              ;   35/AB06 terrain targeting (a bit each)
BD_ITSPL   = BD_2F + $3D0       ;   2E/91A0 the spell an item casts ($98-$C7)
BD_ITMUL   = $7610              ;   01/A35E item multipliers ($A6-$C7)
BD_MITEMS  = $7100              ; BDATA: 10/9B80 monster item sets (8 bytes)
BD_MEXPID  = $7200              ;   10/9C80 monster experience id
BD_MEXP    = $7300              ;   10/9D80 experience values (2 bytes)
BD2_GOLD   = $5C58              ; BDATA2: 30/9C58 monster gold (2 bytes)
JB_CP      = $52AE              ; JOB_BANK: 39/B2AE monster capacity
JB_LVEXP   = $40B0              ;   39/A0B0 experience by level (3 bytes)
JB_LVBON   = $41D6              ;   39/A1D6 level up bonuses (job x 196 + level x 2)
REFL_T     = BD_2F + $3B0       ; 31/BB0E (build.py)
MAGMSG_T   = BD_2F + $3C0       ; 35/A5FD (build.py)
SCRIPTS    = BD_2F + $2A0       ; 34/950D (build.py): script pointers, scripts, types at +$68
SCR_TYPES  = SCRIPTS + $68      ; 34/9575: battle message variable types (nibbles)
ROWTAB     = BD_2F + $340       ; 34/8739: monster rows by tilemap id (build.py)
NUM_OAM    = oam_buf + 4 * 24   ; sprites 24-39 (the hand is hidden while actions run)
ARROW      = $CA
; the battle windows' strings (btlvwf.s bv_put): flags
BVF_R      = $08                ; flags: right-aligned
BVF_C      = $10                ;   centred
BVP_W      = 4                  ; palettes: white (and the frames), yellow, label (4-6: the menus'
BVP_Y      = 5                  ;   gradient writes colour 2 of BG palettes 1-6)
BVP_L      = 6
BVP_G      = 6
BD_CMDS    = BD_2F + $240       ; 34/9B21: 4 battle commands a job (build.py)
HAND_T     = $60                ; the hand cursor (VRAM bank 1; loaded again after the spells, btlui.s)
NUM_T      = $40                ; numeral sprite tiles in VRAM bank 1 ($40-$49 digits, $4A-$4C Miss)
BTXT_IDX   = $4000              ; BTXT_BANK: 3 bytes a battle string ($0400 + index)
BCV_BUF    = win_buf            ; (bank 0, the field's dialogue box buffer: 4 lines x 20)
TS_GRID    = BD_2F + $360       ; 32/9EAD (build.py)
TB_A2D0    = BD_2F + $20C       ; 2F/A2D0: first tile of each monster type (build.py)
BT_ROWS    = 14
BD_ROWX    = BD_2F + $220       ; 2F/B516: x by row (front, back; back attack +2)
BD_START   = BD_2F + $224       ; 2F/B51A: start x 4, y 4 (back attack + 8)
BD_SPR     = $6800              ; 32/9100-97FF
SP_TMPL    = BD_SPR + $CB       ; 32/91CB template pointers (NES addresses)
SP_IDX     = BD_SPR + $16B      ; 32/926B template id by frame (flipped: + $15)
SP_OFS     = BD_SPR + $195      ; 32/9295 tile offset by member
SP_FRAME   = BD_SPR + $62E      ; 32/972E 6 tiles a frame
PARTY_OAM  = oam_buf            ; sprites 0-23 (6 a member)

; a byte of BDATA_BANK at HL
bd_rd:      ld a, BDATA_BANK
            jp rd_byte


; FFCF5: (BZ+$18:$19) * (BZ+$1A:$1B) -> BZ+$1C..$1F (32 bits)
bmul16:      ld a, [BZ + $18]
            ld e, a
            ld a, [BZ + $19]
            ld d, a
            ld a, [BZ + $1A]
            ld c, a
            ld a, [BZ + $1B]
            ld b, a
            ld hl, 0                        ; HL:IX-less: hi word in HL, lo word in btl_lo
            xor a
            ld [btl_lo], a
            ld [btl_lo + 1], a
            ld a, 16
            ld [btl_n2], a
.l:         srl b                           ; (BC >> 1, bit 0 -> carry)
            rr c
            jr nc, .s
            add hl, de
.s:         rr h                            ; (HL:lo) >> 1 with the carry in
            rr l
            ld a, [btl_lo + 1]
            rra
            ld [btl_lo + 1], a
            ld a, [btl_lo]
            rra
            ld [btl_lo], a
            ld a, [btl_n2]
            dec a
            ld [btl_n2], a
            jr nz, .l
            ld a, [btl_lo]
            ld [BZ + $1C], a
            ld a, [btl_lo + 1]
            ld [BZ + $1D], a
            ld a, l
            ld [BZ + $1E], a
            ld a, h
            ld [BZ + $1F], a
            ret


; FFC92: (BZ+$18:$19) / (BZ+$1A:$1B) -> quotient BZ+$1C:$1D, remainder BZ+$1E:$1F
bdiv16:      xor a
            ld [BZ + $1C], a
            ld [BZ + $1D], a
            ld [BZ + $1E], a
            ld [BZ + $1F], a
            ld a, [BZ + $18]
            ld e, a
            ld a, [BZ + $19]
            ld d, a
            or e
            ret z
            ld a, [BZ + $1A]
            ld c, a
            ld a, [BZ + $1B]
            ld b, a
            or c
            ret z
            ld hl, 0                        ; remainder
            ld a, 16
            ld [btl_n2], a
            xor a
            ld [btl_lo], a                  ; quotient
            ld [btl_lo + 1], a
.l:         sla e                           ; (FF3 rotates the carry of the last step in: the
            rl d                            ;   quotient bits; the dividend's bits out)
            rl l
            rl h
            ld a, l
            sub c
            ld l, a
            ld a, h
            sbc b
            ld h, a
            jr nc, .ok
            add hl, bc
            scf
.ok:        ccf                             ; (quotient bit: 1 if the subtraction held)
            ld a, [btl_lo]
            rla
            ld [btl_lo], a
            ld a, [btl_lo + 1]
            rla
            ld [btl_lo + 1], a
            ld a, [btl_n2]
            dec a
            ld [btl_n2], a
            jr nz, .l
            ld a, [btl_lo]
            ld [BZ + $1C], a
            ld a, [btl_lo + 1]
            ld [BZ + $1D], a
            ld a, l
            ld [BZ + $1E], a
            ld a, h
            ld [BZ + $1F], a
            ret


; FFCD6 / FF8EA: A * X (8 x 8) -> A = low, X(B) = high
bmul8:       ld e, a
            ld d, 0
            ld hl, 0
            ld a, b
            ld c, 8
.l:         srl a
            jr nc, .s
            add hl, de
.s:         sla e
            rl d
            dec c
            jr nz, .l
            ld b, h
            ld a, l
            ret


; FFBEF random (X..A): X in B, A = max; counter BZ+$21 selects $15 / $16 / $17
rnd_xa:     ld c, a
            ld a, b
            ld [BZ + $20], a
            cp $FF
            jr nz, .a
            ld a, b
            and a
            jr nz, .x
.a:         ld a, c
            and a
            ret z
            cp b
            ret z
            sub b
            ld [BZ + $18], a
            ld a, $80
            ld [BZ + $1A], a
            xor a
            ld [BZ + $19], a
            ld a, [BZ + $21]                ; rng counter (+1)
            add a, low(BZ + $15)
            ld l, a
            ld h, high(BZ + $15)
            ld a, [hl]
            inc [hl]
            add a, low(W7 + $7BE3)
            ld l, a
            ld h, high(W7 + $7BE3)
            jr nc, .t
            inc h
.t:         ld a, [hl]
            ld [BZ + $1B], a
            call bmul16
            ld a, [BZ + $1E]
            ld b, a
            ld a, [BZ + $1D]
            bit 7, a
            jr z, .r
            inc b
.r:         ld a, [BZ + $20]
            add a, b
            ret
.x:         ld a, b                         ; (X = $FF, A <> 0: returns X)
            ret


; A = zero page offset of a pointer, C = Y -> HL = pointer + Y (BC, DE kept)
zpy:        push de
            ld e, a
            ld d, high(BZ)
            ld a, [de]
            ld l, a
            inc e
            ld a, [de]
            ld h, a
            ld e, c
            ld d, 0
            add hl, de
            pop de
            ret

; A = zero page offset: [pointer] += $40 (16 bits)
zpadd40:    ld l, a
            ld h, high(BZ)
            ld a, [hl]
            add a, $40
            ld [hl+], a
            ret nc
            inc [hl]
            ret

; set pointer at zero page offset A to HL
zpset:      push de
            ld e, a
            ld d, high(BZ)
            ld a, l
            ld [de], a
            inc e
            ld a, h
            ld [de], a
            pop de
            ret


; 31/BE90 get character offset: $5F = $52 * $40 (A)
chr_ofs:    ld a, [BZ + $52]
            rrca
            rrca
            and $C0
            ld [BZ + $5F], a
            ret


; 31/BEB4 random (0..A) with counter 1
rnd_0a:     ld c, a
            ld a, 1
            ld [BZ + $21], a
            ld b, 0
            ld a, c
            jp rnd_xa


; FFD20 / FFD24: A = $80 >> A (the "set bit" table)
bitmask:    ld b, a
            ld a, $80
            inc b
.s:         dec b
            ret z
            rrca
            jr .s


; HL = $7575 + 64 A
rec_ptr:    rrca
            rrca
            ld l, a
            and $C0
            ld e, a
            ld a, l
            and 3
            ld d, a
            ld hl, W7 + $7575
            add hl, de
            ret


; 35/A42E get attacker flags: A = [$6E] + $2C (HL there)
atk_flags:  ld c, $2C
            ld a, $6E
            call zpy
            ld a, [hl]
            ret


; 31/BC25 get target flags (A, HL = target + $2C)
tgt_flags:  ld c, $2C
            ld a, $70
            call zpy
            ld a, [hl]
            ret


; $24 = the attacker / the target
at_ptr:     ld a, [BZ + $6E]
            ld [BZ + $24], a
            ld a, [BZ + $6F]
            ld [BZ + $25], a
            ret

tg_ptr:     ld a, [BZ + $70]
            ld [BZ + $24], a
            ld a, [BZ + $71]
            ld [BZ + $25], a
            ret


; DE = DE / 10, A = DE mod 10
b_div10:    ld hl, 0
            ld b, 16
.l:         sla e
            rl d
            rl l
            ld a, l
            sub 10
            jr c, .n
            ld l, a
            inc e
.n:         dec b
            jr nz, .l
            ld a, l
            ret



; ---- the 8 x 16 sprite mode (battle magic, btlfx.s): WRAM bank 5 holds the OAM ($D000) and a
; mirror of VRAM bank 1 tiles $00-$7F ($D800), bank 6 the composed tile pairs (32 bytes a pair ->
; VRAM bank 1 tiles 2 n)
s16_vbl:    ld a, [s16_lock]                ; (being built: the last picture stays)
            and a
            ret nz
            ldh a, [rLCDC]
            set 2, a
            ldh [rLCDC], a
            ldh a, [rSVBK]
            push af
            ld a, 5
            ldh [rSVBK], a
            call hram_dma16
            ld a, [s16_lo]                  ; dirty pairs lo..hi-1 (WRAM 6): at most 24 a V-Blank
            ld b, a
            ld a, [s16_hi]
            sub b
            jr z, .x
            jr c, .x
            cp 24
            jr c, .n
            ld a, 24
.n:         ld c, a
            ldh a, [rLY]                    ; (late in the V-Blank: the next one - Lot Check)
            cp 149
            jr nc, .x
            ld a, 6
            ldh [rSVBK], a
            ld l, b
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            push hl
            ld de, S16_STG
            add hl, de
            ld a, h
            ldh [rHDMA1], a
            ld a, l
            ldh [rHDMA2], a
            pop hl                          ; (VRAM $8000 + 32 slot)
            ld a, h
            or $80
            ldh [rHDMA3], a
            ld a, l
            ldh [rHDMA4], a
            ld a, 1
            ldh [rVBK], a
            ld a, c
            add a, a
            dec a
            ldh [rHDMA5], a
            xor a
            ldh [rVBK], a
            ld a, b
            add a, c
            ld [s16_lo], a
.x:         pop af
            ldh [rSVBK], a
            ret
; sprite tiles loaded in the 8 x 16 mode (B tiles at VRAM DE): the slots composed from them out of
; date (their keys emptied); the party paired again (its slots looked up again)
s16_inv:    ld a, d
            and $0F
            swap a
            ld c, a
            ld a, e
            swap a
            and $0F
            or c
            ld c, a                         ; C = the first tile
            ld a, b
            and a
            jr nz, .n
            ld a, $80
.n:         ld b, a                         ; B = tiles
            ldh a, [rSVBK]
            push af
            ld a, 5
            ldh [rSVBK], a
            ld hl, S16_K0
            ld e, 64
.k:         ld a, [hl]
            sub c
            cp b
            jr c, .x
            ld a, l
            add a, $80
            ld l, a
            ld a, [hl]
            sub c
            cp b
            ld a, l
            res 7, l
            jr nc, .nx
.x:         ld [hl], $FF
.nx:        inc l
            dec e
            jr nz, .k
            pop af
            ldh [rSVBK], a
            ld a, $FF
            ldh [s16_pp], a
            ret
; vcopy's VRAM bank 1 sprite tiles (DE < $8800) -> the mirror too (WRAM 6; B tiles from HL; a
; source in $D000- (WRAM 3) copied 2 bytes at a time)
s16_mir:    push bc
            push de
            push hl
            ld a, d
            add a, high(S16_MIR) - $80
            ld d, a
            ldh a, [rSVBK]
            ld c, a
.t:         push bc
            ld b, 8
.r:         ld a, [hl+]
            push af
            ld a, [hl+]
            push af
            ld a, 6
            ldh [rSVBK], a
            pop af
            inc de
            ld [de], a
            dec de
            pop af
            ld [de], a
            inc de
            inc de
            ld a, c
            ldh [rSVBK], a
            dec b
            jr nz, .r
            pop bc
            ld a, d
            cp $E0
            jr nc, .x
            dec b
            jr nz, .t
.x:         pop hl
            pop de
            pop bc
            ret

; a call into the other battle bank (from a stub: [fx_a] = A, [fx_t] = the routine, A = its
; bank): A, BC, DE passed; A, F, BC, DE, HL returned; the caller's bank back
; the compact stubs: call far_s / db bank / dw routine (A, BC, DE passed; A, F, HL returned)
far_s:      ld [fx_a], a
            pop hl
            ld a, [hl+]
            push af
            ld a, [hl+]
            ld [fx_t], a
            ld a, [hl]
            ld [fx_t + 1], a
            pop af
far_x:      ld [fx_b], a
            ld a, [code_bank]
            push af
            ld a, [fx_b]
            ld [code_bank], a
            ld [MBC5_BANKL], a
            ld a, [fx_t]
            ld l, a
            ld a, [fx_t + 1]
            ld h, a
            ld a, [fx_a]
            call .jp
            push af
            push hl
            ld hl, sp + 5
            ld a, [hl]
            ld [code_bank], a
            ld [MBC5_BANKL], a
            pop hl
            pop af
            inc sp
            inc sp
            ret
.jp:        jp hl

section wram, $DF60
fx_a:       ds 1
fx_t:       ds 2
fx_b:       ds 1
