"""FF3 native engine: the Sound Test's song names (owner, 2026-11-28: FF1's Sound Test in FF3; as
FF1's, our own names by where the game plays each song, worked out at build time from the user's
ROM: a map's song by the map's title, the world maps' table by world and vehicle, the battle's
songs, the title and the story scenes)."""
import re
import text

N_SONGS = 63                                  # FF3's songs $00-$3E (the NSF's 63)
VEHICLES = ('', 'Chocobo', 'Canoe', 'Ship', 'Airship', 'Airship', 'Airship', 'Airship')
WORLDS = ('Floating Continent', 'Surface World', 'Floating Continent')
FIXED = {0x01: 'Prophecy', 0x20: 'Battle', 0x2A: 'Boss Battle', 0x28: 'Last Boss',
         0x07: 'Victory', 0x13: 'Defeat', 0x14: 'Story', 0x3B: 'Epilogue', 0x3C: 'Credits'}


def clean(s):
    s = re.sub(r'\{[^}]*\}|\[[^]]*\]', '', s)
    return ' '.join(s.split())


def names(rom):
    from collections import Counter, defaultdict
    found = dict(FIXED)
    seen = defaultdict(Counter)                  # song -> titles of the maps playing it
    for w in (0, 1, 2):
        for mid in range(256):
            try:
                mp = rom.map_props(mid, w)
                song = mp[10]
                if song & 0x80 or song >= N_SONGS:
                    continue
                t = clean(text.decode(text.raw_string(rom, 't8200', mp[2])))
            except Exception:
                continue
            if t and len(t) <= 16 and t.isprintable():
                seen[song][t] += 1
    spread = Counter()                           # a title over many songs: the maps' default
    for song, c in seen.items():
        for t in c: spread[t] += 1
    for song, c in seen.items():
        if song in found: continue
        good = [(n, t) for t, n in c.items() if spread[t] <= 2]
        if good: found[song] = max(good)[1]
    ws = rom.b(0x3B, 0xA027, 32)
    for k, s in enumerate(ws):
        if s < N_SONGS and s not in found:
            v = VEHICLES[k & 7]
            found[s] = v if v else 'World Map'
    return [found.get(k, 'Song %d' % (k + 1)) for k in range(N_SONGS)]


STRINGS = {'ex_t_ex': 'Extras', 'ex_t_st': 'Sound Test', 'ex_t_bs': 'Bestiary', 'ex_song': 'Song',
           'ex_of': ' / %d' % N_SONGS, 'ex_now': 'Now playing', 'ex_h0': 'Control Pad: song',
           'ex_h1': 'A Button: play', 'ex_h2': 'B Button: back', 'ex_blank': ' ' * 15}


def code_data(rom):
    z = lambda w: ', '.join('$%02X' % c for c in text.encode(w)) + ', 0'
    ns = names(rom)
    out = 'st_names:\n' + ''.join('    dw sndn_%d\n' % k for k in range(N_SONGS))
    for k, n in enumerate(ns):
        out += 'sndn_%d: db %s\n' % (k, z(n[:16]))
    for k, v in STRINGS.items():
        out += '%s: db %s\n' % (k, z(v))
    fr = rom.b(0x7E, 0xDCF2, 8)                 # the hand's frame (as menu.py MD_HAND: tiles $10-)
    cv = lambda a: ((a & 3) + 4) | 8 | ((a & 0x40) >> 1) | ((a & 0x80) >> 1)
    hand = bytes((v + 0x10) & 0xFF if k % 2 == 0 else cv(v) for k, v in enumerate(fr))
    out += 'EX_HAND: db %s\n' % ', '.join('$%02X' % v for v in hand)
    return out


if __name__ == '__main__':
    import sys
    from data import Rom
    for k, n in enumerate(names(Rom(sys.argv[1]))): print('%02X %s' % (k, n))
