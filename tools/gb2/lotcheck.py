"""Lot Check checks for a built Game Boy ROM (docs/gb-release-requirements.md).

usage: python3 tools/gb2/lotcheck.py GB [--cgb 80|C0|none] [--no-sgb] [--type 1B] [--ram 4]
       [--run NES FRAMES [--random SEED]] [--reset] [--release]

Static (always):
  - header: Nintendo logo, header and global checksums, CGB / SGB flags (SGB needs old
    licensee $33), cartridge type, ROM size against the file size, RAM size, entry point
  - padding: unused space in every bank one filler byte ($FF)
  - LCD off: every write to LCDC ($FF40) in the assembled source (GB + '.s') must keep the
    LCD on (a value with bit 7 set, or a read-modify-write of bits 0-6) or be labelled
    `.lcdoff`; an `.lcdoff` write must follow a wait for LY >= 144 within a few lines
  - debug code: test-only paths (`TEST_PAD`, the rst $38 trap) listed; with --release
    the test-runner pad path must be absent
Dynamic (PyBoy; GB_CGB=1 for a Color):
  --run NES FRAMES [--random S]: firstdiff's input; at every `.lcdoff` label reached, LY
      must be 144-153 (the LCD goes off only in the V-Blank)
  --reset: A + B + Select + Start in the middle of play restarts the game: the screen and
      work RAM some frame waits later match a fresh power-on at the same wait
Exit status 1 if any check fails."""
import os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'gb')); sys.path.insert(0, HERE)
from asm_sm83 import NINTENDO_LOGO

FAIL = []


def check(ok, msg):
    print(('  ok    ' if ok else '  FAIL  ') + msg)
    if not ok: FAIL.append(msg)


