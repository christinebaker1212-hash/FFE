"""The native FF3 sound driver (src/snd.s) against the owner's FF3 NSF, song by song.

  state:  FF3's driver in the NSF runs in a 6502 emulator (py65), the native build in PyBoy; the
          driver variables ($7F40-$7FFF on the NES, $CC40-$CCFF on the GB) are compared frame by
          frame from the song's start (the song number bytes $7F40 / $7F41 / $7F43 excepted: the
          NSF's own init numbers the songs of its second bank from 0).
  voices: each voice alone, NES rendered by libgme (build/nsfrender), GB recorded by mGBA
          (build/sgbrun --cgb, test builds with env GB_SND_MASK = the voice's NR51 bits):
          frames sounding on one side only, loudness-envelope correlation, pitch agreement.

usage: python3 tools/gb3n/sndcmp.py state|voices NSF [SONGS] [SECONDS]
       SONGS: FF3 song numbers, e.g. 0,2,12 or 0-64 (default 0-64; song 54 is not in the NSF)
The NSF is the user's own file; nothing of it is kept."""
import os, sys, subprocess, tempfile
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.join(HERE, '..', '..')
sys.path.insert(0, os.path.join(ROOT, 'tools', 'gb'))
NES_HZ = 1789773 / 29780.5
GB_HZ = 4194304 / 70224
VOICES = [('pulse 1', '11'), ('pulse 2', '22'), ('triangle', '44'), ('noise', '88')]


def track_of(song):
    """FF3 song number -> NSF track (1-based): the NSF orders songs $37-$40 before $2B-$35"""
    if song < 43: return song + 1
    if song < 54: return song + 11
    return song - 11


def build(song, out, mask='FF'):
    env = dict(os.environ, GB_SND_MASK=mask)
    subprocess.run([sys.executable, os.path.join(HERE, 'build.py'), '--map', '6', '--song', str(song),
                    '--out', out], check=True, capture_output=True, env=env)


def nsf_states(nsf, track, frames):
    from py65.devices.mpu6502 import MPU
    d = open(nsf, 'rb').read()
    data = d[0x80:]; init = d[10] | d[11] << 8; play = d[12] | d[13] << 8

    class Mem:
        def __init__(self): self.ram = bytearray(0x10000); self.bank = list(d[0x70:0x78])
        def __len__(self): return 0x10000
        def __getitem__(self, a):
            if isinstance(a, slice): return [self[i] for i in range(*a.indices(0x10000))]
            if a >= 0x8000:
                o = self.bank[(a - 0x8000) >> 12] * 0x1000 + (a & 0xFFF)
                return data[o] if o < len(data) else 0
            return self.ram[a]
        def __setitem__(self, a, v):
            if isinstance(a, slice):
                for i, x in zip(range(*a.indices(0x10000)), v): self[i] = x
                return
            if 0x5FF8 <= a <= 0x5FFF: self.bank[a - 0x5FF8] = v & 0xFF
            if a < 0x8000: self.ram[a] = v & 0xFF
    m = Mem(); cpu = MPU(memory=m)

    def call(addr, a=0):
        m.ram[0x300:0x304] = bytes([0x20, addr & 0xFF, addr >> 8, 0xEA])
        cpu.pc = 0x300; cpu.a = a; cpu.sp = 0xFD
        n = 0
        while cpu.pc != 0x303:
            cpu.step(); n += 1
            if n > 2000000: raise RuntimeError('NSF stuck at %04X' % cpu.pc)
    call(init, a=track - 1)
    out = []
    for f in range(frames):
        call(play); out.append(bytes(m.ram[0x7F40:0x8000]))
    return out


def gb_states(rom, frames):
    from pyboy import PyBoy
    pb = PyBoy(rom, window='null', cgb=True)
    out = []
    for f in range(frames):
        pb.tick(); out.append(bytes(pb.memory[0xCC40:0xCD00]))
    pb.stop(save=False)
    return out


