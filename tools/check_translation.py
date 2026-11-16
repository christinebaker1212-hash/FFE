"""Validate translations: every control token in `ja` must appear in `en` the same
number of times; flag empty translations and disallowed characters.
usage: check_translation.py script/ff3/t8000.json [...]"""
import sys, json, re, collections
TOK = re.compile(r'\{[0-9A-F]{2}(?::[0-9A-F]{2})?\}|\{COL:[0-9A-F]{2}\}|\[[0-9A-F]{2}\]')
ALLOWED = re.compile(r"^[A-Za-z0-9 .,!?'\"\-:;()/%&+…\[\]\n]*$")   # [ ] = FF2 key-word brackets

def check(path):
    rows = json.load(open(path)); bad = 0; done = 0
    for e in rows:
        if not e['ja'].strip('　\n'): continue
        en = e.get('en', '')
        if not en: continue
        done += 1
        a = collections.Counter(TOK.findall(e['ja'])); b = collections.Counter(TOK.findall(en))
        plain = TOK.sub('', en)
        problems = []
        if a != b: problems.append('tokens %s != %s' % (dict(a - b), dict(b - a)))
        if not ALLOWED.match(plain): problems.append('chars %r' % sorted(set(re.sub(r"[A-Za-z0-9 .,!?'\"\-:;()/%&+…\[\]\n]", '', plain))))
        if problems:
            bad += 1; print('%s #%s: %s' % (path, e['id'], '; '.join(problems)))
    todo = sum(1 for e in rows if e['ja'].strip('　\n') and not e.get('en'))
    print('%s: %d translated, %d problems, %d untranslated' % (path, done, bad, todo))
    return bad

if __name__ == '__main__':
    sys.exit(1 if sum(check(p) for p in sys.argv[1:]) else 0)
