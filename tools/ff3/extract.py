"""Dump FF3 pointer tables in bank 0x18 to JSON."""
import sys, json, os
sys.path.insert(0, os.path.dirname(__file__))
from table import decode

def ptr(data, tab_off, idx):
    lo, hi = data[tab_off + idx*2], data[tab_off + idx*2 + 1]
    bank = (hi >> 5) + 0x18
    addr = lo | ((hi & 0x1F) | 0x80) << 8
    return bank*0x2000 + (addr - 0x8000), bank, addr

TABLES = {'t8000': 0x30000, 't8200': 0x30200, 't8600': 0x30600, 'names8800': 0x30800}

if __name__ == '__main__':
    data = open(sys.argv[1], 'rb').read()[16:]
    res = {}
    for name, toff in TABLES.items():
        n = 256
        res[name] = []
        for i in range(n):
            off, bank, addr = ptr(data, toff, i)
            txt, ln = decode(data, off)
            res[name].append({'id': i, 'off': '%05X' % off, 'len': ln, 'ja': txt})
    json.dump(res, open(sys.argv[2], 'w'), ensure_ascii=False, indent=1)
