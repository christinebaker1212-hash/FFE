"""FF2 source base: everything8215's annotated listing + the user's ROM -> 6502 source.

The everything8215/ff2 repository (fetched into build/src/ff2, never committed) is an
annotated listing of the standalone FF2 (J) ROM, not an assemblable source: lines
`BB/AAAA: bytes  MNEMONIC  ; comment`, covering the code and some tables (~67 KB of
256 KB), plus rom-map.txt / ram-map.txt. This tool turns it into assemblable source:

  - instruction starts come from the listing (a line whose bytes match the ROM there);
    instructions are re-decoded from the ROM bytes, so the source can't drift from them;
  - every byte not covered as code is data, taken from the given ROM at build time
    (graphics, maps, text, music never come from this repo);
  - branch/jump/call targets get labels (Lbb_aaaa; fixed bank: Fxxxx), the listing's
    routine titles and comments are kept.

Input ROM: "Final Fantasy I, II (Japan).nes" (FF2 = the second 256 KB half), or the
English FF2 MMC5 ROM made from it (--english: runs build_mmc5.py + insert.py here, with
tools/gb2/ff2en.py recording insert.py's code modules). In the English source:
  - listing instructions changed by the patch (hooks, operands) or by the MMC5 split are
    re-decoded from the new bytes when the decode lands back on the next listed
    instruction; operand-only changes keep the listing's comment;
  - insert.py's modules (fixed bank, bank 12, init) are code with their own labels;
  - the ExRAM code (bank 22 image, runs at $5C00) is written as exram.asm.

usage: ff2src.py ROM OUTDIR [--english | --gb] [--listing build/src/ff2/ff2j.asm]
  --gb: the English build plus the GB layout (tools/gb2/layout.py)
Writes OUTDIR/bankNN.asm (game banks 00-0E, fixed bank 0F), exram.asm (English),
map.json (code starts and labels per bank) and checks that each file reassembles
(tools/asm6502.py) to the ROM's bytes."""
import sys, os, re, json, hashlib, argparse
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..'))
from dis6502 import OPS, SIZE
from asm6502 import asm

BANK = 0x4000
EXRAM = 16                                     # index of the ExRAM "bank" (English only)
SHA1_FF12 = '4b22c2c88fc71eacf270ea51ef218944bb4c536a'
LINE = re.compile(r'^([0-9A-F]{2})/([0-9A-F]{4}): ([0-9A-F -]+?)(?:\s{2,}(.*))?$')
MNEMONICS = {mn for mn, md in OPS.values()}

def base(b): return 0xC000 if b == 15 else 0x5C00 if b == EXRAM else 0x8000

def parse_listing(path):
    """-> list of dicts: bank, addr, lead, bytes, text, comment, title, notes"""
    out = []; title = None; notes = []
    for raw in open(path, encoding='utf-8', errors='replace'):
        l = raw.rstrip('\n').replace('\xa0', ' ')
        m = LINE.match(l)
        if not m:
            s = l.strip()
            t = re.match(r'^;\s*\[\s*(.*?)\s*\]\s*$', s)
            if t: title = t.group(1) or None
            elif s.startswith(';'): notes.append(s[1:].strip())
            continue
        lead = 0; bs = []
        for t in m.group(3).split():
            if t == '--': lead += 1; continue          # leading byte not shown (stale code)
            if re.fullmatch(r'[0-9A-F]{2}', t): bs.append(int(t, 16))
            else: bs = None; break                     # word tables ("9100 9180 ...")
        rest = (m.group(4) or '').strip()
        text, _, com = rest.partition(';')
        out.append(dict(bank=int(m.group(1), 16), addr=int(m.group(2), 16), lead=lead, bytes=bs,
                        text=text.strip(), comment=com.strip(), title=title, notes=notes))
        title = None; notes = []
    return out

def decode(bk, off):
    if off >= len(bk) or bk[off] not in OPS: return None
    mn, md = OPS[bk[off]]; n = SIZE[md]
    if off + n > len(bk): return None
    return mn, md, bk[off:off + n]

def load(rom_path, english, gb=False):
    data = open(rom_path, 'rb').read()
    if hashlib.sha1(data).hexdigest() != SHA1_FF12:
        sys.exit('expected "Final Fantasy I, II (Japan).nes" (sha1 %s)' % SHA1_FF12)
    if not english:
        half = data[16 + 0x40000:16 + 0x80000]
        return [half[i * BANK:(i + 1) * BANK] for i in range(16)], [], data, 'ja'
    import importlib.util, tempfile
    spec = importlib.util.spec_from_file_location('build_mmc5', os.path.join(HERE, '..', 'split', 'build_mmc5.py'))
    bm = importlib.util.module_from_spec(spec); spec.loader.exec_module(bm)
    import ff2en
    tmp = tempfile.mkdtemp(prefix='ff2src_')
    mmc5 = os.path.join(tmp, 'ff2_mmc5.nes'); en = os.path.join(tmp, 'ff2_en.nes')
    gbn = os.path.join(tmp, 'ff2_gb.nes') if gb else None
    open(mmc5, 'wb').write(bm.build(data[16:], 2))
    mods = ff2en.record(mmc5, en, gb_out=gbn)
    rom = open(gbn or en, 'rb').read(); prg = rom[16:]
    banks = [prg[i * BANK:(i + 1) * BANK] for i in range(15)] + [prg[31 * BANK:32 * BANK]]
    ex = [m for m in mods if m['where'][0] == 22]
    assert len(ex) == 1
    banks.append(prg[22 * BANK:22 * BANK + len(ex[0]['bytes'])])
    if gb:                                     # the GB layout's code banks 23-30 (index = bank)
        banks += [b''] * (23 - len(banks))
        banks += [prg[i * BANK:(i + 1) * BANK] for i in range(23, 31)]
    return banks, mods, rom, 'gb' if gb else 'en'

