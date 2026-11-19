"""Record the English patch's code (tools/ff3/insert.py) for the FF3 source base.

insert.py assembles its engine changes from 6502 source (tools/asm6502.py modules: ExRAM
code, fixed-bank code, the battle text converter, field-menu helpers, ...) and writes hook
bytes into the game's code. This runs insert.py unchanged with a recording asm(): for each
module it notes the origin, the bytes, the labels and every instruction start (found by
assembling a copy with a local marker label before each instruction line; labels do not
change the bytes, and the copy's bytes are checked against the original's). Same method as
tools/gb2/ff2en.py (FF2).

usage (library): modules = record(mmc5_in, en_out)   -> list of dicts
  org, bytes, labels, insns (CPU addresses of instruction starts), where (bank, offset)
  bank = 8KB bank of the 1MB MMC5 ROM; EXRAM (128) for the ExRAM image (bank 64's first
  1KB, copied to $5C00 at reset)
usage (command line): ff3en.py ff3_mmc5.nes OUT.nes   (lists the modules)"""
import sys, os, re, types, runpy
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..'))
import asm6502

EXRAM = 128
B8 = 0x2000
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
    argv = sys.argv
    try:
        sys.argv = ['insert.py', mmc5_in, en_out]
        runpy.run_path(script or os.path.join(HERE, '..', 'ff3', 'insert.py'), run_name='__main__')
    finally:
        sys.argv = argv
        if saved is not None: sys.modules['asm6502'] = saved
        else: del sys.modules['asm6502']
    prg = open(en_out, 'rb').read()[16:]
    nb = len(prg) // B8
    for m in mods:
        o = m['org']; n = len(m['bytes'])
        if 0x5C00 <= o < 0x6000:            # ExRAM image: bank 64 $8000-$83FF, runs at $5C00
            m['where'] = (EXRAM, o - 0x5C00)
            continue
        if o >= 0xE000: cands = [nb - 1]
        elif o >= 0xC000: cands = [nb - 2]
        else: cands = range(nb - 2)
        hits = [b for b in cands if prg[b * B8 + (o & 0x1FFF):b * B8 + (o & 0x1FFF) + n] == m['bytes']]
        if not hits and m['insns']:         # tables inside the module filled in afterwards:
            k = max(m['insns']) - o + 1     #   match the code part (up to the last opcode)
            hits = [b for b in cands if prg[b * B8 + (o & 0x1FFF):b * B8 + (o & 0x1FFF) + k] == m['bytes'][:k]]
        if len(hits) != 1:                  # (an unused module)
            m['where'] = None; continue
        m['where'] = (hits[0], o & 0x1FFF)
    return mods

if __name__ == '__main__':
    mods = record(sys.argv[1], sys.argv[2])
    for m in mods:
        w = m['where']
        print('module org %04X len %4d at %s: %d instructions, %d labels' %
              (m['org'], len(m['bytes']), 'bank %d+%04X' % w if w else 'NOT FOUND',
               len(m['insns']), len(m['labels'])))