def state(nsf, songs, secs):
    tmp = tempfile.mkdtemp()
    nf = secs * 60
    for s in songs:
        rom = os.path.join(tmp, 's%d.gbc' % s)
        build(s, rom)
        ref = nsf_states(nsf, track_of(s), nf + 60)
        gb = gb_states(rom, nf + 400)
        rs = next((k for k, x in enumerate(ref) if x[0x18]), None)
        gs = next((k for k, x in enumerate(gb) if x[0x18]), None)
        if rs is None or gs is None:
            print('song %d: not started (NSF %s, GB %s)' % (s, rs, gs)); continue
        ref, gb = ref[rs:], gb[gs:]
        n = min(len(ref), len(gb), nf)
        for k in range(n):
            d = [o for o in range(0xC0) if ref[k][o] != gb[k][o] and o not in (0, 1, 3)]
            if d:
                print('song %d (track %d): frame %d differs: %s' % (s, track_of(s), k, ' '.join(
                    '$%02X NES %02X GB %02X' % (o + 0x40, ref[k][o], gb[k][o]) for o in d[:8])))
                break
        else:
            print('song %d (track %d): identical, %d frames' % (s, track_of(s), n))
        sys.stdout.flush()


def gb1():
    """tools/gb/sndcmp.py (FF1's tool): load / frames"""
    import importlib.util
    spec = importlib.util.spec_from_file_location('ff1_sndcmp', os.path.join(ROOT, 'tools', 'gb', 'sndcmp.py'))
    m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
    return m


def voices(nsf, songs, secs):
    g = gb1()
    tmp = tempfile.mkdtemp()
    nf = secs * 60
    for s in songs:
        t = track_of(s)
        print('song %d (track %d)' % (s, t))
        rec = []
        for v, (name, mask) in enumerate(VOICES):
            ref = os.path.join(tmp, 'n%d.wav' % v); gbw = os.path.join(tmp, 'g%d.wav' % v)
            rom = os.path.join(tmp, 'v%s.gbc' % mask)
            build(s, rom, mask)
            subprocess.run([os.path.join(ROOT, 'build', 'nsfrender'), nsf, str(t), str(secs + 2), ref, str(v)], check=True)
            subprocess.run([os.path.join(ROOT, 'build', 'sgbrun'), rom, str(nf + 200), os.path.join(tmp, 'x'), '--cgb'],
                           check=True, capture_output=True, env=dict(os.environ, SGBRUN_WAV=gbw))
            xn, srn = g.load(ref); xg, srg = g.load(gbw); xg = cgb_filter(xg, srg)
            # (each side cut at its own frame rate: NES 60.0988 Hz, GB 59.7275 Hz: the GB plays
            # the same frames 0.6% slower)
            fn = g.frames(xn, srn * 60 / NES_HZ, nf); fg_all = g.frames(xg, srg * 60 / GB_HZ, nf + 200)
            ln = np.array([np.sqrt(np.mean(x ** 2)) for x in fn])
            lg_all = np.array([np.sqrt(np.mean(x ** 2)) for x in fg_all])
            rec.append((fn, srn, ln, fg_all, srg, lg_all))
        # one lag for the song (every test build boots alike): the fewest frames sounding on one
        # side only over all voices, then the best summed envelope correlation
        def score(L):
            miss = 0; tot = 0
            for fn, srn, ln, fg_all, srg, lg_all in rec:
                w = lg_all[L:L + nf]
                if ln.max() > 0 and w.std() > 0:
                    miss += int(((ln > 0.02 * ln.max()) != (w > 0.02 * w.max())).sum())
                    tot += np.corrcoef(ln, w)[0, 1]
            return (-miss, tot)
        best = max(range(0, 200), key=score)
        for v, (name, mask) in enumerate(VOICES):
            fn, srn, ln, fg_all, srg, lg_all = rec[v]
            if ln.max() == 0:
                print('  %-9s NES silent; GB %s' % (name, 'silent' if lg_all[best:best + nf].max() < 1 else
                                                    'sounds (rms %.0f)' % lg_all[best:best + nf].max())); continue
            lg = lg_all[best:best + nf]; fg = fg_all[best:best + nf]
            on_n = ln > 0.02 * ln.max(); on_g = lg > 0.02 * max(lg.max(), 1e-9)
            corr = np.corrcoef(ln, lg)[0, 1] if lg.std() > 0 else 0
            detail = os.environ.get('SND_DETAIL') == name.replace(' ', '')
            if detail:
                print('    lag %d; NES-only frames %s; GB-only %s' % (best, list(np.where(on_n & ~on_g)[0][:40]),
                                                                  list(np.where(~on_n & on_g)[0][:40])))
            cents = []
            meas = centroid if v == 3 else pitch
            for k in range(0, nf - 4, 4):
                if on_n[k:k + 4].all() and on_g[k:k + 4].all():
                    a = meas(np.concatenate(fn[k:k + 4]), srn); b = meas(np.concatenate(fg[k:k + 4]), srg)
                    if a and b:
                        cents.append(1200 * np.log2(b / a))
                        if detail and abs(cents[-1]) > 50:
                            print('    frame %d: NES %.0f Hz, GB %.0f Hz' % (k, a, b))
            cents = np.array(cents)
            off = (np.abs(cents) > 50).mean() * 100 if len(cents) else 0
            print('  %-9s sounding NES %4d GB %4d | NES-only %4d GB-only %4d | envelope corr %.2f | %s off >50c %4.1f%% (median %+.0f)' % (
                name, on_n.sum(), on_g.sum(), (on_n & ~on_g).sum(), (~on_n & on_g).sum(), corr,
                'brightness' if v == 3 else 'pitch', off, np.median(cents) if len(cents) else 0))
        sys.stdout.flush()


