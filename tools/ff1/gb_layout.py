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


def boxline_one_row(rom):
    """English patch's boxline (far code): a line that fits is written on the text
    record's own row (the Japanese dakuten row is not drawn), so lines can be single
    spaced; a line that has to be split still takes that row and the next."""
    main = sys.modules['__main__']
    L = main.FAR_LABELS
    o1, done = L['boxline.o1'], L['boxline.done']
    off = HDR + main.FAR8 * 0x2000 - 0xC000
    assert bytes(rom[off + o1:off + o1 + 5]) == bytes([0xBD, 0xD4, 0x6C, 0xF0, rom[off + o1 + 4]])
    rom[off + o1 + 1] = 0xD5                          # LDA $6CD5,X: the character row
    rom[off + o1 + 4] = (done - (o1 + 5)) & 0xFF      # BEQ .done (no second row)


def battle_panel(rom):
    """Bottom panel (25x12 image at $691E, NES rows 18-29; the GB shows panel rows 0-5,
    cols 2-21). Box records: type 0 = frame (x y w h), type 1 = text (x y, pointer).
    Windows are 7 rows high: their bottom frame falls on panel row 6, which the GB does
    not show, so 5 text rows are visible (rows 1-5)."""
    # panel clear: no row of box bottoms for the (removed) enemy/party boxes
    put(rom, 0xF625, bytes([0x60]), expect=bytes([0xA9, 0xFD]))
    # enemy names: full-width window, names on rows 1-4 (single spacing)
    put(rom, 0xF9DC, bytes([0, 2, 0, 20, 7]), expect=bytes([0, 1, 0, 12, 10]))
    put(rom, 0xF6D2, bytes([0xEA] * 3), expect=bytes([0xCE, 0xA0, 0x6A]))      # no DEC $6AA0
    put(rom, 0xF6D7, bytes([0xEA] * 3), expect=bytes([0xEE, 0xA0, 0x6A]))      # one INC $6AA0
    # command window over the right half: Fight Run / Magic / Medicine / Items
    cmd = fixed(rom, 0xFA13)[0]
    ptr = [bytes(rom[cmd + 5 * k + 3:cmd + 5 * k + 5]) for k in range(1, 6)]   # Fight Magic Medicine Items Run
    rec = bytes([0, 11, 0, 11, 7])
    for k, (x, y) in enumerate(((12, 1), (12, 2), (12, 3), (12, 4), (18, 1))):
        rec += bytes([1, x, y]) + ptr[k]
    put(rom, 0xFA13, rec)
    # battle messages: attacker / action / target / result on rows 1 / 2 / 3 / 4(-5) of
    # one window; boxes 2-4 are drawn in panel rows 8-9, which the GB does not show
    msg = bytes([0, 2, 0, 20, 7, 1, 3, 1,
                 0, 2, 8, 20, 2, 1, 3, 2,
                 0, 2, 8, 20, 2, 1, 3, 3,
                 0, 2, 8, 20, 2, 1, 3, 4,
                 0, 2, 0, 20, 7, 1, 3, 1])           # long single message (record 4)
    put(rom, 0xF9E1, msg)
    # item / medicine list window: into the visible rows
    put(rom, 0xFA0E, bytes([0, 2, 0, 20, 7]))


def apply(rom, report):
    battle_frames(rom)
    boxline_one_row(rom)
    battle_panel(rom)
    report.append('GB layout applied')
