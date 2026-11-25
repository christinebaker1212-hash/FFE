; FF1 native engine: "Modern MP" (owner, 2026-11-24; Options, off by default). With it on, magic
; costs MP as in Dawn of Souls instead of FF1's charges per spell level: each spell's cost and each
; job's growth are Dawn of Souls data kept in tools/gbn/modern_mp.py (from the FINAL FANTASY wiki;
; table at MMP_TAB in bank MMP_BANK). A level's MP gain is floor(INT / 4) + 1, plus 10-12 on the job's
; guaranteed strong levels or with a chance of 1 in 8 on the others; Fighter / Thief gain MP only
; as Knight / Ninja, Black Belt / Master never.
;
; Each member's MP lives in the magic page next to FF1's charges (unused by FF1): ch_magic + 64 m
; + $30 current, $32 maximum (16 bits), $34 a mark ($A5: made), $35 the mode the party's MP is
; in (0 charges, 1 MP). The maximum grows at every level up in both modes; switching the mode
; converts the current amount by the same fraction of the whole (charges weighted by the average
; cost of their level), so a party half spent stays half spent. A save made before the option
; gets its maximum estimated from level, job and INT (Knight / Ninja: from their charges).

MMP_BANK   = 105
MMP_TAB    = $7F00          ; (modern_mp.tables(): ok, starting MP, level weights, costs, strong)
MMP_COST   = MMP_TAB + $10
MMP_WT     = MMP_TAB + $08
MMP_STR    = MMP_TAB + $50
MM_CUR     = $30
MM_MAX     = $32
MM_MK      = $34
MM_MODE    = $35
CH_INT     = $12

section bank 0, $2DA0                       ; (Modern MP: the helpers every bank calls)
; the party's MP into the mode in use (made / estimated first where missing)
mmp_sync:   push hl
            push de
            push bc
            ld a, MMP_BANK
            ld hl, mmp_sync_b
            call bank_call
            pop bc
            pop de
            pop hl
            ret
; A = nonzero when the build has the Modern MP table (always; HL kept)
mmp_ok:     push hl
            ld hl, MMP_TAB
            ld a, MMP_BANK
            ld [fc_bank], a
            call far_byte
            pop hl
            ret
; spell A (0-63) -> A = its MP cost
mmp_cost:   push hl
            add a, low(MMP_COST)
            ld l, a
            ld h, high(MMP_COST)
            ld a, MMP_BANK
            ld [fc_bank], a
            call far_byte
            pop hl
            ret
; member A -> HL = its current MP
mmp_hl:     rrca
            rrca
            add a, MM_CUR
            ld l, a
            ld h, high(ch_magic)
            ret
; member A, cost E: C if its MP is less
mmp_can:    call mmp_hl
            ld a, [hl+]
            sub e
            ld a, [hl]
            sbc a, 0
            ret
; member A pays E MP (not below 0); then C if it has less than E left
mmp_pay:    call mmp_hl
            ld a, [hl]
            sub e
            ld [hl+], a
            ld a, [hl]
            sbc a, 0
            ld [hl-], a
            jr nc, .ok
            xor a
            ld [hl+], a
            ld [hl-], a
.ok:        ld a, [hl+]
            sub e
            ld a, [hl]
            sbc a, 0
            ret
; member A's MP full (inns, the House)
mmp_full:   call mmp_hl
            push de
            inc l
            inc l
            ld a, [hl+]
            ld e, a
            ld d, [hl]
            dec l
            dec l
            ld [hl], d
            dec l
            ld [hl], e
            pop de
            ret
; a level up of member [bt_lvm] (battle): the maximum grows (both modes)
mmp_lvup:   ld a, [bt_lvm]
            ld [mmp_m], a
            ldh a, [rDIV]
            ld hl, frame
            xor [hl]
            ld [mmp_r], a
            ld a, MMP_BANK
            ld hl, mmp_lvup_b
            jp bank_call
; member A's current MP as text into nf_dig (nf_val set)
mmp_nf:     call mmp_hl
            jp nf_w
