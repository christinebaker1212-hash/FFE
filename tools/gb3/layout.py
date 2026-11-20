"""FF3 GBC screen layouts on the NES side (after tools/ff3/insert.py), as FF1 / FF2 do: the game
code itself draws its screens for a 160x144 view, so the GB build can still be checked frame
by frame against this "GB-layout" NES ROM.

usage: layout.py EN.nes OUT.nes        (EN.nes = the English build, build/ff3_en.nes)

Patches are matched by their original bytes (a wrong address stops the build). Owner's
decisions: docs/ff3-gb-plan.md section 6.

Battle (decision 3, with FF1 / FF2's battle rules):
- cameras (GB runtime registers, open bus on the NES): battlefield camera NES x 20 / y 48
  (pixels, $5802 / $5803), window camera (tiles, $5800 / $5801) = col 2 / row 6, split at GB
  line 96 ($5804); field camera back after the battle
- party column GB x 140-159: front row NES x 160, back row 164; members 24 px apart from NES
  y 47 (GB rows 0-11, every sprite whole); acting members step 8 px (back row 12)
- battle windows from NES row 18 (GB row 12) instead of 19, one tile row per text line (the
  English text has no dakuten row): 4 text rows; party window cols 2-21 (GB 0-19), command
  and enemy-name windows cols 2-11 (GB 0-9)
"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..'))
B8 = 0x2000


class Rom:
    def __init__(self, data):
        self.d = bytearray(data); self.log = []

    def off(self, bank, addr):
        return 16 + bank * B8 + (addr & 0x1FFF)

    def patch(self, bank, addr, old, new, why):
        """bytes at CPU addr in 8 KB bank: old (hex) -> new (hex)"""
        old = bytes.fromhex(old.replace(' ', '')); new = bytes.fromhex(new.replace(' ', ''))
        o = self.off(bank, addr)
        if self.d[o:o + len(old)] != old:
            raise SystemExit('layout: %02X:%04X is %s, expected %s (%s)' % (
                bank, addr, self.d[o:o + len(old)].hex(), old.hex(), why))
        self.d[o:o + len(new)] = new
        self.log.append((bank, addr, why))


def battle(r):
    B2F, B34, B7F, B40 = 0x2F, 0x34, 0x7F, 0x40
    # cameras: two trampolines in the ExRAM image's free bytes ($5E7F-$5E8F; the English
    # engine's box save buffer starts at $5E90), called instead of "reset ppu control"
    # ($FA1D) at the start and the end of a battle ($FA26)
    code = bytes([
        0xA9, 0x01,             # $5E7F gbbon:  LDA #1 (battle cameras)
        0xD0, 0x02,             #               BNE +2
        0xA9, 0x00,             # $5E83 gbboff: LDA #0 (field camera)
        0x8D, 0x06, 0x58,       #               STA $5806 (GB: camera set)
        0x4C, 0x1D, 0xFA])      #               JMP $FA1D
    assert len(code) <= 0x5E90 - 0x5E7F
    r.patch(B40, 0x827F, 'FF' * len(code), code.hex(), 'battle camera trampolines (ExRAM $5E7F)')
    r.patch(B7F, 0xFA2F, '20 1D FA', '20 7F 5E', 'battle start: battle cameras')
    r.patch(B7F, 0xFA73, '20 1D FA', '20 83 5E', 'battle end: field camera')
    # party column: x by row (front, back) and members 24 px apart
    r.patch(B2F, 0xB516, 'D0 E0', 'A0 A4', 'party x: front 160 / back 164 (GB 140 / 144)')
    for a in (0xB51E, 0xB526):
        r.patch(B2F, a, '2C 48 64 80', '2F 47 5F 77', 'party y: 24 px apart from 47')
    # step forward / back: 8 px (front row), 12 (back row), 8 confused
    r.patch(B2F, 0xB3B8, '10', '08', 'step forward (front row) 8 px')
    r.patch(B2F, 0xB3B1, '20', '0C', 'step forward (back row) 12 px')
    r.patch(B2F, 0xB37C, '10', '08', 'step back (front row) 8 px')
    r.patch(B2F, 0xB375, '20', '0C', 'step back (back row) 12 px')
    r.patch(B2F, 0xB362, 'F0', 'F8', 'confused: step back 8 px')
    r.patch(B2F, 0xB39E, 'F0', 'F8', 'confused: step back 8 px')
    # battle windows: from row 18, 4 rows of text (one tile row per line)
    r.patch(B34, 0x8B8F, '69 60 85 2A A9 00 69 22', '69 40 85 2A A9 00 69 22', 'windows from row 18 (nt 0)')
    r.patch(B34, 0x8BA0, '69 60 85 2A A9 00 69 26', '69 40 85 2A A9 00 69 26', 'windows from row 18 (nt 1)')
    r.patch(B34, 0x8BB0, 'A9 60', 'A9 40', 'windows from row 18 (overflow, nt 0)')
    r.patch(B34, 0x8BBB, 'A9 60', 'A9 40', 'windows from row 18 (overflow, nt 1)')
    r.patch(B34, 0x8BC3, 'A9 08', 'A9 04', 'windows: 4 rows')
    r.patch(B34, 0x966A, 'A5 18', 'A9 00', 'text lines in the first buffer row (bconv)')
    r.patch(B34, 0x969C, 'A5 18', 'A9 00', 'text lines in the first buffer row (bconvb)')
    r.patch(B34, 0x967E, '0A', 'EA', 'bconv newline: one buffer row (was two)')
    r.patch(B34, 0x9BB0, 'A9 77 8D 0A 72 A9 79 8D 0B 72', 'EA' * 10, 'no HP header (on line 1 now)')
    r.patch(B34, 0x9CD4, 'A9 0B 85 18 A9 1E', 'A9 02 85 18 A9 15', 'party window cols 2-21')
    for a in (0x9AD8, 0x9DD5):
        r.patch(B34, a, 'A9 01 85 18 A9 0A', 'A9 02 85 18 A9 0B', 'command / names window cols 2-11')


def main():
    src, out = sys.argv[1], sys.argv[2]
    r = Rom(open(src, 'rb').read())
    battle(r)
    open(out, 'wb').write(bytes(r.d))
    print('layout: %d patches -> %s' % (len(r.log), out))


if __name__ == '__main__':
    main()
