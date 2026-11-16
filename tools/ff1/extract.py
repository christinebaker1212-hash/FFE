"""Extract the complete FF1 Japanese script (first 256KB of the FF I・II cart).
usage: extract.py ROM OUTDIR"""
import sys, os, json
sys.path.insert(0, os.path.dirname(__file__))
from table import decode

def cpu_to_off(cpu, bank16):
    if cpu >= 0xC000: return 0x3C000 + cpu - 0xC000
    return bank16 * 0x4000 + cpu - 0x8000

# name: (table offset, 16KB bank of strings, text range lo, hi, max entries)
TABLES = {
    'dialogue':      (0x28000, 0x0A, 0x28200, 0x2B580, 256),
    'items':         (0x2B700, 0x0A, 0x2B900, 0x2C000, 256),   # fixed-width names incl. weapons/armor/magic/classes
    'enemy_attacks': (0x2B600, 0x0A, 0x2B600, 0x2B700, 64),
    'battle_msgs':   (0x2CF50, 0x0B, 0x2CC40, 0x2CF50, 128),
    'monsters':      (0x2D4E0, 0x0B, 0x2D5E0, 0x2D9B7, 128),
    'story':         (0x36800, 0x0D, 0x36832, 0x37000, 64),
    'shop':          (0x38000, 0x0E, 0x38000, 0x38300, 64),
    # 0x38300-0x3837F: magic-shop spell index lists (not text)
    'menu':          (0x38500, 0x0E, 0x38580, 0x39000, 128),
}
# strings addressed directly by code (start offset, label)
FIXED = {'prologue': (0x37F20, 2), 'title_menu': (0x3A26C, 3), 'battle_cmds': (0x3FA31, 5)}

def extract(data):
    res = {}
    for name, (toff, bank, lo, hi, nmax) in TABLES.items():
        rows = []
        for i in range(nmax):
            p = data[toff + 2*i] | data[toff + 2*i + 1] << 8
            off = cpu_to_off(p, bank)
            if not (lo <= off < hi): break
            txt, ln = decode(data, off)
            rows.append({'id': i, 'off': '%05X' % off, 'ja': txt, 'en': ''})
        res[name] = rows
    for name, (o, count) in FIXED.items():
        rows = []; i = o
        for k in range(count):  # consecutive 0-terminated strings
            txt, ln = decode(data, i)
            rows.append({'id': k, 'off': '%05X' % i, 'ja': txt, 'en': ''})
            i += ln
        res[name] = rows
    return res

if __name__ == '__main__':
    data = open(sys.argv[1], 'rb').read()[16:]
    res = extract(data)
    os.makedirs(sys.argv[2], exist_ok=True)
    for name, rows in res.items():
        json.dump(rows, open(os.path.join(sys.argv[2], name + '.json'), 'w'), ensure_ascii=False, indent=1)
        print(name, len(rows))
