"""Run the NES build (cynes) and the GB build (PyBoy) on the same input script and
save side-by-side screenshots; compare NES RAM $0000-$07FF with GB $C000-$C7FF and
NES save RAM with GB $A000 at each shot.
usage: PYTHONPATH=build/emu compare.py NES.nes GB.gb OUTPREFIX [--random SEED FRAMES]"""
import os, sys, random
import numpy as np
from PIL import Image
from cynes import NES
from pyboy import PyBoy

RIGHT, LEFT, DOWN, UP, START, SEL, B, A = 1, 2, 4, 8, 16, 32, 64, 128
GBNAME = {RIGHT: 'right', LEFT: 'left', DOWN: 'down', UP: 'up', START: 'start', SEL: 'select', B: 'b', A: 'a'}


def new_game_script():
    s = [(0, 1, 600), (START, 5, 120), (A, 5, 60)]
    for c in range(4): s += [(A, 5, 40), (A, 5, 30), (A, 5, 30), (A, 5, 30), (A, 5, 60), ('shot',)]
    s += [(START, 5, 200), ('shot',), (A, 5, 300), ('shot',), (A, 5, 300), ('shot',)]
    for k in range(6): s += [(A, 5, 200), ('shot',)]
    return s


class GB:
    def __init__(self, path):
        self.pb = PyBoy(path, window='null', cgb=os.environ.get('GB_CGB') == '1', sound_emulated=False)
        self.pb.set_emulation_speed(0)
        self.held = 0

    def set(self, mask):
        for bit, name in GBNAME.items():
            if mask & bit and not self.held & bit: self.pb.button_press(name)
            if not mask & bit and self.held & bit: self.pb.button_release(name)
        self.held = mask

    def step(self, n):
        for _ in range(n): self.pb.tick()

    def ram(self):
        return bytes(self.pb.memory[0xC000 + k] for k in range(0x800))

    def image(self):
        return self.pb.screen.image.convert('RGB')


def sync_sram(nes, gb):
    """Give the GB cart RAM (bank 0 = NES $6000-$7FFF) the NES emulator's power-on
    contents, so reads of not-yet-written save RAM agree."""
    for i in range(0x2000):
        gb.pb.memory[0, 0xA000 + i] = nes[0x6000 + i]


def gb_nmi(gb):
    m = gb.pb.memory
    return m[0xD830] | m[0xD831] << 8


def main():
    nes_path, gb_path, prefix = sys.argv[1:4]
    script = new_game_script()
    if '--random' in sys.argv:
        k = sys.argv.index('--random'); rng = random.Random(int(sys.argv[k + 1])); n = int(sys.argv[k + 2])
        btns = [UP, DOWN, LEFT, RIGHT, A, A, B, START, UP, DOWN, LEFT, RIGHT]
        done = 0
        while done < n:
            h = rng.randint(2, 40); g = rng.randint(1, 20)
            script.append((rng.choice(btns), h, g)); done += h + g
            if len(script) % 40 == 0: script.append(('shot',))
        script.append(('shot',))
    off = int(sys.argv[sys.argv.index('--off') + 1]) if '--off' in sys.argv else 0
    nes = NES(nes_path); gb = GB(gb_path); sync_sram(nes, gb)
    shots = []; gb_ticks = 0; first_bad = None

    def frame(mask):
        nonlocal gb_ticks
        nes.controller = mask
        k0 = nes.nmi_count
        nes.step(1)
        hist = nes.pad_history
        for j in range(k0 + 1, nes.nmi_count + 1):      # one GB frame per NES NMI, same pad
            gb.set(hist[j & 0xFF])
            guard = 0
            while gb_nmi(gb) < j + off and guard < 600:
                gb.pb.tick(); gb_ticks += 1; guard += 1
            if guard >= 600: raise SystemExit('GB stuck (NES nmi %d, GB %d)' % (nes.nmi_count, gb_nmi(gb)))

    for it in script:
        if it[0] == 'shot':
            fn = np.array(nes.step(1)); nes.step  # picture after this frame
            target = nes.nmi_count + off
            while gb_nmi(gb) < target: gb.pb.tick(); gb_ticks += 1
            nr = bytes(nes[k] for k in range(0x800)); gr = gb.ram()
            diff = [k for k in range(0x800) if nr[k] != gr[k] and not 0x100 <= k < 0x200]
            sw = [k for k in range(0x2000) if nes[0x6000 + k] != gb.pb.memory[0xA000 + k]]
            print('shot %2d (NES nmi %5d, GB frames %5d): RAM diff %3d %s | SRAM diff %d' % (
                len(shots), nes.nmi_count, gb_ticks, len(diff), ' '.join('%03X' % d for d in diff[:12]), len(sw)))
            shots.append((Image.fromarray(fn), gb.image()))
            continue
        m, hold, after = it
        for _ in range(hold): frame(m)
        for _ in range(after): frame(0)
    W = 256 + 16 + 320
    im = Image.new('RGB', (W, 288 * len(shots)), 'white')
    for i, (a, b) in enumerate(shots):
        im.paste(a, (0, i * 288)); im.paste(b.resize((320, 288)), (272, i * 288))
    im.save(prefix + '.png')
    print('saved', prefix + '.png')


if __name__ == '__main__':
    main()
