"""Extract the complete FF2 Japanese script (second 256KB of the FF I・II cart).
usage: extract.py ROM OUTDIR"""
import sys, os, json
sys.path.insert(0, os.path.dirname(__file__))
from table import decode

def cpu_to_off(cpu, bank16):
    """bank16 counts 16KB banks within the FF2 half."""
    if cpu >= 0xC000: return 0x7C000 + cpu - 0xC000
    return 0x40000 + bank16 * 0x4000 + cpu - 0x8000

# name: (table offset, bank, text lo, text hi, entries)
TABLES = {
    'dialogue_a':  (0x68000, 0x0A, 0x68600, 0x6A920, 256),
    'names':       (0x68200, 0x0A, 0x6A920, 0x6B040, 256),
    'system':      (0x68400, 0x0A, 0x6B040, 0x6C000, 256),
    'dialogue_b':  (0x58000, 0x06, 0x58200, 0x5C000, 256),
    'events':      (0x77F00, 0x0D, 0x747EC, 0x76000, 128),
    'monsters':    (0x56C44, 0x05, 0x56D44, 0x570BB, 128),
    'battle_magic':(0x570BB, 0x05, 0x57147, 0x57295, 70),   # spells/items/enemy attacks as named in battle
    'battle_msgs': (0x57295, 0x05, 0x5737D, 0x57800, 116),  # commands + battle messages
}
FIXED = {
    'ending':      (0x53C00, 4),   # bank 4 $BC00, addressed by code at $BACD
    'guest_names': None,           # filled below (character templates in bank 0)
}
GUESTS = [0x41102, 0x41182, 0x41202, 0x41282, 0x41302]

def extract(data):
    res = {}
    for name, (toff, bank, lo, hi, n) in TABLES.items():
        rows = []
        for i in range(n):
            p = data[toff + 2*i] | data[toff + 2*i + 1] << 8
            off = cpu_to_off(p, bank)
            if not (lo <= off < hi): continue   # unused entry
            txt, ln = decode(data, off)
            rows.append({'id': i, 'off': '%05X' % off, 'ja': txt, 'en': ''})
        res[name] = rows
    rows = []
    for k, o in enumerate(GUESTS):
        rows.append({'id': k, 'off': '%05X' % o, 'ja': decode(data, o, maxlen=6)[0], 'en': ''})
    res['guest_names'] = rows
    for name, v in FIXED.items():
        if v is None: continue
        o, count = v
        rows = []; i = o
        for k in range(count):
            txt, ln = decode(data, i)
            rows.append({'id': k, 'off': '%05X' % i, 'ja': txt, 'en': ''}); i += ln
        res[name] = rows
    return res

if __name__ == '__main__':
    data = open(sys.argv[1], 'rb').read()[16:]
    res = extract(data)
    os.makedirs(sys.argv[2], exist_ok=True)
    for name, rows in res.items():
        json.dump(rows, open(os.path.join(sys.argv[2], name + '.json'), 'w'), ensure_ascii=False, indent=1)
        print(name, len(rows))
