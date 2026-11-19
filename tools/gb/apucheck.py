"""Sound logic of the GB build against a frame-level model of the NES APU, wait by wait.
The NES game (cynes) plays song T (FF1's song variable $4B = $40 + T set at frame 3700 on the
field); its APU register writes drive a model of the NES APU (length counters, envelopes,
sweep and its mute rule, triangle linear counter, $4015). The GB build (PyBoy) plays the same;
at each frame wait its runtime state (channel on, GB volume, NES period after the sweep) is
compared with the model. Reports per channel the waits where sounding, period or volume differ.
usage: PYTHONPATH=build/emu apucheck.py NES GB TRACK [FRAMES]"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from compare import GB, sync_sram, gb_nmi
from cynes import NES
import fieldseq, battleseq

LEN = [10, 254, 20, 2, 40, 4, 80, 6, 160, 8, 60, 10, 14, 12, 26, 14, 12, 16, 24, 18, 48, 20, 96, 22, 192, 24, 72, 26, 16, 28, 32, 30]


class APU:
    def __init__(self):
        self.r = [0] * 0x18; self.en = 0
        self.p = [dict(len=0, start=False, div=0, decay=0, swdiv=0, swrel=False, per=0) for _ in range(2)]
        self.t = dict(len=0, lin=0, rel=False)

    def write(self, a, v):
        r = a - 0x4000
        if not 0 <= r < 0x18: return
        self.r[r] = v
        if r in (0, 4): pass
        elif r in (1, 5): self.p[r // 4]['swrel'] = True
        elif r in (2, 6): c = r // 4; self.p[c]['per'] = (self.p[c]['per'] & 0x700) | v
        elif r in (3, 7):
            c = r // 4; p = self.p[c]
            p['per'] = (p['per'] & 0xFF) | ((v & 7) << 8)
            if self.en & (1 << c): p['len'] = LEN[v >> 3]
            p['start'] = True
        elif r == 0xB:
            if self.en & 4: self.t['len'] = LEN[v >> 3]
            self.t['rel'] = True
        elif r == 0x15:
            self.en = v
            for c in range(2):
                if not v & (1 << c): self.p[c]['len'] = 0
            if not v & 4: self.t['len'] = 0

    def target(self, c):
        p = self.p[c]; sw = self.r[c * 4 + 1]; ch = p['per'] >> (sw & 7)
        return p['per'] - ch - (1 if c == 0 else 0) if sw & 8 else p['per'] + ch

    def quarter(self):
        for c in range(2):
            p = self.p[c]; ctl = self.r[c * 4]
            if p['start']: p['start'] = False; p['decay'] = 15; p['div'] = ctl & 15
            elif p['div'] == 0:
                p['div'] = ctl & 15
                if p['decay']: p['decay'] -= 1
                elif ctl & 0x20: p['decay'] = 15
            else: p['div'] -= 1
        t = self.t
        if t['rel']: t['lin'] = self.r[8] & 0x7F
        elif t['lin']: t['lin'] -= 1
        if not self.r[8] & 0x80: t['rel'] = False

    def half(self):
        for c in range(2):
            p = self.p[c]; ctl = self.r[c * 4]; sw = self.r[c * 4 + 1]
            if not ctl & 0x20 and p['len']: p['len'] -= 1
            if p['swdiv'] == 0 and sw & 0x80 and sw & 7 and p['per'] >= 8 and self.target(c) <= 0x7FF:
                p['per'] = self.target(c)
            if p['swdiv'] == 0 or p['swrel']: p['swdiv'] = (sw >> 4) & 7; p['swrel'] = False
            else: p['swdiv'] -= 1
        if not self.r[8] & 0x80 and self.t['len']: self.t['len'] -= 1

    def frame(self):
        self.quarter(); self.half(); self.quarter(); self.quarter(); self.half(); self.quarter()

    def state(self):
        out = []
        for c in range(2):
            p = self.p[c]; ctl = self.r[c * 4]
            vol = ctl & 15 if ctl & 0x10 else p['decay']
            on = p['len'] > 0 and p['per'] >= 8 and self.target(c) <= 0x7FF
            out.append((on and vol > 0, p['per'], vol if on else 0))
        t = self.t; per = self.r[0xA] | ((self.r[0xB] & 7) << 8)
        out.append((t['len'] > 0 and t['lin'] > 0 and per >= 2, per, 15))
        return out


def main():
    nes_path, gb_path, track = sys.argv[1], sys.argv[2], int(sys.argv[3], 0)
    nfr = int(sys.argv[4]) if len(sys.argv) > 4 else 900
    nes = NES(nes_path); gb = GB(gb_path); sync_sram(nes, gb)
    sym = {}
    for l in open(gb_path[:-3] + '.sym'):
        b, rest = l.split(':'); a, n = rest.split(); sym[n] = (int(b, 16), int(a, 16))
    fr = fieldseq.frames_for('_%d' % (nfr + 300)); f = 0; pads = {}; model = {}; apu = APU(); poke_k = None
    nes.watch = (0x4000, 0x4017)
    while nes.nmi_count < 3700 + nfr and f < len(fr):
        if f == 3700:
            st = nes.save(); battleseq.poke_state(st, 0x4B, 0x40 | track); nes.load(st); poke_k = nes.nmi_count
            nes.watch = (0x4000, 0x4017)
        nes.controller = fr[f]; k = nes.nmi_count; nes.step(1); f += 1
        for i, a, v in nes.watch: apu.write(a, v)
        for j in range(k + 1, nes.nmi_count + 1):
            pads[j] = nes.pad_history[j & 0xFF]
            apu.frame(); model[j] = apu.state()
    gb.feed_pads(sym, lambda n: pads.get(n + 1))
    while gb_nmi(gb) < poke_k: gb.pb.tick()
    gb.pb.memory[0xC04B] = 0x40 | track
    bad = {0: [], 1: [], 2: []}
    D = lambda a: gb.pb.memory[a]
    for k in range(poke_k + 2, 3700 + nfr - 5):
        while gb_nmi(gb) < k: gb.pb.tick()
        sh = [D(0xD840 + i) for i in range(0x18)]
        gs = []
        for c in range(2):
            on = D(0xD864 + c); cv = D(0xD868 + c)
            per = sh[c * 4 + 2] | ((sh[c * 4 + 3] & 7) << 8)
            gs.append((on and cv != 0, per, cv))
        gs.append((bool(D(0xD866)), sh[0xA] | ((sh[0xB] & 7) << 8), 15))
        m = model.get(k + int(os.environ.get('APU_SHIFT', '0')))
        if not m: continue
        for c in range(3):
            if gs[c][0] != m[c][0] or (m[c][0] and gs[c][1] != m[c][1]):
                bad[c].append((k, m[c], gs[c]))
    for c, name in enumerate(('pulse 1', 'pulse 2', 'triangle')):
        print('%-9s waits differing: %d %s' % (name, len(bad[c]), bad[c][:int(os.environ.get('APU_N', '6'))]))


if __name__ == '__main__':
    main()
