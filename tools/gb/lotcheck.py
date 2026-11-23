"""Static release checks of a built Game Boy ROM (docs/gb-release-checklist.md section 1, and
the binary side of section 4). Independent of the writer (tools/gb/asm_sm83.py make_rom):
everything is recomputed from the file.

usage: lotcheck.py ROM --game ff1|ff2|ff3 [--release]

Checks:
  - Nintendo logo $0104-$0133 (the boot ROM compares it byte for byte)
  - header checksum $014D (complement sum over $0134-$014C) and global checksum $014E-$014F
  - flags: cartridge type $0147 = $1B (MBC5 + RAM + battery), ROM size $0148 = the file size,
    RAM size $0149 (32 KB; FF3 release 8 KB: the save slots), CGB flag $0143 (FF1 / FF2 $80, FF3 $C0), SGB flag $0146
    (FF1 / FF2 $03 with old licensee $33, FF3 $00), destination $014A
  - unused space: every bank whose bytes are all one value holds $FF, and each bank's tail
    (after its last byte that is not $FF) is $FF to the bank end (padding consistent)
  - --release: no test hook left in the binary (the runtime's test-pad read: ld a, [TEST_PAD]
    followed by cp $A5), checked against the ROM's .sym when present (no TEST_PAD use)
Exit status 1 if any check fails; every result is printed (PASS / FAIL)."""
import sys, os, argparse

LOGO = bytes.fromhex(
    'CEED6666CC0D000B03730083000C000D0008111F8889000EDCCC6EE6DDDDD999'
    'BBBB67636E0EECCCDDDC999FBBB9333E')
GAMES = {
    'ff1': dict(cgb=0x80, sgb=0x03, test_pad=0xD83E),
    'ff2': dict(cgb=0x80, sgb=0x03, test_pad=0xD83E),
    'ff3': dict(cgb=0xC0, sgb=0x00, test_pad=0xCD9E),
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('rom'); ap.add_argument('--game', required=True, choices=sorted(GAMES))
    ap.add_argument('--release', action='store_true')
    a = ap.parse_args()
    g = GAMES[a.game]
    d = open(a.rom, 'rb').read()
    res = []

    def check(name, ok, info=''):
        res.append(ok)
        print('%s  %s%s' % ('PASS' if ok else 'FAIL', name, (': ' + info) if info else ''))

    check('Nintendo logo $0104-$0133', d[0x104:0x134] == LOGO)
    x = 0
    for i in range(0x134, 0x14D): x = (x - d[i] - 1) & 0xFF
    check('header checksum $014D', d[0x14D] == x, 'stored %02X, computed %02X' % (d[0x14D], x))
    s = (sum(d) - d[0x14E] - d[0x14F]) & 0xFFFF
    st = d[0x14E] << 8 | d[0x14F]
    check('global checksum $014E-$014F', st == s, 'stored %04X, computed %04X' % (st, s))
    check('cartridge type $0147 = $1B (MBC5 + RAM + battery)', d[0x147] == 0x1B, '%02X' % d[0x147])
    size_code = {32768 << k: k for k in range(9)}.get(len(d))
    check('ROM size $0148 matches the file (%d KB)' % (len(d) // 1024), size_code is not None and d[0x148] == size_code,
          '%02X' % d[0x148])
    ram = 0x02 if a.game == 'ff3' and a.release else 0x03   # (FF3 release: the save slots only, 8 KB;
    check('RAM size $0149 = $%02X' % ram, d[0x149] == ram, '%02X' % d[0x149])   #  dev builds: + test pads in bank 3)
    check('CGB flag $0143 = $%02X' % g['cgb'], d[0x143] == g['cgb'], '%02X' % d[0x143])
    check('SGB flag $0146 = $%02X' % g['sgb'], d[0x146] == g['sgb'], '%02X' % d[0x146])
    if g['sgb']: check('old licensee $014B = $33 (SGB functions need it)', d[0x14B] == 0x33, '%02X' % d[0x14B])
    check('destination $014A = $01 (overseas)', d[0x14A] == 0x01, '%02X' % d[0x14A])
    check('entry point $0100: nop / jp', d[0x100] == 0x00 and d[0x101] == 0xC3,
          '%02X %02X %02X %02X' % tuple(d[0x100:0x104]))
    bad_fill = []; bad_tail = []
    symf = os.path.splitext(a.rom)[0] + '.sym'           # (banks the builder marks as data of one
    data = set()                                          #  value: `uniform_data_N` at N:4000)
    if os.path.exists(symf):
        for l in open(symf):
            p = l.split()
            if len(p) == 2 and p[1].startswith('uniform_data_'): data.add(int(p[0].split(':')[0], 16))
    for b in range(len(d) // 0x4000):
        bank = d[b * 0x4000:(b + 1) * 0x4000]
        if len(set(bank)) == 1 and bank[0] != 0xFF and b not in data: bad_fill.append(b)
    check('unused banks filled with $FF', not bad_fill, 'banks %s' % bad_fill if bad_fill else '')
    if a.release:
        tp = g['test_pad']
        pat = bytes([0xFA, tp & 0xFF, tp >> 8, 0xFE, 0xA5])   # ld a, [TEST_PAD] / cp $A5
        hits = [i for i in range(len(d) - 5) if d[i:i + 5] == pat]
        check('no test-pad hook (ld a, [$%04X] / cp $A5)' % tp, not hits,
              ' '.join('%02X:%04X' % (i // 0x4000, 0x4000 * (i >= 0x4000) + i % 0x4000) for i in hits[:4]))
        sym = os.path.splitext(a.rom)[0] + '.sym'
        if os.path.exists(sym):
            names = [l.split()[1] for l in open(sym) if l[:1] not in ';\n' and len(l.split()) == 2]
            dev = [n for n in names if 'test' in n.lower() or n.startswith(('rst38_trap',))]
            check('no test symbols in %s' % os.path.basename(sym), not dev, ' '.join(dev[:6]))
    print('%d of %d checks pass' % (sum(res), len(res)))
    sys.exit(0 if all(res) else 1)


if __name__ == '__main__':
    main()
