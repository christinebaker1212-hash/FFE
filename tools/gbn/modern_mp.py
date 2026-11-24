"""Data for the "Modern MP" option (owner, 2026-11-24): the Dawn of Souls MP rules, stored here for
good (owner: keep the data in the repository, no downloads at build time). Taken once from the
FINAL FANTASY wiki (finalfantasy.fandom.com, 2026-11-24):
  - each spell's MP cost (page "Magic (Final Fantasy)": the spell tables' "NES: <name>", level,
    MP), in the game's spell-id order (level x 8 + slot: four white, four black a level);
  - each job's starting MP and its guaranteed "strong" MP levels (page "Final Fantasy stats": the
    starting stats table, the guaranteed stat growth table);
  - the rule (page "Stat growth"), which is in the game's code (src/mmp.s): a level's MP gain is
    floor(INT / 4) + 1, plus 10-12 on a strong level, any other level strong with a chance of 1
    in 8; Fighter / Thief gain MP only after the class change (Knight / Ninja), Black Belt /
    Master never."""
MMP_BANK = 105

# FF1's NES spell names, in spell-id order (only to read the costs table below)
NES_NAMES = ('CURE HARM FOG RUSE FIRE SLEP LOCK LIT LAMP MUTE ALIT INVS ICE DARK TMPR SLOW '
             'CUR2 HRM2 AFIR HEAL FIR2 HOLD LIT2 LOK2 PURE FEAR AICE AMUT SLP2 FAST CONF ICE2 '
             'CUR3 LIFE HRM3 HEL2 FIR3 BANE WARP SLO2 SOFT EXIT FOG2 INV2 LIT3 RUB QAKE STUN '
             'CUR4 HRM4 ARUB HEL3 ICE3 BRAK SABR BLND LIF2 FADE WALL XFER NUKE STOP ZAP! XXXX').split()
COSTS = [3, 5, 3, 3, 5, 3, 3, 5,  3, 5, 8, 5, 8, 5, 10, 5,  10, 12, 8, 10, 15, 10, 15, 10,
         3, 10, 8, 3, 15, 15, 15, 18,  20, 20, 25, 25, 30, 28, 5, 18,  10, 10, 20, 25, 35, 30, 32, 20,
         35, 35, 28, 38, 40, 30, 25, 25,  40, 50, 40, 35, 50, 30, 38, 40]
# starting MP by FF1's class (0 Fighter, 1 Thief, 2 Black Belt, 3 Red Mage, 4 White Mage, 5 Black Mage)
INIT = [0, 0, 0, 10, 10, 10]
# guaranteed strong MP levels by class (Fighter / Thief: as Knight / Ninja)
STRONG = {
    0: [29, 33, 37, 41, 45, 49, 53, 57, 61, 65, 69, 73, 77, 81, 85, 89, 93, 97],
    1: [29, 33, 35, 39, 41, 45, 47, 51, 53, 57, 59, 63, 65, 69, 71, 75, 77, 81, 83, 87, 89, 93, 95, 99],
    2: [],
    3: [3, 7, 9, 12, 14, 16, 18, 20, 23, 26, 28, 30, 32, 35, 40, 44, 49, 52, 56, 60, 64, 71, 77, 83, 87,
        90, 96],
    4: [2, 6, 10, 13, 15, 17, 19, 21, 23, 25, 27, 29, 31, 33, 35, 37, 39, 41, 43, 45, 47, 49, 51, 53, 55,
        57, 59, 61, 64, 66, 68, 70, 72, 74, 76, 78, 80, 82, 84, 86, 88, 90, 92, 94, 96],
    5: list(range(2, 99, 2)),
}


def tables():
    """the bank's contents: $4000 1 (data present), $4001 starting MP per class (6), $4008 the
    level weights (8: the average cost of a level's spells), $4010 the costs (64), $4050 strong
    levels (6 classes x 7 bytes: bit k of byte j = level 2 + 8 j + k)"""
    assert len(COSTS) == 64 == len(NES_NAMES)
    blob = bytearray(0x100)
    blob[0] = 1
    blob[1:7] = bytes(INIT)
    for lv in range(8):
        blob[8 + lv] = round(sum(COSTS[lv * 8:lv * 8 + 8]) / 8)
    blob[0x10:0x50] = bytes(COSTS)
    for cls in range(6):
        for lv in STRONG[cls]:
            if 2 <= lv <= 57:
                k = lv - 2
                blob[0x50 + 7 * cls + k // 8] |= 1 << (k % 8)
    return bytes(blob)


if __name__ == '__main__':
    b = tables()
    print('init', list(b[1:7]), 'weights', list(b[8:16]))
    print('costs', dict(zip(NES_NAMES, COSTS)))
