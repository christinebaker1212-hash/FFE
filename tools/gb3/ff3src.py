"""FF3 source base: everything8215's annotated listing + the user's ROM -> 6502 source.

The everything8215/ff3 repository (fetched into build/src/ff3, never committed) is an
annotated listing of Final Fantasy III (J), not an assemblable source: lines
`BB/AAAA: bytes  MNEMONIC  ; comment` (BB = 8KB bank), covering the code (banks $10, $1F,
$2E-$36, $3A-$3F) and some tables, plus rom-map.txt and the RAM maps. This tool turns it
into assemblable source (same method as tools/gb2/ff2src.py for FF2):

  - instruction starts come from the listing (a line whose bytes match the ROM there);
    instructions are re-decoded from the ROM bytes, so the source can't drift from them;
  - every byte not covered as code is data, taken from the given ROM at build time
    (graphics, maps, text, music never come from this repo);
  - static flow: jump / branch / call targets that land outside the listed code inside a
    known bank are decoded too (code the listing lacks: the MMC5 conversion's ExRAM
    helpers, patch code), stopping at RTS / RTI / JMP, a known start, or undecodable bytes;
  - branch / jump / call targets get labels (Lbb_aaaa; fixed banks: Fxxxx; ExRAM: Xxxxx);
    the listing's routine titles and comments are kept.

Input ROM: "Final Fantasy III (Japan).nes" (MMC3, 64 banks), or with --english the
English MMC5 ROM made from it (runs tools/ff3_mmc5/build.py + tools/ff3/insert.py in a
temp dir, with tools/gb3/ff3en.py recording insert.py's code modules). English layout:
128 banks, the listing's $3E/$3F at 126/127, the ExRAM image (bank 64 $8000-$83FF, runs at
$5C00) written as exram.asm. In the English source:
  - listing instructions changed by the patch (hooks, operands) or by the MMC3 -> MMC5
    conversion are re-decoded from the new bytes when the decode lands back on the next
    listed instruction; operand-only changes keep the listing's comment;
  - insert.py's modules are code with their own labels.

usage: ff3src.py ROM OUTDIR [--english] [--listing build/src/ff3/ff3j.asm]
Writes OUTDIR/bankNN.asm (hex bank numbers of the source ROM, banks holding code only),
exram.asm (English), map.json (code starts, labels, CPU base per bank) and checks that each
file reassembles (tools/asm6502.py) to the ROM's bytes."""
import sys, os, re, json, hashlib, argparse
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..'))
sys.path.insert(0, HERE)
from dis6502 import OPS, SIZE
from asm6502 import asm

B8 = 0x2000
EXRAM = 128                                    # index of the ExRAM "bank" (English only)
SHA1_JA = 'c4443fc24625e3c2bb859525eb44b6b3a80e7c35'
LINE = re.compile(r'^([0-9A-F]{2})/([0-9A-F]{4}): ([0-9A-F -]+?)(?:\s{2,}(.*))?$')
MNEMONICS = {mn for mn, md in OPS.values()}

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
            elif s.startswith(';') and not s.startswith('; ---') and not s.startswith('; |') \
                    and not s.startswith('; +'):
                notes.append(s[1:].strip())
            continue
        lead = 0; bs = []
        for t in m.group(3).split():
            if t == '--': lead += 1; continue          # leading byte not shown (stale code)
            if re.fullmatch(r'[0-9A-F]{2}', t): bs.append(int(t, 16))
            else: bs = None; break                     # word tables ("A601 A614 ...")
        rest = (m.group(4) or '').strip()
        text, _, com = rest.partition(';')
        out.append(dict(bank=int(m.group(1), 16), addr=int(m.group(2), 16), lead=lead, bytes=bs,
                        text=text.strip(), comment=com.strip(), title=title, notes=notes))
        title = None; notes = []
    return out

