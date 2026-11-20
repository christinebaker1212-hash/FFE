"""Nintendo hardware terminology in the text the Game Boy builds show (docs/gb-release-checklist.md
section 4): scans the translation sources and the GB layout / runtime message strings for
wrong forms of the hardware names.

usage: termcheck.py [ff1|ff2|ff3 ...]      (default: all)

Required forms: "Game Boy", "Game Boy Color", "Game Boy Advance", "Game Link Cable",
"Control Pad", "Game Pak", "A Button" / "B Button", "START" / "SELECT" (or "Start" /
"Select" as menu words). Flagged: "Gameboy" / "GameBoy" / "game boy", "cartridge",
"D-pad" / "directional pad" / "control pad", "A button" / "B button", "link cable",
"NES" / "Famicom" / "controller" / "RESET" / "POWER" (NES hardware the GB has not).
Exit status 1 if anything is flagged."""
import os, re, sys, glob

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
SOURCES = {
    'ff1': ['script/ff1/*.json', 'translations/ff1*.py', 'translations/ff1/*', 'tools/ff1/insert.py', 'tools/ff1/gb_layout.py',
            'tools/gb/build.py'],
    'ff2': ['script/ff2/*.json', 'translations/ff2*.py', 'translations/ff2/*', 'tools/ff2/insert.py', 'tools/gb2/*.py'],
    'ff3': ['script/ff3/*.json', 'translations/ff3*.py', 'translations/ff3/*', 'tools/ff3/insert.py', 'tools/gb3/layout.py',
            'tools/gb3/build.py'],
}
BAD = [
    (r'\bGame ?boy\b|\bGameBoy\b|\bgame boy\b', 'Game Boy'),
    (r'\bcartridge', 'Game Pak'),
    (r'\bD-?pad\b|\bdirectional pad\b|\bcontrol pad\b', 'Control Pad'),
    (r'\b[AB] button\b', 'A Button / B Button'),
    (r'\blink cable\b|\bLink cable\b', 'Game Link Cable'),
    (r'\bFamicom\b|\bcontroller\b|\bRESET\b|\bPOWER\b', '(NES hardware: not on a Game Boy)'),
]


# what each GB build changes in the text it takes from these sources (so the NES English patch
# keeps its own wording): replacements applied everywhere, and texts the GB build replaces
GB_SUBST = {
    'ff1': [('A button', 'A Button'), ('B button', 'B Button')],     # tools/ff1/insert.py enc() with --gb
    'ff3': [('A button', 'A Button'), ('B button', 'B Button')],     # tools/gb3/layout.py dialogue()
}
GB_REPLACED = {
    'ff3': ['Hold RESET while you'],          # system message $4E: GB text in tools/gb3/layout.py MENU_TEXT
}


def strings_of(path):
    """text the game shows: translation files whole; Python sources: string literals only"""
    s = open(path, encoding='utf-8', errors='replace').read()
    if path.endswith('.py'):
        for m in re.finditer(r"'([^'\\\n]*(?:\\.[^'\\\n]*)*)'|\"([^\"\\\n]*(?:\\.[^\"\\\n]*)*)\"", s):
            yield s.count('\n', 0, m.start()) + 1, m.group(1) or m.group(2) or ''
    else:
        for i, l in enumerate(s.splitlines(), 1): yield i, l


def main():
    games = sys.argv[1:] or sorted(SOURCES)
    bad = 0
    for g in games:
        files = sorted({f for p in SOURCES[g] for f in glob.glob(os.path.join(ROOT, p)) if os.path.isfile(f)})
        n = 0
        for f in files:
            for ln, text in strings_of(f):
                for a, b in GB_SUBST.get(g, []): text = text.replace(a, b)
                if any(r in text for r in GB_REPLACED.get(g, [])): continue
                for pat, want in BAD:
                    for m in re.finditer(pat, text):
                        if os.path.basename(f) == 'termcheck.py': continue
                        print('%s: %s:%d: "%s" -> %s' % (g, os.path.relpath(f, ROOT), ln, m.group(0), want))
                        n += 1
        print('%s: %d files, %d flagged' % (g, len(files), n))
        bad += n
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