; member A's maximum into nf_val
mmp_nfmax:  call mmp_hl
            inc l
            inc l
            jp nf_w
; member A: "current/maximum" into mmp_sbuf (0-terminated), B = its length
mmp_str:    push af
            call mmp_nf
            call num_fmt
            ld de, mmp_sbuf
            call mmp_dig
            ld a, $2F
            ld [de], a
            inc de
            pop af
            push de
            call mmp_nfmax
            call num_fmt
            pop de
            call mmp_dig
            xor a
            ld [de], a
            ld a, e
            sub low(mmp_sbuf)
            ld b, a
            ret
; nf_dig without its leading blanks -> [DE++]
mmp_dig:    ld hl, nf_dig
            ld c, 6
.s:         ld a, [hl]
            cp $20
            jr nz, .d
            inc hl
            dec c
            jr .s
.d:         ld a, [hl+]
            ld [de], a
            inc de
            dec c
            jr nz, .d
            ret

section wram, $DAE0
mmp_m:      ds 1                            ; the member
mmp_r:      ds 1                            ; a random byte (level ups)
mmp_p:      ds 3                            ; 24-bit product / quotient
mmp_t:      ds 4
mmp_n:      ds 2                            ; sums (conversion)
mmp_d:      ds 2
bt_mhc:     ds 1                            ; the cursor the battle list's header shows
mg_cost:    ds 1                            ; the field spell's cost
mmp_sbuf:   ds 12                           ; "current/maximum"

section bank 105, $4000
; ---- every member: the fields made if missing, then converted when its mode is not the one in use
mmp_sync_b: ld a, [MMP_TAB]                 ; (no table: the option cannot be on)
            and a
            jr nz, .g
            ld [opt_mmp], a
.g:         xor a
.m:         ld [mmp_m], a
            call mmp_ens
            call mmp_base
            ld a, l
            add a, MM_MODE
            ld l, a
            ld a, [opt_mmp]
            cp [hl]
            jr z, .n
            ld [hl], a
            and a
            jr z, .off
            call mmp_tomp
            jr .n
.off:       call mmp_tochg
.n:         ld a, [mmp_m]
            inc a
            cp 4
            jr c, .m
            ret

; HL = member [mmp_m]'s magic page
mmp_base:   ld a, [mmp_m]
            rrca
            rrca
            ld l, a
            ld h, high(ch_magic)
            ret
; HL = member [mmp_m]'s record
mmp_rec:    ld a, [mmp_m]
            jp ch_rec

; the fields made when the mark is missing: maximum estimated, current 0, mode charges
mmp_ens:    call mmp_base
            ld a, l
            add a, MM_MK
            ld l, a
            ld a, [hl]
            cp $A5
            ret z
            ld [hl], $A5
            inc l
            ld [hl], 0                      ; mode: charges (a converted copy follows)
            call mmp_est
            call mmp_base
            ld a, l
            add a, MM_CUR
            ld l, a
            xor a
            ld [hl+], a
            ld [hl+], a
            ld a, e
            ld [hl+], a
            ld [hl], d
            ret

; A = class -> NZ if it gains MP (not Fighter 0, Thief 1, Black Belt 2, Master 8)
mmp_caster: cp 3
            jr c, .no
            cp 8
            jr z, .no
            or 1
            ret
.no:        xor a
            ret
; A = class -> A = class mod 6
mmp_c6:     cp 6
            ret c
            sub 6
            ret
; byte of the strong-level table: class B (0-5), level C (1-based, >= 2) -> NZ if strong
mmp_strong: ld a, b
            add a, a
            add a, a
            add a, a
            sub b                           ; 7 class
            ld e, a
            ld a, c
            sub 2
            ld d, a
            srl a
            srl a
            srl a
            add a, e
            add a, low(MMP_STR)
            ld l, a
            ld h, high(MMP_STR)
            ld a, d
            and 7
            ld d, [hl]
            inc a
