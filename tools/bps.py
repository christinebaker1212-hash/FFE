"""BPS patch creation and application (beat format).

  python3 tools/bps.py make SOURCE TARGET OUT.bps
  python3 tools/bps.py apply SOURCE PATCH.bps OUT

The encoder copies from the source wherever it can (SourceRead at the same offset,
SourceCopy from anywhere, TargetCopy from earlier output), so a patch made against the
original Japanese ROM carries the new data, not the original game's.
"""
import sys, zlib

def _num(n):
    out = bytearray()
    while True:
        x = n & 0x7F; n >>= 7
        if n == 0: out.append(0x80 | x); return bytes(out)
        out.append(x); n -= 1

def _read(p, i):
    data, shift = 0, 1
    while True:
        x = p[i]; i += 1
        data += (x & 0x7F) * shift
        if x & 0x80: return data, i
        shift <<= 7; data += shift

K = 8
def make(src, tgt):
    idx = {}
    for i in range(len(src) - K + 1):
        idx.setdefault(src[i:i + K], []).append(i)
    tdx = {}
    out = bytearray(b'BPS1') + _num(len(src)) + _num(len(tgt)) + _num(0)
    lit = bytearray(); src_rel = 0; tgt_rel = 0
    def flush():
        nonlocal lit
        if lit:
            out.extend(_num(((len(lit) - 1) << 2) | 1)); out.extend(lit); lit = bytearray()
    i = 0
    while i < len(tgt):
        # same-offset source run
        n = 0
        while i + n < len(tgt) and i + n < len(src) and src[i + n] == tgt[i + n]: n += 1
        best, kind, at = n, 0, 0
        if best < 32:
            key = tgt[i:i + K]
            for cand, k in ((idx.get(key, ())[:64], 2), (tdx.get(key, ())[-32:], 3)):
                for p in cand:
                    m = 0
                    lim = len(src) - p if k == 2 else i - p
                    while i + m < len(tgt) and m < lim and (src if k == 2 else tgt)[p + m] == tgt[i + m]: m += 1
                    if m > best: best, kind, at = m, k, p
        if (kind == 0 and best >= 4) or (kind and best >= K + 4):
            flush()
            out.extend(_num(((best - 1) << 2) | kind))
            if kind == 2:
                d = at - src_rel; out.extend(_num((abs(d) << 1) | (d < 0))); src_rel = at + best
            elif kind == 3:
                d = at - tgt_rel; out.extend(_num((abs(d) << 1) | (d < 0))); tgt_rel = at + best
            for j in range(i, i + best):
                if j + K <= len(tgt): tdx.setdefault(tgt[j:j + K], []).append(j)
            i += best
        else:
            if i + K <= len(tgt): tdx.setdefault(tgt[i:i + K], []).append(i)
            lit.append(tgt[i]); i += 1
    flush()
    out.extend((zlib.crc32(src) & 0xFFFFFFFF).to_bytes(4, 'little'))
    out.extend((zlib.crc32(tgt) & 0xFFFFFFFF).to_bytes(4, 'little'))
    out.extend((zlib.crc32(out) & 0xFFFFFFFF).to_bytes(4, 'little'))
    return bytes(out)

def apply(src, p):
    assert p[:4] == b'BPS1', 'not a BPS patch'
    assert zlib.crc32(p[:-4]) & 0xFFFFFFFF == int.from_bytes(p[-4:], 'little'), 'patch damaged'
    assert zlib.crc32(src) & 0xFFFFFFFF == int.from_bytes(p[-12:-8], 'little'), 'wrong source ROM'
    i = 4
    ss, i = _read(p, i); ts, i = _read(p, i); ms, i = _read(p, i); i += ms
    assert ss == len(src)
    out = bytearray(); sr = tr = 0
    while i < len(p) - 12:
        d, i = _read(p, i); cmd = d & 3; n = (d >> 2) + 1
        if cmd == 0: out += src[len(out):len(out) + n]
        elif cmd == 1: out += p[i:i + n]; i += n
        else:
            o, i = _read(p, i); o = -(o >> 1) if o & 1 else o >> 1
            if cmd == 2: sr += o; out += src[sr:sr + n]; sr += n
            else:
                tr += o
                for _ in range(n): out.append(out[tr]); tr += 1
    assert len(out) == ts
    assert zlib.crc32(out) & 0xFFFFFFFF == int.from_bytes(p[-8:-4], 'little'), 'result mismatch'
    return bytes(out)

if __name__ == '__main__':
    if sys.argv[1] == 'make':
        src, tgt = open(sys.argv[2], 'rb').read(), open(sys.argv[3], 'rb').read()
        p = make(src, tgt)
        assert apply(src, p) == tgt
        open(sys.argv[4], 'wb').write(p); print(sys.argv[4], len(p), 'bytes')
    else:
        open(sys.argv[4], 'wb').write(apply(open(sys.argv[2], 'rb').read(), open(sys.argv[3], 'rb').read()))
        print('wrote', sys.argv[4])
