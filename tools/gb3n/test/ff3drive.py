"""Pad scripts for FF3 (English NES build) as (pad, frames) lists, shared by cynes and pynes runs:
NEW_GAME reaches the first map from power-on (title, New Game, four names)."""
R, L, D, U, START, SELECT, B, A = 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80


def press(pad, on=5, off=15):
    return [(pad, on), (0, off)]


def new_game():
    s = [(0, 200)] + press(START, 5, 60) + press(A, 5, 60)
    for k in range(4):                          # names: letter k six times (FF3 refuses duplicates)
        for _ in range(k):
            s += press(R, 5, 10)
        for _ in range(7):
            s += press(A)
        s += [(0, 60)]
        for _ in range(k):
            s += press(L, 5, 10)
    return s


NEW_GAME = new_game()
