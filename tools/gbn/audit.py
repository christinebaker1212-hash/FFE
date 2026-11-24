"""Audit of every game table the native build reads from the user's ROM, against a trusted
source: the FF1 disassembly (Entroper/FF1Disassembly, US release, cloned into build/ref/ at work
time, never committed). Owner, 2026-11-24: "Compare current data tables for all data against
trusted sources."

The build is run with every ROM read logged (bank, address, length, calling function); the reads
are merged into ranges per bank; each range is compared with the disassembly's bytes at the same
address (its whole data banks bank_XX.dat / bank_01_data.bin / bank_09_data.bin and its table
files bin/BB_AAAA_name.bin). Results per range:
  same      the user's ROM holds the disassembly's table at that address (layout and data agree)
  moved     the disassembly's bytes are found at another address of the user's ROM: the Japanese
            layout differs there; the build must read the Japanese address (checked: which one it uses)
  differs   neither: a Japanese / translation difference (text, names, a changed value) to review
  part      only some bytes covered by the disassembly's binaries: those compared
  no ref    the disassembly has no binary for that address (code banks' inline tables)
usage: python3 tools/gbn/audit.py [NES_ROM]   (default build/ff1_gb.nes)"""
import os, sys, glob, re, inspect, collections
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.join(HERE, '..', '..')
REF = os.path.join(ROOT, 'build', 'ref', 'FF1Disassembly', 'Final Fantasy Disassembly')
sys.path.insert(0, HERE); sys.path.insert(0, os.path.join(HERE, '..', 'gb'))


def us_reference():
    """bank -> 16 KB bytearray of the US data where the disassembly has it, and a mask"""
    ref = {}; mask = {}
    def put(bank, addr, data):
        if bank not in ref: ref[bank] = bytearray(0x4000); mask[bank] = bytearray(0x4000)
        o = addr - (0xC000 if bank == 0x0F else 0x8000)
        n = min(len(data), 0x4000 - o)
        ref[bank][o:o + n] = data[:n]; mask[bank][o:o + n] = b'\1' * n
    for f in glob.glob(os.path.join(REF, 'bank_*.dat')):
        b = int(os.path.basename(f)[5:7], 16); put(b, 0x8000, open(f, 'rb').read())
    for f, b in (('bank_01_data.bin', 1), ('bank_09_data.bin', 9)):
        p = os.path.join(REF, 'bin', f)
        if os.path.exists(p): put(b, 0x8000, open(p, 'rb').read())
    for f in glob.glob(os.path.join(REF, 'bin', '*.bin')):
        m = re.match(r'([0-9A-F]{2})_([0-9A-F]{4})_', os.path.basename(f))
        if m: put(int(m.group(1), 16), int(m.group(2), 16), open(f, 'rb').read())
    # inline tables in the code banks' source: data lines after an address marker "[$AAAA ::"
    for f in glob.glob(os.path.join(REF, 'bank_*.asm')):
        b = int(os.path.basename(f)[5:7], 16)
        cur = None; buf = bytearray(); start = None
        def flush():
            if start is not None and buf: put(b, start, bytes(buf))
        for line in open(f, encoding='latin-1'):
            sg = re.match(r'\s*\.segment\s+"BANK_([0-9A-F]{2})"', line, re.I)
            if sg:                                  # the bank's start
                flush(); start = cur = 0xC000 if int(sg.group(1), 16) == 0x0F else 0x8000; buf = bytearray(); continue
            m = re.search(r'\[\$([0-9A-Fa-f]{4})\s*::', line)
            if m:
                flush(); start = cur = int(m.group(1), 16); buf = bytearray(); continue
            t = line.split(';')[0].strip()
            if not t or t.endswith(':'): continue
            if cur is None: continue
            d = re.match(r'\.(BYTE|WORD|FARADDR|INCBIN)\s+(.*)', t, re.I)
            if not d:
                flush(); cur = start = None; buf = bytearray(); continue      # code: unknown from here
            kind, args = d.group(1).upper(), d.group(2)
            if kind == 'INCBIN':
                pth = os.path.join(REF, args.strip().strip('"'))
                if os.path.exists(pth): buf += open(pth, 'rb').read(); continue
                flush(); cur = start = None; buf = bytearray(); continue
            vals = []
            ok = True
            for v in [x.strip() for x in args.split(',') if x.strip()]:
                v = v.replace('$', '0x')
                try: vals.append(int(v, 0))
                except ValueError: ok = False; break
            if not ok:
                flush(); cur = start = None; buf = bytearray(); continue
            w = {'BYTE': 1, 'WORD': 2, 'FARADDR': 3}[kind]
            for v in vals: buf += (v & ((1 << (8 * w)) - 1)).to_bytes(w, 'little')
        flush()
    return ref, mask


