"""Game Boy layout for the FF1 English build (applied by `insert.py --gb`).

The GB shows NES nametable columns 6-25, rows 6-23 (20x18 tiles; camera in
tools/gb/rt/runtime.s). Each screen is re-laid out inside that view in FF1's own code,
following docs/gb-screens.md (SaGa 3 / GB RPG style, party sprites visible in battle).

Camera: the NES code selects the GB view per screen by writing tile coordinates to
$5800 (X) / $5801 (Y) (unmapped on the MMC5; the GB runtime moves its view). Default
(field, until a screen sets its own): X = 6, Y = 6.

Battle: camera (2, 6), so GB = NES - (2, 6):
  enemy area   GB cols 0-13, rows 0-11  (NES enemy box interior, unchanged)
  party column GB cols 14-19, rows 0-11 (sprite at cols 14-15, name/HP at 16-19)
  bottom window GB rows 12-17, full width (enemy names, commands over its right half,
  battle messages)
"""
import os, sys
HDR = 16
BANK = 0x4000


def fixed(rom, cpu):
    """file offsets of a fixed-bank address (copies in banks 15 and 31)"""
    return [HDR + b * BANK + cpu - 0xC000 for b in (15, 31)]


def put(rom, cpu, data, expect=None):
    for o in fixed(rom, cpu):
        if expect is not None and bytes(rom[o:o + len(expect)]) != expect:
            raise SystemExit('gb_layout: unexpected bytes at $%04X' % cpu)
        rom[o:o + len(data)] = data


def bank_off(bank, cpu):
    return HDR + bank * BANK + cpu - 0x8000


def battle_frames(rom):
    """$F2DC-$F30B draws the enemy box (1,1,16,18), the party box (17,1,8,18) and the four
    6x7 HP boxes; the GB layout has no frames there. The freed bytes hold the battle
    camera (X = 2: NES cols 2-21) and a wrapper for the two battle calls from the field
    (overworld $C1D6, dungeons $C935) that sets the field camera (X = 6) again after the
    battle, keeping A and the flags (the dungeon caller branches on carry)."""
    put(rom, 0xF2DC, bytes([0xA9, 0x02, 0x8D, 0x00, 0x58,      # LDA #2 / STA $5800
                            0x4C, 0x0C, 0xF3]),                 # JMP $F30C
        expect=bytes([0xA9, 0x01, 0x8D, 0x38, 0x00]))
    wrap = 0xF2E4
    put(rom, wrap, bytes([0x20, 0x00, 0xF2,                    # JSR $F200 (battle)
                          0x08, 0x48,                          # PHP / PHA
                          0xA9, 0x06, 0x8D, 0x00, 0x58,        # LDA #6 / STA $5800
                          0x68, 0x28, 0x60]))                  # PLA / PLP / RTS
    for site in (0xC1D6, 0xC935):
        put(rom, site, bytes([0x20, wrap & 0xFF, wrap >> 8]), expect=bytes([0x20, 0x00, 0xF2]))


def apply(rom, report):
    battle_frames(rom)
    report.append('GB layout applied')