class Rom:
    """banks: {index: bytes}; base: {index: CPU address of byte 0}; lmap: listing bank ->
    index; fixed: (index at $C000, index at $E000)"""
    def __init__(self, path, english):
        data = open(path, 'rb').read()
        if hashlib.sha1(data).hexdigest() != SHA1_JA:
            sys.exit('expected "Final Fantasy III (Japan).nes" (sha1 %s)' % SHA1_JA)
        self.mods = []; self.seeds = []
        if english:
            import importlib.util, tempfile
            spec = importlib.util.spec_from_file_location('ff3_mmc5_build', os.path.join(HERE, '..', 'ff3_mmc5', 'build.py'))
            bm = importlib.util.module_from_spec(spec); spec.loader.exec_module(bm)
            import ff3en
            tmp = tempfile.mkdtemp(prefix='ff3src_')
            mmc5 = os.path.join(tmp, 'ff3_mmc5.nes'); en = os.path.join(tmp, 'ff3_en.nes')
            out = bm.convert(data[16:])
            open(mmc5, 'wb').write(out if out[:4] == b'NES\x1a' else bytes(16) + out)
            self.mods = ff3en.record(mmc5, en)
            # the MMC5 converter's ExRAM helpers: code parts named by build.py (irq_entry is
            # reached through the RAM vector at $0103, the others by direct calls)
            self.seeds = [(EXRAM, bm.LABELS[k] - 0x5C00, 'tools/ff3_mmc5 ' + k)
                          for k in ('irq_entry', 'enable', 'fx2f', 'mir_h', 'mir_v') if k in bm.LABELS]
            data = open(en, 'rb').read()
        self.rom = data; prg = data[16:]
        n = len(prg) // B8
        self.banks = {i: prg[i * B8:(i + 1) * B8] for i in range(n)}
        self.fixed = (n - 2, n - 1)
        self.base = {i: 0x8000 if i % 2 == 0 else 0xA000 for i in range(n)}
        self.base[n - 2] = 0xC000; self.base[n - 1] = 0xE000
        self.lmap = {b: b for b in range(0x3E)}
        self.lmap[0x3E] = n - 2; self.lmap[0x3F] = n - 1
        self.kind = 'en' if english else 'ja'
        if english:
            self.banks[EXRAM] = prg[64 * B8:64 * B8 + 0x400]; self.base[EXRAM] = 0x5C00
            for m in self.mods:
                if m['where'] and m['where'][0] != EXRAM:
                    self.base[m['where'][0]] = m['org'] & 0xE000

def decode(bk, off):
    if off < 0 or off >= len(bk) or bk[off] not in OPS: return None
    mn, md = OPS[bk[off]]; n = SIZE[md]
    if off + n > len(bk): return None
    return mn, md, bk[off:off + n]

def target(mn, md, bs, pc):
    if md == 'rel': return (pc + 2 + ((bs[1] ^ 0x80) - 0x80)) & 0xFFFF
    if mn in ('JSR', 'JMP') and md == 'abs': return bs[1] | bs[2] << 8
    return None

