"""Dump FF3 pointer tables in bank 0x18 to JSON."""
import sys, json, os
sys.path.insert(0, os.path.dirname(__file__))
from table import decode

def ptr(data, tab_off, idx):
    lo, hi = data[tab_off + idx*2], data[tab_off + idx*2 + 1]
    bank = (hi >> 5) + 0x18
    addr = lo | ((hi & 0x1F) | 0x80) << 8
    return bank*0x2000 + (addr - 0x8000), bank, addr

# name -> (file offset, entry count)
TABLES = {'t8000': (0x30000, 256), 't8200': (0x30200, 256), 't8400': (0x30400, 256),
          't8600': (0x30600, 256), 'names8800': (0x30800, 688)}

def _main_dump():
    data = open(sys.argv[1], 'rb').read()[16:]
    res = {}
    for name, (toff, n) in TABLES.items():
        res[name] = []
        for i in range(n):
            if data[toff + i*2] == 0 and data[toff + i*2 + 1] == 0:
                res[name].append({'id': i, 'off': None, 'len': 0, 'ja': None}); continue
            off, bank, addr = ptr(data, toff, i)
            txt, ln = decode(data, off)
            res[name].append({'id': i, 'off': '%05X' % off, 'len': ln, 'ja': txt})
    json.dump(res, open(sys.argv[2], 'w'), ensure_ascii=False, indent=1)


def extract_epilogue(data):
    """Ending narration in bank 0x1F: pages ending in 00, lines in 01,
    '02 xx' sets the column (used for centring)."""
    from table import SINGLE
    start = data.find(bytes([0x02, 0x0A, 0x84, 0x9F, 0xB6, 0xA3]), 0x3E000, 0x40000)
    end = data.find(bytes([0x3C, 0x8C, 0x7B, 0xC3, 0xC3, 0x00]), start) + 6  # ...ぼうを‥‥ 00
    pages, cur, i = [], [], start
    page_start = start
    while i < end:
        b = data[i]; i += 1
        if b == 0x00:
            pages.append({'id': len(pages), 'off': '%05X' % page_start, 'len': i - page_start, 'ja': ''.join(cur)})
            cur = []; page_start = i
        elif b == 0x01: cur.append('\n')
        elif b == 0x02: cur.append('{COL:%02X}' % data[i]); i += 1
        else: cur.append(SINGLE.get(b, '[%02X]' % b))
    return pages


def write_script(data, outdir):
    os.makedirs(outdir, exist_ok=True)
    for name, (toff, n) in TABLES.items():
        rows = []
        for i in range(n):
            if data[toff + i*2] == 0 and data[toff + i*2 + 1] == 0:
                continue
            off, bank, addr = ptr(data, toff, i)
            txt, ln = decode(data, off)
            rows.append({'id': i, 'off': '%05X' % off, 'ja': txt, 'en': ''})
        json.dump(rows, open(os.path.join(outdir, name + '.json'), 'w'), ensure_ascii=False, indent=1)
    rows = extract_epilogue(data)
    for r in rows: r['en'] = ''
    json.dump(rows, open(os.path.join(outdir, 'epilogue.json'), 'w'), ensure_ascii=False, indent=1)


if __name__ == '__main__':
    # usage: extract.py ROM OUTDIR   (writes script/ff3/*.json)
    write_script(open(sys.argv[1], 'rb').read()[16:], sys.argv[2])