def run_build_logged(nes):
    import data
    log = []
    orig = data.Rom.rd
    def rd(self, bank, addr, n=1):
        fr = inspect.stack()[1]
        log.append((bank, addr, n, '%s:%s' % (os.path.basename(fr.filename), fr.function)))
        return orig(self, bank, addr, n)
    data.Rom.rd = rd

    class View(bytes):
        """the ROM's bytes (a bytes object, so searches and regexes work natively): indexed reads
        and small slices logged; slices of more than 4 KB (banks for code searches) stay views"""
        def __new__(cls, b, off=0):
            o = super().__new__(cls, b); o.off = off; return o
        def _log(self, o, n):
            fr = inspect.stack()[2]
            for a in range(o, o + n):
                bank = a // 0x4000
                log.append((bank, (0xC000 if bank == 15 else 0x8000) + a % 0x4000, 1,
                            '%s:%s' % (os.path.basename(fr.filename), fr.function)))
        def __getitem__(self, k):
            if isinstance(k, slice):
                st, sp, step = k.indices(len(self))
                r = bytes.__getitem__(self, k)
                if sp - st > 4096: return View(r, self.off + st)
                self._log(self.off + st, max(0, sp - st)); return r
            if k < 0: k += len(self)
            self._log(self.off + k, 1); return bytes.__getitem__(self, k)
    oinit = data.Rom.__init__
    def init(self, path):
        oinit(self, path); self.prg = View(self.prg)
    data.Rom.__init__ = init
    import importlib.util
    spec = importlib.util.spec_from_file_location('gbn_build', os.path.join(HERE, 'build.py'))
    build = importlib.util.module_from_spec(spec); spec.loader.exec_module(build)
    out = os.path.join(ROOT, 'build', 'audit_tmp.gb')
    sys.argv = ['build.py', '--nes', nes, '--out', out]
    build.main()
    data.Rom.rd = orig; data.Rom.__init__ = oinit
    return log


def main():
    nes = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'build', 'ff1_gb.nes')
    if not os.path.isdir(REF):
        print('no disassembly at', REF, '(clone github.com/Entroper/FF1Disassembly into build/ref/)'); return
    rom = open(nes, 'rb').read()[16:]
    ref, mask = us_reference()
    log = run_build_logged(nes)
    by = collections.defaultdict(set); callers = collections.defaultdict(set)
    for bank, addr, n, who in log:
        base = 0xC000 if bank == 0x0F and addr >= 0xC000 else 0x8000
        for a in range(addr, addr + n):
            by[bank].add(a); callers[(bank, a)].add(who)
    rows = []
    for bank in sorted(by):
        addrs = sorted(by[bank]); start = prev = addrs[0]
        spans = []
        for a in addrs[1:] + [None]:
            if a is None or a != prev + 1:
                spans.append((start, prev)); start = a
            prev = a if a is not None else prev
        for lo, hi in spans:
            n = hi - lo + 1
            base = 0xC000 if bank == 0x0F else 0x8000
            o = bank * 0x4000 + lo - base
            mine = rom[o:o + n]
            who = sorted(set().union(*(callers[(bank, a)] for a in range(lo, hi + 1))))
            cov = sum(mask[bank][lo - base:min(hi - base + 1, 0x4000)]) if bank in ref else 0
            if cov == 0:
                st = 'no ref'
            elif cov < n:                           # partly covered: the covered bytes compared
                d = sum(1 for k in range(min(n, 0x4000 - lo + base)) if mask[bank][lo - base + k] and ref[bank][lo - base + k] != mine[k])
                st = 'part: %d of %d covered, %d differ' % (cov, n, d)
            else:
                us = bytes(ref[bank][lo - base:hi - base + 1])
                if us == mine: st = 'same'
                else:
                    diff = sum(1 for x, y in zip(us, mine) if x != y)
                    k = rom.find(us) if n >= 8 else -1
                    st = ('moved: US bytes at %02X:%04X' % (k // 0x4000, k % 0x4000 + 0x8000)) if k >= 0 else \
                         'differs (%d of %d bytes)' % (diff, n)
            rows.append((bank, lo, n, st, ', '.join(who)))
    jp_path = os.path.join(ROOT, 'roms', 'Final Fantasy I, II (Japan).nes')
    jp = open(jp_path, 'rb').read()[16:] if os.path.exists(jp_path) else None
    if jp:                                          # not as the US data: as the original Japanese ROM?
        out = []
        for bank, lo, n, st, who in rows:
            if not st.startswith('same') and bank < 16:
                base = 0xC000 if bank == 0x0F else 0x8000
                o = bank * 0x4000 + lo - base
                st += '; = Japanese ROM' if rom[o:o + n] == jp[o:o + n] else '; CHANGED from the Japanese ROM'
            elif not st.startswith('same'):
                st += '; English insert bank'
            out.append((bank, lo, n, st, who))
        rows = out
    cnt = collections.Counter(r[3].split(':')[0].split(' (')[0].split(';')[0] for r in rows)
    for bank, lo, n, st, who in rows:
        print('%02X:%04X %5d  %-34s %s' % (bank, lo, n, st, who))
    print('ranges:', dict(cnt))


if __name__ == '__main__':
    main()