def build(rom_path, outdir, listing, english=False, gb=False):
    banks, mods, rom, kind = load(rom_path, english or gb, gb)
    NB = len(banks)
    L = parse_listing(listing)
    code = [dict() for _ in range(NB)]          # bank -> {offset: entry}
    names = [dict() for _ in range(NB)]         # bank -> {offset: label from insert.py}
    rep = dict(kind=kind, mismatch=[], redecoded=[], overlap=[])
    # insert.py modules: instruction starts and labels; listing lines inside them are void
    span = [set() for _ in range(NB)]
    for m in mods:
        wb, woff = m['where']
        b = EXRAM if wb == 22 else 15 if wb == 31 else wb
        span[b] |= set(range(m['org'] - base(b), m['org'] - base(b) + len(m['bytes'])))
        for a in m['insns']:
            code[b][a - base(b)] = dict(title=None, notes=[], comment='')
        for k, a in m['labels'].items():
            if '.' not in k and base(b) <= a < base(b) + len(banks[b]): names[b][a - base(b)] = k
    per = [[] for _ in range(NB)]
    for e in L:
        if e['bytes'] is None or not e['text'] or e['text'].split()[0].upper() not in MNEMONICS:
            continue                                   # data line
        if e['lead']: rep['mismatch'].append('%02X/%04X %s (stale fragment)' % (e['bank'], e['addr'], e['text'])); continue
        o = e['addr'] - base(e['bank'])
        if o not in span[e['bank']]: per[e['bank']].append((o, e))
    # walk each bank's listed instructions in address order. Unchanged: code. Same opcode
    # and length, other operand: code. Otherwise (patch hooks, MMC5 split, compilation
    # boot) re-decode the new bytes until the decode lands on the next listed start.
    for b in range(NB):
        bk = banks[b]; ents = sorted(per[b], key=lambda x: x[0])
        bounds = {o for o, e in ents} | set(code[b]) | {len(bk)}
        cov = 0
        for o, e in ents:
            if o < cov: continue                       # inside a re-decoded instruction
            want = bytes(e['bytes']); dec = decode(bk, o)
            mn = e['text'].split()[0].upper()
            if dec and bk[o:o + len(want)] == want and dec[0] == mn:
                code[b][o] = e; cov = o + len(want); continue
            if dec and len(dec[2]) == len(want) and dec[2][0] == want[0]:
                code[b][o] = dict(e, comment=(e['comment'] + ' ' if e['comment'] else '') + '[operand changed]')
                rep['redecoded'].append('%02X/%04X operand' % (b, e['addr'])); cov = o + len(want); continue
            p = o; starts = []
            while True:
                d = decode(bk, p)
                if d is None or p in span[b] and p != o: break
                starts.append(p); p += len(d[2])
                if p in bounds: break
            if p in bounds and starts:
                for s in starts:
                    code[b][s] = dict(title=e['title'] if s == o else None, notes=e['notes'] if s == o else [],
                                      comment='[changed: was %s]' % e['text'] if s == o else '[changed]')
                rep['redecoded'].append('%02X/%04X %d instruction(s)' % (b, e['addr'], len(starts)))
                cov = p
            else:
                rep['mismatch'].append('%02X/%04X %s' % (b, e['addr'], e['text']))
    # overlapping instructions (stale code, jumps into another instruction): data
    skip = [set() for _ in range(NB)]
    for b in range(NB):
        s = sorted(code[b])
        for i in range(len(s) - 1):
            if s[i + 1] < s[i] + SIZE[OPS[banks[b][s[i]]][1]]:
                skip[b] |= {s[i], s[i + 1]}
        for o in sorted(skip[b]):
            rep['overlap'].append('%02X/%04X' % (b, o + base(b))); del code[b][o]
    # labels for jump/branch/call targets
    def owner(b, t):
        """bank whose code a target address t (seen from bank b) lands in, or None"""
        if t >= 0xC000: return 15
        if 0x5C00 <= t < 0x6000 and NB > EXRAM: return EXRAM
        if 0x8000 <= t < 0xC000 and b not in (15, EXRAM): return b
        return None                                  # fixed -> banked $8000: bank unknown
    labels = [dict(n) for n in names]
    for b in range(NB):
        for o in code[b]:
            mn, md, bs = decode(banks[b], o)
            if md == 'rel': t = (o + base(b) + 2 + ((bs[1] ^ 0x80) - 0x80)) & 0xFFFF
            elif mn in ('JSR', 'JMP') and md == 'abs': t = bs[1] | bs[2] << 8
            else: continue
            tb = owner(b, t)
            if tb is None: continue
            to = t - base(tb)
            if to in code[tb] and to not in labels[tb]:
                labels[tb][to] = ('F%04X' % t) if tb == 15 else ('X%04X' % t) if tb == EXRAM else ('L%02X_%04X' % (tb, t))
    glob = {}
    for b in (15, EXRAM):
        if b < NB: glob.update({v: base(b) + o for o, v in labels[b].items()})
    os.makedirs(outdir, exist_ok=True)
    ok = True; summary = {}
    for b in range(NB):
        bk = banks[b]; name = 'exram' if b == EXRAM else 'bank%02X' % b
        if not bk: continue
        lines = ['; FF2 %s (generated by tools/gb2/ff2src.py, %s; ROM-derived: never commit)' % (name, kind),
                 '    org $%04X' % base(b)]
        pend = []
        def flush():
            for i in range(0, len(pend), 16):
                lines.append('    .db ' + ', '.join('$%02X' % x for x in pend[i:i + 16]))
            pend.clear()
        o = 0; ncode = 0
        while o < len(bk):
            e = code[b].get(o)
            if e is None:
                if o in labels[b]: flush(); lines.append('%s:' % labels[b][o])
                pend.append(bk[o]); o += 1; continue
            flush()
            if e.get('title'): lines += ['', '; [ %s ]' % e['title']]
            for c in e.get('notes', []): lines.append('; ' + c)
            if o in labels[b]: lines.append('%s:' % labels[b][o])
            mn, md, bs = decode(bk, o)
            com = e.get('comment', '')
            lines.append('    ' + fmt(mn, md, bs, o + base(b), b, labels, owner) + ('    ; ' + com if com else ''))
            o += len(bs); ncode += len(bs)
        flush()
        src = '\n'.join(lines) + '\n'
        open(os.path.join(outdir, name + '.asm'), 'w').write(src)
        syms = {k: v for k, v in glob.items() if k not in labels[b].values()}
        r = asm(src, syms=syms)
        same = r.org == base(b) and r.bytes == bk
        ok &= same
        summary[name] = dict(code_bytes=ncode, labels=len(labels[b]), reassembles=same)
    json.dump(dict(kind=kind, rom_sha1=hashlib.sha1(rom).hexdigest(),
                   code={b: sorted(code[b]) for b in range(NB)},
                   labels={b: {str(k): v for k, v in labels[b].items()} for b in range(NB)},
                   report=rep, summary=summary),
              open(os.path.join(outdir, 'map.json'), 'w'), indent=0)
    return ok, summary, rep, rom

