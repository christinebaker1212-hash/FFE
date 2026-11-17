"""Build the milestone-1 boot test ROM (DMG + SGB flag, MBC5+RAM+battery) and run it
headless in PyBoy: checks the frame counter, the save-RAM signature and the picture.
usage: boot_test.py [OUT.gb]"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from asm_sm83 import asm, make_rom

def build():
    src = open(os.path.join(HERE, 'rt', 'hw.s')).read() + open(os.path.join(HERE, 'rt', 'boot_test.s')).read()
    r = asm(src)
    return make_rom(r.banks, 'FFE BOOT TEST', cart_type=0x1B, rom_banks=2, ram_size_code=0x02, sgb=True), r

def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', '..', 'build', 'boot_test.gb')
    os.makedirs(os.path.dirname(out), exist_ok=True)
    rom, r = build()
    open(out, 'wb').write(rom); open(out[:-3] + '.sym', 'w').write(r.sym_file())
    from pyboy import PyBoy
    pb = PyBoy(out, window='null', cgb=False)
    pb.set_emulation_speed(0)
    for _ in range(200): pb.tick()           # the boot ROM's logo scroll runs first
    f0 = pb.memory[r.labels['frames']]
    for _ in range(60): pb.tick()
    frames = (pb.memory[r.labels['frames']] - f0) & 0xFF
    sram = pb.memory[0xA000]
    img = pb.screen.ndarray
    shades = sorted(set(map(tuple, img[:, :, :3].reshape(-1, 3).tolist())))
    pb.screen.image.save(out[:-3] + '.png')
    pb.stop(save=False)
    ok = frames == 60 and sram == 0x5A and len(shades) == 3
    print('vblanks in 60 frames=%d sram=%02X shades=%d -> %s' % (frames, sram, len(shades), 'OK' if ok else 'FAIL'))
    sys.exit(0 if ok else 1)

if __name__ == '__main__':
    main()