def build(rom_path, outdir, listing, english=False):
    R = Rom(rom_path, english)
    banks, base = R.banks, R.base
    code = {b: {} for b in banks}               # bank -> {offset: entry}
    names = {b: {} for b in banks}              # bank -> {offset: label from insert.py}
    span = {b: set() for b in banks}
    rep = dict(kind=R.kind, mismatch=[], redecoded=[], overlap=[], flow=[], realigned=[], unknown_bank=0)
    for m in R.mods:
        if not m['where']: continue
        b = m['where'][0]
        o0 = m['org'] - base[b]
        span[b] |= set(range(o0, o0 + len(m['bytes'])))
        for a in m['insns']:
            code[b][a - base[b]] = dict(title=None, notes=[], comment='')
        for k, a in m['labels'].items():
            if '.' not in k and base[b] <= a < base[b] + len(banks[b]): names[b][a - base[b]] = k
    per = {b: [] for b in banks}
    for e in parse_listing(listing):
        if e['bytes'] is None or not e['text'] or e['text'].split()[0].upper() not in MNEMONICS:
            continue                                   # data line
        if e['lead']: rep['mismatch'].append('%02X/%04X %s (stale fragment)' % (e['bank'], e['addr'], e['text'])); continue
        b = R.lmap.get(e['bank'])
        if b is None: continue
        o = e['addr'] - base[b]
        if not 0 <= o < len(banks[b]):
            rep['mismatch'].append('%02X/%04X %s (outside the bank window)' % (e['bank'], e['addr'], e['text'])); continue
        if o not in span[b]: per[b].append((o, e))
    # walk each bank's listed instructions in address order. Unchanged: code. Same opcode
    # and length, other operand: code. Otherwise (patch hooks, MMC5 conversion) re-decode
    # the new bytes until the decode lands on the next listed start.
    for b in banks:
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
                rep['redecoded'].append('%02X/%04X operand' % (e['bank'], e['addr'])); cov = o + len(want); continue
            p = o; starts = []; term = False
            while True:
                d = decode(bk, p)
                if d is None or p in span[b] and p != o: break
                starts.append(p); p += len(d[2])
                if p in bounds: break
                if d[0] in ('JMP', 'RTS', 'RTI'):       # (a patched jump over a cut-up
                    term = True; break                  #   instruction: the rest is dead)
            if (p in bounds or term) and starts:
                for s in starts:
                    code[b][s] = dict(title=e['title'] if s == o else None, notes=e['notes'] if s == o else [],
                                      comment='[changed: was %s]' % e['text'] if s == o else '[changed]', soft=True)
                rep['redecoded'].append('%02X/%04X %d instruction(s)' % (e['bank'], e['addr'], len(starts)))
                cov = p
            else:
                rep['mismatch'].append('%02X/%04X %s' % (e['bank'], e['addr'], e['text']))
    cfix, efix = R.fixed
    def owner(b, t):
        """bank whose code a target address t (seen from bank b) lands in, or None"""
        if t >= 0xE000: return efix
        if t >= 0xC000: return cfix
        if 0x5C00 <= t < 0x6000 and EXRAM in banks: return EXRAM
        if base[b] <= t < base[b] + B8 and b not in (cfix, efix, EXRAM): return b
        return None                                  # other window: bank unknown here
    # static flow from every known instruction (and the vectors) into undecoded bytes
    def flow_from(b, o, why):
        work = [(b, o)]; added = 0
        while work:
            b, o = work.pop()
            if o in code[b] or not 0 <= o < len(banks[b]): continue
            taken = {p for s in code[b] for p in range(s, s + SIZE[OPS[banks[b][s]][1]])}
            p = o; run = []
            while True:
                if p in code[b]: break
                d = decode(banks[b], p)
                if d is None or any(q in taken for q in range(p, p + len(d[2]))):
                    run = None; break               # data or overlap: not code
                run.append(p)
                t = target(d[0], d[1], d[2], base[b] + p)
                if t is not None:
                    tb = owner(b, t)
                    if tb is not None: work.append((tb, t - base[tb]))
                p += len(d[2])
                if d[0] in ('JMP', 'RTS', 'RTI'): break
            if not run: continue
            for s in run: code[b][s] = dict(title=None, notes=[], comment='[flow]' if s == run[0] else '', soft=True)
            added += len(run)
            rep['flow'].append('%s %s: %d instruction(s) from %s' % (('X' if b == EXRAM else '%02X' % b),
                                                                 '%04X' % (base[b] + run[0]), len(run), why))
        return added
    vec = banks[efix]
    for i, nm in ((0x1FFA, 'NMI'), (0x1FFC, 'RESET'), (0x1FFE, 'IRQ')):
        t = vec[i] | vec[i + 1] << 8
        tb = owner(efix, t)
        if tb is not None: flow_from(tb, t - base[tb], nm + ' vector')
    for b, o, why in R.seeds: flow_from(b, o, why)
    changed = True
    while changed:
        changed = False
        for b in banks:
            for o in sorted(code[b]):
                d = decode(banks[b], o)
                t = target(d[0], d[1], d[2], base[b] + o)
                if t is None: continue
                tb = owner(b, t)
                if tb is None: continue
                to = t - base[tb]
                if 0 <= to < len(banks[tb]) and to not in code[tb]:
                    # a target inside a re-decoded / flow instruction: the target wins
                    # (drop the soft run from the containing instruction on)
                    inside = [q for q in code[tb] if q < to < q + SIZE[OPS[banks[tb][q]][1]]]
                    if not inside:              # in a gap just before a soft run
                        inside = [q for q in code[tb] if to < q < to + 3 and code[tb][q].get('soft')][:1]
                    if inside and code[tb][inside[0]].get('soft'):
                        q = inside[0]; n = 0
                        while q in code[tb] and code[tb][q].get('soft'):
                            nq = q + SIZE[OPS[banks[tb][q]][1]]; del code[tb][q]; q = nq; n += 1
                        rep['realigned'].append('%02X/%04X: %d soft instruction(s) dropped for target %04X'
                                                % (tb, base[tb] + inside[0], n, t))
                    elif inside: continue
                    if flow_from(tb, to, '%s/%04X' % ('X' if b == EXRAM else '%02X' % b, base[b] + o)):
                        changed = True
    # overlapping instructions (stale code, jumps into another instruction): data
    for b in banks:
        s = sorted(code[b]); skip = set()
        for i in range(len(s) - 1):
            if s[i + 1] < s[i] + SIZE[OPS[banks[b][s[i]]][1]]:
                skip |= {s[i], s[i + 1]}
        for o in sorted(skip):
            rep['overlap'].append('%02X/%04X' % (b, o + base[b])); del code[b][o]
    # labels for jump/branch/call targets
    def lname(tb, t):
        return ('F%04X' % t) if tb in (cfix, efix) else ('X%04X' % t) if tb == EXRAM else ('L%02X_%04X' % (tb, t))
    labels = {b: dict(names[b]) for b in banks}
    for b in banks:
        for o in code[b]:
            d = decode(banks[b], o)
            t = target(d[0], d[1], d[2], o + base[b])
            if t is None: continue
            tb = owner(b, t)
            if tb is None:
                rep['unknown_bank'] += 1; continue
            to = t - base[tb]
            if to in code[tb] and to not in labels[tb]: labels[tb][to] = lname(tb, t)
    glob = {}
    for b in (cfix, efix, EXRAM):
        if b in banks: glob.update({v: base[b] + o for o, v in labels[b].items()})
    os.makedirs(outdir, exist_ok=True)
    ok = True; summary = {}
    for b in sorted(banks):
        if not code[b]: continue
        bk = banks[b]; name = 'exram' if b == EXRAM else 'bank%02X' % b
        lines = ['; FF3 %s (generated by tools/gb3/ff3src.py, %s; ROM-derived: never commit)' % (name, R.kind),
                 '    org $%04X' % base[b]]
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
            lines.append('    ' + fmt(mn, md, bs, o + base[b], b, labels, owner, base) + ('    ; ' + com if com else ''))
            o += len(bs); ncode += len(bs)
        flush()
        src = '\n'.join(lines) + '\n'
        open(os.path.join(outdir, name + '.asm'), 'w').write(src)
        syms = {k: v for k, v in glob.items() if k not in labels[b].values()}
        r = asm(src, syms=syms)
        same = r.org == base[b] and r.bytes == bk
        ok &= same
        summary[name] = dict(code_bytes=ncode, labels=len(labels[b]), reassembles=same)
    json.dump(dict(kind=R.kind, rom_sha1=hashlib.sha1(R.rom).hexdigest(),
                   base={b: base[b] for b in banks if code[b]},
                   fixed=list(R.fixed),
                   code={b: sorted(code[b]) for b in banks if code[b]},
                   labels={b: {str(k): v for k, v in labels[b].items()} for b in banks if code[b]},
                   report=rep, summary=summary),
              open(os.path.join(outdir, 'map.json'), 'w'), indent=0)
    return ok, summary, rep, R.rom