def header(rom, cgb, sgb, ctype, ram):
    print('header')
    check(rom[0x104:0x134] == NINTENDO_LOGO, 'Nintendo logo $0104-$0133')
    x = 0
    for i in range(0x134, 0x14D): x = (x - rom[i] - 1) & 0xFF
    check(rom[0x14D] == x, 'header checksum $014D = %02X (computed %02X)' % (rom[0x14D], x))
    s = (sum(rom) - rom[0x14E] - rom[0x14F]) & 0xFFFF
    g = rom[0x14E] << 8 | rom[0x14F]
    check(g == s, 'global checksum $014E = %04X (computed %04X)' % (g, s))
    if cgb is None: check(rom[0x143] < 0x80, 'CGB flag $0143 = %02X (DMG only)' % rom[0x143])
    else: check(rom[0x143] == cgb, 'CGB flag $0143 = %02X (want %02X)' % (rom[0x143], cgb))
    check(rom[0x146] == (3 if sgb else 0), 'SGB flag $0146 = %02X' % rom[0x146])
    if sgb: check(rom[0x14B] == 0x33, 'old licensee $014B = $33 (needed for SGB functions)')
    check(rom[0x147] == ctype, 'cartridge type $0147 = %02X (want %02X)' % (rom[0x147], ctype))
    size = 0x8000 << rom[0x148] if rom[0x148] <= 8 else -1
    check(size == len(rom), 'ROM size $0148 = %02X: %d KB, file %d KB' % (rom[0x148], size // 1024, len(rom) // 1024))
    check(rom[0x149] == ram, 'RAM size $0149 = %02X (want %02X)' % (rom[0x149], ram))
    ep = rom[0x100:0x104]
    check(ep[0] in (0x00, 0xF3) and ep[1] == 0xC3, 'entry point $0100: %s (NOP / DI, JP)' % ep.hex(' '))
    check(all(32 <= c < 127 or c == 0 for c in rom[0x134:0x143]), 'title $0134: %r' % bytes(rom[0x134:0x143]).rstrip(b'\0'))


def padding(rom, src):
    """unused space: everything after a bank's last assembled byte, and the gaps between
    sections, is the assembler's filler $FF; report the filler and free bytes per code bank"""
    print('padding')
    nb = len(rom) // 0x4000
    zero_tail = [b for b in range(nb) if rom[b * 0x4000 + 0x3FF0:(b + 1) * 0x4000] == bytes(16)]
    free = {}
    for b in range(nb):
        d = rom[b * 0x4000:(b + 1) * 0x4000]
        n = len(d) - len(d.rstrip(b'\xff'))
        free[b] = n
    check(not zero_tail, 'unused bank tails filled with $FF (banks ending in $00: %s)' % (zero_tail or 'none'))
    empty = [b for b in range(nb) if free[b] == 0x4000]
    print('        free at the end of each bank (bytes): ' + ', '.join(
        '%d:%d' % (b, free[b]) for b in range(nb) if 0 < free[b] < 0x4000) + '; empty banks: %s' % (empty or 'none'))


def lcd_sites(src):
    print('LCD off (static)')
    lines = src.split('\n')
    bad = []; off = 0; n = 0
    for i, l in enumerate(lines):
        code = l.split(';')[0]
        if not re.search(r'\b(ldh|ld)\s+\[\$FF40\]\s*,\s*a', code, re.I): continue
        n += 1
        prev = [re.sub(r'^[.\w]+:\s*', '', p.split(';')[0].strip()).lower() for p in lines[max(0, i - 8):i]]
        if code.strip().startswith('.lcdoff:'):
            off += 1
            w = ' '.join(prev)
            if not re.search(r'ldh a, \[\$ff44\].*cp 144', w): bad.append('%d: .lcdoff without a LY >= 144 wait' % (i + 1))
            continue
        last = prev[-1] if prev else ''
        if re.match(r'(set|res) [0-6], a', last) and any('ldh a, [$ff40]' in p for p in prev[-3:]):
            continue                                    # bits 0-6 only, the LCD stays as it is
        m = re.match(r'ld a, (.+)', last)
        if m and re.match(r'(lcdc_on\b|%1[01]{7}|\$[89a-f][0-9a-f])', m.group(1)):
            continue                                    # LCD on
        far = [re.sub(r'^[.\w]+:\s*', '', p.split(';')[0].strip()).lower() for p in lines[max(0, i - 24):i]]
        if last == 'ld a, b' and any(re.match(r'ld b, lcdc_on', p) for p in far) and \
                not any(re.match(r'(ld b,(?! lcdc_on)|res 7, b)', p) for p in far):
            continue                                    # vbl_regs: B = LCDC_ON with bits 1 / 5
        bad.append('%d: %s  (after: %s)' % (i + 1, code.strip(), ' / '.join(prev[-3:])))
    check(not bad, '%d LCDC writes, %d labelled .lcdoff, the others keep the LCD on%s' % (
        n, off, ''.join('\n          ' + b for b in bad)))


def debug_code(src, release):
    print('debug / test code')
    t = src.count('TEST_PAD')
    print('        TEST_PAD (test-runner pad input in cart RAM bank 3): %d references' % t)
    print('        rst $38 trap: %s' % ('present (crash catcher: stops on a jump into $FF filler)'
                                         if 'rst38_trap' in src else 'absent'))
    if release: check(t == 0, 'release build: no test-runner pad path')


def run_lcd(gb_path, args):
    from cynes import NES
    import firstdiff as fd
    nes_path, _, steps, pokes, poke_at, limit = fd.scenario(args)
    nes_ram, pads, frame_of, _, _ = fd.nes_pass(NES(nes_path), steps, limit, (), pokes, poke_at)
    gb = fd.GB(gb_path); sym = fd_sym(gb_path)
    st = {'k': 0, 'hits': 0, 'bad': []}
    def on_wait(_):
        m = gb.pb.memory; st['k'] = (m[0xD830] | m[0xD831] << 8) + 1
    def on_off(name):
        m = gb.pb.memory
        if not m[0xFF40] & 0x80: return                 # (already off)
        st['hits'] += 1
        if not 144 <= m[0xFF44] <= 153: st['bad'].append('%s at wait %d: LY %d' % (name, st['k'], m[0xFF44]))
    gb.pb.hook_register(*sym['rt_frame'], on_wait, None)
    for n, ba in sym.items():
        if n.endswith('.lcdoff'): gb.pb.hook_register(*ba, on_off, n)
    gb.feed_pads(sym, lambda n: pads.get(n + 1, 0))
    last = max(nes_ram)
    while st['k'] < last: gb.pb.tick()
    print('LCD off (run, %s, %d frame waits)' % ('CGB' if os.environ.get('GB_CGB') == '1' else 'DMG', last))
    check(not st['bad'], '%d LCD-off writes, all in V-Blank%s' % (st['hits'], ''.join('\n          ' + b for b in st['bad'][:10])))


def fd_sym(gb_path):
    sym = {}
    for l in open(gb_path[:-3] + '.sym'):
        b, rest = l.split(':'); a, n = rest.split(); sym[n] = (int(b, 16), int(a, 16))
    return sym


def run_reset(gb_path):
    """power-on to wait W0 with presses that get into the game, A+B+Select+Start, then W1 waits
    without input; a second run powers on and runs W1 waits without input: same screen, same
    WRAM (NES RAM page 0 and 2-7; the NES work RAM in cart RAM keeps what the game wrote, as
    on the NES after a reset)"""
    import firstdiff as fd
    import numpy as np
    sym = fd_sym(gb_path)
    W1 = 400
    def run(reset_at):
        gb = fd.GB(gb_path); st = {'k': 0, 'resets': 0}
        def on_wait(_):
            m = gb.pb.memory; st['k'] = (m[0xD830] | m[0xD831] << 8) + 1
        gb.pb.hook_register(*sym['rt_frame'], on_wait, None)
        gb.pb.hook_register(*sym['soft_reset'], lambda _: st.__setitem__('resets', st['resets'] + 1), None)
        if reset_at:
            t = 0
            while st['k'] < reset_at:
                gb.set(0x10 if (t // 8) % 6 == 0 else (0x80 if (t // 8) % 3 == 0 else 0))   # Start / A
                gb.pb.tick(); t += 1
            gb.set(0xF0); n = 0                            # A + B + Select + Start
            while not st['resets'] and n < 120: gb.pb.tick(); n += 1
            gb.set(0)
            check(st['resets'] == 1, 'A + B + Select + Start at wait %d: soft reset (%d)' % (reset_at, st['resets']))
            st['k'] = 0
        while st['k'] < W1: gb.pb.tick()
        m = gb.pb.memory
        ram = bytes(m[0xC000 + i] for i in range(0x800))
        return np.array(gb.image().convert('RGB')), ram
    kind = 'CGB' if os.environ.get('GB_CGB') == '1' else 'DMG'
    print('soft reset (%s)' % kind)
    a, ra = run(0)
    b, rb = run(2500)
    check((a == b).all(), 'screen at wait %d after the reset = power-on screen at wait %d' % (W1, W1))
    d = [i for i in range(0x800) if ra[i] != rb[i] and not 0x100 <= i < 0x200]
    print('        NES RAM bytes differing at that wait (not the stack): %d %s' % (
        len(d), ' '.join('%03X' % i for i in d[:16])))


def main():
    a = sys.argv[1:]
    def opt(name, default=None):
        if name in a:
            k = a.index(name); v = a[k + 1]; del a[k:k + 2]; return v
        return default
    def flag(name):
        if name in a: a.remove(name); return True
        return False
    cgb = opt('--cgb', '80'); cgb = None if cgb == 'none' else int(cgb, 16)
    ctype = int(opt('--type', '1B'), 16); ram = int(opt('--ram', '4'), 16)
    sgb = not flag('--no-sgb'); release = flag('--release'); reset = flag('--reset')
    run = flag('--run')
    gb_path = a.pop(0)
    rom = open(gb_path, 'rb').read()
    src = open(gb_path + '.s').read() if os.path.exists(gb_path + '.s') else ''
    print('%s: %d KB' % (gb_path, len(rom) // 1024))
    header(rom, cgb, sgb, ctype, ram)
    padding(rom, src)
    if src: lcd_sites(src); debug_code(src, release)
    else: check(False, 'assembled source %s.s missing (LCD / debug audit)' % gb_path)
    if run: run_lcd(gb_path, [a[0], gb_path] + a[1:])
    if reset: run_reset(gb_path)
    print('%d check(s) failed' % len(FAIL) if FAIL else 'all checks passed')
    sys.exit(1 if FAIL else 0)


if __name__ == '__main__':
    main()
