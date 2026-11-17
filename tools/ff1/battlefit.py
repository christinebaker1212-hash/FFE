"""Static fit check of FF1 battle strings against the battle boxes (two tile rows each,
split at the last space that fits, as the boxline routine does).
Box interiors (after insert.py): attacker/target/action/result/enemy list 10, message 22.
Tyrannosaurus is drawn with narrow-letter tiles (7 tiles)."""
import json, re, sys

def split(text, W):
    """Return the rows boxline produces, or None if it cannot fit."""
    if len(text) <= W: return [text]
    k = text.rfind(' ', 0, W + 1)
    if k <= 0: return None
    a, b = text[:k], text[k + 1:]
    return [a, b] if len(b) <= W else None

def vis(s): return re.sub(r'\{..\}', '#', s)

def main():
    bad = 0
    names = []
    for f in ('monsters', 'enemy_attacks'):
        names += [(f, e['id'], e['en']) for e in json.load(open('script/ff1/%s.json' % f))]
    items = json.load(open('script/ff1/items.json'))
    names += [('items', e['id'], e['en']) for e in items if e['en'] and e['id'] < 240]
    for f, i, n in names:
        if n == 'Tyrannosaurus': continue
        if split(n, 10) is None: bad += 1; print('name does not fit 10x2:', f, i, n)
    for e in json.load(open('script/ff1/battle_msgs.json')):
        # short strings may appear in a 10-column box; level-up parts (47-58) are composed
        # into the message box
        W = 10 if len(e['ja']) <= 5 and not 47 <= e['id'] <= 58 else 22
        t = vis(e['en']).strip()
        if split(t, W) is None: bad += 1; print('message does not fit %dx2:' % W, e['id'], t)
    print('battle strings not fitting:', bad)
    return bad

if __name__ == '__main__':
    sys.exit(1 if main() else 0)