.sh:        dec a
            jr z, .t
            srl d
            jr .sh
.t:         ld a, d
            and 1
            ret

; DE = member [mmp_m]'s estimated maximum (a save from before the option)
mmp_est:    call mmp_rec
            ld a, [hl]
            ld [mmp_t], a                   ; class
            call mmp_caster
            jr nz, .c
            ld de, 0
            ret
.c:         ld a, [mmp_t]
            cp 6
            jr z, .kn
            cp 7
            jr nz, .mg
.kn:        call mmp_base                   ; Knight / Ninja: their charges' worth
            ld a, l
            add a, $28
            ld l, a
            ld bc, MMP_WT
            ld de, 0
.k:         push hl
            ld a, [bc]
            ld h, [hl]
            call mmp_mul8                   ; HL = H x A
            add hl, de
            ld d, h
            ld e, l
            pop hl
            inc hl
            inc c
            ld a, c
            cp low(MMP_WT) + 8
            jr c, .k
            jp mmp_cap
.mg:        call mmp_rec                    ; level, INT
            ld a, l
            add a, CH_LEVEL
            ld l, a
            ld a, [hl]
            inc a
            ld [mmp_t + 1], a               ; level (1-based)
            call mmp_rec
            ld a, l
            add a, CH_INT
            ld l, a
            ld a, [hl]
            ld b, a
            ld a, [mmp_t + 1]               ; INT over the levels: now minus level / 4
            srl a
            srl a
            ld c, a
            ld a, b
            sub c
            jr c, .i1
            jr nz, .i2
.i1:        ld a, 1
.i2:        srl a
            srl a
            inc a                           ; gain a level
            ld [mmp_t + 2], a
            ld a, [mmp_t]                   ; start: the job's starting MP
            call mmp_c6
            ld [mmp_t + 3], a
            add a, low(MMP_TAB + 1)
            ld l, a
            ld h, high(MMP_TAB)
            ld e, [hl]
            ld d, 0
            ld a, [mmp_t + 1]               ; + (level - 1) x gain
            dec a
            jr z, .x
            ld h, a
            ld a, [mmp_t + 2]
            push de
            call mmp_mul8
            pop de
            add hl, de
            ld d, h
            ld e, l
            ld c, 2                         ; + 11 a strong level, 11 / 8 an other one
            xor a
            ld [mmp_n], a                   ; strong
            ld [mmp_n + 1], a               ; others
.s:         push de
            push bc
            ld a, [mmp_t + 3]
            ld b, a
            call mmp_strong
            pop bc
            pop de
            ld hl, mmp_n
            jr nz, .st
            inc hl
.st:        inc [hl]
            inc c
            ld a, [mmp_t + 1]
            cp c
            jr nc, .s
            ld a, [mmp_n]
            ld h, a
            ld a, 11
            push de
            call mmp_mul8
            pop de
            add hl, de
            ld d, h
            ld e, l
            ld a, [mmp_n + 1]
            ld h, a
            ld a, 11
            push de
            call mmp_mul8
            pop de
            ld bc, 4
            add hl, bc
            srl h
            rr l
            srl h
            rr l
            srl h
            rr l
            add hl, de
            ld d, h
            ld e, l
.x:
; DE at most 999
mmp_cap:    ld a, e
            sub low(1000)
            ld a, d
            sbc a, high(1000)
            ret c
            ld de, 999
            ret

; HL = H x A (8 x 8 bits; DE kept)
mmp_mul8:   push de
            ld e, h
            ld d, 0
            ld hl, 0
            and a
            jr z, .x
.l:         add hl, de
            dec a
            jr nz, .l
.x:         pop de
            ret