def cgb_filter(x, sr):
    """the Color's output capacitor (Pan Docs: charge factor 0.998943 per clock), a high-pass that
    mGBA's recording leaves out: y[n] = x[n] - x[n-1] + k y[n-1]"""
    k = 0.998943 ** (4194304 / sr)
    y = np.empty_like(x); prev_x = prev_y = 0.0
    for i, v in enumerate(x.tolist()):
        prev_y = v - prev_x + k * prev_y; prev_x = v; y[i] = prev_y
    return y


def pitch(seg, sr):
    """the lowest strong spectral peak"""
    if len(seg) < 64 or np.abs(seg).max() < 1e-6: return 0.0
    N = 1 << 15; sp = np.abs(np.fft.rfft(seg * np.hanning(len(seg)), N)); f = np.fft.rfftfreq(N, 1 / sr)
    m = (f > 30) & (f < 5000); sm, fm = sp[m], f[m]
    i = np.where(sm > 0.3 * sm.max())[0][0]
    while i + 1 < len(sm) and sm[i + 1] > sm[i]: i += 1
    return fm[i]


def centroid(seg, sr):
    """the noise voice's brightness: the spectral centroid"""
    if len(seg) < 64 or np.abs(seg).max() < 1e-6: return 0.0
    sp = np.abs(np.fft.rfft(seg * np.hanning(len(seg)))); f = np.fft.rfftfreq(len(seg), 1 / sr)
    m = (f > 30) & (f < 12000)
    return float((sp[m] * f[m]).sum() / max(sp[m].sum(), 1e-9))


def parse_songs(arg):
    out = []
    for part in arg.split(','):
        if '-' in part:
            a, b = part.split('-'); out += list(range(int(a), int(b) + 1))
        else:
            out.append(int(part))
    return [s for s in out if s != 54]


if __name__ == '__main__':
    mode, nsf = sys.argv[1], sys.argv[2]
    songs = parse_songs(sys.argv[3]) if len(sys.argv) > 3 else parse_songs('0-64')
    secs = int(sys.argv[4]) if len(sys.argv) > 4 else 15
    {'state': state, 'voices': voices}[mode](nsf, songs, secs)
