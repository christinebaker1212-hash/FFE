"""FF3 native engine: the encounter transition's tables (FF1's, owner 2026-11-28: "the fancy battle
transition we made for FF1"; the same function as tools/gbn/battle.py trans_tables, our own maths,
no game data). Per frame 144 SCX offsets, then 144 SCY offsets (map line - screen line): 8 frames
of two white flashes, 24 of a swirl drawn in towards the party's line, 16 of the lines parting as
the picture folds onto that line and fades to white. $3600: the fade to white, 8 levels x 32
(c + (31 - c) f / 8); $3700: each frame's colour level (0 as before, 1 the map's own colours, 2-9
the fade's levels 1-8)."""
import math

TR_FLASH, TR_SWIRL, TR_FADE = 8, 24, 16       # frames: 48 in all (wipe.s TR_FR)


def trans_tables():
    def ease(u): return u * u * (3 - 2 * u)                         # smoothstep
    out = bytearray(); lv = bytearray(); cy = 72
    def frame(dx, sy):                                              # 144 SCX, then 144 SCY
        out.extend(int(round(dx[y])) & 255 for y in range(144))
        out.extend((int(round(sy[y])) - y) & 255 for y in range(144))
    for t in range(TR_FLASH):                                       # two flashes
        frame([0] * 144, list(range(144)))
        lv.append((3, 7, 3, 1)[t % 4])
    for t in range(TR_SWIRL):                                       # the swirl
        u = (t + 1) / TR_SWIRL
        a = 22 * ease(u); ph = 0.55 * t
        k1 = 2 * math.pi * (1.1 + 0.9 * u) / 144
        z = 1 + 0.7 * ease(u) ** 2
        dx = [a * math.sin(k1 * y + ph) + 0.35 * a * math.sin(2.7 * k1 * y - 1.3 * ph)
              for y in range(144)]
        sy = [cy + (y - cy) / z + 3 * ease(u) * math.sin(2 * math.pi * y / 48 + 0.8 * ph)
              for y in range(144)]
        frame(dx, sy)
        lv.append(0)
    for t in range(TR_FADE):                                        # part, fold, white
        u = (t + 1) / TR_FADE
        ph = 0.55 * (TR_SWIRL + t)
        a = 22 * (1 - 0.5 * u)
        k1 = 2 * math.pi * 2.0 / 144
        part = 90 * ease(u) ** 1.5
        z = 1.7 + 14 * ease(u) ** 2
        dx = [a * math.sin(k1 * y + ph) + (part if y & 1 else -part) for y in range(144)]
        sy = [cy + (y - cy) / z for y in range(144)]
        frame(dx, sy)
        lv.append(1 + max(1, min(8, int(round(8 * ease(u))))))
    assert len(out) <= 0x3600
    out += b'\0' * (0x3600 - len(out))
    for f in range(1, 9):
        out += bytes(c + (31 - c) * f // 8 for c in range(32))
    out += b'\0' * (0x3700 - len(out))
    out += bytes(lv)
    out += b'\0' * (0x4000 - len(out))
    return bytes(out)