; ---- a level up (member [mmp_m], its new level and INT in its record)
mmp_lvup_b: ld a, [mmp_m]
            push af
            call mmp_sync_b
            pop af
            ld [mmp_m], a
            call mmp_rec
            ld a, [hl]
            ld [mmp_t], a
            call mmp_caster
            ret z
            call mmp_rec
            ld a, l
            add a, CH_INT
            ld l, a
            ld a, [hl]
            srl a
            srl a
            inc a
            ld [mmp_t + 2], a               ; gain
            call mmp_rec
            ld a, l
            add a, CH_LEVEL
            ld l, a
            ld a, [hl]
            inc a
            cp 2
            jr c, .add
            ld c, a
            ld a, [mmp_t]
            call mmp_c6
            ld b, a
            call mmp_strong
            jr nz, .str
            ld a, [mmp_r]                   ; (otherwise 1 in 8)
            cp 32
            jr nc, .add
.str:       ld a, [mmp_r]                   ; + 10-12
            and 3
            cp 3
            jr nz, .b
            xor a
.b:         add a, 10
            ld hl, mmp_t + 2
            add a, [hl]
            ld [hl], a
.add:       call mmp_base
            ld a, l
            add a, MM_MAX
            ld l, a
            ld a, [mmp_t + 2]
            add a, [hl]
            ld e, a
            inc l
            ld a, [hl]
            adc a, 0
            ld d, a
            call mmp_cap
            ld [hl], d
            dec l
            ld [hl], e
            dec l
            dec l                           ; current + the gain, at most the maximum
            ld a, [mmp_t + 2]
            add a, [hl]
            ld c, a
            inc l
            ld a, [hl]
            adc a, 0
            ld b, a
            ld a, c
            sub e
            ld a, b
            sbc a, d
            jr c, .ok
            ld b, d
            ld c, e
.ok:        ld [hl], b
            dec l
            ld [hl], c
            ret

; ---- member [mmp_m]: charges -> MP (the same weighted fraction of the maximum)
mmp_tomp:   call mmp_sums                   ; mmp_n = current worth, mmp_d = whole worth
            call mmp_base
            ld a, l
            add a, MM_MAX
            ld l, a
            ld a, [hl+]
            ld e, a
            ld d, [hl]
            ld a, [mmp_d]
            ld c, a
            ld a, [mmp_d + 1]
            or c
            jr z, .full                     ; (no charges at all: full)
            ld a, [mmp_n]
            ld l, a
            ld a, [mmp_n + 1]
            ld h, a
            call mmp_mul16                  ; maximum x current worth
            ld a, [mmp_d]
            ld e, a
            ld a, [mmp_d + 1]
            ld d, a
            call mmp_rdiv                   ; / whole worth, rounded -> HL
            ld d, h
            ld e, l
.full:      call mmp_base
            ld a, l
            add a, MM_CUR
            ld l, a
            ld [hl], e
            inc l
            ld [hl], d
            ret
; mmp_n = sum of current charges x level weight, mmp_d = of the maximum charges
mmp_sums:   xor a
            ld [mmp_n], a
            ld [mmp_n + 1], a
            ld [mmp_d], a
            ld [mmp_d + 1], a
            ld c, 0
.l:         push bc
            call mmp_base
            ld a, l
            add a, $20
            add a, c
            ld l, a
            ld b, [hl]                      ; current
            ld a, l
            add a, 8
            ld l, a
            ld a, [hl]                      ; maximum
            cp b
            jr nc, .k
            ld b, a                         ; (current above the maximum: the maximum)
.k:         ld [mmp_t], a
            ld a, b
            ld [mmp_t + 1], a
            ld a, c
            add a, low(MMP_WT)
            ld l, a
            ld h, high(MMP_WT)
            ld a, [hl]
            ld [mmp_t + 2], a               ; the level's weight
            ld a, [mmp_t]
            ld h, a
            ld a, [mmp_t + 2]
            call mmp_mul8
            ld a, [mmp_d]
            add a, l
            ld [mmp_d], a
            ld a, [mmp_d + 1]
            adc a, h
            ld [mmp_d + 1], a
            ld a, [mmp_t + 1]
            ld h, a
            ld a, [mmp_t + 2]
            call mmp_mul8
            ld a, [mmp_n]
            add a, l
            ld [mmp_n], a
            ld a, [mmp_n + 1]
            adc a, h
            ld [mmp_n + 1], a
            pop bc
            inc c
            ld a, c
            cp 8
            jr c, .l
            ret