def fmt(mn, md, bs, pc, b, labels, owner, base):
    def tl(t):
        tb = owner(b, t)
        return None if tb is None else labels[tb].get(t - base[tb])
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
    ap.add_argument('--listing', default='build/src/ff3/ff3j.asm')
    ap.add_argument('-v', action='store_true', help='list every re-decoded / flow item')
    a = ap.parse_args()
    ok, summary, rep, rom = build(a.rom, a.outdir, a.listing, a.english)
    tot = 0
    for n, s in summary.items():
        print('%-7s %5d code bytes, %4d labels, reassembles: %s' % (n, s['code_bytes'], s['labels'], s['reassembles']))
        tot += s['code_bytes']
    print('code bytes in total: %d' % tot)
    print('source ROM sha1: %s' % hashlib.sha1(rom).hexdigest())
    print('re-decoded listing instructions: %d' % len(rep['redecoded']))
    print('static-flow runs added: %d (%d instructions)' % (len(rep['flow']), sum(int(x.split(': ')[1].split()[0]) for x in rep['flow'])))
    if a.v:
        for x in rep['redecoded'] + rep['flow']: print('  ' + x)
    for x in rep['realigned']: print('realigned: ' + x)
    print('jumps/calls into another bank window (bank unknown statically): %d' % rep['unknown_bank'])
    print('overlapping instructions kept as data: %s' % (', '.join(rep['overlap']) or 'none'))
    print('listed instructions left as data (%d): %s' % (len(rep['mismatch']), '; '.join(rep['mismatch'])))
    print('ALL FILES REASSEMBLE BYTE-IDENTICAL' if ok else 'REASSEMBLY MISMATCH')
    sys.exit(0 if ok else 1)
