"""Record the English patch's code (tools/ff2/insert.py) for the FF2 source base.

insert.py assembles its engine changes from 6502 source (tools/asm6502.py modules:
ExRAM code, fixed-bank code, the bank 12 converter, init) and writes hook bytes into
the game's code. This runs insert.py unchanged with a recording asm(): for each module
it notes the origin, the bytes, the labels and every instruction start (found by
assembling a copy with a local marker label before each instruction line; labels do
not change the bytes, and the copy's bytes are checked against the original's).

usage (library): modules = record(mmc5_in, en_out)   -> list of dicts
  org, bytes, labels, insns (CPU addresses of instruction starts), where (bank, offset)"""
import sys, os, re, types, runpy, hashlib
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..'))
import asm6502

DIRECTIVE = re.compile(r'^\s*(org|\.db|\.dw|\.ds)\b', re.I)
CONST = re.compile(r'^\s*[A-Za-z_.][A-Za-z_0-9.]*\s*=')
LABEL = re.compile(r'^\s*([A-Za-z_.][A-Za-z_0-9.]*):(.*)$')

def marked(src):
    out = []; n = 0
    for raw in src.split('\n'):
        line = raw.split(';')[0].rstrip()
        if not line.strip() or CONST.match(line): out.append(raw); continue
        m = LABEL.match(line); rest = m.group(2) if m else line
        if rest.strip() and not DIRECTIVE.match(rest):
            out.append('.__i%d:' % n); n += 1
        out.append(raw)
    return '\n'.join(out), n

def record(mmc5_in, en_out, script=None):
    real = asm6502.asm; mods = []
    def rec(src, syms=None, org=0x8000):
        r = real(src, syms=syms, org=org)
        msrc, n = marked(src)
        r2 = real(msrc, syms=syms, org=org)
        assert r2.bytes == r.bytes and r2.org == r.org, 'marker labels changed the bytes'
        insns = sorted(v for k, v in r2.labels.items() if re.search(r'\.__i\d+$', k))
        assert len(insns) == n
        labels = {k: v for k, v in r.labels.items() if (syms is None or k not in syms)}
        mods.append(dict(org=r.org, bytes=r.bytes, labels=labels, insns=insns))
        return r
    fake = types.ModuleType('asm6502'); fake.asm = rec
    saved = sys.modules.get('asm6502'); sys.modules['asm6502'] = fake
    argv = sys.argv; cwd = os.getcwd()
    try:
        sys.argv = ['insert.py', mmc5_in, en_out]
        runpy.run_path(script or os.path.join(HERE, '..', 'ff2', 'insert.py'), run_name='__main__')
    finally:
        sys.argv = argv
        if saved is not None: sys.modules['asm6502'] = saved
    rom = open(en_out, 'rb').read()[16:]
    B = 0x4000
    for m in mods:
        o = m['org']; n = len(m['bytes'])
        if 0x5C00 <= o < 0x6000:  # ExRAM image: bank 22 (copied to $5C00 at reset); SYSONE bits differ
            m['where'] = (22, o - 0x5C00)
        elif o >= 0xC000:
            m['where'] = (31, o - 0xC000)
        else:
            hits = [b for b in range(32) if rom[b * B + o - 0x8000:b * B + o - 0x8000 + n] == m['bytes']]
            assert len(hits) == 1, (hex(o), hits)
            m['where'] = (hits[0], o - 0x8000)
    return mods

if __name__ == '__main__':
    mods = record(sys.argv[1], sys.argv[2])
    for m in mods:
        print('module org %04X len %4d at bank %d+%04X: %d instructions, %d labels' %
              (m['org'], len(m['bytes']), m['where'][0], m['where'][1], len(m['insns']), len(m['labels'])))