def fmt(mn, md, bs, pc, b, labels, owner):
    def tl(t):
        tb = owner(b, t)
        return None if tb is None else labels[tb].get(t - base(tb))
    mn = mn.lower()
    if md == 'imp': return mn
    if md == 'acc': return mn + ' a'
    if md == 'imm': return '%s #$%02X' % (mn, bs[1])
    if md == 'rel':
        t = (pc + 2 + ((bs[1] ^ 0x80) - 0x80)) & 0xFFFF
        return '%s %s' % (mn, tl(t) or '$%04X' % t)
    if SIZE[md] == 2:
        v = '$%02X' % bs[1]
        return mn + ' ' + {'zp': v, 'zpx': v + ',x', 'zpy': v + ',y', 'izx': '(%s,x)' % v, 'izy': '(%s),y' % v}[md]
    t = bs[1] | bs[2] << 8
    v = (tl(t) if mn in ('jsr', 'jmp') and md == 'abs' else None) or '$%04X' % t
    if t < 0x100 and md != 'ind': v = 'a:' + v
    return mn + ' ' + {'abs': v, 'abx': v + ',x', 'aby': v + ',y', 'ind': '(%s)' % v}[md]

if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('rom'); ap.add_argument('outdir')
    ap.add_argument('--english', action='store_true')
    ap.add_argument('--gb', action='store_true', help='English + GB layout (tools/gb2/layout.py)')
    ap.add_argument('--listing', default='build/src/ff2/ff2j.asm')
    a = ap.parse_args()
    ok, summary, rep, rom = build(a.rom, a.outdir, a.listing, a.english, a.gb)
    for n, s in summary.items():
        print('%-7s %5d code bytes, %4d labels, reassembles: %s' % (n, s['code_bytes'], s['labels'], s['reassembles']))
    print('source ROM sha1: %s' % hashlib.sha1(rom).hexdigest())
    print('re-decoded listing instructions (%d)' % len(rep['redecoded']))
    print('overlapping instructions kept as data: %s' % (', '.join(rep['overlap']) or 'none'))
    print('listed instructions left as data (%d): %s' % (len(rep['mismatch']), '; '.join(rep['mismatch'])))
    print('ALL FILES REASSEMBLE BYTE-IDENTICAL' if ok else 'REASSEMBLY MISMATCH')
    sys.exit(0 if ok else 1)