; ---- member [mmp_m]: MP -> charges (each level the same fraction of its maximum, rounded)
mmp_tochg:  call mmp_base
            ld a, l
            add a, MM_CUR
            ld l, a
            ld a, [hl+]
            ld [mmp_n], a
            ld a, [hl+]
            ld [mmp_n + 1], a
            ld a, [hl+]
            ld [mmp_d], a
            ld a, [hl]
            ld [mmp_d + 1], a
            ld c, 0
.l:         push bc
            call mmp_base
            ld a, l
            add a, $28
            add a, c
            ld l, a
            ld a, [hl]                      ; maximum charges
            ld [mmp_t], a
            ld a, [mmp_d]
            ld e, a
            ld a, [mmp_d + 1]
            ld d, a
            or e
            ld a, [mmp_t]
            jr z, .st                       ; (no MP maximum: full)
            ld a, [mmp_n]                   ; current MP above the maximum: full
            sub e
            ld a, [mmp_n + 1]
            sbc a, d
            ld a, [mmp_t]
            jr nc, .st
            ld l, a
            ld h, 0
            ld a, [mmp_n]
            ld e, a
            ld a, [mmp_n + 1]
            ld d, a
            call mmp_mul16                  ; charges x current
            ld a, [mmp_d]
            ld e, a
            ld a, [mmp_d + 1]
            ld d, a
            call mmp_rdiv
            ld a, l
.st:        ld b, a
            pop de                          ; (E = level)
            push de
            call mmp_base
            ld a, l
            add a, $20
            add a, e
            ld l, a
            ld [hl], b
            pop bc
            inc c
            ld a, c
            cp 8
            jr c, .l
            ret

; mmp_p (24 bits) = HL x DE
mmp_mul16:  xor a
            ld [mmp_p], a
            ld [mmp_p + 1], a
            ld [mmp_p + 2], a
            ld b, 16
.l:         ld a, [mmp_p]
            add a, a
            ld [mmp_p], a
            ld a, [mmp_p + 1]
            adc a, a
            ld [mmp_p + 1], a
            ld a, [mmp_p + 2]
            adc a, a
            ld [mmp_p + 2], a
            sla e
            rl d
            jr nc, .n
            ld a, [mmp_p]
            add a, l
            ld [mmp_p], a
            ld a, [mmp_p + 1]
            adc a, h
            ld [mmp_p + 1], a
            ld a, [mmp_p + 2]
            adc a, 0
            ld [mmp_p + 2], a
.n:         dec b
            jr nz, .l
            ret
; HL = (mmp_p + DE / 2) / DE (DE > 0, the quotient below 65536)
mmp_rdiv:   ld h, d
            ld l, e
            srl h
            rr l
            ld a, [mmp_p]
            add a, l
            ld [mmp_p], a
            ld a, [mmp_p + 1]
            adc a, h
            ld [mmp_p + 1], a
            ld a, [mmp_p + 2]
            adc a, 0
            ld [mmp_p + 2], a
            ld hl, 0
            ld b, 24
.l:         ld a, [mmp_p]
            add a, a
            ld [mmp_p], a
            ld a, [mmp_p + 1]
            adc a, a
            ld [mmp_p + 1], a
            ld a, [mmp_p + 2]
            adc a, a
            ld [mmp_p + 2], a
            rl l
            rl h
            ld a, l
            sub e
            ld c, a
            ld a, h
            sbc a, d
            jr c, .n
            ld h, a
            ld l, c
            ld a, [mmp_p]
            or 1
            ld [mmp_p], a
.n:         dec b
            jr nz, .l
            ld a, [mmp_p]
            ld l, a
            ld a, [mmp_p + 1]
            ld h, a
            ret

