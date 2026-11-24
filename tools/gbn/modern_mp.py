"""Data for the "Modern MP" option (owner, 2026-11-24): the Dawn of Souls MP rules, fetched from the
FINAL FANTASY wiki when the build runs (finalfantasy.fandom.com through its public MediaWiki API;
cached in build/wiki/, never committed):
  - each spell's MP cost (page "Magic (Final Fantasy)": the spell tables, "NES: <name>", level, MP),
    matched to the game's spell ids by FF1's own NES spell names (the order of the spell list);
  - each job's starting MP and its guaranteed "strong" MP levels (page "Final Fantasy stats": the
    starting stats table, the guaranteed stat growth table);
  - the rule itself (page "Stat growth"): a level's MP gain is floor(INT / 4) + 1, plus 10-12 on a
    strong level; any other level is strong with a chance of 1 in 8; Warrior / Thief gain MP only
    after the class change (Knight / Ninja), Monk / Master never. The rule is in the game's code
    (src/mmp.s); this module checks that the page still states it.
Without the pages (no network, no cache) the option is built switched off (MMP_OK = 0)."""
import os, re, json, urllib.request, urllib.parse
HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(HERE, '..', '..', 'build', 'wiki')
API = 'https://finalfantasy.fandom.com/api.php'
MMP_BANK = 105

# FF1's NES spell names in spell-id order (level x 8 + slot: four white, four black a level); only
# used to match the wiki's "NES:" names to the game's spell ids
NES_NAMES = ('CURE HARM FOG RUSE FIRE SLEP LOCK LIT LAMP MUTE ALIT INVS ICE DARK TMPR SLOW '
             'CUR2 HRM2 AFIR HEAL FIR2 HOLD LIT2 LOK2 PURE FEAR AICE AMUT SLP2 FAST CONF ICE2 '
             'CUR3 LIFE HRM3 HEL2 FIR3 BANE WARP SLO2 SOFT EXIT FOG2 INV2 LIT3 RUB QAKE STUN '
             'CUR4 HRM4 ARUB HEL3 ICE3 BRAK SABR BLND LIF2 FADE WALL XFER NUKE STOP ZAP! XXXX').split()
WIKI_JOBS = ('Warrior', 'Thief', 'Monk', 'W.Mage', 'B.Mage', 'R.Mage')
WIKI_TO_CLASS = (0, 1, 2, 4, 5, 3)               # the wiki's column -> FF1's class (0 Fighter .. 5 BlackMage)


def page(title):
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, re.sub(r'\W', '_', title) + '.txt')
    if os.path.exists(path):
        return open(path, encoding='utf-8').read()
    url = API + '?' + urllib.parse.urlencode({'action': 'parse', 'page': title, 'prop': 'wikitext',
                                              'format': 'json'})
    req = urllib.request.Request(url, headers={'User-Agent': 'ffe-builder/1.0 (wiki data reader)'})
    t = json.load(urllib.request.urlopen(req, timeout=30))['parse']['wikitext']['*']
    open(path, 'w', encoding='utf-8').write(t)
    return t


def costs(t):
    out = {}
    for m in re.finditer(r'NES: ([A-Z0-9!]+)[^\n]*\n\|(\d+)\n\|(\d+)', t):
        name, lv, mp = m.group(1), int(m.group(2)), int(m.group(3))
        k = NES_NAMES.index(name)
        assert k // 8 + 1 == lv, (name, lv)
        out[k] = mp
    assert sorted(out) == list(range(64)), 'spell costs incomplete: %s' % sorted(set(range(64)) - set(out))
    return [out[k] for k in range(64)]


def growth(t):
    i = t.index('Guaranteed stat growth by class level')
    rows = t[i:t.index('|}', i)].split('|-')[2:]
    strong = {c: set() for c in range(6)}
    for r in rows:
        cells = [c[1:].strip() for c in r.strip().split('\n') if c.startswith('|')]
        lv = int(cells[0])
        for col in range(6):
            if re.search(r'\bMP\b', cells[1 + col]): strong[WIKI_TO_CLASS[col]].add(lv)
    i = t.index('\n!MP\n')                      # the starting stats: MP row
    start = [int(x) for x in re.findall(r'\|(\d+)', t[i:i + 60])[:6]]
    init = [0] * 6
    for col in range(6): init[WIKI_TO_CLASS[col]] = start[col]
    return strong, init


def rule_ok(t):
    return re.search(r'MP increase is equal to FLOOR \[ Intelligence . 4 \] \+ 1', t) is not None and \
           re.search(r'additional 10 . 12 MP', t) is not None


def tables():
    """the bank's contents: $4000 MMP_OK, $4001 starting MP per class (6), $4008 the level
    weights (8: the average cost of a level's spells), $4010 the costs (64), $4050 strong levels
    (6 classes x 7 bytes: bit k of byte j = level 2 + 8 j + k)"""
    blob = bytearray(0x100)
    try:
        c = costs(page('Magic (Final Fantasy)'))
        strong, init = growth(page('Final Fantasy stats'))
        ok = rule_ok(page('Stat growth'))
    except Exception as e:                        # (no network and no cache: the option off)
        print('Modern MP: wiki data not available (%s): option disabled' % e)
        return bytes(blob)
    if not ok:
        print('Modern MP: the Stat growth page no longer states the rule: option disabled')
        return bytes(blob)
    blob[0] = 1
    blob[1:7] = bytes(init)
    for lv in range(8):
        blob[8 + lv] = round(sum(c[lv * 8:lv * 8 + 8]) / 8)
    blob[0x10:0x50] = bytes(c)
    for cls in range(6):
        for lv in strong[cls]:
            if 2 <= lv <= 57:
                k = lv - 2
                blob[0x50 + 7 * cls + k // 8] |= 1 << (k % 8)
    return bytes(blob)


if __name__ == '__main__':
    b = tables()
    print('ok', b[0], 'init', list(b[1:7]), 'weights', list(b[8:16]))
    print('costs', list(b[0x10:0x50]))
