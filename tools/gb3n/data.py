"""FF3 native engine (Game Boy Color): game data read from the user's (English) NES ROM at build
time. Nothing here is game data: every table is decoded from the ROM by the rules of FF3's own
loaders (everything8215/ff3 disassembly, names as there).

NES PRG addressing: 8 KB banks; `pa(bank, cpu)` = PRG offset of CPU address cpu in 8 KB bank
`bank` (the window the game maps it into is implied by cpu)."""

B8 = 0x2000


class Rom:
    def __init__(self, path):
        d = open(path, 'rb').read()
        self.prg = d[16:16 + d[4] * 0x4000]

    def pa(self, bank, cpu):
        return bank * B8 + (cpu & 0x1FFF)

    def b(self, bank, cpu, n=1):
        o = self.pa(bank, cpu)
        return self.prg[o:o + n]

    def u8(self, bank, cpu):
        return self.prg[self.pa(bank, cpu)]

    # ---- maps --------------------------------------------------------------------------------
    def map_props(self, mid, world=0):
        """16 bytes (3A L3A_915E: 02/A000 + 16 id, the second set at 02/B000 off world 0)"""
        a = 0xA000 + 16 * mid + (0x1000 if world else 0)
        return self.b(2, a, 16)

    def layout(self, mid, world=0):
        """the 32 x 32 metatile layout ($7400; FCBA4 / FCBFA): id from 00/8A00 (00/8B00 from world
        2), pointer 11/8000 + 2 id (page low 5 bits | $80, bank $11 + the top 3 bits), RLE: a byte
        with bit 7 set repeats (b & $7F) the next byte's count times"""
        tid = self.u8(0, (0x8B00 if world >= 2 else 0x8A00) + mid)
        po = 0x11 * B8 + 2 * tid
        lo, hi = self.prg[po], self.prg[po + 1]
        bank = 0x11 + (hi >> 5)
        o = bank * B8 + (((hi & 0x1F) | 0x80) << 8 | lo) - 0x8000
        out = bytearray()
        while len(out) < 0x400:
            v = self.prg[o]; o += 1
            if v & 0x80:
                n = self.prg[o]; o += 1
                out += bytes([v & 0x7F]) * (n or 256)
            else:
                out.append(v)
        return bytes(out[:0x400])

    def tileset(self, ts):
        """(L3A_9267) metatiles of tileset ts: TL / TR / BL / BR tile ids (01/A380 + $200 ts),
        attributes (01/B180 + $80 ts: palette per metatile), properties (01/B500 + $100 ts:
        2 bytes per metatile); metatiles $80-$FF copied from $00-$7F by 3A/93C1 (triggers)"""
        t = 0xA380 + 0x200 * ts
        tl = self.b(1, t, 0x80); tr = self.b(1, t + 0x80, 0x80)
        bl = self.b(1, t + 0x100, 0x80); br = self.b(1, t + 0x180, 0x80)
        at = self.b(1, 0xB180 + 0x80 * ts, 0x80)
        pr = self.b(1, 0xB500 + 0x100 * ts, 0x100)
        p1, p2 = pr[0::2], pr[1::2]
        cp = self.b(0x3A, 0x93C1, 0x80)
        ext = lambda t: bytes(t) + bytes(t[x] for x in cp)
        return dict(tl=ext(tl), tr=ext(tr), bl=ext(bl), br=ext(br), attr=ext(at), p1=ext(p1), p2=ext(p2))

    def bg_palettes(self, world):
        """16 bytes: 00/9640 + (world & 6) * 8 (L3A_9091)"""
        return self.b(0, 0x9640 + (world & 6) * 8, 16)

    def obj_palettes(self, world):
        return self.b(0, 0x9670 + (world & 4) * 4, 16)

    def bg_chr(self, mid, world=0):
        """PPU $0000-$0FFF of a normal map (FDE5A + FDED6): 8 blocks from the map's graphics
        subset (00/8C00, 00/8D00 from world 2: id; 00/8E00 + 16 id: 8 pointers, page low 5 bits
        | $80, bank 3 + the top 3 bits; tiles per block from fix:DF00), then the menu window /
        text tiles (0D/B700, 144 tiles) at $0700"""
        sid = self.u8(0, (0x8D00 if world >= 2 else 0x8C00) + mid)
        tab = self.b(0, 0x8E00 + 16 * sid, 16)
        counts = self.b(0x7E, 0xDF00, 8)
        chr_ = bytearray(0x1000)
        pos = 0
        for k in range(8):
            lo, hi = tab[2 * k], tab[2 * k + 1]
            bank = 3 + (hi >> 5)
            o = bank * B8 + (((hi & 0x1F) | 0x80) << 8 | lo) - 0x8000
            n = counts[k] * 16
            chr_[pos:pos + n] = self.prg[o:o + n]; pos += n
        chr_[0x700:0x700 + 144 * 16] = self.prg[0x0D * B8 + 0x1700:0x0D * B8 + 0x1700 + 144 * 16]
        return bytes(chr_), pos

    def map_palettes(self, mid, world=0, job=0):
        """32 NES colours (BG 0-3, OBJ 0-3) of a normal map as L3A_9091 / L3A_910B / L3A_9050
        leave $03C0-$03DF: the world's base palettes; BG 0-2 and OBJ 2-3 from the map properties
        (bytes 5-9 -> the general palettes 00/9100, /9200, /9300); BG 3 the window palette;
        backdrop black; the walking character's colours (00/9690 + 4 job) in OBJ 0 / 1"""
        p = bytearray(self.bg_palettes(world) + self.obj_palettes(world))
        mp = self.map_props(mid, world)
        gen = lambda i: bytes([self.u8(0, 0x9100 + i), self.u8(0, 0x9200 + i), self.u8(0, 0x9300 + i)])
        for byte, slot in ((5, 1), (6, 5), (7, 9), (8, 0x19), (9, 0x1D)):
            p[slot:slot + 3] = gen(mp[byte])
        p[0xD:0x10] = bytes([0x00, 0x02, 0x30])
        p[0x10] = p[0] = 0x0F
        c = self.b(0, 0x9690 + 4 * (job & 0x3F), 4)
        p[0x12], p[0x13], p[0x16], p[0x17] = c[0], c[1], c[2], c[3]
        return bytes(p)

    def char_chr(self, job=0):
        """16 map-character tiles (0E/8000 + $100 job, FDD2D)"""
        o = 0x0E * B8 + 0x100 * (job & 0x3F)
        return self.prg[o:o + 0x100]


def nes2gb(tile16):
    """one NES tile (plane 0 rows, plane 1 rows) -> GB 2bpp (rows of low, high)"""
    return bytes(b for r in range(8) for b in (tile16[r], tile16[8 + r]))