; ---- battle (bank 6): the spell list, casting, the party window
section bank 6, $5E00
; spell list: NZ if level B of the commanding member can be chosen (charges left at [DE]; with
; Modern MP any level: the spell's cost decides)
bt_mchg:    ld a, [opt_mmp]
            and a
            ret nz
            ld a, [de]
            and a
            ret
; spell A chosen: C if its cost is more than the member's MP (Modern MP; A kept)
bt_mcost:   push af
            ld a, [opt_mmp]
            and a
            jr z, .ok
            pop af
            push af
            call mmp_cost
            ld e, a
            ld a, [bt_cm]
            call mmp_can
            jr c, .no
.ok:        pop af
            and a
            ret
.no:        ld a, SFX_ERROR
            ld [sfx_req], a
            pop af
            scf
            ret
; casting spell [mg_id] by [bt_who]: C if Modern MP paid it (its MP shown again)
bt_mpay:    ld a, [opt_mmp]
            and a
            ret z
            ld a, [mg_id]
            call mmp_cost
            ld e, a
            ld a, [bt_who]
            call mmp_pay
            ld a, [bt_who]
            call bt_pline
            scf
            ret
; the spell list's header row: "L<n> MP <charges>" of both levels; with Modern MP "L<n>" and the
; cost of the spell under the hand at x 24, the member's MP at x 104
bt_mhdraw:  ld a, [bt_mcur]
            ld [bt_mhc], a
            ld b, 18
            call vwf_clr
            ld a, [bt_mpage]
            add a, a
            ld [bt_t + 6], a
            ld a, 8
            call bt_mhdr
            ld hl, bt_t + 6
            inc [hl]
            ld a, 88
            call bt_mhdr
            ld a, [opt_mmp]
            and a
            ret z
            ld a, [bt_mcur]
            call bt_mslot                   ; B level, C slot
            call bt_mdata
            ld a, b
            add a, a
            add a, a
            add a, c
            add a, l
            ld l, a
            ld a, [hl]
            and a
            jr z, .mp
            dec a
            ld c, a
            ld a, b
            add a, a
            add a, a
            add a, a
            add a, c
            call mmp_cost
            call nf_a
            ld hl, bt_s_cost
            ld a, 24
            call bt_mtxt
.mp:        ld a, [bt_cm]
            call mmp_nf
            ld hl, bt_s_mp
            ld a, 104
; the label HL (bank 6) and the number in nf_val at pixel A
bt_mtxt:    push af
            ld de, bt_sbuf
.c:         ld a, [hl+]
            ld [de], a
            inc de
            and a
            jr nz, .c
            dec de
            push de
            call num_fmt
            pop de
            ld hl, nf_dig
            ld b, 6
.s:         ld a, [hl]
            cp $20
            jr nz, .d
            inc hl
            dec b
            jr .s
.d:         ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .d
            xor a
            ld [de], a
            pop af
            ld hl, bt_sbuf
            jp vwf_str
bt_s_cost:  db "Cost ", 0
bt_s_mp:    db "MP ", 0
; the header row again when the hand moved (Modern MP: the cost shown is the hand's spell)
bt_mhrow:   ld a, [opt_mmp]
            and a
            ret z
            ld a, [bt_mcur]
            ld hl, bt_mhc
            cp [hl]
            ret z
            ld a, [bt_rows]
            push af
            xor a
            ld [bt_rows], a
            call bt_mhdraw
            call bt_mrow
            pop af
            ld [bt_rows], a
            ret
; party line: the status word's x (50; Modern MP: right after the HP) and word DE (Modern MP:
; Poison shortened, the MP needs the room)
bt_stx:     ld a, [opt_mmp]
            and a
            ld a, 44                        ; (the icon from x 44, the word after it)
            ret z
            ld a, [vw_x]
            inc a
            ret
bt_stw:     ld a, [opt_mmp]
            and a
            ret z
            ld a, e
            cp low(bst_poison)
            ret nz
            ld a, d
            cp high(bst_poison)
            ret nz
            ld de, bst_poisn
            ret
; party line: the member's MP right-aligned in small digits (Modern MP; not for those without MP)
bt_plmp:    ld a, [opt_mmp]
            and a
            ret z
            ld a, [bt_t + 11]
            call mmp_hl
            push hl
            inc l
            inc l
            ld a, [hl+]
            or [hl]
            pop hl
            ret z
            call nf_w
            call num_fmt
            ld de, bt_sbuf
            call bt_dig3
            xor a
            ld [de], a
            ld a, e
            sub low(bt_sbuf)
            add a, a
            add a, a
            ld c, a
            ld a, 81
            sub c
            ld hl, bt_sbuf
            jp vwf_str


; ---- the menus (bank 2): Options' question, the Status and Magic screens
section bank 2, $7230
; Status screen (MP row 7): Modern MP: the member's MP as current / maximum ending at column
; 18 as the HP, NZ
st_mmp:     ld a, [opt_mmp]
            and a
            ret z
            ld a, [mm_t]
            call mmp_str
            ld a, 19
            sub b
            ld b, a
            ld c, 7
            call pen_at
            ld hl, mmp_sbuf
            call pen_str
            or 1
            ret
; Magic screen, the level line (row C): Modern MP: "MP current/maximum" ending at column 18, NZ
mg_mmpl:    ld a, [opt_mmp]
            and a
            ret z
            push bc
            ld a, [mg_ch]
            call mmp_str
            ld a, 16
            sub b
            pop bc
            push bc
            ld b, a
            call pen_at
            ld hl, mg_s_mp
            call pen_str
            ld hl, mmp_sbuf
            call pen_str
            pop bc
            or 1
            ret
mg_s_mp:    db "MP ", 0
; Magic screen, a spell (slot value B of level [mg_lv], pen after its name, row C): Modern MP: its
; cost ending at column 18 (on the row below when the name leaves no room)
mg_mcrow:   ld a, [opt_mmp]
            and a
            ret z
            push bc
            ld a, [mg_lv]
            add a, a
            add a, a
            add a, a
            add a, b
            dec a
            call mmp_cost
            call nf_a
            call num_fmt
            ld de, mmp_sbuf
            call mmp_dig
            xor a
            ld [de], a
            ld a, e
            sub low(mmp_sbuf)
            ld b, a                         ; digits
            ld a, 19
            sub b
            ld d, a                         ; its column
            ld a, [pen]
            and 31
            inc a                           ; (a space after the name)
            pop bc
            push bc
            cp d
            jr c, .r
            jr z, .r
            inc c                           ; (no room: the row below)
.r:         ld b, d
            call pen_at
            ld hl, mmp_sbuf
            call pen_str
            pop bc
            ret
; casting from the Magic screen: NZ if the level can be cast (charges at [DE]; Modern MP: yes)
mg_mchg:    ld a, [opt_mmp]
            and a
            ret nz
            ld a, [de]
            and a
            ret
; spell A ($B0 + id): Modern MP: C if the member's MP is less than its cost (A kept)
mg_mchk:    push af
            ld a, [opt_mmp]
            and a
            jr z, .ok
            pop af
            push af
            sub $B0
            call mmp_cost
            ld [mg_cost], a
            ld e, a
            ld a, [mg_ch]
            call mmp_can
            jr c, .no
.ok:        pop af
            and a
            ret
.no:        pop af
            scf
            ret
mg_nomp:    ld bc, $0009                    ; (as desc_box, with our words)
            ld de, $1409
            call scr_win
            ld bc, $010A
            call pen_at
            ld a, 1
            ld [it_desc], a
            call scr_upd
            ld hl, mg_s_nomp
            call pen_type
            call scr_upd
            call wait_ab
            jp magic_menu.re
mg_s_nomp:  db "Not enough MP.", 0
; a field spell cast (Modern MP): its cost paid; Z if not enough left for another
mg_mpay:    ld a, [mg_cost]
            ld e, a
            ld a, [mg_ch]
            call mmp_pay
            sbc a, a
            cpl
            and a
            ret
